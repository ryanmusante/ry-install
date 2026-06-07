ry-install changelog — newest first; lines are `<subsystem>: <change>`.

7.22.13 - 2026-06-07
- cli: name _as/_run misuse sentinels (250/255) as EXIT_AS_MISUSE/EXIT_RUN_MISUSE globals.
- preflight: count-guard _RY_ISO3166_ALPHA2 (249) alongside the other array invariants.
- style: final log-path notice prefix [i] -> [INFO] for level-vocab consistency.

7.22.12 - 2026-06-07
- cli: unexpected-positional error lists all stray args, not just the first.
- docs: uninstall removes `.ry.bak` backups; user env file removed without sudo.
- style: trim longest inline comments to vital info.

7.22.11 - 2026-06-07
- install-file: deploy/gen/hook on the matched literal dst (symlink-safe).
- verify: CPU EPP check advisory, not FAIL (profile sets governor, not EPP).
- fix: summary banner reads ERRORS not WARNINGS on a failed run.
- harden: user config dir uses ambient umask; 0600 file unchanged.
- style: trim longest inline comment.

7.22.10 - 2026-06-07
- docs: label 11/12/13/251 internal sentinels, never a process exit (README + --help).
- docs: NetworkManager logging is `[logging] level=WARN`.

7.22.9 - 2026-06-07
- docs: correct retry-command reference to -Syyu.
- check: rename _cpu_chk_expected → _svc_chk_expected (checks EXPECTED_SERVICES).
- style: single-split DATE_LABEL/TIMESTAMP; clarify _RY_TMPDIR_GLOBS scope comment.

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
- aur: verify via pacman -T post-paru; rc=0 but missing → WARN.

7.21.8 - 2026-06-06
- preflight: run invariants before lock; note post-write verify/restore.

7.21.7 - 2026-06-06
- install-file: post-hook resolves on the matched managed dst.

7.21.6 - 2026-06-06
- verify: root-UUID-unresolved cmdline checksum → WARN (presence checked).
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
- resolved: DNSOverTLS no → opportunistic.
- docs: failure-triage jq matches PHASE_RESULT FAIL/WARN; clarify CachyOS-default pkgs.

7.20.11 - 2026-06-06
- docs: per-row counts; drop header totals.

7.20.10 - 2026-06-06
- docs: drop low-value README prose.

7.20.9 - 2026-06-06
- docs: trim redundant README prose.

7.20.8 - 2026-06-06
- docs: term log→JSONL; driver→device; phase heading suffixes.

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
- pkgs: drop lib32-mesa from EXPECTED_VULKAN_PKGS (3→2).
- verify: track dmesg line count, not 5000-line buffer.

7.19.0–7.19.25 - 2026-06-02..2026-06-04
- fix: preflight-abort renders PREFLIGHT (3); only -Syu/pkg-verify/boot-config taint Phase 5.
- fix: fstab rewrite refuses when findmnt absent.
- harden: validate --country; CPU gate every mode; guard id(1)/PATH.
- verify: combined static+runtime totals; THP/ZRAM/swap advisory.
- install-file: live-apply only on byte change; post-hook rc0 WARN.
- pkgs: drop iw, rtkit (16→14); add cachy-update to removals (7→8).
- files: drop i2c-dev modules-load (16→15); regdom to /etc/iw-regdomain.
- cmdline: ppfeaturemask 0xfff73fff; iommu=pt → amd_iommu=off.

7.18.0 - 2026-06-01
- remove: kernel-version floor gate.

7.17.0–7.17.29 - 2026-05-30..2026-06-01
- feat: pin NVMe scheduler none (15→16); add ddcutil; --country=XX regdom.
- cli: --verify replaces --verify-static/--verify-runtime.
- cmdline: drop max_cstate, cwsr_enable, sg_display (13 params).
- sysctl: +vm.max_map_count (8); halve ttm page limits.
- harden: systemd ≥ 250 gate; _run overflow-spill; 3x stale-lock reclaim.
- fix: paru-absent WARN; partial AUR WARN, all-failed FAIL; per-file findmnt skips vfat.
- verify: fix footer double-count; ppfeaturemask derived from KERNEL_PARAMS.

7.16.0 - 2026-05-30
- logind: drop HandleSecureAttentionKey (9→8).
- mask: drop lvm2-monitor.service (12→11).

7.15.0 - 2026-05-30
- env: PROTON_FSR4_UPGRADE → PROTON_FSR4_RDNA3_UPGRADE.
- sysctl: drop busy_poll/busy_read (9→7).

7.14.0–7.14.3 - 2026-05-29..2026-05-30
- cmdline: ppfeaturemask tuning; AUR reduced to mkinitcpio-firmware (3→1).
- harden: guard optional tools (ip, ping, swapon, zcat).

7.13.0–7.13.5 - 2026-05-29
- aur: install unconditionally; drop hardware-gating.
- cli: drop RY_INSTALL_* toggles (runtime-vars 6→4).

7.12.0 - 2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; add time-sync preflight.

Earlier releases: see git history.
