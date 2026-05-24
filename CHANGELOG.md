ry-install ChangeLog

v7.6.7 - v7.6.8 - 2026-05-24

- README WARNING block compressed: sudo-cache mitigations folded into single paragraph (`timestamp_timeout` extension, keepalive loop, scoped `NOPASSWD` drop-in) plus TTY/cron note and idempotent-rerun recovery; per-binary `NOPASSWD` enumeration trimmed to `pacman, paru, sdboot-manage, mkinitcpio, bootctl, systemctl, ufw, paccache` + invoked coreutils (`install mv cp rm chmod chown cat tee find stat grep awk cmp mktemp`) — full `/usr/bin/` path enumeration dropped; Install Flow phase descriptions condensed to one-line operator summaries; Phase 1 row labels shortened; Packages-install table regrouped by category (5 rows vs 15: sysadmin / gaming / Vulkan-GL / rust utilities / perf); Packages-remove regrouped by category (5 rows vs 11: boot-splash incl. rdeps / pacman GUI / text editor / superseded / Thunderbolt incl. rdep); Masked-units table compacted (7 rows vs 12 via brace-notation: `avahi-daemon.{service,socket}` and `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target`); Known Issues MES-page-faults row tightened to single line; Troubleshooting MT7925 and 6.19.0-black-screen rows compressed; Hardware paragraph tightened; version bump 7.6.7 → 7.6.8.

v7.6.6 - v7.6.7 - 2026-05-24

- `_acquire_lock_fresh` post-`mkdir`-failure path adds `test -d "$LOCK_DIR"` to distinguish rc=2 (dir exists; stale-claim path) from rc=1 (permission, space, or other mkdir error — bail without stale-claim attempt); `_acquire_lock` stale-reclaim and `_dc_kill_children` lock-release both guard the `rm -rf --preserve-root` with `test -L "$LOCK_DIR"` (refuse on symlink); `_phase_record` sanitizes the `result` field through the same `string replace -ra '[\n\r│]' ' '` filter as `check` + `evidence` (matrix-delimiter parity); `_ry_apply_wireless_regdom` writes via `mktemp -p /etc/conf.d` + `test -L` probe + `chmod 0644` + `chown root:root` + atomic `mv -T` (mirrors `_fstab_atomic_replace`; defensive `install -d /etc/conf.d` when absent); README sudo drop-in suggestion enumerates per-binary `NOPASSWD:` list (`pacman, paru, sdboot-manage, mkinitcpio, bootctl, systemctl, systemd-tmpfiles, sysctl, paccache, ufw, install, mv, cp, rm, chmod, chown, find, cat, tee, stat, test, grep, awk, cmp, mktemp, dmesg, findmnt`) — blanket `NOPASSWD: ALL` retained as alternative with elevation warning; README Package caveats `PGP failures` row notes `--skipreview` auto-declines the interactive key-import prompt; README Phase 3 step 3 rephrases "TOCTOU close" → "narrows TOCTOU window to mktemp→tee"; README Env vars block appends `0600` user-file visibility note; README Exit codes `128+N` row notes `137` (KILL) cannot be caught — surfaces on external `pkill -KILL` or `_run`'s 10s post-TERM grace; version bump 7.6.6 → 7.6.7.

v7.6.5 - v7.6.6 - 2026-05-24

- `_post_service` adds user-scope branch routing `*/.config/systemd/user/*` targets through `systemctl --user` (parity with `_verify_unit_content` scope detection; user-bus probe gates dispatch); `_init_runtime` CPU model check fails closed when `/proc/cpuinfo` lacks a `model name` field (was fail-open; override via `RY_INSTALL_SKIP_HARDWARE_CHECK=1`); `_install_aur_packages` PGP hint reworded ("interactive import prompt is auto-declined under --skipreview"); 3 trivial helpers (`_pre_dispatch_exit`, `_set_exit`, `_ip_bail_prep`) collapsed to single-line form; 2 redundant `test …; return $status` lines dropped (fish implicit return covers); README Known Issues warns that `IgnorePkg=linux-firmware` pin leaves firmware unpatched against future CVEs; 7 `<summary>` rows strip trailing parentheticals for uniform shape; 5 multi-line prose wraps folded.

v7.6.4 - v7.6.5 - 2026-05-24

- `_fail_silent` renamed `_fail_no_count`; `_mr_copy_size_verify` drops redundant stat-size compare; `_awf_symlink_check` collapses to post-write probe; `_atomic_write_file` step list trimmed; `_acquire_lock` stale-PID reclaim simplified to `kill -0`; `_vs_read_symmetry_selftest` removed; `SYSTEM_DESTINATIONS` quotes `/etc/kernel/cmdline`; README softens paru version requirement; Safety table updates lock claim to `kill -0` probe.

