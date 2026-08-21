#!/usr/bin/env fish
# ry-verify v7.177.2 — CachyOS config manager for the Beelink GTR9 Pro (gfx1151)
if contains -- (status filename) - 'Standard input'; or string match -qr -- '^(/dev/(stdin|fd/0)|/proc/self/fd/0)$' (status filename); or status stack-trace | string match -q '*from sourcing*'; echo "[ERR] ry-verify: must be executed as a file, not sourced or piped (use ./ry-verify.fish)" >&2; return 1; end

# ── HEADER: VERSION + EXIT CODES + PROFILE CONSTANTS ──
set -g VERSION "7.177.2"; set -g EXIT_OK 0; set -g EXIT_FAIL 1; set -g EXIT_USAGE 2; set -g EXIT_PREFLIGHT 3; set -g EXIT_BOOT_CRIT 4; set -g EXIT_LOCK 5; set -g EXIT_DRIFT 10
set -g EXIT_GEN_NOFN 11; set -g EXIT_GEN_NOUUID 12; set -g EXIT_GEN_SYSCTL 13; set -g EXIT_GEN_ENVD 14 # internal gen-fail sentinels (fn return only)
set -g EXIT_RUN_TMPFAIL 251 # internal sentinel (fn return only)
set -g EXIT_AS_MISUSE 250; set -g EXIT_RUN_MISUSE 255 # internal sentinels, never a process exit
set -g _RY_TS_FMT '+%Y-%m-%dT%H:%M:%S.%3N%z'
set -g PACTREE_TIMEOUT_S 60
set -g PROFILE_NAME gtr9_pro; set -g PROFILE_DESC "Beelink GTR9 Pro - Ryzen AI Max+ 395 / Radeon 8060S"; set -g _RY_MANAGED_FILE_COUNT 17
set -g _RY_PHASE_NAMES Preflight Packages Configuration Services Boot Finalize
set -g -- _RY_ARGPARSE_SPEC --exclusive=verify,check h/help v/version verify check # single option-spec source (root guard + main argparse)

# ── HELP TEXT ──
function _ry_show_help --description "Display usage information and available subcommands"
    printf '%s\n' \
        "" \
        "ry-verify v$VERSION" \
        "Self-contained CachyOS configuration for $PROFILE_DESC" \
        "Paired with ry-install.fish; $_RY_MANAGED_FILE_COUNT embedded configs, no bundled dependencies." \
        "Usage: "(status filename)" [OPTIONS]" \
        "  (no args)              Same as --verify" \
        "  --verify               Check config files + live system state" \
        "  --check                Silent idempotency probe (0=clean 3=preflight 10=drift)" \
        "                         (compares the live /proc/cmdline — a fresh install reads 10 until reboot)" \
        "  --                     End of options (no positional arguments accepted)" \
        "  -h, --help             Show this help (honored before all checks)" \
        "  -v, --version          Show version (honored before all checks)" \
        "EXIT CODES: 0 ok · 1 verify-FAIL · 2 usage · 3 preflight · 10 --check drift" \
        "  (sentinels 11-14/250/251/255 are internal; signals exit 128+N)" \
        "ENVIRONMENT (see README.md for detail):" \
        "  RY_INSTALL_SKIP_HARDWARE_CHECK=1  Bypass EXPECTED_CPU_MATCH hard-fail." \
        "  NO_COLOR              Disable colored output when set non-empty (no-color.org)." \
        "Log: ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl" \
        "Backups: ~/ry-install/backups/<slash-encoded path>.ry.bak" \
        ""
end

# ── EARLY ARG INTERCEPT: -h/-v BEFORE ROOT GUARD ──
set -l _skip_if_val false
for _early_arg in $argv
    if test "$_skip_if_val" = true; set _skip_if_val false; continue; end # --install-file value: defer to argparse
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
            if string match -qr -- '^-[hvV]+$' "$_early_arg" # glued h/v/V only; first h/v wins (getopt order)
                for _early_ch in (string split '' -- (string sub -s 2 -- "$_early_arg"))
                    test "$_early_ch" = h; and begin; _ry_show_help; exit $EXIT_OK; end
                    test "$_early_ch" = v; and begin; echo "v$VERSION"; exit $EXIT_OK; end
                end
            end
    end
end
set -q _early_arg; and set --erase _early_arg
set -q _early_ch; and set --erase _early_ch
set --erase _skip_if_val

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

# ── BAIL PRIMITIVES: _RY_EXIT + _SET_EXIT + HANDLER ERASE ──
function _ry_erase_handlers --description "Erase signal/exit handler functions"; functions -e _cleanup _cleanup_pipe _cleanup_on_exit _progress_on_winch 2>/dev/null; end
function _ry_exit --argument-names code --description "Set bail sentinel and exit"
    test -z "$code"; and set code 0
    string match -qr '^\d+$' -- "$code"; or set code $EXIT_FAIL # non-numeric breaks footer printf %d
    if set -q _RY_INSTALL_BAILING; and test "$_RY_INSTALL_BAILING" = true; set -g _RY_INSTALL_LAST_EXIT $code; exit $code; end
    set -g _CLEANUP_DONE true; set -g _RY_INSTALL_LAST_EXIT $code; set -g _RY_INSTALL_BAILING true
    if not set -q _RY_HEADER_WRITTEN; and not set -q _RY_LOG_WRITTEN
        set -q LOG_FILE; and command rm -f -- "$LOG_FILE" 2>/dev/null
        set -q LOG_DIR; and command rmdir -- "$LOG_DIR" 2>/dev/null; set -q _RY_BACKUP_DIR; and command rmdir -- "$_RY_BACKUP_DIR" 2>/dev/null
        set -q LOG_DIR; and command rmdir -- (command dirname -- "$LOG_DIR") 2>/dev/null
        set -q HOME; and command rmdir -- "$HOME/ry-install" 2>/dev/null
    else
        functions -q _write_footer; and _write_footer "$code" bail
    end
    functions -q _do_cleanup; and _do_cleanup
    _ry_erase_handlers
    exit $code
end
function _set_exit --argument-names _code --description "Set both _RY_EXIT_CODE and _INTENDED_EXIT_CODE atomically"; set -g _RY_EXIT_CODE $_code; set -g _INTENDED_EXIT_CODE $_code; end
function _ry_root_usage --description "Root-guard usage error: print msg + help to stderr, exit EXIT_USAGE"; echo "[ERR] $argv" >&2; echo >&2; _ry_show_help >&2; _ry_exit $EXIT_USAGE; end

# ── ROOT GUARD + COLOR/TTY + FISH VERSION CHECK ──
set -g QUIET true; set -g MODE bootstrap # pinned pre-argparse for signal footers
if not string match -qr '^\d+$' -- "$_MY_UID"; echo "[ERR] id -u returned non-numeric value: '$_MY_UID' — cannot determine user identity" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -l _ry_root_silent_check false; set -l _rsc_skip false; set -l _rsc_other_mode false; set -l _rsc_after_dd false # --check silent contract holds on root-refusal path
for _rsc_a in $argv
    if test "$_rsc_skip" = true; set _rsc_skip false; continue; end # a literal --check path is not the flag
    if test "$_rsc_after_dd" = true; set _rsc_other_mode true; break; end # positional after --: exit-2 parity
    switch "$_rsc_a"
        case --
            set _rsc_after_dd true
        case --install-file
            set _rsc_skip true; set _rsc_other_mode true
        case '--install-file=*' --verify
            set _rsc_other_mode true
        case --check
            set _ry_root_silent_check true
        case '*'
            set _rsc_other_mode true # unknown flag/positional: non-root exits 2 — keep parity
    end
end
set -q _rsc_a; and set --erase _rsc_a
set --erase _rsc_skip _rsc_after_dd
set -g _RY_ARGV_CHECK_ONLY false # pre-argparse hint: --check silence must hold before MODE is set
test "$_ry_root_silent_check" = true; and test "$_rsc_other_mode" = false; and set -g _RY_ARGV_CHECK_ONLY true
if test "$_MY_UID" -eq 0
    if test "$_ry_root_silent_check" = true; and test "$_rsc_other_mode" = false; _ry_exit $EXIT_PREFLIGHT; end # --check + valid mode: silent, 3 = cannot probe
    set -l _rg_msgout (begin; argparse --name=(command basename -- (status filename)) $_RY_ARGPARSE_SPEC -- $argv 2>&1 >/dev/null; echo "@@RC@@$status"; end) # parity argparse in subshell; parent argv intact
    set -l _rg_prc 0; set -l _rg_msg ""
    for _rg_l in $_rg_msgout
        if string match -q '@@RC@@*' -- "$_rg_l"; set _rg_prc (string replace '@@RC@@' '' -- "$_rg_l"); else if test -z "$_rg_msg"; set _rg_msg (string replace -ra '\e\[[0-9;]*[a-zA-Z]' '' -- "$_rg_l" | string trim --); end
    end
    set -l _rg_state (begin; argparse --name=ry-install $_RY_ARGPARSE_SPEC -- $argv 2>/dev/null; for _rg_p in $argv; echo "@@LEFT@@$_rg_p"; end; set -q _flag_install_file; and echo "@@IF@@$_flag_install_file"; end) # one @@LEFT@@ per leftover; display-only
    set -l _rg_left; set -l _rg_if_present false; set -l _rg_if_val ""
    for _rg_l in $_rg_state
        if string match -q '@@LEFT@@*' -- "$_rg_l"; set -a _rg_left "$_rg_l"; else if string match -q '@@IF@@*' -- "$_rg_l"; set _rg_if_present true; set _rg_if_val (string replace '@@IF@@' '' -- "$_rg_l"); end # LEFT before IF; prefix stripped later
    end
    if test "$_rg_prc" -ne 0; test -n "$_rg_msg"; or set _rg_msg "Invalid arguments: $argv"; _ry_root_usage "$_rg_msg"; end
    if test "$_rg_if_present" = true; and test -z "$_rg_if_val"; _ry_root_usage "--install-file requires a non-empty absolute path"; end
    if test (count $_rg_left) -gt 0; set -l _rg_disp (string replace -r -- '^@@LEFT@@' '' $_rg_left); _ry_root_usage "Unexpected positional argument(s): $_rg_disp"; end
    set -q _rg_l; and set --erase _rg_l
    set -q _rg_p; and set --erase _rg_p
    echo "[ERR] "(command basename -- (status filename))" must not run as root. Run as your normal user; sudo is invoked internally." >&2
    _ry_exit $EXIT_USAGE
end
set --erase _ry_root_silent_check _rsc_other_mode
set -g _RY_NO_COLOR false
test "$TERM" = dumb; and set -g _RY_NO_COLOR true
set -q NO_COLOR; and test -n "$NO_COLOR"; and set -g _RY_NO_COLOR true # no-color.org: non-empty value disables color
set -l fish_ver $FISH_VERSION; set -l parts (string split '.' -- "$fish_ver"); set -l _fish_minor (string replace -r '[^0-9].*' '' -- "$parts[2]"); test -z "$_fish_minor"; and set _fish_minor 0
if not string match -qr '^\d+$' -- "$parts[1]"; or not string match -qr '^\d+$' -- "$_fish_minor"; echo "[ERR] fish version unparseable: '$fish_ver'" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -l _fish_ok 0
test "$parts[1]" -gt 3; and set _fish_ok 1
test "$parts[1]" -eq 3; and test "$_fish_minor" -ge 6; and set _fish_ok 1
if test "$_fish_ok" -eq 0; echo "[ERR] fish 3.6+ required (found: $fish_ver)" >&2; _ry_exit $EXIT_PREFLIGHT; end
set --erase fish_ver parts _fish_minor _fish_ok

