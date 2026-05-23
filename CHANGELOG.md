ry-install ChangeLog
====================

v7.4.57 - v7.4.58 - 2026-05-23
------------------------------

- README Configuration: revert v7.4.56-7.4.57 single-line phase-intro prose across all six phases (Phase 1 Preflight, Phase 2 Packages, Phase 3 Configuration Files, Phase 4 Services, Phase 5 Boot, Phase 6 Finalize).
- README Configuration: expand the first `<details>` collapsible in each phase to an always-visible markdown table (Phase 1 Preflight steps, Phase 2 Phase steps, Phase 3 Atomic-write sequence, Phase 4 Phase steps, Phase 5 Boot steps, Phase 6 Finalize steps).
- Remaining per-phase collapsibles (data tables — packages, kernel cmdline, sysctl, env vars, fstab, masked units, etc.) untouched.
- All step counts and rows preserved (10/4/4/6/4/4); zero content drift versus script invariants.
- README badge: `7.4.57` → `7.4.58`.
- Script: header comment + `VERSION` global `7.4.57` → `7.4.58`. No functional changes.

v7.4.56 - v7.4.57 - 2026-05-23
------------------------------

- Phase 1 Preflight: insert 1-line prose lead before `Preflight steps` collapsible.
- Phase 2 Packages: insert 1-line prose lead; fold inter-collapsible `PKGS_DEL` / `EXPECTED_VULKAN_PKGS` note into lead.
- Phase 3 Configuration Files: collapse 2-line wrap to 1-line lead; fold Managed Files cross-reference into lead.
- Phase 4 Services: insert 1-line prose lead; move `OFS = " "` fstab blockquote into fstab collapsible.
- Phase 5 Boot: insert 1-line prose lead; fold trailing skip-condition + `RY_INSTALL_FORCE_BOOT_REBUILD` hint into lead.
- Phase 6 Finalize: insert 1-line prose lead enumerating the 4 steps.
- README badge: `7.4.56` → `7.4.57`.
- Script: no functional changes. Version bump only.

v7.4.55 - v7.4.56 - 2026-05-23
------------------------------

- README Configuration: wrap 6 bare per-phase Step tables in `<details>` collapsibles for uniform shape (Phase 1 Preflight, Phase 2 Packages, Phase 3 Atomic-write, Phase 4 Services, Phase 5 Boot, Phase 6 Finalize).
- Phase intro prose and Phase 4 fstab `OFS` blockquote kept outside the collapsible.
- Script: no functional changes. Version bump only.

v7.4.54 - v7.4.55 - 2026-05-23
------------------------------

- README Configuration: convert all 9 non-table collapsibles to uniform Markdown tables (Packages-install, Packages-AUR, Vulkan-deps, Kernel cmdline, systemd-logind, cpupower-service, tmpfiles, fstab, Packages-remove, Masked units).
- Already-table collapsibles untouched: Package caveats, Bootloader, Initramfs, systemd-resolved, iwd, NetworkManager, sysctl, Env vars, Enabled units.
- All `<summary>` counts unchanged (15/2/3/15/9/1/1/3/11/12); every package, parameter, key, unit, and path preserved.
- Script: no functional changes. Version bump only.

v7.4.53 - v7.4.54 - 2026-05-23
------------------------------

- README: trim verbose tables, 678 → 623 lines (−55, −8.1%); table-row count 319 → 241 (−78, −24.4%).
- Phase 1 preflight: drop restated function-name parentheticals from Action column.
- Packages-install (15) / Packages-AUR (2) / Vulkan (3): table → inline `·`-separated list.
- Kernel cmdline (15): table → compact 4-line code block.
- Packages-remove (11): table → grouped inline lists (boot splash · Thunderbolt · replaced/unused).
- Masked units (12): table → grouped inline lists (suspend targets · replaced/unused).
- fstab options: 3-row table → inline `·`-separated list + rewrite rules.
- Managed Files destinations (12): table → bulleted list with perm rule stated once.
- Safety & Reliability: condensed Detail cells; all flags/gates preserved.
- Runtime variables: `RY_INSTALL_WIRELESS_REGDOM` persist recipe moved to trailing paragraph.
- Logs: `ERR_NO_DATA` and `gen_fail` cells condensed to one sentence each.
- Script: no functional changes. Version bump only.

