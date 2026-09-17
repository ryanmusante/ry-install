Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.203.0
-------

  - configuration: every managed file but /etc/kernel/cmdline opens with one
    ry-install managed-file header; nftables.conf drops its add-ports invite
  - services: a withheld ufw mask records WARN and names the unit; the row
    read PASS, masked 10 units
  - readme: MangoHud cpu_temp is turned on in the generators, not the deployed
    file; a post-write mismatch restores a backup only where one exists
  - changelog: trimmed to value changes, operator-visible behavior and fixes;
    both prior single-version blocks folded into the range below


7.190.0 - 7.202.0
-----------------

  - kernel: 7.195.0 fsck.mode auto -> force; 7.199.0 adds
    ttm.pages_limit=20971520
  - network: 7.200.0 disables NetworkManager connectivity checking
  - env: 7.195.0 drops PROTON_FSR4_INDICATOR=1
  - configuration: 7.195.0 MangoHud ships cpu_stats enabled, cpu_temp off
  - packages: 7.198.0 adds dmemcg-booster and plasma-foreground-booster,
    7.200.0 drops both (dmem sees VRAM only)
  - services: 7.197.0 withholds the ufw mask unless nftables.service is
    expected
  - sysctl: 7.195.0 adds vm.watermark_scale_factor=125
  - install-file: 7.201.0 a symlinked destination is always replaced with a
    regular file; its mode drift is no longer reported
  - split: 7.190.0 moves ry-verify.fish to its repository; 7.195.1 - 7.195.2,
    7.200.1 and 7.202.0 are lockstep bumps


7.139.0 - 7.189.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0; fsck.mode=force -> auto
  - kernel: land on iommu=pt; drop amd_iommu, clearcpuid=umip, amdxdna
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0, wlan0 quit after four tries
  - env: PROTON_FSR4_UPGRADE -> FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1;
    drop PROTON_ENABLE_WAYLAND=1; GSK_RENDERER ngl then gl
  - configuration: ICMPv6 base accept in nftables
  - packages: 7.173.0 adds cachyos-benchmarker
  - sysctl: drop both net.core.netdev_budget keys and vm.swappiness=150
  - fstab: 7.182.1 parity probe never ran, awk read its -- as a filename
  - install: chmod on mode drift, bytes unchanged
  - install-file: 7.177.3 -h and -v were swallowed after --install-file;
    7.185.0 lists the managed set
  - backup: .ry.bak moves to ~/ry-install/backups, slash-encoded; 7.176.0
    drops the .ry.orig preserve
  - preflight: rc 3 on a reserved COUNTRY, NM_WIFI_POWERSAVE outside 0-3; no
    ipv6.disable=1 warns
  - logging: millisecond JSONL timestamps
  - split: 7.177.0 moves verify and check to ry-verify.fish


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS nftables gate


7.135.0 - 7.136.1
-----------------

  - install: fix .ry.orig preserve dead under an if-scoped set -l


7.132.0 - 7.134.0
-----------------

  - summary: abort path used the normal path's name for the phase-3 row


7.130.0 - 7.131.1
-----------------

  - perf: governor and EPP performance, GPU DPM level high


7.123.0 - 7.129.0
-----------------

  - dns: pin upstreams in resolved and the NM global-dns section
  - kernel: add mt7925e.disable_aspm=1 and kernel.nmi_watchdog=0
  - env: FSR4_UPGRADE -> PROTON_FSR4_UPGRADE, drop VKD3D_CONFIG


7.118.0 - 7.122.0
-----------------

  - services: mask ufw instead of removing; the nftables-first gate
    withholds ufw.service


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers
  - boot: mkinitcpio.conf snapshot and byte-exact revert; fstab atomic
    replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only, live or ambiguous pidfiles fail closed


7.100.0 - 7.107.3
-----------------

  - boot: boot failures exit 4, skip finalization
  - configuration: 17 configs deployed atomically via temp+backup+mv -T


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
