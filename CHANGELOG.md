ry-install changelog

v3.51.15  2026-04-17
- `_install_configure_services` dead local variable (LOW): `display_list` + the associated `first_five` subshell construction removed. The variable was set but never read; `_log "PKG_REMOVE_REQUESTED: …"` uses `$to_del` directly. 5 lines of dead code eliminated.
- Historical-marker comment trimming (INFO): 31 comment sites carrying `v3.51.N:` / `Fix N:` / `LOW-N fix:` / `(was: …)` / `previously …` prefixes had their version-history tags removed. Behavioral rationale preserved verbatim; only the temporal/journal framing was stripped (user rule: "comments describe current behavior, not change history"). Sites: L11, L14, L33, L44, L141, L163, L208, L338, L485, L871, L1190, L1587, L1678, L2356, L2442, L2447, L2507, L2537, L3244, L3260, L3366, L3556, L4557, L4617, L4765, L4889, L4904, L4992, L5306, L5583, L5681, L5773.
- Verification sweep: zero dead functions (all 77 have >=2 references), zero unread `set -g` globals (40 declared, all read), zero unused `set -l` locals across all 77 functions. `fish --no-execute` clean.
- Line count: 6175 → 6170 (5 lines from `display_list` removal; comment trims are content-only).
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.
- README.md: version banner + sample log bumped to v3.51.15.

v3.51.14  2026-04-17
- Comment trimming (INFO): two multi-line `#` comment blocks collapsed to single-line form for consistency with user rule "comments are single-sentence" — `_kill_sudo_keepalive` SIGTERM→SIGKILL rationale at L485-487 (3 lines → 1) and `_install_configure_services` pactree intra-batch filter rationale at L4994-4995 (2 lines → 1). No behavior change; content preserved verbatim in merged form.
- Content generation condensation (INFO): 8 multi-line `printf '%s\n' "X"` blocks in `_ry_get_file_content` collapsed to single-call multi-arg form (loader.conf, sdboot-manage.conf, mkinitcpio.conf, resolved.conf.d, coredump.conf.d, nvme-rqaffinity.rules, iwd/main.conf, NM/nm.conf). `printf '%s\n' a b c` reuses the format per arg — byte-identical output, ~39 lines saved, no embedded-config hash drift.
- `_ry_show_help` trimming (INFO): ENVIRONMENT and NOTES sections consolidated to single-line entries; information preserved, ~15 lines saved. Help text still self-contained.
- Line count: 6233 → 6175 (58 lines, ~0.9%).
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.
- README.md: version banner + sample log bumped to v3.51.14.

v3.51.13  2026-04-17
- `_install_configure_services` pactree intra-batch filter (MED): `pactree -ru $pkg` reverse-dep check now filters sibling members of `$PKGS_DEL` before the `count -gt 0` guard. Previously, removing a base pkg (plymouth, micro) whose only live rdeps were themselves queued for removal (cachyos-plymouth-bootanimation/theme depends=plymouth; cachyos-micro-settings depends=micro) caused the base pkg to be skipped silently, leaving it installed after the pipeline reported success. Verified against upstream PKGBUILDs at github.com/CachyOS/CachyOS-PKGBUILDS.
- `_detect_lvm` helper (LOW): new function extracts the three identical `timeout 5 sudo -n pvs --noheadings` probes at (prev) L2840/L3518/L5087. Probe body lives in one place; callers retain per-site action. Incidental fixes: missing `command` prefix on `timeout`, and variable-name drift `_pvs_output` vs `pvs_output`, both unified.
- `_kill_sudo_keepalive` SIGTERM→SIGKILL escalation (LOW): explicit `sleep 0.1` + `kill -KILL` fallback after SIGTERM closes the defensive-hardening window where a keepalive ignoring SIGTERM keeps sudo credentials cached past script exit. Child is still disowned — init reaps.
- `_validate_profile` error message (LOW): L854 wording "(space/quote/paren)" extended to "(space/quote/paren/newline)" to match its sibling at L866; POSIX `[[:space:]]` matches `\n` so the shorter wording was incomplete.
- CHANGELOG.md (MED): v3.51.10 was skipped during release — internal bump, no shipped changes — and is intentionally absent from this log. This note documents the gap so future readers do not assume a missing entry.
- README.md: version banner + sample log bumped to v3.51.13.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.

