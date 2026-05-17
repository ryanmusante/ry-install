ry-install ChangeLog
====================

v7.3.1 - 2026-05-17
-------------------

  * README Configuration: add `Phase 1 — Preflight`, `Phase 5 — Boot`, `Phase 6 — Finalize` prose subsections (action-only phases, no embedded data). Intro reworded to note phases 1/5/6 carry no `set -g` payload.
  * README: Phase 3 cross-ref `[Phase 5 (Boot)](#install-flow)` → `[Phase 5 — Boot](#phase-5--boot)`.
  * VERSION 7.3.0 → 7.3.1. 5133 L unchanged.

v7.3.0 - 2026-05-17
-------------------

  * Inline 6 standalone rationale comments to their target lines. 5139 → 5133 L.
  * VERSION 7.2.6 → 7.3.0.

v7.2.6 - 2026-05-17
-------------------

  * README: Configuration section split into Phase 2 / Phase 3 / Phase 4 H3 subsections matching install-flow order.
  * README: Vulkan deps block — vulkan-radeon / lib32-vulkan-radeon installed by chwd on AMD profiles.
  * VERSION 7.2.5 → 7.2.6. 5139 L unchanged.

v7.2.5 - 2026-05-17
-------------------

  * `_ry_show_help` EXIT CODES: rc=1 description adds old-kernel warn path.
  * `_dc_kill_children` description: parent-PID reap (pkill -P), not process-group.
  * README Install Flow phase 2: add updatedb + pkgfile --update cache refresh.
  * README Initramfs: 9 ordering invariants → 11 hook invariants.
  * README Vulkan deps: chwd documented as transitive source of vulkan-radeon / lib32-vulkan-radeon. 5139 L unchanged.

v7.2.4 - 2026-05-17
-------------------

  * `_vre_fstab`: noatime/lazytime/commit=10 unified to `(^|,)tok(,|$)`. Fixes `lazytime` substr false-match on `nolazytime`. 14 → 9 L.
  * `_ir_validate_counts`: +`_RY_POST_HOOKS:14` +`_RY_BOOT_CRITICAL_DSTS:4` (13 → 15 invariants).
  * `_mr_copy_size_verify`: +`cmp -s` byte-content verify after size match.
  * `_dc_erase_globals`: +`_RY_BOOT_TAINTED` for symmetry.
  * `_dc_kill_children` description: matches `pkill -TERM -P` + `pkill -KILL -P` body.
  * `_verify_static_syntax`: explicit `system` scope arg.
  * `_ip_snapshot_mkinitcpio`: drop redundant `chmod 600`.
  * README Bootloader: 8 keys → 10 keys (4 loader.conf + 6 sdboot-manage.conf).
  * README Initramfs: 4 → 9 ordering invariants enumerated.
  * README Install Flow phase 4: +fstab ext4 opts +`PKGS_DEL` removal. 5138 → 5139 L.

v7.2.3 - 2026-05-17
-------------------

  * `_vmh_order_checks`: +2 pair rules (`systemd:autodetect`, `autodetect:microcode`) + `fsck`-last check.
  * `_msg_print` color branch: bare echo → printf.
  * `_vrs_boot_perf`: adjacent-quote concat cleanup. 5129 → 5138 L.

v7.2.2 - 2026-05-17
-------------------

  * README Configuration: 2 collapsibles → 19 per-domain collapsibles.
  * README: 13 → 12 embedded configs (tagline + Install Flow phase 3).
  * README Quick Start: 3 admonitions → 1 inline + 1 IMPORTANT. Hardware BIOS-prereq → `<details>`.
  * README: news-check + `--` orphan paragraphs folded into tables. Uninstall → 6-step list. 5129 L unchanged.

v7.2.1 - 2026-05-17
-------------------

  * `cpupower-epp.service` dropped. `SERVICE_DESTINATIONS` empty. `_RY_MANAGED_FILE_COUNT` 13 → 12. `EXPECTED_SERVICES` 4 → 3.
  * Removed: `_content__etc_systemd_system_cpupower-epp.service`, `_vrsv_chk_cpupower`. `_vrsv_sys_units` 6 → 5.
  * `_verify_static_services`, `_verify_static_syntax`, `_install_system_files`: service blocks gated on `count $SERVICE_DESTINATIONS`. 5185 → 5129 L.

v7.2.0 - 2026-05-17
-------------------

  * `/etc/drirc` dropped from managed destinations.
  * `/etc/default/cpupower-service.conf` added — `governor='performance'`.
  * `PKGS_ADD` +`cpupower` (14 → 15). `EXPECTED_SERVICES` +`cpupower.service` (3 → 4).
  * `_RY_POST_HOOKS`: drirc → cpupower-service. New `_post_cpupower` handler.
  * `_vrk_cpu_state`: scaling_governor expectation powersave → performance.
  * `_vrsv_sys_units`: 5 → 6 batch (+cpupower.service). New `_vrsv_chk_cpupower_governor`.
  * `_verify_static_system`: drop `_vss_drirc_sysctl`; add cpupower-service.conf grep.
  * `_rvc_dispatch`: drop drirc XML; add cpupower-service.conf no-validation case.
  * Removed: `_content__etc_drirc`, `_grep_xml_tag`, `_post_drirc`. 5181 → 5185 L.

