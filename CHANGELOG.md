ry-install ChangeLog

v7.4.64 - v7.4.65 - 2026-05-23

- Script readability pass: lift 11 single-line WHY comments above function declarations (`_ntsync_state` dispatch-order rationale, `_resolve_systemd_ver` one-shot probe sentinel, `_acquire_lock` mkdir-atomicity primitive, `_cleanup` 128+N signal convention, `_cleanup_pipe` SIGPIPE non-fatal contract, `_cleanup_on_exit` exit-code resolution priority, `_ir_validate_counts` README/script drift gate, `_ir_validate_keys` dispatcher-collision refusal, `_init_runtime` every-mode hardware gate, `_atomic_write_file` same-FS rename invariant, `_ry_install_file` iwd-gated-destination skip); lift the inline `Dynamic dispatch` comment from `_ry_get_file_content` body to above the declaration; insert blank lines between consecutive `function`/`end` boundaries across the script (content generators + sub-helper clusters in verify/install/services/boot/post-hook families) for visual grouping; LOC 4745 → 4967 (+222: 11 lifts + ~211 blank-line separators); zero behavioural change; version bump.

v7.4.63 - v7.4.64 - 2026-05-23

- Lift 7 top-of-function-body comments to immediately above the `function` declaration (`_is_system_dst`, `_progress_init`, `_chk_token_in`, `_ry_check_wireless_regdom`, `_far_build_awk_script`, `_csm_disable_ufw_rules`, `_idf_match_dst`); zero LOC delta; output of all 12 content generators byte-identical (md5 unchanged); function count unchanged; version bump.

v7.4.62 - v7.4.63 - 2026-05-23

- Script comment trim (-24 LOC): drop file-top narrative comments above 6 set -g blocks (EXIT_GEN_*, EXIT_RUN_TMPFAIL, RC_KVER_*, PACTREE_TIMEOUT_S, _RY_PHASE_NAMES, _RY_NTSYNC_MODLOAD_CONF), drop section-preamble narrative under PATH HARDENING + GLOBAL STATE banners, drop redundant function-description duplicates above _phase_record/_err/_run_emit_stream/_set_exit, drop dispatch-table preamble above _RY_POST_HOOKS, drop log-rename inline comments; CHANGELOG style flatten (drop `====` title underline and per-entry `----` separator; uniform plain-text font); version bump.

v7.4.61 - v7.4.62 - 2026-05-23

- Sync pass: README trim verbose table cells (670 → 666 LOC); script trim verbose >100-char comments; CHANGELOG collapse multi-bullet entries to single summary lines; version bump; no behavioural changes.

v7.4.60 - v7.4.61 - 2026-05-23

- README Phase 3 tmpfiles header `Mode` → `Argument` (sysfs content per tmpfiles.d(5), not file mode); version bump.

v7.4.59 - v7.4.60 - 2026-05-23

- `_rdi_summary` realtime group hint `gpasswd -a` → `usermod -aG` (preserves other groups); version bump.

v7.4.58 - v7.4.59 - 2026-05-23

- Comment trims across 7 sites (`_idf_dispatch_hook`, `_rdi_matrix_header`, `KVER_MINOR`, `_phase_record`, `_install_preflight`, `_cse_collect_units`, `_boot_initrd_size_scan`); -2 LOC, zero behavioural change.

v7.4.57 - v7.4.58 - 2026-05-23

- README Configuration: revert per-phase prose intros; expand first `<details>` per phase to always-visible table (step counts 10/4/4/6/4/4 preserved).

v7.4.56 - v7.4.57 - 2026-05-23

- README Configuration: insert 1-line prose lead before first collapsible across all 6 phases; fold scattered cross-references into leads.

v7.4.55 - v7.4.56 - 2026-05-23

- README: wrap 6 bare per-phase Step tables in `<details>` for uniform shape.

v7.4.54 - v7.4.55 - 2026-05-23

- README: convert all 9 non-table collapsibles to uniform Markdown tables (counts preserved 15/2/3/15/9/1/1/3/11/12).

v7.4.53 - v7.4.54 - 2026-05-23

- README trim 678 → 623 LOC (-8.1%); rows 319 → 241 (-24.4%); compact value lists; kernel cmdline → code block.