# ── TMP ROOT (PINNED /tmp) + COREUTILS PROBES ──
set -q TMPDIR; and set --erase TMPDIR # pin tmp to /tmp; children must not honor inherited TMPDIR
if not test -w /tmp; echo "[ERR] tmp dir not writable: /tmp" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command -q timeout; echo "[ERR] GNU coreutils timeout(1) required (used for hang-protection)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command timeout --foreground --kill-after=1 1 true 2>/dev/null; echo "[ERR] timeout(1) lacks --foreground/--kill-after (need GNU coreutils ≥ 8.x; busybox/uutils not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command -q find; echo "[ERR] GNU findutils find(1) required (tmpfile sweeps + boot-entry enumeration)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command find /dev/null -maxdepth 0 -printf '' 2>/dev/null; echo "[ERR] find(1) lacks -maxdepth/-printf (need GNU findutils; busybox/uutils not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
set -l _ry_mv_a (command mktemp 2>/dev/null); set -l _ry_mv_b (command mktemp 2>/dev/null)
if test -z "$_ry_mv_a"; or test -z "$_ry_mv_b"; command rm -f -- "$_ry_mv_a" "$_ry_mv_b" 2>/dev/null; echo "[ERR] mktemp(1) failed — cannot allocate probe files for the mv -T capability check (tmp dir probed writable above; check inode/space limits)" >&2; _ry_exit $EXIT_PREFLIGHT; end
if not command mv -T -- "$_ry_mv_a" "$_ry_mv_b" 2>/dev/null; command rm -f -- "$_ry_mv_a" "$_ry_mv_b" 2>/dev/null; echo "[ERR] mv(1) lacks -T no-target-directory (need GNU coreutils ≥ 8.x; busybox not supported)" >&2; _ry_exit $EXIT_PREFLIGHT; end
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
set -g _RY_HOME_DIR "$HOME/ry-install"; set -g LOG_DIR "$_RY_HOME_DIR/logs/$DATE_LABEL"; set -g _RY_BACKUP_DIR "$_RY_HOME_DIR/backups"
set -l _prev_mkdir_umask 022; set -q umask; and set _prev_mkdir_umask $umask # umask var directly; autoloaded umask(1) leaks to stderr
set -g umask 0077
command mkdir -p -- "$LOG_DIR" "$_RY_BACKUP_DIR" 2>/dev/null; or begin
    set -g umask $_prev_mkdir_umask
    echo "[ERR] Cannot create log/backup directory: $LOG_DIR $_RY_BACKUP_DIR" >&2
    _ry_exit $EXIT_PREFLIGHT
end
set -g umask $_prev_mkdir_umask
for _ld_path in "$_RY_HOME_DIR" "$_RY_HOME_DIR/logs" "$LOG_DIR" "$_RY_BACKUP_DIR"
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
set -g _RY_BACKUP_TARGETS $_RY_BOOT_CRITICAL_DSTS; set -g _RY_BACKUP_SUFFIX .ry.bak
set -g _RY_TMPDIR_GLOBS "ry-sudo-err.$fish_pid.*" "ry-tee-err.$fish_pid.*" "ry-run.$fish_pid.*" "ry-argparse-err.$fish_pid.*" "ry-fstab-tee-err.$fish_pid.*" "ry-fstab-awk-err.$fish_pid.*" # PID-scoped: never touch a peer run's files
set -g _TRACKED_TMPFILES; set -g _SYS_TMP_DIRS; set -g _USR_TMP_DIRS; set -g _RY_PHASE_RESULTS
set -g _RY_DEPLOY_CHANGED_COUNT 0; set -g _RY_DEPLOY_IDEMPOTENT_COUNT 0; set -g _RY_DEPLOY_CHANGED_DSTS; set -g _RY_PROFILE_USES_WIFI_BACKEND false
set -g SYSTEM_UPGRADED false # cross-phase global (set install-side)
set -g _RY_AWK_EXT4_FILTER '!/^[ \t]*#/ && NF >= 4 && $3 == "ext4" { print $0 }'
set -g _RY_AWK_EXT4_MALFORMED_FILTER '!/^[ \t]*#/ && NF < 4 && $0 ~ /(^|[ \t,])ext4([ \t,]|$)/ { print $0 }'
set -g NM_RESTART_DELAY 3; set -g _PROG_BAR_WIDTH 40

# ── KERNEL / SYSTEMD STATE PROBES ──
function _kconfig_cache --description "Load /proc/config.gz into _KCONFIG_DATA (lazy; empty when unavailable)"
    if not set -q _KCONFIG_LOADED
        if test -f /proc/config.gz; and command -q zcat
            set -g _KCONFIG_DATA (command zcat /proc/config.gz 2>/dev/null)
        else
            set -g _KCONFIG_DATA
        end
        set -g _KCONFIG_LOADED true
    end
    return 0
end
function _ntsync_state --description "Return: builtin|loaded|loaded_nodev|missing"
    _kconfig_cache # list membership avoids a builtin→pipe SIGPIPE
    if contains -- CONFIG_NTSYNC=y $_KCONFIG_DATA
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
function _unit_state_padded --argument-names unit --description "Return LoadState/ActiveState/UnitFileState as exactly 3 lines" # pads on systemctl error; keeps $rec[1..3] in-bounds
    set -l _v (command systemctl show --value --property=LoadState,ActiveState,UnitFileState -- "$unit" 2>/dev/null)
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
    set -g _FOOTER_WRITTEN true; set -l _mode_esc (_json_str "$MODE"); set -l _ts (command date $_RY_TS_FMT); set -l _extra ""
    test -n "$extra_key"; and set _extra ",\""(_json_str "$extra_key")"\":true"
    set -l _gen_fail 0
    set -q VERIFY_GEN_FAIL; and set _gen_fail $VERIFY_GEN_FAIL
    printf '{"ts":"%s","event":"footer","mode":"%s","exit_code":%d,"pass":%d,"fail":%d,"warn":%d,"gen_fail":%d%s}\n' "$_ts" "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" "$_gen_fail" "$_extra" >>"$LOG_FILE" 2>/dev/null
    test "$status" -ne 0; and not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true
end
function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    not set -q _FOOTER_WRITTEN; and functions -q _log; and _log "CLEANUP_TMPFILES: sweep starting" # signals may precede _log
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
# mkdir+pidfile lock; live/ambiguous PID fails closed

# ── CLEANUP ORCHESTRATION: REVERT → TMPFILES → CHILDREN → GLOBALS ──
function _dc_mki_revert --description "_do_cleanup sub: Signal-time mkinitcpio.conf revert"
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
function _dc_sweep_filesystem --description "_do_cleanup sub: Sweep tmp root for leftover ry-* tmpfiles"
    functions -q _tmp_dir; or return 0
    set -l _tmpdir (_tmp_dir); set -l _tmp_globs $_RY_TMPDIR_GLOBS
    test (count $_tmp_globs) -gt 0; or return 0
    set -l _find_name_args
    for _g in $_tmp_globs; test -n "$_find_name_args"; and set -a _find_name_args -o; set -a _find_name_args -name "$_g"; end
    command find "$_tmpdir" -xdev -maxdepth 1 \( $_find_name_args \) -type f -uid "$_MY_UID" -delete 2>/dev/null
    for _rd in "$_tmpdir"/ry-run.$fish_pid.* # per-dir descent keeps glob metachars literal
        test -d "$_rd"; and command find "$_rd" -xdev -maxdepth 1 -type f -uid "$_MY_UID" -delete 2>/dev/null
    end
    command find "$_tmpdir" -xdev -maxdepth 1 -name "ry-run.$fish_pid.*" -type d -empty -uid "$_MY_UID" -delete 2>/dev/null
end
function _dc_erase_globals --description "_do_cleanup sub: Erase cached globals"
    set --erase _KCONFIG_DATA _KCONFIG_LOADED _RY_ESP_PATH _RY_BOOT_PATH
    set --erase _RY_ESP_TRIED _RY_BOOT_TRIED
    set --erase _RY_SYSTEMD_VER _RY_SYSTEMD_VER_TRIED
    set --erase _RY_BOOT_COUNT _RY_BOOT_ENUM_OK _CPU_PATH
    set --erase _RY_CANON_SYSTEM_DSTS _RY_CANON_USER_DSTS _SYS_TMP_DIRS _USR_TMP_DIRS
    set --erase _RY_PROFILE_USES_WIFI_BACKEND _RY_ESP_FALLBACK
    set --erase _RY_MKI_REVERT_FAILED _RY_PACTREE_MISSING_WARNED _RY_REALPATH_ABSENT_WARNED
    set --erase _RY_RUN_TIMEOUT_WARNED _RY_RUN_TIMEOUT_CLAMPED _PROG_CLOCK _PROG_NOW_LAST _RY_HOLDS_LOCK _RY_LOCK_DIR_OWNED _RY_LOCK_MKDIR_OK
    set --erase _RY_PKG_REMOVE_SKIPS _RY_BOOT_TAINTED _RY_PKGS_REMOVED_COUNT _RY_PKG_REMOVE_DBLOCK
    set --erase _RY_PHASE_RESULTS _RY_DEPLOY_CHANGED_COUNT _RY_DEPLOY_IDEMPOTENT_COUNT _RY_DEPLOY_CHANGED_DSTS _RY_BOOT_CRIT_HIT _RY_DEPLOY_TAG
    set --erase _RY_MTX_PASS _RY_MTX_WARN _RY_MTX_FAIL _RY_MTX_DEFER _RY_MTX_SKIP _RY_MTX_NA
    set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES _RY_SYSCTL_BAD_ENTRIES _RY_ENVD_BAD_ENTRIES _RY_FSTAB_EVIDENCE _RY_FSTAB_RESULT
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
    test -f /var/lib/pacman/db.lck; and set _grace 100 # pkg txn: up to 10s grace; only -P $fish_pid descendants
    for _gi in (seq $_grace)
        command -q pgrep; or begin; command sleep 0.5 </dev/null 2>/dev/null; break; end
        test (count (command pgrep -P "$fish_pid" 2>/dev/null)) -eq 0; and break
        command sleep 0.1 </dev/null 2>/dev/null
    end
    command -q pgrep; and test (count (command pgrep -P "$fish_pid" 2>/dev/null)) -eq 0; and return 0 # no children: skip KILL
    command pkill -KILL -P "$fish_pid" 2>/dev/null
end

# ── CLEANUP: MASTER ORCHESTRATOR (_do_cleanup) ──
function _do_cleanup --description "Master cleanup: reap children → revert → tmpfiles → fs sweep → lock release → globals"
    _dc_kill_children # quiesce children first: revert must not race live pacman
    _dc_mki_revert
    _dc_sweep_tmpfiles
    _dc_sweep_filesystem
    _dc_release_lock # sweeps run while the lock is still held
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
    set -l _sig_silent false # --check stays stderr-silent even before argparse sets MODE
    test "$MODE" = check; and set _sig_silent true
    test "$MODE" = bootstrap; and set -q _RY_ARGV_CHECK_ONLY; and test "$_RY_ARGV_CHECK_ONLY" = true; and set _sig_silent true
    if not set -q _RY_OUTPUT_BROKEN; and test "$_sig_silent" = false
        echo "" >&2
        echo "[WARN] Caught $_sig_label - cleaning up..." >&2
    end
    set -l _sig_name (string replace -r '^SIG' '' -- "$_sig_label")
    set -l _sig_exit ""
    for _sm in HUP:129 INT:130 QUIT:131 TERM:143 ABRT:134 # 128+N per signal
        string match -q "$_sig_name:*" -- $_sm; and set _sig_exit (string split ':' -- $_sm)[2]; and break
    end
    if test -z "$_sig_exit"
        functions -q _log; and _log "CLEANUP_UNKNOWN_SIGNAL: argv[1]='$argv[1]' fallback_exit=130"
        set _sig_exit 130
    end
    _teardown signal $_sig_exit
    _ry_erase_handlers # fish swallows handler exit status; exec sh re-raises 128+N
    string match -qr '^[A-Z]+$' -- "$_sig_name"; and exec /bin/sh -c "kill -$_sig_name \$\$ 2>/dev/null; exit $_sig_exit"
    exit $_sig_exit # fallback: non-signal label or exec failure
end
function _cleanup_pipe --on-signal PIPE --description "Signal handler: mark stderr/stdout broken"; set -q _RY_OUTPUT_BROKEN; and return 0; set -g _RY_OUTPUT_BROKEN true; set -q _RY_HEADER_WRITTEN; or return 0; _log "SIGPIPE_RECEIVED: stderr/stdout consumer closed; continuing with JSONL log only"; end
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

# ── EMBEDDED CONFIG: DESTINATIONS (_content_ fns + _RY_POST_HOOKS mirror order) ──
set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" "/etc/kernel/cmdline" "/etc/sdboot-manage.conf" "/etc/mkinitcpio.conf" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf" "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/iw-regdomain" "/etc/bluetooth/main.conf" "/etc/nftables.conf" "/etc/default/cpupower-service.conf" \
    "/etc/sysctl.d/95-ry-overrides.conf" "/etc/udev/rules.d/99-ry-perf.rules" "/etc/modprobe.d/60-ry-modules.conf"
set -g USER_DESTINATIONS "$HOME/.config/environment.d/10-environment.conf" "$HOME/.config/MangoHud/MangoHud.conf"
set -l _ry_dst_count (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS)
if test "$_ry_dst_count" -ne "$_RY_MANAGED_FILE_COUNT"; echo "[ERR] _RY_MANAGED_FILE_COUNT drift: declared=$_RY_MANAGED_FILE_COUNT computed=$_ry_dst_count" >&2; _ry_exit $EXIT_PREFLIGHT; end
set --erase _ry_dst_count

# ── EMBEDDED DATA: BOOTLOADER KEYS + KERNEL_PARAMS + MKINITCPIO ──
set -g LOADER_DEFAULT "@saved"; set -g LOADER_TIMEOUT 0; set -g LOADER_CONSOLE_MODE keep; set -g LOADER_EDITOR no
set -g SDBOOT_DEFAULT_ENTRY manual; set -g SDBOOT_OVERWRITE yes; set -g SDBOOT_REMOVE_EXISTING yes; set -g SDBOOT_REMOVE_OBSOLETE yes
set -g KERNEL_PARAMS amd_pstate=active btusb.enable_autosuspend=n fsck.mode=auto fsck.repair=yes iommu=pt ipv6.disable=1 mt7925e.disable_aspm=1 nvme_core.default_ps_max_latency_us=0 pcie_aspm.policy=performance processor.max_cstate=1 quiet split_lock_detect=off usbcore.autosuspend=-1 zswap.enabled=0
set -g MKINITCPIO_MODULES amdgpu
set -g MKINITCPIO_HOOKS base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck
set -g MKINITCPIO_COMPRESSION zstd; set -g MKINITCPIO_COMPRESSION_OPTIONS -3 # mkinitcpio prepends -T0 for zstd

# ── EMBEDDED DATA: SERVICE KEYS ──
set -g RESOLVED_MDNS no; set -g RESOLVED_LLMNR no
set -g NM_DISPATCHER_LOGLEVELMAX notice # drop info-level dispatcher spam, keep notice+
set -g COUNTRY US
set -g LOGIND_IGNORE_KEYS HandlePowerKey HandlePowerKeyLongPress HandleSuspendKey HandleSuspendKeyLongPress HandleHibernateKey HandleHibernateKeyLongPress HandleRebootKey HandleRebootKeyLongPress
set -g NM_WIFI_BACKEND wpa_supplicant; set -g NM_WIFI_POWERSAVE 2; set -g NM_LOG_LEVEL WARN # Wi-Fi PS off: MT7925/mt76 PS in software causes latency spikes
set -g CPUPOWER_GOVERNOR performance
set -g BT_AUTO_ENABLE true; set -g BT_FAST_CONNECTABLE true; set -g BT_RECONNECT_ATTEMPTS 3 # adapter auto-power-on; paired-sink reconnect retries
set -g GPU_DPM_LEVEL high # gfx1151 dpm; high pins clocks, gating stays active
set -g _RY_DPM_LEVELS auto low high manual profile_standard profile_min_sclk profile_min_mclk profile_peak perf_determinism # power_dpm_force_performance_level accepted set
set -g EPP_PREFERENCE performance; set -g _RY_EPP_LEVELS default performance balance_performance balance_power power # accepted set; udev-pinned per CPU; blocked if dynamic_epp on
set -g EXPECTED_SCALING_DRIVER amd-pstate-epp # verify-only: scaling_driver under amd_pstate=active
set -g BLACKLIST_AMDXDNA false # false + iommu=pt enables the NPU

# ── EMBEDDED DATA: ENV_VARS + SYSCTL_VALUES ──
set -g ENV_VARS "DXVK_LOG_LEVEL=none" "FSR4_WATERMARK=1" "GSK_RENDERER=ngl" "MANGOHUD=1" "MESA_SHADER_CACHE_MAX_SIZE=16G" "POWERDEVIL_NO_DDCUTIL=1" "PROTON_LOCAL_SHADER_CACHE=1" "VKD3D_DEBUG=none" "VKD3D_SHADER_DEBUG=none" "WINEDEBUG=-all"
# max_map_count=esync
set -g SYSCTL_VALUES "kernel.nmi_watchdog=0" "net.core.default_qdisc=fq" "net.ipv4.tcp_congestion_control=bbr" "net.ipv4.tcp_notsent_lowat=16384" "net.ipv4.tcp_slow_start_after_idle=0" "vm.compaction_proactiveness=0" "vm.max_map_count=2147483642" "vm.watermark_boost_factor=0"

# ── EMBEDDED DATA: PACKAGES (ADD / DEL / VULKAN) ──
set -g PKGS_ADD \
    nvme-cli cachyos-gaming-meta cachyos-gaming-applications cachyos-benchmarker lib32-mesa mkinitcpio-firmware fd sd dust procs \
    bottom htop lm_sensors rtkit realtime-privileges nftables pacman-contrib # pacman-contrib: pactree + paccache
set -g PKGS_DEL plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update kdeconnect
set -g EXPECTED_VULKAN_PKGS vulkan-radeon lib32-vulkan-radeon # chwd Vulkan drivers

# ── EMBEDDED DATA: UNITS (MASK / EXPECTED) + THRESHOLDS ──
set -g MASK ananicy-cpp.service power-profiles-daemon.service NetworkManager-wait-online.service avahi-daemon.service avahi-daemon.socket ufw.service sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target # avahi+resolved: mDNS off by design; ufw: nft owns the ruleset
set -g EXPECTED_SERVICES fstrim.timer NetworkManager.service cpupower.service nftables.service bluetooth.service # enabled in Phase 4/6
set -g _RY_PKG_MANAGED_SERVICES NetworkManager.service
set -g BOOT_SPACE_CRIT 200; set -g BOOT_SPACE_WARN 500; set -g ROOT_AVAIL_CRIT 2; set -g ROOT_AVAIL_WARN 5 # disk thresholds
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
        case install-file # only cmdline embeds root=UUID
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
        KERNEL_PARAMS:14 \
        MKINITCPIO_HOOKS:11 \
        MKINITCPIO_MODULES:1 \
        LOGIND_IGNORE_KEYS:8 \
        ENV_VARS:10 \
        SYSCTL_VALUES:8 \
        PKGS_ADD:17 \
        PKGS_DEL:9 \
        MASK:11 \
        EXPECTED_VULKAN_PKGS:2 \
        EXPECTED_SERVICES:5 \
        _RY_PKG_MANAGED_SERVICES:1 \
        _RY_POST_HOOKS:17 \
        _RY_ARGPARSE_SPEC:5 \
        _RY_BOOT_CRITICAL_DSTS:4 \
        _RY_PHASE_NAMES:6 \
        _RY_BACKUP_TARGETS:4 \
        _RY_TMPDIR_GLOBS:6 \
        SYSTEM_DESTINATIONS:15 \
        USER_DESTINATIONS:2 \
        MKINITCPIO_COMPRESSION_OPTIONS:1 # drift tripwires; sync arrays + docs on change
    for _kv in $_expect
        set -l _parts (string split -m1 ':' -- "$_kv"); set -l _name $_parts[1]; set -l _want $_parts[2]; set -l _got (count $$_name)
        if test "$_got" -ne "$_want"; _err_loud "$_name count drift: got=$_got expected=$_want — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
function _ir_validate_keys --description "Refuse deploy on out-of-domain embedded scalar keys"
    for _k in BT_AUTO_ENABLE BT_FAST_CONNECTABLE BLACKLIST_AMDXDNA
        if not contains -- "$$_k" true false; _err_loud "$_k must be true|false (got: '$$_k') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _k in SDBOOT_OVERWRITE SDBOOT_REMOVE_EXISTING SDBOOT_REMOVE_OBSOLETE RESOLVED_MDNS RESOLVED_LLMNR
        if not contains -- "$$_k" yes no; _err_loud "$_k must be yes|no (got: '$$_k') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _k in LOADER_TIMEOUT NM_WIFI_POWERSAVE BT_RECONNECT_ATTEMPTS
        if not string match -qr '^\d+$' -- "$$_k"; _err_loud "$_k must be a non-negative integer (got: '$$_k') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    if not string match -qr '^[A-Z][A-Z]$' -- "$COUNTRY"; _err_loud "COUNTRY must be an ISO-3166-1 alpha-2 code (got: '$COUNTRY') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    if string match -qr '^(AA|Q[M-Z]|X[A-Z]|ZZ)$' -- "$COUNTRY"; _err_loud "COUNTRY '$COUNTRY' is in the ISO-3166-1 user-assigned/reserved range (AA, QM-QZ, XA-XZ, ZZ) — not a real country code; would silently fall back to world regdomain. Refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    if not contains -- "$GPU_DPM_LEVEL" $_RY_DPM_LEVELS; _err_loud "GPU_DPM_LEVEL must be one of "(string join '|' -- $_RY_DPM_LEVELS)" (got: '$GPU_DPM_LEVEL') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end # value is interpolated unquoted into udev ATTR
    if not contains -- "$EPP_PREFERENCE" $_RY_EPP_LEVELS; _err_loud "EPP_PREFERENCE must be one of "(string join '|' -- $_RY_EPP_LEVELS)" (got: '$EPP_PREFERENCE') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end # value is interpolated unquoted into udev ATTR
    if not string match -qr '^[a-z][a-z0-9_-]*$' -- "$CPUPOWER_GOVERNOR"; _err_loud "CPUPOWER_GOVERNOR must match ^[a-z][a-z0-9_-]*\$ (got: '$CPUPOWER_GOVERNOR') — refuse to deploy (the domain _grep_cpupower_entry accepts)"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    if contains -- /etc/nftables.conf $SYSTEM_DESTINATIONS; and not contains -- ipv6.disable=1 $KERNEL_PARAMS # base ICMPv6 is accepted; service rules are not
        _warn "Dual-stack: the ruleset accepts only the ICMPv6 base set — add service-specific IPv6 rules to /etc/nftables.conf"
    end
    if test "$BLACKLIST_AMDXDNA" = false; and contains -- amd_iommu=off $KERNEL_PARAMS # amdxdna probes -ENODEV (-19) without the IOMMU
        _err_loud "BLACKLIST_AMDXDNA=false requires the IOMMU (drop amd_iommu=off; set iommu=pt) — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT
    end
    for _k in LOADER_DEFAULT LOADER_CONSOLE_MODE LOADER_EDITOR SDBOOT_DEFAULT_ENTRY NM_WIFI_BACKEND NM_LOG_LEVEL CPUPOWER_GOVERNOR NM_DISPATCHER_LOGLEVELMAX MKINITCPIO_COMPRESSION EXPECTED_SCALING_DRIVER
        if test -z "$$_k"; _err_loud "$_k must be non-empty — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    set -l _scalar_metachar_re '[\s"`$;\\\\&|<>(){}*?\x27~!#]' # shell metachar class for scalars written to boot configs
    for _k in MKINITCPIO_COMPRESSION SDBOOT_DEFAULT_ENTRY LOADER_DEFAULT LOADER_CONSOLE_MODE LOADER_EDITOR CPUPOWER_GOVERNOR
        if string match -qr -- "$_scalar_metachar_re" "$$_k"; _err_loud "$_k contains whitespace, quote, or shell metachar: '$$_k' — refuse to deploy (would corrupt a shell-sourced or parser-read boot config)"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _co in $MKINITCPIO_COMPRESSION_OPTIONS # spliced into a shell array literal; flag charset only
        if not string match -qr -- '^-?[A-Za-z0-9]+$' "$_co"; _err_loud "MKINITCPIO_COMPRESSION_OPTIONS token invalid: '$_co' — refuse to deploy (spliced into a shell-sourced array literal)"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _kp in $KERNEL_PARAMS # spliced into boot configs; charset excludes shell metachars
        if not string match -qr -- '^[A-Za-z0-9._,=-]+$' "$_kp"; _err_loud "KERNEL_PARAMS token invalid: '$_kp' — refuse to deploy (spliced into a shell-sourced boot config and the kernel cmdline)"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end
function _ir_validate_sets --description "Refuse deploy when add and remove sets contradict each other"
    for _p in $PKGS_ADD # phase 2 installs, phase 4 -Rns removes: verify would assert both
        if contains -- "$_p" $PKGS_DEL; _err_loud "'$_p' is in both PKGS_ADD and PKGS_DEL — phase 4 would remove what phase 2 installed; refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _u in $EXPECTED_SERVICES # phase 4 masks before it enables: enable would fail
        if contains -- "$_u" $MASK; _err_loud "'$_u' is in both MASK and EXPECTED_SERVICES — phase 4 masks before it enables; refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _u in $_RY_PKG_MANAGED_SERVICES
        if contains -- "$_u" $MASK; _err_loud "'$_u' is in both MASK and _RY_PKG_MANAGED_SERVICES — a masked unit cannot be package-managed; refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end

# ── RUNTIME INIT: ORCHESTRATOR (_init_runtime) ──
function _init_runtime --description "Cache root UUID + validate config + precompute caches"
    _ir_resolve_root_uuid
    if set -q EXPECTED_CPU_MATCH; and test -n "$EXPECTED_CPU_MATCH"
        set -l _cpu_model (string match -rg -- '^model name\s*:\s*(.*)$' (command cat -- /proc/cpuinfo 2>/dev/null))[1]
        if test -z "$_cpu_model"
            if test "$RY_INSTALL_SKIP_HARDWARE_CHECK" = 1 # fail-closed: empty model requires override
                _warn_loud "Hardware check (override): CPU model unreadable from /proc/cpuinfo — proceeding"
                _log "HARDWARE_MODEL_UNREADABLE_OVERRIDE: /proc/cpuinfo missing 'model name'"
            else if test "$MODE" = verify # read-only: warn and continue
                _warn "Hardware check: CPU model unreadable from /proc/cpuinfo — verify continues; deploy would refuse"
                _log "HARDWARE_MODEL_UNREADABLE_VERIFY: /proc/cpuinfo missing 'model name'"
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
            else if test "$MODE" = verify # read-only: warn and continue
                _warn "Hardware mismatch: expected $EXPECTED_CPU_MATCH, detected: $_cpu_model — verify continues; deploy would refuse"
                _log "HARDWARE_MISMATCH_VERIFY: expected=$EXPECTED_CPU_MATCH detected=$_cpu_model"
            else
                _err_loud "Hardware mismatch: profile $PROFILE_NAME expects $EXPECTED_CPU_MATCH, detected: $_cpu_model"
                _err_loud_cont "  Deploying gfx1151/Strix Halo defaults on non-matching CPU would set incorrect kernel cmdline + initramfs MODULES."
                _err_loud_cont "  Override (at your risk): RY_INSTALL_SKIP_HARDWARE_CHECK=1 ./ry-install.fish"
                _pre_dispatch_exit $EXIT_PREFLIGHT
            end
        end
    end
    _ir_validate_counts
    _ir_validate_keys
    _ir_validate_sets
    _ir_validate_post_hooks
    for _bt in $_RY_BACKUP_TARGETS; if string match -q '*/sysctl.d/*' -- "$_bt"; _err_loud "_RY_BACKUP_TARGETS member '$_bt' uses a side-effecting content generator — _awf_postwrite_verify_restore re-run would mutate run state; refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end; end
    _ir_precompute_caches
    for _pn in $PKGS_ADD $PKGS_DEL
        if string match -q -- '-*' "$_pn"; _err_loud "Package name starts with dash: '$_pn' — pacman would parse as flag, refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end

# ── CONTENT GENERATORS: BOOT (loader, cmdline, sdboot-manage, mkinitcpio) ──
function _content__boot_loader_loader.conf --description "Generate content for /boot/loader/loader.conf"; printf '%s\n' "# systemd-boot loader configuration" "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"; end
function _content__etc_kernel_cmdline --description "Generate content for /etc/kernel/cmdline"; test -z "$_ROOT_UUID"; and return $EXIT_GEN_NOUUID; printf '%s %s\n' "rw root=UUID=$_ROOT_UUID" (string join -- " " $KERNEL_PARAMS); end
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
    if set -q MKINITCPIO_COMPRESSION_OPTIONS; and test (count $MKINITCPIO_COMPRESSION_OPTIONS) -gt 0; printf '%s\n' "COMPRESSION_OPTIONS=("(string join -- " " $MKINITCPIO_COMPRESSION_OPTIONS)")"; end
end

# ── CONTENT GENERATORS: SYSTEM (resolved, logind, NM, bluetooth, nft, sysctl, udev) ──
function _content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf --description "Generate content for systemd-resolved drop-in"; printf '%s\n' "# systemd-resolved: link DNS from DHCP, mDNS/LLMNR off" "[Resolve]" "MulticastDNS=$RESOLVED_MDNS" "LLMNR=$RESOLVED_LLMNR"; end
function _content__etc_systemd_logind.conf.d_99-cachyos-logind.conf --description "Generate content for systemd-logind drop-in"
    printf '%s\n' "# systemd-logind configuration — desktop power handling"
    printf '%s\n' "[Login]"
    for key in $LOGIND_IGNORE_KEYS
        printf '%s\n' "$key=ignore"
    end
end
function _content__etc_systemd_system_NetworkManager-dispatcher.service.d_logging.conf --description "Generate content for NetworkManager-dispatcher logging drop-in (journal noise suppression)"; printf '%s\n' "# LogLevelMax drops info-level dispatcher lines (journald-logged; StandardError=null ineffective)" "[Service]" "LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX"; end
function _content__etc_NetworkManager_conf.d_99-cachyos-nm.conf --description "Generate content for NetworkManager drop-in (wifi.backend from NM_WIFI_BACKEND)"
    printf '%s\n' "# NetworkManager configuration — $NM_WIFI_BACKEND backend" "[main]" "autoconnect-retries-default=0" "" "[device]" "wifi.backend=$NM_WIFI_BACKEND" "" "[connection]" "wifi.powersave=$NM_WIFI_POWERSAVE" "" "[logging]" "level=$NM_LOG_LEVEL"
end
function _content__etc_iw-regdomain --description "Generate content for /etc/iw-regdomain (CachyOS regdomain input)"; printf '%s\n' "# ry-install: wireless regulatory domain (managed file, do not edit by hand)" "COUNTRY=$COUNTRY"; end
function _content__etc_bluetooth_main.conf --description "Generate content for /etc/bluetooth/main.conf (adapter auto-power-on + paired-sink reconnect)"
    printf '%s\n' "# ry-install: BlueZ daemon config (managed file, do not edit by hand)" "[General]" "FastConnectable=$BT_FAST_CONNECTABLE" "" "[Policy]" "AutoEnable=$BT_AUTO_ENABLE" "ReconnectAttempts=$BT_RECONNECT_ATTEMPTS"
end
function _content__etc_nftables.conf --description "Generate content for nftables default-deny-inbound ruleset"
    printf '%s\n' \
        "#!/usr/bin/nft -f" \
        "# ry-install: default-deny-inbound (ufw masked). ICMPv6 is live on the fallback entry. Add inbound ports below." \
        "flush ruleset" \
        "table inet filter {" \
        "    chain input {" \
        "        type filter hook input priority filter; policy drop;" \
        "        ct state invalid drop # early drop of invalid connections" \
        "        ct state established,related accept" \
        "        iif \"lo\" accept" \
        "        # IPv4 ICMP: inbound ping (echo-request) + error/PMTUD types (replies match ct established)" \
        "        icmp type { echo-request, destination-unreachable, time-exceeded, parameter-problem } accept" \
        "        # ICMPv6: NDP, MLD, and error/PMTUD types (RFC 4890 host minimum); live on the fallback entry" \
        "        icmpv6 type { echo-request, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert, mld-listener-query } accept"
    printf '%s\n' \
        "    }" \
        "    chain forward { type filter hook forward priority filter; policy drop; }" \
        "    chain output { type filter hook output priority filter; policy accept; }" \
        "}"
end
function _content__etc_default_cpupower-service.conf --description "Generate content for cpupower-service.conf"; printf '%s\n' "# cpupower-service.conf — sourced by /usr/lib/systemd/scripts/cpupower (cpupower.service)" "GOVERNOR='$CPUPOWER_GOVERNOR'"; end
function _content__etc_sysctl.d_95-ry-overrides.conf --description "Generate content for sysctl drop-in"
    printf '%s\n' "# ry-install sysctl tunables (priority 95 — loaded after CachyOS vendor 70-cachyos-settings.conf)"
    set -l _printed 0; set -g _RY_SYSCTL_BAD_ENTRIES
    for entry in $SYSCTL_VALUES
        if not string match -qr '^\s*[A-Za-z0-9._-]+\s*=\s*\S' -- "$entry"; set -ga _RY_SYSCTL_BAD_ENTRIES "$entry"; functions -q _log; and _log "SYSCTL_SKIP_MALFORMED: '$entry' (require key=value, key charset [A-Za-z0-9._-])"; continue; end
        if string match -qr '[\x00-\x1f\x7f]' -- "$entry"; set -ga _RY_SYSCTL_BAD_ENTRIES "$entry"; functions -q _log; and _log "SYSCTL_SKIP_CTRLCHAR: entry contains control character (newline/CR/etc) — refuse to emit"; continue; end
        set -l parts (string split -m1 '=' -- "$entry"); set -l key (string trim -- "$parts[1]"); set -l val (string trim -- "$parts[2]")
        printf '%s = %s\n' "$key" "$val"
        set _printed (math $_printed + 1)
    end
    if test "$_printed" -ne (count $SYSCTL_VALUES); functions -q _log; and _log "SYSCTL_COUNT_MISMATCH: printed=$_printed expected="(count $SYSCTL_VALUES); return $EXIT_GEN_SYSCTL; end
end
function _content__etc_udev_rules.d_99-ry-perf.rules --description "Generate content for combined udev perf rules"
    printf '%s\n' \
        "# ry-install: udev performance rules (managed file, do not edit by hand)" \
        "# NVMe scheduler none (lowest tail latency; diverges from CachyOS kyber default)" \
        'ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="none"' \
        "# AMD P-State EPP performance (maximum CPPC hint)" \
        'ACTION=="add|change", SUBSYSTEM=="cpu", KERNEL=="cpu[0-9]*", ATTR{cpufreq/energy_performance_preference}="'$EPP_PREFERENCE'"' \
        "# GPU performance level (gfx1151 clock-floor; forced high)" \
        'ACTION=="add", KERNEL=="card[0-9]*", SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="'$GPU_DPM_LEVEL'"'
end
function _content__etc_modprobe.d_60-ry-modules.conf --description "Generate content for /etc/modprobe.d/60-ry-modules.conf (optional amdxdna blacklist)"
    printf '%s\n' \
        "# ry-install: module options + blacklist (managed file, do not edit by hand)"
    if test "$BLACKLIST_AMDXDNA" = true # false = NPU path (see BLACKLIST_AMDXDNA global)
        printf '%s\n' \
            "# blacklist amdxdna: XDNA NPU needs IOMMU, probes -ENODEV (ret -19) under amd_iommu=off" \
            "blacklist amdxdna"
    else
        printf '%s\n' \
            "# no directives: BLACKLIST_AMDXDNA=false (NPU path); MT7925 ASPM handled on the kernel command line"
    end
end

# ── CONTENT GENERATORS: USER ($HOME dotfiles; environment.d + MangoHud) ──
function _content_HOME_.config_environment.d_10-environment.conf --description "Generate content for ~/.config/environment.d/10-environment.conf"
    printf '%s\n' "# Environment for systemd --user services and graphical sessions (Plasma, Flatpak, D-Bus apps)"
    set -l _printed 0; set -g _RY_ENVD_BAD_ENTRIES
    for var in $ENV_VARS
        if not string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- "$var"; set -ga _RY_ENVD_BAD_ENTRIES "$var"; functions -q _log; and _log "ENVD_SKIP_MALFORMED: '$var' (require KEY=value, KEY charset [A-Za-z_][A-Za-z0-9_]*)"; continue; end
        if string match -qr '[\x00-\x1f\x7f]' -- "$var"; set -ga _RY_ENVD_BAD_ENTRIES "$var"; functions -q _log; and _log "ENVD_SKIP_CTRLCHAR: entry contains control character (newline/CR/etc) — refuse to emit"; continue; end
        printf '%s\n' "$var"
        set _printed (math $_printed + 1)
    end
    if test "$_printed" -ne (count $ENV_VARS); functions -q _log; and _log "ENVD_COUNT_MISMATCH: printed=$_printed expected="(count $ENV_VARS); return $EXIT_GEN_ENVD; end
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
        "gpu_temp" \
        "gpu_core_clock" \
        "gpu_power" \
        "# cpu_stats intentionally disabled — enable for CPU load in the HUD" \
        "# cpu_temp intentionally disabled — enable if you want CPU temperature in the HUD" \
        "# cpu_custom_temp_sensor is inert here — MangoHud reads apu_cpu_temp from gpu_metrics before any hwmon lookup" \
        "cpu_mhz" \
        "cpu_power" \
        "vram" \
        "ram" \
        "font_size=20" \
        "text_outline" \
        "background_alpha=0.4"
end

# ── CONTENT DISPATCH (_ry_get_file_content; fn name derived via _content_fn_for) ──
function _content_fn_for --argument-names dst --description "Resolve the _content_ generator function name for a destination"; echo "_content_"(_tmpfile_key "$dst"); end
function _ry_get_file_content --argument-names dst --description "Generate expected content for a destination (dispatcher)"; set -l fn (_content_fn_for "$dst"); functions -q $fn; or return $EXIT_GEN_NOFN; $fn; end

# ── SUDO CREDENTIAL CACHE + COMMAND ESCALATION ──
function _ensure_sudo_cached --description "Cache sudo credential once before repeated sudo -n calls"
    if not command -q sudo; _err "sudo credential cache failed: sudo not found"; return 1; end
    set -l _sudo_err (_mktemp_or_null -p (_tmp_dir) "ry-sudo-err.$fish_pid.XXXXXX")
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
    set -l _pfx (string sub -l (math $_hlen + 1) -- "$p" | string collect)
    if test "$p" = "$HOME"
        set p HOME
    else if test "$_pfx" = "$HOME/"
        set p "HOME"(string sub -s (math $_hlen + 1) -- "$p")
    end
    string replace -a / _ -- "$p"
end
function _ry_bak_path --argument-names dst --description "Slash-encoded .ry.bak path for dst under _RY_BACKUP_DIR"; string join '' -- "$_RY_BACKUP_DIR/" (string replace -a / _ -- "$dst") "$_RY_BACKUP_SUFFIX"; end
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
function _track_tmpfile --argument-names path --description "Track a tmpfile/dir in _TRACKED_TMPFILES"; test -n "$path"; or return 0; test "$path" = /dev/null; and return 0; set -ga _TRACKED_TMPFILES "$path"; end
function _mktemp_or_null --description "Wrapper for mktemp; emits path on stdout, /dev/null sentinel on failure"
    set -l _tf (command mktemp $argv 2>/dev/null)
    if test -z "$_tf"; echo /dev/null; functions -q _log; and _log "MKTEMP_OR_NULL_FAIL: args='$argv' — falling back to /dev/null sentinel"; return 0; end
    echo "$_tf"
    return 0
end
function _tmp_dir --description "Tmp root (pinned /tmp)"; printf '%s' /tmp; end

# ── FILESYSTEM PROBES (symlink, system-dst, byte read) ──
function _is_system_dst --argument-names dst --description "True if dst is a system path (requires sudo to read)"; string match -q '/etc/*' -- "$dst"; or string match -q '/boot/*' -- "$dst"; end
function _installed_bytes --argument-names dst --description "Raw bytes of installed file" # callers read $pipestatus[1] only
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
    for _hex in 01 02 03 04 05 06 07 0b 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 7f; set s (string replace -ar -- '\x'$_hex '\\\\u00'$_hex "$s" | string collect); end # NUL omitted: fish strings can't hold NUL
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
        set -l _prev_umask 022; set -q umask; and set _prev_umask $umask
        set -g umask 0177
        command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
        set -l _create_rc $status
        set -g umask $_prev_umask
        if test "$_create_rc" -ne 0; not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true; return 0; end
    end
    set -l _ts (command date $_RY_TS_FMT); set -l raw (string join -- " " $argv | string collect); set -l data (_json_str "$raw") # collect keeps embedded \n for _json_str
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
function _msg_nocount --argument-names level --description "Like _msg but skips VERIFY_* counter bump"; set -l msg (string join -- " " $argv[2..-1]); test -z "$msg"; and return 0; _log "$level: $msg"; _msg_print $argv; end
function _ok --description "Emit OK-level message and increment VERIFY_OK"; _msg OK $argv; return 0; end # always return 0 (callers chain via and)
function _fail --description "Emit FAIL-level message and increment VERIFY_FAIL"; _msg FAIL $argv; return 0; end
function _info --description "Emit INFO-level message (no counter)"; _msg INFO $argv; return 0; end
function _warn --description "Emit WARN-level message and increment VERIFY_WARN"; _msg WARN $argv; return 0; end

# ── MESSAGING: LOUD EMITTERS (_err, _err_loud, _warn_loud; bypass QUIET) ──
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
function _err_loud --description "Fatal-preflight err: stderr regardless of QUIET, except MODE=check (silent-probe contract)"; set -l msg (string join -- " " $argv); _log "ERR: $msg"; set -q VERIFY_FAIL; and set -g VERIFY_FAIL (math $VERIFY_FAIL + 1); test "$MODE" = check; and return 0; _msg_print --force ERR $argv; end
function _err_loud_cont --description "Continuation for _err_loud: same routing, no VERIFY_FAIL bump"; set -l msg (string join -- " " $argv); _log "ERR: $msg"; test "$MODE" = check; and return 0; _msg_print --force ERR $argv; end
function _warn_loud --description "Override-path warn: stderr regardless of QUIET, except MODE=check (silent-probe contract)" # mirrors _err_loud
    set -l msg (string join -- " " $argv)
    _log "WARN: $msg"
    set -q VERIFY_WARN; and set -g VERIFY_WARN (math $VERIFY_WARN + 1)
    test "$MODE" = check; and return 0
    _msg_print --force WARN $argv
end
function _echo --description "Print a plain message without level prefix"; set -q argv[1]; and _log "ECHO: $argv"; if test "$QUIET" = false; and not set -q _RY_OUTPUT_BROKEN; printf '%s\n' (string join ' ' -- $argv) >&2; end; end

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
function _progress_teardown --description "Clear pinned progress bar and reset scroll region (signal/abort path)"
    set -q _RY_OUTPUT_BROKEN; and set -g _PROG_PINNED false # SIGPIPE seen: skip terminal writes
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
    if test "$_new_rows" -lt 10; set -g _PROG_ROWS $_new_rows; _progress_teardown; return 0; end # <10 rows: tear down (mirrors init)
    set -l _new_cols (command tput cols 2>/dev/null)
    if string match -qr '^\d+$' -- "$_new_cols"; and test "$_new_cols" -lt 64; set -g _PROG_ROWS $_new_rows; _progress_teardown; return 0; end # <64 cols: tear down (mirrors init)
    set -g _PROG_ROWS $_new_rows
    printf '\e[s\e[1;%dr\e[u' (math $_PROG_ROWS - 1) >&2
    _progress_redraw "$_PROG_STEP_NAME" $_PROG_CUR
end

# ── GENERIC CHECK HELPERS (file, perms, sysfs) ──
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
function _chk_sysfs_eq --argument-names path expected label --description "Read sysfs/proc, compare to expected (silent on missing path)"; test -f "$path"; or return 0; set -l _val (command cat -- "$path" 2>/dev/null | string trim --); _chk_eq "$label" "$_val" "$expected"; end
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
    if not sudo -n true 2>/dev/null; _warn "  $label: sudo cache lapsed — re-run ry-verify"; return 1; end
    if not sudo -n test -f "$file" 2>/dev/null; _fail "  $label: FILE NOT FOUND"; return 1; end
    return 0
end

# ── CHECK HELPERS: GREP/TOKEN (sudo-aware file-content assertions) ──
function _chk_grep --argument-names file pattern label --description "Verify a file contains an expected token"
    test -z "$label"; and set label "$pattern"
    _log "CHECK_GREP: file=$file pattern=$pattern"
    set -l use_sudo false
    string match -q '/boot/*' -- "$file"; and set use_sudo true
    if test "$use_sudo" = false; and not test -r "$file"; and _is_system_dst "$file"; set use_sudo true; end # sudo read avoids false DENIED on perms drift
    _cg_access_ok "$file" "$label" $use_sudo; or return 1
    set -l _grep_flags -wF
    _as $use_sudo awk '{ sub(/[[:space:]]+#.*$/, "") } /^[[:space:]]*#/ { next } NF { print; f=1 } END { exit f ? 0 : 1 }' "$file" 2>/dev/null | command grep $_grep_flags -- "$pattern" >/dev/null 2>/dev/null # strips comments; rc 1 = no content (grep -v parity)
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
function _vmh_order_checks --description "_ry_validate_mkinitcpio_hooks sub: Hook ordering"
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

# ── ATOMIC FILE INSTALL: RENDER → SYMLINK CHECK → CHMOD → MV -T ──
function _ry_mkinitcpio_array --argument-names key file --description "Last KEY=... assignment from a conf file; multi-line KEY=( ... ) joined"
    test -z "$file"; and set file /etc/mkinitcpio.conf
    set -l _awk 'BEGIN{n=0}
$0 ~ "^[[:space:]]*"K"=" {c=1; buf=$0; n++; if (buf !~ /\(/ || buf ~ /\)/) {last=buf; c=0}; next}
c {buf=buf" "$0; if ($0 ~ /\)/) {last=buf; c=0}}
END{if (n>0) printf "%d\n%s\n", n, last}'
    set -l _out
    if test -r "$file"
        set _out (command awk -v K="$key" "$_awk" "$file" 2>/dev/null)
    else
        set _out (sudo -n awk -v K="$key" "$_awk" "$file" 2>/dev/null)
    end
    test (count $_out) -ge 2; or return 0 # no assignment, or sole block unterminated
    test "$_out[1]" -gt 1 2>/dev/null; and _warn "  $file: multiple $key= assignments ($_out[1]) — using last (conf is shell-sourced)"
    printf '%s\n' (string join ' ' -- $_out[2..-1] | string replace -ra '\s+' ' ' | string trim --)
end
function _ry_content_bytes --argument-names dst --description "Raw bytes of embedded content" # pipestatus[1]=gen rc
    set -l _content (_ry_get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines --allow-empty); set -l _ps $pipestatus
    test "$_ps[1]" -ne 0; and return "$_ps[1]"
    printf '%s' "$_content"
end
function _ry_mode_drift --argument-names dst use_sudo perms --description "Emit the current mode when it differs from the managed contract, else nothing"
    string match -q '/boot/*' -- "$dst"; and return 1 # vfat synthesizes modes from mount options
    set -l _cur (_as $use_sudo stat -c '%a' -- "$dst" 2>/dev/null | string trim --); test -z "$_cur"; and return 1
    test "$_cur" = (string replace -r '^0+(?=.)' '' -- "$perms"); and return 1
    printf '%s' "$_cur"
end

# ── VERIFY-STATIC: BOOT (LOADER + SDBOOT) ──
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
    for _kv in "OVERWRITE_EXISTING:$SDBOOT_OVERWRITE" "REMOVE_EXISTING:$SDBOOT_REMOVE_EXISTING" "REMOVE_OBSOLETE:$SDBOOT_REMOVE_OBSOLETE" "DEFAULT_ENTRY:$SDBOOT_DEFAULT_ENTRY"
        set -l _p (string split -m1 ':' -- $_kv)
        _chk_grep /etc/sdboot-manage.conf "$_p[1]=\"$_p[2]\"" "$_p[1]=$_p[2]"
    end
    _chk_grep /etc/sdboot-manage.conf 'LINUX_FALLBACK_OPTIONS="quiet"' "LINUX_FALLBACK_OPTIONS=quiet"
end

# ── VERIFY-STATIC: BOOT (SDBOOT DROP-INS + CMDLINE) ──
function _vsb_sdboot_dropins --description "_verify_static_boot sub: sdboot-manage drop-ins that outrank the managed conf"
    _echo "── sdboot-manage drop-ins ──"
    set -l _found
    for _dir in /usr/lib/sdboot-manage.conf.d /etc/sdboot-manage.conf.d
        test -d "$_dir"; or continue
        set -a _found (command find "$_dir" -maxdepth 1 -type f -name '*.conf' 2>/dev/null)
    end
    if test (count $_found) -eq 0
        _ok "  no sdboot-manage drop-ins present"; return 0
    end
    _warn "  "(count $_found)" sdboot-manage drop-in(s) sourced after /etc/sdboot-manage.conf — they override LINUX_OPTIONS: $_found"
    _log "SDBOOT_DROPIN_PRESENT: "(string join ',' -- $_found)
end
function _vsb_cmdline --description "_verify_static_boot sub: cmdline KERNEL_PARAMS + root=UUID + rw"
    _echo "── kernel cmdline ──"
    _chk_file /etc/kernel/cmdline; or return 0
    set -l cmdline_content (command cat -- /etc/kernel/cmdline 2>/dev/null)
    test -z "$cmdline_content"; and set cmdline_content (sudo -n cat -- /etc/kernel/cmdline 2>/dev/null)
    if test -z "$cmdline_content"
        if not sudo -n true 2>/dev/null; _warn "  /etc/kernel/cmdline: sudo cache lapsed — cannot determine content"; return 0; end
        _fail "  /etc/kernel/cmdline: empty or unreadable"; return 0
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

# ── VERIFY-STATIC: BOOT (MKINITCPIO + ENTRIES + ORCHESTRATOR) ──
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
    if string match -q "*$MKINITCPIO_COMPRESSION*" -- "$comp_line"
        _ok "  COMPRESSION=$MKINITCPIO_COMPRESSION: present"
    else
        _fail "  COMPRESSION=$MKINITCPIO_COMPRESSION: MISSING"
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
function _vsb_entry_options --description "_vsb_entries sub: Assert each non-fallback loader entry carries every KERNEL_PARAMS token"
    for _e in $argv
        set -l _n (command basename -- "$_e")
        string match -qr -- '-fallback\.conf$' "$_n"; and continue # sdboot-manage names them *-fallback.conf
        set -l _opts (_as true awk '/^[ \t]*options[ \t]/ { sub(/^[ \t]*options[ \t]+/, ""); print; exit }' "$_e" 2>/dev/null | string trim --)
        if test -z "$_opts"; _warn "  $_n: no options line — cannot compare against KERNEL_PARAMS"; continue; end
        set -l _missing
        for _p in $KERNEL_PARAMS
            string match -qr -- '(^|\s)'(string escape --style=regex -- "$_p")'(\s|$)' "$_opts"; or set -a _missing "$_p"
        end
        if test (count $_missing) -eq 0
            _ok "  $_n: all "(count $KERNEL_PARAMS)" kernel params present"
        else
            _fail "  $_n: missing "(count $_missing)": $_missing"
        end
    end
end
function _vsb_entries --description "_verify_static_boot sub: \$BOOT entries enumeration + count check"
    _echo "── Boot entries ──"
    set -l _boot (_resolve_boot_path)
    if test -z "$_boot"; _warn "  Boot entries: cannot resolve \$BOOT path (bootctl/findmnt failed) — skipping"; return 0; end
    set -l entry_count 0; set -l _entries_pipe_ok true; set -l _entries_dir_probed false; set -l _entries
    if sudo -n test -d "$_boot/loader/entries" 2>/dev/null
        set _entries_dir_probed true
        set _entries (sudo -n find "$_boot/loader/entries" -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null | string split0); set -l _ps $pipestatus
        test "$_ps[1]" -eq 0; or set _entries_pipe_ok false
        set entry_count (count $_entries)
    else if not sudo -n true 2>/dev/null
        _warn "  Boot entries: sudo cache lapsed — cannot enumerate $_boot/loader/entries"; return 0
    end
    if test "$_entries_pipe_ok" = false
        _warn "  Boot entries: cannot enumerate $_boot/loader/entries (sudo lapsed or read error)"
    else if test "$_entries_dir_probed" = false
        _fail "  Boot entries: $_boot/loader/entries/ does not exist"; _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    else if test "$entry_count" -gt 0
        _ok "  Boot entries: $entry_count found"
        _vsb_entry_options $_entries
    else
        _fail "  Boot entries: NONE in $_boot/loader/entries/"; _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    end
end
function _verify_static_boot --description "Verify loader.conf, sdboot-manage, kernel cmdline, mkinitcpio, boot entries"; _echo "BOOT CONFIGURATION"; _vsb_loader; _vsb_sdboot; _vsb_sdboot_dropins; _vsb_cmdline; _vsb_mkinitcpio; _vsb_entries; end

# ── VERIFY-STATIC: SYSTEM + USER (drop-ins, env.d) ──
function _vss_logind --description "_verify_static_system sub: logind.conf.d keys"
    _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf; or return 0
    for key in $LOGIND_IGNORE_KEYS
        _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
    end
end
function _vss_nmdispatch --description "_verify_static_system sub: NetworkManager-dispatcher logging drop-in"; _chk_file /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf; or return 0; _chk_grep /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf "LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX" "dispatcher LogLevelMax=$NM_DISPATCHER_LOGLEVELMAX"; end
function _vss_nm --description "_verify_static_system sub: NetworkManager config"
    _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf; or return 0
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "autoconnect-retries-default=0" "autoconnect retries unlimited"
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
function _vss_regdom --description "_verify_static_system sub: Wireless regdom (/etc/iw-regdomain)"; _echo "── wireless regdom (iw-regdomain) ──"; _chk_file /etc/iw-regdomain; and _chk_grep /etc/iw-regdomain "COUNTRY=$COUNTRY" "iw-regdomain COUNTRY=$COUNTRY"; end
function _vss_bluetooth --description "_verify_static_system sub: BlueZ main.conf (adapter auto-power-on)"
    _echo "── bluetooth (main.conf) ──"
    _chk_file /etc/bluetooth/main.conf; or return 0
    _chk_grep /etc/bluetooth/main.conf "AutoEnable=$BT_AUTO_ENABLE"
    _chk_grep /etc/bluetooth/main.conf "FastConnectable=$BT_FAST_CONNECTABLE"
    _chk_grep /etc/bluetooth/main.conf "ReconnectAttempts=$BT_RECONNECT_ATTEMPTS"
end
function _vss_udev --description "_verify_static_system sub: Combined udev perf rules (NVMe scheduler + EPP + GPU clock-floor)"
    _echo "── udev (perf: I/O scheduler + EPP + GPU clock-floor) ──"
    _chk_file /etc/udev/rules.d/99-ry-perf.rules; or return 0
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'queue/scheduler}="none"' "nvme scheduler=none"
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'energy_performance_preference}="'$EPP_PREFERENCE'"' "EPP=$EPP_PREFERENCE"
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'power_dpm_force_performance_level}="'$GPU_DPM_LEVEL'"' "GPU dpm=$GPU_DPM_LEVEL"
    _chk_grep /etc/udev/rules.d/99-ry-perf.rules 'KERNEL=="card[0-9]*"' "GPU rule card-scoped"
end
function _vss_nft --description "_verify_static_system sub: nftables default-deny-inbound + IPv4 ping and ICMPv6 base accept"
    _chk_file /etc/nftables.conf; or return 0
    _chk_grep /etc/nftables.conf "policy drop" "nftables input policy drop"
    _chk_grep /etc/nftables.conf "echo-request" "nftables IPv4 ping accept" # regression guard: inbound ping must stay enabled
    _chk_grep /etc/nftables.conf "icmpv6 type" "nftables ICMPv6 base accept" # NDP/MLD; the fallback entry boots with IPv6 up
end
function _vss_modprobe --description "_verify_static_system sub: modprobe drop-in + unmanaged 60-ry-* sweep"
    set -l _stale (_ry_stale_ry_dropins) # same sweep --check records; one implementation, two modes
    if test (count $_stale) -gt 0
        _warn "  /etc/modprobe.d: unmanaged ry drop-in(s): $_stale — superseded by 60-ry-modules.conf; confirm with pacman -Qo, then remove"
        _log "MODPROBE_STALE_DROPIN: count="(count $_stale)" files="(string join ',' -- $_stale)
    end
    _chk_file /etc/modprobe.d/60-ry-modules.conf; or return 0
    test "$BLACKLIST_AMDXDNA" = true; and _chk_grep /etc/modprobe.d/60-ry-modules.conf 'blacklist amdxdna' 'amdxdna blacklisted'
end
function _verify_static_system --description "Verify resolved, logind, NM, regdom, bluetooth, cpupower-service.conf, sysctl, udev, modprobe"
    _echo "SYSTEM CONFIGURATION"; _echo "── resolved ──"
    if _chk_file /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        for kv in "MulticastDNS=$RESOLVED_MDNS" "LLMNR=$RESOLVED_LLMNR"; _chk_grep /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf "$kv"; end
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
    _echo "── modprobe (60-ry-modules.conf) ──"
    _vss_modprobe
    _echo "── nftables ──"
    _vss_nft
end
function _verify_static_user --description "Verify environment.d ENV_VARS + MangoHud HUD config"
    _echo "USER CONFIGURATION"
    if _chk_file "$HOME/.config/environment.d/10-environment.conf"
        for exp in $ENV_VARS; _chk_grep "$HOME/.config/environment.d/10-environment.conf" "$exp"; end
    end
    _echo "── MangoHud (readout-only HUD) ──"
    if _chk_file "$HOME/.config/MangoHud/MangoHud.conf"
        _chk_grep "$HOME/.config/MangoHud/MangoHud.conf" "fps" "MangoHud fps readout"
    end
end

# ── VERIFY-STATIC: PACKAGES + SERVICES + SYNTAX ──
function _vsp_required --description "_verify_static_packages sub: Check PKGS_ADD + Vulkan pkgs against installed list in argv"
    _echo "── Required packages ──"
    for pkg in $PKGS_ADD
        if contains -- "$pkg" $argv
            _ok "  $pkg: installed"
        else
            _fail "  $pkg: NOT INSTALLED"
        end
    end
    if set -q EXPECTED_VULKAN_PKGS; and test (count $EXPECTED_VULKAN_PKGS) -gt 0 # argv = caller-validated installed list
        _echo "── Vulkan driver packages ──"
        set -l _vk_missing
        for pkg in $EXPECTED_VULKAN_PKGS
            if contains -- "$pkg" $argv
                _ok "  $pkg: installed"
            else
                _fail "  $pkg: NOT installed (DXVK/VKD3D-Proton requires this)"
                set -a _vk_missing "$pkg"
            end
        end
        test (count $_vk_missing) -gt 0; and _info "  Install missing: sudo pacman -S --needed $_vk_missing"
    end
end
function _vsp_removed --description "_verify_static_packages sub: Check PKGS_DEL against installed; warn if still present"
    _echo "── Removed packages ──"
    for pkg in $PKGS_DEL
        if contains -- "$pkg" $argv
            _warn "  $pkg: still installed (should be removed)"
        else
            _ok "  $pkg: not installed"
        end
    end
end
function _vsp_pacman_conf --description "_verify_static_packages sub: Inspect IgnorePkg / ParallelDownloads in /etc/pacman.conf"
    _echo "── pacman.conf ──"
    if not test -f /etc/pacman.conf; _warn "  /etc/pacman.conf not found"; return 0; end
    set -l _pc_sudo false # sudo read avoids false 'not set' on 0600 conf
    if not test -r /etc/pacman.conf
        if command -q sudo; and sudo -n test -r /etc/pacman.conf 2>/dev/null
            set _pc_sudo true
        else
            _warn "  /etc/pacman.conf not readable (perms drift; sudo unavailable or cache lapsed) — IgnorePkg/ParallelDownloads inspection skipped"
            _log "PACMAN_CONF_UNREADABLE: inspection skipped"; return 0
        end
    end
    set -l ignore_lines (_as $_pc_sudo grep -E -- '^[[:space:]]*IgnorePkg' /etc/pacman.conf 2>/dev/null)
    set -l _ig_rc $status
    if test "$_ig_rc" -gt 1; _warn "  /etc/pacman.conf: read error (grep rc=$_ig_rc) — inspection skipped"; _log "PACMAN_CONF_READ_FAIL: IgnorePkg grep rc=$_ig_rc"; return 0; end
    if test "$_ig_rc" -eq 1; and test "$_pc_sudo" = true; and not sudo -n true 2>/dev/null; _warn "  /etc/pacman.conf: sudo cache lapsed during read — inspection skipped"; _log "PACMAN_CONF_SUDO_LAPSE: IgnorePkg read"; return 0; end
    if test -n "$ignore_lines"
        for line in $ignore_lines; _ok "  $line"; end
    else
        _info "  No IgnorePkg set"
    end
    set -l parallel (_as $_pc_sudo grep -E -- '^[[:space:]]*ParallelDownloads[[:space:]]*=' /etc/pacman.conf 2>/dev/null)
    set -l _pl_rc $status
    if test "$_pl_rc" -gt 1; _warn "  /etc/pacman.conf: read error (grep rc=$_pl_rc) — ParallelDownloads check skipped"; _log "PACMAN_CONF_READ_FAIL: ParallelDownloads grep rc=$_pl_rc"; return 0; end
    if test "$_pl_rc" -eq 1; and test "$_pc_sudo" = true; and not sudo -n true 2>/dev/null; _warn "  /etc/pacman.conf: sudo cache lapsed during read — ParallelDownloads check skipped"; _log "PACMAN_CONF_SUDO_LAPSE: ParallelDownloads read"; return 0; end
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
    _echo "SERVICES"; _echo "── Masked services ──"
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
    _vss_orphan_masks
end
function _vss_orphan_masks --description "_verify_static_services sub: Masked units the profile no longer declares"
    set -l _orphan (_ry_orphan_masked_units)
    test (count $_orphan) -eq 0; and return 0
    _info "  "(count $_orphan)" masked unit(s) not in MASK: $_orphan"
    _info "  Admin-scope masks only (vendor masks filtered) — unmask any this profile masked under an earlier MASK"
    _log "MASK_ORPHAN: count="(count $_orphan)" units="(string join ',' -- $_orphan)
end
function _verify_static_syntax --description "Validate live mkinitcpio HOOKS presence (multi-line HOOKS tolerated)"
    _echo "SYNTAX VALIDATION"; _echo "── mkinitcpio hooks ──"
    set -l hooks_syntax_line (_ry_mkinitcpio_array HOOKS)
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
        if test "$_gen_rc" -eq "$EXIT_GEN_NOUUID"; and test -z "$_ROOT_UUID"; _vsc_uuid_fallback "$dst"; return 0; end
        _msg_nocount FAIL "  $dst: generator failed (rc=$_gen_rc)"; set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + 1); _log "VERIFY_STATIC_GEN_FAIL: dst=$dst rc=$_gen_rc"; return 0
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
function _vsc_uuid_fallback --argument-names dst --description "_vsc_check_one sub: Compare under the root UUID carried by the installed file"
    set -l _actual (_installed_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
    if test "$pipestatus[1]" -ne 0; _warn "  $dst: checksum skipped — root UUID unresolved and file unreadable"; _log "VERIFY_STATIC_GEN_SKIP_NOUUID: dst=$dst reason=unreadable"; return 0; end
    set -l _uuid (string match -rg -- 'root=UUID=(\S+)' "$_actual")
    if test -z "$_uuid"; _warn "  $dst: checksum skipped — no root=UUID= in the installed file either"; _log "VERIFY_STATIC_GEN_SKIP_NOUUID: dst=$dst reason=no_uuid_in_file"; return 0; end
    set -l _had false; set -q _ROOT_UUID; and set _had true # generators read the global, not a caller local
    set -g _ROOT_UUID "$_uuid"
    set -l _expected (_ry_content_bytes "$dst" | string collect --no-trim-newlines --allow-empty)
    set -l _gen_rc $pipestatus[1]
    if test "$_had" = true; set -g _ROOT_UUID ""; else; set --erase _ROOT_UUID; end
    if test "$_gen_rc" -ne 0
        _msg_nocount FAIL "  $dst: generator failed under the adopted root UUID (rc=$_gen_rc)"
        set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + 1); _log "VERIFY_STATIC_GEN_FAIL: dst=$dst rc=$_gen_rc phase=nouuid_fallback"
        return 0
    end
    if test "$_expected" = "$_actual"
        _ok "  $dst: match (root UUID adopted from the file; its value unverified)"
    else
        _fail "  $dst: MISMATCH (compared under the file's own root UUID)"
    end
    _log "VERIFY_STATIC_NOUUID_FALLBACK: dst=$dst adopted_uuid=$_uuid"
end
function _vsc_backups --description "_verify_static_checksum sub: .ry.bak recovery copies non-empty; live under _RY_BACKUP_DIR"
    _echo "── recovery copies ──"
    set -l _present 0; set -l _empty
    for _dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS /etc/fstab
        set -l _cand (_ry_bak_path "$_dst")
        test -f "$_cand"; or continue
        set _present (math $_present + 1)
        test -s "$_cand"; or set -a _empty "$_cand"
    end
    if test "$_present" -eq 0
        _info "  no $_RY_BACKUP_SUFFIX copies (nothing deployed yet, or they were removed by hand)"
    else if test (count $_empty) -gt 0
        _fail "  $_RY_BACKUP_SUFFIX: "(count $_empty)" of $_present empty — unusable for recovery: $_empty"
    else
        _ok "  $_RY_BACKUP_SUFFIX: $_present present, all non-empty"
    end
    _log "BACKUP_SWEEP: suffix=$_RY_BACKUP_SUFFIX present=$_present empty="(count $_empty)
    set -l _legacy
    for _dst in $_RY_BACKUP_TARGETS /etc/fstab
        _as true test -f "$_dst$_RY_BACKUP_SUFFIX" 2>/dev/null; and set -a _legacy "$_dst$_RY_BACKUP_SUFFIX"
    end
    test (count $_legacy) -gt 0; and _info "  legacy sibling .ry.bak at the old location (left in place): $_legacy"
    set -l _stray
    for _dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS /etc/fstab
        set -l _su false; _is_system_dst "$_dst"; and set _su true
        _as $_su test -f "$_dst.ry.orig" 2>/dev/null; and set -a _stray "$_dst.ry.orig"
    end
    test (count $_stray) -gt 0; and _info "  stray .ry.orig from older releases (mechanism removed; left in place): $_stray"
    return 0
end
function _verify_static_checksum --description "Verify embedded content hash matches installed file SHA256"
    _echo "CHECKSUM VERIFICATION"; _echo
    _echo "── embedded vs installed ──"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS
        _vsc_check_one "$dst"
    end
    _vsc_backups
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
end

# ── --CHECK MODE: SILENT IDEMPOTENCY PROBE ──
function _check_phase_files --description "Check-mode phase: file content hash compare"
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
                _log "CHECK_PREFLIGHT: sudo lapse reading $dst"; return $EXIT_PREFLIGHT
            case '*'
                _log "CHECK_PREFLIGHT: _installed_bytes returned unexpected rc=$_ib_rc for $dst"; return $EXIT_PREFLIGHT
        end
        test "$expected" = "$actual"; or set -g _RY_CHECK_DRIFT 1
        set -l _mp 0644; set -l _ms true; contains -- "$dst" $USER_DESTINATIONS; and set _mp 0600; and set _ms false
        set -l _mc (_ry_mode_drift "$dst" "$_ms" "$_mp"); test -n "$_mc"; and set -g _RY_CHECK_DRIFT 1; and _log "CHECK_MODE_DRIFT: dst=$dst mode=$_mc expected=$_mp"
        set -g _RY_CHECK_FILES_CHECKED (math $_RY_CHECK_FILES_CHECKED + 1)
    end
    return 0
end
function _check_phase_cmdline --description "Check-mode phase: cmdline contains KERNEL_PARAMS + rw"
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
            _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"; return $EXIT_PREFLIGHT
        else if test "$load" = not-found
            set -g _RY_CHECK_DRIFT 1
        else
            if test "$unit" = nftables.service; and test "$active" != active # oneshot reads inactive after clean load
                if not command -q nft
                    _log "CHECK_NFT_UNPROBEABLE: nft(8) absent — live ruleset unverifiable, treating as drift (fail-closed)"
                    set -g _RY_CHECK_DRIFT 1
                else
                    _nft_input_drop_live; or set -g _RY_CHECK_DRIFT 1
                end
            else
                test "$active" = active; or set -g _RY_CHECK_DRIFT 1 # RemainAfterExit oneshots read active
            end
            test "$ufs" = enabled; or set -g _RY_CHECK_DRIFT 1
        end
    end
    return 0
end

# ── SHARED COLLECTORS: conf.d UNITS + STALE DROP-INS + ORPHAN MASKS (--check + verify) ──
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
function _ry_stale_ry_dropins --description "Unmanaged 60-ry-* modprobe drop-ins (shared: --check + static verify)"
    command find /etc/modprobe.d -maxdepth 1 -name '60-ry-*.conf' ! -name '60-ry-modules.conf' -printf '%f\n' 2>/dev/null
    return 0 # pre-7.99 leftovers: profile never wrote them, never removes them
end
function _ry_orphan_masked_units --description "Masked units absent from MASK (shared: --check + static verify)"
    set -l _raw (command systemctl list-unit-files --state=masked,masked-runtime --no-legend --plain 2>/dev/null)
    test "$status" -ne 0; and return 0 # no manager or old systemctl: report nothing, never guess
    for _line in $_raw
        set -l _u (string match -rg -- '^(\S+)' (string trim -- "$_line")) # column padding is spaces today, tabs would still parse
        test -z "$_u"; and continue
        contains -- "$_u" $MASK; and continue
        set -l _admin false
        for _d in /etc/systemd/system /run/systemd/system
            if test -L "$_d/$_u"; and test (command readlink -- "$_d/$_u") = /dev/null
                set _admin true
                break
            end
        end
        test "$_admin" = false; and continue # systemctl mask writes only to /etc or /run
        set -l _alias ""
        for _d in /usr/lib/systemd/system /lib/systemd/system
            test -L "$_d/$_u"; or continue
            set _alias (string replace -r '.*/' '' -- (command readlink -- "$_d/$_u"))
            break
        end
        test -n "$_alias"; and contains -- "$_alias" $MASK; and continue # Alias= of a masked unit
        printf '%s\n' "$_u"
    end
    return 0
end
function _check_record_orphans --description "_ry_do_check sub: Record masked-unit leftovers a re-run cannot clear; never sets drift"; set -l _orphan (_ry_orphan_masked_units); test (count $_orphan) -gt 0; and _log "MASK_ORPHAN: count="(count $_orphan)" units="(string join ',' -- $_orphan); return 0; end
function _check_phase_units --description "Check-mode phase: EXPECTED_SERVICES + MASK + conf.d-driven units"
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
    set -l _stale (_ry_stale_ry_dropins) # privilege-free: recorded before the sudo gate can bail
    test (count $_stale) -gt 0; and _log "MODPROBE_STALE_DROPIN: count="(count $_stale)" files="(string join ',' -- $_stale)
    if not command -q sudo; or not sudo -n true 2>/dev/null; _log "CHECK_PREFLIGHT: sudo not cached"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    if not command -q systemctl; _log "CHECK_PREFLIGHT: systemctl not available"; _log_section "CHECK END"; return $EXIT_PREFLIGHT; end
    _check_record_orphans # observations only, before any phase can bail
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

# ── VERIFY-RUNTIME: KERNEL CMDLINE + PARAM ACCEPTANCE + GPU + CPU ──
function _vrk_cmdline --description "_verify_runtime_kparams sub: /proc/cmdline token check"
    _echo "KERNEL CMDLINE"; _echo
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
end
function _vrk_param_rejects --description "_verify_runtime_kparams sub: Kernel parser rejections naming a managed token"
    _echo "── kernel parameter acceptance ──"
    set -l _krn
    command -q journalctl; and set _krn (command journalctl -k -b 0 --no-pager -o cat 2>/dev/null)
    if test -z "$_krn"; and command -q dmesg; set _krn (_as true dmesg 2>/dev/null); end
    if test -z "$_krn"
        _warn "  kernel ring buffer unreadable (journalctl and dmesg both empty) — token acceptance unverified"; _log "KPARAM_REJECT_SCAN_SKIP: ring buffer unreadable"
        return 0
    end
    set -l _susp (printf '%s\n' $_krn | command grep -iE -- 'unknown (option|parameter|kernel command line)|malformed early option|invalid (option|parameter)' 2>/dev/null)
    if test -z "$_susp"; _ok "  no kernel parser rejections this boot ("(count $KERNEL_PARAMS)" tokens)"; return 0; end
    set -l _hit; set -l _maybe
    for _line in $_susp
        _log "KPARAM_REJECT_LINE: $_line"
        for _p in $KERNEL_PARAMS
            set -l _parts (string split -m1 '=' -- "$_p"); set -l _key $_parts[1]; set -l _val ""
            test (count $_parts) -gt 1; and set _val $_parts[2]
            set -l _kre (string escape --style=regex -- "$_key") # dots and dashes count as token chars
            if string match -qr -- '(^|[^A-Za-z0-9_.-])'$_kre'([^A-Za-z0-9_.-]|$)' "$_line"
                contains -- "$_p" $_hit; or set -a _hit "$_p"
            else if test -n "$_val"; and begin; string match -q -- "*'$_val'*" "$_line"; or string match -q -- "*\"$_val\"*" "$_line"; end
                contains -- "$_p" $_maybe; or set -a _maybe "$_p" # message quotes the value, not the key
            end
        end
    end
    if test (count $_hit) -gt 0
        _fail "  kernel REJECTED managed token(s): "(string join ',' -- $_hit)" — inert, drop or correct them"; _log "KPARAM_REJECTED: tokens="(string join ',' -- $_hit)
    end
    if test (count $_maybe) -gt 0
        _warn "  parser complaint quotes the value of: "(string join ',' -- $_maybe)" — read the log lines and confirm"
        _log "KPARAM_REJECT_VALUE_MATCH: tokens="(string join ',' -- $_maybe)
    end
    if test (count $_hit) -eq 0; and test (count $_maybe) -eq 0
        _info "  "(count $_susp)" parser complaint(s) in the ring buffer, none naming a managed token"; _log "KPARAM_REJECT_UNRELATED: count="(count $_susp)
    end
end
function _vrk_gpu_state --description "_verify_runtime_kparams sub: GPU performance level"
    _echo "HARDWARE STATE"; _echo "── GPU performance level ──"
    set -l gpu_ok false; set -l found_gpu false
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level
        if test -f "$f"
            set found_gpu true
            set -l level (command cat -- "$f" 2>/dev/null)
            if test "$level" = "$GPU_DPM_LEVEL"
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
function _vrk_cpu_state --description "_verify_runtime_kparams sub: CPU governor/EPP + amd_pstate + boost"
    _echo "── CPU performance ──"
    set -g _CPU_PATH ""; set -l _cpu_dirs
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq; test -d "$cpu_dir"; and set -a _cpu_dirs "$cpu_dir"; end
    test (count $_cpu_dirs) -gt 0; and set -g _CPU_PATH $_cpu_dirs[1]
    if test -z "$_CPU_PATH"
        _warn "  No CPU frequency scaling found"
    else
        set -l cpu_name (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_CPU_PATH")
        _info "  Checking $cpu_name (representative)"
        for check in "scaling_driver:$EXPECTED_SCALING_DRIVER:Scaling driver" \
            "scaling_governor:$CPUPOWER_GOVERNOR:Governor" # profile-managed
            set -l parts (string split ':' -- "$check"); set -l sysfs_val (command cat -- "$_CPU_PATH/$parts[1]" 2>/dev/null)
            _chk_eq "$parts[3]" "$sysfs_val" "$parts[2]"
        end
        set -l _epp (command cat -- "$_CPU_PATH/energy_performance_preference" 2>/dev/null) # EPP pinned via 99-ry-perf.rules
        if test -n "$_epp"
            _chk_eq "EPP" "$_epp" "$EPP_PREFERENCE"
        else
            _info "  EPP: unreadable"
        end
        for _attr in scaling_driver:$EXPECTED_SCALING_DRIVER scaling_governor:$CPUPOWER_GOVERNOR energy_performance_preference:$EPP_PREFERENCE
            set -l _a (string split -m1 ':' -- "$_attr"); set -l _bad
            for _d in $_cpu_dirs
                test -r "$_d/$_a[1]"; or continue
                set -l _v (command cat -- "$_d/$_a[1]" 2>/dev/null | string trim --)
                test "$_v" = "$_a[2]"; or set -a _bad (string replace -r '.*/cpu(\d+)/.*' 'cpu$1' -- "$_d")":$_v"
            end
            if test (count $_bad) -eq 0
                _ok "  $_a[1]: uniform across "(count $_cpu_dirs)" policies"
            else
                _fail "  $_a[1]: "(count $_bad)" of "(count $_cpu_dirs)" policies diverge: $_bad"
            end
        end
    end
    _echo; _echo "── amd_pstate / CPU boost ──"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/status active "amd_pstate status"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/prefcore enabled "amd_pstate prefcore"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/dynamic_epp disabled "amd_pstate dynamic_epp" # ships since 7.1; when enabled, manual EPP writes are blocked
    _chk_sysfs_eq /sys/devices/system/cpu/cpufreq/boost 1 "CPU boost"
    _echo
end

# ── VERIFY-RUNTIME: MODULE-STATE SUBS (_vrkm_*; feed _vrk_module_state) ──
function _vrkm_amdgpu --description "_vrk_module_state sub: amdgpu parameters (hex-aware compare; expected from KERNEL_PARAMS)"
    test -d /sys/module/amdgpu/parameters; or return 0
    set -l _pairs
    for _kp in $KERNEL_PARAMS
        string match -q 'amdgpu.*=*' -- "$_kp"; and set -a _pairs (string replace -r '^amdgpu\.([^=]+)=' '$1:' -- "$_kp")
    end
    test (count $_pairs) -eq 0; and return 0 # no amdgpu.* module params in KERNEL_PARAMS
    for pair in $_pairs
        set -l _p (string split -m1 ':' -- "$pair"); set -l pname $_p[1]; set -l expected $_p[2]; set -l ppath /sys/module/amdgpu/parameters/$pname
        test -f "$ppath"; or continue
        set -l sysfs_val (string trim -- (command cat -- "$ppath" 2>/dev/null)); set -l sysfs_val_dec "$sysfs_val"; set -l expected_dec "$expected"
        string match -qr '^0x[0-9a-fA-F]+$' -- "$sysfs_val"; and set sysfs_val_dec (printf '%d' "$sysfs_val" 2>/dev/null; or echo "$sysfs_val") # normalize hex to decimal (amdgpu emits either)
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
function _vrkm_blacklist_modprobe --description "_vrk_module_state sub: lsmod-check 'blacklist' entries from managed modprobe.d content"
    set -l _mods
    for _dst in $SYSTEM_DESTINATIONS
        string match -q '*/modprobe.d/*' -- "$_dst"; or continue
        set -l _content (_ry_get_file_content "$_dst" 2>/dev/null)
        test "$status" -eq 0; or continue # generator failure: surfaced by static checksum verify
        for _bl in (string match -rg -- '^[[:space:]]*blacklist[[:space:]]+(\S+)' $_content)
            contains -- "$_bl" $_mods; or set -a _mods "$_bl"
        end
    end
    test (count $_mods) -eq 0; and return 0 # no managed modprobe.d blacklist entries
    if not command -q lsmod; _warn "  modprobe.d blacklist: lsmod absent — cannot verify load state"; return 0; end
    for mod in $_mods
        set -l _mod_lsmod (string replace -a -- '-' '_' "$mod")
        if command env LC_ALL=C lsmod 2>/dev/null | command grep -q -- "^$_mod_lsmod "
            _fail "  $mod: LOADED (modprobe.d blacklist not in effect — reboot pending, or loaded from initramfs)"
        else
            _ok "  $mod: not loaded (modprobe.d)"
        end
    end
end
function _vrk_module_state --description "_verify_runtime_kparams sub: Module parameters + blacklist"
    _echo "MODULE STATE"; _echo
    _echo "── Module parameters ──"
    _chk_sysfs_eq /sys/module/usbcore/parameters/autosuspend -1 "usbcore.autosuspend"
    _chk_sysfs_eq /sys/module/nvme_core/parameters/default_ps_max_latency_us 0 "nvme_core.default_ps_max_latency_us"
    _vrkm_amdgpu
    _echo "── Additional module parameters ──"
    _chk_sysfs_match /sys/module/zswap/parameters/enabled '^[N0]$' zswap.enabled
    _chk_sysfs_eq /proc/sys/kernel/nmi_watchdog 0 nmi_watchdog
    _echo; _echo "── I/O scheduler (NVMe) ──"
    set -l _nvme_bdevs (command find /sys/block -mindepth 1 -maxdepth 1 -name 'nvme*n*' 2>/dev/null)
    if test (count $_nvme_bdevs) -eq 0; _info "  No NVMe block device present"; end
    for _bdev in $_nvme_bdevs
        _chk_sysfs_match "$_bdev/queue/scheduler" '\[none\]' "io-sched "(command basename -- "$_bdev")
    end
    _echo; _echo "── Blacklisted modules ──"
    _vrkm_blacklist
    _vrkm_blacklist_modprobe
    _echo
end

# ── VERIFY-RUNTIME: KPARAMS ORCHESTRATOR (_verify_runtime_kparams) ──
function _verify_runtime_kparams --description "Verify /proc/cmdline, hardware state, module params, blacklist"; _vrk_cmdline; _vrk_param_rejects; _vrk_gpu_state; _vrk_cpu_state; _vrk_module_state; end

# ── VERIFY-RUNTIME: SERVICES (units, resolved, cpupower, nftables) ──
function _vrsv_chk_active_enabled --argument-names label rec_str --description "_vrsv_sys_units sub: ok if active+enabled, warn if active only, fail otherwise"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found
        _warn "  $label: not installed"; return 0
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
function _vrsv_nft_assert_ping --description "_vrsv_chk_nftables sub: Assert live input chain accepts inbound IPv4 ping (warn-only)"
    set -l _chain (_as true env LC_ALL=C nft list chain inet filter input 2>/dev/null)
    if string match -q -- '*echo-request*' "$_chain"
        _ok "  nftables: live IPv4 ping (echo-request) accept present"
    else
        _warn "  nftables: live input chain has no echo-request accept — inbound ping blocked until reload"
    end
end
function _vrsv_chk_nftables --argument-names label rec_str --description "_vrsv_sys_units sub: nftables.service: oneshot reads inactive after clean load"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found; _warn "  $label: not installed"; return 0; end
    set -l _nft_probe_ok false
    command -q nft; and sudo -n true 2>/dev/null; and set _nft_probe_ok true
    if test "$rec[2]" = active
        _vrsv_chk_active_enabled $label "$rec_str"
        test "$_nft_probe_ok" = true; and _vrsv_nft_assert_ping # ping assert independent of unit-state path
        return 0
    end
    if not command -q nft
        _fail "  $label: $rec[2] and nft(8) absent — live ruleset unverifiable"; return 0
    end
    if test "$_nft_probe_ok" = false
        _warn "  $label: $rec[2] — sudo cache lapsed, live ruleset unverifiable"; return 0
    end
    if not _nft_input_drop_live
        _fail "  $label: $rec[2] and no live inet/filter/input chain with policy drop"; return 0
    end
    if test "$rec[3]" = enabled
        _ok "  $label: ruleset live, input policy drop ($rec[3]; $rec[2] — oneshot, no RemainAfterExit)"
    else
        _warn "  $label: ruleset live but unit $rec[3] (will not persist across boots)"
    end
    _vrsv_nft_assert_ping
    return 0
end
function _vrsv_chk_resolved --argument-names rec_str --description "_vrsv_sys_units sub: Check systemd-resolved active + persistent state"
    set -l rec (string split ':' -- "$rec_str")
    test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf; or return 0
    if test "$rec[1]" = not-found; _warn "  systemd-resolved: not installed"; return 0; end
    if test "$rec[2]" != active
        _fail "  systemd-resolved: $rec[2] (expected: active — DNS may be broken)"
    else if contains -- "$rec[3]" enabled static
        _ok "  systemd-resolved: active ($rec[3])"
    else
        _warn "  systemd-resolved: active but $rec[3] (will not persist across boots)"
    end
end
function _vrsv_chk_cpupower_governor --argument-names rec_str --description "_vrsv_sys_units sub: Check cpupower.service (RemainAfterExit oneshot reads active)"
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

# ── VERIFY-RUNTIME: SERVICE COLLECTORS ──
function _vrsv_sys_units --description "_verify_runtime_services sub: conf.d-implied + EXPECTED_SERVICES (per-unit dispatch)"
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
function _vrsv_wifi_nm_backend --description "_vrsv_wifi sub: Verify NM effective wifi.backend vs NM_WIFI_BACKEND"
    if not command -q NetworkManager
        _info "  NetworkManager binary absent — backend check skipped"; return 0
    end
    set -l _eff (_as true NetworkManager --print-config 2>/dev/null | command grep -E -- '^[[:space:]]*wifi\.backend[[:space:]]*=' | command head -n1 | string replace -r '.*=[[:space:]]*' '' | string trim --)
    if test -z "$_eff"
        if not sudo -n true 2>/dev/null
            _warn "  NM effective wifi.backend: sudo cache lapsed — cannot determine"; return 0
        end
        _info "  NM effective wifi.backend: unset (NM default is wpa_supplicant)"
        test "$NM_WIFI_BACKEND" != wpa_supplicant; and _fail "  NM backend: expected $NM_WIFI_BACKEND, none configured (drop-in not active)"
    else if test "$_eff" = "$NM_WIFI_BACKEND"
        _ok "  NM effective wifi.backend: $_eff"
    else
        _fail "  NM effective wifi.backend: $_eff (expected: $NM_WIFI_BACKEND)"
    end
end
function _vrsv_wifi --description "_verify_runtime_services sub: WiFi + NM backend + NM state"
    _echo; _echo "WIFI STATE"
    _echo
    if test "$_RY_PROFILE_USES_WIFI_BACKEND" = false
        _info "  NetworkManager not managed — skipping WiFi state checks"; return 0
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
function _vrsv_masked_inactive --description "_verify_runtime_services sub: MASK units must be inactive"
    _echo; _echo "── Masked units (runtime) ──"
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

# ── VERIFY-RUNTIME: USER-SCOPE UNIT COLLECTOR ──
function _vrsv_user_units --description "_verify_runtime_services sub: Managed user-scope units not failed"
    if not _has_user_bus_active; _info "  user units: skipped (no active user-bus — log in graphically or enable-linger to verify)"; return 0; end
    if test (command systemctl --user list-unit-files --no-legend plasma-powerdevil.service 2>/dev/null | count) -eq 0
        _info "  plasma-powerdevil.service: unit not present — skipping user-unit health check"; return 0
    end
    if command systemctl --user is-failed --quiet plasma-powerdevil.service 2>/dev/null
        _fail "plasma-powerdevil.service: failed — journalctl --user -u plasma-powerdevil -b · coredumpctl list org_kde_powerdevil"
    else
        _ok "plasma-powerdevil.service: not failed"
    end
    set -l _failed_n (command systemctl --user --failed --plain --no-legend 2>/dev/null | count)
    test "$_failed_n" -gt 0; and _warn "  systemd --user reports $_failed_n failed unit(s) — systemctl --user --failed"
    return 0
end

# ── VERIFY-RUNTIME: SERVICES ORCHESTRATOR (_verify_runtime_services) ──
function _verify_runtime_services --description "Verify systemd unit states (sys batch) and WiFi runtime"; _echo "SERVICE STATE"; _echo; _vrsv_sys_units; _vrsv_masked_inactive; _vrsv_user_units; _vrsv_wifi; return 0; end

# ── VERIFY-RUNTIME: ENVIRONMENT ──
function _vre_envvars --description "_verify_runtime_env sub: ENV_VARS via systemctl --user show-environment"
    _echo "ENVIRONMENT STATE"; _echo
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
function _vre_sysctl_runtime --description "_verify_runtime_env sub: sysctl values via /proc/sys"
    set -q SYSCTL_VALUES; and test (count $SYSCTL_VALUES) -gt 0; or return 0
    _echo "── sysctl (ry-install) ──"
    for entry in $SYSCTL_VALUES
        set -l _parts (string split -m1 '=' -- "$entry"); set -l _key $_parts[1]; set -l _expected $_parts[2]
        set -l _proc_path (string replace -a '.' '/' -- "$_key"); set -l _actual (command cat -- "/proc/sys/$_proc_path" 2>/dev/null | string replace -ra '\s+' ' ' | string trim --); set -l _expected_norm (string replace -ra '\s+' ' ' -- "$_expected")
        if test "$_actual" = "$_expected_norm"
            _ok "  $_key: $_actual"
        else if test -n "$_actual"
            _fail "  $_key: $_actual (expected: $_expected)"
        else if not test -e "/proc/sys/$_proc_path"
            _warn "  $_key: knob absent — init_net-only key under a private netns, or kernel lacks it"
        else
            _warn "  $_key: unreadable"
        end
    end
    _echo
end
function _vre_fstab --description "_verify_runtime_env sub: fstab ext4 entries have noatime,lazytime,commit=10"
    _echo "── fstab mount options ──"
    set -l _rootfs (command findmnt -n -o FSTYPE / 2>/dev/null | string trim --)
    test -n "$_rootfs"; and _info "  root filesystem: $_rootfs"
    set -l _fstab_ext4; set -l _fstab_malformed
    if test -r /etc/fstab
        set _fstab_ext4 (command awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
        set _fstab_malformed (command awk "$_RY_AWK_EXT4_MALFORMED_FILTER" /etc/fstab 2>/dev/null)
    else if sudo -n test -r /etc/fstab 2>/dev/null
        set _fstab_ext4 (sudo -n awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null)
        set _fstab_malformed (sudo -n awk "$_RY_AWK_EXT4_MALFORMED_FILTER" /etc/fstab 2>/dev/null)
    else
        _warn "  /etc/fstab not readable (even via sudo) — skipping mount-option check"; return 0
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
        for _conflict in defaults relatime atime strictatime # installer strips these; presence = rewrite pending
            set -l _cre (string escape --style=regex -- "$_conflict")
            if string match -qr '(^|,)'$_cre'(,|$)' -- "$_opts"; _fail "  ext4 entry has $_conflict (installer removes it — rewrite pending): $_fl"; set _fstab_ok false; end
        end
    end
    test "$_fstab_ok" = true; and _ok "  ext4 entries ("(count $_fstab_ext4)"): noatime,lazytime,commit=10 present"
end
function _vre_fstab_live --description "_verify_runtime_env sub: Live ext4 mounts carry the fstab options"
    _echo; _echo "── fstab options applied live ──"
    if not command -q findmnt; _warn "  findmnt unavailable — live mount options unverified"; return 0; end
    set -l _rows (command findmnt -rn -t ext4 -o TARGET,OPTIONS 2>/dev/null)
    if test (count $_rows) -eq 0; _info "  no ext4 filesystem mounted"; return 0; end
    set -l _fstab_mps
    if test -r /etc/fstab
        set _fstab_mps (command awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null | command awk '{ print $2 }')
    else if sudo -n test -r /etc/fstab 2>/dev/null
        set _fstab_mps (sudo -n awk "$_RY_AWK_EXT4_FILTER" /etc/fstab 2>/dev/null | command awk '{ print $2 }')
    else
        _warn "  /etc/fstab not readable (even via sudo) — live mount options unverified"; return 0
    end
    set -l _fstab_paths # fstab escapes \040, findmnt -r escapes \x20 — compare decoded
    for _m in $_fstab_mps; set -a _fstab_paths (printf '%b' "$_m"); end
    set -l _pending; set -l _checked 0; set -l _skipped 0
    for _row in $_rows
        set -l _f (string split -m1 ' ' -- "$_row"); set -l _mp (printf '%b' "$_f[1]"); set -l _opts "$_f[2]"
        if not contains -- "$_mp" $_fstab_paths; set _skipped (math $_skipped + 1); continue; end
        set _checked (math $_checked + 1)
        for _tok in noatime lazytime commit=10 # same triad the rewrite writes
            set -l _re (string escape --style=regex -- "$_tok")
            string match -qr -- '(^|,)'$_re'(,|$)' "$_opts"; or set -a _pending "$_mp:$_tok"
        end
    end
    test "$_skipped" -gt 0; and _info "  $_skipped mounted ext4 filesystem(s) absent from /etc/fstab — unmanaged, not checked"
    if test "$_checked" -eq 0
        _info "  no fstab-listed ext4 filesystem is mounted"
    else if test (count $_pending) -eq 0
        _ok "  ext4 mounts ($_checked): noatime,lazytime,commit=10 live"
    else
        _warn "  written to fstab but not live: $_pending — sudo mount -o remount <target>, or reboot"; _log "FSTAB_REMOUNT_PENDING: "(string join ',' -- $_pending)
    end
end
function _vre_ntsync --description "_verify_runtime_env sub: ntsync state via _ntsync_state dispatch"
    _echo; _echo "── ntsync support ──"
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
function _vre_regdom --description "_verify_runtime_env sub: Wireless regulatory domain via iw reg get"
    _echo; _echo "── wireless regdom ──"
    if not command -q iw
        _info "regdom: iw(8) absent — cannot query (expected $COUNTRY)"; _echo
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
function _verify_runtime_env --description "Verify ENV_VARS, sysctl, fstab, ntsync, regdom runtime"; _vre_envvars; _vre_sysctl_runtime; _vre_fstab; _vre_fstab_live; _vre_ntsync; _vre_regdom; end

# ── VERIFY-RUNTIME: SESSION + PERMS ──
function _vrs_nm_perms --description "_verify_runtime_session sub: NetworkManager system-connections perms (0600 root:root)"
    set -l nm_conn_dir /etc/NetworkManager/system-connections
    if not test -d "$nm_conn_dir"; _info "  NetworkManager connections: directory not found"; return 0; end
    set -l conn_files (sudo -n find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f -print0 2>/dev/null | string split0); set -l _conn_ps $pipestatus
    if test "$_conn_ps[1]" -ne 0; _warn "  NetworkManager connections: cannot enumerate (sudo lapse or read error)"; return 0; end
    if test (count $conn_files) -gt 0
        set -l bad_perms 0
        for conn_file in $conn_files; _chk_perms "$conn_file" 600 root:root true; or set bad_perms (math $bad_perms + 1); end
        if test "$bad_perms" -eq 0; set -l conn_count (count $conn_files); _ok "  NetworkManager connections: $conn_count files with correct permissions"; end
    else if begin; command grep -q -- 'wifi.backend=' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null; or begin; not test -r /etc/NetworkManager/conf.d/99-cachyos-nm.conf; and sudo -n grep -q -- 'wifi.backend=' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null; end; end # sudo fallback if drop-in is 0600
        _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
    else
        _info "  NetworkManager connections: no .nmconnection files found"
    end
end
function _vrs_vfat_skip --argument-names path boot_fstype --description "_vrs_installed_file_perms sub: rc 0 = vfat/undetermined boot path"
    set -l _fst (command findmnt -n -o FSTYPE --target "$path" 2>/dev/null | string trim --) # per-path fstype
    test -z "$_fst"; and set _fst "$boot_fstype"
    if test "$_fst" = vfat; _info "  $path: skipped (vfat — unix perms synthesized from mount options)"; return 0; end
    if test -z "$_fst"; _info "  $path: skipped (boot fstype undetermined — vfat-safe default)"; return 0; end
    return 1
end
function _resolve_boot_fstype --description "Emit \$BOOT partition fstype (resolve \$BOOT, default /boot, findmnt FSTYPE)"; set -l _boot_resolved (_resolve_boot_path); test -z "$_boot_resolved"; and set _boot_resolved /boot; command findmnt -n -o FSTYPE "$_boot_resolved" 2>/dev/null | string trim --; end
function _vrs_installed_file_perms --description "_verify_runtime_session sub: Installed system/service/user file perms"
    _echo "── Installed files ──"
    set -l perm_bad 0; set -l perm_checked 0; set -l perm_vfat_skipped 0; set -l _boot_fstype (_resolve_boot_fstype)
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
function _vrs_parent_dirs --description "_verify_runtime_session sub: Parent dirs of managed files"
    _echo "── Parent directories ──"
    set -l dir_bad 0; set -l dir_checked 0; set -l dir_vfat_skipped 0; set -l checked_dirs
    set -l _boot_fstype (_resolve_boot_fstype)
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
        else if not sudo -n true 2>/dev/null # lapse mid-loop: warn once, stop
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

# ── VERIFY-RUNTIME: SESSION ORCHESTRATOR (_verify_runtime_session) ──
function _verify_runtime_session --description "Verify NM connection perms, installed-file perms, parent dirs"; _echo "FILE PERMISSIONS"; _echo "── Sensitive files ──"; _vrs_nm_perms; _vrs_installed_file_perms; _vrs_parent_dirs; end

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
function _dir_group_or_world_writable --argument-names mode --description "True when octal mode has group or world write bit"
    not string match -qr '^[0-7]+$' -- "$mode"; and return 0 # unparseable mode -> writable (fail-closed)
    test (string length -- "$mode") -gt 3; and set mode (string sub -s -3 -- "$mode") # drop special-bits digit
    while test (string length -- "$mode") -lt 3; set mode "0$mode"; end # stat %a strips leading zeros
    set -l group_w (string sub -s 2 -l 1 -- "$mode"); set -l other_w (string sub -s 3 -l 1 -- "$mode"); set -l group_has_w (math "floor($group_w / 2) % 2"); set -l other_has_w (math "floor($other_w / 2) % 2")
    test "$group_has_w" -eq 1; and return 0
    test "$other_has_w" -eq 1; and return 0
    return 1
end
function _has_user_bus_active --description "True iff user systemd manager is reachable"; set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"; and return 0; set -l _user_state (command systemctl --user is-system-running 2>/dev/null | string trim --); test -n "$_user_state"; and test "$_user_state" != offline; and return 0; return 1; end

# ── INSTALL PHASE 4: MASK + FIREWALL HANDOFF (NFTABLES LIVE BEFORE UFW FLUSH) ──
function _nft_input_drop_live --description "True when live inet/filter/input chain has policy drop"; command -q nft; or return 1; sudo -n true 2>/dev/null; or return 1; set -l _in_chain (_as true env LC_ALL=C nft list chain inet filter input 2>/dev/null | string collect); string match -q -- '*policy drop*' "$_in_chain"; end

# ── BOOT PATH RESOLUTION (ESP + $BOOT via bootctl / findmnt) ──
function _bootctl_dir --argument-names flag logtag fallnote --description "Probe bootctl path (user then sudo); empty on failure"
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
        for _candidate in /efi /boot/efi /boot/EFI /boot # only independently-mounted vfat (plain dir: findmnt empty)
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

# ── --INSTALL-FILE: DISPATCH TABLE + ORCHESTRATOR ──
set -g _RY_POST_HOOKS \
    "/boot/loader/loader.conf|loader" "/etc/kernel/cmdline|cmdline" "/etc/sdboot-manage.conf|boot" "/etc/mkinitcpio.conf|boot" \
    "*/resolved.conf.d/*|resolved" "*/logind.conf.d/*|logind" "*/NetworkManager-dispatcher.service.d/*|nmdispatch" "*/NetworkManager/conf.d/*|nm" \
    "/etc/iw-regdomain|regdom" "/etc/bluetooth/main.conf|bluetooth" "/etc/nftables.conf|nft" "/etc/default/cpupower-service.conf|cpupower" \
    "*/sysctl.d/*|sysctl" "/etc/udev/rules.d/*|udev" "*/modprobe.d/*|modprobe" "*/environment.d/*|envd" \
    "*/MangoHud/MangoHud.conf|mangohud"
function _ir_validate_post_hooks --description "Refuse deploy when a _RY_POST_HOOKS tag lacks a handler or breaks destination mirror" # mirrors _ir_validate_keys
    set -l _seen_tags
    set -l _mirror_dsts $SYSTEM_DESTINATIONS $USER_DESTINATIONS
    set -l _mirror_n (count $_mirror_dsts)
    if test (count $_RY_POST_HOOKS) -ne "$_mirror_n"; _err_loud "_RY_POST_HOOKS count "(count $_RY_POST_HOOKS)" does not mirror destination count $_mirror_n — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    for _i in (seq $_mirror_n)
        set -l _mparts (string split -m1 '|' -- "$_RY_POST_HOOKS[$_i]"); set -l _mpat $_mparts[1]
        if not string match -q "$_mpat" -- "$_mirror_dsts[$_i]"; _err_loud "_RY_POST_HOOKS mirror break at index $_i: pattern '$_mpat' does not match destination '$_mirror_dsts[$_i]' — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
    for _entry in $_RY_POST_HOOKS
        set -l _parts (string split -m1 '|' -- "$_entry"); set -l _tag $_parts[2]
        if test -z "$_tag"; _err_loud "_RY_POST_HOOKS entry has empty tag: '$_entry' — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
        contains -- "$_tag" $_seen_tags; and continue
        set -a _seen_tags "$_tag"
        if not functions -q "_post_$_tag"; _err_loud "_RY_POST_HOOKS tag '$_tag' has no handler '_post_$_tag' (entry '$_entry') — refuse to deploy"; _pre_dispatch_exit $EXIT_PREFLIGHT; end
    end
end

# ── --INSTALL-FILE: POST-HOOK HANDLERS ──
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
function _post_boot --argument-names target --description "Post-hook: rebuild boot entries (mkinitcpio + sdboot-manage)"; _post_boot_apply "$target" false; end
function _post_cmdline --argument-names target --description "Post-hook: regenerate sdboot entries only (cmdline is not an initramfs input)"; _post_boot_apply "$target" true; end
function _post_loader --argument-names target --description "Post-hook: regenerate sdboot entries only"; _post_boot_apply "$target" true; end

# ── POST-HOOKS: NON-BOOT LIVE-APPLY (SERVICE/CONFIG; FAILURES NON-FATAL, EXIT 0) ──
function _post_resolved --argument-names target --description "Post-hook: restart systemd-resolved"
    _echo
    if not _run sudo -n systemctl restart systemd-resolved
        _warn "systemd-resolved restart failed — drop-in applies at next boot (non-fatal; file deployed)"
        return 0
    end
    return 0
end
function _post_logind --argument-names target --description "Post-hook: notify reboot needed for logind"; _info "Logind config $target changed — reboot required (restarting logind kills all sessions)"; return 0; end
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
function _post_mangohud --argument-names target --description "Post-hook: notify MangoHud.conf change (read at next game/Vulkan app launch)"; _info "MangoHud $target changed — applies at next launch under 'mangohud %command%' (no service restart needed)"; _info "  Toggle the HUD in-app with Shift_R+F12 (MangoHud default)"; return 0; end
function _post_envd --argument-names target --description "Post-hook: env-generator re-run + PowerDevil re-apply after environment.d change"
    _info "environment.d $target changed — log out and back in (or restart the user session) to apply session-wide"
    _info "  Active systemd --user services retain the old environment until restarted"
    if not _has_user_bus_active
        _info "  No active user-bus — POWERDEVIL_NO_DDCUTIL applies at next graphical login"
        _log "POST_ENVD_SKIP: no active user-bus target=$target"
        return 0
    end
    if not _run systemctl --user daemon-reload # re-runs systemd.environment-generator(7)
        _warn "systemctl --user daemon-reload failed — environment.d applies at next login (non-fatal; file deployed)"
        return 0
    end
    if not _run systemctl --user restart plasma-powerdevil.service
        _warn "plasma-powerdevil.service restart failed — POWERDEVIL_NO_DDCUTIL applies at next login (non-fatal; file deployed)"
        return 0
    end
    return 0
end

# ── POST-HOOKS: HARDWARE + FIREWALL (CPUPOWER, NFT, REGDOM, BT, UDEV, MODPROBE) ──
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
function _post_regdom --argument-names target --description "Post-hook: apply wireless regdom after /etc/iw-regdomain change"; _echo; _apply_wireless_regdom; end
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
function _post_udev --argument-names target --description "Post-hook: reload udev rules + retrigger block/cpu devices after /etc/udev/rules.d/* change"
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
        set -l _sv (set -q _RY_SYSTEMD_VER; and echo $_RY_SYSTEMD_VER; or echo unknown)
        _warn "udevadm verify unavailable (systemd $_sv < 254) — reloading $target unvalidated; check the rule by hand if you edited it"
        _log "UDEV_VERIFY_SKIP: systemd $_sv < 254 — udevadm verify unavailable; reloading rule unvalidated"
    end
    if not _run sudo -n udevadm control --reload-rules
        _warn "udevadm control --reload-rules failed — rule applies at next boot (non-fatal; file deployed)"
        _info "  Retry: sudo udevadm control --reload-rules; and sudo udevadm trigger --subsystem-match=block --subsystem-match=cpu --action=change"
        return 0
    end
    _run sudo -n udevadm trigger --subsystem-match=block --subsystem-match=cpu --action=change; or _warn "udevadm trigger failed — scheduler/EPP apply at next boot or device event" # drm rule is ACTION==add: applies at boot
    return 0
end
function _post_modprobe --argument-names target --description "Post-hook: notify reboot needed for modprobe.d option change"
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
    set -g _RY_LOG_SUPPRESS_CREATE true # suppress lazy-create
end
function _pre_dispatch_exit --argument-names code --description "Pre-dispatch teardown: log/dir cleanup, then exit"; _pre_dispatch_log_cleanup; _ry_exit $code; end

# ── MAIN: ARGPARSE + MODE SELECTION + LOG HEADER + EXIT ──
set -g MODE verify
set -l _ORIG_ARGV $argv; set -l _ap_errfile (_mktemp_or_null -p (_tmp_dir) "ry-argparse-err.$fish_pid.XXXXXX")
_track_tmpfile "$_ap_errfile"
argparse --name=(command basename -- (status filename)) $_RY_ARGPARSE_SPEC -- $argv 2>"$_ap_errfile"
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
set --erase _RY_ARGV_CHECK_ONLY # MODE is authoritative past this point
if test (count $argv) -gt 0; echo "[ERR] Unexpected positional argument(s): $argv" >&2; echo >&2; _ry_show_help >&2; _pre_dispatch_exit $EXIT_USAGE; end
test "$MODE" != check; and set -g QUIET false

# ── MAIN: LOG RENAME + 0600 CREATE + JSONL HEADER ──
set -l mode_label $MODE
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"; set -l old_log "$LOG_FILE"; set -l _log_rename_ok true
if test -f "$old_log"; and test "$old_log" != "$new_log"
    if not command mv -T -- "$old_log" "$new_log" 2>/dev/null
        if command cp -pT -- "$old_log" "$new_log" 2>/dev/null
            command rm -f -- "$old_log" 2>/dev/null
            test "$MODE" != check; and echo "[WARN] Log rename via mv failed; recovered via cp+rm: $old_log -> $new_log" >&2
        else
            set _log_rename_ok false # old path stays writable: keep logging there
            test "$MODE" != check; and echo "[WARN] Log rename failed (mv and cp both): $old_log -> $new_log (keeping old path)" >&2
        end
    end
end
test "$_log_rename_ok" = true; and set -g LOG_FILE "$new_log"
if test -L "$LOG_FILE"; command rm -f -- "$LOG_FILE" 2>/dev/null; test "$MODE" != check; and echo "[WARN] Pre-existing LOG_FILE was a symlink — removed; will re-create with 0600" >&2; end
if not test -f "$LOG_FILE"
    set -l _prev_umask 022; set -q umask; and set _prev_umask $umask
    set -g umask 0177
    if not command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
        if not command touch -- "$LOG_FILE" 2>/dev/null; set -g umask $_prev_umask; echo "[ERR] Failed to create log file: $LOG_FILE" >&2; _ry_exit $EXIT_PREFLIGHT; end
        if not command chmod -- 600 "$LOG_FILE" 2>/dev/null; set -g umask $_prev_umask; command rm -f -- "$LOG_FILE" 2>/dev/null; echo "[ERR] Failed to set 0600 on log file: $LOG_FILE" >&2; _ry_exit $EXIT_PREFLIGHT; end
    end
    set -g umask $_prev_umask
else
    command chmod -- 600 "$LOG_FILE" 2>/dev/null
end
set -l _argv_parts; set -l _argv_in (status filename) $_ORIG_ARGV
for _r in $_argv_in; set -a _argv_parts '"'(_json_str "$_r")'"'; end
set --erase _r
set -l _argv_json '['(string join -- ',' $_argv_parts)']'; set -l _verbose_json false
test "$QUIET" = false; and set _verbose_json true
printf '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","verbose":%s,"argv":%s}\n' (command date $_RY_TS_FMT) "$VERSION" "$PROFILE_NAME" "$MODE" "$_verbose_json" "$_argv_json" >>"$LOG_FILE" 2>/dev/null
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
_init_runtime
switch "$MODE"
    case verify
        _ry_verify_all
        _set_exit $status
    case check
        _ry_do_check
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
