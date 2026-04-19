ry-install changelog

v4.1.3  2026-04-19
- `_tmpfile_key` (L1319): new helper prepends 8-char sha256 prefix to destination path; replaces naive `string replace -a '/' '_'` at 7 sites. Closes latent `/` vs `_` collision trap.
- CLI dispatcher: manual `while/switch` → `argparse --exclusive=verify-static,verify-runtime,check,install-file` (L5795). Parity preserved across 13 flag scenarios.
- `_write_footer`: dropped redundant `finished` field (duplicate of `ts`).
- `_ry_verify_static`: `implicit_svcs` derived from `SYSTEM_DESTINATIONS` path match; no longer hardcoded.
- `_ry_validate_configs`: prune `$val_dir` + `$content_dir` from `_TRACKED_TMPFILES` after `rm -rf`.
- `_preflight_boot_sanity`: BLS path-traversal check now exact-segment match, not substring; accepts `kernel..custom`.
- Timestamp init: one combined `date` call split into two; eliminates `%Y` duplication.
- Exit-propagation: 6 `_load_profile` sites normalized to triple-form `_ry_exit $CODE; and return $CODE; or return $CODE`.
- Line: 5994 → 6026. README version banner + sample log bumped.

v4.1.2  2026-04-19
- `_install_preflight` sudo-tag regex: `\b!PASSWD\b` / `\b!SETENV\b` failed to anchor (leading `!` is non-word). Fix: `(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)` — anchor only `\b`-compatible ends.
- `_ry_do_install`: manifest-write decoupled from `INSTALL_HAD_ERRORS`; failure now logs `MANIFEST_WRITE_FAILED` only.
- `_install_rebuild_boot`: `sdboot-manage update` failure elevated to EXIT_BOOT_CRIT (symmetric with `gen`).
- Unattended `-Syu` gated behind `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1`; without ack prints 3 headlines/feed from arch/cachyos RSS.
- `_ry_show_help`: ENVIRONMENT documents `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE`.
- `_write_footer`: LOG_FILE existence check wrapped in `begin; …; end; or return 0`.
- `_acquire_lock`: quoted `"$fish_pid"` in `sh -c` positional args.
- `_do_cleanup`: `printf '%s\n'` replaces `echo` for TMPDIR fallback.
- `_run` stderr dedup: `head -n 10000` cap on multi-MB stderr storms.
- `_ry_check_deps`: `flock(1)` re-classified HARD → SOFT (fallback exists).
- Line: 5970 → 5994. README: `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE` row added.

v4.1.1  2026-04-19
- `_cleanup`: fish 3.4+ passes SIG-prefixed name as `$argv[1]`; added `case HUP SIGHUP`, `INT SIGINT`, `QUIT SIGQUIT`, `TERM SIGTERM` — exit codes 129/130/131/143 correctly distinguished (were all falling through to 130).

v4.1.0  2026-04-19
- Removed `--test-all` (169 L) and `--completions` (93 L + autoinstall/verify). Pre-commit `fish --no-execute` supersedes the former; README is authoritative for the latter.
- `_ry_show_help`: 72 → 49 lines; EXIT CODES condensed; EXAMPLES/LOG FILE/REQUIREMENTS/NOTES dropped.
- 78 → 75 fns. Line: 6301 → 5970.

v4.0.4  2026-04-19
- Comment-only pass: all multi-line `#` blocks collapsed; 47 long comments trimmed to <120 chars.
- `fish_indent` canonical pass: quote-strip 3 literal `case` labels; 5 `wait/set -l _rc $status` one-liners split per canonical output.

v4.0.3  2026-04-19
- Hash pipelines at 8 sites: `cat | sha256sum | string split` captured only final value; empty-stdin SHA (`e3b0c44…`) could mask cat failure. Fix: capture raw line, snapshot `$pipestatus`, guard on `_ps[1]=0; and _ps[2]=0`.
- `_content_hash`: check `pipestatus[2]` on `string collect` (OOM defense).

v4.0.2  2026-04-19
- `_ry_verify_static`: terminal `case '*'` catch-all in result switch; partial-write payloads no longer silently skip.
- `_ry_verify_static` hash workers: per-pid `wait` captures timeout sentinels 124/137/143 (batch `wait` masked all but last).
- `_cleanup`, `_cleanup_pipe`: entry reentrancy guard matches `_cleanup_on_exit`.
- `_ry_namespace_cleanup`: `HOME` added to `_preserve`; source-exit with empty caller HOME no longer reverts.
- `_ry_do_install_file`: `--` separator on 2 single-unit sites (matches batch pattern).

