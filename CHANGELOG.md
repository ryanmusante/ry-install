Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.234.0
-------

  - guard: a sourced or piped run is refused under any locale; fish's
    translated 'Standard input' and 'from sourcing file' are read under
    LC_ALL=C
  - signals: a SIGINT, SIGTERM or SIGHUP during startup exits 128+N instead
    of 0; the handler no longer registers QUIT, which fish never delivers
  - cli: -h and -v exit 1 when stdout is closed or full; --install-file
    rejects --report as its value
  - logging: a signal or tmpfile helper before the header no longer leaves a
    footer-only or header-second JSONL; child SIGKILL, a failed
    pending-apply clear, an absent modinfo and a skipped mkinitcpio.conf
    snapshot are logged
  - preflight: the hardware override hint keeps --install-file; iommu=off
    counts as no IOMMU for amdxdna; a failed timedatectl query and an absent
    ping are named as such; low-disk and RY_RUN_TIMEOUT warnings print in
    install mode; leading zeros in RY_RUN_TIMEOUT carry no magnitude
  - mkinitcpio: a HOOKS entry needs a build script in an initcpio install
    dir; a hooks/ script alone no longer passes
  - backup: the post-write restore uses only the .ry.bak this run took; the
    copy never writes through a symlink at the backup path
  - packages: a failed pactree probe is reported as held, not as nothing
    installed; a PKGS_DEL member removed by another's -s cascade is not
    reported failed
  - services: a unit that masks but fails to stop is a WARN, not a FAIL; the
    enable-start WARN covers persistent enable states only; the fstab row is
    WARN when a digits-only ext4 row is left; a preserved mkinitcpio.conf
    snapshot path prints in install mode
  - boot: the DO-NOT-REBOOT inspect step uses sudo and the resolved $BOOT
  - summary: the verdict is still logged when stderr is gone; --install-file
    prints Installed only when bytes changed
  - progress: the bar reads the terminal size from the stderr tty
  - consistency: function descriptions, banners and comments match their
    code; lines over 300 characters are split (KERNEL_PARAMS stays on one
    line for hand edits)


7.233.0
-------

  - install-file: a re-run on a boot file runs the boot cascade even when
    its bytes are unchanged; a retry after a failed rebuild no longer exits
    0 unrebuilt
  - install-file: mkinitcpio.conf and sdboot-manage.conf check HOOKS and
    MODULES before the write and exit 3, as the full install does
  - install-file: with nft(8) absent the nftables post-hook says so instead
    of reporting a failed nft -c
  - configuration: an nft -c failure after this run's upgrade removed the
    running kernel's modules is named as such, with reboot then re-run as
    the next step; the ruleset is still not deployed
  - configuration: a managed file with bytes after a NUL is rewritten
    instead of reported unchanged
  - packages: a failed -Syu whose mkinitcpio.conf revert succeeded keeps the
    restored conf through Configuration (WARN 'mkinitcpio.conf held')
  - packages: PKGS_ADD is re-marked explicit whatever the -Syu result and
    again before -Rns, so a PKGS_ADD package is never removed as an orphan
  - services: a unit that enables but fails to start reads WARN on the
    enable row, naming the unit, and the warning prints during the run
  - services: the live nftables policy-drop probe before the ufw flush
    matches only the input hook line
  - finalize: a run that stops before Finalize records the NetworkManager
    restart and PowerDevil re-apply it owes in ~/ry-install/pending-apply as
    each file lands; the next run of the same boot applies them
  - preflight: the /boot free-space gate runs on stacked /boot mounts; ESP
    autodetect and the sdboot-manage vfat gate read the topmost non-autofs
    mount
  - preflight: a setgid $HOME or a symlinked ~/ry-install no longer fails
    the log-dir mode check
  - lock: only the lock holder sweeps destination dirs; a peer refused with
    exit 5 no longer deletes the holder's in-flight tmpfiles
  - lock: stale-lock reclaim takes an exclusive claim and moves the stale
    dir aside in one rename; the pidfile is installed with link(2), and
    release checks it still carries this run's record
  - lock: the pidfile records boot_id and process start time; a pidfile from
    an earlier boot or a reused PID is reclaimed instead of exiting 5, and
    an unreadable identity fails closed
  - lock: a signal between the lock mkdir and the pidfile write no longer
    leaves an empty .lock behind
  - cleanup: tracked tmpfiles in the root-only /run/ry-install are removed
    via sudo
  - cli: --h, --he, --hel and --v through --versio are honored before the
    root guard like --help and --version
  - sudo: the credential check keeps sudo's error text in memory instead of
    a /tmp file
  - readme: the Kernel Parameter Notes name the KERNEL_PARAMS:<n> count
    check in both scripts


7.232.0
-------

  - configuration: MangoHud sets text_outline=0; a commented-out line left
    the default outline on
  - readme: PROTON_FSR4_UPGRADE pins 4.0.0 or 4.1.1 only, not 4.0.1