v7.6.3 - v7.6.4 - 2026-05-24

- `_chk_perms` refuses 4-digit `stat -c %a` modes; `_ry_validate_configs` validates iwd-gated content unconditionally; preflight gains GNU `date '+%z'` probe; `_mask_list_effective` inlined; `VERIFY_STATIC_MISMATCH` JSONL relabels `_bytes` → `_chars`; README adds sudo TTY requirement, root-user caveat, exact `paccache -rk2 -ruk0` flags.

v7.6.2 - v7.6.3 - 2026-05-24

- `_dc_kill_children` `command sleep 0.5` gains `</dev/null` for stdin closure under cron/systemd unit.

v7.6.1 - v7.6.2 - 2026-05-24

- JSONL header `printf` format inlined as literal; `_set_exit` definition lifted above `_acquire_lock` call site.

v7.6 - v7.6.1 - 2026-05-24

- `_ntsync_state` `CONFIG_NTSYNC=y` `grep -q` gains `2>/dev/null` for stderr symmetry; six >100-char inline comments compressed.

v7.5 - v7.6 - 2026-05-24

- `_ry_do_install_file` iwd-gate pre-check; `_post_nm` defensive `pacman -Qi iwd` precheck; new run-summary matrix rows for PKGS_DEL/mask/enable; `_install_fstab_opts` moved into `_install_configure_services`; `_if_nm_restart` sleep gets `</dev/null`.

v7.4.74 - v7.5 - 2026-05-24

- Drop 18 trailing WHY-comments adjacent to section dividers; version bump to stable v7.5.

v7.4.73 - v7.4.74 - 2026-05-23

- Trim ~75 verbose WHY-comments to compact single-line form.

v7.4.72 - v7.4.73 - 2026-05-23

- Lift single-line WHY-comments above ~90 function declarations.

v7.4.71 - v7.4.72 - 2026-05-23

- `_content__etc_default_cpupower-service.conf` parameterize via `$CPUPOWER_GOVERNOR`; `_check_boot_taint_gate` extracted; `_csp_filter_rdeps` 5-stage pactree pipe → discrete stages; `_idf_match_dst` → `_idf_use_sudo_for_dst`; Exit-codes table widened to 12 entries.

v7.4.70 - v7.4.71 - 2026-05-23

- `_mkinitcpio_revert` + `_fstab_atomic_replace` tmpfile parent `/run/ry-install` → `/etc` (same-FS atomic `rename(2)`); `--install-file` path-length check char → byte.

v7.4.69 - v7.4.70 - 2026-05-23

- README Phase 1 row 9 documents always-on `_ry_check_wireless_regdom`; Safety signals row appends `WINCH`.

v7.4.68 - v7.4.69 - 2026-05-23

- `_verify_static_system` resolved.conf grep list parameterized via `$RESOLVED_LLMNR`/`$RESOLVED_DOT`/`$RESOLVED_DNSSEC`.

v7.4.67 - v7.4.68 - 2026-05-23

- `_content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf` parameterize LLMNR/DOT/DNSSEC globals; `_RY_LOG_WRITE_FAIL` setter gains `not set -q` guard.

v7.4.66 - v7.4.67 - 2026-05-23

- README + script + CHANGELOG version-aligned; CHANGELOG trimmed to kernel.org single-bullet form.

v7.4.65 - v7.4.66 - 2026-05-23

- README PKGS_DEL/MASK row order realigned to script declaration order; Exit-codes table 8 → 11 entries.

v7.4.64 - v7.4.65 - 2026-05-23

- Lift 11 single-line WHY comments above function declarations.

v7.4.63 - v7.4.64 - 2026-05-23

- Lift 7 top-of-body comments above function declarations.

v7.4.62 - v7.4.63 - 2026-05-23

- Trim file-top narrative comments above 6 `set -g` blocks; flatten CHANGELOG headings.

v7.4.61 - v7.4.62 - 2026-05-23

- README trim verbose table cells; script trim >100-char comments; CHANGELOG collapse multi-bullet entries.

v7.4.60 - v7.4.61 - 2026-05-23

- README Phase 3 tmpfiles header `Mode` → `Argument`.

v7.4.59 - v7.4.60 - 2026-05-23

- `_rdi_summary` realtime group hint `gpasswd -a` → `usermod -aG`.

v7.4.58 - v7.4.59 - 2026-05-23

- Comment trims across 7 sites.

v7.4.57 - v7.4.58 - 2026-05-23

- README Configuration revert per-phase prose; expand first `<details>` per phase to always-visible table.

