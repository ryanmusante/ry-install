Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.300.0
-------

  - consistency: the _run capture and fstab size errors read capture directory
    and temp file, as the rest of the output does
  - changelog: split the oversized newest range into four medium ranges and
    trim bullets


7.260.0 - 7.276.0
-----------------

  - configuration: 7.260.0 a boot file unreadable with sudo cached FAILs and
    is restored from its .ry.bak
  - configuration: 7.267.0 a refused temp-file chmod, move, or owner or mode
    repair, 7.270.0 or temp-file write, names the lapsed cache
  - configuration: 7.271.0 an existing parent dir is not re-created with sudo;
    the deploy FAIL row names the lapse
  - packages: 7.267.0 - 7.271.0 a refused snapshot, snapshot probe, -Syu
    pass, -Syyu retry, revert or pre-deploy reads not run, naming the lapse
  - guard: 7.260.0 fish_read_limit is pinned to 1 GiB; 7.264.0 a few-byte
    inherited one no longer breaks startup or a piped run's refusal
  - preflight: 7.260.0 the ESP gate refuses an ESP not at /boot or an XBOOTLDR
    $BOOT; a /boot linked to the ESP gets the free-space gate
  - preflight: 7.268.0 a ppid-scoped sudo ticket exits 3; a background sudo -n
    true every 30 s keeps the ticket alive until exit
  - preflight: 7.269.0 a verifypw that lets sudo -v skip authentication
    prompts once on a TTY; 7.274.0 an unmanaged boot-critical path is refused
  - lock: 7.276.0 a symlinked lock directory, dangling or not, is refused as a
    symlink, not as a failed mkdir or a stale claim
  - backup: 7.267.0 a backup copy or post-write restore that sudo refused
    reads not run
  - services: 7.260.0 a start, enable or mask failing as sudo expires reads
    failed; a resolved restart sudo refused reads not run
  - services: 7.267.0 - 7.271.0 a refused PKGS_DEL, mask or enable batch,
    fstab step, nft probe or ufw disable reads not run, naming the lapse
  - services: 7.272.0 after sudo refused the -D re-mark or the enable batch,
    no PKGS_DEL removal or preset start is tried
  - boot: 7.260.0 sanity reads entries as systemd-boot does, fails a linux
    entry with no initrd line, and stops at the first lapse
  - boot: 7.267.0 a refused rebuild step logs not run; 7.271.0 a sanity FAIL
    names the lapse, a refused revert reads not run
  - finalize: 7.260.0 a refused NM restart or cache trim reads not run;
    7.267.0 a refused -ruk0 after -rk2 reads cut short
  - install-file: 7.260.0 boot gates refuse an ESP not at /boot or an XBOOTLDR
    $BOOT; an NM drop-in without NetworkManager owes no restart
  - install-file: 7.267.0 a refused cascade step, daemon-reload, restart or
    udev call, 7.270.0 or sysctl, nft -c or verify, reads not run
  - logging: 7.260.0 RY_RUN_TIMEOUT warnings count; 7.265.0 every run logs
    KERNEL_RELEASE; 7.267.0 - 7.270.0 refused steps log _LAPSE
  - logging: 7.271.0 TMPFILE_STUCK tells a lapsed sudo cache from a missing
    sudo; 7.274.0 POSTWRITE_VERIFY_FAIL logs ERR for a missing digest
  - consistency: 7.264.0 messages read user bus, re-deploy and pidfile;
    7.265.0 --help and the README name the 7200 s floor
  - consistency: 7.273.0 - 7.275.0 messages drop sentence periods and
    abbreviations; refusals read refusing to; --help groups its sections
  - consistency: 7.276.0 the dispatcher reload and WirePlumber OKs match their
    WARNs; RY_RUN_TIMEOUT WARNs print the value bare