v7.4.52 - v7.4.53 - 2026-05-23
------------------------------

- `_verify_static_checksum`: extract per-destination loop body into `_vsc_check_one` helper (55 LOC → 9 LOC; helper 40 LOC).
- README Phase 1 row 9: enumerate `_ry_check_wireless_regdom` alongside `_ry_apply_wireless_regdom`; step count remains 10.

v7.4.51 - v7.4.52 - 2026-05-23
------------------------------

- `_rrp_optional_indexer`: capture optional flag via `set -l flag $argv[3..-1]`; eliminates `sudo -n updatedb ""` empty-operand rejection.
- `PKGS_DEL`: append `breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt` (Plasma rdeps holding plymouth/bolt).
- `_install_preflight` count-drift assertion `PKGS_DEL:8` → `PKGS_DEL:11`.
- README Reverse-deps cell: note Plasma rdeps now enumerated; cascade rarely needed.
- README Packages-remove summary: `8 pkgs` → `11 pkgs`; rows extended with rdep sources.
- README `RY_INSTALL_WIRELESS_REGDOM` row: persistent-config recipe in `~/.config/fish/conf.d/ry-install-env.fish`.
- README badge: `7.4.51` → `7.4.52`.

v7.4.50 - v7.4.51 - 2026-05-23
------------------------------

- Uninstall steps 1-4: prefix system commands with `sudo`.
- Uninstall step 5 + Known Issues NM+iwd row: bash `&&` → fish `; and`.
- Quick Start preflight: drop redundant standalone `sudo -v` (`_ensure_sudo_cached` primes internally).
- Hardware override + Troubleshooting `PKGS_DEL` cells: show env-var with full `./ry-install.fish` invocation.
- Troubleshooting `set-wireless-regdom` cell: cross-reference `RY_INSTALL_WIRELESS_REGDOM`; manual `tee` kept as fallback.
- Prerequisites WARNING: replace prose with three concrete recipes (visudo timeout, fish keepalive loop, drop-in path).
- Logs prune cell: `find -delete` → `find -print -delete`.
- Known Issues MES page faults: concrete `paru -S amdgpu-dkms-firmware` / `IgnorePkg` commands.
- Known Issues ROCm VRAM: append `sudo pacman -Syu linux-cachyos` upgrade command.
- Troubleshooting kernel 6.19.0 black screen: explicit upgrade + downgrade commands.
- Package caveats + Known Issues PGP cells: pin `--keyserver hkps://keyserver.ubuntu.com`.
- Troubleshooting PipeWire row: `gpasswd -a` → `usermod -aG` (preserves other groups).
- Troubleshooting sudo-expired cell: drop `sudo -v; and ./ry-install.fish` chain.

v7.4.49 - v7.4.50 - 2026-05-23
------------------------------

- `_ry_show_help` Log path: `+ZZZZ` → `±ZZZZ` to match `date '+%z'`.
- `_ry_show_help` signal-caveat: drop stale `3.x` qualifier.
- `_vrkg_vram` VRAM-carveout warn: inline BIOS setting name (`UMA Frame Buffer Size`).
- README Usage table: `-V, --verbose` aligned with `--check` silent-probe contract.
- README Runtime variables: `RY_RUN_TIMEOUT` bypass list extended to db-indexer ops.
- README Logs `<details>` summary: `5 properties` → `7 properties`.

v7.4.48 - v7.4.49 - 2026-05-23
------------------------------

