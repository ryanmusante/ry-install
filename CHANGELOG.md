ry-install ChangeLog
====================

v7.0 - 2026-05-15
-----------------

  * `_content__etc_NetworkManager_conf.d_99-cachyos-nm.conf` drops `wifi.iwd.autoconnect=false` from `[connection]` — NM 1.56.0 rejects the key as unknown; iwd's `[General] EnableNetworkConfiguration=false` in `/etc/iwd/main.conf` already prevents autoconnect. Matching `_chk_grep` in `_vss_nm` removed. `MASK` adds `avahi-daemon.service` and `avahi-daemon.socket` (10 -> 12) so systemd-resolved is the sole mDNS responder; eliminates the `another mDNS responder running` conflict that arose when `MulticastDNS=resolve` ran alongside an active avahi-daemon. New `_csm_disable_ufw_rules` runs `sudo -n ufw --force disable` before `_configure_services_mask` so kernel netfilter rules are flushed atomically rather than persisting between mask and reboot (gated on `ufw` in `$MASK`, binary present, and `ufw.service` is-active). `PKGS_ADD` adds `realtime-privileges` (13 -> 14); `_rdi_summary` surfaces the `sudo gpasswd -a <user> realtime` instruction (gated on `realtime-privileges` installed AND user not yet a member) — once joined, PipeWire/wireplumber/pipewire-pulse acquire RT scheduling instead of falling back to `nice-level Permission denied`. `PKGS_DEL` adds `bolt` (7 -> 8) — boltd handles Intel TB3 NHI; Strix Halo USB4 IDs `1022:158d/158e` are unrecognised, producing per-boot `udev: failed to determine if uid is stable` warnings. New `_ry_check_wireless_regdom` preflight probe warns when `/etc/conf.d/wireless-regdom` is absent or has no `WIRELESS_REGDOM=` key (non-blocking, INFO+WARN only) — surfaces the silent per-boot `cfg80211: Process '/usr/bin/set-wireless-regdom' failed with exit code 1` failure. New `_vrk_audio_state` adds an INFO row to `--verify-runtime` when dmesg shows `acp_asoc_acp7[0-9].[0-9]+: warning: No matching ASoC machine driver found` — surfaces the Strix Halo ACP70 ASoC machine-driver gap in linux 7.0.8-cachyos; HDMI/USB audio paths unaffected. `_ir_validate_counts` invariants synced: `PKGS_ADD:14`, `PKGS_DEL:8`, `MASK:12`. README troubleshooting table gains two rows (regdom remediation, PipeWire RT group). Major version bump reflects cumulative behaviour changes from the v6.5 series: avahi now masked by default, `bolt` removed by default, ufw rules flushed pre-mask, and the NM conf file shape changed (one fewer key). Header v6.5.18 -> v7.0; 5092 -> 5152 lines.

v6.5.18 - 2026-05-15
--------------------

  * `_rvc_dispatch` `*/tmpfiles.d/*` case added (dispatches to new `_grep_tmpfiles_entry`); previously `/etc/tmpfiles.d/99-cachyos-thp.conf` fell through to the `*` catchall and was checked by `_grep_ini_header`, which raised `no [Section] header found` and aborted preflight with `EXIT_PREFLIGHT` (3) — tmpfiles.d uses systemd-tmpfiles syntax per `man tmpfiles.d`, not INI. `_grep_tmpfiles_entry` asserts ≥1 line matching `^[a-zA-Z][!\-=+~^]*[[:space:]]+\S`. Regression from v6.5.14 when the tmpfiles.d destination was added without a matching dispatcher case. Header v6.5.17 -> v6.5.18; 5081 -> 5092 lines.

v6.5.17 - 2026-05-15
--------------------

  * README tables trimmed to vital rows; profile-highlight matrix collapsed (script remains source of truth). No script behaviour change.

v6.5.16 - 2026-05-15
--------------------

  * `_msg_print` argv mutation removed (`_msg_start` index variable). Single-line rationale comments added at four dynamic-dispatch sites. 5075 -> 5081 lines.

v6.5.15 - 2026-05-16
--------------------

  * Single-line rationale comments at three regression-prone sites: `_installed_bytes` bare printf, `_vs_read_symmetry_selftest` 12-byte payload, `_aur_verify_mt7925` paired probes. 5072 -> 5075 lines.

v6.5.14 - 2026-05-16
--------------------

  * `_installed_bytes` terminal `printf '%s' "$_bytes" | string collect` collapsed to bare printf; output now byte-symmetric with `_ry_content_bytes`. Fixes false MISMATCH on `--verify-static`, false drift on `_check_phase_files`, and duplicate `/etc/mkinitcpio.conf` write. New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed dest (12 -> 13) writes `0` to `transparent_hugepage/shrink_underused`; applied post-deploy via `systemd-tmpfiles --create`. `_aur_verify_mt7925` asserts pacman + modinfo resolve. 5005 -> 5072 lines.

v6.5.13 - 2026-05-15
--------------------

  * Comments trimmed to single-line rationale. 5008 -> 5005 lines.

v6.5.12 - 2026-05-15
--------------------

  * Log-dir mode probe extended to all three managed paths; `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL`; `_acquire_lock` race clears `_RY_LOCK_DIR_OWNED`; unknown-MODE fallback via `_msg_print --force`.

v6.5.11 - 2026-05-15
--------------------

  * `_ry_exit` bail path writes JSONL footer; `_cleanup_pipe` gates SIGPIPE log on `_RY_HEADER_WRITTEN`; missing `--` separators added.

