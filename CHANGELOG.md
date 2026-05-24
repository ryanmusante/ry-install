ry-install ChangeLog

v7.6.4 - v7.6.5 - 2026-05-24

- `_fail_silent` renamed `_fail_no_count` (description was already accurate; name now matches behaviour — counter-skip not stderr-silent); `_mr_copy_size_verify` drops redundant stat-size compare (`cmp -s` covers length+content in one step); `_awf_symlink_check` collapses to post-write probe only (mktemp -p O_EXCL|O_CREAT precludes a pre-existing symlink at the just-created path); `_atomic_write_file` step list trims to mktemp → render → post-write symlink probe → chmod → mv -T; `_acquire_lock` stale-PID reclaim simplified to `kill -0` only (PID-recycle race rare; recovery is `rm -rf ~/ry-install/.lock`); `_vs_read_symmetry_selftest` removed (preventive canary with no observed regression); `SYSTEM_DESTINATIONS` quotes `/etc/kernel/cmdline` for whitespace consistency; README softens paru version from "≥ 2.0.0" to "(≥ 2.0.0 recommended)" matching `_ry_check_deps` WARN-only semantics; README Safety table updates lock claim to `kill -0` probe; README Phase 3 step list drops pre-render symlink probe.

v7.6.3 - v7.6.4 - 2026-05-24

- `_chk_perms` refuses 4-digit `stat -c %a` modes (surfaces setuid/sgid/sticky drift on managed files instead of stripping the leading bit); `_ry_validate_configs` validates iwd-gated content regardless of `_should_skip_iwd` (preflight catches embedded-content bugs before iwd is later installed); preflight gains GNU `date '+%z'` probe (busybox/uutils emit `+0000` without sign — log path embeds `±ZZZZ`); `_mask_list_effective` inlined at three sites (single-line passthrough removed); `VERIFY_STATIC_MISMATCH` JSONL relabels `_bytes` → `_chars` (fish `string length` is char-based); README adds sudo TTY requirement, root-user caveat in Quick Start, exact `paccache -rk2 -ruk0` flags, fstab malformed-entry skip semantics, MT7925 workaround verification step.

v7.6.2 - v7.6.3 - 2026-05-24

- `_dc_kill_children` `command sleep 0.5` gains `</dev/null` for stdin closure under cron/systemd unit (signal-path symmetry with v7.5→7.6 `_if_nm_restart` sleep fix; defensive — sleep runs in cleanup TERM→KILL grace window only); zero behavioural change.

v7.6.1 - v7.6.2 - 2026-05-24

- JSONL header printf format inlined as literal (eliminates `_hdr_fmt` variable indirection — no format-string-from-variable surface for future edits); `_set_exit` function definition lifted above `_acquire_lock` call site (defence-in-depth ordering — signal handler `_cleanup` still exits via direct path, but `_set_exit` is now defined before any code that could conceivably invoke it); zero behavioural change.

v7.6 - v7.6.1 - 2026-05-24

- `_ntsync_state` `CONFIG_NTSYNC=y` `grep -q` gains `2>/dev/null` for stderr symmetry with sibling `/proc/modules` probe; six >100-char inline comments compressed in-place; byte-identical content-generator output.

v7.5 - v7.6 - 2026-05-24

- `_ry_do_install_file` iwd-gate pre-check: skipped target now emits skip-banner and returns 0 without dispatching the post-hook (previously printed false `Installed:` line + fired `_post_nm` cascade); `_post_nm` defensive `pacman -Qi iwd` precheck mirroring `_if_nm_restart`; new run-summary matrix rows for `Services: PKGS_DEL removal`, `Services: mask units`, `Services: enable units`; `_install_fstab_opts` moved into `_install_configure_services` head (matches README Phase 4 step 1 order); aggregate `Services: configuration` row replaced by granular rows; `_post_hook_for_target` drop redundant `-r` from `string split` (single-separator entries); `_if_nm_restart` sleep gets `</dev/null` for stdin closure under cron; partial-upgrade retry comment tightened.

v7.4.74 - v7.5 - 2026-05-24

- Drop 18 trailing WHY-comments adjacent to section dividers; version bump to stable v7.5.

v7.4.73 - v7.4.74 - 2026-05-23

