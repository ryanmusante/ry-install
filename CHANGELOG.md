Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.200.0
-------

  - packages: drop dmemcg-booster and plasma-foreground-booster (dmem sees
    only the VRAM carveout, not GTT); PKGS_ADD 19 -> 17, tripwire follows
  - services: dmemcg-booster-system.service leaves EXPECTED_SERVICES and the
    package-managed list; 6 -> 5 and 2 -> 1, tripwires follow
  - network: disable NetworkManager connectivity checking in the managed
    drop-in; the periodic reachability request is unwanted on the gaming path


7.139.0 - 7.199.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0; fsck.mode=force -> auto
  - kernel: land on iommu=pt; drop amd_iommu, clearcpuid=umip, amdxdna;
    7.195.0 fsck.mode auto -> force; 7.199.0 adds ttm.pages_limit=20971520
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0, wlan0 quit after four tries
  - env: PROTON_FSR4_UPGRADE -> FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1,
    7.195.0 drops it; drop PROTON_ENABLE_WAYLAND=1; GSK_RENDERER ngl then gl
  - configuration: ICMPv6 base accept in nftables; 7.195.0 MangoHud ships
    cpu_stats enabled, cpu_temp stays off
  - packages: 7.173.0 adds cachyos-benchmarker; 7.198.0 adds dmemcg-booster
    and plasma-foreground-booster (dmem cgroup VRAM protection)
  - services: 7.197.0 ufw mask withheld unless nftables.service is expected
  - services: 7.198.0 dmemcg-booster-system.service joins EXPECTED_SERVICES
    as a package-managed unit
  - sysctl: drop both net.core.netdev_budget keys and vm.swappiness=150;
    7.195.0 adds vm.watermark_scale_factor=125
  - fstab: 7.182.1 parity probe never ran, awk read its -- as a filename
  - install: chmod on mode drift, bytes unchanged; 7.177.3, 7.179.0 named
    tools it never runs; 7.182.0 - 7.184.0 drop ext4 awk filter, MODE=check
  - install-file: 7.177.3 -h and -v were swallowed after --install-file
  - install-file: /boot post-hook keys on the exact path, unmatched hooks
    WARN; 7.185.0 an unmanaged path lists the managed set
  - backup: .ry.bak moves to ~/ry-install/backups, slash-encoded; 7.176.0
    drops the .ry.orig preserve
  - cleanup: 7.181.0 - 7.182.2 erase and sweep only what each script sets
  - preflight: rc 3 on a broken post-hook mirror, a stale counts tripwire,
    a reserved COUNTRY, NM_WIFI_POWERSAVE outside 0-3; no ipv6.disable=1 warns
  - preflight: 7.197.0 refuses rc 3 unless the resolved, NetworkManager and
    environment.d change keys are managed destinations
  - logging: millisecond JSONL timestamps; sudo cache and config gates log
    a START, all six pair
  - logging: 7.197.0 JSONL header keeps an empty argv element; post-hook skip
    and failure paths record target=
  - help: backups path beside the log path; each names its counterpart;
    7.181.0 lists _run sentinels 251 and 255
  - split: 7.177.0 moves verify and check to ry-verify.fish, shared fns
    verbatim; 7.177.1 - 7.180.0 shed every counterpart arm
  - split: 7.190.0 moves ry-verify.fish to its repository; 7.192.0 - 7.193.0
    make this the sole home of shared value tables and tuning documentation
  - split: 7.195.1 - 7.195.2 lockstep bumps; comments and descriptions only
  - counts: 2 scripts, sync sites 4 -> 6, zip entries 5 -> 6; KERNEL_PARAMS
    15 -> 14, ENV_VARS 9 -> 10, SYSCTL_VALUES 9 -> 8, PKGS_ADD 16 -> 17
  - counts: 7.195.0 ENV_VARS 10 -> 9, SYSCTL_VALUES 8 -> 9; 7.198.0 PKGS_ADD
    17 -> 19, EXPECTED_SERVICES 5 -> 6; 7.199.0 KERNEL_PARAMS 14 -> 15


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

  - services: mask ufw instead of removing, MASK 10 -> 11, PKGS_DEL 10 -> 9;
    the nftables-first gate withholds ufw.service


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