7.256.0 - 7.258.0
-----------------

  - configuration: 7.256.0 WP_BLUEZ_ROLES sets bluez5.roles, no `hfp_*/hsp_*`
    role, in wireplumber.conf.d/51-ry-bluez-roles.conf
  - configuration: 7.257.0 a sudo lapse before the temp copy FAILs the file; a
    boot file's post-write check compares sizes
  - packages: 7.257.0 after a failed seed Configuration holds the restored
    mkinitcpio.conf; a failed install counts once in the footer
  - packages: 7.257.1 -Syu also installs EXPECTED_VULKAN_PKGS, swapping out a
    conflicting -git or -bin build; 7.258.0 only missing ones
  - packages: 7.258.0 a pass a pre-transaction hook stopped reads nothing
    committed; a failed conflict swap is named on the -Syu row
  - guard: 7.258.0 fish_read_limit is pinned to 100 MiB, so a config.fish or
    universal value no longer fails a large output
  - signals: 7.257.0 a pacman dying with its lock makes DO NOT REBOOT say to
    remove db.lck
  - preflight: 7.256.0 WP_BLUEZ_ROLES entries must be PipeWire role names;
    7.257.1 an EXPECTED_VULKAN_PKGS member in PKGS_DEL is refused
  - preflight: 7.258.0 an unresolvable $BOOT or a non-vfat fallback /boot
    exits 3 before -Syu; true(1) and test(1) are checked at startup
  - backup: 7.257.0 a failed .ry.bak copy WARNs on the terminal
  - services: 7.257.0 the enable row counts only units this run enabled; a
    failed fstab scan FAILs the fstab step
  - services: 7.258.0 a MASK unit removed while running is masked and stopped;
    a PKGS_DEL member failing before its dependent is retried
  - services: 7.258.0 a stopped NetworkManager.service is started; on systemd
    253+ an empty is-enabled answer no longer skips a unit
  - boot: 7.257.0 an entry name ending in .. passes sanity; 7.258.0 an empty
    kernel or a non-regular initrd fails it
  - finalize: 7.256.0 a changed or owed bluez5.roles drop-in try-restarts
    wireplumber.service; 7.257.0 its row and PowerDevil's say changed or owed
  - install-file: 7.256.0 the bluez5.roles drop-in try-restarts WirePlumber,
    owed when that fails; 7.257.0 a stopped WirePlumber claims nothing
  - install-file: 7.257.0 the nft and udevadm verify hints name the script;
    7.258.0 a udevadm verify sudo refused is no verdict
  - logging: 7.257.0 a failed restart, daemon-reload, cache trim or indexer
    run logs a _FAIL key; a non-UTF-8 byte logs as U+FFFD
  - logging: 7.258.0 failed revert, snapshot and fstab steps log their error;
    new MASK_*FAIL, ENABLE_*FAIL and SKIP_PROBE_SUDO_LAPSE keys
  - summary: 7.257.0 a -Syu that changed packages adds a manual step to review
    the news; 7.258.0 a failed boot step gives its rc


