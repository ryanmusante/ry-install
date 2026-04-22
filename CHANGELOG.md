ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first,
entries grouped under a dated heading, each bullet names the
subsystem or function before the change description.


v4.1.15 - 2026-04-22
--------------------

  * _atomic_write_file: add parent-dir trust checks to the non-sudo
    branch (symmetric with sudo branch). Verifies stat %F=directory,
    test -L for symlink, %u == $_MY_UID, and calls
    _dir_group_or_world_writable on %a. Closes pre-existing asymmetry
    that allowed USER_DESTINATIONS writes under shared or
    group-writable parents without validation.

  * _ry_verify_runtime: fold dual stat invocations into one at four
    call sites (NM connection files, installed system files,
    installed user files, parent directories). Replace
    `stat -c '%a'` + `stat -c '%U:%G'` pairs with a single
    `stat -c '%a %U:%G'` and `string split ' '`. Halves fork count
    per enumerated file; output is byte-identical.

  * _ry_install_file: drop redundant `set -l dst $argv[1]` /
    `set -l use_sudo $argv[2]`. The enclosing
    `--argument-names dst use_sudo` already creates both as
    function-local pointing to the same argv slots. Dead code.

  * _install_fstab_opts: deregister tmpfstab (aliased to tmpfstab2
    at post-awk rename) from _TRACKED_TMPFILES after successful
    atomic mv. Mirrors the existing tmpfstab-original deregister
    and keeps the cleanup list from growing stale on the success
    path. rm -f was already idempotent; no functional impact.

  * _ry_verify_runtime: replace `test -n "$conn_files"` with
    `test (count $conn_files) -gt 0` at the NM connection scope.
    Fish quotes the list into a space-joined single arg so
    test -n was correct but misleading; new form is consistent
    with `count $conn_files` use elsewhere in the same block.

  * _ry_get_file_content, _ry_check_deps: drop redundant trailing
    `| head -n 1` after `string match -r -- '\d+'`. Verified
    against fish 3.7.0: `string match -r` without `-a` returns
    only the first match per input line, so the pipeline's
    preceding `| head -n 1` already constrains to a single result.

  * version: 4.1.14 -> 4.1.15.