v3.51.12  2026-04-17
- `_RY_MANAGED_CASE_COUNT` renamed to `_RY_MANAGED_FILE_COUNT` (MED): constant counts managed destinations (16), not raw `case` branches (17 incl. wildcard).
- Drift-error line reference (MED): replaced `"Bump the constant near line 149"` with name-based reference; old form was off by 4 and drift-prone.
- Stale `--quiet` comment (LOW): L57 referenced a flag that does not exist in the arg parser; rewritten to reflect actual `-V/--verbose` semantics.
- Inline `~line N` back-references (INFO): five drifted line numbers (L132, 4611, 6084, 6095, 6195) replaced with stable anchors.
- `_log` and `_run` function descriptions trimmed (INFO): 346 and 488 chars reduced to one-sentence summaries; invariants moved to preceding `# INVARIANT:` comments.
- Standalone script comments trimmed (INFO): 24 comments over 100 chars reduced to single-sentence form; adjacent-duplicate comment pair collapsed at L5991.
- CHANGELOG.md: all verification-confirmation bullets and trailing review-trail phrases stripped; every bullet across 30 version entries trimmed to first sentence.
- Header line (INFO): banner adds ISO date `(2026-04-17)` per `header: version+date` convention; drops trailing fragment that had collapsed into the MIT license tag.
- README.md: version banner + sample log bumped to v3.51.12; event table gains `progress` row between `step_time` and `run`.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.

v3.51.11  2026-04-16
- Sourcing detection (HIGH): replaced `status is-interactive` with `status stack-trace 2>/dev/null | string match -q '*from sourcing*'` at lines 5 and 15.
- `_ry_exit` defense-in-depth (MED): namespace cleanup now runs unconditionally before both the `return` and `exit` paths.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.
- README.md: version banner bumped to v3.51.11, sample log version bumped to v3.51.11.

v3.51.9  2026-04-15
- `_acquire_lock` log PID literals (LOW): `_log "LOCK_ACQUIRED: pid=%self dir=$LOCK_DIR"` at line 377 and `_log "LOCK_RECLAIMED: stale pid=$old_pid, new pid=%self"` at line 436 embedded `%self` inside double-quoted strings.
- `%self` → `$fish_pid` consistency (LOW): 6 additional `%self` bareword uses (`_acquire_lock` at lines 371, 397, 419, 424, 466; `_sudo_keepalive` at line 4708) functionally correct but stylistically inconsistent with the `$fish_pid` use at line 99 (TIMESTAMP suffix).
- `command install -m 0600 /dev/null "$LOG_FILE"` at lines 134 and 6112 (INFO): added `--` end-of-options separator.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.
- README.md: version banner and sample log version bumped to v3.51.9.

v3.51.8  2026-04-15
- Namespace cleanup on source-bail and source-completion (MED): sourced runs now erase every `set -g` global the script created, preserving host-shell namespace.
- Redundant `2>/dev/null` removed from 4 `set --erase` call sites (LOW): `set --erase` is a no-op on missing variable names in fish 3.4+; the redirect suppressed nothing.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift.
- README.md: version banner and sample log version bumped to v3.51.8.

v3.51.7  2026-04-14
- `_ry_do_install_file` boot cascade (MED): single-file re-deploy of `/boot/*`, `/etc/mkinitcpio*`, `/etc/sdboot*`, or `/etc/kernel/cmdline` is now strict-chained and gated.
- `_ry_verify_static` installed-hash pre-serialization (MED): both `$pipestatus[1]` (cat) AND `$pipestatus[2]` (sha256sum) are now checked on the `sudo -n cat -- $dst | sha256sum | …` pipeline.
- `_ry_verify_runtime` THP enabled fallback (LOW): changed the extraction regex from `\[(\w+)\]` to `\[(\S+)\]` to mirror the `defrag` sibling branch which already uses `\S+` because `defer+madvise` contains a non-word-class character.
- README.md (LOW): version banner at line 1 bumped to v3.51.7 and sample log block `"version":"3.51.6"` at line 433 updated to `"version":"3.51.7"`.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift (all fixes are in verification/install functions, not `_ry_get_file_content`).

