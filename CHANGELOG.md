Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.185.0
-------

  - install-file: an unmanaged path now lists the managed files; the
    branch that printed the list could never be reached
  - cleanup: remove a ry-run tmpdir recursively; a file landing after the
    file-only sweep left the directory behind
  - readme: the MIT link had no LICENSE file to resolve to; LICENSE ships


7.184.0
-------

  - install: drop the six remaining MODE=check guards; the log setup,
    footer, and _err all tested a mode ry-install cannot enter
  - install: drop EXPECTED_VULKAN_PKGS and EXPECTED_SCALING_DRIVER;
    only ry-verify reads them
  - verify: drop _RY_PKG_MANAGED_SERVICES and its set-contradiction arm;
    only ry-install acts on the value
  - counts: ry-install count tripwires 21 -> 20; ry-verify 19 -> 18


7.139.0 - 7.183.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3 and drop the redundant -T0
  - boot: fsck.mode=force -> auto
  - kernel: land on iommu=pt; amd_iommu tokens dropped, amdxdna unblacklisted
  - kernel: drop clearcpuid=umip; emulated since 5.4
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0; wlan0 quit after four tries
  - env: replace PROTON_FSR4_UPGRADE=1 with FSR4_WATERMARK=1
  - env: drop PROTON_ENABLE_WAYLAND=1; per-title opt-in
  - env: add GSK_RENDERER=ngl; GTK4 Vulkan aborts on gfx1151
  - env: 7.181.0 replaces FSR4_WATERMARK=1, a Proton-EM variable inert
    under Proton-CachyOS, with PROTON_FSR4_INDICATOR=1
  - configuration: ICMPv6 base accept added to nftables and asserted by
    verify
  - packages: 7.173.0 adds cachyos-benchmarker
  - sysctl: drop both net.core.netdev_budget keys; squeezed stayed zero
  - sysctl: 7.171.0 drops vm.swappiness=150; the vendor default 100 governs
  - fstab: 7.182.1 the line-count parity probe passed awk a -- separator
    awk reads as a filename, so the probe never ran
  - install: chmod a managed file whose mode drifted while bytes did not
  - install: 7.177.3 post-run hint pointed at ry-install.fish --verify;
    corrected to ry-verify.fish
  - install: 7.179.0 optional-tools warning named seven commands
    ry-install never runs
  - install: 7.182.0 drops the malformed-ext4 awk filter and 7.183.0 the
    MODE=check guards in the loud err and warn helpers
  - install-file: /boot post-hook keys on the exact path, not /boot/*
  - install-file: an unmatched post-hook WARNs, not log-only
  - backup: .ry.bak copies move to ~/ry-install/backups, slash-encoded
  - backup: 7.176.0 drops the .ry.orig preserve; verify reports strays and
    legacy siblings as INFO, nothing auto-removed
  - verify: sweep every cpufreq policy for driver, governor, EPP
  - verify: each non-fallback loader entry carries every token
  - verify: resolved unit-file state; only admin-scope orphan masks reported
  - verify: fail when a kernel parser complaint names a managed token
  - verify: compare cmdline under the file's own UUID when findmnt fails
  - verify: report .ry.bak/.ry.orig copies, fail on an empty one
  - verify: live ext4 mount options for fstab-listed rows, paths decoded
  - verify: assert the MangoHud layout directives and the empty mkinitcpio
    BINARIES and FILES arrays
  - verify: 7.177.3 -h and -v were swallowed after --install-file, an
    option ry-verify does not accept
  - verify: 7.181.0 drops the signal-time mkinitcpio revert and the
    progress teardown and resize handlers; all need install-only state
  - verify: 7.181.0 help listed the _run sentinels 251 and 255, which
    only ry-install can return
  - verify: 7.182.0 drops the unreachable lock release, the loud _err
    branch, _RY_POST_HOOKS and _RY_PHASE_NAMES; none are reachable here
  - verify: 7.182.0 raw-argv peek named ry-install, and a refusal message
    named a function that ships in ry-install
  - verify: 7.183.0 drops the deploy-tmpfile and ry-run sweeps and the
    stuck-tmpfile escalation arm; all need install-only state
  - cleanup: 7.181.0 erases only globals the script can set; 31
    verify-side and 3 install-side names never existed there
  - cleanup: 7.182.0 drops the eight erase targets ry-verify cannot set,
    including the lock trio it never declares
  - cleanup: 7.182.2 stops ry-verify sweeping four tmpfile globs only
    ry-install creates
  - check: record unmanaged 60-ry-* drop-ins before the sudo gate
  - check: mode-only drift sets drift, matching verify
  - preflight: the nftables ipv6.disable=1 coupling gate warns, not refuses
  - preflight: sync the _ir_validate_counts tripwire; stale count refused
    rc 3
  - preflight: _ir_validate_post_hooks refuses a broken 1:1 index mirror
  - logging: millisecond JSONL timestamps; CHECK_GREP uses key=value
  - help: print the backups path beside the log path
  - help: 7.177.2 - 7.180.0 each script names its counterpart instead of
    claiming to be self-contained; RY_RUN_TIMEOUT drops from ry-verify
  - summary: aligned columns replace the box-drawn table; 4 fns collapse
    to 1
  - split: 7.177.0 moves verify and check to ry-verify.fish; ry-install.fish
    keeps install and install-file
  - split: shared functions are duplicated verbatim; the parity cert
    enforces byte-identical bodies outside the declared variants
  - split: 7.177.1 - 7.180.0 shed every arm, gate, banner and comment each
    script carried for its counterpart, including all 17 _post_* handlers
  - counts: 7.177.0 ships 2 scripts; version sync sites 4 -> 6, release
    zip entries 5 -> 6
  - counts: KERNEL_PARAMS 15 -> 14, ENV_VARS 9 -> 10, SYSCTL_VALUES 9 -> 8,
    PKGS_ADD 16 -> 17
  - counts: 7.182.0 splits the exit constants per script; ry-verify count
    tripwires 21 -> 19, then _RY_TMPDIR_GLOBS 6 -> 2 at 7.182.2


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS nftables gate


7.135.0 - 7.136.1
-----------------

  - install: fix .ry.orig preserve dead under an if-scoped set -l
  - check: record unmanaged 60-ry-* drop-ins and masked units absent from MASK
  - preflight: refuse overlaps: PKGS_ADD/PKGS_DEL, MASK/EXPECTED_SERVICES


7.132.0 - 7.134.0
-----------------

  - summary: abort path used the normal path's name for the phase-3 row
  - preflight: read the CPU model via cat; a missing cpuinfo warned


7.130.0 - 7.131.1
-----------------

  - perf: governor and EPP performance, GPU DPM level high


7.123.0 - 7.129.0
-----------------

  - dns: pin upstreams in resolved and the NM global-dns section
  - kernel: add mt7925e.disable_aspm=1
  - sysctl: add kernel.nmi_watchdog=0
  - env: FSR4_UPGRADE -> PROTON_FSR4_UPGRADE; drop VKD3D_CONFIG
  - color: NO_COLOR needs a non-empty value


7.118.0 - 7.122.0
-----------------

  - services: mask ufw instead of removing; MASK 10 -> 11, PKGS_DEL 10 -> 9
  - services: nftables-first gate on the mask path withholds ufw.service


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers
  - boot: mkinitcpio.conf snapshot and byte-exact revert
  - fstab: atomic replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only; live or ambiguous pidfiles fail closed
  - preserve: one-time .ry.orig for differing non-boot files at adoption


7.100.0 - 7.107.3
-----------------

  - configuration: 17 configs deployed atomically via temp+backup+mv -T
  - packages: -Rns rdep-aware via pactree; PKGS_ADD re-marked explicit
  - verify: SHA256 static checksum, installed vs generated bytes
  - boot: boot-critical failures exit 4 and skip finalization


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
