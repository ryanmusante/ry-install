ry-install changelog - newest first.

7.25.4 - 2026-06-10
- cleanup: guard the progress-bar teardown call; a signal landing before the progress module loads no longer prints an unknown-command error.
- docs: README firewall note states the forward chain is dropped, matching the shipped ruleset.
- style: trim two long inline comments; post-hook banner reads 12 handlers / 17 patterns.

7.25.3 - 2026-06-10
- services: activate nftables.service before the ufw flush (no unfirewalled window in the handoff).
- verify: runtime unit batch covers nftables.service (pinned 5->6).
- verify: parent-dir perms skip vfat/undetermined /boot dirs (per-file parity).
- verify: HOOKS parse tolerates multi-line HOOKS=( ... ).
- log: failed log rename keeps logging to the old path instead of disabling JSONL.
- log: _json_str preserves trailing newlines.
- fstab: opts rewrite splices the options field, original whitespace preserved.
- summary: matrix footer joins column rules with proper junctions.
- style: pacman -Qq for iwd presence; single username resolve in the completion summary.

7.25.2 - 2026-06-09
- cleanup: failed/skipped signal-time mkinitcpio revert preserves the /run snapshot.
- cleanup: reap children before the revert; lock release moved after the sweeps.
- cleanup: child-reap grace polls up to 10s while db.lck is held (0.5s otherwise).
- cleanup: ry-run.* inner-file sweep no longer breaks on TMPDIR glob metachars.
- packages: after a -Syu revert, mkinitcpio.conf.pacnew is reported for pacdiff, not auto-resolved.
- verify: boot-time parser accepts h/min/s/ms totals; >60s boots hit the target compare.
- verify: NM wifi.backend probe distinguishes sudo lapse from a missing backend.
- lock: live-but-unsignalable peer PID (/proc present, EPERM) is never reclaimed.
- boot: _preflight_boot_sanity refuses an empty $BOOT.
- docs: README trimmed; sdboot injects root=+rw; vm sysctls are kernel defaults.
- style: trim long inline comments; merge AUR noise-token log lines.

7.25.1 - 2026-06-09
- guard: sourced invocation returns 1 instead of exiting the caller's shell.
- lock: settle 0.2s + re-read before empty-pidfile reclaim; live peer wins.
- packages: keep the /run mkinitcpio snapshot when revert fails.
- verify: parent-dir check covers the user environment.d dir.
- run: _rm_tmp keeps paths tracked unless rm returned 0.
- preflight: drop dead fish-minor re-test; add '#' to the metachar reject set.
- docs: README notes boot-time near-miss tier, snapshot keep, lock settle.
- style: trim longest inline comments.

7.25.0 - 2026-06-09
- cpupower: governor performance -> powersave; EPP unpinned, reported advisory.
- cmdline: drop preempt=full (kernel default; 13->12).
- check: unreadable /proc/cmdline returns preflight (3), not drift (10).
- services: ufw flush messages name nftables as the active host firewall.
- lock: cleanup removes an empty-pidfile lock dir only if self-created.
- run: rename _run_emit_stream capture list _redacted -> _captured.
- docs: README notes sdboot-manage injects root= into LINUX_OPTIONS.

7.24.7 - 2026-06-09
- progress: WINCH below 10 rows tears down the pinned bar.
- docs: reword stale descriptions for _csp_filter_rdeps and _verify_static_syntax.
- docs: README Phase 2 documents .pacnew auto-resolution and .pacsave reporting.
- style: drop redundant string split in the dmesg capture.
- build: archive ships ry-install.fish mode 0755 (7.24.6 stored 0644).

7.24.6 - 2026-06-09
- style: script comments trimmed; 7.24.3 changelog entry condensed.

7.24.5 - 2026-06-09
- modprobe: ttm page_pool_size 12582912 -> 25165824 (equal to pages_limit).
- preflight: ttm assert updated to page_pool_size == pages_limit.

7.24.4 - 2026-06-09
- resolved: DNSOverTLS opportunistic -> no.

7.24.3 - 2026-06-09
- fix: wifi-route case 'br[0-9]*' never matched (fish lacks [..] globs); use 'br*'.
- fix: --install-file boot cascade refuses a non-vfat /boot ESP fallback (Phase 5 parity).
- verify: drirc xmllint sudo-reads root-only files; nft unknown/n-a posture; sys_units pinned to 5.
- check: stderr-silent on post-parse anomalies; pre-parse TMPDIR warnings remain.
- harden: lock pidfile write/install failures emit JSONL tags.
- run: nftables is-active probe un-wrapped from _run.
- docs: README synced (NTP, scope, orphan sweep, exit-5, --check stderr, non-vfat).
- style: note fish literal-bracket globs at the THP check and overlay case list.

