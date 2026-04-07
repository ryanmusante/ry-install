ry-install changelog

2026-04-07  Ryan Musante

- Tagged as v3.47.8
- audit: applied 24-item audit spec — 5 HIGH, 13 MED, 5 LOW, 1 INFO.
- F-1 (HIGH): _ry_do_lint file count xref now uses strict equality (-eq).
- F-2 (LOW): _ry_do_lint anti-pattern greps preserve real source line numbers via awk NR: prefix.
- F-3 (HIGH): _run argv metachar reject regex extended with < > ( ) { }.
- F-4 (LOW): _get_boot_time gained explicit return 0 / return 1.
- F-5 (INFO): _kill_sudo_keepalive verifies PID with kill -0 before TERM.
- F-6 (MED): _ensure_sudo_cached uses sudo -v with interactive fallback.
- F-7 (HIGH): _find_pacnew_files captures sudo -n stderr and warns on failure.
- F-8 (MED): _ry_do_diff removed redundant inline sudo cache block in --fix branch.
- F-9 (MED): .pacnew/.pacsave detection uses one batched find instead of 2*N sudo test -f calls.
- F-10 (MED): _ry_install_file lazy-caches iwd-skip state.
- F-11 (MED): _manifest_write defensive mkdir -p $manifest_dir before mktemp.
- F-12 (MED): _pregenerate_content_files bails on mktemp -d failure before tracking.
- F-13 (MED): _cleanup_tmpfiles dropped DRY early-return; closes tmpfile leak on dry-run exit.
- F-14 (LOW): _kconfig_cache uses sentinel _KCONFIG_LOADED instead of count==0 gate.
- F-15 (HIGH): _ry_validate_configs Job 1 (xref) replaced count comparison with explicit per-destination existence check.
- F-16 (HIGH): _ry_do_check Job 4 (svc check) added runtime assertion guarding positional coupling.
- F-17 (MED): _validate_kernel_params CONFIG_ map extended; unchecked params documented.
- F-18 (MED): _ry_verify_static sysctl check now compares value, not just key presence.
- F-19 (MED): _validate_profile decoupled iwd vs NM required-var sets.
- F-20 (MED): added SDBOOT_DEFAULT_ENTRY profile global; removes hardcoded "manual".
- F-21 (MED): _ry_do_diff --fix iwd branch now restarts iwd.service before NetworkManager.
- F-22 (LOW): _ry_verify_runtime ENV_VARS check sources from systemctl --user show-environment with printenv fallback.
- F-23 (LOW): WiFi nmcli loop magic numbers promoted to WIFI_RELOAD_WAIT/WIFI_RESCAN_INTV.
- F-24 (MED): added "Profile Trust Model" section to README.md.

2026-04-07  Ryan Musante

