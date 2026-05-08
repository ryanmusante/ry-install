#!/usr/bin/env fish
# ry-install v4.6.3 (2026-05-08) — CachyOS config manager | Ryan Musante | MIT. Dynamic dispatch: _ry_get_file_content → _content_<key>. Module-state via `set -g` globals namespaced _RY_* / _* / SCREAMING_SNAKE_CASE; erased in _ry_namespace_cleanup; re-source guard _RY_INSTALL_LOADED.
if set -q _RY_INSTALL_LOADED
    echo "ry-install already loaded in this session" >&2
    if status stack-trace 2>/dev/null | string match -q '*from sourcing*'
        return 1
    else
        exit 1
    end
end
# reset bail sentinel + last-exit on fresh load.
set -e _RY_INSTALL_BAILING
set -e _RY_INSTALL_LAST_EXIT
set -g _RY_PRE_GLOBALS (set --names -g)
set -g _RY_INSTALL_LOADED true
if status stack-trace 2>/dev/null | string match -q '*from sourcing*'
    set -g _RY_INSTALL_SOURCED true
else
    set -g _RY_INSTALL_SOURCED false
end
set -g VERSION "4.6.3"
set -g EXIT_OK 0
set -g EXIT_FAIL 1
set -g EXIT_USAGE 2
set -g EXIT_PREFLIGHT 3
set -g EXIT_BOOT_CRIT 4
set -g EXIT_LOCK 5
set -g EXIT_DRIFT 10
# internal-only sentinels — squashed to EXIT_PREFLIGHT at consumer site
set -g EXIT_GEN_NOFN 11
set -g EXIT_GEN_NOUUID 12
set -g EXIT_GEN_SYSCTL 13
set -g _RY_SECRET_FLAGS --passphrase --password --token --key --secret --api-key --apikey --psk --wpa-psk --private-key --auth --bearer --cookie --client-secret --credential
set -g _RY_RUN_TIMEOUT_DEFAULT 3600
set -g _MY_UID (id -u)

function _ry_show_help --description "Display usage information and available subcommands"
    # fallback for unset _RY_MANAGED_FILE_COUNT
    set -l _file_count 15
    set -q _RY_MANAGED_FILE_COUNT; and test -n "$_RY_MANAGED_FILE_COUNT"; and set _file_count $_RY_MANAGED_FILE_COUNT
    set -l _profile_desc "Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S"
    set -q PROFILE_DESC; and test -n "$PROFILE_DESC"; and set _profile_desc "$PROFILE_DESC"
    echo "
ry-install v$VERSION
Self-contained CachyOS configuration for $_profile_desc
Single fish script, $_file_count embedded configs, no external dependencies.
Usage: "(status filename)" [OPTIONS]
INSTALLATION:
  (no args)         Unattended install (the only mode)
  -V, --verbose     Show output for install/check (silent by default; verify modes are always verbose)
VERIFICATION:
  --verify-static   Check config files exist with correct content
  --verify-runtime  Check live system state (run after reboot)
  --check           Silent idempotency probe (exit 0 = clean, exit 3 = preflight, exit 10 = drift)
UTILITIES:
  --install-file <path>  Re-deploy a single managed file
OPTIONS:
  --                End of options (positional args after `--` are rejected with exit 2)
  -h, --help        Show this help
  -v, --version     Show version
Modes are mutually exclusive (argparse --exclusive).
Unattended install is the only mode. There is no preview, diff, or repair mode.
For drift detection, use --verify-static / --verify-runtime.
EXIT CODES:
  0 ok · 1 non-critical · 2 usage · 3 preflight · 4 boot-critical · 5 lock · 10 drift
  129/130/131/143 signal (HUP/INT/QUIT/TERM) · 134/138/140 signal (ABRT/USR1/USR2) · 141 SIGPIPE
ENVIRONMENT:
  RY_RUN_TIMEOUT=<seconds>    Wall-clock limit for each _run. Default $_RY_RUN_TIMEOUT_DEFAULT. 0=disable.
  RY_INSTALL_CONFIRM_BOOT_WIPE=1    One-time ack for SDBOOT_REMOVE_EXISTING=yes.
  RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1    Switch Packages phase from `pacman -Syu --needed` (Arch-recommended) to `pacman -Sy --needed` (install-only; partial-upgrade risk).
  RY_INSTALL_FORCE_BOOT_REBUILD=1    Bypass torn-package gate (recovery only; literal '1' required).
  NO_COLOR    Suppress ANSI color when set to any non-empty value (also auto on TERM=dumb / non-TTY stderr).
Log: ~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl
See README.md for full reference.
"
end

set -l _early_cleanup _RY_INSTALL_LOADED _RY_INSTALL_SOURCED _RY_PRE_GLOBALS _RY_INSTALL_BAILING _RY_INSTALL_LAST_EXIT VERSION EXIT_OK EXIT_FAIL EXIT_USAGE EXIT_PREFLIGHT EXIT_BOOT_CRIT EXIT_LOCK EXIT_DRIFT EXIT_GEN_NOFN EXIT_GEN_NOUUID EXIT_GEN_SYSCTL _RY_SECRET_FLAGS _RY_RUN_TIMEOUT_DEFAULT _MY_UID
for _early_arg in $argv
    switch "$_early_arg"
        case -h --help
            _ry_show_help
            set -e $_early_cleanup _early_cleanup _early_arg 2>/dev/null
            exit 0
        case -v --version
            echo "v$VERSION"
            set -e $_early_cleanup _early_cleanup _early_arg 2>/dev/null
            exit 0
    end
end
set -e _early_cleanup _early_arg

function _ry_erase_handlers --description "Erase signal/exit handler functions; single-source-of-truth for the handler list"
    functions -e _cleanup _cleanup_pipe _cleanup_on_exit _cleanup_other _progress_on_winch 2>/dev/null
end

function _ry_exit --argument-names code --description "Source-safe exit: set bail sentinel and return when sourced, exit otherwise"
    test -z "$code"; and set code 0
    if set -q _RY_INSTALL_BAILING; and test "$_RY_INSTALL_BAILING" = true
        set -g _RY_INSTALL_LAST_EXIT $code
        test "$_RY_INSTALL_SOURCED" = true; and return $code
        exit $code
    end
    # Order matters: assign _CLEANUP_DONE first to gate signal-handler re-entry
    set -g _CLEANUP_DONE true
    set -g _RY_INSTALL_LAST_EXIT $code
    set -g _RY_INSTALL_BAILING true
    set -l _was_sourced "$_RY_INSTALL_SOURCED"
    if not set -q _RY_HEADER_WRITTEN; and not set -q _RY_LOG_WRITTEN
        set -q LOG_FILE; and command rm -f -- "$LOG_FILE" 2>/dev/null
        set -q LOG_DIR; and command rmdir -- "$LOG_DIR" 2>/dev/null
        set -q LOG_DIR; and command rmdir -- (dirname -- "$LOG_DIR") 2>/dev/null
        set -q HOME; and command rmdir -- "$HOME/ry-install" 2>/dev/null
    end
    functions -q _do_cleanup; and _do_cleanup
    # erase handlers before namespace cleanup.
    _ry_erase_handlers
    _ry_namespace_cleanup bail
    test "$_was_sourced" = true; and return $code
    exit $code
end

function _ry_namespace_cleanup --argument-names mode --description "Erase script-set globals; preserve caller-API"
    # IDEMPOTENCY GUARD: snapshot already lost → skip
    set -q _RY_PRE_GLOBALS; or return 0
    set -l _preserve _RY_INSTALL_LAST_EXIT HOME
    test "$mode" = bail; and set -a _preserve _RY_INSTALL_BAILING
    set -l _snap $_RY_PRE_GLOBALS
    for _v in (set --names -g)
        contains -- $_v $_snap; and continue
        contains -- $_v $_preserve; and continue
        set -e $_v 2>/dev/null
    end
end

set -g QUIET true
set -l _no_color_env (set -q NO_COLOR; and printf '%s' "$NO_COLOR")
set -g NO_COLOR false
test -n "$_no_color_env"; and set -g NO_COLOR true
test "$TERM" = dumb; and set -g NO_COLOR true
set -l fish_ver $FISH_VERSION
set -l parts (string split '.' -- "$fish_ver")
if not string match -qr '^\d+$' -- "$parts[1]"; or not string match -qr '^\d+$' -- "$parts[2]"
    echo "[ERR] fish version unparseable: '$fish_ver'" >&2
    _ry_exit $EXIT_PREFLIGHT
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
test "$parts[1]" -lt 3; or begin; test "$parts[1]" -eq 3; and test "$parts[2]" -lt 6; end; and echo "[ERR] fish 3.6+ required (found: $fish_ver)" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -gx PATH /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin
# TMPDIR writability gate
set -l _ry_tmpprobe_dir (set -q TMPDIR; and test -n "$TMPDIR"; and printf '%s' "$TMPDIR"; or printf '%s' /tmp)
not test -w "$_ry_tmpprobe_dir"; and echo "[ERR] tmp dir not writable: $_ry_tmpprobe_dir" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
not printf 'b\0a\0' | command sort -z 2>/dev/null | command tr -d '\0' | command grep -q '^ab$'; and echo "[ERR] GNU sort with NUL-delimited sort (-z) required (busybox/BSD sort detected)" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
# GNU stat -c probe
not command stat -c '%a' / >/dev/null 2>&1; and echo "[ERR] GNU stat with -c format flag required (BSD stat detected)" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
# GNU find -printf probe (BSD find lacks -printf)
not command find /tmp -maxdepth 0 -printf '' 2>/dev/null; and echo "[ERR] GNU find with -printf required (BSD find detected)" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
# GNU df --output probe (BSD df lacks --output)
not command df --output=avail / >/dev/null 2>&1; and echo "[ERR] GNU df with --output required (BSD df detected)" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
not command -q timeout; and echo "[ERR] GNU coreutils timeout(1) required (used by _run for hang-protection)" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -g _RY_SLEEP_FRAC 1
command sleep 0.05 2>/dev/null; and set -g _RY_SLEEP_FRAC 0.1
# Timestamps: DATE_LABEL for dirs
set -g DATE_LABEL (date '+%Y-%m-%d')
set -g TIMESTAMP (date '+%Y%m%d-%H%M%S%z')"-"$fish_pid
set -gx _RY_LOG_OWNER_PID $fish_pid
if test -z "$HOME"; or not test -d "$HOME"
    set -g HOME (getent passwd $_MY_UID 2>/dev/null | cut -d: -f6)
    test -z "$HOME"; or not test -d "$HOME"; and echo "[ERR] Cannot determine HOME directory" >&2; and _ry_exit $EXIT_PREFLIGHT
end
set -g HOME (string trim -r -c / -- "$HOME")
set -g _RY_HOME_DIR "$HOME/ry-install"
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -g LOG_DIR "$_RY_HOME_DIR/logs/$DATE_LABEL"
# Boot-wipe acknowledgement marker
set -g BOOT_WIPE_MARKER "$_RY_HOME_DIR/.boot-wipe-acknowledged"
set -l _prev_mkdir_umask (umask)
umask 0077
command mkdir -p -- "$LOG_DIR" 2>/dev/null; or begin
    umask $_prev_mkdir_umask
    echo "[ERR] Cannot create log directory: $LOG_DIR" >&2
    _ry_exit $EXIT_PREFLIGHT
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
umask $_prev_mkdir_umask
command chmod -- 700 "$_RY_HOME_DIR/logs" 2>/dev/null
command chmod -- 700 "$LOG_DIR" 2>/dev/null
set -l _ld_cur_mode (command stat -c '%a' -- "$_RY_HOME_DIR" 2>/dev/null)
test "$_ld_cur_mode" != 700; and command chmod -- 700 "$_RY_HOME_DIR" 2>/dev/null
set -l _ld_mode (command stat -c '%a' -- "$_RY_HOME_DIR" 2>/dev/null)
test "$_ld_mode" != 700; and echo "[ERR] Log dir mode is $_ld_mode (expected 700): $_RY_HOME_DIR" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -g LOG_FILE "$LOG_DIR/preflight-$TIMESTAMP.jsonl"
set -l _prev_umask (umask)
umask 0177
command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null; or begin
    command touch -- "$LOG_FILE" 2>/dev/null
    command chmod -- 600 "$LOG_FILE" 2>/dev/null
end
umask $_prev_umask
not test -f "$LOG_FILE"; and echo "[ERR] Failed to create log file: $LOG_FILE" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -g INSTALL_HAD_ERRORS false
# _RY_BOOT_TAINTED: separate from INSTALL_HAD_ERRORS — only set true by failures that mean
# the on-disk package state or boot-critical configs may be inconsistent with the embedded
# /etc/mkinitcpio.conf / /etc/kernel/cmdline / /etc/sdboot-manage.conf. Service-runtime
# failures (e.g. nftables.service start fails because /etc/nftables.conf is missing/invalid)
# do NOT taint boot — they're orthogonal to initramfs rebuild safety.
set -g _RY_BOOT_TAINTED false
set -g _RY_BOOT_CRITICAL_DSTS \
    "/boot/loader/loader.conf" \
    "/etc/kernel/cmdline" \
    "/etc/sdboot-manage.conf" \
    "/etc/mkinitcpio.conf"
set -g _TRACKED_TMPFILES
set -g _SYS_TMP_DIRS
set -g _USR_TMP_DIRS
set -g _PROFILE_USES_WIFI_BACKEND false
set -g MAX_LOGS 50
set -g SUDO_KEEPALIVE_INTERVAL 45
set -g NM_RESTART_DELAY 3
set -g KVER (uname -r)
set -g KVER_PARTS (string split '.' -- "$KVER")
set -g KVER_MAJOR $KVER_PARTS[1]
not string match -qr '^\d+$' -- "$KVER_MAJOR"; and echo "[ERR] Cannot parse kernel major version from uname -r: $KVER" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -g KVER_MINOR (string replace -r '[^0-9].*' '' -- "$KVER_PARTS[2]")
test -z "$KVER_MINOR"; or not string match -qr '^\d+$' -- "$KVER_MINOR"; and echo "[ERR] Cannot parse kernel minor version from uname -r: $KVER" >&2; and _ry_exit $EXIT_PREFLIGHT
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
function _kconfig_cache --description "Return cached /proc/config.gz lines (lazy-loaded; empty on missing config)"
    # sentinel-based gate
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

function _resolve_systemd_ver --description "Cache systemd major version into _RY_SYSTEMD_VER (anchored regex on systemctl --version line 1); empty on parse failure"
    set -q _RY_SYSTEMD_VER; and return 0
    set -g _RY_SYSTEMD_VER (systemctl --version 2>/dev/null | head -n 1 | string match -rg -- '^systemd (\d+)')
    return 0
end

function _detect_lvm --description "Return 0 (LVM present) or 1 (no LVM detected)"
    if command -q sudo; and sudo -n true 2>/dev/null
        set -l _pvs_output (command timeout 10 sudo -n pvs --noheadings 2>/dev/null | string trim --)
        if test -n "$_pvs_output"
            functions -q _log; and _log "LVM_DETECT: method=pvs result=present"
            return 0
        end
    end
    if command -q lsblk
        if lsblk -no TYPE 2>/dev/null | string match -q lvm
            functions -q _log; and _log "LVM_DETECT: method=lsblk result=present"
            return 0
        end
        functions -q _log; and _log "LVM_DETECT: method=lsblk result=absent"
        return 1
    end
    functions -q _log; and _log "LVM_DETECT: method=none result=absent (no sudo, no lsblk)"
    return 1
end

function _validate_kernel_params --description "Warn if KERNEL_PARAMS reference features not compiled into running kernel"
    # Only useful if /proc/config.gz exists
    not test -f /proc/config.gz; and _info "  /proc/config.gz unavailable — skipping kernel config validation"; and return 0
    # Map cmdline param prefix → CONFIG_ symbol
    set -l param_config_map "zswap.=CONFIG_ZSWAP" "amdgpu.=CONFIG_DRM_AMDGPU" "pcie_aspm.=CONFIG_PCIEASPM" "split_lock_detect=CONFIG_X86_BUS_LOCK_DETECT" "usbcore.=CONFIG_USB_SUPPORT"
    set -l config_data (_kconfig_cache)
    test -z "$config_data"; and _warn "  Failed to read /proc/config.gz"; and return 1
    set -l mismatches 0
    for entry in $param_config_map
        set -l prefix (string split '=' -- "$entry")[1]
        set -l config_sym (string split '=' -- "$entry")[2]
        set -l found false
        for param in $KERNEL_PARAMS
            string match -q -- "$prefix*" "$param"; and set found true; and break
        end
        test "$found" = true; or continue
        not printf '%s\n' $config_data | command grep -q -- "^$config_sym=[ym]"; and _warn "  $prefix* requires $config_sym but not enabled in running kernel"; and set mismatches (math $mismatches + 1)
    end
    test $mismatches -gt 0; and return 1
    return 0
end

function _unit_state --argument-names unit --description "Return LoadState/ActiveState/UnitFileState as a 3-element list (one field per element); empty on failure"
    systemctl show --value --property=LoadState,ActiveState,UnitFileState -- "$unit" 2>/dev/null | string split \n
end

function _unit_state_user --argument-names unit --description "Return user-scope LoadState/ActiveState/UnitFileState as a 3-element list; empty on failure or no user-bus"
    systemctl --user show --value --property=LoadState,ActiveState,UnitFileState -- "$unit" 2>/dev/null | string split \n
end

function _unit_state_padded --argument-names unit --description "Return _unit_state values; on <3 fields, return ERR_NO_DATA sentinels so callers indexing [1..3] never see empty strings"
    set -l _v (_unit_state "$unit")
    if test (count $_v) -lt 3
        printf '%s\n' ERR_NO_DATA ERR_NO_DATA ERR_NO_DATA
    else
        printf '%s\n' $_v[1] $_v[2] $_v[3]
    end
end

function _verify_unit_syntax --description "Verify systemd unit syntax via systemd-analyze. argv = unit_path label [intended_scope]"
    set -l unit_path $argv[1]
    set -l label $argv[2]
    set -l intended_scope $argv[3]
    _log "VERIFY_UNIT: $label ($unit_path) scope="(test -n "$intended_scope"; and echo $intended_scope; or echo "auto")
    command -q systemd-analyze; or begin
        _warn "  systemd-analyze not available — skipping $label"
        return 0
    end
    set -l user_flag
    if test "$intended_scope" = user
        set user_flag --user
    else if test "$intended_scope" = system
        set user_flag
    else
        string match -q '*/.config/systemd/user/*' -- "$unit_path"; and set user_flag --user
    end
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
    test -n "$extra_key"; and set _extra ",\"$extra_key\":true"
    set -l _gen_fail 0
    set -q VERIFY_GEN_FAIL; and set _gen_fail $VERIFY_GEN_FAIL
    # %d (was %s) for JSON number fields; %s emits invalid JSON on empty value.
    printf '{"ts":"%s","event":"footer","mode":"%s","exit_code":%d,"pass":%d,"fail":%d,"warn":%d,"gen_fail":%d%s}\n' \
        "$_ts" "$_mode_esc" "$exit_code" "$VERIFY_OK" "$VERIFY_FAIL" "$VERIFY_WARN" "$_gen_fail" "$_extra" >>"$LOG_FILE" 2>/dev/null
end

function _cleanup_tmpfiles --description "Remove temporary files created during this run"
    not set -q _FOOTER_WRITTEN; and _log "CLEANUP_TMPFILES: sweep starting"
    for dir in $_SYS_TMP_DIRS
        if command -q sudo
            sudo -n find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
        else
            command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
        end
    end
    for dir in $_USR_TMP_DIRS
        command find "$dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
    end
    set -l comp_dir "$HOME/.config/fish/completions"
    test -d "$comp_dir"; and command find "$comp_dir" -maxdepth 1 -name '.ry-install.*' -type f -delete 2>/dev/null
end

set -g _CLEANUP_DONE false

function _acquire_lock_fresh --description "Try fresh atomic-mkdir lock; rc=0 acquired, rc=1 hard error, rc=2 LOCK_DIR already exists (caller falls through to reclaim)"
    if not command mkdir -- "$LOCK_DIR" 2>/dev/null
        return 2
    end
    # Atomic pid write: mktemp inside just-created LOCK_DIR
    set -l _pid_tmp (mktemp -p "$LOCK_DIR" .pid.XXXXXX 2>/dev/null)
    if test -z "$_pid_tmp"; or not printf '%s\n' $fish_pid >"$_pid_tmp" 2>/dev/null
        test -n "$_pid_tmp"; and command rm -f -- "$_pid_tmp" 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null
        echo "[ERR] Failed to write lock pid file: $LOCK_FILE" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    if not command mv -f -- "$_pid_tmp" "$LOCK_FILE" 2>/dev/null
        command rm -f -- "$_pid_tmp" 2>/dev/null
        command rmdir -- "$LOCK_DIR" 2>/dev/null
        echo "[ERR] Failed to install lock pid file: $LOCK_FILE" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    set -g _RY_HOLDS_LOCK true
    _log "LOCK_ACQUIRED: pid=$fish_pid dir=$LOCK_DIR"
    return 0
end

function _reclaim_stale_lock --description "Stale-lock reclaim: /proc/<pid>/comm liveness probe + flock(1) atomic reclaim. rc=0 reclaimed, rc=1 contention/hard error"
    set -l old_pid (command cat -- "$LOCK_FILE" 2>/dev/null)
    if test -n "$old_pid"; and string match -qr '^\d+$' -- "$old_pid"; and kill -0 -- "$old_pid" 2>/dev/null
        set -l _old_comm (command cat -- /proc/$old_pid/comm 2>/dev/null | string trim --)
        if test "$_old_comm" = fish
            echo "[ERR] Another ry-install instance is running (PID $old_pid)" >&2
            _pre_dispatch_log_cleanup
            return 1
        end
        # PID alive but not fish → reused. Fall through to flock-reclaim.
    end
    if not command -q flock; or not command -q sh
        # flock(1) is base util-linux on CachyOS
        echo "[ERR] flock(1) and/or /bin/sh not available — cannot safely reclaim stale lock" >&2
        echo "[ERR]   Install util-linux: sudo pacman -S --needed util-linux" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    set -l _reclaim_parent (dirname -- "$LOCK_DIR")
    # flock -n/-E 5: non-blocking, exit 5 on contention
    set -l _sh_script (string join \n 'find "$1" -maxdepth 1 -type f -delete 2>/dev/null  # lint:ignore (embedded /bin/sh -c block)' 'rmdir -- "$1" 2>/dev/null || true  # lint:ignore (sh, not fish — embedded /bin/sh -c block)' 'mkdir -- "$1" 2>/dev/null || exit 1  # lint:ignore (sh, not fish — embedded /bin/sh -c block)' 'printf "%s\n" "$2" > "$1/pid" 2>/dev/null || exit 2  # lint:ignore (sh, not fish — embedded /bin/sh -c block)' | string collect)
    flock -n -E 5 "$_reclaim_parent" /bin/sh -c "$_sh_script" _ "$LOCK_DIR" "$fish_pid" 2>/dev/null
    set -l _flock_rc $status
    if test $_flock_rc -eq 5
        echo "[ERR] Failed to reclaim stale lock — another instance is reclaiming" >&2
        _pre_dispatch_log_cleanup
        return 1
    else if test $_flock_rc -ne 0
        echo "[ERR] Failed to reclaim stale lock via flock (rc=$_flock_rc)" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    set -l verify_pid (command cat -- "$LOCK_FILE" 2>/dev/null)
    if test "$verify_pid" != "$fish_pid"
        echo "[ERR] Lock reclaim lost to concurrent instance (PID $verify_pid)" >&2
        _pre_dispatch_log_cleanup
        return 1
    end
    set -g _RY_HOLDS_LOCK true
    _log "LOCK_RECLAIMED: stale pid=$old_pid, new pid=$fish_pid"
    return 0
end

function _acquire_lock --description "Acquire instance lock (atomic mkdir; flock(1) reclaim if stale)"
    set -g LOCK_DIR "$_RY_HOME_DIR/.lock"
    set -g LOCK_FILE "$LOCK_DIR/pid"
    command mkdir -p -- (dirname -- "$LOCK_DIR") 2>/dev/null; or true
    _acquire_lock_fresh
    set -l _fresh_rc $status
    test $_fresh_rc -eq 0; and return 0
    test $_fresh_rc -eq 1; and return 1
    # rc=2: LOCK_DIR exists, fall through to stale-lock reclaim
    _reclaim_stale_lock
    return $status
