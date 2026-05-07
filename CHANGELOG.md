ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.5.33 - 2026-05-06
--------------------

  * helpers: extract `_redact_argv_elements` (NUL-emit, single source of truth for `--flag value` / `--flag=val` redaction); `_run_redact_argv` and the JSON header-build site become thin wrappers.
  * helpers: `_installed_bytes` rc-set expanded — 0=ok, 1=read fail, 2=sudo lapse; `_ry_install_file` 27-line read-current-bytes block collapses to 9, `SKIP_PROBE_SUDO_LAPSED` preserved via rc=2.
  * structure: `_configure_services_preset` split into `_configure_services_resolved_restart` + `_configure_services_pkg_remove` (single-concern functions).
  * naming: `_PROFILE_USES_NM` renamed to `_PROFILE_USES_WIFI_BACKEND` — global is set true on either nm.conf or iwd, so the original name was misleading.
  * correctness: `_grep_kparam` validates every declared `$KERNEL_PARAMS` member appears in the rendered cmdline (whole-token boundary regex, escaped). Catches generator regressions that drop params silently.
  * correctness: `_boot_wipe_gate` hash-mismatch error includes 16-char hash prefixes (`marked_hash=…[16] current_hash=…[16]`); count-only collisions diff-able from the user-facing error.
  * correctness: `_fail "…(pipestatus=…)"` sites use `string join , -- $_ps` with `(empty)` fallback. Handles arbitrary-length `$pipestatus` and the fish gotcha where empty cmdsub adjacent to literal text drops the entire concatenated argument.
  * cross-site: `_grep_kv` gains the argv-count BUG guard already present in the four sibling `_grep_*` helpers.
  * cross-site: `_atomic_write_file` function header documents the dual-return contract (rc=1 most paths; `EXIT_BOOT_CRIT` only on sudo lapse mid-mv).
  * cross-site: `_configure_services_pkg_remove` gains `command -q pacman` guard (mirrors `_verify_static_packages` sibling).
  * cross-site: `_configure_services_enable` iterates `$EXPECTED_SERVICES` filtered by `$_RY_DEPLOYED_SERVICES` and the new `$_RY_PKG_MANAGED_SERVICES`. Was hardcoded `fstrim.timer` + `nftables.service`; new EXPECTED_SERVICES auto-flow.
  * cross-site: ssh-agent `--user enable` failures bump `_ret` (parity with system-side enable for caller-signal consistency).
  * cross-site: `_mkinitcpio_revert` `chmod`/`chown` switched to `--reference=/etc/mkinitcpio.conf` (mirrors `_fstab_atomic_replace`); inherits the live file's mode/owner instead of hardcoded `644` / `root:root`.
  * dead-code: 4 redundant `set -g INSTALL_HAD_ERRORS true` bumps dropped from `_install_rebuild_boot` (caller `_ry_do_install` already bumps); 3 outer `_err "Failed to install: $dst"` dropped from `_install_system_files` (`_atomic_write_file` already `_fail`s on every failure path).
  * dead-code: `$HOME/ry-install` literal consolidated to `_RY_HOME_DIR` global (10 sites; the early-`_ry_exit` cleanup retains the literal — runs before this set is reachable).
  * dead-code: `3600` literal consolidated to `_RY_RUN_TIMEOUT_DEFAULT` global (6 sites — both help bodies plus `_run_resolve_timeout`); registered in `_early_cleanup`.
  * dead-code: defensive `MAX_LOGS` re-default removed (variable not env-overridable; canonical default at globals holds).
  * dead-code: `_install_system_files` collapses 3 `_had_failure` declarations to 1 + 2 inline resets; double `command -q pacman` probe in `_verify_static_packages` folded into single if/else.
  * readability: 3 `string match -q …; or X; and Y; and Z` chains rewritten as explicit `if … or … ; …; end` blocks (fish-version regex, wifi-backend detect, KERNEL_PARAMS hygiene).
  * readability: `_ry_do_install_file` post-hook dispatch rewritten as pre-validate (known-set `contains`) then `switch`; `case '*'` and the `_hook_rc` / `_switch_status` interleave eliminated.
  * readability: `_ry_do_install` `INSTALL_HAD_ERRORS` bump form harmonized to `not fn; and set …` across all 6 sites (was 4× this form + 2× `fn; or set …`).
  * readability: `_fstab_needs_change` probes use anchored `(^|,)opt(,|$)` regex throughout (was glob + regex mixed; symmetric across noatime/lazytime/commit=10).
  * UX: peek and `_ry_show_help` exit-code 3 wording harmonized to "preflight" across both help bodies and the README; "Modes are mutually exclusive" line and `Log:` line appear in both bodies; `HELP-TEXT SYNC:` anchor comments mark the two parallel sites.
  * docs: README `Managed Files` table — `cpupower-epp.service` scope corrected `System` → `Service`. `mkinitcpio rollback` row qualifies "rollback when pre-deploy backup succeeded; skipped on sudo lapse". `--check` exit-codes uses "preflight".
  * docs: CHANGELOG v4.5.27 typo fix (`patternsg` → `patterns`); orphaned bullets between v4.5.27 Migration paragraph and v4.5.25 folded into v4.5.27 above the Migration; v4.5.28 `_ry_erase_handlers` entry rewritten to match the actual L85 description text.
  * comments: docstring / inline annotations clarified for `_msg_print` (QUIET gate + `_err_loud` bypass), `_json_str` (lossy control-byte substitution), `_run` (`--kill-after=10` hardcoded grace), `_boot_wipe_gate` (legacy-marker deferred-rewrite), dispatcher-tail (`Log:` emits unconditionally by design), `_RY_SECRET_FLAGS` (long-flag-only contract).
  * style: comment-pass — verbose annotations from this release compressed to single-line form; multi-line comment blocks limited to the 2-line script header (kept by design).

