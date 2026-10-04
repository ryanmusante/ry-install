Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.225.0
-------

  - preflight: the modprobe.d format check names directives in match order


7.217.0 - 7.224.0
-----------------

  - kernel: 7.217.0 drop ttm.pages_limit=20971520
  - perf: 7.217.0 governor performance -> powersave, EPP performance kept
  - network: 7.224.0 NetworkManager leaves the Wi-Fi P2P device unmanaged
  - env: 7.217.0 RADV_PERFTEST=nggc -> nggc,nircache; 7.224.0 add
    SDL_GAMECONTROLLER_IGNORE_DEVICES (Keychron K2 HE, Link receiver)
  - configuration: 7.224.0 new managed user file, a WirePlumber soft-mixer
    rule for the POROSVOC USB microphone
  - packages: 7.224.0 add pipewire-jack; a host on jack2 swaps by hand first
  - services: 7.218.0 enable-units counts only units it enabled or started;
    7.219.0 a oneshot nftables.service no longer reads as newly enabled
  - install-file: 7.224.0 the WirePlumber rule restarts wireplumber.service
  - preflight: 7.219.0 MODULES are checked against each installed kernel;
    7.224.0 a locked pacman database stops the run before anything is deployed
  - cli: 7.218.0 a repeated --install-file exits 2; an unmanaged one exits 2
    before the hardware gate


7.190.0 - 7.216.0
-----------------

  - boot: 7.206.0 rebuild hints name sdboot-manage update; 7.211.0 no-entries
    hint drops --verbose, a sudo lapse no longer reads 'backup file missing'
  - kernel: 7.195.0 fsck.mode=force; 7.199.0 add ttm.pages_limit=20971520;
    7.204.0 add nowatchdog
  - perf: 7.211.0 governor powersave -> performance
  - network: 7.200.0 disable NetworkManager connectivity checking
  - env: 7.195.0 drop PROTON_FSR4_INDICATOR=1; 7.212.1 add RADV_PERFTEST=nggc
    and MANGOHUD_DLSYM=1
  - configuration: 7.195.0 MangoHud cpu_stats on, cpu_temp off; 7.203.0 one
    managed-file header per file, nftables drops its ports invite
  - configuration: 7.205.0 cpupower-service.conf header names EnvironmentFile=
  - configuration: 7.211.0 udev comments print the set EPP and GPU levels; the
    resolved header drops its mDNS/LLMNR claim
  - packages: 7.198.0 add dmemcg-booster and plasma-foreground-booster;
    7.200.0 drop both
  - services: 7.197.0 ufw mask withheld unless nftables.service is expected;
    7.203.0 the withheld ufw mask is a WARN; 7.206.0 its SECURITY note is INFO
  - services: 7.207.0 mask and enable skip units is-enabled reports not-found;
    7.211.0 db.lck refusals name the manual fix
  - sysctl: 7.195.0 add vm.watermark_scale_factor=125
  - fstab: 7.211.0 the symlink refusal offers no skip
  - install: 7.207.0 a signal-time revert removes the empty /run/ry-install
  - install-file: 7.201.0 a symlinked destination becomes a regular file;
    7.206.0 INSTALL-FILE END on every return, hook failures log POST_*
  - install-file: 7.206.0 - 7.207.0 the udev retry hint joins its commands
    with &&; 7.211.0 live-apply hooks print OK on success
  - install-file: 7.211.0 relative-path, udev, MangoHud, logind and regdom
    messages corrected
  - summary: 7.206.0 PASS-WITH-WARNINGS Next says reboot; realtime and i2c
    group steps print after the matrix; abort paths record every SKIP row
  - summary: 7.208.0 the tainted-boot SKIP row names the boot state
  - preflight: 7.211.0 a missing root UUID names the findmnt exit code or an
    empty result
  - cli: 7.211.0 glued short flags take only h and v; -Vh and -hV fail like -V
  - lock: 7.211.0 a pidfile without a PID reads 'holds no PID'
  - logging: 7.206.0 signal-time mkinitcpio.conf revert logs before the
    footer; 7.207.0 suffixes _FAILED/_SKIPPED/_LAPSED -> _FAIL/_SKIP/_LAPSE
  - logging: 7.211.0 the DO-NOT-REBOOT banner and a caught signal log before
    stderr
  - split: 7.190.0 move ry-verify.fish to its repository


7.139.0 - 7.189.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0; fsck.mode=force -> auto
  - kernel: land on iommu=pt; drop amd_iommu, clearcpuid=umip, amdxdna
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0
  - env: PROTON_FSR4_UPGRADE -> FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1;
    drop PROTON_ENABLE_WAYLAND=1; GSK_RENDERER ngl then gl
  - configuration: ICMPv6 base accept in nftables
  - packages: 7.173.0 add cachyos-benchmarker
  - sysctl: drop both net.core.netdev_budget keys and vm.swappiness=150
  - fstab: 7.182.1 parity probe never ran
  - install: chmod on mode drift, bytes unchanged
  - install-file: 7.177.3 -h and -v were swallowed after --install-file
  - backup: .ry.bak moves to ~/ry-install/backups; 7.176.0 drop .ry.orig
  - preflight: rc 3 on a reserved COUNTRY, NM_WIFI_POWERSAVE outside 0-3
  - split: 7.177.0 move verify and check to ry-verify.fish


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

  - services: mask ufw instead of removing; the nftables-first gate withholds
    ufw.service


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers
  - boot: mkinitcpio.conf snapshot and byte-exact revert; fstab atomic replace
    behind parity, size and findmnt gates
  - lock: dead-PID reclaim only, live or ambiguous pidfiles fail closed


7.100.0 - 7.107.3
-----------------

  - boot: boot failures exit 4, skip finalization
  - configuration: 17 configs deployed atomically


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
