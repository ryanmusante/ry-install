#!/usr/bin/env fish
# ry-install v3.9.2 — CachyOS config manager | Ryan Musante | MIT | Global flags below (overridden by CLI) Guard: prevent duplicate event handler registration if sourced twice in same session
set -q _RY_INSTALL_LOADED; and echo "ry-install already loaded in this session" >&2; and exit 1
set -g _RY_INSTALL_LOADED true
set -g VERSION "3.9.2"
# ── Exit codes ──
set -g EXIT_OK 0
set -g EXIT_FAIL 1
set -g EXIT_USAGE 2
set -g EXIT_PREFLIGHT 3
set -g EXIT_BOOT_CRIT 4
set -g EXIT_LOCK 5
set -g EXIT_DRIFT 10
set -g EXIT_LINT_FAIL 11
# --dry-run: simulate all mutations
set -g DRY false
# --all: auto-yes every prompt
set -g ALL false
# --force: skip confirmation prompts
set -g FORCE false
# --quiet: suppress command-wrapper stdout to terminal (auto-disabled for non-install modes)
set -g QUIET true
# Environment detection: NO_COLOR (no-color.org) — check env BEFORE setting global default set -qx tests exported (environment) variables only; avoids false positive from set -g
if set -qx NO_COLOR; or test "$TERM" = dumb
    set -g NO_COLOR true
else
    set -g NO_COLOR false
end
# --fix: auto-repair diffs found by --diff
set -g FIX false

set -g _IS_ROOT false
if test (id -u) -eq 0
    # Running as root forces --dry-run (run as normal user; uses sudo internally)
    set -g _IS_ROOT true
    set -g DRY true
end

# ── Fish version gate (3.4+ required for $() syntax, set --function, string collect --allow-empty; string collect --no-trim-newlines available since fish 3.1) ──
set -l fish_ver (string match -r -- '\d+\.\d+' (fish --version 2>&1) | head -n 1)
if test -z "$fish_ver"
    echo "Error: Could not determine fish version" >&2
    exit 1
end
set -l fish_major (string split '.' -- "$fish_ver")[1]
set -l fish_minor (string split '.' -- "$fish_ver")[2]
if test -z "$fish_major"; or not string match -qr '^\d+$' -- "$fish_major"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test -z "$fish_minor"; or not string match -qr '^\d+$' -- "$fish_minor"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    exit 1
end
if test "$fish_major" -lt 3; or begin
        test "$fish_major" -eq 3; and test "$fish_minor" -lt 4
    end
    echo "Error: fish 3.4+ required (found: $fish_ver)" >&2
    exit 1
end
# Upper bound: warn on untested fish versions — non-blocking
if test "$fish_major" -gt 4
    echo "Warning: ry-install is tested on fish 3.4-4.x; found $fish_ver — please report issues" >&2
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
    if test -z "$HOME"; or not test -d "$HOME"
        echo "Error: Cannot determine HOME directory" >&2
        exit 1
    end
end

set -g LOG_DIR "$HOME/ry-install/logs/$DATE_LABEL"
command mkdir -p -- "$LOG_DIR" 2>/dev/null; or begin
    echo "[ERR] Cannot create log directory: $LOG_DIR" >&2
    exit 1
end
command chmod -- 700 "$HOME/ry-install" 2>/dev/null; or true
set -g LOG_FILE "$LOG_DIR/install-$TIMESTAMP.jsonl"
# install -m creates file with 0600 atomically; touch fallback + chmod for systems without install(1)
command install -m 0600 /dev/null "$LOG_FILE" 2>/dev/null
or begin
    command touch -- "$LOG_FILE" 2>/dev/null
    command chmod -- 600 "$LOG_FILE" 2>/dev/null
end
set -g INSTALL_HAD_ERRORS false
set -g _TRACKED_TMPFILES

# ── Retention limits ──
set -g MAX_LOGS 50

# ── Timing constants ──
set -g SUDO_KEEPALIVE_INTERVAL 45
set -g WIFI_RETRY_DELAY 3
set -g WIFI_CONNECT_WAIT 1
set -g NM_RESTART_DELAY 3

# ── Kernel version globals for _ntsync_state ≥6.14 gate ──
set -g KVER (uname -r)
set -g KVER_PARTS (string split '.' -- $KVER)
set -g KVER_MAJOR $KVER_PARTS[1]
if not string match -qr '^\d+$' -- "$KVER_MAJOR"
    set -g KVER_MAJOR 0
end
# Strip non-numeric suffix (e.g., "14-cachyos" → "14") for numeric comparison
set -g KVER_MINOR (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[2]")
if test -z "$KVER_MINOR"; or not string match -qr '^\d+$' -- "$KVER_MINOR"
    set -g KVER_MINOR 0
end

# Lazy cache for /proc/config.gz — avoids redundant zcat across _ntsync_state and _validate_kernel_params
function _kconfig_cache --description "Return cached /proc/config.gz lines (lazy-loaded)"
    if not set -q _KCONFIG_DATA; or test (count $_KCONFIG_DATA) -eq 0
        if test -f /proc/config.gz
            set -g _KCONFIG_DATA (zcat /proc/config.gz 2>/dev/null)
        else
            set -g _KCONFIG_DATA
        end
    end
    # Guard: empty list → no output (prevents spurious empty line to grep callers)
    test (count $_KCONFIG_DATA) -eq 0; and return 0
    printf '%s\n' $_KCONFIG_DATA
end

# Return: unavailable (<6.14) | builtin (CONFIG_NTSYNC=y) | loaded | loaded_nodev | missing
function _ntsync_state --description "Return: unavailable|builtin|loaded|loaded_nodev|missing"
    _log "NTSYNC_CHECK: major=$KVER_MAJOR minor=$KVER_MINOR"
    if test "$KVER_MAJOR" -lt 6; or begin
            test "$KVER_MAJOR" -eq 6; and test "$KVER_MINOR" -lt 14
        end
        printf '%s\n' unavailable
    else if _kconfig_cache | grep -q -- '^CONFIG_NTSYNC=y'
        printf '%s\n' builtin
    else if test -c /dev/ntsync
        printf '%s\n' loaded
    else if grep -q -- '^ntsync ' /proc/modules 2>/dev/null
        printf '%s\n' loaded_nodev
    else
        printf '%s\n' missing
    end
    return 0
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
        "zswap.=CONFIG_ZSWAP" \
        "iommu=CONFIG_IOMMU_SUPPORT" \
        "amdgpu.=CONFIG_DRM_AMDGPU" \
        "workqueue.=CONFIG_WQ_POWER_EFFICIENT_DEFAULT" \
        "ttm.=CONFIG_DRM_TTM"

    set -l config_data (_kconfig_cache)
    if test -z "$config_data"
        _warn "  Failed to read /proc/config.gz"
        return 1
    end

    set -l mismatches 0
    for entry in $param_config_map
        set -l prefix (string split '=' -- "$entry")[1]
        set -l config_sym (string split '=' -- "$entry")[2]

        # Check if any KERNEL_PARAM starts with _cfg_prefix (e.g., "zswap." matches "zswap.enabled=0")
        set -l found false
        for param in $KERNEL_PARAMS
            if string match -q -- "$prefix*" "$param"
                set found true
                break
            end
        end
        test "$found" = true; or continue

        # Check if config_sym (e.g., CONFIG_AMD_PSTATE) is =y or =m in /proc/config.gz
        if not printf '%s\n' $config_data | grep -q -- "^$config_sym=[ym]"
            _warn "  $prefix* requires $config_sym but not enabled in running kernel"
            set mismatches (math $mismatches + 1)
        end
    end

    # Cap at 1: callers check boolean success/failure, not count; values >125 collide with signals
    test $mismatches -gt 0; and return 1
    return 0
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

# Emit paths of *.pacnew and *.pacsave files in /etc and /boot via elevated find
function _find_pacnew_files --description "Find pacnew/pacsave files in /etc /boot"
    if command -q sudo
        sudo -n find /etc /boot \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null
    end
end

# Parse systemd-analyze output for total boot time in seconds; return 1 if unavailable
function _get_boot_time --description "Print boot time in seconds, or return 1"
    _log "BOOT_TIME_CHECK: querying systemd-analyze"
    command -q systemd-analyze; or return 1
    set -l line (systemd-analyze 2>/dev/null | head -n 1)
    set -l sec (printf '%s\n' "$line" | string match -r -- '= ([0-9.]+)s' | tail -n 1)
    if test -n "$sec"; and string match -qr '^[0-9.]+$' -- "$sec"
        printf '%s\n' "$sec"
    else
        return 1
    end
end

# Sweep /tmp for ry-{run-stderr,run-stdout,validate,diff,argparse,test-stderr}.* owned by current UID
function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    if not set -q _FOOTER_WRITTEN
        _log "CLEANUP_TMPFILES: sweep starting"
    end
    # Skip in dry-run; stale tmpfiles from a crashed run are cleaned on next non-dry invocation.
    if test "$DRY" = true
        return 0
    end
    # Clean orphaned .ry-install.* tmpfiles from atomic writes (crash/interrupt leftovers)
    set -l sys_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if not contains -- "$dir" $sys_dirs
            set -a sys_dirs "$dir"
        end
    end
    if not contains -- /etc/NetworkManager/system-connections $sys_dirs
        set -a sys_dirs /etc/NetworkManager/system-connections
    end
    for dir in $sys_dirs
        for f in (command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f 2>/dev/null)
            if command -q sudo
                sudo -n rm -f -- "$f" 2>/dev/null
            end
        end
    end
    set -l usr_dirs
    for dst in $USER_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if not contains -- "$dir" $usr_dirs
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

# Atomic mkdir mutex with PID file; reclaims stale locks via PID liveness check; flock(1) eliminates TOCTOU race
function _acquire_lock --description "Acquire instance lock (atomic mkdir)"
    # Atomic mkdir as mutex; PID file inside enables stale-lock detection via process liveness probe
    set -g LOCK_DIR "$HOME/ry-install/.lock"
    set -g LOCK_FILE "$LOCK_DIR/pid"
    command mkdir -p -- (dirname -- "$LOCK_DIR") 2>/dev/null; or true

    if command mkdir -- "$LOCK_DIR" 2>/dev/null
        echo %self >"$LOCK_FILE"
        _log "LOCK_ACQUIRED: pid=%self dir=$LOCK_DIR"
        return 0
    end
    # LOCK_DIR exists — check if the PID inside is still alive
    set -l old_pid (command cat -- "$LOCK_FILE" 2>/dev/null)
    if test -n "$old_pid"; and string match -qr '^\d+$' -- "$old_pid"; and kill -0 -- "$old_pid" 2>/dev/null
        echo "[ERR] Another ry-install instance is running (PID $old_pid)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    # Stale lock reclaim: (a) flock(1) atomic advisory lock eliminates TOCTOU, (b) fallback rmdir+mkdir with PID re-verify
    set -l _reclaim_parent (dirname -- "$LOCK_DIR")
    if command -q flock
        # flock -n/-E 5: non-blocking, exit 5 on contention; /bin/sh inner script avoids Fish quoting; paths as positional args
        flock -n -E 5 "$_reclaim_parent" /bin/sh -c '
            rm -f -- "$1/pid" 2>/dev/null
            find "$1" -maxdepth 1 -type f -delete 2>/dev/null
            rmdir -- "$1" 2>/dev/null || true  # lint:ignore
            mkdir -- "$1" 2>/dev/null || exit 1  # lint:ignore
            echo "$2" > "$1/pid"
        ' _ "$LOCK_DIR" %self 2>/dev/null
        set -l _flock_rc $status
        if test $_flock_rc -eq 5
            echo "[ERR] Failed to reclaim stale lock — another instance is reclaiming" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        else if test $_flock_rc -ne 0
            echo "[ERR] Failed to reclaim stale lock via flock" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        end
        # flock subshell wrote its own PID; overwrite with ours
        echo %self >"$LOCK_FILE"
    else
        # Fallback: rmdir+mkdir not atomic; yield + double PID verify narrows the race window
        echo "[WARN] flock(1) not available — using non-atomic stale lock reclaim" >&2
        command rm -f -- "$LOCK_FILE" 2>/dev/null
        command find "$LOCK_DIR" -maxdepth 1 -type f -delete 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null; or true
        if not command mkdir -- "$LOCK_DIR" 2>/dev/null
            echo "[ERR] Failed to reclaim stale lock — another instance may have started" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        end
        echo %self >"$LOCK_FILE"
        # Yield to let any concurrent reclaimer finish writing, then double-verify ownership
        command sleep 0.1 2>/dev/null; or true
    end
    set -l verify_pid (command cat -- "$LOCK_FILE" 2>/dev/null)
    set -l my_pid %self
    if test "$verify_pid" != "$my_pid"
        echo "[ERR] Lock reclaim lost to concurrent instance (PID $verify_pid)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    # Second verify after yield: catches late writers that overwrote between first check and now
    set -l verify_pid2 (command cat -- "$LOCK_FILE" 2>/dev/null)
    if test "$verify_pid2" != "$my_pid"
        echo "[ERR] Lock reclaim lost to late writer (PID $verify_pid2)" >&2
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
    # _TRACKED_TMPFILES stores absolute paths (files and directories); cleanup works even if TMPDIR changed
    for _tf in $_TRACKED_TMPFILES
        if test -d "$_tf"
            command rm -rf --preserve-root -- "$_tf" 2>/dev/null
        else if test -f "$_tf"
            command rm -f -- "$_tf" 2>/dev/null
        end
    end
    set --erase _TRACKED_TMPFILES
    # Fallback sweep: find -user $_MY_UID catches ry-* tmpfiles missed by the tracked list (e.g., crash before tracking)
    set -l _tmpdir (set -q TMPDIR; and echo "$TMPDIR"; or echo /tmp)
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type f -user $_MY_UID -delete 2>/dev/null
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type d -empty -user $_MY_UID -delete 2>/dev/null
    # Credential erase on every exit path — defense-in-depth against WIFI_PASS lingering in memory
    set --erase WIFI_PASS
    # Free cached data (harmless but consistent with cleanup discipline)
    set --erase _KCONFIG_DATA
    # Release LOCK_DIR mutex — verify PID ownership first (LOCK_DIR global is set before mkdir; on failure we don't own it)
    if set -q LOCK_DIR; and test -d "$LOCK_DIR"
        set -l _lock_pid (command cat -- "$LOCK_DIR/pid" 2>/dev/null)
        set -l _my_pid %self
        if test "$_lock_pid" = "$_my_pid"
            command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
        end
    end
    _kill_sudo_keepalive
end

# Send SIGTERM to the background credential-refresh loop started during install preflight
function _kill_sudo_keepalive --description "Terminate the background sudo credential refresh loop"
    if set -q SUDO_KEEPALIVE_PID; and test -n "$SUDO_KEEPALIVE_PID"
        command kill -- $SUDO_KEEPALIVE_PID 2>/dev/null
        set --erase SUDO_KEEPALIVE_PID
    end
end

# Warn if credential keepalive has died — check before critical privileged operations
function _check_sudo_keepalive --description "Warn if sudo keepalive has expired"
    if set -q SUDO_KEEPALIVE_PID; and test -n "$SUDO_KEEPALIVE_PID"
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
# _cleanup (signals) writes footer + exit 128+signum; _cleanup_on_exit (fish_exit) is fallback — _CLEANUP_DONE prevents double-run
function _cleanup --on-signal INT --on-signal TERM --on-signal HUP --on-signal QUIT --description "Signal handler: clean up on INT/TERM/HUP/QUIT"
    echo "" >&2
    echo "[WARN] Interrupted - cleaning up..." >&2
    set -g _CLEANUP_DONE true
    # Fish passes signal name WITHOUT "SIG" prefix as $argv[1] (e.g., "INT", not "SIGINT")
    set -l _sig_exit 130
    switch "$argv[1]"
        case HUP
            set _sig_exit 129
        case INT
            set _sig_exit 130
        case QUIT
            set _sig_exit 131
        case TERM
            set _sig_exit 143
    end
    if not set -q _FOOTER_WRITTEN; and set -q LOG_FILE; and test -n "$LOG_FILE"; and test -f "$LOG_FILE"
        set -l _mode_esc (_json_str "$MODE")
        printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s,"interrupted":true}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (date '+%Y-%m-%dT%H:%M:%S%z') "$_mode_esc" "$_sig_exit" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE"
    end
    _do_cleanup
    exit $_sig_exit
end

# SIGPIPE handler: skip stderr (pipe broken), write JSONL footer, run _do_cleanup, exit 141
function _cleanup_pipe --on-signal PIPE --description "Signal handler: clean up on SIGPIPE (broken pipe)"
    # SIGPIPE: stderr may also be broken — skip all terminal output
    set -g _CLEANUP_DONE true
    if not set -q _FOOTER_WRITTEN; and set -q LOG_FILE; and test -n "$LOG_FILE"; and test -f "$LOG_FILE"
        set -l _mode_esc (_json_str "$MODE")
        printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":141,"pass":%s,"fail":%s,"warn":%s,"interrupted":true}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (date '+%Y-%m-%dT%H:%M:%S%z') "$_mode_esc" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE" 2>/dev/null
    end
    _do_cleanup
    exit 141
end

# fish_exit fallback: ensures cleanup runs if no signal handler fired; respects _CLEANUP_DONE guard
function _cleanup_on_exit --on-event fish_exit --description "Exit handler: ensure cleanup runs on fish_exit"
    set -l _exit_status $status
    if set -q _INTENDED_EXIT_CODE
        # Re-bind the function-local; bare set (no -l) targets enclosing function scope
        set _exit_status $_INTENDED_EXIT_CODE
    end
    if test "$_CLEANUP_DONE" = true
        return 0
    end
    if not set -q _FOOTER_WRITTEN; and set -q LOG_FILE; and test -n "$LOG_FILE"; and test -f "$LOG_FILE"
        set -l _mode_esc (_json_str "$MODE")
        printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s,"cleanup_exit":true}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (date '+%Y-%m-%dT%H:%M:%S%z') "$_mode_esc" "$_exit_status" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE"
    end
    _do_cleanup
end

# ═══ PROFILES — machine-specific configuration ═══

function _ry_profile_gtr9_pro --description "Beelink GTR9 Pro (Strix Halo)"
    # ── Identity ──
    set -g PROFILE_NAME gtr9_pro
    set -g PROFILE_DESC "Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S"

    # ── Managed file destinations — 1:1 map to _ry_get_file_content(); system=0644, user=0600 ──
    set -g SYSTEM_DESTINATIONS \
        "/boot/loader/loader.conf" \
        /etc/kernel/cmdline \
        "/etc/sdboot-manage.conf" \
        "/etc/mkinitcpio.conf" \
        "/etc/udev/rules.d/99-cachyos-udev.rules" \
        "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
        "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
        "/etc/iwd/main.conf" \
        "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
        /etc/drirc

    set -g USER_DESTINATIONS \
        "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" \
        "$HOME/.config/environment.d/10-environment.conf" \
        "$HOME/.config/systemd/user/ssh-agent.service"

    set -g SERVICE_DESTINATIONS \
        "/etc/systemd/system/amdgpu-performance.service" \
        "/etc/systemd/system/cpupower-epp.service"

    # ── Boot ──
    set -g LOADER_DEFAULT "@saved"
    set -g LOADER_TIMEOUT 0
    set -g LOADER_CONSOLE_MODE keep
    set -g LOADER_EDITOR no
    set -g SDBOOT_OVERWRITE yes
    # REMOVE_EXISTING=yes deletes ALL boot entries before regen — manual entries (rescue, Windows) will be lost
    set -g SDBOOT_REMOVE_EXISTING yes
    set -g SDBOOT_REMOVE_OBSOLETE yes

    # Kernel (15 params) ppfeaturemask=0xfffd3fff: bits 14,15,17 off (overdrive/GFXOFF/stutter). cwsr_enable=0: gfx1151 workaround (remove 6.18+) wbrf=0: disable WiFi RFI memory clock throttling (P1 — devastating for UMA bandwidth). clocksource=tsc: force TSC on Zen 5 (P2) module_blacklist: pcspkr (beep) + wdat_wdt (ACPI watchdog, complements nowatchdog). CachyOS covers iTCO/sp5100 only
    set -g KERNEL_PARAMS \
        amdgpu.cwsr_enable=0 \
        amdgpu.ppfeaturemask=0xfffd3fff \
        amdgpu.wbrf=0 \
        clocksource=tsc \
        initcall_blacklist=simpledrm_platform_driver_init \
        iommu=pt \
        module_blacklist=pcspkr,wdat_wdt \
        mt7925e.disable_aspm=1 \
        nowatchdog \
        nvme_core.default_ps_max_latency_us=0 \
        nvme_core.multipath=N \
        quiet \
        usbcore.autosuspend=-1 \
        workqueue.power_efficient=0 \
        zswap.enabled=0

    # ── Initramfs ──
    set -g MKINITCPIO_MODULES amdgpu nvme
    # systemd hooks — no resume hook (targets masked)
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

    # ── Udev ──
    set -g UDEV_RULES \
        'KERNEL=="ntsync", MODE="0666"'

    # ── Network ──
    set -g RESOLVED_MDNS no
    set -g LOGIND_IGNORE_KEYS \
        HandlePowerKey \
        HandlePowerKeyLongPress \
        HandleSuspendKey \
        HandleSuspendKeyLongPress \
        HandleHibernateKey \
        HandleHibernateKeyLongPress \
        HandleRebootKey \
        HandleRebootKeyLongPress
    set -g IWD_ENABLE_NETWORK_CONFIG false
    set -g IWD_DRIVER_QUIRKS "DefaultInterface=*" "PowerSaveDisable=*"
    set -g IWD_DNS_SERVICE systemd
    set -g NM_WIFI_BACKEND iwd
    set -g NM_WIFI_POWERSAVE 2
    set -g NM_LOG_LEVEL WARN

    # ── Environment ──
    set -g ENV_VARS \
        "DXVK_LOG_LEVEL=none" \
        "ENABLE_LAYER_MESA_ANTI_LAG=1" \
        "MESA_SHADER_CACHE_MAX_SIZE=8G" \
        "PROTON_USE_NTSYNC=1" \
        "PROTON_NO_WM_DECORATION=1"

    # ── Packages ──
    set -g PKGS_ADD mkinitcpio-firmware nvme-cli iw cachyos-gaming-meta cachyos-gaming-applications fd sd dust procs bottom git-delta lm_sensors
    set -g PKGS_DEL plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme ufw octopi micro cachyos-micro-settings btop

    # ── Services ──
    set -g MASK \
        ananicy-cpp.service \
        power-profiles-daemon.service \
        lvm2-monitor.service \
        NetworkManager-wait-online.service \
        sleep.target \
        suspend.target \
        hibernate.target \
        hybrid-sleep.target \
        suspend-then-hibernate.target \
        systemd-zram-setup@zram0.service
    set -g EXPECTED_SERVICES amdgpu-performance.service cpupower-epp.service fstrim.timer NetworkManager.service

    # ── Thresholds ──
    set -g BOOT_SPACE_CRIT 200
    set -g BOOT_SPACE_WARN 500
    set -g ROOT_AVAIL_CRIT 2
    set -g ROOT_AVAIL_WARN 5
    set -g BOOT_TIME_TARGET 15

    # ── Hardware expectations (optional) ──
    set -g EXPECTED_CPU_MATCH "Ryzen AI Max"
    return 0
end

# ═══ PROFILE LOADER ═══