7.254.0 - 7.255.0
-----------------

  - configuration: 7.254.0 an nft -c that could not run refuses as not run;
    7.255.0 a system file not owned by root:root is chowned back
  - packages: 7.254.0 a no-op seed drops its rollback, overflow error lines
    stay in order; 7.255.0 a failed seed reverts its bytes
  - packages: 7.255.0 a swap hook error leads its row; a refused -Syyu retry,
    swap, explicit mark, updatedb or pkgfile reads not run
  - signals: 7.254.0 a pass or removal failing mid-transaction keeps DO NOT
    REBOOT owed until the rebuild, even after a refused pass
  - signals: 7.255.0 a signal before the seed lands no longer rewrites it; one
    after -Syu no longer reverts the seed
  - cli: 7.254.0 argument errors and a root run's leftovers escape control
    characters, C1 and raw bytes; -h or -v ending in a newline exits 2
  - preflight: 7.254.0 a relative HOME, 7.255.0 or one with a control
    character, takes the passwd entry; such a passwd entry exits 3
  - preflight: 7.254.0 an embedded value or RY_RUN_TIMEOUT ending in a newline
    is refused or reads invalid; the root UUID takes findmnt's first match
  - preflight: 7.254.0 a TLS failure names the clock or a TLS proxy; 7.255.0
    curl rc 77 names SSL_CERT_FILE, CURL_CA_BUNDLE and ca-certificates
  - preflight: 7.255.0 uncached sudo with no TTY prints one ERR; hints name
    the script as invoked; validation goes by managed path
  - lock: 7.254.0 the lock dir is set 00700, clearing an inherited setgid bit;
    7.255.0 a lock not taken logs ERR and counts in the footer
  - lock: 7.254.0 - 7.255.0 a signal while releasing no longer strands .claim
    or the lock dir; a holder releasing mid-check no longer exits 5
  - services: 7.254.0 the fstab rewrite no longer refuses over a parse error
    the original carries; an fstab with only malformed ext4 rows WARNs
  - services: 7.254.0 a lapsed mask retry FAILs (MASK_LAPSE);
    7.254.0 - 7.255.0 the enable row WARNs for a unit not installed
  - services: 7.255.0 mask --now stops a masked unit still activating; ufw
    masked with nftables down names a diagnosis
  - boot: 7.254.0 the rebuild step prints bootctl --graceful update; 7.255.0
    sanity lists entries as systemd-boot does, failing an unreadable one
  - install-file: 7.254.0 a cpupower deploy without cpupower.service skips the
    restart; a hook only root can see no longer reads as invalid
  - install-file: 7.254.0 an nft -c or udevadm verify that could not run or
    timed out is no verdict; a successful apply strikes its owed entry
  - install-file: 7.254.0 each managed file runs its own post-hook, so a HOME
    under a directory such as sysctl.d no longer reroutes a user file
  - install-file: 7.255.0 a HOME under /etc or /boot no longer reads user
    files via sudo; a boot file runs the dependency and ESP gates first
  - logging: 7.254.0 the end-of-run summary is JSONL-only; 7.255.0 one failure
    counts once in the footer
  - progress: 7.254.0 a signal while the bar pins or unpins no longer leaves
    the scroll region set or clears the top row


7.246.0 - 7.252.0
-----------------

  - env: 7.248.0 SDL_GAMECONTROLLER_IGNORE_DEVICES gains 0x3434/0x0b00 (Q0 HE)
  - configuration: 7.248.0 libinput ignores the Xbox Wireless Controller;
    7.250.0 a managed symlink in a root-only directory is replaced
  - configuration: 7.251.0 the 60-ry-modules.conf header claims no module
    options; 7.252.0 a sudo lapse before the atomic move FAILs the file
  - packages: 7.246.0 a missing member whose dependency conflicts is held for
    the swap; an rc-0 -Syu or swap whose hooks log errors reads WARN
  - packages: 7.247.0 a -Syu pass a dependency conflict stops holds the member
    pulling it and runs again
  - packages: 7.251.0 a failed pacman -Q counts as an upgrade; 7.252.0 a hook
    error past the 500-line capture reads WARN
  - guard: 7.247.0 an early exit keeps a ~/ry-install/backups it did not
    create; inherited rollback variables never drive a revert
  - guard: 7.250.0 inherited internal state (env, config.fish) is erased; a
    universal named like it, or regex-easyesc off, exits 3
  - guard: 7.250.0 an early exit or a signal before the JSONL header removes
    only the empty dirs this run created and runs no user _do_cleanup
  - guard: 7.250.0 config.fish job control or IFS no longer steers a run;
    7.251.0 a universal _ROOT_UUID cannot reach the kernel cmdline
  - signals: 7.250.0 a signal mid-banner or after a package, boot-critical
    file or revert failure prints DO NOT REBOOT
  - signals: 7.250.0 a second startup signal no longer exits 0 or 1; one in an
    early exit's last step, 7.251.0 or before the main handler, keeps its code
  - signals: 7.251.0 - 7.252.0 a signal during a pacman transaction, PKGS_DEL
    removal, failure report, revert or restore prints DO NOT REBOOT
  - signals: 7.252.0 a pass alpm refused at prepare no longer marks the run
    mid-transaction
  - preflight: 7.247.0 MODULES and HOOKS tokens are charset-checked; 7.252.0
    an empty or non-directory HOME names the value
  - backup: 7.250.0 the first .ry.bak copy creates ~/ry-install/backups, so no
    early exit removes it
  - services: 7.247.0 a PKGS_DEL hook error keeps the row's rdep-skip count;
    7.250.0 a root-only resolved drop-in no longer skips the restart
  - services: 7.251.0 a lapse-blocked owed resolved restart reads WARN;
    7.252.0 the fstab rewrite tolerates errors the original carries
  - services: 7.252.0 a masked ufw.service reads firewall unverified under a
    lapsed cache; SECURITY says whether the mask follows or holds
  - boot: 7.250.0 - 7.252.0 an ESP-fallback host's DO NOT REBOOT banner says
    to check the ESP and re-run, never sdboot-manage gen
  - boot: 7.252.0 the EFI refresh runs bootctl --graceful update and fails on
    its error
  - install-file: 7.249.0 a boot-critical failure prints DO NOT REBOOT and its
    recovery steps once, in the closing banner
  - install-file: 7.252.0 an environment.d or bluetooth deploy without its
    unit skips the restart without a WARN
  - logging: 7.246.0 a failed pacman call echoes its package-conflict lines;
    7.247.0 a failed summary or banner write logs STDERR_WRITE_FAIL
  - logging: 7.250.0 the preflight log starts early; 7.251.0 - 7.252.0 new
    HARDWARE_MATCH, ROOT_UUID_OK and PENDING_APPLY_* keys


