ry-install changelog

2026-04-09  Ryan Musante

- Tagged as v3.48.20
- Removed `_ry_do_lint` (~317 lines) and the `--lint` mode entirely. Rationale: self-lint was dev-time only and `fish --no-execute` (still used by `_ry_do_test_all`) plus `fish_indent -c` cover the syntax-and-style ground that mattered. The anti-pattern detectors (bash `$()`, `[[ ]]`, `&&`/`||`, `export`, `${var}`, `\`...\``, `$1`-`$9`, `unset`, dead pipes) were valuable during the bash→fish migration but have reached steady state; no new violations have been caught by the self-lint in months. Dropped: `EXIT_LINT_FAIL` constant, `--lint` help-text entry, exit-code-11 help-text entry, `--lint` completions entry, `--lint` arg-parser case, `lint` dispatch case, `--lint` from `_ry_do_test_all` parallel_modes list, `lint` from the test-all completions-content expected_cmd loop, two stale test-all comments. `# lint:ignore` inline markers scattered throughout the source are left in place — they are inert comments and removing them is a separate cosmetic pass. README Usage table, pre-flight block, exit-code table, and lint:ignore suppression note also trimmed. Net: 6331 → 6001 lines (−330).
- Removed `--restore-power-targets` mode (introduced in v3.48.16). The flag, its handler function `_ry_do_restore_power_targets`, the arg-parser case, the lock-acquire branch, the dispatch branch, the completions entry, and the help-text line are all gone. Rationale: one-shot unmask is trivially replaced by `sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target && sudo systemctl daemon-reload`, and the mode was never re-documented in the README Usage table — removing it eliminates the doc/code drift instead of papering over it.
- Audit response: 26 findings cleared (1 HIGH, 9 MED, 16 LOW). All severities driven by an exhaustive line-by-line audit of v3.48.19.
- HIGH — top-level `exit $exit_code` killed the host shell when the script was `source`d for the first time, and 9 other top-level/early-function exit sites (root check, fish version gate, `_load_profile`, `_early_usage_exit`, `--help`/`--version`/unknown-flag in arg parser, lock-acquire failures) shared the same hazard. Fix is layered: (1) duplicate-source guard at line 5 rewritten from the fragile `status is-interactive; and return 1; or exit 1` to an explicit `if/else`; (2) source-detection flag `_RY_INSTALL_SOURCED` set at the top of file; (3) new `_ry_exit` helper that exits the process when run normally and sets a global `_RY_INSTALL_BAILING` sentinel + returns when sourced; (4) every top-level `exit $X` rewritten to `_ry_exit $X; and return $X; or return $X` so the source frame returns the same code; (5) in-function exits inside `_load_profile` rewritten to `_ry_exit $X` followed by `return $X` so the bail propagates up to the top-level caller; (6) bail checkpoints (`test "$_RY_INSTALL_BAILING" = true; and return $_RY_INSTALL_LAST_EXIT`) added after the arg-parser loop iteration body, after `_load_profile`, and after the main dispatch switch so any helper-triggered bail unwinds cleanly through the source frame; (7) `_acquire_lock; or exit $EXIT_LOCK` rewritten as `_acquire_lock; or begin; _ry_exit $EXIT_LOCK; ... end` for the same reason; (8) `_RY_INSTALL_LAST_EXIT` global stashes the final exit code so the sourcing shell can inspect the result. Verified: sourcing the script with `--version`, `--help`, an unknown flag, `--lint`, and `--check` from an interactive fish all leave the host shell alive and propagate the correct exit code.
- `_ry_profile_gtr9_pro` / `_validate_profile` / `_ry_verify_runtime`: `EXPECTED_VULKAN_PKGS` is now documented as optional and the consumer block in `_ry_verify_runtime` is gated on `set -q EXPECTED_VULKAN_PKGS; and test (count ...) -gt 0`. Custom profiles that omit it get a single info line instead of a silently-disabled vulkan check.
- `_install_configure_services` package-removal reverse-dep check: `pactree -r "$pkg" | tail -n +2` rewritten as `pactree -ru "$pkg" | string match -v -- "$pkg"`. The `-r` form emits indented tree art and a `tail -n +2` strip leaves dependent-tree noise on the list, which on some pacman versions produced false-positive "has reverse dependencies — skipping" for genuinely orphan packages.
- `_ry_do_install_file` membership check: managed destinations are now also `realpath -m`-canonicalized before comparison against the canonicalized `--install-file` argument. Closes a latent failure on hosts where `/home` is a symlink (rpm-ostree, systemd-homed) where realpath would resolve the user arg to `/var/home/...` while `USER_DESTINATIONS` still held literal `$HOME/...` strings.
- `_run`: stdout/stderr capture now uses a single `mktemp -d` instead of two separate `mktemp -t` calls. Halves inode pressure under heavy parallel use, simplifies cleanup to a single `rm -rf` of the run dir, and removes the `_TRACKED_TMPFILES` self-prune dance for the pair.
- `_run` mktemp degraded path: previously degraded silently to `/dev/null` capture and continued executing. Now fails loud with `_log RUN_ABORT` + `_err` + `return 1` — silently swallowing pacman/sdboot-manage stderr was the highest-impact failure mode of the old behavior.
- `_ry_install_file` skip-unchanged probe: added `sudo -n true` precheck before reading the installed file via `sudo cat`. A lapsed keepalive previously produced an empty `_cur_hash`, failed the equality test, and re-deployed an already-correct file. Cosmetic — no data risk — but trips a write cycle on every managed file under that condition.
- `_atomic_write_file` parent-dir trust check: rewrote `if not sudo test -d ...; or sudo test -L ...` as an explicit `if/else if` flag-set + check. The `not` only bound to the first clause; intent was correct but precedence was non-obvious and a future edit could have flipped the semantics.
- Boot-wipe marker write: hoisted from `_install_rebuild_boot` (where it ran after every `sdboot-manage gen` regardless of subsequent step success) into `_install_finalize` (success path only). The marker write is also now atomic (`mktemp` → `printf` → `chmod` → `mv -f`) so a crash mid-write can't leave a zero-byte marker that the legacy-marker fallback at line 5337 silently accepts.
- Top-level `case install` dispatch: dropped the dead `else if test "$INSTALL_HAD_ERRORS" = true` branch. `_ry_do_install` already returns `$EXIT_FAIL` when `INSTALL_HAD_ERRORS=true` (line ~5594); the dispatch-side re-check was unreachable.
- Init block: `command chmod 700 "$HOME/ry-install"` is now skipped when the dir is already mode 700. Saves a stat()/chmod() pair on every invocation and prevents needless audit-log noise on hosts running file-integrity monitors.
- Init block: log file creation now hard-fails with `_early_usage_exit`-style message + `EXIT_PREFLIGHT` when both `install -m 0600` and the `touch+chmod` fallback fail. Previously left `LOG_FILE` referencing a non-existent path; subsequent `_log` calls bailed silently via `test -f "$LOG_FILE"` and the entire run executed without diagnostics.
- `_kconfig_cache`: documented the empty-cache contract (returns 0 with no output when /proc/config.gz is missing). Both callers (`_ntsync_state`, `_validate_kernel_params`) interpret no-input as "feature not enabled" — correct by design, not by accident.
- `_acquire_lock` flock reclaim block: per-line `# lint:ignore` annotations retained as-is. The audit suggested consolidating to a block-marker pair, but the lint detector's awk pre-pass (line ~4417) only understands per-line `# lint:ignore`; introducing block markers would require teaching the awk pre-pass about start/end tokens, and the per-line form is already correct and self-documenting at every line.
- `cpupower-epp.service` ExecStart: `[ -w "$cpu" ] && echo performance > "$cpu"` rewritten as `echo performance > "$cpu" 2>/dev/null || true` per cpu. The old `&&` short-circuit + trailing `exit 0` masked the rc of any genuine I/O failure; the new form lets unwritable cpus fall through cleanly without the test/check race.
- `_log` 4096-char cap: extended the JSON-escape detection regex from `\\\\[tnrbfu]?[0-9a-fA-F]{0,4}$` to `\\\\([tnrbf]|u[0-9a-fA-F]{0,4}|\\\\?)$`. Now also catches a trailing single `\\` that would otherwise orphan a literal-backslash escape on the next byte boundary.
- `_progress`: skip the bar render entirely when `tput cols` reports <60 columns. Old code formatted the bar at fixed 40-char width plus the `[NN/MM] NNN%` prefix and relied on `\r` overwrite at the next step — narrow terminals (mosh, certain serial consoles) wrapped the line and left a tail of garbage on each step transition.
- `_ry_check_network`: curl/ping stderr is now captured into `_log NETWORK: ...` lines on each failed probe. Postmortem analysis no longer has to guess between "DNS failure", "connection refused", and "TLS handshake reject".
- `_ry_check_deps`: added a comment block documenting the GNU coreutils + GNU findutils + util-linux hard dependencies (`mktemp --suffix=`, `find -printf '%T@'`, `flock(1)`). All three are present on CachyOS but Alpine/BusyBox containers will silently degrade log rotation and fail unit-syntax validation.
- `_ry_do_lint` bash-`$()` detector: added a comment cross-referencing the awk pre-pass that strips comments. The exclude regex `ExecStart|/bin/bash|...` would match keyword substrings anywhere in a line, which the awk pre-pass already prevents by zeroing out comment lines — the dependency was non-obvious.
- `_ry_do_lint` bash-`&&`/`||` detector: extended `[^&]&&[^&]` and `[^|]\|\|[^|]` to also match line-leading occurrences (`(^[0-9]+:|...)`). Coverage gap was theoretical (no current line starts with `&&`) but the inconsistency between this detector and the others (which all use the `^[0-9]+:` line-anchor form) was a maintenance hazard.
- `_ry_do_completions` mktemp: added `2>/dev/null` for consistency with the other 32 mktemp call sites.
- `_ry_do_completions` write: replaced 12 separate `>>` appends with a single `printf '%s\n' $_comp_lines >"$tmpfile"` after accumulating all lines into a fish list. ENOSPC mid-build now fails on the printf instead of being detected only by the post-write `grep -q '^end$'` heuristic.
- `README.md`: bumped H1 to v3.48.20 and JSONL example block version field to match. Added `EXPECTED_VULKAN_PKGS` to the Optional globals list (the profile global is now formally optional and `_ry_verify_runtime` skips its block when unset). Added a "Source-safe" row to the Safety & Reliability table documenting the new sourcing behavior and `$_RY_INSTALL_LAST_EXIT` global.