- `_ry_show_help` `RY_INSTALL_NO_MATRIX` label: `=1` → `(any non-empty)`.
- `_content__etc_systemd_logind` + `_vss_logind`: HSAK <257 skip rewritten as explicit nested `if`.
- `_verify_static_checksum`: split gen-stage and ib-stage `string collect` failure single-liners into multi-line `if ... end`.
- `_install_preflight` 3-check loop: inline-comment `_i` advance asymmetry.
- Collapse adjacent comments at `_RY_DEPLOY_CHANGED_COUNT` / `_PROFILE_USES_WIFI_BACKEND` declarations.
- README Logs events row: footer field list enumerated; `ts`/`event` common to all events.

v7.4.47 - v7.4.48 - 2026-05-23
------------------------------

- Kernel <6.14 hard-floor: `_ry_check_kernel_version` emits `_err` (was `_warn`); named return codes `RC_KVER_OK`/`RC_KVER_WARN`/`RC_KVER_FAIL` replace literal 0/1/2.
- Signal-arrival race closures: `_acquire_lock_fresh` sets `_RY_LOCK_DIR_OWNED` sentinel before `mkdir`; new `_set_exit` keeps `_RY_EXIT_CODE` and `_INTENDED_EXIT_CODE` in sync; `_cleanup` adds `case '*'` for unknown signals.
- `_phase_record` consistency: `_install_finalize`, `_configure_services_resolved_restart`, `_configure_services_thp_apply`, `_cse_collect_units` emit `_phase_record` on both branches.
- `_post_*` rc propagation: `_post_service`, `_post_resolved`, `_post_sysctl`, `_post_tmpfiles`, `_post_cpupower` return 1 on failure; `_post_nm` aggregates iwd + NM rcs; `_post_envd` appends live-apply hint.
- Tmpfile relocation: `_mkinitcpio_revert`, mkinitcpio snapshot, `_fstab_atomic_replace` move tmpfile creation from `/etc` to `/run/ry-install` (root 0700).
- AWK pipeline hardening: consolidate `_far_*` to single sudo-awk pipeline; `_far_build_awk_script` skips empty tokens; size floor derives 25%-of-input lower bound (absolute floor 20 bytes); `_awf_render_to_tmp` captures tee stderr.
- Verify-path symmetry: `_verify_static_services` → `_unit_state_padded`; `_vss_ntsync_modules` case order aligned with `_vre_ntsync`; `_vre_zram` refactors to `switch`; `_vs_read_symmetry_selftest` emits WARN + SKIP on mktemp failure.
- Input validation: `--install-file` rejects embedded-newline paths, caps at PATH_MAX (4096); `_csp_filter_rdeps` splits regex; realtime group check uses `id -Gn | contains`; `_ry_check_deps` adds paru ≥ 2.0.0 probe.
- Logging: log rename gains `cp -p` + `rm` fallback; `[i] Log file:` guarded by `not set -q _RY_LOG_WRITE_FAIL`; `--check` with `-V` logs `CHECK_VERBOSE_IGNORED`.
- Lifted globals: `_RY_PHASE_NAMES` (6-phase canonical list), `_RY_NTSYNC_MODLOAD_CONF`, `PACTREE_TIMEOUT_S=60`.
- `_run_resolve_timeout` returns `0` instead of empty for disable case; `RY_INSTALL_NO_MATRIX` accepts any non-empty value; progress bar cursor save/restore switched from DEC-private to ANSI standard.
- README sync: Logs documents `ERR_NO_DATA`, `gen_fail` rc-flip, `±ZZZZ` timezone-sign; verdict footnote that `DEFER`/`SKIP`/`N/A` are informational; boot-rebuild gate distinguishes taint flag from revert-failed flag; Phase 2 sub-table adds `updatedb` + `pkgfile --update` rows; Troubleshooting adds kernel 6.19.0 + iwd `main.conf`-startup-only caveats.