v7.1.2 - 2026-05-17
-------------------

  * `_msg_print` no-color/no-tty: echo → printf.
  * `_vs_read_symmetry_selftest`: `fish=` from `$FISH_VERSION` (drops one fork). 5181 L unchanged.

v7.1.1 - 2026-05-17
-------------------

  * `_ry_apply_wireless_regdom`: rc=1 → soft `_warn`; only `EXIT_USAGE` aborts preflight.
  * `_install_preflight`: capture `_ry_apply_wireless_regdom` status; `_PROG_FINALIZED_SKIP=true` before USAGE return.
  * `_ry_apply_wireless_regdom`: tee stderr → tmpfile; first line logged as `REGDOM_SET_FAIL`.
  * `_ry_apply_wireless_regdom`: bare `sudo -n`; `string trim` before `string upper`.
  * `_ry_check_wireless_regdom`: hint anchor `Environment variables` → `Runtime variables`.
  * `_vrkg_vram`: `math` → `math --scale=0`.
  * `_acquire_lock`: two `command cat` sites gain `--` separator. 5168 → 5181 L.

v7.1.0 - 2026-05-17
-------------------

  * `_ry_apply_wireless_regdom` (new): `RY_INSTALL_WIRELESS_REGDOM=<CC>` writes `WIRELESS_REGDOM=<CC>` to `/etc/conf.d/wireless-regdom`. Validates `^[A-Z]{2}$`.
  * `_csp_filter_rdeps` + `_configure_services_pkg_remove`: per-pkg WARN demoted to INFO; aggregate WARN + `PKG_REMOVE_SKIPS` at phase end.
  * `_if_nm_restart`: 3 WARN → 1 WARN + 1 INFO.
  * `_post_nm`: 2 WARN → 1 WARN + 1 INFO.
  * `_install_aur_packages`: `AUR_NOISE_NOTE` documents benign tokens.
  * `_vrkg_vram`: WARN points to README → Hardware → UMA.
  * README: new Strix Halo ACP audio Known Issues; env-var row for `RY_INSTALL_WIRELESS_REGDOM`. 5127 → 5168 L.

v7.0.20 - 2026-05-17
--------------------

  * `_ry_show_help` `-V` description clarified.
  * `_run` `TIMEOUT_TERM`/`TIMEOUT_KILL` log strings tidied.
  * `_verify_static_checksum`: `_gen_rc` before `_installed_bytes`.

v7.0.19 - 2026-05-17
--------------------

  * `_vrkg_rebar_sam`: lspci regex 256M removed.
  * `_RY_DMESG_BAR`: drop `above.4g` from grep.
  * `_vs_read_symmetry_selftest`: bare `fish` → `command fish`. 5127 L unchanged.

v7.0.18 - 2026-05-17
--------------------

  * 14 one-line `# why` rationale comments. 5113 → 5127 L.

v7.0.17 - 2026-05-17
--------------------

  * `_vrkg_rebar_sam`: `lspci` → `command lspci`.
  * `_MY_UID` hoist below early-exit loop.
  * `_dc_sweep_filesystem`: `functions -q _tmp_dir; or return 0` guard.
  * `_vmh_order_checks`: empty-hooks chain → explicit `if/end`.
  * `_install_aur_packages`: `_RY_AUR_PARTIAL` only when `0 < failed < count`.
  * `_post_service`: `systemctl try-restart` post-`enable --now`.
  * `_post_nm`: `try-restart iwd.service` for iwd main.conf. 5100 → 5113 L.

v7.0.16 - 2026-05-16
--------------------

  * L200 `KVER`: `(uname -r)` → `(command uname -r)`. 5100 L unchanged.

v7.0.15 - 2026-05-16
--------------------

  * 4 two-line `#` rationale blocks → one line each. 5104 → 5100 L.

v7.0.14 - 2026-05-16
--------------------

  * L2 header version sync. README badge bump. 5104 L unchanged.

v7.0.13 - 2026-05-16
--------------------

  * `_enum_boot_entries`: pipestatus + `_RY_BOOT_ENUM_OK` sentinel.
  * `_acquire_lock_fresh`: `_RY_LOCK_DIR_OWNED` hoist above `chmod 700`.
  * `_vs_read_symmetry_selftest`: result memoised in `_RY_READSYM_RESULT`. 5079 → 5104 L.