7.235.0 - 7.245.0
-----------------

  - configuration: 7.240.0 an nft -c timeout reads as a timeout, 7.245.0 exit
    124 or 137 as timed out or killed
  - configuration: 7.243.0 an nft -c a lapsed sudo cannot run, or a failed
    directory create, names the lapse; a mode drift chmod cannot repair warns
  - packages: 7.235.0 a PKGS_ADD member in conflict sits out -Syu and installs
    alone with --ask=4 (pipewire-jack replaces jack2)
  - packages: 7.235.0 the -Syu FAIL row names its cause and missing count;
    manual fixes read pacman -Syu --needed, not a partial -S
  - packages: 7.240.0 a member a -git or -bin build provides is swapped in
    after -Syu
  - packages: 7.243.0 a locked pacman db reverts the seeded mkinitcpio.conf;
    7.245.0 the held WARN names the rollback; -Syyu re-reads holds
  - guard: 7.243.0 TMPDIR is pinned to /tmp; 7.245.0 an early exit removes
    ~/ry-install only if this run made it
  - signals: 7.243.0 a signal during the boot rebuild prints DO NOT REBOOT;
    7.245.0 the mv -T probe strands no temp files; no PIPE handler
  - cli: 7.243.0 argument errors write no /tmp file; 7.245.0 an over-long
    RY_RUN_TIMEOUT warns that 2147483647 is used
  - preflight: 7.243.0 a sudo -v caching nothing (timestamp_timeout=0),
    7.245.0 or leaving sudo -n unusable, exits 3
  - preflight: 7.243.0 an absent findmnt is named; 7.245.0 missing optional
    tools warn
  - lock: 7.245.0 lock hints quote the path and pass --preserve-root; a
    kill-less host takes the /proc lock branch silently
  - backup: 7.243.0 a directory at the .ry.bak path is never written into
  - services: 7.235.0 PKGS_DEL removal is held after an earlier package or
    boot-file failure; a hook or scriptlet error reads WARN
  - services: 7.240.0 a mask or enable FAIL names the failing units; the fstab
    rewrite drops nolazytime like *atime
  - services: 7.242.0 pacman transactions run with LC_ALL=C.UTF-8, so a
    PKGS_DEL hook error reads WARN in any locale
  - services: 7.243.0 several commit= become one commit=10; ufw masked with
    nftables down prints a loud SECURITY warning naming the fix
  - services: 7.243.0 a failed findmnt --verify is logged in full, 7.245.0 [E]
    lines first
  - services: 7.245.0 a masked unit still running is masked with --now; a
    resolved restart owed by an interrupted run stays owed
  - boot: 7.235.0 a refused rebuild prints no manual mkinitcpio -P steps;
    7.245.0 a symlinked loader/entries dir is listed
  - boot: 7.243.0 sanity checks each linux entry's kernel and initrd lines,
    skips efi entries, and names a missing entries dir
  - finalize: 7.243.0 an NM restart deferred over Wi-Fi stays owed; 7.245.0 a
    pending-apply marker from an earlier boot is dropped
  - install-file: 7.241.0 an nft -c timeout reads as a timeout; 7.243.0 nft -c
    and udevadm verify failures say how the file applies
  - install-file: 7.243.0 the DO NOT REBOOT banner cites exit 4 and says to
    re-run the same --install-file; environment.d uses try-restart
  - install-file: 7.245.0 mkinitcpio.conf and sdboot-manage.conf run the
    disk-space gate first (exit 3); a failed nftables reload names the retry
  - logging: 7.235.0 a failed command echoes its error lines; 7.240.0 a failed
    pacman's 'exists in filesystem' lines too, 7.242.0 in any locale
  - logging: 7.243.0 a JSONL string keeps a trailing newline; a failed stderr
    write stops terminal output
  - logging: 7.245.0 STDERR_WRITE_FAIL logs once, and a signal no longer stops
    the footer; TIMEOUT_LONGOP_CAP is TIMEOUT_LONGOP_FLOOR
  - progress: 7.243.0 a resize re-pins the bar; an aborted run counts 6
    phases; 7.245.0 the bar unpins before its last writes
  - consistency: 7.242.0 error text reads 'unparsable', not 'unparseable'


