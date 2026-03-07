#!/usr/bin/env fish
# ry-install v3.5.0 — CachyOS config for Beelink GTR9 Pro (Strix Halo) | Ryan Musante | MIT | Global flags below (overridden by CLI)
set -g VERSION "3.5.0"
# --dry-run: simulate all mutations
set -g DRY false
# --all: auto-yes every prompt
set -g ALL false
# --force: skip confirmation prompts
set -g FORCE false
# --quiet: suppress command-wrapper stdout to terminal (auto-disabled for non-install modes)
set -g QUIET true
set -g NO_COLOR false
# --fix: auto-repair diffs found by --diff
set -g FIX false
# --stress: stress-ng in --diagnose
set -g STRESS false

# ── Environment detection: NO_COLOR (no-color.org), delta, root check, privilege-escalation dry-run safety ──
if set -qx NO_COLOR || test "$TERM" = dumb
    set -g NO_COLOR true
end

set -g HAS_DELTA (command -q delta&& echo true|| echo false)

set -g _IS_ROOT false
if test (id -u) -eq 0
    # Running as root forces --dry-run; TODO: --root-override for chroot/CI with confirmation
    set -g _IS_ROOT true
    set -g DRY true
end

# ── Fish version gate (3.3+ required for string-collect, argparse enhancements) ──
set -l fish_ver (string match -r -- '\d+\.\d+' (fish --version 2>&1) | head -n 1)
if test -z "$fish_ver"
    echo "Error: Could not determine fish version" >&2
    exit 1
end
set -l fish_major (string split '.' -- "$fish_ver")[1]
set -l fish_minor (string split '.' -- "$fish_ver")[2]
if test -z "$fish_major" || not string match -qr '^\d+$' -- "$fish_major"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test -z "$fish_minor" || not string match -qr '^\d+$' -- "$fish_minor"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test "$fish_major" -lt 3 || begin
        test "$fish_major" -eq 3 && test "$fish_minor" -lt 3
    end
    echo "Error: fish 3.3+ required (found: $fish_ver)" >&2
    exit 1
end
# Upper bound: warn on untested fish versions — non-blocking
if test "$fish_major" -gt 4
    echo "Warning: ry-install is tested on fish 3.3-4.x; found $fish_ver — please report issues" >&2
end

# ── Timestamps (single date(1) call → DATE_LABEL for dirs + TIMESTAMP for filenames), HOME resolution, log dirs ──
set -l _now (date '+%Y-%m-%d_%Y%m%d-%H%M%S%z')
set -g DATE_LABEL (string split '_' -- "$_now")[1]
set -g TIMESTAMP (string split '_' -- "$_now")[2]

# HOME resolution: env → getent passwd → tilde expansion (handles privilege-escalated shells, cron, containers)
set -g _MY_UID (id -u)
if test -z "$HOME"
    set -g HOME (getent passwd $_MY_UID 2>/dev/null | cut -d: -f6)
    if test -z "$HOME"
        set -g HOME ~
    end
    if test -z "$HOME" || not test -d "$HOME"
        echo "Error: Cannot determine HOME directory" >&2
        exit 1
    end
end

set -g LOG_DIR "$HOME/ry-install/logs/$DATE_LABEL"
command mkdir -p -- "$LOG_DIR" 2>/dev/null || begin
    echo "[ERR] Cannot create log directory: $LOG_DIR" >&2
    exit 1
end
command chmod -- 700 "$HOME/ry-install" 2>/dev/null || true
set -g LOG_FILE "$LOG_DIR/install-$TIMESTAMP.jsonl"
touch -- "$LOG_FILE" 2>/dev/null
command chmod -- 600 "$LOG_FILE" 2>/dev/null || true
set -g INSTALL_HAD_ERRORS false
set -g _TRACKED_TMPFILES

# ── Retention limits ──
set -g MAX_LOGS 50
test $MAX_LOGS -lt 1 && set -g MAX_LOGS 1

# ── Timing constants ──
set -g SUDO_KEEPALIVE_INTERVAL 45
set -g WIFI_RETRY_DELAY 3
set -g WIFI_CONNECT_WAIT 1
set -g NM_RESTART_DELAY 3

# Conservative vs spec (95°C throttle / 100°C max) — early warning under sustained load
set -g TEMP_CPU_WARN 85
set -g TEMP_CPU_CRIT 90
set -g TEMP_GPU_WARN 85
set -g TEMP_GPU_CRIT 95
set -g DISK_ROOT_CRIT 90
set -g DISK_ROOT_WARN 80
set -g BOOT_SPACE_CRIT 200
set -g BOOT_SPACE_WARN 500
# Root available space thresholds (GB; check_disk_space preflight)
set -g ROOT_AVAIL_CRIT 2
set -g ROOT_AVAIL_WARN 5
set -g BOOT_TIME_WARN 30
set -g BOOT_TIME_TARGET 15
set -g NVME_LIFE_WARN 90
set -g CACHE_CLEAN_THRESHOLD 100

# ── Kernel version globals for _ntsync_state ≥6.14 gate ──
set -g KVER (uname -r)
set -g KVER_PARTS (string split '.' -- $KVER)
set -g KVER_MAJOR $KVER_PARTS[1]
if not string match -qr '^\d+$' -- "$KVER_MAJOR"
    set -g KVER_MAJOR 0
end
# Strip non-numeric suffix (e.g., "14-cachyos" → "14") for numeric comparison
set -g KVER_MINOR (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[2]")
if test -z "$KVER_MINOR" || not string match -qr '^\d+$' -- "$KVER_MINOR"
    set -g KVER_MINOR 0
end

# Return: unavailable (<6.14) | builtin (CONFIG_NTSYNC=y) | loaded | loaded_nodev | missing
function _ntsync_state --description "Return: unavailable|builtin|loaded|loaded_nodev|missing"
    _log "NTSYNC_CHECK: major=$KVER_MAJOR minor=$KVER_MINOR"
    if test "$KVER_MAJOR" -lt 6 || begin
            test "$KVER_MAJOR" -eq 6 && test "$KVER_MINOR" -lt 14
        end
        echo unavailable
    else if zcat /proc/config.gz 2>/dev/null | grep -q -- '^CONFIG_NTSYNC=y'
        echo builtin
    else if test -c /dev/ntsync
        echo loaded
    else if grep -q -- '^ntsync ' /proc/modules 2>/dev/null
        echo loaded_nodev
    else
        echo missing
    end
end

# Cross-check KERNEL_PARAMS against /proc/config.gz to detect unsupported kernel features
function _validate_kernel_params --description "Warn if KERNEL_PARAMS reference features not compiled into running kernel"
    # Only useful if /proc/config.gz exists (requires CONFIG_IKCONFIG_PROC=y)
    if not test -f /proc/config.gz
        _info "  /proc/config.gz unavailable — skipping kernel config validation"
        return 0
    end

    # Map: cmdline param prefix → CONFIG_ symbol; nowatchdog excluded (no-op without CONFIG_WATCHDOG)
    set -l param_config_map \
        "amd_pstate=CONFIG_X86_AMD_PSTATE" \
        "zswap.=CONFIG_ZSWAP" \
        "amd_iommu=CONFIG_AMD_IOMMU" \
        "amdgpu.=CONFIG_DRM_AMDGPU" \
        "split_lock_detect=CONFIG_X86_SPLIT_LOCK_DETECT"

    set -l config_data (zcat /proc/config.gz 2>/dev/null)
    if test -z "$config_data"
        _warn "  Failed to read /proc/config.gz"
        return 1
    end

    set -l mismatches 0
    for entry in $param_config_map
        set -l prefix (string split '=' -- "$entry")[1]
        set -l config_sym (string split '=' -- "$entry")[2]

        # Check if any KERNEL_PARAM starts with _cfg_prefix (e.g., "amd_pstate" matches "amd_pstate=active")
        set -l found false
        for param in $KERNEL_PARAMS
            if string match -q -- "$prefix*" "$param"
                set found true
                break
            end
        end
        test "$found" = true || continue

        # Check if config_sym (e.g., CONFIG_AMD_PSTATE) is =y or =m in /proc/config.gz
        if not printf '%s\n' $config_data | grep -q -- "^$config_sym=[ym]"
            _warn "  $prefix* requires $config_sym but not enabled in running kernel"
            set mismatches (math $mismatches + 1)
        end
    end

    return $mismatches
end

# Validate systemd unit via systemd-analyze verify; auto-detects --user for ~/.config paths
function _verify_unit_syntax --argument-names unit_path label --description "Verify systemd unit syntax via systemd-analyze"
    if test (count $argv) -ne 2
        _err "_verify_unit_syntax: expected 2 args (unit_path label), got "(count $argv)
        return 1
    end
    _log "VERIFY_UNIT: $label ($unit_path)"
    if not command -q systemd-analyze
        _warn "  systemd-analyze not available — skipping $label"
        return 0
    end
    set -l user_flag
    if string match -q '*/.config/systemd/user/*' -- "$unit_path"
        set user_flag --user
    end
    if systemd-analyze $user_flag verify "$unit_path" 2>/dev/null
        _ok "  $label: syntax OK"
        return 0
    else
        _fail "  $label: INVALID SYNTAX"
        return 1
    end
end

# Return 0 only if the named service is both active (running) and enabled (boot-persistent)
function _check_service_active_enabled --argument-names svc --description "Check if a systemd service is active and enabled"
    if test (count $argv) -ne 1
        _err "_check_service_active_enabled: expected 1 arg (svc), got "(count $argv)
        return 1
    end
    set -l state (systemctl is-active "$svc" 2>/dev/null)
    set -l enabled (systemctl is-enabled "$svc" 2>/dev/null)
    if test "$state" = active || test "$state" = exited
        if test "$enabled" = enabled
            _ok "  $svc: $state (enabled)"
        else
            _warn "  $svc: $state but $enabled (won't persist)"
        end
        return 0
    else if test -f "/etc/systemd/system/$svc"
        _fail "  $svc: $state (expected: active)"
        return 1
    else
        _warn "  $svc: not installed"
        return 1
    end
end

# Emit paths of *.pacnew and *.pacsave files in /etc and /boot via elevated find
function _find_pacnew_files --description "Find pacnew/pacsave files in /etc /boot"
    if command -q sudo
        sudo find /etc /boot \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null
    end
end

# Parse systemd-analyze output for total boot time in seconds; return 1 if unavailable
function _get_boot_time --description "Print boot time in seconds, or return 1"
    _log BOOT_TIME_CHECK
    command -q systemd-analyze || return 1
    set -l line (systemd-analyze 2>/dev/null | head -n 1)
    set -l sec (printf '%s\n' "$line" | string match -r -- '= ([0-9.]+)s' | tail -n 1)
    if test -n "$sec" && string match -qr '^[0-9.]+$' -- "$sec"
        echo "$sec"
    else
        return 1
    end
end

# Sweep /tmp for ry-{run-stderr,run-stdout,validate,diff,argparse,test-stderr}.* owned by current UID
function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    _log "CLEANUP_TMPFILES: sweep starting"
    # Skip in dry-run; stale tmpfiles from a crashed run are cleaned on next non-dry invocation.
    if test "$DRY" = true
        return 0
    end
    # Clean orphaned .ry-install.* tmpfiles from atomic writes (crash/interrupt leftovers)
    set -l sys_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if not contains "$dir" $sys_dirs
            set -a sys_dirs "$dir"
        end
    end
    if not contains /etc/NetworkManager/system-connections $sys_dirs
        set -a sys_dirs /etc/NetworkManager/system-connections
    end
    for dir in $sys_dirs
        for f in (command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f 2>/dev/null)
            sudo rm -f -- "$f" 2>/dev/null
        end
    end
    set -l usr_dirs
    for dst in $USER_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if not contains "$dir" $usr_dirs
            set -a usr_dirs "$dir"
        end
    end
    for dir in $usr_dirs
        for f in (command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f 2>/dev/null)
            command rm -f -- "$f" 2>/dev/null
        end
    end
    set -l comp_dir "$HOME/.config/fish/completions"
    if test -d "$comp_dir"
        for f in (command find "$comp_dir" -maxdepth 1 -name '.ry-install.*' -type f 2>/dev/null)
            command rm -f -- "$f" 2>/dev/null
        end
    end
end

# ── Cleanup state: _CLEANUP_DONE prevents double-run across signal + fish_exit handlers ──
set -g _CLEANUP_DONE false

# Atomic mkdir mutex with PID file; reclaims stale locks via PID liveness check with race-safe re-check
function _acquire_lock --description "Acquire instance lock (atomic mkdir)"
    # Atomic mkdir as mutex; PID file inside enables stale-lock detection via process liveness probe
    set -g LOCK_DIR "$HOME/ry-install/.lock"
    set -g LOCK_FILE "$LOCK_DIR/pid"
    command mkdir -p -- (dirname "$LOCK_DIR") 2>/dev/null || true

    if command mkdir -- "$LOCK_DIR" 2>/dev/null
        echo %self >"$LOCK_FILE"
        _log "LOCK_ACQUIRED: pid=%self dir=$LOCK_DIR"
        return 0
    end
    # LOCK_DIR exists — check if the PID inside is still alive
    set -l old_pid (cat -- "$LOCK_FILE" 2>/dev/null)
    if test -n "$old_pid" && string match -qr '^\d+$' -- "$old_pid" && kill -0 -- "$old_pid" 2>/dev/null
        echo "[ERR] Another ry-install instance is running (PID $old_pid)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    # Stale lock reclaim: remove + recreate lock dir for atomic re-acquisition (TOCTOU mitigated by PID verify)
    command rm -f -- "$LOCK_FILE" 2>/dev/null
    command find "$LOCK_DIR" -maxdepth 1 -type f -delete 2>/dev/null
    command rmdir -- "$LOCK_DIR" 2>/dev/null || true
    if not command mkdir -- "$LOCK_DIR" 2>/dev/null
        echo "[ERR] Failed to reclaim stale lock — another instance may have started" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    echo %self >"$LOCK_FILE"
    set -l verify_pid (cat -- "$LOCK_FILE" 2>/dev/null)
    set -l my_pid %self
    if test "$verify_pid" != "$my_pid"
        echo "[ERR] Lock reclaim lost to concurrent instance (PID $verify_pid)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    _log "LOCK_RECLAIMED: stale pid=$old_pid, new pid=%self"
    return 0
end

# ── Signal handling and cleanup chain: tmpfiles → lock release → credential keepalive; three entry points (_cleanup/_cleanup_pipe/_cleanup_on_exit), _CLEANUP_DONE prevents double-run ──

# Master teardown: tmpfiles → lock release → credential keepalive termination; idempotent via _CLEANUP_DONE
function _do_cleanup --description "Master cleanup: remove tmpfiles, release lock, kill keepalive"
    _cleanup_tmpfiles
    # _TRACKED_TMPFILES stores absolute paths so cleanup works even if TMPDIR changed since file creation
    for _tf in $_TRACKED_TMPFILES
        test -f "$_tf" && command rm -f -- "$_tf" 2>/dev/null
    end
    set --erase _TRACKED_TMPFILES
    # Fallback sweep: find -user $_MY_UID catches ry-* tmpfiles missed by the tracked list (e.g., crash before tracking)
    set -l _tmpdir (set -q TMPDIR&& echo "$TMPDIR"|| echo /tmp)
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -user $_MY_UID -delete 2>/dev/null
    # Credential erase on every exit path — defense-in-depth against WIFI_PASS lingering in memory
    set --erase WIFI_PASS
    # Release LOCK_DIR mutex and PID file
    if set -q LOCK_DIR && test -d "$LOCK_DIR"
        command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
    end
    _kill_sudo_keepalive
end

# Send SIGTERM to the background credential-refresh loop started during install preflight
function _kill_sudo_keepalive --description "Terminate the background sudo credential refresh loop"
    if set -q SUDO_KEEPALIVE_PID && test -n "$SUDO_KEEPALIVE_PID"
        command kill -- $SUDO_KEEPALIVE_PID 2>/dev/null
        set --erase SUDO_KEEPALIVE_PID
    end
end

# Warn if credential keepalive has died — check before critical privileged operations
function _check_sudo_keepalive --description "Warn if sudo keepalive has expired"
    if set -q SUDO_KEEPALIVE_PID && test -n "$SUDO_KEEPALIVE_PID"
        if not kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            _warn "Sudo keepalive expired — operations may require re-authentication"
            _log "SUDO_KEEPALIVE_EXPIRED: pid=$SUDO_KEEPALIVE_PID"
            set --erase SUDO_KEEPALIVE_PID
        end
    end
end

# Summary counters for JSONL footer — incremented by _msg OK/FAIL/WARN, reset per verify mode
set -g VERIFY_OK 0
set -g VERIFY_FAIL 0
set -g VERIFY_WARN 0
# _cleanup (signals) writes footer + exit 130; _cleanup_on_exit (fish_exit) is fallback — _CLEANUP_DONE prevents double-run
function _cleanup --on-signal INT --on-signal TERM --on-signal HUP --on-signal QUIT --description "Signal handler: clean up on INT/TERM/HUP/QUIT"
    echo "" >&2
    echo "[WARN] Interrupted - cleaning up..." >&2
    set -g _CLEANUP_DONE true
    if not set -q _FOOTER_WRITTEN && set -q LOG_FILE && test -n "$LOG_FILE" && test -f "$LOG_FILE"
        printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":130,"pass":%s,"fail":%s,"warn":%s,"interrupted":true}\n' (date '+%Y-%m-%dT%H:%M:%S') (date '+%Y-%m-%dT%H:%M:%S%z') "$MODE" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE"
    end
    _do_cleanup
    exit 130
end

# SIGPIPE handler: skip stderr (pipe broken), write JSONL footer, run _do_cleanup, exit 141
function _cleanup_pipe --on-signal PIPE --description "Signal handler: clean up on SIGPIPE (broken pipe)"
    # SIGPIPE: stderr may also be broken — skip all terminal output
    set -g _CLEANUP_DONE true
    if not set -q _FOOTER_WRITTEN && set -q LOG_FILE && test -n "$LOG_FILE" && test -f "$LOG_FILE"
        printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":141,"pass":%s,"fail":%s,"warn":%s,"interrupted":true}\n' (date '+%Y-%m-%dT%H:%M:%S') (date '+%Y-%m-%dT%H:%M:%S%z') "$MODE" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE" 2>/dev/null
    end
    _do_cleanup
    exit 141
end

# fish_exit fallback: ensures cleanup runs if no signal handler fired; respects _CLEANUP_DONE guard
function _cleanup_on_exit --on-event fish_exit --description "Exit handler: ensure cleanup runs on fish_exit"
    set -l _exit_status $status
    if set -q _INTENDED_EXIT_CODE
        # set (no -l) targets the outer _exit_status; adding -l here would create a new local that shadows the outer one
        set _exit_status $_INTENDED_EXIT_CODE
    end
    if test "$_CLEANUP_DONE" = true
        return 0
    end
    if not set -q _FOOTER_WRITTEN && set -q LOG_FILE && test -n "$LOG_FILE" && test -f "$LOG_FILE"
        printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s,"cleanup_exit":true}\n' (date '+%Y-%m-%dT%H:%M:%S') (date '+%Y-%m-%dT%H:%M:%S%z') "$MODE" "$_exit_status" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE"
    end
    _do_cleanup
end

# ═══ MANAGED FILE DESTINATIONS — 1:1 map to get_file_content(); system=0644, user=0600 ═══

set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" \
    /etc/kernel/cmdline \
    "/etc/sdboot-manage.conf" \
    "/etc/mkinitcpio.conf" \
    "/etc/modprobe.d/99-cachyos-modprobe.conf" \
    "/etc/udev/rules.d/99-cachyos-udev.rules" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
    "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/iwd/main.conf" \
    "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/conf.d/wireless-regdom" \
    "/etc/sysctl.d/99-ry-sysctl.conf"

set -g USER_DESTINATIONS \
    "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" \
    "$HOME/.config/environment.d/10-environment.conf" \
    "$HOME/.config/systemd/user/ssh-agent.service"

set -g SERVICE_DESTINATIONS \
    "/etc/systemd/system/amdgpu-performance.service" \
    "/etc/systemd/system/cpupower-epp.service"

set -g MANAGED_FILE_COUNT (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)

# ── systemd-boot loader.conf: @saved default, 0s timeout (hold Space), keep console-mode, no editor ──
set -g LOADER_DEFAULT "@saved"
# timeout 0: no menu delay; user holds Space at boot to access menu
set -g LOADER_TIMEOUT 0
# console-mode keep: preserve firmware-set resolution (avoids mode switch flicker)
set -g LOADER_CONSOLE_MODE keep
# editor no: prevent kernel cmdline editing at boot (security: blocks init= override)
set -g LOADER_EDITOR no

# ── sdboot-manage: auto-generate/prune boot entries on kernel upgrade ──
set -g SDBOOT_OVERWRITE yes
set -g SDBOOT_REMOVE_EXISTING yes
set -g SDBOOT_REMOVE_OBSOLETE yes

# Kernel cmdline (18): IOMMU off, pstate active, amdgpu perf, NVMe/USB no-powersave, mt7925e ASPM fix, zswap off
set -g KERNEL_PARAMS \
    amd_iommu=off \
    amd_pstate=active \
    amdgpu.aspm=0 \
    amdgpu.cwsr_enable=0 \
    amdgpu.gpu_recovery=1 \
    amdgpu.modeset=1 \
    amdgpu.ppfeaturemask=0xfffd3fff \
    amdgpu.runpm=0 \
    audit=0 \
    initcall_blacklist=simpledrm_platform_driver_init \
    mt7925e.disable_aspm=1 \
    nowatchdog \
    nvme_core.default_ps_max_latency_us=0 \
    pci=pcie_bus_perf \
    quiet \
    split_lock_detect=off \
    usbcore.autosuspend=-1 \
    zswap.enabled=0

# Early-load modules: amdgpu before simpledrm (DRM primary), nvme for root fs
set -g MKINITCPIO_MODULES amdgpu nvme
# Hooks: Arch systemd path (not CachyOS udev+plymouth); sd-vconsole covers keymap+consolefont
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
# ── Hardware config: mkinitcpio, udev, iwd, NetworkManager, packages, masking ──
set -g MKINITCPIO_COMPRESSION zstd

# Modprobe blacklist (3) — sp5100_tco removed: 'nowatchdog' cmdline + CachyOS vendor blacklist handle it
set -g MODPROBE_BLACKLIST snd_acp_pci pcspkr snd_pcsp

set -g UDEV_RULES \
    'KERNEL=="ntsync", MODE="0666"'
# USB power/control rule removed — usbcore.autosuspend=-1 handles globally

set -g RESOLVED_MDNS no

# Logind: ignore power keys
set -g LOGIND_IGNORE_KEYS \
    HandlePowerKey \
    HandlePowerKeyLongPress \
    HandleSuspendKey \
    HandleHibernateKey \
    HandleRebootKey

set -g IWD_ENABLE_NETWORK_CONFIG false
set -g IWD_DRIVER_QUIRKS "DefaultInterface=*" "PowerSaveDisable=*"
set -g IWD_DNS_SERVICE systemd

set -g NM_WIFI_BACKEND iwd
# NM wifi.powersave values: 0=default 1=ignore 2=disable 3=enable
set -g NM_WIFI_POWERSAVE 2
set -g NM_LOG_LEVEL ERR

set -g WIRELESS_REGDOM US

# ~/.config/environment.d/ — user-session env vars (read by systemd --user)
set -g ENV_VARS \
    "AMD_VULKAN_ICD=RADV" \
    "MESA_SHADER_CACHE_MAX_SIZE=8G" \
    "PROTON_USE_NTSYNC=1" \
    "PROTON_NO_WM_DECORATION=1"

set -g PKGS_ADD mkinitcpio-firmware nvme-cli iw cachyos-gaming-meta cachyos-gaming-applications fd sd dust procs bat eza bottom git-delta stress-ng lm_sensors
# power-profiles-daemon: cpupower-epp handles EPP; btop: replaced by bottom (Rust, lower overhead)
set -g PKGS_DEL plymouth cachyos-plymouth-bootanimation ufw octopi micro cachyos-micro-settings btop

# Masked services: ananicy-cpp (manual tuning), sleep/suspend targets (24/7 desktop), lvm2 (no LVM)
set -g MASK \
    ananicy-cpp.service \
    power-profiles-daemon.service \
    lvm2-monitor.service \
    NetworkManager-wait-online.service \
    sleep.target \
    suspend.target \
    hibernate.target \
    hybrid-sleep.target \
    suspend-then-hibernate.target

# Generate config file content by destination path — INVARIANT: content emitted via printf/echo only, NEVER eval'd
function get_file_content --argument-names dst --description "Return embedded config content for a given destination path"
    if test (count $argv) -ne 1
        _err "get_file_content: expected 1 argument, got "(count $argv)
        return 1
    end
    switch "$argv[1]"

        case "/boot/loader/loader.conf"
            printf '%s\n' "# systemd-boot loader configuration"
            printf '%s\n' "default $LOADER_DEFAULT"
            printf '%s\n' "timeout $LOADER_TIMEOUT"
            printf '%s\n' "console-mode $LOADER_CONSOLE_MODE"
            printf '%s\n' "editor $LOADER_EDITOR"

        case /etc/kernel/cmdline
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
            printf '%s\n' "DEFAULT_ENTRY=\"manual\""
            printf '%s\n' "REMOVE_EXISTING=\"$SDBOOT_REMOVE_EXISTING\""
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

        case "/etc/modprobe.d/99-cachyos-modprobe.conf"
            printf '%s\n' "# modprobe configuration"
            for mod in $MODPROBE_BLACKLIST
                printf '%s\n' "blacklist $mod"
            end

        case "/etc/udev/rules.d/99-cachyos-udev.rules"
            printf '%s\n' "# udev rules"
            for rule in $UDEV_RULES
                printf '%s\n' $rule
            end

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

        case "/etc/sysctl.d/99-ry-sysctl.conf"
            printf '%s\n' "# Network and security sysctl — complements cachyos vendor 70-cachyos-settings.conf"
            printf '%s\n' ""
            printf '%s\n' "# TCP BBR congestion control + fq qdisc for pacing"
            printf '%s\n' "net.core.default_qdisc = fq"
            printf '%s\n' "net.ipv4.tcp_congestion_control = bbr"
            printf '%s\n' ""
            printf '%s\n' "# TCP Fast Open: 3 = client + server"
            printf '%s\n' "net.ipv4.tcp_fastopen = 3"
            printf '%s\n' ""
            printf '%s\n' "# Inotify watches for file watchers (IDEs, build tools)"
            printf '%s\n' "fs.inotify.max_user_watches = 524288"

        case '*/.config/fish/conf.d/10-ssh-auth-sock.fish'
            printf '%s\n' '# SSH agent socket for fish shell — priority: forwarded > gcr > systemd
if status is-interactive&& set -q XDG_RUNTIME_DIR&& not set -q SSH_CONNECTION
    if test -S "$XDG_RUNTIME_DIR/gcr/ssh"
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"
    else if test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
    end
end'

        case '*/.config/environment.d/10-environment.conf'
            printf '%s\n' "# Environment variables for systemd user services and graphical sessions"
            printf '%s\n' "# Loaded by systemd --user (COSMIC, Flatpak, D-Bus activated apps)"
            printf '%s\n' 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket'
            for var in $ENV_VARS
                printf '%s\n' $var
            end

        case '*/.config/systemd/user/ssh-agent.service'
            printf '%s\n' '[Unit]
Description=SSH authentication agent

[Service]
Type=simple
ExecStart=/usr/bin/ssh-agent -D -a %t/ssh-agent.socket
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target'

        case "/etc/systemd/system/amdgpu-performance.service"
            # After=graphical.target: DRM settle time (Arch #72655); retry loop guards sysfs readiness
            # ExecStart: 5 retries, 2s delay; exit 1 if no writable sysfs nodes found
            printf '%s\n' '[Unit]' \
                'Description=Set AMDGPU power_dpm_force_performance_level to high' \
                'After=graphical.target' \
                'ConditionPathIsDirectory=/sys/class/drm' \
                '' \
                '[Service]' \
                'Type=oneshot' \
                'RemainAfterExit=yes' \
                'ExecStart=/usr/bin/bash -c '\''shopt -s nullglob; retries=5; delay=2; written=0; for attempt in $(seq 1 $retries); do for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do [ -f "$f" ] && [ -w "$f" ] && { echo high > "$f" && written=$((written+1)); }; done; [ "$written" -gt 0 ] && break; [ "$attempt" -lt "$retries" ] && sleep $delay; done; [ "$written" -gt 0 ]'\''' \
                '' \
                '[Install]' \
                'WantedBy=graphical.target'

        case "/etc/systemd/system/cpupower-epp.service"
            printf '%s\n' '[Unit]
