Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.214.0
-------

  - readme: Usage lists --report with --verify and --check as ry-verify modes


7.190.0 - 7.212.1
-----------------

  - boot: 7.206.0 every rebuild hint names sdboot-manage update
  - boot: 7.211.0 the no-entries hint drops --verbose; a sudo lapse at the
    revert probe no longer reads 'backup file missing'
  - kernel: 7.195.0 fsck.mode=force; 7.199.0 adds ttm.pages_limit=20971520;
    7.204.0 adds nowatchdog
  - perf: 7.204.0 governor performance -> powersave, EPP performance kept;
    7.211.0 governor powersave -> performance, reverting 7.204.0
  - network: 7.200.0 disables NetworkManager connectivity checking
  - env: 7.195.0 drops PROTON_FSR4_INDICATOR=1; 7.212.1 adds
    RADV_PERFTEST=nggc and MANGOHUD_DLSYM=1
  - configuration: 7.195.0 MangoHud cpu_stats enabled, cpu_temp off; 7.203.0
    one managed-file header per file, nftables drops its ports invite
  - configuration: 7.205.0 cpupower-service.conf header names EnvironmentFile=
  - configuration: 7.211.0 udev comments print the set EPP and GPU levels; the
    resolved header drops its mDNS/LLMNR claim
  - packages: 7.198.0 adds and 7.200.0 drops dmemcg-booster and
    plasma-foreground-booster
  - services: 7.197.0 ufw mask withheld unless nftables.service is expected,
    7.203.0 as WARN; 7.206.0 its SECURITY note INFO once masked
  - services: 7.207.0 mask and enable skip units is-enabled reports not-found;
    7.211.0 db.lck refusals name the manual fix
  - sysctl: 7.195.0 adds vm.watermark_scale_factor=125
  - fstab: 7.211.0 the symlink refusal stops offering a skip that does not
    exist
  - install: 7.207.0 a signal-time revert removes the empty /run/ry-install
  - install-file: 7.201.0 a symlinked destination becomes a regular file;
    7.206.0 INSTALL-FILE END on every return, hook failures log POST_*
  - install-file: 7.206.0 - 7.207.0 the udev retry hint joins its commands
    with &&
  - install-file: 7.211.0 live-apply hooks print OK on success; relative-path,
    udev, MangoHud, logind and regdom messages corrected
  - summary: 7.206.0 PASS-WITH-WARNINGS Next says reboot; realtime and i2c
    group steps print after the matrix; abort paths record every SKIP row
  - summary: 7.208.0 the tainted-boot SKIP row names the boot state
  - preflight: 7.211.0 a missing root UUID names the findmnt exit code or an
    empty result
  - cli: 7.211.0 glued short flags take only h and v; -Vh and -hV fail like -V
  - lock: 7.211.0 a pidfile without a PID reads 'holds no PID'
  - logging: 7.206.0 signal-time mkinitcpio.conf revert lands before footer;
    7.207.0 suffixes _FAILED/_SKIPPED/_LAPSED -> _FAIL/_SKIP/_LAPSE
  - logging: 7.211.0 the DO-NOT-REBOOT banner and a caught signal log before
    stderr
  - split: 7.190.0 moves ry-verify.fish to its repository


7.139.0 - 7.189.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0; fsck.mode=force -> auto
  - kernel: land on iommu=pt; drop amd_iommu, clearcpuid=umip, amdxdna
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0
  - env: PROTON_FSR4_UPGRADE -> FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1;
    drop PROTON_ENABLE_WAYLAND=1; GSK_RENDERER ngl then gl
  - configuration: ICMPv6 base accept in nftables
  - packages: 7.173.0 adds cachyos-benchmarker
  - sysctl: drop both net.core.netdev_budget keys and vm.swappiness=150
  - fstab: 7.182.1 parity probe never ran
  - install: chmod on mode drift, bytes unchanged
  - install-file: 7.177.3 -h and -v were swallowed after --install-file
  - backup: .ry.bak moves to ~/ry-install/backups; 7.176.0 drops .ry.orig
  - preflight: rc 3 on a reserved COUNTRY, NM_WIFI_POWERSAVE outside 0-3
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
  - env: FSR4_UPGRADE -> PROTON_FSR4_UPGRADE; drop VKD3D_CONFIG


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
  - configuration: 17 configs deployed atomically


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