v3.51.6  2026-04-14
- `/etc/udev/rules.d/99-nvme-rqaffinity.rules` (LOW): widened `KERNEL==` glob from `nvme[0-9]n[0-9]` to `nvme[0-9]*n[0-9]*`. udev KERNEL matches use fnmatch(3) where `[0-9]` consumes exactly one character, so the previous form silently missed `nvme10n1` and `nvme0n10`.
- `/etc/systemd/system/cpupower-epp.service` (LOW): replaced `ConditionPathIsDirectory=/sys/devices/system/cpu` with `ConditionPathExists=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference`.
- Embedded config header comments (LOW): trimmed 4 multi-line `printf '%s\n' "#..."` header blocks in `_ry_get_file_content` to single-line form.
- CHANGELOG.md (LOW): corrected v3.51.4 release date from `2026-04-15` to `2026-04-14`.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no script structure changes.

v3.51.5  2026-04-14
- `_run` (HI): fallback branch at line 1702 now uses `command $argv` instead of bare `$argv` when `timeout(1)` is unavailable.
- `_atomic_write_file` (HI): `sudo stat -c '%F %u %a' -- "$dst_dir"` parent-dir trust check now prefixed with `LC_ALL=C`. %F is locale-sensitive ("Verzeichnis" on de_DE, "répertoire" on fr_FR) and the literal `!= directory` compare below would fail-closed on legitimate directories under non-C locales.
- `_ry_get_file_content` + `_atomic_write_file` (MED): generator now returns distinct exit codes so callers can disambiguate failure modes (rc=2 unknown destination, rc=3 missing prerequisite global like `_ROOT_UUID`, rc=4 internal arity bug).
- `_validate_profile` (MED): element sanitizer now also iterates `SYSTEM_DESTINATIONS USER_DESTINATIONS SERVICE_DESTINATIONS`, rejecting whitespace/quote/paren/newline in destination paths.
- `_ry_verify_static` hash pre-serialization (MED): pre-probes sudo ONCE before the read loop via `sudo -n true; and sudo -n -v` to extend the credential timestamp for the entire loop, minimizing the mid-loop lapse window.
- `_ry_validate_configs` Job 1 xref worker (LOW): destination list now serialized to `$val_dir/xref_dsts` and read by the child via `command cat --`, instead of being inlined into the `fish -c` argv.
- `_content_hash` + `_install_fstab_opts` (MED): standardized `$pipestatus` capture local name from `_gen_rc`/`_hash_ps` (2484, 2491) and `_awk_ps` (4972) to unified `_ps` across all three sites in this file.
- cpupower-epp.service (MED): replaced `echo performance > "$cpu" 2>/dev/null || true` with `... || logger -t cpupower-epp "EPP write failed: $cpu"` in the embedded bash `ExecStart`.
- Lint waivers (MED/LOW): added missing `# lint:ignore` comments at 1136 (systemd env-line `${VAR}`), 1063/1073 (embedded `&&` in generated config comments), 4326/4902 (awk boolean `&&`), 4655/4657 (awk `$(i+1)` field reference), and 5234/5509 (user-facing shell advice with `&&`).
- Dispatch init (LOW): chained double `set -l _init_cmd` at 6032–6033 into a single `set -l _init_cmd (_json_str (string join -- " " (status filename) $argv))`.
- README.md (HI doc drift): updated paru-missing behavior paragraph at line 256, table cell at 262, and sample log block at 432–437.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes.
- Deferred from this release: function-length decomposition for the 28 functions >50 lines (top offenders: _ry_verify_runtime 874, _ry_verify_static 580, _ry_do_check 309) — current length is justified by the parallel-worker fork pattern and per-phase positional coupling, restructure would require an outer-wrapper rewrite. mktemp consolidation into `_mktemp_tracked` helper (17 sites) — mechanical but invasive.

