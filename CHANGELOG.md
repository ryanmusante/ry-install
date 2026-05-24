ry-install ChangeLog

v7.6.9 - v7.6.10 - 2026-05-24

- README WARNING + Hardware + Configuration intro + Run Summary + fstab + Env + Known Issues + Troubleshooting prose trimmed; PGP caveat + MES-page-faults + Stale-lock + user-bus rows tightened; stale Runtime-variables count 10 → 9 fixed; 3 verbose script comments trimmed (lock PID-race, mkinitcpio snapshot retention, `_post_service` daemon-reload).

v7.6.8 - v7.6.9 - 2026-05-24

- Remove wireless-regdom feature (3 functions, env var, Phase 1 step, README rows, --help line); CHANGELOG entries trimmed.

v7.6.7 - v7.6.8 - 2026-05-24

- README WARNING block + Install Flow + Phase 1 tables trimmed; Packages-install (5/15), Packages-remove (5/11), Masked-units (7/12) regrouped; Hardware + Known-Issues + Troubleshooting rows tightened.

v7.6.6 - v7.6.7 - 2026-05-24

- `_acquire_lock_fresh` separates exists vs other mkdir errors; `_acquire_lock` + `_dc_kill_children` symlink-guard LOCK_DIR; `_phase_record` sanitizes result field; README sudoers scoped, PGP/TOCTOU/0600/SIGKILL clarifications.

v7.6.5 - v7.6.6 - 2026-05-24

- `_post_service` routes user-scope `*/.config/systemd/user/*` targets via `systemctl --user`; `_init_runtime` CPU-model check fails closed; AUR PGP hint reworded; 3 trivial helpers collapsed single-line; README Known Issues warns `IgnorePkg=linux-firmware` blocks CVE fixes.

v7.6.4 - v7.6.5 - 2026-05-24

- `_fail_silent` → `_fail_no_count`; `_acquire_lock` stale-PID reclaim simplified to `kill -0`; `_mr_copy_size_verify` drops redundant size compare; README softens paru version requirement.

v7.6.3 - v7.6.4 - 2026-05-24

- `_chk_perms` refuses 4-digit `stat -c %a` modes; `_ry_validate_configs` iwd-gated content validated unconditionally; preflight gains GNU `date '+%z'` probe; README adds sudo TTY + root-user caveat.

v7.6.2 - v7.6.3 - 2026-05-24

- `_dc_kill_children` `command sleep 0.5` gains `</dev/null` for stdin closure under cron/systemd unit.

v7.6.1 - v7.6.2 - 2026-05-24

- JSONL header `printf` format inlined as literal; `_set_exit` lifted above `_acquire_lock` call site.

v7.6 - v7.6.1 - 2026-05-24

- `_ntsync_state` `CONFIG_NTSYNC=y` `grep -q` gains `2>/dev/null` for stderr symmetry.

v7.5 - v7.6 - 2026-05-24

- `_ry_do_install_file` iwd-gate pre-check; `_post_nm` defensive `pacman -Qi iwd` precheck; new run-summary matrix rows for PKGS_DEL/mask/enable; `_install_fstab_opts` moved into `_install_configure_services`.

v7.4.74 - v7.5 - 2026-05-24

- Drop trailing WHY-comments adjacent to section dividers; version bump to stable v7.5.

v7.4.73 - v7.4.74 - 2026-05-23

- Trim verbose WHY-comments to compact single-line form.

v7.4.72 - v7.4.73 - 2026-05-23

- Lift single-line WHY-comments above ~90 function declarations.

v7.4.71 - v7.4.72 - 2026-05-23

- `_content__etc_default_cpupower-service.conf` parameterized via `$CPUPOWER_GOVERNOR`; `_check_boot_taint_gate` extracted; Exit-codes table widened to 12 entries.

v7.4.70 - v7.4.71 - 2026-05-23

- `_mkinitcpio_revert` + `_fstab_atomic_replace` tmpfile parent `/run/ry-install` → `/etc` (same-FS atomic `rename(2)`); `--install-file` path-length check char → byte.

v7.4.69 - v7.4.70 - 2026-05-23

- README Safety signals row appends `WINCH`.

v7.4.68 - v7.4.69 - 2026-05-23

- `_verify_static_system` resolved.conf grep list parameterized via `$RESOLVED_LLMNR`/`$RESOLVED_DOT`/`$RESOLVED_DNSSEC`.

v7.4.67 - v7.4.68 - 2026-05-23

- `_content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf` parameterized via LLMNR/DOT/DNSSEC globals; `_RY_LOG_WRITE_FAIL` setter gains `not set -q` guard.

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

- README convert 9 non-table collapsibles to uniform Markdown tables; trim 678 → 623 LOC.

v7.4.52 - v7.4.53 - 2026-05-23

- `_verify_static_checksum` extract per-destination loop to `_vsc_check_one` helper.

v7.4.51 - v7.4.52 - 2026-05-23

- `_rrp_optional_indexer` flag capture via `set -l $argv[3..-1]`; PKGS_DEL += `breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt`.

v7.4.50 - v7.4.51 - 2026-05-23

- README Uninstall + Known Issues + Troubleshooting cell tightening; concrete kernel 6.19 downgrade commands.

v7.4.49 - v7.4.50 - 2026-05-23

- `_ry_show_help` log path `+ZZZZ` → `±ZZZZ`; drop stale 3.x signal qualifier; README Usage + RY_RUN_TIMEOUT + Logs aligned.

v7.4.48 - v7.4.49 - 2026-05-23

- `_ry_show_help` `RY_INSTALL_NO_MATRIX` label; `_verify_static_checksum` `string collect` multi-line.

v7.4.47 - v7.4.48 - 2026-05-23

- Kernel <6.14 hard-floor FAIL; signal-race closures (`_acquire_lock_fresh`, `_set_exit`, `_cleanup`); tmpfile move `/etc` → `/run/ry-install`; AWK pipeline single sudo-awk.

v7.4.40 - v7.4.47 - 2026-05-22 to 2026-05-23

- Phase 1+2 sub-tables gain leading `#` column; remove redundant Quick Start callout; Phase 5 post-rebuild sanity row; Hardware notes CPU check runs every mode.

v7.4.38 - v7.4.40 - 2026-05-22

- Collapse verbose multi-clause inline comments; split 4 >220-char lines; `_post_cpupower` split warn pair; README safe-trim 740 → 684 LOC.

v7.4.36 - v7.4.38 - 2026-05-22

- Flatten `_ry_tmpprobe_dir` + argparse-tail QUIET toggle; `_vrsv_chk_nm_dispatcher` short-circuit on `not-found`.

v7.4.34 - v7.4.36 - 2026-05-22

- Remove 3 stray `\;` tokens from inline `for` lists; `RY_INITRD_WARN_MB` invalid → `_RY_DEFERRED_WARNS`; malformed sysctl via `EXIT_GEN_SYSCTL`.

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

- NM 1.56.0 compat; MASK += avahi.service/.socket (10 → 12); PKGS_ADD += `realtime-privileges`, `cpupower`; PKGS_DEL += `bolt`; new `_vrk_audio_state`; managed-file count 13 → 12.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994 → 4985 LOC); drop scaffolding; add user-bus detection, `printf`-only emitters, split `_run`, `_atomic_write_file` post-write symlink re-check, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
