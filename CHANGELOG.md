Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.249.0
-------

  - install-file: a boot-critical failure prints DO NOT REBOOT and its
    recovery steps once, in the closing banner


7.246.0 - 7.248.0
-----------------

  - env: 7.248.0 add 0x3434/0x0b00 (Keychron Q0 HE) to
    SDL_GAMECONTROLLER_IGNORE_DEVICES
  - configuration: 7.247.0 a post-write mismatch with only an older run's
    .ry.bak says no backup from this run
  - configuration: 7.248.0 udev has libinput ignore the Xbox Wireless
    Controller
  - guard: 7.247.0 an early exit removes ~/ry-install/backups only when this
    run created it
  - guard: 7.247.0 inherited mkinitcpio rollback variables are pinned, so they
    can never drive a revert
  - cli: 7.247.0 the --install-file control-character refusal states its real
    reason
  - preflight: 7.247.0 MKINITCPIO_MODULES and MKINITCPIO_HOOKS tokens are
    charset-checked
  - preflight: 7.247.0 a missing realpath no longer prints fish errors; a
    module that may not exist warns on the console
  - packages: 7.246.0 a missing member whose dependency conflicts with an
    installed package is held for the swap, not left to fail both passes
  - packages: 7.246.0 a conflict swap gets its own summary row naming what it
    removed; an rc-0 -Syu or swap whose hooks log errors reads WARN
  - packages: 7.247.0 each -Syu pass that stops on a dependency conflict holds
    the missing member that pulls it and runs again
  - packages: 7.247.0 the -Syu re-pass and -Syyu retry notices print on the
    console beside the failed pass's pacman errors
  - services: 7.247.0 a PKGS_DEL row with a pacman hook error keeps its
    rdep-skip count
  - logging: 7.246.0 a failed pacman call echoes its package-conflict lines
  - logging: 7.247.0 boot-cascade and udev-skip records carry the POST_
    prefix; the header timestamp survives a failed date
  - logging: 7.247.0 _run clears its capture before an early return; the
    bail-out record precedes INSTALLATION END
  - logging: 7.247.0 an empty loud _err logs nothing
  - summary: 7.247.0 a failed write of the run summary or the sudo banner logs
    STDERR_WRITE_FAIL


7.245.0
-------

  - guard: an early exit removes ~/ry-install only when this run created it
  - lock: lock hints quote the path and pass --preserve-root; a kill-less host
    takes the /proc lock branch silently
  - cli: an over-long RY_RUN_TIMEOUT warns that 2147483647 is used, not that
    it is clamped
  - signals: a signal during the startup mv -T probe no longer leaves its two
    temp files in /tmp
  - signals: drop the PIPE handler; it silenced a live terminal
  - preflight: a sudo -n -v that passes yet leaves sudo -n unusable exits 3;
    the sudo banner suggests a keepalive in this terminal
  - preflight: missing optional tools and an absent modinfo warn on stderr;
    the validation error counts failed checks
  - packages: the -Syyu retry re-reads conflict holds from the sync db the
    first pass refreshed
  - packages: the held mkinitcpio.conf warning says the seed was rolled back,
    not -Syu
  - configuration: an nft -c that exits 124 or 137 reads timed out or was
    killed
  - services: a masked unit still running is masked again with --now; an
    enable FAIL row counts the units that failed to start
  - services: a systemd-resolved restart owed by an interrupted run stays owed
    in pending-apply until it runs
  - services: a mask failure logs an error; a failed findmnt --verify lists
    its [E] lines first
  - boot: a symlinked loader/entries directory is listed; entry checks name a
    rejected path and a missing directory
  - boot: a signal during the read-only post-rebuild checks no longer prints
    the interrupted-rebuild banner
  - finalize: a pending-apply marker from another boot is deleted when first
    read
  - install-file: mkinitcpio.conf and sdboot-manage.conf run the preflight
    disk-space gate first and exit 3 when it fails
  - install-file: a failed nftables reload names the retry command; an
    environment.d deploy says try-restarted
  - logging: a failed stderr write logs STDERR_WRITE_FAIL once
  - logging: tmpfile and child-reap records precede the footer again; a signal
    while the footer is built still writes it
  - logging: a log rename that falls back to cp, or fails, is logged; the
    log-write warning allows a removed JSONL
  - logging: _run times commands on the monotonic clock; TIMEOUT_LONGOP_CAP is
    renamed TIMEOUT_LONGOP_FLOOR
  - progress: the bar unpins before its last writes, so a resize then cannot
    re-pin it


