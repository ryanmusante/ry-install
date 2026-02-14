#!/usr/bin/env fish
#
# ry-install v2.0 — CachyOS config for Beelink GTR9 Pro (Strix Halo)
# Author: Ryan Musante | License: MIT
# Usage: ./ry-install.fish --help
#
# Design notes:
# - Cmdline+modprobe duplication: intentional (built-in vs loadable)
# - ppfeaturemask modprobe-only; amdgpu modeset/cwsr/runpm cmdline-only
# - amdgpu-performance.service: udev timing workaround (Arch #72655)
# - iwd required for NM backend; do NOT enable iwd.service
# - Sleep masked, resume hook omitted; services exit 0 for missing sysfs
# - Intel E610 ice blacklisted (NVM <1.30 firmware lockup)
# - simpledrm blacklisted (conflicts with amdgpu on Strix Halo)
# - Backups are manual; script does not create or restore backups (see README § Recovery)
#
# GLOBAL CONFIGURATION

set -g VERSION "2.0"
set -g DRY false
set -g ALL false
set -g FORCE false
set -g QUIET true
set -g NO_COLOR false
set -g JSON_OUTPUT false

# Respect NO_COLOR (https://no-color.org/)
if set -q NO_COLOR; or test "$TERM" = "dumb"
    set -g NO_COLOR true
end

# Warn if running as root (should use sudo internally)
if test (id -u) -eq 0
    echo "Warning: Running as root. This script uses sudo internally." >&2
    echo "Consider running as normal user: ./ry-install.fish" >&2
    echo "" >&2
end

# Fish version check (3.3+ required)
set -l fish_ver (string match -r '\d+\.\d+' (fish --version 2>&1) | head -1)
if test -z "$fish_ver"
    echo "Error: Could not determine fish version" >&2
    exit 1
end
set -l fish_major (string split '.' "$fish_ver")[1]
set -l fish_minor (string split '.' "$fish_ver")[2]
if test -z "$fish_major"; or not string match -qr '^\d+$' "$fish_major"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test -z "$fish_minor"; or not string match -qr '^\d+$' "$fish_minor"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test "$fish_major" -lt 3; or begin; test "$fish_major" -eq 3; and test "$fish_minor" -lt 3; end
    echo "Error: fish 3.3+ required (found: $fish_ver)" >&2
    exit 1
end

set -l _now (date '+%Y-%m-%d_%Y%m%d-%H%M%S%z')
set -g DATE_LABEL (string split '_' "$_now")[1]
set -g TIMESTAMP (string split '_' "$_now")[2]

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
set -g LOG_DIR "$HOME/ry-install/logs/$DATE_LABEL"
mkdir -p "$LOG_DIR" 2>/dev/null
chmod 700 "$HOME/ry-install" 2>/dev/null  # Restrict top-level directory (logs may contain system info)
set -g LOG_FILE "$LOG_DIR/install-$TIMESTAMP.log"  # Renamed after MODE is known
touch "$LOG_FILE" 2>/dev/null; chmod 600 "$LOG_FILE" 2>/dev/null
set -g TERMINAL_LOG  # List-based log (avoids O(n²) string concat)
set -g INSTALL_HAD_ERRORS false

# Limits
set -g MAX_LOGS 50

# Thresholds (°C / % / seconds / MB)
set -g TEMP_CPU_WARN 85
set -g TEMP_CPU_CRIT 90
set -g TEMP_GPU_WARN 85
set -g TEMP_GPU_CRIT 95
set -g DISK_ROOT_CRIT 90
set -g DISK_ROOT_WARN 80
set -g BOOT_TIME_WARN 30
set -g BOOT_TIME_TARGET 15
set -g NVME_LIFE_WARN 90
set -g CACHE_CLEAN_THRESHOLD 100

# Signal handler — orphaned temp files: sudo find /etc /boot -name '.ry-install.*' -delete
function _cleanup_tmpfiles
    # Skip in dry-run — no temp files were created, avoid unexpected sudo prompt
    if test "$DRY" = true
        return 0
    end
    # Remove orphaned .ry-install.* temp files
    set -l sys_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l d (dirname "$dst")
        if not contains "$d" $sys_dirs
            set -a sys_dirs "$d"
        end
    end
    # Include NM system-connections (WiFi credential temp files)
    if not contains "/etc/NetworkManager/system-connections" $sys_dirs
        set -a sys_dirs "/etc/NetworkManager/system-connections"
    end
    for dir in $sys_dirs
        for f in (command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f 2>/dev/null)
            sudo rm -f "$f" 2>/dev/null
        end
    end
    set -l usr_dirs
    for dst in $USER_DESTINATIONS
        set -l d (dirname "$dst")
        if not contains "$d" $usr_dirs
            set -a usr_dirs "$d"
        end
    end
    for dir in $usr_dirs
        for f in (command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f 2>/dev/null)
            rm -f "$f" 2>/dev/null
        end
    end
end

set -g _CLEANUP_DONE false

function _do_cleanup
    _cleanup_tmpfiles
    # Clean _run stderr temp files (P2-04)
    command find /tmp -maxdepth 1 -name 'ry-run-stderr.*' -user (id -u) -delete 2>/dev/null
    command find /tmp -maxdepth 1 -name 'ry-run-stdout.*' -user (id -u) -delete 2>/dev/null
    # Clean validate_configs temp files (P3-02)
    command find /tmp -maxdepth 1 -name 'ry-validate-*' -user (id -u) -delete 2>/dev/null
    # Clean do_diff temp files (P4-04)
    command find /tmp -maxdepth 1 -name 'ry-diff-*' -user (id -u) -delete 2>/dev/null
    # Clean argparse temp files
    command find /tmp -maxdepth 1 -name 'ry-argparse.*' -user (id -u) -delete 2>/dev/null
    set -e WIFI_PASS 2>/dev/null
    if set -q LOCK_DIR; and test -d "$LOCK_DIR"
        rm -rf "$LOCK_DIR" 2>/dev/null
    end
    if set -q STDERR_CAPTURE; and test "$STDERR_CAPTURE" != /dev/null
        rm -f "$STDERR_CAPTURE" "$STDERR_CAPTURE.exit" "$STDERR_CAPTURE.tlog" 2>/dev/null
    end
    _kill_sudo_keepalive
end

function _kill_sudo_keepalive
    if set -q SUDO_KEEPALIVE_PID
        kill $SUDO_KEEPALIVE_PID 2>/dev/null
        set -e SUDO_KEEPALIVE_PID
    end
end

function _cleanup --on-signal INT --on-signal TERM --on-signal HUP
    echo "" >&2
    echo "[WARN] Interrupted - cleaning up..." >&2
    set -g _CLEANUP_DONE true
    _do_cleanup
    exit 130
end

# Clean orphaned temp files on any exit
function _cleanup_on_exit --on-event fish_exit
    if test "$_CLEANUP_DONE" = true
        return 0
    end
    _do_cleanup
end

# FILE DEFINITIONS
# Order: boot → core system → systemd drop-ins → network
set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" \
    "/etc/kernel/cmdline" \
    "/etc/sdboot-manage.conf" \
    "/etc/mkinitcpio.conf" \
    "/etc/modprobe.d/99-cachyos-modprobe.conf" \
    "/etc/modules-load.d/99-cachyos-modules.conf" \
    "/etc/udev/rules.d/99-cachyos-udev.rules" \
    "/etc/systemd/journald.conf.d/99-cachyos-journald.conf" \
    "/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
    "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/iwd/main.conf" \
    "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/conf.d/wireless-regdom"

set -g USER_DESTINATIONS \
    "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" \
    "$HOME/.config/environment.d/50-gaming.conf"

set -g SERVICE_DESTINATIONS \
    "/etc/systemd/system/amdgpu-performance.service" \
    "/etc/systemd/system/cpupower-epp.service"

# LOADER (systemd-boot): @saved, no delay, editor=no (security)
set -g LOADER_DEFAULT "@saved"
set -g LOADER_TIMEOUT 0
set -g LOADER_CONSOLE_MODE "keep"
set -g LOADER_EDITOR "no"

# SDBOOT-MANAGE
set -g SDBOOT_OVERWRITE "yes"
set -g SDBOOT_REMOVE_OBSOLETE "yes"

# KERNEL PARAMETERS — module params duplicated in modprobe (built-in vs loadable)
# Security note: amd_iommu=off disables DMA protection (PCI/Thunderbolt devices get
# unrestricted memory access). Acceptable for desktop behind physical access controls.
# For DMA protection with lower overhead: amd_iommu=on iommu=pt (passthrough mode).
# audit=0 disables kernel audit framework. CachyOS has no SELinux/AppArmor/auditd.
# Systems requiring STIG compliance would need audit=1.
set -g KERNEL_PARAMS \
    amd_iommu=off \
    amd_pstate=active \
    amdgpu.cwsr_enable=0 \
    amdgpu.modeset=1 \
    amdgpu.runpm=0 \
    audit=0 \
    btusb.enable_autosuspend=n \
    mt7925e.disable_aspm=1 \
    nowatchdog \
    nvme_core.default_ps_max_latency_us=0 \
    pci=pcie_bus_perf \
    quiet \
    split_lock_detect=off \
    usbcore.autosuspend=-1 \
    zswap.enabled=0

# MKINITCPIO (hook order matters)
# resume omitted (sleep masked)
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

# MODPROBE — blacklist: sp5100_tco, snd_acp_pci, pcspkr/snd_pcsp, floppy, ice, simpledrm
set -g MODPROBE_OPTIONS \
    "amdgpu ppfeaturemask=0xfffd7fff" \
    "mt7925e disable_aspm=1" \
    "btusb enable_autosuspend=n" \
    "usbcore autosuspend=-1" \
    "nvme_core default_ps_max_latency_us=0"

set -g MODPROBE_BLACKLIST sp5100_tco snd_acp_pci pcspkr snd_pcsp floppy ice simpledrm

# MODULES TO LOAD
set -g MODULES_LOAD ntsync

# UDEV RULES (ntsync perms, USB autosuspend off)
# GPU perf NOT via udev (timing issue Arch #72655), use service instead
set -g UDEV_RULES \
    'KERNEL=="ntsync", MODE="0666"' \
    'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"'

# ENVIRONMENT VARIABLES (gaming: Vulkan, shader cache, Proton)
# Written to environment.d (systemd user services)
set -g ENV_VARS \
    "AMD_VULKAN_ICD=RADV" \
    "MESA_SHADER_CACHE_MAX_SIZE=8G" \
    "PROTON_USE_NTSYNC=1" \
    "PROTON_NO_WM_DECORATION=1"

# JOURNALD (cap size/retention — 24/7 desktop grows fast)
set -g JOURNALD_SYSTEM_MAX_USE "500M"
set -g JOURNALD_MAX_RETENTION_SEC "2week"
set -g JOURNALD_COMPRESS "yes"

# COREDUMP (cap storage, keep accessible via coredumpctl)
set -g COREDUMP_STORAGE "external"
set -g COREDUMP_MAX_USE "500M"
set -g COREDUMP_COMPRESS "yes"

# RESOLVED
set -g RESOLVED_MDNS "no"

# LOGIND (ignore all power keys — desktop, sleep masked, use DE menu)
# HandlePowerKeyLongPress: systemd 249+, HandleRebootKey: systemd 250+
set -g LOGIND_IGNORE_KEYS \
    HandlePowerKey \
    HandlePowerKeyLongPress \
    HandleSuspendKey \
    HandleHibernateKey \
    HandleRebootKey

# IWD (NM backend only — do NOT enable iwd.service)
set -g IWD_ENABLE_NETWORK_CONFIG "false"
set -g IWD_DRIVER_QUIRKS "DefaultInterface=*" "PowerSaveDisable=*"
set -g IWD_DNS_SERVICE "systemd"

# NETWORKMANAGER
set -g NM_WIFI_BACKEND "iwd"
set -g NM_WIFI_POWERSAVE 2
set -g NM_LOG_LEVEL "ERR"

# WIRELESS REGULATORY DOMAIN
set -g WIRELESS_REGDOM "US"

# PACKAGES
set -g PKGS_ADD mkinitcpio-firmware nvme-cli iw cachyos-gaming-meta cachyos-gaming-applications fd sd dust procs stress-ng lm_sensors pipewire-libcamera
set -g PKGS_DEL power-profiles-daemon plymouth cachyos-plymouth-bootanimation ufw octopi micro cachyos-micro-settings btop

# MASKED SERVICES (ananicy-cpp: masked not removed, cachyos-settings depends on it)
# lvm2-monitor skipped if LVM detected; sleep targets masked (S0ix unreliable)
# scx_loader: incompatible with BORE kernel
set -g MASK \
    ananicy-cpp.service \
    lvm2-monitor.service \
    ModemManager.service \
    NetworkManager-wait-online.service \
    scx_loader.service \
    sleep.target \
    suspend.target \
    hibernate.target \
    hybrid-sleep.target \
    suspend-then-hibernate.target

# EMBEDDED FILE CONTENTS

function get_file_content
    if test (count $argv) -ne 1
        _err "get_file_content: expected 1 argument, got "(count $argv)
        return 1
    end
    switch "$argv[1]"
        # Order: boot → core system → systemd drop-ins → network → user → services

        # Boot

        case "/boot/loader/loader.conf"
            printf '%s\n' "# systemd-boot loader configuration"
            printf '%s\n' "default $LOADER_DEFAULT"
            printf '%s\n' "timeout $LOADER_TIMEOUT"
            printf '%s\n' "console-mode $LOADER_CONSOLE_MODE"
            printf '%s\n' "editor $LOADER_EDITOR"

        case "/etc/kernel/cmdline"
            # Single-line cmdline for kernel-install / bootctl fallback
            # root UUID detected dynamically from current root filesystem
            set -l root_uuid (findmnt -no UUID / 2>/dev/null)
            if test -z "$root_uuid"
                _err "get_file_content: cannot detect root UUID (findmnt failed)"
                return 1
            end
            printf '%s\n' "rw root=UUID=$root_uuid "(string join -- " " $KERNEL_PARAMS)

        case "/etc/sdboot-manage.conf"
            printf '%s\n' "# sdboot-manage configuration"
            printf '%s\n' "# Changes require: sudo sdboot-manage gen && sudo sdboot-manage update"
            printf '%s\n' "LINUX_OPTIONS=\""(string join -- " " $KERNEL_PARAMS)"\""
            printf '%s\n' "LINUX_FALLBACK_OPTIONS=\"quiet\""
            printf '%s\n' "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\""
            printf '%s\n' "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\""

        case "/etc/mkinitcpio.conf"
            printf '%s\n' "# mkinitcpio configuration"
            printf '%s\n' "# Changes require: sudo mkinitcpio -P && sudo sdboot-manage update"
            printf '%s\n' "MODULES=("(string join -- " " $MKINITCPIO_MODULES)")"
            printf '%s\n' "BINARIES=()"
            printf '%s\n' "FILES=()"
            printf '%s\n' "HOOKS=("(string join -- " " $MKINITCPIO_HOOKS)")"
            printf '%s\n' "COMPRESSION=\"$MKINITCPIO_COMPRESSION\""


        # Core system

        case "/etc/modprobe.d/99-cachyos-modprobe.conf"
            printf '%s\n' "# modprobe configuration"
            for opt in $MODPROBE_OPTIONS
                printf '%s\n' "options $opt"
            end
            for mod in $MODPROBE_BLACKLIST
                printf '%s\n' "blacklist $mod"
            end

        case "/etc/modules-load.d/99-cachyos-modules.conf"
            printf '%s\n' "# Load modules at boot"
            for mod in $MODULES_LOAD
                printf '%s\n' $mod
            end

        case "/etc/udev/rules.d/99-cachyos-udev.rules"
            printf '%s\n' "# udev rules"
            for rule in $UDEV_RULES
                printf '%s\n' $rule
            end


        # Systemd drop-ins

        case "/etc/systemd/journald.conf.d/99-cachyos-journald.conf"
            printf '%s\n' "# systemd-journald configuration"
            printf '%s\n' "[Journal]"
            printf '%s\n' "SystemMaxUse=$JOURNALD_SYSTEM_MAX_USE"
            printf '%s\n' "MaxRetentionSec=$JOURNALD_MAX_RETENTION_SEC"
            printf '%s\n' "Compress=$JOURNALD_COMPRESS"

        case "/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf"
            printf '%s\n' "# systemd-coredump configuration"
            printf '%s\n' "[Coredump]"
            printf '%s\n' "Storage=$COREDUMP_STORAGE"
            printf '%s\n' "MaxUse=$COREDUMP_MAX_USE"
            printf '%s\n' "Compress=$COREDUMP_COMPRESS"

        case "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf"
            printf '%s\n' "# systemd-resolved configuration"
            printf '%s\n' "[Resolve]"
            printf '%s\n' "MulticastDNS=$RESOLVED_MDNS"

        case "/etc/systemd/logind.conf.d/99-cachyos-logind.conf"
            printf '%s\n' "# systemd-logind configuration - desktop power handling"
            printf '%s\n' "[Login]"
            for key in $LOGIND_IGNORE_KEYS
                printf '%s\n' "$key=ignore"
            end


        # Network

        case "/etc/iwd/main.conf"
            printf '%s\n' "# iwd configuration - minimal config for NetworkManager backend"
            printf '%s\n' "[General]"
            printf '%s\n' "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
            printf '%s\n' ""
            printf '%s\n' "[DriverQuirks]"
            for quirk in $IWD_DRIVER_QUIRKS
                printf '%s\n' $quirk
            end
            printf '%s\n' ""
            printf '%s\n' "[Network]"
            printf '%s\n' "NameResolvingService=$IWD_DNS_SERVICE"

        case "/etc/NetworkManager/conf.d/99-cachyos-nm.conf"
            printf '%s\n' "# NetworkManager configuration - iwd backend"
            printf '%s\n' "[device]"
            printf '%s\n' "wifi.backend=$NM_WIFI_BACKEND"
            printf '%s\n' ""
            printf '%s\n' "[connection]"
            printf '%s\n' "wifi.powersave=$NM_WIFI_POWERSAVE"
            printf '%s\n' ""
            printf '%s\n' "[logging]"
            printf '%s\n' "level=$NM_LOG_LEVEL"

        case "/etc/conf.d/wireless-regdom"
            printf '%s\n' "# Wireless regulatory domain"
            printf '%s\n' "WIRELESS_REGDOM=\"$WIRELESS_REGDOM\""


        # User

        case '*/.config/fish/conf.d/10-ssh-auth-sock.fish'
            printf '%s\n' '# SSH agent socket for fish shell (agent-agnostic: gpg-agent or ssh-agent)
