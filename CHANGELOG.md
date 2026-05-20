ry-install ChangeLog
====================

v7.4.9 - v7.4.10 - 2026-05-19
-----------------------------

- `_installed_bytes` (sudo + non-sudo branches): check only stage 1 (`cat` rc) — `string collect` rc=1 on empty input is normal, not an error.
- `_vsb_entries`: check only stage 1 (`find` rc); empty entries dir now correctly routes to `_fail "NONE in entries/"` with `sdboot-manage gen` recovery hint.
- `_vrs_nm_perms`: check only stage 1; zero NM connection files no longer false-warn "cannot enumerate" on iwd-only systems.
- `_enum_boot_entries`: check only stage 1; empty entries dir no longer logs spurious BOOT_ENUM_FAIL with sudo-lapse cause.
- `_pbs_check_boot_files`: check only stage 1; zero kernel/initramfs files now route to "No X found" instead of misleading "Cannot enumerate (sudo lapsed)".
- `_pbs_check_entries`: same — empty entries dir routes to "No boot loader entries" diagnostic.
- `_boot_initrd_size_scan`: check only stage 1; zero initramfs files no longer false-warn.
- Remove `_pipe_all_ok` helper (dead code; all callers now use stage-1-specific checks per fish `string` rc semantics).

v7.4.8 - v7.4.9 - 2026-05-19
----------------------------

- `_do_cleanup`: run `_dc_kill_children` before `_dc_erase_globals` so lock-release gate vars `_RY_HOLDS_LOCK` / `_RY_LOCK_DIR_OWNED` are still set when `$LOCK_DIR` is removed. Fixes orphaned `~/.local/share/ry-install/.lock/` after every clean exit (regression from cleanup-decomposition refactor).

v7.4.7 - v7.4.8 - 2026-05-19
----------------------------

- `_content__etc_default_cpupower-service.conf`: rename key `governor` → `GOVERNOR` for upstream cpupower env-script compatibility.
- `_verify_static_system`: update `_chk_grep` pattern to `GOVERNOR='performance'`.
- `_csp_filter_rdeps`: accept fish `string` rc=1 on stages 2-4 (no-op); only rc≥2 fails. Rename log token `PACTREE_PIPE_PARTIAL` → `PACTREE_PIPE_FAIL`.
- README: document cpupower-service.conf key as `GOVERNOR`.

v7.4.6 - v7.4.7 - 2026-05-20
----------------------------

- `_ry_sudo_cache_banner`: trim from 17 lines to 3 (vital info only — risk, mitigations, recovery).
- README: collapse `[!WARNING]` callout to single sentence.

v7.4.5 - v7.4.6 - 2026-05-20
----------------------------

- `_ip_probe_sudo_policy`: removed; strict NOPASSWD: ALL preflight gate no longer enforced.
- New `_ry_sudo_cache_banner`: install-mode stderr warning that sudo cache can lapse mid-run, with mitigation options (timestamp_timeout extend, parallel `sudo -v` keepalive, NOPASSWD drop-in).
- `_dc_sweep_filesystem`: drop `ry-sudo-l-err.*` tmpfile glob (dead after policy probe removal).
- README: replace strict sudo-policy preflight requirement with `[!WARNING]` cache-lapse callout under Prerequisites.

v7.4.4 - v7.4.5 - 2026-05-20
----------------------------

- Inline comments: collapse 7 multi-line blocks to single-line form; shebang + version header retained.

v7.4.3 - v7.4.4 - 2026-05-20
----------------------------

- README: 17-site trim — drop internal rationale, collapse verbose table cells, deduplicate AUR prose against Package caveats.
- CHANGELOG: rewrite to one-bullet-per-change format.

v7.4.2 - v7.4.3 - 2026-05-20
----------------------------

- `_ip_probe_sudo_policy`: regex requires `NOPASSWD:` explicitly; plain `(user) ALL` rejected.
- `_install_aur_packages`: early-exit logic was inverted (masked by `AUR_PKGS:2` invariant); replaced with `test (count) -gt 0; or return 0`.
- `_acquire_lock`: close `kill -0` / `/proc/$pid/comm` race — re-test `kill -0` when comm reads empty.
- `_dir_group_or_world_writable`: reject modes shorter than 3 chars post-strip; drop redundant `math 2>/dev/null`.
- README: sudo-policy line uses `(user) NOPASSWD: ALL` (no brackets).

v7.4.1 - v7.4.2 - 2026-05-19
----------------------------

