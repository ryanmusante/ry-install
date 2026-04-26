#!/usr/bin/env fish
# ry-install v4.4.6 (2026-04-26) — CachyOS config manager | Ryan Musante | MIT
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
# Source detection via status stack-trace works in both interactive and non-interactive contexts (fish 3.4+).
if status stack-trace 2>/dev/null | string match -q '*from sourcing*'
    set -g _RY_INSTALL_SOURCED true
else
    set -g _RY_INSTALL_SOURCED false
end
set -g VERSION "4.4.6"
set -g EXIT_OK 0
set -g EXIT_FAIL 1
set -g EXIT_USAGE 2
set -g EXIT_PREFLIGHT 3
set -g EXIT_BOOT_CRIT 4
set -g EXIT_LOCK 5
set -g EXIT_DRIFT 10

function _ry_exit --argument-names code --description "Source-safe exit: set bail sentinel and return when sourced, exit otherwise"
    test -z "$code"; and set code 0
    set -g _RY_INSTALL_LAST_EXIT $code
    # _do_cleanup added (guarded by functions -q to skip pre-bootstrap calls).
    set -g _RY_INSTALL_BAILING true
    set -l _was_sourced "$_RY_INSTALL_SOURCED"
    # Erase signal/exit handlers FIRST so host-fish Ctrl+C/SIGPIPE/exit does not fire into dead script context.
    functions -e _cleanup _cleanup_pipe _cleanup_on_exit 2>/dev/null
    # Then explicit cleanup — idempotent; functions -q guards calls before _do_cleanup is defined (line ~430).
    functions -q _do_cleanup; and _do_cleanup
    _ry_namespace_cleanup bail
    if test "$_was_sourced" = true
        return $code
    end
    exit $code
end

function _ry_namespace_cleanup --argument-names mode --description "Erase script-set globals; preserve caller-API"
    # HOME preserved: the HOME-resolution block below populates it from getent passwd when $HOME is empty
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
# NO_COLOR (per no-color.org): honored when set AND non-empty; empty does not trigger. TERM=dumb forces no-color.
if begin
        set -q NO_COLOR; and test -n "$NO_COLOR"
    end
    or test "$TERM" = dumb
    set -g NO_COLOR true
else
    set -g NO_COLOR false
end
# root check moved past --help/--version short-circuits — informational flags work for any user.

# Fish version gate — 3.4+ required (set --function, string collect --allow-empty)
set -l fish_ver (string match -r -- '\d+\.\d+' (fish --version 2>&1) | head -n1)
set -l parts (string split '.' -- "$fish_ver")
if not string match -qr '^\d+$' -- "$parts[1]"
    or not string match -qr '^\d+$' -- "$parts[2]"
    echo "[ERR] fish version unparseable: '$fish_ver'" >&2
    _ry_exit $EXIT_PREFLIGHT
end
if test "$parts[1]" -lt 3
    or begin
        test "$parts[1]" -eq 3; and test "$parts[2]" -lt 4
    end
    echo "[ERR] fish 3.4+ required (found: $fish_ver)" >&2
    _ry_exit $EXIT_PREFLIGHT
end

# TMPDIR writability gate — _run / mktemp / sudo-err sites assume a writable working tmp dir
set -l _ry_tmpprobe_dir (set -q TMPDIR; and test -n "$TMPDIR"; and printf '%s' "$TMPDIR"; or printf '%s' /tmp)
if not test -w "$_ry_tmpprobe_dir"
    echo "[ERR] tmp dir not writable: $_ry_tmpprobe_dir" >&2
    _ry_exit $EXIT_PREFLIGHT
end

# GNU sort -z probe — boot-wipe basename hash + log rotation depend on NUL-delimited sort
if not printf '' | command sort -z </dev/null 2>/dev/null
    echo "[ERR] GNU sort with -z required (busybox/BSD sort detected)" >&2
    _ry_exit $EXIT_PREFLIGHT
end

# Timestamps: DATE_LABEL (ISO date) for dirs, TIMESTAMP (compact+PID) for filenames; two date calls avoid %Y dup.
set -g DATE_LABEL (date '+%Y-%m-%d')
set -g TIMESTAMP (date '+%Y%m%d-%H%M%S%z')"-"$fish_pid

# HOME resolution: env → getent passwd → tilde (handles privilege-escalated shells, cron, containers)
set -g _MY_UID (id -u)
if test -z "$HOME"
    set -g HOME (getent passwd $_MY_UID 2>/dev/null | cut -d: -f6)
    if test -z "$HOME"
        set -g HOME ~
    end
    if test -z "$HOME"; or not test -d "$HOME"
        echo "Error: Cannot determine HOME directory" >&2
        _ry_exit $EXIT_PREFLIGHT
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
    _ry_exit $EXIT_PREFLIGHT
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
    _ry_exit $EXIT_PREFLIGHT
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
    _ry_exit $EXIT_PREFLIGHT
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
set -g KVER_PARTS (string split '.' -- "$KVER")
set -g KVER_MAJOR $KVER_PARTS[1]
# Preflight-fail on unparseable uname -r
if not string match -qr '^\d+$' -- "$KVER_MAJOR"
    echo "[ERR] Cannot parse kernel major version from uname -r: $KVER" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit $EXIT_PREFLIGHT