7.243.0
-------

  - guard: TMPDIR is pinned to /tmp
  - guard: an inherited LOG_FILE, LOG_DIR or _RY_BACKUP_DIR is not deleted
    when the run exits before creating its own log
  - cli: an argument error writes no /tmp file; a 4096-byte --install-file
    path fails as over PATH_MAX
  - signals: a signal during the boot rebuild prints the DO NOT REBOOT
    recovery banner before exiting 128+N
  - preflight: a sudo -v that caches nothing (timestamp_timeout=0) exits 3
    instead of failing every later sudo step
  - preflight: the sudo banner drops the NOPASSWD drop-in; an absent findmnt
    is named as the root-UUID failure
  - preflight: the dual-stack warning says to edit the nftables generator in
    both scripts
  - packages: a pacman database lock at the package step reverts the seeded
    mkinitcpio.conf
  - configuration: an nft -c a lapsed sudo cannot run refuses the deploy as a
    sudo lapse, not an invalid ruleset
  - configuration: a sudo-lapse directory create failure says so; a mode drift
    chmod cannot repair warns on stderr
  - backup: a directory at the .ry.bak path is never written into
  - services: an ext4 fstab row with more than one commit= is rewritten to a
    single commit=10
  - services: an fstab row naming ext4 with fewer than 4 fields is left
    untouched and turns the fstab row WARN
  - services: a findmnt --verify failure logs its full output along with its
    [E] and [W] lines
  - services: with ufw.service masked and nftables down, a loud SECURITY
    warning names the fix; the mask row says no firewall
  - services: an enable FAIL row names the units that failed to start; a
    pacman -Qq failure is a local database read error
  - boot: post-rebuild sanity checks each linux entry's kernel and initrd
    lines, skips efi entries, names a missing entries dir
  - boot: the ESP-not-vfat and unresolved-$BOOT refusals drop the manual
    rebuild step
  - boot: the ESP-not-vfat refusal no longer claims a non-systemd-boot
    bootloader; it says to mount the ESP and re-run
  - finalize: an NM restart deferred over Wi-Fi stays owed in pending-apply
    until a run off Wi-Fi or a reboot applies it
  - finalize: the PowerDevil re-apply uses try-restart and never starts the
    unit outside a session
  - install-file: the nftables and udev post-hook failures say how the
    deployed file applies and what to re-run
  - install-file: the DO NOT REBOOT banner cites exit 4 and the [ERR] lines
    and says to re-run the same --install-file
  - install-file: an environment.d deploy uses try-restart for PowerDevil; an
    NM restart deferred over Wi-Fi stays owed
  - logging: a JSONL string ending in a newline keeps it; a run whose stderr
    write fails stops writing to the terminal
  - logging: _run reads 124 or 137 as a timeout only once the cap has elapsed;
    a removed log symlink is logged
  - logging: an unresolved --install-file path is logged; no TMPFILE_STUCK
    line follows the footer
  - logging: a failed signal-time revert prints the restore command for the
    mkinitcpio.conf snapshot it left
  - progress: a terminal resize re-pins the bar on the new bottom row; an
    aborted run still counts 6 phases
  - summary: the result matrix rule matches the full row width


