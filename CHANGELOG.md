ry-install changelog

v3.51.7  2026-04-14
- `_ry_do_install_file` boot cascade (MED): single-file re-deploy of `/boot/*`, `/etc/mkinitcpio*`, `/etc/sdboot*`, or `/etc/kernel/cmdline` is now strict-chained and gated. Previous form ran `_run sudo mkinitcpio -P; or _warn …` + `_run sudo sdboot-manage gen; or _warn …` + `_run sudo sdboot-manage update; or _warn …` with (a) no `and`-chaining — a failed `sdboot-manage gen` still let `sdboot-manage update` run against a half-generated loader directory, and (b) no `_preflight_boot_sanity` gate — the function returned 0 to the caller even when mkinitcpio/sdboot had failed, diverging from `_install_rebuild_boot` at line 5273 which already aborts with `EXIT_BOOT_CRIT` on the same failures. A user who ran `--install-file /etc/mkinitcpio.conf` could believe success while the system was unbootable. New form: `if not _run mkinitcpio; else if not _run gen; else if not _run update` short-circuits at the first failure, escalates `_warn` → `_err`, sets `_cascade_rc=1`, and returns `$EXIT_BOOT_CRIT` (4). On cascade success, `_preflight_boot_sanity` is invoked; any zero-byte vmlinuz/initramfs or broken loader entry returns `$EXIT_BOOT_CRIT` with "DO NOT REBOOT" surfaced to the user. Behavior parity between `--install` and `--install-file` for boot-critical configs is now enforced. Short-circuit verified via fish simulation: mkinitcpio fail skips gen+update; gen fail skips update; all-pass proceeds to sanity gate. Audit trail: MED finding 5598 + LOW finding 5600.
- `_ry_verify_static` installed-hash pre-serialization (MED): both `$pipestatus[1]` (cat) AND `$pipestatus[2]` (sha256sum) are now checked on the `sudo -n cat -- $dst | sha256sum | …` pipeline. Previous form only gated on `$_ps[1]`, so a sha256sum failure mid-pipeline (OOM, signal, coreutils bug) left a truncated/empty `installed_$safe` file and the collect-phase worker classified the destination as `noread` instead of the more accurate `read_error`. Fix mirrors the pattern already used by `_content_hash` at line 2482: capture `sha256sum` output into a local, check full pipestatus, then `string split` on the result in fish rather than piping through `head`. Write to `installed_$safe` happens only on full success; failure path routes to the `read_rc_$safe` sidecar. User-scope branch at line 3275 received the symmetric fix — same gap, same solution. Audit trail: MED finding 3280.
- `_ry_verify_runtime` THP enabled fallback (LOW): changed the extraction regex from `\[(\w+)\]` to `\[(\S+)\]` to mirror the `defrag` sibling branch which already uses `\S+` because `defer+madvise` contains a non-word-class character. Current kernels only emit word-class values (`always`, `madvise`, `never`) so no active bug, but the asymmetry is a drift risk if another code path derives from the `enabled` pattern. One-character change; no functional impact on current hosts. Audit trail: LOW finding 4250.
- README.md (LOW): version banner at line 1 bumped to v3.51.7 and sample log block `"version":"3.51.6"` at line 433 updated to `"version":"3.51.7"`. No content changes elsewhere — the three script fixes above are all in function bodies, not in user-facing flags, exit codes, managed-file counts, or profile semantics, so no other README section required sync.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no embedded-config hash drift (all fixes are in verification/install functions, not `_ry_get_file_content`). Script structure unchanged except for the three targeted patches.
- Audit: `fish --no-execute build/ry-install.fish` passes; MED-5598 cascade short-circuit verified via standalone fish simulation of all three failure paths; MED-3280 pipestatus capture verified against OK and fail cases; ppfeaturemask/HOOKS/MASK/PKGS_ADD/PKGS_DEL count invariants unchanged; `_RY_MANAGED_CASE_COUNT=16` unchanged.

