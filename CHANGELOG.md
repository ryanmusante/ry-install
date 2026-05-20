ry-install ChangeLog
====================

v7.4.20 - v7.4.21 - 2026-05-20
------------------------------

- `_install_preflight`: extracts `_ip_record_regdom` for the regdom phase-record block; function 57 → 47 lines (within ≤50 target).
- `_install_aur_packages`: extracts `_iap_per_pkg_retry` for the post-batch-failure per-package retry loop and `_iap_record_result` for final phase-record dispatch; function 66 → 44 lines.
- `_install_rebuild_boot`: extracts `_irb_taint_gate` for the mkinitcpio-revert + `_RY_BOOT_TAINTED` early-exit gates; function 60 → 49 lines.
- `_rdi_run_phases`: extracts `_rrp_optional_indexer` for `updatedb` / `pkgfile --update` paired blocks; function 60 → 47 lines.
- `_verify_static_services`: 9-way `or test "$_enabled_state" = <state>` chain (359-char line) collapsed to `contains -- "$_enabled_state" enabled enabled-runtime alias static linked linked-runtime indirect generated transient`; semantics preserved.
- `_ry_check_wireless_regdom` / `_ry_apply_wireless_regdom`: defensive double-quotes around `$_conf` in 5 `test -f` / `grep` / `tee` / `chmod` sites; fish does not word-split, but matches the script-wide convention for paths.
- README: `Run Summary` heading added to the `Contents` TOC between `Install Flow` and `Configuration`; the `#run-summary` anchor was orphaned from v7.4.11 introduction.

v7.4.19 - v7.4.20 - 2026-05-20
------------------------------

