ry-install ChangeLog
====================

v7.2.1 - 2026-05-17
-------------------

  * `cpupower-epp.service` dropped from managed destinations. `SERVICE_DESTINATIONS` is now empty; `_RY_MANAGED_FILE_COUNT` 13 → 12. EXPECTED_SERVICES 4 → 3 (cpupower-epp.service removed).
  * Removed: `_content__etc_systemd_system_cpupower-epp.service`, `_vrsv_chk_cpupower` (EPP-state helper). `_vrsv_sys_units` 6-unit batch → 5-unit batch.
  * `_verify_static_services`: `── Service files ──` header + loop now gated on `count $SERVICE_DESTINATIONS`; stale `scaling_governor`-in-ExecStart WARN block removed.
  * `_verify_static_syntax`: `── systemd units ──` block gated on `count $SERVICE_DESTINATIONS`.
  * `_install_system_files`: service deploy block (info + log + loop + failure dispatch) gated on `count $SERVICE_DESTINATIONS` — section silenced when no managed unit files.
  * `_post_service` comment: stale `(cpupower-epp)` parenthetical removed. 5185 → 5129 L.

v7.2.0 - 2026-05-17
-------------------

  * `/etc/drirc` dropped from managed destinations (RADV `radv_enable_unified_heap_on_apu` no longer enforced).
  * `/etc/default/cpupower-service.conf` added as managed destination; content: `governor='performance'`.
  * PKGS_ADD +`cpupower` (14 → 15). EXPECTED_SERVICES +`cpupower.service` (3 → 4).
  * `_RY_POST_HOOKS`: `/etc/drirc|drirc` → `/etc/default/cpupower-service.conf|cpupower`. New `_post_cpupower` handler restarts `cpupower.service` on re-deploy.
  * `_vrk_cpu_state`: `scaling_governor` expectation `powersave` → `performance` (cpupower.service routes `governor='performance'` to EPP=performance under amd_pstate=active).
  * `_vrsv_sys_units`: 5-unit batch → 6-unit batch (+`cpupower.service`). New `_vrsv_chk_cpupower_governor` accepts oneshot active|exited + enabled.
  * `_verify_static_system`: drop `_vss_drirc_sysctl`; rename helper to `_vss_sysctl`; add `cpupower-service.conf` content grep.
  * `_rvc_dispatch`: drop `*/drirc` XML case; add `*/default/cpupower-service.conf` to the no-validation set (shell-style key=value, embedded content controlled).
  * Removed: `_content__etc_drirc`, `_grep_xml_tag`, `_post_drirc`. 5181 → 5185 L.

v7.1.2 - 2026-05-17
-------------------

  * `_msg_print` no-color/no-tty branch: `echo "[$level] $msg"` → `printf '[%s] %s\n'` — completes the v6.2.12 emit-fn printf migration (last bare-echo site in the level-message family).
  * `_vs_read_symmetry_selftest`: log token `fish=` resolves from in-process `$FISH_VERSION` instead of `(command fish --version | string match)` — drops one fork on the cold-path. 5181 L unchanged.

v7.1.1 - 2026-05-17
-------------------

  * `_ry_apply_wireless_regdom` write-failure no longer fatal: rc=1 (sudo lapse, tee error) stays a soft `_warn`; only rc=`$EXIT_USAGE` (invalid CC) aborts preflight.
  * `_install_preflight`: capture `$status` from `_ry_apply_wireless_regdom`; set `_PROG_FINALIZED_SKIP=true` before the `EXIT_USAGE` return so the progress bar finalises as `Aborted`.
  * `_ry_apply_wireless_regdom`: tee stderr → tmpfile; first line logged on failure as `REGDOM_SET_FAIL: ... err=<msg>`.
  * `_ry_apply_wireless_regdom`: drop `command sudo -n` → bare `sudo -n` (121-site convention; v7.0.7 sweep deliberately excluded `sudo`).
  * `_ry_apply_wireless_regdom`: `string trim` before `string upper` — `"  us  "` accepted instead of regex-rejected.
  * `_ry_check_wireless_regdom`: WARN hint anchor `Environment variables` → `Runtime variables` (target section name).
  * `_vrkg_vram`: `math` → `math --scale=0` for explicit integer division on `mem_info_vram_total`.
  * `_acquire_lock`: two `command cat "$LOCK_FILE"` sites gain `--` separator.
  * Inline rationale at `_csp_filter_rdeps` cmd-sub append and pre-bootstrap fractional-sleep probe. 5168 → 5181 L.

