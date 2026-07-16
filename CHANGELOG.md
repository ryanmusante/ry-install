Summary of changes
==================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.107.2 (2026-07-16)
--------------------
  - fix: drop the stale -V case from the root pre-scan (flag removed in 7.106.0); root --check -V now exits 2 with usage, matching non-root
  - readme: Sysctl Overrides table -> brief prose; badge/checkout -> 7.107.2
  - packaging: release zip ships ry-install.fish with mode 0755 (was 0644)

7.106.0 - 7.107.1 (2026-07-15)
------------------------------
  - remove: --verbose/-V flag (stream emitter retained for error paths); _vss_modprobe_stale scan; NTP auto-enable + RTC writeback — an unsynced clock now warns only; _lock_pid_started_after recycled-PID rescue (dead-PID stale reclaim retained); Mesa soft-warn + kernel-advisory notes; functions 289 -> 286
  - fix: MASK modemmanager.service -> ModemManager.service (unit lookup is case-sensitive; the lowercase mask never matched); resolved-divergence comment DoH -> DoT
  - source: +5 section banners (fstab atomic replace, post-hooks hardware/firewall, verify-static boot, atomic-write public entry, entry greps)
  - readme: flags/NTP/lock/uninstall wording synced; Requirements 6 -> 4 rows; Mask cell casing; badge/checkout -> 7.107.1

7.105.5 - 7.105.15 (2026-07-14 .. 07-15)
----------------------------------------
  - env: FSR4_UPGRADE=1 replaces PROTON_FSR4_RDNA3_UPGRADE=1 (long form removed in Proton-CachyOS 11.0-20260702)
  - boot: pcie_aspm.policy=performance replaces pcie_aspm=off — actively disables ASPM regardless of BIOS state
  - kernel: enforced floor removed — 6.18.4 advisory only; validators 4 -> 3
  - verify: _vss_modprobe_stale added (unmanaged 60-ry-* scan); exit codes 11-14 + 251 annotated internal-only; packaging: archive -> store-mode (zip -0)
  - readme: Embedded Values tables (17/12/10); Managed Files split into Boot/System/User; consistency + precision fixes; trim to vital (BIOS table -> linked walkthrough)
  - changelog: history condensed to range summaries

7.100.0 - 7.105.4 (2026-07-11 .. 07-14)
---------------------------------------
  - kernel: KERNEL_MIN 6.19 -> 6.18.4 (3-part compare; gfx1151 fix is firmware); MES floor re-anchored post-0x83
  - boot: pcie_aspm.policy=performance -> pcie_aspm=off; drop mt7925e disable_aspm=1
  - values: +VKD3D_CONFIG=descriptor_heap, +vm.watermark_boost_factor=0; packages: drop archlinux-contrib (PKGS_ADD -> 18)
  - source: comment/header/data-row condensation; readme: Env Overrides Default column; ntp: scan openntpd; accept comment-only modprobe drop-in

7.60.0 - 7.99.1 (2026-06-21 .. 07-11)
-------------------------------------
  - configs: modprobe drop-ins merged into 60-ry-modules.conf + BLACKLIST_AMDXDNA/IOMMU guard; bluetooth main.conf; NM wpa_supplicant + powersave=2; cmdline: ipv6.disable=1, clearcpuid=umip
  - power: amd_iommu=off; governor powersave; EPP balance_performance; services: avahi pair + modemmanager masked (MASK -> 12)
  - safety: .ry.bak + post-write verify/restore for the 4 boot files; nft -c pre-validate; root-guard argparse, silent root --check exit 3; lock-reclaim hardening; 7200s long-op cap
  - verify: lsmod blacklist / COMPRESSION= / EPP assertions; guards: managed destinations settle at 15 (+2 user)

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