v3.51.6  2026-04-14
- `/etc/udev/rules.d/99-nvme-rqaffinity.rules` (LOW): widened `KERNEL==` glob from `nvme[0-9]n[0-9]` to `nvme[0-9]*n[0-9]*`. udev KERNEL matches use fnmatch(3) where `[0-9]` consumes exactly one character, so the previous form silently missed `nvme10n1` and `nvme0n10`. Beelink GTR9 Pro ships with 2 NVMe slots max so not reachable on the target hardware, but the rule is authored once and inherited by any profile that reuses `SYSTEM_DESTINATIONS`. No functional change on single-digit controllers; removes a latent limit. Audit trail: LOW finding 1105.
- `/etc/systemd/system/cpupower-epp.service` (LOW): replaced `ConditionPathIsDirectory=/sys/devices/system/cpu` with `ConditionPathExists=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference`. Previous condition is an always-true no-op on every Linux system with CONFIG_SMP — effectively no condition at all. New condition gates on the actual EPP capability: the file only exists under `amd_pstate=active` or `intel_pstate` with HWP support, so the unit now skips silently on kernels/platforms without EPP instead of relying on the inline-bash `nullglob` to no-op. Inline bash retained for defense-in-depth against the race where sysfs disappears between condition check and ExecStart. Audit trail: LOW finding 1172.
- Embedded config header comments (LOW): trimmed 4 multi-line `printf '%s\n' "#..."` header blocks in `_ry_get_file_content` to single-line form. Affected destinations: `/etc/sdboot-manage.conf` (2→1), `/etc/mkinitcpio.conf` (2→1), `~/.config/environment.d/10-environment.conf` (2→1), `/etc/sysctl.d/99-cachyos-sysctl.conf` (3→1). Information content preserved via em-dash continuation. Rationale: the script is authored as a single-file deliverable where multi-line comment blocks in emitted output are strictly decorative and add zero semantic value to the target parsers (systemd-boot, mkinitcpio, systemd environment.d, sysctl.d) while bloating the generated files and spreading one logical statement across multiple printf calls. Single-line form is easier to diff and review in the source. v3.51.6 embedded-file hashes change for these 4 destinations — `_ry_verify_static` will flag drift on existing installs and the next `ry-install.fish` run will atomically rewrite them; no functional impact on the parsed config (all comments).
- CHANGELOG.md (LOW): corrected v3.51.4 release date from `2026-04-15` to `2026-04-14`. Dates in the v3.51.0–v3.51.5 cluster are all 2026-04-14 (rapid same-day iteration); the `2026-04-15` was a transcription typo that placed v3.51.4 temporally after v3.51.5, violating the monotonic-descending-date invariant. Audit trail: LOW finding CHANGELOG:18.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes, no script structure changes. Embedded-file hash drift for 4 of 16 managed destinations (documented above) is the only install-surface behavior change.
- Audit: all fixes are scope-local edits; `fish --no-execute` passes; no new lint:ignore waivers required; ppfeaturemask/HOOKS/MASK/PKGS_ADD/PKGS_DEL count invariants unchanged; _RY_MANAGED_CASE_COUNT=16 unchanged.

