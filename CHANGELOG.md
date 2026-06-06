ry-install change log — newest first; subsystem: change, ISO-8601 dates.

ry-install 7.20.6 (2026-06-06)
style: trim verbose comment lines to essential information (code unchanged).
docs: reorder README configuration section by install phase; add prose for the no-write phases (preflight/boot/finalize); flag fstab as in-place (not one of the 15 embedded files); note mkinitcpio.conf pre-deploys in phase 2; adopt GitHub-flavored alert callouts.
docs: correct log-retention claim — logs are not auto-pruned (the script has no retention/pruning).

ry-install 7.20.5 (2026-06-05)
style: fold the _run_effective_timeout header into a single-line comment (last remaining multi-line comment).
docs: fish_indent --check/-w must not gate CI — the dense one-liner style is intentional and reformatting is cosmetic; fish -n is the syntax gate. Header style line updated to match.
docs: trim README — condense verbose prose and tables, keep all sections (script stays source of truth, --verify checks byte-for-byte); align exit-code labels with the script (gen-nofn/gen-nouuid/gen-sysctl).

ry-install 7.20.4 (2026-06-05)
lock: reclaim corrupt/non-numeric .lock pidfile (was permanent exit-5 refusal); live-PID + symlink refusal unchanged.
docs: root-refuse exit 2; --install-file boot-cascade exit 4 vs non-boot rc0 WARN; .lock manual-clear; GNU-coreutils requirement; ufw/amd_iommu posture notes.
style: note intentional one-liner style in header (fish_indent diffs are cosmetic).

ry-install 7.20.3 (2026-06-05)
verify: malformed sdboot-manage.conf LINUX_OPTIONS is now FAIL (was WARN) and no longer skips the remaining sdboot key checks (DEFAULT_ENTRY, REMOVE/OVERWRITE/REMOVE_OBSOLETE, LINUX_FALLBACK_OPTIONS).

ry-install 7.20.2 (2026-06-05)
fstab: snapshot /etc/fstab to .ry.bak before atomic rewrite (best-effort, non-fatal; reuses _awf_make_backup)
doc: document fstab .ry.bak snapshot; "strips conflicting options" (was "entries")

ry-install 7.20.1 (2026-06-05)
harden: RY_RUN_TIMEOUT-invalid notice no longer bumps VERIFY_* counters (config input, not a verify-check anomaly); message and JSONL log unchanged via _msg_nocount.
style: fold the remaining multi-line comment into a single line.
docs: annotate embedded-config arrays with per-array purpose and enforced-count comments.

ry-install 7.20.0 (2026-06-04)
harden: skip cleanup/_run stderr writes after SIGPIPE (honor _RY_OUTPUT_BROKEN).
harden: timeout-bypass matches command basename (absolute paths safe).
sweep: derive sudo-rm escalation roots from managed-dest parents.
pkgs: drop redundant lib32-mesa from EXPECTED_VULKAN_PKGS; 3 -> 2 (verified via PKGS_ADD).
verify: track dmesg line count instead of buffering 5000 lines.
docs: PHASE_RESULT and MATRIX_RENDERED are log entries, not event types.

ry-install 7.19.0 - 7.19.25 (2026-06-02..2026-06-04)
fix: preflight-abort verdict renders PREFLIGHT (exit 3).
fix: only -Syu/pkg-verify/boot-config taint Phase 5 boot rebuild.
fix: fstab rewrite refuses when findmnt absent (gate mandatory).
harden: --country validated against ISO-3166-1 alpha-2 (UK is GB); CPU gate in every mode.
preflight: guard id(1) and PATH before first id -u.
verify: combined static+runtime totals; tcp_congestion_control once; THP/ZRAM/swap demoted to advisory.
install-file: live-apply only on byte change; post-hook failure is rc0 WARN.
pkgs: drop iw, rtkit (16 -> 14); add cachy-update to PKGS_DEL (7 -> 8).
files: drop modules-load.d/i2c-dev.conf (16 -> 15); wireless regdom to /etc/iw-regdomain.
cmdline: ppfeaturemask -> 0xfff73fff; iommu=pt -> amd_iommu=off.
cleanup: drop SERVICE_DESTINATIONS; reclaim empty /run/ry-install staging dir.

ry-install 7.18.0 (2026-06-01)
remove: kernel-version floor gate.

ry-install 7.17.0 - 7.17.29 (2026-05-30..2026-06-01)
feat: pin NVMe scheduler none (15 -> 16); add ddcutil; --country=XX overrides US regdom.
cli: --verify replaces --verify-static/--verify-runtime.
cmdline: drop processor.max_cstate, amdgpu.cwsr_enable, sg_display (KERNEL_PARAMS -> 13).
sysctl: +vm.max_map_count (SYSCTL_VALUES -> 8); ttm page limits halved.
harden: systemd >= 250 hard gate; _run overflow-spill; timeout-bypass skips env/VAR=val; stale-lock reclaim 3x.
harden: write .ry.bak only after render + symlink-probe; force-print boot-critical notice in QUIET.
fix: paru-absent WARN+continue, partial AUR WARN, all-failed FAIL; PKGS_DEL records actual removed count.
fix: per-file findmnt fstype skips vfat; confirmed drift stays EXIT_DRIFT in --check.
verify: fix footer double-count on sudo-cache bail; derive expected ppfeaturemask from KERNEL_PARAMS.
style: quote numeric test operands; condense comments; one-element-per-line arrays.

ry-install 7.16.0 (2026-05-30)
logind: drop HandleSecureAttentionKey (LOGIND_IGNORE_KEYS 9 -> 8).
mask: drop lvm2-monitor.service (MASK 12 -> 11).

ry-install 7.15.0 (2026-05-30)
env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE.
sysctl: drop net.core.busy_poll/busy_read (SYSCTL_VALUES 9 -> 7).

ry-install 7.14.0 - 7.14.3 (2026-05-29..2026-05-30)
cmdline: ppfeaturemask tuning; aur reduce to mkinitcpio-firmware (3 -> 1).
verify: derive expected ppfeaturemask from KERNEL_PARAMS.
harden: guard optional-tool calls (ip, ping, swapon/zramctl, zcat).

ry-install 7.13.0 - 7.13.5 (2026-05-29)
aur: install unconditionally; drop hardware-gating.
cli: drop RY_INSTALL_* partial-upgrade/cascade/interactive/no-matrix toggles; runtime-vars 6 -> 4.
trim: drop advisory diagnostics.

ry-install 7.12.0 (2026-05-29)
backups: auto .ry.bak for loader.conf, mkinitcpio.conf; add time-sync preflight.

Earlier releases: see git history.
