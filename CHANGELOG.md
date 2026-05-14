ry-install ChangeLog
====================

v6.5.3 - 2026-05-14
-------------------

  * dispatch: bundled help/version short flags no longer fall through
    to a full install. The early-exit option loop near the top of the
    script matches only exact tokens (`-h`, `--help`, `-v`,
    `--version`) via `switch`, so a bundled form such as `-hV` or
    `-hv` skipped it, reached `argparse`, and set `_flag_help` /
    `_flag_version` — but nothing after `argparse` read those flags,
    so `MODE` stayed `install` and the script ran an unattended
    install. `_flag_help` and `_flag_version` are now handled in the
    post-argparse block: `--help` prints usage and exits 0,
    `--version` prints the version and exits 0. The early-exit loop is
    kept as the fast path for exact tokens (it touches no filesystem
    state). The comment at the `argparse` call is updated to match.

  * dispatch: the v6.5.2 entry below states that `argparse` rejects an
    empty `--install-file=` value before the mode switch. It does not
    — `argparse` accepts an empty `=` value and sets the flag to an
    empty string. The empty-value rejection is the
    `test -z "$_if_val"` guard in the post-argparse `_flag_install_file`
    block, which is retained. The v6.5.2 removal of the *duplicate*
    guard from the `case install-file` dispatch arm remains correct —
    that guard was genuinely redundant. No code change for this item.

  * _ry_mkinitcpio_array, _verify_static_syntax: the three `grep`
    invocations that read `/etc/mkinitcpio.conf` (the `KEY=` line
    parse, and the `HOOKS=` line parse with its `grep -v '^#'` filter)
    now pass `--` before the pattern, matching the end-of-options
    convention applied to every other `grep` / `rm` / `mv` call in the
    file. The file argument is a constant and the patterns are
    `^`-anchored, so this is a consistency normalization, not a fix
    for an observed failure.

  * _vrsv_wifi, _is_wifi_active_route: the two `basename` calls (both
    fed the output of `dirname -- ...`) now pass `--`. Input is always
    an absolute `/sys/class/net/...` path, so this is defense-in-depth
    for the end-of-options convention, not a fix for an observed
    failure.

  * preflight/TMPDIR: a `TMPDIR` that is set but not an absolute path
    now falls back to `/tmp` (with a `[WARN]`) before the writability
    probe. A relative or dash-prefixed `TMPDIR` would otherwise reach
    the `find "$TMPDIR" ...` cleanup-sweep calls, where `find` parses
    a dash-prefixed argument as an expression rather than a path. The
    existing set-but-non-writable fallback is unchanged.

  * Net effect: 4991 -> 5003 lines. No functional change to the
    install / verify / check flows beyond the help/version dispatch
    fix.

  * README: version badge -> 6.5.3; removed a stale reference to
    `~/ry-install/.boot-wipe-acknowledged` (the boot-wipe marker was
    removed in v6.5.1); the "Other" Known Issues sub-section, the
    Managed Files "Destinations" sub-section, and the "Data directory
    & logs" sub-section converted from prose lists to tables for
    consistency with the other collapsible sections. Added a Contents
    section linking every top-level heading. Trimmed the Prerequisites
    fstab paragraph and the Hardware notice to vital information.
    Removed the metadata parentheticals (param counts, the
    environment.d path, `gfx1151`) from the collapsible summary labels
    — the `Kernel cmdline` body now states that `rw` and `root=UUID=`
    are appended implicitly.

v6.5.2 - 2026-05-14
-------------------

  * Script header: the version string in the line-2 header comment
    was still `v6.5` — it had not been bumped alongside the `VERSION`
    global and the README badge in the v6.5.1 release. Header,
    `VERSION`, and README badge now all read 6.5.2.

  * sha256sum: the three bare `sha256sum` invocations
    (`_verify_static_checksum` expected/actual content-hash compare,
    `_enum_boot_entries` entry-set hash) now use the `command
    sha256sum` form, matching the coreutils-invocation convention
    already applied to every other required coreutils binary in the
    file. No behavior change — `sha256sum` is in the required-command
    list and unconditionally present.

  * dispatch: the post-argparse `case install-file` arm carried an
    unreachable `test -z "$INSTALL_FILE_TARGET"` usage guard.
    `argparse` rejects an empty `--install-file=` value (and a
    missing value) before the mode switch is reached, so
    `INSTALL_FILE_TARGET` is always non-empty at that point. The dead
    guard is removed and `case install-file` / `case install` are
    merged — both did nothing but acquire the instance lock. The
    defensive empty-target guard inside `_ry_do_install_file` itself
    is retained.

  * _install_preflight: the four uniform
    `<check>; or begin; set -g _PROG_FINALIZED_SKIP true;
    return $EXIT_PREFLIGHT; end` blocks (`_ensure_sudo_cached`,
    `_ip_probe_sudo_policy`, `_ry_check_deps`, `_ry_check_disk_space`)
    collapsed into a single `for` loop over the check names. Check
    order, the progress-bar skip sentinel, and the `EXIT_PREFLIGHT`
    return are unchanged; `_ry_check_network`,
    `_ry_check_kernel_version`, and `_ry_validate_configs` keep their
    bespoke handling.

  * _resolve_esp / _resolve_boot_path: the shared `bootctl -p` /
    `bootctl -x` probe (user invocation, sudo fallback, pipestatus
    check, fall-through log marker) factored into a `_bootctl_dir`
    helper taking the flag, log tag, and fall-through note. Both
    resolvers call it with their respective arguments; resolution
    order, the `_RY_ESP_TRIED` / `_RY_BOOT_TRIED` caching sentinels,
    and `/boot` fallback behavior are unchanged.

  * Net effect: 5023 -> 4991 lines. No functional change to the
    install / verify / check flows beyond the corrected header
    version string.

  * README: version badge -> 6.5.2.

