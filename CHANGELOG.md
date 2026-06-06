ry-install changelog — newest first; <subsystem>: <change>.

ry-install 7.21.3 (2026-06-06)
docs: document TMPDIR fallback; prune guidance covers run-overflow/ .log spills.
style: trim verbose comments to vital; fold header lint line (code unchanged).

ry-install 7.21.2 (2026-06-06)
docs: fix missing space in Phase 2 AUR/Vulkan prose.

ry-install 7.21.1 (2026-06-06)
preflight: refuse stateful backup-target generator.
docs: note %z guard rejects empty/literal output.
docs: note sdboot gen clears foreign entries; --check drifts until reboot.

ry-install 7.21.0 (2026-06-06)
resolved: DNSOverTLS no -> opportunistic.
docs: failure-triage jq also matches PHASE_RESULT result=FAIL/WARN rows.
docs: clarify CachyOS-default packages whose configs deploy.

ry-install 7.20.11 (2026-06-06)
docs: counts in per-row # column; drop (N) totals from headers.

ry-install 7.20.10 (2026-06-06)
docs: drop low-value README prose.

ry-install 7.20.9 (2026-06-06)
docs: trim redundant README prose.

ry-install 7.20.8 (2026-06-06)
docs: term log->JSONL; driver->device; phase heading suffixes.

ry-install 7.20.7 (2026-06-06)
verify: static FAIL outranks runtime preflight bail (return 1, not 3).
preflight: pin SYSTEM_DESTINATIONS (14) + USER_DESTINATIONS (1) counts.
style: fold explanatory comments onto statements.

ry-install 7.20.6 (2026-06-06)
style: trim verbose comments (code unchanged).
docs: README config by phase; flag fstab in-place; GitHub callouts.
docs: fix log-retention claim (logs not auto-pruned).

ry-install 7.20.5 (2026-06-05)
style: fold last multi-line comment to single line.
docs: fish -n is the syntax gate (fish_indent cosmetic, not CI-gated).
docs: condense README; align exit-code labels with script.

ry-install 7.20.4 (2026-06-05)
lock: reclaim corrupt/non-numeric .lock pidfile (was permanent exit-5).
docs: document exit 2/4, GNU-coreutils req, ufw/amd_iommu posture.
style: note one-liner style in header.

ry-install 7.20.3 (2026-06-05)
verify: malformed sdboot LINUX_OPTIONS now FAIL (was WARN).

ry-install 7.20.2 (2026-06-05)
fstab: snapshot to .ry.bak before rewrite.

ry-install 7.20.1 (2026-06-05)
harden: RY_RUN_TIMEOUT-invalid notice no longer bumps verify counters.
docs: annotate embedded-config arrays with purpose + count.

ry-install 7.20.0 (2026-06-04)
harden: skip stderr writes after SIGPIPE; timeout-bypass matches command basename.
sweep: derive sudo-rm roots from managed-dest parents.
pkgs: drop lib32-mesa from EXPECTED_VULKAN_PKGS (3->2).
verify: track dmesg line count, not 5000-line buffer.

ry-install 7.19.0 - 7.19.25 (2026-06-02..2026-06-04)
fix: preflight-abort renders PREFLIGHT (3); only -Syu/pkg-verify/boot-config taint Phase 5.
fix: fstab rewrite refuses when findmnt absent.
harden: validate --country; CPU gate every mode; guard id(1)/PATH.
verify: combined static+runtime totals; THP/ZRAM/swap advisory.
install-file: live-apply only on byte change; post-hook rc0 WARN.
pkgs: drop iw, rtkit (16->14); add cachy-update to removals (7->8).
files: drop i2c-dev modules-load (16->15); regdom to /etc/iw-regdomain.
cmdline: ppfeaturemask 0xfff73fff; iommu=pt -> amd_iommu=off.

ry-install 7.18.0 (2026-06-01)
remove: kernel-version floor gate.

ry-install 7.17.0 - 7.17.29 (2026-05-30..2026-06-01)
feat: pin NVMe scheduler none (15->16); add ddcutil; --country=XX regdom.
cli: --verify replaces --verify-static/--verify-runtime.
cmdline: drop max_cstate, cwsr_enable, sg_display (13 params).
sysctl: +vm.max_map_count (8); halve ttm page limits.
harden: systemd >= 250 gate; _run overflow-spill; 3x stale-lock reclaim.
fix: paru-absent WARN; partial AUR WARN, all-failed FAIL; per-file findmnt skips vfat.
verify: fix footer double-count; derive ppfeaturemask from KERNEL_PARAMS.

ry-install 7.16.0 (2026-05-30)
logind: drop HandleSecureAttentionKey (9->8).
mask: drop lvm2-monitor.service (12->11).

ry-install 7.15.0 (2026-05-30)
env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE.
sysctl: drop busy_poll/busy_read (9->7).

ry-install 7.14.0 - 7.14.3 (2026-05-29..2026-05-30)
cmdline: ppfeaturemask tuning; AUR reduced to mkinitcpio-firmware (3->1).
harden: guard optional tools (ip, ping, swapon, zcat).

ry-install 7.13.0 - 7.13.5 (2026-05-29)
aur: install unconditionally; drop hardware-gating.
cli: drop RY_INSTALL_* toggles (runtime-vars 6->4).

ry-install 7.12.0 (2026-05-29)
backups: auto .ry.bak for loader.conf, mkinitcpio.conf; add time-sync preflight.

Earlier releases: see git history.