v4.5.32 - 2026-05-06
--------------------

  * UX: fatal preflight errs in `_init_runtime` (root UUID detection, KERNEL_PARAMS hygiene) surface to stderr regardless of `QUIET=true` via new `_err_loud` helper.

v4.5.31 - 2026-05-06
--------------------

  * structure: `_verify_static_system` (91 LOC) split into 5 `_vss_*` sub-helpers + orchestrator (mirrors `_vsb_*` pattern).
  * structure: `_acquire_lock` (71 LOC) split into `_acquire_lock_fresh` + `_reclaim_stale_lock` + orchestrator.
  * structure: `_vrk_gpu_state` (66 LOC) split into 3 `_vrkg_*` sub-helpers + orchestrator.
  * helpers: extracted `_msg_print` (color stderr emit, no log/counter); added `_msg_nocount` and `_fail_silent`.
  * UX: boot-wipe gate first-run err message now reads `until the entry set changes (any add, remove, or rename)`.
  * docs: CHANGELOG v4.5.27 cross-reference corrected; v4.5.24 date corrected `2026-05-04` → `2026-05-03`.

v4.5.30 - 2026-05-06
--------------------

  * style: comment-pass review — multiline blocks confirmed limited to the 2-line script header; inline `# lint:ignore` directives confirmed required.
  * verify: `fish --no-execute` parse clean; 15 embedded content-generator outputs sha256-identical to v4.5.29.
  * docs: README version badge bump 4.5.29 → 4.5.30; CHANGELOG entries trimmed to terse bullet form.

v4.5.29 - 2026-05-06
--------------------

  * style: collapse `if X / Y / end` blocks to inline `X; and Y` form across the script (137 sites).
  * style: collapse `if X / return | continue | break / end` blocks to inline `X; and <ctrl>` form (19 sites).
  * style: fold `printf` and `set` backslash-continuation arg-lists onto single lines for the 7 embedded content generators and 6 module-scoped `set` blocks (14 sites).
  * style: 3 status-reading sites preserved unchanged (`_content__etc_mkinitcpio.conf`, `_log`, `_echo`).
  * header: source line count 5495 → 5005. No flag, exit code, JSONL schema, or managed-file content changes.

