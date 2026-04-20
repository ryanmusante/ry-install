#!/usr/bin/env fish
# ry-install v4.1.5 (2026-04-19) — CachyOS config manager | Ryan Musante | MIT
if set -q _RY_INSTALL_LOADED
    echo "ry-install already loaded in this session" >&2
    if status stack-trace 2>/dev/null | string match -q '*from sourcing*'
        return 1
    else
        exit 1
    end
end
# Snapshot pre-script globals so namespace cleanup erases only script-created globals, never host-shell globals.
set -g _RY_PRE_GLOBALS (set --names -g)
set -g _RY_INSTALL_LOADED true
# Source detection via `status stack-trace` works in both interactive and non-interactive contexts (fish 3.4+).
if status stack-trace 2>/dev/null | string match -q '*from sourcing*'
    set -g _RY_INSTALL_SOURCED true
else
    set -g _RY_INSTALL_SOURCED false
end
set -g VERSION "4.1.5"
set -g EXIT_OK 0
set -g EXIT_FAIL 1
set -g EXIT_USAGE 2
set -g EXIT_PREFLIGHT 3
set -g EXIT_BOOT_CRIT 4
set -g EXIT_LOCK 5
set -g EXIT_DRIFT 10

# _ry_exit: source-safe exit. Exits normally; sets bail sentinel and returns when sourced.
function _ry_exit --argument-names code --description "Source-safe exit: set bail sentinel and return when sourced, exit otherwise"
    test -z "$code"; and set code 0
    set -g _RY_INSTALL_LAST_EXIT $code
    # Always run namespace cleanup before exit/return (defense-in-depth for fish exit-as-return-from-source).
    set -g _RY_INSTALL_BAILING true
    # Erase signal/exit handlers so host-fish Ctrl+C/SIGPIPE/exit does not fire into dead script context.
    functions -e _cleanup _cleanup_pipe _cleanup_on_exit 2>/dev/null
    _ry_namespace_cleanup bail
    if test "$_RY_INSTALL_SOURCED" = true
        return $code
    end
    exit $code
end

# Erase script-set globals, preserve caller-API vars. mode=bail keeps _RY_INSTALL_BAILING for sentinel propagation.
function _ry_namespace_cleanup --argument-names mode --description "Erase script-set globals; preserve caller-API"
    # HOME preserved: populated at L104-108 when sourced with empty $HOME (containers/cron/systemd --user).
    set -l _preserve _RY_INSTALL_LAST_EXIT HOME
    test "$mode" = bail; and set -a _preserve _RY_INSTALL_BAILING
    # Copy snapshot to local — _RY_PRE_GLOBALS is post-snapshot, so the loop would erase it mid-iteration.
    set -l _snap $_RY_PRE_GLOBALS
    for _v in (set --names -g)
        contains -- $_v $_snap; and continue
        contains -- $_v $_preserve; and continue
        set -e $_v 2>/dev/null
    end
end

# QUIET defaults true; -V/--verbose flips it to false (auto-disabled for non-install modes)
set -g QUIET true
# Environment detection: NO_COLOR (no-color.org); set -qx avoids false positive from set -g
if set -qx NO_COLOR; or test "$TERM" = dumb
    set -g NO_COLOR true
else
    set -g NO_COLOR false
end
if test (id -u) -eq 0
    echo "[ERR] ry-install must not run as root. Run as your normal user; sudo is invoked internally." >&2
    _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
end

# Fish version gate — 3.4+ required (set --function, string collect --allow-empty)
set -l fish_ver (string match -r -- '\d+\.\d+' (fish --version 2>&1) | head -n 1)
if test -z "$fish_ver"
    echo "Error: Could not determine fish version" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
set -l fish_major (string split '.' -- "$fish_ver")[1]
set -l fish_minor (string split '.' -- "$fish_ver")[2]
if test -z "$fish_major"; or not string match -qr '^\d+$' -- "$fish_major"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
if test -z "$fish_minor"; or not string match -qr '^\d+$' -- "$fish_minor"
    echo "Error: Could not parse fish version: $fish_ver" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
if test "$fish_major" -lt 3; or begin
        test "$fish_major" -eq 3; and test "$fish_minor" -lt 4
    end
    echo "Error: fish 3.4+ required (found: $fish_ver)" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
# Upper bound: warn on fish 5.x+ — ry-install is tested on fish 3.4-4.x only; non-blocking
if test "$fish_major" -gt 4
    echo "Warning: ry-install is tested on fish 3.4-4.x; found $fish_ver — please report issues" >&2
end

# Timestamps: DATE_LABEL (ISO date) for dirs, TIMESTAMP (compact+PID) for filenames; two date calls avoid %Y dup.
set -g DATE_LABEL (date '+%Y-%m-%d')
set -g TIMESTAMP (date '+%Y%m%d-%H%M%S%z')"-"$fish_pid

# HOME resolution: env → getent passwd → tilde expansion (handles privilege-escalated shells, cron, containers)
set -g _MY_UID (id -u)
if test -z "$HOME"
    set -g HOME (getent passwd $_MY_UID 2>/dev/null | cut -d: -f6)
    if test -z "$HOME"
        set -g HOME ~
    end
    if test -z "$HOME"; or not test -d "$HOME"
        echo "Error: Cannot determine HOME directory" >&2
        _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
    end
end

set -g LOG_DIR "$HOME/ry-install/logs/$DATE_LABEL"
# Boot-wipe acknowledgement marker — single source of truth for the preflight gate and the post-success writer
set -g BOOT_WIPE_MARKER "$HOME/ry-install/.boot-wipe-acknowledged"
# umask 0077 on mkdir keeps logs/ and logs/YYYY-MM-DD/ at 0700 (parent $HOME/ry-install is forced 0700 below).
set -l _prev_mkdir_umask (umask)
umask 0077
command mkdir -p -- "$LOG_DIR" 2>/dev/null; or begin
    umask $_prev_mkdir_umask
    echo "[ERR] Cannot create log directory: $LOG_DIR" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
umask $_prev_mkdir_umask
# Repair any pre-existing log subdirs created under a looser umask by an older run.
command chmod -- 700 "$HOME/ry-install/logs" 2>/dev/null
command chmod -- 700 "$LOG_DIR" 2>/dev/null
set -l _ld_cur_mode (stat -c '%a' -- "$HOME/ry-install" 2>/dev/null)
if test "$_ld_cur_mode" != 700
    command chmod -- 700 "$HOME/ry-install" 2>/dev/null
end
set -l _ld_mode (stat -c '%a' -- "$HOME/ry-install" 2>/dev/null)
if test "$_ld_mode" != 700
    echo "[ERR] Log dir mode is $_ld_mode (expected 700): $HOME/ry-install" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
set -g LOG_FILE "$LOG_DIR/install-$TIMESTAMP.jsonl"
# NOTE: path format mirrored at dispatch-time rename site; umask 0177 makes touch+chmod fallback race-free
set -l _prev_umask (umask)
umask 0177
command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
or begin
    command touch -- "$LOG_FILE" 2>/dev/null
    command chmod -- 600 "$LOG_FILE" 2>/dev/null
end
umask $_prev_umask
# Fail-loud if neither install nor touch+chmod created the log file
if not test -f "$LOG_FILE"
    echo "[ERR] Failed to create log file: $LOG_FILE" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
set -g INSTALL_HAD_ERRORS false
set -g _TRACKED_TMPFILES

# Retention limits
set -g MAX_LOGS 50

# Managed destinations fallback for _ry_show_help before profile loads (matches DESTINATIONS totals)
set -g _RY_MANAGED_FILE_COUNT 16

# Timing constants
set -g SUDO_KEEPALIVE_INTERVAL 45
set -g NM_RESTART_DELAY 3

# Kernel version globals for _ntsync_state ≥6.14 gate
set -g KVER (uname -r)
set -g KVER_PARTS (string split '.' -- $KVER)
set -g KVER_MAJOR $KVER_PARTS[1]
# Preflight-fail on unparseable uname -r
if not string match -qr '^\d+$' -- "$KVER_MAJOR"
    echo "[ERR] Cannot parse kernel major version from uname -r: $KVER" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end
# Strip non-numeric suffix (e.g., "14-cachyos" → "14") for numeric comparison
set -g KVER_MINOR (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[2]")
if test -z "$KVER_MINOR"; or not string match -qr '^\d+$' -- "$KVER_MINOR"
    echo "[ERR] Cannot parse kernel minor version from uname -r: $KVER" >&2
    _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
end

function _kconfig_cache --description "Return cached /proc/config.gz lines (lazy-loaded; empty on missing config)"
    # sentinel-based gate — `count == 0` re-tested /proc/config.gz on every call when missing
    if not set -q _KCONFIG_LOADED
        if test -f /proc/config.gz
            set -g _KCONFIG_DATA (zcat /proc/config.gz 2>/dev/null)
        else
            set -g _KCONFIG_DATA
        end
        set -g _KCONFIG_LOADED true
    end
    test (count $_KCONFIG_DATA) -eq 0; and return 0
    printf '%s\n' $_KCONFIG_DATA
end

# States: unavailable | builtin (CONFIG_NTSYNC=y) | loaded (/dev/ntsync) | loaded_nodev | missing
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

# Probe shared by _ry_verify_static, _ry_do_check, _install_configure_services; per-site action stays local.
function _detect_lvm --description "Return 0 (LVM present) or 1 (no LVM / sudo lapsed); sets \$_pvs_output as side channel"
    set -g _pvs_output (command timeout 10 sudo -n pvs --noheadings 2>/dev/null | string trim --)
    test -n "$_pvs_output"
end

# Cross-check KERNEL_PARAMS against /proc/config.gz to detect unsupported kernel features
function _validate_kernel_params --description "Warn if KERNEL_PARAMS reference features not compiled into running kernel"
    # Only useful if /proc/config.gz exists (requires CONFIG_IKCONFIG_PROC=y)
    if not test -f /proc/config.gz
        _info "  /proc/config.gz unavailable — skipping kernel config validation"
        return 0
    end

    # Map cmdline param prefix → CONFIG_ symbol. Unchecked: iommu, clocksource, module_blacklist, nowatchdog, quiet.
    set -l param_config_map \
        "zswap.=CONFIG_ZSWAP" \
        "amdgpu.=CONFIG_DRM_AMDGPU" \
        "nvme_core.=CONFIG_NVME_CORE" \
        "pcie_aspm.=CONFIG_PCIEASPM" \
        "split_lock_detect=CONFIG_X86_BUS_LOCK_DETECT" \
        "usbcore.=CONFIG_USB_SUPPORT"

    set -l config_data (_kconfig_cache)
    if test -z "$config_data"
        _warn "  Failed to read /proc/config.gz"
        return 1
    end

    set -l mismatches 0
    for entry in $param_config_map
        set -l prefix (string split '=' -- "$entry")[1]
        set -l config_sym (string split '=' -- "$entry")[2]

        set -l found false
        for param in $KERNEL_PARAMS
            if string match -q -- "$prefix*" "$param"
                set found true
                break
            end
        end
        test "$found" = true; or continue

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
    set -l _verify_err (mktemp -t ry-verify-unit.XXXXXX 2>/dev/null; or echo /dev/null)
    test "$_verify_err" != /dev/null; and set -ga _TRACKED_TMPFILES "$_verify_err"
    if systemd-analyze $user_flag verify "$unit_path" 2>"$_verify_err"
        if test "$_verify_err" != /dev/null; and test -s "$_verify_err"
            _log "VERIFY_UNIT_WARN: ($label) "(head -n 5 "$_verify_err")
        end
        command rm -f -- "$_verify_err" 2>/dev/null
        _ok "  $label: syntax OK"
        return 0
    else
        if test "$_verify_err" != /dev/null; and test -s "$_verify_err"
            _log "VERIFY_UNIT_ERR: ($label) "(head -n 5 "$_verify_err")
        end
        command rm -f -- "$_verify_err" 2>/dev/null
        _fail "  $label: INVALID SYNTAX"
        return 1
    end
end

function _write_footer --argument-names exit_code extra_key --description "Append JSONL footer to LOG_FILE; idempotent via _FOOTER_WRITTEN"
    set -q _FOOTER_WRITTEN; and return 0
    set -q LOG_FILE; or return 0
    begin; test -n "$LOG_FILE"; and test -f "$LOG_FILE"; end; or return 0
    set -g _FOOTER_WRITTEN true
    set -l _mode_esc (_json_str "$MODE")
    set -l _ts (date '+%Y-%m-%dT%H:%M:%S%z')
    set -l _extra ""
    if test -n "$extra_key"
        set _extra ",\"$extra_key\":true"
    end
    printf '{"ts":"%s","event":"footer","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s%s}\n' \
        "$_ts" "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" "$_extra" >>"$LOG_FILE" 2>/dev/null
end

# Sweep /tmp for ry-{run-stderr,run-stdout,validate,diff,argparse,test-stderr}.* owned by current UID
function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    if not set -q _FOOTER_WRITTEN
        _log "CLEANUP_TMPFILES: sweep starting"
    end
    # Clean orphaned .ry-install.* tmpfiles from atomic writes (crash/interrupt leftovers)
    set -l sys_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname -- "$dst")
        if not contains -- "$dir" $sys_dirs
            set -a sys_dirs "$dir"
        end
    end
    # Only sweep NM connections dir if profile manages NM/iwd configs
    set -l _profile_uses_nm false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_d"; or string match -q '*/iwd/*' -- "$_d"
            set _profile_uses_nm true
            break
        end
    end
    if test "$_profile_uses_nm" = true; and not contains -- /etc/NetworkManager/system-connections $sys_dirs
        set -a sys_dirs /etc/NetworkManager/system-connections
    end
    for dir in $sys_dirs
        # 0700 root-only dirs (e.g. /etc/NetworkManager/system-connections) need sudo to enumerate
        if command -q sudo
            # Warn once/run when sudo lapsed AND dir is root-owned 0700 NM — else stale .ry-install.* accumulate.
            if string match -q '*NetworkManager/system-connections' -- "$dir"
                if not sudo -n true 2>/dev/null; and not set -q _RY_CLEANUP_SUDO_LAPSED_WARNED
                    _warn "Sudo lapsed — tmpfile sweep in $dir skipped; stale files may accumulate"
                    set -g _RY_CLEANUP_SUDO_LAPSED_WARNED true
                end
            end
            sudo -n find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
        else
            command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
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
        command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
    end
    set -l comp_dir "$HOME/.config/fish/completions"
    if test -d "$comp_dir"
        command find "$comp_dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
    end
end

set -g _CLEANUP_DONE false

# Atomic mkdir mutex with PID file; reclaims stale locks via PID liveness check; flock(1) eliminates TOCTOU race
function _acquire_lock --description "Acquire instance lock (atomic mkdir)"
    # Atomic mkdir as mutex; PID file inside enables stale-lock detection via process liveness probe
    set -g LOCK_DIR "$HOME/ry-install/.lock"
    set -g LOCK_FILE "$LOCK_DIR/pid"
    command mkdir -p -- (dirname -- "$LOCK_DIR") 2>/dev/null; or true

    if command mkdir -- "$LOCK_DIR" 2>/dev/null
        # Check pid write; on disk-full mkdir/echo race, rmdir and bail so stale-reclaim can't evict own empty lock.
        if not printf '%s\n' $fish_pid >"$LOCK_FILE" 2>/dev/null
            command rmdir -- "$LOCK_DIR" 2>/dev/null
            echo "[ERR] Failed to write lock pid file: $LOCK_FILE" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        end
        _log "LOCK_ACQUIRED: pid=$fish_pid dir=$LOCK_DIR"
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
        # flock -n/-E 5: non-blocking, exit 5 on contention. Paths as positional args; PID write inside flocked subshell.
        flock -n -E 5 "$_reclaim_parent" /bin/sh -c '
            rm -f -- "$1/pid" 2>/dev/null  # lint:ignore (embedded /bin/sh -c block)
            find "$1" -maxdepth 1 -type f -delete 2>/dev/null  # lint:ignore (embedded /bin/sh -c block)
            rmdir -- "$1" 2>/dev/null || true  # lint:ignore (sh, not fish — embedded /bin/sh -c block)
            mkdir -- "$1" 2>/dev/null || exit 1  # lint:ignore (sh, not fish — embedded /bin/sh -c block)
            printf "%s\n" "$2" > "$1/pid" 2>/dev/null || exit 2  # lint:ignore (sh, not fish — embedded /bin/sh -c block)
        ' _ "$LOCK_DIR" "$fish_pid" 2>/dev/null
        set -l _flock_rc $status
        if test $_flock_rc -eq 5
            echo "[ERR] Failed to reclaim stale lock — another instance is reclaiming" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        else if test $_flock_rc -ne 0
            echo "[ERR] Failed to reclaim stale lock via flock (rc=$_flock_rc)" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        end
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
        printf '%s\n' $fish_pid >"$LOCK_FILE"
        # Yield to let any concurrent reclaimer finish writing, then double-verify ownership
        command sleep 0.1 2>/dev/null; or true
    end
    set -l verify_pid (command cat -- "$LOCK_FILE" 2>/dev/null)
    set -l my_pid $fish_pid
    if test "$verify_pid" != "$my_pid"
        echo "[ERR] Lock reclaim lost to concurrent instance (PID $verify_pid)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    set -l verify_pid2 (command cat -- "$LOCK_FILE" 2>/dev/null)
    if test "$verify_pid2" != "$my_pid"
        echo "[ERR] Lock reclaim lost to late writer (PID $verify_pid2)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    _log "LOCK_RECLAIMED: stale pid=$old_pid, new pid=$fish_pid"
    return 0
end

# Signal handling: tmpfiles → lock release → keepalive; three entry points guarded by _CLEANUP_DONE

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
    set -l _tmpdir (set -q TMPDIR; and test -n "$TMPDIR"; and printf '%s\n' "$TMPDIR"; or printf '%s\n' /tmp)
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type f -user $_MY_UID -delete 2>/dev/null
    # Descend to purge abandoned ry-run.* dirs; -type d -empty reclaims parents (maxdepth=1 sweep can't reach in).
    command find "$_tmpdir" -mindepth 2 -maxdepth 2 -path "$_tmpdir/ry-*" -type f -user $_MY_UID -delete 2>/dev/null
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type d -empty -user $_MY_UID -delete 2>/dev/null
    # Free cached data (harmless but consistent with cleanup discipline)
    set --erase _KCONFIG_DATA
    set --erase _KCONFIG_LOADED
    set --erase _RY_SKIP_IWD
    set --erase _RY_SKIP_IWD_CACHED
    # Release LOCK_DIR mutex — verify PID ownership first (LOCK_DIR global is set before mkdir; on failure we don't own it)
    if set -q LOCK_DIR; and test -d "$LOCK_DIR"
        set -l _lock_pid (command cat -- "$LOCK_DIR/pid" 2>/dev/null)
        set -l _my_pid $fish_pid
        if test "$_lock_pid" = "$_my_pid"
            command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
        end
    end
    _kill_sudo_keepalive
end

function _kill_sudo_keepalive --description "Terminate the background sudo credential refresh loop"
    if set -q SUDO_KEEPALIVE_PID; and test -n "$SUDO_KEEPALIVE_PID"
        # PID re-verify before kill: closes a narrow PID-reuse race window after wait/reap
        if kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            # pkill -P reaps descendants (sleep/sudo) so they don't orphan to init when parent fish exits.
            if command -q pkill
                command pkill -TERM -P $SUDO_KEEPALIVE_PID 2>/dev/null
            end
            command kill -- $SUDO_KEEPALIVE_PID 2>/dev/null
            # SIGTERM→sleep→SIGKILL: child disowned (init reaps); closes SIGTERM-ignoring keepalive window past exit.
            command sleep 0.1 2>/dev/null
            if kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
                if command -q pkill
                    command pkill -KILL -P $SUDO_KEEPALIVE_PID 2>/dev/null
                end
                command kill -KILL -- $SUDO_KEEPALIVE_PID 2>/dev/null
            end
        end
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
# _cleanup writes footer + exits 128+signum; _cleanup_on_exit is the fish_exit fallback
function _cleanup --on-signal INT --on-signal TERM --on-signal HUP --on-signal QUIT --description "Signal handler: clean up on INT/TERM/HUP/QUIT"
    # Reentrancy guard: double-signal (two Ctrl+C during _do_cleanup) must not re-enter; mirrors _cleanup_on_exit.
    test "$_CLEANUP_DONE" = true; and return 0
    echo "" >&2
    echo "[WARN] Interrupted - cleaning up..." >&2
    set -g _CLEANUP_DONE true
    # Fish 3.4+ passes the SIG-prefixed signal name as $argv[1] (e.g., "SIGTERM"); match both forms for robustness.
    set -l _sig_exit 130
    switch "$argv[1]"
        case HUP SIGHUP
            set _sig_exit 129
        case INT SIGINT
            set _sig_exit 130
        case QUIT SIGQUIT
            set _sig_exit 131
        case TERM SIGTERM
            set _sig_exit 143
    end
    _write_footer "$_sig_exit" interrupted
    _do_cleanup
    # Source-safe: when sourced, `exit` would kill host shell. Set bail sentinel and return from signal frame instead.
    if test "$_RY_INSTALL_SOURCED" = true
        set -g _RY_INSTALL_LAST_EXIT $_sig_exit
        set -g _RY_INSTALL_BAILING true
        functions -e _cleanup _cleanup_pipe _cleanup_on_exit 2>/dev/null
        return $_sig_exit
    end
    exit $_sig_exit
