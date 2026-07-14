Summary of changes
==================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.105.6 (2026-07-14)
--------------------
  - readme: trim redundant prose (scope/pactree/fstab/tuning lead-ins); no facts or values dropped

7.105.5 (2026-07-14)
--------------------
  - readme: add Note column to BIOS table; move per-setting rationale out of the intro prose

7.104.0 - 7.105.4 (2026-07-14)
------------------------------
  - readme: add Default column to Environment Overrides; move defaults out of Effect prose
  - comments: condense long-line inline notes to vital rationale; trim KERNEL_MIN + pactree/paccache notes
  - headers: consistent "PHASE 4:" prefix; merge adjacent Phase 4 headers; Phase 3 -> CONFIGURATION
  - data: reflow PKGS_ADD/SYSCTL_VALUES/SYSTEM_DESTINATIONS/_RY_POST_HOOKS to packed rows (order/counts unchanged)
  - changelog: trim history; condense pre-7.100 ranges to per-range summaries

7.103.0 (2026-07-13)
--------------------
  - kernel: relax KERNEL_MIN 6.19 -> 6.18.4; 3-part floor compare (MAJOR.MINOR.PATCH)
  - kernel: KERNEL_MIN rationale rewrite (gfx1151 fix is firmware, not kernel)

7.102.0 - 7.102.2 (2026-07-12)
------------------------------
  - boot: pcie_aspm.policy=performance -> pcie_aspm=off; drop mt7925e disable_aspm=1
  - env.d: add VKD3D_CONFIG=descriptor_heap; sysctl: add vm.watermark_boost_factor=0
  - validate: accept comment-only modprobe drop-in

7.101.0 (2026-07-12)
--------------------
  - comments: trim verbose inline notes to vital rationale

7.100.0 (2026-07-11)
--------------------
  - kernel: re-anchor MES floor to post-0x83 (reverted upstream 2025-12-01)
  - packages: drop archlinux-contrib (PKGS_ADD 19 -> 18)
  - ntp: scan openntpd.service in the NTP-client conflict guard

7.98.0 - 7.99.1 (2026-07-09 .. 07-11)
-------------------------------------
  - modprobe: merge drop-ins into 60-ry-modules.conf; add BLACKLIST_AMDXDNA toggle + IOMMU guard
  - verify: lsmod blacklist check; COMPRESSION= compare; EPP/scaling-driver assertions
  - signal: hold --check stderr-silence through the pre-argparse window
  - guards: managed destinations 18 -> 17

7.94.0 - 7.97.3 (2026-07-06 .. 07-08)
-------------------------------------
  - services: mask avahi .service+.socket (MASK 10 -> 12)
  - backup: .ry.bak + post-write verify/restore for the 4 boot files; nft -c pre-validate
  - udev: GPU rule DEVTYPE -> ENV{DEVTYPE}; cmdline: clearcpuid=umip (version-stable)
  - dispatch: single _RY_ARGPARSE_SPEC global + count tripwire

7.85.0 - 7.93.0 (2026-07-01 .. 07-05)
-------------------------------------
  - args: root guard defers to argparse (invalid exit 2); root --check silent exit 3; refuse stdin/pipe
  - install-file: format-validate before write; loader.conf regenerates entries only; resolve $BOOT first
  - cmdline: add ipv6.disable=1 (IPv4-only ruleset, inbound ping); fstab atime-variant rewrite
  - run: hard-cap long ops 7200s; timeout clamp; overflow analysis
  - lock: refuse reclaim on garbage pidfile; PID-scoped tmpfiles

7.60.0 - 7.84.0 (2026-06-21 .. 07-01)
-------------------------------------
  - kernel: KERNEL_MIN 6.18 -> 6.19; add kernel-floor + key validators
  - cmdline: iommu=pt -> amd_iommu=off; cpupower governor -> powersave; EPP -> balance_performance
  - bluetooth: main.conf + reconnect=3; net: wpa_supplicant, powersave=2, mask modemmanager
  - env: PROTON_FSR4_RDNA3_UPGRADE=1, RY_REMOTE_PLAY_PORTS; generators reject control chars
  - guards: destinations 17 -> 15

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
