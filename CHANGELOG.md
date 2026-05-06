ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.5.29 - 2026-05-06
--------------------

  * style: collapse `if X / Y / end` and `if X / Y1 / Y2 / end` blocks to inline `X; and Y` / `X; and Y1; and Y2` form across the script (137 sites, all chain-safe and `$status`-clean at the follow-line).
  * style: collapse `if X / return | continue | break / end` blocks to inline `X; and <ctrl>` form (19 sites).
  * style: fold `printf` and `set` backslash-continuation arg-lists onto single lines for the 7 embedded content generators and the 6 module-scoped multi-arg `set` blocks (14 sites). `printf` arg vectors and `string join \n` outputs byte-identical pre/post.
  * style: the 3 sites where the surrounding function ends on the if-block AND a current caller reads `$status` are preserved unchanged: `_content__etc_mkinitcpio.conf` (caller path: `_atomic_write_file` → `_ry_install_file` → `_ry_do_install_file`), and the foundational utilities `_log` / `_echo` (broad invocation surface; future status-reading callers would silently break under collapse).
  * style: Phase-5 collapse introduces a Y1-success gate on Y2 in the inline form. Y1 verbs in scope are exclusively the `_msg` family (`_err`/`_warn`/`_fail`/`_info`/`_ok`), `_log`, `set` of valid local/global names, `echo` to fd 2, and one `command rm -rf -- "$_run_dir" 2>/dev/null` inside a `test -d` guard — all return 0 in this script's invocation contexts. The shift is theoretical, not behavioural.
  * header: source line count 5495 → 5005. No flag, exit code, JSONL schema, or managed-file content changes.

  Migration: none. Behaviour-preserving.


v4.5.28 - 2026-05-04
--------------------

  * dispatch: `_ry_do_install_file` captures switch `$status` into `_switch_status` before the gate `test`; previously `test` clobbered `$status` so post-hook rc was always read as 0 and a failed `_post_boot` / `_post_service` under `--install-file` returned 0 to the dispatcher.
  * dispatch: top-level early-peek erases `_early_arg` on the no-flag fallthrough path (already erased on `-h` / `-v`).
  * structure: `_run` split into `_run_redact_argv` (per-element secret-flag eat, NUL-delimited stdout) + `_run_resolve_timeout` (RY_RUN_TIMEOUT validation, single-shot warn).
  * structure: `_verify_static_boot` split into `_vsb_loader` / `_vsb_sdboot` / `_vsb_cmdline` / `_vsb_mkinitcpio` / `_vsb_entries`.
  * structure: `_install_fstab_opts` split into `_fstab_needs_change` (scan; sets `_RY_FSTAB_NEEDS_CHANGE` / `_RY_FSTAB_COMMIT_OVERRIDES`) + `_fstab_atomic_replace` (mktemp /etc → awk → chmod/chown ref → findmnt verify → mv).
  * structure: `_preflight_boot_sanity` split into `_pbs_check_kernels` / `_pbs_check_initrds` / `_pbs_check_entries`; each takes ESP via `--argument-names esp`, emits integer error count on stdout, summed by orchestrator via `math`.
  * style: version-parse `if not CMD\n    or not CMD` collapsed to single-line `if not CMD; or not CMD` form.
  * style: `_ry_erase_handlers` comment corrected from "Adding a 7th handler?" to "Adding a 6th handler?" (5 handlers tracked).
  * style: `_msg` adds empty-body guard — log line still written, bare `[LEVEL] ` stderr print suppressed.
  * style: log-rotation `MAX_LOGS` reset uses explicit `set -g` for refactor-safety.
  * style: trim verbose comments throughout to single-line form.

