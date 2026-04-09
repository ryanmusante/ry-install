ry-install changelog

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
