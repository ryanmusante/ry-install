ry-install ChangeLog
====================

v7.0.7 - 2026-05-16
-------------------

  * 68 bare system-cmd invocations gain `command` prefix (`date`, `dirname`, `basename`, `systemctl`, `id`, `env`, `findmnt`, `systemd-analyze`, `tput`, `getent`, `nmcli`, `modinfo`, `swapon`, `pacman`, `curl`, `ping`, `pgrep`, `bootctl`, `ip`, `zramctl`, `kill`); `printf` (fish builtin) and `sudo` intentionally bare. Line count unchanged (5060).

v7.0.6 - 2026-05-16
-------------------

  * `HandleSecureAttentionKey` emit-gate `-lt 256` -> `-lt 257` (added v257 per upstream `org.freedesktop.login1(5)`); `_aur_verify_mt7925` hoists `(pacman -Q | awk)` out of double-quoted `_warn`; `_install_rebuild_boot` hoists `_resolve_boot_path` to one fn-entry call (cache-equivalent); `_is_wifi_active_route` `'br*'` -> `'br[0-9]*' 'br-*'`; `_awf_finalize_mv` sudo-lapse returns literal `1`; `_untrack_tmpfile` + top-level header capture switch to explicit `if/else`; help-text "(the only mode)" -> "Default mode: unattended install"; README orphan-recovery cmd `find /etc /boot/loader -xdev -name '.ry-install.*' -delete`. 5054 -> 5060 lines.

v7.0.5 - 2026-05-16
-------------------

  * `_RY_POST_HOOKS` gains `*/tmpfiles.d/*|tmpfiles` + `_post_tmpfiles` handler (fixes silent `--install-file thp.conf` re-deploy gap); `_ensure_sudo_cached` interactive retry redirects stderr to truncate stale non-interactive readback. 5041 -> 5054 lines.

v7.0.4 - 2026-05-16
-------------------

  * `_ry_check_wireless_regdom` regex requires 2-letter ISO 3166-1 code; `_post_hook_for_target` uses `string split -r -m1 '|'`; `_unit_state` drops redundant `| string split \n`. Line count unchanged (5041).

v7.0 - 2026-05-15
-----------------

  * NM 1.56.0 compat: drop `wifi.iwd.autoconnect=false`; MASK +`avahi-daemon.{service,socket}` (10 -> 12); new `_csm_disable_ufw_rules` flushes netfilter pre-mask; PKGS_ADD +`realtime-privileges` (13 -> 14); PKGS_DEL +`bolt` (7 -> 8); new `_ry_check_wireless_regdom` + `_vrk_audio_state` probes; ENV_VARS splits `RADV_PERFTEST=transfer_queue` into `RADV_EXPERIMENTAL=transfer_queue` (Mesa >= 26.1.0); `_ok`/`_fail`/`_warn`/`_info`/`_err`/`_fail_silent` gain explicit `; return 0`; `_vsb_mkinitcpio` amdgpu probe `*amdgpu*` -> `\bamdgpu\b`; `_ry_check_deps` adds upfront GNU-coreutils df probe; 117 inter-fn blank lines collapsed; `_ir_validate_counts` invariants synced. 5092 -> 5041 lines.

v6.5.18 - 2026-05-15
--------------------

  * `_rvc_dispatch` adds `*/tmpfiles.d/*` case + new `_grep_tmpfiles_entry` validator — fixes v6.5.14 regression where `/etc/tmpfiles.d/99-cachyos-thp.conf` fell through to `_grep_ini_header` and aborted preflight. 5081 -> 5092 lines.

v6.5.17 - 2026-05-15
--------------------

  * README tables trimmed to vital rows; profile-highlight matrix collapsed (script remains source of truth). No script behaviour change.

v6.5.16 - 2026-05-15
--------------------

  * `_msg_print` argv mutation removed; single-line rationale comments added at four dynamic-dispatch sites. 5075 -> 5081 lines.

v6.5.15 - 2026-05-16
--------------------

  * Single-line rationale comments at three regression-prone sites (`_installed_bytes`, `_vs_read_symmetry_selftest`, `_aur_verify_mt7925`). 5072 -> 5075 lines.

v6.5.14 - 2026-05-16
--------------------

  * `_installed_bytes` terminal `printf` collapsed to bare printf (byte-symmetric with `_ry_content_bytes`; fixes false MISMATCH and duplicate writes); new `/etc/tmpfiles.d/99-cachyos-thp.conf` managed dest (12 -> 13); `_aur_verify_mt7925` asserts pacman + modinfo resolve. 5005 -> 5072 lines.

v6.5.13 - 2026-05-15
--------------------

  * Comments trimmed to single-line rationale. 5008 -> 5005 lines.

v6.5.12 - 2026-05-15
--------------------

  * Log-dir mode probe extended to all three managed paths; `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL`; unknown-MODE fallback via `_msg_print --force`.

