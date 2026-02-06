#!/usr/bin/env fish
#
# ry-install v4.0
# Self-contained installer - all config files embedded
# Target: Beelink GTR9 Pro (AMD Ryzen AI Max+ 395 / Strix Halo)
# Author: Ryan Musante
# License: MIT
# TARGET HARDWARE:
#   System:   Beelink GTR9 Pro
#   CPU:      AMD Ryzen AI Max+ 395 (Zen 5, 16C/32T, 5.1GHz boost)
#   GPU:      AMD Radeon 8060S (RDNA 3.5, gfx1151, 40 CUs)
#   Memory:   128GB LPDDR5x-8000 (soldered, unified with GPU)
#   Storage:  Dual M.2 2280 PCIe 4.0
#   WiFi:     MediaTek MT7925 (WiFi 7)
#   Ethernet: Dual Intel E610 10GbE
#   TDP:      55-120W configurable (BIOS cTDP settings)
#
# USAGE:
#   ./ry-install.fish [OPTIONS]
#
# OPTIONS:
#   --all             Unattended installation (auto-yes to all prompts)
#   --verbose         Show output on terminal (default: silent, log only)
#   --dry-run         Preview changes without modifying system
#   --diff            Compare embedded files against installed system
#   --verify          Run full verification (static + runtime)
#   --verify-static   Verify config file existence and content
#   --verify-runtime  Verify live system state (run after reboot)
#   --lint            Run fish syntax and anti-pattern checks
#   --no-color        Disable colored output
#   -h, --help        Display help message
#   -v, --version     Display version
#
# NOTES
# - Strix Halo: early platform, check Beelink/kernel bugzilla for updates
# - Thermal: 85°C sustained target, 95°C throttle, 100°C max
# - AMDGPU udev timing (Arch #72655): use amdgpu-performance.service fallback
# - mkinitcpio: resume hook omitted (sleep masked), LUKS systems add sd-encrypt
# - Sleep: all targets masked, S0ix only (no S3), desktop stays powered
# - WiFi: iwd required, do NOT enable iwd.service (NM manages it internally)
# - Security: split_lock_detect=off for gaming, editor=no in loader.conf
# - Cmdline+modprobe duplication: intentional for built-in vs loadable modules
# - ppfeaturemask: cmdline-only (must be set at module load)
# - eval in _run(): safe, all inputs controlled by script
# - Services exit 0: by design for missing sysfs
# - Intel E610: dual 10GbE NICs have confirmed firmware lockup (NVM <1.30).
#   ice driver blacklisted. Use WiFi or USB ethernet until Intel NVM update.
# - linux-firmware: version 20251125 breaks ROCm on Strix Halo. Use ≥20260110.
# - sched-ext: not compatible with BORE kernel. Pre-flight check in do_install, detailed check in do_diagnose.
# GLOBAL CONFIGURATION

set -g VERSION "4.0.1"
set -g DRY false
set -g ALL false
set -g FORCE false
set -g QUIET true
set -g NO_COLOR false

# Respect NO_COLOR environment variable (https://no-color.org/)
if set -q NO_COLOR; or test "$TERM" = "dumb"
    set -g NO_COLOR true
end

# Warn if running as root directly (should use sudo internally)
if test (id -u) -eq 0
    echo "Warning: Running as root. This script uses sudo internally." >&2
    echo "Consider running as normal user: ./ry-install.fish" >&2
    echo "" >&2
end

# Generate unique timestamp for log file (with timezone)
# Check fish version (3.3+ required for string match -r, argparse features)
set -l fish_ver (string match -r '\d+\.\d+' (fish --version 2>&1) | head -1)
if test -z "$fish_ver"
    echo "Error: Could not determine fish version" >&2
    exit 1
end
set -l fish_major (string split '.' "$fish_ver")[1]
set -l fish_minor (string split '.' "$fish_ver")[2]
# Validate parsed values are numeric
if test -z "$fish_major"; or not string match -qr '^\d+$' "$fish_major"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test -z "$fish_minor"; or not string match -qr '^\d+$' "$fish_minor"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test "$fish_major" -lt 3; or test "$fish_major" -eq 3 -a "$fish_minor" -lt 3
    echo "Error: fish 3.3+ required (found: $fish_ver)" >&2
    exit 1
end

set -g TIMESTAMP (date +%Y%m%d-%H%M%S%z)

# Handle missing HOME
if test -z "$HOME"
    set -g HOME (getent passwd (id -u) 2>/dev/null | cut -d: -f6)
    if test -z "$HOME"
        # Fallback: use fish native tilde expansion
        set -g HOME ~
    end
    if test -z "$HOME"; or not test -d "$HOME"
        echo "Error: Cannot determine HOME directory" >&2
        exit 1
    end
end

# Output paths
set -g LOG_DIR "$HOME/ry-install/logs"
set -g BACKUP_DIR "$HOME/ry-install/backup/$TIMESTAMP"
mkdir -p "$LOG_DIR" 2>/dev/null
set -g LOG_FILE "$LOG_DIR/install-$TIMESTAMP.log"  # Placeholder; renamed after MODE is known
touch "$LOG_FILE" 2>/dev/null; chmod 600 "$LOG_FILE" 2>/dev/null  # Restrict log file permissions
set -g TERMINAL_LOG  # List-based log: each entry is one line (avoids O(n²) string concat)
set -g INSTALL_HAD_ERRORS false  # Track if any installation steps failed

# Signal handler for cleanup on interrupt
function _cleanup --on-signal INT --on-signal TERM
    echo "" >&2
    echo "[WARN] Interrupted - cleaning up..." >&2
    # Remove orphaned temp files from known destinations
    for dir in /etc /etc/modprobe.d /etc/modules-load.d /etc/systemd/resolved.conf.d /etc/systemd/logind.conf.d /etc/systemd/system /etc/NetworkManager/conf.d /etc/NetworkManager/system-connections /etc/udev/rules.d /etc/iwd /etc/conf.d /boot /boot/loader
        for f in $dir/.ry-install.*
            test -f "$f"; and sudo rm -f "$f" 2>/dev/null
        end
    end
    # Remove orphaned temp files from user destinations (no sudo needed)
    for dir in "$HOME/.config/fish/conf.d" "$HOME/.config/environment.d"
        for f in $dir/.ry-install.*
            test -f "$f"; and rm -f "$f" 2>/dev/null
        end
    end
    if set -q SUDO_KEEPALIVE_PID
        kill $SUDO_KEEPALIVE_PID 2>/dev/null
    end
    exit 130
end

# FILE DEFINITIONS
# Each file is defined with: destination path and content

# File destinations (system files require sudo)
set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" \
    "/etc/udev/rules.d/99-cachyos-udev.rules" \
    "/etc/modprobe.d/99-cachyos-modprobe.conf" \
    "/etc/environment" \
    "/etc/iwd/main.conf" \
    "/etc/mkinitcpio.conf" \
    "/etc/modules-load.d/99-cachyos-modules.conf" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
    "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/sdboot-manage.conf" \
    "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/conf.d/wireless-regdom"

set -g USER_DESTINATIONS \
    "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" \
    "$HOME/.config/environment.d/50-gaming.conf"

set -g SERVICE_DESTINATIONS \
    "/etc/systemd/system/amdgpu-performance.service" \
    "/etc/systemd/system/cpupower-epp.service"

# AUDIT NOTES (v3.6.0) — services:
#   amdgpu-performance.service (sets "high") — ROCm Issue #5750 reports "high" is accepted
#     but may not change clocks on Strix Halo iGPU. Adds 5-15W idle power on 140W TDP.
#     Kept: ensures maximum GPU performance when it does work; exit 0 is safe if sysfs missing.
#   cpupower-epp.service — forces performance governor + performance EPP. With BORE kernel
#     (no sched-ext), this is valid. With amd_pstate=active, performance governor pins EPP
#     to 0x0 and disables dynamic frequency scaling. Adds 20-40W idle overhead.
#     Kept: user preference for locked performance mode. CachyOS alternative would be
#     powersave governor + balance_performance EPP + game-performance %command% in Steam.

# EMBEDDED FILE CONTENTS

function get_file_content
    switch $argv[1]
        # GENERATED FROM ARRAYS (single source of truth)

        case "/boot/loader/loader.conf"
            echo "# systemd-boot loader configuration"
            echo "default $LOADER_DEFAULT"
            echo "timeout $LOADER_TIMEOUT"
            echo "console-mode $LOADER_CONSOLE_MODE"
            echo "editor $LOADER_EDITOR"

        case "/etc/environment"
            echo "# Global environment variables - read by PAM on login"
            for var in $ENV_VARS
                echo $var
            end

        case "/etc/mkinitcpio.conf"
            echo "# mkinitcpio configuration"
            echo "# Changes require: sudo mkinitcpio -P && sudo sdboot-manage update"
            echo "MODULES=("(string join -- " " $MKINITCPIO_MODULES)")"
            echo "BINARIES=()"
            echo "FILES=()"
            echo "HOOKS=("(string join -- " " $MKINITCPIO_HOOKS)")"
            echo "COMPRESSION=\"$MKINITCPIO_COMPRESSION\""

        case "/etc/modules-load.d/99-cachyos-modules.conf"
            echo "# Load modules at boot"
            for mod in $MODULES_LOAD
                echo $mod
            end

        case "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf"
            echo "# systemd-resolved configuration"
            echo "[Resolve]"
            echo "MulticastDNS=$RESOLVED_MDNS"

        case "/etc/systemd/logind.conf.d/99-cachyos-logind.conf"
            echo "# systemd-logind configuration - desktop power handling"
            echo "[Login]"
            for key in $LOGIND_IGNORE_KEYS
                echo "$key=ignore"
            end

        case "/etc/sdboot-manage.conf"
            echo "# sdboot-manage configuration"
            echo "# Changes require: sudo sdboot-manage gen && sudo sdboot-manage update"
            echo "LINUX_OPTIONS=\""(string join -- " " $KERNEL_PARAMS)"\""
            echo "LINUX_FALLBACK_OPTIONS=\"quiet\""
            echo "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\""
            echo "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\""

        case "/etc/iwd/main.conf"
            echo "# iwd configuration - minimal config for NetworkManager backend"
            echo "[General]"
            echo "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
            echo ""
            echo "[DriverQuirks]"
            for quirk in $IWD_DRIVER_QUIRKS
                echo $quirk
            end
            echo ""
            echo "[Network]"
            echo "NameResolvingService=$IWD_DNS_SERVICE"

        case "/etc/NetworkManager/conf.d/99-cachyos-nm.conf"
            echo "# NetworkManager configuration - iwd backend"
            echo "[device]"
            echo "wifi.backend=$NM_WIFI_BACKEND"
            echo ""
            echo "[connection]"
            echo "wifi.powersave=$NM_WIFI_POWERSAVE"
            echo ""
            echo "[logging]"
            echo "level=$NM_LOG_LEVEL"

        case "/etc/conf.d/wireless-regdom"
            echo "# Wireless regulatory domain"
            echo "WIRELESS_REGDOM=\"$WIRELESS_REGDOM\""

        case '*/.config/environment.d/50-gaming.conf'
            echo "# Gaming environment variables for systemd user services"
            echo "# Note: Duplicates /etc/environment for apps launched via systemd --user"
            echo "# (e.g., Flatpak apps, user services that don't inherit PAM environment)"
            for var in $ENV_VARS
                echo $var
            end

        # GENERATED FROM ARRAYS (simple line-based files)

        case "/etc/udev/rules.d/99-cachyos-udev.rules"
            echo "# udev rules"
            for rule in $UDEV_RULES
                echo $rule
            end

        case "/etc/modprobe.d/99-cachyos-modprobe.conf"
            echo "# modprobe configuration"
            for opt in $MODPROBE_OPTIONS
                echo "options $opt"
            end
            for mod in $MODPROBE_BLACKLIST
                echo "blacklist $mod"
            end

        case '*/.config/fish/conf.d/10-ssh-auth-sock.fish'
            echo '# SSH agent socket for fish shell
if status is-interactive
    if set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
    end
end'

        case "/etc/systemd/system/amdgpu-performance.service"
            echo '[Unit]
Description=Set AMDGPU power_dpm_force_performance_level to high
After=graphical.target
ConditionPathIsDirectory=/sys/class/drm

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\''shopt -s nullglob; for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do [ -f "$f" ] && [ -w "$f" ] && echo high > "$f"; done; exit 0'\''

[Install]
WantedBy=graphical.target'

        case "/etc/systemd/system/cpupower-epp.service"
            echo '[Unit]
Description=Set CPU EPP and governor to performance
After=cpupower.service
Wants=cpupower.service
ConditionPathIsDirectory=/sys/devices/system/cpu

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\''shopt -s nullglob; for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$cpu" ] && echo performance > "$cpu"; done; exit 0'\''
ExecStart=/bin/bash -c '\''shopt -s nullglob; for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$cpu" ] && echo performance > "$cpu"; done; exit 0'\''

[Install]
WantedBy=multi-user.target'

        case '*'
            return 1
    end
    return 0
end

# PACKAGE LISTS
#
# AUDIT NOTES (v3.6.0) — packages:
#   power-profiles-daemon (removed) — CachyOS ships a custom-patched ppd with integrations:
#     game-performance script, scx_loader, KDE/GNOME power switcher. On BORE kernel without
#     sched-ext, ppd's value is limited to DE power profile UI and CPB boost control.
#     Kept removed: user uses cpupower.service with performance governor instead.
#   ufw (removed) — leaves no firewall on dual 10GbE system. ice driver is now blacklisted
#     (E610 NICs disabled), so network exposure is WiFi-only behind NAT router.
#     Kept removed: acceptable risk for home desktop behind NAT. Consider firewalld if
#     E610 NICs are re-enabled after Intel NVM update.

set -g PKGS_ADD mkinitcpio-firmware nvme-cli htop iw plocate cachyos-gaming-meta cachyos-gaming-applications fd ripgrep sd dust procs
set -g PKGS_DEL power-profiles-daemon plymouth cachyos-plymouth-bootanimation ufw octopi micro cachyos-micro-settings

# SYSTEMD SERVICES TO MASK
# Masked services are completely disabled (cannot be started even manually).
# Using mask instead of disable because these should NEVER run on this system.
# Note: ananicy-cpp is masked (not removed) because cachyos-settings depends on it.
# Note: lvm2-monitor is conditionally skipped if LVM is detected on the system.
# Note: Sleep targets masked because S0ix is unreliable on Strix Halo; desktop stays powered.

set -g MASK \
    ananicy-cpp.service \
    lvm2-monitor.service \
    ModemManager.service \
    NetworkManager-wait-online.service \
    sleep.target \
    suspend.target \
    hibernate.target \
    hybrid-sleep.target \
    suspend-then-hibernate.target

# KERNEL PARAMETERS
# These are set via /etc/sdboot-manage.conf and applied at boot.
# Module-specific params (amdgpu.*, btusb.*, etc.) are ALSO set in modprobe.conf.
# This duplication is INTENTIONAL:
#   - Kernel cmdline: applies to built-in modules (compiled into kernel)
#   - modprobe.conf: applies to loadable modules (loaded later)
# Both are needed for complete coverage across different kernel configurations.
#
# AUDIT NOTES (v3.6.0) — items below were flagged but kept for precaution:
#   amd_pstate=active      — redundant (default since kernel 6.5, CachyOS ships it).
#                             Kept: explicit is safer across kernel upgrades.
#   amdgpu.modeset=1       — technically a no-op (KMS is unconditional on RDNA 3.5+).
#                             Kept: harmless, ensures early KMS on any future kernel change.
#   amdgpu.runpm=0         — no-op on iGPU-only (runtime PM is for discrete GPU D3cold).
#                             Kept: harmless, prevents issues if external GPU ever added.
#   amdgpu.gpu_recovery=1  — redundant (default is auto=-1, which enables for GFX8+).
#                             Kept: explicit guarantee of GPU hang recovery.
#   usbcore.autosuspend=-1 — broader than needed (btusb param already handles MT7925E).
#                             Kept: prevents USB dropouts on all devices, not just bluetooth.
#   split_lock_detect=off  — CachyOS recommends sysctl kernel.split_lock_mitigate=0 instead.
#                             Kept: cmdline approach is more aggressive but simpler for gaming.
#   tsc=reliable           — unnecessary on Zen 5 (auto-detects TSC reliability).
#                             Kept: harmless, avoids any clocksource fallback edge cases.
#
# NOT ADDED (documented decision):
#   ttm.pages_limit / ttm.page_pool_size — would expose ~124GB to GPU compute via unified
#   memory (128GB minus 4GB OS reserve = 32505856 pages). Required for ROCm/LLM workloads.
#   Not added: gaming-focused config, ROCm not currently in use. Add when needed:
#     ttm.pages_limit=32505856 ttm.page_pool_size=32505856
#   Also reduce ZRAM to ram/8 with vm.swappiness=10 when using large TTM.

set -g KERNEL_PARAMS \
    8250.nr_uarts=0 \
    amd_iommu=off \
    amd_pstate=active \
    amdgpu.cwsr_enable=0 \
    amdgpu.dcdebugmask=0x10 \
    amdgpu.gpu_recovery=1 \
    amdgpu.modeset=1 \
    amdgpu.ppfeaturemask=0xfffd7fff \
    amdgpu.runpm=0 \
    audit=0 \
    btusb.enable_autosuspend=n \
    mt7925e.disable_aspm=1 \
    nowatchdog \
    nvme_core.default_ps_max_latency_us=0 \
    pci=pcie_bus_perf \
    quiet \
    split_lock_detect=off \
    tsc=reliable \
    usbcore.autosuspend=-1 \
    zswap.enabled=0

# ENVIRONMENT VARIABLES
# Set in both /etc/environment (PAM login) and ~/.config/environment.d/ (systemd user).
# Duplication is intentional: /etc/environment for TTY/X11, environment.d for systemd services.
# These gaming-focused variables optimize Vulkan, shader caching, and Proton behavior.
# Note: RADV_PERFTEST=sam removed in v3.6.0 — SAM/ReBAR is a PCIe feature for discrete GPUs.
#       On iGPU with unified memory, CPU already has full memory access.
#
# AUDIT NOTES (v3.6.0):
#   MESA_SHADER_CACHE_MAX_SIZE=12G — audit suggested reducing to 2-4G (default is 1G,
#     Steam uses Fossilize DB which bypasses this). Kept at 12G: 128GB system has headroom,
#     benefits non-Steam Vulkan apps, and avoids shader recompilation stalls.

set -g ENV_VARS \
    "AMD_VULKAN_ICD=RADV" \
    "MESA_SHADER_CACHE_MAX_SIZE=12G" \
    "PROTON_USE_NTSYNC=1" \
    "PROTON_NO_WM_DECORATION=1"

# MKINITCPIO CONFIGURATION
# Hook order matters! systemd-based hooks require specific ordering.
# - 'resume' hook is OMITTED because sleep targets are masked (desktop stays on)
# - LUKS users: script will prompt to add 'sd-encrypt' before 'filesystems'
# - 'microcode' must come after 'autodetect' for CPU microcode loading
# - 'kms' enables early kernel modesetting (required for amdgpu in MODULES)

set -g MKINITCPIO_MODULES amdgpu nvme
set -g MKINITCPIO_HOOKS \
    base \
    systemd \
    autodetect \
    microcode \
    modconf \
    kms \
    keyboard \
    sd-vconsole \
    block \
    filesystems \
    fsck
set -g MKINITCPIO_COMPRESSION zstd

# LOADER CONFIGURATION (systemd-boot)
# - default=@saved: Remember last booted entry
# - timeout=0: No menu delay (hold Space during boot to show menu)
# - console-mode=keep: Don't change display resolution
# - editor=no: SECURITY - prevents editing kernel cmdline at boot (no root shell bypass)

set -g LOADER_DEFAULT "@saved"
set -g LOADER_TIMEOUT 0
set -g LOADER_CONSOLE_MODE "keep"
set -g LOADER_EDITOR "no"

# SDBOOT-MANAGE CONFIGURATION

set -g SDBOOT_OVERWRITE "yes"
set -g SDBOOT_REMOVE_OBSOLETE "yes"

# IWD CONFIGURATION
# iwd is used as the WiFi backend for NetworkManager (not standalone).
# IMPORTANT: Do NOT enable iwd.service - NetworkManager manages iwd internally.
# EnableNetworkConfiguration=false means NM handles IP config, not iwd.
# DriverQuirks work around hardware-specific issues with various WiFi chips.

set -g IWD_ENABLE_NETWORK_CONFIG "false"
set -g IWD_DRIVER_QUIRKS "DefaultInterface=*" "PowerSaveDisable=*"
set -g IWD_DNS_SERVICE "systemd"

# NETWORKMANAGER CONFIGURATION

set -g NM_WIFI_BACKEND "iwd"
set -g NM_WIFI_POWERSAVE 2
set -g NM_LOG_LEVEL "ERR"

# RESOLVED CONFIGURATION

set -g RESOLVED_MDNS "no"

# LOGIND CONFIGURATION
# All power-related actions set to 'ignore' because:
# 1. Desktop system - no need for lid/suspend behavior
# 2. Sleep targets are masked anyway
# 3. Prevents accidental shutdowns from power button
# Power off via DE menu or 'poweroff' command instead

set -g LOGIND_IGNORE_KEYS \
    HandlePowerKey \
    HandleSuspendKey \
    HandleHibernateKey

# MODULES TO LOAD AT BOOT

set -g MODULES_LOAD ntsync

# WIRELESS REGULATORY DOMAIN

set -g WIRELESS_REGDOM "US"

# UDEV RULES
# Rule 1: ntsync device permissions (0666 allows all users to use NT sync primitives)
# Rule 2: Disable USB autosuspend for all devices (prevents USB device dropouts)
# Note: AMDGPU performance level is NOT set via udev due to timing issues (Arch #72655)
#       Instead, use amdgpu-performance.service which runs after graphical.target

