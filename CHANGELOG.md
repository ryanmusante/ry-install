Summary of changes
==================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.115.0 (2026-07-18)
--------------------
  - readme: libvirt known-interaction note condensed to vital information (mechanism one-liner, snippet, no-duplicate-NAT, verify commands)
  - readme: full information verify vs script values — loader/sdboot/resolved/NM/BT/cpupower/regdom/EPP/DPM tokens, remote-play port sets, log path, perms, managed-file split all confirmed accurate; ufw reverse-dependency check: no hard reverse dependency on this profile (gufw/ufw-extras not installed; desktop integrations list ufw as optional), removal stays pactree-gated at run time

7.114.0 (2026-07-18)
--------------------
  - readme: line-by-line trim to vital information (prose + table cells; libvirt note tightened)
  - readme: cmdline row count synced (14 KERNEL_PARAMS); stale ddcutil troubleshooting row dropped

7.113.0 (2026-07-18)
--------------------
  - changelog: restyled to terse per-area lines
  - source: comment trim pass (vital information only)
  - readme: badge/checkout synced

7.112.0 (2026-07-18)
--------------------
  - cmdline: drop nowatchdog (15 -> 14); NMI watchdog stays off via vendor sysctl + watchdog-module blacklists, soft-lockup detector returns to kernel default
  - services: mask NetworkManager-wait-online.service (MASK 9 -> 10)
  - env: drop DXVK_LOG_PATH=none (11 vars; inert under DXVK_LOG_LEVEL=none)

7.111.0 (2026-07-18)
--------------------
  - services: remove ufw instead of masking (MASK 10 -> 9, PKGS_DEL 9 -> 10); nftables default-deny confirmed live before flush -> disable -> unmask -> -Rns, removal defers while the live ruleset is unconfirmed
  - readme: document libvirt/QEMU NAT vs the forward drop (nftables backend since libvirt 10.4.0) with the virbr0 accept snippet; managed ruleset unchanged
  - nftables: header comment synced (ufw masked -> removed)

7.110.0 (2026-07-18)
--------------------
  - env: drop AMD_VULKAN_ICD=RADV (12 vars; read only by amdvlk's switchable-graphics layer, profile ships RADV only)
  - nftables: input chain reordered to the Arch default shape (invalid drop, established/related, loopback); live-applies via post-hook
  - readme: Session Environment table synced

7.109.0 (2026-07-18)
--------------------
  - env: POWERDEVIL_NO_DDCUTIL=1 moves from the user drop-in to environment.d (managed 18 -> 17, user files 3 -> 2, hooks 18 -> 17); delete the deployed drop-in by hand on migration
  - deploy: one-time first-adoption preserve <dst>.ry.orig for differing pre-existing non-boot files
  - verify: user-unit health check (plasma-powerdevil must not be failed; any failed --user unit warns)
  - install: environment.d changes live-apply to PowerDevil (user daemon-reload + restart)
  - readme: counts and tables synced

7.108.0 (2026-07-17)
--------------------
  - env: PowerDevil DDC/CI opt-out drop-in added as managed file 18 with user-scope live-apply hook
  - cmdline: drop 8250.nr_uarts=0 and tsc=reliable (17 -> 15)
  - packages: drop git-delta and ddcutil (18 -> 16); mask: drop NetworkManager-wait-online.service and ModemManager.service (12 -> 10)
  - resolved: DNSSEC allow-downgrade -> no
  - readme: counts and tables synced

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
