Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.210.0
-------

  - boot: the no-entries hint drops --verbose, unknown to sdboot-manage
  - perf: governor powersave -> performance, reverting 7.204.0
  - perf: EPP stays performance; its udev write is a no-op the kernel rejects
  - services: db.lck and batch-removal messages match their siblings
  - services: cache trim failures name paccache or pacman -Sc
  - fstab: the symlink refusal stops offering a skip that does not exist
  - install-file: a relative path reads 'requires an absolute path'
  - install-file: the udev hints stop naming one rule
  - install-file: the MangoHud hint stops naming a launch option
  - install-file: the logind hint names the SIGHUP reload, not a reboot
  - install-file: regdom hook failures and skips log POST_* keys
  - summary: removal, mask and enable counts read package(s) and unit(s)
  - preflight: the COUNTRY and dash-package refusals end '; refuse to deploy'
  - cli: glued short flags take only h and v; -Vh and -hV now fail like -V


7.190.0 - 7.208.0
-----------------

  - boot: 7.206.0 every rebuild hint names sdboot-manage update
  - kernel: 7.195.0 fsck.mode=force
  - kernel: 7.199.0 adds ttm.pages_limit=20971520
  - kernel: 7.204.0 adds nowatchdog
  - perf: 7.204.0 governor performance -> powersave, EPP performance kept
  - network: 7.200.0 disables NetworkManager connectivity checking
  - env: 7.195.0 drops PROTON_FSR4_INDICATOR=1
  - configuration: 7.195.0 MangoHud ships cpu_stats enabled, cpu_temp off
  - configuration: 7.203.0 one managed-file header per file
  - configuration: 7.203.0 nftables drops its ports invite
  - configuration: 7.205.0 cpupower-service.conf header names EnvironmentFile=
  - packages: 7.198.0 adds dmemcg-booster and plasma-foreground-booster
  - packages: 7.200.0 drops dmemcg-booster and plasma-foreground-booster
  - services: 7.197.0 ufw mask withheld unless nftables.service is expected
  - services: 7.203.0 records a withheld mask as WARN, not PASS
  - services: 7.206.0 the ufw SECURITY note is INFO once ufw.service is masked
  - services: 7.207.0 mask and enable skip units is-enabled reports not-found
  - sysctl: 7.195.0 adds vm.watermark_scale_factor=125
  - install: 7.207.0 a signal-time revert removes the empty /run/ry-install
  - install: 7.208.0 single blank lines before the RUN SUMMARY and help text
  - install: 7.208.0 sudo-banner, withheld-ufw, non-systemd-boot drop periods
  - install-file: 7.201.0 a symlinked destination becomes a regular file
  - install-file: 7.206.0 INSTALL-FILE END on every return
  - install-file: 7.206.0 dash-path and modprobe hints trimmed
  - install-file: 7.206.0 nm, bluetooth, envd, udev hook failures log POST_*
  - install-file: 7.207.0 output drops its blank lines
  - install-file: 7.207.0 the udev retry hint joins its commands with &&
  - summary: 7.206.0 PASS-WITH-WARNINGS Next says reboot
  - summary: 7.206.0 realtime and i2c group steps print after the matrix
  - summary: 7.206.0 abort paths record every SKIP row
  - summary: 7.207.0 network, withheld-ufw and mask-retry evidence fit the
    50-ch cell
  - summary: 7.208.0 the tainted-boot SKIP row names the boot state
  - logging: 7.206.0 signal-time mkinitcpio.conf revert lands before footer
  - logging: 7.207.0 suffixes _FAILED/_SKIPPED/_LAPSED -> _FAIL/_SKIP/_LAPSE
  - logging: 7.207.0 MKINITCPIO_REVERT_OK drops its pacman-failure clause
  - split: 7.190.0 moves ry-verify.fish to its repository


7.139.0 - 7.189.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0
  - boot: fsck.mode=force -> auto
  - kernel: land on iommu=pt
  - kernel: drop amd_iommu, clearcpuid=umip, amdxdna
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0, wlan0 quit after four tries
  - env: PROTON_FSR4_UPGRADE -> FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1
  - env: drop PROTON_ENABLE_WAYLAND=1
  - env: GSK_RENDERER ngl then gl
  - configuration: ICMPv6 base accept in nftables
  - packages: 7.173.0 adds cachyos-benchmarker
  - sysctl: drop both net.core.netdev_budget keys and vm.swappiness=150
  - fstab: 7.182.1 parity probe never ran, awk read its -- as a filename
  - install: chmod on mode drift, bytes unchanged
  - install-file: 7.177.3 -h and -v were swallowed after --install-file
  - backup: .ry.bak moves to ~/ry-install/backups, slash-encoded
  - backup: 7.176.0 drops the .ry.orig preserve
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
  - env: FSR4_UPGRADE -> PROTON_FSR4_UPGRADE
  - env: drop VKD3D_CONFIG


7.118.0 - 7.122.0
-----------------

  - services: mask ufw instead of removing
  - services: the nftables-first gate withholds ufw.service


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers
  - boot: mkinitcpio.conf snapshot and byte-exact revert
  - boot: fstab atomic replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only, live or ambiguous pidfiles fail closed


7.100.0 - 7.107.3
-----------------

  - boot: boot failures exit 4, skip finalization
  - configuration: 17 configs deployed atomically via temp+backup+mv -T


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