- Trim ~75 verbose WHY-comments to compact single-line form; zero behavioural change; byte-identical content-generator output.

v7.4.72 - v7.4.73 - 2026-05-23

- Lift single-line WHY-comments above ~90 function declarations; zero behavioural change.

v7.4.71 - v7.4.72 - 2026-05-23

- `_content__etc_default_cpupower-service.conf` parameterize via `$CPUPOWER_GOVERNOR`; `_check_boot_taint_gate` extracted from `_irb_taint_gate` + `_post_boot`; `_csp_filter_rdeps` 5-stage pactree pipe → discrete stages; `_idf_match_dst` → `_idf_use_sudo_for_dst`; `_kver_below` drop 3-arg defaults; fstab phase row label aligned to README Phase 4; Exit-codes table widened to 12 entries.

v7.4.70 - v7.4.71 - 2026-05-23

- `_mkinitcpio_revert` + `_fstab_atomic_replace` tmpfile parent `/run/ry-install` → `/etc` (same-FS atomic `rename(2)`); `--install-file` path-length check char → byte (PATH_MAX is byte-bound); README Phase 6 step list trimmed.

v7.4.69 - v7.4.70 - 2026-05-23

- README Phase 1 row 9 documents always-on `_ry_check_wireless_regdom`; Safety signals row appends `WINCH` (non-fatal progress-bar re-anchor).

v7.4.68 - v7.4.69 - 2026-05-23

- `_verify_static_system` resolved.conf grep list parameterized via `$RESOLVED_LLMNR`/`$RESOLVED_DOT`/`$RESOLVED_DNSSEC` globals.

v7.4.67 - v7.4.68 - 2026-05-23

- `_content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf` parameterize LLMNR/DOT/DNSSEC globals; README Phase 3 table 4 → 6 rows mirroring `_atomic_write_file`; README NM-dispatcher note corrected; `_RY_LOG_WRITE_FAIL` setter gains `not set -q` guard.

v7.4.66 - v7.4.67 - 2026-05-23

- README + script + CHANGELOG version-aligned; CHANGELOG trimmed to kernel.org single-bullet form.

v7.4.65 - v7.4.66 - 2026-05-23

- README PKGS_DEL/MASK row order realigned to script declaration order; Exit-codes table 8 → 11 entries (sentinels 11/12/13/251); help text mirrors README.

v7.4.64 - v7.4.65 - 2026-05-23

- Lift 11 single-line WHY comments above function declarations; visual blank-line grouping across function families.

v7.4.63 - v7.4.64 - 2026-05-23

- Lift 7 top-of-body comments above function declarations; content-generator output byte-identical.

v7.4.62 - v7.4.63 - 2026-05-23

- Trim file-top narrative comments above 6 `set -g` blocks; flatten CHANGELOG headings.

v7.4.61 - v7.4.62 - 2026-05-23

- README trim verbose table cells; script trim >100-char comments; CHANGELOG collapse multi-bullet entries.

v7.4.60 - v7.4.61 - 2026-05-23

- README Phase 3 tmpfiles header `Mode` → `Argument` (sysfs content per tmpfiles.d(5)).

v7.4.59 - v7.4.60 - 2026-05-23

- `_rdi_summary` realtime group hint `gpasswd -a` → `usermod -aG` (preserves other groups).

v7.4.58 - v7.4.59 - 2026-05-23

- Comment trims across 7 sites.

v7.4.57 - v7.4.58 - 2026-05-23

- README Configuration revert per-phase prose; expand first `<details>` per phase to always-visible table.

v7.4.56 - v7.4.57 - 2026-05-23

- README insert 1-line prose lead before first collapsible across all 6 phases.

v7.4.55 - v7.4.56 - 2026-05-23

- README wrap 6 bare per-phase Step tables in `<details>` for uniform shape.

v7.4.54 - v7.4.55 - 2026-05-23

- README convert all 9 non-table collapsibles to uniform Markdown tables.

v7.4.53 - v7.4.54 - 2026-05-23

- README trim 678 → 623 LOC; compact value lists; kernel cmdline → code block.

v7.4.52 - v7.4.53 - 2026-05-23

- `_verify_static_checksum` extract per-destination loop to `_vsc_check_one` helper.

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