7.235.0 - 7.242.0
-----------------

  - cli: 7.241.0 help aligns its ENVIRONMENT column
  - packages: 7.235.0 a PKGS_ADD member an installed package conflicts with
    sits out -Syu, installs alone with --ask=4 (pipewire-jack replaces jack2)
  - packages: 7.235.0 the -Syu FAIL row names its cause and missing count;
    manual fixes read pacman -Syu --needed instead of a partial-upgrade -S
  - packages: 7.240.0 a member an installed -git or -bin build provides and
    conflicts with is swapped in after -Syu instead of aborting both passes
  - packages: 7.240.0 the post-install check counts members by name, so a
    failed swap of a provided member reads FAIL
  - packages: 7.240.0 pacman -Si and -Qi output is read with COLUMNS=0; an
    exported COLUMNS no longer wraps a conflict list past the parser
  - configuration: 7.240.0 an nft -c timeout reads as a timeout, not as a
    failed ruleset
  - services: 7.235.0 PKGS_DEL removal is held after an earlier package or
    boot-file failure; a hook or scriptlet error reads WARN
  - services: 7.240.0 a mask or enable FAIL row names the failing units;
    7.241.0 a per-unit mask retry row keeps the ufw.service withheld note
  - services: 7.240.0 the fstab rewrite drops nolazytime like *atime; a row
    carrying it no longer reads as conformant
  - services: 7.242.0 every pacman transaction runs with LC_ALL=C.UTF-8; a
    PKGS_DEL removal whose hook logged an error reads WARN in any locale
  - boot: 7.235.0 a refused rebuild no longer prints manual mkinitcpio -P
    steps; the banner says to resolve the earlier FAIL and re-run
  - install-file: 7.241.0 an nft -c timeout in the nftables post-hook reads as
    a timeout, not as a failed ruleset
  - logging: 7.235.0 a failed command echoes its error lines instead of its
    first five; pending-apply is rewritten only when the owed set changes
  - logging: 7.240.0 a failed pacman echo keeps 'exists in filesystem' lines;
    7.242.0 its error lines in any locale
  - consistency: 7.242.0 error text reads 'unparsable', not 'unparseable'


7.234.0
-------

  - guard: a sourced or piped run is refused under any locale
  - signals: a SIGINT, SIGTERM or SIGHUP during startup exits 128+N instead of
    0; the handler no longer registers QUIT
  - cli: -h and -v exit 1 when stdout is closed or full; --install-file
    rejects --report as its value
  - logging: a signal or tmpfile helper before the header no longer leaves a
    footer-only or header-second JSONL
  - logging: child SIGKILL, a failed pending-apply clear, an absent modinfo
    and a skipped mkinitcpio.conf snapshot are logged
  - preflight: the hardware override hint keeps --install-file; iommu=off
    counts as no IOMMU for amdxdna
  - preflight: a failed timedatectl query and an absent ping are named;
    low-disk and RY_RUN_TIMEOUT warnings print in install mode
  - preflight: leading zeros in RY_RUN_TIMEOUT carry no magnitude
  - preflight: a HOOKS entry needs a build script in an initcpio install dir;
    a hooks/ script alone no longer passes
  - backup: the post-write restore uses only the .ry.bak this run took; the
    copy never writes through a symlink at the backup path
  - packages: a failed pactree probe is reported as held, not as nothing
    installed
  - packages: a PKGS_DEL member removed by another's -s cascade is not
    reported failed
  - services: a unit that masks but fails to stop is a WARN, not a FAIL; the
    enable-start WARN covers persistent enable states only
  - services: the fstab row is WARN when a digits-only ext4 row is left; a
    preserved mkinitcpio.conf snapshot path prints in install mode
  - boot: the DO-NOT-REBOOT inspect step uses sudo and the resolved $BOOT
  - summary: the verdict is still logged when stderr is gone; --install-file
    prints Installed only when bytes changed
  - progress: the bar reads the terminal size from the stderr tty


7.233.0
-------

  - install-file: a re-run on a boot file runs the boot cascade even when its
    bytes are unchanged
  - install-file: mkinitcpio.conf and sdboot-manage.conf check HOOKS and
    MODULES before the write and exit 3
  - install-file: with nft(8) absent the nftables post-hook says so instead of
    reporting a failed nft -c
  - configuration: an nft -c failure after an upgrade removed the running
    kernel's modules is named, with reboot then re-run as the next step
  - configuration: a managed file with bytes after a NUL is rewritten instead
    of reported unchanged
  - packages: after a failed -Syu, a reverted mkinitcpio.conf stays in place
    through Configuration (WARN 'mkinitcpio.conf held')
  - packages: PKGS_ADD is re-marked explicit whatever the -Syu result and
    again before -Rns
  - services: a unit that enables but fails to start reads WARN on the enable
    row, naming the unit, and the warning prints during the run
  - services: the live nftables policy-drop probe before the ufw flush matches
    only the input hook line
  - finalize: a run that stops before Finalize records the restarts it owes in
    ~/ry-install/pending-apply; the next run of the same boot applies them
  - preflight: the /boot free-space gate runs on stacked mounts; ESP
    autodetect and the vfat gate read the topmost non-autofs mount
  - preflight: a setgid $HOME or a symlinked ~/ry-install no longer fails the
    log-dir mode check
  - preflight: the sudo credential check keeps sudo's error text in memory
    instead of a /tmp file
  - lock: only the lock holder sweeps destination dirs; a peer refused with
    exit 5 no longer deletes the holder's in-flight tmpfiles
  - lock: stale-lock reclaim takes an exclusive claim and moves the stale dir
    aside in one rename
  - lock: release checks the pidfile still carries this run's record
  - lock: a pidfile from an earlier boot or a reused PID is reclaimed instead
    of exiting 5; an unreadable identity fails closed
  - lock: a signal between the lock mkdir and the pidfile write no longer
    leaves an empty .lock behind
  - cleanup: tracked tmpfiles in the root-only /run/ry-install are removed via
    sudo
  - cli: --h, --he, --hel and --v through --versio are honored before the root
    guard


