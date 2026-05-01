ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.5.2 - 2026-05-01
-------------------

  * Bootstrap: snapshot reordered before `_RY_INSTALL_LOADED` set so
    clean exit erases the flag — re-source in same shell now works
    without manual `set -e _RY_INSTALL_LOADED`.
  * Run: `timeout --foreground` so external `kill -TERM <pid>`
    propagates to the running child process group.
  * Run: stderr first 5 lines now mirrored to fd 2 on rc≠0 even when
    `QUIET=true` — unattended-install failures no longer require
    `--verbose` to surface root cause.
  * Run: `_do_cleanup` reaps direct children via `pkill -P` before
    keepalive teardown — closes the RY_RUN_TIMEOUT=0 untimed-branch
    hang where signals to ry-install didn't propagate.
  * Run: TMPDIR-aware path redaction in `_run` (was only matching
    `/tmp/ry-*`).
  * Boot: `_install_rebuild_boot` refuses to run `mkinitcpio -P` when
    `INSTALL_HAD_ERRORS=true`. Override:
    `RY_INSTALL_FORCE_BOOT_REBUILD=1`.
  * Boot: `_check_sudo_keepalive` refresh before `_preflight_boot_sanity`
    finds and the post-rebuild entry-count find — sudo lapse no longer
    masquerades as "No boot entries found".
  * Boot: explicit umask 0177 around boot-wipe marker mktemp.
  * Verify-static: `_verify_static_boot` captures pipestatus on
    LINUX_OPTIONS extraction; missing line surfaces as one warn
    instead of N false-positive KERNEL_PARAMS failures.
  * Verify-static: `_verify_static_user` uses `string split -m1`
    (consistency with `_verify_runtime_env`).
  * Verify-static: `_verify_static_services` masked-services loop
    pre-checks `_unit_state` field count; emits `WARN: systemctl
    unavailable` instead of `FAIL: load= state= file=`.
  * Verify-static: pacman.conf grep drops `-n` (no line-number leak
    into _ok output).
  * Verify-runtime: `_verify_runtime_env` ntsync switch adds `case '*'`
    catchall.
  * Verify-runtime: drop dead `tail -n 1` in env-var extraction.
  * Verify-runtime: hoist `pacman -Qq` cache for Vulkan check (single
    fork replaces N).
  * Validate: `_chk_grep` distinguishes stage-1 sudo/read failure from
    stage-2 grep "not found" via `$pipestatus[1]` inspection.
  * Validate: `_ry_validate_configs` captures `printf|fish --no-execute`
    pipestatus across both stages (printf failure was masked).
  * Validate: `_ry_mkinitcpio_array` warns when multiple non-comment
    `KEY=` lines exist (pacnew artefacts).
  * Fstab: `_install_fstab_opts` adds post-mktemp symlink check before
    chmod (mirror `_atomic_write_file`).
  * Install-file: post-hook dispatch via explicit `switch` on hook tag
    (was dynamic `_post_$_h`).
  * Install-file: launches sudo keepalive when target is in /boot or
    triggers boot rebuild (`/etc/mkinitcpio.conf`, `/etc/sdboot*`,
    `/etc/kernel/cmdline`).
  * Preflight: capture `sudo -n -l` stderr to JSONL; sudoers parse
    errors no longer surface as misleading "requires full sudo".
  * Logging: `_run` redaction list extended with --apikey, --auth,
    --bearer, --cookie, --client-secret, --credential.
  * Logging: dispatcher header redacts argv via same flag list.
  * Logging: track first `_log` write failure; surface
    `[WARN] Log writes failed during this run` at exit.
  * Hygiene: octal validation in `_dir_group_or_world_writable`; log
    rotation uses `-not -samefile "$LOG_FILE"` (was `! -path`); style
    normalised `_install_preflight; or return` (was bare `or` on next
    line).
  * Comments: 6 multi-line `@@AUDIT@@` blocks joined to single line;
    `# lint:ignore`, `@@AUDIT@@`, `@@REVERT@@` markers preserved.
  * Footprint: 4,966 → 5,095 LOC (+2.6%).