v4.0.1  2026-04-19
- `_install_fstab_opts`: `sudo chmod/chown --reference=/etc/fstab` before `findmnt --verify` and mv; prevents 0644 → 0600 regression from `sudo mktemp` default.
- Log subdirs: `mkdir` under `umask 0077`; chmod 700 repair for looser-umask dirs from older runs.
- `_ry_do_install_file` post-deploy: added branches for `sysctl.d`, `coredump.conf.d`, `environment.d`, `/etc/drirc`.
- `_run`: invalid `RY_RUN_TIMEOUT` → one-shot `_warn` + fallback to 3600 (no longer silently disables).
- Parallel child timeout detection: `contains -- "$_phase_rc" 124 137 143`.
- 11 `fish -c` sites: added `--preserve-status` to `command timeout` wrapper.
- `_do_cleanup` /tmp sweep: extra `-mindepth 2 -maxdepth 2` pass reaps `_run` scratch dirs.
- `_validate_profile`: `PKGS_ADD/DEL/AUR_PKGS` sanitized against pacman naming grammar.

v4.0.0  2026-04-18
- KERNEL_PARAMS 12 → 15; SYSCTL_VALUES 21 → 19; PKGS_ADD 15 → 14; EXPECTED_SERVICES 3 → 4; new dep: `nftables`.
- Added `amd_pstate=active` (forces amd_pstate_epp driver).
- RADV env: `RADV_EXPERIMENTAL=transfer_queue,hic`, new `RADV_PERFTEST=sam,nircache`.
- `nftables` firewall baseline restored (closes gap from `ufw` removal).
- `clocksource=tsc` → `tsc=reliable`.
- Removed `nvme_core.default_ps_max_latency_us=0`; NVMe APST check flipped to regression detector.
- Removed `fs.inotify.max_user_watches=524288` (kernel auto-scales).
- Added `net.ipv4.tcp_notsent_lowat=131072`.
- Added `systemd-coredump.socket` to MASK.
- `RESOLVED_MDNS`: `no` → `resolve` (fixes `.local` under COSMIC).
- Added `loglevel=3`, `rd.udev.log_level=3`, `rd.systemd.show_status=auto`.
- Removed `net.core.somaxconn=8192`, `kernel.unprivileged_bpf_disabled=1`.
- drirc: Mesa requirement `≥25.0` → `≥22.3` (MR !18884 landed Sep 2022).
- MKINITCPIO_MODULES: `amdgpu nvme` → `amdgpu`.
- Removed `irqbalance.service` from MASK.
- Removed `vulkan-radeon` + `lib32-vulkan-radeon` from PKGS_ADD (chwd auto-installs).
- README: "Deprecated flags — DO NOT re-introduce" subsection.

v3.51.15  2026-04-17
- `_install_configure_services`: removed dead `display_list` + `first_five` subshell.
- 31 comments stripped of `v3.51.N:` / `Fix N:` / temporal prefixes.
- 77 fns, 40 globals, zero unused locals.

v3.51.14  2026-04-17
- 2 multi-line `#` blocks collapsed.
- 8 `printf '%s\n'` blocks in `_ry_get_file_content` collapsed to single multi-arg calls (byte-identical output, ~39 lines saved).
- `_ry_show_help`: ENVIRONMENT + NOTES consolidated.

v3.51.13  2026-04-17
- `_install_configure_services` pactree rdep check: filters sibling `$PKGS_DEL` members before count — fixes plymouth/micro base-pkg skip.
- `_detect_lvm` helper: extracts 3 identical `timeout 5 sudo -n pvs` probes; fixes missing `command` prefix.
- `_kill_sudo_keepalive`: SIGTERM → `sleep 0.1` → SIGKILL escalation.
- `_validate_profile` L854: error message adds `newline` to forbidden chars list.

v3.51.12  2026-04-17
- `_RY_MANAGED_CASE_COUNT` → `_RY_MANAGED_FILE_COUNT`.
- 5 drifted `~line N` back-references replaced with stable anchors.
- `_log`, `_run` descriptions trimmed to one sentence; invariants moved to `# INVARIANT:` prefix comments.
- 24 comments over 100 chars reduced to single sentence; adjacent-duplicate pair at L5991 collapsed.
- README: `progress` row added to event table.

v3.51.11  2026-04-16
- Sourcing detection: `status is-interactive` → `status stack-trace | string match -q '*from sourcing*'`.
- `_ry_exit`: namespace cleanup runs unconditionally before return/exit.

v3.51.9  2026-04-15
- `_acquire_lock` + keepalive: `%self` → `$fish_pid` at 8 sites.
- `command install -m 0600 /dev/null $LOG_FILE` at 2 sites: added `--`.

