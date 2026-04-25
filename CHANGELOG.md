ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first,
entries grouped under a dated heading, each bullet names the
subsystem or function before the change description.


v4.3.1 - 2026-04-25
-------------------

  Audit-driven cleanup release. Eighteen verified findings from the
  v4.3.0 audit addressed plus a follow-up simplification pass adding
  four verifier helpers (_chk_eq, _chk_sysfs_eq, _chk_perms,
  _chk_present) and trimming inline rationale. External contracts
  (CLI, exit codes, JSONL schema, manifest format, boot-wipe marker,
  16 managed destinations, signal handlers, lock semantics)
  preserved. Output byte-identical for verify-static and
  verify-runtime modes.

[fixes]

  * _install_fstab_opts: bare `set _TRACKED_TMPFILES` -> `set -g`.

  * _atomic_write_file: untrack tmpfile after successful mv (cleanup
    loop was stat()-ing dead paths; tracked list grew unbounded).

  * _ensure_sudo_cached: untrack $_sudo_err on both paths after rm.

  * _post_boot: remove `_log_section "INSTALL-FILE END"` writes
    from helper. Caller-context bleed; _ry_do_install_file now
    writes END unconditionally via single-exit refactor.

  * _ry_do_install_file: post-hook dispatch converted to single-exit.

  * _chk_grep: pre-check file existence with `sudo -n test -f` in
    /boot path so missing-file vs missing-key distinguishable.

  * _grep_kv: escape $key with `string escape --style=regex` before
    `string match -qr` interpolation.

  * _ry_do_install_file: drop unreachable `or echo "$dst"` fallback
    on `realpath -m` cmdsubst (realpath -m has no failure mode).

[refactor]

  * verifier helpers: add _chk_eq, _chk_sysfs_eq, _chk_perms,
    _chk_present; sweep prefcore / CPU boost / usbcore.autosuspend
    blocks in _verify_runtime_kparams; collapse perm-check loops
    in _verify_runtime_session; loop-ify static loader.conf,
    resolved, coredump, sdboot KERNEL_PARAMS, mkinitcpio modules.

  * _chk_grep: label arg now optional (defaults to pattern); 23
    existing 3-arg call sites unchanged.

  * comments: 11 redundant pre-function comments removed (paraphrased
    --description); 9 "Pipeline phase N" banners removed; multi-line
    rationale blocks collapsed to single-line form.

[diagnostics]

  * _verify_static_services: surface full LoadState:ActiveState:
    UnitFileState in masked-service FAIL message.

  * _install_fstab_opts: warn when replacing non-default commit=
    value in /etc/fstab.

  * _ry_do_install: "INSTALLATION COMPLETE (WITH WARNINGS)" ->
    "INSTALLATION FINISHED WITH WARNINGS".

[performance]

  * _content__etc_systemd_logind...: cache systemd version in
    _RY_SYSTEMD_VER on first call (was 16 forks per verify-static).

[robustness]

  * cpupower-epp.service: add `ConditionPathExists=/usr/bin/bash`.

  * sudo keepalive: quote `$argv[2]` in `test -d -- "$argv[2]"`.


v4.3.0 - 2026-04-25
-------------------

  Decomposition release: completes the four large-function splits
  scoped in v4.2.0. External contracts preserved; output
  byte-identical to v4.2.1 on the gtr9_pro profile.

[refactor]

  * _install_configure_services: 155 L -> 13-L orchestrator + 3
    helpers (_configure_services_preset, _mask, _enable).

  * _ry_verify_static: 427 L -> 31-L orchestrator + 7 section
    helpers (_verify_static_boot, _system, _user, _packages,
    _services, _syntax, _checksum).

  * _ry_verify_runtime: 818 L -> 30-L orchestrator + 4 section
    helpers (_verify_runtime_kparams, _services, _env, _session).
    sys_units count drift assertion returns 1; orchestrator skips
    env+session helpers on signal.

  * _ry_profile_gtr9_pro: 192 L -> 14-L orchestrator + 8 inline
    helpers grouped by config domain. Single-file inline split
    chosen over external profile-partials to preserve "single Fish
    script, no required external dependencies".

