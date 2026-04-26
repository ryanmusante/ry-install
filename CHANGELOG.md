ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first,
entries grouped under a dated heading, each bullet names the
subsystem or function before the change description.


v4.4.0 - 2026-04-25
-------------------

  Audit-driven release. Two HIGH cleanup-invariant defects closed,
  two MED diagnostic and trust-model gaps closed, two LOW correctness
  fixes, and one drift assertion. Same root cause for both HIGHs: the
  resource-cleanup function (`_do_cleanup`) was reachable only from
  signal-handler paths (SIGINT/SIGTERM/SIGHUP/SIGQUIT/SIGPIPE), never
  from normal exit, sourced return, or early bail. Symptom: every run
  of v4.3.x and earlier left `~/ry-install/.lock/` on disk, forcing the
  stale-reclaim path on the next invocation. No managed-file content
  changes; verify-static remains stable across upgrade.

[fix]

  * _teardown / _cleanup_on_exit cleanup invariant: `_do_cleanup` is
    now called from the `case exit` arm of `_teardown`, so the
    fish_exit handler (`_cleanup_on_exit`) releases LOCK_DIR, removes
    tracked tmpfiles, and terminates the sudo-keepalive child on
    every normal exit. Previously the `case exit` arm wrote the JSONL
    footer and returned without calling `_do_cleanup`, so LOCK_DIR
    was retained until either the host fish process exited or a
    subsequent run hit the stale-reclaim path. Affected all four
    primary modes (install, install-file, verify-static,
    verify-runtime) plus --check. Location: L506 (_teardown body).

  * end-of-script sourced-return path cleanup: the sourced branch
    that runs when `_RY_INSTALL_SOURCED=true` now calls `_do_cleanup`
    before erasing the signal/exit handlers, instead of jumping
    straight to `_ry_namespace_cleanup` (which only erases globals).
    Symptom for sourced workflows: lock leaked on every successful
    run; the user had to `rm -rf ~/ry-install/.lock/` between
    sessions. fish_exit does not fire on `return` from a sourced
    script, so this could not be picked up by the exit handler.
    Location: L5077-5085 (top-level dispatch tail).

  * _ry_exit early-bail cleanup: `_ry_exit` (the source-safe exit
    helper used by 25 preflight/usage rejection sites) now invokes
    `_do_cleanup` between the handler-erase and `_ry_namespace_cleanup`
    calls, guarded by `functions -q _do_cleanup` so calls before the
    function is defined (during early bootstrap, e.g. fish-version
    gate, HOME resolution, LOG_DIR creation) silently skip cleanup
    where there is nothing to clean. After the function is defined
    (line ~430), every `_ry_exit` call releases resources idempotently.
    Location: L29-43 (function body).

  * argparse stderr capture: argparse output is now captured to a
    tracked tempfile and forwarded into the `[ERR]` line emitted on
    parse failure, replacing the previous generic "Invalid arguments:
    $_ORIG_ARGV" message. Users now see fish's specific diagnostic
    (`--bogus: unknown option`, `check verify-static: options cannot
    be used together`, `Option '--install-file' requires an argument`)
    before the help text. The previous behavior swallowed argparse's
    stderr via `2>/dev/null`. The capture file is added to
    `_TRACKED_TMPFILES` and explicitly removed on both success and
    failure paths. Location: L4895-4922 (CLI parser block).

  * profile ownership + mode check: external profile files at
    `~/.config/ry-install/profiles/<name>.fish` are now stat'd before
    `source`. The script refuses to load any profile not owned by
    the invoking UID, or any profile whose group/other mode digits
    have the write bit set (mode digit must match `[0145]`). The
    profile-name regex was already path-traversal-safe; this fix
    closes the gap where the README documented a trust model that
    the script did not enforce. Failure exits `EXIT_USAGE` (2) with
    the offending uid or mode named in the error. Location: L965-985
    (_load_profile body).

  * _acquire_lock dead code: the redundant `verify_pid2` block in
    the stale-reclaim path was removed. Both `verify_pid` and
    `verify_pid2` reads were issued back-to-back with no time gap
    in the flock(1) branch (which had already atomically written
    our PID), and the fallback branch already performs a 100 ms
    yield before the first read, leaving no semantic difference
    between the two adjacent reads. The "late writer" failure
    mode the second read claimed to detect cannot occur after the
    flock-protected write or the fallback yield. Location: L417-426.

  * _run tracked-tmpfile filter glob safety: `_TRACKED_TMPFILES`
    no longer uses `string match -v` (which interprets glob
    metacharacters in the pattern argument) to filter out a removed
    `_run_dir`. Replaced with an explicit for-loop using literal
    string equality. mktemp output is alphanumeric in practice so
    the original code was not exploitable, but a non-default `TMPDIR`
    containing a `*` or `?` would have caused the filter to either
    drop unrelated entries or fail to drop the intended one.
    Location: L1660-1671 (end of _run body).

