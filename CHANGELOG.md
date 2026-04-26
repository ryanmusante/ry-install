ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first,
entries grouped under a dated heading, each bullet names the
subsystem or function before the change description.


v4.4.7 - 2026-04-26
-------------------

  Size and clarity pass. SHA256 dropped from the verify and
  install paths in favor of direct byte comparison; comment
  density reduced. No managed-file content changes; no
  user-visible behavior change; verify-static remains stable.

[change]

  * Verify-static / install-file skip-probe (`_content_bytes`,
    `_installed_bytes`): replaces the prior SHA256 hash pair
    (`_content_hash` and `_hash_installed`) with byte-wise
    capture and `test "$expected" = "$actual"` equality. The
    files compared are at most a few KB; a cryptographic digest
    was overkill for an equality test on small text and
    introduced its own pitfalls (empty-stdin canonical hash
    collision, pipestatus capture across two pipe stages, the
    extra `string split ' '` field extraction). The new path
    has fewer failure modes and removes ~50 lines of helper
    code plus one inline duplicate in `_install_file`.

  * SHA256 retained at exactly two sites and one dependency
    probe: `_install_rebuild_boot` and `_install_finalize`
    fingerprint the set of `/boot/loader/entries/*.conf`
    basenames so the boot-wipe acknowledgement marker can
    detect set-equality across runs. That use is legitimate
    (compact, stable identifier for a multi-element set) and
    is unchanged.

[style]

  * Removed approximately 175 standalone narration comments
    that paraphrased an immediately-following code line without
    adding load-bearing rationale. Preserved: the script header,
    every `# lint:ignore` marker, `INVARIANT:` / `SECURITY:` /
    `MAINTENANCE:` annotations, section dividers, validator
    phase labels, generator preconditions, race-window and
    cleanup-protocol explanations, fish-specific idioms (e.g.
    bare `set` re-binding outer scope inside `if`/`else`), and
    the rationale for any non-obvious sudo / awk / find / sort
    invocation.

  * Trimmed nine excess blank lines (consecutive blanks inside
    function bodies; blank line immediately after a `function
    ... --description` header; blank line immediately before a
    closing `end`).

[size]

  * 5275 → 5060 lines (-215, -4.1 percent). Function count and
  public surface unchanged.

v4.4.6 - 2026-04-26
-------------------

  Hardening pass on profile validation, hash-comparison, and
  preflight gating; one schema addition to the JSONL footer
  (`gen_fail` counter); profile-resolution order changed to
  prefer file-based profiles over built-ins. No managed-file
  content changes; verify-static remains stable across upgrade.

[fix]

  * `_validate_profile` (L878): glob metacharacters (`*` `?`
    `[` `]` `{` `}`) added to the rejected-character class for
    `KERNEL_PARAMS`, `MKINITCPIO_MODULES`, and `MKINITCPIO_HOOKS`.
    Prior class blocked shell metachars (whitespace, quotes,
    redirect, semicolon, ampersand, pipe, paren, backslash,
    backtick) but not glob metachars. Three downstream sites
    (`_chk_sdboot_param`, `_chk_kernel_cmdline_param`, runtime
    `/proc/cmdline` check) ran the captured element through
    `string match -q -- "* $param *"` — a literal `*` in any
    such element matched any non-empty cmdline and falsely
    reported every parameter as present.

  * `_validate_profile` (L887): control-character rejection
    extended to cover the destination lists. Previously only
    `ENV_VARS`, `SYSCTL_VALUES`, `LOGIND_IGNORE_KEYS`, and
    `IWD_DRIVER_QUIRKS` rejected NUL/LF/CR; now `SYSTEM_DESTINATIONS`,
    `USER_DESTINATIONS`, and `SERVICE_DESTINATIONS` are checked
    too. `_manifest_write` emits one path per `printf '%s\n'`,
    so an embedded LF would corrupt the line/profile/destinations
    framing read back by `_manifest_check_orphans`.

  * `_validate_profile` (new, two checks): `ENV_VARS` elements
    now required to match `^[A-Za-z_][A-Za-z0-9_]*=`; malformed
    entries (e.g. `MESA_DEBUG` without `=`) previously passed
    validation and were emitted verbatim into
    `~/.config/environment.d/10-environment.conf`, where
    `systemd-environment-d-generator` silently dropped them.
    `SYSCTL_VALUES` elements now required to match
    `^[A-Za-z][A-Za-z0-9._-]*=\S`; entries without `=` previously
    produced lines like `key = ` (empty value) that `sysctl
    --system` rejects on apply.

  * `_hash_installed` (L1361): rewritten to use the same
    `pipestatus`-checked pattern as `_content_hash`. The old
    `(sudo -n cat | sha256sum)` capture did not distinguish a
    failed `sudo -n cat` (cache lapse mid-run) from successful
    empty input. On lapse, sha256sum hashed empty stdin and
    returned `e3b0c44…`, the canonical empty-input digest, which
    `test -n "$_raw"` could not catch — `_ry_do_check` and
    `_verify_static_checksum` then reported drift on a perfectly
    consistent file. Now returns empty (read-fail signal) when
    either pipe stage exits non-zero.

  * `_acquire_lock` (L346): pid file written via `mktemp` inside
    the just-created `LOCK_DIR` and atomically renamed into
    place. The previous `printf '%s\n' $fish_pid > "$LOCK_FILE"`
    was non-atomic; a crash or disk-full between `mkdir` and the
    `printf` could leave a 0-byte pid file on disk. The flock-based
    stale-lock reclaim path was already tolerant of this, but the
    write is now correct in its own right.

  * `_install_preflight` (L3848): sudoers scan now also rejects
    per-line `Defaults requiretty`, `Defaults tty_tickets`, and
    `Defaults timestamp_timeout=0`. The keepalive child relies
    on a non-tty `sudo -n -v` succeeding against a live sudo
    timestamp; any of these three Defaults breaks that contract
    and would surface as silent keepalive death rather than a
    diagnostic at preflight.

  * `_check_env_ssh_auth_sock` (L1212): adds a systemd version
    check for the embedded `${XDG_RUNTIME_DIR}` reference in
    `~/.config/environment.d/10-environment.conf`. Variable
    expansion in `environment.d` requires systemd ≥ 232; older
    hosts (stripped chroots, very old containers) get a clear
    warning rather than a silent unexpanded literal in the
    SSH_AUTH_SOCK path.

  * Boot/runtime `/proc/cmdline` check (L3018): falls back to
    `sudo -n cat` when the unprivileged read returns empty.
    AppArmor profiles with `kernel.dmesg_restrict=1` plus
    `kptr_restrict=2` sometimes also restrict `/proc/cmdline`;
    the fallback removes the false-negative on those hosts.

  * Three `string match` sites (L2480, L2497, L3019): switched
    from glob match `"* $param *"` to regex match
    `"(^|\s)$_param_re(\s|\$)"` with `string escape --style=regex`
    on the parameter. Defends against future profile elements
    that contain `*` or other glob metachars even if the L878
    sanitizer were ever loosened, and matches the idiom already
    used at `_ry_do_check` L2935.

  * `_chk_grep`: docstring corrected to reflect substring-match
    semantics (`grep -qF`); no behavior change. The matcher is
    now consistent with the regex-bounded sites above.

  * `_kill_sudo_keepalive` background spawn (L3878): keepalive
    `fish -c` child now redirects stdout and stderr to
    `/dev/null` in addition to stdin. Prevents spurious child
    output from leaking past the parent's log redirection.

  * `awk` invocations (L3580, L3585, L3857, L3860, L4095, L4119):
    every `awk` callsite now invokes `command awk` to bypass
    autoloaded user-defined `awk` functions in
    `~/.config/fish/functions/`. Pure defense-in-depth; matches
    the discipline already applied to `command rm`, `command
    cat`, `command find`, `command head`.

