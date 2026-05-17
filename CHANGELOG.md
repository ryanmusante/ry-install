ry-install ChangeLog
====================

v7.0.19 - 2026-05-17
--------------------

  * `_vrkg_rebar_sam` lspci regex `256M|512M|[0-9]G` → `512M|[0-9]G`: 256 MB is the no-ReBAR AMD GPU BAR cap, not a ReBAR signal — every no-ReBAR system false-positived `large BAR detected`. L2800 comment retuned.
  * `_RY_DMESG_BAR` grep filter `resize|rebar|large|above.4g` → `resize|rebar|large`: `above.4g` ↔ L2787 `*enabled*` status check false-positives on BIOS-level dmesg lines that aren't ReBAR signals.
  * `_vs_read_symmetry_selftest` bare `fish --version` → `command fish --version`: closes remaining gap in v7.0.7/v7.0.16/v7.0.17 bare-cmd sweep. 5127 L unchanged.

v7.0.18 - 2026-05-17
--------------------

  * 14 troubleshooting comments added (one-line `# why` above each site). No behaviour change. 5113 → 5127 L.

v7.0.17 - 2026-05-17
--------------------

  * `_vrkg_rebar_sam`: `lspci` → `command lspci` (v7.0.7/v7.0.16 sweep gap).
  * `_MY_UID` capture hoisted below early-exit flag loop — no fork on `-h`/`-v`.
  * `_dc_sweep_filesystem` gains `functions -q _tmp_dir; or return 0` guard.
  * `_vmh_order_checks` empty-hooks chain rewritten as explicit `if/end`.
  * `_install_aur_packages` `_RY_AUR_PARTIAL` true only when `0 < failed < count`.
  * `_post_service` adds `systemctl try-restart` post-`enable --now`.
  * `_post_nm` adds `systemctl try-restart iwd.service` for `*/iwd/main.conf` targets. 5100 → 5113 L.

v7.0.16 - 2026-05-16
--------------------

  * L200 `KVER`: bare `(uname -r)` → `(command uname -r)`. Closes final gap in v7.0.7 bare-cmd sweep. 5100 L unchanged.

v7.0.15 - 2026-05-16
--------------------

  * Four two-line `#` rationale blocks collapsed to one line each. Shebang + version banner remain documented exception. 5104 → 5100 L.

v7.0.14 - 2026-05-16
--------------------

  * L2 header version sync — `v7.0.12` → `v7.0.14` (v6.5.2 regression class). README badge bumped. 5104 L unchanged.

v7.0.13 - 2026-05-16
--------------------

  * `_enum_boot_entries` gains pipestatus + `_RY_BOOT_ENUM_OK` sentinel — sudo lapse or read error branches `_warn` not false-negative `_err`.
  * `_acquire_lock_fresh` `_RY_LOCK_DIR_OWNED` sentinel hoisted above `chmod 700` — closes sub-ms SIGINT leak window.
  * `_vs_read_symmetry_selftest` result memoized in `_RY_READSYM_RESULT`.
  * Inline doc comments at `_ip_run_and_verify`, `_chk_token_in`, `_RY_POST_HOOKS`. 5079 → 5104 L.

v7.0.12 - 2026-05-16
--------------------

  * Pre-bootstrap `command -q date` check added alongside `timeout(1)`/`stat(1)`. Help text `-V` clarified. 5075 → 5079 L.

v7.0.11 - 2026-05-16
--------------------

  * `_ry_check_deps` required-cmds list adds `date(1)`.
  * `_log_section` description corrected.
  * `_ry_do_check` gains `_log_section "CHECK START"`/`"CHECK END"` at all 8 return paths. 5064 → 5075 L.

v7.0.10 - 2026-05-16
--------------------

  * `_vre_fstab` malformed-line filter hoisted to `_RY_AWK_EXT4_MALFORMED_FILTER`; regex tightened to whitespace/comma-bounded match. 5063 → 5064 L.

v7.0.9 - 2026-05-16
-------------------

  * `_vrkm_blacklist` translates hyphens→underscores before `lsmod` compare.
  * `EXIT_GEN_NOFN/NOUUID/SYSCTL` inline rationale.
  * `_ensure_sudo_cached` description reworded. 5060 → 5063 L.

v7.0.8 - 2026-05-16
-------------------

  * README `<details>` sections use tables for mobile-friendly rendering. Anchor link corrected. Script: version sync only. 5060 L unchanged.

