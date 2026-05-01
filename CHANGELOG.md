ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.5.0 - 2026-04-30
-------------------

  * Profile subsystem: removed entirely. _load_profile,
    _validate_profile, _ry_profile_gtr9_pro_* (8 sub-fns + entry),
    and the ~/.config/ry-install/profiles/<name>.fish override
    path are deleted. gtr9_pro defaults are now inlined as a flat
    set -g block at module init under
    # === GTR9_PRO BUILT-IN DEFAULTS ===. Single-machine focus;
    forking the script is the supported path for alternative
    hardware.
  * Manifest / orphan tracking: removed. _manifest_write,
    _manifest_check_orphans, and the ~/ry-install/.manifest
    file are deleted. Stale files from prior installs are no
    longer auto-detected.
  * Bootstrap: _init_runtime (63 lines) replaces _load_profile.
    Salvages _ROOT_UUID caching, EXPECTED_CPU_MATCH wrong-machine
    warning (collapsed from 2 _warn calls to 1 — no longer
    references the removed default-profile path),
    SUDO_KEEPALIVE_INTERVAL / NM_RESTART_DELAY defensive
    validation, and the _SYS_TMP_DIRS / _USR_TMP_DIRS /
    _PROFILE_USES_NM precompute cache (formerly tail of
    _validate_profile; consumed by _cleanup_tmpfiles,
    verify-runtime WIFI checks, and the finalize NM-restart path).
  * Validation: MANAGED_FILE_COUNT drift warning removed from
    dispatch preamble. _RY_MANAGED_FILE_COUNT at L195 is now the
    sole authoritative count. Help-text fallback at _ry_show_help
    L1816–1820 collapsed to an unconditional read of the constant.
  * Help text: tagline now reads the full PROFILE_DESC
    ("Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S")
    instead of the prior truncated fallback string
    ("Beelink GTR9 Pro (Strix Halo)") — single-line drift,
    cosmetic only.
  * Logging: JSONL log-event identifiers reduced and renamed —
    see Migration below. Header still emits "profile":"gtr9_pro"
    as a constant string.
  * Documentation: ## Profiles section removed from README;
    references to manifest, profile trust, profile sanitization,
    and external override paths purged. ## Customization note
    added pointing at the inlined defaults block.
  * Footprint: script LOC 5,335 → 4,954 (−381, −7.1%);
    bytes 210,899 → ~194,360 (−16,540, −7.8%).

  Migration:
    For existing v4.4.x installs, manually clear the now-orphaned
    user-config and manifest files:
        rm -rf ~/.config/ry-install/profiles
        rm -f  ~/.config/ry-install/default-profile
        rm -f  ~/ry-install/.manifest
    If you maintained a custom external profile, fork the script
    and edit the # === GTR9_PRO BUILT-IN DEFAULTS === block.
    No automated migration.

    JSONL log-event identifier changes (external consumers):
        REMOVED: PROFILE_DEFAULT, PROFILE_OVERRIDE,
                 MANIFEST_CHMOD_FAIL, MANIFEST_WRITTEN,
                 MANIFEST_WRITE_FAILED
        RENAMED: MANIFEST_SKIP                       → INSTALL_BAILOUT
                 PROFILE_INVALID_SUDO_KEEPALIVE_INTERVAL
                                                     → INVALID_SUDO_KEEPALIVE_INTERVAL
                 PROFILE_INVALID_NM_RESTART_DELAY    → INVALID_NM_RESTART_DELAY
        UNCHANGED: header "profile" field (constant "gtr9_pro")


