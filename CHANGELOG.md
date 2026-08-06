Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.


7.156.0
-------

  - env: drop PROTON_ENABLE_WAYLAND=1; winewayland is a per-title opt-in
    and the global pin applied it to every Proton game
  - check: record unmanaged 60-ry-* drop-ins before the sudo gate; the
    sweep needs no privilege
  - readme: note that the fallback entry carries none of the kernel
    parameters


7.139.0 - 7.155.0
-----------------

  - boot: drop the redundant -T0 from MKINITCPIO_COMPRESSION_OPTIONS;
    mkinitcpio prepends it for zstd, so the image is unchanged
  - dns: drop the pinned upstreams and stop pinning DNSOverTLS= and
    DNSSEC=; link DNS from DHCP wins, systemd already defaults both to no
  - env: replace PROTON_FSR4_UPGRADE=1 with FSR4_WATERMARK=1; the runtime
    now copies the DLL itself, so the old pin did nothing
  - verify: sweep every cpufreq policy for driver, governor and EPP
    uniformity; cpu0 stays the representative detail readout
  - verify: assert each non-fallback loader entry carries every
    KERNEL_PARAMS token; fallback entries keep their own options
  - verify: check the systemd-resolved unit-file state, warn on any
    sdboot-manage drop-in, and report only admin-scope orphan masks
  - verify: log the root filesystem type and the ext4 fstab entry count
  - verify: drop the preemption-model advisory and its dmesg scan
  - preflight: drop free, uptime, swapon and zramctl from the optional
    tool probe; the script never invokes any of them
  - logging: millisecond JSONL timestamps; CHECK_GREP records use
    key=value form; nftables verdict names the unit-file state
  - internal: hoist the boot-entry list to function scope
  - source: pack 17 single-statement helpers onto one line each
  - source: capitalize descriptions and cap each at 96 characters
  - source: add five section banners, trim two banner titles
  - readme: add the missing sudo to the unmask and pacman commands
  - readme: link Requirements to the BIOS section
  - readme: document the systemd 250 floor and why DNSOverTLS= and
    DNSSEC= stay unset
  - readme: rename the heading that collided on an anchor slug
  - readme: document all eleven mkinitcpio HOOKS ordering constraints the
    preflight enforces; the Initramfs note named two of them
  - readme: name the failure verdicts the run summary prints; only the two
    success verdicts were documented
  - changelog: record README corrections that change a printed command


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS gate and its
    Sunshine/Steam inbound rules from the nftables generator


7.135.0 - 7.136.1
-----------------

  - install: fix the one-time <path>.ry.orig preserve never running for
    non-boot managed files; a set -l inside an if block does not leak
  - check: record unmanaged 60-ry-*.conf drop-ins and masked units absent
    from MASK, both previously visible to --verify only
  - preflight: refuse a package in both PKGS_ADD and PKGS_DEL, or a unit
    in both MASK and EXPECTED_SERVICES
  - logging: count captured lines without a redirect; fish warns on a
    failed redirect even when stderr is silenced


7.132.0 - 7.134.0
-----------------

  - summary: the abort path records the phase-3 row under the normal
    path's name; the old one also overflowed the matrix column
  - preflight: read the CPU model through cat; a missing /proc/cpuinfo
    made the redirect warn, which --check must never print
  - verify: warn on unmanaged /etc/modprobe.d/60-ry-*.conf drop-ins
  - source: sub marker names the calling function across every family


7.130.0 - 7.131.1
-----------------

  - perf: cpu governor and p-state epp hint set to performance, gpu dpm
    level forced to high; package power stays capped at 85W in firmware


7.123.0 - 7.127.0
-----------------

  - dns: upstreams pinned in the resolver drop-in and in the
    NetworkManager global-dns section, which per-link config outranks
  - kernel: add mt7925e.disable_aspm=1. The global policy governs link
    state only, so the endpoint driver disables ASPM itself
  - sysctl: add kernel.nmi_watchdog=0. The runtime check asserted it
    while nothing set it; the profile now owns what it verifies
  - env: rename FSR4_UPGRADE to PROTON_FSR4_UPGRADE and drop
    VKD3D_CONFIG=descriptor_heap
  - color: NO_COLOR now needs a non-empty value to disable color
  - counts: KERNEL_PARAMS 14 to 15, SYSCTL_VALUES 10 to 11, ENV_VARS 11
    to 10; drift tripwires and the readme tables follow


7.118.0 - 7.122.0
-----------------

  - services: ufw is masked, not removed - MASK 10 -> 11 (+ufw.service),
    PKGS_DEL 10 -> 9 (-ufw)
  - services: nftables-first gate moved from the removal path to the
    mask path; an unconfirmed ruleset withholds the ufw.service mask
  - source: comments normalized to one line each, section banners name
    only the functions they hold


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers,
    coverage enforced by an invariant validator
  - boot: mkinitcpio.conf snapshot and revert with byte-exact compare
  - fstab: atomic replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only; live or ambiguous pidfiles fail closed
  - preserve: one-time <path>.ry.orig for non-boot managed files whose
    content differed at first adoption


7.100.0 - 7.107.3
-----------------

  - configuration: 17 embedded configs deployed atomically - temp file
    on the same filesystem, pre-validation, backup, mv -T, re-read
  - packages: pacman -Rns made rdep-aware via pactree, with a timeout;
    PKGS_ADD re-marked explicit after -Syu
  - verify: static checksum path compares installed bytes to generator
    output by SHA256; --check is a silent idempotency probe
  - services: masked unit set and enabled unit set established
  - boot: boot-critical failures exit 4 and skip finalization


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro: kernel parameters,
    mkinitcpio, sysctl, udev, session environment and systemd-boot