v6.5.10 - 2026-05-15
--------------------

  * `_enum_boot_entries` drops write-only globals; dead locals removed; `_verify_unit_syntax` collapsed branch.

v6.5.9 - 2026-05-15
-------------------

  * `_verify_unit_syntax` log joins multi-line stderr; `_vrs_installed_file_perms` emits `perm_vfat_skipped` count; four `string trim` sites normalised to `--`.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher pre-header `_warn` calls replaced with direct `echo >&2` so JSONL `log` events never precede `header`.

v6.5.7 - 2026-05-14
-------------------

  * `KERNEL_PARAMS` metachar regex source `\\` -> `\\\\`; 93 `string match -qr` patterns swept clean.

v6.5.6 - 2026-05-14
-------------------

  * `_msg` drops `VERIFY_MODE` gate so counters track install + install-file modes; five dead `set -g VERIFY_MODE` writes removed.

v6.5.5 - 2026-05-14
-------------------

  * `_chk_grep` stage 2 runs `grep -wF` (was `-q`, SIGPIPE-killed on files > pipe buffer); stderr tmpfiles renamed for sweep glob coverage.

v6.5.4 - 2026-05-14
-------------------

  * `_check_phase_units` accepts `static` for NetworkManager-dispatcher; stderr tmpfiles via `_mktemp_or_null`; five unreachable `_RY_INSTALL_BAILING` guards removed.

v6.5.3 - 2026-05-14
-------------------

  * Bundled short flags (`-hV`, `-hv`) routed through argparse post-block; `--` added before `grep` and `basename` args; non-absolute TMPDIR falls back to `/tmp`.

v6.5.2 - 2026-05-14
-------------------

  * Script header version sync; bare `sha256sum` -> `command sha256sum`; preflight blocks collapsed to for-loop; `_bootctl_dir` factored.

v6.5.1 - 2026-05-14
-------------------

  * `_resolve_esp`/`_resolve_boot_path` hard-fail cached on `_RY_ESP_TRIED`/`_RY_BOOT_TRIED`; `_run_emit_stream` adds 1 to `wc -l` on non-newline tail; `_vre_zram` derives instance from live swapon.

v6.5 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` spurious-TMPFILE_STUCK fix; `_verify_static_services` multi-ExecStart guard; 14 head/tail sites use `command` prefix.

v6.4 - 2026-05-14
-----------------

  * `_vsb_entries` distinguishes lapsed-sudo from empty entries dir; `_ry_check_deps` adds 10 coreutils; `_progress_init` skipped under `NO_COLOR`; `LC_ALL=C` normalised to `env` prefix.

v6.3 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` logs `TMPFILE_STUCK` before erase; header-write sets log-write-fail sentinel; `_err_loud` deduped via `_msg_print --force`; `_vrsv_chk_nm_dispatcher` accepts `static`.

v6.2.13 - 2026-05-14
--------------------

  * `_run` split into `_run`/`_run_redact_cmd`/`_run_effective_timeout`.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect`; emit functions use `printf` (flag injection); `_write_footer` `extra_key` through `_json_str`; `_progress_init` bails under `$ZELLIJ`.

v6.2.11 - 2026-05-13
--------------------

  * `_csp_filter_rdeps` pipestatus gate narrowed; JSONL header before `_init_runtime`; root-check hoisted after UID parse; `LOCK_DIR` chmod 700; TMPDIR/HOME preflight hardening.

v6.2.10 - 2026-05-14
--------------------

  * `_ry_check_deps` adds `grep`; pacman `-Qq`/`-T` status capture; `_vsb_mkinitcpio` per-token COMPRESSION_OPTIONS match; dmesg-slice precompute. 5054 -> 5008 LOC.

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

  * `_pbs_check_boot_files` snapshots `$pipestatus` before `_pipe_all_ok`; ~52 `_echo` blank-line separators collapsed.

v6.2.4 - 2026-05-13
-------------------

  * `_run` timeout-bypass for pacman/paru/mkinitcpio/sdboot-manage/paccache; tmpfile-path redaction under `$TMPDIR`; `_err_loud` always emits regardless of QUIET.

v6.2.3 - 2026-05-13
-------------------

  * `_ip_pacman_invoke` `-Syyu` retry / `-Sy` gated on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`; `_install_aur_packages` per-pkg retry; .pacnew auto-resolve; `_vrkg_*` GPU runtime checks.

v6.2.2 - 2026-05-13
-------------------

  * `_atomic_write_file` post-write symlink re-check (TOCTOU); `_ry_install_file` skip-probe via `_installed_bytes`; `_fstab_atomic_replace` `findmnt --verify` hard-fail; `_post_boot` force-rebuild taint-gate parity.

v6.2.1 - 2026-05-13
-------------------

  * `_ir_validate_counts` array-count invariants; `_ir_validate_keys` `_tmpfile_key` collision refuse; `_RY_POST_HOOKS` first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * `--install-file` single-file redeploy with per-target post-hook dispatch; argparse `--exclusive` mode group; atomic mkdir + pid-file lock with dead-PID reclaim.

v6.1.0 - 2026-05-12
-------------------

  * User-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`, replacing the systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 -> 4985 LOC: drop GNU-tool sanity probes, source-mode scaffolding, ntsync per-kernel probes, sudo-keepalive, JSONL progress events, tail-of-script log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gate family, LVM detection.