v7.4.52 - v7.4.53 - 2026-05-23

- `_verify_static_checksum`: extract per-destination loop to `_vsc_check_one` helper (55 → 9 LOC); README Phase 1 row 9 enumerates `_ry_check_wireless_regdom`.

v7.4.51 - v7.4.52 - 2026-05-23

- `_rrp_optional_indexer` flag capture via `set -l $argv[3..-1]`; `PKGS_DEL` += `breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt` (Plasma rdeps); count assertion 8 → 11; README synced.

v7.4.50 - v7.4.51 - 2026-05-23

- README Uninstall + Known Issues + Troubleshooting cell tightening: sudo prefixing, `&&` → `; and`, `gpasswd -a` → `usermod -aG`, env var + invocation, PGP keyserver pin, concrete kernel 6.19 downgrade commands.

v7.4.49 - v7.4.50 - 2026-05-23

- `_ry_show_help` log path `+ZZZZ` → `±ZZZZ`, drop stale 3.x signal qualifier; `_vrkg_vram` inline `UMA Frame Buffer Size`; README Usage + RY_RUN_TIMEOUT + Logs aligned.

v7.4.48 - v7.4.49 - 2026-05-23

- `_ry_show_help` `RY_INSTALL_NO_MATRIX` label; HSAK <257 nested `if`; `_verify_static_checksum` `string collect` multi-line; README Logs events row.

v7.4.47 - v7.4.48 - 2026-05-23

- Kernel <6.14 hard-floor FAIL; signal-race closures (`_acquire_lock_fresh` sentinel, `_set_exit`, `_cleanup` unknown-signal case); `_phase_record` both-branch emission; `_post_*` rc propagation; tmpfile move `/etc` → `/run/ry-install`; AWK pipeline single sudo-awk; `--install-file` newline/PATH_MAX checks; lifted globals (`_RY_PHASE_NAMES`, `_RY_NTSYNC_MODLOAD_CONF`, `PACTREE_TIMEOUT_S`).

v7.4.46 - v7.4.47 - 2026-05-23

- Phase 1 + Phase 2 sub-tables: leading `#` column for step numbering consistency across all 6 phases.

v7.4.45 - v7.4.46 - 2026-05-23

- Remove redundant Quick Start `[!IMPORTANT]` callout; trim iwd `<details>` skip note.

v7.4.44 - v7.4.45 - 2026-05-23

- Phase 1 enumerates 10 preflight steps in runtime order; Phase 5 post-rebuild sanity row; exit-code row 1 drops stale old-kernel-warn; Hardware notes CPU check runs every mode.

v7.4.40 - v7.4.44 - 2026-05-22

- README: drop orphan kernel-bugzilla; clarify iwd-gated skip; align cpupower-service + tmpfiles to logind shape; collapse 3 low-density tables; drop incorrect `cleanup_exit` from Footer-marker.

v7.4.39 - v7.4.40 - 2026-05-22

- README safe-trim 740 → 684 LOC; drop header blockquote, WiFi-defer duplicate, Hardware bugzilla, `jq` footer example; fold preflight prose; flatten 5 Known Issues `<details>` to one 3-col table.

v7.4.38 - v7.4.39 - 2026-05-22

- Collapse verbose multi-clause inline comments to concise WHY; split 4 >220-char lines; `_post_cpupower` split warn pair; `_init_runtime` KERNEL_PARAMS regex lifted; `_install_aur_packages` collapse 4 `AUR_NOISE_NOTE_TOKEN` calls.

v7.4.37 - v7.4.38 - 2026-05-22

- Flatten `_ry_tmpprobe_dir` + argparse-tail QUIET toggle; move 8 trailing inline comments to dedicated lines; README Run Summary → prose; Configuration → tables for mobile.

v7.4.36 - v7.4.37 - 2026-05-22

- `_vrsv_chk_nm_dispatcher`: short-circuit on `not-found` (`_warn` + return 0).

v7.4.35 - v7.4.36 - 2026-05-22

- Remove 3 stray `\;` tokens from inline `for` lists; `RY_INITRD_WARN_MB` invalid → `_RY_DEFERRED_WARNS`; malformed sysctl via `EXIT_GEN_SYSCTL`; defensive `MATRIX_TRUNCATED` JSONL in `_rdi_matrix_rows`.