v7.1.0 - 2026-05-17
-------------------

  * `_ry_apply_wireless_regdom` (new): opt-in `RY_INSTALL_WIRELESS_REGDOM=<CC>` writes `WIRELESS_REGDOM=<CC>` to `/etc/conf.d/wireless-regdom`; validates `^[A-Z]{2}$`, invalid value returns `$EXIT_USAGE`. Wired into `_install_preflight` before `_ry_check_wireless_regdom`.
  * `_csp_filter_rdeps` + `_configure_services_pkg_remove`: per-pkg `WARN` pair demoted to `INFO`; aggregate `WARN` + `PKG_REMOVE_SKIPS:` log token at phase end. `_RY_PKG_REMOVE_SKIPS` added to `_dc_erase_globals`.
  * `_if_nm_restart`: 3-line `WARN` → 1 `WARN` + 1 `INFO`.
  * `_post_nm`: 2-line `WARN` (wifi-active) → 1 `WARN` + 1 `INFO`.
  * `_install_aur_packages`: pre-paru `AUR_NOISE_NOTE:` documents benign `$srcdir/`, `command failed`, and DKMS `BUILD_EXCLUSIVE` tokens.
  * `_ry_check_wireless_regdom`: WARN advertises new `RY_INSTALL_WIRELESS_REGDOM` env var.
  * `_vrkg_vram`: WARN points to `README → Hardware → UMA Frame Buffer Size`.
  * `README.md`: new `Strix Halo ACP audio` Known Issues block; env-var row for `RY_INSTALL_WIRELESS_REGDOM`. 5127 → 5168 L.

v7.0.20 - 2026-05-17
--------------------

  * `_ry_show_help` `-V` description clarified.
  * `_run` `TIMEOUT_TERM`/`TIMEOUT_KILL` log strings: quote-break tidied (cosmetic).
  * `_verify_static_checksum`: `_gen_rc` checked before `_installed_bytes` — skips one `sudo -n cat` per file on generator failure.

v7.0.19 - 2026-05-17
--------------------

  * `_vrkg_rebar_sam` lspci regex `256M|512M|[0-9]G` → `512M|[0-9]G`.
  * `_RY_DMESG_BAR` grep `resize|rebar|large|above.4g` → `resize|rebar|large`.
  * `_vs_read_symmetry_selftest`: bare `fish --version` → `command fish --version`. 5127 L unchanged.

v7.0.18 - 2026-05-17
--------------------

  * 14 one-line `# why` rationale comments. 5113 → 5127 L.

v7.0.17 - 2026-05-17
--------------------

  * `_vrkg_rebar_sam`: `lspci` → `command lspci`.
  * `_MY_UID` hoisted below early-exit flag loop.
  * `_dc_sweep_filesystem`: `functions -q _tmp_dir; or return 0` guard.
  * `_vmh_order_checks`: empty-hooks chain → explicit `if/end`.
  * `_install_aur_packages`: `_RY_AUR_PARTIAL` true only when `0 < failed < count`.
  * `_post_service`: `systemctl try-restart` post-`enable --now`.
  * `_post_nm`: `systemctl try-restart iwd.service` for `*/iwd/main.conf`. 5100 → 5113 L.

v7.0.16 - 2026-05-16
--------------------

  * L200 `KVER`: `(uname -r)` → `(command uname -r)`. 5100 L unchanged.

v7.0.15 - 2026-05-16
--------------------

  * Four two-line `#` rationale blocks → one line each. Shebang + version banner exempted. 5104 → 5100 L.

v7.0.14 - 2026-05-16
--------------------

  * L2 header version sync. README badge bumped. 5104 L unchanged.

v7.0.13 - 2026-05-16
--------------------

  * `_enum_boot_entries`: pipestatus + `_RY_BOOT_ENUM_OK` sentinel — sudo lapse branches `_warn`.
  * `_acquire_lock_fresh`: `_RY_LOCK_DIR_OWNED` hoisted above `chmod 700` — closes sub-ms SIGINT leak.
  * `_vs_read_symmetry_selftest`: result memoised in `_RY_READSYM_RESULT`.
  * Inline doc comments at `_ip_run_and_verify`, `_chk_token_in`, `_RY_POST_HOOKS`. 5079 → 5104 L.

v7.0.12 - 2026-05-16
--------------------

  * Pre-bootstrap `command -q date` check.
  * Help text `-V` clarified. 5075 → 5079 L.

v7.0.11 - 2026-05-16
--------------------

  * `_ry_check_deps`: +`date(1)`.
  * `_log_section`: description corrected.
  * `_ry_do_check`: `_log_section "CHECK START"`/`"CHECK END"` at all 8 return paths. 5064 → 5075 L.

v7.0.10 - 2026-05-16
--------------------

  * `_vre_fstab`: malformed-line filter → `_RY_AWK_EXT4_MALFORMED_FILTER`; regex tightened to whitespace/comma bounds. 5063 → 5064 L.

v7.0.9 - 2026-05-16
-------------------

  * `_vrkm_blacklist`: hyphen → underscore before `lsmod` compare.
  * `EXIT_GEN_NOFN`/`NOUUID`/`SYSCTL`: inline rationale.
  * `_ensure_sudo_cached`: description reworded. 5060 → 5063 L.

v7.0.8 - 2026-05-16
-------------------

  * README `<details>` sections use tables for mobile rendering. Anchor link corrected. 5060 L unchanged.

