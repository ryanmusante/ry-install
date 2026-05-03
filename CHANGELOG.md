ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.5.21 - 2026-05-03
--------------------

  * Atomic-write: `_atomic_write_file` initialises `_sp` to empty
    instead of literal `command`. The variable was passed to `_run`
    as argv[1]; under variable expansion it survived as a plain string
    and reached timeout(1) as the command name, producing
    `timeout: failed to run command 'command'` (rc 127) on every
    user-side write (`~/.config/fish/conf.d/*`,
    `~/.config/environment.d/*`, `~/.config/systemd/user/*`).
    Sudo path keeps `sudo -n`; non-sudo path now invokes chmod / mv
    directly through `_run`.
  * Style: comment at the patch site trimmed to single-line
    annotation.

v4.5.20 - 2026-05-03
--------------------

  * Run: drop literal `--` between timeout(1)'s DURATION and COMMAND.
    GNU coreutils `timeout(1)` does not accept `--` as end-of-options;
    `--` was consumed as the command name (rc 127), so every `_run`
    invocation failed. Pass argv directly.
  * Run: drop literal `--` between fish's `command` keyword and `$argv`
    in the `RY_RUN_TIMEOUT=0` fallback branch. `command --` triggers
    the `command` builtin's option-parser (requires -a/-q/-s/-v and
    prints help otherwise); bare `command CMD ARGS` is the parser's
    force-external-lookup keyword.
  * As: same `command --` fix in `_as` user-side branch — was rendering
    every `_as false ...` call as a help-print no-op (rc 2).
  * Style: comments at the three patched sites trimmed to single-line
    annotation (mirrors v4.5.14 / v4.5.19 cleanup pass).

v4.5.19 - 2026-05-03
--------------------

  * Bootstrap: fish-version probe uses `$FISH_VERSION` builtin
    instead of `(fish --version)` cmdsubst. PATH not yet pinned
    at that line; subprocess could have resolved a shadow `fish`.
  * Run: secret-flag redaction regex boundary widened from `(^| )`
    to `(^|\s)` and separator from `[ =]` to `[\s=]` — tab-separated
    `--token<TAB>foo` argv now matches.
  * Preflight: bare `grep -v` in `sudo -n -l` filter normalized to
    `command grep -v` (mirrors v4.5.12 normalization for the one
    site missed in that pass).
  * Style: two two-line narrative comments compressed to single-line
    annotations (mirrors v4.5.14 cleanup pass).

v4.5.18 - 2026-05-03
--------------------

  * Dispatch: early `-h` / `--help` / `-v` / `--version`
    short-circuit inserted before the GNU-coreutils preflight gates;
    usage and version reachable on systems missing GNU coreutils,
    fish 3.6+, or writable `HOME`.
  * Run: `_run` no longer caps subprocess stderr at 5 lines under
    `--verbose`; full stderr cat'd to fd 2. 5-line cap retained for
    unattended (`QUIET=true`, `rc≠0`) so logs don't flood.
  * Verify-runtime: `nftables.service` added to `sys_units`;
    `parsed[]` count raised 5→6 with matching ok/warn/fail block.
  * Progress: `_progress_init` short-circuits under mosh
    (`$MOSH_CONNECTION` or `$TERM_PROGRAM` matching `mosh*`); JSONL
    `prog_step_*` events still emit.
  * Exit: `_ry_exit` removes orphan `LOG_FILE` / `LOG_DIR` (rmdir
    chain through `~/ry-install/`) when neither `_RY_HEADER_WRITTEN`
    nor `_RY_LOG_WRITTEN` is set.

v4.5.17 - 2026-05-03
--------------------

  * Install-file: `_post_service` user branch probes `$XDG_RUNTIME_DIR/bus`
    before `systemctl --user enable --now`; falls back to `enable`
    (no `--now`) plus an info line when the bus is absent.
  * Install-file: `_ry_do_install_file` calls `_kill_sudo_keepalive`
    on both return paths.
  * Install-file: keepalive-launch glob match canonicalizes `$target`
    via local `realpath -m` before pattern testing.
  * Logging: `_log` sets `_RY_LOG_WRITTEN` on first successful
    append; `_pre_dispatch_log_cleanup` preserves `LOG_FILE` when
    either `_RY_HEADER_WRITTEN` or `_RY_LOG_WRITTEN` is set.
  * Logging: log-rotation `find` capped at `-maxdepth 2`.
  * Cleanup: `_cleanup_tmpfiles` no longer walks
    `/etc/NetworkManager/system-connections`. Drops the
    `_RY_CLEANUP_SUDO_LAPSED_WARNED` global.
  * Preflight: `_validate_kernel_params` `param_config_map` drops
    stale `nvme_core.=CONFIG_NVME_CORE` entry.
  * Docs: README log-rotation note matches dispatcher behaviour
    (`MAX_LOGS=50`, oldest first).

  Migration: none. Behaviour-preserving on all install paths.