v3.51.5  2026-04-14
- `_run` (HI): fallback branch at line 1702 now uses `command $argv` instead of bare `$argv` when `timeout(1)` is unavailable. The primary branch (`command timeout --preserve-status --kill-after=10 "$_run_timeout" $argv`) was already safe because timeout(1) execs argv[0] via PATH lookup, bypassing fish's function namespace. The fallback is reached only when coreutils timeout is missing — low-probability but a future caller whose argv[0] happens to match an in-scope fish function would have recursed silently. Audit trail: HI finding 1702.
- `_atomic_write_file` (HI): `sudo stat -c '%F %u %a' -- "$dst_dir"` parent-dir trust check now prefixed with `LC_ALL=C`. %F is locale-sensitive ("Verzeichnis" on de_DE, "répertoire" on fr_FR) and the literal `!= directory` compare below would fail-closed on legitimate directories under non-C locales. This is the only `stat %F` call in the file; no sibling precedent to copy from — establishes the canonical form. Audit trail: HI finding 2489.
- `_ry_get_file_content` + `_atomic_write_file` (MED): generator now returns distinct exit codes so callers can disambiguate failure modes (rc=2 unknown destination, rc=3 missing prerequisite global like `_ROOT_UUID`, rc=4 internal arity bug). `_atomic_write_file` maps each rc to a specific user-visible error via a switch block instead of the previous generic "No content defined for: $dst" which misled diagnostics when a profile-load bug masqueraded as an unknown-destination error. Callers that treat any non-zero as failure (`_pregenerate_content_files`, `_content_hash`) are unchanged and remain correct. Audit trail: MED finding 2560.
- `_validate_profile` (MED): element sanitizer now also iterates `SYSTEM_DESTINATIONS USER_DESTINATIONS SERVICE_DESTINATIONS`, rejecting whitespace/quote/paren/newline in destination paths. Same regex as the existing `KERNEL_PARAMS MKINITCPIO_MODULES MKINITCPIO_HOOKS` loop. A newline in a destination path would corrupt the `printf '%s\n' $dsts >dst_list` serializations used by parallel workers at 962, 3307, 3409, 3419, 3421. Profile data is hardcoded in-script today; the gate catches future copy-paste errors before they reach disk. Audit trail: MED finding 832.
- `_ry_verify_static` hash pre-serialization (MED): pre-probes sudo ONCE before the read loop via `sudo -n true; and sudo -n -v` to extend the credential timestamp for the entire loop, minimizing the mid-loop lapse window. Per-destination `read_rc_$safe` sidecar file now classifies failures as `sudo_lapsed` vs `read_error`, and the collect phase surfaces the distinct reason via a switch block instead of the previous ambiguous "cannot read (sudo timestamp lapsed or file missing)". Fail-closed semantics unchanged; only diagnostics improve. Audit trail: MED finding 3258.
- `_ry_validate_configs` Job 1 xref worker (LOW): destination list now serialized to `$val_dir/xref_dsts` and read by the child via `command cat --`, instead of being inlined into the `fish -c` argv. Matches the `_ry_do_check` pattern at 3420–3429. Pattern consistency; 16-destination profile is ~800 bytes of argv vs ~2 MiB ARG_MAX so no realistic scale trigger, but the inconsistency was noise for reviewers. Audit trail: LOW finding 2195.
- `_content_hash` + `_install_fstab_opts` (MED): standardized `$pipestatus` capture local name from `_gen_rc`/`_hash_ps` (2484, 2491) and `_awk_ps` (4972) to unified `_ps` across all three sites in this file. Non-functional; improves diff readability and makes the "DO NOT insert commands between pipe and capture" invariant easier to see. Audit trail: MED finding 2462.
- cpupower-epp.service (MED): replaced `echo performance > "$cpu" 2>/dev/null || true` with `... || logger -t cpupower-epp "EPP write failed: $cpu"` in the embedded bash `ExecStart`. `|| true` silenced every per-CPU write failure; a sysfs policy change or kernel regression would have failed on all 32 cores without any user-visible signal. `logger -t` surfaces failures in the journal. Audit trail: MED finding 1168.
- Lint waivers (MED/LOW): added missing `# lint:ignore` comments at 1136 (systemd env-line `${VAR}`), 1063/1073 (embedded `&&` in generated config comments), 4326/4902 (awk boolean `&&`), 4655/4657 (awk `$(i+1)` field reference), and 5234/5509 (user-facing shell advice with `&&`). All are legitimate content flagged as false-positives by the lint scanner; bringing them into line with the existing waiver style at 379/380/381/1168/2451/3179/4264/4840/4887/4894. Audit trail: MED findings 1136/4593/4595, LOW findings 1046/1056/5172/5447.
- Dispatch init (LOW): chained double `set -l _init_cmd` at 6032–6033 into a single `set -l _init_cmd (_json_str (string join -- " " (status filename) $argv))`. Correct fish semantics in the original form (second rebinds the local in-place) but read as an accidental double-declaration on review. Audit trail: LOW finding 6032.
- README.md (HI doc drift): updated paru-missing behavior paragraph at line 256, table cell at 262, and sample log block at 432–437. Previous text said "warns and continues rather than aborting" which was stale since v3.51.3 when `_ry_check_deps` and `_install_aur_packages` were changed to emit `_err` + `INSTALL_HAD_ERRORS` + `return 1`. Sample log block now shows `event:err` with the correct message and `exit_code:1`, and all five timestamps share the same base date (was copy-paste mix of 2026-04-14 and 2026-04-08). Audit trail: HI README finding, LOW README:433 finding.
- No profile changes, no new dependencies, no managed-file count change (still 16), no kernel parameter changes.
- Deferred from this release: function-length decomposition for the 28 functions >50 lines (top offenders: _ry_verify_runtime 874, _ry_verify_static 580, _ry_do_check 309) — current length is justified by the parallel-worker fork pattern and per-phase positional coupling, restructure would require an outer-wrapper rewrite. mktemp consolidation into `_mktemp_tracked` helper (17 sites) — mechanical but invasive. Both tracked for v3.52.

