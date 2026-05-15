ry-install ChangeLog
====================

v6.5.7 - 2026-05-14
-------------------

  * _init_runtime: the KERNEL_PARAMS sanity gate
    `string match -qr -- '[\s"`$;\\]' "$_kp"` had two source
    backslashes between the `;` and the closing `]`, intending to put
    `\\` in the PCRE pattern so the class would contain a literal
    backslash plus the terminator. Fish single-quote semantics
    collapse each `\\` to one `\` (the only escapes recognised inside
    single quotes are `\\` and `\'`), so PCRE actually received nine
    bytes — `[\s"`$;\]` — with only one backslash before the bracket.
    Inside a class, `\]` is an escaped `]` (literal, does not close),
    leaving the class with no terminator; PCRE refused to compile and
    `string match` returned rc=2 for every `$KERNEL_PARAMS` member
    (15 on this profile), emitting `Regular expression compile error:
    missing terminating ]` to stderr fifteen times at the top of every
    install. The bootstrap stage runs before `_log` opens the JSONL,
    so the stderr noise was visible on the TTY but never captured in
    any log file. More consequential: `rc=2` reads as "no match" to
    the surrounding `if`, so the validator body — `_err_loud` +
    `_pre_dispatch_exit $EXIT_PREFLIGHT` — never fired. Every
    KERNEL_PARAMS member containing whitespace, an unescaped quote,
    backtick, dollar, or semicolon would have silently propagated
    into `/etc/kernel/cmdline` and sdboot-manage `LINUX_OPTIONS=`.
    The profile's actual params are all clean tokens, so the latent
    failure mode never surfaced in practice; the gate has been dead
    since the validator was introduced. Doubled the trailing
    backslashes (source `\\` -> `\\\\`) so fish delivers `\\` to PCRE
    as a literal-backslash escape; verified against all 15 real
    KERNEL_PARAMS plus six representative bad inputs (space, quote,
    semicolon, dollar, backtick, lone backslash) — all six now
    blocked, all 15 legitimate params pass without stderr noise.

  * Other regexes: ran every other single-quoted (43) and
    double-quoted (51) `string match -qr` pattern in the script
    through PCRE the same way (`string match -qr -- $pat ""`) to
    flush any other latent compile failures. Line 758 was the only
    one; the remaining 93 patterns compile clean.

  * Net effect: 4996 -> 4996 lines (single-character source delta on
    line 758). No exit-code or footer-schema impact; the validator
    becomes functional for the first time, but the profile's actual
    KERNEL_PARAMS members all pass it, so observable install
    behaviour is identical apart from the disappearance of the
    fifteen `string match: Regular expression compile error` lines
    at startup.

  * README: version badge -> 6.5.7.

v6.5.6 - 2026-05-14
-------------------

  * _msg: OK/WARN/FAIL counter increments were gated behind
    `if test "$VERIFY_MODE" = true`, so the `VERIFY_OK`/`VERIFY_FAIL`/
    `VERIFY_WARN` globals only moved in `verify-static` /
    `verify-runtime`. `_write_footer` reads those same globals
    unconditionally and prints them as the footer's `pass`/`fail`/
    `warn` fields for every mode — meaning an install run that
    emitted half a dozen `WARN:` lines (deferred NM restart on active
    WiFi, plymouth reverse-dep block, transient AUR retry, etc.) still
    closed with `"pass":0,"fail":0,"warn":0,"gen_fail":0`. The
    structural always-zero install summary made
    `jq 'select(.event=="footer" and .warn>0)'` etc. unusable for
    install/install-file logs. Removed the gate; `_msg` now counts in
    every mode. The reset+snapshot contract used by
    `_ry_verify_static` / `_ry_verify_runtime` is unchanged (each
    zeroes the counters at entry and `_verify_summary` snapshots
    before printing via `_msg_nocount`), so verify-mode totals are
    identical to v6.5.5. `--check` mode footers remain `0,0,0,0`
    because the `_check_phase_*` helpers use `_log` directly and never
    enter the `_msg` family — correct for a silent idempotency probe.

  * VERIFY_MODE: with the gate above gone, the variable was read
    nowhere (only written — twice in `_ry_verify_static`, twice in
    `_ry_verify_runtime`, and a trailing `set -g VERIFY_MODE false`
    inside `_verify_summary`; no separate top-level initialiser).
    Removed all five assignments; `_msg_nocount` still exists as the
    explicit opt-out for `_verify_summary`'s own summary line and for
    `_verify_static_checksum`'s `_fail_silent` generator-failure path
    (which bumps `VERIFY_GEN_FAIL` itself, separately from the
    `FAIL`/`WARN` counters).

  * README: the documented jq one-liner
    `jq 'select(.event == "fail")'` matched zero records — the script
    only ever emits three event types (`header`, `log`, `footer`).
    Errors are `log` events whose `data` field begins with `FAIL:` or
    `ERR:`. Replaced with
    `jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):")))'`,
    added a second example for the per-run `footer` event, and
    documented the three event types and the footer's
    `exit_code`/`pass`/`fail`/`warn`/`gen_fail` keys (previously
    hand-waved by `...` in the schema line) — the schema note now
    explicitly states the counters are populated in every mode, which
    matches the `_msg` change above.

  * Net effect: 5003 -> 4996 lines (7 lines removed: the 2-line
    `if`/`end` gate in `_msg`, and five `set -g VERIFY_MODE` writes
    across `_ry_verify_static` (2), `_ry_verify_runtime` (2), and
    `_verify_summary` (1)). Only the install + install-file footer
    JSON changes observably; verify-static / verify-runtime / check /
    install exit codes are unchanged.

  * README: version badge -> 6.5.6.