7.217.0 - 7.234.0
-----------------

  - kernel: 7.217.0 drop ttm.pages_limit=20971520
  - perf: 7.217.0 governor performance -> powersave, EPP performance kept
  - network: 7.220.0 NetworkManager leaves the Wi-Fi P2P device unmanaged
  - env: 7.217.0 RADV_PERFTEST=nggc -> nggc,nircache; 7.220.0 add
    SDL_GAMECONTROLLER_IGNORE_DEVICES (Keychron K2 HE, Link receiver)
  - configuration: 7.220.0 manage a WirePlumber soft-mixer rule (POROSVOC mic)
    that restarts wireplumber.service; 7.229.0 drop it and its post-hook
  - configuration: 7.229.0 MangoHud comments out text_outline, adds
    no_small_font and alpha=0.8; 7.232.0 sets text_outline=0
  - configuration: 7.233.0 an nft -c failing because an upgrade removed the
    running kernel's modules is named; bytes after a NUL are rewritten
  - packages: 7.220.0 add pipewire-jack; 7.233.0 after a failed -Syu, a
    reverted mkinitcpio.conf stays in place through Configuration
  - packages: 7.233.0 PKGS_ADD is re-marked explicit whatever the -Syu
    result; -Rns runs only after a successful mark, else -Rn
  - packages: 7.234.0 a failed pactree probe reads as held, not as nothing
    installed; a member another's -s cascade removed is not failed
  - guard: 7.234.0 a sourced or piped run is refused under any locale
  - signals: 7.234.0 a startup SIGINT exits 130, not 0, and every startup
    signal prints a notice; QUIT is no longer registered
  - cli: 7.218.0 a repeated --install-file exits 2, an unmanaged one before
    the hardware gate; 7.233.0 --h through --versio work before the root guard
  - cli: 7.234.0 -h and -v exit 1 on a full stdout (closed too, under fish 3)
  - preflight: 7.219.0 MODULES are checked against each installed kernel;
    7.224.0 a locked pacman database stops the run before any deploy
  - preflight: 7.225.0 the modprobe.d check names directives in match order
  - preflight: 7.233.0 the /boot space gate and ESP checks read the topmost
    non-autofs mount; a setgid $HOME or symlinked ~/ry-install passes
  - preflight: 7.234.0 iommu=off counts as no IOMMU; HOOKS need a build
    script; RY_RUN_TIMEOUT and low-disk warnings print in install mode
  - lock: 7.233.0 only the holder sweeps destination dirs, so a peer refused
    with exit 5 deletes none of its tmpfiles
  - lock: 7.233.0 stale reclaim takes an exclusive claim; a pidfile from an
    earlier boot or a reused PID is reclaimed, an unreadable one fails closed
  - backup: 7.231.0 a sudo lapse at the existence probe is warned and logged;
    7.234.0 the restore uses only this run's .ry.bak, never via a symlink
  - services: 7.218.0 enable-units counts only units it enabled or started;
    7.219.0 a oneshot nftables.service no longer reads newly enabled
  - services: 7.233.0 a unit that enables but fails to start reads WARN,
    naming it; the pre-flush policy-drop probe reads the input hook
  - services: 7.234.0 a unit that masks but fails to stop is a WARN; a
    digits-only ext4 row turns the fstab row WARN
  - boot: 7.234.0 the DO NOT REBOOT inspect step uses sudo and resolved $BOOT
  - finalize: 7.233.0 a run that stops before Finalize records the restarts it
    owes in ~/ry-install/pending-apply
  - install-file: 7.233.0 a boot-file re-run runs the cascade, changed or not;
    mkinitcpio.conf and sdboot-manage.conf check HOOKS and MODULES first
  - cleanup: 7.233.0 root-only /run/ry-install tmpfiles are removed via sudo
  - logging: 7.234.0 a signal before the header leaves no footer-only JSONL;
    child SIGKILL, absent modinfo and a skipped snapshot are logged
  - summary: 7.234.0 the verdict is logged when stderr is gone; --install-file
    prints Installed only when bytes changed