v3.51.8  2026-04-15
- Sourced runs: namespace cleanup erases every script-set `set -g`, preserving host-shell namespace.
- 4 `set --erase` sites: dropped redundant `2>/dev/null` (no-op in fish 3.4+).

v3.51.7  2026-04-14
- `_ry_do_install_file` boot cascade: strict-chained and gated.
- `_ry_verify_static`: both `$pipestatus[1]` (cat) AND `$pipestatus[2]` (sha256sum) checked.
- `_ry_verify_runtime` THP fallback: regex `\[(\w+)\]` → `\[(\S+)\]` (matches `defer+madvise`).

v3.51.6  2026-04-14
- `_ry_verify_runtime`: NVMe rq_affinity accepts kernel-managed value 2 in addition to script-written 1.
- `_ry_check_deps`: `timeout` promoted SOFT → HARD.

v3.51.5  2026-04-14
- `_ry_validate_mkinitcpio_hooks`: explicit `order_checks` — `autodetect` must precede `modconf`, `kms`, `block`, `filesystems`.
- `_ry_verify_runtime`: HPET disable check auto-scans `dmesg | grep 'Marking TSC unstable'` on fail.
- `_install_configure_services`: batch-then-retry on `systemctl enable --now` failure.
- Profile-aware iwd/NM restart in `_install_finalize`.

v3.51.4  2026-04-14
- `_content_hash`: dropped external `head -n 1` from sha256sum parse.
- `_atomic_write_file`, `_install_fstab_opts`: mktemp tmpfile tracked immediately after allocation.

v3.51.3  2026-04-14
- Source-safety: `_cleanup`, `_cleanup_pipe`, `_ry_exit` gate `exit` behind `_RY_INSTALL_SOURCED`.
- `_install_aur_packages` + `_ry_check_deps`: `paru not found` → `_err` + `INSTALL_HAD_ERRORS=true` + `return 1` when AUR_PKGS non-empty.
- `_pregenerate_content_files`: writes `<safe>.genfail` sentinel on generator rc != 0.
- `_ry_validate_configs` + `_ry_do_check`: detect `.genfail` sentinel; flip drift/errors.
- Boot-wipe marker: stores `"<count> <sha256-of-sorted-basenames>"`.
- `_atomic_write_file` parent-dir trust: 3 sudo calls → single `sudo stat -c '%F %u %a'` + `sudo test -L`.
- `_run`: `RY_RUN_TIMEOUT` defaults to 3600 when unset.
- `_is_wifi_active_route`: falls back to `ip -6 route show default`.
- `_preflight_boot_sanity` initramfs size: `du -m | cut -f1` → `stat -c '%s' | math floor(/1048576)`.
- `_ry_get_file_content`: `case /etc/kernel/cmdline` + `case /etc/drirc` quoted for consistency.

v3.51.2  2026-04-14
- `_ry_verify_static`: content pre-gen captures rc + stderr.
- `_validate_profile`: element sanitization for KERNEL_PARAMS, MKINITCPIO_MODULES/HOOKS.
- `_load_profile`: validation failure → EXIT_PREFLIGHT (was EXIT_USAGE).
- `_ry_verify_static`: `string escape --style=regex` on MKINITCPIO checks.
- `_ry_do_check` Job 4: positional-coupling assertion writes `svc_assert_fail` sentinel.
- `_preflight_boot_sanity`: loader `linux` path rejects any `..` component.

v3.51.1  2026-04-14
- `_ry_verify_runtime`: ext4 else-if split into 3 independent `if` blocks.
- `_install_fstab_opts`: `_check_sudo_keepalive` as first body line; awk strips `strictatime`; 5 write-path failures `_warn` → `_fail`.

v3.51.0  2026-04-14
- Kernel cmdline: `amd_iommu=off` → `iommu=pt`.
- ENV_VARS: `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`; dropped `VKD3D_CONFIG=transfer_queue` (12 → 11).
- `_install_fstab_opts`: `commit=10` appended; awk strips pre-existing `commit=N`.

v3.50.4  2026-04-13
- `_ry_do_test_all`: parallel worker fork wrapped with `timeout --kill-after=5 180`.

v3.50.3  2026-04-13
- `_ry_verify_runtime`: AMD GPU power level uses `/sys/class/drm/card*/` glob.
- `_ry_check_network`: probe list extended with IPv6 gateways.

v3.50.2  2026-04-13
- `_ry_do_check`: pre-serialize LVM state in parent (sudo pvs needs parent cache).
- `_install_rebuild_boot`: BOOT_WIPE_MARKER re-prompts on basename-set change (not just count).

v3.50.1  2026-04-13
- `_acquire_lock`: stale-lock reclaim uses `flock -n -E 5` before rmdir+mkdir+PID re-verify.