v4.4.36 - 2026-04-29
--------------------

  * Bootstrap: fish version gate raised from 3.4 to 3.6.
    Three required language/builtin features were added in
    3.5/3.6: omitted-end slice `[N..]` (3.6, 5 sites),
    `string match -rg` / `--groups-only` (3.5, 6 sites), and
    reliable `set $pipestatus` capture immediately after a
    cmdsub'd pipeline (3.6, #6820/#6998, 4 sites). Pre-3.6
    runs would silently malfunction rather than refuse to
    start. Error message updated to "fish 3.6+ required".
  * Validation: `_chk_grep` strips comment-only lines via
    `grep -v '^[[:space:]]*#'` upstream of the pattern grep,
    and uses `-qwF` (whole-word) for plain tokens versus `-qF`
    (substring) for `=`-shaped k=v patterns. Prior `grep -qF`
    was substring-only across all callers, so a `# token`
    comment-line mention satisfied verify-static checks for
    plain-token verifiers (SSH_AUTH_SOCK, ssh-agent,
    radv_enable_unified_heap_on_apu). Pipestatus[2] is
    captured to preserve the original 3-state semantics
    (0=found, 1=missing, ≥2=grep error).
  * Validation: `_ry_check_kernel_version` now switches all
    five `_ntsync_state` returns. Prior if/else only treated
    `unavailable` as a warning; `loaded_nodev` (module loaded
    but `/dev/ntsync` missing) and `missing` (kernel ≥6.14
    capable but module not loaded) reported as `_ok`,
    masking partial/absent ntsync on a capable kernel.
    Mirrors the runtime-side switch at `_verify_runtime_env`.
  * IO: `_installed_bytes` adopts capture-then-emit pattern
    (mirror `_content_bytes` v4.4.29). Prior streamed cat
    output before checking pipestatus, so a partial-write
    mid-read silently emitted truncated bytes to callers
    using `set -l x (_installed_bytes …)`. Final emit uses
    `string collect --no-trim-newlines --allow-empty` plus
    explicit `return 0` to preserve the original empty-file
    status-0 contract.
  * AUR: `_install_aur_packages` now returns 1 when any
    per-package install fails after the batch retry, not
    just on the no-paru path. Prior the per-package failure
    branch reached `return 0`, so the caller's
    `or set -g INSTALL_HAD_ERRORS true` was a dead branch
    in that case. Function still sets the global directly,
    so behaviour was correct; the contract is now
    consistent with peer `_install_*` functions.
  * UX: progress bar now renders `Aborted at N%` instead of
    `100% Done` when finalisation is skipped on a
    boot-critical failure. New `_PROG_FINALIZED_SKIP`
    sentinel is set by `_ry_do_install` before calling
    `_progress Finalize skip` and read by `_progress_done`.
  * UX: new `_progress_on_winch` SIGWINCH handler re-anchors
    the pinned bar after terminal resize. `_PROG_ROWS` was
    previously captured once at `_progress_init`, so a
    resize during install left the bar at the old row.
    Handler is registered alongside `_cleanup`,
    `_cleanup_pipe`, `_cleanup_on_exit` and erased on every
    bail/exit/cleanup path.
  * Validation: profile-name regex `^[a-z0-9][a-z0-9_-]*$`
    permitted unbounded length and a `_` prefix that
    collides with the internal `_ry_profile_*` namespace.
    Length is now capped at 64 chars and names starting
    with `_` are rejected with `EXIT_USAGE`.
  * Boot: `_progress_done` log line now includes the
    `skip=` field for post-mortem inspection.
  * Validation: `systemd-analyze` boot-time regex tightened
    from `^[0-9.]+$` to `^\d+(\.\d+)?$`. `printf %.0f` on a
    multi-dot input still extracted a numeric prefix, so the
    boot-time threshold check ran on a wrong-but-bounded
    number rather than crashing; now it skips cleanly.
  * Robustness: keepalive subshell args `$my_pid` and
    `$SUDO_KEEPALIVE_INTERVAL` are now quoted at the
    `fish -c` invocation site. Both are validated as positive
    integers upstream so the change is defensive only.
  * Hygiene: `_pre_dispatch_log_cleanup` and
    `_pre_dispatch_exit` now use a bounded 3-level
    `rmdir LOG_DIR; rmdir logs/; rmdir ry-install/` chain
    instead of `rmdir -p`. Behaviour matches original
    (rmdir refuses non-empty, so `$HOME` is never touched);
    intent is now explicit and bounded to this run's
    footprint.
  * Comments: dispatch-time `case '*'` empty body annotated
    to flag verify-static, verify-runtime, and check as
    read-only modes that intentionally skip lock acquisition.




  * Docs: README Prerequisites table simplified — the
    Verification command column is dropped and the two
    GNU coreutils rows (`sort -z`, `stat -c`) folded into
    a single Coreutils row. Same requirements; runtime
    checks remain covered by `--check` and the pre-flight
    block immediately below the table. No code change.