v3.51.4  2026-04-14
- `_content_hash` (LOW): dropped external `head -n 1` from the sha256sum parse pipeline.
- `_atomic_write_file` (LOW): mktemp tmpfile now added to `_TRACKED_TMPFILES` immediately after successful allocation.
- `_install_fstab_opts` (LOW): both `tmpfstab` and `tmpfstab2` (`sudo mktemp -p /etc .ry-install.fstab.XXXXXX`) now added to `_TRACKED_TMPFILES` immediately after successful mktemp.
- `_ry_do_check` collect loop (docs): added a comment documenting that fish's `wait` builtin returns 0 on successful wait regardless of child exit code (per fish docs: "0 if the wait was successful"), so per-pid rc capture is not feasible without an outer-wrapper pattern (see `_ry_do_test_all` for the file-based alternative).
- No version bump to README managed-file counts (still 16), no profile changes, no new dependencies.

v3.51.3  2026-04-14
- SOURCE-SAFETY (HIGH): `_cleanup`, `_cleanup_pipe`, and `_ry_exit` now gate their `exit` call behind `_RY_INSTALL_SOURCED`.
- `_install_aur_packages` + `_ry_check_deps` (MED): promoted `paru not found` from `_warn` + `return 0` to `_err` + `set -g INSTALL_HAD_ERRORS true` + `return 1` when `AUR_PKGS` is non-empty.
- `_pregenerate_content_files` (MED): writes a `<safe>.genfail` sentinel file and deletes the zero-byte expected file when `_ry_get_file_content` returns non-zero. v3.51.2 introduced the genfail pattern for `_ry_verify_static` only; this completes the coverage so preflight (`_ry_validate_configs`) and idempotency probe (`_ry_do_check`) also fail-closed on content generator bugs.
- `_ry_validate_configs` xref job + collect phase (MED): detects the `.genfail` sentinel, counts occurrences separately, and surfaces `Content generator failed for N destination(s)` as a fail with a `HASH_GENERATOR_STDERR` log pointer.
- `_ry_do_check` Job 1 hash loop (MED): checks the `.genfail` sentinel before the `test -s` skip and flips `drift=true` instead of silently continuing.
- Boot-wipe marker (MED): now stores `"<count> <sha256-of-sorted-basenames>"` instead of count-only.
- `_atomic_write_file` parent-dir trust check (MED): collapsed three independent sudo calls (`sudo test -d`, `sudo test -L`, `sudo stat -c '%u %a'`) into one `sudo stat -c '%F %u %a'` + one `sudo test -L`.
- `_run` (MED): `RY_RUN_TIMEOUT` now defaults to `3600` (60 min) when unset.
- `_pregenerate_content_files`, `_ry_check_network` (MED): added explicit fd-order comments at three `set -l _var (cmd 2>&1 >/path)` sites explaining that `2>&1 >path` duplicates fd2 to the capture pipe BEFORE fd1 is redirected.
- `_ry_validate_mkinitcpio_hooks` (LOW): added `autodetect:modconf` to the `order_checks` list. mkinitcpio requires `autodetect` to precede any hook that consumes the module list, otherwise module trimming silently does not apply and initramfs bloats.
- `_is_wifi_active_route` (LOW): falls back to `ip -6 route show default` when `ip -4` returns no default route.
- `_preflight_boot_sanity` initramfs size check (LOW): replaced `sudo du -m | cut -f1` with `sudo stat -c '%s' | math floor(/1048576)`.
- `_manifest_write` (LOW): added `or _warn` + log line on the `command chmod -- 600 "$tmp"` call.
- `_ry_do_test_all` case count (LOW): computes `_actual_cases` from `count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS` after `_load_profile` instead of awk-parsing the script source (`/^function _ry_get_file_content/{f=1} f && $1=="case"{n++} ...`).
- `_log` (LOW): docstring now spells out the "NEVER call from a parallel `fish -c` child" invariant.
- `_gather_cpu_state` (LOW): docstring now notes the symmetric-CPU assumption.
- `_run` (LOW): docstring now states the metacharacter-rejection invariant explicitly.
- Fish upper-bound warning comment (LOW): reworded to "warn on fish 5.x+" to match code (`test "$fish_major" -gt 4`).
- `_cleanup_tmpfiles` (LOW): emits a one-time `_warn` when sudo is lapsed AND the `/etc/NetworkManager/system-connections` dir exists.
- `_ry_validate_configs` (LOW): parent `wait` now captures per-pid exit status individually.
- `_install_configure_services` (LOW): added error-discipline doc block above the function.
- `_ry_get_file_content` (LOW): quoted `case /etc/kernel/cmdline` → `case "/etc/kernel/cmdline"` and `case /etc/drirc` → `case "/etc/drirc"` for quoting consistency with the other 14 case labels.
- `_install_packages` (LOW): pacman `-Syu` retry warn now points to the JSONL log for the first-pass stderr (`retrying with fresh sync (first-pass stderr in JSONL log)`).
- `_ry_do_install` (internal): `_install_aur_packages; or set -g INSTALL_HAD_ERRORS true` — explicit propagation matches the pattern used by every other pipeline phase.

