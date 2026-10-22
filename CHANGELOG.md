Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.255.0
-------

  - signals: a pacman pass alpm refused at prepare keeps the run marked when
    an earlier pass failed past prepare
  - signals: a pacman pass that passes after one failed mid-transaction keeps
    DO NOT REBOOT owed until Boot's rebuild; the -Syu row WARNs
  - signals: a pacman run that never ran or stopped before its hooks no longer
    reads as cut short mid-transaction
  - signals: a PKGS_DEL removal that fails mid-transaction keeps DO NOT
    REBOOT owed until Boot's rebuild
  - signals: a signal just after the mkinitcpio.conf snapshot is made no
    longer strands it; one just after its removal prints no restore command
  - signals: a signal before the mkinitcpio.conf seed lands no longer rewrites
    the unchanged file or prints a restore WARN
  - signals: a signal after -Syu passes no longer reverts the mkinitcpio.conf
    seed the initramfs was built from
  - cli: a root run escapes each leftover argument whole, so an embedded
    newline no longer splits or forges the message
  - cli: argument errors print control characters escaped or as ?, C1 and
    raw bytes included; an --install-file value holding one is refused first
  - cli: --install-file given --verify, --check, --report, --help or
    --version as its value names both spellings
  - cli: every --install-file error escapes the value, so a trailing blank
    no longer reads as the managed path
  - cli: an --install-file path of 4095 slashes no longer stalls the NAME_MAX
    check for seconds
  - cli: -h or -v ending in a newline is an unknown option (exit 2), not help
  - preflight: an embedded value ending in a newline (governor, country,
    count, kernel or HOOKS token) is refused
  - preflight: a relative HOME takes the passwd entry, and a relative passwd
    entry exits 3, instead of resolving under the current directory
  - preflight: a HOME holding a control character takes the passwd entry; one
    there exits 3, so a newline or escape never reaches printed lines
  - preflight: the root UUID takes findmnt's first match, so a mount stacked
    on / no longer fails the run as an invalid UUID
  - preflight: an RY_RUN_TIMEOUT ending in a newline reads invalid, not a fish
    error at every command; its WARN prints the value escaped
  - preflight: the network probe skips ~/.curlrc, so a write-out it sets no
    longer reaches stdout
  - preflight: a TLS handshake or certificate failure names the clock or a
    TLS proxy, not DNS or blocked egress
  - preflight: an unreadable CA store (curl rc 77) names SSL_CERT_FILE,
    CURL_CA_BUNDLE and ca-certificates, not the clock or a TLS proxy
  - preflight: a ping that cannot open an ICMP socket leaves the raw IPs
    unprobed instead of reporting them unreachable
  - preflight: sudo uncached with no TTY prints one ERR that names the TTY
  - preflight: the hardware override hint and the nftables manual step name
    the script as invoked, not ./ry-install.fish
  - preflight: config validation picks each validator by managed path, so a
    HOME under a dir such as modprobe.d no longer fails it
  - preflight: the dependency gate also requires bootctl, ln, readlink and
    uname, so a host without bootctl stops before any change
  - lock: the printed lock-removal command escapes its path, so a quote in
    HOME no longer breaks or splits it
  - lock: a signal while dropping a reclaim claim or releasing the lock no
    longer strands .claim or an empty lock directory
  - lock: a lock that cannot be taken logs ERR and counts in the footer
  - lock: the lock directory is set 00700, clearing an inherited setgid bit
  - lock: a holder releasing the lock mid-check, or between this run's mkdir
    and its check, no longer makes the run exit 5
  - progress: a signal while the bar pins or unpins no longer leaves the
    scroll region set or clears the top row
  - packages: error lines kept from a long pacman output's elided middle stay
    in file order, print with QUIET off, log under _OVERFLOW_KEPT
  - packages: a re-run whose mkinitcpio.conf seed changed nothing drops its
    rollback, so a failed -Syu no longer reverts and holds the file
  - packages: a failed mkinitcpio.conf seed reverts any bytes it landed from
    the snapshot before dropping it
  - packages: a conflict-swap hook error leads its row, so a long removal
    list no longer cuts it from the matrix
  - packages: a -Syyu retry, conflict swap, explicit mark, updatedb or pkgfile
    that sudo refused reads as not run (sudo cache lapsed), not failed
  - configuration: an nft -c that could not run refuses the deploy as not run,
    not as a failed ruleset
  - configuration: an owed restart is on file before its config lands, so a
    signal right after the move no longer drops it
  - configuration: a config that fails to land is no longer left owed, so a
    later run does not restart its service as if it changed
  - configuration: an unchanged system file not owned by root:root is
    chowned back, as a drifted mode is restored
  - services: the fstab rewrite no longer refuses over a parse error the
    original carries, in any locale; a refusal names its new entries first
  - services: an fstab with only malformed ext4 rows WARNs that none is
    well-formed, not that all are conformant
  - services: a mask retry under a lapsed sudo cache FAILs naming the lapse
    (MASK_LAPSE), not a WARN that the stop failed
  - services: a mask FAIL row also counts units that masked but did not stop
  - services: the mask and enable rows put their notes before unit lists, so
    the matrix cell no longer cuts them off
  - services: the enable row no longer counts nftables.service as already
    enabled when the nftables-first step enabled it this run
  - services: the enable row WARNs naming any unit that is not installed, as
    ry-verify does, instead of PASS or a failed enable
  - services: the fstab rewrite names a lapsed sudo cache when its mktemp or
    read fails, not fstab perms
  - services: a masked unit still activating is stopped by mask --now, not
    read as already masked
  - services: a regdom apply that sudo refused names the lapsed cache, not a
    failed iw reg set
  - services: with ufw masked and nftables down, the SECURITY line names a
    diagnosis, not the enable that just failed
  - services: a PKGS_DEL package that a failed batch removal took counts as
    removed
  - boot: the DO NOT REBOOT rebuild step prints bootctl --graceful update, not
    sdboot-manage update
  - boot: the DO NOT REBOOT inspect step quotes $BOOT, so a mount path with a
    space prints a working command
  - boot: the sanity check lists loader entries as systemd-boot does, hidden
    files skipped and .conf matched in any case
  - boot: the sanity check fails a loader entry it cannot read instead of
    skipping it as an efi entry
  - finalize: an NM_RESTART_DELAY ending in a newline falls back to 3 s
    instead of failing the settle sleep
  - finalize: the matrix Next line points at ./ry-verify.fish in the
    ry-verify clone, not beside this script
  - finalize: the usermod manual steps quote the account name, so one ending
    in $ prints a command fish can run
  - install-file: a cpupower deploy without cpupower.service skips the
    restart instead of claiming the governor applied
  - install-file: the boot-file gates run after sudo is cached, so a hook
    only root can see no longer reads as invalid
  - install-file: an absent udevadm, or a failed verify or reload, says udevd
    re-reads the changed rule on its next event, not at next boot
  - install-file: a post-write nft -c or udevadm verify that could not run,
    or a udevadm verify that timed out, reads as no verdict, not a failure
  - install-file: a resolved, NetworkManager or environment.d apply that
    succeeds strikes its owed entry, so a later run does not repeat it
  - install-file: each managed file runs its own post-hook, so a HOME under a
    directory such as sysctl.d no longer reroutes a user file
  - install-file: a HOME under /etc or /boot no longer reads the user files
    via sudo, so a lapsed cache no longer redeploys them
  - install-file: a sysctl --system that rejected a key says the rest are
    live, fix the key; one that did not run or finish says retry or reboot
  - install-file: a changed file prints one OK and a failed write one FAIL,
    not two; the nm-dispatcher apply confirms with an OK like the others
  - install-file: a boot file runs the dependency and ESP gates before the
    write, so a missing bootctl or unmounted ESP exits 3 instead of 4 after it
  - logging: Finalize's NM deferral logs PENDING_APPLY_DROPPED for entries it
    drops and leaves an NM-only owed list as filed
  - logging: enable skips log ENABLE_ALREADY and ENABLE_NOT_INSTALLED; an
    absent NetworkManager logs NM_RESTART_SKIP_NO_NM
  - logging: an explicit mark that finds no PKGS_ADD package logs
    PKG_ASEXPLICIT_SKIP
  - logging: BACKUP_SKIP_SUDO_LAPSE logs dst= and probe= at both sites;
    Finalize's NM restart deferral and failure log context=finalize
  - logging: the end-of-run summary is JSONL-only, so the footer no longer
    counts Done! as a pass or the error recap as a fail and a warn
  - logging: one failure counts once in the footer, however many ERR, FAIL or
    WARN lines explain, restate or retry it
  - logging: a skipped enable and an owed resolved restart that cannot run
    count a WARN, as their rows do
  - logging: hardware and root UUID refusals log HARDWARE_*_REFUSED and
    ROOT_UUID_UNAVAILABLE
  - logging: a signal-time mkinitcpio.conf revert skipped under a lapsed sudo
    cache logs that cause
  - readme: exit 3 names the systemd gate; the mask step says the next full
    run stops a unit that masked but did not stop; enable WARNs an absent unit
  - readme: pending-apply also records a failed --install-file resolved or
    NetworkManager restart or PowerDevil re-apply
  - readme: Troubleshooting and Uninstall rebuild with bootctl --graceful
    update; Tools lists bootctl
  - readme: only a run that reaches Preflight closes with Totals; Backups says
    each rewrite replaces the previous .ry.bak
  - readme: only a run past argument parsing writes a JSONL log; an
    --install-file of a user file needs no sudo
  - readme: --install-file of a boot config gates before the write (exit 3)