v4.5.28 - 2026-05-04
--------------------

  * dispatch: `_ry_do_install_file` captures switch `$status` into `_switch_status` before the gate `test`.
  * dispatch: top-level early-peek erases `_early_arg` on the no-flag fallthrough path.
  * structure: `_run` split into `_run_redact_argv` + `_run_resolve_timeout`.
  * structure: `_verify_static_boot` split into `_vsb_loader` / `_vsb_sdboot` / `_vsb_cmdline` / `_vsb_mkinitcpio` / `_vsb_entries`.
  * structure: `_install_fstab_opts` split into `_fstab_needs_change` + `_fstab_atomic_replace`.
  * structure: `_preflight_boot_sanity` split into `_pbs_check_kernels` / `_pbs_check_initrds` / `_pbs_check_entries`.
  * style: version-parse `if not CMD\n or not CMD` collapsed to single-line `if not CMD; or not CMD` form.
  * style: `_ry_erase_handlers` description rephrased to "single-source-of-truth for the handler list"; inline guidance reads "add new handlers here and at the definition" (5 handlers tracked).
  * style: `_msg` adds empty-body guard — log line still written, bare `[LEVEL] ` stderr print suppressed.
  * style: log-rotation `MAX_LOGS` reset uses explicit `set -g`.
  * style: trim verbose comments throughout to single-line form.

v4.5.27 - 2026-05-04
--------------------

  * verify: `_verify_summary` surfaces `VERIFY_GEN_FAIL` to stderr and treats it as a hard failure for the verdict.
  * verify: `_chk_grep` always uses `grep -wF` (whole-word) for both plain tokens and `k=v` patterns.
  * cleanup: `_do_cleanup` two-pass tmpfile sweep — plain `rm` first, then sudo-aware fallback for root-owned orphans in /etc, /boot, /var.
  * dispatch: `_run` rejects dash-prefixed `argv[1]` with rc 2 + `BUG: _run called with dash-prefixed argv[1]` log marker.
  * docs: `_ry_show_help` and the early `-h`/`-v` peek note `NO_COLOR` accepts any non-empty value.
  * docs: README `Safety & Reliability` table sysctl invariant rc corrected (12 → 13).
  * style: lowercased "Ssh-agent.service" → "ssh-agent.service" in user-facing `_warn`.
  * refactor: largest verify/install orchestrators split into focused helpers (each ≤90 lines):
      - `_verify_runtime_kparams` (209→25 + `_vrk_*` family).
      - `_verify_runtime_env` (172→9 + `_vre_*` family).
      - `_verify_runtime_session` (154→14 + `_vrs_*` family).
      - `_verify_runtime_services` (153→7 + `_vrsv_*` family).
      - `_ry_do_check` (118→33 + `_check_phase_*` family).
      - `_install_packages` (128→90 + `_mkinitcpio_revert`).
      - `_install_rebuild_boot` (125→75 + `_boot_wipe_gate` / `_boot_initrd_size_scan`).
  * boot: `_resolve_esp` final fallback to /boot emits `_warn`.
  * deps: `ping` added to `_ry_check_deps` soft-deps probe.
  * post-hooks: `_post_sysctl` probes `command -q sysctl` before invoking.
  * generators: sysctl content generator returns rc 13 (assertion failure) on count mismatch; `_atomic_write_file` dispatcher gains a distinct rc-13 branch.

  Migration: `--verify-static` and `--verify-runtime` exit codes change when the *only* failure is generator failure: previously rc=0, now rc=1 with `gen_fail=N` summary segment.

v4.5.25 - 2026-05-03
--------------------

  * signals: `_cleanup` and `_cleanup_pipe` invoke `_ry_namespace_cleanup bail` before sourced return.
  * configuration: `_install_system_files` iterates `$SERVICE_DESTINATIONS` and exposes `_RY_DEPLOYED_SERVICES`.
  * verify: `_verify_unit_syntax` accepts optional `intended_scope`; `_verify_unit_content` derives scope from `$dst`.
  * help: early-peek mirrors the full `_ry_show_help` body.
  * string-match: replaced 3 `string match -qe` sites with `string match -q '*X*'` glob form.
  * keepalive: `fish --no-config -c` for the keepalive child (hermetic).
  * post-hooks: extracted `$_RY_POST_HOOKS` + `_post_hook_for_target` helper.
  * comments: dropped six stale source-line references and the hardcoded version pin in `RY_INSTALL_FORCE_BOOT_REBUILD` blurb.