end

# SIGPIPE handler: skip stderr (pipe broken), write JSONL footer, run _do_cleanup, exit 141
function _cleanup_pipe --on-signal PIPE --description "Signal handler: clean up on SIGPIPE (broken pipe)"
    # Reentrancy guard: a second SIGPIPE mid-cleanup must not re-enter. Mirrors _cleanup / _cleanup_on_exit.
    test "$_CLEANUP_DONE" = true; and return 0
    # SIGPIPE: stderr may also be broken — skip all terminal output
    set -g _CLEANUP_DONE true
    _write_footer 141 interrupted
    _do_cleanup
    # Source-safe exit (see _cleanup): return from signal frame when sourced in interactive fish so host shell lives.
    if test "$_RY_INSTALL_SOURCED" = true
        set -g _RY_INSTALL_LAST_EXIT 141
        set -g _RY_INSTALL_BAILING true
        functions -e _cleanup _cleanup_pipe _cleanup_on_exit 2>/dev/null
        return 141
    end
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
    _write_footer "$_exit_status" cleanup_exit
    _do_cleanup
end

# PROFILES — machine-specific configuration

function _ry_profile_gtr9_pro --description "Beelink GTR9 Pro (Strix Halo)"
    # Identity
    set -g PROFILE_NAME gtr9_pro
    set -g PROFILE_DESC "Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S"

    # Managed file destinations — 1:1 to _ry_get_file_content(); sys=0644 user=0600; 12+3+1=16 = README count.
    set -g SYSTEM_DESTINATIONS \
        "/boot/loader/loader.conf" \
        /etc/kernel/cmdline \
        "/etc/sdboot-manage.conf" \
        "/etc/mkinitcpio.conf" \
        "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
        "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
        "/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf" \
        "/etc/iwd/main.conf" \
        "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
        /etc/drirc \
        "/etc/sysctl.d/99-cachyos-sysctl.conf" \
        "/etc/udev/rules.d/99-nvme-rqaffinity.rules"

    set -g USER_DESTINATIONS \
        "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" \
        "$HOME/.config/environment.d/10-environment.conf" \
        "$HOME/.config/systemd/user/ssh-agent.service"

    set -g SERVICE_DESTINATIONS \
        "/etc/systemd/system/cpupower-epp.service"

    # Boot
    set -g LOADER_DEFAULT "@saved"
    set -g LOADER_TIMEOUT 0
    set -g LOADER_CONSOLE_MODE keep
    set -g LOADER_EDITOR no
    set -g SDBOOT_DEFAULT_ENTRY manual
    set -g SDBOOT_OVERWRITE yes
    # REMOVE_EXISTING=yes deletes ALL boot entries before regen — manual entries (rescue, Windows) will be lost
    set -g SDBOOT_REMOVE_EXISTING yes
    set -g SDBOOT_REMOVE_OBSOLETE yes

    # Kernel (15): amd_pstate=active; ppfeaturemask bits 14,15,17 off; cwsr_enable=0 gfx1151; iommu=pt; tsc=reliable.
    set -g KERNEL_PARAMS \
        iommu=pt \
        amd_pstate=active \
        amdgpu.cwsr_enable=0 \
        amdgpu.ppfeaturemask=0xfffd3fff \
        loglevel=3 \
        module_blacklist=pcspkr \
        nowatchdog \
        pcie_aspm.policy=performance \
        quiet \
        rd.systemd.show_status=auto \
        rd.udev.log_level=3 \
        split_lock_detect=off \
        tsc=reliable \
        usbcore.autosuspend=-1 \
        zswap.enabled=0

    # Initramfs
    set -g MKINITCPIO_MODULES amdgpu
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
    set -g MKINITCPIO_COMPRESSION_OPTIONS -1 -T0

    # Udev — ntsync autoloaded via wine-cachyos modules-load.d/10-ntsync.conf (transitive of gaming-meta).

    # Network
    set -g RESOLVED_MDNS resolve
    set -g LOGIND_IGNORE_KEYS \
        HandlePowerKey \
        HandlePowerKeyLongPress \
        HandleSuspendKey \
        HandleSuspendKeyLongPress \
        HandleHibernateKey \
        HandleHibernateKeyLongPress \
        HandleRebootKey \
        HandleRebootKeyLongPress \
        HandleSecureAttentionKey
    set -g IWD_ENABLE_NETWORK_CONFIG false
    set -g IWD_DRIVER_QUIRKS "PowerSaveDisable=*"
    set -g IWD_DNS_SERVICE systemd
    set -g NM_WIFI_BACKEND iwd
    set -g NM_WIFI_POWERSAVE 2
    set -g NM_LOG_LEVEL WARN

    # Environment
    set -g ENV_VARS \
        "DXVK_LOG_LEVEL=none" \
        "DXVK_LOG_PATH=none" \
        "ENABLE_LAYER_MESA_ANTI_LAG=1" \
        "MESA_SHADER_CACHE_MAX_SIZE=4G" \
        "PROTON_ENABLE_WAYLAND=1" \
        "PROTON_LOCAL_SHADER_CACHE=1" \
        "RADV_EXPERIMENTAL=transfer_queue,hic" \
        "RADV_PERFTEST=sam,nircache" \
        "VKD3D_DEBUG=none" \
        "VKD3D_SHADER_DEBUG=none" \
        "WINEDEBUG=-all" \
        "PROTON_USE_NTSYNC=1"

    # Sysctl — supplements vendor 70-cachyos-settings.conf; netdev_max_backlog overrides 4096→16384 (99-* after 70-*).
    set -g SYSCTL_VALUES \
        "net.core.default_qdisc=fq" \
        "net.core.netdev_max_backlog=16384" \
        "net.core.rmem_max=134217728" \
        "net.core.wmem_max=134217728" \
        "net.ipv4.tcp_congestion_control=bbr" \
        "net.ipv4.tcp_fastopen=3" \
        "net.ipv4.tcp_mtu_probing=1" \
        "net.ipv4.tcp_notsent_lowat=131072" \
        "net.ipv4.tcp_rmem=4096 87380 134217728" \
        "net.ipv4.tcp_slow_start_after_idle=0" \
        "net.ipv4.tcp_wmem=4096 65536 134217728" \
        "vm.max_map_count=2147483642" \
        "vm.watermark_boost_factor=0" \
        "fs.protected_fifos=2" \
        "fs.protected_regular=2" \
        "vm.compaction_proactiveness=0" \
        "net.core.busy_read=50" \
        "net.core.busy_poll=50" \
        "net.core.netdev_budget=600"

    # Packages: PKGS_ADD=14 PKGS_DEL=8 AUR=1 EXPECTED_SERVICES=4 must equal README
    set -g PKGS_ADD \
        mkinitcpio-firmware \
        nftables \
        nvme-cli \
        cachyos-gaming-meta \
        cachyos-gaming-applications \
        libva-mesa-driver \
        lib32-libva-mesa-driver \
        fd \
        sd \
        dust \
        procs \
        bottom \
        git-delta \
        lm_sensors
    set -g PKGS_DEL \
        plymouth \
        cachyos-plymouth-bootanimation \
        cachyos-plymouth-theme \
        ufw \
        octopi \
        micro \
        cachyos-micro-settings \
        btop

    # AUR packages — installed via paru (not pacman)
    set -g AUR_PKGS mt76-mt7925-dkms

    # Services
    set -g EXPECTED_VULKAN_PKGS vulkan-radeon lib32-vulkan-radeon lib32-mesa
    # MASK=10 must equal README "Masked Services" count
    set -g MASK \
        ananicy-cpp.service \
        power-profiles-daemon.service \
        lvm2-monitor.service \
        NetworkManager-wait-online.service \
        systemd-coredump.socket \
        sleep.target \
        suspend.target \
        hibernate.target \
        hybrid-sleep.target \
        suspend-then-hibernate.target
    set -g EXPECTED_SERVICES cpupower-epp.service fstrim.timer NetworkManager.service nftables.service

    # Thresholds
    set -g BOOT_SPACE_CRIT 200
    set -g BOOT_SPACE_WARN 500
    set -g ROOT_AVAIL_CRIT 2
    set -g ROOT_AVAIL_WARN 5
    set -g BOOT_TIME_TARGET 15

    # Hardware expectations (optional)
    set -g EXPECTED_CPU_MATCH "Ryzen AI Max"
    return 0
end

# PROFILE LOADER

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
        SDBOOT_DEFAULT_ENTRY \
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

    # Optional globals (consumers unset-safe) — full list below and in _validate_profile.

    # Conditionally required — needed only when profile includes corresponding destinations
    for dst in $SYSTEM_DESTINATIONS
        switch "$dst"
            case '*/iwd/*'
                # decoupled from NM
                for nw_var in IWD_ENABLE_NETWORK_CONFIG IWD_DNS_SERVICE IWD_DRIVER_QUIRKS
                    if not contains -- $nw_var $required
                        set -a required $nw_var
                    end
                end
            case '*nm.conf'
                for nw_var in NM_WIFI_BACKEND NM_WIFI_POWERSAVE NM_LOG_LEVEL
                    if not contains -- $nw_var $required
                        set -a required $nw_var
                    end
                end
            case '*/resolved.conf.d/*'
                if not contains -- RESOLVED_MDNS $required
                    set -a required RESOLVED_MDNS
                end
            case '*/sysctl.d/*'
                if not contains -- SYSCTL_VALUES $required
                    set -a required SYSCTL_VALUES
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

    # Element sanitization: reject shell-metachars in profile globals embedded into config files (cmdline, mkinitcpio).
    for _list_var in KERNEL_PARAMS MKINITCPIO_MODULES MKINITCPIO_HOOKS
        if set -q $_list_var
            for _elem in $$_list_var
                if string match -qr -- '[[:space:]"\(\)]' "$_elem"
                    _err "Profile global $_list_var element contains forbidden character (space/quote/paren/newline): '$_elem'"
                    return 1
                end
            end
        end
    end

    # Package name sanitize: pacman/paru accept [a-zA-Z0-9._+-]; reject metachars to block profile command shaping.
    for _pkg_list_var in PKGS_ADD PKGS_DEL AUR_PKGS
        if set -q $_pkg_list_var
            for _elem in $$_pkg_list_var
                if not string match -qr '^[a-zA-Z0-9][a-zA-Z0-9._+-]*$' -- "$_elem"
                    _err "Profile global $_pkg_list_var element is not a valid package name: '$_elem'"
                    return 1
                end
            end
        end
    end

    # Destination path sanitization — newline/whitespace would corrupt parallel-worker `printf '%s\n'` serialization.
    for _list_var in SYSTEM_DESTINATIONS USER_DESTINATIONS SERVICE_DESTINATIONS
        if set -q $_list_var
            for _elem in $$_list_var
                if string match -qr -- '[[:space:]"\(\)]' "$_elem"
                    _err "Profile global $_list_var element contains forbidden character (space/quote/paren/newline): '$_elem'"
                    return 1
                end
            end
        end
    end

    # Destination guard: reject literal duplicates AND slash→underscore key collisions (e.g. /a/b and /a_b → _a_b).
    set -l _seen_dests
    set -l _seen_keys
    set -l _seen_owners
    for _d in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if contains -- "$_d" $_seen_dests
            _err "Profile destination duplicated: '$_d' appears more than once in SYSTEM/USER/SERVICE destinations"
            return 1
        end
        set -l _k (string replace -a '/' '_' -- "$_d")
        set -l _idx (contains -i -- "$_k" $_seen_keys)
        if test -n "$_idx"
            _err "Profile destination key collision: '$_d' and '$_seen_owners[$_idx]' both map to tmpfile key '$_k'"
            return 1
        end
        set -a _seen_dests "$_d"
        set -a _seen_keys "$_k"
        set -a _seen_owners "$_d"
    end

    return 0
end

# Resolve profile name (default-file → gtr9_pro), load function, cache root UUID, check orphans
function _load_profile --description "Determine, load, and validate the active profile"
    # 1. Determine name
    set -l name
    set -l default_file "$HOME/.config/ry-install/default-profile"
    set -l _name_from_file false
    if test -f "$default_file"
        set name (string trim < "$default_file")
        test -n "$name"; and set _name_from_file true
    end
    if test -z "$name"
        set name gtr9_pro
        if test "$_name_from_file" = false
            _log "PROFILE_DEFAULT: no $default_file — using built-in default '$name'"
        end
    end

    # 2. Validate name format
    if not string match -qr '^[a-z0-9][a-z0-9_-]*$' -- "$name"
        _err "Invalid profile name: '$name' (must be lowercase alphanumeric, starting with [a-z0-9])"
        command rm -f -- "$LOG_FILE" 2>/dev/null
        _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
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
            _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
        end
        source "$profile_path"
        # Bail check: sourced profile calling _ry_exit (via helper) sets sentinel; catch before profile fn invoke.
        test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
        if functions -q "_ry_profile_$name"
            _ry_profile_$name
        else if functions -q "profile_$name"
            # Backward compatibility: accept old profile_<name> convention with deprecation warning
            _warn "Profile uses deprecated naming: profile_$name → rename to _ry_profile_$name"
            profile_$name
        else
            _err "Profile file does not define function _ry_profile_$name: $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
        end
    else
        _err "Unknown profile: $name"
        command rm -f -- "$LOG_FILE" 2>/dev/null
        _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
    end

    # 4. Validate
    if not _validate_profile "$name"
        # EXIT_PREFLIGHT (not EXIT_USAGE): profile loaded but failed structural validation (missing globals, type errors).
        command rm -f -- "$LOG_FILE" 2>/dev/null
        _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
    end

    # 5. Derived globals
    set -g MANAGED_FILE_COUNT (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)

    # 6. Cache root UUID — findmnt called once; eliminates TOCTOU between _ry_install_file compare/write paths.
    set -g _ROOT_UUID (findmnt -no UUID / 2>/dev/null)
    if test -z "$_ROOT_UUID"
        # Hard-fail on missing root UUID for modes that generate/verify /etc/kernel/cmdline.
        switch "$MODE"
            case install install-file verify-static verify-runtime check
                _err "Cannot detect root UUID (findmnt failed) — /etc/kernel/cmdline cannot be generated"
                command rm -f -- "$LOG_FILE" 2>/dev/null
                _ry_exit $EXIT_PREFLIGHT; and return $EXIT_PREFLIGHT; or return $EXIT_PREFLIGHT
            case '*'
                _log "ROOT_UUID_UNAVAILABLE: mode=$MODE — non-fatal for this mode"
        end
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

# MANIFEST — orphan tracking across versions and profile switches

set -g MANIFEST_FILE "$HOME/ry-install/.manifest"

function _manifest_write --description "Record current profile destinations for orphan detection"
    # Create tmpfile in same directory as manifest for same-filesystem atomic mv
    set -l manifest_dir (dirname -- "$MANIFEST_FILE")
    # defensive mkdir -p — init block creates $HOME/ry-install but external rm could remove it mid-run
    command mkdir -p -- "$manifest_dir" 2>/dev/null
    set -l tmp (mktemp -p "$manifest_dir" .ry-install.manifest.XXXXXX 2>/dev/null)
    if test -z "$tmp"
        _warn "Failed to write manifest (mktemp failed)"
        return 1
    end
    # Track tmp for cleanup; on successful mv it disappears (rm -f is harmless), on failure cleanup removes the leftover.
    set -ga _TRACKED_TMPFILES "$tmp"
    printf '%s\n' "v$VERSION" "$PROFILE_NAME" $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS >"$tmp"
    if not command chmod -- 600 "$tmp" 2>/dev/null
        # FS without mode bits (FAT/exFAT $HOME) would silently leave a world-readable manifest with dest paths.
        _warn "Failed to chmod manifest tmpfile to 600 — manifest may be world-readable"
        _log "MANIFEST_CHMOD_FAIL: tmp=$tmp"
    end
    if not command mv -f -- "$tmp" "$MANIFEST_FILE" 2>/dev/null
        command rm -f -- "$tmp" 2>/dev/null
        _warn "Failed to write manifest"
        return 1
    end
    # Success: remove tmp from tracked list (mv consumed it)
    if set -q _TRACKED_TMPFILES
        set -l _new_tracked
        for _t in $_TRACKED_TMPFILES
            test "$_t" = "$tmp"; or set -a _new_tracked "$_t"
        end
        set -g _TRACKED_TMPFILES $_new_tracked
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

# Generate config content by destination path; exit 2=unknown, 3=missing prereq, 4=arity
function _ry_get_file_content --argument-names dst --description "Return embedded config content for a given destination path"
    if test (count $argv) -ne 1
        _err "_ry_get_file_content: expected 1 argument, got "(count $argv)
        return 4
    end
    switch "$argv[1]"

        case "/boot/loader/loader.conf"
            printf '%s\n' "# systemd-boot loader configuration" "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"

        case /etc/kernel/cmdline
            if test -z "$_ROOT_UUID"
                _err "_ry_get_file_content: root UUID not cached (_load_profile may not have run)"
                return 3
            end
            printf '%s %s\n' "rw root=UUID=$_ROOT_UUID" (string join -- " " $KERNEL_PARAMS)

        case "/etc/sdboot-manage.conf"
            printf '%s\n' "# sdboot-manage configuration — changes require: sudo sdboot-manage gen && sudo sdboot-manage update" "LINUX_OPTIONS=\""(string join -- " " $KERNEL_PARAMS)"\"" "LINUX_FALLBACK_OPTIONS=\"quiet\"" "DEFAULT_ENTRY=\"$SDBOOT_DEFAULT_ENTRY\"" "REMOVE_EXISTING=\"$SDBOOT_REMOVE_EXISTING\"" "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\"" "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\"" # lint:ignore (embedded user-facing shell advice)

        case "/etc/mkinitcpio.conf"
            printf '%s\n' "# mkinitcpio configuration — changes require: sudo mkinitcpio -P && sudo sdboot-manage update" "MODULES=("(string join -- " " $MKINITCPIO_MODULES)")" "BINARIES=()" "FILES=()" "HOOKS=("(string join -- " " $MKINITCPIO_HOOKS)")" "COMPRESSION=\"$MKINITCPIO_COMPRESSION\"" # lint:ignore (embedded user-facing shell advice)
            if set -q MKINITCPIO_COMPRESSION_OPTIONS; and test -n "$MKINITCPIO_COMPRESSION_OPTIONS"
                printf '%s\n' "COMPRESSION_OPTIONS=($MKINITCPIO_COMPRESSION_OPTIONS)"
            end

        case "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf"
            printf '%s\n' "# systemd-resolved configuration" "[Resolve]" "MulticastDNS=$RESOLVED_MDNS" "LLMNR=no" "DNSOverTLS=opportunistic" "DNSSEC=allow-downgrade"

        case "/etc/systemd/logind.conf.d/99-cachyos-logind.conf"
            printf '%s\n' "# systemd-logind configuration - desktop power handling"
            printf '%s\n' "[Login]"
            for key in $LOGIND_IGNORE_KEYS
                if test "$key" = HandleSecureAttentionKey
                    set -l _sd_ver (systemctl --version 2>/dev/null \
                        | head -n 1 | string match -r -- '\d+' | head -n 1)
                    if test -z "$_sd_ver"; or test "$_sd_ver" -lt 256
                        continue
                    end
                end
                printf '%s\n' "$key=ignore"
            end

        case "/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf"
            printf '%s\n' "# Disable coredump storage — Wine/Proton crashes can write multi-GB dumps" "[Coredump]" "Storage=none" "ProcessSizeMax=0"

        case "/etc/udev/rules.d/99-nvme-rqaffinity.rules"
            printf '%s\n' '# NVMe completion locality — pin completions to submitting core' 'ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/rq_affinity}="2"'

        case "/etc/iwd/main.conf"
            printf '%s\n' "# iwd configuration - minimal config for NetworkManager backend" "[General]" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "" "[DriverQuirks]"
            for quirk in $IWD_DRIVER_QUIRKS
                printf '%s\n' "$quirk"
            end
            printf '%s\n' "" "[Network]" "NameResolvingService=$IWD_DNS_SERVICE"

        case "/etc/NetworkManager/conf.d/99-cachyos-nm.conf"
            printf '%s\n' "# NetworkManager configuration - iwd backend" "[device]" "wifi.backend=$NM_WIFI_BACKEND" "" "[connection]" "wifi.powersave=$NM_WIFI_POWERSAVE" "wifi.iwd.autoconnect=false" "" "[logging]" "level=$NM_LOG_LEVEL"

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
            printf '%s\n' "# Environment variables for systemd user services and graphical sessions — loaded by systemd --user (COSMIC, Flatpak, D-Bus activated apps)"
            printf '%s\n' 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket' # lint:ignore (systemd env-line syntax, not fish ${var})
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

        case "/etc/systemd/system/cpupower-epp.service"
            # Tradeoff: permanent EPP=performance masks PPD, breaks CachyOS game-perf wrapper; alt: unmask PPD + ppctl.
            printf '%s\n' '[Unit]
