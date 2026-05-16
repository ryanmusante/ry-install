ry-install ChangeLog
====================

v7.0.7 - 2026-05-16
-------------------

  * Defensive style sweep: 49 bare system-command invocations gain `command` prefix to bypass potential function/abbreviation shadowing — `date` (8 sites: timestamps in `_progress_now`, `_log`, `_write_footer`, top-level JSONL header, `DATE_LABEL`/`TIMESTAMP` globals), `systemctl` (10 sites: `_unit_state` body, `_resolve_systemd_ver`, `_check_phase_units` is-enabled/is-active probes, `_csm_disable_ufw_rules`, `_csp_disable_dispatcher`, `_vre_envvars` `--user show-environment`, `_vre_thp_ksm` is-enabled, `_check_phase_files` cpupower-epp ExecStart extract, `_has_user_bus_active` `--user is-system-running`), `env` (4 sites: preflight df probe in `_ry_check_deps`, `_check_avail` df cmd-sub, `_vrm_modules_loaded` lsmod probe, `_ip_probe_sudo_policy` `sudo -n -l`), `id` (4 sites: `_MY_UID` global, `_vre_fstab` user/group resolution, `_rdi_summary` realtime-group check), `findmnt` (3 sites: `_ir_resolve_root_uuid`, `_vre_fstab` boot fstype, `_irb_sdboot_apply` ESP-fallback /boot probe), `getent` (2 sites: HOME resolution, `_rdi_summary` user lookup), `tput` (3 sites: `_progress_init`, `_progress_on_winch`), `nmcli` (2 sites: `_vre_envvars` wifi radio + state probes), `modinfo` (2 sites: `_ry_validate_mkinitcpio_modules`, `_vre_zram` tcp_bbr version), `swapon` (2 sites: `_vre_zram` zram swap probes), `pacman` (1 site: `_rdi_summary` realtime-privileges check; `command -q pacman` guard precedes), `curl` (1 site: `_ry_check_network`), `ping` (1 site: `_ry_check_network` raw-IP fallback), `pgrep` (1 site: `_vre_envvars` iwd process check), `bootctl` (1 site: `_bootctl_dir` flag dispatch), `ip` (1 site: `_is_wifi_active_route` default-route enumeration), `zramctl` (1 site: `_vre_zram` info table), `kill` (1 site: `_acquire_lock` stale-PID liveness check). No bare invocations of these binaries remain in non-comment, non-string statement-start, post-pipe, post-semicolon, post-`and`/`or`/`not`/`if`/`while`/`else`, or command-substitution `(...)` contexts. Standard UNIX utilities (`head`/`tail`/`cat`/`awk`/`grep`/`sed`/`find`/`chmod`/`chown`/`mv`/`rm`/`cp`/`sort`/`stat`/`sha256sum`) were already uniformly `command`-prefixed; this sweep brings systemd/distro-specific tools and other named system binaries to the same convention. Behavior unchanged: `command X` resolves to the external binary on `$PATH` the same way bare `X` does in non-sourced execution, so no functional difference at runtime; the change closes the corner case where an interactive user sources the script and has previously defined a same-named fish function or abbreviation. Header v7.0.6 -> v7.0.7; line count unchanged (5060).

v7.0.6 - 2026-05-16
-------------------

  * `_content__etc_systemd_logind.conf.d_99-cachyos-logind.conf` + `_vss_logind`: `HandleSecureAttentionKey` emit-gate `-lt 256` -> `-lt 257`. Upstream systemd v250-rc1 NEWS file confirms `HandlePowerKeyLongPress=`/`HandleRebootKeyLongPress=`/`HandleSuspendKeyLongPress=`/`HandleHibernateKeyLongPress=` are v250+ (matches existing dep-check warn floor at L1579), but `HandleSecureAttentionKey=` was added in v257 per `org.freedesktop.login1(5)` ("HandleSecureAttentionKey, SecureAttentionKey(), ... were added in version 257") and the v257 NEWS file ("logind now reacts to Ctrl-Alt-Shift-Esc..."). Previous gate emitted the directive on systemd 256 where it is unknown; logind would log a parse warning. `_aur_verify_mt7925` hoists `(pacman -Q mt76-mt7925-dkms | awk '{print $2}')` out of the double-quoted `_warn` message into `set -l _mt_ver (...)`; the cmdsub still executes (correctly — branch only reached when `pacman -Qi` already confirmed the pkg) but is now visually obvious instead of hidden inside an advisory string. `_install_rebuild_boot` hoists `_resolve_boot_path` to one fn-entry call; both prior call sites (`SDBOOT_REMOVE_EXISTING=yes` gate + post-`_irb_sdboot_apply` verification) read the cached value via `_RY_BOOT_TRIED`/`_RY_BOOT_PATH` so behavior is unchanged. `_is_wifi_active_route` virtual-iface `switch` case: `'br*'` -> `'br[0-9]*' 'br-*'` to exclude vendor-prefix false-positives (e.g. `brcm*`); both standard bridge naming (`br0`/`br1`) and Docker-style (`br-XXXXXX`) still match, `'bridge*'` retained for the long-form. `_awf_finalize_mv` sudo-lapse return `$EXIT_FAIL` -> literal `1` for consistency with sibling chmod/mv failure paths in the same function (no behavior change — both equal 1). `_untrack_tmpfile` + top-level JSONL-header status-capture `cmd1; and X; or Y` chains expanded to explicit `if/else` — removes the load-bearing assumption that `set -g VAR value` never fails (theoretical, but the brittle pattern was confined to two sites). Help text `(no args)         Unattended install (the only mode)` -> `(no args)         Default mode: unattended install` — 5 modes are available (`install`, `install-file`, `verify-static`, `verify-runtime`, `check`); "the only mode" wording contradicted the modes listed in the same help block. README troubleshooting: `/etc/.ry-install.*` orphan recovery cmd `sudo rm /etc/.ry-install.* /boot/.ry-install.* /var/.ry-install.*` -> `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete` — the script never targets `/var` via `mktemp -p`, and shell-glob `/etc/.ry-install.*` does not recurse into subdir mktemp targets like `/etc/systemd/resolved.conf.d/`, `/etc/iwd/`, `/etc/NetworkManager/conf.d/`, `/etc/sysctl.d/`, etc. (atomic-write tmpfiles live next to their final destination). Header v7.0.5 -> v7.0.6; 5054 -> 5060 lines.

