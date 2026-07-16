Summary of changes
==================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.105.10 - 7.105.15 (2026-07-14 .. 07-15)
--------------------------------
  - env: replace PROTON_FSR4_RDNA3_UPGRADE=1 with FSR4_UPGRADE=1 (long form removed upstream in Proton-CachyOS 11.0-20260702; ENV_VARS count unchanged at 12)
  - boot: replace pcie_aspm=off with pcie_aspm.policy=performance — "off" leaves firmware-programmed ASPM untouched (kernel doc 2e0239d47d75e08); policy=performance actively disables it regardless of BIOS state (KERNEL_PARAMS count unchanged at 17)
  - verify: add _vss_modprobe_stale — fail on any /etc/modprobe.d/60-ry-* drop-in outside SYSTEM_DESTINATIONS (pre-7.99 leftovers); function count 288 -> 289
  - modprobe: NPU-path comment names pcie_aspm.policy=performance as the MT7925 ASPM cover
  - readme: document the Mesa >= 26.0 soft-warn gate in Requirements; note the stale drop-in scan in the --verify row
  - readme: de-dup BIOS intro vs table Note cells, drop repeated --verify-warns and exit-4 mentions, tighten FSR4 + ASPM rows; no facts or values dropped
  - readme: split the Packages Install row into an Install-headed category table (Gaming/CLI/Hardware/RT audio/Firewall/Contrib; Remove/Verify keep their own Action table under a bold "Remove & verify" lead-in); verb-first Flag actions; move root/exit-code detail from the Quick Start alert into Exit Codes (exit 3 gains the root + --check emitter); collapse the BIOS walkthrough into a collapsibility note above it; sentence-split fstab and Safety prose
  - readme: normalize H3 case (Boot/System/User Files); rename Globals -> CachyOS Divergences; backtick the fstab heading; code-format chwd; count the 11 system files in Uninstall; Emitted When header case
  - readme: add Embedded Values — Kernel Parameters (17) / Gaming Environment (12) / Sysctl Overrides (10) tables in declaration order, one-line Effect cells; rationale stays in Tuning Notes
  - readme: precision — DoH divergence tied to plaintext DNS (DNSOverTLS=no), not DNSSEC; full ICMP accept set + invalid-drop named; GPU DPM value auto; RY_RUN_TIMEOUT >9-digit clamp; wpa_supplicant backend + WARN level named; /boot floor gated on separate mount; full phase-verdict set; Divergences reordered to decl order (EPP before sysctl-95); Platform row footnoted as declarative; NO_COLOR empty-string handling marked stricter-than-spec
  - readme: detail — remote-play port sets, paccache -rk2/-ruk0, network probe targets + 37-command GNU roster, mkinitcpio amdgpu + zstd -1 -T0, loader/sdboot values, BlueZ FastConnectable + 3 retries, logind long-press variants, LogLevelMax=notice, MangoHud toggle key, exit-code sentinel note, lock path, Wi-Fi NM-restart DEFER, amd-pstate-epp verify expectation, ESP-fallback note; nothing removed
  - readme: Uninstall gains a disable-before-remove note (nftables unit failure); Out of scope += Secure Boot; Configuration names the profile seam
  - readme: badge/checkout -> 7.105.15
  - readme: precision — resolved-divergence protocol DoH -> DoT (the overridden key is DNSOverTLS; script comment retains DoH until the next script cut); Requirements gate sentence names the Mesa soft-warn + kernel-advisory exceptions; phase-verdict row token is `--` (N/A is the Totals label); free-space warn thresholds gain GiB/MiB; --check row "reads" -> "reports" drift; SKIP_HARDWARE_CHECK row restyled (bare variable, unset default, exact-match =1 note)
  - readme: Units cells -> exact unit names (byte-match MASK/EXPECTED_SERVICES; systemctl unmask copy-safe; systemd-oomd suffixed); Uninstall step-3 revert list -> full paths; Uninstall caveats reordered to step order; Boot-failure fix row gains sdboot-manage update (parity with Phase 5 + the exit-4 hint); env.d purpose adds DXVK + Wine; color-gating note (non-TTY stderr / TERM=dumb); In scope += resolved DNS, logind keys, udev rules, modprobe.d, cpupower governor, regdomain; Out-of-scope dotfiles narrowed to beyond the 2 managed user files; drop the BIOS click/tap note

7.105.5 - 7.105.9 (2026-07-14)
------------------------------
  - readme: Globals table -> prose (values unchanged); Managed Files split into Boot/System/User tables (17 rows, deploy order kept)
  - exit codes: annotate EXIT_GEN_11-14 + EXIT_RUN_TMPFAIL 251 as internal-only sentinels (parity with the 250/255 note); no behavior change
  - lock: document mkdir+pidfile rationale above _acquire_lock (flock intentionally not used)
  - packaging: release archive now store-mode (zip -0) per archive convention
  - kernel: remove enforced floor — drop _ir_validate_kernel_floor fn + call site, retire KERNEL_MIN var; floor kept as advisory comment only (6.18.4: RTL8127 r8169 + suspend-hang fix)
  - validators: 4 -> 3 (counts/keys/post_hooks); function count 289 -> 288
  - readme: kernel row + exit-3 causes + hard-gate list now describe the floor as advisory, not hard-fail
  - readme: trim redundant prose (scope/pactree/fstab/tuning lead-ins); no facts or values dropped
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