v7.0.7 - 2026-05-16
-------------------

  * 68 bare system-cmd invocations gain `command` prefix across `date`/`dirname`/`basename`/`systemctl`/`id`/`env`/`findmnt`/`systemd-analyze`/`tput`/`getent`/`nmcli`/`modinfo`/`swapon`/`pacman`/`curl`/`ping`/`pgrep`/`bootctl`/`ip`/`zramctl`/`kill`. 5060 L unchanged.

v7.0.6 - 2026-05-16
-------------------

  * `HandleSecureAttentionKey` systemd-version gate `-lt 256` → `-lt 257` (added v257).
  * `_aur_verify_mt7925` hoists `(pacman -Q | awk)` out of double-quoted `_warn`.
  * `_install_rebuild_boot` hoists `_resolve_boot_path` to one fn-entry call.
  * `_is_wifi_active_route` `'br*'` → `'br[0-9]*' 'br-*'`.
  * `_awf_finalize_mv` sudo-lapse returns literal `1`. 5054 → 5060 L.

v7.0.5 - 2026-05-16
-------------------

  * `_RY_POST_HOOKS` gains `*/tmpfiles.d/*|tmpfiles` + `_post_tmpfiles` handler — fixes `--install-file thp.conf` re-deploy gap.
  * `_ensure_sudo_cached` interactive retry redirects stderr to truncate stale readback. 5041 → 5054 L.

v7.0.4 - 2026-05-16
-------------------

  * `_ry_check_wireless_regdom` regex requires 2-letter ISO 3166-1 code.
  * `_post_hook_for_target` uses `string split -r -m1 '|'`.
  * `_unit_state` drops redundant `| string split \n`. 5041 L unchanged.

v7.0 - 2026-05-15
-----------------

  * NM 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
  * MASK +`avahi-daemon.{service,socket}` (10 → 12). New `_csm_disable_ufw_rules` flushes netfilter pre-mask.
  * PKGS_ADD +`realtime-privileges` (13 → 14). PKGS_DEL +`bolt` (7 → 8).
  * New `_ry_check_wireless_regdom` + `_vrk_audio_state` probes.
  * ENV_VARS split: `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue` (Mesa ≥ 26.1.0).
  * `_ok`/`_fail`/`_warn`/`_info`/`_err`/`_fail_silent` gain explicit `; return 0`.
  * `_vsb_mkinitcpio` amdgpu probe `*amdgpu*` → `\bamdgpu\b`.
  * `_ry_check_deps` adds upfront GNU-coreutils `df` probe.
  * 117 inter-fn blank lines collapsed. `_ir_validate_counts` invariants synced. 5092 → 5041 L.

v6.5.18 - 2026-05-15
--------------------

  * `_rvc_dispatch` adds `*/tmpfiles.d/*` case + `_grep_tmpfiles_entry` validator — fixes v6.5.14 regression. 5081 → 5092 L.

v6.5.17 - 2026-05-15
--------------------

  * README tables trimmed to vital rows. Profile-highlight matrix collapsed. No script change.

v6.5.16 - 2026-05-15
--------------------

  * `_msg_print` argv mutation removed.
  * Single-line rationale comments at four dynamic-dispatch sites. 5075 → 5081 L.

v6.5.15 - 2026-05-16
--------------------

  * Single-line rationale comments at three regression-prone sites (`_installed_bytes`, `_vs_read_symmetry_selftest`, `_aur_verify_mt7925`). 5072 → 5075 L.

v6.5.14 - 2026-05-16
--------------------

  * `_installed_bytes` terminal `printf` collapsed to bare printf — fixes false MISMATCH + duplicate writes.
  * New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed dest (12 → 13).
  * `_aur_verify_mt7925` asserts pacman + modinfo resolve. 5005 → 5072 L.

v6.5.13 - 2026-05-15
--------------------

  * Comments trimmed to single-line rationale. 5008 → 5005 L.

v6.5.12 - 2026-05-15
--------------------

  * Log-dir mode probe extended to all three managed paths.
  * `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL`.
  * Unknown-MODE fallback via `_msg_print --force`.

v6.5.11 - 2026-05-15
--------------------

  * `_ry_exit` bail path writes JSONL footer.
  * `_cleanup_pipe` SIGPIPE log gated on `_RY_HEADER_WRITTEN`.

v6.5.10 - 2026-05-15
--------------------

  * `_enum_boot_entries` drops write-only globals.
  * `_verify_unit_syntax` collapsed branch.

v6.5.9 - 2026-05-15
-------------------

  * `_verify_unit_syntax` log joins multi-line stderr.
  * `_vrs_installed_file_perms` emits `perm_vfat_skipped` count.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher pre-header `_warn` calls replaced with direct `echo >&2`.