v7.0.12 - 2026-05-16
--------------------

  * Pre-bootstrap `command -q date` check.
  * Help text `-V` clarified. 5075 → 5079 L.

v7.0.11 - 2026-05-16
--------------------

  * `_ry_check_deps`: +`date(1)`.
  * `_log_section`: description corrected.
  * `_ry_do_check`: `_log_section` at all 8 return paths. 5064 → 5075 L.

v7.0.10 - 2026-05-16
--------------------

  * `_vre_fstab`: malformed-line filter → `_RY_AWK_EXT4_MALFORMED_FILTER`. 5063 → 5064 L.

v7.0.9 - 2026-05-16
-------------------

  * `_vrkm_blacklist`: hyphen → underscore before `lsmod` compare.
  * `EXIT_GEN_NOFN`/`NOUUID`/`SYSCTL`: inline rationale.
  * `_ensure_sudo_cached`: description reworded. 5060 → 5063 L.

v7.0.8 - 2026-05-16
-------------------

  * README `<details>` use tables for mobile rendering. 5060 L unchanged.

v7.0.7 - 2026-05-16
-------------------

  * 68 bare system-cmd invocations gain `command` prefix. 5060 L unchanged.

v7.0.6 - 2026-05-16
-------------------

  * `HandleSecureAttentionKey` systemd-version gate `-lt 256` → `-lt 257`.
  * `_aur_verify_mt7925`: hoist `pacman -Q | awk` out of `_warn`.
  * `_install_rebuild_boot`: hoist `_resolve_boot_path` to one call.
  * `_is_wifi_active_route`: `'br*'` → `'br[0-9]*' 'br-*'`.
  * `_awf_finalize_mv`: sudo-lapse returns literal `1`. 5054 → 5060 L.

v7.0.5 - 2026-05-16
-------------------

  * `_RY_POST_HOOKS`: +`*/tmpfiles.d/*|tmpfiles` + `_post_tmpfiles`.
  * `_ensure_sudo_cached`: retry stderr redirect. 5041 → 5054 L.

v7.0.4 - 2026-05-16
-------------------

  * `_ry_check_wireless_regdom`: regex requires 2-letter ISO 3166-1.
  * `_post_hook_for_target`: `string split -r -m1 '|'`.
  * `_unit_state`: drop redundant `string split \n`. 5041 L unchanged.

v7.0 - 2026-05-15
-----------------

  * NM 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
  * `MASK` +`avahi-daemon.{service,socket}` (10 → 12). New `_csm_disable_ufw_rules`.
  * `PKGS_ADD` +`realtime-privileges` (13 → 14). `PKGS_DEL` +`bolt` (7 → 8).
  * New `_ry_check_wireless_regdom` + `_vrk_audio_state`.
  * `ENV_VARS`: `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`.
  * `_ok`/`_fail`/`_warn`/`_info`/`_err`/`_fail_silent`: explicit `; return 0`.
  * `_vsb_mkinitcpio`: amdgpu probe `*amdgpu*` → `\bamdgpu\b`.
  * `_ry_check_deps`: GNU-coreutils `df` probe.
  * 117 inter-fn blank lines collapsed. `_ir_validate_counts` invariants synced. 5092 → 5041 L.

v6.5.18 - 2026-05-15
--------------------

  * `_rvc_dispatch`: `*/tmpfiles.d/*` case + `_grep_tmpfiles_entry`. 5081 → 5092 L.

v6.5.17 - 2026-05-15
--------------------

  * README tables trimmed. Profile-highlight matrix collapsed.

v6.5.16 - 2026-05-15
--------------------

  * `_msg_print`: argv mutation removed.
  * Single-line rationale at 4 dynamic-dispatch sites. 5075 → 5081 L.

v6.5.15 - 2026-05-16
--------------------

  * Single-line rationale at 3 regression-prone sites. 5072 → 5075 L.

v6.5.14 - 2026-05-16
--------------------

  * `_installed_bytes`: terminal `printf` collapsed.
  * New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed dest (12 → 13).
  * `_aur_verify_mt7925`: assert pacman + modinfo resolve. 5005 → 5072 L.

v6.5.13 - 2026-05-15
--------------------

  * Comments trimmed to single-line rationale. 5008 → 5005 L.

v6.5.12 - 2026-05-15
--------------------

  * Log-dir mode probe extended to 3 managed paths.
  * `_awf_finalize_mv`: sudo-lapse returns `$EXIT_FAIL`.
  * Unknown-MODE fallback via `_msg_print --force`.

v6.5.11 - 2026-05-15
--------------------

  * `_ry_exit` bail path writes JSONL footer.
  * `_cleanup_pipe`: SIGPIPE log gated on `_RY_HEADER_WRITTEN`.