function _validate_profile --description "Verify loaded profile has all required globals" --argument-names expected_name
    if test (count $argv) -gt 1
        _err "_validate_profile: expected 0-1 args (expected_name), got "(count $argv)
        return 1
    end
    set -l required \
        PROFILE_NAME \
        PROFILE_DESC \
        KERNEL_PARAMS \
        SYSTEM_DESTINATIONS \
        USER_DESTINATIONS \
        SERVICE_DESTINATIONS \
        PKGS_ADD \
        MASK \
        MKINITCPIO_MODULES \
        MKINITCPIO_HOOKS \
        MKINITCPIO_COMPRESSION \
        LOADER_DEFAULT \
        LOADER_TIMEOUT \
        LOADER_CONSOLE_MODE \
        LOADER_EDITOR \
        SDBOOT_OVERWRITE \
        SDBOOT_REMOVE_EXISTING \
        SDBOOT_REMOVE_OBSOLETE \
        EXPECTED_SERVICES \
        ENV_VARS \
        LOGIND_IGNORE_KEYS \
        BOOT_SPACE_CRIT \
        BOOT_SPACE_WARN \
        ROOT_AVAIL_CRIT \
        ROOT_AVAIL_WARN

    # Intentionally optional (consumers handle unset safely): PKGS_DEL, BOOT_TIME_TARGET, EXPECTED_CPU_MATCH

    # Conditionally required — needed only when profile includes corresponding destinations
    for dst in $SYSTEM_DESTINATIONS
        switch "$dst"
            case '*/iwd/*' '*/nm.conf'
                for nw_var in IWD_ENABLE_NETWORK_CONFIG IWD_DNS_SERVICE IWD_DRIVER_QUIRKS NM_WIFI_BACKEND NM_WIFI_POWERSAVE NM_LOG_LEVEL
                    if not contains -- $nw_var $required
                        set -a required $nw_var
                    end
                end
            case '*/resolved.conf.d/*'
                if not contains -- RESOLVED_MDNS $required
                    set -a required RESOLVED_MDNS
                end
            case '*/udev/rules.d/*'
                if not contains -- UDEV_RULES $required
                    set -a required UDEV_RULES
                end
        end
    end

    set -l missing
    for var_name in $required
        if not set -q $var_name
            set -a missing $var_name
        else
            set -l val $$var_name
            if test (count $val) -eq 0
                set -a missing $var_name
            end
        end
    end

    if test (count $missing) -gt 0
        _err "Profile missing required globals: $missing"
        return 1
    end

    # Verify PROFILE_NAME matches the function that was called
    if test -n "$expected_name"; and test "$PROFILE_NAME" != "$expected_name"
        _err "Profile function _ry_profile_$expected_name set PROFILE_NAME='$PROFILE_NAME' (expected '$expected_name')"
        return 1
    end

    # Type-check numeric globals
    for num_var in LOADER_TIMEOUT \
        BOOT_SPACE_CRIT BOOT_SPACE_WARN ROOT_AVAIL_CRIT \
        ROOT_AVAIL_WARN BOOT_TIME_TARGET
        if set -q $num_var
            set -l val $$num_var
            if not string match -qr '^\d+$' -- "$val"
                _err "Profile global $num_var must be numeric (got '$val')"
                return 1
            end
        end
    end

    return 0
end