7.217.0 - 7.231.0
-----------------

  - kernel: 7.217.0 drop ttm.pages_limit=20971520
  - perf: 7.217.0 governor performance -> powersave, EPP performance kept
  - network: 7.224.0 NetworkManager leaves the Wi-Fi P2P device unmanaged
  - env: 7.217.0 RADV_PERFTEST=nggc -> nggc,nircache; 7.224.0 add
    SDL_GAMECONTROLLER_IGNORE_DEVICES (Keychron K2 HE, Link receiver)
  - configuration: 7.224.0 manage a WirePlumber soft-mixer rule (POROSVOC mic)
  - configuration: 7.229.0 drop the WirePlumber soft-mixer rule (POROSVOC mic)
    and its post-hook
  - configuration: 7.229.0 MangoHud comments out text_outline, adds
    no_small_font and alpha=0.8
  - packages: 7.224.0 add pipewire-jack; a host on jack2 swaps by hand first
  - services: 7.218.0 enable-units counts only units it enabled or started;
    7.219.0 a oneshot nftables.service no longer reads as newly enabled
  - install-file: 7.224.0 the WirePlumber rule restarts wireplumber.service
  - backup: 7.231.0 a sudo lapse at the existence probe is warned and logged
    instead of silently skipping the copy
  - preflight: 7.219.0 MODULES are checked against each installed kernel;
    7.224.0 a locked pacman database stops the run before anything is deployed
  - preflight: 7.225.0 the modprobe.d format check names directives in
    match order
  - cli: 7.218.0 a repeated --install-file exits 2; an unmanaged one exits 2
    before the hardware gate


7.190.0 - 7.216.0
-----------------

  - boot: 7.206.0 rebuild hints name sdboot-manage update; 7.211.0 no-entries
    hint drops --verbose, a sudo lapse no longer reads 'backup file missing'
  - kernel: 7.195.0 fsck.mode=force; 7.199.0 add ttm.pages_limit=20971520;
    7.204.0 add nowatchdog
  - perf: 7.204.0 governor performance -> powersave; 7.211.0 performance again
  - network: 7.200.0 disable NetworkManager connectivity checking
  - env: 7.195.0 GSK_RENDERER ngl -> gl, drop PROTON_FSR4_INDICATOR=1; 7.212.1
    add RADV_PERFTEST=nggc and MANGOHUD_DLSYM=1
  - configuration: 7.195.0 MangoHud cpu_stats on, cpu_temp off; 7.203.0 one
    header per managed file, nftables drops its ports invite
  - configuration: 7.205.0 cpupower header names EnvironmentFile=; 7.211.0
    udev comments print EPP and GPU levels; resolved drops mDNS/LLMNR claim
  - packages: 7.198.0 add dmemcg-booster and plasma-foreground-booster;
    7.200.0 drop both
  - services: 7.197.0 ufw mask needs nftables.service; 7.203.0 a withheld mask
    is a WARN, 7.206.0 its SECURITY note INFO; 7.207.0 skip not-found units
  - services: 7.211.0 db.lck refusals name the manual fix
  - sysctl: 7.195.0 add vm.watermark_scale_factor=125
  - fstab: 7.211.0 the symlink refusal offers no skip
  - install: 7.207.0 a signal-time revert removes the empty /run/ry-install
  - install-file: 7.201.0 a symlinked destination becomes a regular file;
    7.206.0 INSTALL-FILE END on every return, hook failures log POST_*
  - install-file: 7.206.0 - 7.207.0 the udev retry hint joins its commands
    with &&; 7.211.0 live-apply hooks print OK, five messages corrected
  - summary: 7.206.0 PASS-WITH-WARNINGS Next says reboot, group steps follow
    the matrix, aborts record every SKIP row; 7.208.0 tainted SKIP names state
  - preflight: 7.211.0 a missing root UUID names findmnt's rc or empty output
  - cli: 7.211.0 glued short flags take only h and v; -Vh and -hV fail like -V
  - lock: 7.211.0 a pidfile without a PID reads 'holds no PID'
  - logging: 7.206.0 signal-time revert logs before the footer; 7.207.0 log
    suffixes _FAIL/_SKIP/_LAPSE; 7.211.0 banner and signals log before stderr
  - split: 7.190.0 move ry-verify.fish to its repository


7.139.0 - 7.189.0
-----------------

  - boot: COMPRESSION_OPTIONS -1 -> -3, drop -T0; fsck.mode=force -> auto
  - kernel: land on iommu=pt; drop amd_iommu, clearcpuid=umip, amdxdna
  - dns: drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - network: autoconnect-retries-default=0
  - env: PROTON_FSR4_UPGRADE -> FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1;
    drop PROTON_ENABLE_WAYLAND=1; add GSK_RENDERER=ngl
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

  - kernel: add mt7925e.disable_aspm=1 and kernel.nmi_watchdog=0
  - dns: pin upstreams in resolved and the NM global-dns section
  - env: FSR4_UPGRADE -> PROTON_FSR4_UPGRADE; drop VKD3D_CONFIG


7.118.0 - 7.122.0
-----------------

  - services: mask ufw instead of removing; the nftables-first gate withholds
    ufw.service


7.108.0 - 7.117.0
-----------------

  - boot: mkinitcpio.conf snapshot and byte-exact revert; fstab atomic replace
    behind parity, size and findmnt gates
  - install-file: post-hook dispatch table with per-target handlers
  - lock: dead-PID reclaim only, live or ambiguous pidfiles fail closed


7.100.0 - 7.107.3
-----------------

  - boot: boot failures exit 4, skip finalization
  - configuration: 17 configs deployed atomically


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