2026-04-09  Ryan Musante

- Tagged as v3.48.19
- `fish_indent -w`: cleared one line of formatting drift at `_test_label` that caused `--lint` mode to fail on its own source. Quoted single-char args (`'--'`, `' '`, `'/'`) inside `string replace` are stripped to bare tokens by current fish_indent; the rewrite is semantically identical.
- `_ry_do_lint` README version cross-check: rewrote the regex to grep the literal `vX.Y.Z` token instead of a non-existent shields.io `version-X.Y.Z-` badge. Previous parser silently fell through to "Could not parse README version" warn on every lint run; the version comparison was dead code.
- `README.md`: added `v3.48.19` to the H1 title so the new lint parser has a token to find. Also bumped the JSONL example block from a stale `"version":"3.48.12"` to current.
- `_pregenerate_content_files`: gate the trailing `printf '%s\n' "$out_dir"` on `_we_created_dir = true` so caller-supplied dirs no longer leak a stray line into the caller's command sub. Both current callers (2077, 3204) invoke with no arg and still get the path; latent fix for future callers that pass a dir and treat the function as void.
- `_ry_do_lint` `_output_funcs`: added missing `_log` to the alternation. The script defines 8 output helpers but the exclude list named only 7, so any future `_log "string with $(...)"` line would silently false-positive the bash-subst detector. No current trigger; contract is now closed.
- `_dir_group_or_world_writable`: extracted single helper to replace the regex-based check in `_atomic_write_file` (line 2357) and the arithmetic-based check in `_ry_verify_runtime` (line 4288). Both implementations were correct and equivalent for 3- and 4-digit modes but the duplication invited drift on future edits.
- `BOOT_WIPE_MARKER`: marker file now stores the count of `/boot/loader/entries/*.conf` files at the time of last acknowledged wipe. On subsequent runs the gate compares current count against the stored count and re-prompts (via `RY_INSTALL_CONFIRM_BOOT_WIPE=1`) if entries grew — protecting later-added rescue/Windows/custom-kernel entries from being silently deleted by a routine `--install`. Legacy empty-marker files from v3.48.18 are accepted once and rewritten with a count on the next successful gen.
- `_acquire_lock`: `echo %self >"$LOCK_FILE"` swapped to `printf '%s\n' %self` at both the initial-write site (line 335) and the fallback-reclaim site (line 383). Cosmetic; aligns with the rest of the script's discipline of `printf` over `echo` for data writes.
- `_progress` and `_progress_skip`: bar construction switched from two `for i in (seq 1 $n)` concat loops to a single `(string repeat -n $filled -- '█')(string repeat -n $empty -- '░')` builtin call. Cosmetic perf — width=40 is small enough that the loop was never measurable.

