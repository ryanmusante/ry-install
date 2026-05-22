ry-install ChangeLog
====================

v7.4.40 - v7.4.44 - 2026-05-22
------------------------------

- Hardware: drop orphan kernel-bugzilla tracker line (References covers gfx1151).
- Managed Files: clarify both iwd-gated destinations (`iwd/main.conf` + NM drop-in) skip when iwd absent.
- Configuration: align cpupower-service + tmpfiles blocks to systemd-logind shape (prose lead + bullet); collapse three low-density tables.
- Logs: drop incorrect `cleanup_exit` claim from Footer-marker row; normal-exit footers carry no marker. Script `_teardown exit` updated to match.

v7.4.39 - v7.4.40 - 2026-05-22
------------------------------

- README safe-trim 740 → 684 lines.
- Drop header blockquote (paru/AUR note → Prerequisites table).
- Drop WiFi-defer sentence from `[!IMPORTANT]` (duplicates Phase 6).
- Prerequisites: fold "Additional preflight gates" prose into table.
- Hardware: compress `[!IMPORTANT]` to one-line; inline UMA Frame Buffer table.
- Run Summary: compress intro paragraph.
- Logs: drop redundant `jq` footer-filter example.
- Known Issues: flatten 5 `<details>` blocks into one 3-column table.
- References: inline link bullets to prose line.

v7.4.38 - v7.4.39 - 2026-05-22
------------------------------

- Collapse verbose multi-clause inline comments to concise WHY lines.
- Split four >220-char lines: `_unit_state`, `_post_sysctl` warn chain, header JSONL printf, pacman db-lock string.
- `_post_cpupower`: split single-line restart-warn into `_warn` + `_info` pair.
- `_init_runtime`: lift KERNEL_PARAMS metachar regex to `set -l`; multi-line if-chain.
- `_check_phase_cmdline`: emit `CHECK_PREFLIGHT` JSONL when `/proc/cmdline` empty (was silent drift).
- `_install_aur_packages`: collapse four `AUR_NOISE_NOTE_TOKEN` calls into single joined log.
- `_post_boot`: shorten `_RY_BOOT_TAINTED=true` rejection parenthetical.

v7.4.37 - v7.4.38 - 2026-05-22
------------------------------

- Flatten `_ry_tmpprobe_dir` initialiser (default-then-update).
- Flatten argparse-tail QUIET toggle (`if/else if` replaces nested `begin..end`).
- Move eight trailing inline comments to dedicated lines.
- README Run Summary: drop example matrix; describe shape in prose.
- README Configuration: Phase 1-6 numbered lists → tables (mobile readability).
- README Phase 6: add `systemctl --user daemon-reload` + JSONL footer row.
- README Phase 3: tmp file in destination's parent dir; symlink probe pre + post render.
- README Safety table: atomic-writes match implementation; fstab notes symlink refusal; mkinitcpio rollback notes `cp + size + cmp -s`; instance-lock notes `/proc/$pid/comm = fish`.

v7.4.36 - v7.4.37 - 2026-05-21
------------------------------

- `_vrsv_chk_nm_dispatcher`: short-circuit on `not-found` (`_warn` + return 0); aligns with sibling `_vrsv_chk_*` helpers.

v7.4.35 - v7.4.36 - 2026-05-22
------------------------------

- Remove three stray `\;` tokens from inline `for` lists (`_vsb_loader`, `_verify_static_system`, `_ry_check_deps`); fish parses `\;` as literal element, flipping `--verify-static` to FAIL on clean installs.
- `RY_INITRD_WARN_MB` invalid values queue into `_RY_DEFERRED_WARNS` (mirrors `RY_RUN_TIMEOUT`).
- Malformed sysctl entries surface via `EXIT_GEN_SYSCTL` dispatcher branch.
- Add defensive `MATRIX_TRUNCATED` JSONL diagnostic in `_rdi_matrix_rows`.

v7.4.34 - v7.4.35 - 2026-05-22
------------------------------

- Split two >250-char lines (MASK service list, sudo-cache warning printf).
- Drop dead `2>/dev/null` on `status stack-trace` (builtin does not write to stderr).