v4.5.24 - 2026-05-03
--------------------

  * Re-source guard: early-peek erases `_RY_INSTALL_LOADED` and 12 sibling globals before `exit 0`. Re-source via the L4 guard now works after `-h`/`-v`.
  * Logs: pre-mode-resolution log filename is `preflight-$TIMESTAMP.jsonl`; dispatch-time `mv` promotes once `$MODE` is finalized.
  * Logs: `_log` auto-create failure sets `_RY_LOG_WRITE_FAIL` so the dispatcher's "log incomplete" warning fires.
  * Cleanup: `_do_cleanup` invokes `_kill_sudo_keepalive` before the `pkill -P $fish_pid` broadcast.
  * `_run`: secret-flag redaction switched from joined-string regex to per-argv-element walk.
  * `_as`: bool guard rejects non-`true`/`false` `use_sudo` with `BUG: _as called with non-bool` log and rc=2.
  * Verify-static: pipestatus capture on the boot-entries `sudo -n find … -print0 | string split0` pipe.
  * Preflight-boot-sanity: pipestatus-capture pattern applied to the three internal `sudo find` pipes.
  * Verify-static-syntax: `fish --no-execute` captures stderr; first 5 lines surface via `_info`.
  * Refactor: handler-erase line extracted to `_ry_erase_handlers` helper.
  * Namespace: `_content_bytes` renamed to `_ry_content_bytes`.
  * Comments: trim multi-line annotation blocks; lint directives preserved.
  * Docs: README `Stderr surfacing` row clarifies `--verbose` mirrored output is stderr-block then stdout-block.

v4.5.23 - 2026-05-03
--------------------

  * Cleanup: `_MY_UID` initialised before any `_ry_exit` gate fires.
  * Signals: `USR1`, `USR2`, `ABRT` bound via `_cleanup_other`; `_cleanup` switch gains 138/140/134 mappings.
  * Verify-static: `_chk_grep` distinguishes stage-1 `rc=1` from `rc>=2`.
  * Verify-static: `_verify_unit_content` uses `mktemp --suffix=.service` and chmods tmpfile to 0600.
  * Verify-static: `_verify_static_syntax` rejects 0-byte `ssh-auth-sock.fish` before invoking `fish --no-execute`.
  * Verify-runtime: `_verify_runtime_session` captures `$pipestatus` on the `sudo find` of NM `*.nmconnection` files.
  * Verify-runtime: ssh-agent user-state probe routed through new `_unit_state_user` helper.
  * Verify-runtime: `systemd-analyze` first-line parser gated on expected `= Ns` tail.
  * Install-file: `_post_hooks` list hoisted to top of `_ry_do_install_file`.
  * Detect: `_detect_lvm` logs `LVM_DETECT: method=… result=…`.
  * Style: three multi-line `or set` continuations collapsed to single-line form.
  * Docs: `_run` function header documents the "argv[1] PATH-resolvable external; no shell metachars" invariant.

v4.5.22 - 2026-05-03
--------------------

  * Verify-static: `_verify_static_checksum` no longer double-counts generator failures.
  * Verify-runtime: `NetworkManager.service` not-found warns ("not installed (skipping)") instead of failing.
  * Install-file: `case '*'` post-hook catchall annotated with break-before-overwrite intent.
  * Msg: `[$level]` prefix uses `printf '[%s]'` (was `echo -n`).
  * Docs: README `System Services` table lists all 4 verified units plus implicit-conf-d-driven pair.

v4.5.21 - 2026-05-03
--------------------

  * Atomic-write: `_atomic_write_file` initialises `_sp` to empty (was literal `command`); fixes `timeout: failed to run command 'command'` rc 127 on every user-side write.

v4.5.20 - 2026-05-03
--------------------

  * Run: drop literal `--` between timeout(1)'s DURATION and COMMAND (consumed as the command name → rc 127).
  * Run: drop literal `--` between fish's `command` keyword and `$argv` in the `RY_RUN_TIMEOUT=0` fallback.
  * As: same `command --` fix in `_as` user-side branch.