[change]

  * Profile resolution order (`_load_profile`, L989): a file at
    `~/.config/ry-install/profiles/<n>.fish` now takes precedence
    over a built-in `_ry_profile_<n>` of the same name. Earlier
    releases had the reverse: a same-named file was silently
    shadowed. The override path erases the built-in function
    before sourcing the file and emits a `PROFILE_OVERRIDE` line
    to the JSONL log so the active source is auditable.
    Documented user-override path now actually works.

  * JSONL header `argv` (L5102): `command` field replaced with
    `argv` as a JSON array. The old form joined `(status filename)`
    with positional args via `string join " "`, losing argument
    boundaries for paths that contain whitespace (e.g.
    `--install-file '/path with space'`). The new form preserves
    every boundary and parses cleanly with `jq -r '.argv[]'`.

  * JSONL footer schema: `gen_fail` counter added. Counts
    destinations whose embedded-content generator returned an
    empty string during `--verify-static`, distinct from
    `read-fail` and `mismatch`. Distinguishes "config drifted"
    from "generator broken" in dashboards. Field is always
    present; value is `0` when no generators failed.

[preflight]

  * Two new gates run between the Fish version check and any
    privileged action. Both fail with `EXIT_PREFLIGHT (3)` and
    a single-line error to stderr.

  * Writable working tmp directory: probes `${TMPDIR:-/tmp}` with
    `test -w`. Removes a class of late, confusing failures where
    `mktemp` calls inside `_run`, `_atomic_write`, sudo-error
    capture, and unit verification all failed mid-install with
    distinct messages. Now a single early diagnostic.

  * GNU `coreutils` sort with `-z`: probes `printf '' | command
    sort -z </dev/null`. Boot-wipe basename hashing
    (`SDBOOT_REMOVE_EXISTING=yes` gate) and log rotation both
    require NUL-delimited sort to be safe across paths with
    whitespace. busybox/BSD sort produce unsorted output for
    `-z` without erroring, which silently broke both flows on
    non-GNU bases.

[security]

  * `_run` log redaction (L1626): tmp paths matching
    `/tmp/ry-[A-Za-z0-9_.-]+` are now replaced with
    `/tmp/ry-[REDACTED]` before the command line is logged.
    Prevents `$TMPDIR` location and per-run randomness from
    bleeding into `~/ry-install/logs/`.

[style]

  * Removed every `# @@AUDIT@@ vX.Y.Z: …` change-history comment
    from the source (39 occurrences). Two of them (L1245-1246
    inside `_content__etc_systemd_system_cpupower-epp.service`)
    were positional arguments to `printf` and were therefore
    being emitted into the deployed unit body. The remaining 37
    were source-only and pure noise once the change history is
    in this file. Substantive comments at those lines are
    preserved or rewritten to drop the version prefix.

  * Multi-line comment runs collapsed to single lines except
    where adjacent to a `# lint:ignore` marker (which has to
    stay on its own line by tooling convention).

v4.4.5 - 2026-04-26
-------------------

  Audit-driven cleanup pass: one MED, three LOW, one INFO finding
  closed. No behavior change on the supported CachyOS profile;
  no managed-file content changes; verify-static remains stable
  across upgrade.

[fix]

  * Log rotation (L5129): replaced the `find -printf '%T@ %p\n' |
    sort -n | head -n -$MAX_LOGS | cut -d' ' -f2- | xargs -r rm -f`
    pipeline with a NUL-framed fish-native rotation. Old pipeline
    was newline-framed and `cut -d' '` plus `xargs` re-split paths
    on whitespace — any space anywhere in `$HOME` (and therefore
    `_log_base_rot=$HOME/ry-install/logs`) silently mis-parsed
    rotation candidates. Replacement uses `find -printf '%T@\t%p\0'`
    + `LC_ALL=C sort -zn` + `string split0`, then iterates with
    `string split -m 1 \t` to extract the path. Also drops the
    `head -n -N` GNU-coreutils-only dependency. Smoke-tested
    against 8 logs with one space-bearing filename: drops the
    oldest 5, keeps the 3 newest, including the space-bearing
    name when it falls within the keep window.

  * `_run` / `_ensure_sudo_cached` (L1306, L1681, L1682, L1685):
    four `command head -n N "$file"` callsites missing the `--`
    end-of-options separator. Inconsistent with the L939 sibling
    which already used it. No exploit path today (`mktemp` names
    are always `.ry-install.*` or `ry-*.XXXXXX`), pure convention
    drift; now uniformly `command head -n N -- "$file"` across
    all five callsites.

  * `_load_profile` (L1049-1060): two profile-overridable timing
    globals — `SUDO_KEEPALIVE_INTERVAL` (default 45) and
    `NM_RESTART_DELAY` (default 3) — were consumed by `sleep(1)`
    and the keepalive loop without any input validation. A profile
    that set either to a non-positive-integer (negative, zero,
    decimal, or non-numeric) would propagate junk into `sleep`
    and the keepalive `fish -c` invocation, producing silent
    hangs or fail-fast loops with no diagnostic. Both globals are
    now validated via the same `string match -qr '^[1-9][0-9]*$'`
    idiom already applied to `MAX_LOGS` at the log-rotation site;
    invalid values warn, log `PROFILE_INVALID_*`, and reset to
    documented defaults.