[version]

  * version: 4.2.1 -> 4.3.0.


v4.2.1 - 2026-04-25
-------------------

  Targeted hardening pass; semver patch, no CLI/JSONL changes.

[hygiene]

  * _json_str: extend escape pass from {\\, ", \n} to {\\, ", \n,
    \r, \t}; strip remaining C0 controls (0x00-0x08, 0x0B-0x0C,
    0x0E-0x1F) and DEL (0x7F).

  * argparse + JSONL header: snapshot $argv into _ORIG_ARGV before
    argparse consumes recognized flags.

  * _hash_installed: `echo` -> `printf '%s\n'` for parity.

[robustness]

  * _ry_check_kernel_version: soft-warn for kernels in [6.14,
    6.18.4); 6.18.4 documented as gfx1151 stability floor.

  * _validate_profile: reject empty-string scalar globals for 10
    required globals.

  * _should_skip_iwd: tighten path glob from `*nm.conf` to
    `*/NetworkManager/*nm.conf`.

  * _ry_install_file: route iwd-skip through _should_skip_iwd.

  * _is_wifi_active_route: detect tun/tap/wg/ppp/gre/sit/ip6tnl/
    ipip default-route ifaces; scan /sys/class/net for associated
    802.11 phy.

[version]

  * version: 4.2.0 -> 4.2.1.


v4.2.0 - 2026-04-23
-------------------

  Simplification release: large-function decompositions, sequential
  rewrites of three parallel `fish -c` workers, removal of dead
  defense-in-depth, consolidation of duplicated helpers.

  * BUGFIX: three USER_DESTINATIONS `_content_<key>` declarations
    had `$HOME` in their function names. Fish parse-time variable
    expansion in `function NAME` position interpreted `$HOME_` as
    unset variable; user content generators never defined.
    _tmpfile_key now substitutes `$HOME` -> literal `HOME` before
    slash->underscore pass.

[progress]

  * progress bar: line-rewriting -> stationary bottom-row via
    DECSTBM scroll region (113 L -> ~52 L).

[hygiene]

  * _json_str: 9 byte-class substitutions -> 3 (backslash, quote,
    newline).

  * _banner: 25-L Unicode box-drawing -> 3-L `_echo "── $text ──"`.

  * fish version gate: 3 separate parses -> single regex extract.

  * _ry_exit: drop trailing `and return $C; or return $C` at 26
    sites.

  * _run: drop per-call argv metachar scan.

  * defensive arg-count guards: drop in 11 internal helpers.

  * _TRACKED_TMPFILES: 5 filter-and-reassign loops -> single-line
    `string match -v` forms.

  * argparse: drop deprecated-flag block.

  * sudo keepalive: 2-retry / 1-s-backoff -> single
    `sudo -n -v || break`.

[semantic refactors]

  * _ry_verify_static, _ry_do_check Job 4, _ry_verify_runtime:
    batched `systemctl show` -> per-unit loops. systemd >= 230
    required.

  * _install_fstab_opts: 121 L -> ~85 L. One mktemp, one awk,
    chmod/chown `--reference`, atomic mv.

  * _cleanup, _cleanup_pipe, _cleanup_on_exit: shared body extracted
    to `_teardown mode` helper.

  * _ry_install_files: fold 45-L wrapper into call sites.

  * _ry_do_install_file: 9-branch cascade -> glob->hook table.

  * _ry_get_file_content: 134-L switch -> one `_content_<key>`
    function per destination.

  * _pregenerate_content_files: deleted.

[core rewrites]

  * _ry_do_check: 331 L -> ~96 L. Four `fish -c` children + 7
    serialization tmpfiles -> 5-phase sequential loop.

  * _ry_validate_configs: 262 L -> ~57 L body + 8 helpers. 5
    `fish -c` children -> 3-phase sequential loop.

  * _ry_verify_static CHECKSUM: 197 L -> 22-L sequential
    `for dst` + switch.

  * _atomic_write_file: 232 L -> ~120 L body via `_as use_sudo`
    dispatcher.

  * _validate_profile: 155 L -> ~135 L. New 9-L key-collision
    check via _tmpfile_key + sort -u.