if status is-interactive; and set -q XDG_RUNTIME_DIR
    # Prefer gpg-agent SSH socket if available
    if test -S "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh"
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh"
    else
        # Pre-set ssh-agent path so it resolves once the service starts
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
    end
end'

        case '*/.config/environment.d/50-gaming.conf'
            printf '%s\n' "# Gaming environment variables for systemd user services"
            printf '%s\n' "# Loaded by systemd --user (graphical sessions, Flatpak, user services)"
            for var in $ENV_VARS
                printf '%s\n' $var
            end

        # Services

        case "/etc/systemd/system/amdgpu-performance.service"
            printf '%s\n' '[Unit]
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
            printf '%s\n' '[Unit]
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

# LOGGING FUNCTIONS

set -g _LOG_CACHED_TS ""
set -g _LOG_CACHED_SEC ""

function _log
    # Cache formatted timestamp per-second to reduce date subprocess overhead
    # /proc/uptime read is a fish builtin (no fork); date only called when second changes
    set -l _upt
    read _upt < /proc/uptime 2>/dev/null
    set -l _sec (string replace -r '[. ].*' '' "$_upt")
    if test "$_sec" != "$_LOG_CACHED_SEC"
        set -g _LOG_CACHED_SEC "$_sec"
        set -g _LOG_CACHED_TS "["(date '+%Y-%m-%d %H:%M:%S')"]"
    end
    set -l timestamp "$_LOG_CACHED_TS"
    set -l msg "$argv"
    if string match -qr '\n' "$msg"
        # Replace newlines with newline + timestamp + continuation marker
        set msg (string replace -ar '\n' "\n$timestamp   " "$msg")
    end
    echo "$timestamp $msg" >> "$LOG_FILE"
end

# Verification counters
set -g VERIFY_OK 0
set -g VERIFY_FAIL 0
set -g VERIFY_WARN 0

function _msg --argument-names level
    set -l msg (string join " " $argv[2..])
    _log "$level: $msg"
    set -a TERMINAL_LOG "[$level] $msg"
    if set -q VERIFY_MODE; and test "$VERIFY_MODE" = true
        switch $level
            case OK; set -g VERIFY_OK (math $VERIFY_OK + 1)
            case FAIL; set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
            case WARN; set -g VERIFY_WARN (math $VERIFY_WARN + 1)
        end
    end
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[$level] $msg"
        else
            switch $level
                case OK; set_color green
                case FAIL ERR; set_color red
                case INFO; set_color blue
                case WARN; set_color yellow
                case DRY; set_color cyan
            end
            echo -n "[$level]"; set_color normal; echo " $msg"
        end
    end
end

function _ok; _msg OK $argv; end
function _fail; _msg FAIL $argv; end
function _info; _msg INFO $argv; end
function _warn; _msg WARN $argv; end
function _dry; _msg DRY $argv; end

function _err
    _log "ERR: $argv"
    set -a TERMINAL_LOG "[ERR] $argv"
    if test "$QUIET" = false
        if test "$NO_COLOR" = true
            echo "[ERR] $argv" >&2
        else
            begin
                set_color red; echo -n "[ERR]"; set_color normal; echo " $argv"
            end >&2
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

# Force-print (bypasses QUIET)
function _fmsg --argument-names level
    set -l msg (string join " " $argv[2..])
    _log "$level: $msg"
    if test "$NO_COLOR" = true
        echo "[$level] $msg"
    else
        switch $level
            case OK; set_color green
            case WARN; set_color yellow
            case ERR; set_color red
            case INFO '*'; set_color blue
        end
        echo -n "[$level]"; set_color normal; echo " $msg"
    end
end

# 68-char banner box
function _banner
    if test (count $argv) -lt 1
        return 0
    end
    set -l text $argv[1]
    set -l border "┌──────────────────────────────────────────────────────────────────┐"
    set -l bottom "└──────────────────────────────────────────────────────────────────┘"
    # Interior width between vertical bars is 66 chars.
    set -l inner 66
    set -l prefix "│  "
    set -l suffix " │"
    # max_text = inner minus interior spacing only (2 left + 1 right = 3)
    # prefix/suffix include border chars (│) which are already outside inner
    set -l max_text (math "$inner - 3")
    if test (string length -- "$text") -gt $max_text
        set text (string sub -l $max_text -- "$text")
    end
    set -l text_len (string length -- "$text")
    set -l pad (math "$max_text - $text_len")
    if test $pad -lt 0
        set pad 0
    end
    set -l spaces (string repeat -n $pad " ")
    _echo $border
    _echo "$prefix$text$spaces$suffix"
    _echo $bottom
    _echo
end

# Print verification summary
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

# PROGRESS BAR (--all mode only)
set -g PROGRESS_CURRENT 0
set -g PROGRESS_WIDTH 40
set -g PROGRESS_START_TIME 0
set -g PROGRESS_STEPS \
    "Checking dependencies" \
    "Syncing packages" \
    "Installing packages" \
    "Installing system files" \
    "Wireless regulatory domain" \
    "Installing user files" \
    "AMDGPU performance service" \
    "Updating databases" \
    "Reloading system config" \
    "Removing packages" \
    "Masking services" \
    "NetworkManager dispatcher" \
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
        if test "$PROGRESS_TOTAL" -le 0 2>/dev/null
            return
        end
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
                set eta_str (printf ' ~%dm%02ds' $eta_m $eta_s)
            else if test "$eta_secs" -gt 0
                set eta_str (printf ' ~%ds' $eta_secs)
            end
        end

        # Pad or truncate description to fixed width (clear previous text)
        set -l desc
        if test (string length -- "$argv[1]") -gt 25
            set desc (string sub -l 22 -- "$argv[1]")"..."
        else
            set desc (string sub -l 25 -- "$argv[1]                              ")
        end

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
        printf '\r[%s] 100%% Done%-25s%s\n' "$bar" "" "$elapsed_str"
    end
end

# COMMAND EXECUTION

# Execute command with logging; skip if --dry-run
function _run
    # Direct $argv execution (no eval). For pipes: _run fish -c 'cmd | pipe'
    set -l log_cmd (string join -- " " $argv)

    if string match -q '*--passphrase*' "$log_cmd"
        set log_cmd (string replace -r -- '--passphrase [^ ]+' '--passphrase [REDACTED]' "$log_cmd")
    end

    _log "RUN: $log_cmd"

    if test "$DRY" = true
        _dry "$log_cmd"
        return 0
    else
        # Capture stdout and stderr to temp files — avoids holding large output (e.g. pacman -Syu) in memory
        set -l stderr_tmp (mktemp /tmp/ry-run-stderr.XXXXXX 2>/dev/null; or echo /dev/null)
        set -l stdout_tmp (mktemp /tmp/ry-run-stdout.XXXXXX 2>/dev/null; or echo /dev/null)
        $argv > "$stdout_tmp" 2>"$stderr_tmp"
        set -l ret $status
        # Log stderr separately
        if test "$stderr_tmp" != /dev/null; and test -s "$stderr_tmp"
            set -l err_lines (cat "$stderr_tmp" 2>/dev/null)
            _log "STDERR: "(string join -- " | " $err_lines)
        end
        rm -f "$stderr_tmp" 2>/dev/null
        # Log and display stdout from temp file
        if test "$stdout_tmp" != /dev/null; and test -s "$stdout_tmp"
            set -l line_count (wc -l < "$stdout_tmp" | string trim)
            if test $line_count -le 50
                _log "OUTPUT: "(string join -- " | " (cat "$stdout_tmp"))
            else
                _log "OUTPUT: "(string join -- " | " (head -50 "$stdout_tmp"))" | ... ($line_count lines, truncated)"
            end
            if test "$QUIET" = false
                cat "$stdout_tmp"
            end
        end
        rm -f "$stdout_tmp" 2>/dev/null
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
    if not isatty stdin
        _log "ASK: $argv[1] -> auto-no (non-interactive)"
        return 1
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

    set -l is_boot false
    string match -q '/boot/*' "$argv[1]"; and set is_boot true

    if test "$is_boot" = false
        if not test -r "$argv[1]"
            if test -f "$argv[1]"
                _fail "  $argv[3]: PERMISSION DENIED (need sudo?)"
            else
                _fail "  $argv[3]: FILE NOT FOUND"
            end
            return 1
        end
    end

    set -l found false
    if test "$is_boot" = true
        sudo grep -qF "$argv[2]" "$argv[1]" 2>/dev/null; and set found true
    else
        grep -qF "$argv[2]" "$argv[1]" 2>/dev/null; and set found true
    end

    if test "$found" = true
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

    for cmd in pacman systemctl mkinitcpio udevadm sdboot-manage curl diff
        if not command -q $cmd
            set -a missing $cmd
        end
    end

    if test (count $missing) -gt 0
        _err "Missing required commands: $missing"
        _err "  This script requires CachyOS (Arch-based) with systemd-boot"
        if contains sdboot-manage $missing
            _err "  sdboot-manage is required for CachyOS bootloader management"
            _err "  Install with: sudo pacman -S sdboot-manage"
        end
        if contains mkinitcpio $missing
            _err "  mkinitcpio is required for initramfs generation (Arch/CachyOS)"
        end
        return 1
    end

    # Version checks for critical features
    # systemd 250+ required for: ConditionFirmware=, improved credentials, etc.
    set -l systemd_ver (systemctl --version 2>/dev/null | head -1 | string match -r '\d+' | head -1)
    if test -n "$systemd_ver"; and test "$systemd_ver" -lt 250
        _warn "systemd version $systemd_ver detected; some features require 250+"
    end

    # Soft-check tools from base packages (warn but don't fail)
    for cmd in journalctl dmesg modinfo pgrep free uptime
        if not command -q $cmd
            _warn "Expected tool not found: $cmd (from base packages)"
        end
    end

    _log "All dependencies satisfied"
    return 0
end

# Check network connectivity
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

# Check disk space (2GB root, 200MB boot)
function check_disk_space
    _log "Checking disk space..."

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
    else
        _warn "Could not determine disk space for /"
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
    else
        _warn "Could not determine disk space for /boot"
    end

    return 0
end

# Check kernel version for ntsync (6.14+)
function check_kernel_version
    set -l kver (uname -r)
    set -l parts (string split '.' -- $kver)
    set -l major $parts[1]
    # Extract numeric part only from minor (handles "14-rc1" -> "14")
    set -l minor (string replace -r '[^0-9].*' '' -- "$parts[2]")

    # Validate we got numbers
    if not string match -qr '^\d+$' "$major"
        set major 0
    end
    if test -z "$minor"; or not string match -qr '^\d+$' "$minor"
        set minor 0
    end

    _info "Kernel version: $kver"

    # ntsync requires kernel 6.14+
    if test "$major" -lt 6; or begin; test "$major" -eq 6; and test "$minor" -lt 14; end
        _warn "Kernel $kver < 6.14: ntsync will NOT be available"
        _warn "  Upgrade kernel for PROTON_USE_NTSYNC=1 support"
        set -g NTSYNC_SUPPORTED false
    else
        set -g NTSYNC_SUPPORTED true
    end

    return 0
end

# Check Secure Boot
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
        # Fallback: check EFI variable directly (glob-safe)
        set -l sb_vars /sys/firmware/efi/efivars/SecureBoot-*
        if test -e "$sb_vars[1]"
            _info "Secure Boot: EFI system detected"
        end
    end
    return 0
end

# Show BIOS version
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

# Check for sched-ext (incompatible with BORE)
function check_sched_ext
    # sched-ext: not compatible with BORE kernel — actively disable during install
    set -l scx_found false
    if systemctl is-active --quiet scx_loader.service 2>/dev/null
        set scx_found true
        _warn "sched-ext: scx_loader.service is active (not compatible with BORE kernel)"
        if test "$DRY" = true
            _dry "Would stop and disable scx_loader.service"
        else
            if not _run sudo systemctl disable --now scx_loader.service
                _warn "Failed to disable scx_loader.service"
            else
                _ok "Stopped and disabled scx_loader.service"
            end
        end
    else if systemctl is-enabled --quiet scx_loader.service 2>/dev/null
        set scx_found true
        _warn "sched-ext: scx_loader.service is enabled (not compatible with BORE kernel)"
        if test "$DRY" = true
            _dry "Would disable scx_loader.service"
        else
            if not _run sudo systemctl disable scx_loader.service
                _warn "Failed to disable scx_loader.service"
            else
                _ok "Disabled scx_loader.service"
            end
        end
    end
    for scx_svc in scx_lavd scx_bpfland scx_rusty scx_rustland
        if pgrep -x "$scx_svc" >/dev/null 2>&1
            set scx_found true
            _warn "sched-ext: $scx_svc is running (not compatible with BORE kernel)"
            if test "$DRY" = true
                _dry "Would kill $scx_svc"
            else
                if not sudo pkill -x "$scx_svc" 2>/dev/null
                    _warn "Failed to stop $scx_svc"
                else
                    _ok "Stopped $scx_svc"
                end
            end
        end
    end
    if test "$scx_found" = false
        _ok "sched-ext: no incompatible schedulers detected"
    end
    return 0
end

# Validate mkinitcpio hooks
function validate_mkinitcpio_hooks
    set -l errors 0
    for hook in $MKINITCPIO_HOOKS
        if not test -f "/usr/lib/initcpio/install/$hook"
            if not test -f "/usr/lib/initcpio/hooks/$hook"
                _err "Invalid mkinitcpio hook: $hook"
                set errors (math $errors + 1)
            end
        end
    end
    test $errors -eq 0; and return 0; or return 1
end

# Validate mkinitcpio modules
function validate_mkinitcpio_modules
    if not command -q modprobe
        return 0
    end
    for mod in $MKINITCPIO_MODULES
        if not modprobe -n "$mod" 2>/dev/null
            _warn "Module may not exist: $mod (continuing anyway)"
        end
    end
    return 0
end

# Validate systemd unit syntax
function validate_systemd_unit
    set -l tmpfile $argv[1]
    set -l unit_name $argv[2]

    if command -q systemd-analyze
        set -l verify_output (systemd-analyze verify "$tmpfile" 2>&1)
        set -l verify_status $status
        if test $verify_status -ne 0
            _err "Invalid systemd unit syntax: $unit_name"
            for line in $verify_output
                _log "  systemd-analyze: $line"
            end
            return 1
        else if test -n "$verify_output"
            # Log warnings (dependency hints, etc.) even on success
            for line in $verify_output
                _log "  systemd-analyze: $line"
            end
        end
    end

    return 0
end

# Validate modprobe options
function validate_modprobe_options
    if not command -q modprobe
        return 0
    end
    for opt in $MODPROBE_OPTIONS
        set -l mod (string split ' ' "$opt")[1]
        if not modprobe -n "$mod" 2>/dev/null
            _warn "Module may not exist: $mod (continuing anyway)"
        end
    end
    return 0
end

# Validate modprobe blacklist
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
    set -l tmpfile_amdgpu (mktemp -t ry-validate-XXXXXX --suffix=.service)
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

    set -l tmpfile_cpupower (mktemp -t ry-validate-XXXXXX --suffix=.service)
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
    set -l tmpfile_fish (mktemp -t ry-validate-XXXXXX --suffix=.fish)
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

    # Validate INI-format configs (systemd drop-ins, iwd, NetworkManager)
    # Each entry: destination|expected_section1,expected_section2,...
    set -l ini_checks \
        "/etc/systemd/journald.conf.d/99-cachyos-journald.conf|[Journal]" \
        "/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf|[Coredump]" \
        "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf|[Resolve]" \
        "/etc/systemd/logind.conf.d/99-cachyos-logind.conf|[Login]" \
        "/etc/iwd/main.conf|[General],[DriverQuirks],[Network]" \
        "/etc/NetworkManager/conf.d/99-cachyos-nm.conf|[device],[connection],[logging]"

    for check in $ini_checks
        set -l dst (string split '|' "$check")[1]
        set -l sections_str (string split '|' "$check")[2]
        set -l sections (string split ',' "$sections_str")
        set -l label (basename "$dst")

        set -l tmpfile_ini (mktemp -t ry-validate-XXXXXX --suffix=.ini)
        if test -z "$tmpfile_ini"
            _err "Failed to create temp file for $label validation"
            set errors (math $errors + 1)
            continue
        end

        get_file_content "$dst" > "$tmpfile_ini"
        set -l missing_sections
        for section in $sections
            if not grep -qF "$section" "$tmpfile_ini"
                set -a missing_sections "$section"
            end
        end

        if test (count $missing_sections) -gt 0
            _err "$label: missing section header(s): "(string join ', ' $missing_sections)
            set errors (math $errors + 1)
        else
            _log "VALIDATE: $label INI sections OK"
        end

        # Check for lines with content before any section header (orphaned keys)
        set -l first_section_line (grep -n '^\[' "$tmpfile_ini" | head -1 | cut -d: -f1)
        if test -n "$first_section_line"; and test "$first_section_line" -gt 1
            set -l orphaned (sed -n "1,"(math $first_section_line - 1)"p" "$tmpfile_ini" | grep -vE '^\s*$|^\s*#')
            if test -n "$orphaned"
                _warn "$label: key=value lines before first section header"
            end
        end

        rm -f "$tmpfile_ini"
    end

    if test $errors -gt 0
        _err "Validation failed with $errors error(s)"
        return 1
    end

    _ok "All configurations validated"
    return 0