v7.4.46 - v7.4.47 - 2026-05-23
------------------------------

- Phase 1 + Phase 2 sub-tables: add leading `#` column for step numbering consistency across all six phases.

v7.4.45 - v7.4.46 - 2026-05-23
------------------------------

- Remove redundant `[!IMPORTANT]` callout from Quick Start (duplicated Phase 5).
- Trim iwd `<details>` skip note (covered in Managed Files preamble).

v7.4.44 - v7.4.45 - 2026-05-23
------------------------------

- Phase 1: enumerate all 10 preflight steps in runtime order (Bootstrap → `_init_runtime` → lock → sudo → deps → disk → network → kernel → regdom → config).
- Phase 5: add post-rebuild sanity row (vmlinuz + initramfs + loader-entry kernel-path verify).
- Exit codes row `1`: drop stale "old-kernel warn"; kernel <6.14 is matrix FAIL.
- Hardware section: clarify CPU check runs in `_init_runtime` on every mode.
- `_ry_show_help`: align exit-code one-liner with README row `1` (kernel <6.14 hard-floor fail).

v7.4.40 - v7.4.44 - 2026-05-22
------------------------------

- Hardware: drop orphan kernel-bugzilla tracker line.
- Managed Files: clarify both iwd-gated destinations skip when iwd absent.
- Configuration: align cpupower-service + tmpfiles blocks to systemd-logind shape; collapse three low-density tables.
- Logs: drop incorrect `cleanup_exit` claim from Footer-marker row; normal-exit footers carry no marker.

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
- Split four >220-char lines (`_unit_state`, `_post_sysctl` warn chain, header JSONL printf, pacman db-lock string).
- `_post_cpupower`: split single-line restart-warn into `_warn` + `_info` pair.
- `_init_runtime`: lift KERNEL_PARAMS metachar regex to `set -l`; multi-line if-chain.
- `_check_phase_cmdline`: emit `CHECK_PREFLIGHT` JSONL when `/proc/cmdline` empty.
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

v7.4.36 - v7.4.37 - 2026-05-22
------------------------------

- `_vrsv_chk_nm_dispatcher`: short-circuit on `not-found` (`_warn` + return 0).

v7.4.35 - v7.4.36 - 2026-05-22
------------------------------

- Remove three stray `\;` tokens from inline `for` lists (`_vsb_loader`, `_verify_static_system`, `_ry_check_deps`).
- `RY_INITRD_WARN_MB` invalid values queue into `_RY_DEFERRED_WARNS`.
- Malformed sysctl entries surface via `EXIT_GEN_SYSCTL` dispatcher branch.
- Add defensive `MATRIX_TRUNCATED` JSONL diagnostic in `_rdi_matrix_rows`.

v7.4.34 - v7.4.35 - 2026-05-22
------------------------------

- Split two >250-char lines (MASK service list, sudo-cache warning printf).
- Drop dead `2>/dev/null` on `status stack-trace`.

v7.4.33 - v7.4.34 - 2026-05-21
------------------------------

- LOC reduction 5113 → 4468: ~200 multi-line blocks collapsed to `; and` chain form.
- Function count unchanged (256 multi-line + 8 single-line); largest still `_ry_show_help` at 39 LOC.

v7.4.32 - v7.4.33 - 2026-05-21
------------------------------

- Consolidate CHANGELOG per-patch entries into ranges; close chain gaps.
- Bump README version badge and run-summary example matrix.

v7.4.31 - v7.4.32 - 2026-05-21
------------------------------

- Expand four single-line content generators (`loader.conf`, resolved drop-in, NM drop-in, `cpupower-service.conf`) to multi-line `printf '%s\n' \` form; output byte-identical.

v7.4.22 - v7.4.31 - 2026-05-21
------------------------------

- README cleanup: Phase blocks → uniform "N sequential operations" intro + ordered step list.
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