v4.5.16 - 2026-05-03
--------------------

  * Services: drop dead `_RY_IMPLICIT_SERVICES` global. The
    `_verify_runtime_services` and `_implicit_svcs` in `_ry_do_check`
    list unit names inline.
  * Comments: `_verify_runtime_services` `sys_units` annotation
    documents literal-list semantics (positional coupling to
    `parsed[N]`).

  Migration: none. Behaviour-preserving cleanup.


v4.5.15 - 2026-05-03
--------------------

  * Preflight: KERNEL_PARAMS hygiene gate refuses members containing
    whitespace or `"`.
  * Preflight: fractional-sleep probe sets `_RY_SLEEP_FRAC` for
    cleanup TERM→KILL gaps.
  * Sysctl: content generator returns rc 12 when printed line count
    ≠ `count $SYSCTL_VALUES`.
  * Install-file: post-hook dispatch table gains
    `*/fish/conf.d/*.fish|fish` mapped to a new `_post_fish` handler.
  * Verify-runtime: `systemctl --user show-environment` capture
    strips surrounding double-quotes.
  * Install: `_configure_services_enable` probes for an active user
    bus before `systemctl --user enable --now`; without one,
    enables without `--now`.
  * Logging: section-event class captures content via anchored
    `^=== (.*) ===$` regex.
  * Logging: `_log` records `MKTEMP_FAIL: ry-fish-syntax` when the
    fish syntax-check tmpfile falls back to `/dev/null`.
  * Boot: post-rebuild entry count reuses `_enum_boot_entries`.
  * Verify: `_chk_file` tries plain `test -f` before sudo for
    `/boot` paths.
  * Verify: `_progress_init` adds `tput cup 0 0` capability probe
    before pinning the bar.

  Migration: none. KERNEL_PARAMS gate and sysctl count assertion
  fail closed at preflight rc 3 if violated.


v4.5.14 - 2026-05-03
--------------------

  * Verify: end-of-string anchor `$` in four single-quoted PCRE
    patterns was reaching the regex engine as a literal dollar
    character. Affected `_grep_kparam`, `_verify_static_boot`,
    `_ry_do_check`, `_verify_runtime_kparams` `rw` token checks.
  * Style: in-script narrative comments compressed to single-line
    annotations; blank lines stripped from function bodies (5262
    → 4975 LOC).


v4.5.13 - 2026-05-03
--------------------

  * Packages: pacman flags follow Arch's no-partial-upgrade policy
    by default — `-Syu --needed`. Opt-in `-Sy` via
    `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` with warning. Legacy
    `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE` removed.
  * Boot: `_install_rebuild_boot` no longer carries a standalone
    `-Syu` site; Packages phase is sole upgrade location.
  * Bug: `_RY_BOOT_PIPE_OK=false` returns EXIT_PREFLIGHT instead
    of proceeding with phantom 0-count.
  * Bug: `_atomic_write_file` switched to `|`-delimited
    `stat -c` format.
  * Verify: IWD DriverQuirks and ENV_VARS checks compare full
    `key=value`.
  * Verify: `rw` token verified across four cmdline check sites.

  Migration: default invocation now runs `pacman -Syu --needed`.


v4.5.12 - 2026-05-03
--------------------

  * Style: normalize bare → `command` for `grep`, `stat`, `sed`,
    `realpath`. PATH pinned at L94, no functional change.
  * Style: bootstrap stderr at L150 uses `[ERR]` prefix to match
    other 14 bootstrap stderr emits.


v4.5.11 - 2026-05-03
--------------------

  * Tuning: drop 5 sysctl entries — `vm.swappiness=100`,
    `kernel.split_lock_mitigate=0`, `net.core.busy_read=50`,
    `net.core.busy_poll=50`, `net.core.netdev_budget=600`.
    Vendor defaults now apply. SYSCTL_VALUES count: 21 → 16.