2026-04-09  Ryan Musante

- Tagged as v3.48.18
- `_ry_do_test_all`: extract `_test_label` helper called from both fork and collect sites. Previous code stripped only the leading `--` on the fork path but stripped *every* hyphen on the collect path, so `--verify-static`/`--verify-runtime`/`--test-all` wrote `verify-static.exit` etc. while the collector tried to read `verifystatic.exit` and reported false `code=999` failures on every `--test-all` run, masking real regressions in those modes.
- `_ry_do_completions` wrapper: dropped `2>/dev/null` so the function's own `_fail`/`_warn` lines (mktemp, symlink reject, syntax error, chmod, mv) reach stderr instead of being collapsed to a single generic warning.
- `_validate_user_env`: regex-escape `$var_name` via `string escape --style=regex` and add the missing `--`. Closes two latent failure modes — a name beginning with `-` would have parsed as a flag, and a name containing a regex metachar would have silently mismatched and fallen through to `printenv`, masking env drift.
- `BOOT_WIPE_MARKER`: hoisted `~/ry-install/.boot-wipe-acknowledged` to a single global. The literal was duplicated in the gate and the writer; future path changes can no longer desync the two halves.
- `_install_kernel_cmdline`: anchored the `LINUX_OPTIONS=` strip regex with `.*$` so any future trailing comment on the same line cannot leak into the captured value.
- `_ry_count_managed_cases`: replaced 8-space-literal `grep` with an awk pass keyed on `$1=="case"`. The lint at line 4406 still enforces `fish_indent --check`, but the counter is no longer coupled to indent style. Note: `awk` does not honor `--` as an end-of-options separator (unlike `sed`/`grep`/`find`); `awk PROG -- FILE` would parse `--` as a literal filename. The call site uses `awk PROG "$script_path"` directly.
- `_ry_verify_runtime` NM-connection sweep: switched `find` to `-print0 | string split0`. Theoretical only; no current `.nmconnection` filename contains a newline.
- Generated completions: `--install-file` now emits one `complete -c $cmd -l install-file -rxa '<path>'` per destination instead of joining all paths into a single space-delimited `-rxa` argument. Latent fix for any future destination path containing spaces.
- Generated completions: pre-escape single quotes in the description string before wrapping it in single quotes. None of `_comp_entries` currently contain `'`; defensive only.
- `modinfo tcp_bbr` version parse (`_bbr_ver`): added missing `--` after `string replace -r`.
- Completions version probe (`comp_ver`): switched to `string match -rg` so the capture group is read directly instead of relying on `tail -n 1` over the full-match-then-capture output.
- NM restart delay: wrapped `sleep $NM_RESTART_DELAY` in `_run` so the timing appears in the JSONL log alongside every other timed step.
- Log rotation: documented the no-`flock(1)` fallback path as best-effort with idempotent failure mode (`rm -f`); util-linux is a hard dep on Arch/CachyOS so the path is unreachable in supported environments. Added `2>/dev/null` to suppress the duplicated stderr noise on the impossible race.
- `_lint_no_bash_subst`: added a CONTRACT comment over `_output_funcs` documenting the implicit coupling to the `grep -vE` exclude alternation at line ~4429, so a future helper added without updating this set is caught in code review instead of becoming a silent false-positive.