v6.5.1 - 2026-05-14
-------------------

  * _resolve_esp / _resolve_boot_path: a hard-fail (bootctl and
    findmnt both unable to resolve a path, /boot absent) cached an
    empty string into _RY_ESP_PATH / _RY_BOOT_PATH. The cache guard
    was `set -q VAR; and test -n "$VAR"`, so an empty cached value
    read as "not cached" and every subsequent call re-ran the full
    autodetect — re-emitting the `ESP autodetect failed` warning and
    re-probing sudo on each invocation. Resolution is now gated on
    dedicated `_RY_ESP_TRIED` / `_RY_BOOT_TRIED` sentinels (mirroring
    _resolve_systemd_ver), so an unresolved path is cached and warned
    about exactly once. Both sentinels are cleared in
    _dc_erase_globals alongside the existing cache vars.

  * _run_emit_stream: the captured-stream line total came from
    `wc -l`, which counts newlines and therefore undercounts by one
    when a command's stdout/stderr ends without a trailing newline.
    That could suppress the `*_TRUNCATED` JSONL marker even when the
    output was actually clipped at the 500-line cap. The count now
    adds one when the file's last byte is not a newline.

  * _vre_zram: the ZRAM service check hard-coded
    `systemd-zram-setup@zram0.service`; a zram swap device with any
    other instance name produced a false `ZRAM service: not found`.
    The instance name is now derived from the live `swapon` device,
    falling back to `zram0` only when no zram swap is active.

  * _post_service: removed an unreachable `$HOME/*` user-unit branch.
    SERVICE_DESTINATIONS contains only a system path, so the branch
    was dead code; the function now handles the system path directly.

  * _csm_retry_individual: dropped a redundant per-unit re-filter.
    Its only caller passes a list already filtered by
    _csm_filter_units (masked / not-installed units removed), so the
    second pass could never skip anything, and re-masking an
    already-masked unit is idempotent.

  * _cleanup_other: removed a redundant `_CLEANUP_DONE` guard already
    enforced as the first statement of _cleanup.

  * Removed the vestigial boot-wipe marker: BOOT_WIPE_MARKER, the
    _if_write_wipe_marker function, its two call sites, and the
    write-only _RY_BOOT_REBUILD_OK flag. The marker file
    (~/ry-install/.boot-wipe-acknowledged) was written after a
    successful entry rebuild but never read by any code path — no
    behavior depended on it.

  * README: documented that the ext4 fstab rewrite drops the
    `defaults` token and normalizes atime/commit options. Mount
    semantics are unchanged; only the literal fstab text differs.

  * Net effect: 5087 -> 5023 lines. No functional change to the
    install / verify / check flows beyond the fixes above.

  * README: version badge -> 6.5.1.

v6.5 - 2026-05-14
-----------------

  * _dc_sweep_tmpfiles: the post-`rm` `TMPFILE_STUCK` log no longer
    fires on a *successful* sudo removal. The branches were written
    `sudo -n rm … 2>/dev/null; or functions -q _log; and _log …`,
    which fish parses as `(rm or functions-q) and _log`: when `rm`
    succeeded the `or` clause was satisfied, the chain status stayed
    success, and the trailing `and _log` ran regardless — emitting a
    spurious `TMPFILE_STUCK: <path> (sudo rm -rf failed)` /
    `(sudo rm -f failed)` JSONL event for a path that was in fact
    removed cleanly, and obscuring genuinely stuck paths. Both
    branches now wrap the log call in an explicit `or begin … end`
    block so it is reached only on real removal failure. The
    user-mode passes and the `no sudo or outside escalation paths`
    branch were already correct and are unchanged.
  * _verify_static_services: the `scaling_governor` ExecStart probe
    no longer aborts when `systemctl cat cpupower-epp.service`
    returns more than one `ExecStart=` line. `string match -rg`
    yields one list element per match, so a unit carrying a drop-in
    (or any second `ExecStart=`) made `_execstart` a multi-element
    list and `test -n "$_execstart"` failed with "too many
    arguments". The guard is now `test (count $_execstart) -gt 0`
    and the `string match` runs against the unquoted list, so every
    ExecStart line is inspected. The shipped unit has a single
    ExecStart, so observable output is unchanged for a clean install.
  * head/tail: fourteen `head`/`tail` call sites that piped without
    the `command` prefix now use `command head` / `command tail`,
    matching the coreutils-invocation convention used elsewhere in
    the file. Both are already in the required-command list, so this
    is a consistency normalization, not a behavior change. Affected:
    _resolve_systemd_ver, _verify_unit_syntax, _check_avail,
    _verify_static_syntax, _vrkg_rebar_sam, _verify_runtime_kparams,
    _vre_zram, _vrs_boot_perf, _fstab_atomic_replace.
  * _json_str: dropped the `00` entry from the control-character
    escape loop. `(printf '\x00')` collapses to an empty needle in
    fish command substitution (NUL cannot occur inside a fish
    string), so `string replace -a` over it was an unreachable
    no-op; the U+0000..U+001F range is fully covered by the
    remaining entries plus the dedicated `\n \r \t \b \f` replaces.
  * comments: the two-line `_run_emit_stream` QUIET-stderr rationale
    and the two-line `_ry_do_install` discarded-return-code note
    each collapsed to a single line. A one-line note was added at
    the `argparse` call recording that `h/help` and `v/version` are
    serviced by the early-exit option loop and are declared on
    `argparse` only so an unknown-option error is not raised.
  * README: version badge -> 6.5.