end

# Signal handling: tmpfiles → lock release → keepalive

function _do_cleanup --description "Master cleanup: remove tmpfiles, release lock, kill children, kill keepalive"
    _cleanup_tmpfiles
    set -l _stuck_tmpfiles
    for _tf in $_TRACKED_TMPFILES
        if test -d "$_tf"
            command rm -rf --preserve-root -- "$_tf" 2>/dev/null; or set -a _stuck_tmpfiles "$_tf"
        else if test -f "$_tf"
            command rm -f -- "$_tf" 2>/dev/null; or set -a _stuck_tmpfiles "$_tf"
        end
    end
    if test (count $_stuck_tmpfiles) -gt 0; and command -q sudo; and sudo -n true 2>/dev/null
        for _tf in $_stuck_tmpfiles
            if string match -q '/etc/*' -- "$_tf"; or string match -q '/boot/*' -- "$_tf"; or string match -q '/var/*' -- "$_tf"
                if sudo -n test -d "$_tf" 2>/dev/null
                    sudo -n rm -rf --preserve-root -- "$_tf" 2>/dev/null
                else if sudo -n test -f "$_tf" 2>/dev/null
                    sudo -n rm -f -- "$_tf" 2>/dev/null
                end
            end
        end
    end
    set --erase _TRACKED_TMPFILES
    set -l _tmpdir (set -q TMPDIR; and test -n "$TMPDIR"; and printf '%s\n' "$TMPDIR"; or printf '%s\n' /tmp)
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type f -user $_MY_UID -delete 2>/dev/null
    command find "$_tmpdir" -mindepth 2 -maxdepth 2 -path "$_tmpdir/ry-*" -type f -user $_MY_UID -delete 2>/dev/null
    command find "$_tmpdir" -maxdepth 1 -name 'ry-*' -type d -empty -user $_MY_UID -delete 2>/dev/null
    set --erase _KCONFIG_DATA
    set --erase _KCONFIG_LOADED
    set --erase _RY_SKIP_IWD
    set --erase _RY_ESP_PATH
    set --erase _RY_SYSTEMD_VER
    # Release LOCK_DIR mutex
    set -q _RY_HOLDS_LOCK; and set -q LOCK_DIR; and command rm -rf --preserve-root -- "$LOCK_DIR" 2>/dev/null
    _kill_sudo_keepalive
    if command -q pkill
        command pkill -TERM -P $fish_pid 2>/dev/null
        command sleep $_RY_SLEEP_FRAC 2>/dev/null
        command pkill -KILL -P $fish_pid 2>/dev/null
    end
end

function _kill_sudo_keepalive --description "Terminate the background sudo credential refresh loop"
    if set -q SUDO_KEEPALIVE_PID; and test -n "$SUDO_KEEPALIVE_PID"
        # PID re-verify before kill: closes a narrow
        if kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            # pkill -P reaps descendants so they do not
            command -q pkill; and command pkill -TERM -P $SUDO_KEEPALIVE_PID 2>/dev/null
            command kill -- $SUDO_KEEPALIVE_PID 2>/dev/null
            # SIGTERM→sleep→SIGKILL: child disowned
            command sleep $_RY_SLEEP_FRAC 2>/dev/null
            if kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
                command -q pkill; and command pkill -KILL -P $SUDO_KEEPALIVE_PID 2>/dev/null
                command kill -KILL -- $SUDO_KEEPALIVE_PID 2>/dev/null
            end
        end
        set --erase SUDO_KEEPALIVE_PID
    end
    if set -q SUDO_KEEPALIVE_ERR; and test "$SUDO_KEEPALIVE_ERR" != /dev/null
        _rm_tmp "$SUDO_KEEPALIVE_ERR" false
    end
    set --erase SUDO_KEEPALIVE_ERR
end

function _check_sudo_keepalive --description "Warn if sudo keepalive has expired; surface child stderr if available"
    if set -q SUDO_KEEPALIVE_PID; and test -n "$SUDO_KEEPALIVE_PID"
        if not kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
            set -l _reason ""
            if set -q SUDO_KEEPALIVE_ERR; and test "$SUDO_KEEPALIVE_ERR" != /dev/null; and test -s "$SUDO_KEEPALIVE_ERR"
                set _reason (command head -n 1 -- "$SUDO_KEEPALIVE_ERR" 2>/dev/null | string trim)
            end
            if test -n "$_reason"
                _warn "Sudo keepalive expired — operations may require re-authentication ($_reason)"
            else
                _warn "Sudo keepalive expired — operations may require re-authentication"
            end
            _log "SUDO_KEEPALIVE_EXPIRED: pid=$SUDO_KEEPALIVE_PID reason='$_reason'"
            set --erase SUDO_KEEPALIVE_PID
        end
    end
end

# Summary counters for JSONL footer
set -g VERIFY_OK 0
set -g VERIFY_FAIL 0
set -g VERIFY_WARN 0
set -g VERIFY_GEN_FAIL 0
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
            # _do_cleanup added
            _write_footer "$argv[2]" cleanup_exit
            _do_cleanup
        case '*'
            _err "_teardown: unknown mode '$mode'"
            return 1
    end
end

function _cleanup_other --on-signal USR1 --on-signal USR2 --on-signal ABRT --description "Signal handler: clean up on USR1/USR2/ABRT"
    test "$_CLEANUP_DONE" = true; and return 0
    _cleanup $argv
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
        case USR1 SIGUSR1
            set _sig_exit 138
        case USR2 SIGUSR2
            set _sig_exit 140
        case ABRT SIGABRT
            set _sig_exit 134
    end
    _teardown signal $_sig_exit
    if test "$_RY_INSTALL_SOURCED" = true
        set -g _RY_INSTALL_LAST_EXIT $_sig_exit
        set -g _RY_INSTALL_BAILING true
        _ry_erase_handlers
        _ry_namespace_cleanup bail
        return $_sig_exit
    end
    exit $_sig_exit
end

function _cleanup_pipe --on-signal PIPE --description "Signal handler: clean up on SIGPIPE (broken pipe)"
    test "$_CLEANUP_DONE" = true; and return 0
    set -g _CLEANUP_DONE true
    _teardown pipe
    if test "$_RY_INSTALL_SOURCED" = true
        set -g _RY_INSTALL_LAST_EXIT 141
        set -g _RY_INSTALL_BAILING true
        _ry_erase_handlers
        _ry_namespace_cleanup bail
        return 141
    end
    exit 141
end

function _cleanup_on_exit --on-event fish_exit --description "Exit handler: ensure cleanup runs on fish_exit"
    set -l _exit_status $status
    # prefer _RY_INSTALL_LAST_EXIT over the fish status var
    if set -q _INTENDED_EXIT_CODE
        set _exit_status $_INTENDED_EXIT_CODE
    else if set -q _RY_INSTALL_LAST_EXIT
        set _exit_status $_RY_INSTALL_LAST_EXIT
    end
    test "$_CLEANUP_DONE" = true; and return 0
    _teardown exit $_exit_status
end

# === GTR9_PRO BUILT-IN DEFAULTS ===
set -g PROFILE_NAME gtr9_pro
set -g PROFILE_DESC "Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S"
# 1:1 mapping to _ry_get_file_content
set -g SYSTEM_DESTINATIONS \
    "/boot/loader/loader.conf" \
    "/etc/kernel/cmdline" \
    "/etc/sdboot-manage.conf" \
    "/etc/mkinitcpio.conf" \
    "/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf" \
    "/etc/systemd/logind.conf.d/99-cachyos-logind.conf" \
    "/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf" \
    "/etc/iwd/main.conf" \
    "/etc/NetworkManager/conf.d/99-cachyos-nm.conf" \
    "/etc/drirc" \
    "/etc/sysctl.d/99-cachyos-sysctl.conf"
set -g USER_DESTINATIONS \
    "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" \
    "$HOME/.config/environment.d/10-environment.conf" \
    "$HOME/.config/systemd/user/ssh-agent.service"
set -g SERVICE_DESTINATIONS \
    "/etc/systemd/system/cpupower-epp.service"
set -g _RY_MANAGED_FILE_COUNT (count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS)
set -g LOADER_DEFAULT "@saved"
set -g LOADER_TIMEOUT 0
set -g LOADER_CONSOLE_MODE keep
set -g LOADER_EDITOR no
set -g SDBOOT_DEFAULT_ENTRY manual
set -g SDBOOT_OVERWRITE yes
set -g SDBOOT_REMOVE_EXISTING yes
set -g SDBOOT_REMOVE_OBSOLETE yes
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
# systemd hooks; no resume hook
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
# Udev; ntsync autoloaded via wine-cachyos
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
# Supplements vendor 70-cachyos-settings.conf
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
set -g _RY_PKG_MANAGED_SERVICES NetworkManager.service
set -g BOOT_SPACE_CRIT 200
set -g BOOT_SPACE_WARN 500
set -g ROOT_AVAIL_CRIT 2
set -g ROOT_AVAIL_WARN 5
set -g BOOT_TIME_TARGET 15
set -g EXPECTED_CPU_MATCH "Ryzen AI Max"

function _ir_resolve_root_uuid --description "Cache root UUID into _ROOT_UUID; gates absence by mode (preflight-fatal except --check log-only)"
    set -g _ROOT_UUID (findmnt -no UUID / 2>/dev/null)
    test -n "$_ROOT_UUID"; and not string match -qr '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' -- "$_ROOT_UUID"; and _err_loud "Root UUID has invalid shape (got: $_ROOT_UUID) — refusing to cache"; and set --erase _ROOT_UUID
    test -n "$_ROOT_UUID"; and return 0
    switch "$MODE"
        case check
            _log "ROOT_UUID_UNAVAILABLE: findmnt failed (silent for --check)"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        case install install-file verify-static verify-runtime
            _err_loud "Cannot detect root UUID (findmnt failed) — /etc/kernel/cmdline cannot be generated"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        case '*'
            _log "ROOT_UUID_UNAVAILABLE: mode=$MODE — non-fatal for this mode"
    end
end

function _ir_validate_timing --description "Defensive bounds on SUDO_KEEPALIVE_INTERVAL + NM_RESTART_DELAY; resets to safe defaults"
    if not string match -qr '^[1-9][0-9]*$' -- "$SUDO_KEEPALIVE_INTERVAL"
        _warn "SUDO_KEEPALIVE_INTERVAL='$SUDO_KEEPALIVE_INTERVAL' invalid — resetting to 45"
        _log "INVALID_SUDO_KEEPALIVE_INTERVAL: value=$SUDO_KEEPALIVE_INTERVAL — using default 45"
        set -g SUDO_KEEPALIVE_INTERVAL 45
    end
    if not string match -qr '^[1-9][0-9]*$' -- "$NM_RESTART_DELAY"
        _warn "NM_RESTART_DELAY='$NM_RESTART_DELAY' invalid — resetting to 3"
        _log "INVALID_NM_RESTART_DELAY: value=$NM_RESTART_DELAY — using default 3"
        set -g NM_RESTART_DELAY 3
    end
end

function _ir_precompute_caches --description "Precompute _SYS_TMP_DIRS, _USR_TMP_DIRS, _PROFILE_USES_WIFI_BACKEND from destination lists"
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
    set -g _PROFILE_USES_WIFI_BACKEND false
    for _d in $SYSTEM_DESTINATIONS
        if string match -q '*nm.conf' -- "$_d"; or string match -q '*/iwd/*' -- "$_d"
            set -g _PROFILE_USES_WIFI_BACKEND true; break
        end
    end
end

function _ir_validate_counts --description "Refuse to deploy when KERNEL_PARAMS / LOGIND_IGNORE_KEYS / ENV_VARS / SYSCTL_VALUES / PKGS_ADD / PKGS_DEL / MASK count drift from documented invariants"
    set -l _expect KERNEL_PARAMS:15 LOGIND_IGNORE_KEYS:9 ENV_VARS:11 SYSCTL_VALUES:16 PKGS_ADD:14 PKGS_DEL:8 AUR_PKGS:1 MASK:10
    for _kv in $_expect
        set -l _parts (string split -m1 ':' -- "$_kv")
        set -l _name $_parts[1]
        set -l _want $_parts[2]
        set -l _got (count $$_name)
        if test "$_got" -ne "$_want"
            _err_loud "$_name count drift: got=$_got expected=$_want — README/script desync, refuse to deploy"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        end
    end
end

function _init_runtime --description "Cache root UUID, validate hardware sanity, validate timing + count invariants, precompute tmp-dir cache"
    _ir_resolve_root_uuid
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    if set -q EXPECTED_CPU_MATCH; and test -n "$EXPECTED_CPU_MATCH"
        set -l _cpu_model (command grep -m1 -- 'model name' /proc/cpuinfo 2>/dev/null | command sed 's/.*: //')
        test -n "$_cpu_model"; and not string match -q -i -- "*$EXPECTED_CPU_MATCH*" "$_cpu_model"; and _warn "Built-in defaults expect $EXPECTED_CPU_MATCH but detected: $_cpu_model"
    end
    _ir_validate_timing
    _ir_validate_counts
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    _ir_precompute_caches
    for _kp in $KERNEL_PARAMS
        if string match -qr -- '\s' "$_kp"; or string match -q -- '*"*' "$_kp"
            _err_loud "KERNEL_PARAMS member contains whitespace or quote: '$_kp' — refuse to deploy (would corrupt cmdline / LINUX_OPTIONS)"
            _pre_dispatch_exit $EXIT_PREFLIGHT
        end
    end
end

function _content__boot_loader_loader.conf --description "Embedded content for /boot/loader/loader.conf"
    printf '%s\n' "# systemd-boot loader configuration" "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"
end

function _content__etc_kernel_cmdline --description "Embedded content for /etc/kernel/cmdline"
    test -z "$_ROOT_UUID"; and return $EXIT_GEN_NOUUID
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
    _resolve_systemd_ver
    for key in $LOGIND_IGNORE_KEYS
        if test "$key" = HandleSecureAttentionKey
            test -z "$_RY_SYSTEMD_VER"; or test "$_RY_SYSTEMD_VER" -lt 256; and continue
        end
        printf '%s\n' "$key=ignore"
    end
end

function _content__etc_systemd_coredump.conf.d_99-cachyos-coredump.conf --description "Embedded content for /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf"
    printf '%s\n' "# Disable coredump storage — Wine/Proton crashes can write multi-GB dumps" "[Coredump]" "Storage=none" "ProcessSizeMax=0"
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

# FISH-LINT-DIRECTIVE: do-not-format — do NOT run `fish_indent -w` on this function; the literal 'end' in the trailing printf-arg below would be unquoted and break the embedded content.
function _content_HOME_.config_fish_conf.d_10-ssh-auth-sock.fish --description "Embedded content for \$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"
    printf '%s\n' '# SSH agent socket for fish shell -- priority: forwarded > gcr > systemd' 'if status is-interactive; and set -q XDG_RUNTIME_DIR; and not set -q SSH_CONNECTION' '    if test -S "$XDG_RUNTIME_DIR/gcr/ssh"' '        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"' '    else if test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"' '        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"' '    end' 'end' # lint:ignore (literal printf-arg, not a block terminator)
end

function _content_HOME_.config_environment.d_10-environment.conf --description "Embedded content for \$HOME/.config/environment.d/10-environment.conf"
    printf '%s\n' "# Environment variables for systemd user services and graphical sessions — loaded by systemd --user (COSMIC, Flatpak, D-Bus activated apps)"
    printf '%s\n' 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket'
    for var in $ENV_VARS
        printf '%s\n' "$var"
    end
end

function _content_HOME_.config_systemd_user_ssh-agent.service --description "Embedded content for \$HOME/.config/systemd/user/ssh-agent.service"
    printf '%s\n' '[Unit]' 'Description=SSH authentication agent' '' '[Service]' 'Type=simple' 'ExecStart=/usr/bin/ssh-agent -D -a %t/ssh-agent.socket' 'Restart=on-failure' 'RestartSec=5' '' '[Install]' 'WantedBy=default.target'
end

function _content__etc_systemd_system_cpupower-epp.service --description "Embedded content for /etc/systemd/system/cpupower-epp.service"
    # Service intentionally succeeds on partial EPP write
    printf '%s\n' '[Unit]' 'Description=Set CPU EPP to performance (amd_pstate=active: powersave governor + performance EPP)' 'After=cpupower.service' 'Wants=cpupower.service' 'ConditionPathExists=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference' 'ConditionPathExists=/usr/bin/bash' '' '[Service]' 'Type=oneshot' 'RemainAfterExit=yes' 'TimeoutStartSec=10' 'StandardError=journal' 'ExecStart=/usr/bin/bash -c \'shopt -s nullglob; for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$cpu" 2>/dev/null || echo "EPP write failed: $cpu" >&2; done; exit 0\'' '' '[Install]' 'WantedBy=multi-user.target'
end

function _content__etc_drirc --description "Embedded content for /etc/drirc"
    # RADV unified VRAM heap: lets UMA APUs treat system RAM as unified VRAM
    printf '%s\n' '<driconf>' '  <device>' '    <application name="Default">' '      <option name="radv_enable_unified_heap_on_apu"' '              value="true" />' '    </application>' '  </device>' '</driconf>'
end

function _content__etc_sysctl.d_99-cachyos-sysctl.conf --description "Embedded content for /etc/sysctl.d/99-cachyos-sysctl.conf"
    printf '%s\n' "# ry-install sysctl tunables (priority 99 — loaded after CachyOS vendor 70-cachyos-settings.conf; overrides net.core.netdev_max_backlog 4096 → 16384)"
    set -l _printed 0
    for entry in $SYSCTL_VALUES
        if not string match -qr '^\s*\S[^=]*=\s*\S' -- "$entry"
            functions -q _log; and _log "SYSCTL_SKIP_MALFORMED: '$entry' (require non-empty key=value)"
            continue
        end
        set -l parts (string split -m1 '=' -- "$entry")
        set -l key (string trim -- "$parts[1]")
        set -l val (string trim -- "$parts[2]")
        printf '%s = %s\n' "$key" "$val"
        set _printed (math $_printed + 1)
    end
    if test $_printed -ne (count $SYSCTL_VALUES)
        functions -q _log; and _log "SYSCTL_COUNT_MISMATCH: printed=$_printed expected="(count $SYSCTL_VALUES)
        return $EXIT_GEN_SYSCTL
    end
end

function _ry_get_file_content --argument-names dst --description "Generate expected content for a destination (dispatcher)"
    set -l fn "_content_"(_tmpfile_key "$dst")
    functions -q $fn; or return $EXIT_GEN_NOFN
    $fn
end

function _ensure_sudo_cached --description "Cache sudo credential once before parallel forking"
    not command -q sudo; and _err "Sudo credential cache failed: sudo not found"; and return 1
    set -l _sudo_err (mktemp -t ry-sudo-err.XXXXXX 2>/dev/null; or echo /dev/null)
    test "$_sudo_err" = /dev/null; and _log "MKTEMP_FAIL: ry-sudo-err — sudo error message will be unavailable"
    _track_tmpfile "$_sudo_err"
    # Probe sudo -n -v first
    sudo -n -v 2>"$_sudo_err"
    set -l _rc $status
    if test $_rc -ne 0
        # gate interactive `sudo -v` fallback on isatty 0+2
        if isatty 0; and isatty 2
            sudo -v 2>"$_sudo_err"
            set _rc $status
        else
            _log "SUDO_CACHE_NONINTERACTIVE: stdin or stderr is not a tty — refusing interactive sudo -v"
        end
    end
    if test $_rc -ne 0
        set -l _reason (command head -n 1 -- "$_sudo_err" 2>/dev/null)
        # gate on /dev/null sentinel.
        test "$_sudo_err" != /dev/null; and _rm_tmp "$_sudo_err" false
        _log "SUDO_CACHE_FAIL: $_reason"
        if test -n "$_reason"
            _err "Sudo credential cache failed: $_reason"
        else
            _err "Sudo credential cache failed"
        end
        return 1
    end
    test "$_sudo_err" != /dev/null; and _rm_tmp "$_sudo_err" false
    return 0
end

function _as --argument-names use_sudo --description "Prefix command with sudo or command based on use_sudo flag"
    test (count $argv) -lt 2; and _log "BUG: _as called without command (argv=$argv)"; and return 2
    test "$use_sudo" != true; and test "$use_sudo" != false; and _log "BUG: _as called with non-bool use_sudo='$use_sudo' (argv=$argv)"; and return 2
    if test "$use_sudo" = true
        sudo -n -- $argv[2..-1]
    else
        command $argv[2..-1]
    end
end

function _tmpfile_key --argument-names path --description "Generate filename key from destination path (\$HOME→HOME literal, then slash→underscore)"
    set -l p $path
    if string match -q -- "$HOME/*" "$p"
        set p HOME(string sub -s (math (string length -- "$HOME") + 1) -- "$p")
    else if test "$p" = "$HOME"
        set p HOME
    end
    string replace -a / _ -- "$p"
end

function _untrack_tmpfile --argument-names path --description "Remove a single literal path from _TRACKED_TMPFILES (no glob); erase global when list empties so source-mode bail paths do not leak the name"
    set -l _new
    for _tf in $_TRACKED_TMPFILES
        test "$_tf" = "$path"; and continue
        set -a _new "$_tf"
    end
    test (count $_new) -gt 0; and set -g _TRACKED_TMPFILES $_new; or set --erase _TRACKED_TMPFILES
end

function _rm_tmp --argument-names path use_sudo --description "Sudo-aware tmpfile delete + untrack (paired with _atomic_write_file family)"
    test -n "$path"; or return 0
    if test "$use_sudo" = true
        sudo -n rm -f -- "$path" 2>/dev/null
    else
        command rm -f -- "$path" 2>/dev/null
    end
    _untrack_tmpfile "$path"
end

function _track_tmpfile --argument-names path --description "Track a tmpfile/dir in _TRACKED_TMPFILES iff non-empty + not /dev/null sentinel; single source of truth for register-after-mktemp idiom"
    test -n "$path"; or return 0
    test "$path" = /dev/null; and return 0
    set -ga _TRACKED_TMPFILES "$path"
end

function _is_symlink --argument-names path use_sudo --description "Sudo-aware test -L probe"
    if test "$use_sudo" = true
        sudo -n test -L "$path"
    else
        test -L "$path"
    end
end

function _is_system_dst --argument-names dst --description "True if dst is a system path (requires sudo to read)"
    string match -q '/etc/*' -- "$dst"; or string match -q '/boot/*' -- "$dst"; or string match -q '/usr/*' -- "$dst"; or string match -q '/var/*' -- "$dst"
end

function _installed_bytes --argument-names dst --description "Raw bytes of installed file. Returns: 0=ok (bytes on stdout), 1=read fail, 2=sudo lapse (system dst)."
    set -l _bytes
    if _is_system_dst "$dst"
        sudo -n true 2>/dev/null; or return 2
        sudo -n test -r "$dst" 2>/dev/null; or return 1
        set _bytes (sudo -n cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines)
        set -l _ps $pipestatus
        test $_ps[1] -eq 0; or return 1
    else
        test -r "$dst"; or return 1
        set _bytes (command cat -- "$dst" 2>/dev/null | string collect --no-trim-newlines)
        set -l _ps $pipestatus
        test $_ps[1] -eq 0; or return 1
    end
    printf '%s' "$_bytes" | string collect --no-trim-newlines --allow-empty
    return 0
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
        test "$_u" = lvm2-monitor.service; and test "$_has_lvm" = true; and continue
        echo "$_u"
    end
end

# LOGGING, MESSAGE OUTPUT, AND VERIFICATION COUNTERS