v7.4.55 - v7.4.57 - 2026-05-23

- README wrap 6 bare per-phase Step tables in `<details>`; insert 1-line prose lead before first collapsible across all 6 phases.

v7.4.53 - v7.4.55 - 2026-05-23

- README convert all 9 non-table collapsibles to uniform Markdown tables; trim 678 → 623 LOC; compact value lists.

v7.4.52 - v7.4.53 - 2026-05-23

- `_verify_static_checksum` extract per-destination loop to `_vsc_check_one` helper.

v7.4.51 - v7.4.52 - 2026-05-23

- `_rrp_optional_indexer` flag capture via `set -l $argv[3..-1]`; PKGS_DEL += `breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt`.

v7.4.50 - v7.4.51 - 2026-05-23

- README Uninstall/Known Issues/Troubleshooting cell tightening; concrete kernel 6.19 downgrade commands.

v7.4.49 - v7.4.50 - 2026-05-23

- `_ry_show_help` log path `+ZZZZ` → `±ZZZZ`; drop stale 3.x signal qualifier; README Usage + RY_RUN_TIMEOUT + Logs aligned.

v7.4.48 - v7.4.49 - 2026-05-23

- `_ry_show_help` `RY_INSTALL_NO_MATRIX` label; HSAK <257 nested `if`; `_verify_static_checksum` `string collect` multi-line.

v7.4.47 - v7.4.48 - 2026-05-23

- Kernel <6.14 hard-floor FAIL; signal-race closures (`_acquire_lock_fresh`, `_set_exit`, `_cleanup`); tmpfile move `/etc` → `/run/ry-install`; AWK pipeline single sudo-awk.

v7.4.40 - v7.4.47 - 2026-05-22 to 2026-05-23

- Phase 1+2 sub-tables gain leading `#` column for step numbering; remove redundant Quick Start callout; Phase 1 enumerates 10 preflight steps; Phase 5 post-rebuild sanity row; Hardware notes CPU check runs every mode; README drop orphan kernel-bugzilla; clarify iwd-gated skip.

v7.4.38 - v7.4.40 - 2026-05-22

- Collapse verbose multi-clause inline comments; split 4 >220-char lines; `_post_cpupower` split warn pair; `_init_runtime` KERNEL_PARAMS regex lifted; README safe-trim 740 → 684 LOC.

v7.4.36 - v7.4.38 - 2026-05-22

- Flatten `_ry_tmpprobe_dir` + argparse-tail QUIET toggle; `_vrsv_chk_nm_dispatcher` short-circuit on `not-found`.

v7.4.34 - v7.4.36 - 2026-05-22

- Remove 3 stray `\;` tokens from inline `for` lists; `RY_INITRD_WARN_MB` invalid → `_RY_DEFERRED_WARNS`; malformed sysctl via `EXIT_GEN_SYSCTL`; split 2 >250-char lines.

v7.4.33 - v7.4.34 - 2026-05-21

- LOC reduction 5113 → 4468 via ~200 multi-line blocks collapsed to `; and` chain form.

v7.4.31 - v7.4.33 - 2026-05-21

- Consolidate CHANGELOG per-patch entries into ranges; expand 4 single-line content generators to multi-line `printf '%s\n' \` form.

v7.4.22 - v7.4.31 - 2026-05-21

- README Phase blocks → uniform "N sequential operations" intro; `<summary>` normalised to count+unit; style sync (`Fish` → `fish`, `Pacman` → `pacman`).

v7.4.5 - v7.4.22 - 2026-05-20

- LOC 5204 → 5113; collapse inline comments; function extractions ≤50 LOC; kernel <6.14 matrix FAIL; box-drawn Unicode run-summary matrix to stderr.

v7.4.0 - v7.4.5 - 2026-05-20

- Preflight + lock + sudo cache redesign; fish-version flat sentinel; `_acquire_lock` `/proc/$pid/comm` race close; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19

- Major preflight hardening; `_RY_LOUD_ERR` default-quiet; `_ir_resolve_root_uuid` 4-way mode dispatch; LOC 5177 → 4842; systemd <250 hard-fail; `EXIT_RUN_TMPFAIL` sentinel.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17

- NM 1.56.0 compat; MASK += avahi.service/.socket (10 → 12); PKGS_ADD += `realtime-privileges`, `cpupower`; PKGS_DEL += `bolt`; new `_ry_check_wireless_regdom`/`_vrk_audio_state`/`_ry_apply_wireless_regdom`; managed-file count 13 → 12.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994 → 4985 LOC); drop scaffolding; add user-bus detection, `printf`-only emitters, split `_run`, `_atomic_write_file` post-write symlink re-check, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
