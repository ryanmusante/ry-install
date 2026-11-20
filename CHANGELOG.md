Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.275.0
-------

  - consistency: the remaining refusals read refusing to deploy, reclaim, run
    or emit; PKGS_DEL output spells out dependencies


7.246.0 - 7.274.0
-----------------

  - env: 7.248.0 SDL_GAMECONTROLLER_IGNORE_DEVICES gains 0x3434/0x0b00 (Q0 HE)
  - configuration: 7.247.0 a post-write mismatch with only an older run's
    .ry.bak says no backup from this run
  - configuration: 7.248.0 libinput ignores the Xbox Wireless Controller
  - configuration: 7.250.0 a managed symlink in a root-only directory is
    replaced; 7.251.0 the 60-ry-modules.conf header claims no module options
  - configuration: 7.252.0 a sudo lapse before the atomic move, 7.257.0 or
    before the temp copy, FAILs the file and names the lapse
  - configuration: 7.254.0 an nft -c that could not run refuses as not run; a
    landed config keeps its owed restart through a signal
  - configuration: 7.255.0 an unchanged system file not owned by root:root is
    chowned back
  - configuration: 7.256.0 WP_BLUEZ_ROLES sets bluez5.roles, no `hfp_*/hsp_*`
    role, in wireplumber.conf.d/51-ry-bluez-roles.conf
  - configuration: 7.257.0 a boot file's post-write check compares sizes; the
    bluez5.roles comment no longer denies an `hfp_*/hsp_*` role
  - configuration: 7.258.0 the held mkinitcpio.conf WARN claims no rollback
    when the seed never landed; a failed revert cmp gives its rc
  - configuration: 7.260.0 a boot file unreadable with sudo cached FAILs and
    is restored from its .ry.bak
  - configuration: 7.260.0 an nft -c or parent-dir mkdir failing as the sudo
    ticket expires reads as failed, not a lapse
  - configuration: 7.267.0 a refused temp-file chmod, move, or owner or mode
    repair, 7.270.0 or temp-file write, names the lapsed cache
  - configuration: 7.271.0 an existing parent dir is not re-created with sudo;
    the deploy FAIL row names the lapse
  - packages: 7.246.0 a missing member whose dependency conflicts with an
    installed package is held for the swap, which gets its own row
  - packages: 7.246.0 an rc-0 -Syu or swap whose hooks log errors reads WARN
  - packages: 7.247.0 a -Syu pass a dependency conflict stops holds the member
    pulling it and runs again
  - packages: 7.250.0 a HOOKS build script behind a 0700 /etc/initcpio/install
    no longer reads missing; 7.251.0 sudo probes only unseen ones
  - packages: 7.251.0 a failed pacman -Q counts as an upgrade; a PKGS_DEL
    member an earlier -Rns took is logged as removed
  - packages: 7.252.0 a hook error past the 500-line capture reads WARN;
    7.254.0 kept error lines stay in order (_OVERFLOW_KEPT)
  - packages: 7.254.0 a no-op seed drops its rollback; 7.255.0 a failed seed
    reverts its bytes, 7.257.0 and Configuration holds the original
  - packages: 7.255.0 a swap hook error leads its row; a refused -Syyu retry,
    swap, explicit mark, updatedb or pkgfile reads not run
  - packages: 7.257.0 a failed install counts once in the footer; a lapse at a
    HOOKS check reads unchecked (a WARN after -Syu)
  - packages: 7.257.1 -Syu also installs EXPECTED_VULKAN_PKGS, swapping out a
    conflicting -git or -bin build
  - packages: 7.258.0 -Syu names only a missing EXPECTED_VULKAN_PKGS member,
    so an IgnorePkg hold stands
  - packages: 7.258.0 a pass a pre-transaction hook stopped reads nothing
    committed; a failed conflict swap is named on the -Syu row
  - packages: 7.267.0 - 7.271.0 a refused snapshot, snapshot probe, -Syu
    pass, -Syyu retry, revert or pre-deploy reads not run, naming the lapse
  - guard: 7.247.0 an early exit keeps a ~/ry-install/backups it did not
    create; inherited rollback variables never drive a revert
  - guard: 7.250.0 state inherited from the environment or config.fish is
    erased; LOCK_DIR and LOCK_FILE values are ignored
  - guard: 7.250.0 a fish universal named like internal state is never read
    and exits 3 naming its set -eU, as does regex-easyesc turned off
  - guard: 7.250.0 an early exit or a signal before the JSONL header removes
    only the empty log and ~/ry-install dirs this run created
  - guard: 7.250.0 an early exit no longer runs a user's _do_cleanup, 7.251.0
    _dc_settle or _write_footer
  - guard: 7.250.0 config.fish job control or IFS no longer steers a run;
    fish_read_limit is pinned, 7.258.0 to 100 MiB, 7.260.0 to 1 GiB
  - guard: 7.250.0 a universal _early_ch is not erased; the root check ignores
    _flag_install_file, 7.251.0 the kernel cmdline _ROOT_UUID
  - guard: 7.264.0 a few-byte inherited fish_read_limit no longer breaks
    startup or a piped run's refusal; a universal `_RPT_*` no longer exits 3
  - signals: 7.250.0 a signal mid-banner or after a package, boot-critical
    file or revert failure prints DO NOT REBOOT, pointing at the JSONL log
  - signals: 7.250.0 a second startup signal no longer exits 0 or 1; one in an
    early exit's last step, 7.251.0 or before the main handler, keeps its code
  - signals: 7.251.0 a signal during a pacman transaction, 7.252.0 or a
    PKGS_DEL removal, prints DO NOT REBOOT
  - signals: 7.251.0 - 7.252.0 a signal during a failure's [ERR] or [FAIL]
    lines, revert or restore prints the banner
  - signals: 7.252.0 a pass alpm refused at prepare no longer marks the run
    mid-transaction, 7.254.0 unless an earlier pass failed past it
  - signals: 7.252.0 teardown no longer autoloads a user's _progress_teardown
    or _tmp_dir during startup
  - signals: 7.254.0 a pass or removal failing mid-transaction keeps DO NOT
    REBOOT owed until the rebuild; the snapshot is no longer stranded
  - signals: 7.255.0 a signal before the seed lands no longer rewrites it; one
    after -Syu no longer reverts the seed
  - signals: 7.257.0 a pacman dying with its lock makes DO NOT REBOOT say to
    remove db.lck; 7.260.0 a lapse-skipped revert counts a WARN
  - cli: 7.247.0 the --install-file control-character refusal states why;
    7.252.0 an unexpected positional prints escaped, an empty one as ''
  - cli: 7.254.0 argument errors escape control characters, C1 and raw bytes;
    a root run escapes each leftover; --install-file errors escape the value
  - cli: 7.254.0 --install-file given a mode flag names both spellings; -h
    or -v ending in a newline exits 2; 7.264.0 --report reads got flag
  - preflight: 7.247.0 MODULES and HOOKS tokens are charset-checked; a missing
    realpath prints no fish error; a module that may not exist warns
  - preflight: 7.252.0 a HOME that normalizes to empty or a non-directory
    names the value set in its exit-3 error
  - preflight: 7.254.0 a relative HOME, 7.255.0 or one with a control
    character, takes the passwd entry; such a passwd entry exits 3
  - preflight: 7.254.0 an embedded value or RY_RUN_TIMEOUT ending in a newline
    is refused or reads invalid; the network probe skips ~/.curlrc
  - preflight: 7.254.0 the root UUID takes findmnt's first match under a
    stacked mount; the dependency gate adds bootctl, ln, readlink, uname
  - preflight: 7.254.0 a TLS failure names the clock or a TLS proxy; 7.255.0
    curl rc 77 names SSL_CERT_FILE, CURL_CA_BUNDLE and ca-certificates
  - preflight: 7.255.0 a ping without an ICMP socket leaves the raw IPs
    unprobed; uncached sudo with no TTY prints one ERR naming the TTY
  - preflight: 7.255.0 hints name the script as invoked; validation picks each
    validator by managed path, so a HOME under modprobe.d passes
  - preflight: 7.256.0 WP_BLUEZ_ROLES entries must be PipeWire role names;
    7.257.0 a failed validation names its checks
  - preflight: 7.257.1 an EXPECTED_VULKAN_PKGS member in PKGS_DEL or starting
    with a dash is refused
  - preflight: 7.258.0 an unresolvable $BOOT or a non-vfat fallback /boot
    exits 3 before -Syu; true(1) and test(1) are checked at startup
  - preflight: 7.260.0 the ESP gate refuses an ESP not at /boot or an XBOOTLDR
    $BOOT; a /boot linked to the ESP gets the free-space gate
  - preflight: 7.268.0 a ppid-scoped sudo ticket exits 3; a background sudo -n
    true every 30 s keeps the ticket alive until exit
  - preflight: 7.269.0 a verifypw that lets sudo -v skip authentication
    prompts once through a command on a TTY instead of exiting 3
  - preflight: 7.274.0 a boot-critical path that is not a managed system
    destination refuses to deploy
  - lock: 7.254.0 the lock dir is set 00700, clearing an inherited setgid bit;
    the printed removal command escapes its path
  - lock: 7.254.0 - 7.255.0 a signal while releasing no longer strands .claim
    or the lock dir; a holder releasing mid-check no longer exits 5
  - lock: 7.255.0 a lock not taken logs ERR and counts in the footer
  - backup: 7.250.0 the first .ry.bak copy creates ~/ry-install/backups, so no
    early exit removes it; 7.257.0 a failed copy WARNs on the terminal
  - backup: 7.267.0 a backup copy or post-write restore, its mktemp included,
    that sudo refused reads not run
  - services: 7.247.0 a PKGS_DEL hook error keeps the row's rdep-skip count;
    7.250.0 a root-only resolved drop-in no longer skips the restart
  - services: 7.251.0 a lapse-blocked owed resolved restart reads WARN;
    7.260.0 one sudo refused reads not run
  - services: 7.252.0 the fstab rewrite no longer refuses over a
    findmnt --verify error, 7.254.0 or a parse error, the original carries too
  - services: 7.252.0 a masked ufw.service reads firewall unverified under a
    lapsed cache; SECURITY says whether the mask follows or holds
  - services: 7.254.0 an fstab with only malformed ext4 rows WARNs; a lapsed
    mask retry FAILs (MASK_LAPSE); a mask FAIL counts units not stopped
  - services: 7.254.0 - 7.255.0 the mask and enable rows lead with their
    notes; the enable row WARNs for a unit not installed
  - services: 7.255.0 the fstab rewrite names a lapse at its mktemp or read;
    mask --now stops a masked unit still activating
  - services: 7.255.0 a refused regdom apply names the lapse; ufw masked with
    nftables down names a diagnosis; a failed batch's removals count
  - services: 7.257.0 the enable row counts only units this run enabled; a
    failed fstab scan FAILs the fstab step
  - services: 7.258.0 a MASK unit removed while running is masked and stopped;
    a PKGS_DEL member failing before its dependent is retried
  - services: 7.258.0 the PKGS_DEL row tells probe-failed from rdep skips; on
    systemd 253+ an empty is-enabled answer no longer skips a unit
  - services: 7.258.0 an enabled but stopped NetworkManager.service is
    started; findmnt --verify runs under RY_RUN_TIMEOUT
  - services: 7.260.0 a preset unit the enable batch owned is reported once; a
    start, enable or mask failing as sudo expires reads failed
  - services: 7.260.0 the enable row reads enabled, not started for a unit
    whose start failed or was refused
  - services: 7.267.0 - 7.271.0 a refused PKGS_DEL, mask or enable batch,
    fstab step, nft probe or ufw disable reads not run, naming the lapse
  - services: 7.272.0 after sudo refused the -D re-mark or the enable batch,
    no PKGS_DEL removal or preset start is tried; each reads not run
  - boot: 7.250.0 an empty entries dir adds no sdboot-manage gen or
    LINUX_OPTIONS hint; the boundary check resolves links as root
  - boot: 7.250.0 - 7.252.0 an ESP-fallback host's DO NOT REBOOT banner says
    to check the ESP and re-run, never sdboot-manage gen
  - boot: 7.252.0 the EFI refresh runs bootctl --graceful update and fails on
    its error; 7.254.0 the rebuild step prints it too
  - boot: 7.255.0 the inspect step quotes $BOOT; sanity lists entries as
    systemd-boot does and fails an unreadable one
  - boot: 7.257.0 an entry name ending in .. passes sanity; 7.258.0 an empty
    kernel or a non-regular initrd fails it
  - boot: 7.260.0 sanity reads entries as systemd-boot does, fails a linux
    entry with no initrd line, and stops at the first lapse
  - boot: 7.267.0 a refused rebuild step logs not run; 7.271.0 a sanity FAIL
    names the lapse and a refused revert reads not run (sudo)
  - finalize: 7.252.0 without PowerDevil an environment.d change skips the
    re-apply; 7.254.0 an NM_RESTART_DELAY ending in a newline reads 3 s
  - finalize: 7.255.0 the Next line points at ./ry-verify.fish in the
    ry-verify clone; the usermod manual steps quote the account name
  - finalize: 7.256.0 a changed or owed bluez5.roles drop-in try-restarts
    wireplumber.service; no user bus, no unit or exit 4 is a SKIP row
  - finalize: 7.257.0 PowerDevil and WirePlumber rows say changed or owed;
    7.260.0 a refused NM restart or cache trim reads not run
  - finalize: 7.267.0 a paccache -ruk0 that sudo refused after -rk2 ran reads
    cut short, not failed
  - install-file: 7.249.0 a boot-critical failure prints DO NOT REBOOT and its
    recovery steps once, in the closing banner
  - install-file: 7.252.0 an environment.d or bluetooth deploy without its
    unit, 7.254.0 or a cpupower one, skips the restart without a WARN
  - install-file: 7.252.0 the modprobe.d post-hook claims no module options;
    7.254.0 a hook only root can see no longer reads as invalid
  - install-file: 7.254.0 a failed or absent udevadm says udevd re-reads the
    rule on its next event; a successful apply strikes its owed entry
  - install-file: 7.254.0 an nft -c or udevadm verify that could not run or
    timed out, 7.258.0 or that sudo refused, is no verdict
  - install-file: 7.254.0 each managed file runs its own post-hook, so a HOME
    under a directory such as sysctl.d no longer reroutes a user file
  - install-file: 7.254.0 - 7.255.0 sysctl --system names a rejected key or
    says retry; a changed file prints one OK, a failed write one FAIL
  - install-file: 7.255.0 a HOME under /etc or /boot no longer reads user
    files via sudo; a boot file runs the dependency and ESP gates first
  - install-file: 7.256.0 the bluez5.roles drop-in try-restarts WirePlumber,
    owed when that fails; 7.257.0 a stopped WirePlumber claims nothing
  - install-file: 7.257.0 the nft and udevadm verify hints name the script;
    7.260.0 boot gates refuse an ESP not at /boot or an XBOOTLDR $BOOT
  - install-file: 7.260.0 an NM drop-in without NetworkManager owes no
    restart; a sysctl or udevadm verify failing as sudo expires reads failed
  - install-file: 7.267.0 a refused cascade step, daemon-reload, restart or
    udev call, 7.270.0 or sysctl, nft -c or verify, reads not run
  - logging: 7.246.0 a failed pacman call echoes its package-conflict lines;
    7.247.0 boot-cascade and udev-skip records carry the POST_ prefix
  - logging: 7.247.0 a failed date no longer breaks the header; _run clears
    its capture before an early return; an empty loud _err logs nothing
  - logging: 7.250.0 a full install logs no second rebuild command or reboot
    hint after an nft -c failure; closing lines skip a gone stderr
  - logging: 7.250.0 the preflight log is created as soon as its dir exists;
    7.251.0 new HARDWARE_MATCH and BACKUP_DIR_MKDIR_FAIL keys
  - logging: 7.251.0 PENDING_APPLY_DROPPED, and SECURITY_POSTURE with
    ufw.service's state before its mask; 7.252.0 ROOT_UUID_OK
  - logging: 7.252.0 new PENDING_APPLY_SAVED, MKINITCPIO_SNAPSHOT_OK,
    POST_REGDOM_APPLY_OK and POST_NM_RESTART_DEFERRED keys
  - logging: 7.254.0 new ENABLE_ALREADY, ENABLE_NOT_INSTALLED and
    NM_RESTART_SKIP_NO_NM keys; BACKUP_SKIP_SUDO_LAPSE logs dst= and probe=
  - logging: 7.254.0 the end-of-run summary is JSONL-only; 7.254.0 - 7.255.0
    Finalize's NM deferral logs context=finalize and each drop
  - logging: 7.255.0 one failure counts once in the footer; a skipped enable
    or blocked resolved restart counts a WARN
  - logging: 7.255.0 new PKG_ASEXPLICIT_SKIP, HARDWARE_*_REFUSED and
    ROOT_UUID_UNAVAILABLE keys; a lapse-skipped signal-time revert is logged
  - logging: 7.257.0 a failed restart, daemon-reload, cache trim or indexer
    run logs a _FAIL key; a non-UTF-8 byte logs as U+FFFD
  - logging: 7.258.0 the network check logs its curl rc, df its raw value; new
    MASK_FAIL, ENABLE_FAIL, MASK_BATCH_FAIL, ENABLE_BATCH_FAIL keys
  - logging: 7.258.0 new SKIP_PROBE_SUDO_LAPSE, MODE_DRIFT_UNPROBED,
    POSTWRITE_RESTORE_STALE and NFT_PRE_ENABLE_UNMANAGED keys
  - logging: 7.258.0 revert, snapshot and fstab steps log their error;
    PACTREE_PROBE_FAIL its rc; POSTWRITE_VERIFY_FAIL a reason, digests, sizes
  - logging: 7.260.0 RY_RUN_TIMEOUT warnings count; new ESP_LAYOUT_REFUSED,
    ESP_LAYOUT_LAPSE, STATE_DIR_PERM_FIX and POSTWRITE_VERIFY_SKIP keys
  - logging: 7.260.0 refused steps log PRESET_START_LAPSE, NM_RESTART_LAPSE,
    RESOLVED_RESTART_LAPSE, PACMAN_CACHE_TRIM_LAPSE, POST_*_LAPSE
  - logging: 7.260.0 a post-footer revert logs nothing; 7.265.0 every run logs
    KERNEL_RELEASE; 7.267.0 - 7.270.0 refused steps log _LAPSE
  - logging: 7.271.0 TMPFILE_STUCK tells a lapsed sudo cache from a missing
    sudo; 7.274.0 POSTWRITE_VERIFY_FAIL logs ERR for a missing digest
  - progress: 7.254.0 a signal while the bar pins or unpins no longer leaves
    the scroll region set or clears the top row
  - summary: 7.247.0 failed summary or banner writes log STDERR_WRITE_FAIL;
    7.257.0 a -Syu that changed packages adds a manual step to review the news
  - summary: 7.258.0 a failed mkinitcpio, sdboot-manage gen or bootctl update
    row gives its rc or never ran; 7.260.0 refused ones read not run
  - consistency: 7.260.0 an nft -c _run cannot start reads no capture dir;
    7.264.0 messages read user bus, re-deploy and pidfile
  - consistency: 7.265.0 --help and the README name the 7200 s floor; 7.273.0
    messages drop sentence periods, read Bootloader and at next boot
  - consistency: 7.274.0 --help groups its sections; refusals read refusing
    to; the NM post-hook reads deployed; output spells out abbreviations


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
    after -Syu; pacman -Si and -Qi are read with COLUMNS=0
  - packages: 7.243.0 a locked pacman db reverts the seeded mkinitcpio.conf;
    7.245.0 the held WARN names the rollback; -Syyu re-reads holds
  - guard: 7.243.0 TMPDIR is pinned to /tmp; an early exit deletes no
    inherited LOG_FILE, LOG_DIR or _RY_BACKUP_DIR
  - guard: 7.245.0 an early exit removes ~/ry-install only if this run made it
  - signals: 7.243.0 a signal during the boot rebuild prints DO NOT REBOOT;
    7.245.0 the mv -T probe strands no temp files; no PIPE handler
  - cli: 7.241.0 help aligns ENVIRONMENT; 7.243.0 argument errors write no
    /tmp file, and a 4096-byte --install-file path exceeds PATH_MAX
  - cli: 7.245.0 an over-long RY_RUN_TIMEOUT warns that 2147483647 is used
  - preflight: 7.243.0 a sudo -v caching nothing (timestamp_timeout=0),
    7.245.0 or leaving sudo -n unusable, exits 3
  - preflight: 7.243.0 an absent findmnt is named; the dual-stack WARN names
    both generators; 7.245.0 missing optional tools warn
  - lock: 7.245.0 lock hints quote the path and pass --preserve-root; a
    kill-less host takes the /proc lock branch silently
  - backup: 7.243.0 a directory at the .ry.bak path is never written into
  - services: 7.235.0 PKGS_DEL removal is held after an earlier package or
    boot-file failure; a hook or scriptlet error reads WARN
  - services: 7.240.0 a mask or enable FAIL names the failing units; the fstab
    rewrite drops nolazytime like *atime
  - services: 7.241.0 a per-unit mask retry row keeps the ufw.service withheld
    note
  - services: 7.242.0 pacman transactions run with LC_ALL=C.UTF-8, so a
    PKGS_DEL hook error reads WARN in any locale
  - services: 7.243.0 several commit= become one commit=10; a row with fewer
    than 4 fields stays untouched (row WARN)
  - services: 7.243.0 ufw masked and nftables down: a loud SECURITY warning
    names the fix; enable FAILs name units that failed to start
  - services: 7.243.0 a failed findmnt --verify is logged in full, 7.245.0 [E]
    lines first; a mask failure logs an error
  - services: 7.245.0 a masked unit still running is masked with --now; a
    resolved restart owed by an interrupted run stays owed
  - boot: 7.235.0 a refused rebuild prints no manual mkinitcpio -P steps;
    7.243.0 ESP refusals drop the manual rebuild step
  - boot: 7.243.0 sanity checks each linux entry's kernel and initrd lines,
    skips efi entries, and names a missing entries dir
  - boot: 7.245.0 a symlinked loader/entries dir is listed; a signal during
    the read-only checks prints no interrupted-rebuild banner
  - finalize: 7.243.0 an NM restart deferred over Wi-Fi stays owed; the
    PowerDevil re-apply uses try-restart
  - finalize: 7.245.0 a pending-apply marker from an earlier boot is dropped
  - install-file: 7.241.0 an nft -c timeout reads as a timeout; 7.243.0 nft -c
    and udevadm verify failures say how the file applies
  - install-file: 7.243.0 the DO NOT REBOOT banner cites exit 4 and says to
    re-run the same --install-file; environment.d uses try-restart
  - install-file: 7.245.0 mkinitcpio.conf and sdboot-manage.conf run the
    disk-space gate first (exit 3); a failed nftables reload names the retry
  - logging: 7.235.0 a failed command echoes its error lines; pending-apply is
    rewritten only when the owed set changes
  - logging: 7.240.0 a failed pacman echo keeps 'exists in filesystem' lines,
    7.242.0 and its error lines in any locale
  - logging: 7.243.0 a JSONL string keeps a trailing newline; a run whose
    stderr write fails stops writing to the terminal
  - logging: 7.243.0 _run reads 124 or 137 as a timeout only after the cap;
    removed log symlinks and failed reverts are logged
  - logging: 7.245.0 STDERR_WRITE_FAIL logs once; tmpfile and child-reap
    records precede the footer, which a signal no longer stops
  - logging: 7.245.0 a log rename falling back to cp is logged; _run times on
    the monotonic clock; TIMEOUT_LONGOP_CAP is TIMEOUT_LONGOP_FLOOR
  - progress: 7.243.0 a resize re-pins the bar; an aborted run counts 6
    phases; 7.245.0 the bar unpins before its last writes
  - summary: 7.243.0 the result matrix rule matches the full row width
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
  - cli: 7.234.0 -h and -v exit 1 on a full stdout (closed too, under fish
    3); --install-file --report says its value is missing
  - preflight: 7.219.0 MODULES are checked against each installed kernel;
    7.224.0 a locked pacman database stops the run before any deploy
  - preflight: 7.225.0 the modprobe.d check names directives in match order
  - preflight: 7.233.0 the /boot space gate and ESP checks read the topmost
    non-autofs mount; a setgid $HOME or symlinked ~/ry-install passes
  - preflight: 7.234.0 the override hint keeps --install-file; iommu=off
    counts as no IOMMU; failed timedatectl and absent ping are named
  - preflight: 7.234.0 RY_RUN_TIMEOUT and low-disk warnings print in install
    mode, leading zeros carry no magnitude; HOOKS need a build script
  - lock: 7.233.0 only the holder sweeps destination dirs, so a peer refused
    with exit 5 deletes none of its tmpfiles
  - lock: 7.233.0 stale-lock reclaim takes an exclusive claim and renames the
    stale dir aside; release checks the pidfile is this run's
  - lock: 7.233.0 a pidfile from an earlier boot or a reused PID is reclaimed,
    an unreadable identity fails closed; no empty .lock is left
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
  - install-file: 7.233.0 with nft(8) absent the nftables post-hook says so
  - cleanup: 7.233.0 root-only /run/ry-install tmpfiles are removed via sudo
  - logging: 7.234.0 a signal before the header leaves no footer-only JSONL;
    child SIGKILL, absent modinfo and a skipped snapshot are logged
  - progress: 7.234.0 the bar reads the terminal size from the stderr tty
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
