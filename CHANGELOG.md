ry-install ChangeLog

v7.4.69 - v7.4.70 - 2026-05-23

- README Phase 1 row 9 documents always-on `_ry_check_wireless_regdom` (warn on unset/invalid) alongside opt-in `_ry_apply_wireless_regdom`; Safety signals row appends `WINCH` (non-fatal; `_progress_on_winch` re-anchors progress bar on terminal resize); zero behavioural change.

v7.4.68 - v7.4.69 - 2026-05-23

- `_verify_static_system` resolved.conf grep list parameterized via `$RESOLVED_LLMNR`/`$RESOLVED_DOT`/`$RESOLVED_DNSSEC`; `_irb_taint_gate` + `_post_boot` `not test "$RY_INSTALL_FORCE_BOOT_REBUILD" = 1` → `test "$RY_INSTALL_FORCE_BOOT_REBUILD" != 1`; `_ry_check_wireless_regdom` section divider merged with cfg80211 udev note.

v7.4.67 - v7.4.68 - 2026-05-23

- `_content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf` parameterize LLMNR/DOT/DNSSEC via new `RESOLVED_LLMNR`/`RESOLVED_DOT`/`RESOLVED_DNSSEC` globals (matches sibling generators; bytes-identical output); README Phase 3 table 4 → 6 rows (mktemp/probe-pre/render/probe-post/chmod/mv-T mirrors `_atomic_write_file`); README NM-dispatcher note corrected (enabled when present and disabled); `_RY_LOG_WRITE_FAIL` setter at log-rename + header-write fail paths gains `not set -q` guard (style alignment with `_log`/`_write_footer`).

v7.4.66 - v7.4.67 - 2026-05-23

- README + script + CHANGELOG version-aligned; CHANGELOG trimmed to kernel.org single-bullet form; zero behavioural change.

v7.4.65 - v7.4.66 - 2026-05-23

- README PKGS_DEL/MASK row order realigned to script declaration order; Exit-codes table 8 → 11 entries (sentinels 11/12/13/251); help text mirrors README.

v7.4.64 - v7.4.65 - 2026-05-23

- Lift 11 single-line WHY comments above function declarations; visual blank-line grouping across function families; LOC 4745 → 4967.

v7.4.63 - v7.4.64 - 2026-05-23

- Lift 7 top-of-body comments above function declarations; zero LOC delta; content-generator output byte-identical.

v7.4.62 - v7.4.63 - 2026-05-23

- Trim file-top narrative comments above 6 set -g blocks; flatten CHANGELOG headings (-24 LOC).

v7.4.61 - v7.4.62 - 2026-05-23

- README trim verbose table cells (670 → 666 LOC); script trim >100-char comments; CHANGELOG collapse multi-bullet entries.

v7.4.60 - v7.4.61 - 2026-05-23

- README Phase 3 tmpfiles header `Mode` → `Argument` (sysfs content per tmpfiles.d(5)).

v7.4.59 - v7.4.60 - 2026-05-23

- `_rdi_summary` realtime group hint `gpasswd -a` → `usermod -aG` (preserves other groups).

v7.4.58 - v7.4.59 - 2026-05-23

- Comment trims across 7 sites; -2 LOC.

v7.4.57 - v7.4.58 - 2026-05-23

- README Configuration revert per-phase prose; expand first `<details>` per phase to always-visible table.

v7.4.56 - v7.4.57 - 2026-05-23

- README insert 1-line prose lead before first collapsible across all 6 phases.

v7.4.55 - v7.4.56 - 2026-05-23

- README wrap 6 bare per-phase Step tables in `<details>` for uniform shape.

v7.4.54 - v7.4.55 - 2026-05-23

- README convert all 9 non-table collapsibles to uniform Markdown tables.

v7.4.53 - v7.4.54 - 2026-05-23

- README trim 678 → 623 LOC (-8.1%); compact value lists; kernel cmdline → code block.

v7.4.52 - v7.4.53 - 2026-05-23

- `_verify_static_checksum` extract per-destination loop to `_vsc_check_one` helper (55 → 9 LOC).

v7.4.51 - v7.4.52 - 2026-05-23

- `_rrp_optional_indexer` flag capture via `set -l $argv[3..-1]`; PKGS_DEL += `breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt` (Plasma rdeps).

v7.4.50 - v7.4.51 - 2026-05-23

- README Uninstall/Known Issues/Troubleshooting cell tightening; sudo prefixing; `&&` → `; and`; concrete kernel 6.19 downgrade commands.

v7.4.49 - v7.4.50 - 2026-05-23

- `_ry_show_help` log path `+ZZZZ` → `±ZZZZ`; drop stale 3.x signal qualifier; README Usage + RY_RUN_TIMEOUT + Logs aligned.