end


# FILE INSTALLATION

# Install embedded config file
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

    # Get content — reconstruct with: printf '%s\n' $content (strips trailing blank lines)
    set -l content (get_file_content "$dst")
    if test $status -ne 0
        _err "No content defined for: $dst"
        return 1
    end

    # Create destination directory
    set -l dir (dirname "$dst")
    if test "$use_sudo" = true
        if not _run sudo mkdir -p "$dir"
            _fail "Cannot create directory: $dir"
            return 1
        end
    else
        if not _run mkdir -p "$dir"
            _fail "Cannot create directory: $dir"
            return 1
        end
    end

    # Write new content atomically
    if test "$DRY" = true
        _dry "rm -f $dst"
        _dry "write content to $dst"
        _dry "chmod 0644 $dst"
        _ok "(dry-run) → $dst"
        return 0
    end

    if test "$use_sudo" = true
        set -l dst_dir (dirname "$dst")
        set -l tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
        if test -z "$tmpfile"
            _fail "→ $dst (mktemp failed)"
            return 1
        end
        # Verify temp file is a regular file, not a symlink (prevent redirect attacks)
        if sudo test -L "$tmpfile"
            sudo rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
        if not printf '%s\n' $content | sudo tee "$tmpfile" >/dev/null
            sudo rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (write to temp failed)"
            return 1
        end
        if not sudo chmod 0644 "$tmpfile"
            sudo rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (chmod failed)"
            return 1
        end
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
        if test -L "$tmpfile"
            rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
        if not printf '%s\n' $content | tee "$tmpfile" >/dev/null
            rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (write to temp failed)"
            return 1
        end
        # Set correct permissions for user files
        if not chmod 0644 "$tmpfile"
            rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (chmod failed)"
            return 1
        end
        if not mv "$tmpfile" "$dst"
            rm -f "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
        _ok "→ $dst"
    end

    return 0
end

# Unified file installation
function install_files
    set -l _argparse_tmp (mktemp /tmp/ry-argparse.XXXXXX 2>/dev/null; or echo /dev/null)
    argparse 's/sudo' 'd/desc=' -- $argv 2>$_argparse_tmp
    or begin
        set -l _argparse_err (cat "$_argparse_tmp" 2>/dev/null | string trim)
        rm -f "$_argparse_tmp" 2>/dev/null
        _err "install_files: invalid arguments"(test -n "$_argparse_err"; and echo ": $_argparse_err")
        return 1
    end
    rm -f "$_argparse_tmp" 2>/dev/null
    set -l use_sudo false
    if set -q _flag_sudo
        set use_sudo true
    end
    set -l desc (test -n "$_flag_desc"; and echo "$_flag_desc"; or echo "FILES")
    if test (count $argv) -eq 0
        _err "install_files: no destinations provided"
        return 1
    end
    set -l destinations $argv

    _log "INSTALL $desc"
    set -l had_failure false
    for dst in $destinations
        if not install_file "$dst" $use_sudo
            _err "Failed to install: $dst"
            set had_failure true
        end
    end
    test "$had_failure" = true; and return 1
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

        # Read file directly (avoids TOCTOU — no separate existence check)
        set -l tmp (mktemp -t ry-diff-XXXXXX)
        set -l tmp_installed (mktemp -t ry-diff-XXXXXX)
        if test -z "$tmp"; or test -z "$tmp_installed"
            _warn "Failed to create temp files for diff: $dst"
            rm -f "$tmp" "$tmp_installed" 2>/dev/null
            continue
        end
        printf '%s\n' $content > "$tmp"
        # Attempt to read installed file; if it doesn't exist, treat as missing
        # Normalize through variable capture to match expected content treatment
        set -l read_ok false
        set -l installed_content
        if string match -q "$HOME/*" "$dst"
            set installed_content (cat "$dst" 2>/dev/null); and set read_ok true
        else
            set installed_content (sudo cat "$dst" 2>/dev/null); and set read_ok true
        end

        if test "$read_ok" = true
            printf '%s\n' $installed_content > "$tmp_installed"
            if not diff -q "$tmp" "$tmp_installed" >/dev/null 2>&1
                set has_diff true
                _warn "DIFFERS: $dst"
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
            rm -f "$tmp" "$tmp_installed" 2>/dev/null
            set has_diff true
            _fail "NOT INSTALLED: $dst"
        end
    end

    if test "$has_diff" = false
        _ok "All files match system!"
    end

    _log "=== DIFF END ==="

    if test "$has_diff" = true
        return 1
    end
    return 0
end