v4.5.19 - 2026-05-03
--------------------

  * Bootstrap: fish-version probe uses `$FISH_VERSION` builtin (PATH not yet pinned).
  * Run: secret-flag redaction regex boundary widened from `(^| )` to `(^|\s)`; separator from `[ =]` to `[\s=]`.
  * Preflight: bare `grep -v` in `sudo -n -l` filter normalized to `command grep -v`.

v4.5.18 - 2026-05-03
--------------------

  * Dispatch: early `-h` / `--help` / `-v` / `--version` short-circuit inserted before the GNU-coreutils preflight gates.
  * Run: `_run` no longer caps subprocess stderr at 5 lines under `--verbose`.
  * Verify-runtime: `nftables.service` added to `sys_units`; `parsed[]` count raised 5→6.
  * Progress: `_progress_init` short-circuits under mosh.
  * Exit: `_ry_exit` removes orphan `LOG_FILE` / `LOG_DIR` (rmdir chain) when neither header nor log was written.

v4.5.17 - 2026-05-03
--------------------

  * Install-file: `_post_service` user branch probes `$XDG_RUNTIME_DIR/bus` before `systemctl --user enable --now`.
  * Install-file: `_ry_do_install_file` calls `_kill_sudo_keepalive` on both return paths.
  * Install-file: keepalive-launch glob match canonicalizes `$target` via local `realpath -m`.
  * Logging: `_log` sets `_RY_LOG_WRITTEN` on first successful append.
  * Logging: log-rotation `find` capped at `-maxdepth 2`.
  * Cleanup: `_cleanup_tmpfiles` no longer walks `/etc/NetworkManager/system-connections`.
  * Preflight: `_validate_kernel_params` `param_config_map` drops stale `nvme_core.=CONFIG_NVME_CORE` entry.

v4.5.16 - 2026-05-03
--------------------

  * Services: drop dead `_RY_IMPLICIT_SERVICES` global; unit names listed inline.

v4.5.15 - 2026-05-03
--------------------

  * Preflight: KERNEL_PARAMS hygiene gate refuses members containing whitespace or `"`.
  * Preflight: fractional-sleep probe sets `_RY_SLEEP_FRAC` for cleanup TERM→KILL gaps.
  * Sysctl: content generator returns rc 12 when printed line count ≠ `count $SYSCTL_VALUES`.
  * Install-file: post-hook dispatch table gains `*/fish/conf.d/*.fish|fish` mapped to `_post_fish`.
  * Verify-runtime: `systemctl --user show-environment` capture strips surrounding double-quotes.
  * Install: `_configure_services_enable` probes for an active user bus before `systemctl --user enable --now`.
  * Logging: section-event class captures content via anchored `^=== (.*) ===$` regex.
  * Boot: post-rebuild entry count reuses `_enum_boot_entries`.
  * Verify: `_chk_file` tries plain `test -f` before sudo for `/boot` paths.
  * Verify: `_progress_init` adds `tput cup 0 0` capability probe before pinning the bar.

v4.5.14 - 2026-05-03
--------------------

  * Verify: end-of-string anchor `$` in four single-quoted PCRE patterns reaching the regex engine as a literal dollar. Affected `_grep_kparam`, `_verify_static_boot`, `_ry_do_check`, `_verify_runtime_kparams` `rw` token checks.
  * Style: in-script narrative comments compressed to single-line annotations; blank lines stripped from function bodies (5262 → 4975 LOC).

v4.5.13 - 2026-05-03
--------------------

  * Packages: pacman flags follow Arch's no-partial-upgrade policy by default — `-Syu --needed`. Opt-in `-Sy` via `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` with warning.
  * Boot: `_install_rebuild_boot` no longer carries a standalone `-Syu` site; Packages phase is sole upgrade location.
  * Bug: `_RY_BOOT_PIPE_OK=false` returns EXIT_PREFLIGHT instead of proceeding with phantom 0-count.
  * Bug: `_atomic_write_file` switched to `|`-delimited `stat -c` format.
  * Verify: IWD DriverQuirks and ENV_VARS checks compare full `key=value`.
  * Verify: `rw` token verified across four cmdline check sites.

  Migration: default invocation now runs `pacman -Syu --needed`.

