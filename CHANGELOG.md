ry-install changelog

v3.50.0  2026-04-13
- Kernel cmdline (14 → 12 params):
  * Dropped threadirqs — CachyOS kernel enables threaded IRQs by
    default; param redundant (S1).
  * Dropped initcall_blacklist=simpledrm_platform_driver_init —
    workaround no longer required on current amdgpu (S2).
- Sysctl (17 → 21 net-new tunables) (S3):
  * vm.compaction_proactiveness=0 (reduce background compaction)
  * net.core.busy_read=50, net.core.busy_poll=50 (low-latency NAPI)
  * net.core.netdev_budget=600 (raise packet budget for 10 GbE)
- Packages (PKGS_ADD 11 → 15) (S4): vulkan-radeon,
  lib32-vulkan-radeon, libva-mesa-driver, lib32-libva-mesa-driver —
  explicit RADV + VA-API for gfx1151.
- New managed file (15 → 16) (S6):
  * /etc/udev/rules.d/99-nvme-rqaffinity.rules —
    rq_affinity=2 (pin completions to submitting core).
- logind (8 → 9 ignore keys) (S7): HandleSecureAttentionKey gated
  to systemd ≥256.
- NetworkManager (S8): wifi.iwd.autoconnect=false — prevent NM/iwd
  autoconnect race.
- Verification (S9): documented Intel ice DDP firmware path
  (linux-firmware vs linux-firmware-other split).
- Comment cleanup: collapsed 8 multi-line tradeoff/contract comment
  blocks to single lines (sourcing detection, _ry_exit contract,
  _ry_call_or_bail guidance, TIMESTAMP TOCTOU race, BOOT_WIPE_MARKER
  contract, _RY_MANAGED_CASE_COUNT invariant, _kconfig_cache CONTRACT,
  _test_label invariant, footer bail checkpoint). Moved 1 inline
  trailing comment above its line. Net −20 lines (6010 → 5990).
  Zero semantic change; 76/76 functions preserved; TOCTOU, CONTRACT,
  lint:ignore markers all preserved at baseline counts.
- README: TOC replaced with numbered list including nested
  subsection bullets (35 anchors total, 15 top-level + 20 ###
  subsections under Configuration Reference, Profiles, Safety &
  Reliability, and Known Issues); License row added (was missing
  from prior bullet TOC).
- Revert: @@REVERT@@ markers S1–S4, S6–S8 in-script.

v3.49.0  2026-04-12
- Comment sweep: dropped 61 low-value comment lines (6050 → 5989). Zero
  semantic change; script behavior, output, exit codes, and embedded config
  hashes are identical to v3.48.26. Version string is the only non-comment
  line modified.