[robustness]

  * _detect_lvm: two-stage probe (sudo pvs, lsblk fallback).

  * sudo discipline: 73 unattended `sudo` invocations -> `sudo -n`
    for fail-fast on cache lapse.

  * NO_COLOR: align with no-color.org spec (set AND non-empty).

[version]

  * version: 4.1.15 -> 4.2.0.


v4.1.15 - 2026-04-22
--------------------

  * _atomic_write_file: parent-dir trust checks added to non-sudo
    branch (symmetric with sudo branch).

  * _ry_verify_runtime: dual stat invocations -> single
    `stat -c '%a %U:%G'` + split at 4 call sites.

  * _ry_install_file: drop redundant `set -l dst $argv[1]` /
    `set -l use_sudo $argv[2]` (--argument-names already creates
    them).

  * _install_fstab_opts: deregister tmpfstab from
    _TRACKED_TMPFILES after atomic mv.

  * version: 4.1.14 -> 4.1.15.


v4.1.14 - 2026-04-21
--------------------

  * _ry_exit: capture _RY_INSTALL_SOURCED into function-local
    _was_sourced before _ry_namespace_cleanup bail.

  * _acquire_lock: flock-less stale reclaim error-checks
    `printf $fish_pid >LOCK_FILE` with rmdir rollback.

  * _ry_verify_static, _install_rebuild_boot:
    `find ... | wc -l` -> `count (find ... -print0 | string split0)`.

  * progress bar: remove dead PROGRESS_STEPS list.


v4.1.13 - 2026-04-21
--------------------

  * profile gtr9_pro SYSCTL_VALUES: + kernel.split_lock_mitigate=0,
    vm.swappiness=100 (count 19 -> 21).

  * profile gtr9_pro ENV_VARS: RADV_EXPERIMENTAL hic token dropped
    (default-on for GFX10.3+); + PROTON_NO_WM_DECORATION=1
    (count 12 -> 13).

  * README: kernel >= 6.14 -> >= 6.18.4 (gfx1151 stability floor);
    fish 3.4+ -> >= 4.0 recommended.


v4.1.12 - 2026-04-21
--------------------

  * boot-wipe marker: `find -printf '%f\n'` -> `-printf '%f\0' |
    sort -z | string split0`. Pre-v4.1.12 markers remain valid.

  * _preflight_boot_sanity: count == 0 guard before initramfs
    non-zero loop (matches vmlinuz check).


v4.1.11 - 2026-04-21
--------------------

  * _ry_get_file_content: rc codes renumbered out of EXIT_* range
    (2 -> 11, 3 -> 12, 4 -> 13).

  * _atomic_write_file: post-write hash _ps -> _hash_ps to avoid
    shadow.


v4.1.10 - 2026-04-21
--------------------

  * _ry_verify_runtime: 9 bare sudo probes -> `sudo -n` for parity.

  * bootstrap: KVER parse failure paths now `rm -f LOG_FILE`
    before _ry_exit.


v4.1.9 - 2026-04-21
-------------------

  * _write_footer, _tmpfile_key, top-level dispatcher: fish_indent
    canonical pass.


v4.1.8 - 2026-04-20
-------------------

  * _install_packages: drop misleading "Synchronizing package
    databases..." _info.

  * _preflight_boot_sanity: 3 find enumerations ->
    `-print0 | string split0`.


v4.1.7 - 2026-04-20
-------------------

  * README: tables trimmed to essential columns.


v4.1.6 - 2026-04-19
-------------------

  * 6 JSONL writers share `2>/dev/null` on append redirects (TOCTOU
    closure on log rotation race).


v4.1.5 - 2026-04-19
-------------------

  * _validate_profile: literal duplicates vs slash->underscore
    collisions report distinct messages.


v4.1.4 - 2026-04-19
-------------------

  * _tmpfile_key: revert sha256 -> `string replace -a '/' '_'`.

  * _validate_profile: tmpfile-key collision guard.

  * _kill_sudo_keepalive: `pkill -TERM -P` reaps descendants.

  * _detect_lvm: timeout 5 -> 10 (slow PAM/NSS first-call).