v6.4 - 2026-05-14
-----------------

  * _vsb_entries: a lapsed sudo credential or an unresolved `$BOOT`
    path no longer produces a spurious `Boot entries: NONE` FAIL.
    Previously, when `sudo -n test -d "$BOOT/loader/entries"` returned
    non-zero (sudo timestamp expired) the enumeration block was
    skipped, leaving `entry_count` at 0 and `_entries_pipe_ok` at its
    initialized `true`, so control fell through to the `NONE` FAIL
    branch — indistinguishable from a genuinely empty entries
    directory. The function now: returns early with a WARN when
    `_resolve_boot_path` yields an empty string; probes `sudo -n true`
    and WARNs on a lapsed credential instead of reporting NONE; and
    distinguishes a missing `loader/entries` directory from a present
    but empty one. The genuine-empty path still FAILs.
  * _ry_check_deps: the required-command loop now also checks `tee`,
    `stat`, `find`, `cp`, `chmod`, `chown`, `sort`, `install`, `cat`,
    and `rm`. All ten are used on critical paths (`tee` in the
    atomic-write and fstab-rewrite render pipes, `stat` in permission
    and size verification, `sort` in boot-entry enumeration, the
    rest throughout). They are coreutils and effectively always
    present, but the contract is "verify required packages are
    installed" and the list was incomplete.
  * _ry_check_deps: systemd major-version detection now calls
    `_resolve_systemd_ver` and reads the cached `_RY_SYSTEMD_VER`
    global instead of re-parsing `systemctl --version` inline. The
    parse logic was duplicated verbatim between the two functions.
  * _progress_init: the pinned scroll-region progress bar is now
    skipped when `_RY_NO_COLOR` is true. `TERM=dumb` already sets
    that sentinel during early init; the bar's DECSTBM/cursor-save
    escape sequences are inappropriate for a dumb terminal. Other
    suppression gates (tmux/screen/mosh, non-tty, missing `tput`)
    are unchanged.
  * _install_configure_services: removed the dead `; or set _ret 1`
    clauses on the `_configure_services_resolved_restart` and
    `_configure_services_pkg_remove` calls. Both functions
    unconditionally `return 0`, so the clauses could never fire. The
    `_configure_services_mask` and `_configure_services_enable`
    clauses are retained — those functions do propagate failure.
  * _check_avail, _enum_boot_entries: `LC_ALL=C` invocations
    normalized to the `env LC_ALL=C` prefix form used elsewhere in
    the file (`_vrkm_blacklist`, `_ip_probe_sudo_policy`). Inline
    `VAR=val cmd` is fish-valid; this is a style normalization only.
  * _run_emit_stream: added an inline comment documenting that the
    `QUIET=true` + `STDERR` + non-zero-rc branch deliberately
    surfaces up to five stderr lines, so package/bootloader failures
    are visible without `--verbose`.
  * _ry_do_install: added an inline comment noting that
    `_rdi_run_phases`'s return code is intentionally discarded —
    phase-failure state is carried in the `INSTALL_HAD_ERRORS`
    global and checked at function end.
  * _ip_pacman_invoke, _csp_remove_pkgs: the `db.lck` pre-check
    error message now states the lock may be either a live pacman
    process or a stale lock from a crashed run, rather than implying
    it is always an active lock.
  * README: version badge → 6.4; new Troubleshooting row for the
    expected `logind.conf.d` checksum MISMATCH when systemd crosses
    the 255↔256 boundary between install and `--verify-static`
    (`HandleSecureAttentionKey` is version-gated in both the content
    generator and the verifier, so the on-disk file legitimately
    diverges from the regenerated content after a systemd major
    upgrade).

