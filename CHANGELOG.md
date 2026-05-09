ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.6.12 - 2026-05-08
--------------------

  * lock: `_reclaim_stale_lock` adds `/proc/<pid>/cmdline` substring match for "ry-install" before refusing reclaim — defence-in-depth against fish-PID reuse by an unrelated fish process. Old behaviour blocked reclaim on bare `comm == fish` even when the new fish had no relation to ry-install.
  * preflight: `_ir_validate_counts` invariant set extended with `MKINITCPIO_HOOKS:11` + `MKINITCPIO_MODULES:1` — catches hook-order regressions before they corrupt the rendered `mkinitcpio.conf`.
  * docs: README adds Known-Issues entry for `Sudo keepalive process failed to start` (`_start_sudo_keepalive` warn path) plus matching Troubleshooting row; TOC updated.
  * release: 4.6.11 → 4.6.12.

v4.6.11 - 2026-05-08
--------------------

  * pkg: 8 read-only `pacman -Q*` / `-T` / `-Qi` invocations (`_should_skip_iwd`, `_verify_static_system`, `_verify_static_packages`, `_vrs_vulkan`, `_install_packages`, `_csp_remove_pkgs`, `_configure_services_pkg_remove`, `_if_nm_restart`) gain `command` prefix — shadow-immunity for users with autoloaded `~/.config/fish/functions/pacman.fish`; rest of script already uses `command pacman` / `sudo -n pacman` consistently.
  * keepalive: `_start_sudo_keepalive` child loop drops `2>/dev/null` on the breaking `sudo -n -v` so cred-expiry stderr lands in `SUDO_KEEPALIVE_ERR`; `_check_sudo_keepalive` now surfaces the specific reason instead of a generic warn. Successful refreshes remain silent.
  * style: `_ry_show_help` fallback comment annotates lockstep with `$PROFILE_DESC` (L686) and `$_RY_MANAGED_FILE_COUNT` (L706) — drift between hardcoded fallbacks and runtime globals would silently desync early-peek vs post-argparse `-h` output.
  * release: 4.6.10 → 4.6.11.

v4.6.10 - 2026-05-08
--------------------

  * install-file: `_ry_install_file` user-scope `mkdir -p` wrapped in `umask 0077` so newly-created intermediate dirs are 0700; counters umask 002 envs (USERGROUPS_ENAB) where 0775 trips `_awf_validate_parent`.
  * release: 4.6.9 → 4.6.10.

v4.6.9 - 2026-05-08
-------------------

  * atomic-write: `_atomic_write_file`, `_mkinitcpio_revert`, `_fstab_atomic_replace`, `_if_write_wipe_marker`, `_acquire_lock_fresh` use `mv -T` / `mv -Tf` — refuses target-as-directory.
  * lock: `_reclaim_stale_lock` liveness probe via `test -d /proc/$old_pid` (owner-independent); old `kill -0` returned EPERM=ESRCH=1 and skipped the fish-comm check against another user's running instance.
  * pacman: `_csp_remove_pkgs` and `_ip_pacman_invoke` re-test `/var/lib/pacman/db.lck` on failure; emits explicit "became locked during run" with `PKG_REMOVE_BATCH_FAIL_DBLOCK` JSONL marker.
  * aur: `_install_aur_packages` skips per-package retry when `count $AUR_PKGS ≤ 1` (single-pkg retry runs the same paru invocation twice).
  * check: `_check_phase_files` consumes `_installed_bytes` rc directly (0=ok / 1=drift / 2=preflight); old `test -z $actual` mis-mapped missing system files to preflight.
  * finalize: `_install_finalize` gates `_if_write_wipe_marker` on `INSTALL_HAD_ERRORS=false` so the marker hash never advances on a partially-failed deploy.
  * style: 6 multi-line comment blocks collapsed to single-line. Log-rotation comment corrected: only `string split0` returns rc=1 on empty input, `sort -zn` returns 0.
  * docs: README install-flow row reworded to `mask 11 desktop/power units (5 sleep targets + 6 service/socket masks; lvm2-monitor auto-skipped under LVM)`.
  * release: 4.6.8 → 4.6.9.