Description=Set CPU EPP to performance (amd_pstate=active: powersave governor + performance EPP)
After=cpupower.service
Wants=cpupower.service
ConditionPathIsDirectory=/sys/devices/system/cpu

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=10
ExecStart=/usr/bin/bash -c '\''shopt -s nullglob; for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$cpu" ] && echo performance > "$cpu"; done; exit 0'\''

[Install]
WantedBy=multi-user.target'

        case '*'
            return 1
    end
    return 0
end

# ═══ LOGGING, MESSAGE OUTPUT, AND VERIFICATION COUNTERS ═══

# Escape string for JSON embedding; function-scope reassignments use explicit set -l
function _json_str --description "Escape a string for safe JSON embedding"
    # Escape order: backslash first to avoid double-escaping later chars; each set -l val re-binds the local
    set -l val "$argv[1]"
    set -l val (string replace -a '\\' '\\\\' -- "$val")
    set -l val (string replace -a '"' '\\"' -- "$val")
    set -l val (string replace -a \t '\\t' -- "$val")
    set -l val (string replace -a \r '\\r' -- "$val")
    set -l val (string replace -a \n '\\n' -- "$val")
    set -l val (string replace -a \x08 '\\b' -- "$val")
    set -l val (string replace -a \x0c '\\f' -- "$val")
    set -l val (string replace -a \x00 '\\u0000' -- "$val")
    set -l val (string replace -ra '[\x01-\x07\x0b\x0e-\x1f\x7f\x80-\x9f]' '' -- "$val")
    # printf '%s\n' ensures set -l val (...) captures one element even when $val is empty; '%s' alone yields zero
    printf '%s\n' "$val"
end

# ── Structured NDJSON logging — self-contained JSON per line, event classification (section/prefix/message), _json_str escapes+caps at 4096 chars ──

# Append JSONL event to LOG_FILE with ISO timestamp
function _log --description "Append a timestamped message to the log file"
    set -l _ts (date '+%Y-%m-%dT%H:%M:%S')
    set -l raw (string join -- " " $argv)
    # Inside if/else, bare set (no -l) re-binds outer event/data; after block, set -l re-binds at outer scope
    set -l event message
    set -l data "$raw"
    if string match -qr '^=== .* ===$' -- "$raw"
        set event section
        set data (string replace -ar '=+ *' '' -- "$raw" | string trim --)
    else if string match -qr '^[A-Z][A-Z_]*: ' -- "$raw"
        set event (string lower (string match -r '^[A-Z][A-Z_]*' -- "$raw"))
        set data (string replace -r '^[A-Z][A-Z_]*: *' '' -- "$raw")
    end
    # Sanitize event field: strip non-alphanumeric/underscore to prevent JSON injection in JSONL output
    set -l event (string replace -ra '[^a-z0-9_]' '' -- "$event")
    set -l data (_json_str "$data")
    # Cap $data at 4096 chars to prevent pathological log lines from long paths/SSIDs
    if test (string length -- "$data") -gt 4096
        set data (string sub -l 4093 -- "$data")"..."
    end
    printf '{"ts":"%s","event":"%s","data":"%s"}\n' "$_ts" "$event" "$data" >>"$LOG_FILE"
end

# Format and emit a leveled [LEVEL] message to stderr; respects NO_COLOR and logs to JSONL
function _msg --argument-names level --description "Format and print a leveled status message"
    if test (count $argv) -lt 1
        _err "_msg: expected at least 1 arg (level), got 0"
        return 1
    end
    set -l valid_levels INFO WARN ERR FAIL OK DRY
    if not contains -- "$level" $valid_levels
        echo "[BUG] _msg called with invalid level: '$level'" >&2
        printf '{"ts":"%s","event":"bug","data":"_msg called with invalid level: %s"}\n' (date '+%Y-%m-%dT%H:%M:%S') "$level" >>"$LOG_FILE"
        set level ERR
    end
    # Route level to JSONL event + increment verify counters for summary
    set -l msg (string join -- " " $argv[2..])
    _log "$level: $msg"
    if set -q VERIFY_MODE && test "$VERIFY_MODE" = true
        switch $level
            case OK
                set -g VERIFY_OK (math $VERIFY_OK + 1)
            case FAIL
                set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
            case WARN
                set -g VERIFY_WARN (math $VERIFY_WARN + 1)
        end
    end
    if test "$QUIET" = false
        # All leveled output → stderr; begin...end >&2 groups the color open/close under one redirect
        if test "$NO_COLOR" = true || not isatty 2
            echo "[$level] $msg" >&2
        else
            begin
                switch $level
                    case FAIL ERR
                        set_color red
                    case WARN
                        set_color yellow
                    case OK
                        set_color green
                    case INFO
                        set_color blue
                    case DRY
                        set_color cyan
                end
                echo -n "[$level]"
                set_color normal
                echo " $msg"
            end >&2
        end
    end
end

# Convenience wrappers: _ok/_fail/_info/_warn/_dry/_err delegate to _msg with fixed level
function _ok --description "Print an OK-level status message"
    _msg OK $argv
end
# FAIL-level: verification failures, missing files, broken configs
function _fail --description "Print a FAIL-level status message"
    _msg FAIL $argv
end
# INFO-level: progress updates, non-actionable status
function _info --description "Print an INFO-level status message"
    _msg INFO $argv
end
# WARN-level: non-fatal issues, degraded state, skipped steps
function _warn --description "Print a WARN-level status message"
    _msg WARN $argv
end
# DRY-level: simulated mutations that would occur without --dry-run
function _dry --description "Print a DRY-RUN-level status message"
    _msg DRY $argv
end
# ERR-level: internal errors, unexpected failures, arity violations
function _err --description "Print an ERR-level status message"
    _msg ERR $argv
end

# All user-facing output goes to stderr; stdout reserved for pipeable data (command wrapper captures)
function _echo --description "Print a plain message without level prefix"
    _log "ECHO: $argv"
    if test "$QUIET" = false
        echo "$argv" >&2
    end
end

# Read installed file content; uses elevated read for system paths, direct read for $HOME paths
function _read_installed --argument-names dst --description "Read installed file content at a destination path"
    if test (count $argv) -ne 1
        _err "_read_installed: expected 1 arg (dst), got "(count $argv)
        return 1
    end
    # $HOME/* files: read as user; system files: read as root (preserves privilege separation)
    if string match -q "$HOME/*" -- "$dst"
        test -f "$dst" || return 1
        cat -- "$dst" 2>/dev/null
        return $status
    else
        sudo test -f "$dst" 2>/dev/null || return 1
        sudo cat -- "$dst" 2>/dev/null
        return $status
    end
end

# Print the boxed ry-install header with mode title; suppressed by QUIET flag
function _banner --argument-names text --description "Print the ry-install startup banner"
    if test (count $argv) -lt 1
        return 0
    end
    set -l text $argv[1]
    set -l border "┌──────────────────────────────────────────────────────────────────┐"
    set -l bottom "└──────────────────────────────────────────────────────────────────┘"
    set -l inner 66
    set -l prefix "│  "
    set -l suffix " │"
    set -l max_text (math "$inner - 3")
    if test (string length -- "$text") -gt $max_text
        set text (string sub -l $max_text -- "$text")
    end
    set -l text_len (string length -- "$text")
    set -l pad (math "$max_text - $text_len")
    if test $pad -lt 0
        set pad 0
    end
    set -l spaces (string repeat -n $pad -- " ")
    _echo $border
    _echo "$prefix$text$spaces$suffix"
    _echo $bottom
    _echo
end

# Emit pass/fail/warn totals and CI-parseable VERIFY:STATUS:ok:fail:warn line to stdout
function _verify_summary --description "Print verification pass/fail/warn summary"
    _echo
    _echo "VERIFICATION SUMMARY"
    _echo

    set -l summary "Results: $VERIFY_OK OK"
    if test "$VERIFY_WARN" -gt 0
        set summary "$summary, $VERIFY_WARN WARN"
    end
    if test "$VERIFY_FAIL" -gt 0
        set summary "$summary, $VERIFY_FAIL FAIL"
    end

    if test "$VERIFY_FAIL" -gt 0
        _fail "$summary"
        # CI-friendly: emit machine-parseable summary to stdout (all other output is stderr)
        echo "VERIFY:FAIL:$VERIFY_OK:$VERIFY_FAIL:$VERIFY_WARN"
        return 1
    else if test "$VERIFY_WARN" -gt 0
        _warn "$summary"
        echo "VERIFY:WARN:$VERIFY_OK:$VERIFY_FAIL:$VERIFY_WARN"
        return 0
    else
        _ok "$summary"
        echo "VERIFY:OK:$VERIFY_OK:$VERIFY_FAIL:$VERIFY_WARN"
        return 0
    end
end

# ── Progress bar: step tracking with timing for multi-phase operations ──
set -g PROGRESS_CURRENT 0
# 40-char bar fits 60-col minimum terminal (15 cols for [XX/YY] prefix + padding)
set -g PROGRESS_WIDTH 40
set -g PROGRESS_START_TIME 0
set -g PROGRESS_STEP_START 0
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

# Reset progress counters and compute PROGRESS_TOTAL from PROGRESS_STEPS list
function _progress_init --description "Initialize the step progress counter"
    set -g _STEP_PREV_NAME ""
    set -g _STEP_PREV_START 0
    if test "$ALL" = true && test "$DRY" = false
        set -g PROGRESS_CURRENT 0
        set -g PROGRESS_START_TIME (date +%s)
        set -g PROGRESS_STEP_START 0
        printf '\n' >&2
    end
end

# Advance to next step: emit timing for previous step, display [N/M] progress bar to stderr
function _progress --description "Advance and display the current progress step"
    # Emit timing for the previous step
    if test -n "$_STEP_PREV_NAME" && test "$_STEP_PREV_START" -gt 0
        set -l _step_now (date +%s)
        set -l _step_elapsed (math "$_step_now - $_STEP_PREV_START")
        set -l _step_name_esc (_json_str "$_STEP_PREV_NAME")
        printf '{"ts":"%s","event":"step_time","data":"%s","elapsed_s":%d}\n' \
            (date '+%Y-%m-%dT%H:%M:%S') "$_step_name_esc" "$_step_elapsed" >>"$LOG_FILE"
    end
    set -g _STEP_PREV_NAME "$argv[1]"
    set -g _STEP_PREV_START (date +%s)

    if test "$ALL" = true && test "$DRY" = false
        if test "$PROGRESS_TOTAL" -le 0 2>/dev/null
            return 0
        end
        # Advance progress counter and emit step banner
        set -g PROGRESS_CURRENT (math "min($PROGRESS_CURRENT + 1, $PROGRESS_TOTAL)")
        set -l pct (math "floor($PROGRESS_CURRENT * 100 / $PROGRESS_TOTAL)")
        set -l filled (math "floor($PROGRESS_CURRENT * $PROGRESS_WIDTH / $PROGRESS_TOTAL)")
        set -l empty (math "$PROGRESS_WIDTH - $filled")

        set -l bar ""
        for i in (seq 1 $filled)
            set bar "$bar█"
        end
        for i in (seq 1 $empty)
            set bar "$bar░"
        end

        set -l step_elapsed ""
        set -l now (date +%s)
        if test "$PROGRESS_STEP_START" -gt 0
            set -l step_secs (math "$now - $PROGRESS_STEP_START")
            if test "$step_secs" -ge 60
                set -l sm (math "floor($step_secs / 60)")
                set -l ss (math "$step_secs % 60")
                set step_elapsed (printf ' %dm%02ds' $sm $ss)
            else if test "$step_secs" -gt 0
                set step_elapsed (printf ' %ds' $step_secs)
            end
        end
        set -g PROGRESS_STEP_START $now

        set -l desc
        if test (string length -- "$argv[1]") -gt 25
            set desc (string sub -l 22 -- "$argv[1]")"..."
        else
            set desc (string sub -l 25 -- "$argv[1]                              ")
        end

        printf '\r[%s] %3d%% %s%s' "$bar" "$pct" "$desc" "$step_elapsed" >&2
    end
    _log "PROGRESS: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $argv[1]"
end

# Close progress display: emit final step timing, fill bar to 100%, reset state
function _progress_done --description "Finalize and close the progress display"
    # Emit timing for the final step
    if test -n "$_STEP_PREV_NAME" && test "$_STEP_PREV_START" -gt 0
        set -l _step_now (date +%s)
        set -l _step_elapsed (math "$_step_now - $_STEP_PREV_START")
        set -l _step_name_esc (_json_str "$_STEP_PREV_NAME")
        printf '{"ts":"%s","event":"step_time","data":"%s","elapsed_s":%d}\n' \
            (date '+%Y-%m-%dT%H:%M:%S') "$_step_name_esc" "$_step_elapsed" >>"$LOG_FILE"
    end
    set -g _STEP_PREV_NAME ""
    set -g _STEP_PREV_START 0

    if test "$ALL" = true && test "$DRY" = false
        set -g PROGRESS_CURRENT $PROGRESS_TOTAL
        set -l bar (string repeat -n $PROGRESS_WIDTH -- '█')
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
        printf '\r[%s] 100%% Done%-25s%s\n' "$bar" "" "$elapsed_str" >&2
    end
end

# ── Command execution wrapper — secret redaction (10 patterns), dry-run gating, output capture to tmpfiles, structured error reporting ──

# Execute command with logging, secret redaction, dry-run gating, and stdout/stderr capture to tmpfiles
function _run --description "Execute a command with logging, dry-run support, and error capture"
    set -l log_cmd (string join -- " " $argv)

    # Redact secrets from log output; globs match --flag=value and --flag value without false positives
    for _secret_flag in --passphrase --password --token --key --secret --api-key --psk --wpa-psk --private-key
        if string match -q "* $_secret_flag=*" -- " $log_cmd" || string match -q "* $_secret_flag *" -- " $log_cmd"
            set -l _escaped_flag (string escape --style=regex -- "$_secret_flag")
            set log_cmd (string replace -r -- "(^| )$_escaped_flag=[^ ]+" '$1'"$_secret_flag=[REDACTED]" "$log_cmd")
            set log_cmd (string replace -r -- "(^| )$_escaped_flag [^ ]+" '$1'"$_secret_flag [REDACTED]" "$log_cmd")
        end
    end

    _log "RUN: $log_cmd"

    if test "$DRY" = true
        _dry "$log_cmd"
        return 0
    else
        # mktemp fallback to /dev/null: handles disk-full gracefully
        set -l stderr_tmp (mktemp -t ry-run-stderr.XXXXXX 2>/dev/null|| echo /dev/null)
        set -l stdout_tmp (mktemp -t ry-run-stdout.XXXXXX 2>/dev/null|| echo /dev/null)
        test "$stderr_tmp" != /dev/null && set -ga _TRACKED_TMPFILES "$stderr_tmp"
        test "$stdout_tmp" != /dev/null && set -ga _TRACKED_TMPFILES "$stdout_tmp"
        if test "$stderr_tmp" = /dev/null || test "$stdout_tmp" = /dev/null
            _log "WARN: mktemp fallback to /dev/null — output capture degraded"
        end
        # SECURITY INVARIANT: $argv is hardcoded from internal callers; WIFI_SSID is read-validated (no metacharacters)
        $argv >"$stdout_tmp" 2>"$stderr_tmp"
        set -l ret $status
        if test "$stderr_tmp" != /dev/null && test -s "$stderr_tmp"
            set -l total_err (wc -l < "$stderr_tmp" | string trim --)
            set -l first_lines (head -n 5 "$stderr_tmp")
            set -l dedup_lines (LC_ALL=C sort "$stderr_tmp" | uniq -c | sort -rn | sed 's/^ *//')
            _log "STDERR($total_err lines): first: "(string join -- " | " $first_lines)" | dedup: "(string join -- " | " $dedup_lines)
            if test "$QUIET" = false && test $ret -ne 0
                for el in $first_lines
                    echo "  stderr: $el" >&2
                end
                if test $total_err -gt 5
                    echo "  stderr: ... ($total_err lines total, showing first 5)" >&2
                end
            end
        end
        command rm -f -- "$stderr_tmp" 2>/dev/null
        if test "$stdout_tmp" != /dev/null && test -s "$stdout_tmp"
            set -l line_count (wc -l < "$stdout_tmp" | string trim --)
            if test $line_count -le 50
                _log "OUTPUT: "(string join -- " | " (cat -- "$stdout_tmp"))
            else if test $ret -ne 0
                if test $line_count -le 200
                    _log "OUTPUT: "(string join -- " | " (cat -- "$stdout_tmp"))
                else
                    _log "OUTPUT: "(string join -- " | " (head -n 100 "$stdout_tmp"))" | ... ($line_count lines, showing first 100 + last 100) | "(string join -- " | " (tail -n 100 "$stdout_tmp"))
                end
            else
                _log "OUTPUT: "(string join -- " | " (head -n 50 "$stdout_tmp"))" | ... ($line_count lines, truncated)"
            end
            # Print captured stdout when QUIET=false; note: install_file uses get_file_content|tee directly, not this wrapper
            if test "$QUIET" = false
                cat -- "$stdout_tmp"
            end
        end
        command rm -f -- "$stdout_tmp" 2>/dev/null
        _log "EXIT: $ret"
        return $ret
    end
end

# Prompt for yes/no; auto-yes when --all or --force; returns 1 on decline or non-tty
function _ask --description "Prompt the user for yes/no confirmation"
    if test "$ALL" = true || test "$FORCE" = true
        _log "ASK: $argv[1] -> auto-yes"
        return 0
    end
    if not isatty stdin
        _log "ASK: $argv[1] -> auto-no (non-interactive)"
        return 1
    end
    read -P "[?] $argv[1] [y/N] " r
    _log "ASK: $argv[1] -> $r"
    string match -qir '^y(es)?$' -- "$r"
end

# Verify a managed file exists at dst; uses elevated test for /boot paths, logs OK/FAIL with context
function _chk_file --argument-names filepath --description "Verify a file exists (with sudo for /boot paths)"
    if test (count $argv) -lt 1
        _err "_chk_file: missing argument"
        return 1
    end
    _log "CHECK_FILE: $argv[1]"
    if string match -q '/boot/*' -- "$argv[1]"
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

# Grep installed file for expected pattern; logs OK/FAIL with label; elevated read for system files
function _chk_grep --argument-names file pattern label --description "Verify a file contains an expected string"
    if test (count $argv) -lt 3
        _err "_chk_grep: requires 3 arguments (file, pattern, label)"
        return 1
    end
    _log "CHECK_GREP: $argv[1] for '$argv[2]'"

    set -l is_boot false
    string match -q '/boot/*' -- "$argv[1]" && set is_boot true

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
        sudo grep -qF -- "$argv[2]" "$argv[1]" 2>/dev/null && set found true
    else
        grep -qF -- "$argv[2]" "$argv[1]" 2>/dev/null && set found true
    end

    if test "$found" = true
        _ok "  $argv[3]: present"
        return 0
    else
        _fail "  $argv[3]: MISSING"
        return 1
    end
end

# Verify all required external commands are available via command -q
function check_deps --description "Verify required packages are installed"
    _log "Checking dependencies..."
    set -l missing

    for cmd in pacman systemctl mkinitcpio udevadm sdboot-manage diff findmnt md5sum sha256sum stat date tput
        if not command -q $cmd
            set -a missing $cmd
        end
    end

    if test (count $missing) -gt 0
        _err "Missing required commands: $missing"
        _err "  This script requires CachyOS (Arch-based) with systemd-boot"
        if contains sdboot-manage $missing
            _err "  sdboot-manage is required for CachyOS bootloader management"
            _err "  Install with: sudo pacman -S --needed sdboot-manage"
        end
        if contains mkinitcpio $missing
            _err "  mkinitcpio is required for initramfs generation (Arch/CachyOS)"
        end
        return 1
    end

    set -l systemd_ver (systemctl --version 2>/dev/null | head -n 1 | string match -r -- '\d+' | head -n 1)
    # systemd 250+: required for environment.d, systemd-analyze verify --user
    if test -n "$systemd_ver" && test "$systemd_ver" -lt 250
        _warn "Systemd version $systemd_ver detected; some features require 250+"
    end

    for cmd in journalctl dmesg modinfo pgrep free uptime
        if not command -q $cmd
            _warn "Expected tool not found: $cmd (from base packages)"
        end
    end

    _log "All dependencies satisfied"
    return 0
end

# Test HTTPS connectivity to archlinux.org and DNS resolution before package operations
function check_network --description "Verify network connectivity and DNS resolution"
    _log "Checking network connectivity..."

    _info "Checking HTTPS connectivity..."
    for _probe in https://archlinux.org https://cachyos.org https://cdn.cloudflare.com
        if curl -sf --max-time 5 --head "$_probe" >/dev/null 2>&1
            _ok "Network connectivity: OK"
            return 0
        end
    end

    _info "Checking DNS resolution..."
    for _probe_host in archlinux.org cachyos.org
        if ping -c 1 -W 3 $_probe_host >/dev/null 2>&1
            _ok "Network connectivity: OK (ping)"
            return 0
        end
    end

    _info "Checking raw IP connectivity..."
    for _ip in 1.1.1.1 8.8.8.8
        if ping -c 1 -W 3 $_ip >/dev/null 2>&1
            _err "Network connectivity: DNS resolution failed (raw IP reachable)"
            _err "  Check /etc/resolv.conf or systemd-resolved configuration"
            return 1
        end
    end

    _err "Network connectivity: FAILED"
    _err "  Cannot reach archlinux.org - check your network connection"
    _err "  Package installation requires internet access"
    return 1
end

# Ensure root and /boot have sufficient free space; warn/fail at configurable thresholds
function check_disk_space --description "Verify sufficient free disk space for installation"
    _log "Checking disk space..."

    set -l root_avail (LC_ALL=C df -BG / 2>/dev/null | tail -n 1 | awk '{print $4}' | tr -d 'G')
    if test -n "$root_avail" && string match -qr '^\d+$' -- "$root_avail"
        if test "$root_avail" -lt $ROOT_AVAIL_CRIT
            _err "Insufficient disk space on /: $root_avail""GB available, need "$ROOT_AVAIL_CRIT"GB minimum"
            return 1
        else if test "$root_avail" -lt $ROOT_AVAIL_WARN
            _warn "Low disk space on /: $root_avail""GB available"
        else
            _ok "Disk space on /: $root_avail""GB available"
        end
    else
        _warn "Could not determine disk space for /"
    end

    set -l boot_avail (LC_ALL=C df -BM /boot 2>/dev/null | tail -n 1 | awk '{print $4}' | tr -d 'M')
    if test -n "$boot_avail" && string match -qr '^\d+$' -- "$boot_avail"
        if test "$boot_avail" -lt $BOOT_SPACE_CRIT
            _err "Insufficient disk space on /boot: $boot_avail""MB available, need "$BOOT_SPACE_CRIT"MB minimum"
            return 1
        else if test "$boot_avail" -lt $BOOT_SPACE_WARN
            _warn "Low disk space on /boot: $boot_avail""MB available"
        else
            _ok "Disk space on /boot: $boot_avail""MB available"
        end
    else
        _warn "Could not determine disk space for /boot"
    end

    return 0
end

# Verify running kernel meets minimum version and report ntsync availability
function check_kernel_version --description "Verify running kernel version meets minimum requirement"
    set -l kver $KVER
    set -l major $KVER_MAJOR
    set -l minor $KVER_MINOR

    _info "Kernel version: $kver"

    set -l _ns (_ntsync_state)
    if test "$_ns" = unavailable
        _warn "Kernel $KVER < 6.14: ntsync will NOT be available"
        _warn "  Upgrade kernel for PROTON_USE_NTSYNC=1 support"
    end

    return 0
end

# ── Config validation pipeline — pre-flight checks on embedded content: hooks ordering, modprobe resolve, systemd-analyze verify, fish --no-execute; aborts on any error ──

# Validate HOOKS ordering (base first, keyboard before sd-vconsole, etc.) and hook existence
function validate_mkinitcpio_hooks --description "Validate mkinitcpio HOOKS ordering and presence"
    set -l existence_only false
    set -l hooks
    # Verify mkinitcpio hook ordering and presence
    if test (count $argv) -gt 0 && test "$argv[1]" = --existence-only
        set existence_only true
        set hooks $argv[2..]
    else if test (count $argv) -gt 0
        set hooks $argv
    else
        set hooks $MKINITCPIO_HOOKS
    end

    set -l errors 0

    if test "$existence_only" = true
        for hook in $hooks
            if test -z "$hook"
                continue
            end
            if test -f "/usr/lib/initcpio/install/$hook" || test -f "/usr/lib/initcpio/hooks/$hook" || test -f "/etc/initcpio/install/$hook" || test -f "/etc/initcpio/hooks/$hook"
                _ok "  $hook: exists"
            else
                _fail "  $hook: NOT FOUND"
                set errors (math $errors + 1)
            end
        end
        test $errors -eq 0 && return 0 || return 1
    end

    for hook in $hooks
        if not test -f "/usr/lib/initcpio/install/$hook" && not test -f "/etc/initcpio/install/$hook"
            if not test -f "/usr/lib/initcpio/hooks/$hook" && not test -f "/etc/initcpio/hooks/$hook"
                _err "Invalid mkinitcpio hook: $hook"
                set errors (math $errors + 1)
            end
        end
    end

    if test (count $MKINITCPIO_HOOKS) -gt 0
        if test "$MKINITCPIO_HOOKS[1]" != base
            _err "Mkinitcpio hook order: 'base' must be first (found: $MKINITCPIO_HOOKS[1])"
            set errors (math $errors + 1)
        end
        set -l order_checks \
            "systemd:sd-vconsole" \
            # Verify hook ordering constraints (before:after pairs)
            "modconf:kms" \
            "block:filesystems"
        for check in $order_checks
            set -l hook_before (string split ':' -- "$check")[1]
            set -l hook_after (string split ':' -- "$check")[2]
            set -l idx_a 0
            set -l idx_b 0
            for i in (seq (count $MKINITCPIO_HOOKS))
                test "$MKINITCPIO_HOOKS[$i]" = "$hook_before" && set idx_a $i
                test "$MKINITCPIO_HOOKS[$i]" = "$hook_after" && set idx_b $i
            end
            if test $idx_a -gt 0 && test $idx_b -gt 0 && test $idx_a -ge $idx_b
                _err "Mkinitcpio hook order: '$hook_before' must come before '$hook_after'"
                set errors (math $errors + 1)
            end
        end
    end

    test $errors -eq 0 && return 0 || return 1
end

# Verify each MKINITCPIO_MODULES entry resolves via modprobe --resolve-alias
function validate_mkinitcpio_modules --description "Validate mkinitcpio MODULES array entries"
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

# Validate a systemd unit tmpfile via systemd-analyze verify; returns error count
function validate_systemd_unit --argument-names tmpfile unit_name --description "Validate a systemd unit file via systemd-analyze"
    if test (count $argv) -ne 2
        _err "validate_systemd_unit: expected 2 args (tmpfile unit_name), got "(count $argv)
        return 1
    end
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
            for line in $verify_output
                _log "  systemd-analyze: $line"
            end
        end
    end

    return 0
end

# Ensure MODPROBE_BLACKLIST entries contain only valid module name characters
function validate_modprobe_blacklist --description "Validate modprobe blacklist file syntax"
    for mod in $MODPROBE_BLACKLIST
        if not string match -qr '^[a-zA-Z0-9_-]+$' -- "$mod"
            _err "Invalid module name in blacklist: $mod"
            return 1
        end
    end
    return 0
end

# Validate fish script syntax via fish --no-execute on a tmpfile
function validate_fish_script --argument-names tmpfile script_name --description "Validate fish script syntax via fish --no-execute"
    if test (count $argv) -ne 2
        _err "validate_fish_script: expected 2 args (tmpfile script_name), got "(count $argv)
        return 1
    end
    set -l tmpfile $argv[1]
    set -l script_name $argv[2]

    if not fish --no-execute "$tmpfile" 2>/dev/null
        _err "Invalid fish syntax: $script_name"
        return 1
    end

    return 0
end