v7.4.34 - v7.4.35 - 2026-05-22

- Split 2 >250-char lines (MASK service list, sudo-cache warning printf); drop dead `2>/dev/null` on `status stack-trace`.

v7.4.33 - v7.4.34 - 2026-05-21

- LOC reduction 5113 → 4468: ~200 multi-line blocks collapsed to `; and` chain form; function count unchanged (256 multi-line + 8 single-line).

v7.4.32 - v7.4.33 - 2026-05-21

- Consolidate CHANGELOG per-patch entries into ranges; close chain gaps; bump README badge and run-summary example.

v7.4.31 - v7.4.32 - 2026-05-21

- Expand 4 single-line content generators (`loader.conf`, resolved drop-in, NM drop-in, `cpupower-service.conf`) to multi-line `printf '%s\n' \` form; output byte-identical.

v7.4.22 - v7.4.31 - 2026-05-21

- README cleanup: Phase blocks → uniform "N sequential operations" intro; `<summary>` normalised to count+unit; inline boot-critical paths → bullet lists; style sync (`Fish` → `fish`, `Pacman` → `pacman`); en-dash on durations.

v7.4.5 - v7.4.22 - 2026-05-20

- LOC 5204 → 5113; collapse inline comments; chain `set -l/-g` runs; function extractions ≤50 LOC (`_ip_record_regdom`, `_iap_per_pkg_retry`, `_iap_record_result`, `_irb_taint_gate`, `_rrp_optional_indexer`); kernel <6.14 matrix FAIL; box-drawn Unicode run-summary matrix to stderr; drop strict `NOPASSWD: ALL` preflight gate.

v7.4.0 - v7.4.5 - 2026-05-20

- Preflight + lock + sudo cache redesign: fish-version flat sentinel; reject `timeout(1)` without `--foreground`/`--kill-after`; `_acquire_lock` `/proc/$pid/comm` race close; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out; `_csp_filter_rdeps` 4-stage `pipestatus`; `_dc_kill_children` 0.5s SIGKILL grace; `_cleanup_tmpfiles` two-step `sudo -n true` gate.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19

- Major preflight hardening: `_RY_LOUD_ERR` default-quiet stderr surface; `_ir_resolve_root_uuid` 4-way mode dispatch; `_RY_LOG_SUPPRESS_CREATE` plug; `_cse_batch_enable` accept-list expansion (linked, linked-runtime, indirect, generated, transient); `_chk_perms` setuid/sgid/sticky strip; `_run_emit_stream` head+tail 100; `_boot_initrd_size_scan` byte comparison; LOC 5177 → 4842; systemd <250 hard-fail; `EXIT_RUN_TMPFAIL` sentinel; log filename → `MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17

- NM 1.56.0 compat (drop `wifi.iwd.autoconnect=false`); MASK += avahi.service/.socket (10 → 12); PKGS_ADD += `realtime-privileges`, `cpupower`; PKGS_DEL += `bolt`; new `_ry_check_wireless_regdom`, `_vrk_audio_state`, `_ry_apply_wireless_regdom`; `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`; HSAK gate <256 → <257; add `/etc/default/cpupower-service.conf`, drop `/etc/drirc`; scaling_governor → performance; `_vmh_order_checks` adds fsck-last + microcode-pair invariants; managed-file count 13 → 12; services 4 → 3; `_vre_fstab` unifies under `(^|,)tok(,|$)`; `_mr_copy_size_verify` adds `cmp -s`.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994 → 4985 LOC): drop scaffolding (GNU probes, source-mode, ntsync probes, sudo-keepalive, log rotation, LVM, TOCTOU re-stat); add user-bus detection, `printf`-only emitters, split `_run`/`_run_redact_cmd`/`_run_effective_timeout` with timeout-bypass list, `_atomic_write_file` post-write symlink re-check, `_fstab_atomic_replace` `findmnt --verify` hard-fail, `0600` user destinations, `--install-file` post-hook dispatch, argparse `--exclusive`, atomic mkdir + pid-file lock, `_ir_validate_counts`, `_RY_POST_HOOKS` first-match dispatch, managed `/etc/tmpfiles.d/99-cachyos-thp.conf`, `_aur_verify_mt7925`.