v6.3 - 2026-05-14
-----------------

  * _dc_sweep_tmpfiles: tracked tmpfiles that survive both the user-mode
    `rm` pass and the sudo-escalated `rm` pass are now logged as
    `TMPFILE_STUCK: <path> (<reason>)` JSONL events before
    `_TRACKED_TMPFILES` is erased. Reasons are differentiated:
    `sudo rm -rf failed` / `sudo rm -f failed` / `no sudo or outside
    escalation paths`. Previously, files outside `/etc /boot /efi /var`
    or files surviving the sudo `rm` were dropped without trace,
    leaving operators no record of which paths the next install would
    inherit.
  * dispatch/header: JSONL `event=header` write at top-level now sets
    `_RY_LOG_WRITE_FAIL` on failure, so the closing `[WARN] Log writes
    failed during this run` notice fires consistently. Previously the
    sentinel was only updated by `_log` body writes and footer; a
    header-only write failure (rare, but possible if `LOG_FILE` filled
    the partition between creation and first write) ran silently.
  * _err_loud: emission body deduplicated. The function used to carry
    a verbatim copy of `_msg_print`'s color/tty branch; it now calls
    `_msg_print --force ERR $argv`. The new sentinel `--force` (first
    positional, consumed before `level`) bypasses the `QUIET=true`
    short-circuit while preserving the existing `_RY_OUTPUT_BROKEN` and
    `_RY_NO_COLOR` gates. No emitted-output change for any caller.
  * _ok, _fail, _fail_silent, _info, _warn, _err: collapsed from
    three-line definitions to one-line definitions
    (`function X; _msg LEVEL $argv; end`). `--description` strings
    removed from these six wrappers and from all twelve `_content__*`
    embedded-content generators; the function names are
    self-documenting and `functions --details` still resolves the
    bodies. No behavior change.
  * _is_wifi_active_route: `ip -4` and `ip -6` invocations collapsed
    into a `for _af in -4 -6` loop. The two `awk` invocations were
    byte-identical except for the protocol flag.
  * _ry_check_network: `curl` retries against `archlinux.org` and
    `cloudflare.com` collapsed into a `for _host in ...` loop with an
    index counter for the "primary"/"fallback host" `_ok` message
    differentiation. Wire-level behavior (per-host timeouts,
    connect-timeout, max-time, raw-IP ICMP fallback) unchanged.
  * _vrsv_chk_nm_dispatcher: `static` is now accepted as a valid
    UnitFileState alongside `enabled`. NetworkManager-dispatcher.service
    ships with `WantedBy=` empty and is normally `static`;
    `systemctl is-enabled` returns `static` for the shipped unit.
    Previously, runtime verification reported a spurious FAIL on a
    clean install where the unit had not been explicitly `enable`'d.
  * _msg_print: leading positional `--force` consumed as a sentinel
    that bypasses the `QUIET=true` early-return. Existing call sites
    pass `level` as `$argv[1]` unchanged; only `_err_loud` uses the
    new path.
  * _tmpfile_key: `set p HOME(string sub ...)` concatenation rewritten
    as `set -l _rest (string sub ...); set p "HOME$_rest"`. fish-valid
    juxtaposition concatenation worked, but read as a typo on cursory
    review. Output is byte-identical for every destination key.
  * _run: argument validation rewritten from `test ...; and _log ...;
    and return 255` semicolon-and chains into explicit `if` blocks.
    The chain relied on `_log` returning 0 on every path (it does), so
    behavior is unchanged; the rewrite removes a latent fragility
    where a future `_log` change could break the `return 255`.
  * _vre_thp_ksm: `set -l _active (string match -r ...)[2]` rewritten
    as `set -l _m (string match ...); set -l _active $_m[2]`. Indexing
    a command substitution inline is fish-valid; the two-step form
    matches the convention used elsewhere in the file.
  * _json_str: description updated to "RFC 8259 mandatory + DEL". The
    escape table is mandatory characters (U+0000..U+001F, `"`, `\`)
    plus U+007F (DEL); 8259 does not mandate DEL escaping but does not
    forbid it. The description now matches the implementation.
  * README: reference tables (Prerequisites, Safety & Reliability,
    Runtime variables, Troubleshooting, and the collapsible
    Configuration tables) trimmed to vital fields. Long prose cells
    moved to the surrounding paragraph text or dropped; no documented
    behavior removed.

v6.2.13 - 2026-05-14
--------------------

  * _run: function split into _run, _run_redact_cmd, and
    _run_effective_timeout. Tmpdir-path redaction of the logged command
    and timeout resolution / bypass selection are now self-contained
    helpers. Wire-level behaviour (logged RUN string, TIMEOUT_BYPASS
    marker, timeout invocation, exit-code propagation) unchanged.
  * _content__etc_systemd_system_cpupower-epp.service: the `$$cpu`
    rationale (systemd.service(5) unescapes `$$`→`$`) collapsed from
    five comment lines to one. No code change.

v6.2.12 - 2026-05-14
--------------------

  * _ry_install_file, _verify_static_checksum, _check_phase_files:
    content equality test fixed for files whose embedded vs installed
    bytes differ only by `<space>` vs `<newline>` token boundaries.
    `set -l x (cmd)` splits stdout on newlines into a fish array;
    `test "$x" = "$y"` then joins quoted-array elements with single
    spaces, so `"a b\nc\n"` and `"a\nb c\n"` compared EQUAL. Three
    callsites now pipe through `string collect --no-trim-newlines
    --allow-empty` to preserve newline positions in a single-element
    scalar comparison. Function return codes are recovered from
    `$pipestatus[1]` (was: `$status`, which would have reflected
    `string collect`'s rc rather than the content generator's).
    Affects: idempotency skip in install path, sha256 mismatch
    detection in --verify-static, drift detection in --check.
  * _run_emit_stream: STDERR/STDOUT line replay uses `printf '%s\n'
    "$_l"` instead of `echo $_l`. Fish builtin `echo` consumes bare
    `-n`, `-e`, `-E`, and `-{n,e,E}` combinations as flags when the
    arg matches exactly. Captured pacman/awk/sudo output containing
    a line equal to (e.g.) `-n` was previously suppressed entirely.
    `--noconfirm`, `-Sy`, etc. were never affected (flag-set is
    strict).
  * _echo: same flag-injection class — `echo "$argv"` replaced with
    `printf '%s\n' (string join ' ' -- $argv)`. Empty-argv preserves
    the prior "empty line on stderr" behavior.
  * _csm_filter_units, _csp_filter_rdeps: capture-pipe emits switched
    from `echo "$pkg"` / `echo "$_unit"` to `printf '%s\n'`. Package
    names cannot begin with `-` per Arch packaging spec and systemd
    unit names cannot either, so the change is defense-in-depth, not
    a fix for an observed failure mode.
  * _write_footer: `$extra_key` is now passed through `_json_str`
    before concatenation into the JSONL footer. All current callers
    (`interrupted`, `cleanup_exit`, empty) are JSON-safe literals;
    the change closes the contract gap for future callers.
  * _verify_static_syntax: `string trim --` added between the
    whitespace-collapse `string replace -ra '\s+' ' '` and the
    `string split ' '` of HOOKS=. Eliminates leading/trailing empty
    array elements when /etc/mkinitcpio.conf had surrounding
    whitespace inside the HOOKS=( ... ) parens. Downstream
    `_vmh_existence_only` already skipped empty hooks, so behavior
    is unchanged; the change removes a sharp edge.
  * _progress_init: pinned-progress-bar terminal probe now also
    bails when `$ZELLIJ` is set. Zellij does not advertise itself
    via `$TERM` (xterm-256color); scroll-region escape sequences
    leak into the pane background otherwise.
  * _content__etc_systemd_system_cpupower-epp.service: inline
    comment added explaining why `$$cpu` is intentional. systemd
    unescapes `$$`→`$` in ExecStart per systemd.service(5); bash
    receives `$cpu`. The previous unannotated `$$cpu` looked like a
    typo on cursory review.

v6.2.11 - 2026-05-14
--------------------

  * _csp_filter_rdeps: pipestatus gate narrowed from `_pipe_all_ok $_ps`
    back to `test $_ps[1] -ne 0`. The widened check (introduced v6.2.8)
    treated `string replace -r` and `string match -rv` non-match returns
    (rc=1) as pipeline failure, causing PKGS_DEL members with no rdeps
    or no version operators to be silently skipped on every system with
    pacman-contrib installed. Only the first stage (timeout/pactree)
    represents a real probe failure.
  * dispatch/header: JSONL `event=header` line written before
    `_init_runtime` so preflight failures inside `_ir_resolve_root_uuid`
    et al. preserve a parseable log (was: log content without header).
  * dispatch/log-create: lazy creation in `_log` covers the common
    path; top-level eager creation removed. Closes the signal window
    between log-file creation (formerly ~line 169) and signal-handler
    install (line 469). Failure to set mode 0600 on the fallback
    `touch`+`chmod` path now hard-fails preflight instead of warn-only.
  * dispatch/root-check: refusal-to-run-as-root hoisted from
    post-argparse to immediately after UID parse. Root no longer hits
    the HOME-normalisation gate first with a misleading error.
  * lock/perms: `LOCK_DIR` chmod 700 applied immediately after mkdir
    (was: inherits umask; ~/ry-install 0700 made this academic).
  * lock/cleanup: `_RY_LOCK_DIR_OWNED` sentinel set immediately after
    mkdir success so signal-driven cleanup removes the lock dir even
    when the script is killed mid-`mktemp`/`mv`.
  * _verify_unit_syntax: `--argument-names unit_path label intended_scope`
    declaration replaces positional `$argv[1..3]` reads. Matches the
    convention used by every other helper in the file.
  * _post_resolved, _post_sysctl: `--argument-names target` added for
    dispatch-table parity with the other six `_post_*` handlers.
  * _early_usage_exit: also prints `_ry_show_help` to stderr, matching
    the argparse-failure path. `--install-file=foo` and friends now
    show help, not just an `[ERR]` line.
  * _run/timeout-bypass: `updatedb` and `pkgfile --update` added to
    the bypass list. Slow filesystems were hitting the 1h cap during
    post-install DB rebuilds with no rollback to recover.
  * preflight/TMPDIR: probe adds `test -d "$TMPDIR"` so a set-but-
    invalid `TMPDIR` falls back to `/tmp` cleanly.
  * preflight/HOME: getent-passwd pipeline gains `head -n 1` so
    nsswitch chains returning multiple matches don't concatenate
    field-6 values into a malformed path.
  * _vrs_boot_perf: `systemd-analyze` parse anchors on the `= Xs Total`
    match (last `= Xs` token) and tightens the format probe regex.
  * _vsc_static_checksum: log marker rewords `expected_sha`/`actual_sha`
    to `expected_content_sha`/`actual_content_sha` — these are SHA256
    of the trimmed content used for comparison parity, not of the raw
    on-disk file.
  * _cse_collect_units: loop emitting one unit per `echo` replaced with
    a single `printf '%s\n' $_enable` after the loop.
  * _dc_erase_globals: adds `_RY_HOLDS_LOCK`, `_RY_LOCK_DIR_OWNED` to
    the erase list.
  * style: drop dead global `_RY_TIMEOUT_OK` (set once at preflight,
    never read).

v6.2.10 - 2026-05-14
--------------------

  * _ry_check_deps: `grep` added to required-cmds list (used in
    9 sites: chk_grep, mkinitcpio array parse, sdboot LINUX_OPTIONS
    extract, pacman.conf inspect, mkinitcpio hooks-line parse,
    NM-perms branch, BLS loader-entry probe, blacklist scan).
  * _verify_static_packages: capture `pacman -Qq` exit status; on
    failure (db lock, read error) skip per-pkg verification with a
    single warn instead of false-flagging every PKGS_ADD entry as
    NOT INSTALLED against an empty installed-list.
  * _ip_run_and_verify: capture `pacman -T` status; treat rc not in
    {0, 127} as verification failure (db lock, permission). Was:
    empty stdout + non-zero rc silently reported "All packages
    verified installed".
  * _csp_remove_pkgs/retry: check `pacman -Qq` rc on the per-pkg
    retry list; abort retry with a warn instead of running
    `pacman -R` against a stale/empty pkg set.
  * _idf_match_dst: return single token (`true`/`false`) instead of
    `true|true`/`true|false`. `_ry_do_install_file` reads it
    directly; no split needed.
  * _content/_vss_logind: `HandleSecureAttentionKey` skip on
    systemd<256 rewritten as explicit `if`-block (was relying on
    `test … ; or test … ; and continue` precedence).
  * _vsb_mkinitcpio: `COMPRESSION_OPTIONS` match now per-token,
    order-independent. Was substring match — reordered
    `(-T0 -1)` reported MISSING.
  * _verify_runtime_kparams: dmesg slice extractions (preempt-line,
    BAR-line, TSC-line) precomputed once into globals instead of
    three full re-scans of the 5000-line cache.
  * _pb_rebuild_cascade: dropped dead `_failed_step` local; step
    label inlined in `_log` calls.
  * _resolve_systemd_ver and 26 other `--description` strings
    trimmed to leading clause; parenthetical detail dropped where
    it duplicated the function body.
  * _msg_print: color switch hoisted out of the `begin … end` block
    so the colored stderr write is a straight-line sequence.
  * _dc_erase_globals: 25 single-name `set --erase` lines collapsed
    into 8 grouped lines (fish accepts multiple names per call).
  * top-level: EXIT_* constants grouped (3 lines vs 10) and counter
    inits in `_ry_verify_static`/`_ry_verify_runtime` joined.
  * boot-time: `-lt` → `-le` so an exact-target boot-time
    (e.g. 15.0s against `BOOT_TIME_TARGET=15`) reports "within".
  * dispatch: `QUIET` toggle simplified from nested `begin` blocks
    to single conjunction.
  * style: dedupe two-call `string split` patterns in `_vsb_sdboot`,
    `_vrs_parent_dirs`, `_vrkm_amdgpu`; drop no-op `printf '%s\n'`
    around already-split capture in `_ip_probe_sudo_policy`; drop
    `string split -n` for fixed-format stat output; mkinitcpio
    snapshot tmpfile prefix unified to `.ry-install.mki-snap`;
    `string match -r | tail -n 1` → `string match -rg`; nmcli
    `grep | head | cut` → `string match -rg` capture.
  * script: 5054 → ~5008 LOC; 214241 → ~212200 B (~−2 KB).

v6.2.9 - 2026-05-13
-------------------

  * HOME fallback: getent-passwd field-6 extraction uses
    `awk -F: '{print $6}'` instead of `string split -m6 ':' …[6]`.
    Robust to passwd entries with `:` in GECOS.
  * _atomic_write_file: removed unused `_expected_uid` local.
  * _ry_check_deps: `mv` added to required-cmds (boot-lock install
    and boot-wipe marker both depend on GNU `mv -T`).
  * comments: collapsed verbose `--description` strings to single
    leading clause; ~3.5 KB shaved.

v6.2.8 - 2026-05-13
-------------------

  * dispatch/log-filename: log rename (`preflight-*.jsonl` →
    `<mode>-*.jsonl`) now happens before `_init_runtime`.
  * dispatch/lock-ordering: `_acquire_lock` runs before JSONL
    header write — no orphan log on lock contention.
  * _install_preflight: every early-return sets
    `_PROG_FINALIZED_SKIP=true` so the progress bar renders
    aborted instead of "1/6 Done".
  * _msg/_msg_nocount: empty-message short-circuit hoisted from
    `_msg_print` into the callers; `_log` call also skipped.
  * _dc_erase_globals: also erases `_RY_PACTREE_MISSING_WARNED`
    and `_RY_RUN_TIMEOUT_WARNED` for symmetry.
  * _csp_filter_rdeps: pipestatus gate widened from `_ps[1]` to
    `_pipe_all_ok $_ps`.
  * _csp_remove_pkgs: batch-removal success emits visible
    `_ok "Removed: $argv"`.
  * _progress_init: TTY-feature probe replaced `tput cup 0 0` with
    read-only `tput cols` (no cursor side effect).
  * _ry_do_install: dropped dead `$_boot_rc` argument to
    `_rdi_summary`.

v6.2.7 - 2026-05-13
-------------------

  * perms/user-files: user destinations deploy 0600 (was 0644).
  * _as/sentinel: BUG rc 2 → 250 for non-bool `use_sudo`
    (avoid colliding with downstream tee/sudo exit-2 paths).
  * _run/sudo-bypass: effective-cmd detection scans past dash-flags
    after `sudo` instead of hard-indexing `$argv[3]`.
  * _run/abort: distinct rc=251 for tmpdir-alloc failure.
  * _run_emit_stream: stdout label `OUTPUT` → `STDOUT`.
  * _ry_check_deps: optional-tool absences batched into one warn.
  * _vmh_order_checks: hoist `string split ':'` to one call/iter.
  * _far_awk_rewrite: capture awk stderr to its own tmpfile.
  * _is_system_dst: drop `/root/*` from system-path allowlist.
  * _dc_sweep_filesystem: `find -xdev` added.
  * _install_aur_packages: rewrote `not set -q … or …; and return`
    chain as explicit `if`.
  * _post_service: hoist basename; user-bus daemon-reload gated by
    `_has_user_bus_active`.
  * _if_trim_pacman_cache, _if_nm_restart: explicit `return 0`.
  * 9 sites: bare `return` → `return 0`.
  * cat: drop `--` end-of-options on lock-file reads.
  * HOME-parse: `string split -m6 ':'` for GECOS `:` tolerance.
  * set/erase: replace `set -e` with `set --erase`.
  * dispatch: removed two unreachable `_RY_INSTALL_BAILING` checks.
  * argv-log: dropped dead `_argv_for_log` intermediate.
  * sourcing-guard: simplified `return 1 2>/dev/null; or exit 1`
    to direct `exit 1`.

v6.2.6 - 2026-05-13
-------------------

  * data-tables/wrap: top-level array decls wrap one element per
    continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * preflight/boot-files: `_pbs_check_boot_files` snapshots
    `$pipestatus` into `_ps` before `_pipe_all_ok` for refactor
    robustness.
  * mkinitcpio/array-parse: dropped dead `functions -q _warn`
    guard inside `_ry_mkinitcpio_array`.
  * output/separators: collapsed ~52 standalone `_echo` blank-line
    separators in verification + install routines.

v6.2.4 - 2026-05-13
-------------------

  * run/timeout: `_run` bypasses `RY_RUN_TIMEOUT` for `pacman`,
    `paru`, `mkinitcpio`, `sdboot-manage`, `paccache` (SIGKILL
    would skip rollback). Emits `TIMEOUT_BYPASS` log marker.
  * _run/log-prefix: tmpfile paths under `$TMPDIR` redacted in
    addition to `/tmp/`.
  * timeout/probe: `command timeout` invocation refuses to run if
    `timeout(1)` absent (was a soft warn).
  * _run_emit_stream: log first 500 lines per stream (was 100);
    new `STDERR_TRUNCATED`/`STDOUT_TRUNCATED` sentinels.
  * _msg/levels: `_err_loud` always emits regardless of QUIET;
    used at preflight bail-points.
  * _vsb_sdboot: only extract LINUX_OPTIONS when quote-count == 2.

v6.2.3 - 2026-05-13
-------------------

  * _ip_pacman_invoke: `-Syu` retry path uses `-Syyu` only
    (forced db re-sync); fall-through `-Sy --needed` only when
    `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1`.
  * _install_aur_packages: per-pkg retry after batch failure;
    `_RY_AUR_PARTIAL=true` surfaced in summary.
  * _ip_scan_pacnew: managed `.pacnew` auto-resolves via
    re-deploy; `.pacsave` warn-only.
  * _vrkg_perf_level: scan all `/sys/class/drm/card*/device`,
    report per-card.
  * _vrkg_rebar_sam: dmesg cache + lspci fallback.
  * _vrkg_vram: `mem_info_vram_total` BIOS carveout check.

v6.2.2 - 2026-05-13
-------------------

  * _atomic_write_file: post-write symlink re-check (TOCTOU).
  * _ry_install_file: skip-probe via `_installed_bytes` compare.
  * _fstab_atomic_replace: `findmnt --verify` hard-fail.
  * _vrs_nm_perms: `find -print0 | string split0` + pipestatus.
  * _vrs_parent_dirs: refuse group/world-writable managed parents.
  * _vrs_vulkan: `EXPECTED_VULKAN_PKGS` check (DXVK/VKD3D dep).
  * _post_boot: `RY_INSTALL_FORCE_BOOT_REBUILD` taint-gate parity
    with `_install_rebuild_boot`.

v6.2.1 - 2026-05-13
-------------------

  * _ir_validate_counts: hard-fail when documented array counts
    drift from declared invariants (`_RY_MANAGED_FILE_COUNT`,
    `KERNEL_PARAMS`, `MKINITCPIO_HOOKS`, etc.).
  * _ir_validate_keys: refuse deploy when two managed destinations
    produce the same `_tmpfile_key` (dispatch collision).
  * _init_runtime: precompute caches before any sudo write.
  * _RY_POST_HOOKS: first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * --install-file: single-file redeploy with per-target post-hook
    dispatch (boot, service, resolved, logind, nm, sysctl, envd,
    drirc); paths canonicalised via `realpath -m`.
  * argparse: `--exclusive` group for mode flags; positional after
    `--` rejected; empty `--install-file=` rejected.
  * lock: atomic `mkdir` + pid-file; stale-lock auto-reclaim on
    dead PID (`kill -0`); `EXIT_LOCK (5)` on contention.

v6.1.0 - 2026-05-12
-------------------

  * user-bus: replaced systemd-keepalive workaround with inline
    `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`
    probes (`_vre_envvars`, `_install_finalize`, `_post_service`).

v6.0.0 - 2026-05-12
-------------------

Reduction release: 5994 → 4985 LOC (-16.8%).

  * preflight: drop GNU-tool sanity probes (timeout retained).
  * source-mode: drop `_ry_bail_check` + 34 sites,
    `_ry_namespace_cleanup`; load guard refuses `source` at head.
  * ntsync: drop per-installed-kernel probes; running-kernel
    `_ntsync_state` retained.
  * kernel-params: drop `_validate_kernel_params` (advisory).
  * initramfs: drop `_ir_validate_timing`.
  * sudo-keepalive: drop `_*_sudo_keepalive` + 19 sites + interval
    global. User: long phases may re-prompt — `sudo -v` first.
  * progress: drop `_progress*` + JSONL `progress` events.
  * logging/rotation: drop tail-of-script rotation; manual prune
    via `find ~/ry-install/logs -mtime +30 -delete`.
  * logging/_log: drop parallel-child PID guard; entries emit
    `event="log"` with raw `data`.
  * credentials/redact: drop `_redact_*` (script passes no secrets
    via argv).
  * atomic-writes: drop `_awf_validate_parent`,
    `_awf_parent_changed`, TOCTOU re-stat.
  * boot/sdboot: drop `_boot_wipe_gate` family;
    `RY_INSTALL_CONFIRM_BOOT_WIPE` no longer consulted.
  * lock: drop `.lock-broker` artifact; stale lock now exits
    `EXIT_LOCK`.
  * services/mask: drop LVM detection; `lvm2-monitor.service`
    always masked.

v5.0.35 - 2026-05-11: preflight/awk `n==1` → `n==3`; sudo-keepalive `env LC_ALL=C stat` fix; `cond; and _err` → `if`; AUR PGP remediation hint; `findmnt --verify` per-line failures; redactor dash-flag guard.
v5.0.34 - 2026-05-11: 24 `cond; and _err X; and return N` → explicit `if` (EPIPE short-circuited return); `realpath` soft-dep; pactree 60s ceiling under `RY_RUN_TIMEOUT=0`; `_acquire_lock` failure via `_pre_dispatch_exit`; `_write_footer` sets log-write-fail flag; `_progress_*` monotonic seconds.
v5.0.33 - 2026-05-11: bootstrap chained-test refactor; KERNEL_PARAMS metachar reject; `df -B`; fstab awk strips `defaults`; install-file dispatch tag whitelist from `_post_<tag>`; sudo-policy `LC_ALL=C`; dmesg cache 5000; cpupower-epp service hardened (ProtectSystem/LockPersonality/MemoryDenyWriteExecute).
v5.0.32 - 2026-05-12: redact combined-alternation; preflight `mv -T`/`chmod --reference`; awk POSIX probe; `RY_INITRD_WARN_MB`; mkinitcpio post-pacman hook revalidation; lock atomic pid-file; pactree honors `RY_RUN_TIMEOUT=0`.
v5.0.31 - 2026-05-12: `_MY_UID` regex; `_ir_validate_keys`; `_awf_render_to_tmp` BUG vs tee-fail distinction; `_post_boot` install-file parity.
v5.0.30 - 2026-05-11: `_RY_SECRET_FLAGS` `$` reject; `_RY_SYSTEMD_VER_TRIED` sentinel; `_run` hard-fails on missing `timeout(1)`; capture cap 100 → 500; mask list pre-filter; cache-trim gated on `SYSTEM_UPGRADED=true`.
v5.0.29 - 2026-05-11: `$BOOT` via `bootctl -x` (XBOOTLDR); mkinitcpio signal-time revert; byte-exact size verify; `daemon-reload --user` gated on user-bus.
v5.0.28 - 2026-05-11: `-h`/`--help` to stdout; user-mode perms 0600 → 0644; cloudflare.com secondary HTTPS probe; `_run` redaction; lock `chmod 600` post `mv -Tf`.
v5.0.27 - 2026-05-11: `_RY_HAS_LVM` memoization; `_vre_thp_ksm` raw sysfs fallback; `--check` unconditionally silent; virtual-iface allowlist.
v5.0.26 - 2026-05-11: cpupower-epp `$$cpu` escape; `_vrsv_chk_cpupower` reads cpu0 EPP; `NO_COLOR` byte-preserved; keepalive lower bound.
v5.0.25 - 2026-05-11: defensive `2>/dev/null` on sudo probes; parent inode/uid/mode TOCTOU snapshot; `_mktemp_or_null`; `_RY_CANON_*` precomputed.
v5.0.24 - 2026-05-11: `_log` JSONL truncation indexing fix; `_is_symlink` rc=2 on sudo lapse; SSH key checks dropped.
v5.0.23 - 2026-05-11: `_redact_text` greedy multi-token; `_run` line-by-line redact; fstab skips digits-only options; `_ir_validate_counts` map extended.
v5.0.22 - 2026-05-10: drop `_RY_BOOT_TAINTED` on AUR failure; paru `--removemake`; `_vrk_module_state` split.
v5.0.21 - 2026-05-10: `_run` redact before log; `_pbs_entry_has_valid_kernel` tab-sep `linux<TAB>`; sudo-policy "not cached" vs "denies ALL".
v5.0.20 - 2026-05-10: `find -print0 | string split0` pipestatus `[1]`; dash-prefix pkg name reject; `cpupower-epp.service` hardening.
v5.0.19 - 2026-05-10: `_redact_argv_elements` case-insensitive; `bootctl` advisory; `--skipreview` on batch+per-pkg.
v5.0.18 - 2026-05-10: cleanup mktemp allowlist; `_verify_static_checksum` branches on `_installed_bytes` rc; runtime blacklist from `module_blacklist=` parse; `grep -m1` probe.
v5.0.17 - 2026-05-10: `_chk_file` rejects `/boot/*` symlinks.
v5.0.16 - 2026-05-10: `_ry_content_bytes` preserves dispatcher rc; `_RY_IWD_GATED_DSTS`; refuse empty/non-dir HOME.
v5.0.15 - 2026-05-10: fstab passthrough whitespace; reject empty `--install-file=`; lock reclaim flock-broker only when PID dead.
v5.0.14 - 2026-05-10: `_pbs_entry_has_valid_kernel` `realpath -m`; `_bwg_managed_only` auto-ack.
v5.0.13 - 2026-05-10: keepalive hermetic child via `fish --no-config -c`; `_do_cleanup` `pkill -P` TERM→KILL.
v5.0.12 - 2026-05-10: pinned scroll-region progress bar (DECSTBM); SIGWINCH re-anchor; skipped under mosh/tmux/screen.
v5.0.11 - 2026-05-10: pre-deploy `/etc/mkinitcpio.conf` before `pacman -Syu`; byte-exact revert on failure.
v5.0.10 - 2026-05-10: pactree cascade under `RY_INSTALL_PKG_REMOVE_CASCADE=1`; pacman `-Syyu` retry.
v5.0.9  - 2026-05-10: services split "enable ok, --now failed" from "enable failed"; NM restart deferred when WiFi is active route.
v5.0.8  - 2026-05-10: `_resolve_esp`/`_resolve_boot_path` via bootctl; `_preflight_boot_sanity` vmlinuz+initramfs+valid-entry.
v5.0.7  - 2026-05-10: `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` → `pacman -Sy --needed`; `RY_INSTALL_FORCE_BOOT_REBUILD` bypasses taint gate.
v5.0.6  - 2026-05-10: `_vre_zram` accepts `static`+active swap; THP defer+madvise + shrink_underused=0 + ksm.run=0.
v5.0.5  - 2026-05-10: `.pacnew` auto-resolve at managed paths; `_post_sysctl` runs `sysctl --system`.
v5.0.4  - 2026-05-10: NO_COLOR no-color.org spec; `RY_RUN_TIMEOUT` unified via `math`; `_cleanup` reports actual signal name.
v5.0.3  - 2026-05-09: `htop` added to PKGS_ADD; `_post_boot` honours wipe gate; `_vsb_cmdline` verifies live root UUID.
v5.0.2  - 2026-05-09: `_vre_zram` accepts `static`+swap; paru `--cleanafter`.
v5.0.1  - 2026-05-09: style — trim verbose comments.
v5.0    - 2026-05-09: stable milestone.

Pre-v5.0 history archived to `ChangeLog-4.x` upstream.