v3.51.2  2026-04-14
- _ry_verify_static: content pre-generation phase now captures `_ry_get_file_content` rc and stderr.
- _validate_profile: added element sanitization for `KERNEL_PARAMS`, `MKINITCPIO_MODULES`, `MKINITCPIO_HOOKS`.
- _load_profile: `_validate_profile` failure now exits `EXIT_PREFLIGHT` (3) instead of `EXIT_USAGE` (2).
- _ry_verify_static: `string match -qr "\b$mod\b"` / `"\b$hook\b"` in the MKINITCPIO module/hook presence checks wrapped in `string escape --style=regex --`.
- _ry_do_check Job 4: positional-coupling assertion failure (exp_svcs + mask_units + implicit_svcs count mismatch) now writes a `svc_assert_fail` sentinel alongside the `svc_drift` flag.
- _preflight_boot_sanity: loader entry `linux` path validation now rejects any `..` component.
- _atomic_write_file: removed redundant post-mv `sudo chown -- root:root "$dst"`.
- _ry_mkinitcpio_array: documented `$key` trust boundary inline.

v3.51.1  2026-04-14
- _ry_verify_runtime: ext4 check else-if chain split into three independent `if` blocks.
- _install_fstab_opts: added `_check_sudo_keepalive` as first body line.
- _install_fstab_opts: awk opts rewriter now strips `strictatime` alongside `relatime`/`atime`.
- _install_fstab_opts: 5 write-path failures (mktemp, cp backup, mktemp awk target, awk/tee rewrite, findmnt --verify, atomic mv) promoted from `_warn` to `_fail`.
- _run: removed redundant `command rm -f -- "$stdout_tmp"` — the subsequent `rm -rf --preserve-root -- "$_run_dir"` already removes both stdout_tmp and stderr_tmp via the parent directory.
- LOG_FILE path construction: added cross-reference comments at both sites (init block line 114, dispatch rename ~line 5830) to prevent format-string drift.
- README: fstab atomicity sentence rewritten.
- README: sample log block version bumped 3.50.2 → 3.51.1 (was stale since v3.50.3).

v3.51.0  2026-04-14
- Kernel cmdline: amd_iommu=off → iommu=pt.
- ENV_VARS: RADV_PERFTEST=transfer_queue → RADV_EXPERIMENTAL=transfer_queue.
- ENV_VARS: dropped VKD3D_CONFIG=transfer_queue (not a documented VKD3D-Proton option, silently ignored). 12 → 11 vars.
- _install_fstab_opts: append commit=10 to ext4 entries alongside noatime,lazytime. awk rewriter strips any pre-existing commit=N. --verify-runtime fstab check extended.

v3.50.4  2026-04-13
- _ry_do_test_all: wrapped parallel worker fork (`fish -c` at the test harness call site) with `command timeout --kill-after=5 180` — was the only parallel `fish -c` site missing the timeout wrapper that the other 10 sites already carry.

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
- Comment sweep: dropped 61 low-value comment lines (narration-prefix and orphaned section refs). 6050 → 5989 lines.

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
- Net 6001 → 5983 lines (-18).

v3.48.21  2026-04-09
- Removed 4 stale --lint comments.
- _run: dropped dead /dev/null init and unreachable guards.

v3.48.20  2026-04-09
- Removed --lint mode and _ry_do_lint (~317 lines).
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