v6.5.10 - 2026-05-15
--------------------

  * `_enum_boot_entries`: drop write-only globals.
  * `_verify_unit_syntax`: collapsed branch.

v6.5.9 - 2026-05-15
-------------------

  * `_verify_unit_syntax`: log joins multi-line stderr.
  * `_vrs_installed_file_perms`: emit `perm_vfat_skipped` count.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher pre-header `_warn` → direct `echo >&2`.

v6.5.7 - 2026-05-14
-------------------

  * `KERNEL_PARAMS` metachar regex source `\\` → `\\\\`.
  * 93 `string match -qr` patterns sweep.

v6.5.6 - 2026-05-14
-------------------

  * `_msg`: drop `VERIFY_MODE` gate.

v6.5.5 - 2026-05-14
-------------------

  * `_chk_grep` stage 2: `grep -wF`.

v6.5.4 - 2026-05-14
-------------------

  * `_check_phase_units`: accept `static` for NetworkManager-dispatcher.
  * stderr tmpfiles via `_mktemp_or_null`.

v6.5.3 - 2026-05-14
-------------------

  * Bundled short flags (`-hV`, `-hv`) routed through argparse post-block.
  * Non-absolute `TMPDIR` falls back to `/tmp`.

v6.5.2 - 2026-05-14
-------------------

  * Script header version sync.
  * Bare `sha256sum` → `command sha256sum`.
  * Preflight blocks collapsed to for-loop.

v6.5.1 - 2026-05-14
-------------------

  * `_resolve_esp`/`_resolve_boot_path`: hard-fail cached.
  * `_run_emit_stream`: adds 1 to `wc -l` on non-newline tail.

v6.5 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles`: spurious `TMPFILE_STUCK` fix.
  * `_verify_static_services`: multi-ExecStart guard.
  * 14 head/tail sites use `command` prefix.

v6.4 - 2026-05-14
-----------------

  * `_vsb_entries`: distinguish lapsed-sudo from empty entries dir.
  * `_ry_check_deps`: +10 coreutils.

v6.3 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles`: log `TMPFILE_STUCK` before erase.
  * `_err_loud`: deduped via `_msg_print --force`.

v6.2.13 - 2026-05-14
--------------------

  * `_run` split into `_run` / `_run_redact_cmd` / `_run_effective_timeout`.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect`.
  * Emit functions use `printf` (flag injection).

v6.2.11 - 2026-05-13
--------------------

  * `_csp_filter_rdeps`: pipestatus gate narrowed.
  * JSONL header before `_init_runtime`.
  * `LOCK_DIR`: `chmod 700`.

v6.2.10 - 2026-05-14
--------------------

  * `_ry_check_deps`: +`grep`.
  * pacman `-Qq`/`-T` status capture.
  * dmesg-slice precompute. 5054 → 5008 L.

v6.2.9 - 2026-05-13
-------------------

  * HOME field-6 via `awk -F:` (GECOS-tolerant).
  * `_ry_check_deps`: +`mv`.

v6.2.8 - 2026-05-13
-------------------

  * Log rename + `_acquire_lock` before JSONL header.
  * `_install_preflight`: early-returns set `_PROG_FINALIZED_SKIP`.

v6.2.7 - 2026-05-13
-------------------

  * User destinations 0600.
  * `_run`: sudo-bypass dash-flag scan.
  * Capture cap 100 → 500 with `_TRUNCATED` sentinels.

v6.2.6 - 2026-05-13
-------------------

  * Top-level array decls: one element per continuation line.

v6.2.5 - 2026-05-13
-------------------

  * `_pbs_check_boot_files`: snapshot `$pipestatus` before `_pipe_all_ok`.

v6.2.4 - 2026-05-13
-------------------

  * `_run`: timeout-bypass for pacman/paru/mkinitcpio/sdboot-manage/paccache.
  * Tmpfile-path redaction under `$TMPDIR`.

v6.2.3 - 2026-05-13
-------------------

  * `_ip_pacman_invoke`: `-Syyu` retry gated on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`.
  * Per-pkg AUR retry.
  * `_vrkg_*`: GPU runtime checks.

v6.2.2 - 2026-05-13
-------------------

  * `_atomic_write_file`: post-write symlink re-check (TOCTOU).
  * `_fstab_atomic_replace`: `findmnt --verify` hard-fail.

v6.2.1 - 2026-05-13
-------------------

  * `_ir_validate_counts`: array-count invariants.
  * `_RY_POST_HOOKS`: first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * `--install-file`: single-file redeploy with per-target post-hook dispatch.
  * argparse `--exclusive` mode group.
  * Atomic mkdir + pid-file lock.

v6.1.0 - 2026-05-12
-------------------

  * User-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 → 4985 L: drop GNU-tool probes, source-mode scaffolding, ntsync probes, sudo-keepalive, JSONL progress events, log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gates, LVM detection.
