ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.6.7 - 2026-05-08
-------------------

  * packages: `ufw` removed from `PKGS_DEL` (8 → 7). The package is no longer uninstalled by ry-install — installations that pulled `ufw` in via meta-package dependencies (`ufw-extras`-style) are no longer subject to cascade-or-skip arithmetic on every run.
  * services: `ufw.service` added to `MASK` (10 → 11), inserted between `systemd-coredump.socket` and the sleep/suspend target block. Mask is applied unconditionally — `systemctl mask` writes the `/dev/null` symlink whether or not the unit file is present, so the mask survives subsequent `ufw` package install or removal and prevents auto-start in either state.
  * preflight: `_ir_validate_counts` invariants `PKGS_DEL:8` → `PKGS_DEL:7` and `MASK:10` → `MASK:11`. Drift assert continues to refuse deploy on any further unexpected count change.
  * docs: `_ry_show_help` `RY_INSTALL_PKG_REMOVE_CASCADE` line had `(e.g. ufw-extras pulled in with ufw)` parenthetical dropped — `ufw` is no longer a `PKGS_DEL` member, so the example was stale; description is now generic. README `Packages` `Remove` row count `8` → `7` with `ufw` dropped from the package list; new NOTE callout for the cascade env var also dropped the `ufw-extras blocking ufw` example. README `Masked Services` count `10` → `11`; new `ufw.service` row inserted with reason "Firewall not used on this profile (mask retained even if `ufw` package is installed; mask survives package install/removal)". README `Runtime Variables` `RY_INSTALL_PKG_REMOVE_CASCADE` row also dropped the stale `ufw` example.
  * release: patch version bump `4.6.6` → `4.6.7` (script header line 2 + `set -g VERSION` + README badge).

v4.6.6 - 2026-05-08
-------------------

  * boot: new `_bwg_managed_only` helper — auto-acks `SDBOOT_REMOVE_EXISTING=yes` when every `$esp/loader/entries/*.conf` corresponds to a kernel `sdboot-manage gen` will regenerate from `$esp/vmlinuz-*` (i.e. entry basename matches `<vmlinuz-name>` or `<vmlinuz-name>-fallback`). Wired into `_boot_wipe_gate` as a third ack source after env-var (`RY_INSTALL_CONFIRM_BOOT_WIPE=1`) and marker file. Was: first-run installs without the env var or marker were unconditionally refused at the wipe gate, returning `EXIT_BOOT_CRIT` (4) and skipping `[6/6] Finalize`. Reproduced in v4.6.5 install log: `mkinitcpio -P` succeeded for both kernels, then `_boot_wipe_gate` rejected 2 entries (`linux-cachyos.conf` + `linux-cachyos-lts.conf`, both regenerable) — initramfs rebuilt but loader entries left stale. New JSONL markers `BOOT_WIPE_AUTO_ACK` (entries + managed_kernels list) and `BOOT_WIPE_AUTO_ACK_DECLINE` (foreign_entries list when refusal still warranted, e.g. `windows.conf` / `rescue.conf`). Refusal err message updated to "Foreign entries detected" and ack path emits `_info` (auto) vs `_warn` (env/marker). Marker writer (`_if_write_wipe_marker`) unchanged — auto-ack runs still record the entry-set hash on first successful run, so subsequent runs hit the fast marker-match path.
  * pacnew: `_ip_scan_pacnew` no longer leaves `.pacnew` files at managed destinations as a user-action request. For each `.pacnew` at a `SYSTEM_DESTINATIONS` / `SERVICE_DESTINATIONS` path, the embedded content is re-deployed via `_ry_install_file` (idempotent — no-op when the live file already matches) and the `.pacnew` is removed via `_run sudo -n rm -f --`. The script's embedded content is the source of truth for managed paths; the upstream package default the `.pacnew` records is irrelevant to the managed deploy. `.pacsave` continues to warn (separate scan branch — package removal is out-of-scope for auto-resolve). New JSONL markers `PACNEW_AUTO_HANDLED` (per file resolved), `PACNEW_AUTO_HANDLE_DEPLOY_FAIL` / `PACNEW_AUTO_HANDLE_RM_FAIL` (failure paths that fall through to warn), `PACSAVE_FOUND` (was `PACNEW_FOUND` covering both — split). Reproduced in v4.6.5 install log: `/etc/mkinitcpio.conf.pacnew` warned every run, surviving across runs because nothing removed it.
  * packages: `_csp_filter_rdeps` opt-in cascade. New env var `RY_INSTALL_PKG_REMOVE_CASCADE=1` — when set and a `PKGS_DEL` member has installed reverse deps outside `PKGS_DEL`, the function emits the target plus its rdeps (one per line) instead of skipping. Caller `_configure_services_pkg_remove` updated to consume multi-line stdout via `for _emit in (_csp_filter_rdeps "$pkg")` with `contains` dedupe across iterations (covers the case where a cascaded rdep is also `PKGS_DEL`-listed under another iteration). Default behaviour unchanged: blocked package skipped with warn. Reproduced in v4.6.5 install log: `ufw has reverse dependencies: ufw-extras — skipping` — `ufw` is `PKGS_DEL`-listed but `ufw-extras` (not listed, installed via `cachyos-firewall-meta`-style pull) blocked removal indefinitely. Skip-warn message extended with the cascade hint.
  * docs: `_ry_show_help` env-var block extended with `RY_INSTALL_PKG_REMOVE_CASCADE` row and the `RY_INSTALL_CONFIRM_BOOT_WIPE` description gained an `(override; auto-ack handles managed-only entry sets)` qualifier.
  * release: patch version bump `4.6.5` → `4.6.6` (script header line 2 + `set -g VERSION` + README badge).