v4.1.14 - 2026-04-21
--------------------

  * _ry_exit: capture _RY_INSTALL_SOURCED into function-local
    _was_sourced before calling _ry_namespace_cleanup bail. The
    sentinel is set after the _RY_PRE_GLOBALS snapshot and not in
    the preserve list, so the prior guard always evaluated false
    and `exit $code` unconditionally ran; worked solely because
    fish's exit in sourced context is host-safe.

  * _acquire_lock: flock-less stale reclaim error-checks
    `printf '%s\n' $fish_pid >"$LOCK_FILE"` with rmdir rollback
    and LOG_FILE cleanup; symmetric with primary-write path.

  * _detect_lvm: scope _pvs_output function-local (was dead global;
    no consumer read it).

  * _ry_get_file_content: `case /etc/kernel/cmdline` and
    `case /etc/drirc` quoted for consistency with the other 14
    case arms.

  * _ry_verify_static, _install_rebuild_boot: switch
    `find ... *.conf | wc -l` to
    `count (find ... -print0 | string split0)` at all three sites.
    Aligns with v4.1.12 null-delim policy.

  * _install_rebuild_boot: _initrd_list enumeration switched to
    `-print0 | string split0` for parity with boot-wipe marker
    scans.

  * bootstrap: quote KVER in `string split '.' -- "$KVER"`. Parity
    with L77-78 and error-message sites.

  * progress bar: remove dead PROGRESS_STEPS list; set -g
    PROGRESS_TOTAL 6 replaces `(count $PROGRESS_STEPS)`. Step
    names live at call sites; runtime mismatch still caught by
    _progress_done assertion.

  * comments: three multi-line # blocks collapsed to single-line
    form (project convention).

  * comments: stale line-number references replaced with
    function-name references (L5325/L5438 ->
    _install_rebuild_boot + _install_finalize boot-wipe marker;
    detector L3716 -> "hash-job child distinguishes missing hash
    from hash-mismatch").

  * ChangeLog: v4.1.9-v4.1.12 dates corrected 2026-04-22 ->
    2026-04-21 (chronology was non-monotonic vs. v4.1.13).


v4.1.13 - 2026-04-21
--------------------

  * profile gtr9_pro SYSCTL_VALUES: add kernel.split_lock_mitigate=0
    and vm.swappiness=100. Count 19 -> 21. split_lock_mitigate=0
    pairs with the existing split_lock_detect=off kernel param
    (detection off + 10 ms sleep-penalty suppression on).
    swappiness=100 tuned for zram-backed swap (zswap.enabled=0
    kernel param documents ZRAM as primary swap tier).

  * profile gtr9_pro ENV_VARS: RADV_EXPERIMENTAL=transfer_queue,hic
    -> transfer_queue. HIC default-on for GFX10.3+ in Mesa
    post-2026-04-21; hic token inert on gfx1151. Count 12 -> 13:
    add PROTON_NO_WM_DECORATION=1 (borderless-fullscreen
    correctness under COSMIC Wayland). List re-sorted to strict
    alpha.

  * profile gtr9_pro: annotate amd_pstate=active as upstream
    default since Linux 6.5, ppfeaturemask=0xfffd3fff as upstream
    driver default (bits 14/15/17 off), and
    fs.protected_{fifos,regular}=2 as kernel defaults since 5.0.
    All treated as drift-pins; explicit settings retained.

  * README: Kernel 6.14+ -> >= 6.18.4 (gfx1151 stability floor).
    Fish 3.4+ -> >= 4.0 recommended (3.4 minimum).

  * README Known Issues (Strix Halo GPU, MES page faults row):
    generic "Pin known-good linux-firmware" -> specific guidance
    (avoid linux-firmware-20251125; pin <= 20250808-1 for ROCm, or
    switch to amdgpu-dkms-firmware).

  * README Environment Variables table:
    ENABLE_LAYER_MESA_ANTI_LAG marked AMD-only;
    PROTON_ENABLE_WAYLAND marked "experimental; breaks Steam
    Overlay"; PROTON_NO_WM_DECORATION row added. sysctl.d summary
    row count 19 -> 21.

  * README Kernel Parameters table: pcie_aspm.policy=performance
    annotated with desktop-only scope.

  * README: new "Per-game tuning" subsection covering
    MESA_VK_WSI_PRESENT_MODE=mailbox,
    DISABLE_LAYER_MESA_ANTI_LAG=1,
    PROTON_NO_WM_DECORATION=0, and PROTON_FSR4_RDNA3_UPGRADE=1.


v4.1.12 - 2026-04-21
--------------------

  * _install_rebuild_boot, _install_finalize boot-wipe marker:
    `find -printf '%f\n'` -> `-printf '%f\0' | LC_ALL=C sort -z |
    string split0`. Aligns with v4.1.8 null-delim policy for
    \n-in-filename hazard closure. Pre-v4.1.12 markers remain
    valid — hash input unchanged for any given file set; only the
    _existing_entries count metric gains accuracy.

  * _preflight_boot_sanity check #2: add count == 0 guard before
    the initramfs non-zero loop. Matches check #1 (vmlinuz)
    symmetry. Catches pathological mkinitcpio configs that exit 0
    while producing no initramfs-*.img output.


v4.1.11 - 2026-04-21
--------------------

  * _ry_get_file_content: renumber function-local rc codes out of
    the EXIT_* global range to eliminate numeric overlap with
    EXIT_USAGE=2, EXIT_PREFLIGHT=3, EXIT_BOOT_CRIT=4.
    Unknown-dst 2 -> 11, missing-prereq 3 -> 12, arity-bug
    4 -> 13. Caller switch in _atomic_write_file updated in
    lockstep.

  * _atomic_write_file: post-write hash-verify pipeline inner _ps
    renamed to _hash_ps to avoid shadowing the earlier
    tee-pipeline _ps. Block-local shadow was harmless but
    distinct names reduce cognitive load when tracing pipestatus
    flow.


v4.1.10 - 2026-04-21
--------------------

  * _ry_verify_runtime: nine bare sudo read-only probes (stat,
    test, find on NM connection files, installed files, parent
    directories) switched to `sudo -n` for parity with
    _ry_verify_static. Prevents interactive prompt if sudo
    timestamp expires mid-run.

  * bootstrap: KVER major/minor parse failure paths now run
    `command rm -f -- "$LOG_FILE"` before _ry_exit, matching
    _load_profile and dispatcher cleanup symmetry.


v4.1.9 - 2026-04-21
-------------------

  * _write_footer: L307 `begin; ...; end; or return 0` expanded to
    canonical multi-line form.

  * _tmpfile_key: L1347 `string replace -a '/' '_'` unquoted
    single-char args.

  * top-level dispatcher: argparse short-form flag spec
    (L5784-5786) and deprecated-flag dispatch (L5801-5804)
    normalized to fish_indent canonical form; fish_indent --check
    exits 0.


v4.1.8 - 2026-04-20
-------------------

  * _install_packages: drop misleading "Synchronizing package
    databases..." _info (sync is inline in pacman -Syu); replace
    stale "install then remove" comment with phase-4 cross-ref.

  * _ry_show_help: document that positional args after `--` are
    rejected; add NO_COLOR to ENVIRONMENT block (README parity).

  * _install_fstab_opts: deregister deleted tmpfstab from
    _TRACKED_TMPFILES after atomic rename.

  * _preflight_boot_sanity: three find enumerations switched to
    `-print0 | string split0` for parity with
    _install_post_package_refresh (L4456) and log rotation
    (L5952). Closes \n-in-filename hazard.


v4.1.7 - 2026-04-20
-------------------

  * README: tables trimmed to essential columns/values; Managed
    Files index col, Prerequisites Notes col, and Deprecated
    Flags Notes col dropped.

  * README: sample log timestamps + version bumped to 4.1.7 /
    2026-04-20.

  * ChangeLog: v4.1.6-v4.1.2 entries condensed; line-number noise
    dropped where redundant with function names.


v4.1.6 - 2026-04-19
-------------------

  * six JSONL writers (_json_str, _log, _msg bug branch,
    _write_step_time, top-level header, _write_footer) now share
    `2>/dev/null` on append redirects. Closes TOCTOU stderr-noise
    window when log rotation races _log's existence test.

  * known deferral: _ry_verify_runtime (842 L),
    _ry_verify_static (627 L), _ry_do_check (331 L),
    _ry_validate_configs (262 L) remain monolithic —
    category-split refactor tracked for 4.2.0.


v4.1.5 - 2026-04-19
-------------------

  * _validate_profile: destination guard split — literal
    duplicates vs. slash->underscore key collisions now report
    distinct messages.


v4.1.4 - 2026-04-19
-------------------

  * _tmpfile_key: revert 4.1.3's sha256 prefix back to
    `string replace -a '/' '_'`. Producer/consumer parity
    restored across eight child-side derivations.

  * _validate_profile: tmpfile-key collision guard rejects
    destinations whose slash->underscore keys collide.

  * _ry_validate_configs, _ry_verify_static: remove dead
    timeout-vs-crash branches; collapse phantom timeout paths
    into single FAIL.

  * _kill_sudo_keepalive: `pkill -TERM -P` reaps descendants
    before SIGTERM/SIGKILL.

  * _detect_lvm: timeout 5 -> 10 (slow PAM/NSS first-call).

  * _run: stderr dedup sed -> `string trim --left` (fish-native).

  * boot-time parse: `LC_ALL=C` for locale-safe float->int.


v4.1.3 - 2026-04-19
-------------------

  * CLI dispatcher: manual while/switch -> `argparse --exclusive`.
    13-flag parity preserved.

  * _write_footer: dropped redundant `finished` field.

  * _ry_verify_static: implicit_svcs derived from
    SYSTEM_DESTINATIONS (no longer hardcoded).

  * _ry_validate_configs: prune val_dir + content_dir from
    _TRACKED_TMPFILES after rm.

  * _preflight_boot_sanity: BLS path-traversal check now
    exact-segment match.


v4.1.2 - 2026-04-19
-------------------

  * _install_preflight: sudo-tag regex `\b!PASSWD\b` failed to
    anchor; fix to
    `(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)`.

  * _ry_do_install: manifest-write decoupled from
    INSTALL_HAD_ERRORS.

  * _install_rebuild_boot: sdboot-manage update failure ->
    EXIT_BOOT_CRIT.

  * unattended -Syu now gated behind
    RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1; without ack prints three
    RSS headlines per feed.

  * _acquire_lock: quote "$fish_pid" in sh -c args.

  * _ry_check_deps: flock(1) HARD -> SOFT (fallback exists).


v4.1.1 - 2026-04-19
-------------------

  * _cleanup: fish 3.4+ passes SIG-prefixed name as $argv[1]; add
    case HUP SIGHUP, INT SIGINT, QUIT SIGQUIT, TERM SIGTERM. Exit
    codes 129/130/131/143 correctly distinguished.


v4.1.0 - 2026-04-19
-------------------

  * remove --test-all (169 L) and --completions (93 L).
    Pre-commit `fish --no-execute` supersedes the former; README
    is authoritative for the latter.

  * _ry_show_help: 72 -> 49 lines.


v4.0.x - 2026-04-18 -> 2026-04-19
---------------------------------

  * profile: KERNEL_PARAMS 12 -> 15; SYSCTL_VALUES 21 -> 19;
    PKGS_ADD 15 -> 14; EXPECTED_SERVICES 3 -> 4; new dep:
    nftables.

  * kernel params: amd_pstate=active; iommu=pt; tsc=reliable;
    loglevel=3; rd.udev.log_level=3;
    rd.systemd.show_status=auto.

  * RADV: RADV_EXPERIMENTAL=transfer_queue,hic;
    RADV_PERFTEST=sam,nircache.

  * RESOLVED_MDNS: no -> resolve (fixes .local under COSMIC).

  * MASK: add systemd-coredump.socket; remove irqbalance.service.

  * _install_fstab_opts: `chmod/chown --reference=/etc/fstab`
    before findmnt --verify; commit=10 appended.

  * log subdirs created under umask 0077 with chmod 700 repair.

  * eight hash pipelines: capture raw line + snapshot
    $pipestatus (empty-stdin SHA mask fix).

  * _ry_namespace_cleanup: HOME preserved; source-exit no longer
    reverts caller HOME.

  * all multi-line # blocks collapsed; fish_indent canonical pass.


v3.51.x - 2026-04-13 -> 2026-04-17
----------------------------------

  * sourcing detection: `status stack-trace | string match -q
    '*from sourcing*'`.

  * _ry_exit: namespace cleanup runs unconditionally.

  * _acquire_lock + keepalive: `%self` -> `$fish_pid`;
    `flock -n -E 5` reclaim before rmdir+mkdir+PID re-verify.

  * _pregenerate_content_files: writes `<safe>.genfail` sentinel
    on generator failure; consumers detect it.

  * boot-wipe marker: stores
    "<count> <sha256-of-sorted-basenames>"; re-prompts on
    basename-set change.

  * _install_aur_packages: paru-missing ->
    INSTALL_HAD_ERRORS=true + return 1 when AUR_PKGS non-empty.

  * _atomic_write_file parent-dir trust: three sudo calls ->
    single `sudo stat -c '%F %u %a'` + `sudo test -L`.

  * _run: RY_RUN_TIMEOUT defaults to 3600 when unset; invalid ->
    one-shot _warn + fallback.

  * _validate_profile: 26 required globals + numeric type-check +
    element sanitization.

  * _install_fstab_opts: _check_sudo_keepalive first; awk strips
    strictatime; five write-path _warn -> _fail.

  * KERNEL_PARAMS: amd_iommu=off -> iommu=pt.


v3.50.x - 2026-04-13
--------------------

  * profile system: external profiles at
    `~/.config/ry-install/profiles/<n>.fish`; resolution via
    `~/.config/ry-install/default-profile` -> gtr9_pro fallback.

  * _validate_profile: 26 required globals + numeric type-check +
    element sanitization.

  * _manifest_check_orphans: warns on files from previous
    install/profile.

  * _acquire_lock: stale-lock reclaim uses `flock -n -E 5` before
    rmdir+mkdir+PID re-verify.


v3.49.0 - 2026-04-12
--------------------

  * drop 61 low-value comment lines.


v3.48.x - 2026-04-08 -> 2026-04-09
----------------------------------

  * TIMESTAMP suffixed with $fish_pid (concurrent-children
    log-file race).

  * SDBOOT_REMOVE_EXISTING=yes requires
    RY_INSTALL_CONFIRM_BOOT_WIPE=1; marker at
    `~/ry-install/.boot-wipe-acknowledged`.

  * source-safe exit: _ry_exit helper + _RY_INSTALL_BAILING +
    _RY_INSTALL_SOURCED + _RY_INSTALL_LAST_EXIT (fixes top-level
    exit killing host shell on source).

  * _atomic_write_file: post-write hash distinguishes sudo lapse
    from fs error.

  * remove --lint mode (~317 L), undocumented
    --restore-power-targets, _ry_count_managed_cases,
    _get_boot_time.

  * ten fish -c workers wrapped with `timeout --kill-after=5 60`.

  * _run: RY_RUN_TIMEOUT regex hardened (rejects 0, leading-zero,
    empty); `</dev/null` added.

  * _dir_group_or_world_writable helper consolidated;
    BOOT_WIPE_MARKER stores entry count.

  * _install_fstab_opts: awk OFS fix; post-rewrite
    findmnt --verify.


v3.x - pre-2026-04-08
---------------------

  * profile/manifest/lock infrastructure, multi-mode CLI
    dispatch, embedded config generators, parallel verify/check
    workers.

  * full per-version detail elided — see git log for individual
    commits.