v4.6.8 - 2026-05-08
-------------------

  * boot: `_pbs_entry_has_valid_kernel` BLS Type #1 `linux=` resolution. Per uapi-group BLS, `linux=` is anchored on `$BOOT` regardless of leading slash. Strip leading `/+` then join as `$boot/$rel`. Containment check retained as `..`-traversal defence.
  * boot: new `_resolve_boot_path` (cached `_RY_BOOT_PATH`) using `bootctl -x`, falls back to `_resolve_esp`. `_preflight_boot_sanity` family operates on `$BOOT`; identical to ESP when no XBOOTLDR partition.
  * release: 4.6.7 → 4.6.8.

v4.6.7 - 2026-05-08
-------------------

  * packages: `ufw` removed from `PKGS_DEL` (8 → 7); `ufw.service` added to `MASK` (10 → 11).
  * preflight: `_ir_validate_counts` invariants refreshed `PKGS_DEL:7`, `MASK:11`.
  * docs: README `Packages` / `Masked Services` and help text resynced.
  * release: 4.6.6 → 4.6.7.

v4.6.6 - 2026-05-08
-------------------

  * boot: new `_bwg_managed_only` auto-acks `SDBOOT_REMOVE_EXISTING=yes` when every `loader/entries/*.conf` matches a `vmlinuz-*` (or `<name>-fallback`) sdboot-manage will regenerate. Foreign entries (`windows.conf` / `rescue.conf`) preserve refusal. Markers `BOOT_WIPE_AUTO_ACK` / `BOOT_WIPE_AUTO_ACK_DECLINE`.
  * pacnew: `_ip_scan_pacnew` re-deploys embedded content for `.pacnew` at managed paths and removes the file. `.pacsave` continues to warn. Markers `PACNEW_AUTO_HANDLED`, `PACNEW_AUTO_HANDLE_*_FAIL`, `PACSAVE_FOUND`.
  * packages: `_csp_filter_rdeps` opt-in cascade via `RY_INSTALL_PKG_REMOVE_CASCADE=1` — emits target plus installed reverse deps; default skip-with-warn unchanged.
  * release: 4.6.5 → 4.6.6.

v4.6.5 - 2026-05-08
-------------------

  * counters: `_msg` no longer gates `VERIFY_*` increments on `VERIFY_MODE`; install footer now reports real pass/fail/warn. ERR level also bumps `VERIFY_FAIL`.
  * log-rotation: `_rot_pipe_ok` narrowed to `pipestatus[1]` only — `string split0` rc=1 on empty input is benign.
  * packages: `libva-mesa-driver` → `mesa`; `lib32-libva-mesa-driver` → `lib32-mesa` (upstream removed standalone names around mesa 24.2.7).
  * preflight: new `_ntsync_per_kernel_state` / `_ntsync_check_installed_kernels` (advisory) — flags second installed kernel ≥6.14 missing ntsync pre-reboot.
  * release: 4.6.4 → 4.6.5.

v4.6.4 - 2026-05-08
-------------------

  * packages: `nftables` dropped from `PKGS_ADD` (14 → 13) and `nftables.service` from `EXPECTED_SERVICES` (4 → 3).
  * runtime-verify: `_vrsv_sys_units` 6-unit batch → 5-unit batch.
  * preflight: `PKGS_ADD:13` invariant.
  * release: 4.6.3 → 4.6.4.