v3.51.4  2026-04-14
- `_content_hash` (LOW): dropped external `head -n 1` from the sha256sum parse pipeline. Replaced `... | sha256sum | string split -- ' ' | head -n 1` with `set _hash_line (... | sha256sum); set _hash (string split ' ' -- "$_hash_line")[1]`. Eliminates one fork per hash call; functionally identical. Audit trail: LOW finding 2465.
- `_atomic_write_file` (LOW): mktemp tmpfile now added to `_TRACKED_TMPFILES` immediately after successful allocation. A SIGKILL between mktemp and any of the explicit rm-paths below previously leaked `.ry-install.XXXXXX` in the destination parent dir. The existing `_cleanup_tmpfiles` sys_dirs sweep recovered these on next run via the `.ry-install.*` glob, but explicit tracking closes the same-run window and matches the documented pattern used at all other mktemp sites. Audit trail: LOW finding 2515.
- `_install_fstab_opts` (LOW): both `tmpfstab` and `tmpfstab2` (`sudo mktemp -p /etc .ry-install.fstab.XXXXXX`) now added to `_TRACKED_TMPFILES` immediately after successful mktemp. `/etc` is in `_cleanup_tmpfiles` sys_dirs via the dirname of managed destinations (`/etc/drirc`, `/etc/mkinitcpio.conf`, etc.) so cross-run recovery already worked, but same-run leak window on crash is now closed. Audit trail: LOW findings 4850 + 4862.
- `_ry_do_check` collect loop (docs): added a comment documenting that fish's `wait` builtin returns 0 on successful wait regardless of child exit code (per fish docs: "0 if the wait was successful"), so per-pid rc capture is not feasible without an outer-wrapper pattern (see `_ry_do_test_all` for the file-based alternative). The log message for missing drift-result files was changed from `child '<phase>' crashed without writing results` to `child '<phase>' did not write results (crashed or timed out after 60s)` — neutral wording reflecting the unrecoverable ambiguity. No functional change: drift detection was already correct via missing-file = drift. Audit trail: LOW finding 3619 (RETRACTED — invalid premise; the "reference implementation" at `_ry_validate_configs` line ~2373 is latent dead code for the same reason and is NOT changed in this release, but is flagged for a future refactor to the outer-wrapper pattern).
- No version bump to README managed-file counts (still 16), no profile changes, no new dependencies.