v7.0.7 - 2026-05-16
-------------------

  * 68 bare system-cmd invocations gain `command` prefix across `date`, `dirname`, `basename`, `systemctl`, `id`, `env`, `findmnt`, `systemd-analyze`, `tput`, `getent`, `nmcli`, `modinfo`, `swapon`, `pacman`, `curl`, `ping`, `pgrep`, `bootctl`, `ip`, `zramctl`, `kill`. 5060 L unchanged.

v7.0.6 - 2026-05-16
-------------------

  * `HandleSecureAttentionKey` systemd-version gate `-lt 256` → `-lt 257`.
  * `_aur_verify_mt7925`: hoist `(pacman -Q | awk)` out of quoted `_warn`.
  * `_install_rebuild_boot`: hoist `_resolve_boot_path` to one fn-entry call.
  * `_is_wifi_active_route` `'br*'` → `'br[0-9]*' 'br-*'`.
  * `_awf_finalize_mv`: sudo-lapse returns literal `1`. 5054 → 5060 L.

v7.0.5 - 2026-05-16
-------------------

  * `_RY_POST_HOOKS`: `*/tmpfiles.d/*|tmpfiles` + `_post_tmpfiles` handler — fixes `--install-file thp.conf` re-deploy gap.
  * `_ensure_sudo_cached`: interactive retry redirects stderr. 5041 → 5054 L.

v7.0.4 - 2026-05-16
-------------------

  * `_ry_check_wireless_regdom`: regex requires 2-letter ISO 3166-1.
  * `_post_hook_for_target`: `string split -r -m1 '|'`.
  * `_unit_state`: drop redundant `| string split \n`. 5041 L unchanged.

v7.0 - 2026-05-15
-----------------

  * NM 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
  * MASK +`avahi-daemon.{service,socket}` (10 → 12). New `_csm_disable_ufw_rules` flushes netfilter pre-mask.
  * PKGS_ADD +`realtime-privileges` (13 → 14). PKGS_DEL +`bolt` (7 → 8).
  * New `_ry_check_wireless_regdom` + `_vrk_audio_state` probes.
  * ENV_VARS: `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue` (Mesa ≥ 26.1.0).
  * `_ok`/`_fail`/`_warn`/`_info`/`_err`/`_fail_silent`: explicit `; return 0`.
  * `_vsb_mkinitcpio`: amdgpu probe `*amdgpu*` → `\bamdgpu\b`.
  * `_ry_check_deps`: upfront GNU-coreutils `df` probe.
  * 117 inter-fn blank lines collapsed. `_ir_validate_counts` invariants synced. 5092 → 5041 L.

v6.5.18 - 2026-05-15
--------------------

  * `_rvc_dispatch`: `*/tmpfiles.d/*` case + `_grep_tmpfiles_entry` validator — fixes v6.5.14 regression. 5081 → 5092 L.

v6.5.17 - 2026-05-15
--------------------

  * README tables trimmed. Profile-highlight matrix collapsed.

v6.5.16 - 2026-05-15
--------------------

  * `_msg_print`: argv mutation removed.
  * Single-line rationale at four dynamic-dispatch sites. 5075 → 5081 L.

v6.5.15 - 2026-05-16
--------------------

  * Single-line rationale at three regression-prone sites (`_installed_bytes`, `_vs_read_symmetry_selftest`, `_aur_verify_mt7925`). 5072 → 5075 L.

v6.5.14 - 2026-05-16
--------------------

  * `_installed_bytes`: terminal `printf` collapsed — fixes false MISMATCH + duplicate writes.
  * New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed dest (12 → 13).
  * `_aur_verify_mt7925`: assert pacman + modinfo resolve. 5005 → 5072 L.

v6.5.13 - 2026-05-15
--------------------

  * Comments trimmed to single-line rationale. 5008 → 5005 L.

v6.5.12 - 2026-05-15
--------------------

  * Log-dir mode probe extended to all three managed paths.
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
  * `_vrs_installed_file_perms`: emits `perm_vfat_skipped` count.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher pre-header `_warn` replaced with direct `echo >&2`.

v6.5.7 - 2026-05-14
-------------------

  * `KERNEL_PARAMS` metachar regex source `\\` → `\\\\`.
  * 93 `string match -qr` patterns swept clean.

v6.5.6 - 2026-05-14
-------------------

  * `_msg`: drop `VERIFY_MODE` gate so counters track install + install-file modes.

v6.5.5 - 2026-05-14
-------------------

  * `_chk_grep` stage 2: `grep -wF` (was `-q`, SIGPIPE-killed on files > pipe buffer).

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

  * `_dc_sweep_tmpfiles`: spurious-`TMPFILE_STUCK` fix.
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

  * `_run` split into `_run`/`_run_redact_cmd`/`_run_effective_timeout`.

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

  * User-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`, replacing systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 → 4985 L: drop GNU-tool sanity probes, source-mode scaffolding, ntsync per-kernel probes, sudo-keepalive, JSONL progress events, tail-of-script log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gate family, LVM detection.