v7.4.48 - v7.4.49 - 2026-05-23

- `_ry_show_help` `RY_INSTALL_NO_MATRIX` label; HSAK <257 nested `if`; `_verify_static_checksum` `string collect` multi-line.

v7.4.47 - v7.4.48 - 2026-05-23

- Kernel <6.14 hard-floor FAIL; signal-race closures (`_acquire_lock_fresh`, `_set_exit`, `_cleanup`); tmpfile move `/etc` → `/run/ry-install`; AWK pipeline single sudo-awk.

v7.4.46 - v7.4.47 - 2026-05-23

- Phase 1 + Phase 2 sub-tables: leading `#` column for step numbering consistency across all 6 phases.

v7.4.45 - v7.4.46 - 2026-05-23

- Remove redundant Quick Start `[!IMPORTANT]` callout; trim iwd `<details>` skip note.

v7.4.44 - v7.4.45 - 2026-05-23

- Phase 1 enumerates 10 preflight steps in runtime order; Phase 5 post-rebuild sanity row; Hardware notes CPU check runs every mode.

v7.4.40 - v7.4.44 - 2026-05-22

- README drop orphan kernel-bugzilla; clarify iwd-gated skip; align cpupower-service + tmpfiles to logind shape; collapse 3 low-density tables.

v7.4.39 - v7.4.40 - 2026-05-22

- README safe-trim 740 → 684 LOC; drop header blockquote, WiFi-defer duplicate, Hardware bugzilla, `jq` footer example.

v7.4.38 - v7.4.39 - 2026-05-22

- Collapse verbose multi-clause inline comments; split 4 >220-char lines; `_post_cpupower` split warn pair; `_init_runtime` KERNEL_PARAMS regex lifted.

v7.4.37 - v7.4.38 - 2026-05-22

- Flatten `_ry_tmpprobe_dir` + argparse-tail QUIET toggle; README Run Summary → prose; Configuration → tables for mobile.

v7.4.36 - v7.4.37 - 2026-05-22

- `_vrsv_chk_nm_dispatcher`: short-circuit on `not-found` (`_warn` + return 0).

v7.4.35 - v7.4.36 - 2026-05-22

- Remove 3 stray `\;` tokens from inline `for` lists; `RY_INITRD_WARN_MB` invalid → `_RY_DEFERRED_WARNS`; malformed sysctl via `EXIT_GEN_SYSCTL`.

v7.4.34 - v7.4.35 - 2026-05-22

- Split 2 >250-char lines (MASK service list, sudo-cache warning printf); drop dead `2>/dev/null` on `status stack-trace`.

v7.4.33 - v7.4.34 - 2026-05-21

- LOC reduction 5113 → 4468: ~200 multi-line blocks collapsed to `; and` chain form; function count unchanged.

v7.4.32 - v7.4.33 - 2026-05-21

- Consolidate CHANGELOG per-patch entries into ranges; close chain gaps; bump README badge.

v7.4.31 - v7.4.32 - 2026-05-21

- Expand 4 single-line content generators to multi-line `printf '%s\n' \` form; output byte-identical.

v7.4.22 - v7.4.31 - 2026-05-21

- README cleanup: Phase blocks → uniform "N sequential operations" intro; `<summary>` normalised to count+unit; style sync (`Fish` → `fish`, `Pacman` → `pacman`).

v7.4.5 - v7.4.22 - 2026-05-20

- LOC 5204 → 5113; collapse inline comments; chain `set -l/-g` runs; function extractions ≤50 LOC; kernel <6.14 matrix FAIL; box-drawn Unicode run-summary matrix to stderr.

v7.4.0 - v7.4.5 - 2026-05-20

- Preflight + lock + sudo cache redesign; fish-version flat sentinel; `_acquire_lock` `/proc/$pid/comm` race close; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19

- Major preflight hardening; `_RY_LOUD_ERR` default-quiet; `_ir_resolve_root_uuid` 4-way mode dispatch; LOC 5177 → 4842; systemd <250 hard-fail; `EXIT_RUN_TMPFAIL` sentinel.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17

- NM 1.56.0 compat; MASK += avahi.service/.socket (10 → 12); PKGS_ADD += `realtime-privileges`, `cpupower`; PKGS_DEL += `bolt`; new `_ry_check_wireless_regdom`/`_vrk_audio_state`/`_ry_apply_wireless_regdom`; managed-file count 13 → 12.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994 → 4985 LOC); drop scaffolding (GNU probes, source-mode, sudo-keepalive); add user-bus detection, `printf`-only emitters, split `_run`, `_atomic_write_file` post-write symlink re-check, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
