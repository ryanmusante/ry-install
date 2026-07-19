Summary of changes
==================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.119.0 (2026-07-18)
--------------------
  - changelog: 7.117.0 folded into the range entry
  - readme + source: version sync

7.118.0 (2026-07-18)
--------------------
  - services: ufw masked, not removed - MASK 10 -> 11 (+ufw.service), PKGS_DEL 10 -> 9 (-ufw)
  - services: nftables-first gate moved from the removal path to the mask path; on an
    unconfirmed ruleset the ufw.service mask is withheld for the run (mask --now stops
    ufw and ufw-init stop flushes - never before default-deny is live)
  - nftables.conf: embedded header now reads "ufw masked" (one-time drift + redeploy)
  - readme: flow, warning, packages, units, uninstall synced

7.108.0 - 7.117.0 (2026-07-17 .. 07-18)
---------------------------------------
  - cmdline: drop 8250.nr_uarts=0, tsc=reliable, nowatchdog (17 -> 14)
  - env: POWERDEVIL_NO_DDCUTIL=1 via environment.d (per-service drop-in retired); drop AMD_VULKAN_ICD=RADV, DXVK_LOG_PATH=none (11 vars)
  - services: ufw removed instead of masked (PKGS_DEL 9 -> 10) — nftables default-deny confirmed live, then flush -> disable -> unmask -> -Rns; removal defers while the live ruleset is unconfirmed
  - services: mask net 12 -> 10 (ModemManager.service and ufw.service out, NetworkManager-wait-online.service re-added)
  - packages: drop git-delta, ddcutil (PKGS_ADD 18 -> 16)
  - resolved: DNSSEC allow-downgrade -> no
  - deploy: one-time first-adoption preserve <dst>.ry.orig for differing pre-existing non-boot files
  - verify: user-unit health check (plasma-powerdevil must not be failed; any failed --user unit warns)
  - install: environment.d changes live-apply to PowerDevil (user daemon-reload + restart)
  - nftables: input chain reordered to the Arch default shape; header comment synced
  - readme: libvirt/QEMU NAT known-interaction note (forward drop breaks guest WAN; virbr0 accept snippet); trim passes; counts synced
  - changelog + source: restyle and comment trim passes

7.107.3 (2026-07-16)
--------------------
  - changelog: 7.60.0 - 7.99.1 folded into the history-trim line
  - source + readme: trim pass

7.107.2 (2026-07-16)
--------------------
  - fix: root pre-scan drops the stale -V case; root --check -V exits 2 with usage
  - readme: Sysctl Overrides table folded to prose
  - packaging: release zip ships ry-install.fish 0755

7.106.0 - 7.107.1 (2026-07-15)
------------------------------
  - remove: --verbose/-V, modprobe stale scan, NTP auto-enable + RTC writeback (unsynced clock warns only), recycled-PID lock rescue, Mesa soft-warn (functions 289 -> 286)
  - fix: MASK ModemManager.service casing; resolved comment DoH -> DoT
  - source: +5 section banners
  - readme: wording synced; Requirements 6 -> 4 rows

7.105.5 - 7.105.15 (2026-07-14 .. 07-15)
----------------------------------------
  - env: FSR4_UPGRADE=1 replaces PROTON_FSR4_RDNA3_UPGRADE=1
  - boot: pcie_aspm.policy=performance replaces pcie_aspm=off
  - kernel: enforced floor removed; 6.18.4 advisory only
  - verify: modprobe stale scan added; internal exit sentinels annotated
  - packaging: store-mode zip
  - readme + changelog: tables split, history condensed to range summaries

7.100.0 - 7.105.4 (2026-07-11 .. 07-14)
---------------------------------------
  - kernel: KERNEL_MIN 6.19 -> 6.18.4; MES floor re-anchored
  - boot: pcie_aspm.policy=performance -> pcie_aspm=off; drop mt7925e disable_aspm=1
  - values: add VKD3D_CONFIG=descriptor_heap and vm.watermark_boost_factor=0; packages: drop archlinux-contrib
  - source: comment/header/data-row condensation; ntp: scan openntpd; accept comment-only modprobe drop-in

7.99.1 and earlier
------------------
  - History trimmed. See git tags for the full record.