Description=Set CPU EPP to performance (amd_pstate=active: powersave governor + performance EPP)
After=cpupower.service
Wants=cpupower.service
ConditionPathExists=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=10
# Inline bash retained: oneshot unit, no external dep, nullglob handles empty cpufreq dirs
ExecStart=/usr/bin/bash -c '\''shopt -s nullglob; for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$cpu" 2>/dev/null || logger -t cpupower-epp "EPP write failed: $cpu"; done; exit 0'\''

[Install]
WantedBy=multi-user.target'

        case /etc/drirc
            # RADV unified VRAM heap: prevents UMA APU games from misallocating. Requires Mesa ≥22.3.
            printf '%s\n' '<driconf>' \
                '  <device>' \
                '    <application name="Default">' \
                '      <option name="radv_enable_unified_heap_on_apu"' \
                '              value="true" />' \
                '    </application>' \
                '  </device>' \
                '</driconf>'

        case "/etc/sysctl.d/99-cachyos-sysctl.conf"
            printf '%s\n' "# ry-install sysctl tunables (priority 99 — loaded after CachyOS vendor 70-cachyos-settings.conf; overrides net.core.netdev_max_backlog 4096 → 16384)"
            for entry in $SYSCTL_VALUES
                set -l parts (string split -m1 '=' -- "$entry")
                set -l key (string trim -- "$parts[1]")
                set -l val (string trim -- "$parts[2]")
                printf '%s = %s\n' "$key" "$val"
            end

        case '*'
            # rc=2 signals unknown destination — _atomic_write_file maps this to "Not a managed destination" message.
            return 2
    end
    return 0
end

# BATCH & PARALLEL PREREQUISITES

function _pregenerate_content_files --argument-names out_dir --description "Write all expected-content files to a tmpdir (prereq for parallel consumers)"
    if test (count $argv) -gt 1
        _err "_pregenerate_content_files: expected 0-1 args (out_dir), got "(count $argv)
        return 1
    end
    # Must run after _load_profile — needs profile globals for _ry_get_file_content
    set -l _we_created_dir false
    if test -z "$out_dir"
        set out_dir (mktemp -d -t ry-content.XXXXXX)
        # bail on mktemp failure BEFORE set -ga to avoid tracking empty path
        if test -z "$out_dir"
            _err "_pregenerate_content_files: mktemp -d failed"
            return 1
        end
        set _we_created_dir true
    end
    if not test -d "$out_dir"
        return 1
    end
    # Only track for cleanup when we own the dir; caller-supplied dirs are caller's responsibility
    test "$_we_created_dir" = true; and set -ga _TRACKED_TMPFILES "$out_dir"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l safe (_tmpfile_key "$dst")
        # `2>&1 >file` order → cmdsubst captures stderr only (reversing routes both to file, empty cmdsubst).
        set -l _gen_err (_ry_get_file_content "$dst" 2>&1 >"$out_dir/$safe")
        set -l _gen_rc $status
        if test $_gen_rc -ne 0
            # Sentinel: distinguishes 'generator failed' from 'file intentionally skipped' for downstream consumers.
            command rm -f -- "$out_dir/$safe" 2>/dev/null
            printf 'genfail\n' >"$out_dir/$safe.genfail" 2>/dev/null
            _log "CONTENT_GEN_FAIL: dst=$dst rc=$_gen_rc"
            test -n "$_gen_err"; and _log "HASH_GENERATOR_STDERR: dst=$dst err=$_gen_err"
        end
    end
    # Only emit dir on stdout when we created it; caller-supplied dirs stay silent to avoid stray line in cmdsubst.
    test "$_we_created_dir" = true; and printf '%s\n' "$out_dir"
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
    # Probe `sudo -n -v` first (silent; redirect kills prompt); on miss retry `sudo -v` for tty password prompt.
    sudo -n -v 2>"$_sudo_err"
    set -l _rc $status
    if test $_rc -ne 0
        sudo -v 2>"$_sudo_err"
        set _rc $status
    end
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
    if test -n "$current_active"; or test -n "$current_unitfile"; or test -n "$current_load"
        printf '%s\n' "$current_load:$current_active:$current_unitfile"
    end
end

# Tmpfile key: slash→underscore of destination path. Collision guard lives in _validate_profile (rejects /a/b vs /a_b at load time).
function _tmpfile_key --argument-names path --description "Generate filename key from destination path (slash→underscore)"
    string replace -a '/' '_' -- "$path"
end

# LOGGING, MESSAGE OUTPUT, AND VERIFICATION COUNTERS

# Escape string for JSON embedding; function-scope reassignments use explicit set -l
function _json_str --description "Escape a string for safe JSON embedding"
    if test (count $argv) -ne 1
        if test -f "$LOG_FILE"
            printf '{"ts":"%s","event":"bug","data":"_json_str: expected 1 arg, got %d"}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (count $argv) >>"$LOG_FILE"
        end
        printf '\n'
        return 1
    end
    # Escape order: backslash first; `string collect` before \n escape prevents Fish splitting embedded newlines
    set -l val "$argv[1]"
    set -l val (string replace -a '\\' '\\\\' -- "$val" | string collect)
    set -l val (string replace -a '"' '\\"' -- "$val" | string collect)
    set -l val (string replace -a \t '\\t' -- "$val" | string collect)
    set -l val (string replace -a \r '\\r' -- "$val" | string collect)
    set -l val (string replace -a \n '\\n' -- "$val")
    set -l val (string replace -a \x08 '\\b' -- "$val")
    set -l val (string replace -a \x0c '\\f' -- "$val")
    set -l val (string replace -a \x00 '\\u0000' -- "$val")
    set -l val (string replace -ra '[\x01-\x07\x0b\x0e-\x1f\x7f\x80-\x9f]' '?' -- "$val")
    # printf '%s\n' ensures set -l val (...) captures one element even when $val is empty; '%s' alone yields zero
    printf '%s\n' "$val"
end

# INVARIANT: NEVER call _log from a `fish -c` parallel child — no file locking, concurrent writes corrupt JSONL.
function _log --description "Append a timestamped JSONL line to LOG_FILE"
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
        # Step back from cut point if inside a JSON escape sequence (\uXXXX, \t/\n/\r/\b/\f, trailing \).
        set -l tail3 (string sub -s (math $cut - 7) -l 8 -- "$data")
        set -l _esc_match (string match -r '\\\\([tnrbf]|u[0-9a-fA-F]{0,4}|\\\\?)$' -- "$tail3" | head -n 1)
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
    set -l valid_levels INFO WARN ERR FAIL OK
    if not contains -- "$level" $valid_levels
        echo "[BUG] _msg called with invalid level: '$level'" >&2
        if test -n "$LOG_FILE"; and test -f "$LOG_FILE"
            printf '{"ts":"%s","event":"bug","data":"_msg called with invalid level: %s"}\n' (date '+%Y-%m-%dT%H:%M:%S%z') (_json_str "$level") >>"$LOG_FILE"
        end
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
                end
                echo -n "[$level]"
                set_color normal
                echo " $msg"
            end >&2
        end
    end
end

# Convenience wrappers: _ok/_fail/_info/_warn/_err delegate to _msg with fixed level
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

function _banner --argument-names text --description "Print the ry-install startup banner"
    if test (count $argv) -lt 1
        return 0
    end
    set -l border "┌──────────────────────────────────────────────────────────────────┐"
    set -l bottom "└──────────────────────────────────────────────────────────────────┘"
    # inner = border width in codepoints; max_text = inner - len(prefix) - len(suffix) = 68 - 3 - 2 = 63
    set -l inner 68
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

# Progress bar: step tracking with timing for multi-phase operations
set -g PROGRESS_CURRENT 0
# 40-char bar fits 60-col minimum terminal (15 cols for [XX/YY] prefix + padding)
set -g PROGRESS_WIDTH 40
set -g PROGRESS_START_TIME 0
set -g PROGRESS_STEP_START 0
set -g PROGRESS_STEPS \
    Preflight \
    Packages \
    Configuration \
    Services \
    Boot \
    Finalize
set -g PROGRESS_TOTAL (count $PROGRESS_STEPS)

function _emit_step_time --description "Log elapsed time for the previous progress step"
    if test -n "$_STEP_PREV_NAME"; and test "$_STEP_PREV_START" -gt 0
        set -l _step_now (date +%s)
        set -l _step_elapsed (math "$_step_now - $_STEP_PREV_START")
        set -l _step_name_esc (_json_str "$_STEP_PREV_NAME")
        printf '{"ts":"%s","event":"step_time","data":"%s","elapsed_s":%d}\n' \
            (date '+%Y-%m-%dT%H:%M:%S%z') "$_step_name_esc" "$_step_elapsed" >>"$LOG_FILE"
    end
end

# Reset progress counters and compute PROGRESS_TOTAL from PROGRESS_STEPS list
function _progress_init --description "Initialize the step progress counter"
    set -g _STEP_PREV_NAME ""
    set -g _STEP_PREV_START 0
    set -g PROGRESS_CURRENT 0
    set -g PROGRESS_START_TIME (date +%s)
    # seed with current time so step 1 elapsed display is non-empty
    set -g PROGRESS_STEP_START (date +%s)
    printf '\n' >&2
end

# Advance to next step: emit timing for previous step, display [N/M] progress bar to stderr
function _progress --argument-names step_name skip_flag --description "Advance and display the current progress step; pass 'skip' as second arg for a skipped step"
    if test (count $argv) -lt 1
        return 0
    end
    set -l is_skip false
    test "$skip_flag" = skip; and set is_skip true

    _emit_step_time
    set -g _STEP_PREV_NAME "$step_name"
    set -g _STEP_PREV_START (date +%s)

    if test "$PROGRESS_TOTAL" -le 0 2>/dev/null
        return 0
    end
    # Advance progress counter and emit step banner
    set -g PROGRESS_CURRENT (math "min($PROGRESS_CURRENT + 1, $PROGRESS_TOTAL)")
    set -l pct (math "floor($PROGRESS_CURRENT * 100 / $PROGRESS_TOTAL)")
    set -l filled (math "floor($PROGRESS_CURRENT * $PROGRESS_WIDTH / $PROGRESS_TOTAL)")
    set -l empty (math "$PROGRESS_WIDTH - $filled")

    # Fix: `string repeat -n 0` exits 1, erasing adjacent cmdsubst; at 100%/0% rendered `[]`. Build conditionally.
    set -l bar_filled ""
    set -l bar_empty ""
    test $filled -gt 0; and set bar_filled (string repeat -n $filled -- '█')
    test $empty -gt 0; and set bar_empty (string repeat -n $empty -- '░')
    set -l bar "$bar_filled$bar_empty"

    set -l step_elapsed ""
    if test "$is_skip" = false
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
    end

    # Skip the bar on narrow terminals (<60 cols) to avoid wrap+\r tail garbage
    set -l _term_cols (tput cols 2>/dev/null; or echo 80)
    if not string match -qr '^\d+$' -- "$_term_cols"; or test "$_term_cols" -lt 60
        if test "$is_skip" = true
            _log "PROGRESS_SKIP: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $step_name"
        else
            _log "PROGRESS: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $step_name"
        end
        return 0
    end

    set -l desc
    if test (string length -- "$step_name") -gt 25
        set desc (string sub -l 22 -- "$step_name")"..."
    else
        set desc (string sub -l 25 -- "$step_name                              ")
    end

    if test "$is_skip" = true
        printf '\r[%s] %3d%% %s (skip)' "$bar" "$pct" "$desc" >&2
        _log "PROGRESS_SKIP: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $step_name"
    else
        printf '\r[%s] %3d%% %s%s' "$bar" "$pct" "$desc" "$step_elapsed" >&2
        _log "PROGRESS: [$PROGRESS_CURRENT/$PROGRESS_TOTAL] $step_name"
    end
end

# Close progress display: emit final step timing, fill bar to 100%, reset state
function _progress_done --description "Finalize and close the progress display"
    _emit_step_time
    set -g _STEP_PREV_NAME ""
    set -g _STEP_PREV_START 0

    # Runtime assertion: catch step count drift
    if test "$PROGRESS_CURRENT" -ne "$PROGRESS_TOTAL" 2>/dev/null
        _warn "Progress step mismatch: emitted $PROGRESS_CURRENT of $PROGRESS_TOTAL expected"
    end

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

# INVARIANT: callers pass pre-expanded argv with no shell metacharacters ([;|&`$\n\t\r<>(){}]); _run rejects them.
function _run --description "Execute a command with logging, stdout/stderr capture, and timeout enforcement"
    if test (count $argv) -eq 0
        _log "BUG: _run called with no arguments"
        return 1
    end
    # SECURITY: reject argv with shell metachars (;|&`$\n\t\r<>(){}) — defense for log integrity + profile sourcing.
    for _arg in $argv
        if string match -qr '[;|&`\$\n\t\r<>(){}]' -- "$_arg"
            _err "_run: argv contains shell metacharacter — refusing command (see log for detail)"
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

    # Single mktemp -d for the pair: halves inode pressure under heavy parallel use
    set -l _run_dir (mktemp -d -t ry-run.XXXXXX 2>/dev/null)
    set -l stderr_tmp
    set -l stdout_tmp
    if test -n "$_run_dir"; and test -d "$_run_dir"
        set stderr_tmp "$_run_dir/stderr"
        set stdout_tmp "$_run_dir/stdout"
        set -ga _TRACKED_TMPFILES "$_run_dir"
    else
        # Fail-loud — silent stderr would mask transient errors in pacman/sdboot-manage (top callers). Refuse to run.
        _log "RUN_ABORT: mktemp -d failed — refusing to execute without stderr capture"
        _err "_run: cannot allocate tmpdir for stdout/stderr capture — aborting command"
        return 1
    end
    # SECURITY: $argv internal callers only; </dev/null prevents terminal hangs; timeout 3600s (RY_RUN_TIMEOUT).
    set -l _run_timeout
    if set -q RY_RUN_TIMEOUT; and test -n "$RY_RUN_TIMEOUT"
        if test "$RY_RUN_TIMEOUT" = 0
            # Explicit opt-out
            set _run_timeout ""
        else if string match -qr '^[1-9]\d*$' -- "$RY_RUN_TIMEOUT"
            set _run_timeout "$RY_RUN_TIMEOUT"
        else
            # Invalid value — warn once per run and fall back to default rather than silently disabling timeout.
            if not set -q _RY_RUN_TIMEOUT_WARNED
                set -g _RY_RUN_TIMEOUT_WARNED true
                _warn "RY_RUN_TIMEOUT='$RY_RUN_TIMEOUT' is invalid (expected positive integer or 0 to disable) — using default 3600s"
                _log "RY_RUN_TIMEOUT_INVALID: value=$RY_RUN_TIMEOUT — using default 3600"
            end
            set _run_timeout 3600
        end
    else
        set _run_timeout 3600
    end
    if test -n "$_run_timeout"; and command -q timeout
        command timeout --preserve-status --kill-after=10 "$_run_timeout" $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    else
        # `command` prefix forces external binary — prevents fish function recursion when timeout(1) unavailable.
        command $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    end
    set -l ret $status
    if test -s "$stderr_tmp"
        set -l total_err (command wc -l < "$stderr_tmp" | string trim --)
        set -l first_lines (command head -n 5 "$stderr_tmp")
        set -l dedup_lines (command head -n 10000 "$stderr_tmp" | LC_ALL=C command sort | command uniq -c | command sort -rn | string trim --left)
        _log "STDERR: ($total_err lines) first: "(string join -- " | " $first_lines)" | dedup: "(string join -- " | " $dedup_lines)
        if test "$QUIET" = false
            for el in $first_lines
                echo "  stderr: $el" >&2
            end
            if test $total_err -gt 5
                echo "  stderr: ... ($total_err lines total, showing first 5)" >&2
            end
        end
    end
    if test -s "$stdout_tmp"
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
    # stdout_tmp and stderr_tmp are inside _run_dir; single rm -rf below cleans both
    if test -n "$_run_dir"; and test -d "$_run_dir"
        command rm -rf --preserve-root -- "$_run_dir" 2>/dev/null
        # remove from tracked list (cleanup already happened)
        if set -q _TRACKED_TMPFILES
            set -l _new_tracked
            for _t in $_TRACKED_TMPFILES
                test "$_t" = "$_run_dir"; or set -a _new_tracked "$_t"
            end
            set -g _TRACKED_TMPFILES $_new_tracked
        end
    end
    _log "EXIT: $ret cmd=$log_cmd"
    return $ret
end

# Display full usage, options, exit codes, and examples to stdout
function _ry_show_help --description "Display usage information and available subcommands"
    # Fallback: use compile-time constant if profile hasn't loaded (--help exits before _load_profile)
    set -l _file_count "$MANAGED_FILE_COUNT"
    if test -z "$_file_count"
        set _file_count $_RY_MANAGED_FILE_COUNT
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
  (no args)         Unattended install (the only mode)
  -V, --verbose     Show output on terminal (default: silent, log only)

VERIFICATION:
  --verify-static   Check config files exist with correct content
  --verify-runtime  Check live system state (run after reboot)
  --check           Silent idempotency probe (exit 0 = clean, exit 3 = prereq fail, exit 10 = drift)

UTILITIES:
  --install-file <path>  Re-deploy a single managed file

OPTIONS:
  --                End of options (remaining arguments ignored)
  -h, --help        Show this help
  -v, --version     Show version

Unattended install is the only mode. There is no preview, diff, or repair mode.
For drift detection, use --verify-static / --verify-runtime.

EXIT CODES:
  0 ok · 1 non-critical · 2 usage · 3 preflight · 4 boot-critical · 5 lock · 10 drift
  129/130/131/143 signal · 141 SIGPIPE

ENVIRONMENT:
  RY_RUN_TIMEOUT=<seconds>    Wall-clock limit for each _run. Default 3600. 0=disable.
  RY_INSTALL_CONFIRM_BOOT_WIPE=1    One-time ack for SDBOOT_REMOVE_EXISTING=yes.
  RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1    Ack for unattended pacman -Syu (review arch/cachy news first).

Log: ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS+ZZZZ.jsonl
See README.md for full reference.
"
end

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

function _ry_check_deps --description "Verify required packages are installed"
    _log "Checking dependencies..."
    set -l missing

    # HARD: GNU mktemp --suffix=, find -printf. SOFT: flock(1) — non-atomic fallback in _acquire_lock.
    for cmd in pacman systemctl mkinitcpio udevadm sdboot-manage findmnt sha256sum stat date
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

    if set -q AUR_PKGS; and test (count $AUR_PKGS) -gt 0
        if not command -q paru
            _err "paru not found — required for AUR packages ($AUR_PKGS)"
            _err "  Install paru first: sudo pacman -S --needed paru"
            _err "  AUR packages include critical drivers (e.g. WiFi DKMS) — install will be marked failed"
            set -g INSTALL_HAD_ERRORS true
            return 1
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
            # fd-order: 2>&1 >/dev/null — stderr to capture pipe BEFORE stdout to /dev/null. Do NOT swap.
            set -l _curl_err (curl -sf --connect-timeout 3 --max-time 5 --head "$_probe" 2>&1 >/dev/null)
            if test $status -eq 0
                _ok "Network connectivity: OK"
                return 0
            else
                _log "NETWORK: curl probe $_probe failed: $_curl_err"
            end
        end
    end

    _info "Checking DNS resolution..."
    for _probe_host in archlinux.org cachyos.org
        # fd-order: see curl site above
        set -l _ping_err (ping -c 1 -W 3 $_probe_host 2>&1 >/dev/null)
        if test $status -eq 0
            _ok "Network connectivity: OK (ping)"
            return 0
        else
            _log "NETWORK: ping $_probe_host failed: $_ping_err"
        end
    end

    _info "Checking raw IP connectivity..."
    for _ip in 1.1.1.1 8.8.8.8
        if ping -c 1 -W 3 $_ip >/dev/null 2>&1
            _log "NETWORK: raw IP $_ip reachable but DNS failed — likely /etc/resolv.conf issue"
            _err "Network connectivity: DNS resolution failed (raw IP reachable)"
            _err "  Check /etc/resolv.conf or systemd-resolved configuration"
            return 1
        end
    end

    _log "NETWORK: all probes failed (HTTPS, DNS, raw IP)"
    _err "Network connectivity: FAILED"
    _err "  Cannot reach archlinux.org - check your network connection"
    _err "  Package installation requires internet access"
    return 1
end