- `_ip_probe_sudo_policy`: ALL-grant regex gains end-anchor; skip lines with `,\s*!` negation.
- `_ensure_sudo_cached`: add `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.
- `_csp_filter_rdeps`: pipestatus checked on all 4 pipe stages (was pactree-only).
- `_acquire_lock`: PID-recycle check via `/proc/$_stale_pid/comm`.
- `_acquire_lock_fresh`: `umask 0077` around `mkdir`.
- `_dc_kill_children`: SIGKILL grace widened `$_RY_SLEEP_FRAC` → 0.5s.
- `_cleanup_tmpfiles`: two-step `sudo -n true` gate before `sudo find`.
- `_log`: empty-`LOG_FILE` early-return.
- `_cleanup`: 7×`--on-signal` consolidated on one fn; `_cleanup_other` removed.
- `_ry_install_file`: sudo `mkdir -m 0755`.
- Cosmetic: redundant `2>/dev/null` removed from `_vrk_*` dmesg cap and `_dir_group_or_world_writable` numeric tests.
- README: `RY_INSTALL_NO_INTERACTIVE_SUDO` documented; sudo-policy preflight note added.

v7.4.0 - v7.4.1 - 2026-05-20
----------------------------

- Fish-version preflight: flat `_fish_ok` sentinel replaces nested `begin ... end`.
- New preflight: rejects `timeout(1)` lacking `--foreground/--kill-after` (busybox, uutils).
- `_vrs_boot_perf`: `(count $_tm) -gt 0` guard replaces fragile `[-1]` negative-index.

v7.3.9 - v7.4.0 - 2026-05-19
----------------------------

- `_RY_LOUD_ERR`: critical preflight failures reach stderr in default QUIET install mode; `--check` stays silent.
- `_ir_resolve_root_uuid`: 4-way mode dispatch (`install`/`install-file` hard-fail, `verify-static` hard-fails, `verify-runtime` logs + continues, `check` silent).
- `_RY_LOG_SUPPRESS_CREATE`: no more orphan `preflight-*.jsonl` on argparse-error paths.
- `_cse_batch_enable`: accept-list adds `linked`, `linked-runtime`, `indirect`, `generated`, `transient`.
- `_chk_perms`: strip leading setuid/setgid/sticky digit.
- `_run_emit_stream`: head + tail capture (100 each) preserves build-error tail.
- `_boot_initrd_size_scan`: byte comparison removes off-by-1MB silent pass.
- `_verify_runtime_kparams`: pre-extract preempt/BAR/TSC from full dmesg before 5000-line cap.

v7.3.8 - v7.3.9 - 2026-05-18
----------------------------

- Short-circuit chain collapse: 9 single-statement bodies, 16 three-line + 95 four-line if-end blocks (5177 → 4842 lines).
- Invariants preserved: 253 functions, 12 managed destinations, all array counts.

v7.3.7 - v7.3.8 - 2026-05-18
----------------------------

- `_ir_resolve_root_uuid`: `_reason` string distinguishes "findmnt failed" from "invalid UUID shape".
- `_ry_check_disk_space`: labels switch from `GB`/`MB` to `GiB`/`MiB`.
- `_vrkg_rebar_sam`: lspci regex broadens to any G-suffix or M-values ≥ 500.
- README + CHANGELOG re-styled; four composite statements split across continuations.

v7.3.5 - v7.3.6 - 2026-05-17
----------------------------

- `_err_loud`: log-only when `MODE=check` (silence contract preserved).
- `_ry_show_help`: clarifies fish 3.x `--on-signal` limitation; notes `--check` requirements.
- `_ry_do_check`: three rc-blocks collapse to phase-fn-name loop.
- `_ry_check_network`: `test;and;or` replaced with explicit `if/else`.
- `_acquire_lock`: stale-pid regex tightens `^\d+$` → `^[1-9]\d*$`.
- `_run`: tmpdir-alloc sentinel promoted from magic 251 to `EXIT_RUN_TMPFAIL`.

v7.3.0 - v7.3.3 - 2026-05-17
----------------------------

- `_ry_check_deps`: systemd `<250` hard-fail preflight gate.
- Log filename format: `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.

v7.2.4 - v7.2.6 - 2026-05-17
----------------------------

- `_vre_fstab`: noatime/lazytime/commit=10 token tests unified under `(^|,)tok(,|$)`.
- `_ir_validate_counts`: adds `_RY_POST_HOOKS:14` and `_RY_BOOT_CRITICAL_DSTS:4`.
- `_mr_copy_size_verify`: adds `cmp -s` after size match.
- README: bootloader section 8 → 10 keys; initramfs invariants 4 → 9 → 11.

v7.2.1 - v7.2.3 - 2026-05-17
----------------------------

- `_vmh_order_checks`: adds systemd:autodetect, autodetect:microcode pair rules and fsck-last invariant.
- `cpupower-epp.service` dropped; `SERVICE_DESTINATIONS` empty.
- `_RY_MANAGED_FILE_COUNT`: 13 → 12.
- `EXPECTED_SERVICES`: 4 → 3.
- README: Configuration expands 2 → 19 per-domain collapsibles.

v7.1.0 - v7.2.0 - 2026-05-17
----------------------------

- New `_ry_apply_wireless_regdom` driven by `RY_INSTALL_WIRELESS_REGDOM`.
- `_install_aur_packages`: documents benign tokens via `AUR_NOISE_NOTE`.
- `/etc/drirc` dropped; `/etc/default/cpupower-service.conf` added.
- `PKGS_ADD` gains `cpupower` (14 → 15).
- `EXPECTED_SERVICES` gains `cpupower.service`.
- `_vrk_cpu_state`: scaling_governor `powersave` → `performance`.
- README: Strix Halo ACP audio known-issue + REGDOM env-var row.