function _json_str --description "Escape a string for safe JSON embedding"
    set -l s "$argv[1]"
    not string match -qr -- '[\x00-\x1f"\\\\\x7f]' "$s"; and printf '%s' "$s" | string collect --allow-empty; and return
    set s (string replace -a -- \\ \\\\ "$s" | string collect)
    set s (string replace -a -- '"' '\\"' "$s" | string collect)
    set s (string replace -a -- \n '\\n' "$s" | string collect)
    set s (string replace -a -- \r '\\r' "$s" | string collect)
    set s (string replace -a -- \t '\\t' "$s" | string collect)
    set s (string replace -ar -- '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]' '?' "$s" | string collect)
    printf '%s' "$s" | string collect --allow-empty
end

function _log_section --argument-names name --description "Emit a section-event JSONL marker"
    _log "=== $name ==="
end

function _log --description "Append a timestamped JSONL line to LOG_FILE"
    set -q _RY_NO_LOG; and return 0
    # parallel-child guard.
    set -q _RY_LOG_OWNER_PID; and test "$_RY_LOG_OWNER_PID" != "$fish_pid"; and return 0
    if not test -f "$LOG_FILE"
        set -l _prev_umask (umask)
        umask 0177
        command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null
        set -l _create_rc $status
        umask $_prev_umask
        if test $_create_rc -ne 0
            not set -q _RY_LOG_WRITE_FAIL; and set -g _RY_LOG_WRITE_FAIL true
            return 0
        end
    end
    set -l _ts (date '+%Y-%m-%dT%H:%M:%S%z')
    set -l raw (string join -- " " $argv)
    set -l event message
    set -l data "$raw"
    if string match -qr '^=== .* ===$' -- "$raw"
        set event section
        set data (string match -rg '^=== (.*) ===$' -- "$raw" | string trim --)
    else if string match -qr '^[A-Z][A-Z_]*: ' -- "$raw"
        set event (string lower (string match -r '^[A-Z][A-Z_]*' -- "$raw"))
        set data (string replace -r '^[A-Z][A-Z_]*: *' '' -- "$raw")
    end
    set event (string replace -ra '[^a-z0-9_]' '' -- "$event")
    set data (_json_str "$data")
    if test (string length -- "$data") -gt 4096
        set -l cut 4093
        set -l tail3 (string sub -s (math $cut - 7) -l 8 -- "$data")
        set -l _esc_match (string match -r '\\\\([tnrbf]|u[0-9a-fA-F]{0,4}|\\\\?)$' -- "$tail3")
        if test -n "$_esc_match"
            set -l _esc_len (string length -- "$_esc_match")
            test "$_esc_len" -gt 0; and set cut (math $cut - $_esc_len)
        end
        set data (string sub -l $cut -- "$data")"..."
    end
    printf '{"ts":"%s","event":"%s","data":"%s"}\n' "$_ts" "$event" "$data" >>"$LOG_FILE" 2>/dev/null
    set -l _write_rc $status
    test $_write_rc -eq 0; and not set -q _RY_LOG_WRITTEN; and set -g _RY_LOG_WRITTEN true
    if test $_write_rc -ne 0; and not set -q _RY_LOG_WRITE_FAIL
        set -g _RY_LOG_WRITE_FAIL true
    end
end

function _msg_print --argument-names level --description "Internal: leveled message to stderr (color-aware, no log/counter); emits only when QUIET=false. _err_loud is the bypass for fatal-preflight."
    set -l msg (string join -- " " $argv[2..])
    test -z "$msg"; and return 0
    test "$QUIET" = false; or return 0
    if test "$NO_COLOR" = true; or not isatty 2
        echo "[$level] $msg" >&2
        return 0
    end
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
        printf '[%s]' "$level"
        set_color normal
        echo " $msg"
    end >&2
end

function _msg --argument-names level --description "Format and print a leveled status message"
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
    _msg_print $argv
end

function _msg_nocount --argument-names level --description "Like _msg but skips VERIFY_* counter bump (caller increments a different counter)"
    set -l msg (string join -- " " $argv[2..])
    _log "$level: $msg"
    _msg_print $argv
end

function _ok --description "Print an OK-level status message"
    _msg OK $argv
end
function _fail --description "Print a FAIL-level status message"
    _msg FAIL $argv
end
function _fail_silent --description "Print a FAIL-level message without bumping VERIFY_FAIL (caller increments a different counter, e.g. VERIFY_GEN_FAIL)"
    _msg_nocount FAIL $argv
end
function _info --description "Print an INFO-level status message"
    _msg INFO $argv
end
function _warn --description "Print a WARN-level status message"
    _msg WARN $argv
end
function _err --description "Print an ERR-level status message"
    _msg ERR $argv
end
function _err_loud --description "Fatal-preflight err: always emits [ERR] to stderr regardless of QUIET; logs to JSONL. Use only at sites where the user MUST see the cause of an imminent bail."
    set -l msg (string join -- " " $argv)
    _log "ERR: $msg"
    if test "$NO_COLOR" = true; or not isatty 2
        echo "[ERR] $msg" >&2
    else
        begin
            set_color red
            printf '[ERR]'
            set_color normal
            echo " $msg"
        end >&2
    end
end

function _echo --description "Print a plain message without level prefix"
    _log "ECHO: $argv"
    if test "$QUIET" = false
        echo "$argv" >&2
    end
end

function _verify_summary --description "Print verification pass/fail/warn summary"
    _echo
    _echo "VERIFICATION SUMMARY"
    _echo
    set -l snap_ok $VERIFY_OK
    set -l snap_fail $VERIFY_FAIL
    set -l snap_warn $VERIFY_WARN
    set -l snap_gen_fail 0
    set -q VERIFY_GEN_FAIL; and set snap_gen_fail $VERIFY_GEN_FAIL
    set -g VERIFY_MODE false
    set -l summary "Results: $snap_ok OK"
    test "$snap_warn" -gt 0; and set summary "$summary, $snap_warn WARN"
    test "$snap_fail" -gt 0; and set summary "$summary, $snap_fail FAIL"
    test "$snap_gen_fail" -gt 0; and set summary "$summary, $snap_gen_fail GEN_FAIL"
    if test "$snap_fail" -gt 0; or test "$snap_gen_fail" -gt 0
        _fail "$summary"
        _log "VERIFY_RESULT: status=fail ok=$snap_ok fail=$snap_fail warn=$snap_warn gen_fail=$snap_gen_fail"
        return 1
    else if test "$snap_warn" -gt 0
        _warn "$summary"
        _log "VERIFY_RESULT: status=warn ok=$snap_ok fail=$snap_fail warn=$snap_warn gen_fail=$snap_gen_fail"
        return 0
    else
        _ok "$summary"
        _log "VERIFY_RESULT: status=ok ok=$snap_ok fail=$snap_fail warn=$snap_warn gen_fail=$snap_gen_fail"
        return 0
    end
end


function _progress_init --description "Open scroll region; draw initial bar"
    # _PROG_TOTAL derived from count $_PROG_STEPS, not hardcoded
    set -g _PROG_STEPS Preflight Packages Configuration Services Boot Finalize
    set -g _PROG_CUR 0
    set -g _PROG_TOTAL (count $_PROG_STEPS)
    set -g _PROG_START (date +%s)
    set -g _PROG_STEP_START $_PROG_START
    set -g _PROG_STEP_NAME ""
    set -g _PROG_PINNED false
    isatty 2; or return 0
    # ncurses-tinfo may be absent on minimal installs; skip pinned bar
    command -q tput; or return 0
    set -q TMUX; and return 0
    set -q STY; and return 0
    string match -q 'screen*' -- "$TERM"; and return 0
    set -q MOSH_CONNECTION; and return 0
    string match -q 'mosh*' -- "$TERM_PROGRAM"; and return 0
    set -l rows (tput lines 2>/dev/null)
    string match -qr '^\d+$' -- "$rows"; or return 0
    test $rows -ge 10; or return 0
    tput cup 0 0 >/dev/null 2>&1; or return 0
    set -g _PROG_PINNED true
    set -g _PROG_ROWS $rows
    # DECSTBM (CSI Ps;Ps r) homes the cursor to (1,1) as a side effect; explicitly position
    # cursor at the bottom of the scroll region so subsequent output (e.g. the sudo password
    # prompt in _install_preflight) appears just above the pinned bar instead of at the top.
    printf '\e[1;%dr\e[%d;1H' (math $_PROG_ROWS - 1) (math $_PROG_ROWS - 1) >&2
    _progress_redraw "" 0
end

function _progress --argument-names name outcome --description "Advance progress counter and emit step-end log; optional outcome marker (e.g. 'skip')"
    # validate name against known step list to catch caller drift early
    not contains -- "$name" $_PROG_STEPS; and _log "BUG: _progress called with unknown step name='$name' (known: "(string join ',' -- $_PROG_STEPS)")"
    set -g _PROG_CUR (math "min($_PROG_CUR + 1, $_PROG_TOTAL)")
    set -l now (date +%s)
    test -n "$_PROG_STEP_NAME"; and _log "PROG_STEP_END: name=$_PROG_STEP_NAME secs="(math $now - $_PROG_STEP_START)
    set -g _PROG_STEP_NAME $name
    set -g _PROG_STEP_START $now
    set -l _outcome_marker
    test -n "$outcome"; and set _outcome_marker " outcome=$outcome"
    _log "PROG_STEP_START: [$_PROG_CUR/$_PROG_TOTAL] $name$_outcome_marker"
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

function _progress_done --description "Finalize progress bar (or hold position on skip-cascade) and log elapsed seconds"
    set -l elapsed (math (date +%s) - $_PROG_START)
    set -l _skip false
    set -q _PROG_FINALIZED_SKIP; and test "$_PROG_FINALIZED_SKIP" = true; and set _skip true
    _log "PROG_DONE: elapsed_secs=$elapsed skip=$_skip"
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r' >&2
    if test "$_skip" = true
        set -l pct (math "floor($_PROG_CUR * 100 / $_PROG_TOTAL)")
        printf '\e[%d;1H\e[K[%s] %3d%% Aborted (%ds)\n' \
            $_PROG_ROWS (string repeat -n 40 '░') $pct $elapsed >&2
    else
        printf '\e[%d;1H\e[K[%s] 100%% Done (%ds)\n' \
            $_PROG_ROWS (string repeat -n 40 '█') $elapsed >&2
    end
    set -g _PROG_PINNED false
end

function _progress_teardown --description "Clear pinned progress bar and reset scroll region (signal/abort path)"
    test "$_PROG_PINNED" = true; or return 0
    printf '\e[r\e[%d;1H\e[K\n' $_PROG_ROWS >&2
    set -g _PROG_PINNED false
end

function _progress_on_winch --on-signal WINCH --description "Re-anchor progress bar on terminal resize"
    test "$_PROG_PINNED" = true; or return 0
    set -l _new_rows (tput lines 2>/dev/null)
    string match -qr '^\d+$' -- "$_new_rows"; or return 0
    test "$_new_rows" -lt 10; and return 0
    set -g _PROG_ROWS $_new_rows
    # DECSTBM homes the cursor; bracket with DECSC (\e7) / DECRC (\e8) so output streaming
    # mid-install isn't interrupted by a cursor jump to (1,1) on terminal resize.
    printf '\e7\e[1;%dr\e8' (math $_PROG_ROWS - 1) >&2
    _progress_redraw "$_PROG_STEP_NAME" $_PROG_CUR
end

function _redact_argv_elements --description "Per-element secret-flag redaction; emits NUL-delimited (whitespace-safe via | string split0). Single source of truth for --flag value / --flag=val redaction."
    set -l _redacted_argv
    set -l _eat_next false
    for _arg in $argv
        if test "$_eat_next" = true
            set -a _redacted_argv "[REDACTED]"
            set _eat_next false
            continue
        end
        set -l _matched false
        for _secret_flag in $_RY_SECRET_FLAGS
            if test "$_arg" = "$_secret_flag"
                set -a _redacted_argv "$_arg"
                set _eat_next true
                set _matched true
                break
            else if string match -q -- "$_secret_flag=*" "$_arg"
                set -a _redacted_argv "$_secret_flag=[REDACTED]"
                set _matched true
                break
            end
        end
        test "$_matched" = false; and set -a _redacted_argv "$_arg"
    end
    printf '%s\0' $_redacted_argv
end

function _run_redact_argv --description "NUL-emit wrapper around _redact_argv_elements (stable name for _run callers)"
    _redact_argv_elements $argv
end

function _run_resolve_timeout --description "Resolve RY_RUN_TIMEOUT to a usable seconds integer or empty (empty = disable); warns once on invalid values"
    not set -q RY_RUN_TIMEOUT; or test -z "$RY_RUN_TIMEOUT"; and echo $_RY_RUN_TIMEOUT_DEFAULT; and return
    test "$RY_RUN_TIMEOUT" = 0; and echo ""; and return
    string match -qr '^[1-9]\d*$' -- "$RY_RUN_TIMEOUT"; and echo "$RY_RUN_TIMEOUT"; and return
    if not set -q _RY_RUN_TIMEOUT_WARNED
        set -g _RY_RUN_TIMEOUT_WARNED true
        _warn "RY_RUN_TIMEOUT='$RY_RUN_TIMEOUT' is invalid (expected positive integer or 0 to disable) — using default "$_RY_RUN_TIMEOUT_DEFAULT"s"
        _log "RY_RUN_TIMEOUT_INVALID: value=$RY_RUN_TIMEOUT — using default $_RY_RUN_TIMEOUT_DEFAULT"
    end
    echo $_RY_RUN_TIMEOUT_DEFAULT
end

function _run --description "Execute a command with logging, stdout/stderr capture, and timeout enforcement"
    test (count $argv) -eq 0; and _log "BUG: _run called with no arguments"; and return 1
    string match -q -- '-*' "$argv[1]"; and _log "BUG: _run called with dash-prefixed argv[1]='$argv[1]' — refusing"; and return 2
    set -l _redacted_argv (_run_redact_argv $argv | string split0)
    set -l log_cmd (string join -- " " $_redacted_argv)
    # Redact ry-* tmp paths; TMPDIR-aware with /tmp/ry-* fallback.
    set -q TMPDIR; and test -n "$TMPDIR"; and test "$TMPDIR" != /tmp; and set -l _td_re (string escape --style=regex -- "$TMPDIR"); and set log_cmd (string replace -ar -- "$_td_re"'/ry-[A-Za-z0-9_.-]+' '$TMPDIR/ry-[REDACTED]' "$log_cmd")
    set log_cmd (string replace -ar -- '/tmp/ry-[A-Za-z0-9_.-]+' '/tmp/ry-[REDACTED]' "$log_cmd")
    _log "RUN: $log_cmd"
    set -l _run_dir (mktemp -d -t ry-run.XXXXXX 2>/dev/null)
    _track_tmpfile "$_run_dir"
    if test -z "$_run_dir"; or not test -d "$_run_dir"
        _log "RUN_ABORT: mktemp -d failed — refusing to execute without stderr capture"
        _err "_run: cannot allocate tmpdir for stdout/stderr capture — aborting command"
        return 1
    end
    set -l stderr_tmp "$_run_dir/stderr"
    set -l stdout_tmp "$_run_dir/stdout"
    # SECURITY: $argv internal callers only
    set -l _run_timeout (_run_resolve_timeout)
    if test -n "$_run_timeout"; and command -q timeout
        command timeout --foreground --kill-after=10 "$_run_timeout" $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    else
        command $argv </dev/null >"$stdout_tmp" 2>"$stderr_tmp"
    end
    set -l ret $status
    if test -s "$stderr_tmp"
        _log "STDERR: "(string join -- " | " (command head -n 50 -- "$stderr_tmp"))
        if test "$QUIET" = false
            command cat -- "$stderr_tmp" >&2
        else if test $ret -ne 0
            command head -n 5 -- "$stderr_tmp" >&2
        end
    end
    if test -s "$stdout_tmp"
        _log "OUTPUT: "(string join -- " | " (command head -n 100 -- "$stdout_tmp"))
        test "$QUIET" = false; and command cat -- "$stdout_tmp" >&2
    end
    # stdout_tmp & stderr_tmp are inside _run_dir
    test -d "$_run_dir"; and command rm -rf --preserve-root -- "$_run_dir" 2>/dev/null; and _untrack_tmpfile "$_run_dir"
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