v4.4.34 - 2026-04-29
--------------------

  * Bootstrap: `_RY_INSTALL_LOADED` is now set before the
    `_RY_PRE_GLOBALS` snapshot so `_ry_namespace_cleanup`
    preserves it as caller-API state. Prior order let cleanup
    wipe the flag on every exit path; the re-source guard at
    L9 therefore never fired after a normal sourced run, only
    after abnormal termination.
  * Boot: `_install_rebuild_boot` boot-wipe precheck captures
    `$pipestatus` into `_pre_ps` immediately after the
    find/sort/split0 cmdsub. The late
    `BOOT_WIPE_PRECHECK_PIPE_FAIL` log emit now reports the
    captured pipeline status rather than `$pipestatus` after
    the loop body's inner `test` commands have clobbered it.
    Detection itself was correct (fish does not clobber
    `$pipestatus` on `set -l`), but the log message was
    misleading. Same shape as the v4.4.31 fstab pipestatus
    capture.
  * Boot: `_install_finalize` post-rebuild marker write
    captures `$pipestatus` into `_post_ps` for defensive
    consistency. No behavioural change at this site (no late
    `$pipestatus` reference today); guards against future
    maintainers inserting a clobberer between the cmdsub and
    the loop.
  * Validation: `_chk_perms` stat-output split now uses
    `string split -n ' '`; tolerates double-space `%a %U:%G`
    output from non-standard stat impls. Mirrors the v4.4.31
    fix in `_load_profile`.
  * Manifest: `_manifest_write` gates `printf >"$tmp"` on
    exit status. Prior code silently installed an empty or
    truncated manifest if the redirect failed. Failure path
    now removes the tmpfile, untracks it, warns, and returns 1.
  * Validation: `_verify_unit_content` gates `printf >"$tmp"`
    on exit status. Prior silent failure surfaced as a
    misleading `systemd-analyze verify` syntax error.
  * Comments: `_atomic_write_file` post-write
    symlink-then-chmod TOCTOU window documented as irreducible
    in userspace fish without O_NOFOLLOW-aware syscalls.
  * Comments: `NO_COLOR` deviation rationale expanded to cite
    the spec and the partial `env -u NO_COLOR` case;
    `_resolve_esp` fallback cache stickiness for the run
    documented inline; the two captions above each were merged
    into the marker comment to keep one logical comment per
    physical line.
  * Comments: 13 truncated mid-sentence comments completed
    (lines 153, 249, 261, 633, 1151, 1398, 1656, 2078, 2089,
    3340, 3351, 4393, 4849).
  * Header: top-of-file version updated to v4.4.34.


v4.4.33 - 2026-04-29
--------------------

  * Profile: `SYSTEM_DESTINATIONS` quoting normalised. Two paths
    (`/etc/kernel/cmdline`, `/etc/drirc`) were bareword while the
    other ten were double-quoted. Cosmetic only — fish parses
    barewords identically when they contain no metacharacters or
    `$`-expansion — but the visual asymmetry surfaced in audits.
    All twelve entries now uniformly double-quoted.
  * Header: top-of-file version updated to v4.4.33.