v7.0.17 - v7.0.20 - 2026-05-17
------------------------------

- `_vrkg_rebar_sam`: lspci gains `command` prefix; drops 256M match.
- `_RY_DMESG_BAR`: drops `above.4g`.
- `_MY_UID`: hoists below early-exit loop.
- `_install_aur_packages`: sets `_RY_AUR_PARTIAL` only when `0 < failed < count`.
- `_post_service`: adds `systemctl try-restart` after `enable --now`.
- `_post_nm`: adds `try-restart iwd.service` when `iwd/main.conf` is the target.

v7.0.11 - v7.0.16 - 2026-05-16
------------------------------

- `KVER`: switches to `(command uname -r)`.
- `_enum_boot_entries`: pipestatus capture + `_RY_BOOT_ENUM_OK`.
- `_acquire_lock_fresh`: `_RY_LOCK_DIR_OWNED` hoists above `chmod 700`.
- `_vs_read_symmetry_selftest`: memoised via `_RY_READSYM_RESULT`.
- Pre-bootstrap `command -q date` check.
- `_ry_check_deps`: adds `date(1)`.

v7.0.7 - v7.0.10 - 2026-05-16
-----------------------------

- `_vre_fstab`: malformed-line filter becomes `_RY_AWK_EXT4_MALFORMED_FILTER`.
- `_vrkm_blacklist`: normalises hyphen → underscore before `lsmod` compare.
- Sixty-eight bare system-command invocations gain a `command` prefix.
- README: `<details>` blocks switch to tables for mobile rendering.

v7.0 - v7.0.6 - 2026-05-15 to 2026-05-16
----------------------------------------

- NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
- `MASK` gains `avahi-daemon.service` and `.socket` (10 → 12).
- New `_csm_disable_ufw_rules`.
- `PKGS_ADD` gains `realtime-privileges`; `PKGS_DEL` gains `bolt`.
- New `_ry_check_wireless_regdom` and `_vrk_audio_state`.
- `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`.
- `_vsb_mkinitcpio`: amdgpu probe `*amdgpu*` → `\bamdgpu\b`.
- `_ry_check_deps`: GNU-coreutils `df` probe.
- `HandleSecureAttentionKey` gate: `<256` → `<257`.

v6.5.13 - v6.5.18 - 2026-05-15
------------------------------

- `_rvc_dispatch`: adds `*/tmpfiles.d/*` case and `_grep_tmpfiles_entry`.
- New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed destination (12 → 13).
- `_aur_verify_mt7925`: asserts both `pacman` and `modinfo` resolve.
- `_installed_bytes`: terminal `printf` collapsed.
- README tables trimmed.

v6.5.8 - v6.5.12 - 2026-05-15
-----------------------------

- Log-dir mode probe extended to three managed paths.
- `_awf_finalize_mv`: sudo-lapse returns `$EXIT_FAIL`.
- `_ry_exit`: bail path writes the JSONL footer.
- `_cleanup_pipe`: SIGPIPE log gated on `_RY_HEADER_WRITTEN`.
- `_vrs_installed_file_perms`: emits `perm_vfat_skipped` count.

v6.5 - v6.5.7 - 2026-05-14
--------------------------

- `_dc_sweep_tmpfiles`: spurious `TMPFILE_STUCK` fix.
- `_verify_static_services`: multi-`ExecStart` guard.
- `_err_loud`: deduplicated via `_msg_print --force`.
- `_vsb_entries`: distinguishes lapsed-sudo from empty entries dir.
- `_ry_check_deps`: adds 10 coreutils.
- `_chk_grep`: stage-2 switches to `grep -wF`.
- `KERNEL_PARAMS`: metachar regex backslash escaping tightened.

v6.2.9 - v6.2.13 - 2026-05-13 to 2026-05-14
-------------------------------------------

- HOME field-6 captured via `awk -F:` (GECOS-tolerant).
- `_ry_check_deps`: adds `mv`, `grep`.
- `pacman -Qq` and `-T` status captured.
- JSONL header written before `_init_runtime`.
- `LOCK_DIR`: gains `chmod 700`.
- Emit functions use `printf` (flag-injection guard).
- `_run` split into `_run`, `_run_redact_cmd`, `_run_effective_timeout`.

v6.2.4 - v6.2.8 - 2026-05-13
----------------------------

- `_run`: timeout-bypass for `pacman`, `paru`, `mkinitcpio`, `sdboot-manage`, `paccache`.
- Tmpfile-path redaction under `$TMPDIR`.
- `_ip_pacman_invoke`: `-Syyu` retry gated on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`.
- Per-package AUR retry.
- `_vrkg_*`: GPU runtime checks.
- `_atomic_write_file`: post-write symlink re-check (TOCTOU).
- `_fstab_atomic_replace`: `findmnt --verify` hard-fail.
- User destinations install with `0600`.
- Capture cap raised from 100 to 500.

v6.2.0 - v6.2.3 - 2026-05-12 to 2026-05-13
------------------------------------------

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
