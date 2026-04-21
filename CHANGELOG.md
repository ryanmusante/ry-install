# ry-install changelog

v4.1.8  2026-04-20
- `_install_packages`: dropped misleading "Synchronizing package databases..." `_info` (sync is inline in `pacman -Syu`); replaced stale "install then remove" comment with phase-4 cross-reference.
- `_ry_show_help`: `--` description now states positional args after `--` are rejected (matches dispatch behavior); `NO_COLOR` added to ENVIRONMENT block (parity with README).
- `_install_fstab_opts`: deregisters deleted `tmpfstab` from `_TRACKED_TMPFILES` after atomic rename (cleanup list no longer retains stale entry).
- `_preflight_boot_sanity`: 3 `find` enumerations switched to `-print0 | string split0` for parity with `_install_post_package_refresh` (L4456) and log rotation (L5952). Closes \n-in-filename hazard.

v4.1.7  2026-04-20
- README: tables trimmed to essential columns/values; `# Managed Files` index col, Prerequisites Notes col, and Deprecated Flags Notes col dropped.
- README: sample log timestamps + version bumped to 4.1.7 / 2026-04-20.
- CHANGELOG: v4.1.6–v4.1.2 entries condensed; line-number noise dropped where redundant with function names.

v4.1.6  2026-04-19
- 6 JSONL writers (`_json_str`, `_log`, `_msg` bug branch, `_write_step_time`, top-level header, `_write_footer`) now share `2>/dev/null` on append redirects. Closes TOCTOU stderr-noise window when log rotation races `_log`'s existence test.
- Known deferral: `_ry_verify_runtime` (842 L), `_ry_verify_static` (627 L), `_ry_do_check` (331 L), `_ry_validate_configs` (262 L) remain monolithic — category-split refactor tracked for 4.2.0.

v4.1.5  2026-04-19
- `_validate_profile` destination guard split: literal duplicates vs slash→underscore key collisions now report distinct messages.

v4.1.4  2026-04-19
- `_tmpfile_key`: reverted 4.1.3's sha256 prefix back to `string replace -a '/' '_'`. Producer/consumer parity restored across 8 child-side derivations.
- `_validate_profile`: tmpfile-key collision guard rejects destinations whose slash→underscore keys collide.
- `_ry_validate_configs` + `_ry_verify_static`: removed dead timeout-vs-crash branches; collapsed phantom timeout paths into single FAIL.
- `_kill_sudo_keepalive`: `pkill -TERM -P` reaps descendants before SIGTERM/SIGKILL.
- `_detect_lvm`: timeout 5 → 10 (slow PAM/NSS first-call).
- `_run` stderr dedup: `sed` → `string trim --left` (fish-native).
- Boot-time parse: `LC_ALL=C` for locale-safe float→int.

v4.1.3  2026-04-19
- CLI dispatcher: manual `while/switch` → `argparse --exclusive`. 13-flag parity preserved.
- `_write_footer`: dropped redundant `finished` field.
- `_ry_verify_static`: `implicit_svcs` derived from `SYSTEM_DESTINATIONS` (no longer hardcoded).
- `_ry_validate_configs`: prune val_dir + content_dir from `_TRACKED_TMPFILES` after rm.
- `_preflight_boot_sanity`: BLS path-traversal check now exact-segment match.

v4.1.2  2026-04-19
- `_install_preflight` sudo-tag regex: `\b!PASSWD\b` failed to anchor; fix to `(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)`.
- `_ry_do_install`: manifest-write decoupled from `INSTALL_HAD_ERRORS`.
- `_install_rebuild_boot`: `sdboot-manage update` failure → EXIT_BOOT_CRIT.
- Unattended `-Syu` now gated behind `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1`; without ack prints 3 RSS headlines/feed.
- `_acquire_lock`: quoted `"$fish_pid"` in `sh -c` args.
- `_ry_check_deps`: `flock(1)` HARD → SOFT (fallback exists).

v4.1.1  2026-04-19
- `_cleanup`: fish 3.4+ passes SIG-prefixed name as `$argv[1]`; added `case HUP SIGHUP`, `INT SIGINT`, `QUIT SIGQUIT`, `TERM SIGTERM` — exit codes 129/130/131/143 correctly distinguished.

v4.1.0  2026-04-19
- Removed `--test-all` (169 L) and `--completions` (93 L). Pre-commit `fish --no-execute` supersedes the former; README is authoritative for the latter.
- `_ry_show_help`: 72 → 49 lines.