v4.4.32 - 2026-04-28
--------------------

  * Header: top-of-file module-state note collapsed from 12 lines
    to 4. Architectural rationale (no module scope → `set -g`
    namespacing, `_ry_namespace_cleanup` on exit, re-source guard
    `_RY_INSTALL_LOADED`) preserved; per-function-category list
    and example function names dropped (covered by per-function
    descriptions).
  * Comments: 5 truncated mid-sentence comments completed —
    `_ry_exit` idempotency-guard short-circuits via
    `_RY_INSTALL_BAILING`; `_CLEANUP_DONE` set first to gate
    signal-handler re-entry; `/etc/drirc` RADV unified VRAM
    heap lets UMA APUs treat system RAM as unified VRAM;
    progress-bar section header notes terminal scroll-region
    escapes; `_PROG_TOTAL` derived from `count $_PROG_STEPS`,
    not hardcoded.
  * README: Safety & Reliability section trimmed 107 → 95 lines.
    Three implementation-detail rows removed (verify-static
    HandleSecureAttentionKey skip, lvm2-monitor mask skip on
    LVM-detected systems, source-mode last-exit return path).
    Five table cells tightened (Profile trust, Profile
    sanitization, fstab edits, Cleanup invariant, Boot safety)
    by removing nested parentheticals. Log Format event table
    folded from 16 rows to 6 categorical groupings; sample
    JSONL output retained. Inner Environment Variables
    subsection renamed to Runtime Variables to resolve heading
    collision with Configuration Reference > Environment
    Variables.
  * Header: top-of-file version updated to v4.4.32.


v4.4.31 - 2026-04-28
--------------------

  * Fstab: `_install_fstab_opts` awk/tee pipeline gates on
    `$pipestatus[1]` and `$pipestatus[2]`. Fish `if not pipeline`
    tests only the last stage's rc; an awk silent-fail with
    tee rc=0 would let `findmnt --verify` pass against an empty
    fstab and `mv` it into place.
  * Cleanup: `_ry_exit` erases `_cleanup` / `_cleanup_pipe` /
    `_cleanup_on_exit` before `_ry_namespace_cleanup bail`;
    mirrors dispatch-bottom order (L5230-5232). Reversed order
    let SIGINT firing after `_CLEANUP_DONE` was cleared but
    before handler erasure re-enter `_cleanup`.
  * Boot: `_resolve_esp` adds `findmnt -no FSTYPE` vfat
    fallback over `/efi`, `/boot/efi`, `/boot` before
    defaulting to bare `/boot`; logs `ESP_RESOLVE_FALLBACK`.
    Prior code silently targeted `/boot` even on systems with
    `/efi` as the actual ESP when `bootctl -p` returned empty.
  * Boot: `_install_rebuild_boot` zero-entry guard before
    `_existing_hash`. Empty `$_existing_basenames` yields
    `printf '%s\0'` → one NUL → deterministic non-empty hash
    with no semantic meaning for a zero-entry set. Mirrors
    the post-write `_post_count -lt 1` guard.
  * Preflight: GNU `sort -z` probe rewritten to feed two
    NUL-separated tokens out of order (`b\0a\0`) and verify
    the join equals `ab`. Prior probe (`printf '' | sort -z`)
    accepted modern BSD sort and some busybox builds.
  * Profile: `_load_profile` mode regex
    `^[0-7]?[0-7][0145][0145]$` accepts 4-digit modes (4755,
    2755, 1755). Special bits irrelevant — fish source is not
    setuid-honored. Prior 3-digit-only regex rejected such
    files with the misleading "group/world write bit set".
  * Profile: `_load_profile` `string split -n ' '`
    (--no-empty) on `stat -c '%u %a'` output; tolerates
    double-space from non-standard stat impls.
  * Logging: `_write_footer` printf format string switches
    `exit_code` / `pass` / `fail` / `warn` / `gen_fail` from
    `%s` to `%d`; `%s` would emit invalid JSON on empty value.
  * Style: bare `set -e _RY_INSTALL_BAILING` and
    `set -e _RY_INSTALL_LAST_EXIT` at re-source guard;
    `2>/dev/null` redirect was cosmetic (Fish 3.4+ writes
    nothing to stderr on unset-erase).
  * Comments: multi-line `#` blocks collapsed to single lines;
    lint annotations and shebang/header preserved.
  * Header: top-of-file version updated to v4.4.31.