- Bootstrap: `TMPDIR` pointing at a non-existent directory now overrides to `/tmp` with a stderr warning. Previously the env var leaked through `_tmp_dir`, causing every downstream `mktemp -p` to fail and every `_run` to return `EXIT_RUN_TMPFAIL` with no root-cause surface.
- `_tmp_dir`: gains a `test -d "$TMPDIR"` defence-in-depth so a non-existent path can never leak even if the bootstrap probe is bypassed.
- `_ry_apply_wireless_regdom`: explicit `chmod 0644` after `sudo -n tee` writes `/etc/conf.d/wireless-regdom`, normalising mode against root's umask.
- `_install_aur_packages`: when `mt76-mt7925-dkms` is in `AUR_PKGS` but `modinfo mt7925e` fails post-build, phase result is now `WARN` (sets `INSTALL_HAD_ERRORS`) instead of silent `PASS`.
- `_install_rebuild_boot` / `_post_boot`: emit a JSONL `BOOT_TAINTED_OVERRIDE` log + stderr warn when `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses the taint gate. Post-mortem can now distinguish forced from clean runs.
- `_rdi_render_matrix` split into `_rdi_matrix_header` / `_rdi_matrix_rows` / `_rdi_matrix_footer`; each ≤50 lines. Output byte-identical to the previous monolithic renderer.
- `_is_system_dst`: trimmed to `/etc/*` and `/boot/*` (the only managed-destination roots); dead branches `/efi`, `/usr`, `/var`, `/srv`, `/opt` removed.
- `_RY_SLEEP_FRAC`: removed (set on bootstrap, never consumed in any sleep call).
- `_dc_erase_globals`: erases `_RY_MTX_*` matrix tally globals as part of cleanup symmetry.

v7.4.18 - v7.4.19 - 2026-05-20
------------------------------

- `_install_preflight`: `_ry_check_kernel_version` rc=2 (hard floor `<6.14`) now records matrix `FAIL` instead of `WARN`. Soft-warn rc=1 (stability floor, ntsync, 6.19.0) remains `WARN`.
- `_vrsv_wifi`: gate `pgrep -x iwd` probe on `command -q pgrep`; warn when procps-ng is absent instead of false `FAIL`.
- `_vsp_pacman_conf`: reword "ParallelDownloads not set (default: 1)" → "(sequential downloads — uncomment in /etc/pacman.conf to enable)".
- README: Phase 1 — "unrestricted sudo" → "cached sudo credential" (stale phrasing from pre-v7.4.6 strict `NOPASSWD: ALL` gate).

v7.4.17 - v7.4.18 - 2026-05-20
------------------------------

- `_rdi_render_matrix`: `_inner = w + 6` → `w + 8`. Previously the top/bottom/mid bars and footer rows were 78 chars against 80-char data rows; all rows are now uniformly 80 wide.
- CHANGELOG: `v7.4.x` entry dates normalised to monotonic `2026-05-20`.

v7.4.16 - v7.4.17 - 2026-05-20
------------------------------

- Script: 76 adjacent `set -l/-g` runs collapsed to semicolon-chained one-liners (5204 → 5040 lines).
- README: every `<details>` opens to a markdown table; prose-only collapsibles converted back to tables.

v7.4.15 - v7.4.16 - 2026-05-20
------------------------------

- README: 16 enumerative tables trimmed; script remains source of truth via `--verify-static`.

v7.4.14 - v7.4.15 - 2026-05-20
------------------------------

- README: 17 `<summary>` headers stripped of parenthetical suffixes; counts retained.

v7.4.13 - v7.4.14 - 2026-05-20
------------------------------

- `_rdi_summary`: gate REBOOT advisory on `_RY_BOOT_CRIT_HIT`; print `DO NOT REBOOT` + recovery on `FAIL-BOOT-CRITICAL`.
- `_install_rebuild_boot`: record `Boot: post-rebuild sanity` SKIP on `_irb_sdboot_apply` non-zero return.
- `_rdi_render_matrix`: totals line gains `N/A` bucket.
- `_ry_check_kernel_version`: rc=0/1/2 (ok/soft-warn/hard-fail); only hard floor `<6.14` elevates `INSTALL_HAD_ERRORS`.
- `_install_preflight`: regdom `test;and;or` chain refactored to `if/else`.
- New `_irb_skip_post_mki` and `_ip_bail_prep` helpers consolidate inline SKIP/bail cascades.

v7.4.12 - v7.4.13 - 2026-05-20
------------------------------

- Run-summary matrix renders on preflight bail (`EXIT_PREFLIGHT` / `EXIT_USAGE`).
- Verdict `FAIL-BOOT-CRITICAL` keyed on dedicated `_RY_BOOT_CRIT_HIT` (was overloaded `_PROG_FINALIZED_SKIP`).
- `_phase_record`: strip embedded newlines and `U+2502` field delimiter from arguments.

v7.4.11 - v7.4.12 - 2026-05-20
------------------------------

- Run-summary matrix: install completion prints box-drawn Unicode matrix to stderr (CHECK / RESULT / EVIDENCE + totals + verdict). `RY_INSTALL_NO_MATRIX=1` opts out.
- New `_phase_record` helper appends rows to `_RY_PHASE_RESULTS` and JSONL.
- New `_rdi_render_matrix` renderer and `_rdi_elapsed` formatter.
- `_ry_install_file`: track changed-vs-idempotent deploys.
- Phase instrumentation across preflight / packages / AUR / configs / fstab / services / boot / finalize.

v7.4.10 - v7.4.11 - 2026-05-20
------------------------------

- `_csp_filter_rdeps`: drop redundant `2>/dev/null` on numeric `pipestatus` tests.
- `--description` coverage: 18 single-line helpers gain `--description` for 100% coverage.

v7.4.9 - v7.4.10 - 2026-05-20
-----------------------------

- Stage-1-rc semantics: 7 callers check only pipe stage 1 — fish `string` builtins rc=1 on empty input is normal. Empty enumeration now routes to "NONE found" diagnostics.

v7.4.7 - v7.4.8 - 2026-05-20
----------------------------

- `_content__etc_default_cpupower-service.conf`: key `governor` → `GOVERNOR` for upstream env-script compatibility.
- `_csp_filter_rdeps`: accept fish `string` rc=1 on stages 2-4 (no-op).

v7.4.6 - v7.4.7 - 2026-05-20
----------------------------

- `_ry_sudo_cache_banner`: trim to 3 lines (risk, mitigations, recovery).

v7.4.5 - v7.4.6 - 2026-05-20
----------------------------

- Strict `NOPASSWD: ALL` preflight gate dropped; replaced with `_ry_sudo_cache_banner` install-mode warning.

v7.4.4 - v7.4.5 - 2026-05-20
----------------------------

- Inline comments collapsed from multi-line to single-line form.

v7.4.0 - v7.4.3 - 2026-05-20
----------------------------

- Fish-version preflight: flat sentinel replaces nested `begin ... end`.
- Preflight rejects `timeout(1)` lacking `--foreground/--kill-after` (busybox, uutils).
- `_acquire_lock`: PID-recycle race closed via `/proc/$pid/comm`.
- `_acquire_lock_fresh`: `umask 0077` around `mkdir`.
- `_ensure_sudo_cached`: `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.
- `_csp_filter_rdeps`: pipestatus checked across all 4 pipe stages.
- `_dc_kill_children`: SIGKILL grace widened to 0.5s.
- `_cleanup_tmpfiles`: two-step `sudo -n true` gate before `sudo find`.

v7.3.9 - v7.4.0 - 2026-05-19
----------------------------

- `_RY_LOUD_ERR`: critical preflight failures reach stderr in default QUIET install mode; `--check` stays silent.
- `_ir_resolve_root_uuid`: 4-way mode dispatch.
- `_RY_LOG_SUPPRESS_CREATE`: no more orphan `preflight-*.jsonl` on argparse-error paths.
- `_cse_batch_enable`: accept-list adds `linked`, `linked-runtime`, `indirect`, `generated`, `transient`.
- `_chk_perms`: strip leading setuid/setgid/sticky digit.
- `_run_emit_stream`: head + tail capture (100 each) preserves build-error tail.
- `_boot_initrd_size_scan`: byte comparison removes off-by-1MB silent pass.
- `_verify_runtime_kparams`: pre-extract preempt/BAR/TSC from full dmesg before 5000-line cap.

v7.3.0 - v7.3.9 - 2026-05-17 to 2026-05-18
------------------------------------------

- Short-circuit chain collapse: 9 single-statement bodies, 16 three-line + 95 four-line if-end blocks (5177 → 4842 lines).
- `_ir_resolve_root_uuid`: `_reason` distinguishes "findmnt failed" from "invalid UUID shape".
- `_ry_check_disk_space`: labels switch to `GiB`/`MiB`.
- `_vrkg_rebar_sam`: lspci regex broadens to any G-suffix or M-values ≥ 500.
- `_err_loud`: log-only when `MODE=check` (silence contract).
- `_ry_check_deps`: systemd `<250` hard-fail preflight gate.
- `_run`: tmpdir-alloc sentinel promoted from magic 251 to `EXIT_RUN_TMPFAIL`.
- Log filename format: `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.

v7.2.0 - v7.2.6 - 2026-05-17
----------------------------

- New `_ry_apply_wireless_regdom` driven by `RY_INSTALL_WIRELESS_REGDOM`.
- `/etc/default/cpupower-service.conf` added; `/etc/drirc` dropped.
- `PKGS_ADD` gains `cpupower`; `EXPECTED_SERVICES` gains `cpupower.service`.
- `_vrk_cpu_state`: scaling_governor `powersave` → `performance`.
- `_vmh_order_checks`: adds systemd:autodetect, autodetect:microcode pair rules and fsck-last invariant.
- `cpupower-epp.service` dropped; `SERVICE_DESTINATIONS` empty.
- `_RY_MANAGED_FILE_COUNT`: 13 → 12; `EXPECTED_SERVICES`: 4 → 3.
- `_vre_fstab`: noatime/lazytime/commit=10 token tests unified under `(^|,)tok(,|$)`.
- `_ir_validate_counts`: adds `_RY_POST_HOOKS:14` and `_RY_BOOT_CRITICAL_DSTS:4`.
- `_mr_copy_size_verify`: adds `cmp -s` after size match.

v7.0.0 - v7.1.0 - 2026-05-15 to 2026-05-17
------------------------------------------

- NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
- `MASK` gains `avahi-daemon.service` and `.socket` (10 → 12).
- New `_csm_disable_ufw_rules`.
- `PKGS_ADD` gains `realtime-privileges`; `PKGS_DEL` gains `bolt`.
- New `_ry_check_wireless_regdom` and `_vrk_audio_state`.
- `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`.
- `_vsb_mkinitcpio`: amdgpu probe `*amdgpu*` → `\bamdgpu\b`.
- `_ry_check_deps`: GNU-coreutils `df` probe.
- `HandleSecureAttentionKey` gate: `<256` → `<257`.
- `_vrkm_blacklist`: normalises hyphen → underscore before `lsmod` compare.
- Sixty-eight bare system-command invocations gain a `command` prefix.
- README: `<details>` blocks switch to tables for mobile rendering.

v6.5.0 - v6.5.18 - 2026-05-14 to 2026-05-15
-------------------------------------------

- `_rvc_dispatch`: adds `*/tmpfiles.d/*` case and `_grep_tmpfiles_entry`.
- New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed destination.
- `_aur_verify_mt7925`: asserts both `pacman` and `modinfo` resolve.
- Log-dir mode probe extended to three managed paths.
- `_awf_finalize_mv`: sudo-lapse returns `$EXIT_FAIL`.
- `_ry_exit`: bail path writes the JSONL footer.
- `_cleanup_pipe`: SIGPIPE log gated on `_RY_HEADER_WRITTEN`.
- `_dc_sweep_tmpfiles`: spurious `TMPFILE_STUCK` fix.
- `_verify_static_services`: multi-`ExecStart` guard.
- `_err_loud`: deduplicated via `_msg_print --force`.
- `_vsb_entries`: distinguishes lapsed-sudo from empty entries dir.
- `_ry_check_deps`: adds 10 coreutils.
- `KERNEL_PARAMS`: metachar regex backslash escaping tightened.

v6.2.0 - v6.2.13 - 2026-05-12 to 2026-05-14
-------------------------------------------

- HOME field-6 captured via `awk -F:` (GECOS-tolerant).
- `_ry_check_deps`: adds `mv`, `grep`.
- JSONL header written before `_init_runtime`.
- `LOCK_DIR`: gains `chmod 700`.
- Emit functions use `printf` (flag-injection guard).
- `_run` split into `_run`, `_run_redact_cmd`, `_run_effective_timeout`.
- `_run`: timeout-bypass for `pacman`, `paru`, `mkinitcpio`, `sdboot-manage`, `paccache`.
- Tmpfile-path redaction under `$TMPDIR`.
- `_ip_pacman_invoke`: `-Syyu` retry gated on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`.
- Per-package AUR retry.
- `_vrkg_*`: GPU runtime checks.
- `_atomic_write_file`: post-write symlink re-check (TOCTOU).
- `_fstab_atomic_replace`: `findmnt --verify` hard-fail.
- User destinations install with `0600`.
- `--install-file`: single-file redeploy with per-target post-hook dispatch.
- argparse `--exclusive` mode group.
- Atomic `mkdir` + pid-file lock.
- `_ir_validate_counts`: enforces array-count invariants.
- `_RY_POST_HOOKS`: first-match table for `--install-file` hooks.

v6.0.0 - v6.1.0 - 2026-05-12
----------------------------

- Reduction release: 5994 → 4985 lines.
- Drops GNU-tool probes, source-mode scaffolding, ntsync probes, sudo-keepalive.
- Drops JSONL progress events, log rotation, parallel-child PID guard.
- Drops atomic-write TOCTOU re-stat, boot-wipe gates, LVM detection.
- User-bus detection added via `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`.
