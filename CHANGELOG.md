ry-install changelog

v3.50.4  2026-04-13
- _ry_do_test_all: wrapped parallel worker fork (`fish -c` at the test harness call site) with `command timeout --kill-after=5 180` — was the only parallel `fish -c` site missing the timeout wrapper that the other 10 sites already carry. A hung child (e.g. `--verify-static` blocking mid-sudo) would have blocked the parent `wait $parallel_pids` indefinitely. 180s chosen over the 60s used elsewhere because this site runs full verify modes (sudo reads, dmesg parse, pacman queries), not in-memory validators.

v3.50.3  2026-04-13
- README: Environment Variables table — added missing `|---|---|` separator row (table was rendering as raw text).
- README: Environment Variables table — added missing `DXVK_LOG_LEVEL=none` (script defines 12 ENV_VARS, README was listing 11).
- README: Quick Start — removed duplicated "on ethernet" phrase in the WiFi-install note.
- README: capitalized `[Changelog]` link to match heading style.

v3.50.2  2026-04-13
- _load_profile: bail sentinel check after source call — prevents execution continuing with _RY_INSTALL_BAILING already set.
- _run: metacharacter rejection now surfaces to stderr via _err in addition to JSONL.
- Corrected fish version gate comment: 3.4 requires set --function and string collect, not $() syntax.
- _ry_install_files: mktemp degradation now surfaces to stderr via _warn in addition to JSONL.

v3.50.1  2026-04-13
- _ry_verify_runtime: guard BOOT_TIME_TARGET dereference behind set -q to match its optional declaration in _validate_profile.
- README: corrected 15 → 16 embedded configs in lede and Install Flow (Managed Files table was already correct).
- README: Log Format footer fields, event table, and sample log corrected and expanded.
- README: condensed Profiles, Safety & Reliability, Environment Variables, and Data Directory sections.

v3.50.0  2026-04-13
- Kernel cmdline: dropped threadirqs (redundant on CachyOS kernel) and initcall_blacklist=simpledrm_platform_driver_init. 14 → 12 params.
- Sysctl: added vm.compaction_proactiveness=0, net.core.busy_read/poll=50, net.core.netdev_budget=600. 17 → 21 tunables.
- Packages: added vulkan-radeon, lib32-vulkan-radeon, libva-mesa-driver, lib32-libva-mesa-driver. 11 → 15 installs.
- Managed files: added /etc/udev/rules.d/99-nvme-rqaffinity.rules (rq_affinity=2). 15 → 16 files.
- logind: added HandleSecureAttentionKey (gated to systemd ≥256). 8 → 9 ignore keys.
- NetworkManager: wifi.iwd.autoconnect=false to prevent NM/iwd autoconnect race.
- Comment cleanup: collapsed 8 multi-line comment blocks, net −20 lines.
- README: TOC converted to numbered list with nested subsection bullets.

v3.49.0  2026-04-12
- Comment sweep: dropped 61 low-value comment lines (narration-prefix and orphaned section refs). 6050 → 5989 lines. Zero behavior change.

v3.48.26  2026-04-09
- TIMESTAMP: suffixed with $fish_pid to prevent log-file race between concurrent --test-all children running in the same second.
- _ry_verify_static: mktemp early-return path now calls _verify_summary and uses _fail so summary line and counter are consistent.
- _ry_verify_runtime: sys_units count-drift assertion path given same treatment.

v3.48.25  2026-04-09
- _run: RY_RUN_TIMEOUT regex tightened from ^\d+$ to ^[1-9]\d*$ — rejects 0, empty, leading-zero, and non-integer forms.
- _ry_show_help: added ENVIRONMENT section documenting RY_RUN_TIMEOUT and RY_INSTALL_CONFIRM_BOOT_WIPE.
- README: Safety & Reliability — added Environment Variables subsection (RY_RUN_TIMEOUT, RY_INSTALL_CONFIRM_BOOT_WIPE, NO_COLOR).

v3.48.24  2026-04-09
- _run: added </dev/null to prevent terminal-probing hangs (stray sudo prompt, pacman confirm).
- _run: opt-in wall-clock timeout via RY_RUN_TIMEOUT env var; unset preserves legacy behavior.
- Parallel workers: wrapped 10 fish -c background jobs with timeout --kill-after=5 60.
- _atomic_write_file: post-write hash mismatch now distinguishes real content mismatch from sudo credential lapse.