function _chk_perms --argument-names path expected_perms expected_owner use_sudo --description "Compare file mode+owner; returns 1 on mismatch"
    set -l _po
    if test "$use_sudo" = true
        set _po (sudo -n stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    else
        set _po (command stat -c '%a %U:%G' -- "$path" 2>/dev/null)
    end
    # stat-fail guard
    test -z "$_po"; and _fail "  $path: stat failed (file disappeared or unreadable)"; and return 1
    set -l _parts (string split -n ' ' -- "$_po")
    test "$_parts[1]" != "$expected_perms"; or test "$_parts[2]" != "$expected_owner"; and _fail "  $path: $_parts[1] $_parts[2] (expected: $expected_perms $expected_owner)"; and return 1
    return 0
end

function _chk_path_mode_in --argument-names path label --description "Verify file mode is in the accepted-modes list (passed via argv[3..])"
    test -e "$path"; or return 0
    set -l _m (command stat -c '%a' -- "$path" 2>/dev/null)
    if contains -- "$_m" $argv[3..]
        _ok "  $label: $_m"
    else
        _warn "  $label: $_m (should be: $argv[3..])"
    end
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

function _chk_file --argument-names filepath --description "Verify a file exists (plain test first; sudo fallback for /boot when permission denied)"
    _log "CHECK_FILE: $argv[1]"
    test -f "$argv[1]"; and _ok "File exists: $argv[1]"; and return 0
    if string match -q '/boot/*' -- "$argv[1]"
        not command -q sudo; and _fail "File check requires sudo: $argv[1]"; and return 1
        sudo -n test -f "$argv[1]" 2>/dev/null; and _ok "File exists: $argv[1]"; and return 0
    end
    _fail "File NOT FOUND: $argv[1]"
    return 1
end

function _cg_access_ok --argument-names file label is_boot --description "Pre-flight read access check; rc=0 ok, rc=1 fail (already _fail'd or _warn'd)"
    if test "$is_boot" = false
        test -r "$file"; and return 0
        test -f "$file"; and _fail "  $label: PERMISSION DENIED (need sudo?)"; or _fail "  $label: FILE NOT FOUND"
        return 1
    end
    not command -q sudo; and _fail "  $label: sudo required for /boot path"; and return 1
    not sudo -n true 2>/dev/null; and _warn "  $label: sudo cache lapsed — re-run with sudo -v"; and return 1
    not sudo -n test -f -- "$file" 2>/dev/null; and _fail "  $label: FILE NOT FOUND"; and return 1
    return 0
end

function _chk_grep --argument-names file pattern label --description "Verify a file contains an expected token (label defaults to pattern; whole-word match)"
    test -z "$label"; and set label "$pattern"
    _log "CHECK_GREP: $file for '$pattern'"
    set -l is_boot false
    string match -q '/boot/*' -- "$file"; and set is_boot true
    _cg_access_ok "$file" "$label" $is_boot; or return 1
    set -l _grep_flags -qwF
    set -l _stage1_rc 0; set -l _grep_rc 1
    if test "$is_boot" = true
        sudo -n grep -v '^[[:space:]]*#' -- "$file" 2>/dev/null | command grep $_grep_flags -- "$pattern" 2>/dev/null
    else
        command grep -v '^[[:space:]]*#' -- "$file" 2>/dev/null | command grep $_grep_flags -- "$pattern" 2>/dev/null
    end
    set _stage1_rc $pipestatus[1]; set _grep_rc $pipestatus[2]
    switch $_stage1_rc
        # proceed
        case 0
        case 1;  _fail "  $label: MISSING (file has no non-comment lines)"; return 1
        case '*'; _warn "  $label: cannot read file (stage-1 rc=$_stage1_rc — sudo lapse or read error)"; return 1
    end
    switch $_grep_rc
        case 0;  _ok "  $label: present"; return 0
        case 1;  _fail "  $label: MISSING"; return 1
        case '*'; _warn "  $label: grep error rc=$_grep_rc (binary/IO/regex) — cannot determine presence"; return 1
    end
end

function _chk_token_in --argument-names line token label --description "Verify a whole-word token is present in a config line; emit _ok or _fail"
    set -l _re (string escape --style=regex -- "$token")
    if string match -qr "\\b$_re\\b" -- "$line"
        _ok "  $label: present"
    else
        _fail "  $label: MISSING"
    end
end

function _ry_check_deps --description "Verify required packages are installed"
    _log "DEPS_CHECK_START"
    set -l missing
    # hard deps.
    for cmd in pacman systemctl mkinitcpio sdboot-manage findmnt sha256sum \
               stat date curl timeout mktemp awk head tail cut sed find \
               grep sort cat printf chmod chown mv rm tee ip getent \
               realpath basename dirname id flock bootctl sudo df mkdir rmdir
        command -q $cmd; or set -a missing $cmd
    end
    test (count $missing) -gt 0; and _err "missing: $missing"; and return 1
    set -l systemd_ver (systemctl --version 2>/dev/null | head -n 1 | string match -rg -- '^systemd (\d+)')
    test -n "$systemd_ver"; and test "$systemd_ver" -lt 250; and _warn "Systemd version $systemd_ver detected; some features require 250+"
    for cmd in journalctl dmesg modinfo pgrep free uptime zcat tput \
               swapon zramctl lsmod modprobe pkill nmcli ping
        command -q $cmd; or _warn "Expected tool not found: $cmd (from base packages)"
    end
    if set -q AUR_PKGS; and test (count $AUR_PKGS) -gt 0; and not command -q paru
        _warn "paru not found — AUR phase will fail (AUR_PKGS=$AUR_PKGS)"
        _info "  Install paru: sudo pacman -S --needed paru"
    end
    _log "DEPS_CHECK_OK"
    return 0
end

function _ry_check_network --description "Verify network connectivity (single HEAD + raw-IP fallback)"
    _log "NET_CHECK_START"
    # curl is a reqd dep
    curl -sfI --connect-timeout 3 --max-time 5 https://archlinux.org >/dev/null 2>&1; and _ok "Network connectivity: OK"; and return 0
    if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1
        # cover both DNS-broken and 443-egress-blocked modes
        _err "Network connectivity: HTTPS or DNS unreachable (raw-IP ICMP works; check /etc/resolv.conf or 443 egress)"
        return 1
    end
    _err "Network connectivity: FAILED — cannot reach archlinux.org or 1.1.1.1"
    return 1
end

function _check_avail --argument-names path divisor unit crit warn --description "Compare available bytes at path against crit/warn thresholds (in scaled units)"
    set -l _b (LC_ALL=C df --output=avail -B1 -- "$path" 2>/dev/null | tail -n 1 | string trim --)
    set -l _v ""
    test -n "$_b"; and string match -qr '^\d+$' -- "$_b"; and set _v (math "floor($_b / $divisor)")
    test -z "$_v"; or not string match -qr '^\d+$' -- "$_v"; and _warn "Could not determine disk space for $path"; and return 0
    if test "$_v" -lt $crit
        _err "Insufficient disk space on $path: $_v$unit available, need $crit$unit minimum"
        return 1
    else if test "$_v" -lt $warn
        _warn "Low disk space on $path: $_v$unit available"
    else
        _ok "Disk space on $path: $_v$unit available"
    end
    return 0
end

function _ry_check_disk_space --description "Verify sufficient free disk space for installation"
    _log "DISK_CHECK_START"
    _check_avail /     1073741824 GB $ROOT_AVAIL_CRIT $ROOT_AVAIL_WARN; or return 1
    _check_avail /boot 1048576    MB $BOOT_SPACE_CRIT $BOOT_SPACE_WARN; or return 1
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
    # handle all 5 ntsync states (was if/else handling only `unavailable`).
    switch $_ns
        case unavailable
            _warn "Kernel $kver: ntsync not available (expected builtin or module)"
        case loaded_nodev
            _warn "Kernel $kver: ntsync module loaded but /dev/ntsync missing"
        case missing
            _warn "Kernel $kver: ntsync module not loaded (kernel ≥6.14 supports it; check MODULES list)"
        case builtin loaded
            _ok "Kernel $kver: ntsync $_ns"
        case '*'
            _warn "Kernel $kver: ntsync unknown state '$_ns'"
    end
    if test "$major" -eq 6; and test "$minor" -eq 19
        test "$kver_patch" = 0; and _warn "Kernel 6.19.0: black screen regression on Strix Halo (CachyOS #23042)"; and _warn "  Recommend: downgrade to 6.18.x or upgrade to 6.19.1+"
    end
    return 0
end


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
            test -z "$hook"; and continue
            if test -f "/usr/lib/initcpio/install/$hook"; or test -f "/usr/lib/initcpio/hooks/$hook"; or test -f "/etc/initcpio/install/$hook"; or test -f "/etc/initcpio/hooks/$hook"
                _ok "  $hook: exists"
            else
                _fail "  $hook: NOT FOUND"
                set errors (math $errors + 1)
            end
        end
        test $errors -eq 0
        return $status
    end
    for hook in $hooks
        if not test -f "/usr/lib/initcpio/install/$hook"; and not test -f "/etc/initcpio/install/$hook"
            not test -f "/usr/lib/initcpio/hooks/$hook"; and not test -f "/etc/initcpio/hooks/$hook"; and _err "Invalid mkinitcpio hook: $hook"; and set errors (math $errors + 1)
        end
    end
    if test (count $hooks) -gt 0
        test "$hooks[1]" != base; and _err "Mkinitcpio hook order: 'base' must be first (found: $hooks[1])"; and set errors (math $errors + 1)
        set -l order_checks "autodetect:modconf" "systemd:sd-vconsole" "systemd:keyboard" "keyboard:sd-vconsole" "modconf:kms" "block:filesystems"
        for check in $order_checks
            set -l hook_before (string split ':' -- "$check")[1]
            set -l hook_after (string split ':' -- "$check")[2]
            set -l idx_a 0
            set -l idx_b 0
            for i in (seq (count $hooks))
                test "$hooks[$i]" = "$hook_before"; and set idx_a $i
                test "$hooks[$i]" = "$hook_after"; and set idx_b $i
            end
            test $idx_a -gt 0; and test $idx_b -gt 0; and test $idx_a -ge $idx_b; and _err "Mkinitcpio hook order: '$hook_before' must come before '$hook_after'"; and set errors (math $errors + 1)
        end
    end
    test $errors -eq 0
    return $status
end

function _ry_validate_mkinitcpio_modules --description "Validate mkinitcpio MODULES array entries"
    not command -q modinfo; and return 0
    for mod in $MKINITCPIO_MODULES
        not modinfo "$mod" >/dev/null 2>&1; and _warn "Module may not exist: $mod (continuing anyway)"
    end
    return 0
end

function _verify_unit_content --argument-names dst --description "Verify systemd unit content via tmpfile+_verify_unit_syntax"
    test (count $argv) -lt 2; and _log "BUG: _verify_unit_content called without content (dst=$dst)"; and return 2
    set -l content $argv[2..-1]
    command -q systemd-analyze; or return 0
    set -l _intended_scope system
    string match -q '*/.config/systemd/user/*' -- "$dst"; and set _intended_scope user
    set -l tmp (mktemp --suffix=.service -t ry-val-unit.XXXXXX 2>/dev/null)
    _track_tmpfile "$tmp"
    test -n "$tmp"; or begin
        _fail "  $dst: mktemp failed"
        return 1
    end
    command chmod -- 600 "$tmp" 2>/dev/null
    if not printf '%s\n' $content >"$tmp" 2>/dev/null
        _rm_tmp "$tmp" false
        _fail "  $dst: failed to write unit tmpfile for verification"
        return 1
    end
    _verify_unit_syntax "$tmp" (basename -- "$dst") "$_intended_scope"
    set -l rc $status
    _rm_tmp "$tmp" false
    return $rc
end

function _grep_kv --argument-names dst --description "Validate kv pairs (loader.conf space-sep; sdboot-manage.conf eq-sep)"
    test (count $argv) -lt 2; and _log "BUG: _grep_kv called without content (dst=$dst)"; and return 2
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
        case '*'
            # defensive default.
            _log "BUG: _grep_kv called for unsupported dst=$dst"
            return 2
    end
    for key in $keys
        # Escape key.
        set -l _key_re (string escape --style=regex -- "$key")
        string match -qr -- "^$_key_re$sep" $content; or begin
            _fail "  $dst: missing key '$key'"
            return 1
        end
    end
    return 0
end

function _grep_kparam --argument-names dst --description "Validate kernel cmdline has required tokens (root=UUID=, rw) and every declared \$KERNEL_PARAMS member"
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
        if not string match -qr -- "(^|\s)$_kp_re(\s|\$)" $argv[2..-1]
            _fail "  $dst: missing declared KERNEL_PARAMS token '$_kp'"
            return 1
        end
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

function _grep_xml_tag --argument-names dst --description "Validate drirc XML has required tags"
    test (count $argv) -lt 2; and _log "BUG: _grep_xml_tag called without content (dst=$dst)"; and return 2
    set -l content $argv[2..-1]
    # tightened '<application' → '<application '.
    for tag in '<driconf>' '<device>' '<application '
        string match -q -- "*$tag*" $content; or begin
            _fail "  $dst: missing XML tag '$tag'"
            return 1
        end
    end
    return 0
end

function _check_env_ssh_auth_sock --description "Phase 3: environment.d has SSH_AUTH_SOCK= and no %t literal"
    set -l dst "$HOME/.config/environment.d/10-environment.conf"
    set -l content (_ry_get_file_content "$dst")
    test $status -ne 0; and _fail "  $dst: content generator failed"; and return 1
    string match -qr '^SSH_AUTH_SOCK=' -- $content; or begin
        _fail "  $dst: missing SSH_AUTH_SOCK="
        return 1
    end
    string match -q -- '*%t*' $content; and begin
        _fail "  $dst: forbidden %t literal present"
        return 1
    end
    # systemd-env-d-generator(8) ${VAR} expansion requires
    _resolve_systemd_ver
    if test -n "$_RY_SYSTEMD_VER"; and test "$_RY_SYSTEMD_VER" -lt 232
        _warn "  $dst: systemd $_RY_SYSTEMD_VER < 232; \${XDG_RUNTIME_DIR} expansion not supported (upgrade systemd or pin SSH_AUTH_SOCK to /run/user/\$UID/ssh-agent.socket)"
    end
    return 0
end

function _rvc_fish_syntax --argument-names dst --description "Validate fish source via fish --no-execute; rc=0 ok, rc=1 syntax error (logged + previewed)"
    set -l _fish_err_tmp (mktemp -t ry-fish-syntax.XXXXXX 2>/dev/null; or echo /dev/null)
    _track_tmpfile "$_fish_err_tmp"
    test "$_fish_err_tmp" = /dev/null; and _log "MKTEMP_FAIL: ry-fish-syntax — diagnostic preview unavailable on syntax-check failure"
    printf '%s\n' $argv[2..] | fish --no-execute 2>"$_fish_err_tmp"
    set -l _ps $pipestatus
    set -l _rc 0
    if test $_ps[1] -ne 0; or test $_ps[2] -ne 0
        set -l _ps_str (string join , -- $_ps); test -z "$_ps_str"; and set _ps_str "(empty)"
        _fail "  $dst: fish syntax check failed (pipestatus=$_ps_str)"
        if test "$_fish_err_tmp" != /dev/null; and test -s "$_fish_err_tmp"
            _log "VALIDATE_FISH_STDERR: "(command head -n 5 -- "$_fish_err_tmp" 2>/dev/null | string join '; ')
            for _ferr_line in (command head -n 5 -- "$_fish_err_tmp" 2>/dev/null)
                _info "    $_ferr_line"
            end
        end
        set _rc 1
    end
    test "$_fish_err_tmp" != /dev/null; and _rm_tmp "$_fish_err_tmp" false
    return $_rc
end

function _rvc_dispatch --argument-names dst --description "Validate single embedded content by format family; rc=0 ok, rc=1 fail"
    set -l _content $argv[2..]
    switch "$dst"
        case '*.service';                          _verify_unit_content "$dst" $_content; return $status
        case '*.fish';                             _rvc_fish_syntax "$dst" $_content; return $status
        case '*/loader.conf' '*/sdboot-manage.conf'; _grep_kv "$dst" $_content; return $status
        case '*/kernel/cmdline';                   _grep_kparam "$dst" $_content; return $status
        case '*/sysctl.d/*';                       _grep_sysctl_kv "$dst" $_content; return $status
        case '*/drirc';                            _grep_xml_tag "$dst" $_content; return $status
        case '*/mkinitcpio.conf' '*/environment.d/*'; return 0
        case '*';                                  _grep_ini_header "$dst" $_content; return $status
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
        if not functions -q $fn
            _fail "  $dst: content generator '$fn' not found"
            set errors (math $errors + 1); continue
        end
        set -l content ($fn)
        if test $status -ne 0
            _fail "  $dst: content generator failed"
            set errors (math $errors + 1); continue
        end
        _rvc_dispatch "$dst" $content; or set errors (math $errors + 1)
    end
    _check_env_ssh_auth_sock; or set errors (math $errors + 1)
    test $errors -gt 0; and _err "Validation failed with $errors error(s)"; and return $EXIT_PREFLIGHT
    _ok "All configurations validated"
    return 0
end

function _ry_mkinitcpio_array --argument-names key file --description "First non-comment KEY=... line from a conf file"
    test -z "$file"; and set file /etc/mkinitcpio.conf
    set -l _all_lines (command grep -E "^[[:space:]]*$key=" "$file" 2>/dev/null | command grep -v '^[[:space:]]*#')
    test (count $_all_lines) -gt 1; and functions -q _warn; and _warn "  $file: multiple $key= lines found ("(count $_all_lines)") — using first"
    test (count $_all_lines) -gt 0; and printf '%s\n' "$_all_lines[1]"
end

function _ry_content_bytes --argument-names dst --description "Raw bytes of embedded content for a destination, or empty on generator failure"
    set -l _content (_ry_get_file_content "$dst" 2>/dev/null | string collect --no-trim-newlines)
    set -l _ps $pipestatus
    test $_ps[1] -ne 0; and return 1
    # _ps[2] (string collect) returns 1 on empty input.
    printf '%s' "$_content" | string collect --no-trim-newlines --allow-empty
end

function _awf_validate_parent --argument-names dst dst_dir use_sudo expected_uid --description "Validate parent dir: exists, is dir, not symlink, owned by expected uid, not group/world writable"
    set -l _dir_stat (_as $use_sudo env LC_ALL=C stat -c '%F|%u|%a' -- "$dst_dir" 2>/dev/null)
    test -z "$_dir_stat"; and _fail "→ $dst (parent dir missing or unreadable: $dst_dir)"; and return 1
    set -l _df (string split '|' -- "$_dir_stat")
    test "$_df[1]" != directory; and _fail "→ $dst (parent dir not a directory: type='$_df[1]' $dst_dir)"; and return 1
    if test "$use_sudo" = true
        sudo -n test -L "$dst_dir"; and _fail "→ $dst (parent dir is a symlink: $dst_dir)"; and return 1
    else
        test -L "$dst_dir"; and _fail "→ $dst (parent dir is a symlink: $dst_dir)"; and return 1
    end
    test "$_df[2]" != "$expected_uid"; and _fail "→ $dst (parent dir uid=$_df[2] expected=$expected_uid)"; and return 1
    _dir_group_or_world_writable "$_df[3]"; and _fail "→ $dst (parent dir group/world writable: mode=$_df[3])"; and return 1
    return 0
end

function _awf_render_to_tmp --argument-names dst tmpfile use_sudo --description "Pipe content generator into tee; map pipestatus[1] to specific error class"
    _ry_get_file_content "$dst" | _as $use_sudo tee -- "$tmpfile" >/dev/null
    set -l _ps $pipestatus
    if test $_ps[1] -ne 0
        switch $_ps[1]
            case 11; _err "Not a managed destination: $dst"
            case 12; _err "Content generator missing prerequisite global (e.g. _ROOT_UUID): $dst"
            case 13; _err "Content generator assertion failed (output count mismatch): $dst"
            case '*'; _err "Content generator failed for $dst (rc=$_ps[1])"
        end
        return 1
    end
    test $_ps[2] -ne 0; and _fail "→ $dst (write to temp failed)"; and return 1
    return 0
end

function _atomic_write_file --argument-names dst perms use_sudo --description "Atomic file write. rc=0 ok; rc=1 any failure; rc=EXIT_BOOT_CRIT only on sudo lapse mid-mv"
    set -l _sp
    set -l _expected_uid $_MY_UID
    test "$use_sudo" = true; and set _sp sudo -n; and set _expected_uid 0
    set -l dst_dir (dirname -- "$dst")
    _awf_validate_parent "$dst" "$dst_dir" $use_sudo $_expected_uid; or return 1
    set -l tmpfile (_as $use_sudo mktemp -p "$dst_dir" .ry-install.XXXXXX 2>/dev/null)
    _track_tmpfile "$tmpfile"
    test -z "$tmpfile"; and _fail "→ $dst (mktemp failed)"; and return 1
    if _is_symlink "$tmpfile" $use_sudo
        _rm_tmp "$tmpfile" $use_sudo
        _fail "→ $dst (temp file is symlink — aborting)"; return 1
    end
    if not _awf_render_to_tmp "$dst" "$tmpfile" $use_sudo
        _rm_tmp "$tmpfile" $use_sudo; return 1
    end
    if _is_symlink "$tmpfile" $use_sudo
        _rm_tmp "$tmpfile" $use_sudo
        _fail "→ $dst (temp file replaced with symlink during write — aborting)"; return 1
    end
    if not _run $_sp chmod -- $perms "$tmpfile"
        _rm_tmp "$tmpfile" $use_sudo; _fail "→ $dst (chmod failed)"; return 1
    end
    if test "$use_sudo" = true; and not sudo -n true 2>/dev/null
        _err "sudo credential lapsed before atomic mv of $dst"
        _rm_tmp "$tmpfile" $use_sudo; return $EXIT_BOOT_CRIT
    end
    if not _run $_sp mv -- "$tmpfile" "$dst"
        _rm_tmp "$tmpfile" $use_sudo; _fail "→ $dst (atomic move failed)"; return 1
    end
    _untrack_tmpfile "$tmpfile"
    _ok "→ $dst"
    return 0
end

function _ry_install_file --argument-names dst use_sudo --description "Install a single embedded config to its destination"
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
        if not _run mkdir -p -- "$dir"
            _fail "Cannot create directory: $dir"
            return 1
        end
    end
    set -l perms 0644
    test "$use_sudo" = false; and set perms 0600
    set -l _new_bytes (_ry_content_bytes "$dst")
    if test -n "$_new_bytes"
        set -l _cur_bytes (_installed_bytes "$dst")
        set -l _read_rc $status
        if test $_read_rc -eq 0; and test "$_new_bytes" = "$_cur_bytes"
            _ok "→ $dst (unchanged)"
            return 0
        end
        test $_read_rc -eq 2; and _log "SKIP_PROBE_SUDO_LAPSED: dst=$dst — re-deploying"
    end
    _atomic_write_file "$dst" $perms $use_sudo
    return $status
end

# FILE OPERATIONS — diff, install, verify

function _vsb_loader --description "_verify_static_boot sub: /boot/loader/loader.conf key/value verification"
    _echo "── loader.conf ──"
    _chk_file /boot/loader/loader.conf; or return 0
    for kv in "default $LOADER_DEFAULT" "timeout $LOADER_TIMEOUT" \
              "console-mode $LOADER_CONSOLE_MODE" "editor $LOADER_EDITOR"
        _chk_grep /boot/loader/loader.conf "$kv"
    end
end

function _vsb_sdboot --description "_verify_static_boot sub: /etc/sdboot-manage.conf LINUX_OPTIONS extraction + key checks"
    _echo "── sdboot-manage.conf ──"
    _chk_file /etc/sdboot-manage.conf; or return 0
    set -l _opts_raw (command grep -- '^LINUX_OPTIONS=' /etc/sdboot-manage.conf 2>/dev/null)
    set -l _grep_rc $status
    if test $_grep_rc -ne 0; or test -z "$_opts_raw"
        _fail "  /etc/sdboot-manage.conf: LINUX_OPTIONS= line missing"
        return 0
    end
    # lint:ignore (PCRE backref); depends on KERNEL_PARAMS hygiene in _init_runtime rejecting embedded quote chars; manual edits with embedded \" will mis-extract.
    set -l opts (printf '%s\n' "$_opts_raw" | string replace -r -- '^LINUX_OPTIONS=\x22([^\x22]*)\x22.*$' '$1')
    for param in $KERNEL_PARAMS
        set -l _param_re (string escape --style=regex -- "$param")
        string match -qr -- "(^|\s)$_param_re(\s|\$)" "$opts"
        _chk_present $status "$param"
    end
    for _kv in "OVERWRITE_EXISTING:$SDBOOT_OVERWRITE" \
               "REMOVE_EXISTING:$SDBOOT_REMOVE_EXISTING" \
               "REMOVE_OBSOLETE:$SDBOOT_REMOVE_OBSOLETE" \
               "DEFAULT_ENTRY:$SDBOOT_DEFAULT_ENTRY"
        set -l _k (string split ':' -- $_kv)[1]
        set -l _v (string split ':' -- $_kv)[2]
        _chk_grep /etc/sdboot-manage.conf "$_k=\"$_v\"" "$_k=$_v"
    end
    _chk_grep /etc/sdboot-manage.conf 'LINUX_FALLBACK_OPTIONS="quiet"' "LINUX_FALLBACK_OPTIONS=quiet"
end

function _vsb_cmdline --description "_verify_static_boot sub: /etc/kernel/cmdline KERNEL_PARAMS + root=UUID + rw checks"
    _echo "── kernel cmdline ──"
    _chk_file /etc/kernel/cmdline; or return 0
    set -l cmdline_content (sudo -n cat -- /etc/kernel/cmdline 2>/dev/null)
    if test -z "$cmdline_content"
        _fail "  /etc/kernel/cmdline: empty or unreadable"
        return 0
    end
    for param in $KERNEL_PARAMS
        set -l _param_re (string escape --style=regex -- "$param")
        string match -qr -- "(^|\s)$_param_re(\s|\$)" "$cmdline_content"
        _chk_present $status "$param" "MISSING from /etc/kernel/cmdline"
    end
    string match -q '*root=UUID=*' -- "$cmdline_content"
    _chk_present $status root=UUID "MISSING from /etc/kernel/cmdline"
    string match -qr -- '(^|\s)rw(\s|$)' "$cmdline_content"
    _chk_present $status rw "MISSING from /etc/kernel/cmdline"
end

function _vsb_mkinitcpio --description "_verify_static_boot sub: /etc/mkinitcpio.conf MODULES/HOOKS/COMPRESSION checks"
    _echo "── mkinitcpio.conf ──"
    _chk_file /etc/mkinitcpio.conf; or return 0
    set -l modules_line (_ry_mkinitcpio_array MODULES)
    _echo "  Config: $modules_line"
    string match -q '*amdgpu*' -- "$modules_line"
    _chk_present $status amdgpu MISSING "present (early KMS)"
    for mod in $MKINITCPIO_MODULES
        test "$mod" = amdgpu; and continue
        _chk_token_in "$modules_line" "$mod" "$mod"
    end
    set -l hooks_line (_ry_mkinitcpio_array HOOKS)
    _echo "  Config: $hooks_line"
    for hook in $MKINITCPIO_HOOKS
        _chk_token_in "$hooks_line" "$hook" "$hook"
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

function _vsb_entries --description "_verify_static_boot sub: ESP boot entries enumeration + count check"
    _echo "── Boot entries ──"
    set -l _esp (_resolve_esp)
    set -l entry_count 0
    set -l _entries_pipe_ok true
    if sudo -n test -d "$_esp/loader/entries" 2>/dev/null
        set -l _entries (sudo -n find "$_esp/loader/entries" -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null | string split0)
        set -l _ps $pipestatus
        for _rc in $_ps
            test "$_rc" = 0; or set _entries_pipe_ok false
        end
        set entry_count (count $_entries)
    end
    if test "$_entries_pipe_ok" = false
        _warn "  Boot entries: cannot enumerate $_esp/loader/entries (sudo lapsed or read error)"
    else if test "$entry_count" -gt 0
        _ok "  Boot entries: $entry_count found"
    else
        _fail "  Boot entries: NONE in $_esp/loader/entries/"
        _info "  System may not boot! Run: sudo sdboot-manage gen --verbose"
    end
end

function _verify_static_boot --description "Verify loader.conf, sdboot-manage, kernel cmdline, mkinitcpio, boot entries"
    _echo "BOOT CONFIGURATION"
    _echo
    _vsb_loader
    _vsb_sdboot
    _echo
    _vsb_cmdline
    _echo
    _vsb_mkinitcpio
    _echo
    _vsb_entries
    _echo
end

function _vss_ntsync_modules --description "_verify_static_system sub: ntsync state + modules-load.d autoload check"
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

function _vss_logind --description "_verify_static_system sub: logind.conf.d keys (with systemd<256 HandleSecureAttentionKey skip)"
    _chk_file /etc/systemd/logind.conf.d/99-cachyos-logind.conf; or return 0
    # mirror generator's systemd<256 skip for HandleSecureAttentionKey.
    _resolve_systemd_ver
    for key in $LOGIND_IGNORE_KEYS
        if test "$key" = HandleSecureAttentionKey
            test -z "$_RY_SYSTEMD_VER"; or test "$_RY_SYSTEMD_VER" -lt 256; and continue
        end
        _chk_grep /etc/systemd/logind.conf.d/99-cachyos-logind.conf "$key=ignore" "$key"
    end
end

function _vss_iwd --argument-names skip_iwd --description "_verify_static_system sub: iwd config (skip-iwd-aware)"
    if test "$skip_iwd" = true
        _info "  Skipping (iwd not installed)"
        return 0
    end
    _chk_file /etc/iwd/main.conf; or return 0
    _chk_grep /etc/iwd/main.conf "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG" "EnableNetworkConfiguration=$IWD_ENABLE_NETWORK_CONFIG"
    for quirk in $IWD_DRIVER_QUIRKS
        # full key=value match.
        _chk_grep /etc/iwd/main.conf "$quirk" "DriverQuirks $quirk"
    end
    _chk_grep /etc/iwd/main.conf "NameResolvingService=$IWD_DNS_SERVICE" "DNS via $IWD_DNS_SERVICE"
end

function _vss_nm --argument-names skip_iwd --description "_verify_static_system sub: NetworkManager config (skip-iwd-aware)"
    if test "$skip_iwd" = true
        _info "  Skipping iwd-backend config (iwd not installed)"
        return 0
    end
    _chk_file /etc/NetworkManager/conf.d/99-cachyos-nm.conf; or return 0
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.backend=$NM_WIFI_BACKEND" "wifi backend $NM_WIFI_BACKEND"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.powersave=$NM_WIFI_POWERSAVE" "WiFi powersave $NM_WIFI_POWERSAVE"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "wifi.iwd.autoconnect=false" "iwd autoconnect disabled"
    _chk_grep /etc/NetworkManager/conf.d/99-cachyos-nm.conf "level=$NM_LOG_LEVEL" "logging level $NM_LOG_LEVEL"
end

function _vss_drirc_sysctl --description "_verify_static_system sub: drirc XML tag + sysctl drop-in key=value check"
    _echo "── RADV driconf ──"
    _chk_file /etc/drirc; and _chk_grep /etc/drirc radv_enable_unified_heap_on_apu unified_heap_on_apu
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
end

function _verify_static_system --description "Verify ntsync, modules-load, resolved, logind, coredump, iwd, NM, drirc, sysctl"
    # Pre-compute iwd state once
    set -l _skip_iwd false
    not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1; and set _skip_iwd true
    _echo "SYSTEM CONFIGURATION"
    _echo
    _vss_ntsync_modules
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
    _vss_logind
    _echo
    _echo "── coredump.conf ──"
    if _chk_file /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf
        for kv in Storage=none ProcessSizeMax=0
            _chk_grep /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf "$kv"
        end
    end
    _echo
    _echo "── iwd ──"
    _vss_iwd $_skip_iwd
    _echo
    _echo "── NetworkManager ──"
    _vss_nm $_skip_iwd
    _echo
    _vss_drirc_sysctl
    _echo
end

function _verify_static_user --description "Verify SSH agent fish script, environment.d, ssh-agent.service unit"
    _echo "USER CONFIGURATION"
    _echo
    _echo "── SSH agent ──"
    _chk_file "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish"; and _chk_grep "$HOME/.config/fish/conf.d/10-ssh-auth-sock.fish" SSH_AUTH_SOCK "SSH_AUTH_SOCK configured"
    if _chk_file "$HOME/.config/environment.d/10-environment.conf"
        _chk_grep "$HOME/.config/environment.d/10-environment.conf" "SSH_AUTH_SOCK=" "SSH_AUTH_SOCK for systemd"
        for exp in $ENV_VARS
            # full name=value match (mirrors _verify_runtime_env coverage).
            _chk_grep "$HOME/.config/environment.d/10-environment.conf" "$exp" "$exp"
        end
    end
    set -l _ssh_unit "$HOME/.config/systemd/user/ssh-agent.service"
    if _chk_file "$_ssh_unit"
        _chk_grep "$_ssh_unit" ssh-agent "ssh-agent ExecStart"
        _chk_grep "$_ssh_unit" "WantedBy=default.target" "ssh-agent WantedBy"
    end
    _echo
end

function _vsp_required --description "Check PKGS_ADD against installed; emits OK/FAIL per pkg"
    _echo "── Required packages ──"
    for pkg in $PKGS_ADD
        contains -- "$pkg" $argv; and _ok "  $pkg: installed"; or _fail "  $pkg: NOT INSTALLED"
    end
end

function _vsp_aur --description "Check AUR_PKGS against installed; warn on missing"
    set -q AUR_PKGS; or return 0
    for pkg in $AUR_PKGS
        contains -- "$pkg" $argv; and _ok "  $pkg: installed (AUR)"; or _warn "  $pkg: NOT INSTALLED (AUR — install via paru)"
    end
end

function _vsp_removed --description "Check PKGS_DEL against installed; warn if still present"
    _echo "── Removed packages ──"
    for pkg in $PKGS_DEL
        contains -- "$pkg" $argv; and _warn "  $pkg: still installed (should be removed)"; or _ok "  $pkg: not installed"
    end
end

function _vsp_pacman_conf --description "Inspect IgnorePkg / ParallelDownloads in /etc/pacman.conf"
    _echo "── pacman.conf ──"
    test -f /etc/pacman.conf; or _warn "  /etc/pacman.conf not found"; or return 0
    set -l ignore_lines (command grep -E -- '^[[:space:]]*IgnorePkg' /etc/pacman.conf 2>/dev/null)
    if test -n "$ignore_lines"
        for line in $ignore_lines; _ok "  $line"; end
    else
        _info "  No IgnorePkg set"
    end
    set -l parallel (command grep -E -- '^[[:space:]]*ParallelDownloads[[:space:]]*=' /etc/pacman.conf 2>/dev/null)
    test -n "$parallel"; and _ok "  $parallel"; or _info "  ParallelDownloads not set (default: 1)"
end

function _verify_static_packages --description "Verify PKGS_ADD, AUR_PKGS, PKGS_DEL, pacman.conf"
    _echo PACKAGES
    _echo
    set -l _installed_pkgs
    if command -q pacman
        set _installed_pkgs (pacman -Qq 2>/dev/null)
    else
        _warn "  pacman not found, skipping package verification"
    end
    _vsp_required $_installed_pkgs
    _vsp_aur $_installed_pkgs
    _echo
    _vsp_removed $_installed_pkgs
    _echo
    _vsp_pacman_conf
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
        # scaling_governor ExecStart absent:
        _chk_grep /etc/systemd/system/cpupower-epp.service energy_performance_preference "cpupower-epp EPP ExecStart"
        command grep -q -- scaling_governor /etc/systemd/system/cpupower-epp.service 2>/dev/null; and _warn "  cpupower-epp: scaling_governor ExecStart present — remove it (amd_pstate=active uses powersave+EPP)"
        _chk_grep /etc/systemd/system/cpupower-epp.service "WantedBy=multi-user.target" "cpupower-epp WantedBy"
    end
    _echo
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
    _echo
end

function _verify_static_syntax --description "Validate mkinitcpio hooks ordering, systemd unit files, fish scripts"
    _echo "SYNTAX VALIDATION"
    _echo
    _echo "── mkinitcpio hooks ──"
    set -l hooks_syntax_line (command grep -E '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf 2>/dev/null | command grep -v '^#' | head -n 1)
    if test -n "$hooks_syntax_line"
        # lint:ignore (PCRE backref)
        set -l hooks_str (string replace -r '.*HOOKS=\(([^)]*)\).*' '$1' -- "$hooks_syntax_line")
        set hooks_str (string replace -ra '\s+' ' ' -- "$hooks_str")
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
        if not test -s "$fish_script"
            _fail "  ssh-auth-sock.fish: empty (truncated write?)"
        else
            set -l _fs_err_tmp (mktemp -t ry-fish-syntax-vs.XXXXXX 2>/dev/null; or echo /dev/null)
            _track_tmpfile "$_fs_err_tmp"
            test "$_fs_err_tmp" = /dev/null; and _log "MKTEMP_FAIL: ry-fish-syntax-vs — diagnostic preview unavailable"
            if fish --no-execute "$fish_script" 2>"$_fs_err_tmp"
                _ok "  ssh-auth-sock.fish: syntax OK"
            else
                _fail "  ssh-auth-sock.fish: INVALID SYNTAX"
                if test "$_fs_err_tmp" != /dev/null; and test -s "$_fs_err_tmp"
                    _log "VERIFY_FISH_STDERR: "(command head -n 5 -- "$_fs_err_tmp" 2>/dev/null | string join '; ')
                    for _ferr_line in (command head -n 5 -- "$_fs_err_tmp" 2>/dev/null)
                        _info "    $_ferr_line"
                    end
                end
            end
            test "$_fs_err_tmp" != /dev/null; and _rm_tmp "$_fs_err_tmp" false
        end
    end
    _echo
end

function _verify_static_checksum --description "Verify embedded content hash matches installed file SHA256"
    _echo "CHECKSUM VERIFICATION"
    _echo
    _echo "── embedded vs installed ──"
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l expected (_ry_content_bytes "$dst")
        set -l actual (_installed_bytes "$dst")
        # replaced switch "$expected::$actual" with explicit checks.
        if test -z "$expected"
            _fail_silent "  $dst: generator failed"
            set -g VERIFY_GEN_FAIL (math $VERIFY_GEN_FAIL + 1)
            _log "VERIFY_STATIC_GEN_FAIL: dst=$dst"
        else if test -z "$actual"
            _fail "  $dst: cannot read"
            _log "VERIFY_STATIC_READ_FAIL: dst=$dst"
        else if test "$expected" = "$actual"
            _ok "  $dst: match"
        else
            _fail "  $dst: MISMATCH"
            set -l _exp_sha (printf '%s' "$expected" | sha256sum 2>/dev/null | string split ' ')[1]
            set -l _act_sha (printf '%s' "$actual" | sha256sum 2>/dev/null | string split ' ')[1]
            _log "VERIFY_STATIC_MISMATCH: dst=$dst expected_sha=$_exp_sha actual_sha=$_act_sha expected_bytes="(string length -- "$expected")" actual_bytes="(string length -- "$actual")
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

function _check_phase_files --description "--check phase: file content hash compare. Sets _RY_CHECK_DRIFT, _RY_CHECK_FILES_CHECKED. Returns EXIT_PREFLIGHT on generator/sudo failure."
    for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
        _should_skip_iwd "$dst"; and continue
        set -l expected (_ry_content_bytes "$dst")
        set -l actual (_installed_bytes "$dst")
        if test -z "$expected"
            _log "CHECK_PREFLIGHT: generator failed for $dst (rc=EXIT_GEN_NOFN/NOUUID)"
            return $EXIT_PREFLIGHT
        end
        if test -z "$actual"
            if _is_system_dst "$dst"
                _log "CHECK_PREFLIGHT: cannot read $dst (sudo unavailable?)"
                return $EXIT_PREFLIGHT
            end
            set -g _RY_CHECK_DRIFT 1
            continue
        end
        test "$expected" = "$actual"; or set -g _RY_CHECK_DRIFT 1
        set -g _RY_CHECK_FILES_CHECKED (math $_RY_CHECK_FILES_CHECKED + 1)
    end
    return 0
end

function _check_phase_cmdline --description "--check phase: kernel cmdline contains all KERNEL_PARAMS + implicit rw. Sets _RY_CHECK_DRIFT on miss."
    set -l _cmdline (command cat -- /proc/cmdline 2>/dev/null)
    if test -z "$_cmdline"
        set -g _RY_CHECK_DRIFT 1
        return 0
    end
    # whole-word regex match (escaped)
    for _p in $KERNEL_PARAMS
        set -l _p_re (string escape --style=regex -- "$_p")
        string match -qr -- "(^|\s)$_p_re(\s|\$)" "$_cmdline"; or set -g _RY_CHECK_DRIFT 1
    end
    # `rw` is the implicit prefix written by _content__etc_kernel_cmdline.
    string match -qr -- '(^|\s)rw(\s|$)' "$_cmdline"; or set -g _RY_CHECK_DRIFT 1
    return 0
end

function _cpu_chk_expected --description "Check EXPECTED_SERVICES units; sets _RY_CHECK_DRIFT or rc=EXIT_PREFLIGHT on systemctl error"
    for unit in $EXPECTED_SERVICES
        set -l _v (_unit_state_padded $unit)
        set -l load $_v[1]; set -l active $_v[2]; set -l ufs $_v[3]
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

function _check_phase_units --description "--check phase: EXPECTED_SERVICES + MASK + implicit conf.d-driven units. Sets _RY_CHECK_DRIFT or rc=EXIT_PREFLIGHT"
    set -l _implicit_svcs
    for _dst in $SYSTEM_DESTINATIONS
        switch $_dst
            case '*/systemd/resolved.conf.d/*'
                contains -- systemd-resolved.service $_implicit_svcs; or set -a _implicit_svcs systemd-resolved.service
            case '*/NetworkManager/dispatcher.d/*' '*/NetworkManager/conf.d/*'
                contains -- NetworkManager-dispatcher.service $_implicit_svcs; or set -a _implicit_svcs NetworkManager-dispatcher.service
        end
    end
    _cpu_chk_expected; or return $status
    for unit in (_mask_list_effective)
        set -l _v (_unit_state_padded $unit)
        if test "$_v[1]" = ERR_NO_DATA
            _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"
            return $EXIT_PREFLIGHT
        end
        test "$_v[1]" = not-found; and continue
        test "$_v[3]" = masked; or set -g _RY_CHECK_DRIFT 1
    end
    for unit in $_implicit_svcs
        set -l _v (_unit_state_padded $unit)
        if test "$_v[1]" = ERR_NO_DATA
            _log "CHECK_PREFLIGHT: cannot determine state for $unit (systemctl error)"
            return $EXIT_PREFLIGHT
        end
        test "$_v[1]" = not-found; and continue
        test "$_v[3]" = enabled; or set -g _RY_CHECK_DRIFT 1
    end
    return 0
end

function _check_phase_user_ssh --description "--check phase: user-scope ssh-agent.service is-enabled. Returns EXIT_PREFLIGHT if no user-bus."
    set -l _ssh_unit_file "$HOME/.config/systemd/user/ssh-agent.service"
    test -f "$_ssh_unit_file"; or return 0
    set -l _ssh_state (systemctl --user is-enabled ssh-agent.service 2>/dev/null | string trim --)
    if test -z "$_ssh_state"
        _log "CHECK_PREFLIGHT: cannot determine ssh-agent state (no user-bus session?)"
        return $EXIT_PREFLIGHT
    end
    test "$_ssh_state" = enabled; or set -g _RY_CHECK_DRIFT 1
    return 0
end

function _ry_do_check --description "Silent idempotency probe — exit 0 if clean, EXIT_DRIFT if drifted, EXIT_PREFLIGHT if prereqs fail"
    # Phase 1: sudo cache + systemctl availability
    if not command -q sudo; or not sudo -n true 2>/dev/null
        _log "CHECK_PREFLIGHT: sudo not cached"
        return $EXIT_PREFLIGHT
    end
    if not command -q systemctl
        _log "CHECK_PREFLIGHT: systemctl not available"
        return $EXIT_PREFLIGHT
    end
    set -g _RY_CHECK_DRIFT 0
    set -g _RY_CHECK_FILES_CHECKED 0
    set -l _rc 0
    _check_phase_files; set _rc $status
    if test $_rc -ne 0
        set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
        return $_rc
    end
    _check_phase_cmdline
    _check_phase_units; set _rc $status
    if test $_rc -ne 0
        set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
        return $_rc
    end
    _check_phase_user_ssh; set _rc $status
    if test $_rc -ne 0
        set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
        return $_rc
    end
    set -l _drift $_RY_CHECK_DRIFT
    set -l _checked $_RY_CHECK_FILES_CHECKED
    set --erase _RY_CHECK_DRIFT _RY_CHECK_FILES_CHECKED
    test $_drift -ne 0; and return $EXIT_DRIFT
    if test $_checked -eq 0
        _log "CHECK_DRIFT: no files could be checked (all skipped)"
        return $EXIT_DRIFT
    end
    return $EXIT_OK
end

function _gather_cpu_state --description "Collect CPU frequency path for representative core"
    # Assumes symmetric CPU topology
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

function _vrk_cmdline --description "Runtime kparam check: /proc/cmdline + preemption model"
    _echo "KERNEL CMDLINE"
    _echo
    set -l cmdline (command cat -- /proc/cmdline 2>/dev/null)
    test -z "$cmdline"; and command -q sudo; and sudo -n true 2>/dev/null; and set cmdline (sudo -n cat -- /proc/cmdline 2>/dev/null)
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
    _validate_kernel_params
    _echo "── Preemption model ──"
    set -l _preempt (printf '%s\n' $_RY_DMESG_CACHE | command grep -o 'Dynamic Preempt: [a-z]*' | head -n 1)
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
end

function _vrkg_perf_level --description "_vrk_gpu_state sub: power_dpm_force_performance_level sysfs scan"
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
end

function _vrkg_rebar_sam --description "_vrk_gpu_state sub: ReBAR/SAM status via dmesg cache + lspci fallback"
    _echo "── ReBAR/SAM status ──"
    set -l rebar_status (printf '%s\n' $_RY_DMESG_CACHE | command grep -i 'BAR' | command grep -i -E 'resize|rebar|large|above.4g' | head -n 1)
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
    if not command -q lspci
        _info "  lspci not available for ReBAR check"
        return 0
    end
    set -l bar_size (lspci -vvv 2>/dev/null | command grep -iE 'Region.*Memory.*256M|Region.*Memory.*512M|Region.*Memory.*[0-9]G' | head -n 1)
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
        if test -f "$f"
            set _vram_bytes (command cat -- "$f" 2>/dev/null | string trim --)
            break
        end
    end
    if not test "$_vram_bytes" -gt 0 2>/dev/null
        _info "  VRAM carveout: cannot read mem_info_vram_total"
        return 0
    end
    set -l _vram_mb (math "$_vram_bytes / 1048576")
    if test "$_vram_mb" -le 512
        _ok "  VRAM carveout: $_vram_mb MB"
    else
        _warn "  VRAM carveout: $_vram_mb MB (recommended: ≤512 MB for UMA — check BIOS)"
    end
end

function _vrk_gpu_state --description "Runtime kparam check: GPU performance level + ReBAR/SAM + VRAM carveout"
    _echo "HARDWARE STATE"
    _echo
    _vrkg_perf_level
    _echo
    _vrkg_rebar_sam
    _echo
    _vrkg_vram
    _echo
end

function _vrk_cpu_state --description "Runtime kparam check: CPU governor/EPP + amd_pstate + boost"
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
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/status active "amd_pstate status"
    _chk_sysfs_eq /sys/devices/system/cpu/amd_pstate/prefcore enabled "amd_pstate prefcore"
    _chk_sysfs_eq /sys/devices/system/cpu/cpufreq/boost 1 "CPU boost"
    _echo
end

function _vrk_module_state --description "Runtime kparam check: module parameters + blacklist"
    _echo "MODULE STATE"
    _echo
    _echo "── Module parameters ──"
    _chk_sysfs_eq /sys/module/usbcore/parameters/autosuspend -1 "usbcore.autosuspend"
    # Regression guard: nvme_core.default_ps_max_latency_us=0 disables APST.
    if test -f /sys/module/nvme_core/parameters/default_ps_max_latency_us
        set -l sysfs_val (command cat -- /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null)
        if test "$sysfs_val" = 0
            _fail "  nvme_core.default_ps_max_latency_us: 0 (regression — should be unset; re-check /etc/kernel/cmdline)"
        else
            _ok "  nvme_core.default_ps_max_latency_us: $sysfs_val (APST enabled)"
        end
    end
    if test -d /sys/module/amdgpu/parameters
        for pair in "ppfeaturemask:0xfffd3fff" "cwsr_enable:0"
            set -l pname (string split ':' -- "$pair")[1]
            set -l expected (string split ':' -- "$pair")[2]
            set -l ppath /sys/module/amdgpu/parameters/$pname
            if test -f "$ppath"
                set -l sysfs_val (string trim -- (command cat -- "$ppath" 2>/dev/null))
                set -l sysfs_val_dec "$sysfs_val"
                set -l expected_dec "$expected"
                string match -q '0x*' -- "$sysfs_val"; and set sysfs_val_dec (printf '%d' "$sysfs_val" 2>/dev/null; or echo "$sysfs_val")
                string match -q '0x*' -- "$expected"; and set expected_dec (printf '%d' "$expected" 2>/dev/null; or echo "$expected")
                if test "$sysfs_val_dec" = "$expected_dec"
                    _ok "  amdgpu.$pname: $sysfs_val"
                else
                    _fail "  amdgpu.$pname: $sysfs_val (expected: $expected)"
                end
            end
        end
    end
    _echo "── Additional module parameters ──"
    _chk_sysfs_match /sys/module/zswap/parameters/enabled '^[N0]$' zswap.enabled
    _chk_sysfs_eq /proc/sys/kernel/nmi_watchdog 0 nmi_watchdog
    _echo
    _echo "── Blacklisted modules ──"
    for mod in pcspkr
        if lsmod 2>/dev/null | command grep -q -- "^$mod "
            _fail "  $mod: LOADED (should be blacklisted)"
        else
            _ok "  $mod: not loaded"
        end
    end
    _echo
end

function _vrk_clocksource_coredump --description "Runtime kparam check: clocksource (with TSC demotion correlation) + coredump.conf"
    _echo "── Clocksource ──"
    if test -f /sys/devices/system/clocksource/clocksource0/current_clocksource
        set -l _cs (command cat -- /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null | string trim --)
        if test "$_cs" = tsc
            _ok "  clocksource: $_cs"
        else if test "$_cs" = hpet
            _fail "  clocksource: $_cs (expected: tsc — HPET has 10–100× higher read latency)"
            set -l _tsc_demote (printf '%s\n' $_RY_DMESG_CACHE | command grep -iE 'Marking TSC unstable|TSC: Marking|clocksource.*tsc.*unstable' | head -n 3)
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
        if command grep -q -- 'Storage=none' /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf 2>/dev/null
            _ok "  coredump: Storage=none"
        else
            _fail "  coredump: Storage!=none in /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf"
        end
    else
        _warn "  coredump: /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf not found"
    end
    _echo
end

function _verify_runtime_kparams --description "Verify /proc/cmdline, hardware state, module params, blacklist, clocksource, coredump"
    set -g _RY_DMESG_CACHE
    command -q dmesg; and command -q sudo; and sudo -n true 2>/dev/null; and set -g _RY_DMESG_CACHE (sudo -n dmesg 2>/dev/null)
    _vrk_cmdline
    _vrk_gpu_state
    _vrk_cpu_state
    _vrk_module_state
    _vrk_clocksource_coredump
    set --erase _RY_DMESG_CACHE
end

function _vrsv_chk_active_enabled --argument-names label rec_str --description "Helper: parsed[N] '$L:$A:$F' → ok if active+enabled, warn if active+notenabled, fail if other (default expects active)"
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

function _vrsv_chk_cpupower --argument-names rec_str --description "Check cpupower-epp.service: oneshot RemainAfterExit=yes accepts 'exited'; falls back to file-presence"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[1]" = not-found
        _warn "  cpupower-epp.service: not installed"; return
    end
    if test "$rec[2]" = active; or test "$rec[2]" = exited
        test "$rec[3]" = enabled; and _ok "  cpupower-epp.service: $rec[2] (enabled)"; or _warn "  cpupower-epp.service: $rec[2] but $rec[3] (will not persist)"
        return
    end
    test -f /etc/systemd/system/cpupower-epp.service; and _fail "  cpupower-epp.service: $rec[2] (expected: active)"; or _warn "  cpupower-epp.service: not installed"
end

function _vrsv_chk_resolved --argument-names rec_str --description "Check systemd-resolved active state, only when conf.d drop-in is deployed"
    set -l rec (string split ':' -- "$rec_str")
    test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf; or return 0
    test "$rec[2]" = active; and _ok "  systemd-resolved: active"; or _fail "  systemd-resolved: $rec[2] (expected: active — DNS may be broken)"
end

function _vrsv_chk_nm_dispatcher --argument-names rec_str --description "Check NM-dispatcher: enabled + (active|inactive) acceptable (on-demand)"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[3]" != enabled
        _fail "  NetworkManager-dispatcher: $rec[3] (expected: enabled)"; return
    end
    test "$rec[2]" = active; or test "$rec[2]" = inactive; and _ok "  NetworkManager-dispatcher: $rec[3] ($rec[2])"; or _warn "  NetworkManager-dispatcher: $rec[2] (enabled but unexpected state)"
end

function _vrsv_chk_fstrim --argument-names rec_str --description "Check fstrim.timer: must be active+enabled"
    set -l rec (string split ':' -- "$rec_str")
    if test "$rec[2]" != active
        _fail "  fstrim.timer: NOT active"; return
    end
    test "$rec[3]" = enabled; and _ok "  fstrim.timer: active (enabled)"; or _warn "  fstrim.timer: active but $rec[3] (will not persist)"
end

function _vrsv_sys_units --description "Runtime services check: 6-unit batch (cpupower-epp/fstrim/resolved/NM-dispatcher/NM/nftables)"
    set -l sys_units cpupower-epp.service fstrim.timer systemd-resolved.service NetworkManager-dispatcher.service NetworkManager.service nftables.service
    set -l parsed
    for _u in $sys_units
        set -l _v (_unit_state_padded $_u)
        set -a parsed "$_v[1]:$_v[2]:$_v[3]"
    end
    _vrsv_chk_cpupower      "$parsed[1]"
    _vrsv_chk_fstrim        "$parsed[2]"
    _vrsv_chk_resolved      "$parsed[3]"
    _vrsv_chk_nm_dispatcher "$parsed[4]"
    _vrsv_chk_active_enabled NetworkManager.service "$parsed[5]"
    _vrsv_chk_active_enabled nftables.service "$parsed[6]"
end

function _vrsv_ssh_agent --description "Runtime services check: ssh-agent.service (user) + SSH_AUTH_SOCK runtime"
    set -l _u (_unit_state_user ssh-agent.service)
    # count<3 branch is reachable when no user-bus session.
    if test (count $_u) -lt 3
        if not set -q XDG_RUNTIME_DIR
            _warn "  ssh-agent.service: no user-bus session (XDG_RUNTIME_DIR unset — likely sudo or headless)"
        else
            _warn "  ssh-agent.service: systemctl --user returned no data"
        end
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
end

function _vrsv_wifi --description "Runtime services check: WiFi interface, iwd process, NM wifi radio + device state"
    _echo
    _echo "WIFI STATE"
    _echo
    # use cached _PROFILE_USES_WIFI_BACKEND rather than re-deriving locally
    if test "$_PROFILE_USES_WIFI_BACKEND" = false
        _info "  iwd/NetworkManager not managed — skipping WiFi state checks"
        return 0
    end
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
        set -l nm_wifi_enabled (nmcli -t -f WIFI general 2>/dev/null | string trim --)
        test -n "$nm_wifi_enabled"; and _info "  NM wifi radio: $nm_wifi_enabled"
        set -l wifi_state (nmcli -t -f TYPE,STATE device 2>/dev/null | command grep '^wifi:' | head -n 1 | cut -d: -f2)
        if test "$wifi_state" = connected
            _ok "  WiFi device: connected"
        else if test -n "$wifi_state"
            _warn "  WiFi device: $wifi_state (not connected)"
        end
    end
end

function _verify_runtime_services --description "Verify systemd unit states (sys batch + ssh-agent user) and WiFi runtime"
    _echo "SERVICE STATE"
    _echo
    _vrsv_sys_units; or return 1
    _vrsv_ssh_agent
    _vrsv_wifi
    return 0
end

function _vre_envvars --description "Runtime env check: ENV_VARS via systemctl --user show-environment"
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
            set actual (printf '%s\n' $_user_env | string match -rg -- "^"$_vn_re"=(.*)")
            set actual (string trim -c '"' -- "$actual")
        end
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
        set -l _parts (string split -m1 '=' -- "$entry")
        set -l _key $_parts[1]
        set -l _expected $_parts[2]
        set -l _proc_path (string replace -a '.' '/' -- "$_key")
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

function _vre_tcp --description "Runtime env check: TCP congestion control (bbr) + tcp_bbr module version"
    _echo "── TCP congestion control ──"
    if command -q modinfo
        set -l _bbr_ver (modinfo tcp_bbr 2>/dev/null | command grep -i '^version:' | string replace -r -- '^version:\s*' '')
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
end

function _vre_zram --description "Runtime env check: zram service + active swap device"
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
    set -l _zram_swap (swapon --show=NAME,TYPE 2>/dev/null | command grep zram)
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
end

function _vre_fstab --description "Runtime env check: fstab ext4 entries have noatime,lazytime,commit=10"
    _echo "── fstab mount options ──"
    if not test -r /etc/fstab
        _warn "  /etc/fstab not readable — skipping mount-option check (sudoers may need fstab read)"
        return 0
    end
    # lint:ignore (awk boolean operators)
    set -l _fstab_ext4 (command awk '!/^[[:space:]]*#/ && NF >= 4 && $3 == "ext4" { print $0 }' /etc/fstab 2>/dev/null)
    if test -z "$_fstab_ext4"
        _info "  No ext4 entries in /etc/fstab"
        return 0
    end
    set -l _fstab_ok true
    for _fl in $_fstab_ext4
        # lint:ignore (awk field reference, not fish cmdsubst)
        set -l _opts (printf '%s\n' "$_fl" | command awk '{ print $4 }')
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
            # catchall for forward-compat with new states from _ntsync_state.
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
    if not test -d "$nm_conn_dir"
        _info "  NetworkManager connections: directory not found"
        return 0
    end
    set -l conn_files (sudo -n find "$nm_conn_dir" -maxdepth 1 -name '*.nmconnection' -type f -print0 2>/dev/null | string split0)
    set -l _conn_ps $pipestatus
    if test "$_conn_ps[1]" -ne 0
        _warn "  NetworkManager connections: cannot enumerate (sudo lapse or read error)"
        return 0
    end
    if test (count $conn_files) -gt 0
        set -l bad_perms 0
        for conn_file in $conn_files
            _chk_perms "$conn_file" 600 root:root true; or set bad_perms (math $bad_perms + 1)
        end
        if test $bad_perms -eq 0
            set -l conn_count (count $conn_files)
            _ok "  NetworkManager connections: $conn_count files with correct permissions"
        end
    else if command grep -q -- 'wifi.backend=iwd' /etc/NetworkManager/conf.d/99-cachyos-nm.conf 2>/dev/null
        _warn "  NetworkManager connections: no .nmconnection files (WiFi may not auto-connect)"
    else
        _info "  NetworkManager connections: no .nmconnection files found"
    end
end

function _vrs_installed_file_perms --description "Runtime session check: installed system/service/user file perms"
    _echo "── Installed files ──"
    set -l perm_bad 0
    set -l perm_checked 0
    set -l _boot_fstype (findmnt -n -o FSTYPE /boot 2>/dev/null | string trim --)
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        if sudo -n test -f "$dst" 2>/dev/null
            string match -q '/boot/*' -- "$dst"; and test "$_boot_fstype" = vfat; and continue
            set perm_checked (math $perm_checked + 1)
            _chk_perms "$dst" 644 root:root true; or set perm_bad (math $perm_bad + 1)
        end
    end
    set -l expected_owner (id -un)":"(id -gn)
    for dst in $USER_DESTINATIONS
        if test -f "$dst"
            set perm_checked (math $perm_checked + 1)
            _chk_perms "$dst" 600 "$expected_owner" false; or set perm_bad (math $perm_bad + 1)
        end
    end
    if test $perm_bad -eq 0; and test $perm_checked -gt 0
        _ok "  All $perm_checked installed files: correct permissions and ownership"
    else if test $perm_checked -eq 0
        _warn "  No installed files found to check"
    end
end

function _vrs_parent_dirs --description "Runtime session check: parent directories of managed files (root-owned, not group/world-writable)"
    _echo "── Parent directories ──"
    set -l dir_bad 0
    set -l dir_checked 0
    set -l checked_dirs
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l dir (dirname -- "$dst")
        contains -- "$dir" $checked_dirs; and continue
        set -a checked_dirs "$dir"
        if sudo -n test -d "$dir" 2>/dev/null
            set dir_checked (math $dir_checked + 1)
            set -l _po (sudo -n stat -c '%a %U:%G' -- "$dir" 2>/dev/null)
            if test -z "$_po"
                _fail "  $dir: stat failed"
                set dir_bad (math $dir_bad + 1)
                continue
            end
            set -l perms (string split ' ' -- "$_po")[1]
            set -l owner (string split ' ' -- "$_po")[2]
            # parent-dir mode parse
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
    if not set -q EXPECTED_VULKAN_PKGS; or test (count $EXPECTED_VULKAN_PKGS) -eq 0
        _info "  EXPECTED_VULKAN_PKGS not defined — skipping"
        return 0
    end
    # single pacman -Qq replaces N forks of pacman -Q (one per pkg).
    set -l _vk_installed
    command -q pacman; and set _vk_installed (pacman -Qq 2>/dev/null)
    set -l _vk_missing 0
    for _vk_pkg in $EXPECTED_VULKAN_PKGS
        if contains -- "$_vk_pkg" $_vk_installed
            _ok "  $_vk_pkg: installed"
        else
            _fail "  $_vk_pkg: NOT installed (DXVK/VKD3D-Proton requires this)"
            set _vk_missing (math $_vk_missing + 1)
        end
    end
    test $_vk_missing -gt 0; and _info "  Install missing packages: sudo pacman -S $EXPECTED_VULKAN_PKGS"
end

function _vrs_boot_perf --description "Runtime session check: systemd-analyze boot time + slowest services"
    _echo
    _echo "BOOT PERFORMANCE"
    _echo
    if not command -q systemd-analyze
        _warn "  systemd-analyze not available"
        return 0
    end
    set -l boot_time (systemd-analyze 2>/dev/null | head -n 1)
    _info "  $boot_time"
    _log "BOOT_TIME_CHECK: parsing systemd-analyze output"
    if not string match -qr ' = [0-9.]+s' -- "$boot_time"
        _info "  systemd-analyze output format unrecognized — skipping target compare"
    else
        set -l total_sec (printf '%s\n' "$boot_time" | string match -r -- '= ([0-9.]+)s' | tail -n 1)
        if test -n "$total_sec"; and string match -qr '^\d+(\.\d+)?$' -- "$total_sec"
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
                _info "  BOOT_TIME_TARGET not set — skipping target comparison"
            end
        end
    end
    _echo "  Slowest services:"
    set -l blame (systemd-analyze blame 2>/dev/null | head -n 3)
    for line in $blame
        _info "    $line"
    end
end

function _verify_runtime_session --description "Verify file perms, parent dirs, Vulkan packages, boot performance"
    _echo "FILE PERMISSIONS"
    _echo
    _echo "── Sensitive files ──"
    _vrs_nm_perms
    _chk_path_mode_in "$HOME/.ssh/authorized_keys" "~/.ssh/authorized_keys" 600 644
    _chk_path_mode_in "$HOME/.ssh"                "~/.ssh directory"        700
    _echo
    _vrs_installed_file_perms
    _echo
    _vrs_parent_dirs
    _vrs_vulkan
    _echo
    _vrs_boot_perf
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

# INSTALL PIPELINE

function _dir_group_or_world_writable --argument-names mode --description "True when octal mode has group or world write bit"
    test (string length -- "$mode") -gt 3; and set mode (string sub -s 2 -- "$mode")
    # validate octal chars before math (else stderr noise before return 1).
    not string match -qr '^[0-7]+$' -- "$mode"; and return 1
    set -l group_w (string sub -s 2 -l 1 -- "$mode")
    set -l other_w (string sub -s 3 -l 1 -- "$mode")
    set -l group_has_w (math "floor($group_w / 2) % 2" 2>/dev/null)
    set -l other_has_w (math "floor($other_w / 2) % 2" 2>/dev/null)
    test "$group_has_w" -eq 1 2>/dev/null; and return 0
    test "$other_has_w" -eq 1 2>/dev/null; and return 0
    return 1
end

function _is_wifi_active_route --description "True if the default route exits via a wireless interface (handles VPN over WiFi)"
    # lint:ignore (awk field reference, not fish cmdsubst)
    set -l _def_iface (ip -4 route show default 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
    if test -z "$_def_iface"
        # lint:ignore (awk field reference, not fish cmdsubst)
        set _def_iface (ip -6 route show default 2>/dev/null | command awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
    end
    test -z "$_def_iface"; and return 1
    test -d "/sys/class/net/$_def_iface/wireless"; and return 0
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

function _start_sudo_keepalive --description "Launch background sudo credential refresh loop tied to LOCK_DIR inode. Child stderr captured to a tracked tmpfile so _check_sudo_keepalive can surface premature-exit reasons."
    set -l my_pid $fish_pid
    set -l _ka_script (string join \n 'set -l _start_inode (command stat -c %i -- "$argv[2]" 2>/dev/null); or exit 0' 'while command kill -0 -- $argv[1] 2>/dev/null; and test -d "$argv[2]"' '    test "$_start_inode" = (command stat -c %i -- "$argv[2]" 2>/dev/null); or break' '    command sudo -n -v 2>/dev/null; or break' '    command sleep $argv[3] 2>/dev/null' 'end' | string collect)
    set -g SUDO_KEEPALIVE_ERR (mktemp -t ry-ka-err.XXXXXX 2>/dev/null; or echo /dev/null)
    test "$SUDO_KEEPALIVE_ERR" != /dev/null; and _track_tmpfile "$SUDO_KEEPALIVE_ERR"
    env _RY_NO_LOG=1 fish --no-config -c "$_ka_script" -- "$my_pid" "$LOCK_DIR" "$SUDO_KEEPALIVE_INTERVAL" </dev/null >/dev/null 2>"$SUDO_KEEPALIVE_ERR" &
    set -g SUDO_KEEPALIVE_PID $last_pid
    if not kill -0 -- $SUDO_KEEPALIVE_PID 2>/dev/null
        functions -q _warn; and _warn "Sudo keepalive process failed to start — long installs may require re-auth"
        set --erase SUDO_KEEPALIVE_PID
        return 1
    end
    disown $SUDO_KEEPALIVE_PID 2>/dev/null
    return 0
end

function _ip_probe_sudo_policy --description "Probe sudo -l: reject incompatible Defaults; require unrestricted ALL grant. rc=0 ok, rc=EXIT_PREFLIGHT block."
    set -l _sudo_l_err (mktemp -t ry-sudo-l-err.XXXXXX 2>/dev/null; or echo /dev/null)
    _track_tmpfile "$_sudo_l_err"
    set -l _sudo_lines (sudo -n -l 2>"$_sudo_l_err" | command grep -v '^[[:space:]]*#')
    set -l sudo_all 0
    for _sl in $_sudo_lines
        if string match -qr -- '\bDefaults\b.*\b(requiretty|tty_tickets|timestamp_timeout=0)\b' "$_sl"
            _err "Sudoers contains incompatible Defaults: $_sl"
            test "$_sudo_l_err" != /dev/null; and _rm_tmp "$_sudo_l_err" false
            return $EXIT_PREFLIGHT
        end
        string match -qr -- '(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)' "$_sl"; and continue
        string match -qr -- '\((ALL|root)(\s*:\s*ALL)?\)\s+(NOPASSWD:\s*)?ALL(\s*,|\s*$)' "$_sl"; and set sudo_all (math $sudo_all + 1)
    end
    if test "$sudo_all" -eq 0
        if test "$_sudo_l_err" != /dev/null; and test -s "$_sudo_l_err"
            _log "SUDO_LIST_STDERR: "(command head -n 5 -- "$_sudo_l_err" 2>/dev/null | string join '; ')
        end
        test "$_sudo_l_err" != /dev/null; and _rm_tmp "$_sudo_l_err" false
        _err "Unattended install requires full sudo"
        return $EXIT_PREFLIGHT
    end
    test "$_sudo_l_err" != /dev/null; and _rm_tmp "$_sudo_l_err" false
    return 0
end

function _install_preflight --description "Run all preflight checks before installation"
    _progress Preflight
    _info "Sudo password required for installation..."
    printf '\n' >&2
    _ensure_sudo_cached; or return $EXIT_PREFLIGHT
    _ip_probe_sudo_policy; or begin; _kill_sudo_keepalive; return $EXIT_PREFLIGHT; end
    _start_sudo_keepalive
    _ry_check_deps; or begin; _kill_sudo_keepalive; return $EXIT_PREFLIGHT; end
    _ry_check_disk_space; or begin; _kill_sudo_keepalive; return $EXIT_PREFLIGHT; end
    if not _ry_check_network
        _err "Network required for package installation — aborting"
        _kill_sudo_keepalive; return $EXIT_PREFLIGHT
    end
    not _ry_check_kernel_version; and set -g INSTALL_HAD_ERRORS true
    _echo
    if not _ry_validate_configs
        _err "Configuration validation failed - aborting"
        _kill_sudo_keepalive; return $EXIT_PREFLIGHT
    end
end

function _mkinitcpio_revert --argument-names backup_bytes --description "Restore /etc/mkinitcpio.conf from in-memory backup bytes (pacman -Syu rollback). Returns 0 on success, 1 on any stage failure."
    set -l _mki_tmp (sudo -n mktemp -p /etc .ry-install.mki.XXXXXX 2>/dev/null)
    _track_tmpfile "$_mki_tmp"
    if test -z "$_mki_tmp"
        _err "  /etc/mkinitcpio.conf revert failed at mktemp — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: mktemp failed"
        return 1
    end
    # post-mktemp symlink check (mirrors _atomic_write_file). Defence-in-depth.
    if sudo -n test -L -- "$_mki_tmp" 2>/dev/null
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at symlink check — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: tmp is symlink"
        return 1
    end
    printf '%s' "$backup_bytes" | sudo -n tee -- "$_mki_tmp" >/dev/null 2>&1
    set -l _mki_ps $pipestatus
    if test "$_mki_ps[1]" -ne 0; or test "$_mki_ps[2]" -ne 0
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at write — current conf may reference uninstalled modules (pipestatus printf=$_mki_ps[1] tee=$_mki_ps[2])"
        _log "MKINITCPIO_REVERT_FAIL: pipestatus printf=$_mki_ps[1] tee=$_mki_ps[2]"
        return 1
    end
    if not sudo -n chmod --reference=/etc/mkinitcpio.conf -- "$_mki_tmp" 2>/dev/null
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at chmod — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: chmod failed"
        return 1
    end
    if not sudo -n chown --reference=/etc/mkinitcpio.conf -- "$_mki_tmp" 2>/dev/null
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at chown — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: chown failed"
        return 1
    end
    if not sudo -n mv -- "$_mki_tmp" /etc/mkinitcpio.conf 2>/dev/null
        _rm_tmp "$_mki_tmp" true
        _err "  /etc/mkinitcpio.conf revert failed at atomic mv — current conf may reference uninstalled modules"
        _log "MKINITCPIO_REVERT_FAIL: mv failed"
        return 1
    end
    _untrack_tmpfile "$_mki_tmp"
    _warn "  /etc/mkinitcpio.conf restored to pre-install content"
    _log "MKINITCPIO_REVERT_OK: pacman failure → restored backup"
    return 0
end

function _ip_snapshot_mkinitcpio --description "Snapshot /etc/mkinitcpio.conf for rollback; sets _RY_MKI_BACKUP / _RY_MKI_HAD_ORIG globals"
    set -g _RY_MKI_BACKUP ""
    set -g _RY_MKI_HAD_ORIG false
    if not sudo -n true 2>/dev/null
        _log "MKINITCPIO_BACKUP_SKIPPED: sudo -n returned non-zero before snapshot"
        return 0
    end
    if sudo -n test -f /etc/mkinitcpio.conf 2>/dev/null
        set -g _RY_MKI_BACKUP (sudo -n cat -- /etc/mkinitcpio.conf 2>/dev/null | string collect --no-trim-newlines)
        test $pipestatus[1] -eq 0; and set -g _RY_MKI_HAD_ORIG true
    end
end

function _ip_pacman_invoke --description "Run pacman -Syu (or -Sy via RY_INSTALL_ALLOW_PARTIAL_UPGRADE); rc=0 ok, rc=1 failed-with-rollback"
    set -l _pacman_first; set -l _pacman_retry; set -l _do_upgrade true
    if test "$RY_INSTALL_ALLOW_PARTIAL_UPGRADE" = 1
        set _pacman_first -Sy --needed --noconfirm
        set _pacman_retry -Syy --needed --noconfirm
        set _do_upgrade false
        _warn "Partial-upgrade mode (RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1) — violates Arch's no-partial-upgrade policy"
        _info "  Refresh DB + install listed pkgs only; dependency-version skew may break shared-library ABI"
        _log "PARTIAL_UPGRADE_MODE: RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1"
    else
        set _pacman_first -Syu --needed --noconfirm
        set _pacman_retry -Syyu --needed --noconfirm
        _info "System upgrade proceeding unattended — review archlinux.org/news and wiki.cachyos.org post-install"
    end
    if test -f /var/lib/pacman/db.lck
        _err "Pacman database is locked (/var/lib/pacman/db.lck exists) — skipping package install"
        return 1
    end
    if not _run sudo -n pacman $_pacman_first -- $argv
        _warn "Package installation failed, retrying with fresh sync (first-pass stderr in JSONL log)..."
        if not _run sudo -n pacman $_pacman_retry -- $argv
            _err "Package installation failed after retry"
            test "$_RY_MKI_HAD_ORIG" = true; and test -n "$_RY_MKI_BACKUP"; and _mkinitcpio_revert "$_RY_MKI_BACKUP"
            return 1
        end
    end
    test "$_do_upgrade" = true; and set -g SYSTEM_UPGRADED true
    return 0
end

function _ip_scan_pacnew --description "Scan managed destinations for .pacnew/.pacsave remnants; warns and logs"
    set -l _pacnew_found
    for _dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        for _suffix in .pacnew .pacsave
            sudo -n test -f "$_dst$_suffix" 2>/dev/null; and set -a _pacnew_found "$_dst$_suffix"
        end
    end
    test (count $_pacnew_found) -eq 0; and return 0
    _warn "Pacman config remnants found at managed destinations:"
    for _f in $_pacnew_found
        _warn "  $_f"
    end
    _warn "  Review with: sudo pacdiff   (then re-run install to redeploy managed configs)"
    _log "PACNEW_FOUND: $_pacnew_found"
end

function _install_packages --description "Install managed packages via pacman -Syu"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Packages
    _echo
    _info "Package installation..."
    set -l pkgs_to_install $PKGS_ADD
    set -g SYSTEM_UPGRADED false
    _ip_snapshot_mkinitcpio
    if not _ry_install_file "/etc/mkinitcpio.conf" true
        _err "Failed to pre-deploy mkinitcpio.conf before package install"
        _err "Aborting package installation — mkinitcpio.conf must be in place before -Syu"
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        return 1
    end
    if test (count $pkgs_to_install) -gt 0
        if not _ip_pacman_invoke $pkgs_to_install
            set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true; set _fn_err true
        end
        _info "Verifying package installation..."
        set -l missing_pkgs (pacman -T -- $pkgs_to_install 2>/dev/null)
        if test (count $missing_pkgs) -gt 0
            _err "Missing packages: $missing_pkgs"
            _warn "  Install manually: sudo pacman -S --needed $missing_pkgs"
            set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true; set _fn_err true
        else
            _ok "All packages verified installed"
        end
    end
    _ip_scan_pacnew
    set --erase _RY_MKI_BACKUP _RY_MKI_HAD_ORIG
    test "$_fn_err" = true; and return 1
    return 0
end

function _install_aur_packages --description "Install AUR packages via paru"
    not set -q AUR_PKGS; or test (count $AUR_PKGS) -eq 0; and return 0
    if not command -q paru
        _err "paru not found — cannot install AUR packages: $AUR_PKGS"
        _err "  Install paru: sudo pacman -S --needed paru"
        _err "  AUR_PKGS may include critical drivers (e.g. WiFi DKMS)"
        set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
        return 1
    end
    set -l _had_fail false
    if not _run paru -S --needed --noconfirm -- $AUR_PKGS
        _warn "AUR batch install failed — retrying per-package to identify failures"
        for pkg in $AUR_PKGS
            if not _run paru -S --needed --noconfirm -- "$pkg"
                _warn "AUR install failed: $pkg"
                set -g INSTALL_HAD_ERRORS true; set -g _RY_BOOT_TAINTED true
                set _had_fail true
            end
        end
    end
    test "$_had_fail" = true; and return 1
    return 0
end

function _isf_deploy_set --argument-names use_sudo phase --description "Deploy all destinations from argv[3..]; rc=0 ok, rc=1 any failure. Sets _RY_BOOT_TAINTED when a failed dst is in _RY_BOOT_CRITICAL_DSTS."
    set -l _had_failure false
    for dst in $argv[3..]
        if not _ry_install_file "$dst" $use_sudo
            set _had_failure true
            contains -- "$dst" $_RY_BOOT_CRITICAL_DSTS; and set -g _RY_BOOT_TAINTED true
        end
    end
    test "$_had_failure" = true; and _err "$phase file installation failed"; and return 1
    return 0
end

function _install_system_files --description "Deploy all 15 embedded config files (system + user + service units) to the system"
    _check_sudo_keepalive
    set -l _fn_err false
    _progress Configuration
    _echo; _info "Installing system configuration files..."; _log "=== INSTALL SYSTEM FILES ==="
    if not _isf_deploy_set true System $SYSTEM_DESTINATIONS
        set -g INSTALL_HAD_ERRORS true; set _fn_err true
    end
    _echo; _info "Installing service unit files..."; _log "=== INSTALL SERVICE FILES ==="
    set -g _RY_DEPLOYED_SERVICES
    set -l _svc_failed false
    for dst in $SERVICE_DESTINATIONS
        if _ry_install_file "$dst" true
            set -a _RY_DEPLOYED_SERVICES (basename -- "$dst")
        else
            set _svc_failed true
        end
    end
    if test "$_svc_failed" = true
        _err "Service unit file installation failed"
        set -g INSTALL_HAD_ERRORS true; set _fn_err true
    end
    _echo; _info "Installing user configuration files..."; _log "=== INSTALL USER FILES ==="
    if not _isf_deploy_set false User $USER_DESTINATIONS
        set -g INSTALL_HAD_ERRORS true; set _fn_err true
    end
    test "$_fn_err" = true; and return 1
    return 0
end

function _fstab_needs_change --description "Scan ext4 entries for missing noatime/lazytime/commit=10; sets _RY_FSTAB_NEEDS_CHANGE + _RY_FSTAB_COMMIT_OVERRIDES globals; returns 0 always"
    set -g _RY_FSTAB_NEEDS_CHANGE false
    set -g _RY_FSTAB_COMMIT_OVERRIDES
    for line in $argv
        # lint:ignore (awk field reference, not fish cmdsubst)
        set -l opts_field (printf '%s\n' "$line" | command awk '{ print $4 }')
        if not string match -qr '(^|,)noatime(,|$)' -- "$opts_field"; or not string match -qr '(^|,)lazytime(,|$)' -- "$opts_field"; or not string match -qr '(^|,)commit=10(,|$)' -- "$opts_field"
            set -g _RY_FSTAB_NEEDS_CHANGE true
            # -rg + non-capturing
            set -l _existing_commit (string match -rg -- '(?:^|,)commit=([0-9]+)(?:,|$)' -- "$opts_field")
            test -n "$_existing_commit"; and test "$_existing_commit" != 10; and set -ga _RY_FSTAB_COMMIT_OVERRIDES "$_existing_commit"
        end
    end
end

function _far_awk_rewrite --argument-names tmpfstab --description "Run fstab awk rewrite into tmpfstab via tee; rc=0 ok, rc=1 pipeline failure"
    set -l _awk_script (string join \n 'BEGIN { OFS = "\t" }' '/^[[:space:]]*#/ || NF < 4 { print; next }' '$3 != "ext4" { print; next }' '{' '    n = split($4, opts, ",")' '    has_noat = 0; has_lazy = 0; out = ""' '    for (i = 1; i <= n; i++) {' '        o = opts[i]' '        if (o == "relatime" || o == "atime" || o == "strictatime") continue' '        if (o ~ /^commit=/) continue' '        if (o == "noatime") has_noat = 1' '        if (o == "lazytime") has_lazy = 1' '        out = (out == "" ? o : out "," o)' '    }' '    if (!has_noat)  out = (out == "" ? "noatime"  : out ",noatime")' '    if (!has_lazy)  out = (out == "" ? "lazytime" : out ",lazytime")' '    out = (out == "" ? "commit=10" : out ",commit=10")' '    $4 = out' '    print' '}' | string collect)
    command awk "$_awk_script" /etc/fstab | sudo -n tee -- "$tmpfstab" >/dev/null
    set -l _ps $pipestatus
    if test "$_ps[1]" -ne 0; or test "$_ps[2]" -ne 0
        set -l _ps_str (string join , -- $_ps); test -z "$_ps_str"; and set _ps_str "(empty)"
        _fail "  /etc/fstab: awk/tee rewrite failed (pipestatus=$_ps_str)"
        return 1
    end
    return 0
end

function _fstab_atomic_replace --description "Atomic /etc/fstab rewrite: mktemp → awk transform → chmod/chown ref → findmnt verify → mv. rc=0 ok, rc=1 fail"
    set -l tmpfstab (sudo -n mktemp -p /etc .ry-install.fstab.XXXXXX 2>/dev/null)
    _track_tmpfile "$tmpfstab"
    test -z "$tmpfstab"; and _fail "  /etc/fstab: mktemp failed"; and return 1
    if sudo -n test -L "$tmpfstab"
        _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: temp file is symlink — aborting"; return 1
    end
    if not _far_awk_rewrite "$tmpfstab"
        _rm_tmp "$tmpfstab" true; return 1
    end
    if not sudo -n chmod --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null
        _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: chmod --reference failed"; return 1
    end
    if not sudo -n chown --reference=/etc/fstab -- "$tmpfstab" 2>/dev/null
        _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: chown --reference failed"; return 1
    end
    if command -q findmnt
        set -l _verify_out (sudo -n findmnt --verify --tab-file "$tmpfstab" 2>&1)
        if test $status -ne 0
            _rm_tmp "$tmpfstab" true
            _fail "  /etc/fstab: findmnt --verify failed: "(printf '%s\n' $_verify_out | head -n 3 | string join '; ')
            return 1
        end
    end
    if not sudo -n mv -- "$tmpfstab" /etc/fstab
        _rm_tmp "$tmpfstab" true; _fail "  /etc/fstab: atomic move failed"; return 1
    end
    _untrack_tmpfile "$tmpfstab"
    return 0
end

function _install_fstab_opts --description "Add noatime,lazytime,commit=10 to ext4 fstab entries"
    _check_sudo_keepalive
    if not test -f /etc/fstab
        _warn "  /etc/fstab not found — skipping"
        return 0
    end
    if test -L /etc/fstab
        _fail "  /etc/fstab is a symlink — refusing to rewrite (resolve symlink first or skip fstab opts)"
        return 1
    end
    if not test -r /etc/fstab
        _fail "  /etc/fstab not readable — cannot rewrite (check sudoers / fstab perms)"
        return 1
    end
    # lint:ignore (awk field reference + boolean operators, not fish cmdsubst)
    set -l ext4_lines (command awk '!/^[[:space:]]*#/ && NF >= 4 && $3 == "ext4" { print $0 }' /etc/fstab 2>/dev/null)
    if test -z "$ext4_lines"
        _info "  No ext4 entries in /etc/fstab"
        return 0
    end
    _fstab_needs_change $ext4_lines
    if test "$_RY_FSTAB_NEEDS_CHANGE" = false
        set --erase _RY_FSTAB_NEEDS_CHANGE _RY_FSTAB_COMMIT_OVERRIDES
        _ok "  /etc/fstab: ext4 entries already have noatime,lazytime,commit=10"
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
    if test -f /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf
        not _run sudo -n systemctl restart systemd-resolved; and _warn "Systemd-resolved restart failed"
    end
    return 0
end

function _csp_filter_rdeps --argument-names pkg --description "Echo $pkg if removable (no reverse deps outside PKGS_DEL); else empty"
    if not command -q pactree
        echo "$pkg"; return 0
    end
    set -l _rdeps_raw (pactree -ru "$pkg" 2>/dev/null | string trim -- | string match -v -- "$pkg" | string match -rv '^$')
    set -l _rdeps
    for _r in $_rdeps_raw
        contains -- "$_r" $PKGS_DEL; and continue
        set -a _rdeps "$_r"
    end
    if test (count $_rdeps) -gt 0
        _warn "  $pkg has reverse dependencies: $_rdeps — skipping"
        return 0
    end
    echo "$pkg"
end

function _csp_remove_pkgs --description "pacman -Rns batch with per-pkg retry on batch failure; bumps INSTALL_HAD_ERRORS on db lock"
    if test -f /var/lib/pacman/db.lck
        _err "Pacman database is locked (/var/lib/pacman/db.lck exists) — skipping package removal"
        set -g INSTALL_HAD_ERRORS true; return 0
    end
    if _run sudo -n pacman -Rns --noconfirm -- $argv
        _log "PKG_REMOVE_BATCH_OK: $argv"; return 0
    end
    _warn "Batch removal failed, trying individually..."
    _log "PKG_REMOVE_BATCH_FAIL: $argv"
    set -l _retry_installed (pacman -Qq 2>/dev/null)
    for pkg in $argv
        contains -- "$pkg" $_retry_installed; or continue
        if not _run sudo -n pacman -Rns --noconfirm -- "$pkg"
            _warn "Failed to remove $pkg"; _log "PKG_REMOVE_FAIL: $pkg"
        else
            _log "PKG_REMOVE_OK: $pkg"
        end
    end
end

function _configure_services_pkg_remove --description "Remove PKGS_DEL packages (rdep-aware via pactree). No-op when pacman absent or db locked."
    if not command -q pacman
        _warn "pacman not found, skipping PKGS_DEL removal"; return 0
    end
    set -l to_del
    set -l _del_installed (pacman -Qq 2>/dev/null)
    for pkg in $PKGS_DEL
        contains -- "$pkg" $_del_installed; or continue
        set -l _ok_pkg (_csp_filter_rdeps "$pkg")
        test -n "$_ok_pkg"; and set -a to_del "$_ok_pkg"
    end
    if test (count $to_del) -gt 0
        _log "PKG_REMOVE_REQUESTED: $to_del"
        _csp_remove_pkgs $to_del
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
        not _run sudo -n systemctl mask -- $safe_mask; and _warn "Failed to mask some services"
    end
    return 0
end

function _cse_collect_units --description "Collect system units to enable: NM-dispatcher + deployed + EXPECTED minus pkg-managed; emits one unit per line"
    set -l _enable
    set -l _ndsp (systemctl is-enabled NetworkManager-dispatcher.service 2>/dev/null | string trim --)
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
    for _exp in $EXPECTED_SERVICES
        contains -- "$_exp" $_RY_DEPLOYED_SERVICES; and continue
        contains -- "$_exp" $_RY_PKG_MANAGED_SERVICES; and continue
        set -a _enable "$_exp"
    end
    for _u in $_enable; echo $_u; end
end

function _cse_batch_enable --description "Batch enable system units; falls back to per-unit enable on batch failure. On --now failure, distinguishes 'enable ok, start failed' (warn, will activate next boot) from 'enable failed' (err, taint INSTALL_HAD_ERRORS)."
    test (count $argv) -eq 0; and return 0
    if _run sudo -n systemctl enable --now -- $argv
        return 0
    end
    _warn "Batch enable failed — retrying individually to identify failures"
    set -l _ret 0
    for _unit in $argv
        if _run sudo -n systemctl enable --now -- $_unit
            _ok "Enabled: $_unit"
        else
            # Distinguish "enable succeeded but start (--now) failed" from "enable failed".
            # systemctl enable --now returns non-zero in both cases; probe is-enabled to split.
            set -l _enabled_state (systemctl is-enabled -- $_unit 2>/dev/null | string trim)
            if test "$_enabled_state" = enabled; or test "$_enabled_state" = enabled-runtime; or test "$_enabled_state" = alias; or test "$_enabled_state" = static
                _warn "Enabled but failed to start: $_unit (will activate on next boot if config is fixed)"
                _warn "  Diagnose: systemctl status $_unit; journalctl -u $_unit -b"
                _log "ENABLE_OK_START_FAIL: unit=$_unit is-enabled=$_enabled_state"
            else
                _err "Failed to enable: $_unit (is-enabled=$_enabled_state)"; set -g INSTALL_HAD_ERRORS true; set _ret 1
            end
        end
    end
    return $_ret
end

function _cse_ssh_agent --description "Enable user ssh-agent.service; gates --now on active user-bus; rc=1 on enable failure"
    if not systemctl --user cat ssh-agent.service >/dev/null 2>&1
        _warn "ssh-agent.service user unit not found"
        _info "  Expected at ~/.config/systemd/user/ssh-agent.service"
        return 0
    end
    set -l _has_user_bus false
    set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"; and set _has_user_bus true
    if test "$_has_user_bus" = false
        _info "  ssh-agent.service: enabling without --now (no active user-bus session — start manually post-login)"
        not _run systemctl --user enable ssh-agent.service; and _warn "Failed to enable ssh-agent.service"; and return 1
        return 0
    end
    if not _run systemctl --user enable --now ssh-agent.service
        _warn "Failed to enable ssh-agent.service"; return 1
    end
    _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"; or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
    return 0
end

function _configure_services_enable --description "Daemon-reload, batch-enable system units, enable ssh-agent (user)"
    set -l _ret 0
    set -l _units (_cse_collect_units)
    _cse_batch_enable $_units; or set _ret 1
    not _run systemctl --user daemon-reload; and _warn "Systemctl --user daemon-reload failed"
    _cse_ssh_agent; or set _ret 1
    return $_ret
end

function _install_configure_services --description "Enable, start, and configure systemd services"
    _check_sudo_keepalive
    _progress Services
    _echo
    _info "Post-installation tasks..."
    set -l _ret 0
    _configure_services_resolved_restart; or set _ret 1
    _configure_services_pkg_remove; or set _ret 1
    _configure_services_mask; or set _ret 1
    _configure_services_enable; or set _ret 1
    return $_ret
end

function _resolve_esp --description "Resolve EFI system partition path (cached); falls back to /boot."
    if set -q _RY_ESP_PATH; and test -n "$_RY_ESP_PATH"
        echo "$_RY_ESP_PATH"
        return 0
    end
    set -l _p ""
    command -q bootctl; and set _p (sudo -n bootctl -p 2>/dev/null | string trim --)
    if test -z "$_p"; or not sudo -n test -d "$_p" 2>/dev/null
        for _candidate in /efi /boot/efi /boot
            set -l _fs (command findmnt -no FSTYPE -- "$_candidate" 2>/dev/null)
            if test "$_fs" = vfat
                set _p "$_candidate"
                break
            end
        end
    end
    if test -z "$_p"; or not sudo -n test -d "$_p" 2>/dev/null
        set _p /boot
        functions -q _warn; and _warn "  ESP autodetect failed — defaulting to /boot. Verify systemd-boot mount: findmnt /boot"
        functions -q _log; and _log "ESP_RESOLVE_FALLBACK: bootctl/findmnt failed, defaulting to /boot"
    end
    set -g _RY_ESP_PATH "$_p"
    echo "$_p"
end

function _enum_boot_entries --argument-names esp --description "Enumerate \$esp/loader/entries/*.conf — sets _RY_BOOT_COUNT, _RY_BOOT_HASH, _RY_BOOT_PIPE_OK"
    set -l _basenames (sudo -n find "$esp/loader/entries" -maxdepth 1 -type f -name '*.conf' -printf '%f\0' 2>/dev/null | LC_ALL=C sort -z | string split0)
    # capture $pipestatus immediately; mirrors v4.4.31 fstab pattern.
    set -l _ps $pipestatus
    set -g _RY_BOOT_PIPE_OK true
    for _ps_rc in $_ps
        test "$_ps_rc" = 0; or set -g _RY_BOOT_PIPE_OK false
    end
    set -g _RY_BOOT_COUNT (count $_basenames)
    set -g _RY_BOOT_HASH ""
    test "$_RY_BOOT_COUNT" -gt 0; and set -g _RY_BOOT_HASH (printf '%s\0' $_basenames | sha256sum | string split ' ')[1]
end

function _pbs_check_kernels --argument-names esp --description "_preflight_boot_sanity sub: enumerate vmlinuz-* in ESP root; verify all are non-zero. Echoes error count to stdout."
    set -l errors 0
    set -l vmlinuz_files (sudo -n find "$esp" -maxdepth 1 -name 'vmlinuz-*' -type f -print0 2>/dev/null | string split0)
    set -l _vm_ps $pipestatus
    set -l _vm_pipe_ok true
    for _rc in $_vm_ps
        test "$_rc" = 0; or set _vm_pipe_ok false
    end
    if test "$_vm_pipe_ok" = false
        _err "Cannot enumerate $esp/ for vmlinuz-* (sudo lapsed or read error)"
        set errors (math $errors + 1)
    else if test (count $vmlinuz_files) -eq 0
        _err "No vmlinuz found in $esp/"
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
    echo $errors
end

function _pbs_check_initrds --argument-names esp --description "_preflight_boot_sanity sub: enumerate initramfs-*.img in ESP root; verify all are non-zero. Echoes error count to stdout."
    set -l errors 0
    set -l initrd_files (sudo -n find "$esp" -maxdepth 1 -name 'initramfs-*.img' -type f -print0 2>/dev/null | string split0)
    set -l _ir_ps $pipestatus
    set -l _ir_pipe_ok true
    for _rc in $_ir_ps
        test "$_rc" = 0; or set _ir_pipe_ok false
    end
    if test "$_ir_pipe_ok" = false
        _err "Cannot enumerate $esp/ for initramfs-*.img (sudo lapsed or read error)"
        set errors (math $errors + 1)
    else if test (count $initrd_files) -eq 0
        _err "No initramfs found in $esp/"
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
    echo $errors
end

function _pbs_entry_has_valid_kernel --argument-names esp conf --description "Probe a single loader-entry .conf for a kernel image inside ESP; rc=0 valid, rc=1 invalid/missing"
    set -l linux_line (sudo -n grep -m1 '^linux ' -- "$conf" 2>/dev/null | string replace -r '^linux\s+' '' | string trim --)
    test -z "$linux_line"; and return 1
    set -l linux_check
    string match -q -- '/*' "$linux_line"; and set linux_check "$linux_line"; or set linux_check "$esp/$linux_line"
    set -l linux_canon (command realpath -m -- "$linux_check" 2>/dev/null)
    test -z "$linux_canon"; and _warn "  Loader entry path could not be canonicalized: $conf ($linux_line)"; and return 1
    set -l _esp_re (string escape --style=regex -- "$esp")
    if not string match -qr -- "^"$_esp_re"(/|\$)" "$linux_canon"
        _warn "  Loader entry escapes ESP boundary: $conf -> $linux_canon"; return 1
    end
    sudo -n test -f "$linux_canon" 2>/dev/null
end

function _pbs_check_entries --argument-names esp --description "Enumerate ESP/loader/entries/*.conf; verify ≥1 references a valid kernel inside ESP. Echoes error count."
    set -l errors 0
    set -l confs (sudo -n find "$esp/loader/entries" -maxdepth 1 -name '*.conf' -type f -print0 2>/dev/null | string split0)
    set -l _cf_ps $pipestatus
    for _rc in $_cf_ps
        test "$_rc" = 0; or begin
            _err "Cannot enumerate $esp/loader/entries (sudo lapsed or read error)"
            set errors (math $errors + 1); echo $errors; return
        end
    end
    if test (count $confs) -eq 0
        _err "No boot loader entries in $esp/loader/entries/"
        set errors (math $errors + 1); echo $errors; return
    end
    set -l valid_entry false
    for conf in $confs
        if _pbs_entry_has_valid_kernel "$esp" "$conf"
            set valid_entry true; break
        end
    end
    test "$valid_entry" = false; and _err "No boot entry references a valid kernel image"; and set errors (math $errors + 1)
    echo $errors
end

function _preflight_boot_sanity --description "Verify boot artifacts are viable after rebuild"
    _check_sudo_keepalive
    set -l _esp (_resolve_esp)
    set -l errors (math (_pbs_check_kernels "$_esp") + (_pbs_check_initrds "$_esp") + (_pbs_check_entries "$_esp"))
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

function _bwg_eval_marker --argument-names wipe_marker existing_count existing_hash --description "Evaluate marker file vs current entry set; rc=0 ack, rc=1 mismatch (errs already emitted)"
    set -l _marker_raw (string trim -- (command cat -- "$wipe_marker" 2>/dev/null))
    set -l _parts (string split ' ' -- "$_marker_raw")
    set -l _marked_count "$_parts[1]"
    set -l _marked_hash ""
    test (count $_parts) -ge 2; and set _marked_hash "$_parts[2]"
    if test -z "$_marked_hash"; or not string match -qr '^\d+$' -- "$_marked_count"
        _log "BOOT_WIPE_ACK: legacy marker $wipe_marker (current_entries=$existing_count hash=$existing_hash)"
        return 0
    end
    if test "$existing_hash" = "$_marked_hash"
        _log "BOOT_WIPE_ACK: marker hash match $wipe_marker (count=$existing_count)"
        return 0
    end
    set -l _ms (string sub --length 16 -- "$_marked_hash")
    set -l _es (string sub --length 16 -- "$existing_hash")
    _err "Boot loader entries changed since last acknowledged wipe: marked_count=$_marked_count current=$existing_count marked_hash=$_ms current_hash=$_es"
    _err "  Entry set delta detected (added, removed, or renamed) — manual entries (rescue, Windows, custom kernels) may be affected."
    _err "  To proceed: RY_INSTALL_CONFIRM_BOOT_WIPE=1 ./ry-install.fish"
    return 1
end

function _boot_wipe_gate --argument-names esp wipe_marker --description "Gate for SDBOOT_REMOVE_EXISTING=yes — rc=0 ack, rc=EXIT_PREFLIGHT/EXIT_BOOT_CRIT refusal"
    _enum_boot_entries "$esp"
    if test "$_RY_BOOT_PIPE_OK" = false
        _err "Cannot enumerate $esp/loader/entries — refusing wipe gate"
        _log "BOOT_WIPE_PRECHECK_PIPE_FAIL: enumerate failed"
        set -g INSTALL_HAD_ERRORS true
        return $EXIT_PREFLIGHT
    end
    set -l _existing_entries $_RY_BOOT_COUNT
    set -l _existing_hash $_RY_BOOT_HASH
    set -l _acknowledged false
    if test "$RY_INSTALL_CONFIRM_BOOT_WIPE" = 1
        set _acknowledged true
        _log "BOOT_WIPE_ACK: env var RY_INSTALL_CONFIRM_BOOT_WIPE=1 entries=$_existing_entries hash=$_existing_hash"
    else if test -f "$wipe_marker"
        if _bwg_eval_marker "$wipe_marker" "$_existing_entries" "$_existing_hash"
            set _acknowledged true
        else
            set -g INSTALL_HAD_ERRORS true
            return $EXIT_BOOT_CRIT
        end
    end
    if test "$_acknowledged" = false
        _err "SDBOOT_REMOVE_EXISTING=yes will delete $_existing_entries existing $esp/loader/entries/*.conf file(s)"
        _err "  Manual entries (rescue, Windows, custom kernels) will be LOST."
        _err "  To proceed (one-time): RY_INSTALL_CONFIRM_BOOT_WIPE=1 ./ry-install.fish"
        _err "  After the first successful run, marker file $wipe_marker will record the entry-set hash and suppress this gate until the entry set changes."
        set -g INSTALL_HAD_ERRORS true
        return $EXIT_BOOT_CRIT
    end
    _warn "SDBOOT_REMOVE_EXISTING=yes — all existing $esp/loader/entries/*.conf will be deleted and regenerated."
    _warn "Manual entries (rescue, Windows, custom kernels) will be LOST."
    return 0
end

function _boot_initrd_size_scan --argument-names esp --description "Post-rebuild initramfs size sanity check; warn if >100 MB. Returns 0 always (advisory)."
    set -l _initrd_list (sudo -n find "$esp" -maxdepth 1 -type f -name 'initramfs-*.img' -print0 2>/dev/null | string split0)
    set -l _il_ps $pipestatus
    set -l _il_pipe_ok true
    for _rc in $_il_ps
        test "$_rc" = 0; or set _il_pipe_ok false
    end
    if test "$_il_pipe_ok" = false
        _warn "Cannot enumerate initramfs-*.img for size check (sudo lapsed or read error)"
        return 0
    end
    for initrd in $_initrd_list
        # stat -c %s gives exact bytes
        set -l size_b (sudo -n stat -c '%s' -- "$initrd" 2>/dev/null)
        if test -n "$size_b"; and string match -qr '^\d+$' -- "$size_b"
            set -l size_mb (math "floor($size_b / 1048576)")
            if test "$size_mb" -gt 100
                _warn "Large initramfs: $initrd ($size_mb MB) - consider reviewing MODULES/HOOKS"
            else
                _ok "Initramfs size: $initrd ($size_mb MB)"
            end
        end
    end
    return 0
end

function _irb_sdboot_apply --description "Run sdboot-manage gen + update; rc=EXIT_BOOT_CRIT on either failure"
    if not _run sudo -n sdboot-manage gen
        _err "Sdboot-manage gen failed"
        _err "CRITICAL: Bootloader update failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end
    if not _run sudo -n sdboot-manage update
        _err "Sdboot-manage update failed (bootctl EFI binary refresh)"
        _err "CRITICAL: Bootloader binary update failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end
    return 0
end

function _irb_verify_entries --argument-names esp --description "Re-enumerate boot entries post-rebuild; warns if zero, runs initrd-size scan"
    _check_sudo_keepalive
    _enum_boot_entries "$esp"
    set -l entry_count $_RY_BOOT_COUNT
    if test "$entry_count" -gt 0
        _ok "Boot entries: $entry_count found in $esp/loader/entries/"
    else
        _err "No boot entries found in $esp/loader/entries/"
        _info "  System may not boot! Check /etc/sdboot-manage.conf LINUX_OPTIONS"
        _info "  Try: sudo sdboot-manage gen --verbose"
        set -g INSTALL_HAD_ERRORS true
    end
    _boot_initrd_size_scan "$esp"
end

function _install_rebuild_boot --description "Regenerate initramfs and bootloader entries"
    _check_sudo_keepalive
    _progress Boot
    test "$SYSTEM_UPGRADED" = true; and _ok "System upgraded during package installation"
    if test "$_RY_BOOT_TAINTED" = true; and not test "$RY_INSTALL_FORCE_BOOT_REBUILD" = 1
        _err "Refusing initramfs rebuild — package or boot-critical config state may be inconsistent"
        _err "  (mkinitcpio.conf, kernel cmdline, loader, sdboot-manage, or pacman/AUR install failed)"
        _err "  Resolve manually then re-run, OR set RY_INSTALL_FORCE_BOOT_REBUILD=1 to force"
        return $EXIT_BOOT_CRIT
    end
    if not _run sudo -n mkinitcpio -P
        _err "Mkinitcpio failed"
        _err "CRITICAL: Boot rebuild failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end
    if test "$SDBOOT_REMOVE_EXISTING" = yes
        set -l _esp (_resolve_esp)
        _boot_wipe_gate "$_esp" "$BOOT_WIPE_MARKER"
        set -l _gate_rc $status
        test $_gate_rc -ne 0; and return $_gate_rc
    end
    _irb_sdboot_apply; or return $status
    set -l _esp (_resolve_esp)
    _irb_verify_entries "$_esp"
    if not _preflight_boot_sanity
        _err "CRITICAL: Boot sanity failed — aborting remaining steps"
        return $EXIT_BOOT_CRIT
    end
    return 0
end

function _if_write_wipe_marker --description "Atomically write boot-wipe marker after successful entry rebuild; warns on any failure"
    set -l _esp (_resolve_esp)
    set -l _wipe_marker $BOOT_WIPE_MARKER
    _enum_boot_entries "$_esp"
    set -l _post_count $_RY_BOOT_COUNT
    if test "$_RY_BOOT_PIPE_OK" = false
        _warn "Failed to enumerate /boot/loader/entries for marker update — leaving marker untouched"
        _log "BOOT_WIPE_MARKER_SKIP: pipestatus failure during enumeration"
        return 0
    end
    if test "$_post_count" -lt 1
        _warn "No boot loader entries present after rebuild — refusing to write 0-count marker"
        _log "BOOT_WIPE_MARKER_SKIP: post_count=0"
        return 0
    end
    set -l _post_hash $_RY_BOOT_HASH
    set -l _marker_dir (dirname -- "$_wipe_marker")
    set -l _prev_umask (umask); umask 0177
    set -l _marker_tmp (mktemp -p "$_marker_dir" .boot-wipe.XXXXXX 2>/dev/null)
    umask $_prev_umask
    _track_tmpfile "$_marker_tmp"
    test -z "$_marker_tmp"; and _warn "Failed to mktemp boot-wipe marker tmpfile"; and return 0
    if not printf '%s %s\n' "$_post_count" "$_post_hash" >"$_marker_tmp" 2>/dev/null
        _rm_tmp "$_marker_tmp" false; _warn "Failed to write boot-wipe marker tmpfile"; return 0
    end
    command chmod -- 600 "$_marker_tmp" 2>/dev/null
    if command mv -f -- "$_marker_tmp" "$_wipe_marker" 2>/dev/null
        _untrack_tmpfile "$_marker_tmp"
        _log "BOOT_WIPE_MARKER_UPDATED: $_wipe_marker count=$_post_count hash=$_post_hash"
    else
        _rm_tmp "$_marker_tmp" false; _warn "Failed to atomically install boot-wipe marker"
    end
end

function _if_trim_pacman_cache --description "Trim pacman cache via paccache -rk2 -ruk0; falls back to pacman -Sc"
    if command -q paccache
        not _run sudo -n paccache -rk2 -ruk0; and _warn "Paccache cache trim failed"
    else
        not _run sudo -n pacman -Sc --noconfirm; and _warn "Pacman cache clear failed"
    end
end

function _if_nm_restart --description "Restart NetworkManager when iwd backend switch is in effect; defers on active WiFi route"
    if test "$_PROFILE_USES_WIFI_BACKEND" = false
        _info "iwd/NetworkManager not managed — skipping NM restart"
        return 0
    end
    if not command -q pacman; or not pacman -Qi iwd >/dev/null 2>&1
        _warn "iwd configs deployed but iwd package is not installed"
        set -g INSTALL_HAD_ERRORS true
        return 0
    end
    if _is_wifi_active_route
        _warn "NetworkManager restart deferred — WiFi is the active route."
        _warn "  Backend switch to iwd will not take effect until next reboot or manual restart."
        _warn "  After reconnecting via ethernet (or post-reboot): sudo systemctl restart NetworkManager"
        _log "NM_RESTART_DEFERRED: reason=wifi_active_route context=finalize_backend_switch"
        return 0
    end
    _info "iwd will restart with NetworkManager (D-Bus disconnect expected)"
    if not _run sudo -n systemctl restart NetworkManager
        _warn "NetworkManager restart failed (will recover on reboot)"
        _log "NM_RESTART_FAILED: context=finalize_backend_switch"
    end
    _run sleep $NM_RESTART_DELAY; or _warn "Sleep interrupted during NM restart settle window"
end

function _install_finalize --description "Run post-install verification, cleanup, and summary"
    _progress Finalize
    test "$SDBOOT_REMOVE_EXISTING" = yes; and _if_write_wipe_marker
    not _run sudo -n systemctl daemon-reload; and _warn "Systemctl daemon-reload failed"
    not _run systemctl --user daemon-reload; and _warn "Systemctl --user daemon-reload failed"
    _if_trim_pacman_cache
    _if_nm_restart
    test "$INSTALL_HAD_ERRORS" = true; and return 1
    return 0
end

function _rdi_run_phases --description "Run pkgs/aur/sys/fstab/services phases; bumps INSTALL_HAD_ERRORS on phase failure"
    not _install_packages; and set -g INSTALL_HAD_ERRORS true
    test "$_RY_INSTALL_BAILING" = true; and return 0
    not _install_aur_packages; and set -g INSTALL_HAD_ERRORS true
    test "$_RY_INSTALL_BAILING" = true; and return 0
    set --erase _RY_SKIP_IWD
    command -q updatedb; and begin; _run sudo -n updatedb; or _warn "Updatedb failed"; end
    command -q pkgfile; and begin; _run sudo -n pkgfile --update; or _warn "Pkgfile update failed"; end
    test "$_RY_INSTALL_BAILING" = true; and return 0
    not _install_system_files; and set -g INSTALL_HAD_ERRORS true
    test "$_RY_INSTALL_BAILING" = true; and return 0
    not _install_fstab_opts; and set -g INSTALL_HAD_ERRORS true
    test "$_RY_INSTALL_BAILING" = true; and return 0
    not _install_configure_services; and set -g INSTALL_HAD_ERRORS true
end

function _rdi_summary --argument-names boot_rc --description "Print final install summary; rc echoed unchanged"
    _kill_sudo_keepalive
    _echo
    if test "$INSTALL_HAD_ERRORS" = true
        _echo "INSTALLATION FINISHED WITH WARNINGS"
    else
        _echo "INSTALLATION COMPLETE"
    end
    _echo
    test "$INSTALL_HAD_ERRORS" = true; and _err "Some steps had errors - review log for details"; and _echo
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
end

function _ry_do_install --description "Full installation: preflight, packages, configs, services, boot"
    _log_section "INSTALLATION START"
    _log "VERSION: $VERSION"
    _log "MODE: unattended"
    _echo; _echo "ry-install v$VERSION"; _echo
    _progress_init
    _install_preflight; or return $EXIT_PREFLIGHT
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    _echo
    _rdi_run_phases
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    _install_rebuild_boot
    set -l _boot_rc $status
    test $_boot_rc -ne 0; and set -g INSTALL_HAD_ERRORS true
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
        _err "Boot-critical failure — skipping finalization"
        # lint:ignore (user-facing shell advice)
        _err "Fix boot issue first: sudo mkinitcpio -P && sudo sdboot-manage gen"
        set -g _PROG_FINALIZED_SKIP true
        _progress Finalize skip
    else
        not _install_finalize; and set -g INSTALL_HAD_ERRORS true
    end
    _progress_done
    _rdi_summary $_boot_rc
    _log_section "INSTALLATION END"
    if test "$_boot_rc" -eq $EXIT_BOOT_CRIT
        _log "INSTALL_BAILOUT: boot-critical failure → returning EXIT_BOOT_CRIT"
        return $EXIT_BOOT_CRIT
    end
    test "$INSTALL_HAD_ERRORS" = true; and return $EXIT_FAIL
    return $EXIT_OK
end

set -g _RY_POST_HOOKS "/boot/*|boot" "/etc/mkinitcpio*|boot" "/etc/sdboot-manage*|boot" "/etc/kernel/cmdline|boot" "*.service|service" "*/resolved.conf.d/*|resolved" "*/logind.conf.d/*|logind" "*/iwd/main.conf|nm" "*/NetworkManager/conf.d/*|nm" "*/sysctl.d/*|sysctl" "*/coredump.conf.d/*|coredump" "*/environment.d/*|envd" "/etc/drirc|drirc" "*/fish/conf.d/*.fish|fish"

function _post_hook_for_target --argument-names target --description "Return post-hook tag for a single target path; empty stdout = no match. Single iteration site over \$_RY_POST_HOOKS."
    for _entry in $_RY_POST_HOOKS
        set -l _parts (string split '|' -- $_entry)
        if string match -q "$_parts[1]" -- "$target"
            echo "$_parts[2]"
            return 0
        end
    end
    return 1
end

function _idf_match_dst --argument-names target --description "Match $target against managed destination sets; emit 'true|true' (system+sudo) or 'true|false' (user) or empty"
    for dst in $SYSTEM_DESTINATIONS $SERVICE_DESTINATIONS
        set -l _c (command realpath -m -- "$dst" 2>/dev/null)
        test "$target" = "$dst"; or test "$target" = "$_c"; and echo "true|true"; and return 0
    end
    for dst in $USER_DESTINATIONS
        set -l _c (command realpath -m -- "$dst" 2>/dev/null)
        test "$target" = "$dst"; or test "$target" = "$_c"; and echo "true|false"; and return 0
    end
    echo ""
end

function _idf_dispatch_hook --argument-names target tag --description "Dispatch a single post-hook tag to its _post_* handler; rc=1 on unknown tag"
    set -l _known boot service resolved logind nm sysctl coredump envd drirc fish
    if not contains -- "$tag" $_known
        _err "Internal: unknown post-hook tag '$tag' (target=$target)"
        return 1
    end
    switch $tag
        case boot;     _post_boot "$target"
        case service;  _post_service "$target"
        case resolved; _post_resolved "$target"
        case logind;   _post_logind "$target"
        case nm;       _post_nm "$target"
        case sysctl;   _post_sysctl "$target"
        case coredump; _post_coredump "$target"
        case envd;     _post_envd "$target"
        case drirc;    _post_drirc "$target"
        case fish;     _post_fish "$target"
    end
end

function _ry_do_install_file --argument-names target --description "Install a single named config file"
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
    set -l _resolved (_idf_match_dst "$target")
    if test -z "$_resolved"
        _err "Not a managed file: $target"
        _info "Run without path to see managed files"
        return $EXIT_USAGE
    end
    set -l _use_sudo (string split '|' -- "$_resolved")[2]
    set -l _canon_target (command realpath -m -- "$target" 2>/dev/null; or echo "$target")
    _echo "── ry-install v$VERSION - Install Single File ──"
    if test "$_use_sudo" = true
        _ensure_sudo_cached; or return $EXIT_PREFLIGHT
        test (_post_hook_for_target "$_canon_target") = boot; and _start_sudo_keepalive
    end
    if not _ry_install_file "$target" $_use_sudo
        _err "Failed to install: $target"
        _kill_sudo_keepalive
        _log_section "INSTALL-FILE END"
        return 1
    end
    _echo
    _ok "Installed: $target"
    set -l _hook_rc 0
    set -l _h (_post_hook_for_target "$_canon_target")
    if test -n "$_h"
        _idf_dispatch_hook "$_canon_target" "$_h"
        set _hook_rc $status
    end
    _kill_sudo_keepalive
    _log_section "INSTALL-FILE END"
    return $_hook_rc
end

function _post_boot --argument-names target --description "Post-hook: rebuild boot entries (mkinitcpio + sdboot-manage)"
    _echo
    set -l _rc 0
    set -l _failed_step ""
    if not _run sudo -n mkinitcpio -P
        _err "Mkinitcpio failed"
        set _rc 1
        set _failed_step mkinitcpio
    else if not _run sudo -n sdboot-manage gen
        _err "Sdboot-manage gen failed"
        set _rc 1
        set _failed_step "sdboot-manage gen"
    else if not _run sudo -n sdboot-manage update
        _err "Sdboot-manage update failed"
        set _rc 1
        set _failed_step "sdboot-manage update"
    end
    if test $_rc -ne 0
        # name the failed step in the diagnostic log
        _log "BOOT_REBUILD_FAILED: step='$_failed_step' target=$target"
        _err "CRITICAL: boot rebuild cascade failed at '$_failed_step' — DO NOT REBOOT"
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
    set -l _rc 0
    if string match -q "$HOME/*" -- "$target"
        _run systemctl --user daemon-reload; or _warn "Systemctl --user daemon-reload failed"
        set -l _has_user_bus false
        set -q XDG_RUNTIME_DIR; and test -S "$XDG_RUNTIME_DIR/bus"; and set _has_user_bus true
        set -l _enable_ok false
        if test "$_has_user_bus" = false
            _info "  "(basename -- "$target")": enabling without --now (no active user-bus session — start manually post-login)"
            _run systemctl --user enable -- (basename -- "$target"); and set _enable_ok true
        else if _run systemctl --user enable --now -- (basename -- "$target")
            set _enable_ok true
        end
        if test "$_enable_ok" = true
            if string match -q '*ssh-agent*' -- "$target"; and test "$_has_user_bus" = true
                _run systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"; or _warn "Failed to propagate SSH_AUTH_SOCK to systemd user environment"
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

function _post_resolved --argument-names target --description "Post-hook: restart systemd-resolved"
    _echo
    _run sudo -n systemctl restart systemd-resolved; or _warn "Systemd-resolved restart failed"
    return 0
end

function _post_logind --argument-names target --description "Post-hook: notify reboot needed for logind"
    _info "Logind config $target changed — reboot required (restarting logind kills all sessions)"
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
    _info "environment.d $target changed — log out and back in (or restart user session) to apply"
    _info "  Active systemd --user services retain old environment until restarted"
    return 0
end

function _post_drirc --argument-names target --description "Post-hook: notify Wayland/X restart needed for drirc"
    _info "drirc $target changed — restart Wayland/X session or relaunch affected applications to apply"
    return 0
end

function _post_fish --argument-names target --description "Post-hook: notify shell-restart needed for fish/conf.d/*.fish"
    _info "fish config $target changed — open a new fish shell or run 'source $target' to apply"
    return 0
end

function _pre_dispatch_log_cleanup --description "Remove pre-dispatch log file/dir (no exit; for caller-managed return paths)"
    set -l _preserve false
    set -q _RY_HEADER_WRITTEN; and test "$_RY_HEADER_WRITTEN" = true; and set _preserve true
    set -q _RY_LOG_WRITTEN; and test "$_RY_LOG_WRITTEN" = true; and set _preserve true
    test "$_preserve" = false; and command rm -f -- "$LOG_FILE" 2>/dev/null
    command rmdir -- "$LOG_DIR" 2>/dev/null
    command rmdir -- (dirname -- "$LOG_DIR") 2>/dev/null
    command rmdir -- "$_RY_HOME_DIR" 2>/dev/null
end

function _pre_dispatch_exit --argument-names code --description "Pre-dispatch teardown: log/dir cleanup, then exit"
    _pre_dispatch_log_cleanup
    _ry_exit $code
end

function _early_usage_exit --description "Print usage error to stderr, remove pre-dispatch log, exit EXIT_USAGE"
    echo "[ERR] $argv" >&2
    _pre_dispatch_exit $EXIT_USAGE
end

set -g MODE install
set -l INSTALL_FILE_TARGET ""
set -l _ORIG_ARGV $argv
set -l _ap_errfile (mktemp -t ry-argparse-err.XXXXXX 2>/dev/null)
# mktemp fail → /dev/null only. Never fall back to LOG_FILE.
test -z "$_ap_errfile"; and set _ap_errfile /dev/null
_track_tmpfile "$_ap_errfile"
argparse --name=(basename -- (status filename)) \
    --exclusive=verify-static,verify-runtime,check,install-file \
    h/help v/version V/verbose \
    verify-static verify-runtime check install-file= \
    -- $argv 2>"$_ap_errfile"
set -l _argparse_rc $status
if test $_argparse_rc -ne 0
    set -l _ap_msg ""
    test "$_ap_errfile" != /dev/null; and test -s "$_ap_errfile"; and set _ap_msg (command cat -- "$_ap_errfile" 2>/dev/null | string trim --)
    test -n "$_ap_msg"; or set _ap_msg "Invalid arguments: $_ORIG_ARGV"
    echo "[ERR] $_ap_msg" >&2
    test "$_ap_errfile" != /dev/null; and _rm_tmp "$_ap_errfile" false
    echo >&2
    _ry_show_help >&2
    _pre_dispatch_exit $EXIT_USAGE
end
test "$_ap_errfile" != /dev/null; and _rm_tmp "$_ap_errfile" false
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
if set -q _flag_help
    _ry_show_help
    _pre_dispatch_exit 0
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
if set -q _flag_version
    echo "v$VERSION"
    _pre_dispatch_exit 0
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
# root check after --help/--version
if test (id -u) -eq 0
    echo "[ERR] ry-install must not run as root. Run as your normal user; sudo is invoked internally." >&2
    _pre_dispatch_exit $EXIT_USAGE
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -q _flag_verbose; and set -g QUIET false
set -q _flag_verify_static; and set -g MODE verify-static
set -q _flag_verify_runtime; and set -g MODE verify-runtime
set -q _flag_check; and set -g MODE check
if set -q _flag_install_file
    set -g MODE install-file
    set -l _if_val "$_flag_install_file"
    # explicit empty-check (argparse with `=` accepts empty strings).
    test -z "$_if_val"; and _early_usage_exit "--install-file requires a non-empty absolute path"
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    if not string match -q -- '/*' "$_if_val"
        if string match -q -- '-*' "$_if_val"
            _early_usage_exit "--install-file requires an absolute path argument (got flag: $_if_val)"
        else
            _early_usage_exit "--install-file requires absolute path (got: $_if_val)"
        end
    end
    test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
    set -l _canon (command realpath -m -- "$_if_val" 2>/dev/null)
    if test -n "$_canon"
        set INSTALL_FILE_TARGET "$_canon"
    else
        # route through _warn so the WARN reaches JSONL log.
        _warn "realpath -m failed on '$_if_val' — using literal path; managed-file validation may not match"
        set INSTALL_FILE_TARGET "$_if_val"
    end
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
if test (count $argv) -gt 0
    echo "[ERR] Unexpected positional argument: $argv[1]" >&2
    echo >&2
    _ry_show_help >&2
    _pre_dispatch_exit $EXIT_USAGE
end
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
test "$MODE" != install; and test "$MODE" != check; and set -g QUIET false
_init_runtime
test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
set -l mode_label $MODE
set -l new_log "$LOG_DIR/$mode_label-$TIMESTAMP.jsonl"
set -l old_log "$LOG_FILE"
set -l _log_rename_ok true
if test -f "$old_log"; and test "$old_log" != "$new_log"
    if not command mv -- "$old_log" "$new_log" 2>/dev/null
        set _log_rename_ok false
        _warn "Log rename failed: $old_log -> $new_log (keeping old path)"
    end
end
test "$_log_rename_ok" = true; and set -g LOG_FILE "$new_log"
if not test -f "$LOG_FILE"
    set -l _prev_umask (umask)
    umask 0177
    command install -m 0600 -- /dev/null "$LOG_FILE" 2>/dev/null; or begin
        command touch -- "$LOG_FILE" 2>/dev/null
        command chmod -- 600 "$LOG_FILE" 2>/dev/null; or _warn "Chmod 600 failed on $LOG_FILE"
    end
    umask $_prev_umask
else
    command chmod -- 600 "$LOG_FILE" 2>/dev/null; or true
end
set -l _argv_parts
set -l _argv_in (status filename) $_ORIG_ARGV
set -l _argv_redacted (_redact_argv_elements $_argv_in | string split0)
for _r in $_argv_redacted
    set -a _argv_parts '"'(_json_str "$_r")'"'
end
set -l _argv_json '['(string join ',' $_argv_parts)']'
printf '{"ts":"%s","event":"header","version":"%s","profile":"%s","mode":"%s","verbose":%s,"argv":%s}\n' (date '+%Y-%m-%dT%H:%M:%S%z') "$VERSION" "$PROFILE_NAME" "$MODE" (test "$QUIET" = false; and echo true; or echo false) "$_argv_json" >>"$LOG_FILE" 2>/dev/null
test $status -eq 0; and set -g _RY_HEADER_WRITTEN true
switch $MODE
    case install-file
        if test -z "$INSTALL_FILE_TARGET"
            _err "Usage: ry-install.fish --install-file <path>"
            _echo
            _info "Managed files:"
            for dst in $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS
                _echo "  $dst"
            end
            _pre_dispatch_exit $EXIT_USAGE
        end
        test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT
        _acquire_lock; or begin
            _ry_exit $EXIT_LOCK
        end
    case install
        _acquire_lock; or begin
            _ry_exit $EXIT_LOCK
        end
    case '*'
end
if test "$_RY_INSTALL_BAILING" = true
    _write_footer "$_RY_INSTALL_LAST_EXIT" interrupted
    test "$_RY_INSTALL_SOURCED" = true; and _ry_namespace_cleanup bail
    return $_RY_INSTALL_LAST_EXIT
end
# derive from LOG_DIR rather than hardcoded HOME path
set -l _log_base_rot (dirname -- "$LOG_DIR")
set -l _rot_rows (command find "$_log_base_rot" -maxdepth 2 \( -name '*.jsonl' -o -name '*.log' \) -type f -not -samefile "$LOG_FILE" -printf '%T@\t%p\0' 2>/dev/null | LC_ALL=C sort -zn | string split0)
set -l _rot_ps $pipestatus
set -l _rot_pipe_ok true
for _rps in $_rot_ps
    test "$_rps" = 0; or set _rot_pipe_ok false
end
set -l _rot_count (count $_rot_rows)
if test "$_rot_pipe_ok" = false
    _log "LOG_ROTATION_SKIP: pipestatus="(string join ',' -- $_rot_ps)
else if test $_rot_count -gt $MAX_LOGS
    set -l _drop_to (math $_rot_count - $MAX_LOGS)
    for _row in $_rot_rows[1..$_drop_to]
        set -l _path (string split -m 1 \t -- "$_row")[2]
        test -n "$_path"; and command rm -f -- "$_path" 2>/dev/null
    end
end
command find "$_log_base_rot" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
set -g _RY_EXIT_CODE 0
switch $MODE
    case verify-static
        _ry_verify_static
        set _RY_EXIT_CODE $status
    case verify-runtime
        _ry_verify_runtime
        set _RY_EXIT_CODE $status
    case check
        _ry_do_check
        set _RY_EXIT_CODE $status
    case install-file
        _ry_do_install_file "$INSTALL_FILE_TARGET"
        set _RY_EXIT_CODE $status
    case install
        _ry_do_install
        set _RY_EXIT_CODE $status
    case '*'
        _err "Unknown mode: $MODE"
        set _RY_EXIT_CODE $EXIT_USAGE
end
if test "$_RY_INSTALL_BAILING" = true
    set -g _RY_INSTALL_LAST_EXIT $_RY_EXIT_CODE
    test "$_RY_INSTALL_SOURCED" = true; and _ry_namespace_cleanup bail
    return $_RY_EXIT_CODE
end
set -g _INTENDED_EXIT_CODE $_RY_EXIT_CODE
_write_footer "$_RY_EXIT_CODE" ""
set -q _RY_LOG_WRITE_FAIL; and test "$_RY_LOG_WRITE_FAIL" = true; and echo "[WARN] Log writes failed during this run — JSONL may be incomplete (check disk space / file permissions on $LOG_FILE)" >&2
test "$MODE" != check; and echo "[i] Log file: $LOG_FILE" >&2
if test "$_RY_INSTALL_SOURCED" = true
    set -g _RY_INSTALL_LAST_EXIT $_RY_EXIT_CODE
    _do_cleanup
    _ry_erase_handlers
    _ry_namespace_cleanup
    return $_RY_EXIT_CODE
end
exit $_RY_EXIT_CODE