[diag]

  * managed-file count drift assertion: after `_load_profile`, the
    script now compares the active profile's `MANAGED_FILE_COUNT`
    against the hardcoded `_RY_MANAGED_FILE_COUNT` constant (used as
    a fallback in `_ry_show_help` before profile load) and emits a
    `[WARN]` if they differ. Catches the maintenance hazard where
    profile destinations are added or removed but the help-text
    fallback constant is not kept in sync. Location: L5008-5012
    (post-_load_profile dispatch tail).

  * comment style cleanup: 17 comment lines that ended in trailing
    " ..." truncation artifacts (legacy from an earlier mechanical
    line-shortening pass) have had the ellipsis stripped. The
    affected comments now end with the last meaningful word.
    Mid-line semantic ellipsis (notation like `begin...end`,
    `KEY=...`, `(ALL,...)`, systemd output format strings) is
    preserved. Header (L1-2) and `lint:ignore` directives are
    untouched. No code paths affected.

[deferred]

  * function length cap: 24 functions exceed the 50-LOC project
    rule, 9 exceed 100. Largest is `_verify_runtime_kparams` at
    242 LOC, followed by `_verify_runtime_session` (175),
    `_verify_runtime_env` (174), `_verify_runtime_services` (165),
    `_install_rebuild_boot` (136), `_validate_profile` (130). The
    verify-runtime family is mostly flat per-parameter or
    per-subsystem switch logic and would split cleanly along
    natural seams. Mechanical splitting risks regressions in the
    verify-mode counter wiring (VERIFY_OK/FAIL/WARN updates flow
    through `_msg`); deferred to a dedicated refactor with
    verify-mode regression coverage.