2026-04-09  Ryan Musante

- Tagged as v3.48.17
- `_pregenerate_content_files`: switch `mktemp -d --tmpdir=/tmp` to `-t` for TMPDIR parity with the rest of the script.
- `_cleanup_tmpfiles`: sweep 0700 root-only sys dirs (e.g. /etc/NetworkManager/system-connections) via `sudo -n find` instead of unprivileged find. Collapse three near-identical sweep blocks to single-line `find -delete`.
- `_install_fstab_opts`: change awk `OFS` from `\t` to space; ext4 lines no longer mix tabs into a space-formatted fstab.
- `_install_fstab_opts`: post-rewrite check now uses `findmnt --verify` exit code instead of grepping free-form output for `error|unknown|invalid`.
- `_content_hash`: capture `$pipestatus` after the sha256sum pipeline so generator-side failures return rc=1 instead of an empty hash with rc=0.
- `_ry_do_test_all`: sudo cache is now best-effort; lint/version/help no longer abort on sudo-less hosts.
- `_ry_do_test_all`: completions content check matches `-l <flag>` form rather than the never-present `--<flag>` substring.
- Cosmetic: collapsed runs of consecutive `#` comment lines to single-line comments (36 lines removed). Embedded `/bin/sh -c` and `awk` blocks untouched.