# STATIC VERIFICATION (no reboot required)
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

    _echo "── loader.conf ──"
    if _chk_file /boot/loader/loader.conf
        _chk_grep /boot/loader/loader.conf "default $LOADER_DEFAULT" "default $LOADER_DEFAULT"
        _chk_grep /boot/loader/loader.conf "timeout $LOADER_TIMEOUT" "timeout $LOADER_TIMEOUT"
        _chk_grep /boot/loader/loader.conf "console-mode $LOADER_CONSOLE_MODE" "console-mode $LOADER_CONSOLE_MODE"
        _chk_grep /boot/loader/loader.conf "editor $LOADER_EDITOR" "editor $LOADER_EDITOR"
    end

    _echo "── sdboot-manage.conf ──"
    if _chk_file /etc/sdboot-manage.conf
        # Extract just the value between quotes to avoid boundary-match failures
        # on first/last params (e.g., LINUX_OPTIONS="first ... last")
        set -l opts (grep '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null \
            | string replace -r '^LINUX_OPTIONS="?(.*?)"?\s*$' '$1')

        for param in $KERNEL_PARAMS
            if string match -q "* $param *" " $opts "
                _ok "  $param: present"
            else
                _fail "  $param: MISSING"
            end
        end

        _chk_grep /etc/sdboot-manage.conf "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\"" "OVERWRITE_EXISTING=$SDBOOT_OVERWRITE"
        _chk_grep /etc/sdboot-manage.conf "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\"" "REMOVE_OBSOLETE=$SDBOOT_REMOVE_OBSOLETE"
    end
    _echo

    _echo "── kernel cmdline ──"
    if _chk_file /etc/kernel/cmdline
        set -l cmdline_content (sudo cat /etc/kernel/cmdline 2>/dev/null)
        if test -n "$cmdline_content"
            for param in $KERNEL_PARAMS
                if string match -q "* $param *" " $cmdline_content "
                    _ok "  $param: present"
                else
                    _fail "  $param: MISSING from /etc/kernel/cmdline"
                end
            end
            # Verify root= is present
            if string match -q '*root=UUID=*' "$cmdline_content"
                _ok "  root=UUID: present"
            else
                _fail "  root=UUID: MISSING from /etc/kernel/cmdline"
            end
        else
            _fail "  /etc/kernel/cmdline: empty or unreadable"
        end
    end
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
            if string match -qr "\\b$mod\\b" "$m"
                _ok "  $mod: present"
            else
                _fail "  $mod: MISSING"
            end
        end

        set -l h (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -1)
        _echo "  Config: $h"

        for hook in $MKINITCPIO_HOOKS
            if string match -qr "\\b$hook\\b" "$h"
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
    end
    _echo

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

    _echo "── Modules load ──"
    # Check kernel ntsync support (6.14+)
    set -l _kver_parts (string split '.' -- (uname -r))
    set -l _kver_major $_kver_parts[1]
    set -l _kver_minor (string replace -r '[^0-9].*' '' -- "$_kver_parts[2]")
    if test "$_kver_major" -lt 6 2>/dev/null; or begin; test "$_kver_major" -eq 6 2>/dev/null; and test "$_kver_minor" -lt 14 2>/dev/null; end
        _info "  Skipping (kernel < 6.14, ntsync not supported)"
    else if _chk_file /etc/modules-load.d/99-cachyos-modules.conf
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

    _echo "── journald ──"
    if _chk_file /etc/systemd/journald.conf.d/99-cachyos-journald.conf
        _chk_grep /etc/systemd/journald.conf.d/99-cachyos-journald.conf "SystemMaxUse=$JOURNALD_SYSTEM_MAX_USE" "SystemMaxUse=$JOURNALD_SYSTEM_MAX_USE"
        _chk_grep /etc/systemd/journald.conf.d/99-cachyos-journald.conf "MaxRetentionSec=$JOURNALD_MAX_RETENTION_SEC" "MaxRetentionSec=$JOURNALD_MAX_RETENTION_SEC"
        _chk_grep /etc/systemd/journald.conf.d/99-cachyos-journald.conf "Compress=$JOURNALD_COMPRESS" "Compress=$JOURNALD_COMPRESS"
    end
    _echo

    _echo "── coredump ──"
    if _chk_file /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf
        _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "Storage=$COREDUMP_STORAGE" "Storage=$COREDUMP_STORAGE"
        _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "MaxUse=$COREDUMP_MAX_USE" "MaxUse=$COREDUMP_MAX_USE"
        _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "Compress=$COREDUMP_COMPRESS" "Compress=$COREDUMP_COMPRESS"
    end
    _echo

    _echo "── resolved ──"
    if _chk_file /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "MulticastDNS=$RESOLVED_MDNS" "MulticastDNS=$RESOLVED_MDNS"
    end
    _echo

    _echo "── logind.conf ──"
    if _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf
        for key in $LOGIND_IGNORE_KEYS
            _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
        end
    end
    _echo

    _echo "── iwd ──"
    if not pacman -Qi iwd >/dev/null 2>&1
        _info "  Skipping (iwd not installed)"
    else if _chk_file /etc/iwd/main.conf
        _chk_grep /etc/iwd/main.conf "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
        for quirk in $IWD_DRIVER_QUIRKS
            set -l key (string split '=' $quirk)[1]
            _chk_grep /etc/iwd/main.conf "$key" "DriverQuirks $key"
        end
        _chk_grep /etc/iwd/main.conf "NameResolvingService=$IWD_DNS_SERVICE" "DNS via $IWD_DNS_SERVICE"
    end
    _echo

    _echo "── NetworkManager ──"
    if not pacman -Qi iwd >/dev/null 2>&1
        _info "  Skipping iwd-backend config (iwd not installed)"
    else if _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
    end
    set -l nm_disp_state (systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null)
    if test "$nm_disp_state" = enabled
        _ok "  NetworkManager-dispatcher.service: enabled"
    else
        _fail "  NetworkManager-dispatcher.service: $nm_disp_state (expected: enabled)"
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

    _echo "── pacman.conf ──"
    if test -f /etc/pacman.conf
        # Check for malformed IgnorePkg lines
        set -l ignore_lines (grep -n '^IgnorePkg' /etc/pacman.conf 2>/dev/null)
        if test -n "$ignore_lines"
            for line in $ignore_lines
                _ok "  $line"
            end
        else
            _info "  No IgnorePkg set"
        end
        # Check ParallelDownloads
        set -l parallel (grep -n '^ParallelDownloads' /etc/pacman.conf 2>/dev/null)
        if test -n "$parallel"
            _ok "  $parallel"
        else
            _info "  ParallelDownloads not set (default: 1)"
        end
    else
        _warn "  /etc/pacman.conf not found"
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

# ─── Shared hardware state helpers ───────────────────────────────────────────
# These gather raw values into globals; callers handle formatting and thresholds.

# Gather GPU performance level and busy % from first DRM card
# Sets: _GPU_PERF_LEVEL, _GPU_BUSY_PCT, _GPU_VRAM_USED, _GPU_VRAM_TOTAL (empty if not found)
function _gather_gpu_state
    set -g _GPU_PERF_LEVEL ""
    set -g _GPU_BUSY_PCT ""
    set -g _GPU_VRAM_USED ""
    set -g _GPU_VRAM_TOTAL ""
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set -g _GPU_PERF_LEVEL (cat "$f" 2>/dev/null)
            break
        end
    end
    for f in /sys/class/drm/card*/device/gpu_busy_percent
        if test -f "$f"
            set -g _GPU_BUSY_PCT (cat "$f" 2>/dev/null)
            break
        end
    end
    for f in /sys/class/drm/card*/device/mem_info_vram_used
        if test -f "$f"
            set -g _GPU_VRAM_USED (cat "$f" 2>/dev/null)
            break
        end
    end
    for f in /sys/class/drm/card*/device/mem_info_vram_total
        if test -f "$f"
            set -g _GPU_VRAM_TOTAL (cat "$f" 2>/dev/null)
            break
        end
    end
end

# Gather CPU performance state from first online CPU with cpufreq
# Sets: _CPU_PATH, _CPU_GOVERNOR, _CPU_EPP, _CPU_DRIVER (empty if not found)
function _gather_cpu_state
    set -g _CPU_PATH ""
    set -g _CPU_GOVERNOR ""
    set -g _CPU_EPP ""
    set -g _CPU_DRIVER ""
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq
        if test -d "$cpu_dir"
            set -g _CPU_PATH "$cpu_dir"
            set -g _CPU_GOVERNOR (cat "$cpu_dir/scaling_governor" 2>/dev/null)
            set -g _CPU_EPP (cat "$cpu_dir/energy_performance_preference" 2>/dev/null)
            set -g _CPU_DRIVER (cat "$cpu_dir/scaling_driver" 2>/dev/null)
            break
        end
    end
end

# Gather CPU/GPU temperatures from sensors
# Sets: _TEMP_CPU_RAW ("+55.0°C"), _TEMP_CPU_NUM ("55.0"), _TEMP_CPU_INT ("55"),
#       _TEMP_GPU_RAW, _TEMP_GPU_NUM, _TEMP_GPU_INT, _SENSORS_RAW
# Returns 1 if sensors command not available
function _gather_temps
    set -g _TEMP_CPU_RAW ""
    set -g _TEMP_CPU_NUM ""
    set -g _TEMP_CPU_INT ""
    set -g _TEMP_GPU_RAW ""
    set -g _TEMP_GPU_NUM ""
    set -g _TEMP_GPU_INT ""
    set -g _SENSORS_RAW
    set -l sensors_cmd sensors
    if not command -q sensors
        # Fish command cache may miss newly-installed binaries until rehash
        if test -x /usr/bin/sensors
            set sensors_cmd /usr/bin/sensors
        else
            return 1
        end
    end
    set -g _SENSORS_RAW ($sensors_cmd 2>/dev/null)
    for pair in "CPU:Tctl|Tdie" "GPU:edge|junction"
        set -l label (string split ':' "$pair")[1]
        set -l pattern (string split ':' "$pair")[2]
        set -l line (printf '%s\n' $_SENSORS_RAW | grep -E "$pattern" | head -1)
        if test -n "$line"
            set -l raw (echo "$line" | awk '{print $2}')
            set -l num (echo "$line" | grep -oE '\+[0-9.]+' | head -1 | tr -d '+')
            set -l int_val (string split '.' -- "$num")[1]
            if test "$label" = CPU
                set -g _TEMP_CPU_RAW "$raw"
                set -g _TEMP_CPU_NUM "$num"
                set -g _TEMP_CPU_INT "$int_val"
            else
                set -g _TEMP_GPU_RAW "$raw"
                set -g _TEMP_GPU_NUM "$num"
                set -g _TEMP_GPU_INT "$int_val"
            end
        end
    end
end

# RUNTIME VERIFICATION (run after reboot)
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
        if string match -q "* $param *" " $cmdline "
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
    _gather_cpu_state
    if test -z "$_CPU_PATH"
        _warn "  No CPU frequency scaling found"
    else
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' "$_CPU_PATH")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:amd-pstate-epp:Scaling driver" \
                     "scaling_governor:performance:Governor" \
                     "energy_performance_preference:performance:EPP"
            set -l c (string split ':' "$check")
            set -l v (cat "$_CPU_PATH/$c[1]" 2>/dev/null)

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
        for pair in "modeset:1" "cwsr_enable:0" "runpm:0" "ppfeaturemask:0xfffd7fff"
            set -l pname (string split ':' "$pair")[1]
            set -l expected (string split ':' "$pair")[2]
            set -l ppath /sys/module/amdgpu/parameters/$pname
            if test -f "$ppath"
                set -l v (cat "$ppath" 2>/dev/null | string trim)
                # Normalize: sysfs may output decimal while expected is hex (or vice versa)
                # Convert both to decimal for comparison
                set -l v_dec "$v"
                set -l expected_dec "$expected"
                if string match -q '0x*' -- "$v"
                    set v_dec (printf '%d' "$v" 2>/dev/null; or echo "$v")
                end
                if string match -q '0x*' -- "$expected"
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

    if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"
        # Identify which agent is providing the socket
        if string match -q '*gpg-agent*' "$SSH_AUTH_SOCK"
            _ok "  SSH agent: gpg-agent ($SSH_AUTH_SOCK)"
        else if string match -q '*ssh-agent*' "$SSH_AUTH_SOCK"
            set -l ssh_enabled (systemctl --user is-enabled ssh-agent.socket 2>/dev/null; or systemctl --user is-enabled ssh-agent.service 2>/dev/null)
            if test "$ssh_enabled" = enabled
                _ok "  SSH agent: ssh-agent (enabled)"
            else
                _warn "  SSH agent: ssh-agent (socket ready but not enabled)"
            end
        else
            _ok "  SSH agent: active ($SSH_AUTH_SOCK)"
        end
    else if not set -q XDG_RUNTIME_DIR
        _warn "  SSH agent: XDG_RUNTIME_DIR not set (not in graphical session?)"
    else if set -q SSH_AUTH_SOCK
        _warn "  SSH agent: SSH_AUTH_SOCK set but socket missing ($SSH_AUTH_SOCK)"
    else
        _info "  SSH agent: not active (SSH_AUTH_SOCK not set)"
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
            _fail "  $n: NOT SET (re-login may be required)"
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
    # Directory is typically 700 root:root, so sudo is required to list contents
    set -l nm_conn_dir "/etc/NetworkManager/system-connections"
    if test -d "$nm_conn_dir"
        set -l conn_files (sudo find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f 2>/dev/null)
        if test -n "$conn_files"
            set -l bad_perms 0
            for conn_file in $conn_files
                set -l perms (sudo stat -c '%a' "$conn_file" 2>/dev/null)
                set -l owner (sudo stat -c '%U:%G' "$conn_file" 2>/dev/null)
                if test "$perms" != "600"; or test "$owner" != "root:root"
                    _fail "  $conn_file: $perms $owner (expected: 600 root:root)"
                    set bad_perms (math $bad_perms + 1)
                end
            end
            if test $bad_perms -eq 0
                set -l conn_count (count $conn_files)
                _ok "  NetworkManager connections: $conn_count files with correct permissions"
            end
        else
            # Warn if NM uses iwd backend (WiFi profiles expected)
            if grep -q 'wifi.backend=iwd' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null
                _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
            else
                _info "  NetworkManager connections: no .nmconnection files found"
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

    _echo "── Installed files ──"
    # Verify permissions and ownership on every file installed by ry-install
    # System and service files: expected 0644 root:root
    # Exception: /boot files may be tightened to 600/700 by bootctl/sdboot-manage
    set -l perm_bad 0
    set -l perm_checked 0
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo test -f "$dst" 2>/dev/null
            set perm_checked (math $perm_checked + 1)
            set -l perms (sudo stat -c '%a' "$dst" 2>/dev/null)
            set -l owner (sudo stat -c '%U:%G' "$dst" 2>/dev/null)
            set -l expected_perms "644"
            if string match -q '/boot/*' "$dst"
                # Boot manager tools may set 600 or 700; accept any of 644/600/700
                if test "$perms" = "644"; or test "$perms" = "600"; or test "$perms" = "700"
                    set expected_perms "$perms"
                end
            end
            if test "$perms" != "$expected_perms"; or test "$owner" != "root:root"
                _fail "  $dst: $perms $owner (expected: $expected_perms root:root)"
                set perm_bad (math $perm_bad + 1)
            end
        end
    end
    # User files: expected 0644 current_user:current_group
    set -l expected_owner (id -un)":"(id -gn)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            set -l perms (stat -c '%a' "$dst" 2>/dev/null)
            set -l owner (stat -c '%U:%G' "$dst" 2>/dev/null)
            if test "$perms" != "644"; or test "$owner" != "$expected_owner"
                _fail "  $dst: $perms $owner (expected: 644 $expected_owner)"
                set perm_bad (math $perm_bad + 1)
            end
        end
    end
    if test $perm_bad -eq 0; and test $perm_checked -gt 0
        _ok "  All $perm_checked installed files: correct permissions and ownership"
    else if test $perm_checked -eq 0
        _warn "  No installed files found to check"
    end
    _echo

    _echo "── Parent directories ──"
    # Verify parent dirs are not world-writable (prevents unprivileged config drops)
    set -l dir_bad 0
    set -l dir_checked 0
    set -l checked_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname "$dst")
        # Skip already-checked dirs
        if contains "$dir" $checked_dirs
            continue
        end
        set -a checked_dirs "$dir"
        if sudo test -d "$dir" 2>/dev/null
            set dir_checked (math $dir_checked + 1)
            set -l perms (sudo stat -c '%a' "$dir" 2>/dev/null)
            set -l owner (sudo stat -c '%U:%G' "$dir" 2>/dev/null)
            if test "$owner" != "root:root"
                _fail "  $dir: $perms $owner (expected: root:root)"
                set dir_bad (math $dir_bad + 1)
            else
                # Check world/group writable — strip setuid/setgid/sticky prefix
                if test (string length "$perms") -gt 3
                    set perms (string sub -s 2 "$perms")
                end
                set -l other_w (string sub -s 3 -l 1 "$perms")
                set -l group_w (string sub -s 2 -l 1 "$perms")
                set -l other_has_w (math "floor($other_w / 2) % 2" 2>/dev/null)
                set -l group_has_w (math "floor($group_w / 2) % 2" 2>/dev/null)
                if test "$other_has_w" -eq 1 2>/dev/null; or test "$group_has_w" -eq 1 2>/dev/null
                    _fail "  $dir: $perms (writable by non-root)"
                    set dir_bad (math $dir_bad + 1)
                end
            end
        end
    end
    if test $dir_bad -eq 0; and test $dir_checked -gt 0
        _ok "  All $dir_checked parent directories: correct ownership, not world/group-writable"
    else if test $dir_checked -eq 0
        _warn "  No parent directories found to check"
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
            set -l target $BOOT_TIME_TARGET
            set -l time_int (printf "%.0f" (math "$total_sec") 2>/dev/null)
            if test -n "$time_int"; and test "$time_int" -lt $target
                _ok "  Boot time under $target""s target"
            else if test -n "$time_int"
                _info "  Boot time exceeds $target""s target (ignored)"
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

    # Strip full-line comments before checking for bash patterns
    # Note: only removes lines starting with #, not inline # (which may be inside quotes)
    set -l clean_content (sed '/^[[:space:]]*#/d' "$script_path")

    set -l bash_subst (printf '%s\n' $clean_content | grep -n '\$(' 2>/dev/null | grep -v 'echo' | grep -v 'string match' | grep -v 'string replace' | grep -v '_warn' | grep -v '_ok' | grep -v '_fail' | grep -v '_info'; or true)
    if test -n "$bash_subst"
        _warn "Possible bash-style \$() found:"
        set -l lint_out (printf '%s\n' $bash_subst | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_subst | sed 's/^/  /'
        end
    else
        _ok "No bash-style \$() substitution found"
        _info "  Note: lines containing echo/string/log functions are excluded (may mask false negatives)"
    end

    set -l bash_cond (printf '%s\n' $clean_content | grep -nE '(^|[[:space:];])\[\[[[:space:]]' 2>/dev/null | grep -vE '_fail|_ok|_warn|_info|_echo'; or true)
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
    # Verify destination count matches get_file_content cases
    set -l total (math (count $SYSTEM_DESTINATIONS) + (count $USER_DESTINATIONS) + (count $SERVICE_DESTINATIONS))
    set -l case_count (sed -n '/^function get_file_content/,/^end$/p' "$script_path" | grep -cE "case [\"'](/|[*]/.)")
    if test $total -eq $case_count
        _ok "File count verified: $total destinations = $case_count content cases"
    else
        _fail "File count mismatch: $total destinations but $case_count content cases"
        set has_errors true
    end

    # Verify PROGRESS_STEPS matches _progress calls in install functions
    set -l steps_count (count $PROGRESS_STEPS)
    set -l progress_calls (sed -n '/^function _install_/,/^end$/p; /^function do_install/,/^end$/p' "$script_path" | grep -c '_progress "')
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


# UTILITY COMMANDS

# Quick system status dashboard
function do_status
    _banner "ry-install v$VERSION - System Status"

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
    if _gather_temps
        for pair in "CPU:$_TEMP_CPU_RAW:$_TEMP_CPU_INT:$TEMP_CPU_WARN" "GPU:$_TEMP_GPU_RAW:$_TEMP_GPU_INT:$TEMP_GPU_WARN"
            set -l parts (string split ':' "$pair")
            set -l label $parts[1]
            set -l raw $parts[2]
            set -l int_val $parts[3]
            set -l threshold $parts[4]
            if test -n "$raw"
                if test -n "$int_val"; and string match -qr '^\d+$' "$int_val"
                    if test "$int_val" -ge $threshold
                        _warn "$label: $raw (high)"
                    else
                        _ok "$label: $raw"
                    end
                else
                    _info "$label: $raw"
                end
            end
        end
    else
        _info "sensors not found (install lm_sensors or run 'rehash')"
    end
    _echo

    # GPU Performance
    _echo "── GPU Performance ──"
    _gather_gpu_state
    if test -n "$_GPU_PERF_LEVEL"
        if test "$_GPU_PERF_LEVEL" = "high"
            _ok "Performance level: $_GPU_PERF_LEVEL"
        else
            _warn "Performance level: $_GPU_PERF_LEVEL (expected: high)"
        end
    end
    if test -n "$_GPU_BUSY_PCT"
        _info "GPU busy: $_GPU_BUSY_PCT%"
    end
    _echo

    # CPU Performance
    _echo "── CPU Performance ──"
    _gather_cpu_state
    if test "$_CPU_GOVERNOR" = "performance"
        _ok "Governor: $_CPU_GOVERNOR"
    else
        _warn "Governor: $_CPU_GOVERNOR (expected: performance)"
    end

    if test "$_CPU_EPP" = "performance"
        _ok "EPP: $_CPU_EPP"
    else
        _warn "EPP: $_CPU_EPP (expected: performance)"
    end

    # CPU frequency range (needs direct sysfs read for cur/max — not in helper)
    if test -n "$_CPU_PATH"
        set -l freq_max (cat "$_CPU_PATH/scaling_max_freq" 2>/dev/null)
        set -l freq_cur (cat "$_CPU_PATH/scaling_cur_freq" 2>/dev/null)
        if test -n "$freq_cur"; and test -n "$freq_max"
            set freq_cur (math "$freq_cur / 1000")
            set freq_max (math "$freq_max / 1000")
            _info "Frequency: $freq_cur MHz (max: $freq_max MHz)"
        else if test -n "$freq_cur"
            set freq_cur (math "$freq_cur / 1000")
            _info "Frequency: $freq_cur MHz"
        end
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
        set -l wifi_active (nmcli -t -f ACTIVE,SSID dev wifi list 2>/dev/null | grep '^yes:')
        if test -n "$wifi_active"
            # Use -f2- to capture full SSID including any colons
            set -l ssid (echo $wifi_active | cut -d: -f2-)
            set -l signal (nmcli -t -f ACTIVE,SIGNAL dev wifi list 2>/dev/null | grep '^yes:' | cut -d: -f2)
            set -l freq (nmcli -t -f ACTIVE,FREQ dev wifi list 2>/dev/null | grep '^yes:' | cut -d: -f2-)
            _ok "WiFi: $ssid ($signal% @ $freq)"
        else
            set -l eth_state (nmcli -t -f TYPE,STATE dev 2>/dev/null | grep ethernet | cut -d: -f2)
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

    # VRAM (populated by _gather_gpu_state above)
    if test -n "$_GPU_VRAM_USED"; and test -n "$_GPU_VRAM_TOTAL"
        if string match -qr '^\d+$' "$_GPU_VRAM_USED"; and string match -qr '^\d+$' "$_GPU_VRAM_TOTAL"
            set -l vram_used (math "round($_GPU_VRAM_USED / 1073741824 * 10) / 10")
            set -l vram_total (math "round($_GPU_VRAM_TOTAL / 1073741824 * 10) / 10")
            _info "VRAM: "$vram_used"G / "$vram_total"G"
        else
            _warn "VRAM: unreadable sysfs values"
        end
    end
    _echo

    # Disk
    _echo "── Storage ──"
    set -l root_info (df -h / | tail -1)
    set -l root_used (echo $root_info | awk '{print $3}')
    set -l root_size (echo $root_info | awk '{print $2}')
    set -l root_pct (echo $root_info | awk '{print $5}')
    _info "Root: $root_used / $root_size ($root_pct)"
    if command -q nvme; and command -q sudo
        for dev in (find /dev -maxdepth 1 -name 'nvme[0-9]*' -type c 2>/dev/null | sort)
            if test -c "$dev"
                set -l smart (sudo nvme smart-log "$dev" 2>/dev/null)
                if test -n "$smart"
                    set -l pct_used (echo "$smart" | grep -i 'percentage_used' | awk '{print $NF}' | tr -d '%')
                    set -l temp_c (echo "$smart" | grep -i 'temperature' | head -1 | grep -oE '[0-9]+' | head -1)
                    set -l model (sudo nvme id-ctrl "$dev" 2>/dev/null | grep -i '^mn ' | sed 's/^mn *: *//')
                    set -l label (basename "$dev")
                    test -n "$model"; and set label "$label ($model)"
                    set -l health_parts
                    test -n "$pct_used"; and set -a health_parts "life used: $pct_used%"
                    if test -n "$temp_c"; and test "$temp_c" -gt 0 2>/dev/null
                        set -a health_parts "temp: $temp_c°C"
                    else if test -n "$temp_c"
                        set -a health_parts "temp: N/A"
                    end
                    if test (count $health_parts) -gt 0
                        _info "$label: "(string join ", " $health_parts)
                    end
                end
            end
        end
    end
    _echo

    # Fan speeds (if available)
    _echo "── Fans ──"
    if test (count $_SENSORS_RAW) -gt 0
        set -l fans (printf '%s\n' $_SENSORS_RAW | grep -i "fan" | head -3)
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
    if test -n "$pkg_power"; and string match -qr '^\d+$' "$pkg_power"
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
    if test -n "$gpu_power"; and string match -qr '^\d+$' "$gpu_power"
        set -l watts (math "$gpu_power / 1000000")
        _info "GPU power: "$watts"W"
    end
    if test -z "$pkg_power"; and test -z "$gpu_power"
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
    set -l root_dev (findmnt -no SOURCE / 2>/dev/null | string replace -r '\[.*\]' '' | xargs -r realpath 2>/dev/null)
    set -l blk_name
    if string match -q '/dev/dm-*' -- "$root_dev"
        # Device mapper (LVM): resolve to underlying physical device
        set -l dm_name (string replace '/dev/' '' -- "$root_dev")
        set -l slaves /sys/block/$dm_name/slaves/* 2>/dev/null
        if set -q slaves[1]
            set blk_name (path basename $slaves[1])
        end
    else if test -n "$root_dev"
        set blk_name (string replace -r 'p?[0-9]*$' '' -- "$root_dev" | xargs basename 2>/dev/null)
    end
    if test -z "$blk_name"
        _warn "Could not detect root block device for I/O scheduler"
    else
        set -l io_sched (cat /sys/block/$blk_name/queue/scheduler 2>/dev/null | grep -oE '\[.*\]' | tr -d '[]')
        if test -n "$io_sched"
            _info "I/O scheduler: $io_sched ($blk_name)"
        end
    end

    return 0
end

# System cleanup
function do_clean
    _banner "ry-install v$VERSION - System Cleanup"

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
                if not sudo paccache -rk2
                    _warn "paccache -rk2 failed"
                end
                if not sudo paccache -ruk0
                    _warn "paccache -ruk0 failed"
                end
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
            set -l vacuum_out (sudo journalctl --vacuum-time=7d 2>&1)
            for line in $vacuum_out
                if string match -q '*freed*' "$line"
                    _log "VACUUM: $line"
                end
            end
            set -l new_size (journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[GMK]')
            _ok "New size: $new_size"
        end
    end
    _echo

    # Shader cache
    _echo "── Shader Cache ──"
    set -l shader_dirs ~/.cache/mesa_shader_cache ~/.cache/mesa_shader_cache_sf ~/.cache/radv_builtin_shaders
    set -l shader_size 0
    for dir in $shader_dirs
        if test -d "$dir"
            set -l dir_size (du -sb "$dir" 2>/dev/null | cut -f1)
            if test -n "$dir_size"; and string match -qr '^\d+$' "$dir_size"
                set shader_size (math "$shader_size + $dir_size")
            end
        end
    end
    set -l shader_size_h (math "floor($shader_size / 1048576)")
    if test "$shader_size_h" -gt 1024
        set -l shader_gb (math "round($shader_size_h / 1024 * 10) / 10")
        _info "Current size: ~"$shader_gb"G"
    else
        _info "Current size: ~"$shader_size_h"M"
    end

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
    set -l log_base "$HOME/ry-install/logs"
    set -l old_logs (find "$log_base" -name '*.log' -mtime +7 2>/dev/null)
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
                # Remove empty date directories left after log cleanup
                find "$log_base" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
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
        set dump_count (string trim "$dump_count")
        # wc -l output should be numeric but validate to be safe
        if test -n "$dump_count"; and string match -qr '^\d+$' "$dump_count"; and test "$dump_count" -gt 0
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
    for d in ~/.cache/thumbnails ~/.cache/fontconfig
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

        if test "$cache_mb" -gt $CACHE_CLEAN_THRESHOLD
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

    return 0
end

# WiFi diagnostics
function do_wifi_diag
    _banner "ry-install v$VERSION - WiFi Diagnostics"

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
        set -l state (printf '%s\n' $conn_info | grep GENERAL.STATE | cut -d: -f2-)
        set -l ssid (printf '%s\n' $conn_info | grep GENERAL.CONNECTION | cut -d: -f2-)

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
                if string match -qr '^-?\d+$' -- "$signal"
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
            _echo "    $err"
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
        set -l bands (iw phy 2>/dev/null | grep -E "Band [0-9]:" | wc -l | string trim)
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
    _echo

    # Link-layer details (ethtool)
    _echo "── Link-Layer Details ──"
    if command -q ethtool
        for iface_path in /sys/class/net/*
            set -l iface (basename "$iface_path")
            if test "$iface" = "lo"
                continue
            end
            # Cache ethtool output per interface (2 calls instead of 4)
            set -l drv_output (ethtool -i "$iface" 2>/dev/null)
            set -l link_output (ethtool "$iface" 2>/dev/null)
            set -l drv (printf '%s\n' $drv_output | grep '^driver:' | awk '{print $2}')
            set -l fw (printf '%s\n' $drv_output | grep '^firmware-version:' | sed 's/firmware-version: //')
            set -l link (printf '%s\n' $link_output | grep 'Link detected:' | awk '{print $NF}')
            set -l speed (printf '%s\n' $link_output | grep 'Speed:' | awk '{print $2}')
            if test -n "$drv"
                _info "$iface: $drv"(test -n "$fw"; and echo " fw:$fw"; or echo "")
                if test -n "$speed"; and test "$speed" != "Unknown!"
                    _info "  Speed: $speed  Link: $link"
                else if test -n "$link"
                    _info "  Link: $link"
                end
                # EEE (Energy Efficient Ethernet) — only meaningful for wired
                if test -d "$iface_path/wireless"
                    continue  # Skip EEE for WiFi interfaces
                end
                set -l eee (ethtool --show-eee "$iface" 2>/dev/null | grep 'EEE status:' | awk '{print $NF}')
                if test -n "$eee"
                    _info "  EEE: $eee"
                end
            end
        end
    else
        _info "ethtool not installed (install for link-layer diagnostics)"
    end
    return 0
end

# Export system config
function do_export
    set -l export_file "$LOG_DIR/export-"(date +%Y%m%d-%H%M%S)".txt"

    _banner "ry-install v$VERSION - System Export"
    _info "Exporting system configuration to: $export_file"
    _echo

    # Start export
    echo "# ry-install System Export" > "$export_file"
    if test $status -ne 0; or not test -w "$export_file"
        _err "Failed to create export file: $export_file"
        return 1
    end
    chmod 600 "$export_file"
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
        echo "GPU: "(lspci 2>/dev/null | grep -iE 'vga|3d controller|display controller' | sed 's/^[^:]*:[^:]*: //' | head -1 | xargs) >> "$export_file"
    else
        echo "GPU: (lspci not available)" >> "$export_file"
    end
    echo "Memory: "(free -h | grep Mem | awk '{print $2}') >> "$export_file"
    echo "" >> "$export_file"

    # GPU details
    echo "## GPU STATE" >> "$export_file"
    _gather_gpu_state
    echo "Performance level: $_GPU_PERF_LEVEL" >> "$export_file"
    if test -n "$_GPU_VRAM_TOTAL"
        echo "VRAM total: "(math "round($_GPU_VRAM_TOTAL / 1073741824 * 10) / 10")" GB" >> "$export_file"
    else
        echo "VRAM total: N/A" >> "$export_file"
    end
    echo "" >> "$export_file"

    # CPU details
    echo "## CPU STATE" >> "$export_file"
    _gather_cpu_state
    echo "Governor: $_CPU_GOVERNOR" >> "$export_file"
    echo "EPP: $_CPU_EPP" >> "$export_file"
    echo "Driver: "(cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null) >> "$export_file"
    echo "" >> "$export_file"

    # Kernel cmdline
    echo "## KERNEL CMDLINE" >> "$export_file"
    echo "Runtime (/proc/cmdline):" >> "$export_file"
    cat /proc/cmdline >> "$export_file" 2>/dev/null
    if test -f /etc/kernel/cmdline
        echo "Source (/etc/kernel/cmdline):" >> "$export_file"
        cat /etc/kernel/cmdline >> "$export_file"
    end
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
    for f in /etc/mkinitcpio.conf /etc/sdboot-manage.conf /etc/modprobe.d/99-cachyos-modprobe.conf /etc/iwd/main.conf
        if test -f "$f"
            echo "$f: EXISTS" >> "$export_file"
        else
            echo "$f: MISSING" >> "$export_file"
        end
    end
    echo "" >> "$export_file"

    # Packages (gaming-related)
    echo "## PACMAN CONFIG" >> "$export_file"
    if test -f /etc/pacman.conf
        grep -E '^(IgnorePkg|IgnoreGroup|ParallelDownloads|SigLevel|Color|VerbosePkgLists)\b' /etc/pacman.conf >> "$export_file" 2>/dev/null
        echo "" >> "$export_file"
        echo "Repositories:" >> "$export_file"
        grep -E '^\[' /etc/pacman.conf | grep -v '^\[options\]' >> "$export_file" 2>/dev/null
    else
        echo "(pacman.conf not found)" >> "$export_file"
    end
    echo "" >> "$export_file"

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
    set -l _sensors_cmd
    if command -q sensors
        set _sensors_cmd sensors
    else if test -x /usr/bin/sensors
        set _sensors_cmd /usr/bin/sensors
    end
    if test -n "$_sensors_cmd"
        set -l sensor_output ($_sensors_cmd 2>/dev/null)
        if test -n "$sensor_output"
            echo "$sensor_output" >> "$export_file"
        else
            echo "(sensors returned no data — k10temp/amdgpu hwmon modules may not be loaded)" >> "$export_file"
        end
    else
        echo "(lm_sensors not installed)" >> "$export_file"
    end

    _ok "Export complete: $export_file"
    _info "Share this file when asking for help (contains no passwords)"
end


# Log viewer with smart filtering
function do_logs
    set -l target $argv[1]

    _banner "ry-install v$VERSION - Log Viewer"

    if test -z "$target"
        _info "Usage: ry-install.fish --logs <target>"
        _echo
        _info "Available targets:"
        _echo "    system     - Recent system errors (dmesg + journal)"
        _echo "    gpu        - AMDGPU driver messages"
        _echo "    wifi       - NetworkManager + iwd logs"
        _echo "    boot       - Boot sequence logs"
        _echo "    audio      - PipeWire/audio logs"
        _echo "    usb        - USB device events"
        _echo "    kernel     - Kernel errors and warnings (dmesg)"
        _echo "    <service>  - Any systemd service name"
        return 2
    end

    # Helper: capture command output and route through _echo for log capture
    # Usage: _log_cmd (command ... | tail -N)
    # Reads from $argv as lines; if empty, prints "  (no output)"
    set -l _log_lines

    switch $target
        case system
            _info "System errors (last hour):"
            _echo
            _echo "── dmesg errors ──"
            if command -q sudo
                set _log_lines (sudo dmesg --level=err,warn --ctime 2>/dev/null | tail -30)
            else
                set _log_lines (dmesg --level=err,warn --ctime 2>/dev/null | tail -30)
            end
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end
            _echo
            _echo "── journal errors ──"
            set _log_lines (journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | tail -30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end

        case gpu
            _info "AMDGPU logs:"
            _echo
            set _log_lines (sudo dmesg 2>/dev/null | grep -iE "amdgpu|drm|radeon|gfx" | tail -50)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end

        case wifi
            _info "WiFi logs (last 30 min):"
            _echo
            set _log_lines (journalctl -u NetworkManager -u iwd --since "30 minutes ago" --no-pager 2>/dev/null | tail -50)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end

        case boot
            _info "Boot logs:"
            _echo
            set _log_lines (journalctl -b --no-pager 2>/dev/null | head -100)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
                set -l total_lines (journalctl -b --no-pager 2>/dev/null | wc -l | string trim)
                if string match -qr '^\d+$' "$total_lines"; and test "$total_lines" -gt 100
                    _info "(showing first 100 of $total_lines lines — use 'journalctl -b' for full output)"
                end
            else
                _echo "  (no output)"
            end

        case audio
            _info "Audio logs:"
            _echo
            set _log_lines (journalctl --user -u pipewire -u wireplumber --since "1 hour ago" --no-pager 2>/dev/null | tail -50)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end

        case usb
            _info "USB events:"
            _echo
            set _log_lines (sudo dmesg 2>/dev/null | grep -iE "usb|hub" | grep -v "amdgpu" | tail -30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end

        case kernel
            _info "Kernel errors and warnings:"
            _echo
            _echo "── dmesg errors ──"
            set _log_lines (sudo dmesg --level=err 2>/dev/null | tail -30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end
            _echo
            _echo "── dmesg warnings ──"
            set _log_lines (sudo dmesg --level=warn 2>/dev/null | tail -30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines; _echo "$line"; end
            else
                _echo "  (no output)"
            end

        case '*'
            # Reject flags passed as targets (e.g., --logs -b)
            if string match -q -- '-*' "$target"
                _warn "Invalid log target: '$target' (looks like a flag)"
                _info "Valid targets: system, gpu, wifi, boot, audio, usb, kernel, <service>"
                return 1
            end
            # Treat as service name
            _info "Logs for $target:"
            _echo
            if systemctl cat "$target" >/dev/null 2>&1
                set _log_lines (journalctl -u "$target" --since "1 hour ago" --no-pager 2>/dev/null | tail -50)
                if test (count $_log_lines) -gt 0
                    for line in $_log_lines; _echo "$line"; end
                else
                    _echo "  (no output)"
                end
            else
                _warn "Service '$target' not found"
                _info "Try: systemctl list-units '*$target*'"
                return 1
            end
    end
end

# Automated system diagnostics
# Known harmless noise (see README § Expected Warnings):
# MT7925 "HCI Enhanced Setup", NVMe "No UUID/old NGUID",
# "deferred probe pending", "wireless extensions" (Firefox), "Overdrive is enabled",
# "invalid HE capabilities", "audit: failed to open auditd socket", WirePlumber
# "leaked proxy", COSMIC "GetKey ... No such file", taint flag S, "No matching ASoC"
function do_diagnose
    _banner "ry-install v$VERSION - System Diagnostics"

    set -l issues 0
    set -l checks 0

    # 1. Check for kernel errors
    set checks (math $checks + 1)
    _echo "── Kernel Errors ──"
    if command -q sudo
        set -l kernel_errors (sudo dmesg --level=err 2>/dev/null | wc -l | string trim)
        if test -n "$kernel_errors"; and string match -qr '^\d+$' "$kernel_errors"; and test "$kernel_errors" -gt 0
            _warn "Found $kernel_errors kernel error(s)"
            set -l _diag_lines (sudo dmesg --level=err 2>/dev/null | tail -5)
            for line in $_diag_lines; _echo "  $line"; end
            set issues (math $issues + 1)
        else
            _ok "No kernel errors"
        end
    else
        _info "sudo not available for dmesg check"
    end
    _echo

    # 2. Check failed services
    set checks (math $checks + 1)
    _echo "── Failed Services ──"
    set -l failed (systemctl --failed --no-pager 2>/dev/null | grep -c "failed" | string trim)
    if test -n "$failed"; and string match -qr '^\d+$' "$failed"; and test "$failed" -gt 0
        _warn "Found $failed failed service(s):"
        set -l _diag_lines (systemctl --failed --no-pager 2>/dev/null | grep failed | head -5)
        for line in $_diag_lines; _echo "  $line"; end
        set issues (math $issues + 1)
    else
        _ok "No failed services"
    end
    _echo

    # 3. Check expected services
    set checks (math $checks + 1)
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
    set checks (math $checks + 1)
    _echo "── GPU State ──"
    _gather_gpu_state
    if test "$_GPU_PERF_LEVEL" = "high"
        _ok "GPU performance: high"
    else if test -n "$_GPU_PERF_LEVEL"
        _warn "GPU performance: $_GPU_PERF_LEVEL (expected: high)"
        set issues (math $issues + 1)
    else
        _warn "Cannot read GPU performance level"
        set issues (math $issues + 1)
    end
    _echo

    # 5. Check CPU governor
    set checks (math $checks + 1)
    _echo "── CPU State ──"
    _gather_cpu_state
    if test "$_CPU_GOVERNOR" = "performance"
        _ok "CPU governor: performance"
    else if test -n "$_CPU_GOVERNOR"
        _warn "CPU governor: $_CPU_GOVERNOR (expected: performance)"
        set issues (math $issues + 1)
    end

    if test "$_CPU_EPP" = "performance"
        _ok "CPU EPP: performance"
    else if test -n "$_CPU_EPP"
        _warn "CPU EPP: $_CPU_EPP (expected: performance)"
        set issues (math $issues + 1)
    end
    _echo

    # 6. Check disk space
    set checks (math $checks + 1)
    _echo "── Disk Space ──"
    set -l root_pct (df / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    if test -n "$root_pct"; and string match -qr '^\d+$' "$root_pct"
        if test "$root_pct" -ge $DISK_ROOT_CRIT
            _fail "Root filesystem: $root_pct% (critical)"
            set issues (math $issues + 1)
        else if test "$root_pct" -ge $DISK_ROOT_WARN
            _warn "Root filesystem: $root_pct% (getting full)"
            set issues (math $issues + 1)
        else
            _ok "Root filesystem: $root_pct%"
        end
    end
    _echo

    # 7. Check temperatures
    set checks (math $checks + 1)
    _echo "── Temperatures ──"
    if _gather_temps
        if test -n "$_TEMP_CPU_NUM"
            if test -n "$_TEMP_CPU_INT"; and string match -qr '^\d+$' "$_TEMP_CPU_INT"
                if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_CRIT
                    _fail "CPU: $_TEMP_CPU_NUM°C (throttling likely)"
                    set issues (math $issues + 1)
                else if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_WARN
                    _warn "CPU: $_TEMP_CPU_NUM°C (high)"
                    set issues (math $issues + 1)
                else
                    _ok "CPU: $_TEMP_CPU_NUM°C"
                end
            else
                _info "CPU: $_TEMP_CPU_NUM°C (unable to parse for threshold check)"
            end
        end
        if test -n "$_TEMP_GPU_NUM"
            if test -n "$_TEMP_GPU_INT"; and string match -qr '^\d+$' "$_TEMP_GPU_INT"
                if test "$_TEMP_GPU_INT" -ge $TEMP_GPU_CRIT
                    _fail "GPU: $_TEMP_GPU_NUM°C (critical)"
                    set issues (math $issues + 1)
                else if test "$_TEMP_GPU_INT" -ge $TEMP_GPU_WARN
                    _warn "GPU: $_TEMP_GPU_NUM°C (high)"
                    set issues (math $issues + 1)
                else
                    _ok "GPU: $_TEMP_GPU_NUM°C"
                end
            else
                _info "GPU: $_TEMP_GPU_NUM°C (unable to parse for threshold check)"
            end
        end
    else
        _info "Install lm_sensors for temperature monitoring"
    end
    _echo

    # 8. Check WiFi
    set checks (math $checks + 1)
    _echo "── Network ──"
    if command -q nmcli
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
    set checks (math $checks + 1)
    _echo "── Gaming ──"
    if test -c /dev/ntsync
        _ok "ntsync: available"
    else
        _info "ntsync: not available (kernel 6.14+ required)"
    end
    _echo

    # 10. Recent OOM events
    set checks (math $checks + 1)
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
    set checks (math $checks + 1)
    _echo "── Kernel Taint ──"
    set -l taint (cat /proc/sys/kernel/tainted 2>/dev/null)
    if test -n "$taint"; and string match -qr '^\d+$' "$taint"; and test "$taint" != "0"
        _info "Kernel tainted: $taint (ignored)"
        # Decode taint flags (fish math doesn't support bitwise &, use modular arithmetic)
        set -l taint_flags \
            "0:Proprietary module loaded (P)" \
            "1:Module force-loaded (F)" \
            "2:Out-of-spec system (S)" \
            "3:Module force-unloaded (R)" \
            "4:Machine check exception (M)" \
            "5:Bad page reference (B)" \
            "6:User-requested taint (U)" \
            "7:Kernel OOPS/BUG (D)" \
            "8:ACPI table overridden (A)" \
            "9:Warning issued (W)" \
            "10:Staging driver loaded (C)" \
            "11:Hardware bug workaround (I)" \
            "12:Out-of-tree module loaded (O)" \
            "13:Unsigned module loaded (E)" \
            "14:Soft lockup occurred (L)" \
            "15:Kernel live-patched (K)" \
            "16:Auxiliary taint / distro-specific (X)" \
            "17:Struct randomization (T)" \
            "18:In-kernel test (N)"
        for flag in $taint_flags
            set -l bit (string split ':' "$flag")[1]
            set -l desc (string split ':' "$flag")[2]
            set -l divisor (math "2 ^ $bit")
            if test (math "floor($taint / $divisor) % 2") -eq 1
                _info "  - $desc"
            end
        end
        # Ignored per user preference
    else if test -n "$taint"; and test "$taint" = "0"
        _ok "Kernel not tainted"
    else
        _info "Could not read kernel taint status"
    end
    _echo

    # 12. Coredumps check
    set checks (math $checks + 1)
    _echo "── Coredumps ──"
    if command -q coredumpctl
        set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
        set dump_count (string trim "$dump_count")
        if test -n "$dump_count"; and string match -qr '^\d+$' "$dump_count"; and test "$dump_count" -gt 0
            _warn "Found $dump_count coredump(s)"
            set -l _diag_lines (coredumpctl list --no-pager 2>/dev/null | tail -5)
            for line in $_diag_lines; _echo "  $line"; end
            set issues (math $issues + 1)
        else
            _ok "No coredumps"
        end
    else
        _info "coredumpctl not available"
    end
    _echo

    # 13. Journal disk usage
    set checks (math $checks + 1)
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
    set checks (math $checks + 1)
    _echo "── NVMe Health ──"
    if command -q nvme
        set -l nvme_found false
        # Use find instead of glob — fish globs can silently fail in script context
        for dev in (find /dev -maxdepth 1 -name 'nvme[0-9]*n[0-9]*' -not -name '*p[0-9]*' -type b 2>/dev/null | sort)
            set nvme_found true
            set -l smart (sudo nvme smart-log $dev 2>/dev/null)
            if test -n "$smart"
                set -l pct_used (printf '%s\n' $smart | grep -i "percentage_used" | awk '{print $NF}' | tr -d '%')
                set -l crit_warn (printf '%s\n' $smart | grep -i "critical_warning" | awk '{print $NF}')

                if test -n "$crit_warn"; and test "$crit_warn" != "0"
                    _fail "$dev: Critical warning flag set!"
                    set issues (math $issues + 1)
                else if test -n "$pct_used"; and string match -qr '^\d+$' "$pct_used"; and test "$pct_used" -ge $NVME_LIFE_WARN
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
        if test "$nvme_found" = false
            _info "No NVMe devices found"
        end
    else
        _info "nvme-cli not installed (install for NVMe health monitoring)"
    end
    _echo

    # 15. Boot time analysis
    set checks (math $checks + 1)
    _echo "── Boot Performance ──"
    if command -q systemd-analyze
        set -l boot_line (systemd-analyze 2>/dev/null | head -1)
        set -l boot_sec (echo "$boot_line" | string match -r '= ([0-9.]+)s' | tail -1)
        if test -n "$boot_sec"; and string match -qr '^[0-9.]+$' "$boot_sec"
            set -l boot_int (math "floor($boot_sec)" 2>/dev/null)
            if test -n "$boot_int"; and test "$boot_int" -ge $BOOT_TIME_WARN
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
    set checks (math $checks + 1)
    _echo "── sched-ext Scheduler ──"
    if systemctl is-active --quiet scx_loader.service 2>/dev/null
        _warn "scx_loader.service is active (not compatible with BORE kernel)"
        _info "  Fix: sudo systemctl disable --now scx_loader.service"
        set issues (math $issues + 1)
    else if systemctl is-enabled --quiet scx_loader.service 2>/dev/null
        _warn "scx_loader.service is enabled (will start on reboot, not compatible with BORE kernel)"
        _info "  Fix: sudo systemctl disable scx_loader.service"
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
    set checks (math $checks + 1)
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

    # 18. ZRAM/ZSWAP state
    set checks (math $checks + 1)
    _echo "── ZRAM / ZSWAP ──"
    if command -q zramctl
        set -l zram_out (zramctl 2>/dev/null)
        if test -n "$zram_out"
            _info "ZRAM devices:"
            # Show algorithm and size from sysfs (reliable)
            for zdev in /sys/block/zram[0-9]*
                if test -d "$zdev"
                    set -l zname (basename "$zdev")
                    set -l algo (cat "$zdev/comp_algorithm" 2>/dev/null | grep -oE '\[.*\]' | tr -d '[]')
                    set -l disksize (cat "$zdev/disksize" 2>/dev/null)
                    if test -n "$disksize"; and test "$disksize" -gt 0 2>/dev/null
                        set disksize (math "round($disksize / 1073741824)")
                        _info "  $zname: $algo, $disksize GB"
                    else
                        _info "  $zname: $algo"
                    end
                end
            end
        else
            _info "ZRAM: no devices configured"
        end
    else
        _info "zramctl: not installed"
    end
    # ZSWAP
    if test -f /sys/module/zswap/parameters/enabled
        set -l zswap_enabled (cat /sys/module/zswap/parameters/enabled 2>/dev/null)
        if test "$zswap_enabled" = "Y"
            _warn "zswap: enabled (kernel param zswap.enabled=0 not applied?)"
            set issues (math $issues + 1)
        else
            _ok "zswap: disabled"
        end
    else
        _info "zswap: module not present"
    end
    _echo

    # 19. Power profiles
    set checks (math $checks + 1)
    _echo "── Power Profiles ──"
    if command -q powerprofilesctl
        set -l profile (powerprofilesctl get 2>/dev/null)
        if test -n "$profile"
            _info "Active power profile: $profile"
            # ppd should be masked per our config
            if systemctl is-active --quiet power-profiles-daemon.service 2>/dev/null
                _warn "power-profiles-daemon is running (should be removed per config)"
                set issues (math $issues + 1)
            end
        end
    else
        _ok "powerprofilesctl: not installed (expected — using cpupower-epp)"
    end
    _echo

    # 20. System topology
    set checks (math $checks + 1)
    _echo "── System Topology ──"
    if command -q lscpu
        set -l lscpu_out (lscpu 2>/dev/null)
        set -l cpu_model (printf '%s\n' $lscpu_out | grep 'Model name:' | sed 's/.*: *//')
        set -l cpu_cores (printf '%s\n' $lscpu_out | grep '^CPU(s):' | awk '{print $2}')
        set -l numa_nodes (printf '%s\n' $lscpu_out | grep 'NUMA node(s):' | sed 's/.*: *//')
        if test -n "$cpu_model"
            _info "CPU: $cpu_model"
        end
        if test -n "$cpu_cores"
            _info "CPUs: $cpu_cores"
        end
        if test -n "$numa_nodes"
            _info "NUMA nodes: $numa_nodes"
        end
    else
        _info "lscpu: not installed"
    end
    if command -q lsmem
        set -l mem_total (lsmem -b 2>/dev/null | grep 'Total online memory:' | awk '{print $NF}')
        if test -n "$mem_total"; and string match -qr '^\d+$' "$mem_total"
            set mem_total (math "round($mem_total / 1073741824)")
            _info "Memory: $mem_total GB"
        end
    else
        _info "lsmem: not available"
    end
    _echo

    # 21. Network link details (ethtool)
    set checks (math $checks + 1)
    _echo "── Network Link Details ──"
    if command -q ethtool
        for iface_path in /sys/class/net/*
            set -l iface (basename "$iface_path")
            # Skip loopback and virtual interfaces
            if test "$iface" = "lo"
                continue
            end
            _info "Interface: $iface"
            # Driver/firmware info (non-fatal — ethtool returns nonzero on WiFi/virtual)
            set -l drv_info (ethtool -i "$iface" 2>/dev/null)
            if test -n "$drv_info"
                set -l drv (printf '%s\n' $drv_info | grep '^driver:' | awk '{print $2}')
                set -l fw (printf '%s\n' $drv_info | grep '^firmware-version:' | sed 's/firmware-version: //')
                if test -n "$drv"
                    _info "  Driver: $drv"
                end
                if test -n "$fw"
                    _info "  Firmware: $fw"
                end
            end
            # Link state
            set -l link_detected (ethtool "$iface" 2>/dev/null | grep 'Link detected:' | awk '{print $NF}')
            if test -n "$link_detected"
                _info "  Link: $link_detected"
            end
            # EEE status (Energy Efficient Ethernet — non-fatal if unsupported)
            set -l eee_info (ethtool --show-eee "$iface" 2>/dev/null | grep 'EEE status:' | awk '{print $NF}')
            if test -n "$eee_info"
                _info "  EEE: $eee_info"
            end
        end
    else
        _info "ethtool: not installed (install for link-layer diagnostics)"
    end
    _echo

    # 22. Opt-in stress tests (default No; --all enables)
    set checks (math $checks + 1)
    _echo "── Stress Tests (optional) ──"
    set -l run_stress false
    if test "$ALL" = true
        set run_stress true
        _log "ASK: Run stress tests? -> auto-yes (--all)"
    else
        if _ask "Run stress tests? (CPU + memory, ~50s)"
            set run_stress true
        end
    end

    if test "$run_stress" = true
        if command -q stress-ng
            _info "Running CPU stress test (30s)..."
            set -l cpu_result (stress-ng --cpu (nproc) --timeout 30s --metrics 2>&1 | tail -3)
            if test -n "$cpu_result"
                for line in $cpu_result
                    _info "  $line"
                end
            end
            _ok "CPU stress test complete"

            _info "Running memory bandwidth test (20s)..."
            set -l mem_result (stress-ng --stream 1 --timeout 20s --metrics 2>&1 | tail -3)
            if test -n "$mem_result"
                for line in $mem_result
                    _info "  $line"
                end
            end
            _ok "Memory bandwidth test complete"

            # Check for thermal issues after stress (fresh read)
            if _gather_temps; and test -n "$_TEMP_CPU_NUM"
                if test -n "$_TEMP_CPU_INT"; and string match -qr '^\d+$' "$_TEMP_CPU_INT"
                    if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_CRIT
                        _fail "Post-stress CPU temp: $_TEMP_CPU_NUM°C (throttling)"
                        set issues (math $issues + 1)
                    else if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_WARN
                        _warn "Post-stress CPU temp: $_TEMP_CPU_NUM°C (high but within spec)"
                    else
                        _ok "Post-stress CPU temp: $_TEMP_CPU_NUM°C"
                    end
                end
            end
        else
            _warn "stress-ng not installed (install via: sudo pacman -S stress-ng)"
            _info "  Or run: ./ry-install.fish (no flags) to get diagnostic packages"
        end
    else
        _info "Skipped (pass --all or answer yes to run)"
    end
    _echo

    # 23. Kernel cmdline consistency
    set checks (math $checks + 1)
    _echo "── Kernel Cmdline ──"
    if test -f /etc/kernel/cmdline
        set -l cmdline_content (sudo cat /etc/kernel/cmdline 2>/dev/null)
        set -l missing 0
        for param in $KERNEL_PARAMS
            if not string match -q "* $param *" " $cmdline_content "
                set missing (math $missing + 1)
            end
        end
        if test $missing -gt 0
            _warn "/etc/kernel/cmdline: $missing kernel param(s) missing"
            _info "  Run: ./ry-install.fish --all (or reinstall to regenerate)"
            set issues (math $issues + 1)
        else
            _ok "/etc/kernel/cmdline: all params present"
        end
    else
        _info "/etc/kernel/cmdline: not found (kernel-install fallback unavailable)"
    end
    _echo

    # Summary
    _echo "════════════════════════════════════════════════════════════════════"
    if test $issues -eq 0
        _ok "Diagnostics complete: No issues found ($checks checks passed)"
    else
        _warn "Diagnostics complete: $issues issue(s) found"
        _info "Run './ry-install.fish --logs system' for more details"
    end

    # JSON output (machine-readable summary)
    if test "$JSON_OUTPUT" = true
        echo "{"
        echo "  \"version\": \"$VERSION\","
        echo "  \"mode\": \"diagnose\","
        echo "  \"checks\": $checks,"
        echo "  \"issues\": $issues,"
        echo "  \"status\": \""(test $issues -eq 0; and echo "ok"; or echo "issues_found")"\","
        echo "  \"timestamp\": \"$TIMESTAMP\""
        echo "}"
    end

    # Return boolean: 0 = no issues, 1 = issues found (count available via JSON/log)
    test $issues -eq 0; and return 0; or return 1
end

# INSTALLATION SUB-FUNCTIONS (orchestrated by do_install)

# Collect WiFi credentials upfront
function _install_collect_wifi
    set -g WIFI_SSID ""
    set -g WIFI_PASS ""
    set -g WIFI_IFACE ""

    if test "$DRY" != true; and _ask "Reconnect WiFi at end of installation?"
        if not command -q nmcli
            _fmsg WARN "nmcli not found - WiFi reconnection will be skipped"
        else
            set -l wlan_iface ""

            # Method 1: Parse iwctl device list
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
                _fmsg WARN "Could not detect WiFi interface"
                read -P "[?] Enter WiFi interface name: " wlan_iface
                if not string match -qr '^[a-zA-Z0-9_]+$' "$wlan_iface"; or test (string length -- "$wlan_iface") -gt 15
                    _fmsg ERR "Invalid interface name: must be alphanumeric, max 15 chars"
                    set wlan_iface ""
                else if not test -d "/sys/class/net/$wlan_iface"
                    _fmsg ERR "Interface '$wlan_iface' does not exist (check /sys/class/net/)"
                    set wlan_iface ""
                end
            end

            if test -n "$wlan_iface"
                set -g WIFI_IFACE "$wlan_iface"
                _fmsg INFO "WiFi interface: $wlan_iface"

                read -P "[?] WiFi SSID: " wifi_ssid
                if test -n "$wifi_ssid"
                    # Reject shell metacharacters and path separators
                    set -l _ssid_bad false
                    for _c in '/' '\\' ';' '`' '$' '(' ')' '{' '}' '|' '<' '>' '&' "'" '"' '%' '!'
                        if string match -q -- "*$_c*" "$wifi_ssid"
                            set _ssid_bad true
                            break
                        end
                    end
                    if test "$_ssid_bad" = true; or string match -qr '\\n|\\r' "$wifi_ssid"
                        _fmsg ERR "Invalid SSID: contains forbidden characters"
                        _fmsg INFO "SSIDs cannot contain shell metacharacters, quotes, or newlines"
                    else if string match -q '*..*' "$wifi_ssid"
                        _fmsg ERR "Invalid SSID: contains path traversal sequence"
                    else if test (string length -- "$wifi_ssid") -gt 32
                        _fmsg ERR "Invalid SSID: must be 1-32 characters"
                    else
                        set -g WIFI_SSID "$wifi_ssid"
                        set -l wifi_pass ""
                        read -sP "[?] WiFi passphrase: " wifi_pass
                        echo
                        if string match -qr '\n|\r' "$wifi_pass"
                            _fmsg ERR "Invalid passphrase: contains newline"
                            set -g WIFI_SSID ""
                            set wifi_pass ""
                        else if test (string length -- "$wifi_pass") -lt 8; or test (string length -- "$wifi_pass") -gt 63
                            _fmsg ERR "Invalid passphrase: WPA2 requires 8-63 characters"
                            set -g WIFI_SSID ""
                            set wifi_pass ""
                        else
                            set -g WIFI_PASS "$wifi_pass"
                            set wifi_pass ""  # Clear local copy immediately
                            _fmsg OK "WiFi credentials saved (will connect at end)"
                        end
                    end
                end
            end
        end
    end
    return 0
end

# Pre-flight checks
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
            return 1
        end
        # Check for unrestricted sudo (required for install)
        set -l sudo_all (sudo -l 2>/dev/null | grep -c '(ALL.*) ALL')
        or set sudo_all 0
        if test "$sudo_all" -eq 0
            if test "$ALL" = true
                _err "Restricted sudo incompatible with --all mode (unattended install requires full sudo)"
                _kill_sudo_keepalive
                return 1
            end
            _warn "Restricted sudo detected — some operations may fail"
            _warn "Install requires unrestricted sudo for pacman, systemctl, mkinitcpio, etc."
        end
        # Keep sudo alive in background for long installations
        # Self-terminates if parent dies (handles SIGKILL orphan edge case)
        # Redirect stdin from /dev/null to prevent stdin contention with main script
        set -l my_pid %self
        fish -c "while kill -0 $my_pid 2>/dev/null; sudo -n true 2>/dev/null; sleep 50; end" </dev/null &
        set -g SUDO_KEEPALIVE_PID $last_pid
        # Verify keepalive process actually started
        if not kill -0 $SUDO_KEEPALIVE_PID 2>/dev/null
            _warn "Sudo keepalive process failed to start — long installs may require re-auth"
            set -e SUDO_KEEPALIVE_PID
        else
            disown $SUDO_KEEPALIVE_PID 2>/dev/null
        end

        # Cleanup handler for abnormal exit (HUP signal and normal exit)
        # INT/TERM/HUP already handled by _cleanup which calls _kill_sudo_keepalive

        if not check_deps
            _kill_sudo_keepalive
            return 1
        end

        # Check disk space before proceeding
        if not check_disk_space
            _kill_sudo_keepalive
            return 1
        end

        # Check network connectivity (required for package operations)
        if not check_network
            _err "Network required for package installation — aborting"
            _kill_sudo_keepalive
            return 1
        end

        # Check kernel version for feature compatibility
        check_kernel_version

        # Check for sched-ext schedulers (incompatible with BORE kernel)
        check_sched_ext

        # Check Secure Boot status
        check_secure_boot

        # Show BIOS version (helpful for Strix Halo troubleshooting)
        show_bios_info
    end

    # Validate all configuration syntax before proceeding (runs in dry-run too)
    _echo
    if not validate_configs
        _err "Configuration validation failed - aborting"
        _kill_sudo_keepalive
        return 1
    end
end


# Sync databases, upgrade system, install packages
function _install_packages
    set -l _fn_err false
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
        # The second write in _install_system_files is a no-op (identical content).
        if test "$DRY" = false
            if not install_file "/etc/mkinitcpio.conf" true
                _err "Failed to pre-deploy mkinitcpio.conf before package install"
                set -g INSTALL_HAD_ERRORS true
                set _fn_err true
            end
        end

        if test (count $pkgs_to_install) -gt 0
            if not _run sudo pacman -Syu --needed --noconfirm -- $pkgs_to_install
                _warn "Package installation failed, retrying with fresh sync..."
                if not _run sudo pacman -Syyu --needed --noconfirm -- $pkgs_to_install
                    _err "Package installation failed after retry"
                    set -g INSTALL_HAD_ERRORS true
                    set _fn_err true
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
                    set _fn_err true
                else
                    _ok "All packages verified installed"
                end
            end
        end
    end
    test "$_fn_err" = true; and return 1
    return 0
end

# Install system configs, set wireless regdom
function _install_system_files
    set -l _fn_err false
    # SYSTEM FILES INSTALLATION
    _progress "Installing system files"
    _echo
    _info "Installing system configuration files..."
    if not install_files --sudo --desc "SYSTEM FILES" $SYSTEM_DESTINATIONS
        _err "System file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    # WIRELESS REGULATORY DOMAIN
    _progress "Wireless regulatory domain"
    _echo
    _info "Wireless regulatory domain (current: $WIRELESS_REGDOM)"
    _info "Common codes: US, GB, DE, FR, JP, AU, CA"

    if test "$DRY" != true; and not test "$ALL" = true
        read -P "[?] Enter your country code (or Enter for US): " regdom_input
        if test -n "$regdom_input"
            # Normalize to uppercase first, then validate
            set -l regdom_upper (string upper -- "$regdom_input" | string trim)

            if not string match -qr '^[A-Z]{2}$' "$regdom_upper"
                _err "Invalid country code: '$regdom_input' (must be 2 letters, e.g., US, GB, DE)"
            else
                # Validate against known wireless regulatory domains from system file
                set -l known_codes (grep -E '^#WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null | string match -rg '"([A-Z]{2})"')
                if test (count $known_codes) -eq 0
                    # Fallback: common ISO 3166-1 alpha-2 wireless regulatory codes
                    set known_codes US GB DE FR JP AU CA NZ IT ES NL BE AT CH SE NO DK FI PL CZ HU RO BG HR SI SK PT IE GR LU EE LV LT MT CY KR TW HK SG MY TH PH IN ID VN BR MX AR CL CO PE VE ZA IL TR UA RU KZ
                end
                if not contains -- "$regdom_upper" $known_codes
                    _warn "Unknown regulatory domain: '$regdom_upper' (not in system's wireless-regdom list)"
                    _warn "Proceeding anyway — invalid codes may fail silently at runtime"
                end
                set -l dst_dir (dirname /etc/conf.d/wireless-regdom)
                set -l tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
                if test -z "$tmpfile"
                    _err "Failed to create temp file for wireless-regdom"
                else if sudo test -L "$tmpfile"
                    sudo rm -f "$tmpfile" 2>/dev/null
                    _err "Temp file is symlink — aborting regulatory domain update"
                else
                    if sudo cat /etc/conf.d/wireless-regdom 2>/dev/null | string replace -r 'WIRELESS_REGDOM="[A-Z]*"' "WIRELESS_REGDOM=\"$regdom_upper\"" | sudo tee "$tmpfile" >/dev/null
                        if not sudo chmod 0644 "$tmpfile"
                            sudo rm -f "$tmpfile" 2>/dev/null
                            _err "Failed to set permissions on regulatory domain temp file"
                        else if not sudo mv "$tmpfile" /etc/conf.d/wireless-regdom
                            sudo rm -f "$tmpfile" 2>/dev/null
                            _err "Failed to set regulatory domain (mv failed)"
                        else if not sudo chown root:root /etc/conf.d/wireless-regdom
                            _err "Failed to set ownership on wireless-regdom"
                        else
                            # Verify the value was actually set (sed no-ops if all lines are commented)
                            if sudo grep -qF "WIRELESS_REGDOM=\"$regdom_upper\"" /etc/conf.d/wireless-regdom 2>/dev/null
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
            end
        end
    end

    # USER FILES INSTALLATION
    _progress "Installing user files"
    _echo
    _info "Installing user configuration files..."
    if not install_files --desc "USER FILES" $USER_DESTINATIONS
        _err "User file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    # AMDGPU PERFORMANCE SERVICE
    _progress "AMDGPU performance service"
    _echo
    _info "AMDGPU performance service (STRONGLY RECOMMENDED)"
    _info "  Udev rule may fail due to timing (Arch bug #72655)"

    if _ask "Install amdgpu-performance.service?"
        if not install_file "/etc/systemd/system/amdgpu-performance.service" true
            _err "Failed to install amdgpu-performance.service"
            set -g INSTALL_HAD_ERRORS true
            set _fn_err true
        else
            if not _run sudo systemctl daemon-reload
                _warn "systemctl daemon-reload failed"
            end
            if not _run sudo systemctl enable --now amdgpu-performance.service
                _warn "Failed to enable amdgpu-performance.service"
            end
        end
    end
    test "$_fn_err" = true; and return 1
    return 0
end

# Post-install: databases, reload, remove pkgs, mask/enable
function _install_configure_services
    set -l _fn_err false
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

    _progress "Reloading system config"
    if _ask "Reload udev rules?"
        if not _run sudo udevadm control --reload-rules
            _warn "udevadm reload-rules failed"
        end
        if not _run sudo udevadm trigger
            _warn "udevadm trigger failed"
        end
        if test "$DRY" = false
            if not _run sudo udevadm settle --timeout=5
                _warn "udevadm settle timed out"
            end
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
                        if not _run sudo pacman -Rns --noconfirm -- $pkg
                            _warn "Failed to remove $pkg"
                        end
                    end
                end
            end
        end
    end

    # Mask services (with LVM safety check)
    set -l safe_mask
    set -l has_lvm false

    if test "$DRY" = true
        # Use sudo -n (non-interactive) for read-only LVM detection even in dry-run
        if sudo -n true 2>/dev/null
            set -l pvs_output (sudo -n pvs --noheadings 2>/dev/null | string trim)
            if test -n "$pvs_output"
                set has_lvm true
                _warn "LVM DETECTED - lvm2 services will NOT be masked"
            end
        else
            _info "(dry-run) LVM detection skipped (no cached sudo credentials)"
        end
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

    _progress "NetworkManager dispatcher"
    set -l nm_disp_state (systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null)
    if test "$nm_disp_state" = enabled
        _ok "NetworkManager-dispatcher.service: already enabled"
    else if _ask "Enable NetworkManager-dispatcher.service?"
        if not _run sudo systemctl enable --now NetworkManager-dispatcher.service
            _warn "Failed to enable NetworkManager-dispatcher.service"
        end
    end

    _progress "CPU performance service"
    # EPP Service
    if _ask "Install and enable cpupower-epp.service? (REQUIRED for performance mode)"
        if not install_file "/etc/systemd/system/cpupower-epp.service" true
            _err "Failed to install cpupower-epp.service"
            set -g INSTALL_HAD_ERRORS true
            set _fn_err true
        else
            if not _run sudo systemctl daemon-reload
                _warn "systemctl daemon-reload failed"
            end
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

    # Check if gpg-agent is already providing SSH (skip ssh-agent in that case)
    set -l gpg_ssh_sock "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh"
    if set -q XDG_RUNTIME_DIR; and test -S "$gpg_ssh_sock"
        _ok "SSH agent: gpg-agent already active (skipping ssh-agent)"
    else if _ask "Enable ssh-agent (user, socket-activated)?"
        # Verify the user unit exists (provided by openssh or systemd)
        if systemctl --user cat ssh-agent.service >/dev/null 2>&1
            if not _run systemctl --user enable --now ssh-agent.service
                _warn "Failed to enable ssh-agent.service"
            end
        else
            _warn "ssh-agent.service user unit not found"
            _info "  Install openssh or create ~/.config/systemd/user/ssh-agent.service"
        end
    end
    test "$_fn_err" = true; and return 1
    return 0
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
            if test "$ALL" = true
                _err "CRITICAL: Boot rebuild failed in unattended mode — aborting remaining steps"
                return 1
            end
        end
    end

    _progress "Updating bootloader"
    if _ask "Update bootloader?"
        set -l _boot_ok true
        if not _run sudo sdboot-manage gen
            _warn "sdboot-manage gen failed"
            set -g INSTALL_HAD_ERRORS true
            set _boot_ok false
            if test "$ALL" = true
                _err "CRITICAL: Bootloader update failed in unattended mode — aborting remaining steps"
                return 1
            end
        end
        if test "$_boot_ok" = true
            if not _run sudo sdboot-manage update
                _warn "sdboot-manage update failed"
                set -g INSTALL_HAD_ERRORS true
            end
        end

        # Verify boot entries were created
        set -l entry_count (sudo find /boot/loader/entries -name "*.conf" 2>/dev/null | wc -l)
        set entry_count (string trim "$entry_count")
        if test -n "$entry_count"; and string match -qr '^\d+$' "$entry_count"; and test "$entry_count" -gt 0
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
    return 0
end

# NM restart, WiFi reconnection, cleanup
function _install_finalize
    _progress "Finalizing system"
    if not _run sudo systemctl daemon-reload
        _warn "systemctl daemon-reload failed"
    end
    if not _run systemctl --user daemon-reload
        _warn "systemctl --user daemon-reload failed"
    end

    if _ask "Clear package cache?"
        if command -q paccache
            if not _run sudo paccache -rk2
                _warn "paccache cache trim failed"
            end
            _run sudo paccache -ruk0 2>/dev/null
        else
            if not _run sudo pacman -Sc --noconfirm
                _warn "pacman cache clear failed"
            end
        end
    end

    # NETWORKMANAGER RESTART (switch to iwd backend)
    # Moved to end to preserve network connectivity during system upgrade

    _progress "NetworkManager restart"
    if _ask "Restart NetworkManager (switch to iwd backend)?"
        if command -q pacman; and pacman -Qi iwd >/dev/null 2>&1
            _info "iwd will restart with NetworkManager (D-Bus disconnect expected)"
            if not _run sudo systemctl restart NetworkManager
                _warn "NetworkManager restart failed"
                set -g INSTALL_HAD_ERRORS true
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

            set -l conn_dir (dirname "$conn_file")
            set -l tmpfile (sudo mktemp -p "$conn_dir" .ry-install.XXXXXX 2>/dev/null)
            if test -z "$tmpfile"
                set -e WIFI_PASS
                _err "Failed to create temp file for WiFi connection"
                set -g INSTALL_HAD_ERRORS true
            else if sudo test -L "$tmpfile"
                sudo rm -f "$tmpfile" 2>/dev/null
                set -e WIFI_PASS
                _err "Temp file is symlink — aborting WiFi connection creation"
                set -g INSTALL_HAD_ERRORS true
            else
                # Generate a deterministic UUID from SSID+interface for idempotent updates
                set -l _hex (printf '%s-%s' "$WIFI_SSID" "$WIFI_IFACE" | md5sum | string split ' ')[1]
                set -l conn_uuid (string sub -l 8 -- $_hex)-(string sub -s 9 -l 4 -- $_hex)-(string sub -s 13 -l 4 -- $_hex)-(string sub -s 17 -l 4 -- $_hex)-(string sub -s 21 -l 12 -- $_hex)
                # IPv6 disabled per user preference (single-stack IPv4 network)
                # Escape for GLib keyfile format: backslash, semicolon, hash, edge spaces
                set -l safe_pass (string replace -a '\\' '\\\\' -- "$WIFI_PASS")
                set safe_pass (string replace -a ';' '\\;' -- $safe_pass)
                # Escape leading # (GKeyFile comment marker at value start)
                if string match -q '#*' -- "$safe_pass"
                    set safe_pass '\\#'(string sub -s 2 -- "$safe_pass")
                end
                # Escape leading/trailing spaces (GKeyFile strips them)
                if string match -qr '^ ' -- "$safe_pass"
                    set safe_pass '\\s'(string sub -s 2 -- "$safe_pass")
                end
                if string match -qr ' $' -- "$safe_pass"
                    set safe_pass (string sub -l (math (string length -- "$safe_pass") - 1) -- "$safe_pass")'\\s'
                end
                if printf '%s\n' "[connection]" "id=$WIFI_SSID" "uuid=$conn_uuid" "type=wifi" "interface-name=$WIFI_IFACE" "autoconnect=true" "[wifi]" "mode=infrastructure" "ssid=$WIFI_SSID" "[wifi-security]" "key-mgmt=wpa-psk" "psk=$safe_pass" "[ipv4]" "method=auto" "[ipv6]" "method=disabled" | sudo tee "$tmpfile" >/dev/null
                    # Clear passphrase from memory immediately
                    set -e WIFI_PASS
                    if not sudo chmod 0600 "$tmpfile"
                        sudo rm -f "$tmpfile" 2>/dev/null
                        _err "Failed to set permissions on WiFi credential file"
                        set -g INSTALL_HAD_ERRORS true
                    else if not sudo mv "$tmpfile" "$conn_file"
                        sudo rm -f "$tmpfile" 2>/dev/null
                        _err "WiFi connection profile creation failed"
                        set -g INSTALL_HAD_ERRORS true
                    else
                        sudo chown root:root "$conn_file" 2>/dev/null
                        # Load single connection file atomically (avoids full reload race)
                        sudo nmcli connection load "$conn_file" 2>/dev/null
                        # Poll until NM sees the connection (iwd backend needs scan time)
                        set -l reload_wait 0
                        while test $reload_wait -lt 10
                            if nmcli connection show "$WIFI_SSID" >/dev/null 2>&1
                                break
                            end
                            set reload_wait (math $reload_wait + 1)
                            sleep 1
                            # Re-trigger load and WiFi scan periodically
                            if test (math "$reload_wait % 3") -eq 0
                                sudo nmcli connection load "$conn_file" 2>/dev/null
                                nmcli device wifi rescan ifname "$WIFI_IFACE" 2>/dev/null
                            end
                        end
                        # Activate with retry
                        set -l wifi_retry 0
                        set -l wifi_connected false
                        while test $wifi_retry -lt 3; and test "$wifi_connected" = false
                            if nmcli connection up id "$WIFI_SSID" 2>&1
                                set wifi_connected true
                                _ok "WiFi connection established"
                            else
                                set wifi_retry (math $wifi_retry + 1)
                                if test $wifi_retry -lt 3
                                    _info "WiFi connection attempt $wifi_retry failed, retrying in 3s..."
                                    sleep 3
                                    # Retry load in case NM dropped the profile
                                    sudo nmcli connection load "$conn_file" 2>/dev/null
                                end
                            end
                        end
                        if test "$wifi_connected" = false
                            _err "WiFi connection failed after 3 attempts"
                            set -g INSTALL_HAD_ERRORS true
                        end
                    end
                else
                    set -e WIFI_PASS
                    sudo rm -f "$tmpfile" 2>/dev/null
                    _err "WiFi connection profile write failed"
                    set -g INSTALL_HAD_ERRORS true
                end
            end
        else
            set -e WIFI_PASS
            _dry "Create /etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"
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
    return 0
end

# MAIN INSTALLATION
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

    # Sync databases, upgrade system, install packages
    if not _install_packages
        set -g INSTALL_HAD_ERRORS true
    end

    # System files, regulatory domain, user files, AMDGPU service
    if not _install_system_files
        set -g INSTALL_HAD_ERRORS true
    end

    # Post-install tasks, remove pkgs, mask/enable services
    if not _install_configure_services
        set -g INSTALL_HAD_ERRORS true
    end

    # Rebuild initramfs, update bootloader, system upgrade
    if not _install_rebuild_boot
        set -g INSTALL_HAD_ERRORS true
    end

    # NM restart, WiFi reconnection, cleanup
    _install_finalize

    # Install fish completions (non-critical, no progress step)
    do_completions 2>/dev/null; or _warn "Completions install failed (run --completions manually)"

    # COMPLETION

    # Complete progress bar
    _progress_done

    # Kill sudo keepalive background process
    _kill_sudo_keepalive

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
    _info "  1. Review /etc/fstab mount options (rw,noatime,lazytime for ext4/btrfs)"
    _info "  2. Run 'rehash' or start new shell (updates command paths)"
    _info "  3. REBOOT to apply kernel cmdline and module changes"
    _echo
    _info "Post-reboot verification: ./ry-install.fish --verify"
    _echo

    if test "$INSTALL_HAD_ERRORS" = true
        _warn "Done (with warnings - see above)"
    else
        _ok "Done!"
    end

    _log "=== INSTALLATION END ==="
    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end

# HELP

# Uninstall ry-install
function do_uninstall
    _banner "ry-install v$VERSION - Uninstall"

    if test "$DRY" = false
        if not sudo true
            _err "Sudo required for uninstall"
            return 1
        end
        if not _ask "This will remove all ry-install managed configs. Proceed?"
            _info "Uninstall cancelled"
            return 0
        end
    end

    set -l removed 0
    set -l failed 0

    # Stop and disable managed services before removing unit files
    for svc_file in $SERVICE_DESTINATIONS
        set -l svc_name (basename "$svc_file")
        if test "$DRY" = true
            if systemctl is-active --quiet "$svc_name" 2>/dev/null
                _dry "Would stop: $svc_name"
            end
            if systemctl is-enabled --quiet "$svc_name" 2>/dev/null
                _dry "Would disable: $svc_name"
            end
        else
            if systemctl is-active --quiet "$svc_name" 2>/dev/null
                if sudo systemctl stop "$svc_name" 2>/dev/null
                    _ok "Stopped: $svc_name"
                else
                    _warn "Failed to stop: $svc_name"
                end
            end
            if systemctl is-enabled --quiet "$svc_name" 2>/dev/null
                if sudo systemctl disable "$svc_name" 2>/dev/null
                    _ok "Disabled: $svc_name"
                else
                    _warn "Failed to disable: $svc_name"
                end
            end
        end
    end
    _echo

    # Remove system config files
    _echo "── Removing config files ──"
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo test -f "$dst" 2>/dev/null
            if test "$DRY" = true
                _dry "Would remove: $dst"
            else
                if sudo rm -f "$dst"
                    _ok "Removed: $dst"
                    set removed (math $removed + 1)
                else
                    _fail "Failed to remove: $dst"
                    set failed (math $failed + 1)
                end
            end
        else
            _info "Not installed: $dst"
        end
    end
    _echo

    # Reload systemd after removing unit files
    if test "$DRY" = true
        _dry "Would run: systemctl daemon-reload"
    else
        sudo systemctl daemon-reload 2>/dev/null
    end

    # Remove user config files
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            if test "$DRY" = true
                _dry "Would remove: $dst"
            else
                if rm -f "$dst"
                    _ok "Removed: $dst"
                    set removed (math $removed + 1)
                else
                    _fail "Failed to remove: $dst"
                    set failed (math $failed + 1)
                end
            end
        end
    end
    _echo

    # Remove fish completions
    set -l comp_file "$HOME/.config/fish/completions/ry-install.fish"
    if test -e "$comp_file"
        if test "$DRY" = true
            _dry "Would remove: $comp_file"
        else
            if rm -f "$comp_file"
                _ok "Removed: $comp_file"
                set removed (math $removed + 1)
            else
                _fail "Failed to remove: $comp_file"
                set failed (math $failed + 1)
            end
        end
    end
    _echo

    # Unmask services
    _echo "── Unmasking services ──"
    for svc in $MASK
        set -l state (systemctl is-enabled "$svc" 2>/dev/null)
        if test "$state" = masked
            if test "$DRY" = true
                _dry "Would unmask: $svc"
            else
                if sudo systemctl unmask "$svc" 2>/dev/null
                    _ok "Unmasked: $svc"
                else
                    _fail "Failed to unmask: $svc"
                    set failed (math $failed + 1)
                end
            end
        end
    end
    _echo

    _echo "════════════════════════════════════════════════════════════════════"
    if test "$DRY" = true
        _info "Dry-run complete. No changes made."
    else
        _ok "Uninstall complete ($removed files removed)"
        if test $failed -gt 0
            _warn "$failed operation(s) failed"
        end
        _info "Reboot recommended. Run 'sudo mkinitcpio -P' if initcpio configs were removed."
    end
    if test $failed -gt 0
        return 1
    end
    return 0
end

# Install fish completions (embedded)
function do_completions
    set -l comp_dir "$HOME/.config/fish/completions"
    set -l comp_dst "$comp_dir/ry-install.fish"

    if test "$DRY" = true
        _dry "Would install completions to: $comp_dst"
        return 0
    end

    mkdir -p "$comp_dir" 2>/dev/null

    # Embedded completions content
    set -l tmpfile (mktemp -p "$comp_dir" .ry-install.XXXXXX)
    if test -z "$tmpfile"
        _fail "Failed to create temp file for completions"
        return 1
    end
    if test -L "$tmpfile"
        rm -f "$tmpfile" 2>/dev/null
        _fail "Temp file is symlink — aborting completions install"
        return 1
    end

    printf '%s\n' \
        '# Fish completions for ry-install v'"$VERSION" \
        '# Generated by: ./ry-install.fish --completions' \
        '' \
        '# Both "ry-install" (renamed) and "ry-install.fish" (direct)' \
        'for cmd in ry-install ry-install.fish' \
        '    complete -c $cmd -f' \
        '' \
        '    # Installation' \
        '    complete -c $cmd -l all -d '"'"'Install without prompts (unattended mode)'"'"'' \
        '    complete -c $cmd -l force -d '"'"'Auto-yes all prompts (for --clean, --all, etc.)'"'"'' \
        '    complete -c $cmd -l verbose -d '"'"'Show output on terminal'"'"'' \
        '    complete -c $cmd -l dry-run -d '"'"'Preview changes without modifying system'"'"'' \
        '' \
        '    # Verification' \
        '    complete -c $cmd -l diff -d '"'"'Compare embedded files against installed system'"'"'' \
        '    complete -c $cmd -l verify -d '"'"'Run full verification (static + runtime)'"'"'' \
        '    complete -c $cmd -l verify-static -d '"'"'Check config files exist with correct content'"'"'' \
        '    complete -c $cmd -l verify-runtime -d '"'"'Check live system state (run after reboot)'"'"'' \
        '    complete -c $cmd -l lint -d '"'"'Run fish syntax and anti-pattern checks'"'"'' \
        '    complete -c $cmd -l test-all -d '"'"'Run all safe modes and generate log files (test suite)'"'"'' \
        '' \
        '    # Utilities' \
        '    complete -c $cmd -l status -d '"'"'Quick system health dashboard'"'"'' \
        '    complete -c $cmd -l clean -d '"'"'System cleanup (cache, journal, orphans)'"'"'' \
        '    complete -c $cmd -l wifi-diag -d '"'"'WiFi diagnostics and troubleshooting'"'"'' \
        '    complete -c $cmd -l export -d '"'"'Export system config for sharing/troubleshooting'"'"'' \
        '    complete -c $cmd -l logs -d '"'"'View logs (system, gpu, wifi, boot, audio, usb, kernel, or service name)'"'"'' \
        '    complete -c $cmd -l diagnose -d '"'"'Automated problem detection'"'"'' \
        '    complete -c $cmd -l uninstall -d '"'"'Remove ry-install configs and unmask services'"'"'' \
        '    complete -c $cmd -l completions -d '"'"'Install fish completions'"'"'' \
        '' \
        '    # Other' \
        '    complete -c $cmd -l no-color -d '"'"'Disable colored output'"'"'' \
        '    complete -c $cmd -l json -d '"'"'Machine-readable JSON output (with --diagnose)'"'"'' \
        '    complete -c $cmd -s h -l help -d '"'"'Show help'"'"'' \
        '    complete -c $cmd -s v -l version -d '"'"'Show version'"'"'' \
        '' \
        '    # Completions for --logs subcommands' \
        '    complete -c $cmd -l logs -xa '"'"'system gpu wifi boot audio usb kernel'"'"'' \
        'end' \
        > "$tmpfile"

    if test $status -ne 0
        rm -f "$tmpfile" 2>/dev/null
        _fail "Failed to write completions"
        return 1
    end

    chmod 0644 "$tmpfile"
    if not mv "$tmpfile" "$comp_dst"
        rm -f "$tmpfile" 2>/dev/null
        _fail "Failed to install completions (mv failed)"
        return 1
    end

    _ok "Completions installed to: $comp_dst"
end

# Run all non-destructive modes (test suite)
function do_test_all
    _banner "ry-install v$VERSION - Full Test Suite"

    set -l script_path (status filename)

    # Parse check first — catches syntax errors before running modes
    _info "Syntax check..."
    if not fish --no-execute "$script_path" 2>/dev/null
        _err "Script has parse errors — fix before running tests"
        fish --no-execute "$script_path"
        return 1
    end
    _ok "  fish --no-execute: passed"
    _echo

    # All safe (read-only) modes — excludes install, clean, uninstall, completions
    # Format: "flag [arg]" — split at runtime
    set -l modes \
        --verify-static \
        --verify-runtime \
        --lint \
        --diff \
        --status \
        --wifi-diag \
        --export \
        --diagnose \
        "--logs system" \
        "--logs gpu" \
        "--logs wifi" \
        "--logs boot" \
        "--logs audio" \
        "--logs usb" \
        "--logs kernel" \
        "--dry-run --all" \
        "--uninstall --dry-run --all"

    set -l total (count $modes)
    set -l passed 0
    set -l failed 0

    _info "Running $total diagnostic modes..."
    _echo

    for i in (seq (count $modes))
        set -l mode_args (string split ' ' -- $modes[$i])
        set -l label (string replace -- '--' '' "$modes[$i]")
        _info "[$i/$total] $modes[$i]"

        # Re-exec the script to produce a proper per-mode log file
        fish "$script_path" $mode_args --verbose --no-color </dev/null >/dev/null 2>&1
        set -l code $status

        if test $code -eq 0
            set passed (math $passed + 1)
            _ok "  $label: passed"
        else
            set failed (math $failed + 1)
            _warn "  $label: exit code $code"
        end
    end

    _echo
    _echo "════════════════════════════════════════════════════════════════════"
    if test $failed -eq 0
        _ok "Test suite complete: $passed/$total passed"
    else
        _warn "Test suite complete: $passed passed, $failed failed out of $total"
    end
    _echo
    _info "Log files created in: $LOG_DIR/"

    return $failed
end

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
  --test-all        Run all safe modes and generate log files (test suite)

UTILITIES:
  --status          Quick system health dashboard
  --clean           System cleanup (cache, journal, orphans)
  --wifi-diag       WiFi diagnostics and troubleshooting
  --export          Export system config for sharing/troubleshooting
  --logs <target>   View logs (system, gpu, wifi, boot, audio, usb, kernel, <service>)
  --diagnose        Automated problem detection
  --uninstall       Remove ry-install configs and unmask services
  --completions     Install fish completions

OPTIONS:
  --no-color        Disable colored output (also respects NO_COLOR env)
  --json            Machine-readable JSON output (with --diagnose)
  -h, --help        Show this help
  -v, --version     Show version

EXAMPLES:
  ./ry-install.fish              # Interactive installation
  ./ry-install.fish --all        # Unattended installation
  ./ry-install.fish --status     # Check system health
  ./ry-install.fish --clean      # Clean up system
  ./ry-install.fish --clean --force  # Clean up without prompts
  ./ry-install.fish --wifi-diag  # Troubleshoot WiFi
  ./ry-install.fish --diagnose --json  # Machine-readable diagnostics
  ./ry-install.fish --uninstall --dry-run  # Preview uninstall
  ./ry-install.fish --test-all      # Run all safe modes, generate log files

LOG FILE:
  ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS.log

REQUIREMENTS:
  CachyOS (Arch-based), systemd-boot, fish 3.3+
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
        case --test-all
            set MODE test-all
            set mode_count (math $mode_count + 1)
        case --status
            set MODE status
            set mode_count (math $mode_count + 1)
        case --json
            set JSON_OUTPUT true
        case --clean
            set MODE clean
            set mode_count (math $mode_count + 1)
        case --wifi-diag
            set MODE wifi-diag
            set mode_count (math $mode_count + 1)
        case --export
            set MODE export
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
        case --uninstall
            set MODE uninstall
            set mode_count (math $mode_count + 1)

        case --completions
            set MODE completions
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
            exit 2
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
    exit 2
end

# Non-install modes show output by default
if test "$MODE" != install
    set QUIET false
end

# Dry-run always shows output
if test "$DRY" = true
    set QUIET false
end

# JSON output suppresses human-readable text to avoid polluting pipe
if test "$JSON_OUTPUT" = true
    set QUIET true
end

# Rename log file to include mode name
set -l mode_label $MODE
if test -n "$LOG_TARGET"
    set mode_label "$MODE-$LOG_TARGET"
end
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.log"
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
echo "---LOG_START---" >> "$LOG_FILE"

# Log rotation: prune beyond MAX_LOGS
set -l log_base "$HOME/ry-install/logs"
set -l existing_logs (find "$log_base" -name '*.log' -type f 2>/dev/null | sort)
set -l log_count (count $existing_logs)
if test $log_count -gt $MAX_LOGS
    set -l to_remove (math $log_count - $MAX_LOGS)
    for old_log in $existing_logs[1..$to_remove]
        rm -f "$old_log" 2>/dev/null
    end
    # Remove empty date directories left after pruning
    find "$log_base" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
end

# Capture fish runtime stderr
set -g STDERR_CAPTURE (mktemp /tmp/ry-install-stderr.XXXXXX 2>/dev/null)
if test -z "$STDERR_CAPTURE"
    set -g STDERR_CAPTURE /dev/null
end

# Instance lock for mutating modes (prevents concurrent runs)
switch $MODE
    case install clean uninstall
        set -g LOCK_DIR "$HOME/ry-install/.lock"
        set -g LOCK_FILE "$LOCK_DIR/pid"
        mkdir -p (dirname "$LOCK_DIR") 2>/dev/null
        if not mkdir "$LOCK_DIR" 2>/dev/null
            # Lock dir exists — check if holder is still alive
            set -l old_pid (cat "$LOCK_FILE" 2>/dev/null)
            if test -n "$old_pid"; and kill -0 "$old_pid" 2>/dev/null
                echo "[ERR] Another ry-install instance is running (PID $old_pid)" >&2
                rm -f "$LOG_FILE" 2>/dev/null
                exit 1
            end
            # Stale lock from crashed process — reclaim atomically
            # rmdir+mkdir narrows the race window; mkdir is the atomic gate
            rm -f "$LOCK_FILE" 2>/dev/null
            rmdir "$LOCK_DIR" 2>/dev/null
            if not mkdir "$LOCK_DIR" 2>/dev/null
                echo "[ERR] Failed to reclaim stale lock — another instance may have started" >&2
                rm -f "$LOG_FILE" 2>/dev/null
                exit 1
            end
        end
        echo %self > "$LOCK_FILE"
end

# Execute requested mode
set -l exit_code 0
set -l _exit_code_tmp "$STDERR_CAPTURE.exit"
set -l _terminal_log_tmp "$STDERR_CAPTURE.tlog"
begin
switch $MODE
    case diff
        do_diff
        set exit_code $status
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
    case test-all
        do_test_all
        set exit_code $status
    case status
        do_status
        set exit_code $status
    case clean
        do_clean
        set exit_code $status
    case wifi-diag
        do_wifi_diag
        set exit_code $status
    case export
        do_export
        set exit_code $status
    case logs
        do_logs $LOG_TARGET
        set exit_code $status
    case diagnose
        do_diagnose
        set exit_code $status
    case uninstall
        do_uninstall
        set exit_code $status

    case completions
        do_completions
        set exit_code $status
    case install
        do_install
        set -l install_status $status
        if test $install_status -ne 0; or test "$INSTALL_HAD_ERRORS" = true
            set exit_code 1
        end
end
# Persist exit_code for retrieval after pipe (fish <3.4 may not propagate locals through 2>|)
echo $exit_code > "$_exit_code_tmp" 2>/dev/null
# Persist TERMINAL_LOG across subshell boundary (begin..end 2>| runs in subshell)
if test (count $TERMINAL_LOG) -gt 0
    printf '%s\n' $TERMINAL_LOG > "$_terminal_log_tmp" 2>/dev/null
end
end 2>| tee -a "$STDERR_CAPTURE" >&2
# Recover exit_code in case pipe ran begin block in subshell
if test -f "$_exit_code_tmp"
    set exit_code (cat "$_exit_code_tmp" 2>/dev/null; or echo 0)
    rm -f "$_exit_code_tmp" 2>/dev/null
end
# Recover TERMINAL_LOG from subshell persistence file
if test -f "$_terminal_log_tmp"
    set -g TERMINAL_LOG
    while read -l line
        set -a TERMINAL_LOG "$line"
    end < "$_terminal_log_tmp"
    rm -f "$_terminal_log_tmp" 2>/dev/null
end

# Finalize log
echo "" >> "$LOG_FILE"
echo "# Finished: "(date) >> "$LOG_FILE"

# Prepend terminal output to log
set -l _has_stderr false
if test "$STDERR_CAPTURE" != /dev/null; and test -s "$STDERR_CAPTURE"
    set _has_stderr true
end
if test (count $TERMINAL_LOG) -gt 0; or test "$_has_stderr" = true
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
        # Add captured stderr section if any fish runtime errors occurred
        # Filter out _err messages (already in TERMINAL OUTPUT) and ANSI codes
        if test "$_has_stderr" = true
            set -l filtered (sed -e 's/\x1b\[[0-9;]*m//g' -e '/^\[ERR\]/d' -e '/^Vacuuming done/d' -e '/^Rotating /d' "$STDERR_CAPTURE")
            if test -n "$filtered"
                echo "" >> "$temp_log"
                echo "TERMINAL STDERR" >> "$temp_log"
                echo "" >> "$temp_log"
                printf '%s\n' $filtered >> "$temp_log"
            end
        end
        echo "" >> "$temp_log"
        echo "DETAILED LOG" >> "$temp_log"
        echo "" >> "$temp_log"
        # Append the detailed log (skip header, find sentinel)
        set -l _log_start (grep -nF -- '---LOG_START---' "$LOG_FILE" | head -1 | cut -d: -f1)
        if test -n "$_log_start"
            tail -n +$_log_start "$LOG_FILE" | tail -n +2 >> "$temp_log"
        else
            tail -n +8 "$LOG_FILE" >> "$temp_log"
        end
        if not mv "$temp_log" "$LOG_FILE"
            rm -f "$temp_log" 2>/dev/null
            # Log file structure unchanged, continue
        end
    end
end

echo "[i] Log file: $LOG_FILE" >&2

rm -f "$STDERR_CAPTURE" 2>/dev/null
exit $exit_code