# Ensure root and /boot have sufficient free space; warn/fail at configurable thresholds
function _ry_check_disk_space --description "Verify sufficient free disk space for installation"
    _log "Checking disk space..."

    # df -B1 for byte-precision; -BG/-BM round UP and create false-pass at boundary
    set -l root_avail_b (LC_ALL=C df -B1 / 2>/dev/null | tail -n 1 | awk '{print $4}')
    set -l root_avail ""
    if test -n "$root_avail_b"; and string match -qr '^\d+$' -- "$root_avail_b"
        set root_avail (math "floor($root_avail_b / 1073741824)")
    end
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

    set -l boot_avail_b (LC_ALL=C df -B1 /boot 2>/dev/null | tail -n 1 | awk '{print $4}')
    set -l boot_avail ""
    if test -n "$boot_avail_b"; and string match -qr '^\d+$' -- "$boot_avail_b"
        set boot_avail (math "floor($boot_avail_b / 1048576)")
    end
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

function _ry_check_kernel_version --description "Verify running kernel version meets minimum requirement"
    set -l kver $KVER
    set -l major $KVER_MAJOR
    set -l minor $KVER_MINOR

    _info "Kernel version: $kver"

    # Minimum: 6.14 (ntsync, gfx1151 fixes)
    if test "$major" -lt 6; or begin
            test "$major" -eq 6; and test "$minor" -lt 14
        end
        _fail "Kernel $kver < 6.14: ntsync and gfx1151 fixes unavailable"
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

# Config validation pipeline: pre-flight checks on embedded content; aborts on any error

# Validate HOOKS ordering (base first, keyboard before sd-vconsole, etc.) and hook existence
function _ry_validate_mkinitcpio_hooks --description "Validate mkinitcpio HOOKS ordering and presence"
    set -l existence_only false
    set -l hooks
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
        set -l order_checks \
            "autodetect:modconf" \
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

function _ry_validate_configs --description "Run all embedded config validators"
    _info "Validating configuration syntax..."

    set -l errors 0

    # Phase 1 (sequential): fast in-memory checks + content pre-generation
    if not _ry_validate_mkinitcpio_hooks
        set errors (math $errors + 1)
    end
    _ry_validate_mkinitcpio_modules

    # Pre-generate all content files for parallel validation
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

    # Phase 1 (sequential): fast in-memory checks + content pre-generation
    printf '%s\n' $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS >"$val_dir/xref_dsts"

    # Phase 2 (parallel): fork independent validation jobs

    # Job 1: cross-reference check — per-destination existence and content verification.
    command timeout --preserve-status --kill-after=5 60 fish -c '
        set -l errs 0
        set -l genfails 0
        set -l content_dir $argv[1]
        set -l val_dir $argv[2]
        set -l dsts (command cat -- "$val_dir/xref_dsts")
        for dst in $dsts
            set -l safe (string replace -a "/" "_" -- "$dst")
            if test -e "$content_dir/$safe.genfail"
                set genfails (math $genfails + 1)
                continue
            end
            if not test -e "$content_dir/$safe"
                set errs (math $errs + 1)
            end
        end
        echo $errs > "$val_dir/xref.errors"
        echo $genfails > "$val_dir/xref.genfails"
    ' -- "$content_dir" "$val_dir" >/dev/null 2>"$val_dir/xref.stderr" &
    set -l pid_xref $last_pid

    # Job 2: systemd unit syntax — derive keys from SERVICE_DESTINATIONS (system) + USER_DESTINATIONS (user scope)
    set -l _svc_dsts
    for _sd in $SERVICE_DESTINATIONS
        set -a _svc_dsts "$_sd"
    end
    for _ud in $USER_DESTINATIONS
        if string match -q '*.service' -- "$_ud"
            set -a _svc_dsts "$_ud"
        end
    end
    command timeout --preserve-status --kill-after=5 60 fish -c '
        set -l errs 0
        set -l content_dir $argv[1]
        set -l val_dir $argv[2]
        set -l my_home $argv[3]
        set -l svc_dsts $argv[4..]
        if not command -q systemd-analyze
            echo $errs > "$val_dir/units.errors"
            exit 0
        end
        if test (count $svc_dsts) -eq 0
            # No service destinations in this profile — no units to validate.
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
    ' -- "$content_dir" "$val_dir" "$HOME" $_svc_dsts >/dev/null 2>"$val_dir/units.stderr" &
    set -l pid_units $last_pid

    # Job 3: fish script syntax + environment.d check
    command timeout --preserve-status --kill-after=5 60 fish -c '
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
    ' -- "$content_dir" "$val_dir" "$HOME" >/dev/null 2>"$val_dir/scripts.stderr" &
    set -l pid_scripts $last_pid

    # Job 4: INI section-header validation (4 configs)
    command timeout --preserve-status --kill-after=5 60 fish -c '
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
            set -l f "$content_dir/$key"
            if not test -s "$f"
                set errs (math $errs + 1)
                continue
            end
            for section in $sections
                # -qFx (whole-line match) closes false-positive where section name appears inside a comment or value
                if not grep -qFx -- "$section" "$f"
                    set errs (math $errs + 1)
                end
            end
        end
        echo $errs > "$val_dir/ini.errors"
    ' -- "$content_dir" "$val_dir" >/dev/null 2>"$val_dir/ini.stderr" &
    set -l pid_ini $last_pid

    # Job 5: simple key-value config validation (3 configs)
    command timeout --preserve-status --kill-after=5 60 fish -c '
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
    ' -- "$content_dir" "$val_dir" >/dev/null 2>"$val_dir/simple.stderr" &
    set -l pid_simple $last_pid

    # Wait for all validation children; fish's wait does not propagate child exit status, so per-phase detection relies on the result-file-presence check below.
    wait $pid_xref $pid_units $pid_scripts $pid_ini $pid_simple

    # Merge error counts — treat missing result files as child crash/timeout (prevents false-pass).
    for phase in xref units scripts ini simple
        if not test -f "$val_dir/$phase.errors"
            _err "Validation child '$phase' did not write results (crashed or timed out after 60s)"
            if test -s "$val_dir/$phase.stderr"
                _log "VALIDATE_CHILD_STDERR: ($phase) "(head -n 15 "$val_dir/$phase.stderr")
            end
            set errors (math $errors + 1)
            continue
        end
        if test -s "$val_dir/$phase.stderr"
            _log "VALIDATE_STDERR: ($phase) "(head -n 15 "$val_dir/$phase.stderr")
            # Surface warnings to terminal so user sees systemd-analyze/fish diagnostics
            set -l _child_lines (command head -n 5 "$val_dir/$phase.stderr")
            for _cl in $_child_lines
                _warn "  validate($phase): $_cl"
            end
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

    # Surface xref.genfails from _pregenerate_content_files sentinels (v3.51.3); single genfail fail-closes dst.
    if test -f "$val_dir/xref.genfails"
        set -l _gf (command cat -- "$val_dir/xref.genfails" 2>/dev/null | string trim --)
        if test -n "$_gf"; and string match -qr '^\d+$' -- "$_gf"; and test "$_gf" -gt 0
            _err "Content generator failed for $_gf destination(s) — see HASH_GENERATOR_STDERR in log"
            set errors (math $errors + $_gf)
        end
    end

    command rm -rf --preserve-root -- "$val_dir" "$content_dir"
    # Prune tracked entries after explicit cleanup (mirrors _run's cleanup pattern; prevents array growth).
    if set -q _TRACKED_TMPFILES
        set -l _new_tracked
        for _t in $_TRACKED_TMPFILES
            test "$_t" = "$val_dir"; or test "$_t" = "$content_dir"; or set -a _new_tracked "$_t"
        end
        set -g _TRACKED_TMPFILES $_new_tracked
    end

    if test $errors -gt 0
        _err "Validation failed with $errors error(s)"
        return 1
    end

    _ok "All configurations validated"
    return 0
end

# First non-comment KEY=... line from a conf file; used by mkinitcpio HOOKS/MODULES xref checks

function _ry_mkinitcpio_array --argument-names key file --description "First non-comment KEY=... line from a conf file"
    test -z "$file"; and set file /etc/mkinitcpio.conf
    # Trust: $key is always a literal from a fixed caller set (HOOKS, MODULES, etc). Safe for grep -E interpolation.
    grep -E "^[[:space:]]*$key=" "$file" 2>/dev/null | grep -v '^[[:space:]]*#' | head -n 1
end

# Single canonical hash method for embedded content. Used by _ry_install_file and _atomic_write_file.
function _content_hash --argument-names dst --description "SHA256 of embedded content for a destination, or empty on generator failure"
    if test (count $argv) -ne 1
        _err "_content_hash: expected 1 arg (dst), got "(count $argv)
        return 1
    end
    # Capture $pipestatus immediately; [1]=_ry_get_file_content, [2]=string collect (fish, OOM-only failure).
    set -l _content (_ry_get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines)
    set -l _ps $pipestatus
    test $_ps[1] -ne 0; and return 1
    test $_ps[2] -ne 0; and return 1
    test -z "$_content"; and return 1
    # Inline index via `string split` replaces external head(1). pipestatus[1..2] covers printf+sha256sum.
    set -l _hash_line (printf '%s' "$_content" | sha256sum)
    set -l _ps $pipestatus
    if test $_ps[1] -ne 0; or test $_ps[2] -ne 0
        return 1
    end
    set -l _hash (string split ' ' -- "$_hash_line")[1]
    test -z "$_hash"; and return 1
    printf '%s\n' "$_hash"
    return 0
end

# Atomic write: mktemp→symlink-check→write→symlink-recheck→chmod→hash→mv→verify→chown
function _atomic_write_file --argument-names dst perms use_sudo --description "Atomic file write with symlink and integrity checks"
    if test (count $argv) -ne 3
        _err "_atomic_write_file: expected 3 args (dst perms use_sudo), got "(count $argv)
        return 1
    end

    set -l dst_dir (dirname -- "$dst")
    # Parent-dir trust: must exist, be a real directory (not symlink), root-owned (uid 0), not group/world-writable.
    if test "$use_sudo" = true
        set -l _dir_stat (LC_ALL=C sudo stat -c '%F %u %a' -- "$dst_dir" 2>/dev/null)
        if test -z "$_dir_stat"
            _fail "→ $dst (parent dir missing or unreadable: $dst_dir)"
            return 1
        end
        set -l _dir_fields (string split ' ' -- "$_dir_stat")
        set -l _dir_type "$_dir_fields[1]"
        set -l _dir_uid "$_dir_fields[2]"
        set -l _dir_mode "$_dir_fields[3]"
        # %F reports 'directory' for real dirs. `sudo stat` follows symlinks, so `sudo test -L` is still needed.
        if test "$_dir_type" != directory
            _fail "→ $dst (parent dir not a regular directory: type=$_dir_type $dst_dir)"
            return 1
        end
        if sudo test -L "$dst_dir"
            _fail "→ $dst (parent dir is a symlink: $dst_dir)"
            return 1
        end
        if test "$_dir_uid" != 0
            _fail "→ $dst (parent dir not root-owned: uid=$_dir_uid)"
            return 1
        end
        # Reject if group or world writable (canonical helper — see _dir_group_or_world_writable)
        if _dir_group_or_world_writable "$_dir_mode"
            _fail "→ $dst (parent dir group/world writable: mode=$_dir_mode)"
            return 1
        end
    end
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
    # Track immediately after mktemp so SIGKILL doesn't leak .ry-install.XXXXXX files.
    set -ga _TRACKED_TMPFILES "$tmpfile"

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
        # Distinct error messages per generator rc (2=unknown dst, 3=missing prereq, 4=arity bug).
        switch $_ps[1]
            case 2
                _err "Not a managed destination: $dst"
            case 3
                _err "Content generator missing prerequisite global (e.g. _ROOT_UUID): $dst"
            case 4
                _err "Internal bug in _ry_get_file_content arity check (dst=$dst)"
            case '*'
                _err "Content generator failed for $dst (rc=$_ps[1])"
        end
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

    # Pre+post-write symlink recheck closes TOCTOU between pre-write test -L and tee (mktemp/tee race).
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

    # Expected hash via canonical helper — fail-closed on generator failure
    set -l _expected_hash (_content_hash "$dst")
    set -l _gen_rc $status
    # Fail-closed: empty hash OR generator failure means generator failure — never silently accept
    if test $_gen_rc -ne 0; or test -z "$_expected_hash"
        if test "$use_sudo" = true
            sudo rm -f -- "$tmpfile" 2>/dev/null
        else
            command rm -f -- "$tmpfile" 2>/dev/null
        end
        _fail "→ $dst (pre-mv hash unavailable — generator returned empty)"
        _log "HASH_UNAVAILABLE: dst=$dst use_sudo=$use_sudo"
        return 1
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

    # Post-write integrity: verify mv preserved content. Uses sudo -n to detect credential lapse.
    set -l _actual_hash
    set -l _hash_fail_reason ""
    if test "$use_sudo" = true
        # Pre-probe sudo cred to distinguish auth-lapse from fs-error
        if not sudo -n true 2>/dev/null
            set _hash_fail_reason "sudo credential lapsed"
        else
            # Capture sha256sum first; cat-fail empty-stdin hash would dodge `test -z` guard (misread as mismatch).
            set -l _raw_line (sudo -n cat -- "$dst" 2>/dev/null | sha256sum)
            set -l _ps $pipestatus
            if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
                set _actual_hash (string split ' ' -- "$_raw_line")[1]
            end
            test -z "$_actual_hash"; and set _hash_fail_reason "filesystem read error after write"
        end
    else
        set -l _raw_line (command cat -- "$dst" 2>/dev/null | sha256sum)
        set -l _ps $pipestatus
        if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
            set _actual_hash (string split ' ' -- "$_raw_line")[1]
        end
        test -z "$_actual_hash"; and set _hash_fail_reason "filesystem read error after write"
    end
    if test -z "$_actual_hash"
        _fail "→ $dst (post-write hash unavailable: $_hash_fail_reason)"
        _log "HASH_UNAVAILABLE_POST: dst=$dst reason=$_hash_fail_reason"
        return 1
    end
    if test "$_expected_hash" != "$_actual_hash"
        # Classify: re-probe sudo to distinguish content mismatch from credential lapse (empty pipe → empty-file hash).
        if test "$use_sudo" = true; and not sudo -n true 2>/dev/null
            _fail "→ $dst (post-write hash unavailable: sudo credential lapsed mid-verify)"
            _log "HASH_UNAVAILABLE_POST: dst=$dst reason=sudo credential lapsed mid-verify"
        else
            _fail "→ $dst (post-write checksum mismatch)"
            _log "HASH_MISMATCH: expected=$_expected_hash actual=$_actual_hash dst=$dst"
        end
        return 1
    end

    # Ownership: sudo mktemp creates root:root, user mktemp inherits uid/gid. No post-mv chown needed.
    _ok "→ $dst"
    return 0
end

# Deploy single embedded config: content → mktemp → chmod → mv; skips unchanged + iwd-less NM/IWD
function _ry_install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
    if test (count $argv) -ne 2
        _err "_ry_install_file: expected 2 args (dst use_sudo), got "(count $argv)
        return 1
    end
    set -l dst $argv[1]
    set -l use_sudo $argv[2]

    # lazy-cache iwd skip state — first call probes, subsequent calls hit cache
    if not set -q _RY_SKIP_IWD_CACHED
        if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
            set -g _RY_SKIP_IWD true
        else
            set -g _RY_SKIP_IWD false
        end
        set -g _RY_SKIP_IWD_CACHED true
    end

    if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
        if test "$_RY_SKIP_IWD" = true
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

    set -l _new_hash (_content_hash "$dst")
    if test -n "$_new_hash"
        set -l _cur_hash
        if test "$use_sudo" = true
            # Sudo precheck: keepalive lapse → skip the skip-check (force re-deploy) vs empty-hash silent path.
            if sudo -n true 2>/dev/null
                # Capture sha256sum first; cat-fail empty-stdin hash would mask as matching current hash.
                set -l _raw_line (sudo -n cat -- "$dst" 2>/dev/null | sha256sum)
                set -l _ps $pipestatus
                if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
                    set _cur_hash (string split ' ' -- "$_raw_line")[1]
                end
            else
                _log "SKIP_PROBE_SUDO_LAPSED: dst=$dst — re-deploying"
            end
        else
            set -l _raw_line (command cat -- "$dst" 2>/dev/null | sha256sum)
            set -l _ps $pipestatus
            if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
                set _cur_hash (string split ' ' -- "$_raw_line")[1]
            end
        end
        if test -n "$_cur_hash"; and test "$_new_hash" = "$_cur_hash"
            _ok "→ $dst (unchanged)"
            return 0
        end
    end

    _atomic_write_file "$dst" $perms $use_sudo
    return $status
end

# FILE OPERATIONS — diff, install, verify

function _ry_install_files --description "Install multiple embedded configs with argparse options"
    set -l _argparse_tmp (mktemp -t ry-argparse.XXXXXX 2>/dev/null; or echo /dev/null)
    test "$_argparse_tmp" != /dev/null; and set -ga _TRACKED_TMPFILES "$_argparse_tmp"
    if test "$_argparse_tmp" = /dev/null; and not set -q _MKTEMP_DEGRADED_WARNED
        set -g _MKTEMP_DEGRADED_WARNED true
        _warn "mktemp failed — argparse error capture degraded; stderr from argparse will be lost"
        _log "WARN: mktemp fallback to /dev/null — argparse error capture degraded"
    end
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