v6.5.5 - 2026-05-14
-------------------

  * _chk_grep: the comment-strip / pattern-match pipeline ran the
    second stage as `grep -qwF`. `grep -q` exits on the first match,
    closing the pipe; when the matched token is not near the end of a
    large config file the upstream `grep -v '^#'` is still writing and
    dies with SIGPIPE (exit 141). `_chk_grep` reads that stage-1 code,
    falls through its `0`/`1` switch arms to `case '*'`, and emits a
    spurious `cannot read file (stage-1 rc=141 — sudo lapse or read
    error)` WARN instead of the correct OK. The current managed files
    are all far smaller than the 64 KiB pipe buffer, so `grep -v`
    always finishes writing before `grep -q` reads and the bug never
    triggers in practice — but it is latent for any larger managed
    destination. The second stage now runs `grep -wF ... >/dev/null`
    (output discarded, no early exit): `grep -wF` consumes its entire
    input, so stage 1 never receives SIGPIPE and `$pipestatus[1]` is
    reliable. `-w`/`-F` semantics and the 0/1/2 exit-status contract
    are unchanged.

  * _far_awk_rewrite: the awk-stderr and tee-stderr capture tmpfiles
    were created in `(_tmp_dir)` with a `.ry-install.` prefix
    (`.ry-install.tee-err.XXXXXX`, `.ry-install.awk-err.XXXXXX`). Every
    other `_tmp_dir` tmpfile uses the `ry-` prefix; the `.ry-install.`
    prefix is the convention for tmpfiles created *in a managed
    destination directory* (swept by `_cleanup_tmpfiles`). As a
    result these two files were not matched by the
    `_dc_sweep_filesystem` fallback glob set and would survive in
    `/tmp` if a run were SIGKILL'd between their creation and the
    tracked-tmpfile cleanup. Renamed to `ry-fstab-tee-err.XXXXXX` /
    `ry-fstab-awk-err.XXXXXX` and added both globs to
    `_dc_sweep_filesystem`. They remain tracked + explicitly removed
    on every normal path; this only closes the killed-mid-run gap.

  * Net effect: 5001 -> 5003 lines. The `_chk_grep` change is the only
    behavior change (and only observable on managed files larger than
    one pipe buffer); install / verify-runtime / check flows are
    otherwise unchanged.

  * README: version badge -> 6.5.5.