- Tagged as v3.47.7
- audit: applied v3.47.6 audit spec — 1 HIGH, 8 MED, 15 LOW, 3 REFACTOR, 18 INFO injections. fish --no-execute, fish_indent --check, --lint internal consistency: all green.
- fix(H-01): _atomic_write_file expected hash now sourced from `_ry_get_file_content "$dst"` (generator), not from sudo cat of the tee'd tmpfile. Closes integrity gap where tee truncation, generator drift, or in-flight tampering could not be detected by the post-mv check. Pattern matches existing _ry_install_file at the skip-unchanged path.
- fix(M-01): subsumed by H-01 — the `sudo -n cat -- $tmpfile` call that raced sudo keepalive no longer exists.
- fix(M-02): _ry_install_file skip-unchanged path: `sudo -n cat` → `sudo cat`. Removes false-abort on sudo credential lapse during long runs.
- fix(M-03): init block — `chmod 700 "$HOME/ry-install"` now verifies mode via `stat -c %a` and preflight-fails on mismatch (was: `; or true` swallowed errors silently).
- fix(M-04): init block — touch+chmod fallback for $LOG_FILE wrapped in `umask 0177` to make file creation race-free even when `install -m` is unavailable.
- fix(M-05): log-rename block — same `umask 0177` wrap applied to the second touch+chmod fallback.
- fix(M-06): _ry_verify_runtime — `perm_checked` counter increment moved AFTER the vfat-skip `continue` so /boot vfat files no longer inflate the "All N installed files: correct permissions" tally.
- fix(M-07): _install_finalize — dropped trailing `2>/dev/null` on `_run sudo chown` and `_run sudo nmcli connection load` so failures surface in the log.
- fix(M-08): _ry_do_install_file — system *.service post-install now prompts to enable, matching the user-scope path. Closes dispatch asymmetry where user services were enabled interactively but system services only got daemon-reload.
- fix(L-01): root execution is now a hard EXIT_USAGE error. Previously forced --dry-run and continued; now requires explicit `--allow-root` opt-in with a louder NOTICE banner. Fail-closed privilege.
- fix(L-02): KVER_MAJOR/KVER_MINOR parse failures now preflight-fail with EXIT_PREFLIGHT instead of silently falling back to 0 (which masked broken `uname -r` output).
- fix(L-03): _ry_verify_static parallel hash workers now write `fail` (not `skip`) when `installed_$safe` is empty, so a sudo readback failure can no longer be misclassified as "missing file, skip".
- fix(L-04): _ry_do_check Job 3 (kernel params) — empty/unreadable /proc/cmdline now sets drift=true. Previously the `if test -n "$cmdline"` guard caused silent skip.
- fix(L-05): _install_configure_services dry-run LVM detection — when sudo is uncached, `has_lvm` defaults to true. Prevents incorrect masking of `lvm2-monitor.service` in dry-run reports on LVM systems.
- fix(L-06): _ry_verify_runtime pacnew loop — removed dead `pac_managed` counter that was incremented but never read.
- fix(L-07): _ry_verify_runtime vulkan check — `vulkan-radeon lib32-vulkan-radeon lib32-mesa` no longer hardcoded; new profile global `EXPECTED_VULKAN_PKGS` added and iterated. Removes profile bleed.
- fix(L-08): updatedb / pkgfile prompts moved from `_install_configure_services` to the end of `_install_packages`. DB refreshes now sit on the correct side of the package phase boundary.
- doc(L-09): added comment in _install_system_files explaining that SERVICE_DESTINATIONS are deployed in _install_configure_services for atomic install+enable, not here.
- fix(L-10): _install_configure_services interactive cpupower-epp prompt — declined branch now writes `USER_DECLINED: cpupower-epp.service install` to the log for audit trail.
- fix(L-11): _install_finalize — `sleep $NM_RESTART_DELAY` after NetworkManager restart is no longer gated on `WIFI_SSID`. Restart-without-WiFi now also gets the iwd D-Bus settle window.
- fix(L-12): dispatch-time `_IS_ROOT` warning block removed; duplicated the init-block NOTICE that already runs at line ~38.
- fix(L-13): _ry_do_completions — mktemp failure error now includes `$comp_dir` path for diagnostics.
- fix(L-14): _ry_do_completions — captured `$status` immediately after the `echo end >>"$tmpfile"` write into a dedicated variable; the verification block no longer relies on a `$status` value that was overwritten by intervening checks.
- doc(L-15): no code change required — log-rotation `rm -f` is idempotent; existing comment is accurate.
- refactor(R-03): injected 18 `# INVARIANT[I-NN]:` single-line comments at the verified anchors (file-count consistency, MASK consistency, fish-syntax gate, anti-pattern gate, _run argv hardening, WiFi credential lifecycle, NM UUID derivation, drift accounting, parallel-hash worker contract, TOCTOU symlink recheck, parent-dir mode parser, fstab patching, boot sanity, EXIT_BOOT_CRIT short-circuit, lock policy, argparse model, nproc-scaled parallelism).
- refactor(R-02): collapsed 25 adjacent multi-line comment runs into single comments. `lint:ignore` markers, shebang, and header line 2 preserved.
- refactor(R-01): moved 5 trailing inline comments onto their own lines above the code they describe. `lint:ignore` markers preserved in original position.

2026-04-07  Ryan Musante

- Tagged as v3.47.6
- fix: PKGS_ADD — removed `ntsync-common`. Redundant on CachyOS: linux-cachyos ships `CONFIG_NTSYNC=m` and declares `provides=(NTSYNC-MODULE)`; wine-cachyos (transitive dep of cachyos-gaming-meta via wine-cachyos-opt) installs `/usr/lib/modules-load.d/10-ntsync.conf` to auto-load the in-kernel module on boot. Refs: github.com/CachyOS/linux-cachyos config + PKGBUILD, github.com/CachyOS/CachyOS-PKGBUILDS/wine-cachyos.
- fix: SYSCTL_VALUES — dropped `vm.dirty_bytes=268435456` and `vm.dirty_background_bytes=67108864`. Both are byte-identical to vendor `/usr/lib/sysctl.d/70-cachyos-settings.conf` and were no-op duplicates.
- doc: README sysctl row updated to "17 net-new tunables" and explicitly notes `net.core.netdev_max_backlog` overrides vendor 4096→16384 (99-* loads after 70-* lexically).
- doc: Hardware Reference NIC corrected from "Dual Realtek RTL8127 10 GbE (board v2.2)" to "Dual Intel E610-XT2 10 GbE" per ServeTheHome review and Beelink/Intel support correspondence (craigwilson.blog).
- fix: KERNEL_PARAMS — removed `preempt=full`. No-op on stock linux-cachyos (CONFIG_PREEMPT=y + CONFIG_PREEMPT_DYNAMIC=y → "full" is already the dynamic default). README kernel-params count 15 → 14.
- doc: README Masked Services — removed unsourced "cache thrashing on 32T" framing from irqbalance row; left only the verifiable "Conflicts with threadirqs".
- doc: README Environment Variables — `PROTON_USE_NTSYNC=1` annotated as "default in current proton-cachyos; explicit pin" since recent proton-cachyos releases enable it by default.
- doc: README + profile comment — softened CWSR row, dropped unverifiable "Ubuntu OEM kernel 1018+ (not mainline as of 2026-Q2)" claim; kept the verified ROCm 7.2 userspace fix note and the kernel workaround.
- doc: README Known Issues — softened MES page faults row (dropped specific FW 0x83 / linux-firmware-20251125 date string pending upstream verification); softened black-screen row (dropped specific 6.19.0/6.19.1+ version pins pending verification).
- doc: Hardware Reference BIOS row softened from "P110 (Dec 2025 — ACPI fix)" to "Latest available from Beelink (P110+ recommended)" — vendor changelog not publicly verifiable.