- Rules applied:
  * R4: dropped 8 bare `# §N #M:` reference comments (already captured in
    CHANGELOG history; the in-line refs were orphaned breadcrumbs).
  * R5: dropped 53 narration-prefix comments that restated the next line
    in English ("# Loop over services" above `for svc in ...`, "# Check if
    file exists" above `if test -f ...`, etc.).
- Rules NOT applied (kept in-place): R1 (`function --description`), R2
  (keep-list: TOCTOU, STIG, CVE-, §10, MAINTENANCE, AUDIT, REVERT,
  lint:ignore), R3 (tradeoff/gotcha/external-ref comments).
- Guard check: `grep -c '@@AUDIT@@\|@@REVERT@@'` before=0, after=0 — no
  audit markers touched.
- Verified: `fish --no-execute ry-install.fish` clean; 76/76 functions
  preserved; `_ry_get_file_content` byte-exact (all embedded config hashes
  unchanged).
- Context: condensation pass driven by /home/claude/ry-condense-spec. Four
  additional specs (S1 verify_runtime table dispatch −70, S3 do_check shared
  compare −6, S4 validate_configs fork helper −23) are documented but
  unapplied — they require manual surgery with per-commit verify/check
  parity testing. Two specs (S2 verify_static loop, S5 get_file_content
  printf) were evaluated and found net-negative or no-op and are permanently
  skipped. The original 5000-line target is not reachable under the
  single-file constraint (measured ceiling: 5890).

v3.48.26  2026-04-09
- `TIMESTAMP` (init block): suffixed with `$fish_pid` so concurrent instances
  running in the same second get distinct `$LOG_FILE` paths. Without the suffix,
  two concurrent read-only children under `--test-all` (each computing
  `TIMESTAMP` via second-precision `date(1)` as it re-runs the init block) could
  race on the pre-rename `install-$TIMESTAMP.jsonl` path: the loser's
  `install -m 0600 /dev/null` would truncate the winner's profile-load log
  lines, and the loser's subsequent mode-specific rename (`mv install-T.jsonl
  check-T.jsonl`) would fail because the winner had already moved the source
  file away. The window is narrow (milliseconds, bounded by init → arg-parse →
  `_load_profile` → rename) and only reachable via `--test-all`, but the race
  is real and the fix is one line. Audit trigger: execution-flow review on
  v3.48.25.
- `_ry_verify_static`: hash_dir mktemp early-return path (line ~3153) now
  calls `_verify_summary` before returning so the CI-parseable
  `VERIFY:FAIL:N:M:W` line is always emitted on stdout, matching the contract
  of the non-early-return path. Also switched the error reporter from `_err`
  (which does not increment `VERIFY_FAIL`) to `_fail` (which does), so the
  summary reflects the infrastructure failure.
- `_ry_verify_runtime`: `sys_units` count-drift assertion path (line ~3908)
  got the same treatment — calls `_verify_summary` before returning and uses
  `_fail` instead of `_err` + manual `VERIFY_FAIL` increment. Removes the
  one-off counter-mutation pattern that drifted from the rest of the
  verification code. Audit trigger: same execution-flow review; both
  early-return paths violated the VERIFY: stdout-line contract.
- No user-visible behavior change beyond the two verify-mode contract fixes
  (CI pipelines that grep stdout for `VERIFY:` will now see the line on
  mktemp/assertion failures where they previously saw only the exit code).

v3.48.25  2026-04-09
- `_run`: tightened `RY_RUN_TIMEOUT` validation regex from `^\d+$` to
  `^[1-9]\d*$`. Rejects `RY_RUN_TIMEOUT=0`, which `timeout(1)` treats as
  "no limit" and would otherwise produce a silent no-op wrap (user sets
  timeout, expects bounded execution, gets none). Also rejects empty and
  leading-zero forms. Positive integers ≥1 only.
- `_ry_show_help`: added an `ENVIRONMENT:` section documenting
  `RY_RUN_TIMEOUT` (new in v3.48.24) and `RY_INSTALL_CONFIRM_BOOT_WIPE`
  (pre-existing but never surfaced in help). Both env vars were previously
  source-only — readable by anyone who opened the script but invisible to
  `./ry-install.fish --help`. Help text stays stderr-only and free of any
  new stdout producers.
- `README.md`: added `### Environment Variables` subsection under
  `## Safety & Reliability`, documenting `RY_RUN_TIMEOUT`,
  `RY_INSTALL_CONFIRM_BOOT_WIPE`, and `NO_COLOR` (also pre-existing but
  previously undocumented in user-facing docs). Table format matches the
  existing Exit Codes / Data Directory tables.
- Documentation-only fixes aside from the one-line regex tighten.
  No functional changes to execution flow, options parsing, stdout/stderr
  discipline, logging, verification, or parallel worker machinery.
- Post-v3.48.24 audit delta: all three v3.48.23 findings remain resolved.
  Three v3.48.24 nits (undocumented env var × 2, too-loose regex)
  closed by this release. No blocking issues.
- Verified: `fish --no-execute` clean, `./ry-install.fish --help` shows
  new ENVIRONMENT section, regex rejects `RY_RUN_TIMEOUT=0` / `""` /
  `"-5"` / `"1.5"` / `"01"` and accepts `1`, `60`, `1800`.
- Net 6023 → 6039 lines (+16, all doc/comment).


v3.48.24  2026-04-09
- `_run`: added `</dev/null` on the command exec line. Closes a hang class
  where any caller that would otherwise probe the terminal (stray sudo
  password prompt after keepalive lapse, pacman confirm on a malformed
  package set) would block forever with no interrupt path beyond the signal
  handler. Previously masked only by upstream `sudo -n` + `--noconfirm`
  discipline; now defense-in-depth at the exec site.
- `_run`: added opt-in wall-clock timeout via `RY_RUN_TIMEOUT` env var.
  Default unset = legacy behavior preserved. When set to a positive integer
  and `timeout(1)` is available, wraps the exec in
  `command timeout --preserve-status --kill-after=10 $RY_RUN_TIMEOUT`.
  Recommended value for unattended installs: `RY_RUN_TIMEOUT=1800` (30 min,
  covers worst-case `pacman -Syu` on a slow mirror). `timeout(1)` is part of
  GNU coreutils and therefore a hard dep on Arch/CachyOS; the `command -q`
  guard is purely defensive.
- Parallel workers: wrapped 10 `fish -c` background jobs with
  `command timeout --kill-after=5 60`. Sites:
  `_ry_validate_configs` jobs 1–5 (xref, systemd unit syntax, fish syntax +
  environment.d, INI headers, simple key-value) and `_ry_verify_static` +
  `_ry_do_check` jobs (hash workers, permissions, kernel params, services).
  Closes the hang class where a stuck `systemd-analyze verify` on a
  malformed socket, or a syscall stall inside `sha256sum`, would block the
  parent `wait` forever. Parent collection already treats missing
  `*.errors` / `*_drift` result files as "child crashed without writing
  results" → timeout-killed workers slot cleanly into the existing
  fail-closed path, no parent-side changes required.
- Deliberately NOT wrapped: `_install_preflight` sudo keepalive loop (must
  run for entire install duration) and `_ry_do_test_all` per-mode runner
  (invokes full ry-install subprocesses that carry their own guards).
- `_atomic_write_file`: classify post-write hash mismatch. When the
  expected/actual hash comparison fails, re-probe `sudo -n true` to
  distinguish a real content mismatch from a sudo credential lapse between
  the existing pre-probe (`sudo -n true`) and the actual `sudo -n cat`
  microseconds later. A lapsed `cat` produces an empty pipe → `sha256sum`
  of nothing → canonical `e3b0c442...` (non-empty), which slipped past the
  `test -z "$_actual_hash"` check and surfaced as "post-write checksum
  mismatch". Users would then debug content generation instead of the real
  cause (sudo timestamp expiry). New branch emits "sudo credential lapsed
  mid-verify" and logs `HASH_UNAVAILABLE_POST` with the accurate reason.
  Preserves the existing trailing-newline invariant (no command
  substitution on content — would strip trailing newlines and poison
  subsequent hash compares).
- Audit methodology: execution flow + options + stdout/stderr + logging +
  verification + shells/subshells review across all 5999 lines. 5
  candidate findings, 3 confirmed actionable, 1 downgraded to
  informational (`_log` append atomicity is guaranteed by ext4/btrfs
  `i_rwsem` inode lock on the target filesystem, not by the mistaken
  `4096 == PIPE_BUF` rationale — only a concern if `LOG_FILE` ever lands
  on NFS), 1 withdrawn (`--install-file --` edge case — the existing
  `-*` branch in the install-file parser rejects it correctly).
- Verified: `fish --no-execute` clean, `command timeout --kill-after=5 60`
  + `--preserve-status` semantics confirmed in isolation (normal=0,
  timeout-kill=124, preserve-status-kill=143). Runtime test deferred to
  the CachyOS host; run `./ry-install.fish --check` and `--verify-static`
  before the next full `--install`.
- Net 5999 → 6023 lines (+24).


v3.48.23  2026-04-09
- `_ry_do_test_all`: added managed-case count drift assertion. Runs `awk`
  over `_ry_get_file_content` to count `case` branches and compares against
  the `_RY_MANAGED_CASE_COUNT` constant (used as the `_ry_show_help`
  fallback since v3.48.22). On mismatch: `[ERR]` with exact counts + line
  reference, `return 1` before forking parallel sub-tests. Moves the
  drift-catch from "self-parsing awk on every --help invocation"
  (v3.48.19) to "one awk pass in the test suite" (v3.48.23) — production
  --help stays awk-free and zero-subprocess, while a forgotten constant
  bump is caught at release time instead of by end users.
- Verified both paths: PASS on 15=15, `[ERR]` + `exit 1` on forced 16→15
  mismatch.

v3.48.22  2026-04-09
- Removed `_ry_count_managed_cases` (11 lines, awk-self-parse). Replaced
  with compile-time constant `_RY_MANAGED_CASE_COUNT=15` used as the
  `_ry_show_help` fallback when --help runs before `_load_profile`. Bump
  by hand if you add/remove a case in `_ry_get_file_content`.
- Removed `_get_boot_time` (11 lines, single caller in `_ry_verify_runtime`).
  Inlined at the call site, reusing the already-captured `$boot_time` line
  from the `systemd-analyze` call three lines above — saves one redundant
  `systemd-analyze` spawn per `--verify-runtime` run. Also clears the
  v3.48.20 audit finding about `math "$total_sec"` wrapping an already-
  numeric value.
- Merged `_progress_skip` (23 lines) into `_progress` with an optional
  `skip` second positional. Single caller in `_ry_do_install` updated:
  `_progress_skip Finalize` → `_progress Finalize skip`. Eliminates ~60%
  shared-code duplication between the two functions.
- Incidental fix: `_progress` bar rendered as `[]` at 100% (and 0%).
  `string repeat -n 0` exits 1 in fish, which erases the entire adjacent
  command substitution `(string repeat -n $filled ...)(string repeat -n
  $empty ...)`. Each segment is now built conditionally. Pre-existing bug
  since the v3.48.19 string-repeat rewrite.
- Fixed misattached `# Sweep /tmp for ry-*` comment: was stranded above
  `_write_footer` since some earlier refactor, belongs above
  `_cleanup_tmpfiles`.
- Net 6001 → 5983 lines (−18). Function count 79 → 76.

v3.48.21  2026-04-09
- Polish: removed 4 stale `--lint` comments (910, 1607, 5604, 5922).
- `_run`: dropped dead `/dev/null` init and unreachable `!= /dev/null` guards.

v3.48.20  2026-04-09
- Removed `--lint` mode and `_ry_do_lint` (~317 lines). Dropped
  `EXIT_LINT_FAIL`, help/completions/arg-parser/dispatch/test-all entries.
  Net 6331 → 6001.
- Removed `--restore-power-targets` mode (added v3.48.16, never documented).
- HIGH audit fix: top-level `exit` killed host shell on `source`. New
  `_ry_exit` helper + `_RY_INSTALL_BAILING` sentinel + `_RY_INSTALL_SOURCED`
  flag; all top-level exits rewritten; bail checkpoints after arg parser,
  `_load_profile`, dispatch; `_RY_INSTALL_LAST_EXIT` for sourcing shell.
- `EXPECTED_VULKAN_PKGS` now optional; verify-runtime gates on `set -q`.
- `_install_configure_services`: `pactree -r | tail -n +2` →
  `pactree -ru | string match -v` (old form false-flagged orphans).
- `_ry_do_install_file`: `realpath -m` managed dests (fixes `/home` symlink
  hosts — rpm-ostree, homed).
- `_run`: single `mktemp -d` for stdout/stderr pair; degraded path fails
  loud instead of swallowing stderr.
- `_ry_install_file`: `sudo -n true` precheck before skip-unchanged probe.
- `_atomic_write_file`: parent-dir trust check rewritten as explicit
  `if/else if`.
- Boot-wipe marker: hoisted into `_install_finalize` success path; atomic
  write via `mktemp → printf → chmod → mv -f`.
- Init: skip `chmod 700` when already correct; hard-fail `EXIT_PREFLIGHT`
  if both log-file creation paths fail.
- `cpupower-epp.service`: `[ -w ] && echo` → `echo > "$cpu" 2>/dev/null
  || true` (old form masked I/O failures).
- `_log` cap: JSON-escape regex catches trailing single `\\`.
- `_progress`: skip bar render when `tput cols < 60`.
- `_ry_check_network`: curl/ping stderr → `_log NETWORK:`.
- `_ry_do_completions`: 12 `>>` appends → single `printf >` write.
- README: v3.48.20; `EXPECTED_VULKAN_PKGS` optional; Source-safe row added.

v3.48.19  2026-04-09
- `fish_indent -w`: drift at `_test_label`.
- `_pregenerate_content_files`: gate trailing echo on `_we_created_dir`.
- `_dir_group_or_world_writable`: single helper replaces regex/arithmetic
  duplicates.
- `BOOT_WIPE_MARKER`: stores entry count; re-prompts if entries grew.
- `_acquire_lock`: `echo` → `printf '%s\n'`.
- `_progress`: bar via `string repeat`.

v3.48.18  2026-04-09
- `_ry_do_test_all`: extract `_test_label`. Collect path stripped every
  hyphen vs fork's leading-`--` only → false `code=999` on every run.
- `_ry_do_completions`: dropped `2>/dev/null` wrapper.
- `_validate_user_env`: regex-escape `$var_name`; missing `--`.
- `BOOT_WIPE_MARKER`: single global.
- `_install_kernel_cmdline`: anchor `LINUX_OPTIONS=` strip with `.*$`.
- `_ry_count_managed_cases`: literal grep → awk `$1=="case"`.
- `_ry_verify_runtime` NM sweep: `find -print0 | string split0`.
- Completions: `--install-file` one entry per dest; escape `'` in
  descriptions; `modinfo tcp_bbr --`; version probe `string match -rg`.
- NM restart delay: wrapped in `_run`.
- Log rotation: no-`flock(1)` fallback documented.

v3.48.17  2026-04-08
- `_pregenerate_content_files`: `mktemp -d --tmpdir=/tmp` → `-t`.
- `_cleanup_tmpfiles`: sweep 0700 root dirs via `sudo -n find`.
- `_install_fstab_opts`: awk `OFS` → space; post-rewrite via
  `findmnt --verify` exit code.
- `_content_hash`: capture `$pipestatus` for generator failures.
- `_ry_do_test_all`: sudo cache best-effort; completions match `-l <flag>`.
- Cosmetic: collapsed `#` comment runs (-36 lines).

v3.48.16  2026-04-08
- `SDBOOT_REMOVE_EXISTING=yes` requires explicit ack via
  `RY_INSTALL_CONFIRM_BOOT_WIPE=1`; marker at
  `~/ry-install/.boot-wipe-acknowledged`.
- New `--restore-power-targets` (removed v3.48.20).
- `_atomic_write_file`: post-write hash fail distinguishes sudo lapse
  from fs error.
- Preflight: missing root UUID → `EXIT_PREFLIGHT`; dropped
  `diff`/`md5sum`/`tput` from deps; dropped `iw` from `PKGS_ADD` (12→11).
- `_acquire_lock`: flock reclaim writes PID inside locked subshell.
- `_load_profile`: INFO on gtr9_pro default.
- `_ry_verify_runtime`: WiFi checks gated on profile; HPET fail auto-greps
  dmesg for "Marking TSC unstable".
- `/etc/drirc`: comment for Mesa ≥25.0 requirement on
  `radv_enable_unified_heap_on_apu`.

v3.48.6–v3.48.15  2026-04-08  (historical — `[.N]` = v3.48.N)
- `SDBOOT_REMOVE_EXISTING=yes` requires `RY_INSTALL_CONFIRM_BOOT_WIPE=1`
  ack; marker at `~/ry-install/.boot-wipe-acknowledged`.            [.16]
- New `--restore-power-targets` mode (removed v3.48.20).            [.16]
- `_atomic_write_file`: post-write hash fail distinguishes sudo lapse
  from fs error.                                                    [.16]
- Preflight: missing root UUID is `EXIT_PREFLIGHT`; dropped
  `diff`/`md5sum`/`tput` from deps; dropped `iw` from `PKGS_ADD`.    [.16]
- `_acquire_lock`: flock reclaim writes PID inside locked subshell. [.16]
- `_load_profile`: INFO on gtr9_pro default.                        [.16]
- `_ry_verify_runtime`: WiFi checks gated on profile; HPET fail auto-
  greps dmesg for "Marking TSC unstable".                           [.16]
- `/etc/drirc`: Mesa ≥25.0 note on `radv_enable_unified_heap_on_apu`.[.16]
- README: Uninstall → paragraph; removed v3.48.0 BREAKING blockquote;
  dropped inaccurate pacdiff claim.                             [.12,14,15]
- README completeness pass: Uninstall, Scope, `paru` fallback, fstab
  no-backup, pre-flight commands, profile globals, NDJSON sample,
  Troubleshooting 5→12, TOC 25→13, badges removed.                  [.13]
- `_log` classifier: `PREFIX(parens):` → `PREFIX: (parens) ...`
  (7 sites fell through to `event=message`).                        [.11]
- `_ry_verify_runtime`: cache `sudo dmesg` once; env-var absence WARN
  not FAIL.                                                          [.11]
- `_ry_verify_static`: hash collection adds `sudo -n true` probe +
  `$pipestatus[1]` + `noread` state.                                 [.11]
- `_ry_do_test_all`: label preserves interior hyphens.               [.11]
- README: `AUR_PKGS`, `MKINITCPIO_COMPRESSION_OPTIONS` optional.      [.11]
- `_install_packages`: `pacman -Qq` → `pacman -T`.                   [.10]
- Sudo keepalive: 3-attempt retry + 1s backoff.                      [.10]
- `_install_aur_packages`: batched `paru -S --needed` + per-pkg
  fallback.                                                          [.10]
- `systemctl --user set-environment`: gated on
  `-S $XDG_RUNTIME_DIR/bus`.                                         [.10]
- `_ry_do_install`: `_ry_do_completions` inside success branch.      [.10]
- Manifest: completions tracked.                                     [.10]
- Top-level arg parser: 9 error branches → `_early_usage_exit`.      [.10]
- `_ry_do_{check,verify_runtime}`: `(count ...)` moved outside quoted
  assertion strings.                                              [.8,.9]
- `_content_hash`: `$pipestatus[1]` for generator (bare `$status`
  tracked tail `string collect`).                                     [.7]
- `_msg`: invalid-level branch gated like `_log`.                     [.7]
- `_validate_kernel_params`: stale comments updated.                  [.7]
- `_ry_verify_runtime` THP: `string match` glob → regex.              [.6]
- `_ry_do_test_all`: `--completions` sandboxed under
  `HOME=(mktemp -d)`.                                                 [.6]
- CLI: `--install-file` without path → `EXIT_USAGE`.                  [.6]