v3.48.23  2026-04-09
- _ry_do_test_all: managed-case count drift assertion — awk counts case branches in _ry_get_file_content and compares against _RY_MANAGED_CASE_COUNT; mismatch aborts before forking sub-tests.

v3.48.22  2026-04-09
- Removed _ry_count_managed_cases; replaced with compile-time constant _RY_MANAGED_CASE_COUNT.
- Removed _get_boot_time; inlined at call site in _ry_verify_runtime.
- Merged _progress_skip into _progress with optional skip positional.
- Fixed _progress bar rendering as [] at 0% and 100%.
- Net 6001 → 5983 lines (-18). Function count 79 → 76.

v3.48.21  2026-04-09
- Removed 4 stale --lint comments.
- _run: dropped dead /dev/null init and unreachable guards.

v3.48.20  2026-04-09
- Removed --lint mode and _ry_do_lint (~317 lines). Net 6331 → 6001.
- Removed --restore-power-targets mode (never documented).
- Fixed top-level exit killing host shell on source: added _ry_exit helper, _RY_INSTALL_BAILING sentinel, _RY_INSTALL_SOURCED flag; _RY_INSTALL_LAST_EXIT for sourcing shell.
- EXPECTED_VULKAN_PKGS now optional; verify-runtime gates on set -q.
- _install_configure_services: corrected pactree orphan detection (pactree -ru | string match -v).
- _ry_do_install_file: realpath -m on managed dests (fixes /home symlink hosts).
- _run: single mktemp -d for stdout/stderr pair; degraded path fails loud.
- _atomic_write_file: parent-dir trust check rewritten as explicit if/else if.
- Boot-wipe marker: hoisted into _install_finalize success path; atomic write.
- Minor: cpupower-epp.service I/O masking, _log JSON-escape, _progress narrow terminal, _ry_do_completions printf consolidation.

v3.48.19  2026-04-09
- _pregenerate_content_files: gate trailing echo on _we_created_dir.
- _dir_group_or_world_writable: single helper replaces duplicates.
- BOOT_WIPE_MARKER: stores entry count; re-prompts if entries grew.
- _progress: bar via string repeat.

v3.48.18  2026-04-09
- _ry_do_test_all: fixed false code=999 from label stripping mismatch.
- _validate_user_env: regex-escape $var_name; added missing --.
- _install_kernel_cmdline: anchored LINUX_OPTIONS= strip.
- _ry_verify_runtime NM sweep: find -print0 | string split0.
- Minor: BOOT_WIPE_MARKER consolidation, completions, NM restart delay, log rotation.

v3.48.17  2026-04-08
- _pregenerate_content_files: mktemp -t flag fix.
- _cleanup_tmpfiles: sweep 0700 root dirs via sudo -n find.
- _install_fstab_opts: awk OFS fix; post-rewrite findmnt --verify check.
- _content_hash: capture $pipestatus for generator failures.
- Cosmetic: collapsed comment runs (-36 lines).

v3.48.16  2026-04-08
- SDBOOT_REMOVE_EXISTING=yes now requires RY_INSTALL_CONFIRM_BOOT_WIPE=1; marker at ~/ry-install/.boot-wipe-acknowledged.
- _atomic_write_file: post-write hash distinguishes sudo lapse from fs error.
- Preflight: missing root UUID is EXIT_PREFLIGHT; dropped diff/md5sum/tput deps; iw removed from PKGS_ADD (12->11).
- _acquire_lock: flock reclaim writes PID inside locked subshell.
- _ry_verify_runtime: WiFi checks gated on profile; HPET fail auto-greps dmesg for "Marking TSC unstable".

v3.48.6-v3.48.15  2026-04-08
- See v3.48.16 for SDBOOT_REMOVE_EXISTING ack, _atomic_write_file, preflight, _acquire_lock, and _ry_verify_runtime changes (landed across these versions).
- README: condensation and completeness pass (Uninstall, Scope, paru fallback, fstab no-backup, profile globals, NDJSON sample, Troubleshooting, TOC, badges removed).
- Internal fixes: _log classifier, _ry_verify_static, _ry_do_test_all, _install_packages, sudo keepalive, _install_aur_packages, arg parser.