2026-04-08  Ryan Musante

- Tagged as v3.48.16
- `SDBOOT_REMOVE_EXISTING=yes` now requires explicit ack on first run via `RY_INSTALL_CONFIRM_BOOT_WIPE=1`; subsequent runs use `~/ry-install/.boot-wipe-acknowledged` marker. Prevents silent loss of dual-boot/rescue entries.
- New `--restore-power-targets` mode unmasks the sleep/suspend/hibernate targets that install masks.
- `_atomic_write_file`: post-write hash failure messages distinguish sudo credential lapse from filesystem read error.
- Preflight: missing root UUID (findmnt failure) is now a hard `EXIT_PREFLIGHT`, not a warn.
- Preflight: dropped unused `diff`, `md5sum`, `tput` from required deps list.
- Profile: dropped diagnostic-only `iw` from PKGS_ADD (12 → 11).
- `_cleanup_tmpfiles`: NM connections sweep gated on profile actually managing NM/iwd.
- `_acquire_lock`: flock reclaim writes the PID file inside the locked subshell.
- `_load_profile`: logs INFO when defaulting to gtr9_pro.
- `_ry_verify_runtime`: WiFi state checks gated on profile managing NM/iwd.
- `_ry_verify_runtime`: clocksource HPET fail message auto-greps cached dmesg for "Marking TSC unstable".
- `/etc/drirc` generator: comment notes that `radv_enable_unified_heap_on_apu` requires Mesa ≥25.0.

2026-04-08  Ryan Musante

- Tagged as v3.48.15
- README: condensed Uninstall section. Replaced 8-step rollback block with one paragraph pointing at `~/ry-install/.manifest` and the existing Masked Services + Managed Files tables.

2026-04-08  Ryan Musante

- Tagged as v3.48.14
- README: removed v3.48.0 BREAKING blockquote from Quick Start. Removed-flag history is preserved here.

2026-04-08  Ryan Musante

- Tagged as v3.48.13
- README: documentation completeness pass. Added Uninstall section, Scope section, `paru` fallback note, fstab no-persistent-backup note, real `--check`/`--lint`/`sudo -v`/`df -h` pre-flight commands, profile required-globals tables (26 unconditional + 8 conditional), Hardware Reference moved to follow Prerequisites, Known Issues promoted to top-level, 4-step post-install verification workflow, sample NDJSON log output, exit-code disambiguation, Troubleshooting expanded 5 → 12 rows, BREAKING blockquote clarified, TOC trimmed 25 → 13 entries, badges removed.

2026-04-08  Ryan Musante