7.246.0 - 7.252.0
-----------------

  - env: 7.248.0 add 0x3434/0x0b00 (Keychron Q0 HE) to
    SDL_GAMECONTROLLER_IGNORE_DEVICES
  - configuration: 7.247.0 a post-write mismatch with only an older run's
    .ry.bak says no backup from this run
  - configuration: 7.248.0 udev has libinput ignore the Xbox Wireless
    Controller
  - configuration: 7.250.0 a managed symlink behind a directory this user
    cannot traverse is replaced; its target is never chmodded
  - configuration: 7.251.0 the 60-ry-modules.conf header no longer claims
    module options; an existing install redeploys it once
  - configuration: 7.252.0 a sudo cache lapse before an atomic move FAILs the
    file rather than printing an [ERR] line
  - guard: 7.247.0 an early exit removes ~/ry-install/backups only when this
    run created it
  - guard: 7.247.0 inherited mkinitcpio rollback variables are pinned, so they
    can never drive a revert
  - guard: 7.250.0 state inherited from the environment or config.fish is
    erased at startup; LOCK_DIR and LOCK_FILE values are ignored
  - guard: 7.250.0 a fish universal named like internal state (the error names
    its set -eU) or regex-easyesc turned off exits 3
  - guard: 7.250.0 a fish universal named like the mkinitcpio snapshot, the
    tmpfile list or the boot-path or systemd-version cache is never read
  - guard: 7.250.0 an early exit or a signal before the JSONL header removes
    only the empty log and ~/ry-install dirs this run created
  - guard: 7.250.0 an early exit no longer runs a user's fish function named
    _do_cleanup; 7.251.0 nor one named _dc_settle or _write_footer
  - guard: 7.250.0 a config.fish job-control or IFS setting no longer steers a
    run (output read as one line)
  - guard: 7.250.0 a fish universal named _early_ch is no longer erased; the
    root check ignores a universal _flag_install_file
  - guard: 7.251.0 an invalid root UUID never lets a fish universal of that
    name reach the kernel cmdline
  - signals: 7.250.0 a signal in any later phase after a package,
    boot-critical file or mkinitcpio revert failure prints DO NOT REBOOT
  - signals: 7.250.0 a signal between a boot-critical failure and the end of
    its banner prints DO NOT REBOOT worded for the interrupted run
  - signals: 7.250.0 an interrupted banner for a refused rebuild points at the
    JSONL log, not the summary matrix or an [ERR] line
  - signals: 7.250.0 a second signal while a startup signal is handled no
    longer exits 0 or 1, skipping the notice and dir cleanup
  - signals: 7.250.0 a signal in an early exit's final step keeps its exit
    code; one during a signal teardown no longer turns 128+N into 0
  - signals: 7.251.0 a signal during a pacman transaction (-Syu, its retry or
    the conflict swap) prints the DO NOT REBOOT banner
  - signals: 7.251.0 a signal during a package failure's [ERR] lines or
    mkinitcpio.conf revert prints the banner
  - signals: 7.251.0 a signal during an early exit, before the main handler
    takes over, keeps the exit code instead of 128+N
  - signals: 7.252.0 a signal during a PKGS_DEL removal prints the DO NOT
    REBOOT banner, as one during -Syu does
  - signals: 7.252.0 a signal during a failed boot-file check's [FAIL] lines
    or restore prints the banner
  - signals: 7.252.0 a pacman pass alpm refused at prepare no longer leaves
    the run marked mid-transaction
  - signals: 7.252.0 teardown no longer autoloads a user function named
    _progress_teardown or _tmp_dir during startup
  - cli: 7.247.0 the --install-file control-character refusal states its real
    reason
  - cli: 7.252.0 an unexpected positional argument prints escaped; an empty
    one reads ''
  - preflight: 7.247.0 MKINITCPIO_MODULES and MKINITCPIO_HOOKS tokens are
    charset-checked
  - preflight: 7.247.0 a missing realpath no longer prints fish errors; a
    module that may not exist warns on the console
  - preflight: 7.252.0 a HOME that normalizes to empty or a non-directory
    names the value set in its exit-3 error
  - packages: 7.246.0 a missing member whose dependency conflicts with an
    installed package is held for the swap, not left to fail both passes
  - packages: 7.246.0 a conflict swap gets a summary row naming what it
    removed; an rc-0 -Syu or swap whose hooks log errors reads WARN
  - packages: 7.247.0 each -Syu pass that stops on a dependency conflict holds
    the missing member that pulls it and runs again
  - packages: 7.247.0 the -Syu re-pass and -Syyu retry notices print on the
    console beside the failed pass's pacman errors
  - packages: 7.250.0 a HOOKS build script behind a 0700 /etc/initcpio/install
    no longer reads as missing after -Syu (a false exit 4)
  - packages: 7.251.0 a failed pacman -Q no longer reads as an unchanged
    package set; the run counts it as an upgrade
  - packages: 7.251.0 a PKGS_DEL member an earlier member's -Rns took is
    logged as removed, not retried as a failing removal
  - packages: 7.251.0 HOOKS build scripts are probed as this user first, with
    sudo only for one this user cannot see
  - packages: 7.252.0 a hook error past the 500-line output capture still
    reads WARN
  - backup: 7.250.0 ~/ry-install/backups is created by the first .ry.bak copy,
    so no run's early exit removes it
  - services: 7.247.0 a PKGS_DEL row with a pacman hook error keeps its
    rdep-skip count
  - services: 7.250.0 a resolved drop-in behind a directory this user cannot
    traverse no longer skips the restart as absent
  - services: 7.250.0 the systemd-resolved restart row says the drop-in is
    unreadable, not absent, when a lapsed sudo hides it
  - services: 7.251.0 an owed systemd-resolved restart that a lapsed sudo
    cache blocks reads WARN (applies next boot), not SKIP
  - services: 7.252.0 the fstab rewrite no longer refuses over a findmnt
    --verify error the original carries (an unplugged nofail device)
  - services: 7.252.0 under a lapsed sudo cache a masked ufw.service reads
    firewall unverified, not down; enable and mask retries name the lapse
  - services: 7.252.0 nftables-first no longer claims ufw rules stay before
    the ufw step decides; SECURITY says whether the mask follows or holds
  - boot: 7.250.0 an empty loader entries directory no longer adds
    sdboot-manage gen or LINUX_OPTIONS hints before the banner
  - boot: 7.250.0 - 7.252.0 an ESP-fallback host's DO NOT REBOOT banner says
    to check the ESP and re-run, even mid-pacman, never sdboot-manage gen
  - boot: 7.250.0 the loader-entry boundary check resolves symlinks as root,
    catching an entry that escapes a 0700 $BOOT through a link
  - boot: 7.252.0 the EFI binary refresh runs bootctl --graceful update, whose
    failure fails the step (sdboot-manage update always exits 0)
  - finalize: 7.252.0 with no plasma-powerdevil.service, an environment.d
    change skips the re-apply instead of WARNing a failed restart
  - install-file: 7.249.0 a boot-critical failure prints DO NOT REBOOT and its
    recovery steps once, in the closing banner
  - install-file: 7.252.0 an environment.d or bluetooth deploy without the
    unit to restart no longer WARNs a failed restart
  - install-file: 7.252.0 the modprobe.d post-hook no longer claims module
    options, matching the 60-ry-modules.conf header
  - logging: 7.246.0 a failed pacman call echoes its package-conflict lines
  - logging: 7.247.0 boot-cascade and udev-skip records carry the POST_
    prefix; a failed date no longer breaks the header JSON
  - logging: 7.247.0 _run clears its capture before an early return; the
    bail-out record precedes INSTALLATION END
  - logging: 7.247.0 an empty loud _err logs nothing
  - logging: 7.250.0 a full-install boot-critical failure no longer logs a
    second copy of the rebuild command ahead of the banner
  - logging: 7.250.0 closing log-file lines are skipped once stderr is gone
  - logging: 7.250.0 the preflight log is created as soon as its dir exists,
    so a concurrent run's early exit cannot remove that dir
  - logging: 7.250.0 a full install no longer logs the per-file reboot hint
    after an nft -c failure on a kernel upgraded since boot
  - logging: 7.251.0 the hardware gate logs HARDWARE_MATCH, a failed backups
    mkdir BACKUP_DIR_MKDIR_FAIL and a struck entry PENDING_APPLY_DROPPED
  - logging: 7.251.0 SECURITY_POSTURE records ufw.service's state before its
    mask, not a mask that has not run
  - logging: 7.252.0 the root UUID gate logs ROOT_UUID_OK
  - logging: 7.252.0 Finalize logs PENDING_APPLY_SAVED and
    PENDING_APPLY_DROPPED, and the NM post-hook PENDING_APPLY_SAVED
  - logging: 7.252.0 the mkinitcpio.conf snapshot logs MKINITCPIO_SNAPSHOT_OK;
    its skip and fail keys carry the SNAPSHOT name too
  - logging: 7.252.0 the regdom post-hook logs POST_REGDOM_APPLY_OK, not a
    start key; the NM post-hook defers under POST_NM_RESTART_DEFERRED
  - summary: 7.247.0 a failed write of the run summary or the sudo banner logs
    STDERR_WRITE_FAIL


