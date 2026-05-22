#!/usr/bin/env fish
# ry-install v7.4.43 (2026-05-22) — CachyOS config manager | Ryan Musante | MIT.
if status stack-trace | string match -q '*from sourcing*'; echo "[ERR] ry-install: must be executed, not sourced (use ./ry-install.fish)" >&2; exit 1; end
set -g VERSION "7.4.43"; set -g EXIT_OK 0; set -g EXIT_FAIL 1; set -g EXIT_USAGE 2; set -g EXIT_PREFLIGHT 3; set -g EXIT_BOOT_CRIT 4; set -g EXIT_LOCK 5; set -g EXIT_DRIFT 10
# EXIT_GEN_* are internal sub-codes — _awf_render_to_tmp converts them to EXIT_FAIL; never the process exit code
set -g EXIT_GEN_NOFN 11; set -g EXIT_GEN_NOUUID 12; set -g EXIT_GEN_SYSCTL 13
# EXIT_RUN_TMPFAIL is an internal _run sentinel — distinct from timeout codes (124/137); never the process exit code
set -g EXIT_RUN_TMPFAIL 251
set -g _RY_RUN_TIMEOUT_DEFAULT 3600
set -g PROFILE_NAME gtr9_pro; set -g PROFILE_DESC "Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S"; set -g _RY_MANAGED_FILE_COUNT 12

function _ry_show_help --description "Display usage information and available subcommands"
    printf '%s\n' \
        "" \
        "ry-install v$VERSION" \
        "Self-contained CachyOS configuration for $PROFILE_DESC" \
        "Single fish script, $_RY_MANAGED_FILE_COUNT embedded configs, no external dependencies." \
        "Usage: "(status filename)" [OPTIONS]" \
        "INSTALLATION:" \
        "  (no args)         Default mode: unattended install" \
        "  -V, --verbose     Show install output (install: silent by default; check: always silent; install-file/verify-*: always verbose)" \
        "VERIFICATION:" \
        "  --verify-static   Check config files match expected content" \
        "  --verify-runtime  Check live system state (run after reboot)" \
        "  --check           Silent idempotency probe (0=clean 3=preflight 10=drift). Requires functional sudo + systemctl;" \
        "                    ERR_NO_DATA from systemctl probes is treated as preflight (rc=3), masking any drift detection" \
        "UTILITIES:" \
        "  --install-file <path>  Re-deploy a single managed file" \
        "OPTIONS:" \
        "  --                End of options" \
        "  -h, --help        Show this help" \
        "  -v, --version     Show version" \
        "EXIT CODES:" \
        "  0 ok · 1 verify-FAIL, install-warn, or old-kernel warn · 2 usage · 3 preflight · 4 boot-critical · 5 lock · 10 --check drift" \
        "  Signal-induced runs: process \$status may not match signal (fish 3.x --on-signal limitation);" \
        "  canonical code recorded in JSONL footer.exit_code (130 INT / 143 TERM / 129 HUP / 131 QUIT / 134 ABRT / 138 USR1 / 140 USR2)" \
        "ENVIRONMENT (see README.md for detail):" \
        "  RY_RUN_TIMEOUT=<sec>  Per-_run wall-clock cap. Default $_RY_RUN_TIMEOUT_DEFAULT. 0=disable." \
        "  RY_INITRD_WARN_MB=<MB>  Initramfs size warning threshold. Default 100." \
        "  RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1  Use pacman -Sy --needed (install-only)." \
        "  RY_INSTALL_FORCE_BOOT_REBUILD=1  Bypass torn-package gate (recovery)." \
        "  RY_INSTALL_PKG_REMOVE_CASCADE=1  Cascade-remove reverse deps." \
        "  RY_INSTALL_SKIP_HARDWARE_CHECK=1  Bypass EXPECTED_CPU_MATCH hard-fail." \
        "  RY_INSTALL_WIRELESS_REGDOM=<CC>  Write WIRELESS_REGDOM=<CC> to /etc/conf.d/wireless-regdom (opt-in)." \
        "  RY_INSTALL_NO_INTERACTIVE_SUDO=1  Refuse interactive sudo -v fallback (strict unattended; cron/ansible/systemd unit)." \
        "  RY_INSTALL_NO_MATRIX=1  Suppress post-install run-summary matrix (JSONL log unaffected)." \
        "  NO_COLOR  Suppress ANSI color (any value, per no-color.org)." \
        "Log: ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl" \
        ""
end

for _early_arg in $argv
    switch "$_early_arg"
        case --
            break
        case -h --help
            _ry_show_help
            exit $EXIT_OK
        case -v --version
            echo "v$VERSION"
            exit $EXIT_OK
    end
end
set --erase _early_arg
set -g _MY_UID (command id -u)

function _ry_erase_handlers --description "Erase signal/exit handler functions"; functions -e _cleanup _cleanup_pipe _cleanup_on_exit _progress_on_winch 2>/dev/null; end
# Pre-bootstrap callers must `functions -q`-guard _log/_write_footer/_do_cleanup.
function _ry_exit --argument-names code --description "Set bail sentinel and exit"
    test -z "$code"; and set code 0
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

set -g QUIET true
if not string match -qr '^\d+$' -- "$_MY_UID"; echo "[ERR] id -u returned non-numeric value: '$_MY_UID' — cannot determine user identity" >&2; _ry_exit $EXIT_PREFLIGHT; end
if test "$_MY_UID" -eq 0; echo "[ERR] ry-install must not run as root. Run as your normal user; sudo is invoked internally." >&2; _ry_exit $EXIT_USAGE; end

