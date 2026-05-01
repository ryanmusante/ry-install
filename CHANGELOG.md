ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.5.1 - 2026-05-01
-------------------

  * Preflight: GNU coreutils `timeout(1)` now required; `_run` no
    longer falls through silently to an untimed exec.
  * Argparse: `--install-file=` rejects empty values explicitly.
  * Logging: pre-dispatch `[WARN]` echoes routed through `_warn`
    so they reach the JSONL log.
  * Content fns: `_content__etc_kernel_cmdline` no longer calls
    `_err`; stdout-pure invariant strengthened (callers may run
    dispatchers under `2>/dev/null`).


v4.5.0 - 2026-04-30
-------------------

  * Profile: subsystem removed. `gtr9_pro` defaults inlined as
    `set -g` block at module init. Forking is the only path for
    other hardware.
  * Manifest: orphan tracking removed; `~/ry-install/.manifest`
    deleted.
  * Bootstrap: `_init_runtime` (63 lines) replaces `_load_profile`;
    salvages root-UUID cache, CPU-match warn, timing-global
    validation, tmp-dir precompute.
  * Validation: `MANAGED_FILE_COUNT` drift warn dropped;
    `_RY_MANAGED_FILE_COUNT` is sole authoritative count.
  * Help: tagline reads full `PROFILE_DESC` instead of truncated
    fallback.
  * Logging: JSONL event identifiers reduced and renamed.
  * Docs: README ## Profiles removed; ## Customization added.
  * Footprint: 5,335 → 4,941 LOC (-7.4%); 210k → 195k bytes.

  Migration:
    rm -rf ~/.config/ry-install/profiles
    rm -f  ~/.config/ry-install/default-profile
    rm -f  ~/ry-install/.manifest
  Custom external profile users: fork the script and edit the
  inlined defaults block.

  JSONL event renames (external consumers):
    REMOVED:  PROFILE_DEFAULT, PROFILE_OVERRIDE,
              MANIFEST_CHMOD_FAIL, MANIFEST_WRITTEN,
              MANIFEST_WRITE_FAILED
    RENAMED:  MANIFEST_SKIP                          → INSTALL_BAILOUT
              PROFILE_INVALID_SUDO_KEEPALIVE_INTERVAL
                                                     → INVALID_SUDO_KEEPALIVE_INTERVAL
              PROFILE_INVALID_NM_RESTART_DELAY       → INVALID_NM_RESTART_DELAY


v4.4.36 - 2026-04-29
--------------------

  * Bootstrap: fish version gate raised 3.4 → 3.6 (slice `[N..]`,
    `string match -rg`, post-pipeline `$pipestatus` capture).
  * Validation: `_chk_grep` strips comment lines; `-qwF` for plain
    tokens vs `-qF` for k=v; `$pipestatus[2]` preserves 3-state.
  * Validation: `_ry_check_kernel_version` switches all five
    `_ntsync_state` returns; `loaded_nodev` and `missing` no longer
    `_ok` on capable kernels.
  * IO: `_installed_bytes` capture-then-emit (mirrors
    `_content_bytes` v4.4.29); no more truncated mid-read emits.
  * AUR: `_install_aur_packages` returns 1 on per-package failure
    after batch retry, not just no-paru path.
  * UX: progress bar renders `Aborted at N%` on boot-critical skip
    via `_PROG_FINALIZED_SKIP`.
  * UX: `_progress_on_winch` SIGWINCH handler re-anchors pinned
    bar after terminal resize.
  * Validation: profile-name regex caps length at 64; rejects
    leading `_`.
  * Boot: `_progress_done` log line adds `skip=` field.
  * Validation: `systemd-analyze` boot-time regex tightened to
    `^\d+(\.\d+)?$`.
  * Hygiene: `_pre_dispatch_log_cleanup` uses bounded 3-level
    rmdir chain.
  * Docs: README Prerequisites table simplified.


v4.4.34 - 2026-04-29
--------------------

  * Bootstrap: `_RY_INSTALL_LOADED` set before `_RY_PRE_GLOBALS`
    snapshot so namespace_cleanup preserves it as caller-API state.
  * Boot: `_install_rebuild_boot` captures `$pipestatus` into
    `_pre_ps` immediately after find/sort/split0 cmdsub.
  * Validation: `_chk_perms` uses `string split -n ' '`; tolerates
    double-space stat output.
  * Manifest: `_manifest_write` gates `printf >"$tmp"` on exit
    status; failure path removes tmpfile, untracks, warns.
  * Validation: `_verify_unit_content` gates `printf >"$tmp"` on
    exit status.
  * Comments: 13 truncated mid-sentence comments completed.


v4.4.33 - 2026-04-29
--------------------

  * Profile: `SYSTEM_DESTINATIONS` quoting normalised
    (12/12 double-quoted).


v4.4.32 - 2026-04-28
--------------------

  * Header: top-of-file module-state note collapsed 12 → 4 lines.
  * Comments: 5 truncated mid-sentence comments completed.
  * Docs: README Safety & Reliability trimmed 107 → 95 lines;
    Log Format event table folded 16 → 6 categorical groupings;
    inner `Environment Variables` renamed to `Runtime Variables`
    to resolve heading collision.