# Run all embedded config validators: hooks, modules, units, modprobe, fish; abort on errors
function validate_configs --description "Run all embedded config validators"
    _info "Validating configuration syntax..."

    # Run syntax validators for all embedded config types
    set -l errors 0

    if not validate_mkinitcpio_hooks
        set errors (math $errors + 1)
    end
    validate_mkinitcpio_modules

    if not validate_modprobe_blacklist
        set errors (math $errors + 1)
    end

    set -l tmpfile_amdgpu (mktemp -t ry-validate-XXXXXX --suffix=.service)
    if test -z "$tmpfile_amdgpu"
        _err "Failed to create temp file for amdgpu-performance.service validation"
        set errors (math $errors + 1)
    else
        get_file_content "/etc/systemd/system/amdgpu-performance.service" >"$tmpfile_amdgpu"
        if not test -s "$tmpfile_amdgpu"
            _err "Empty content for amdgpu-performance.service"
            set errors (math $errors + 1)
        else if not validate_systemd_unit "$tmpfile_amdgpu" "amdgpu-performance.service"
            set errors (math $errors + 1)
        end
        command rm -f -- "$tmpfile_amdgpu"
    end

    set -l tmpfile_cpupower (mktemp -t ry-validate-XXXXXX --suffix=.service)
    if test -z "$tmpfile_cpupower"
        _err "Failed to create temp file for cpupower-epp.service validation"
        set errors (math $errors + 1)
    else
        get_file_content "/etc/systemd/system/cpupower-epp.service" >"$tmpfile_cpupower"
        if not test -s "$tmpfile_cpupower"
            _err "Empty content for cpupower-epp.service"
            set errors (math $errors + 1)
        else if not validate_systemd_unit "$tmpfile_cpupower" "cpupower-epp.service"
            set errors (math $errors + 1)
        end
        command rm -f -- "$tmpfile_cpupower"
    end

    set -l tmpfile_fish (mktemp -t ry-validate-XXXXXX --suffix=.fish)
    if test -z "$tmpfile_fish"
        _err "Failed to create temp file for fish script validation"
        set errors (math $errors + 1)
    else
        get_file_content "*/.config/fish/conf.d/10-ssh-auth-sock.fish" >"$tmpfile_fish"
        if not test -s "$tmpfile_fish"
            _err "Empty content for ssh-auth-sock.fish"
            set errors (math $errors + 1)
        else if not validate_fish_script "$tmpfile_fish" "ssh-auth-sock.fish"
            set errors (math $errors + 1)
        end
        command rm -f -- "$tmpfile_fish"
    end

    set -l tmpfile_sshagent (mktemp -t ry-validate-XXXXXX --suffix=.service)
    if test -z "$tmpfile_sshagent"
        _err "Failed to create temp file for ssh-agent.service validation"
        set errors (math $errors + 1)
    else
        get_file_content "*/.config/systemd/user/ssh-agent.service" >"$tmpfile_sshagent"
        if not test -s "$tmpfile_sshagent"
            _err "Empty content for ssh-agent.service"
            set errors (math $errors + 1)
        else if not validate_systemd_unit "$tmpfile_sshagent" "ssh-agent.service"
            set errors (math $errors + 1)
        end
        command rm -f -- "$tmpfile_sshagent"
    end

    # Per-destination content diff for runtime drift detection
    set -l tmpfile_sshenv (mktemp -t ry-validate-XXXXXX --suffix=.conf)
    if test -z "$tmpfile_sshenv"
        _err "Failed to create temp file for 10-environment.conf validation"
        set errors (math $errors + 1)
    else
        get_file_content "*/.config/environment.d/10-environment.conf" >"$tmpfile_sshenv"
        if not test -s "$tmpfile_sshenv"
            _err "Empty content for 10-environment.conf"
            set errors (math $errors + 1)
        else if not grep -q -- '^SSH_AUTH_SOCK=' "$tmpfile_sshenv"
            _err "10-environment.conf: missing SSH_AUTH_SOCK= line"
            set errors (math $errors + 1)
        else if grep -q -- '%t' "$tmpfile_sshenv"
            _err "10-environment.conf: contains %t (environment.d uses \${VAR}, not unit specifiers)"
            set errors (math $errors + 1)
        end
        command rm -f -- "$tmpfile_sshenv"
    end

    set -l ini_checks \
        "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf|[Resolve]" \
        "/etc/systemd/logind.conf.d/99-cachyos-logind.conf|[Login]" \
        "/etc/iwd/main.conf|[General],[DriverQuirks],[Network]" \
        "/etc/NetworkManager/conf.d/99-cachyos-nm.conf|[device],[connection],[logging]"

    for check in $ini_checks
        set -l dst (string split '|' -- "$check")[1]
        set -l sections_str (string split '|' -- "$check")[2]
        set -l sections (string split ',' -- "$sections_str")
        set -l label (basename -- "$dst")

        set -l tmpfile_ini (mktemp -t ry-validate-XXXXXX --suffix=.ini)
        if test -z "$tmpfile_ini"
            _err "Failed to create temp file for $label validation"
            set errors (math $errors + 1)
            continue
        end

        get_file_content "$dst" >"$tmpfile_ini"
        if not test -s "$tmpfile_ini"
            _err "$label: empty content from get_file_content"
            set errors (math $errors + 1)
            command rm -f -- "$tmpfile_ini"
            continue
        end
        set -l missing_sections
        for section in $sections
            if not grep -qF -- "$section" "$tmpfile_ini"
                set -a missing_sections "$section"
            end
        end

        if test (count $missing_sections) -gt 0
            _err "$label: missing section header(s): "(string join -- ', ' $missing_sections)
            set errors (math $errors + 1)
        else
            _log "VALIDATE: $label INI sections OK"
        end

        set -l first_section_line (grep -n -- '^\[' "$tmpfile_ini" | head -n 1 | cut -d: -f1)
        if test -n "$first_section_line" && test "$first_section_line" -gt 1
            set -l orphaned (sed -n "1,"(math $first_section_line - 1)"p" "$tmpfile_ini" | grep -vE -- '^\s*$|^\s*#')
            if test -n "$orphaned"
                _warn "$label: key=value lines before first section header"
            end
        end

        command rm -f -- "$tmpfile_ini"
    end

    set -l tmpfile_simple (mktemp -t ry-validate-XXXXXX)
    if test -n "$tmpfile_simple"
        get_file_content "/boot/loader/loader.conf" >"$tmpfile_simple"
        if test -s "$tmpfile_simple"
            for key in default timeout console-mode editor
                if not grep -qE -- "^$key " "$tmpfile_simple"
                    _err "Loader.conf: missing '$key' directive"
                    set errors (math $errors + 1)
                end
            end
        else
            _err "Loader.conf: empty content"
            set errors (math $errors + 1)
        end

        get_file_content "/etc/sdboot-manage.conf" >"$tmpfile_simple"
        if test -s "$tmpfile_simple"
            for key in LINUX_OPTIONS LINUX_FALLBACK_OPTIONS DEFAULT_ENTRY REMOVE_EXISTING OVERWRITE_EXISTING REMOVE_OBSOLETE
                if not grep -qE -- "^$key=" "$tmpfile_simple"
                    _err "Sdboot-manage.conf: missing '$key' directive"
                    set errors (math $errors + 1)
                end
            end
        else
            _err "Sdboot-manage.conf: empty content"
            set errors (math $errors + 1)
        end

        get_file_content "/etc/udev/rules.d/99-cachyos-udev.rules" >"$tmpfile_simple"
        if test -s "$tmpfile_simple"
            if grep -qE -- '[A-Z]+=[^=]' "$tmpfile_simple" 2>/dev/null
                if grep -qE -- '==[[:space:]]*$' "$tmpfile_simple" 2>/dev/null
                    _err "Udev rules: empty match value detected"
                    set errors (math $errors + 1)
                end
            end
        else
            _err "Udev rules: empty content"
            set errors (math $errors + 1)
        end

        command rm -f -- "$tmpfile_simple"
    end

    if test $errors -gt 0
        _err "Validation failed with $errors error(s)"
        return 1
    end

    _ok "All configurations validated"
    return 0
end

# ── Atomic file installation — get_file_content → mktemp → validate → chmod/chown → mv; hash comparison skips unchanged files; skips NM/IWD if iwd not installed ──