set -g _RY_NO_COLOR false
set -q NO_COLOR; and set -g _RY_NO_COLOR true
test "$TERM" = dumb; and set -g _RY_NO_COLOR true
set -l fish_ver $FISH_VERSION; set -l parts (string split '.' -- "$fish_ver"); set -l _fish_minor (string replace -r '[^0-9].*' '' -- "$parts[2]")
if not string match -qr '^\d+$' -- "$parts[1]"; or test -z "$_fish_minor"; or not string match -qr '^\d+$' -- "$_fish_minor"; echo "[ERR] fish version unparseable: '$fish_ver'" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -l _fish_ok 0
test "$parts[1]" -gt 3; and set _fish_ok 1
test "$parts[1]" -eq 3; and test "$_fish_minor" -ge 6; and set _fish_ok 1
if test $_fish_ok -eq 0; echo "[ERR] fish 3.6+ required (found: $fish_ver)" >&2; _ry_exit $EXIT_PREFLIGHT; end
# Canonical system paths first; defends sudo/pacman/findmnt against PATH-injection; user PATH retained as suffix.
set -l _ry_path_new
for _ry_p in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin $PATH; contains -- $_ry_p $_ry_path_new; or set -a _ry_path_new $_ry_p; end
set -gx PATH $_ry_path_new
set --erase _ry_path_new _ry_p
if set -q TMPDIR; and test -n "$TMPDIR"; and not string match -q -- '/*' "$TMPDIR"; echo "[WARN] TMPDIR is not an absolute path ($TMPDIR) — falling back to /tmp" >&2; set -gx TMPDIR /tmp; end
# Override TMPDIR if non-existent; otherwise downstream mktemp -p cascades to EXIT_RUN_TMPFAIL.
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
if not command -q timeout; echo "[ERR] GNU coreutils timeout(1) required (used by _run for hang-protection)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command timeout --foreground --kill-after=1 1 true 2>/dev/null; echo "[ERR] timeout(1) lacks --foreground/--kill-after (need GNU coreutils ≥ 8.x; busybox/uutils not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command -q stat; echo "[ERR] GNU coreutils stat(1) required (used for mode/owner verification)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command -q date; echo "[ERR] GNU coreutils date(1) required (used for timestamps in DATE_LABEL, TIMESTAMP, JSONL ts fields)" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -g DATE_LABEL (command date '+%Y-%m-%d')
set -g TIMESTAMP (command date '+%Y%m%d-%H%M%S%z')"-"$fish_pid
if test -z "$HOME"; or not test -d "$HOME"
    set -g HOME (command getent passwd $_MY_UID 2>/dev/null | command head -n 1 | command awk -F: '{print $6}')
    if test -z "$HOME"; or not test -d "$HOME"; echo "[ERR] Cannot determine HOME directory" >&2; _ry_exit $EXIT_PREFLIGHT; end
end
set -g HOME (string trim -r -c / -- (string trim -- "$HOME"))
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
    if test -n "$_pre"; and test "$_pre" != "$_post"; not set -q _RY_PERM_FIX_NOTICES; and set -g _RY_PERM_FIX_NOTICES; set -ga _RY_PERM_FIX_NOTICES "LOG_DIR_PERM_FIX: $_ld_path $_pre→$_post"; end
    if test "$_post" != 700; echo "[ERR] Log dir mode is $_post (expected 700): $_ld_path" >&2; _ry_exit $EXIT_PREFLIGHT; end
end
set --erase _ld_path
set -g LOG_FILE "$LOG_DIR/preflight-$TIMESTAMP.jsonl"; set -g INSTALL_HAD_ERRORS false

set -g _RY_BOOT_TAINTED false
# Deploy failure on any of these 4 sets _RY_BOOT_TAINTED; blocks rebuild unless RY_INSTALL_FORCE_BOOT_REBUILD=1.
set -g _RY_BOOT_CRITICAL_DSTS "/boot/loader/loader.conf" /etc/kernel/cmdline "/etc/sdboot-manage.conf" "/etc/mkinitcpio.conf"
set -g _TRACKED_TMPFILES; set -g _SYS_TMP_DIRS; set -g _USR_TMP_DIRS; set -g _RY_PHASE_RESULTS
# Reset to 0 in _rdi_run_phases before _install_system_files so "Configs" matrix evidence excludes pre-deploys.
set -g _RY_DEPLOY_CHANGED_COUNT 0; set -g _RY_DEPLOY_IDEMPOTENT_COUNT 0; set -g _PROFILE_USES_WIFI_BACKEND false
# NF-inverted pair: malformed branch uses word/comma bounds to skip LABEL=ext4_root substrings.
set -g _RY_AWK_EXT4_FILTER '!/^[ \t]*#/ && NF >= 4 && $3 == "ext4" { print $0 }'
set -g _RY_AWK_EXT4_MALFORMED_FILTER '!/^[ \t]*#/ && NF < 4 && $0 ~ /(^|[ \t,])ext4([ \t,]|$)/ { print $0 }'
set -g NM_RESTART_DELAY 3; set -g _PROG_BAR_WIDTH 40
set -g KVER (command uname -r); set -g KVER_PARTS (string split '.' -- "$KVER"); set -g KVER_MAJOR $KVER_PARTS[1]
if not string match -qr '^\d+$' -- "$KVER_MAJOR"; echo "[ERR] Cannot parse kernel major version from uname -r: $KVER" >&2; _ry_exit $EXIT_PREFLIGHT; end
# Strip non-digit suffix (e.g. `-cachyos1`, `-rc1`, `-arch1`) so version comparisons see integers, not strings.
set -g KVER_MINOR (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[2]")
if test -z "$KVER_MINOR"; or not string match -qr '^\d+$' -- "$KVER_MINOR"; echo "[ERR] Cannot parse kernel minor version from uname -r: $KVER" >&2; _ry_exit $EXIT_PREFLIGHT; end
function _kconfig_cache --description "Return cached /proc/config.gz lines (lazy-loaded; empty on missing config)"
    if not set -q _KCONFIG_LOADED
        if test -f /proc/config.gz
            set -g _KCONFIG_DATA (command zcat /proc/config.gz 2>/dev/null)
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
    else if _kconfig_cache | command grep -q -- '^CONFIG_NTSYNC=y'
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
function _unit_state_padded --argument-names unit --description "Return _unit_state values"
    set -l _v (_unit_state "$unit")
    if test (count $_v) -lt 3
        printf '%s\n' ERR_NO_DATA ERR_NO_DATA ERR_NO_DATA
    else
        printf '%s\n' $_v[1] $_v[2] $_v[3]
    end
end
function _verify_unit_syntax --argument-names unit_path label intended_scope --description "Verify unit syntax via systemd-analyze"
    set -l _scope_label auto
    test -n "$intended_scope"; and set _scope_label $intended_scope
    _log "VERIFY_UNIT: $label ($unit_path) scope=$_scope_label"
    command -q systemd-analyze; or begin
        _warn "  systemd-analyze not available — skipping $label"
        return 0
    end
    set -l user_flag
    if test "$intended_scope" = user
        set user_flag --user
    else if test "$intended_scope" != system
        string match -q '*/.config/systemd/user/*' -- "$unit_path"; and set user_flag --user
    end
    set -l _err_out (command systemd-analyze $user_flag verify "$unit_path" 2>&1)
    if test $status -eq 0; test -n "$_err_out"; and _log "VERIFY_UNIT_WARN: ($label) "(printf '%s\n' $_err_out | command head -n 5 | string join -- '; '); _ok "  $label: syntax OK"; return 0; end
    _log "VERIFY_UNIT_ERR: ($label) "(printf '%s\n' $_err_out | command head -n 5 | string join -- '; ')
    _fail "  $label: INVALID SYNTAX"
    return 1
end
function _write_footer --argument-names exit_code extra_key --description "Append JSONL footer to LOG_FILE"
    set -q _FOOTER_WRITTEN; and return 0
    set -q LOG_FILE; or return 0
    begin
        test -n "$LOG_FILE"; and test -f "$LOG_FILE"
    end; or return 0
    set -g _FOOTER_WRITTEN true; set -l _mode_esc (_json_str "$MODE"); set -l _ts (command date '+%Y-%m-%dT%H:%M:%S%z'); set -l _extra ""
    test -n "$extra_key"; and set _extra ",\""(_json_str "$extra_key")"\":true"
    set -l _gen_fail 0
    set -q VERIFY_GEN_FAIL; and set _gen_fail $VERIFY_GEN_FAIL
    printf '{"ts":"%s","event":"footer","mode":"%s","exit_code":%d,"pass":%d,"fail":%d,"warn":%d,"gen_fail":%d%s}\n' \
        "$_ts" "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" "$_gen_fail" "$_extra" >>"$LOG_FILE" 2>/dev/null
    test $status -ne 0; and not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true
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

function _acquire_lock_fresh --description "Try fresh atomic-mkdir lock"
    set -l _prev_umask (umask)
    umask 0077
    command mkdir -- "$LOCK_DIR" 2>/dev/null
    set -l _mk_rc $status
    umask $_prev_umask
    test $_mk_rc -ne 0; and return 2
    # Sentinel must precede chmod; signal between mkdir and sentinel would leak LOCK_DIR via _dc_kill_children gate.
    set -g _RY_LOCK_DIR_OWNED true
    command chmod -- 700 "$LOCK_DIR" 2>/dev/null
    set -l _pid_tmp (command mktemp -p "$LOCK_DIR" .pid.XXXXXX 2>/dev/null)
    if test -z "$_pid_tmp"; or not printf '%s\n' "$fish_pid" >"$_pid_tmp" 2>/dev/null
        test -n "$_pid_tmp"; and command rm -f -- "$_pid_tmp" 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null
        set --erase _RY_LOCK_DIR_OWNED
        echo "[ERR] Failed to write lock pid file: $LOCK_FILE" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    if not command mv -Tf -- "$_pid_tmp" "$LOCK_FILE" 2>/dev/null
        command rm -f -- "$_pid_tmp" 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null
        set --erase _RY_LOCK_DIR_OWNED
        echo "[ERR] Failed to install lock pid file: $LOCK_FILE" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    command chmod -- 600 "$LOCK_FILE" 2>/dev/null
    set -g _RY_HOLDS_LOCK true
    _log "LOCK_ACQUIRED: pid=$fish_pid dir=$LOCK_DIR"
    return 0
end
function _acquire_lock --description "Acquire instance lock (atomic mkdir; stale-lock reclaim)"
    set -g LOCK_DIR "$_RY_HOME_DIR/.lock"; set -g LOCK_FILE "$LOCK_DIR/pid"
    command mkdir -p -- (command dirname -- "$LOCK_DIR") 2>/dev/null
    _acquire_lock_fresh
    set -l _fresh_rc $status
    test $_fresh_rc -eq 0; and return 0
    test $_fresh_rc -ne 2; and return 1
    set -l _stale_pid (command cat -- "$LOCK_FILE" 2>/dev/null | string trim --)
    set -l _can_reclaim false
    if string match -qr '^[1-9]\d*$' -- "$_stale_pid"
        if not command kill -0 "$_stale_pid" 2>/dev/null
            set _can_reclaim true
            functions -q _log; and _log "LOCK_STALE_CLAIM: pid=$_stale_pid dir=$LOCK_DIR (PID not running, reclaiming)"
        else
            # PID alive — verify it's fish; Linux recycles PIDs after parent death.
            set -l _stale_comm (command cat -- "/proc/$_stale_pid/comm" 2>/dev/null | string trim --)
            if test -n "$_stale_comm"; and test "$_stale_comm" != fish
                set _can_reclaim true
                functions -q _log; and _log "LOCK_STALE_CLAIM: pid=$_stale_pid comm='$_stale_comm' (not fish — PID recycled, reclaiming)"
            else if test -z "$_stale_comm"; and not command kill -0 "$_stale_pid" 2>/dev/null
                # Race: proc died between initial kill -0 success and /proc/$pid/comm read.
                set _can_reclaim true
                functions -q _log; and _log "LOCK_STALE_CLAIM: pid=$_stale_pid dir=$LOCK_DIR (PID died during comm read, reclaiming)"
            end
        end
    end
    if test "$_can_reclaim" = true
        command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
        _acquire_lock_fresh
        if test $status -eq 0
            set -l _owner_pid (command cat -- "$LOCK_FILE" 2>/dev/null | string trim --)
            test "$_owner_pid" = "$fish_pid"; and return 0
            functions -q _log; and _log "LOCK_RECLAIM_RACE: post-reclaim owner_pid='$_owner_pid' != fish_pid=$fish_pid — refusing"
            set --erase _RY_HOLDS_LOCK _RY_LOCK_DIR_OWNED
            return 1
        end
    end
    return 1
end
function _dc_mki_revert --description "_do_cleanup sub: signal-time mkinitcpio.conf revert"
    set -q _RY_MKI_HAD_ORIG; and test "$_RY_MKI_HAD_ORIG" = true; or return 0
    set -q _RY_MKI_BACKUP_FILE; and test -n "$_RY_MKI_BACKUP_FILE"; or return 0
    if functions -q _mkinitcpio_revert; and command -q sudo; and sudo -n test -f "$_RY_MKI_BACKUP_FILE" 2>/dev/null
        functions -q _log; and _log "MKINITCPIO_REVERT_SIGNAL: cleanup-time revert triggered (backup=$_RY_MKI_BACKUP_FILE)"
        _mkinitcpio_revert "$_RY_MKI_BACKUP_FILE" 2>/dev/null
    else
        functions -q _log; and _log "MKINITCPIO_REVERT_SIGNAL_SKIP: backup unavailable or sudo missing (backup=$_RY_MKI_BACKUP_FILE)"
    end
    set --erase _RY_MKI_BACKUP_FILE _RY_MKI_HAD_ORIG
end
function _dc_sweep_tmpfiles --description "_do_cleanup sub. Remove tracked tmpfiles/dirs"
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
    for _tf in $_stuck_tmpfiles
        if test "$_has_sudo" = true; and begin; string match -q '/etc/*' -- "$_tf"; or string match -q '/boot/*' -- "$_tf"; or string match -q '/efi/*' -- "$_tf"; or string match -q '/var/*' -- "$_tf"; end
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
function _dc_sweep_filesystem --description "_do_cleanup sub. Sweep TMPDIR for leftover ry-* tmpfiles"
    functions -q _tmp_dir; or return 0
    set -l _tmpdir (_tmp_dir)
    set -l _tmp_globs \
        'ry-sudo-err.*' \
        'ry-run.*' \
        'ry-val-unit.*' \
        'ry-argparse-err.*' \
        'ry-fstab-tee-err.*' \
        'ry-fstab-awk-err.*'
    set -l _find_name_args
    for _g in $_tmp_globs; test -n "$_find_name_args"; and set -a _find_name_args -o; set -a _find_name_args -name "$_g"; end
    command find "$_tmpdir" -xdev -maxdepth 1 \( $_find_name_args \) -type f -user "$_MY_UID" -delete 2>/dev/null
    command find "$_tmpdir" -xdev -mindepth 2 -maxdepth 2 -path "$_tmpdir/ry-run.*" -type f -user "$_MY_UID" -delete 2>/dev/null
    command find "$_tmpdir" -xdev -maxdepth 1 -name 'ry-run.*' -type d -empty -user "$_MY_UID" -delete 2>/dev/null
end
function _dc_erase_globals --description "_do_cleanup sub. Erase cached globals"
    set --erase _KCONFIG_DATA _KCONFIG_LOADED _RY_SKIP_IWD _RY_ESP_PATH _RY_BOOT_PATH
    set --erase _RY_ESP_TRIED _RY_BOOT_TRIED
    set --erase _RY_SYSTEMD_VER _RY_SYSTEMD_VER_TRIED _RY_DEPLOYED_SERVICES
    set --erase _RY_BOOT_COUNT _RY_BOOT_ENUM_OK _CPU_PATH
    set --erase _RY_CANON_SYSTEM_DSTS _RY_CANON_USER_DSTS _SYS_TMP_DIRS _USR_TMP_DIRS
    set --erase _PROFILE_USES_WIFI_BACKEND _RY_ESP_FALLBACK _RY_PACMAN_REVERT_ATTEMPTED
    set --erase _RY_MKI_REVERT_FAILED _RY_AUR_PARTIAL _RY_PACTREE_MISSING_WARNED
    set --erase _RY_RUN_TIMEOUT_WARNED _PROG_CLOCK _RY_HOLDS_LOCK _RY_LOCK_DIR_OWNED
    set --erase _RY_DMESG_CACHE _RY_DMESG_PREEMPT _RY_DMESG_BAR _RY_DMESG_TSC
    set --erase _RY_READSYM_RESULT _RY_PKG_REMOVE_SKIPS _RY_BOOT_TAINTED
    set --erase _RY_PHASE_RESULTS _RY_DEPLOY_CHANGED_COUNT _RY_DEPLOY_IDEMPOTENT_COUNT _RY_BOOT_CRIT_HIT
    set --erase _RY_MTX_PASS _RY_MTX_WARN _RY_MTX_FAIL _RY_MTX_DEFER _RY_MTX_SKIP _RY_MTX_NA
end
function _dc_kill_children --description "_do_cleanup sub. Release lock + reap child PIDs (pkill -P, then SIGKILL after grace)"
    if set -q _RY_HOLDS_LOCK; or set -q _RY_LOCK_DIR_OWNED; set -q LOCK_DIR; and command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null; end
    if command -q pkill
        command pkill -TERM -P "$fish_pid" 2>/dev/null
        # 0.5s grace: gives pacman/paru and atomic ops a chance to flush before SIGKILL.
        command sleep 0.5 2>/dev/null; or command sleep 1 2>/dev/null
        command pkill -KILL -P "$fish_pid" 2>/dev/null
    end
end
function _do_cleanup --description "Master cleanup: orchestrate revert → tmpfiles → fs sweep → children → globals"
    _dc_mki_revert
    _dc_sweep_tmpfiles
    _dc_sweep_filesystem
    _dc_kill_children
    _dc_erase_globals
end

set -g VERIFY_OK 0; set -g VERIFY_FAIL 0; set -g VERIFY_WARN 0; set -g VERIFY_GEN_FAIL 0

function _teardown --argument-names mode --description "Unified cleanup: progress teardown, footer, resources"
    _progress_teardown
    switch $mode
        case signal
            _write_footer "$argv[2]" interrupted
            _do_cleanup
        case exit
            _write_footer "$argv[2]" cleanup_exit
            _do_cleanup
        case '*'
            _err "_teardown: unknown mode '$mode'"
            return 1
    end
end
function _cleanup --on-signal INT --on-signal TERM --on-signal HUP --on-signal QUIT --on-signal USR1 --on-signal USR2 --on-signal ABRT --description "Signal handler for INT/TERM/HUP/QUIT/USR1/USR2/ABRT"
    test "$_CLEANUP_DONE" = true; and return 0
    set -g _CLEANUP_DONE true; set -l _sig_label SIG$argv[1]
    string match -q 'SIG*' -- "$argv[1]"; and set _sig_label "$argv[1]"
    test -z "$argv[1]"; and set _sig_label exit
    echo "" >&2
    echo "[WARN] Caught $_sig_label - cleaning up..." >&2
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
        case USR1 SIGUSR1
            set _sig_exit 138
        case USR2 SIGUSR2
            set _sig_exit 140
        case ABRT SIGABRT
            set _sig_exit 134
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
    # Priority: explicit normal-path → _ry_exit bail sentinel → $status.
    if set -q _INTENDED_EXIT_CODE
        set _exit_status $_INTENDED_EXIT_CODE
    else if set -q _RY_INSTALL_LAST_EXIT
        set _exit_status $_RY_INSTALL_LAST_EXIT
    end
    test "$_CLEANUP_DONE" = true; and return 0
    _teardown exit $_exit_status
end

set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" \
    /etc/kernel/cmdline \
    "/etc/sdboot-manage.conf" \
    "/etc/mkinitcpio.conf" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
    "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/iwd/main.conf" \
    "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/default/cpupower-service.conf" \
    "/etc/sysctl.d/99-cachyos-sysctl.conf" \
    "/etc/tmpfiles.d/99-cachyos-thp.conf"
set -g USER_DESTINATIONS "$HOME/.config/environment.d/10-environment.conf"
set -g SERVICE_DESTINATIONS
set -g _RY_IWD_GATED_DSTS "/etc/iwd/main.conf" "/etc/NetworkManager/conf.d/99-cachyos-nm.conf"
set -l _ry_dst_count (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)
if test "$_ry_dst_count" -ne "$_RY_MANAGED_FILE_COUNT"; echo "[ERR] _RY_MANAGED_FILE_COUNT drift: declared=$_RY_MANAGED_FILE_COUNT computed=$_ry_dst_count" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -g LOADER_DEFAULT "@saved"; set -g LOADER_TIMEOUT 0; set -g LOADER_CONSOLE_MODE keep; set -g LOADER_EDITOR no
set -g SDBOOT_DEFAULT_ENTRY manual; set -g SDBOOT_OVERWRITE yes; set -g SDBOOT_REMOVE_EXISTING yes; set -g SDBOOT_REMOVE_OBSOLETE yes
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
set -g MKINITCPIO_HOOKS base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck
set -g MKINITCPIO_COMPRESSION zstd; set -g MKINITCPIO_COMPRESSION_OPTIONS -1 -T0
set -g RESOLVED_MDNS resolve
set -g LOGIND_IGNORE_KEYS HandlePowerKey HandlePowerKeyLongPress HandleSuspendKey HandleSuspendKeyLongPress HandleHibernateKey HandleHibernateKeyLongPress HandleRebootKey HandleRebootKeyLongPress HandleSecureAttentionKey
set -g IWD_ENABLE_NETWORK_CONFIG false; set -g IWD_DRIVER_QUIRKS "PowerSaveDisable=*"; set -g IWD_DNS_SERVICE systemd
set -g NM_WIFI_BACKEND iwd; set -g NM_WIFI_POWERSAVE 2; set -g NM_LOG_LEVEL WARN
set -g ENV_VARS \
    "DXVK_LOG_LEVEL=none" \
    "DXVK_LOG_PATH=none" \
    "MESA_SHADER_CACHE_MAX_SIZE=4G" \
    "PROTON_ENABLE_WAYLAND=1" \
    "PROTON_LOCAL_SHADER_CACHE=1" \
    "PROTON_USE_NTSYNC=1" \
    "RADV_EXPERIMENTAL=transfer_queue" \
    "RADV_PERFTEST=sam,nircache" \
    "VKD3D_DEBUG=none" \
    "VKD3D_SHADER_DEBUG=none" \
    "WINEDEBUG=-all"
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
    "vm.compaction_proactiveness=0"
set -g PKGS_ADD nvme-cli cachyos-gaming-meta cachyos-gaming-applications mesa lib32-mesa fd sd dust procs bottom htop git-delta lm_sensors realtime-privileges cpupower
set -g PKGS_DEL plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme octopi micro cachyos-micro-settings btop bolt
set -g AUR_PKGS mkinitcpio-firmware mt76-mt7925-dkms
set -g _RY_PKG_REMOVE_SKIPS
set -g EXPECTED_VULKAN_PKGS vulkan-radeon lib32-vulkan-radeon lib32-mesa
set -g MASK ananicy-cpp.service avahi-daemon.service avahi-daemon.socket \
    power-profiles-daemon.service lvm2-monitor.service \
    NetworkManager-wait-online.service ufw.service \
    sleep.target suspend.target hibernate.target \
    hybrid-sleep.target suspend-then-hibernate.target
set -g EXPECTED_SERVICES fstrim.timer NetworkManager.service cpupower.service
set -g _RY_PKG_MANAGED_SERVICES NetworkManager.service
set -g BOOT_SPACE_CRIT 200; set -g BOOT_SPACE_WARN 500; set -g ROOT_AVAIL_CRIT 2; set -g ROOT_AVAIL_WARN 5
set -g BOOT_TIME_TARGET 15; set -g INITRD_WARN_MB 100
if set -q RY_INITRD_WARN_MB; and test -n "$RY_INITRD_WARN_MB"
    if string match -qr '^[1-9][0-9]*$' -- "$RY_INITRD_WARN_MB"; set -g INITRD_WARN_MB $RY_INITRD_WARN_MB
    else; not set -q _RY_DEFERRED_WARNS; and set -g _RY_DEFERRED_WARNS; set -ga _RY_DEFERRED_WARNS "RY_INITRD_WARN_MB='$RY_INITRD_WARN_MB' is invalid (expected positive integer) — using default $INITRD_WARN_MB MB"
    end
end
set -g EXPECTED_CPU_MATCH "Ryzen AI Max"
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
        case install install-file
            _err_loud "Cannot detect root UUID ($_reason) — /etc/kernel/cmdline cannot be generated"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        case verify-static
            _err_loud "Cannot detect root UUID ($_reason) — exact /etc/kernel/cmdline byte-equality cannot be verified"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        case verify-runtime
            # verify-runtime reads /proc/cmdline only; UUID missing → skip cross-check, continue.
            _log "ROOT_UUID_UNAVAILABLE: mode=verify-runtime reason=$_reason — root=UUID cross-check skipped, other runtime probes proceed"
        case '*'
            _log "ROOT_UUID_UNAVAILABLE: mode=$MODE reason=$_reason — non-fatal for this mode"
    end
end
function _ir_precompute_caches --description "Precompute tmpdir / WiFi-backend / canonical-dst caches"
    set -g _SYS_TMP_DIRS
    for _d in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS; set -l _dir (command dirname -- "$_d"); contains -- "$_dir" $_SYS_TMP_DIRS; or set -a _SYS_TMP_DIRS "$_dir"; end
    set -g _USR_TMP_DIRS
    for _d in $USER_DESTINATIONS; set -l _dir (command dirname -- "$_d"); contains -- "$_dir" $_USR_TMP_DIRS; or set -a _USR_TMP_DIRS "$_dir"; end
    set -g _PROFILE_USES_WIFI_BACKEND false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_d"; or string match -q '*/iwd/*' -- "$_d"; set -g _PROFILE_USES_WIFI_BACKEND true; break; end
    end
    set -g _RY_CANON_SYSTEM_DSTS
    for _d in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS; set -a _RY_CANON_SYSTEM_DSTS (command realpath -m -- "$_d" 2>/dev/null; or echo "$_d"); end
    set -g _RY_CANON_USER_DSTS
    for _d in $USER_DESTINATIONS; set -a _RY_CANON_USER_DSTS (command realpath -m -- "$_d" 2>/dev/null; or echo "$_d"); end
    set -l _sys_in (count $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS)
    set -l _sys_out (count $_RY_CANON_SYSTEM_DSTS)
    if test "$_sys_in" -ne "$_sys_out"; _err_loud "BUG: _RY_CANON_SYSTEM_DSTS count drift: in=$_sys_in out=$_sys_out"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    set -l _usr_in (count $USER_DESTINATIONS)
    set -l _usr_out (count $_RY_CANON_USER_DSTS)
    if test "$_usr_in" -ne "$_usr_out"; _err_loud "BUG: _RY_CANON_USER_DSTS count drift: in=$_usr_in out=$_usr_out"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
end
function _ir_validate_counts --description "Refuse to deploy when documented array counts drift from invariants"
    set -l _expect \
        KERNEL_PARAMS:15 \
        MKINITCPIO_HOOKS:11 \
        MKINITCPIO_MODULES:1 \
        LOGIND_IGNORE_KEYS:9 \
        ENV_VARS:11 \
        SYSCTL_VALUES:16 \
        PKGS_ADD:15 \
        PKGS_DEL:8 \
        AUR_PKGS:2 \
        MASK:12 \
        EXPECTED_VULKAN_PKGS:3 \
        EXPECTED_SERVICES:3 \
        _RY_PKG_MANAGED_SERVICES:1 \
        _RY_POST_HOOKS:14 \
        _RY_BOOT_CRITICAL_DSTS:4
    for _kv in $_expect
        set -l _parts (string split -m1 ':' -- "$_kv"); set -l _name $_parts[1]; set -l _want $_parts[2]; set -l _got (count $$_name)
        if test "$_got" -ne "$_want"; _err_loud "$_name count drift: got=$_got expected=$_want — README/script desync, refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
function _ir_validate_keys --description "Refuse deploy on _tmpfile_key collision"
    set -l _seen_keys
    for _d in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        set -l _k (_tmpfile_key "$_d")
        if contains -- "$_k" $_seen_keys; _err_loud "Destination key collision: '$_d' produces key '_content_$_k' already in use — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
        set -a _seen_keys "$_k"
    end
end
function _init_runtime --description "Cache root UUID + validate invariants + precompute caches"
    _ir_resolve_root_uuid
    if set -q EXPECTED_CPU_MATCH; and test -n "$EXPECTED_CPU_MATCH"
        set -l _cpu_model (string match -rg -- '^model name\s*:\s*(.*)$' < /proc/cpuinfo 2>/dev/null)[1]
        if test -n "$_cpu_model"; and not string match -q -i -- "*$EXPECTED_CPU_MATCH*" "$_cpu_model"
            if test "$RY_INSTALL_SKIP_HARDWARE_CHECK" = 1
                _warn "Hardware mismatch (override): expected $EXPECTED_CPU_MATCH, detected: $_cpu_model"
                _log "HARDWARE_MISMATCH_OVERRIDE: expected=$EXPECTED_CPU_MATCH detected=$_cpu_model"
            else
                _err_loud "Hardware mismatch: profile $PROFILE_NAME expects $EXPECTED_CPU_MATCH, detected: $_cpu_model"
                _err_loud "  Deploying gfx1151/Strix Halo defaults on non-matching CPU would set incorrect kernel cmdline + initramfs MODULES."
                _err_loud "  Override (at your risk): RY_INSTALL_SKIP_HARDWARE_CHECK=1 ./ry-install.fish"
                _pre_dispatch_exit $EXIT_PREFLIGHT
            end
        end
    end
    _ir_validate_counts
    _ir_validate_keys
    _ir_precompute_caches
    set -l _kp_metachar_re '[\s"`$;\\\\]'
    for _kp in $KERNEL_PARAMS
        if string match -qr -- "$_kp_metachar_re" "$_kp"
            _err_loud "KERNEL_PARAMS member contains whitespace, quote, or shell metachar: '$_kp' — refuse to deploy (would corrupt cmdline / LINUX_OPTIONS)"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        end
    end
    for _pn in $PKGS_ADD $PKGS_DEL $AUR_PKGS
        if string match -q -- '-*' "$_pn"; _err_loud "Package name starts with dash: '$_pn' — pacman/paru would parse as flag, refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
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
    printf '%s\n' "# systemd-resolved configuration" "[Resolve]" "MulticastDNS=$RESOLVED_MDNS" "LLMNR=no" "DNSOverTLS=opportunistic" "DNSSEC=allow-downgrade"
end
function _content__etc_systemd_logind.conf.d_99-cachyos-logind.conf --description "Generate content for systemd-logind drop-in"
    printf '%s\n' "# systemd-logind configuration - desktop power handling"
    printf '%s\n' "[Login]"
    _resolve_systemd_ver
    for key in $LOGIND_IGNORE_KEYS
        if test "$key" = HandleSecureAttentionKey; test -z "$_RY_SYSTEMD_VER"; or test "$_RY_SYSTEMD_VER" -lt 257; and continue; end
        printf '%s\n' "$key=ignore"
    end
end
function _content__etc_iwd_main.conf --description "Generate content for /etc/iwd/main.conf"
    printf '%s\n' "# iwd configuration - minimal config for NetworkManager backend" "[General]" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "" "[DriverQuirks]"
    for quirk in $IWD_DRIVER_QUIRKS; printf '%s\n' "$quirk"; end
    printf '%s\n' "" "[Network]" "NameResolvingService=$IWD_DNS_SERVICE"
end
function _content__etc_NetworkManager_conf.d_99-cachyos-nm.conf --description "Generate content for NetworkManager drop-in (iwd backend)"
    printf '%s\n' "# NetworkManager configuration - iwd backend" "[device]" "wifi.backend=$NM_WIFI_BACKEND" "" "[connection]" "wifi.powersave=$NM_WIFI_POWERSAVE" "" "[logging]" "level=$NM_LOG_LEVEL"
end
function _content_HOME_.config_environment.d_10-environment.conf --description "Generate content for ~/.config/environment.d/10-environment.conf"
    printf '%s\n' "# Environment variables for systemd user services and graphical sessions — loaded by systemd --user (COSMIC, Flatpak, D-Bus activated apps)"
    for var in $ENV_VARS; printf '%s\n' "$var"; end
end
function _content__etc_default_cpupower-service.conf --description "Generate content for cpupower-service.conf"
    printf '%s\n' "# cpupower-service.conf — sourced by /usr/lib/systemd/scripts/cpupower (cpupower.service)" "GOVERNOR='performance'"
end
function _content__etc_sysctl.d_99-cachyos-sysctl.conf --description "Generate content for sysctl drop-in"
    printf '%s\n' "# ry-install sysctl tunables (priority 99 — loaded after CachyOS vendor 70-cachyos-settings.conf; overrides net.core.netdev_max_backlog 4096 → 16384)"
    set -l _printed 0; set -g _RY_SYSCTL_BAD_ENTRIES
    for entry in $SYSCTL_VALUES
        if not string match -qr '^\s*\S[^=]*=\s*\S' -- "$entry"; set -ga _RY_SYSCTL_BAD_ENTRIES "$entry"; functions -q _log; and _log "SYSCTL_SKIP_MALFORMED: '$entry' (require non-empty key=value)"; continue; end
        set -l parts (string split -m1 '=' -- "$entry"); set -l key (string trim -- "$parts[1]"); set -l val (string trim -- "$parts[2]")
        printf '%s = %s\n' "$key" "$val"
        set _printed (math $_printed + 1)
    end
    if test $_printed -ne (count $SYSCTL_VALUES); functions -q _log; and _log "SYSCTL_COUNT_MISMATCH: printed=$_printed expected="(count $SYSCTL_VALUES); return $EXIT_GEN_SYSCTL; end
end
function _content__etc_tmpfiles.d_99-cachyos-thp.conf --description "Generate content for THP tmpfiles drop-in"
    printf '%s\n' "# THP shrink_underused: keep huge pages intact on high-RAM workstations (128 GB profile)" "w /sys/kernel/mm/transparent_hugepage/shrink_underused - - - - 0"
end
function _ry_get_file_content --argument-names dst --description "Generate expected content for a destination (dispatcher)"
    set -l fn "_content_"(_tmpfile_key "$dst")
    functions -q $fn; or return $EXIT_GEN_NOFN
    # Dynamic dispatch: function name built from destination path via _tmpfile_key.
    $fn
end
function _ensure_sudo_cached --description "Cache sudo credential once before repeated sudo -n calls"
    if not command -q sudo; _err "Sudo credential cache failed: sudo not found"; return 1; end
    set -l _sudo_err (_mktemp_or_null -p (_tmp_dir) ry-sudo-err.XXXXXX)
    _track_tmpfile "$_sudo_err"
    sudo -n -v 2>"$_sudo_err"
    set -l _rc $status
    if test $_rc -ne 0
        if test "$RY_INSTALL_NO_INTERACTIVE_SUDO" = 1
            _err "Sudo credential not cached and RY_INSTALL_NO_INTERACTIVE_SUDO=1 — refusing interactive sudo -v"
            _log "SUDO_CACHE_NONINTERACTIVE_FORCED: RY_INSTALL_NO_INTERACTIVE_SUDO=1"
        else if isatty 0; and isatty 2
            # Truncate stale stderr (interactive readback); RY_INSTALL_NO_INTERACTIVE_SUDO=1 for strict-unattended runs.
            sudo -v 2>"$_sudo_err"
            set _rc $status
        else
            _err "Sudo credential required but stdin/stderr is not a TTY — pre-cache via 'sudo -v' before running"
            _log "SUDO_CACHE_NONINTERACTIVE: stdin or stderr is not a tty — refusing interactive sudo -v"
        end
    end
    if test $_rc -ne 0
        set -l _reason (command head -n 1 -- "$_sudo_err" 2>/dev/null)
        _rm_tmp "$_sudo_err" false
        _log "SUDO_CACHE_FAIL: $_reason"
        if test -n "$_reason"
            _err "Sudo credential cache failed: $_reason"
        else
            _err "Sudo credential cache failed"
        end
        return 1
    end
    _rm_tmp "$_sudo_err" false
    return 0
end
function _as --argument-names use_sudo --description "Prefix command with sudo or command based on use_sudo flag"
    if test (count $argv) -lt 2; _log "BUG: _as called without command (argv=$argv)"; return 250; end
    if test "$use_sudo" != true; and test "$use_sudo" != false; _log "BUG: _as called with non-bool use_sudo='$use_sudo' (argv=$argv)"; return 250; end
    if test "$use_sudo" = true
        sudo -n -- $argv[2..-1]
    else
        command $argv[2..-1]
    end
end
function _tmpfile_key --argument-names path --description "Generate filename key from destination path"
    set -l p $path
    if string match -q -- "$HOME/*" "$p"
        set -l _rest (string sub -s (math (string length -- "$HOME") + 1) -- "$p")
        set p "HOME$_rest"
    else if test "$p" = "$HOME"
        set p HOME
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
    if test $_rm_rc -eq 0; or not test -e "$path"
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
function _is_symlink --argument-names path use_sudo --description "Sudo-aware test -L (rc 0/1/2 = symlink/not/sudo-lapse)"
    if test "$use_sudo" = true
        sudo -n true 2>/dev/null; or return 2
        sudo -n test -L "$path" 2>/dev/null
    else
        test -L "$path"
    end
end
function _is_system_dst --argument-names dst --description "True if dst is a system path (requires sudo to read)"
    # Extend if new destinations land outside /etc or /boot.
    string match -q '/etc/*' -- "$dst"; or string match -q '/boot/*' -- "$dst"
end
function _installed_bytes --argument-names dst --description "Raw bytes of installed file (rc: 0=ok 1=fail 2=sudo-lapse)"
    set -l _bytes
    if _is_system_dst "$dst"
        sudo -n true 2>/dev/null; or return 2
        sudo -n test -r "$dst" 2>/dev/null; or return 1
        set _bytes (sudo -n cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines)
        set -l _ps $pipestatus
        if test "$_ps[1]" -ne 0; sudo -n true 2>/dev/null; or return 2; return 1; end
    else
        test -r "$dst"; or return 1
        set _bytes (command cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines)
        set -l _ps $pipestatus
        test "$_ps[1]" -eq 0; or return 1
    end
    # bare printf: pipe into string collect would inject phantom \n at callers (asymmetric vs _ry_content_bytes).
    printf '%s' "$_bytes"
    return 0
end
function _should_skip_iwd --argument-names dst --description "True if dst is iwd-gated AND iwd not installed (memoized)"
    contains -- "$dst" $_RY_IWD_GATED_DSTS; or return 1
    if not set -q _RY_SKIP_IWD
        if command -q pacman; and command pacman -Qi iwd >/dev/null 2>&1
            set -g _RY_SKIP_IWD false
        else
            set -g _RY_SKIP_IWD true
        end
    end
    test "$_RY_SKIP_IWD" = true
end
function _mask_list_effective --description "Effective MASK list"; printf '%s\n' $MASK; end
function _json_str --description "Escape a string for safe JSON embedding (RFC 8259 mandatory + DEL)"
    set -l s "$argv[1]"
    if not string match -qr -- '[\x00-\x1f"\\\\\x7f]' "$s"; printf '%s' "$s" | string collect --allow-empty; return $status; end
    set s (string replace -a -- \\ \\\\ "$s" | string collect)
    set s (string replace -a -- '"' '\\"' "$s" | string collect)
    set s (string replace -a -- \n '\\n' "$s" | string collect)
    set s (string replace -a -- \r '\\r' "$s" | string collect)
    set s (string replace -a -- \t '\\t' "$s" | string collect)
    set s (string replace -a -- \b '\\b' "$s" | string collect)
    set s (string replace -a -- \f '\\f' "$s" | string collect)
    # NUL omitted: fish strings cannot carry NUL — truncated at variable boundary.
    for _hex in 01 02 03 04 05 06 07 0b 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 7f; set s (string replace -a -- (printf '\x'$_hex) '\u00'$_hex "$s" | string collect); end
    printf '%s' "$s" | string collect --allow-empty
end
function _log_section --argument-names name --description "Emit a section boundary marker line via _log"; _log "=== $name ==="; end
function _log --description "Append a timestamped JSONL line to LOG_FILE"
    set -q _RY_LOG_WRITE_FAIL; and test "$_RY_LOG_WRITE_FAIL" = true; and return 0
    # Pre-bootstrap guard: skip when LOG_FILE not yet set (callable via functions -q before L199 init).
    test -n "$LOG_FILE"; or return 0
    # Skip lazy-create after _pre_dispatch_log_cleanup; prevents orphan preflight-*.jsonl on argparse-error paths.
    set -q _RY_LOG_SUPPRESS_CREATE; and test "$_RY_LOG_SUPPRESS_CREATE" = true; and not test -f "$LOG_FILE"; and return 0
    if not test -f "$LOG_FILE"
        set -l _prev_umask (umask)
        umask 0177
        command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
        set -l _create_rc $status
        umask $_prev_umask
        if test $_create_rc -ne 0; not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true; return 0; end
    end
    set -l _ts (command date '+%Y-%m-%dT%H:%M:%S%z'); set -l raw (string join -- " " $argv); set -l data (_json_str "$raw")
    printf '{"ts":"%s","event":"log","data":"%s"}\n' "$_ts" "$data" >>"$LOG_FILE" 2>/dev/null
    set -l _write_rc $status
    test $_write_rc -eq 0; and not set -q _RY_LOG_WRITTEN; and set -g _RY_LOG_WRITTEN true
    if test $_write_rc -ne 0; and not set -q _RY_LOG_WRITE_FAIL; set -g _RY_LOG_WRITE_FAIL true; end
end
function _msg_print --argument-names level --description "Internal: leveled message to stderr"
    set -l _force false
    # _msg_start indexes msg-part-1 in argv; --force shifts past the sentinel without mutating argv.
    set -l _msg_start 2
    if test "$level" = --force; set _force true; set level $argv[2]; set _msg_start 3; end
    set -l msg (string join -- " " $argv[$_msg_start..])
    test -z "$msg"; and return 0
    if test "$_force" = false; test "$QUIET" = false; or return 0; end
    set -q _RY_OUTPUT_BROKEN; and return 0
    if test "$_RY_NO_COLOR" = true; or not isatty 2; printf '[%s] %s\n' "$level" "$msg" >&2; return 0; end
    set -l _color normal
    switch $level
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
    switch $level
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

# Invariant: _ok/_fail/_warn/_info/_err always return 0 (callers chain via `; and`/`; or`).
function _ok --description "Emit OK-level message and increment VERIFY_OK"; _msg OK $argv; return 0; end
function _fail --description "Emit FAIL-level message and increment VERIFY_FAIL"; _msg FAIL $argv; return 0; end
function _fail_silent --description "Emit FAIL-level message without incrementing VERIFY_FAIL"; _msg_nocount FAIL $argv; return 0; end
function _info --description "Emit INFO-level message (no counter)"; _msg INFO $argv; return 0; end
function _warn --description "Emit WARN-level message and increment VERIFY_WARN"; _msg WARN $argv; return 0; end
# Appends to run-summary matrix; U+2502 reserved as delimiter. JSONL-logged regardless of QUIET.
function _phase_record --argument-names check result evidence --description "Append a row to the install summary matrix and JSONL"
    # Defensive: strip embedded newlines (break matrix rows) and U+2502 (delimiter collision).
    set -l _e (string replace -ra '[\n\r│]' ' ' -- "$evidence")
    set -l _c (string replace -ra '[\n\r│]' ' ' -- "$check")
    set -ga _RY_PHASE_RESULTS "$_c│$result│$_e"
    _log "PHASE_RESULT: check='$_c' result=$result evidence='$_e'"
end
# _RY_LOUD_ERR force-prints err to stderr in QUIET install mode (--check stays silent).
function _err --description "Emit ERR-level message (force-prints to stderr when _RY_LOUD_ERR=true)"
    if set -q _RY_LOUD_ERR; and test "$_RY_LOUD_ERR" = true; and test "$MODE" != check
        _log "ERR: "(string join -- " " $argv)
        set -g VERIFY_FAIL (math $VERIFY_FAIL + 1)
        _msg_print --force ERR $argv
    else
        _msg ERR $argv
    end
    return 0
end
function _err_loud --description "Fatal-preflight err: stderr regardless of QUIET, except MODE=check (silent-probe contract)"
    set -l msg (string join -- " " $argv)
    _log "ERR: $msg"
    test "$MODE" = check; and return 0
    _msg_print --force ERR $argv
end
function _echo --description "Print a plain message without level prefix"
    _log "ECHO: $argv"
    if test "$QUIET" = false; and not set -q _RY_OUTPUT_BROKEN; printf '%s\n' (string join ' ' -- $argv) >&2; end
end
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
    # 6-phase list must match README "Install Flow".
    set -g _PROG_STEPS Preflight Packages Configuration Services Boot Finalize
    set -g _PROG_CUR 0; set -g _PROG_TOTAL (count $_PROG_STEPS)
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
    test $rows -ge 10; or return 0
    command tput cols >/dev/null 2>&1; or return 0
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
    set -l pct (math "floor($current * 100 / $_PROG_TOTAL)")
    set -l filled (math "floor($current * $_PROG_BAR_WIDTH / $_PROG_TOTAL)")
    set -l empty (math "$_PROG_BAR_WIDTH - $filled")
    set -l bar
    test $filled -gt 0; and set bar (string repeat -n $filled '█')
    test $empty -gt 0; and set bar "$bar"(string repeat -n $empty '░')
    printf '\e7\e[%d;1H\e[K[%s] %3d%% %s\e8' \
        $_PROG_ROWS "$bar" $pct "$name" >&2
end
function _progress_done --description "Finalize progress bar and log elapsed seconds"
    set -l _now (_progress_now)
    set -l elapsed (math $_now - $_PROG_START)
    test -n "$_PROG_STEP_NAME"; and _log "PROG_STEP_END: name=$_PROG_STEP_NAME secs="(math $_now - $_PROG_STEP_START)
    set -l _skip false
    set -q _PROG_FINALIZED_SKIP; and test "$_PROG_FINALIZED_SKIP" = true; and set _skip true
    _log "PROG_DONE: elapsed_secs=$elapsed skip=$_skip"
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
    set -q _PROG_PINNED; or return 0
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r\e[%d;1H\e[K\n' $_PROG_ROWS >&2
    set -g _PROG_PINNED false
end
function _progress_on_winch --on-signal WINCH --description "Re-anchor progress bar on terminal resize"
    set -q _PROG_PINNED; or return 0
    test "$_PROG_PINNED" = true; or return 0
    set -l _new_rows (command tput lines 2>/dev/null)
    string match -qr '^\d+$' -- "$_new_rows"; or return 0
    test "$_new_rows" -lt 10; and return 0
    set -g _PROG_ROWS $_new_rows
    printf '\e7\e[1;%dr\e8' (math $_PROG_ROWS - 1) >&2
    _progress_redraw "$_PROG_STEP_NAME" $_PROG_CUR
end
function _run_resolve_timeout --description "Resolve RY_RUN_TIMEOUT to a usable seconds integer or empty (empty = disable)"
    if not set -q RY_RUN_TIMEOUT; echo $_RY_RUN_TIMEOUT_DEFAULT; return 0; end
    if test -z "$RY_RUN_TIMEOUT"; echo $_RY_RUN_TIMEOUT_DEFAULT; return 0; end
    if string match -qr '^[0-9]+$' -- "$RY_RUN_TIMEOUT"
        set -l _t (math "$RY_RUN_TIMEOUT")
        if test $_t -eq 0; echo ""; return 0; end
        echo $_t
        return 0
    end
    if not set -q _RY_RUN_TIMEOUT_WARNED
        set -g _RY_RUN_TIMEOUT_WARNED true
        _warn "RY_RUN_TIMEOUT='$RY_RUN_TIMEOUT' is invalid (expected non-negative integer; 0 to disable) — using default "$_RY_RUN_TIMEOUT_DEFAULT"s"
        _log "RY_RUN_TIMEOUT_INVALID: value=$RY_RUN_TIMEOUT — using default $_RY_RUN_TIMEOUT_DEFAULT"
    end
    echo $_RY_RUN_TIMEOUT_DEFAULT
end
# Splits cap into head + 100 tail so final-line diagnostics (AUR build errors, pacman conflicts) survive truncation.
function _run_emit_stream --argument-names label_tag tmpfile ret cap --description "_run sub. Capture stream, log, emit per QUIET/rc."
    test -s "$tmpfile"; or return 0
    set -l _total (command wc -l <"$tmpfile" 2>/dev/null | string trim --)
    # wc -l misses final no-NL line; add 1 when tail byte is non-empty.
    set -l _last_byte (command tail -c1 -- "$tmpfile" 2>/dev/null)
    test -n "$_last_byte"; and string match -qr '^\d+$' -- "$_total"; and set _total (math $_total + 1)
    set -l _redacted; set -l _head_cap (math "max(1, $cap - 100)"); set -l _tail_cap 100; set -l _need_tail false
    string match -qr '^\d+$' -- "$_total"; and test "$_total" -gt "$cap"; and set _need_tail true
    for _l in (command head -n $_head_cap -- "$tmpfile"); set -a _redacted "$_l"; end
    if test "$_need_tail" = true
        set -a _redacted "[... "(math $_total - $_head_cap - $_tail_cap)" lines elided ...]"
        for _l in (command tail -n $_tail_cap -- "$tmpfile"); set -a _redacted "$_l"; end
    end
    _log "$label_tag: "(string join -- " | " $_redacted)
    string match -qr '^\d+$' -- "$_total"; and test "$_total" -gt "$cap"; and _log "$label_tag""_TRUNCATED: total_lines=$_total head_cap=$_head_cap tail_cap=$_tail_cap"
    if test "$QUIET" = false
        for _l in $_redacted; printf '%s\n' "$_l" >&2; end
    else if test "$label_tag" = STDERR; and test $ret -ne 0
        # QUIET bypass: surface ≤5 stderr lines on rc≠0.
        for _l in $_redacted[1..5]
            printf '%s\n' "$_l" >&2
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
function _run_effective_timeout --description "_run sub: resolve timeout; bypass for long-running pkg/boot/db ops"
    set -l _t (_run_resolve_timeout)
    set -l _effective_cmd $argv[1]
    if test "$_effective_cmd" = sudo
        for _ec_arg in $argv[2..-1]
            if not string match -q -- '-*' "$_ec_arg"; set _effective_cmd $_ec_arg; break; end
        end
    end
    if contains -- "$_effective_cmd" pacman paru mkinitcpio sdboot-manage paccache updatedb pkgfile
        test -n "$_t"; and _log "TIMEOUT_BYPASS: cmd=$_effective_cmd (long-running pkg/boot/db op; SIGKILL would bypass rollback)"
        set _t ""
    end
    echo "$_t"
end
function _run --description "Execute a command with logging, stdout/stderr capture, and timeout enforcement"
    if test (count $argv) -eq 0; _log "BUG: _run called with no arguments"; return 255; end
    if string match -q -- '-*' "$argv[1]"; _log "BUG: _run called with dash-prefixed argv[1]='$argv[1]' — refusing"; return 255; end
    set -l log_cmd (_run_redact_cmd $argv)
    _log "RUN: $log_cmd"
    set -l _run_dir (command mktemp -d -p (_tmp_dir) ry-run.XXXXXX 2>/dev/null)
    _track_tmpfile "$_run_dir"
    if test -z "$_run_dir"; or not test -d "$_run_dir"
        _log "RUN_ABORT: mktemp -d failed — refusing to execute without stderr capture"
        _err "_run: cannot allocate tmpdir for stdout/stderr capture — aborting command"
        return $EXIT_RUN_TMPFAIL
    end
    set -l stderr_tmp "$_run_dir/stderr"; set -l stdout_tmp "$_run_dir/stdout"; set -l _run_timeout (_run_effective_timeout $argv)
    if test -n "$_run_timeout"
        # --kill-after=10: SIGKILL 10s after SIGTERM if hung; rc=124 (TERM) / rc=137 (KILL).
        command timeout --foreground --kill-after=10 "$_run_timeout" $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    else
        command $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    end
    set -l ret $status; set -l _cap 500
    _run_emit_stream STDERR "$stderr_tmp" $ret $_cap
    _run_emit_stream STDOUT "$stdout_tmp" $ret $_cap
    _rm_tmp "$_run_dir" false
    if test -n "$_run_timeout"
        if test "$ret" -eq 124
            _log "TIMEOUT_TERM: timeout="$_run_timeout"s cmd=$log_cmd"
        else if test "$ret" -eq 137
            _log "TIMEOUT_KILL: timeout="$_run_timeout"s cmd=$log_cmd (SIGKILL after 10s grace)"
        end
    end
    _log "EXIT: $ret cmd=$log_cmd"
    return $ret
end
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
function _chk_perms --argument-names path expected_perms expected_owner use_sudo --description "Compare file mode+owner; sgid/sticky/setuid bit stripped before compare."
    set -l _po
    if test "$use_sudo" = true
        set _po (sudo -n stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    else
        set _po (command stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    end
    if test -z "$_po"; _fail "  $path: stat failed (file disappeared or unreadable)"; return 1; end
    set -l _parts (string split ' ' -- "$_po")
    if test (count $_parts) -lt 2; _fail "  $path: stat output malformed (got: '$_po')"; return 1; end
    # stat -c %a returns 4 digits when sgid/sticky/setuid set; strip leading bit so 2600 compares equal to expected 600.
    set -l _actual_perms $_parts[1]
    if test (string length -- "$_actual_perms") -eq 4; set _actual_perms (string sub -s 2 -- "$_actual_perms"); end
    set -l _bad 0
    test "$_actual_perms" != "$expected_perms"; and set _bad 1
    test "$_parts[2]" != "$expected_owner"; and set _bad 1
    if test $_bad -eq 1; _fail "  $path: $_parts[1] $_parts[2] (expected: $expected_perms $expected_owner)"; return 1; end
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
function _cg_access_ok --argument-names file label is_boot --description "Pre-flight read access check"
    if test "$is_boot" = false
        test -r "$file"; and return 0
        if test -f "$file"
            _fail "  $label: PERMISSION DENIED (need sudo?)"
        else
            _fail "  $label: FILE NOT FOUND"
        end
        return 1
    end
    if not command -q sudo; _fail "  $label: sudo required for /boot path"; return 1; end
    if not sudo -n true 2>/dev/null; _warn "  $label: sudo cache lapsed — re-run ry-install"; return 1; end
    if not sudo -n test -f "$file" 2>/dev/null; _fail "  $label: FILE NOT FOUND"; return 1; end
    return 0
end
function _chk_grep --argument-names file pattern label --description "Verify a file contains an expected token"
    test -z "$label"; and set label "$pattern"
    _log "CHECK_GREP: $file for '$pattern'"
    set -l is_boot false
    string match -q '/boot/*' -- "$file"; and set is_boot true
    _cg_access_ok "$file" "$label" $is_boot; or return 1
    set -l _grep_flags -wF
    _as $is_boot grep -v '^[[:space:]]*#' -- "$file" 2>/dev/null | command grep $_grep_flags -- "$pattern" >/dev/null 2>/dev/null
    set -l _stage1_rc $pipestatus[1]; set -l _grep_rc $pipestatus[2]
    switch $_stage1_rc
        case 0
        case 1
            if test "$is_boot" = true; and not sudo -n true 2>/dev/null; _warn "  $label: sudo cache lapsed during read — cannot determine presence"; return 1; end
            _fail "  $label: MISSING (file has no non-comment lines)"
            return 1
        case '*'
            _warn "  $label: cannot read file (stage-1 rc=$_stage1_rc — sudo lapse or read error)"
            return 1
    end
    switch $_grep_rc
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
    # \b word boundary; assumes word-char start/end (MKINITCPIO_MODULES/HOOKS callers comply).
    set -l _re (string escape --style=regex -- "$token")
    if string match -qr "\\b$_re\\b" -- "$line"
        _ok "  $label: present"
    else
        _fail "  $label: MISSING"
    end
end
function _ry_check_deps --description "Verify required packages are installed"
    _log DEPS_CHECK_START
    set -l missing
    for cmd in pacman systemctl mkinitcpio sdboot-manage findmnt sha256sum \
        timeout mktemp awk grep curl getent sudo head df mv \
        tee stat find cp chmod chown sort install cat rm date
        command -q $cmd; or set -a missing $cmd
    end
    if test (count $missing) -gt 0; _err "missing: $missing"; return 1; end
    if not command env LC_ALL=C df --output=avail / >/dev/null 2>&1; _err "df(1) lacks --output flag — GNU coreutils required (busybox/uutils not supported)"; return 1; end
    _resolve_systemd_ver
    if test -n "$_RY_SYSTEMD_VER"; and test "$_RY_SYSTEMD_VER" -lt 250; _err "Systemd $_RY_SYSTEMD_VER < 250 — preflight gate; upgrade systemd before install"; return 1; end
    set -l _opt_missing
    for cmd in bootctl journalctl dmesg modinfo pgrep free uptime zcat tput swapon zramctl lsmod modprobe pkill nmcli ping realpath ip; command -q $cmd; or set -a _opt_missing $cmd; end
    test (count $_opt_missing) -gt 0; and _warn "Expected tools not found (from base packages): $_opt_missing"
    if test (count $AUR_PKGS) -gt 0; and not command -q paru; _warn "paru not found — AUR phase will fail (AUR_PKGS=$AUR_PKGS)"; _info "  Install paru: sudo pacman -S --needed paru"; end
    _log DEPS_CHECK_OK
    return 0
end
function _ry_check_network --description "Verify network connectivity (HTTPS primary + secondary + raw-IP fallback)"
    _log NET_CHECK_START
    set -l _idx 0
    for _host in archlinux.org cloudflare.com
        set _idx (math $_idx + 1)
        if command curl -sfI --connect-timeout 3 --max-time 5 "https://$_host" >/dev/null 2>&1
            if test $_idx -eq 1
                _ok "Network connectivity: OK"
            else
                _ok "Network connectivity: OK (fallback host)"
            end
            return 0
        end
    end
    if command ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1
        _err "Network connectivity: HTTPS or DNS unreachable (raw-IP ICMP works; check /etc/resolv.conf or 443 egress)"
    else
        _err "Network connectivity: FAILED — cannot reach archlinux.org, cloudflare.com, or 1.1.1.1"
    end
    return 1
end
function _check_avail --argument-names path divisor unit crit warn --description "Compare available bytes at path against crit/warn thresholds (in scaled units)"
    set -l _b (command env LC_ALL=C df --output=avail -B1 -- "$path" 2>/dev/null | command tail -n 1 | string trim --)
    set -l _v ""
    test -n "$_b"; and string match -qr '^\d+$' -- "$_b"; and set _v (math "floor($_b / $divisor)")
    if test -z "$_v"; or not string match -qr '^\d+$' -- "$_v"
        if test "$MODE" = install; _err "Cannot determine disk space for $path (df --output=avail returned unparseable output) — refusing to install"; return 1; end
        _warn "Could not determine disk space for $path"
        return 0
    end
    set -l _disp "$_v$unit"
    test "$_v" -eq 0; and test "$_b" -gt 0; and set _disp "<1$unit"
    if test "$_v" -lt $crit
        _err "Insufficient disk space on $path: $_disp available, need $crit$unit minimum"
        return 1
    else if test "$_v" -lt $warn
        _warn "Low disk space on $path: $_disp available"
    else
        _ok "Disk space on $path: $_disp available"
    end
    return 0
end
function _ry_check_disk_space --description "Verify sufficient free disk space for installation"
    _log DISK_CHECK_START
    _check_avail / 1073741824 GiB $ROOT_AVAIL_CRIT $ROOT_AVAIL_WARN; or return 1
    _check_avail /boot 1048576 MiB $BOOT_SPACE_CRIT $BOOT_SPACE_WARN; or return 1
    return 0
end
function _kver_below --argument-names major minor patch want_major want_minor want_patch --description "True iff (major.minor.patch) < (want_major.want_minor.want_patch). Integer args"
    test -z "$patch"; and set patch 0
    test -z "$want_patch"; and set want_patch 0
    test "$major" -lt "$want_major"; and return 0
    test "$major" -gt "$want_major"; and return 1
    test "$minor" -lt "$want_minor"; and return 0
    test "$minor" -gt "$want_minor"; and return 1
    test "$patch" -lt "$want_patch"
end
function _ry_check_kernel_version --description "Verify running kernel version meets minimum requirement"
    set -l kver $KVER; set -l major $KVER_MAJOR; set -l minor $KVER_MINOR; set -l kver_patch 0
    if set -q KVER_PARTS[3]; set -l _patch_clean (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[3]"); test -n "$_patch_clean"; and set kver_patch $_patch_clean; end
    _info "Kernel version: $kver"
    if _kver_below $major $minor $kver_patch 6 14 0
        _warn "Kernel $kver < 6.14: ntsync and gfx1151 fixes unavailable"
        _info "  Upgrade kernel before or during install (pacman -Syu)"
        return 2
    end
    set -l _warns 0
    if _kver_below $major $minor $kver_patch 6 18 4; _warn "Kernel $kver below README stability floor 6.18.4 (gfx1151)"; _info "  Recommend upgrading: sudo pacman -Syu linux-cachyos"; set _warns (math $_warns + 1); end
    set -l _ns (_ntsync_state)
    switch $_ns
        case unavailable
            _warn "Kernel $kver: ntsync not available (expected builtin or module)"
            set _warns (math $_warns + 1)
        case loaded_nodev
            _warn "Kernel $kver: ntsync module loaded but /dev/ntsync missing"
            set _warns (math $_warns + 1)
        case missing
            _warn "Kernel $kver: ntsync module not loaded (kernel ≥6.14 supports it; check MODULES list)"
            set _warns (math $_warns + 1)
        case builtin loaded
            _ok "Kernel $kver: ntsync $_ns"
        case '*'
            _warn "Kernel $kver: ntsync unknown state '$_ns'"
            set _warns (math $_warns + 1)
    end
    if test "$major" -eq 6; and test "$minor" -eq 19
        if test "$kver_patch" = 0; _warn "Kernel 6.19.0: black screen regression on Strix Halo (CachyOS #23042)"; _warn "  Recommend: downgrade to 6.18.x or upgrade to 6.19.1+"; set _warns (math $_warns + 1); end
    end
    test $_warns -gt 0; and return 1
    return 0
end
function _mkinitcpio_hook_exists --argument-names hook --description "True iff hook file exists in any mkinitcpio install/hooks dir"
    test -z "$hook"; and return 1
    for _d in /usr/lib/initcpio/install /usr/lib/initcpio/hooks /etc/initcpio/install /etc/initcpio/hooks; test -f "$_d/$hook"; and return 0; end
    return 1
end
function _vmh_existence_only --description "_ry_validate_mkinitcpio_hooks sub. Existence-only path: emit _ok/_fail per hook"
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
    test $errors -eq 0
    return $status
end
function _vmh_order_checks --description "_ry_validate_mkinitcpio_hooks sub: ordering invariants"
    set -l hooks $argv; set -l errors 0
    if test (count $hooks) -eq 0; echo 0; return 0; end
    if test "$hooks[1]" != base; _err "Mkinitcpio hook order: 'base' must be first (found: $hooks[1])"; set errors (math $errors + 1); end
    set -l _seen_hooks
    for hook in $hooks
        if contains -- "$hook" $_seen_hooks
            _err "Duplicate mkinitcpio hook: $hook"
            set errors (math $errors + 1)
        else
            set -a _seen_hooks "$hook"
        end
    end
    # Pair "BEFORE:AFTER": right hook must come after left in MKINITCPIO_HOOKS (build order).
    set -l order_checks "systemd:autodetect" "autodetect:microcode" "autodetect:modconf" "systemd:sd-vconsole" "systemd:keyboard" "keyboard:sd-vconsole" "modconf:kms" "block:filesystems"
    for check in $order_checks
        set -l _sp (string split ':' -- "$check"); set -l hook_before $_sp[1]; set -l hook_after $_sp[2]; set -l idx_a 0; set -l idx_b 0
        for i in (seq (count $hooks)); test "$hooks[$i]" = "$hook_before"; and set idx_a $i; test "$hooks[$i]" = "$hook_after"; and set idx_b $i; end
        if test $idx_a -gt 0; and test $idx_b -gt 0; and test $idx_a -ge $idx_b; _err "Mkinitcpio hook order: '$hook_before' must come before '$hook_after'"; set errors (math $errors + 1); end
    end
    # fsck must be the final hook — runs after filesystems are mounted; misplacement defeats the early-boot fsck pass.
    set -l _fsck_idx 0
    for i in (seq (count $hooks)); test "$hooks[$i]" = fsck; and set _fsck_idx $i; and break; end
    if test $_fsck_idx -gt 0; and test $_fsck_idx -ne (count $hooks); _err "Mkinitcpio hook order: 'fsck' must be last (found at position $_fsck_idx of "(count $hooks)")"; set errors (math $errors + 1); end
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
    test $errors -eq 0
    return $status
end
function _ry_validate_mkinitcpio_modules --description "Validate mkinitcpio MODULES array entries"
    not command -q modinfo; and return 0
    for mod in $MKINITCPIO_MODULES; not command modinfo "$mod" >/dev/null 2>&1; and _warn "Module may not exist: $mod (continuing anyway)"; end
    return 0
end
function _verify_unit_content --argument-names dst --description "Verify systemd unit content via tmpfile+_verify_unit_syntax"
    test (count $argv) -lt 2; and _log "BUG: _verify_unit_content called without content (dst=$dst)"; and return 2
    set -l content $argv[2..-1]
    command -q systemd-analyze; or return 0
    set -l _intended_scope system
    string match -q '*/.config/systemd/user/*' -- "$dst"; and set _intended_scope user
    set -l tmp (command mktemp --suffix=.service -p (_tmp_dir) ry-val-unit.XXXXXX 2>/dev/null)
    _track_tmpfile "$tmp"
    test -n "$tmp"; or begin
        _fail "  $dst: mktemp failed"
        return 1
    end
    command chmod -- 600 "$tmp" 2>/dev/null
    if not printf '%s\n' $content >"$tmp" 2>/dev/null; _rm_tmp "$tmp" false; _fail "  $dst: failed to write unit tmpfile for verification"; return 1; end
    _verify_unit_syntax "$tmp" (command basename -- "$dst") "$_intended_scope"
    set -l rc $status
    _rm_tmp "$tmp" false
    return $rc
end
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
    string match -qre '^[a-zA-Z._0-9-]+\s*=\s*\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no 'key = value' lines found"
        return 1
    end
    return 0
end
function _grep_ini_header --argument-names dst --description 'Validate ≥1 [Section] header present'
    test (count $argv) -lt 2; and _log "BUG: _grep_ini_header called without content (dst=$dst)"; and return 2
    string match -qre '^\[[^]]+\]$' -- $argv[2..-1]; or begin
        _fail "  $dst: no [Section] header found"
        return 1
    end
    return 0
end
function _grep_tmpfiles_entry --argument-names dst --description 'Validate ≥1 systemd-tmpfiles.d entry line'
    test (count $argv) -lt 2; and _log "BUG: _grep_tmpfiles_entry called without content (dst=$dst)"; and return 2
    # tmpfiles.d format: TypeLetter[!\-=+~^]* <ws> Path …  (man tmpfiles.d, src/tmpfiles); NOT INI.
    string match -qre '^[a-zA-Z][!\-=+~^]*[[:space:]]+\S' -- $argv[2..-1]; or begin
        _fail "  $dst: no tmpfiles.d entries found"
        return 1
    end
    return 0
end
function _rvc_dispatch --argument-names dst --description "Validate single embedded content by format family"
    set -l _content $argv[2..-1]
    switch "$dst"
        case '*.service'
            _verify_unit_content "$dst" $_content
        case '*/loader.conf' '*/sdboot-manage.conf'
            _grep_kv "$dst" $_content
        case '*/kernel/cmdline'
            _grep_kparam "$dst" $_content
        case '*/sysctl.d/*'
            _grep_sysctl_kv "$dst" $_content
        case '*/tmpfiles.d/*'
            _grep_tmpfiles_entry "$dst" $_content
        case '*/mkinitcpio.conf' '*/environment.d/*' '*/default/cpupower-service.conf'
            return 0
        case '*'
            _grep_ini_header "$dst" $_content
    end
end
function _ry_validate_configs --description "Run all embedded config validators"
    _info "Validating configuration syntax..."
    set -l errors 0
    _ry_validate_mkinitcpio_hooks; or set errors (math $errors + 1)
    _ry_validate_mkinitcpio_modules
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l fn "_content_"(_tmpfile_key "$dst")
        if not functions -q $fn; _fail "  $dst: content generator '$fn' not found"; set errors (math $errors + 1); continue; end
        set -l content ($fn)
        if test $status -ne 0; _fail "  $dst: content generator failed"; set errors (math $errors + 1); continue; end
        _rvc_dispatch "$dst" $content; or set errors (math $errors + 1)
    end
    if test $errors -gt 0; _err "Validation failed with $errors error(s)"; return $EXIT_PREFLIGHT; end
    _ok "All configurations validated"
    return 0
end
function _ry_mkinitcpio_array --argument-names key file --description "First non-comment KEY=... line from a conf file"
    test -z "$file"; and set file /etc/mkinitcpio.conf
    set -l _key_re (string escape --style=regex -- "$key")
    set -l _all_lines (command grep -E -- "^[[:space:]]*$_key_re=" "$file" 2>/dev/null)
    test (count $_all_lines) -gt 1; and _warn "  $file: multiple $key= lines found ("(count $_all_lines)") — using first"
    test (count $_all_lines) -gt 0; and printf '%s\n' "$_all_lines[1]"
end
function _ry_content_bytes --argument-names dst --description "Raw bytes of embedded content"
    set -l _content (_ry_get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines --allow-empty)
    set -l _ps $pipestatus
    test $_ps[1] -ne 0; and return $_ps[1]
    printf '%s' "$_content"
end
function _awf_render_to_tmp --argument-names dst tmpfile use_sudo --description "Pipe content generator into tee"
    _ry_get_file_content "$dst" | _as $use_sudo tee -- "$tmpfile" >/dev/null
    set -l _ps $pipestatus
    if test $_ps[1] -ne 0
        switch $_ps[1]
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
        return 1
    end
    if test $_ps[2] -eq 250; _fail "→ $dst (BUG: _as called with non-bool use_sudo='$use_sudo' in render pipe)"; return 1; end
    if test $_ps[2] -ne 0; _fail "→ $dst (write to temp failed)"; return 1; end
    return 0
end
function _awf_symlink_check --argument-names dst tmpfile use_sudo phase --description "_atomic_write_file sub: probe tmpfile for symlink"
    _is_symlink "$tmpfile" $use_sudo
    set -l _sym_rc $status
    if test $_sym_rc -eq 0
        if test "$phase" = post-write
            _fail "→ $dst (temp file replaced with symlink during write — aborting)"
        else
            _fail "→ $dst (temp file is symlink — aborting)"
        end
        return 1
    else if test $_sym_rc -eq 2
        _fail "→ $dst (sudo cache lapsed during $phase symlink check — aborting)"
        return 1
    end
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
function _atomic_write_file --argument-names dst perms use_sudo --description "Atomic file write. rc=0 ok; rc=1 any failure"
    set -l dst_dir (command dirname -- "$dst")
    set -l tmpfile (_as $use_sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
    _track_tmpfile "$tmpfile"
    if test -z "$tmpfile"; _fail "→ $dst (mktemp failed)"; return 1; end
    if not _awf_symlink_check "$dst" "$tmpfile" $use_sudo pre; _rm_tmp "$tmpfile" $use_sudo; return 1; end
    if not _awf_render_to_tmp "$dst" "$tmpfile" $use_sudo; _rm_tmp "$tmpfile" $use_sudo; return 1; end
    if not _awf_symlink_check "$dst" "$tmpfile" $use_sudo post-write; _rm_tmp "$tmpfile" $use_sudo; return 1; end
    _awf_finalize_mv "$dst" "$tmpfile" $use_sudo "$perms"
    set -l _fin_rc $status
    if test $_fin_rc -ne 0; _rm_tmp "$tmpfile" $use_sudo; return $_fin_rc; end
    _untrack_tmpfile "$tmpfile"
    _ok "→ $dst"
    return 0
end
function _ry_install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
    if _should_skip_iwd "$dst"; _warn "Skipping $dst: iwd package not installed"; return 0; end
    set -l dir (command dirname -- "$dst")
    if test "$use_sudo" = true
        if not _run sudo -n mkdir -p -m 0755 -- "$dir"; _fail "Cannot create directory: $dir"; return 1; end
    else
        set -l _prev_umask (umask)
        umask 0077
        set -l _mkdir_rc 0
        _run mkdir -p -- "$dir"; or set _mkdir_rc 1
        umask $_prev_umask
        if test $_mkdir_rc -ne 0; _fail "Cannot create directory: $dir"; return 1; end
    end
    set -l perms 0644
    test "$use_sudo" = false; and set perms 0600
    set -l _new_bytes (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
    set -l _gen_rc $pipestatus[1]
    if test $_gen_rc -eq 0
        set -l _cur_bytes (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
        set -l _read_rc $pipestatus[1]
        if test $_read_rc -eq 0; and test "$_new_bytes" = "$_cur_bytes"; set -g _RY_DEPLOY_IDEMPOTENT_COUNT (math $_RY_DEPLOY_IDEMPOTENT_COUNT + 1); _ok "→ $dst (unchanged)"; return 0; end
        test $_read_rc -eq 2; and _log "SKIP_PROBE_SUDO_LAPSED: dst=$dst — re-deploying"
    end
    _atomic_write_file "$dst" "$perms" "$use_sudo"
    set -l _aw_rc $status
    test $_aw_rc -eq 0; and set -g _RY_DEPLOY_CHANGED_COUNT (math $_RY_DEPLOY_CHANGED_COUNT + 1)
    return $_aw_rc
end
function _vsb_loader --description "_verify_static_boot sub: /boot/loader/loader.conf key/value verification"
    _echo "── loader.conf ──"
    _chk_file /boot/loader/loader.conf; or return 0
    for kv in "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"; _chk_grep /boot/loader/loader.conf "$kv"; end
end
function _vsb_sdboot --description "_verify_static_boot sub: sdboot-manage.conf LINUX_OPTIONS + key checks"
    _echo "── sdboot-manage.conf ──"
    _chk_file /etc/sdboot-manage.conf; or return 0
    set -l _opts_raw (command grep -- '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null)
    set -l _grep_rc $status
    if test $_grep_rc -ne 0; or test -z "$_opts_raw"; _fail "  /etc/sdboot-manage.conf: LINUX_OPTIONS= line missing"; return 0; end
    if test (count $_opts_raw) -gt 1; _warn "  /etc/sdboot-manage.conf: "(count $_opts_raw)" LINUX_OPTIONS= lines found (expected 1) — skipping param extraction"; return 0; end
    set -l _quote_count (string replace -ar -- '[^\x22]' '' "$_opts_raw" | string length --)
    if test "$_quote_count" -ne 2; _warn "  /etc/sdboot-manage.conf: LINUX_OPTIONS= has $_quote_count quote chars (expected 2) — skipping param extraction"; return 0; end
    set -l opts (printf '%s\n' "$_opts_raw" | string replace -r -- '^LINUX_OPTIONS=\x22([^\x22]*)\x22.*$' '$1')
    for param in $KERNEL_PARAMS; set -l _param_re (string escape --style=regex -- "$param"); string match -qr -- "(^|\s)$_param_re(\s|\$)" "$opts"; _chk_present $status "$param"; end
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
        set -l comp_opts_line (_ry_mkinitcpio_array COMPRESSION_OPTIONS)
        set -l _missing
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
        set -l _entries (sudo -n find "$_boot/loader/entries" -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null | string split0)
        set -l _ps $pipestatus
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
function _vss_ntsync_modules --description "_verify_static_system sub: ntsync state + autoload check"
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
    _echo "── Modules autoload ──"
    if test -f /usr/lib/modules-load.d/10-ntsync.conf
        _ok "  ntsync autoload: /usr/lib/modules-load.d/10-ntsync.conf present (shipped by wine-cachyos)"
    else
        _warn "  ntsync autoload: /usr/lib/modules-load.d/10-ntsync.conf missing — module may not load on boot"
    end
end
function _vss_logind --description "_verify_static_system sub: logind.conf.d keys"
    _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf; or return 0
    _resolve_systemd_ver
    for key in $LOGIND_IGNORE_KEYS
        if test "$key" = HandleSecureAttentionKey; test -z "$_RY_SYSTEMD_VER"; or test "$_RY_SYSTEMD_VER" -lt 257; and continue; end
        _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
    end
end
function _vss_iwd --argument-names skip_iwd --description "_verify_static_system sub: iwd config (skip-iwd-aware)"
    if test "$skip_iwd" = true; _info "  Skipping (iwd not installed)"; return 0; end
    _chk_file /etc/iwd/main.conf; or return 0
    _chk_grep /etc/iwd/main.conf "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
    for quirk in $IWD_DRIVER_QUIRKS; _chk_grep /etc/iwd/main.conf "$quirk" "DriverQuirks $quirk"; end
    _chk_grep /etc/iwd/main.conf "NameResolvingService=$IWD_DNS_SERVICE" "DNS via $IWD_DNS_SERVICE"
end
function _vss_nm --argument-names skip_iwd --description "_verify_static_system sub: NetworkManager config (skip-iwd-aware)"
    if test "$skip_iwd" = true; _info "  Skipping iwd-backend config (iwd not installed)"; return 0; end
    _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf; or return 0
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
end
function _vss_sysctl --description "_verify_static_system sub: sysctl drop-in key=value check"
    _echo "── sysctl drop-in ──"
    if _chk_file /etc/sysctl.d/99-cachyos-sysctl.conf
        for entry in $SYSCTL_VALUES; set -l parts (string split -m1 '=' -- "$entry"); set -l key $parts[1]; set -l val $parts[2]; _chk_grep /etc/sysctl.d/99-cachyos-sysctl.conf "$key = $val" "$key=$val"; end
    end
end
function _verify_static_system --description "Verify ntsync, modules-load, resolved, logind, iwd, NM, cpupower-service.conf, sysctl"
    set -l _skip_iwd false
    if not command -q pacman
        set _skip_iwd true
    else if not command pacman -Qi iwd >/dev/null 2>&1
        set _skip_iwd true
    end
    _echo "SYSTEM CONFIGURATION"
    _vss_ntsync_modules
    _echo "── resolved ──"
    if _chk_file /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        for kv in "MulticastDNS=$RESOLVED_MDNS" "DNSOverTLS=opportunistic" "DNSSEC=allow-downgrade" "LLMNR=no"; _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "$kv"; end
    end
    _echo "── logind.conf ──"
    _vss_logind
    _echo "── iwd ──"
    _vss_iwd $_skip_iwd
    _echo "── NetworkManager ──"
    _vss_nm $_skip_iwd
    _echo "── cpupower-service.conf ──"
    _chk_file /etc/default/cpupower-service.conf; and _chk_grep /etc/default/cpupower-service.conf "GOVERNOR='performance'" "GOVERNOR=performance"
    _vss_sysctl
end
function _verify_static_user --description "Verify environment.d ENV_VARS"
    _echo "USER CONFIGURATION"
    if _chk_file "$HOME/.config/environment.d/10-environment.conf"
        for exp in $ENV_VARS; _chk_grep "$HOME/.config/environment.d/10-environment.conf" "$exp" "$exp"; end
    end
end
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
function _vsp_aur --description "Check AUR_PKGS against installed; warn on missing"
    set -q AUR_PKGS; or return 0
    for pkg in $AUR_PKGS
        if contains -- "$pkg" $argv
            _ok "  $pkg: installed (AUR)"
        else
            _warn "  $pkg: NOT INSTALLED (AUR — install via paru)"
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
function _vsp_pacman_conf --description "Inspect IgnorePkg / ParallelDownloads in /etc/pacman.conf"
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
function _verify_static_packages --description "Verify PKGS_ADD, AUR_PKGS, PKGS_DEL, pacman.conf"
    _echo PACKAGES
    set -l _installed_pkgs
    if not command -q pacman; _warn "  pacman not found, skipping package verification"; return 0; end
    set _installed_pkgs (command pacman -Qq 2>/dev/null)
    if test $status -ne 0; _warn "  pacman -Qq failed (db locked or read error) — skipping package verification"; _log "VERIFY_PKGS_QQ_FAIL: pacman -Qq returned non-zero"; _vsp_pacman_conf; return 0; end
    _vsp_required $_installed_pkgs
    _vsp_aur $_installed_pkgs
    _vsp_removed $_installed_pkgs
    _vsp_pacman_conf
end
function _verify_static_services --description "Verify SERVICE_DESTINATIONS files + masked services state"
    _echo SERVICES
    if test (count $SERVICE_DESTINATIONS) -gt 0
        _echo "── Service files ──"
        for svc_file in $SERVICE_DESTINATIONS; _chk_file "$svc_file"; end
    end
    _echo "── Masked services ──"
    set -l _check_mask (_mask_list_effective)
    set -l _mask_parsed
    for _u in $_check_mask
        set -l _v (_unit_state $_u)
        if test (count $_v) -lt 3
            set -a _mask_parsed "::ERR_NO_DATA"
        else
            set -a _mask_parsed "$_v[1]:$_v[2]:$_v[3]"
        end
    end
    for _mask_idx in (seq 1 (count $_check_mask))
        set -l _svc $_check_mask[$_mask_idx]
        set -l _rec (string split ':' -- "$_mask_parsed[$_mask_idx]")
        if test "$_rec[3]" = ERR_NO_DATA
            _warn "  $_svc: systemctl unavailable — cannot verify mask state"
        else if test "$_rec[1]" = not-found
            _info "  $_svc: unit not found (may not be installed)"
        else if test "$_rec[3]" = masked
            _ok "  $_svc: masked"
        else
            _fail "  $_svc: load=$_rec[1] state=$_rec[2] file=$_rec[3] (expected: masked)"
        end
    end
end
function _verify_static_syntax --description "Validate mkinitcpio hooks ordering, systemd unit files"
    _echo "SYNTAX VALIDATION"
    _echo "── mkinitcpio hooks ──"
    set -l hooks_syntax_line (command grep -E -- '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | command head -n 1)
    if test -n "$hooks_syntax_line"
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_syntax_line")
        set hooks_str (string replace -ra '\s+' ' ' -- "$hooks_str" | string trim --)
        _ry_validate_mkinitcpio_hooks --existence-only (string split ' ' -- "$hooks_str")
    else
        _warn "  Could not parse HOOKS from mkinitcpio.conf"
    end
    if test (count $SERVICE_DESTINATIONS) -gt 0
        _echo "── systemd units ──"
        for unit in $SERVICE_DESTINATIONS; test -f "$unit"; and _verify_unit_syntax "$unit" (command basename -- "$unit") system; end
    end
end
function _verify_static_checksum --description "Verify embedded content hash matches installed file SHA256"
    _echo "CHECKSUM VERIFICATION"
    _echo
    _echo "── embedded vs installed ──"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l expected (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
        set -l _gen_rc $pipestatus[1]
        if test $_gen_rc -ne 0; _fail_silent "  $dst: generator failed (rc=$_gen_rc)"; set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + 1); _log "VERIFY_STATIC_GEN_FAIL: dst=$dst rc=$_gen_rc"; continue; end
        set -l actual (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
        set -l _ib_rc $pipestatus[1]
        switch $_ib_rc
            case 1
                _fail "  $dst: cannot read"
                _log "VERIFY_STATIC_READ_FAIL: dst=$dst"
                continue
            case 2
                _fail "  $dst: sudo lapse during read"
                _log "VERIFY_STATIC_SUDO_LAPSE: dst=$dst"
                continue
            case 0
            case '*'
                _fail "  $dst: unexpected read rc=$_ib_rc"
                _log "VERIFY_STATIC_READ_UNEXPECTED: dst=$dst rc=$_ib_rc"
                continue
        end
        if test "$expected" = "$actual"
            _ok "  $dst: match"
        else
            _fail "  $dst: MISMATCH"
            set -l _exp_sha (printf '%s' "$expected" | command sha256sum 2>/dev/null | string match -rg -- '^(\S+)')
            set -l _act_sha (printf '%s' "$actual" | command sha256sum 2>/dev/null | string match -rg -- '^(\S+)')
            test -z "$_exp_sha"; and set _exp_sha ERR
            test -z "$_act_sha"; and set _act_sha ERR
            _log "VERIFY_STATIC_MISMATCH: dst=$dst expected_content_sha=$_exp_sha actual_content_sha=$_act_sha expected_bytes="(string length -- "$expected")" actual_bytes="(string length -- "$actual")
        end
    end
    _echo
end
function _vs_read_symmetry_selftest --description "Preflight: detect read-symmetry regressions in _installed_bytes (asymmetric trailing newline)"
    # Idempotent: cached in _RY_READSYM_RESULT (0=ok, 1=fail).
    set -q _RY_READSYM_RESULT; and return $_RY_READSYM_RESULT
    set -l _tmp (_mktemp_or_null -p (_tmp_dir) ry-readsym.XXXXXX)
    if test -z "$_tmp"; or test "$_tmp" = /dev/null; _log "READ_SYMMETRY_SKIP: mktemp returned no path"; set -g _RY_READSYM_RESULT 0; return 0; end
    _track_tmpfile "$_tmp"
    # 12-byte probe: 2×5-char lines + 2 NL; exercises \n drop/add path.
    printf '%s\n' line1 line2 > "$_tmp"
    set -l _disk_bytes (command stat -c %s -- "$_tmp" 2>/dev/null)
    set -l _read (_installed_bytes "$_tmp" | string collect --no-trim-newlines --allow-empty)
    set -l _read_len (string length -- "$_read")
    _rm_tmp "$_tmp" false
    if test "$_disk_bytes" = 12; and test "$_read_len" = 12; _log "READ_SYMMETRY_OK: disk=12 read=12"; set -g _RY_READSYM_RESULT 0; return 0; end
    _fail "  read-symmetry self-test: disk=$_disk_bytes read=$_read_len (expected both=12) — verifier logic is broken; results UNRELIABLE"
    _log "VERIFY_LOGIC_BUG: read-symmetry self-test failed disk=$_disk_bytes read=$_read_len fish=$FISH_VERSION"
    set -g _RY_READSYM_RESULT 1
    return 1
end
function _ry_verify_static --description "Verify installed configs match embedded checksums"
    _log_section "STATIC VERIFICATION START"
    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
        return $EXIT_PREFLIGHT
    end
    set -g VERIFY_OK 0; set -g VERIFY_FAIL 0; set -g VERIFY_WARN 0; set -g VERIFY_GEN_FAIL 0
    if not _vs_read_symmetry_selftest; _log_section "STATIC VERIFICATION END"; _verify_summary; return 1; end
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
function _check_phase_files --description "--check phase: file content hash compare"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l expected (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
        set -l _gen_rc $pipestatus[1]
        if test $_gen_rc -ne 0; _log "CHECK_PREFLIGHT: generator failed for $dst (rc=$_gen_rc)"; return $EXIT_PREFLIGHT; end
        set -l actual (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
        set -l _ib_rc $pipestatus[1]
        switch $_ib_rc
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
    if test -z "$_cmdline"; _log "CHECK_PREFLIGHT: /proc/cmdline empty or unreadable"; set -g _RY_CHECK_DRIFT 1; return 0; end
    for _p in $KERNEL_PARAMS; set -l _p_re (string escape --style=regex -- "$_p"); string match -qr -- "(^|\s)$_p_re(\s|\$)" "$_cmdline"; or set -g _RY_CHECK_DRIFT 1; end
    string match -qr -- '(^|\s)rw(\s|$)' "$_cmdline"; or set -g _RY_CHECK_DRIFT 1
    return 0
end
function _cpu_chk_expected --description "Check EXPECTED_SERVICES units"
    for unit in $EXPECTED_SERVICES
        set -l _v (_unit_state_padded $unit); set -l load $_v[1]; set -l active $_v[2]; set -l ufs $_v[3]
        if test "$load" = ERR_NO_DATA
            _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"
            return $EXIT_PREFLIGHT
        else if test "$load" = not-found
            set -g _RY_CHECK_DRIFT 1
        else if string match -q '*.timer' -- "$unit"
            test "$active" = active; or set -g _RY_CHECK_DRIFT 1
            test "$ufs" = enabled; or set -g _RY_CHECK_DRIFT 1
        else
            test "$active" = active; or test "$active" = exited; or set -g _RY_CHECK_DRIFT 1
            test "$ufs" = enabled; or set -g _RY_CHECK_DRIFT 1
        end
    end
    return 0
end
function _check_phase_units --description "--check phase: EXPECTED_SERVICES + MASK + conf.d-driven units"
    set -l _implicit_svcs
    for _dst in $SYSTEM_DESTINATIONS
        switch $_dst
            case '*/systemd/resolved.conf.d/*'
                contains -- systemd-resolved.service $_implicit_svcs; or set -a _implicit_svcs systemd-resolved.service
            case '*/NetworkManager/conf.d/*'
                contains -- NetworkManager-dispatcher.service $_implicit_svcs; or set -a _implicit_svcs NetworkManager-dispatcher.service
        end
    end
    _cpu_chk_expected; or return $status
    for unit in (_mask_list_effective)
        set -l _v (_unit_state_padded $unit)
        if test "$_v[1]" = ERR_NO_DATA; _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"; return $EXIT_PREFLIGHT; end
        test "$_v[1]" = not-found; and continue
        test "$_v[3]" = masked; or set -g _RY_CHECK_DRIFT 1
    end
    for unit in $_implicit_svcs
        set -l _v (_unit_state_padded $unit)
        if test "$_v[1]" = ERR_NO_DATA; _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"; return $EXIT_PREFLIGHT; end
        test "$_v[1]" = not-found; and continue
        if test "$unit" = NetworkManager-dispatcher.service
            test "$_v[3]" = enabled; or test "$_v[3]" = static; or set -g _RY_CHECK_DRIFT 1
        else
            test "$_v[3]" = enabled; or set -g _RY_CHECK_DRIFT 1
        end
    end
    return 0
end
function _ry_do_check --description "Silent idempotency probe"
    _log_section "CHECK START"
    if not command -q sudo; or not sudo -n true 2>/dev/null; _log "CHECK_PREFLIGHT: sudo not cached"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    if not command -q systemctl; _log "CHECK_PREFLIGHT: systemctl not available"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    set -g _RY_CHECK_DRIFT 0; set -g _RY_CHECK_FILES_CHECKED 0; set -l _rc 0
    # Dynamic dispatch: phase fn name resolved at iteration; preserves per-phase rc + drift-erase semantics.
    for _phase in _check_phase_files _check_phase_cmdline _check_phase_units
        $_phase
        set _rc $status
        if test $_rc -ne 0; set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED; _log_section "CHECK END"; return $_rc; end
    end
    set -l _drift $_RY_CHECK_DRIFT; set -l _checked $_RY_CHECK_FILES_CHECKED
    set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
    if test $_drift -ne 0; _log_section "CHECK END"; return $EXIT_DRIFT; end
    if test $_checked -eq 0; _log "CHECK_PREFLIGHT: no files could be checked (all skipped by _should_skip_iwd)"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    _log_section "CHECK END"
    return $EXIT_OK
end
function _gather_cpu_state --description "Collect CPU frequency path for representative core"
    set -g _CPU_PATH ""
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq
        if test -d "$cpu_dir"; set -g _CPU_PATH "$cpu_dir"; break; end
    end
    return 0
end
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
            _warn "  $_preempt (linux-cachyos defaults to full; add preempt=full to cmdline if running a different kernel)"
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
function _vrkg_perf_level --description "_vrk_gpu_state sub: power_dpm_force_performance_level sysfs scan"
    _echo "── GPU performance level ──"
    set -l gpu_ok false; set -l found_gpu false
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
end
function _vrkg_rebar_sam --description "_vrk_gpu_state sub: ReBAR/SAM status via dmesg cache + lspci fallback"
    _echo "── ReBAR/SAM status ──"
    set -l rebar_status $_RY_DMESG_BAR
    if test -n "$rebar_status"
        if string match -qi '*enabled*' -- "$rebar_status"; or string match -qi '*resiz*' -- "$rebar_status"
            _ok "  ReBAR/SAM: enabled"
            _info "  $rebar_status"
        else
            _info "  ReBAR/SAM: check manually"
            _info "  $rebar_status"
        end
        return 0
    end
    if not command -q lspci; _info "  lspci not available for ReBAR check"; return 0; end
    # ReBAR signal: BAR >256 MB (AMD pre-ReBAR cap); match G-suffix or M-values ≥500.
    set -l bar_size (command lspci -vvv 2>/dev/null | command grep -iE 'Region.*Memory.*[0-9]+G\b|Region.*Memory.*([5-9][0-9]{2}|[0-9]{4,})M\b' | command head -n 1)
    if test -n "$bar_size"
        _ok "  ReBAR/SAM: large BAR detected"
        _info "  $bar_size"
    else
        _warn "  ReBAR/SAM: not detected (check BIOS settings)"
        _info "  Verify with: dmesg | grep -i bar"
    end
end
function _vrkg_vram --description "_vrk_gpu_state sub: BIOS VRAM carveout via mem_info_vram_total"
    _echo "── BIOS VRAM carveout ──"
    set -l _vram_bytes 0
    for f in /sys/class/drm/card*/device/mem_info_vram_total
        if test -f "$f"; set _vram_bytes (command cat -- "$f" 2>/dev/null | string trim --); break; end
    end
    if not string match -qr '^\d+$' -- "$_vram_bytes"; or test "$_vram_bytes" -le 0; _info "  VRAM carveout: cannot read mem_info_vram_total"; return 0; end
    set -l _vram_mb (math --scale=0 "$_vram_bytes / 1048576")
    if test "$_vram_mb" -le 512
        _ok "  VRAM carveout: $_vram_mb MB"
    else
        _warn "  VRAM carveout: $_vram_mb MB (recommended: ≤512 MB for UMA — check BIOS)"
        _info "    See README → Hardware → UMA Frame Buffer Size"
    end
end
function _vrk_gpu_state --description "Runtime kparam check: GPU performance level + ReBAR/SAM + VRAM carveout"
    _echo "HARDWARE STATE"
    _vrkg_perf_level
    _vrkg_rebar_sam
    _vrkg_vram
end
function _vrk_cpu_state --description "Runtime kparam check: CPU governor/EPP + amd_pstate + boost"
    _echo "── CPU performance ──"
    _gather_cpu_state
    if test -z "$_CPU_PATH"
        _warn "  No CPU frequency scaling found"
    else
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_CPU_PATH")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:amd-pstate-epp:Scaling driver" \
            "scaling_governor:performance:Governor" \
            "energy_performance_preference:performance:EPP"
            set -l parts (string split ':' -- "$check")
            set -l sysfs_val (command cat -- "$_CPU_PATH/$parts[1]" 2>/dev/null)
            _chk_eq "$parts[3]" "$sysfs_val" "$parts[2]"
        end
    end
    _echo
    _echo "── amd_pstate / CPU boost ──"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/status active "amd_pstate status"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/prefcore enabled "amd_pstate prefcore"
    _chk_sysfs_eq /sys/devices/system/cpu/cpufreq/boost 1 "CPU boost"
    _echo
end
function _vrkm_amdgpu --description "_vrk_module_state sub: amdgpu parameters (hex-aware compare)"
    test -d /sys/module/amdgpu/parameters; or return 0
    for pair in "ppfeaturemask:0xfffd3fff" "cwsr_enable:0"
        set -l _p (string split ':' -- "$pair"); set -l pname $_p[1]; set -l expected $_p[2]; set -l ppath /sys/module/amdgpu/parameters/$pname
        test -f "$ppath"; or continue
        set -l sysfs_val (string trim -- (command cat -- "$ppath" 2>/dev/null)); set -l sysfs_val_dec "$sysfs_val"; set -l expected_dec "$expected"
        # Normalize to decimal: amdgpu sysfs returns hex on some kernels, decimal on others.
        string match -qr '^0x[0-9a-fA-F]+$' -- "$sysfs_val"; and set sysfs_val_dec (printf '%d' "$sysfs_val" 2>/dev/null; or echo "$sysfs_val")
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
    for mod in $_bl_mods
        # lsmod normalizes hyphens to underscores in module names
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
    if test -f /sys/module/nvme_core/parameters/default_ps_max_latency_us
        set -l sysfs_val (command cat -- /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null)
        if test "$sysfs_val" = 0
            _fail "  nvme_core.default_ps_max_latency_us: 0 (regression — should be unset; re-check /etc/kernel/cmdline)"
        else
            _ok "  nvme_core.default_ps_max_latency_us: $sysfs_val (APST enabled)"
        end
    end
    _vrkm_amdgpu
    _echo "── Additional module parameters ──"
    _chk_sysfs_match /sys/module/zswap/parameters/enabled '^[N0]$' zswap.enabled
    _chk_sysfs_eq /proc/sys/kernel/nmi_watchdog 0 nmi_watchdog
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
            else if test (count $_RY_DMESG_CACHE) -eq 0
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
function _vrk_audio_state --description "Surface ACP ASoC machine-driver gap on Strix Halo (HDMI/USB audio unaffected)"
    test (count $_RY_DMESG_CACHE) -eq 0; and return 0
    # acp_asoc_acp70 fires once per boot on Strix Halo until linux ships a matching ASoC machine driver
    set -l _hit (printf '%s\n' $_RY_DMESG_CACHE | command grep -m1 -E 'acp_asoc_acp7[0-9]\.[0-9]+: warning: No matching ASoC machine driver found')
    test -z "$_hit"; and return 0
    _echo "── ACP audio state ──"
    _info "  ACP ASoC machine driver missing (Strix Halo) — internal analog audio via ACP not routed"
    _info "    HDMI audio (snd_hda_intel) and USB audio paths are unaffected"
    _log "ACP_NO_MACHINE_DRIVER: $_hit"
end
function _verify_runtime_kparams --description "Verify /proc/cmdline, hardware state, module params, blacklist, clocksource"
    set -g _RY_DMESG_CACHE; set -g _RY_DMESG_PREEMPT; set -g _RY_DMESG_BAR; set -g _RY_DMESG_TSC
    if command -q dmesg; and command -q sudo; and sudo -n true 2>/dev/null
        set -l _full (sudo -n dmesg 2>/dev/null | string split \n)
        set -l _full_count (count $_full)
        # Extract markers from FULL buffer first; early-boot events scroll past 5000-line head on long-uptime.
        if test (count $_full) -gt 0
            set -g _RY_DMESG_PREEMPT (printf '%s\n' $_full | command grep -o 'Dynamic Preempt: [a-z]*' | command head -n 1)
            set -g _RY_DMESG_BAR (printf '%s\n' $_full | command grep -i 'BAR' | command grep -i -E 'resize|rebar|large' | command head -n 1)
            set -g _RY_DMESG_TSC (printf '%s\n' $_full | command grep -iE 'Marking TSC unstable|TSC: Marking|clocksource.*tsc.*unstable' | command head -n 3)
        end
        # 5000-line cap bounds fish list memory; markers pre-extracted.
        set -g _RY_DMESG_CACHE $_full[1..5000]
        test "$_full_count" -gt 5000; and _log "DMESG_CAPPED: kept=5000 of $_full_count lines (markers pre-extracted from full buffer)"
    end
    if test (count $_RY_DMESG_CACHE) -eq 0
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
    _vrk_audio_state
    _vrk_clocksource
    set --erase _RY_DMESG_CACHE _RY_DMESG_PREEMPT _RY_DMESG_BAR _RY_DMESG_TSC
end
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
function _vrsv_chk_resolved --argument-names rec_str --description "Check systemd-resolved active state, only when conf.d drop-in is deployed"
    set -l rec (string split ':' -- "$rec_str")
    test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf; or return 0
    if test "$rec[2]" = active
        _ok "  systemd-resolved: active"
    else
        _fail "  systemd-resolved: $rec[2] (expected: active — DNS may be broken)"
    end
end
function _vrsv_chk_nm_dispatcher --argument-names rec_str --description "Check NM-dispatcher: enabled or static + (active|inactive) acceptable (on-demand)"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found; _warn "  NetworkManager-dispatcher: not installed"; return 0; end
    if test "$rec[3]" != enabled; and test "$rec[3]" != static; _fail "  NetworkManager-dispatcher: $rec[3] (expected: enabled or static)"; return 0; end
    if test "$rec[2]" = active; or test "$rec[2]" = inactive
        _ok "  NetworkManager-dispatcher: $rec[3] ($rec[2])"
    else
        _warn "  NetworkManager-dispatcher: $rec[2] ($rec[3] but unexpected state)"
    end
end
function _vrsv_chk_cpupower_governor --argument-names rec_str --description "Check cpupower.service (oneshot accepts 'exited'); governor applied from /etc/default/cpupower-service.conf"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found; _warn "  cpupower.service: not installed (PKGS_ADD includes cpupower; pacman db may be stale)"; return 0; end
    if test "$rec[2]" = active; or test "$rec[2]" = exited
        if test "$rec[3]" = enabled
            _ok "  cpupower.service: $rec[2] (enabled)"
        else
            _warn "  cpupower.service: $rec[2] but $rec[3] (will not persist)"
        end
        return 0
    end
    _fail "  cpupower.service: $rec[2] (expected: active or exited)"
end
function _vrsv_sys_units --description "Runtime services check: 5-unit batch"
    set -l sys_units fstrim.timer systemd-resolved.service NetworkManager-dispatcher.service NetworkManager.service cpupower.service
    set -l parsed
    for _u in $sys_units; set -l _v (_unit_state_padded $_u); set -a parsed "$_v[1]:$_v[2]:$_v[3]"; end
    _vrsv_chk_active_enabled fstrim.timer "$parsed[1]"
    _vrsv_chk_resolved "$parsed[2]"
    _vrsv_chk_nm_dispatcher "$parsed[3]"
    _vrsv_chk_active_enabled NetworkManager.service "$parsed[4]"
    _vrsv_chk_cpupower_governor "$parsed[5]"
end
function _vrsv_wifi --description "Runtime services check: WiFi + iwd + NM state"
    _echo
    _echo "WIFI STATE"
    _echo
    if test "$_PROFILE_USES_WIFI_BACKEND" = false; _info "  iwd/NetworkManager not managed — skipping WiFi state checks"; return 0; end
    set -l wlan_iface ""
    for iface in /sys/class/net/*/wireless
        if test -d "$iface"; set wlan_iface (command basename -- (command dirname -- "$iface")); break; end
    end
    if test -n "$wlan_iface"
        _ok "  WiFi interface: $wlan_iface"
    else
        _warn "  WiFi interface: NOT DETECTED"
    end
    if not command -q pgrep
        _warn "  iwd process: pgrep not installed — cannot determine"
    else if command pgrep -x iwd >/dev/null
        _ok "  iwd process: running"
    else
        _fail "  iwd process: NOT running"
    end
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
end
function _verify_runtime_services --description "Verify systemd unit states (sys batch) and WiFi runtime"
    _echo "SERVICE STATE"
    _echo
    _vrsv_sys_units
    _vrsv_wifi
    return 0
end
function _vre_envvars --description "Runtime env check: ENV_VARS via systemctl --user show-environment"
    _echo "ENVIRONMENT STATE"
    _echo
    if not _has_user_bus_active; _info "  Skipping ENV_VARS runtime check (no active user-bus — log in graphically or enable-linger to verify)"; _echo; return 0; end
    set -l _user_env (command systemctl --user show-environment 2>/dev/null)
    for exp in $ENV_VARS
        set -l _ev_parts (string split -m1 '=' -- "$exp"); set -l var_name $_ev_parts[1]; set -l expected $_ev_parts[2]; set -l actual ""
        if test -n "$_user_env"; set -l _vn_re (string escape --style=regex -- $var_name); set actual (printf '%s\n' $_user_env | string match -rg -- "^"$_vn_re"=(.*)"); set actual (string trim -c '"' -- "$actual"); end
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
        set -l _proc_path (string replace -a '.' '/' -- "$_key")
        set -l _actual (command cat -- "/proc/sys/$_proc_path" 2>/dev/null | string replace -ra '\s+' ' ' | string trim --)
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
function _vre_tcp --description "Runtime env check: TCP congestion control (bbr) + tcp_bbr module version"
    _echo "── TCP congestion control ──"
    if command -q modinfo
        set -l _bbr_ver (command modinfo tcp_bbr 2>/dev/null | command grep -i '^version:' | string replace -r -- '^version:\s*' '')
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
end
function _vre_thp_ksm --description "Runtime env check: THP enabled/defrag/shrink_underused + KSM"
    _echo "── THP / KSM / ZRAM ──"
    for _kv in 'enabled:[always]:always:CachyOS default' 'defrag:[defer+madvise]:defer+madvise:'
        set -l _parts (string split ':' -- "$_kv")
        set -l _f /sys/kernel/mm/transparent_hugepage/$_parts[1]
        test -f "$_f"; or continue
        set -l _val (command cat -- "$_f" 2>/dev/null)
        if string match -q -- "*$_parts[2]*" "$_val"
            _ok "  THP $_parts[1]: $_parts[3]"
        else
            set -l _m (string match -r '\[(\S+)\]' -- "$_val")
            set -l _active $_m[2]
            test -n "$_active"; or set _active "$_val"
            set -l _hint "recommended: $_parts[3]"
            test -n "$_parts[4]"; and set _hint "$_hint — $_parts[4]"
            _warn "  THP $_parts[1]: $_active ($_hint)"
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
end
function _vre_zram --description "Runtime env check: zram service + active swap device"
    set -l _zram_swap (command swapon --show=NAME,TYPE 2>/dev/null | command grep zram)
    set -l _zram_dev (printf '%s\n' $_zram_swap | command awk '/zram/ {n=$1; sub(".*/","",n); print n; exit}')
    test -z "$_zram_dev"; and set _zram_dev zram0
    set -l _zram_state (command systemctl is-enabled "systemd-zram-setup@$_zram_dev.service" 2>/dev/null | string trim --)
    if test "$_zram_state" = masked
        _fail "  ZRAM service: masked (expected: enabled or static+active)"
    else if test "$_zram_state" = enabled
        _ok "  ZRAM service: enabled"
    else if test "$_zram_state" = static; and test -n "$_zram_swap"
        _ok "  ZRAM service: static (template instantiated by zram-generator)"
    else if test "$_zram_state" = static
        _warn "  ZRAM service: static but no zram swap device active"
    else if test -n "$_zram_state"
        _warn "  ZRAM service: $_zram_state (expected: enabled or static+active)"
    else
        _warn "  ZRAM service: not found"
    end
    _echo "── ZRAM device ──"
    if test -n "$_zram_swap"
        set -l _zram_info (command zramctl --output NAME,ALGORITHM,DISKSIZE,TOTAL,COMP-RATIO --noheadings 2>/dev/null | command head -n 1 | string trim --)
        _ok "  ZRAM swap active: $_zram_info"
    else
        set -l _any_swap (command swapon --show=NAME,SIZE 2>/dev/null | command tail -n +2)
        if test -z "$_any_swap"
            _fail "  No swap available (ZRAM not active, no swap file/partition)"
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
        # Comma/end-boundary required: `lazytime:substr` would false-match `nolazytime`; noatime kept symmetric.
        for _tok in noatime lazytime commit=10
            set -l _re (string escape --style=regex -- "$_tok")
            if not string match -qr '(^|,)'$_re'(,|$)' -- "$_opts"; _fail "  ext4 entry missing $_tok: $_fl"; set _fstab_ok false; end
        end
    end
    test "$_fstab_ok" = true; and _ok "  ext4 entries: noatime,lazytime,commit=10 present"
end
function _vre_ntsync --description "Runtime env check: ntsync state via _ntsync_state dispatch"
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
        case '*'
            _warn "ntsync: unknown state '$_ns'"
    end
    _echo
end
function _verify_runtime_env --description "Verify ENV_VARS, sysctl, TCP, THP/KSM/ZRAM, fstab, ntsync runtime"
    _vre_envvars
    _vre_sysctl_runtime
    _vre_tcp
    _vre_thp_ksm
    _vre_zram
    _vre_fstab
    _vre_ntsync
end
function _vrs_nm_perms --description "Runtime session check: NetworkManager system-connections perms (0600 root:root)"
    set -l nm_conn_dir /etc/NetworkManager/system-connections
    if not test -d "$nm_conn_dir"; _info "  NetworkManager connections: directory not found"; return 0; end
    set -l conn_files (sudo -n find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f -print0 2>/dev/null | string split0)
    set -l _conn_ps $pipestatus
    if test "$_conn_ps[1]" -ne 0; _warn "  NetworkManager connections: cannot enumerate (sudo lapse or read error)"; return 0; end
    if test (count $conn_files) -gt 0
        set -l bad_perms 0
        for conn_file in $conn_files; _chk_perms "$conn_file" 600 root:root true; or set bad_perms (math $bad_perms + 1); end
        if test $bad_perms -eq 0; set -l conn_count (count $conn_files); _ok "  NetworkManager connections: $conn_count files with correct permissions"; end
    else if command grep -q -- 'wifi.backend=iwd' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null
        _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
    else
        _info "  NetworkManager connections: no .nmconnection files found"
    end
end
function _vrs_installed_file_perms --description "Runtime session check: installed system/service/user file perms"
    _echo "── Installed files ──"
    set -l perm_bad 0; set -l perm_checked 0; set -l perm_vfat_skipped 0; set -l _boot_resolved (_resolve_boot_path)
    test -z "$_boot_resolved"; and set _boot_resolved /boot
    set -l _boot_fstype (command findmnt -n -o FSTYPE "$_boot_resolved" 2>/dev/null | string trim --)
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo -n test -f "$dst" 2>/dev/null
            if string match -q '/boot/*' -- "$dst"; and test "$_boot_fstype" = vfat
                set perm_vfat_skipped (math $perm_vfat_skipped + 1)
                _info "  $dst: skipped (vfat — unix perms synthesized from mount options, not stored)"
                continue
            end
            set perm_checked (math $perm_checked + 1)
            _chk_perms "$dst" 644 root:root true; or set perm_bad (math $perm_bad + 1)
        end
    end
    set -l _u_uname (command id -un)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            set -l _actual_grp (command stat -c '%G' -- "$dst" 2>/dev/null)
            test -z "$_actual_grp"; and set _actual_grp (command id -gn)
            _chk_perms "$dst" 600 "$_u_uname:$_actual_grp" false; or set perm_bad (math $perm_bad + 1)
        end
    end
    if test $perm_bad -eq 0; and test $perm_checked -gt 0
        _ok "  All $perm_checked installed files: correct permissions and ownership"
    else if test $perm_checked -eq 0
        _warn "  No installed files found to check"
    end
    test $perm_vfat_skipped -gt 0; and _info "  $perm_vfat_skipped file(s) skipped on vfat boot partition (unix perms synthesized from mount options)"
end
function _vrs_parent_dirs --description "Runtime session check: parent dirs of managed files"
    _echo "── Parent directories ──"
    set -l dir_bad 0; set -l dir_checked 0; set -l checked_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (command dirname -- "$dst")
        contains -- "$dir" $checked_dirs; and continue
        set -a checked_dirs "$dir"
        if sudo -n test -d "$dir" 2>/dev/null
            set dir_checked (math $dir_checked + 1)
            set -l _po (sudo -n stat -c '%a %U:%G' -- "$dir" 2>/dev/null)
            if test -z "$_po"; _fail "  $dir: stat failed"; set dir_bad (math $dir_bad + 1); continue; end
            set -l _po_parts (string split ' ' -- "$_po"); set -l perms $_po_parts[1]; set -l owner $_po_parts[2]
            if test "$owner" != "root:root"
                _fail "  $dir: $perms $owner (expected: root:root)"
                set dir_bad (math $dir_bad + 1)
            else if _dir_group_or_world_writable "$perms"
                _fail "  $dir: $perms (writable by non-root)"
                set dir_bad (math $dir_bad + 1)
            end
        end
    end
    if test $dir_bad -eq 0; and test $dir_checked -gt 0
        _ok "  All $dir_checked parent directories: correct ownership, not world/group-writable"
    else if test $dir_checked -eq 0
        _warn "  No parent directories found to check"
    end
end
function _vrs_vulkan --description "Runtime session check: Vulkan driver packages (DXVK/VKD3D-Proton dependency)"
    _echo
    _echo "PACKAGE MANAGEMENT"
    _echo
    _echo "── Vulkan driver packages ──"
    if not set -q EXPECTED_VULKAN_PKGS; or test (count $EXPECTED_VULKAN_PKGS) -eq 0; _info "  EXPECTED_VULKAN_PKGS not defined — skipping"; return 0; end
    set -l _vk_installed
    command -q pacman; and set _vk_installed (command pacman -Qq 2>/dev/null)
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
function _vrs_boot_perf --description "Runtime session check: systemd-analyze boot time + slowest services"
    _echo
    _echo "BOOT PERFORMANCE"
    _echo
    if not command -q systemd-analyze; _warn "  systemd-analyze not available"; return 0; end
    set -l boot_time (command systemd-analyze 2>/dev/null | command head -n 1)
    _info "  $boot_time"
    _log "BOOT_TIME_CHECK: parsing systemd-analyze output"
    if not string match -qr -- '= [0-9.]+s\b' "$boot_time"
        _info "  systemd-analyze output format unrecognized — skipping target compare"
    else
        set -l _tm (string match -rg -- '= ([0-9.]+)s(?:\s|$)' "$boot_time")
        set -l total_sec ""
        test (count $_tm) -gt 0; and set total_sec $_tm[-1]
        if test -n "$total_sec"; and string match -qr '^\d+(\.\d+)?$' -- "$total_sec"
            if set -q BOOT_TIME_TARGET; and test -n "$BOOT_TIME_TARGET"
                set -l target $BOOT_TIME_TARGET
                set -l time_int (math "round($total_sec)" 2>/dev/null)
                if test -n "$time_int"; and test "$time_int" -le $target
                    _ok "  Boot time within "$target"s target"
                else if test -n "$time_int"
                    _info "  Boot time exceeds "$target"s target (ignored)"
                    _info "  Run 'systemd-analyze blame' to identify slow services"
                end
            else
                _info "  BOOT_TIME_TARGET not set — skipping target comparison"
            end
        end
    end
    _echo "  Slowest services:"
    set -l blame (command systemd-analyze blame 2>/dev/null | command head -n 3)
    for line in $blame; _info "    $line"; end
end
function _verify_runtime_session --description "Verify file perms, parent dirs, Vulkan packages, boot performance"
    _echo "FILE PERMISSIONS"
    _echo "── Sensitive files ──"
    _vrs_nm_perms
    _vrs_installed_file_perms
    _vrs_parent_dirs
    _vrs_vulkan
    _vrs_boot_perf
end
function _ry_verify_runtime --description "Verify runtime kernel params, services, and modules"
    _log_section "RUNTIME VERIFICATION START"
    _ensure_sudo_cached; or begin
        _err "Sudo required for verification"
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
function _dir_group_or_world_writable --argument-names mode --description "True when octal mode has group or world write bit"
    test (string length -- "$mode") -gt 3; and set mode (string sub -s 2 -- "$mode")
    not string match -qr '^[0-7]+$' -- "$mode"; and return 1
    # Reject modes <3 chars post-strip; stat -c %a guarantees ≥3 digits (defence-in-depth).
    test (string length -- "$mode") -eq 3; or return 1
    set -l group_w (string sub -s 2 -l 1 -- "$mode")
    set -l other_w (string sub -s 3 -l 1 -- "$mode")
    set -l group_has_w (math "floor($group_w / 2) % 2")
    set -l other_has_w (math "floor($other_w / 2) % 2")
    test "$group_has_w" -eq 1; and return 0
    test "$other_has_w" -eq 1; and return 0
    return 1
end
function _is_wifi_active_route --description "True if default route exits via wireless interface"
    set -l _def_iface ""
    for _af in -4 -6; set _def_iface (command ip $_af route show default 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}'); test -n "$_def_iface"; and break; end
    test -z "$_def_iface"; and return 1
    test -d "/sys/class/net/$_def_iface/wireless"; and return 0
    switch "$_def_iface"
        case 'tun*' 'tap*' 'wg*' 'ppp*' 'gre*' 'gretap*' 'sit*' 'ip6tnl*' 'ipip*' 'br[0-9]*' 'br-*' 'bridge*' 'macvlan*' 'macvtap*' 'vlan*' 'bond*' 'geneve*' 'vxlan*' 'nlmon*'
            for _phy in /sys/class/net/*/wireless
                test -d "$_phy"; or continue
                set -l _name (command basename -- (command dirname -- "$_phy"))
                set -l _state (command cat -- "/sys/class/net/$_name/operstate" 2>/dev/null | string trim --)
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
        "[WARN] Sudo cache may lapse during 3-8 min install. Mitigations:" \
        "[WARN]   Defaults timestamp_timeout=60 in /etc/sudoers, sudo -v keepalive in parallel shell," \
        "[WARN]   or NOPASSWD: ALL drop-in. Recovery: re-run ry-install (idempotent)." \
        "" >&2
end
function _ry_check_wireless_regdom --description "Warn if WIRELESS_REGDOM unset or invalid — set-wireless-regdom skips iw reg set otherwise, leaving cfg80211 in world domain"
    # cfg80211 udev rule pipes /etc/conf.d/wireless-regdom through set-wireless-regdom on boot.
    set -l _conf /etc/conf.d/wireless-regdom
    if not test -f "$_conf"
        _warn "  Wireless regulatory domain unset (no $_conf) — cfg80211 will use restrictive defaults"
        _info "    Fix: echo 'WIRELESS_REGDOM=\"<CC>\"' | sudo tee $_conf  (e.g., US, GB, DE)"
        _log "REGDOM_MISSING: $_conf absent"
        return 0
    end
    if not command grep -qE '^[[:space:]]*WIRELESS_REGDOM="?[A-Z]{2}"?[[:space:]]*$' "$_conf" 2>/dev/null
        _warn "  $_conf present but WIRELESS_REGDOM not set to a valid 2-letter ISO 3166-1 code — set-wireless-regdom will skip iw reg set"
        _info "    Fix: echo 'WIRELESS_REGDOM=\"<CC>\"' | sudo tee $_conf"
        _info "    Or set RY_INSTALL_WIRELESS_REGDOM=<CC> on the next install run (e.g. US, GB, DE) — see README → Runtime variables"
        _log "REGDOM_INVALID: $_conf missing or empty WIRELESS_REGDOM value"
        return 0
    end
    return 0
end
function _ry_apply_wireless_regdom --description "Apply RY_INSTALL_WIRELESS_REGDOM env var to /etc/conf.d/wireless-regdom (opt-in)"
    set -q RY_INSTALL_WIRELESS_REGDOM; or return 0
    test -n "$RY_INSTALL_WIRELESS_REGDOM"; or return 0
    set -l _cc (string trim -- "$RY_INSTALL_WIRELESS_REGDOM" | string upper --)
    if not string match -qr -- '^[A-Z]{2}$' "$_cc"
        _err "RY_INSTALL_WIRELESS_REGDOM='$RY_INSTALL_WIRELESS_REGDOM' invalid — must be a 2-letter ISO 3166-1 code (e.g. US, GB, DE)"
        _log "REGDOM_ENV_INVALID: value=$RY_INSTALL_WIRELESS_REGDOM"
        return $EXIT_USAGE
    end
    set -l _conf /etc/conf.d/wireless-regdom
    if test -f "$_conf"; and command grep -qE '^[[:space:]]*WIRELESS_REGDOM="?'$_cc'"?[[:space:]]*$' "$_conf" 2>/dev/null
        _ok "  WIRELESS_REGDOM=$_cc (already present in $_conf)"
        _log "REGDOM_SET_NOOP: cc=$_cc file=$_conf"
        return 0
    end
    set -l _payload 'WIRELESS_REGDOM="'$_cc'"'
    set -l _err_tmp (_mktemp_or_null -p (_tmp_dir) ry-regdom-err.XXXXXX)
    _track_tmpfile "$_err_tmp"
    _log "RUN: sudo -n tee -- $_conf (stdin: WIRELESS_REGDOM=$_cc)"
    if printf '%s\n' "$_payload" | sudo -n tee -- "$_conf" >/dev/null 2>"$_err_tmp"
        # tee inherits root umask; explicit chmod 0644 normalizes (matches /etc/conf.d/* convention).
        sudo -n chmod 0644 -- "$_conf" 2>/dev/null
        _ok "  WIRELESS_REGDOM=$_cc → $_conf"
        _log "REGDOM_SET: cc=$_cc file=$_conf"
        _rm_tmp "$_err_tmp" false
        return 0
    end
    set -l _err_msg ""
    test "$_err_tmp" != /dev/null; and test -s "$_err_tmp"; and set _err_msg " err="(command head -n 1 -- "$_err_tmp" | string trim --)
    _rm_tmp "$_err_tmp" false
    _warn "  RY_INSTALL_WIRELESS_REGDOM: failed to write $_conf"
    _log "REGDOM_SET_FAIL: cc=$_cc file=$_conf$_err_msg"
    return 1
end
function _ip_bail_prep --description "_install_preflight bail prep: clear LOUD_ERR, mark progress skip"
    set --erase _RY_LOUD_ERR
    set -g _PROG_FINALIZED_SKIP true
end
function _ip_record_regdom --argument-names _ar_rc --description "_install_preflight sub. Record wireless-regdom phase result"
    if set -q RY_INSTALL_WIRELESS_REGDOM; and test -n "$RY_INSTALL_WIRELESS_REGDOM"
        if test $_ar_rc -eq 0
            _phase_record "Preflight: wireless regdom" PASS "WIRELESS_REGDOM=$RY_INSTALL_WIRELESS_REGDOM"
        else
            _phase_record "Preflight: wireless regdom" WARN "apply failed (see JSONL)"
        end
    else
        _phase_record "Preflight: wireless regdom" "--" "RY_INSTALL_WIRELESS_REGDOM unset"
    end
end
function _install_preflight --description "Run all preflight checks before installation"
    _progress Preflight
    _ry_sudo_cache_banner
    # Force preflight errors to stderr in QUIET install; cleared on success/bail.
    set -g _RY_LOUD_ERR true; set -l _chk_labels "Preflight: sudo credential cache" "Preflight: dependency check" "Preflight: disk space"; set -l _i 1
    for _chk in _ensure_sudo_cached _ry_check_deps _ry_check_disk_space
        if $_chk; _phase_record $_chk_labels[$_i] PASS "ok"; set _i (math $_i + 1); continue; end
        _phase_record $_chk_labels[$_i] FAIL "see JSONL log"
        _ip_bail_prep
        return $EXIT_PREFLIGHT
    end
    if not _ry_check_network
        _phase_record "Preflight: network reachability" FAIL "archlinux.org, cloudflare.com, 1.1.1.1 unreachable"
        _err "Network required for package installation — aborting"
        _ip_bail_prep
        return $EXIT_PREFLIGHT
    end
    _phase_record "Preflight: network reachability" PASS "ok"
    _ry_check_kernel_version
    set -l _kv_rc $status
    switch $_kv_rc
        case 0
            _phase_record "Preflight: kernel version" PASS "$KVER"
        case 1
            _phase_record "Preflight: kernel version" WARN "$KVER (below recommended)"
        case '*'
            _phase_record "Preflight: kernel version" FAIL "$KVER (below required)"
            set -g INSTALL_HAD_ERRORS true
    end
    _ry_apply_wireless_regdom
    set -l _ar_rc $status
    if test $_ar_rc -eq $EXIT_USAGE; _phase_record "Preflight: wireless regdom" FAIL "invalid RY_INSTALL_WIRELESS_REGDOM"; _ip_bail_prep; return $EXIT_USAGE; end
    _ip_record_regdom $_ar_rc
    _ry_check_wireless_regdom
    _echo
    if not _ry_validate_configs; _phase_record "Preflight: config validation" FAIL "see JSONL log"; _err "Configuration validation failed - aborting"; _ip_bail_prep; return $EXIT_PREFLIGHT; end
    _phase_record "Preflight: config validation" PASS "$_RY_MANAGED_FILE_COUNT/$_RY_MANAGED_FILE_COUNT destinations"
    set --erase _RY_LOUD_ERR
end
function _mr_copy_size_verify --argument-names backup_file _mki_tmp --description "_mkinitcpio_revert sub: cp + byte-exact size + content verify"
    if not sudo -n cp -- "$backup_file" "$_mki_tmp" 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at copy — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: cp $backup_file failed"
        return 1
    end
    set -l _src_size (sudo -n stat -c '%s' -- "$backup_file" 2>/dev/null)
    set -l _dst_size (sudo -n stat -c '%s' -- "$_mki_tmp" 2>/dev/null)
    if test -z "$_src_size"; or test -z "$_dst_size"; or not string match -qr '^[0-9]+$' -- "$_src_size"; or not string match -qr '^[0-9]+$' -- "$_dst_size"; or test "$_src_size" != "$_dst_size"
        _err "  /etc/mkinitcpio.conf revert failed at size verify (src=$_src_size dst=$_dst_size) — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: cp size mismatch src=$_src_size dst=$_dst_size"
        return 1
    end
    # Defence-in-depth: cmp confirms byte-content (size-equal alone insufficient).
    if command -q cmp; and not sudo -n cmp -s -- "$backup_file" "$_mki_tmp" 2>/dev/null
        _err "  /etc/mkinitcpio.conf revert failed at cmp — same-size content drift between backup and tmp"
        _log "MKINITCPIO_REVERT_FAIL: cmp content mismatch (size=$_src_size)"
        return 1
    end
    return 0
end
function _mr_chmod_chown_mv --argument-names _mki_tmp --description "_mkinitcpio_revert sub. chmod/chown --reference + atomic mv"
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
    set -l _mki_tmp (sudo -n mktemp -p /etc .ry-install.mki.XXXXXX 2>/dev/null)
    _track_tmpfile "$_mki_tmp"
    if test -z "$_mki_tmp"; _err "  /etc/mkinitcpio.conf revert failed at mktemp — current conf may reference uninstalled modules"; _log "MKINITCPIO_REVERT_FAIL: mktemp failed"; return 1; end
    if sudo -n test -L "$_mki_tmp" 2>/dev/null
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at symlink check — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: tmp is symlink"
        return 1
    end
    if not _mr_copy_size_verify "$backup_file" "$_mki_tmp"; _rm_tmp "$_mki_tmp" true; return 1; end
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
    set -l _snap (sudo -n mktemp -p /etc .ry-install.mki-snap.XXXXXX 2>/dev/null)
    if test -z "$_snap"; _warn "  mkinitcpio.conf snapshot skipped: mktemp failed (rollback will be unavailable)"; _log "MKINITCPIO_BACKUP_FAIL: mktemp"; return 0; end
    _track_tmpfile "$_snap"
    if not sudo -n cp -- /etc/mkinitcpio.conf "$_snap" 2>/dev/null
        _rm_tmp "$_snap" true
        _warn "  mkinitcpio.conf snapshot skipped: cp failed (rollback will be unavailable)"
        _log "MKINITCPIO_BACKUP_FAIL: cp"
        return 0
    end
    # Snapshot mode moot: revert chmods --reference=destination.
    set -g _RY_MKI_BACKUP_FILE "$_snap"; set -g _RY_MKI_HAD_ORIG true
end
function _ip_pacman_invoke --description "Run pacman -Syu (or -Sy via RY_INSTALL_ALLOW_PARTIAL_UPGRADE)"
    set -l _pacman_first; set -l _pacman_retry; set -l _do_upgrade true
    if test "$RY_INSTALL_ALLOW_PARTIAL_UPGRADE" = 1
        set _pacman_first -Sy --needed --noconfirm
        set _pacman_retry -Syy --needed --noconfirm
        set _do_upgrade false
        _warn "Partial-upgrade mode (RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1) — violates Arch's no-partial-upgrade policy"
        _info "  Refresh DB + install listed pkgs only; dependency-version skew may break shared-library ABI"
        _info "  Retry (on failure) uses -Syy without -u — already-installed packages are NOT upgraded, only re-fetched on db mismatch"
        _log "PARTIAL_UPGRADE_MODE: RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1"
    else
        set _pacman_first -Syu --needed --noconfirm
        set _pacman_retry -Syyu --needed --noconfirm
        _info "System upgrade proceeding unattended — review archlinux.org/news and wiki.cachyos.org post-install"
    end
    if test -f /var/lib/pacman/db.lck
        _err "Pacman database is locked (/var/lib/pacman/db.lck) — another pacman may be running, or stale lock from a crashed run"
        _err "  Skipping package install — remove the lock file manually if no pacman process is active"
        return 1
    end
    if not _run sudo -n pacman $_pacman_first -- $argv
        _warn "Package installation failed — retrying with forced db re-sync (handles transient mirror staleness; will not resolve pkg conflicts — see JSONL log for first-pass stderr)..."
        if not _run sudo -n pacman $_pacman_retry -- $argv
            if test -f /var/lib/pacman/db.lck
                _err "Pacman database became locked during install — aborting"
            else
                _err "Package installation failed after retry"
            end
            if test "$_RY_MKI_HAD_ORIG" = true; and test -n "$_RY_MKI_BACKUP_FILE"
                set -g _RY_PACMAN_REVERT_ATTEMPTED true
                if not _mkinitcpio_revert "$_RY_MKI_BACKUP_FILE"; set -g _RY_MKI_REVERT_FAILED true; _err "Mkinitcpio revert failed — boot state may be inconsistent; aborting"; end
            end
            return 1
        end
    end
    test "$_do_upgrade" = true; and set -g SYSTEM_UPGRADED true
    return 0
end
function _ip_scan_pacnew --description "Scan managed destinations for .pacnew/.pacsave remnants"
    set -l _pacnew_handled; set -l _pacnew_failed; set -l _pacsave_found
    for _dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo -n test -f "$_dst.pacnew" 2>/dev/null
            if _ry_install_file "$_dst" true
                if _run sudo -n rm -f -- "$_dst.pacnew"
                    set -a _pacnew_handled "$_dst.pacnew"
                    _log "PACNEW_AUTO_HANDLED: $_dst.pacnew (managed content re-deployed)"
                else
                    set -a _pacnew_failed "$_dst.pacnew"
                    _log "PACNEW_AUTO_HANDLE_RM_FAIL: $_dst.pacnew"
                end
            else
                set -a _pacnew_failed "$_dst.pacnew"
                _log "PACNEW_AUTO_HANDLE_DEPLOY_FAIL: $_dst"
            end
        end
        sudo -n test -f "$_dst.pacsave" 2>/dev/null; and set -a _pacsave_found "$_dst.pacsave"
    end
    if test (count $_pacnew_handled) -gt 0
        _info "Resolved pacman config remnants at managed destinations:"
        for _f in $_pacnew_handled; _info "  $_f (re-deployed managed content, removed)"; end
    end
    if test (count $_pacnew_failed) -gt 0
        _warn "Pacman config remnants could not be auto-resolved:"
        for _f in $_pacnew_failed; _warn "  $_f"; end
        _warn "  Review with: sudo pacdiff (then re-run install to redeploy managed configs)"
    end
    if test (count $_pacsave_found) -gt 0
        _warn "Pacman .pacsave files at managed destinations (package removed but config preserved):"
        for _f in $_pacsave_found; _warn "  $_f"; end
        _warn "  Review with: sudo pacdiff"
        _log "PACSAVE_FOUND: $_pacsave_found"
    end
end
function _ip_run_and_verify --description "_install_packages sub: run pacman -Syu + verify + revalidate hooks"
    set -l pkgs_to_install $argv; set -l _err false
    if not _ip_pacman_invoke $pkgs_to_install; set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true; set _err true; end
    _info "Verifying package installation..."
    set -l missing_pkgs (command pacman -T -- $pkgs_to_install 2>/dev/null)
    set -l _pt_rc $status
    # pacman -T: 0=all installed, 127=some missing (non-fatal, names on stdout), other=fatal.
    if test $_pt_rc -ne 0; and test $_pt_rc -ne 127
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
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        _phase_record "Packages: pacman -Syu" FAIL "mkinitcpio.conf pre-deploy failed"
        return 1
    end
    if test (count $pkgs_to_install) -gt 0; _ip_run_and_verify $pkgs_to_install; or set _fn_err true; end
    _ip_scan_pacnew
    set -q _RY_MKI_BACKUP_FILE; and test -n "$_RY_MKI_BACKUP_FILE"; and _rm_tmp "$_RY_MKI_BACKUP_FILE" true
    set --erase _RY_MKI_BACKUP_FILE _RY_MKI_HAD_ORIG
    if test "$_fn_err" = true; _phase_record "Packages: pacman -Syu" FAIL "see JSONL log"; return 1; end
    if test "$SYSTEM_UPGRADED" = true
        _phase_record "Packages: pacman -Syu" PASS "system upgraded"
    else
        _phase_record "Packages: pacman -Syu" PASS "partial-upgrade mode (RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1)"
    end
    return 0
end
function _iap_per_pkg_retry --description "_install_aur_packages sub. Re-attempt AUR install one package at a time; returns failed count via _RY_IAP_RETRY_FAILED"
    set -g _RY_IAP_RETRY_FAILED 0
    for pkg in $AUR_PKGS
        if not _run paru -S --needed --noconfirm --skipreview --cleanafter -- "$pkg"; _warn "AUR install failed: $pkg"; set -g INSTALL_HAD_ERRORS true; set -g _RY_IAP_RETRY_FAILED (math $_RY_IAP_RETRY_FAILED + 1); end
    end
    # Partial = some-but-not-all failed; total per-pkg failure is full failure.
    test $_RY_IAP_RETRY_FAILED -gt 0; and test $_RY_IAP_RETRY_FAILED -lt (count $AUR_PKGS); and set -g _RY_AUR_PARTIAL true
end
function _iap_record_result --description "_install_aur_packages sub. Record final phase result for the run-summary matrix"
    set -l _total (count $AUR_PKGS)
    if contains -- mt76-mt7925-dkms $AUR_PKGS
        if command -q modinfo; and command modinfo mt7925e >/dev/null 2>&1
            _phase_record "Packages: AUR (paru)" PASS "$_total/$_total (mt7925e module verified)"
        else
            set -g INSTALL_HAD_ERRORS true
            _phase_record "Packages: AUR (paru)" WARN "$_total/$_total (mt76-mt7925-dkms installed but mt7925e module unbuilt — see JSONL)"
        end
    else
        _phase_record "Packages: AUR (paru)" PASS "$_total/$_total"
    end
end
function _install_aur_packages --description "Install AUR packages via paru (no --removemake for DKMS)"
    if test (count $AUR_PKGS) -le 0; _phase_record "Packages: AUR (paru)" "--" "AUR_PKGS empty"; return 0; end
    if not command -q paru
        _err "paru not found — cannot install AUR packages: $AUR_PKGS"
        _err "  Install paru: sudo pacman -S --needed paru"
        _err "  AUR_PKGS may include WiFi DKMS (mt76-mt7925-dkms) — runtime, not boot-critical"
        set -g INSTALL_HAD_ERRORS true
        _phase_record "Packages: AUR (paru)" FAIL "paru not installed"
        return 1
    end
    set -l _had_fail false; set -l _retry_failed 0; set -g _RY_AUR_PARTIAL false
    _log "AUR_NOISE_NOTE: paru/makepkg stderr/stdout may contain benign tokens; authoritative success signal is MT7925_VERIFY_OK from _aur_verify_mt7925"
    set -l _aur_noise_tokens \
        "'WARNING: Using existing \$srcdir/ tree' (cache reuse)" \
        "'error: command failed to execute correctly' (retried sub-step)" \
        "'BUILD_EXCLUSIVE directives ... do not match this kernel' (DKMS rejects alt kernel; mainline ships mt7925e in-tree)"
    _log "AUR_NOISE_NOTE_TOKENS: "(string join -- ' | ' $_aur_noise_tokens)
    if not _run paru -S --needed --noconfirm --skipreview --cleanafter -- $AUR_PKGS
        if test (count $AUR_PKGS) -le 1
            _warn "AUR install failed: $AUR_PKGS"
            set -g INSTALL_HAD_ERRORS true
            set _had_fail true
            set _retry_failed 1
        else
            _warn "AUR batch install failed — retrying per-package to identify failures"
            _iap_per_pkg_retry
            set _had_fail true
            set _retry_failed $_RY_IAP_RETRY_FAILED
        end
    end
    if test "$_had_fail" = true
        _info "  Common cause: AUR maintainer PGP key not in keyring (suppressed by --skipreview)."
        _info "  Inspect the stderr event in the JSONL log; if it mentions 'invalid or corrupted package (PGP signature)',"
        _info "  pre-import the maintainer key: gpg --recv-keys <KEYID>, then re-run install."
        _info "  Alternatively, install the affected package manually: paru -S <pkg> (without --skipreview)."
        set -l _total (count $AUR_PKGS)
        if test "$_RY_AUR_PARTIAL" = true
            set -l _ok_count (math $_total - $_retry_failed)
            _phase_record "Packages: AUR (paru)" WARN "$_ok_count/$_total (partial — see JSONL)"
        else
            _phase_record "Packages: AUR (paru)" FAIL "0/$_total (all failed)"
        end
        return 1
    end
    _aur_verify_mt7925
    _iap_record_result
    return 0
end
function _aur_verify_mt7925 --description "Post-AUR check: mt76-mt7925-dkms pkg installed AND mt7925e module built (paru rc=0 alone is not definitive)"
    contains -- mt76-mt7925-dkms $AUR_PKGS; or return 0
    if not command -q pacman; _log "MT7925_VERIFY_SKIP: pacman not found"; return 0; end
    if not command pacman -Qi mt76-mt7925-dkms >/dev/null 2>&1
        _warn "  mt76-mt7925-dkms: paru reported success but pacman -Qi cannot find the package — DKMS build likely failed"
        _warn "  Inspect: paru -S mt76-mt7925-dkms (no --skipreview), then dkms status"
        _log "MT7925_VERIFY_PKG_MISSING: pacman -Qi mt76-mt7925-dkms returned non-zero"
        return 0
    end
    if not command -q modinfo; _log "MT7925_VERIFY_SKIP: modinfo not found"; return 0; end
    # pacman -Qi confirms db entry; modinfo confirms DKMS build produced loadable .ko (distinct failure modes).
    if command modinfo mt7925e >/dev/null 2>&1
        _ok "  mt76-mt7925-dkms verified (mt7925e modinfo found)"
        _log "MT7925_VERIFY_OK: pkg installed and mt7925e module discoverable"
    else
        set -l _mt_ver (command pacman -Q mt76-mt7925-dkms 2>/dev/null | command awk '{print $2}')
        _warn "  mt76-mt7925-dkms installed but mt7925e module not found — DKMS build silently failed"
        _warn "  Inspect: dkms status mt76-mt7925; sudo dkms install mt76-mt7925/$_mt_ver"
        _log "MT7925_VERIFY_MODULE_MISSING: pkg installed but modinfo mt7925e failed"
    end
    return 0
end
function _isf_deploy_set --argument-names use_sudo phase --description "Deploy all destinations from argv[3..]"
    set -l _had_failure false
    for dst in $argv[3..]
        if not _ry_install_file "$dst" $use_sudo; set _had_failure true; contains -- "$dst" $_RY_BOOT_CRITICAL_DSTS; and set -g _RY_BOOT_TAINTED true; end
    end
    if test "$_had_failure" = true; _err "$phase file installation failed"; return 1; end
    return 0
end
function _install_system_files --description "Deploy all embedded config + service unit files"
    set -l _fn_err false
    _progress Configuration
    _info "Installing system configuration files..."
    _log "=== INSTALL SYSTEM FILES ==="
    if not _isf_deploy_set true System $SYSTEM_DESTINATIONS; set -g INSTALL_HAD_ERRORS true; set _fn_err true; end
    if test (count $SERVICE_DESTINATIONS) -gt 0
        _info "Installing service unit files..."
        _log "=== INSTALL SERVICE FILES ==="
        set -g _RY_DEPLOYED_SERVICES; set -l _svc_failed false
        for dst in $SERVICE_DESTINATIONS
            if _ry_install_file "$dst" true
                set -a _RY_DEPLOYED_SERVICES (command basename -- "$dst")
            else
                set _svc_failed true
            end
        end
        if test "$_svc_failed" = true; _err "Service unit file installation failed"; set -g INSTALL_HAD_ERRORS true; set _fn_err true; end
    end
    _info "Installing user configuration files..."
    _log "=== INSTALL USER FILES ==="
    if not _isf_deploy_set false User $USER_DESTINATIONS; set -g INSTALL_HAD_ERRORS true; set _fn_err true; end
    test "$_fn_err" = true; and return 1
    return 0
end
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
            set -l _existing_commit (string match -rg -- '(?:^|,)commit=([0-9]+)(?:,|$)' -- "$opts_field")
            test -n "$_existing_commit"; and test "$_existing_commit" != 10; and set -ga _RY_FSTAB_COMMIT_OVERRIDES "$_existing_commit"
        end
    end
end
function _far_build_awk_script --description "_far_awk_rewrite sub. Emit awk script for ext4 mount-opt rewrite"
    # Idempotent: comments / non-ext4 / digits-only $4 / conformant ext4 pass through; only non-conformant rewritten.
    string join -- \n \
        'BEGIN { OFS = " " }' \
        '/^[ \t]*#/ || NF < 4 { print; next }' \
        '$3 != "ext4" { print; next }' \
        '$4 ~ /^[0-9]+$/ { print; next }' \
        '$4 ~ /(^|,)noatime(,|$)/ && $4 ~ /(^|,)lazytime(,|$)/ && $4 ~ /(^|,)commit=10(,|$)/ { print; next }' \
        '{' \
        '    n = split($4, opts, ",")' \
        '    has_noat = 0; has_lazy = 0; out = ""' \
        '    for (i = 1; i <= n; i++) {' \
        '        o = opts[i]' \
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
        '    $4 = out' \
        '    print' \
        '}'
end
function _far_awk_rewrite --argument-names tmpfstab --description "awk-rewrite fstab into tmpfstab via tee"
    set -l _awk_script (_far_build_awk_script | string collect)
    set -l _tee_err (_mktemp_or_null -p (_tmp_dir) ry-fstab-tee-err.XXXXXX)
    set -l _awk_err (_mktemp_or_null -p (_tmp_dir) ry-fstab-awk-err.XXXXXX)
    _track_tmpfile "$_tee_err"
    _track_tmpfile "$_awk_err"
    if test -r /etc/fstab
        command awk "$_awk_script" /etc/fstab 2>"$_awk_err" | sudo -n tee -- "$tmpfstab" >/dev/null 2>"$_tee_err"
    else
        sudo -n awk "$_awk_script" /etc/fstab 2>"$_awk_err" | sudo -n tee -- "$tmpfstab" >/dev/null 2>"$_tee_err"
    end
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
    set -l _tmp_size (sudo -n stat -c '%s' -- "$tmpfstab" 2>/dev/null)
    if not string match -qr '^[0-9]+$' -- "$_tmp_size"; or test "$_tmp_size" -lt 20; _fail "  /etc/fstab: rewrite produced suspiciously small tmpfile ($_tmp_size bytes) — refusing to install"; return 1; end
    return 0
end
function _fstab_atomic_replace --description "Atomic /etc/fstab rewrite (mktemp + awk + verify + mv)"
    set -l tmpfstab (sudo -n mktemp -p /etc .ry-install.fstab.XXXXXX 2>/dev/null)
    _track_tmpfile "$tmpfstab"
    if test -z "$tmpfstab"; _fail "  /etc/fstab: mktemp failed"; return 1; end
    if sudo -n test -L "$tmpfstab" 2>/dev/null; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: temp file is symlink — aborting"; return 1; end
    if not _far_awk_rewrite "$tmpfstab"; _rm_tmp "$tmpfstab" true; return 1; end
    if not sudo -n chmod --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: chmod --reference failed"; return 1; end
    if not sudo -n chown --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: chown --reference failed"; return 1; end
    if command -q findmnt
        set -l _verify_out (sudo -n findmnt --verify --tab-file "$tmpfstab" 2>&1)
        if test $status -ne 0
            _rm_tmp "$tmpfstab" true
            _fail "  /etc/fstab: findmnt --verify failed:"
            for _vl in (printf '%s\n' $_verify_out | command head -n 3); _fail "    $_vl"; end
            return 1
        end
    end
    if not sudo -n mv -T -- "$tmpfstab" /etc/fstab; _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: atomic move failed"; return 1; end
    _untrack_tmpfile "$tmpfstab"
    return 0
end
function _install_fstab_opts --description "Add noatime,lazytime,commit=10 to ext4 fstab entries"
    if not test -f /etc/fstab; _warn "  /etc/fstab not found — skipping"; return 0; end
    if test -L /etc/fstab; _fail "  /etc/fstab is a symlink — refusing to rewrite (resolve symlink first or skip fstab opts)"; return 1; end
    set -l ext4_lines
    if not test -r /etc/fstab
        if not sudo -n test -r /etc/fstab 2>/dev/null; _fail "  /etc/fstab not readable (even via sudo) — cannot rewrite (check fstab perms)"; return 1; end
        _info "  /etc/fstab not user-readable — using sudo for read+rewrite"
        set ext4_lines (sudo -n awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
    else
        set ext4_lines (command awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
    end
    if test -z "$ext4_lines"; _info "  No ext4 entries in /etc/fstab"; return 0; end
    _fstab_needs_change $ext4_lines
    if test "$_RY_FSTAB_NEEDS_CHANGE" = false
        set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES
        _ok "  /etc/fstab: ext4 entries already have noatime,lazytime,commit=10"
        _log "FSTAB_OPTS_NOOP: ext4 entries already conformant"
        return 0
    end
    test (count $_RY_FSTAB_COMMIT_OVERRIDES) -gt 0; and _warn "  /etc/fstab: replacing existing commit= value(s) with commit=10: $_RY_FSTAB_COMMIT_OVERRIDES"
    set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES
    not _fstab_atomic_replace; and return 1
    _ok "  /etc/fstab: noatime,lazytime,commit=10 applied to ext4 entries"
    _log "FSTAB_OPTS: noatime,lazytime,commit=10 applied"
    return 0
end
function _configure_services_resolved_restart --description "Restart systemd-resolved when its conf.d drop-in is in place"
    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf; not _run sudo -n systemctl restart systemd-resolved; and _warn "Systemd-resolved restart failed"; end
    return 0
end
function _configure_services_thp_apply --description "Apply THP tmpfiles.d entry immediately (avoid reboot dependency for verify-runtime)"
    test -f /etc/tmpfiles.d/99-cachyos-thp.conf; or return 0
    command -q systemd-tmpfiles; or return 0
    not _run sudo -n systemd-tmpfiles --create -- /etc/tmpfiles.d/99-cachyos-thp.conf; and _warn "systemd-tmpfiles --create for 99-cachyos-thp.conf failed (will apply on next boot)"
    return 0
end
function _csp_filter_rdeps --argument-names pkg --description "Emit one-pkg-per-line: \$pkg + installed rdeps (cascade=1) or nothing (blocked)"
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
    set -l _pkg_re (string escape --style=regex -- "$pkg")
    set -l _t (_run_resolve_timeout)
    test -z "$_t"; and set _t 60
    test "$_t" -gt 60; and set _t 60
    # Pipe: trim → strip `[=<>]…` version constraints → filter self+empty. Output: bare rdep names.
    set -l _rdeps_raw (command timeout "$_t" pactree -ru "$pkg" 2>/dev/null | string trim -- | string replace -r '[=<>].*$' '' | string match -rv -- "^($_pkg_re|)\$")
    set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0; _warn "  $pkg: pactree probe failed (rc=$_ps[1]) — skipping for safety"; _log "PACTREE_PROBE_FAIL: pkg=$pkg pactree_rc=$_ps[1] (timeout, missing pkg, or db error)"; return 0; end
    # Stages 2-4 are `string` subcommands; rc=1 = no-match (normal), only ≥2 is error. 4-stage pipe → $_ps[1..4].
    if test "$_ps[2]" -ge 2; or test "$_ps[3]" -ge 2; or test "$_ps[4]" -ge 2
        set -l _ps_str (string join , -- $_ps)
        _warn "  $pkg: pactree pipe failure (pipestatus=$_ps_str) — skipping for safety"
        _log "PACTREE_PIPE_FAIL: pkg=$pkg pipestatus=$_ps_str"
        return 0
    end
    set -l _rdeps
    for _r in $_rdeps_raw; contains -- "$_r" $PKGS_DEL; and continue; set -a _rdeps "$_r"; end
    if test (count $_rdeps) -gt 0
        if test "$RY_INSTALL_PKG_REMOVE_CASCADE" = 1; _warn "  $pkg: cascading removal of reverse dependencies: $_rdeps"; _log "PKG_REMOVE_CASCADE: pkg=$pkg rdeps=$_rdeps"; printf '%s\n' $pkg $_rdeps; return 0; end
        _info "  $pkg: skipped (reverse deps: $_rdeps)"
        # fish-specific: command subs run in parent shell; `set -a` propagates to caller's loop.
        set -a _RY_PKG_REMOVE_SKIPS "$pkg"
        return 0
    end
    printf '%s\n' "$pkg"
end
function _csp_remove_pkgs --description "pacman -Rns batch with per-pkg retry on batch failure"
    if test -f /var/lib/pacman/db.lck
        _err "Pacman database is locked (/var/lib/pacman/db.lck) — another pacman may be running, or it is a stale lock from a crashed run; skipping package removal"
        set -g INSTALL_HAD_ERRORS true
        return 0
    end
    if _run sudo -n pacman -Rns --noconfirm -- $argv; _ok "Removed: $argv"; _log "PKG_REMOVE_BATCH_OK: $argv"; return 0; end
    if test -f /var/lib/pacman/db.lck; _err "Pacman database became locked during removal — aborting"; set -g INSTALL_HAD_ERRORS true; _log "PKG_REMOVE_BATCH_FAIL_DBLOCK: $argv"; return 0; end
    _warn "Batch removal failed, trying individually..."
    _log "PKG_REMOVE_BATCH_FAIL: $argv"
    set -l _retry_installed (command pacman -Qq 2>/dev/null)
    if test $status -ne 0; _warn "pacman -Qq failed during retry — aborting per-pkg removal"; _log "PKG_REMOVE_RETRY_QQ_FAIL: pacman -Qq returned non-zero"; return 0; end
    for pkg in $argv
        contains -- "$pkg" $_retry_installed; or continue
        if not _run sudo -n pacman -Rns --noconfirm -- "$pkg"
            _warn "Failed to remove $pkg"
            _log "PKG_REMOVE_FAIL: $pkg"
        else
            _log "PKG_REMOVE_OK: $pkg"
        end
    end
end
function _configure_services_pkg_remove --description "Remove PKGS_DEL packages (rdep-aware via pactree)"
    if not command -q pacman; _warn "pacman not found, skipping PKGS_DEL removal"; return 0; end
    set -g _RY_PKG_REMOVE_SKIPS; set -l to_del; set -l _del_installed (command pacman -Qq 2>/dev/null)
    for pkg in $PKGS_DEL
        contains -- "$pkg" $_del_installed; or continue
        for _emit in (_csp_filter_rdeps "$pkg"); test -z "$_emit"; and continue; contains -- "$_emit" $to_del; and continue; set -a to_del "$_emit"; end
    end
    if test (count $_RY_PKG_REMOVE_SKIPS) -gt 0
        _warn "  Skipped (reverse deps held by other packages): $_RY_PKG_REMOVE_SKIPS — set RY_INSTALL_PKG_REMOVE_CASCADE=1 to cascade"
        _log "PKG_REMOVE_SKIPS: $_RY_PKG_REMOVE_SKIPS"
    end
    if test (count $to_del) -gt 0; _log "PKG_REMOVE_REQUESTED: $to_del"; _csp_remove_pkgs $to_del; end
    return 0
end
function _csm_filter_units --description "_configure_services_mask sub. Pre-filter unit list"
    for _unit in $argv
        set -l _state (command systemctl is-enabled -- $_unit 2>/dev/null | string trim --)
        if test "$_state" = masked; _log "MASK_ALREADY: $_unit"; continue; end
        if test -z "$_state"; _info "Mask skip (unit not installed): $_unit"; _log "MASK_NOT_INSTALLED: $_unit"; continue; end
        printf '%s\n' "$_unit"
    end
end
function _csm_retry_individual --description "_configure_services_mask sub. Per-unit retry after batch mask failed (argv pre-filtered by _csm_filter_units)"
    set -l _ret 0
    for _unit in $argv
        if _run sudo -n systemctl mask -- $_unit
            _ok "Masked: $_unit"
        else
            set -l _state (command systemctl is-enabled -- $_unit 2>/dev/null | string trim --)
            _warn "Failed to mask: $_unit (is-enabled=$_state)"
            set _ret 1
        end
    end
    return $_ret
end
function _csm_disable_ufw_rules --description "Flush ufw rules before mask so kernel-level iptables/nftables rules don't persist post-mask"
    # `systemctl mask ufw.service` does not flush live netfilter rules; `ufw disable` does.
    contains -- ufw.service $MASK; or return 0
    command -q ufw; or return 0
    set -l _state (command systemctl is-active ufw.service 2>/dev/null | string trim --)
    if test "$_state" != active; _log "UFW_RULE_FLUSH_SKIP: ufw.service is-active=$_state"; return 0; end
    if _run sudo -n ufw --force disable
        _ok "ufw disabled — netfilter rules flushed prior to mask"
        _log "UFW_RULE_FLUSH_OK"
    else
        _warn "ufw --force disable failed — netfilter rules may persist until reboot"
        _log "UFW_RULE_FLUSH_FAIL"
    end
    return 0
end
function _configure_services_mask --description "Apply MASK list; batch-mask with per-unit retry"
    _csm_disable_ufw_rules
    set -l safe_mask (_mask_list_effective)
    test (count $safe_mask) -eq 0; and return 0
    set -l _to_mask (_csm_filter_units $safe_mask)
    test (count $_to_mask) -eq 0; and return 0
    _run sudo -n systemctl mask -- $_to_mask; and return 0
    _warn "Batch mask failed — retrying individually to identify failures"
    _csm_retry_individual $_to_mask
    return $status
end
function _cse_collect_units --description "Collect system units to enable"
    set -l _enable
    set -l _ndsp (command systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null | string trim --)
    if test "$_ndsp" = enabled
        _ok "NetworkManager-dispatcher.service: already enabled"
    else if test -z "$_ndsp"
        _info "NetworkManager-dispatcher.service: not installed — skipping enable"
    else
        set -a _enable NetworkManager-dispatcher.service
    end
    if set -q _RY_DEPLOYED_SERVICES; and test (count $_RY_DEPLOYED_SERVICES) -gt 0
        not _run sudo -n systemctl daemon-reload; and _warn "Systemctl daemon-reload failed"
        for _u in $_RY_DEPLOYED_SERVICES; set -a _enable $_u; end
    end
    for _exp in $EXPECTED_SERVICES; contains -- "$_exp" $_RY_DEPLOYED_SERVICES; and continue; contains -- "$_exp" $_RY_PKG_MANAGED_SERVICES; and continue; set -a _enable "$_exp"; end
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
            # Accept-list per systemctl(1): states that run on boot. Excluded: masked, disabled, bad, empty.
            if contains -- "$_enabled_state" enabled enabled-runtime alias static linked linked-runtime indirect generated transient
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
function _configure_services_enable --description "Daemon-reload, batch-enable system units"
    set -l _ret 0
    set -l _units (_cse_collect_units)
    _cse_batch_enable $_units; or set _ret 1
    return $_ret
end
function _install_configure_services --description "Enable, start, and configure systemd services"
    _progress Services
    _info "Post-installation tasks..."
    set -l _ret 0
    _configure_services_resolved_restart
    _configure_services_thp_apply
    _configure_services_pkg_remove
    _configure_services_mask; or set _ret 1
    _configure_services_enable; or set _ret 1
    return $_ret
end
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
    if test -z "$_p"; or not sudo -n test -d "$_p" 2>/dev/null
        for _candidate in /efi /boot/efi /boot/EFI /boot
            set -l _fs (command findmnt -no FSTYPE -- "$_candidate" 2>/dev/null)
            if test "$_fs" = vfat; set _p "$_candidate"; break; end
        end
    end
    if test -z "$_p"; or not sudo -n test -d "$_p" 2>/dev/null
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
    test -z "$_p"; or not sudo -n test -d "$_p" 2>/dev/null; and set _p (_resolve_esp)
    set -g _RY_BOOT_PATH "$_p"; set -g _RY_BOOT_TRIED true
    printf '%s' "$_p"
end
function _enum_boot_entries --argument-names esp --description "Enumerate \$esp/loader/entries/*.conf"
    set -g _RY_BOOT_ENUM_OK true
    set -l _basenames (sudo -n find "$esp/loader/entries" -maxdepth 1 -type f -name '*.conf' -printf '%f\0' 2>/dev/null | string split0)
    set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0; set -g _RY_BOOT_ENUM_OK false; set -g _RY_BOOT_COUNT 0; functions -q _log; and _log "BOOT_ENUM_FAIL: esp=$esp pipestatus=$_ps (sudo lapse or read error)"; return 0; end
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
            if test $status -ne 0; _err "Zero-byte $label image: $f"; set errors (math $errors + 1); end
        end
    end
    echo $errors
end
function _pbs_entry_has_valid_kernel --argument-names boot conf --description "Probe a loader-entry .conf for a kernel image inside \$BOOT"
    set -l linux_line (sudo -n grep -m1 -E '^[[:space:]]*linux[[:space:]]' -- "$conf" 2>/dev/null | string replace -r '^\s*linux\s+' '' | string trim --)
    test -z "$linux_line"; and return 1
    set -l linux_rel (string replace -r '^/+' '' -- "$linux_line")
    set -l linux_canon (command realpath -m -- "$boot/$linux_rel" 2>/dev/null)
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
    set -l _k (_pbs_check_boot_files "$_boot" 'vmlinuz-*' kernel)
    set -l _i (_pbs_check_boot_files "$_boot" 'initramfs-*.img' initramfs)
    set -l _e (_pbs_check_entries "$_boot")
    for _v in _k _i _e; string match -qr '^\d+$' -- "$$_v"; or set $_v 1; end
    set -l errors (math $_k + $_i + $_e)
    if test $errors -gt 0
        _err "Boot sanity check failed ($errors error(s)) — DO NOT REBOOT"
        _info "  Inspect: ls -la $_boot/vmlinuz-* $_boot/initramfs-*.img"
        _info "  Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen"
        return 1
    end
    _ok "Boot sanity: vmlinuz present, initramfs non-zero, entries valid"
    return 0
end
function _boot_initrd_size_scan --argument-names esp --description "Post-rebuild initramfs size sanity check"
    set -l _initrd_list (sudo -n find "$esp" -maxdepth 1 -type f -name 'initramfs-*.img' -print0 2>/dev/null | string split0)
    set -l _il_ps $pipestatus
    if test "$_il_ps[1]" -ne 0; _warn "Cannot enumerate initramfs-*.img for size check (sudo lapsed or read error)"; return 0; end
    # Compare in bytes: avoids floor-to-MB precision loss (100.9MB would pass 100MB threshold).
    set -l _threshold_b (math "$INITRD_WARN_MB * 1048576")
    for initrd in $_initrd_list
        set -l size_b (sudo -n stat -c '%s' -- "$initrd" 2>/dev/null)
        if test -n "$size_b"; and string match -qr '^\d+$' -- "$size_b"
            set -l size_mb (math "floor($size_b / 1048576)")
            if test "$size_b" -gt "$_threshold_b"
                _warn "Large initramfs: $initrd ($size_mb MB > $INITRD_WARN_MB MB threshold) - consider reviewing MODULES/HOOKS"
            else
                _ok "Initramfs size: $initrd ($size_mb MB)"
            end
        end
    end
    return 0
end
function _irb_skip_post_mki --description "Record SKIP rows for sdboot-gen, sdboot-update, post-rebuild sanity"
    _phase_record "Boot: sdboot-manage gen" SKIP "aborted"
    _phase_record "Boot: sdboot-manage update" SKIP "aborted"
    _phase_record "Boot: post-rebuild sanity" SKIP "aborted"
end
function _irb_sdboot_apply --description "Run sdboot-manage gen + update"
    if set -q _RY_ESP_FALLBACK; and test "$_RY_ESP_FALLBACK" = true
        set -l _boot_fs (command findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)
        if test "$_boot_fs" != vfat
            _err "Refusing sdboot-manage: ESP autodetect fell back to /boot but /boot is not vfat (fstype=$_boot_fs)"
            _err "  ry-install targets systemd-boot. Detected non-systemd-boot bootloader — aborting."
            _log "SDBOOT_APPLY_REFUSED: esp_fallback=true boot_fstype=$_boot_fs"
            _phase_record "Boot: sdboot-manage gen" FAIL "ESP fallback to /boot not vfat (fstype=$_boot_fs)"
            _phase_record "Boot: sdboot-manage update" SKIP "aborted"
            return $EXIT_BOOT_CRIT
        end
    end
    if not _run sudo -n sdboot-manage gen
        _err "Sdboot-manage gen failed"
        _err "CRITICAL: Bootloader update failed — aborting remaining steps"
        _phase_record "Boot: sdboot-manage gen" FAIL "rc=non-zero"
        _phase_record "Boot: sdboot-manage update" SKIP "aborted"
        return $EXIT_BOOT_CRIT
    end
    _phase_record "Boot: sdboot-manage gen" PASS "rc=0"
    if not _run sudo -n sdboot-manage update
        _err "Sdboot-manage update failed (bootctl EFI binary refresh)"
        _err "CRITICAL: Bootloader binary update failed — aborting remaining steps"
        _phase_record "Boot: sdboot-manage update" FAIL "rc=non-zero"
        return $EXIT_BOOT_CRIT
    end
    _phase_record "Boot: sdboot-manage update" PASS "rc=0"
    return 0
end
function _irb_verify_entries --argument-names esp --description "Re-enumerate boot entries post-rebuild"
    _enum_boot_entries "$esp"
    if test "$_RY_BOOT_ENUM_OK" = false
        _warn "Boot entries: cannot enumerate $esp/loader/entries (sudo lapsed or read error)"
    else
        set -l entry_count $_RY_BOOT_COUNT
        if test "$entry_count" -gt 0
            _ok "Boot entries: $entry_count found in $esp/loader/entries/"
        else
            _err "No boot entries found in $esp/loader/entries/"
            _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
            _info "  Try: sudo sdboot-manage gen --verbose"
            set -g INSTALL_HAD_ERRORS true
        end
    end
    _boot_initrd_size_scan "$esp"
end
function _irb_taint_gate --description "_install_rebuild_boot sub. Verify mkinitcpio.conf is consistent and boot state is not tainted; returns non-zero with _phase_record + _irb_skip_post_mki on bail"
    if test "$_RY_BOOT_TAINTED" = true; and test "$RY_INSTALL_FORCE_BOOT_REBUILD" = 1
        # Surface override: post-mortem cannot distinguish forced vs clean otherwise.
        _warn "Boot-rebuild forced by RY_INSTALL_FORCE_BOOT_REBUILD=1 — _RY_BOOT_TAINTED gate bypassed"
        _log "BOOT_TAINTED_OVERRIDE: RY_INSTALL_FORCE_BOOT_REBUILD=1 bypassed taint flag in _install_rebuild_boot"
    end
    if set -q _RY_MKI_REVERT_FAILED; and test "$_RY_MKI_REVERT_FAILED" = true
        _err "Refusing initramfs rebuild — mkinitcpio.conf revert failed (boot state inconsistent)"
        _err "  Manual recovery required; RY_INSTALL_FORCE_BOOT_REBUILD does NOT bypass this gate"
        _phase_record "Boot: mkinitcpio -P" SKIP "mkinitcpio.conf revert failed"
        _irb_skip_post_mki
        return $EXIT_BOOT_CRIT
    end
    if test "$_RY_BOOT_TAINTED" = true; and not test "$RY_INSTALL_FORCE_BOOT_REBUILD" = 1
        _err "Refusing initramfs rebuild — an earlier phase of THIS run tainted package or boot-critical config state"
        _err "  (mkinitcpio.conf, kernel cmdline, loader, sdboot-manage, or pacman/AUR install failed)"
        _err "  Resolve manually then re-run, OR set RY_INSTALL_FORCE_BOOT_REBUILD=1 to force"
        _phase_record "Boot: mkinitcpio -P" SKIP "_RY_BOOT_TAINTED=true"
        _irb_skip_post_mki
        return $EXIT_BOOT_CRIT
    end
    return 0
end
function _install_rebuild_boot --description "Regenerate initramfs and bootloader entries"
    _progress Boot
    _irb_taint_gate
    set -l _tg_rc $status
    test $_tg_rc -ne 0; and return $_tg_rc
    test "$SYSTEM_UPGRADED" = true; and _ok "System upgraded during package installation"
    if not _run sudo -n mkinitcpio -P
        _err "Mkinitcpio failed"
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
    if test $_sb_rc -ne 0; _phase_record "Boot: post-rebuild sanity" SKIP "aborted"; return $_sb_rc; end
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
function _if_trim_pacman_cache --description "Trim pacman cache via paccache -rk2 -ruk0"
    if not set -q SYSTEM_UPGRADED; or test "$SYSTEM_UPGRADED" != true
        _log "PACMAN_CACHE_TRIM_SKIP: SYSTEM_UPGRADED=false (idempotent re-run)"
        _phase_record "Finalize: pacman cache trim" SKIP "no upgrade this run"
        return 0
    end
    if command -q paccache
        if _run sudo -n paccache -rk2 -ruk0
            _phase_record "Finalize: pacman cache trim" PASS "paccache -rk2"
        else
            _warn "Paccache cache trim failed"
            _phase_record "Finalize: pacman cache trim" WARN "paccache failed"
        end
    else
        if _run sudo -n pacman -Sc --noconfirm
            _phase_record "Finalize: pacman cache trim" PASS "pacman -Sc"
        else
            _warn "Pacman cache clear failed"
            _phase_record "Finalize: pacman cache trim" WARN "pacman -Sc failed"
        end
    end
    return 0
end
function _if_nm_restart --description "Restart NetworkManager when iwd backend switch is in effect"
    if test "$_PROFILE_USES_WIFI_BACKEND" = false; _info "iwd/NetworkManager not managed — skipping NM restart"; _phase_record "Finalize: NetworkManager restart" SKIP "iwd backend not active"; return 0; end
    if not command -q pacman; or not command pacman -Qi iwd >/dev/null 2>&1
        _warn "iwd configs deployed but iwd package is not installed"
        set -g INSTALL_HAD_ERRORS true
        _phase_record "Finalize: NetworkManager restart" WARN "iwd package not installed"
        return 0
    end
    if _is_wifi_active_route
        _warn "NetworkManager restart deferred — WiFi is the active route; iwd backend switch takes effect on reboot."
        _info "  Or, after switching to ethernet: sudo systemctl restart NetworkManager"
        _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=finalize_backend_switch"
        _phase_record "Finalize: NetworkManager restart" DEFER "over WiFi — applies on reboot"
        return 0
    end
    _info "iwd will restart with NetworkManager (D-Bus disconnect expected)"
    if not _run sudo -n systemctl restart NetworkManager
        _warn "NetworkManager restart failed (will recover on reboot)"
        _log "NM_RESTART_FAILED: context=finalize_backend_switch"
        _phase_record "Finalize: NetworkManager restart" WARN "restart failed (will recover on reboot)"
    else
        _phase_record "Finalize: NetworkManager restart" PASS "restarted"
    end
    command sleep $NM_RESTART_DELAY 2>/dev/null; or _warn "Sleep interrupted during NM restart settle window"
    return 0
end
function _install_finalize --description "Run post-install verification, cleanup, and summary"
    _progress Finalize
    if _has_user_bus_active
        if _run systemctl --user daemon-reload
            _phase_record "Finalize: systemctl --user reload" PASS "user-bus active"
        else
            _warn "Systemctl --user daemon-reload failed"
            _phase_record "Finalize: systemctl --user reload" WARN "daemon-reload failed"
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
function _rrp_optional_indexer --argument-names cmd label flag --description "_rdi_run_phases sub. Run an optional indexer (updatedb / pkgfile) and record phase"
    if not command -q $cmd; _phase_record "Packages: $label" "--" "not installed"; return 0; end
    if _run sudo -n $cmd $flag
        _phase_record "Packages: $label" PASS "ok"
    else
        _warn "$label failed"
        _phase_record "Packages: $label" WARN "failed (non-fatal)"
    end
end
function _rdi_run_phases --description "Run pkgs/aur/sys/fstab/services phases"
    not _install_packages; and set -g INSTALL_HAD_ERRORS true
    if set -q _RY_MKI_REVERT_FAILED; and test "$_RY_MKI_REVERT_FAILED" = true
        _phase_record "Packages: AUR (paru)" SKIP "mkinitcpio.conf revert failed — aborting"
        _phase_record "Configs: system file deployment" SKIP "aborted"
        _phase_record "Configs: /etc/fstab opts" SKIP "aborted"
        _phase_record "Services: configuration" SKIP "aborted"
        _err "Aborting remaining phases: mkinitcpio.conf revert failed (boot state inconsistent)"
        return 0
    end
    if set -q _RY_PACMAN_REVERT_ATTEMPTED; and test "$_RY_PACMAN_REVERT_ATTEMPTED" = true
        _warn "Skipping AUR phase: pacman -Syu was rolled back (avoiding install against inconsistent mkinitcpio state)"
        _log "AUR_SKIP_AFTER_REVERT: pacman rolled back; AUR phase bypassed"
        _phase_record "Packages: AUR (paru)" SKIP "pacman rolled back"
    else
        not _install_aur_packages; and set -g INSTALL_HAD_ERRORS true
    end
    # AUR may have transitively installed iwd; re-probe.
    set --erase _RY_SKIP_IWD
    _rrp_optional_indexer updatedb updatedb ""
    _rrp_optional_indexer pkgfile "pkgfile --update" --update
    set -g _RY_DEPLOY_CHANGED_COUNT 0; set -g _RY_DEPLOY_IDEMPOTENT_COUNT 0
    if _install_system_files
        _phase_record "Configs: system file deployment" PASS "$_RY_DEPLOY_CHANGED_COUNT deployed, $_RY_DEPLOY_IDEMPOTENT_COUNT idempotent"
    else
        set -g INSTALL_HAD_ERRORS true
        _phase_record "Configs: system file deployment" FAIL "$_RY_DEPLOY_CHANGED_COUNT deployed, $_RY_DEPLOY_IDEMPOTENT_COUNT idempotent, see JSONL"
    end
    if _install_fstab_opts
        _phase_record "Configs: /etc/fstab opts" PASS "noatime,lazytime,commit=10"
    else
        set -g INSTALL_HAD_ERRORS true
        _phase_record "Configs: /etc/fstab opts" FAIL "see JSONL log"
    end
    if _install_configure_services
        _phase_record "Services: configuration" PASS "mask + enable ok"
    else
        set -g INSTALL_HAD_ERRORS true
        _phase_record "Services: configuration" FAIL "see JSONL log"
    end
    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end
function _rdi_elapsed --description "Format wall-clock elapsed since _PROG_START as 'Nm Ms'"
    set -q _PROG_START; or begin; printf '%s' "?"; return 0; end
    set -l _now (_progress_now)
    set -l _secs (math $_now - $_PROG_START)
    if test $_secs -lt 60
        printf '%ds' $_secs
    else
        set -l _m (math "floor($_secs / 60)")
        set -l _s (math "$_secs - $_m * 60")
        printf '%dm %ds' $_m $_s
    end
end
function _rdi_matrix_header --description "_rdi_render_matrix sub. Emit top bar, title, column header, separator"
    set -l _bar_top $argv[1]; set -l _sep_c $argv[2]; set -l _sep_r $argv[3]; set -l _sep_e $argv[4]
    set -l _inner $argv[5]; set -l _w_c $argv[6]; set -l _w_r $argv[7]; set -l _w_e $argv[8]
    set -l _title "ry-install v$VERSION — RUN SUMMARY"
    # Center title within $_inner cols; (inner - len) // 2 spaces of left pad
    set -l _title_lpad (math -s0 "max(0, ($_inner - "(string length -- $_title)") / 2)")
    set -l _title_padded $_title
    test $_title_lpad -gt 0; and set _title_padded (string repeat -n $_title_lpad ' ')$_title
    set _title_padded (string pad -r -w $_inner -- $_title_padded)
    printf '╔%s╗\n' $_bar_top >&2
    printf '║%s║\n' $_title_padded >&2
    printf '╠%s╦%s╦%s╣\n' $_sep_c $_sep_r $_sep_e >&2
    printf '║ %s ║ %s ║ %s ║\n' (string pad -r -w $_w_c -- CHECK) (string pad -r -w $_w_r -- RESULT) (string pad -r -w $_w_e -- EVIDENCE) >&2
    printf '╠%s╬%s╬%s╣\n' $_sep_c $_sep_r $_sep_e >&2
end
function _rdi_matrix_rows --description "_rdi_render_matrix sub. Emit data rows; tally buckets via _RY_MTX_* globals"
    set -l _w_c $argv[1]; set -l _w_r $argv[2]; set -l _w_e $argv[3]
    set -g _RY_MTX_PASS 0; set -g _RY_MTX_WARN 0; set -g _RY_MTX_FAIL 0
    set -g _RY_MTX_DEFER 0; set -g _RY_MTX_SKIP 0; set -g _RY_MTX_NA 0
    for _row in $_RY_PHASE_RESULTS
        set -l _parts (string split '│' -- $_row)
        test (string length -- $_parts[1]) -gt $_w_c; and functions -q _log; and _log "MATRIX_TRUNCATED: check label "(string length -- $_parts[1])" > $_w_c chars: $_parts[1]"
        test (string length -- $_parts[3]) -gt $_w_e; and functions -q _log; and _log "MATRIX_TRUNCATED: evidence "(string length -- $_parts[3])" > $_w_e chars: $_parts[3]"
        set -l _chk (string sub -l $_w_c -- $_parts[1]); set -l _res $_parts[2]; set -l _evd (string sub -l $_w_e -- $_parts[3])
        set -l _res_lpad (math -s0 "max(0, ($_w_r - "(string length -- $_res)") / 2)")
        set -l _res_padded $_res
        test $_res_lpad -gt 0; and set _res_padded (string repeat -n $_res_lpad ' ')$_res
        set _res_padded (string pad -r -w $_w_r -- $_res_padded)
        printf '║ %s ║ %s ║ %s ║\n' (string pad -r -w $_w_c -- $_chk) $_res_padded (string pad -r -w $_w_e -- $_evd) >&2
        switch $_parts[2]
            case PASS;  set -g _RY_MTX_PASS  (math $_RY_MTX_PASS + 1)
            case WARN;  set -g _RY_MTX_WARN  (math $_RY_MTX_WARN + 1)
            case FAIL;  set -g _RY_MTX_FAIL  (math $_RY_MTX_FAIL + 1)
            case DEFER; set -g _RY_MTX_DEFER (math $_RY_MTX_DEFER + 1)
            case SKIP;  set -g _RY_MTX_SKIP  (math $_RY_MTX_SKIP + 1)
            case '*';   set -g _RY_MTX_NA    (math $_RY_MTX_NA + 1)
        end
    end
end
function _rdi_matrix_footer --description "_rdi_render_matrix sub. Emit verdict-bearing footer rows + bottom bar"
    set -l _bar_top $argv[1]; set -l _inner $argv[2]
    set -l _verdict PASS
    test $_RY_MTX_WARN -gt 0; and set _verdict PASS-WITH-WARNINGS
    test $_RY_MTX_FAIL -gt 0; and set _verdict FAIL
    set -q _RY_BOOT_CRIT_HIT; and test "$_RY_BOOT_CRIT_HIT" = true; and set _verdict FAIL-BOOT-CRITICAL
    set -l _totals "Totals : $_RY_MTX_PASS PASS · $_RY_MTX_WARN WARN · $_RY_MTX_FAIL FAIL · $_RY_MTX_DEFER DEFER · $_RY_MTX_SKIP SKIP · $_RY_MTX_NA N/A"
    set -l _elapsed "Elapsed: "(_rdi_elapsed)"   ·   Verdict: $_verdict"
    set -l _log_line "Log    : $LOG_FILE"
    set -l _next_msg "Next   : reboot · ./ry-install.fish --verify-static · --verify-runtime"
    test "$_verdict" != PASS; and set _next_msg "Next   : review FAIL/WARN above · re-run install (idempotent)"
    set -l _pad_inner (math "$_inner - 2")
    printf '╠%s╣\n' $_bar_top >&2
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
    if set -q RY_INSTALL_NO_MATRIX; and test "$RY_INSTALL_NO_MATRIX" = 1; _log "MATRIX_RENDER_SKIP: RY_INSTALL_NO_MATRIX=1"; return 0; end
    set -q _RY_OUTPUT_BROKEN; and return 0
    set -l _w_check 34; set -l _w_result 6; set -l _w_evidence 30
    # _inner = sum of 3 col widths + 6 padding spaces (2 per cell) + 2 inner ║ separators = w+8
    set -l _inner (math "$_w_check + $_w_result + $_w_evidence + 8")
    set -l _bar_top (string repeat -n $_inner '═')
    set -l _sep_c (string repeat -n (math "$_w_check + 2") '═')
    set -l _sep_r (string repeat -n (math "$_w_result + 2") '═')
    set -l _sep_e (string repeat -n (math "$_w_evidence + 2") '═')
    _rdi_matrix_header $_bar_top $_sep_c $_sep_r $_sep_e $_inner $_w_check $_w_result $_w_evidence
    _rdi_matrix_rows $_w_check $_w_result $_w_evidence
    _rdi_matrix_footer $_bar_top $_inner
end
function _rdi_summary --description "Print final install summary"
    if test "$INSTALL_HAD_ERRORS" = true
        _echo "INSTALLATION FINISHED WITH WARNINGS"
        _err "Some steps had errors - review log for details"
    else
        _echo "INSTALLATION COMPLETE"
    end
    _rdi_render_matrix
    set -q _RY_AUR_PARTIAL; and test "$_RY_AUR_PARTIAL" = true; and _warn "AUR phase completed with partial success — some packages failed (see JSONL log)"
    if set -q _RY_BOOT_CRIT_HIT; and test "$_RY_BOOT_CRIT_HIT" = true
        _err "DO NOT REBOOT — boot-critical failure (verdict: FAIL-BOOT-CRITICAL)"
        _info "Recovery steps:"
        _info "  1. Inspect: ls -la /boot/vmlinuz-* /boot/initramfs-*.img; sudo bootctl list"
        _info "  2. Rebuild: sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update"
        _info "  3. Re-run ry-install (idempotent) — only reboot once verdict is PASS or PASS-WITH-WARNINGS"
        _info "JSONL log captures the exact failure: $LOG_FILE"
        return 0
    end
    _info "Manual steps required:"
    _info "  1. Run 'rehash' or start new shell (updates command paths)"
    _info "  2. REBOOT to apply kernel cmdline and module changes"
    # realtime-privileges: 'realtime' group; changes need re-login.
    if command -q pacman; and command pacman -Qq realtime-privileges >/dev/null 2>&1
        set -l _uname (command getent passwd $_MY_UID 2>/dev/null | command head -n 1 | command awk -F: '{print $1}')
        if test -n "$_uname"; and not command id -nG -- "$_uname" 2>/dev/null | string match -qr '\brealtime\b'
            _info "  3. Add user to realtime group for PipeWire RT scheduling:"
            _info "       sudo gpasswd -a $_uname realtime  (then log out and back in)"
        end
    end
    _info "Post-reboot verification: ./ry-install.fish --verify-static; and ./ry-install.fish --verify-runtime"
    if test "$INSTALL_HAD_ERRORS" = true
        _warn "Done (with warnings - see above)"
    else
        _ok "Done!"
    end
end
function _ry_do_install --description "Full installation: preflight, packages, configs, services, boot"
    _log_section "INSTALLATION START"
    _log "VERSION: $VERSION"
    _log "MODE: unattended"
    _echo "ry-install v$VERSION"
    _progress_init
    _install_preflight
    set -l _pre_rc $status
    if test $_pre_rc -ne 0; _progress_done; _rdi_render_matrix; _log_section "INSTALLATION END"; test $_pre_rc -eq $EXIT_USAGE; and return $EXIT_USAGE; return $EXIT_PREFLIGHT; end
    # rc discarded; phase failures tracked via INSTALL_HAD_ERRORS.
    _rdi_run_phases
    _install_rebuild_boot
    set -l _boot_rc $status
    test $_boot_rc -ne 0; and set -g INSTALL_HAD_ERRORS true
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
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
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT; _log "INSTALL_BAILOUT: boot-critical failure → returning EXIT_BOOT_CRIT"; return $EXIT_BOOT_CRIT; end
    test "$INSTALL_HAD_ERRORS" = true; and return $EXIT_FAIL
    return $EXIT_OK
end

# First-match-wins (specific first, `*.service` catchall last); fish glob `*` spans `/`.
set -g _RY_POST_HOOKS \
    "/boot/*|boot" \
    "/efi/*|boot" \
    "/etc/mkinitcpio.conf|boot" \
    "/etc/sdboot-manage.conf|boot" \
    "/etc/kernel/cmdline|boot" \
    "*/resolved.conf.d/*|resolved" \
    "*/logind.conf.d/*|logind" \
    "*/iwd/main.conf|nm" \
    "*/NetworkManager/conf.d/*|nm" \
    "*/sysctl.d/*|sysctl" \
    "*/environment.d/*|envd" \
    "/etc/default/cpupower-service.conf|cpupower" \
    "*/tmpfiles.d/*|tmpfiles" \
    "*.service|service"

function _post_hook_for_target --argument-names target --description "Return post-hook tag for a single target path"
    for _entry in $_RY_POST_HOOKS
        set -l _parts (string split -r -m1 '|' -- $_entry)
        if string match -q "$_parts[1]" -- "$target"; echo "$_parts[2]"; return 0; end
    end
    return 1
end
function _idf_match_dst --argument-names target --description "Match \$target against managed destinations"
    # _idx aligns canon-list to source-list (order preserved; drift refused by _ir_validate_counts).
    set -l _idx 1
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if test "$target" = "$dst"; or test "$target" = "$_RY_CANON_SYSTEM_DSTS[$_idx]"; echo true; return 0; end
        set _idx (math $_idx + 1)
    end
    set _idx 1
    for dst in $USER_DESTINATIONS
        if test "$target" = "$dst"; or test "$target" = "$_RY_CANON_USER_DSTS[$_idx]"; echo false; return 0; end
        set _idx (math $_idx + 1)
    end
    return 1
end
function _idf_dispatch_hook --argument-names target tag --description "Dispatch a post-hook tag to its _post_<tag> handler"
    if test -z "$tag"; or not functions -q "_post_$tag"; _err "Internal: unknown post-hook tag '$tag' (target=$target)"; return 1; end
    # Dynamic dispatch via _post_$tag.
    _post_$tag "$target"
end
function _ry_do_install_file --argument-names target --description "Install a single named config file (caller-canonicalized path)"
    _log_section "INSTALL-FILE START"
    if test -z "$target"
        _err "Usage: ry-install.fish --install-file <path>"
        _echo
        _info "Managed files:"
        for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS; _echo "  $dst"; end
        return $EXIT_USAGE
    end
    set -l _use_sudo (_idf_match_dst "$target")
    if test -z "$_use_sudo"; _err "Not a managed file: $target"; _info "Run without path to see managed files"; return $EXIT_USAGE; end
    _echo "── ry-install v$VERSION - Install Single File ──"
    if test "$_use_sudo" = true; _ensure_sudo_cached; or return $EXIT_PREFLIGHT; end
    if not _ry_install_file "$target" $_use_sudo; _err "Failed to install: $target"; _log_section "INSTALL-FILE END"; return 1; end
    _echo
    _ok "Installed: $target"
    set -l _hook_rc 0
    set -l _h (_post_hook_for_target "$target")
    if test -n "$_h"; _idf_dispatch_hook "$target" "$_h"; set _hook_rc $status; end
    _log_section "INSTALL-FILE END"
    return $_hook_rc
end
function _pb_rebuild_cascade --argument-names target --description "_post_boot sub. mkinitcpio -P + sdboot-manage cascade"
    if not _run sudo -n mkinitcpio -P; _err "Mkinitcpio failed"; _log "BOOT_REBUILD_FAILED: step=mkinitcpio target=$target"; return $EXIT_BOOT_CRIT; end
    if test "$SDBOOT_REMOVE_EXISTING" = yes
        set -l _boot (_resolve_boot_path)
        if test -z "$_boot"
            _err "Cannot resolve \$BOOT path — refusing boot-wipe gate"
            _err "CRITICAL: bootctl/findmnt failed AND /boot missing — aborting"
            _log "POST_BOOT_BOOT_RESOLVE_FAIL: target=$target"
            return $EXIT_BOOT_CRIT
        end
    end
    if not _run sudo -n sdboot-manage gen; _err "Sdboot-manage gen failed"; _log "BOOT_REBUILD_FAILED: step='sdboot-manage gen' target=$target"; return $EXIT_BOOT_CRIT; end
    if not _run sudo -n sdboot-manage update; _err "Sdboot-manage update failed"; _log "BOOT_REBUILD_FAILED: step='sdboot-manage update' target=$target"; return $EXIT_BOOT_CRIT; end
    return 0
end
function _post_boot --argument-names target --description "Post-hook: rebuild boot entries (mkinitcpio + sdboot-manage)"
    _echo
    if test "$_RY_BOOT_TAINTED" = true; and test "$RY_INSTALL_FORCE_BOOT_REBUILD" = 1
        _warn "  Boot-rebuild forced by RY_INSTALL_FORCE_BOOT_REBUILD=1 — _RY_BOOT_TAINTED gate bypassed"
        _log "BOOT_TAINTED_OVERRIDE: RY_INSTALL_FORCE_BOOT_REBUILD=1 bypassed taint flag in _post_boot target=$target"
    end
    if set -q _RY_MKI_REVERT_FAILED; and test "$_RY_MKI_REVERT_FAILED" = true
        _err "Refusing initramfs rebuild — mkinitcpio.conf revert failed (boot state inconsistent)"
        _log "POST_BOOT_REFUSED: _RY_MKI_REVERT_FAILED=true target=$target"
        return $EXIT_BOOT_CRIT
    end
    if test "$_RY_BOOT_TAINTED" = true; and not test "$RY_INSTALL_FORCE_BOOT_REBUILD" = 1
        _err "Refusing initramfs rebuild — _RY_BOOT_TAINTED=true (intra-process flag from prior deploy step or env)"
        _err "  Re-run unattended install OR set RY_INSTALL_FORCE_BOOT_REBUILD=1 to force"
        _log "POST_BOOT_REFUSED: _RY_BOOT_TAINTED=true target=$target"
        return $EXIT_BOOT_CRIT
    end
    _pb_rebuild_cascade "$target"
    set -l _cas_rc $status
    if test $_cas_rc -ne 0; _err "CRITICAL: boot rebuild cascade failed — DO NOT REBOOT"; _info "  Fix: sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update"; return $_cas_rc; end
    set -l _boot_v (_resolve_boot_path)
    test -n "$_boot_v"; and _irb_verify_entries "$_boot_v"
    if not _preflight_boot_sanity; _err "CRITICAL: boot sanity check failed after single-file install — DO NOT REBOOT"; return $EXIT_BOOT_CRIT; end
    return 0
end
function _post_service --argument-names target --description "Post-hook: daemon-reload + enable .service unit (+ try-restart to pick up changed ExecStart)"
    set -l _rc 0
    set -l _bn (command basename -- "$target")
    _run sudo -n systemctl daemon-reload; or _warn "Systemctl daemon-reload failed"
    if not _run sudo -n systemctl enable --now -- "$_bn"; _warn "Failed to enable $_bn (system)"; set _rc 1; end
    # try-restart picks up ExecStart change for non-oneshot; oneshot+RemainAfterExit re-runs idempotently.
    _run sudo -n systemctl try-restart -- "$_bn"; or _log "POST_SERVICE_TRY_RESTART: rc=non-zero unit=$_bn"
    return $_rc
end
function _post_resolved --argument-names target --description "Post-hook: restart systemd-resolved"
    _echo
    _run sudo -n systemctl restart systemd-resolved; or _warn "Systemd-resolved restart failed"
    return 0
end
function _post_logind --argument-names target --description "Post-hook: notify reboot needed for logind"
    _info "Logind config $target changed — reboot required (restarting logind kills all sessions)"
    return 0
end
function _post_nm --argument-names target --description "Post-hook: restart NetworkManager (+ try-restart iwd when iwd/main.conf changes); deferred when WiFi is active route"
    _echo
    if _is_wifi_active_route
        _warn "NM/iwd config installed but NetworkManager restart deferred — WiFi is the active route."
        _info "  Config change will not take effect until next reboot or manual restart."
        _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=install_file target=$target"
    else
        # iwd reads main.conf only at startup; NM restart alone does not re-read it.
        if string match -q '*/iwd/main.conf' -- "$target"; _run sudo -n systemctl try-restart iwd.service; or _warn "iwd try-restart failed (config will apply on next reboot)"; end
        _run sudo -n systemctl restart NetworkManager; or _warn "NetworkManager restart failed"
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
        _warn "sysctl --system failed — tunables not applied until reboot"
        _info "  Retry: sudo sysctl --system"
    end
    return 0
end
function _post_tmpfiles --argument-names target --description "Post-hook: apply tmpfiles.d entry immediately (avoid reboot dependency)"
    _echo
    if not command -q systemd-tmpfiles; _warn "systemd-tmpfiles(8) not found — entries will apply on next boot via systemd-tmpfiles-setup.service"; return 0; end
    if not _run sudo -n systemd-tmpfiles --create -- "$target"; _warn "systemd-tmpfiles --create $target failed — entries not applied until reboot"; _info "  Retry: sudo systemd-tmpfiles --create -- $target"; end
    return 0
end
function _post_envd --argument-names target --description "Post-hook: notify session restart needed for environment.d"
    _info "environment.d $target changed — log out and back in (or restart user session) to apply"
    _info "  Active systemd --user services retain old environment until restarted"
    return 0
end
function _post_cpupower --argument-names target --description "Post-hook: restart cpupower.service after /etc/default/cpupower-service.conf change"
    _echo
    if not _run sudo -n systemctl restart cpupower.service
        _warn "cpupower.service restart failed — governor change applies on next boot"
        _info "  Under amd_pstate=active, governor=performance routes to EPP=performance internally"
    end
    return 0
end
function _pre_dispatch_log_cleanup --description "Remove pre-dispatch log file/dir (no exit; for caller-managed return paths)"
    set -l _preserve false
    set -q _RY_HEADER_WRITTEN; and test "$_RY_HEADER_WRITTEN" = true; and set _preserve true
    set -q _RY_LOG_WRITTEN; and test "$_RY_LOG_WRITTEN" = true; and set _preserve true
    test "$_preserve" = false; and command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -- "$LOG_DIR" 2>/dev/null
    command rmdir -- (command dirname -- "$LOG_DIR") 2>/dev/null
    command rmdir -- "$_RY_HOME_DIR" 2>/dev/null
    # Suppress _log lazy-create; prevents orphan 90-byte log on argparse error.
    set -g _RY_LOG_SUPPRESS_CREATE true
end
function _pre_dispatch_exit --argument-names code --description "Pre-dispatch teardown: log/dir cleanup, then exit"
    _pre_dispatch_log_cleanup
    _ry_exit $code
end
function _early_usage_exit --description "Print usage error to stderr, remove pre-dispatch log, exit EXIT_USAGE"
    echo "[ERR] $argv" >&2
    echo >&2
    _ry_show_help >&2
    _pre_dispatch_exit $EXIT_USAGE
end

set -g MODE install; set -g INSTALL_FILE_TARGET ""; set -l _ORIG_ARGV $argv; set -l _ap_errfile (_mktemp_or_null -p (_tmp_dir) ry-argparse-err.XXXXXX)
_track_tmpfile "$_ap_errfile"
argparse --name=(status basename) \
    --exclusive=verify-static,verify-runtime,check,install-file \
    h/help v/version V/verbose \
    verify-static verify-runtime check install-file= \
    -- $argv 2>"$_ap_errfile"
set -l _argparse_rc $status
if test $_argparse_rc -ne 0
    set -l _ap_msg ""
    if test "$_ap_errfile" = /dev/null
        set _ap_msg "(argparse error message unavailable: tmpfile alloc failed)"
    else if test -s "$_ap_errfile"
        set _ap_msg (command head -n 3 -- "$_ap_errfile" 2>/dev/null | string join -- '; ' | string trim --)
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
set -q _flag_verify_static; and set -g MODE verify-static
set -q _flag_verify_runtime; and set -g MODE verify-runtime
set -q _flag_check; and set -g MODE check
if set -q _flag_install_file
    set -g MODE install-file; set -l _if_val "$_flag_install_file"
    test -z "$_if_val"; and _early_usage_exit "--install-file requires a non-empty absolute path"
    if not string match -q -- '/*' "$_if_val"
        if string match -qr -- '^--(verify-static|verify-runtime|check|verbose|help|version)$' "$_if_val"
            _early_usage_exit "--install-file requires a value, but the next argument is the flag $_if_val. Use --install-file=<path> or place the path immediately after"
        else if string match -q -- '-*' "$_if_val"
            _early_usage_exit "--install-file requires an absolute path argument (got flag: $_if_val). Use --install-file=<path> for paths starting with '-'"
        else
            _early_usage_exit "--install-file requires absolute path (got: $_if_val)"
        end
    end
    set -l _canon (command realpath -m -- "$_if_val" 2>/dev/null)
    if test -n "$_canon"
        set -g INSTALL_FILE_TARGET "$_canon"
    else
        echo "[WARN] realpath -m failed on '$_if_val' — using literal path; managed-file validation may not match" >&2
        set -g INSTALL_FILE_TARGET "$_if_val"
    end
end
if test (count $argv) -gt 0; echo "[ERR] Unexpected positional argument: $argv[1]" >&2; echo >&2; _ry_show_help >&2; _pre_dispatch_exit $EXIT_USAGE; end
if test "$MODE" = check
    # --check ignores -V (silent-probe contract).
else if set -q _flag_verbose; or test "$MODE" != install
    set -g QUIET false
end
set -l mode_label $MODE
# Rename preflight-*.jsonl → MODE-*.jsonl once MODE is known; orphan recreation plugged by _RY_LOG_SUPPRESS_CREATE.
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"; set -l old_log "$LOG_FILE"; set -l _log_rename_ok true
if test -f "$old_log"; and test "$old_log" != "$new_log"
    if not command mv -- "$old_log" "$new_log" 2>/dev/null; set _log_rename_ok false; echo "[WARN] Log rename failed: $old_log -> $new_log (keeping old path)" >&2; end
end
test "$_log_rename_ok" = true; and set -g LOG_FILE "$new_log"
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
set -l _argv_parts
set -l _argv_in (status filename) $_ORIG_ARGV
for _r in $_argv_in; set -a _argv_parts '"'(_json_str "$_r")'"'; end
set -l _argv_json '['(string join -- ',' $_argv_parts)']'
set -l _verbose_json false
test "$QUIET" = false; and set _verbose_json true
set -l _hdr_fmt '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","verbose":%s,"argv":%s}\n'
printf "$_hdr_fmt" (command date '+%Y-%m-%dT%H:%M:%S%z') "$VERSION" "$PROFILE_NAME" "$MODE" "$_verbose_json" "$_argv_json" >>"$LOG_FILE" 2>/dev/null
if test $status -eq 0
    set -g _RY_HEADER_WRITTEN true
else
    set -g _RY_LOG_WRITE_FAIL true
end
if set -q _RY_PERM_FIX_NOTICES
    for _n in $_RY_PERM_FIX_NOTICES; _log "$_n"; end
    set --erase _RY_PERM_FIX_NOTICES _n
end
if set -q _RY_DEFERRED_WARNS
    for _w in $_RY_DEFERRED_WARNS; _warn "$_w"; _log "DEFERRED_WARN: $_w"; end
    set --erase _RY_DEFERRED_WARNS _w
end
_init_runtime
switch $MODE
    case install-file install
        _acquire_lock; or _pre_dispatch_exit $EXIT_LOCK
    case '*'
end
set -g _RY_EXIT_CODE 0
switch $MODE
    case verify-static
        _ry_verify_static
        set -g _RY_EXIT_CODE $status
    case verify-runtime
        _ry_verify_runtime
        set -g _RY_EXIT_CODE $status
    case check
        _ry_do_check
        set -g _RY_EXIT_CODE $status
    case install-file
        _ry_do_install_file "$INSTALL_FILE_TARGET"
        set -g _RY_EXIT_CODE $status
    case install
        _ry_do_install
        set -g _RY_EXIT_CODE $status
    case '*'
        _msg_print --force ERR "Unknown mode: $MODE"
        _log "ERR: Unknown mode: $MODE"
        set -g _RY_EXIT_CODE $EXIT_USAGE
end
set -g _INTENDED_EXIT_CODE $_RY_EXIT_CODE
_write_footer "$_RY_EXIT_CODE" ""
set -q _RY_LOG_WRITE_FAIL; and test "$_RY_LOG_WRITE_FAIL" = true; and echo "[WARN] Log writes failed during this run — JSONL may be incomplete (check disk space / file permissions on $LOG_FILE)" >&2
test "$MODE" != check; and echo "[i] Log file: $LOG_FILE" >&2
exit $_RY_EXIT_CODE