v4.5.10 - 2026-05-03
--------------------

  * Bug: `_ry_check_deps` aborted preflight on missing paru;
    contradicted the soft-fail contract. Now `_warn` + `_info`.
  * Bug: `_ry_do_check` masked + implicit + Phase 4 + Phase 5
    + Phase 2 paths now return EXIT_PREFLIGHT (not silent drift)
    when `_unit_state_padded` reports ERR_NO_DATA or generator
    returns rc 11/12.
  * Reliability: `_ry_do_check` Phase 1 probes `command -q
    systemctl`. `_SYS_TMP_DIRS`, `_USR_TMP_DIRS`,
    `_PROFILE_USES_NM` initialized at top-of-file so signal
    handlers firing pre-`_init_runtime` are well-defined.
  * Refactor: `_content_bytes` terminal `string collect` carries
    `--allow-empty`.


v4.5.9 - 2026-05-03
-------------------

  * Bug: secret-flag redaction in `_run` and the dispatch header
    logger emitted fish "Invalid index value" runtime errors —
    the pattern `"$flag[ =]\S+"` was parsed as a variable index
    expression. Fixed by close-quoting: `"$flag""[ =]\S+"`.
  * Bug: dispatch-header `argv` field corrupted argv elements
    containing spaces (e.g. `--install-file '/path with space'`).
    Replaced join-then-split with a per-element redact loop.
  * Reliability: `_unit_state_padded` returns `ERR_NO_DATA`
    sentinels when systemctl produces fewer than 3 fields.
  * Reliability: stale-lock detection cross-checks
    `/proc/<old_pid>/comm` against `fish` before refusing.
  * Refactor: extract `_start_sudo_keepalive` (replaces two
    16-line copies); `_pre_dispatch_exit` delegates to
    `_pre_dispatch_log_cleanup` + `_ry_exit`.


v4.5.8 - 2026-05-02
-------------------

  * Refactor: extract `_rm_tmp` helper (sudo-aware tmpfile delete +
    untrack) and `_is_symlink` helper. Replaces 27 instances of
    the 2-line pattern across atomic-write, validate, install,
    fstab, finalize, early-usage paths.
  * Refactor: extract `_enum_boot_entries` helper. Replaces the
    14-line find/sort/split0 block duplicated between rebuild
    precheck and finalize marker write.
  * Footprint: 5,240 → 5,205 LOC.


v4.5.7 - 2026-05-02
-------------------

  * Boot: mkinitcpio rollback gates `chmod 644` and
    `chown root:root` on explicit success checks; failures route
    to `MKINITCPIO_REVERT_FAIL` with distinct markers (was
    silently dropped via `2>/dev/null`).
  * Logging: `_pre_dispatch_log_cleanup` and `_pre_dispatch_exit`
    preserve `LOG_FILE` when the dispatch JSONL header was
    already written (`_RY_HEADER_WRITTEN=true`).
  * Verify: `_verify_unit_content` drops GNU-only `mktemp
    --suffix=.service`. Replaced with `mktemp -t` + explicit `mv`.
  * Refactor: 7 `string match -qr -- "$pattern" -- "$value"` sites
    trimmed; the redundant second `--` was consumed as an
    additional STRING argument.
  * Preflight: sudoers parser comment-strip uses `^[[:space:]]*#`
    POSIX class (was GNU `^\s*#` PCRE extension).


v4.5.6 - 2026-05-02
-------------------

  * Sudoers: NOPASSWD regex relaxed to accept the no-space
    `NOPASSWD:ALL` form and the `(root)` runas alternative.
  * Logging: dispatch-header argv redaction mirrors `_run`;
    `--token sekret` next-positional form redacted at the header.
  * Boot: `$PATH` pinned to canonical sbin/bin set immediately
    after fish-version gate. Defends against shadow binaries.
  * Boot: mkinitcpio rollback captures `printf | tee` `$pipestatus`.
  * Verify/Install: `/etc/fstab` readability prechecked.
  * `_run`: explicit `--` separator before $argv.
  * Externals: `command` prefix added at five preflight cmdsubst
    sites.
  * Refactor: `_content_*` printf args for sdboot-manage,
    mkinitcpio, NetworkManager split via `\` continuation
    (392/289/228-char single-line forms → ≤80 each).


v4.5.5 - 2026-05-02
-------------------

  * Comments: in-line review markers stripped (mirrors v4.5.2
    cleanup pass). Single-line annotation invariant retained;
    `# lint:ignore` and the script header preserved.
  * Footprint: 5,201 → 5,175 LOC.