v4.6.5 - 2026-05-08
-------------------

  * counters: `_msg` no longer gates `VERIFY_OK` / `VERIFY_FAIL` / `VERIFY_WARN` increments on `VERIFY_MODE=true`. Install-mode runs were silently emitting `pass=0,fail=0,warn=0,gen_fail=0` in the JSONL footer regardless of how many `_warn` / `_err` events fired (reproduced in v4.6.3 install log: footer claimed all-zero despite 6 err lines around the boot-wipe gate). Counter resets in `_ry_verify_static` / `_ry_verify_runtime` (lines ~2535 and ~3465) keep verify-mode summaries clean. ERR level now also bumps `VERIFY_FAIL` (was unincremented under either mode).
  * log-rotation: `_rot_pipe_ok` check narrowed from "all 3 pipestatus stages == 0" to "pipestatus[1] (find) == 0". `sort -zn` and `string split0` both return rc=1 on empty input — the steady-state benign case when no prior logs are present to rotate. Previous behaviour emitted spurious `LOG_ROTATION_SKIP: pipestatus=0,0,1` markers and skipped trim of stale logs once `MAX_LOGS` was reached.
  * packages: `libva-mesa-driver` → `mesa`, `lib32-libva-mesa-driver` → `lib32-mesa` in `PKGS_ADD`. Confirmed via Arch package metadata: `mesa` Provides/Replaces/Conflicts `libva-mesa-driver<1:24.2.7-1` (and same for lib32 variant) — standalone `libva-mesa-driver` package was removed from upstream around mesa 24.2.7. Pacman silently resolved the obsolete name via virtual provides on every install (visible as `warning: mesa-2:26.0.6-2 is up to date -- skipping` in v4.6.3 install log when `libva-mesa-driver` was requested). PKGS_ADD count unchanged at 13.
  * preflight: new helpers `_ntsync_per_kernel_state` (returns `builtin|module|missing` from `/lib/modules/$kver/modules.builtin` and `modules.dep`) and `_ntsync_check_installed_kernels` (walks `/lib/modules/*/`, gates by ≥6.14, advisory only). Wired into `_ry_check_kernel_version` (preflight) and `_vss_ntsync_modules` (verify-static) under a new `── Per-installed-kernel ntsync metadata ──` section. Was: only the running kernel's ntsync state was checked (via `/proc/config.gz` / `/dev/ntsync` / `/proc/modules`); a second installed kernel (e.g. `linux-cachyos-lts` alongside `linux-cachyos`) could be missing ntsync and the preflight would not detect it pre-reboot.
  * release: patch version bump `4.6.4` → `4.6.5` (script header line 2 + `set -g VERSION` + README badge).