# Resolve profile name (default-file → gtr9_pro), load function, cache root UUID, check orphans
function _load_profile --description "Determine, load, and validate the active profile"
    # 1. Determine name
    set -l name
    set -l default_file "$HOME/.config/ry-install/default-profile"
    if test -f "$default_file"
        set name (string trim < "$default_file")
    end
    if test -z "$name"
        set name gtr9_pro
    end

    # 2. Validate name format
    if not string match -qr '^[a-z0-9][a-z0-9_-]*$' -- "$name"
        _err "Invalid profile name: '$name' (must be lowercase alphanumeric, starting with [a-z0-9])"
        command rm -f -- "$LOG_FILE" 2>/dev/null
        exit $EXIT_USAGE
    end

    # 3. Load profile function
    set -l profile_dir "$HOME/.config/ry-install/profiles"
    set -l profile_path "$profile_dir/$name.fish"

    if functions -q "_ry_profile_$name"
        _ry_profile_$name
    else if test -f "$profile_path"
        if not fish --no-execute "$profile_path" 2>/dev/null
            _err "Profile file has syntax errors: $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit $EXIT_USAGE
        end
        source "$profile_path"
        if functions -q "_ry_profile_$name"
            _ry_profile_$name
        else if functions -q "profile_$name"
            # Backward compatibility: accept old profile_<name> convention with deprecation warning
            _warn "Profile uses deprecated naming: profile_$name → rename to _ry_profile_$name"
            profile_$name
        else
            _err "Profile file does not define function _ry_profile_$name: $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit $EXIT_USAGE
        end
    else
        _err "Unknown profile: $name"
        command rm -f -- "$LOG_FILE" 2>/dev/null
        exit $EXIT_USAGE
    end

    # 4. Validate
    if not _validate_profile "$name"
        command rm -f -- "$LOG_FILE" 2>/dev/null
        exit $EXIT_USAGE
    end

    # 5. Derived globals
    set -g MANAGED_FILE_COUNT (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)

    # 6. Cache root UUID — findmnt called once here; eliminates TOCTOU between _ry_install_file's comparison and write paths
    set -g _ROOT_UUID (findmnt -no UUID / 2>/dev/null)
    if test -z "$_ROOT_UUID"
        _warn "Cannot detect root UUID (findmnt failed) — /etc/kernel/cmdline generation will fail"
    end

    # 7. Lightweight hardware sanity — /proc/cpuinfo only, no lspci/sudo
    if set -q EXPECTED_CPU_MATCH; and test -n "$EXPECTED_CPU_MATCH"
        set -l _cpu_model (grep -m1 -- 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //')
        if test -n "$_cpu_model"; and not string match -q -- "*$EXPECTED_CPU_MATCH*" "$_cpu_model"
            _warn "Profile '$name' expects $EXPECTED_CPU_MATCH but detected: $_cpu_model"
            _warn "  Wrong machine? Create ~/.config/ry-install/default-profile"
        end
    end
end

# ═══ MANIFEST — orphan tracking across versions and profile switches ═══

set -g MANIFEST_FILE "$HOME/ry-install/.manifest"

# Write manifest: version, profile, and all managed destinations (one per line)
function _manifest_write --description "Record current profile destinations for orphan detection"
    if test "$DRY" = true
        _log "MANIFEST_SKIP: dry-run"
        return 0
    end
    # Create tmpfile in same directory as manifest for same-filesystem atomic mv
    set -l manifest_dir (dirname -- "$MANIFEST_FILE")
    set -l tmp (mktemp -p "$manifest_dir" .ry-install.manifest.XXXXXX 2>/dev/null)
    if test -z "$tmp"
        _warn "Failed to write manifest (mktemp failed)"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$tmp"
    printf '%s\n' "v$VERSION" "$PROFILE_NAME" $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS >"$tmp"
    command chmod -- 600 "$tmp"
    command mv -f -- "$tmp" "$MANIFEST_FILE" 2>/dev/null
    or begin
        command rm -f -- "$tmp" 2>/dev/null
        _warn "Failed to write manifest"
        return 1
    end
    _log "MANIFEST_WRITTEN: $MANIFEST_FILE ($MANAGED_FILE_COUNT destinations)"
    return 0
end

# Check for orphaned files: destinations in previous manifest not in current profile
function _manifest_check_orphans --description "Warn about files from previous install/profile not in current destinations"
    if not test -f "$MANIFEST_FILE"
        return 0
    end
    set -l manifest_lines (command cat -- "$MANIFEST_FILE" 2>/dev/null)
    if test (count $manifest_lines) -lt 3
        return 0
    end
    set -l prev_ver "$manifest_lines[1]"
    set -l prev_profile "$manifest_lines[2]"
    set -l prev_dests $manifest_lines[3..]
    set -l current_dests $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS

    set -l orphans
    for prev in $prev_dests
        if not contains -- "$prev" $current_dests
            set -a orphans "$prev"
        end
    end

    if test (count $orphans) -gt 0
        if test "$prev_profile" != "$PROFILE_NAME"
            _warn "Profile changed: $prev_profile → $PROFILE_NAME"
        else
            _warn "Destinations changed since $prev_ver"
        end
        for orphan in $orphans
            _warn "  ORPHAN: $orphan (no longer managed)"
        end
        _info "  Review and remove orphaned files manually"
    end
    return 0
end

# Generate config file content by destination path — INVARIANT: content emitted via printf/echo only, NEVER eval'd
function _ry_get_file_content --argument-names dst --description "Return embedded config content for a given destination path"
    if test (count $argv) -ne 1
        _err "_ry_get_file_content: expected 1 argument, got "(count $argv)
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
            if test -z "$_ROOT_UUID"
                _err "_ry_get_file_content: root UUID not cached (_load_profile may not have run)"
                return 1
            end
            printf '%s\n' "rw root=UUID=$_ROOT_UUID "(string join -- " " $KERNEL_PARAMS)

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

        case "/etc/udev/rules.d/99-cachyos-udev.rules"
            printf '%s\n' "# udev rules"
            for rule in $UDEV_RULES
                printf '%s\n' "$rule"
            end

        case "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf"
            printf '%s\n' "# systemd-resolved configuration"
            printf '%s\n' "[Resolve]"
            printf '%s\n' "MulticastDNS=$RESOLVED_MDNS"
            printf '%s\n' "DNSOverTLS=opportunistic"
            printf '%s\n' "DNSSEC=allow-downgrade"

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
                printf '%s\n' "$quirk"
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

        case "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"
            printf '%s\n' '# SSH agent socket for fish shell -- priority: forwarded > gcr > systemd
if status is-interactive; and set -q XDG_RUNTIME_DIR; and not set -q SSH_CONNECTION
    if test -S "$XDG_RUNTIME_DIR/gcr/ssh"
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"
    else if test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
    end
end'

        case "$HOME/.config/environment.d/10-environment.conf"
            printf '%s\n' "# Environment variables for systemd user services and graphical sessions"
            printf '%s\n' "# Loaded by systemd --user (COSMIC, Flatpak, D-Bus activated apps)"
            printf '%s\n' 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket'
            for var in $ENV_VARS
                printf '%s\n' "$var"
            end

            # Custom unit preferred over Arch openssh ≥9.4p1-3: adds Restart=on-failure, survives package upgrades
        case "$HOME/.config/systemd/user/ssh-agent.service"
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
            # After=multi-user.target for DRM settle (Arch #72655); ExecStart: 5 retries, 2s delay, exit 1 if no writable sysfs "auto" not "high": shared-TDP APU wastes CPU headroom at fixed max; GameMode sets "high" dynamically when gaming
            printf '%s\n' '[Unit]' \
                'Description=Set AMDGPU power_dpm_force_performance_level to auto' \
                'After=multi-user.target' \
                'ConditionPathIsDirectory=/sys/class/drm' \
                '' \
                '[Service]' \
                'Type=oneshot' \
                'RemainAfterExit=yes' \
                'ExecStart=/usr/bin/bash -c '\''shopt -s nullglob; retries=5; delay=2; written=0; for attempt in $(seq 1 $retries); do for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do [ -f "$f" ] && [ -w "$f" ] && { echo auto > "$f" && written=$((written+1)); }; done; [ "$written" -gt 0 ] && break; [ "$attempt" -lt "$retries" ] && sleep $delay; done; [ "$written" -gt 0 ]'\''' \
                '' \
                '[Install]' \
                'WantedBy=graphical.target'

        case "/etc/systemd/system/cpupower-epp.service"
            # Tradeoff: permanent EPP=performance + masks power-profiles-daemon. This breaks CachyOS game-performance wrapper + PPD integration (auto EPP/sched-ext switching). Alternative: unmask PPD, remove this service, use powerprofilesctl for dynamic switching.
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

        case /etc/drirc
            # RADV unified VRAM heap: prevents games from misallocating via artificial two-heap split on UMA APUs
            printf '%s\n' '<driconf>' \
                '  <device>' \
                '    <application name="Default">' \
                '      <option name="radv_enable_unified_heap_on_apu"' \
                '              value="true" />' \
                '    </application>' \
                '  </device>' \
                '</driconf>'

        case '*'
            return 1
    end
    return 0
end

# ═══ BATCH & PARALLEL PREREQUISITES ═══

function _pregenerate_content_files --argument-names out_dir --description "Write all expected-content files to a tmpdir (prereq for parallel consumers)"
    if test (count $argv) -gt 1
        _err "_pregenerate_content_files: expected 0-1 args (out_dir), got "(count $argv)
        return 1
    end
    # Must run after _load_profile — needs profile globals for _ry_get_file_content
    if test -z "$out_dir"
        set out_dir (mktemp -d -t ry-content.XXXXXX)
    end
    if not test -d "$out_dir"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$out_dir"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l safe (string replace -a '/' '_' -- "$dst")
        _ry_get_file_content "$dst" >"$out_dir/$safe" 2>/dev/null
        or _log "CONTENT_GEN_FAIL: dst=$dst"
    end
    printf '%s\n' "$out_dir"
    return 0
end

# Pre-cache sudo credential once before forking parallel children (prevents N concurrent prompts)
function _ensure_sudo_cached --description "Cache sudo credential once before parallel forking"
    if not command -q sudo
        _err "Sudo credential cache failed: sudo not found"
        return 1
    end
    set -l _sudo_err (mktemp -t ry-sudo-err.XXXXXX 2>/dev/null; or echo /dev/null)
    test "$_sudo_err" != /dev/null; and set -ga _TRACKED_TMPFILES "$_sudo_err"
    # Avoid "if not sudo true" — Fish "not" can silently invert status; explicit capture is safe
    sudo true 2>"$_sudo_err"
    set -l _rc $status
    if test $_rc -ne 0
        set -l _reason (command head -n 1 "$_sudo_err" 2>/dev/null)
        command rm -f -- "$_sudo_err" 2>/dev/null
        _log "SUDO_CACHE_FAIL: $_reason"
        if test -n "$_reason"
            _err "Sudo credential cache failed: $_reason"
        else
            _err "Sudo credential cache failed"
        end
        return 1
    end
    command rm -f -- "$_sudo_err" 2>/dev/null
    return 0
end

# Parse multi-record systemctl show output into LoadState:ActiveState:UnitFileState lines
function _parse_systemctl_show --argument-names raw_output --description "Parse multi-record systemctl show output into unit:ActiveState:UnitFileState lines"
    if test (count $argv) -ne 1
        _err "_parse_systemctl_show: expected 1 arg (raw_output), got "(count $argv)
        return 1
    end
    # systemctl show outputs records separated by blank lines; each record has key=value pairs
    set -l current_active ""
    set -l current_unitfile ""
    set -l current_load ""
    for line in (string split -- \n "$raw_output")
        if test -z "$line"
            # End of record — emit only if at least one property was accumulated (guards against leading blank lines)
            if test -n "$current_active"; or test -n "$current_unitfile"; or test -n "$current_load"
                printf '%s\n' "$current_load:$current_active:$current_unitfile"
            end
            set current_active ""
            set current_unitfile ""
            set current_load ""
            continue
        end
        switch "$line"
            case 'ActiveState=*'
                set current_active (string replace -- 'ActiveState=' '' "$line")
            case 'UnitFileState=*'
                set current_unitfile (string replace -- 'UnitFileState=' '' "$line")
            case 'LoadState=*'
                set current_load (string replace -- 'LoadState=' '' "$line")
        end
    end
    # Emit final record if no trailing blank line
    if test -n "$current_active"; or test -n "$current_unitfile"; or test -n "$current_load"
        printf '%s\n' "$current_load:$current_active:$current_unitfile"
    end
end

# ═══ LOGGING, MESSAGE OUTPUT, AND VERIFICATION COUNTERS ═══

# Escape string for JSON embedding; function-scope reassignments use explicit set -l
function _json_str --description "Escape a string for safe JSON embedding"
    if test (count $argv) -ne 1
        _log "BUG: _json_str: expected 1 arg, got "(count $argv)
        printf '\n'
        return 1
    end
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
    set -l val (string replace -ra '[\x01-\x07\x0b\x0e-\x1f\x7f\x80-\x9f]' '?' -- "$val")
    # printf '%s\n' ensures set -l val (...) captures one element even when $val is empty; '%s' alone yields zero
    printf '%s\n' "$val"
end

# GKeyFile escape for NM .nmconnection: backslash, tab, newline, semicolon, leading #, leading/trailing space
function _gkeyfile_escape --argument-names raw --description "Escape a string for GKeyFile (NM keyfile) format"
    if test (count $argv) -ne 1
        _err "_gkeyfile_escape: expected 1 arg (raw), got "(count $argv)
        return 1
    end
    set -l val (string replace -a '\\' '\\\\' -- "$raw")
    set -l val (string replace -a \t '\\t' -- "$val")
    set -l val (string replace -a \n '\\n' -- "$val")
    set -l val (string replace -a ';' '\\;' -- "$val")
    if string match -q '#*' -- "$val"
        set val '\\#'(string sub -s 2 -- "$val")
    end
    if string match -qr '^ ' -- "$val"
        set val '\\s'(string sub -s 2 -- "$val")
    end
    if string match -qr ' $' -- "$val"
        set val (string sub -l (math (string length -- "$val") - 1) -- "$val")'\\s'
    end
    printf '%s\n' "$val"
end

# Extract "data" field value from a JSONL line, handling escaped quotes PCRE2: [^"\\] matches non-quote non-backslash; \\. matches escaped char Fish single-quotes process \\ → \ and \' → ' (NOT fully literal like bash) So source \\\\ → fish \\ → PCRE2 escaped-backslash
function _jsonl_data --description "Extract data field from JSONL line"
    if test (count $argv) -ne 1
        return 1
    end
    string match -r --groups-only -- '"data":"((?:[^"\\\\]|\\\\.)*)\"' "$argv[1]"
end

# ── Structured NDJSON logging — self-contained JSON per line, event classification (section/prefix/message), _json_str escapes+caps at 4096 chars ──

# Append JSONL event to LOG_FILE with ISO timestamp
function _log --description "Append a timestamped message to the log file"
    # Guard: do not recreate LOG_FILE if it was intentionally deleted (e.g. _acquire_lock contention)
    test -f "$LOG_FILE"; or return 0
    set -l _ts (date '+%Y-%m-%dT%H:%M:%S%z')
    set -l raw (string join -- " " $argv)
    # Inside if/else, bare set (no -l) re-binds outer event/data at function scope
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
    # Cap $data at 4096 chars; step back from cut point if inside a JSON escape sequence to avoid malformed output
    if test (string length -- "$data") -gt 4096
        set -l cut 4093
        # Step back from cut point if inside a backslash escape (≥8 char window catches \\uXXXX)
        set -l tail3 (string sub -s (math $cut - 7) -l 8 -- "$data")
        set -l _esc_match (string match -r '\\\\[tnrbfu]?[0-9a-fA-F]{0,4}$' -- "$tail3" | head -n 1)
        if test -n "$_esc_match"
            set -l _esc_len (string length -- "$_esc_match")
            if test "$_esc_len" -gt 0
                set cut (math $cut - $_esc_len)
            end
        end
        set data (string sub -l $cut -- "$data")"..."
    end
    printf '{"ts":"%s","event":"%s","data":"%s"}\n' "$_ts" "$event" "$data" >>"$LOG_FILE"
end

# Format and emit a leveled [LEVEL] message to stderr; respects NO_COLOR and logs to JSONL
function _msg --argument-names level --description "Format and print a leveled status message"
    if test (count $argv) -lt 2
        if test (count $argv) -eq 0
            echo "[BUG] _msg: expected at least 2 args (level message), got 0" >&2
        else
            echo "[BUG] _msg: expected at least 2 args (level message), got 1 (level='$argv[1]')" >&2
        end
        return 1
    end
    set -l valid_levels INFO WARN ERR FAIL OK DRY
    if not contains -- "$level" $valid_levels
        echo "[BUG] _msg called with invalid level: '$level'" >&2
        printf '{"ts":"%s","event":"bug","data":"_msg called with invalid level: %s"}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (_json_str "$level") >>"$LOG_FILE"
        set level ERR
    end
    # Route level to JSONL event + increment verify counters for summary
    set -l msg (string join -- " " $argv[2..])
    _log "$level: $msg"
    if set -q VERIFY_MODE; and test "$VERIFY_MODE" = true
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
        if test "$NO_COLOR" = true; or not isatty 2
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

# Print the boxed ry-install header with mode title; suppressed by QUIET flag
function _banner --argument-names text --description "Print the ry-install startup banner"
    if test (count $argv) -lt 1
        return 0
    end
    set -l border "┌──────────────────────────────────────────────────────────────────┐"
    set -l bottom "└──────────────────────────────────────────────────────────────────┘"
    set -l inner 66
    set -l prefix "│  "
    set -l suffix " │"
    set -l max_text (math "$inner - 5")
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

    # Snapshot counters and disable VERIFY_MODE before _fail/_warn/_ok to keep CI line and JSONL footer in sync
    set -l snap_ok $VERIFY_OK
    set -l snap_fail $VERIFY_FAIL
    set -l snap_warn $VERIFY_WARN
    set -g VERIFY_MODE false

    set -l summary "Results: $snap_ok OK"
    if test "$snap_warn" -gt 0
        set summary "$summary, $snap_warn WARN"
    end
    if test "$snap_fail" -gt 0
        set summary "$summary, $snap_fail FAIL"
    end

    if test "$snap_fail" -gt 0
        _fail "$summary"
        # CI-friendly: emit machine-parseable summary to stdout (all other output is stderr)
        echo "VERIFY:FAIL:$snap_ok:$snap_fail:$snap_warn"
        return 1
    else if test "$snap_warn" -gt 0
        _warn "$summary"
        echo "VERIFY:WARN:$snap_ok:$snap_fail:$snap_warn"
        return 0
    else
        _ok "$summary"
        echo "VERIFY:OK:$snap_ok:$snap_fail:$snap_warn"
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
    "Installing user files" \
    "AMDGPU performance service" \
    "Updating databases" \
    "Reloading system config" \
    "Removing packages" \
    "Masking services" \
    "NetworkManager dispatcher" \
    "CPU performance service" \
    "Enabling timers" \
    "System upgrade" \
    "Rebuilding initramfs" \
    "Updating bootloader" \
    "Finalizing system" \
    "NetworkManager restart" \
    "WiFi reconnection"
set -g PROGRESS_TOTAL (count $PROGRESS_STEPS)

# Reset progress counters and compute PROGRESS_TOTAL from PROGRESS_STEPS list
function _progress_init --description "Initialize the step progress counter"
    set -g _STEP_PREV_NAME ""
    set -g _STEP_PREV_START 0
    if test "$ALL" = true; and test "$DRY" = false
        set -g PROGRESS_CURRENT 0
        set -g PROGRESS_START_TIME (date +%s)
        set -g PROGRESS_STEP_START 0
        printf '\n' >&2
    end
end

# Advance to next step: emit timing for previous step, display [N/M] progress bar to stderr
function _progress --argument-names step_name --description "Advance and display the current progress step"
    if test (count $argv) -lt 1
        return 0
    end
    # Emit timing for the previous step
    if test -n "$_STEP_PREV_NAME"; and test "$_STEP_PREV_START" -gt 0
        set -l _step_now (date +%s)
        set -l _step_elapsed (math "$_step_now - $_STEP_PREV_START")
        set -l _step_name_esc (_json_str "$_STEP_PREV_NAME")
        printf '{"ts":"%s","event":"step_time","data":"%s","elapsed_s":%d}\n' \
            (date '+%Y-%m-%dT%H:%M:%S%z') "$_step_name_esc" "$_step_elapsed" >>"$LOG_FILE"
    end
    set -g _STEP_PREV_NAME "$step_name"
    set -g _STEP_PREV_START (date +%s)

    if test "$ALL" = true; and test "$DRY" = false
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
        if test (string length -- "$step_name") -gt 25
            set desc (string sub -l 22 -- "$step_name")"..."
        else
            set desc (string sub -l 25 -- "$step_name                              ")
        end

        printf '\r[%s] %3d%% %s%s' "$bar" "$pct" "$desc" "$step_elapsed" >&2
    end
    _log "PROGRESS: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $step_name"
end

# Record a skipped progress step to keep counter synchronized with PROGRESS_TOTAL
function _progress_skip --argument-names step_name --description "Advance progress counter for a skipped step"
    if test (count $argv) -lt 1
        return 0
    end
    # Emit timing for the previous step (consistent with _progress)
    if test -n "$_STEP_PREV_NAME"; and test "$_STEP_PREV_START" -gt 0
        set -l _step_now (date +%s)
        set -l _step_elapsed (math "$_step_now - $_STEP_PREV_START")
        set -l _step_name_esc (_json_str "$_STEP_PREV_NAME")
        printf '{"ts":"%s","event":"step_time","data":"%s","elapsed_s":%d}\n' \
            (date '+%Y-%m-%dT%H:%M:%S%z') "$_step_name_esc" "$_step_elapsed" >>"$LOG_FILE"
    end
    set -g _STEP_PREV_NAME "$step_name"
    set -g _STEP_PREV_START (date +%s)
    set -g PROGRESS_CURRENT (math "min($PROGRESS_CURRENT + 1, $PROGRESS_TOTAL)")
    # Render progress bar to avoid visual stall on skipped steps
    if test "$ALL" = true; and test "$DRY" = false; and test "$PROGRESS_TOTAL" -gt 0 2>/dev/null
        set -l pct (math "floor($PROGRESS_CURRENT * 100 / $PROGRESS_TOTAL)")
        set -l filled (math "floor($PROGRESS_CURRENT * $PROGRESS_WIDTH / $PROGRESS_TOTAL)")
        set -l empty (math "$PROGRESS_WIDTH - $filled")
        set -l bar ""
        for _si in (seq 1 $filled)
            set bar "$bar█"
        end
        for _si in (seq 1 $empty)
            set bar "$bar░"
        end
        set -l desc
        if test (string length -- "$step_name") -gt 25
            set desc (string sub -l 22 -- "$step_name")"..."
        else
            set desc (string sub -l 25 -- "$step_name                              ")
        end
        printf '\r[%s] %3d%% %s (skip)' "$bar" "$pct" "$desc" >&2
    end
    _log "PROGRESS_SKIP: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $step_name"
end

# Close progress display: emit final step timing, fill bar to 100%, reset state
function _progress_done --description "Finalize and close the progress display"
    # Emit timing for the final step
    if test -n "$_STEP_PREV_NAME"; and test "$_STEP_PREV_START" -gt 0
        set -l _step_now (date +%s)
        set -l _step_elapsed (math "$_step_now - $_STEP_PREV_START")
        set -l _step_name_esc (_json_str "$_STEP_PREV_NAME")
        printf '{"ts":"%s","event":"step_time","data":"%s","elapsed_s":%d}\n' \
            (date '+%Y-%m-%dT%H:%M:%S%z') "$_step_name_esc" "$_step_elapsed" >>"$LOG_FILE"
    end
    set -g _STEP_PREV_NAME ""
    set -g _STEP_PREV_START 0

    # Runtime assertion: catch step count drift (lint also checks at build time); only meaningful with --all without --dry-run
    if test "$ALL" = true; and test "$DRY" = false
        if test "$PROGRESS_CURRENT" -ne "$PROGRESS_TOTAL" 2>/dev/null
            _warn "Progress step mismatch: emitted $PROGRESS_CURRENT of $PROGRESS_TOTAL expected"
        end
    end

    if test "$ALL" = true; and test "$DRY" = false
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

# ── Command execution wrapper — secret redaction (9 patterns), dry-run gating, output capture to tmpfiles, structured error reporting ──

# Execute command with logging, secret redaction, dry-run gating, and stdout/stderr capture to tmpfiles
function _run --description "Execute a command with logging, dry-run support, and error capture; stdout captured and only displayed when QUIET=false"
    if test (count $argv) -eq 0
        _log "BUG: _run called with no arguments"
        return 1
    end
    # SECURITY: reject any argv element with shell metacharacters (;|&`$\n\t\r) to prevent injection from untrusted input Fish does not eval $argv (each element is a separate token), so this is defense-in-depth for log integrity and future external profile sourcing where callers may pass unsanitized data.
    for _arg in $argv
        if string match -qr '[;|&`\$\n\t\r]' -- "$_arg"
            _log "BUG: _run argv contains shell metacharacters — refusing to execute: $_arg"
            return 1
        end
    end
    set -l log_cmd (string join -- " " $argv)

    # Redact secrets from log output; globs match --flag=value and --flag value without false positives
    for _secret_flag in --passphrase --password --token --key --secret --api-key --psk --wpa-psk --private-key
        if string match -q "* $_secret_flag=*" -- " $log_cmd"; or string match -q "* $_secret_flag *" -- " $log_cmd"
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
        set -l stderr_tmp (mktemp -t ry-run-stderr.XXXXXX 2>/dev/null; or echo /dev/null)
        set -l stdout_tmp (mktemp -t ry-run-stdout.XXXXXX 2>/dev/null; or echo /dev/null)
        test "$stderr_tmp" != /dev/null; and set -ga _TRACKED_TMPFILES "$stderr_tmp"
        test "$stdout_tmp" != /dev/null; and set -ga _TRACKED_TMPFILES "$stdout_tmp"
        if test "$stderr_tmp" = /dev/null; or test "$stdout_tmp" = /dev/null
            if not set -q _MKTEMP_DEGRADED_WARNED
                set -g _MKTEMP_DEGRADED_WARNED true
                _log "WARN: mktemp fallback to /dev/null — output capture degraded"
            end
        end
        # SECURITY INVARIANT: $argv is hardcoded from internal callers; WIFI_SSID is read-validated (no metacharacters)
        $argv >"$stdout_tmp" 2>"$stderr_tmp"
        set -l ret $status
        if test "$stderr_tmp" != /dev/null; and test -s "$stderr_tmp"
            set -l total_err (command wc -l < "$stderr_tmp" | string trim --)
            set -l first_lines (command head -n 5 "$stderr_tmp")
            set -l dedup_lines (LC_ALL=C command sort "$stderr_tmp" | command uniq -c | command sort -rn | command sed 's/^ *//')
            _log "STDERR($total_err lines): first: "(string join -- " | " $first_lines)" | dedup: "(string join -- " | " $dedup_lines)
            if test "$QUIET" = false
                for el in $first_lines
                    echo "  stderr: $el" >&2
                end
                if test $total_err -gt 5
                    echo "  stderr: ... ($total_err lines total, showing first 5)" >&2
                end
            end
        end
        command rm -f -- "$stderr_tmp" 2>/dev/null
        if test "$stdout_tmp" != /dev/null; and test -s "$stdout_tmp"
            set -l line_count (command wc -l < "$stdout_tmp" | string trim --)
            if test $line_count -le 50
                _log "OUTPUT: "(string join -- " | " (command cat -- "$stdout_tmp"))
            else if test $ret -ne 0
                if test $line_count -le 200
                    _log "OUTPUT: "(string join -- " | " (command cat -- "$stdout_tmp"))
                else
                    _log "OUTPUT: "(string join -- " | " (command head -n 100 "$stdout_tmp"))" | ... ($line_count lines, showing first 100 + last 100) | "(string join -- " | " (command tail -n 100 "$stdout_tmp"))
                end
            else
                _log "OUTPUT: "(string join -- " | " (command head -n 50 "$stdout_tmp"))" | ... ($line_count lines, truncated)"
            end
            # Print captured stdout when QUIET=false; cap display to 50 lines (full output in JSONL log above)
            if test "$QUIET" = false
                if test $line_count -le 50
                    command cat -- "$stdout_tmp" >&2
                else
                    command head -n 50 "$stdout_tmp" >&2
                    echo "  stdout: ... ($line_count lines total, showing first 50)" >&2
                    _log "STDOUT_TRUNCATED: $line_count lines total, displayed first 50"
                end
            end
        end
        command rm -f -- "$stdout_tmp" 2>/dev/null
        _log "EXIT: $ret cmd=$log_cmd"
        return $ret
    end
end

# Prompt for yes/no; auto-yes when --all or --force; returns 1 on decline or non-tty
function _ask --description "Prompt the user for yes/no confirmation"
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
    string match -qir '^y(es)?$' -- "$r"
end

# Display full usage, options, exit codes, and examples to stdout
function _ry_show_help --description "Display usage information and available subcommands"
    # Fallback: count _ry_get_file_content case branches if profile hasn't loaded (--help exits before _load_profile)
    set -l _file_count "$MANAGED_FILE_COUNT"
    if test -z "$_file_count"
        # Count all case branches minus the wildcard case '*'; avoids $HOME expansion bugs in regex
        set -l _all_cases (sed -n -- '/^function _ry_get_file_content/,/^end$/p' (status filename) | grep -c '^        case ')
        set _file_count (math "$_all_cases - 1")
    end
    set -l _profile_desc "Beelink GTR9 Pro (Strix Halo)"
    if set -q PROFILE_DESC; and test -n "$PROFILE_DESC"
        set _profile_desc "$PROFILE_DESC"
    end
    echo "
ry-install v$VERSION
Self-contained CachyOS configuration for $_profile_desc
Single fish script, $_file_count embedded configs, no external dependencies.

Usage: "(status filename)" [OPTIONS]

INSTALLATION:
  (no args)         Interactive installation
  -a, --all         Install without prompts (unattended mode)
  -f, --force       Auto-yes prompts, no progress bar
  -V, --verbose     Show output on terminal (default: silent, log only)
  -n, --dry-run     Preview changes without modifying system

VERIFICATION:
  --diff            Per-file unified diff (colorized)
  --diff <path>     Diff a single managed file (absolute path required)
  --diff --fix      Show diffs and re-install drifted files (per-file prompt)
  --verify-static   Check config files exist with correct content
  --verify-runtime  Check live system state (run after reboot)
  --lint            Run fish syntax and anti-pattern checks
  --check           Silent idempotency probe (exit 0 = clean, exit 10 = drift)
  --test-all        Run all safe modes and generate NDJSON logs (test suite)

UTILITIES:
  --logs <target>   View logs (system gpu wifi boot audio usb kernel <service>)
  --logs analyze [file]  Parse NDJSON log, show human-readable results
  --logs last       Analyze most recent log file
  --logs all        Analyze all logs, show combined summary
  --logs list       List recent log files with summaries
  --install-file <path>  Re-deploy a single managed file
  --completions     Install fish tab-completions for ry-install itself

OPTIONS:
  --fix             Re-install drifted files (use with --diff)
  --                End of options (remaining arguments ignored)
  -h, --help        Show this help
  -v, --version     Show version

EXIT CODES:
  0   Success
  1   Non-critical failure (one or more operations failed)
  2   Usage error (invalid arguments or flag combinations)
  3   Preflight check failed (deps, disk space, hardware mismatch)
  4   Boot-critical failure (mkinitcpio, sdboot-manage, vmlinuz missing)
  5   Lock acquisition failed (another instance running)
  10  Drift detected (--check mode)
  11  Lint errors found (--lint mode)
  130  Interrupted (SIGINT)
  129/131/143  Interrupted (SIGHUP/SIGQUIT/SIGTERM)
  141  Broken pipe (SIGPIPE)

EXAMPLES:
  ./ry-install.fish              # Interactive installation
  ./ry-install.fish --all        # Unattended installation
  ./ry-install.fish --diff --fix     # Fix drifted config files
  ./ry-install.fish --install-file /etc/mkinitcpio.conf  # Re-deploy single file
  ./ry-install.fish --test-all      # Run all safe modes, generate NDJSON logs
  ./ry-install.fish --logs last     # Analyze most recent log
  ./ry-install.fish --logs all      # Analyze all logs, combined summary
  ./ry-install.fish --logs list     # List recent logs with summaries
  ./ry-install.fish --logs analyze ~/ry-install/logs/.../test.jsonl

LOG FILE:
  ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS+ZZZZ.jsonl

REQUIREMENTS:
  CachyOS (Arch-based), systemd-boot, fish 3.4+

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

# Verify a managed file exists at dst; uses elevated test for /boot paths, logs OK/FAIL with context System files are 0644 (world-readable) — only /boot/* needs sudo (ESP may be root-only vfat)
function _chk_file --argument-names filepath --description "Verify a file exists (sudo for /boot, direct for /etc)"
    if test (count $argv) -lt 1
        _err "_chk_file: missing argument"
        return 1
    end
    _log "CHECK_FILE: $argv[1]"
    if string match -q '/boot/*' -- "$argv[1]"
        if not command -q sudo
            _fail "File check requires sudo: $argv[1]"
            return 1
        end
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
    string match -q '/boot/*' -- "$argv[1]"; and set is_boot true

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
        if not command -q sudo
            _fail "  $argv[3]: sudo required for /boot path"
            return 1
        end
        sudo grep -qF -- "$argv[2]" "$argv[1]" 2>/dev/null; and set found true
    else
        grep -qF -- "$argv[2]" "$argv[1]" 2>/dev/null; and set found true
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
function _ry_check_deps --description "Verify required packages are installed"
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
        if contains -- sdboot-manage $missing
            _err "  sdboot-manage is required for CachyOS bootloader management"
            _err "  Install with: sudo pacman -S --needed sdboot-manage"
        end
        if contains -- mkinitcpio $missing
            _err "  mkinitcpio is required for initramfs generation (Arch/CachyOS)"
        end
        return 1
    end

    set -l systemd_ver (systemctl --version 2>/dev/null | head -n 1 | string match -r -- '\d+' | head -n 1)
    # systemd 250+: required for environment.d, systemd-analyze verify --user
    if test -n "$systemd_ver"; and test "$systemd_ver" -lt 250
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
function _ry_check_network --description "Verify network connectivity and DNS resolution"
    _log "Checking network connectivity..."

    _info "Checking HTTPS connectivity..."
    if command -q curl
        for _probe in https://archlinux.org https://cachyos.org https://cdn.cloudflare.com
            if curl -sf --max-time 5 --head "$_probe" >/dev/null 2>&1
                _ok "Network connectivity: OK"
                return 0
            end
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
function _ry_check_disk_space --description "Verify sufficient free disk space for installation"
    _log "Checking disk space..."

    set -l root_avail (LC_ALL=C df -BG / 2>/dev/null | tail -n 1 | awk '{print $4}' | tr -d 'G')
    if test -n "$root_avail"; and string match -qr '^\d+$' -- "$root_avail"
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
    if test -n "$boot_avail"; and string match -qr '^\d+$' -- "$boot_avail"
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
function _ry_check_kernel_version --description "Verify running kernel version meets minimum requirement"
    set -l kver $KVER
    set -l major $KVER_MAJOR
    set -l minor $KVER_MINOR

    _info "Kernel version: $kver"

    # Minimum: 6.14 (ntsync, gfx1151 fixes, mt7925e.disable_aspm)
    if test "$major" -lt 6; or begin
            test "$major" -eq 6; and test "$minor" -lt 14
        end
        _fail "Kernel $kver < 6.14: ntsync, gfx1151 fixes, and mt7925e.disable_aspm unavailable"
        _info "  Upgrade kernel before or during install (pacman -Syu)"
        return 1
    end

    set -l _ns (_ntsync_state)
    if test "$_ns" = unavailable
        _warn "Kernel $kver: ntsync not available (expected builtin or module)"
    else
        _ok "Kernel $kver: ntsync $_ns"
    end

    # CHK-03: Kernel 6.19.0 black screen regression on Strix Halo (CachyOS #23042)
    if test "$major" -eq 6; and test "$minor" -eq 19
        set -l kver_patch (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[3]")
        if test -z "$kver_patch"; or test "$kver_patch" = 0
            _warn "Kernel 6.19.0: black screen regression on Strix Halo (CachyOS #23042)"
            _warn "  Recommend: downgrade to 6.18.x or upgrade to 6.19.1+"
        end
    end

    return 0
end

# ── Config validation pipeline — pre-flight checks on embedded content: hooks ordering, modprobe resolve, systemd-analyze verify, fish --no-execute; aborts on any error ──

# Validate HOOKS ordering (base first, keyboard before sd-vconsole, etc.) and hook existence
function _ry_validate_mkinitcpio_hooks --description "Validate mkinitcpio HOOKS ordering and presence"
    set -l existence_only false
    set -l hooks
    # Verify mkinitcpio hook ordering and presence
    if test (count $argv) -gt 0; and test "$argv[1]" = --existence-only
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
            if test -f "/usr/lib/initcpio/install/$hook"; or test -f "/usr/lib/initcpio/hooks/$hook"; or test -f "/etc/initcpio/install/$hook"; or test -f "/etc/initcpio/hooks/$hook"
                _ok "  $hook: exists"
            else
                _fail "  $hook: NOT FOUND"
                set errors (math $errors + 1)
            end
        end
        if test $errors -eq 0
            return 0
        end
        return 1
    end

    for hook in $hooks
        if not test -f "/usr/lib/initcpio/install/$hook"; and not test -f "/etc/initcpio/install/$hook"
            if not test -f "/usr/lib/initcpio/hooks/$hook"; and not test -f "/etc/initcpio/hooks/$hook"
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
        # Verify hook ordering constraints (before:after pairs)
        set -l order_checks \
            "systemd:sd-vconsole" \
            "keyboard:sd-vconsole" \
            "modconf:kms" \
            "block:filesystems"
        for check in $order_checks
            set -l hook_before (string split ':' -- "$check")[1]
            set -l hook_after (string split ':' -- "$check")[2]
            set -l idx_a 0
            set -l idx_b 0
            for i in (seq (count $MKINITCPIO_HOOKS))
                test "$MKINITCPIO_HOOKS[$i]" = "$hook_before"; and set idx_a $i
                test "$MKINITCPIO_HOOKS[$i]" = "$hook_after"; and set idx_b $i
            end
            if test $idx_a -gt 0; and test $idx_b -gt 0; and test $idx_a -ge $idx_b
                _err "Mkinitcpio hook order: '$hook_before' must come before '$hook_after'"
                set errors (math $errors + 1)
            end
        end
    end

    if test $errors -eq 0
        return 0
    end
    return 1
end
function _ry_validate_mkinitcpio_modules --description "Validate mkinitcpio MODULES array entries"
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

# Run all embedded config validators: hooks, modules, units, modprobe, fish; abort on errors
function _ry_validate_configs --description "Run all embedded config validators"
    _info "Validating configuration syntax..."

    set -l errors 0

    # Phase 1 (sequential): fast in-memory checks + content pre-generation
    if not _ry_validate_mkinitcpio_hooks
        set errors (math $errors + 1)
    end
    _ry_validate_mkinitcpio_modules

    # B-1: Pre-generate all content files for parallel validation
    set -l content_dir (_pregenerate_content_files)
    if not test -d "$content_dir"
        _err "Failed to pre-generate content files"
        return 1
    end

    set -l val_dir (mktemp -d -t ry-validate-par.XXXXXX)
    if not test -d "$val_dir"
        _err "Failed to create validation temp directory"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$val_dir"

    # Phase 2 (parallel): fork independent validation jobs
    set -l dst_count (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)

    # Job 1: cross-reference check — verify files exist (empty files indicate runtime deps; content validation in jobs 2-5)
    fish -c '
        set -l errs 0
        set -l expected_count $argv[1]
        set -l content_dir $argv[2]
        set -l val_dir $argv[3]
        set -l actual_count (count (find "$content_dir" -maxdepth 1 -type f 2>/dev/null))
        if test $actual_count -lt $expected_count
            set errs (math $expected_count - $actual_count)
        end
        echo $errs > "$val_dir/xref.errors"
    ' -- "$dst_count" "$content_dir" "$val_dir" 2>"$val_dir/xref.stderr" &
    set -l pid_xref $last_pid

    # Job 2: systemd unit syntax — derive keys from destinations (not hardcoded) Collect all .service destinations: SERVICE_DESTINATIONS (system) + USER_DESTINATIONS (user scope)
    set -l _svc_dsts
    for _sd in $SERVICE_DESTINATIONS
        set -a _svc_dsts "$_sd"
    end
    for _ud in $USER_DESTINATIONS
        if string match -q '*.service' -- "$_ud"
            set -a _svc_dsts "$_ud"
        end
    end
    fish -c '
        set -l errs 0
        set -l content_dir $argv[1]
        set -l val_dir $argv[2]
        set -l my_home $argv[3]
        set -l svc_dsts $argv[4..]
        if not command -q systemd-analyze
            echo $errs > "$val_dir/units.errors"
            exit 0
        end
        for dst in $svc_dsts
            set -l unit_key (string replace -a -- "/" "_" "$dst")
            set -l f "$content_dir/$unit_key"
            set -l user_flag
            if string match -q "$my_home/*" -- "$dst"
                set user_flag --user
            end
            if test -s "$f"
                set -l tmp (mktemp -p "$val_dir" --suffix=.service ry-val-unit.XXXXXX)
                command cp -- "$f" "$tmp"
                if not systemd-analyze $user_flag verify "$tmp"
                    set errs (math $errs + 1)
                end
                command rm -f -- "$tmp"
            else
                set errs (math $errs + 1)
            end
        end
        echo $errs > "$val_dir/units.errors"
    ' -- "$content_dir" "$val_dir" "$HOME" $_svc_dsts 2>"$val_dir/units.stderr" &
    set -l pid_units $last_pid

    # Job 3: fish script syntax + environment.d check
    fish -c '
        set -l errs 0
        set -l content_dir $argv[1]
        set -l val_dir $argv[2]
        set -l my_home $argv[3]
        set -l fish_key (string replace -a -- "/" "_" "$my_home/.config/fish/conf.d/10-ssh-auth-sock.fish")
        set -l f "$content_dir/$fish_key"
        if test -s "$f"
            if not fish --no-execute "$f" 2>/dev/null
                set errs (math $errs + 1)
            end
        else
            set errs (math $errs + 1)
        end
        # environment.d check
        set -l env_key (string replace -a -- "/" "_" "$my_home/.config/environment.d/10-environment.conf")
        set -l ef "$content_dir/$env_key"
        if test -s "$ef"
            if not grep -q -- "^SSH_AUTH_SOCK=" "$ef"
                set errs (math $errs + 1)
            end
            if grep -q -- "%t" "$ef"
                set errs (math $errs + 1)
            end
        else
            set errs (math $errs + 1)
        end
        echo $errs > "$val_dir/scripts.errors"
    ' -- "$content_dir" "$val_dir" "$HOME" 2>"$val_dir/scripts.stderr" &
    set -l pid_scripts $last_pid

    # Job 4: INI section-header validation (4 configs)
    fish -c '
        set -l errs 0
        set -l content_dir $argv[1]
        set -l val_dir $argv[2]
        set -l checks \
            "_etc_systemd_resolved.conf.d_99-cachyos-resolved.conf|[Resolve]" \
            "_etc_systemd_logind.conf.d_99-cachyos-logind.conf|[Login]" \
            "_etc_iwd_main.conf|[General],[DriverQuirks],[Network]" \
            "_etc_NetworkManager_conf.d_99-cachyos-nm.conf|[device],[connection],[logging]"
        for check in $checks
            set -l key (string split "|" -- $check)[1]
            set -l sections_str (string split "|" -- $check)[2]
            set -l sections (string split "," -- $sections_str)
            set -l f "$content_dir/$key" # lint:ignore
            if not test -s "$f"
                set errs (math $errs + 1)
                continue
            end
            for section in $sections
                if not grep -qF -- "$section" "$f"
                    set errs (math $errs + 1)
                end
            end
        end
        echo $errs > "$val_dir/ini.errors"
    ' -- "$content_dir" "$val_dir" 2>"$val_dir/ini.stderr" &
    set -l pid_ini $last_pid

    # Job 5: simple key-value config validation (3 configs)
    fish -c '
        set -l errs 0
        set -l content_dir $argv[1]
        set -l val_dir $argv[2]
        # loader.conf
        set -l f "$content_dir/_boot_loader_loader.conf"
        if test -s "$f"
            for key in default timeout console-mode editor
                if not grep -qE -- "^$key " "$f"
                    set errs (math $errs + 1)
                end
            end
        else
            set errs (math $errs + 1)
        end
        # sdboot-manage.conf
        set -l f "$content_dir/_etc_sdboot-manage.conf"
        if test -s "$f"
            for key in LINUX_OPTIONS LINUX_FALLBACK_OPTIONS DEFAULT_ENTRY REMOVE_EXISTING OVERWRITE_EXISTING REMOVE_OBSOLETE
                if not grep -qE -- "^$key=" "$f"
                    set errs (math $errs + 1)
                end
            end
        else
            set errs (math $errs + 1)
        end
        # udev rules
        set -l f "$content_dir/_etc_udev_rules.d_99-cachyos-udev.rules"
        if test -s "$f"
            if grep -qE -- "[A-Z]+=[^=]" "$f" 2>/dev/null
                if grep -qE -- "==[[:space:]]*\$" "$f" 2>/dev/null
                    set errs (math $errs + 1)
                end
            end
            # FN-03: match-position keys must use == (not single =); single = is assign, not match
            if grep -qE -- "(KERNEL|SUBSYSTEM|DRIVER|ACTION|DEVPATH|ATTR\{[^}]*\})[[:space:]]*=[^=]" "$f" 2>/dev/null
                set errs (math $errs + 1)
            end
        else
            set errs (math $errs + 1)
        end
        # drirc XML structure
        set -l f "$content_dir/_etc_drirc"
        if test -s "$f"
            for tag in "<driconf>" "<device>" "<application" "radv_enable_unified_heap_on_apu"
                if not grep -qF -- "$tag" "$f"
                    set errs (math $errs + 1)
                end
            end
        else
            set errs (math $errs + 1)
        end
        echo $errs > "$val_dir/simple.errors"
    ' -- "$content_dir" "$val_dir" 2>"$val_dir/simple.stderr" &
    set -l pid_simple $last_pid

    wait $pid_xref $pid_units $pid_scripts $pid_ini $pid_simple

    # Merge error counts — treat missing result files as child crash (prevents false-pass)
    for phase in xref units scripts ini simple
        if not test -f "$val_dir/$phase.errors"
            _err "Validation child '$phase' crashed without writing results"
            if test -s "$val_dir/$phase.stderr"
                _log "VALIDATE_CHILD_STDERR($phase): "(head -n 5 "$val_dir/$phase.stderr")
            end
            set errors (math $errors + 1)
            continue
        end
        # Log stderr from ALL children (warnings from systemd-analyze, fish --no-execute, etc.)
        if test -s "$val_dir/$phase.stderr"
            _log "VALIDATE_STDERR($phase): "(head -n 5 "$val_dir/$phase.stderr")
        end
        set -l phase_errors (command cat -- "$val_dir/$phase.errors" 2>/dev/null)
        if test -n "$phase_errors"; and string match -qr '^\d+$' -- "$phase_errors"
            if test "$phase_errors" -gt 0
                set errors (math $errors + $phase_errors)
            end
        else if test -n "$phase_errors"
            _err "Validation child '$phase' wrote non-numeric result: $phase_errors"
            set errors (math $errors + 1)
        end
    end

    command rm -rf --preserve-root -- "$val_dir" "$content_dir"

    if test $errors -gt 0
        _err "Validation failed with $errors error(s)"
        return 1
    end

    _ok "All configurations validated"
    return 0
end

# ── Atomic file write helper — shared by _ry_install_file (deduplicates sudo/non-sudo paths) ──

# Atomic write: mktemp→symlink-check→write→symlink-recheck→chmod→hash→mv→verify→chown
function _atomic_write_file --argument-names dst perms use_sudo --description "Atomic file write with symlink and integrity checks"
    if test (count $argv) -ne 3
        _err "_atomic_write_file: expected 3 args (dst perms use_sudo), got "(count $argv)
        return 1
    end

    set -l dst_dir (dirname -- "$dst")
    set -l tmpfile
    if test "$use_sudo" = true
        set tmpfile (sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
    else
        set tmpfile (mktemp -p "$dst_dir" .ry-install.XXXXXX)
    end
    if test -z "$tmpfile"
        _fail "→ $dst (mktemp failed)"
        return 1
    end

    # Pre-write symlink check
    if test "$use_sudo" = true
        if sudo test -L "$tmpfile"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
    else
        if test -L "$tmpfile"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
    end

    # Write content via pipe
    if test "$use_sudo" = true
        _ry_get_file_content "$dst" | sudo tee -- "$tmpfile" >/dev/null
    else
        _ry_get_file_content "$dst" | tee -- "$tmpfile" >/dev/null
    end
    set -l _ps $pipestatus
    if test $_ps[1] -ne 0
        if test "$use_sudo" = true
            sudo rm -f -- "$tmpfile" 2>/dev/null
        else
            command rm -f -- "$tmpfile" 2>/dev/null
        end
        _err "No content defined for: $dst"
        return 1
    end
    if test $_ps[2] -ne 0
        if test "$use_sudo" = true
            sudo rm -f -- "$tmpfile" 2>/dev/null
        else
            command rm -f -- "$tmpfile" 2>/dev/null
        end
        _fail "→ $dst (write to temp failed)"
        return 1
    end

    # Post-write symlink re-check: closes TOCTOU between pre-write test -L and tee
    if test "$use_sudo" = true
        if sudo test -L "$tmpfile"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file replaced with symlink during write — aborting)"
            return 1
        end
    else
        if test -L "$tmpfile"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file replaced with symlink during write — aborting)"
            return 1
        end
    end

    # chmod
    if test "$use_sudo" = true
        if not _run sudo chmod -- $perms "$tmpfile"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (chmod failed)"
            return 1
        end
    else
        if not _run command chmod -- $perms "$tmpfile"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (chmod failed)"
            return 1
        end
    end

    # Capture expected hash from tmpfile before mv (single _ry_get_file_content call; no redundant re-generation)
    set -l _expected_hash
    if test "$use_sudo" = true
        set _expected_hash (sudo cat -- "$tmpfile" 2>/dev/null | sha256sum | string split -- ' ')[1]
    else
        set _expected_hash (command cat -- "$tmpfile" 2>/dev/null | sha256sum | string split -- ' ')[1]
    end

    # Atomic mv
    if test "$use_sudo" = true
        if not _run sudo mv -- "$tmpfile" "$dst"
            sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
    else
        if not _run command mv -- "$tmpfile" "$dst"
            command rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (atomic move failed)"
            return 1
        end
    end

    # Post-write integrity check: verify mv preserved content (catches fs corruption, not generation bugs)
    set -l _actual_hash
    if test "$use_sudo" = true
        set _actual_hash (sudo cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
    else
        set _actual_hash (command cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
    end
    if test -n "$_expected_hash"; and test "$_expected_hash" != "$_actual_hash"
        _fail "→ $dst (post-write checksum mismatch)"
        _log "HASH_MISMATCH: expected=$_expected_hash actual=$_actual_hash dst=$dst"
        return 1
    end

    # chown + success message
    if test "$use_sudo" = true
        if not _run sudo chown -- root:root "$dst"
            _warn "→ $dst (chown failed, check ownership)"
            set -g INSTALL_HAD_ERRORS true
        else
            _ok "→ $dst"
        end
    else
        _ok "→ $dst"
    end
    return 0
end

# ── Atomic file installation — _ry_get_file_content → mktemp → validate → chmod/chown → mv; hash comparison skips unchanged files; skips NM/IWD if iwd not installed ──

# Deploy a single embedded config: get content → mktemp → validate → chmod → atomic mv to dst
function _ry_install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
    if test (count $argv) -ne 2
        _err "_ry_install_file: expected 2 args (dst use_sudo), got "(count $argv)
        return 1
    end
    set -l dst $argv[1]
    set -l use_sudo $argv[2]

    # Skip NM/IWD configs if iwd not installed — prevents broken wifi stack
    if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
        if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
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

    # Skip unchanged: SHA256 hash comparison (Fish variable comparison flattens newlines to spaces)
    set -l _new_hash (_ry_get_file_content "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
    if test -n "$_new_hash"
        set -l _cur_hash
        if test "$use_sudo" = true
            set _cur_hash (sudo cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
        else
            set _cur_hash (command cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ')[1]
        end
        if test -n "$_cur_hash"; and test "$_new_hash" = "$_cur_hash"
            _ok "→ $dst (unchanged)"
            return 0
        end
    end

    _atomic_write_file "$dst" $perms $use_sudo

    return 0
end

# ═══ FILE OPERATIONS — diff, install, verify ═══

function _ry_install_files --description "Install multiple embedded configs with argparse options"
    set -l _argparse_tmp (mktemp -t ry-argparse.XXXXXX 2>/dev/null; or echo /dev/null)
    test "$_argparse_tmp" != /dev/null; and set -ga _TRACKED_TMPFILES "$_argparse_tmp"
    argparse s/sudo 'd/desc=' -- $argv 2>$_argparse_tmp
    or begin
        set -l _argparse_err (string trim -- (command cat -- "$_argparse_tmp" 2>/dev/null))
        command rm -f -- "$_argparse_tmp" 2>/dev/null
        set -l _err_suffix ""
        if test -n "$_argparse_err"
            set _err_suffix ": $_argparse_err"
        end
        _err "_ry_install_files: invalid arguments$_err_suffix"
        return 1
    end
    command rm -f -- "$_argparse_tmp" 2>/dev/null
    set -l use_sudo false
    if set -q _flag_sudo
        set use_sudo true
    end
    set -l desc FILES
    if test -n "$_flag_desc"
        set desc "$_flag_desc"
    end
    if test (count $argv) -eq 0
        _err "_ry_install_files: no destinations provided"
        return 1
    end
    set -l destinations $argv

    _log "INSTALL $desc"
    set -l had_failure false
    for dst in $destinations
        if not _ry_install_file "$dst" $use_sudo
            _err "Failed to install: $dst"
            set had_failure true
        end
    end
    test "$had_failure" = true; and return 1
    return 0
end

# Compare embedded content against installed files; --fix repairs in-place; exit 1 when drift found.
function _ry_do_diff --argument-names target_file --description "Show diffs between embedded and installed configs"
    _log "=== DIFF START ==="

    # Check for orphaned files from previous install or profile switch
    _manifest_check_orphans

    # target_file is bound by the named-argument declaration on the line above
    if test (count $argv) -gt 0; and test -n "$argv[1]"
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
    set -l nm_config_fixed false
    set -l logind_files_fixed false
    set -l _boot_fstype (findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)

    if test "$FIX" = true; and test "$DRY" = false
        if not command -q sudo
            _err "Sudo required for --diff --fix"
            return 1
        end
        sudo true 2>/dev/null
        if test $status -ne 0
            _err "Sudo required for --diff --fix"
            return 1
        end
        # Automatic pre-install snapshots removed in v3.5.0; user is responsible for rootfs snapshots
        _info "No automatic backup — snapshot your rootfs before proceeding if needed"
    end

    # B-6: Batch I/O — pre-generate expected content + parallel installed-file reads
    _ensure_sudo_cached
    or return 1
    set -l diff_batch_dir (mktemp -d -t ry-diffbatch.XXXXXX)
    if not test -d "$diff_batch_dir"
        _err "Failed to create diff temp directory"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$diff_batch_dir"
    set -l my_home "$HOME"

    # Detect iwd skip state for both Phase 1 and Phase 2 (avoids wasted content generation + parallel forks)
    set -l _diff_skip_iwd false
    if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
        set _diff_skip_iwd true
    end

    # Phase 1: pre-generate expected content (fast sequential printf)
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test -n "$target_file"; and test "$dst" != "$target_file"
            continue
        end
        if test "$_diff_skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                continue
            end
        end
        set -l safe (string replace -a '/' '_' -- "$dst")
        _ry_get_file_content "$dst" >"$diff_batch_dir/expected_$safe" 2>/dev/null
    end

    # Phase 2: sequential installed-file reads in parent (sudo ppid doesn't propagate to children; configs <1KB)
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        # Skip non-target files when single-file diff requested
        if test -n "$target_file"; and test "$dst" != "$target_file"
            continue
        end
        # Skip iwd/NM configs when iwd not installed (consistent with Phase 3 filter)
        if test "$_diff_skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                continue
            end
        end
        set -l safe (string replace -a '/' '_' -- "$dst")
        if string match -q "$my_home/*" -- "$dst"
            command cat -- "$dst" >"$diff_batch_dir/installed_$safe" 2>/dev/null
        else
            sudo -n cat -- "$dst" >"$diff_batch_dir/installed_$safe" 2>/dev/null
        end
        printf "%d\n" $status >"$diff_batch_dir/readok_$safe"
        diff -u --label "embedded: $dst" --label "installed: $dst" -- "$diff_batch_dir/expected_$safe" "$diff_batch_dir/installed_$safe" >"$diff_batch_dir/diff_$safe" 2>&1
        printf "%d\n" $status >"$diff_batch_dir/diffstatus_$safe"
    end

    # Phase 3: sequential display + optional fix (reads pre-computed files)
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test -n "$target_file"; and test "$dst" != "$target_file"
            continue
        end
        # Skip NM/IWD configs if iwd not installed — use Phase 2 pre-computed state (avoids TOCTOU + extra pacman call)
        if test "$_diff_skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                _info "Skipping $dst: iwd package not installed"
                continue
            end
        end

        set -l safe (string replace -a '/' '_' -- "$dst")
        set -l tmp "$diff_batch_dir/expected_$safe"
        set -l tmp_installed "$diff_batch_dir/installed_$safe"

        if not test -s "$tmp"
            set has_diff true
            _warn "Cannot generate expected content for: $dst"
            continue
        end

        # Guard: missing readok file means Phase 2 failed to process this destination
        if not test -f "$diff_batch_dir/readok_$safe"
            set has_diff true
            _warn "$dst: diff processing failed (readok missing)"
            continue
        end
        set -l read_ok (command cat -- "$diff_batch_dir/readok_$safe" 2>/dev/null)
        if test -z "$read_ok"
            set read_ok 1
        end

        set -l this_diff false
        set -l this_perm_only false
        if test $read_ok -eq 0
            set -l diff_status (command cat -- "$diff_batch_dir/diffstatus_$safe" 2>/dev/null)
            if test -z "$diff_status"; or not string match -qr '^\d+$' -- "$diff_status"
                set diff_status 1
            end
            if test "$diff_status" != 0
                set has_diff true
                set this_diff true
                _echo "── $dst ──"
                # Use pre-computed diff for display
                set -l diff_tmp "$diff_batch_dir/diff_$safe"
                begin
                    if test "$NO_COLOR" = true; or not isatty 2
                        command cat -- "$diff_tmp"
                    else
                        # Colorize pre-computed unified diff via sed (standard tool)
                        sed -e 's/^-.*$/\x1b[31m&\x1b[0m/' -e 's/^+.*$/\x1b[32m&\x1b[0m/' -e 's/^@.*$/\x1b[36m&\x1b[0m/' -- "$diff_tmp"
                    end
                end >&2
                while read -l dline
                    _log "DIFF: $dst: $dline"
                end <"$diff_tmp"
                _echo
            else
                if string match -q "$HOME/*" -- "$dst"
                    set -l actual_perms (stat -c '%a' -- "$dst" 2>/dev/null)
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
                        set -l actual_perms (sudo stat -c '%a' -- "$dst" 2>/dev/null)
                        set -l actual_owner (sudo stat -c '%U:%G' -- "$dst" 2>/dev/null)
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
        else
            set has_diff true
            set this_diff true
            _fail "NOT INSTALLED: $dst"
        end

        # Detect .pacnew/.pacsave: pacman drops these when config files conflict with upgrades
        if not string match -q "$HOME/*" -- "$dst"
            for _pac_ext in .pacnew .pacsave
                set -l _pac_file "$dst$_pac_ext"
                if command -q sudo; and sudo test -f "$_pac_file" 2>/dev/null
                    _warn "STALE $_pac_ext: $_pac_file (review with pacdiff or merge manually)"
                    set has_pacnew true
                end
            end
        end

        if test "$FIX" = true; and test "$this_diff" = true
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
                    if _ry_install_file "$dst" $use_sudo
                        set fixed_count (math $fixed_count + 1)
                        if string match -q '/boot/*' -- "$dst"; or string match -q '/etc/mkinitcpio*' -- "$dst"; or string match -q '/etc/sdboot*' -- "$dst"; or string match -q /etc/kernel/cmdline -- "$dst"
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

                        if string match -q '*/iwd/main.conf' -- "$dst"; or string match -q '*/NetworkManager/conf.d/*' -- "$dst"
                            set nm_config_fixed true
                        end
                        if string match -q '*/logind.conf.d/*' -- "$dst"
                            set logind_files_fixed true
                        end
                    else
                        set fix_errors true
                    end
                end
            end
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
        if test "$boot_files_fixed" = true; and test "$DRY" = false
            _echo
            if _ask "Boot files changed — rebuild initramfs and update bootloader?"
                _run sudo mkinitcpio -P; or _warn "Mkinitcpio failed"
                _run sudo sdboot-manage gen; or _warn "Sdboot-manage gen failed"
                _run sudo sdboot-manage update; or _warn "Sdboot-manage update failed"
            end
        end
        if test "$service_files_fixed" = true; and test "$DRY" = false
            _run sudo systemctl daemon-reload; or _warn "Systemctl daemon-reload failed"
        end
        if test "$udev_files_fixed" = true; and test "$DRY" = false
            _echo
            if _ask "Udev rules changed — reload?"
                _run sudo udevadm control --reload-rules; or _warn "Udevadm reload-rules failed"
                _run sudo udevadm trigger; or _warn "Udevadm trigger failed"
                _run sudo udevadm settle --timeout=5; or _warn "Udevadm settle timed out"
            end
        end
        if test "$resolved_files_fixed" = true; and test "$DRY" = false
            _echo
            if _ask "Resolved config changed — restart systemd-resolved?"
                _run sudo systemctl restart systemd-resolved; or _warn "Systemd-resolved restart failed"
            end
        end

        if test "$nm_config_fixed" = true; and test "$DRY" = false
            _echo
            if _ask "NetworkManager config changed — restart NetworkManager?"
                _run sudo systemctl restart NetworkManager; or _warn "NetworkManager restart failed"
            end
        end
        if test "$logind_files_fixed" = true
            _info "Logind config changed — reboot required (restarting logind kills all sessions)"
        end
        if test (count $fixed_user_services) -gt 0; and test "$DRY" = false
            _run systemctl --user daemon-reload; or _warn "Systemctl --user daemon-reload failed"
            for _unit in $fixed_user_services
                _echo
                if _ask "Enable $_unit (user)?"
                    if _run systemctl --user enable --now "$_unit"
                        if test "$_unit" = ssh-agent.service; and set -q XDG_RUNTIME_DIR
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
                if string match -q '*.service' -- "$dst"; and test -f "$dst"
                    set -l _unit (basename -- "$dst")
                    if not contains -- "$_unit" $fixed_user_services
                        set -l _state (systemctl --user is-active "$_unit" 2>/dev/null)
                        if test "$_state" != active
                            _warn "$_unit exists but is not active ($_state)"
                            if _ask "Enable $_unit (user)?"
                                _run systemctl --user daemon-reload; or _warn "Systemctl --user daemon-reload failed"
                                if _run systemctl --user enable --now "$_unit"
                                    if test "$_unit" = ssh-agent.service; and set -q XDG_RUNTIME_DIR
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

    if test "$FIX" = true; and test "$DRY" = false
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
            end
        end

        if command -q coredumpctl
            set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
            set -l dump_count (string trim -- "$dump_count")
            if test -n "$dump_count"; and string match -qr '^\d+$' -- "$dump_count"; and test "$dump_count" -gt 0
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
    else if test "$FIX" = true; and test "$DRY" = true
        set -l pac_system_files (_find_pacnew_files)
        if test (count $pac_system_files) -gt 0
            _echo
            _info "Would offer to merge "(count $pac_system_files)" .pacnew/.pacsave file(s)"
        end
        if command -q coredumpctl
            set -l dump_count (coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
            set -l dump_count (string trim -- "$dump_count")
            if test -n "$dump_count"; and string match -qr '^\d+$' -- "$dump_count"; and test "$dump_count" -gt 0
                _info "Would offer to remove $dump_count coredump(s)"
            end
        end
    end

    command rm -rf --preserve-root -- "$diff_batch_dir"

    _log "=== DIFF END ==="

    if test "$fix_errors" = true
        return 1
    end
    if test "$has_diff" = true; and test "$FIX" != true
        return 1
    end
    if test "$has_diff" = true; and test "$DRY" = true
        return 1
    end
    return 0
end

# Checksum verification: sha256 of embedded content vs installed file; exit 1 when drifted.
function _ry_verify_static --description "Verify installed configs match embedded checksums"
    _log "=== STATIC VERIFICATION START ==="
    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
        return 1
    end

    set -g VERIFY_MODE true
    set -g VERIFY_OK 0
    set -g VERIFY_FAIL 0
    set -g VERIFY_WARN 0

    # Pre-compute iwd state once (avoids 3 independent pacman -Qi calls and TOCTOU between them)
    set -l _skip_iwd false
    if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
        set _skip_iwd true
    end

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
            | string replace -r -- '^LINUX_OPTIONS="([^"]*)"' '$1')

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
        # FN-04: parse value between quotes instead of glob-matching entire line (avoids comment false-pass)
        set -l comp_val (string match -r -- 'COMPRESSION="([^"]*)"' "$comp_line")[2]
        if test -z "$comp_val"
            # Fallback: unquoted value
            set comp_val (string replace -r -- '^[[:space:]]*COMPRESSION=' '' "$comp_line" | string trim --)
        end
        if test "$comp_val" = "$MKINITCPIO_COMPRESSION"
            _ok "  COMPRESSION=$MKINITCPIO_COMPRESSION: present"
        else
            _fail "  COMPRESSION=$MKINITCPIO_COMPRESSION: MISSING (found: $comp_val)"
        end
    end
    _echo

    _echo "── Boot entries ──"
    set -l entry_count 0
    if sudo test -d /boot/loader/entries 2>/dev/null
        set entry_count (sudo find /boot/loader/entries -name "*.conf" 2>/dev/null | wc -l | string trim --)
    end
    if test -n "$entry_count"; and string match -qr '^\d+$' -- "$entry_count"; and test "$entry_count" -gt 0
        _ok "  Boot entries: $entry_count found"
    else
        _fail "  Boot entries: NONE in /boot/loader/entries/"
        _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    end
    _echo

    _echo "SYSTEM CONFIGURATION"
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
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "DNSOverTLS=opportunistic" "DNSOverTLS=opportunistic"
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "DNSSEC=allow-downgrade" "DNSSEC=allow-downgrade"
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
    if test "$_skip_iwd" = true
        _info "  Skipping (iwd not installed)"
    else if _chk_file /etc/iwd/main.conf
        _chk_grep /etc/iwd/main.conf "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
        # Section-aware check: verify DriverQuirks keys are under [DriverQuirks], not elsewhere (FN-01)
        set -l _dq_section (sed -n '/^\[DriverQuirks\]/,/^\[/p' /etc/iwd/main.conf 2>/dev/null | sed '${ /^\[/d }')
        for quirk in $IWD_DRIVER_QUIRKS
            set -l key (string split '=' -- $quirk)[1]
            if test -n "$_dq_section"; and printf '%s\n' $_dq_section | grep -qF -- "$key"
                _ok "  DriverQuirks $key: present"
            else
                _fail "  DriverQuirks $key: MISSING from [DriverQuirks] section"
            end
        end
        _chk_grep /etc/iwd/main.conf "NameResolvingService=$IWD_DNS_SERVICE" "DNS via $IWD_DNS_SERVICE"
    end
    _echo

    _echo "── NetworkManager ──"
    if test "$_skip_iwd" = true
        _info "  Skipping iwd-backend config (iwd not installed)"
    else if _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
    end
    # NM-dispatcher enable state: checked in _ry_verify_runtime (batch systemctl show) — not a static config file check
    _echo

    _echo "── RADV driconf ──"
    if _chk_file /etc/drirc
        _chk_grep /etc/drirc radv_enable_unified_heap_on_apu unified_heap_on_apu
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

    # Batch: single pacman -Q replaces N individual pacman -Qi calls for both add/del checks
    set -l _installed_pkgs
    if command -q pacman
        set _installed_pkgs (pacman -Qq 2>/dev/null)
    end

    _echo "── Required packages ──"
    if command -q pacman
        for pkg in $PKGS_ADD
            if contains -- "$pkg" $_installed_pkgs
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
            if contains -- "$pkg" $_installed_pkgs
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
    # LVM detection: skip lvm2-monitor.service mask check when LVM volumes are active (mirrors _ry_do_check L3725)
    set -l _verify_has_lvm false
    set -l _pvs_out (timeout 5 sudo -n pvs --noheadings 2>/dev/null | string trim --)
    if test -n "$_pvs_out"
        set _verify_has_lvm true
    end
    # Batch systemctl show replaces N individual is-enabled+cat calls; string collect preserves blank-line delimiters
    set -l _mask_raw (systemctl show --property=LoadState,UnitFileState -- $MASK 2>/dev/null | string collect --no-trim-newlines)
    set -l _mask_parsed (_parse_systemctl_show "$_mask_raw")
    if test (count $_mask_parsed) -lt (count $MASK)
        _warn "  systemctl show returned incomplete mask data ("(count $_mask_parsed)" of "(count $MASK)" records)"
        _log "SYSTEMCTL_SHOW_MASK_PARTIAL: got="(count $_mask_parsed)" expected="(count $MASK)
        # Fallback: per-unit query to avoid positional misattribution
        for _svc in $MASK
            if test "$_svc" = lvm2-monitor.service; and test "$_verify_has_lvm" = true
                _info "  $_svc: skipped (LVM volumes active)"
                continue
            end
            set -l _state (systemctl is-enabled "$_svc" 2>/dev/null)
            switch "$_state"
                case masked
                    _ok "  $_svc: masked"
                case not-found
                    _info "  $_svc: unit not found (may not be installed)"
                case '*'
                    _fail "  $_svc: $_state (expected: masked)"
            end
        end
    else
        for _mask_idx in (seq 1 (count $MASK))
            set -l _svc $MASK[$_mask_idx]
            if test "$_svc" = lvm2-monitor.service; and test "$_verify_has_lvm" = true
                _info "  $_svc: skipped (LVM volumes active)"
                continue
            end
            set -l _rec (string split -- ':' -- "$_mask_parsed[$_mask_idx]")
            if test "$_rec[1]" = not-found
                _info "  $_svc: unit not found (may not be installed)"
            else if test "$_rec[3]" = masked
                _ok "  $_svc: masked"
            else
                _fail "  $_svc: $_rec[3] (expected: masked)"
            end
        end
    end
    _echo

    _echo "SYNTAX VALIDATION"
    _echo

    _echo "── mkinitcpio hooks ──"
    set -l hooks_line (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^#' | head -n 1)
    if test -n "$hooks_line"
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_line")
        _ry_validate_mkinitcpio_hooks --existence-only (string split ' ' -- "$hooks_str")
    else
        _warn "  Could not parse HOOKS from mkinitcpio.conf"
    end
    _echo

    _echo "── systemd units ──"
    for unit in $SERVICE_DESTINATIONS
        test -f "$unit"; and _verify_unit_syntax "$unit" (basename -- "$unit")
    end
    set -l user_svc "$HOME/.config/systemd/user/ssh-agent.service"
    test -f "$user_svc"; and _verify_unit_syntax "$user_svc" "ssh-agent.service (user)"
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

    # B-2: Pre-generate expected content + batched parallel hash verification (4 workers)
    set -l hash_dir (mktemp -d -t ry-hash-par.XXXXXX)
    if not test -d "$hash_dir"
        _err "Failed to create hash verification temp directory"
        set -g VERIFY_MODE false
        return 1
    end
    set -ga _TRACKED_TMPFILES "$hash_dir"
    set -l my_home "$HOME"

    # Filter destinations: skip iwd/NM configs when iwd not installed (uses pre-computed _skip_iwd)
    set -l hash_dsts
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test "$_skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                set -l safe (string replace -a '/' '_' -- "$dst")
                echo skip >"$hash_dir/result_$safe"
                continue
            end
        end
        set -a hash_dsts "$dst"
    end

    # Pre-generate expected content files (fast sequential printf)
    for dst in $hash_dsts
        set -l safe (string replace -a '/' '_' -- "$dst")
        _ry_get_file_content "$dst" >"$hash_dir/expected_$safe" 2>/dev/null
    end

    # Pre-serialize installed file hashes in parent (sudo timestamp_type=ppid doesn't propagate to children)
    for dst in $hash_dsts
        set -l safe (string replace -a '/' '_' -- "$dst")
        if string match -q "$my_home/*" -- "$dst"
            if test -r "$dst"
                sha256sum <"$dst" 2>/dev/null | string split -- ' ' | head -n 1 >"$hash_dir/installed_$safe"
            end
        else
            if sudo -n test -r "$dst" 2>/dev/null
                sudo -n cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ' | head -n 1 >"$hash_dir/installed_$safe"
            end
        end
    end

    # Serialize destination list for children; batch into min(4, nproc) workers
    printf '%s\n' $hash_dsts >"$hash_dir/dst_list"
    set -l total_dsts (count $hash_dsts)
    set -l _nproc_hash (nproc 2>/dev/null)
    if test -z "$_nproc_hash"; or not string match -qr '^\d+$' -- "$_nproc_hash"
        set _nproc_hash 4
    end
    set -l num_workers (math "min(4, $_nproc_hash)")
    if test $total_dsts -lt $num_workers
        set num_workers $total_dsts
    end
    if test $num_workers -le 0
        set num_workers 1
    end
    set -l batch_size (math "ceil($total_dsts / $num_workers)")

    set -l hash_pids
    for worker in (seq 1 $num_workers)
        set -l start_idx (math "($worker - 1) * $batch_size + 1")
        set -l end_idx (math "min($worker * $batch_size, $total_dsts)")
        if test $start_idx -gt $total_dsts
            continue
        end
        fish -c '
            set -l hash_dir $argv[1]
            set -l start_idx $argv[2]
            set -l end_idx $argv[3]
            set -l all_dsts (command cat -- "$hash_dir/dst_list")
            for idx in (seq $start_idx $end_idx)
                set -l dst $all_dsts[$idx]
                test -n "$dst"; or continue
                set -l safe (string replace -a "/" "_" -- "$dst")
                if not test -s "$hash_dir/expected_$safe"
                    echo skip > "$hash_dir/result_$safe"
                    continue
                end
                set -l expected_hash (sha256sum < "$hash_dir/expected_$safe" | string split -- " ")[1]
                set -l installed_hash (string trim -- (command cat -- "$hash_dir/installed_$safe" 2>/dev/null))
                if test -z "$installed_hash"
                    echo skip > "$hash_dir/result_$safe"
                else if test "$expected_hash" = "$installed_hash"
                    echo pass > "$hash_dir/result_$safe"
                else
                    echo fail > "$hash_dir/result_$safe"
                end
            end
        ' -- "$hash_dir" "$start_idx" "$end_idx" 2>"$hash_dir/worker_$worker.stderr" &
        set -a hash_pids $last_pid
    end

    test (count $hash_pids) -gt 0; and wait $hash_pids

    # Log any worker stderr (child crash diagnostics)
    for worker in (seq 1 $num_workers)
        if test -s "$hash_dir/worker_$worker.stderr"
            _log "HASH_WORKER_STDERR(worker $worker): "(head -n 5 "$hash_dir/worker_$worker.stderr")
        end
    end

    # Collect results in deterministic order
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l safe (string replace -a '/' '_' -- "$dst")
        set -l result (command cat -- "$hash_dir/result_$safe" 2>/dev/null)
        switch "$result"
            case pass
                _ok "  $dst: checksum match"
            case fail
                _fail "  $dst: checksum MISMATCH"
            case skip
                # Intentional skip (no expected content, file unreadable, or NM/IWD not installed)
            case ''
                # Empty or missing result file — child likely crashed; must be FAIL (unverified ≠ passed)
                _fail "  $dst: verification incomplete (no result from hash job)"
        end
    end
    command rm -rf --preserve-root -- "$hash_dir"
    _echo

    _log "=== STATIC VERIFICATION END ==="

    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

# Silent idempotency probe — exit 0 if clean, EXIT_DRIFT if drifted
function _ry_do_check --description "Silent idempotency probe — exit 0 if clean, EXIT_DRIFT if drifted"
    set -l drift false
    set -l checked 0

    # Pre-cache sudo for parallel children; avoid "if not sudo -n true" — Fish's "not" on unknown commands silently inverts
    set -l _sudo_ok false
    if command -q sudo; and sudo -n true 2>/dev/null
        set _sudo_ok true
    end
    if test "$_sudo_ok" = false
        _log "CHECK_DRIFT: sudo not cached"
        return $EXIT_DRIFT
    end

    # Pre-generate content files (prereq 1)
    set -l content_dir (_pregenerate_content_files)
    if not test -d "$content_dir"
        _log "CHECK_DRIFT: content pregeneration failed"
        return $EXIT_DRIFT
    end

    # Determine iwd skip list
    set -l skip_iwd false
    if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
        set skip_iwd true
    end

    set -l result_dir (mktemp -d -t ry-check-parallel.XXXXXX)
    if not test -d "$result_dir"
        _log "CHECK_DRIFT: mktemp failed"
        return $EXIT_DRIFT
    end
    set -ga _TRACKED_TMPFILES "$result_dir"
    set -l my_home "$HOME"
    set -l boot_fstype (findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)
    set -l my_user (id -un)
    set -l my_group (id -gn)

    # Serialize destination lists to files for children
    printf '%s\n' $SYSTEM_DESTINATIONS >"$result_dir/sys_dsts"
    printf '%s\n' $USER_DESTINATIONS >"$result_dir/usr_dsts"
    printf '%s\n' $SERVICE_DESTINATIONS >"$result_dir/svc_dsts"
    # Serialize service/mask lists for Job 4 (avoids interpolation into fish -c strings)
    printf '%s\n' $EXPECTED_SERVICES >"$result_dir/exp_svcs"
    printf '%s\n' $MASK >"$result_dir/mask_units"
    # Implicit service dependencies not in EXPECTED_SERVICES (checked by _ry_verify_runtime)
    printf '%s\n' systemd-resolved.service NetworkManager-dispatcher.service >"$result_dir/implicit_svcs"

    # Pre-serialize installed file hashes+permissions in parent (sudo timestamp_type=ppid doesn't propagate to children)
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test "$skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                continue
            end
        end
        set -l safe (string replace -a '/' '_' -- "$dst")
        if string match -q "$my_home/*" -- "$dst"
            if test -r "$dst"
                sha256sum <"$dst" 2>/dev/null | string split -- ' ' | head -n 1 >"$result_dir/hash_$safe"
                stat -c '%a %U:%G' -- "$dst" 2>/dev/null >"$result_dir/perm_$safe"
            end
        else
            if sudo -n test -r "$dst" 2>/dev/null
                sudo -n cat -- "$dst" 2>/dev/null | sha256sum | string split -- ' ' | head -n 1 >"$result_dir/hash_$safe"
            end
            if sudo -n test -e "$dst" 2>/dev/null
                sudo -n stat -c '%a %U:%G' -- "$dst" 2>/dev/null >"$result_dir/perm_$safe"
            end
        end
    end

    # Pre-serialize LVM state (sudo pvs) in parent for Job 4
    set -l _has_lvm false
    set -l pvs_output (timeout 5 sudo -n pvs --noheadings 2>/dev/null | string trim --)
    if test -n "$pvs_output"
        set _has_lvm true
    end
    echo $_has_lvm >"$result_dir/has_lvm"

    # ── Job 1: file content hashes (parallel) — reads pre-serialized hashes from parent ──
    fish -c '
        set -l result_dir $argv[1]; set -l content_dir $argv[2]; set -l skip_iwd $argv[3]; set -l my_home $argv[4]
        set -l drift false
        set -l checked 0
        set -l sys_dsts (command cat -- "$result_dir/sys_dsts")
        set -l usr_dsts (command cat -- "$result_dir/usr_dsts")
        set -l svc_dsts (command cat -- "$result_dir/svc_dsts")
        for dst in $sys_dsts $usr_dsts $svc_dsts
            if string match -q "*nm.conf" -- "$dst"; or string match -q "*/iwd/*" -- "$dst"
                if test "$skip_iwd" = true
                    continue
                end
            end
            set -l safe (string replace -a "/" "_" -- "$dst")
            if not test -s "$content_dir/$safe"
                continue
            end
            set -l expected_hash (sha256sum < "$content_dir/$safe" | string split -- " ")[1]
            set -l installed_hash (string trim -- (command cat -- "$result_dir/hash_$safe" 2>/dev/null))
            if test -z "$installed_hash"
                set drift true
                continue
            end
            if test "$expected_hash" != "$installed_hash"
                set drift true
            end
            set checked (math $checked + 1)
        end
        echo $drift > "$result_dir/hash_drift"
        echo $checked > "$result_dir/hash_checked"
    ' -- "$result_dir" "$content_dir" "$skip_iwd" "$my_home" 2>"$result_dir/hash.stderr" &
    set -l pid_hash $last_pid

    # ── Job 2: file permissions (parallel) — reads pre-serialized perms from parent ──
    fish -c '
        set -l result_dir $argv[1]; set -l boot_fstype $argv[2]; set -l my_user $argv[3]; set -l my_group $argv[4]
        set -l drift false
        set -l sys_dsts (command cat -- "$result_dir/sys_dsts")
        set -l svc_dsts (command cat -- "$result_dir/svc_dsts")
        set -l usr_dsts (command cat -- "$result_dir/usr_dsts")
        for dst in $sys_dsts $svc_dsts
            set -l safe (string replace -a "/" "_" -- "$dst")
            set -l perms (string trim -- (command cat -- "$result_dir/perm_$safe" 2>/dev/null))
            if test -z "$perms"
                continue
            end
            if string match -q "/boot/*" -- "$dst"
                if test "$boot_fstype" = vfat
                    continue
                end
            end
            if test "$perms" != "644 root:root"
                set drift true
            end
        end
        for dst in $usr_dsts
            set -l safe (string replace -a "/" "_" -- "$dst")
            set -l perms (string trim -- (command cat -- "$result_dir/perm_$safe" 2>/dev/null))
            if test -z "$perms"
                continue
            end
            if test "$perms" != "600 $my_user:$my_group"
                set drift true
            end
        end
        echo $drift > "$result_dir/perm_drift"
    ' -- "$result_dir" "$boot_fstype" "$my_user" "$my_group" 2>"$result_dir/perm.stderr" &
    set -l pid_perm $last_pid

    printf '%s\n' $KERNEL_PARAMS >"$result_dir/kparams"

    # ── Job 3: kernel params (parallel) — no sudo needed ──
    fish -c '
        set -l result_dir $argv[1]
        set -l drift false
        set -l cmdline (command cat -- /proc/cmdline 2>/dev/null)
        set -l kparams (command cat -- "$result_dir/kparams")
        if test -n "$cmdline"
            for param in $kparams
                if not string match -q -- "* $param *" " $cmdline "
                    set drift true
                end
            end
        end
        echo $drift > "$result_dir/kparam_drift"
    ' -- "$result_dir" 2>"$result_dir/kparam.stderr" &
    set -l pid_kparam $last_pid

    # Job 4: service state — batch systemctl show (parallel); LVM pre-serialized by parent Pre-parse systemctl show in parent (child can't call _parse_systemctl_show)
    set -l _all_check_units (command cat -- "$result_dir/exp_svcs") (command cat -- "$result_dir/mask_units") (command cat -- "$result_dir/implicit_svcs" 2>/dev/null)
    set -l _check_show (systemctl show --property=LoadState,ActiveState,UnitFileState -- $_all_check_units 2>/dev/null | string collect --no-trim-newlines)
    set -l _check_parsed (_parse_systemctl_show "$_check_show")
    printf '%s\n' $_check_parsed >"$result_dir/parsed_units"
    fish -c '
        set -l result_dir $argv[1]
        set -l drift false
        # Read serialized lists from files (safe for names with quotes/backslashes)
        set -l exp_svcs (command cat -- "$result_dir/exp_svcs")
        set -l mask_units (command cat -- "$result_dir/mask_units")
        set -l implicit_svcs (command cat -- "$result_dir/implicit_svcs" 2>/dev/null)
        # Read pre-parsed results from parent (eliminates duplicated _parse_systemctl_show)
        set -l results (command cat -- "$result_dir/parsed_units" 2>/dev/null)

        # Check expected services (first N results) Timer units: ActiveState=active (waiting for next trigger); never exited Oneshot services (RemainAfterExit): ActiveState=exited after successful run
        set -l exp_count (count $exp_svcs)
        for i in (seq 1 $exp_count)
            set -l rec (string split -- ":" $results[$i])
            if test "$rec[1]" = not-found
                set drift true
            else if string match -q '*.timer' -- "$exp_svcs[$i]"
                # Timers must be active (registered); exited would be abnormal
                if test "$rec[2]" != active
                    set drift true
                else if test "$rec[3]" != enabled
                    set drift true
                end
            else if test "$rec[2]" != active; and test "$rec[2]" != exited
                set drift true
            else if test "$rec[3]" != enabled
                set drift true
            end
        end

        # LVM state pre-serialized by parent (sudo pvs requires parent credential)
        set -l has_lvm (string trim -- (command cat -- "$result_dir/has_lvm" 2>/dev/null))

        # Check masked services (next M results)
        set -l mask_count (count $mask_units)
        for i in (seq 1 $mask_count)
            set -l ri (math $exp_count + $i)
            if test "$mask_units[$i]" = lvm2-monitor.service; and test "$has_lvm" = true
                continue
            end
            set -l rec (string split -- ":" $results[$ri])
            # Unit not found (package removed) is not drift — matches _ry_verify_static behavior
            if test "$rec[1]" = not-found
                continue
            end
            if test "$rec[3]" != masked
                set drift true
            end
        end

        # Check implicit service dependencies (remaining results after exp+mask)
        set -l implicit_offset (math $exp_count + $mask_count)
        for i in (seq 1 (count $implicit_svcs))
            set -l ri (math $implicit_offset + $i)
            if test $ri -gt (count $results)
                continue
            end
            set -l rec (string split -- ":" $results[$ri])
            # Not-found is not drift (package may not be installed)
            if test "$rec[1]" = not-found
                continue
            end
            # Must be enabled; active state varies (NM-dispatcher may be inactive when idle)
            if test "$rec[3]" != enabled
                set drift true
            end
        end
        echo $drift > "$result_dir/svc_drift"
    ' -- "$result_dir" 2>"$result_dir/svc.stderr" &
    set -l pid_svc $last_pid

    wait $pid_hash $pid_perm $pid_kparam $pid_svc

    # User-scope ssh-agent check (must run in parent for D-Bus session access)
    set -l _ssh_unit_file "$HOME/.config/systemd/user/ssh-agent.service"
    if test -f "$_ssh_unit_file"
        set -l _ssh_state (systemctl --user is-enabled ssh-agent.service 2>/dev/null)
        if test "$_ssh_state" != enabled
            set drift true
        end
    end

    # Merge results — treat missing result files as child crash (prevents false-negative)
    for phase in hash perm kparam svc
        set -l _drift_file "$result_dir/"$phase"_drift"
        # Log stderr from ALL children for diagnostics (not just crashes)
        if test -s "$result_dir/"$phase".stderr"
            _log "CHECK_STDERR($phase): "(head -n 5 "$result_dir/"$phase".stderr")
        end
        if not test -f "$_drift_file"
            _log "CHECK_DRIFT: child '$phase' crashed without writing results"
            set drift true
        else
            set -l result (command cat -- "$_drift_file" 2>/dev/null)
            if test "$result" = true
                set drift true
            else if test "$result" != false
                # Empty or malformed result file — child crashed mid-write
                _log "CHECK_DRIFT: child '$phase' wrote malformed result: '$result'"
                set drift true
            end
        end
    end
    set checked (command cat -- "$result_dir/hash_checked" 2>/dev/null)
    if test -z "$checked"; or not string match -qr '^\d+$' -- "$checked"
        set checked 0
    end

    command rm -rf --preserve-root -- "$result_dir" "$content_dir"

    test "$drift" = true; and return $EXIT_DRIFT

    # Guard against false negative: if no files could be checked (missing sudo, mktemp failures), report drift
    if test $checked -eq 0
        _log "CHECK_DRIFT: no files could be checked (all skipped)"
        return $EXIT_DRIFT
    end

    return $EXIT_OK
end


# Read CPU governor and current frequency from cpufreq sysfs
function _gather_cpu_state --description "Collect CPU governor and frequency state"
    set -g _CPU_PATH ""
    set -g _CPU_GOVERNOR ""
    set -g _CPU_EPP ""
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq
        if test -d "$cpu_dir"
            set -g _CPU_PATH "$cpu_dir"
            set -g _CPU_GOVERNOR (command cat -- "$cpu_dir/scaling_governor" 2>/dev/null)
            set -g _CPU_EPP (command cat -- "$cpu_dir/energy_performance_preference" 2>/dev/null)
            break
        end
    end
    return 0
end


# ═══ RUNTIME VERIFICATION — live sysfs/procfs state checks; exit 1 when state doesn't match config.
function _ry_verify_runtime --description "Verify runtime kernel params, services, and modules"
    _log "=== RUNTIME VERIFICATION START ==="

    _ensure_sudo_cached; or begin
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

    set -l cmdline (command cat -- /proc/cmdline 2>/dev/null)
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

    # This loop validates ALL cards for compliance
    _echo "── GPU performance level ──"
    set -l gpu_ok false
    set -l found_gpu false
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set found_gpu true
            set -l level (command cat -- "$f" 2>/dev/null)
            if test "$level" = auto
                _ok "  $f: $level"
                set gpu_ok true
            else
                _fail "  $f: $level (expected: auto)"
            end
        end
    end

    if test "$found_gpu" = false
        _warn "  No GPU DPM sysfs entries found"
    else if test "$gpu_ok" = false
        _warn "  GPU not at 'auto' - enable amdgpu-performance.service"
    end
    _echo

    _echo "── ReBAR/SAM status ──"
    set -l rebar_status (sudo dmesg 2>/dev/null | grep -i 'BAR' | grep -i -E 'resize|rebar|large|above.4g' | head -n 1)
    if test -n "$rebar_status"
        if string match -qi '*enabled*' -- "$rebar_status"; or string match -qi '*resiz*' -- "$rebar_status"
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

    _echo "── BIOS VRAM carveout ──"
    set -l _vram_bytes 0
    for f in /sys/class/drm/card*/device/mem_info_vram_total
        if test -f "$f"
            set _vram_bytes (command cat -- "$f" 2>/dev/null | string trim --)
            break
        end
    end
    if test "$_vram_bytes" -gt 0 2>/dev/null
        set -l _vram_mb (math "$_vram_bytes / 1048576")
        if test "$_vram_mb" -le 1024
            _ok "  VRAM carveout: $_vram_mb MB"
        else
            _warn "  VRAM carveout: $_vram_mb MB (recommended: ≤1024 MB for UMA — check BIOS)"
        end
    else
        _info "  VRAM carveout: cannot read mem_info_vram_total"
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
            set -l sysfs_val (command cat -- "$_CPU_PATH/$parts[1]" 2>/dev/null)

            if test "$sysfs_val" = "$parts[2]"
                _ok "  $parts[3]: $sysfs_val"
            else
                _fail "  $parts[3]: $sysfs_val (expected: $parts[2])"
            end
        end
    end
    _echo

    _echo "── amd_pstate / CPU boost ──"
    # §10 #7: amd_pstate status (complements scaling_driver check above)
    if test -f /sys/devices/system/cpu/amd_pstate/status
        set -l _pstate_status (command cat -- /sys/devices/system/cpu/amd_pstate/status 2>/dev/null | string trim --)
        if test "$_pstate_status" = active
            _ok "  amd_pstate status: $_pstate_status"
        else
            _fail "  amd_pstate status: $_pstate_status (expected: active)"
        end
    else
        _info "  amd_pstate status: sysfs not available"
    end
    # §10 #8: prefcore
    if test -f /sys/devices/system/cpu/amd_pstate/prefcore
        set -l _prefcore (command cat -- /sys/devices/system/cpu/amd_pstate/prefcore 2>/dev/null | string trim --)
        if test "$_prefcore" = enabled
            _ok "  amd_pstate prefcore: $_prefcore"
        else
            _fail "  amd_pstate prefcore: $_prefcore (expected: enabled)"
        end
    end
    # §10 #9: CPU boost
    if test -f /sys/devices/system/cpu/cpufreq/boost
        set -l _boost (command cat -- /sys/devices/system/cpu/cpufreq/boost 2>/dev/null | string trim --)
        if test "$_boost" = 1
            _ok "  CPU boost: $_boost"
        else
            _fail "  CPU boost: $_boost (expected: 1)"
        end
    end
    _echo

    _echo "MODULE STATE"
    _echo

    _echo "── Module parameters ──"
    # btusb check removed — usbcore.autosuspend=-1 handles globally

    if test -f /sys/module/usbcore/parameters/autosuspend
        set -l sysfs_val (command cat -- /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
        if test "$sysfs_val" = -1
            _ok "  usbcore.autosuspend: $sysfs_val"
        else
            _fail "  usbcore.autosuspend: $sysfs_val (expected: -1)"
        end
    end

    if test -f /sys/module/nvme_core/parameters/default_ps_max_latency_us
        set -l sysfs_val (command cat -- /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null)
        if test "$sysfs_val" = 0
            _ok "  nvme_core.default_ps_max_latency_us: $sysfs_val"
        else
            _fail "  nvme_core.default_ps_max_latency_us: $sysfs_val (expected: 0)"
        end
    end

    if test -f /sys/module/nvme_core/parameters/multipath
        set -l sysfs_val (command cat -- /sys/module/nvme_core/parameters/multipath 2>/dev/null)
        if test "$sysfs_val" = N
            _ok "  nvme_core.multipath: $sysfs_val"
        else
            _fail "  nvme_core.multipath: $sysfs_val (expected: N)"
        end
    end

    if test -d /sys/module/amdgpu/parameters
        # Hex→decimal normalization: sysfs may return 0xfffd3fff or 4294787071
        for pair in "ppfeaturemask:0xfffd3fff" "cwsr_enable:0" "wbrf:0"
            set -l pname (string split ':' -- "$pair")[1]
            set -l expected (string split ':' -- "$pair")[2]
            set -l ppath /sys/module/amdgpu/parameters/$pname
            if test -f "$ppath"
                set -l sysfs_val (string trim -- (command cat -- "$ppath" 2>/dev/null))
                set -l sysfs_val_dec "$sysfs_val"
                set -l expected_dec "$expected"
                if string match -q '0x*' -- "$sysfs_val"
                    set sysfs_val_dec (printf '%d' "$sysfs_val" 2>/dev/null; or echo "$sysfs_val")
                end
                if string match -q '0x*' -- "$expected"
                    set expected_dec (printf '%d' "$expected" 2>/dev/null; or echo "$expected")
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
        set -l sysfs_val (command cat -- /sys/module/mt7925e/parameters/disable_aspm 2>/dev/null)
        if test "$sysfs_val" = Y; or test "$sysfs_val" = 1
            _ok "  mt7925e.disable_aspm: $sysfs_val"
        else
            _fail "  mt7925e.disable_aspm: $sysfs_val (expected: 1/Y)"
        end
    else if test -d /sys/module/mt7925e
        _info "  mt7925e: loaded but disable_aspm param not found"
    end

    # workqueue.power_efficient sysfs check (FN-02: was only verified in /proc/cmdline)
    if test -f /sys/module/workqueue/parameters/power_efficient
        set -l sysfs_val (command cat -- /sys/module/workqueue/parameters/power_efficient 2>/dev/null | string trim --)
        if test "$sysfs_val" = 0; or test "$sysfs_val" = N
            _ok "  workqueue.power_efficient: $sysfs_val"
        else
            _fail "  workqueue.power_efficient: $sysfs_val (expected: 0/N)"
        end
    end
    _echo

    _echo "SERVICE STATE"
    _echo

    # B-8a: Batch systemctl show — 1 system call replaces 9 individual calls
    set -l sys_units amdgpu-performance.service cpupower-epp.service \
        fstrim.timer systemd-resolved.service NetworkManager-dispatcher.service \
        NetworkManager.service
    set -l show_output (systemctl show --property=LoadState,ActiveState,UnitFileState -- $sys_units 2>/dev/null | string collect --no-trim-newlines)
    set -l parsed (_parse_systemctl_show "$show_output")

    # Index into parsed (LoadState:ActiveState:UnitFileState): 1=amdgpu-performance, 2=cpupower-epp, 3=fstrim, 4=resolved, 5=nm-dispatcher, 6=NetworkManager
    set -l _expected_unit_count (count $sys_units)
    if test (count $parsed) -lt $_expected_unit_count
        _warn "  systemctl show returned incomplete data ("(count $parsed)" of $_expected_unit_count records)"
        _log "SYSTEMCTL_SHOW_PARTIAL: got="(count $parsed)" expected=$_expected_unit_count"
        # Fallback: per-unit query to avoid positional misattribution
        for _svc in $sys_units
            set -l _unit_raw (systemctl show --property=LoadState,ActiveState,UnitFileState -- "$_svc" 2>/dev/null | string collect --no-trim-newlines)
            set -l _unit_parsed (_parse_systemctl_show "$_unit_raw")
            if test (count $_unit_parsed) -lt 1
                _warn "  $_svc: cannot query"
                continue
            end
            set -l _rec (string split -- ':' -- "$_unit_parsed[1]")
            if test "$_rec[1]" = not-found
                _info "  $_svc: unit not found (may not be installed)"
            else if test "$_rec[2]" = active; or test "$_rec[2]" = exited
                if test "$_rec[3]" = enabled
                    _ok "  $_svc: $_rec[2] (enabled)"
                else
                    _warn "  $_svc: $_rec[2] but $_rec[3] (won't persist)"
                end
            else
                _fail "  $_svc: $_rec[2] (expected: active)"
            end
        end
    else

        # amdgpu-performance.service
        set -l rec (string split -- ':' -- "$parsed[1]")
        if test "$rec[1]" = not-found
            _warn "  amdgpu-performance.service: not installed"
        else if test "$rec[2]" = active; or test "$rec[2]" = exited
            if test "$rec[3]" = enabled
                _ok "  amdgpu-performance.service: $rec[2] (enabled)"
            else
                _warn "  amdgpu-performance.service: $rec[2] but $rec[3] (won't persist)"
            end
        else if test -f /etc/systemd/system/amdgpu-performance.service
            _fail "  amdgpu-performance.service: $rec[2] (expected: active)"
        else
            _warn "  amdgpu-performance.service: not installed"
        end

        # cpupower-epp.service
        set -l rec (string split -- ':' -- "$parsed[2]")
        if test "$rec[1]" = not-found
            _warn "  cpupower-epp.service: not installed"
        else if test "$rec[2]" = active; or test "$rec[2]" = exited
            if test "$rec[3]" = enabled
                _ok "  cpupower-epp.service: $rec[2] (enabled)"
            else
                _warn "  cpupower-epp.service: $rec[2] but $rec[3] (won't persist)"
            end
        else if test -f /etc/systemd/system/cpupower-epp.service
            _fail "  cpupower-epp.service: $rec[2] (expected: active)"
        else
            _warn "  cpupower-epp.service: not installed"
        end

        # fstrim.timer
        set -l rec (string split -- ':' -- "$parsed[3]")
        if test "$rec[2]" = active
            if test "$rec[3]" = enabled
                _ok "  fstrim.timer: active (enabled)"
            else
                _warn "  fstrim.timer: active but $rec[3] (won't persist)"
            end
        else
            _fail "  fstrim.timer: NOT active"
        end

        # systemd-resolved
        set -l rec (string split -- ':' -- "$parsed[4]")
        if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
            if test "$rec[2]" = active
                _ok "  systemd-resolved: active"
            else
                _fail "  systemd-resolved: $rec[2] (expected: active — DNS may be broken)"
            end
        end

        # NetworkManager-dispatcher
        set -l rec (string split -- ':' -- "$parsed[5]")
        if test "$rec[3]" = enabled
            if test "$rec[2]" = active; or test "$rec[2]" = inactive
                _ok "  NetworkManager-dispatcher: $rec[3] ($rec[2])"
            else
                _warn "  NetworkManager-dispatcher: $rec[2] (enabled but unexpected state)"
            end
        else
            _fail "  NetworkManager-dispatcher: $rec[3] (expected: enabled)"
        end

        # NetworkManager
        set -l rec (string split -- ':' -- "$parsed[6]")
        if test "$rec[2]" = active
            if test "$rec[3]" = enabled
                _ok "  NetworkManager.service: active (enabled)"
            else
                _warn "  NetworkManager.service: active but $rec[3] (won't persist)"
            end
        else
            _fail "  NetworkManager.service: $rec[2] (expected: active)"
        end

        # guard: (count $parsed) -lt $_expected_unit_count
    end

    # User scope: 1 batch call for ssh-agent
    set -l user_show (systemctl --user show --property=LoadState,ActiveState,UnitFileState -- ssh-agent.service 2>/dev/null | string collect --no-trim-newlines)
    set -l user_parsed (_parse_systemctl_show "$user_show")
    if test (count $user_parsed) -lt 1
        _warn "  ssh-agent.service: systemctl --user show returned no data"
    else
        set -l rec (string split -- ':' -- "$user_parsed[1]")
        if test "$rec[2]" = active
            if test "$rec[3]" = enabled
                _ok "  ssh-agent.service: active (enabled)"
            else
                _warn "  ssh-agent.service: active but $rec[3] (won't persist)"
            end
        else if test -f "$HOME/.config/systemd/user/ssh-agent.service"
            _fail "  ssh-agent.service: $rec[2] (expected: active)"
        else
            _warn "  ssh-agent.service: not installed"
        end
        # guard: (count $user_parsed) -lt 1
    end

    if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"
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
            # environment.d vars require re-login to take effect; WARN not FAIL for unset (FP-02)
            _warn "  $var_name: NOT SET (re-login required for environment.d)"
        end
    end
    _echo

    _echo "── sysctl (vendor) ──"
    # Vendor-managed sysctl values (CachyOS 70-cachyos-settings.conf) — _warn on mismatch, not _fail
    set -l _sysctl_vendor \
        "kernel.split_lock_mitigate=0"
    for _sc in $_sysctl_vendor
        set -l _key (string split '=' -- "$_sc")[1]
        set -l _expected (string split '=' -- "$_sc")[2]
        set -l _proc_path (string replace -a '.' '/' -- "$_key")
        set -l _actual (command cat -- "/proc/sys/$_proc_path" 2>/dev/null | string trim --)
        if test "$_actual" = "$_expected"
            _ok "  $_key: $_actual (vendor)"
        else if test -n "$_actual"
            _warn "  $_key: $_actual (expected: $_expected, vendor-managed)"
        else
            _info "  $_key: not available"
        end
    end
    _echo

    _echo "── THP / KSM / ZRAM ──"
    # §10 #2: THP enabled
    if test -f /sys/kernel/mm/transparent_hugepage/enabled
        set -l _thp (command cat -- /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)
        if string match -q '*\[madvise\]*' -- "$_thp"
            _ok "  THP enabled: madvise"
        else
            set -l _active (string match -r '\[(\w+)\]' -- "$_thp")[2]
            _warn "  THP enabled: $_active (recommended: madvise — see README)"
        end
    end
    # §10 #3: THP defrag
    if test -f /sys/kernel/mm/transparent_hugepage/defrag
        set -l _defrag (command cat -- /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null)
        if string match -q '*\[defer+madvise\]*' -- "$_defrag"
            _ok "  THP defrag: defer+madvise"
        else
            set -l _active (string match -r '\[(\S+)\]' -- "$_defrag")[2]
            _warn "  THP defrag: $_active (recommended: defer+madvise)"
        end
    end
    # §10 #4: THP shrink_underused
    if test -f /sys/kernel/mm/transparent_hugepage/shrink_underused
        set -l _shrink (command cat -- /sys/kernel/mm/transparent_hugepage/shrink_underused 2>/dev/null | string trim --)
        if test "$_shrink" = 0
            _ok "  THP shrink_underused: 0"
        else
            _warn "  THP shrink_underused: $_shrink (recommended: 0)"
        end
    end
    # §10 #5: KSM run state
    if test -f /sys/kernel/mm/ksm/run
        set -l _ksm (command cat -- /sys/kernel/mm/ksm/run 2>/dev/null | string trim --)
        if test "$_ksm" = 0
            _ok "  KSM run: 0 (disabled)"
        else
            _warn "  KSM run: $_ksm (recommended: 0 — breaks THP, wastes CPU with 128 GB)"
        end
    end
    # §10 #6: ZRAM service state
    set -l _zram_state (systemctl is-enabled systemd-zram-setup@zram0.service 2>/dev/null | string trim --)
    if test "$_zram_state" = masked
        _ok "  ZRAM service: masked"
    else if test -n "$_zram_state"
        _warn "  ZRAM service: $_zram_state (expected: masked — 128 GB makes ZRAM pointless)"
    else
        _ok "  ZRAM service: not found (OK)"
    end
    _echo

    _echo "── ntsync support ──"
    set -l _ns (_ntsync_state)
    switch $_ns
        case loaded
            _ok "ntsync: /dev/ntsync exists"
        case builtin
            if test -c /dev/ntsync
                _ok "ntsync: built-in, /dev/ntsync exists"
            else
                _warn "ntsync: built-in (CONFIG_NTSYNC=y) but /dev/ntsync missing — check udev rules"
            end
        case loaded_nodev
            _warn "ntsync: module loaded but /dev/ntsync missing"
        case unavailable
            _info "ntsync: NOT available (kernel 6.14+ required)"
        case missing
            _info "ntsync: NOT available (module not loaded)"
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

    # §10 #1: E610 NVM firmware version (P0 — hang-under-load if < 1.30)
    _echo
    _echo "── E610 NVM firmware ──"
    if command -q ethtool
        set -l _e610_found false
        for iface_path in /sys/class/net/*/device/driver
            set -l _driver (basename (readlink -f "$iface_path" 2>/dev/null) 2>/dev/null)
            if test "$_driver" = ice
                set -l _iface (basename (dirname (dirname -- "$iface_path")))
                set -l _fw_ver (ethtool -i "$_iface" 2>/dev/null | grep '^firmware-version:' | string replace -r '^firmware-version:\s+' '')
                if test -n "$_fw_ver"
                    set _e610_found true
                    # Extract NVM version (format varies: "X.YY 0xABCDEF..." or similar)
                    set -l _nvm_major (string match -r '^(\d+)\.' -- "$_fw_ver")[2]
                    set -l _nvm_minor (string match -r '^\d+\.(\d+)' -- "$_fw_ver")[2]
                    if test -n "$_nvm_major"; and test -n "$_nvm_minor"
                        set -l _nvm_combined (math "$_nvm_major * 100 + $_nvm_minor")
                        if test "$_nvm_combined" -ge 130
                            _ok "  $_iface E610 NVM: $_fw_ver (≥ 1.30)"
                        else
                            _fail "  $_iface E610 NVM: $_fw_ver (REQUIRED: ≥ 1.30 — update via Intel NVM Package or BIOS ≥ v1.08)"
                        end
                    else
                        _info "  $_iface E610 firmware: $_fw_ver (cannot parse NVM version)"
                    end
                end
            end
        end
        if test "$_e610_found" = false
            _info "  E610 NIC: not detected (ice driver not found)"
        end
    else
        _info "  ethtool not available for E610 NVM check"
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
                set -l perms (sudo stat -c '%a' -- "$conn_file" 2>/dev/null)
                set -l owner (sudo stat -c '%U:%G' -- "$conn_file" 2>/dev/null)
                if test "$perms" != 600; or test "$owner" != "root:root"
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
        if test "$perms" = 600; or test "$perms" = 644
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
    end
    _echo

    _echo "── Installed files ──"
    set -l perm_bad 0
    set -l perm_checked 0
    set -l _boot_fstype (findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo test -f "$dst" 2>/dev/null
            set perm_checked (math $perm_checked + 1)
            if string match -q '/boot/*' -- "$dst"; and test "$_boot_fstype" = vfat
                continue
            end
            set -l perms (sudo stat -c '%a' -- "$dst" 2>/dev/null)
            set -l owner (sudo stat -c '%U:%G' -- "$dst" 2>/dev/null)
            set -l expected_perms 644
            if test "$perms" != "$expected_perms"; or test "$owner" != "root:root"
                _fail "  $dst: $perms $owner (expected: $expected_perms root:root)"
                set perm_bad (math $perm_bad + 1)
            end
        end
    end
    set -l expected_owner (id -un)":"(id -gn)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            set -l perms (stat -c '%a' -- "$dst" 2>/dev/null)
            set -l owner (stat -c '%U:%G' -- "$dst" 2>/dev/null)
            if test "$perms" != 600; or test "$owner" != "$expected_owner"
                _fail "  $dst: $perms $owner (expected: 600 $expected_owner)"
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
    set -l dir_bad 0
    set -l dir_checked 0
    set -l checked_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if contains -- "$dir" $checked_dirs
            continue
        end
        set -a checked_dirs "$dir"
        if sudo test -d "$dir" 2>/dev/null
            set dir_checked (math $dir_checked + 1)
            set -l perms (sudo stat -c '%a' -- "$dir" 2>/dev/null)
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
        if test -n "$total_sec"; and string match -qr '^[0-9.]+$' -- "$total_sec"
            set -l target $BOOT_TIME_TARGET
            set -l time_int (printf "%.0f" (math "$total_sec") 2>/dev/null)
            if test -n "$time_int"; and test "$time_int" -lt $target
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
function _ry_do_lint --description "Lint the script source for fish anti-patterns and style issues"
    _log "=== LINT START ==="
    _info "Running fish syntax check..."
    _echo

    set -l script_path (status filename)

    if test "$script_path" != (status current-filename 2>/dev/null; or echo "$script_path")
        _warn "Script appears to be sourced; lint results may vary"
    end

    set -l has_errors false

    # Output function exclusions for anti-pattern checks (update when adding output functions)
    set -l _output_funcs '_fail|_ok|_warn|_info|_echo|_err|_dry|_msg'

    _echo "── Fish Syntax Check ──"
    if fish -n "$script_path"
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
            _fail "Fish_indent reports $drift_count lines of formatting drift"
            _info "  Run: fish_indent -w $script_path"
            set has_errors true
        end
    else
        _warn "Fish_indent not found — skipping formatting check"
    end
    _echo

    _echo "── Anti-pattern Check ──"

    set -l clean_content (sed '/^[[:space:]]*#/d; /# lint:ignore/d' "$script_path")

    # Exclude embedded bash in systemd ExecStart= (bash syntax is correct there)
    set -l bash_subst (printf '%s\n' $clean_content | grep -n '\$(' 2>/dev/null | grep -vE "ExecStart|/bin/bash|fish --version|'\\\$\\('|$_output_funcs" | head -n 20|| true)
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

    set -l bash_cond (printf '%s\n' $clean_content | grep -nE '(^|[[:space:];])\[\[[[:space:]]' 2>/dev/null | grep -vE "$_output_funcs"|| true)
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

    set -l bash_export (printf '%s\n' $clean_content | grep -n '^[[:space:]]*export ' 2>/dev/null; or true)
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

    set -l bash_logic (printf '%s\n' $clean_content | grep -nE '[^|]\|\|[^|]|[^&]&&[^&]' 2>/dev/null | grep -vE "printf|awk|sed|$_output_funcs|'.*&&|'.*\|\||NR >|~ /|/\\^"|| true)
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

    set -l bash_varexp (printf '%s\n' $clean_content | grep -nE '\$\{[a-zA-Z_]' 2>/dev/null | grep -vE "$_output_funcs|printf"|| true)
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

    set -l dead_pipe (printf '%s\n' $clean_content | grep -nE 'grep\s+-[a-zA-Z]*q[a-zA-Z]*\s.*\|' 2>/dev/null | grep -vE "$_output_funcs"; or true)
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

    # Scope shadow check: set -l in blocks can shadow outer vars; mawk-compatible, tracks piped while, anchored ^set -l filters false positives
    set -l shadow_hits (awk '
        /# lint:ignore/ { next }
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
                    if (depth > 0 && rest in vars) print NR": "$0  # lint:ignore
                    if (depth == 0) vars[rest] = 1
                }
            }
        }
    ' "$script_path" 2>/dev/null; or true)
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
    set -l changelog_path "$script_dir/CHANGELOG.txt"
    if test -f "$changelog_path"
        set -l changelog_ver (sed -n -- 's/^\([0-9][0-9.]*\) (.*/\1/p' "$changelog_path" | head -n 1)
        if test -n "$changelog_ver"
            if test "$changelog_ver" = "$VERSION"
                _ok "CHANGELOG version matches: v$VERSION"
            else
                _fail "CHANGELOG version mismatch: changelog=$changelog_ver global=$VERSION"
                set has_errors true
            end
        else
            _warn "Could not parse CHANGELOG version"
        end
    end

    set -l total (math (count $SYSTEM_DESTINATIONS) + (count $USER_DESTINATIONS) + (count $SERVICE_DESTINATIONS))
    # Count all case branches minus the wildcard case '*'; avoids $HOME expansion bugs in regex
    set -l _all_cases (sed -n -- '/^function _ry_get_file_content/,/^end$/p' "$script_path" | grep -c '^        case ')
    set -l case_count (math "$_all_cases - 1")
    if test $case_count -ge $total
        _ok "File count verified: $total destinations, $case_count content cases"
    else
        _fail "File count mismatch: $total destinations but $case_count content cases"
        set has_errors true
    end

    set -l steps_count (count $PROGRESS_STEPS)
    set -l progress_calls (sed -n -- '/^function _install_/,/^end$/p; /^function _ry_do_install/,/^end$/p' "$script_path" | grep -c '_progress "')
    if test $steps_count -eq $progress_calls
        _ok "Progress steps verified: $steps_count steps = $progress_calls calls"
    else
        _fail "Progress mismatch: PROGRESS_STEPS has $steps_count, but _ry_do_install has $progress_calls _progress calls"
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
        return $EXIT_LINT_FAIL
    else
        _ok "Lint check passed"
        return 0
    end
end


# Return path of most recently modified *.jsonl under ~/ry-install/logs/
function _find_latest_log --description "Find the most recent ry-install log file"
    set -l base "$HOME/ry-install/logs"
    test -d "$base"; or return 1
    command find "$base" -name '*.jsonl' -type f ! -path "$LOG_FILE" -printf '%T@\t%p\n' 2>/dev/null | sort -n | tail -n 1 | string replace -r -- '^[^\t]+\t' ''
    return 0
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
        set -l size (stat -c '%s' -- "$f" 2>/dev/null; or echo 0)
        set -l size_k (math "ceil($size / 1024)")

        set -l footer (grep -m1 '"event":"footer"' "$f" 2>/dev/null)
        set -l _log_exit ""
        set -l pass ""
        set -l fail ""
        set -l warn ""
        if test -n "$footer"
            set _log_exit (printf '%s' "$footer" | grep -oE '"exit_code":[0-9]+' | sed 's/.*://')
            set pass (printf '%s' "$footer" | grep -oE '"pass":[0-9]+' | sed 's/.*://')
            set fail (printf '%s' "$footer" | grep -oE '"fail":[0-9]+' | sed 's/.*://')
            set warn (printf '%s' "$footer" | grep -oE '"warn":[0-9]+' | sed 's/.*://')
        end

        set -l summary ""
        if test -n "$_log_exit"
            set -l result_mark "✓"
            if test "$_log_exit" != 0
                set result_mark "✗"
            end
            set summary (printf '  %s exit=%s' "$result_mark" "$_log_exit")
            if test -n "$pass"; or test -n "$fail"
                set summary "$summary pass=$pass fail=$fail warn=$warn"
            end
        else
            set summary "  ? (incomplete)"
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

    set -l header (grep -m1 '"event":"header"' "$log_path" 2>/dev/null)
    set -l mode ""
    set -l log_version ""
    set -l command ""
    set -l header_ts ""
    set -l dry_run ""
    if test -n "$header"
        set mode (printf '%s' "$header" | grep -oE '"mode":"[^"]+"' | cut -d'"' -f4)
        set log_version (printf '%s' "$header" | grep -oE '"version":"[^"]+"' | cut -d'"' -f4)
        set command (printf '%s' "$header" | grep -oE '"command":"[^"]+"' | cut -d'"' -f4)
        set header_ts (printf '%s' "$header" | grep -oE '"ts":"[^"]+"' | cut -d'"' -f4)
        set dry_run (printf '%s' "$header" | grep -oE '"dry_run":[a-z]+' | sed 's/.*://')
    end

    set -l footer (grep -m1 '"event":"footer"' "$log_path" 2>/dev/null)
    set -l _log_exit ""
    set -l pass 0
    set -l fail 0
    set -l warn_count 0
    set -l footer_ts ""
    set -l interrupted false
    if test -n "$footer"
        set _log_exit (printf '%s' "$footer" | grep -oE '"exit_code":[0-9]+' | sed 's/.*://')
        set pass (printf '%s' "$footer" | grep -oE '"pass":[0-9]+' | sed 's/.*://')
        set fail (printf '%s' "$footer" | grep -oE '"fail":[0-9]+' | sed 's/.*://')
        set warn_count (printf '%s' "$footer" | grep -oE '"warn":[0-9]+' | sed 's/.*://')
        set footer_ts (printf '%s' "$footer" | grep -oE '"finished":"[^"]+"' | cut -d'"' -f4)
        if string match -q '*"interrupted":true*' -- "$footer"
            set interrupted true
        end
    end

    set -l duration ""
    if test -n "$header_ts"; and test -n "$footer_ts"
        set -l start_epoch (date -d "$header_ts" +%s 2>/dev/null)
        set -l end_epoch (date -d "$footer_ts" +%s 2>/dev/null)
        if test -n "$start_epoch"; and test -n "$end_epoch"
            set -l secs (math "$end_epoch - $start_epoch")
            if test "$secs" -ge 60
                set duration (printf '%dm%ds' (math "floor($secs / 60)") (math "$secs % 60"))
            else
                set duration (printf '%ds' "$secs")
            end
        end
    end

    _echo "── Run Info ──"
    test -n "$mode"; and _echo "  Mode:    $mode"
    test -n "$log_version"; and _echo "  Version: $log_version"
    test -n "$header_ts"; and _echo "  Started: $header_ts"
    test -n "$duration"; and _echo "  Duration: $duration"
    test "$dry_run" = true; and _echo "  Dry run: yes"
    test "$interrupted" = true; and _echo "  Status:  INTERRUPTED"
    test -n "$command"; and _echo "  Command: $command"
    _echo

    _echo "── Results ──"
    if test -n "$_log_exit"
        if test "$_log_exit" = 0
            _ok "  Exit: 0 (success)"
        else if test "$_log_exit" = 129; or test "$_log_exit" = 130; or test "$_log_exit" = 131; or test "$_log_exit" = 141; or test "$_log_exit" = 143
            _warn "  Exit: $_log_exit (interrupted)"
        else
            _fail "  Exit: $_log_exit (failure)"
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

    set -l all_fails
    for _jline in (grep -E '"event":"fail"' "$log_path" 2>/dev/null)
        set -l _val (_jsonl_data "$_jline")
        test -n "$_val"; and set -a all_fails "$_val"
    end
    set -l all_warns
    for _jline in (grep -E '"event":"warn"' "$log_path" 2>/dev/null)
        set -l _val (_jsonl_data "$_jline")
        test -n "$_val"; and set -a all_warns "$_val"
    end
    set -l all_errs
    for _jline in (grep -E '"event":"err"' "$log_path" 2>/dev/null)
        set -l _val (_jsonl_data "$_jline")
        test -n "$_val"; and set -a all_errs "$_val"
    end
    set -l stderr_lines
    for _jline in (grep -E '"event":"stderr"' "$log_path" 2>/dev/null)
        set -l _val (_jsonl_data "$_jline")
        test -n "$_val"; and set -a stderr_lines "$_val"
    end

    if test (count $all_fails) -gt 0
        _echo "── Failures ──"
        printf '%s\n' $all_fails | LC_ALL=C sort -u | while read -l line
            test -n "$line"; and _fail "  $line"
        end
        _echo
    end

    if test (count $all_errs) -gt 0
        _echo "── Errors ──"
        printf '%s\n' $all_errs | LC_ALL=C sort -u | while read -l line
            test -n "$line"; and _err "  $line"
        end
        _echo
    end

    if test (count $all_warns) -gt 0
        _echo "── Warnings ──"
        printf '%s\n' $all_warns | LC_ALL=C sort -u | while read -l line
            test -n "$line"; and _warn "  $line"
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
            set -l sname (_jsonl_data "$line")
            set -l selap (printf '%s' "$line" | grep -oE '"elapsed_s":[0-9]+' | sed 's/.*://')
            test -z "$selap"; and set selap 0
            set total_step_s (math "$total_step_s + $selap")
            _echo (printf '  %-30s %ds' "$sname" "$selap")
        end
        _echo (printf '  %-30s %ds' "Total" "$total_step_s")
        _echo
    end

    if test "$mode" = test-all
        set -l test_ok
        for _jline in (grep '"event":"ok"' "$log_path" 2>/dev/null)
            set -l _val (_jsonl_data "$_jline")
            test -n "$_val"; and set -a test_ok "$_val"
        end
        set -l test_warns_ta
        for _jline in (grep '"event":"warn"' "$log_path" 2>/dev/null)
            set -l _val (_jsonl_data "$_jline")
            if test -n "$_val"; and string match -q '*exit code*' -- "$_val"
                set -a test_warns_ta "$_val"
            end
        end
        if test (count $test_ok) -gt 0; or test (count $test_warns_ta) -gt 0
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
        set -l diff_files
        for _jline in $diff_lines
            set -l _val (_jsonl_data "$_jline")
            if string match -q 'DIFF: *' -- "$_val"
                set -l _path (string replace -- 'DIFF: ' '' "$_val" | string split -- ':')[1]
                test -n "$_path"; and set -a diff_files "$_path"
            end
        end
        set diff_files (printf '%s\n' $diff_files | LC_ALL=C sort -u)
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
    set -l size (stat -c '%s' -- "$log_path" 2>/dev/null; or echo 0)
    _echo "  $line_count events, "(math "ceil($size / 1024)")" KB"

    test -n "$_log_exit"; and return "$_log_exit"
    return 0
end

# Route --logs subcommands: list, last, all, analyze <path>, system/gpu/wifi/boot/audio/usb/kernel.
function _logs_file_ops --argument-names target --description "Log viewer: analyze, last, list, all file operations"
    if test (count $argv) -lt 1
        _err "_logs_file_ops: expected at least 1 arg (target), got "(count $argv)
        return 1
    end
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
            set -l files (command find "$base" -name '*.jsonl' -type f ! -path "$LOG_FILE" -printf '%T@\t%p\n' 2>/dev/null | sort -n | string replace -r -- '^[^\t]+\t' '')
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

                set -l footer (grep -m1 '"event":"footer"' "$f" 2>/dev/null)
                set -l _log_exit ""
                set -l pass 0
                set -l fail 0
                set -l warn_c 0
                set -l interrupted false
                if test -n "$footer"
                    set _log_exit (printf '%s' "$footer" | grep -oE '"exit_code":[0-9]+' | sed 's/.*://')
                    set pass (printf '%s' "$footer" | grep -oE '"pass":[0-9]+' | sed 's/.*://')
                    set fail (printf '%s' "$footer" | grep -oE '"fail":[0-9]+' | sed 's/.*://')
                    set warn_c (printf '%s' "$footer" | grep -oE '"warn":[0-9]+' | sed 's/.*://')
                    string match -q '*"interrupted":true*' -- "$footer"; and set interrupted true
                    # Iterate all log files, compile pass/fail summary
                end

                test -n "$pass"; and string match -qr '^\d+$' -- "$pass"; and set total_pass (math "$total_pass + $pass")
                test -n "$fail"; and string match -qr '^\d+$' -- "$fail"; and set total_fail (math "$total_fail + $fail")
                test -n "$warn_c"; and string match -qr '^\d+$' -- "$warn_c"; and set total_warn (math "$total_warn + $warn_c")

                set -l all_fails
                for _jline in (grep -E '"event":"fail"' "$f" 2>/dev/null)
                    set -l _val (_jsonl_data "$_jline")
                    test -n "$_val"; and set -a all_fails "$_val"
                end

                set -l mark "✓"
                set -l incomplete false
                if test -z "$_log_exit"; and test "$interrupted" != true
                    set mark "?"
                    set incomplete true
                else if test -n "$_log_exit"; and test "$_log_exit" != 0
                    set mark "✗"
                    set -a failed_runs "$fdir/$fname"
                end
                if test "$interrupted" = true
                    set mark "⚡"
                end

                set -l suffix ""
                if test "$incomplete" = true
                    set suffix " (incomplete)"
                end
                set -l summary (printf '%s %-50s exit=%-3s pass=%-3s fail=%-3s warn=%s%s' "$mark" "$fdir/$fname" "$_log_exit" "$pass" "$fail" "$warn_c" "$suffix")
                _echo "  $summary"

                if test (count $all_fails) -gt 0
                    printf '%s\n' $all_fails | LC_ALL=C sort -u | while read -l line
                        test -n "$line"; and _echo "      ✗ $line"
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

            if test "$total_fail" -eq 0
                return 0
            end
            return 1
    end
end

# View journalctl logs filtered by target (system, gpu, wifi, boot, audio, usb, kernel)
function _logs_journal --argument-names target --description "Log viewer: system journal targets (system, gpu, wifi, boot, audio, usb, kernel)"
    if test (count $argv) -ne 1
        _err "_logs_journal: expected 1 arg (target), got "(count $argv)
        return 1
    end
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
            if command -q sudo
                set _log_lines (sudo dmesg 2>/dev/null | grep -iE "amdgpu|drm|radeon|gfx" | tail -n 50)
            else
                set _log_lines (dmesg 2>/dev/null | grep -iE "amdgpu|drm|radeon|gfx" | tail -n 50)
            end
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
            if command -q sudo
                set _log_lines (sudo dmesg 2>/dev/null | grep -iE "usb|hub" | grep -v "amdgpu" | tail -n 30)
            else
                set _log_lines (dmesg 2>/dev/null | grep -iE "usb|hub" | grep -v "amdgpu" | tail -n 30)
            end
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
            if command -q sudo
                set _log_lines (sudo dmesg --level=err 2>/dev/null | tail -n 30)
            else
                set _log_lines (dmesg --level=err 2>/dev/null | tail -n 30)
            end
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end
            _echo
            _echo "── dmesg warnings ──"
            if command -q sudo
                set _log_lines (sudo dmesg --level=warn 2>/dev/null | tail -n 30)
            else
                set _log_lines (dmesg --level=warn 2>/dev/null | tail -n 30)
            end
            if test (count $_log_lines) -gt 0
                for line in $_log_lines
                    _echo "$line"
                end
            else
                _echo "  (no output)"
            end
    end
end

# Dispatch --logs to file operations (analyze/last/list/all) or journal targets; fuzzy-match on typos
function _ry_do_logs --argument-names target --description "Browse, search, and analyze ry-install log files"
    if test (count $argv) -gt 2
        _err "_ry_do_logs: expected 0-2 args (target [arg]), got "(count $argv)
        return 2
    end
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
            return $status
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


# Install pipeline

# ═══ INSTALL PIPELINE — preflight → wifi → packages → files → services → boot → finalize ═══
function _install_collect_wifi --description "Interactively collect WiFi credentials for iwd setup"
    set -g WIFI_SSID ""
    set -g WIFI_PASS ""
    set -g WIFI_IFACE ""

    if test "$DRY" != true; and _ask "Reconnect WiFi at end of installation?"
        # Non-interactive: skip interface detection + credential prompts (avoids wasted nmcli/iwctl/sysfs I/O in --all pipe mode)
        if not isatty stdin
            _info "Non-interactive — skipping WiFi setup"
            return 0
        end
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
                            if($2 !~ /^-+$/) { print $2; exit }
                        }' | head -n 1)
                    if test -n "$wlan_iface"; and not test -d "/sys/class/net/$wlan_iface"
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
                if not isatty stdin
                    _warn "Non-interactive — skipping WiFi interface prompt"
                else
                    read -P "[?] Enter WiFi interface name: " wlan_iface
                    if not string match -qr '^[a-zA-Z0-9_]+$' -- "$wlan_iface"; or test (string length -- "$wlan_iface") -gt 15
                        _err "Invalid interface name: must be alphanumeric, max 15 chars"
                        set wlan_iface ""
                    else if not test -d "/sys/class/net/$wlan_iface"
                        _err "Interface '$wlan_iface' does not exist (check /sys/class/net/)"
                        set wlan_iface ""
                    end
                end
            end

            if test -n "$wlan_iface"
                set -g WIFI_IFACE "$wlan_iface"
                _info "WiFi interface: $wlan_iface"

                if not isatty stdin
                    _warn "Non-interactive — skipping WiFi credential prompts"
                else
                    read -P "[?] WiFi SSID: " wifi_ssid
                    if test -n "$wifi_ssid"
                        set -l _ssid_bad false
                        # Path separator (/) + GKeyFile special (\ ;) + subshell/expansion/redirect chars + quotes + printf % format
                        for _c in / '\\' ';' '`' '$' '(' ')' '{' '}' '|' '<' '>' "'" '"' '%'
                            if string match -q -- "*$_c*" "$wifi_ssid"
                                set _ssid_bad true
                                break
                            end
                        end
                        if test "$_ssid_bad" = true; or string match -qr '\\n|\\r' -- "$wifi_ssid"
                            _err "Invalid SSID: contains forbidden characters"
                            _info "SSIDs cannot contain path separators, quotes, subshell chars, or newlines"
                            _info "Workaround: skip WiFi setup here, then connect manually:"
                            _info "  nmcli device wifi connect '<SSID>' password '<pass>'"
                        else if string match -qr '^ | $' -- "$wifi_ssid"
                            _err "Invalid SSID: leading/trailing whitespace (GKeyFile trims unquoted values)"
                        else if test "$wifi_ssid" = "."; or test "$wifi_ssid" = ".."
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
                            else if test (printf '%s' "$wifi_pass" | wc -c) -lt 8; or test (printf '%s' "$wifi_pass" | wc -c) -gt 63
                                _err "Invalid passphrase: WPA2 requires 8-63 bytes"
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
    end
    return 0
end

# Pipeline phase 1: deps, disk, network, kernel version, config validation
function _install_preflight --description "Run all preflight checks before installation"
    _progress "Checking dependencies"

    if test "$DRY" = false
        _info "Sudo password required for installation..."
        if test "$ALL" = true
            printf '\n' >&2
        end
        if not command -q sudo
            _err "Sudo required for installation"
            return $EXIT_PREFLIGHT
        end
        sudo true; or begin
            _err "Sudo required for installation"
            return $EXIT_PREFLIGHT
        end
        # Matches: (ALL : ALL) ALL, (ALL) ALL, (ALL) NOPASSWD: ALL Does NOT match: (root) ALL — which IS genuinely restricted
        set -l sudo_all (sudo -n -l 2>/dev/null | grep -v '^\s*#' | grep -cE '\(ALL.*\) .*ALL$')
        or set sudo_all 0
        if test "$sudo_all" -eq 0
            if test "$ALL" = true
                _err "Restricted sudo incompatible with --all mode (unattended install requires full sudo)"
                # Verify critical paths exist before proceeding
                _kill_sudo_keepalive
                return $EXIT_PREFLIGHT
            end
            _warn "Restricted sudo detected — some operations may fail"
            _warn "Install requires unrestricted sudo for pacman, systemctl, mkinitcpio, etc."
        end
        set -l my_pid %self
        # Keepalive: refresh assumes credential timeout ≥5min (timestamp_timeout=5)
        fish -c 'while kill -0 -- $argv[1] 2>/dev/null; and test -d -- $argv[2]; sudo -n true 2>/dev/null; or break; sleep $argv[3]; end' -- $my_pid "$LOCK_DIR" $SUDO_KEEPALIVE_INTERVAL </dev/null &
        set -g SUDO_KEEPALIVE_PID $last_pid
        if not kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            _warn "Sudo keepalive process failed to start — long installs may require re-auth"
            set --erase SUDO_KEEPALIVE_PID
        else
            disown $SUDO_KEEPALIVE_PID 2>/dev/null
        end

        _ry_check_deps; or begin
            _kill_sudo_keepalive
            return $EXIT_PREFLIGHT
        end

        _ry_check_disk_space; or begin
            _kill_sudo_keepalive
            return $EXIT_PREFLIGHT
        end

        _ry_check_network; or begin
            _err "Network required for package installation — aborting"
            _kill_sudo_keepalive
            return $EXIT_PREFLIGHT
        end
    else
        _info "(dry-run) Skipping: sudo, disk space, network checks"
        _info "(dry-run) Skipping: LVM detection (no sudo credentials)"
    end

    if not _ry_check_kernel_version
        _warn "Kernel version below 6.14 — some features will not work"
        set -g INSTALL_HAD_ERRORS true
    end

    _echo
    _ry_validate_configs; or begin
        _err "Configuration validation failed - aborting"
        _kill_sudo_keepalive
        return $EXIT_PREFLIGHT
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

        if test "$DRY" = false
            if not _ry_install_file "/etc/mkinitcpio.conf" true
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
                else
                    set -g SYSTEM_UPGRADED true
                end
            else
                set -g SYSTEM_UPGRADED true
            end

            if test "$DRY" = false
                _info "Verifying package installation..."
                set -l missing_pkgs
                set -l _inst_check (pacman -Qq 2>/dev/null)
                for pkg in $pkgs_to_install
                    if not contains -- "$pkg" $_inst_check
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
    test "$_fn_err" = true; and return 1
    return 0
end

# Pipeline phase 4: deploy all SYSTEM/USER/SERVICE files via _ry_install_file with privilege elevation as needed
function _install_system_files --description "Deploy all embedded config files to the system"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress "Installing system files"
    _echo
    _info "Installing system configuration files..."
    if not _ry_install_files --sudo --desc "SYSTEM FILES" $SYSTEM_DESTINATIONS
        _err "System file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    _progress "Installing user files"
    _echo
    _info "Installing user configuration files..."
    if not _ry_install_files --desc "USER FILES" $USER_DESTINATIONS
        _err "User file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    _progress "AMDGPU performance service"
    _echo
    _info "AMDGPU performance service (STRONGLY RECOMMENDED)"
    _info "  Udev rule may fail due to timing (Arch bug #72655)"

    if _ask "Install amdgpu-performance.service?"
        if not _ry_install_file "/etc/systemd/system/amdgpu-performance.service" true
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
    test "$_fn_err" = true; and return 1
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

    _progress "Removing packages"
    set -l to_del
    if test "$DRY" = true
        set to_del $PKGS_DEL
    else
        # Batch: single pacman -Qq replaces N individual pacman -Qi calls
        set -l _del_installed (pacman -Qq 2>/dev/null)
        for pkg in $PKGS_DEL
            if contains -- "$pkg" $_del_installed
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
                # Re-query installed packages for TOCTOU: pkg may be removed between batch and retry
                set -l _retry_installed (pacman -Qq 2>/dev/null)
                for pkg in $to_del
                    if contains -- "$pkg" $_retry_installed
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

    if test "$has_lvm" = false; and test "$DRY" = false
        if not command -q sudo; or not sudo -n true 2>/dev/null
            _info "LVM detection may be incomplete (sudo not cached)"
        end
    end

    # Service masking: skip lvm2-monitor if LVM volumes detected to avoid breaking storage
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
    _progress "CPU performance service"
    _progress "Enabling timers"

    # B-7: Batch system-scope enable --now in --all mode
    if test "$ALL" = true
        set -l sys_enable

        # NM-dispatcher
        set -l nm_disp_state (systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null)
        if test "$nm_disp_state" = enabled
            _ok "NetworkManager-dispatcher.service: already enabled"
        else
            set -a sys_enable NetworkManager-dispatcher.service
        end

        # cpupower-epp: install file + daemon-reload first
        if not _ry_install_file "/etc/systemd/system/cpupower-epp.service" true
            _err "Failed to install cpupower-epp.service"
            set -g INSTALL_HAD_ERRORS true
            set _fn_err true
        else
            if not _run sudo systemctl daemon-reload
                _warn "Systemctl daemon-reload failed"
            end
            set -a sys_enable cpupower-epp.service
        end

        # fstrim.timer
        set -a sys_enable fstrim.timer

        # Batch enable all collected system units; fall back to per-unit on failure
        if test (count $sys_enable) -gt 0
            if not _run sudo systemctl enable --now -- $sys_enable
                _warn "Batch enable failed — retrying individually to identify failures"
                for _unit in $sys_enable
                    if not _run sudo systemctl enable --now -- $_unit
                        _err "Failed to enable: $_unit"
                        set -g INSTALL_HAD_ERRORS true
                        set _fn_err true
                    else
                        _ok "Enabled: $_unit"
                    end
                end
            end
        end

        # ssh-agent stays separate (user scope)
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
    else
        # Interactive mode: individual prompts (original behavior)
        set -l nm_disp_state (systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null)
        if test "$nm_disp_state" = enabled
            _ok "NetworkManager-dispatcher.service: already enabled"
        else if _ask "Enable NetworkManager-dispatcher.service?"
            if not _run sudo systemctl enable --now NetworkManager-dispatcher.service
                _warn "Failed to enable NetworkManager-dispatcher.service"
            end
        end

        if _ask "Install and enable cpupower-epp.service? (REQUIRED for performance mode)"
            if not _ry_install_file "/etc/systemd/system/cpupower-epp.service" true
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

        if _ask "Enable fstrim.timer?"
            if not _run sudo systemctl enable --now fstrim.timer
                _warn "Failed to enable fstrim.timer"
            end
        end

        # User-level services: ssh-agent socket activation + SSH_AUTH_SOCK propagation
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
    end
    test "$_fn_err" = true; and return 1
    return 0
end

# Post-rebuild safety gate: verify vmlinuz exists, initramfs non-zero, boot entry valid; block reboot on failure
function _preflight_boot_sanity --description "Verify boot artifacts are viable after rebuild"
    set -l errors 0
    # /boot (ESP, vfat) typically 700 root:root — use sudo for all access, consistent with _chk_file/_ry_verify_static

    # 1. At least one vmlinuz must exist
    set -l vmlinuz_files (sudo find /boot -maxdepth 1 -name 'vmlinuz-*' -type f 2>/dev/null)
    if test (count $vmlinuz_files) -eq 0
        _err "No vmlinuz found in /boot/"
        set errors (math $errors + 1)
    else
        for f in $vmlinuz_files
            sudo test -s "$f" 2>/dev/null
            if test $status -ne 0
                _err "Zero-byte kernel image: $f"
                set errors (math $errors + 1)
            end
        end
    end

    # 2. Every initramfs must be non-zero
    set -l initrd_files (sudo find /boot -maxdepth 1 -name 'initramfs-*.img' -type f 2>/dev/null)
    for f in $initrd_files
        sudo test -s "$f" 2>/dev/null
        if test $status -ne 0
            _err "Zero-byte initramfs: $f"
            set errors (math $errors + 1)
        end
    end

    # 3. At least one boot entry .conf must reference an existing kernel
    set -l confs (sudo find /boot/loader/entries -maxdepth 1 -name '*.conf' -type f 2>/dev/null)
    if test (count $confs) -eq 0
        _err "No boot loader entries in /boot/loader/entries/"
        set errors (math $errors + 1)
    else
        set -l valid_entry false
        for conf in $confs
            set -l linux_line (sudo grep -m1 '^linux ' -- "$conf" 2>/dev/null | string replace 'linux ' '' | string trim --)
            if test -n "$linux_line"; and sudo test -f "/boot$linux_line" 2>/dev/null
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

    # Order: syu → mkinitcpio → sdboot → boot_sanity; syu first so new kernel is present before mkinitcpio -P; explicit pass ensures our configs apply
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

    # mkinitcpio/sdboot failure in --all aborts to prevent unbootable system; interactive continues
    _progress "Rebuilding initramfs"
    if _ask "Rebuild initramfs?"
        if not _run sudo mkinitcpio -P
            _err "Mkinitcpio failed"
            set -g INSTALL_HAD_ERRORS true
            if test "$ALL" = true
                _err "CRITICAL: Boot rebuild failed in unattended mode — aborting remaining steps"
                return $EXIT_BOOT_CRIT
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
                return $EXIT_BOOT_CRIT
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
        if test -n "$entry_count"; and string match -qr '^\d+$' -- "$entry_count"; and test "$entry_count" -gt 0
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
                if test -n "$size_mb"; and string match -qr '^\d+$' -- "$size_mb"
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

    # Final boot viability gate: verify vmlinuz, initramfs, and boot entry exist
    if not _preflight_boot_sanity
        set -g INSTALL_HAD_ERRORS true
        if test "$ALL" = true
            _err "CRITICAL: Boot sanity failed in unattended mode — aborting remaining steps"
            return $EXIT_BOOT_CRIT
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
        if command -q pacman; and pacman -Qi iwd >/dev/null 2>&1
            _info "iwd will restart with NetworkManager (D-Bus disconnect expected)"
            if not _run sudo systemctl restart NetworkManager
                _warn "NetworkManager restart failed"
                set -g INSTALL_HAD_ERRORS true
            end
            if test "$DRY" = false; and test -n "$WIFI_SSID"
                # iwd needs time to re-register on D-Bus after NM restart before WiFi reconnect
                sleep $NM_RESTART_DELAY
            end
        else
            _err "Iwd package not installed"
            set -g INSTALL_HAD_ERRORS true
        end
    end

    _progress "WiFi reconnection"
    if test -n "$WIFI_SSID"; and test -n "$WIFI_IFACE"; and test -n "$WIFI_PASS"
        _info "Reconnecting WiFi: $WIFI_SSID on $WIFI_IFACE"

        if test "$DRY" = false
            set -l safe_filename (string replace -ra '[^a-zA-Z0-9._-]' '_' -- "$WIFI_SSID")
            set -l conn_file "/etc/NetworkManager/system-connections/$safe_filename.nmconnection"

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
                set -l _hex ""
                if command -q md5sum
                    set _hex (printf '%s-%s' "$WIFI_SSID" "$WIFI_IFACE" | md5sum | string split -- ' ')[1]
                end
                if test -z "$_hex"; or not string match -qr '^[0-9a-f]{32}$' -- "$_hex"
                    # Fallback: use /proc/sys/kernel/random/uuid if md5sum unavailable or failed
                    set _hex (string replace -a '-' '' -- (command cat -- /proc/sys/kernel/random/uuid 2>/dev/null))
                end
                if test -z "$_hex"; or test (string length -- "$_hex") -lt 32
                    set --erase WIFI_PASS
                    sudo rm -f -- "$tmpfile" 2>/dev/null
                    _err "Failed to generate UUID for WiFi connection (md5sum and /proc/sys/kernel/random/uuid unavailable)"
                    set -g INSTALL_HAD_ERRORS true
                else
                    set -l conn_uuid (string sub -l 8 -- $_hex)-(string sub -s 9 -l 4 -- $_hex)-(string sub -s 13 -l 4 -- $_hex)-(string sub -s 17 -l 4 -- $_hex)-(string sub -s 21 -l 12 -- $_hex)
                    # GKeyFile escapes via consolidated helper (single source of truth)
                    set -l safe_pass (_gkeyfile_escape "$WIFI_PASS")
                    set -l safe_ssid (_gkeyfile_escape "$WIFI_SSID")
                    # Inside DRY=false gate; credential write only occurs on live runs
                    printf '%s\n' "[connection]" "id=$safe_ssid" "uuid=$conn_uuid" "type=wifi" "interface-name=$WIFI_IFACE" "autoconnect=true" "[wifi]" "mode=infrastructure" "ssid=$safe_ssid" "[wifi-security]" "key-mgmt=wpa-psk" "psk=$safe_pass" "[ipv4]" "method=auto" "[ipv6]" "method=disabled" | sudo tee -- "$tmpfile" >/dev/null
                    set -l _wifi_ps $pipestatus
                    if test $_wifi_ps[1] -ne 0; or test $_wifi_ps[2] -ne 0
                        set --erase WIFI_PASS
                        sudo rm -f -- "$tmpfile" 2>/dev/null
                        _err "WiFi connection profile write failed"
                        set -g INSTALL_HAD_ERRORS true
                    else
                        set --erase WIFI_PASS
                        # Post-write symlink re-check: closes TOCTOU between pre-write test -L and tee
                        if sudo test -L "$tmpfile"
                            sudo rm -f -- "$tmpfile" 2>/dev/null
                            _err "Temp file replaced with symlink during write — aborting WiFi connection creation"
                            set -g INSTALL_HAD_ERRORS true
                        else if not _run sudo chmod -- 0600 "$tmpfile"
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
                                if command nmcli connection show "$WIFI_SSID" >/dev/null 2>&1
                                    break
                                end
                                set reload_wait (math $reload_wait + 1)
                                sleep $WIFI_CONNECT_WAIT
                                if test (math "$reload_wait % 3") -eq 0
                                    _run sudo nmcli connection load "$conn_file" 2>/dev/null
                                    _run nmcli device wifi rescan ifname "$WIFI_IFACE"
                                end
                            end
                            set -l wifi_retry 0
                            set -l wifi_connected false
                            while test $wifi_retry -lt 3; and test "$wifi_connected" = false
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
                    end
                end
            end
        else
            set --erase WIFI_PASS
            set -l safe_filename (string replace -ra '[^a-zA-Z0-9._-]' '_' -- "$WIFI_SSID")
            _dry "Create /etc/NetworkManager/system-connections/$safe_filename.nmconnection"
        end
    else if test -n "$WIFI_SSID"; and test -n "$WIFI_IFACE"
        _warn "WiFi reconnection skipped (empty passphrase)"
        test "$DRY" = false; and sleep $NM_RESTART_DELAY
    else if test -n "$WIFI_IFACE"
        _info "WiFi reconnection skipped (no credentials provided)"
        test "$DRY" = false; and sleep $NM_RESTART_DELAY
    end
    # Final credential erase — runs regardless of success/failure path
    set --erase WIFI_SSID
    set --erase WIFI_PASS
    set --erase WIFI_IFACE
    # Return 1 on partial failure so _ry_do_install can detect and report errors
    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end

# Orchestrator: runs all pipeline phases, collecting errors without aborting
function _ry_do_install --description "Full installation: preflight, packages, configs, services, boot"
    _log "=== INSTALLATION START ==="
    _log "VERSION: $VERSION"
    _log "DRY: $DRY"
    _log "ALL: $ALL"

    # Pre-declare _boot_rc at function scope — Fish's set -l inside a block scopes to THAT BLOCK, not the enclosing function
    set -l _boot_rc 0

    _echo
    _echo "ry-install v$VERSION"
    _echo

    if test "$DRY" = true
        _warn "DRY-RUN MODE - No changes will be made"
        _echo
    end

    # Check for orphaned files from previous install or profile switch
    _manifest_check_orphans

    _progress_init

    _install_preflight
    or return $EXIT_PREFLIGHT

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

    _install_rebuild_boot
    set _boot_rc $status
    if test $_boot_rc -ne 0
        set -g INSTALL_HAD_ERRORS true
    end

    # Boot-critical failure: skip WiFi/finalize — system may not boot; continuing would mask the failure
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
        _err "Boot-critical failure — skipping WiFi and finalization"
        _err "Fix boot issue first: sudo mkinitcpio -P && sudo sdboot-manage gen"
        _progress_skip "Finalizing system"
        _progress_skip "NetworkManager restart"
        _progress_skip "WiFi reconnection"
    else
        # Collect WiFi creds just before use to minimize WIFI_PASS global lifetime
        _install_collect_wifi

        if not _install_finalize
            set -g INSTALL_HAD_ERRORS true
        end
    end

    _ry_do_completions 2>/dev/null; or _warn "Completions install failed (run --completions manually)"

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
    _info "Post-reboot verification: ./ry-install.fish --verify-static; and ./ry-install.fish --verify-runtime"
    _echo

    if test "$INSTALL_HAD_ERRORS" = true
        _warn "Done (with warnings - see above)"
    else
        _ok "Done!"
    end

    _log "=== INSTALLATION END ==="
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
        _log "MANIFEST_SKIP: boot-critical failure — partial deploy not recorded"
        return $EXIT_BOOT_CRIT
    end
    _manifest_write; or set -g INSTALL_HAD_ERRORS true
    test "$INSTALL_HAD_ERRORS" = true; and return $EXIT_FAIL
    return $EXIT_OK
end

# Single-file install: deploy one managed config by destination path
function _ry_do_install_file --argument-names target --description "Install a single named config file interactively"
    if test (count $argv) -gt 1
        _err "_ry_do_install_file: expected 0-1 args (target), got "(count $argv)
        return 2
    end
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

    if test "$use_sudo" = true; and test "$DRY" = false
        if not command -q sudo
            _err "Sudo required"
            return 1
        end
        sudo true; or begin
            _err "Sudo required"
            return 1
        end
    end

    if _ry_install_file "$target" $use_sudo
        # Post-install: rebuild boot entries if target is a boot-related config
        _echo
        _ok "Installed: $target"

        if test "$DRY" = false
            if string match -q '/boot/*' -- "$target"; or string match -q '/etc/mkinitcpio*' -- "$target"; or string match -q '/etc/sdboot*' -- "$target"; or string match -q /etc/kernel/cmdline -- "$target"
                _echo
                if _ask "Rebuild initramfs and update bootloader?"
                    _run sudo mkinitcpio -P; or _warn "Mkinitcpio failed"
                    _run sudo sdboot-manage gen; or _warn "Sdboot-manage gen failed"
                    _run sudo sdboot-manage update; or _warn "Sdboot-manage update failed"
                end
            else if string match -q '*.service' -- "$target"
                if string match -q "$HOME/*" -- "$target"
                    _run systemctl --user daemon-reload; or _warn "Systemctl --user daemon-reload failed"
                    if _ask "Enable "(basename -- "$target")" (user)?"
                        if _run systemctl --user enable --now (basename -- "$target")
                            if string match -q '*ssh-agent*' -- "$target"; and set -q XDG_RUNTIME_DIR
                                _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                                or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
                            end
                        else
                            _warn "Failed to enable "(basename -- "$target")" (user)"
                        end
                    end
                else
                    _run sudo systemctl daemon-reload; or _warn "Systemctl daemon-reload failed"
                end
            else if string match -q '*/udev/rules.d/*' -- "$target"
                _echo
                if _ask "Reload udev rules?"
                    _run sudo udevadm control --reload-rules; or _warn "Udevadm reload-rules failed"
                    _run sudo udevadm trigger; or _warn "Udevadm trigger failed"
                    _run sudo udevadm settle --timeout=5; or _warn "Udevadm settle timed out"
                end
            else if string match -q '*/resolved.conf.d/*' -- "$target"
                _echo
                if _ask "Restart systemd-resolved?"
                    _run sudo systemctl restart systemd-resolved; or _warn "Systemd-resolved restart failed"
                end

            else if string match -q '*/logind.conf.d/*' -- "$target"
                _info "Logind config changed — reboot required (restarting logind kills all sessions)"

            else if string match -q '*/iwd/main.conf' -- "$target"; or string match -q '*/NetworkManager/conf.d/*' -- "$target"
                _echo
                if _ask "NetworkManager config changed — restart NetworkManager?"
                    _run sudo systemctl restart NetworkManager; or _warn "NetworkManager restart failed"
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
function _ry_do_completions --description "Generate fish shell completions for ry-install"
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
    set -ga _TRACKED_TMPFILES "$tmpfile"
    if test -L "$tmpfile"
        command rm -f -- "$tmpfile" 2>/dev/null
        _fail "Temp file is symlink — aborting completions install"
        return 1
    end

    # Build --install-file destination list at generation time
    set -l _install_file_targets (string join ' ' $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)

    # Header
    echo '# Fish completions for ry-install v'"$VERSION" >"$tmpfile"
    echo '# Generated by: ./ry-install.fish --completions' >>"$tmpfile"
    echo 'for cmd in ry-install ry-install.fish' >>"$tmpfile"
    echo '    complete -c $cmd -f' >>"$tmpfile"

    # Flag completions: "flags|description"
    set -l _comp_entries \
        '-s a -l all|Install without prompts (unattended mode)' \
        '-s f -l force|Auto-yes prompts without progress bar' \
        '-s V -l verbose|Show output on terminal' \
        '-s n -l dry-run|Preview changes without modifying system' \
        '-l diff|Compare embedded files against installed system' \
        '-l verify-static|Check config files exist with correct content' \
        '-l verify-runtime|Check live system state (run after reboot)' \
        '-l lint|Run fish syntax and anti-pattern checks' \
        '-l check|Silent idempotency probe (exit 0 = clean, exit 10 = drift)' \
        '-l test-all|Run all safe modes and generate NDJSON logs (test suite)' \
        '-l logs|View logs (system, gpu, wifi, boot, audio, usb, kernel, or service name)' \
        '-l completions|Install fish tab-completions for ry-install itself' \
        '-l fix|Re-install drifted files (use with --diff)' \
        '-s h -l help|Show help' \
        '-s v -l version|Show version'
    for _ce in $_comp_entries
        set -l _flags (string split '|' -- "$_ce")[1]
        set -l _desc (string split '|' -- "$_ce")[2]
        echo "    complete -c \$cmd $_flags -d '$_desc'" >>"$tmpfile"
    end

    # --install-file with destination completions
    echo "    complete -c \$cmd -l install-file -d 'Re-deploy a single managed file' -rxa '$_install_file_targets'" >>"$tmpfile"

    # --logs subcommand completions
    echo "    complete -c \$cmd -l logs -xa 'analyze last all list system gpu wifi boot audio usb kernel'" >>"$tmpfile"

    echo end >>"$tmpfile"

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
function _ry_do_test_all --description "Run the full test suite across all subcommands"
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

    # Pre-cache sudo for modes that need it
    _ensure_sudo_cached
    or return 1

    # B-5: Split into parallel-safe (read-only, no lock) and sequential (writes or lock-acquiring)
    set -l parallel_modes \
        --check \
        --verify-static \
        --verify-runtime \
        --lint \
        --diff \
        "--logs system" \
        "--logs gpu" \
        "--logs wifi" \
        "--logs boot" \
        "--logs audio" \
        "--logs usb" \
        "--logs kernel" \
        --version \
        --help

    set -l sequential_modes \
        "--dry-run --all" \
        "--diff --fix --dry-run --all" \
        "--install-file /etc/kernel/cmdline --dry-run"

    # Nested parallelism guard: <8 cores→sequential, 8-15→batch nproc, 16+→full parallel
    set -l nproc_val (nproc 2>/dev/null)
    set -l par_batch_size 0
    if test -n "$nproc_val"; and string match -qr '^\d+$' -- "$nproc_val"
        if test "$nproc_val" -lt 8
            _warn "Low CPU count ($nproc_val) — running test modes sequentially to avoid oversubscription"
            set sequential_modes $parallel_modes $sequential_modes
            set parallel_modes
        else if test "$nproc_val" -lt 16
            set par_batch_size $nproc_val
            _info "Mid-range CPU count ($nproc_val) — batching parallel modes in groups of $par_batch_size"
        else
            set par_batch_size 16
            _info "High CPU count ($nproc_val) — capping parallel modes at 16"
        end
    end

    # +1 for the completions validation block (line ~6865)
    set -l total (math (count $parallel_modes) + (count $sequential_modes) + 1)
    set -l passed 0
    set -l failed 0

    # ── Parallel phase: fork all read-only modes ──
    set -l test_dir (mktemp -d -t ry-test.XXXXXX)
    if not test -d "$test_dir"
        _err "Failed to create test temp directory"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$test_dir"
    set -l parallel_pids

    _info "Forking "(count $parallel_modes)" parallel read-only modes..."
    _echo

    for i in (seq (count $parallel_modes))
        set -l mode_args (string split ' ' -- $parallel_modes[$i])
        set -l label (string replace -a ' ' '_' -- $parallel_modes[$i] | string replace -a '/' '_' | string replace -a '-' '')
        fish -c '
            set -l script_path $argv[1]; set -l stderr_file $argv[2]; set -l exit_file $argv[3] # lint:ignore
            set -l mode_args $argv[4..]
            env NO_COLOR=1 fish "$script_path" $mode_args --verbose </dev/null >/dev/null 2>"$stderr_file"
            set -l rc $status
            printf "%d\n" $rc > "$exit_file"
        ' -- "$script_path" "$test_dir/$label.stderr" "$test_dir/$label.exit" $mode_args &
        set -a parallel_pids $last_pid
        # Batch throttle: wait for current batch before forking more (mid-range CPU guard)
        if test "$par_batch_size" -gt 0; and test (math $i % $par_batch_size) -eq 0
            wait $parallel_pids
            set parallel_pids
        end
    end

    test (count $parallel_pids) -gt 0; and wait $parallel_pids

    # Collect parallel results in order
    for i in (seq (count $parallel_modes))
        set -l label (string replace -a ' ' '_' -- $parallel_modes[$i] | string replace -a '/' '_' | string replace -a '-' '')
        set -l display_label (string replace -- '--' '' "$parallel_modes[$i]")
        set -l code (command cat -- "$test_dir/$label.exit" 2>/dev/null)
        if test -z "$code"
            set code 999
        end

        if test "$code" = 0
            set passed (math $passed + 1)
            _ok "  $display_label: passed"
        else
            set failed (math $failed + 1)
            _warn "  $display_label: exit code $code"
            if test -s "$test_dir/$label.stderr"
                set -l _head (head -n 5 "$test_dir/$label.stderr" | string trim --)
                for _hl in $_head
                    _warn "    $_hl"
                end
            end
        end
    end
    _echo

    # ── Sequential phase: modes that write or acquire locks ──
    _info "Running "(count $sequential_modes)" sequential modes..."
    _echo

    for i in (seq (count $sequential_modes))
        set -l mode_args (string split ' ' -- $sequential_modes[$i])
        set -l display_label (string replace -- '--' '' "$sequential_modes[$i]")
        _info "  $sequential_modes[$i]"

        set -l _test_stderr (mktemp -t ry-test-stderr.XXXXXX 2>/dev/null; or echo /dev/null)
        test "$_test_stderr" != /dev/null; and set -ga _TRACKED_TMPFILES "$_test_stderr"
        env NO_COLOR=1 fish "$script_path" $mode_args --verbose </dev/null >/dev/null 2>"$_test_stderr"
        set -l code $status

        if test $code -eq 0
            set passed (math $passed + 1)
            _ok "  $display_label: passed"
        else
            set failed (math $failed + 1)
            _warn "  $display_label: exit code $code"
            if test "$_test_stderr" != /dev/null; and test -s "$_test_stderr"
                set -l _head (head -n 5 "$_test_stderr" | string trim --)
                for _hl in $_head
                    _warn "    $_hl"
                end
            end
        end
        command rm -f -- "$_test_stderr" 2>/dev/null
    end

    # Validate --completions installs file with expected subcommands
    _echo "─ Validating completions output..."
    fish "$script_path" --completions 2>/dev/null
    set -l _comp_file "$HOME/.config/fish/completions/ry-install.fish"
    set -l _comp_out (command cat -- "$_comp_file" 2>/dev/null)
    set -l _comp_ok true
    if test -z "$_comp_out"
        # dry-run or write failure — skip content validation
        _info "  completions file not available (dry-run or write failed) — skipping content check"
        set passed (math $passed + 1)
    else
        for _expected_cmd in install diff verify-static verify-runtime lint logs
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

    command rm -rf --preserve-root -- "$test_dir"

    _echo
    _echo "════════════════════════════════════════════════════════════════════"
    if test $failed -eq 0
        _ok "Test suite complete: $passed/$total passed"
    else
        _warn "Test suite complete: $passed passed, $failed failed out of $total"
    end
    _echo
    _info "Log files created in: $LOG_DIR/"

    test $failed -gt 0; and return 1; or return 0
end

# ═══ CLI ARGUMENT PARSING AND DISPATCH ═══

# Entry point
set -g MODE install
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
                    set -l _canon (realpath -m -- "$next_arg" 2>/dev/null)
                    if test -n "$_canon"
                        set DIFF_TARGET "$_canon"
                    else
                        set DIFF_TARGET "$next_arg"
                    end
                    set i $next_i
                else if not string match -q -- '-*' "$next_arg"
                    echo "[ERR] --diff requires absolute path (got: $next_arg)" >&2
                    command rm -f -- "$LOG_FILE" 2>/dev/null
                    exit $EXIT_USAGE
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
        case --check
            set MODE check
            set mode_count (math $mode_count + 1)
        case --test-all
            set MODE test-all
            set mode_count (math $mode_count + 1)
        case --fix
            set -g FIX true
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

        case --completions
            set MODE completions
            set mode_count (math $mode_count + 1)
        case --install-file
            set MODE install-file
            set mode_count (math $mode_count + 1)
            set -l next_i (math $i + 1)
            if test $next_i -le (count $argv)
                set -l next_arg $argv[$next_i]
                if string match -q -- '/*' "$next_arg"
                    # Canonicalize: collapse //, .., symlinks to prevent bypassing managed-file validation
                    set -l _canon (realpath -m -- "$next_arg" 2>/dev/null)
                    if test -n "$_canon"
                        set INSTALL_FILE_TARGET "$_canon"
                    else
                        set INSTALL_FILE_TARGET "$next_arg"
                    end
                    set i $next_i
                else if not string match -q -- '-*' "$next_arg"
                    echo "[ERR] --install-file requires absolute path (got: $next_arg)" >&2
                    command rm -f -- "$LOG_FILE" 2>/dev/null
                    exit $EXIT_USAGE
                end
            end
        case -h --help
            _ry_show_help
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
            _ry_show_help >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            exit $EXIT_USAGE
    end
    set i (math $i + 1)
end

# ── Mode exclusivity: exactly one mode flag allowed per invocation ──
if test $mode_count -gt 1
    _log "ERR: Cannot combine multiple mode flags — run each separately"
    if test "$NO_COLOR" = true; or not isatty 2
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
    exit $EXIT_USAGE
end

if test "$FIX" = true; and test "$MODE" != diff
    _log "ERR: --fix requires --diff"
    echo "[ERR] --fix requires --diff" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    exit $EXIT_USAGE
end

if test "$_IS_ROOT" = true
    echo "Warning: Running as root. This script uses sudo internally." >&2
    echo "Consider running as normal user: ./ry-install.fish" >&2
    echo "Forcing --dry-run to prevent privilege separation bypass." >&2
    echo "" >&2
    set -g DRY true
end

if test "$MODE" != install; and test "$MODE" != check
    set -g QUIET false
end

if test "$DRY" = true
    set -g QUIET false
end

# Load machine profile — must be after arg parsing but before any mode that reads config globals
_load_profile

set -l mode_label $MODE
if test -n "$LOG_TARGET"
    set mode_label "$MODE-$LOG_TARGET"
end
if test "$FIX" = true
    set mode_label "$mode_label-fix"
end
if test "$DRY" = true; and test "$MODE" != test-all
    set mode_label "$mode_label-dry"
end
if test "$ALL" = true; and test "$MODE" != test-all
    set mode_label "$mode_label-all"
end
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"
set -l old_log "$LOG_FILE"
# Rename log to mode-specific path; mv before set — signal between them loses footer (acceptable) but preserves log content. Reversed order would lose content (signal handler creates empty new_log, then mv never runs because signal handler exits).
if test -f "$old_log"; and test "$old_log" != "$new_log"
    command mv -- "$old_log" "$new_log" 2>/dev/null
end
set -g LOG_FILE "$new_log"
# Only create fresh file if it doesn't already exist (mv above may have placed it); preserve pre-existing content from _load_profile
if not test -f "$LOG_FILE"
    command install -m 0600 /dev/null "$LOG_FILE" 2>/dev/null
    or begin
        command touch -- "$LOG_FILE" 2>/dev/null
        command chmod -- 600 "$LOG_FILE" 2>/dev/null; or _warn "Chmod 600 failed on $LOG_FILE"
    end
else
    command chmod -- 600 "$LOG_FILE" 2>/dev/null; or true
end

set -l _init_cmd (string join -- " " (status filename) $argv)
set -l _init_cmd (_json_str "$_init_cmd")
printf '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","dry_run":%s,"all":%s,"verbose":%s,"command":"%s"}\n' \
    (date '+%Y-%m-%dT%H:%M:%S%z') "$VERSION" "$PROFILE_NAME" "$MODE" "$DRY" "$ALL" \
    (test "$QUIET" = false; and echo true; or echo false) "$_init_cmd" >>"$LOG_FILE"

# Lock policy: write modes (install, diff --fix) acquire; read modes skip
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
            exit $EXIT_USAGE
        end
        _acquire_lock; or exit $EXIT_LOCK
    case install
        _acquire_lock; or exit $EXIT_LOCK
    case diff
        if test "$FIX" = true
            _acquire_lock; or exit $EXIT_LOCK
        end
    case '*'
        # No lock needed for read-only modes (verify, lint, logs, completions, test-all)
end

# Log rotation: flock serializes concurrent instances; without flock, rm -f is idempotent (last-write-wins)
set -l _log_base_rot "$HOME/ry-install/logs"
set -l _existing_logs (command find "$_log_base_rot" \( -name '*.jsonl' -o -name '*.log' \) -type f ! -path "$LOG_FILE" -printf '%T@\t%p\n' 2>/dev/null | LC_ALL=C sort -n | string replace -r -- '^[^\t]+\t' '')
set -l _log_count (count $_existing_logs)
if test $_log_count -gt $MAX_LOGS
    set -l _to_remove (math $_log_count - $MAX_LOGS)
    set -l _rm_targets (string join0 -- $_existing_logs[1..$_to_remove])
    if command -q flock
        printf '%s' "$_rm_targets" | flock -n "$_log_base_rot" xargs -0 rm -f -- 2>/dev/null
    else
        printf '%s' "$_rm_targets" | xargs -0 rm -f --
    end
    command find "$_log_base_rot" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
end

set -g exit_code 0
# ── Main dispatch: route MODE to handler, capture exit code ──
switch $MODE
    case diff
        _ry_do_diff "$DIFF_TARGET"
        set exit_code $status
    case verify-static
        _ry_verify_static
        set exit_code $status
    case verify-runtime
        _ry_verify_runtime
        set exit_code $status
    case lint
        _ry_do_lint
        set exit_code $status
    case check
        _ry_do_check
        set exit_code $status
    case test-all
        _ry_do_test_all
        set exit_code $status
    case logs
        _ry_do_logs "$LOG_TARGET" "$LOG_TARGET_ARG"
        set exit_code $status
    case completions
        _ry_do_completions
        set exit_code $status
    case install-file
        _ry_do_install_file "$INSTALL_FILE_TARGET"
        set exit_code $status
    case install
        _ry_do_install
        set -l install_status $status
        if test $install_status -ne 0
            set exit_code $install_status
        else if test "$INSTALL_HAD_ERRORS" = true
            set exit_code $EXIT_FAIL
        end
    case '*'
        _err "Unknown mode: $MODE"
        set exit_code 2
end
# fish_exit handler receives $status of last command in setup, not script exit — capture intended code here
set -g _INTENDED_EXIT_CODE $exit_code

# Set flag BEFORE write to prevent signal-handler race (SIGINT between printf and flag would double-write)
set -g _FOOTER_WRITTEN true
set -l _mode_esc (_json_str "$MODE")
printf '{"ts":"%s","event":"footer","finished":"%s","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (date '+%Y-%m-%dT%H:%M:%S%z') "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" >>"$LOG_FILE"

if test "$MODE" != check
    echo "[i] Log file: $LOG_FILE" >&2
end

exit $exit_code