7.24.2 - 2026-06-09
- fix: nftables.conf fell through to _grep_ini_header; add _grep_nft_entry (7.24.0 regression).
- harden: stale-reclaim re-reads the pidfile right before rm -rf.

7.24.1 - 2026-06-09
- docs: fix stale count comments (PKGS_ADD 14->15, post-hooks 11->12).

7.24.0 - 2026-06-08
- cpupower: governor powersave -> performance (EPP follows; no ppd).
- modprobe: ttm pages_limit 8388608 -> 25165824, page_pool_size 4194304 -> 12582912.
- security: nftables default-deny-inbound; ufw masked; counts 14->15/3->4/15->16/16->17.
- services: ppd stays masked; governor=performance is global.
- docs: recommend cachyos-znver4 (Zen5/AVX-512) repos.

7.23.2 - 2026-06-08
- services: record regdom phase row in the run-summary matrix.

7.23.1 - 2026-06-08
- verify: advisory report of CachyOS vm.max_map_count/compaction_proactiveness.
- preflight: assert ttm page_pool_size == pages_limit / 2.
- docs: document timing tunables + CachyOS vm sysctls; single-AUR-pkg fail exits 1.

7.23.0 - 2026-06-07
- cmdline: ppfeaturemask 0xfff73fff -> 0xffff7fff (GFXOFF off; overdrive un-gated).
- modprobe: ttm page_pool_size 8388608 -> 4194304 (half of pages_limit).
- sysctl: drop vm.max_map_count + vm.compaction_proactiveness (CachyOS-set; 8->6).

7.22.14 - 2026-06-07
- preflight: gate remaining coreutils + kill.

7.22.13 - 2026-06-07
- cli: name 250/255 sentinels EXIT_AS_MISUSE/EXIT_RUN_MISUSE.
- preflight: count-guard _RY_ISO3166_ALPHA2 (249).
- style: log-path notice prefix [i] -> [INFO].

7.22.12 - 2026-06-07
- cli: positional error lists all stray args.
- docs: uninstall removes .ry.bak backups; user env file removed without sudo.
- style: trim longest inline comments.

7.22.11 - 2026-06-07
- install-file: deploy/gen/hook on the matched literal dst (symlink-safe).
- verify: CPU EPP check advisory (profile sets governor, not EPP).
- fix: summary banner reads ERRORS not WARNINGS on a failed run.
- harden: user config dir uses ambient umask; 0600 file unchanged.
- style: trim longest inline comment.

7.22.10 - 2026-06-07
- docs: label 11/12/13/251 internal sentinels (README + --help).
- docs: NetworkManager logging is [logging] level=WARN.

7.22.9 - 2026-06-07
- docs: correct retry-command reference to -Syyu.
- check: rename _cpu_chk_expected -> _svc_chk_expected.
- style: single-split DATE_LABEL/TIMESTAMP; clarify _RY_TMPDIR_GLOBS comment.

7.22.8 - 2026-06-07
- fix: derive DATE_LABEL/TIMESTAMP from one date call (midnight-atomic).
- docs: document --verify runtime coverage; -Syy retry on transient pacman fail.
- style: trim verbose inline comments.

7.22.7 - 2026-06-07
- docs: correct atomic-write order (backup precedes mv -T; restore post-write).
- docs: flatten changelog to plain text.
- style: tighten longest inline comments.

7.22.6 - 2026-06-07
- services: skip enabling NetworkManager-dispatcher when preset is static.

7.22.5 - 2026-06-07
- services: enable NetworkManager.service when preset leaves it disabled.
- check: accept static for conf.d-driven units (resolved).
- harden: widen KERNEL_PARAMS metachar reject set.
- sweep: centralize TMPDIR tmpfile globs; pin count.
- docs: scope post-write re-read/restore to boot backup-targets.

7.22.4 - 2026-06-07
- docs: render Configuration section as tables.

7.22.3 - 2026-06-07
- docs: trim README; fold per-phase prose into flow table; condense config tables.

7.22.2 - 2026-06-07
- cli: glued short cluster honors only h/v/V; other clusters exit usage.

7.22.1 - 2026-06-06
- cli: honor glued short flags (-hV/-Vh) before root guard.

7.22.0 - 2026-06-06
- fix: realtime/i2c group hint mis-fired for existing members.
- docs: README PKGS_ADD order synced; fstab rewrite drops redundant defaults.

7.21.9 - 2026-06-06
- aur: verify via pacman -T post-paru; rc=0 but missing -> WARN.

7.21.8 - 2026-06-06
- preflight: run invariants before lock; note post-write verify/restore.

7.21.7 - 2026-06-06
- install-file: post-hook resolves on the matched managed dst.

7.21.6 - 2026-06-06
- verify: root-UUID-unresolved cmdline checksum -> WARN (presence checked).
- preflight: explicit return 0.