7.235.0 - 7.245.0
-----------------

  - guard: 7.243.0 TMPDIR is pinned to /tmp
  - guard: 7.243.0 an inherited LOG_FILE, LOG_DIR or _RY_BACKUP_DIR is not
    deleted when the run exits before creating its own log
  - guard: 7.245.0 an early exit removes ~/ry-install only when this run
    created it
  - lock: 7.245.0 lock hints quote the path and pass --preserve-root; a
    kill-less host takes the /proc lock branch silently
  - cli: 7.241.0 help aligns its ENVIRONMENT column
  - cli: 7.243.0 an argument error writes no /tmp file; a 4096-byte
    --install-file path fails as over PATH_MAX
  - cli: 7.245.0 an over-long RY_RUN_TIMEOUT warns that 2147483647 is used,
    not that it is clamped
  - signals: 7.243.0 a signal during the boot rebuild prints the DO NOT REBOOT
    recovery banner before exiting 128+N
  - signals: 7.245.0 a signal during the startup mv -T probe no longer leaves
    its two temp files in /tmp
  - signals: 7.245.0 drop the PIPE handler; it silenced a live terminal
  - preflight: 7.243.0 a sudo -v that caches nothing (timestamp_timeout=0)
    exits 3 instead of failing every later sudo step
  - preflight: 7.243.0 the sudo banner drops the NOPASSWD drop-in; an absent
    findmnt is named as the root-UUID failure
  - preflight: 7.243.0 the dual-stack warning says to edit the nftables
    generator in both scripts
  - preflight: 7.245.0 a sudo -n -v that passes yet leaves sudo -n unusable
    exits 3; the sudo banner suggests a keepalive in this terminal
  - preflight: 7.245.0 missing optional tools and an absent modinfo warn on
    stderr; the validation error counts failed checks
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
  - packages: 7.243.0 a pacman database lock at the package step reverts the
    seeded mkinitcpio.conf
  - packages: 7.245.0 the -Syyu retry re-reads conflict holds from the sync db
    the first pass refreshed
  - packages: 7.245.0 the held mkinitcpio.conf warning says the seed was
    rolled back, not -Syu
  - configuration: 7.240.0 an nft -c timeout reads as a timeout, not as a
    failed ruleset; 7.245.0 exit 124 or 137 reads timed out or killed
  - configuration: 7.243.0 an nft -c a lapsed sudo cannot run refuses the
    deploy as a sudo lapse, not an invalid ruleset
  - configuration: 7.243.0 a sudo-lapse directory create failure says so; a
    mode drift chmod cannot repair warns on stderr
  - backup: 7.243.0 a directory at the .ry.bak path is never written into
  - services: 7.235.0 PKGS_DEL removal is held after an earlier package or
    boot-file failure; a hook or scriptlet error reads WARN
  - services: 7.240.0 a mask or enable FAIL row names the failing units;
    7.241.0 a per-unit mask retry row keeps the ufw.service withheld note
  - services: 7.240.0 the fstab rewrite drops nolazytime like *atime; a row
    carrying it no longer reads as conformant
  - services: 7.242.0 every pacman transaction runs with LC_ALL=C.UTF-8; a
    PKGS_DEL removal whose hook logged an error reads WARN in any locale
  - services: 7.243.0 an ext4 fstab row with more than one commit= is
    rewritten to a single commit=10
  - services: 7.243.0 an fstab row naming ext4 with fewer than 4 fields is
    left untouched and turns the fstab row WARN
  - services: 7.243.0 a findmnt --verify failure logs its full output along
    with its [E] and [W] lines
  - services: 7.243.0 with ufw.service masked and nftables down, a loud
    SECURITY warning names the fix; the mask row says no firewall
  - services: 7.243.0 an enable FAIL row names the units that failed to start;
    a pacman -Qq failure is a local database read error
  - services: 7.245.0 a masked unit still running is masked again with --now;
    an enable FAIL row counts the units that failed to start
  - services: 7.245.0 a systemd-resolved restart owed by an interrupted run
    stays owed in pending-apply until it runs
  - services: 7.245.0 a mask failure logs an error; a failed findmnt --verify
    lists its [E] lines first
  - boot: 7.235.0 a refused rebuild no longer prints manual mkinitcpio -P
    steps; the banner says to resolve the earlier FAIL and re-run
  - boot: 7.243.0 post-rebuild sanity checks each linux entry's kernel and
    initrd lines, skips efi entries, names a missing entries dir
  - boot: 7.243.0 the ESP-not-vfat and unresolved-$BOOT refusals drop the
    manual rebuild step
  - boot: 7.243.0 the ESP-not-vfat refusal no longer claims a non-systemd-boot
    bootloader; it says to mount the ESP and re-run
  - boot: 7.245.0 a symlinked loader/entries directory is listed; entry checks
    name a rejected path and a missing directory
  - boot: 7.245.0 a signal during the read-only post-rebuild checks no longer
    prints the interrupted-rebuild banner
  - finalize: 7.243.0 an NM restart deferred over Wi-Fi stays owed in
    pending-apply until a run off Wi-Fi or a reboot applies it
  - finalize: 7.243.0 the PowerDevil re-apply uses try-restart and never
    starts the unit outside a session
  - finalize: 7.245.0 a pending-apply marker from another boot is deleted when
    first read
  - install-file: 7.241.0 an nft -c timeout in the nftables post-hook reads as
    a timeout, not as a failed ruleset
  - install-file: 7.243.0 the nft -c and udevadm verify post-hook failures say
    how the deployed file applies and what to re-run
  - install-file: 7.243.0 the DO NOT REBOOT banner cites exit 4 and a
    refusal's [ERR] lines, and says to re-run the same --install-file
  - install-file: 7.243.0 an environment.d deploy uses try-restart for
    PowerDevil; an NM restart deferred over Wi-Fi stays owed
  - install-file: 7.245.0 mkinitcpio.conf and sdboot-manage.conf run the
    preflight disk-space gate first and exit 3 when it fails
  - install-file: 7.245.0 a failed nftables reload names the retry command; an
    environment.d deploy says try-restarted
  - logging: 7.235.0 a failed command echoes its error lines instead of its
    first five; pending-apply is rewritten only when the owed set changes
  - logging: 7.240.0 a failed pacman echo keeps 'exists in filesystem' lines;
    7.242.0 its error lines in any locale
  - logging: 7.243.0 a JSONL string ending in a newline keeps it; a run whose
    stderr write fails stops writing to the terminal
  - logging: 7.243.0 _run reads 124 or 137 as a timeout only once the cap has
    elapsed; a removed log symlink is logged
  - logging: 7.243.0 an unresolved --install-file path is logged; no
    TMPFILE_STUCK line follows the footer
  - logging: 7.243.0 a failed signal-time revert prints the restore command
    for the mkinitcpio.conf snapshot it left
  - logging: 7.245.0 a failed stderr write logs STDERR_WRITE_FAIL once
  - logging: 7.245.0 tmpfile and child-reap records precede the footer; a
    signal while the footer is built still writes it
  - logging: 7.245.0 a log rename that falls back to cp, or fails, is logged;
    the log-write warning allows a removed JSONL
  - logging: 7.245.0 _run times commands on the monotonic clock;
    TIMEOUT_LONGOP_CAP is renamed TIMEOUT_LONGOP_FLOOR
  - progress: 7.243.0 a terminal resize re-pins the bar on the new bottom row;
    an aborted run still counts 6 phases
  - progress: 7.245.0 the bar unpins before its last writes, so a resize then
    cannot re-pin it
  - summary: 7.243.0 the result matrix rule matches the full row width
  - consistency: 7.242.0 error text reads 'unparsable', not 'unparseable'