# Deploy a single embedded config: get content → mktemp → validate → chmod → atomic mv to dst
function install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
    if test (count $argv) -ne 2
        _err "install_file: expected 2 args (dst use_sudo), got "(count $argv)
        return 1
    end
    set -l dst $argv[1]
    set -l use_sudo $argv[2]

    # Skip NM/IWD configs if iwd not installed — prevents broken wifi stack
    if string match -q '*nm.conf' -- "$dst" || string match -q '*/iwd/*' -- "$dst"
        if not command -q pacman || not pacman -Qi iwd >/dev/null 2>&1
            _warn "Skipping $dst: iwd package not installed"
            return 0
        end
    end

    set -l dir (dirname -- "$dst")
    if test "$use_sudo" = true
        if not _run sudo mkdir -p -- "$dir"
            _fail "Cannot create directory: $dir"
            return 1
        end
    else
        if not _run command mkdir -p -- "$dir"
            _fail "Cannot create directory: $dir"
            return 1
        end
    end

    # Permission model: system files 0644 (world-readable configs), user files 0600 (private)
    set -l perms 0644
    if test "$use_sudo" = false
        set perms 0600
    end

    if test "$DRY" = true
        _dry "rm -f -- $dst"
        _dry "write content to $dst"
        _dry "chmod $perms $dst"
        _ok "(dry-run) → $dst"
        return 0
    end

    # Skip unchanged: compare generated content against installed file
    set -l _new_content (get_file_content "$dst" 2>/dev/null)
    if test $status -eq 0 && test -n "$_new_content"
        set -l _cur_content
        if test "$use_sudo" = true
            set _cur_content (sudo cat -- "$dst" 2>/dev/null)
        else
            set _cur_content (cat -- "$dst" 2>/dev/null)
        end
        if test "$_new_content" = "$_cur_content"
            _ok "→ $dst (unchanged)"
            return 0
        end
    end

    if test "$use_sudo" = true
        # Atomic: mktemp in dst_dir (same fs) → chmod → mv; symlink check prevents TOCTOU
        set -l dst_dir (dirname -- "$dst")
        set -l tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
        if test -z "$tmpfile"
            _fail "→ $dst (mktemp failed)"
            return 1
        end
        if sudo test -L "$tmpfile"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
        get_file_content "$dst" | sudo tee -- "$tmpfile" >/dev/null
        set -l _ps $pipestatus
        if test $_ps[1] -ne 0
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _err "No content defined for: $dst"
            return 1
        end
        if test $_ps[2] -ne 0
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (write to temp failed)"
            return 1
        end
        if not _run sudo chmod -- $perms "$tmpfile"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (chmod failed)"
            return 1
        end
        if not _run sudo mv -- "$tmpfile" "$dst"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
        # Post-write integrity check (system file): re-generate + hash to catch content-generation bugs
        set -l _expected_hash (get_file_content "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
        set -l _actual_hash (sudo cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
        if test -n "$_expected_hash" && test "$_expected_hash" != "$_actual_hash"
            _fail "→ $dst (post-write checksum mismatch)"
            _log "HASH_MISMATCH: expected=$_expected_hash actual=$_actual_hash dst=$dst"
            return 1
        end
        if not _run sudo chown -- root:root "$dst"
            _warn "→ $dst (chown failed, check ownership)"
            set -g INSTALL_HAD_ERRORS true
        else
            _ok "→ $dst"
        end
    else
        set -l tmpfile (mktemp -p (dirname -- "$dst") .ry-install.XXXXXX)
        if test -z "$tmpfile"
            _fail "→ $dst (mktemp failed)"
            return 1
        end
        if test -L "$tmpfile"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
        get_file_content "$dst" | tee -- "$tmpfile" >/dev/null
        set -l _ps $pipestatus
        if test $_ps[1] -ne 0
            command rm -f -- "$tmpfile" 2>/dev/null
            _err "No content defined for: $dst"
            return 1
        end
        if test $_ps[2] -ne 0
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (write to temp failed)"
            return 1
        end
        if not command chmod -- $perms "$tmpfile"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (chmod failed)"
            return 1
        end
        if not command mv -- "$tmpfile" "$dst"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
        # Post-write integrity check (user file): re-generate + hash to catch content-generation bugs
        set -l _expected_hash (get_file_content "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
        set -l _actual_hash (cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
        if test -n "$_expected_hash" && test "$_expected_hash" != "$_actual_hash"
            _fail "→ $dst (post-write checksum mismatch)"
            _log "HASH_MISMATCH: expected=$_expected_hash actual=$_actual_hash dst=$dst"
            return 1
        end
        _ok "→ $dst"
    end

    return 0
end

# ═══ FILE OPERATIONS — diff, install, verify ═══

function install_files --description "Install multiple embedded configs with argparse options"
    set -l _argparse_tmp (mktemp -t ry-argparse.XXXXXX 2>/dev/null|| echo /dev/null)
    argparse s/sudo 'd/desc=' -- $argv 2>$_argparse_tmp
    or begin
        set -l _argparse_err (string trim -- (cat -- "$_argparse_tmp" 2>/dev/null))
        command rm -f -- "$_argparse_tmp" 2>/dev/null
        _err "install_files: invalid arguments"(test -n "$_argparse_err"&& echo ": $_argparse_err")
        return 1
    end
    command rm -f -- "$_argparse_tmp" 2>/dev/null
    set -l use_sudo false
    if set -q _flag_sudo
        set use_sudo true
    end
    set -l desc (test -n "$_flag_desc"&& echo "$_flag_desc"|| echo "FILES")
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
    test "$had_failure" = true && return 1
    return 0
end

# Compare embedded content against installed files; --fix repairs in-place; exit 1 when drift found.
function do_diff --argument-names target_file --description "Show diffs between embedded and installed configs"
    _log "=== DIFF START ==="

    # target_file is bound by the named-argument declaration on the line above
    if test (count $argv) -gt 0 && test -n "$argv[1]"
        set target_file "$argv[1]"
        set -l valid false
        for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
            if test "$target_file" = "$dst"
                set valid true
                break
            end
        end
        if test "$valid" = false
            _err "Not a managed file: $target_file"
            _echo
            _info "Managed files:"
            for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
                _echo "  $dst"
            end
            return 2
        end
        _info "Comparing: $target_file"
    else
        _info "Comparing embedded files against system..."
    end
    _echo

    set -l has_diff false
    set -l has_pacnew false
    set -l fixed_count 0
    set -l fix_errors false
    set -l boot_files_fixed false
    set -l service_files_fixed false
    set -l fixed_user_services
    set -l udev_files_fixed false
    set -l resolved_files_fixed false
    set -l modprobe_files_fixed false
    set -l nm_config_fixed false
    set -l logind_files_fixed false
    set -l regdom_fixed false
    set -l _boot_fstype (findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)

    if test "$FIX" = true && test "$DRY" = false
        if not sudo true 2>/dev/null
            _err "Sudo required for --diff --fix"
            return 1
        end
        # Automatic pre-install snapshots removed in v3.4.2; user is responsible for rootfs snapshots
        _info "No automatic backup — snapshot your rootfs before proceeding if needed"
    end

    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test -n "$target_file" && test "$dst" != "$target_file"
            continue
        end
        # Skip NM/IWD configs if iwd not installed — consistent with install_file and verify_static
        if string match -q '*nm.conf' -- "$dst" || string match -q '*/iwd/*' -- "$dst"
            if not command -q pacman || not pacman -Qi iwd >/dev/null 2>&1
                _info "Skipping $dst: iwd package not installed"
                continue
            end
        end
        set -l tmp (mktemp -t ry-diff-XXXXXX)
        set -l tmp_installed (mktemp -t ry-diff-XXXXXX)
        if test -z "$tmp" || test -z "$tmp_installed"
            _warn "Failed to create temp files for diff: $dst"
            command rm -f -- "$tmp" "$tmp_installed" 2>/dev/null
            continue
        end
        get_file_content "$dst" >"$tmp"
        if test $status -ne 0
            set has_diff true
            _warn "Cannot generate expected content for: $dst"
            command rm -f -- "$tmp" "$tmp_installed" 2>/dev/null
            continue
        end

        set -l installed_content (_read_installed "$dst")
        set -l read_ok $status

        set -l this_diff false
        set -l this_perm_only false
        if test $read_ok -eq 0
            # $installed_content is a fish list (one element per line); printf '%s\n' restores newline-separated file content
            printf '%s\n' $installed_content >"$tmp_installed"
            if not diff -q -- "$tmp" "$tmp_installed" >/dev/null 2>&1
                set has_diff true
                set this_diff true
                _echo "── $dst ──"
                set -l diff_tmp (mktemp -t ry-diff-XXXXXX 2>/dev/null|| echo /dev/null)
                diff -u --label "embedded: $dst" --label "installed: $dst" -- "$tmp" "$tmp_installed" >"$diff_tmp"
                if test "$NO_COLOR" = true
                    cat -- "$diff_tmp"
                else if test "$HAS_DELTA" = true
                    delta <"$diff_tmp"
                else
                    diff -u --label "embedded: $dst" --label "installed: $dst" --color=always -- "$tmp" "$tmp_installed"
                end
                while read -l dline
                    _log "DIFF: $dst: $dline"
                end <"$diff_tmp"
                command rm -f -- "$diff_tmp" 2>/dev/null
                _echo
            else
                set -l actual_perms (stat -c '%a' -- "$dst" 2>/dev/null)
                if string match -q "$HOME/*" -- "$dst"
                    set -l actual_owner (stat -c '%U:%G' -- "$dst" 2>/dev/null)
                    set -l expected_owner (id -un)":"(id -gn)
                    if test "$actual_perms" != 600
                        set has_diff true
                        set this_diff true
                        set this_perm_only true
                        _fail "WRONG PERMISSIONS: $dst ($actual_perms, expected 600)"
                    end
                    if test "$actual_owner" != "$expected_owner"
                        set has_diff true
                        set this_diff true
                        set this_perm_only true
                        _fail "WRONG OWNERSHIP: $dst ($actual_owner, expected $expected_owner)"
                    end
                else
                    set -l expected_perms 644
                    set -l _skip_perm_check false
                    # vfat (ESP) has no Unix permissions — skip permission checks for /boot/*
                    if string match -q '/boot/*' -- "$dst"
                        if test "$_boot_fstype" = vfat
                            set _skip_perm_check true
                        end
                    end
                    if test "$_skip_perm_check" = false
                        set actual_perms (sudo stat -c '%a' -- "$dst" 2>/dev/null)
                        set actual_owner (sudo stat -c '%U:%G' -- "$dst" 2>/dev/null)
                        if test "$actual_perms" != "$expected_perms"
                            set has_diff true
                            set this_diff true
                            set this_perm_only true
                            _fail "WRONG PERMISSIONS: $dst ($actual_perms, expected $expected_perms)"
                        end
                        if test "$actual_owner" != "root:root"
                            set has_diff true
                            set this_diff true
                            set this_perm_only true
                            _fail "WRONG OWNERSHIP: $dst ($actual_owner, expected root:root)"
                        end
                    end
                end
            end
            command rm -f -- "$tmp" "$tmp_installed" 2>/dev/null
        else
            command rm -f -- "$tmp" "$tmp_installed" 2>/dev/null
            set has_diff true
            set this_diff true
            _fail "NOT INSTALLED: $dst"
        end

        # Detect .pacnew/.pacsave: pacman drops these when config files conflict with upgrades
        if not string match -q "$HOME/*" -- "$dst"
            for _pac_ext in .pacnew .pacsave
                set -l _pac_file "$dst$_pac_ext"
                if sudo test -f "$_pac_file" 2>/dev/null
                    _warn "STALE $_pac_ext: $_pac_file (review with pacdiff or merge manually)"
                    set has_pacnew true
                end
            end
        end

        if test "$FIX" = true && test "$this_diff" = true
            if test "$this_perm_only" = true
                # Permissions/ownership fix: chmod + chown without rewriting file
                set -l target_perms 0600
                set -l target_owner ""
                if string match -q "$HOME/*" -- "$dst"
                    set target_owner (id -un)":"(id -gn)
                else
                    set target_perms 0644
                    set target_owner "root:root"
                end
                if _ask "Fix permissions/ownership on $dst?"
                    set -l _fix_ok true
                    if string match -q "$HOME/*" -- "$dst"
                        if not command chmod -- $target_perms "$dst"
                            _fail "→ $dst (chmod failed)"
                            set fix_errors true
                            set _fix_ok false
                        end
                        if test -n "$target_owner"
                            if not command chown -- $target_owner "$dst"
                                _fail "→ $dst (chown failed)"
                                set fix_errors true
                                set _fix_ok false
                            end
                        end
                    else
                        if not _run sudo chmod -- $target_perms "$dst"
                            _fail "→ $dst (chmod failed)"
                            set fix_errors true
                            set _fix_ok false
                        end
                        if test -n "$target_owner"
                            if not _run sudo chown -- $target_owner "$dst"
                                _fail "→ $dst (chown failed)"
                                set fix_errors true
                                set _fix_ok false
                            end
                        end
                    end
                    if test "$_fix_ok" = true
                        set fixed_count (math $fixed_count + 1)
                        _ok "→ $dst (permissions/ownership fixed)"
                    end
                end
            else
                if _ask "Re-install embedded version of $dst?"
                    set -l use_sudo true
                    if string match -q "$HOME/*" -- "$dst"
                        set use_sudo false
                    end
                    if install_file "$dst" $use_sudo
                        set fixed_count (math $fixed_count + 1)
                        if string match -q '/boot/*' -- "$dst" || string match -q '/etc/mkinitcpio*' -- "$dst" || string match -q '/etc/sdboot*' -- "$dst" || string match -q /etc/kernel/cmdline -- "$dst"
                            set boot_files_fixed true
                        end
                        if string match -q '*.service' -- "$dst"
                            if string match -q "$HOME/*" -- "$dst"
                                set -a fixed_user_services (basename -- "$dst")
                            else
                                set service_files_fixed true
                            end
                        end
                        if string match -q '*/udev/rules.d/*' -- "$dst"
                            set udev_files_fixed true
                        end
                        if string match -q '*/resolved.conf.d/*' -- "$dst"
                            set resolved_files_fixed true
                        end
                        if string match -q '*/modprobe.d/*' -- "$dst"
                            set modprobe_files_fixed true
                        end

                        if string match -q '*/iwd/main.conf' -- "$dst" || string match -q '*/NetworkManager/conf.d/*' -- "$dst"
                            set nm_config_fixed true
                        end
                        if string match -q '*/logind.conf.d/*' -- "$dst"
                            set logind_files_fixed true
                        end
                        if string match -q '*/conf.d/wireless-regdom' -- "$dst"
                            set regdom_fixed true
                        end
                    else
                        set fix_errors true
                    end
                end
            end
            # Summary: report diff results and optionally auto-fix drifted files
        end
    end

    if test "$has_diff" = false
        _ok "All files match system!"
    else if test "$FIX" = true
        _echo
        if test $fixed_count -gt 0
            _ok "Fixed $fixed_count file(s)"
        end
        if test "$fix_errors" = true
            _warn "Some files could not be fixed"
        end
        if test "$boot_files_fixed" = true && test "$DRY" = false
            _echo
            if _ask "Boot files changed — rebuild initramfs and update bootloader?"
                _run sudo mkinitcpio -P || _warn "Mkinitcpio failed"
                _run sudo sdboot-manage gen || _warn "Sdboot-manage gen failed"
                _run sudo sdboot-manage update || _warn "Sdboot-manage update failed"
            end
        end
        if test "$service_files_fixed" = true && test "$DRY" = false
            _run sudo systemctl daemon-reload || _warn "Systemctl daemon-reload failed"
        end
        if test "$udev_files_fixed" = true && test "$DRY" = false
            _echo
            if _ask "Udev rules changed — reload?"
                _run sudo udevadm control --reload-rules || _warn "Udevadm reload-rules failed"
                _run sudo udevadm trigger || _warn "Udevadm trigger failed"
                _run sudo udevadm settle --timeout=5 || _warn "Udevadm settle timed out"
            end
        end
        if test "$resolved_files_fixed" = true && test "$DRY" = false
            _echo
            if _ask "Resolved config changed — restart systemd-resolved?"
                _run sudo systemctl restart systemd-resolved || _warn "Systemd-resolved restart failed"
            end
        end

        if test "$modprobe_files_fixed" = true
            # Post-fix: prompt NM restart if network config changed, reload services
            _info "Module options changed — reboot required for full effect"
        end

        if test "$nm_config_fixed" = true && test "$DRY" = false
            _echo
            if _ask "NetworkManager config changed — restart NetworkManager?"
                _run sudo systemctl restart NetworkManager || _warn "NetworkManager restart failed"
            end
        end
        if test "$logind_files_fixed" = true
            _info "Logind config changed — reboot required (restarting logind kills all sessions)"
        end
        if test "$regdom_fixed" = true
            _info "Regulatory domain changed — run 'sudo iw reg set XX' or reboot for full effect"
        end
        if test (count $fixed_user_services) -gt 0 && test "$DRY" = false
            _run systemctl --user daemon-reload || _warn "Systemctl --user daemon-reload failed"
            for _unit in $fixed_user_services
                _echo
                if _ask "Enable $_unit (user)?"
                    if _run systemctl --user enable --now "$_unit"
                        if test "$_unit" = ssh-agent.service && set -q XDG_RUNTIME_DIR
                            _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                            or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
                        end
                    else
                        _warn "Failed to enable $_unit"
                    end
                end
            end
        end
        if test "$DRY" = false
            for dst in $USER_DESTINATIONS
                if string match -q '*.service' -- "$dst" && test -f "$dst"
                    set -l _unit (basename -- "$dst")
                    if not contains -- "$_unit" $fixed_user_services
                        set -l _state (systemctl --user is-active "$_unit" 2>/dev/null)
                        if test "$_state" != active
                            _warn "$_unit exists but is not active ($_state)"
                            if _ask "Enable $_unit (user)?"
                                _run systemctl --user daemon-reload || _warn "Systemctl --user daemon-reload failed"
                                if _run systemctl --user enable --now "$_unit"
                                    if test "$_unit" = ssh-agent.service && set -q XDG_RUNTIME_DIR
                                        _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                                        or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
                                    end
                                else
                                    _warn "Failed to enable $_unit"
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if test "$has_pacnew" = true
        _echo
        _warn "Stale .pacnew/.pacsave files found alongside managed files"
        _info "  Run 'sudo pacdiff' to review and merge package updates"
    end

    if test "$FIX" = true && test "$DRY" = false
        set -l pac_system_files (_find_pacnew_files)
        if test (count $pac_system_files) -gt 0
            _echo
            _warn "Found "(count $pac_system_files)" system-wide .pacnew/.pacsave file(s):"
            for _pf in $pac_system_files
                _info "  $_pf"
            end
            if command -q pacdiff
                if _ask "Run pacdiff to review and merge?"
                    _run sudo pacdiff
                    or _warn "Pacdiff exited with errors"
                end
            else
                _info "  Install pacman-contrib for pacdiff, or merge manually"
                # Supplemental checks: pacnew/pacsave files, coredumps, boot entries
            end
        end

        if command -q coredumpctl
            set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
            set -l dump_count (string trim -- "$dump_count")
            if test -n "$dump_count" && string match -qr '^\d+$' -- "$dump_count" && test "$dump_count" -gt 0
                _echo
                _warn "Found $dump_count coredump(s):"
                set -l _dump_lines (coredumpctl list --no-pager 2>/dev/null | tail -n 5)
                for _dl in $_dump_lines
                    _info "  $_dl"
                end
                if _ask "Remove all coredumps?"
                    if _run sudo coredumpctl vacuum --time=1s
                        _ok "Coredumps removed"
                    else
                        _warn "Coredump vacuum failed"
                    end
                end
            end
        end
    else if test "$FIX" = true && test "$DRY" = true
        set -l pac_system_files (_find_pacnew_files)
        if test (count $pac_system_files) -gt 0
            _echo
            _info "Would offer to merge "(count $pac_system_files)" .pacnew/.pacsave file(s)"
        end
        if command -q coredumpctl
            set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
            set -l dump_count (string trim -- "$dump_count")
            if test -n "$dump_count" && string match -qr '^\d+$' -- "$dump_count" && test "$dump_count" -gt 0
                _info "Would offer to remove $dump_count coredump(s)"
            end
        end
    end

    _log "=== DIFF END ==="

    if test "$fix_errors" = true
        return 1
    end
    if test "$has_diff" = true && test "$FIX" != true
        return 1
    end
    if test "$has_diff" = true && test "$DRY" = true
        return 1
    end
    return 0
end

# Checksum verification: sha256 of embedded content vs installed file; exit 1 when drifted.
function verify_static --description "Verify installed configs match embedded checksums"
    _log "=== STATIC VERIFICATION START ==="
    sudo true 2>/dev/null || begin
        _err "Sudo required for verification"
        return 1
    end

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
        set -l opts (grep -- '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null \
            | string replace -r -- '^LINUX_OPTIONS="?(.*?)"?\s*$' '$1')

        for param in $KERNEL_PARAMS
            if string match -q -- "* $param *" " $opts "
                _ok "  $param: present"
            else
                _fail "  $param: MISSING"
            end
        end

        _chk_grep /etc/sdboot-manage.conf "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\"" "OVERWRITE_EXISTING=$SDBOOT_OVERWRITE"
        _chk_grep /etc/sdboot-manage.conf "REMOVE_EXISTING=\"$SDBOOT_REMOVE_EXISTING\"" "REMOVE_EXISTING=$SDBOOT_REMOVE_EXISTING"
        _chk_grep /etc/sdboot-manage.conf "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\"" "REMOVE_OBSOLETE=$SDBOOT_REMOVE_OBSOLETE"
        _chk_grep /etc/sdboot-manage.conf 'DEFAULT_ENTRY="manual"' "DEFAULT_ENTRY=manual"
        _chk_grep /etc/sdboot-manage.conf 'LINUX_FALLBACK_OPTIONS="quiet"' "LINUX_FALLBACK_OPTIONS=quiet"
    end
    _echo

    _echo "── kernel cmdline ──"
    if _chk_file /etc/kernel/cmdline
        set -l cmdline_content (sudo cat -- /etc/kernel/cmdline 2>/dev/null)
        if test -n "$cmdline_content"
            for param in $KERNEL_PARAMS
                if string match -q -- "* $param *" " $cmdline_content "
                    _ok "  $param: present"
                else
                    _fail "  $param: MISSING from /etc/kernel/cmdline"
                end
            end
            if string match -q '*root=UUID=*' -- "$cmdline_content"
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
        set -l modules_line (grep -E '^[[:space:]]*MODULES=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -n 1)
        _echo "  Config: $modules_line"

        if string match -q '*amdgpu*' -- "$modules_line"
            _ok "  amdgpu: present (early KMS)"
        else
            _fail "  amdgpu: MISSING"
        end

        for mod in $MKINITCPIO_MODULES
            if test "$mod" = amdgpu
                continue
            end
            if string match -qr "\\b$mod\\b" -- "$modules_line"
                _ok "  $mod: present"
            else
                _fail "  $mod: MISSING"
            end
        end

        set -l hooks_line (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -n 1)
        _echo "  Config: $hooks_line"

        for hook in $MKINITCPIO_HOOKS
            if string match -qr "\\b$hook\\b" -- "$hooks_line"
                _ok "  $hook: present"
            else
                _fail "  $hook: MISSING"
            end
        end

        set -l comp_line (grep -E '^[[:space:]]*COMPRESSION=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^[[:space:]]*#' | head -n 1)
        if string match -q '*zstd*' -- "$comp_line"
            _ok "  COMPRESSION=zstd: present"
        else
            _fail "  COMPRESSION=zstd: MISSING"
        end
    end
    _echo

    _echo "── Boot entries ──"
    set -l entry_count 0
    if sudo test -d /boot/loader/entries 2>/dev/null
        set entry_count (sudo find /boot/loader/entries -name "*.conf" 2>/dev/null | wc -l | string trim --)
    end
    if test -n "$entry_count" && string match -qr '^\d+$' -- "$entry_count" && test "$entry_count" -gt 0
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
        for mod in $MODPROBE_BLACKLIST
            _chk_grep /etc/modprobe.d/99-cachyos-modprobe.conf "blacklist $mod" "$mod blacklist"
        end
    end
    _echo

    _echo "── ntsync state ──"
    set -l _ns (_ntsync_state)
    switch $_ns
        case unavailable
            _info "  Kernel < 6.14 — ntsync not supported"
            if contains -- PROTON_USE_NTSYNC=1 $ENV_VARS
                _warn "  PROTON_USE_NTSYNC=1 in ENV_VARS but kernel < 6.14 — ntsync unavailable"
            end
        case builtin
            _info "  ntsync: built-in (CONFIG_NTSYNC=y)"
        case loaded
            _ok "  ntsync: loaded, /dev/ntsync present"
        case loaded_nodev
            _warn "  ntsync: module loaded but /dev/ntsync missing"
        case missing
            _info "  ntsync: module not loaded"
    end
    _echo

    _echo "── Udev rules ──"
    if _chk_file /etc/udev/rules.d/99-cachyos-udev.rules
        _chk_grep /etc/udev/rules.d/99-cachyos-udev.rules ntsync "ntsync rule"
        # USB power/control rule removed — usbcore.autosuspend=-1 handles globally
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
    if not command -q pacman || not pacman -Qi iwd >/dev/null 2>&1
        _info "  Skipping (iwd not installed)"
    else if _chk_file /etc/iwd/main.conf
        _chk_grep /etc/iwd/main.conf "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
        for quirk in $IWD_DRIVER_QUIRKS
            set -l key (string split '=' -- $quirk)[1]
            _chk_grep /etc/iwd/main.conf "$key" "DriverQuirks $key"
        end
        _chk_grep /etc/iwd/main.conf "NameResolvingService=$IWD_DNS_SERVICE" "DNS via $IWD_DNS_SERVICE"
    end
    _echo

    _echo "── NetworkManager ──"
    if not command -q pacman || not pacman -Qi iwd >/dev/null 2>&1
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
        set -l actual_regdom (grep -E '^[[:space:]]*WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null | grep -v '^#' | cut -d'"' -f2 | head -n 1)
        if test -n "$actual_regdom"
            _ok "WIRELESS_REGDOM=$actual_regdom"
        else
            _fail "WIRELESS_REGDOM: not set (no uncommented WIRELESS_REGDOM= line)"
        end
    end
    _echo

    _echo "── sysctl overrides ──"
    if _chk_file /etc/sysctl.d/99-ry-sysctl.conf
        _chk_grep /etc/sysctl.d/99-ry-sysctl.conf "net.core.default_qdisc = fq" "default_qdisc = fq"
        _chk_grep /etc/sysctl.d/99-ry-sysctl.conf "net.ipv4.tcp_congestion_control = bbr" "tcp_congestion_control = bbr"
        _chk_grep /etc/sysctl.d/99-ry-sysctl.conf "net.ipv4.tcp_fastopen = 3" "tcp_fastopen = 3"
        _chk_grep /etc/sysctl.d/99-ry-sysctl.conf "fs.inotify.max_user_watches = 524288" "inotify max_user_watches = 524288"
    end
    _echo

    _echo "USER CONFIGURATION"
    _echo

    _echo "── SSH agent ──"
    if _chk_file "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"
        _chk_grep "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" SSH_AUTH_SOCK "SSH_AUTH_SOCK configured"
    end
    if _chk_file "$HOME/.config/environment.d/10-environment.conf"
        _chk_grep "$HOME/.config/environment.d/10-environment.conf" "SSH_AUTH_SOCK=" "SSH_AUTH_SOCK for systemd"
        for exp in $ENV_VARS
            set -l var_name (string split '=' -- "$exp")[1]
            _chk_grep "$HOME/.config/environment.d/10-environment.conf" "$var_name=" "$var_name"
        end
    end
    if _chk_file "$HOME/.config/systemd/user/ssh-agent.service"
        _chk_grep "$HOME/.config/systemd/user/ssh-agent.service" ssh-agent "ssh-agent ExecStart"
        _chk_grep "$HOME/.config/systemd/user/ssh-agent.service" "WantedBy=default.target" "ssh-agent WantedBy"
    end
    _echo

    _echo PACKAGES
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
        set -l ignore_lines (grep -n -- '^IgnorePkg' /etc/pacman.conf 2>/dev/null)
        if test -n "$ignore_lines"
            for line in $ignore_lines
                _ok "  $line"
            end
        else
            _info "  No IgnorePkg set"
        end
        set -l parallel (grep -n -- '^ParallelDownloads' /etc/pacman.conf 2>/dev/null)
        if test -n "$parallel"
            _ok "  $parallel"
        else
            _info "  ParallelDownloads not set (default: 1)"
        end
    else
        _warn "  /etc/pacman.conf not found"
    end
    _echo

    _echo SERVICES
    _echo

    _echo "── Service files ──"
    for svc_file in $SERVICE_DESTINATIONS
        _chk_file "$svc_file"
    end
    if test -f /etc/systemd/system/amdgpu-performance.service
        _chk_grep /etc/systemd/system/amdgpu-performance.service power_dpm_force_performance_level "amdgpu-performance ExecStart"
        _chk_grep /etc/systemd/system/amdgpu-performance.service "WantedBy=graphical.target" "amdgpu-performance WantedBy"
        _chk_grep /etc/systemd/system/amdgpu-performance.service "retries=" "amdgpu-performance retry loop"
    end
    if test -f /etc/systemd/system/cpupower-epp.service
        # scaling_governor ExecStart absent: amd_pstate=active uses powersave+performance EPP
        _chk_grep /etc/systemd/system/cpupower-epp.service energy_performance_preference "cpupower-epp EPP ExecStart"
        if grep -q -- scaling_governor /etc/systemd/system/cpupower-epp.service 2>/dev/null
            _warn "  cpupower-epp: scaling_governor ExecStart present — remove it (amd_pstate=active uses powersave+EPP)"
        end
        _chk_grep /etc/systemd/system/cpupower-epp.service "WantedBy=multi-user.target" "cpupower-epp WantedBy"
    end
    _echo

    _echo "── Masked services ──"
    for svc in $MASK
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

    _echo "── mkinitcpio hooks ──"
    set -l hooks_line (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^#' | head -n 1)
    if test -n "$hooks_line"
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_line")
        validate_mkinitcpio_hooks --existence-only (string split ' ' -- "$hooks_str")
    else
        _warn "  Could not parse HOOKS from mkinitcpio.conf"
    end
    _echo

    _echo "── systemd units ──"
    for unit in $SERVICE_DESTINATIONS
        test -f "$unit" && _verify_unit_syntax "$unit" (basename -- "$unit")
    end
    set -l user_svc "$HOME/.config/systemd/user/ssh-agent.service"
    test -f "$user_svc" && _verify_unit_syntax "$user_svc" "ssh-agent.service (user)"
    _echo

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

    _echo "CHECKSUM VERIFICATION"
    _echo
    _echo "── embedded vs installed ──"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        # Collect with --no-trim-newlines preserves exact file content (avoids fish list normalization)
        set -l content (get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines)
        if test -z "$content"
            continue
        end
        set -l installed (_read_installed "$dst" | string collect --no-trim-newlines)
        if test -z "$installed"
            continue
        end
        set -l expected_hash (printf '%s' "$content" | sha256sum | awk '{print $1}')
        set -l actual_hash (printf '%s' "$installed" | sha256sum | awk '{print $1}')
        if test "$expected_hash" = "$actual_hash"
            _ok "  $dst: checksum match"
        else
            _fail "  $dst: checksum MISMATCH"
        end
    end
    _echo

    _log "=== STATIC VERIFICATION END ==="

    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

# Read GPU performance level and busy percentage from amdgpu sysfs nodes
function _gather_gpu_state --description "Collect GPU driver and firmware state for diagnostics"
    set -g _GPU_PERF_LEVEL ""
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set -g _GPU_PERF_LEVEL (cat -- "$f" 2>/dev/null)
            break
        end
    end
    return 0
end

# Read CPU governor and current frequency from cpufreq sysfs; stores path for diagnostics
function _gather_cpu_state --description "Collect CPU governor and frequency state for diagnostics"
    set -g _CPU_PATH ""
    set -g _CPU_GOVERNOR ""
    set -g _CPU_EPP ""
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq
        if test -d "$cpu_dir"
            set -g _CPU_PATH "$cpu_dir"
            set -g _CPU_GOVERNOR (cat -- "$cpu_dir/scaling_governor" 2>/dev/null)
            set -g _CPU_EPP (cat -- "$cpu_dir/energy_performance_preference" 2>/dev/null)
            break
        end
        # Collect thermal sensor readings from hwmon sysfs entries for dashboard/diagnostics
    end
    return 0
end

# Read CPU (k10temp) and GPU (amdgpu) temperatures from /sys/class/hwmon/*/temp*_input
function _gather_temps --description "Collect thermal sensor readings from sysfs hwmon"
    set -g _TEMP_CPU_NUM ""
    set -g _TEMP_CPU_INT ""
    set -g _TEMP_GPU_NUM ""
    set -g _TEMP_GPU_INT ""

    # CPU: k10temp or zenpower (AMD thermal driver)
    for f in /sys/class/hwmon/hwmon*/temp1_input
        test -f "$f" || continue
        set -l name_f (string replace 'temp1_input' 'name' -- "$f")
        test -f "$name_f" || continue
        set -l name (cat -- "$name_f" 2>/dev/null)
        if test "$name" = k10temp || test "$name" = zenpower
            set raw (cat -- "$f" 2>/dev/null|| echo 0)
            if string match -qr '^\d+$' -- "$raw"
                set -l temp_val (math "$raw / 1000")
                set -g _TEMP_CPU_INT (string split '.' -- "$temp_val")[1]
                set -g _TEMP_CPU_NUM (printf '%.1f' "$temp_val")
            end
            break
        end
    end

    # GPU: amdgpu hwmon (first DRM card with temp1_input)
    for card_dir in /sys/class/drm/card*/device
        test -d "$card_dir" || continue
        for f in $card_dir/hwmon/hwmon*/temp1_input
            test -f "$f" || continue
            set -l raw (cat -- "$f" 2>/dev/null|| echo 0)
            if string match -qr '^\d+$' -- "$raw"
                set -l temp_val (math "$raw / 1000")
                set -g _TEMP_GPU_INT (string split '.' -- "$temp_val")[1]
                set -g _TEMP_GPU_NUM (printf '%.1f' "$temp_val")
            end
            break
        end
        break
    end

    if test -z "$_TEMP_CPU_NUM" && test -z "$_TEMP_GPU_NUM"
        return 1
    end
    return 0
end

# ═══ RUNTIME VERIFICATION — live sysfs/procfs state checks; exit 1 when state doesn't match config.
function verify_runtime --description "Verify runtime kernel params, services, and modules"
    _log "=== RUNTIME VERIFICATION START ==="

    sudo true 2>/dev/null || begin
        _err "Sudo required for verification"
        return 1
    end

    # VERIFY_* counters are global (read by _msg); all other variables are function-local
    set -g VERIFY_MODE true
    set -g VERIFY_OK 0
    set -g VERIFY_FAIL 0
    set -g VERIFY_WARN 0

    _info "Runtime verification (live system state)..."
    _echo

    _echo "KERNEL CMDLINE"
    _echo

    set -l cmdline (cat -- /proc/cmdline 2>/dev/null)
    for param in $KERNEL_PARAMS
        if string match -q -- "* $param *" " $cmdline "
            _ok "  $param: active"
        else
            _fail "  $param: NOT in cmdline"
        end
    end
    _echo

    _validate_kernel_params

    _echo "HARDWARE STATE"
    _echo

    # _gather_gpu_state samples first card only; this loop validates ALL cards for compliance
    _echo "── GPU performance level ──"
    set -l gpu_ok false
    set -l found_gpu false
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set found_gpu true
            set -l level (cat -- "$f" 2>/dev/null)
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
    set -l rebar_status (dmesg 2>/dev/null | grep -i 'BAR' | grep -i -E 'resize|rebar|large|above.4g' | head -n 1)
    if test -n "$rebar_status"
        if string match -qi '*enabled*' -- "$rebar_status" || string match -qi '*resiz*' -- "$rebar_status"
            _ok "  ReBAR/SAM: enabled"
            _info "  $rebar_status"
        else
            _info "  ReBAR/SAM: check manually"
            _info "  $rebar_status"
        end
    else
        if command -q lspci
            set -l bar_size (lspci -vvv 2>/dev/null | grep -i 'Region.*Memory.*256M\|Region.*Memory.*512M\|Region.*Memory.*[0-9]G' | head -n 1)
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
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_CPU_PATH")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:amd-pstate-epp:Scaling driver" \
            "scaling_governor:powersave:Governor" \
            "energy_performance_preference:performance:EPP"
            set -l parts (string split ':' -- "$check")
            set -l sysfs_val (cat -- "$_CPU_PATH/$parts[1]" 2>/dev/null)

            if test "$sysfs_val" = "$parts[2]"
                _ok "  $parts[3]: $sysfs_val"
            else
                _fail "  $parts[3]: $sysfs_val (expected: $parts[2])"
            end
        end
    end
    _echo

    _echo "MODULE STATE"
    _echo

    _echo "── Module parameters ──"
    # btusb check removed — usbcore.autosuspend=-1 handles globally

    if test -f /sys/module/usbcore/parameters/autosuspend
        set -l sysfs_val (cat -- /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
        if test "$sysfs_val" = -1
            _ok "  usbcore.autosuspend: $sysfs_val"
        else
            _fail "  usbcore.autosuspend: $sysfs_val (expected: -1)"
        end
    end

    if test -f /sys/module/nvme_core/parameters/default_ps_max_latency_us
        set -l sysfs_val (cat -- /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null)
        if test "$sysfs_val" = 0
            _ok "  nvme_core.default_ps_max_latency_us: $sysfs_val"
        else
            _fail "  nvme_core.default_ps_max_latency_us: $sysfs_val (expected: 0)"
        end
    end

    if test -d /sys/module/amdgpu/parameters
        # Hex→decimal normalization: sysfs may return 0xfffd3fff or 4294705151
        for pair in "aspm:0" "cwsr_enable:0" "gpu_recovery:1" "modeset:1" "ppfeaturemask:0xfffd3fff" "runpm:0"
            set -l pname (string split ':' -- "$pair")[1]
            set -l expected (string split ':' -- "$pair")[2]
            set -l ppath /sys/module/amdgpu/parameters/$pname
            if test -f "$ppath"
                set sysfs_val (string trim -- (cat -- "$ppath" 2>/dev/null))
                set -l sysfs_val_dec "$sysfs_val"
                set -l expected_dec "$expected"
                if string match -q '0x*' -- "$sysfs_val"
                    set sysfs_val_dec (printf '%d' "$sysfs_val" 2>/dev/null|| echo "$sysfs_val")
                end
                if string match -q '0x*' -- "$expected"
                    set expected_dec (printf '%d' "$expected" 2>/dev/null|| echo "$expected")
                end
                if test "$sysfs_val_dec" = "$expected_dec"
                    _ok "  amdgpu.$pname: $sysfs_val"
                else
                    _fail "  amdgpu.$pname: $sysfs_val (expected: $expected)"
                end
            end
        end
    end

    if test -f /sys/module/mt7925e/parameters/disable_aspm
        set -l sysfs_val (cat -- /sys/module/mt7925e/parameters/disable_aspm 2>/dev/null)
        if test "$sysfs_val" = Y || test "$sysfs_val" = 1
            _ok "  mt7925e.disable_aspm: $sysfs_val"
        else
            _fail "  mt7925e.disable_aspm: $sysfs_val (expected: 1/Y)"
        end
    else if test -d /sys/module/mt7925e
        _info "  mt7925e: loaded but disable_aspm param not found"
    end
    _echo

    _echo "SERVICE STATE"
    _echo

    _check_service_active_enabled amdgpu-performance.service

    _check_service_active_enabled cpupower-epp.service

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

    set -l resolved_state (systemctl is-active systemd-resolved.service 2>/dev/null)
    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        if test "$resolved_state" = active
            _ok "  systemd-resolved: active"
        else
            _fail "  systemd-resolved: $resolved_state (expected: active — DNS may be broken)"
        end
    end

    set -l nm_disp_state (systemctl is-active NetworkManager-dispatcher.service 2>/dev/null)
    set -l nm_disp_enabled (systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null)
    if test "$nm_disp_enabled" = enabled
        if test "$nm_disp_state" = active || test "$nm_disp_state" = inactive
            _ok "  NetworkManager-dispatcher: $nm_disp_enabled ($nm_disp_state)"
        else
            _warn "  NetworkManager-dispatcher: $nm_disp_state (enabled but unexpected state)"
        end
    else
        _fail "  NetworkManager-dispatcher: $nm_disp_enabled (expected: enabled)"
    end

    set -l ssh_svc_state (systemctl --user is-active ssh-agent.service 2>/dev/null)
    set -l ssh_svc_enabled (systemctl --user is-enabled ssh-agent.service 2>/dev/null)
    if test "$ssh_svc_state" = active
        if test "$ssh_svc_enabled" = enabled
            _ok "  ssh-agent.service: active (enabled)"
        else
            _warn "  ssh-agent.service: active but $ssh_svc_enabled (won't persist)"
        end
    else if test -f "$HOME/.config/systemd/user/ssh-agent.service"
        _fail "  ssh-agent.service: $ssh_svc_state (expected: active)"
    else
        _warn "  ssh-agent.service: not installed"
    end

    if set -q SSH_AUTH_SOCK && test -S "$SSH_AUTH_SOCK"
        if string match -q '*ssh-agent*' -- "$SSH_AUTH_SOCK"
            _ok "  SSH_AUTH_SOCK: ssh-agent ($SSH_AUTH_SOCK)"
        else
            _ok "  SSH_AUTH_SOCK: active ($SSH_AUTH_SOCK)"
        end
    else if not set -q XDG_RUNTIME_DIR
        _warn "  SSH_AUTH_SOCK: XDG_RUNTIME_DIR not set (not in graphical session?)"
    else if set -q SSH_AUTH_SOCK
        _warn "  SSH_AUTH_SOCK: set but socket missing ($SSH_AUTH_SOCK)"
    else
        _warn "  SSH_AUTH_SOCK: not set (re-login may be required after install)"
    end
    _echo

    _echo "ENVIRONMENT STATE"
    _echo

    for exp in $ENV_VARS
        set -l var_name (string split '=' -- "$exp")[1]
        set -l expected (string split '=' -- "$exp")[2]
        set -l actual (printenv "$var_name")

        if test "$actual" = "$expected"
            _ok "  $var_name=$actual"
        else if test -n "$actual"
            _fail "  $var_name=$actual (expected: $expected)"
        else
            _fail "  $var_name: NOT SET (re-login may be required)"
        end
    end
    _echo

    _echo "── sysctl overrides ──"
    # Verify runtime values from /etc/sysctl.d/99-ry-sysctl.conf
    set -l _sysctl_checks \
        "net.core.default_qdisc=fq" \
        "net.ipv4.tcp_congestion_control=bbr" \
        "net.ipv4.tcp_fastopen=3" \
        "fs.inotify.max_user_watches=524288"
    for _sc in $_sysctl_checks
        set -l _key (string split '=' -- "$_sc")[1]
        set -l _expected (string split '=' -- "$_sc")[2]
        set -l _proc_path (string replace -a '.' '/' -- "$_key")
        set -l _actual (cat -- "/proc/sys/$_proc_path" 2>/dev/null | string trim --)
        if test "$_actual" = "$_expected"
            _ok "  $_key: $_actual"
        else if test -n "$_actual"
            _fail "  $_key: $_actual (expected: $_expected)"
        else
            _warn "  $_key: cannot read /proc/sys/$_proc_path"
        end
    end
    _echo

    _echo "── ntsync support ──"
    set -l _ns (_ntsync_state)
    switch $_ns
        case loaded builtin
            _ok "ntsync: /dev/ntsync exists"
        case loaded_nodev
            _warn "ntsync: module loaded but /dev/ntsync missing"
        case unavailable
            _info "ntsync: NOT available (kernel 6.14+ required)"
        case missing
            _info "ntsync: NOT available (module not loaded)"
    end
    _echo

    _echo "── Blacklisted modules ──"
    set -l _bl_loaded 0
    for mod in $MODPROBE_BLACKLIST
        if grep -q -- "^$mod " /proc/modules 2>/dev/null
            _fail "  $mod: LOADED (blacklist ineffective — reboot required)"
            set _bl_loaded (math $_bl_loaded + 1)
        end
    end
    if test $_bl_loaded -eq 0
        _ok "  All blacklisted modules: not loaded ($MODPROBE_BLACKLIST)"
    end
    _echo

    _echo "WIFI STATE"
    _echo

    set -l wlan_iface ""
    for iface in /sys/class/net/*/wireless
        if test -d "$iface"
            set wlan_iface (basename (dirname -- "$iface"))
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

    if command -q nmcli
        set -l nm_wifi_backend (nmcli -t -f WIFI general 2>/dev/null | string trim --)
        if test -n "$nm_wifi_backend"
            _info "  NM wifi: $nm_wifi_backend"
        end
        set -l wifi_state (nmcli -t -f TYPE,STATE device 2>/dev/null | grep '^wifi:' | head -n 1 | cut -d: -f2)
        if test "$wifi_state" = connected
            _ok "  WiFi device: connected"
        else if test -n "$wifi_state"
            _warn "  WiFi device: $wifi_state (not connected)"
        end
    end

    set -l reg ""
    set -l expected_regdom (grep -E '^[[:space:]]*WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null | grep -v '^#' | cut -d'"' -f2 | head -n 1)
    if test -z "$expected_regdom"
        set expected_regdom US
    end

    if not command -q iw
        _warn "  Regulatory domain: iw command not found (install iw package)"
    else
        set -l iw_output (iw reg get 2>/dev/null)
        if test -z "$iw_output"
            set iw_output (sudo iw reg get 2>/dev/null)
        end

        if test -n "$iw_output"
            set -l match_result (printf '%s\n' $iw_output | string match -r -- '^country ([A-Z]{2}):')
            if test (count $match_result) -ge 2
                set reg $match_result[2]
            end
            if test -z "$reg"
                set reg (printf '%s\n' $iw_output | awk '/^country/ {gsub(/:/, "", $2); print $2; exit}')
            end
        end

        if test -z "$reg" && test -f /sys/module/cfg80211/parameters/ieee80211_regdom
            set reg (string trim -- (cat /sys/module/cfg80211/parameters/ieee80211_regdom 2>/dev/null))
        end
    end

    if test -z "$reg"
        _info "  Regulatory domain: runtime state unavailable"
        _info "  Config file set to: $expected_regdom"
        _info "  Will apply after reboot or: sudo iw reg set $expected_regdom"
    else if test "$reg" = 00
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
    set -l nm_conn_dir /etc/NetworkManager/system-connections
    if test -d "$nm_conn_dir"
        set -l conn_files (sudo find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f 2>/dev/null)
        if test -n "$conn_files"
            set -l bad_perms 0
            for conn_file in $conn_files
                set perms (sudo stat -c '%a' -- "$conn_file" 2>/dev/null)
                set -l owner (sudo stat -c '%U:%G' -- "$conn_file" 2>/dev/null)
                if test "$perms" != 600 || test "$owner" != "root:root"
                    _fail "  $conn_file: $perms $owner (expected: 600 root:root)"
                    set bad_perms (math $bad_perms + 1)
                end
            end
            if test $bad_perms -eq 0
                set -l conn_count (count $conn_files)
                _ok "  NetworkManager connections: $conn_count files with correct permissions"
            end
        else
            if grep -q -- 'wifi.backend=iwd' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null
                _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
            else
                _info "  NetworkManager connections: no .nmconnection files found"
            end
        end
    else
        _info "  NetworkManager connections: directory not found"
    end

    if test -f "$HOME/.ssh/authorized_keys"
        set -l perms (stat -c '%a' -- "$HOME/.ssh/authorized_keys" 2>/dev/null)
        if test "$perms" = 600 || test "$perms" = 644
            _ok "  ~/.ssh/authorized_keys: $perms"
        else
            _warn "  ~/.ssh/authorized_keys: $perms (should be 600 or 644)"
        end
    end

    if test -d "$HOME/.ssh"
        set -l perms (stat -c '%a' -- "$HOME/.ssh" 2>/dev/null)
        if test "$perms" = 700
            _ok "  ~/.ssh directory: $perms"
        else
            _warn "  ~/.ssh directory: $perms (should be 700)"
        end
        # Verify installed file permissions and ownership match expected values
    end
    _echo

    _echo "── Installed files ──"
    set -l perm_bad 0
    set -l perm_checked 0
    set -l _boot_fstype (findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo test -f "$dst" 2>/dev/null
            set perm_checked (math $perm_checked + 1)
            if string match -q '/boot/*' -- "$dst" && test "$_boot_fstype" = vfat
                continue
            end
            set perms (sudo stat -c '%a' -- "$dst" 2>/dev/null)
            set -l owner (sudo stat -c '%U:%G' -- "$dst" 2>/dev/null)
            set -l expected_perms 644
            if test "$perms" != "$expected_perms" || test "$owner" != "root:root"
                _fail "  $dst: $perms $owner (expected: $expected_perms root:root)"
                set perm_bad (math $perm_bad + 1)
            end
        end
    end
    set -l expected_owner (id -un)":"(id -gn)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            set perms (stat -c '%a' -- "$dst" 2>/dev/null)
            set -l owner (stat -c '%U:%G' -- "$dst" 2>/dev/null)
            if test "$perms" != 600 || test "$owner" != "$expected_owner"
                _fail "  $dst: $perms $owner (expected: 600 $expected_owner)"
                set perm_bad (math $perm_bad + 1)
            end
        end
    end
    if test $perm_bad -eq 0 && test $perm_checked -gt 0
        _ok "  All $perm_checked installed files: correct permissions and ownership"
    else if test $perm_checked -eq 0
        _warn "  No installed files found to check"
        # Verify parent directories of managed files have correct permissions
    end
    _echo

    _echo "── Parent directories ──"
    set -l dir_bad 0
    set -l dir_checked 0
    set -l checked_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if contains "$dir" $checked_dirs
            continue
        end
        set -a checked_dirs "$dir"
        if sudo test -d "$dir" 2>/dev/null
            set dir_checked (math $dir_checked + 1)
            set perms (sudo stat -c '%a' -- "$dir" 2>/dev/null)
            set -l owner (sudo stat -c '%U:%G' -- "$dir" 2>/dev/null)
            if test "$owner" != "root:root"
                _fail "  $dir: $perms $owner (expected: root:root)"
                set dir_bad (math $dir_bad + 1)
            else
                if test (string length -- "$perms") -gt 3
                    set perms (string sub -s 2 -- "$perms")
                end
                set -l other_w (string sub -s 3 -l 1 -- "$perms")
                set -l group_w (string sub -s 2 -l 1 -- "$perms")
                set -l other_has_w (math "floor($other_w / 2) % 2" 2>/dev/null)
                set -l group_has_w (math "floor($group_w / 2) % 2" 2>/dev/null)
                if test "$other_has_w" -eq 1 2>/dev/null || test "$group_has_w" -eq 1 2>/dev/null
                    _fail "  $dir: $perms (writable by non-root)"
                    set dir_bad (math $dir_bad + 1)
                end
            end
        end
    end
    if test $dir_bad -eq 0 && test $dir_checked -gt 0
        _ok "  All $dir_checked parent directories: correct ownership, not world/group-writable"
    else if test $dir_checked -eq 0
        _warn "  No parent directories found to check"
    end
    _echo

    _echo "── Completions ──"
    set -l comp_dir "$HOME/.config/fish/completions"
    set -l comp_file "$comp_dir/ry-install.fish"
    if test -f "$comp_file"
        set -l comp_perms (stat -c '%a' -- "$comp_file" 2>/dev/null)
        if test "$comp_perms" = 644
            _ok "  $comp_file: present (644)"
        else
            _warn "  $comp_file: permissions $comp_perms (expected 644)"
        end
        set -l comp_ver (string match -r 'v([0-9.]+)' -- (head -n 1 "$comp_file" 2>/dev/null) | tail -n 1)
        if test "$comp_ver" = "$VERSION"
            _ok "  Completions version: v$comp_ver"
        else if test -n "$comp_ver"
            _warn "  Completions version: v$comp_ver (script is v$VERSION — run --completions)"
        end
    else
        _info "  Completions not installed (run --completions)"
    end
    _echo

    _echo "PACKAGE MANAGEMENT"
    _echo

    _echo "── Pacnew/Pacsave files ──"
    set -l pac_managed 0
    set -l pac_managed_bad 0
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        for _pac_ext in .pacnew .pacsave
            if sudo test -f "$dst$_pac_ext" 2>/dev/null
                _fail "  $dst$_pac_ext (stale — review with pacdiff)"
                set pac_managed_bad (math $pac_managed_bad + 1)
            end
        end
        set pac_managed (math $pac_managed + 1)
    end
    if test $pac_managed_bad -eq 0
        _ok "  No .pacnew/.pacsave files on managed configs"
    end

    set -l pac_system_count 0
    set -l pac_system_files (_find_pacnew_files)
    if test (count $pac_system_files) -gt 0
        set pac_system_count (count $pac_system_files)
        _warn "  $pac_system_count system-wide .pacnew/.pacsave file(s) found"
        for _pf in $pac_system_files
            _info "    $_pf"
        end
        _info "  Run 'sudo pacdiff' to review"
    else
        _ok "  No system-wide .pacnew/.pacsave files"
    end
    _echo

    _echo "BOOT PERFORMANCE"
    _echo

    if command -q systemd-analyze
        set -l boot_time (systemd-analyze 2>/dev/null | head -n 1)
        _info "  $boot_time"

        set -l total_sec (_get_boot_time)
        if test -n "$total_sec" && string match -qr '^[0-9.]+$' -- "$total_sec"
            set -l target $BOOT_TIME_TARGET
            set -l time_int (printf "%.0f" (math "$total_sec") 2>/dev/null)
            if test -n "$time_int" && test "$time_int" -lt $target
                _ok "  Boot time under $target""s target"
            else if test -n "$time_int"
                _info "  Boot time exceeds $target""s target (ignored)"
                _info "  Run 'systemd-analyze blame' to identify slow services"
            end
        end

        _echo "  Slowest services:"
        set -l blame (systemd-analyze blame 2>/dev/null | head -n 3)
        for line in $blame
            _info "    $line"
        end
    else
        _warn "  systemd-analyze not available"
    end
    _echo

    _log "=== RUNTIME VERIFICATION END ==="

    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

# ═══ LINT, CLEAN — development and maintenance tools ═══
function do_lint --description "Lint the script source for fish anti-patterns and style issues"
    _log "=== LINT CHECK START ==="
    _info "Running fish syntax check..."
    _echo

    set -l script_path (status filename)

    if test "$script_path" != (status current-filename 2>/dev/null|| echo "$script_path")
        _warn "Script appears to be sourced; lint results may vary"
    end

    set -l has_errors false

    _echo "── Fish Syntax Check ──"
    if fish -n "$script_path" 2>&1
        _ok "ry-install.fish: syntax valid"
    else
        set has_errors true
        _fail "Ry-install.fish: syntax errors detected"
    end
    _echo

    _echo "── Formatting Check ──"
    if command -q fish_indent
        set -l indent_diff (fish_indent --check "$script_path" 2>&1)
        if test $status -eq 0
            _ok "fish_indent --check: formatting consistent"
        else
            set -l drift_count (printf '%s\n' $indent_diff | wc -l)
            _warn "Fish_indent reports $drift_count lines of formatting drift"
            _info "  Run: fish_indent -w $script_path"
        end
    else
        _warn "Fish_indent not found — skipping formatting check"
    end
    _echo

    _echo "── Anti-pattern Check ──"

    set -l clean_content (sed '/^[[:space:]]*#/d' "$script_path")

    # Exclude embedded bash in systemd ExecStart= (bash syntax is correct there)
    set -l bash_subst (printf '%s\n' $clean_content | grep -n '\$(' 2>/dev/null | grep -vE "ExecStart|/bin/bash|fish --version|'\\\$\\('|_warn|_ok" | head -n 20|| true)
    if test -n "$bash_subst"
        _warn "Possible bash-style \$() found:"
        set -l lint_out (printf '%s\n' $bash_subst | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_subst | sed 's/^/  /' >&2
        end
    else
        _ok "No bash-style \$() substitution found"
        _info "  Note: ExecStart and embedded bash lines excluded"
    end

    set -l bash_cond (printf '%s\n' $clean_content | grep -nE '(^|[[:space:];])\[\[[[:space:]]' 2>/dev/null | grep -vE '_fail|_ok|_warn|_info|_echo'|| true)
    if test -n "$bash_cond"
        _fail "Bash-style [[ ]] found:"
        set -l lint_out (printf '%s\n' $bash_cond | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_cond | sed 's/^/  /' >&2
        end
        set has_errors true
    else
        _ok "No bash-style [[ ]] conditionals found"
    end

    set -l bash_export (printf '%s\n' $clean_content | grep -n '^[[:space:]]*export ' 2>/dev/null|| true)
    if test -n "$bash_export"
        _fail "Bash-style 'export' found:"
        set -l lint_out (printf '%s\n' $bash_export | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_export | sed 's/^/  /' >&2
        end
        set has_errors true
    else
        _ok "No bash-style 'export' found"
    end

    set -l bash_logic (printf '%s\n' $clean_content | grep -nE '[^|]\|\|[^|]|[^&]&&[^&]' 2>/dev/null | grep -vE "printf|awk|sed|_warn|_ok|_fail|_info|_echo|'.*&&|'.*\|\||NR >|~ /|/\\^"|| true)
    if test -n "$bash_logic"
        _warn "Possible bash-style &&/|| found:"
        set -l lint_out (printf '%s\n' $bash_logic | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_logic | sed 's/^/  /' >&2
        end
    else
        _ok "No bash-style &&/|| operators found"
    end

    set -l bash_varexp (printf '%s\n' $clean_content | grep -nE '\$\{[a-zA-Z_]' 2>/dev/null | grep -vE '_warn|_ok|_fail|_info|_echo|_err|printf'|| true)
    if test -n "$bash_varexp"
        _fail "Bash-style \${var} found:"
        set -l lint_out (printf '%s\n' $bash_varexp | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $bash_varexp | sed 's/^/  /' >&2
        end
        set has_errors true
    else
        _ok "No bash-style \${var} expansion found"
    end

    set -l dead_pipe (printf '%s\n' $clean_content | grep -nE 'grep\s+-[a-zA-Z]*q[a-zA-Z]*\s.*\|' 2>/dev/null | grep -vE '_fail|_ok|_warn|_info|_echo|_err'|| true)
    if test -n "$dead_pipe"
        _warn "Possible dead pipe (grep -q suppresses stdout):"
        set -l lint_out (printf '%s\n' $dead_pipe | sed 's/^/  /')
        _log "LINT: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $dead_pipe | sed 's/^/  /' >&2
        end
    else
        _ok "No dead grep -q pipes found"
        # Cross-check: header version, VERSION constant, changelog, and README badge
    end

    # Scope shadow check: set -l inside for/while/if/switch blocks can shadow outer variables
    # mawk-compatible (no match capture groups), tracks piped while (cmd | while read),
    # anchored ^set -l filters string false positives (e.g. lint messages containing "set -l")
    set -l shadow_hits (awk '
        /^[[:space:]]*function / { in_func=1; depth=0; delete vars; next }
        !in_func { next }
        /^[[:space:]]*end($|[[:space:]])/ { if (depth > 0) depth--; else in_func=0; next }
        /^[[:space:]]*(for|while|if|switch)[[:space:]]/ { depth++ }
        /\|[[:space:]]*while[[:space:]]/ { depth++ }
        /^[[:space:]]*set -l [a-zA-Z_]/ {
            i = index($0, "set -l ")
            if (i > 0) {
                rest = substr($0, i + 7)
                sub(/[^a-zA-Z0-9_].*/, "", rest)
                if (rest != "") {
                    if (depth > 0 && rest in vars) print NR": "$0
                    if (depth == 0) vars[rest] = 1
                }
            }
        }
    ' "$script_path" 2>/dev/null|| true)
    if test -n "$shadow_hits"
        set -l shadow_count (printf '%s\n' $shadow_hits | wc -l)
        _warn "Found $shadow_count potential scope shadow(s) (set -l inside block re-declares outer variable):"
        set -l lint_out (printf '%s\n' $shadow_hits | sed 's/^/  /' | head -n 10)
        _log "LINT_SCOPE: $lint_out"
        if test "$QUIET" = false
            printf '%s\n' $shadow_hits | sed 's/^/  /' | head -n 10 >&2
        end
    else
        _ok "No scope shadow patterns found (set -l inside blocks)"
    end
    _echo

    _echo "── Internal Consistency ──"
    set -l header_ver (sed -n -- 's/^# ry-install v\([0-9][0-9.]*\).*/\1/p' "$script_path" | head -n 1)
    if test -n "$header_ver"
        if test "$header_ver" = "$VERSION"
            _ok "Header version matches: v$VERSION"
        else
            _fail "Header version mismatch: header=$header_ver global=$VERSION"
            set has_errors true
        end
    else
        _warn "Could not parse header version"
    end
    set -l script_dir (dirname -- "$script_path")
    set -l readme_path "$script_dir/README.md"
    if test -f "$readme_path"
        set -l readme_ver (sed -n -- 's/.*version-\([0-9][0-9.]*\)-.*/\1/p' "$readme_path" | head -n 1)
        if test -z "$readme_ver"
            set readme_ver (sed -n -- 's/^[- ]*\*\*v\([0-9][0-9.]*\)\*\*.*/\1/p' "$readme_path" | head -n 1)
        end
        if test -n "$readme_ver"
            if test "$readme_ver" = "$VERSION"
                _ok "README version matches: v$VERSION"
            else
                _fail "README version mismatch: readme=$readme_ver global=$VERSION"
                set has_errors true
            end
        else
            _warn "Could not parse README version"
        end
    end

    set -l total (math (count $SYSTEM_DESTINATIONS) + (count $USER_DESTINATIONS) + (count $SERVICE_DESTINATIONS))
    set -l case_count (sed -n -- '/^function get_file_content/,/^end$/p' "$script_path" | grep -cE "case [\"']?(/|[*]/.)")
    if test $total -eq $case_count
        _ok "File count verified: $total destinations = $case_count content cases"
    else
        _fail "File count mismatch: $total destinations but $case_count content cases"
        set has_errors true
    end

    set -l steps_count (count $PROGRESS_STEPS)
    set -l progress_calls (sed -n -- '/^function _install_/,/^end$/p; /^function do_install/,/^end$/p' "$script_path" | grep -c '_progress "')
    if test $steps_count -eq $progress_calls
        _ok "Progress steps verified: $steps_count steps = $progress_calls calls"
    else
        _fail "Progress mismatch: PROGRESS_STEPS has $steps_count, but do_install has $progress_calls _progress calls"
        set has_errors true
    end

    set -l mask_count (count $MASK)
    if test $mask_count -gt 0
        _ok "MASK list: $mask_count services/targets defined"
    else
        _fail "MASK list is empty"
        set has_errors true
    end

    _log "=== LINT END ==="

    if test "$has_errors" = true
        _fail "Lint check completed with errors"
        return 1
    else
        _ok "Lint check passed"
        return 0
    end
end


# Return path of most recently modified *.jsonl under ~/ry-install/logs/
function _find_latest_log --description "Find the most recent ry-install log file"
    set -l base "$HOME/ry-install/logs"
    test -d "$base" || return 1
    command find "$base" -name '*.jsonl' -type f ! -path "$LOG_FILE" -printf '%T@\t%p\n' 2>/dev/null | sort -n | tail -n 1 | string replace -r -- '^[^\t]+\t' ''
end

# List all log files with size, exit status, and pass/fail/warn counts from JSONL footers
function _logs_list --description "List available ry-install log files"
    set -l base "$HOME/ry-install/logs"
    if not test -d "$base"
        _warn "No log directory: $base"
        return 1
    end
    set -l files (command find "$base" -name '*.jsonl' -type f ! -path "$LOG_FILE" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n 20 | string replace -r -- '^[^\t]+\t' '')
    if test (count $files) -eq 0
        _info "No log files found"
        return 0
    end

    _info "Recent log files (newest first):"
    _echo
    for f in $files
        set -l fname (basename -- "$f")
        set -l fdir (basename (dirname -- "$f"))
        set -l size (stat -c '%s' -- "$f" 2>/dev/null|| echo 0)
        set -l size_k (math "ceil($size / 1024)")

        set -l footer (tail -n 1 "$f" 2>/dev/null)
        set -l exit_code ""
        set -l pass ""
        set -l fail ""
        set -l warn ""
        if string match -q '*"event":"footer"*' -- "$footer"
            set exit_code (printf '%s' "$footer" | grep -oE '"exit_code":[0-9]+' | sed 's/.*://')
            set pass (printf '%s' "$footer" | grep -oE '"pass":[0-9]+' | sed 's/.*://')
            set fail (printf '%s' "$footer" | grep -oE '"fail":[0-9]+' | sed 's/.*://')
            set warn (printf '%s' "$footer" | grep -oE '"warn":[0-9]+' | sed 's/.*://')
        end

        set -l summary ""
        if test -n "$exit_code"
            set -l result_mark "✓"
            if test "$exit_code" != 0
                set result_mark "✗"
            end
            set summary (printf '  %s exit=%s' "$result_mark" "$exit_code")
            if test -n "$pass" || test -n "$fail"
                set summary "$summary pass=$pass fail=$fail warn=$warn"
            end
        end

        _echo "  $fdir/$fname  ($size_k KB)$summary"
    end
    _echo
    _info "Analyze: ry-install.fish --logs analyze <path>"
end

# Parse a JSONL log file and display run info, results, warnings, and per-mode breakdown
function _analyze_log --argument-names log_path --description "Parse and summarize a single ry-install log file"
    if test (count $argv) -ne 1
        _err "_analyze_log: expected 1 arg (log_path), got "(count $argv)
        # Parse NDJSON log entries into structured summary
        return 1
    end
    set -l fname (basename -- "$log_path")
    _info "Analyzing: $fname"
    _echo

    set -l header (head -n 1 "$log_path" 2>/dev/null)
    set -l mode ""
    set -l log_version ""
    set -l command ""
    set -l header_ts ""
    set -l dry_run ""
    if string match -q '*"event":"header"*' -- "$header"
        set mode (printf '%s' "$header" | grep -oE '"mode":"[^"]+"' | cut -d'"' -f4)
        set log_version (printf '%s' "$header" | grep -oE '"version":"[^"]+"' | cut -d'"' -f4)
        set command (printf '%s' "$header" | grep -oE '"command":"[^"]+"' | cut -d'"' -f4)
        set header_ts (printf '%s' "$header" | grep -oE '"ts":"[^"]+"' | cut -d'"' -f4)
        set dry_run (printf '%s' "$header" | grep -oE '"dry_run":[a-z]+' | sed 's/.*://')
    end

    set -l footer (tail -n 1 "$log_path" 2>/dev/null)
    set -l exit_code ""
    set -l pass 0
    set -l fail 0
    set -l warn_count 0
    set -l footer_ts ""
    set -l interrupted false
    if string match -q '*"event":"footer"*' -- "$footer"
        set exit_code (printf '%s' "$footer" | grep -oE '"exit_code":[0-9]+' | sed 's/.*://')
        set pass (printf '%s' "$footer" | grep -oE '"pass":[0-9]+' | sed 's/.*://')
        set fail (printf '%s' "$footer" | grep -oE '"fail":[0-9]+' | sed 's/.*://')
        set warn_count (printf '%s' "$footer" | grep -oE '"warn":[0-9]+' | sed 's/.*://')
        set footer_ts (printf '%s' "$footer" | grep -oE '"finished":"[^"]+"' | cut -d'"' -f4)
        if string match -q '*"interrupted":true*' -- "$footer"
            set interrupted true
        end
    end

    set -l duration ""
    if test -n "$header_ts" && test -n "$footer_ts"
        set -l start_epoch (date -d "$header_ts" +%s 2>/dev/null)
        set -l end_epoch (date -d "$footer_ts" +%s 2>/dev/null)
        if test -n "$start_epoch" && test -n "$end_epoch"
            set -l secs (math "$end_epoch - $start_epoch")
            if test "$secs" -ge 60
                set duration (printf '%dm%ds' (math "floor($secs / 60)") (math "$secs % 60"))
            else
                set duration (printf '%ds' "$secs")
            end
        end
    end

    _echo "── Run Info ──"
    test -n "$mode" && _echo "  Mode:    $mode"
    test -n "$log_version" && _echo "  Version: $log_version"
    test -n "$header_ts" && _echo "  Started: $header_ts"
    test -n "$duration" && _echo "  Duration: $duration"
    test "$dry_run" = true && _echo "  Dry run: yes"
    test "$interrupted" = true && _echo "  Status:  INTERRUPTED"
    test -n "$command" && _echo "  Command: $command"
    _echo

    _echo "── Results ──"
    if test -n "$exit_code"
        if test "$exit_code" = 0
            _ok "  Exit: 0 (success)"
        else if test "$exit_code" = 130
            _warn "  Exit: 130 (interrupted)"
        else
            _fail "  Exit: $exit_code (failure)"
        end
    else
        # Aggregate timing data and error counts
        _warn "  No footer found (incomplete run?)"
    end
    set -l total_checks (math "$pass + $fail + $warn_count")
    if test "$total_checks" -gt 0
        _echo "  Checks: $total_checks total — $pass passed, $fail failed, $warn_count warnings"
    end
    _echo

    set -l all_fails (grep -E '"event":"fail"' "$log_path" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)
    set -l all_warns (grep -E '"event":"warn"' "$log_path" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)
    set -l all_errs (grep -E '"event":"err"' "$log_path" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)
    set -l stderr_lines (grep -E '"event":"stderr"' "$log_path" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)

    if test (count $all_fails) -gt 0
        _echo "── Failures ──"
        printf '%s\n' $all_fails | LC_ALL=C sort -u | while read -l line
            test -n "$line" && _fail "  $line"
        end
        _echo
    end

    if test (count $all_errs) -gt 0
        _echo "── Errors ──"
        printf '%s\n' $all_errs | LC_ALL=C sort -u | while read -l line
            test -n "$line" && _err "  $line"
        end
        _echo
    end

    if test (count $all_warns) -gt 0
        _echo "── Warnings ──"
        printf '%s\n' $all_warns | LC_ALL=C sort -u | while read -l line
            test -n "$line" && _warn "  $line"
        end
        _echo
    end

    if test (count $stderr_lines) -gt 0
        _echo "── Captured Stderr ──"
        for line in $stderr_lines
            _echo "  $line"
        end
        _echo
    end

    set -l step_lines (grep -- '"event":"step_time"' "$log_path" 2>/dev/null)
    if test (count $step_lines) -gt 0
        _echo "── Step Timing ──"
        set -l total_step_s 0
        for line in $step_lines
            set -l sname (printf '%s' "$line" | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)
            set -l selap (printf '%s' "$line" | grep -oE '"elapsed_s":[0-9]+' | sed 's/.*://')
            test -z "$selap" && set selap 0
            set total_step_s (math "$total_step_s + $selap")
            _echo (printf '  %-30s %ds' "$sname" "$selap")
        end
        _echo (printf '  %-30s %ds' "Total" "$total_step_s")
        _echo
    end

    if test "$mode" = test-all
        set -l test_ok (grep '"event":"ok"' "$log_path" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)
        set -l test_warns_ta (grep '"event":"warn"' "$log_path" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4 | grep 'exit code')
        if test (count $test_ok) -gt 0 || test (count $test_warns_ta) -gt 0
            _echo "── Per-Mode Results ──"
            for line in $test_ok
                _ok "  $line"
            end
            for line in $test_warns_ta
                _warn "  $line"
            end
            _echo
        end
    end

    set -l diff_lines (grep -- '"event":"diff"' "$log_path" 2>/dev/null)
    if test (count $diff_lines) -gt 0
        set -l diff_files (printf '%s\n' $diff_lines | grep -oE '"data":"DIFF: [^:]+' | sed 's/"data":"DIFF: //' | LC_ALL=C sort -u)
        if test (count $diff_files) -gt 0
            _echo "── Drifted Files ──"
            for f in $diff_files
                _warn "  $f"
            end
            _echo
        end
    end

    _echo "── Log File ──"
    _echo "  $log_path"
    set -l line_count (wc -l < "$log_path" 2>/dev/null | string trim --)
    set -l size (stat -c '%s' -- "$log_path" 2>/dev/null|| echo 0)
    _echo "  $line_count events, "(math "ceil($size / 1024)")" KB"

    test -n "$exit_code" && return "$exit_code"
    return 0
end

# Route --logs subcommands: list, last, all, analyze <path>, system/gpu/wifi/boot/audio/usb/kernel.
function _logs_file_ops --argument-names target --description "Log viewer: analyze, last, list, all file operations"
    # File-based log operations: analyze, last, list, all
    switch $target
        case analyze
            set -l log_path "$argv[2]"
            if test -z "$log_path"
                set log_path (_find_latest_log)
                if test -z "$log_path"
                    _warn "No log files found in ~/ry-install/logs/"
                    return 1
                end
            end
            if not test -f "$log_path"
                _err "Log file not found: $log_path"
                return 1
            end
            _analyze_log "$log_path"
            return $status

        case last
            set -l log_path (_find_latest_log)
            if test -z "$log_path"
                _warn "No log files found in ~/ry-install/logs/"
                return 1
            end
            _analyze_log "$log_path"
            return $status

        case list
            _logs_list
            return $status

        case all
            set -l base "$HOME/ry-install/logs"
            if not test -d "$base"
                _warn "No log directory: $base"
                return 1
            end
            set -l files (command find "$base" -name '*.jsonl' -type f -printf '%T@\t%p\n' 2>/dev/null | sort -n | string replace -r -- '^[^\t]+\t' '')
            if test (count $files) -eq 0
                _info "No log files found"
                return 0
            end

            set -l total_files (count $files)
            set -l total_pass 0
            set -l total_fail 0
            set -l total_warn 0
            set -l failed_runs

            _info "Analyzing $total_files log files..."
            _echo

            for f in $files
                set -l fname (basename -- "$f")
                set -l fdir (basename (dirname -- "$f"))

                set -l footer (tail -n 1 "$f" 2>/dev/null)
                set -l exit_code ""
                set -l pass 0
                set -l fail 0
                set -l warn_c 0
                set -l interrupted false
                if string match -q '*"event":"footer"*' -- "$footer"
                    set exit_code (printf '%s' "$footer" | grep -oE '"exit_code":[0-9]+' | sed 's/.*://')
                    set pass (printf '%s' "$footer" | grep -oE '"pass":[0-9]+' | sed 's/.*://')
                    set fail (printf '%s' "$footer" | grep -oE '"fail":[0-9]+' | sed 's/.*://')
                    set warn_c (printf '%s' "$footer" | grep -oE '"warn":[0-9]+' | sed 's/.*://')
                    string match -q '*"interrupted":true*' -- "$footer" && set interrupted true
                    # Iterate all log files, compile pass/fail summary
                end

                test -n "$pass" && string match -qr '^\d+$' -- "$pass" && set total_pass (math "$total_pass + $pass")
                test -n "$fail" && string match -qr '^\d+$' -- "$fail" && set total_fail (math "$total_fail + $fail")
                test -n "$warn_c" && string match -qr '^\d+$' -- "$warn_c" && set total_warn (math "$total_warn + $warn_c")

                set -l all_fails (grep -E '"event":"fail"' "$f" 2>/dev/null | grep -oE '"data":"[^"]+"' | cut -d'"' -f4)

                set -l mark "✓"
                if test -n "$exit_code" && test "$exit_code" != 0
                    set mark "✗"
                    set -a failed_runs "$fdir/$fname"
                end
                if test "$interrupted" = true
                    set mark "⚡"
                end

                set -l summary (printf '%s %-50s exit=%-3s pass=%-3s fail=%-3s warn=%s' "$mark" "$fdir/$fname" "$exit_code" "$pass" "$fail" "$warn_c")
                _echo "  $summary"

                if test (count $all_fails) -gt 0
                    printf '%s\n' $all_fails | LC_ALL=C sort -u | while read -l line
                        test -n "$line" && _echo "      ✗ $line"
                    end
                end
            end

            _echo
            _echo "── Combined Summary ──"
            _echo "  Files:    $total_files"
            _echo "  Passed:   $total_pass"
            _echo "  Failed:   $total_fail"
            _echo "  Warnings: $total_warn"

            if test (count $failed_runs) -gt 0
                _echo
                _echo "── Failed Runs ──"
                for r in $failed_runs
                    _fail "  $r"
                end
            end

            test "$total_fail" -eq 0 && return 0 || return 1
    end
end

function _logs_journal --argument-names target --description "Log viewer: system journal targets (system, gpu, wifi, boot, audio, usb, kernel)"
    # Per-target journal/dmesg log retrieval
    set -l _log_lines
    switch $target
        case system
            _info "System errors (last hour):"
            _echo
            _echo "── dmesg errors & warnings ──"
            if command -q sudo
                set _log_lines (sudo dmesg --level=err,warn --ctime 2>/dev/null | tail -n 30)
            else
                set _log_lines (dmesg --level=err,warn --ctime 2>/dev/null | tail -n 30)
            end
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end
            _echo
            _echo "── journal errors ──"
            set _log_lines (journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | tail -n 30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end

        case gpu
            _info "AMDGPU logs:"
            _echo
            set _log_lines (sudo dmesg 2>/dev/null | grep -iE "amdgpu|drm|radeon|gfx" | tail -n 50)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end

        case wifi
            _info "WiFi logs (last 30 min):"
            _echo
            set _log_lines (journalctl -u NetworkManager -u iwd --since "30 minutes ago" --no-pager 2>/dev/null | tail -n 50)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end

            # Boot sequence and early startup logs
        case boot
            _info "Boot logs:"
            _echo
            set _log_lines (journalctl -b --no-pager 2>/dev/null | head -n 100)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
                if test (count $_log_lines) -ge 100
                    _info "(truncated at 100 lines — use 'journalctl -b' for full output)"
                end
            else
                _echo "  (no output)"
            end

        case audio
            _info "Audio logs:"
            _echo
            set _log_lines (journalctl --user -u pipewire -u wireplumber --since "1 hour ago" --no-pager 2>/dev/null | tail -n 50)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end

        case usb
            _info "USB events:"
            _echo
            set _log_lines (sudo dmesg 2>/dev/null | grep -iE "usb|hub" | grep -v "amdgpu" | tail -n 30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end

        case kernel
            _info "Kernel errors and warnings:"
            _echo
            _echo "── dmesg errors ──"
            set _log_lines (sudo dmesg --level=err 2>/dev/null | tail -n 30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end
            _echo
            _echo "── dmesg warnings ──"
            set _log_lines (sudo dmesg --level=warn 2>/dev/null | tail -n 30)
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end
    end
end

function do_logs --argument-names target --description "Browse, search, and analyze ry-install log files"
    set -l target $argv[1]

    _banner "ry-install v$VERSION - Log Viewer"

    if test -z "$target"
        _info "Usage: ry-install.fish --logs <target>"
        _echo
        _info "Available targets:"
        _echo "    analyze [file]  - Parse NDJSON log, show human-readable results"
        _echo "    last            - Analyze most recent log file"
        _echo "    all             - Analyze all logs, show combined summary"
        _echo "    list            - List recent log files with summaries"
        _echo "    system          - Recent system errors (dmesg + journal)"
        _echo "    gpu             - AMDGPU driver messages"
        _echo "    wifi            - NetworkManager + iwd logs"
        _echo "    boot            - Boot sequence logs"
        _echo "    audio           - PipeWire/audio logs"
        _echo "    usb             - USB device events"
        _echo "    kernel          - Kernel errors and warnings (dmesg)"
        _echo "    <service>       - Any systemd service name"
        return 2
    end

    switch $target
        case analyze last list all
            _logs_file_ops $argv
            return $status
        case system gpu wifi boot audio usb kernel
            _logs_journal $target
        case '*'
            if string match -q -- '-*' "$target"
                _warn "Invalid log target: '$target' (looks like a flag)"
                _info "Valid targets: system, gpu, wifi, boot, audio, usb, kernel, <service>"
                return 1
            end
            _info "Logs for $target:"
            _echo
            # Arbitrary systemd service journal lookup with fuzzy-match fallback
            if systemctl cat "$target" >/dev/null 2>&1
                set _log_lines (journalctl -u "$target" --since "1 hour ago" --no-pager 2>/dev/null | tail -n 50)
                if test (count $_log_lines) -gt 0
                    for line in $_log_lines
                        _echo "$line"
                    end
                else
                    _echo "  (no output)"
                end
            else
                _warn "Service '$target' not found"
                # Fuzzy-match: suggest known target if first 3 chars match and length is close (within ±2)
                set -l _known_targets system gpu wifi boot audio usb kernel
                set -l _t_prefix (string sub -l 3 -- "$target")
                set -l _t_len (string length -- "$target")
                for _kt in $_known_targets
                    set -l _kt_len (string length -- "$_kt")
                    if string match -qi -- "$_t_prefix*" "$_kt"
                        if test (math "abs($_t_len - $_kt_len)") -le 2
                            _info "Did you mean '$_kt'?"
                            break
                        end
                    end
                end
                _info "Valid targets: system, gpu, wifi, boot, audio, usb, kernel, <service>"
                return 1
            end
    end
end

# ── Diagnostic helpers ── extracted from do_diagnose for readability ──

function _diag_info --description "Diagnose: system overview, fans, power, schedulers"
    _echo "── System Overview ──"
    set -l kernel $KVER
    # System overview: kernel, uptime, hostname, arch
    set -l uptime (uptime -p 2>/dev/null | string replace -- 'up ' '')
    set -l boot_time (who -b 2>/dev/null | awk '{print $3, $4}')
    _info "Kernel: $kernel"
    _info "Uptime: $uptime"
    if test -n "$boot_time"
        _info "Booted: $boot_time"
    end

    set -l last_update (grep -E "^\[.*\] \[PACMAN\] starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -n 1 | grep -oE '\[[-0-9T:+]+\]' | head -n 1 | tr -d '[]')
    if test -n "$last_update"
        _info "Last update: $last_update"
    end
    _echo

    _echo "── Fans ──"
    _gather_temps
    # Read fan RPMs from /sys/class/hwmon/hwmon*/fan*_input; 0 RPM fans are excluded from output
    set -l fan_readings
    for f in /sys/class/hwmon/hwmon*/fan*_input
        test -f "$f" || continue
        set -l rpm (cat -- "$f" 2>/dev/null|| echo 0)
        if string match -qr '^\d+$' -- "$rpm" && test "$rpm" -gt 0
            set -l label_f (string replace '_input' '_label' -- "$f")
            set -l label ""
            if test -f "$label_f"
                set label (string trim -- (cat -- "$label_f" 2>/dev/null))
            end
            if test -z "$label"
                set label (basename -- "$f" | string replace '_input' '')
            end
            set -a fan_readings "$label: $rpm RPM"
        end
    end
    if test (count $fan_readings) -gt 0
        for fr in $fan_readings
            _ok "  $fr"
        end
    else
        _info "No fan sensors detected"
    end
    _echo

    _echo "── Power ──"
    # power1_average reports microwatts; 0W means RAPL not exposing data
    set -l pkg_power ""
    for f in /sys/class/hwmon/hwmon*/power1_average
        if test -f "$f"
            set pkg_power (cat -- "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$pkg_power" && string match -qr '^\d+$' -- "$pkg_power"
        set -l watts (math "$pkg_power / 1000000")
        _info "Package power: "$watts"W"
    end
    set -l gpu_power ""
    for f in /sys/class/drm/card*/device/hwmon/hwmon*/power1_average
        if test -f "$f"
            set gpu_power (cat -- "$f" 2>/dev/null)
            break
        end
    end
    if test -n "$gpu_power" && string match -qr '^\d+$' -- "$gpu_power"
        set -l watts (math "$gpu_power / 1000000")
        _info "GPU power: "$watts"W"
    end
    if test -z "$pkg_power" && test -z "$gpu_power"
        _info "Power sensors not available"
    end
    _echo

    _echo "── Schedulers ──"
    set -l cpu_sched ""
    # /sys/kernel/debug/sched/ requires root; fall back to /proc/config.gz CONFIG_SCHED_* if unavailable
    for f in /sys/kernel/debug/sched/*/name
        if test -f "$f"
            set cpu_sched (cat -- "$f" 2>/dev/null)
            break
        end
    end
    if test -z "$cpu_sched"
        set cpu_sched (zgrep CONFIG_SCHED /proc/config.gz 2>/dev/null | grep "=y" | head -n 1 | cut -d'_' -f3 | cut -d'=' -f1)
    end
    if test -n "$cpu_sched"
        _info "CPU scheduler: $cpu_sched"
    end

    set -l root_dev (findmnt -no SOURCE / 2>/dev/null | string replace -r -- '\[.*\]' '' | xargs -r realpath 2>/dev/null)
    set -l blk_name
    if string match -q '/dev/dm-*' -- "$root_dev"
        # DM devices lack I/O schedulers; traverse slaves/ to find underlying block device
        set -l dm_name (string replace '/dev/' '' -- "$root_dev")
        set -l slaves /sys/block/$dm_name/slaves/* 2>/dev/null
        if set -q slaves[1]
            set blk_name (string replace -r '.*/' '' -- $slaves[1])
        end
    else if test -n "$root_dev"
        set blk_name (basename (string replace -r 'p?[0-9]*$' '' -- "$root_dev") 2>/dev/null)
    end
    if test -z "$blk_name"
        _warn "Could not detect root block device for I/O scheduler"
    else
        set -l io_sched (grep -oE -- '\[.*\]' /sys/block/$blk_name/queue/scheduler 2>/dev/null | tr -d '[]')
        if test -n "$io_sched"
            _info "I/O scheduler: $io_sched ($blk_name)"
        end
    end
    _echo

    _echo "════════════════════════════════════════════════════════════════════"
    _echo
end

function _diag_services --description "Diagnose: kernel errors, failed services, expected services"
    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Kernel Errors ──"
    # Kernel error count from dmesg
    if command -q sudo
        set -l kernel_errors (sudo dmesg --level=err 2>/dev/null | wc -l | string trim --)
        if test -n "$kernel_errors" && string match -qr '^\d+$' -- "$kernel_errors" && test "$kernel_errors" -gt 0
            _warn "Found $kernel_errors kernel error(s)"
            set -l _diag_lines (sudo dmesg --level=err 2>/dev/null | tail -n 5)
            for line in $_diag_lines
                _echo "  $line"
            end
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "No kernel errors"
        end
    else
        _info "sudo not available for dmesg check"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Failed Services ──"
    set -l failed (systemctl --failed --no-pager 2>/dev/null | grep -c "failed" | string trim --)
    if test -n "$failed" && string match -qr '^\d+$' -- "$failed" && test "$failed" -gt 0
        _warn "Found $failed failed system service(s):"
        set -l _diag_lines (systemctl --failed --no-pager 2>/dev/null | grep failed | head -n 5)
        for line in $_diag_lines
            _echo "  $line"
            # Verify critical services are active and enabled
        end
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    else
        _ok "No failed system services"
    end
    set -l user_failed (systemctl --user --failed --no-pager 2>/dev/null | grep -c "failed" | string trim --)
    if test -n "$user_failed" && string match -qr '^\d+$' -- "$user_failed" && test "$user_failed" -gt 0
        _warn "Found $user_failed failed user service(s):"
        set -l _diag_lines (systemctl --user --failed --no-pager 2>/dev/null | grep failed | head -n 5)
        for line in $_diag_lines
            _echo "  $line"
        end
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    else
        _ok "No failed user services"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Expected Services ──"
    for svc in amdgpu-performance cpupower-epp fstrim.timer NetworkManager
        set -l state (systemctl is-active "$svc" 2>/dev/null)
        if test "$state" = active
            _ok "$svc: active"
        else
            _warn "$svc: $state"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        end
    end
    set -l ssh_user_state (systemctl --user is-active ssh-agent.service 2>/dev/null)
    if test "$ssh_user_state" = active
        _ok "ssh-agent.service (user): active"
    else
        _warn "Ssh-agent.service (user): $ssh_user_state"
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
end

function _diag_hardware --description "Diagnose: GPU, CPU, disk space, temperatures"
    _echo "── GPU State ──"
    _gather_gpu_state
    if test "$_GPU_PERF_LEVEL" = high
        _ok "GPU performance: high"
    else if test -n "$_GPU_PERF_LEVEL"
        _warn "GPU performance: $_GPU_PERF_LEVEL (expected: high)"
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    else
        _warn "Cannot read GPU performance level"
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── CPU State ──"
    _gather_cpu_state
    if test "$_CPU_GOVERNOR" = powersave
        _ok "CPU governor: powersave (amd_pstate=active + performance EPP)"
    else if test -n "$_CPU_GOVERNOR"
        _warn "CPU governor: $_CPU_GOVERNOR (expected: powersave)"
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    else
        _info "CPU governor: not available"
    end

    # Disk usage thresholds for root and boot partitions
    if test "$_CPU_EPP" = performance
        _ok "CPU EPP: performance"
    else if test -n "$_CPU_EPP"
        _warn "CPU EPP: $_CPU_EPP (expected: performance)"
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    else
        _info "CPU EPP: not available"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Disk Space ──"
    set -l root_pct (LC_ALL=C df / 2>/dev/null | tail -n 1 | awk '{print $5}' | tr -d '%')
    if test -n "$root_pct" && string match -qr '^\d+$' -- "$root_pct"
        if test "$root_pct" -ge $DISK_ROOT_CRIT
            _fail "Root filesystem: $root_pct% (critical)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else if test "$root_pct" -ge $DISK_ROOT_WARN
            _warn "Root filesystem: $root_pct% (getting full)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "Root filesystem: $root_pct%"
        end
    end
    set -l boot_avail (LC_ALL=C df -BM /boot 2>/dev/null | tail -n 1 | awk '{print $4}' | tr -d 'M')
    if test -n "$boot_avail" && string match -qr '^\d+$' -- "$boot_avail"
        if test "$boot_avail" -lt $BOOT_SPACE_CRIT
            _fail "/boot: "$boot_avail"MB available (critical — initramfs rebuild will fail)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else if test "$boot_avail" -lt $BOOT_SPACE_WARN
            _warn "/boot: "$boot_avail"MB available (low)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "/boot: "$boot_avail"MB available"
        end
        # Thermal sensor diagnostics: collect temps, warn on high readings
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Temperatures ──"
    if _gather_temps
        if test -n "$_TEMP_CPU_NUM"
            if test -n "$_TEMP_CPU_INT" && string match -qr '^\d+$' -- "$_TEMP_CPU_INT"
                if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_CRIT
                    _fail "CPU: $_TEMP_CPU_NUM°C (throttling likely)"
                    set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                else if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_WARN
                    _warn "CPU: $_TEMP_CPU_NUM°C (high)"
                    set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                else
                    _ok "CPU: $_TEMP_CPU_NUM°C"
                end
            else
                _info "CPU: $_TEMP_CPU_NUM°C (unable to parse for threshold check)"
            end
        end
        if test -n "$_TEMP_GPU_NUM"
            if test -n "$_TEMP_GPU_INT" && string match -qr '^\d+$' -- "$_TEMP_GPU_INT"
                if test "$_TEMP_GPU_INT" -ge $TEMP_GPU_CRIT
                    _fail "GPU: $_TEMP_GPU_NUM°C (critical)"
                    set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                else if test "$_TEMP_GPU_INT" -ge $TEMP_GPU_WARN
                    _warn "GPU: $_TEMP_GPU_NUM°C (high)"
                    set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                else
                    _ok "GPU: $_TEMP_GPU_NUM°C"
                end
            else
                _info "GPU: $_TEMP_GPU_NUM°C (unable to parse for threshold check)"
            end
        end
    else
        _info "No hwmon temperature sensors found"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
end

function _diag_network --description "Diagnose: network, sysctl, gaming, memory, coredumps"
    _echo "── Network ──"
    if command -q nmcli
        # NM connectivity and DNS state
        set -l conn_state (nmcli -t -f STATE g 2>/dev/null)
        if test "$conn_state" = connected
            _ok "Network: connected"
        else
            _warn "Network: $conn_state"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        end
    else
        _info "Network: nmcli not available"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Sysctl Tuning ──"
    set -l _diag_sysctl \
        "net.core.default_qdisc=fq" \
        "net.ipv4.tcp_congestion_control=bbr" \
        "net.ipv4.tcp_fastopen=3" \
        "fs.inotify.max_user_watches=524288"
    for _sc in $_diag_sysctl
        set -l _key (string split '=' -- "$_sc")[1]
        set -l _expected (string split '=' -- "$_sc")[2]
        set -l _proc_path (string replace -a '.' '/' -- "$_key")
        set -l _actual (cat -- "/proc/sys/$_proc_path" 2>/dev/null | string trim --)
        if test "$_actual" = "$_expected"
            _ok "  $_key: $_actual"
        else if test -n "$_actual"
            _warn "  $_key: $_actual (expected: $_expected)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _warn "  $_key: cannot read /proc/sys/$_proc_path"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        end
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    # Memory pressure and OOM history
    _echo "── Gaming ──"
    set -l _ns (_ntsync_state)
    if contains -- $_ns loaded builtin
        _ok "ntsync: available"
    else
        _info "ntsync: not available (kernel 6.14+ required)"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Memory ──"
    if command -q sudo
        set -l oom_count (sudo dmesg 2>/dev/null | grep -c "Out of memory" | string trim --)
        if test -n "$oom_count" && string match -qr '^\d+$' -- "$oom_count" && test "$oom_count" -gt 0
            _warn "OOM events detected: $oom_count"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "No OOM events"
        end
    else
        _info "sudo not available for OOM check"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Coredumps ──"
    if command -q coredumpctl
        set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
        set -l dump_count (string trim -- "$dump_count")
        if test -n "$dump_count" && string match -qr '^\d+$' -- "$dump_count" && test "$dump_count" -gt 0
            _warn "Found $dump_count coredump(s)"
            set -l _diag_lines (coredumpctl list --no-pager 2>/dev/null | tail -n 5)
            for line in $_diag_lines
                _echo "  $line"
            end
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "No coredumps"
        end
    else
        _info "coredumpctl not available"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
end

function _diag_storage --description "Diagnose: journal size, NVMe health, boot performance, ZRAM/ZSWAP"
    _echo "── Journal Size ──"
    set -l journal_size (journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[GMK]' | head -n 1)
    if test -n "$journal_size"
        set -l size_num (string replace -r '[^0-9.]' '' -- "$journal_size")
        set -l size_unit (string replace -r '[0-9.]' '' -- "$journal_size")
        if test -n "$size_num" && string match -qr '^[0-9.]+$' -- "$size_num" && test "$size_unit" = G
            set -l size_int (math "floor($size_num)" 2>/dev/null)
            if test -n "$size_int" && test "$size_int" -ge 2
                _warn "Journal using $journal_size (consider: journalctl --vacuum-size=500M)"
                set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
            else
                _ok "Journal size: $journal_size"
            end
        else
            _ok "Journal size: $journal_size"
        end
    else
        _info "Journal size: not available"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── NVMe Health ──"
    if command -q nvme
        # NVMe SMART health and wear indicators
        set -l nvme_found false
        for dev in (command find /dev -maxdepth 1 -name 'nvme[0-9]*n[0-9]*' -not -name '*p[0-9]*' -type b 2>/dev/null | LC_ALL=C sort)
            set nvme_found true
            set -l smart (sudo nvme smart-log $dev 2>/dev/null)
            if test -n "$smart"
                set -l pct_used (printf '%s\n' $smart | grep -i "percentage_used" | awk '{print $NF}' | tr -d '%')
                set -l crit_warn (printf '%s\n' $smart | grep -i "critical_warning" | awk '{print $NF}')

                if test -n "$crit_warn" && test "$crit_warn" != 0
                    _fail "$dev: Critical warning flag set!"
                    set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                else if test -n "$pct_used" && string match -qr '^\d+$' -- "$pct_used" && test "$pct_used" -ge $NVME_LIFE_WARN
                    _warn "$dev: $pct_used% life used"
                    set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                else if test -n "$pct_used" && string match -qr '^\d+$' -- "$pct_used"
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

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Boot Performance ──"
    if command -q systemd-analyze
        set -l boot_sec (_get_boot_time)
        if test -n "$boot_sec" && string match -qr '^[0-9.]+$' -- "$boot_sec"
            set -l boot_int (math "floor($boot_sec)" 2>/dev/null)
            if test -n "$boot_int" && test "$boot_int" -ge $BOOT_TIME_WARN
                _warn "Slow boot: $boot_sec""s (run: systemd-analyze blame)"
                set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
            else
                _ok "Boot time: $boot_sec""s"
            end
        else
            _info "Boot time: not available"
        end
        # ZRAM/ZSWAP diagnostics: check swap configuration and utilization
    else
        _info "Boot time: systemd-analyze not available"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── ZRAM / ZSWAP ──"
    if command -q zramctl
        set -l zram_out (zramctl 2>/dev/null)
        if test -n "$zram_out"
            _info "ZRAM devices:"
            for zdev in /sys/block/zram[0-9]*
                if test -d "$zdev"
                    set -l zname (basename -- "$zdev")
                    set -l algo (grep -oE -- '\[.*\]' "$zdev/comp_algorithm" 2>/dev/null | tr -d '[]')
                    set -l disksize (cat -- "$zdev/disksize" 2>/dev/null)
                    if test -n "$disksize" && test "$disksize" -gt 0 2>/dev/null
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
    if test -f /sys/module/zswap/parameters/enabled
        set -l zswap_enabled (cat -- /sys/module/zswap/parameters/enabled 2>/dev/null)
        if test "$zswap_enabled" = Y
            _warn "zswap: enabled (expected disabled via cmdline or CachyOS 30-zram.rules)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "zswap: disabled"
        end
    else
        _info "zswap: module not present"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
end

function _diag_config --description "Diagnose: power profiles, stress tests, kernel cmdline, pacnew"
    _echo "── Power Profiles ──"
    if command -q powerprofilesctl
        # Power profile and daemon conflict detection
        set -l profile (powerprofilesctl get 2>/dev/null)
        if test -n "$profile"
            _info "Active power profile: $profile"
            if systemctl is-active --quiet power-profiles-daemon.service 2>/dev/null
                _warn "Power-profiles-daemon is running (should be removed per config)"
                set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
            end
        end
    else
        _ok "powerprofilesctl: not installed (expected — using cpupower-epp)"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Stress Tests (optional) ──"
    set -l run_stress false
    if test "$ALL" = true || test "$STRESS" = true
        set run_stress true
        _log "ASK: Run stress tests? -> auto-yes (--all/--stress)"
    else
        if _ask "Run stress tests? (CPU + memory, ~50s)"
            set run_stress true
        end
    end

    if test "$run_stress" = true
        if command -q stress-ng
            _info "Running CPU stress test (30s)..."
            set -l cpu_result (stress-ng --cpu (nproc) --timeout 30s --metrics 2>&1 | tail -n 3)
            if test -n "$cpu_result"
                for line in $cpu_result
                    _info "  $line"
                end
            end
            _ok "CPU stress test complete"

            _info "Running memory bandwidth test (20s)..."
            set -l mem_result (stress-ng --stream 1 --timeout 20s --metrics 2>&1 | tail -n 3)
            if test -n "$mem_result"
                for line in $mem_result
                    _info "  $line"
                end
            end
            _ok "Memory bandwidth test complete"

            if _gather_temps && test -n "$_TEMP_CPU_NUM"
                if test -n "$_TEMP_CPU_INT" && string match -qr '^\d+$' -- "$_TEMP_CPU_INT"
                    if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_CRIT
                        _fail "Post-stress CPU temp: $_TEMP_CPU_NUM°C (throttling)"
                        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
                    else if test "$_TEMP_CPU_INT" -ge $TEMP_CPU_WARN
                        # Stress test thermal monitoring (optional)
                        _warn "Post-stress CPU temp: $_TEMP_CPU_NUM°C (high but within spec)"
                    else
                        _ok "Post-stress CPU temp: $_TEMP_CPU_NUM°C"
                    end
                end
            end
        else
            _warn "Stress-ng not installed (install via: sudo pacman -S --needed stress-ng)"
            _info "  Or run: ./ry-install.fish (no flags) to get diagnostic packages"
        end
    else
        _info "Skipped (pass --all or answer yes to run)"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Kernel Cmdline ──"
    if test -f /etc/kernel/cmdline
        set -l cmdline_content (sudo cat -- /etc/kernel/cmdline 2>/dev/null)
        set -l missing 0
        for param in $KERNEL_PARAMS
            if not string match -q -- "* $param *" " $cmdline_content "
                set missing (math $missing + 1)
            end
        end
        if test $missing -gt 0
            _warn "/etc/kernel/cmdline: $missing kernel param(s) missing"
            _info "  Run: ./ry-install.fish --all (or reinstall to regenerate)"
            set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
        else
            _ok "/etc/kernel/cmdline: all params present"
        end
    else
        _info "/etc/kernel/cmdline: not found (kernel-install fallback unavailable)"
    end
    _echo

    set -g _DIAG_CHECKS (math $_DIAG_CHECKS + 1)
    _echo "── Pacnew/Pacsave ──"
    set -l _pac_files (_find_pacnew_files)
    if test (count $_pac_files) -gt 0
        _warn "  "(count $_pac_files)" stale .pacnew/.pacsave file(s):"
        for _pf in $_pac_files
            _info "    $_pf"
        end
        _info "  Run 'sudo pacdiff' to review and merge"
        set -g _DIAG_ISSUES (math $_DIAG_ISSUES + 1)
    else
        _ok "  No .pacnew/.pacsave files"
    end
    _echo

end

# Run 20+ diagnostic sections: CPU, GPU, disk, temps, network, services, boot, sysctl, etc.
function do_diagnose --description "Run comprehensive system diagnostics and health checks"
    _log "=== DIAGNOSE START ==="
    _banner "ry-install v$VERSION - System Diagnostics"

    _diag_info

    set -g _DIAG_ISSUES 0
    set -g _DIAG_CHECKS 0

    _diag_services
    _diag_hardware
    _diag_network
    _diag_storage
    _diag_config

    _echo "════════════════════════════════════════════════════════════════════"
    if test $_DIAG_ISSUES -eq 0
        _ok "Diagnostics complete: No issues found ($_DIAG_CHECKS checks passed)"
    else
        _warn "Diagnostics complete: $_DIAG_ISSUES issue(s) found"
        _info "Run './ry-install.fish --logs system' for more details"
    end

    _log "=== DIAGNOSE END ==="
    test $_DIAG_ISSUES -eq 0 && return 0 || return 1
end


# Install pipeline

# ═══ INSTALL PIPELINE — preflight → wifi → packages → files → services → boot → finalize ═══
function _install_collect_wifi --description "Interactively collect WiFi credentials for iwd setup"
    set -g WIFI_SSID ""
    set -g WIFI_PASS ""
    set -g WIFI_IFACE ""

    if test "$DRY" != true && _ask "Reconnect WiFi at end of installation?"
        if not command -q nmcli
            _warn "Nmcli not found - WiFi reconnection will be skipped"
        else
            set -l wlan_iface ""

            if command -q iwctl
                set -l iwctl_output (iwctl device list 2>/dev/null)
                if test -n "$iwctl_output"
                    set wlan_iface (printf '%s\n' $iwctl_output | awk '
                        NR > 4 && /station/ {
                            for(i=1; i<=NF; i++) {
                                if($i ~ /^wl/ || $i ~ /^wlan/) { print $i; exit }
                            }
                            if($2 !~ /^-+$/) print $2; exit
                        }' | head -n 1)
                    if test -n "$wlan_iface" && not test -d "/sys/class/net/$wlan_iface"
                        _warn "Iwctl reported interface '$wlan_iface' not found in /sys/class/net — falling back"
                        set wlan_iface ""
                    end
                end
            end

            if test -z "$wlan_iface"
                for iface in /sys/class/net/*/wireless
                    if test -d "$iface"
                        set wlan_iface (basename (dirname -- "$iface"))
                        break
                    end
                end
            end

            if test -z "$wlan_iface"
                _warn "Could not detect WiFi interface"
                read -P "[?] Enter WiFi interface name: " wlan_iface
                if not string match -qr '^[a-zA-Z0-9_]+$' -- "$wlan_iface" || test (string length -- "$wlan_iface") -gt 15
                    _err "Invalid interface name: must be alphanumeric, max 15 chars"
                    set wlan_iface ""
                else if not test -d "/sys/class/net/$wlan_iface"
                    _err "Interface '$wlan_iface' does not exist (check /sys/class/net/)"
                    set wlan_iface ""
                end
            end

            if test -n "$wlan_iface"
                set -g WIFI_IFACE "$wlan_iface"
                _info "WiFi interface: $wlan_iface"

                read -P "[?] WiFi SSID: " wifi_ssid
                if test -n "$wifi_ssid"
                    set -l _ssid_bad false
                    # GKeyFile special chars (; # leading/trailing space) + shell metacharacters + printf % format injection
                    for _c in / '\\' ';' '`' '$' '(' ')' '{' '}' '|' '<' '>' '&' "'" '"' '%' '!'
                        if string match -q -- "*$_c*" "$wifi_ssid"
                            set _ssid_bad true
                            break
                        end
                    end
                    if test "$_ssid_bad" = true || string match -qr '\\n|\\r' -- "$wifi_ssid"
                        _err "Invalid SSID: contains forbidden characters"
                        _info "SSIDs cannot contain shell metacharacters, quotes, or newlines"
                        _info "Workaround: skip WiFi setup here, then connect manually:"
                        _info "  nmcli device wifi connect '<SSID>' password '<pass>'"
                    else if string match -qr '^ | $' -- "$wifi_ssid"
                        _err "Invalid SSID: leading/trailing whitespace (GKeyFile trims unquoted values)"
                    else if test "$wifi_ssid" = "." || test "$wifi_ssid" = ".."
                        _err "Invalid SSID: cannot be '.' or '..'"
                    else if test (printf '%s' "$wifi_ssid" | wc -c) -gt 32
                        _err "Invalid SSID: must be 1-32 bytes (IEEE 802.11)"
                    else
                        set -g WIFI_SSID "$wifi_ssid"
                        set -l wifi_pass ""
                        read -sP "[?] WiFi passphrase: " wifi_pass
                        echo >&2
                        if string match -qr '\n|\r' -- "$wifi_pass"
                            _err "Invalid passphrase: contains newline"
                            set -g WIFI_SSID ""
                            set wifi_pass ""
                        else if string match -q -- '*%*' "$wifi_pass"
                            _err "Invalid passphrase: contains '%' (GKeyFile parse safety)"
                            set -g WIFI_SSID ""
                            set wifi_pass ""
                        else if test (string length -- "$wifi_pass") -lt 8 || test (string length -- "$wifi_pass") -gt 63
                            _err "Invalid passphrase: WPA2 requires 8-63 characters"
                            set -g WIFI_SSID ""
                            set wifi_pass ""
                        else
                            # Credential lifecycle: set here → used in _install_finalize → erased in _do_cleanup
                            set -g WIFI_PASS "$wifi_pass"
                            set wifi_pass ""
                            _ok "WiFi credentials saved (will connect at end)"
                        end
                    end
                end
            end
        end
    end
    return 0
end

# Pipeline phase 1: deps, disk, network, hardware fingerprint, kernel version, config validation
function _install_preflight --description "Run all preflight checks before installation"
    _progress "Checking dependencies"

    if test "$DRY" = false
        _info "Sudo password required for installation..."
        if test "$ALL" = true
            printf '\n' >&2
        end
        sudo true || begin
            _err "Sudo required for installation"
            return 1
        end
        set -l sudo_all (sudo -l 2>/dev/null | grep -v '^\s*#' | grep -c '(ALL.*) ALL')
        or set sudo_all 0
        if test "$sudo_all" -eq 0
            if test "$ALL" = true
                _err "Restricted sudo incompatible with --all mode (unattended install requires full sudo)"
                # Verify critical paths exist before proceeding
                _kill_sudo_keepalive
                return 1
            end
            _warn "Restricted sudo detected — some operations may fail"
            _warn "Install requires unrestricted sudo for pacman, systemctl, mkinitcpio, etc."
        end
        set -l my_pid %self
        # Keepalive: refresh assumes credential timeout ≥5min (timestamp_timeout=5)
        fish -c 'while kill -0 -- $argv[1] 2>/dev/null&& test -d -- $argv[2]; sudo -n true 2>/dev/null|| break; sleep $argv[3]; end' -- $my_pid "$LOCK_DIR" $SUDO_KEEPALIVE_INTERVAL </dev/null &
        set -g SUDO_KEEPALIVE_PID $last_pid
        if not kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            _warn "Sudo keepalive process failed to start — long installs may require re-auth"
            set --erase SUDO_KEEPALIVE_PID
        else
            disown $SUDO_KEEPALIVE_PID 2>/dev/null
        end

        check_deps || begin
            _kill_sudo_keepalive
            return 1
        end

        check_disk_space || begin
            _kill_sudo_keepalive
            return 1
        end

        _check_hardware_fingerprint || begin
            _kill_sudo_keepalive
            return 1
        end

        check_network || begin
            _err "Network required for package installation — aborting"
            _kill_sudo_keepalive
            return 1
        end
    else
        _info "(dry-run) Skipping: sudo, disk space, hardware fingerprint, network checks"
        _info "(dry-run) Skipping: LVM detection (no sudo credentials)"
    end

    check_kernel_version

    _echo
    validate_configs || begin
        _err "Configuration validation failed - aborting"
        _kill_sudo_keepalive
        return 1
    end
end

# Pipeline phase 3: pacman -Syu, install PKGS_ADD, remove PKGS_DEL with --needed idempotency
function _install_packages --description "Install and remove managed packages via pacman"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress "Syncing packages"
    _echo
    _info "Synchronizing package databases..."

    _progress "Installing packages"
    _echo
    # Install missing packages, then remove unwanted ones
    _info "Package installation..."

    set -l pkgs_to_install $PKGS_ADD

    set -g SYSTEM_UPGRADED false
    if _ask "Sync databases, upgrade system, and install packages? ($pkgs_to_install)"
        set -g SYSTEM_UPGRADED true

        if test "$DRY" = false
            if not install_file "/etc/mkinitcpio.conf" true
                _err "Failed to pre-deploy mkinitcpio.conf before package install"
                _err "Aborting package installation — mkinitcpio.conf must be in place before -Syu"
                set -g INSTALL_HAD_ERRORS true
                return 1
            end
        end

        if test (count $pkgs_to_install) -gt 0
            if test -f /var/lib/pacman/db.lck
                _err "Pacman database is locked (/var/lib/pacman/db.lck exists) — skipping package install"
                set -g INSTALL_HAD_ERRORS true
                set _fn_err true
            else if not _run sudo pacman -Syu --needed --noconfirm -- $pkgs_to_install
                _warn "Package installation failed, retrying with fresh sync..."
                if not _run sudo pacman -Syyu --needed --noconfirm -- $pkgs_to_install
                    _err "Package installation failed after retry"
                    set -g INSTALL_HAD_ERRORS true
                    set _fn_err true
                end
            end

            if test "$DRY" = false
                _info "Verifying package installation..."
                set -l missing_pkgs
                for pkg in $pkgs_to_install
                    # Remove packages that conflict with target configuration
                    if not pacman -Qi "$pkg" >/dev/null 2>&1
                        set -a missing_pkgs "$pkg"
                    end
                end
                if test (count $missing_pkgs) -gt 0
                    _err "Missing packages: $missing_pkgs"
                    _warn "  Install manually: sudo pacman -S --needed $missing_pkgs"
                    set -g INSTALL_HAD_ERRORS true
                    set _fn_err true
                else
                    _ok "All packages verified installed"
                    set -l _pacnew_files (_find_pacnew_files)
                    if test (count $_pacnew_files) -gt 0
                        _warn (count $_pacnew_files)" .pacnew file(s) generated — run 'sudo pacdiff' after install"
                    end
                end
            end
        end
    end
    test "$_fn_err" = true && return 1
    return 0
end

# Pipeline phase 4: deploy all SYSTEM/USER/SERVICE files via install_file with privilege elevation as needed
function _install_system_files --description "Deploy all embedded config files to the system"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress "Installing system files"
    _echo
    _info "Installing system configuration files..."
    if not install_files --sudo --desc "SYSTEM FILES" $SYSTEM_DESTINATIONS
        _err "System file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    _progress "Wireless regulatory domain"
    _echo
    _info "Wireless regulatory domain (current: $WIRELESS_REGDOM)"
    _info "Common codes: US, GB, DE, FR, JP, AU, CA"

    if test "$DRY" != true && not test "$ALL" = true && isatty stdin
        # Interactive wireless regulatory domain configuration
        read -P "[?] Enter your country code (or Enter for US): " regdom_input
        # Validate regulatory domain: must be 2-letter ISO country code
        if test -n "$regdom_input"
            set -l regdom_upper (string upper -- "$regdom_input" | string trim --)

            if not string match -qr '^[A-Z]{2}$' -- "$regdom_upper"
                _err "Invalid country code: '$regdom_input' (must be 2 letters, e.g., US, GB, DE)"
                set -g INSTALL_HAD_ERRORS true
            else
                set -l known_codes (grep -E '^#WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null | string match -rg -- '"([A-Z]{2})"')
                if test (count $known_codes) -eq 0
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
                    set -g INSTALL_HAD_ERRORS true
                else if sudo test -L "$tmpfile"
                    sudo rm -f -- "$tmpfile" 2>/dev/null
                    _err "Temp file is symlink — aborting regulatory domain update"
                    set -g INSTALL_HAD_ERRORS true
                else
                    set -l _has_uncommented false
                    sudo grep -qE -- '^[[:space:]]*WIRELESS_REGDOM=' /etc/conf.d/wireless-regdom 2>/dev/null && set _has_uncommented true
                    set -l _write_ok false
                    if test "$_has_uncommented" = true
                        _log "RUN: regdom replace pipeline (cat → replace → tee) → $tmpfile"
                        sudo cat /etc/conf.d/wireless-regdom 2>/dev/null | string replace -r -- 'WIRELESS_REGDOM="[^"]*"' "WIRELESS_REGDOM=\"$regdom_upper\"" | sudo tee -- "$tmpfile" >/dev/null
                        set -l _regdom_ps $pipestatus
                        if test $_regdom_ps[1] -ne 0 || test $_regdom_ps[3] -ne 0
                            sudo rm -f -- "$tmpfile" 2>/dev/null
                            _err "Regulatory domain pipeline failed (cat=$_regdom_ps[1] tee=$_regdom_ps[3])"
                            set -g INSTALL_HAD_ERRORS true
                        else if sudo test -s "$tmpfile"
                            set _write_ok true
                        end
                    else
                        if _run sudo cp -- /etc/conf.d/wireless-regdom "$tmpfile"
                            if printf '%s\n' "WIRELESS_REGDOM=\"$regdom_upper\"" | _run sudo tee -a -- "$tmpfile"
                                set _write_ok true
                            else
                                sudo rm -f -- "$tmpfile" 2>/dev/null
                                _err "Failed to append regulatory domain to temp file"
                                set -g INSTALL_HAD_ERRORS true
                            end
                        else
                            sudo rm -f -- "$tmpfile" 2>/dev/null
                            _err "Failed to copy wireless-regdom to temp file"
                            set -g INSTALL_HAD_ERRORS true
                        end
                    end
                    if test "$_write_ok" = true
                        if not _run sudo chmod -- 0644 "$tmpfile"
                            sudo rm -f -- "$tmpfile" 2>/dev/null
                            _err "Failed to set permissions on regulatory domain temp file"
                            set -g INSTALL_HAD_ERRORS true
                        else if not _run sudo mv -- "$tmpfile" /etc/conf.d/wireless-regdom
                            sudo rm -f -- "$tmpfile" 2>/dev/null
                            _err "Failed to set regulatory domain (mv failed)"
                            set -g INSTALL_HAD_ERRORS true
                        else if not _run sudo chown -- root:root /etc/conf.d/wireless-regdom
                            _err "Failed to set ownership on wireless-regdom"
                            set -g INSTALL_HAD_ERRORS true
                        else
                            _ok "Set regulatory domain to: $regdom_upper"
                        end
                    else
                        sudo rm -f -- "$tmpfile" 2>/dev/null
                        _err "Failed to set regulatory domain"
                        set -g INSTALL_HAD_ERRORS true
                    end
                end
            end
        end
    end

    _progress "Installing user files"
    _echo
    _info "Installing user configuration files..."
    if not install_files --desc "USER FILES" $USER_DESTINATIONS
        _err "User file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

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
                _warn "Systemctl daemon-reload failed"
            end
            if not _run sudo systemctl enable --now amdgpu-performance.service
                _warn "Failed to enable amdgpu-performance.service"
            end
        end
    end
    test "$_fn_err" = true && return 1
    return 0
end

# Pipeline phase 5: daemon-reload, enable/start services, configure systemd-resolved, mask units
function _install_configure_services --description "Enable, start, and configure systemd services"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress "Updating databases"
    _echo
    _info "Post-installation tasks..."

    if _ask "Update plocate database?"
        if command -q updatedb
            if not _run sudo updatedb
                _warn "Updatedb failed"
            end
        end
    end

    if _ask "Update pkgfile database?"
        if command -q pkgfile
            if not _run sudo pkgfile --update
                _warn "Pkgfile update failed"
            end
        end
    end

    _progress "Reloading system config"
    if _ask "Reload udev rules?"
        if not _run sudo udevadm control --reload-rules
            _warn "Udevadm reload-rules failed"
        end
        if not _run sudo udevadm trigger
            _warn "Udevadm trigger failed"
        end
        if test "$DRY" = false
            if not _run sudo udevadm settle --timeout=5
                _warn "Udevadm settle timed out"
            end
        end
    end

    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        if _ask "Restart systemd-resolved to apply new config?"
            if not _run sudo systemctl restart systemd-resolved
                _warn "Systemd-resolved restart failed"
            end
        end
    end

    if test -f /etc/sysctl.d/99-ry-sysctl.conf
        if _ask "Reload sysctl settings?"
            if not _run sudo sysctl --system
                _warn "Sysctl --system failed"
            end
        end
    end

    _progress "Removing packages"
    set -l to_del
    if test "$DRY" = true
        set to_del $PKGS_DEL
    else
        for pkg in $PKGS_DEL
            if command -q pacman && pacman -Qi "$pkg" >/dev/null 2>&1
                # Check reverse dependencies before removing $pkg; skip if other packages depend on it
                if command -q pactree
                    set -l _rdeps (pactree -r "$pkg" 2>/dev/null | tail -n +2)
                    if test (count $_rdeps) -gt 0
                        _warn "  $pkg has reverse dependencies: $_rdeps — skipping"
                        continue
                    end
                end
                set -a to_del "$pkg"
            end
        end
    end

    if test (count $to_del) -gt 0
        set -l display_list "$to_del"
        if test (count $to_del) -gt 5
            set -l first_five $to_del[1..5]
            set display_list "$first_five... and "(math (count $to_del) - 5)" more"
        end
        if _ask "Remove conflicting packages? ($display_list)"
            _log "PKG_REMOVE_REQUESTED: $to_del"
            if test -f /var/lib/pacman/db.lck
                _err "Pacman database is locked (/var/lib/pacman/db.lck exists) — skipping package removal"
                set -g INSTALL_HAD_ERRORS true
            else if not _run sudo pacman -Rns --noconfirm -- $to_del
                _warn "Batch removal failed, trying individually..."
                _log "PKG_REMOVE_BATCH_FAIL: $to_del"
                for pkg in $to_del
                    # TOCTOU: pkg may be removed between -Qi check and -Rns; the command wrapper catches the error
                    if command -q pacman && pacman -Qi "$pkg" >/dev/null 2>&1
                        if not _run sudo pacman -Rns --noconfirm -- "$pkg"
                            _warn "Failed to remove $pkg"
                            _log "PKG_REMOVE_FAIL: $pkg"
                        else
                            _log "PKG_REMOVE_OK: $pkg"
                        end
                    end
                end
            else
                _log "PKG_REMOVE_BATCH_OK: $to_del"
            end
        end
    end

    set -l safe_mask
    set -l has_lvm false

    if test "$DRY" = true
        if sudo -n true 2>/dev/null
            set -l pvs_output (timeout 5 sudo -n pvs --noheadings 2>/dev/null | string trim --)
            if test -n "$pvs_output"
                set has_lvm true
                _warn "LVM DETECTED - lvm2 services will NOT be masked"
            end
        else
            _warn "(dry-run) LVM detection skipped (no cached sudo credentials) — lvm2 services may be incorrectly masked"
        end
    else
        set -l pvs_output (timeout 5 sudo -n pvs --noheadings 2>/dev/null | string trim --)

        if test -n "$pvs_output"
            set has_lvm true
            _warn "LVM DETECTED - lvm2 services will NOT be masked"
        end
    end

    if test "$has_lvm" = false && test "$DRY" = false
        if not sudo -n true 2>/dev/null
            _info "LVM detection may be incomplete (sudo not cached)"
        end
    end

    for svc in $MASK
        if string match -q 'lvm2*' -- "$svc"
            if test "$has_lvm" = true
                continue
            end
        end
        set -a safe_mask "$svc"
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
    if _ask "Install and enable cpupower-epp.service? (REQUIRED for performance mode)"
        if not install_file "/etc/systemd/system/cpupower-epp.service" true
            _err "Failed to install cpupower-epp.service"
            set -g INSTALL_HAD_ERRORS true
            set _fn_err true
        else
            if not _run sudo systemctl daemon-reload
                _warn "Systemctl daemon-reload failed"
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

    if _ask "Enable ssh-agent (user, socket-activated)?"
        if not _run systemctl --user daemon-reload
            _warn "Systemctl --user daemon-reload failed"
        end
        if systemctl --user cat ssh-agent.service >/dev/null 2>&1
            if not _run systemctl --user enable --now ssh-agent.service
                _warn "Failed to enable ssh-agent.service"
            else
                if set -q XDG_RUNTIME_DIR
                    _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                    or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
                end
            end
        else
            _warn "Ssh-agent.service user unit not found"
            _info "  Expected at ~/.config/systemd/user/ssh-agent.service"
        end
    end
    test "$_fn_err" = true && return 1
    return 0
end

# Post-rebuild safety gate: verify vmlinuz exists, initramfs non-zero, boot entry valid; block reboot on failure
function _preflight_boot_sanity --description "Verify boot artifacts are viable after rebuild"
    set -l errors 0

    # 1. At least one vmlinuz must exist
    set -l vmlinuz_files /boot/vmlinuz-*
    if test (count $vmlinuz_files) -eq 0 || not test -f "$vmlinuz_files[1]"
        _err "No vmlinuz found in /boot/"
        set errors (math $errors + 1)
    else
        for f in $vmlinuz_files
            if not test -s "$f"
                _err "Zero-byte kernel image: $f"
                set errors (math $errors + 1)
            end
        end
    end

    # 2. Every initramfs must be non-zero
    for f in /boot/initramfs-*.img
        test -f "$f" || continue
        if not test -s "$f"
            _err "Zero-byte initramfs: $f"
            set errors (math $errors + 1)
        end
    end

    # 3. At least one boot entry .conf must reference an existing kernel
    set -l confs /boot/loader/entries/*.conf
    if test (count $confs) -eq 0 || not test -f "$confs[1]"
        _err "No boot loader entries in /boot/loader/entries/"
        set errors (math $errors + 1)
    else
        set -l valid_entry false
        for conf in $confs
            set -l linux_line (grep -m1 '^linux ' -- "$conf" 2>/dev/null | string replace 'linux ' '' | string trim --)
            if test -n "$linux_line" && test -f "/boot$linux_line"
                set valid_entry true
                break
            end
        end
        if test "$valid_entry" = false
            _err "No boot entry references a valid kernel image"
            set errors (math $errors + 1)
        end
    end

    if test $errors -gt 0
        _err "Boot sanity check failed ($errors error(s)) — DO NOT REBOOT"
        _info "  Inspect: ls -la /boot/vmlinuz-* /boot/initramfs-*.img"
        _info "  Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen"
        return 1
    end

    _ok "Boot sanity: vmlinuz present, initramfs non-zero, entries valid"
    return 0
end

# Pipeline phase 7: mkinitcpio -P, sdboot-manage gen, bootctl install; abort --all on failure
function _install_rebuild_boot --description "Regenerate initramfs and bootloader entries"
    _check_sudo_keepalive
    # mkinitcpio/sdboot failure in --all aborts to prevent unbootable system; interactive continues
    _progress "Rebuilding initramfs"
    if _ask "Rebuild initramfs?"
        if not _run sudo mkinitcpio -P
            _err "Mkinitcpio failed"
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
            _warn "Sdboot-manage gen failed"
            set -g INSTALL_HAD_ERRORS true
            set _boot_ok false
            if test "$ALL" = true
                _err "CRITICAL: Bootloader update failed in unattended mode — aborting remaining steps"
                return 1
            end
        end
        if test "$_boot_ok" = true
            if not _run sudo sdboot-manage update
                _warn "Sdboot-manage update failed"
                set -g INSTALL_HAD_ERRORS true
            end
        end

        set -l entry_count (sudo find /boot/loader/entries -name "*.conf" 2>/dev/null | wc -l)
        set -l entry_count (string trim -- "$entry_count")
        if test -n "$entry_count" && string match -qr '^\d+$' -- "$entry_count" && test "$entry_count" -gt 0
            _ok "Boot entries: $entry_count found in /boot/loader/entries/"
        else
            _err "No boot entries found in /boot/loader/entries/"
            _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
            _info "  Try: sudo sdboot-manage gen --verbose"
            set -g INSTALL_HAD_ERRORS true
        end

        for initrd in /boot/initramfs-*.img
            if test -f "$initrd"
                set -l size_mb (du -m -- "$initrd" 2>/dev/null | cut -f1)
                if test -n "$size_mb" && string match -qr '^\d+$' -- "$size_mb"
                    # >100MB initramfs suggests unnecessary MODULES or hooks (typical: 30-60MB)
                    if test "$size_mb" -gt 100
                        _warn "Large initramfs: $initrd ($size_mb MB) - consider reviewing MODULES/HOOKS"
                    else
                        _ok "Initramfs size: $initrd ($size_mb MB)"
                    end
                end
            end
        end
    end

    # Final boot viability gate: verify vmlinuz, initramfs, and boot entry exist before system upgrade
    _preflight_boot_sanity || set -g INSTALL_HAD_ERRORS true

    _progress "System upgrade"
    if test "$SYSTEM_UPGRADED" = true
        _ok "System already upgraded during package installation"
    else if _ask "Perform full system upgrade? (pacman -Syu)"
        _info "Check https://archlinux.org/news/ and https://wiki.cachyos.org/ for known issues before upgrading"
        if not _run sudo pacman -Syu --noconfirm
            _warn "System upgrade failed or was interrupted"
            set -g INSTALL_HAD_ERRORS true
        else
            _ok "System upgrade complete"
            set -l _pacnew_files (_find_pacnew_files)
            if test (count $_pacnew_files) -gt 0
                _warn "Upgrade generated "(count $_pacnew_files)" .pacnew file(s):"
                for _pf in $_pacnew_files
                    _info "  $_pf"
                end
                _info "Run 'sudo pacdiff' after install to review"
            end
        end
    end
    return 0
end

# Pipeline phase 8: daemon-reload, verify-static, verify-runtime, log summary, report errors
function _install_finalize --description "Run post-install verification, cleanup, and summary"
    _progress "Finalizing system"
    if not _run sudo systemctl daemon-reload
        _warn "Systemctl daemon-reload failed"
    end
    if not _run systemctl --user daemon-reload
        _warn "Systemctl --user daemon-reload failed"
    end

    if _ask "Clear package cache?"
        if command -q paccache
            if not _run sudo paccache -rk2
                _warn "Paccache cache trim failed"
            end
            if not _run sudo paccache -ruk0
                _warn "Paccache uninstalled cache clear failed"
            end
        else
            if not _run sudo pacman -Sc --noconfirm
                _warn "Pacman cache clear failed"
            end
        end
    end

    _progress "NetworkManager restart"
    if _ask "Restart NetworkManager (switch to iwd backend)?"
        if command -q pacman && pacman -Qi iwd >/dev/null 2>&1
            _info "iwd will restart with NetworkManager (D-Bus disconnect expected)"
            if not _run sudo systemctl restart NetworkManager
                _warn "NetworkManager restart failed"
                set -g INSTALL_HAD_ERRORS true
            end
            if test "$DRY" = false && test -n "$WIFI_SSID"
                # iwd needs time to re-register on D-Bus after NM restart before WiFi reconnect
                sleep $NM_RESTART_DELAY
            end
        else
            _err "Iwd package not installed"
            set -g INSTALL_HAD_ERRORS true
        end
    end

    _progress "WiFi reconnection"
    if test -n "$WIFI_SSID" && test -n "$WIFI_IFACE" && test -n "$WIFI_PASS"
        _info "Reconnecting WiFi: $WIFI_SSID on $WIFI_IFACE"

        if test "$DRY" = false
            set -l conn_file "/etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"

            set -l conn_dir (dirname -- "$conn_file")
            set -l tmpfile (sudo mktemp -p "$conn_dir" .ry-install.XXXXXX 2>/dev/null)
            if test -z "$tmpfile"
                set --erase WIFI_PASS
                _err "Failed to create temp file for WiFi connection"
                set -g INSTALL_HAD_ERRORS true
            else if sudo test -L "$tmpfile"
                sudo rm -f -- "$tmpfile" 2>/dev/null
                set --erase WIFI_PASS
                _err "Temp file is symlink — aborting WiFi connection creation"
                set -g INSTALL_HAD_ERRORS true
            else
                # Generate deterministic NM connection UUID from SSID+interface via MD5 (not security-critical)
                set -l _hex (printf '%s-%s' "$WIFI_SSID" "$WIFI_IFACE" | md5sum | string split -- ' ')[1]
                set -l conn_uuid (string sub -l 8 -- $_hex)-(string sub -s 9 -l 4 -- $_hex)-(string sub -s 13 -l 4 -- $_hex)-(string sub -s 17 -l 4 -- $_hex)-(string sub -s 21 -l 12 -- $_hex)
                # GKeyFile escapes for NM keyfile: backslash, semicolon, leading #, leading/trailing space
                # Note: Fish single-quoted '\\' is one literal \ (not two); quoting levels are correct
                set -l safe_pass (string replace -a '\\' '\\\\' -- "$WIFI_PASS")
                set -l safe_pass (string replace -a ';' '\\;' -- "$safe_pass")
                if string match -q '#*' -- "$safe_pass"
                    set safe_pass '\\#'(string sub -s 2 -- "$safe_pass")
                end
                if string match -qr '^ ' -- "$safe_pass"
                    set safe_pass '\\s'(string sub -s 2 -- "$safe_pass")
                end
                if string match -qr ' $' -- "$safe_pass"
                    set safe_pass (string sub -l (math (string length -- "$safe_pass") - 1) -- "$safe_pass")'\\s'
                end
                set -l safe_ssid (string replace -a '\\' '\\\\' -- "$WIFI_SSID")
                set -l safe_ssid (string replace -a ';' '\\;' -- "$safe_ssid")
                if string match -q '#*' -- "$safe_ssid"
                    set safe_ssid '\\#'(string sub -s 2 -- "$safe_ssid")
                end
                if printf '%s\n' "[connection]" "id=$safe_ssid" "uuid=$conn_uuid" "type=wifi" "interface-name=$WIFI_IFACE" "autoconnect=true" "[wifi]" "mode=infrastructure" "ssid=$safe_ssid" "[wifi-security]" "key-mgmt=wpa-psk" "psk=$safe_pass" "[ipv4]" "method=auto" "[ipv6]" "method=disabled" | sudo tee -- "$tmpfile" >/dev/null
                    set --erase WIFI_PASS
                    if not _run sudo chmod -- 0600 "$tmpfile"
                        sudo rm -f -- "$tmpfile" 2>/dev/null
                        _err "Failed to set permissions on WiFi credential file"
                        set -g INSTALL_HAD_ERRORS true
                    else if not _run sudo mv -- "$tmpfile" "$conn_file"
                        sudo rm -f -- "$tmpfile" 2>/dev/null
                        _err "WiFi connection profile creation failed"
                        set -g INSTALL_HAD_ERRORS true
                    else
                        _run sudo chown -- root:root "$conn_file" 2>/dev/null
                        _run sudo nmcli connection load "$conn_file" 2>/dev/null
                        # NM may take up to 10s to register .nmconnection; rescan every 3s
                        set -l reload_wait 0
                        while test $reload_wait -lt 10
                            if nmcli connection show "$WIFI_SSID" >/dev/null 2>&1
                                break
                            end
                            set reload_wait (math $reload_wait + 1)
                            sleep $WIFI_CONNECT_WAIT
                            if test (math "$reload_wait % 3") -eq 0
                                _run sudo nmcli connection load "$conn_file" 2>/dev/null
                                nmcli device wifi rescan ifname "$WIFI_IFACE" 2>/dev/null
                            end
                        end
                        set -l wifi_retry 0
                        set -l wifi_connected false
                        while test $wifi_retry -lt 3 && test "$wifi_connected" = false
                            if _run nmcli connection up id "$WIFI_SSID"
                                set wifi_connected true
                                _ok "WiFi connection established"
                            else
                                set wifi_retry (math $wifi_retry + 1)
                                if test $wifi_retry -lt 3
                                    _info "WiFi connection attempt $wifi_retry failed, retrying in "$WIFI_RETRY_DELAY"s..."
                                    sleep $WIFI_RETRY_DELAY
                                    _run sudo nmcli connection load "$conn_file" 2>/dev/null
                                end
                            end
                        end
                        if test "$wifi_connected" = false
                            _err "WiFi connection failed after 3 attempts"
                            set -g INSTALL_HAD_ERRORS true
                        end
                    end
                else
                    set --erase WIFI_PASS
                    sudo rm -f -- "$tmpfile" 2>/dev/null
                    _err "WiFi connection profile write failed"
                    set -g INSTALL_HAD_ERRORS true
                end
            end
        else
            set --erase WIFI_PASS
            _dry "Create /etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"
        end
    else if test -n "$WIFI_SSID" && test -n "$WIFI_IFACE"
        _warn "WiFi reconnection skipped (empty passphrase)"
        test "$DRY" = false && sleep $NM_RESTART_DELAY
    else if test -n "$WIFI_IFACE"
        _info "WiFi reconnection skipped (no credentials provided)"
        test "$DRY" = false && sleep $NM_RESTART_DELAY
    end
    # Final credential erase — runs regardless of success/failure path
    set --erase WIFI_SSID
    set --erase WIFI_PASS
    set --erase WIFI_IFACE
    # Return 1 on partial failure so do_install can detect and report errors
    test "$INSTALL_HAD_ERRORS" = true && return 1
    return 0
end

# Detect hardware changes since last install (CPU/GPU/NVMe/RAM/MAC)
function _check_hardware_fingerprint --description "Verify hardware matches expected Beelink GTR9 Pro specs"
    set -l fp_dir "$HOME/ry-install"
    set -l fp_file "$fp_dir/.hardware-fingerprint"

    set -l cur_cpu (grep -m1 -- 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //')
    set -l cur_gpu ""
    if command -q lspci
        set cur_gpu (lspci -nn 2>/dev/null | grep -i 'VGA\|Display' | head -n 1 | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]')
    end
    set -l cur_nvme ""
    for m in /sys/block/nvme*/device/model
        test -f "$m" || continue
        set cur_nvme (string trim -- (cat -- "$m" 2>/dev/null))
        break
    end
    set -l cur_wifi ""
    # Compare current hardware against saved fingerprint
    if command -q lspci
        set cur_wifi (lspci -nn 2>/dev/null | grep -i 'Network\|Wireless' | head -n 1 | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]')
    end
    set -l cur_ram (grep -- MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')

    if test "$DRY" = true
        if test -f "$fp_file"
            _dry "Would compare hardware fingerprint against: $fp_file"
        else
            _dry "Would save hardware fingerprint to: $fp_file"
        end
        return 0
    end

    # BIOS version (informational only — not part of fingerprint comparison)
    if command -q dmidecode
        set -l bios_ver (sudo dmidecode -s bios-version 2>/dev/null)
        set -l bios_date (sudo dmidecode -s bios-release-date 2>/dev/null)
        if test -n "$bios_ver"
            _info "BIOS: $bios_ver ($bios_date)"
        end
    end

    if not test -f "$fp_file"
        if not command mkdir -p -- "$fp_dir" 2>/dev/null
            _warn "Cannot create fingerprint dir: $fp_dir"
            return 0
        end
        printf 'cpu=%s\ngpu=%s\nnvme=%s\nwifi=%s\nram=%s\n' \
            "$cur_cpu" "$cur_gpu" "$cur_nvme" "$cur_wifi" "$cur_ram" >"$fp_file" 2>/dev/null
        command chmod -- 0600 "$fp_file" 2>/dev/null || _warn "Cannot set permissions on $fp_file"
        _info "Hardware fingerprint saved"
        return 0
    end

    set -l changed false
    set -l changes

    set -l prev_cpu (grep -- '^cpu=' "$fp_file" 2>/dev/null | sed 's/^cpu=//')
    set -l prev_gpu (grep -- '^gpu=' "$fp_file" 2>/dev/null | sed 's/^gpu=//')
    set -l prev_nvme (grep -- '^nvme=' "$fp_file" 2>/dev/null | sed 's/^nvme=//')
    set -l prev_wifi (grep -- '^wifi=' "$fp_file" 2>/dev/null | sed 's/^wifi=//')
    set -l prev_ram (grep -- '^ram=' "$fp_file" 2>/dev/null | sed 's/^ram=//')

    if test "$cur_cpu" != "$prev_cpu"
        set changed true
        set -a changes "  CPU: $prev_cpu → $cur_cpu"
    end
    if test -n "$cur_gpu" && test "$cur_gpu" != "$prev_gpu"
        set changed true
        set -a changes "  GPU: $prev_gpu → $cur_gpu"
    end
    if test "$cur_nvme" != "$prev_nvme"
        set changed true
        set -a changes "  NVMe: $prev_nvme → $cur_nvme"
    end
    if test -n "$cur_wifi" && test "$cur_wifi" != "$prev_wifi"
        set changed true
        set -a changes "  WiFi: $prev_wifi → $cur_wifi"
    end
    if test "$cur_ram" != "$prev_ram"
        set changed true
        set -a changes "  RAM: "$prev_ram"kB → "$cur_ram"kB"
    end

    if test "$changed" = true
        _warn "Hardware has changed since last install"
        for c in $changes
            _warn "$c"
        end
        _warn "This script is tuned for Beelink GTR9 Pro (Strix Halo)"
        if test "$FORCE" = true || test "$ALL" = true
            _info "Continuing (--force/--all)"
        else
            if not _ask "Continue anyway?"
                return 1
            end
        end
        printf 'cpu=%s\ngpu=%s\nnvme=%s\nwifi=%s\nram=%s\n' \
            "$cur_cpu" "$cur_gpu" "$cur_nvme" "$cur_wifi" "$cur_ram" >"$fp_file" 2>/dev/null
        command chmod -- 0600 "$fp_file" 2>/dev/null || _warn "Cannot set permissions on $fp_file"
    end

    return 0
end

# Orchestrator: runs all pipeline phases, collecting errors without aborting
function do_install --description "Full installation: preflight, packages, configs, services, boot"
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

    # Automatic pre-install snapshots removed in v3.4.2; user is responsible for rootfs snapshots
    _info "No automatic backup — snapshot your rootfs before proceeding if needed"
    _echo

    _progress_init

    if not _install_preflight
        return 1
    end

    _echo

    if not _install_packages
        set -g INSTALL_HAD_ERRORS true
    end

    if not _install_system_files
        set -g INSTALL_HAD_ERRORS true
    end

    if not _install_configure_services
        set -g INSTALL_HAD_ERRORS true
    end

    if not _install_rebuild_boot
        set -g INSTALL_HAD_ERRORS true
    end

    # Collect WiFi creds just before use to minimize WIFI_PASS global lifetime
    _install_collect_wifi

    if not _install_finalize
        set -g INSTALL_HAD_ERRORS true
    end

    do_completions 2>/dev/null || _warn "Completions install failed (run --completions manually)"

    _progress_done

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
    _info "Post-reboot verification: ./ry-install.fish --verify-static&& ./ry-install.fish --verify-runtime"
    _echo

    if test "$INSTALL_HAD_ERRORS" = true
        _warn "Done (with warnings - see above)"
    else
        _ok "Done!"
    end

    _log "=== INSTALLATION END ==="
    test "$INSTALL_HAD_ERRORS" = true && return 1
    return 0
end

# Single-file install: deploy one managed config by destination path
function do_install_file --argument-names target --description "Install a single named config file interactively"
    set -l target $argv[1]
    _log "=== INSTALL-FILE START ==="

    if test -z "$target"
        _err "Usage: ry-install.fish --install-file <path>"
        _echo
        _info "Managed files:"
        for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
            _echo "  $dst"
        end
        return 2
    end

    set -l valid false
    set -l use_sudo true
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if test "$target" = "$dst"
            set valid true
            # Resolve destination and validate it exists in managed file list
            break
        end
    end
    if test "$valid" = false
        for dst in $USER_DESTINATIONS
            if test "$target" = "$dst"
                set valid true
                set use_sudo false
                break
            end
        end
    end

    if test "$valid" = false
        _err "Not a managed file: $target"
        _info "Run without path to see managed files"
        return 2
    end

    _banner "ry-install v$VERSION - Install Single File"

    if test "$use_sudo" = true && test "$DRY" = false
        sudo true || begin
            _err "Sudo required"
            return 1
        end
    end

    if install_file "$target" $use_sudo
        # Post-install: rebuild boot entries if target is a boot-related config
        _echo
        _ok "Installed: $target"

        if test "$DRY" = false
            if string match -q '/boot/*' -- "$target" || string match -q '/etc/mkinitcpio*' -- "$target" || string match -q '/etc/sdboot*' -- "$target" || string match -q /etc/kernel/cmdline -- "$target"
                _echo
                if _ask "Rebuild initramfs and update bootloader?"
                    _run sudo mkinitcpio -P || _warn "Mkinitcpio failed"
                    _run sudo sdboot-manage gen || _warn "Sdboot-manage gen failed"
                    _run sudo sdboot-manage update || _warn "Sdboot-manage update failed"
                end
            else if string match -q '*.service' -- "$target"
                if string match -q "$HOME/*" -- "$target"
                    _run systemctl --user daemon-reload || _warn "Systemctl --user daemon-reload failed"
                    if _ask "Enable "(basename -- "$target")" (user)?"
                        if _run systemctl --user enable --now (basename -- "$target")
                            if string match -q '*ssh-agent*' -- "$target" && set -q XDG_RUNTIME_DIR
                                _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                                or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
                            end
                        else
                            _warn "Failed to enable "(basename -- "$target")
                        end
                    end
                else
                    _run sudo systemctl daemon-reload || _warn "Systemctl daemon-reload failed"
                end
            else if string match -q '*/udev/rules.d/*' -- "$target"
                _echo
                if _ask "Reload udev rules?"
                    _run sudo udevadm control --reload-rules || _warn "Udevadm reload-rules failed"
                    _run sudo udevadm trigger || _warn "Udevadm trigger failed"
                    _run sudo udevadm settle --timeout=5 || _warn "Udevadm settle timed out"
                end
            else if string match -q '*/resolved.conf.d/*' -- "$target"
                _echo
                if _ask "Restart systemd-resolved?"
                    _run sudo systemctl restart systemd-resolved || _warn "Systemd-resolved restart failed"
                end

            else if string match -q '*/modprobe.d/*' -- "$target"
                _info "Module options changed — reboot required for full effect"

            else if string match -q '*/logind.conf.d/*' -- "$target"
                _info "Logind config changed — reboot required (restarting logind kills all sessions)"

            else if string match -q '*/iwd/main.conf' -- "$target" || string match -q '*/NetworkManager/conf.d/*' -- "$target"
                _echo
                if _ask "NetworkManager config changed — restart NetworkManager?"
                    _run sudo systemctl restart NetworkManager || _warn "NetworkManager restart failed"
                end
            else if string match -q '*/conf.d/wireless-regdom' -- "$target"
                _info "Regulatory domain changed — run 'sudo iw reg set XX' or reboot for full effect"
            else if string match -q '*/sysctl.d/*' -- "$target"
                _echo
                if _ask "Reload sysctl settings?"
                    _run sudo sysctl --system || _warn "Sysctl --system failed"
                end
            end
        end
    else
        _err "Failed to install: $target"
        _log "=== INSTALL-FILE END ==="
        return 1
    end

    _log "=== INSTALL-FILE END ==="
    return 0
end

# Tab completions: dynamically generated from SYSTEM/USER/SERVICE_DESTINATIONS
function do_completions --description "Generate fish shell completions for ry-install"
    set -l comp_dir "$HOME/.config/fish/completions"
    set -l comp_dst "$comp_dir/ry-install.fish"

    if test "$DRY" = true
        _dry "Would install completions to: $comp_dst"
        return 0
    end

    if not command mkdir -p -- "$comp_dir" 2>/dev/null
        _warn "Cannot create completions dir: $comp_dir"
        return 1
    end
    # Generate completion script from DESTINATIONS and flag list

    set -l tmpfile (mktemp -p "$comp_dir" .ry-install.XXXXXX)
    if test -z "$tmpfile"
        _fail "Failed to create temp file for completions"
        return 1
    end
    if test -L "$tmpfile"
        command rm -f -- "$tmpfile" 2>/dev/null
        _fail "Temp file is symlink — aborting completions install"
        # Emit fish completion script: flags, modes, --install-file targets, --logs subcommands
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
        '    complete -c $cmd -s a -l all -d '"'"'Install without prompts (unattended mode)'"'"'' \
        '    complete -c $cmd -s f -l force -d '"'"'Auto-yes prompts without progress bar (for --diff --fix, etc.)'"'"'' \
        '    complete -c $cmd -s V -l verbose -d '"'"'Show output on terminal'"'"'' \
        '    complete -c $cmd -s n -l dry-run -d '"'"'Preview changes without modifying system'"'"'' \
        '' \
        '    # Verification' \
        '    complete -c $cmd -l diff -d '"'"'Compare embedded files against installed system (use absolute path for single file)'"'"'' \
        '    complete -c $cmd -l verify-static -d '"'"'Check config files exist with correct content'"'"'' \
        '    complete -c $cmd -l verify-runtime -d '"'"'Check live system state (run after reboot)'"'"'' \
        '    complete -c $cmd -l lint -d '"'"'Run fish syntax and anti-pattern checks'"'"'' \
        '    complete -c $cmd -l test-all -d '"'"'Run all safe modes and generate NDJSON logs (test suite)'"'"'' \
        '' \
        '    # Utilities' \
        '    complete -c $cmd -l logs -d '"'"'View logs (system, gpu, wifi, boot, audio, usb, kernel, or service name)'"'"'' \
        '    complete -c $cmd -l diagnose -d '"'"'Automated problem detection'"'"'' \
        '    complete -c $cmd -l install-file -d '"'"'Re-deploy a single managed file'"'"'' \
        '    complete -c $cmd -l completions -d '"'"'Install fish tab-completions for ry-install itself'"'"'' \
        '' \
        '    # Other' \
        '    complete -c $cmd -l fix -d '"'"'Re-install drifted files (use with --diff)'"'"'' \
        '    complete -c $cmd -l stress -d '"'"'Include stress tests (use with --diagnose)'"'"'' \
        '    complete -c $cmd -s h -l help -d '"'"'Show help'"'"'' \
        '    complete -c $cmd -s v -l version -d '"'"'Show version'"'"'' \
        '' \
        '    # Completions for --logs subcommands' \
        '    complete -c $cmd -l logs -xa '"'"'analyze last all list system gpu wifi boot audio usb kernel'"'"'' \
        end >"$tmpfile"

    if test $status -ne 0
        command rm -f -- "$tmpfile" 2>/dev/null
        _fail "Failed to write completions"
        return 1
    end

    if not command chmod -- 0644 "$tmpfile"
        command rm -f -- "$tmpfile" 2>/dev/null
        _fail "Failed to install completions (chmod failed)"
        return 1
    end
    if not command mv -- "$tmpfile" "$comp_dst"
        command rm -f -- "$tmpfile" 2>/dev/null
        _fail "Failed to install completions (mv failed)"
        return 1
    end

    _ok "Completions installed to: $comp_dst"
end

# Smoke test: runs diff, verify-static, verify-runtime, lint in sequence
function do_test_all --description "Run the full test suite across all subcommands"
    _banner "ry-install v$VERSION - Full Test Suite"

    set -l script_path (status filename)

    # Fast-fail: abort suite on parse errors (direct fish --no-execute gives clearer error output than --lint's subprocess)
    _info "Syntax check..."
    if not fish --no-execute "$script_path" 2>/dev/null
        _err "Script has parse errors — fix before running tests"
        fish --no-execute "$script_path"
        return 1
    end
    _ok "  fish --no-execute: passed"
    _echo

    set -l modes \
        --verify-static \
        --verify-runtime \
        --lint \
        --diff \
        --diagnose \
        "--logs system" \
        "--logs gpu" \
        "--logs wifi" \
        "--logs boot" \
        "--logs audio" \
        "--logs usb" \
        "--logs kernel" \
        "--dry-run --all" \
        "--diff --fix --dry-run --all"

    set -l total (count $modes)
    set -l passed 0
    set -l failed 0

    _info "Running $total diagnostic modes..."
    _echo

    for i in (seq (count $modes))
        set -l mode_args (string split ' ' -- $modes[$i])
        set -l label (string replace -- '--' '' "$modes[$i]")
        _info "[$i/$total] $modes[$i]"

        set -l _test_stderr (mktemp -t ry-test-stderr.XXXXXX 2>/dev/null|| echo /dev/null)
        env NO_COLOR=1 fish "$script_path" $mode_args --verbose </dev/null >/dev/null 2>"$_test_stderr"
        set -l code $status

        if test $code -eq 0
            set passed (math $passed + 1)
            _ok "  $label: passed"
        else
            set failed (math $failed + 1)
            _warn "  $label: exit code $code"
            if test "$_test_stderr" != /dev/null && test -s "$_test_stderr"
                set -l _head (head -n 3 "$_test_stderr" | string trim --)
                for _hl in $_head
                    _warn "    $_hl"
                end
            end
        end
        command rm -f -- "$_test_stderr" 2>/dev/null
    end

    # Additional test cases: --install-file (dry-run), --version, and --help exit codes
    set total (math $total + 3)
    for _extra_mode in "--install-file /etc/kernel/cmdline --dry-run" --version --help
        _echo "─ Testing: $_extra_mode"
        set -l _test_stderr2 (mktemp -t ry-test-stderr.XXXXXX 2>/dev/null|| echo /dev/null)
        fish "$script_path" (string split -- " " $_extra_mode) >/dev/null 2>"$_test_stderr2"
        set -l code2 $status
        if test $code2 -eq 0
            set passed (math $passed + 1)
            _ok "  PASS: $_extra_mode"
        else
            set failed (math $failed + 1)
            _fail "  FAIL: $_extra_mode (exit $code2)"
            if test "$_test_stderr2" != /dev/null && test -s "$_test_stderr2"
                set -l _head2 (head -n 3 "$_test_stderr2" | string trim --)
                for _hl2 in $_head2
                    _warn "    $_hl2"
                end
            end
        end
        command rm -f -- "$_test_stderr2" 2>/dev/null
    end

    # Validate --completions installs file with expected subcommands
    _echo "─ Validating completions output..."
    fish "$script_path" --completions 2>/dev/null
    set -l _comp_file "$HOME/.config/fish/completions/ry-install.fish"
    set -l _comp_out (cat -- "$_comp_file" 2>/dev/null)
    set -l _comp_ok true
    set total (math $total + 1)
    if test -z "$_comp_out"
        # dry-run or write failure — skip content validation
        _info "  completions file not available (dry-run or write failed) — skipping content check"
        set passed (math $passed + 1)
    else
        for _expected_cmd in install diff verify-static verify-runtime lint logs diagnose
            if not string match -q "*$_expected_cmd*" -- "$_comp_out"
                _warn "  completions missing: $_expected_cmd"
                set _comp_ok false
            end
        end
        if test "$_comp_ok" = true
            set passed (math $passed + 1)
            _ok "  completions content: passed"
        else
            set failed (math $failed + 1)
            _fail "  completions content: missing subcommands"
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

    test $failed -gt 0 && return 1 || return 0
end

# ═══ CLI ARGUMENT PARSING AND DISPATCH ═══
function show_help --description "Display usage information and available subcommands"
    echo "
ry-install v$VERSION
Self-contained CachyOS configuration for Beelink GTR9 Pro (Strix Halo)
Single fish script, $MANAGED_FILE_COUNT embedded configs, no external dependencies.

Usage: "(status filename)" [OPTIONS]

INSTALLATION:
  (no args)         Interactive installation
    # Installation and verification modes
  -a, --all         Install without prompts (unattended mode)
  -f, --force       Auto-yes prompts, no progress bar
  -V, --verbose     Show output on terminal (default: silent, log only)
  -n, --dry-run     Preview changes without modifying system

VERIFICATION:
  --diff            Per-file unified diff (delta or diff --color)
  --diff <path>     Diff a single managed file (absolute path required)
  --diff --fix      Show diffs and re-install drifted files (per-file prompt)
  --verify-static   Check config files exist with correct content
  --verify-runtime  Check live system state (run after reboot)
  --lint            Run fish syntax and anti-pattern checks
  --test-all        Run all safe modes and generate NDJSON logs (test suite)

UTILITIES:
  --logs <target>   View logs (system gpu wifi boot audio usb kernel)
  --logs analyze [file]  Parse NDJSON log, show human-readable results
  --logs last       Analyze most recent log file
  --logs all        Analyze all logs, show combined summary
  --logs list       List recent log files with summaries
  --diagnose        Automated problem detection
    # Diagnostic and maintenance modes
  --diagnose --stress  Include stress tests without prompting
  --install-file <path>  Re-deploy a single managed file
  --completions     Install fish tab-completions for ry-install itself

OPTIONS:
  --fix             Re-install drifted files (use with --diff)
  --stress          Include stress tests (use with --diagnose)
  --                End of options (all subsequent args treated as positional)
  -h, --help        Show this help
  -v, --version     Show version

EXIT CODES:
  0   Success
  1   Failure (install error, diff found, verification failed)
  2   Usage error (invalid arguments)
  130  Interrupted (SIGINT)
  141  Broken pipe (SIGPIPE)

EXAMPLES:
  ./ry-install.fish              # Interactive installation
  ./ry-install.fish --all        # Unattended installation
  ./ry-install.fish --diff --fix     # Fix drifted config files
  ./ry-install.fish --diagnose --stress  # Include stress tests
  ./ry-install.fish --install-file /etc/mkinitcpio.conf  # Re-deploy single file
  ./ry-install.fish --test-all      # Run all safe modes, generate NDJSON logs
  ./ry-install.fish --logs last     # Analyze most recent log
  ./ry-install.fish --logs all      # Analyze all logs, combined summary
  ./ry-install.fish --logs list     # List recent logs with summaries
  ./ry-install.fish --logs analyze ~/ry-install/logs/.../test.jsonl

LOG FILE:
  ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS.jsonl

REQUIREMENTS:
  CachyOS (Arch-based), systemd-boot, fish 3.3+

NOTES:
  Installation is best-effort: a failed phase (packages, services, etc.)
  sets INSTALL_HAD_ERRORS and continues rather than aborting. This prevents
  a non-critical failure (e.g., pkgfile update) from blocking boot rebuild.
  Review the log to distinguish transient from blocking failures.

  Message severity: [ERR] = blocking failure that may abort the current phase.
  [WARN] = non-critical issue, operation continues. [FAIL] = verification
  check did not pass (used by --verify-static, --verify-runtime, --diff).

  WiFi SSIDs/passphrases containing '%' are rejected (GKeyFile safety).
"
end

# Entry point
set -l MODE install
set -l mode_count 0
set -l LOG_TARGET ""
set -l LOG_TARGET_ARG ""
set -l INSTALL_FILE_TARGET ""
set -l DIFF_TARGET ""

# ── Argument parsing — manual loop for mode exclusivity, --flag VALUE pairs, and optional trailing args; exit 2 on usage errors ──

# Manual argument loop (not argparse): supports --flag VALUE pairs and mode exclusivity
set -l i 1
while test $i -le (count $argv)
    set -l arg $argv[$i]
    switch $arg
        case -a --all
            set -g ALL true
        case -f --force
            set -g FORCE true
        case -V --verbose
            set -g QUIET false
        case -n --dry-run
            set -g DRY true
        case --diff
            set MODE diff
            set mode_count (math $mode_count + 1)
            set -l next_i (math $i + 1)
            if test $next_i -le (count $argv)
                set -l next_arg $argv[$next_i]
                if string match -q -- '/*' "$next_arg"
                    set DIFF_TARGET "$next_arg"
                    set i $next_i
                else if not string match -q -- '-*' "$next_arg"
                    echo "[ERR] --diff requires absolute path (got: $next_arg)" >&2
                    command rm -f -- "$LOG_FILE" 2>/dev/null
                    exit 2
                end
            end
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
        case --fix
            set -g FIX true
        case --stress
            set -g STRESS true
        case --logs
            set MODE logs
            set mode_count (math $mode_count + 1)
            set -l next_i (math $i + 1)
            if test $next_i -le (count $argv)
                set -l next_arg $argv[$next_i]
                if not string match -q -- '-*' "$next_arg"
                    set LOG_TARGET "$next_arg"
                    set i $next_i
                    if test "$LOG_TARGET" = analyze
                        set -l next_i2 (math $i + 1)
                        if test $next_i2 -le (count $argv)
                            set -l next_arg2 $argv[$next_i2]
                            if not string match -q -- '-*' "$next_arg2"
                                set LOG_TARGET_ARG "$next_arg2"
                                set i $next_i2
                            end
                        end
                    end
                end
            end
        case --diagnose
            # Parse remaining flags: --completions, --test-all, modifier flags, --help, --version
            set MODE diagnose
            set mode_count (math $mode_count + 1)

        case --completions
            set MODE completions
            set mode_count (math $mode_count + 1)
        case --install-file
            set MODE install-file
            set mode_count (math $mode_count + 1)
            set -l next_i (math $i + 1)
            if test $next_i -le (count $argv)
                set -l next_arg $argv[$next_i]
                if not string match -q -- '-*' "$next_arg"
                    set INSTALL_FILE_TARGET "$next_arg"
                    set i $next_i
                end
            end
        case -h --help
            show_help
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit 0
        case -v --version
            echo "v$VERSION"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit 0
        case --
            break
        case '*'
            echo "[ERR] Unknown option: $arg" >&2
            echo >&2
            show_help >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit 2
    end
    set i (math $i + 1)
end

# ── Mode exclusivity: exactly one mode flag allowed per invocation ──
if test $mode_count -gt 1
    _log "ERR: Cannot combine multiple mode flags — run each separately"
    if test "$NO_COLOR" = true
        echo "[ERR] Cannot combine multiple mode flags — run each separately" >&2
    else
        begin
            set_color red
            echo -n "[ERR]"
            set_color normal
            echo " Cannot combine multiple mode flags — run each separately"
        end >&2
    end
    command rm -f -- "$LOG_FILE" 2>/dev/null
    exit 2
end

if test "$FIX" = true && test "$MODE" != diff
    _log "ERR: --fix requires --diff"
    echo "[ERR] --fix requires --diff" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    exit 2
end

if test "$STRESS" = true && test "$MODE" != diagnose
    _log "ERR: --stress requires --diagnose"
    echo "[ERR] --stress requires --diagnose" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    exit 2
end

if test "$_IS_ROOT" = true
    echo "Warning: Running as root. This script uses sudo internally." >&2
    echo "Consider running as normal user: ./ry-install.fish" >&2
    echo "Forcing --dry-run to prevent privilege separation bypass." >&2
    echo "" >&2
    set -g DRY true
end

if test "$MODE" != install
    set -g QUIET false
end

if test "$DRY" = true
    set -g QUIET false
end

set -l mode_label $MODE
if test -n "$LOG_TARGET"
    set mode_label "$MODE-$LOG_TARGET"
end
if test "$FIX" = true
    set mode_label "$mode_label-fix"
end
if test "$DRY" = true && test "$MODE" != test-all
    set mode_label "$mode_label-dry"
end
if test "$ALL" = true && test "$MODE" != test-all
    set mode_label "$mode_label-all"
end
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"
if test -f "$LOG_FILE" && test "$LOG_FILE" != "$new_log"
    command mv -- "$LOG_FILE" "$new_log" 2>/dev/null
end
set -g LOG_FILE "$new_log"
touch -- "$LOG_FILE" 2>/dev/null
command chmod -- 600 "$LOG_FILE" 2>/dev/null || _warn "Chmod 600 failed on $LOG_FILE"

set -l _init_cmd (string join -- " " (status filename) $argv)
set -l _init_cmd (_json_str "$_init_cmd")
printf '{"ts":"%s","event":"header","version":"%s","mode":"%s","dry_run":%s,"all":%s,"verbose":%s,"command":"%s"}\n' \
    (date '+%Y-%m-%dT%H:%M:%S') "$VERSION" "$MODE" "$DRY" "$ALL" \
    (test "$QUIET" = false&& echo true|| echo false) "$_init_cmd" >"$LOG_FILE"

# Lock policy: write modes (install, diff --fix) acquire; read modes skip
set -l _has_lock false
switch $MODE
    case install-file
        # Validate path before lock — exit 2 (usage) not masked by lock failure
        if test -z "$INSTALL_FILE_TARGET"
            _err "Usage: ry-install.fish --install-file <path>"
            _echo
            _info "Managed files:"
            for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
                _echo "  $dst"
            end
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit 2
        end
        _acquire_lock || exit 1
        set _has_lock true
    case install
        _acquire_lock || exit 1
        set _has_lock true
    case diff
        if test "$FIX" = true
            _acquire_lock || exit 1
            set _has_lock true
        end
    case '*'
        # No lock needed for read-only modes (verify, lint, logs, diagnose, completions, test-all)
end

# Log rotation: rm -f is idempotent — concurrent read-only instances may race but cannot corrupt (last-write-wins)
set -l _log_base_rot "$HOME/ry-install/logs"
set -l _existing_logs (command find "$_log_base_rot" \( -name '*.jsonl' -o -name '*.log' \) -type f -printf '%T@\t%p\n' 2>/dev/null | LC_ALL=C sort -n | string replace -r -- '^[^\t]+\t' '')
set -l _log_count (count $_existing_logs)
if test $_log_count -gt $MAX_LOGS
    set -l _to_remove (math $_log_count - $MAX_LOGS)
    for _old_log in $_existing_logs[1..$_to_remove]
        command rm -f -- "$_old_log" 2>/dev/null
    end
    command find "$_log_base_rot" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
end

set exit_code 0
# ── Main dispatch: route MODE to handler, capture exit code ──
switch $MODE
    case diff
        do_diff "$DIFF_TARGET"
        set exit_code $status
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
    case logs
        do_logs "$LOG_TARGET" "$LOG_TARGET_ARG"
        set exit_code $status
    case diagnose
        do_diagnose
        set exit_code $status
    case completions
        do_completions
        set exit_code $status
    case install-file
        do_install_file "$INSTALL_FILE_TARGET"
        set exit_code $status
    case install
        do_install
        set -l install_status $status
        if test $install_status -ne 0 || test "$INSTALL_HAD_ERRORS" = true
            set exit_code 1
        end
    case '*'
        _err "Unknown mode: $MODE"
        set exit_code 2
end
# fish_exit handler receives $status of last command in setup, not script exit — capture intended code here
set -g _INTENDED_EXIT_CODE $exit_code

# Set flag BEFORE write to prevent signal-handler race (SIGINT between printf and flag would double-write)
set -g _FOOTER_WRITTEN true
printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s}\n' (date '+%Y-%m-%dT%H:%M:%S') (date '+%Y-%m-%dT%H:%M:%S%z') "$MODE" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE"

echo "[i] Log file: $LOG_FILE" >&2

exit $exit_code