7.21.5 - 2026-06-06
- docs: drop stale iwd-gate/dmesg comments; list pacman-contrib soft-dep.

7.21.4 - 2026-06-06
- install-file: only /etc/kernel/cmdline needs root UUID.
- docs: --help notes 250/255 _as/_run sentinels.

7.21.3 - 2026-06-06
- docs: document TMPDIR fallback and run-overflow .log prune.

7.21.2 - 2026-06-06
- docs: fix Phase 2 prose spacing.

7.21.1 - 2026-06-06
- preflight: refuse stateful backup-target generator.
- docs: %z guard; sdboot gen clears foreign entries; --check drifts until reboot.

7.21.0 - 2026-06-06
- resolved: DNSOverTLS no -> opportunistic.
- docs: failure-triage jq matches PHASE_RESULT FAIL/WARN; clarify CachyOS-default pkgs.

7.20.11 - 2026-06-06
- docs: per-row counts; drop header totals.

7.20.10 - 2026-06-06
- docs: drop low-value README prose.

7.20.9 - 2026-06-06
- docs: trim redundant README prose.

7.20.8 - 2026-06-06
- docs: term log->JSONL; driver->device; phase heading suffixes.

7.20.7 - 2026-06-06
- verify: static FAIL outranks runtime preflight bail (return 1, not 3).
- preflight: pin SYSTEM_DESTINATIONS (14) + USER_DESTINATIONS (1).

7.20.6 - 2026-06-06
- docs: README config by phase; flag fstab in-place; fix log-retention claim.

7.20.5 - 2026-06-05
- docs: fish -n is the syntax gate; condense README; align exit-code labels.

7.20.4 - 2026-06-05
- lock: reclaim corrupt/non-numeric .lock pidfile.
- docs: document exit 2/4, GNU-coreutils req, ufw/amd_iommu posture.

7.20.3 - 2026-06-05
- verify: malformed sdboot LINUX_OPTIONS now FAIL (was WARN).

7.20.2 - 2026-06-05
- fstab: snapshot to .ry.bak before rewrite.

7.20.1 - 2026-06-05
- harden: RY_RUN_TIMEOUT-invalid notice no longer bumps verify counters.
- docs: annotate embedded-config arrays with purpose + count.

7.20.0 - 2026-06-04
- harden: skip stderr after SIGPIPE; timeout-bypass matches command basename.
- sweep: derive sudo-rm roots from managed-dest parents.
- pkgs: drop lib32-mesa from EXPECTED_VULKAN_PKGS (3->2).
- verify: track dmesg line count, not 5000-line buffer.

7.19.0..7.19.25 - 2026-06-02..2026-06-04
- fix: preflight-abort renders PREFLIGHT (3); only -Syu/pkg/boot-config taint Phase 5.
- fix: fstab rewrite refuses when findmnt absent.
- harden: validate --country; CPU gate every mode; guard id(1)/PATH.
- verify: combined static+runtime totals; THP/ZRAM/swap advisory.
- install-file: live-apply only on byte change; post-hook rc0 WARN.
- pkgs: drop iw, rtkit (16->14); add cachy-update to removals (7->8).
- files: drop i2c-dev modules-load (16->15); regdom to /etc/iw-regdomain.
- cmdline: ppfeaturemask 0xfff73fff; iommu=pt -> amd_iommu=off.

7.18.0 - 2026-06-01
- remove: kernel-version floor gate.

7.17.0..7.17.29 - 2026-05-30..2026-06-01
- feat: pin NVMe scheduler none (15->16); add ddcutil; --country=XX regdom.
- cli: --verify replaces --verify-static/--verify-runtime.
- cmdline: drop max_cstate, cwsr_enable, sg_display (13 params).
- sysctl: +vm.max_map_count (8); halve ttm page limits.
- harden: systemd >= 250 gate; _run overflow-spill; 3x stale-lock reclaim.
- fix: paru-absent/partial AUR WARN, all-failed FAIL; per-file findmnt skips vfat.
- verify: fix footer double-count; ppfeaturemask derived from KERNEL_PARAMS.

7.16.0 - 2026-05-30
- logind: drop HandleSecureAttentionKey (9->8).
- mask: drop lvm2-monitor.service (12->11).

7.15.0 - 2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE.
- sysctl: drop busy_poll/busy_read (9->7).

7.14.0..7.14.3 - 2026-05-29..2026-05-30
- cmdline: ppfeaturemask tuning; AUR reduced to mkinitcpio-firmware (3->1).
- harden: guard optional tools (ip, ping, swapon, zcat).

7.13.0..7.13.5 - 2026-05-29
- aur: install unconditionally; drop hardware-gating.
- cli: drop RY_INSTALL_* toggles (runtime-vars 6->4).

7.12.0 - 2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; add time-sync preflight.

Earlier releases: see git history.
