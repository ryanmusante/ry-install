Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.165.0
-------

  - verify: scan the boot ring buffer for kernel parser rejections and
    fail when a complaint names a managed cmdline token
  - verify: compare /etc/kernel/cmdline under the UUID found in the file
    when findmnt cannot resolve the root UUID, instead of skipping
  - verify: report .ry.bak and .ry.orig copies, failing on an empty one
  - verify: check live ext4 mount options, not only the fstab rows


7.164.0
-------

  - kernel: drop amd_iommu=on; the parser has no on branch and the kernel
    logs AMD-Vi: Unknown option - 'on'
  - verify: assert autoconnect-retries-default=0 in the NM drop-in
  - counts: KERNEL_PARAMS 15 to 14


7.163.0
-------

  - env: add GSK_RENDERER=ngl; the GTK4 Vulkan renderer aborts on gfx1151
  - network: emit autoconnect-retries-default=0; wlan0 gave up after four
    tries at the daily group-rekey drop
  - counts: ENV_VARS 9 to 10


7.139.0 - 7.162.2
-----------------

  - boot: drop the redundant -T0 from MKINITCPIO_COMPRESSION_OPTIONS
  - boot: fsck.mode=force -> auto; force checked the ext4 root every boot
  - boot: MKINITCPIO_COMPRESSION_OPTIONS -1 -> -3; smaller initramfs
  - kernel: drop clearcpuid=umip; emulated since 5.4 and it taints
  - kernel: amd_iommu=off -> amd_iommu=on iommu=pt for the XDNA NPU
  - kernel: BLACKLIST_AMDXDNA true -> false; the amdxdna driver loads
  - dns: drop the pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - env: replace PROTON_FSR4_UPGRADE=1 with FSR4_WATERMARK=1
  - env: drop PROTON_ENABLE_WAYLAND=1; winewayland is a per-title opt-in
  - configuration: ship cpu_stats commented in the MangoHud generator;
    cpu_custom_temp_sensor is inert on this APU
  - configuration: add the ICMPv6 base accept to the nftables generator
  - configuration: correct the MASK comment; masking avahi with
    MulticastDNS=no leaves no mDNS responder at all
  - sysctl: drop both net.core.netdev_budget keys; squeezed stayed zero
  - verify: assert the ICMPv6 base accept in the nftables ruleset
  - verify: sweep every cpufreq policy for driver, governor and EPP
  - verify: assert each non-fallback loader entry carries every token
  - verify: check the systemd-resolved unit-file state and report only
    admin-scope orphan masks
  - verify: log the root filesystem type and the ext4 fstab entry count
  - check: record unmanaged 60-ry-* drop-ins before the sudo gate
  - preflight: the nftables ipv6.disable=1 coupling gate warns, not refuses
  - preflight: drop free, uptime, swapon and zramctl from the optional
    tool probe
  - preflight: add readlink to the optional tool probe
  - preflight: sync the _ir_validate_counts tripwire to KERNEL_PARAMS 15;
    left at 14 by the token change, it refused every run at rc 3
  - logging: millisecond JSONL timestamps; CHECK_GREP records use
    key=value form
  - source: pack 17 single-statement helpers onto one line each, cap
    descriptions at 96 characters, add five section banners
  - source: normalize inline comments; drop four trailing periods and
    lowercase six sentence starts
  - source: capitalize twenty sub: description bodies and switch seven
    single-quoted descriptions to double quotes


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS gate and its
    inbound rules from the nftables generator


7.135.0 - 7.136.1
-----------------

  - install: fix the one-time <path>.ry.orig preserve never running for
    non-boot managed files; a set -l inside an if block does not leak
  - check: record unmanaged 60-ry-*.conf drop-ins and masked units
    absent from MASK
  - preflight: refuse a package in both PKGS_ADD and PKGS_DEL, or a unit
    in both MASK and EXPECTED_SERVICES


7.132.0 - 7.134.0
-----------------

  - summary: the abort path recorded the phase-3 row under the normal
    path's name
  - preflight: read the CPU model through cat; a missing /proc/cpuinfo
    made the redirect warn
  - verify: warn on unmanaged /etc/modprobe.d/60-ry-*.conf drop-ins


7.130.0 - 7.131.1
-----------------

  - perf: cpu governor and p-state epp hint set to performance, gpu dpm
    level forced to high


7.123.0 - 7.129.0
-----------------

  - dns: upstreams pinned in the resolver drop-in and the NetworkManager
    global-dns section, which per-link config outranks
  - kernel: add mt7925e.disable_aspm=1; the global policy governs link
    state only
  - sysctl: add kernel.nmi_watchdog=0; the runtime check asserted it
    while nothing set it
  - env: rename FSR4_UPGRADE to PROTON_FSR4_UPGRADE and drop
    VKD3D_CONFIG=descriptor_heap
  - color: NO_COLOR now needs a non-empty value to disable color
  - counts: KERNEL_PARAMS 14 to 15, SYSCTL_VALUES 10 to 11, ENV_VARS 11
    to 10


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

  - configuration: 17 embedded configs deployed atomically - temp file
    on the same filesystem, pre-validation, backup, mv -T, re-read
  - packages: pacman -Rns made rdep-aware via pactree; PKGS_ADD
    re-marked explicit after -Syu
  - verify: static checksum path compares installed bytes to generator
    output by SHA256
  - boot: boot-critical failures exit 4 and skip finalization


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro: kernel parameters,
    mkinitcpio, sysctl, udev, session environment and systemd-boot