2026-04-07  Ryan Musante

- Tagged as v3.47.5
- fix: ENV_VARS — `DXVK_LOG_LEVEL=none` valid but creates empty `app_d3d11.log` / `app_dxgi.log` files (doitsujin/dxvk#1703); added `DXVK_LOG_PATH=none` per DXVK README to disable log file creation entirely.
- doc: corrected `amdgpu.cwsr_enable=0` rationale in profile comment, README env table, and audit table — kernel-mode fix is only in Ubuntu OEM kernel 1018+ (not mainline as of 2026-Q2); ROCm 7.2 ships userspace fix only, kernel workaround still required. Refs: ROCm/ROCm#5724, ROCm/TheRock#2991.

2026-04-07  Ryan Musante

- Tagged as v3.47.4
- fix: ENV_VARS — `RADV_EXPERIMENTAL=transfer_queue` does not exist; correct variable per Mesa 26.0 is `RADV_PERFTEST=transfer_queue`. Also added `VKD3D_CONFIG=transfer_queue` so vkd3d-proton (DX12) titles actually use the dedicated SDMA transfer queue. Ref: https://www.phoronix.com/news/Mesa-26.0-RADV-Transfer-SDMA

2026-04-07  Ryan Musante

- Tagged as v3.47.3
- _install_fstab_opts: replace substring sed pipeline with field-based awk filter ($3 == "ext4"); old pipeline corrupted unrelated mounts whose path contained the literal "ext4" (e.g. /srv/ext4backups on xfs). Same fix applied to _ry_verify_runtime and needs_change check.
- _install_rebuild_boot: initrd size loop uses sudo find instead of user-context glob; on ESP-mounted /boot (vfat 0700) the glob silently yielded zero iterations.
- _ry_verify_static, _install_rebuild_boot: add -maxdepth 1 -type f to find /boot/loader/entries -name '*.conf'.
- CLI dispatch: unknown-mode arm uses $EXIT_USAGE constant.
- _validate_profile: SYSCTL_VALUES moved to conditional required block (only when */sysctl.d/* destination present); _ry_verify_runtime sysctl loop guards on set -q.
- _manifest_write: drop tmp from _TRACKED_TMPFILES on successful mv.
- Top-level LOG_FILE rename: capture mv rc, warn on failure, keep old path so footer/header still write.
- WiFi passphrase % rejection: rationale corrected to "NM keyfile reserved character".

2026-04-06  Ryan Musante

- Tagged as v3.47.2
- Drop spurious second `--` in 8 `string split -- ':' --` calls; rec[1..3] indices were off by one, breaking every service-state assertion in --verify-static and --verify-runtime.
- _validate_profile case glob `*/nm.conf` -> `*nm.conf` (fish glob `*` doesn't cross `/`; basename `99-cachyos-nm.conf` never matched).
- lint: changelog cross-check pointed at CHANGELOG.txt (file is .md) and used a regex for `3.47.1 (...)`; updated to match `- Tagged as v<ver>` lines.
- Log rotation piped `string join0` directly into xargs; capture into variable was stripping NULs and removing only one stale log per run.
- Removed dead `or set sudo_all 0` after `set -l sudo_all (...)`.
- test: --test-all completions check matches full flag tokens.
- _install_fstab_opts: removed unused `_mnt` local.

2026-04-05  Ryan Musante

- Tagged as v3.47.1
- Re-source guard no longer kills caller's interactive shell.
- _atomic_write_file: chown failure now returns 1.
- _acquire_lock: removed redundant PID write inside flock /bin/sh -c.
- Extracted _write_footer helper; deduped four JSONL footer printf sites.

2026-04-04  Ryan Musante

- Tagged as v3.47.0
- _atomic_write_file: parent-dir trust check before sudo mktemp; closes TOCTOU vs symlink probe.
- _atomic_write_file: fail-closed on empty pre-mv / post-mv hash.
- _ry_install_files: _argparse_tmp /dev/null fallback emits one-shot WARN.
- _pregenerate_content_files: mktemp uses --tmpdir=/tmp explicitly.
- Bootloader update: interactive confirm before destructive sdboot-manage gen.
- Root invocation emits explicit [NOTICE] when forcing --dry-run.