7.217.0 - 7.234.0
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
  - configuration: 7.233.0 an nft -c failure after an upgrade removed the
    running kernel's modules is named; the next step is reboot, then re-run
  - configuration: 7.233.0 a managed file with bytes after a NUL is rewritten
    instead of reported unchanged
  - packages: 7.224.0 add pipewire-jack
  - packages: 7.233.0 after a failed -Syu, a reverted mkinitcpio.conf stays in
    place through Configuration (WARN 'mkinitcpio.conf held')
  - packages: 7.233.0 PKGS_ADD is re-marked explicit whatever the -Syu result;
    -Rns runs only after a successful mark, retried if it failed; else -Rn
  - packages: 7.234.0 a failed pactree probe is reported as held, not as
    nothing installed
  - packages: 7.234.0 a PKGS_DEL member removed by another's -s cascade is not
    reported failed
  - guard: 7.234.0 a sourced or piped run is refused under any locale
  - signals: 7.234.0 a SIGINT during startup exits 130 instead of 0, and every
    startup signal prints a notice; the handler no longer registers QUIT
  - cli: 7.218.0 a repeated --install-file exits 2; an unmanaged one exits 2
    before the hardware gate
  - cli: 7.233.0 --h, --he, --hel and --v through --versio are honored before
    the root guard
  - cli: 7.234.0 -h and -v exit 1 on a full stdout (closed too, under fish 3);
    --install-file --report says its value is missing
  - preflight: 7.219.0 MODULES are checked against each installed kernel;
    7.224.0 a locked pacman database stops the run before anything is deployed
  - preflight: 7.225.0 the modprobe.d format check names directives in match
    order
  - preflight: 7.233.0 the /boot free-space gate runs on stacked mounts; ESP
    autodetect and the vfat gate read the topmost non-autofs mount
  - preflight: 7.233.0 a setgid $HOME or a symlinked ~/ry-install no longer
    fails the log-dir mode check
  - preflight: 7.233.0 the sudo credential check keeps sudo's error text in
    memory instead of a /tmp file
  - preflight: 7.234.0 the hardware override hint keeps --install-file;
    iommu=off counts as no IOMMU for amdxdna
  - preflight: 7.234.0 a failed timedatectl query and an absent ping are
    named; low-disk and RY_RUN_TIMEOUT warnings print in install mode
  - preflight: 7.234.0 leading zeros in RY_RUN_TIMEOUT carry no magnitude
  - preflight: 7.234.0 a HOOKS entry needs a build script in an initcpio
    install dir; a hooks/ script alone no longer passes
  - lock: 7.233.0 only the lock holder sweeps destination dirs; a peer refused
    with exit 5 no longer deletes the holder's in-flight tmpfiles
  - lock: 7.233.0 stale-lock reclaim takes an exclusive claim and moves the
    stale dir aside in one rename
  - lock: 7.233.0 release checks the pidfile still carries this run's record
  - lock: 7.233.0 a pidfile from an earlier boot or a reused PID is reclaimed
    instead of exiting 5; an unreadable identity fails closed
  - lock: 7.233.0 a signal between the lock mkdir and the pidfile write no
    longer leaves an empty .lock behind
  - backup: 7.231.0 a sudo lapse at the existence probe is warned and logged
    instead of silently skipping the copy
  - backup: 7.234.0 the post-write restore uses only the .ry.bak this run
    took; the copy never writes through a symlink at the backup path
  - services: 7.218.0 enable-units counts only units it enabled or started;
    7.219.0 a oneshot nftables.service no longer reads as newly enabled
  - services: 7.233.0 a unit that enables but fails to start reads WARN on the
    enable row, naming the unit, and the warning prints during the run
  - services: 7.233.0 the live nftables policy-drop probe before the ufw flush
    matches only the input hook line
  - services: 7.234.0 a unit that masks but fails to stop is a WARN, not a
    FAIL; the enable-start WARN covers persistent enable states only
  - services: 7.234.0 the fstab row is WARN when a digits-only ext4 row is
    left; a preserved mkinitcpio.conf snapshot path prints in install mode
  - boot: 7.234.0 the DO-NOT-REBOOT inspect step uses sudo and the resolved
    $BOOT
  - finalize: 7.233.0 a run that stops before Finalize records the restarts it
    owes in ~/ry-install/pending-apply for the next run of the same boot
  - install-file: 7.233.0 a re-run on a boot file runs the boot cascade even
    when its bytes are unchanged
  - install-file: 7.233.0 mkinitcpio.conf and sdboot-manage.conf check HOOKS
    and MODULES before the write and exit 3
  - install-file: 7.233.0 with nft(8) absent the nftables post-hook says so
    instead of reporting a failed nft -c
  - cleanup: 7.233.0 tracked tmpfiles in the root-only /run/ry-install are
    removed via sudo
  - logging: 7.234.0 a signal or tmpfile helper before the header no longer
    leaves a footer-only or header-second JSONL
  - logging: 7.234.0 child SIGKILL, a failed pending-apply clear, an absent
    modinfo and a skipped mkinitcpio.conf snapshot are logged
  - progress: 7.234.0 the bar reads the terminal size from the stderr tty
  - summary: 7.234.0 the verdict is still logged when stderr is gone;
    --install-file prints Installed only when bytes changed


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