# Checksum verification: sha256 of embedded content vs installed file; exit 1 when drifted.
function _ry_verify_static --description "Verify installed configs match embedded checksums"
    _log "=== STATIC VERIFICATION START ==="
    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
        # use EXIT_PREFLIGHT constant for consistency with other modes
        return $EXIT_PREFLIGHT
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

    # Pre-compute LVM state — lvm2-monitor.service is intentionally unmasked when LVM detected
    set -l _has_lvm false
    _detect_lvm; and set _has_lvm true

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
            | string replace -r -- '^LINUX_OPTIONS="([^"]*)".*$' '$1') # lint:ignore (PCRE backref)

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
        _chk_grep /etc/sdboot-manage.conf "DEFAULT_ENTRY=\"$SDBOOT_DEFAULT_ENTRY\"" "DEFAULT_ENTRY=$SDBOOT_DEFAULT_ENTRY"
        _chk_grep /etc/sdboot-manage.conf 'LINUX_FALLBACK_OPTIONS="quiet"' "LINUX_FALLBACK_OPTIONS=quiet"
    end
    _echo

    _echo "── kernel cmdline ──"
    if _chk_file /etc/kernel/cmdline
        set -l cmdline_content (sudo -n cat -- /etc/kernel/cmdline 2>/dev/null)
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
        set -l modules_line (_ry_mkinitcpio_array MODULES)
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
            set -l _mod_re (string escape --style=regex -- "$mod")
            if string match -qr "\\b$_mod_re\\b" -- "$modules_line"
                _ok "  $mod: present"
            else
                _fail "  $mod: MISSING"
            end
        end

        set -l hooks_line (_ry_mkinitcpio_array HOOKS)
        _echo "  Config: $hooks_line"

        for hook in $MKINITCPIO_HOOKS
            set -l _hook_re (string escape --style=regex -- "$hook")
            if string match -qr "\\b$_hook_re\\b" -- "$hooks_line"
                _ok "  $hook: present"
            else
                _fail "  $hook: MISSING"
            end
        end

        set -l comp_line (_ry_mkinitcpio_array COMPRESSION)
        if string match -q '*zstd*' -- "$comp_line"
            _ok "  COMPRESSION=zstd: present"
        else
            _fail "  COMPRESSION=zstd: MISSING"
        end

        if set -q MKINITCPIO_COMPRESSION_OPTIONS; and test -n "$MKINITCPIO_COMPRESSION_OPTIONS"
            set -l comp_opts_line (_ry_mkinitcpio_array COMPRESSION_OPTIONS)
            if string match -q "*$MKINITCPIO_COMPRESSION_OPTIONS*" -- "$comp_opts_line"
                _ok "  COMPRESSION_OPTIONS=$MKINITCPIO_COMPRESSION_OPTIONS: present"
            else
                _fail "  COMPRESSION_OPTIONS=$MKINITCPIO_COMPRESSION_OPTIONS: MISSING"
            end
        end
    end
    _echo

    _echo "── Boot entries ──"
    set -l entry_count 0
    if sudo test -d /boot/loader/entries 2>/dev/null
        set entry_count (sudo find /boot/loader/entries -maxdepth 1 -type f -name "*.conf" 2>/dev/null | wc -l | string trim --)
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
    if test -f /usr/lib/modules-load.d/10-ntsync.conf
        _ok "  ntsync autoload: /usr/lib/modules-load.d/10-ntsync.conf present (shipped by wine-cachyos)"
    else
        _warn "  ntsync autoload: /usr/lib/modules-load.d/10-ntsync.conf missing — module may not load on boot"
    end
    _echo

    _echo "── resolved ──"
    if _chk_file /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "MulticastDNS=$RESOLVED_MDNS" "MulticastDNS=$RESOLVED_MDNS"
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "DNSOverTLS=opportunistic" "DNSOverTLS=opportunistic"
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "DNSSEC=allow-downgrade" "DNSSEC=allow-downgrade"
        _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "LLMNR=no" "LLMNR=no"
    end
    _echo

    _echo "── logind.conf ──"
    if _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf
        for key in $LOGIND_IGNORE_KEYS
            _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
        end
    end
    _echo

    _echo "── coredump.conf ──"
    if _chk_file /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf
        _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "Storage=none" "Storage=none"
        _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "ProcessSizeMax=0" "ProcessSizeMax=0"
    end
    _echo

    _echo "── iwd ──"
    if test "$_skip_iwd" = true
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
    if test "$_skip_iwd" = true
        _info "  Skipping iwd-backend config (iwd not installed)"
    else if _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.iwd.autoconnect=false" "iwd autoconnect disabled"
        _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
    end
    # NM-dispatcher enable state: checked in _ry_verify_runtime (batch systemctl show) — not a static config file check
    _echo

    _echo "── RADV driconf ──"
    if _chk_file /etc/drirc
        _chk_grep /etc/drirc radv_enable_unified_heap_on_apu unified_heap_on_apu
    end
    _echo

    _echo "── sysctl drop-in ──"
    if _chk_file /etc/sysctl.d/99-cachyos-sysctl.conf
        # compare key + value, not just key presence
        for entry in $SYSCTL_VALUES
            set -l parts (string split -m1 '=' -- "$entry")
            set -l key $parts[1]
            set -l val $parts[2]
            _chk_grep /etc/sysctl.d/99-cachyos-sysctl.conf "$key = $val" "$key=$val"
        end
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
    if set -q AUR_PKGS
        for pkg in $AUR_PKGS
            if contains -- "$pkg" $_installed_pkgs
                _ok "  $pkg: installed (AUR)"
            else
                _warn "  $pkg: NOT INSTALLED (AUR — install via paru)"
            end
        end
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
    # LVM-aware: exclude lvm2-monitor from mask checks when LVM volumes exist
    set -l _check_mask
    for _svc in $MASK
        if test "$_has_lvm" = true; and string match -q 'lvm2*' -- "$_svc"
            _info "  $_svc: skipped (LVM detected)"
            continue
        end
        set -a _check_mask "$_svc"
    end
    # Batch systemctl show replaces N individual calls. string collect preserves blank-line delimiters.
    set -l _mask_raw (systemctl show --property=LoadState,ActiveState,UnitFileState -- $_check_mask 2>/dev/null | string collect --no-trim-newlines)
    set -l _mask_parsed (_parse_systemctl_show "$_mask_raw")
    if test (count $_mask_parsed) -lt (count $_check_mask)
        _warn "  systemctl show returned incomplete mask data ("(count $_mask_parsed)" of "(count $_check_mask)" records)"
        _log "SYSTEMCTL_SHOW_MASK_PARTIAL: got="(count $_mask_parsed)" expected="(count $_check_mask)
        # Fallback: per-unit query to avoid positional misattribution
        for _svc in $_check_mask
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
        for _mask_idx in (seq 1 (count $_check_mask))
            set -l _svc $_check_mask[$_mask_idx]
            set -l _rec (string split ':' -- "$_mask_parsed[$_mask_idx]")
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
    set -l hooks_syntax_line (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^#' | head -n 1)
    if test -n "$hooks_syntax_line"
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_syntax_line") # lint:ignore (PCRE backref)
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

    # Pre-gen expected + batched parallel hash verify (4 workers); per-worker stderr captured; result="" → FAIL.
    set -l hash_dir (mktemp -d -t ry-hash-par.XXXXXX)
    if not test -d "$hash_dir"
        _fail "Failed to create hash verification temp directory"
        _log "=== STATIC VERIFICATION END ==="
        _verify_summary
        set -l ret $status
        set -g VERIFY_MODE false
        return $ret
    end
    set -ga _TRACKED_TMPFILES "$hash_dir"
    set -l my_home "$HOME"

    # Filter destinations: skip iwd/NM configs when iwd not installed (uses pre-computed _skip_iwd)
    set -l hash_dsts
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test "$_skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                set -l safe (_tmpfile_key "$dst")
                echo skip >"$hash_dir/result_$safe"
                continue
            end
        end
        set -a hash_dsts "$dst"
    end

    # Pre-generate expected content files. Fail-closed: capture generator rc AND stderr.
    for dst in $hash_dsts
        set -l safe (_tmpfile_key "$dst")
        # `2>&1 >file` order → cmdsubst captures stderr only (see _ry_validate_configs hash_dir loop).
        set -l _gen_err (_ry_get_file_content "$dst" 2>&1 >"$hash_dir/expected_$safe")
        set -l _gen_rc $status
        if test $_gen_rc -ne 0
            echo genfail >"$hash_dir/result_$safe"
            test -n "$_gen_err"; and _log "HASH_GENERATOR_STDERR: dst=$dst rc=$_gen_rc err=$_gen_err"
            command rm -f -- "$hash_dir/expected_$safe" 2>/dev/null
        end
    end

    # Pre-serialize installed hashes in parent (sudo timestamp_type=ppid doesn't propagate to children).
    set -l _sudo_ok_for_hash false
    if sudo -n true 2>/dev/null
        set _sudo_ok_for_hash true
        # Extend timestamp lifetime for the upcoming read loop
        sudo -n -v 2>/dev/null
    end
    for dst in $hash_dsts
        set -l safe (_tmpfile_key "$dst")
        if string match -q "$my_home/*" -- "$dst"
            if test -r "$dst"
                # Symmetric with sudo branch below — capture sha256sum, check both pipe stages, write only on full success.
                set -l _hash_line (sha256sum <"$dst" 2>/dev/null)
                set -l _ps $pipestatus
                if test $_ps[1] -eq 0
                    set -l _hash (string split ' ' -- "$_hash_line")[1]
                    if test -n "$_hash"
                        printf '%s\n' "$_hash" >"$hash_dir/installed_$safe" 2>/dev/null
                    else
                        printf 'read_error\n' >"$hash_dir/read_rc_$safe" 2>/dev/null
                    end
                else
                    printf 'read_error\n' >"$hash_dir/read_rc_$safe" 2>/dev/null
                end
            end
        else
            if test "$_sudo_ok_for_hash" = true; and sudo -n test -r "$dst" 2>/dev/null
                # Capture sha256sum into variable first, check full pipestatus, then string split.
                set -l _hash_line (sudo -n cat -- "$dst" 2>/dev/null | sha256sum)
                set -l _ps $pipestatus
                if test $_ps[1] -ne 0; or test $_ps[2] -ne 0
                    # Classify: if sudo cred lapsed mid-loop, record distinct reason
                    if not sudo -n true 2>/dev/null
                        printf 'sudo_lapsed\n' >"$hash_dir/read_rc_$safe" 2>/dev/null
                        set _sudo_ok_for_hash false
                    else
                        printf 'read_error\n' >"$hash_dir/read_rc_$safe" 2>/dev/null
                    end
                else
                    set -l _hash (string split ' ' -- "$_hash_line")[1]
                    if test -n "$_hash"
                        printf '%s\n' "$_hash" >"$hash_dir/installed_$safe" 2>/dev/null
                    else
                        printf 'read_error\n' >"$hash_dir/read_rc_$safe" 2>/dev/null
                    end
                end
            else
                # Either initial sudo probe failed or sudo -n test -r refused
                printf 'sudo_lapsed\n' >"$hash_dir/read_rc_$safe" 2>/dev/null
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
        command timeout --preserve-status --kill-after=5 60 fish -c '
            set -l hash_dir $argv[1]
            set -l start_idx $argv[2]
            set -l end_idx $argv[3]
            set -l all_dsts (command cat -- "$hash_dir/dst_list")
            for idx in (seq $start_idx $end_idx)
                set -l dst $all_dsts[$idx]
                test -n "$dst"; or continue
                set -l safe (string replace -a "/" "_" -- "$dst")
                # Respect pre-written genfail sentinel from parent pre-gen phase
                if test -s "$hash_dir/result_$safe"
                    set -l _pre (command cat -- "$hash_dir/result_$safe")
                    if test "$_pre" = genfail; or test "$_pre" = skip
                        continue
                    end
                end
                if not test -s "$hash_dir/expected_$safe"
                    echo skip > "$hash_dir/result_$safe"
                    continue
                end
                set -l expected_hash (sha256sum < "$hash_dir/expected_$safe" | string split -- " ")[1]
                # Distinguish cat-fail/unreadable from hash-diff. Missing installed_$safe=noread; present-diff=fail.
                if not test -e "$hash_dir/installed_$safe"
                    echo noread > "$hash_dir/result_$safe"
                    continue
                end
                set -l installed_hash (string trim -- (command cat -- "$hash_dir/installed_$safe" 2>/dev/null))
                if test -z "$installed_hash"
                    echo noread > "$hash_dir/result_$safe"
                else if test "$expected_hash" = "$installed_hash"
                    echo pass > "$hash_dir/result_$safe"
                else
                    echo fail > "$hash_dir/result_$safe"
                end
            end
        ' -- "$hash_dir" "$start_idx" "$end_idx" >/dev/null 2>"$hash_dir/worker_$worker.stderr" &
        set -a hash_pids $last_pid
    end

    wait $hash_pids

    for worker in (seq 1 $num_workers)
        if test -s "$hash_dir/worker_$worker.stderr"
            _log "HASH_WORKER_STDERR: (worker $worker) "(head -n 15 "$hash_dir/worker_$worker.stderr")
        end
    end

    # Collect results in deterministic order
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l safe (_tmpfile_key "$dst")
        set -l result (command cat -- "$hash_dir/result_$safe" 2>/dev/null)
        switch "$result"
            case pass
                _ok "  $dst: checksum match"
            case fail
                _fail "  $dst: checksum MISMATCH"
            case noread
                # Consult read_rc sidecar written by parent sudo probe
                set -l _safe_rr (_tmpfile_key "$dst")
                set -l _rr (command cat -- "$hash_dir/read_rc_$_safe_rr" 2>/dev/null | string trim --)
                switch "$_rr"
                    case sudo_lapsed
                        _fail "  $dst: sudo credential lapsed during hash pre-serialization"
                    case read_error
                        _fail "  $dst: filesystem read error during hash pre-serialization"
                    case '*'
                        _fail "  $dst: cannot read (file missing or permission change)"
                end
            case genfail
                _fail "  $dst: content generator failed (see HASH_GENERATOR_STDERR in log)"
            case skip
                # Intentional skip (no expected content, file unreadable, or NM/IWD not installed)
            case ''
                # Empty/missing result — child crashed or timed out; must FAIL.
                _fail "  $dst: verification incomplete (no result from hash job)"
            case '*'
                # Unexpected payload (e.g. partial write from SIGKILL'd worker); catch-all prevents silent miss.
                _fail "  $dst: verification incomplete (unexpected result: $result)"
                _log "VERIFY_STATIC_UNEXPECTED_RESULT: dst=$dst result=$result"
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

function _ry_do_check --description "Silent idempotency probe — exit 0 if clean, EXIT_DRIFT if drifted, EXIT_PREFLIGHT if prereqs fail"
    set -l drift false
    set -l checked 0

    # Pre-cache sudo for parallel children. Read-only mode has no keepalive; sudo -n depends on timestamp_timeout.
    set -l _sudo_ok false
    if command -q sudo; and sudo -n true 2>/dev/null
        set _sudo_ok true
    end
    if test "$_sudo_ok" = false
        _log "CHECK_PREFLIGHT: sudo not cached"
        return $EXIT_PREFLIGHT
    end

    # Pre-generate content files (prereq 1)
    set -l content_dir (_pregenerate_content_files)
    if not test -d "$content_dir"
        _log "CHECK_PREFLIGHT: content pregeneration failed"
        return $EXIT_PREFLIGHT
    end

    # Determine iwd skip list
    set -l skip_iwd false
    if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
        set skip_iwd true
    end

    set -l result_dir (mktemp -d -t ry-check-parallel.XXXXXX)
    if not test -d "$result_dir"
        _log "CHECK_PREFLIGHT: mktemp failed"
        return $EXIT_PREFLIGHT
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
    # Implicit services derived from SYSTEM_DESTINATIONS: drop-in present → managing service implicit (keep in sync).
    set -l _implicit_svcs
    for _dst in $SYSTEM_DESTINATIONS
        switch $_dst
            case '*/systemd/resolved.conf.d/*'
                contains -- systemd-resolved.service $_implicit_svcs; or set -a _implicit_svcs systemd-resolved.service
            case '*/NetworkManager/dispatcher.d/*' '*/NetworkManager/conf.d/*'
                contains -- NetworkManager-dispatcher.service $_implicit_svcs; or set -a _implicit_svcs NetworkManager-dispatcher.service
        end
    end
    printf '%s\n' $_implicit_svcs >"$result_dir/implicit_svcs"

    # Pre-serialize installed file hashes+permissions in parent (sudo timestamp_type=ppid doesn't propagate to children)
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        if test "$skip_iwd" = true
            if string match -q '*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"
                continue
            end
        end
        set -l safe (_tmpfile_key "$dst")
        if string match -q "$my_home/*" -- "$dst"
            if test -r "$dst"
                # sha256sum first; write hash_$safe on success; detector L3716 splits read-fail vs drift.
                set -l _raw_line (sha256sum <"$dst" 2>/dev/null)
                set -l _ps $pipestatus
                if test $_ps[1] -eq 0
                    set -l _first (string split ' ' -- "$_raw_line")[1]
                    if test -n "$_first"
                        printf '%s\n' "$_first" >"$result_dir/hash_$safe"
                    end
                end
                stat -c '%a %U:%G' -- "$dst" 2>/dev/null >"$result_dir/perm_$safe"
            end
        else
            if sudo -n test -r "$dst" 2>/dev/null
                set -l _raw_line (sudo -n cat -- "$dst" 2>/dev/null | sha256sum)
                set -l _ps $pipestatus
                if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
                    set -l _first (string split ' ' -- "$_raw_line")[1]
                    if test -n "$_first"
                        printf '%s\n' "$_first" >"$result_dir/hash_$safe"
                    end
                end
            end
            if sudo -n test -e "$dst" 2>/dev/null
                sudo -n stat -c '%a %U:%G' -- "$dst" 2>/dev/null >"$result_dir/perm_$safe"
            end
        end
    end

    # Pre-serialize LVM state (sudo pvs) in parent for Job 4
    set -l _has_lvm false
    _detect_lvm; and set _has_lvm true
    echo $_has_lvm >"$result_dir/has_lvm"

    # Job 1: file content hashes (parallel) — reads pre-serialized hashes from parent
    command timeout --preserve-status --kill-after=5 60 fish -c '
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
            # genfail from _pregenerate_content_files — treat as drift not skip (v3.51.3 fix for test -s mask).
            if test -e "$content_dir/$safe.genfail"
                set drift true
                continue
            end
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
    ' -- "$result_dir" "$content_dir" "$skip_iwd" "$my_home" >/dev/null 2>"$result_dir/hash.stderr" &
    set -l pid_hash $last_pid

    # Job 2: file permissions (parallel) — reads pre-serialized perms from parent
    command timeout --preserve-status --kill-after=5 60 fish -c '
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
    ' -- "$result_dir" "$boot_fstype" "$my_user" "$my_group" >/dev/null 2>"$result_dir/perm.stderr" &
    set -l pid_perm $last_pid

    printf '%s\n' $KERNEL_PARAMS >"$result_dir/kparams"

    # Job 3: kernel params (parallel) — no sudo needed
    command timeout --preserve-status --kill-after=5 60 fish -c '
        set -l result_dir $argv[1]
        set -l drift false
        set -l cmdline (command cat -- /proc/cmdline 2>/dev/null)
        set -l kparams (command cat -- "$result_dir/kparams")
        # empty/unreadable /proc/cmdline → drift
        if test -z "$cmdline"
            set drift true
        else
            for param in $kparams
                if not string match -q -- "* $param *" " $cmdline "
                    set drift true
                end
            end
        end
        echo $drift > "$result_dir/kparam_drift"
    ' -- "$result_dir" >/dev/null 2>"$result_dir/kparam.stderr" &
    set -l pid_kparam $last_pid

    # Job 4: service state — batch systemctl show (parallel); pre-parsed in parent (child can't call _parse_systemctl_show)
    set -l _all_check_units (command cat -- "$result_dir/exp_svcs") (command cat -- "$result_dir/mask_units") (command cat -- "$result_dir/implicit_svcs" 2>/dev/null)
    set -l _check_show (systemctl show --property=LoadState,ActiveState,UnitFileState -- $_all_check_units 2>/dev/null | string collect --no-trim-newlines)
    set -l _check_parsed (_parse_systemctl_show "$_check_show")
    printf '%s\n' $_check_parsed >"$result_dir/parsed_units"
    command timeout --preserve-status --kill-after=5 60 fish -c '
        set -l result_dir $argv[1]
        set -l drift false
        set -l exp_svcs (command cat -- "$result_dir/exp_svcs")
        set -l mask_units (command cat -- "$result_dir/mask_units")
        set -l implicit_svcs (command cat -- "$result_dir/implicit_svcs" 2>/dev/null)
        set -l results (command cat -- "$result_dir/parsed_units" 2>/dev/null)

        # Assertion: parsed[] indices coupled to exp_svcs/mask_units/implicit_svcs concatenation order.
        set -l _expected_total (math (count $exp_svcs) + (count $mask_units) + (count $implicit_svcs))
        if test (count $results) -ne $_expected_total
            echo "ASSERT_FAIL: parsed_units count="(count $results)" expected=$_expected_total" >&2
            printf "parsed_units count=%d expected=%d\n" (count $results) $_expected_total > "$result_dir/svc_assert_fail"
            echo true > "$result_dir/svc_drift"
            exit 1
        end

        # Check expected services: timers=ActiveState:active (waiting); oneshot RemainAfterExit=ActiveState:exited
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
    ' -- "$result_dir" >/dev/null 2>"$result_dir/svc.stderr" &
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

    # Merge results: missing/malformed result file → drift. checked==0 → EXIT_DRIFT.
    if test -s "$result_dir/svc_assert_fail"
        _err "Job 4 positional-coupling assertion failed: "(command cat -- "$result_dir/svc_assert_fail" 2>/dev/null)
        _err "  Update exp_svcs / mask_units / implicit_svcs together — parsed[N] indices drifted"
    end
    for phase in hash perm kparam svc
        set -l _drift_file "$result_dir/"$phase"_drift"
        if test -s "$result_dir/"$phase".stderr"
            _log "CHECK_STDERR: ($phase) "(head -n 15 "$result_dir/"$phase".stderr")
        end
        if not test -f "$_drift_file"
            _log "CHECK_DRIFT: child '$phase' did not write results (crashed or timed out after 60s)"
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

    if test $checked -eq 0
        _log "CHECK_DRIFT: no files could be checked (all skipped)"
        return $EXIT_DRIFT
    end

    return $EXIT_OK
end

function _gather_cpu_state --description "Collect CPU frequency path for representative core"
    # Assumes symmetric CPU topology. Strix Halo is symmetric; asymmetric (P/E-core) would be mis-represented.
    set -g _CPU_PATH ""
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq
        if test -d "$cpu_dir"
            set -g _CPU_PATH "$cpu_dir"
            break
        end
    end
    return 0
end

# RUNTIME VERIFICATION — live sysfs/procfs state checks; exit 1 when state doesn't match config.
function _ry_verify_runtime --description "Verify runtime kernel params, services, and modules"
    _log "=== RUNTIME VERIFICATION START ==="

    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
        # use EXIT_PREFLIGHT constant for consistency
        return $EXIT_PREFLIGHT
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

    set -l _dmesg (sudo dmesg 2>/dev/null)

    _echo "── Preemption model ──"
    set -l _preempt (printf '%s\n' $_dmesg | grep -o 'Dynamic Preempt: [a-z]*' | head -n 1)
    if test -n "$_preempt"
        if string match -q '*full*' -- "$_preempt"
            _ok "  $_preempt"
        else
            _warn "  $_preempt (linux-cachyos defaults to full; add preempt=full to cmdline if running a different kernel)"
        end
    else
        _info "  Preemption model: cannot determine from dmesg"
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
        _warn "  GPU not at 'auto' — check dmesg for amdgpu errors"
    end
    _echo

    _echo "── ReBAR/SAM status ──"
    set -l rebar_status (printf '%s\n' $_dmesg | grep -i 'BAR' | grep -i -E 'resize|rebar|large|above.4g' | head -n 1)
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
        if test "$_vram_mb" -le 512
            _ok "  VRAM carveout: $_vram_mb MB"
        else
            _warn "  VRAM carveout: $_vram_mb MB (recommended: ≤512 MB for UMA — check BIOS)"
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
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_CPU_PATH") # lint:ignore (PCRE backref)
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
    if test -f /sys/devices/system/cpu/amd_pstate/prefcore
        set -l _prefcore (command cat -- /sys/devices/system/cpu/amd_pstate/prefcore 2>/dev/null | string trim --)
        if test "$_prefcore" = enabled
            _ok "  amd_pstate prefcore: $_prefcore"
        else
            _fail "  amd_pstate prefcore: $_prefcore (expected: enabled)"
        end
    end
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

    # Regression: nvme_core.default_ps_max_latency_us was removed; value=0 = re-added, blocks APST, raises idle W.
    if test -f /sys/module/nvme_core/parameters/default_ps_max_latency_us
        set -l sysfs_val (command cat -- /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null)
        if test "$sysfs_val" = 0
            _fail "  nvme_core.default_ps_max_latency_us: 0 (regression — should be unset; re-check /etc/kernel/cmdline)"
        else
            _ok "  nvme_core.default_ps_max_latency_us: $sysfs_val (APST enabled)"
        end
    end

    if test -d /sys/module/amdgpu/parameters
        # Hex→decimal normalization: sysfs may return 0xfffd3fff or 4294787071
        for pair in "ppfeaturemask:0xfffd3fff" "cwsr_enable:0"
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

    _echo "── Additional module parameters ──"
    if test -f /sys/module/zswap/parameters/enabled
        set -l sysfs_val (command cat -- /sys/module/zswap/parameters/enabled 2>/dev/null | string trim --)
        if test "$sysfs_val" = N; or test "$sysfs_val" = 0
            _ok "  zswap.enabled: $sysfs_val"
        else
            _fail "  zswap.enabled: $sysfs_val (expected: N/0)"
        end
    end
    if test -f /proc/sys/kernel/nmi_watchdog
        set -l sysfs_val (command cat -- /proc/sys/kernel/nmi_watchdog 2>/dev/null | string trim --)
        if test "$sysfs_val" = 0
            _ok "  nmi_watchdog: $sysfs_val"
        else
            _fail "  nmi_watchdog: $sysfs_val (expected: 0 — nowatchdog)"
        end
    end
    _echo

    _echo "── Blacklisted modules ──"
    for mod in pcspkr
        if lsmod 2>/dev/null | grep -q -- "^$mod "
            _fail "  $mod: LOADED (should be blacklisted)"
        else
            _ok "  $mod: not loaded"
        end
    end
    _echo

    _echo "── Clocksource ──"
    if test -f /sys/devices/system/clocksource/clocksource0/current_clocksource
        set -l _cs (command cat -- /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null | string trim --)
        if test "$_cs" = tsc
            _ok "  clocksource: $_cs"
        else if test "$_cs" = hpet
            _fail "  clocksource: $_cs (expected: tsc — HPET has 10–100× higher read latency)"
            # Auto-correlate: grep cached dmesg for TSC instability markers
            set -l _tsc_demote (printf '%s\n' $_dmesg | grep -iE 'Marking TSC unstable|TSC: Marking|clocksource.*tsc.*unstable' | head -n 3)
            if test -n "$_tsc_demote"
                for _l in $_tsc_demote
                    _info "  dmesg: $_l"
                end
            else
                _info "  dmesg: no TSC demotion markers found — check BIOS/firmware"
            end
        else
            _warn "  clocksource: $_cs (expected: tsc)"
        end
    end
    _echo

    _echo "── Coredump config ──"
    if test -f /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf
        if grep -q -- 'Storage=none' /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf 2>/dev/null
            _ok "  coredump: Storage=none"
        else
            _fail "  coredump: Storage!=none in /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf"
        end
    else
        _warn "  coredump: /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf not found"
    end
    _echo

    _echo "SERVICE STATE"
    _echo

    # Batch systemctl show — 1 system call replaces individual calls
    set -l sys_units cpupower-epp.service \
        fstrim.timer systemd-resolved.service NetworkManager-dispatcher.service \
        NetworkManager.service
    # Static assertion: sys_units is positionally coupled to parsed[1..5] consumers below; fail loud on drift.
    if test (count $sys_units) -ne 5
        _fail "  sys_units count drift: actual="(count $sys_units)" expected=5 — update parsed[N] indices below"
        _log "=== RUNTIME VERIFICATION END ==="
        _verify_summary
        set -l ret $status
        set -g VERIFY_MODE false
        return $ret
    end
    set -l show_output (systemctl show --property=LoadState,ActiveState,UnitFileState -- $sys_units 2>/dev/null | string collect --no-trim-newlines)
    set -l parsed (_parse_systemctl_show "$show_output")

    # MAINTENANCE: parsed[] (Load:Active:UnitFileState) is positionally coupled to sys_units — update together.
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
            set -l _rec (string split ':' -- "$_unit_parsed[1]")
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

        # cpupower-epp.service
        set -l rec (string split ':' -- "$parsed[1]")
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
        set -l rec (string split ':' -- "$parsed[2]")
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
        set -l rec (string split ':' -- "$parsed[3]")
        if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
            if test "$rec[2]" = active
                _ok "  systemd-resolved: active"
            else
                _fail "  systemd-resolved: $rec[2] (expected: active — DNS may be broken)"
            end
        end

        # NetworkManager-dispatcher
        set -l rec (string split ':' -- "$parsed[4]")
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
        set -l rec (string split ':' -- "$parsed[5]")
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
        set -l rec (string split ':' -- "$user_parsed[1]")
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

    set -l _user_env (systemctl --user show-environment 2>/dev/null)
    for exp in $ENV_VARS
        set -l _ev_parts (string split -m1 '=' -- "$exp")
        set -l var_name $_ev_parts[1]
        set -l expected $_ev_parts[2]
        set -l actual ""
        if test -n "$_user_env"
            set -l _vn_re (string escape --style=regex -- $var_name)
            set actual (printf '%s\n' $_user_env | string match -rg -- "^"$_vn_re"=(.*)" | tail -n 1)
        end
        if test -z "$actual"
            set actual (printenv "$var_name")
        end

        if test "$actual" = "$expected"
            _ok "  $var_name=$actual"
        else if test -n "$actual"
            _fail "  $var_name=$actual (expected: $expected)"
        else
            # Env file verified by _ry_verify_static; here we observe shell-visible state. WARN, not FAIL — re-login fixes.
            _warn "  $var_name: NOT SET in current session (re-login or systemctl --user import-environment)"
        end
    end
    _echo

    if set -q SYSCTL_VALUES; and test (count $SYSCTL_VALUES) -gt 0
        _echo "── sysctl (ry-install) ──"
        for entry in $SYSCTL_VALUES
            set -l _parts (string split -m1 '=' -- "$entry")
            set -l _key $_parts[1]
            set -l _expected $_parts[2]
            set -l _proc_path (string replace -a '.' '/' -- "$_key")
            # Normalize whitespace: /proc/sys uses tabs for multi-value keys; SYSCTL_VALUES uses spaces
            set -l _actual (command cat -- "/proc/sys/$_proc_path" 2>/dev/null | string trim -- | string replace -ra '\s+' ' ')
            set -l _expected_norm (string replace -ra '\s+' ' ' -- "$_expected")
            if test "$_actual" = "$_expected_norm"
                _ok "  $_key: $_actual"
            else if test -n "$_actual"
                _fail "  $_key: $_actual (expected: $_expected)"
            else
                _warn "  $_key: not available"
            end
        end
        _echo
    end

    _echo "── TCP congestion control ──"
    if command -q modinfo
        set -l _bbr_ver (modinfo tcp_bbr 2>/dev/null | grep -i '^version:' | string replace -r -- '^version:\s*' '')
        if test -n "$_bbr_ver"
            _ok "  tcp_bbr module version: $_bbr_ver"
        else
            _info "  tcp_bbr: version field not available"
        end
    end
    set -l _cc_active (command cat -- /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null | string trim --)
    if test "$_cc_active" = bbr
        _ok "  tcp_congestion_control: $_cc_active"
    else if test -n "$_cc_active"
        _warn "  tcp_congestion_control: $_cc_active (expected: bbr)"
    end
    _echo

    _echo "── THP / KSM / ZRAM ──"
    if test -f /sys/kernel/mm/transparent_hugepage/enabled
        set -l _thp (command cat -- /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)
        if string match -qr '\[always\]' -- "$_thp"
            _ok "  THP enabled: always"
        else
            set -l _active (string match -r '\[(\S+)\]' -- "$_thp")[2]
            _warn "  THP enabled: $_active (recommended: always — CachyOS default)"
        end
    end
    if test -f /sys/kernel/mm/transparent_hugepage/defrag
        set -l _defrag (command cat -- /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null)
        if string match -qr '\[defer\+madvise\]' -- "$_defrag"
            _ok "  THP defrag: defer+madvise"
        else
            set -l _active (string match -r '\[(\S+)\]' -- "$_defrag")[2]
            _warn "  THP defrag: $_active (recommended: defer+madvise)"
        end
    end
    if test -f /sys/kernel/mm/transparent_hugepage/shrink_underused
        set -l _shrink (command cat -- /sys/kernel/mm/transparent_hugepage/shrink_underused 2>/dev/null | string trim --)
        if test "$_shrink" = 0
            _ok "  THP shrink_underused: 0"
        else
            _warn "  THP shrink_underused: $_shrink (recommended: 0)"
        end
    end
    if test -f /sys/kernel/mm/ksm/run
        set -l _ksm (command cat -- /sys/kernel/mm/ksm/run 2>/dev/null | string trim --)
        if test "$_ksm" = 0
            _ok "  KSM run: 0 (disabled)"
        else
            _warn "  KSM run: $_ksm (recommended: 0 — breaks THP, wastes CPU with 128 GB)"
        end
    end
    set -l _zram_state (systemctl is-enabled systemd-zram-setup@zram0.service 2>/dev/null | string trim --)
    if test "$_zram_state" = enabled
        _ok "  ZRAM service: enabled"
    else if test "$_zram_state" = masked
        _fail "  ZRAM service: masked (expected: enabled)"
    else if test -n "$_zram_state"
        _warn "  ZRAM service: $_zram_state (expected: enabled)"
    else
        _warn "  ZRAM service: not found"
    end

    _echo "── ZRAM device ──"
    set -l _zram_swap (swapon --show=NAME,TYPE 2>/dev/null | grep zram)
    if test -n "$_zram_swap"
        set -l _zram_info (zramctl --output NAME,ALGORITHM,DISKSIZE,TOTAL,COMP-RATIO --noheadings 2>/dev/null | head -n 1 | string trim --)
        _ok "  ZRAM swap active: $_zram_info"
    else
        set -l _any_swap (swapon --show=NAME,SIZE 2>/dev/null | tail -n +2)
        if test -z "$_any_swap"
            _fail "  No swap available (ZRAM not active, no swap file/partition)"
        else
            _warn "  ZRAM not active but other swap found: $_any_swap"
        end
    end

    _echo "── fstab mount options ──"
    set -l _fstab_ext4 (awk '!/^[[:space:]]*#/ && NF >= 4 && $3 == "ext4" { print $0 }' /etc/fstab 2>/dev/null) # lint:ignore (awk boolean operators)
    if test -n "$_fstab_ext4"
        set -l _fstab_ok true
        for _fl in $_fstab_ext4
            set -l _opts (printf '%s\n' "$_fl" | awk '{ print $4 }')
            # Independent if blocks (not else-if): report every missing option per line in one pass
            if not string match -q '*noatime*' -- "$_opts"
                _fail "  ext4 entry missing noatime: $_fl"
                set _fstab_ok false
            end
            if not string match -q '*lazytime*' -- "$_opts"
                _fail "  ext4 entry missing lazytime: $_fl"
                set _fstab_ok false
            end
            if not string match -qr '(^|,)commit=10(,|$)' -- "$_opts"
                _fail "  ext4 entry missing commit=10: $_fl"
                set _fstab_ok false
            end
        end
        if test "$_fstab_ok" = true
            _ok "  ext4 entries: noatime,lazytime,commit=10 present"
        end
    else
        _info "  No ext4 entries in /etc/fstab"
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

    # Gate WiFi state checks on profile actually managing iwd configs
    set -l _profile_uses_iwd false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_d"; or string match -q '*/iwd/*' -- "$_d"
            set _profile_uses_iwd true
            break
        end
    end

    if test "$_profile_uses_iwd" = false
        _info "  Profile does not manage iwd/NM — skipping WiFi state checks"
    else
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
    end

    _echo "FILE PERMISSIONS"
    _echo

    _echo "── Sensitive files ──"
    set -l nm_conn_dir /etc/NetworkManager/system-connections
    if test -d "$nm_conn_dir"
        set -l conn_files (sudo find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f -print0 2>/dev/null | string split0)
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
            if string match -q '/boot/*' -- "$dst"; and test "$_boot_fstype" = vfat
                continue
            end
            set perm_checked (math $perm_checked + 1)
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
            # parent-dir mode parse — strip leading on len>3, floor(n/2)%2 verified for 755/775/757/1755/4755
            if test "$owner" != "root:root"
                _fail "  $dir: $perms $owner (expected: root:root)"
                set dir_bad (math $dir_bad + 1)
            else
                if _dir_group_or_world_writable "$perms"
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

    _echo "PACKAGE MANAGEMENT"
    _echo

    _echo "── Vulkan driver packages ──"
    if not set -q EXPECTED_VULKAN_PKGS; or test (count $EXPECTED_VULKAN_PKGS) -eq 0
        _info "  EXPECTED_VULKAN_PKGS not defined in profile — skipping"
    else
        set -l _vk_missing 0
        for _vk_pkg in $EXPECTED_VULKAN_PKGS
            if pacman -Q "$_vk_pkg" >/dev/null 2>&1
                _ok "  $_vk_pkg: installed"
            else
                _fail "  $_vk_pkg: NOT installed (DXVK/VKD3D-Proton requires this)"
                set _vk_missing (math $_vk_missing + 1)
            end
        end
        if test $_vk_missing -gt 0
            _info "  Install missing packages: sudo pacman -S $EXPECTED_VULKAN_PKGS"
        end
    end
    _echo

    _echo "BOOT PERFORMANCE"
    _echo

    if command -q systemd-analyze
        set -l boot_time (systemd-analyze 2>/dev/null | head -n 1)
        _info "  $boot_time"

        # Extract total seconds from already-captured line. Format: "Startup finished in ... = 12.345s"
        _log "BOOT_TIME_CHECK: parsing systemd-analyze output"
        set -l total_sec (printf '%s\n' "$boot_time" | string match -r -- '= ([0-9.]+)s' | tail -n 1)
        if test -n "$total_sec"; and string match -qr '^[0-9.]+$' -- "$total_sec"
            # BOOT_TIME_TARGET optional (see _validate_profile); guard so omitting doesn't trip `test: arg expected`.
            if set -q BOOT_TIME_TARGET; and test -n "$BOOT_TIME_TARGET"
                set -l target $BOOT_TIME_TARGET
                set -l time_int (LC_ALL=C printf "%.0f" "$total_sec" 2>/dev/null)
                if test -n "$time_int"; and test "$time_int" -lt $target
                    _ok "  Boot time under $target""s target"
                else if test -n "$time_int"
                    _info "  Boot time exceeds $target""s target (ignored)"
                    _info "  Run 'systemd-analyze blame' to identify slow services"
                end
            else
                _info "  BOOT_TIME_TARGET not set in profile — skipping target comparison"
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

# Install pipeline

# INSTALL PIPELINE — preflight → packages → files → services → boot → finalize

# Octal mode group/world-writable check. Returns 0 (true) when group OR world write bit is set.
function _dir_group_or_world_writable --argument-names mode --description "True when octal mode has group or world write bit"
    if test (count $argv) -ne 1
        return 1
    end
    # Strip leading char on 4-digit modes (sticky/setuid/setgid) — only the last 3 digits carry rwx
    if test (string length -- "$mode") -gt 3
        set mode (string sub -s 2 -- "$mode")
    end
    set -l group_w (string sub -s 2 -l 1 -- "$mode")
    set -l other_w (string sub -s 3 -l 1 -- "$mode")
    set -l group_has_w (math "floor($group_w / 2) % 2" 2>/dev/null)
    set -l other_has_w (math "floor($other_w / 2) % 2" 2>/dev/null)
    test "$group_has_w" -eq 1 2>/dev/null; and return 0
    test "$other_has_w" -eq 1 2>/dev/null; and return 0
    return 1
end

function _is_wifi_active_route --description "True if the default route exits via a wireless interface"
    # Check both v4 and v6 default routes so IPv6-only hosts aren't misreported as wired.
    set -l _def_iface (ip -4 route show default 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}') # lint:ignore (awk field reference, not fish cmdsubst)
    if test -z "$_def_iface"
        set _def_iface (ip -6 route show default 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}') # lint:ignore (awk field reference, not fish cmdsubst)
    end
    test -z "$_def_iface"; and return 1
    test -d "/sys/class/net/$_def_iface/wireless"
end

# Pipeline phase 1: deps, disk, network, kernel version, config validation
function _install_preflight --description "Run all preflight checks before installation"
    _progress Preflight

    _info "Sudo password required for installation..."
    printf '\n' >&2
    if not command -q sudo
        _err "Sudo required for installation"
        return $EXIT_PREFLIGHT
    end
    # redirect to keep sudo lecture text out of the script's banner stream
    sudo true >/dev/null 2>&1; or begin
        _err "Sudo required for installation"
        return $EXIT_PREFLIGHT
    end
    # Reject restrictive sudoers tags (NOEXEC, !PASSWD, !SETENV, LOG_OUTPUT) before whitelisting.
    set -l _sudo_lines (sudo -n -l 2>/dev/null | grep -v '^\s*#')
    set -l sudo_all 0
    for _sl in $_sudo_lines
        # `!`-prefixed tags: right-boundary only — PCRE \b needs word↔non-word (space+! are both non-word).
        if string match -qr -- '(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)' "$_sl"
            continue
        end
        # Accept ALL at end of Cmnd_List OR followed by additional whitelisted commands (ALL,...)
        if string match -qr -- '\(ALL(\s*:\s*ALL)?\)\s+(NOPASSWD:\s+)?ALL(\s*,|\s*$)' "$_sl"
            set sudo_all (math $sudo_all + 1)
        end
    end
    if test "$sudo_all" -eq 0
        _err "Unattended install requires full sudo"
        _kill_sudo_keepalive
        return $EXIT_PREFLIGHT
    end
    set -l my_pid $fish_pid
    # Keepalive: sudo -n -v refreshes timestamp; 2 retries with 1s backoff absorb transient PAM/NSS failures.
    fish -c '
        while kill -0 -- $argv[1] 2>/dev/null; and test -d -- $argv[2]
            set -l _ok false
            for _try in 1 2 3
                if sudo -n -v 2>/dev/null
                    set _ok true
                    break
                end
                sleep 1
            end
            test "$_ok" = true; or break
            sleep $argv[3]
        end
    ' -- $my_pid "$LOCK_DIR" $SUDO_KEEPALIVE_INTERVAL </dev/null &
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

# Pipeline phase 2: pacman -Syu + install PKGS_ADD with --needed (PKGS_DEL removal is phase 4)
function _install_packages --description "Install managed packages via pacman -Syu"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Packages
    _echo
    _info "Synchronizing package databases..."

    _echo
    # Install missing packages, then remove unwanted ones
    _info "Package installation..."

    set -l pkgs_to_install $PKGS_ADD

    set -g SYSTEM_UPGRADED false
    if not _ry_install_file "/etc/mkinitcpio.conf" true
        _err "Failed to pre-deploy mkinitcpio.conf before package install"
        _err "Aborting package installation — mkinitcpio.conf must be in place before -Syu"
        set -g INSTALL_HAD_ERRORS true
        return 1
    end

    if test (count $pkgs_to_install) -gt 0
        if test -f /var/lib/pacman/db.lck
            _err "Pacman database is locked (/var/lib/pacman/db.lck exists) — skipping package install"
            set -g INSTALL_HAD_ERRORS true
            set _fn_err true
        else if not _run sudo pacman -Syu --needed --noconfirm -- $pkgs_to_install
            _warn "Package installation failed, retrying with fresh sync (first-pass stderr in JSONL log)..."
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

        _info "Verifying package installation..."
        # pacman -T prints unsatisfied targets. Non-empty output means packages need installing.
        set -l missing_pkgs (pacman -T -- $pkgs_to_install 2>/dev/null)
        if test (count $missing_pkgs) -gt 0
            _err "Missing packages: $missing_pkgs"
            _warn "  Install manually: sudo pacman -S --needed $missing_pkgs"
            set -g INSTALL_HAD_ERRORS true
            set _fn_err true
        else
            _ok "All packages verified installed"
        end
    end

    # Scan for .pacnew/.pacsave at managed destinations — pacman creates these silently on config-modified upgrades.
    set -l _pacnew_found
    for _dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        for _suffix in .pacnew .pacsave
            if sudo -n test -f "$_dst$_suffix" 2>/dev/null
                set -a _pacnew_found "$_dst$_suffix"
            end
        end
    end
    if test (count $_pacnew_found) -gt 0
        _warn "Pacman config remnants found at managed destinations:"
        for _f in $_pacnew_found
            _warn "  $_f"
        end
        _warn "  Review with: sudo pacdiff   (then re-run install to redeploy managed configs)"
        _log "PACNEW_FOUND: $_pacnew_found"
    end
    test "$_fn_err" = true; and return 1
    return 0
end

# Pipeline phase 2b: install AUR packages via paru (not pacman); hard-fail if paru missing and AUR_PKGS non-empty
function _install_aur_packages --description "Install AUR packages via paru"
    if not set -q AUR_PKGS; or test (count $AUR_PKGS) -eq 0
        return 0
    end
    if not command -q paru
        _err "paru not found — cannot install AUR packages: $AUR_PKGS"
        _err "  Install paru: sudo pacman -S --needed paru"
        _err "  AUR_PKGS may include critical drivers (e.g. WiFi DKMS)"
        set -g INSTALL_HAD_ERRORS true
        return 1
    end
    # Batch install: paru resolves shared makedeps once; per-package fallback on batch failure to find culprit.
    if not _run paru -S --needed --noconfirm -- $AUR_PKGS
        _warn "AUR batch install failed — retrying per-package to identify failures"
        for pkg in $AUR_PKGS
            if not _run paru -S --needed --noconfirm -- "$pkg"
                _warn "AUR install failed: $pkg"
                set -g INSTALL_HAD_ERRORS true
            end
        end
    end
    return 0
end

# Post-package: invalidate iwd cache (state changed via -Syu) and refresh package DBs. Must run unconditionally.
function _install_post_package_refresh --description "Invalidate caches and refresh package DBs after pacman/paru phase"
    # Invalidate _RY_SKIP_IWD cache: pacman -Syu may have installed/removed iwd since preflight primed it.
    set --erase _RY_SKIP_IWD
    set --erase _RY_SKIP_IWD_CACHED

    if command -q updatedb
        if not _run sudo updatedb
            _warn "Updatedb failed"
        end
    end
    if command -q pkgfile
        if not _run sudo pkgfile --update
            _warn "Pkgfile update failed"
        end
    end
    return 0
end

# Pipeline phase 3: deploy SYSTEM/USER files. SERVICE_DESTINATIONS deployed in _install_configure_services.
function _install_system_files --description "Deploy all embedded config files to the system"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Configuration
    _echo
    _info "Installing system configuration files..."
    if not _ry_install_files --sudo --desc "SYSTEM FILES" $SYSTEM_DESTINATIONS
        _err "System file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    _echo
    _info "Installing user configuration files..."
    if not _ry_install_files --desc "USER FILES" $USER_DESTINATIONS
        _err "User file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    test "$_fn_err" = true; and return 1
    return 0
end

# Ensure ext4 fstab entries have noatime,lazytime,commit=10 via atomic copy→awk→verify→mv
function _install_fstab_opts --description "Add noatime,lazytime,commit=10 to ext4 fstab entries"
    _check_sudo_keepalive
    if not test -f /etc/fstab
        _warn "  /etc/fstab not found — skipping"
        return 0
    end

    # Check any ext4 entry missing noatime/lazytime — field-based: $3 == "ext4".  # lint:ignore (awk ref)
    set -l needs_change false
    set -l ext4_lines (awk '!/^[[:space:]]*#/ && NF >= 4 && $3 == "ext4" { print $0 }' /etc/fstab 2>/dev/null) # lint:ignore (awk boolean operators)
    if test -z "$ext4_lines"
        _info "  No ext4 entries in /etc/fstab"
        return 0
    end
    for line in $ext4_lines
        set -l opts_field (printf '%s\n' "$line" | awk '{ print $4 }')
        if not string match -q '*noatime*' -- "$opts_field"; or not string match -q '*lazytime*' -- "$opts_field"; or not string match -qr '(^|,)commit=10(,|$)' -- "$opts_field"
            set needs_change true
            break
        end
    end

    if test "$needs_change" = false
        _ok "  /etc/fstab: ext4 entries already have noatime,lazytime,commit=10"
        return 0
    end

    # Atomic modify: copy → sed → verify → mv
    set -l tmpfstab (sudo mktemp -p /etc .ry-install.fstab.XXXXXX 2>/dev/null)
    if test -z "$tmpfstab"
        _fail "  /etc/fstab: mktemp failed"
        return 1
    end
    # Track immediately so SIGKILL between mktemp and explicit rm doesn't leak tmpfiles in /etc.
    set -ga _TRACKED_TMPFILES "$tmpfstab"
    if not sudo cp --preserve=mode,ownership -- /etc/fstab "$tmpfstab"
        sudo rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: backup copy failed"
        return 1
    end

    # Field-based edit: $3=='ext4' prevents corrupting mounts whose path contains 'ext4' literally.
    set -l tmpfstab2 (sudo mktemp -p /etc .ry-install.fstab.XXXXXX 2>/dev/null)
    if test -z "$tmpfstab2"
        sudo rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: mktemp (awk target) failed"
        return 1
    end
    # Track awk target tmpfile (symmetric with tmpfstab above).
    set -ga _TRACKED_TMPFILES "$tmpfstab2"
    sudo awk '
        BEGIN { OFS = " " }
        /^[[:space:]]*#/ || NF < 4 { print; next }
        $3 != "ext4" { print; next }  # lint:ignore (awk field reference)
        {
            n = split($4, opts, ",")  # lint:ignore (awk field reference)
            has_noat = 0; has_lazy = 0; out = ""
            for (i = 1; i <= n; i++) {
                o = opts[i]
                if (o == "relatime" || o == "atime" || o == "strictatime") continue  # lint:ignore (awk, not fish — embedded awk script)
                if (o ~ /^commit=/) continue
                if (o == "noatime") has_noat = 1
                if (o == "lazytime") has_lazy = 1
                out = (out == "" ? o : out "," o)
            }
            if (!has_noat)  out = (out == "" ? "noatime"  : out ",noatime")
            if (!has_lazy)  out = (out == "" ? "lazytime" : out ",lazytime")
            out = (out == "" ? "commit=10" : out ",commit=10")
            $4 = out  # lint:ignore (awk field reference)
            print
        }
    ' "$tmpfstab" | sudo tee -- "$tmpfstab2" >/dev/null
    set -l _ps $pipestatus
    if test $_ps[1] -ne 0; or test $_ps[2] -ne 0
        sudo rm -f -- "$tmpfstab" "$tmpfstab2" 2>/dev/null
        _fail "  /etc/fstab: awk/tee rewrite failed"
        return 1
    end
    sudo rm -f -- "$tmpfstab" 2>/dev/null
    set tmpfstab "$tmpfstab2"

    # Preserve /etc/fstab mode+own — tmpfstab2 sudo-mktemp 0600 root:root; mv else regresses 0644→0600.
    if not sudo chmod --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null
        sudo rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: chmod --reference failed (cannot preserve source mode)"
        return 1
    end
    if not sudo chown --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null
        sudo rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: chown --reference failed (cannot preserve source ownership)"
        return 1
    end

    if command -q findmnt
        # findmnt --verify exits non-zero on real errors; rely on rc, not free-form output grep
        set -l _verify_out (sudo findmnt --verify --tab-file "$tmpfstab" 2>&1)
        set -l _verify_rc $status
        if test $_verify_rc -ne 0
            set -l _verify_snip (printf '%s\n' $_verify_out | head -n 3 | string join '; ')
            _fail "  /etc/fstab: findmnt --verify failed (rc=$_verify_rc): $_verify_snip"
            _warn "  Keeping original /etc/fstab unchanged"
            sudo rm -f -- "$tmpfstab" 2>/dev/null
            return 1
        end
    end

    if not sudo mv -- "$tmpfstab" /etc/fstab
        sudo rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: atomic move failed"
        return 1
    end

    _ok "  /etc/fstab: noatime,lazytime,commit=10 applied to ext4 entries"
    _log "FSTAB_OPTS: noatime,lazytime,commit=10 applied"
    return 0
end

# Pipeline phase 4: daemon-reload, enable/start, mask units; sets _fn_err + INSTALL_HAD_ERRORS on failure
function _install_configure_services --description "Enable, start, and configure systemd services"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Services
    _echo
    _info "Post-installation tasks..."

    if not _run sudo udevadm control --reload-rules
        _warn "Udevadm reload-rules failed"
    end
    if not _run sudo udevadm trigger
        _warn "Udevadm trigger failed"
    end
    if not _run sudo udevadm settle --timeout=5
        _warn "Udevadm settle timed out"
    end

    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        if not _run sudo systemctl restart systemd-resolved
            _warn "Systemd-resolved restart failed"
        end
    end

    set -l to_del
    # Batch: single pacman -Qq replaces N individual pacman -Qi calls
    set -l _del_installed (pacman -Qq 2>/dev/null)
    for pkg in $PKGS_DEL
        if contains -- "$pkg" $_del_installed
            # Check reverse dependencies before removing $pkg; skip if other packages depend on it
            if command -q pactree
                # pactree -ru -u lists pkg+rdeps flat; filter PKGS_DEL siblings so intra-batch deps don't shortcut.
                set -l _rdeps_raw (pactree -ru "$pkg" 2>/dev/null | string match -v -- "$pkg" | string match -rv '^$')
                set -l _rdeps
                for _r in $_rdeps_raw
                    contains -- "$_r" $PKGS_DEL; and continue
                    set -a _rdeps "$_r"
                end
                if test (count $_rdeps) -gt 0
                    _warn "  $pkg has reverse dependencies: $_rdeps — skipping"
                    continue
                end
            end
            set -a to_del "$pkg"
        end
    end

    if test (count $to_del) -gt 0
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

    set -l safe_mask
    set -l has_lvm false

    if _detect_lvm
        set has_lvm true
        _warn "LVM DETECTED - lvm2 services will NOT be masked"
    end

    if test "$has_lvm" = false
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

    if test (count $safe_mask) -gt 0
        if not _run sudo systemctl mask -- $safe_mask
            _warn "Failed to mask some services"
        end
    end

    # Batch system-scope enable --now
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

    # fstrim.timer (ext4 NVMe needs periodic TRIM — no discard=async mount opt for ext4)
    set -a sys_enable fstrim.timer
    # nftables.service (stateful host firewall — baseline after ufw removal)
    set -a sys_enable nftables.service

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
            # Require an active user bus before set-environment; skip silently on TTY/no-session installs
            if set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"
                _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
            else
                _info "  SSH_AUTH_SOCK propagation skipped (no active user D-Bus session)"
            end
        end
    else
        _warn "Ssh-agent.service user unit not found"
        _info "  Expected at ~/.config/systemd/user/ssh-agent.service"
    end
    test "$_fn_err" = true; and return 1
    return 0
end

# Post-rebuild gate: vmlinuz/initramfs non-zero, ≥1 entry references existing kernel; blocks reboot
function _preflight_boot_sanity --description "Verify boot artifacts are viable after rebuild"
    set -l errors 0
    # ESP path: resolve via bootctl, fall back to /boot. Handles hosts using /efi or /boot/efi.
    set -l _esp (sudo bootctl -p 2>/dev/null | string trim --)
    if test -z "$_esp"; or not sudo test -d "$_esp" 2>/dev/null
        set _esp /boot
    end

    # 1. At least one vmlinuz must exist
    set -l vmlinuz_files (sudo find "$_esp" -maxdepth 1 -name 'vmlinuz-*' -type f 2>/dev/null)
    if test (count $vmlinuz_files) -eq 0
        _err "No vmlinuz found in $_esp/"
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
    set -l initrd_files (sudo find "$_esp" -maxdepth 1 -name 'initramfs-*.img' -type f 2>/dev/null)
    for f in $initrd_files
        sudo test -s "$f" 2>/dev/null
        if test $status -ne 0
            _err "Zero-byte initramfs: $f"
            set errors (math $errors + 1)
        end
    end

    # 3. At least one boot entry .conf must reference an existing kernel
    set -l confs (sudo find "$_esp/loader/entries" -maxdepth 1 -name '*.conf' -type f 2>/dev/null)
    if test (count $confs) -eq 0
        _err "No boot loader entries in $_esp/loader/entries/"
        set errors (math $errors + 1)
    else
        set -l valid_entry false
        for conf in $confs
            # Strip leading 'linux' keyword and optional slash from initrd path to extract the basename.
            set -l linux_line (sudo grep -m1 '^linux ' -- "$conf" 2>/dev/null | string replace -r '^linux\s+' '' | string trim --)
            set -l linux_rel (string trim --left --chars=/ -- "$linux_line")
            # Reject exact `..` path segments (not substring — `foo..bar` is a legal filename in some BLS setups).
            if contains -- ".." (string split '/' -- "$linux_rel")
                _warn "  Loader entry has non-BLS path (contains ..): $conf"
                continue
            end
            if test -n "$linux_rel"; and sudo test -f "$_esp/$linux_rel" 2>/dev/null
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
        _info "  Inspect: ls -la $_esp/vmlinuz-* $_esp/initramfs-*.img"
        _info "  Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen" # lint:ignore (user-facing shell advice)
        return 1
    end

    _ok "Boot sanity: vmlinuz present, initramfs non-zero, entries valid"
    return 0
end

# Pipeline phase 5: mkinitcpio -P, sdboot-manage gen, bootctl install; abort on failure
function _install_rebuild_boot --description "Regenerate initramfs and bootloader entries"
    _check_sudo_keepalive

    # Order: syu → mkinitcpio → sdboot → boot_sanity (syu first for new kernel; explicit pass ensures configs apply).
    _progress Boot
    if test "$SYSTEM_UPGRADED" = true
        _ok "System already upgraded during package installation"
    else if not set -q RY_INSTALL_CONFIRM_SYSTEM_UPGRADE; or test "$RY_INSTALL_CONFIRM_SYSTEM_UPGRADE" != 1
        # Project rule: review arch/cachy news before -Syu. Skip unattended unless one-time ack given.
        _warn "Skipping unattended system upgrade (RY_INSTALL_CONFIRM_SYSTEM_UPGRADE not set)"
        _info "  Review news before -Syu:"
        _info "    https://archlinux.org/news/"
        _info "    https://cachyos.org/news/"
        _info "  Run manually: sudo pacman -Syu"
        _info "  Or re-run ry-install with RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1"
        if command -q curl
            for url in https://archlinux.org/feeds/news/ https://cachyos.org/feeds/news/
                set -l _headlines (curl -sf --connect-timeout 2 --max-time 5 -- "$url" 2>/dev/null \
                    | string match -ra '<title>([^<]+)</title>' \
                    | head -n 4 | tail -n 3)
                for _h in $_headlines
                    _info "  [$url] $_h"
                end
            end
        end
        _log "SYSTEM_UPGRADE_SKIPPED: RY_INSTALL_CONFIRM_SYSTEM_UPGRADE not set"
    else
        _info "System upgrade proceeding unattended — review archlinux.org/news and wiki.cachyos.org post-install"
        if not _run sudo pacman -Syu --noconfirm
            _warn "System upgrade failed or was interrupted"
            set -g INSTALL_HAD_ERRORS true
        else
            _ok "System upgrade complete"
        end
    end

    # mkinitcpio/sdboot failure aborts to prevent unbootable system
    if not _run sudo mkinitcpio -P
        _err "Mkinitcpio failed"
        set -g INSTALL_HAD_ERRORS true
        _err "CRITICAL: Boot rebuild failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end

    # SDBOOT_REMOVE_EXISTING=yes: first-run safety gate requires RY_INSTALL_CONFIRM_BOOT_WIPE=1.
    if test "$SDBOOT_REMOVE_EXISTING" = yes
        # see global; do not re-hardcode the path
        set -l _wipe_marker $BOOT_WIPE_MARKER
        set -l _acknowledged false
        set -l _existing_basenames (sudo find /boot/loader/entries -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
        set -l _existing_entries (count $_existing_basenames)
        # Capture sha256sum first — unreachable path (printf can't fail; binary unreadable); kept for consistency.
        set -l _raw_line (printf '%s\n' $_existing_basenames | sha256sum)
        set -l _ps $pipestatus
        set -l _existing_hash ""
        if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
            set _existing_hash (string split ' ' -- "$_raw_line")[1]
        end
        if set -q RY_INSTALL_CONFIRM_BOOT_WIPE; and test "$RY_INSTALL_CONFIRM_BOOT_WIPE" = 1
            set _acknowledged true
            _log "BOOT_WIPE_ACK: env var RY_INSTALL_CONFIRM_BOOT_WIPE=1 entries=$_existing_entries hash=$_existing_hash"
        else if test -f "$_wipe_marker"
            # Marker: v3.51.3+ stores "<count> <sha256>"; legacy (count-only/empty) accepted once then rewritten.
            set -l _marker_raw (string trim -- (command cat -- "$_wipe_marker" 2>/dev/null))
            set -l _marker_parts (string split ' ' -- "$_marker_raw")
            set -l _marked_count "$_marker_parts[1]"
            set -l _marked_hash ""
            if test (count $_marker_parts) -ge 2
                set _marked_hash "$_marker_parts[2]"
            end
            if test -z "$_marker_raw"; or not string match -qr '^\d+$' -- "$_marked_count"
                # Legacy marker (empty or non-numeric) — accept once, will be rewritten with count+hash below
                set _acknowledged true
                _log "BOOT_WIPE_ACK: legacy marker file $_wipe_marker (entries=$_existing_entries hash=$_existing_hash)"
            else if test -z "$_marked_hash"
                # v3.51.2 format (count only) — accept once, will be rewritten with count+hash
                set _acknowledged true
                _log "BOOT_WIPE_ACK: v3.51.2 count-only marker $_wipe_marker (marked_count=$_marked_count current=$_existing_entries hash=$_existing_hash)"
            else if test "$_existing_hash" = "$_marked_hash"
                # Exact basename-set match — entries unchanged since last ack
                set _acknowledged true
                _log "BOOT_WIPE_ACK: marker hash match $_wipe_marker (count=$_existing_entries)"
            else
                _err "Boot loader entries changed since last acknowledged wipe: marked_count=$_marked_count current=$_existing_entries"
                _err "  Entry set delta detected (added, removed, or renamed) — manual entries (rescue, Windows, custom kernels) may be affected."
                _err "  To proceed: RY_INSTALL_CONFIRM_BOOT_WIPE=1 ./ry-install.fish"
                set -g INSTALL_HAD_ERRORS true
                return $EXIT_BOOT_CRIT
            end
        end

        if test "$_acknowledged" = false
            _err "SDBOOT_REMOVE_EXISTING=yes will delete $_existing_entries existing /boot/loader/entries/*.conf file(s)"
            _err "  Manual entries (rescue, Windows, custom kernels) will be LOST."
            _err "  To proceed (one-time): RY_INSTALL_CONFIRM_BOOT_WIPE=1 ./ry-install.fish"
            _err "  After the first successful run, marker file $_wipe_marker will record the entry count and suppress this gate until entries grow."
            set -g INSTALL_HAD_ERRORS true
            return $EXIT_BOOT_CRIT
        end

        _warn "SDBOOT_REMOVE_EXISTING=yes — all existing /boot/loader/entries/*.conf will be deleted and regenerated."
        _warn "Manual entries (rescue, Windows, custom kernels) will be LOST."
    end
    if not _run sudo sdboot-manage gen
        _warn "Sdboot-manage gen failed"
        set -g INSTALL_HAD_ERRORS true
        _err "CRITICAL: Bootloader update failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end
    if not _run sudo sdboot-manage update
        _err "Sdboot-manage update failed (bootctl EFI binary refresh)"
        set -g INSTALL_HAD_ERRORS true
        _err "CRITICAL: Bootloader binary update failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end

    # Boot-wipe marker written in _install_finalize success only (Fix 9) — partial-failure can't update count.

    set -l entry_count (sudo find /boot/loader/entries -maxdepth 1 -type f -name "*.conf" 2>/dev/null | wc -l)
    set -l entry_count (string trim -- "$entry_count")
    if test -n "$entry_count"; and string match -qr '^\d+$' -- "$entry_count"; and test "$entry_count" -gt 0
        _ok "Boot entries: $entry_count found in /boot/loader/entries/"
    else
        _err "No boot entries found in /boot/loader/entries/"
        _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
        _info "  Try: sudo sdboot-manage gen --verbose"
        set -g INSTALL_HAD_ERRORS true
    end

    # sudo find required: /boot may be ESP (vfat) 0700 root:root — user-context glob yields 0 iter, hides warnings.
    set -l _initrd_list (sudo find /boot -maxdepth 1 -type f -name 'initramfs-*.img' 2>/dev/null)
    for initrd in $_initrd_list
        # stat -c %s gives exact bytes; du -m has whole-MB granularity varying by filesystem.
        set -l size_b (sudo stat -c '%s' -- "$initrd" 2>/dev/null)
        if test -n "$size_b"; and string match -qr '^\d+$' -- "$size_b"
            set -l size_mb (math "floor($size_b / 1048576)")
            # >100MB initramfs suggests unnecessary MODULES or hooks (typical: 30-60MB)
            if test "$size_mb" -gt 100
                _warn "Large initramfs: $initrd ($size_mb MB) - consider reviewing MODULES/HOOKS"
            else
                _ok "Initramfs size: $initrd ($size_mb MB)"
            end
        end
    end

    if not _preflight_boot_sanity
        set -g INSTALL_HAD_ERRORS true
        _err "CRITICAL: Boot sanity failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end

    return 0
end

# Pipeline phase 6: daemon-reload, verify-static, verify-runtime, log summary, report errors
function _install_finalize --description "Run post-install verification, cleanup, and summary"
    _progress Finalize

    # Persist boot-wipe acknowledgement on success only. Atomic tmp+mv prevents zero-byte marker from mid-write crash.
    if test "$SDBOOT_REMOVE_EXISTING" = yes
        set -l _wipe_marker $BOOT_WIPE_MARKER
        set -l _post_basenames (sudo find /boot/loader/entries -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
        set -l _post_count (count $_post_basenames)
        # Capture sha256sum into var so pipestatus can be checked before parsing; symmetric with _install_boot.
        set -l _raw_line (printf '%s\n' $_post_basenames | sha256sum)
        set -l _ps $pipestatus
        set -l _post_hash ""
        if test $_ps[1] -eq 0; and test $_ps[2] -eq 0
            set _post_hash (string split ' ' -- "$_raw_line")[1]
        end
        if test -n "$_post_count"; and string match -qr '^\d+$' -- "$_post_count"
            set -l _marker_dir (dirname -- "$_wipe_marker")
            set -l _marker_tmp (mktemp -p "$_marker_dir" .boot-wipe.XXXXXX 2>/dev/null)
            if test -n "$_marker_tmp"
                set -ga _TRACKED_TMPFILES "$_marker_tmp"
                if printf '%s %s\n' "$_post_count" "$_post_hash" >"$_marker_tmp" 2>/dev/null
                    command chmod -- 600 "$_marker_tmp" 2>/dev/null
                    if command mv -f -- "$_marker_tmp" "$_wipe_marker" 2>/dev/null
                        _log "BOOT_WIPE_MARKER_UPDATED: $_wipe_marker count=$_post_count hash=$_post_hash"
                    else
                        command rm -f -- "$_marker_tmp" 2>/dev/null
                        _warn "Failed to atomically install boot-wipe marker"
                    end
                else
                    command rm -f -- "$_marker_tmp" 2>/dev/null
                    _warn "Failed to write boot-wipe marker tmpfile"
                end
            else
                _warn "Failed to mktemp boot-wipe marker tmpfile"
            end
        end
    end

    if not _run sudo systemctl daemon-reload
        _warn "Systemctl daemon-reload failed"
    end
    if not _run systemctl --user daemon-reload
        _warn "Systemctl --user daemon-reload failed"
    end

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

    # Profile-aware: only attempt NM/iwd restart when profile actually manages those configs
    set -l _profile_uses_iwd false
    for _dst in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_dst"; or string match -q '*/iwd/*' -- "$_dst"
            set _profile_uses_iwd true
            break
        end
    end

    if test "$_profile_uses_iwd" = false
        _info "Profile does not manage iwd/NetworkManager — skipping NM restart"
    else if command -q pacman; and pacman -Qi iwd >/dev/null 2>&1
        if _is_wifi_active_route
            _warn "NetworkManager restart deferred — WiFi is the active route."
            _warn "  Backend switch to iwd will not take effect until next reboot or manual restart."
            _warn "  After reconnecting via ethernet (or post-reboot): sudo systemctl restart NetworkManager"
            _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=finalize_backend_switch"
        else
            _info "iwd will restart with NetworkManager (D-Bus disconnect expected)"
            if not _run sudo systemctl restart NetworkManager
                _warn "NetworkManager restart failed (will recover on reboot)"
                _log "NM_RESTART_FAILED: context=finalize_backend_switch"
            end
            # iwd needs time to re-register on D-Bus after NM restart
            _run sleep $NM_RESTART_DELAY
        end
    else
        _warn "Profile manages iwd configs but iwd package is not installed"
        set -g INSTALL_HAD_ERRORS true
    end

    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end

# Orchestrator: runs all pipeline phases, collecting errors without aborting
function _ry_do_install --description "Full installation: preflight, packages, configs, services, boot"
    _log "=== INSTALLATION START ==="
    _log "VERSION: $VERSION"
    _log "MODE: unattended"

    # Pre-declare _boot_rc at function scope — Fish's set -l inside a block scopes to that block, not the function.
    set -l _boot_rc 0

    _echo
    _echo "ry-install v$VERSION"
    _echo

    # Check for orphaned files from previous install or profile switch
    _manifest_check_orphans

    _progress_init

    _install_preflight
    or return $EXIT_PREFLIGHT

    _echo

    if not _install_packages
        set -g INSTALL_HAD_ERRORS true
    end

    _install_aur_packages; or set -g INSTALL_HAD_ERRORS true

    # Unconditional post-package boundary work — must run regardless of AUR_PKGS state
    _install_post_package_refresh

    if not _install_system_files
        set -g INSTALL_HAD_ERRORS true
    end

    # fstab failure non-blocking: no downstream phase depends on noatime/lazytime/commit=10.
    _install_fstab_opts; or set -g INSTALL_HAD_ERRORS true

    if not _install_configure_services
        set -g INSTALL_HAD_ERRORS true
    end

    _install_rebuild_boot
    set _boot_rc $status
    if test $_boot_rc -ne 0
        set -g INSTALL_HAD_ERRORS true
    end

    # EXIT_BOOT_CRIT short-circuits finalize/manifest_write — system may not boot; continuing would mask the failure
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
        _err "Boot-critical failure — skipping finalization"
        _err "Fix boot issue first: sudo mkinitcpio -P && sudo sdboot-manage gen" # lint:ignore (user-facing shell advice)
        _progress Finalize skip
    else
        if not _install_finalize
            set -g INSTALL_HAD_ERRORS true
        end
    end

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
    _info "  1. Run 'rehash' or start new shell (updates command paths)"
    _info "  2. REBOOT to apply kernel cmdline and module changes"
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
    _manifest_write; or _log "MANIFEST_WRITE_FAILED: install succeeded, manifest deferred (cosmetic — orphan detection next run)"
    test "$INSTALL_HAD_ERRORS" = true; and return $EXIT_FAIL
    return $EXIT_OK
end

# Single-file install: deploy one managed config by destination path
function _ry_do_install_file --argument-names target --description "Install a single named config file"
    if test (count $argv) -gt 1
        _err "_ry_do_install_file: expected 0-1 args (target), got "(count $argv)
        return $EXIT_USAGE
    end
    # target bound by --argument-names; empty string when 0 args (handled by test -z below)
    _log "=== INSTALL-FILE START ==="

    if test -z "$target"
        _err "Usage: ry-install.fish --install-file <path>"
        _echo
        _info "Managed files:"
        for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
            _echo "  $dst"
        end
        return $EXIT_USAGE
    end

    set -l valid false
    set -l use_sudo true
    # Canonicalize destinations for comparison — handles symlinked /home (rpm-ostree, systemd-homed).
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l _canon_dst (realpath -m -- "$dst" 2>/dev/null; or echo "$dst")
        if test "$target" = "$dst"; or test "$target" = "$_canon_dst"
            set valid true
            # Resolve destination and validate it exists in managed file list
            break
        end
    end
    if test "$valid" = false
        for dst in $USER_DESTINATIONS
            set -l _canon_dst (realpath -m -- "$dst" 2>/dev/null; or echo "$dst")
            if test "$target" = "$dst"; or test "$target" = "$_canon_dst"
                set valid true
                set use_sudo false
                break
            end
        end
    end

    if test "$valid" = false
        _err "Not a managed file: $target"
        _info "Run without path to see managed files"
        return $EXIT_USAGE
    end

    _banner "ry-install v$VERSION - Install Single File"

    if test "$use_sudo" = true
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

        if string match -q '/boot/*' -- "$target"; or string match -q '/etc/mkinitcpio*' -- "$target"; or string match -q '/etc/sdboot*' -- "$target"; or string match -q /etc/kernel/cmdline -- "$target"
            _echo
            # Strict and-chained cascade with _preflight_boot_sanity gate. Returns EXIT_BOOT_CRIT on failure.
            set -l _cascade_rc 0
            if not _run sudo mkinitcpio -P
                _err "Mkinitcpio failed"
                set _cascade_rc 1
            else if not _run sudo sdboot-manage gen
                _err "Sdboot-manage gen failed"
                set _cascade_rc 1
            else if not _run sudo sdboot-manage update
                _err "Sdboot-manage update failed"
                set _cascade_rc 1
            end
            if test $_cascade_rc -ne 0
                _err "CRITICAL: boot rebuild cascade failed — DO NOT REBOOT"
                _info "  Fix: sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update" # lint:ignore (user-facing shell advice)
                _log "=== INSTALL-FILE END ==="
                return $EXIT_BOOT_CRIT
            end
            if not _preflight_boot_sanity
                _err "CRITICAL: boot sanity check failed after single-file install — DO NOT REBOOT"
                _log "=== INSTALL-FILE END ==="
                return $EXIT_BOOT_CRIT
            end
        else if string match -q '*.service' -- "$target"
            if string match -q "$HOME/*" -- "$target"
                _run systemctl --user daemon-reload; or _warn "Systemctl --user daemon-reload failed"
                if _run systemctl --user enable --now -- (basename -- "$target")
                    if string match -q '*ssh-agent*' -- "$target"; and set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"
                        _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                        or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
                    end
                else
                    _warn "Failed to enable "(basename -- "$target")" (user)"
                end
            else
                _run sudo systemctl daemon-reload; or _warn "Systemctl daemon-reload failed"
                if not _run sudo systemctl enable --now -- (basename -- "$target")
                    _warn "Failed to enable "(basename -- "$target")" (system)"
                end
            end
        else if string match -q '*/udev/rules.d/*' -- "$target"
            _echo
            _run sudo udevadm control --reload-rules; or _warn "Udevadm reload-rules failed"
            _run sudo udevadm trigger; or _warn "Udevadm trigger failed"
            _run sudo udevadm settle --timeout=5; or _warn "Udevadm settle timed out"
        else if string match -q '*/resolved.conf.d/*' -- "$target"
            _echo
            _run sudo systemctl restart systemd-resolved; or _warn "Systemd-resolved restart failed"

        else if string match -q '*/logind.conf.d/*' -- "$target"
            _info "Logind config changed — reboot required (restarting logind kills all sessions)"

        else if string match -q '*/iwd/main.conf' -- "$target"; or string match -q '*/NetworkManager/conf.d/*' -- "$target"
            _echo
            if _is_wifi_active_route
                _warn "NM/iwd config installed but NetworkManager restart deferred — WiFi is the active route."
                _warn "  Config change will not take effect until next reboot or manual restart."
                _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=install_file target=$target"
            else
                _run sudo systemctl restart NetworkManager; or _warn "NetworkManager restart failed"
            end
        else if string match -q '*/sysctl.d/*' -- "$target"
            _echo
            if not _run sudo sysctl --system
                _warn "sysctl --system failed — tunables not applied until reboot"
                _info "  Retry: sudo sysctl --system"
            end
        else if string match -q '*/coredump.conf.d/*' -- "$target"
            _echo
            # systemd-coredump is socket-activated — daemon-reload + restart socket propagates new drop-in
            _run sudo systemctl daemon-reload; or _warn "daemon-reload failed"
            if systemctl is-enabled systemd-coredump.socket >/dev/null 2>&1
                _run sudo systemctl restart systemd-coredump.socket; or _warn "systemd-coredump.socket restart failed"
            else
                _info "  systemd-coredump.socket not active — new config takes effect on next crash"
            end
        else if string match -q '*/environment.d/*' -- "$target"
            _info "environment.d changed — log out and back in (or restart user session) to apply"
            _info "  Active systemd --user services retain old environment until restarted"
        else if string match -q /etc/drirc -- "$target"
            _info "drirc changed — restart Wayland/X session or relaunch affected applications to apply"
        end
    else
        _err "Failed to install: $target"
        _log "=== INSTALL-FILE END ==="
        return 1
    end

    _log "=== INSTALL-FILE END ==="
    return 0
end

# CLI ARGUMENT PARSING AND DISPATCH

# Shared usage-exit helper: prints message, removes pre-dispatch log, exits EXIT_USAGE.
function _early_usage_exit --description "Print usage error to stderr, remove pre-dispatch log, exit EXIT_USAGE"
    echo "[ERR] $argv" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
end

# Entry point
set -g MODE install
set -l mode_count 0

set -l INSTALL_FILE_TARGET ""

# CLI parser — argparse with --exclusive for mode flags; deprecated flags declared solely to emit specific messages.
argparse --name=ry-install.fish \
    --exclusive=verify-static,verify-runtime,check,install-file \
    'h/help' 'v/version' 'V/verbose' \
    'verify-static' 'verify-runtime' 'check' 'install-file=' \
    'a/all' 'n/dry-run' 'diff' 'fix' \
    -- $argv 2>/dev/null
set -l _argparse_rc $status
if test $_argparse_rc -ne 0
    # argparse already rejected (unknown option, exclusive-group violation, or missing =VALUE). Emit help + exit EXIT_USAGE.
    echo "[ERR] Invalid arguments: $argv" >&2
    echo >&2
    _ry_show_help >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
end

# Deprecated-flag messages — order mirrors prior manual while-loop declaration order; first match wins.
set -q _flag_all;      and _early_usage_exit "--all is no longer required; unattended is the only mode"
set -q _flag_dry_run;  and _early_usage_exit "--dry-run has been removed; unattended is the only mode"
set -q _flag_diff;     and _early_usage_exit "--diff has been removed; use --verify-static for read-only drift checks"
set -q _flag_fix;      and _early_usage_exit "--fix has been removed; ry-install no longer performs in-tool drift repair"
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT

# --help / --version: short-circuit modes (exit 0).
if set -q _flag_help
    _ry_show_help
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit 0; and return 0; or return 0
end
if set -q _flag_version
    echo "v$VERSION"
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit 0; and return 0; or return 0
end

# -V/--verbose
set -q _flag_verbose; and set -g QUIET false

# Mode flags — argparse's --exclusive enforces at most one; mode_count retained as defense-in-depth.
if set -q _flag_verify_static
    set MODE verify-static
    set mode_count (math $mode_count + 1)
end
if set -q _flag_verify_runtime
    set MODE verify-runtime
    set mode_count (math $mode_count + 1)
end
if set -q _flag_check
    set MODE check
    set mode_count (math $mode_count + 1)
end
if set -q _flag_install_file
    set MODE install-file
    set mode_count (math $mode_count + 1)
    set -l _if_val "$_flag_install_file"
    if not string match -q -- '/*' "$_if_val"
        if string match -q -- '-*' "$_if_val"
            _early_usage_exit "--install-file requires an absolute path argument (got flag: $_if_val)"
        else
            _early_usage_exit "--install-file requires absolute path (got: $_if_val)"
        end
    end
    # Canonicalize: collapse //, .., symlinks to prevent bypassing managed-file validation.
    set -l _canon (realpath -m -- "$_if_val" 2>/dev/null)
    if test -n "$_canon"
        set INSTALL_FILE_TARGET "$_canon"
    else
        set INSTALL_FILE_TARGET "$_if_val"
    end
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT

# Reject positional args (argparse leaves them in $argv post-parse).
if test (count $argv) -gt 0
    echo "[ERR] Unexpected positional argument: $argv[1]" >&2
    echo >&2
    _ry_show_help >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
end

# Mode exclusivity: exactly one mode flag allowed per invocation
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
    _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
end

# dispatch-time root warning removed (duplicated init-block NOTICE, see root-UID check above)

if test "$MODE" != install; and test "$MODE" != check
    set -g QUIET false
end

# Load machine profile — must be after arg parsing but before any mode that reads config globals
_load_profile
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT

set -l mode_label $MODE
# NOTE: path format mirrored at LOG_FILE init site ($LOG_DIR/install-$TIMESTAMP.jsonl). Keep both in sync.
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"
set -l old_log "$LOG_FILE"
# Rename log to mode-specific path; mv-before-set keeps content on signal even if footer is lost
set -l _log_rename_ok true
if test -f "$old_log"; and test "$old_log" != "$new_log"
    if not command mv -- "$old_log" "$new_log" 2>/dev/null
        set _log_rename_ok false
        echo "[WARN] Log rename failed: $old_log -> $new_log (keeping old path)" >&2
    end
end
if test "$_log_rename_ok" = true
    set -g LOG_FILE "$new_log"
end
# umask-wrapped touch+chmod fallback (race-free); preserve pre-existing content from _load_profile
if not test -f "$LOG_FILE"
    set -l _prev_umask (umask)
    umask 0177
    command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
    or begin
        command touch -- "$LOG_FILE" 2>/dev/null
        command chmod -- 600 "$LOG_FILE" 2>/dev/null; or _warn "Chmod 600 failed on $LOG_FILE"
    end
    umask $_prev_umask
else
    command chmod -- 600 "$LOG_FILE" 2>/dev/null; or true
end

set -l _init_cmd (_json_str (string join -- " " (status filename) $argv))
printf '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","verbose":%s,"command":"%s"}\n' \
    (date '+%Y-%m-%dT%H:%M:%S%z') "$VERSION" "$PROFILE_NAME" "$MODE" \
    (test "$QUIET" = false; and echo true; or echo false) "$_init_cmd" >>"$LOG_FILE"

# install / install-file acquire lock; read modes skip
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
            _ry_exit $EXIT_USAGE; and return $EXIT_USAGE; or return $EXIT_USAGE
        end
        _acquire_lock; or begin
            _ry_exit $EXIT_LOCK; and return $EXIT_LOCK; or return $EXIT_LOCK
        end
    case install
        _acquire_lock; or begin
            _ry_exit $EXIT_LOCK; and return $EXIT_LOCK; or return $EXIT_LOCK
        end
    case '*'
        # No lock needed for read-only modes (verify, check)
end

set -l _log_base_rot "$HOME/ry-install/logs"
# Null-delim pipeline (paths with newlines); sort -z -t \t uses fish escape (literal TAB at cmd line).
set -l _rot_raw (command find "$_log_base_rot" \( -name '*.jsonl' -o -name '*.log' \) -type f ! -path "$LOG_FILE" -printf '%T@\t%p\0' 2>/dev/null | LC_ALL=C sort -z -t \t -k1,1n | string split0)
set -l _existing_logs
for _rot_entry in $_rot_raw
    # Each entry is "MTIME\tPATH" — strip up to first tab
    set -a _existing_logs (string replace -r -- '^[^\t]+\t' '' "$_rot_entry")
end
set -l _log_count (count $_existing_logs)
if test $_log_count -gt $MAX_LOGS
    set -l _to_remove (math $_log_count - $MAX_LOGS)
    if command -q flock
        string join0 -- $_existing_logs[1..$_to_remove] | flock -n "$_log_base_rot" xargs -0 rm -f -- 2>/dev/null
    else
        # Best-effort fallback: flock is a hard dep on Arch/CachyOS. Concurrent `rm -f` is idempotent.
        string join0 -- $_existing_logs[1..$_to_remove] | xargs -0 rm -f -- 2>/dev/null
    end
    command find "$_log_base_rot" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
end

set -g exit_code 0
switch $MODE
    case verify-static
        _ry_verify_static
        set exit_code $status
    case verify-runtime
        _ry_verify_runtime
        set exit_code $status
    case check
        _ry_do_check
        set exit_code $status
    case install-file
        _ry_do_install_file "$INSTALL_FILE_TARGET"
        set exit_code $status
    case install
        _ry_do_install
        # _ry_do_install already returns EXIT_FAIL when INSTALL_HAD_ERRORS=true; no need to re-check at dispatch level.
        set exit_code $status
    case '*'
        _err "Unknown mode: $MODE"
        set exit_code $EXIT_USAGE
end
# Bail checkpoint: if any handler tripped the source-safe bail sentinel, return from the source frame
if test "$_RY_INSTALL_BAILING" = true
    set -g _RY_INSTALL_LAST_EXIT $exit_code
    return $exit_code
end
# fish_exit handler receives $status of last command in setup, not script exit — capture intended code here
set -g _INTENDED_EXIT_CODE $exit_code

_write_footer "$exit_code" ""

if test "$MODE" != check
    echo "[i] Log file: $LOG_FILE" >&2
end

if test "$_RY_INSTALL_SOURCED" = true
    # Sourced: do NOT exit (kills host fish). Erase handlers, clean namespace, return exit code.
    set -g _RY_INSTALL_LAST_EXIT $exit_code
    functions -e _cleanup _cleanup_pipe _cleanup_on_exit 2>/dev/null
    _ry_namespace_cleanup
    return $exit_code
end

exit $exit_code