v4.6.3 - 2026-05-08
-------------------

  * keepalive: critical fix — `_start_sudo_keepalive` child-fish loop used `--` against fish builtin `test`, which (unlike POSIX) rejects it. `--` removed from fish-builtin invocations; external GNU calls retain it.
  * progress: `_progress_init` appends explicit CUP after DECSTBM so cursor lands at scroll-region bottom. `_progress_on_winch` bracketed with DECSC/DECRC.
  * preflight: `_init_runtime` CPU model match switched to case-insensitive.
  * boot: install-error gating split — `_RY_BOOT_TAINTED` (boot-critical) vs `INSTALL_HAD_ERRORS`. `_install_rebuild_boot` gates on the former; service-runtime failures no longer block rebuild.
  * services: `_cse_batch_enable` distinguishes "enable ok, --now start failed" (warn, no taint) from "enable failed" (err, taint). New `ENABLE_OK_START_FAIL` marker.
  * keepalive: child stderr captured to tracked tmpfile; reason surfaced on premature exit.
  * release: 4.6.2 → 4.6.3.

v4.6.2 - 2026-05-08
-------------------

  * naming: `EXIT_GEN_SYSCTL=13` named constant (squashed to `EXIT_PREFLIGHT` at consumer).
  * preflight: `_ry_check_deps` hard-deps loop adds `sudo`, `df`, `mkdir`, `rmdir`.
  * release: 4.6.1 → 4.6.2.

v4.6.1 - 2026-05-08
-------------------

  * docs: `_ry_show_help` hoisted above early-arg loop; `-h`/`--help` paths emit byte-identical output.
  * naming: `EXIT_GEN_NOFN=11`, `EXIT_GEN_NOUUID=12` named constants.
  * dead-code: `string match -r` 4096-byte truncation drops unreachable `head -n 1`.
  * style: comment-pass; safe-lint markers preserved.
  * release: 4.6.0 → 4.6.1.

v4.6.0 - 2026-05-07
-------------------

  * release: minor version bump consolidating the 4.5.x point series. No functional changes vs v4.5.38.

v4.5.38 - 2026-05-07
--------------------

  * env-vars: drop `ENABLE_LAYER_MESA_ANTI_LAG=1` from `environment.d`. `ENV_VARS:11` invariant. README `Per-game overrides` deprecated list extended.

v4.5.37 - 2026-05-07
--------------------

  * env-vars: drop `PROTON_NO_WM_DECORATION=1` from `environment.d`. `ENV_VARS:12` invariant.

v4.5.36 - 2026-05-07
--------------------

  * correctness: tmpfile registration moved before validation at every `mktemp` site (closes signal-between-mktemp-and-set window).
  * correctness: `_ry_do_install_file` canonicalises `target` once at entry; keepalive trigger and post-hook dispatch use the same canonical path.
  * helpers: extract `_track_tmpfile` and `_resolve_systemd_ver` (cached major-version parse).
  * preflight: `_ir_validate_counts` promoted from comment-only to runtime asserts.
  * docs: README env-vars / logind / iwd-skip / data-directory entries refreshed.

v4.5.35 - 2026-05-07
--------------------

  * correctness: `_untrack_tmpfile` erases `_TRACKED_TMPFILES` when emptied (was leaking the name in sourced-caller scope on argparse-error path).

v4.5.34 - 2026-05-07
--------------------

  * structure: 19 oversized orchestrators split into focused helpers (each ≤90 lines).
  * style: multi-line comment blocks limited to the 2-line script header. Function count 200 → 239; LOC 5098 → 4849.