v6.5.4 - 2026-05-14
-------------------

  * _check_phase_units: the --check implicit-service loop required
    NetworkManager-dispatcher.service to be `enabled`, but the unit
    ships `static` (`WantedBy=` empty) on a clean CachyOS install — so
    `--check` returned `EXIT_DRIFT` (10) on a correctly-installed
    system. `--verify-runtime` already accepts `static` for this unit
    (v6.3); the `--check` path now does too. systemd-resolved.service
    still requires `enabled`.

  * _far_awk_rewrite: the awk-stderr and tee-stderr capture tmpfiles
    were allocated with a bare `command mktemp`; on mktemp failure the
    path was an empty string and `2>"$_awk_err"` / `2>"$_tee_err"`
    became an invalid-redirection error, failing the fstab rewrite.
    Both now use `_mktemp_or_null`, matching every other tmpfile that
    feeds a redirect (empty result → `/dev/null` sentinel).

  * _dc_sweep_filesystem: dropped the vestigial `ry-ka-err.*` cleanup
    glob. The sudo-keepalive helpers that produced those tmpfiles were
    removed in v6.0; no code path creates them.

  * _rdi_run_phases: removed five unreachable
    `test "$_RY_INSTALL_BAILING" = true; and return 0` guards. The
    only writer of the sentinel, `_ry_exit`, calls `exit` immediately
    after setting it, so it can never be observed true mid-function
    (v6.2.7 removed two of the same class).

  * Net effect: 5003 -> 5001 lines. The `--check` NM-dispatcher fix is
    the only behavior change; the install / verify-static /
    verify-runtime flows are unchanged.

  * README: version badge -> 6.5.4; Prerequisites `Tooling` row marks
    `ip(8)` as recommended rather than required — the script classes
    it optional (`_ry_check_deps` optional-tool list) and degrades
    gracefully when it is absent.

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

  * _dc_sweep_tmpfiles spurious-TMPFILE_STUCK fix (or-chain precedence); _verify_static_services multi-ExecStart guard; 14 head/tail sites use `command` prefix; _json_str drops unreachable NUL escape; _run_emit_stream / _ry_do_install / argparse comment trims; README badge -> 6.5.

v6.4 - 2026-05-14
-----------------

  * _vsb_entries distinguishes lapsed-sudo / unresolved-$BOOT from genuine-empty entries dir; _ry_check_deps adds 10 coreutils + reuses _resolve_systemd_ver; _progress_init skipped under NO_COLOR; dead `; or set _ret 1` clauses dropped; LC_ALL=C normalized to `env` prefix; _run_emit_stream / _ry_do_install comments; db.lck message wording; README badge -> 6.4 + logind.conf.d MISMATCH troubleshooting row.

v6.3 - 2026-05-14
-----------------

  * _dc_sweep_tmpfiles logs TMPFILE_STUCK before erase; header-write sets log-write-fail sentinel; _err_loud deduped via `_msg_print --force`; six _msg wrappers + content generators collapsed to one line; _is_wifi_active_route / _ry_check_network loop-folded; _vrsv_chk_nm_dispatcher accepts `static`; _tmpfile_key / _run / _vre_thp_ksm / _json_str rewrites; README reference tables trimmed.

