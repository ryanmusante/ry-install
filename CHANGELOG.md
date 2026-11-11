Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.264.0
-------

  - guard: an inherited fish_read_limit of a few bytes no longer prints a fish
    error at startup or lets a piped run past its refusal
  - guard: a fish universal named _RPT_* no longer exits 3; ry-verify's report
    state is gone
  - cli: --install-file given --report as its value reads got flag, like any
    other dash value; ry-verify dropped that flag
  - consistency: messages and log lines read user bus, not user-bus, as the
    README does; the DEPLOY_HELD log line reads re-deploy
  - consistency: the lock pidfile write and install errors read pidfile, as
    the other lock errors and log keys do
  - changelog: fold the previous release into the range


7.246.0 - 7.262.0
-----------------

  - env: 7.248.0 SDL_GAMECONTROLLER_IGNORE_DEVICES gains 0x3434/0x0b00 (Q0 HE)
  - configuration: 7.247.0 a post-write mismatch with only an older run's
    .ry.bak says no backup from this run
  - configuration: 7.248.0 libinput ignores the Xbox Wireless Controller
  - configuration: 7.250.0 a managed symlink behind a directory this user
    cannot traverse is replaced; its target is never chmodded
  - configuration: 7.251.0 the 60-ry-modules.conf header no longer claims
    module options; an existing install re-deploys it once
  - configuration: 7.252.0 a sudo lapse before the atomic move FAILs the file,
    not an [ERR] line; 7.257.0 one before the temp copy is named in the FAIL
  - configuration: 7.254.0 an nft -c that could not run refuses the deploy as
    not run, not as a failed ruleset
  - configuration: 7.254.0 a signal right after a config lands no longer drops
    its owed restart, and a config that fails to land is not left owed
  - configuration: 7.255.0 an unchanged system file not owned by root:root is
    chowned back, as a drifted mode is restored
  - configuration: 7.256.0 bluez5.roles from WP_BLUEZ_ROLES, no hfp_*/hsp_*
    role, in ~/.config/wireplumber/wireplumber.conf.d/51-ry-bluez-roles.conf
  - configuration: 7.257.0 a boot file's post-write check also compares sizes,
    so one with NUL bytes no longer passes as identical
  - configuration: 7.257.0 a sudo lapse at the post-write restore probe prints
    the hand-restore command rather than claiming no backup from this run
  - configuration: 7.257.0 with an hfp_*/hsp_* role in WP_BLUEZ_ROLES, the
    bluez5.roles drop-in comment no longer says there is none
  - configuration: 7.257.0 a mode drift repair names the old mode in 0644
    form, read before an owner repair's chown clears setuid/setgid
  - configuration: 7.258.0 the held mkinitcpio.conf WARN no longer claims a
    rollback when the seed never landed; a revert's failed cmp gives its rc
  - configuration: 7.260.0 a boot file not readable back with sudo cached
    FAILs and restores its .ry.bak by copy, then rename
  - configuration: 7.260.0 the hand-restore hint after a lapsed backup probe
    copies the .ry.bak (sudo cp)
  - configuration: 7.260.0 an nft -c or a parent-dir mkdir that ran and failed
    as the sudo ticket expired reads as failed, not as a lapse
  - guard: 7.247.0 an early exit keeps a ~/ry-install/backups it did not
    create
  - guard: 7.247.0 inherited mkinitcpio rollback variables never drive a
    revert
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
    run; fish_read_limit is pinned, 7.258.0 to 100 MiB, 7.260.0 to 1 GiB
  - guard: 7.250.0 a fish universal named _early_ch is no longer erased; the
    root check ignores a universal _flag_install_file
  - guard: 7.251.0 a universal _ROOT_UUID never reaches the kernel cmdline
  - signals: 7.250.0 a signal mid-banner or in any phase after a package,
    boot-critical file or mkinitcpio revert failure prints DO NOT REBOOT
  - signals: 7.250.0 an interrupted banner for a refused rebuild points at the
    JSONL log, not the summary matrix or an [ERR] line
  - signals: 7.250.0 a second signal while a startup signal is handled no
    longer exits 0 or 1, skipping the notice and dir cleanup
  - signals: 7.250.0 a signal in an early exit's final step, 7.251.0 or before
    the main handler takes over, keeps its exit code; teardown keeps 128+N
  - signals: 7.251.0 a signal during a pacman transaction (-Syu, its retry,
    the conflict swap), 7.252.0 or a PKGS_DEL removal, prints DO NOT REBOOT
  - signals: 7.251.0 - 7.252.0 a signal during a package or boot-file
    failure's [ERR] or [FAIL] lines, revert or restore prints the banner
  - signals: 7.252.0 a pacman pass alpm refused at prepare no longer marks the
    run mid-transaction, 7.254.0 unless an earlier pass failed past prepare
  - signals: 7.252.0 teardown no longer autoloads a user function named
    _progress_teardown or _tmp_dir during startup
  - signals: 7.254.0 after a pacman pass or PKGS_DEL removal fails
    mid-transaction, DO NOT REBOOT stays owed until Boot's rebuild; -Syu WARNs
  - signals: 7.254.0 a pacman run that never ran or stopped before its hooks
    no longer reads as cut short mid-transaction
  - signals: 7.254.0 a signal just after the mkinitcpio.conf snapshot is made
    no longer strands it; one just after its removal prints no restore command
  - signals: 7.255.0 a signal before the mkinitcpio.conf seed lands no longer
    rewrites it or WARNs; one after -Syu passes no longer reverts the seed
  - signals: 7.257.0 when pacman dies holding its lock, the DO NOT REBOOT
    banner says to remove the stale db.lck before -Syu
  - signals: 7.260.0 a signal-time mkinitcpio.conf revert skipped for a sudo
    lapse counts its WARN in the footer tally
  - cli: 7.247.0 the --install-file control-character refusal states why
  - cli: 7.252.0 an unexpected positional argument prints escaped, an empty
    one as ''; 7.254.0 a root run escapes each leftover argument whole
  - cli: 7.254.0 argument errors print control characters (C1, raw bytes)
    escaped or as ?; an --install-file value holding one is refused first
  - cli: 7.254.0 --install-file given --verify, --check, --report, --help or
    --version as its value names both spellings
  - cli: 7.254.0 every --install-file error escapes the value, so a trailing
    blank no longer reads as the managed path
  - cli: 7.254.0 a 4095-slash --install-file no longer stalls the NAME_MAX
    check
  - cli: 7.254.0 -h or -v ending in a newline is an unknown option (exit 2)
  - preflight: 7.247.0 MKINITCPIO_MODULES and MKINITCPIO_HOOKS tokens are
    charset-checked
  - preflight: 7.247.0 a missing realpath no longer prints fish errors; a
    module that may not exist warns on the console
  - preflight: 7.252.0 a HOME that normalizes to empty or a non-directory
    names the value set in its exit-3 error
  - preflight: 7.254.0 an embedded value ending in a newline (governor,
    country, count, kernel or HOOKS token) is refused
  - preflight: 7.254.0 a relative HOME, 7.255.0 or one with a control
    character, takes the passwd entry; such a passwd entry exits 3
  - preflight: 7.254.0 the root UUID takes findmnt's first match, so a mount
    stacked on / no longer fails the run as an invalid UUID
  - preflight: 7.254.0 an RY_RUN_TIMEOUT ending in a newline reads invalid,
    not a fish error at every command; its WARN prints the value escaped
  - preflight: 7.254.0 the network probe skips ~/.curlrc; no write-out on
    stdout
  - preflight: 7.254.0 a TLS failure names the clock or a TLS proxy, not DNS;
    7.255.0 curl rc 77 names SSL_CERT_FILE, CURL_CA_BUNDLE and ca-certificates
  - preflight: 7.254.0 the dependency gate also requires bootctl, ln, readlink
    and uname, so a host without bootctl stops before any change
  - preflight: 7.255.0 a ping that cannot open an ICMP socket leaves the raw
    IPs unprobed instead of reporting them unreachable
  - preflight: 7.255.0 sudo uncached with no TTY prints one ERR naming the TTY
  - preflight: 7.255.0 the hardware override hint and the nftables manual step
    name the script as invoked, not ./ry-install.fish
  - preflight: 7.255.0 config validation picks each validator by managed path,
    so a HOME under a dir such as modprobe.d no longer fails it
  - preflight: 7.256.0 WP_BLUEZ_ROLES entries must be PipeWire role names;
    WP_BLUEZ_ROLES:4 is a drift tripwire
  - preflight: 7.257.0 a failed config validation names the failing checks
  - preflight: 7.257.1 EXPECTED_VULKAN_PKGS:2 is a drift tripwire; a member in
    PKGS_DEL or starting with a dash refuses to deploy
  - preflight: 7.258.0 an unresolvable $BOOT or a non-vfat fallback /boot
    exits 3 before -Syu, not 4 after, with the gate's refusal the one ERR
  - preflight: 7.258.0 true(1) and test(1) are checked at startup
  - preflight: 7.260.0 the ESP gate refuses an ESP not at /boot or an XBOOTLDR
    $BOOT, and reads not checked under a sudo lapse
  - preflight: 7.260.0 a /boot linked to the ESP gets the /boot free-space
    gate, not the INFO that the / check covers it
  - lock: 7.254.0 the lock dir is set 00700, clearing an inherited setgid bit;
    the printed lock-removal command escapes its path
  - lock: 7.254.0 - 7.255.0 a signal while dropping a reclaim claim or
    releasing the lock no longer strands .claim or an empty lock directory
  - lock: 7.254.0 - 7.255.0 a holder releasing the lock mid-check, or between
    this run's mkdir and its check, no longer makes the run exit 5
  - lock: 7.255.0 a lock not taken logs ERR and counts in the footer
  - progress: 7.254.0 a signal while the bar pins or unpins no longer leaves
    the scroll region set or clears the top row
  - packages: 7.246.0 a missing member whose dependency conflicts with an
    installed package is held for the swap, not left to fail both passes
  - packages: 7.246.0 a conflict swap gets a summary row naming what it
    removed; an rc-0 -Syu or swap whose hooks log errors reads WARN
  - packages: 7.247.0 a -Syu pass stopped by a dependency conflict holds the
    member pulling it and runs again; re-pass and -Syyu notices print
  - packages: 7.250.0 a HOOKS build script behind a 0700 /etc/initcpio/install
    no longer reads missing after -Syu; 7.251.0 sudo probes only unseen ones
  - packages: 7.251.0 a failed pacman -Q no longer reads as an unchanged
    package set; the run counts it as an upgrade
  - packages: 7.251.0 a PKGS_DEL member an earlier member's -Rns took is
    logged as removed, not retried as a failing removal
  - packages: 7.252.0 a hook error past the 500-line capture still reads WARN
  - packages: 7.254.0 error lines kept from a long pacman output's elided
    middle stay in file order, print with QUIET off, log under _OVERFLOW_KEPT
  - packages: 7.254.0 a re-run whose mkinitcpio.conf seed changed nothing
    drops its rollback, so a failed -Syu no longer reverts and holds the file
  - packages: 7.255.0 a failed mkinitcpio.conf seed reverts any bytes it
    landed; 7.257.0 Configuration then holds the restored original
  - packages: 7.255.0 a conflict-swap hook error leads its row, so a long
    removal list no longer cuts it from the matrix
  - packages: 7.255.0 a -Syyu retry, conflict swap, explicit mark, updatedb or
    pkgfile that sudo refused reads as not run (sudo cache lapsed), not failed
  - packages: 7.257.0 a failed install counts once in the footer; neither the
    missing-package recap nor a failed retry's notice adds a count
  - packages: 7.257.0 a sudo lapse at a HOOKS check reads as unchecked (a WARN
    after -Syu), not as a missing or invalid hook
  - packages: 7.257.1 -Syu also installs EXPECTED_VULKAN_PKGS, so on a host
    without RADV, vulkan-driver no longer resolves to an NVIDIA package
  - packages: 7.257.1 an installed -git or -bin build conflicting with a
    Vulkan driver is swapped out after -Syu, as for PKGS_ADD
  - packages: 7.258.0 -Syu names only a missing EXPECTED_VULKAN_PKGS member,
    none when pacman -Qq fails, so an IgnorePkg hold stands
  - packages: 7.258.0 a pacman run stopped by a pre-transaction hook reads as
    nothing committed, not as failed mid-transaction
  - packages: 7.258.0 a failed conflict swap is named on the -Syu row
    (conflict swap failed, N missing), not only in an [ERR]
  - backup: 7.250.0 ~/ry-install/backups is created by the first .ry.bak copy,
    so no early exit removes it; 7.257.0 a failed copy WARNs on the terminal
  - services: 7.247.0 a PKGS_DEL hook error keeps the row's rdep-skip count
  - services: 7.250.0 a resolved drop-in behind a directory this user cannot
    traverse no longer skips the restart, nor reads absent under a lapsed sudo
  - services: 7.251.0 an owed systemd-resolved restart that a lapsed sudo
    cache blocks reads WARN (applies next boot), not SKIP
  - services: 7.252.0 the fstab rewrite no longer refuses over a findmnt
    --verify error, 7.254.0 or parse error, the original carries
  - services: 7.252.0 under a lapsed sudo cache a masked ufw.service reads
    firewall unverified, not down; enable and mask retries name the lapse
  - services: 7.252.0 nftables-first no longer claims ufw rules stay before
    the ufw step decides; SECURITY says whether the mask follows or holds
  - services: 7.254.0 an fstab with only malformed ext4 rows WARNs that none
    is well-formed, not that all are conformant
  - services: 7.254.0 a mask retry under a lapsed sudo cache FAILs naming the
    lapse (MASK_LAPSE); a mask FAIL row counts units masked but not stopped
  - services: 7.254.0 the enable row no longer counts nftables.service as
    already enabled when the nftables-first step enabled it this run
  - services: 7.254.0 - 7.255.0 the mask and enable rows put their notes
    before unit lists, so the matrix cell no longer cuts them off
  - services: 7.254.0 - 7.255.0 the enable row WARNs naming a unit not
    installed; 7.257.0 it then counts only units this run enabled
  - services: 7.255.0 the fstab rewrite names a lapsed sudo cache when its
    mktemp or read fails, not fstab perms
  - services: 7.255.0 a masked unit still activating is stopped by mask --now
  - services: 7.255.0 a regdom apply sudo refused names the lapsed cache
  - services: 7.255.0 with ufw masked and nftables down, the SECURITY line
    names a diagnosis, not the enable that just failed
  - services: 7.255.0 a package a failed PKGS_DEL batch took counts as removed
  - services: 7.257.0 an fstab scan that fails, ext4 or malformed rows, FAILs
    the fstab step rather than reading as nothing found
  - services: 7.258.0 a PKGS_DEL member that failed while a later member
    depended on it is retried once that member is gone
  - services: 7.258.0 the PKGS_DEL row tells probe-failed apart from rdep
    skips
  - services: 7.258.0 a MASK unit whose file is gone but which still runs is
    masked and stopped, not skipped as not installed
  - services: 7.258.0 on systemd 253+, an empty is-enabled answer is a failed
    query: the unit is masked or enabled, not skipped
  - services: 7.258.0 an enabled NetworkManager.service that is not running is
    started; its package preset stays
  - services: 7.258.0 the fstab rewrite's findmnt --verify runs under
    RY_RUN_TIMEOUT (0: no limit); a timeout refuses the rewrite
  - services: 7.260.0 a package-preset unit the enable batch owned is reported
    once when its start fails, not retried and counted again
  - services: 7.260.0 a resolved restart that sudo refused reads not run (sudo
    cache lapsed); a lapsed preset start shows no Diagnose hint
  - services: 7.260.0 a start, enable or mask that ran and failed while the
    sudo ticket expired reads as failed, not as a lapse
  - services: 7.260.0 the enable row reads enabled, not started for a unit
    whose start failed or was refused
  - boot: 7.250.0 an empty loader entries directory no longer adds
    sdboot-manage gen or LINUX_OPTIONS hints before the banner
  - boot: 7.250.0 the loader-entry boundary check resolves symlinks as root,
    catching an entry that escapes a 0700 $BOOT through a link
  - boot: 7.250.0 - 7.252.0 an ESP-fallback host's DO NOT REBOOT banner says
    to check the ESP and re-run, even mid-pacman, never sdboot-manage gen
  - boot: 7.252.0 the EFI refresh runs bootctl --graceful update and fails on
    its error; 7.254.0 the DO NOT REBOOT rebuild step prints it too
  - boot: 7.255.0 the DO NOT REBOOT inspect step quotes $BOOT, so a mount path
    with a space prints a working command
  - boot: 7.255.0 boot sanity lists loader entries as systemd-boot does
    (hidden skipped, .conf in any case) and fails one it cannot read
  - boot: 7.257.0 a loader entry path whose name merely ends in .. no longer
    fails boot sanity as parent-dir traversal
  - boot: 7.258.0 boot sanity also fails an entry whose kernel is empty or
    whose initrd is not a regular file, such as a directory
  - boot: 7.260.0 boot sanity also fails a linux entry with no initrd line
  - boot: 7.260.0 boot sanity names a sudo lapse once and stops probing; a
    failed listing says lapsed, missing or read error
  - boot: 7.260.0 boot sanity reads entries as systemd-boot does: the last
    linux line counts, and auto-* entries are skipped
  - boot: 7.260.0 an unmounted /boot reads fstype=none in the non-vfat refusal
  - finalize: 7.252.0 with no plasma-powerdevil.service, an environment.d
    change skips the re-apply instead of WARNing a failed restart
  - finalize: 7.254.0 an NM_RESTART_DELAY ending in a newline falls back to 3
    s instead of failing the settle sleep
  - finalize: 7.255.0 the matrix Next line points at ./ry-verify.fish in the
    ry-verify clone; the usermod manual steps quote the account name
  - finalize: 7.256.0 a changed or owed bluez5.roles drop-in try-restarts
    wireplumber.service; no user bus, no unit or exit 4 is a SKIP row
  - finalize: 7.257.0 the PowerDevil and WirePlumber PASS rows read changed or
    owed, as a restart owed by an earlier run also fires them
  - finalize: 7.260.0 a NetworkManager restart or pacman cache trim that sudo
    refused reads not run (sudo cache lapsed), not failed
  - install-file: 7.249.0 a boot-critical failure prints DO NOT REBOOT and its
    recovery steps once, in the closing banner
  - install-file: 7.252.0 an environment.d or bluetooth deploy without the
    unit no longer WARNs a failed restart; 7.254.0 a cpupower one skips it
  - install-file: 7.252.0 the modprobe.d post-hook no longer claims module
    options, matching the 60-ry-modules.conf header
  - install-file: 7.254.0 the boot-file gates run after sudo is cached, so a
    hook only root can see no longer reads as invalid
  - install-file: 7.254.0 an absent udevadm, or a failed verify or reload,
    says udevd re-reads the changed rule on its next event, not at next boot
  - install-file: 7.254.0 a post-write nft -c or udevadm verify that could not
    run or timed out, 7.258.0 or that sudo kept from running, is no verdict
  - install-file: 7.254.0 a resolved, NetworkManager or environment.d apply
    that succeeds strikes its owed entry, so a later run does not repeat it
  - install-file: 7.254.0 each managed file runs its own post-hook, so a HOME
    under a directory such as sysctl.d no longer reroutes a user file
  - install-file: 7.254.0 - 7.255.0 a sysctl --system that rejected a key says
    the rest are live, fix the key; one that did not run or finish says retry
  - install-file: 7.254.0 - 7.255.0 a changed file prints one OK, a failed
    write one FAIL; the nm-dispatcher apply confirms with an OK too
  - install-file: 7.255.0 a HOME under /etc or /boot no longer reads the user
    files via sudo, so a lapsed cache no longer re-deploys them
  - install-file: 7.255.0 a boot file runs the dependency and ESP gates before
    the write: a missing bootctl or unmounted ESP exits 3, not 4 after it
  - install-file: 7.256.0 the bluez5.roles drop-in try-restarts
    wireplumber.service; one that fails or finds no user bus stays owed
  - install-file: 7.257.0 the nft and udevadm verify hints name the script
  - install-file: 7.257.0 a WirePlumber try-restart no longer claims
    bluez5.roles applied when WirePlumber was not running
  - install-file: 7.260.0 a boot file's gates also refuse an ESP not mounted
    at /boot or an XBOOTLDR $BOOT (exit 3)
  - install-file: 7.260.0 a NetworkManager drop-in deployed without
    NetworkManager owes no restart in ~/ry-install/pending-apply
  - install-file: 7.260.0 a resolved or NetworkManager restart sudo refused
    reads not run (sudo cache lapsed), as in a full install
  - install-file: 7.260.0 a sysctl --system or udevadm verify that ran and
    failed as the sudo ticket expired reads as failed, not as a lapse
  - logging: 7.246.0 a failed pacman call echoes its package-conflict lines
  - logging: 7.247.0 boot-cascade and udev-skip records carry the POST_
    prefix; a failed date no longer breaks the header JSON
  - logging: 7.247.0 _run clears its capture before an early return, the
    bail-out record precedes INSTALLATION END, an empty loud _err logs nothing
  - logging: 7.250.0 a full-install boot-critical failure no longer logs a
    second copy of the rebuild command ahead of the banner
  - logging: 7.250.0 closing log-file lines are skipped once stderr is gone;
    the preflight log is created as soon as its dir exists
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
  - logging: 7.254.0 enable skips log ENABLE_ALREADY and ENABLE_NOT_INSTALLED;
    an absent NetworkManager logs NM_RESTART_SKIP_NO_NM
  - logging: 7.254.0 BACKUP_SKIP_SUDO_LAPSE logs dst= and probe= at both
    sites; Finalize's NM restart deferral and failure log context=finalize
  - logging: 7.254.0 the end-of-run summary is JSONL-only, so the footer no
    longer counts Done! as a pass or the error recap as a fail and a warn
  - logging: 7.254.0 - 7.255.0 Finalize's NM deferral leaves an NM-only owed
    list as filed and logs PENDING_APPLY_DROPPED per drop
  - logging: 7.255.0 an empty explicit mark logs PKG_ASEXPLICIT_SKIP
  - logging: 7.255.0 one failure counts once in the footer, however many lines
    restate it; a skipped enable or blocked resolved restart counts a WARN
  - logging: 7.255.0 refusals log HARDWARE_*_REFUSED and ROOT_UUID_UNAVAILABLE
  - logging: 7.255.0 a sudo lapse that skips a signal-time revert is logged
  - logging: 7.257.0 a failed resolved or PowerDevil restart, user
    daemon-reload, cache trim or indexer run logs a _FAIL key
  - logging: 7.257.0 a non-UTF-8 byte in a logged string is written as U+FFFD,
    so every JSONL line stays valid UTF-8
  - logging: 7.258.0 a host that fails the network check logs its curl rc; an
    unparsable df read logs its raw value
  - logging: 7.258.0 a mask or enable failure logs MASK_FAIL or ENABLE_FAIL, a
    failed batch MASK_BATCH_FAIL or ENABLE_BATCH_FAIL
  - logging: 7.258.0 a sudo lapse at a managed file's read, mode or owner
    probe logs SKIP_PROBE_SUDO_LAPSE or MODE_DRIFT_UNPROBED
  - logging: 7.258.0 the mkinitcpio revert's cp, cmp, chmod, chown and mv, the
    snapshot cp and the fstab chmod and chown log their error
  - logging: 7.258.0 PACTREE_PROBE_FAIL logs the rc; POSTWRITE_VERIFY_FAIL a
    reason, both digests and, for reason=size, both sizes
  - logging: 7.258.0 POSTWRITE_RESTORE_STALE only when an older copy exists;
    an unmanaged nftables.service logs NFT_PRE_ENABLE_UNMANAGED
  - logging: 7.260.0 an invalid or clamped RY_RUN_TIMEOUT counts a footer warn
  - logging: 7.260.0 a ~/ry-install dir moded to 0700 logs STATE_DIR_PERM_FIX;
    one that stays wrong names the state tree in its ERR, not the log tree
  - logging: 7.260.0 an ESP layout refusal logs ESP_LAYOUT_REFUSED
  - logging: 7.260.0 sudo-refused steps log PRESET_START_LAPSE,
    NM_RESTART_LAPSE, RESOLVED_RESTART_LAPSE or PACMAN_CACHE_TRIM_LAPSE
  - logging: 7.260.0 an ESP gate lapse logs ESP_LAYOUT_LAPSE; refused
    post-hook restarts POST_RESOLVED_RESTART_LAPSE or POST_NM_RESTART_LAPSE
  - logging: 7.260.0 a lapsed read-back logs POSTWRITE_VERIFY_SKIP
    reason=read_lapse, a failed one POSTWRITE_VERIFY_FAIL reason=unreadable
  - logging: 7.260.0 a mkinitcpio revert after the footer prints but logs
    nothing, so the footer stays the last JSONL record
  - summary: 7.247.0 failed summary or banner writes log STDERR_WRITE_FAIL
  - summary: 7.257.0 a run whose -Syu changed packages adds a manual step to
    review archlinux.org/news and wiki.cachyos.org
  - summary: 7.258.0 a failed mkinitcpio, sdboot-manage gen or bootctl update
    row gives the command's rc, or that it never ran
  - summary: 7.260.0 a boot step sudo refused reads not run (sudo cache
    lapsed)
  - consistency: 7.260.0 an nft -c that _run cannot start reads no capture dir


