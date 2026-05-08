ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.5.36 - 2026-05-07
--------------------

  * correctness: tmpfile registration moved before validation at every `mktemp` site (`_run`, `_verify_unit_content`, `_atomic_write_file`, `_mkinitcpio_revert`, `_fstab_atomic_replace`, `_if_write_wipe_marker`, top-level argparse error capture). Closes the signal-arrives-between-`mktemp`-and-`set -ga` window where an interrupted child could leave an unknown tmpfile on disk; `_cleanup_tmpfiles` name-prefix sweep already bounded blast radius, but per-run cleanup is now exact.
  * correctness: `_ry_do_install_file` canonicalises `target` once at entry (`realpath -m`) and reuses for both the `boot`-tag keepalive trigger and the post-hook dispatch. Previously `_post_hook_for_target` was called twice with raw vs canonicalised paths; non-canonical user input could route the keepalive trigger and the hook dispatch to different rules.
  * helpers: extract `_track_tmpfile` (single source of truth for non-empty + non-/dev/null tmpfile registration; replaces 11 `set -ga _TRACKED_TMPFILES` call sites including the four pre-existing `test "$X" != /dev/null; and set -ga` sentinel-guarded forms).
  * helpers: extract `_resolve_systemd_ver` (single source of truth for cached `systemctl --version` major-number parse; replaces three inline lazy-init blocks at `_content__etc_systemd_logind*`, `_check_env_ssh_auth_sock`, and `_vss_logind`).
  * preflight: `_ir_validate_counts` promoted from comment-only invariants to runtime asserts in `_init_runtime`. `KERNEL_PARAMS=15`, `LOGIND_IGNORE_KEYS=9`, `ENV_VARS=13`, `SYSCTL_VALUES=16`, `PKGS_ADD=14`, `PKGS_DEL=8`, `AUR_PKGS=1`, `MASK=10`. Drift returns `EXIT_PREFLIGHT` via `_err_loud`.
  * dead-code: `# PKGS_ADD=14 PKGS_DEL=8 AUR=1 must equal README counts` and `# MASK=10 must equal README Masked Services count` invariant comments dropped (now enforced at runtime).
  * docs: README `Environment Variables` section corrected from 13 vars → 14 vars; `SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket` row added (emitted by the generator but absent from the table — required for systemd-user services to find the local agent socket regardless of fish/conf.d session-priority logic).
  * docs: README `logind.conf.d` row notes `HandleSecureAttentionKey` requires systemd ≥ 256; emitted-key count is 9 on ≥ 256, 8 on 252–255 (mirrors generator gate).
  * docs: README `Network Stack` adds caveat block: when `iwd` is not installed at install-time, both `iwd/main.conf` and `NetworkManager/conf.d/99-cachyos-nm.conf` are skipped via `_should_skip_iwd`.
  * docs: README `Data Directory & Logs` event-type list refreshed to enumerate prefix families instead of a stale total.
  * docs: README version badge bump 4.5.35 → 4.5.36.

v4.5.35 - 2026-05-07
--------------------

  * correctness: `_untrack_tmpfile` erases `_TRACKED_TMPFILES` when the working list empties; previously `set -g _TRACKED_TMPFILES $_new` recreated the global as an empty list, leaving the name in a sourcing caller's scope when the post-bail sweep ran (argparse-error path only).
  * style: single inline comment relocated to its own line above the annotated code (`case 0` switch arm). `# lint:ignore` and `# FISH-LINT-DIRECTIVE` markers and the script-header line preserved in place.
  * docs: README version badge bump 4.5.34 → 4.5.35.

v4.5.34 - 2026-05-07
--------------------

  * structure: `_ry_do_install_file` (90 LOC) split into `_idf_match_dst` + `_idf_dispatch_hook` + orchestrator (25 LOC).
  * structure: `_atomic_write_file` (89 LOC) split into `_awf_validate_parent` + `_awf_render_to_tmp` + orchestrator (34 LOC).
  * structure: `_install_packages` (87 LOC) split into `_ip_snapshot_mkinitcpio` + `_ip_pacman_invoke` + `_ip_scan_pacnew` + orchestrator (39 LOC).
  * structure: `_ry_do_install` (76 LOC) split into `_rdi_run_phases` + `_rdi_summary` + orchestrator (43 LOC).
  * structure: `_install_finalize` (73 LOC) split into `_if_write_wipe_marker` + `_if_trim_pacman_cache` + `_if_nm_restart` + orchestrator (26 LOC).
  * structure: `_ry_validate_configs` (66 LOC) split into `_rvc_fish_syntax` + `_rvc_dispatch` + orchestrator (33 LOC).
  * structure: `_configure_services_enable` (63 LOC) split into `_cse_collect_units` + `_cse_batch_enable` + `_cse_ssh_agent` + orchestrator (24 LOC).
  * structure: `_vrsv_sys_units` (61 LOC) split into `_vrsv_chk_cpupower` + `_vrsv_chk_resolved` + `_vrsv_chk_nm_dispatcher` + `_vrsv_chk_fstrim` + orchestrator (26 LOC).
  * structure: `_init_runtime` (60 LOC) split into `_ir_resolve_root_uuid` + `_ir_validate_timing` + `_ir_precompute_caches` + orchestrator (27 LOC).
  * structure: `_verify_static_packages` (59 LOC) split into `_vsp_required` + `_vsp_aur` + `_vsp_removed` + `_vsp_pacman_conf` + orchestrator (24 LOC).
  * structure: `_pbs_check_entries` (55 LOC) split — extracts `_pbs_entry_has_valid_kernel`; orchestrator 27 LOC.
  * structure: `_install_preflight` (55 LOC) split — extracts `_ip_probe_sudo_policy`; orchestrator 31 LOC.
  * structure: `_chk_grep` (55 LOC) split — extracts `_cg_access_ok`; orchestrator 34 LOC.
  * structure: `_install_rebuild_boot` (54 LOC) split into `_irb_sdboot_apply` + `_irb_verify_entries` + orchestrator (26 LOC).
  * structure: `_configure_services_pkg_remove` (53 LOC) split into `_csp_filter_rdeps` + `_csp_remove_pkgs` + orchestrator (33 LOC).
  * structure: `_boot_wipe_gate` (52 LOC) split — extracts `_bwg_eval_marker`; orchestrator 32 LOC.
  * structure: `_install_system_files` (51 LOC) split — extracts `_isf_deploy_set`; orchestrator 24 LOC.
  * structure: `_fstab_atomic_replace` (51 LOC) split — extracts `_far_awk_rewrite`; orchestrator 32 LOC.
  * structure: `_check_phase_units` (51 LOC) split — extracts `_cpu_chk_expected`; orchestrator 34 LOC.
  * style: comment-pass — verbose rationale annotations compressed; multi-line comment blocks limited to 2-line script header. Function count 200 → 239; source 5098 → 4849 LOC.
  * docs: README footer version bump 4.5.33 → 4.5.34.

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