v4.5.33 - 2026-05-06
--------------------

  * helpers: extract `_redact_argv_elements` (NUL-emit, single source of truth); `_installed_bytes` rc-set 0=ok / 1=read fail / 2=sudo lapse.
  * structure: `_configure_services_preset` split into `_configure_services_resolved_restart` + `_configure_services_pkg_remove`.
  * naming: `_PROFILE_USES_NM` → `_PROFILE_USES_WIFI_BACKEND`.
  * correctness: `_grep_kparam` validates every declared `$KERNEL_PARAMS` member against rendered cmdline; `_boot_wipe_gate` hash error includes 16-char prefixes; `_fail "...(pipestatus=...)"` sites use `string join , -- $_ps` with `(empty)` fallback.
  * cross-site: `_grep_kv` argv-count BUG guard; `_configure_services_pkg_remove` `command -q pacman` guard; ssh-agent `--user enable` failure bumps `_ret`; `_mkinitcpio_revert` chmod/chown via `--reference=`.
  * dead-code: `$HOME/ry-install` → `_RY_HOME_DIR`; `3600` → `_RY_RUN_TIMEOUT_DEFAULT`.
  * UX: peek and `_ry_show_help` exit-code-3 wording harmonised to "preflight".
  * docs: README `Managed Files` cpupower-epp.service scope `System` → `Service`.

v4.5.32 - 2026-05-06
--------------------

  * UX: fatal preflight errs in `_init_runtime` surface to stderr regardless of `QUIET=true` via new `_err_loud` helper.

v4.5.31 - 2026-05-06
--------------------

  * structure: `_verify_static_system` (5 `_vss_*`), `_acquire_lock` (fresh + reclaim), `_vrk_gpu_state` (3 `_vrkg_*`) split.
  * helpers: `_msg_print`, `_msg_nocount`, `_fail_silent`.

v4.5.30 - 2026-05-06
--------------------

  * style: multi-line blocks confirmed limited to 2-line script header.
  * verify: `fish --no-execute` parse clean; embedded content sha256-identical to v4.5.29.

v4.5.29 - 2026-05-06
--------------------

  * style: 137 if-blocks → inline `X; and Y`; 19 control-flow blocks → inline; 14 `printf`/`set` arg-lists folded onto single lines.
  * header: 5495 → 5005 LOC. No functional or schema change.

v4.5.28 - 2026-05-04
--------------------

  * dispatch: `_ry_do_install_file` captures switch `$status` before gate test; early-peek erases `_early_arg` on no-flag path.
  * structure: `_run`, `_verify_static_boot`, `_install_fstab_opts`, `_preflight_boot_sanity` split into focused helpers.
  * style: version-parse if-blocks inlined; `_msg` empty-body guard; log-rotation `MAX_LOGS` reset uses explicit `set -g`.

v4.5.27 - 2026-05-04
--------------------

  * verify: `_verify_summary` surfaces `VERIFY_GEN_FAIL` and treats it as hard failure for verdict.
  * verify: `_chk_grep` always uses `grep -wF` (whole-word).
  * cleanup: `_do_cleanup` two-pass tmpfile sweep — plain `rm` then sudo-aware fallback for /etc, /boot, /var orphans.
  * dispatch: `_run` rejects dash-prefixed `argv[1]` with rc 2.
  * refactor: 7 largest verify/install orchestrators split into focused helpers (each ≤ 90 lines).
  * boot: `_resolve_esp` final fallback to /boot emits `_warn`.
  * deps: `ping` added to soft-deps probe.
  * post-hooks: `_post_sysctl` probes `command -q sysctl` first.
  * generators: sysctl content generator returns rc 13 on count mismatch.

  Migration: `--verify-static` / `--verify-runtime` rc when only failure is generator failure changed 0 → 1 with `gen_fail=N` in summary.

v4.5.25 - 2026-05-03
--------------------

  * signals: `_cleanup` / `_cleanup_pipe` invoke `_ry_namespace_cleanup bail` before sourced return.
  * configuration: `_install_system_files` iterates `$SERVICE_DESTINATIONS`; exposes `_RY_DEPLOYED_SERVICES`.
  * verify: `_verify_unit_syntax` accepts optional `intended_scope`; `_verify_unit_content` derives scope from `$dst`.
  * help: early-peek mirrors full `_ry_show_help`.
  * keepalive: `fish --no-config -c` for the keepalive child (hermetic).
  * post-hooks: `$_RY_POST_HOOKS` table + `_post_hook_for_target` helper.