set -g UDEV_RULES \
    'KERNEL=="ntsync", MODE="0666"' \
    'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"'

# MODPROBE CONFIGURATION
# Options set module parameters for loadable kernel modules.
# Blacklist prevents modules from auto-loading (can still be loaded manually).
# - sp5100_tco: AMD watchdog, disabled via kernel params anyway
# - snd_acp_pci: Silences "No matching ASoC machine driver" dmesg spam
# - pcspkr/snd_pcsp: PC speaker beeps (annoying)
# - floppy: No floppy drive hardware
# - ice: Intel E610 10GbE NIC driver — confirmed cross-platform firmware lockup
#         under sustained GPU + network workloads (NVM <1.30). Both ports share a
#         single NVM image and fail simultaneously. Blacklisted until Intel releases
#         a stable NVM update. Use WiFi or USB ethernet as workaround.
#
# AUDIT NOTES (v3.6.0):
#   amdgpu modeset=1 runpm=0 — mirrors kernel cmdline flags (see kernel param audit notes).
#     Kept: modprobe options apply when amdgpu loads as a module, not built-in.
#   bluetooth disable_esco=1 — generic workaround, not specific to MT7925E bluetooth.
#     Kept: silences "HCI Enhanced Setup Synchronous Connection" dmesg noise.

set -g MODPROBE_OPTIONS \
    "amdgpu modeset=1 cwsr_enable=0 gpu_recovery=1 runpm=0 dcdebugmask=0x10" \
    "mt7925e disable_aspm=1" \
    "btusb enable_autosuspend=n" \
    "usbcore autosuspend=-1" \
    "nvme_core default_ps_max_latency_us=0" \
    "bluetooth disable_esco=1"

set -g MODPROBE_BLACKLIST sp5100_tco snd_acp_pci pcspkr snd_pcsp floppy ice

# LOGGING FUNCTIONS

# Write timestamped message to log file, handling multiline messages
function _log
    # Handle multiline messages by prefixing continuation lines
    set -l timestamp "["(date '+%Y-%m-%d %H:%M:%S')"]"
    set -l msg "$argv"
    if string match -q '*\n*' "$msg"
        # Replace newlines with newline + timestamp + continuation marker
        set msg (string replace -a '\n' "\n$timestamp   " "$msg")
    end
    echo "$timestamp $msg" >> "$LOG_FILE"
end

# Logging functions: log to file, capture for TERMINAL_LOG, print if not quiet
# Verification counters (reset by verify_* functions)
set -g VERIFY_OK 0
set -g VERIFY_FAIL 0
set -g VERIFY_WARN 0

function _ok
    _log "OK: $argv"
    # Capture terminal-style output for log
    set -a TERMINAL_LOG "[OK] $argv"
    # Increment verification counter if in verify mode
    if set -q VERIFY_MODE; and test "$VERIFY_MODE" = true
        set -g VERIFY_OK (math $VERIFY_OK + 1)
    end
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[OK] $argv"
        else
            set_color green; echo -n "[OK]"; set_color normal; echo " $argv"
        end
    end
end

function _fail
    _log "FAIL: $argv"
    set -a TERMINAL_LOG "[FAIL] $argv"
    if set -q VERIFY_MODE; and test "$VERIFY_MODE" = true
        set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
    end
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[FAIL] $argv"
        else
            set_color red; echo -n "[FAIL]"; set_color normal; echo " $argv"
        end
    end
end

function _info
    _log "INFO: $argv"
    set -a TERMINAL_LOG "[INFO] $argv"
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[INFO] $argv"
        else
            set_color blue; echo -n "[INFO]"; set_color normal; echo " $argv"
        end
    end
end

function _warn
    _log "WARN: $argv"
    set -a TERMINAL_LOG "[WARN] $argv"
    if set -q VERIFY_MODE; and test "$VERIFY_MODE" = true
        set -g VERIFY_WARN (math $VERIFY_WARN + 1)
    end
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[WARN] $argv"
        else
            set_color yellow; echo -n "[WARN]"; set_color normal; echo " $argv"
        end
    end
end

function _err
    _log "ERR: $argv"
    set -a TERMINAL_LOG "[ERR] $argv"
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[ERR] $argv" >&2
        else
            set_color red; echo -n "[ERR]"; set_color normal; echo " $argv" >&2
        end
    end
end

function _echo
    # Echo with logging, respects quiet mode
    _log "ECHO: $argv"
    set -a TERMINAL_LOG "$argv"
    if test "$QUIET" = false
        echo "$argv"
    end
end

# Print verification summary and return appropriate exit code
function _verify_summary
    _echo
    _echo "VERIFICATION SUMMARY"
    _echo

    set -l summary "Results: $VERIFY_OK OK"
    if test $VERIFY_WARN -gt 0
        set summary "$summary, $VERIFY_WARN WARN"
    end
    if test $VERIFY_FAIL -gt 0
        set summary "$summary, $VERIFY_FAIL FAIL"
    end

    if test $VERIFY_FAIL -gt 0
        _fail "$summary"
        return 1
    else if test $VERIFY_WARN -gt 0
        _warn "$summary"
        return 0
    else
        _ok "$summary"
        return 0
    end
end

# PROGRESS BAR

# Progress bar state (only shown in --all mode)
set -g PROGRESS_CURRENT 0
set -g PROGRESS_WIDTH 40
set -g PROGRESS_START_TIME 0

# Progress steps - PROGRESS_TOTAL derived from this array to prevent counting errors
set -g PROGRESS_STEPS \
    "Checking dependencies" \
    "Creating backup directory" \
    "Syncing packages" \
    "Installing packages" \
    "Installing system files" \
    "Checking disk encryption" \
    "Wireless regulatory domain" \
    "Installing user files" \
    "AMDGPU performance service" \
    "Updating databases" \
    "Session directories" \
    "Reloading system config" \
    "Removing packages" \
    "Masking services" \
    "CPU performance service" \
    "Enabling timers" \
    "Rebuilding initramfs" \
    "Updating bootloader" \
    "System upgrade" \
    "Finalizing system" \
    "NetworkManager restart" \
    "WiFi reconnection"
set -g PROGRESS_TOTAL (count $PROGRESS_STEPS)

function _progress_init
    # Initialize progress bar (only in --all unattended mode)
    if test "$ALL" = true; and test "$DRY" = false
        set -g PROGRESS_CURRENT 0
        set -g PROGRESS_START_TIME (date +%s)
        printf '\n'
    end
end

function _progress
    # Update progress bar with step description and ETA
    # Usage: _progress "Step description"
    if test "$ALL" = true; and test "$DRY" = false
        set -g PROGRESS_CURRENT (math $PROGRESS_CURRENT + 1)
        set -l pct (math "floor($PROGRESS_CURRENT * 100 / $PROGRESS_TOTAL)")
        set -l filled (math "floor($PROGRESS_CURRENT * $PROGRESS_WIDTH / $PROGRESS_TOTAL)")
        set -l empty (math "$PROGRESS_WIDTH - $filled")

        # Build progress bar string
        set -l bar ""
        for i in (seq 1 $filled)
            set bar "$bar█"
        end
        for i in (seq 1 $empty)
            set bar "$bar░"
        end

        # Calculate ETA from elapsed time and progress
        set -l eta_str ""
        if test "$PROGRESS_START_TIME" -gt 0; and test "$PROGRESS_CURRENT" -gt 1
            set -l now (date +%s)
            set -l elapsed (math "$now - $PROGRESS_START_TIME")
            set -l remaining_steps (math "$PROGRESS_TOTAL - $PROGRESS_CURRENT")
            set -l secs_per_step (math "$elapsed / ($PROGRESS_CURRENT - 1)")
            set -l eta_secs (math "ceil($remaining_steps * $secs_per_step)")
            if test "$eta_secs" -ge 60
                set -l eta_m (math "floor($eta_secs / 60)")
                set -l eta_s (math "$eta_secs % 60")
                set eta_str (printf ' ETA %dm%02ds' $eta_m $eta_s)
            else if test "$eta_secs" -gt 0
                set eta_str (printf ' ETA %ds' $eta_secs)
            end
        end

        # Pad description to fixed width (clear previous text)
        set -l desc (string sub -l 25 -- "$argv[1]                              ")

        # Print progress bar (carriage return to overwrite)
        printf '\r[%s] %3d%% %s%s' "$bar" "$pct" "$desc" "$eta_str"
    end
    _log "PROGRESS: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $argv[1]"
end

function _progress_done
    # Complete the progress bar with total elapsed time
    if test "$ALL" = true; and test "$DRY" = false
        set -g PROGRESS_CURRENT $PROGRESS_TOTAL
        set -l bar (string repeat -n $PROGRESS_WIDTH '█')
        set -l elapsed_str ""
        if test "$PROGRESS_START_TIME" -gt 0
            set -l now (date +%s)
            set -l elapsed (math "$now - $PROGRESS_START_TIME")
            if test "$elapsed" -ge 60
                set -l el_m (math "floor($elapsed / 60)")
                set -l el_s (math "$elapsed % 60")
                set elapsed_str (printf ' (%dm%02ds)' $el_m $el_s)
            else
                set elapsed_str (printf ' (%ds)' $elapsed)
            end
        end
        printf '\r[%s] 100%% Done%-20s%s\n' "$bar" "" "$elapsed_str"
    end
end

# COMMAND EXECUTION

# Execute command with logging; skip if --dry-run mode
function _run
    # Execute command arguments directly (no eval).
    # Pass commands as separate tokens: _run sudo pacman -Sy
    # For commands requiring shell parsing (pipes, redirects), use:
    #   _run fish -c 'command | pipe'
    set -l log_cmd (string join -- " " $argv)

    if string match -q '*--passphrase*' "$log_cmd"
        set log_cmd (string replace -r -- '--passphrase [^ ]+' '--passphrase [REDACTED]' "$log_cmd")
    end

    _log "RUN: $log_cmd"

    if test "$DRY" = true
        _log "DRY: (not executed)"
        if test "$QUIET" = false
            if test "$NO_COLOR" = true
                echo "[DRY] $log_cmd"
            else
                set_color cyan; echo -n "[DRY]"; set_color normal; echo " $log_cmd"
            end
        end
        return 0
    else
        set -l output ($argv 2>&1)
        set -l ret $status
        if test -n "$output"
            _log "OUTPUT: "(string join -- " | " $output)
            if test "$QUIET" = false
                printf '%s\n' $output
            end
        end
        _log "EXIT: $ret"
        return $ret
    end
end

# Prompt user for y/n; auto-yes if --all or --force mode
function _ask
    if test "$ALL" = true; or test "$FORCE" = true
        _log "ASK: $argv[1] -> auto-yes"
        return 0
    end
    read -P "[?] $argv[1] [y/N] " r
    _log "ASK: $argv[1] -> $r"
    string match -qir '^y(es)?$' "$r"
end

# VERIFICATION HELPERS

function _chk_file
    if test (count $argv) -lt 1
        _err "_chk_file: missing argument"
        return 1
    end
    _log "CHECK FILE: $argv[1]"
    # Use sudo test for /boot paths (may have restrictive permissions)
    if string match -q '/boot/*' "$argv[1]"
        if sudo test -f "$argv[1]" 2>/dev/null
            _ok "File exists: $argv[1]"
            return 0
        end
    else if test -f "$argv[1]"
        _ok "File exists: $argv[1]"
        return 0
    end
    _fail "File NOT FOUND: $argv[1]"
    return 1
end

function _chk_grep
    if test (count $argv) -lt 3
        _err "_chk_grep: requires 3 arguments (file, pattern, label)"
        return 1
    end
    _log "CHECK GREP: $argv[1] for '$argv[2]'"

    # For non-/boot paths, check readability first
    if not string match -q '/boot/*' "$argv[1]"
        if not test -r "$argv[1]"
            if test -f "$argv[1]"
                _fail "  $argv[3]: PERMISSION DENIED (need sudo?)"
                return 1
            else
                _fail "  $argv[3]: FILE NOT FOUND"
                return 1
            end
        end
    end

    # Use sudo grep for /boot paths (may have restrictive permissions)
    if string match -q '/boot/*' "$argv[1]"
        if sudo grep -q "$argv[2]" "$argv[1]" 2>/dev/null
            _ok "  $argv[3]: present"
            return 0
        else
            _fail "  $argv[3]: MISSING"
            return 1
        end
    else if grep -q "$argv[2]" "$argv[1]" 2>/dev/null
        _ok "  $argv[3]: present"
        return 0
    else
        _fail "  $argv[3]: MISSING"
        return 1
    end
end

# DEPENDENCY CHECK

function check_deps
    _log "Checking dependencies..."
    set -l missing

    for cmd in pacman systemctl mkinitcpio udevadm sysctl sdboot-manage curl
        if not command -q $cmd
            set -a missing $cmd
        end
    end

    if test (count $missing) -gt 0
        _err "Missing required commands: $missing"
        if contains sdboot-manage $missing
            _err "  sdboot-manage is required for CachyOS bootloader management"
            _err "  Install with: sudo pacman -S sdboot-manage"
        end
        return 1
    end

    # Version checks for critical features
    # systemd 250+ required for: ConditionFirmware=, improved credentials, etc.
    set -l systemd_ver (systemctl --version 2>/dev/null | head -1 | string match -r '\d+' | head -1)
    if test -n "$systemd_ver"; and test "$systemd_ver" -lt 250
        _warn "systemd version $systemd_ver detected; some features require 250+"
    end

    _log "All dependencies satisfied"
    return 0
end

# Check network connectivity before package operations
function check_network
    _log "Checking network connectivity..."

    # Try to reach archlinux.org (pacman mirror check)
    if curl -sf --max-time 5 --head https://archlinux.org >/dev/null 2>&1
        _ok "Network connectivity: OK"
        return 0
    end

    # Fallback: try ping
    if ping -c 1 -W 3 archlinux.org >/dev/null 2>&1
        _ok "Network connectivity: OK (ping)"
        return 0
    end

    _err "Network connectivity: FAILED"
    _err "  Cannot reach archlinux.org - check your network connection"
    _err "  Package installation requires internet access"
    return 1
end

# Check available disk space before operations
function check_disk_space
    _log "Checking disk space..."

    # Check root filesystem (need ~2GB for packages/initramfs)
    set -l root_avail (df -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
    if test -n "$root_avail"; and string match -qr '^\d+$' "$root_avail"
        if test "$root_avail" -lt 2
            _err "Insufficient disk space on /: $root_avail""GB available, need 2GB minimum"
            return 1
        else if test "$root_avail" -lt 5
            _warn "Low disk space on /: $root_avail""GB available"
        else
            _ok "Disk space on /: $root_avail""GB available"
        end
    end

    # Check /boot (need ~500MB for kernels/initramfs)
    set -l boot_avail (df -BM /boot 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'M')
    if test -n "$boot_avail"; and string match -qr '^\d+$' "$boot_avail"
        if test "$boot_avail" -lt 200
            _err "Insufficient disk space on /boot: $boot_avail""MB available, need 200MB minimum"
            return 1
        else if test "$boot_avail" -lt 500
            _warn "Low disk space on /boot: $boot_avail""MB available"
        else
            _ok "Disk space on /boot: $boot_avail""MB available"
        end
    end

    return 0
end

# Check kernel version for feature compatibility
function check_kernel_version
    set -l kver (uname -r)
    set -l major (echo $kver | cut -d. -f1)
    # Extract numeric part only from minor (handles "14-rc1" -> "14")
    set -l minor_raw (echo $kver | cut -d. -f2)
    set -l minor (string replace -r '[^0-9].*' '' "$minor_raw")

    # Validate we got numbers
    if not string match -qr '^\d+$' "$major"
        set major 0
    end
    if test -z "$minor"; or not string match -qr '^\d+$' "$minor"
        set minor 0
    end

    _info "Kernel version: $kver"

    # ntsync requires kernel 6.14+
    if test "$major" -lt 6; or test "$major" -eq 6 -a "$minor" -lt 14
        _warn "Kernel $kver < 6.14: ntsync will NOT be available"
        _warn "  Upgrade kernel for PROTON_USE_NTSYNC=1 support"
        set -g NTSYNC_SUPPORTED false
    else
        set -g NTSYNC_SUPPORTED true
    end

    return 0
end

# Check Secure Boot status
function check_secure_boot
    if command -q mokutil
        set -l sb_state (mokutil --sb-state 2>/dev/null)
        if string match -q "*SecureBoot enabled*" "$sb_state"
            _info "Secure Boot: enabled"
        else if string match -q "*SecureBoot disabled*" "$sb_state"
            _info "Secure Boot: disabled"
        else
            _info "Secure Boot: unknown"
        end
    else
        # Fallback: check EFI variable directly
        if test -f /sys/firmware/efi/efivars/SecureBoot-*
            _info "Secure Boot: EFI system detected"
        end
    end
    return 0
end

# Show BIOS version info (useful for Strix Halo troubleshooting)
function show_bios_info
    if command -q dmidecode
        set -l bios_ver (sudo dmidecode -s bios-version 2>/dev/null)
        set -l bios_date (sudo dmidecode -s bios-release-date 2>/dev/null)
        if test -n "$bios_ver"
            _info "BIOS: $bios_ver ($bios_date)"
        end
    end
    return 0
end

# Check for sched-ext schedulers (incompatible with BORE kernel)
function check_sched_ext
    # sched-ext: not compatible with BORE kernel (see do_diagnose for detailed check)
    if systemctl is-active --quiet scx_loader.service 2>/dev/null
        _warn "sched-ext: scx_loader.service is active (not compatible with BORE kernel)"
        _info "  Disable with: sudo systemctl disable --now scx_loader.service"
    else
        for scx_svc in scx_lavd scx_bpfland scx_rusty scx_rustland
            if pgrep -x "$scx_svc" >/dev/null 2>&1
                _warn "sched-ext: $scx_svc is running (not compatible with BORE kernel)"
            end
        end
    end
end

# SYNTAX VALIDATION FUNCTIONS

# Validate mkinitcpio hooks exist
function validate_mkinitcpio_hooks
    for hook in $MKINITCPIO_HOOKS
        if not test -f "/usr/lib/initcpio/install/$hook"
            if not test -f "/usr/lib/initcpio/hooks/$hook"
                _err "Invalid mkinitcpio hook: $hook"
                return 1
            end
        end
    end
    return 0
end

# Validate mkinitcpio modules are loadable
function validate_mkinitcpio_modules
    for mod in $MKINITCPIO_MODULES
        if not modprobe -n "$mod" 2>/dev/null
            _warn "Module may not exist: $mod (continuing anyway)"
        end
    end
    return 0
end

# Validate systemd unit file syntax
# Usage: validate_systemd_unit /path/to/tmpfile unit_name
function validate_systemd_unit
    set -l tmpfile $argv[1]
    set -l unit_name $argv[2]

    if command -q systemd-analyze
        if not systemd-analyze verify "$tmpfile" 2>/dev/null
            _err "Invalid systemd unit syntax: $unit_name"
            return 1
        end
    end

    return 0
end

# Validate modprobe options (module names)
function validate_modprobe_options
    for opt in $MODPROBE_OPTIONS
        set -l mod (string split ' ' "$opt")[1]
        if not modprobe -n "$mod" 2>/dev/null
            _warn "Module may not exist: $mod (continuing anyway)"
        end
    end
    return 0
end

# Validate modprobe blacklist entries
function validate_modprobe_blacklist
    for mod in $MODPROBE_BLACKLIST
        # Just check it's a valid module name format (no spaces, reasonable chars)
        if not string match -qr '^[a-zA-Z0-9_-]+$' "$mod"
            _err "Invalid module name in blacklist: $mod"
            return 1
        end
    end
    return 0
end

# Validate fish script syntax
# Usage: validate_fish_script /path/to/tmpfile script_name
function validate_fish_script
    set -l tmpfile $argv[1]
    set -l script_name $argv[2]

    if not fish --no-execute "$tmpfile" 2>/dev/null
        _err "Invalid fish syntax: $script_name"
        return 1
    end

    return 0
end

# Run all pre-install validations
function validate_configs
    _info "Validating configuration syntax..."

    set -l errors 0

    # Validate mkinitcpio
    if not validate_mkinitcpio_hooks
        set errors (math $errors + 1)
    end
    validate_mkinitcpio_modules

    # Validate modprobe
    if not validate_modprobe_blacklist
        set errors (math $errors + 1)
    end
    validate_modprobe_options

    # Validate systemd units (write content to temp files to preserve newlines)
    set -l tmpfile_amdgpu (mktemp --suffix=.service)
    if test -z "$tmpfile_amdgpu"
        _err "Failed to create temp file for amdgpu-performance.service validation"
        set errors (math $errors + 1)
    else
        get_file_content "/etc/systemd/system/amdgpu-performance.service" > "$tmpfile_amdgpu"
        if not validate_systemd_unit "$tmpfile_amdgpu" "amdgpu-performance.service"
            set errors (math $errors + 1)
        end
        rm -f "$tmpfile_amdgpu"
    end

    set -l tmpfile_cpupower (mktemp --suffix=.service)
    if test -z "$tmpfile_cpupower"
        _err "Failed to create temp file for cpupower-epp.service validation"
        set errors (math $errors + 1)
    else
        get_file_content "/etc/systemd/system/cpupower-epp.service" > "$tmpfile_cpupower"
        if not validate_systemd_unit "$tmpfile_cpupower" "cpupower-epp.service"
            set errors (math $errors + 1)
        end
        rm -f "$tmpfile_cpupower"
    end

    # Validate fish script (write content to temp file to preserve newlines)
    set -l tmpfile_fish (mktemp --suffix=.fish)
    if test -z "$tmpfile_fish"
        _err "Failed to create temp file for fish script validation"
        set errors (math $errors + 1)
    else
        get_file_content "*/.config/fish/conf.d/10-ssh-auth-sock.fish" > "$tmpfile_fish"
        if not validate_fish_script "$tmpfile_fish" "ssh-auth-sock.fish"
            set errors (math $errors + 1)
        end
        rm -f "$tmpfile_fish"
    end

    if test $errors -gt 0
        _err "Validation failed with $errors error(s)"
        return 1
    end

    _ok "All configurations validated"
    return 0
end

# BACKUP FUNCTIONS

function backup_file
    set -l dst $argv[1]
    set -l use_sudo $argv[2]

    if not test -f "$dst"
        return 0
    end

    set -l bp
    if string match -q "$HOME/*" "$dst"
        set bp "$BACKUP_DIR/home/"(string replace "$HOME/" "" "$dst")
    else if string match -q "/boot/*" "$dst"
        set bp "$BACKUP_DIR/boot/"(string replace "/boot/" "" "$dst")
    else if string match -q "/etc/*" "$dst"
        set bp "$BACKUP_DIR/etc/"(string replace "/etc/" "" "$dst")
    else
        # Handle paths outside expected locations - preserve directory structure
        _warn "Backup: unexpected path $dst - using fallback location"
        set bp "$BACKUP_DIR/other"(dirname "$dst")/(basename "$dst")
    end

    _log "BACKUP: $dst -> $bp"

    if test "$DRY" = true
        _log "DRY: backup $dst"
        if test "$QUIET" = false
            if test "$NO_COLOR" = true
                echo "[DRY] backup $dst"
            else
                set_color cyan; echo "[DRY] backup $dst"; set_color normal
            end
        end
        return 0
    end

    if not mkdir -p (dirname "$bp")
        _err "Failed to create backup directory: "(dirname "$bp")
        return 1
    end

    if test "$use_sudo" = true
        if not sudo cp "$dst" "$bp"
            _err "Failed to backup: $dst"
            return 1
        end
    else
        if not cp "$dst" "$bp"
            _err "Failed to backup: $dst"
            return 1
        end
    end

    return 0
end

# FILE INSTALLATION

# Install embedded config file to destination with backup
function install_file
    set -l dst $argv[1]
    set -l use_sudo $argv[2]

    # Skip iwd-dependent files if iwd not installed
    if string match -q '*nm.conf' "$dst"; or string match -q '*/iwd/*' "$dst"
        if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
            _warn "Skipping $dst: iwd package not installed"
            return 0
        end
    end

    # Skip ntsync modules-load.d if kernel lacks support
    if string match -q '*/modules-load.d/*' "$dst"
        if set -q NTSYNC_SUPPORTED; and test "$NTSYNC_SUPPORTED" = false
            _warn "Skipping $dst: kernel < 6.14 (ntsync not supported)"
            return 0
        end
    end

    # Get content for this file
    set -l content (get_file_content "$dst")
    if test $status -ne 0
        _err "No content defined for: $dst"
        return 1
    end

    # Create destination directory
    set -l dir (dirname "$dst")
    if test "$use_sudo" = true
        if not _run sudo mkdir -p $dir
            _fail "Cannot create directory: $dir"
            return 1
        end
    else
        if not _run mkdir -p $dir
            _fail "Cannot create directory: $dir"
            return 1
        end
    end

    # Backup existing file
    if not backup_file "$dst" "$use_sudo"
        _warn "Backup failed for $dst - continuing anyway"
    end

    # Remove existing file and write new content atomically
    if test "$DRY" = true
        _log "DRY: rm -f $dst; write content to $dst; chmod 0644 $dst"
        if test "$QUIET" = false
            if test "$NO_COLOR" = true
                echo "[DRY] rm -f $dst"
                echo "[DRY] write content to $dst"
                echo "[DRY] chmod 0644 $dst"
            else
                set_color cyan; echo "[DRY] rm -f $dst"; set_color normal
                set_color cyan; echo "[DRY] write content to $dst"; set_color normal
                set_color cyan; echo "[DRY] chmod 0644 $dst"; set_color normal
            end
        end
        _ok "(dry-run) → $dst"
        return 0
    end

    if test "$use_sudo" = true
        set -l dst_dir (dirname "$dst")
        set -l tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX)
        if test -z "$tmpfile"
            _fail "→ $dst (mktemp failed)"
            return 1
        end
        if not printf '%s\n' $content | sudo tee "$tmpfile" >/dev/null
            sudo rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (write to temp failed)"
            return 1
        end
        sudo chmod 0644 "$tmpfile"
        if not sudo mv "$tmpfile" "$dst"
            sudo rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
        # Ensure ownership is root:root for system files
        if not sudo chown root:root "$dst"
            _warn "→ $dst (chown failed, check ownership)"
        else
            _ok "→ $dst"
        end
    else
        set -l tmpfile (mktemp -p (dirname "$dst") .ry-install.XXXXXX)
        if test -z "$tmpfile"
            _fail "→ $dst (mktemp failed)"
            return 1
        end
        printf '%s\n' $content > "$tmpfile"
        if test $status -ne 0
            rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (write to temp failed)"
            return 1
        end
        # Set correct permissions for user files
        chmod 0644 "$tmpfile"
        if not mv "$tmpfile" "$dst"
            rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
        _ok "→ $dst"
    end

    return 0