7.235.0 - 7.245.0
-----------------

  - guard: 7.243.0 TMPDIR is pinned to /tmp; an inherited LOG_FILE, LOG_DIR or
    _RY_BACKUP_DIR is not deleted by an early exit
  - guard: 7.245.0 an early exit removes ~/ry-install only if this run made it
  - lock: 7.245.0 lock hints quote the path and pass --preserve-root; a
    kill-less host takes the /proc lock branch silently
  - cli: 7.241.0 help aligns its ENVIRONMENT column
  - cli: 7.243.0 an argument error writes no /tmp file; a 4096-byte
    --install-file path fails as over PATH_MAX
  - cli: 7.245.0 an over-long RY_RUN_TIMEOUT warns that 2147483647 is used
  - signals: 7.243.0 a signal during the boot rebuild prints the DO NOT REBOOT
    recovery banner before exiting 128+N
  - signals: 7.245.0 a signal in the mv -T probe leaves no temp files in /tmp
  - signals: 7.245.0 drop the PIPE handler; it silenced a live terminal
  - preflight: 7.243.0 a sudo -v that caches nothing (timestamp_timeout=0)
    exits 3 instead of failing every later sudo step
  - preflight: 7.243.0 the sudo banner drops the NOPASSWD drop-in; an absent
    findmnt is named as the root-UUID failure
  - preflight: 7.243.0 the dual-stack WARN names both nftables generators
  - preflight: 7.245.0 a sudo -n -v that passes yet leaves sudo -n unusable
    exits 3; the sudo banner suggests a keepalive in this terminal
  - preflight: 7.245.0 missing optional tools and an absent modinfo warn on
    stderr; the validation error counts failed checks
  - packages: 7.235.0 a PKGS_ADD member an installed package conflicts with
    sits out -Syu, installs alone with --ask=4 (pipewire-jack replaces jack2)
  - packages: 7.235.0 the -Syu FAIL row names its cause and missing count;
    manual fixes read pacman -Syu --needed instead of a partial-upgrade -S
  - packages: 7.240.0 a member a -git or -bin build provides and conflicts
    with is swapped in after -Syu; a failed swap of it reads FAIL
  - packages: 7.240.0 pacman -Si and -Qi output is read with COLUMNS=0; an
    exported COLUMNS no longer wraps a conflict list past the parser
  - packages: 7.243.0 a locked pacman db reverts the seeded mkinitcpio.conf
  - packages: 7.245.0 -Syyu re-reads conflict holds from the refreshed sync db
  - packages: 7.245.0 the held mkinitcpio.conf WARN names the seed rollback
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
  - services: 7.243.0 an ext4 fstab row with several commit= gets one
    commit=10; one with fewer than 4 fields is left untouched (row WARN)
  - services: 7.243.0 a findmnt --verify failure logs its full output
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
    manual rebuild step; the former says to mount the ESP and re-run
  - boot: 7.245.0 a symlinked loader/entries directory is listed; entry checks
    name a rejected path and a missing directory
  - boot: 7.245.0 a signal during the read-only post-rebuild checks no longer
    prints the interrupted-rebuild banner
  - finalize: 7.243.0 an NM restart deferred over Wi-Fi stays owed in
    pending-apply until a run off Wi-Fi or a reboot applies it
  - finalize: 7.243.0 the PowerDevil re-apply uses try-restart
  - finalize: 7.245.0 a pending-apply marker from an earlier boot is dropped
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
  - progress: 7.243.0 a resize re-pins the bar on the new bottom row, an
    aborted run counts 6 phases; 7.245.0 the bar unpins before its last writes
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
  - packages: 7.224.0 add pipewire-jack
  - packages: 7.233.0 after a failed -Syu, a reverted mkinitcpio.conf stays in
    place through Configuration (WARN 'mkinitcpio.conf held')
  - packages: 7.233.0 PKGS_ADD is re-marked explicit whatever the -Syu result;
    -Rns runs only after a successful mark, retried if it failed; else -Rn
  - packages: 7.234.0 a failed pactree probe is reported as held, not as
    nothing installed; a member another's -s cascade removed is not failed
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
  - preflight: 7.225.0 the modprobe.d check names directives in match order
  - preflight: 7.233.0 the /boot free-space gate runs on stacked mounts; ESP
    autodetect and the vfat gate read the topmost non-autofs mount
  - preflight: 7.233.0 a setgid $HOME or a symlinked ~/ry-install no longer
    fails the log-dir mode check
  - preflight: 7.233.0 the sudo credential check writes no /tmp file
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
    stale dir aside in one rename; release checks the pidfile is this run's
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
  - boot: 7.234.0 the DO-NOT-REBOOT inspect step uses sudo and resolved $BOOT
  - finalize: 7.233.0 a run that stops before Finalize records the restarts it
    owes in ~/ry-install/pending-apply for the next run of the same boot
  - install-file: 7.233.0 a boot-file re-run runs the cascade, unchanged or
    not
  - install-file: 7.233.0 mkinitcpio.conf and sdboot-manage.conf check HOOKS
    and MODULES before the write and exit 3
  - install-file: 7.233.0 with nft(8) absent the nftables post-hook says so
    instead of reporting a failed nft -c
  - cleanup: 7.233.0 root-only /run/ry-install tmpfiles are removed via sudo
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
  - dns: 7.123.0 - 7.129.0 pin upstreams in resolved and NM global-dns
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
  - install-file: 7.108.0 - 7.117.0 a post-hook dispatch table
  - lock: 7.108.0 - 7.117.0 dead-PID reclaim only, live or ambiguous pidfiles
    fail closed
  - summary: 7.132.0 - 7.134.0 the abort path's phase-3 row took the normal
    name


7.99.1 and earlier
------------------

  - profile: initial profile for the Beelink GTR9 Pro