v4.5.4 - 2026-05-02
-------------------

  * Packages: `_install_packages` captures pre-deploy
    mkinitcpio.conf bytes; on `pacman -Syu` failure the prior
    content is restored via atomic mv.
  * Install: `_ry_install_file` tracks file-read success
    separately from empty content — sudo lapse / EIO no longer
    masquerades as "current is empty".
  * Logging: `_log` recreates LOG_FILE if disappeared mid-run;
    rotation pipeline is pipestatus-gated; `_json_str` adds
    ASCII-clean fast path.
  * Validate: `*.fish` branch surfaces fish stderr as `_info`
    plus `VALIDATE_FISH_STDERR` JSONL event.
  * Boot: `RY_INSTALL_FORCE_BOOT_REBUILD` requires literal `=1`
    (was `set -q` accepting any value).
  * Refactor: credential redaction list hoisted to
    `_RY_SECRET_FLAGS` global; `_RY_MANAGED_FILE_COUNT` derived
    at runtime (was hardcoded `15`).

  Note: v4.5.3 was skipped due to regressions; v4.5.4
  selectively backports the v4.5.3 fixes that did not introduce
  regressions.


v4.5.3 - SKIPPED
----------------

  Tag never released. See note inside the v4.5.4 entry above.


v4.5.2 - 2026-05-01
-------------------

  * Bootstrap: snapshot reordered before `_RY_INSTALL_LOADED` set
    — re-source in same shell now works.
  * Run: `timeout --foreground` for parent→child signal
    propagation; first 5 stderr lines mirrored on rc≠0 under
    QUIET; `pkill -P` child reap before keepalive teardown.
  * Boot: `mkinitcpio -P` gated on `INSTALL_HAD_ERRORS=false`
    (override `RY_INSTALL_FORCE_BOOT_REBUILD=1`); umask 0177
    around boot-wipe marker mktemp.
  * Verify: pipestatus on LINUX_OPTIONS extraction; masked-services
    field-count pre-check; ntsync `case '*'` catchall.
  * Validate: `_chk_grep` distinguishes stage-1 sudo/read failure
    from stage-2 grep "not found"; pipestatus across stages.
  * Install-file: explicit `switch` hook dispatch; sudo keepalive
    when target writes to /boot or triggers boot rebuild.
  * Preflight: `sudo -n -l` stderr captured to JSONL.
  * Logging: redaction extended (`--apikey`, `--auth`, `--bearer`,
    `--cookie`, `--client-secret`, `--credential`); first `_log`
    write failure surfaced at exit.


v4.5.1 - 2026-05-01
-------------------

  * Preflight: GNU `timeout(1)` hard-required.
  * Argparse: `--install-file=` rejects empty values.
  * Logging: pre-dispatch `[WARN]` echoes routed through `_warn`.
  * Content fns: `_content__etc_kernel_cmdline` no longer calls
    `_err`; stdout-purity invariant strengthened.


v4.5.0 - 2026-04-30
-------------------

  * Profile: subsystem removed. `gtr9_pro` defaults inlined as
    `set -g` block at module init. Forking is the only path for
    other hardware.
  * Manifest: orphan tracking removed.
  * Bootstrap: `_init_runtime` (63 lines) replaces `_load_profile`.
  * Logging: JSONL event identifiers reduced and renamed.
  * Footprint: 5,335 → 4,941 LOC.

  Migration:
    rm -rf ~/.config/ry-install/profiles
    rm -f  ~/.config/ry-install/default-profile
    rm -f  ~/ry-install/.manifest


v4.4.36 - 2026-04-29
--------------------

  * Bootstrap: fish version gate raised 3.4 → 3.6.
  * Validation: `_chk_grep` strips comment lines; ntsync 5-state
    return.
  * UX: progress bar `Aborted at N%` on boot-critical skip;
    SIGWINCH re-anchor.


v4.4.x - 2026-04-25..04-29
--------------------------

  * Profile system + verify split (`--verify-static` /
    `--verify-runtime` / `--check`).
  * Locking: mkdir mutex + `flock(1)` stale reclaim.
  * Sudo keepalive: TERM → sleep → KILL teardown.
  * Helpers: `_pre_dispatch_exit`, `_unit_state`, `_check_avail`
    extracted; redaction loop unified.
  * Bootstrap: `_RY_INSTALL_LOADED` ordering (reverted in v4.5.2).


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256
    verification.


v4.2.x..v4.0.x - 2026-04-18..04-25
----------------------------------

  * Initial fish rewrite from v3.x bash.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