7.190.0 - 7.216.0
-----------------

  - kernel: 7.195.0 fsck.mode=force; 7.199.0 add ttm.pages_limit=20971520;
    7.204.0 add nowatchdog
  - perf: 7.204.0 governor performance -> powersave; 7.211.0 performance again
  - network: 7.200.0 disable NetworkManager connectivity checking
  - env: 7.195.0 GSK_RENDERER ngl -> gl, drop PROTON_FSR4_INDICATOR=1; 7.212.1
    add RADV_PERFTEST=nggc and MANGOHUD_DLSYM=1
  - sysctl: 7.195.0 add vm.watermark_scale_factor=125
  - configuration: 7.195.0 MangoHud cpu_stats on, cpu_temp off; 7.203.0 a
    header on all but /etc/kernel/cmdline, nftables drops its ports invite
  - configuration: 7.205.0 cpupower header names EnvironmentFile=; 7.211.0
    udev comments print EPP and GPU levels; resolved drops mDNS/LLMNR claim
  - packages: 7.198.0 add dmemcg-booster and plasma-foreground-booster;
    7.200.0 drop both
  - cli: 7.211.0 glued short flags take only h and v; -Vh and -hV fail like -V
  - preflight: 7.211.0 a missing root UUID names findmnt's rc or empty output
  - lock: 7.211.0 a pidfile without a PID reads 'holds no PID'
  - services: 7.197.0 ufw mask needs nftables.service; 7.203.0 a withheld mask
    is a WARN, 7.206.0 its SECURITY note INFO; 7.207.0 skip not-found units
  - services: 7.211.0 db.lck refusals name the manual fix; the fstab symlink
    refusal offers no skip
  - boot: 7.206.0 rebuild hints name sdboot-manage update; 7.211.0 no-entries
    hint drops --verbose, a sudo lapse no longer reads 'backup file missing'
  - install-file: 7.201.0 a symlinked destination becomes a regular file;
    7.206.0 INSTALL-FILE END on every return, hook failures log POST_*
  - install-file: 7.206.0 - 7.207.0 the udev retry hint joins its commands
    with &&; 7.211.0 live-apply hooks print OK, five messages corrected
  - cleanup: 7.207.0 a signal-time revert removes the empty /run/ry-install
  - logging: 7.206.0 signal-time revert logs before the footer; 7.207.0 log
    suffixes _FAIL/_SKIP/_LAPSE; 7.211.0 banner and signals log before stderr
  - summary: 7.206.0 PASS-WITH-WARNINGS Next says reboot, group steps follow
    the matrix, aborts record every SKIP row; 7.208.0 tainted SKIP names state
  - split: 7.190.0 move ry-verify.fish to its repository