end

# Unified file installation function
# Usage: install_files $destinations $use_sudo $description
function install_files
    if test (count $argv) -lt 3
        _err "install_files: expected destinations... use_sudo desc (got $argv)"
        return 1
    end
    set -l destinations $argv[1..-3]
    set -l use_sudo $argv[-2]
    set -l desc $argv[-1]

    _log "INSTALL $desc"
    for dst in $destinations
        if not install_file "$dst" $use_sudo
            _err "Failed to install: $dst"
            return 1
        end
    end
    return 0
end

# DIFF FUNCTION

function do_diff
    _log "=== DIFF START ==="
    _info "Comparing embedded files against system..."
    _echo

    set -l has_diff false

    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l content (get_file_content "$dst")
        if test $status -ne 0
            continue
        end

        # Check file existence (use sudo for system paths that may be restricted)
        set -l file_exists false
        if string match -q "$HOME/*" "$dst"
            test -f "$dst"; and set file_exists true
        else
            sudo test -f "$dst" 2>/dev/null; and set file_exists true
        end

        if test "$file_exists" = true
            set -l tmp (mktemp)
            set -l tmp_installed (mktemp)
            if test -z "$tmp"; or test -z "$tmp_installed"
                _warn "Failed to create temp files for diff: $dst"
                rm -f "$tmp" "$tmp_installed" 2>/dev/null
                continue
            end
            printf '%s\n' $content > "$tmp"
            # Use sudo cat for system paths to handle restrictive permissions
            if string match -q "$HOME/*" "$dst"
                cat "$dst" > "$tmp_installed" 2>/dev/null
            else
                sudo cat "$dst" > "$tmp_installed" 2>/dev/null
            end
            if not diff -q "$tmp" "$tmp_installed" >/dev/null 2>&1
                set has_diff true
                _warn "DIFFERS: $dst"
                # Show colored output to terminal only if color is enabled
                if test "$NO_COLOR" = true
                    diff "$tmp" "$tmp_installed"
                else
                    diff --color=auto "$tmp" "$tmp_installed"
                end
                # Log without ANSI codes
                diff "$tmp" "$tmp_installed" >> "$LOG_FILE"
                _echo
            end
            rm -f "$tmp" "$tmp_installed" 2>/dev/null
        else
            set has_diff true
            _fail "NOT INSTALLED: $dst"
        end
    end

    if test "$has_diff" = false
        _ok "All files match system!"
    end

    _log "=== DIFF END ==="
end

# STATIC VERIFICATION