v4.5.12 - 2026-05-03
--------------------

  * Style: normalize bare → `command` for `grep`, `stat`, `sed`, `realpath`. PATH pinned, no functional change.
  * Style: bootstrap stderr at L150 uses `[ERR]` prefix to match other 14 bootstrap stderr emits.

v4.5.11 - 2026-05-03
--------------------

  * Tuning: drop 5 sysctl entries (`vm.swappiness=100`, `kernel.split_lock_mitigate=0`, `net.core.busy_read=50`, `net.core.busy_poll=50`, `net.core.netdev_budget=600`); SYSCTL_VALUES count 21 → 16.

v4.5.10 - 2026-05-03
--------------------

  * Bug: `_ry_check_deps` aborted preflight on missing paru; contradicted soft-fail contract. Now `_warn` + `_info`.
  * Bug: `_ry_do_check` masked / implicit / Phase 4 / Phase 5 / Phase 2 paths return EXIT_PREFLIGHT (not silent drift) on `ERR_NO_DATA` or generator rc 11/12.
  * Reliability: `_ry_do_check` Phase 1 probes `command -q systemctl`; `_SYS_TMP_DIRS`, `_USR_TMP_DIRS`, `_PROFILE_USES_NM` initialized at top-of-file (later renamed `_PROFILE_USES_WIFI_BACKEND` in v4.5.33).
  * Refactor: `_content_bytes` terminal `string collect` carries `--allow-empty`.

v4.5.9 - 2026-05-03
-------------------

  * Bug: secret-flag redaction in `_run` and dispatch header logger emitted "Invalid index value" runtime errors. Fixed by close-quoting the pattern.
  * Bug: dispatch-header `argv` field corrupted argv elements containing spaces. Replaced join-then-split with per-element redact loop.
  * Reliability: `_unit_state_padded` returns `ERR_NO_DATA` sentinels when systemctl produces fewer than 3 fields.
  * Reliability: stale-lock detection cross-checks `/proc/<old_pid>/comm` against `fish` before refusing.
  * Refactor: extract `_start_sudo_keepalive`; `_pre_dispatch_exit` delegates to `_pre_dispatch_log_cleanup` + `_ry_exit`.

v4.5.8 - 2026-05-02
-------------------

  * Refactor: extract `_rm_tmp` and `_is_symlink` helpers (replaces 27 instances of the 2-line pattern).
  * Refactor: extract `_enum_boot_entries` helper (replaces 14-line find/sort/split0 block).
  * Footprint: 5,240 → 5,205 LOC.

v4.5.7 - 2026-05-02
-------------------

  * Boot: mkinitcpio rollback gates `chmod 644` and `chown root:root` on explicit success checks (later switched to `--reference=` in v4.5.33).
  * Logging: `_pre_dispatch_log_cleanup` and `_pre_dispatch_exit` preserve `LOG_FILE` when the dispatch JSONL header was already written.
  * Verify: `_verify_unit_content` drops GNU-only `mktemp --suffix=.service`; uses `mktemp -t` + explicit `mv`.
  * Refactor: 7 `string match -qr -- "$pattern" -- "$value"` sites trimmed (redundant second `--` was consumed as additional STRING arg).
  * Preflight: sudoers parser comment-strip uses `^[[:space:]]*#` POSIX class.

v4.5.6 - 2026-05-02
-------------------

  * Sudoers: NOPASSWD regex relaxed to accept the no-space `NOPASSWD:ALL` form and the `(root)` runas alternative.
  * Logging: dispatch-header argv redaction mirrors `_run`.
  * Boot: `$PATH` pinned to canonical sbin/bin set immediately after fish-version gate.
  * Boot: mkinitcpio rollback captures `printf | tee` `$pipestatus`.
  * Verify/Install: `/etc/fstab` readability prechecked.
  * `_run`: explicit `--` separator before `$argv` (later removed in v4.5.20 — `timeout(1)` consumed it as command name).
  * Externals: `command` prefix added at five preflight cmdsubst sites.
  * Refactor: `_content_*` printf args for sdboot-manage, mkinitcpio, NetworkManager split via `\` continuation.

v4.5.5 - 2026-05-02
-------------------

  * Comments: in-line review markers stripped (single-line annotation invariant retained; `# lint:ignore` and script header preserved).
  * Footprint: 5,201 → 5,175 LOC.