v4.5.27 - 2026-05-04
--------------------

  * verify: `_verify_summary` now surfaces `VERIFY_GEN_FAIL` to stderr and treats it as a hard failure for the verdict; previously generator failures were logged only to JSONL footer and the user-facing summary reported "OK" despite N gen-failures.
  * verify: `_chk_grep` always uses `grep -wF` (whole-word) for both plain tokens and `k=v` patterns; eliminates substring false-positives where e.g. `wifi.backend=iwd` would match a drifted `wifi.backend=iwdfoo`. The `=`/`"`/`.` chars are non-word delimiters so k=v boundaries are still respected.
  * cleanup: `_do_cleanup` two-pass tmpfile sweep — plain `rm` first, then sudo-aware fallback for root-owned orphans in /etc, /boot, /var (only when sudo is non-interactive available). Closes the orphan-tmpfile gap when sudo lapses during `_atomic_write_file` mid-mv.
  * dispatch: `_run` rejects dash-prefixed `argv[1]` with rc 2 + `BUG: _run called with dash-prefixed argv[1]` log marker; previously `timeout(1)` would mis-parse the leading flag and return the misleading rc 125/127.
  * docs: `_ry_show_help` and the early `-h`/`-v` peek both note `NO_COLOR` accepts any non-empty value (matches the implementation in `_no_color_env` capture); previously help showed `NO_COLOR=1` only.
  * docs: README `Safety & Reliability` table — sysctl invariant rc corrected (12 → 13) to match `_content__etc_sysctl.d_99-cachyos-sysctl.conf` and the v4.5.26 dispatcher branch.
  * style: lowercased "Ssh-agent.service" → "ssh-agent.service" in user-facing `_warn` (matches systemd convention and README casing).
  * refactor: largest verify/install orchestrators split into focused helpers (each ≤90 lines):
      - `_verify_runtime_kparams` (209→25 + `_vrk_cmdline`/`_vrk_gpu_state`/`_vrk_cpu_state`/`_vrk_module_state`/`_vrk_clocksource_coredump` with shared `_RY_DMESG_CACHE`).
      - `_verify_runtime_env` (172→9 + `_vre_envvars`/`_vre_sysctl_runtime`/`_vre_tcp`/`_vre_thp_ksm`/`_vre_zram`/`_vre_fstab`/`_vre_ntsync`).
      - `_verify_runtime_session` (154→14 + `_vrs_nm_perms`/`_vrs_installed_file_perms`/`_vrs_parent_dirs`/`_vrs_vulkan`/`_vrs_boot_perf`).
      - `_verify_runtime_services` (153→7 + `_vrsv_chk_active_enabled`/`_vrsv_sys_units`/`_vrsv_ssh_agent`/`_vrsv_wifi`).
      - `_ry_do_check` (118→33 + `_check_phase_files`/`_check_phase_cmdline`/`_check_phase_units`/`_check_phase_user_ssh` with shared `_RY_CHECK_DRIFT`/`_RY_CHECK_FILES_CHECKED`).
      - `_install_packages` (128→90 + `_mkinitcpio_revert`).
      - `_install_rebuild_boot` (125→75 + `_boot_wipe_gate`/`_boot_initrd_size_scan`).

  Migration: `--verify-static` and `--verify-runtime` exit codes change when the *only* failure is generator failure: previously rc=0 ("OK" reported despite gen_fail in JSONL), now rc=1 ("FAIL" reported with `gen_fail=N` summary segment). All other behaviour preserved. JSONL `event=footer` schema unchanged.



  * boot: `_resolve_esp` final fallback to /boot emits `_warn` (was `_log`-only); ESP autodetect failure now surfaces at user-facing fd 2 with verification hint.
  * deps: `ping` added to `_ry_check_deps` soft-deps probe (used by `_ry_check_network` raw-IP fallback).
  * post-hooks: `_post_sysctl` probes `command -q sysctl` before invoking; clean degradation with install hint when procps-ng absent.
  * generators: sysctl content generator returns rc 13 (assertion failure) instead of rc 12 (missing prerequisite global) on count mismatch; `_atomic_write_file` dispatcher gains a distinct rc-13 branch.

  Migration: none. Behaviour-preserving on the happy path; only diagnostic and edge-case messaging changes.


v4.5.25 - 2026-05-03
--------------------

  * signals: `_cleanup` and `_cleanup_pipe` invoke `_ry_namespace_cleanup bail` before sourced return; fixes globals leak on signal-driven sourced exit. Same call added at the two dispatcher bail-out paths.
  * configuration: `_install_system_files` iterates `$SERVICE_DESTINATIONS` and exposes `_RY_DEPLOYED_SERVICES`; all 15 managed files deploy in Configuration phase, Services reduced to daemon-reload + enable.
  * verify: `_verify_unit_syntax` accepts optional `intended_scope`; `_verify_unit_content` derives scope from `$dst` so user-scope units verify with `--user`.
  * help: early-peek mirrors the full `_ry_show_help` body (EXIT CODES, ENVIRONMENT, `--` end-of-options).
  * string-match: replaced 3 `string match -qe` sites with `string match -q '*X*'` glob form.
  * keepalive: `fish --no-config -c` for the keepalive child (hermetic; skips user conf.d).
  * post-hooks: extracted `$_RY_POST_HOOKS` + `_post_hook_for_target` helper; two iteration sites in `_ry_do_install_file` now share one helper.
  * comments: dropped six stale source-line references and the hardcoded version pin in `RY_INSTALL_FORCE_BOOT_REBUILD` blurb.
  * README: Quick Start documents `chmod +x`; install-flow table reflects Configuration-phase consolidation.