v6.5.11 - 2026-05-15
--------------------

  * `_ry_exit` bail path writes JSONL footer; `_cleanup_pipe` SIGPIPE log gated on `_RY_HEADER_WRITTEN`.

v6.5.10 - 2026-05-15
--------------------

  * `_enum_boot_entries` drops write-only globals; `_verify_unit_syntax` collapsed branch.

v6.5.9 - 2026-05-15
-------------------

  * `_verify_unit_syntax` log joins multi-line stderr; `_vrs_installed_file_perms` emits `perm_vfat_skipped` count.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher pre-header `_warn` calls replaced with direct `echo >&2` — JSONL `log` events never precede `header`.

v6.5.7 - 2026-05-14
-------------------

  * `KERNEL_PARAMS` metachar regex source `\\` -> `\\\\`; 93 `string match -qr` patterns swept clean.

v6.5.6 - 2026-05-14
-------------------

  * `_msg` drops `VERIFY_MODE` gate so counters track install + install-file modes.

v6.5.5 - 2026-05-14
-------------------

  * `_chk_grep` stage 2 uses `grep -wF` (was `-q`, SIGPIPE-killed on files > pipe buffer).

v6.5.4 - 2026-05-14
-------------------

  * `_check_phase_units` accepts `static` for NetworkManager-dispatcher; stderr tmpfiles via `_mktemp_or_null`.

v6.5.3 - 2026-05-14
-------------------

  * Bundled short flags (`-hV`, `-hv`) routed through argparse post-block; non-absolute TMPDIR falls back to `/tmp`.

v6.5.2 - 2026-05-14
-------------------

  * Script header version sync; bare `sha256sum` -> `command sha256sum`; preflight blocks collapsed to for-loop.

v6.5.1 - 2026-05-14
-------------------

  * `_resolve_esp`/`_resolve_boot_path` hard-fail cached; `_run_emit_stream` adds 1 to `wc -l` on non-newline tail.

v6.5 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` spurious-TMPFILE_STUCK fix; `_verify_static_services` multi-ExecStart guard; 14 head/tail sites use `command` prefix.

v6.4 - 2026-05-14
-----------------

  * `_vsb_entries` distinguishes lapsed-sudo from empty entries dir; `_ry_check_deps` adds 10 coreutils.

v6.3 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` logs `TMPFILE_STUCK` before erase; `_err_loud` deduped via `_msg_print --force`.

v6.2.13 - 2026-05-14
--------------------

  * `_run` split into `_run`/`_run_redact_cmd`/`_run_effective_timeout`.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect`; emit functions use `printf` (flag injection).

v6.2.11 - 2026-05-13
--------------------

  * `_csp_filter_rdeps` pipestatus gate narrowed; JSONL header before `_init_runtime`; `LOCK_DIR` chmod 700.

v6.2.10 - 2026-05-14
--------------------

  * `_ry_check_deps` adds `grep`; pacman `-Qq`/`-T` status capture; dmesg-slice precompute. 5054 -> 5008 LOC.

v6.2.9 - 2026-05-13
-------------------

  * HOME field-6 via `awk -F:` (GECOS-tolerant); `_ry_check_deps` adds `mv`.

v6.2.8 - 2026-05-13
-------------------

  * Log rename + `_acquire_lock` before JSONL header; `_install_preflight` early-returns set `_PROG_FINALIZED_SKIP`.

v6.2.7 - 2026-05-13
-------------------

  * User destinations 0600; `_run` sudo-bypass dash-flag scan; capture cap 100 -> 500 with `_TRUNCATED` sentinels.

v6.2.6 - 2026-05-13
-------------------

  * Top-level array declarations: one element per continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * `_pbs_check_boot_files` snapshots `$pipestatus` before `_pipe_all_ok`.

v6.2.4 - 2026-05-13
-------------------

  * `_run` timeout-bypass for pacman/paru/mkinitcpio/sdboot-manage/paccache; tmpfile-path redaction under `$TMPDIR`.

v6.2.3 - 2026-05-13
-------------------

  * `_ip_pacman_invoke` `-Syyu` retry gated on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`; per-pkg AUR retry; `_vrkg_*` GPU runtime checks.

v6.2.2 - 2026-05-13
-------------------

  * `_atomic_write_file` post-write symlink re-check (TOCTOU); `_fstab_atomic_replace` `findmnt --verify` hard-fail.

v6.2.1 - 2026-05-13
-------------------

  * `_ir_validate_counts` array-count invariants; `_RY_POST_HOOKS` first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * `--install-file` single-file redeploy with per-target post-hook dispatch; argparse `--exclusive` mode group; atomic mkdir + pid-file lock.

v6.1.0 - 2026-05-12
-------------------

  * User-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`, replacing the systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 -> 4985 LOC: drop GNU-tool sanity probes, source-mode scaffolding, ntsync per-kernel probes, sudo-keepalive, JSONL progress events, tail-of-script log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gate family, LVM detection.