v4.1.3 - 2026-04-19
-------------------

  * CLI dispatcher: manual while/switch -> `argparse --exclusive`.

  * _ry_verify_static: implicit_svcs derived from
    SYSTEM_DESTINATIONS.

  * _preflight_boot_sanity: BLS path-traversal exact-segment match.


v4.1.2 - 2026-04-19
-------------------

  * _install_preflight: sudo-tag regex hardened
    (`(\bNOEXEC\b|!PASSWD\b|!SETENV\b|\bLOG_OUTPUT\b)`).

  * _install_rebuild_boot: sdboot-manage update failure ->
    EXIT_BOOT_CRIT.

  * unattended -Syu gated behind RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1.

  * _ry_check_deps: flock(1) HARD -> SOFT.


v4.1.1 - 2026-04-19
-------------------

  * _cleanup: handle SIG-prefixed name in $argv[1] (fish 3.4+).
    Exit codes 129/130/131/143 distinguished.


v4.1.0 - 2026-04-19
-------------------

  * remove --test-all (169 L) and --completions (93 L).

  * _ry_show_help: 72 -> 49 lines.


v4.0.x - 2026-04-18 -> 2026-04-19
---------------------------------

  * profile: KERNEL_PARAMS 12 -> 15; SYSCTL_VALUES 21 -> 19;
    PKGS_ADD 15 -> 14; EXPECTED_SERVICES 3 -> 4; + nftables.

  * kernel params: amd_pstate=active; iommu=pt; tsc=reliable;
    loglevel=3.

  * RADV: RADV_EXPERIMENTAL=transfer_queue,hic; RADV_PERFTEST=
    sam,nircache.

  * RESOLVED_MDNS: no -> resolve (.local under COSMIC).

  * MASK: + systemd-coredump.socket; - irqbalance.service.

  * _install_fstab_opts: chmod/chown `--reference=/etc/fstab` before
    findmnt --verify; commit=10 appended.

  * _ry_namespace_cleanup: HOME preserved.


v3.51.x - 2026-04-13 -> 2026-04-17
----------------------------------

  * sourcing detection via `status stack-trace`.

  * _ry_exit: namespace cleanup runs unconditionally.

  * _acquire_lock + keepalive: %self -> $fish_pid; flock reclaim.

  * boot-wipe marker: stores "<count> <sha256-of-sorted-basenames>".

  * _atomic_write_file parent-dir trust: 3 sudo calls -> single
    `sudo stat` + `sudo test -L`.

  * _run: RY_RUN_TIMEOUT defaults to 3600 when unset.

  * _validate_profile: 26 required globals + numeric type-check +
    element sanitization.

  * KERNEL_PARAMS: amd_iommu=off -> iommu=pt.


v3.50.x - 2026-04-13
--------------------

  * profile system: external profiles at
    `~/.config/ry-install/profiles/<n>.fish`.

  * _validate_profile: 26 required globals + type-check.

  * _manifest_check_orphans: warns on previous-install/profile
    files.


v3.49.0 - 2026-04-12
--------------------

  * drop 61 low-value comment lines.


v3.48.x - 2026-04-08 -> 2026-04-09
----------------------------------

  * TIMESTAMP suffixed with $fish_pid.

  * SDBOOT_REMOVE_EXISTING=yes requires
    RY_INSTALL_CONFIRM_BOOT_WIPE=1; marker at
    `~/ry-install/.boot-wipe-acknowledged`.

  * source-safe exit: _ry_exit + _RY_INSTALL_BAILING +
    _RY_INSTALL_SOURCED + _RY_INSTALL_LAST_EXIT.

  * remove --lint mode (~317 L), --restore-power-targets,
    _ry_count_managed_cases, _get_boot_time.

  * 10 `fish -c` workers wrapped with
    `timeout --kill-after=5 60`.

  * _dir_group_or_world_writable helper consolidated.


v3.x - pre-2026-04-08
---------------------

  * profile/manifest/lock infrastructure, multi-mode CLI dispatch,
    embedded config generators, parallel verify/check workers.

  * full per-version detail elided — see git log.
