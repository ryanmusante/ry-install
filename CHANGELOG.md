Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.180.0
-------

  - verify: drop the 17 _post_* handlers; ry-install dispatches them and
    the table validator keeps the destination-mirror check
  - verify: prune the install-only arms the split left in the shared
    root-UUID resolver; drop install's check-only cleanup branch
  - verify: mode selection re-set MODE to verify, the value it held;
    --check is the only flag that moves it
  - verify: assert the MangoHud layout directives and the empty
    mkinitcpio BINARIES/FILES arrays
  - verify: refusal text said "refuse to deploy" and pointed the
    hardware override at ry-install.fish
  - help: drop "Self-contained"; each script is half of a pair
  - readme: the tools row named coreutils only; findmnt, awk, grep, find
    and curl are hard preflight dependencies too
  - changelog: the 7.177.0 zip-entry count named the release shape


7.179.1
-------

  - install: drop the write-only root-refusal argv classifier; only
    ry-verify reads that result, for its silent --check path
  - style: two ry-verify banners named install-only machinery, an
    instance lock and a pinned progress bar


7.179.0
-------

  - install: the optional-tools warning named seven commands ry-install
    never runs; ry-verify guards its own at each call site


7.178.0
-------

  - install: drop the --check argv peek; ry-install has no --check mode,
    so the flag and its two guards could never fire
  - install: --verify leaves the root-argv classifier; the catch-all arm
    already gives it the same classification
  - verify: drop the timeout(1) preflight gates; the command runner they
    protect ships only in ry-install
  - style: two ry-install comments named flags that script does not accept


7.177.3
-------

  - verify: -h and -v were swallowed after --install-file, an option
    ry-verify does not accept; the early intercept no longer skips it
  - verify: drop the unreachable --install-file arms from the root-argv
    classifier and its argparse peek
  - install: post-run hint pointed at ry-install.fish --verify; corrected
    to ry-verify.fish
  - style: retitle 4 ry-verify banners that named install-only surfaces;
    drop the empty instance-lock banner left by the split


7.177.2
-------

  - help: both scripts described themselves as a single script; each now
    names its counterpart
  - help: drop RY_RUN_TIMEOUT from ry-verify; the timeout wrapper it tunes
    ships only in ry-install
  - verify: sudo-lapse remedy in the config-access gate said re-run
    ry-install; corrected to ry-verify


7.177.1
-------

  - verify: source guard message named ry-install; corrected to ry-verify


7.177.0
-------

  - split: verify and check move to ry-verify.fish; ry-install.fish keeps
    install and install-file
  - split: 102 shared functions duplicated verbatim; parity cert enforces
    byte-identical bodies with 2 declared per-script variants
  - counts: 2 scripts; version sync sites 4 -> 6; release zip entries
    5 -> 6 (topdir and LICENSE included)


7.139.0 - 7.176.0
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
  - configuration: ship cpu_stats commented in the MangoHud generator
  - configuration: ICMPv6 base accept added to nftables and asserted by verify
  - packages: 7.173.0 adds cachyos-benchmarker; [cachyos] benchmark suite
  - sysctl: drop both net.core.netdev_budget keys; squeezed stayed zero
  - sysctl: 7.171.0 drops vm.swappiness=150; the vendor default 100 governs
  - install: chmod a managed file whose mode drifted while bytes did not
  - install-file: /boot post-hook keys on the exact path, not /boot/*
  - install-file: an unmatched post-hook WARNs, not log-only
  - backup: .ry.bak copies move to ~/ry-install/backups, slash-encoded
  - backup: 7.176.0 drops the .ry.orig preserve; verify reports strays and
    legacy siblings as INFO, nothing auto-removed
  - verify: sweep every cpufreq policy for driver, governor, EPP
  - verify: each non-fallback loader entry carries every token
  - verify: resolved unit-file state; only admin-scope orphan masks reported
  - verify: assert autoconnect-retries-default=0 in the NM drop-in
  - verify: fail when a kernel parser complaint names a managed token
  - verify: compare cmdline under the file's own UUID when findmnt fails
  - verify: report .ry.bak/.ry.orig copies, fail on an empty one
  - verify: live ext4 mount options for fstab-listed rows, paths decoded
  - check: record unmanaged 60-ry-* drop-ins before the sudo gate
  - check: mode-only drift sets drift, matching verify
  - preflight: the nftables ipv6.disable=1 coupling gate warns, not refuses
  - preflight: optional probe drops free/uptime/swapon/zramctl, adds readlink
  - preflight: sync the _ir_validate_counts tripwire; stale count refused rc 3
  - preflight: _ir_validate_post_hooks refuses a broken 1:1 index mirror
  - logging: millisecond JSONL timestamps; CHECK_GREP uses key=value
  - help: print the backups path beside the log path
  - summary: aligned columns replace the box-drawn table; 4 fns collapse to 1
  - style: join continuations and adjacent statement pairs; 4,997 -> 4,945
  - style: restore continuations on six one-emitted-line-per-source printfs
  - counts: KERNEL_PARAMS 15 -> 14, ENV_VARS 9 -> 10, SYSCTL_VALUES 9 -> 8,
    PKGS_ADD 16 -> 17


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
  - counts: KERNEL_PARAMS 14 to 15, SYSCTL_VALUES 10 to 11, ENV_VARS 11 to 10


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