v4.5.1 - 2026-05-01
-------------------

  * Preflight: GNU `timeout(1)` now hard-required.
  * Argparse: `--install-file=` rejects empty values.
  * Logging: pre-dispatch `[WARN]` echoes routed through `_warn`.
  * Content fns: `_content__etc_kernel_cmdline` no longer calls
    `_err`; stdout-purity invariant strengthened.


v4.5.0 - 2026-04-30
-------------------

  * Profile: subsystem removed. `gtr9_pro` defaults inlined as
    `set -g` block at module init. Forking is the only path for
    other hardware.
  * Manifest: orphan tracking removed.
  * Bootstrap: `_init_runtime` (63 lines) replaces `_load_profile`.
  * Logging: JSONL event identifiers reduced and renamed.
  * Footprint: 5,335 → 4,941 LOC (-7.4%).

  Migration:
    rm -rf ~/.config/ry-install/profiles
    rm -f  ~/.config/ry-install/default-profile
    rm -f  ~/ry-install/.manifest

  JSONL event renames:
    REMOVED:  PROFILE_DEFAULT, PROFILE_OVERRIDE, MANIFEST_*
    RENAMED:  MANIFEST_SKIP → INSTALL_BAILOUT
              PROFILE_INVALID_SUDO_KEEPALIVE_INTERVAL
                  → INVALID_SUDO_KEEPALIVE_INTERVAL
              PROFILE_INVALID_NM_RESTART_DELAY
                  → INVALID_NM_RESTART_DELAY


v4.4.36 - 2026-04-29
--------------------

  * Bootstrap: fish version gate raised 3.4 → 3.6.
  * Validation: `_chk_grep` strips comment lines; ntsync 5-state
    return; `_ry_check_kernel_version` switches all states.
  * IO: `_installed_bytes` capture-then-emit.
  * AUR: per-package failure returns 1 from `_install_aur_packages`.
  * UX: progress bar `Aborted at N%` on boot-critical skip; SIGWINCH
    re-anchor.


v4.4.34 - 2026-04-29
--------------------

  * Bootstrap: `_RY_INSTALL_LOADED` set before `_RY_PRE_GLOBALS`
    snapshot (reverted in v4.5.2).
  * Boot: `_install_rebuild_boot` `$pipestatus` capture.
  * Validation: `_chk_perms` tolerates double-space stat output.
  * Manifest/Validation: gate `printf >"$tmp"` on exit status.


v4.4.31 - 2026-04-28
--------------------

  * Fstab: pipestatus gate on awk/tee.
  * Cleanup: erase signal handlers before namespace cleanup.
  * Boot: `_resolve_esp` findmnt vfat fallback.
  * Boot: zero-entry guard before `_existing_hash`.
  * Preflight: GNU `sort -z` probe rewritten.
  * Logging: `_write_footer` printf format `%s` → `%d` for numeric
    fields.


v4.4.27 - 2026-04-27
--------------------

  * Helpers: introduce `_pre_dispatch_exit`, `_unit_state`,
    `_check_avail`, `_chk_path_mode_in`, `_chk_token_in`,
    `_chk_sysfs_match`. Replaces 27 duplicated 3-line blocks.
  * `_run`: redaction loop unified via `[ =]\S+` regex.
  * Lines: 5,282 → 5,197 (-85).


v4.4.0..v4.4.26 - 2026-04-25..04-27
-----------------------------------

  * Profile system + verify split (`--verify-static` /
    `--verify-runtime` / `--check`).
  * Locking: mkdir mutex + `flock(1)` stale reclaim.
  * Sudo keepalive: TERM → sleep → KILL teardown.
  * Tmpfile + sudo-cache idempotency hardening; ESP cache.


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256
    verification.


v4.2.x..v4.0.x - 2026-04-18..04-25
----------------------------------

  * Initial fish rewrite from v3.x bash.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
