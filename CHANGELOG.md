Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.172.0
-------

  - summary: render the run summary as aligned columns instead of a
    box-drawn table; four render functions collapse to one


7.171.0
-------

  - sysctl: drop vm.swappiness=150; the CachyOS vendor default of 100
    now governs, and zram sizing is unchanged
  - install: repair a managed file whose mode drifted while its bytes
    did not; the byte-compare used to return before the chmod
  - check: mode-only drift now sets drift, matching verify
  - counts: SYSCTL_VALUES 9 to 8
  - style: restore backslash continuations on the six printf bodies
    that emit one config or message line per source line


7.170.0
-------

  - style: join 11 backslash-continued statements, 4,997 -> 4,971 lines


7.169.0
-------

  - preflight: _ir_validate_post_hooks now asserts that _RY_POST_HOOKS
    mirrors the destination arrays 1:1 by index, and refuses on a break
  - install-file: an unmatched post-hook now emits a WARN, not a log-only
    line, so a deployed-but-not-live-applied file is visible on stderr


7.168.0
-------

  - install-file: /boot post-hook now keys on the exact path, not
    the glob /boot/*, so a new /boot file cannot misroute to loader


7.167.0
-------

  - verify: match live ext4 mounts to fstab entries by decoded path, so
    an escaped space in a mount point no longer skips the check


7.139.0 - 7.166.0
-----------------

  - boot: drop the redundant -T0 from MKINITCPIO_COMPRESSION_OPTIONS
  - boot: fsck.mode=force -> auto; force checked the ext4 root every boot
  - boot: MKINITCPIO_COMPRESSION_OPTIONS -1 -> -3; smaller initramfs
  - kernel: drop clearcpuid=umip; emulated since 5.4 and it taints
  - kernel: amd_iommu=off -> amd_iommu=on iommu=pt for the XDNA NPU
  - kernel: BLACKLIST_AMDXDNA true -> false; the amdxdna driver loads
  - kernel: drop amd_iommu=on; the parser has no on branch
  - dns: drop the pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: emit autoconnect-retries-default=0; wlan0 gave up after four
    tries at the daily group-rekey drop
  - env: replace PROTON_FSR4_UPGRADE=1 with FSR4_WATERMARK=1
  - env: drop PROTON_ENABLE_WAYLAND=1; winewayland is a per-title opt-in
  - env: add GSK_RENDERER=ngl; the GTK4 Vulkan renderer aborts on gfx1151
  - configuration: ship cpu_stats commented in the MangoHud generator
  - configuration: add the ICMPv6 base accept to the nftables generator
  - configuration: fix the MASK comment; masking avahi drops mDNS entirely
  - sysctl: drop both net.core.netdev_budget keys; squeezed stayed zero
  - verify: assert the ICMPv6 base accept in the nftables ruleset
  - verify: sweep every cpufreq policy for driver, governor and EPP
  - verify: assert each non-fallback loader entry carries every token
  - verify: check the systemd-resolved unit-file state and report only
    admin-scope orphan masks
  - verify: log the root filesystem type and the ext4 fstab entry count
  - verify: assert autoconnect-retries-default=0 in the NM drop-in
  - verify: fail when a kernel parser complaint names a managed token
  - verify: compare /etc/kernel/cmdline under the UUID in the file when
    findmnt cannot resolve the root UUID
  - verify: report .ry.bak and .ry.orig copies, failing on an empty one
  - verify: check live ext4 mount options, not only the fstab rows
  - verify: check live ext4 mount options only for filesystems listed
    in fstab, not every mounted ext4
  - check: record unmanaged 60-ry-* drop-ins before the sudo gate
  - preflight: the nftables ipv6.disable=1 coupling gate warns, not refuses
  - preflight: optional tool probe drops free, uptime, swapon and zramctl,
    and adds readlink
  - preflight: sync the _ir_validate_counts tripwire to KERNEL_PARAMS 15;
    left at 14 it refused every run at rc 3
  - logging: millisecond JSONL timestamps; CHECK_GREP records use key=value
  - counts: ENV_VARS 9 to 10
  - counts: KERNEL_PARAMS 15 to 14


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS gate and its
    inbound rules from the nftables generator


7.135.0 - 7.136.1
-----------------

  - install: fix the one-time <path>.ry.orig preserve never running for
    non-boot managed files; a set -l inside an if block does not leak
  - check: record unmanaged 60-ry-* drop-ins and masked units absent from MASK
  - preflight: refuse a package in both PKGS_ADD and PKGS_DEL, or a unit
    in both MASK and EXPECTED_SERVICES


7.132.0 - 7.134.0
-----------------

  - summary: abort path recorded the phase-3 row under the normal path's name
  - preflight: read the CPU model through cat; a missing /proc/cpuinfo
    made the redirect warn
  - verify: warn on unmanaged /etc/modprobe.d/60-ry-*.conf drop-ins


7.130.0 - 7.131.1
-----------------

  - perf: cpu governor and p-state epp set to performance, gpu dpm level high


7.123.0 - 7.129.0
-----------------

  - dns: upstreams pinned in the resolver drop-in and the NetworkManager
    global-dns section, which per-link config outranks
  - kernel: add mt7925e.disable_aspm=1; global policy governs link state only
  - sysctl: add kernel.nmi_watchdog=0; nothing set what the check asserted
  - env: rename FSR4_UPGRADE to PROTON_FSR4_UPGRADE and drop
    VKD3D_CONFIG=descriptor_heap
  - color: NO_COLOR now needs a non-empty value to disable color
  - counts: KERNEL_PARAMS 14 to 15, SYSCTL_VALUES 10 to 11, ENV_VARS 11 to 10


7.118.0 - 7.122.0
-----------------

  - services: ufw is masked, not removed - MASK 10 -> 11 (+ufw.service),
    PKGS_DEL 10 -> 9 (-ufw)
  - services: nftables-first gate moved to the mask path; an unconfirmed
    ruleset withholds the ufw.service mask


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers
  - boot: mkinitcpio.conf snapshot and revert with byte-exact compare
  - fstab: atomic replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only; live or ambiguous pidfiles fail closed
  - preserve: one-time <path>.ry.orig for non-boot managed files whose
    content differed at first adoption


7.100.0 - 7.107.3
-----------------

  - configuration: 17 embedded configs deployed atomically - temp file on
    the same filesystem, pre-validation, backup, mv -T, re-read
  - packages: pacman -Rns made rdep-aware via pactree; PKGS_ADD re-marked
    explicit after -Syu
  - verify: static checksum compares installed to generated bytes by SHA256
  - boot: boot-critical failures exit 4 and skip finalization


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro: kernel parameters,
    mkinitcpio, sysctl, udev, session environment and systemd-boot