- Tagged as v3.48.12
- README BREAKING note: dropped inaccurate "all pacdiff/pacnew/pacsave handling" claim. `_install_packages` actively scans for `.pacnew`/`.pacsave` and emits `_warn` + `PACNEW_FOUND:` JSONL events.

2026-04-08  Ryan Musante

- Tagged as v3.48.11
- `_log` event classification: 7 sites used `PREFIX(parens):` form, which broke the `^[A-Z][A-Z_]*: ` event-classifier and silently fell through to `event=message`. Rewritten as `PREFIX: (parens) ...`.
- `_ry_verify_runtime`: cache `sudo dmesg` once and reuse for both Dynamic Preempt and ReBAR/SAM detection.
- `_ry_verify_runtime`: env-var absence is now WARN with a `systemctl --user import-environment` hint, not FAIL.
- `_ry_verify_static` / `_parse_systemctl_show`: all three call sites request the same 3 systemd properties (`LoadState,ActiveState,UnitFileState`) for parser symmetry.
- `_ry_verify_static`: hash collection adds explicit `sudo -n true` probe + `$pipestatus[1]` check + new `noread` state to avoid the empty-file digest masquerading as "checksum MISMATCH".
- `_ry_do_test_all`: label derivation strips only the leading `--` (preserving interior hyphens) instead of stripping all `-`.
- README profile example: added missing `AUR_PKGS` and `MKINITCPIO_COMPRESSION_OPTIONS` to optional globals list.

2026-04-08  Ryan Musante

- Tagged as v3.48.10
- `_install_packages`: post-install verification switched from `pacman -Qq` exact-match to `pacman -T` so groups, virtual packages, and providers are honored.
- `_install_preflight` sudo keepalive: child loop uses 3-attempt retry + 1s backoff around `sudo -n -v`; transient PAM/NSS failures no longer kill the loop.
- `_install_aur_packages`: single batched `paru -S --needed --noconfirm -- $AUR_PKGS` with per-package fallback on batch failure.
- `_install_configure_services` / `_ry_do_install_file`: `systemctl --user set-environment` now also requires `test -S "$XDG_RUNTIME_DIR/bus"` so TTY installs don't emit a misleading warning.
- `_ry_do_install`: `_ry_do_completions` moved inside the success branch so it skips on `EXIT_BOOT_CRIT`.
- `_manifest_write` + `_manifest_check_orphans`: completions path now tracked symmetrically.
- `_install_rebuild_boot`: reworded news-review message to reflect unattended reality.
- Top-level arg parser: 9 open-coded usage-error branches extracted to `_early_usage_exit` helper.

2026-04-08  Ryan Musante

- Tagged as v3.48.9
- `_ry_do_check` job 4 child: assertion diagnostic embedded `(count $results)` inside a double-quoted string. Rewrote with command substitution outside the quoted span.

2026-04-08  Ryan Musante

- Tagged as v3.48.8
- `_ry_verify_runtime`: assertion diagnostic embedded `(count $sys_units)` inside escape-quoted boundaries. Rewrote with command substitution outside the quoted span.

2026-04-08  Ryan Musante

- Tagged as v3.48.7
- `_content_hash`: captured `$pipestatus[1]` for generator status instead of bare `$status` (which reflected the tail `string collect`, not the generator).
- `_msg`: invalid-level branch now gated on `test -n ... ; and test -f ...` like `_log`, so it doesn't emit "No such file" if called during early init.
- `_validate_kernel_params`: stale inline comments rewritten to match the actual `param_config_map` contents.

2026-04-08  Ryan Musante

- Tagged as v3.48.6
- `_ry_verify_runtime`: THP `enabled` and `defrag` runtime checks were running glob-mode `string match` against backslash-bracket patterns, which never matched. Switched to regex mode (`-qr '\[always\]'`, `-qr '\[defer\+madvise\]'`).
- `_ry_do_test_all`: sandboxes `--completions` invocation under `HOME=(mktemp -d)` so the test mode doesn't overwrite the user's real completions file.
- CLI dispatch: `--install-file` without a path now emits an explicit usage error and exits `EXIT_USAGE` immediately.