end
# Strip non-numeric suffix (e.g., 14-cachyos becomes 14) for numeric comparison
set -g KVER_MINOR (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[2]")
if test -z "$KVER_MINOR"; or not string match -qr '^\d+$' -- "$KVER_MINOR"
    echo "[ERR] Cannot parse kernel minor version from uname -r: $KVER" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    _ry_exit $EXIT_PREFLIGHT
end

function _kconfig_cache --description "Return cached /proc/config.gz lines (lazy-loaded; empty on missing config)"
    # sentinel-based gate — count == 0 re-tested /proc/config.gz on every call when missing
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

# LVM probe (_mask_list_effective + _install_configure_services); sudo -n pvs then lsblk fallback for sudo-cache lapses.
function _detect_lvm --description "Return 0 (LVM present) or 1 (no LVM detected)"
    if command -q sudo; and sudo -n true 2>/dev/null
        set -l _pvs_output (command timeout 10 sudo -n pvs --noheadings 2>/dev/null | string trim --)
        test -n "$_pvs_output"; and return 0
    end
    # Non-sudo fallback: lsblk reports LVM block-device types without root, catching LVM-rooted systems on stale
    if command -q lsblk
        lsblk -no TYPE 2>/dev/null | string match -q lvm; and return 0
    end
    return 1
end

# Cross-check KERNEL_PARAMS against /proc/config.gz to detect unsupported kernel features
function _validate_kernel_params --description "Warn if KERNEL_PARAMS reference features not compiled into running kernel"
    # Only useful if /proc/config.gz exists (requires CONFIG_IKCONFIG_PROC=y)
    if not test -f /proc/config.gz
        _info "  /proc/config.gz unavailable — skipping kernel config validation"
        return 0
    end

    # Map cmdline param prefix → CONFIG_ symbol. Unchecked (kernel reports support via dmesg/sysfs, not
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

function _verify_unit_syntax --argument-names unit_path label --description "Verify systemd unit syntax via systemd-analyze"
    _log "VERIFY_UNIT: $label ($unit_path)"
    command -q systemd-analyze; or begin
        _warn "  systemd-analyze not available — skipping $label"
        return 0
    end
    set -l user_flag
    string match -q '*/.config/systemd/user/*' -- "$unit_path"; and set user_flag --user
    set -l _err_out (systemd-analyze $user_flag verify "$unit_path" 2>&1)
    if test $status -eq 0
        test -n "$_err_out"; and _log "VERIFY_UNIT_WARN: ($label) "(printf '%s\n' $_err_out | head -n 5)
        _ok "  $label: syntax OK"
        return 0
    end
    _log "VERIFY_UNIT_ERR: ($label) "(printf '%s\n' $_err_out | head -n 5)
    _fail "  $label: INVALID SYNTAX"
    return 1
end

function _write_footer --argument-names exit_code extra_key --description "Append JSONL footer to LOG_FILE; idempotent via _FOOTER_WRITTEN"
    set -q _FOOTER_WRITTEN; and return 0
    set -q LOG_FILE; or return 0
    begin
        test -n "$LOG_FILE"; and test -f "$LOG_FILE"
    end; or return 0
    set -g _FOOTER_WRITTEN true
    set -l _mode_esc (_json_str "$MODE")
    set -l _ts (date '+%Y-%m-%dT%H:%M:%S%z')
    set -l _extra ""
    if test -n "$extra_key"
        set _extra ",\"$extra_key\":true"
    end
    set -l _gen_fail 0
    set -q VERIFY_GEN_FAIL; and set _gen_fail $VERIFY_GEN_FAIL
    printf '{"ts":"%s","event":"footer","mode":"%s","exit_code":%s,"pass":%s,"fail":%s,"warn":%s,"gen_fail":%s%s}\n' \
        "$_ts" "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" "$_gen_fail" "$_extra" >>"$LOG_FILE" 2>/dev/null
end

# Sweep /tmp for ry-{run-stderr,run-stdout,validate,diff,argparse,test-stderr}.* owned by current UID
function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    if not set -q _FOOTER_WRITTEN
        _log "CLEANUP_TMPFILES: sweep starting"
    end
    # Clean orphaned .ry-install.* tmpfiles from atomic writes (crash/interrupt leftovers)
    set -l sys_dirs $_SYS_TMP_DIRS
    if test "$_PROFILE_USES_NM" = true; and not contains -- /etc/NetworkManager/system-connections $sys_dirs
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
    for dir in $_USR_TMP_DIRS
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
        # Atomic pid write: mktemp inside the just-created LOCK_DIR + rename, eliminates 0-byte pid race
        set -l _pid_tmp (mktemp -p "$LOCK_DIR" .pid.XXXXXX 2>/dev/null)
        if test -z "$_pid_tmp"; or not printf '%s\n' $fish_pid >"$_pid_tmp" 2>/dev/null
            test -n "$_pid_tmp"; and command rm -f -- "$_pid_tmp" 2>/dev/null
            command rmdir -- "$LOCK_DIR" 2>/dev/null
            echo "[ERR] Failed to write lock pid file: $LOCK_FILE" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        end
        if not command mv -f -- "$_pid_tmp" "$LOCK_FILE" 2>/dev/null
            command rm -f -- "$_pid_tmp" 2>/dev/null
            command rmdir -- "$LOCK_DIR" 2>/dev/null
            echo "[ERR] Failed to install lock pid file: $LOCK_FILE" >&2
            command rm -f -- "$LOG_FILE" 2>/dev/null
            return 1
        end
        set -g _RY_HOLDS_LOCK true
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
    # Stale lock reclaim: (a) flock(1) atomic advisory lock eliminates TOCTOU, (b) fallback rmdir+mkdir with PID
    set -l _reclaim_parent (dirname -- "$LOCK_DIR")
    # require both flock(1) AND /bin/sh — flock branch invokes /bin/sh -c
    if command -q flock; and command -q sh
        # flock -n/-E 5: non-blocking, exit 5 on contention. Paths as positional args
        set -l _sh_script (string join \n \
            'rm -f -- "$1/pid" 2>/dev/null  # lint:ignore (embedded /bin/sh -c block)' \
            'find "$1" -maxdepth 1 -type f -delete 2>/dev/null  # lint:ignore (embedded /bin/sh -c block)' \
            'rmdir -- "$1" 2>/dev/null || true  # lint:ignore (sh, not fish — embedded /bin/sh -c block)' \
            'mkdir -- "$1" 2>/dev/null || exit 1  # lint:ignore (sh, not fish — embedded /bin/sh -c block)' \
            'printf "%s\n" "$2" > "$1/pid" 2>/dev/null || exit 2  # lint:ignore (sh, not fish — embedded /bin/sh -c block)' | string collect)
        flock -n -E 5 "$_reclaim_parent" /bin/sh -c "$_sh_script" _ "$LOCK_DIR" "$fish_pid" 2>/dev/null
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
        # flock(1) is base util-linux on CachyOS; missing → broken env, refuse non-atomic reclaim.
        echo "[ERR] flock(1) and/or /bin/sh not available — cannot safely reclaim stale lock" >&2
        echo "[ERR]   Install util-linux: sudo pacman -S --needed util-linux" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    set -l verify_pid (command cat -- "$LOCK_FILE" 2>/dev/null)
    set -l my_pid $fish_pid
    if test "$verify_pid" != "$my_pid"
        echo "[ERR] Lock reclaim lost to concurrent instance (PID $verify_pid)" >&2
        command rm -f -- "$LOG_FILE" 2>/dev/null
        return 1
    end
    # removed redundant verify_pid2 — no time gap in flock branch; fallback yield covers race.
    set -g _RY_HOLDS_LOCK true
    _log "LOCK_RECLAIMED: stale pid=$old_pid, new pid=$fish_pid"
    return 0
end

# Signal handling: tmpfiles → lock release → keepalive; three entry points guarded by _CLEANUP_DONE

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
    # Descend to purge abandoned ry-run.* dirs; -type d -empty reclaims parents (maxdepth=1 sweep cannot reach in).
    command find "$_tmpdir" -mindepth 2 -maxdepth 2 -path "$_tmpdir/ry-*" -type f -user $_MY_UID -delete 2>/dev/null
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type d -empty -user $_MY_UID -delete 2>/dev/null
    # Free cached data (harmless but consistent with cleanup discipline)
    set --erase _KCONFIG_DATA
    set --erase _KCONFIG_LOADED
    set --erase _RY_SKIP_IWD
    # Release LOCK_DIR mutex — _RY_HOLDS_LOCK sentinel set by _acquire_lock on success
    if set -q _RY_HOLDS_LOCK; and set -q LOCK_DIR
        command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
    end
    _kill_sudo_keepalive
end

function _kill_sudo_keepalive --description "Terminate the background sudo credential refresh loop"
    if set -q SUDO_KEEPALIVE_PID; and test -n "$SUDO_KEEPALIVE_PID"
        # PID re-verify before kill: closes a narrow PID-reuse race window after wait/reap
        if kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            # pkill -P reaps descendants (sleep/sudo) so they do not orphan to init when parent fish exits.
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
set -g VERIFY_GEN_FAIL 0
# _cleanup writes footer + exits 128+signum; _cleanup_on_exit is the fish_exit fallback
function _teardown --argument-names mode --description "Unified cleanup: progress teardown, footer, resources"
    _progress_teardown
    switch $mode
        case signal
            _write_footer "$argv[2]" interrupted
            _do_cleanup
        case pipe
            _write_footer 141 interrupted
            _do_cleanup
        case exit
            # _do_cleanup added — normal exit must release lock + tmpfiles + keepalive
            _write_footer "$argv[2]" cleanup_exit
            _do_cleanup
        case '*'
            _err "_teardown: unknown mode '$mode'"
            return 1
    end
end

function _cleanup --on-signal INT --on-signal TERM --on-signal HUP --on-signal QUIT --description "Signal handler: clean up on INT/TERM/HUP/QUIT"
    test "$_CLEANUP_DONE" = true; and return 0
    echo "" >&2
    echo "[WARN] Interrupted - cleaning up..." >&2
    set -g _CLEANUP_DONE true
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
    _teardown signal $_sig_exit
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
    test "$_CLEANUP_DONE" = true; and return 0
    set -g _CLEANUP_DONE true
    _teardown pipe
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
    # prefer _RY_INSTALL_LAST_EXIT (set in _ry_exit) over $status
    if set -q _INTENDED_EXIT_CODE
        set _exit_status $_INTENDED_EXIT_CODE
    else if set -q _RY_INSTALL_LAST_EXIT
        set _exit_status $_RY_INSTALL_LAST_EXIT
    end
    if test "$_CLEANUP_DONE" = true
        return 0
    end
    _teardown exit $_exit_status
end

# PROFILES — machine-specific configuration

function _ry_profile_gtr9_pro_destinations --description "gtr9_pro: managed file destinations (12 system + 3 user + 1 service = 16)"
    # 1:1 to _ry_get_file_content(); sys=0644 user=0600; 12+3+1=16 = README count.
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
end

function _ry_profile_gtr9_pro_boot --description "gtr9_pro: systemd-boot loader.conf + sdboot-manage.conf settings"
    set -g LOADER_DEFAULT "@saved"
    set -g LOADER_TIMEOUT 0
    set -g LOADER_CONSOLE_MODE keep
    set -g LOADER_EDITOR no
    set -g SDBOOT_DEFAULT_ENTRY manual
    set -g SDBOOT_OVERWRITE yes
    # REMOVE_EXISTING=yes deletes ALL boot entries before regen — manual entries (rescue, Windows) will be lost
    set -g SDBOOT_REMOVE_EXISTING yes
    set -g SDBOOT_REMOVE_OBSOLETE yes
end

function _ry_profile_gtr9_pro_kernel --description "gtr9_pro: kernel cmdline params (15) + mkinitcpio modules/hooks/compression"
    # Zen 5 + gfx1151 defaults: amd_pstate=active, ppfeaturemask=0xfffd3fff, cwsr_enable=0, iommu=pt, tsc=reliable.
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

    set -g MKINITCPIO_MODULES amdgpu
    # systemd hooks — no resume hook (sleep/suspend targets masked)
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
end

function _ry_profile_gtr9_pro_network --description "gtr9_pro: resolved + logind + iwd + NetworkManager settings"
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
end

function _ry_profile_gtr9_pro_env --description "gtr9_pro: gaming/Proton ENV_VARS + sysctl tunables (21)"
    set -g ENV_VARS \
        "DXVK_LOG_LEVEL=none" \
        "DXVK_LOG_PATH=none" \
        "ENABLE_LAYER_MESA_ANTI_LAG=1" \
        "MESA_SHADER_CACHE_MAX_SIZE=4G" \
        "PROTON_ENABLE_WAYLAND=1" \
        "PROTON_LOCAL_SHADER_CACHE=1" \
        "PROTON_NO_WM_DECORATION=1" \
        "PROTON_USE_NTSYNC=1" \
        "RADV_EXPERIMENTAL=transfer_queue" \
        "RADV_PERFTEST=sam,nircache" \
        "VKD3D_DEBUG=none" \
        "VKD3D_SHADER_DEBUG=none" \
        "WINEDEBUG=-all"

    # Supplements vendor 70-cachyos-settings.conf (99-* loads after 70-*); see CHANGELOG for per-setting rationale.
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
        "net.core.netdev_budget=600" \
        "kernel.split_lock_mitigate=0" \
        "vm.swappiness=100"
end

function _ry_profile_gtr9_pro_packages --description "gtr9_pro: PKGS_ADD (14) / PKGS_DEL (8) / AUR_PKGS (1) / EXPECTED_VULKAN_PKGS"
    # PKGS_ADD=14 PKGS_DEL=8 AUR=1 must equal README counts
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

    set -g EXPECTED_VULKAN_PKGS vulkan-radeon lib32-vulkan-radeon lib32-mesa
end

function _ry_profile_gtr9_pro_services --description "gtr9_pro: MASK list (10) + EXPECTED_SERVICES (4)"
    # MASK=10 must equal README Masked Services count
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
end

function _ry_profile_gtr9_pro_thresholds --description "gtr9_pro: disk-space, boot-time, and CPU-detection thresholds"
    set -g BOOT_SPACE_CRIT 200
    set -g BOOT_SPACE_WARN 500
    set -g ROOT_AVAIL_CRIT 2
    set -g ROOT_AVAIL_WARN 5
    set -g BOOT_TIME_TARGET 15

    # Hardware expectations (optional)
    set -g EXPECTED_CPU_MATCH "Ryzen AI Max"
end

function _ry_profile_gtr9_pro --description "Beelink GTR9 Pro (Strix Halo)"
    set -g PROFILE_NAME gtr9_pro
    set -g PROFILE_DESC "Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S"

    _ry_profile_gtr9_pro_destinations
    _ry_profile_gtr9_pro_boot
    _ry_profile_gtr9_pro_kernel
    _ry_profile_gtr9_pro_network
    _ry_profile_gtr9_pro_env
    _ry_profile_gtr9_pro_packages
    _ry_profile_gtr9_pro_services
    _ry_profile_gtr9_pro_thresholds
    return 0
end

# PROFILE LOADER

function _validate_profile --description "Verify loaded profile has all required globals" --argument-names expected_name
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
    set -l empty_scalar
    # Scalar globals where empty string emits broken config
    set -l _scalar_required \
        PROFILE_NAME PROFILE_DESC \
        LOADER_DEFAULT LOADER_CONSOLE_MODE LOADER_EDITOR \
        SDBOOT_DEFAULT_ENTRY SDBOOT_OVERWRITE \
        SDBOOT_REMOVE_EXISTING SDBOOT_REMOVE_OBSOLETE \
        MKINITCPIO_COMPRESSION
    for var_name in $required
        if not set -q $var_name
            set -a missing $var_name
        else
            set -l val $$var_name
            if test (count $val) -eq 0
                set -a missing $var_name
            else if contains -- $var_name $_scalar_required; and test -z "$val"
                set -a empty_scalar $var_name
            end
        end
    end

    if test (count $missing) -gt 0
        _err "Profile missing required globals: $missing"
        return 1
    end

    if test (count $empty_scalar) -gt 0
        _err "Profile required globals set to empty string: $empty_scalar"
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

    # Element sanitization: reject shell metachars + glob metachars in profile globals embedded into config files
    for _list_var in KERNEL_PARAMS MKINITCPIO_MODULES MKINITCPIO_HOOKS
        if set -q $_list_var
            for _elem in $$_list_var
                if string match -qr -- '[[:space:]\x22\x24\x27\x5c\x60\(\);&|<>*?\[\]\{\}]' "$_elem"
                    _err "Profile global $_list_var element contains forbidden shell or glob metacharacter: '$_elem'"
                    return 1
                end
            end
        end
    end

    # NUL/LF/CR sanitization for config-value globals; LF/CR would split config silently
    for _list_var in ENV_VARS SYSCTL_VALUES LOGIND_IGNORE_KEYS IWD_DRIVER_QUIRKS SYSTEM_DESTINATIONS USER_DESTINATIONS SERVICE_DESTINATIONS
        if set -q $_list_var
            for _elem in $$_list_var
                if string match -qr -- '[\x00\x0a\x0d]' "$_elem"
                    _err "Profile global $_list_var element contains forbidden control character (NUL/LF/CR): '$_elem'"
                    return 1
                end
            end
        end
    end

    # ENV_VARS shape: KEY=VALUE (KEY = [A-Za-z_][A-Za-z0-9_]*); blocks malformed entries before environment.d generator
    if set -q ENV_VARS
        for _v in $ENV_VARS
            if not string match -qr -- '^[A-Za-z_][A-Za-z0-9_]*=' -- "$_v"
                _err "Profile global ENV_VARS element must be KEY=VALUE shape: '$_v'"
                return 1
            end
        end
    end

    # SYSCTL_VALUES shape: key=value (key = [A-Za-z][A-Za-z0-9._-]*, non-empty value); blocks empty-value sysctl lines
    if set -q SYSCTL_VALUES
        for _v in $SYSCTL_VALUES
            if not string match -qr -- '^[A-Za-z][A-Za-z0-9._-]*=\S' -- "$_v"
                _err "Profile global SYSCTL_VALUES element must be key=value with non-empty value: '$_v'"
                return 1
            end
        end
    end

    # Destination key uniqueness — covers BOTH literal dst duplicates AND slash→_ key collisions in one pass.
    set -l _keys
    for _d in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -a _keys (_tmpfile_key "$_d")
    end
    test (count $_keys) -eq (count (printf '%s\n' $_keys | sort -u))
    or begin
        _err "Profile destination keys collide (literal duplicate or slash-to-underscore collision)"
        return 1
    end

    # Precompute tmp dir lists for _cleanup_tmpfiles (avoids per-call rebuild).
    set -g _SYS_TMP_DIRS
    for _d in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l _dir (dirname -- "$_d")
        contains -- "$_dir" $_SYS_TMP_DIRS; or set -a _SYS_TMP_DIRS "$_dir"
    end
    set -g _USR_TMP_DIRS
    for _d in $USER_DESTINATIONS
        set -l _dir (dirname -- "$_d")
        contains -- "$_dir" $_USR_TMP_DIRS; or set -a _USR_TMP_DIRS "$_dir"
    end
    set -g _PROFILE_USES_NM false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_d"; or string match -q '*/iwd/*' -- "$_d"
            set -g _PROFILE_USES_NM true
            break
        end
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
        # head -n1 before string trim
        set name (command head -n 1 -- "$default_file" 2>/dev/null | string trim --)
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
        _ry_exit $EXIT_USAGE
    end

    # 3. Load profile function — file-based takes precedence over built-in (allows user override)
    set -l profile_dir "$HOME/.config/ry-install/profiles"
    set -l profile_path "$profile_dir/$name.fish"

    if test -f "$profile_path"
        # ownership + mode check before source (README documents trust model; enforce in code)
        set -l _po (stat -c '%u %a' -- "$profile_path" 2>/dev/null)
        if test -z "$_po"
            _err "Cannot stat profile: $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            _ry_exit $EXIT_USAGE
        end
        set -l _pp (string split ' ' -- "$_po")
        if test "$_pp[1]" != "$_MY_UID"
            _err "Profile not owned by current user (uid $_pp[1] != $_MY_UID): $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            _ry_exit $EXIT_USAGE
        end
        # Reject group/other write bits — pattern: owner=any, group/other in {0,1,4,5}
        if not string match -qr '^[0-7][0145][0145]$' -- "$_pp[2]"
            _err "Profile mode too permissive (mode=$_pp[2]; group/world write bit set): $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            _ry_exit $EXIT_USAGE
        end
        if not fish --no-execute "$profile_path" 2>/dev/null
            _err "Profile file has syntax errors: $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            _ry_exit $EXIT_USAGE
        end
        if functions -q "_ry_profile_$name"
            _log "PROFILE_OVERRIDE: file '$profile_path' overrides built-in _ry_profile_$name"
            functions -e "_ry_profile_$name"
        end
        source "$profile_path"
        # Bail check: sourced profile calling _ry_exit (via helper) sets sentinel; catch before profile fn invoke
        test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
        if functions -q "_ry_profile_$name"
            _ry_profile_$name
        else if functions -q "profile_$name"
            # Backward compatibility: accept old profile_<n> convention with deprecation warning
            _warn "Profile uses deprecated naming: profile_$name → rename to _ry_profile_$name"
            profile_$name
        else
            _err "Profile file does not define function _ry_profile_$name: $profile_path"
            command rm -f -- "$LOG_FILE" 2>/dev/null
            _ry_exit $EXIT_USAGE
        end
    else if functions -q "_ry_profile_$name"
        _ry_profile_$name
    else
        _err "Unknown profile: $name"
        command rm -f -- "$LOG_FILE" 2>/dev/null
        _ry_exit $EXIT_USAGE
    end

    # 4. Validate
    if not _validate_profile "$name"
        # EXIT_PREFLIGHT (not EXIT_USAGE): profile loaded but failed structural validation (missing globals, type
        command rm -f -- "$LOG_FILE" 2>/dev/null
        _ry_exit $EXIT_PREFLIGHT
    end

    # 5. Derived globals
    set -g MANAGED_FILE_COUNT (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)

    # 6. Cache root UUID — findmnt called once; eliminates TOCTOU between _ry_install_file compare/write paths.
    set -g _ROOT_UUID (findmnt -no UUID / 2>/dev/null)
    # tightened from `^[0-9a-fA-F-]+$` (accepted '----' and bare hex) to canonical UUID form.
    if test -n "$_ROOT_UUID"; and not string match -qr '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' -- "$_ROOT_UUID"
        _err "Root UUID has invalid shape (got: $_ROOT_UUID) — refusing to cache"
        set --erase _ROOT_UUID
    end
    if test -z "$_ROOT_UUID"
        # --check routes via _log to honor "silent idempotency probe" contract on preflight failure.
        switch "$MODE"
            case check
                _log "ROOT_UUID_UNAVAILABLE: findmnt failed (silent for --check)"
                command rm -f -- "$LOG_FILE" 2>/dev/null
                _ry_exit $EXIT_PREFLIGHT
            case install install-file verify-static verify-runtime
                _err "Cannot detect root UUID (findmnt failed) — /etc/kernel/cmdline cannot be generated"
                command rm -f -- "$LOG_FILE" 2>/dev/null
                _ry_exit $EXIT_PREFLIGHT
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

    # 8. Profile-overridable timing globals: reject non-positive-int and reset to defaults; protects sleep(1) and keepalive loop from junk values
    if not string match -qr '^[1-9][0-9]*$' -- "$SUDO_KEEPALIVE_INTERVAL"
        _warn "SUDO_KEEPALIVE_INTERVAL='$SUDO_KEEPALIVE_INTERVAL' invalid (expected positive integer) — resetting to 45"
        _log "PROFILE_INVALID_SUDO_KEEPALIVE_INTERVAL: value=$SUDO_KEEPALIVE_INTERVAL — using default 45"
        set -g SUDO_KEEPALIVE_INTERVAL 45
    end
    if not string match -qr '^[1-9][0-9]*$' -- "$NM_RESTART_DELAY"
        _warn "NM_RESTART_DELAY='$NM_RESTART_DELAY' invalid (expected positive integer) — resetting to 3"
        _log "PROFILE_INVALID_NM_RESTART_DELAY: value=$NM_RESTART_DELAY — using default 3"
        set -g NM_RESTART_DELAY 3
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
    # Track tmp for cleanup; on successful mv it disappears (rm -f is harmless), on failure cleanup removes the
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
    _untrack_tmpfile "$tmp"
    _log "MANIFEST_WRITTEN: $MANIFEST_FILE ($MANAGED_FILE_COUNT destinations)"
    return 0
end

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

# Per-destination content generators (C.6) — names: _content_<_tmpfile_key(dst)>
function _content__boot_loader_loader.conf --description "Embedded content for /boot/loader/loader.conf"
    printf '%s\n' "# systemd-boot loader configuration" "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"
end

function _content__etc_kernel_cmdline --description "Embedded content for /etc/kernel/cmdline"
    if test -z "$_ROOT_UUID"
        _err "_content_etc_kernel_cmdline: root UUID not cached (_load_profile may not have run)"
        return 12
    end
    printf '%s %s\n' "rw root=UUID=$_ROOT_UUID" (string join -- " " $KERNEL_PARAMS)
end

function _content__etc_sdboot-manage.conf --description "Embedded content for /etc/sdboot-manage.conf"
    printf '%s\n' "# sdboot-manage configuration — changes require: sudo sdboot-manage gen && sudo sdboot-manage update" "LINUX_OPTIONS=\""(string join -- " " $KERNEL_PARAMS)"\"" "LINUX_FALLBACK_OPTIONS=\"quiet\"" "DEFAULT_ENTRY=\"$SDBOOT_DEFAULT_ENTRY\"" "REMOVE_EXISTING=\"$SDBOOT_REMOVE_EXISTING\"" "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\"" "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\""
end

function _content__etc_mkinitcpio.conf --description "Embedded content for /etc/mkinitcpio.conf"
    printf '%s\n' "# mkinitcpio configuration — changes require: sudo mkinitcpio -P && sudo sdboot-manage update" "MODULES=("(string join -- " " $MKINITCPIO_MODULES)")" "BINARIES=()" "FILES=()" "HOOKS=("(string join -- " " $MKINITCPIO_HOOKS)")" "COMPRESSION=\"$MKINITCPIO_COMPRESSION\""
    if set -q MKINITCPIO_COMPRESSION_OPTIONS; and test -n "$MKINITCPIO_COMPRESSION_OPTIONS"
        printf '%s\n' "COMPRESSION_OPTIONS=($MKINITCPIO_COMPRESSION_OPTIONS)"
    end
end

function _content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf --description "Embedded content for /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf"
    printf '%s\n' "# systemd-resolved configuration" "[Resolve]" "MulticastDNS=$RESOLVED_MDNS" "LLMNR=no" "DNSOverTLS=opportunistic" "DNSSEC=allow-downgrade"
end

function _content__etc_systemd_logind.conf.d_99-cachyos-logind.conf --description "Embedded content for /etc/systemd/logind.conf.d/99-cachyos-logind.conf"
    printf '%s\n' "# systemd-logind configuration - desktop power handling"
    printf '%s\n' "[Login]"
    # Cache systemd version once per process (called by every _content_hash → 16 times per verify-static).
    if not set -q _RY_SYSTEMD_VER
        set -g _RY_SYSTEMD_VER (systemctl --version 2>/dev/null \
            | head -n 1 | string match -r -- '\d+')
    end
    for key in $LOGIND_IGNORE_KEYS
        if test "$key" = HandleSecureAttentionKey
            if test -z "$_RY_SYSTEMD_VER"; or test "$_RY_SYSTEMD_VER" -lt 256
                continue
            end
        end
        printf '%s\n' "$key=ignore"
    end
end

function _content__etc_systemd_coredump.conf.d_99-cachyos-coredump.conf --description "Embedded content for /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf"
    printf '%s\n' "# Disable coredump storage — Wine/Proton crashes can write multi-GB dumps" "[Coredump]" "Storage=none" "ProcessSizeMax=0"
end

function _content__etc_udev_rules.d_99-nvme-rqaffinity.rules --description "Embedded content for /etc/udev/rules.d/99-nvme-rqaffinity.rules"
    printf '%s\n' '# NVMe completion locality — pin completions to submitting core' 'ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/rq_affinity}="2"'
end

function _content__etc_iwd_main.conf --description "Embedded content for /etc/iwd/main.conf"
    printf '%s\n' "# iwd configuration - minimal config for NetworkManager backend" "[General]" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "" "[DriverQuirks]"
    for quirk in $IWD_DRIVER_QUIRKS
        printf '%s\n' "$quirk"
    end
    printf '%s\n' "" "[Network]" "NameResolvingService=$IWD_DNS_SERVICE"
end

function _content__etc_NetworkManager_conf.d_99-cachyos-nm.conf --description "Embedded content for /etc/NetworkManager/conf.d/99-cachyos-nm.conf"
    printf '%s\n' "# NetworkManager configuration - iwd backend" "[device]" "wifi.backend=$NM_WIFI_BACKEND" "" "[connection]" "wifi.powersave=$NM_WIFI_POWERSAVE" "wifi.iwd.autoconnect=false" "" "[logging]" "level=$NM_LOG_LEVEL"
end

function _content_HOME_.config_fish_conf.d_10-ssh-auth-sock.fish --description "Embedded content for \$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"
    printf '%s\n' \
        '# SSH agent socket for fish shell -- priority: forwarded > gcr > systemd' \
        'if status is-interactive; and set -q XDG_RUNTIME_DIR; and not set -q SSH_CONNECTION' \
        '    if test -S "$XDG_RUNTIME_DIR/gcr/ssh"' \
        '        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"' \
        '    else if test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"' \
        '        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"' \
        '    end' \
        'end'
end

function _content_HOME_.config_environment.d_10-environment.conf --description "Embedded content for \$HOME/.config/environment.d/10-environment.conf"
    printf '%s\n' "# Environment variables for systemd user services and graphical sessions — loaded by systemd --user (COSMIC, Flatpak, D-Bus activated apps)"
    printf '%s\n' 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket'
    for var in $ENV_VARS
        printf '%s\n' "$var"
    end
end

function _content_HOME_.config_systemd_user_ssh-agent.service --description "Embedded content for \$HOME/.config/systemd/user/ssh-agent.service"
    printf '%s\n' \
        '[Unit]' \
        'Description=SSH authentication agent' \
        '' \
        '[Service]' \
        'Type=simple' \
        'ExecStart=/usr/bin/ssh-agent -D -a %t/ssh-agent.socket' \
        'Restart=on-failure' \
        'RestartSec=5' \
        '' \
        '[Install]' \
        'WantedBy=default.target'
end

function _content__etc_systemd_system_cpupower-epp.service --description "Embedded content for /etc/systemd/system/cpupower-epp.service"
    # Service intentionally succeeds on partial EPP write failure; per-CPU errors land in journal via StandardError=journal
    printf '%s\n' \
        '[Unit]' \
        'Description=Set CPU EPP to performance (amd_pstate=active: powersave governor + performance EPP)' \
        'After=cpupower.service' \
        'Wants=cpupower.service' \
        'ConditionPathExists=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference' \
        'ConditionPathExists=/usr/bin/bash' \
        '' \
        '[Service]' \
        'Type=oneshot' \
        'RemainAfterExit=yes' \
        'TimeoutStartSec=10' \
        'StandardError=journal' \
        'ExecStart=/usr/bin/bash -c \'shopt -s nullglob; for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$cpu" 2>/dev/null || echo "EPP write failed: $cpu" >&2; done; exit 0\'' \
        '' \
        '[Install]' \
        'WantedBy=multi-user.target'
end

function _content__etc_drirc --description "Embedded content for /etc/drirc"
    # RADV unified VRAM heap: prevents UMA APU games from misallocating. Requires Mesa ≥22.3.
    printf '%s\n' '<driconf>' \
        '  <device>' \
        '    <application name="Default">' \
        '      <option name="radv_enable_unified_heap_on_apu"' \
        '              value="true" />' \
        '    </application>' \
        '  </device>' \
        '</driconf>'
end

function _content__etc_sysctl.d_99-cachyos-sysctl.conf --description "Embedded content for /etc/sysctl.d/99-cachyos-sysctl.conf"
    printf '%s\n' "# ry-install sysctl tunables (priority 99 — loaded after CachyOS vendor 70-cachyos-settings.conf; overrides net.core.netdev_max_backlog 4096 → 16384)"
    for entry in $SYSCTL_VALUES
        set -l parts (string split -m1 '=' -- "$entry")
        set -l key (string trim -- "$parts[1]")
        set -l val (string trim -- "$parts[2]")
        printf '%s = %s\n' "$key" "$val"
    end
end

function _ry_get_file_content --argument-names dst --description "Generate expected content for a destination (dispatcher)"
    set -l fn "_content_"(_tmpfile_key "$dst")
    functions -q $fn; or return 11
    $fn
end

function _ensure_sudo_cached --description "Cache sudo credential once before parallel forking"
    if not command -q sudo
        _err "Sudo credential cache failed: sudo not found"
        return 1
    end
    set -l _sudo_err (mktemp -t ry-sudo-err.XXXXXX 2>/dev/null; or echo /dev/null)
    # log when mktemp fails
    if test "$_sudo_err" = /dev/null
        _log "MKTEMP_FAIL: ry-sudo-err — sudo error message will be unavailable"
    end
    test "$_sudo_err" != /dev/null; and set -ga _TRACKED_TMPFILES "$_sudo_err"
    # Probe sudo -n -v first (silent; redirect kills prompt); on miss retry sudo -v for tty password prompt.
    sudo -n -v 2>"$_sudo_err"
    set -l _rc $status
    if test $_rc -ne 0
        # gate interactive `sudo -v` fallback on isatty 0+2; non-tty contexts (cron/CI/sourced) hang.
        if isatty 0; and isatty 2
            sudo -v 2>"$_sudo_err"
            set _rc $status
        else
            _log "SUDO_CACHE_NONINTERACTIVE: stdin or stderr is not a tty — refusing interactive sudo -v"
        end
    end
    if test $_rc -ne 0
        set -l _reason (command head -n 1 -- "$_sudo_err" 2>/dev/null)
        command rm -f -- "$_sudo_err" 2>/dev/null
        # Untrack: rm consumed it; cleanup loop would otherwise stat() a dead path.
        _untrack_tmpfile "$_sudo_err"
        _log "SUDO_CACHE_FAIL: $_reason"
        if test -n "$_reason"
            _err "Sudo credential cache failed: $_reason"
        else
            _err "Sudo credential cache failed"
        end
        return 1
    end
    command rm -f -- "$_sudo_err" 2>/dev/null
    # Untrack: rm consumed it; cleanup loop would otherwise stat() a dead path.
    _untrack_tmpfile "$_sudo_err"
    return 0
end

# Tmpfile key: slash→underscore of destination path. Collision guard lives in _validate_profile (rejects /a/b vs
function _as --argument-names use_sudo --description "Prefix command with sudo or command based on use_sudo flag"
    # arity guard — caller error (use_sudo without a real command) previously invoked sudo or
    if test (count $argv) -lt 2
        _log "BUG: _as called without command (argv=$argv)"
        return 2
    end
    if test "$use_sudo" = true
        sudo -n $argv[2..-1]
    else
        command $argv[2..-1]
    end
end

function _tmpfile_key --argument-names path --description "Generate filename key from destination path (\$HOME→HOME literal, then slash→underscore)"
    # $HOME→HOME substitution before slash-replace keeps user-scope content fn names stable across users (fish
    string replace -a / _ -- (string replace -- "$HOME" HOME "$path")
end

# extracted from `string match -v` at six sites — enforces explicit-loop literal-equality uniformly.
function _untrack_tmpfile --argument-names path --description "Remove a single literal path from _TRACKED_TMPFILES (no glob)"
    set -l _new
    for _tf in $_TRACKED_TMPFILES
        test "$_tf" = "$path"; and continue
        set -a _new "$_tf"
    end
    set -g _TRACKED_TMPFILES $_new
end

# ─── Shared helpers (D.1 / D.2 / D.3) ─────────────────────────────────
function _is_system_dst --argument-names dst --description "True if dst is a system path (requires sudo to read)"
    string match -q '/etc/*' -- "$dst"
    or string match -q '/boot/*' -- "$dst"
    or string match -q '/usr/*' -- "$dst"
    or string match -q '/var/*' -- "$dst"
end

function _hash_installed --argument-names dst --description "SHA256 of installed file (empty on read failure; sudo-aware; pipestatus-checked)"
    set -l _bytes
    set -l _ps
    if _is_system_dst "$dst"
        sudo -n test -r "$dst" 2>/dev/null; or return 0
        set _bytes (sudo -n cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines)
        set _ps $pipestatus
        test $_ps[1] -ne 0; and return 0
    else
        test -r "$dst"; or return 0
        set _bytes (command cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines)
        set _ps $pipestatus
        test $_ps[1] -ne 0; and return 0
    end
    set -l _hash_line (printf '%s' "$_bytes" | sha256sum)
    set -l _ps2 $pipestatus
    if test $_ps2[1] -ne 0; or test $_ps2[2] -ne 0
        return 0
    end
    set -l _hash (string split ' ' -- "$_hash_line")[1]
    test -z "$_hash"; and return 0
    printf '%s\n' "$_hash"
end

function _should_skip_iwd --argument-names dst --description "True if dst is iwd/NM-related and iwd is not installed (memoized)"
    string match -q '*/NetworkManager/*nm.conf' -- "$dst"; or string match -q '*/iwd/*' -- "$dst"; or return 1
    if not set -q _RY_SKIP_IWD
        if command -q pacman; and pacman -Qi iwd >/dev/null 2>&1
            set -g _RY_SKIP_IWD false
        else
            set -g _RY_SKIP_IWD true
        end
    end
    test "$_RY_SKIP_IWD" = true
end

function _mask_list_effective --description "Effective MASK list (excludes lvm2-monitor.service when LVM detected)"
    set -l _has_lvm false
    _detect_lvm; and set _has_lvm true
    for _u in $MASK
        if test "$_u" = lvm2-monitor.service; and test "$_has_lvm" = true
            continue
        end
        echo "$_u"
    end
end


# LOGGING, MESSAGE OUTPUT, AND VERIFICATION COUNTERS

# Escape \\, \x22, \n, \r, \t for JSON
function _json_str --description "Escape a string for safe JSON embedding"
    set -l val (string replace -a '\\' '\\\\' -- "$argv[1]" | string collect)
    set val (string replace -a '"' '\\"' -- "$val" | string collect)
    set val (string replace -a \n '\\n' -- "$val" | string collect)
    set val (string replace -a \r '\\r' -- "$val" | string collect)
    set val (string replace -a \t '\\t' -- "$val" | string collect)
    # Strip remaining C0 (0x00-0x08, 0x0B-0x0C, 0x0E-0x1F) + DEL (0x7F) by replacement
    set val (string replace -ar '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]' '?' -- "$val")
    printf '%s\n' "$val"
end

function _log_section --argument-names name --description "Emit a section-event JSONL marker"
    _log "=== $name ==="
end


# INVARIANT: NEVER call _log from a fish -c parallel child — no file locking, concurrent writes corrupt JSONL.
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
    # drop redundant set -l — event and data are already locals from L1355-1356
    set event (string replace -ra '[^a-z0-9_]' '' -- "$event")
    set data (_json_str "$data")
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
    printf '{"ts":"%s","event":"%s","data":"%s"}\n' "$_ts" "$event" "$data" >>"$LOG_FILE" 2>/dev/null
end

# Format and emit a leveled [LEVEL] message to stderr; respects NO_COLOR and logs to JSONL
function _msg --argument-names level --description "Format and print a leveled status message"
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
    _echo "── $text ──"
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

# Progress bar: stationary bottom-row rendering via DECSTBM scroll region

function _progress_init --description "Open scroll region; draw initial bar"
    set -g _PROG_CUR 0
    set -g _PROG_TOTAL 6
    set -g _PROG_START (date +%s)
    set -g _PROG_STEP_START $_PROG_START
    set -g _PROG_STEP_NAME ""
    set -g _PROG_PINNED false
    isatty 2; or return 0
    set -l rows (tput lines 2>/dev/null)
    string match -qr '^\d+$' -- "$rows"; or return 0
    test $rows -ge 10; or return 0
    set -g _PROG_PINNED true
    set -g _PROG_ROWS $rows
    printf '\e[1;%dr' (math $_PROG_ROWS - 1) >&2
    _progress_redraw "" 0
end

function _progress --argument-names name --description "Advance progress counter and emit step-end log"
    set -g _PROG_CUR (math "min($_PROG_CUR + 1, $_PROG_TOTAL)")
    set -l now (date +%s)
    if test -n "$_PROG_STEP_NAME"
        _log "PROG_STEP_END: name=$_PROG_STEP_NAME secs="(math $now - $_PROG_STEP_START)
    end
    set -g _PROG_STEP_NAME $name
    set -g _PROG_STEP_START $now
    _log "PROG_STEP_START: [$_PROG_CUR/$_PROG_TOTAL] $name"
    test "$_PROG_PINNED" = true; or return 0
    _progress_redraw "$name" $_PROG_CUR
end

function _progress_redraw --argument-names name current --description "Redraw pinned progress bar at terminal bottom row"
    set -l pct (math "floor($current * 100 / $_PROG_TOTAL)")
    set -l filled (math "floor($current * 40 / $_PROG_TOTAL)")
    set -l empty (math "40 - $filled")
    set -l bar
    test $filled -gt 0; and set bar (string repeat -n $filled '█')
    test $empty -gt 0; and set bar "$bar"(string repeat -n $empty '░')
    printf '\e7\e[%d;1H\e[K[%s] %3d%% %s\e8' \
        $_PROG_ROWS "$bar" $pct "$name" >&2
end

function _progress_done --description "Finalize progress bar to 100% and log elapsed seconds"
    set -l elapsed (math (date +%s) - $_PROG_START)
    _log "PROG_DONE: elapsed_secs=$elapsed"
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r' >&2
    printf '\e[%d;1H\e[K[%s] 100%% Done (%ds)\n' \
        $_PROG_ROWS (string repeat -n 40 '█') $elapsed >&2
    set -g _PROG_PINNED false
end

function _progress_teardown --description "Clear pinned progress bar and reset scroll region (signal/abort path)"
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r\e[%d;1H\e[K\n' $_PROG_ROWS >&2
    set -g _PROG_PINNED false
end

# INVARIANT: argv[1] must be a PATH-resolvable external binary (not a fish/POSIX builtin); timeout(1) execs argv[1].
function _run --description "Execute a command with logging, stdout/stderr capture, and timeout enforcement"
    if test (count $argv) -eq 0
        _log "BUG: _run called with no arguments"
        return 1
    end
    # INVARIANT: callers pass pre-expanded argv with no shell metacharacters
    set -l log_cmd (string join -- " " $argv)

    # Redact secrets from log output; globs match --flag=value and --flag value without false positives
    for _secret_flag in --passphrase --password --token --key --secret --api-key --psk --wpa-psk --private-key
        if string match -q "* $_secret_flag=*" -- " $log_cmd"; or string match -q "* $_secret_flag *" -- " $log_cmd"
            set -l _escaped_flag (string escape --style=regex -- "$_secret_flag")
            # lint:ignore (PCRE backref)
            set log_cmd (string replace -r -- "(^| )$_escaped_flag=[^ ]+" '$1'"$_secret_flag=[REDACTED]" "$log_cmd")
            # lint:ignore (PCRE backref)
            set log_cmd (string replace -r -- "(^| )$_escaped_flag [^ ]+" '$1'"$_secret_flag [REDACTED]" "$log_cmd")
        end
    end
    # Redact tmp paths from ry-* artefacts so $TMPDIR location does not leak into logs
    set log_cmd (string replace -ar -- '/tmp/ry-[A-Za-z0-9_.-]+' '/tmp/ry-[REDACTED]' "$log_cmd")

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
        # command prefix forces external binary — prevents fish function recursion when timeout(1) unavailable.
        command $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    end
    set -l ret $status
    if test -s "$stderr_tmp"
        _log "STDERR: "(string join -- " | " (command head -n 50 -- "$stderr_tmp"))
        test "$QUIET" = false; and command head -n 5 -- "$stderr_tmp" >&2
    end
    if test -s "$stdout_tmp"
        _log "OUTPUT: "(string join -- " | " (command head -n 100 -- "$stdout_tmp"))
        test "$QUIET" = false; and command cat -- "$stdout_tmp" >&2
    end
    # stdout_tmp and stderr_tmp are inside _run_dir; single rm -rf below cleans both
    if test -n "$_run_dir"; and test -d "$_run_dir"
        command rm -rf --preserve-root -- "$_run_dir" 2>/dev/null
        # explicit loop replaces `string match -v` glob — defensive against metacharacters in $TMPDIR.
        set -l _new_tracked
        for _tf in $_TRACKED_TMPFILES
            test "$_tf" = "$_run_dir"; and continue
            set -a _new_tracked "$_tf"
        end
        set -g _TRACKED_TMPFILES $_new_tracked
    end
    _log "EXIT: $ret cmd=$log_cmd"
    return $ret
end

# Display full usage, options, exit codes, and examples to stdout
function _ry_show_help --description "Display usage information and available subcommands"
    # Fallback: use compile-time constant if profile has not loaded (--help exits before _load_profile)
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
  --                End of options (positional args after `--` are rejected with exit 2)
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
  NO_COLOR=1    Suppress ANSI color (also auto on TERM=dumb / non-TTY stderr).

Log: ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS+ZZZZ.jsonl
See README.md for full reference.
"
end

function _chk_eq --argument-names label actual expected --description "Compare actual vs expected; emit _ok or _fail"
    if test "$actual" = "$expected"
        _ok "  $label: $actual"
    else
        _fail "  $label: $actual (expected: $expected)"
    end
end

function _chk_sysfs_eq --argument-names path expected label --description "Read sysfs/proc, compare to expected (silent on missing path)"
    test -f "$path"; or return 0
    set -l _val (command cat -- "$path" 2>/dev/null | string trim --)
    _chk_eq "$label" "$_val" "$expected"
end

function _chk_perms --argument-names path expected_perms expected_owner use_sudo --description "Compare file mode+owner; returns 1 on mismatch"
    set -l _po
    if test "$use_sudo" = true
        set _po (sudo -n stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    else
        set _po (stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    end
    # stat-fail guard
    if test -z "$_po"
        _fail "  $path: stat failed (file disappeared or unreadable)"
        return 1
    end
    set -l _parts (string split ' ' -- "$_po")
    if test "$_parts[1]" != "$expected_perms"; or test "$_parts[2]" != "$expected_owner"
        _fail "  $path: $_parts[1] $_parts[2] (expected: $expected_perms $expected_owner)"
        return 1
    end
    return 0
end

function _chk_present --argument-names rc label fail_suffix ok_word --description "Emit _ok / _fail based on rc; configurable suffix/word"
    test -z "$fail_suffix"; and set fail_suffix MISSING
    test -z "$ok_word"; and set ok_word present
    if test "$rc" -eq 0
        _ok "  $label: $ok_word"
    else
        _fail "  $label: $fail_suffix"
    end
end

function _chk_file --argument-names filepath --description "Verify a file exists (sudo for /boot, direct for /etc)"
    _log "CHECK_FILE: $argv[1]"
    if string match -q '/boot/*' -- "$argv[1]"
        if not command -q sudo
            _fail "File check requires sudo: $argv[1]"
            return 1
        end
        if sudo -n test -f "$argv[1]" 2>/dev/null
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
function _chk_grep --argument-names file pattern label --description "Verify a file contains an expected token (label defaults to pattern; whole-word for plain tokens, substring for k=v)"
    test -z "$label"; and set label "$pattern"
    _log "CHECK_GREP: $file for '$pattern'"

    set -l is_boot false
    string match -q '/boot/*' -- "$file"; and set is_boot true

    if test "$is_boot" = false
        if not test -r "$file"
            if test -f "$file"
                _fail "  $label: PERMISSION DENIED (need sudo?)"
            else
                _fail "  $label: FILE NOT FOUND"
            end
            return 1
        end
    end

    set -l found false
    if test "$is_boot" = true
        if not command -q sudo
            _fail "  $label: sudo required for /boot path"
            return 1
        end
        if not sudo -n test -f -- "$file" 2>/dev/null
            _fail "  $label: FILE NOT FOUND"
            return 1
        end
        sudo -n grep -qF -- "$pattern" "$file" 2>/dev/null; and set found true
    else
        grep -qF -- "$pattern" "$file" 2>/dev/null; and set found true
    end

    if test "$found" = true
        _ok "  $label: present"
        return 0
    else
        _fail "  $label: MISSING"
        return 1
    end
end

function _ry_check_deps --description "Verify required packages are installed"
    _log "Checking dependencies..."
    set -l missing
    for cmd in pacman systemctl mkinitcpio udevadm sdboot-manage findmnt sha256sum stat date
        command -q $cmd; or set -a missing $cmd
    end
    if test (count $missing) -gt 0
        _err "missing: $missing"
        return 1
    end
    set -l systemd_ver (systemctl --version 2>/dev/null | head -n 1 | string match -r -- '\d+')
    if test -n "$systemd_ver"; and test "$systemd_ver" -lt 250
        _warn "Systemd version $systemd_ver detected; some features require 250+"
    end
    for cmd in journalctl dmesg modinfo pgrep free uptime
        command -q $cmd; or _warn "Expected tool not found: $cmd (from base packages)"
    end
    if set -q AUR_PKGS; and test (count $AUR_PKGS) -gt 0; and not command -q paru
        _err "missing: paru (AUR_PKGS=$AUR_PKGS)"
        set -g INSTALL_HAD_ERRORS true
        return 1
    end
    _log "All dependencies satisfied"
    return 0
end

# Test HTTPS connectivity to archlinux.org and DNS resolution before package operations
function _ry_check_network --description "Verify network connectivity (single HEAD + raw-IP fallback)"
    _log "Checking network connectivity..."
    if command -q curl
        if curl -sfI --connect-timeout 3 --max-time 5 https://archlinux.org >/dev/null 2>&1
            _ok "Network connectivity: OK"
            return 0
        end
    end
    if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1
        # cover both DNS-broken and 443-egress-blocked modes
        _err "Network connectivity: HTTPS or DNS unreachable (raw-IP ICMP works; check /etc/resolv.conf or 443 egress)"
        return 1
    end
    _err "Network connectivity: FAILED — cannot reach archlinux.org or 1.1.1.1"
    return 1
end

# Ensure root and /boot have sufficient free space; warn/fail at configurable thresholds
function _ry_check_disk_space --description "Verify sufficient free disk space for installation"
    _log "Checking disk space..."

    # df -B1 byte-precision (-BG/-BM round up); GNU only. v4.4.4: --output=avail single-column; tail -1 drops header.
    set -l root_avail_b (LC_ALL=C df --output=avail -B1 / 2>/dev/null | tail -n 1 | string trim --)
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

    # --output=avail single-column form (see / probe above for rationale).
    set -l boot_avail_b (LC_ALL=C df --output=avail -B1 /boot 2>/dev/null | tail -n 1 | string trim --)
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

    # Hard floor: 6.14 (ntsync + gfx1151 base support).
    if test "$major" -lt 6; or begin
            test "$major" -eq 6; and test "$minor" -lt 14
        end
        _fail "Kernel $kver < 6.14: ntsync and gfx1151 fixes unavailable"
        _info "  Upgrade kernel before or during install (pacman -Syu)"
        return 1
    end

    # Soft floor: 6.18.4 (gfx1151 stability — README floor)
    set -l kver_patch 0
    if set -q KVER_PARTS[3]
        set -l _patch_clean (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[3]")
        test -n "$_patch_clean"; and set kver_patch $_patch_clean
    end
    if test "$major" -eq 6; and begin
            test "$minor" -lt 18
            or begin
                test "$minor" -eq 18; and test "$kver_patch" -lt 4
            end
        end
        _warn "Kernel $kver below README stability floor 6.18.4 (gfx1151)"
        _info "  Recommend upgrading: sudo pacman -Syu linux-cachyos"
    end

    set -l _ns (_ntsync_state)
    if test "$_ns" = unavailable
        _warn "Kernel $kver: ntsync not available (expected builtin or module)"
    else
        _ok "Kernel $kver: ntsync $_ns"
    end

    # CHK-03: Kernel 6.19.0 black screen regression on Strix Halo (CachyOS #23042)
    if test "$major" -eq 6; and test "$minor" -eq 19
        if test "$kver_patch" = 0
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

    if test (count $hooks) -gt 0
        if test "$hooks[1]" != base
            _err "Mkinitcpio hook order: 'base' must be first (found: $hooks[1])"
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
            for i in (seq (count $hooks))
                test "$hooks[$i]" = "$hook_before"; and set idx_a $i
                test "$hooks[$i]" = "$hook_after"; and set idx_b $i
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

function _verify_unit_content --argument-names dst --description "Verify systemd unit content via tmpfile+_verify_unit_syntax"
    set -l content $argv[2..-1]
    command -q systemd-analyze; or return 0
    set -l tmp (mktemp -t ry-val-unit.XXXXXX --suffix=.service 2>/dev/null)
    test -n "$tmp"; or begin
        _fail "  $dst: mktemp failed"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$tmp"
    printf '%s\n' $content >"$tmp"
    _verify_unit_syntax "$tmp" (basename -- "$dst")
    set -l rc $status
    command rm -f -- "$tmp" 2>/dev/null
    _untrack_tmpfile "$tmp"
    return $rc
end

function _grep_kv --argument-names dst --description "Validate kv pairs (loader.conf space-sep; sdboot-manage.conf eq-sep)"
    set -l content $argv[2..-1]
    set -l keys
    set -l sep
    switch "$dst"
        case '*/loader.conf'
            set keys default timeout console-mode editor
            set sep ' '
        case '*/sdboot-manage.conf'
            set keys LINUX_OPTIONS LINUX_FALLBACK_OPTIONS DEFAULT_ENTRY REMOVE_EXISTING OVERWRITE_EXISTING REMOVE_OBSOLETE
            set sep '='
    end
    for key in $keys
        # Escape key (defense — current keys are alphanumeric/underscore, but profile may extend).
        set -l _key_re (string escape --style=regex -- "$key")
        string match -qr -- "^$_key_re$sep" $content; or begin
            _fail "  $dst: missing key '$key'"
            return 1
        end
    end
    return 0
end

function _grep_kparam --argument-names dst --description "Validate kernel cmdline has required tokens"
    string match -qr -- '(^|\s)root=UUID=' $argv[2..-1]; or begin
        _fail "  $dst: missing required token 'root=UUID='"
        return 1
    end
    return 0
end

function _grep_sysctl_kv --argument-names dst --description "Validate sysctl.d has ≥1 'key = value' line"
    # include `-` in key class
    string match -qre '^[a-zA-Z._0-9-]+\s*=\s*\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no 'key = value' lines found"
        return 1
    end
    return 0
end

function _grep_udev_kv --argument-names dst --description 'Validate udev rule shape (KEY==...<val>)'
    string match -qre '[A-Z_]+\s*[!=+:]{1,2}=\s*\x22' -- $argv[2..-1]; or begin
        _fail "  $dst: no udev rule found"
        return 1
    end
    return 0
end

function _grep_ini_header --argument-names dst --description 'Validate ≥1 [Section] header present'
    string match -qre '^\[[^]]+\]$' -- $argv[2..-1]; or begin
        _fail "  $dst: no [Section] header found"
        return 1
    end
    return 0
end

function _grep_xml_tag --argument-names dst --description "Validate drirc XML has required tags"
    set -l content $argv[2..-1]
    for tag in '<driconf>' '<device>' '<application'
        string match -qe -- "$tag" $content; or begin
            _fail "  $dst: missing XML tag '$tag'"
            return 1
        end
    end
    return 0
end

function _check_env_ssh_auth_sock --description "Phase 3: environment.d has SSH_AUTH_SOCK= and no %t literal"
    set -l dst "$HOME/.config/environment.d/10-environment.conf"
    set -l content (_ry_get_file_content "$dst")
    if test $status -ne 0
        _fail "  $dst: content generator failed"
        return 1
    end
    string match -qr '^SSH_AUTH_SOCK=' -- $content; or begin
        _fail "  $dst: missing SSH_AUTH_SOCK="
        return 1
    end
    string match -qe -- '%t' $content; and begin
        _fail "  $dst: forbidden %t literal present"
        return 1
    end
    # systemd-environment-d-generator(8) ${VAR} expansion requires systemd >= 232; warn on older hosts
    if not set -q _RY_SYSTEMD_VER
        set -g _RY_SYSTEMD_VER (systemctl --version 2>/dev/null | head -n 1 | string match -r -- '\d+')
    end
    if test -n "$_RY_SYSTEMD_VER"; and test "$_RY_SYSTEMD_VER" -lt 232
        _warn "  $dst: systemd $_RY_SYSTEMD_VER < 232; \${XDG_RUNTIME_DIR} expansion not supported"
    end
    return 0
end

function _ry_validate_configs --description "Run all embedded config validators"
    _info "Validating configuration syntax..."
    set -l errors 0

    # Phase 1: mkinitcpio HOOKS/MODULES (dedicated validators)
    _ry_validate_mkinitcpio_hooks; or set errors (math $errors + 1)
    _ry_validate_mkinitcpio_modules

    # Phase 2: per-destination validation by format family
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l fn "_content_"(_tmpfile_key "$dst")
        functions -q $fn; or begin
            _fail "  $dst: content generator '$fn' not found"
            set errors (math $errors + 1)
            continue
        end
        set -l content ($fn)
        if test $status -ne 0
            _fail "  $dst: content generator failed"
            set errors (math $errors + 1)
            continue
        end
        switch "$dst"
            case '*.service'
                _verify_unit_content "$dst" $content; or set errors (math $errors + 1)
            case '*.fish'
                # drop trailing dash arg — fish does not special-case dash as stdin (GH #1039)
                printf '%s\n' $content | fish --no-execute; or set errors (math $errors + 1)
            case '*/loader.conf' '*/sdboot-manage.conf'
                _grep_kv "$dst" $content; or set errors (math $errors + 1)
            case '*/kernel/cmdline'
                _grep_kparam "$dst" $content; or set errors (math $errors + 1)
            case '*/sysctl.d/*'
                _grep_sysctl_kv "$dst" $content; or set errors (math $errors + 1)
            case '*/udev/rules.d/*'
                _grep_udev_kv "$dst" $content; or set errors (math $errors + 1)
            case '*/drirc'
                _grep_xml_tag "$dst" $content; or set errors (math $errors + 1)
            case '*/mkinitcpio.conf'
                # Phase 1 validates HOOKS/MODULES via dedicated helpers
            case '*/environment.d/*'
                # Phase 3 validates environment.d
            case '*'
                _grep_ini_header "$dst" $content; or set errors (math $errors + 1)
        end
    end

    # Phase 3: environment.d sanity
    _check_env_ssh_auth_sock; or set errors (math $errors + 1)

    if test $errors -gt 0
        _err "Validation failed with $errors error(s)"
        return $EXIT_PREFLIGHT
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
    # Capture $pipestatus immediately; [1]=_ry_get_file_content, [2]=string collect (fish, OOM-only failure).
    set -l _content (_ry_get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines)
    set -l _ps $pipestatus
    test $_ps[1] -ne 0; and return 1
    test $_ps[2] -ne 0; and return 1
    test -z "$_content"; and return 1
    # Inline index via string split replaces external head(1). pipestatus[1..2] covers printf+sha256sum.
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

# Atomic write: dir-trust→mktemp→symlink-check→write→symlink-recheck→chmod→sudo-recheck→mv (v4.4.4: realigned)
function _atomic_write_file --argument-names dst perms use_sudo --description "Atomic file write with symlink and integrity checks"
    set -l _sp command
    set -l _expected_uid $_MY_UID
    if test "$use_sudo" = true
        set _sp sudo -n
        set _expected_uid 0
    end

    set -l dst_dir (dirname -- "$dst")
    # Parent-dir trust: exists, real dir, expected-uid-owned, not group/world-writable
    set -l _dir_stat (_as $use_sudo env LC_ALL=C stat -c '%F %u %a' -- "$dst_dir" 2>/dev/null)
    if test -z "$_dir_stat"
        _fail "→ $dst (parent dir missing or unreadable: $dst_dir)"
        return 1
    end
    set -l _df (string split ' ' -- "$_dir_stat")
    test "$_df[1]" != directory; and begin
        _fail "→ $dst (parent dir not a regular directory: type=$_df[1] $dst_dir)"
        return 1
    end
    if test "$use_sudo" = true
        sudo -n test -L "$dst_dir"; and begin
            _fail "→ $dst (parent dir is a symlink: $dst_dir)"
            return 1
        end
    else
        test -L "$dst_dir"; and begin
            _fail "→ $dst (parent dir is a symlink: $dst_dir)"
            return 1
        end
    end
    test "$_df[2]" != "$_expected_uid"; and begin
        _fail "→ $dst (parent dir uid=$_df[2] expected=$_expected_uid)"
        return 1
    end
    _dir_group_or_world_writable "$_df[3]"; and begin
        _fail "→ $dst (parent dir group/world writable: mode=$_df[3])"
        return 1
    end

    set -l tmpfile (_as $use_sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
    if test -z "$tmpfile"
        _fail "→ $dst (mktemp failed)"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$tmpfile"

    if test "$use_sudo" = true
        if sudo -n test -L "$tmpfile"
            _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
    else
        if test -L "$tmpfile"
            _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file is symlink — aborting)"
            return 1
        end
    end

    _ry_get_file_content "$dst" | _as $use_sudo tee -- "$tmpfile" >/dev/null
    set -l _ps $pipestatus
    if test $_ps[1] -ne 0
        _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
        switch $_ps[1]
            case 11
                _err "Not a managed destination: $dst"
            case 12
                _err "Content generator missing prerequisite global (e.g. _ROOT_UUID): $dst"
            case '*'
                _err "Content generator failed for $dst (rc=$_ps[1])"
        end
        return 1
    end
    if test $_ps[2] -ne 0
        _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
        _fail "→ $dst (write to temp failed)"
        return 1
    end

    if test "$use_sudo" = true
        if sudo -n test -L "$tmpfile"
            _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file replaced with symlink during write — aborting)"
            return 1
        end
    else
        if test -L "$tmpfile"
            _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
            _fail "→ $dst (temp file replaced with symlink during write — aborting)"
            return 1
        end
    end

    if not _run $_sp chmod -- $perms "$tmpfile"
        _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
        _fail "→ $dst (chmod failed)"
        return 1
    end

    # Atomic mv on same fs is sufficient; periodic integrity = --verify-static responsibility.
    if test "$use_sudo" = true; and not sudo -n true 2>/dev/null
        _err "sudo credential lapsed before atomic mv of $dst"
        _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
        return $EXIT_BOOT_CRIT
    end

    if not _run $_sp mv -- "$tmpfile" "$dst"
        _as $use_sudo rm -f -- "$tmpfile" 2>/dev/null
        _fail "→ $dst (atomic move failed)"
        return 1
    end

    # Untrack: mv consumed the tmpfile path; cleanup loop would otherwise stat() a dead path.
    _untrack_tmpfile "$tmpfile"
    _ok "→ $dst"
    return 0
end

# Deploy single embedded config: content → mktemp → chmod → mv; skips unchanged + iwd-less NM/IWD
function _ry_install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
    # Centralized iwd skip via _should_skip_iwd (matches NM/iwd path globs and memoizes pacman -Qi).
    if _should_skip_iwd "$dst"
        _warn "Skipping $dst: iwd package not installed"
        return 0
    end

    set -l dir (dirname -- "$dst")
    if test "$use_sudo" = true
        if not _run sudo -n mkdir -p -- "$dir"
            _fail "Cannot create directory: $dir"
            return 1
        end
    else
        # drop `command` prefix
        if not _run mkdir -p -- "$dir"
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

function _verify_static_boot --description "Verify loader.conf, sdboot-manage, kernel cmdline, mkinitcpio, boot entries"
    _echo "BOOT CONFIGURATION"
    _echo

    _echo "── loader.conf ──"
    if _chk_file /boot/loader/loader.conf
        for kv in "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" \
                  "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"
            _chk_grep /boot/loader/loader.conf "$kv"
        end
    end

    _echo "── sdboot-manage.conf ──"
    if _chk_file /etc/sdboot-manage.conf
        set -l opts (grep -- '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null \
            # lint:ignore (PCRE backref)
            | string replace -r -- '^LINUX_OPTIONS=\x22([^\x22]*)\x22.*$' '$1')

        for param in $KERNEL_PARAMS
            set -l _param_re (string escape --style=regex -- "$param")
            string match -qr -- "(^|\s)$_param_re(\s|\$)" -- "$opts"
            _chk_present $status "$param"
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
                set -l _param_re (string escape --style=regex -- "$param")
                string match -qr -- "(^|\s)$_param_re(\s|\$)" -- "$cmdline_content"
                _chk_present $status "$param" "MISSING from /etc/kernel/cmdline"
            end
            string match -q '*root=UUID=*' -- "$cmdline_content"
            _chk_present $status root=UUID "MISSING from /etc/kernel/cmdline"
        else
            _fail "  /etc/kernel/cmdline: empty or unreadable"
        end
    end
    _echo

    _echo "── mkinitcpio.conf ──"
    if _chk_file /etc/mkinitcpio.conf
        set -l modules_line (_ry_mkinitcpio_array MODULES)
        _echo "  Config: $modules_line"

        string match -q '*amdgpu*' -- "$modules_line"
        _chk_present $status amdgpu MISSING "present (early KMS)"

        for mod in $MKINITCPIO_MODULES
            if test "$mod" = amdgpu
                continue
            end
            set -l _mod_re (string escape --style=regex -- "$mod")
            string match -qr "\\b$_mod_re\\b" -- "$modules_line"
            _chk_present $status "$mod"
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
    if sudo -n test -d /boot/loader/entries 2>/dev/null
        # Null-delim count (\n-in-filename hazard closure
        set entry_count (count (sudo -n find /boot/loader/entries -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null | string split0))
    end
    # count(1) always emits non-negative integer
    if test "$entry_count" -gt 0
        _ok "  Boot entries: $entry_count found"
    else
        _fail "  Boot entries: NONE in /boot/loader/entries/"
        _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    end
    _echo
end

function _verify_static_system --description "Verify ntsync, udev, resolved, logind, coredump, iwd, NM, drirc, sysctl"
    # Pre-compute iwd state once (avoids 3 independent pacman -Qi calls and TOCTOU between them)
    set -l _skip_iwd false
    if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
        set _skip_iwd true
    end

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
        for kv in "MulticastDNS=$RESOLVED_MDNS" "DNSOverTLS=opportunistic" \
                  "DNSSEC=allow-downgrade" "LLMNR=no"
            _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "$kv"
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

    _echo "── coredump.conf ──"
    if _chk_file /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf
        for kv in Storage=none ProcessSizeMax=0
            _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "$kv"
        end
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
end

function _verify_static_user --description "Verify SSH agent fish script, environment.d, ssh-agent.service unit"
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
end

function _verify_static_packages --description "Verify PKGS_ADD, AUR_PKGS, PKGS_DEL, pacman.conf"
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
        set -l parallel (grep -nE -- '^ParallelDownloads[[:space:]]*=' /etc/pacman.conf 2>/dev/null)
        if test -n "$parallel"
            _ok "  $parallel"
        else
            _info "  ParallelDownloads not set (default: 1)"
        end
    else
        _warn "  /etc/pacman.conf not found"
    end
    _echo
end

function _verify_static_services --description "Verify SERVICE_DESTINATIONS files + masked services state"
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
    set -l _check_mask (_mask_list_effective)
    # Per-unit loop guarantees count($_mask_parsed) == count($_check_mask), so legacy partial-data fallback removed.
    set -l _mask_parsed
    for _u in $_check_mask
        set -l _v (systemctl show --value --property=LoadState,ActiveState,UnitFileState -- $_u 2>/dev/null | string split \n)
        set -a _mask_parsed "$_v[1]:$_v[2]:$_v[3]"
    end
    for _mask_idx in (seq 1 (count $_check_mask))
        set -l _svc $_check_mask[$_mask_idx]
        set -l _rec (string split ':' -- "$_mask_parsed[$_mask_idx]")
        if test "$_rec[1]" = not-found
            _info "  $_svc: unit not found (may not be installed)"
        else if test "$_rec[3]" = masked
            _ok "  $_svc: masked"
        else
            # Surface the actual LoadState (error/merged/bad-setting/masked-runtime) instead of just UnitFileState.
            _fail "  $_svc: load=$_rec[1] state=$_rec[2] file=$_rec[3] (expected: masked)"
        end
    end
    _echo
end

function _verify_static_syntax --description "Validate mkinitcpio hooks ordering, systemd unit files, fish scripts"
    _echo "SYNTAX VALIDATION"
    _echo

    _echo "── mkinitcpio hooks ──"
    set -l hooks_syntax_line (grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | grep -v '^#' | head -n 1)
    if test -n "$hooks_syntax_line"
        # lint:ignore (PCRE backref)
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_syntax_line")
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
end

function _verify_static_checksum --description "Verify embedded content hash matches installed file SHA256"
    _echo "CHECKSUM VERIFICATION"
    _echo
    _echo "── embedded vs installed ──"

    # under VERIFY_MODE (set at function entry); _verify_summary returns nonzero on fails.
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l expected (_content_hash "$dst")
        set -l actual (_hash_installed "$dst")
        switch "$expected::$actual"
            case "::*"
                _fail "  $dst: generator failed"
                set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + 1)
                _log "VERIFY_STATIC_GEN_FAIL: dst=$dst"
            case "*::"
                _fail "  $dst: cannot read"
                _log "VERIFY_STATIC_READ_FAIL: dst=$dst"
            case "*"
                if test "$expected" = "$actual"
                    _ok "  $dst: match"
                else
                    _fail "  $dst: MISMATCH"
                    _log "VERIFY_STATIC_MISMATCH: dst=$dst expected=$expected actual=$actual"
                end
        end
    end
    _echo
end

function _ry_verify_static --description "Verify installed configs match embedded checksums"
    _log_section "STATIC VERIFICATION START"
    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
        return $EXIT_PREFLIGHT
    end

    set -g VERIFY_MODE true
    set -g VERIFY_OK 0
    set -g VERIFY_FAIL 0
    set -g VERIFY_WARN 0
    set -g VERIFY_GEN_FAIL 0

    _info "Static verification (config files)..."
    _echo

    # Decomposition: 7 section helpers in original output order (boot → system → user → packages → services →
    _verify_static_boot
    _verify_static_system
    _verify_static_user
    _verify_static_packages
    _verify_static_services
    _verify_static_syntax
    _verify_static_checksum

    _log_section "STATIC VERIFICATION END"

    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

function _ry_do_check --description "Silent idempotency probe — exit 0 if clean, EXIT_DRIFT if drifted, EXIT_PREFLIGHT if prereqs fail"
    set -l drift 0

    # Phase 1: sudo cache (read-only mode has no keepalive; need cached creds for system reads)
    if not command -q sudo; or not sudo -n true 2>/dev/null
        _log "CHECK_PREFLIGHT: sudo not cached"
        return $EXIT_PREFLIGHT
    end

    # Phase 2: file content hash compare
    set -l checked 0
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l expected (_content_hash "$dst")
        set -l actual (_hash_installed "$dst")
        if test -z "$actual"
            if _is_system_dst "$dst"
                _log "CHECK_PREFLIGHT: cannot read $dst (sudo unavailable?)"
                return $EXIT_PREFLIGHT
            end
            set drift 1
            continue
        end
        test "$expected" = "$actual"; or set drift 1
        set checked (math $checked + 1)
    end

    # Phase 3: kernel cmdline parameters
    set -l _cmdline (cat /proc/cmdline 2>/dev/null)
    if test -z "$_cmdline"
        set drift 1
    else
        # whole-word regex match (escaped)
        for _p in $KERNEL_PARAMS
            set -l _p_re (string escape --style=regex -- "$_p")
            string match -qr -- "(^|\s)$_p_re(\s|\$)" -- "$_cmdline"; or set drift 1
        end
    end

    # Phase 4: per-unit systemctl show (C.1 pattern); compare to expected.
    set -l _implicit_svcs
    for _dst in $SYSTEM_DESTINATIONS
        switch $_dst
            case '*/systemd/resolved.conf.d/*'
                contains -- systemd-resolved.service $_implicit_svcs; or set -a _implicit_svcs systemd-resolved.service
            case '*/NetworkManager/dispatcher.d/*' '*/NetworkManager/conf.d/*'
                contains -- NetworkManager-dispatcher.service $_implicit_svcs; or set -a _implicit_svcs NetworkManager-dispatcher.service
        end
    end
    # Expected services: timers must be active+enabled; services active|exited+enabled.
    for unit in $EXPECTED_SERVICES
        set -l _v (systemctl show --value --property=LoadState,ActiveState,UnitFileState -- $unit 2>/dev/null | string split \n)
        set -l load $_v[1]
        set -l active $_v[2]
        set -l ufs $_v[3]
        if test "$load" = not-found
            set drift 1
        else if string match -q '*.timer' -- "$unit"
            test "$active" = active; or set drift 1
            test "$ufs" = enabled; or set drift 1
        else
            test "$active" = active; or test "$active" = exited; or set drift 1
            test "$ufs" = enabled; or set drift 1
        end
    end
    # Masked services (lvm2-monitor excluded by _mask_list_effective when LVM detected)
    for unit in (_mask_list_effective)
        set -l _v (systemctl show --value --property=LoadState,ActiveState,UnitFileState -- $unit 2>/dev/null | string split \n)
        if test "$_v[1]" = not-found
            continue
        end
        test "$_v[3]" = masked; or set drift 1
    end
    # Implicit services (drop-in present → managing service expected enabled; active varies)
    for unit in $_implicit_svcs
        set -l _v (systemctl show --value --property=LoadState,ActiveState,UnitFileState -- $unit 2>/dev/null | string split \n)
        if test "$_v[1]" = not-found
            continue
        end
        test "$_v[3]" = enabled; or set drift 1
    end

    # Phase 5: user-scope ssh-agent (must run in parent for D-Bus session access)
    set -l _ssh_unit_file "$HOME/.config/systemd/user/ssh-agent.service"
    if test -f "$_ssh_unit_file"
        set -l _ssh_state (systemctl --user is-enabled ssh-agent.service 2>/dev/null)
        test "$_ssh_state" = enabled; or set drift 1
    end

    if test $drift -ne 0
        return $EXIT_DRIFT
    end
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

# RUNTIME VERIFICATION — live sysfs/procfs state checks

function _verify_runtime_kparams --description "Verify /proc/cmdline, hardware state, module params, blacklist, clocksource, coredump"
    _echo "KERNEL CMDLINE"
    _echo

    set -l cmdline (command cat -- /proc/cmdline 2>/dev/null)
    if test -z "$cmdline"; and command -q sudo; and sudo -n true 2>/dev/null
        set cmdline (sudo -n cat -- /proc/cmdline 2>/dev/null)
    end
    for param in $KERNEL_PARAMS
        set -l _param_re (string escape --style=regex -- "$param")
        if string match -qr -- "(^|\s)$_param_re(\s|\$)" -- "$cmdline"
            _ok "  $param: active"
        else
            _fail "  $param: NOT in cmdline"
        end
    end
    _echo

    _validate_kernel_params

    set -l _dmesg (sudo -n dmesg 2>/dev/null)

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
        # lint:ignore (PCRE backref)
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_CPU_PATH")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:amd-pstate-epp:Scaling driver" \
            "scaling_governor:powersave:Governor" \
            "energy_performance_preference:performance:EPP"
            set -l parts (string split ':' -- "$check")
            set -l sysfs_val (command cat -- "$_CPU_PATH/$parts[1]" 2>/dev/null)
            _chk_eq "$parts[3]" "$sysfs_val" "$parts[2]"
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
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/prefcore enabled "amd_pstate prefcore"
    _chk_sysfs_eq /sys/devices/system/cpu/cpufreq/boost 1 "CPU boost"
    _echo

    _echo "MODULE STATE"
    _echo

    _echo "── Module parameters ──"
    # btusb check removed — usbcore.autosuspend=-1 handles globally

    _chk_sysfs_eq /sys/module/usbcore/parameters/autosuspend -1 "usbcore.autosuspend"

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
end

function _verify_runtime_services --description "Verify systemd unit states (sys batch + ssh-agent user) and WiFi runtime"
    _echo "SERVICE STATE"
    _echo

    # Batch systemctl show — 1 system call replaces individual calls
    set -l sys_units cpupower-epp.service \
        fstrim.timer systemd-resolved.service NetworkManager-dispatcher.service \
        NetworkManager.service
    # Static assertion: sys_units positionally coupled to parsed[1..5]; return 1 to abort env+session on drift.
    if test (count $sys_units) -ne 5
        _fail "  sys_units count drift: actual="(count $sys_units)" expected=5 — update parsed[N] indices below"
        return 1
    end
    set -l parsed
    for _u in $sys_units
        set -l _v (systemctl show --value --property=LoadState,ActiveState,UnitFileState -- $_u 2>/dev/null | string split \n)
        set -a parsed "$_v[1]:$_v[2]:$_v[3]"
    end

    # MAINTENANCE: parsed[] (Load:Active:UnitFileState) is positionally coupled to sys_units — update together.

    # cpupower-epp.service
    set -l rec (string split ':' -- "$parsed[1]")
    if test "$rec[1]" = not-found
        _warn "  cpupower-epp.service: not installed"
    else if test "$rec[2]" = active; or test "$rec[2]" = exited
        if test "$rec[3]" = enabled
            _ok "  cpupower-epp.service: $rec[2] (enabled)"
        else
            _warn "  cpupower-epp.service: $rec[2] but $rec[3] (will not persist)"
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
            _warn "  fstrim.timer: active but $rec[3] (will not persist)"
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
            _warn "  NetworkManager.service: active but $rec[3] (will not persist)"
        end
    else
        _fail "  NetworkManager.service: $rec[2] (expected: active)"
    end

    # User scope: ssh-agent (per-unit C.1 form; was batched + parser helper, deleted in v4.2.0 cleanup)
    set -l _u (systemctl --user show --value --property=LoadState,ActiveState,UnitFileState -- ssh-agent.service 2>/dev/null | string split \n)
    if test (count $_u) -lt 3
        _warn "  ssh-agent.service: systemctl --user show returned no data"
    else if test "$_u[2]" = active
        if test "$_u[3]" = enabled
            _ok "  ssh-agent.service: active (enabled)"
        else
            _warn "  ssh-agent.service: active but $_u[3] (will not persist)"
        end
    else if test -f "$HOME/.config/systemd/user/ssh-agent.service"
        _fail "  ssh-agent.service: $_u[2] (expected: active)"
    else
        _warn "  ssh-agent.service: not installed"
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

    return 0
end

function _verify_runtime_env --description "Verify ENV_VARS, sysctl, TCP, THP/KSM/ZRAM, fstab, ntsync runtime"
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

        if test "$actual" = "$expected"
            _ok "  $var_name=$actual"
        else if test -n "$actual"
            _fail "  $var_name=$actual (expected: $expected)"
        else
            # Env file verified by _ry_verify_static
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
    # lint:ignore (awk boolean operators)
    set -l _fstab_ext4 (command awk '!/^[[:space:]]*#/ && NF >= 4 && $3 == "ext4" { print $0 }' /etc/fstab 2>/dev/null)
    if test -n "$_fstab_ext4"
        set -l _fstab_ok true
        for _fl in $_fstab_ext4
            # lint:ignore (awk field reference, not fish cmdsubst)
            set -l _opts (printf '%s\n' "$_fl" | command awk '{ print $4 }')
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
end

function _verify_runtime_session --description "Verify file perms, parent dirs, Vulkan packages, boot performance"
    _echo "FILE PERMISSIONS"
    _echo

    _echo "── Sensitive files ──"
    set -l nm_conn_dir /etc/NetworkManager/system-connections
    if test -d "$nm_conn_dir"
        set -l conn_files (sudo -n find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f -print0 2>/dev/null | string split0)
        if test (count $conn_files) -gt 0
            set -l bad_perms 0
            for conn_file in $conn_files
                _chk_perms "$conn_file" 600 root:root true
                or set bad_perms (math $bad_perms + 1)
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
        if sudo -n test -f "$dst" 2>/dev/null
            if string match -q '/boot/*' -- "$dst"; and test "$_boot_fstype" = vfat
                continue
            end
            set perm_checked (math $perm_checked + 1)
            _chk_perms "$dst" 644 root:root true
            or set perm_bad (math $perm_bad + 1)
        end
    end
    set -l expected_owner (id -un)":"(id -gn)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            _chk_perms "$dst" 600 "$expected_owner" false
            or set perm_bad (math $perm_bad + 1)
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
        if sudo -n test -d "$dir" 2>/dev/null
            set dir_checked (math $dir_checked + 1)
            set -l _po (sudo -n stat -c '%a %U:%G' -- "$dir" 2>/dev/null)
            # stat-fail guard mirrors _chk_perms
            if test -z "$_po"
                _fail "  $dir: stat failed"
                set dir_bad (math $dir_bad + 1)
                continue
            end
            set -l perms (string split ' ' -- "$_po")[1]
            set -l owner (string split ' ' -- "$_po")[2]
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

        # Extract total seconds from already-captured line. Format: Startup finished in ... = 12.345s
        _log "BOOT_TIME_CHECK: parsing systemd-analyze output"
        set -l total_sec (printf '%s\n' "$boot_time" | string match -r -- '= ([0-9.]+)s' | tail -n 1)
        if test -n "$total_sec"; and string match -qr '^[0-9.]+$' -- "$total_sec"
            # BOOT_TIME_TARGET optional (see _validate_profile)
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
end

function _ry_verify_runtime --description "Verify runtime kernel params, services, and modules"
    _log_section "RUNTIME VERIFICATION START"

    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
        return $EXIT_PREFLIGHT
    end

    set -g VERIFY_MODE true
    set -g VERIFY_OK 0
    set -g VERIFY_FAIL 0
    set -g VERIFY_WARN 0
    set -g VERIFY_GEN_FAIL 0

    _info "Runtime verification (live system state)..."
    _echo

    # Decomposition: kparams → services → env → session per README v4.3.0 plan. _verify_runtime_services returns
    _verify_runtime_kparams
    if _verify_runtime_services
        _verify_runtime_env
        _verify_runtime_session
    end

    _log_section "RUNTIME VERIFICATION END"

    _verify_summary
    set -l ret $status
    set -g VERIFY_MODE false
    return $ret
end

# Install pipeline

# INSTALL PIPELINE — preflight → packages → files → services → boot → finalize

function _dir_group_or_world_writable --argument-names mode --description "True when octal mode has group or world write bit"
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

function _is_wifi_active_route --description "True if the default route exits via a wireless interface (handles VPN over WiFi)"
    # Check both v4 and v6 default routes so IPv6-only hosts are not misreported as wired
    # lint:ignore (awk field reference, not fish cmdsubst)
    set -l _def_iface (ip -4 route show default 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
    if test -z "$_def_iface"
        # lint:ignore (awk field reference, not fish cmdsubst)
        set _def_iface (ip -6 route show default 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
    end
    test -z "$_def_iface"; and return 1
    # Direct hit: default route exits a physical wireless iface.
    test -d "/sys/class/net/$_def_iface/wireless"; and return 0
    # Tunnel hit: route is virtual (tun*/wg*/ppp*/gre*/tap*)
    switch "$_def_iface"
        case 'tun*' 'tap*' 'wg*' 'ppp*' 'gre*' 'gretap*' 'sit*' 'ip6tnl*' 'ipip*'
            for _phy in /sys/class/net/*/wireless
                test -d "$_phy"; or continue
                set -l _name (basename (dirname -- "$_phy"))
                set -l _state (command cat -- "/sys/class/net/$_name/operstate" 2>/dev/null | string trim --)
                test "$_state" = up; and return 0
            end
    end
    return 1
end

function _install_preflight --description "Run all preflight checks before installation"
    _progress Preflight

    _info "Sudo password required for installation..."
    printf '\n' >&2
    # _ensure_sudo_cached for interactive sudo prompt (was bare `sudo -n true` with no fallback).
    _ensure_sudo_cached; or return $EXIT_PREFLIGHT
    # Reject restrictive sudoers tags before whitelisting
    set -l _sudo_lines (sudo -n -l 2>/dev/null | grep -v '^\s*#')
    set -l sudo_all 0
    for _sl in $_sudo_lines
        # Per-line Defaults that break keepalive: requiretty, tty_tickets, timestamp_timeout=0
        if string match -qr -- '\bDefaults\b.*\b(requiretty|tty_tickets|timestamp_timeout=0)\b' "$_sl"
            _err "Sudoers contains incompatible Defaults: $_sl"
            _kill_sudo_keepalive
            return $EXIT_PREFLIGHT
        end
        # Per-cmd reject tags: NOEXEC / !PASSWD / !SETENV / LOG_OUTPUT
        if string match -qr -- '(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)' "$_sl"
            continue
        end
        # Accept ALL at end of Cmnd_List or followed by additional whitelisted commands
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
    # Keepalive: 45 s cycle; loop bails on first sudo -n -v failure (fail-fast). Parent surfaces death via
    set -l _ka_script (string join \n \
        'while command kill -0 -- $argv[1] 2>/dev/null; and test -d -- "$argv[2]"' \
        '    command sudo -n -v 2>/dev/null; or break' \
        '    command sleep $argv[3] 2>/dev/null' \
        'end' | string collect)
    fish -c "$_ka_script" -- $my_pid "$LOCK_DIR" $SUDO_KEEPALIVE_INTERVAL </dev/null >/dev/null 2>&1 &
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

function _install_packages --description "Install managed packages via pacman -Syu"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Packages
    _echo
    # Install missing packages (PKGS_DEL removal: phase 4 in _install_configure_services)
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
        else if not _run sudo -n pacman -Syu --needed --noconfirm -- $pkgs_to_install
            _warn "Package installation failed, retrying with fresh sync (first-pass stderr in JSONL log)..."
            if not _run sudo -n pacman -Syyu --needed --noconfirm -- $pkgs_to_install
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

function _install_system_files --description "Deploy all embedded config files to the system"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Configuration
    _echo
    _info "Installing system configuration files..."
    _log "INSTALL SYSTEM FILES"
    set -l _had_failure false
    for dst in $SYSTEM_DESTINATIONS
        if not _ry_install_file "$dst" true
            _err "Failed to install: $dst"
            set _had_failure true
        end
    end
    if test "$_had_failure" = true
        _err "System file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    _echo
    _info "Installing user configuration files..."
    _log "INSTALL USER FILES"
    set -l _had_failure false
    for dst in $USER_DESTINATIONS
        if not _ry_install_file "$dst" false
            _err "Failed to install: $dst"
            set _had_failure true
        end
    end
    if test "$_had_failure" = true
        _err "User file installation failed"
        set -g INSTALL_HAD_ERRORS true
        set _fn_err true
    end

    test "$_fn_err" = true; and return 1
    return 0
end

function _install_fstab_opts --description "Add noatime,lazytime,commit=10 to ext4 fstab entries"
    _check_sudo_keepalive
    if not test -f /etc/fstab
        _warn "  /etc/fstab not found — skipping"
        return 0
    end
    # reject symlinked /etc/fstab; atomic mv would replace the symlink with a regular file.
    if test -L /etc/fstab
        _fail "  /etc/fstab is a symlink — refusing to rewrite (resolve symlink first or skip fstab opts)"
        return 1
    end
    # Detect any ext4 entry missing the desired opts (field-based: $3==ext4)
    # lint:ignore (awk field reference + boolean operators, not fish cmdsubst)
    set -l ext4_lines (command awk '!/^[[:space:]]*#/ && NF >= 4 && $3 == "ext4" { print $0 }' /etc/fstab 2>/dev/null)
    if test -z "$ext4_lines"
        _info "  No ext4 entries in /etc/fstab"
        return 0
    end
    set -l needs_change false
    set -l _commit_overrides
    for line in $ext4_lines
        # lint:ignore (awk field reference, not fish cmdsubst)
        set -l opts_field (printf '%s\n' "$line" | command awk '{ print $4 }')
        if not string match -q '*noatime*' -- "$opts_field"; or not string match -q '*lazytime*' -- "$opts_field"; or not string match -qr '(^|,)commit=10(,|$)' -- "$opts_field"
            set needs_change true
            # Surface non-default commit= overrides (commit=30 etc) so the rewrite is not silent.
            set -l _existing_commit (string match -r -- '(^|,)commit=([0-9]+)(,|$)' -- "$opts_field")[3]
            if test -n "$_existing_commit"; and test "$_existing_commit" != 10
                set -a _commit_overrides "$_existing_commit"
            end
        end
    end
    if test "$needs_change" = false
        _ok "  /etc/fstab: ext4 entries already have noatime,lazytime,commit=10"
        return 0
    end
    if test (count $_commit_overrides) -gt 0
        _warn "  /etc/fstab: replacing existing commit= value(s) with commit=10: $_commit_overrides"
    end
    # Atomic edit: one mktemp + one awk
    set -l tmpfstab (sudo -n mktemp -p /etc .ry-install.fstab.XXXXXX 2>/dev/null)
    if test -z "$tmpfstab"
        _fail "  /etc/fstab: mktemp failed"
        return 1
    end
    set -ga _TRACKED_TMPFILES "$tmpfstab"
    set -l _awk_script (string join \n \
        'BEGIN { OFS = " " }' \
        '/^[[:space:]]*#/ || NF < 4 { print; next }' \
        '$3 != "ext4" { print; next }' \
        '{' \
        '    n = split($4, opts, ",")' \
        '    has_noat = 0; has_lazy = 0; out = ""' \
        '    for (i = 1; i <= n; i++) {' \
        '        o = opts[i]' \
        '        if (o == "relatime" || o == "atime" || o == "strictatime") continue' \
        '        if (o ~ /^commit=/) continue' \
        '        if (o == "noatime") has_noat = 1' \
        '        if (o == "lazytime") has_lazy = 1' \
        '        out = (out == "" ? o : out "," o)' \
        '    }' \
        '    if (!has_noat)  out = (out == "" ? "noatime"  : out ",noatime")' \
        '    if (!has_lazy)  out = (out == "" ? "lazytime" : out ",lazytime")' \
        '    out = (out == "" ? "commit=10" : out ",commit=10")' \
        '    $4 = out' \
        '    print' \
        '}' | string collect)
    # drop sudo from awk side — /etc/fstab is 0644 root:root (world-readable per filesystem package)
    if not command awk "$_awk_script" /etc/fstab | sudo -n tee -- "$tmpfstab" >/dev/null
        sudo -n rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: awk/tee rewrite failed"
        return 1
    end
    if not sudo -n chmod --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null
        sudo -n rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: chmod --reference failed"
        return 1
    end
    if not sudo -n chown --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null
        sudo -n rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: chown --reference failed"
        return 1
    end
    if command -q findmnt
        set -l _verify_out (sudo -n findmnt --verify --tab-file "$tmpfstab" 2>&1)
        if test $status -ne 0
            sudo -n rm -f -- "$tmpfstab" 2>/dev/null
            _fail "  /etc/fstab: findmnt --verify failed: "(printf '%s\n' $_verify_out | head -n 3 | string join '; ')
            return 1
        end
    end
    if not sudo -n mv -- "$tmpfstab" /etc/fstab
        sudo -n rm -f -- "$tmpfstab" 2>/dev/null
        _fail "  /etc/fstab: atomic move failed"
        return 1
    end
    _untrack_tmpfile "$tmpfstab"
    _ok "  /etc/fstab: noatime,lazytime,commit=10 applied to ext4 entries"
    _log "FSTAB_OPTS: noatime,lazytime,commit=10 applied"
    return 0
end

function _configure_services_preset --description "udev finalize, systemd-resolved restart, PKGS_DEL removal"
    # gate udev finalize on presence of udev rules in SYSTEM_DESTINATIONS
    set -l _has_udev_dst false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*/udev/*' -- "$_d"
            set _has_udev_dst true
            break
        end
    end
    if test "$_has_udev_dst" = true
        _run sudo -n udevadm control --reload-rules; or _warn "Udevadm reload-rules failed"
        _run sudo -n udevadm trigger; or _warn "Udevadm trigger failed"
        _run sudo -n udevadm settle --timeout=5; or _warn "Udevadm settle timed out"
    end

    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        if not _run sudo -n systemctl restart systemd-resolved
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
                # pactree -ru -u lists pkg+rdeps flat; filter PKGS_DEL siblings so intra-batch deps do not shortcut.
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
        else if not _run sudo -n pacman -Rns --noconfirm -- $to_del
            _warn "Batch removal failed, trying individually..."
            _log "PKG_REMOVE_BATCH_FAIL: $to_del"
            # Re-query installed packages for TOCTOU: pkg may be removed between batch and retry
            set -l _retry_installed (pacman -Qq 2>/dev/null)
            for pkg in $to_del
                if contains -- "$pkg" $_retry_installed
                    if not _run sudo -n pacman -Rns --noconfirm -- "$pkg"
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
    return 0
end

function _configure_services_mask --description "Apply MASK list (LVM-aware via _mask_list_effective)"
    set -l safe_mask (_mask_list_effective)
    if test (count $safe_mask) -lt (count $MASK)
        _warn "LVM DETECTED - lvm2 services will NOT be masked"
    else if not command -q sudo; or not sudo -n true 2>/dev/null
        _info "LVM detection may be incomplete (sudo not cached)"
    end

    if test (count $safe_mask) -gt 0
        if not _run sudo -n systemctl mask -- $safe_mask
            _warn "Failed to mask some services"
        end
    end
    return 0
end

function _configure_services_enable --description "Install cpupower-epp, batch-enable system units, enable ssh-agent (user)"
    set -l _ret 0
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
        set _ret 1
    else
        if not _run sudo -n systemctl daemon-reload
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
        if not _run sudo -n systemctl enable --now -- $sys_enable
            _warn "Batch enable failed — retrying individually to identify failures"
            for _unit in $sys_enable
                if not _run sudo -n systemctl enable --now -- $_unit
                    _err "Failed to enable: $_unit"
                    set -g INSTALL_HAD_ERRORS true
                    set _ret 1
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
    return $_ret
end

function _install_configure_services --description "Enable, start, and configure systemd services"
    _check_sudo_keepalive
    _progress Services
    _echo
    _info "Post-installation tasks..."

    # Decomposition: preset (udev/resolved/PKGS_DEL) → mask → enable. Unified rollup: any helper returning 1
    set -l _ret 0
    _configure_services_preset; or set _ret 1
    _configure_services_mask; or set _ret 1
    _configure_services_enable; or set _ret 1
    return $_ret
end

# Post-rebuild gate: vmlinuz/initramfs non-zero, ≥1 entry references existing kernel; blocks reboot
function _preflight_boot_sanity --description "Verify boot artifacts are viable after rebuild"
    set -l errors 0
    # ESP path: resolve via bootctl, fall back to /boot. Handles hosts using /efi or /boot/efi.
    set -l _esp (sudo -n bootctl -p 2>/dev/null | string trim --)
    if test -z "$_esp"; or not sudo -n test -d "$_esp" 2>/dev/null
        set _esp /boot
    end

    # 1. At least one vmlinuz must exist
    set -l vmlinuz_files (sudo -n find "$_esp" -maxdepth 1 -name 'vmlinuz-*' -type f -print0 2>/dev/null | string split0)
    if test (count $vmlinuz_files) -eq 0
        _err "No vmlinuz found in $_esp/"
        set errors (math $errors + 1)
    else
        for f in $vmlinuz_files
            sudo -n test -s "$f" 2>/dev/null
            if test $status -ne 0
                _err "Zero-byte kernel image: $f"
                set errors (math $errors + 1)
            end
        end
    end

    # 2. At least one initramfs must exist and all must be non-zero. count==0 guard matches check #1 (vmlinuz)
    set -l initrd_files (sudo -n find "$_esp" -maxdepth 1 -name 'initramfs-*.img' -type f -print0 2>/dev/null | string split0)
    if test (count $initrd_files) -eq 0
        _err "No initramfs found in $_esp/"
        set errors (math $errors + 1)
    else
        for f in $initrd_files
            sudo -n test -s "$f" 2>/dev/null
            if test $status -ne 0
                _err "Zero-byte initramfs: $f"
                set errors (math $errors + 1)
            end
        end
    end

    # 3. At least one boot entry .conf must reference an existing kernel
    set -l confs (sudo -n find "$_esp/loader/entries" -maxdepth 1 -name '*.conf' -type f -print0 2>/dev/null | string split0)
    if test (count $confs) -eq 0
        _err "No boot loader entries in $_esp/loader/entries/"
        set errors (math $errors + 1)
    else
        set -l valid_entry false
        for conf in $confs
            # Strip leading linux keyword and optional slash from initrd path to extract the basename.
            set -l linux_line (sudo -n grep -m1 '^linux ' -- "$conf" 2>/dev/null | string replace -r '^linux\s+' '' | string trim --)
            set -l linux_rel (string trim --left --chars=/ -- "$linux_line")
            # Reject exact dot-dot path segments (not substring — foo..bar is a legal filename in some BLS setups).
            if contains -- ".." (string split '/' -- "$linux_rel")
                _warn "  Loader entry has non-BLS path (contains ..): $conf"
                continue
            end
            if test -n "$linux_rel"; and sudo -n test -f "$_esp/$linux_rel" 2>/dev/null
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
        # lint:ignore (user-facing shell advice)
        _info "  Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen"
        return 1
    end

    _ok "Boot sanity: vmlinuz present, initramfs non-zero, entries valid"
    return 0
end

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
        _log "SYSTEM_UPGRADE_SKIPPED: RY_INSTALL_CONFIRM_SYSTEM_UPGRADE not set"
    else
        _info "System upgrade proceeding unattended — review archlinux.org/news and wiki.cachyos.org post-install"
        if not _run sudo -n pacman -Syu --noconfirm
            _warn "System upgrade failed or was interrupted"
            set -g INSTALL_HAD_ERRORS true
        else
            _ok "System upgrade complete"
        end
    end

    # mkinitcpio/sdboot failure aborts to prevent unbootable system
    if not _run sudo -n mkinitcpio -P
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
        # Null-delim find + split0 keeps count accurate when entry filenames contain newlines (pathological)
        set -l _existing_basenames (sudo -n find /boot/loader/entries -maxdepth 1 -type f -name '*.conf' -printf '%f\0' 2>/dev/null | LC_ALL=C sort -z | string split0)
        set -l _existing_entries (count $_existing_basenames)
        # NUL-delimit hash input
        set -l _existing_hash (printf '%s\0' $_existing_basenames | sha256sum | string split ' ')[1]
        if set -q RY_INSTALL_CONFIRM_BOOT_WIPE; and test "$RY_INSTALL_CONFIRM_BOOT_WIPE" = 1
            set _acknowledged true
            _log "BOOT_WIPE_ACK: env var RY_INSTALL_CONFIRM_BOOT_WIPE=1 entries=$_existing_entries hash=$_existing_hash"
        else if test -f "$_wipe_marker"
            # Marker: v3.51.3+ stores count then sha256 separated by space
            set -l _marker_raw (string trim -- (command cat -- "$_wipe_marker" 2>/dev/null))
            set -l _marker_parts (string split ' ' -- "$_marker_raw")
            set -l _marked_count "$_marker_parts[1]"
            set -l _marked_hash ""
            if test (count $_marker_parts) -ge 2
                set _marked_hash "$_marker_parts[2]"
            end
            if test -z "$_marked_hash"; or not string match -qr '^\d+$' -- "$_marked_count"
                # Legacy/count-only marker — accept once; rewrite with count+hash below.
                set _acknowledged true
                _log "BOOT_WIPE_ACK: legacy marker $_wipe_marker (current_entries=$_existing_entries hash=$_existing_hash)"
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
    if not _run sudo -n sdboot-manage gen
        _warn "Sdboot-manage gen failed"
        set -g INSTALL_HAD_ERRORS true
        _err "CRITICAL: Bootloader update failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end
    if not _run sudo -n sdboot-manage update
        _err "Sdboot-manage update failed (bootctl EFI binary refresh)"
        set -g INSTALL_HAD_ERRORS true
        _err "CRITICAL: Bootloader binary update failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end

    # Boot-wipe marker written in _install_finalize success only (Fix 9) — partial-failure cannot update count.

    # Null-delim count (\n-in-filename hazard closure
    set -l entry_count (count (sudo -n find /boot/loader/entries -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null | string split0))
    # count(1) always emits non-negative integer
    if test "$entry_count" -gt 0
        _ok "Boot entries: $entry_count found in /boot/loader/entries/"
    else
        _err "No boot entries found in /boot/loader/entries/"
        _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
        _info "  Try: sudo sdboot-manage gen --verbose"
        set -g INSTALL_HAD_ERRORS true
    end

    # sudo find required: /boot may be ESP (vfat) 0700 root:root — user-context glob yields 0 iter, hides warnings.
    set -l _initrd_list (sudo -n find /boot -maxdepth 1 -type f -name 'initramfs-*.img' -print0 2>/dev/null | string split0)
    for initrd in $_initrd_list
        # stat -c %s gives exact bytes; du -m has whole-MB granularity varying by filesystem.
        set -l size_b (sudo -n stat -c '%s' -- "$initrd" 2>/dev/null)
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

function _install_finalize --description "Run post-install verification, cleanup, and summary"
    _progress Finalize

    # Persist boot-wipe acknowledgement on success only. Atomic tmp+mv prevents zero-byte marker from mid-write crash.
    if test "$SDBOOT_REMOVE_EXISTING" = yes
        set -l _wipe_marker $BOOT_WIPE_MARKER
        # Null-delim find + split0 (see _install_rebuild_boot gate for rationale; backward-compatible hash).
        set -l _post_basenames (sudo -n find /boot/loader/entries -maxdepth 1 -type f -name '*.conf' -printf '%f\0' 2>/dev/null | LC_ALL=C sort -z | string split0)
        set -l _post_count (count $_post_basenames)
        # NUL-delimit hash input
        set -l _post_hash (printf '%s\0' $_post_basenames | sha256sum | string split ' ')[1]
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

    if not _run sudo -n systemctl daemon-reload
        _warn "Systemctl daemon-reload failed"
    end
    if not _run systemctl --user daemon-reload
        _warn "Systemctl --user daemon-reload failed"
    end

    if command -q paccache
        if not _run sudo -n paccache -rk2 -ruk0
            _warn "Paccache cache trim failed"
        end
    else
        if not _run sudo -n pacman -Sc --noconfirm
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
            if not _run sudo -n systemctl restart NetworkManager
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
    _log_section "INSTALLATION START"
    _log "VERSION: $VERSION"
    _log "MODE: unattended"

    # Pre-declare _boot_rc at function scope so the bare set _boot_rc $status at the post-_install_rebuild_boot
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
    set --erase _RY_SKIP_IWD
    if command -q updatedb
        _run sudo -n updatedb; or _warn "Updatedb failed"
    end
    if command -q pkgfile
        _run sudo -n pkgfile --update; or _warn "Pkgfile update failed"
    end

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
        # lint:ignore (user-facing shell advice)
        _err "Fix boot issue first: sudo mkinitcpio -P && sudo sdboot-manage gen"
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
        _echo "INSTALLATION FINISHED WITH WARNINGS"
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

    _log_section "INSTALLATION END"
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
        _log "MANIFEST_SKIP: boot-critical failure — partial deploy not recorded"
        return $EXIT_BOOT_CRIT
    end
    _manifest_write; or _log "MANIFEST_WRITE_FAILED: install succeeded, manifest deferred (cosmetic — orphan detection next run)"
    test "$INSTALL_HAD_ERRORS" = true; and return $EXIT_FAIL
    return $EXIT_OK
end

function _ry_do_install_file --argument-names target --description "Install a single named config file"
    # target bound by --argument-names; empty string when 0 args (handled by test -z below)
    _log_section "INSTALL-FILE START"

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
        set -l _canon_dst (realpath -m -- "$dst" 2>/dev/null)
        if test "$target" = "$dst"; or test "$target" = "$_canon_dst"
            set valid true
            break
        end
    end
    if test "$valid" = false
        for dst in $USER_DESTINATIONS
            set -l _canon_dst (realpath -m -- "$dst" 2>/dev/null)
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
        # align with _install_preflight — _ensure_sudo_cached probes -n -v then falls back to -v.
        _ensure_sudo_cached; or return $EXIT_PREFLIGHT
    end

    if _ry_install_file "$target" $use_sudo
        # Post-install: rebuild boot entries if target is a boot-related config
        _echo
        _ok "Installed: $target"

        # Glob → post-install hook table. First-match-wins; no fallthrough on hook failure
        set -l _post_hooks \
            "/boot/*|boot" \
            "/etc/mkinitcpio*|boot" \
            "/etc/sdboot*|boot" \
            "/etc/kernel/cmdline|boot" \
            "*.service|service" \
            "*/udev/rules.d/*|udev" \
            "*/resolved.conf.d/*|resolved" \
            "*/logind.conf.d/*|logind" \
            "*/iwd/main.conf|nm" \
            "*/NetworkManager/conf.d/*|nm" \
            "*/sysctl.d/*|sysctl" \
            "*/coredump.conf.d/*|coredump" \
            "*/environment.d/*|envd" \
            "/etc/drirc|drirc"
        set -l _hook_rc 0
        for _entry in $_post_hooks
            set -l _g (string split '|' -- $_entry)[1]
            set -l _h (string split '|' -- $_entry)[2]
            if string match -q $_g -- "$target"
                # validate hook function exists before dispatch
                if not functions -q "_post_$_h"
                    _err "Internal: post-hook _post_$_h not defined for glob '$_g' (target=$target)"
                    set _hook_rc 1
                    break
                end
                _post_$_h "$target"
                set _hook_rc $status
                break
            end
        end
        _log_section "INSTALL-FILE END"
        return $_hook_rc
    else
        _err "Failed to install: $target"
        _log_section "INSTALL-FILE END"
        return 1
    end
end

# ─── Post-install hook helpers (C.5) ──────────────────────────────────
function _post_boot --argument-names target --description "Post-hook: rebuild boot entries (mkinitcpio + sdboot-manage)"
    _echo
    set -l _rc 0
    if not _run sudo -n mkinitcpio -P
        _err "Mkinitcpio failed"
        set _rc 1
    else if not _run sudo -n sdboot-manage gen
        _err "Sdboot-manage gen failed"
        set _rc 1
    else if not _run sudo -n sdboot-manage update
        _err "Sdboot-manage update failed"
        set _rc 1
    end
    if test $_rc -ne 0
        _err "CRITICAL: boot rebuild cascade failed — DO NOT REBOOT"
        # lint:ignore (user-facing shell advice)
        _info "  Fix: sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update"
        return $EXIT_BOOT_CRIT
    end
    if not _preflight_boot_sanity
        _err "CRITICAL: boot sanity check failed after single-file install — DO NOT REBOOT"
        return $EXIT_BOOT_CRIT
    end
    return 0
end

function _post_service --argument-names target --description "Post-hook: daemon-reload + enable .service unit"
    # enable failures propagate rc!=0 so --install-file dispatcher surfaces them (was warn+rc 0).
    set -l _rc 0
    if string match -q "$HOME/*" -- "$target"
        _run systemctl --user daemon-reload; or _warn "Systemctl --user daemon-reload failed"
        if _run systemctl --user enable --now -- (basename -- "$target")
            if string match -q '*ssh-agent*' -- "$target"; and set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"
                _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
                or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
            end
        else
            _warn "Failed to enable "(basename -- "$target")" (user)"
            set _rc 1
        end
    else
        _run sudo -n systemctl daemon-reload; or _warn "Systemctl daemon-reload failed"
        if not _run sudo -n systemctl enable --now -- (basename -- "$target")
            _warn "Failed to enable "(basename -- "$target")" (system)"
            set _rc 1
        end
    end
    return $_rc
end

function _post_udev --argument-names target --description "Post-hook: udev reload-rules + trigger + settle"
    _echo
    _run sudo -n udevadm control --reload-rules; or _warn "Udevadm reload-rules failed"
    _run sudo -n udevadm trigger; or _warn "Udevadm trigger failed"
    _run sudo -n udevadm settle --timeout=5; or _warn "Udevadm settle timed out"
    return 0
end

function _post_resolved --argument-names target --description "Post-hook: restart systemd-resolved"
    _echo
    _run sudo -n systemctl restart systemd-resolved; or _warn "Systemd-resolved restart failed"
    return 0
end

function _post_logind --argument-names target --description "Post-hook: notify reboot needed for logind"
    _info "Logind config changed — reboot required (restarting logind kills all sessions)"
    return 0
end

function _post_nm --argument-names target --description "Post-hook: restart NetworkManager (deferred when WiFi is active route)"
    _echo
    if _is_wifi_active_route
        _warn "NM/iwd config installed but NetworkManager restart deferred — WiFi is the active route."
        _warn "  Config change will not take effect until next reboot or manual restart."
        _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=install_file target=$target"
    else
        _run sudo -n systemctl restart NetworkManager; or _warn "NetworkManager restart failed"
    end
    return 0
end

function _post_sysctl --argument-names target --description "Post-hook: apply sysctl tunables"
    _echo
    if not _run sudo -n sysctl --system
        _warn "sysctl --system failed — tunables not applied until reboot"
        _info "  Retry: sudo sysctl --system"
    end
    return 0
end

function _post_coredump --argument-names target --description "Post-hook: reload coredump.socket"
    _echo
    _run sudo -n systemctl daemon-reload; or _warn "daemon-reload failed"
    if systemctl is-enabled systemd-coredump.socket >/dev/null 2>&1
        _run sudo -n systemctl restart systemd-coredump.socket; or _warn "systemd-coredump.socket restart failed"
    else
        _info "  systemd-coredump.socket not active — new config takes effect on next crash"
    end
    return 0
end

function _post_envd --argument-names target --description "Post-hook: notify session restart needed for environment.d"
    _info "environment.d changed — log out and back in (or restart user session) to apply"
    _info "  Active systemd --user services retain old environment until restarted"
    return 0
end

function _post_drirc --argument-names target --description "Post-hook: notify Wayland/X restart needed for drirc"
    _info "drirc changed — restart Wayland/X session or relaunch affected applications to apply"
    return 0
end



function _early_usage_exit --description "Print usage error to stderr, remove pre-dispatch log, exit EXIT_USAGE"
    echo "[ERR] $argv" >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -p -- "$LOG_DIR" 2>/dev/null
    _ry_exit $EXIT_USAGE
end

set -g MODE install

set -l INSTALL_FILE_TARGET ""

# Snapshot $argv pre-argparse so the JSONL header records the full invocation (argparse strips recognized flags
set -l _ORIG_ARGV $argv

# argparse --exclusive modes; v4.4.0: stderr → tmpfile for fish-specific errors. v4.4.4: tmpfile fail → $LOG_FILE.
set -l _ap_errfile (mktemp -t ry-argparse-err.XXXXXX 2>/dev/null)
if test -z "$_ap_errfile"
    if test -n "$LOG_FILE"; and test -f "$LOG_FILE"
        set _ap_errfile "$LOG_FILE"
    else
        set _ap_errfile /dev/null
    end
end
test "$_ap_errfile" != /dev/null; and test "$_ap_errfile" != "$LOG_FILE"; and set -ga _TRACKED_TMPFILES "$_ap_errfile"
argparse --name=ry-install.fish \
    --exclusive=verify-static,verify-runtime,check,install-file \
    h/help v/version V/verbose \
    verify-static verify-runtime check install-file= \
    -- $argv 2>"$_ap_errfile"
set -l _argparse_rc $status
if test $_argparse_rc -ne 0
    # Forward argparse's specific message; fall back to generic on capture failure.
    set -l _ap_msg ""
    if test "$_ap_errfile" != /dev/null; and test -s "$_ap_errfile"
        set _ap_msg (command cat -- "$_ap_errfile" 2>/dev/null | string trim --)
    end
    test -n "$_ap_msg"; or set _ap_msg "Invalid arguments: $_ORIG_ARGV"
    echo "[ERR] $_ap_msg" >&2
    test "$_ap_errfile" != /dev/null; and test "$_ap_errfile" != "$LOG_FILE"; and command rm -f -- "$_ap_errfile" 2>/dev/null
    echo >&2
    _ry_show_help >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -p -- "$LOG_DIR" 2>/dev/null
    _ry_exit $EXIT_USAGE
end
test "$_ap_errfile" != /dev/null; and test "$_ap_errfile" != "$LOG_FILE"; and command rm -f -- "$_ap_errfile" 2>/dev/null

test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT

# rmdir -p with rm -f LOG_FILE in every refused/informational early-exit path — no scaffolding left.

# --help / --version: short-circuit modes (exit 0).
if set -q _flag_help
    _ry_show_help
    command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -p -- "$LOG_DIR" 2>/dev/null
    _ry_exit 0
end
if set -q _flag_version
    echo "v$VERSION"
    command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -p -- "$LOG_DIR" 2>/dev/null
    _ry_exit 0
end

# root check after --help/--version; rmdir -p clears empty log dirs so root leaves no trace.
if test (id -u) -eq 0
    echo "[ERR] ry-install must not run as root. Run as your normal user; sudo is invoked internally." >&2
    command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -p -- "$LOG_DIR" 2>/dev/null
    _ry_exit $EXIT_USAGE
end

# -V/--verbose
set -q _flag_verbose; and set -g QUIET false

# Mode flags — argparse --exclusive enforces at most one.
if set -q _flag_verify_static
    set MODE verify-static
end
if set -q _flag_verify_runtime
    set MODE verify-runtime
end
if set -q _flag_check
    set MODE check
end
if set -q _flag_install_file
    set MODE install-file
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
        # warn on realpath -m fail (loop/ENAMETOOLONG/perm-denied) — surface stale-symlink fallback.
        echo "[WARN] realpath -m failed on '$_if_val' — using literal path; managed-file validation may not match" >&2
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
    command rmdir -p -- "$LOG_DIR" 2>/dev/null
    _ry_exit $EXIT_USAGE
end

# Mode exclusivity enforced by argparse --exclusive

if test "$MODE" != install; and test "$MODE" != check
    set -g QUIET false
end

# Load machine profile — must be after arg parsing but before any mode that reads config globals
_load_profile
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
# drift check between hardcoded help-fallback constant and active profile count.
if set -q MANAGED_FILE_COUNT; and test "$MANAGED_FILE_COUNT" -ne "$_RY_MANAGED_FILE_COUNT"
    _warn "_RY_MANAGED_FILE_COUNT ($_RY_MANAGED_FILE_COUNT) drifts from active profile ($MANAGED_FILE_COUNT) — update the constant in the bootstrap globals block"
end

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

set -l _argv_parts
for _a in (status filename) $_ORIG_ARGV
    set -a _argv_parts '"'(_json_str "$_a")'"'
end
set -l _argv_json '['(string join ',' $_argv_parts)']'
printf '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","verbose":%s,"argv":%s}\n' \
    (date '+%Y-%m-%dT%H:%M:%S%z') "$VERSION" "$PROFILE_NAME" "$MODE" \
    (test "$QUIET" = false; and echo true; or echo false) "$_argv_json" >>"$LOG_FILE" 2>/dev/null

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
            _ry_exit $EXIT_USAGE
        end
        _acquire_lock; or begin
            _ry_exit $EXIT_LOCK
        end
    case install
        _acquire_lock; or begin
            _ry_exit $EXIT_LOCK
        end
    case '*'
        # No lock needed for read-only modes (verify, check)
end

set -l _log_base_rot "$HOME/ry-install/logs"
# Oldest-first NUL-framed sort, drop oldest beyond MAX_LOGS; guard MAX_LOGS>0 (head -n -0 would wipe archive); LC_ALL=C ensures byte-wise mtime sort regardless of profile locale
if not string match -qr '^[1-9][0-9]*$' -- "$MAX_LOGS"
    set MAX_LOGS 50
end
set -l _rot_rows (command find "$_log_base_rot" \( -name '*.jsonl' -o -name '*.log' \) -type f ! -path "$LOG_FILE" -printf '%T@\t%p\0' 2>/dev/null | LC_ALL=C sort -zn | string split0)
set -l _rot_count (count $_rot_rows)
if test $_rot_count -gt $MAX_LOGS
    set -l _drop_to (math $_rot_count - $MAX_LOGS)
    for _row in $_rot_rows[1..$_drop_to]
        set -l _path (string split -m 1 \t -- "$_row")[2]
        test -n "$_path"; and command rm -f -- "$_path" 2>/dev/null
    end
end
command find "$_log_base_rot" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null

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
    # Sourced: release resources/handlers/namespace; do NOT exit. _do_cleanup runs before handler erase.
    set -g _RY_INSTALL_LAST_EXIT $exit_code
    _do_cleanup
    functions -e _cleanup _cleanup_pipe _cleanup_on_exit 2>/dev/null
    _ry_namespace_cleanup
    return $exit_code
end

exit $exit_code