[style]

  * Function descriptions: 20 functions previously defined without
    `--description` now carry one-line descriptions for `functions`
    builtin introspection and completion display. Affected: 16
    `_content_*` embedded-content builders (L1118-1253, every
    managed destination from `/boot/loader/loader.conf` through
    `/etc/sysctl.d/99-cachyos-sysctl.conf`) plus the four-function
    `_progress*` family (L1564, L1577, L1588, L1598). Brings
    coverage to 141/141 functions documented.

[meta]

  * VERSION: bumped 4.4.4 → 4.4.5 in shebang header (L2),
    VERSION global (L20), and README badge.
  * Verification: `fish --no-execute ry-install.fish` exit 0
    across the full 5183-line file post-patch.
  * Audit reference: findings F1 (MED, log rotation), F2 (LOW,
    head separator), F3+F4 (LOW, function descriptions), and F5
    (INFO, timing-globals validation) closed in this release.
    F6 (INFO, `_hash_installed` return contract) reviewed and
    dismissed — the existing `--description` string already
    documents `"empty on read failure; sudo-aware"` and both
    callers (verify-static at L2834 and check at L2900) rely on
    the documented empty-string sentinel rather than the return
    code, so any change would be cosmetic.


v4.4.4 - 2026-04-25
-------------------

  Hardening pass: nine fixes across robustness, error propagation,
  and comment-vs-code drift. No managed-file content changes;
  verify-static remains stable across upgrade.

[fix]

  * `_atomic_write_file` (L2270): comment claimed pipeline ended with
    `→hash→mv→verify→chown`. No `hash`, no post-mv `verify`, and no
    `chown` step exists — the function ends at atomic `mv`. Comment
    realigned to actual pipeline: `dir-trust → mktemp →
    symlink-check → write → symlink-recheck → chmod → sudo-recheck
    → mv`.

  * `_acquire_lock` (L388): non-atomic stale-lock reclaim fallback
    (rmdir+mkdir+sleep 0.1) deleted. flock(1) ships in util-linux,
    which is part of the Arch base group and always present on
    CachyOS — its absence indicates a broken environment, not a
    legitimate config. Missing flock now hard-fails with an
    actionable `pacman -S util-linux` hint instead of attempting a
    reclaim that loses the race window during double-yield.

  * `_ensure_sudo_cached` (L1285): bare `sudo -v` interactive
    fallback after `sudo -n -v` miss could hang indefinitely under
    cron, CI, or sourced startup contexts. Gated on
    `isatty 0; and isatty 2` — non-interactive callers now log
    `SUDO_CACHE_NONINTERACTIVE` and return failure cleanly instead
    of blocking on an unread tty prompt.

  * `_ry_check_disk_space` (L1900, L1920): `df -B1 / | tail -n 1
    | awk '{print $4}'` is brittle on long device source paths
    where df wraps output across two lines and `$4` becomes an
    unrelated column. Replaced both / and /boot probes with
    `df --output=avail -B1 ...` single-column form, dropping the
    awk dependency entirely. `string trim --` strips the column
    header.

  * `_post_service` (L4844): system-scope `systemctl enable --now`
    failures emitted a `_warn` but the function unconditionally
    returned 0, so `--install-file <some-unit>.service` exited
    success even when the unit failed to enable. Both user and
    system branches now propagate `return 1` on enable failure
    while preserving the warn-level message — `_ry_do_install_file`
    surfaces this in its dispatcher exit code.

  * Log rotation (L5128): `head -n -$MAX_LOGS` with `MAX_LOGS=0`
    outputs every line, feeding every log file to `xargs rm -f`
    and wiping the entire archive. While the global is set to 50
    in pre-bootstrap and not exposed to env override, defense-in-
    depth guard now validates `MAX_LOGS` matches `^[1-9][0-9]*$`
    before the find pipeline; invalid values reset to 50.

  * argparse stderr capture (L4947): on `mktemp` failure for
    `_ap_errfile`, the fish-specific argparse error message was
    silently dropped to /dev/null and only the generic
    `Invalid arguments: $_ORIG_ARGV` reached the user. Fallback
    now reuses `$LOG_FILE` (already created in pre-bootstrap and
    empty at this point in the flow) so the argparse message is
    preserved in the JSONL log. Both rm-cleanup sites guarded so
    the LOG_FILE is never deleted when used as fallback.

  * `_install_fstab_opts` (L4048): function rewrote `/etc/fstab`
    via tmpfile-then-mv without checking whether the target was a
    symlink. On systems that intentionally symlink `/etc/fstab`
    (rare but legal — e.g., dotfile-managed configs), the
    atomic mv would replace the symlink with a regular file,
    silently breaking the indirection. Now mirrors the
    `_atomic_write_file` symlink invariant: refuses to rewrite
    when `test -L /etc/fstab` is true and emits an actionable
    `_fail` message.

  * `--install-file` canonicalization (L5035): `realpath -m`
    failure caused the script to silently fall back to the literal
    `_if_val`, which means managed-file validation might match a
    different physical path than what the user supplied (or fail
    entirely). The fallback path now emits an explicit `[WARN]`
    so the substitution is visible.

[meta]

  * VERSION: bumped 4.4.3 → 4.4.4 in shebang header (L2),
    VERSION global (L20), README badge, and JSONL header sample.
  * Comments: nine new fix-site comments collapsed to single lines
    matching the v4.4.3 line-length rule (≤120 chars). Three
    pre-existing multi-line comment blocks (df-precision rationale,
    argparse stderr capture preamble, log-rotation C.21 marker)
    folded into single lines that retain both historical context
    and the new note.
  * Verification: `fish --no-execute ry-install.fish` exit 0 across
    the full 5169-line file post-patch.


v4.4.3 - 2026-04-25
-------------------

  Comment-style cleanup pass. No behavior change; no managed-file
  content changes; verify-static remains stable across upgrade.

