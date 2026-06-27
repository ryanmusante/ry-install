#!/usr/bin/env fish
# ry-install v7.76.4 (2026-06-27) - CachyOS config manager for Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151)
if test (status filename) = '-'; or status stack-trace | string match -q '*from sourcing*'; echo "[ERR] ry-install: must be executed, not sourced (use ./ry-install.fish)" >&2; return 1; end # refuse sourcing (filename='-' or by-path)

# ── HEADER: VERSION + EXIT CODES + PROFILE CONSTANTS ──
set -g VERSION "7.76.4"; set -g EXIT_OK 0; set -g EXIT_FAIL 1; set -g EXIT_USAGE 2; set -g EXIT_PREFLIGHT 3; set -g EXIT_BOOT_CRIT 4; set -g EXIT_LOCK 5; set -g EXIT_DRIFT 10
set -g EXIT_GEN_NOFN 11; set -g EXIT_GEN_NOUUID 12; set -g EXIT_GEN_SYSCTL 13
set -g EXIT_RUN_TMPFAIL 251
set -g EXIT_AS_MISUSE 250; set -g EXIT_RUN_MISUSE 255 # internal sentinels, never a process exit
set -g _RY_RUN_TIMEOUT_DEFAULT 3600
set -g PACTREE_TIMEOUT_S 60
set -g PROFILE_NAME gtr_pro; set -g PROFILE_DESC "Beelink GTR9 Pro - Ryzen AI Max+ 395 / Radeon 8060S"; set -g _RY_MANAGED_FILE_COUNT 18
set -g _RY_PHASE_NAMES Preflight Packages Configuration Services Boot Finalize
set -g KERNEL_MIN 6.18 # preflight floor: RTL8127 suspend-hang fix + r8169 support land >=6.18

# ── HELP TEXT ──
function _ry_show_help --description "Display usage information and available subcommands"
    printf '%s\n' \
        "" \
        "ry-install v$VERSION" \
        "Self-contained CachyOS configuration for $PROFILE_DESC" \
        "Single fish script, $_RY_MANAGED_FILE_COUNT embedded configs, no bundled dependencies." \
        "Usage: "(status filename)" [OPTIONS]" \
        "  (no args)              Unattended install" \
        "  -V, --verbose          Show install output (check is always silent)" \
        "  --verify               Check config files + live system state" \
        "  --check                Silent idempotency probe (0=clean 3=preflight 10=drift)" \
        "  --install-file <path>  Re-deploy a single managed file" \
        "  --                     End of options (no positional arguments accepted)" \
        "  -h, --help             Show this help (honored before all checks)" \
        "  -v, --version          Show version (honored before all checks)" \
        "EXIT CODES: 0 ok · 1 verify-FAIL/install-error · 2 usage · 3 preflight · 4 boot-critical · 5 lock · 10 --check drift" \
        "  (gen/run sentinels 11-13/250/251/255 are internal, never a process exit; signal codes 128+N appear in the JSONL footer; see README.md)" \
        "ENVIRONMENT (see README.md for detail):" \
        "  RY_RUN_TIMEOUT=<sec>  Per-_run wall-clock cap. Default $_RY_RUN_TIMEOUT_DEFAULT. 0=disable." \
        "  RY_INSTALL_SKIP_HARDWARE_CHECK=1  Bypass EXPECTED_CPU_MATCH hard-fail." \
        "  RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1  Bypass KERNEL_MIN hard-fail." \
        "  NO_COLOR  Suppress ANSI color (non-empty value, per no-color.org)." \
        "Log: ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl" \
        ""
end

# ── EARLY ARG INTERCEPT: -h/-v BEFORE ROOT GUARD ──
set -l _skip_if_val false
for _early_arg in $argv
    if test "$_skip_if_val" = true; set _skip_if_val false; continue; end # --install-file value: defer -h/-v to argparse
    switch "$_early_arg"
        case --
            break
        case --install-file
            set _skip_if_val true
        case -h --help
            _ry_show_help
            exit $EXIT_OK
        case -v --version
            echo "v$VERSION"
            exit $EXIT_OK
        case '-*'
            if string match -qr -- '^-[hvV]+$' "$_early_arg" # glued h/v/V only
                string match -q -- '*h*' "$_early_arg"; and begin; _ry_show_help; exit $EXIT_OK; end
                string match -q -- '*v*' "$_early_arg"; and begin; echo "v$VERSION"; exit $EXIT_OK; end
            end
    end
end
set --erase _early_arg _skip_if_val

# ── PATH HARDENING (before first external command: id -u) ──
set -l _ry_path_new
for _ry_p in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin $PATH
    string match -q -- '/*' $_ry_p; or continue # drop empty/relative PATH entries
    not contains -- $_ry_p $_ry_path_new; and set -a _ry_path_new $_ry_p
end
set -gx PATH $_ry_path_new
set --erase _ry_path_new _ry_p
command -q id; or begin; echo "[ERR] GNU coreutils id(1) required (resolves UID before privilege checks)" >&2; exit $EXIT_PREFLIGHT; end # first external command
set -g _MY_UID (command id -u)

# ── BAIL PRIMITIVES: _RY_EXIT + HANDLER ERASE ──
function _ry_erase_handlers --description "Erase signal/exit handler functions"; functions -e _cleanup _cleanup_pipe _cleanup_on_exit _progress_on_winch 2>/dev/null; end
function _ry_exit --argument-names code --description "Set bail sentinel and exit"
    test -z "$code"; and set code 0
    string match -qr '^\d+$' -- "$code"; or set code $EXIT_FAIL # non-numeric breaks footer printf %d
    if set -q _RY_INSTALL_BAILING; and test "$_RY_INSTALL_BAILING" = true; set -g _RY_INSTALL_LAST_EXIT $code; exit $code; end
    set -g _CLEANUP_DONE true; set -g _RY_INSTALL_LAST_EXIT $code; set -g _RY_INSTALL_BAILING true
    if not set -q _RY_HEADER_WRITTEN; and not set -q _RY_LOG_WRITTEN
        set -q LOG_FILE; and command rm -f -- "$LOG_FILE" 2>/dev/null
        set -q LOG_DIR; and command rmdir -- "$LOG_DIR" 2>/dev/null
        set -q LOG_DIR; and command rmdir -- (command dirname -- "$LOG_DIR") 2>/dev/null
        set -q HOME; and command rmdir -- "$HOME/ry-install" 2>/dev/null
    else
        functions -q _write_footer; and _write_footer "$code" bail
    end
    functions -q _do_cleanup; and _do_cleanup
    _ry_erase_handlers
    exit $code
end

# ── ROOT GUARD + COLOR/TTY + FISH VERSION CHECK ──
set -g QUIET true; set -g MODE bootstrap # pinned pre-argparse for signal footers
if not string match -qr '^\d+$' -- "$_MY_UID"; echo "[ERR] id -u returned non-numeric value: '$_MY_UID' — cannot determine user identity" >&2; _ry_exit $EXIT_PREFLIGHT; end
if test "$_MY_UID" -eq 0; echo "[ERR] ry-install must not run as root. Run as your normal user; sudo is invoked internally." >&2; _ry_exit $EXIT_USAGE; end
set -g _RY_NO_COLOR false
set -q NO_COLOR; and test -n "$NO_COLOR"; and set -g _RY_NO_COLOR true # present and non-empty
test "$TERM" = dumb; and set -g _RY_NO_COLOR true
set -l fish_ver $FISH_VERSION; set -l parts (string split '.' -- "$fish_ver"); set -l _fish_minor (string replace -r '[^0-9].*' '' -- "$parts[2]"); test -z "$_fish_minor"; and set _fish_minor 0
if not string match -qr '^\d+$' -- "$parts[1]"; or not string match -qr '^\d+$' -- "$_fish_minor"; echo "[ERR] fish version unparseable: '$fish_ver'" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -l _fish_ok 0
test "$parts[1]" -gt 3; and set _fish_ok 1
test "$parts[1]" -eq 3; and test "$_fish_minor" -ge 6; and set _fish_ok 1
if test "$_fish_ok" -eq 0; echo "[ERR] fish 3.6+ required (found: $fish_ver)" >&2; _ry_exit $EXIT_PREFLIGHT; end
set --erase fish_ver parts _fish_minor _fish_ok

# ── TMPDIR + COREUTILS PROBES ──
if set -q TMPDIR; and test -n "$TMPDIR"; and not string match -q -- '/*' "$TMPDIR"; echo "[WARN] TMPDIR is not an absolute path ($TMPDIR) — falling back to /tmp" >&2; set -gx TMPDIR /tmp; end
if set -q TMPDIR; and test -n "$TMPDIR"; and not test -d "$TMPDIR"; echo "[WARN] TMPDIR does not exist ($TMPDIR) — falling back to /tmp" >&2; set -gx TMPDIR /tmp; end
set -l _ry_tmpprobe_dir /tmp
if set -q TMPDIR; and test -n "$TMPDIR"; and test -d "$TMPDIR"; set _ry_tmpprobe_dir "$TMPDIR"; end
if not test -w "$_ry_tmpprobe_dir"
    if test "$_ry_tmpprobe_dir" != /tmp; and test -w /tmp
        echo "[WARN] TMPDIR not writable ($_ry_tmpprobe_dir) — falling back to /tmp" >&2
        set -gx TMPDIR /tmp
        set _ry_tmpprobe_dir /tmp
    else
        echo "[ERR] tmp dir not writable: $_ry_tmpprobe_dir" >&2
        _ry_exit $EXIT_PREFLIGHT
    end