v4.5.24 - 2026-05-04
--------------------

  * Re-source guard: `--help` / `--version` early-peek (L37-58) now
    erases `_RY_INSTALL_LOADED` and the 12 sibling globals it set
    (`_RY_PRE_GLOBALS`, `VERSION`, `EXIT_*`, `_RY_SECRET_FLAGS`,
    `_MY_UID`, `_RY_INSTALL_SOURCED`, `_RY_INSTALL_BAILING`,
    `_RY_INSTALL_LAST_EXIT`) before `exit 0`. Fish treats `exit` in
    a sourced script as `return` from the source, so the prior bare
    `exit 0` left those globals on the caller's shell and blocked
    re-source via the L4 guard. Exec-mode behaviour unchanged.
  * Logs: pre-mode-resolution log filename is now
    `preflight-$TIMESTAMP.jsonl` (was hardcoded `install-…jsonl`).
    Dispatch-time `mv` still promotes to `<mode>-$TIMESTAMP.jsonl`
    once `$MODE` is finalized; preflight-bail leaves an honest
    `preflight-…` artefact rather than a misleading `install-…`.
  * Logs: `_log` auto-create failure (mktemp/install/touch) now
    sets `_RY_LOG_WRITE_FAIL` so the dispatcher's "log incomplete"
    warning fires; previously silently dropped.
  * Cleanup: `_do_cleanup` now invokes `_kill_sudo_keepalive`
    by-PID BEFORE the `pkill -P $fish_pid` broadcast. Prior order
    had pkill -P kill the disowned-but-still-parented keepalive,
    rendering the per-PID TERM→sleep→KILL ladder a no-op.
  * `_run`: secret-flag redaction switched from joined-string regex
    to per-argv-element walk. Now redacts both `--flag=value` and
    `--flag value` (space-separated next argv element); space-
    separated values were previously leaked.
  * `_as`: bool guard rejects non-`true`/`false` `use_sudo` with
    `BUG: _as called with non-bool` log and rc=2; previously fell
    through silently to the `command` branch.
  * Verify-static: pipestatus capture on the boot-entries
    `sudo -n find … -print0 | string split0` pipe distinguishes
    "no entries found" from "sudo lapsed mid-traversal" — emits
    `_warn` rather than a misleading `_fail "Boot entries: NONE"`.
  * Preflight-boot-sanity: same pipestatus-capture pattern applied
    to the three internal `sudo find` pipes (vmlinuz, initramfs,
    loader entries).
  * Install-rebuild-boot: pipestatus capture on the post-rebuild
    initramfs size-check loop.
  * Verify-static-syntax: `fish --no-execute` on the embedded
    fish-script destination now captures stderr; first 5 lines
    surface via `_info` so syntax errors include line numbers.
  * Refactor: handler-erase line `functions -e _cleanup
    _cleanup_pipe _cleanup_on_exit _cleanup_other
    _progress_on_winch` extracted to `_ry_erase_handlers` helper;
    single source of truth for the 5-handler list.
  * Namespace: `_content_bytes` renamed to `_ry_content_bytes` to
    eliminate the collision class where a managed-destination key
    resolving to literal "bytes" would hit the helper instead of
    erroring via `functions -q` in `_ry_get_file_content`.
  * Comments: trim multi-line annotation blocks at the top-of-file
    header, the early-peek preamble, and the HOME-resolution gate
    into single-line form. Lint directives (`# lint:ignore (...)`,
    `# FISH-LINT-DIRECTIVE: do-not-format`) preserved.
  * Docs: README "Stderr surfacing" row clarifies that under
    `--verbose` the mirrored output is "stderr block then stdout
    block", not interleaved with the child's own stream-mixing.
    "Runtime Variables" rows for `CONFIRM_BOOT_WIPE` and
    `ALLOW_PARTIAL_UPGRADE` document the literal-`1` requirement
    (matches `FORCE_BOOT_REBUILD`). "Re-source guard" row updated
    to reflect early-peek cleanup.

  Migration: none. Behaviour-preserving everywhere except: source-
  mode `--help` / `--version` (was: leak globals and block re-
  source; now: clean re-sourceable); log filename for early-bail
  paths (was: misleading `install-…`; now: honest `preflight-…`);
  secret-flag redaction (was: missed space-separated values; now:
  redacts both `--flag=v` and `--flag v`); `_log` auto-create
  failure (was: silent drop; now: surfaces via
  `_RY_LOG_WRITE_FAIL`); boot-artefact enumeration (was:
  misleading "NONE" on sudo lapse; now: explicit "cannot
  enumerate" warning).


v4.5.23 - 2026-05-03
--------------------

  * Cleanup: `_MY_UID` now initialised before any `_ry_exit` gate fires
    (early bails at L115+ previously left `find -user $_MY_UID -delete`
    consuming the next arg as a user-name and silently no-op'ing the
    tmpfile sweep).
  * Signals: `USR1`, `USR2`, `ABRT` now bound via `_cleanup_other`
    (delegates to `_cleanup`); `_cleanup` switch gains 138/140/134
    exit-code mappings. `functions -e` cleanup paths erase
    `_cleanup_other` alongside the existing handler set.
  * Verify-static: `_chk_grep` distinguishes stage-1 `rc=1`
    (no non-comment lines) from `rc>=2` (read/IO error). Comment-only
    config files now report MISSING instead of misleading
    "sudo lapse or read error".
  * Verify-static: `_verify_unit_content` uses
    `mktemp --suffix=.service` (single call) and chmod's tmpfile to
    0600. Removes the post-mktemp rename window.
  * Verify-static: `_verify_static_syntax` rejects 0-byte
    `ssh-auth-sock.fish` before invoking `fish --no-execute`
    (truncated writes were reporting "syntax OK").
  * Verify-runtime: `_verify_runtime_session` captures `$pipestatus`
    on the `sudo find` of NM `*.nmconnection` files; sudo lapse now
    warns explicitly instead of falsely reporting "no .nmconnection
    files".
  * Verify-runtime: ssh-agent user-state probe routed through new
    `_unit_state_user` helper (parallels `_unit_state`).
  * Verify-runtime: `systemd-analyze` first-line parser gated on
    expected `= Ns` tail; future format changes degrade to
    "format unrecognized" instead of silent skip.
  * Install-file: `_post_hooks` list hoisted to top of
    `_ry_do_install_file`; keepalive-trigger globs derived from the
    same list (single source of truth, was duplicated).
  * Install-file: post-hook for-loop caches `string split` once per
    iteration instead of twice.
  * Detect: `_detect_lvm` logs `LVM_DETECT: method=<pvs|lsblk|none>
    result=<present|absent>` for diagnostic visibility.
  * Style: three multi-line `or set` continuations in
    `_verify_runtime_session` collapsed to single-line
    `cmd; or set X` form (matches the rest of the file).
  * Docs: function header for `_run` documents the
    "argv[1] PATH-resolvable external; no shell metachars" invariant
    inline. `_ORIG_ARGV` capture site annotated. Inline note at
    `LINUX_OPTIONS` extraction site flags the dependency on
    `KERNEL_PARAMS` hygiene.
  * Docs: pre-LOAD `--help` peek annotated with
    `MAINTENANCE: keep brief help below in sync with the full
    _ry_show_help body — fish does not hoist function defs.`
  * Docs: ssh-auth-sock content generator gains
    `# FISH-LINT-DIRECTIVE: do-not-format` for machine-readable
    lint suppression.

  Migration: none. Behaviour-preserving everywhere except early-bail
  paths (which now sweep tmpfiles correctly), `_chk_grep` on
  comment-only configs (warn → fail), and 0-byte fish-script
  verification (false-pass → fail).


v4.5.22 - 2026-05-03
--------------------

  * Verify-static: `_verify_static_checksum` no longer double-counts
    generator failures. Gen-fail branch decrements `VERIFY_FAIL` after
    `_fail` to keep `gen_fail` mutually exclusive of `fail` in the
    JSONL footer.
  * Verify-runtime: `NetworkManager.service` not-found now warns
    ("not installed (skipping)") instead of failing. Mirrors
    `nftables.service` handling.
  * Install-file: `case '*'` post-hook catchall annotated with
    break-before-overwrite intent (skips post-switch
    `set _hook_rc $status` zeroing).
  * Msg: `[$level]` prefix uses `printf '[%s]'` (was `echo -n`).
  * Comments: implicit-units note names units inline
    (`systemd-resolved.service`, `NetworkManager-dispatcher.service`)
    for grep discoverability.
  * Docs: README "System Services" table lists all 4 verified units
    plus implicit-conf-d-driven pair. "Stderr surfacing" row clarifies
    `--verbose` routes both streams to fd 2. Event-type ceiling
    softened from "~70" to "~65".

  Migration: none. Behaviour-preserving everywhere except verify-runtime
  on NM-not-installed systems (fail → warn).


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