v4.6.4 - 2026-05-08
-------------------

  * packages: `nftables` removed from `PKGS_ADD` (14 → 13). The package is no longer installed or managed by ry-install. Users who want a nftables-based firewall should install and configure it manually.
  * services: `nftables.service` removed from `EXPECTED_SERVICES` (4 → 3 entries: `cpupower-epp.service`, `fstrim.timer`, `NetworkManager.service`). No longer enabled or verified by `_configure_services_enable` / `_cpu_chk_expected` / `_check_phase_units`.
  * runtime-verify: `_vrsv_sys_units` collapsed from 6-unit batch to 5-unit batch (dropped trailing `_vrsv_chk_active_enabled nftables.service "$parsed[6]"` call and the corresponding `nftables.service` entry from the `sys_units` list). Function description updated.
  * preflight: `_ir_validate_counts` invariant `PKGS_ADD:14` → `PKGS_ADD:13` (matches new package count). Drift assert continues to refuse deploy on any further unexpected count change.
  * docs: README — `nftables` dropped from the `Install` row in the package count table (14 → 13); `nftables.service` row removed from the `System Services` table; service-runtime example in both `IMPORTANT` callouts (`Initramfs rebuild refuses…` and `mkinitcpio -P is not invoked…`) reworded to a generic `systemctl enable --now` start-failure example; troubleshooting row for `Enabled but failed to start: <unit>` reworded with the nftables-specific tail dropped; package-install Services bullet pruned (`cpupower-epp.service`, `fstrim.timer`, `NM-dispatcher`).
  * release: patch version bump `4.6.3` → `4.6.4` (script header line 2 + `set -g VERSION` + README badge).