[style]

  * comments: 11 single-line comments that exceeded 120 chars
    after the v4.4.2 multi-line collapse have been trimmed by
    dropping non-essential context (parenthetical asides,
    historical clauses, repeated rationale already present in
    this CHANGELOG). Operational essence preserved on every line.
    Affected: pre-bootstrap rationale (L70), `_acquire_lock`
    dead-code removal note (L415), `_load_profile` element
    sanitization (L899), `_load_profile` UUID branch (L1038),
    `_untrack_tmpfile` extraction note (L1338), `_install_preflight`
    sudo-cache note (L3847), `_ry_do_install_file` sudo-cache
    note (L4764), CLI parser preamble (L4939), early-exit
    cleanup invariants (L4968 and L4984), and the sourced-return
    branch (L5150).

  * inline comments: project-wide audit confirms zero remaining
    inline comments outside string literals (the v4.3.8 above-
    line migration plus the v4.4.2 multi-line collapse covered
    every reachable site). Five `# lint:ignore` markers inside
    `/bin/sh -c` string literals at the lock-reclaim site stay
    in place per construction — they are sh-script comments
    being passed verbatim to the embedded interpreter, not fish
    comments.

  * comment line-length: comment lines now fit within 120 chars
    project-wide. Verified via parser-aware Python pass:
    zero comment lines exceed the limit. Multi-line comment
    blocks reduced to 4 (script header L1-2 plus three blocks
    where the second line is a `lint:ignore` adjacency, all
    preserved per project comment-style rule).

[version]

  * VERSION: 4.4.2 -> 4.4.3
  * banner header: 4.4.3 (2026-04-25)


v4.4.2 - 2026-04-25
-------------------

  Two correctness fixes and a comment-style cleanup pass. No
  managed-file content changes; verify-static remains stable
  across upgrade.

[fix]

  * _load_profile / root UUID validation: tighten regex from
    `^[0-9a-fA-F-]+$` to canonical 8-4-4-4-12 form
    `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`.
    The prior pattern accepted strings like `----` or bare hex,
    which would have cached an invalid UUID and produced a
    malformed `/etc/kernel/cmdline` if findmnt ever returned
    corrupt output. CachyOS targets ext4 root, which always
    yields a canonical UUID; the strict shape now matches the
    prerequisite. Location: L1037 (_load_profile body).

  * --check / preflight stderr leak: `--check` is documented as
    a "silent idempotency probe" but the `_err` call on missing
    root UUID emitted `[ERR] Cannot detect root UUID...` to
    stderr before exiting EXIT_PREFLIGHT (3). Help text and
    behavior now agree: `--check` routes the failure through
    `_log` and exits silently with rc=3; install / install-file
    / verify-static / verify-runtime continue to emit the `[ERR]`
    line as before. Catch-all for other modes unchanged.
    Location: L1043-1058 (_load_profile UUID branch).

[style]

  * comments: seven multi-line comment blocks collapsed to single
    line each. Affected blocks were rationale paragraphs in
    pre-bootstrap (L70-71), `_load_profile` element sanitization
    (L900-903), `_untrack_tmpfile` introduction (L1342-1344), CLI
    parser preamble (L4945-4946), early-exit cleanup invariants
    (L4975-4977 and L4993-4995), and the sourced-return cleanup
    branch (L5161-5162). Script header (L1-2) and three
    `lint:ignore` adjacency blocks (L1905, L3819, L4052)
    preserved per project comment-style rule. Total LOC change:
    5166 -> 5158.

[version]

  * VERSION: 4.4.1 -> 4.4.2
  * banner header: 4.4.2 (2026-04-25)


v4.4.1 - 2026-04-26
-------------------

  Point release. One UX defect closed; six defensive-consistency
  fixes; no behavior change for the install, verify-static,
  verify-runtime, check, or install-file modes on unattended
  runs. No managed-file content changes; verify-static remains
  stable across upgrade.

[fix]

  * cli / root-check ordering: `--help`, `-h`, `--version`, `-v`
    were refused with EXIT_USAGE (2) when the script was invoked
    as root because the `id -u == 0` gate ran before argparse.
    Help and version are informational and must succeed for any
    user. The root-check block was relocated past the `--help` /
    `--version` short-circuits in the dispatch section, with
    explicit `rm -f -- "$LOG_FILE"` so the pre-allocated log is
    cleaned for refused-root invocations too.

  * cli / scaffolding cleanup invariant: every refused-or-
    informational early-exit path that already removed
    `$LOG_FILE` now also runs `command rmdir -p -- "$LOG_DIR"
    2>/dev/null` so the empty log subdir + ancestors that became
    empty are removed. Restores the pre-patch property that root
    invocations leave no trace and extends it to argparse-
    failure, positional-argument rejection, `--install-file`
    path-validation failure (`_early_usage_exit`), and the
    `--help` / `--version` success handlers (these had also been
    leaking empty scaffolding for non-root users since v4.4.0).
    Verified across 38 invocation cases x 2 user contexts: every
    early-exit path now produces zero on-disk artifacts. Mode-
    dispatch paths (install/verify/check) still write logs as
    designed.

  * _untrack_tmpfile / cleanup invariant: `_TRACKED_TMPFILES`
    filter unified across six call sites. Replaced inline
    `set -g _TRACKED_TMPFILES (string match -v -- "$path" ...)`
    with explicit-loop literal-equality compare, extracted into
    a single `_untrack_tmpfile` helper. Routed `_manifest_write`,
    both `_ensure_sudo_cached` paths, `_verify_unit_content`,
    `_atomic_write_file`, and `_install_fstab_opts` through it.
    Real-world risk was zero (mktemp suffixes are alphanumeric)
    but the invariant is now enforced from one place.

  * _atomic_write_file dead branch: the content-generator
    error-code `switch` had a `case 13` arm referring to
    "Internal bug in `_ry_get_file_content` arity check", but no
    path in the script returns 13 — `_ry_get_file_content`
    returns 11 on missing generator and
    `_content__etc_kernel_cmdline` returns 12 on missing
    `_ROOT_UUID`. Removed the unreachable arm; the `case '*'`
    catch-all handles any future return code with the underlying
    rc surfaced verbatim.

  * _verify_static_packages / pacman.conf parser: the
    `ParallelDownloads` grep used `^ParallelDownloads` without
    an anchor on the right edge, so a hypothetical
    `ParallelDownloadsX` directive would have produced a false
    positive. Tightened to `^ParallelDownloads[[:space:]]*=` via
    `grep -nE`. Theoretical only — pacman.conf has a fixed key
    set — but the regex now matches the directive shape.

  * dispatch / drift warning: removed the brittle "near line
    153" line-number reference from the `_RY_MANAGED_FILE_COUNT`
    drift warning; the constant lives on a moving line and the
    message now points to "the bootstrap globals block" instead.

  * _validate_profile / config-value sanitization: the existing
    element-sanitization loop covered `KERNEL_PARAMS`,
    `MKINITCPIO_MODULES`, `MKINITCPIO_HOOKS` against shell
    metacharacters (defense-in-depth even though no shell-eval
    path exists for them). Added a second, narrower loop for
    `ENV_VARS`, `SYSCTL_VALUES`, `LOGIND_IGNORE_KEYS`,
    `IWD_DRIVER_QUIRKS` that rejects only NUL/LF/CR — these
    globals legitimately contain spaces (sysctl multi-value
    `tcp_rmem=4096 87380 134217728`), `=` (env vars), and `*`
    (iwd glob quirks like `PowerSaveDisable=*`), but a stray
    newline in any element would split the rendered config and
    silently change semantics. Profile is user-controlled so
    this is invariant enforcement, not a security boundary.