v7.0.5 - 2026-05-16
-------------------

  * `_RY_POST_HOOKS` table gains `"*/tmpfiles.d/*|tmpfiles"` (before `*.service` catchall, preserves first-match-wins ordering) + new `_post_tmpfiles` handler — fixes silent gap on `--install-file /etc/tmpfiles.d/99-cachyos-thp.conf` re-deploy where `_post_hook_for_target` previously returned empty and THP runtime values were deferred to next boot (full `install` mode was unaffected — `_install_configure_services` -> `_configure_services_thp_apply` already runs `systemd-tmpfiles --create` post-deploy). Handler is non-blocking: missing `systemd-tmpfiles(8)` warns; `--create` failure warns with retry hint. `_ensure_sudo_cached` interactive retry now redirects stderr (`sudo -v 2>"$_sudo_err"`) — `>` truncates the file, replacing the stale non-interactive "a password is required" stderr so the readback at the failure-reason emit point reports the actual interactive-attempt error (wrong password, ^C abort, etc.) rather than a misleading non-interactive message. Header v7.0.4 -> v7.0.5; 5041 -> 5054 lines.

v7.0.4 - 2026-05-16
-------------------

  * `_ry_check_wireless_regdom` regex tightened to require a non-empty 2-letter ISO 3166-1 code (`'^[[:space:]]*WIRELESS_REGDOM="?[A-Z]{2}"?[[:space:]]*$'`) — `WIRELESS_REGDOM=""` and bare `WIRELESS_REGDOM=` now warn alongside the missing-key case (upstream `/usr/bin/set-wireless-regdom` silently skips `iw reg set` when the value is empty, leaving cfg80211 in the restrictive `world` domain). `_post_hook_for_target` switches `string split '|'` -> `string split -r -m1 '|'` (right-anchored, single split) — pattern column may now contain literal `|` without mistokenisation. `_unit_state` drops the redundant terminal `| string split \n` pipe — `systemctl show --value` emits one property per line, command-substitution already line-splits, and no caller of `_unit_state`/`_unit_state_padded` consumes the function's return code. Header v7.0.3 -> v7.0.4; line count unchanged (5041).

v7.0 - 2026-05-15
-----------------

  * NM 1.56.0 compat: drop `wifi.iwd.autoconnect=false` from `99-cachyos-nm.conf` (key rejected as unknown; iwd's `EnableNetworkConfiguration=false` already prevents autoconnect). MASK adds `avahi-daemon.{service,socket}` (10 -> 12) — systemd-resolved becomes sole mDNS responder. New `_csm_disable_ufw_rules` flushes netfilter pre-mask (`systemctl mask ufw.service` does not flush live iptables/nftables rules; `ufw --force disable` does). PKGS_ADD +`realtime-privileges` (13 -> 14, `_rdi_summary` surfaces `gpasswd -a <user> realtime` hint for PipeWire RT scheduling). PKGS_DEL +`bolt` (7 -> 8, Strix Halo USB4 IDs unrecognised by boltd). New `_ry_check_wireless_regdom` and `_vrk_audio_state` non-blocking probes (regdom config, ACP70 ASoC machine-driver gap). `ENV_VARS`: split deprecated `RADV_PERFTEST=transfer_queue` into `RADV_EXPERIMENTAL=transfer_queue` (Mesa ≥ 26.1.0; older Mesa emits a deprecation warning per docs.mesa3d.org/envvars.html); `RADV_PERFTEST` retained as `sam,nircache`. `_ok`/`_fail`/`_fail_silent`/`_info`/`_warn`/`_err` one-liners gain explicit `; return 0` — rc-0 invariant no longer load-bearing for the `; and X; or Y` if-else idioms. `_vsb_mkinitcpio` amdgpu probe `*amdgpu*` -> `\bamdgpu\b` (word-boundary, consistency with `_chk_token_in`; eliminates `noamdgpu`/`amdgpu2` substring false-positive). `_ry_check_deps` adds upfront `env LC_ALL=C df --output=avail / >/dev/null 2>&1` probe — surfaces non-GNU coreutils (busybox/uutils) at preflight with a clear error rather than mid-run. `_RY_POST_HOOKS` first-match-wins ordering documented inline (`*.service` catchall last). 117 inter-function blank lines collapsed (style harmonised — 122 fn-boundaries already tight pre-edit). `_ir_validate_counts` invariants synced. Header v6.5.18 -> v7.0; 5092 -> 5041 lines.

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