end
set --erase _ry_tmpprobe_dir
if not command -q timeout; echo "[ERR] GNU coreutils timeout(1) required (used by _run for hang-protection)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command timeout --foreground --kill-after=1 1 true 2>/dev/null; echo "[ERR] timeout(1) lacks --foreground/--kill-after (need GNU coreutils ≥ 8.x; busybox/uutils not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if command -q find; and not command find /dev/null -maxdepth 0 -printf '' 2>/dev/null; echo "[ERR] find(1) lacks -maxdepth/-printf (need GNU findutils; busybox/uutils not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -l _ry_mv_a (command mktemp 2>/dev/null); set -l _ry_mv_b (command mktemp 2>/dev/null)
if test -z "$_ry_mv_a"; or test -z "$_ry_mv_b"; or not command mv -T -- "$_ry_mv_a" "$_ry_mv_b" 2>/dev/null; command rm -f -- "$_ry_mv_a" "$_ry_mv_b" 2>/dev/null; echo "[ERR] mv(1) lacks -T no-target-directory (need GNU coreutils ≥ 8.x; busybox not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
command rm -f -- "$_ry_mv_a" "$_ry_mv_b" 2>/dev/null; set --erase _ry_mv_a _ry_mv_b
if not command -q stat; echo "[ERR] GNU coreutils stat(1) required (used for mode/owner verification)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command -q date; echo "[ERR] GNU coreutils date(1) required (used for timestamps in DATE_LABEL, TIMESTAMP, JSONL ts fields)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not string match -qr '^[+-]\d{4}$' -- (command date '+%z' 2>/dev/null); echo "[ERR] date(1) lacks %z timezone offset support (need GNU coreutils ≥ 8.x; rejects empty or literal-%z output)" >&2; _ry_exit $EXIT_PREFLIGHT; end

# ── TIMESTAMPS + HOME + LOG_DIR ──
set -l _ry_now (command date '+%Y-%m-%d|%Y%m%d-%H%M%S%z'); set -l _ry_dt (string split -m1 '|' -- "$_ry_now"); set -g DATE_LABEL $_ry_dt[1]; set -g TIMESTAMP (string join '-' $_ry_dt[2] $fish_pid); set --erase _ry_now _ry_dt
if test -z "$HOME"; or not test -d "$HOME"
    set -gx HOME (command getent passwd $_MY_UID 2>/dev/null | command head -n 1 | command awk -F: '{print $6}')
    if test -z "$HOME"; or not test -d "$HOME"; echo "[ERR] Cannot determine HOME directory" >&2; _ry_exit $EXIT_PREFLIGHT; end
end
set -gx HOME (string trim -r -c / -- (string trim -- "$HOME"))
if test -z "$HOME"; or not test -d "$HOME"; echo "[ERR] HOME resolves to empty/non-dir after normalization: '$HOME'" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -g _RY_HOME_DIR "$HOME/ry-install"; set -g LOG_DIR "$_RY_HOME_DIR/logs/$DATE_LABEL"
set -l _prev_mkdir_umask (umask)
umask 0077
command mkdir -p -- "$LOG_DIR" 2>/dev/null; or begin
    umask $_prev_mkdir_umask
    echo "[ERR] Cannot create log directory: $LOG_DIR" >&2
    _ry_exit $EXIT_PREFLIGHT
end
umask $_prev_mkdir_umask
for _ld_path in "$_RY_HOME_DIR" "$_RY_HOME_DIR/logs" "$LOG_DIR"
    set -l _pre (command stat -c '%a' -- "$_ld_path" 2>/dev/null)
    command chmod -- 700 "$_ld_path" 2>/dev/null
    set -l _post (command stat -c '%a' -- "$_ld_path" 2>/dev/null)
    if test -n "$_pre"; and test "$_pre" != "$_post"; set -ga _RY_PERM_FIX_NOTICES "LOG_DIR_PERM_FIX: $_ld_path $_pre→$_post"; end
    if test "$_post" != 700; echo "[ERR] Log dir mode is $_post (expected 700): $_ld_path" >&2; _ry_exit $EXIT_PREFLIGHT; end
end
set --erase _ld_path _prev_mkdir_umask
set -g LOG_FILE "$LOG_DIR/preflight-$TIMESTAMP.jsonl"; set -g INSTALL_HAD_ERRORS false

# ── GLOBAL STATE: BOOT TAINT, TRACKED RESOURCES, AWK FILTERS ──
set -g _RY_BOOT_TAINTED false
set -g _RY_BOOT_CRITICAL_DSTS "/boot/loader/loader.conf" "/etc/kernel/cmdline" "/etc/sdboot-manage.conf" "/etc/mkinitcpio.conf"
set -g _RY_BACKUP_TARGETS "/boot/loader/loader.conf" "/etc/mkinitcpio.conf"; set -g _RY_BACKUP_SUFFIX .ry.bak
set -g _RY_TMPDIR_GLOBS 'ry-sudo-err.*' 'ry-tee-err.*' 'ry-run.*' 'ry-argparse-err.*' 'ry-fstab-tee-err.*' 'ry-fstab-awk-err.*' # TMPDIR sweep globs
set -g _TRACKED_TMPFILES; set -g _SYS_TMP_DIRS; set -g _USR_TMP_DIRS; set -g _RY_PHASE_RESULTS
set -g _RY_DEPLOY_CHANGED_COUNT 0; set -g _RY_DEPLOY_IDEMPOTENT_COUNT 0; set -g _RY_PROFILE_USES_WIFI_BACKEND false
set -g _RY_AWK_EXT4_FILTER '!/^[ \t]*#/ && NF >= 4 && $3 == "ext4" { print $0 }'
set -g _RY_AWK_EXT4_MALFORMED_FILTER '!/^[ \t]*#/ && NF < 4 && $0 ~ /(^|[ \t,])ext4([ \t,]|$)/ { print $0 }'
set -g NM_RESTART_DELAY 3; set -g _PROG_BAR_WIDTH 40

# ── KERNEL / SYSTEMD STATE PROBES ──
function _kconfig_cache --description "Return cached /proc/config.gz lines (lazy-loaded; empty on missing config)"
    if not set -q _KCONFIG_LOADED
        if test -f /proc/config.gz; and command -q zcat
            set -g _KCONFIG_DATA (command zcat /proc/config.gz 2>/dev/null)
        else
            set -g _KCONFIG_DATA
        end
        set -g _KCONFIG_LOADED true
    end
    test (count $_KCONFIG_DATA) -eq 0; and return 0
    printf '%s\n' $_KCONFIG_DATA
end
function _ntsync_state --description "Return: builtin|loaded|loaded_nodev|missing"
    if _kconfig_cache | command grep -q -- '^CONFIG_NTSYNC=y' 2>/dev/null
        printf '%s\n' builtin
    else if test -c /dev/ntsync
        printf '%s\n' loaded
    else if command grep -q -- '^ntsync ' /proc/modules 2>/dev/null
        printf '%s\n' loaded_nodev
    else
        printf '%s\n' missing
    end
    return 0
end
function _resolve_systemd_ver --description "Cache systemd major version into _RY_SYSTEMD_VER"
    set -q _RY_SYSTEMD_VER_TRIED; and return 0
    set -l _v (command systemctl --version 2>/dev/null | command head -n 1 | string match -rg -- '^systemd (\d+)')
    if test -n "$_v"
        set -g _RY_SYSTEMD_VER $_v
    else
        _log "SYSTEMD_VER_PARSE_FAIL: empty result from systemctl --version"
    end
    set -g _RY_SYSTEMD_VER_TRIED true
    return 0
end
function _unit_state --argument-names unit --description "Return LoadState/ActiveState/UnitFileState as 3-line list (fewer on systemctl error)"
    command systemctl show --value --property=LoadState,ActiveState,UnitFileState -- "$unit" 2>/dev/null
end
function _unit_state_padded --argument-names unit --description "Return _unit_state values" # ERR_NO_DATA triple keeps $rec[1..3] in-bounds
    set -l _v (_unit_state "$unit")
    if test (count $_v) -lt 3
        printf '%s\n' ERR_NO_DATA ERR_NO_DATA ERR_NO_DATA
    else
        printf '%s\n' $_v[1] $_v[2] $_v[3]
    end
end

# ── JSONL FOOTER + TMPFILE CLEANUP ──
function _write_footer --argument-names exit_code extra_key --description "Append JSONL footer to LOG_FILE"
    set -q _FOOTER_WRITTEN; and return 0
    set -q LOG_FILE; or return 0
    test -n "$LOG_FILE"; and test -f "$LOG_FILE"; or return 0
    set -g _FOOTER_WRITTEN true; set -l _mode_esc (_json_str "$MODE"); set -l _ts (command date '+%Y-%m-%dT%H:%M:%S%z'); set -l _extra ""
    test -n "$extra_key"; and set _extra ",\""(_json_str "$extra_key")"\":true"
    set -l _gen_fail 0
    set -q VERIFY_GEN_FAIL; and set _gen_fail $VERIFY_GEN_FAIL
    printf '{"ts":"%s","event":"footer","mode":"%s","exit_code":%d,"pass":%d,"fail":%d,"warn":%d,"gen_fail":%d%s}\n' \
        "$_ts" "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" "$_gen_fail" "$_extra" >>"$LOG_FILE" 2>/dev/null
    test "$status" -ne 0; and not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true
end
function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    not set -q _FOOTER_WRITTEN; and _log "CLEANUP_TMPFILES: sweep starting"
    set -l _has_sudo false
    command -q sudo; and sudo -n true 2>/dev/null; and set _has_sudo true
    for dir in $_SYS_TMP_DIRS
        if test "$_has_sudo" = true
            sudo -n find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
        else
            command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
        end
    end
    for dir in $_USR_TMP_DIRS; command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null; end
end
set -g _CLEANUP_DONE false

# ── INSTANCE LOCK: ATOMIC MKDIR + STALE-PID RECLAIM ──
function _acquire_lock_fresh --description "Try fresh atomic-mkdir lock"
    set -l _prev_umask (umask)
    umask 0077
    set -g _RY_LOCK_DIR_OWNED true
    command mkdir -- "$LOCK_DIR" 2>/dev/null
    set -l _mk_rc $status
    umask $_prev_umask
    if test "$_mk_rc" -ne 0
        set --erase _RY_LOCK_DIR_OWNED
        test -d "$LOCK_DIR"; and return 2
        _log "LOCK_MKDIR_FAIL: $LOCK_DIR rc=$_mk_rc"
        echo "[ERR] Cannot create lock dir: $LOCK_DIR (mkdir rc=$_mk_rc)" >&2
        return 1
    end
    set -g _RY_LOCK_MKDIR_OK true
    command chmod -- 700 "$LOCK_DIR" 2>/dev/null
    set -l _pid_tmp (command mktemp -p "$LOCK_DIR" .pid.XXXXXX 2>/dev/null)
    if test -z "$_pid_tmp"; or not printf '%s\n' "$fish_pid" >"$_pid_tmp" 2>/dev/null
        test -n "$_pid_tmp"; and command rm -f -- "$_pid_tmp" 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null
        set --erase _RY_LOCK_DIR_OWNED _RY_LOCK_MKDIR_OK
        _log "LOCK_PIDFILE_WRITE_FAIL: $LOCK_FILE"
        echo "[ERR] Failed to write lock pid file: $LOCK_FILE" >&2
        return 1
    end
    if not command mv -Tf -- "$_pid_tmp" "$LOCK_FILE" 2>/dev/null
        command rm -f -- "$_pid_tmp" 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null
        set --erase _RY_LOCK_DIR_OWNED _RY_LOCK_MKDIR_OK
        _log "LOCK_PIDFILE_INSTALL_FAIL: $LOCK_FILE"
        echo "[ERR] Failed to install lock pid file: $LOCK_FILE" >&2
        return 1
    end
    command chmod -- 600 "$LOCK_FILE" 2>/dev/null
    set -g _RY_HOLDS_LOCK true
    _log "LOCK_ACQUIRED: pid=$fish_pid dir=$LOCK_DIR"
    return 0
end
function _lock_pid_started_after --argument-names pid mtime --description "rc 0 = PID provably started after mtime+2s (recycled); rc 1 = unknown or older (fail-closed)"
    string match -qr '^[1-9]\d*$' -- "$pid"; or return 1
    string match -qr '^\d+$' -- "$mtime"; or return 1
    set -l _stat (command cat -- /proc/$pid/stat 2>/dev/null | string collect)
    test -n "$_stat"; or return 1
    set -l _post (string replace -r '^.*\) ' '' -- "$_stat") # cut after last ') '; comm may embed parens
    set -l _ticks (string split ' ' -- "$_post")[20] # stat field 22 starttime = post-comm index 20
    string match -qr '^\d+$' -- "$_ticks"; or return 1
    set -l _btime (command awk '/^btime /{print $2; exit}' /proc/stat 2>/dev/null)
    string match -qr '^\d+$' -- "$_btime"; or return 1
    set -l _hz (command getconf CLK_TCK 2>/dev/null)
    if not string match -qr '^[1-9]\d*$' -- "$_hz" # getconf absent: recover USER_HZ from CONFIG_HZ
        set -l _cfg_hz (_kconfig_cache | string match -rg -- '^CONFIG_HZ=([1-9][0-9]*)$' | command head -n 1)
        if string match -qr '^[1-9]\d*$' -- "$_cfg_hz"
            set _hz $_cfg_hz; functions -q _log; and _log "LOCK_CLK_TCK_FROM_CONFIG: getconf CLK_TCK unavailable — using CONFIG_HZ=$_hz from /proc/config.gz"
        else
            functions -q _log; and _log "LOCK_CLK_TCK_UNKNOWN: getconf CLK_TCK and CONFIG_HZ both unavailable — cannot compute PID start time; treating as live (fail-closed, refusing reclaim)"
            return 1 # USER_HZ unknown: fail closed
        end
    end
    test (math "floor($_btime + $_ticks / $_hz)") -gt (math "$mtime + 2")
end
function _acquire_lock --description "Acquire instance lock (atomic mkdir; stale-lock reclaim)"
    set -g LOCK_DIR "$_RY_HOME_DIR/.lock"; set -g LOCK_FILE "$LOCK_DIR/pid"
    command mkdir -p -- (command dirname -- "$LOCK_DIR") 2>/dev/null
    _acquire_lock_fresh
    set -l _fresh_rc $status
    test "$_fresh_rc" -eq 0; and return 0
    test "$_fresh_rc" -ne 2; and return 1
    for _reclaim_attempt in 1 2 3 # bounded stale-reclaim
        set -l _stale_pid (command cat -- "$LOCK_FILE" 2>/dev/null | string trim --)
        if not string match -qr '^[1-9]\d*$' -- "$_stale_pid" # empty pidfile: settle then recheck
            command sleep 0.2 </dev/null 2>/dev/null
            set _stale_pid (command cat -- "$LOCK_FILE" 2>/dev/null | string trim --)
        end
        if string match -qr '^[1-9]\d*$' -- "$_stale_pid"
            set -l _pf_mtime (command stat -c '%Y' -- "$LOCK_FILE" 2>/dev/null)
            if command kill -0 "$_stale_pid" 2>/dev/null # kill absent rc 127 -> /proc branch (fail-closed)
                if not _lock_pid_started_after "$_stale_pid" "$_pf_mtime" # provably-newer start = recycled PID
                    _log "LOCK_HELD: pid=$_stale_pid dir=$LOCK_DIR (live instance)"
                    echo "[ERR] Another instance is running (pid=$_stale_pid) — lock: $LOCK_DIR" >&2
                    return 1
                end
                _log "LOCK_PID_RECYCLED: pid=$_stale_pid started after pidfile mtime=$_pf_mtime — reclaiming (attempt=$_reclaim_attempt)"
            else if test -d /proc/"$_stale_pid" # kill -0 EPERM: /proc presence wins
                if not _lock_pid_started_after "$_stale_pid" "$_pf_mtime"
                    _log "LOCK_PEER_UNSIGNALABLE: pid=$_stale_pid alive in /proc — not reclaiming"
                    echo "[ERR] Another instance appears alive (pid=$_stale_pid, unsignalable) — lock: $LOCK_DIR" >&2
                    return 1
                end
                _log "LOCK_PID_RECYCLED: pid=$_stale_pid (unsignalable) started after pidfile mtime=$_pf_mtime — reclaiming (attempt=$_reclaim_attempt)"
            else
                _log "LOCK_STALE_CLAIM: pid=$_stale_pid dir=$LOCK_DIR attempt=$_reclaim_attempt (PID not running, reclaiming)"
            end
        else # corrupt path logs CORRUPT only
            _log "LOCK_PIDFILE_CORRUPT: '$_stale_pid' not a PID after settle — reclaiming (attempt=$_reclaim_attempt)"
        end
        if test -L "$LOCK_DIR"; _log "LOCK_RECLAIM_REFUSED: $LOCK_DIR is a symlink"; echo "[ERR] Lock dir is a symlink — refusing reclaim: $LOCK_DIR" >&2; return 1; end
        set -l _recheck_pid (command cat -- "$LOCK_FILE" 2>/dev/null | string trim --) # re-read right before rm
        if test "$_recheck_pid" != "$_stale_pid"; _log "LOCK_RECLAIM_ABORT: pidfile changed mid-pass ('$_stale_pid' → '$_recheck_pid') — another instance active"; echo "[ERR] Lock pidfile changed mid-reclaim — another instance active: $LOCK_DIR" >&2; return 1; end
        command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
        _acquire_lock_fresh
        set -l _re_rc $status
        test "$_re_rc" -eq 0; and return 0
        test "$_re_rc" -eq 2; or return 1
    end
    _log "LOCK_RECLAIM_EXHAUSTED: dir=$LOCK_DIR attempts=3"
    echo "[ERR] Cannot acquire lock after 3 reclaim attempts: $LOCK_DIR" >&2
    return 1
end

# ── CLEANUP ORCHESTRATION: REVERT → TMPFILES → CHILDREN → GLOBALS ──
function _dc_mki_revert --description "_do_cleanup sub: signal-time mkinitcpio.conf revert"
    set -q _RY_MKI_HAD_ORIG; and test "$_RY_MKI_HAD_ORIG" = true; or return 0
    set -q _RY_MKI_BACKUP_FILE; and test -n "$_RY_MKI_BACKUP_FILE"; or return 0
    set -l _rv_rc 1; set -l _rv_tried false
    if functions -q _mkinitcpio_revert; and command -q sudo; and sudo -n test -f "$_RY_MKI_BACKUP_FILE" 2>/dev/null
        set _rv_tried true
        functions -q _log; and _log "MKINITCPIO_REVERT_SIGNAL: cleanup-time revert triggered (backup=$_RY_MKI_BACKUP_FILE)"
        _mkinitcpio_revert "$_RY_MKI_BACKUP_FILE" 2>/dev/null
        set _rv_rc $status
    else
        functions -q _log; and _log "MKINITCPIO_REVERT_SIGNAL_SKIP: backup unavailable or sudo missing (backup=$_RY_MKI_BACKUP_FILE)"
    end
    if test "$_rv_tried" = true; and test "$_rv_rc" -eq 0
        command -q sudo; and functions -q _rm_tmp; and _rm_tmp "$_RY_MKI_BACKUP_FILE" true
    else # keep /run snapshot for manual restore
        functions -q _untrack_tmpfile; and _untrack_tmpfile "$_RY_MKI_BACKUP_FILE"
        functions -q _log; and _log "MKINITCPIO_SNAPSHOT_PRESERVED: $_RY_MKI_BACKUP_FILE (signal-time revert failed or skipped)"
    end
    set --erase _RY_MKI_BACKUP_FILE _RY_MKI_HAD_ORIG
end
function _dc_sweep_tmpfiles --description "_do_cleanup sub: Remove tracked tmpfiles/dirs"
    _cleanup_tmpfiles
    set -l _stuck_tmpfiles
    for _tf in $_TRACKED_TMPFILES
        if test -d "$_tf"
            command rm -rf --preserve-root -- "$_tf" 2>/dev/null; or set -a _stuck_tmpfiles "$_tf"
        else if test -f "$_tf"
            command rm -f -- "$_tf" 2>/dev/null; or set -a _stuck_tmpfiles "$_tf"
        end
    end
    set -l _has_sudo false
    test (count $_stuck_tmpfiles) -gt 0; and command -q sudo; and sudo -n true 2>/dev/null; and set _has_sudo true
    set -l _esc_roots /run/ry-install # escalation roots = dest parents + /run
    for _d in $SYSTEM_DESTINATIONS; set -a _esc_roots (command dirname -- "$_d"); end
    for _tf in $_stuck_tmpfiles
        if test "$_has_sudo" = true; and contains -- (command dirname -- "$_tf") $_esc_roots
            if sudo -n test -d "$_tf" 2>/dev/null
                sudo -n rm -rf --preserve-root -- "$_tf" 2>/dev/null; or begin
                    functions -q _log; and _log "TMPFILE_STUCK: $_tf (sudo rm -rf failed)"
                end
            else if sudo -n test -f "$_tf" 2>/dev/null
                sudo -n rm -f -- "$_tf" 2>/dev/null; or begin
                    functions -q _log; and _log "TMPFILE_STUCK: $_tf (sudo rm -f failed)"
                end
            end
        else
            functions -q _log; and _log "TMPFILE_STUCK: $_tf (no sudo or outside escalation paths)"
        end
    end
    set --erase _TRACKED_TMPFILES
end
function _dc_sweep_filesystem --description "_do_cleanup sub: Sweep TMPDIR for leftover ry-* tmpfiles"
    functions -q _tmp_dir; or return 0
    set -l _tmpdir (_tmp_dir); set -l _tmp_globs $_RY_TMPDIR_GLOBS
    test (count $_tmp_globs) -gt 0; or return 0
    set -l _find_name_args
    for _g in $_tmp_globs; test -n "$_find_name_args"; and set -a _find_name_args -o; set -a _find_name_args -name "$_g"; end
    command find "$_tmpdir" -xdev -maxdepth 1 \( $_find_name_args \) -type f -uid "$_MY_UID" -delete 2>/dev/null
    for _rd in "$_tmpdir"/ry-run.* # per-dir descent keeps glob metachars literal
        test -d "$_rd"; and command find "$_rd" -xdev -maxdepth 1 -type f -uid "$_MY_UID" -delete 2>/dev/null
    end
    command find "$_tmpdir" -xdev -maxdepth 1 -name 'ry-run.*' -type d -empty -uid "$_MY_UID" -delete 2>/dev/null
end
function _dc_erase_globals --description "_do_cleanup sub: Erase cached globals"
    set --erase _KCONFIG_DATA _KCONFIG_LOADED _RY_ESP_PATH _RY_BOOT_PATH
    set --erase _RY_ESP_TRIED _RY_BOOT_TRIED
    set --erase _RY_SYSTEMD_VER _RY_SYSTEMD_VER_TRIED
    set --erase _RY_BOOT_COUNT _RY_BOOT_ENUM_OK _CPU_PATH
    set --erase _RY_CANON_SYSTEM_DSTS _RY_CANON_USER_DSTS _SYS_TMP_DIRS _USR_TMP_DIRS
    set --erase _RY_PROFILE_USES_WIFI_BACKEND _RY_ESP_FALLBACK
    set --erase _RY_MKI_REVERT_FAILED _RY_PACTREE_MISSING_WARNED _RY_REALPATH_ABSENT_WARNED
    set --erase _RY_RUN_TIMEOUT_WARNED _PROG_CLOCK _RY_HOLDS_LOCK _RY_LOCK_DIR_OWNED _RY_LOCK_MKDIR_OK
    set --erase _RY_DMESG_LINES _RY_DMESG_PREEMPT _RY_DMESG_TSC
    set --erase _RY_PKG_REMOVE_SKIPS _RY_BOOT_TAINTED _RY_PKGS_REMOVED_COUNT _RY_PKG_REMOVE_DBLOCK
    set --erase _RY_PHASE_RESULTS _RY_DEPLOY_CHANGED_COUNT _RY_DEPLOY_IDEMPOTENT_COUNT _RY_BOOT_CRIT_HIT
    set --erase _RY_MTX_PASS _RY_MTX_WARN _RY_MTX_FAIL _RY_MTX_DEFER _RY_MTX_SKIP _RY_MTX_NA
    set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES _RY_SYSCTL_BAD_ENTRIES _RY_FSTAB_EVIDENCE _RY_FSTAB_RESULT
    set --erase _RY_RESOLVED_MANAGED_DST _RY_REGDOM_RESULT _RY_REGDOM_EVIDENCE _RY_SDBOOT_REFUSE_FS _RY_NET_FAIL_EVIDENCE
end
function _dc_release_lock --description "_do_cleanup sub: Release the instance lock (ownership-gated)"
    if begin; set -q _RY_HOLDS_LOCK; or set -q _RY_LOCK_DIR_OWNED; end; and set -q LOCK_DIR; and not test -L "$LOCK_DIR"
        set -l _own false # rm only if lock held or pidfile empty/ours
        if set -q _RY_HOLDS_LOCK
            set _own true
        else if set -q _RY_LOCK_MKDIR_OK # empty pidfile ours only if we created LOCK_DIR
            set -l _lp (command cat -- "$LOCK_FILE" 2>/dev/null | string trim --)
            test -z "$_lp"; or test "$_lp" = "$fish_pid"; and set _own true
        end
        test "$_own" = true; and command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
    end
end
function _dc_kill_children --description "_do_cleanup sub: Reap child PIDs (TERM → bounded grace → KILL)"
    command -q pkill; or return 0
    set -l _have_kids unknown # no children -> skip TERM/grace/KILL
    command -q pgrep; and begin
        test (count (command pgrep -P "$fish_pid" 2>/dev/null)) -gt 0; and set _have_kids yes; or set _have_kids no
    end
    test "$_have_kids" = no; and return 0
    command pkill -TERM -P "$fish_pid" 2>/dev/null
    set -l _grace 5 # 0.1s polls
    test -f /var/lib/pacman/db.lck; and set _grace 100 # pkg txn in flight: up to 10s grace
    for _gi in (seq $_grace)
        command -q pgrep; or begin; command sleep 0.5 </dev/null 2>/dev/null; break; end
        test (count (command pgrep -P "$fish_pid" 2>/dev/null)) -eq 0; and break
        command sleep 0.1 </dev/null 2>/dev/null
    end
    command -q pgrep; and test (count (command pgrep -P "$fish_pid" 2>/dev/null)) -eq 0; and return 0 # zero children confirmed: skip KILL
    command pkill -KILL -P "$fish_pid" 2>/dev/null
end

# ── CLEANUP: MASTER ORCHESTRATOR (_do_cleanup) ──
function _do_cleanup --description "Master cleanup: reap children → revert → tmpfiles → fs sweep → lock release → globals"
    _dc_kill_children # quiesce children first: revert must not race live pacman
    _dc_mki_revert
    _dc_sweep_tmpfiles
    _dc_sweep_filesystem
    _dc_release_lock # Sweeps run while the lock is still held.
    _dc_erase_globals
end

# ── VERIFY COUNTERS + TEARDOWN + SIGNAL/EXIT HANDLERS ──
set -g VERIFY_OK 0; set -g VERIFY_FAIL 0; set -g VERIFY_WARN 0; set -g VERIFY_GEN_FAIL 0
function _teardown --argument-names mode --description "Unified cleanup: progress teardown, footer, resources"
    functions -q _progress_teardown; and _progress_teardown # signals may precede progress module
    set -l _signum 0 # validate argv[2] numeric before footer
    test (count $argv) -ge 2; and string match -qr '^\d+$' -- "$argv[2]"; and set _signum $argv[2]
    switch "$mode"
        case signal
            _write_footer "$_signum" interrupted
            _do_cleanup
        case exit
            _write_footer "$_signum" ""
            _do_cleanup
        case '*'
            _err "_teardown: unknown mode '$mode'"
            return 1
    end
end
function _cleanup --on-signal INT --on-signal TERM --on-signal HUP --on-signal QUIT --on-signal ABRT --description "Signal handler for INT/TERM/HUP/QUIT/ABRT" # 128+N per signal
    test "$_CLEANUP_DONE" = true; and return 0
    set -g _CLEANUP_DONE true; set -l _sig_label SIG$argv[1]
    string match -q 'SIG*' -- "$argv[1]"; and set _sig_label "$argv[1]"
    test -z "$argv[1]"; and set _sig_label exit
    if not set -q _RY_OUTPUT_BROKEN; and test "$MODE" != check # --check stays stderr-silent
        echo "" >&2
        echo "[WARN] Caught $_sig_label - cleaning up..." >&2
    end
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
        case ABRT SIGABRT
            set _sig_exit 134
        case '*'
            functions -q _log; and _log "CLEANUP_UNKNOWN_SIGNAL: argv[1]='$argv[1]' fallback_exit=130"
            set _sig_exit 130
    end
    _teardown signal $_sig_exit
    exit $_sig_exit
end
function _cleanup_pipe --on-signal PIPE --description "Signal handler: mark stderr/stdout broken"
    set -q _RY_OUTPUT_BROKEN; and return 0
    set -g _RY_OUTPUT_BROKEN true
    set -q _RY_HEADER_WRITTEN; or return 0
    _log "SIGPIPE_RECEIVED: stderr/stdout consumer closed; continuing with JSONL log only"
end
function _cleanup_on_exit --on-event fish_exit --description "Exit handler: ensure cleanup runs on fish_exit"
    set -l _exit_status $status
    if set -q _INTENDED_EXIT_CODE
        set _exit_status $_INTENDED_EXIT_CODE
    else if set -q _RY_INSTALL_LAST_EXIT
        set _exit_status $_RY_INSTALL_LAST_EXIT
    end
    test "$_CLEANUP_DONE" = true; and return 0
    _teardown exit $_exit_status
end

# ── EMBEDDED CONFIG: DESTINATIONS (source of truth; _content_ fns + _RY_POST_HOOKS mirror order) ──
set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" \
    "/etc/kernel/cmdline" \
    "/etc/sdboot-manage.conf" \
    "/etc/mkinitcpio.conf" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
    "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf" \
    "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/iw-regdomain" \
    "/etc/bluetooth/main.conf" \
    "/etc/nftables.conf" \
    "/etc/default/cpupower-service.conf" \
    "/etc/sysctl.d/95-ry-overrides.conf" \
    "/etc/udev/rules.d/99-ry-perf.rules" \
    "/etc/modprobe.d/60-ry-mt7925e.conf"
set -g USER_DESTINATIONS "$HOME/.config/environment.d/10-environment.conf" "$HOME/.config/baloofilerc" "$HOME/.config/MangoHud/MangoHud.conf"
set -l _ry_dst_count (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS)
if test "$_ry_dst_count" -ne "$_RY_MANAGED_FILE_COUNT"; echo "[ERR] _RY_MANAGED_FILE_COUNT drift: declared=$_RY_MANAGED_FILE_COUNT computed=$_ry_dst_count" >&2; _ry_exit $EXIT_PREFLIGHT; end
set --erase _ry_dst_count

# ── EMBEDDED DATA: BOOTLOADER KEYS + KERNEL_PARAMS + MKINITCPIO ──
set -g LOADER_DEFAULT "@saved"; set -g LOADER_TIMEOUT 0; set -g LOADER_CONSOLE_MODE keep; set -g LOADER_EDITOR no
set -g SDBOOT_DEFAULT_ENTRY manual; set -g SDBOOT_OVERWRITE yes; set -g SDBOOT_REMOVE_EXISTING yes; set -g SDBOOT_REMOVE_OBSOLETE yes
set -g KERNEL_PARAMS 8250.nr_uarts=0 amd_pstate=active btusb.enable_autosuspend=n clearcpuid=514 fsck.mode=force fsck.repair=yes iommu=pt nowatchdog nvme_core.default_ps_max_latency_us=0 pcie_aspm.policy=performance processor.max_cstate=1 quiet split_lock_detect=off tsc=reliable usbcore.autosuspend=-1 zswap.enabled=0
set -g MKINITCPIO_MODULES amdgpu
set -g MKINITCPIO_HOOKS base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck
set -g MKINITCPIO_COMPRESSION zstd; set -g MKINITCPIO_COMPRESSION_OPTIONS -1 -T0

# ── EMBEDDED DATA: SERVICE KEYS ──
set -g RESOLVED_MDNS no; set -g RESOLVED_LLMNR no; set -g RESOLVED_DOT no; set -g RESOLVED_DNSSEC allow-downgrade
set -g NM_DISPATCHER_LOGLEVELMAX notice # drop info-level dispatcher spam, keep notice+
set -g COUNTRY US
set -g LOGIND_IGNORE_KEYS HandlePowerKey HandlePowerKeyLongPress HandleSuspendKey HandleSuspendKeyLongPress HandleHibernateKey HandleHibernateKeyLongPress HandleRebootKey HandleRebootKeyLongPress
# Wi-Fi PS off: MT7925/mt76 PS in software causes latency spikes
set -g NM_WIFI_BACKEND wpa_supplicant; set -g NM_WIFI_POWERSAVE 2; set -g NM_LOG_LEVEL WARN
set -g CPUPOWER_GOVERNOR powersave
# Bluetooth: power adapter on at service start/resume; reconnect retry for paired sinks
set -g BT_AUTO_ENABLE true; set -g BT_FAST_CONNECTABLE true; set -g BT_RECONNECT_ATTEMPTS 3
set -g GPU_DPM_LEVEL auto # gfx1151 dpm floor; auto avoids pinning SCLK on CPU-bound titles
set -g RY_REMOTE_PLAY_PORTS false # true appends Sunshine/Steam stream ports to nftables input

# ── EMBEDDED DATA: ENV_VARS + SYSCTL_VALUES ──
set -g ENV_VARS "AMD_VULKAN_ICD=RADV" "DXVK_LOG_LEVEL=none" "DXVK_LOG_PATH=none" "MANGOHUD=1" "MESA_SHADER_CACHE_MAX_SIZE=16G" "PROTON_ENABLE_WAYLAND=1" "PROTON_FSR4_RDNA3_UPGRADE=1" "PROTON_LOCAL_SHADER_CACHE=1" "VKD3D_DEBUG=none" "VKD3D_SHADER_DEBUG=none" "WINEDEBUG=-all"
set -g SYSCTL_VALUES \
    "net.core.default_qdisc=fq" \
    "net.core.netdev_budget=600" \
    "net.core.netdev_budget_usecs=5000" \
    "net.ipv4.tcp_congestion_control=bbr" \
    "net.ipv4.tcp_notsent_lowat=16384" \
    "net.ipv4.tcp_slow_start_after_idle=0" \
    "vm.compaction_proactiveness=0" \
    "vm.max_map_count=2147483642" \
    "vm.swappiness=150"

# ── EMBEDDED DATA: PACKAGES (ADD / DEL / VULKAN) ──
set -g PKGS_ADD \
    nvme-cli \
    cachyos-gaming-meta \
    cachyos-gaming-applications \
    lib32-mesa \
    mkinitcpio-firmware \
    fd \
    sd \
    dust \
    procs \
    bottom \
    htop \
    git-delta \
    lm_sensors \
    rtkit \
    realtime-privileges \
    ddcutil \
    nftables
set -g PKGS_DEL plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update kdeconnect
set -g _RY_PKG_REMOVE_SKIPS
set -g EXPECTED_VULKAN_PKGS vulkan-radeon lib32-vulkan-radeon # chwd Vulkan drivers

# ── EMBEDDED DATA: UNITS (MASK / EXPECTED) + THRESHOLDS ──
set -g MASK ananicy-cpp.service power-profiles-daemon.service NetworkManager-wait-online.service ufw.service modemmanager.service sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
set -g EXPECTED_SERVICES fstrim.timer NetworkManager.service cpupower.service nftables.service bluetooth.service # enabled in Phase 4/6
set -g _RY_PKG_MANAGED_SERVICES NetworkManager.service
set -g BOOT_SPACE_CRIT 200; set -g BOOT_SPACE_WARN 500; set -g ROOT_AVAIL_CRIT 2; set -g ROOT_AVAIL_WARN 5 # thresholds: disk, CPU
set -g EXPECTED_CPU_MATCH "Ryzen AI Max"

# ── RUNTIME INIT: ROOT UUID + INVARIANT VALIDATION + CACHE PRECOMPUTE ──
function _ir_resolve_root_uuid --description "Cache root UUID into _ROOT_UUID"
    set -g _ROOT_UUID (command findmnt -no UUID / 2>/dev/null)
    set -l _reason "findmnt failed"
    if test -n "$_ROOT_UUID"; and not string match -qr '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' -- "$_ROOT_UUID"
        set _reason "invalid UUID shape (got: $_ROOT_UUID)"
        set --erase _ROOT_UUID
    end
    test -n "$_ROOT_UUID"; and return 0
    switch "$MODE"
        case check
            _log "ROOT_UUID_UNAVAILABLE: $_reason (silent for --check)"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        case install
            _err_loud "Cannot detect root UUID ($_reason) — /etc/kernel/cmdline cannot be generated"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        case install-file # Only cmdline embeds root=UUID
            set -l _cmdline_canon (command realpath -m -- /etc/kernel/cmdline 2>/dev/null)
            if test "$INSTALL_FILE_TARGET" = /etc/kernel/cmdline; or begin; test -n "$_cmdline_canon"; and test "$INSTALL_FILE_TARGET" = "$_cmdline_canon"; end
                _err_loud "Cannot detect root UUID ($_reason) — /etc/kernel/cmdline cannot be generated"
                _pre_dispatch_exit $EXIT_PREFLIGHT
            end
            _warn "Cannot detect root UUID ($_reason) — only /etc/kernel/cmdline embeds it; continuing for --install-file $INSTALL_FILE_TARGET"
            _log "ROOT_UUID_UNAVAILABLE: $_reason — install-file target=$INSTALL_FILE_TARGET does not embed root=UUID; continuing"
        case verify
            _warn "Cannot detect root UUID ($_reason) — exact root=UUID match in /etc/kernel/cmdline skipped; other checks continue"
            _log "ROOT_UUID_UNAVAILABLE: $_reason — verify continues with generic root=UUID presence check"
        case '*'
            _log "ROOT_UUID_UNAVAILABLE: mode=$MODE reason=$_reason — non-fatal for this mode"
    end
end
function _ir_precompute_caches --description "Precompute tmpdir / WiFi-backend / canonical-dst caches" # canon list index-aligned to source
    set -g _SYS_TMP_DIRS
    for _d in $SYSTEM_DESTINATIONS; set -l _dir (command dirname -- "$_d"); contains -- "$_dir" $_SYS_TMP_DIRS; or set -a _SYS_TMP_DIRS "$_dir"; end
    set -g _USR_TMP_DIRS
    for _d in $USER_DESTINATIONS; set -l _dir (command dirname -- "$_d"); contains -- "$_dir" $_USR_TMP_DIRS; or set -a _USR_TMP_DIRS "$_dir"; end
    set -g _RY_PROFILE_USES_WIFI_BACKEND false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_d"; set -g _RY_PROFILE_USES_WIFI_BACKEND true; break; end
    end
    set -g _RY_CANON_SYSTEM_DSTS
    for _d in $SYSTEM_DESTINATIONS; set -a _RY_CANON_SYSTEM_DSTS (command realpath -m -- "$_d" 2>/dev/null; or echo "$_d"); end
    set -g _RY_CANON_USER_DSTS
    for _d in $USER_DESTINATIONS; set -a _RY_CANON_USER_DSTS (command realpath -m -- "$_d" 2>/dev/null; or echo "$_d"); end
    set -l _sys_in (count $SYSTEM_DESTINATIONS); set -l _sys_out (count $_RY_CANON_SYSTEM_DSTS)
    if test "$_sys_in" -ne "$_sys_out"; _err_loud "BUG: _RY_CANON_SYSTEM_DSTS count drift: in=$_sys_in out=$_sys_out"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    set -l _usr_in (count $USER_DESTINATIONS); set -l _usr_out (count $_RY_CANON_USER_DSTS)
    if test "$_usr_in" -ne "$_usr_out"; _err_loud "BUG: _RY_CANON_USER_DSTS count drift: in=$_usr_in out=$_usr_out"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
end
function _ir_validate_counts --description "Refuse to deploy when array counts drift from expected"
    set -l _expect \
        KERNEL_PARAMS:16 \
        MKINITCPIO_HOOKS:11 \
        MKINITCPIO_MODULES:1 \
        LOGIND_IGNORE_KEYS:8 \
        ENV_VARS:11 \
        SYSCTL_VALUES:9 \
        PKGS_ADD:17 \
        PKGS_DEL:9 \
        MASK:10 \
        EXPECTED_VULKAN_PKGS:2 \
        EXPECTED_SERVICES:5 \
        _RY_PKG_MANAGED_SERVICES:1 \
        _RY_POST_HOOKS:18 \
        _RY_BOOT_CRITICAL_DSTS:4 \
        _RY_PHASE_NAMES:6 \
        _RY_BACKUP_TARGETS:2 \
        _RY_TMPDIR_GLOBS:6 \
        SYSTEM_DESTINATIONS:15 \
        USER_DESTINATIONS:3
    for _kv in $_expect
        set -l _parts (string split -m1 ':' -- "$_kv"); set -l _name $_parts[1]; set -l _want $_parts[2]; set -l _got (count $$_name)
        if test "$_got" -ne "$_want"; _err_loud "$_name count drift: got=$_got expected=$_want — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
function _ir_validate_keys --description "Refuse to deploy when an embedded scalar key holds an out-of-domain value (empty/malformed would corrupt rendered configs)"
    for _k in BT_AUTO_ENABLE BT_FAST_CONNECTABLE RY_REMOTE_PLAY_PORTS
        if not contains -- "$$_k" true false; _err_loud "$_k must be true|false (got: '$$_k') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _k in SDBOOT_OVERWRITE SDBOOT_REMOVE_EXISTING SDBOOT_REMOVE_OBSOLETE RESOLVED_MDNS RESOLVED_LLMNR RESOLVED_DOT
        if not contains -- "$$_k" yes no; _err_loud "$_k must be yes|no (got: '$$_k') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _k in LOADER_TIMEOUT NM_WIFI_POWERSAVE BT_RECONNECT_ATTEMPTS
        if not string match -qr '^\d+$' -- "$$_k"; _err_loud "$_k must be a non-negative integer (got: '$$_k') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    if not string match -qr '^[A-Z]{2}$' -- "$COUNTRY"; _err_loud "COUNTRY must be an ISO-3166 alpha-2 code (got: '$COUNTRY') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    for _k in LOADER_DEFAULT LOADER_CONSOLE_MODE LOADER_EDITOR SDBOOT_DEFAULT_ENTRY RESOLVED_DNSSEC NM_WIFI_BACKEND NM_LOG_LEVEL CPUPOWER_GOVERNOR GPU_DPM_LEVEL NM_DISPATCHER_LOGLEVELMAX MKINITCPIO_COMPRESSION
        if test -z "$$_k"; _err_loud "$_k must be non-empty — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
function _ir_validate_kernel_floor --description "Hard preflight: refuse deploy when running kernel < KERNEL_MIN (override: RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1)"
    set -l _kr (command uname -r 2>/dev/null)
    set -l _kver (string match -rg -- '^([0-9]+\.[0-9]+)' "$_kr") # strip -arch1-1/-cachyos suffix to MAJOR.MINOR
    if test -z "$_kver"
        if test "$RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK" = 1 # fail-closed: unreadable release requires override
            _warn_loud "Kernel floor (override): release unreadable from uname -r ('$_kr') — proceeding"
            _log "KERNEL_FLOOR_UNREADABLE_OVERRIDE: uname -r='$_kr'"
        else
            _err_loud "Kernel floor: release unreadable from uname -r ('$_kr') — refusing to deploy"
            _err_loud_cont "  RTL8127 suspend/shutdown hang fix + r8169 support land only >=$KERNEL_MIN; deploying below risks suspend lockup."
            _err_loud_cont "  Override (at your risk): RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1 ./ry-install.fish"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        end
        return 0
    end
    set -l _cur_parts (string split '.' -- "$_kver"); set -l _min_parts (string split '.' -- "$KERNEL_MIN")
    if test "$_cur_parts[1]" -lt "$_min_parts[1]"; or begin; test "$_cur_parts[1]" -eq "$_min_parts[1]"; and test "$_cur_parts[2]" -lt "$_min_parts[2]"; end
        _err_loud "Kernel floor: running $_kver, profile $PROFILE_NAME requires >=$KERNEL_MIN — refusing to deploy"
        _err_loud_cont "  RTL8127 suspend/shutdown hang fix (ae1737e7339b) + r8169 support are present only at/above $KERNEL_MIN."
        _err_loud_cont "  Override (at your risk): RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1 ./ry-install.fish"
        _pre_dispatch_exit $EXIT_PREFLIGHT
    end
end

# ── RUNTIME INIT: ORCHESTRATOR (_init_runtime) ──
function _init_runtime --description "Cache root UUID + validate config + precompute caches"
    _ir_resolve_root_uuid
    if set -q EXPECTED_CPU_MATCH; and test -n "$EXPECTED_CPU_MATCH"
        set -l _cpu_model (string match -rg -- '^model name\s*:\s*(.*)$' < /proc/cpuinfo 2>/dev/null)[1]
        if test -z "$_cpu_model"
            if test "$RY_INSTALL_SKIP_HARDWARE_CHECK" = 1 # fail-closed: empty model requires override
                _warn_loud "Hardware check (override): CPU model unreadable from /proc/cpuinfo — proceeding"
                _log "HARDWARE_MODEL_UNREADABLE_OVERRIDE: /proc/cpuinfo missing 'model name'"
            else
                _err_loud "Hardware check: CPU model unreadable from /proc/cpuinfo (no 'model name' field) — refusing to deploy"
                _err_loud_cont "  Deploying gfx1151/Strix Halo defaults without CPU validation risks incorrect kernel cmdline + initramfs MODULES."
                _err_loud_cont "  Override (at your risk): RY_INSTALL_SKIP_HARDWARE_CHECK=1 ./ry-install.fish"
                _pre_dispatch_exit $EXIT_PREFLIGHT
            end
        else if not string match -q -i -- "*$EXPECTED_CPU_MATCH*" "$_cpu_model"
            if test "$RY_INSTALL_SKIP_HARDWARE_CHECK" = 1
                _warn_loud "Hardware mismatch (override): expected $EXPECTED_CPU_MATCH, detected: $_cpu_model"
                _log "HARDWARE_MISMATCH_OVERRIDE: expected=$EXPECTED_CPU_MATCH detected=$_cpu_model"
            else
                _err_loud "Hardware mismatch: profile $PROFILE_NAME expects $EXPECTED_CPU_MATCH, detected: $_cpu_model"
                _err_loud_cont "  Deploying gfx1151/Strix Halo defaults on non-matching CPU would set incorrect kernel cmdline + initramfs MODULES."
                _err_loud_cont "  Override (at your risk): RY_INSTALL_SKIP_HARDWARE_CHECK=1 ./ry-install.fish"
                _pre_dispatch_exit $EXIT_PREFLIGHT
            end
        end
    end
    _ir_validate_kernel_floor # hard preflight kernel floor (>= KERNEL_MIN)
    _ir_validate_counts
    _ir_validate_keys
    _ir_validate_post_hooks
    for _bt in $_RY_BACKUP_TARGETS; if string match -q '*/sysctl.d/*' -- "$_bt"; _err_loud "_RY_BACKUP_TARGETS member '$_bt' uses a side-effecting content generator — _awf_postwrite_verify_restore re-run would mutate run state; refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end; end
    _ir_precompute_caches
    set -l _kp_metachar_re '[\s"`$;\\\\&|<>(){}*?\'~!#]' # literal ' splits/rejoins the class; edit with care
    for _kp in $KERNEL_PARAMS
        if string match -qr -- "$_kp_metachar_re" "$_kp"
            _err_loud "KERNEL_PARAMS member contains whitespace, quote, or shell metachar: '$_kp' — refuse to deploy (would corrupt cmdline / LINUX_OPTIONS)"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        end
    end
    for _pn in $PKGS_ADD $PKGS_DEL
        if string match -q -- '-*' "$_pn"; _err_loud "Package name starts with dash: '$_pn' — pacman would parse as flag, refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end

# ── CONTENT GENERATORS (via _ry_get_file_content) ──
function _content__boot_loader_loader.conf --description "Generate content for /boot/loader/loader.conf"
    printf '%s\n' "# systemd-boot loader configuration" "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"
end
function _content__etc_kernel_cmdline --description "Generate content for /etc/kernel/cmdline"
    test -z "$_ROOT_UUID"; and return $EXIT_GEN_NOUUID
    printf '%s %s\n' "rw root=UUID=$_ROOT_UUID" (string join -- " " $KERNEL_PARAMS)
end
function _content__etc_sdboot-manage.conf --description "Generate content for /etc/sdboot-manage.conf"
    printf '%s\n' \
        "# sdboot-manage configuration — changes require: sudo sdboot-manage gen && sudo sdboot-manage update" \
        "LINUX_OPTIONS=\""(string join -- " " $KERNEL_PARAMS)"\"" \
        "LINUX_FALLBACK_OPTIONS=\"quiet\"" \
        "DEFAULT_ENTRY=\"$SDBOOT_DEFAULT_ENTRY\"" \
        "REMOVE_EXISTING=\"$SDBOOT_REMOVE_EXISTING\"" \
        "OVERWRITE_EXISTING=\"$SDBOOT_OVERWRITE\"" \
        "REMOVE_OBSOLETE=\"$SDBOOT_REMOVE_OBSOLETE\""
end
function _content__etc_mkinitcpio.conf --description "Generate content for /etc/mkinitcpio.conf"
    printf '%s\n' \
        "# mkinitcpio configuration — changes require: sudo mkinitcpio -P && sudo sdboot-manage update" \
        "MODULES=("(string join -- " " $MKINITCPIO_MODULES)")" \
        "BINARIES=()" \
        "FILES=()" \
        "HOOKS=("(string join -- " " $MKINITCPIO_HOOKS)")" \
        "COMPRESSION=\"$MKINITCPIO_COMPRESSION\""
    if set -q MKINITCPIO_COMPRESSION_OPTIONS; and test -n "$MKINITCPIO_COMPRESSION_OPTIONS"; printf '%s\n' "COMPRESSION_OPTIONS=($MKINITCPIO_COMPRESSION_OPTIONS)"; end
end
function _content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf --description "Generate content for systemd-resolved drop-in"
    printf '%s\n' "# systemd-resolved configuration (plaintext DNS, mDNS/LLMNR off — deliberate divergence from CachyOS DoH default)" "[Resolve]" "MulticastDNS=$RESOLVED_MDNS" "LLMNR=$RESOLVED_LLMNR" "DNSOverTLS=$RESOLVED_DOT" "DNSSEC=$RESOLVED_DNSSEC"
end
function _content__etc_systemd_logind.conf.d_99-cachyos-logind.conf --description "Generate content for systemd-logind drop-in"
    printf '%s\n' "# systemd-logind configuration - desktop power handling"
    printf '%s\n' "[Login]"
    for key in $LOGIND_IGNORE_KEYS
        printf '%s\n' "$key=ignore"
    end
end
function _content__etc_systemd_system_NetworkManager-dispatcher.service.d_logging.conf --description "Generate content for NetworkManager-dispatcher logging drop-in (journal noise suppression)"
    printf '%s\n' "# nm-dispatcher logs via journald (not stdout), so StandardError=null is ineffective; LogLevelMax drops routine info-level lines, keeps notice+" "[Service]" "LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX"
end
function _content__etc_NetworkManager_conf.d_99-cachyos-nm.conf --description "Generate content for NetworkManager drop-in (wifi.backend from NM_WIFI_BACKEND)"
    printf '%s\n' "# NetworkManager configuration - $NM_WIFI_BACKEND backend" "[device]" "wifi.backend=$NM_WIFI_BACKEND" "" "[connection]" "wifi.powersave=$NM_WIFI_POWERSAVE" "" "[logging]" "level=$NM_LOG_LEVEL"
end
function _content__etc_iw-regdomain --description "Generate content for /etc/iw-regdomain (CachyOS regdomain input)"
    printf '%s\n' "# ry-install: wireless regulatory domain (managed file, do not edit by hand)" "COUNTRY=$COUNTRY"
end
function _content__etc_bluetooth_main.conf --description "Generate content for /etc/bluetooth/main.conf (adapter auto-power-on + paired-sink reconnect)"
    printf '%s\n' "# ry-install: BlueZ daemon config (managed file, do not edit by hand)" "[General]" "FastConnectable=$BT_FAST_CONNECTABLE" "" "[Policy]" "AutoEnable=$BT_AUTO_ENABLE" "ReconnectAttempts=$BT_RECONNECT_ATTEMPTS"
end
function _content__etc_nftables.conf --description "Generate content for nftables default-deny-inbound ruleset"
    printf '%s\n' \
        "#!/usr/bin/nft -f" \
        "# ry-install: minimal default-deny-inbound (ufw masked). No inbound ports open by default — add them below." \
        "flush ruleset" \
        "table inet filter {" \
        "    chain input {" \
        "        type filter hook input priority filter; policy drop;" \
        "        ct state established,related accept" \
        "        iif \"lo\" accept" \
        "        ct state invalid drop" \
        "        ip6 nexthdr ipv6-icmp icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert, nd-router-solicit, echo-request, packet-too-big, time-exceeded, parameter-problem } accept" \
        "        # IPv4: inbound echo-request (ping) intentionally NOT accepted; IPv6 echo-request is, since ICMPv6 is load-bearing for NDP/PMTUD" \
        "        icmp type { echo-reply, destination-unreachable, time-exceeded, parameter-problem } accept"
    if test "$RY_REMOTE_PLAY_PORTS" = true # gated: Sunshine/Moonlight + Steam Remote Play inbound stream ports
        printf '%s\n' \
            "        # ry-install: remote-play inbound (RY_REMOTE_PLAY_PORTS=true)" \
            "        tcp dport { 47984, 47989, 48010, 27036 } accept" \
            "        udp dport { 47998-48010, 27031-27036 } accept"
    end
    printf '%s\n' \
        "    }" \
        "    chain forward { type filter hook forward priority filter; policy drop; }" \
        "    chain output { type filter hook output priority filter; policy accept; }" \
        "}"
end
function _content__etc_default_cpupower-service.conf --description "Generate content for cpupower-service.conf"
    printf '%s\n' "# cpupower-service.conf — sourced by /usr/lib/systemd/scripts/cpupower (cpupower.service)" "GOVERNOR='$CPUPOWER_GOVERNOR'"
end
function _content__etc_sysctl.d_95-ry-overrides.conf --description "Generate content for sysctl drop-in"
    printf '%s\n' "# ry-install sysctl tunables (priority 95 — loaded after CachyOS vendor 70-cachyos-settings.conf)"
    set -l _printed 0; set -g _RY_SYSCTL_BAD_ENTRIES
    for entry in $SYSCTL_VALUES
        if not string match -qr '^\s*[A-Za-z0-9._-]+\s*=\s*\S' -- "$entry"; set -ga _RY_SYSCTL_BAD_ENTRIES "$entry"; functions -q _log; and _log "SYSCTL_SKIP_MALFORMED: '$entry' (require key=value, key charset [A-Za-z0-9._-])"; continue; end
        set -l parts (string split -m1 '=' -- "$entry"); set -l key (string trim -- "$parts[1]"); set -l val (string trim -- "$parts[2]")
        printf '%s = %s\n' "$key" "$val"
        set _printed (math $_printed + 1)
    end
    if test "$_printed" -ne (count $SYSCTL_VALUES); functions -q _log; and _log "SYSCTL_COUNT_MISMATCH: printed=$_printed expected="(count $SYSCTL_VALUES); return $EXIT_GEN_SYSCTL; end
end
function _content__etc_udev_rules.d_99-ry-perf.rules --description "Generate content for combined udev perf rules (NVMe scheduler none + AMD P-State EPP balance_performance + gfx1151 GPU clock-floor)"
    printf '%s\n' \
        "# ry-install: udev performance rules (managed file, do not edit by hand)" \
        "# NVMe I/O scheduler none (peak IOPS/lowest tail latency on NVMe; deliberate divergence from CachyOS kyber default)" \
        'ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="none"' \
        "# AMD P-State EPP balance_performance (perf-leaning hint to CPPC firmware; named profile, not raw 0x0)" \
        'ACTION=="add|change", SUBSYSTEM=="cpu", DEVPATH=="*/cpufreq", ATTR{cpufreq/energy_performance_preference}="balance_performance"' \
        "# GPU performance level (gfx1151 clock-floor; optional)" \
        'ACTION=="add", KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="'$GPU_DPM_LEVEL'"'
end
function _content__etc_modprobe.d_60-ry-mt7925e.conf --description "Generate content for /etc/modprobe.d/60-ry-mt7925e.conf (disable PCIe ASPM on MT7925; symptomatic reserve fix)"
    printf '%s\n' \
        "# 60-ry-mt7925e.conf - disable PCIe ASPM on MT7925 (coredump/BT-reconnect/assoc-fail mitigation; symptomatic, drop if upstream resolves)" \
        "options mt7925e disable_aspm=1"
end
function _content_HOME_.config_environment.d_10-environment.conf --description "Generate content for ~/.config/environment.d/10-environment.conf"
    printf '%s\n' "# Environment variables for systemd user services and graphical sessions — loaded by systemd --user (KDE Plasma, Flatpak, D-Bus activated apps)"
    for var in $ENV_VARS; printf '%s\n' "$var"; end
end
function _content_HOME_.config_baloofilerc --description "Generate content for ~/.config/baloofilerc (KDE Baloo file indexing disabled)"
    printf '%s\n' "# ry-install: KDE Baloo file indexing disabled (managed file, do not edit by hand)" "[Basic Settings]" "Indexing-Enabled=false"
end
function _content_HOME_.config_MangoHud_MangoHud.conf --description "Generate content for ~/.config/MangoHud/MangoHud.conf (readout-only HUD; Radeon 8060S / gfx1151)"
    printf '%s\n' \
        "# ry-install: MangoHud readout-only HUD (managed file, do not edit by hand)" \
        "horizontal" \
        "legacy_layout=0" \
        "position=top-left" \
        "toggle_hud=Shift_R+F12" \
        "fps" \
        "frametime" \
        "frame_timing" \
        "gpu_stats" \
        "gpu_core_clock" \
        "gpu_temp" \
        "gpu_power" \
        "cpu_stats" \
        "# cpu_temp" \
        "cpu_mhz" \
        "vram" \
        "ram" \
        "font_size=20" \
        "text_outline" \
        "background_alpha=0.4"
end

# ── CONTENT DISPATCH (_ry_get_file_content; fn name derived via _content_fn_for) ──
function _content_fn_for --argument-names dst --description "Resolve the _content_ generator function name for a destination"
    echo "_content_"(_tmpfile_key "$dst")
end
function _ry_get_file_content --argument-names dst --description "Generate expected content for a destination (dispatcher)"
    set -l fn (_content_fn_for "$dst")
    functions -q $fn; or return $EXIT_GEN_NOFN
    $fn
end

# ── SUDO CREDENTIAL CACHE + COMMAND ESCALATION ──
function _ensure_sudo_cached --description "Cache sudo credential once before repeated sudo -n calls"
    if not command -q sudo; _err "sudo credential cache failed: sudo not found"; return 1; end
    set -l _sudo_err (_mktemp_or_null -p (_tmp_dir) ry-sudo-err.XXXXXX)
    _track_tmpfile "$_sudo_err"
    sudo -n -v 2>"$_sudo_err"
    set -l _rc $status
    if test "$_rc" -ne 0
        if isatty 0; and isatty 2
            sudo -v 2>"$_sudo_err" # truncate stale stderr before retry
            set _rc $status
        else
            _err "sudo credential required but stdin/stderr is not a TTY — pre-cache via 'sudo -v' before running"
            _log "SUDO_CACHE_NONINTERACTIVE: stdin or stderr is not a tty — refusing interactive sudo -v"
        end
    end
    if test "$_rc" -ne 0
        set -l _reason (command head -n 1 -- "$_sudo_err" 2>/dev/null)
        _rm_tmp "$_sudo_err" false
        _log "SUDO_CACHE_FAIL: $_reason"
        if test -n "$_reason"
            _err "sudo credential cache failed: $_reason"
        else
            _err "sudo credential cache failed"
        end
        return 1
    end
    _rm_tmp "$_sudo_err" false
    return 0
end
function _as --argument-names use_sudo --description "Prefix command with sudo or command based on use_sudo flag"
    if test (count $argv) -lt 2; _log "BUG: _as called without command (argv=$argv)"; return $EXIT_AS_MISUSE; end
    if test "$use_sudo" != true; and test "$use_sudo" != false; _log "BUG: _as called with non-bool use_sudo='$use_sudo' (argv=$argv)"; return $EXIT_AS_MISUSE; end
    if test "$use_sudo" = true
        sudo -n -- $argv[2..-1]
    else
        command $argv[2..-1]
    end
end

# ── TMPFILE TRACKING + KEY DERIVATION ──
function _tmpfile_key --argument-names path --description "Generate filename key from destination path"
    set -l p $path
    set -l _hlen (string length -- "$HOME") # literal HOME-prefix match
    if test "$p" = "$HOME"
        set p HOME
    else if test (string sub -l (math $_hlen + 1) -- "$p") = "$HOME/"
        set p "HOME"(string sub -s (math $_hlen + 1) -- "$p")
    end
    string replace -a / _ -- "$p"
end
function _untrack_tmpfile --argument-names path --description "Remove a single literal path from _TRACKED_TMPFILES"
    set -l _new
    for _tf in $_TRACKED_TMPFILES; test "$_tf" = "$path"; and continue; set -a _new "$_tf"; end
    if test (count $_new) -gt 0
        set -g _TRACKED_TMPFILES $_new
    else
        set --erase _TRACKED_TMPFILES
    end
end
function _rm_tmp --argument-names path use_sudo --description "Sudo-aware tmpfile/dir delete + untrack"
    test -n "$path"; or return 0
    test "$path" = /dev/null; and return 0
    set -l _rm_rc; set -l _is_dir false
    if test "$use_sudo" = true
        sudo -n test -d "$path" 2>/dev/null; and set _is_dir true
        if test "$_is_dir" = true
            sudo -n rm -rf --preserve-root -- "$path" 2>/dev/null
        else
            sudo -n rm -f -- "$path" 2>/dev/null
        end
        set _rm_rc $status
    else
        test -d "$path"; and set _is_dir true
        if test "$_is_dir" = true
            command rm -rf --preserve-root -- "$path" 2>/dev/null
        else
            command rm -f -- "$path" 2>/dev/null
        end
        set _rm_rc $status
    end
    set -l _gone false
    test "$use_sudo" != true; and not test -e "$path"; and set _gone true
    if test "$_rm_rc" -eq 0; or test "$_gone" = true # sudo path untracks only on rm success
        _untrack_tmpfile "$path"
    else
        functions -q _log; and _log "RM_TMP_DEFER: path=$path use_sudo=$use_sudo is_dir=$_is_dir rc=$_rm_rc — left tracked for cleanup retry"
    end
end
function _track_tmpfile --argument-names path --description "Track a tmpfile/dir in _TRACKED_TMPFILES"
    test -n "$path"; or return 0
    test "$path" = /dev/null; and return 0
    set -ga _TRACKED_TMPFILES "$path"
end
function _mktemp_or_null --description "mktemp wrapper; emits path on stdout, /dev/null sentinel on failure"
    set -l _tf (command mktemp $argv 2>/dev/null)
    if test -z "$_tf"; echo /dev/null; functions -q _log; and _log "MKTEMP_OR_NULL_FAIL: args='$argv' — falling back to /dev/null sentinel"; return 0; end
    echo "$_tf"
    return 0
end
function _tmp_dir --description "Return \$TMPDIR if set+exists, else /tmp"
    if set -q TMPDIR; and test -n "$TMPDIR"; and test -d "$TMPDIR"
        printf '%s' "$TMPDIR"
    else
        printf '%s' /tmp
    end
end

# ── FILESYSTEM PROBES (symlink, system-dst, byte read) ──
function _is_symlink --argument-names path use_sudo --description "Sudo-aware test -L (rc 0/1/2 = symlink/not/sudo-lapse)"
    if test "$use_sudo" = true
        sudo -n true 2>/dev/null; or return 2
        sudo -n test -L "$path" 2>/dev/null
    else
        test -L "$path"
    end
end
function _is_system_dst --argument-names dst --description "True if dst is a system path (requires sudo to read)"
    string match -q '/etc/*' -- "$dst"; or string match -q '/boot/*' -- "$dst"
end
function _installed_bytes --argument-names dst --description "Raw bytes of installed file (rc: 0=ok 1=fail 2=sudo-lapse)" # tri-state rc 0/1/2: drift vs sudo-lapse
    set -l _bytes
    if _is_system_dst "$dst"
        sudo -n true 2>/dev/null; or return 2
        sudo -n test -r "$dst" 2>/dev/null; or return 1
        set _bytes (sudo -n cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines --allow-empty)
        set -l _ps $pipestatus
        if test "$_ps[1]" -ne 0; sudo -n true 2>/dev/null; or return 2; return 1; end
    else
        test -r "$dst"; or return 1
        set _bytes (command cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines --allow-empty)
        set -l _ps $pipestatus
        test "$_ps[1]" -eq 0; or return 1
    end
    printf '%s' "$_bytes" # bare printf; pipe injects newline
    return 0
end

# ── JSON ESCAPE ──
function _json_str --description "Escape a string for safe JSON embedding (RFC 8259 mandatory + DEL)"
    set -l s $argv[1]
    if not string match -qr -- '[\x00-\x1f"\x5c\x7f]' "$s"; printf '%s' "$s"; return 0; end # fast path: no escape needed (\x5c = backslash)
    set s (string replace -ar -- '\x5c' '\x5c\x5c' "$s" | string collect) # backslash first; \x5c literals avoid grammar desync
    set s (string replace -ar -- '"' '\\\\"' "$s" | string collect)
    set s (string replace -ar -- '\n' '\\\\n' "$s" | string collect)
    set s (string replace -ar -- '\r' '\\\\r' "$s" | string collect)
    set s (string replace -ar -- '\t' '\\\\t' "$s" | string collect)
    set s (string replace -ar -- '\x08' '\\\\b' "$s" | string collect)
    set s (string replace -ar -- '\f' '\\\\f' "$s" | string collect)
    for _hex in 01 02 03 04 05 06 07 0b 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 7f; set s (string replace -ar -- '\x'$_hex '\\\\u00'$_hex "$s" | string collect); end # NUL omitted: fish strings cannot carry NUL
    printf '%s' "$s"
    return 0
end

# ── LOGGING + MESSAGING EMITTERS (JSONL + LEVELED STDERR) ──
function _log_section --argument-names name --description "Emit a section boundary marker line via _log"; _log "=== $name ==="; end
function _log --description "Append a timestamped JSONL line to LOG_FILE"
    set -q _RY_LOG_WRITE_FAIL; and test "$_RY_LOG_WRITE_FAIL" = true; and return 0
    test -n "$LOG_FILE"; or return 0 # skip when LOG_FILE unset
    set -q _RY_LOG_SUPPRESS_CREATE; and test "$_RY_LOG_SUPPRESS_CREATE" = true; and not test -f "$LOG_FILE"; and return 0 # skip lazy-create post-cleanup
    if not test -f "$LOG_FILE"
        set -l _prev_umask (umask)
        umask 0177
        command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
        set -l _create_rc $status
        umask $_prev_umask
        if test "$_create_rc" -ne 0; not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true; return 0; end
    end
    set -l _ts (command date '+%Y-%m-%dT%H:%M:%S%z'); set -l raw (string join -- " " $argv); set -l data (_json_str "$raw")
    printf '{"ts":"%s","event":"log","data":"%s"}\n' "$_ts" "$data" >>"$LOG_FILE" 2>/dev/null
    set -l _write_rc $status
    test "$_write_rc" -eq 0; and not set -q _RY_LOG_WRITTEN; and set -g _RY_LOG_WRITTEN true
    if test "$_write_rc" -ne 0; and not set -q _RY_LOG_WRITE_FAIL; set -g _RY_LOG_WRITE_FAIL true; end
end
function _msg_print --argument-names level --description "Internal: leveled message to stderr"
    set -l _force false
    set -l _msg_start 2 # _msg_start indexes msg in argv
    if test "$level" = --force; set _force true; set level $argv[2]; set _msg_start 3; end
    set -l msg (string join -- " " $argv[$_msg_start..])
    test -z "$msg"; and return 0
    if test "$_force" = false; test "$QUIET" = false; or return 0; end
    set -q _RY_OUTPUT_BROKEN; and return 0
    if test "$_RY_NO_COLOR" = true; or not isatty 2; printf '[%s] %s\n' "$level" "$msg" >&2; return 0; end
    set -l _color normal
    switch "$level"
        case FAIL ERR
            set _color red
        case WARN
            set _color yellow
        case OK
            set _color green
        case INFO
            set _color blue
    end
    begin
        set_color $_color
        printf '[%s]' "$level"
        set_color normal
        printf ' %s\n' "$msg"
    end >&2
end
function _msg --argument-names level --description "Format and print a leveled status message"
    set -l msg (string join -- " " $argv[2..-1])
    test -z "$msg"; and return 0
    _log "$level: $msg"
    switch "$level"
        case OK
            set -g VERIFY_OK (math $VERIFY_OK + 1)
        case FAIL ERR
            set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
        case WARN
            set -g VERIFY_WARN (math $VERIFY_WARN + 1)
    end
    _msg_print $argv
end
function _msg_nocount --argument-names level --description "Like _msg but skips VERIFY_* counter bump"
    set -l msg (string join -- " " $argv[2..-1])
    test -z "$msg"; and return 0
    _log "$level: $msg"
    _msg_print $argv
end
function _ok --description "Emit OK-level message and increment VERIFY_OK"; _msg OK $argv; return 0; end # always return 0 (callers chain via 'and')
function _fail --description "Emit FAIL-level message and increment VERIFY_FAIL"; _msg FAIL $argv; return 0; end
function _fail_no_count --description "Emit FAIL-level message without incrementing VERIFY_FAIL"; _msg_nocount FAIL $argv; return 0; end
function _info --description "Emit INFO-level message (no counter)"; _msg INFO $argv; return 0; end
function _warn --description "Emit WARN-level message and increment VERIFY_WARN"; _msg WARN $argv; return 0; end
function _phase_record --argument-names check result evidence --description "Append a row to the install summary matrix and JSONL"
    set -l _e (string replace -ra '[\n\r│]' ' ' -- "$evidence"); set -l _c (string replace -ra '[\n\r│]' ' ' -- "$check"); set -l _r (string replace -ra '[\n\r│]' ' ' -- "$result")
    set -ga _RY_PHASE_RESULTS "$_c│$_r│$_e"
    _log "PHASE_RESULT: check='$_c' result=$_r evidence='$_e'"
end
function _err --description "Emit ERR-level message (force-prints to stderr when _RY_LOUD_ERR=true)"
    if set -q _RY_LOUD_ERR; and test "$_RY_LOUD_ERR" = true; and test "$MODE" != check
        _log "ERR: "(string join -- " " $argv)
        set -q VERIFY_FAIL; and set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
        _msg_print --force ERR $argv
    else
        _msg ERR $argv
    end
    return 0
end
function _err_loud --description "Fatal-preflight err: stderr regardless of QUIET, except MODE=check (silent-probe contract)"
    set -l msg (string join -- " " $argv)
    _log "ERR: $msg"
    set -q VERIFY_FAIL; and set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
    test "$MODE" = check; and return 0
    _msg_print --force ERR $argv
end
function _err_loud_cont --description "Continuation line for a prior _err_loud (rationale/override hint): same routing, no VERIFY_FAIL bump (one condition counts once)"
    set -l msg (string join -- " " $argv)
    _log "ERR: $msg"
    test "$MODE" = check; and return 0
    _msg_print --force ERR $argv
end
function _warn_loud --description "Override-path warn: stderr regardless of QUIET, except MODE=check (silent-probe contract)" # mirrors _err_loud
    set -l msg (string join -- " " $argv)
    _log "WARN: $msg"
    set -q VERIFY_WARN; and set -g VERIFY_WARN (math $VERIFY_WARN + 1)
    test "$MODE" = check; and return 0
    _msg_print --force WARN $argv
end
function _echo --description "Print a plain message without level prefix"
    _log "ECHO: $argv"
    if test "$QUIET" = false; and not set -q _RY_OUTPUT_BROKEN; printf '%s\n' (string join ' ' -- $argv) >&2; end
end

# ── VERIFY SUMMARY ──
function _verify_summary --description "Print verification pass/fail/warn summary"
    _echo "VERIFICATION SUMMARY"
    set -l snap_ok $VERIFY_OK; set -l snap_fail $VERIFY_FAIL; set -l snap_warn $VERIFY_WARN; set -l snap_gen_fail 0
    set -q VERIFY_GEN_FAIL; and set snap_gen_fail $VERIFY_GEN_FAIL
    set -l summary "Results: $snap_ok OK"
    test "$snap_warn" -gt 0; and set summary "$summary, $snap_warn WARN"
    test "$snap_fail" -gt 0; and set summary "$summary, $snap_fail FAIL"
    test "$snap_gen_fail" -gt 0; and set summary "$summary, $snap_gen_fail GEN_FAIL"
    if test "$snap_fail" -gt 0; or test "$snap_gen_fail" -gt 0
        _msg_nocount FAIL "$summary"
        _log "VERIFY_RESULT: status=fail ok=$snap_ok fail=$snap_fail warn=$snap_warn gen_fail=$snap_gen_fail"
        return 1
    else if test "$snap_warn" -gt 0
        _msg_nocount WARN "$summary"
        _log "VERIFY_RESULT: status=warn ok=$snap_ok fail=$snap_fail warn=$snap_warn gen_fail=$snap_gen_fail"
        return 0
    else
        _msg_nocount OK "$summary"
        _log "VERIFY_RESULT: status=ok ok=$snap_ok fail=$snap_fail warn=$snap_warn gen_fail=$snap_gen_fail"
        return 0
    end
end

# ── PROGRESS BAR (PINNED BOTTOM ROW WITH SCROLL REGION) ──
function _progress_now --description "Monotonic seconds (cached uptime or epoch)"
    if set -q _PROG_CLOCK; and test "$_PROG_CLOCK" = uptime
        set -l _u (command cat -- /proc/uptime 2>/dev/null | string split ' ')[1]
        if string match -qr '^\d+(\.\d+)?$' -- "$_u"; math "floor($_u)"; return 0; end
        command date +%s
        return 0
    else if set -q _PROG_CLOCK
        command date +%s
        return 0
    end
    set -l _u (command cat -- /proc/uptime 2>/dev/null | string split ' ')[1]
    if string match -qr '^\d+(\.\d+)?$' -- "$_u"; set -g _PROG_CLOCK uptime; math "floor($_u)"; return 0; end
    set -g _PROG_CLOCK epoch
    command date +%s
end
function _progress_init --description "Open scroll region; draw initial bar"
    set -g _PROG_STEPS $_RY_PHASE_NAMES
    set -g _PROG_CUR 0; set -g _PROG_TOTAL (count $_PROG_STEPS); test "$_PROG_TOTAL" -gt 0; or set -g _PROG_TOTAL 1
    set -g _PROG_START (_progress_now); set -g _PROG_STEP_START $_PROG_START
    set -g _PROG_STEP_NAME ""; set -g _PROG_PINNED false
    test "$_RY_NO_COLOR" = true; and return 0
    isatty 2; or return 0
    command -q tput; or return 0
    set -q TMUX; and return 0
    set -q STY; and return 0
    set -q ZELLIJ; and return 0
    string match -q 'screen*' -- "$TERM"; and return 0
    set -q MOSH_CONNECTION; and return 0
    string match -q 'mosh*' -- "$TERM_PROGRAM"; and return 0
    set -l rows (command tput lines 2>/dev/null)
    string match -qr '^\d+$' -- "$rows"; or return 0
    test "$rows" -ge 10; or return 0
    set -l _cols (command tput cols 2>/dev/null)
    string match -qr '^\d+$' -- "$_cols"; or return 0
    test "$_cols" -ge 64; or return 0 # min 64 cols; narrower corrupts scroll region
    set -g _PROG_PINNED true; set -g _PROG_ROWS $rows; set -l _scroll_bot (math $_PROG_ROWS - 1)
    printf '\e[1;%dr\e[%d;1H' $_scroll_bot $_scroll_bot >&2
    _progress_redraw "" 0
end
function _progress --argument-names name outcome --description "Advance progress counter and emit step-end log"
    if not contains -- "$name" $_PROG_STEPS; _log "BUG: _progress called with unknown step name='$name' (known: "(string join ',' -- $_PROG_STEPS)") — refusing to mutate counter"; return 1; end
    set -g _PROG_CUR (math "min($_PROG_CUR + 1, $_PROG_TOTAL)")
    set -l now (_progress_now)
    test -n "$_PROG_STEP_NAME"; and _log "PROG_STEP_END: name=$_PROG_STEP_NAME secs="(math $now - $_PROG_STEP_START)
    set -g _PROG_STEP_NAME $name; set -g _PROG_STEP_START $now; set -l _outcome_marker
    test -n "$outcome"; and set _outcome_marker " outcome=$outcome"
    _log "PROG_STEP_START: [$_PROG_CUR/$_PROG_TOTAL] $name$_outcome_marker"
    test "$_PROG_PINNED" = true; or return 0
    _progress_redraw "$name" $_PROG_CUR
end
function _progress_redraw --argument-names name current --description "Redraw pinned progress bar at terminal bottom row"
    set -q _RY_OUTPUT_BROKEN; and return 0 # SIGPIPE: stderr consumer gone
    set -l pct (math "floor($current * 100 / $_PROG_TOTAL)"); set -l filled (math "floor($current * $_PROG_BAR_WIDTH / $_PROG_TOTAL)"); set -l empty (math "$_PROG_BAR_WIDTH - $filled"); set -l bar
    test "$filled" -gt 0; and set bar (string repeat -n $filled '█')
    test "$empty" -gt 0; and set bar "$bar"(string repeat -n $empty '░')
    printf '\e[s\e[%d;1H\e[K[%s] %3d%% %s\e[u' \
        $_PROG_ROWS "$bar" $pct "$name" >&2
end
function _progress_done --description "Finalize progress bar and log elapsed seconds"
    set -l _now (_progress_now); set -l elapsed (math $_now - $_PROG_START)
    test -n "$_PROG_STEP_NAME"; and _log "PROG_STEP_END: name=$_PROG_STEP_NAME secs="(math $_now - $_PROG_STEP_START)
    set -l _skip false
    set -q _PROG_FINALIZED_SKIP; and test "$_PROG_FINALIZED_SKIP" = true; and set _skip true
    _log "PROG_DONE: elapsed_secs=$elapsed skip=$_skip"
    set -q _RY_OUTPUT_BROKEN; and set -g _PROG_PINNED false # SIGPIPE seen: skip terminal writes.
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r' >&2
    if test "$_skip" = true
        set -l pct (math "floor($_PROG_CUR * 100 / $_PROG_TOTAL)")
        printf '\e[%d;1H\e[K[%s] %3d%% Aborted (%ds)\n' \
            $_PROG_ROWS (string repeat -n $_PROG_BAR_WIDTH '░') $pct $elapsed >&2
    else
        printf '\e[%d;1H\e[K[%s] 100%% Done (%ds)\n' \
            $_PROG_ROWS (string repeat -n $_PROG_BAR_WIDTH '█') $elapsed >&2
    end
    set -g _PROG_PINNED false
end
function _progress_teardown --description "Clear pinned progress bar and reset scroll region (signal/abort path)"
    set -q _RY_OUTPUT_BROKEN; and set -g _PROG_PINNED false # SIGPIPE seen: skip terminal writes.
    set -q _PROG_PINNED; or return 0
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r\e[%d;1H\e[K\n' $_PROG_ROWS >&2
    set -g _PROG_PINNED false
end
function _progress_on_winch --on-signal WINCH --description "Re-anchor progress bar on terminal resize"
    set -q _RY_OUTPUT_BROKEN; and return 0 # SIGPIPE: stderr consumer gone
    set -q _PROG_PINNED; or return 0
    test "$_PROG_PINNED" = true; or return 0
    set -l _new_rows (command tput lines 2>/dev/null)
    string match -qr '^\d+$' -- "$_new_rows"; or return 0
    if test "$_new_rows" -lt 10; set -g _PROG_ROWS $_new_rows; _progress_teardown; return 0; end # <10 rows: tear down (mirrors init refusal).
    set -l _new_cols (command tput cols 2>/dev/null)
    if string match -qr '^\d+$' -- "$_new_cols"; and test "$_new_cols" -lt 64; set -g _PROG_ROWS $_new_rows; _progress_teardown; return 0; end # <64 cols: tear down (mirrors init refusal)
    set -g _PROG_ROWS $_new_rows
    printf '\e[s\e[1;%dr\e[u' (math $_PROG_ROWS - 1) >&2
    _progress_redraw "$_PROG_STEP_NAME" $_PROG_CUR
end

# ── COMMAND RUNNER: _run + STDOUT/STDERR CAPTURE + TIMEOUT DISPATCH ──
function _run_resolve_timeout --description "Resolve RY_RUN_TIMEOUT to a usable seconds integer (0 = disabled)"
    if not set -q RY_RUN_TIMEOUT; echo $_RY_RUN_TIMEOUT_DEFAULT; return 0; end
    if test -z "$RY_RUN_TIMEOUT"; echo $_RY_RUN_TIMEOUT_DEFAULT; return 0; end
    if string match -qr '^[0-9]+$' -- "$RY_RUN_TIMEOUT"
        set -l _t (math "$RY_RUN_TIMEOUT")
        if test "$_t" -eq 0; echo 0; return 0; end
        echo $_t
        return 0
    end
    if not set -q _RY_RUN_TIMEOUT_WARNED
        set -g _RY_RUN_TIMEOUT_WARNED true
        _msg_nocount WARN "RY_RUN_TIMEOUT='$RY_RUN_TIMEOUT' is invalid (expected non-negative integer; 0 to disable) — using default $_RY_RUN_TIMEOUT_DEFAULT""s"
        _log "RY_RUN_TIMEOUT_INVALID: value=$RY_RUN_TIMEOUT — using default $_RY_RUN_TIMEOUT_DEFAULT"
    end
    echo $_RY_RUN_TIMEOUT_DEFAULT
end
function _run_emit_stream --argument-names label_tag tmpfile ret cap --description "_run sub: Capture stream, log, emit per QUIET/rc"
    test -s "$tmpfile"; or return 0
    set -l _total (command wc -l <"$tmpfile" 2>/dev/null | string trim --); set -l _last_byte (command tail -c1 -- "$tmpfile" 2>/dev/null)
    test -n "$_last_byte"; and string match -qr '^\d+$' -- "$_total"; and set _total (math $_total + 1)
    set -l _captured; set -l _head_cap (math "max(1, $cap - 100)"); set -l _tail_cap 100; set -l _need_tail false
    string match -qr '^\d+$' -- "$_total"; and test "$_total" -gt "$cap"; and set _need_tail true
    set -l _head_n $cap; test "$_need_tail" = true; and set _head_n $_head_cap
    for _l in (command head -n $_head_n -- "$tmpfile"); test (string length -- "$_l") -gt 2000; and set _l (string sub -l 2000 -- "$_l"); set -a _captured "$_l"; end # 2000-char/line cap for JSONL
    if test "$_need_tail" = true
        set -a _captured "[... "(math $_total - $_head_cap - $_tail_cap)" lines elided ...]"
        for _l in (command tail -n $_tail_cap -- "$tmpfile"); test (string length -- "$_l") -gt 2000; and set _l (string sub -l 2000 -- "$_l"); set -a _captured "$_l"; end
    end
    _log "$label_tag: "(string join -- " | " $_captured)
    string match -qr '^\d+$' -- "$_total"; and test "$_total" -gt "$cap"; and _log "$label_tag""_TRUNCATED: total_lines=$_total head_cap=$_head_cap tail_cap=$_tail_cap"
    if test "$_need_tail" = true
        set -l _ovf "$LOG_DIR/run-overflow"
        if not test -d "$_ovf"; command mkdir -p -m 700 -- "$_ovf" 2>/dev/null; and _track_tmpfile "$_ovf"; end # ephemeral: tracked, swept at teardown
        set -l _dest (command mktemp --suffix=.log -p "$_ovf" "$label_tag-$TIMESTAMP-XXXXXX" 2>/dev/null)
        if test -n "$_dest"; and command cp -- "$tmpfile" "$_dest" 2>/dev/null
            set -l _sha (command sha256sum -- "$_dest" 2>/dev/null | string match -rg -- '^(\S+)')
            _log "$label_tag""_FULL_SPILL: path=$_dest sha256=$_sha lines=$_total ephemeral=true (swept at teardown)"
        else
            _log "$label_tag""_FULL_SPILL_FAIL: could not write spill file under $_ovf"
        end
    end
    if not set -q _RY_OUTPUT_BROKEN
        if test "$QUIET" = false
            for _l in $_captured; printf '%s\n' "$_l" >&2; end
        else if test "$label_tag" = STDERR; and test "$ret" -ne 0
            for _l in $_captured[1..5]
                printf '%s\n' "$_l" >&2
            end
        end
    end
end
function _run_redact_cmd --description "_run sub: build logged cmd string with tmpdir paths redacted"
    set -l log_cmd (string join -- " " $argv)
    if set -q TMPDIR; and test -n "$TMPDIR"; and test "$TMPDIR" != /tmp
        set -l _td_re (string escape --style=regex -- "$TMPDIR")
        set log_cmd (string replace -ar -- "$_td_re"'/ry-[A-Za-z0-9_.-]+' '<TMPDIR>/ry-[REDACTED]' "$log_cmd")
    end
    string replace -ar -- '/tmp/ry-[A-Za-z0-9_.-]+' '/tmp/ry-[REDACTED]' "$log_cmd"
end
function _run_effective_timeout --description "_run sub: resolve timeout; bypass for long-running pkg/boot/db ops (0 = disabled)" # SIGKILL mid-txn corrupts db.lck
    set -l _t (_run_resolve_timeout); set -l _effective_cmd $argv[1]
    if test "$_effective_cmd" = sudo
        set -l _skip_next false
        for _ec_arg in $argv[2..-1]
            if test "$_skip_next" = true; set _skip_next false; continue; end
            if contains -- "$_ec_arg" -u -g -p -C -D -R -T -U; set _skip_next true; continue; end # value-taking sudo flags: skip flag + value
            string match -q -- '-*' "$_ec_arg"; and continue
            test "$_ec_arg" = env; and continue
            string match -qr -- '^[A-Za-z_][A-Za-z0-9_]*=' "$_ec_arg"; and continue
            set _effective_cmd $_ec_arg; break
        end
    end
    set _effective_cmd (command basename -- "$_effective_cmd")
    if contains -- "$_effective_cmd" pacman mkinitcpio sdboot-manage paccache updatedb pkgfile
        test "$_t" -gt 0 2>/dev/null; and _log "TIMEOUT_BYPASS: cmd=$_effective_cmd (long-running pkg/boot/db op; SIGKILL would bypass rollback)"
        set _t 0
    end
    echo "$_t"
end

# ── COMMAND RUNNER: _run ENTRY (capture + timeout dispatch; rc passthrough) ──
function _run --description "Execute a command with logging, stdout/stderr capture, and timeout enforcement"
    if test (count $argv) -eq 0; _log "BUG: _run called with no arguments"; return $EXIT_RUN_MISUSE; end
    if string match -q -- '-*' "$argv[1]"; _log "BUG: _run called with dash-prefixed argv[1]='$argv[1]' — refusing"; return $EXIT_RUN_MISUSE; end
    set -l log_cmd (_run_redact_cmd $argv)
    _log "RUN: $log_cmd"
    set -l _run_dir (command mktemp -d -p (_tmp_dir) ry-run.XXXXXX 2>/dev/null)
    _track_tmpfile "$_run_dir"
    if test -z "$_run_dir"; or not test -d "$_run_dir"
        _log "RUN_ABORT: mktemp -d failed for cmd=$log_cmd — refusing to execute without stderr capture"
        _err "_run: cannot allocate tmpdir for stdout/stderr capture — aborting command"
        return $EXIT_RUN_TMPFAIL
    end
    set -l stderr_tmp "$_run_dir/stderr"; set -l stdout_tmp "$_run_dir/stdout"; set -l _run_timeout (_run_effective_timeout $argv)
    if test "$_run_timeout" -gt 0 2>/dev/null
        command timeout --foreground --kill-after=10 "$_run_timeout" $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp" # SIGKILL 10s post-TERM
    else
        command $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    end
    set -l ret $status; set -l _cap 500
    _run_emit_stream STDERR "$stderr_tmp" $ret $_cap
    _run_emit_stream STDOUT "$stdout_tmp" $ret $_cap
    _rm_tmp "$_run_dir" false
    if test "$_run_timeout" -gt 0 2>/dev/null
        if test "$ret" -eq 124
            _log "TIMEOUT_TERM: timeout="$_run_timeout"s cmd=$log_cmd"
        else if test "$ret" -eq 137
            _log "TIMEOUT_KILL: timeout="$_run_timeout"s cmd=$log_cmd (SIGKILL after 10s grace)"
        end
    end
    _log "EXIT: $ret cmd=$log_cmd"
    return $ret
end

# ── GENERIC CHECK HELPERS (file, grep, perms, sysfs, token) ──
function _chk_eq --argument-names label actual expected --description "Compare actual vs expected; emit _ok or _fail"
    if test "$actual" = "$expected"
        _ok "  $label: $actual"
    else
        _fail "  $label: $actual (expected: $expected)"
    end
end
function _chk_sysfs_match --argument-names path regex label --description "Read sysfs/proc, regex-match value (silent on missing path)"
    test -f "$path"; or return 0
    set -l _v (command cat -- "$path" 2>/dev/null | string trim --)
    if string match -qr -- "$regex" "$_v"
        _ok "  $label: $_v"
    else
        _fail "  $label: $_v (expected match: $regex)"
    end
end
function _chk_sysfs_eq --argument-names path expected label --description "Read sysfs/proc, compare to expected (silent on missing path)"
    test -f "$path"; or return 0
    set -l _val (command cat -- "$path" 2>/dev/null | string trim --)
    _chk_eq "$label" "$_val" "$expected"
end
function _chk_perms --argument-names path expected_perms expected_owner use_sudo --description "Compare file mode+owner; refuses 4-digit modes (setuid/sgid/sticky)"
    set -l _po
    if test "$use_sudo" = true
        set _po (sudo -n stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    else
        set _po (command stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    end
    if test -z "$_po"; _fail "  $path: stat failed (file disappeared or unreadable)"; return 1; end
    set -l _parts (string split ' ' -- "$_po")
    if test (count $_parts) -lt 2; _fail "  $path: stat output malformed (got: '$_po')"; return 1; end
    set -l _actual_perms $_parts[1]
    if test (string length -- "$_actual_perms") -eq 4
        _fail "  $path: $_parts[1] $_parts[2] (unexpected setuid/sgid/sticky bit; expected: $expected_perms $expected_owner)"
        return 1
    end
    set -l _bad 0
    test "$_actual_perms" != "$expected_perms"; and set _bad 1
    test "$_parts[2]" != "$expected_owner"; and set _bad 1
    if test "$_bad" -eq 1; _fail "  $path: $_parts[1] $_parts[2] (expected: $expected_perms $expected_owner)"; return 1; end
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
function _chk_file --argument-names filepath --description "Verify file exists; sudo fallback for /boot"
    _log "CHECK_FILE: $filepath"
    test -f "$filepath"; and _ok "File exists: $filepath"; and return 0
    if string match -q '/boot/*' -- "$filepath"
        if not command -q sudo; _fail "File check requires sudo: $filepath"; return 1; end
        if sudo -n test -L "$filepath" 2>/dev/null; _fail "File is a symlink (refused for /boot path): $filepath"; _log "CHECK_FILE_SYMLINK_REJECT: $filepath"; return 1; end
        sudo -n test -f "$filepath" 2>/dev/null; and _ok "File exists: $filepath"; and return 0
        if not sudo -n true 2>/dev/null; _warn "$filepath: sudo cache lapsed — cannot determine presence"; _log "CHECK_FILE_SUDO_LAPSE: $filepath"; return 1; end
    end
    _fail "File NOT FOUND: $filepath"
    return 1
end
function _cg_access_ok --argument-names file label use_sudo --description "Pre-flight read access check (use_sudo: sudo-mediated probe)"
    if test "$use_sudo" = false
        test -r "$file"; and return 0
        if test -f "$file"
            _fail "  $label: PERMISSION DENIED (need sudo?)"
        else
            _fail "  $label: FILE NOT FOUND"
        end
        return 1
    end
    if not command -q sudo; _fail "  $label: sudo required to read $file"; return 1; end
    if not sudo -n true 2>/dev/null; _warn "  $label: sudo cache lapsed — re-run ry-install"; return 1; end
    if not sudo -n test -f "$file" 2>/dev/null; _fail "  $label: FILE NOT FOUND"; return 1; end
    return 0
end

# ── CHECK HELPERS: GREP/TOKEN (sudo-aware file-content assertions) ──
function _chk_grep --argument-names file pattern label --description "Verify a file contains an expected token"
    test -z "$label"; and set label "$pattern"
    _log "CHECK_GREP: $file for '$pattern'"
    set -l use_sudo false
    string match -q '/boot/*' -- "$file"; and set use_sudo true
    if test "$use_sudo" = false; and not test -r "$file"; and _is_system_dst "$file"; set use_sudo true; end # sudo read avoids false DENIED on perms drift
    _cg_access_ok "$file" "$label" $use_sudo; or return 1
    set -l _grep_flags -wF
    _as $use_sudo grep -v '^[[:space:]]*#' -- "$file" 2>/dev/null | command grep $_grep_flags -- "$pattern" >/dev/null 2>/dev/null
    set -l _stage1_rc $pipestatus[1]; set -l _grep_rc $pipestatus[2]
    switch "$_stage1_rc"
        case 0
        case 1
            if test "$use_sudo" = true; and not sudo -n true 2>/dev/null; _warn "  $label: sudo cache lapsed during read — cannot determine presence"; return 1; end
            _fail "  $label: MISSING (file has no non-comment lines)"
            return 1
        case '*'
            _warn "  $label: cannot read file (stage-1 rc=$_stage1_rc — sudo lapse or read error)"
            return 1
    end
    switch "$_grep_rc"
        case 0
            _ok "  $label: present"
            return 0
        case 1
            _fail "  $label: MISSING"
            return 1
        case '*'
            _warn "  $label: grep error rc=$_grep_rc (binary/IO/regex) — cannot determine presence"
            return 1
    end
end
function _chk_token_in --argument-names line token label --description "Verify a whole-word token is present in a config line"
    set -l _re (string escape --style=regex -- "$token")
    if string match -qr "\\b$_re\\b" -- "$line"
        _ok "  $label: present"
    else
        _fail "  $label: MISSING"
    end
end

# ── PREFLIGHT GATES: DEPS + NETWORK + DISK + SYSTEMD ──
function _ry_check_deps --description "Verify required packages are installed"
    _log "DEPS_CHECK_START"
    set -l missing
    for cmd in pacman systemctl mkinitcpio sdboot-manage findmnt sha256sum timeout mktemp awk grep curl getent sudo head df mv tee stat find cp chmod chown install cat rm date wc tail basename dirname mkdir rmdir touch env sleep cmp
        command -q $cmd; or set -a missing $cmd
    end
    if test (count $missing) -gt 0; _err "missing: $missing"; return 1; end
    if not command env LC_ALL=C df --output=avail / >/dev/null 2>&1; _err "df(1) lacks --output flag — GNU coreutils required (busybox/uutils not supported)"; return 1; end
    _resolve_systemd_ver
    if test -z "$_RY_SYSTEMD_VER"; _err "Cannot determine systemd version (systemctl --version unparseable) — refusing install (systemd ≥ 250 is a hard requirement)"; return 1; end
    if test "$_RY_SYSTEMD_VER" -lt 250; _err "systemd $_RY_SYSTEMD_VER < 250 — preflight gate; upgrade systemd before install"; return 1; end
    set -l _opt_missing
    for cmd in bootctl journalctl dmesg modinfo pgrep free uptime zcat tput swapon zramctl lsmod modprobe pkill nmcli ping realpath ip lspci kill; command -q $cmd; or set -a _opt_missing $cmd; end
    test (count $_opt_missing) -gt 0; and _warn "Expected tools not found (from base packages): $_opt_missing"
    _log "DEPS_CHECK_OK"
    return 0
end
function _ry_check_network --description "Verify network connectivity (HTTPS primary + secondary + raw-IP fallback)"
    _log "NET_CHECK_START"
    set -l _idx 0
    for _host in archlinux.org cloudflare.com
        set _idx (math $_idx + 1)
        if command curl -sf -o /dev/null --connect-timeout 3 --max-time 5 "https://$_host" 2>/dev/null
            if test "$_idx" -eq 1
                _ok "Network connectivity: OK"
            else
                _ok "Network connectivity: OK (fallback host)"
            end
            return 0
        end
    end
    set -l _icmp_ok false
    if command -q ping
        for _ip in 1.1.1.1 8.8.8.8; command ping -c 1 -W 3 "$_ip" >/dev/null 2>&1; and set _icmp_ok true; and break; end
    end
    if test "$_icmp_ok" = true
        _err "Network connectivity: HTTPS or DNS unreachable (raw-IP ICMP works; check /etc/resolv.conf or 443 egress)"
        set -g _RY_NET_FAIL_EVIDENCE "HTTPS/DNS unreachable (raw-IP ICMP ok)"
    else
        _err "Network connectivity: FAILED — cannot reach archlinux.org, cloudflare.com, 1.1.1.1, or 8.8.8.8"
        set -g _RY_NET_FAIL_EVIDENCE "archlinux.org, cloudflare.com, 1.1.1.1, 8.8.8.8 unreachable"
    end
    return 1
end
function _ry_rtc_writeback --description "Persist NTP-corrected system time to the hardware clock (hwclock --systohc) so a skewed RTC stops poisoning timer persistence stamps; non-fatal"
    if not command -q hwclock; _info "    RTC: hwclock not found — cannot persist corrected time to hardware clock (timer persistence stamps may stay skewed until next sync)"; _log "RTC_WRITEBACK_SKIP: hwclock absent"; return 1; end
    set -l _rtc_local (command timedatectl show -p RTCInLocalTZ --value 2>/dev/null | string trim --)
    if test "$_rtc_local" = yes; _info "    RTC: hardware clock is in local time — leaving --systohc to systemd; not writing directly"; _log "RTC_WRITEBACK_SKIP: RTCInLocalTZ=yes"; return 1; end
    if _run sudo -n hwclock --systohc --utc
        _ok "  RTC: hardware clock written back from NTP-corrected system time (--systohc)"
        _log "RTC_WRITEBACK_OK"
        return 0
    end
    _warn "  RTC: hwclock --systohc failed — hardware clock still skewed; correct manually (sudo hwclock --systohc --utc)"
    _log "RTC_WRITEBACK_FAIL"
    return 1
end
function _ry_check_time_sync --description "Verify NTP time sync; enable systemd-timesyncd if drifted (non-fatal); persist corrected time to RTC"
    _log "TIME_SYNC_CHECK_START"
    if not command -q timedatectl; _warn "  Time sync: timedatectl not found — cannot verify (pacman GPG checks may fail on a skewed clock)"; _log "TIME_SYNC_SKIP: timedatectl absent"; return 1; end
    set -l _synced (command timedatectl show -p NTPSynchronized --value 2>/dev/null | string trim --)
    if test "$_synced" = yes; _ok "  Time sync: NTP synchronized"; _log "TIME_SYNC_OK"; _ry_rtc_writeback; return 0; end
    _warn "  Time sync: clock NOT NTP-synchronized (NTPSynchronized=$_synced) — pacman signature checks can fail"
    _log "TIME_SYNC_UNSYNCED: NTPSynchronized=$_synced"
    if not command -q systemctl; _info "    systemctl absent — start an NTP client manually"; return 1; end
    for _ntp_alt in chronyd.service ntpd.service # never stack timesyncd on existing NTP client
        set -l _alt_en (command systemctl is-enabled -- $_ntp_alt 2>/dev/null | string trim --)
        set -l _alt_act (command systemctl is-active -- $_ntp_alt 2>/dev/null | string trim --)
        if begin; test -n "$_alt_en"; and not contains -- "$_alt_en" disabled masked not-found; end; or contains -- "$_alt_act" active activating
            _warn "  Time sync: $_ntp_alt is present ($_alt_en/$_alt_act) but the clock is unsynced — not enabling systemd-timesyncd (two NTP clients would conflict); repair $_ntp_alt manually"
            _log "TIME_SYNC_CONFLICT: $_ntp_alt is-enabled=$_alt_en is-active=$_alt_act — timesyncd auto-enable skipped"
            return 1
        end
    end
    if _run sudo -n systemctl enable --now systemd-timesyncd.service
        command sleep 2 </dev/null 2>/dev/null
        set -l _resynced (command timedatectl show -p NTPSynchronized --value 2>/dev/null | string trim --)
        if test "$_resynced" = yes; _ok "  Time sync: synchronized after starting systemd-timesyncd"; _log "TIME_SYNC_RECOVERED"; _ry_rtc_writeback; return 0; end
        _warn "  Time sync: still not synchronized (NTPSynchronized=$_resynced) — verify NTP egress before relying on signatures"
        _info "    Manual: sudo timedatectl set-ntp true; sleep 5; timedatectl"
        _log "TIME_SYNC_STILL_UNSYNCED: NTPSynchronized=$_resynced"
        return 1
    end
    _warn "  Time sync: could not enable systemd-timesyncd — configure an NTP client manually"
    _log "TIME_SYNC_TIMESYNCD_ENABLE_FAIL"
    return 1
end
function _check_avail --argument-names path divisor unit crit warn --description "Compare available bytes at path against crit/warn thresholds (in scaled units)"
    set -l _b (command env LC_ALL=C df --output=avail -B1 -- "$path" 2>/dev/null | command tail -n 1 | string trim --); set -l _v ""
    test -n "$_b"; and string match -qr '^\d+$' -- "$_b"; and set _v (math "floor($_b / $divisor)")
    if test -z "$_v"; or not string match -qr '^\d+$' -- "$_v"
        if test "$MODE" = install; _err "Cannot determine disk space for $path (df --output=avail returned unparseable output) — refusing to install"; return 1; end
        _warn "Could not determine disk space for $path"
        return 0
    end
    set -l _disp "$_v$unit"
    test "$_v" -eq 0; and test "$_b" -gt 0; and set _disp "<1$unit"
    if test "$_v" -lt "$crit"
        _err "Insufficient disk space on $path: $_disp available, need $crit$unit minimum"
        return 1
    else if test "$_v" -lt "$warn"
        _warn "Low disk space on $path: $_disp available"
    else
        _ok "Disk space on $path: $_disp available"
    end
    return 0
end
function _ry_check_disk_space --description "Verify sufficient free disk space for installation"
    _log "DISK_CHECK_START"
    _check_avail / 1073741824 GiB $ROOT_AVAIL_CRIT $ROOT_AVAIL_WARN; or return 1
    set -l _boot_mnt (command findmnt -no TARGET /boot 2>/dev/null | string trim --) # gate only when /boot is its own mount
    if test "$_boot_mnt" = /boot
        _check_avail /boot 1048576 MiB $BOOT_SPACE_CRIT $BOOT_SPACE_WARN; or return 1
    else
        _info "  /boot is not a separate mount — its free space is covered by the / check"
        _log "DISK_CHECK_BOOT_NOT_SEPARATE: findmnt target='$_boot_mnt' (expected /boot); skipping dedicated /boot gate"
    end
    return 0
end

# ── MKINITCPIO HOOK + MODULE VALIDATORS (ordering invariants) ──
function _mkinitcpio_hook_exists --argument-names hook --description "True iff hook file exists in any mkinitcpio install/hooks dir"
    test -z "$hook"; and return 1
    for _d in /usr/lib/initcpio/install /usr/lib/initcpio/hooks /etc/initcpio/install /etc/initcpio/hooks; test -f "$_d/$hook"; and return 0; end
    return 1
end
function _vmh_existence_only --description "_ry_validate_mkinitcpio_hooks sub: Existence-only path: emit _ok/_fail per hook"
    set -l errors 0
    for hook in $argv
        test -z "$hook"; and continue
        if _mkinitcpio_hook_exists "$hook"
            _ok "  $hook: exists"
        else
            _fail "  $hook: NOT FOUND"
            set errors (math $errors + 1)
        end
    end
    test "$errors" -eq 0
end
function _vmh_order_checks --description "_ry_validate_mkinitcpio_hooks sub: hook ordering"
    set -l hooks $argv; set -l errors 0
    if test (count $hooks) -eq 0; echo 0; return 0; end
    if test "$hooks[1]" != base; _err "mkinitcpio hook order: 'base' must be first (found: $hooks[1])"; set errors (math $errors + 1); end
    set -l _seen_hooks
    for hook in $hooks
        if contains -- "$hook" $_seen_hooks
            _err "Duplicate mkinitcpio hook: $hook"
            set errors (math $errors + 1)
        else
            set -a _seen_hooks "$hook"
        end
    end
    set -l order_checks "systemd:autodetect" "autodetect:microcode" "autodetect:modconf" "systemd:sd-vconsole" "systemd:keyboard" "keyboard:sd-vconsole" "modconf:kms" "block:filesystems" # pair BEFORE:AFTER
    for check in $order_checks
        set -l _sp (string split ':' -- "$check"); set -l hook_before $_sp[1]; set -l hook_after $_sp[2]; set -l idx_a 0; set -l idx_b 0
        for i in (seq (count $hooks)); test "$hooks[$i]" = "$hook_before"; and set idx_a $i; test "$hooks[$i]" = "$hook_after"; and set idx_b $i; end
        if test "$idx_a" -gt 0; and test "$idx_b" -gt 0; and test "$idx_a" -ge "$idx_b"; _err "mkinitcpio hook order: '$hook_before' must come before '$hook_after'"; set errors (math $errors + 1); end
    end
    set -l _fsck_idx 0 # fsck must be last
    for i in (seq (count $hooks)); test "$hooks[$i]" = fsck; and set _fsck_idx $i; and break; end
    if test "$_fsck_idx" -gt 0; and test "$_fsck_idx" -ne (count $hooks); _err "mkinitcpio hook order: 'fsck' must be last (found at position $_fsck_idx of "(count $hooks)")"; set errors (math $errors + 1); end
    echo $errors
end
function _ry_validate_mkinitcpio_hooks --description "Validate mkinitcpio HOOKS ordering and presence"
    set -l existence_only false; set -l hooks
    if test (count $argv) -gt 0; and test "$argv[1]" = --existence-only
        set existence_only true
        set hooks $argv[2..-1]
    else if test (count $argv) -gt 0
        set hooks $argv
    else
        set hooks $MKINITCPIO_HOOKS
    end
    if test "$existence_only" = true; _vmh_existence_only $hooks; return $status; end
    set -l errors 0
    for hook in $hooks
        if not _mkinitcpio_hook_exists "$hook"; _err "Invalid mkinitcpio hook: $hook"; set errors (math $errors + 1); end
    end
    set -l _order_errs (_vmh_order_checks $hooks)
    string match -qr '^\d+$' -- "$_order_errs"; or set _order_errs 0
    set errors (math $errors + $_order_errs)
    test "$errors" -eq 0
end
function _ry_validate_mkinitcpio_modules --description "Validate mkinitcpio MODULES array entries"
    not command -q modinfo; and return 0
    set -l _errors 0
    for mod in $MKINITCPIO_MODULES
        command modinfo "$mod" >/dev/null 2>&1; and continue
        if test "$mod" = amdgpu
            _err "Required module not found: amdgpu (gfx1151 KMS depends on it) — refusing to deploy"
            set _errors (math $_errors + 1)
        else
            _warn "Module may not exist: $mod (continuing anyway)"
        end
    end
    test "$_errors" -eq 0
end

# ── CONFIG-FORMAT VALIDATORS (KV, KPARAM, SYSCTL, INI, TMPFILES) ──
function _grep_kv --argument-names dst --description "Validate kv pairs (loader.conf space-sep; sdboot-manage.conf eq-sep)"
    test (count $argv) -lt 2; and _log "BUG: _grep_kv called without content (dst=$dst)"; and return 2
    set -l content $argv[2..-1]; set -l keys; set -l sep
    switch "$dst"
        case '*/loader.conf'
            set keys default timeout console-mode editor
            set sep ' '
        case '*/sdboot-manage.conf'
            set keys LINUX_OPTIONS LINUX_FALLBACK_OPTIONS DEFAULT_ENTRY REMOVE_EXISTING OVERWRITE_EXISTING REMOVE_OBSOLETE
            set sep '='
        case '*'
            _log "BUG: _grep_kv called for unsupported dst=$dst"
            return 2
    end
    set -l _sep_re (string escape --style=regex -- "$sep")
    for key in $keys
        set -l _key_re (string escape --style=regex -- "$key")
        string match -qr -- "^$_key_re$_sep_re" $content; or begin
            _fail "  $dst: missing key '$key'"
            return 1
        end
    end
    return 0
end
function _grep_kparam --argument-names dst --description "Validate cmdline has root=UUID, rw, all KERNEL_PARAMS"
    test (count $argv) -lt 2; and _log "BUG: _grep_kparam called without content (dst=$dst)"; and return 2
    string match -qr -- '(^|\s)root=UUID=' $argv[2..-1]; or begin
        _fail "  $dst: missing required token 'root=UUID='"
        return 1
    end
    string match -qr -- '(^|\s)rw(\s|$)' $argv[2..-1]; or begin
        _fail "  $dst: missing required token 'rw'"
        return 1
    end
    for _kp in $KERNEL_PARAMS
        set -l _kp_re (string escape --style=regex -- "$_kp")
        if not string match -qr -- "(^|\s)$_kp_re(\s|\$)" $argv[2..-1]; _fail "  $dst: missing declared KERNEL_PARAMS token '$_kp'"; return 1; end
    end
    return 0
end
function _grep_sysctl_kv --argument-names dst --description "Validate sysctl.d has ≥1 'key = value' line"
    test (count $argv) -lt 2; and _log "BUG: _grep_sysctl_kv called without content (dst=$dst)"; and return 2
    string match -qr '^[a-zA-Z._0-9-]+\s*=\s*\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no 'key = value' lines found"
        return 1
    end
    return 0
end
function _grep_ini_header --argument-names dst --description 'Validate ≥1 [Section] header present'
    test (count $argv) -lt 2; and _log "BUG: _grep_ini_header called without content (dst=$dst)"; and return 2
    string match -qr '^\[[^]]+\]$' -- $argv[2..-1]; or begin
        _fail "  $dst: no [Section] header found"
        return 1
    end
    return 0
end
function _grep_modprobe_entry --argument-names dst --description 'Validate ≥1 modprobe.d directive line (options/blacklist/install/alias/softdep/remove)'
    test (count $argv) -lt 2; and _log "BUG: _grep_modprobe_entry called without content (dst=$dst)"; and return 2
    string match -qr '^[[:space:]]*(options|blacklist|install|remove|alias|softdep)[[:space:]]+\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no modprobe directive (options/blacklist/install/alias/softdep/remove) found"
        return 1
    end
    return 0
end
function _grep_regdomain_entry --argument-names dst --description 'Validate a COUNTRY=<ISO-3166 alpha-2> line (/etc/iw-regdomain; # comments allowed)'
    test (count $argv) -lt 2; and _log "BUG: _grep_regdomain_entry called without content (dst=$dst)"; and return 2
    string match -qr '^[[:space:]]*COUNTRY=[A-Z][A-Z][[:space:]]*$' -- $argv[2..-1]; or begin
        _fail "  $dst: no COUNTRY=<ISO-3166 alpha-2> line found"
        return 1
    end
    return 0
end
function _grep_udev_entry --argument-names dst --description 'Validate ≥1 udev rule line (KEY{...}op match/assignment, # comments allowed)'
    test (count $argv) -lt 2; and _log "BUG: _grep_udev_entry called without content (dst=$dst)"; and return 2
    string match -qr '^[[:space:]]*[A-Z][A-Z_]*(\{[^}]*\})?[[:space:]]*(==|!=|\+=|:=|=)' -- $argv[2..-1]; or begin
        _fail "  $dst: no udev rule directive (KEY[{attr}]op\"val\") found"
        return 1
    end
    return 0
end
function _grep_nft_entry --argument-names dst --description 'Validate nftables ruleset skeleton (table + chain); loaded via nft -f, not INI' # nft has no [Section]
    test (count $argv) -lt 2; and _log "BUG: _grep_nft_entry called without content (dst=$dst)"; and return 2
    string match -qr '^[[:space:]]*table[[:space:]]+\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no nftables 'table <family> <name>' declaration found"
        return 1
    end
    string match -qr '^[[:space:]]*chain[[:space:]]+\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no nftables 'chain' declaration found"
        return 1
    end
    return 0
end
function _grep_envd_entry --argument-names dst --description 'Validate ≥1 KEY=value line (environment.d)'
    test (count $argv) -lt 2; and _log "BUG: _grep_envd_entry called without content (dst=$dst)"; and return 2
    string match -qr '^[A-Za-z_][A-Za-z0-9_]*=\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no KEY=value line found"
        return 1
    end
    return 0
end
function _grep_cpupower_entry --argument-names dst --description "Validate a GOVERNOR='<name>' line (cpupower-service.conf)"
    test (count $argv) -lt 2; and _log "BUG: _grep_cpupower_entry called without content (dst=$dst)"; and return 2
    string match -qr -- "^GOVERNOR='[a-z]+'\$" $argv[2..-1]; or begin
        _fail "  $dst: no GOVERNOR='<name>' line found"
        return 1
    end
    return 0
end
function _grep_mangohud_entry --argument-names dst --description 'Validate ≥1 MangoHud directive line (bareword token or key=value; # comments allowed)'
    test (count $argv) -lt 2; and _log "BUG: _grep_mangohud_entry called without content (dst=$dst)"; and return 2
    string match -qr '^[a-z][a-z0-9_]*(=\S+)?[[:space:]]*$' -- $argv[2..-1]; or begin
        _fail "  $dst: no MangoHud directive (bareword or key=value) found"
        return 1
    end
    return 0
end
function _rvc_dispatch --argument-names dst --description "Validate single embedded content by format family"
    set -l _content $argv[2..-1]
    switch "$dst"
        case '*/loader.conf' '*/sdboot-manage.conf'
            _grep_kv "$dst" $_content
        case '*/kernel/cmdline'
            _grep_kparam "$dst" $_content
        case '*/sysctl.d/*'
            _grep_sysctl_kv "$dst" $_content
        case '*/modprobe.d/*'
            _grep_modprobe_entry "$dst" $_content
        case '/etc/iw-regdomain'
            _grep_regdomain_entry "$dst" $_content
        case '*/udev/rules.d/*'
            _grep_udev_entry "$dst" $_content
        case '*/nftables.conf'
            _grep_nft_entry "$dst" $_content
        case '*/environment.d/*'
            _grep_envd_entry "$dst" $_content
        case '*/default/cpupower-service.conf'
            _grep_cpupower_entry "$dst" $_content
        case '*/MangoHud/MangoHud.conf'
            _grep_mangohud_entry "$dst" $_content
        case '*/mkinitcpio.conf'
            return 0
        case '*'
            _grep_ini_header "$dst" $_content
    end
end
function _ry_validate_configs --description "Run all embedded config validators"
    _info "Validating configuration syntax..."
    set -l errors 0
    _ry_validate_mkinitcpio_hooks; or set errors (math $errors + 1)
    _ry_validate_mkinitcpio_modules; or set errors (math $errors + 1)
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS
        set -l fn (_content_fn_for "$dst")
        if not functions -q $fn; _fail "  $dst: content generator '$fn' not found"; set errors (math $errors + 1); continue; end
        set -l content ($fn)
        if test "$status" -ne 0; _fail "  $dst: content generator failed"; set errors (math $errors + 1); continue; end
        _rvc_dispatch "$dst" $content; or set errors (math $errors + 1)
    end
    if test "$errors" -gt 0; _err "Validation failed with $errors error(s)"; return $EXIT_PREFLIGHT; end
    _ok "All configurations validated"
    return 0
end

# ── ATOMIC FILE INSTALL: RENDER → SYMLINK CHECK → CHMOD → MV -T ──
function _ry_mkinitcpio_array --argument-names key file --description "First non-comment KEY=... line from a conf file"
    test -z "$file"; and set file /etc/mkinitcpio.conf
    set -l _key_re (string escape --style=regex -- "$key"); set -l _all_lines
    if test -r "$file"
        set _all_lines (command grep -E -- "^[[:space:]]*$_key_re=" "$file" 2>/dev/null)
    else
        set _all_lines (sudo -n grep -E -- "^[[:space:]]*$_key_re=" "$file" 2>/dev/null)
    end
    test (count $_all_lines) -gt 1; and _warn "  $file: multiple $key= lines found ("(count $_all_lines)") — using first"
    test (count $_all_lines) -gt 0; and printf '%s\n' "$_all_lines[1]"
end
function _ry_content_bytes --argument-names dst --description "Raw bytes of embedded content" # pipestatus[1]=gen rc
    set -l _content (_ry_get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines --allow-empty); set -l _ps $pipestatus
    test "$_ps[1]" -ne 0; and return "$_ps[1]"
    printf '%s' "$_content"
end
function _awf_render_to_tmp --argument-names dst tmpfile use_sudo --description "Pipe content generator into tee"
    set -l _tee_err (_mktemp_or_null -p (_tmp_dir) ry-tee-err.XXXXXX)
    _track_tmpfile "$_tee_err"
    _ry_get_file_content "$dst" | _as $use_sudo tee -- "$tmpfile" >/dev/null 2>"$_tee_err"
    set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0
        switch "$_ps[1]"
            case $EXIT_GEN_NOFN
                _err "Not a managed destination: $dst"
            case $EXIT_GEN_NOUUID
                _err "Content generator missing prerequisite global (e.g. _ROOT_UUID): $dst"
            case $EXIT_GEN_SYSCTL
                if set -q _RY_SYSCTL_BAD_ENTRIES; and test (count $_RY_SYSCTL_BAD_ENTRIES) -gt 0
                    _err "Content generator assertion failed (output count mismatch): $dst — malformed entries: "(string join ', ' -- $_RY_SYSCTL_BAD_ENTRIES)
                else
                    _err "Content generator assertion failed (output count mismatch): $dst"
                end
            case '*'
                _err "Content generator failed for $dst (rc=$_ps[1])"
        end
        _rm_tmp "$_tee_err" false
        return 1
    end
    if test "$_ps[2]" -eq $EXIT_AS_MISUSE
        _fail "→ $dst (BUG: _as called with non-bool use_sudo='$use_sudo' in render pipe)"
        _rm_tmp "$_tee_err" false
        return 1
    end
    if test "$_ps[2]" -ne 0
        set -l _tee_msg ""
        test -n "$_tee_err"; and test -s "$_tee_err"; and set _tee_msg " tee_err="(command head -n 1 -- "$_tee_err" | string trim --)
        _fail "→ $dst (write to temp failed)$_tee_msg"
        _rm_tmp "$_tee_err" false
        return 1
    end
    _rm_tmp "$_tee_err" false
    return 0
end
function _awf_symlink_check --argument-names dst tmpfile use_sudo --description "_atomic_write_file sub: probe tmpfile for post-write symlink swap"
    _is_symlink "$tmpfile" $use_sudo
    set -l _sym_rc $status
    if test "$_sym_rc" -eq 0; _fail "→ $dst (temp file replaced with symlink during write — aborting)"; return 1; end
    test "$_sym_rc" -eq 2; and _fail "→ $dst (sudo cache lapsed during post-write symlink check — aborting)"; and return 1
    return 0
end
function _awf_finalize_mv --argument-names dst tmpfile use_sudo perms --description "chmod + sudo cache check + atomic mv"
    set -l _sp
    test "$use_sudo" = true; and set _sp sudo -n
    if not _run $_sp chmod -- $perms "$tmpfile"; _fail "→ $dst (chmod failed)"; return 1; end
    if test "$use_sudo" = true; and not sudo -n true 2>/dev/null; _err "sudo credential lapsed before atomic mv of $dst"; return 1; end
    if not _run $_sp mv -T -- "$tmpfile" "$dst"; _fail "→ $dst (atomic move failed)"; return 1; end
    return 0
end
function _awf_is_backup_target --argument-names dst --description "True if dst is in _RY_BACKUP_TARGETS (automatic .ry.bak set)"
    contains -- "$dst" $_RY_BACKUP_TARGETS
end
function _awf_make_backup --argument-names dst use_sudo --description "Create <dst>.ry.bak before overwrite (loader.conf/mkinitcpio.conf/fstab)"
    set -l _bak "$dst$_RY_BACKUP_SUFFIX"
    set -l _sp; test "$use_sudo" = true; and set _sp sudo -n
    if test "$use_sudo" = true
        sudo -n test -f "$dst" 2>/dev/null; or return 0
    else
        test -f "$dst"; or return 0
    end
    if _run $_sp cp -p -- "$dst" "$_bak"
        _log "BACKUP_CREATED: $dst -> $_bak"
    else
        _warn "  $dst: backup to $_bak failed — proceeding (atomic write still protects original on write failure)"
        _log "BACKUP_FAIL: $dst -> $_bak"
    end
    return 0
end
function _awf_postwrite_verify_restore --argument-names dst use_sudo --description "Re-read installed bytes vs expected; restore .ry.bak on mismatch"
    set -l _bak "$dst$_RY_BACKUP_SUFFIX"; set -l _expected (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty); set -l _gen_ps $pipestatus
    if test "$_gen_ps[1]" -ne 0; _warn "  $dst: post-write verify skipped (content generator re-run rc=$_gen_ps[1])"; _log "POSTWRITE_VERIFY_SKIP: dst=$dst reason=gen_rerun rc=$_gen_ps[1]"; return 0; end
    set -l _actual (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty); set -l _ib_ps $pipestatus
    if test "$_ib_ps[1]" -ne 0; _warn "  $dst: post-write verify skipped (installed-bytes read rc=$_ib_ps[1]; e.g. sudo cache lapse)"; _log "POSTWRITE_VERIFY_SKIP: dst=$dst reason=read_fail rc=$_ib_ps[1]"; return 0; end
    test "$_expected" = "$_actual"; and return 0
    _fail "→ $dst (post-write verification mismatch — installed bytes differ from expected)"
    _log "POSTWRITE_VERIFY_FAIL: dst=$dst installed!=expected"
    set -l _has_bak false
    if test "$use_sudo" = true
        sudo -n test -f "$_bak" 2>/dev/null; and set _has_bak true
    else
        test -f "$_bak"; and set _has_bak true
    end
    if test "$_has_bak" = false; _err "  $dst: no backup ($_bak) to restore"; _log "POSTWRITE_RESTORE_NOBAK: dst=$dst"; return 1; end
    set -l _spr; test "$use_sudo" = true; and set _spr sudo -n
    if _run $_spr mv -T -- "$_bak" "$dst"
        _warn "  $dst: restored from $_bak after verification failure"
        _log "POSTWRITE_RESTORE_OK: dst=$dst"
    else
        _err "  $dst: restore from $_bak FAILED — file may be inconsistent"
        _log "POSTWRITE_RESTORE_FAIL: dst=$dst"
    end
    return 1
end
function _atomic_write_file --argument-names dst perms use_sudo --description "Atomic file write. rc=0 ok; rc=1 any failure"
    set -l dst_dir (command dirname -- "$dst"); set -l _is_bt false
    _awf_is_backup_target "$dst"; and set _is_bt true
    set -l tmpfile (_as $use_sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
    if test -z "$tmpfile"; _fail "→ $dst (mktemp failed)"; return 1; end
    _track_tmpfile "$tmpfile"
    if not _awf_render_to_tmp "$dst" "$tmpfile" $use_sudo; _rm_tmp "$tmpfile" $use_sudo; return 1; end
    if not _awf_symlink_check "$dst" "$tmpfile" $use_sudo; _rm_tmp "$tmpfile" $use_sudo; return 1; end
    test "$_is_bt" = true; and _awf_make_backup "$dst" $use_sudo # back up after render+symlink-probe
    _awf_finalize_mv "$dst" "$tmpfile" $use_sudo "$perms"
    set -l _fin_rc $status
    if test "$_fin_rc" -ne 0; _rm_tmp "$tmpfile" $use_sudo; return $_fin_rc; end
    _untrack_tmpfile "$tmpfile"
    if test "$_is_bt" = true; and not _awf_postwrite_verify_restore "$dst" $use_sudo; return 1; end
    _ok "→ $dst"
    return 0
end
function _ry_install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
    set -l dir (command dirname -- "$dst")
    if test "$use_sudo" = true
        set -l _pmk (umask); umask 0022 # 0022 caps umask so dirs stay 0755
        _run sudo -n mkdir -p -m 0755 -- "$dir"
        set -l _mk_rc $status
        umask $_pmk
        if test "$_mk_rc" -ne 0; _fail "Cannot create directory: $dir"; return 1; end
    else
        if not _run mkdir -p -- "$dir"; _fail "Cannot create directory: $dir"; return 1; end # ambient umask; file 0600 via atomic-write
    end
    set -l perms 0644
    test "$use_sudo" = false; and set perms 0600
    set -l _new_bytes (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty); set -l _gen_rc $pipestatus[1]
    if test "$_gen_rc" -eq 0
        set -l _cur_bytes (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty); set -l _read_rc $pipestatus[1]
        if test "$_read_rc" -eq 0; and test "$_new_bytes" = "$_cur_bytes"; set -g _RY_DEPLOY_IDEMPOTENT_COUNT (math $_RY_DEPLOY_IDEMPOTENT_COUNT + 1); _ok "→ $dst (unchanged)"; return 0; end
        test "$_read_rc" -eq 2; and _log "SKIP_PROBE_SUDO_LAPSED: dst=$dst — re-deploying"
    end
    _atomic_write_file "$dst" "$perms" "$use_sudo"
    set -l _aw_rc $status
    test "$_aw_rc" -eq 0; and set -g _RY_DEPLOY_CHANGED_COUNT (math $_RY_DEPLOY_CHANGED_COUNT + 1)
    return $_aw_rc
end

# ── VERIFY-STATIC: BOOT (LOADER + SDBOOT + CMDLINE + MKINITCPIO + ENTRIES) ──
function _vsb_loader --description "_verify_static_boot sub: /boot/loader/loader.conf key/value verification"
    _echo "── loader.conf ──"
    _chk_file /boot/loader/loader.conf; or return 0
    for kv in "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"; _chk_grep /boot/loader/loader.conf "$kv"; end
end
function _vsb_sdboot --description "_verify_static_boot sub: sdboot-manage.conf LINUX_OPTIONS + key checks"
    _echo "── sdboot-manage.conf ──"
    _chk_file /etc/sdboot-manage.conf; or return 0
    set -l _opts_raw (command grep -- '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null); set -l _grep_rc $status
    if test "$_grep_rc" -gt 1; or begin; test "$_grep_rc" -eq 1; and not test -r /etc/sdboot-manage.conf; end # perms drift: sudo retry before judging missing
        set _opts_raw (sudo -n grep -- '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null); set _grep_rc $status
        if test "$_grep_rc" -gt 1; _warn "  /etc/sdboot-manage.conf: unreadable (sudo lapse or read error) — skipping param extraction"; return 0; end
    end
    set -l _opts_ok true
    if test "$_grep_rc" -ne 0; or test -z "$_opts_raw"
        _fail "  /etc/sdboot-manage.conf: LINUX_OPTIONS= line missing"; set _opts_ok false
    else if test (count $_opts_raw) -gt 1
        _fail "  /etc/sdboot-manage.conf: "(count $_opts_raw)" LINUX_OPTIONS= lines found (expected 1) — skipping param extraction"; set _opts_ok false
    else
        set -l _quote_count (string replace -ar -- '[^"]' '' "$_opts_raw" | string length --)
        if test "$_quote_count" -ne 2; _fail "  /etc/sdboot-manage.conf: LINUX_OPTIONS= has $_quote_count quote chars (expected 2) — skipping param extraction"; set _opts_ok false; end
    end
    if test "$_opts_ok" = true
        set -l opts (printf '%s\n' "$_opts_raw" | string replace -r -- '^LINUX_OPTIONS="([^"]*)".*$' '$1')
        for param in $KERNEL_PARAMS; set -l _param_re (string escape --style=regex -- "$param"); string match -qr -- "(^|\s)$_param_re(\s|\$)" "$opts"; _chk_present $status "$param"; end
    end
    for _kv in "OVERWRITE_EXISTING:$SDBOOT_OVERWRITE" \
        "REMOVE_EXISTING:$SDBOOT_REMOVE_EXISTING" \
        "REMOVE_OBSOLETE:$SDBOOT_REMOVE_OBSOLETE" \
        "DEFAULT_ENTRY:$SDBOOT_DEFAULT_ENTRY"
        set -l _p (string split -m1 ':' -- $_kv)
        _chk_grep /etc/sdboot-manage.conf "$_p[1]=\"$_p[2]\"" "$_p[1]=$_p[2]"
    end
    _chk_grep /etc/sdboot-manage.conf 'LINUX_FALLBACK_OPTIONS="quiet"' "LINUX_FALLBACK_OPTIONS=quiet"
end
function _vsb_cmdline --description "_verify_static_boot sub: cmdline KERNEL_PARAMS + root=UUID + rw"
    _echo "── kernel cmdline ──"
    _chk_file /etc/kernel/cmdline; or return 0
    set -l cmdline_content (command cat -- /etc/kernel/cmdline 2>/dev/null)
    test -z "$cmdline_content"; and set cmdline_content (sudo -n cat -- /etc/kernel/cmdline 2>/dev/null)
    if test -z "$cmdline_content"
        if not sudo -n true 2>/dev/null; _warn "  /etc/kernel/cmdline: sudo cache lapsed — cannot determine content"; return 0; end
        _fail "  /etc/kernel/cmdline: empty or unreadable"
        return 0
    end
    for param in $KERNEL_PARAMS
        set -l _param_re (string escape --style=regex -- "$param")
        string match -qr -- "(^|\s)$_param_re(\s|\$)" "$cmdline_content"
        _chk_present $status "$param" "MISSING from /etc/kernel/cmdline"
    end
    if test -n "$_ROOT_UUID"
        string match -q "*root=UUID=$_ROOT_UUID*" -- "$cmdline_content"
        _chk_present $status "root=UUID=$_ROOT_UUID" "MISSING/MISMATCH in /etc/kernel/cmdline"
    else
        string match -q '*root=UUID=*' -- "$cmdline_content"
        _chk_present $status root=UUID "MISSING from /etc/kernel/cmdline"
    end
    string match -qr -- '(^|\s)rw(\s|$)' "$cmdline_content"
    _chk_present $status rw "MISSING from /etc/kernel/cmdline"
end
function _vsb_mkinitcpio --description "_verify_static_boot sub: /etc/mkinitcpio.conf MODULES/HOOKS/COMPRESSION checks"
    _echo "── mkinitcpio.conf ──"
    _chk_file /etc/mkinitcpio.conf; or return 0
    set -l modules_line (_ry_mkinitcpio_array MODULES)
    _echo "  Config: $modules_line"
    string match -qr -- '\bamdgpu\b' "$modules_line"
    _chk_present $status amdgpu MISSING "present (early KMS)"
    for mod in $MKINITCPIO_MODULES; test "$mod" = amdgpu; and continue; _chk_token_in "$modules_line" "$mod" "$mod"; end
    set -l hooks_line (_ry_mkinitcpio_array HOOKS)
    _echo "  Config: $hooks_line"
    for hook in $MKINITCPIO_HOOKS; _chk_token_in "$hooks_line" "$hook" "$hook"; end
    set -l comp_line (_ry_mkinitcpio_array COMPRESSION)
    if string match -q '*zstd*' -- "$comp_line"
        _ok "  COMPRESSION=zstd: present"
    else
        _fail "  COMPRESSION=zstd: MISSING"
    end
    if set -q MKINITCPIO_COMPRESSION_OPTIONS; and test -n "$MKINITCPIO_COMPRESSION_OPTIONS"
        set -l comp_opts_line (_ry_mkinitcpio_array COMPRESSION_OPTIONS); set -l _missing
        for _co in $MKINITCPIO_COMPRESSION_OPTIONS; set -l _co_re (string escape --style=regex -- "$_co"); string match -qr -- "(^|\(|\s)$_co_re(\s|\)|\$)" "$comp_opts_line"; or set -a _missing "$_co"; end
        if test (count $_missing) -eq 0
            _ok "  COMPRESSION_OPTIONS=$MKINITCPIO_COMPRESSION_OPTIONS: present"
        else
            _fail "  COMPRESSION_OPTIONS: missing tokens: $_missing"
        end
    end
end
function _vsb_entries --description "_verify_static_boot sub: \$BOOT entries enumeration + count check"
    _echo "── Boot entries ──"
    set -l _boot (_resolve_boot_path)
    if test -z "$_boot"; _warn "  Boot entries: cannot resolve \$BOOT path (bootctl/findmnt failed) — skipping"; return 0; end
    set -l entry_count 0; set -l _entries_pipe_ok true; set -l _entries_dir_probed false
    if sudo -n test -d "$_boot/loader/entries" 2>/dev/null
        set _entries_dir_probed true
        set -l _entries (sudo -n find "$_boot/loader/entries" -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null | string split0); set -l _ps $pipestatus
        test "$_ps[1]" -eq 0; or set _entries_pipe_ok false
        set entry_count (count $_entries)
    else if not sudo -n true 2>/dev/null
        _warn "  Boot entries: sudo cache lapsed — cannot enumerate $_boot/loader/entries"
        return 0
    end
    if test "$_entries_pipe_ok" = false
        _warn "  Boot entries: cannot enumerate $_boot/loader/entries (sudo lapsed or read error)"
    else if test "$_entries_dir_probed" = false
        _fail "  Boot entries: $_boot/loader/entries/ does not exist"
        _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    else if test "$entry_count" -gt 0
        _ok "  Boot entries: $entry_count found"
    else
        _fail "  Boot entries: NONE in $_boot/loader/entries/"
        _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    end
end
function _verify_static_boot --description "Verify loader.conf, sdboot-manage, kernel cmdline, mkinitcpio, boot entries"
    _echo "BOOT CONFIGURATION"
    _vsb_loader
    _vsb_sdboot
    _vsb_cmdline
    _vsb_mkinitcpio
    _vsb_entries
end

# ── VERIFY-STATIC: SYSTEM + USER (drop-ins, env.d) ──
function _vss_ntsync_modules --description "_verify_static_system sub: ntsync state"
    _echo "── ntsync state ──"
    set -l _ns (_ntsync_state)
    switch "$_ns" # case order mirrors _vre_ntsync
        case loaded
            _ok "  ntsync: loaded, /dev/ntsync present"
        case builtin
            _info "  ntsync: built-in (CONFIG_NTSYNC=y)"
        case loaded_nodev
            _warn "  ntsync: module loaded but /dev/ntsync missing"
        case missing
            _info "  ntsync: module not loaded"
    end
end
function _vss_logind --description "_verify_static_system sub: logind.conf.d keys"
    _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf; or return 0
    for key in $LOGIND_IGNORE_KEYS
        _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
    end
end
function _vss_nmdispatch --description "_verify_static_system sub: NetworkManager-dispatcher logging drop-in"
    _chk_file /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf; or return 0
    _chk_grep /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf "LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX" "dispatcher LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX"
end
function _vss_nm --description "_verify_static_system sub: NetworkManager config"
    _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf; or return 0
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
end
function _vss_sysctl --description "_verify_static_system sub: sysctl drop-in key=value check"
    _echo "── sysctl drop-in ──"
    if _chk_file /etc/sysctl.d/95-ry-overrides.conf
        for entry in $SYSCTL_VALUES; set -l parts (string split -m1 '=' -- "$entry"); set -l key $parts[1]; set -l val $parts[2]; _chk_grep /etc/sysctl.d/95-ry-overrides.conf "$key = $val" "$key=$val"; end
    end
end
function _vss_regdom --description "_verify_static_system sub: wireless regdom (/etc/iw-regdomain)"
    _echo "── wireless regdom (iw-regdomain) ──"
    _chk_file /etc/iw-regdomain; and _chk_grep /etc/iw-regdomain "COUNTRY=$COUNTRY" "iw-regdomain COUNTRY=$COUNTRY"
end
function _vss_bluetooth --description "_verify_static_system sub: BlueZ main.conf (adapter auto-power-on)"
    _echo "── bluetooth (main.conf) ──"
    _chk_file /etc/bluetooth/main.conf; or return 0
    _chk_grep /etc/bluetooth/main.conf "AutoEnable=$BT_AUTO_ENABLE" "AutoEnable=$BT_AUTO_ENABLE"
    _chk_grep /etc/bluetooth/main.conf "FastConnectable=$BT_FAST_CONNECTABLE" "FastConnectable=$BT_FAST_CONNECTABLE"
    _chk_grep /etc/bluetooth/main.conf "ReconnectAttempts=$BT_RECONNECT_ATTEMPTS" "ReconnectAttempts=$BT_RECONNECT_ATTEMPTS"
end
function _vss_udev --description "_verify_static_system sub: combined udev perf rules (NVMe scheduler + EPP + GPU clock-floor)"
    _echo "── udev (perf: I/O scheduler + EPP + GPU clock-floor) ──"
    _chk_file /etc/udev/rules.d/99-ry-perf.rules; or return 0
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'queue/scheduler}="none"' "nvme scheduler=none"
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'energy_performance_preference}="balance_performance"' "EPP=balance_performance"
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'power_dpm_force_performance_level}="'$GPU_DPM_LEVEL'"' "GPU dpm=$GPU_DPM_LEVEL"
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'KERNEL=="card[0-9]"' "GPU rule card-scoped"
end
function _vss_nft --description "_verify_static_system sub: nftables default-deny-inbound + ICMPv6 NDP/PMTUD accept (IPv6 break-glass)"
    _chk_file /etc/nftables.conf; or return 0
    _chk_grep /etc/nftables.conf "policy drop" "nftables input policy drop"
    _chk_grep /etc/nftables.conf "nd-neighbor-solicit" "nftables ICMPv6 NDP/PMTUD accept" # regression guard: dropping breaks IPv6 post-NDP-expiry
end
function _vss_modprobe --description "_verify_static_system sub: mt7925e modprobe drop-in (ASPM disable)"
    _chk_file /etc/modprobe.d/60-ry-mt7925e.conf; and _chk_grep /etc/modprobe.d/60-ry-mt7925e.conf 'options mt7925e disable_aspm=1' 'mt7925e disable_aspm=1'
end
function _kb_modemmanager_masked --description "INFO when modemmanager.service is masked (expected) — KDE kded probes org.freedesktop.ModemManager1 and the activation fails by design"
    contains -- modemmanager.service $MASK; or return 0 # only relevant when we mask it
    command -q systemctl; or return 0
    set -l _state (command systemctl is-enabled -- modemmanager.service 2>/dev/null | string trim --)
    contains -- "$_state" masked; or return 0 # only annotate if the mask actually took
    _info "  ModemManager masked: kded/D-Bus 'ModemManager1 ... could not be found' activation failures are expected and harmless"
    return 0
end
function _kb_acp70_no_machine_driver --description "INFO when ACP70 audio co-processor has no matching ASoC machine driver (missing kernel board-ID quirk; mic may be undetected)"
    command -q dmesg; or return 0
    command dmesg 2>/dev/null | command grep -qiE 'acp_asoc_acp70.*No matching ASoC machine driver'; or return 0
    _info "  ACP70 audio: no matching ASoC machine driver — needs a kernel board-ID quirk; internal mic stays undetected until linux-cachyos ships one (report board model upstream)"
    return 0
end
function _kb_thunderbolt_nhi_unknown --description "INFO when boltd cannot resolve the USB4/Thunderbolt NHI PCI id (boltd PCI-ID table gap; TB UID-stability undetermined)"
    command -q journalctl; or return 0
    command journalctl -b --no-pager 2>/dev/null | command grep -qiE "unknown NHI PCI id"; or return 0
    _info "  Thunderbolt: boltd does not recognize this NHI PCI id — UID-stability check is skipped; USB4/TB devices still enumerate (boltd PCI-ID table gap)"
    return 0
end
function _kb_no_battery_backlight --description "INFO when powerdevil charge-threshold / backlight sysfs is absent (mini-PC: no internal battery or panel backlight — capability gap, not a fault)"
    set -l _have_bl false
    for _b in /sys/class/backlight/*; test -e "$_b"; and set _have_bl true; and break; end
    test "$_have_bl" = true; and return 0 # backlight present → nothing to annotate
    _info "  No panel backlight / battery sysfs: powerdevil 'charge thresholds not supported' and 'no backlight interface' are expected on this mini-PC (no internal battery or panel)"
    return 0
end
function _kb_usb_mic_volume_curve --description "INFO when a USB audio device reports a non-linear/unlikely volume range (UAC descriptor quirk on the device; cosmetic)"
    command -q dmesg; or return 0
    command dmesg 2>/dev/null | command grep -qiE 'Unlikely small volume range'; or return 0
    _info "  USB mic volume curve: a USB audio device reports an unlikely volume range — a UAC descriptor quirk in the device firmware (cosmetic; does not affect capture)"
    return 0
end
function _vss_known_benign --description "_verify_static_system sub: advisory INFO for known-benign conditions this host triggers by design or hardware (never fails; emits only when present)"
    _echo "── known-benign conditions (advisory) ──"
    _kb_modemmanager_masked
    _kb_acp70_no_machine_driver
    _kb_thunderbolt_nhi_unknown
    _kb_no_battery_backlight
    _kb_usb_mic_volume_curve
end
function _verify_static_system --description "Verify ntsync, resolved, logind, NM, regdom, bluetooth, cpupower-service.conf, sysctl, udev, nftables"
    _echo "SYSTEM CONFIGURATION"
    _vss_ntsync_modules
    _echo "── resolved ──"
    if _chk_file /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        for kv in "MulticastDNS=$RESOLVED_MDNS" "LLMNR=$RESOLVED_LLMNR" "DNSOverTLS=$RESOLVED_DOT" "DNSSEC=$RESOLVED_DNSSEC"; _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "$kv"; end
    end
    _echo "── logind.conf ──"
    _vss_logind
    _echo "── NetworkManager-dispatcher logging ──"
    _vss_nmdispatch
    _echo "── NetworkManager ──"
    _vss_nm
    _vss_regdom
    _vss_bluetooth
    _echo "── cpupower-service.conf ──"
    _chk_file /etc/default/cpupower-service.conf; and _chk_grep /etc/default/cpupower-service.conf "GOVERNOR='$CPUPOWER_GOVERNOR'" "GOVERNOR=$CPUPOWER_GOVERNOR"
    _vss_sysctl
    _vss_udev
    _echo "-- modprobe (mt7925e ASPM) --"
    _vss_modprobe
    _echo "── nftables ──"
    _vss_nft
    _vss_known_benign
end
function _verify_static_user --description "Verify environment.d ENV_VARS + baloo indexing disabled + MangoHud HUD config"
    _echo "USER CONFIGURATION"
    if _chk_file "$HOME/.config/environment.d/10-environment.conf"
        for exp in $ENV_VARS; _chk_grep "$HOME/.config/environment.d/10-environment.conf" "$exp" "$exp"; end
    end
    _echo "── baloo (KDE file indexing) ──"
    if _chk_file "$HOME/.config/baloofilerc"
        _chk_grep "$HOME/.config/baloofilerc" "Indexing-Enabled=false" "baloo indexing disabled"
    end
    _echo "── MangoHud (readout-only HUD) ──"
    if _chk_file "$HOME/.config/MangoHud/MangoHud.conf"
        _chk_grep "$HOME/.config/MangoHud/MangoHud.conf" "fps" "MangoHud fps readout"
    end
end

# ── VERIFY-STATIC: PACKAGES + SERVICES + SYNTAX ──
function _vsp_required --description "Check PKGS_ADD against installed; emits OK/FAIL per pkg"
    _echo "── Required packages ──"
    for pkg in $PKGS_ADD
        if contains -- "$pkg" $argv
            _ok "  $pkg: installed"
        else
            _fail "  $pkg: NOT INSTALLED"
        end
    end
end
function _vsp_removed --description "Check PKGS_DEL against installed; warn if still present"
    _echo "── Removed packages ──"
    for pkg in $PKGS_DEL
        if contains -- "$pkg" $argv
            _warn "  $pkg: still installed (should be removed)"
        else
            _ok "  $pkg: not installed"
        end
    end
end
function _vsp_pacman_conf --description "Inspect IgnorePkg / ParallelDownloads in /etc/pacman.conf (section-agnostic grep; pacman only honours [options])"
    _echo "── pacman.conf ──"
    if not test -f /etc/pacman.conf; _warn "  /etc/pacman.conf not found"; return 0; end
    set -l ignore_lines (command grep -E -- '^[[:space:]]*IgnorePkg' /etc/pacman.conf 2>/dev/null)
    if test -n "$ignore_lines"
        for line in $ignore_lines; _ok "  $line"; end
    else
        _info "  No IgnorePkg set"
    end
    set -l parallel (command grep -E -- '^[[:space:]]*ParallelDownloads[[:space:]]*=' /etc/pacman.conf 2>/dev/null)
    if test -n "$parallel"
        _ok "  $parallel"
    else
        _info "  ParallelDownloads not set (sequential downloads — uncomment in /etc/pacman.conf to enable)"
    end
end
function _verify_static_packages --description "Verify PKGS_ADD, PKGS_DEL, pacman.conf"
    _echo "PACKAGES"
    set -l _installed_pkgs
    if not command -q pacman; _warn "  pacman not found, skipping package verification"; return 0; end
    set _installed_pkgs (command pacman -Qq 2>/dev/null)
    if test "$status" -ne 0; _warn "  pacman -Qq failed (db locked or read error) — skipping package verification"; _log "VERIFY_PKGS_QQ_FAIL: pacman -Qq returned non-zero"; _vsp_pacman_conf; return 0; end
    _vsp_required $_installed_pkgs
    _vsp_removed $_installed_pkgs
    _vsp_pacman_conf
end
function _verify_static_services --description "Verify masked services state"
    _echo "SERVICES"
    _echo "── Masked services ──"
    set -l _check_mask $MASK; set -l _mask_parsed
    for _u in $_check_mask
        set -l _v (_unit_state_padded $_u)
        set -a _mask_parsed "$_v[1]:$_v[2]:$_v[3]"
    end
    for _mask_idx in (seq 1 (count $_check_mask))
        set -l _svc $_check_mask[$_mask_idx]; set -l _rec (string split ':' -- "$_mask_parsed[$_mask_idx]")
        if test "$_rec[3]" = ERR_NO_DATA
            _warn "  $_svc: systemctl state unavailable (absent or no running manager) — cannot verify mask state"
        else if test "$_rec[1]" = not-found
            _info "  $_svc: unit not found (may not be installed)"
        else if test "$_rec[3]" = masked; and test "$_rec[2]" = active
            _fail "  $_svc: masked but ACTIVE (stop or reboot)"
        else if test "$_rec[3]" = masked
            _ok "  $_svc: masked"
        else
            _fail "  $_svc: load=$_rec[1] state=$_rec[2] file=$_rec[3] (expected: masked)"
        end
    end
end
function _verify_static_syntax --description "Validate live mkinitcpio HOOKS presence (multi-line HOOKS tolerated)"
    _echo "SYNTAX VALIDATION"
    _echo "── mkinitcpio hooks ──"
    set -l _hooks_awk '/^[[:space:]]*HOOKS=\(/ { found = 1 } found { printf "%s ", $0 } found && /\)/ { exit }'
    set -l hooks_syntax_line
    if test -r /etc/mkinitcpio.conf
        set hooks_syntax_line (command awk "$_hooks_awk" /etc/mkinitcpio.conf 2>/dev/null | string trim --)
    else
        set hooks_syntax_line (sudo -n awk "$_hooks_awk" /etc/mkinitcpio.conf 2>/dev/null | string trim --) # perms drift: sudo read beats false parse warn
    end
    if test -n "$hooks_syntax_line"
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_syntax_line")
        set hooks_str (string replace -ra '\s+' ' ' -- "$hooks_str" | string trim --)
        _ry_validate_mkinitcpio_hooks --existence-only (string split ' ' -- "$hooks_str")
    else
        _warn "  Could not parse HOOKS from mkinitcpio.conf"
    end
end

# ── VERIFY-STATIC: CHECKSUM + DRIVER (SHA256 match + _ry_verify_static) ──
function _vsc_check_one --argument-names dst --description "_verify_static_checksum sub: Compare one destination's expected vs installed bytes"
    set -l expected (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
    set -l _gen_rc $pipestatus[1]
    if test "$_gen_rc" -ne 0
        if test "$_gen_rc" -eq "$EXIT_GEN_NOUUID"; and test -z "$_ROOT_UUID"; _warn "  $dst: checksum skipped — root UUID unresolved (presence verified separately)"; _log "VERIFY_STATIC_GEN_SKIP_NOUUID: dst=$dst"; return 0; end
        _fail_no_count "  $dst: generator failed (rc=$_gen_rc)"; set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + 1); _log "VERIFY_STATIC_GEN_FAIL: dst=$dst rc=$_gen_rc"; return 0
    end
    set -l actual (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
    set -l _ib_rc $pipestatus[1]
    switch "$_ib_rc"
        case 1
            _fail "  $dst: cannot read"; _log "VERIFY_STATIC_READ_FAIL: dst=$dst"; return 0
        case 2
            _fail "  $dst: sudo lapse during read"; _log "VERIFY_STATIC_SUDO_LAPSE: dst=$dst"; return 0
        case 0
        case '*'
            _fail "  $dst: unexpected read rc=$_ib_rc"; _log "VERIFY_STATIC_READ_UNEXPECTED: dst=$dst rc=$_ib_rc"; return 0
    end
    if test "$expected" = "$actual"
        _ok "  $dst: match"
    else
        _fail "  $dst: MISMATCH"
        set -l _exp_sha (printf '%s' "$expected" | command sha256sum 2>/dev/null | string match -rg -- '^(\S+)'); set -l _act_sha (printf '%s' "$actual" | command sha256sum 2>/dev/null | string match -rg -- '^(\S+)')
        test -z "$_exp_sha"; and set _exp_sha ERR
        test -z "$_act_sha"; and set _act_sha ERR
        _log "VERIFY_STATIC_MISMATCH: dst=$dst expected_content_sha=$_exp_sha actual_content_sha=$_act_sha expected_chars="(string length -- "$expected")" actual_chars="(string length -- "$actual")
    end
    return 0
end
function _verify_static_checksum --description "Verify embedded content hash matches installed file SHA256"
    _echo "CHECKSUM VERIFICATION"
    _echo
    _echo "── embedded vs installed ──"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS
        _vsc_check_one "$dst"
    end
    _echo
end
function _ry_verify_static --description "Verify installed configs: boot, system, user, packages, services, syntax, checksums"
    _log_section "STATIC VERIFICATION START"
    _ensure_sudo_cached; or begin
        _err_loud "sudo required for verification"
        return $EXIT_PREFLIGHT
    end
    set -g VERIFY_OK 0; set -g VERIFY_FAIL 0; set -g VERIFY_WARN 0; set -g VERIFY_GEN_FAIL 0
    _info "Static verification (config files)..."
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
    return $ret
end

# ── --CHECK MODE: SILENT IDEMPOTENCY PROBE ──
function _check_phase_files --description "--check phase: file content hash compare"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS
        set -l expected (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty); set -l _gen_rc $pipestatus[1]
        if test "$_gen_rc" -ne 0; _log "CHECK_PREFLIGHT: generator failed for $dst (rc=$_gen_rc)"; return $EXIT_PREFLIGHT; end
        set -l actual (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty); set -l _ib_rc $pipestatus[1]
        switch "$_ib_rc"
            case 0
            case 1
                set -g _RY_CHECK_DRIFT 1
                continue
            case 2
                _log "CHECK_PREFLIGHT: sudo lapse reading $dst"
                return $EXIT_PREFLIGHT
            case '*'
                _log "CHECK_PREFLIGHT: _installed_bytes returned unexpected rc=$_ib_rc for $dst"
                return $EXIT_PREFLIGHT
        end
        test "$expected" = "$actual"; or set -g _RY_CHECK_DRIFT 1
        set -g _RY_CHECK_FILES_CHECKED (math $_RY_CHECK_FILES_CHECKED + 1)
    end
    return 0
end
function _check_phase_cmdline --description "--check phase: cmdline contains KERNEL_PARAMS + rw"
    set -l _cmdline (command cat -- /proc/cmdline 2>/dev/null)
    if test -z "$_cmdline"; _log "CHECK_PREFLIGHT: /proc/cmdline empty or unreadable"; return $EXIT_PREFLIGHT; end
    for _p in $KERNEL_PARAMS; set -l _p_re (string escape --style=regex -- "$_p"); string match -qr -- "(^|\s)$_p_re(\s|\$)" "$_cmdline"; or set -g _RY_CHECK_DRIFT 1; end
    string match -qr -- '(^|\s)rw(\s|$)' "$_cmdline"; or set -g _RY_CHECK_DRIFT 1
    return 0
end
function _svc_chk_expected --description "Check EXPECTED_SERVICES units"
    for unit in $EXPECTED_SERVICES
        set -l _v (_unit_state_padded $unit); set -l load $_v[1]; set -l active $_v[2]; set -l ufs $_v[3]
        if test "$load" = ERR_NO_DATA
            _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"
            return $EXIT_PREFLIGHT
        else if test "$load" = not-found
            set -g _RY_CHECK_DRIFT 1
        else
            if test "$unit" = nftables.service; and test "$active" != active # oneshot reads inactive after clean load
                if not command -q nft
                    _log "CHECK_NFT_UNPROBEABLE: nft(8) absent — live ruleset unverifiable, treating as drift (fail-closed)"
                    set -g _RY_CHECK_DRIFT 1
                else
                    string match -q -- '*policy drop*' (_as true env LC_ALL=C nft list chain inet filter input 2>/dev/null); or set -g _RY_CHECK_DRIFT 1
                end
            else
                test "$active" = active; or set -g _RY_CHECK_DRIFT 1 # RemainAfterExit oneshots read active
            end
            test "$ufs" = enabled; or set -g _RY_CHECK_DRIFT 1
        end
    end
    return 0
end
function _implicit_confd_units --description "Units implied by managed conf.d drop-ins (shared: --check + runtime verify)"
    set -l _u
    for _dst in $SYSTEM_DESTINATIONS
        switch "$_dst"
            case '*/systemd/resolved.conf.d/*'
                contains -- systemd-resolved.service $_u; or set -a _u systemd-resolved.service
        end
    end
    test (count $_u) -gt 0; and printf '%s\n' $_u
    return 0
end
function _check_phase_units --description "--check phase: EXPECTED_SERVICES + MASK + conf.d-driven units"
    set -l _implicit_svcs (_implicit_confd_units)
    _svc_chk_expected; or return $status
    for unit in $MASK
        set -l _v (_unit_state_padded $unit)
        if test "$_v[1]" = ERR_NO_DATA; _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"; return $EXIT_PREFLIGHT; end
        test "$_v[1]" = not-found; and continue
        test "$_v[3]" = masked; or set -g _RY_CHECK_DRIFT 1
    end
    for unit in $_implicit_svcs
        set -l _v (_unit_state_padded $unit)
        if test "$_v[1]" = ERR_NO_DATA; _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"; return $EXIT_PREFLIGHT; end
        test "$_v[1]" = not-found; and continue
        test "$_v[3]" = enabled; or test "$_v[3]" = static; or set -g _RY_CHECK_DRIFT 1 # conf.d units accept enabled|static
    end
    return 0
end
function _ry_do_check --description "Silent idempotency probe" # ERR_NO_DATA->preflight unless drift confirmed
    _log_section "CHECK START"
    if not command -q sudo; or not sudo -n true 2>/dev/null; _log "CHECK_PREFLIGHT: sudo not cached"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    if not command -q systemctl; _log "CHECK_PREFLIGHT: systemctl not available"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    set -g _RY_CHECK_DRIFT 0; set -g _RY_CHECK_FILES_CHECKED 0; set -l _rc 0
    for _phase in _check_phase_files _check_phase_cmdline _check_phase_units # non-zero phase rc = cannot probe
        $_phase
        set _rc $status
        if test "$_rc" -ne 0
            set -l _drift_seen $_RY_CHECK_DRIFT
            set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
            if test "$_drift_seen" -ne 0; _log "CHECK_DRIFT_CONFIRMED_BEFORE_PREFLIGHT: returning EXIT_DRIFT despite later probe failure (probe_rc=$_rc)"; _log_section "CHECK END"; return $EXIT_DRIFT; end
            _log_section "CHECK END"; return $_rc
        end
    end
    set -l _drift $_RY_CHECK_DRIFT; set -l _checked $_RY_CHECK_FILES_CHECKED
    set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
    if test "$_drift" -ne 0; _log_section "CHECK END"; return $EXIT_DRIFT; end
    if test "$_checked" -eq 0; _log "CHECK_PREFLIGHT: no files could be checked"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    _log_section "CHECK END"
    return $EXIT_OK
end

# ── VERIFY-RUNTIME: KERNEL CMDLINE + GPU + CPU + MODULES + CLOCKSOURCE ──
function _vrk_cmdline --description "Runtime kparam check: /proc/cmdline + preemption model"
    _echo "KERNEL CMDLINE"
    _echo
    set -l cmdline (command cat -- /proc/cmdline 2>/dev/null)
    for param in $KERNEL_PARAMS
        set -l _param_re (string escape --style=regex -- "$param")
        if string match -qr -- "(^|\s)$_param_re(\s|\$)" "$cmdline"
            _ok "  $param: active"
        else
            _fail "  $param: NOT in cmdline"
        end
    end
    if string match -qr -- '(^|\s)rw(\s|$)' "$cmdline"
        _ok "  rw: active"
    else
        _fail "  rw: NOT in cmdline"
    end
    _echo
    _echo "── Preemption model ──"
    set -l _preempt $_RY_DMESG_PREEMPT
    if test -n "$_preempt"
        if string match -q '*full*' -- "$_preempt"
            _ok "  $_preempt"
        else
            _info "  $_preempt (advisory — kernel default; this profile does not pin preempt= on the cmdline)"
        end
    else
        set -l _preempt_param (string match -rg -- '(?:^|\s)preempt=(\S+)' "$cmdline")
        if test -n "$_preempt_param"
            _info "  Preemption (cmdline intent): preempt=$_preempt_param (runtime confirmation needs dmesg)"
        else
            _info "  Preemption model: cannot determine (dmesg unavailable, no preempt= in cmdline)"
        end
    end
    _echo
end
function _vrk_gpu_state --description "Runtime kparam check: GPU performance level (power_dpm_force_performance_level sysfs scan)"
    _echo "HARDWARE STATE"
    _echo "── GPU performance level ──"
    set -l gpu_ok false; set -l found_gpu false
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set found_gpu true
            set -l level (command cat -- "$f" 2>/dev/null)
            if test "$level" = $GPU_DPM_LEVEL
                _ok "  $f: $level"
                set gpu_ok true
            else
                _fail "  $f: $level (expected: $GPU_DPM_LEVEL)"
            end
        end
    end
    if test "$found_gpu" = false
        _warn "  No GPU DPM sysfs entries found"
    else if test "$gpu_ok" = false
        _warn "  GPU not at '$GPU_DPM_LEVEL' — check dmesg for amdgpu errors"
    end
end
function _vrk_cpu_state --description "Runtime kparam check: CPU governor/EPP + amd_pstate + boost"
    _echo "── CPU performance ──"
    set -g _CPU_PATH ""; for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq; if test -d "$cpu_dir"; set -g _CPU_PATH "$cpu_dir"; break; end; end
    if test -z "$_CPU_PATH"
        _warn "  No CPU frequency scaling found"
    else
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_CPU_PATH")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:amd-pstate-epp:Scaling driver" \
            "scaling_governor:$CPUPOWER_GOVERNOR:Governor" # driver + governor profile-managed
            set -l parts (string split ':' -- "$check"); set -l sysfs_val (command cat -- "$_CPU_PATH/$parts[1]" 2>/dev/null)
            _chk_eq "$parts[3]" "$sysfs_val" "$parts[2]"
        end
        set -l _epp (command cat -- "$_CPU_PATH/energy_performance_preference" 2>/dev/null) # EPP pinned via 99-ry-perf.rules
        if test -n "$_epp"
            _chk_eq "EPP" "$_epp" balance_performance
        else
            _info "  EPP: unreadable"
        end
    end
    _echo
    _echo "── amd_pstate / CPU boost ──"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/status active "amd_pstate status"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/prefcore enabled "amd_pstate prefcore"
    _chk_sysfs_eq /sys/devices/system/cpu/cpufreq/boost 1 "CPU boost"
    _echo
end
function _vrkm_amdgpu --description "_vrk_module_state sub: amdgpu parameters (hex-aware compare; expected from KERNEL_PARAMS)"
    test -d /sys/module/amdgpu/parameters; or return 0
    set -l _pairs
    for _kp in $KERNEL_PARAMS
        string match -q 'amdgpu.*=*' -- "$_kp"; and set -a _pairs (string replace -r '^amdgpu\.([^=]+)=' '$1:' -- "$_kp")
    end
    test (count $_pairs) -eq 0; and return 0 # no amdgpu.* module params in KERNEL_PARAMS
    for pair in $_pairs
        set -l _p (string split ':' -- "$pair"); set -l pname $_p[1]; set -l expected $_p[2]; set -l ppath /sys/module/amdgpu/parameters/$pname
        test -f "$ppath"; or continue
        set -l sysfs_val (string trim -- (command cat -- "$ppath" 2>/dev/null)); set -l sysfs_val_dec "$sysfs_val"; set -l expected_dec "$expected"
        string match -qr '^0x[0-9a-fA-F]+$' -- "$sysfs_val"; and set sysfs_val_dec (printf '%d' "$sysfs_val" 2>/dev/null; or echo "$sysfs_val") # normalize to decimal (amdgpu sysfs hex or decimal)
        string match -qr '^0x[0-9a-fA-F]+$' -- "$expected"; and set expected_dec (printf '%d' "$expected" 2>/dev/null; or echo "$expected")
        if test "$sysfs_val_dec" = "$expected_dec"
            _ok "  amdgpu.$pname: $sysfs_val"
        else
            _fail "  amdgpu.$pname: $sysfs_val (expected: $expected)"
        end
    end
end
function _vrkm_blacklist --description "_vrk_module_state sub: module_blacklist= scan from KERNEL_PARAMS"
    set -l _bl_mods
    for _kp in $KERNEL_PARAMS
        if string match -q 'module_blacklist=*' -- "$_kp"; set _bl_mods (string split ',' -- (string replace 'module_blacklist=' '' -- "$_kp")); break; end
    end
    if test (count $_bl_mods) -eq 0; _info "  No module_blacklist= entry in KERNEL_PARAMS"; return 0; end
    if not command -q lsmod; _warn "  module_blacklist: lsmod absent — cannot verify load state"; return 0; end
    for mod in $_bl_mods
        set -l _mod_lsmod (string replace -a -- '-' '_' "$mod")
        if command env LC_ALL=C lsmod 2>/dev/null | command grep -q -- "^$_mod_lsmod "
            _fail "  $mod: LOADED (should be blacklisted)"
        else
            _ok "  $mod: not loaded"
        end
    end
end
function _vrk_module_state --description "Runtime kparam check: module parameters + blacklist"
    _echo "MODULE STATE"
    _echo
    _echo "── Module parameters ──"
    _chk_sysfs_eq /sys/module/usbcore/parameters/autosuspend -1 "usbcore.autosuspend"
    _chk_sysfs_eq /sys/module/nvme_core/parameters/default_ps_max_latency_us 0 "nvme_core.default_ps_max_latency_us"
    _vrkm_amdgpu
    _echo "── Additional module parameters ──"
    _chk_sysfs_match /sys/module/zswap/parameters/enabled '^[N0]$' zswap.enabled
    _chk_sysfs_eq /proc/sys/kernel/nmi_watchdog 0 nmi_watchdog
    _echo
    _echo "── I/O scheduler (NVMe) ──"
    set -l _nvme_bdevs (command find /sys/block -mindepth 1 -maxdepth 1 -name 'nvme*n*' 2>/dev/null)
    if test (count $_nvme_bdevs) -eq 0; _info "  No NVMe block device present"; end
    for _bdev in $_nvme_bdevs
        _chk_sysfs_match "$_bdev/queue/scheduler" '\[none\]' "io-sched "(command basename -- "$_bdev")
    end
    _echo
    _echo "── Blacklisted modules ──"
    _vrkm_blacklist
    _echo
end
function _vrk_clocksource --description "Runtime kparam check: clocksource (with TSC demotion correlation)"
    _echo "── Clocksource ──"
    if test -f /sys/devices/system/clocksource/clocksource0/current_clocksource
        set -l _cs (command cat -- /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null | string trim --)
        if test "$_cs" = tsc
            _ok "  clocksource: $_cs"
        else if test "$_cs" = hpet
            _fail "  clocksource: $_cs (expected: tsc — HPET has 10–100× higher read latency)"
            set -l _tsc_demote $_RY_DMESG_TSC
            if test -n "$_tsc_demote"
                for _l in $_tsc_demote; _info "  dmesg: $_l"; end
            else if test "$_RY_DMESG_LINES" -eq 0
                _info "  dmesg: cannot scan (sudo lapsed or dmesg unavailable — TSC demotion check skipped)"
            else
                _info "  dmesg: no TSC demotion markers found — check BIOS/firmware"
            end
        else
            _warn "  clocksource: $_cs (expected: tsc)"
        end
    end
    _echo
end

# ── VERIFY-RUNTIME: KPARAMS ORCHESTRATOR (_verify_runtime_kparams) ──
function _verify_runtime_kparams --description "Verify /proc/cmdline, hardware state, module params, blacklist, clocksource"
    set -g _RY_DMESG_LINES 0; set -g _RY_DMESG_PREEMPT; set -g _RY_DMESG_TSC
    if command -q dmesg; and command -q sudo; and sudo -n true 2>/dev/null
        set -l _full (sudo -n dmesg 2>/dev/null); set -l _full_count (count $_full)
        if test "$_full_count" -gt 0
            set -g _RY_DMESG_PREEMPT (printf '%s\n' $_full | command grep -o 'Dynamic Preempt: [a-z]*' | command head -n 1)
            set -g _RY_DMESG_TSC (printf '%s\n' $_full | command grep -iE 'Marking TSC unstable|TSC: Marking|clocksource.*tsc.*unstable' | command head -n 3)
        end
        set -g _RY_DMESG_LINES $_full_count
    end
    if test "$_RY_DMESG_LINES" -eq 0
        if not command -q dmesg
            _log "DMESG_CACHE_EMPTY: dmesg(1) not installed"
        else if not command -q sudo
            _log "DMESG_CACHE_EMPTY: sudo not installed"
        else if not sudo -n true 2>/dev/null
            _log "DMESG_CACHE_EMPTY: sudo cache lapsed"
        else
            _log "DMESG_CACHE_EMPTY: dmesg returned empty (kernel.dmesg_restrict or empty ring buffer)"
        end
    end
    _vrk_cmdline
    _vrk_gpu_state
    _vrk_cpu_state
    _vrk_module_state
    _vrk_clocksource
    set --erase _RY_DMESG_LINES _RY_DMESG_PREEMPT _RY_DMESG_TSC
end

# ── VERIFY-RUNTIME: SERVICES (units, resolved, NM, cpupower, wifi, masks) ──
function _vrsv_chk_active_enabled --argument-names label rec_str --description "Helper: ok if active+enabled, warn if active only, fail otherwise"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found
        _warn "  $label: not installed"
        return 0
    else if test "$rec[2]" = active
        if test "$rec[3]" = enabled
            _ok "  $label: active (enabled)"
        else
            _warn "  $label: active but $rec[3] (will not persist)"
        end
    else
        _fail "  $label: $rec[2] (expected: active)"
    end
end
function _vrsv_nft_assert_ndp --description "_vrsv_chk_nftables sub: assert live input chain accepts ICMPv6 NDP (warn-only; missing breaks IPv6 after NDP cache expiry)"
    set -l _chain (_as true env LC_ALL=C nft list chain inet filter input 2>/dev/null)
    if string match -q -- '*nd-neighbor-solicit*' $_chain
        _ok "  nftables: live ICMPv6 NDP/PMTUD accept present"
    else
        _warn "  nftables: live input chain has no ICMPv6 NDP accept — IPv6 may break after NDP cache expiry"
    end
end
function _vrsv_chk_nftables --argument-names label rec_str --description "Check nftables.service: oneshot without RemainAfterExit reads inactive after a clean load — judge by live ruleset"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found; _warn "  $label: not installed"; return 0; end
    set -l _nft_probe_ok false
    command -q nft; and sudo -n true 2>/dev/null; and set _nft_probe_ok true
    if test "$rec[2]" = active
        _vrsv_chk_active_enabled $label "$rec_str"
        test "$_nft_probe_ok" = true; and _vrsv_nft_assert_ndp # NDP assert independent of unit-state path
        return 0
    end
    if not command -q nft
        _fail "  $label: $rec[2] and nft(8) absent — live ruleset unverifiable"
        return 0
    end
    if test "$_nft_probe_ok" = false
        _warn "  $label: $rec[2] — sudo cache lapsed, live ruleset unverifiable"
        return 0
    end
    set -l _input (_as true env LC_ALL=C nft list chain inet filter input 2>/dev/null)
    if not string match -q -- '*policy drop*' $_input
        _fail "  $label: $rec[2] and no live inet/filter/input chain with policy drop"
        return 0
    end
    if test "$rec[3]" = enabled
        _ok "  $label: ruleset live, input policy drop ($rec[2] — oneshot, no RemainAfterExit)"
    else
        _warn "  $label: ruleset live but unit $rec[3] (will not persist across boots)"
    end
    _vrsv_nft_assert_ndp
    return 0
end
function _vrsv_chk_resolved --argument-names rec_str --description "Check systemd-resolved active state, only when conf.d drop-in is deployed"
    set -l rec (string split ':' -- "$rec_str")
    test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf; or return 0
    if test "$rec[2]" = active
        _ok "  systemd-resolved: active"
    else
        _fail "  systemd-resolved: $rec[2] (expected: active — DNS may be broken)"
    end
end
function _vrsv_chk_cpupower_governor --argument-names rec_str --description "Check cpupower.service (RemainAfterExit oneshot reads active); governor applied from /etc/default/cpupower-service.conf"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found; _warn "  cpupower.service: not installed (cpupower is a CachyOS default; pacman db may be stale)"; return 0; end
    if test "$rec[2]" = active
        if test "$rec[3]" = enabled
            _ok "  cpupower.service: $rec[2] (enabled)"
        else
            _warn "  cpupower.service: $rec[2] but $rec[3] (will not persist)"
        end
        return 0
    end
    _fail "  cpupower.service: $rec[2] (expected: active)"
end
function _vrsv_sys_units --description "Runtime services check: conf.d-implied + EXPECTED_SERVICES (per-unit dispatch)"
    set -l sys_units (_implicit_confd_units)
    for _e in $EXPECTED_SERVICES; contains -- $_e $sys_units; or set -a sys_units $_e; end
    for _u in $sys_units
        set -l _v (_unit_state_padded $_u); set -l _rec "$_v[1]:$_v[2]:$_v[3]"
        switch "$_u"
            case systemd-resolved.service
                _vrsv_chk_resolved "$_rec"
            case cpupower.service
                _vrsv_chk_cpupower_governor "$_rec"
            case nftables.service
                _vrsv_chk_nftables $_u "$_rec"
            case '*'
                _vrsv_chk_active_enabled $_u "$_rec"
        end
    end
end
function _vrsv_wifi_nm_backend --description "_vrsv_wifi sub: verify NM effective wifi.backend vs NM_WIFI_BACKEND"
    if not command -q NetworkManager
        _info "  NetworkManager binary absent — backend check skipped"
        return 0
    end
    set -l _eff (_as true NetworkManager --print-config 2>/dev/null \
        | command grep -E -- '^[[:space:]]*wifi\.backend[[:space:]]*=' \
        | command head -n1 | string replace -r '.*=[[:space:]]*' '' | string trim --)
    if test -z "$_eff"
        if not sudo -n true 2>/dev/null
            _warn "  NM effective wifi.backend: sudo cache lapsed — cannot determine"
            return 0
        end
        _info "  NM effective wifi.backend: unset (NM default is wpa_supplicant)"
        test "$NM_WIFI_BACKEND" != wpa_supplicant; and _fail "  NM backend: expected $NM_WIFI_BACKEND, none configured (drop-in not active)"
    else if test "$_eff" = "$NM_WIFI_BACKEND"
        _ok "  NM effective wifi.backend: $_eff"
    else
        _fail "  NM effective wifi.backend: $_eff (expected: $NM_WIFI_BACKEND)"
    end
end
function _vrsv_wifi_iwd_proc --description "_vrsv_wifi sub: report iwd process state vs NM_WIFI_BACKEND"
    command -q pgrep; or return 0
    if command pgrep -x iwd >/dev/null
        if test "$NM_WIFI_BACKEND" = iwd
            _info "  iwd process: running (NM-activated)"
        else
            _warn "  iwd process: running (unexpected — NM backend is $NM_WIFI_BACKEND; iwd should be inactive)"
        end
    else if test "$NM_WIFI_BACKEND" = iwd
        _info "  iwd process: not currently active (NM activates it on demand)"
    else
        _info "  iwd process: inactive (expected — NM backend is $NM_WIFI_BACKEND)"
    end
end
function _vrsv_wifi --description "Runtime services check: WiFi + iwd backend + NM state"
    _echo
    _echo "WIFI STATE"
    _echo
    if test "$_RY_PROFILE_USES_WIFI_BACKEND" = false
        _info "  iwd/NetworkManager not managed — skipping WiFi state checks"
        return 0
    end
    set -l wlan_iface ""
    for iface in /sys/class/net/*/wireless
        if test -d "$iface"; set wlan_iface (command basename -- (command dirname -- "$iface")); break; end
    end
    if test -n "$wlan_iface"
        _ok "  WiFi interface: $wlan_iface"
    else
        _warn "  WiFi interface: NOT DETECTED"
    end
    _vrsv_wifi_iwd_proc
    _vrsv_wifi_nm_backend
    if command -q nmcli
        set -l nm_wifi_enabled (command nmcli -t -f WIFI general 2>/dev/null | string trim --)
        test -n "$nm_wifi_enabled"; and _info "  NM wifi radio: $nm_wifi_enabled"
        set -l wifi_state (command nmcli -t -f TYPE,STATE device 2>/dev/null | string match -rg -- '^wifi:(.*)$')[1]
        if test "$wifi_state" = connected
            _ok "  WiFi device: connected"
        else if test -n "$wifi_state"
            _warn "  WiFi device: $wifi_state (not connected)"
        end
    end
    set -l _ufw (command systemctl is-active ufw.service 2>/dev/null | string trim --)
    set -l _nft n/a # n/a=nft absent, unknown=sudo lapse, else count
    if command -q nft
        if sudo -n true 2>/dev/null
            set _nft (_as true env LC_ALL=C nft -a list ruleset 2>/dev/null | command grep -E -- '# handle [0-9]+$' | command grep -cvE -- '\{ # handle [0-9]+$')
            string match -qr '^\d+$' -- "$_nft"; or set _nft unknown
        else
            set _nft unknown
        end
    end
    _info "  firewall posture: ufw=$_ufw nft_rules=$_nft"
end
function _vrsv_masked_inactive --description "Runtime services check: MASK units must be inactive"
    _echo
    _echo "── Masked units (runtime) ──"
    for _u in $MASK
        set -l _v (_unit_state_padded $_u)
        if test "$_v[3]" = ERR_NO_DATA
            _warn "  $_u: systemctl state unavailable (absent or no running manager) — cannot verify"
        else if test "$_v[1]" = not-found
            _info "  $_u: not installed"
        else if test "$_v[2]" = active
            _fail "  $_u: ACTIVE (masked but still running — stop or reboot)"
        else
            _ok "  $_u: $_v[2]"
        end
    end
end

# ── VERIFY-RUNTIME: SERVICES ORCHESTRATOR (_verify_runtime_services) ──
function _verify_runtime_services --description "Verify systemd unit states (sys batch) and WiFi runtime"
    _echo "SERVICE STATE"
    _echo
    _vrsv_sys_units
    _vrsv_masked_inactive
    _vrsv_wifi
    return 0
end

# ── VERIFY-RUNTIME: ENVIRONMENT ──
function _vre_envvars --description "Runtime env check: ENV_VARS via systemctl --user show-environment"
    _echo "ENVIRONMENT STATE"
    _echo
    if not _has_user_bus_active; _info "  Skipping ENV_VARS runtime check (no active user-bus — log in graphically or enable-linger to verify)"; _echo; return 0; end
    set -l _user_env (command systemctl --user show-environment 2>/dev/null)
    for exp in $ENV_VARS
        set -l _ev_parts (string split -m1 '=' -- "$exp"); set -l var_name $_ev_parts[1]; set -l expected $_ev_parts[2]; set -l actual ""
        if test -n "$_user_env"; set -l _vn_re (string escape --style=regex -- $var_name); set actual (printf '%s\n' $_user_env | string match -rg -- "^"$_vn_re"=(.*)"); set actual (string replace -r -- '^"(.*)"$' '$1' "$actual"); end # one matched quote pair
        if test "$actual" = "$expected"
            _ok "  $var_name=$actual"
        else if test -n "$actual"
            _fail "  $var_name=$actual (expected: $expected)"
        else
            _warn "  $var_name: NOT SET in current session (re-login or systemctl --user import-environment)"
        end
    end
    _echo
end
function _vre_sysctl_runtime --description "Runtime env check: sysctl values via /proc/sys"
    set -q SYSCTL_VALUES; and test (count $SYSCTL_VALUES) -gt 0; or return 0
    _echo "── sysctl (ry-install) ──"
    for entry in $SYSCTL_VALUES
        set -l _parts (string split -m1 '=' -- "$entry"); set -l _key $_parts[1]; set -l _expected $_parts[2]
        set -l _proc_path (string replace -a '.' '/' -- "$_key"); set -l _actual (command cat -- "/proc/sys/$_proc_path" 2>/dev/null | string replace -ra '\s+' ' ' | string trim --); set -l _expected_norm (string replace -ra '\s+' ' ' -- "$_expected")
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
function _vre_tcp --description "Runtime env check: tcp_bbr module version (active bbr value verified in sysctl block)"
    _echo "── TCP congestion control ──"
    if command -q modinfo
        set -l _bbr_ver (command modinfo tcp_bbr 2>/dev/null | command grep -i '^version:' | string replace -r -- '^version:\s*' '')
        if test -n "$_bbr_ver"
            _info "  tcp_bbr module version: $_bbr_ver (advisory — active selection asserted in sysctl block)" # module presence != load+select
        else
            _info "  tcp_bbr: version field not available"
        end
    end
    _echo
end
function _vre_zram --description "Runtime env check: zram service + active swap device"
    if not command -q swapon
        _warn "  ZRAM/swap check skipped: swapon(1) unavailable"
        return 0
    end
    set -l _zram_swap (command swapon --show=NAME,TYPE 2>/dev/null | command grep zram); set -l _zram_dev (printf '%s\n' $_zram_swap | string match -rg -- '(zram\d+)' | command head -n 1)
    test -z "$_zram_dev"; and set _zram_dev zram0
    set -l _zram_state (command systemctl is-enabled "systemd-zram-setup@$_zram_dev.service" 2>/dev/null | string trim --)
    switch "$_zram_state"
        case masked
            _warn "  ZRAM service: masked (out-of-scope advisory; not managed by this profile)"
        case enabled
            _ok "  ZRAM service: enabled"
        case static
            if test -n "$_zram_swap"
                _ok "  ZRAM service: static (template instantiated by zram-generator)"
            else
                _warn "  ZRAM service: static but no zram swap device active"
            end
        case ''
            _warn "  ZRAM service: not found"
        case '*'
            _warn "  ZRAM service: $_zram_state (expected: enabled or static+active)"
    end
    _echo "── ZRAM ──"
    if test -n "$_zram_swap"
        set -l _zram_info ""
        command -q zramctl; and set _zram_info (command zramctl --output NAME,ALGORITHM,DISKSIZE,TOTAL,COMP-RATIO --noheadings 2>/dev/null | command head -n 1 | string trim --)
        _ok "  ZRAM swap active: $_zram_info"
    else
        set -l _any_swap (command swapon --show=NAME,SIZE 2>/dev/null | command tail -n +2)
        if test -z "$_any_swap"
            _warn "  No swap available (out-of-scope advisory; ZRAM/swap not managed by this profile)"
        else
            _warn "  ZRAM not active but other swap found: $_any_swap"
        end
    end
end
function _vre_fstab --description "Runtime env check: fstab ext4 entries have noatime,lazytime,commit=10"
    _echo "── fstab mount options ──"
    set -l _fstab_ext4; set -l _fstab_malformed
    if test -r /etc/fstab
        set _fstab_ext4 (command awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
        set _fstab_malformed (command awk "$_RY_AWK_EXT4_MALFORMED_FILTER" /etc/fstab 2>/dev/null)
    else if sudo -n test -r /etc/fstab 2>/dev/null
        set _fstab_ext4 (sudo -n awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
        set _fstab_malformed (sudo -n awk "$_RY_AWK_EXT4_MALFORMED_FILTER" /etc/fstab 2>/dev/null)
    else
        _warn "  /etc/fstab not readable (even via sudo) — skipping mount-option check"
        return 0
    end
    for _ml in $_fstab_malformed; _warn "  /etc/fstab: ext4-like entry with too few fields (review manually): $_ml"; end
    if test -z "$_fstab_ext4"; _info "  No ext4 entries in /etc/fstab"; return 0; end
    set -l _fstab_ok true
    for _fl in $_fstab_ext4
        set -l _opts (printf '%s\n' "$_fl" | command awk '{ print $4 }')
        for _tok in noatime lazytime commit=10 # boundary avoids lazytime matching nolazytime
            set -l _re (string escape --style=regex -- "$_tok")
            if not string match -qr '(^|,)'$_re'(,|$)' -- "$_opts"; _fail "  ext4 entry missing $_tok: $_fl"; set _fstab_ok false; end
        end
        for _conflict in relatime atime strictatime # contradict noatime (kernel honours last)
            set -l _cre (string escape --style=regex -- "$_conflict")
            if string match -qr '(^|,)'$_cre'(,|$)' -- "$_opts"; _fail "  ext4 entry has $_conflict alongside noatime (contradictory): $_fl"; set _fstab_ok false; end
        end
    end
    test "$_fstab_ok" = true; and _ok "  ext4 entries: noatime,lazytime,commit=10 present"
end
function _vre_ntsync --description "Runtime env check: ntsync state via _ntsync_state dispatch"
    _echo
    _echo "── ntsync support ──"
    set -l _ns (_ntsync_state)
    switch "$_ns"
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
        case missing
            _info "ntsync: NOT available (module not loaded)"
        case '*'
            _warn "ntsync: unknown state '$_ns'"
    end
    _echo
end
function _vre_regdom --description "Runtime env check: wireless regulatory domain via iw reg get"
    _echo
    _echo "── wireless regdom ──"
    if not command -q iw
        _info "regdom: iw(8) absent — cannot query (expected $COUNTRY)"
        _echo
        return 0
    end
    if command env LC_ALL=C iw reg get 2>/dev/null | string match -qr -- "^country $COUNTRY"
        _ok "regdom: country $COUNTRY active"
    else
        _warn "regdom: country $COUNTRY not active — sudo iw reg set $COUNTRY (persists via /etc/iw-regdomain → cachyos-iw-set-regdomain)"
    end
    _echo
end

# ── VERIFY-RUNTIME: ENV ORCHESTRATOR (_verify_runtime_env) ──
function _verify_runtime_env --description "Verify ENV_VARS, sysctl, TCP, ZRAM, fstab, ntsync, regdom runtime"
    _vre_envvars
    _vre_sysctl_runtime
    _vre_tcp
    _vre_zram
    _vre_fstab
    _vre_ntsync
    _vre_regdom
end

# ── VERIFY-RUNTIME: SESSION + PERMS ──
function _vrs_nm_perms --description "Runtime session check: NetworkManager system-connections perms (0600 root:root)"
    set -l nm_conn_dir /etc/NetworkManager/system-connections
    if not test -d "$nm_conn_dir"; _info "  NetworkManager connections: directory not found"; return 0; end
    set -l conn_files (sudo -n find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f -print0 2>/dev/null | string split0); set -l _conn_ps $pipestatus
    if test "$_conn_ps[1]" -ne 0; _warn "  NetworkManager connections: cannot enumerate (sudo lapse or read error)"; return 0; end
    if test (count $conn_files) -gt 0
        set -l bad_perms 0
        for conn_file in $conn_files; _chk_perms "$conn_file" 600 root:root true; or set bad_perms (math $bad_perms + 1); end
        if test "$bad_perms" -eq 0; set -l conn_count (count $conn_files); _ok "  NetworkManager connections: $conn_count files with correct permissions"; end
    else if begin; command grep -q -- 'wifi.backend=' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null; or begin; not test -r /etc/NetworkManager/conf.d/99-cachyos-nm.conf; and sudo -n grep -q -- 'wifi.backend=' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null; end; end # sudo fallback if drop-in tightened to 0600
        _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
    else
        _info "  NetworkManager connections: no .nmconnection files found"
    end
end
function _vrs_vfat_skip --argument-names path boot_fstype --description "rc 0 = vfat/undetermined boot path (perms not verifiable, _info emitted); rc 1 = checkable"
    set -l _fst (command findmnt -n -o FSTYPE --target "$path" 2>/dev/null | string trim --) # Per-path fstype
    test -z "$_fst"; and set _fst "$boot_fstype"
    if test "$_fst" = vfat; _info "  $path: skipped (vfat — unix perms synthesized from mount options)"; return 0; end
    if test -z "$_fst"; _info "  $path: skipped (boot fstype undetermined — vfat-safe default)"; return 0; end
    return 1
end
function _vrs_installed_file_perms --description "Runtime session check: installed system/service/user file perms"
    _echo "── Installed files ──"
    set -l perm_bad 0; set -l perm_checked 0; set -l perm_vfat_skipped 0; set -l _boot_resolved (_resolve_boot_path)
    test -z "$_boot_resolved"; and set _boot_resolved /boot
    set -l _boot_fstype (command findmnt -n -o FSTYPE "$_boot_resolved" 2>/dev/null | string trim --)
    for dst in $SYSTEM_DESTINATIONS
        if sudo -n test -f "$dst" 2>/dev/null
            if string match -q '/boot/*' -- "$dst"
                if _vrs_vfat_skip "$dst" "$_boot_fstype"; set perm_vfat_skipped (math $perm_vfat_skipped + 1); continue; end
            end
            set perm_checked (math $perm_checked + 1)
            _chk_perms "$dst" 644 root:root true; or set perm_bad (math $perm_bad + 1)
        else if not sudo -n true 2>/dev/null # lapse mid-loop: warn once, stop
            _warn "  Installed-file perms: sudo cache lapsed — remaining system files skipped"
            break
        end
    end
    set -l _u_uname (command id -un)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            set -l _actual_grp (command stat -c '%G' -- "$dst" 2>/dev/null) # group from file %G (tolerates setgid ~/.config)
            test -z "$_actual_grp"; and set _actual_grp (command id -gn)
            _chk_perms "$dst" 600 "$_u_uname:$_actual_grp" false; or set perm_bad (math $perm_bad + 1)
        end
    end
    test "$perm_bad" -eq 0; and test "$perm_checked" -gt 0; and _ok "  All $perm_checked installed files: correct permissions and ownership"
    test "$perm_checked" -eq 0; and _warn "  No installed files found to check"
    test "$perm_vfat_skipped" -gt 0; and _info "  $perm_vfat_skipped file(s) skipped on boot partition (vfat or undetermined fstype — unix perms not verifiable)"
end
function _vpd_dir_perm_check --argument-names dir expected_owner use_sudo --description "_vrs_parent_dirs sub: stat + owner + group/world-write check (rc 1 = bad)"
    set -l _po
    if test "$use_sudo" = true
        set _po (sudo -n stat -c '%a %U:%G' -- "$dir" 2>/dev/null)
    else
        set _po (command stat -c '%a %U' -- "$dir" 2>/dev/null)
    end
    if test -z "$_po"; _fail "  $dir: stat failed"; return 1; end
    set -l _p (string split ' ' -- "$_po")
    if test "$_p[2]" != "$expected_owner"
        _fail "  $dir: $_p[1] $_p[2] (expected owner: $expected_owner)"
        return 1
    end
    if _dir_group_or_world_writable "$_p[1]"
        _fail "  $dir: $_p[1] (writable by group/other)"
        return 1
    end
    return 0
end
function _vrs_parent_dirs --description "Runtime session check: parent dirs of managed files (system root-owned; user dir user-owned)"
    _echo "── Parent directories ──"
    set -l dir_bad 0; set -l dir_checked 0; set -l dir_vfat_skipped 0; set -l checked_dirs
    set -l _boot_resolved (_resolve_boot_path)
    test -z "$_boot_resolved"; and set _boot_resolved /boot
    set -l _boot_fstype (command findmnt -n -o FSTYPE "$_boot_resolved" 2>/dev/null | string trim --)
    for dst in $SYSTEM_DESTINATIONS
        set -l dir (command dirname -- "$dst")
        contains -- "$dir" $checked_dirs; and continue
        set -a checked_dirs "$dir"
        if sudo -n test -d "$dir" 2>/dev/null
            if test "$dir" = /boot; or string match -q '/boot/*' -- "$dir" # FAT stores no unix perms
                if _vrs_vfat_skip "$dir" "$_boot_fstype"; set dir_vfat_skipped (math $dir_vfat_skipped + 1); continue; end
            end
            set dir_checked (math $dir_checked + 1)
            _vpd_dir_perm_check "$dir" root:root true; or set dir_bad (math $dir_bad + 1)
        else if not sudo -n true 2>/dev/null # Lapse mid-loop: warn once, stop.
            _warn "  Parent dirs: sudo cache lapsed — remaining system dirs skipped"
            break
        end
    end
    set -l _u_uname (command id -un)
    for dst in $USER_DESTINATIONS
        set -l dir (command dirname -- "$dst")
        contains -- "$dir" $checked_dirs; and continue
        set -a checked_dirs "$dir"
        test -d "$dir"; or continue
        set dir_checked (math $dir_checked + 1)
        _vpd_dir_perm_check "$dir" "$_u_uname" false; or set dir_bad (math $dir_bad + 1)
    end
    test "$dir_bad" -eq 0; and test "$dir_checked" -gt 0; and _ok "  All $dir_checked parent directories: correct ownership, not world/group-writable"
    test "$dir_checked" -eq 0; and _warn "  No parent directories found to check"
    test "$dir_vfat_skipped" -gt 0; and _info "  $dir_vfat_skipped dir(s) skipped on boot partition (vfat or undetermined fstype — unix perms not verifiable)"
end
function _vrs_vulkan --description "Runtime session check: Vulkan driver packages (DXVK/VKD3D-Proton dependency)"
    _echo
    _echo "PACKAGE MANAGEMENT"
    _echo
    _echo "── Vulkan driver packages ──"
    if not set -q EXPECTED_VULKAN_PKGS; or test (count $EXPECTED_VULKAN_PKGS) -eq 0; _info "  EXPECTED_VULKAN_PKGS not defined — skipping"; return 0; end
    if not command -q pacman; _warn "  Vulkan packages: pacman not found — skipping"; return 0; end
    set -l _vk_installed (command pacman -Qq 2>/dev/null)
    if test "$status" -ne 0 # db lock/read error: empty list misreports
        _warn "  Vulkan packages: pacman -Qq failed (db locked or read error) — skipping"
        _log "VULKAN_QQ_FAIL: pacman -Qq returned non-zero"
        return 0
    end
    set -l _vk_missing_list
    for _vk_pkg in $EXPECTED_VULKAN_PKGS
        if contains -- "$_vk_pkg" $_vk_installed
            _ok "  $_vk_pkg: installed"
        else
            _fail "  $_vk_pkg: NOT installed (DXVK/VKD3D-Proton requires this)"
            set -a _vk_missing_list "$_vk_pkg"
        end
    end
    test (count $_vk_missing_list) -gt 0; and _info "  Install missing: sudo pacman -S --needed $_vk_missing_list"
end

# ── VERIFY-RUNTIME: SESSION ORCHESTRATOR (_verify_runtime_session) ──
function _verify_runtime_session --description "Verify NM connection perms, installed-file perms, parent dirs, Vulkan packages"
    _echo "FILE PERMISSIONS"
    _echo "── Sensitive files ──"
    _vrs_nm_perms
    _vrs_installed_file_perms
    _vrs_parent_dirs
    _vrs_vulkan
end

# ── VERIFY: TOP-LEVEL ORCHESTRATORS (_ry_verify_runtime + _ry_verify_all) ──
function _ry_verify_runtime --description "Verify runtime kernel params, services, environment, and session/permissions"
    _log_section "RUNTIME VERIFICATION START"
    _ensure_sudo_cached; or begin
        _err_loud "sudo required for verification"
        return $EXIT_PREFLIGHT
    end
    set -g VERIFY_OK 0; set -g VERIFY_FAIL 0; set -g VERIFY_WARN 0; set -g VERIFY_GEN_FAIL 0
    _info "Runtime verification (live system state)..."
    _verify_runtime_kparams
    _verify_runtime_services
    _verify_runtime_env
    _verify_runtime_session
    _log_section "RUNTIME VERIFICATION END"
    _verify_summary
    set -l ret $status
    return $ret
end
function _ry_verify_all --description "Verify both: static configs + runtime state; FAIL if either fails. Footer = combined counts"
    _ry_verify_static; set -l _rc_s $status
    test "$_rc_s" -eq "$EXIT_PREFLIGHT"; and return $_rc_s
    set -l _s_ok $VERIFY_OK; set -l _s_fail $VERIFY_FAIL; set -l _s_warn $VERIFY_WARN; set -l _s_gen $VERIFY_GEN_FAIL
    _ry_verify_runtime; set -l _rc_r $status
    if test "$_rc_r" -eq "$EXIT_PREFLIGHT"
        set -g VERIFY_OK $_s_ok; set -g VERIFY_FAIL $_s_fail; set -g VERIFY_WARN $_s_warn; set -g VERIFY_GEN_FAIL $_s_gen # restore VERIFY_* static totals after bail
        test "$_rc_s" -ne 0; and return $_rc_s # static FAIL outranks runtime preflight bail
        return $_rc_r
    end
    set -g VERIFY_OK (math $VERIFY_OK + $_s_ok)
    set -g VERIFY_FAIL (math $VERIFY_FAIL + $_s_fail)
    set -g VERIFY_WARN (math $VERIFY_WARN + $_s_warn)
    set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + $_s_gen)
    set -l _vt_lvl OK
    if test "$VERIFY_FAIL" -gt 0; or test "$VERIFY_GEN_FAIL" -gt 0
        set _vt_lvl FAIL
    else if test "$VERIFY_WARN" -gt 0
        set _vt_lvl WARN
    end
    set -l _vt "Combined (static + runtime): $VERIFY_OK OK"
    test "$VERIFY_WARN" -gt 0; and set _vt "$_vt, $VERIFY_WARN WARN"
    test "$VERIFY_FAIL" -gt 0; and set _vt "$_vt, $VERIFY_FAIL FAIL"
    test "$VERIFY_GEN_FAIL" -gt 0; and set _vt "$_vt, $VERIFY_GEN_FAIL GEN_FAIL"
    _msg_nocount $_vt_lvl "$_vt"
    _log "VERIFY_RESULT_COMBINED: ok=$VERIFY_OK fail=$VERIFY_FAIL warn=$VERIFY_WARN gen_fail=$VERIFY_GEN_FAIL"
    test "$_rc_r" -ne 0; and return $_rc_r
    return $_rc_s
end

# ── MISC HELPERS: PERM CHECK, WIFI ROUTE, USER-BUS, SUDO BANNER ──
function _dir_group_or_world_writable --argument-names mode --description "True when octal mode has group or world write bit (unparseable mode reads as writable — fail-closed)"
    not string match -qr '^[0-7]+$' -- "$mode"; and return 0 # unparseable mode -> writable (fail-closed)
    test (string length -- "$mode") -gt 3; and set mode (string sub -s -3 -- "$mode") # drop special-bits digit
    while test (string length -- "$mode") -lt 3; set mode "0$mode"; end # stat %a strips leading zeros
    set -l group_w (string sub -s 2 -l 1 -- "$mode"); set -l other_w (string sub -s 3 -l 1 -- "$mode"); set -l group_has_w (math "floor($group_w / 2) % 2"); set -l other_has_w (math "floor($other_w / 2) % 2")
    test "$group_has_w" -eq 1; and return 0
    test "$other_has_w" -eq 1; and return 0
    return 1
end
function _is_wifi_active_route --description "True if default route exits via wireless interface"
    command -q ip; or return 1
    set -l _def_iface ""
    for _af in -4 -6; set _def_iface (command ip $_af route show default 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}'); test -n "$_def_iface"; and break; end
    if test -z "$_def_iface" # default route may live in a non-main table
        for _af in -4 -6; set _def_iface (command ip $_af route show default table all 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}'); test -n "$_def_iface"; and break; end
    end
    test -z "$_def_iface"; and return 1
    test -d "/sys/class/net/$_def_iface/wireless"; and return 0
    switch "$_def_iface"
        case 'tun*' 'tap*' 'wg*' 'ppp*' 'gre*' 'gretap*' 'sit*' 'ip6tnl*' 'ipip*' 'br*' 'macvlan*' 'macvtap*' 'vlan*' 'bond*' 'geneve*' 'vxlan*' 'nlmon*' # fish lacks [..] globs
            for _phy in /sys/class/net/*/wireless
                test -d "$_phy"; or continue
                set -l _name (command basename -- (command dirname -- "$_phy")); set -l _state (command cat -- "/sys/class/net/$_name/operstate" 2>/dev/null | string trim --)
                test "$_state" = up; and return 0
            end
    end
    return 1
end
function _has_user_bus_active --description "True iff user systemd manager is reachable"
    set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"; and return 0
    set -l _user_state (command systemctl --user is-system-running 2>/dev/null | string trim --)
    test -n "$_user_state"; and test "$_user_state" != offline; and return 0
    return 1
end
function _ry_sudo_cache_banner --description "Install-mode warning: sudo cache may lapse mid-run"
    set -q _RY_OUTPUT_BROKEN; and return 0
    _log "SUDO_CACHE_BANNER: emitted (install-mode preflight)"
    printf '%s\n' "" \
        "[WARN] sudo cache may lapse during 3-8 min install. Mitigations:" \
        "[WARN]   Defaults timestamp_timeout=60 in /etc/sudoers, sudo -v keepalive in parallel shell," \
        "[WARN]   or NOPASSWD: ALL drop-in. Recovery: re-run ry-install (idempotent)." \
        "" >&2
end

# ── INSTALL PHASE 1: PREFLIGHT ──
function _ip_bail_prep --description "_install_preflight bail prep: clear LOUD_ERR, mark progress skip"; set --erase _RY_LOUD_ERR; set -g _PROG_FINALIZED_SKIP true; end
function _ry_check_umip_disabled --description "INFO when clearcpuid=514 (UMIP off) is active — flags the deliberate taint + loss of SGDT/SIDT/SMSW protection (advisory; non-fatal)"
    contains -- clearcpuid=514 $KERNEL_PARAMS; or return 0 # only relevant while UMIP is masked
    _info "  clearcpuid=514 active: UMIP disabled system-wide (SGDT/SIDT/SMSW no longer trapped) and kernel is tainted — intentional latency choice; drop the token to restore UMIP if no umip_printk stutter is observed"
    _log "UMIP_DISABLED: clearcpuid=514 present in KERNEL_PARAMS"
    return 0
end
function _install_preflight --description "Run all preflight checks before installation"
    _progress Preflight
    _ry_sudo_cache_banner
    set -g _RY_LOUD_ERR true; set -l _chk_labels "Preflight: sudo credential cache" "Preflight: dependency check" "Preflight: disk space"; set -l _i 1
    if test (count $_chk_labels) -ne 3; _err_loud "BUG: _chk_labels size drift (got "(count $_chk_labels)" expected 3)"; _ip_bail_prep; return $EXIT_PREFLIGHT; end
    for _chk in _ensure_sudo_cached _ry_check_deps _ry_check_disk_space
        if $_chk; _phase_record $_chk_labels[$_i] PASS "ok"; set _i (math $_i + 1); continue; end # _i advances on PASS only
        _phase_record $_chk_labels[$_i] FAIL "see JSONL log"
        _ip_bail_prep
        return $EXIT_PREFLIGHT
    end
    if not _ry_check_network
        set -l _net_ev "archlinux.org, cloudflare.com, 1.1.1.1, 8.8.8.8 unreachable" # normally overridden by _RY_NET_FAIL_EVIDENCE
        set -q _RY_NET_FAIL_EVIDENCE; and test -n "$_RY_NET_FAIL_EVIDENCE"; and set _net_ev "$_RY_NET_FAIL_EVIDENCE"
        _phase_record "Preflight: network reachability" FAIL "$_net_ev"
        _err "Network required for package installation — aborting"
        _ip_bail_prep
        return $EXIT_PREFLIGHT
    end
    _phase_record "Preflight: network reachability" PASS "ok"
    if _ry_check_time_sync
        _phase_record "Preflight: time sync" PASS "NTP synchronized"
    else
        _phase_record "Preflight: time sync" WARN "clock not NTP-synced or unverifiable"
    end
    set -l _mesa (command pacman -Q mesa 2>/dev/null | string split ' ')[2]
    if test -n "$_mesa"
        if not command -q vercmp
            _log "MESA_SOFT_FLOOR_SKIP: vercmp absent (pacman-provided) — gfx1151 mesa version not compared"
        else if test (command vercmp $_mesa 26.0) -lt 0
            _warn_loud "mesa $_mesa < 26.0 — gfx1151 RADV may be unstable (soft floor)"
            _log "MESA_BELOW_SOFT_FLOOR: $_mesa"
        end
    end
    set -l _fw (command pacman -Q linux-firmware 2>/dev/null | string split ' ')[2]
    set -l _fwver (string split '-' -- "$_fw")[1]
    if test -n "$_fwver"
        if string match -q '20251125*' -- "$_fwver"
            _warn_loud "linux-firmware $_fwver: known-bad MES blob (gfx1151 GCVM_L2 GPU hang) — upgrade to >= 20260110"
            _log "FW_BAD_MES_BLOB: $_fwver"
        else if command -q vercmp; and test (command vercmp $_fwver 20260110) -lt 0
            _warn_loud "linux-firmware $_fwver < 20260110 — pre-dates gfx1151 ROCm MES stability fix (soft floor)"
            _log "FW_BELOW_SOFT_FLOOR: $_fwver"
        end
    end
    _echo
    if not _ry_validate_configs; _phase_record "Preflight: config validation" FAIL "see JSONL log"; _err "Configuration validation failed - aborting"; _ip_bail_prep; return $EXIT_PREFLIGHT; end
    _phase_record "Preflight: config validation" PASS "$_RY_MANAGED_FILE_COUNT/$_RY_MANAGED_FILE_COUNT destinations"
    _ry_check_umip_disabled
    set --erase _RY_LOUD_ERR
    return 0
end

# ── MKINITCPIO.CONF: SNAPSHOT + REVERT (cp + size + cmp byte-exact) ──
function _mr_copy_cmp_verify --argument-names backup_file _mki_tmp --description "_mkinitcpio_revert sub: cp + byte-exact content verify (cmp)"
    if not sudo -n cp -- "$backup_file" "$_mki_tmp" 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at copy — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: cp $backup_file failed"
        return 1
    end
    if not command -q cmp
        _log "MKINITCPIO_REVERT_CMP_SKIP: cmp(1) absent — byte-exact verify skipped (cp rc=0 is the only gate)"
    else if not sudo -n cmp -s -- "$backup_file" "$_mki_tmp" 2>/dev/null # cmp -s: non-zero on any mismatch
        _err "  /etc/mkinitcpio.conf revert failed at cmp — content mismatch between backup and tmp"
        _log "MKINITCPIO_REVERT_FAIL: cmp content mismatch"
        return 1
    end
    return 0
end
function _mr_chmod_chown_mv --argument-names _mki_tmp --description "_mkinitcpio_revert sub: chmod/chown --reference + atomic mv"
    if not sudo -n chmod --reference=/etc/mkinitcpio.conf -- "$_mki_tmp" 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at chmod — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: chmod failed"
        return 1
    end
    if not sudo -n chown --reference=/etc/mkinitcpio.conf -- "$_mki_tmp" 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at chown — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: chown failed"
        return 1
    end
    if not sudo -n mv -T -- "$_mki_tmp" /etc/mkinitcpio.conf 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at atomic mv — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: mv failed"
        return 1
    end
    return 0
end
function _mkinitcpio_revert --argument-names backup_file --description "Restore /etc/mkinitcpio.conf from backup path (pacman -Syu rollback)"
    if test -z "$backup_file"; _err "  /etc/mkinitcpio.conf revert: empty backup_file path"; _log "MKINITCPIO_REVERT_FAIL: empty path"; return 1; end
    if not sudo -n test -f "$backup_file" 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at probe — backup file missing: $backup_file"
        _log "MKINITCPIO_REVERT_FAIL: backup file missing $backup_file"
        return 1
    end
    set -l _mki_tmp (sudo -n mktemp -p /etc .ry-install.mki.XXXXXX 2>/dev/null) # tmpfile in dst parent: same-FS mv -T atomic
    _track_tmpfile "$_mki_tmp"
    if test -z "$_mki_tmp"; _err "  /etc/mkinitcpio.conf revert failed at mktemp — current conf may reference uninstalled modules"; _log "MKINITCPIO_REVERT_FAIL: mktemp failed"; return 1; end
    if sudo -n test -L "$_mki_tmp" 2>/dev/null
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at symlink check — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: tmp is symlink"
        return 1
    end
    if not _mr_copy_cmp_verify "$backup_file" "$_mki_tmp"; _rm_tmp "$_mki_tmp" true; return 1; end
    if not _mr_chmod_chown_mv "$_mki_tmp"; _rm_tmp "$_mki_tmp" true; return 1; end
    _untrack_tmpfile "$_mki_tmp"
    _warn "  /etc/mkinitcpio.conf restored to pre-install content"
    _log "MKINITCPIO_REVERT_OK: pacman failure → restored backup from $backup_file"
    return 0
end
function _ip_snapshot_mkinitcpio --description "Snapshot /etc/mkinitcpio.conf for rollback"
    set -g _RY_MKI_BACKUP_FILE ""; set -g _RY_MKI_HAD_ORIG false
    if not sudo -n true 2>/dev/null; _log "MKINITCPIO_BACKUP_SKIPPED: sudo -n returned non-zero before snapshot"; return 0; end
    sudo -n test -f /etc/mkinitcpio.conf 2>/dev/null; or return 0
    sudo -n install -d -m 0700 -o root -g root /run/ry-install 2>/dev/null
    set -l _snap (sudo -n mktemp -p /run/ry-install ry-install.mki-snap.XXXXXX 2>/dev/null)
    if test -z "$_snap"; _warn "  mkinitcpio.conf snapshot skipped: mktemp failed (rollback will be unavailable)"; _log "MKINITCPIO_BACKUP_FAIL: mktemp"; return 0; end
    _track_tmpfile "$_snap"
    if not sudo -n cp -- /etc/mkinitcpio.conf "$_snap" 2>/dev/null
        _rm_tmp "$_snap" true
        _warn "  mkinitcpio.conf snapshot skipped: cp failed (rollback will be unavailable)"
        _log "MKINITCPIO_BACKUP_FAIL: cp"
        return 0
    end
    set -g _RY_MKI_BACKUP_FILE "$_snap"; set -g _RY_MKI_HAD_ORIG true # revert chmods --reference=destination
end

# ── INSTALL PHASE 2: PACKAGES (PACMAN -SYU + VERIFY) ──
function _ip_pacman_invoke --description "Run full pacman -Syu --needed (partial upgrades forbidden — Arch policy)"
    set -l _pacman_first -Syu --needed --noconfirm; set -l _pacman_retry -Syyu --needed --noconfirm
    if test -f /var/lib/pacman/db.lck
        _err "pacman database is locked (/var/lib/pacman/db.lck) — another pacman may be running, or stale lock from a crashed run"
        _err "  Skipping package install — remove the lock file manually if no pacman process is active"
        return 1
    end
    _info "System upgrade proceeding unattended — review archlinux.org/news and wiki.cachyos.org post-install"
    if not _run sudo -n pacman $_pacman_first -- $argv
        _warn "Package installation failed — retrying with forced db re-sync (handles transient mirror staleness; will not resolve pkg conflicts — see JSONL log for first-pass stderr)..."
        if not _run sudo -n pacman $_pacman_retry -- $argv
            if test -f /var/lib/pacman/db.lck
                _err "pacman database became locked during install — aborting"
            else
                _err "Package installation failed after retry"
            end
            if test "$_RY_MKI_HAD_ORIG" = true; and test -n "$_RY_MKI_BACKUP_FILE"
                if not _mkinitcpio_revert "$_RY_MKI_BACKUP_FILE"; set -g _RY_MKI_REVERT_FAILED true; _err "mkinitcpio revert failed — boot state may be inconsistent; aborting"; end
            end
            return 1
        end
    end
    set -g SYSTEM_UPGRADED true
    return 0
end
function _ip_run_and_verify --description "_install_packages sub: run pacman -Syu + verify + revalidate hooks"
    set -l pkgs_to_install $argv; set -l _err false
    if not _ip_pacman_invoke $pkgs_to_install; set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true; set _err true; end
    _info "Verifying package installation..."
    if not command -q pacman; _err "pacman binary unavailable after install — cannot verify package state"; set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true; set _err true; return 1; end # vanished pacman must not read as all-present
    set -l missing_pkgs (command pacman -T -- $pkgs_to_install 2>/dev/null); set -l _pt_rc $status
    if test "$_pt_rc" -ne 0; and test "$_pt_rc" -ne 127 # pacman -T rc: 0=present 127=targets-missing
        _err "pacman -T failed (rc=$_pt_rc) — cannot verify install state"
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        set _err true
    else if test (count $missing_pkgs) -gt 0
        _err "Missing packages: $missing_pkgs"
        _warn "  Install manually: sudo pacman -S --needed $missing_pkgs"
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        set _err true
    else
        _ok "All packages verified installed"
    end
    if not _ry_validate_mkinitcpio_hooks --existence-only $MKINITCPIO_HOOKS
        _err "Post-pacman: declared MKINITCPIO_HOOKS not all present on disk"
        _err "  pacman -Syu may have removed or renamed a hook this profile references"
        _err "  Inspect: ls /usr/lib/initcpio/{install,hooks}/ /etc/initcpio/{install,hooks}/"
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        set _err true
    end
    test "$_err" = false
    return $status
end
function _install_packages --description "Install managed packages via pacman -Syu"
    set -l _fn_err false
    _progress Packages
    _info "Package installation..."
    set -l pkgs_to_install $PKGS_ADD; set -g SYSTEM_UPGRADED false
    _ip_snapshot_mkinitcpio
    if not _ry_install_file "/etc/mkinitcpio.conf" true
        _err "Failed to pre-deploy mkinitcpio.conf before package install"
        _err "Aborting package installation — mkinitcpio.conf must be in place before -Syu"
        set -q _RY_MKI_BACKUP_FILE; and test -n "$_RY_MKI_BACKUP_FILE"; and _rm_tmp "$_RY_MKI_BACKUP_FILE" true
        set --erase _RY_MKI_BACKUP_FILE _RY_MKI_HAD_ORIG
        sudo -n rmdir /run/ry-install 2>/dev/null
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        _phase_record "Packages: pacman -Syu" FAIL "mkinitcpio.conf pre-deploy failed"
        return 1
    end
    if test (count $pkgs_to_install) -gt 0; _ip_run_and_verify $pkgs_to_install; or set _fn_err true; end
    if set -q _RY_MKI_BACKUP_FILE; and test -n "$_RY_MKI_BACKUP_FILE"
        if set -q _RY_MKI_REVERT_FAILED; and test "$_RY_MKI_REVERT_FAILED" = true # failed revert: keep snapshot (tmpfs, lost on reboot)
            _untrack_tmpfile "$_RY_MKI_BACKUP_FILE"
            _warn "  mkinitcpio.conf snapshot preserved for manual restore (until reboot): $_RY_MKI_BACKUP_FILE"
            _log "MKINITCPIO_SNAPSHOT_PRESERVED: $_RY_MKI_BACKUP_FILE (revert failed)"
        else
            _rm_tmp "$_RY_MKI_BACKUP_FILE" true
        end
    end
    set --erase _RY_MKI_BACKUP_FILE _RY_MKI_HAD_ORIG
    sudo -n rmdir /run/ry-install 2>/dev/null # reclaim empty snapshot dir
    if test "$_fn_err" = true; _phase_record "Packages: pacman -Syu" FAIL "see JSONL log"; return 1; end
    _phase_record "Packages: pacman -Syu" PASS "system upgraded (full -Syu)"
    return 0
end

# ── INSTALL PHASE 3: SYSTEM + USER + SERVICE FILES (ATOMIC WRITES) ──
function _isf_deploy_set --argument-names use_sudo phase --description "Deploy all destinations from argv[3..]"
    set -l _had_failure false
    for dst in $argv[3..]
        if not _ry_install_file "$dst" $use_sudo; set _had_failure true; contains -- "$dst" $_RY_BOOT_CRITICAL_DSTS; and set -g _RY_BOOT_TAINTED true; end
    end
    if test "$_had_failure" = true; _err "$phase file installation failed"; return 1; end
    return 0
end
function _install_system_files --description "Deploy all embedded config files"
    set -l _fn_err false
    _progress Configuration
    _info "Installing system configuration files..."
    _log "=== INSTALL SYSTEM FILES ==="
    if not _isf_deploy_set true System $SYSTEM_DESTINATIONS; set -g INSTALL_HAD_ERRORS true; set _fn_err true; end
    _info "Installing user configuration files..."
    _log "=== INSTALL USER FILES ==="
    if not _isf_deploy_set false User $USER_DESTINATIONS; set -g INSTALL_HAD_ERRORS true; set _fn_err true; end
    test "$_fn_err" = true; and return 1
    return 0
end

# ── INSTALL PHASE 4 (Services slot, fstab sub-step): EXT4 OPTS REWRITE (noatime,lazytime,commit=10) ──
function _fstab_needs_change --description "Scan ext4 entries for missing noatime/lazytime/commit=10"
    set -g _RY_FSTAB_NEEDS_CHANGE false; set -g _RY_FSTAB_COMMIT_OVERRIDES; set -l _malformed_warned false
    for line in $argv
        set -l opts_field (printf '%s\n' "$line" | command awk '{ print $4 }')
        if string match -qr '^[0-9]+$' -- "$opts_field"
            functions -q _log; and _log "FSTAB_SKIP_MALFORMED: digits-only opts field (likely absent options column): $line"
            if test "$_malformed_warned" = false
                functions -q _warn; and _warn "  /etc/fstab: malformed ext4 entry detected (options column absent or unparseable) — entry left untouched; review manually: $line"
                set _malformed_warned true
            end
            continue
        end
        if not string match -qr '(^|,)noatime(,|$)' -- "$opts_field"; or not string match -qr '(^|,)lazytime(,|$)' -- "$opts_field"; or not string match -qr '(^|,)commit=10(,|$)' -- "$opts_field"
            set -g _RY_FSTAB_NEEDS_CHANGE true
            set -l _existing_commit (string match -rg -- '(?:^|,)commit=([0-9]+)(?:,|$)' "$opts_field")
            test -n "$_existing_commit"; and test "$_existing_commit" != 10; and set -ga _RY_FSTAB_COMMIT_OVERRIDES "$_existing_commit"
        end
    end
end
function _far_build_awk_script --description "_far_awk_rewrite sub: Emit awk script for ext4 mount-opt rewrite"
    string join -- \n \
        '/^[ \t]*#/ || NF < 4 { print; next }' \
        '$3 != "ext4" { print; next }' \
        '$4 ~ /^[0-9]+$/ { print; next }' \
        '$4 ~ /(^|,)noatime(,|$)/ && $4 ~ /(^|,)lazytime(,|$)/ && $4 ~ /(^|,)commit=10(,|$)/ { print; next }' \
        '{' \
        '    n = split($4, opts, ",")' \
        '    has_noat = 0; has_lazy = 0; out = ""' \
        '    for (i = 1; i <= n; i++) {' \
        '        o = opts[i]' \
        '        if (o == "") continue' \
        '        if (o == "relatime" || o == "atime" || o == "strictatime") continue' \
        '        if (o == "defaults") continue' \
        '        if (o ~ /^commit=/) continue' \
        '        if (o == "noatime") has_noat = 1' \
        '        if (o == "lazytime") has_lazy = 1' \
        '        out = (out == "" ? o : out "," o)' \
        '    }' \
        '    if (!has_noat)  out = (out == "" ? "noatime"  : out ",noatime")' \
        '    if (!has_lazy)  out = (out == "" ? "lazytime" : out ",lazytime")' \
        '    out = (out == "" ? "commit=10" : out ",commit=10")' \
        '    pos = 1' \
        '    for (f = 1; f <= 3; f++) {' \
        '        match(substr($0, pos), /[^ \t]+/); pos += RSTART + RLENGTH - 1' \
        '        match(substr($0, pos), /[ \t]+/);  pos += RSTART + RLENGTH - 1' \
        '    }' \
        '    match(substr($0, pos), /[^ \t]+/)' \
        '    print substr($0, 1, pos + RSTART - 2) out substr($0, pos + RSTART + RLENGTH - 1)' \
        '}'
end
function _far_awk_rewrite --argument-names tmpfstab --description "awk-rewrite fstab into tmpfstab via tee"
    set -l _awk_script (_far_build_awk_script | string collect); set -l _tee_err (_mktemp_or_null -p (_tmp_dir) ry-fstab-tee-err.XXXXXX); set -l _awk_err (_mktemp_or_null -p (_tmp_dir) ry-fstab-awk-err.XXXXXX)
    _track_tmpfile "$_tee_err"
    _track_tmpfile "$_awk_err"
    sudo -n awk "$_awk_script" /etc/fstab 2>"$_awk_err" | sudo -n tee -- "$tmpfstab" >/dev/null 2>"$_tee_err" # Single sudo-awk path: awk runs as root
    set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0; or test "$_ps[2]" -ne 0
        set -l _ps_str (string join , -- $_ps)
        test -z "$_ps_str"; and set _ps_str "(empty)"
        set -l _awk_msg ""
        test -n "$_awk_err"; and test -s "$_awk_err"; and set _awk_msg " awk_err="(command head -n 1 -- "$_awk_err" | string trim --)
        set -l _tee_msg ""
        test -n "$_tee_err"; and test -s "$_tee_err"; and set _tee_msg " tee_err="(command head -n 1 -- "$_tee_err" | string trim --)
        _rm_tmp "$_awk_err" false
        _rm_tmp "$_tee_err" false
        _fail "  /etc/fstab: awk/tee rewrite failed (pipestatus=$_ps_str)$_awk_msg$_tee_msg"
        return 1
    end
    _rm_tmp "$_awk_err" false
    _rm_tmp "$_tee_err" false
    set -l _src_lines (sudo -n awk 'END{print NR}' /etc/fstab 2>/dev/null); set -l _tmp_lines (sudo -n awk 'END{print NR}' -- "$tmpfstab" 2>/dev/null) # awk is 1-in-1-out: counts must match
    if string match -qr '^[0-9]+$' -- "$_src_lines"; and string match -qr '^[0-9]+$' -- "$_tmp_lines"
        if test "$_src_lines" -ne "$_tmp_lines"
            _fail "  /etc/fstab: rewrite changed line count ($_src_lines → $_tmp_lines) — refusing to install (awk is 1-in-1-out)"
            _log "FSTAB_LINECOUNT_MISMATCH: src=$_src_lines tmp=$_tmp_lines"
            return 1
        end
    else
        _log "FSTAB_LINECOUNT_PROBE_SKIP: src='$_src_lines' tmp='$_tmp_lines' (non-numeric; falling back to size gate + findmnt)"
    end
    set -l _tmp_size (sudo -n stat -c '%s' -- "$tmpfstab" 2>/dev/null); set -l _src_size (command stat -c '%s' -- /etc/fstab 2>/dev/null); set -l _min_size 20
    if string match -qr '^[0-9]+$' -- "$_src_size"; and test "$_src_size" -gt 80
        set _min_size (math "floor($_src_size / 4)")
    end
    if not string match -qr '^[0-9]+$' -- "$_tmp_size"; or test "$_tmp_size" -lt "$_min_size"
        _fail "  /etc/fstab: rewrite produced suspiciously small tmpfile ($_tmp_size bytes < $_min_size) — refusing to install"
        return 1
    end
    return 0
end
function _fstab_atomic_replace --description "Atomic /etc/fstab rewrite (mktemp + awk + verify + mv)"
    set -l tmpfstab (sudo -n mktemp -p /etc .ry-install.fstab.XXXXXX 2>/dev/null) # tmpfile in dst parent: same-FS mv -T atomic
    if test -z "$tmpfstab"; _fail "  /etc/fstab: mktemp failed"; return 1; end
    _track_tmpfile "$tmpfstab"
    if sudo -n test -L "$tmpfstab" 2>/dev/null; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: temp file is symlink — aborting"; return 1; end
    if not _far_awk_rewrite "$tmpfstab"; _rm_tmp "$tmpfstab" true; return 1; end
    if not sudo -n chmod --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: chmod --reference failed"; return 1; end
    if not sudo -n chown --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: chown --reference failed"; return 1; end
    if command -q findmnt
        set -l _verify_out (sudo -n findmnt --verify --tab-file "$tmpfstab" 2>&1)
        if test "$status" -ne 0
            _rm_tmp "$tmpfstab" true
            _fail "  /etc/fstab: findmnt --verify failed:"
            for _vl in (printf '%s\n' $_verify_out | command head -n 3); _fail "    $_vl"; end
            return 1
        end
    else
        _fail "  /etc/fstab: findmnt absent — refusing rewrite (--verify gate is mandatory; findmnt is a hard dependency)"
        _log "FSTAB_VERIFY_REFUSED: findmnt not found"
        _rm_tmp "$tmpfstab" true
        return 1
    end
    _awf_make_backup /etc/fstab true # fstab gate is findmnt --verify
    if not _run sudo -n mv -T -- "$tmpfstab" /etc/fstab; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: atomic move failed"; return 1; end
    _untrack_tmpfile "$tmpfstab"
    return 0
end
function _install_fstab_opts --description "Add noatime,lazytime,commit=10 to ext4 fstab entries"
    set -g _RY_FSTAB_EVIDENCE "noatime,lazytime,commit=10"; set -g _RY_FSTAB_RESULT PASS # row: PASS=applied SKIP=no fstab --=no ext4
    if not test -f /etc/fstab; _warn "  /etc/fstab not found — skipping"; set -g _RY_FSTAB_EVIDENCE "fstab absent — skipped"; set -g _RY_FSTAB_RESULT SKIP; return 0; end
    if test -L /etc/fstab; _fail "  /etc/fstab is a symlink — refusing to rewrite (resolve symlink first or skip fstab opts)"; return 1; end
    set -l ext4_lines
    if not test -r /etc/fstab
        if not sudo -n test -r /etc/fstab 2>/dev/null; _fail "  /etc/fstab not readable (even via sudo) — cannot rewrite (check fstab perms)"; return 1; end
        _info "  /etc/fstab not user-readable — using sudo for read+rewrite"
        set ext4_lines (sudo -n awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
    else
        set ext4_lines (command awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
    end
    if test -z "$ext4_lines"; _info "  No ext4 entries in /etc/fstab"; set -g _RY_FSTAB_EVIDENCE "no ext4 entries"; set -g _RY_FSTAB_RESULT --; return 0; end
    _fstab_needs_change $ext4_lines
    if test "$_RY_FSTAB_NEEDS_CHANGE" = false
        set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES
        _ok "  /etc/fstab: ext4 entries already have noatime,lazytime,commit=10"
        _log "FSTAB_OPTS_NOOP: ext4 entries already conformant"
        set -g _RY_FSTAB_EVIDENCE "already conformant"
        return 0
    end
    test (count $_RY_FSTAB_COMMIT_OVERRIDES) -gt 0; and _warn "  /etc/fstab: replacing existing commit= value(s) with commit=10: $_RY_FSTAB_COMMIT_OVERRIDES"
    set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES
    not _fstab_atomic_replace; and return 1
    _ok "  /etc/fstab: noatime,lazytime,commit=10 applied to ext4 entries"
    _log "FSTAB_OPTS: noatime,lazytime,commit=10 applied"
    set -g _RY_FSTAB_EVIDENCE "applied noatime,lazytime,commit=10"
    return 0
end

# ── INSTALL PHASE 4 (Services slot): RESOLVED + PKG REMOVE + MASK + IWD + ENABLE + REGDOM ──
function _configure_services_resolved_restart --description "Restart systemd-resolved when its conf.d drop-in is in place"
    test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf; or return 0
    if _run sudo -n systemctl restart systemd-resolved
        _phase_record "Services: resolved restart" PASS "systemd-resolved restarted"
    else
        _warn "systemd-resolved restart failed — drop-in still applies at next boot (non-fatal)"
        _phase_record "Services: resolved restart" WARN "restart failed (applies next boot)"
    end
    return 0
end

# ── INSTALL PHASE 4 SUB: PKGS_DEL REMOVAL (RDEP-AWARE VIA PACTREE) ──
function _csp_filter_rdeps --argument-names pkg --description "Emit \$pkg when no external installed rdeps; emit nothing (blocked)"
    if not command -q pactree
        if not set -q _RY_PACTREE_MISSING_WARNED
            set -g _RY_PACTREE_MISSING_WARNED true
            _warn "pactree not found (install pacman-contrib) — rdep-cascade safety bypassed for PKGS_DEL"
            _log "PACTREE_MISSING: pacman-contrib not installed; rdep filter disabled"
        end
        _log "PACTREE_BYPASS: pkg=$pkg emitted unfiltered (pacman -R will refuse on live rdeps)"
        printf '%s\n' "$pkg"
        return 0
    end
    set -l _pkg_re (string escape --style=regex -- "$pkg"); set -l _t $PACTREE_TIMEOUT_S
    set -l _raw (command timeout --foreground --kill-after=5 "$_t" pactree -ru "$pkg" 2>/dev/null) # --foreground: SIGINT reaches child
    if test "$status" -ne 0; _warn "  $pkg: pactree probe failed — skipping for safety"; _log "PACTREE_PROBE_FAIL: pkg=$pkg (timeout, missing pkg, or db error)"; return 0; end
    set -l _trimmed (string trim -- $_raw); set -l _stripped (string replace -r '[=<>].*$' '' -- $_trimmed); set -l _nonempty (string match -rv -- '^$' $_stripped); set -l _rdeps_raw (string match -rv -- "^$_pkg_re\$" $_nonempty); set -l _rdeps
    for _r in $_rdeps_raw; contains -- "$_r" $PKGS_DEL; and continue; set -a _rdeps "$_r"; end
    if test (count $_rdeps) -gt 0
        _info "  $pkg: skipped (reverse deps: $_rdeps)"
        set -a _RY_PKG_REMOVE_SKIPS "$pkg"
        return 0
    end
    printf '%s\n' "$pkg"
end
function _csp_remove_pkgs --description "pacman -Rns batch with per-pkg retry on batch failure"
    if test -f /var/lib/pacman/db.lck
        _err "pacman database is locked (/var/lib/pacman/db.lck) — another pacman may be running, or it is a stale lock from a crashed run; skipping package removal"
        set -g INSTALL_HAD_ERRORS true
        set -g _RY_PKG_REMOVE_DBLOCK true
        return 0
    end
    if _run sudo -n pacman -Rns --noconfirm -- $argv; _ok "Removed: $argv"; _log "PKG_REMOVE_BATCH_OK: $argv"; set -g _RY_PKGS_REMOVED_COUNT (math $_RY_PKGS_REMOVED_COUNT + (count $argv)); return 0; end
    if test -f /var/lib/pacman/db.lck; _err "pacman database became locked during removal — aborting"; set -g INSTALL_HAD_ERRORS true; set -g _RY_PKG_REMOVE_DBLOCK true; _log "PKG_REMOVE_BATCH_FAIL_DBLOCK: $argv"; return 0; end
    _warn "Batch removal failed, trying individually..."
    _log "PKG_REMOVE_BATCH_FAIL: $argv"
    set -l _retry_installed (command pacman -Qq 2>/dev/null)
    if test "$status" -ne 0; _warn "pacman -Qq failed during retry — aborting per-pkg removal"; _log "PKG_REMOVE_RETRY_QQ_FAIL: pacman -Qq returned non-zero"; return 0; end
    for pkg in $argv
        contains -- "$pkg" $_retry_installed; or continue
        if not _run sudo -n pacman -Rns --noconfirm -- "$pkg"
            _warn "Failed to remove $pkg"
            _log "PKG_REMOVE_FAIL: $pkg"
        else
            _log "PKG_REMOVE_OK: $pkg"
            set -g _RY_PKGS_REMOVED_COUNT (math $_RY_PKGS_REMOVED_COUNT + 1)
        end
    end
end
function _configure_services_pkg_remove --description "Remove PKGS_DEL packages (rdep-aware via pactree)"
    if not command -q pacman; _warn "pacman not found, skipping PKGS_DEL removal"; _phase_record "Services: PKGS_DEL removal" SKIP "pacman not found"; return 0; end
    set -g _RY_PKG_REMOVE_SKIPS; set -g _RY_PKGS_REMOVED_COUNT 0; set -g _RY_PKG_REMOVE_DBLOCK false; set -l to_del
    set -l _del_installed (command pacman -Qq 2>/dev/null)
    if test "$status" -ne 0 # db lock: empty list would misreport
        _warn "pacman -Qq failed (db locked or read error) — skipping PKGS_DEL removal"
        _log "PKG_REMOVE_QQ_FAIL: pacman -Qq returned non-zero"
        _phase_record "Services: PKGS_DEL removal" WARN "pacman query failed — skipped"
        return 0
    end
    for pkg in $PKGS_DEL
        contains -- "$pkg" $_del_installed; or continue
        for _emit in (_csp_filter_rdeps "$pkg"); test -z "$_emit"; and continue; contains -- "$_emit" $to_del; and continue; set -a to_del "$_emit"; end
    end
    set -l _skip_count (count $_RY_PKG_REMOVE_SKIPS); set -l _del_count (count $to_del)
    if test "$_skip_count" -gt 0
        _warn "  Skipped (reverse deps held by other packages): $_RY_PKG_REMOVE_SKIPS"
        _log "PKG_REMOVE_SKIPS: $_RY_PKG_REMOVE_SKIPS"
    end
    if test "$_del_count" -gt 0; _log "PKG_REMOVE_REQUESTED: $to_del"; _csp_remove_pkgs $to_del; end
    if test "$_RY_PKG_REMOVE_DBLOCK" = true
        _phase_record "Services: PKGS_DEL removal" FAIL "pacman db locked — 0 of $_del_count removed"
    else if test "$_del_count" -eq 0; and test "$_skip_count" -eq 0
        _phase_record "Services: PKGS_DEL removal" "--" "no PKGS_DEL members installed"
    else if test "$_del_count" -eq 0
        _phase_record "Services: PKGS_DEL removal" WARN "$_skip_count skipped (rdep gate)"
    else if test "$_RY_PKGS_REMOVED_COUNT" -lt "$_del_count"
        set -l _msg "removed $_RY_PKGS_REMOVED_COUNT of $_del_count"
        test "$_skip_count" -gt 0; and set _msg "$_msg, $_skip_count rdep-skipped"
        _phase_record "Services: PKGS_DEL removal" WARN "$_msg"
    else if test "$_skip_count" -gt 0
        _phase_record "Services: PKGS_DEL removal" WARN "removed $_RY_PKGS_REMOVED_COUNT, $_skip_count rdep-skipped"
    else
        _phase_record "Services: PKGS_DEL removal" PASS "removed $_RY_PKGS_REMOVED_COUNT packages"
    end
    return 0
end

# ── INSTALL PHASE 4 SUB: MASK + FIREWALL HANDOFF (NFTABLES LIVE BEFORE UFW FLUSH) ──
function _csm_filter_units --description "_configure_services_mask sub: Pre-filter unit list"
    for _unit in $argv # per-unit avoids batched positional drift
        set -l _state (command systemctl is-enabled -- $_unit 2>/dev/null | string trim --)
        if test "$_state" = masked; _log "MASK_ALREADY: $_unit"; continue; end
        if test -z "$_state"; _info "Mask skip (unit not installed): $_unit"; _log "MASK_NOT_INSTALLED: $_unit"; continue; end
        printf '%s\n' "$_unit"
    end
end
function _csm_retry_individual --description "_configure_services_mask sub: Per-unit retry after batch mask failed (argv pre-filtered by _csm_filter_units)"
    set -l _ret 0
    for _unit in $argv
        if _run sudo -n systemctl mask --now -- $_unit
            _ok "Masked: $_unit"
        else
            set -l _state (command systemctl is-enabled -- $_unit 2>/dev/null | string trim --)
            _warn "Failed to mask: $_unit (is-enabled=$_state)"
            set _ret 1
        end
    end
    return $_ret
end
function _csm_nft_live --description "rc 0 iff live inet/filter/input chain has policy drop (oneshot reads inactive after clean load)"
    command -q nft; or return 1
    sudo -n true 2>/dev/null; or return 1
    string match -q -- '*policy drop*' (_as true env LC_ALL=C nft list chain inet filter input 2>/dev/null)
end
function _csm_enable_nftables_first --description "Activate nftables before the ufw flush; rc 0 iff default-deny ruleset confirmed live"
    contains -- ufw.service $MASK; or return 0
    contains -- nftables.service $EXPECTED_SERVICES; or return 0
    if _csm_nft_live; _log "NFT_PRE_ENABLE_SKIP: ruleset already live"; return 0; end
    _run sudo -n systemctl enable --now -- nftables.service
    if _csm_nft_live
        _ok "nftables.service enabled — default-deny ruleset confirmed live before the ufw flush (oneshot: unit state reads inactive)"
        _log "NFT_PRE_ENABLE_OK"
        return 0
    end
    _warn "nftables default-deny ruleset NOT confirmed live before the ufw flush — leaving ufw rules in place to avoid an unfirewalled window"
    _log "NFT_PRE_ENABLE_FAIL: live ruleset unconfirmed"
    return 1
end
function _csm_disable_ufw_rules --argument-names nft_live --description "Flush ufw rules before mask, but only when nftables default-deny is confirmed live"
    contains -- ufw.service $MASK; or return 0
    command -q ufw; or return 0
    set -l _state (command systemctl is-active ufw.service 2>/dev/null | string trim --)
    if test "$_state" != active; _log "UFW_RULE_FLUSH_SKIP: ufw.service is-active=$_state"; return 0; end
    if test "$nft_live" != true
        _warn "ufw left active — nftables default-deny not confirmed live; flushing ufw now would leave the host unfirewalled until reboot. Re-run after nftables.service starts."
        _log "UFW_RULE_FLUSH_DEFERRED: nft_live=$nft_live (ufw retained to avoid unfirewalled window)"
        return 0
    end
    _warn "SECURITY: ufw disabled+masked by profile — nftables default-deny-inbound is the active host firewall"
    _log "SECURITY_POSTURE: ufw disabled+masked; nftables default-deny-inbound active (/etc/nftables.conf)"
    if _run sudo -n ufw --force disable
        _ok "ufw disabled — netfilter rules flushed (nftables default-deny live)"
        _log "UFW_RULE_FLUSH_OK"
    else
        _warn "ufw --force disable failed — netfilter rules may persist until reboot"
        _log "UFW_RULE_FLUSH_FAIL"
    end
    return 0
end
function _configure_services_mask --description "Apply MASK list; batch-mask with per-unit retry"
    set -l _nft_live false
    _csm_enable_nftables_first; and set _nft_live true
    _csm_disable_ufw_rules $_nft_live
    set -l safe_mask $MASK
    if test "$_nft_live" != true; and contains -- ufw.service $safe_mask # masking ufw with rules retained = no firewall next boot
        set safe_mask (string match -v -- ufw.service $safe_mask)
        _warn "ufw.service mask skipped this run — nftables default-deny not confirmed live; masking ufw now would block its ruleset reload on next boot. Re-run after nftables.service is active."
        _log "MASK_UFW_SKIP: nft_live=false — ufw.service left unmasked to preserve firewall coverage across reboot"
    end
    if test (count $safe_mask) -eq 0
        _phase_record "Services: mask units" "--" "MASK list empty"
        return 0
    end
    set -l _to_mask (_csm_filter_units $safe_mask)
    if test (count $_to_mask) -eq 0
        _phase_record "Services: mask units" PASS "all "(count $safe_mask)" already masked or not installed"
        return 0
    end
    set -l _mask_count (count $_to_mask)
    if _run sudo -n systemctl mask --now -- $_to_mask
        _phase_record "Services: mask units" PASS "masked $_mask_count units"
        return 0
    end
    _warn "Batch mask failed — retrying individually to identify failures"
    _csm_retry_individual $_to_mask
    set -l _rc $status
    if test "$_rc" -eq 0
        _phase_record "Services: mask units" PASS "$_mask_count masked (per-unit retry)"
    else
        _phase_record "Services: mask units" FAIL "some masks failed; see JSONL log"
    end
    return $_rc
end

# ── INSTALL PHASE 4 SUB: IWD HANDOFF (disable standalone iwd.service; NM sole Wi-Fi manager) ──
function _configure_services_iwd_handoff --description "Disable standalone iwd.service so NetworkManager is the sole Wi-Fi manager"
    test "$NM_WIFI_BACKEND" = iwd; or return 0 # only relevant for the iwd backend
    if not command -q systemctl; _phase_record "Services: iwd handoff" "--" "systemctl absent"; return 0; end
    set -l _state (command systemctl is-enabled iwd.service 2>/dev/null | string trim --)
    if test -z "$_state"; _phase_record "Services: iwd handoff" "--" "iwd.service not present"; return 0; end
    if test "$_state" = masked
        # masked blocks NM D-Bus activation: unmask then disable
        _run sudo -n systemctl unmask iwd.service
    end
    # disable not mask: stops boot race, keeps D-Bus activation
    if _run sudo -n systemctl disable --now iwd.service
        _ok "iwd.service disabled (NetworkManager activates iwd on demand)"
        _phase_record "Services: iwd handoff" PASS "iwd.service disabled; NM is sole manager"
    else
        set -l _now (command systemctl is-enabled iwd.service 2>/dev/null | string trim --)
        if test "$_now" = disabled; or test "$_now" = static
            _phase_record "Services: iwd handoff" PASS "iwd.service $_now (NM is sole manager)"
        else
            _warn "Could not disable iwd.service (is-enabled=$_now) — if Wi-Fi misbehaves, run: sudo systemctl disable --now iwd.service"
            _phase_record "Services: iwd handoff" WARN "iwd.service still $_now"
        end
    end
    return 0
end

# ── INSTALL PHASE 4 SUB: ENABLE UNITS + REGDOM ──
function _cse_collect_units --description "Collect system units to enable"
    set -l _enable
    for _exp in $EXPECTED_SERVICES
        if not contains -- "$_exp" $_RY_PKG_MANAGED_SERVICES
            set -a _enable "$_exp"; continue
        end
        set -l _st (command systemctl is-enabled "$_exp" 2>/dev/null | string trim --) # enable only if preset didn't
        if test "$_st" = enabled
            _ok "$_exp: already enabled (package preset)"
        else if test -z "$_st"
            _info "$_exp: not installed — skipping enable"
        else
            set -a _enable "$_exp"
        end
    end
    test (count $_enable) -gt 0; and printf '%s\n' $_enable
end
function _cse_batch_enable --description "Batch enable system units"
    test (count $argv) -eq 0; and return 0
    _run sudo -n systemctl enable --now -- $argv; and return 0
    _warn "Batch enable failed — retrying individually to identify failures"
    set -l _ret 0
    for _unit in $argv
        if _run sudo -n systemctl enable --now -- $_unit
            _ok "Enabled: $_unit"
        else
            set -l _enabled_state (command systemctl is-enabled -- $_unit 2>/dev/null | string trim --)
            if contains -- "$_enabled_state" enabled enabled-runtime alias static linked linked-runtime indirect generated transient # systemctl boot-running states
                _warn "Enabled but failed to start: $_unit (will activate on next boot if config is fixed)"
                _warn "  Diagnose: systemctl status $_unit; journalctl -u $_unit -b"
                _log "ENABLE_OK_START_FAIL: unit=$_unit is-enabled=$_enabled_state"
            else
                _err "Failed to enable: $_unit (is-enabled=$_enabled_state)"
                set -g INSTALL_HAD_ERRORS true
                set _ret 1
            end
        end
    end
    return $_ret
end
function _configure_services_enable --description "Batch-enable system units (per-unit retry on batch failure)"
    set -l _ret 0; set -l _units (_cse_collect_units); set -l _enable_count (count $_units)
    if test "$_enable_count" -eq 0
        _phase_record "Services: enable units" "--" "no units to enable"
        return 0
    end
    if _cse_batch_enable $_units
        _phase_record "Services: enable units" PASS "enabled $_enable_count units"
    else
        _phase_record "Services: enable units" FAIL "$_enable_count requested; see JSONL log"
        set _ret 1
    end
    return $_ret
end
function _apply_wireless_regdom --description "Apply the wireless regulatory domain ($COUNTRY) at runtime"
    set -g _RY_REGDOM_RESULT DEFER; set -g _RY_REGDOM_EVIDENCE ""
    if not command -q iw
        _info "  wireless regdom: iw(8) absent — $COUNTRY applies via /etc/iw-regdomain (cachyos-iw-set-regdomain)"
        set -g _RY_REGDOM_EVIDENCE "iw(8) absent — applies via /etc/iw-regdomain"
        return 0
    end
    _info "  wireless regdom → $COUNTRY"
    if _run sudo -n iw reg set "$COUNTRY"
        set -g _RY_REGDOM_RESULT PASS; set -g _RY_REGDOM_EVIDENCE "country $COUNTRY set"
        return 0
    end
    _warn "iw reg set $COUNTRY failed — applies via /etc/iw-regdomain (cachyos-iw-set-regdomain)"
    set -g _RY_REGDOM_RESULT WARN; set -g _RY_REGDOM_EVIDENCE "iw reg set failed — applies via /etc/iw-regdomain"
    return 0
end
function _install_configure_services --description "Enable, start, and configure systemd services (fstab opts + resolved + PKGS_DEL + mask + iwd handoff + enable + regdom)"
    _progress Services
    _info "Post-installation tasks..."
    set -l _ret 0
    if _install_fstab_opts # Phase 4: fstab ext4 opts
        _phase_record "Services: fstab opts" "$_RY_FSTAB_RESULT" "$_RY_FSTAB_EVIDENCE"
    else
        _phase_record "Services: fstab opts" FAIL "see JSONL log"
        set _ret 1
    end
    _configure_services_resolved_restart
    _configure_services_pkg_remove
    _configure_services_mask; or set _ret 1
    _configure_services_iwd_handoff
    _configure_services_enable; or set _ret 1
    _apply_wireless_regdom
    _phase_record "Services: regdom" $_RY_REGDOM_RESULT "$_RY_REGDOM_EVIDENCE"
    return $_ret
end

# ── BOOT PATH RESOLUTION (ESP + $BOOT via bootctl / findmnt) ──
function _bootctl_dir --argument-names flag logtag fallnote --description "bootctl path probe (user then sudo); empty on failure"
    command -q bootctl; or return 0
    set -l _p (command bootctl $flag 2>/dev/null | string trim -- | string trim -r -c / --)
    if test -z "$_p"
        set _p (sudo -n bootctl $flag 2>/dev/null | string trim -- | string trim -r -c / --)
        set -l _bc_ps $pipestatus
        test "$_bc_ps[1]" -ne 0; and functions -q _log; and _log "$logtag: bootctl $flag rc=$_bc_ps[1] (sudo lapse or bootctl error); $fallnote"
    end
    printf '%s' "$_p"
end
function _resolve_esp --description "Resolve EFI system partition path (cached; empty result also cached)"
    if set -q _RY_ESP_TRIED; printf '%s' "$_RY_ESP_PATH"; return 0; end
    set -l _p (_bootctl_dir -p ESP_BOOTCTL_PIPE_FAIL "falling through to findmnt")
    if test -z "$_p"; or begin; not test -d "$_p"; and not sudo -n test -d "$_p" 2>/dev/null; end
        for _candidate in /efi /boot/efi /boot/EFI /boot
            set -l _fs (command findmnt -no FSTYPE -- "$_candidate" 2>/dev/null)
            if test "$_fs" = vfat; set _p "$_candidate"; break; end
        end
    end
    if test -z "$_p"; or begin; not test -d "$_p"; and not sudo -n test -d "$_p" 2>/dev/null; end
        if test -d /boot; or sudo -n test -d /boot 2>/dev/null
            set _p /boot
            set -g _RY_ESP_FALLBACK true
            functions -q _warn; and _warn "  ESP autodetect failed — defaulting to /boot. Verify systemd-boot mount: findmnt /boot"
            functions -q _log; and _log "ESP_RESOLVE_FALLBACK: bootctl/findmnt failed, defaulting to /boot"
        else
            functions -q _err; and _err "  ESP autodetect failed AND /boot is not a directory — cannot resolve boot path"
            functions -q _log; and _log "ESP_RESOLVE_HARD_FAIL: bootctl/findmnt failed AND /boot missing"
            set _p ""
        end
    else
        set -g _RY_ESP_FALLBACK false
    end
    set -g _RY_ESP_PATH "$_p"; set -g _RY_ESP_TRIED true
    printf '%s' "$_p"
end
function _resolve_boot_path --description "Resolve \$BOOT (XBOOTLDR if present, else ESP) per BLS (cached; empty result also cached)"
    if set -q _RY_BOOT_TRIED; printf '%s' "$_RY_BOOT_PATH"; return 0; end
    set -l _p (_bootctl_dir -x BOOT_BOOTCTL_PIPE_FAIL "falling through to ESP")
    test -z "$_p"; or begin; not test -d "$_p"; and not sudo -n test -d "$_p" 2>/dev/null; end; and set _p (_resolve_esp)
    set -g _RY_BOOT_PATH "$_p"; set -g _RY_BOOT_TRIED true
    printf '%s' "$_p"
end
function _sdboot_fallback_vfat_ok --description "Refuse sdboot when ESP fell back to a non-vfat /boot (rc 0=ok 1=refuse)"
    set -q _RY_ESP_FALLBACK; and test "$_RY_ESP_FALLBACK" = true; or return 0
    set -l _boot_fs (command findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)
    if test "$_boot_fs" = vfat; return 0; end
    set -g _RY_SDBOOT_REFUSE_FS "$_boot_fs"
    _err "Refusing sdboot-manage: ESP autodetect fell back to /boot but /boot is not vfat (fstype=$_boot_fs)"
    _err "  ry-install targets systemd-boot. Detected non-systemd-boot bootloader — aborting."
    _log "SDBOOT_APPLY_REFUSED: esp_fallback=true boot_fstype=$_boot_fs"
    return 1
end

# ── BOOT SANITY: ENTRIES + KERNEL/INITRAMFS PROBES + SIZE SCAN ──
function _enum_boot_entries --argument-names boot --description "Enumerate \$boot/loader/entries/*.conf"
    set -g _RY_BOOT_ENUM_OK true
    set -l _basenames (sudo -n find "$boot/loader/entries" -maxdepth 1 -type f -name '*.conf' -printf '%f\0' 2>/dev/null | string split0); set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0; set -g _RY_BOOT_ENUM_OK false; set -g _RY_BOOT_COUNT 0; functions -q _log; and _log "BOOT_ENUM_FAIL: boot=$boot pipestatus=$_ps (sudo lapse or read error)"; return 0; end
    set -g _RY_BOOT_COUNT (count $_basenames)
end
function _pbs_check_boot_files --argument-names boot glob label --description "_preflight_boot_sanity sub: enumerate \$glob in \$boot root"
    set -l errors 0; set -l files (sudo -n find "$boot" -maxdepth 1 -name "$glob" -type f -print0 2>/dev/null | string split0); set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0
        _err "Cannot enumerate $boot/ for $glob (sudo lapsed or read error)"
        set errors (math $errors + 1)
    else if test (count $files) -eq 0
        _err "No $label found in $boot/"
        set errors (math $errors + 1)
    else
        for f in $files
            sudo -n test -s "$f" 2>/dev/null
            if test "$status" -ne 0; _err "Zero-byte $label image: $f"; set errors (math $errors + 1); end
        end
    end
    echo $errors
end
function _pbs_entry_has_valid_kernel --argument-names boot conf --description "Probe a loader-entry .conf for a kernel image inside \$BOOT"
    set -l linux_line (sudo -n grep -m1 -E '^[[:space:]]*linux[[:space:]]' -- "$conf" 2>/dev/null | string replace -r '^\s*linux\s+' '' | string trim --)
    test -z "$linux_line"; and return 1
    set -l linux_rel (string replace -r '^/+' '' -- "$linux_line")
    if string match -q '*../*' -- "/$linux_rel/"; _warn "  Loader entry uses parent-dir traversal: $conf ($linux_line)"; return 1; end
    set -l linux_canon
    if command -q realpath
        set linux_canon (command realpath -m -- "$boot/$linux_rel" 2>/dev/null)
    else
        if not set -q _RY_REALPATH_ABSENT_WARNED # warn once per run
            set -g _RY_REALPATH_ABSENT_WARNED true
            _warn "  realpath(1) absent — loader-entry canonicalization downgraded to textual join (symlink escapes undetectable)"
            _log "REALPATH_ABSENT_FALLBACK: boot-entry canonicalization textual-only (traversal still rejected)"
        end
        set linux_canon (string replace -ra '/+' '/' -- "$boot/$linux_rel") # realpath absent: normalized join
    end
    if test -z "$linux_canon"; _warn "  Loader entry path could not be canonicalized: $conf ($linux_line)"; return 1; end
    set -l _boot_re (string escape --style=regex -- "$boot")
    if not string match -qr -- "^"$_boot_re"(/|\$)" "$linux_canon"; _warn "  Loader entry escapes \$BOOT boundary: $conf -> $linux_canon"; return 1; end
    sudo -n test -f "$linux_canon" 2>/dev/null
end
function _pbs_check_entries --argument-names boot --description "Enumerate \$BOOT/loader/entries/*.conf"
    set -l errors 0; set -l confs (sudo -n find "$boot/loader/entries" -maxdepth 1 -name '*.conf' -type f -print0 2>/dev/null | string split0); set -l _cf_ps $pipestatus
    if test "$_cf_ps[1]" -ne 0; _err "Cannot enumerate $boot/loader/entries (sudo lapsed or read error)"; set errors (math $errors + 1); echo $errors; return 0; end
    if test (count $confs) -eq 0; _err "No boot loader entries in $boot/loader/entries/"; set errors (math $errors + 1); echo $errors; return 0; end
    set -l valid_entry false
    for conf in $confs
        if _pbs_entry_has_valid_kernel "$boot" "$conf"; set valid_entry true; break; end
    end
    if test "$valid_entry" = false; _err "No boot entry references a valid kernel image"; set errors (math $errors + 1); end
    echo $errors
end
function _preflight_boot_sanity --description "Verify boot artifacts are viable after rebuild"
    set -l _boot (_resolve_boot_path)
    if test -z "$_boot"
        _err "Boot sanity: \$BOOT path unresolved (bootctl/findmnt failed) — DO NOT REBOOT"
        return 1
    end
    set -l _k (_pbs_check_boot_files "$_boot" 'vmlinuz-*' kernel); set -l _i (_pbs_check_boot_files "$_boot" 'initramfs-*.img' initramfs); set -l _e (_pbs_check_entries "$_boot")
    for _v in _k _i _e; string match -qr '^\d+$' -- "$$_v"; or set $_v 1; end
    set -l errors (math $_k + $_i + $_e)
    if test "$errors" -gt 0
        _err "Boot sanity check failed ($errors error(s)) — DO NOT REBOOT"
        _info "  Inspect: ls -la $_boot/vmlinuz-* $_boot/initramfs-*.img"
        _info "  Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen"
        return 1
    end
    _ok "Boot sanity: vmlinuz present, initramfs non-zero, entries valid"
    return 0
end

# ── INSTALL PHASE 5: BOOT REBUILD (MKINITCPIO -P + SDBOOT GEN/UPDATE) ──
function _irb_skip_post_mki --description "Record SKIP rows for sdboot-gen, sdboot-update, post-rebuild sanity"
    _phase_record "Boot: sdboot-manage gen" SKIP "aborted"
    _phase_record "Boot: sdboot-manage update" SKIP "aborted"
    _phase_record "Boot: post-rebuild sanity" SKIP "aborted"
end
function _irb_sdboot_apply --description "Run sdboot-manage gen + update"
    if not _sdboot_fallback_vfat_ok
        _phase_record "Boot: sdboot-manage gen" FAIL "ESP fallback to /boot not vfat (fstype=$_RY_SDBOOT_REFUSE_FS)"
        _phase_record "Boot: sdboot-manage update" SKIP "aborted"
        return $EXIT_BOOT_CRIT
    end
    if not _run sudo -n sdboot-manage gen
        _err "sdboot-manage gen failed"
        _err "CRITICAL: Bootloader update failed — aborting remaining steps"
        _phase_record "Boot: sdboot-manage gen" FAIL "rc=non-zero"
        _phase_record "Boot: sdboot-manage update" SKIP "aborted"
        return $EXIT_BOOT_CRIT
    end
    _phase_record "Boot: sdboot-manage gen" PASS "rc=0"
    if not _run sudo -n sdboot-manage update
        _err "sdboot-manage update failed (bootctl EFI binary refresh)"
        _err "CRITICAL: Bootloader binary update failed — aborting remaining steps"
        _phase_record "Boot: sdboot-manage update" FAIL "rc=non-zero"
        return $EXIT_BOOT_CRIT
    end
    _phase_record "Boot: sdboot-manage update" PASS "rc=0"
    return 0
end
function _irb_verify_entries --argument-names boot --description "Re-enumerate boot entries post-rebuild"
    _enum_boot_entries "$boot"
    if test "$_RY_BOOT_ENUM_OK" = false
        _warn "Boot entries: cannot enumerate $boot/loader/entries (sudo lapsed or read error)"
    else
        set -l entry_count $_RY_BOOT_COUNT
        if test "$entry_count" -gt 0
            _ok "Boot entries: $entry_count found in $boot/loader/entries/"
        else
            _err "No boot entries found in $boot/loader/entries/"
            _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
            _info "  Try: sudo sdboot-manage gen --verbose"
            set -g INSTALL_HAD_ERRORS true
        end
    end
end
function _check_boot_taint_gate --description "Verify boot state not tainted (shared by _irb_taint_gate + _post_boot_apply); rc=0 ok, 1=revert-failed, 2=tainted"
    if set -q _RY_MKI_REVERT_FAILED; and test "$_RY_MKI_REVERT_FAILED" = true
        _err "Refusing initramfs rebuild — mkinitcpio.conf revert failed (boot state inconsistent)"
        _err "  Manual recovery required before re-running"
        return 1
    end
    if test "$_RY_BOOT_TAINTED" = true
        _err "Refusing initramfs rebuild — an earlier phase of THIS run tainted package or boot-critical config state"
        _err "  (mkinitcpio.conf, kernel cmdline, loader, sdboot-manage, or pacman -Syu/package-verify failed)"
        _err "  Resolve the cause manually, then re-run (idempotent)"
        return 2
    end
    return 0
end
function _irb_taint_gate --description "_install_rebuild_boot sub: Verify mkinitcpio.conf is consistent and boot state is not tainted; returns non-zero with _phase_record + _irb_skip_post_mki on bail"
    _check_boot_taint_gate
    set -l _gate_rc $status
    test "$_gate_rc" -eq 0; and return 0
    if test "$_gate_rc" -eq 1
        _phase_record "Boot: mkinitcpio -P" SKIP "mkinitcpio.conf revert failed"
    else
        _phase_record "Boot: mkinitcpio -P" SKIP "_RY_BOOT_TAINTED=true"
    end
    _irb_skip_post_mki
    return $EXIT_BOOT_CRIT
end

# ── INSTALL PHASE 5: REBUILD ORCHESTRATOR (_install_rebuild_boot) ──
function _install_rebuild_boot --description "Regenerate initramfs and bootloader entries"
    _progress Boot
    _irb_taint_gate
    set -l _tg_rc $status
    test "$_tg_rc" -ne 0; and return $_tg_rc
    test "$SYSTEM_UPGRADED" = true; and _ok "System upgraded during package installation"
    if not _run sudo -n mkinitcpio -P
        _err "mkinitcpio failed"
        _err "CRITICAL: Boot rebuild failed — aborting remaining steps"
        _phase_record "Boot: mkinitcpio -P" FAIL "rc=non-zero"
        _irb_skip_post_mki
        return $EXIT_BOOT_CRIT
    end
    _phase_record "Boot: mkinitcpio -P" PASS "rc=0"
    set -l _boot (_resolve_boot_path)
    if test "$SDBOOT_REMOVE_EXISTING" = yes; and test -z "$_boot"
        _err "Cannot resolve \$BOOT path — refusing boot-wipe gate"
        _err "CRITICAL: bootctl/findmnt failed AND /boot missing — aborting remaining steps"
        _phase_record "Boot: sdboot-manage gen" FAIL "\$BOOT unresolvable"
        _phase_record "Boot: sdboot-manage update" SKIP "aborted"
        _phase_record "Boot: post-rebuild sanity" SKIP "aborted"
        return $EXIT_BOOT_CRIT
    end
    _irb_sdboot_apply
    set -l _sb_rc $status
    if test "$_sb_rc" -ne 0; _phase_record "Boot: post-rebuild sanity" SKIP "aborted"; return $_sb_rc; end
    if test -z "$_boot"
        _err "Cannot resolve \$BOOT path post-sdboot-apply — entry verification skipped"
        set -g INSTALL_HAD_ERRORS true
    else
        _irb_verify_entries "$_boot"
    end
    if not _preflight_boot_sanity; _err "CRITICAL: Boot sanity failed — aborting remaining steps"; _phase_record "Boot: post-rebuild sanity" FAIL "see JSONL log"; return $EXIT_BOOT_CRIT; end
    _phase_record "Boot: post-rebuild sanity" PASS "vmlinuz+initramfs+entries OK"
    return 0
end

# ── INSTALL PHASE 6: FINALIZE (USER RELOAD + PACCACHE + NM RESTART) ──
function _if_trim_pacman_cache --description "Trim pacman cache via paccache -rk2 -ruk0"
    set -l _upgraded false; set -l _removed_n 0
    set -q SYSTEM_UPGRADED; and test "$SYSTEM_UPGRADED" = true; and set _upgraded true
    set -q _RY_PKGS_REMOVED_COUNT; and set _removed_n $_RY_PKGS_REMOVED_COUNT
    if test "$_upgraded" = false; and test "$_removed_n" -eq 0
        _log "PACMAN_CACHE_TRIM_SKIP: no upgrade and no removals this run"
        _phase_record "Finalize: pacman cache trim" SKIP "no upgrade or removals this run"
        return 0
    end
    set -l _reason "upgrade"
    test "$_upgraded" = false; and set _reason "removals=$_removed_n"
    if command -q paccache
        if _run sudo -n paccache -rk2 -ruk0
            _phase_record "Finalize: pacman cache trim" PASS "paccache -rk2 ($_reason)"
        else
            _warn "paccache cache trim failed"
            _phase_record "Finalize: pacman cache trim" WARN "paccache failed"
        end
    else
        if _run sudo -n pacman -Sc --noconfirm
            _phase_record "Finalize: pacman cache trim" PASS "pacman -Sc ($_reason)"
        else
            _warn "pacman cache clear failed"
            _phase_record "Finalize: pacman cache trim" WARN "pacman -Sc failed"
        end
    end
    return 0
end
function _if_nm_restart --description "Restart NetworkManager so the deployed wifi.backend/powersave drop-in applies"
    if test "$_RY_PROFILE_USES_WIFI_BACKEND" = false; _info "NetworkManager not managed — skipping NM restart"; _phase_record "Finalize: NetworkManager restart" SKIP "NM backend not active"; return 0; end
    if not command -q NetworkManager
        _warn "NetworkManager configs deployed but NetworkManager not installed — restart skipped; drop-in applies once installed or at next boot"
        _phase_record "Finalize: NetworkManager restart" WARN "NetworkManager not installed"
        return 0
    end
    if test "$NM_WIFI_BACKEND" = iwd; and begin; not command -q pacman; or not command pacman -Qq iwd >/dev/null 2>&1; end
        _warn "NetworkManager configs deployed but iwd is not installed (advisory; install iwd to activate the iwd backend)"
        _phase_record "Finalize: NetworkManager restart" WARN "iwd not installed"
        return 0
    end
    if _is_wifi_active_route
        _warn "NetworkManager restart deferred — WiFi is the active route; drop-in takes effect on reboot."
        _info "  Or, after switching to ethernet: sudo systemctl restart NetworkManager"
        _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=finalize_backend_switch"
        _phase_record "Finalize: NetworkManager restart" DEFER "over WiFi — applies on reboot"
        return 0
    end
    _info "NetworkManager will restart (D-Bus disconnect expected)"
    if not _run sudo -n systemctl restart NetworkManager
        _warn "NetworkManager restart failed (will recover on reboot)"
        _log "NM_RESTART_FAILED: context=finalize_backend_switch"
        _phase_record "Finalize: NetworkManager restart" WARN "restart failed (will recover on reboot)"
    else
        _phase_record "Finalize: NetworkManager restart" PASS "restarted"
    end
    set -l _nm_delay $NM_RESTART_DELAY; string match -qr '^\d+$' -- "$_nm_delay"; or set _nm_delay 3 # guard against non-integer retune
    command sleep $_nm_delay </dev/null 2>/dev/null; or _warn "Sleep interrupted during NM restart settle window"
    return 0
end
function _install_finalize --description "Finalize: user daemon-reload + pacman cache trim + NetworkManager restart"
    _progress Finalize
    if _has_user_bus_active
        if _run systemctl --user daemon-reload
            _phase_record "Finalize: systemctl --user reload" PASS "user-bus active"
        else
            _warn "systemctl --user daemon-reload failed — re-login refreshes the user session (non-fatal)"
            _phase_record "Finalize: systemctl --user reload" WARN "daemon-reload failed (non-fatal)"
        end
    else
        _info "Skipping systemctl --user daemon-reload (no active user-bus — log in graphically or enable-linger)"
        _log "USER_DAEMON_RELOAD_SKIP: no active user-bus"
        _phase_record "Finalize: systemctl --user reload" SKIP "no active user-bus"
    end
    _if_trim_pacman_cache
    _if_nm_restart
    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end

# ── PHASE DISPATCH (_rdi_run_phases) ──
function _rrp_optional_indexer --argument-names cmd label --description "_rdi_run_phases sub: Run an optional indexer (updatedb / pkgfile) and record phase"
    set -l flag $argv[3..-1]
    if not command -q $cmd; _phase_record "Packages: $label" "--" "not installed"; return 0; end
    if _run sudo -n $cmd $flag
        _phase_record "Packages: $label" PASS "ok"
    else
        _warn "$label failed"
        _phase_record "Packages: $label" WARN "failed (non-fatal)"
    end
end
function _rdi_run_phases --description "Run pkgs/sys/services phases"
    not _install_packages; and set -g INSTALL_HAD_ERRORS true
    if set -q _RY_MKI_REVERT_FAILED; and test "$_RY_MKI_REVERT_FAILED" = true
        _phase_record "Packages: updatedb" SKIP "aborted"
        _phase_record "Packages: pkgfile --update" SKIP "aborted"
        _phase_record "Configs: system file deployment" SKIP "aborted"
        _phase_record "Services: fstab opts" SKIP "aborted"
        _phase_record "Services: PKGS_DEL removal" SKIP "aborted"
        _phase_record "Services: mask units" SKIP "aborted"
        _phase_record "Services: enable units" SKIP "aborted"
        _phase_record "Services: regdom" SKIP "aborted"
        _err "Aborting remaining phases: mkinitcpio.conf revert failed (boot state inconsistent)"
        return 0
    end
    _rrp_optional_indexer updatedb updatedb
    _rrp_optional_indexer pkgfile "pkgfile --update" --update
    set -g _RY_DEPLOY_CHANGED_COUNT 0; set -g _RY_DEPLOY_IDEMPOTENT_COUNT 0 # phase-3 scope
    if _install_system_files
        _phase_record "Configs: system file deployment" PASS "$_RY_DEPLOY_CHANGED_COUNT deployed, $_RY_DEPLOY_IDEMPOTENT_COUNT idempotent"
    else
        set -g INSTALL_HAD_ERRORS true
        _phase_record "Configs: system file deployment" FAIL "$_RY_DEPLOY_CHANGED_COUNT deployed, $_RY_DEPLOY_IDEMPOTENT_COUNT idempotent, see JSONL"
    end
    _install_configure_services; or set -g INSTALL_HAD_ERRORS true
    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end

# ── RUN-SUMMARY MATRIX RENDERER (STDERR-ONLY; JSONL IS THE DURABLE RECORD) ──
function _rdi_elapsed --description "Format wall-clock elapsed since _PROG_START as 'Nm Ms'"
    set -q _PROG_START; or begin; printf '%s' "?"; return 0; end
    set -l _now (_progress_now); set -l _secs (math $_now - $_PROG_START)
    if test "$_secs" -lt 60
        printf '%ds' $_secs
    else
        set -l _m (math "floor($_secs / 60)"); set -l _s (math "$_secs - $_m * 60")
        printf '%dm %ds' $_m $_s
    end
end
function _rdi_matrix_header --description "_rdi_render_matrix sub: Emit top bar, title, column header, separator"
    set -l _bar_top $argv[1]; set -l _sep_c $argv[2]; set -l _sep_r $argv[3]; set -l _sep_e $argv[4]
    set -l _inner $argv[5]; set -l _w_c $argv[6]; set -l _w_r $argv[7]; set -l _w_e $argv[8]
    set -l _title "ry-install v$VERSION — RUN SUMMARY"; set -l _title_lpad (math -s0 "max(0, ($_inner - "(string length -- $_title)") / 2)"); set -l _title_padded $_title
    test "$_title_lpad" -gt 0; and set _title_padded (string repeat -n $_title_lpad ' ')$_title
    set _title_padded (string pad -r -w $_inner -- $_title_padded)
    printf '╔%s╗\n' $_bar_top >&2
    printf '║%s║\n' $_title_padded >&2
    printf '╠%s╦%s╦%s╣\n' $_sep_c $_sep_r $_sep_e >&2
    printf '║ %s ║ %s ║ %s ║\n' (string pad -r -w $_w_c -- CHECK) (string pad -r -w $_w_r -- RESULT) (string pad -r -w $_w_e -- EVIDENCE) >&2
    printf '╠%s╬%s╬%s╣\n' $_sep_c $_sep_r $_sep_e >&2
end
function _rdi_matrix_rows --description "_rdi_render_matrix sub: Emit data rows; tally buckets via _RY_MTX_* globals"
    set -l _w_c $argv[1]; set -l _w_r $argv[2]; set -l _w_e $argv[3]
    set -g _RY_MTX_PASS 0; set -g _RY_MTX_WARN 0; set -g _RY_MTX_FAIL 0
    set -g _RY_MTX_DEFER 0; set -g _RY_MTX_SKIP 0; set -g _RY_MTX_NA 0
    for _row in $_RY_PHASE_RESULTS
        set -l _parts (string split '│' -- $_row)
        test (string length -- $_parts[1]) -gt "$_w_c"; and functions -q _log; and _log "MATRIX_TRUNCATED: check label "(string length -- $_parts[1])" > $_w_c chars: $_parts[1]"
        test (string length -- $_parts[3]) -gt "$_w_e"; and functions -q _log; and _log "MATRIX_TRUNCATED: evidence "(string length -- $_parts[3])" > $_w_e chars: $_parts[3]"
        set -l _chk (string sub -l $_w_c -- $_parts[1]); set -l _res $_parts[2]; set -l _evd (string sub -l $_w_e -- $_parts[3])
        set -l _res_lpad (math -s0 "max(0, ($_w_r - "(string length -- $_res)") / 2)"); set -l _res_padded $_res
        test "$_res_lpad" -gt 0; and set _res_padded (string repeat -n $_res_lpad ' ')$_res
        set _res_padded (string pad -r -w $_w_r -- $_res_padded)
        printf '║ %s ║ %s ║ %s ║\n' (string pad -r -w $_w_c -- $_chk) $_res_padded (string pad -r -w $_w_e -- $_evd) >&2
        switch "$_parts[2]"
            case PASS;  set -g _RY_MTX_PASS  (math $_RY_MTX_PASS + 1)
            case WARN;  set -g _RY_MTX_WARN  (math $_RY_MTX_WARN + 1)
            case FAIL;  set -g _RY_MTX_FAIL  (math $_RY_MTX_FAIL + 1)
            case DEFER; set -g _RY_MTX_DEFER (math $_RY_MTX_DEFER + 1)
            case SKIP;  set -g _RY_MTX_SKIP  (math $_RY_MTX_SKIP + 1)
            case '*';   set -g _RY_MTX_NA    (math $_RY_MTX_NA + 1)
        end
    end
end
function _rdi_matrix_footer --description "_rdi_render_matrix sub: Emit verdict-bearing footer rows + bottom bar"
    set -l _bar_top $argv[1]; set -l _inner $argv[2]; set -l _sep_c $argv[3]; set -l _sep_r $argv[4]; set -l _sep_e $argv[5]
    set -l _verdict PASS
    test "$_RY_MTX_WARN" -gt 0; and set _verdict PASS-WITH-WARNINGS
    test "$_RY_MTX_FAIL" -gt 0; and set _verdict FAIL
    set -q _RY_BOOT_CRIT_HIT; and test "$_RY_BOOT_CRIT_HIT" = true; and set _verdict FAIL-BOOT-CRITICAL
    set -q _RY_PREFLIGHT_ABORT; and test "$_RY_PREFLIGHT_ABORT" = true; and set _verdict PREFLIGHT # preflight abort = exit 3, not FAIL
    set -l _totals "Totals : $_RY_MTX_PASS PASS · $_RY_MTX_WARN WARN · $_RY_MTX_FAIL FAIL · $_RY_MTX_DEFER DEFER · $_RY_MTX_SKIP SKIP · $_RY_MTX_NA N/A"; set -l _elapsed "Elapsed: "(_rdi_elapsed)"   ·   Verdict: $_verdict"; set -l _log_line "Log    : $LOG_FILE"; set -l _next_msg "Next   : reboot · ./ry-install.fish --verify"
    test "$_verdict" != PASS; and set _next_msg "Next   : review FAIL/WARN above · re-run install (idempotent)"
    set -l _pad_inner (math "$_inner - 2")
    printf '╠%s╩%s╩%s╣\n' $_sep_c $_sep_r $_sep_e >&2
    printf '║ %s ║\n' (string pad -r -w $_pad_inner -- $_totals) >&2
    printf '║ %s ║\n' (string pad -r -w $_pad_inner -- $_elapsed) >&2
    printf '║ %s ║\n' (string pad -r -w $_pad_inner -- (string sub -l $_pad_inner -- $_log_line)) >&2
    printf '║ %s ║\n' (string pad -r -w $_pad_inner -- $_next_msg) >&2
    printf '╚%s╝\n' $_bar_top >&2
    _log "MATRIX_RENDERED: rows="(count $_RY_PHASE_RESULTS)" pass=$_RY_MTX_PASS warn=$_RY_MTX_WARN fail=$_RY_MTX_FAIL defer=$_RY_MTX_DEFER skip=$_RY_MTX_SKIP na=$_RY_MTX_NA verdict=$_verdict"
    set --erase _RY_MTX_PASS _RY_MTX_WARN _RY_MTX_FAIL _RY_MTX_DEFER _RY_MTX_SKIP _RY_MTX_NA
end
function _rdi_render_matrix --description "Render install phase matrix as box-drawn Unicode table"
    test (count $_RY_PHASE_RESULTS) -eq 0; and return 0
    set -q _RY_OUTPUT_BROKEN; and return 0
    set -l _w_check 34; set -l _w_result 6; set -l _w_evidence 50
    set -l _inner (math "$_w_check + $_w_result + $_w_evidence + 8"); set -l _bar_top (string repeat -n $_inner '═'); set -l _sep_c (string repeat -n (math "$_w_check + 2") '═'); set -l _sep_r (string repeat -n (math "$_w_result + 2") '═'); set -l _sep_e (string repeat -n (math "$_w_evidence + 2") '═')
    _rdi_matrix_header $_bar_top $_sep_c $_sep_r $_sep_e $_inner $_w_check $_w_result $_w_evidence
    _rdi_matrix_rows $_w_check $_w_result $_w_evidence
    _rdi_matrix_footer $_bar_top $_inner $_sep_c $_sep_r $_sep_e
end

# ── INSTALL SUMMARY: FINAL VERDICT + MANUAL STEPS + DO-NOT-REBOOT GATE ──
function _idf_boot_crit_banner --description "Forced DO-NOT-REBOOT recovery banner (shared: full install + --install-file)"
    _msg_print --force ERR "DO NOT REBOOT — boot-critical failure (verdict: FAIL-BOOT-CRITICAL)" # force bypasses QUIET
    _log "ERR: DO NOT REBOOT — boot-critical failure (verdict: FAIL-BOOT-CRITICAL)"
    for _bcl in \
        "Recovery steps:" \
        "  1. Inspect: ls -la /boot/vmlinuz-* /boot/initramfs-*.img; sudo bootctl list" \
        "  2. Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update" \
        "  3. Re-run ry-install (idempotent) — only reboot once verdict is PASS or PASS-WITH-WARNINGS" \
        "JSONL log captures the exact failure: $LOG_FILE"
        _msg_print --force INFO "$_bcl"; _log "INFO: $_bcl"
    end
end
function _rdi_summary --description "Print final install summary"
    if test "$INSTALL_HAD_ERRORS" = true
        _echo "INSTALLATION FINISHED WITH ERRORS"
        _err "Some steps had errors - review log for details"
    else
        _echo "INSTALLATION COMPLETE"
    end
    _rdi_render_matrix
    if set -q _RY_BOOT_CRIT_HIT; and test "$_RY_BOOT_CRIT_HIT" = true
        _idf_boot_crit_banner
        return 0
    end
    _info "Manual steps required:"
    _info "  1. Run 'rehash' or start new shell (updates command paths)"
    _info "  2. REBOOT to apply kernel cmdline and module changes"
    set -l _hint_n 2 # counter keeps hint numbering gap-free
    set -l _post_uname (command getent passwd $_MY_UID 2>/dev/null | command head -n 1 | command awk -F: '{print $1}') # single resolve
    if command -q pacman; and command pacman -Qq realtime-privileges >/dev/null 2>&1
        if test -n "$_post_uname"; and not contains -- realtime (command id -Gn -- "$_post_uname" 2>/dev/null | string split ' ')
            set _hint_n (math $_hint_n + 1)
            _info "  $_hint_n. Add user to realtime group for PipeWire RT scheduling:"
            _info "       sudo usermod -aG realtime $_post_uname  (then log out and back in)"
        end
    end
    if command -q pacman; and command pacman -Qq ddcutil >/dev/null 2>&1
        if test -n "$_post_uname"; and not contains -- i2c (command id -Gn -- "$_post_uname" 2>/dev/null | string split ' ')
            set _hint_n (math $_hint_n + 1)
            _info "  $_hint_n. Add user to i2c group for ddcutil monitor control:"
            _info "       sudo usermod -aG i2c $_post_uname  (then log out and back in)"
        end
    end
    _info "Post-reboot verification: ./ry-install.fish --verify"
    if test "$INSTALL_HAD_ERRORS" = true
        _warn "Done (with errors - see above)"
    else
        _ok "Done!"
    end
end

# ── INSTALL: TOP-LEVEL ORCHESTRATOR (preflight → phases → boot → finalize) ──
function _ry_do_install --description "Full installation: preflight, packages, configs, services, boot"
    _log_section "INSTALLATION START"
    _log "VERSION: $VERSION"
    _log "MODE: unattended"
    _echo "ry-install v$VERSION"
    _progress_init
    _install_preflight
    set -l _pre_rc $status
    if test "$_pre_rc" -ne 0; set -g _RY_PREFLIGHT_ABORT true; _progress_done; _rdi_render_matrix; _log_section "INSTALLATION END"; return $EXIT_PREFLIGHT; end
    _rdi_run_phases # rc discarded
    _install_rebuild_boot
    set -l _boot_rc $status
    test "$_boot_rc" -ne 0; and set -g INSTALL_HAD_ERRORS true
    if test "$_boot_rc" -eq "$EXIT_BOOT_CRIT"
        _err "Boot-critical failure — skipping finalization"
        _err "Fix boot issue first: sudo mkinitcpio -P && sudo sdboot-manage gen"
        set -g _PROG_FINALIZED_SKIP true; set -g _RY_BOOT_CRIT_HIT true
        _progress Finalize skip
    else
        not _install_finalize; and set -g INSTALL_HAD_ERRORS true
    end
    _progress_done
    _rdi_summary
    _log_section "INSTALLATION END"
    if test "$_boot_rc" -eq "$EXIT_BOOT_CRIT"; _log "INSTALL_BAILOUT: boot-critical failure → returning EXIT_BOOT_CRIT"; return $EXIT_BOOT_CRIT; end
    test "$INSTALL_HAD_ERRORS" = true; and return $EXIT_FAIL
    return $EXIT_OK
end

# ── --INSTALL-FILE: DISPATCH TABLE + ORCHESTRATOR ──
set -g _RY_POST_HOOKS \
    "/boot/*|boot" \
    "/etc/kernel/cmdline|cmdline" \
    "/etc/sdboot-manage.conf|boot" \
    "/etc/mkinitcpio.conf|boot" \
    "*/resolved.conf.d/*|resolved" \
    "*/logind.conf.d/*|logind" \
    "*/NetworkManager-dispatcher.service.d/*|nmdispatch" \
    "*/NetworkManager/conf.d/*|nm" \
    "/etc/iw-regdomain|regdom" \
    "/etc/bluetooth/main.conf|bluetooth" \
    "/etc/nftables.conf|nft" \
    "/etc/default/cpupower-service.conf|cpupower" \
    "*/sysctl.d/*|sysctl" \
    "/etc/udev/rules.d/*|udev" \
    "*/modprobe.d/*|modprobe" \
    "*/environment.d/*|envd" \
    "*/baloofilerc|baloo" \
    "*/MangoHud/MangoHud.conf|mangohud"
function _ir_validate_post_hooks --description "Refuse deploy when any _RY_POST_HOOKS tag lacks a _post_<tag> handler" # mirrors _ir_validate_keys
    set -l _seen_tags
    for _entry in $_RY_POST_HOOKS
        set -l _parts (string split -m1 '|' -- "$_entry"); set -l _tag $_parts[2]
        if test -z "$_tag"; _err_loud "_RY_POST_HOOKS entry has empty tag: '$_entry' — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
        contains -- "$_tag" $_seen_tags; and continue
        set -a _seen_tags "$_tag"
        if not functions -q "_post_$_tag"; _err_loud "_RY_POST_HOOKS tag '$_tag' has no handler '_post_$_tag' (entry '$_entry') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
function _post_hook_for_target --argument-names target --description "Return post-hook tag for a single target path" # first-match-wins by order
    for _entry in $_RY_POST_HOOKS
        set -l _parts (string split -m1 '|' -- $_entry)
        if string match -q "$_parts[1]" -- "$target"; echo "$_parts[2]"; return 0; end
    end
    return 1
end
function _idf_use_sudo_for_dst --argument-names target --description "Resolve managed-dst membership + emit sudo flag (true=system, false=user, empty=not-managed)"
    set -g _RY_RESOLVED_MANAGED_DST ""
    set -l _idx 1
    for dst in $SYSTEM_DESTINATIONS
        if test "$target" = "$dst"; or test "$target" = "$_RY_CANON_SYSTEM_DSTS[$_idx]"; set -g _RY_RESOLVED_MANAGED_DST "$dst"; echo true; return 0; end
        set _idx (math $_idx + 1)
    end
    set _idx 1
    for dst in $USER_DESTINATIONS
        if test "$target" = "$dst"; or test "$target" = "$_RY_CANON_USER_DSTS[$_idx]"; set -g _RY_RESOLVED_MANAGED_DST "$dst"; echo false; return 0; end
        set _idx (math $_idx + 1)
    end
    return 1
end
function _idf_dispatch_hook --argument-names target tag --description "Dispatch a post-hook tag to its _post_<tag> handler"
    if test -z "$tag"; or not functions -q "_post_$tag"; _err "Internal: unknown post-hook tag '$tag' (target=$target)"; return 1; end
    _post_$tag "$target"
end
function _ry_do_install_file --argument-names target --description "Install a single named config file (caller-canonicalized path)"
    _log_section "INSTALL-FILE START"
    if test -z "$target"
        _err "Usage: ry-install.fish --install-file <path>"
        _echo
        _info "Managed files:"
        for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS; _echo "  $dst"; end
        return $EXIT_USAGE
    end
    set -l _use_sudo (_idf_use_sudo_for_dst "$target")
    if test -z "$_use_sudo"; _err "Not a managed file: $target"; _info "Run without path to see managed files"; return $EXIT_USAGE; end
    set -l _mdst "$_RY_RESOLVED_MANAGED_DST" # literal dst; canonical key may diverge
    _echo "── ry-install v$VERSION - Install Single File ──"
    if test "$_use_sudo" = true; _ensure_sudo_cached; or return $EXIT_PREFLIGHT; end
    set -l _changed_before $_RY_DEPLOY_CHANGED_COUNT
    if not _ry_install_file "$_mdst" $_use_sudo; _err "Failed to install: $_mdst"; _log_section "INSTALL-FILE END"; return 1; end
    _echo
    _ok "Installed: $_mdst"
    set -l _hook_rc 0 # live-apply post-hook on byte change
    if test "$_RY_DEPLOY_CHANGED_COUNT" -gt "$_changed_before"
        set -l _h (_post_hook_for_target "$_mdst")
        if test -n "$_h"; _idf_dispatch_hook "$_mdst" "$_h"; set _hook_rc $status; end
    else
        _log "POST_HOOK_SKIP_UNCHANGED: target=$_mdst (bytes identical; no live-apply)"
    end
    if test "$_hook_rc" -eq "$EXIT_BOOT_CRIT"; set -g _RY_BOOT_CRIT_HIT true; _idf_boot_crit_banner; end
    _log_section "INSTALL-FILE END"
    return $_hook_rc
end

# ── --INSTALL-FILE: POST-HOOK HANDLERS (coverage enforced by _ir_validate_post_hooks) ──
function _pb_rebuild_cascade --argument-names target skip_mki --description "_post_boot_apply sub: mkinitcpio -P + sdboot-manage cascade"
    if test "$skip_mki" != true
        if not _run sudo -n mkinitcpio -P; _err "mkinitcpio failed"; _log "BOOT_REBUILD_FAILED: step=mkinitcpio target=$target"; return $EXIT_BOOT_CRIT; end
    end
    if not _sdboot_fallback_vfat_ok; _log "POST_BOOT_SDBOOT_REFUSED: target=$target"; return $EXIT_BOOT_CRIT; end
    if test "$SDBOOT_REMOVE_EXISTING" = yes
        set -l _boot (_resolve_boot_path)
        if test -z "$_boot"
            _err "Cannot resolve \$BOOT path — refusing boot-wipe gate"
            _err "CRITICAL: bootctl/findmnt failed AND /boot missing — aborting"
            _log "POST_BOOT_BOOT_RESOLVE_FAIL: target=$target"
            return $EXIT_BOOT_CRIT
        end
    end
    if not _run sudo -n sdboot-manage gen; _err "sdboot-manage gen failed"; _log "BOOT_REBUILD_FAILED: step='sdboot-manage gen' target=$target"; return $EXIT_BOOT_CRIT; end
    if not _run sudo -n sdboot-manage update; _err "sdboot-manage update failed"; _log "BOOT_REBUILD_FAILED: step='sdboot-manage update' target=$target"; return $EXIT_BOOT_CRIT; end
    return 0
end
function _post_boot_apply --argument-names target skip_mki --description "Shared post-hook body: taint gate + cascade + entry verify + sanity"
    _echo
    _check_boot_taint_gate
    set -l _gate_rc $status
    if test "$_gate_rc" -ne 0
        _log "POST_BOOT_REFUSED: target=$target gate_rc=$_gate_rc"
        return $EXIT_BOOT_CRIT
    end
    _pb_rebuild_cascade "$target" "$skip_mki"
    set -l _cas_rc $status
    if test "$_cas_rc" -ne 0; _err "CRITICAL: boot rebuild cascade failed — DO NOT REBOOT"; _info "  Fix: sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update"; return $_cas_rc; end
    set -l _boot_v (_resolve_boot_path)
    test -n "$_boot_v"; and _irb_verify_entries "$_boot_v"
    if not _preflight_boot_sanity; _err "CRITICAL: boot sanity check failed after single-file install — DO NOT REBOOT"; return $EXIT_BOOT_CRIT; end
    return 0
end
function _post_boot --argument-names target --description "Post-hook: rebuild boot entries (mkinitcpio + sdboot-manage)"
    _post_boot_apply "$target" false
end
function _post_cmdline --argument-names target --description "Post-hook: regenerate sdboot entries only (cmdline is not an initramfs input)"
    _post_boot_apply "$target" true
end

# ── POST-HOOKS: NON-BOOT LIVE-APPLY (SERVICE/CONFIG; FAILURES NON-FATAL, EXIT 0) ──
function _post_resolved --argument-names target --description "Post-hook: restart systemd-resolved"
    _echo
    if not _run sudo -n systemctl restart systemd-resolved
        _warn "systemd-resolved restart failed — drop-in applies at next boot (non-fatal; file deployed)"
        return 0
    end
    return 0
end
function _post_logind --argument-names target --description "Post-hook: notify reboot needed for logind"
    _info "Logind config $target changed — reboot required (restarting logind kills all sessions)"
    return 0
end
function _post_nmdispatch --argument-names target --description "Post-hook: daemon-reload after NetworkManager-dispatcher logging drop-in change"
    _echo
    if not _run sudo -n systemctl daemon-reload
        _warn "systemctl daemon-reload failed — dispatcher LogLevelMax applies at next boot (non-fatal; file deployed)"
        return 0
    end
    _info "  nm-dispatcher LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX active on next dispatch activation"
    return 0
end
function _post_nm --argument-names target --description "Post-hook: restart NetworkManager; deferred when WiFi is active route"
    _echo
    if not command -q NetworkManager
        _warn "NetworkManager config deployed but NetworkManager not installed — restart skipped; drop-in keys apply once installed or at next boot"
        _log "POST_NM_SKIP_NO_NM: target=$target"
        return 0
    end
    if _is_wifi_active_route
        _warn "NetworkManager config installed but restart deferred — WiFi is the active route."
        _info "  Config change will not take effect until next reboot or manual restart."
        _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=install_file target=$target"
        return 0
    end
    if not _run sudo -n systemctl restart NetworkManager
        _warn "NetworkManager restart failed — config applies on next reboot (non-fatal; file deployed)"
    end
    return 0
end
function _post_sysctl --argument-names target --description "Post-hook: apply sysctl tunables"
    _echo
    if not command -q sysctl
        _warn "sysctl(8) not found — tunables will apply on next reboot via systemd-sysctl.service"
        _info "  Install procps-ng for immediate apply: sudo pacman -S --needed procps-ng"
        return 0
    end
    if not _run sudo -n sysctl --system
        _warn "sysctl --system failed — tunables not applied until reboot (non-fatal; file deployed)"
        _info "  Retry: sudo sysctl --system"
        return 0
    end
    return 0
end
function _post_mangohud --argument-names target --description "Post-hook: notify MangoHud.conf change (read at next game/Vulkan app launch)"
    _info "MangoHud $target changed — applies at next launch under 'mangohud %command%' (no service restart needed)"
    _info "  Toggle the HUD in-app with Shift_R+F12 (MangoHud default)"
    return 0
end
function _post_envd --argument-names target --description "Post-hook: notify session restart needed for environment.d"
    _info "environment.d $target changed — log out and back in (or restart user session) to apply"
    _info "  OR for live apply: systemctl --user import-environment + restart active user units"
    _info "  Active systemd --user services retain old environment until restarted"
    return 0
end
function _post_baloo --argument-names target --description "Post-hook: disable + purge KDE Baloo index after baloofilerc change"
    _echo
    set -l _balooctl
    for _b in balooctl6 balooctl
        command -q $_b; and set _balooctl $_b; and break
    end
    if test -z "$_balooctl"
        _info "baloofilerc deployed; balooctl not found — indexing stays disabled via config at next login (no live purge)"
        return 0
    end
    if _run $_balooctl disable # user-scope; no sudo (runs against the caller's session)
        _ok "Baloo indexing disabled and index purged ($_balooctl disable)"
    else
        _warn "$_balooctl disable failed — config still disables indexing at next login (non-fatal; file deployed)"
    end
    return 0
end
function _post_cpupower --argument-names target --description "Post-hook: restart cpupower.service after /etc/default/cpupower-service.conf change"
    _echo
    if not _run sudo -n systemctl restart cpupower.service
        _warn "cpupower.service restart failed — governor change applies on next boot (non-fatal; file deployed)"
        _info "  Governor from /etc/default/cpupower-service.conf re-applies on next boot"
        return 0
    end
    return 0
end
function _post_nft --argument-names target --description "Post-hook: validate + (if active) reload nftables ruleset"
    _echo
    if not _run sudo -n nft -c -f /etc/nftables.conf
        _warn "nftables ruleset failed validation (nft -c) — not reloaded; fix /etc/nftables.conf"
        return 0
    end
    if _run sudo -n systemctl restart nftables.service # oneshot re-runs nft -f (no ExecReload)
        _ok "nftables ruleset applied (systemctl restart — oneshot re-runs nft -f)"
    else
        _warn "nftables restart failed — validated ruleset applies when the service next starts (reboot)"
    end
    return 0
end
function _post_regdom --argument-names target --description "Post-hook: apply wireless regdom after /etc/iw-regdomain change"
    _echo
    _apply_wireless_regdom
end
function _post_bluetooth --argument-names target --description "Post-hook: restart bluetooth.service after /etc/bluetooth/main.conf change"
    _echo
    if not command -q bluetoothctl; and not test -e /usr/lib/systemd/system/bluetooth.service
        _warn "bluetooth/main.conf deployed but bluez not installed — restart skipped; keys apply once bluez is installed or at next boot"
        _log "POST_BT_SKIP_NO_BLUEZ: target=$target"
        return 0
    end
    if not _run sudo -n systemctl try-restart bluetooth.service
        _warn "bluetooth.service try-restart failed — config applies on next reboot (non-fatal; file deployed)"
    end
    return 0
end
function _post_udev --argument-names target --description "Post-hook: reload udev rules + retrigger block devices after /etc/udev/rules.d/* change"
    _echo
    if not command -q udevadm
        _warn "udevadm(8) not found — I/O scheduler rule applies at next boot"
        return 0
    end
    _resolve_systemd_ver
    if set -q _RY_SYSTEMD_VER; and test "$_RY_SYSTEMD_VER" -ge 254 # udevadm verify landed in v254
        if not _run sudo -n udevadm verify -- "$target"
            _warn "udevadm verify failed for $target — rules not reloaded; fix the rule file"
            return 0
        end
    else
        _warn "udevadm verify unavailable (systemd "(set -q _RY_SYSTEMD_VER; and echo $_RY_SYSTEMD_VER; or echo unknown)" < 254) — reloading $target unvalidated; check the rule by hand if you edited it"
        _log "UDEV_VERIFY_SKIP: systemd "(set -q _RY_SYSTEMD_VER; and echo $_RY_SYSTEMD_VER; or echo unknown)" < 254 — udevadm verify unavailable; reloading rule unvalidated"
    end
    if not _run sudo -n udevadm control --reload-rules
        _warn "udevadm control --reload-rules failed — rule applies at next boot (non-fatal; file deployed)"
        _info "  Retry: sudo udevadm control --reload-rules; and sudo udevadm trigger --subsystem-match=block --action=change"
        return 0
    end
    _run sudo -n udevadm trigger --subsystem-match=block --action=change; or _warn "udevadm trigger failed — scheduler applies at next boot or device hotplug"
    return 0
end
function _post_modprobe --argument-names target --description "Post-hook: notify reboot needed for modprobe.d option change (load-time; cannot live-apply to an already-loaded module)"
    _info "modprobe.d $target changed — reboot required to apply (module options are read at load time; an already-loaded module keeps its current parameters until reloaded)"
    _info "  No initramfs rebuild needed for this file; the option takes effect when the module next loads (reboot, or manual rmmod/modprobe of the affected module)"
    return 0
end

# ── PRE-DISPATCH EXIT (ARGPARSE-ERROR + EARLY-BAIL LOG CLEANUP) ──
function _pre_dispatch_log_cleanup --description "Remove pre-dispatch log file/dir (no exit; for caller-managed return paths)"
    set -l _preserve false
    set -q _RY_HEADER_WRITTEN; and test "$_RY_HEADER_WRITTEN" = true; and set _preserve true
    set -q _RY_LOG_WRITTEN; and test "$_RY_LOG_WRITTEN" = true; and set _preserve true
    test "$_preserve" = false; and command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -- "$LOG_DIR" 2>/dev/null
    command rmdir -- (command dirname -- "$LOG_DIR") 2>/dev/null
    command rmdir -- "$_RY_HOME_DIR" 2>/dev/null
    set -g _RY_LOG_SUPPRESS_CREATE true # Suppress lazy-create
end
function _pre_dispatch_exit --argument-names code --description "Pre-dispatch teardown: log/dir cleanup, then exit"; _pre_dispatch_log_cleanup; _ry_exit $code; end
function _early_usage_exit --description "Print usage error to stderr, remove pre-dispatch log, exit EXIT_USAGE"
    echo "[ERR] $argv" >&2
    echo >&2
    _ry_show_help >&2
    _pre_dispatch_exit $EXIT_USAGE
end

# ── MAIN: ARGPARSE + MODE DISPATCH + LOG HEADER + EXIT ──
set -g MODE install; set -g INSTALL_FILE_TARGET ""
set -l _ORIG_ARGV $argv; set -l _ap_errfile (_mktemp_or_null -p (_tmp_dir) ry-argparse-err.XXXXXX)
_track_tmpfile "$_ap_errfile"
argparse --name=(path basename -- (status filename)) \
    --exclusive=verify,check,install-file \
    h/help v/version V/verbose \
    verify check install-file= \
    -- $argv 2>"$_ap_errfile"
set -l _argparse_rc $status
if test "$_argparse_rc" -ne 0
    set -l _ap_msg ""
    if test "$_ap_errfile" = /dev/null
        set _ap_msg "(argparse error message unavailable: tmpfile alloc failed)"
    else if test -s "$_ap_errfile"
        set _ap_msg (command head -n 3 -- "$_ap_errfile" 2>/dev/null | string replace -ra '\e\[[0-9;]*[a-zA-Z]' '' | string join -- '; ' | string trim --)
    end
    test -n "$_ap_msg"; or set _ap_msg "Invalid arguments: $_ORIG_ARGV"
    echo "[ERR] $_ap_msg" >&2
    _rm_tmp "$_ap_errfile" false
    echo >&2
    _ry_show_help >&2
    _pre_dispatch_exit $EXIT_USAGE
end
_rm_tmp "$_ap_errfile" false
if set -q _flag_help; _ry_show_help; _pre_dispatch_exit $EXIT_OK; end
if set -q _flag_version; echo "v$VERSION"; _pre_dispatch_exit $EXIT_OK; end
set -q _flag_verify; and set -g MODE verify
set -q _flag_check; and set -g MODE check
if set -q _flag_install_file
    set -g MODE install-file; set -l _if_val "$_flag_install_file"
    test -z "$_if_val"; and _early_usage_exit "--install-file requires a non-empty absolute path"
    if not string match -q -- '/*' "$_if_val"
        if string match -qr -- '^--(verify|check|verbose|help|version)$' "$_if_val"
            _early_usage_exit "--install-file requires a value, but the next argument is the flag $_if_val. Use --install-file=<path> or place the path immediately after"
        else if string match -q -- '-*' "$_if_val"
            _early_usage_exit "--install-file requires an absolute path argument (got flag: $_if_val). Use --install-file=<path> for paths starting with '-'"
        else
            _early_usage_exit "--install-file requires absolute path (got: $_if_val)"
        end
    end
    if string match -qr -- '[\x00-\x1f\x7f]' "$_if_val"; _early_usage_exit "--install-file path contains control character — refusing (would break JSONL header / shell quoting)"; end
    set -l _byte_len (printf '%s' "$_if_val" | command wc -c | string trim --)
    if not string match -qr '^\d+$' -- "$_byte_len"; _early_usage_exit "--install-file path byte-length probe failed (wc -c returned '$_byte_len') — refusing"; end
    test "$_byte_len" -gt 4096; and _early_usage_exit "--install-file path exceeds PATH_MAX (4096 bytes)"
    for _comp in (string split / -- "$_if_val") # NAME_MAX 255 per component
        test (printf '%s' "$_comp" | command wc -c | string trim --) -gt 255; and _early_usage_exit "--install-file path component exceeds NAME_MAX (255 bytes): $_comp"
    end
    set --erase _comp
    set -l _canon (command realpath -m -- "$_if_val" 2>/dev/null)
    if test -n "$_canon"
        set -g INSTALL_FILE_TARGET "$_canon"
    else
        echo "[WARN] realpath -m failed on '$_if_val' — using literal path; managed-file validation may not match" >&2
        set -g INSTALL_FILE_TARGET "$_if_val"
    end
end
if test (count $argv) -gt 0; echo "[ERR] Unexpected positional argument(s): $argv" >&2; echo >&2; _ry_show_help >&2; _pre_dispatch_exit $EXIT_USAGE; end
if test "$MODE" = check
    set -q _flag_verbose; and _log "CHECK_VERBOSE_IGNORED: -V/--verbose dropped under --check (silent-probe contract)" # --check ignores -V (silent-probe contract)
else if set -q _flag_verbose; or test "$MODE" != install
    set -g QUIET false
end

# ── MAIN: LOG RENAME + 0600 CREATE + JSONL HEADER ──
set -l mode_label $MODE
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"; set -l old_log "$LOG_FILE"; set -l _log_rename_ok true
if test -f "$old_log"; and test "$old_log" != "$new_log"
    if not command mv -- "$old_log" "$new_log" 2>/dev/null
        if command cp -p -- "$old_log" "$new_log" 2>/dev/null
            command rm -f -- "$old_log" 2>/dev/null
            test "$MODE" != check; and echo "[WARN] Log rename via mv failed; recovered via cp+rm: $old_log -> $new_log" >&2
        else
            set _log_rename_ok false # Old path stays writable: keep logging there
            test "$MODE" != check; and echo "[WARN] Log rename failed (mv and cp both): $old_log -> $new_log (keeping old path)" >&2
        end
    end
end
test "$_log_rename_ok" = true; and set -g LOG_FILE "$new_log"
if test -L "$LOG_FILE"; command rm -f -- "$LOG_FILE" 2>/dev/null; test "$MODE" != check; and echo "[WARN] Pre-existing LOG_FILE was a symlink — removed; will re-create with 0600" >&2; end
if not test -f "$LOG_FILE"
    set -l _prev_umask (umask)
    umask 0177
    if not command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
        if not command touch -- "$LOG_FILE" 2>/dev/null; umask $_prev_umask; echo "[ERR] Failed to create log file: $LOG_FILE" >&2; _ry_exit $EXIT_PREFLIGHT; end
        if not command chmod -- 600 "$LOG_FILE" 2>/dev/null; umask $_prev_umask; command rm -f -- "$LOG_FILE" 2>/dev/null; echo "[ERR] Failed to set 0600 on log file: $LOG_FILE" >&2; _ry_exit $EXIT_PREFLIGHT; end
    end
    umask $_prev_umask
else
    command chmod -- 600 "$LOG_FILE" 2>/dev/null
end
set -l _argv_parts; set -l _argv_in (status filename) $_ORIG_ARGV
for _r in $_argv_in; set -a _argv_parts '"'(_json_str "$_r")'"'; end
set --erase _r
set -l _argv_json '['(string join -- ',' $_argv_parts)']'; set -l _verbose_json false
test "$QUIET" = false; and set _verbose_json true
printf '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","verbose":%s,"argv":%s}\n' (command date '+%Y-%m-%dT%H:%M:%S%z') "$VERSION" "$PROFILE_NAME" "$MODE" "$_verbose_json" "$_argv_json" >>"$LOG_FILE" 2>/dev/null # literal format string
if test "$status" -eq 0
    set -g _RY_HEADER_WRITTEN true
else
    not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true
end
if set -q _RY_PERM_FIX_NOTICES
    for _n in $_RY_PERM_FIX_NOTICES; _log "$_n"; end
    set --erase _RY_PERM_FIX_NOTICES _n
end

# ── MAIN: RUNTIME INIT + LOCK + MODE DISPATCH + FOOTER ──
set -g _RY_EXIT_CODE 0
function _set_exit --argument-names _code --description "Set both _RY_EXIT_CODE and _INTENDED_EXIT_CODE atomically"; set -g _RY_EXIT_CODE $_code; set -g _INTENDED_EXIT_CODE $_code; end
_init_runtime
switch "$MODE"
    case install-file install
        _acquire_lock; or _pre_dispatch_exit $EXIT_LOCK
    case '*'
end
switch "$MODE"
    case verify
        _ry_verify_all
        _set_exit $status
    case check
        _ry_do_check
        _set_exit $status
    case install-file
        _ry_do_install_file "$INSTALL_FILE_TARGET"
        _set_exit $status
    case install
        _ry_do_install
        _set_exit $status
    case '*'
        _msg_print --force ERR "Unknown mode: $MODE"
        _log "ERR: Unknown mode: $MODE"
        _set_exit $EXIT_USAGE
end
_write_footer "$_RY_EXIT_CODE" ""
set -q _RY_LOG_WRITE_FAIL; and test "$_RY_LOG_WRITE_FAIL" = true; and test "$MODE" != check; and echo "[WARN] Log writes failed during this run — JSONL may be incomplete (check disk space / file permissions on $LOG_FILE)" >&2
test "$MODE" != check; and not set -q _RY_LOG_WRITE_FAIL; and echo "[INFO] Log file: $LOG_FILE" >&2
exit $_RY_EXIT_CODE