[refactor]

  * _untrack_tmpfile helper introduced next to `_tmpfile_key` in
    the helpers section. Six call-site bodies shrink to one line
    each. No semantic change.

[verification]

  * fish --no-execute on the patched file: clean.

  * Behavior matrix re-checked across 38 invocation forms x 2
    user contexts (root + non-root) plus 8 sourced cases. Every
    refused or informational early-exit path produces rc per
    spec AND zero on-disk artifacts. Mode-dispatch paths
    (install/verify/check) log normally to
    `~/ry-install/logs/YYYY-MM-DD/MODE-*.jsonl`. Sourced contexts
    preserve the host shell across all tested failure modes.
    Profile sanitization regex `[\x00\x0a\x0d]` accepts every
    legitimate value in the active profile (env vars with paths,
    sysctl multi-value tunables, iwd glob quirks, logind key
    identifiers) and correctly rejects single-element embedded
    LF.


v4.4.0 - 2026-04-25
-------------------

  Cleanup-invariant release. Two cleanup-invariant defects
  closed, two diagnostic and trust-model gaps closed, two
  correctness fixes, and one drift assertion. Same root cause
  for both cleanup-invariant defects: the resource-cleanup
  function (`_do_cleanup`) was reachable only from signal-
  handler paths (SIGINT/SIGTERM/SIGHUP/SIGQUIT/SIGPIPE), never
  from normal exit, sourced return, or early bail. Symptom:
  every run of v4.3.x and earlier left `~/ry-install/.lock/` on
  disk, forcing the stale-reclaim path on the next invocation.
  No managed-file content changes; verify-static remains stable
  across upgrade.

[fix]

  * _teardown / _cleanup_on_exit cleanup invariant: `_do_cleanup`
    is now called from the `case exit` arm of `_teardown`, so
    the fish_exit handler (`_cleanup_on_exit`) releases LOCK_DIR,
    removes tracked tmpfiles, and terminates the sudo-keepalive
    child on every normal exit. Previously the `case exit` arm
    wrote the JSONL footer and returned without calling
    `_do_cleanup`, so LOCK_DIR was retained until either the
    host fish process exited or a subsequent run hit the stale-
    reclaim path. Affected all four primary modes (install,
    install-file, verify-static, verify-runtime) plus --check.

  * end-of-script sourced-return path cleanup: the sourced
    branch that runs when `_RY_INSTALL_SOURCED=true` now calls
    `_do_cleanup` before erasing the signal/exit handlers,
    instead of jumping straight to `_ry_namespace_cleanup`
    (which only erases globals). Symptom for sourced workflows:
    lock leaked on every successful run; the user had to
    `rm -rf ~/ry-install/.lock/` between sessions. fish_exit
    does not fire on `return` from a sourced script, so this
    could not be picked up by the exit handler.

  * _ry_exit early-bail cleanup: `_ry_exit` (the source-safe
    exit helper used by 25 preflight/usage rejection sites) now
    invokes `_do_cleanup` between the handler-erase and
    `_ry_namespace_cleanup` calls, guarded by
    `functions -q _do_cleanup` so calls before the function is
    defined (during early bootstrap, e.g. fish-version gate,
    HOME resolution, LOG_DIR creation) silently skip cleanup
    where there is nothing to clean. After the function is
    defined, every `_ry_exit` call releases resources
    idempotently.

  * argparse stderr capture: argparse output is now captured to
    a tracked tempfile and forwarded into the `[ERR]` line
    emitted on parse failure, replacing the previous generic
    "Invalid arguments: $_ORIG_ARGV" message. Users now see
    fish's specific diagnostic (`--bogus: unknown option`,
    `check verify-static: options cannot be used together`,
    `Option '--install-file' requires an argument`) before the
    help text. The previous behavior swallowed argparse's stderr
    via `2>/dev/null`. The capture file is added to
    `_TRACKED_TMPFILES` and explicitly removed on both success
    and failure paths.

  * profile ownership + mode check: external profile files at
    `~/.config/ry-install/profiles/<n>.fish` are now stat'd
    before `source`. The script refuses to load any profile not
    owned by the invoking UID, or any profile whose group/other
    mode digits have the write bit set (mode digit must match
    `[0145]`). The profile-name regex was already path-traversal-
    safe; this fix closes the gap where the README documented a
    trust model that the script did not enforce. Failure exits
    `EXIT_USAGE` (2) with the offending uid or mode named in the
    error.

  * _acquire_lock dead code: the redundant `verify_pid2` block
    in the stale-reclaim path was removed. Both `verify_pid` and
    `verify_pid2` reads were issued back-to-back with no time
    gap in the flock(1) branch (which had already atomically
    written our PID), and the fallback branch already performs a
    100 ms yield before the first read, leaving no semantic
    difference between the two adjacent reads. The "late writer"
    failure mode the second read claimed to detect cannot occur
    after the flock-protected write or the fallback yield.

  * _run tracked-tmpfile filter glob safety: `_TRACKED_TMPFILES`
    no longer uses `string match -v` (which interprets glob
    metacharacters in the pattern argument) to filter out a
    removed `_run_dir`. Replaced with an explicit for-loop using
    literal string equality. mktemp output is alphanumeric in
    practice so the original code was not exploitable, but a
    non-default `TMPDIR` containing a `*` or `?` would have
    caused the filter to either drop unrelated entries or fail
    to drop the intended one.

