Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.186.1
-------

  - logging: each preflight check logs *_CHECK_OK or *_CHECK_FAIL after its
    *_CHECK_START; the TIME_SYNC tokens take the _CHECK_ stem
  - verify: the root pre-scan takes the argparse abbreviations of --check;
    root -c exited 2 loud where --check exits 3 silent
  - readme: Requirements names id among the ry-verify start gates
  - changelog: fold 7.184.0 - 7.186.0 into the range; trim older blocks


7.139.0 - 7.186.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0; fsck.mode=force -> auto
  - kernel: land on iommu=pt, amd_iommu tokens dropped, amdxdna
    unblacklisted; drop clearcpuid=umip, emulated since 5.4
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0; wlan0 quit after four tries
  - env: PROTON_FSR4_UPGRADE=1 -> FSR4_WATERMARK=1, inert under
    Proton-CachyOS, -> PROTON_FSR4_INDICATOR=1 at 7.181.0
  - env: drop PROTON_ENABLE_WAYLAND=1, per-title opt-in; add
    GSK_RENDERER=ngl, GTK4 Vulkan aborts on gfx1151
  - configuration: ICMPv6 base accept in nftables, asserted by verify
  - packages: 7.173.0 adds cachyos-benchmarker
  - sysctl: drop both net.core.netdev_budget keys, squeezed stayed zero;
    7.171.0 drops vm.swappiness=150, the vendor default 100 governs
  - fstab: 7.182.1 parity probe never ran, awk reads its -- as a filename
  - install: chmod a managed file whose mode drifted while bytes did not
  - install: 7.177.3 post-run hint named ry-install.fish --verify; 7.179.0
    optional-tools warning named seven commands ry-install never runs
  - install: 7.182.0 drops the malformed-ext4 awk filter; 7.183.0 - 7.184.0
    the MODE=check guards, EXPECTED_VULKAN_PKGS, EXPECTED_SCALING_DRIVER
  - install-file: /boot post-hook keys on the exact path; an unmatched
    post-hook WARNs
  - install-file: 7.185.0 an unmanaged path now lists the managed files
  - backup: .ry.bak copies move to ~/ry-install/backups, slash-encoded;
    7.176.0 drops the .ry.orig preserve, strays reported as INFO
  - verify: sweep every cpufreq policy for driver, governor, EPP; each
    non-fallback loader entry carries every token
  - verify: resolved unit-file state, only admin-scope orphan masks
    reported; fail when a kernel parser complaint names a managed token
  - verify: compare cmdline under the file's own UUID when findmnt fails;
    report .ry.bak/.ry.orig copies, fail on an empty one; assert MangoHud
  - verify: live ext4 mount options for fstab-listed rows, paths decoded;
    assert the empty mkinitcpio BINARIES and FILES
  - verify: 7.177.3 -h and -v were swallowed after --install-file; 7.181.0
    help listed the _run sentinels 251 and 255
  - verify: 7.181.0 drops the signal-time mkinitcpio revert and progress
    handlers; 7.182.0 the lock release, _RY_POST_HOOKS, _RY_PHASE_NAMES
  - verify: 7.182.0 raw-argv peek and a refusal message named ry-install;
    7.183.0 - 7.184.0 drop the sweeps and stuck-tmpfile arm, install-only
  - cleanup: 7.181.0 - 7.182.2 erase and sweep only names and globs each
    script can set; 7.185.0 remove a ry-run tmpdir recursively
  - check: record 60-ry-* drop-ins before the sudo gate; mode drift sets drift
  - preflight: the nftables ipv6.disable=1 coupling gate warns, not
    refuses; _ir_validate_post_hooks refuses a broken 1:1 index mirror
  - preflight: a stale _ir_validate_counts tripwire refused rc 3; 7.185.1
    NM_WIFI_POWERSAVE takes 0-3, all NetworkManager accepts
  - logging: millisecond JSONL timestamps; CHECK_GREP uses key=value
  - help: print the backups path beside the log path; 7.177.2 - 7.180.0
    each script names its counterpart, RY_RUN_TIMEOUT drops from ry-verify
  - summary: aligned columns replace the box-drawn table; 4 fns -> 1
  - split: 7.177.0 moves verify and check to ry-verify.fish, shared functions
    duplicated verbatim; 7.177.1 - 7.180.0 shed every arm for the counterpart
  - counts: 7.177.0 ships 2 scripts; version sync sites 4 -> 6, zip
    entries 5 -> 6; KERNEL_PARAMS 15 -> 14, ENV_VARS 9 -> 10
  - counts: SYSCTL_VALUES 9 -> 8, PKGS_ADD 16 -> 17; 7.182.0 splits the exit
    constants; 7.184.0 tripwires 21 -> 20 and, in ry-verify, 21 -> 18


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS nftables gate


7.135.0 - 7.136.1
-----------------

  - install: fix .ry.orig preserve dead under an if-scoped set -l
  - check: record 60-ry-* drop-ins and masked units absent from MASK
  - preflight: refuse PKGS_ADD/PKGS_DEL and MASK/EXPECTED_SERVICES overlaps


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

  - services: mask ufw instead of removing, MASK 10 -> 11, PKGS_DEL 10 -> 9;
    the nftables-first gate on the mask path withholds ufw.service


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers
  - boot: mkinitcpio.conf snapshot and byte-exact revert
  - fstab: atomic replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only, live or ambiguous pidfiles fail closed
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