v4.4.30 - 2026-04-28
--------------------

  * Validation: `_check_env_ssh_auth_sock` now fails the deploy
    when `_RY_SYSTEMD_VER < 232` (was warn-only, return 0).
    systemd <232 cannot expand `${VAR}` in environment.d files,
    so 10-environment.conf would deploy with literal
    `${XDG_RUNTIME_DIR}/ssh-agent.socket` and ssh-agent would be
    unreachable until manual fix. Block-and-report instead of
    silent breakage.
  * Dispatch: `_tmpfile_key` `$HOME→HOME` substitution is now
    anchored. Prior unanchored `string replace` mismatched on
    (a) trailing-slash `$HOME` (lost the / separator), and
    (b) `$HOME` being a path-prefix of unrelated paths
    (mid-path mangling, e.g. `$HOME=/home/ry` would substitute
    inside `/home/ryan/...`). Failure mode was loud (dispatcher
    rc=11) but UX-degrading on non-canonical $HOME. Fixed by
    `string match -q -- "$HOME/*" $path` gate before substring
    replace.
  * Logging: 6 narrative `_log` calls normalized to KEY-style
    events for JSONL parseability — `Checking dependencies...`
    → `DEPS_CHECK_START`, `All dependencies satisfied` →
    `DEPS_CHECK_OK`, `Checking network connectivity...` →
    `NET_CHECK_START`, `Checking disk space...` →
    `DISK_CHECK_START`, `INSTALL SYSTEM FILES` and
    `INSTALL USER FILES` → `=== ... ===` section markers
    (recognized by `_log` itself as event=section).
  * Header: top-of-file DESIGN-NOTE block documents the
    module-state convention (`set -g` writes from inside
    functions for cross-function lifecycle/profile/counter
    state, segregated via `_RY_*` / `_*` / SCREAMING_SNAKE_CASE
    naming, erased in `_ry_namespace_cleanup` on exit).
  * Style: `# lint:ignore (literal printf-arg, not a block
    terminator)` annotation on the trailing `'end'` printf-arg
    in `_content_HOME_.config_fish_conf.d_10-ssh-auth-sock.fish`
    + comment block warning against `fish_indent -w` on the
    file. fish_indent rewrites the quoted literal as bare
    keyword (parses identically because of `\`-continuation,
    but obscures intent).


v4.4.29 - 2026-04-28
--------------------

  * Bootstrap: KVER major/minor parse failure paths now call
    `_ry_exit` instead of `_pre_dispatch_exit`. The latter is
    defined post-dispatch (L4961); fish parses top-down, so the
    call at top-level resolved as "Unknown command" and execution
    fell through past the intended bail point.
  * Logging: `_json_str` rewritten in argument-mode `string
    replace`. Pipe-mode splits stdin on `\n` before any replace
    runs, so the `\n→\\n` step was a no-op and JSONL footer
    payloads with embedded newlines emitted invalid JSON. Per-step
    `string collect` re-joins the cmdsub-split list; terminal
    `string collect --allow-empty` preserves the count=1 contract
    for empty input.
  * Sysctl: `_content__etc_sysctl.d_99-cachyos-sysctl.conf` adds a
    skip-guard for malformed `SYSCTL_VALUES` entries (no `=`,
    empty key, empty value). Skipped entries are logged via
    `SYSCTL_SKIP_MALFORMED`. Without the guard, the validator's
    "≥1 good line" rule let bad entries through deploy and they
    failed at sysctl-apply with "malformed setting".
  * Comments: multi-line `#` blocks collapsed to single lines;
    `lint:ignore` annotations and shebang/header preserved.


v4.4.28 - 2026-04-27
--------------------

  * Dispatch: bail-guard polled after `_early_usage_exit`,
    positional-arg `_pre_dispatch_exit`, and pre-dispatch
    switch — source-mode previously fell through to
    `realpath`, `_load_profile`, and `_ry_do_install` /
    `_ry_do_install_file` / verify entrypoints despite
    `_RY_INSTALL_BAILING=true`.
  * Dispatch: post-pre-dispatch bail-guard writes
    `footer interrupted` JSONL line, closing the
    header-only log left by `_ry_exit $EXIT_LOCK` paths
    when sourced.
  * Bootstrap: NO_COLOR detection — env value captured
    to local before defaulting; replaces `if begin … end;
    or test …` with linear flag set, no var-shadow.
  * Bootstrap: fish version gate `if test … or begin …
    end` flattened to single-line predicate.


v4.4.27 - 2026-04-27
--------------------

  * Helpers: introduce `_pre_dispatch_exit`,
    `_pre_dispatch_log_cleanup`, `_unit_state`,
    `_check_avail`, `_chk_path_mode_in`, `_chk_token_in`,
    `_chk_sysfs_match`. Replaces 27 duplicated 3-line
    blocks across pre-dispatch teardown, systemctl-show
    triple-property reads, disk-space probes, ssh-perm
    checks, mkinitcpio MODULES/HOOKS scans, and sysfs
    regex-match comparisons.
  * Inline: `_banner` single-call wrapper removed; site
    emits `_echo` directly.
  * `_run`: replace 8-line manual `_TRACKED_TMPFILES`
    rebuild loop with existing `_untrack_tmpfile` call.
    No recursion hazard — helper makes no `_log` calls.
  * `_run`: redaction loop unified — `[ =]\S+` regex
    collapses two-pass `--flag value` / `--flag=value`
    matching. Redacted form normalizes to `=`.
  * `_load_profile`: collapse two-branch fallback log
    into one statement; preserves "is empty" vs "no file"
    distinction in the suffix.
  * `_acquire_lock`: drop redundant `rm -f $1/pid`
    before `find $1 -type f -delete` in /bin/sh
    stale-reclaim script (`-delete` covers pid).
  * `_verify_static_packages`: drop redundant
    `command -q pacman` guards inside required/removed
    loops; outer guard handles missing pacman.
  * `_verify_static_boot`: 4 sdboot-manage K=V `_chk_grep`
    calls collapsed to single loop over key list.
  * `_verify_static_boot`: MKINITCPIO_MODULES and
    MKINITCPIO_HOOKS token scans share `_chk_token_in`.
  * `_ry_validate_mkinitcpio_hooks`: replace
    `if test $errors -eq 0; return 0; end; return 1`
    idiom with `test $errors -eq 0; return $status`
    (2 sites).
  * `_verify_static_user`: hoist repeated
    `$HOME/.config/systemd/user/ssh-agent.service`
    literal to local var.
  * `_verify_runtime_kparams`: amd_pstate status and
    nmi_watchdog inline read+compare blocks replaced
    with `_chk_sysfs_eq`; zswap.enabled regex form via
    `_chk_sysfs_match '^[N0]$'`.
  * `_verify_runtime_session`: `~/.ssh/authorized_keys`
    and `~/.ssh` mode probes replaced with
    `_chk_path_mode_in` (accepts mode whitelist via
    argv[3..]).
  * `_ry_check_disk_space`: twin `/` and `/boot` probes
    factored through `_check_avail` helper (path,
    divisor, unit, crit, warn).
  * Comments: long F##/release-marker explanations
    collapsed to first-clause single-line summaries.
    `lint:ignore` annotations and shebang/header
    preserved verbatim.
  * Lines: 5282 → 5197 (-85).


v4.4.26 - 2026-04-27
--------------------

  * Comments: multi-line `#` blocks collapsed to single lines; lint
    annotations and shebang/header preserved.
  * Verify: `_verify_static_system` mirrors generator's systemd<256
    skip for HandleSecureAttentionKey; closes cross-version drift
    between install and verify.
  * Tmpfile tracking: `_atomic_write_file` and `_install_fstab_opts`
    call `_untrack_tmpfile` on every failure path. _TRACKED_TMPFILES
    no longer carries dead entries between aborts.
  * Sudo cache: `_ensure_sudo_cached` cleanup gates `rm` on the
    `/dev/null` mktemp-fail sentinel.
  * Validators: `_grep_kv` adds defensive `case '*'; return 2` for
    unsupported destinations. `_grep_xml_tag` tightens
    `'<application'` to `'<application '` (trailing space).
  * Checksum verify: switch on joined `expected::actual` replaced
    with explicit `test -z` chain; removes `::`-substring ambiguity.
  * Cleanup: `_do_cleanup` erases `_RY_ESP_PATH` and
    `_RY_SYSTEMD_VER` alongside other memoized caches.
  * Logging: `_content__etc_kernel_cmdline` _err message typo
    corrected.
  * Pacman: `pactree -ru` output piped through `string trim --`
    before `string match -v`.


v4.4.25 - 2026-04-27
--------------------

  * Boot: `_resolve_esp` cache; `/boot/loader/entries` hardcoded sites
    replaced. Wipe-marker refuses 0-count writes; pipestatus checked
    across find→sort→split0; tmpfile untracked on success path.
    `linux_check` canonicalized via realpath -m.
  * Logging: `_log` enforces parallel-child guard via
    `_RY_LOG_OWNER_PID`; `_log_base_rot` derived from `LOG_DIR`.
  * Profile: metachar sanitizer extended to MASK, EXPECTED_SERVICES,
    EXPECTED_VULKAN_PKGS, PKGS_*, AUR_PKGS; ENV_VARS rejects
    SSH_AUTH_SOCK collisions.
  * Deps: GNU find -printf and df --output preflight probes added;
    required-cmd list widened (timeout, mktemp, awk, find, grep,
    sort, realpath, flock, bootctl); zcat / tput / nmcli / pkill
    moved to soft-warn list.
  * Fstab: OFS=tab restored; preserves column-aligned format.
  * Progress: tput gated on availability; tmux scroll-region skip;
    unknown step name logged.
  * Mkinitcpio: `systemd:keyboard` order assertion added; modules
    validator switched modprobe -n → modinfo.
  * Pacman.conf parsing: ParallelDownloads / IgnorePkg regex allow
    leading whitespace.
  * Verify: dmesg captured once in `_verify_runtime_kparams` and
    reused for TSC + ReBAR; `_chk_grep` distinguishes rc=2 (file
    error) from rc=1 (not-found); ssh-agent --user check diagnostic
    clarified for headless / no-user-bus; NM wifi info field renamed
    `nm_wifi_enabled`.
  * Content gen: `_content_bytes` drops redundant `test -z` check
    that conflated empty-but-valid output with generator failure.
  * Single-file: `_post_boot` names failed step in EXIT_BOOT_CRIT
    log line.


v4.4.24 - 2026-04-26
--------------------

  * Strings: revert L1310, fix L1461. v4.4.23 misdiagnosed; real
    closer-eating bug was `'\\'` vs grammar's left-biased `\\'|\\`
    regex. Bare `\\ \\\\` uses top-level escape, no string opens.
    fish-vs-grammar span divergence: 86 → 0.


v4.4.18..v4.4.23 - 2026-04-26
-----------------------------

  * Comment hygiene + fish-tmbundle grammar tripwire pass:
    multi-line `#` block collapse, ≤60c abbreviation, U+2026 drop,
    unbalanced quote/backtick/paren close. v4.4.23 misdiagnosis
    reverted in v4.4.24.


v4.4.8..v4.4.17 - 2026-04-26
----------------------------

  * Signal-handler, exit-path, namespace-cleanup re-entry guards.
    `_content_bytes` string-collect terminator (15/15 byte-equal
    round-trip). Comment rewrap and pipeline-orientation passes.


v4.4.0..v4.4.7 - 2026-04-25..2026-04-26
---------------------------------------

  * Profile system: $HOME/.config/ry-install/profiles/<name>.fish.
  * Verification split: --verify-static / --verify-runtime / --check.
  * Locking: mkdir mutex + flock(1) stale reclaim.
  * sudo keepalive with TERM→sleep→KILL teardown.


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256-keyed
    verification. cpupower-epp.service printf-truncation fix.


v4.2.x..v4.0.x - 2026-04-18..2026-04-25
---------------------------------------

  * Initial fish rewrite from v3.x bash. Single-file architecture,
    embedded generators, manifest-driven install, argparse CLI.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