v6.5.7 - 2026-05-14
-------------------

  * `KERNEL_PARAMS` metachar regex source `\\` → `\\\\`.
  * 93 `string match -qr` patterns swept clean.

v6.5.6 - 2026-05-14
-------------------

  * `_msg` drops `VERIFY_MODE` gate so counters track install + install-file modes.

v6.5.5 - 2026-05-14
-------------------

  * `_chk_grep` stage 2 uses `grep -wF` (was `-q`, SIGPIPE-killed on files > pipe buffer).

v6.5.4 - 2026-05-14
-------------------

  * `_check_phase_units` accepts `static` for NetworkManager-dispatcher.
  * stderr tmpfiles via `_mktemp_or_null`.

v6.5.3 - 2026-05-14
-------------------

  * Bundled short flags (`-hV`, `-hv`) routed through argparse post-block.
  * Non-absolute TMPDIR falls back to `/tmp`.

v6.5.2 - 2026-05-14
-------------------

  * Script header version sync.
  * Bare `sha256sum` → `command sha256sum`.
  * Preflight blocks collapsed to for-loop.

v6.5.1 - 2026-05-14
-------------------

  * `_resolve_esp`/`_resolve_boot_path` hard-fail cached.
  * `_run_emit_stream` adds 1 to `wc -l` on non-newline tail.

v6.5 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` spurious-`TMPFILE_STUCK` fix.
  * `_verify_static_services` multi-ExecStart guard.
  * 14 head/tail sites use `command` prefix.

v6.4 - 2026-05-14
-----------------

  * `_vsb_entries` distinguishes lapsed-sudo from empty entries dir.
  * `_ry_check_deps` adds 10 coreutils.

v6.3 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` logs `TMPFILE_STUCK` before erase.
  * `_err_loud` deduped via `_msg_print --force`.

v6.2.13 - 2026-05-14
--------------------

  * `_run` split into `_run`/`_run_redact_cmd`/`_run_effective_timeout`.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect`.
  * Emit functions use `printf` (flag injection).

v6.2.11 - 2026-05-13
--------------------

  * `_csp_filter_rdeps` pipestatus gate narrowed.
  * JSONL header before `_init_runtime`.
  * `LOCK_DIR` chmod 700.

v6.2.10 - 2026-05-14
--------------------

  * `_ry_check_deps` adds `grep`.
  * pacman `-Qq`/`-T` status capture.
  * dmesg-slice precompute. 5054 → 5008 L.

v6.2.9 - 2026-05-13
-------------------

  * HOME field-6 via `awk -F:` (GECOS-tolerant).
  * `_ry_check_deps` adds `mv`.

v6.2.8 - 2026-05-13
-------------------

  * Log rename + `_acquire_lock` before JSONL header.
  * `_install_preflight` early-returns set `_PROG_FINALIZED_SKIP`.

v6.2.7 - 2026-05-13
-------------------

  * User destinations 0600.
  * `_run` sudo-bypass dash-flag scan.
  * Capture cap 100 → 500 with `_TRUNCATED` sentinels.

v6.2.6 - 2026-05-13
-------------------

  * Top-level array declarations: one element per continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * `_pbs_check_boot_files` snapshots `$pipestatus` before `_pipe_all_ok`.

v6.2.4 - 2026-05-13
-------------------

  * `_run` timeout-bypass for pacman/paru/mkinitcpio/sdboot-manage/paccache.
  * Tmpfile-path redaction under `$TMPDIR`.

v6.2.3 - 2026-05-13
-------------------

  * `_ip_pacman_invoke` `-Syyu` retry gated on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`.
  * Per-pkg AUR retry.
  * `_vrkg_*` GPU runtime checks.

v6.2.2 - 2026-05-13
-------------------

  * `_atomic_write_file` post-write symlink re-check (TOCTOU).
  * `_fstab_atomic_replace` `findmnt --verify` hard-fail.

v6.2.1 - 2026-05-13
-------------------

  * `_ir_validate_counts` array-count invariants.
  * `_RY_POST_HOOKS` first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * `--install-file` single-file redeploy with per-target post-hook dispatch.
  * argparse `--exclusive` mode group.
  * Atomic mkdir + pid-file lock.

v6.1.0 - 2026-05-12
-------------------

  * User-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`, replacing systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 → 4985 L: drop GNU-tool sanity probes, source-mode scaffolding, ntsync per-kernel probes, sudo-keepalive, JSONL progress events, tail-of-script log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gate family, LVM detection.