[diag]

  * managed-file count drift assertion: after `_load_profile`,
    the script now compares the active profile's
    `MANAGED_FILE_COUNT` against the hardcoded
    `_RY_MANAGED_FILE_COUNT` constant (used as a fallback in
    `_ry_show_help` before profile load) and emits a `[WARN]` if
    they differ. Catches the maintenance hazard where profile
    destinations are added or removed but the help-text fallback
    constant is not kept in sync.

  * comment style cleanup: 17 comment lines that ended in
    trailing " ..." truncation artifacts (legacy from an earlier
    mechanical line-shortening pass) have had the ellipsis
    stripped. The affected comments now end with the last
    meaningful word. Mid-line semantic ellipsis (notation like
    `begin...end`, `KEY=...`, `(ALL,...)`, systemd output format
    strings) is preserved. Header (L1-2) and `lint:ignore`
    directives are untouched. No code paths affected.

[deferred]

  * function length cap: 24 functions exceed the 50-LOC project
    rule, 9 exceed 100. Largest is `_verify_runtime_kparams` at
    242 LOC, followed by `_verify_runtime_session` (175),
    `_verify_runtime_env` (174), `_verify_runtime_services`
    (165), `_install_rebuild_boot` (136), `_validate_profile`
    (130). The verify-runtime family is mostly flat per-parameter
    or per-subsystem switch logic and would split cleanly along
    natural seams. Mechanical splitting risks regressions in the
    verify-mode counter wiring (VERIFY_OK/FAIL/WARN updates flow
    through `_msg`); deferred to a dedicated refactor with
    verify-mode regression coverage.

[verified]

  * fish --no-execute: clean (RC=0).
  * --version: returns `v4.4.0` as expected, exit 0.
  * --help: renders with v4.4.0 in header, all sections present,
    exit 0.
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
  * Cleanup invariant: three consecutive --check invocations
    followed by an --install-file invocation that acquires the
    lock then fails at preflight — LOCK_DIR absent on disk after
    every run.
  * Sourced execution: `source ry-install.fish --version` and
    `source ry-install.fish --bogus` both return into the host
    fish (exit 0 / exit 2) without killing it. After cleanup,
    only `_RY_INSTALL_LAST_EXIT` and `_RY_INSTALL_BAILING`
    remain in the host namespace — both intentionally preserved
    by `_ry_namespace_cleanup` for caller use.
  * Re-source: a second `source` after the first succeeds (no
    "already loaded" rejection), confirming `_RY_INSTALL_LOADED`
    is correctly erased on cleanup.
  * Total LOC change: 5085 -> 5124 (+39, all from the seven
    inline fixes plus one drift-warning line). Comment-trim pass
    changed 17 comment lines in place (no LOC delta).


v4.3.9 - 2026-04-25
-------------------

  Sudo-flow consistency release. One UX-blocking sudo-flow
  inconsistency closed: install-mode and install-file-mode now
  interactively prompt for sudo password when not pre-cached,
  matching the long-standing behavior of verify modes. No
  content-hash changes; verify-static remains stable across
  upgrade.

[fix]

  * _install_preflight + _ry_do_install_file sudo flow: replace
    bare `sudo -n true` (non-interactive only, no fallback)
    with `_ensure_sudo_cached` (probes `sudo -n -v` then falls
    back to interactive `sudo -v`). Symptom: a user running the
    script without first running `sudo -v` saw the leading
    "[INFO] Sudo password required for installation..." message
    followed by "[ERR] Sudo required for installation" and an
    immediate EXIT_PREFLIGHT (3), with NO opportunity to enter
    a password. Affected both unattended install (default mode)
    and `--install-file` for system-scope targets. The verify
    modes (`--verify-static`, `--verify-runtime`) already used
    `_ensure_sudo_cached` and behaved correctly. Fix unifies
    the pattern across all four privileged entry points. No new
    dependencies; no new exit codes. Verified:
    `fish --no-execute` clean; existing CLI flag matrix
    (`--help`/`-h`/`--version`/`-v`/`--check`/`--verify-static`/
    `--verify-runtime`/`--foo`/positional/exclusive-violation/
    `--install-file=`empty/relative/flag-as-arg) all return the
    same exit codes as v4.3.8.


v4.3.8 - 2026-04-25
-------------------

  One install-blocking defect closed (_ry_install_file user-dir
  mkdir failed under timeout(1) due to `command` builtin
  shadowing), one privilege scope reduction in fstab rewrite,
  two defense-in-depth hardening fixes (sysctl key regex,
  boot-wipe marker hash boundary), and one documentation
  strengthening for _run argv invariant. No content-hash
  changes; verify-static remains stable across upgrade.