v4.5.4 - 2026-05-02
-------------------

  * Packages: `_install_packages` captures pre-deploy mkinitcpio.conf bytes; on `pacman -Syu` failure the prior content is restored via atomic mv.
  * Install: `_ry_install_file` tracks file-read success separately from empty content.
  * Logging: `_log` recreates LOG_FILE if disappeared mid-run; rotation pipeline pipestatus-gated; `_json_str` adds ASCII-clean fast path.
  * Validate: `*.fish` branch surfaces fish stderr as `_info` plus `VALIDATE_FISH_STDERR` JSONL event.
  * Boot: `RY_INSTALL_FORCE_BOOT_REBUILD` requires literal `=1`.
  * Refactor: credential redaction list hoisted to `_RY_SECRET_FLAGS`; `_RY_MANAGED_FILE_COUNT` derived at runtime.

  Note: v4.5.3 was skipped due to regressions; v4.5.4 selectively backports the v4.5.3 fixes that did not regress.

v4.5.3 - SKIPPED
----------------

  Tag never released. See note inside the v4.5.4 entry.

v4.5.2 - 2026-05-01
-------------------

  * Bootstrap: snapshot reordered before `_RY_INSTALL_LOADED` set — re-source in same shell now works.
  * Run: `timeout --foreground` for parent→child signal propagation; first 5 stderr lines mirrored on rc≠0 under QUIET; `pkill -P` child reap before keepalive teardown.
  * Boot: `mkinitcpio -P` gated on `INSTALL_HAD_ERRORS=false` (override `RY_INSTALL_FORCE_BOOT_REBUILD=1`); umask 0177 around boot-wipe marker mktemp.
  * Verify: pipestatus on LINUX_OPTIONS extraction; masked-services field-count pre-check; ntsync `case '*'` catchall.
  * Validate: `_chk_grep` distinguishes stage-1 sudo/read failure from stage-2 grep "not found".
  * Install-file: explicit `switch` hook dispatch; sudo keepalive when target writes to /boot or triggers boot rebuild.
  * Preflight: `sudo -n -l` stderr captured to JSONL.
  * Logging: redaction extended (`--apikey`, `--auth`, `--bearer`, `--cookie`, `--client-secret`, `--credential`).

v4.5.1 - 2026-05-01
-------------------

  * Preflight: GNU `timeout(1)` hard-required.
  * Argparse: `--install-file=` rejects empty values.
  * Logging: pre-dispatch `[WARN]` echoes routed through `_warn`.
  * Content fns: `_content__etc_kernel_cmdline` no longer calls `_err`; stdout-purity invariant strengthened.

v4.5.0 - 2026-04-30
-------------------

  * Profile: subsystem removed. `gtr9_pro` defaults inlined as `set -g` block at module init.
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
  * Validation: `_chk_grep` strips comment lines; ntsync 5-state return.
  * UX: progress bar `Aborted at N%` on boot-critical skip; SIGWINCH re-anchor.

v4.4.x - 2026-04-25..04-29
--------------------------

  * Profile system + verify split (`--verify-static` / `--verify-runtime` / `--check`).
  * Locking: mkdir mutex + `flock(1)` stale reclaim.
  * Sudo keepalive: TERM → sleep → KILL teardown.
  * Helpers: `_pre_dispatch_exit`, `_unit_state`, `_check_avail` extracted.
  * Bootstrap: `_RY_INSTALL_LOADED` ordering (reverted in v4.5.2).

v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256 verification.

v4.2.x..v4.0.x - 2026-04-18..04-25
----------------------------------

  * Initial fish rewrite from v3.x bash.

v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