v4.4.31 - 2026-04-28
--------------------

  * Fstab: `_install_fstab_opts` awk/tee gates on
    `$pipestatus[1]` and `$pipestatus[2]`.
  * Cleanup: `_ry_exit` erases signal handlers before
    `_ry_namespace_cleanup bail`; closes SIGINT re-entry window.
  * Boot: `_resolve_esp` falls back to `findmnt -no FSTYPE` vfat
    over `/efi`, `/boot/efi`, `/boot`.
  * Boot: `_install_rebuild_boot` zero-entry guard before
    `_existing_hash`.
  * Preflight: GNU `sort -z` probe rewritten to feed two
    NUL-separated tokens out of order.
  * Profile: `_load_profile` mode regex accepts 4-digit modes.
  * Logging: `_write_footer` printf format `%s` → `%d` for
    numeric fields.


v4.4.30 - 2026-04-28
--------------------

  * Validation: `_check_env_ssh_auth_sock` fails deploy on
    `_RY_SYSTEMD_VER < 232` (was warn-only).
  * Dispatch: `_tmpfile_key` `$HOME → HOME` substitution
    anchored; trailing-slash and prefix-match cases fixed.
  * Logging: 6 narrative `_log` calls normalised to KEY-style
    events for JSONL parseability.


v4.4.29 - 2026-04-28
--------------------

  * Bootstrap: KVER parse failures call `_ry_exit`, not
    `_pre_dispatch_exit` (forward-ref bug).
  * Logging: `_json_str` rewritten in argument-mode `string
    replace`; embedded newlines now valid JSONL.
  * Sysctl: `_content__etc_sysctl.d_99-cachyos-sysctl.conf`
    skip-guards malformed entries.


v4.4.28 - 2026-04-27
--------------------

  * Dispatch: bail-guard polled after every pre-dispatch exit
    site; source-mode no longer falls through.
  * Dispatch: post-pre-dispatch bail writes
    `footer interrupted` JSONL.
  * Bootstrap: `NO_COLOR` and fish-version gates flattened.


v4.4.27 - 2026-04-27
--------------------

  * Helpers: introduce `_pre_dispatch_exit`,
    `_pre_dispatch_log_cleanup`, `_unit_state`, `_check_avail`,
    `_chk_path_mode_in`, `_chk_token_in`, `_chk_sysfs_match`.
    Replaces 27 duplicated 3-line blocks.
  * `_run`: redaction loop unified via `[ =]\S+` regex.
  * `_acquire_lock`: drop redundant `rm -f` before
    `find -delete` in stale-reclaim sh script.
  * Verify: amd_pstate / nmi_watchdog / zswap inline blocks
    routed through new `_chk_sysfs_*` helpers.
  * Lines: 5,282 → 5,197 (-85).


v4.4.26 - 2026-04-27
--------------------

  * Verify: `_verify_static_system` mirrors generator's
    systemd<256 `HandleSecureAttentionKey` skip.
  * Tmpfile: `_atomic_write_file` and `_install_fstab_opts`
    untrack on every failure path.
  * Sudo cache: `_ensure_sudo_cached` cleanup gates `rm` on
    `/dev/null` mktemp-fail sentinel.
  * Cleanup: `_do_cleanup` erases `_RY_ESP_PATH` and
    `_RY_SYSTEMD_VER` memoization.


v4.4.25 - 2026-04-27
--------------------

  * Boot: `_resolve_esp` cache; `/boot/loader/entries`
    hardcoded sites replaced; wipe-marker refuses 0-count
    writes.
  * Logging: `_log` parallel-child guard via
    `_RY_LOG_OWNER_PID`.
  * Profile: metachar sanitiser extended to MASK,
    EXPECTED_SERVICES, EXPECTED_VULKAN_PKGS, PKGS_*, AUR_PKGS;
    ENV_VARS rejects SSH_AUTH_SOCK collisions.
  * Deps: GNU `find -printf` and `df --output` preflight probes
    added; required-cmd list widened.
  * Verify: dmesg captured once and reused for TSC + ReBAR;
    `_chk_grep` distinguishes rc=2 from rc=1.


v4.4.24 - 2026-04-26
--------------------

  * Strings: revert L1310, fix L1461. v4.4.23 misdiagnosis;
    actual closer-eating bug was `'\\'` vs grammar's
    left-biased `\\'|\\` regex. fish-vs-grammar span
    divergence: 86 → 0.


v4.4.18..v4.4.23 - 2026-04-26
-----------------------------

  * Comment hygiene + fish-tmbundle grammar tripwire pass.
    v4.4.23 misdiagnosis reverted in v4.4.24.


v4.4.8..v4.4.17 - 2026-04-26
----------------------------

  * Signal-handler, exit-path, namespace-cleanup re-entry
    guards. `_content_bytes` round-trip byte-equal terminator.


v4.4.0..v4.4.7 - 2026-04-25..2026-04-26
---------------------------------------

  * Profile: `$HOME/.config/ry-install/profiles/<name>.fish`.
  * Verify split: `--verify-static` / `--verify-runtime` /
    `--check`.
  * Locking: mkdir mutex + `flock(1)` stale reclaim.
  * Sudo keepalive: TERM → sleep → KILL teardown.


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256
    verification. cpupower-epp.service printf-truncation fix.


v4.2.x..v4.0.x - 2026-04-18..2026-04-25
---------------------------------------

  * Initial fish rewrite from v3.x bash. Single-file
    architecture, embedded generators, manifest-driven install,
    argparse CLI.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