[fix]

  * _ry_install_file user-dir mkdir: drop `command` prefix from
    `_run command mkdir -p -- "$dir"`. _run wraps argv with
    timeout(1), and timeout(1) cannot exec the `command`
    builtin (rc=127 "failed to run command 'command': No such
    file or directory"). Symptom on first install: user-dir
    deployments to non-existent paths
    (~/.config/environment.d, ~/.config/systemd/user) failed
    with "Cannot create directory" because mkdir was never
    invoked. Sudo branch was unaffected — sudo is a real binary.
    Root cause: undocumented assumption that `command` builtin
    would pass through timeout. Verified reproducer:
    `command timeout 5 command mkdir /tmp/x` -> rc=127. Fix:
    drop the `command` prefix; _run resolves argv[1] via PATH
    directly. Single-instance bug; no other `_run <builtin>`
    callers found.

[security]

  * _install_fstab_opts: drop sudo from awk side of the rewrite
    pipeline. /etc/fstab is 0644 root:root (world-readable per
    filesystem package); awk reads as user, only tee needs sudo
    to write into the sudo-mktemp'd /etc/.ry-install.fstab.*
    tmpfile. Reduces privilege scope by one process and halves
    sudo invocations on this hot path. No behavior change for
    fstab readability — same input, same output.

[defense]

  * _grep_sysctl_kv key regex: extend [a-zA-Z._0-9]+ to include
    `-`. Current SYSCTL_VALUES has no hyphenated keys, but
    sysctl(8) keys may legally contain hyphens; future-proof for
    profile additions or upstream kernel sysctl renames.

  * Boot-wipe marker hash: switch sha256sum input delimiter from
    LF to NUL at both writer and reader sites. BLS spec
    rare-but-valid filename-with-newline would have collapsed
    adjacent entries in the LF-joined hash input; NUL-delimited
    stream preserves boundaries. sha256sum is byte-stream,
    algorithm unchanged; hash format compatibility handled by
    the legacy-marker accept-once path already present. Twin
    update keeps writer/reader synchronized.

[doc]

  * _run header: strengthen INVARIANT comment to explicitly
    forbid fish/POSIX builtins as argv[1]. Documents the
    timeout(1)-cannot-dispatch-builtins constraint that produced
    the user-dir mkdir regression. Two-line block merged to
    single line per project comment style.

  * lint:ignore markers: add 7 missing markers on awk field-
    reference and PCRE backref sites that a fish static
    analyzer would otherwise flag. Two PCRE-backref `'$1'`
    sites in _run secret redaction, four `awk '{print $4}'` /
    `awk '{ print $4 }'` field-reference sites in
    _ry_check_disk_space, _verify_runtime_env fstab opts probe,
    and _install_fstab_opts opts probe, plus one
    `awk '$3 == "ext4"'` field-reference + boolean-operators
    site in _install_fstab_opts ext4-detection. Marker count:
    14 -> 21. No semantic change; convention parity with
    pre-existing markers in the same patterns.

  * test coverage: end-to-end execution suite verified on Linux
    sandbox (Ubuntu 24.04 + fish 3.7.0). 26 tests covering all
    --options, exit-code matrix, source-mode bail, NO_COLOR /
    TERM=dumb honoring, log-perm chain (0700/0600), JSONL
    parseability, and SIGINT mid-run footer interruption marker.
    All pass. CachyOS-specific paths (pacman, mkinitcpio,
    sdboot-manage, real boot artifacts) require host execution.

[style]

  * lint:ignore marker convention: relocate inline markers to
    above-line position (16 of 21 markers moved; 5 inside
    string literals stay in-place per construction). Aligns
    with the industry standard (shellcheck, clippy, mypy
    noqa-block). Future contributors: place
    `# lint:ignore (reason)` on its own line directly above the
    offending statement.

  * comment line-length: enforce single-line <=120 chars across
    the whole script. 64 long comments were condensed to fit
    by dropping trailing historical clauses, parenthetical
    asides, em-dash trailing detail, or by word-boundary
    truncation with ellipsis. Operational essence preserved on
    every line; full historical context remains available in
    git log + this CHANGELOG. Decorative `--- header ---`
    dividers collapsed to plain `# header`. Multi-line comment
    blocks: 0. Pure-comment lines >120 chars: 0. Out of scope:
    79 pure-code lines (printf strings, profile-data lists,
    regex patterns where shortening changes semantics) and 13
    `#`-in-string-literal lines (shell scripts inside /bin/sh
    -c blocks) — these are not real comments.


v4.3.7 - 2026-04-25
-------------------

  Hardening release. Five low-severity findings closed: profile
  validator metachar gap, keepalive comment vs code mismatch,
  dead rc tracking in cpupower-epp ExecStart, network-failure
  message accuracy, and twin redundant guards on post-rebuild
  boot-entry counts. No execution-flow changes beyond the
  cpupower-epp content hash, which will redeploy on next install
  and re-baseline verify-static for that file.

[security]

  * _validate_profile element regex: extend forbidden-char class
    from [[:space:]"()] to [[:space:]"$'\`()\\;&|<>] (whitespace,
    double-quote, dollar, apostrophe, backtick, parens,
    backslash, semicolon, ampersand, pipe, less, greater).
    Profile elements in KERNEL_PARAMS / MKINITCPIO_MODULES /
    MKINITCPIO_HOOKS are interpolated into /etc/mkinitcpio.conf,
    which mkinitcpio(8) sources as root. The prior class missed
    bash command-substitution (backtick), variable-expansion
    ($), statement separators (; & |), redirects (< >),
    apostrophe, and bare backslash. No privilege escalation in
    single-user trust model (user has full sudo anyway), but
    defense-in-depth closes the gap for shared/repo-pulled
    profiles. Comment already asserted intent to "reject
    shell-metachars... embedded into config files" — code now
    matches the intent.

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
    will report drift on
    /etc/systemd/system/cpupower-epp.service until the next
    install redeploys the unit.

  * _verify_static_boot + _install_rebuild_boot: drop redundant
    `test -n "$entry_count"` and `string match -qr '^\d+$'`
    guards on the `count(1)` result. `count` always emits a
    non-negative integer string, so both prefix guards are
    unreachable-false. Single `test "$entry_count" -gt 0`
    suffices. Twin sites updated together for consistency.

[doc]

  * _install_preflight keepalive comment: replace misleading
    "transient PAM failures self-heal next cycle" claim with
    accurate "loop bails on first sudo -n -v failure
    (fail-fast)" description. The `or break` after
    `command sudo -n -v` exits the loop on any failure; there is
    no retry path. Parent surfaces death via
    _check_sudo_keepalive at each privileged phase. Comment now
    matches code.

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
    table. Dispatcher is `_post_$_h`, so a value of `post_boot`
    resolved to `_post_post_boot` — a name that matches no
    defined function. Every single-file install of a managed
    config since v4.3.2 (when the table was introduced) has
    emitted `Internal: post-hook _post_post_X not defined` via
    the existence guard and returned rc=1, skipping its
    post-action: mkinitcpio rebuild, sdboot-manage refresh,
    daemon-reload + service enable, udev reload-rules + trigger
    + settle, NetworkManager restart, sysctl reload, resolved
    restart, coredump.socket reload, drirc/envd session-restart
    notice, and logind reboot notice. Now consistent with the
    `_ry_profile_$name` and `_content_$key` dispatchers, which
    have always used bare keys with the prefix in the dispatch
    line. Bulk install path (_ry_do_install) was never affected
    — it calls _ry_install_file directly without the glob table.

  * Existence guard retained as defense-in-depth against future
    malformed table entries.

[version]

  * VERSION: 4.3.5 -> 4.3.6

[release]

  * banner header: 4.3.6 (2026-04-25)


v4.3.5 - 2026-04-25
-------------------

  Hygiene release. Completes the comment-rendering fix line
  that began in v4.3.3. No runtime behavior change; fish parser
  was unaffected throughout. External contracts preserved.

[hygiene]

  * comments: 30 paired-quote spans inside fish line-comments
    rewritten to bare prose. v4.3.3 replaced 19 paired backticks
    with single quotes to dodge the fish-tmbundle
    string.interpolated.backtick.fish trap, but the same
    grammar opens string.quoted.single scope on paired
    apostrophes inside comment.line.fish, reproducing the
    identical highlighting-poison cascade with a different
    delimiter. v4.3.5 strips both single- and double-quote
    pairs from every comment; inline references like 'fish -c',
    'set -l', "rebind", and "Unknown function" are now bare.
    Help-text echo string retains its single backtick pair
    (string scope sandboxes it correctly).

  * comments: one five-line rationale block in
    _content__etc_systemd_system_cpupower-epp.service collapsed
    to a single line.

[version]

  * version: 4.3.4 -> 4.3.5. Header date stamp resynced.


v4.3.4 - 2026-04-25
-------------------

  Install-affecting fix exposed during a v4.3.3 follow-up
  cleanup, plus apostrophe and double-quote analogs of the
  v4.3.3 paired-backtick comment sweep.

[fixes]

  * _content__etc_systemd_system_cpupower-epp.service: fix
    premature termination of the multi-line single-quoted
    printf body. Unescaped apostrophe pair around the
    OR-fallback token in an inline comment closed the printf
    string early; printf rc=0, OR short-circuited, error never
    surfaced. v4.3.0 through v4.3.3 installed a 12-line
    cpupower-epp.service missing StandardError, ExecStart, and
    the [Install] section; systemctl start would have failed
    with Unit-has-no-ExecStart but the install run never
    observed it. Generator rewritten as per-line printf args.
    Hosts that ran v4.3.0-v4.3.3 should reinstall or verify
    /etc/systemd/system/cpupower-epp.service is 17 lines and
    contains ExecStart= and [Install].

[hygiene]

  * comments: 13 contractions and several stray apostrophe /
    quote sites inside fish line-comments rewritten.
    Apostrophe analog of the v4.3.3 paired-backtick fix. Note:
    superseded by the exhaustive v4.3.5 sweep.


v4.3.3 - 2026-04-25
-------------------

  Maintenance release. One install-blocker fix, three
  robustness guards, one defensive arity check, and a
  project-wide rewrite of paired backticks in fish comments
  that confused the fish-tmbundle grammar into entering string
  scope mid-comment.

[fixes]

  * _ry_validate_configs: drop trailing dash arg from fish
    --no-execute invocation. Fish does not special-case dash
    as stdin (GH #1039 open since 2013); previous form
    returned rc=127, causing every install to abort at
    preflight before the package phase.

[robustness]

  * _install_preflight: command prefix on kill/sudo/sleep
    inside the sudo keepalive fish -c subshell.
  * _chk_perms / _verify_runtime_session: stat-fail guards.
  * _as: arity guard; empty-argv calls now return rc=2 and log
    BUG.

[hygiene]

  * comments: 19 paired backticks in fish comments replaced
    with single quotes. Fish runtime parser was unaffected;
    rendering fix only. Note: single-quote replacement
    reintroduced the same class of bug under the apostrophe
    rule and was finished off in v4.3.5.


v4.3.2 - 2026-04-25
-------------------

  Follow-up release. Ten findings from the v4.3.1 line-by-line
  review addressed. Highlights: _cleanup_on_exit consults
  $_RY_INSTALL_LAST_EXIT for early-fail footer; sudo-probe
  stderr redirects unified; _post_$hook existence guard before
  dispatch; cpupower-epp drops |logger fallback in favor of
  StandardError=journal; _acquire_lock requires both flock(1)
  and /bin/sh; _ry_do_check uses whole-word regex for
  KERNEL_PARAMS in /proc/cmdline; _log drops redundant
  `set -l` on event/data sanitize lines.


v4.3.1 - 2026-04-25
-------------------

  Cleanup release. Eighteen v4.3.0 findings addressed plus a
  simplification pass adding four verifier helpers (_chk_eq,
  _chk_sysfs_eq, _chk_perms, _chk_present) and trimming inline
  rationale. _atomic_write_file untracks tmpfile after mv so
  the cleanup loop stops stat()-ing dead paths. _post_boot END
  writes moved to _ry_do_install_file via single-exit refactor.
  _grep_kv escapes $key via string escape --style=regex before
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

  Targeted hardening. _json_str escape pass extended to
  {\\, ", \n, \r, \t} plus C0/DEL strip.
  _ry_check_kernel_version soft-warns for [6.14, 6.18.4);
  6.18.4 documented as gfx1151 stability floor.
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

  Fifteen patch releases. Highlights: JSONL log schema
  stabilized; _run timeout enforcement via timeout(1); progress
  bar via DECSTBM scroll region; lock file with flock(1);
  signal handlers for SIGINT/TERM/HUP/PIPE; sudo keepalive
  subshell; atomic file writes via mktemp + sudo mv with
  --reference. Several cpupower-epp.service iterations leading
  to the v4.3.4-discovered printf-truncation bug.


v4.0.x - 2026-04-18 to 2026-04-19
---------------------------------

  Initial fish rewrite from the v3.x bash original. Single-file
  architecture with embedded config generators (no /usr/share
  data files). Manifest-driven install loop replacing per-file
  shell blocks. argparse-based CLI with --help, --version,
  --verbose, --install-file flags.


v3.51.x - 2026-04-13 to 2026-04-17
----------------------------------

  Late-bash hardening. Manifest format finalized to
  count+sha256 separated by space. Embedded-content hashing
  centralized.


v3.50.x and earlier - through 2026-04-13
----------------------------------------

  Bash-era development. Per-file shell blocks; ad-hoc
  verification; no manifest. Superseded by the v4.0 fish
  rewrite.