v3.51.3  2026-04-14
- SOURCE-SAFETY (HIGH): `_cleanup`, `_cleanup_pipe`, and `_ry_exit` now gate their `exit` call behind `_RY_INSTALL_SOURCED`. When the script is sourced from an interactive fish (e.g. from `~/.config/fish/config.fish`), the three handlers (`_cleanup`, `_cleanup_pipe`, `_cleanup_on_exit`) are now erased via `functions -e` before the source frame returns. Previously any Ctrl+C / SIGPIPE / SIGTERM on the host prompt after a sourced run called the registered handler's unguarded `exit`, terminating the user's interactive fish session with exit 130/141/143. A/B runtime reproduction confirmed: pre-fix prints `[WARN] Interrupted - cleaning up...` on post-source SIGINT and kills the host; post-fix does not fire and the host shell survives.
- `_install_aur_packages` + `_ry_check_deps` (MED): promoted `paru not found` from `_warn` + `return 0` to `_err` + `set -g INSTALL_HAD_ERRORS true` + `return 1` when `AUR_PKGS` is non-empty. Previous behavior silently skipped AUR package install — on MT7925 WiFi hosts the install "succeeded" but WiFi was still broken post-reboot because `mt76-mt7925-dkms` never installed. Caller `_ry_do_install` now explicitly propagates the failure via `or set -g INSTALL_HAD_ERRORS true`.
- `_pregenerate_content_files` (MED): writes a `<safe>.genfail` sentinel file and deletes the zero-byte expected file when `_ry_get_file_content` returns non-zero. v3.51.2 introduced the genfail pattern for `_ry_verify_static` only; this completes the coverage so preflight (`_ry_validate_configs`) and idempotency probe (`_ry_do_check`) also fail-closed on content generator bugs. Previously a broken generator wrote an empty expected file that the xref job accepted via `test -e` and the hash drift check silently skipped via `test -s` + `continue`, masking real drift.
- `_ry_validate_configs` xref job + collect phase (MED): detects the `.genfail` sentinel, counts occurrences separately, and surfaces `Content generator failed for N destination(s)` as a fail with a `HASH_GENERATOR_STDERR` log pointer. Prevents preflight from passing when content generation is silently broken.
- `_ry_do_check` Job 1 hash loop (MED): checks the `.genfail` sentinel before the `test -s` skip and flips `drift=true` instead of silently continuing. Aligns `--check` with verify-static semantics.
- Boot-wipe marker (MED): now stores `"<count> <sha256-of-sorted-basenames>"` instead of count-only. Entry-set deltas (add, remove, or rename) re-prompt via `RY_INSTALL_CONFIRM_BOOT_WIPE=1`. Previous v3.51.2 format used `test -le` against the count, so manual removal of a boot entry (e.g. Windows uninstall) silently re-ack'd the wipe. Read path handles three formats: v3.51.3 count+hash (exact match), v3.51.2 count-only (legacy accept once, rewritten on first run), and empty/non-numeric (legacy accept once). Write path in `_install_finalize` emits the v3.51.3 format on the success branch.
- `_atomic_write_file` parent-dir trust check (MED): collapsed three independent sudo calls (`sudo test -d`, `sudo test -L`, `sudo stat -c '%u %a'`) into one `sudo stat -c '%F %u %a'` + one `sudo test -L`. Net: 3 → 2 sudo calls per file on the trust-check path. `sudo stat` without `-L` follows symlinks and reports the target type, so the `test -L` gate is kept to reject symlink parents — defense-in-depth is preserved.
- `_run` (MED): `RY_RUN_TIMEOUT` now defaults to `3600` (60 min) when unset. Previously unset meant "no limit" and a hung `pacman -Syu` on a slow mirror blocked the whole install indefinitely while sudo keepalive masked the hang. Set `RY_RUN_TIMEOUT=0` to explicitly opt out. --help and README updated.
- `_pregenerate_content_files`, `_ry_check_network` (MED): added explicit fd-order comments at three `set -l _var (cmd 2>&1 >/path)` sites explaining that `2>&1 >path` duplicates fd2 to the capture pipe BEFORE fd1 is redirected. Left-to-right evaluation is not obvious from the shell syntax; a future refactor that swaps the order would silently drop error diagnostics. v3.51.2 CHANGELOG documented the intent for `_ry_verify_static` only; this extends the comments to all three sites.
- `_ry_validate_mkinitcpio_hooks` (LOW): added `autodetect:modconf` to the `order_checks` list. mkinitcpio requires `autodetect` to precede any hook that consumes the module list, otherwise module trimming silently does not apply and initramfs bloats. The default profile already orders them correctly; the gate catches future profile edits.
- `_is_wifi_active_route` (LOW): falls back to `ip -6 route show default` when `ip -4` returns no default route. IPv6-only hosts on WiFi previously reported "wired" and the two callers (NM restart deferral logic in finalize and --install-file NM/iwd handler) proceeded to `sudo systemctl restart NetworkManager`, disconnecting the user mid-install. Dual-stack is typical on CachyOS so the bug was rarely triggered but real.
- `_preflight_boot_sanity` initramfs size check (LOW): replaced `sudo du -m | cut -f1` with `sudo stat -c '%s' | math floor(/1048576)`. `du -m` reports block-based disk usage with whole-MB granularity that varies by filesystem; a 99.9MB initramfs reported inconsistently as 99 or 100 depending on block size. `stat -c %s` returns exact file bytes.
- `_manifest_write` (LOW): added `or _warn` + log line on the `command chmod -- 600 "$tmp"` call. Filesystems without mode bits (FAT/exFAT `$HOME`) would previously silently leave a world-readable manifest containing the full destination-path list.
- `_ry_do_test_all` case count (LOW): computes `_actual_cases` from `count $SYSTEM_DESTINATIONS $USER_DESTINATIONS $SERVICE_DESTINATIONS` after `_load_profile` instead of awk-parsing the script source (`/^function _ry_get_file_content/{f=1} f && $1=="case"{n++} ...`). Previous implementation broke silently if `_ry_get_file_content` was ever split into helper functions.
- `_log` (LOW): docstring now spells out the "NEVER call from a parallel `fish -c` child" invariant. Parallel children in `_ry_validate_configs`, `_ry_do_check`, and `_ry_verify_static` write to their own result files; a future refactor that adds `_log` from a child would produce interleaved JSONL under concurrent writers (no advisory locking on the append).
- `_gather_cpu_state` (LOW): docstring now notes the symmetric-CPU assumption. Strix Halo (default profile target) is symmetric; asymmetric topologies (Intel P/E-core, Arm big.LITTLE) would be mis-represented by reading only the first `cpu*/cpufreq` policy.
- `_run` (LOW): docstring now states the metacharacter-rejection invariant explicitly. All callers must pass pre-expanded argv with no `[;|&\`$\n\t\r<>(){}]`; profile-derived values are validated by `_validate_profile` element sanitization.
- Fish upper-bound warning comment (LOW): reworded to "warn on fish 5.x+" to match code (`test "$fish_major" -gt 4`). Previous wording "warn on untested fish versions" was ambiguous for reviewers expecting a 4.1+ trigger.
- `_cleanup_tmpfiles` (LOW): emits a one-time `_warn` when sudo is lapsed AND the `/etc/NetworkManager/system-connections` dir exists. Silent failure previously let stale `.ry-install.*` tmpfiles accumulate across runs.
- `_ry_validate_configs` (LOW): parent `wait` now captures per-pid exit status individually. Exit 124 (timeout) is surfaced as `Validator '<phase>' timed out after 60s (not a validation failure)` with a distinct log event, instead of being indistinguishable from a real validator failure.
- `_install_configure_services` (LOW): added error-discipline doc block above the function. Sub-phase failures must set BOTH the local `_fn_err` flag AND the global `INSTALL_HAD_ERRORS=true`; the final `return 1` consumes `_fn_err` while dispatch-level checks consume `INSTALL_HAD_ERRORS`.
- `_ry_get_file_content` (LOW): quoted `case /etc/kernel/cmdline` → `case "/etc/kernel/cmdline"` and `case /etc/drirc` → `case "/etc/drirc"` for quoting consistency with the other 14 case labels. Functionally identical; prevents future bugs if a destination path acquires a shell glob character.
- `_install_packages` (LOW): pacman `-Syu` retry warn now points to the JSONL log for the first-pass stderr (`retrying with fresh sync (first-pass stderr in JSONL log)`). `_run` already captures and logs stderr via the `_log "STDERR: ..."` path; this just makes the reference explicit in user-visible output.
- `_ry_do_install` (internal): `_install_aur_packages; or set -g INSTALL_HAD_ERRORS true` — explicit propagation matches the pattern used by every other pipeline phase.