v6.2.13 - 2026-05-14
--------------------

  * _run split into _run / _run_redact_cmd / _run_effective_timeout; cpupower-epp `$$cpu` rationale comment collapsed to one line.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect` (space-vs-newline token-boundary bug, pipestatus[1] recovery); _run_emit_stream / _echo / _csm_filter_units / _csp_filter_rdeps emit via `printf` (echo flag-injection); _write_footer extra_key through _json_str; _verify_static_syntax HOOKS `string trim`; _progress_init bails under $ZELLIJ; cpupower-epp `$$cpu` inline comment.

v6.2.11 - 2026-05-13
--------------------

  * _csp_filter_rdeps pipestatus gate narrowed to stage 1; JSONL header before _init_runtime; lazy _log creation, eager top-level removed; root-check hoisted after UID parse; LOCK_DIR chmod 700 + _RY_LOCK_DIR_OWNED set post-mkdir; _verify_unit_syntax / _post_* `--argument-names`; _early_usage_exit prints help; updatedb / pkgfile timeout-bypass; TMPDIR / HOME preflight hardening; _vrs_boot_perf parse anchor; _vsc_static_checksum log wording; _cse_collect_units printf; _dc_erase_globals additions; drop dead _RY_TIMEOUT_OK.

v6.2.10 - 2026-05-14
--------------------

  * _ry_check_deps adds `grep`; pacman -Qq / -T status capture across verify + remove paths; _idf_match_dst single-token return; logind HandleSecureAttentionKey explicit if-block; _vsb_mkinitcpio per-token COMPRESSION_OPTIONS match; _verify_runtime_kparams dmesg-slice precompute; _pb_rebuild_cascade dead local; --description trims; _msg_print / _dc_erase_globals / EXIT_* / boot-time `-le` / dispatch QUIET style cleanups; 5054 -> ~5008 LOC.

v6.2.9 - 2026-05-13
-------------------

  * HOME field-6 via `awk -F:` (GECOS-tolerant); _atomic_write_file dead local removed; _ry_check_deps adds `mv`; verbose `--description` strings collapsed to leading clause.

v6.2.8 - 2026-05-13
-------------------

  * Log rename + _acquire_lock before JSONL header; _install_preflight early-returns set _PROG_FINALIZED_SKIP; empty-message short-circuit hoisted to callers; _dc_erase_globals symmetry; _csp_filter_rdeps pipestatus widened; _csp_remove_pkgs visible _ok; _progress_init read-only TTY probe; _ry_do_install dead arg dropped.

v6.2.7 - 2026-05-13
-------------------

  * user destinations 0600; _as BUG rc -> 250; _run sudo-bypass dash-flag scan; _run tmpdir-alloc rc 251; STDOUT label; optional-tool absences batched; _vmh_order_checks / _far_awk_rewrite / _is_system_dst / _dc_sweep_filesystem / _install_aur_packages / _post_service tweaks; explicit `return 0` across 11 sites; cat `--` drop on lock reads; `set -e` -> `set --erase`; two unreachable _RY_INSTALL_BAILING checks removed; dead intermediates dropped; sourcing-guard simplified.

v6.2.6 - 2026-05-13
-------------------

  * Top-level array declarations wrap one element per continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * _pbs_check_boot_files snapshots `$pipestatus` before _pipe_all_ok; dead `functions -q _warn` guard dropped from _ry_mkinitcpio_array; ~52 standalone _echo blank-line separators collapsed.

v6.2.4 - 2026-05-13
-------------------

  * _run timeout-bypass for pacman / paru / mkinitcpio / sdboot-manage / paccache (TIMEOUT_BYPASS marker); tmpfile-path redaction under $TMPDIR; `command timeout` refuses if timeout(1) absent; capture cap 100 -> 500 with _TRUNCATED sentinels; _err_loud always emits regardless of QUIET; _vsb_sdboot quote-count == 2 guard.

v6.2.3 - 2026-05-13
-------------------

  * _ip_pacman_invoke -Syyu retry / -Sy gated on RY_INSTALL_ALLOW_PARTIAL_UPGRADE; _install_aur_packages per-pkg retry; .pacnew auto-resolve at managed paths; _vrkg_perf_level per-card scan; _vrkg_rebar_sam dmesg + lspci fallback; _vrkg_vram BIOS carveout check.

v6.2.2 - 2026-05-13
-------------------

  * _atomic_write_file post-write symlink re-check (TOCTOU); _ry_install_file skip-probe via _installed_bytes; _fstab_atomic_replace findmnt --verify hard-fail; _vrs_nm_perms pipestatus; _vrs_parent_dirs refuses group/world-writable parents; _vrs_vulkan EXPECTED_VULKAN_PKGS check; _post_boot force-rebuild taint-gate parity.

v6.2.1 - 2026-05-13
-------------------

  * _ir_validate_counts array-count invariants; _ir_validate_keys _tmpfile_key collision refuse; _init_runtime precomputes caches before any sudo write; _RY_POST_HOOKS first-match table for --install-file hooks.

v6.2.0 - 2026-05-12
-------------------

  * --install-file single-file redeploy with per-target post-hook dispatch (paths canonicalised via `realpath -m`); argparse --exclusive mode group + post-`--` positional reject; atomic mkdir + pid-file lock with dead-PID stale-lock reclaim.

v6.1.0 - 2026-05-12
-------------------

  * user-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running` probes, replacing the systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 -> 4985 LOC: drop GNU-tool sanity probes, source-mode scaffolding (_ry_bail_check + 34 sites, _ry_namespace_cleanup), ntsync per-kernel probes, _validate_kernel_params, _ir_validate_timing, sudo-keepalive (+ 19 sites), _progress* + JSONL progress events, tail-of-script log rotation, parallel-child PID guard, _redact_*, atomic-write TOCTOU re-stat, boot-wipe gate family, .lock-broker artifact, LVM detection.

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