[verified]

  * fish --no-execute: clean (RC=0).
  * --version: returns `v4.4.0` as expected, exit 0.
  * --help: renders with v4.4.0 in header, all sections present, exit 0.
  * --bogus: stderr now contains `[ERR] ry-install.fish: --bogus:
    unknown option` (was: `[ERR] Invalid arguments: --bogus`),
    exit 2.
  * --verify-static --check: stderr now contains `[ERR]
    ry-install.fish: check verify-static: options cannot be used
    together` (was: same generic line as --bogus), exit 2.
  * --install-file=relative/path: rejected with absolute-path
    requirement, exit 2.
  * positional argument: rejected with named-positional error,
    exit 2.
  * --check on non-CachyOS host: exits EXIT_PREFLIGHT (3), no
    crash.
  * Cleanup invariant (v4.4.0 HIGH#1+#2 fix): three consecutive
    --check invocations followed by an --install-file invocation
    that acquires the lock then fails at preflight — LOCK_DIR
    absent on disk after every run.
  * Sourced execution: `source ry-install.fish --version` and
    `source ry-install.fish --bogus` both return into the host
    fish (exit 0 / exit 2) without killing it. After cleanup,
    only `_RY_INSTALL_LAST_EXIT` and `_RY_INSTALL_BAILING` remain
    in the host namespace — both intentionally preserved by
    `_ry_namespace_cleanup` for caller use.
  * Re-source: a second `source` after the first succeeds (no
    "already loaded" rejection), confirming `_RY_INSTALL_LOADED`
    is correctly erased on cleanup.
  * 8 `@@AUDIT@@ v4.4.0` markers placed at every fix site.
  * Total LOC change: 5085 → 5124 (+39, all from the seven inline
    fixes plus the audit markers and one drift-warning line).
    Comment-trim pass changed 17 comment lines in place
    (no LOC delta).


v4.3.9 - 2026-04-25
-------------------

  Audit-driven release. One UX-blocking sudo-flow inconsistency
  closed: install-mode and install-file-mode now interactively
  prompt for sudo password when not pre-cached, matching the
  long-standing behavior of verify modes. No content-hash
  changes; verify-static remains stable across upgrade.

[fix]

  * _install_preflight + _ry_do_install_file sudo flow: replace
    bare `sudo -n true` (non-interactive only, no fallback) with
    `_ensure_sudo_cached` (probes `sudo -n -v` then falls back
    to interactive `sudo -v`). Symptom: a user running the
    script without first running `sudo -v` saw the leading
    "[INFO] Sudo password required for installation..." message
    followed by "[ERR] Sudo required for installation" and an
    immediate EXIT_PREFLIGHT (3), with NO opportunity to enter
    a password. Affected both unattended install (default mode)
    and `--install-file` for system-scope targets. The verify
    modes (`--verify-static`, `--verify-runtime`) already used
    `_ensure_sudo_cached` and behaved correctly. Fix unifies the
    pattern across all four privileged entry points. Locations:
    L3802-3807 (_install_preflight) and L4723-4725
    (_ry_do_install_file). No new dependencies; no new exit
    codes. Verified: `fish --no-execute` clean; existing CLI
    flag matrix (`--help`/`-h`/`--version`/`-v`/`--check`/
    `--verify-static`/`--verify-runtime`/`--foo`/positional/
    exclusive-violation/`--install-file=`empty/relative/flag-
    as-arg) all return the same exit codes as v4.3.8.


v4.3.8 - 2026-04-25
-------------------

  Audit-driven release. One install-blocking defect closed
  (_ry_install_file user-dir mkdir failed under timeout(1) due
  to `command` builtin shadowing), one privilege scope reduction
  in fstab rewrite, two defense-in-depth hardening fixes (sysctl
  key regex, boot-wipe marker hash boundary), and one documenta-
  tion strengthening for _run argv invariant. No content-hash
  changes; verify-static remains stable across upgrade.

[fix]

  * _ry_install_file user-dir mkdir: drop `command` prefix from
    `_run command mkdir -p -- "$dir"` (L2362). _run wraps argv
    with timeout(1), and timeout(1) cannot exec the `command`
    builtin (rc=127 "failed to run command 'command': No such
    file or directory"). Symptom on first install: user-dir
    deployments to non-existent paths (~/.config/environment.d,
    ~/.config/systemd/user) failed with "Cannot create direc-
    tory" because mkdir was never invoked. Sudo branch (L2358)
    was unaffected — sudo is a real binary. Root cause: undocu-
    mented assumption that `command` builtin would pass through
    timeout. Verified reproducer: `command timeout 5 command
    mkdir /tmp/x` → rc=127. Fix: drop the `command` prefix; _run
    resolves argv[1] via PATH directly. Single-instance bug; rg
    audit confirmed no other `_run <builtin>` callers.

[security]

  * _install_fstab_opts: drop sudo from awk side of the rewrite
    pipeline (L4039). /etc/fstab is 0644 root:root (world-read-
    able per filesystem package); awk reads as user, only tee
    needs sudo to write into the sudo-mktemp'd /etc/.ry-install.
    fstab.* tmpfile. Reduces privilege scope by one process and
    halves sudo invocations on this hot path. No behavior change
    for fstab readability — same input, same output.

[defense]

  * _grep_sysctl_kv key regex: extend [a-zA-Z._0-9]+ to include
    `-` (L2087). Current SYSCTL_VALUES has no hyphenated keys,
    but sysctl(8) keys may legally contain hyphens; future-proof
    for profile additions or upstream kernel sysctl renames.

  * Boot-wipe marker hash: switch sha256sum input delimiter from
    LF to NUL at both writer (L4482) and reader (L4374) sites.
    BLS spec rare-but-valid filename-with-newline would have
    collapsed adjacent entries in the LF-joined hash input; NUL-
    delimited stream preserves boundaries. sha256sum is byte-
    stream, algorithm unchanged; hash format compatibility hand-
    led by the legacy-marker accept-once path already present at
    L4395. Twin update keeps writer/reader synchronized.

[doc]

  * _run header: strengthen INVARIANT comment to explicitly for-
    bid fish/POSIX builtins as argv[1] (L1572). Documents the
    timeout(1)-cannot-dispatch-builtins constraint that produced
    the L2362 regression. Two-line block merged to single line
    per project comment style.

  * lint:ignore markers: add 7 missing markers on awk field-
    reference and PCRE backref sites that a fish static analyzer
    would otherwise flag. Two PCRE-backref `'$1'` sites in _run
    secret redaction (L1585-L1586), four `awk '{print $4}'` /
    `awk '{ print $4 }'` field-reference sites in _ry_check_disk_
    space (L1859, L1877), _verify_runtime_env fstab opts probe
    (L3497), and _install_fstab_opts opts probe (L4014), plus
    one `awk '$3 == "ext4"'` field-reference + boolean-operators
    site in _install_fstab_opts ext4-detection (L4006). Marker
    count: 14 → 21. No semantic change; convention parity with
    pre-existing markers in the same patterns.

  * test coverage: end-to-end execution suite verified on Linux
    sandbox (Ubuntu 24.04 + fish 3.7.0). 26 tests covering all
    --options, exit-code matrix, source-mode bail, NO_COLOR /
    TERM=dumb honoring, log-perm chain (0700/0600), JSONL parse-
    ability, and SIGINT mid-run footer interruption marker. All
    pass. CachyOS-specific paths (pacman, mkinitcpio, sdboot-
    manage, real boot artifacts) require host execution.

[style]

  * lint:ignore marker convention: relocate inline markers to
    above-line position (16 of 21 markers moved; 5 inside string
    literals stay in-place per construction). Aligns with the
    industry standard (shellcheck, clippy, mypy noqa-block).
    Future contributors: place `# lint:ignore (reason)` on its
    own line directly above the offending statement.

  * comment line-length: enforce single-line ≤120 chars across
    the whole script. 64 long comments were condensed to fit by
    dropping trailing @@AUDIT@@ historical clauses, parenthet-
    ical asides, em-dash trailing detail, or by word-boundary
    truncation with ellipsis. Operational essence preserved on
    every line; full historical context remains available in
    git log + this CHANGELOG. Decorative `─── header ───`
    dividers collapsed to plain `# header`. Multi-line comment
    blocks: 0. Pure-comment lines >120 chars: 0. Out of scope:
    79 pure-code lines (printf strings, profile-data lists,
    regex patterns where shortening changes semantics) and 13
    `#`-in-string-literal lines (shell scripts inside /bin/sh
    -c blocks) — these are not real comments.

  * test coverage: end-to-end execution suite verified on Linux
    sandbox (Ubuntu 24.04 + fish 3.7.0). 26 tests covering all
    --options, exit-code matrix, source-mode bail, NO_COLOR /
    TERM=dumb honoring, log-perm chain (0700/0600), JSONL parse-
    ability, and SIGINT mid-run footer interruption marker. All
    pass. CachyOS-specific paths (pacman, mkinitcpio, sdboot-
    manage, real boot artifacts) require host execution.

v4.3.7 - 2026-04-25
-------------------

  Audit-driven hardening release. Five low-severity findings
  closed: profile validator metachar gap, keepalive comment vs
  code mismatch, dead rc tracking in cpupower-epp ExecStart,
  network-failure message accuracy, and twin redundant guards
  on post-rebuild boot-entry counts. No execution-flow changes
  beyond the cpupower-epp content hash, which will redeploy on
  next install and re-baseline verify-static for that file.

[security]

  * _validate_profile element regex: extend forbidden-char class
    from [[:space:]"()] to [[:space:]"$'\`()\\;&|<>] (whitespace,
    double-quote, dollar, apostrophe, backtick, parens, backslash,
    semicolon, ampersand, pipe, less, greater). Profile elements
    in KERNEL_PARAMS / MKINITCPIO_MODULES / MKINITCPIO_HOOKS are
    interpolated into /etc/mkinitcpio.conf, which mkinitcpio(8)
    sources as root. The prior class missed bash command-substi-
    tution (backtick), variable-expansion ($), statement separa-
    tors (; & |), redirects (< >), apostrophe, and bare back-
    slash. No privilege escalation in single-user trust model
    (user has full sudo anyway), but defense-in-depth closes the
    gap for shared/repo-pulled profiles. Comment at L893 already
    asserted intent to "reject shell-metachars... embedded into
    config files" — code now matches the intent.

[fix]

  * _content__etc_systemd_system_cpupower-epp.service ExecStart:
    drop dead `rc=0` and `; rc=1` from per-CPU loop. Variable
    was assigned but never observed (literal `exit 0` follows
    unconditionally). Service intentionally succeeds on partial
    EPP write failure; per-CPU errors continue to reach the
    journal via StandardError=journal. Dropping the assignment
    removes a maintenance hazard (future reader assuming `rc`
    participates in exit code) without changing semantics. This
    is the only content-hash change in v4.3.7; verify-static
    will report drift on /etc/systemd/system/cpupower-epp.service
    until the next install redeploys the unit.

  * _verify_static_boot + _install_rebuild_boot: drop redundant
    `test -n "$entry_count"` and `string match -qr '^\d+$'`
    guards on the `count(1)` result. `count` always emits a
    non-negative integer string, so both prefix guards are
    unreachable-false. Single `test "$entry_count" -gt 0`
    suffices. Twin sites updated together for consistency.

[doc]

  * _install_preflight keepalive comment: replace misleading
    "transient PAM failures self-heal next cycle" claim with
    accurate "loop bails on first sudo -n -v failure (fail-fast)"
    description. The `or break` after `command sudo -n -v` exits
    the loop on any failure; there is no retry path. Parent
    surfaces death via _check_sudo_keepalive at each privileged
    phase. Comment now matches code.

  * _ry_check_network: when curl https://archlinux.org fails but
    ping 1.1.1.1 succeeds, message reworded from "HTTPS down
    (raw IP reachable; check /etc/resolv.conf)" to "HTTPS or DNS
    unreachable (raw-IP ICMP works; check /etc/resolv.conf or
    443 egress)". Both DNS-broken and 443-egress-blocked failure
    modes produce identical signals from this evidence; prior
    wording presumed only DNS. Functional behavior unchanged
    (both branches return 1).

[version]

  * VERSION: 4.3.6 -> 4.3.7

[release]

  * banner header: 4.3.7 (2026-04-25)




v4.3.6 - 2026-04-25
-------------------

  Hotfix. Post-install hook dispatcher restored. Single-file
  install path returns rc=0 again with its post-action actually
  invoked.

[fix]

  * _ry_install_file post-hook dispatcher: dropped redundant
    `post_` prefix from all 14 entries in the _post_hooks glob
    table. Dispatcher at L4742/L4747 is `_post_$_h`, so a value
    of `post_boot` resolved to `_post_post_boot` — a name that
    matches no defined function. Every single-file install of a
    managed config since v4.3.2 (when the table was introduced)
    has emitted `Internal: post-hook _post_post_X not defined`
    via the L4741 existence guard and returned rc=1, skipping
    its post-action: mkinitcpio rebuild, sdboot-manage refresh,
    daemon-reload + service enable, udev reload-rules + trigger
    + settle, NetworkManager restart, sysctl reload, resolved
    restart, coredump.socket reload, drirc/envd session-restart
    notice, and logind reboot notice. Now consistent with the
    `_ry_profile_$name` and `_content_$key` dispatchers, which
    have always used bare keys with the prefix in the dispatch
    line. Bulk install path (_ry_do_install) was never
    affected — it calls _ry_install_file directly without the
    glob table.

  * L4741 existence guard retained as defense-in-depth against
    future malformed table entries (its original v4.3.2 intent).

[version]

  * VERSION: 4.3.5 -> 4.3.6

[release]

  * banner header: 4.3.6 (2026-04-25)




  Hygiene release. Completes the comment-rendering fix line that
  began in v4.3.3. No runtime behavior change; fish parser was
  unaffected throughout. External contracts preserved.

[hygiene]

  * comments: 30 paired-quote spans inside fish line-comments
    rewritten to bare prose. v4.3.3 replaced 19 paired backticks
    with single quotes to dodge the fish-tmbundle
    string.interpolated.backtick.fish trap, but the same grammar
    opens string.quoted.single scope on paired apostrophes inside
    comment.line.fish, reproducing the identical
    highlighting-poison cascade with a different delimiter. v4.3.5
    strips both single- and double-quote pairs from every comment;
    inline references like 'fish -c', 'set -l', "rebind", and
    "Unknown function" are now bare. Help-text echo string at
    L1681 retains its single backtick pair (string scope sandboxes
    it correctly).

  * comments: one five-line @@AUDIT@@ rationale block in
    _content__etc_systemd_system_cpupower-epp.service collapsed to
    a single line.

[version]

  * version: 4.3.4 -> 4.3.5. Header date stamp resynced.


v4.3.4 - 2026-04-25
-------------------

  Install-affecting fix exposed during a v4.3.3 follow-up cleanup,
  plus apostrophe and double-quote analogs of the v4.3.3
  paired-backtick comment sweep.

[fixes]

  * _content__etc_systemd_system_cpupower-epp.service: fix
    premature termination of the multi-line single-quoted printf
    body. Unescaped apostrophe pair around the OR-fallback token
    in the L1211 @@AUDIT@@ v4.3.2 comment closed the printf string
    early; printf rc=0, OR short-circuited, error never surfaced.
    v4.3.0 through v4.3.3 installed a 12-line cpupower-epp.service
    missing StandardError, ExecStart, and the [Install] section;
    systemctl start would have failed with Unit-has-no-ExecStart
    but the install run never observed it. Generator rewritten as
    per-line printf args. Hosts that ran v4.3.0-v4.3.3 should
    reinstall or verify
    /etc/systemd/system/cpupower-epp.service is 17 lines and
    contains ExecStart= and [Install].

[hygiene]

  * comments: 13 contractions and several stray apostrophe / quote
    sites inside fish line-comments rewritten. Apostrophe analog
    of the v4.3.3 paired-backtick fix. Note: superseded by the
    exhaustive v4.3.5 sweep.


v4.3.3 - 2026-04-25
-------------------

  Maintenance release. One install-blocker fix, three robustness
  guards, one defensive arity check, and a project-wide rewrite
  of paired backticks in fish comments that confused the
  fish-tmbundle grammar into entering string scope mid-comment.

[fixes]

  * _ry_validate_configs: drop trailing dash arg from fish
    --no-execute invocation. Fish does not special-case dash as
    stdin (GH #1039 open since 2013); previous form returned
    rc=127, causing every install to abort at preflight before
    the package phase.

[robustness]

  * _install_preflight: command prefix on kill/sudo/sleep inside
    the sudo keepalive fish -c subshell.
  * _chk_perms / _verify_runtime_session: stat-fail guards.
  * _as: arity guard; empty-argv calls now return rc=2 and log BUG.

[hygiene]

  * comments: 19 paired backticks in fish comments replaced with
    single quotes. Fish runtime parser was unaffected; rendering
    fix only. Note: single-quote replacement reintroduced the same
    class of bug under the apostrophe rule and was finished off in
    v4.3.5.


v4.3.2 - 2026-04-25
-------------------

  Audit follow-up. Ten findings from the v4.3.1 line-by-line audit
  addressed; changes marked @@AUDIT@@ v4.3.2 inline. Highlights:
  _cleanup_on_exit consults $_RY_INSTALL_LAST_EXIT for early-fail
  footer; sudo-probe stderr redirects unified; _post_$hook
  existence guard before dispatch; cpupower-epp drops |logger
  fallback in favor of StandardError=journal; _acquire_lock
  requires both flock(1) and /bin/sh; _ry_do_check uses whole-word
  regex for KERNEL_PARAMS in /proc/cmdline; _log drops redundant
  set -l on event/data sanitize lines.


v4.3.1 - 2026-04-25
-------------------

  Audit-driven cleanup. Eighteen v4.3.0 findings addressed plus a
  simplification pass adding four verifier helpers (_chk_eq,
  _chk_sysfs_eq, _chk_perms, _chk_present) and trimming inline
  rationale. _atomic_write_file untracks tmpfile after mv so the
  cleanup loop stops stat()-ing dead paths. _post_boot END writes
  moved to _ry_do_install_file via single-exit refactor. _grep_kv
  escapes $key via string escape --style=regex before
  interpolation. Output byte-identical for verify-static and
  verify-runtime modes.


v4.3.0 - 2026-04-25
-------------------

  Decomposition release. Four large-function splits scoped in
  v4.2.0 completed: _install_configure_services 155L->13L+3
  helpers; _ry_verify_static 427L->31L+7 section helpers;
  _ry_verify_runtime 818L->30L+4 section helpers;
  _ry_profile_gtr9_pro 192L->14L+8 inline helpers. Output
  byte-identical to v4.2.1 on the gtr9_pro profile.


v4.2.1 - 2026-04-25
-------------------

  Targeted hardening. _json_str escape pass extended to {\\, ", \n,
  \r, \t} plus C0/DEL strip. _ry_check_kernel_version soft-warns
  for [6.14, 6.18.4); 6.18.4 documented as gfx1151 stability floor.
  _validate_profile rejects empty-string scalar globals for 10
  required globals. _should_skip_iwd glob tightened to
  */NetworkManager/*nm.conf. _is_wifi_active_route detects
  tun/tap/wg/ppp/gre/sit/ip6tnl/ipip default-route ifaces.


v4.2.0 - 2026-04-23
-------------------

  Profile system release. Profile loader extracted from script
  body; gtr9_pro profile data isolated from install logic.
  Manifest format introduced for verify-static checksum
  comparisons. New flags: --verify-static, --verify-runtime,
  --check (silent idempotency probe).


v4.1.x - 2026-04-19 to 2026-04-22 (rollup)
------------------------------------------

  Fifteen patch releases. Highlights: JSONL log schema stabilized;
  _run timeout enforcement via timeout(1); progress bar via
  DECSTBM scroll region; lock file with flock(1); signal handlers
  for SIGINT/TERM/HUP/PIPE; sudo keepalive subshell; atomic file
  writes via mktemp + sudo mv with --reference. Several
  cpupower-epp.service iterations leading to the v4.3.4-discovered
  printf-truncation bug.


v4.0.x - 2026-04-18 to 2026-04-19
---------------------------------

  Initial fish rewrite from the v3.x bash original. Single-file
  architecture with embedded config generators (no /usr/share data
  files). Manifest-driven install loop replacing per-file shell
  blocks. argparse-based CLI with --help, --version, --verbose,
  --install-file flags.


v3.51.x - 2026-04-13 to 2026-04-17
----------------------------------

  Late-bash hardening. Manifest format finalized to count+sha256
  separated by space. Embedded-content hashing centralized.


v3.50.x and earlier - through 2026-04-13
----------------------------------------

  Bash-era development. Per-file shell blocks; ad-hoc verification;
  no manifest. Superseded by the v4.0 fish rewrite.