v3.50.0  2026-04-13
- Profile system: external profiles at `~/.config/ry-install/profiles/<n>.fish`; resolution via `~/.config/ry-install/default-profile` → `gtr9_pro` fallback.
- `_validate_profile`: 26 required globals + numeric type-check + element sanitization.
- `_manifest_check_orphans`: warns on files from previous install/profile.

v3.49.0  2026-04-12
- Dropped 61 low-value comment lines (narration-prefix, orphan section refs). 6050 → 5989.

v3.48.26  2026-04-09
- TIMESTAMP: suffixed with `$fish_pid` (prevents log-file race between concurrent children).
- `_ry_verify_static`, `_ry_verify_runtime`: early-return calls `_verify_summary` and uses `_fail` for counter consistency.

v3.48.25  2026-04-09
- `_run`: `RY_RUN_TIMEOUT` regex `^\d+$` → `^[1-9]\d*$` (rejects 0, leading-zero, empty).
- Documented `RY_RUN_TIMEOUT`, `RY_INSTALL_CONFIRM_BOOT_WIPE`, `NO_COLOR`.

v3.48.24  2026-04-09
- `_run`: `</dev/null` added; opt-in wall-clock timeout via `RY_RUN_TIMEOUT`.
- 10 `fish -c` workers wrapped with `timeout --kill-after=5 60`.
- `_atomic_write_file`: post-write hash mismatch distinguishes content-diff from sudo lapse.

v3.48.23  2026-04-09
- `_ry_do_test_all`: managed-case count drift assertion via awk over `case` branches.

v3.48.22  2026-04-09
- Removed `_ry_count_managed_cases` (replaced with compile-time constant).
- Removed `_get_boot_time` (inlined).
- Merged `_progress_skip` into `_progress`.
- Fixed `_progress` bar rendering as `[]` at 0% and 100%.

v3.48.21  2026-04-09
- Removed 4 stale `--lint` comments.

v3.48.20  2026-04-09
- Removed `--lint` mode and `_ry_do_lint` (~317 L).
- Removed undocumented `--restore-power-targets`.
- Fixed top-level `exit` killing host shell on source: `_ry_exit` helper + `_RY_INSTALL_BAILING` + `_RY_INSTALL_SOURCED` + `_RY_INSTALL_LAST_EXIT`.
- `EXPECTED_VULKAN_PKGS` now optional.
- `_ry_do_install_file`: `realpath -m` on managed destinations (symlinked /home on rpm-ostree/homed).
- `_run`: single `mktemp -d` for stdout/stderr; degraded path fails loud.
- Boot-wipe marker: hoisted into `_install_finalize` success path; atomic write.

v3.48.19  2026-04-09
- `_dir_group_or_world_writable`: single helper replaces duplicates.
- BOOT_WIPE_MARKER: stores entry count; re-prompts if entries grew.
- `_progress`: `string repeat` replaces per-char loop.

v3.48.18  2026-04-09
- `_ry_do_test_all`: fixed false code=999 from label-stripping mismatch.
- `_validate_user_env`: regex-escape `$var_name`; added missing `--`.
- `_install_kernel_cmdline`: anchored `LINUX_OPTIONS=` strip.
- `_ry_verify_runtime` NM sweep: `find -print0 | string split0`.

v3.48.17  2026-04-08
- `_pregenerate_content_files`: mktemp `-t` flag fix.
- `_cleanup_tmpfiles`: sweep 0700 root dirs via `sudo -n find`.
- `_install_fstab_opts`: awk `OFS` fix; post-rewrite `findmnt --verify`.
- `_content_hash`: capture `$pipestatus` for generator failures.

v3.48.16  2026-04-08
- `SDBOOT_REMOVE_EXISTING=yes` requires `RY_INSTALL_CONFIRM_BOOT_WIPE=1`; marker at `~/ry-install/.boot-wipe-acknowledged`.
- `_atomic_write_file`: post-write hash distinguishes sudo lapse from fs error.
- Preflight: missing root UUID → EXIT_PREFLIGHT; dropped diff/md5sum/tput deps; `iw` removed from PKGS_ADD.
- `_acquire_lock`: flock reclaim writes PID inside locked subshell.
- `_ry_verify_runtime`: WiFi checks gated on profile; HPET fail auto-greps dmesg.

v3.48.6-v3.48.15  2026-04-08
- Accumulated fixes landing across these versions (see v3.48.16 for SDBOOT ack, `_atomic_write_file`, preflight, `_acquire_lock`, `_ry_verify_runtime`).
- README: condensation pass (Uninstall, Scope, paru fallback, fstab no-backup, profile globals, NDJSON sample, Troubleshooting, TOC; badges removed).