v3.51.2  2026-04-14
- _ry_verify_static: content pre-generation phase now captures `_ry_get_file_content` rc and stderr. A failed generator (empty `_ROOT_UUID`, missing profile global, unknown case branch) previously wrote an empty expected file that the worker silently folded into `skip` — a content-generator bug presented as "verification passed" for that destination. Now writes a `genfail` sentinel; worker respects the pre-written sentinel; collect phase surfaces `_fail "<dst>: content generator failed"` and logs `HASH_GENERATOR_STDERR` with the underlying error.
- _validate_profile: added element sanitization for `KERNEL_PARAMS`, `MKINITCPIO_MODULES`, `MKINITCPIO_HOOKS`. Rejects any element containing whitespace, `"`, `(`, or `)`. These globals are embedded verbatim into generated config files (`/etc/kernel/cmdline`, `/etc/sdboot-manage.conf` `LINUX_OPTIONS`, `mkinitcpio.conf` `MODULES`/`HOOKS` arrays) where a stray metachar would break the downstream parser. Profile data is hardcoded in-script today; the gate catches future copy-paste errors at preflight rather than at deploy.
- _load_profile: `_validate_profile` failure now exits `EXIT_PREFLIGHT` (3) instead of `EXIT_USAGE` (2). A profile that loaded but failed structural validation is a configuration/preflight error — `EXIT_USAGE` is reserved for the arg parser and the "Unknown profile" / "profile function not defined" paths where the user's profile *name* is the problem. Callers polling for preflight failure now see the correct code.
- _ry_verify_static: `string match -qr "\b$mod\b"` / `"\b$hook\b"` in the MKINITCPIO module/hook presence checks wrapped in `string escape --style=regex --`. A module named `amdg.pu` would have false-matched `amdgXpu` under the old form; elements containing any of `.^$*+?()[]{}\|` now compare as literals.
- _ry_do_check Job 4: positional-coupling assertion failure (exp_svcs + mask_units + implicit_svcs count mismatch) now writes a `svc_assert_fail` sentinel alongside the `svc_drift` flag. Parent collect phase reads the sentinel and surfaces `_err "Job 4 positional-coupling assertion failed: …"` with a remediation hint instead of burying the assertion in `CHECK_STDERR` JSONL only.
- _preflight_boot_sanity: loader entry `linux` path validation now rejects any `..` component. Per Boot Loader Specification (BLS), the key MUST be an ESP-relative path; an entry escaping the ESP is misconfiguration or tamper, not a valid kernel reference.
- _atomic_write_file: removed redundant post-mv `sudo chown -- root:root "$dst"`. The sudo `mktemp` at function entry already creates the tempfile as root:root and `sudo mv` preserves ownership — the chown was dead work that would only have masked a real filesystem corruption that also lied to `mv`.
- _ry_mkinitcpio_array: documented `$key` trust boundary inline. `$key` is always a literal from the fixed caller set `{HOOKS, MODULES, COMPRESSION, COMPRESSION_OPTIONS}` — never profile-derived, never user-input — so interpolation into the `grep -E` pattern is safe. Future maintainers should treat the trust assumption as a constraint on new callers.