v4.6.3 - 2026-05-08
-------------------

  * keepalive: critical fix — `_start_sudo_keepalive`'s child-fish loop body used `test -d -- "$argv[2]"` against fish's builtin `test`, which (unlike GNU/POSIX `test`) does not accept the `--` end-of-options separator and aborts with `unexpected argument at index 3`. Loop never reached its first `sleep $SUDO_KEEPALIVE_INTERVAL`, so the keepalive child died ~immediately and every subsequent `_check_sudo_keepalive` warned spuriously. Removed `--` from the fish-builtin invocation; external `command kill -0 --` and `command stat -c %i --` retained (those are GNU `kill`/`stat` and accept it). Reproduced in fish 3.7.0 stand-alone harness pre-fix; verified loop iterates and exits cleanly on lock removal post-fix.
  * progress: `_progress_init` — DECSTBM (`CSI Ps;Ps r`) homes the cursor to (1,1) as a documented side effect (xterm ctlseqs); the subsequent `_progress_redraw` saves/restores around (1,1), leaving cursor at row 1. The very next output — `_install_preflight`'s `Sudo password required for installation...` and the sudo prompt itself — therefore landed at the top of the screen instead of just above the pinned bar. Fix: append explicit CUP (`\e[N-1;1H`) after DECSTBM so cursor lands at the bottom of the scroll region. `_progress_on_winch` got the same DECSTBM bug on terminal resize; bracketed there with DECSC/DECRC (`\e7…\e8`) to preserve mid-stream cursor position. Verified with pyte VT100 emulator: pre-fix puts prompt at row 1, post-fix puts prompt at row N-1.
  * preflight: `_init_runtime` CPU-model sanity check switched from case-sensitive `string match -q --` to `string match -q -i --`. `/proc/cpuinfo` reports the AMD Ryzen AI Max+ 395 model name in upper case (`AMD RYZEN AI MAX+ 395 w/ Radeon 8060S`); the case-sensitive substring match against the literal `Ryzen AI Max` fired a false `Built-in defaults expect ... but detected: ...` warning at every install on the target hardware. The `+` glyph is not part of the comparison.
  * boot: install-error gating split. New globals `_RY_BOOT_TAINTED` (bool, default false) + `_RY_BOOT_CRITICAL_DSTS` (the four boot-driving destinations: loader.conf, cmdline, sdboot-manage.conf, mkinitcpio.conf). Set true only by failures that mean on-disk package state or boot-critical configs may be inconsistent with the embedded mkinitcpio/cmdline content: `_install_packages` (mkinitcpio.conf pre-deploy fail, pacman -Syu fail, missing pkgs after verify), `_install_aur_packages` (paru missing or any AUR install fail — covers DKMS modules referenced by mkinitcpio MODULES), and `_isf_deploy_set` (only when the failed dst is in `_RY_BOOT_CRITICAL_DSTS`). `_install_rebuild_boot` now gates on `_RY_BOOT_TAINTED` instead of `INSTALL_HAD_ERRORS`; service-runtime failures (a unit's `--now` start failing because its runtime config is invalid) no longer cascade into `EXIT_BOOT_CRIT`. The pre-existing `RY_INSTALL_FORCE_BOOT_REBUILD=1` override still applies. `INSTALL_HAD_ERRORS` retains its pre-existing role for the summary print and final exit code.
  * services: `_cse_batch_enable` per-unit retry now distinguishes `enable ok, --now start failed` from `enable failed`. `systemctl enable --now $unit` returns non-zero in both cases; post-failure we probe `systemctl is-enabled $unit` and treat `enabled` / `enabled-runtime` / `alias` / `static` as enable-success → warn (`Enabled but failed to start: $unit (will activate on next boot if config is fixed)`) with diagnose hint; do NOT taint `INSTALL_HAD_ERRORS`. New JSONL marker `ENABLE_OK_START_FAIL: unit=$unit is-enabled=$state`. Other `is-enabled` outputs continue to err and taint as before.
  * keepalive: child stderr captured to a tracked tmpfile (`SUDO_KEEPALIVE_ERR` global, `mktemp -t ry-ka-err.XXXXXX`, `_track_tmpfile`) instead of `2>&1` to `/dev/null`. `_check_sudo_keepalive` reads first line on premature exit and surfaces it (`... (reason)`) in the warn message and `SUDO_KEEPALIVE_EXPIRED` log marker. `_kill_sudo_keepalive` removes the tmpfile and erases the global. Diagnostic-only — does not alter control flow.
  * release: patch version bump `4.6.2` → `4.6.3` (script header line 2 + `set -g VERSION` + README badge).

v4.6.2 - 2026-05-08
-------------------

  * naming: third generator-failure sentinel promoted to a named constant — `EXIT_GEN_SYSCTL=13` (replaces literal `return 13` in `_content__etc_sysctl.d_99-cachyos-sysctl.conf`). Registered in `_early_cleanup`. No exposed exit codes change — sysctl-count-mismatch is still squashed to `EXIT_PREFLIGHT` at the consumer (`_awf_render_to_tmp` `case 13` arm), matching the `EXIT_GEN_NOFN/NOUUID` pattern from v4.6.1.
  * preflight: `_ry_check_deps` hard-deps loop extended with `sudo`, `df`, `mkdir`, `rmdir` (4 entries). All four were previously assumed-present at use sites or guarded one-off (`sudo`: 153 uses, 10 inline `command -q sudo` guards; `df`: 3 uses behind a separate BSD-vs-GNU preflight at script load; `mkdir`/`rmdir`: 8/9 uses, no inline guard). Now centralised in the same coreutils block as `cat`/`cut`/`mv`/`rm`/`tee`. `_ry_check_deps` "missing" failure path is exercised before any `_run` call site.
  * release: patch version bump `4.6.1` → `4.6.2` (script header line 2 + `set -g VERSION` + README badge).

v4.6.1 - 2026-05-08
-------------------

  * docs: `_ry_show_help` hoisted above the early-arg loop; the early `case -h --help` printf body collapses to a single `_ry_show_help` call (was a 38-line parallel HELP-TEXT-SYNC printf with column-width and exit-code-wording drift across `-h`/`--help` vs argparse-routed paths). Both early and post-argparse routes now emit byte-identical output via the same source.
  * naming: internal generator sentinels promoted to named constants — `EXIT_GEN_NOFN=11` (replaces literal `return 11` in `_ry_get_file_content`), `EXIT_GEN_NOUUID=12` (replaces literal `return 12` in `_content__etc_kernel_cmdline`). Both registered in `_early_cleanup`. `_check_phase_files` log marker updated `rc=11/12` → `rc=EXIT_GEN_NOFN/NOUUID`. No exposed exit codes change — both squashed to `EXIT_PREFLIGHT` at the consumer.
  * dead-code: `string match -r '...' -- "$tail3" | head -n 1` in the `_log` 4096-byte truncation collapsed to bare `string match -r` — the `$`-anchored pattern returns at most one match per input string, so the `head -n 1` filter was unreachable.
  * docs: `_ry_show_help` `_file_count 15` literal fallback annotated with inline cross-reference comment to `_RY_MANAGED_FILE_COUNT` and the three destination-list globals (`SYSTEM_DESTINATIONS` / `USER_DESTINATIONS` / `SERVICE_DESTINATIONS`); future destination additions have a paper trail to the fallback site.
  * style: comment-pass — sole inline non-lint comment moved above its line (`_ry_show_help` `_file_count` fallback); 6 standalone comments reworded to drop fish-syntax-like tokens (`NAME set`, `$status`, `()` call-form, leading `switch` keyword) that could trip naive static analyzers reading comment bodies; one 100-char comment trimmed to fit the ≤ 80-char convention. Safe-lint markers (`# FISH-LINT-DIRECTIVE`, in-string `# lint:ignore` annotations, trailing `# lint:ignore` on the printf-arg `'end'` literal) preserved verbatim.
  * release: patch version bump `4.6.0` → `4.6.1` (script header line 2 + `set -g VERSION` + README badge).

v4.6.0 - 2026-05-07
-------------------

  * release: minor version bump consolidating the 4.5.x point series. No functional changes vs `v4.5.38`; tag opens a stable line for the post-anti-lag-removal env-var set.
  * docs: README version badge bump 4.5.38 → 4.6.0.

v4.5.38 - 2026-05-07
--------------------

  * env-vars: drop `ENABLE_LAYER_MESA_ANTI_LAG=1` from `~/.config/environment.d/10-environment.conf`. Anti-lag opt-in moved to per-game Steam launch options; system-wide enablement removed.
  * preflight: `_ir_validate_counts` `ENV_VARS` invariant `12` → `11`.
  * docs: README `Environment Variables` header `13 vars (12 gaming/debug + 1 systemd-user)` → `12 vars (11 gaming/debug + 1 systemd-user)`; `<summary>` `Show 13` → `Show 12`; `ENABLE_LAYER_MESA_ANTI_LAG` row removed from the deployed table.
  * docs: README `Per-game overrides` `Deprecated` list extended with `ENABLE_LAYER_MESA_ANTI_LAG`.
  * docs: README version badge bump 4.5.37 → 4.5.38.

v4.5.37 - 2026-05-07
--------------------

  * env-vars: drop `PROTON_NO_WM_DECORATION=1` from `~/.config/environment.d/10-environment.conf`. Borderless behaviour now governed per-game via Steam launch options or per-WM by COSMIC's own decoration policy; system-wide enforcement removed.
  * preflight: `_ir_validate_counts` `ENV_VARS` invariant `13` → `12` to match the trimmed list.
  * docs: README `Environment Variables` section: header `14 vars (13 gaming/debug + 1 systemd-user)` → `13 vars (12 gaming/debug + 1 systemd-user)`; `<summary>` `Show 14` → `Show 13`; `PROTON_NO_WM_DECORATION` row removed from the deployed table.
  * docs: README `Per-game overrides` section: `DISABLE_LAYER_MESA_ANTI_LAG=1` and `PROTON_NO_WM_DECORATION=0` rows removed; both names appended to the `Deprecated — do not re-introduce` list (alongside `DXVK_ASYNC`, `DXVK_FRAME_RATE`, `WINE_FULLSCREEN_FSR`) so future bumps do not silently reintroduce them.
  * docs: README version badge bump 4.5.36 → 4.5.37.

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
  * cross-site: `_configure_services_enable` iterates `$EXPECTED_SERVICES` filtered by `$_RY_DEPLOYED_SERVICES` and the new `$_RY_PKG_MANAGED_SERVICES`. Was hardcoded `fstrim.timer` + a firewall unit; new EXPECTED_SERVICES auto-flow.
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
