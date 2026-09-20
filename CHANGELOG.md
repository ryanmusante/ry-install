Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.208.0
-------

  - summary: the tainted-boot SKIP row reads boot state tainted by an earlier
    phase, not the _RY_BOOT_TAINTED variable name
  - install: one blank line, not two, separates the sudo banner from the RUN
    SUMMARY and a usage error from the help text
  - install: the sudo banner, withheld-ufw and non-systemd-boot messages drop
    their trailing periods


7.190.0 - 7.207.0
-----------------

  - boot: 7.206.0 every rebuild hint names sdboot-manage update
  - kernel: 7.195.0 fsck.mode=force; 7.199.0 adds ttm.pages_limit=20971520;
    7.204.0 adds nowatchdog, the CachyOS sdboot-manage default
  - perf: 7.204.0 governor performance -> powersave, EPP performance kept
  - network: 7.200.0 disables NetworkManager connectivity checking
  - env: 7.195.0 drops PROTON_FSR4_INDICATOR=1
  - configuration: 7.195.0 MangoHud ships cpu_stats enabled, cpu_temp off;
    7.203.0 one managed-file header per file, nftables drops its ports invite
  - configuration: 7.205.0 cpupower-service.conf header names EnvironmentFile=
  - packages: 7.198.0 adds dmemcg-booster and plasma-foreground-booster,
    7.200.0 drops both (dmem sees VRAM only)
  - services: 7.197.0 withholds the ufw mask unless nftables.service is
    expected; 7.203.0 records a withheld mask as WARN, not PASS
  - services: 7.206.0 the ufw SECURITY note is INFO once ufw.service is masked
  - services: 7.207.0 mask and enable filters skip units is-enabled reports
    not-found
  - sysctl: 7.195.0 adds vm.watermark_scale_factor=125
  - install: 7.207.0 a signal-time revert removes the empty /run/ry-install
  - install-file: 7.201.0 a symlinked destination becomes a regular file
  - install-file: 7.206.0 INSTALL-FILE END on every return; dash-path and
    modprobe hints trimmed
  - install-file: 7.206.0 nm, bluetooth, envd and udev hook failures log
    POST_* keys
  - install-file: 7.207.0 output drops its blank lines; the udev retry hint
    joins its commands with &&
  - summary: 7.206.0 PASS-WITH-WARNINGS Next says reboot; realtime and i2c
    group steps print after the matrix; abort paths record every SKIP row
  - summary: 7.207.0 network, withheld-ufw and mask-retry evidence fit the
    50-ch cell
  - logging: 7.206.0 a signal-time mkinitcpio.conf revert lands before the
    footer
  - logging: 7.207.0 key suffixes _FAILED, _SKIPPED and _LAPSED become _FAIL,
    _SKIP and _LAPSE; MKINITCPIO_REVERT_OK drops its pacman-failure clause
  - split: 7.190.0 moves ry-verify.fish to its repository


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
  - install-file: 7.177.3 -h and -v were swallowed after --install-file
  - backup: .ry.bak moves to ~/ry-install/backups, slash-encoded; 7.176.0
    drops the .ry.orig preserve
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