# Verify config files exist and contain expected values (no reboot required)
function verify_static
    _log "=== STATIC VERIFICATION START ==="

    # Pre-acquire sudo for /boot paths and system file checks
    if not sudo true 2>/dev/null
        _err "sudo required for verification"
        return 1
    end

    # Reset verification counters
    set -g VERIFY_MODE true
    set -g VERIFY_OK 0
    set -g VERIFY_FAIL 0
    set -g VERIFY_WARN 0

    _info "Static verification (config files)..."
    _echo

    _echo "BOOT CONFIGURATION"
    _echo

    _echo "── mkinitcpio.conf ──"
    if _chk_file /etc/mkinitcpio.conf
        # Use grep -E to match only uncommented lines
        set -l m (grep -E '^[[:space:]]*MODULES=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -1)
        _echo "  Config: $m"

        if string match -q '*amdgpu*' "$m"
            _ok "  amdgpu: present (early KMS)"
        else
            _fail "  amdgpu: MISSING"
        end

        for mod in $MKINITCPIO_MODULES
            if test "$mod" = "amdgpu"
                continue  # Already checked above with special message
            end
            if string match -q "*$mod*" "$m"
                _ok "  $mod: present"
            else
                _fail "  $mod: MISSING"
            end
        end

        set -l h (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -1)
        _echo "  Config: $h"

        for hook in $MKINITCPIO_HOOKS
            if string match -q "*$hook*" "$h"
                _ok "  $hook: present"
            else
                _fail "  $hook: MISSING"
            end
        end

        set -l c (grep -E '^[[:space:]]*COMPRESSION=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -1)
        if string match -q '*zstd*' "$c"
            _ok "  COMPRESSION=zstd: present"
        else
            _fail "  COMPRESSION=zstd: MISSING"
        end

        # Check sd-encrypt hook on LUKS systems (added dynamically, not in MKINITCPIO_HOOKS array)
        set -l has_luks false
        if lsblk -o FSTYPE 2>/dev/null | grep -q 'crypto_LUKS'
            set has_luks true
        else if test -f /etc/crypttab; and grep -qE '^[^#[:space:]]' /etc/crypttab 2>/dev/null
            set has_luks true
        end
        if test "$has_luks" = true
            if string match -q '*sd-encrypt*' "$h"
                _ok "  sd-encrypt: present (LUKS system)"
            else
                _fail "  sd-encrypt: MISSING (LUKS detected — system may not boot!)"
            end
        end
    end
    _echo

    _echo "── sdboot-manage.conf ──"
    if _chk_file /etc/sdboot-manage.conf
        set -l opts (grep '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null)

        for param in $KERNEL_PARAMS
            if string match -q "*$param*" "$opts"
                _ok "  $param: present"
            else
                _fail "  $param: MISSING"
            end
        end

        _chk_grep /etc/sdboot-manage.conf "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\"" "OVERWRITE_EXISTING=$SDBOOT_OVERWRITE"
        _chk_grep /etc/sdboot-manage.conf "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\"" "REMOVE_OBSOLETE=$SDBOOT_REMOVE_OBSOLETE"
    end
    _echo

    _echo "── loader.conf ──"
    if _chk_file /boot/loader/loader.conf
        _chk_grep /boot/loader/loader.conf "default $LOADER_DEFAULT" "default $LOADER_DEFAULT"
        _chk_grep /boot/loader/loader.conf "timeout $LOADER_TIMEOUT" "timeout $LOADER_TIMEOUT"
        _chk_grep /boot/loader/loader.conf "console-mode $LOADER_CONSOLE_MODE" "console-mode $LOADER_CONSOLE_MODE"
        _chk_grep /boot/loader/loader.conf "editor $LOADER_EDITOR" "editor $LOADER_EDITOR"
    end

    _echo "── Boot entries ──"
    set -l entry_count 0
    if sudo test -d /boot/loader/entries 2>/dev/null
        set entry_count (sudo find /boot/loader/entries -name "*.conf" 2>/dev/null | wc -l | string trim)
    end
    if test -n "$entry_count"; and string match -qr '^\d+$' "$entry_count"; and test "$entry_count" -gt 0
        _ok "  Boot entries: $entry_count found"
    else
        _fail "  Boot entries: NONE in /boot/loader/entries/"
        _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    end
    _echo

    _echo "SYSTEM CONFIGURATION"
    _echo

    _echo "── Environment ──"
    if _chk_file /etc/environment
        for exp in $ENV_VARS
            set -l n (string split '=' "$exp")[1]
            _chk_grep /etc/environment "$n=" "$n"
        end
    end
    _echo

    _echo "── Modprobe ──"
    if _chk_file /etc/modprobe.d/99-cachyos-modprobe.conf
        for opt in $MODPROBE_OPTIONS
            set -l mod (string split ' ' $opt)[1]
            _chk_grep /etc/modprobe.d/99-cachyos-modprobe.conf "options $opt" "$mod options"
        end
        for mod in $MODPROBE_BLACKLIST
            _chk_grep /etc/modprobe.d/99-cachyos-modprobe.conf "blacklist $mod" "$mod blacklist"
        end
    end
    _echo

    _echo "── logind.conf ──"
    if _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf
        for key in $LOGIND_IGNORE_KEYS
            _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
        end
    end
    _echo

    _echo "── Modules load ──"
    if _chk_file /etc/modules-load.d/99-cachyos-modules.conf
        for mod in $MODULES_LOAD
            _chk_grep /etc/modules-load.d/99-cachyos-modules.conf "$mod" "$mod module"
        end
    end
    _echo

    _echo "── Udev rules ──"
    if _chk_file /etc/udev/rules.d/99-cachyos-udev.rules
        _chk_grep /etc/udev/rules.d/99-cachyos-udev.rules "ntsync" "ntsync rule"
        _chk_grep /etc/udev/rules.d/99-cachyos-udev.rules 'SUBSYSTEM=="usb"' "USB autosuspend rule"
    end
    _echo

    _echo "── NetworkManager ──"
    if _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
    end
    _echo

    _echo "── iwd ──"
    if _chk_file /etc/iwd/main.conf
        _chk_grep /etc/iwd/main.conf "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
        for quirk in $IWD_DRIVER_QUIRKS
            set -l key (string split '=' $quirk)[1]
            _chk_grep /etc/iwd/main.conf "$key" "DriverQuirks $key"
        end
        _chk_grep /etc/iwd/main.conf "NameResolvingService=$IWD_DNS_SERVICE" "DNS via $IWD_DNS_SERVICE"
    end
    _echo

    _echo "── resolved ──"
    if _chk_file /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "MulticastDNS=$RESOLVED_MDNS" "MulticastDNS=$RESOLVED_MDNS"
    end
    _echo

    _echo "── Wireless regulatory domain ──"
    if _chk_file /etc/conf.d/wireless-regdom
        # Read actual value from file (don't use hardcoded WIRELESS_REGDOM global)
        set -l actual_regdom (grep -E '^[[:space:]]*WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null | grep -v '^#' | cut -d'"' -f2 | head -1)
        if test -n "$actual_regdom"
            _ok "WIRELESS_REGDOM=$actual_regdom"
        else
            _fail "WIRELESS_REGDOM: not set (no uncommented WIRELESS_REGDOM= line)"
        end
    end
    _echo

    _echo "USER CONFIGURATION"
    _echo

    _echo "── SSH agent ──"
    if _chk_file "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"
        _chk_grep "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" "SSH_AUTH_SOCK" "SSH_AUTH_SOCK configured"
    end
    _echo

    _echo "── environment.d ──"
    if _chk_file "$HOME/.config/environment.d/50-gaming.conf"
        for exp in $ENV_VARS
            set -l n (string split '=' "$exp")[1]
            _chk_grep "$HOME/.config/environment.d/50-gaming.conf" "$n=" "$n"
        end
    end
    _echo

    _echo "PACKAGES"
    _echo

    _echo "── Required packages ──"
    if command -q pacman
        for pkg in $PKGS_ADD
            if pacman -Qi "$pkg" >/dev/null 2>&1
                _ok "  $pkg: installed"
            else
                _fail "  $pkg: NOT INSTALLED"
            end
        end
    else
        _warn "  pacman not found, skipping package verification"
    end
    _echo

    _echo "── Removed packages ──"
    if command -q pacman
        for pkg in $PKGS_DEL
            if pacman -Qi "$pkg" >/dev/null 2>&1
                _warn "  $pkg: still installed (should be removed)"
            else
                _ok "  $pkg: not installed"
            end
        end
    end
    _echo

    _echo "SERVICES"
    _echo

    _echo "── Service files ──"
    for svc_file in $SERVICE_DESTINATIONS
        _chk_file "$svc_file"
    end
    # Verify service content
    if test -f /etc/systemd/system/amdgpu-performance.service
        _chk_grep /etc/systemd/system/amdgpu-performance.service "power_dpm_force_performance_level" "amdgpu-performance ExecStart"
        _chk_grep /etc/systemd/system/amdgpu-performance.service "WantedBy=graphical.target" "amdgpu-performance WantedBy"
    end
    if test -f /etc/systemd/system/cpupower-epp.service
        _chk_grep /etc/systemd/system/cpupower-epp.service "energy_performance_preference" "cpupower-epp EPP ExecStart"
        _chk_grep /etc/systemd/system/cpupower-epp.service "scaling_governor" "cpupower-epp governor ExecStart"
        _chk_grep /etc/systemd/system/cpupower-epp.service "WantedBy=multi-user.target" "cpupower-epp WantedBy"
    end
    _echo

    _echo "── Masked services ──"
    for svc in $MASK
        # Check if service unit exists before querying state
        if not systemctl cat "$svc" >/dev/null 2>&1
            _info "  $svc: unit not found (may not be installed)"
            continue
        end
        set -l state (systemctl is-enabled "$svc" 2>/dev/null)
        if test "$state" = masked
            _ok "  $svc: masked"
        else
            _fail "  $svc: $state (expected: masked)"
        end
    end
    _echo

    _echo "SYNTAX VALIDATION"
    _echo

    # Validate mkinitcpio hooks exist
    _echo "── mkinitcpio hooks ──"
    set -l hooks_line (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^#' | head -1)
    if test -n "$hooks_line"
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' "$hooks_line")
        for hook in (string split ' ' "$hooks_str")
            if test -z "$hook"
                continue
            end
            if test -f "/usr/lib/initcpio/install/$hook"; or test -f "/usr/lib/initcpio/hooks/$hook"
                _ok "  $hook: exists"
            else
                _fail "  $hook: NOT FOUND"
            end
        end
    else
        _warn "  Could not parse HOOKS from mkinitcpio.conf"
    end
    _echo

    # Validate systemd unit syntax
    _echo "── systemd units ──"
    if command -q systemd-analyze
        for unit in /etc/systemd/system/amdgpu-performance.service /etc/systemd/system/cpupower-epp.service
            if test -f "$unit"
                if systemd-analyze verify "$unit" 2>/dev/null
                    _ok "  "(basename $unit)": syntax OK"
                else
                    _fail "  "(basename $unit)": INVALID SYNTAX"
                end
            end
        end
    else
        _warn "  systemd-analyze not available, skipping unit validation"
    end
    _echo

    # Validate fish script syntax
    _echo "── fish scripts ──"
    set -l fish_script "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"
    if test -f "$fish_script"
        if fish --no-execute "$fish_script" 2>/dev/null
            _ok "  ssh-auth-sock.fish: syntax OK"
        else
            _fail "  ssh-auth-sock.fish: INVALID SYNTAX"
        end
    end
    _echo

    # Checksum verification: compare embedded content against installed files
    _echo "CHECKSUM VERIFICATION"
    _echo
    _echo "── embedded vs installed ──"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l content (get_file_content "$dst" 2>/dev/null)
        if test $status -ne 0; or test -z "$content"
            continue
        end
        # Read installed file (use sudo for system paths)
        set -l installed
        if string match -q "$HOME/*" "$dst"
            if test -f "$dst"
                set installed (cat "$dst" 2>/dev/null)
            end
        else
            if sudo test -f "$dst" 2>/dev/null
                set installed (sudo cat "$dst" 2>/dev/null)
            end
        end
        if test -z "$installed"
            # Already reported as NOT INSTALLED by earlier checks
            continue
        end
        # Compare checksums
        set -l expected_hash (printf '%s\n' $content | sha256sum | awk '{print $1}')
        set -l actual_hash (printf '%s\n' $installed | sha256sum | awk '{print $1}')
        if test "$expected_hash" = "$actual_hash"
            _ok "  $dst: checksum match"
        else
            _fail "  $dst: checksum MISMATCH"
        end
    end
    _echo

    _log "=== STATIC VERIFICATION END ==="

    # Print summary and return exit code
    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

# RUNTIME VERIFICATION

# Verify live system state: kernel params, services, modules (run after reboot)
function verify_runtime
    _log "=== RUNTIME VERIFICATION START ==="

    # Pre-acquire sudo for sysfs/module checks (skips if already cached)
    if not sudo true 2>/dev/null
        _err "sudo required for verification"
        return 1
    end

    # Reset verification counters
    set -g VERIFY_MODE true
    set -g VERIFY_OK 0
    set -g VERIFY_FAIL 0
    set -g VERIFY_WARN 0

    _info "Runtime verification (live system state)..."
    _echo

    _echo "KERNEL CMDLINE"
    _echo

    set -l cmdline (cat /proc/cmdline 2>/dev/null)
    for param in $KERNEL_PARAMS
        if string match -q "*$param*" "$cmdline"
            _ok "  $param: active"
        else
            _fail "  $param: NOT in cmdline"
        end
    end
    _echo

    _echo "HARDWARE STATE"
    _echo

    _echo "── GPU performance level ──"
    set -l gpu_ok false
    set -l found_gpu false
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set found_gpu true
            set -l level (cat "$f" 2>/dev/null)
            if test "$level" = high
                _ok "  $f: $level"
                set gpu_ok true
            else
                _fail "  $f: $level (expected: high)"
            end
        end
    end

    if test "$found_gpu" = false
        _warn "  No GPU DPM sysfs entries found"
    else if test "$gpu_ok" = false
        _warn "  GPU not at 'high' - enable amdgpu-performance.service"
    end
    _echo

    _echo "── ReBAR/SAM status ──"
    # Check for Resizable BAR / Smart Access Memory
    set -l rebar_status (dmesg 2>/dev/null | grep -i 'BAR' | grep -i -E 'resize|rebar|large|above.4g' | head -1)
    if test -n "$rebar_status"
        if string match -qi '*enabled*' "$rebar_status"; or string match -qi '*resiz*' "$rebar_status"
            _ok "  ReBAR/SAM: enabled"
            _info "  $rebar_status"
        else
            _info "  ReBAR/SAM: check manually"
            _info "  $rebar_status"
        end
    else
        # Alternative check via lspci
        if command -q lspci
            set -l bar_size (lspci -vvv 2>/dev/null | grep -i 'Region.*Memory.*256M\|Region.*Memory.*512M\|Region.*Memory.*[0-9]G' | head -1)
            if test -n "$bar_size"
                _ok "  ReBAR/SAM: large BAR detected"
                _info "  $bar_size"
            else
                _warn "  ReBAR/SAM: not detected (check BIOS settings)"
                _info "  Verify with: dmesg | grep -i bar"
            end
        else
            _info "  lspci not available for ReBAR check"
        end
    end
    _echo

    _echo "── CPU performance ──"
    # Find first online CPU with cpufreq support
    set -l cpu_path ""
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq
        if test -d "$cpu_dir"
            set cpu_path "$cpu_dir"
            break
        end
    end

    if test -z "$cpu_path"
        _warn "  No CPU frequency scaling found"
    else
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' "$cpu_path")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:amd-pstate-epp:Scaling driver" \
                     "scaling_governor:performance:Governor" \
                     "energy_performance_preference:performance:EPP"
            set -l c (string split ':' "$check")
            set -l v (cat "$cpu_path/$c[1]" 2>/dev/null)

            if test "$v" = "$c[2]"
                _ok "  $c[3]: $v"
            else
                _fail "  $c[3]: $v (expected: $c[2])"
            end
        end
    end
    _echo

    _echo "MODULE STATE"
    _echo

    _echo "── Module parameters ──"
    if test -f /sys/module/btusb/parameters/enable_autosuspend
        set -l v (cat /sys/module/btusb/parameters/enable_autosuspend 2>/dev/null)
        if test "$v" = "N"
            _ok "  btusb.enable_autosuspend: $v"
        else
            _fail "  btusb.enable_autosuspend: $v (expected: N)"
        end
    else
        _info "  btusb: module not loaded"
    end

    if test -f /sys/module/usbcore/parameters/autosuspend
        set -l v (cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
        if test "$v" = "-1"
            _ok "  usbcore.autosuspend: $v"
        else
            _fail "  usbcore.autosuspend: $v (expected: -1)"
        end
    end

    if test -f /sys/module/nvme_core/parameters/default_ps_max_latency_us
        set -l v (cat /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null)
        if test "$v" = "0"
            _ok "  nvme_core.default_ps_max_latency_us: $v"
        else
            _fail "  nvme_core.default_ps_max_latency_us: $v (expected: 0)"
        end
    end

    if test -d /sys/module/amdgpu/parameters
        for pair in "modeset:1" "cwsr_enable:0" "gpu_recovery:1" "runpm:0" "ppfeaturemask:0xfffd7fff" "dcdebugmask:0x10"
            set -l pname (string split ':' "$pair")[1]
            set -l expected (string split ':' "$pair")[2]
            set -l ppath /sys/module/amdgpu/parameters/$pname
            if test -f "$ppath"
                set -l v (cat "$ppath" 2>/dev/null | string trim)
                # Normalize: sysfs may output decimal while expected is hex (or vice versa)
                # Convert both to decimal for comparison
                set -l v_dec "$v"
                set -l expected_dec "$expected"
                if string match -q '0x*' "$v"
                    set v_dec (printf '%d' "$v" 2>/dev/null; or echo "$v")
                end
                if string match -q '0x*' "$expected"
                    set expected_dec (printf '%d' "$expected" 2>/dev/null; or echo "$expected")
                end
                if test "$v_dec" = "$expected_dec"
                    _ok "  amdgpu.$pname: $v"
                else
                    _fail "  amdgpu.$pname: $v (expected: $expected)"
                end
            end
        end
    end

    if test -f /sys/module/mt7925e/parameters/disable_aspm
        set -l v (cat /sys/module/mt7925e/parameters/disable_aspm 2>/dev/null)
        if test "$v" = "Y"; or test "$v" = "1"
            _ok "  mt7925e.disable_aspm: $v"
        else
            _fail "  mt7925e.disable_aspm: $v (expected: 1/Y)"
        end
    else if test -d /sys/module/mt7925e
        _info "  mt7925e: loaded but disable_aspm param not found"
    end
    _echo

    _echo "SERVICE STATE"
    _echo

    set -l gpu_svc_state (systemctl is-active amdgpu-performance.service 2>/dev/null)
    set -l gpu_svc_enabled (systemctl is-enabled amdgpu-performance.service 2>/dev/null)
    if test "$gpu_svc_state" = active; or test "$gpu_svc_state" = exited
        if test "$gpu_svc_enabled" = enabled
            _ok "  amdgpu-performance.service: $gpu_svc_state (enabled)"
        else
            _warn "  amdgpu-performance.service: $gpu_svc_state but $gpu_svc_enabled (won't persist)"
        end
    else if test -f /etc/systemd/system/amdgpu-performance.service
        _fail "  amdgpu-performance.service: $gpu_svc_state (expected: active)"
    else
        _warn "  amdgpu-performance.service: not installed"
    end

    set -l epp_state (systemctl is-active cpupower-epp.service 2>/dev/null)
    set -l epp_enabled (systemctl is-enabled cpupower-epp.service 2>/dev/null)
    if test "$epp_state" = active; or test "$epp_state" = exited
        if test "$epp_enabled" = enabled
            _ok "  cpupower-epp.service: $epp_state (enabled)"
        else
            _warn "  cpupower-epp.service: $epp_state but $epp_enabled (won't persist)"
        end
    else if test -f /etc/systemd/system/cpupower-epp.service
        _fail "  cpupower-epp.service: $epp_state (expected: active)"
    else
        _warn "  cpupower-epp.service: not installed"
    end

    set -l fstrim_active (systemctl is-active fstrim.timer 2>/dev/null)
    set -l fstrim_enabled (systemctl is-enabled fstrim.timer 2>/dev/null)
    if test "$fstrim_active" = active
        if test "$fstrim_enabled" = enabled
            _ok "  fstrim.timer: active (enabled)"
        else
            _warn "  fstrim.timer: active but $fstrim_enabled (won't persist)"
        end
    else
        _fail "  fstrim.timer: NOT active"
    end

    if set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"
        # Socket exists (running) — also check if enabled for persistence
        set -l ssh_enabled (systemctl --user is-enabled ssh-agent.socket 2>/dev/null; or systemctl --user is-enabled ssh-agent.service 2>/dev/null)
        if test "$ssh_enabled" = enabled
            _ok "  ssh-agent: socket ready (enabled)"
        else
            _warn "  ssh-agent: socket ready but not enabled (won't persist after reboot)"
        end
    else if not set -q XDG_RUNTIME_DIR
        _warn "  ssh-agent: XDG_RUNTIME_DIR not set (not in graphical session?)"
    else
        _fail "  ssh-agent: socket missing at $XDG_RUNTIME_DIR/ssh-agent.socket"
    end
    _echo

    _echo "ENVIRONMENT STATE"
    _echo

    for exp in $ENV_VARS
        set -l n (string split '=' "$exp")[1]
        set -l expected (string split '=' "$exp")[2]
        set -l actual (printenv "$n")

        if test "$actual" = "$expected"
            _ok "  $n=$actual"
        else if test -n "$actual"
            _fail "  $n=$actual (expected: $expected)"
        else
            _fail "  $n: NOT SET"
        end
    end
    _echo

    _echo "── ntsync support ──"
    if test -c /dev/ntsync
        _ok "ntsync: /dev/ntsync exists"
    else if cat /proc/modules 2>/dev/null | grep -q '^ntsync '
        _warn "ntsync: module loaded but /dev/ntsync missing"
    else
        _info "ntsync: NOT available (kernel 6.14+ required)"
    end
    _echo

    _echo "── Modprobe silence settings ──"
    # Check ACP blacklist (modules should NOT be loaded)
    if cat /proc/modules 2>/dev/null | grep -qE 'snd_acp_pci|snd_acp70'
        _warn "  ACP modules still loaded (blacklist may need reboot)"
    else
        _ok "  ACP audio modules: not loaded (blacklisted)"
    end

    # Check Bluetooth eSCO setting
    if test -f /sys/module/bluetooth/parameters/disable_esco
        set -l esco (cat /sys/module/bluetooth/parameters/disable_esco 2>/dev/null)
        if test "$esco" = "Y"
            _ok "  bluetooth.disable_esco: $esco"
        else
            _warn "  bluetooth.disable_esco: $esco (expected: Y)"
        end
    else
        _info "  bluetooth: module not loaded"
    end
    _echo

    _echo "WIFI STATE"
    _echo

    set -l wlan_iface ""
    for iface in /sys/class/net/*/wireless
        if test -d "$iface"
            set wlan_iface (basename (dirname "$iface"))
            break
        end
    end

    if test -n "$wlan_iface"
        _ok "  WiFi interface: $wlan_iface"
    else
        _warn "  WiFi interface: NOT DETECTED"
    end

    if pgrep -x iwd >/dev/null
        _ok "  iwd process: running"
    else
        _fail "  iwd process: NOT running"
    end

    # Check NM is using iwd backend at runtime
    if command -q nmcli
        set -l nm_wifi_backend (nmcli -t -f WIFI general 2>/dev/null | string trim)
        if test -n "$nm_wifi_backend"
            _info "  NM wifi: $nm_wifi_backend"
        end
        # Check WiFi device connectivity
        set -l wifi_state (nmcli -t -f TYPE,STATE device 2>/dev/null | grep '^wifi:' | head -1 | cut -d: -f2)
        if test "$wifi_state" = connected
            _ok "  WiFi device: connected"
        else if test -n "$wifi_state"
            _warn "  WiFi device: $wifi_state (not connected)"
        end
    end

    # Parse regulatory domain with multiple fallback methods
    set -l reg ""
    set -l expected_regdom (grep -E '^[[:space:]]*WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null | grep -v '^#' | cut -d'"' -f2 | head -1)
    if test -z "$expected_regdom"
        set expected_regdom "US"
    end

    if not command -q iw
        _warn "  Regulatory domain: iw command not found (install iw package)"
    else
        # Method 1: iw reg get (may require root)
        set -l iw_output (iw reg get 2>/dev/null)
        if test -z "$iw_output"
            set iw_output (sudo iw reg get 2>/dev/null)
        end

        if test -n "$iw_output"
            # Try primary pattern: "country XX:" - capture group is at index 2
            set -l match_result (printf '%s\n' $iw_output | string match -r '^country ([A-Z]{2}):')
            if test (count $match_result) -ge 2
                set reg $match_result[2]
            end
            # Fallback: awk parsing
            if test -z "$reg"
                set reg (printf '%s\n' $iw_output | awk '/^country/ {gsub(/:/, "", $2); print $2; exit}')
            end
        end

        # Method 2: Check sysfs directly
        if test -z "$reg"; and test -f /sys/module/cfg80211/parameters/ieee80211_regdom
            set reg (cat /sys/module/cfg80211/parameters/ieee80211_regdom 2>/dev/null | string trim)
        end
    end

    if test -z "$reg"
        _info "  Regulatory domain: runtime state unavailable"
        _info "  Config file set to: $expected_regdom"
        _info "  Will apply after reboot or: sudo iw reg set $expected_regdom"
    else if test "$reg" = "00"
        _info "  Regulatory domain: $reg (world domain - not yet applied)"
        _info "  Expected: $expected_regdom (applies after driver reload or reboot)"
    else if test "$reg" = "$expected_regdom"
        _ok "  Regulatory domain: $reg"
    else
        _fail "  Regulatory domain: $reg (expected: $expected_regdom)"
    end
    _echo

    _echo "FILE PERMISSIONS"
    _echo

    _echo "── Sensitive files ──"
    # Check NetworkManager connection files (should be 0600 root:root)
    set -l nm_conn_dir "/etc/NetworkManager/system-connections"
    if test -d "$nm_conn_dir"
        set -l bad_perms 0
        for conn_file in $nm_conn_dir/*.nmconnection
            if test -f "$conn_file"
                set -l perms (stat -c '%a' "$conn_file" 2>/dev/null)
                set -l owner (stat -c '%U:%G' "$conn_file" 2>/dev/null)
                if test "$perms" != "600"; or test "$owner" != "root:root"
                    _fail "  $conn_file: $perms $owner (expected: 600 root:root)"
                    set bad_perms (math $bad_perms + 1)
                end
            end
        end
        if test $bad_perms -eq 0
            set -l conn_files $nm_conn_dir/*.nmconnection
            # Fish returns the literal glob pattern if no matches; check if first element exists
            if test -n "$conn_files[1]" -a -e "$conn_files[1]"
                set -l conn_count (count $conn_files)
                _ok "  NetworkManager connections: $conn_count files with correct permissions"
            else
                # Warn if NM uses iwd backend (WiFi profiles expected)
                if grep -q 'wifi.backend=iwd' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null
                    _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
                else
                    _info "  NetworkManager connections: no .nmconnection files found"
                end
            end
        end
    else
        _info "  NetworkManager connections: directory not found"
    end

    # Check SSH authorized_keys if exists
    if test -f "$HOME/.ssh/authorized_keys"
        set -l perms (stat -c '%a' "$HOME/.ssh/authorized_keys" 2>/dev/null)
        if test "$perms" = "600"; or test "$perms" = "644"
            _ok "  ~/.ssh/authorized_keys: $perms"
        else
            _warn "  ~/.ssh/authorized_keys: $perms (should be 600 or 644)"
        end
    end

    # Check SSH directory permissions
    if test -d "$HOME/.ssh"
        set -l perms (stat -c '%a' "$HOME/.ssh" 2>/dev/null)
        if test "$perms" = "700"
            _ok "  ~/.ssh directory: $perms"
        else
            _warn "  ~/.ssh directory: $perms (should be 700)"
        end
    end
    _echo

    _echo "BOOT PERFORMANCE"
    _echo

    if command -q systemd-analyze
        set -l boot_time (systemd-analyze 2>/dev/null | head -1)
        _info "  $boot_time"

        # Extract total time and check against target
        set -l total_sec (echo "$boot_time" | string match -r '= ([0-9.]+)s' | tail -1)
        if test -n "$total_sec"; and string match -qr '^[0-9.]+$' "$total_sec"
            set -l target 15
            set -l time_int (printf "%.0f" (math "$total_sec") 2>/dev/null)
            if test -n "$time_int"; and test "$time_int" -lt $target
                _ok "  Boot time under $target""s target"
            else if test -n "$time_int"
                _warn "  Boot time exceeds $target""s target"
                _info "  Run 'systemd-analyze blame' to identify slow services"
            end
        end

        # Show top 3 slowest services
        _echo "  Slowest services:"
        set -l blame (systemd-analyze blame 2>/dev/null | head -3)
        for line in $blame
            _info "    $line"
        end
    else
        _warn "  systemd-analyze not available"
    end
    _echo

    _log "=== RUNTIME VERIFICATION END ==="

    # Print summary and return exit code
    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

# =============================================================================
# UTILITY COMMANDS
# =============================================================================

# Quick system status dashboard
function do_status
    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - System Status                            │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo

    # System info
    _echo "── System ──"
    set -l kernel (uname -r)
    set -l uptime (uptime -p 2>/dev/null | string replace 'up ' '')
    set -l boot_time (who -b 2>/dev/null | awk '{print $3, $4}')
    _info "Kernel: $kernel"
    _info "Uptime: $uptime"
    if test -n "$boot_time"
        _info "Booted: $boot_time"
    end

    # Last update and pending updates
    set -l last_update (grep -E "^\[.*\] \[PACMAN\] starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -1 | grep -oE '\[[-0-9T:+]+\]' | head -1 | tr -d '[]')
    if test -n "$last_update"
        _info "Last update: $last_update"
    end

    # Check for pending updates (quick check)
    if command -q checkupdates
        set -l pending (checkupdates 2>/dev/null | wc -l | string trim)
        if test -n "$pending"; and string match -qr '^\d+$' "$pending"; and test "$pending" -gt 0
            _warn "Pending updates: $pending"
        else
            _ok "System up to date"
        end
    end
    _echo

    # Temperatures
    _echo "── Temperatures ──"
    if command -q sensors
        set -l cpu_temp (sensors 2>/dev/null | grep -E "Tctl|Tdie" | head -1 | awk '{print $2}')
        set -l gpu_temp (sensors 2>/dev/null | grep -E "edge|junction" | head -1 | awk '{print $2}')
        if test -n "$cpu_temp"
            # Extract numeric value safely (handles +85.0°C format)
            set -l temp_val (string replace -ra '[^0-9.]' '' "$cpu_temp" | string split '.')[1]
            if test -n "$temp_val"; and string match -qr '^\d+$' "$temp_val"
                if test "$temp_val" -ge 85
                    _warn "CPU: $cpu_temp (high)"
                else
                    _ok "CPU: $cpu_temp"
                end
            else
                _info "CPU: $cpu_temp"
            end
        end
        if test -n "$gpu_temp"
            set -l temp_val (string replace -ra '[^0-9.]' '' "$gpu_temp" | string split '.')[1]
            if test -n "$temp_val"; and string match -qr '^\d+$' "$temp_val"
                if test "$temp_val" -ge 85
                    _warn "GPU: $gpu_temp (high)"
                else
                    _ok "GPU: $gpu_temp"
                end
            else
                _info "GPU: $gpu_temp"
            end
        end
    else
        _warn "sensors not found (install lm_sensors)"
    end
    _echo

    # GPU Performance
    _echo "── GPU Performance ──"
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set -l level (cat "$f" 2>/dev/null)
            if test "$level" = "high"
                _ok "Performance level: $level"
            else
                _warn "Performance level: $level (expected: high)"
            end
            break
        end
    end

    set -l gpu_busy ""
    for f in /sys/class/drm/card*/device/gpu_busy_percent
        if test -f "$f"
            set gpu_busy (cat "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$gpu_busy"
        _info "GPU busy: $gpu_busy%"
    end
    _echo

    # CPU Performance
    _echo "── CPU Performance ──"
    set -l governor (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    if test "$governor" = "performance"
        _ok "Governor: $governor"
    else
        _warn "Governor: $governor (expected: performance)"
    end

    set -l epp (cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
    if test "$epp" = "performance"
        _ok "EPP: $epp"
    else
        _warn "EPP: $epp (expected: performance)"
    end

    # CPU frequency range
    set -l freq_min (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null)
    set -l freq_max (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    set -l freq_cur (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    if test -n "$freq_cur" -a -n "$freq_max"
        set freq_cur (math "$freq_cur / 1000")
        set freq_max (math "$freq_max / 1000")
        _info "Frequency: $freq_cur MHz (max: $freq_max MHz)"
    else if test -n "$freq_cur"
        set freq_cur (math "$freq_cur / 1000")
        _info "Frequency: $freq_cur MHz"
    end
    _echo

    # Services
    _echo "── Services ──"
    for svc in amdgpu-performance cpupower-epp fstrim.timer
        set -l state (systemctl is-active $svc 2>/dev/null)
        if test "$state" = "active"
            _ok "$svc: $state"
        else
            _warn "$svc: $state"
        end
    end
    _echo

    # ntsync
    _echo "── Gaming ──"
    if test -c /dev/ntsync
        _ok "ntsync: available"
    else if cat /proc/modules 2>/dev/null | grep -q '^ntsync '
        _warn "ntsync: module loaded but /dev/ntsync missing"
    else
        _info "ntsync: not available (kernel 6.14+ required)"
    end

    # Proton env check
    if test "$PROTON_USE_NTSYNC" = "1"
        _ok "PROTON_USE_NTSYNC: enabled"
    else
        _info "PROTON_USE_NTSYNC: not set in current shell"
    end
    _echo

    # WiFi
    _echo "── Network ──"
    if command -q nmcli
        set -l wifi_info (nmcli -t -f ACTIVE,SSID,SIGNAL,FREQ dev wifi list 2>/dev/null | grep '^yes:')
        if test -n "$wifi_info"
            set -l ssid (echo $wifi_info | cut -d: -f2)
            set -l signal (echo $wifi_info | cut -d: -f3)
            set -l freq (echo $wifi_info | cut -d: -f4)
            _ok "WiFi: $ssid ($signal% @ $freq)"
        else
            set -l eth_state (nmcli -t -f TYPE,STATE dev | grep ethernet | cut -d: -f2)
            if test "$eth_state" = "connected"
                _ok "Ethernet: connected"
            else
                _warn "Network: not connected"
            end
        end
    end
    _echo

    # Memory
    _echo "── Memory ──"
    set -l mem_info (free -h | grep Mem)
    set -l mem_used (echo $mem_info | awk '{print $3}')
    set -l mem_total (echo $mem_info | awk '{print $2}')
    _info "RAM: $mem_used / $mem_total"

    # VRAM
    set -l vram_used ""
    set -l vram_total ""
    for f in /sys/class/drm/card*/device/mem_info_vram_used
        if test -f "$f"
            set vram_used (cat "$f" 2>/dev/null)
            break
        end
    end
    for f in /sys/class/drm/card*/device/mem_info_vram_total
        if test -f "$f"
            set vram_total (cat "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$vram_used" -a -n "$vram_total"
        set vram_used (math "$vram_used / 1073741824")
        set vram_total (math "$vram_total / 1073741824")
        _info "VRAM: "$vram_used"G / "$vram_total"G"
    end
    _echo

    # Disk
    _echo "── Storage ──"
    set -l root_info (df -h / | tail -1)
    set -l root_used (echo $root_info | awk '{print $3}')
    set -l root_size (echo $root_info | awk '{print $2}')
    set -l root_pct (echo $root_info | awk '{print $5}')
    _info "Root: $root_used / $root_size ($root_pct)"
    _echo

    # Fan speeds (if available)
    _echo "── Fans ──"
    if command -q sensors
        set -l fans (sensors 2>/dev/null | grep -i "fan" | head -3)
        if test -n "$fans"
            for fan in $fans
                _info (string trim "$fan")
            end
        else
            _info "No fan sensors detected"
        end
    end
    _echo

    # Power draw (if available)
    _echo "── Power ──"
    set -l pkg_power ""
    for f in /sys/class/hwmon/hwmon*/power1_average
        if test -f "$f"
            set pkg_power (cat "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$pkg_power"
        set -l watts (math "$pkg_power / 1000000")
        _info "Package power: "$watts"W"
    end
    set -l gpu_power ""
    for f in /sys/class/drm/card*/device/hwmon/hwmon*/power1_average
        if test -f "$f"
            set gpu_power (cat "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$gpu_power"
        set -l watts (math "$gpu_power / 1000000")
        _info "GPU power: "$watts"W"
    end
    if test -z "$pkg_power" -a -z "$gpu_power"
        _info "Power sensors not available"
    end
    _echo

    # Scheduler info
    _echo "── Schedulers ──"
    set -l cpu_sched ""
    for f in /sys/kernel/debug/sched/*/name
        if test -f "$f"
            set cpu_sched (cat "$f" 2>/dev/null)
            break
        end
    end
    if test -z "$cpu_sched"
        # Alternative: check kernel config
        set cpu_sched (zgrep CONFIG_SCHED /proc/config.gz 2>/dev/null | grep "=y" | head -1 | cut -d'_' -f3 | cut -d'=' -f1)
    end
    if test -n "$cpu_sched"
        _info "CPU scheduler: $cpu_sched"
    end

    # Detect root device's block device for I/O scheduler
    set -l root_dev (findmnt -no SOURCE / 2>/dev/null | sed 's/\[.*\]//' | xargs -r realpath 2>/dev/null | sed 's/p\?[0-9]*$//')
    if test -z "$root_dev"
        # Fallback to nvme0n1 if detection fails
        set root_dev /dev/nvme0n1
    end
    set -l blk_name (basename "$root_dev" 2>/dev/null)
    set -l io_sched (cat /sys/block/$blk_name/queue/scheduler 2>/dev/null | grep -oE '\[.*\]' | tr -d '[]')
    if test -n "$io_sched"
        _info "I/O scheduler: $io_sched ($blk_name)"
    end
end

# Live monitoring mode
function do_watch
    if not command -q watch
        _err "watch command not found"
        return 1
    end

    # Check for interactive terminal
    if not isatty stdout
        _err "watch mode requires an interactive terminal"
        return 1
    end

    # Create a temporary script for watch to execute
    # Use deterministic path so it self-cleans on next invocation (survives SIGKILL)
    set -l watch_script "/tmp/ry-install-watch-"(id -u)".fish"
    rm -f "$watch_script" 2>/dev/null

    echo '#!/usr/bin/env fish
    echo "ry-install Live Monitor (Ctrl+C to exit)"
    echo "========================================="
    echo

    # Temps
    echo "TEMPERATURES"
    if command -q sensors
        sensors 2>/dev/null | grep -E "Tctl|Tdie|edge|junction|fan" | head -6
    end
    echo

    # GPU
    echo "GPU"
    # Use fish glob expansion with for-loop
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        test -f "$f"; and printf "  Perf level: %s\n" (cat "$f" 2>/dev/null); and break
    end
    for f in /sys/class/drm/card*/device/gpu_busy_percent
        test -f "$f"; and printf "  Busy: %s%%\n" (cat "$f" 2>/dev/null); and break
    end
    for f in /sys/class/drm/card*/device/hwmon/hwmon*/power1_average
        if test -f "$f"
            set -l pwr (cat "$f" 2>/dev/null)
            test -n "$pwr"; and printf "  Power: %s W\n" (math "$pwr / 1000000")
            break
        end
    end
    echo

    # CPU
    echo "CPU"
    printf "  Governor: %s\n" (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    set -l frq (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    test -n "$frq"; and printf "  Freq: %s MHz\n" (math "$frq / 1000")
    echo

    # Memory
    echo "MEMORY"
    free -h | grep -E "Mem|Swap"
    ' > "$watch_script"

    chmod +x "$watch_script"

    echo "Starting live monitor (Ctrl+C to exit)..."
    if test "$NO_COLOR" = true
        watch -n 1 "fish $watch_script"
    else
        watch -n 1 -c "fish $watch_script"
    end

    rm -f "$watch_script"
end

# System cleanup
function do_clean
    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - System Cleanup                           │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo

    set -l total_freed 0

    # Package cache
    _echo "── Package Cache ──"
    set -l cache_size (du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
    _info "Current size: $cache_size"

    if test "$DRY" = true
        _info "Would run: sudo paccache -rk2 (keep 2 versions)"
        _info "Would run: sudo paccache -ruk0 (remove uninstalled)"
    else
        if _ask "Clean package cache (keep 2 versions)?"
            if command -q paccache
                sudo paccache -rk2
                sudo paccache -ruk0
                set -l new_size (du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
                _ok "New size: $new_size"
            else
                _warn "paccache not found (install pacman-contrib)"
            end
        end
    end
    _echo

    # Journal
    _echo "── System Journal ──"
    set -l journal_size (journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[GMK]')
    _info "Current size: $journal_size"

    if test "$DRY" = true
        _info "Would run: sudo journalctl --vacuum-time=7d"
    else
        if _ask "Vacuum journal (keep 7 days)?"
            sudo journalctl --vacuum-time=7d
            set -l new_size (journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[GMK]')
            _ok "New size: $new_size"
        end
    end
    _echo

    # Shader cache
    _echo "── Shader Cache ──"
    set -l shader_dirs ~/.cache/mesa_shader_cache ~/.cache/radv_builtin_shaders
    set -l shader_size 0
    for dir in $shader_dirs
        if test -d "$dir"
            set -l dir_size (du -sb "$dir" 2>/dev/null | cut -f1)
            if test -n "$dir_size"; and string match -qr '^\d+$' "$dir_size"
                set shader_size (math "$shader_size + $dir_size")
            end
        end
    end
    set shader_size_h (math "$shader_size / 1048576")
    _info "Current size: ~"$shader_size_h"M"

    if test "$DRY" = true
        _info "Would remove shader caches (will rebuild automatically)"
    else
        if test $shader_size -gt 0
            if _ask "Clear shader caches? (will rebuild on next game launch)"
                for dir in $shader_dirs
                    if test -d "$dir"
                        rm -rf "$dir"
                        _ok "Removed: $dir"
                    end
                end
            end
        else
            _info "No shader caches found"
        end
    end
    _echo

    # Orphan packages
    _echo "── Orphan Packages ──"
    if not command -q pacman
        _info "pacman not available"
    else
        set -l orphans (pacman -Qdtq 2>/dev/null)
        if test -n "$orphans"
            _info "Found "(count $orphans)" orphan(s):"
            for pkg in $orphans
                echo "    $pkg"
            end

            if test "$DRY" = true
                _info "Would run: sudo pacman -Rns \$orphans"
            else
                if _ask "Remove orphan packages?"
                    if not _run sudo pacman -Rns --noconfirm -- $orphans
                        _warn "Orphan removal failed"
                    else
                        _ok "Orphans removed"
                    end
                end
            end
        else
            _ok "No orphan packages"
        end
    end
    _echo

    # Old logs
    _echo "── Old ry-install Logs ──"
    set -l old_logs (find "$LOG_DIR" -maxdepth 1 -name '*.log' -mtime +7 2>/dev/null)
    # Also check legacy location
    set -l legacy_logs (find ~ -maxdepth 1 -name 'ry-install-*.log' -mtime +7 2>/dev/null)
    set old_logs $old_logs $legacy_logs
    if test -n "$old_logs"
        _info "Found "(count $old_logs)" log(s) older than 7 days"
        if test "$DRY" = true
            _info "Would remove old log files"
        else
            if _ask "Remove old log files?"
                rm -f -- $old_logs
                _ok "Old logs removed"
            end
        end
    else
        _ok "No old logs"
    end
    _echo

    # 6. Coredumps
    _echo "── Coredumps ──"
    if command -q coredumpctl
        set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
        # wc -l output should be numeric but validate to be safe
        if test -n "$dump_count"; and string match -qr '^\d+$' (string trim "$dump_count"); and test "$dump_count" -gt 0
            _info "Found $dump_count coredump(s)"
            if test "$DRY" = true
                _info "Would remove coredumps"
            else
                if _ask "Remove coredumps?"
                    sudo coredumpctl vacuum --time=1s 2>/dev/null
                    _ok "Coredumps removed"
                end
            end
        else
            _ok "No coredumps"
        end
    else
        _info "coredumpctl not available"
    end
    _echo

    # 7. User cache (thumbnails, etc.)
    _echo "── User Cache ──"
    set -l cache_dirs
    for d in ~/.cache/thumbnails ~/.cache/mesa_shader_cache_sf ~/.cache/fontconfig
        if test -d "$d"
            set -a cache_dirs "$d"
        end
    end

    if test (count $cache_dirs) -gt 0
        set -l cache_total 0
        for d in $cache_dirs
            set -l size (du -sb "$d" 2>/dev/null | cut -f1)
            if test -n "$size"; and string match -qr '^\d+$' "$size"
                set cache_total (math "$cache_total + $size")
            end
        end
        set -l cache_mb (math "$cache_total / 1048576")
        _info "User cache: ~"$cache_mb"M (thumbnails, fontconfig)"

        if test "$cache_mb" -gt 100
            if test "$DRY" = true
                _info "Would clear user caches"
            else
                if _ask "Clear user caches (thumbnails, fontconfig)?"
                    for d in $cache_dirs
                        rm -rf "$d" 2>/dev/null
                    end
                    _ok "User caches cleared"
                end
            end
        else
            _ok "User cache size reasonable"
        end
    else
        _ok "No significant user cache"
    end
    _echo

    _info "Cleanup complete"
end

# WiFi diagnostics
function do_wifi_diag
    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - WiFi Diagnostics                         │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo

    # Check if WiFi interface exists
    set -l wifi_iface ""
    for iface in /sys/class/net/*/wireless
        if test -d "$iface"
            set wifi_iface (dirname "$iface" | xargs basename)
            break
        end
    end

    if test -z "$wifi_iface"
        _err "No WiFi interface found"
        return 1
    end

    _info "Interface: $wifi_iface"
    _echo

    # Driver info
    _echo "── Driver ──"
    set -l driver (readlink /sys/class/net/$wifi_iface/device/driver 2>/dev/null | xargs basename)
    _info "Driver: $driver"

    if test "$driver" = "mt7925e"
        _info "Chip: MediaTek MT7925 (WiFi 7)"
        _info "Known issues: MLO errors, ASPM conflicts"
    end
    _echo

    # Connection status
    _echo "── Connection ──"
    if command -q nmcli
        set -l conn_info (nmcli -t -f GENERAL.STATE,GENERAL.CONNECTION dev show $wifi_iface 2>/dev/null)
        set -l state (printf '%s\n' $conn_info | grep GENERAL.STATE | cut -d: -f2)
        set -l ssid (printf '%s\n' $conn_info | grep GENERAL.CONNECTION | cut -d: -f2)

        if string match -q "*connected*" "$state"
            _ok "State: connected"
            _info "SSID: $ssid"
        else
            _warn "State: $state"
        end
    end
    _echo

    # Signal info
    _echo "── Signal ──"
    if command -q iw
        set -l link_info (iw dev $wifi_iface link 2>/dev/null)
        if test -n "$link_info"
            set -l signal (printf '%s\n' $link_info | grep signal | awk '{print $2}')
            set -l freq (printf '%s\n' $link_info | grep freq | awk '{print $2}')
            set -l tx_rate (printf '%s\n' $link_info | grep "tx bitrate" | sed 's/.*: //')
            set -l rx_rate (printf '%s\n' $link_info | grep "rx bitrate" | sed 's/.*: //')

            if test -n "$signal"
                # Validate signal is numeric before comparison
                if string match -qr '^-?\d+$' "$signal"
                    if test "$signal" -ge -50
                        _ok "Signal: $signal dBm (excellent)"
                    else if test "$signal" -ge -60
                        _ok "Signal: $signal dBm (good)"
                    else if test "$signal" -ge -70
                        _warn "Signal: $signal dBm (fair)"
                    else
                        _fail "Signal: $signal dBm (weak)"
                    end
                else
                    _info "Signal: $signal dBm"
                end
            end

            if test -n "$freq"; and string match -qr '^\d+$' "$freq"
                if test "$freq" -ge 5925
                    _info "Band: 6 GHz ($freq MHz) - WiFi 6E/7"
                else if test "$freq" -ge 5150
                    _info "Band: 5 GHz ($freq MHz)"
                else
                    _info "Band: 2.4 GHz ($freq MHz)"
                end
            else if test -n "$freq"
                _info "Band: $freq MHz"
            end

            if test -n "$tx_rate"
                _info "TX rate: $tx_rate"
            end
            if test -n "$rx_rate"
                _info "RX rate: $rx_rate"
            end
        end
    end
    _echo

    # NM backend check
    _echo "── NetworkManager Config ──"
    set -l nm_backend (grep -r "wifi.backend" /etc/NetworkManager/conf.d/ 2>/dev/null | grep -v "^#" | tail -1)
    if string match -q "*iwd*" "$nm_backend"
        _ok "Backend: iwd"
    else
        _warn "Backend: wpa_supplicant (expected: iwd)"
    end

    set -l nm_powersave (grep -r "wifi.powersave" /etc/NetworkManager/conf.d/ 2>/dev/null | grep -v "^#" | tail -1)
    if string match -q "*2*" "$nm_powersave"
        _ok "Power save: disabled"
    else
        _warn "Power save: enabled (may cause disconnects)"
    end
    _echo

    # Recent errors
    _echo "── Recent Issues (last 5 min) ──"
    set -l errors (journalctl -u NetworkManager -u iwd --since "5 minutes ago" --no-pager 2>/dev/null | grep -iE "error|fail|disconnect|deauth" | tail -5)
    if test -n "$errors"
        _warn "Found issues in logs:"
        for err in $errors
            echo "    $err"
        end
    else
        _ok "No recent errors"
    end
    _echo

    # MLO status (WiFi 7)
    _echo "── WiFi 7 / MLO ──"
    set -l mlo_errors (journalctl -u iwd --since "1 hour ago" --no-pager 2>/dev/null | grep -c "MLO" | string trim)
    if test -n "$mlo_errors"; and string match -qr '^\d+$' "$mlo_errors"; and test "$mlo_errors" -gt 0
        _warn "MLO errors in last hour: $mlo_errors"
        _info "Tip: MLO issues common with WiFi 7 routers"
        _info "     Try disabling MLO or Smart Connect in router"
    else
        _ok "No MLO errors"
    end

    # Band steering check
    set -l band_changes (journalctl -u NetworkManager --since "1 hour ago" --no-pager 2>/dev/null | grep -c "roamed to" | string trim)
    if test -n "$band_changes"; and string match -qr '^\d+$' "$band_changes"; and test "$band_changes" -gt 5
        _warn "Frequent band changes: $band_changes in last hour"
        _info "Tip: Aggressive band steering detected"
        _info "     Disable Smart Connect in router settings"
    else
        _ok "Band steering: stable"
    end
    _echo

    # Firmware version
    _echo "── Firmware ──"
    set -l fw_ver (sudo dmesg 2>/dev/null | grep -i "$driver.*firmware" | tail -1 | grep -oE 'firmware.*' | head -1)
    if test -n "$fw_ver"
        _info "$fw_ver"
    else
        # Try modinfo
        set -l mod_fw (modinfo "$driver" 2>/dev/null | grep "^firmware:" | head -1 | awk '{print $2}')
        if test -n "$mod_fw"
            _info "Firmware file: $mod_fw"
        else
            _info "Firmware version not available in logs"
        end
    end
    _echo

    # Regulatory domain
    _echo "── Regulatory ──"
    if command -q iw
        set -l regdom (iw reg get 2>/dev/null | grep "country" | head -1)
        if test -n "$regdom"
            _info "$regdom"
        else
            _info "Regulatory domain not set"
        end
    end

    set -l expected_regdom (cat /etc/conf.d/wireless-regdom 2>/dev/null | grep "^WIRELESS_REGDOM" | cut -d'"' -f2)
    if test -n "$expected_regdom"
        _info "Configured: $expected_regdom"
    end
    _echo

    # Supported bands (brief)
    _echo "── Capabilities ──"
    if command -q iw
        set -l bands (iw phy 2>/dev/null | grep -E "Band [0-9]:" | wc -l)
        set -l has_6g (iw phy 2>/dev/null | grep -c "Band 4:")

        _info "Supported bands: $bands"
        if test "$has_6g" -gt 0
            _ok "6 GHz capable (WiFi 6E/7)"
        end

        # Check if 160MHz supported
        set -l has_160 (iw phy 2>/dev/null | grep -c "160 MHz")
        if test "$has_160" -gt 0
            _ok "160 MHz channel width supported"
        end
    end
end

# Quick benchmark
function do_benchmark
    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - Quick Benchmark                          │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo
    _info "This is a quick sanity check, not a comprehensive benchmark"
    _echo

    # CPU benchmark
    _echo "── CPU (single-threaded) ──"
    _info "Running 10-second stress test..."
    set -l start_time (date +%s%N)
    set -l iterations 0
    set -l end_time (math (date +%s)" + 10")

    while test (date +%s) -lt $end_time
        # Simple math operations
        math "sqrt(12345.6789) * 9876.54321" >/dev/null
        set iterations (math "$iterations + 1")
    end

    _info "Iterations: $iterations (higher is better)"
    _echo

    # Memory bandwidth (simple test)
    _echo "── Memory ──"
    _info "Testing with dd..."
    set -l mem_result (dd if=/dev/zero of=/dev/null bs=1M count=10000 2>&1 | tail -1)
    _info "$mem_result"
    _echo

    # GPU benchmark
    _echo "── GPU ──"
    if command -q glxgears
        _info "Running glxgears for 10 seconds..."
        set -l fps (timeout 10 glxgears 2>&1 | grep -oE '[0-9]+ frames' | tail -1 | grep -oE '[0-9]+')
        if test -n "$fps"; and string match -qr '^\d+$' "$fps"
            set fps (math "$fps / 10")  # Average FPS
            _info "glxgears: ~$fps FPS"
        else
            _info "glxgears: could not parse FPS"
        end
    else if command -q vkcube
        _info "Running vkcube for 5 seconds..."
        timeout 5 vkcube 2>&1 | tail -3
    else
        _warn "No GPU benchmark tool found"
        _info "Install: mesa-utils (glxgears) or vulkan-tools (vkcube)"
    end
    _echo

    # Disk benchmark
    _echo "── Storage ──"
    _info "Testing with dd (sync write)..."
    set -l bench_file (mktemp --tmpdir ry-benchmark.XXXXXX)
    if test -z "$bench_file"
        _warn "Failed to create temp file for disk benchmark"
    else
        set -l disk_result (dd if=/dev/zero of="$bench_file" bs=1M count=1024 conv=fdatasync 2>&1 | tail -1)
        rm -f "$bench_file"
        _info "$disk_result"
    end
    _echo

    _info "Benchmark complete"
    _info "For detailed benchmarks, use: phoronix-test-suite, glmark2, unigine"
end

# Export system configuration for sharing/troubleshooting
function do_export
    set -l export_file "$LOG_DIR/export-"(date +%Y%m%d-%H%M%S)".txt"

    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - System Export                            │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo
    _info "Exporting system configuration to: $export_file"
    _echo

    # Start export
    echo "# ry-install System Export" > "$export_file"
    echo "# Generated: "(date) >> "$export_file"
    echo "# ry-install version: $VERSION" >> "$export_file"
    echo "" >> "$export_file"

    # System info
    echo "## SYSTEM" >> "$export_file"
    echo "Hostname: "(hostname) >> "$export_file"
    echo "Kernel: "(uname -r) >> "$export_file"
    echo "Arch: "(uname -m) >> "$export_file"
    if test -f /etc/os-release
        echo "OS: "(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2) >> "$export_file"
    end
    echo "" >> "$export_file"

    # Hardware
    echo "## HARDWARE" >> "$export_file"
    if command -q dmidecode
        echo "System: "(sudo dmidecode -s system-product-name 2>/dev/null) >> "$export_file"
        echo "BIOS: "(sudo dmidecode -s bios-version 2>/dev/null)" ("(sudo dmidecode -s bios-release-date 2>/dev/null)")" >> "$export_file"
    end
    echo "CPU: "(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs) >> "$export_file"
    if command -q lspci
        echo "GPU: "(lspci 2>/dev/null | grep -i vga | cut -d: -f3 | xargs) >> "$export_file"
    else
        echo "GPU: (lspci not available)" >> "$export_file"
    end
    echo "Memory: "(free -h | grep Mem | awk '{print $2}') >> "$export_file"
    echo "" >> "$export_file"

    # GPU details
    echo "## GPU STATE" >> "$export_file"
    set -l perf_level_export ""
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set perf_level_export (cat "$f" 2>/dev/null)
            break
        end
    end
    echo "Performance level: $perf_level_export" >> "$export_file"
    set -l vram_bytes ""
    for f in /sys/class/drm/card*/device/mem_info_vram_total
        if test -f "$f"
            set vram_bytes (cat "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$vram_bytes"
        echo "VRAM total: "(math "$vram_bytes / 1073741824")" GB" >> "$export_file"
    else
        echo "VRAM total: N/A" >> "$export_file"
    end
    echo "" >> "$export_file"

    # CPU details
    echo "## CPU STATE" >> "$export_file"
    echo "Governor: "(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null) >> "$export_file"
    echo "EPP: "(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null) >> "$export_file"
    echo "Driver: "(cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null) >> "$export_file"
    echo "" >> "$export_file"

    # Kernel cmdline
    echo "## KERNEL CMDLINE" >> "$export_file"
    cat /proc/cmdline >> "$export_file"
    echo "" >> "$export_file"

    # Key services
    echo "## SERVICES" >> "$export_file"
    for svc in amdgpu-performance cpupower-epp fstrim.timer NetworkManager iwd
        echo "$svc: "(systemctl is-active $svc 2>/dev/null)" ("(systemctl is-enabled $svc 2>/dev/null)")" >> "$export_file"
    end
    echo "" >> "$export_file"

    # Masked services
    echo "## MASKED SERVICES" >> "$export_file"
    systemctl list-unit-files --state=masked --no-pager 2>/dev/null | grep -E "\.service|\.target" | head -20 >> "$export_file"
    echo "" >> "$export_file"

    # Network
    echo "## NETWORK" >> "$export_file"
    if command -q nmcli
        nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null >> "$export_file"
    end
    echo "" >> "$export_file"

    # WiFi details
    echo "## WIFI" >> "$export_file"
    if command -q iw
        set -l wifi_iface (iw dev 2>/dev/null | grep Interface | awk '{print $2}' | head -1)
        if test -n "$wifi_iface"
            iw dev $wifi_iface link 2>/dev/null >> "$export_file"
        end
    end
    echo "" >> "$export_file"

    # Key config files (existence and first line)
    echo "## CONFIG FILES" >> "$export_file"
    for f in /etc/mkinitcpio.conf /etc/sdboot-manage.conf /etc/modprobe.d/99-cachyos-modprobe.conf /etc/environment /etc/iwd/main.conf
        if test -f "$f"
            echo "$f: EXISTS" >> "$export_file"
        else
            echo "$f: MISSING" >> "$export_file"
        end
    end
    echo "" >> "$export_file"

    # Packages (gaming-related)
    echo "## KEY PACKAGES" >> "$export_file"
    if command -q pacman
        for pkg in linux-cachyos mesa vulkan-radeon lib32-vulkan-radeon wine proton steam lutris
            set -l ver (pacman -Q $pkg 2>/dev/null | awk '{print $2}')
            if test -n "$ver"
                echo "$pkg: $ver" >> "$export_file"
            else
                echo "$pkg: not installed" >> "$export_file"
            end
        end
    else
        echo "(pacman not available)" >> "$export_file"
    end
    echo "" >> "$export_file"

    # Recent errors
    echo "## RECENT ERRORS (last hour)" >> "$export_file"
    journalctl --since "1 hour ago" --no-pager -p err 2>/dev/null | tail -20 >> "$export_file"
    echo "" >> "$export_file"

    # Boot analysis
    echo "## BOOT ANALYSIS" >> "$export_file"
    if command -q systemd-analyze
        systemd-analyze 2>/dev/null >> "$export_file"
        echo "" >> "$export_file"
        echo "Slowest units:" >> "$export_file"
        systemd-analyze blame 2>/dev/null | head -10 >> "$export_file"
    end
    echo "" >> "$export_file"

    # Loaded modules
    echo "## LOADED MODULES (relevant)" >> "$export_file"
    cat /proc/modules 2>/dev/null | grep -iE "amdgpu|radeon|drm|mt7|iwl|nvme|btusb|usbcore" >> "$export_file"
    echo "" >> "$export_file"

    # Block devices
    echo "## BLOCK DEVICES" >> "$export_file"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null >> "$export_file"
    echo "" >> "$export_file"

    # Mount options
    echo "## MOUNT OPTIONS" >> "$export_file"
    findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS / /boot /home 2>/dev/null >> "$export_file"
    echo "" >> "$export_file"

    # PCI devices (GPU and network)
    echo "## PCI DEVICES (GPU/Network)" >> "$export_file"
    if command -q lspci
        lspci 2>/dev/null | grep -iE "vga|3d|display|network|ethernet|wifi" >> "$export_file"
    else
        echo "(lspci not available)" >> "$export_file"
    end
    echo "" >> "$export_file"

    # Temperatures
    echo "## TEMPERATURES" >> "$export_file"
    if command -q sensors
        sensors 2>/dev/null >> "$export_file"
    end

    chmod 600 "$export_file"
    _ok "Export complete: $export_file"
    _info "Share this file when asking for help (contains no passwords)"
end

# List available backups
function do_backup_list
    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - Backup List                              │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo

    set -l backup_base "$HOME/ry-install/backup"

    if not test -d "$backup_base"
        # Check legacy location too
        set backup_base "$HOME/.backup"
    end

    if not test -d "$backup_base"
        _warn "No backups found"
        return 0
    end

    set -l backups (ls -1d $backup_base/*/ 2>/dev/null | sort -r)

    if test (count $backups) -eq 0
        _warn "No backups found"
        return 0
    end

    _info "Found "(count $backups)" backup(s):"
    _echo

    for backup in $backups
        set -l name (basename "$backup")
        set -l size (du -sh "$backup" 2>/dev/null | cut -f1)
        set -l file_count (find "$backup" -type f 2>/dev/null | wc -l)

        # Parse timestamp from name (format: YYYYMMDD-HHMMSS+ZZZZ)
        set -l date_part (string sub -l 8 "$name")
        set -l time_part (string sub -s 10 -l 6 "$name")

        if string match -qr '^\d{8}$' "$date_part"
            set -l formatted_date (string sub -l 4 "$date_part")"-"(string sub -s 5 -l 2 "$date_part")"-"(string sub -s 7 "$date_part")
            set -l formatted_time (string sub -l 2 "$time_part")":"(string sub -s 3 -l 2 "$time_part")":"(string sub -s 5 "$time_part")
            _echo "  $formatted_date $formatted_time  $size  ($file_count files)"
        else
            _echo "  $name  $size  ($file_count files)"
        end

        # Show what's in this backup
        if test "$QUIET" = false
            for subdir in etc boot home other
                if test -d "$backup/$subdir"
                    set -l sub_count (find "$backup/$subdir" -type f 2>/dev/null | wc -l)
                    if test "$sub_count" -gt 0
                        echo "    └─ $subdir/ ($sub_count files)"
                    end
                end
            end
        end
    end

    _echo
    _info "To restore: sudo cp ~/ry-install/backup/<timestamp>/<path> <destination>"
    _info "Example: sudo cp ~/ry-install/backup/20260204-120000+0000/etc/mkinitcpio.conf /etc/"
end

# Quick log viewer with smart filtering
function do_logs
    set -l target $argv[1]

    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - Log Viewer                               │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo

    if test -z "$target"
        _info "Usage: ry-install.fish --logs <target>"
        _echo
        _info "Available targets:"
        echo "    system     - Recent system errors (dmesg + journal)"
        echo "    gpu        - AMDGPU driver messages"
        echo "    wifi       - NetworkManager + iwd logs"
        echo "    boot       - Boot sequence logs"
        echo "    audio      - PipeWire/audio logs"
        echo "    usb        - USB device events"
        echo "    <service>  - Any systemd service name"
        return 0
    end

    switch $target
        case system
            _info "System errors (last hour):"
            _echo
            echo "── dmesg errors ──"
            if command -q sudo
                sudo dmesg --level=err,warn --ctime 2>/dev/null | tail -30
            else
                dmesg --level=err,warn --ctime 2>/dev/null | tail -30
            end
            _echo
            echo "── journal errors ──"
            journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | tail -30

        case gpu
            _info "AMDGPU logs:"
            _echo
            sudo dmesg 2>/dev/null | grep -iE "amdgpu|drm|radeon|gfx" | tail -50

        case wifi
            _info "WiFi logs (last 30 min):"
            _echo
            journalctl -u NetworkManager -u iwd --since "30 minutes ago" --no-pager 2>/dev/null | tail -50

        case boot
            _info "Boot logs:"
            _echo
            journalctl -b --no-pager 2>/dev/null | head -100

        case audio
            _info "Audio logs:"
            _echo
            journalctl --user -u pipewire -u wireplumber --since "1 hour ago" --no-pager 2>/dev/null | tail -50

        case usb
            _info "USB events:"
            _echo
            sudo dmesg 2>/dev/null | grep -iE "usb|hub" | tail -30

        case '*'
            # Reject flags passed as targets (e.g., --logs -b)
            if string match -q -- '-*' "$target"
                _warn "Invalid log target: '$target' (looks like a flag)"
                _info "Valid targets: system, gpu, wifi, boot, audio, usb, <service>"
                return 1
            end
            # Treat as service name
            _info "Logs for $target:"
            _echo
            if systemctl cat "$target" >/dev/null 2>&1
                journalctl -u "$target" --since "1 hour ago" --no-pager 2>/dev/null | tail -50
            else
                _warn "Service '$target' not found"
                _info "Try: systemctl list-units '*$target*'"
            end
    end
end

# Automated system diagnostics
function do_diagnose
    _echo "┌──────────────────────────────────────────────────────────────────┐"
    _echo "│  ry-install v$VERSION - System Diagnostics                       │"
    _echo "└──────────────────────────────────────────────────────────────────┘"
    _echo

    set -l issues 0

    # 1. Check for kernel errors
    _echo "── Kernel Errors ──"
    if command -q sudo
        set -l kernel_errors (sudo dmesg --level=err 2>/dev/null | wc -l | string trim)
        if test -n "$kernel_errors"; and string match -qr '^\d+$' "$kernel_errors"; and test "$kernel_errors" -gt 0
            _warn "Found $kernel_errors kernel error(s)"
            sudo dmesg --level=err 2>/dev/null | tail -5
            set issues (math $issues + 1)
        else
            _ok "No kernel errors"
        end
    else
        _info "sudo not available for dmesg check"
    end
    _echo

    # 2. Check failed services
    _echo "── Failed Services ──"
    set -l failed (systemctl --failed --no-pager 2>/dev/null | grep -c "failed" | string trim)
    if test -n "$failed"; and string match -qr '^\d+$' "$failed"; and test "$failed" -gt 0
        _warn "Found $failed failed service(s):"
        systemctl --failed --no-pager 2>/dev/null | grep failed | head -5
        set issues (math $issues + 1)
    else
        _ok "No failed services"
    end
    _echo

    # 3. Check expected services
    _echo "── Expected Services ──"
    for svc in amdgpu-performance cpupower-epp fstrim.timer NetworkManager
        set -l state (systemctl is-active $svc 2>/dev/null)
        if test "$state" = "active"
            _ok "$svc: active"
        else
            _warn "$svc: $state"
            set issues (math $issues + 1)
        end
    end
    _echo

    # 4. Check GPU state
    _echo "── GPU State ──"
    set -l perf_level ""
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set perf_level (cat "$f" 2>/dev/null)
            break
        end
    end
    if test "$perf_level" = "high"
        _ok "GPU performance: high"
    else if test -n "$perf_level"
        _warn "GPU performance: $perf_level (expected: high)"
        set issues (math $issues + 1)
    else
        _warn "Cannot read GPU performance level"
        set issues (math $issues + 1)
    end
    _echo

    # 5. Check CPU governor
    _echo "── CPU State ──"
    set -l governor (cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    if test "$governor" = "performance"
        _ok "CPU governor: performance"
    else if test -n "$governor"
        _warn "CPU governor: $governor (expected: performance)"
        set issues (math $issues + 1)
    end

    set -l epp (cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
    if test "$epp" = "performance"
        _ok "CPU EPP: performance"
    else if test -n "$epp"
        _warn "CPU EPP: $epp (expected: performance)"
        set issues (math $issues + 1)
    end
    _echo

    # 6. Check disk space
    _echo "── Disk Space ──"
    set -l root_pct (df / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    if test -n "$root_pct"; and string match -qr '^\d+$' "$root_pct"
        if test "$root_pct" -ge 90
            _fail "Root filesystem: $root_pct% (critical)"
            set issues (math $issues + 1)
        else if test "$root_pct" -ge 80
            _warn "Root filesystem: $root_pct% (getting full)"
            set issues (math $issues + 1)
        else
            _ok "Root filesystem: $root_pct%"
        end
    end
    _echo

    # 7. Check temperatures
    _echo "── Temperatures ──"
    if command -q sensors
        set -l cpu_temp (sensors 2>/dev/null | grep -E "Tctl|Tdie" | head -1 | grep -oE '\+[0-9.]+' | head -1 | tr -d '+')
        if test -n "$cpu_temp"
            set -l temp_int (string split '.' "$cpu_temp")[1]
            if test -n "$temp_int"; and string match -qr '^\d+$' "$temp_int"
                if test "$temp_int" -ge 90
                    _fail "CPU: $cpu_temp°C (throttling likely)"
                    set issues (math $issues + 1)
                else if test "$temp_int" -ge 85
                    _warn "CPU: $cpu_temp°C (high)"
                    set issues (math $issues + 1)
                else
                    _ok "CPU: $cpu_temp°C"
                end
            else
                _info "CPU: $cpu_temp°C (unable to parse for threshold check)"
            end
        end
    else
        _info "Install lm_sensors for temperature monitoring"
    end
    _echo

    # 8. Check WiFi
    _echo "── Network ──"
    if command -q nmcli
        set -l wifi_state (nmcli -t -f WIFI g 2>/dev/null)
        set -l conn_state (nmcli -t -f STATE g 2>/dev/null)
        if test "$conn_state" = "connected"
            _ok "Network: connected"
        else
            _warn "Network: $conn_state"
            set issues (math $issues + 1)
        end
    end
    _echo

    # 9. Check ntsync
    _echo "── Gaming ──"
    if test -c /dev/ntsync
        _ok "ntsync: available"
    else
        _info "ntsync: not available (kernel 6.14+ required)"
    end
    _echo

    # 10. Recent OOM events
    _echo "── Memory ──"
    if command -q sudo
        set -l oom_count (sudo dmesg 2>/dev/null | grep -c "Out of memory" | string trim)
        if test -n "$oom_count"; and string match -qr '^\d+$' "$oom_count"; and test "$oom_count" -gt 0
            _warn "OOM events detected: $oom_count"
            set issues (math $issues + 1)
        else
            _ok "No OOM events"
        end
    else
        _info "sudo not available for OOM check"
    end
    _echo

    # 11. Kernel taint check
    _echo "── Kernel Taint ──"
    set -l taint (cat /proc/sys/kernel/tainted 2>/dev/null)
    if test -n "$taint"; and string match -qr '^\d+$' "$taint"; and test "$taint" != "0"
        _warn "Kernel tainted: $taint"
        # Decode common taint flags (fish math doesn't support bitwise &, use modular arithmetic)
        if test (math "floor($taint / 1) % 2") -eq 1
            _info "  - Proprietary module loaded"
        end
        if test (math "floor($taint / 4096) % 2") -eq 1
            _info "  - Out-of-tree module loaded"
        end
        set issues (math $issues + 1)
    else if test -n "$taint"; and test "$taint" = "0"
        _ok "Kernel not tainted"
    else
        _info "Could not read kernel taint status"
    end
    _echo

    # 12. Coredumps check
    _echo "── Coredumps ──"
    if command -q coredumpctl
        set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
        if test -n "$dump_count"; and string match -qr '^\d+$' (string trim "$dump_count"); and test "$dump_count" -gt 0
            _warn "Found $dump_count coredump(s)"
            coredumpctl list --no-pager 2>/dev/null | tail -5
            set issues (math $issues + 1)
        else
            _ok "No coredumps"
        end
    else
        _info "coredumpctl not available"
    end
    _echo

    # 13. Journal disk usage
    _echo "── Journal Size ──"
    set -l journal_size (journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[GMK]' | head -1)
    if test -n "$journal_size"
        # Extract numeric part
        set -l size_num (string replace -r '[^0-9.]' '' "$journal_size")
        set -l size_unit (string replace -r '[0-9.]' '' "$journal_size")
        if test -n "$size_num"; and string match -qr '^[0-9.]+$' "$size_num"; and test "$size_unit" = "G"
            set -l size_int (math "floor($size_num)" 2>/dev/null)
            if test -n "$size_int"; and test "$size_int" -ge 2
                _warn "Journal using $journal_size (consider: journalctl --vacuum-size=500M)"
                set issues (math $issues + 1)
            else
                _ok "Journal size: $journal_size"
            end
        else
            _ok "Journal size: $journal_size"
        end
    end
    _echo

    # 14. NVMe health (if nvme-cli installed)
    _echo "── NVMe Health ──"
    if command -q nvme
        for dev in /dev/nvme[0-9]
            if test -e "$dev"
                set -l smart (sudo nvme smart-log $dev 2>/dev/null)
                if test -n "$smart"
                    set -l pct_used (printf '%s\n' $smart | grep -i "percentage_used" | awk '{print $NF}' | tr -d '%')
                    set -l crit_warn (printf '%s\n' $smart | grep -i "critical_warning" | awk '{print $NF}')

                    if test -n "$crit_warn"; and test "$crit_warn" != "0"
                        _fail "$dev: Critical warning flag set!"
                        set issues (math $issues + 1)
                    else if test -n "$pct_used"; and string match -qr '^\d+$' "$pct_used"; and test "$pct_used" -ge 90
                        _warn "$dev: $pct_used% life used"
                        set issues (math $issues + 1)
                    else if test -n "$pct_used"; and string match -qr '^\d+$' "$pct_used"
                        _ok "$dev: $pct_used% life used"
                    else
                        _ok "$dev: healthy"
                    end
                else
                    _info "$dev: smart-log requires sudo"
                end
            end
        end
    else
        _info "nvme-cli not installed (install for NVMe health monitoring)"
    end
    _echo

    # 15. Boot time analysis
    _echo "── Boot Performance ──"
    if command -q systemd-analyze
        set -l boot_line (systemd-analyze 2>/dev/null | head -1)
        set -l boot_sec (echo "$boot_line" | string match -r '= ([0-9.]+)s' | tail -1)
        if test -n "$boot_sec"; and string match -qr '^[0-9.]+$' "$boot_sec"
            set -l boot_int (math "floor($boot_sec)" 2>/dev/null)
            if test -n "$boot_int"; and test "$boot_int" -ge 30
                _warn "Slow boot: $boot_sec""s (run: systemd-analyze blame)"
                set issues (math $issues + 1)
            else
                _ok "Boot time: $boot_sec""s"
            end
        else if test -n "$boot_line"
            _info "$boot_line"
        end
    end
    _echo

    # 16. sched-ext scheduler check (BORE kernel does not support sched-ext)
    _echo "── sched-ext Scheduler ──"
    if systemctl is-active --quiet scx_loader.service 2>/dev/null
        _warn "scx_loader.service is active (not compatible with BORE kernel)"
        _info "  Disable with: sudo systemctl disable --now scx_loader.service"
        set issues (math $issues + 1)
    else
        set -l scx_running false
        for scx_svc in scx_lavd scx_bpfland scx_rusty scx_rustland
            if pgrep -x "$scx_svc" >/dev/null 2>&1
                _warn "$scx_svc is running (not compatible with BORE kernel)"
                set scx_running true
                set issues (math $issues + 1)
            end
        end
        if test "$scx_running" = false
            _ok "No sched-ext schedulers active (BORE kernel)"
        end
    end
    _echo

    # 17. Linux firmware version check
    _echo "── Linux Firmware ──"
    if command -q pacman
        set -l fw_ver (pacman -Q linux-firmware 2>/dev/null | awk '{print $2}')
        if test -n "$fw_ver"
            _info "linux-firmware: $fw_ver"
            # Known bad version: 20251125 breaks ROCm on Strix Halo (gfx1151)
            if string match -q '*20251125*' "$fw_ver"
                _warn "linux-firmware 20251125 has a known regression on Strix Halo"
                _info "  ROCm/compute workloads may fail. Use 20251111 or ≥20260110."
                set issues (math $issues + 1)
            end
        else
            _info "linux-firmware: not installed"
        end
    end
    _echo

    # Summary
    _echo "════════════════════════════════════════════════════════════════════"
    if test $issues -eq 0
        _ok "Diagnostics complete: No issues found (17 checks passed)"
    else
        _warn "Diagnostics complete: $issues issue(s) found"
        _info "Run './ry-install.fish --logs system' for more details"
    end

    return $issues
end

# ─── INSTALLATION SUB-FUNCTIONS ───────────────────────────────────────────────
# do_install orchestrates these in sequence. Each function handles its own
# progress steps and error reporting. Functions set INSTALL_HAD_ERRORS on
# non-fatal failures. Fatal failures return 1 to abort.

# Collect WiFi credentials upfront for reconnection at end of install
function _install_collect_wifi
    # Initialize WiFi globals
    set -g WIFI_SSID ""
    set -g WIFI_PASS ""
    set -g WIFI_IFACE ""

    if test "$DRY" != true; and _ask "Reconnect WiFi at end of installation?"
        if not command -q nmcli
            # Print directly since QUIET=true in default install mode
            if test "$NO_COLOR" = true
                echo "[WARN] nmcli not found - WiFi reconnection will be skipped"
            else
                set_color yellow; echo -n "[WARN]"; set_color normal; echo " nmcli not found - WiFi reconnection will be skipped"
            end
        else
            # Detect WiFi interface
            set -l wlan_iface ""

            # Method 1: Parse iwctl device list (if available)
            if command -q iwctl
                set -l iwctl_output (iwctl device list 2>/dev/null)
                if test -n "$iwctl_output"
                    set wlan_iface (printf '%s\n' $iwctl_output | awk '
                        NR > 4 && /station/ {
                            for(i=1; i<=NF; i++) {
                                if($i ~ /^wl/ || $i ~ /^wlan/) { print $i; exit }
                            }
                            if($2 !~ /^-+$/) print $2; exit
                        }' | head -1)
                end
            end

            # Method 2: Check sysfs
            if test -z "$wlan_iface"
                for iface in /sys/class/net/*/wireless
                    if test -d "$iface"
                        set wlan_iface (basename (dirname "$iface"))
                        break
                    end
                end
            end

            if test -z "$wlan_iface"
                # Print directly since QUIET=true in default install mode
                if test "$NO_COLOR" = true
                    echo "[WARN] Could not detect WiFi interface"
                else
                    set_color yellow; echo -n "[WARN]"; set_color normal; echo " Could not detect WiFi interface"
                end
                read -P "[?] Enter WiFi interface name: " wlan_iface
                # Validate interface name: alphanumeric and underscore only, max 15 chars
                if not string match -qr '^[a-zA-Z0-9_]+$' "$wlan_iface"; or test (string length -- "$wlan_iface") -gt 15
                    if test "$NO_COLOR" = true
                        echo "[ERR] Invalid interface name: must be alphanumeric, max 15 chars"
                    else
                        set_color red; echo -n "[ERR]"; set_color normal; echo " Invalid interface name: must be alphanumeric, max 15 chars"
                    end
                    set wlan_iface ""
                end
            end

            if test -n "$wlan_iface"
                set -g WIFI_IFACE "$wlan_iface"
                # Print directly since QUIET=true in default install mode
                if test "$NO_COLOR" = true
                    echo "[INFO] WiFi interface: $wlan_iface"
                else
                    set_color blue; echo -n "[INFO]"; set_color normal; echo " WiFi interface: $wlan_iface"
                end

                read -P "[?] WiFi SSID: " wifi_ssid
                if test -n "$wifi_ssid"
                    # Validate SSID: reject dangerous characters (path separators, shell metacharacters, newlines)
                    if string match -qr "[/\\\\;`\$(){}|<>&'\\\"%!]" "$wifi_ssid"; or string match -qr '\n|\r' "$wifi_ssid"
                        # Print directly since QUIET=true in default install mode
                        if test "$NO_COLOR" = true
                            echo "[ERR] Invalid SSID: contains forbidden characters"
                            echo '[INFO] SSIDs cannot contain: / \\ ; ` $ ( ) { } | < > & \' \\ " % ! or newlines'
                        else
                            set_color red; echo -n "[ERR]"; set_color normal; echo " Invalid SSID: contains forbidden characters"
                            set_color blue; echo -n "[INFO]"; set_color normal; echo ' SSIDs cannot contain: / \\ ; ` $ ( ) { } | < > & \' \\ " % ! or newlines'
                        end
                    else if string match -q '*..*' "$wifi_ssid"
                        if test "$NO_COLOR" = true
                            echo "[ERR] Invalid SSID: contains path traversal sequence"
                        else
                            set_color red; echo -n "[ERR]"; set_color normal; echo " Invalid SSID: contains path traversal sequence"
                        end
                    else if test (string length -- "$wifi_ssid") -gt 32
                        if test "$NO_COLOR" = true
                            echo "[ERR] Invalid SSID: must be 1-32 characters"
                        else
                            set_color red; echo -n "[ERR]"; set_color normal; echo " Invalid SSID: must be 1-32 characters"
                        end
                    else
                        set -g WIFI_SSID "$wifi_ssid"
                        read -sP "[?] WiFi passphrase: " wifi_pass
                        echo  # Newline after hidden passphrase input
                        # Validate passphrase: reject newlines (would corrupt nmconnection file)
                        if string match -qr '\n|\r' "$wifi_pass"
                            if test "$NO_COLOR" = true
                                echo "[ERR] Invalid passphrase: contains newline"
                            else
                                set_color red; echo -n "[ERR]"; set_color normal; echo " Invalid passphrase: contains newline"
                            end
                        else if test (string length -- "$wifi_pass") -lt 8; or test (string length -- "$wifi_pass") -gt 63
                            if test "$NO_COLOR" = true
                                echo "[ERR] Invalid passphrase: WPA2 requires 8-63 characters"
                            else
                                set_color red; echo -n "[ERR]"; set_color normal; echo " Invalid passphrase: WPA2 requires 8-63 characters"
                            end
                        else
                            set -g WIFI_PASS "$wifi_pass"
                            if test "$NO_COLOR" = true
                                echo "[OK] WiFi credentials saved (will connect at end)"
                            else
                                set_color green; echo -n "[OK]"; set_color normal; echo " WiFi credentials saved (will connect at end)"
                            end
                        end
                    end
                end
            end
        end
    end
end

# Pre-flight checks: sudo, deps, disk space, network, kernel, secure boot, bios, validate
function _install_preflight
    _progress "Checking dependencies"

    # Default to true; check_kernel_version (inside DRY=false block) may override
    set -g NTSYNC_SUPPORTED true

    if test "$DRY" = false
        _info "Sudo password required for installation..."
        # Move cursor off progress bar line so sudo prompt gets its own line
        if test "$ALL" = true
            printf '\n'
        end
        if not sudo true
            _err "Sudo required for installation"
            exit 1
        end
        # Keep sudo alive in background for long installations
        # Redirect stdin from /dev/null to prevent stdin contention with main script
        fish -c 'while true; sudo -n true 2>/dev/null; sleep 50; end' </dev/null &
        set -g SUDO_KEEPALIVE_PID $last_pid

        # Cleanup handler for abnormal exit (INT/TERM/HUP signals)
        # Erase any existing handler first (idempotency)
        functions -e __cleanup_sudo_keepalive 2>/dev/null
        function __cleanup_sudo_keepalive --on-signal INT --on-signal TERM --on-signal HUP --on-event fish_exit
            if set -q SUDO_KEEPALIVE_PID
                kill $SUDO_KEEPALIVE_PID 2>/dev/null
            end
        end

        if not check_deps
            kill $SUDO_KEEPALIVE_PID 2>/dev/null
            exit 1
        end

        # Check disk space before proceeding
        if not check_disk_space
            kill $SUDO_KEEPALIVE_PID 2>/dev/null
            exit 1
        end

        # Check network connectivity (required for package operations)
        if not check_network
            _warn "Continuing without network - package operations may fail"
        end

        # Check kernel version for feature compatibility
        check_kernel_version

        # Check for sched-ext schedulers (incompatible with BORE kernel)
        check_sched_ext

        # Check Secure Boot status
        check_secure_boot

        # Show BIOS version (helpful for Strix Halo troubleshooting)
        show_bios_info

        # Validate all configuration syntax before proceeding
        _echo
        if not validate_configs
            _err "Configuration validation failed - aborting"
            if set -q SUDO_KEEPALIVE_PID
                kill $SUDO_KEEPALIVE_PID 2>/dev/null
            end
            return 1
        end
    end
end

# Create timestamped backup directory with subdirs for each destination
function _install_backup
    _progress "Creating backup directory"
    _echo
    _info "Creating backup directory..."

    if test "$DRY" = true
        _info "Would create backup dir: $BACKUP_DIR"
    else
        # Dynamically derive backup directories from destinations
        set -l backup_dirs "$BACKUP_DIR/other"  # Fallback directory

        for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
            set -l backup_path ""
            if string match -q "$HOME/*" "$dst"
                set backup_path "$BACKUP_DIR/home/"(dirname (string replace "$HOME/" "" "$dst"))
            else if string match -q "/boot/*" "$dst"
                set backup_path "$BACKUP_DIR/boot/"(dirname (string replace "/boot/" "" "$dst"))
            else if string match -q "/etc/*" "$dst"
                set backup_path "$BACKUP_DIR/etc/"(dirname (string replace "/etc/" "" "$dst"))
            end
            if test -n "$backup_path"; and not contains "$backup_path" $backup_dirs
                set -a backup_dirs "$backup_path"
            end
        end

        for dir in $backup_dirs
            if not mkdir -p "$dir" 2>/dev/null
                _err "Failed to create backup directory: $dir"
                if set -q SUDO_KEEPALIVE_PID
                    kill $SUDO_KEEPALIVE_PID 2>/dev/null
                end
                return 1
            end
        end
        chmod 700 "$BACKUP_DIR" 2>/dev/null  # Restrict backup directory permissions
        _ok "Backup directory: $BACKUP_DIR"
    end
end

# Sync databases, upgrade system, install packages
function _install_packages
    _progress "Syncing packages"
    _echo
    _info "Synchronizing package databases..."

    # PACKAGE INSTALLATION
    # Note: -Sy and -S are merged into -Syu to prevent partial upgrades.
    # A separate -Sy followed by -S can leave the system in a broken state
    # if dependencies were updated in the db but base packages were not upgraded.

    _progress "Installing packages"
    _echo
    _info "Package installation..."

    set -l pkgs_to_install $PKGS_ADD
    if grep -E '^\[cachyos\]' /etc/pacman.conf >/dev/null 2>&1
        set -a pkgs_to_install yay
        _info "CachyOS detected: including yay"
    end

    set -g SYSTEM_UPGRADED false
    if _ask "Sync databases, upgrade system, and install packages? ($pkgs_to_install)"
        set -g SYSTEM_UPGRADED true

        # Pre-deploy mkinitcpio.conf before pacman so kernel upgrade hooks
        # build initramfs with our config (correct HOOKS/MODULES), not the
        # old on-disk config (which may still contain plymouth, etc.).
        # Full backup + deployment happens again in _install_system_files;
        # the second write is a no-op (identical content).
        if test "$DRY" = false
            backup_file /etc/mkinitcpio.conf true
            install_file /etc/mkinitcpio.conf true
        end

        if test (count $pkgs_to_install) -gt 0
            if not _run sudo pacman -Syu --needed --noconfirm -- $pkgs_to_install
                _warn "Package installation failed, retrying with fresh sync..."
                if not _run sudo pacman -Syyu --needed --noconfirm -- $pkgs_to_install
                    _err "Package installation failed after retry"
                    set -g INSTALL_HAD_ERRORS true
                end
            end

            # Verify all packages installed (skip in dry-run mode)
            if test "$DRY" = false
                _info "Verifying package installation..."
                set -l missing_pkgs
                for pkg in $pkgs_to_install
                    if not pacman -Qi "$pkg" >/dev/null 2>&1
                        set -a missing_pkgs $pkg
                    end
                end
                if test (count $missing_pkgs) -gt 0
                    _err "Missing packages: $missing_pkgs"
                    _warn "  Install manually: sudo pacman -S $missing_pkgs"
                    set -g INSTALL_HAD_ERRORS true
                else
                    _ok "All packages verified installed"
                end
            end
        end
    end
end

# Install system config files, handle LUKS, set wireless regulatory domain
function _install_system_files
    # SYSTEM FILES INSTALLATION
    _progress "Installing system files"
    _echo
    _info "Installing system configuration files..."
    if not install_files $SYSTEM_DESTINATIONS true "SYSTEM FILES"
        _err "System file installation failed"
        set -g INSTALL_HAD_ERRORS true
    end

    # LUKS ENCRYPTION CHECK
    _progress "Checking disk encryption"
    _echo
    _info "Checking for disk encryption..."

    set -l has_luks false
    if lsblk -o FSTYPE 2>/dev/null | grep -q 'crypto_LUKS'
        set has_luks true
    else if test -f /etc/crypttab; and grep -qE '^[^#[:space:]]' /etc/crypttab 2>/dev/null
        set has_luks true
    end

    if test "$has_luks" = true
        _warn "LUKS ENCRYPTION DETECTED"
        _warn "The sd-encrypt hook MUST be added or system will NOT BOOT"

        if _ask "Add sd-encrypt hook to mkinitcpio.conf?"
            # Check if sd-encrypt is already present
            if grep -qE 'HOOKS=.*sd-encrypt' /etc/mkinitcpio.conf 2>/dev/null
                _ok "sd-encrypt hook already present"
            else if test "$DRY" = false
                set -l dst_dir (dirname /etc/mkinitcpio.conf)
                set -l tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX)
                if test -z "$tmpfile"
                    _err "Failed to create temp file for mkinitcpio.conf"
                    set -g INSTALL_HAD_ERRORS true
                else
                    if sudo sed 's/\(block\) \(filesystems\)/\1 sd-encrypt \2/' /etc/mkinitcpio.conf | sudo tee "$tmpfile" >/dev/null
                        sudo chmod 0644 "$tmpfile"
                        if not sudo mv "$tmpfile" /etc/mkinitcpio.conf
                            sudo rm -f "$tmpfile" 2>/dev/null
                            _err "Failed to install sd-encrypt hook (mv failed)"
                            set -g INSTALL_HAD_ERRORS true
                        else if not sudo chown root:root /etc/mkinitcpio.conf
                            _err "Failed to set ownership on mkinitcpio.conf"
                            set -g INSTALL_HAD_ERRORS true
                        else
                            _ok "Added sd-encrypt hook"
                        end
                    else
                        sudo rm -f "$tmpfile" 2>/dev/null
                        _err "Failed to add sd-encrypt hook"
                        set -g INSTALL_HAD_ERRORS true
                    end
                end
            else
                _log "DRY: Add sd-encrypt hook to /etc/mkinitcpio.conf"
                if test "$QUIET" = false
                    if test "$NO_COLOR" = true
                        echo "[DRY] Add sd-encrypt hook to /etc/mkinitcpio.conf"
                    else
                        set_color cyan; echo "[DRY] Add sd-encrypt hook to /etc/mkinitcpio.conf"; set_color normal
                    end
                end
            end
        else
            _err "ABORTING: Cannot safely continue on LUKS system"
            if set -q SUDO_KEEPALIVE_PID
                kill $SUDO_KEEPALIVE_PID 2>/dev/null
            end
            return 1
        end
    else
        _ok "No LUKS encryption detected"
    end

    # WIRELESS REGULATORY DOMAIN
    _progress "Wireless regulatory domain"
    _echo
    _info "Wireless regulatory domain (current: US)"
    _info "Common codes: US, GB, DE, FR, JP, AU, CA"

    if test "$DRY" != true; and not test "$ALL" = true
        read -P "[?] Enter your country code (or Enter for US): " regdom_input
        if test -n "$regdom_input"
            # Normalize to uppercase first, then validate
            set -l regdom_upper (string upper -- "$regdom_input" | string trim)

            if not string match -qr '^[A-Z]{2}$' "$regdom_upper"
                _err "Invalid country code: '$regdom_input' (must be 2 letters, e.g., US, GB, DE)"
            else if test "$DRY" = false
                set -l dst_dir (dirname /etc/conf.d/wireless-regdom)
                set -l tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX)
                if test -z "$tmpfile"
                    _err "Failed to create temp file for wireless-regdom"
                else
                    if sudo sed "s/WIRELESS_REGDOM=\"[A-Z]*\"/WIRELESS_REGDOM=\"$regdom_upper\"/" /etc/conf.d/wireless-regdom | sudo tee "$tmpfile" >/dev/null
                        sudo chmod 0644 "$tmpfile"
                        if not sudo mv "$tmpfile" /etc/conf.d/wireless-regdom
                            sudo rm -f "$tmpfile" 2>/dev/null
                            _err "Failed to set regulatory domain (mv failed)"
                        else if not sudo chown root:root /etc/conf.d/wireless-regdom
                            _err "Failed to set ownership on wireless-regdom"
                        else
                            # Verify the value was actually set (sed no-ops if all lines are commented)
                            if sudo grep -q "^WIRELESS_REGDOM=\"$regdom_upper\"" /etc/conf.d/wireless-regdom 2>/dev/null
                                _ok "Set regulatory domain to: $regdom_upper"
                            else
                                _warn "Regulatory domain not found in file — appending"
                                echo "WIRELESS_REGDOM=\"$regdom_upper\"" | sudo tee -a /etc/conf.d/wireless-regdom >/dev/null
                                _ok "Appended regulatory domain: $regdom_upper"
                            end
                        end
                    else
                        sudo rm -f "$tmpfile" 2>/dev/null
                        _err "Failed to set regulatory domain"
                    end
                end
            else
                _log "DRY: Set WIRELESS_REGDOM to $regdom_upper"
                if test "$QUIET" = false
                    if test "$NO_COLOR" = true
                        echo "[DRY] Set WIRELESS_REGDOM to $regdom_upper"
                    else
                        set_color cyan; echo "[DRY] Set WIRELESS_REGDOM to $regdom_upper"; set_color normal
                    end
                end
            end
        end
    end

    # USER FILES INSTALLATION
    _progress "Installing user files"
    _echo
    _info "Installing user configuration files..."
    if not install_files $USER_DESTINATIONS false "USER FILES"
        _err "User file installation failed"
        set -g INSTALL_HAD_ERRORS true
    end

    # AMDGPU PERFORMANCE SERVICE
    _progress "AMDGPU performance service"
    _echo
    _info "AMDGPU performance service (STRONGLY RECOMMENDED)"
    _info "  Udev rule may fail due to timing (Arch bug #72655)"

    if _ask "Install amdgpu-performance.service?"
        if not install_file "/etc/systemd/system/amdgpu-performance.service" true
            _err "Failed to install amdgpu-performance.service"
        else
            _run sudo systemctl daemon-reload
            if not _run sudo systemctl enable --now amdgpu-performance.service
                _warn "Failed to enable amdgpu-performance.service"
            end
        end
    end
end

# Post-install: databases, session dirs, reload, remove pkgs, mask/enable services
function _install_configure_services
    # POST-INSTALLATION TASKS
    _progress "Updating databases"
    _echo
    _info "Post-installation tasks..."

    if _ask "Update plocate database?"
        if command -q updatedb
            if not _run sudo updatedb
                _warn "updatedb failed"
            end
        end
    end

    if _ask "Update pkgfile database?"
        if command -q pkgfile
            if not _run sudo pkgfile --update
                _warn "pkgfile update failed"
            end
        end
    end

    _progress "Session directories"
    if _ask "Create missing session directories?"
        if not _run sudo mkdir -p /usr/share/xsessions /usr/local/share/wayland-sessions /usr/local/share/xsessions
            _warn "Failed to create some session directories"
        end
    end

    _progress "Reloading system config"
    if _ask "Reload udev rules?"
        if not _run sudo udevadm control --reload-rules
            _warn "udevadm reload-rules failed"
        end
        if not _run sudo udevadm trigger
            _warn "udevadm trigger failed"
        end
        if test "$DRY" = false
            _run sudo udevadm settle --timeout=5
        end
    end

    if _ask "Reload sysctl?"
        if not _run sudo sysctl --system
            _warn "sysctl --system failed"
        end
    end

    # Restart systemd-resolved to apply resolved.conf changes
    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        if not _run sudo systemctl restart systemd-resolved
            _warn "systemd-resolved restart failed"
        end
    end

    _progress "Removing packages"
    # Remove conflicting packages
    set -l to_del
    if test "$DRY" = true
        set to_del $PKGS_DEL
    else
        for pkg in $PKGS_DEL
            if command -q pacman; and pacman -Qi "$pkg" >/dev/null 2>&1
                set -a to_del $pkg
            end
        end
    end

    if test (count $to_del) -gt 0
        # Truncate display if many packages
        set -l display_list "$to_del"
        if test (count $to_del) -gt 5
            set -l first_five $to_del[1..5]
            set display_list "$first_five... and "(math (count $to_del) - 5)" more"
        end
        if _ask "Remove conflicting packages? ($display_list)"
            if not _run sudo pacman -Rns --noconfirm -- $to_del
                _warn "Batch removal failed, trying individually..."
                for pkg in $to_del
                    if command -q pacman; and pacman -Qi "$pkg" >/dev/null 2>&1
                        _run sudo pacman -Rns --noconfirm -- $pkg
                    end
                end
            end
        end
    end

    # Mask services (with LVM safety check)
    set -l safe_mask
    set -l has_lvm false

    if test "$DRY" = true
        _info "(dry-run) Skipping LVM detection"
    else
        set -l pvs_output (sudo pvs --noheadings 2>/dev/null | string trim)

        if test -n "$pvs_output"
            set has_lvm true
            _warn "LVM DETECTED - lvm2 services will NOT be masked"
        end
    end

    for svc in $MASK
        if string match -q 'lvm2*' "$svc"
            if test "$has_lvm" = true
                continue
            end
        end
        set -a safe_mask $svc
    end

    _progress "Masking services"
    if test (count $safe_mask) -gt 0
        if _ask "Mask services? ($safe_mask)"
            if not _run sudo systemctl mask -- $safe_mask
                _warn "Failed to mask some services"
            end
        end
    end

    _progress "CPU performance service"
    # EPP Service
    if _ask "Install and enable cpupower-epp.service? (REQUIRED for performance mode)"
        if not install_file "/etc/systemd/system/cpupower-epp.service" true
            _err "Failed to install cpupower-epp.service"
        else
            _run sudo systemctl daemon-reload
            if not _run sudo systemctl enable --now cpupower-epp.service
                _warn "Failed to enable cpupower-epp.service"
            end
        end
    end

    _progress "Enabling timers"
    if _ask "Enable fstrim.timer?"
        if not _run sudo systemctl enable --now fstrim.timer
            _warn "Failed to enable fstrim.timer"
        end
    end

    if _ask "Enable ssh-agent (user, socket-activated)?"
        # Verify the user unit exists (provided by openssh or systemd)
        if systemctl --user cat ssh-agent.service >/dev/null 2>&1
            _run systemctl --user enable --now ssh-agent.service
        else
            _warn "ssh-agent.service user unit not found"
            _info "  Install openssh or create ~/.config/systemd/user/ssh-agent.service"
        end
    end
end

# Rebuild initramfs and update bootloader
function _install_rebuild_boot
    _progress "Rebuilding initramfs"
    # mkinitcpio.conf is pre-deployed before pacman (in _install_packages) so
    # any kernel upgrade hook already used the correct config. However, if no
    # kernel was upgraded, no hook fired and the initramfs still reflects the
    # old config. Explicit rebuild ensures correctness in all cases.
    # Cost: ~6s if redundant (kernel was upgraded); necessary otherwise.
    if _ask "Rebuild initramfs?"
        if not _run sudo mkinitcpio -P
            _err "mkinitcpio failed"
            set -g INSTALL_HAD_ERRORS true
        end
    end

    _progress "Updating bootloader"
    if _ask "Update bootloader?"
        if not _run sudo sdboot-manage gen
            _warn "sdboot-manage gen failed"
            set -g INSTALL_HAD_ERRORS true
        end
        if not _run sudo sdboot-manage update
            _warn "sdboot-manage update failed"
            set -g INSTALL_HAD_ERRORS true
        end

        # Verify boot entries were created
        set -l entry_count (sudo find /boot/loader/entries -name "*.conf" 2>/dev/null | wc -l)
        if test -n "$entry_count"; and string match -qr '^\d+$' (string trim "$entry_count"); and test "$entry_count" -gt 0
            _ok "Boot entries: $entry_count found in /boot/loader/entries/"
        else
            _err "No boot entries found in /boot/loader/entries/"
            _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
            _info "  Try: sudo sdboot-manage gen --verbose"
            set -g INSTALL_HAD_ERRORS true
        end

        # Check initramfs size (warn if unusually large)
        for initrd in /boot/initramfs-*.img
            if test -f "$initrd"
                set -l size_mb (du -m "$initrd" 2>/dev/null | cut -f1)
                if test -n "$size_mb"; and string match -qr '^\d+$' "$size_mb"
                    if test "$size_mb" -gt 100
                        _warn "Large initramfs: $initrd ($size_mb MB) - consider reviewing MODULES/HOOKS"
                    else
                        _ok "Initramfs size: $initrd ($size_mb MB)"
                    end
                end
            end
        end
    end

    _progress "System upgrade"
    if test "$SYSTEM_UPGRADED" = true
        _ok "System already upgraded during package installation"
    else if _ask "Perform full system upgrade? (pacman -Syu)"
        if not _run sudo pacman -Syu --noconfirm
            _warn "System upgrade failed or was interrupted"
            set -g INSTALL_HAD_ERRORS true
        else
            _ok "System upgrade complete"
        end
    end
end

# NM restart, WiFi reconnection, credential cleanup
function _install_finalize
    _progress "Finalizing system"
    if not _run sudo systemctl daemon-reload
        _warn "systemctl daemon-reload failed"
    end
    _run systemctl --user daemon-reload

    if _ask "Clear package cache?"
        if not _run sudo pacman -Sc --noconfirm
            _warn "pacman cache clear failed"
        end
    end

    # NETWORKMANAGER RESTART (switch to iwd backend)
    # Moved to end to preserve network connectivity during system upgrade

    _progress "NetworkManager restart"
    if _ask "Restart NetworkManager (switch to iwd backend)?"
        if command -q pacman; and pacman -Qi iwd >/dev/null 2>&1
            if not _run sudo systemctl restart NetworkManager
                _warn "NetworkManager restart failed"
            end
            # Allow NetworkManager time to initialize iwd backend before WiFi reconnect
            if test "$DRY" = false; and test -n "$WIFI_SSID"
                sleep 3
            end
        else
            _err "iwd package not installed"
            set -g INSTALL_HAD_ERRORS true
        end
    end

    # WIFI RECONNECTION (using credentials collected at start)
    _progress "WiFi reconnection"
    if test -n "$WIFI_SSID"; and test -n "$WIFI_IFACE"; and test -n "$WIFI_PASS"
        _info "Reconnecting WiFi: $WIFI_SSID on $WIFI_IFACE"

        if test "$DRY" = false
            # Create connection profile directly in NetworkManager's system-connections
            set -l conn_file "/etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"

            # Backup existing connection file if present
            if sudo test -f "$conn_file"
                set -l backup_conn "$BACKUP_DIR/etc/NetworkManager/system-connections"
                mkdir -p "$backup_conn" 2>/dev/null
                if sudo cp "$conn_file" "$backup_conn/" 2>/dev/null
                    _info "Backed up existing: $conn_file"
                else
                    _warn "Could not backup existing connection file"
                end
            end

            set -l conn_dir (dirname "$conn_file")
            set -l tmpfile (sudo mktemp -p "$conn_dir" .ry-install.XXXXXX)
            if test -z "$tmpfile"
                set -e WIFI_PASS
                _err "Failed to create temp file for WiFi connection"
            else
                # Generate a deterministic UUID from SSID+interface for idempotent updates
                set -l conn_uuid (printf '%s-%s' "$WIFI_SSID" "$WIFI_IFACE" | md5sum | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\).*/\1-\2-\3-\4-\5/')
                # IPv6 disabled per user preference (single-stack IPv4 network)
                if printf '%s\n' "[connection]" "id=$WIFI_SSID" "uuid=$conn_uuid" "type=wifi" "interface-name=$WIFI_IFACE" "autoconnect=true" "[wifi]" "mode=infrastructure" "ssid=$WIFI_SSID" "[wifi-security]" "key-mgmt=wpa-psk" "psk=$WIFI_PASS" "[ipv4]" "method=auto" "[ipv6]" "method=disabled" | sudo tee "$tmpfile" >/dev/null
                    # Clear passphrase from memory immediately
                    set -e WIFI_PASS
                    sudo chmod 0600 "$tmpfile"
                    if not sudo mv "$tmpfile" "$conn_file"
                        sudo rm -f "$tmpfile" 2>/dev/null
                        _err "WiFi connection profile creation failed"
                    else
                        sudo chown root:root "$conn_file" 2>/dev/null
                        # Reload connections and wait for NM to recognize the profile
                        sudo nmcli connection reload 2>/dev/null
                        # Poll until NM sees the connection (iwd backend needs scan time)
                        set -l reload_wait 0
                        while test $reload_wait -lt 10
                            if nmcli connection show "$WIFI_SSID" >/dev/null 2>&1
                                break
                            end
                            set reload_wait (math $reload_wait + 1)
                            sleep 1
                            # Re-trigger reload and WiFi scan periodically
                            if test (math "$reload_wait % 3") -eq 0
                                sudo nmcli connection reload 2>/dev/null
                                nmcli device wifi rescan ifname "$WIFI_IFACE" 2>/dev/null
                            end
                        end
                        # Activate with retry
                        set -l wifi_retry 0
                        set -l wifi_connected false
                        while test $wifi_retry -lt 3; and test "$wifi_connected" = false
                            if nmcli connection up "$WIFI_SSID" 2>&1
                                set wifi_connected true
                                _ok "WiFi connection established"
                            else
                                set wifi_retry (math $wifi_retry + 1)
                                if test $wifi_retry -lt 3
                                    _info "WiFi connection attempt $wifi_retry failed, retrying in 3s..."
                                    sleep 3
                                    # Retry reload in case NM dropped the profile
                                    sudo nmcli connection reload 2>/dev/null
                                end
                            end
                        end
                        if test "$wifi_connected" = false
                            _err "WiFi connection failed after 3 attempts"
                        end
                    end
                else
                    set -e WIFI_PASS
                    sudo rm -f "$tmpfile" 2>/dev/null
                    _err "WiFi connection profile write failed"
                end
            end
        else
            set -e WIFI_PASS
            _log "DRY: Create $WIFI_SSID.nmconnection and activate"
            if test "$QUIET" = false
                if test "$NO_COLOR" = true
                    echo "[DRY] Create /etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"
                else
                    set_color cyan; echo "[DRY] Create /etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"; set_color normal
                end
            end
        end
    else if test -n "$WIFI_SSID"; and test -n "$WIFI_IFACE"
        # SSID provided but passphrase was empty
        _warn "WiFi reconnection skipped (empty passphrase)"
    else if test -n "$WIFI_IFACE"
        # Interface detected but no credentials provided
        _info "WiFi reconnection skipped (no credentials provided)"
    end
    # Clear any remaining WiFi globals
    set -e WIFI_SSID 2>/dev/null
    set -e WIFI_PASS 2>/dev/null
    set -e WIFI_IFACE 2>/dev/null
end


# MAIN INSTALLATION

# Main installation workflow: packages, configs, services, mkinitcpio
# Sub-functions: _install_collect_wifi, _install_preflight, _install_backup,
#   _install_packages, _install_system_files, _install_configure_services,
#   _install_rebuild_boot, _install_finalize
function do_install
    _log "=== INSTALLATION START ==="
    _log "VERSION: $VERSION"
    _log "DRY: $DRY"
    _log "ALL: $ALL"

    _echo
    _echo "ry-install v$VERSION"
    _echo

    if test "$DRY" = true
        _warn "DRY-RUN MODE - No changes will be made"
        _echo
    end

    # Collect WiFi credentials upfront (used at end for reconnection)
    _install_collect_wifi
    _echo

    # Initialize progress bar for --all mode
    _progress_init

    # Pre-flight: sudo, deps, disk, network, kernel, secure boot, validate
    if not _install_preflight
        return 1
    end

    # Create timestamped backup directory
    if not _install_backup
        return 1
    end

    # Sync databases, upgrade system, install packages
    _install_packages

    # System files, LUKS check, regulatory domain, user files, AMDGPU service
    if not _install_system_files
        return 1
    end

    # Post-install tasks, remove pkgs, mask/enable services
    _install_configure_services

    # Rebuild initramfs, update bootloader, system upgrade
    _install_rebuild_boot

    # NM restart, WiFi reconnection, cleanup
    _install_finalize

    # COMPLETION

    # Complete progress bar
    _progress_done

    # Kill sudo keepalive background process
    if set -q SUDO_KEEPALIVE_PID
        kill $SUDO_KEEPALIVE_PID 2>/dev/null
    end

    # Remove signal handler (cleanup)
    functions -e __cleanup_sudo_keepalive 2>/dev/null

    _echo
    if test "$INSTALL_HAD_ERRORS" = true
        _echo "INSTALLATION COMPLETE (WITH WARNINGS)"
    else
        _echo "INSTALLATION COMPLETE"
    end
    _echo

    if test "$INSTALL_HAD_ERRORS" = true
        _err "Some steps had errors - review log for details"
        _echo
    end

    _info "Manual steps required:"
    _info "  1. Review /etc/fstab mount options"
    _info "  2. Run 'rehash' or start new shell (updates command paths)"
    _info "  3. REBOOT to apply kernel cmdline and module changes"
    _echo
    _info "Backup location: $BACKUP_DIR"
    _info "Post-reboot verification: ./ry-install.fish --verify"
    _echo

    if test "$INSTALL_HAD_ERRORS" = true
        _warn "Done (with warnings - see above)"
    else
        _ok "Done!"
    end

    _log "=== INSTALLATION END ==="
end

# LINT CHECK

function do_lint
    _log "=== LINT CHECK START ==="
    _info "Running fish syntax check..."
    _echo

    set -l script_path (status filename)

    # Check if script is being sourced vs executed directly
    if test "$script_path" != (status current-filename 2>/dev/null; or echo "$script_path")
        _warn "Script appears to be sourced; lint results may vary"
    end

    set -l has_errors false

    _echo "── Fish Syntax Check ──"
    if fish -n "$script_path" 2>&1
        _ok "ry-install.fish: syntax valid"
    else
        set has_errors true
        _fail "ry-install.fish: syntax errors detected"
    end
    _echo

    _echo "── Anti-pattern Check ──"

    # Strip comments before checking for bash patterns
    # Create temp file with comments removed for accurate scanning
    set -l clean_content (sed 's/#.*//' "$script_path")

    set -l bash_subst (printf '%s\n' $clean_content | grep -n '\$(' 2>/dev/null | grep -v 'echo.*\$(\|string match\|\\\$('; or true)
    if test -n "$bash_subst"
        _warn "Possible bash-style \$() found:"
        set -l lint_out (printf '%s\n' $bash_subst | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_subst | sed 's/^/  /'
        end
    else
        _ok "No bash-style \$() substitution found"
    end

    set -l bash_cond (printf '%s\n' $clean_content | grep -n '\[\[' 2>/dev/null | grep -v 'sed\|grep\|awk\|string match'; or true)
    if test -n "$bash_cond"
        _fail "Bash-style [[ ]] found:"
        set -l lint_out (printf '%s\n' $bash_cond | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_cond | sed 's/^/  /'
        end
        set has_errors true
    else
        _ok "No bash-style [[ ]] conditionals found"
    end

    set -l bash_export (printf '%s\n' $clean_content | grep -n '^[[:space:]]*export ' 2>/dev/null; or true)
    if test -n "$bash_export"
        _fail "Bash-style 'export' found:"
        set -l lint_out (printf '%s\n' $bash_export | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_export | sed 's/^/  /'
        end
        set has_errors true
    else
        _ok "No bash-style 'export' found"
    end
    _echo

    _echo "── Internal Consistency ──"
    # Verify file count matches expected total (computed from arrays)
    set -l total (math (count $SYSTEM_DESTINATIONS) + (count $USER_DESTINATIONS) + (count $SERVICE_DESTINATIONS))
    # Count case statements in get_file_content function (exclude catch-all case '*')
    set -l case_count (sed -n '/^function get_file_content/,/^end$/p' "$script_path" | grep -cE "case [\"'](/|\\*/.)")
    if test $total -eq $case_count
        _ok "File count verified: $total destinations = $case_count content cases"
    else
        _fail "File count mismatch: $total destinations but $case_count content cases"
        set has_errors true
    end

    # Verify PROGRESS_STEPS count matches actual _progress calls in install functions
    set -l steps_count (count $PROGRESS_STEPS)
    # Count _progress calls across all installation sub-functions and do_install orchestrator
    set -l progress_calls (grep -c '_progress "' "$script_path")
    # Subtract non-install _progress references (this lint check line itself, comments, etc.)
    set progress_calls (sed -n '/^function _install_/,/^end$/p; /^function do_install/,/^end$/p' "$script_path" | grep -c '_progress "')
    if test $steps_count -eq $progress_calls
        _ok "Progress steps verified: $steps_count steps = $progress_calls calls"
    else
        _fail "Progress mismatch: PROGRESS_STEPS has $steps_count, but do_install has $progress_calls _progress calls"
        set has_errors true
    end
    _echo

    if test "$has_errors" = true
        _fail "Lint check completed with errors"
        return 1
    else
        _ok "Lint check passed"
        return 0
    end
end

# HELP

function show_help
    echo "
ry-install v$VERSION
Self-contained CachyOS configuration for Beelink GTR9 Pro (Strix Halo)

Usage: "(status filename)" [OPTIONS]

INSTALLATION:
  (no args)         Interactive installation
  --all             Install without prompts (unattended mode)
  --force           Auto-yes all prompts (for --clean, --all, etc.)
  --verbose         Show output on terminal (default: silent, log only)
  --dry-run         Preview changes without modifying system

VERIFICATION:
  --diff            Compare embedded files against installed system
  --verify          Run full verification (static + runtime)
  --verify-static   Check config files exist with correct content
  --verify-runtime  Check live system state (run after reboot)
  --lint            Run fish syntax and anti-pattern checks

UTILITIES:
  --status          Quick system health dashboard
  --watch           Live monitoring mode (temps, power, clocks)
  --clean           System cleanup (cache, journal, orphans)
  --wifi-diag       WiFi diagnostics and troubleshooting
  --benchmark       Quick performance sanity check
  --export          Export system config for sharing/troubleshooting
  --backup-list     List available configuration backups
  --logs <target>   View logs (system, gpu, wifi, boot, audio, usb, <service>)
  --diagnose        Automated problem detection

OPTIONS:
  --no-color        Disable colored output (also respects NO_COLOR env)
  -h, --help        Show this help
  -v, --version     Show version

EXAMPLES:
  ./ry-install.fish              # Interactive installation
  ./ry-install.fish --all        # Unattended installation
  ./ry-install.fish --status     # Check system health
  ./ry-install.fish --clean      # Clean up system
  ./ry-install.fish --clean --force  # Clean up without prompts
  ./ry-install.fish --wifi-diag  # Troubleshoot WiFi

LOG FILE:
  ~/ry-install/logs/MODE-YYYYMMDD-HHMMSS.log

BACKUP:
  ~/ry-install/backup/YYYYMMDD-HHMMSS/
"
end

# ENTRY POINT

set -l MODE install
set -l mode_count 0
set -l LOG_TARGET ""

# Index-based parsing to allow consuming next argument (for --logs)
set -l i 1
while test $i -le (count $argv)
    set -l arg $argv[$i]
    switch $arg
        case --all
            set ALL true
        case --force
            set FORCE true
        case --verbose
            set QUIET false
        case --dry-run
            set DRY true
        case --no-color
            set NO_COLOR true
        case --diff
            set MODE diff
            set mode_count (math $mode_count + 1)
        case --verify
            set MODE verify
            set mode_count (math $mode_count + 1)
        case --verify-static
            set MODE verify-static
            set mode_count (math $mode_count + 1)
        case --verify-runtime
            set MODE verify-runtime
            set mode_count (math $mode_count + 1)
        case --lint
            set MODE lint
            set mode_count (math $mode_count + 1)
        case --status
            set MODE status
            set mode_count (math $mode_count + 1)
        case --watch
            set MODE watch
            set mode_count (math $mode_count + 1)
        case --clean
            set MODE clean
            set mode_count (math $mode_count + 1)
        case --wifi-diag
            set MODE wifi-diag
            set mode_count (math $mode_count + 1)
        case --benchmark
            set MODE benchmark
            set mode_count (math $mode_count + 1)
        case --export
            set MODE export
            set mode_count (math $mode_count + 1)
        case --backup-list
            set MODE backup-list
            set mode_count (math $mode_count + 1)
        case --logs
            set MODE logs
            set mode_count (math $mode_count + 1)
            # Consume next argument as log target if it exists and doesn't start with -
            set -l next_i (math $i + 1)
            if test $next_i -le (count $argv)
                set -l next_arg $argv[$next_i]
                if not string match -q -- '-*' "$next_arg"
                    set LOG_TARGET "$next_arg"
                    set i $next_i  # Skip the consumed argument
                end
            end
        case --diagnose
            set MODE diagnose
            set mode_count (math $mode_count + 1)
        case -h --help
            show_help
            rm -f "$LOG_FILE" 2>/dev/null
            exit 0
        case -v --version
            echo "v$VERSION"
            rm -f "$LOG_FILE" 2>/dev/null
            exit 0
        case '*'
            # Print directly to stderr since QUIET hasn't been adjusted yet
            echo "[ERR] Unknown option: $arg" >&2
            echo
            show_help
            rm -f "$LOG_FILE" 2>/dev/null
            exit 1
    end
    set i (math $i + 1)
end

if test $mode_count -gt 1
    # Print directly to stderr since QUIET hasn't been adjusted yet
    if test "$NO_COLOR" = true
        echo "[ERR] Cannot combine multiple mode flags — run each separately" >&2
    else
        set_color red; echo -n "[ERR]"; set_color normal; echo " Cannot combine multiple mode flags — run each separately" >&2
    end
    rm -f "$LOG_FILE" 2>/dev/null
    exit 1
end

# Non-install modes should show output by default
if test "$MODE" != install
    set QUIET false
end

# Dry-run shows output UNLESS --all is set (--all keeps progress bar only)
if test "$DRY" = true; and test "$ALL" = false
    set QUIET false
end

# Rename log file to include mode name
set -l new_log "$LOG_DIR/$MODE-$TIMESTAMP.log"
if test -f "$LOG_FILE"; and test "$LOG_FILE" != "$new_log"
    mv "$LOG_FILE" "$new_log" 2>/dev/null
end
set -g LOG_FILE "$new_log"
touch "$LOG_FILE" 2>/dev/null; chmod 600 "$LOG_FILE" 2>/dev/null

# Initialize log file
echo "# ry-install v$VERSION" > "$LOG_FILE"
echo "# Started: "(date) >> "$LOG_FILE"
echo "# Command: "(status filename)" $argv" >> "$LOG_FILE"
echo "# Mode: $MODE" >> "$LOG_FILE"
echo "# Dry-run: $DRY" >> "$LOG_FILE"
echo "# Unattended: $ALL" >> "$LOG_FILE"
echo "# Verbose: "(test "$QUIET" = false; and echo true; or echo false) >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Execute requested mode
set -l exit_code 0
switch $MODE
    case diff
        do_diff
    case verify
        verify_static
        set -l static_code $status
        _echo
        verify_runtime
        set -l runtime_code $status
        # Exit with failure if either verification failed
        if test $static_code -ne 0; or test $runtime_code -ne 0
            set exit_code 1
        end
    case verify-static
        verify_static
        set exit_code $status
    case verify-runtime
        verify_runtime
        set exit_code $status
    case lint
        do_lint
        set exit_code $status
    case status
        do_status
    case watch
        do_watch
    case clean
        do_clean
    case wifi-diag
        do_wifi_diag
    case benchmark
        do_benchmark
    case export
        do_export
    case backup-list
        do_backup_list
    case logs
        do_logs $LOG_TARGET
    case diagnose
        do_diagnose
        set exit_code $status
    case install
        do_install
        if test "$INSTALL_HAD_ERRORS" = true
            set exit_code 1
        end
end

# Finalize log - prepend terminal output section
echo "" >> "$LOG_FILE"
echo "# Finished: "(date) >> "$LOG_FILE"

# Create final log with terminal output first, then detailed log
if test (count $TERMINAL_LOG) -gt 0
    set -l temp_log (mktemp)
    if test -z "$temp_log"
        # Log file structure unchanged, original log preserved
        echo "[WARN] Failed to create temp file for log restructuring" >&2
    else
        # Write header
        echo "# ry-install v$VERSION" > "$temp_log"
        echo "# Started: "(date) >> "$temp_log"
        echo "# Command: "(status filename)" $argv" >> "$temp_log"
        echo "# Mode: $MODE" >> "$temp_log"
        echo "# Dry-run: $DRY" >> "$temp_log"
        echo "# Unattended: $ALL" >> "$temp_log"
        echo "# Verbose: "(test "$QUIET" = false; and echo true; or echo false) >> "$temp_log"
        echo "" >> "$temp_log"
        echo "TERMINAL OUTPUT" >> "$temp_log"
        echo "" >> "$temp_log"
        printf '%s\n' $TERMINAL_LOG >> "$temp_log"
        echo "" >> "$temp_log"
        echo "DETAILED LOG" >> "$temp_log"
        echo "" >> "$temp_log"
        # Append the detailed log (skip the header we already wrote)
        tail -n +8 "$LOG_FILE" >> "$temp_log"
        if not mv "$temp_log" "$LOG_FILE"
            rm -f "$temp_log" 2>/dev/null
            # Log file structure unchanged, continue
        end
    end
end

_info "Log file: $LOG_FILE"

exit $exit_code