v7.4.33 - v7.4.34 - 2026-05-21
------------------------------

- LOC reduction 5113 → 4468: ~200 multi-line blocks collapsed to `; and` chain form (skipped on blocks with trailing `#` comments).
- Function count unchanged (255 multi-line + 9 single-line); largest still `_ry_show_help` at 39 LOC.

v7.4.32 - v7.4.33 - 2026-05-21
------------------------------

- Consolidate CHANGELOG per-patch entries into ranges; close chain gaps.
- Bump README version badge and run-summary example matrix.

v7.4.31 - v7.4.32 - 2026-05-21
------------------------------

- Expand four single-line content generators (`loader.conf`, resolved drop-in, NM drop-in, `cpupower-service.conf`) to multi-line `printf '%s\n' \` form; output byte-identical.

v7.4.22 - v7.4.31 - 2026-05-21
------------------------------

- README cleanup: Phase blocks → uniform "N sequential operations" intro + ordered step list (Phase 3: "Four-step sequence per file").
- `<summary>` blocks normalised to "count + unit" suffix.
- Inline boot-critical paths → bullet lists in `[!IMPORTANT]` and Phase 3.
- Style sync (`Fish` → `fish`, `Pacman` → `pacman`); en-dash on duration ranges.

v7.4.5 - v7.4.22 - 2026-05-20
-----------------------------

- LOC reduction 5204 → 5113; collapse inline comments to single-line "why" form; semicolon-chain adjacent `set -l`/`set -g` runs.
- Function extractions to keep ≤50 LOC: `_install_preflight` → `_ip_record_regdom`; `_install_aur_packages` → `_iap_per_pkg_retry` + `_iap_record_result`; `_install_rebuild_boot` → `_irb_taint_gate`; `_rdi_run_phases` → `_rrp_optional_indexer`.
- Collapse `_verify_static_services` 9-way `is-enabled` chain to `contains`.
- Bootstrap: non-existent `TMPDIR` → `/tmp` with stderr warning; `_tmp_dir` gains `test -d "$TMPDIR"` defence.
- AUR `mt76-mt7925-dkms` post-build `modinfo` failure now WARN (was silent PASS).
- Emit `BOOT_TAINTED_OVERRIDE` (JSONL + stderr) when `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint gate.
- Split `_rdi_render_matrix` into header/rows/footer (each ≤50 LOC).
- Kernel <6.14 hard floor now matrix FAIL (was WARN).
- Run-summary matrix: install prints box-drawn Unicode matrix to stderr (CHECK / RESULT / EVIDENCE + totals + verdict); `RY_INSTALL_NO_MATRIX=1` opts out.
- `_phase_record` strips embedded newlines and U+2502 from arguments.
- Drop strict `NOPASSWD: ALL` preflight gate; replace with `_ry_sudo_cache_banner` install-mode warning.

v7.4.0 - v7.4.5 - 2026-05-20
----------------------------

- Preflight + lock + sudo cache redesign.
- Fish-version preflight: flat sentinel replaces nested `begin..end`.
- Preflight rejects `timeout(1)` lacking `--foreground` / `--kill-after` (busybox, uutils).
- `_acquire_lock` closes PID-recycle race via `/proc/$pid/comm`.
- `_acquire_lock_fresh` runs `umask 0077` around mkdir.
- `_ensure_sudo_cached` gains `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.
- `_csp_filter_rdeps` checks `pipestatus` across all 4 pipe stages.
- `_dc_kill_children` widens SIGKILL grace to 0.5s.
- `_cleanup_tmpfiles` inserts two-step `sudo -n true` gate before `sudo find`.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19
------------------------------------------

- `_RY_LOUD_ERR`: critical preflight failures reach stderr in default QUIET install mode; `--check` stays silent.
- `_ir_resolve_root_uuid` gains 4-way mode dispatch; `_reason` distinguishes "findmnt failed" from "invalid UUID shape".
- `_RY_LOG_SUPPRESS_CREATE` eliminates orphan `preflight-*.jsonl` on argparse-error paths.
- `_cse_batch_enable` accept-list adds linked, linked-runtime, indirect, generated, transient.
- `_chk_perms` strips leading setuid/setgid/sticky digit.
- `_run_emit_stream` captures head + tail (100 each); build-error tails preserved.
- `_boot_initrd_size_scan` switches to byte comparison (removes off-by-1MB silent pass).
- `_verify_runtime_kparams` pre-extracts preempt/BAR/TSC markers from full dmesg before 5000-line cap.
- LOC reduction via short-circuit chain collapse (5177 → 4842).
- `_ry_check_disk_space` labels switch to GiB/MiB.
- `_vrkg_rebar_sam` lspci regex broadened.
- `_ry_check_deps` adds systemd <250 hard-fail preflight gate.
- `_run` tmpdir-alloc sentinel promoted to `EXIT_RUN_TMPFAIL`.
- Log filename → `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17
------------------------------------------

- NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
- `MASK` gains `avahi-daemon.service` and `.socket` (10 → 12 units).
- `PKGS_ADD` gains `realtime-privileges`, `cpupower`; `PKGS_DEL` gains `bolt`.
- New `_ry_check_wireless_regdom`, `_vrk_audio_state`, `_ry_apply_wireless_regdom` (driven by `RY_INSTALL_WIRELESS_REGDOM`).
- `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`.
- `_vsb_mkinitcpio` amdgpu probe tightened `*amdgpu*` → `\bamdgpu\b`.
- `_ry_check_deps` adds GNU-coreutils `df` probe.
- `HandleSecureAttentionKey` gate <256 → <257.
- Add `/etc/default/cpupower-service.conf`; drop `/etc/drirc`.
- `_vrk_cpu_state` scaling_governor: powersave → performance.
- `_vmh_order_checks` adds `systemd:autodetect` and `autodetect:microcode` pair rules plus fsck-last invariant.
- Drop `cpupower-epp.service`; `SERVICE_DESTINATIONS` empty.
- `_RY_MANAGED_FILE_COUNT` 13 → 12; `EXPECTED_SERVICES` 4 → 3.
- `_vre_fstab` unifies `noatime`/`lazytime`/`commit=10` under `(^|,)tok(,|$)`.
- `_mr_copy_size_verify` adds `cmp -s` after size match.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15
------------------------------------------

- Foundational v6.x → v7.0 series. v6.0 → v6.1: 5994 → 4985 LOC.
- Drop GNU-tool probes, source-mode scaffolding, ntsync probes, sudo-keepalive, JSONL progress events, log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gates, LVM detection.
- Add user-bus detection via `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`.
- HOME field-6 captured via `awk -F:` (GECOS-tolerant).
- JSONL header written before `_init_runtime`.
- `LOCK_DIR` gains `chmod 700`.
- Emit functions use `printf` (flag-injection guard).
- Split `_run` into `_run` / `_run_redact_cmd` / `_run_effective_timeout`; timeout-bypass for pacman, paru, mkinitcpio, sdboot-manage, paccache.
- Tmpfile-path redaction under `$TMPDIR`.
- `_ip_pacman_invoke` gates `-Syyu` retry on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`.
- Per-package AUR retry.
- `_atomic_write_file` post-write symlink re-check (TOCTOU).
- `_fstab_atomic_replace` `findmnt --verify` hard-fail.
- User destinations install `0600`.
- `--install-file` single-file redeploy with per-target post-hook dispatch.
- Argparse `--exclusive` mode group.
- Atomic `mkdir` + pid-file lock.
- `_ir_validate_counts` enforces array-count invariants.
- `_RY_POST_HOOKS` first-match table for `--install-file` hooks.
- `_rvc_dispatch` adds `*/tmpfiles.d/*` case + `_grep_tmpfiles_entry`.
- Add managed `/etc/tmpfiles.d/99-cachyos-thp.conf`.
- `_aur_verify_mt7925` asserts both pacman and modinfo resolve.
- `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL`.
- `_ry_exit` bail path writes JSONL footer.
- `_verify_static_services` multi-`ExecStart` guard.
- Tighten `KERNEL_PARAMS` metachar regex backslash escaping.