v4.0.x  2026-04-18 → 2026-04-19
- KERNEL_PARAMS 12 → 15; SYSCTL_VALUES 21 → 19; PKGS_ADD 15 → 14; EXPECTED_SERVICES 3 → 4; new dep: `nftables`.
- `amd_pstate=active`; `iommu=pt`; `tsc=reliable`; `loglevel=3`; `rd.udev.log_level=3`; `rd.systemd.show_status=auto`.
- RADV: `RADV_EXPERIMENTAL=transfer_queue,hic`; `RADV_PERFTEST=sam,nircache`.
- `RESOLVED_MDNS`: `no` → `resolve` (fixes `.local` under COSMIC).
- `systemd-coredump.socket` added to MASK; `irqbalance.service` removed.
- `_install_fstab_opts`: `chmod/chown --reference=/etc/fstab` before `findmnt --verify`; `commit=10` appended.
- Log subdirs created under `umask 0077` with chmod 700 repair.
- 8 hash pipelines: capture raw line + snapshot `$pipestatus` (empty-stdin SHA mask fix).
- `_ry_namespace_cleanup`: `HOME` preserved; source-exit no longer reverts caller `HOME`.
- All multi-line `#` blocks collapsed; `fish_indent` canonical pass.

v3.51.x  2026-04-13 → 2026-04-17
- Sourcing detection: `status stack-trace | string match -q '*from sourcing*'`.
- `_ry_exit`: namespace cleanup runs unconditionally.
- `_acquire_lock` + keepalive: `%self` → `$fish_pid`; `flock -n -E 5` reclaim before rmdir+mkdir+PID re-verify.
- `_pregenerate_content_files`: writes `<safe>.genfail` sentinel on generator failure; consumers detect it.
- Boot-wipe marker: stores `"<count> <sha256-of-sorted-basenames>"`; re-prompts on basename-set change.
- `_install_aur_packages`: paru-missing → `INSTALL_HAD_ERRORS=true` + `return 1` when AUR_PKGS non-empty.
- `_atomic_write_file` parent-dir trust: 3 sudo calls → single `sudo stat -c '%F %u %a'` + `sudo test -L`.
- `_run`: `RY_RUN_TIMEOUT` defaults to 3600 when unset; invalid → one-shot `_warn` + fallback.
- `_validate_profile`: 26 required globals + numeric type-check + element sanitization.
- `_install_fstab_opts`: `_check_sudo_keepalive` first; awk strips `strictatime`; 5 write-path `_warn` → `_fail`.
- KERNEL_PARAMS: `amd_iommu=off` → `iommu=pt`.

v3.50.x  2026-04-13
- Profile system: external profiles at `~/.config/ry-install/profiles/<n>.fish`; resolution via `~/.config/ry-install/default-profile` → `gtr9_pro` fallback.
- `_validate_profile`: 26 required globals + numeric type-check + element sanitization.
- `_manifest_check_orphans`: warns on files from previous install/profile.
- `_acquire_lock`: stale-lock reclaim uses `flock -n -E 5` before rmdir+mkdir+PID re-verify.

v3.49.0  2026-04-12
- Dropped 61 low-value comment lines.

v3.48.x  2026-04-08 → 2026-04-09
- TIMESTAMP suffixed with `$fish_pid` (concurrent-children log-file race).
- `SDBOOT_REMOVE_EXISTING=yes` requires `RY_INSTALL_CONFIRM_BOOT_WIPE=1`; marker at `~/ry-install/.boot-wipe-acknowledged`.
- Source-safe exit: `_ry_exit` helper + `_RY_INSTALL_BAILING` + `_RY_INSTALL_SOURCED` + `_RY_INSTALL_LAST_EXIT` (fixes top-level `exit` killing host shell on source).
- `_atomic_write_file`: post-write hash distinguishes sudo lapse from fs error.
- Removed `--lint` mode (~317 L), undocumented `--restore-power-targets`, `_ry_count_managed_cases`, `_get_boot_time`.
- 10 `fish -c` workers wrapped with `timeout --kill-after=5 60`.
- `_run`: `RY_RUN_TIMEOUT` regex hardened (rejects 0, leading-zero, empty); `</dev/null` added.
- `_dir_group_or_world_writable` helper consolidated; BOOT_WIPE_MARKER stores entry count.
- `_install_fstab_opts`: awk `OFS` fix; post-rewrite `findmnt --verify`.

v3.x  pre-2026-04-08
- Profile/manifest/lock infrastructure, multi-mode CLI dispatch, embedded config generators, parallel verify/check workers.
- Full per-version detail elided — see git log for individual commits.