7.139.0 - 7.189.0
-----------------

  - kernel: 7.160.0 drop clearcpuid=umip; 7.162.0 land on iommu=pt, drop the
    amdxdna blacklist; 7.164.0 drop amd_iommu
  - network: 7.163.0 autoconnect-retries-default=0
  - dns: 7.148.0 drop pinned upstreams, DNSOverTLS= and DNSSEC=; link DNS wins
  - env: 7.154.0 PROTON_FSR4_UPGRADE -> FSR4_WATERMARK; 7.156.0 drop
    PROTON_ENABLE_WAYLAND=1; 7.163.0 add GSK_RENDERER=ngl
  - env: 7.181.0 FSR4_WATERMARK -> PROTON_FSR4_INDICATOR=1
  - sysctl: 7.157.0 drop both net.core.netdev_budget keys; 7.171.0 drop
    vm.swappiness=150
  - configuration: 7.159.0 ICMPv6 base accept in nftables
  - packages: 7.173.0 add cachyos-benchmarker
  - preflight: 7.185.1 an NM_WIFI_POWERSAVE outside 0-3 exits 3, as a reserved
    COUNTRY does
  - backup: 7.174.0 .ry.bak moves to ~/ry-install/backups; 7.176.0 drop
    .ry.orig
  - fstab: 7.182.1 parity probe never ran
  - boot: 7.140.0 drop -T0; 7.158.0 COMPRESSION_OPTIONS -1 -> -3,
    fsck.mode=force -> auto
  - install: 7.171.0 chmod on mode drift, bytes unchanged
  - install-file: 7.177.3 -h and -v were swallowed after --install-file
  - split: 7.177.0 move verify and check to ry-verify.fish


7.100.0 - 7.138.0
-----------------

  - kernel: 7.123.0 - 7.129.0 add mt7925e.disable_aspm=1 and
    kernel.nmi_watchdog=0
  - perf: 7.130.0 - 7.131.1 governor and EPP performance, GPU DPM level high
  - dns: 7.123.0 - 7.129.0 pin upstreams in resolved and NM global-dns
  - env: 7.123.0 - 7.129.0 FSR4_UPGRADE -> PROTON_FSR4_UPGRADE; drop
    VKD3D_CONFIG
  - configuration: 7.100.0 - 7.107.3 17 configs deployed atomically;
    7.137.0 - 7.138.0 drop the dormant RY_REMOTE_PLAY_PORTS nftables gate
  - lock: 7.108.0 - 7.117.0 dead-PID reclaim only, live or ambiguous pidfiles
    fail closed
  - services: 7.118.0 - 7.122.0 mask ufw instead of removing; the
    nftables-first gate withholds ufw.service
  - boot: 7.100.0 - 7.107.3 boot failures exit 4, skip finalization
  - boot: 7.108.0 - 7.117.0 mkinitcpio.conf snapshot and byte-exact revert;
    fstab atomic replace behind parity, size and findmnt gates
  - install: 7.135.0 - 7.136.1 fix .ry.orig preserve dead under an if-scoped
    set -l
  - install-file: 7.108.0 - 7.117.0 a post-hook dispatch table
  - summary: 7.132.0 - 7.134.0 abort path's phase-3 row took the normal name


7.99.1 and earlier
------------------

  - profile: initial profile for the Beelink GTR9 Pro