v3.51.1  2026-04-14
- _ry_verify_runtime: ext4 check else-if chain split into three independent `if` blocks. An entry missing multiple options (e.g. both noatime and commit=10) previously reported only the first, forcing a two-pass fix cycle. Now reports every missing option per line in one pass.
- _install_fstab_opts: added `_check_sudo_keepalive` as first body line. The only v3.51.0 install phase that omitted the keepalive health probe — a dead keepalive would have been silently tolerated here where every other phase (`_install_packages`, `_install_system_files`, `_install_configure_services`, `_install_rebuild_boot`) warns.
- _install_fstab_opts: awk opts rewriter now strips `strictatime` alongside `relatime`/`atime`. Cosmetic — kernel honored `noatime` anyway per mount(8) later-wins precedence — but avoids the ugly `strictatime,noatime,...` output.
- _install_fstab_opts: 5 write-path failures (mktemp, cp backup, mktemp awk target, awk/tee rewrite, findmnt --verify, atomic mv) promoted from `_warn` to `_fail`. Severity label now matches effect (return 1 → INSTALL_HAD_ERRORS=true). The `/etc/fstab not found` skip path remains `_warn` (true soft-skip, return 0).
- _run: removed redundant `command rm -f -- "$stdout_tmp"` — the subsequent `rm -rf --preserve-root -- "$_run_dir"` already removes both stdout_tmp and stderr_tmp via the parent directory. Single-source cleanup.
- LOG_FILE path construction: added cross-reference comments at both sites (init block line 114, dispatch rename ~line 5830) to prevent format-string drift.
- README: fstab atomicity sentence rewritten. Previously claimed `/etc/fstab` was "written in-place rather than atomically" — the function actually uses tmp → awk → tmp2 → `findmnt --verify` → `sudo mv` (atomic rename). Now reads "modified outside the managed-file checksum pipeline; the rewrite itself is still atomic".
- README: sample log block version bumped 3.50.2 → 3.51.1 (was stale since v3.50.3).

v3.51.0  2026-04-14
- Kernel cmdline: amd_iommu=off → iommu=pt. Passthrough preserves IRQ remapping and DMA security on the APU while avoiding translation overhead; functionally equivalent for gaming. Param count unchanged (12).
- ENV_VARS: RADV_PERFTEST=transfer_queue → RADV_EXPERIMENTAL=transfer_queue. Mesa deprecated the PERFTEST form; EXPERIMENTAL is canonical in 26.1-dev+.
- ENV_VARS: dropped VKD3D_CONFIG=transfer_queue (not a documented VKD3D-Proton option, silently ignored). 12 → 11 vars.
- _install_fstab_opts: append commit=10 to ext4 entries alongside noatime,lazytime. awk rewriter strips any pre-existing commit=N. --verify-runtime fstab check extended.

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