7.217.0 - 7.232.0
-----------------

  - kernel: 7.217.0 drop ttm.pages_limit=20971520
  - perf: 7.217.0 governor performance -> powersave, EPP performance kept
  - network: 7.224.0 NetworkManager leaves the Wi-Fi P2P device unmanaged
  - env: 7.217.0 RADV_PERFTEST=nggc -> nggc,nircache; 7.224.0 add
    SDL_GAMECONTROLLER_IGNORE_DEVICES (Keychron K2 HE, Link receiver)
  - configuration: 7.224.0 manage a WirePlumber soft-mixer rule (POROSVOC mic)
    that restarts wireplumber.service; 7.229.0 drop it and its post-hook
  - configuration: 7.229.0 MangoHud comments out text_outline, adds
    no_small_font and alpha=0.8; 7.232.0 sets text_outline=0
  - packages: 7.224.0 add pipewire-jack
  - services: 7.218.0 enable-units counts only units it enabled or started;
    7.219.0 a oneshot nftables.service no longer reads as newly enabled
  - backup: 7.231.0 a sudo lapse at the existence probe is warned and logged
    instead of silently skipping the copy
  - preflight: 7.219.0 MODULES are checked against each installed kernel;
    7.224.0 a locked pacman database stops the run before anything is deployed
  - preflight: 7.225.0 the modprobe.d format check names directives in match
    order
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
  - services: 7.211.0 db.lck refusals name the manual fix; the fstab symlink
    refusal offers no skip
  - sysctl: 7.195.0 add vm.watermark_scale_factor=125
  - cleanup: 7.207.0 a signal-time revert removes the empty /run/ry-install
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


7.100.0 - 7.138.0
-----------------

  - kernel: 7.123.0 - 7.129.0 add mt7925e.disable_aspm=1 and
    kernel.nmi_watchdog=0
  - dns: 7.123.0 - 7.129.0 pin upstreams in resolved and the NM global-dns
    section
  - env: 7.123.0 - 7.129.0 FSR4_UPGRADE -> PROTON_FSR4_UPGRADE; drop
    VKD3D_CONFIG
  - perf: 7.130.0 - 7.131.1 governor and EPP performance, GPU DPM level high
  - configuration: 7.100.0 - 7.107.3 17 configs deployed atomically; 7.137.0 -
    7.138.0 drop the dormant RY_REMOTE_PLAY_PORTS nftables gate
  - boot: 7.100.0 - 7.107.3 boot failures exit 4, skip finalization
  - boot: 7.108.0 - 7.117.0 mkinitcpio.conf snapshot and byte-exact revert;
    fstab atomic replace behind parity, size and findmnt gates
  - services: 7.118.0 - 7.122.0 mask ufw instead of removing; the
    nftables-first gate withholds ufw.service
  - install: 7.135.0 - 7.136.1 fix .ry.orig preserve dead under an if-scoped
    set -l
  - install-file: 7.108.0 - 7.117.0 post-hook dispatch table with per-target
    handlers
  - lock: 7.108.0 - 7.117.0 dead-PID reclaim only, live or ambiguous pidfiles
    fail closed
  - summary: 7.132.0 - 7.134.0 abort path used the normal path's name for the
    phase-3 row


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro
