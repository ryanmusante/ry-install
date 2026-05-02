ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.5.6 - 2026-05-02
-------------------

  * Sudoers: `_install_preflight` NOPASSWD regex relaxed to
    accept the no-space `NOPASSWD:ALL` form and the `(root)`
    runas alternative. Sudoers entries that are semantically
    valid for unattended install no longer trigger spurious
    `EXIT_PREFLIGHT`.
  * Logging: dispatch-header argv redaction now mirrors
    `_run` — joins `(status filename) $_ORIG_ARGV`, applies
    `(^| )$flag[ =]\S+` PCRE globally, re-splits for the
    JSON array. The `--token sekret` next-positional form is
    redacted at the header (was: `--token=sekret` only).
  * Boot: `$PATH` pinned to
    `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`
    immediately after the fish-version gate. A user with a
    shadow `~/.local/bin/sudo`, `pacman`, or `bootctl` no
    longer runs the shadow.
  * Boot: mkinitcpio rollback (`_install_packages` failure
    path) captures `printf | sudo -n tee` `$pipestatus`. A
    `printf` failure routes to the existing
    `MKINITCPIO_REVERT_FAIL` path (pipestatus surfaced)
    instead of leaving an empty `_mki_tmp` staged for
    atomic mv.
  * Verify/Install: `_verify_runtime_env` and
    `_install_fstab_opts` precheck `/etc/fstab` readability.
    Site policy that hardens fstab to `0600 root` no longer
    fails silently through `command awk … 2>/dev/null` —
    verify path `_warn`s and skips, install path `_fail`s.
  * `_run`: `command timeout … "$_run_timeout" -- $argv`
    and the untimed-fallback `command -- $argv` carry an
    explicit `--` separator. `_as` propagates the same
    through `sudo -n -- $argv[2..-1]` and
    `command -- $argv[2..-1]`.
  * Externals: `command` prefix added at five preflight
    cmdsubst sites: `zcat /proc/config.gz` (no `--`, gzip
    variant compat), `cat /proc/cmdline`, the sort-z
    `tr | grep` pipeline, two `grep -q --` config-symbol
    probes. Resilient against caller-shadow regressions in
    the bootstrap path.
  * Refactor: dispatch-mode setters (`_flag_verify_static`,
    `_flag_verify_runtime`, `_flag_check`,
    `_flag_install_file`) declare `set -g MODE` explicitly
    (was bare `set MODE`, functionally equivalent).
    `_content_*` printf args for sdboot-manage, mkinitcpio,
    and NetworkManager split via `\` continuation
    (392/289/228-char single-line forms → ≤80 each). The
    EPP-performance service generator's `ExecStart=` arg is
    intentionally not split — single-quoted bash one-liner
    cannot be safely line-broken.
  * Refactor: `RY_INSTALL_CONFIRM_*` literal-1 checks
    standardised to bare `test "$VAR" = 1` form across
    `_install_rebuild_boot`. Three sites, semantics
    preserved — fish `test` treats unset vars as empty.
  * Comments: docstring above
    `_content_HOME_.config_fish_conf.d_10-ssh-auth-sock.fish`
    documents the literal `'end'` printf-arg
    (`# WARNING: do not run fish_indent -w`); `_cleanup`
    carries an explicit USR1/USR2/ABRT routing note (route
    via `fish_exit` fallback).
  * Docs: README **Codes** table row for `2` clarified to
    cover argparse failures **and** policy refusals
    (root-refusal exits `EXIT_USAGE`); README
    **Runtime Variables** section gains a secret-flag
    redaction note documenting the lowercase-only match and
    the new `--flag value` form catch.
  * Footprint: 5,175 → 5,215 LOC (+0.8%). No public-API,
    JSONL schema, or exit-code semantic changes.

  Migration: none. Sudoers entries that previously failed
  preflight (no-space `NOPASSWD:ALL`, `(root)` runas) now
  pass as intended.


v4.5.5 - 2026-05-02
-------------------

  * Comments: in-line review markers stripped (mirrors
    v4.5.2 release-cleanup pass). Single-line annotation
    invariant retained; `# lint:ignore` and the script
    header preserved.
  * Defaults: dead `# inlined from _ry_profile_gtr9_pro_*`
    provenance line dropped — `_ry_profile_*` was removed in
    v4.5.0; the GTR9_PRO banner remains intact for the README
    customization reference.
  * Footprint: 5,201 → 5,175 LOC (-0.5%); no public-API,
    behavioural, or JSONL schema changes.

  Migration: none.


v4.5.4 - 2026-05-02
-------------------

  * Packages: `_install_packages` captures pre-deploy
    mkinitcpio.conf bytes; on `pacman -Syu` failure the prior
    content is restored via atomic mv so the system isn't left
    with a new conf referencing modules from packages that
    didn't install. `_mki_tmp` written inside `/etc` passes
    through the same post-mktemp symlink check used by
    `_atomic_write_file`. If sudo lapsed before the snapshot,
    `MKINITCPIO_BACKUP_SKIPPED` is logged so a later rollback
    no-op is traceable.
  * Install: `_ry_install_file` tracks file-read success
    separately from empty content, so a sudo lapse / EIO /
    transient FS error reading the existing file no longer
    gets conflated with "current is empty" and silently
    redeployed without surfacing the read failure.
  * Logging: `_log` recreates LOG_FILE if disappeared mid-run
    (rotation race, external rm, dispatch rename failure)
    instead of silently dropping events. Complementary to
    v4.5.2's `_RY_LOG_WRITE_FAIL` tracker.
  * Logging: rotation pipeline (`find→sort→split0`) now
    pipestatus-gated; a stage failure logs `LOG_ROTATION_SKIP`
    instead of acting on partial enumeration.
  * Logging: `_json_str` adds an ASCII-clean fast path; common
    JSONL fields (event names, integer counts, plain
    identifiers) skip the 5-stage replace pipeline.
  * Validate: `_ry_validate_configs` *.fish branch captures
    fish's stderr to a tracked tmpfile and surfaces the first
    5 lines as `_info` context plus a `VALIDATE_FISH_STDERR`
    JSONL event; syntax errors no longer fail with no
    diagnostic.
  * Boot: `RY_INSTALL_FORCE_BOOT_REBUILD` env var checked for
    literal value `=1` (was `set -q` accepting any value).
    Aligns with `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE` semantics
    and README docs.
  * Progress: pinned bar skipped under `screen` (STY env or
    `TERM=screen*`) in addition to tmux. Serial / dumb-term
    coverage was already provided by the existing `tput lines`
    non-numeric guard.
  * Verify: KERNEL_PARAMS comment added near inlined defaults
    documenting that comma-separated multi-values aren't
    supported by the verify regex (one-value-per-entry
    constraint).
  * Refactor: credential redaction list hoisted to a single
    `_RY_SECRET_FLAGS` global; was duplicated at `_run` and
    the dispatch-header argv sites. New flags now require one
    edit.
  * Refactor: `_RY_MANAGED_FILE_COUNT` derived from
    destinations lists at runtime; was hardcoded `15`
    requiring hand-sync.
  * Help: `_ry_show_help` ENVIRONMENT block adds
    `RY_INSTALL_FORCE_BOOT_REBUILD` (was undocumented in
    `--help` even though README covered it). Help log path
    corrected to `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl` (was
    missing `-PID` suffix).
  * Comments: rationale annotations added for
    `_ry_get_file_content` return-11 sentinel,
    `_cleanup` signal-handler bare echo (signal-safety), and
    post-footer warn echo (post-footer invariant). Multi-line
    annotations stored on a single line; in-line review
    markers preserved.
  * Footprint: 5,090 → 5,201 LOC (+2.2%); no public-API or
    JSONL schema changes.

  Migration: none. The mkinitcpio.conf rollback is automatic.

  Note: v4.5.3 was skipped due to regressions across credential
  redaction, log-write-failure tracking, SIGKILL escalation in
  cleanup, octal pre-validation, pacnew warn, log rotation
  exclusion, and README accuracy. v4.5.4 selectively backports
  the v4.5.3 fixes that did not introduce regressions.


v4.5.2 - 2026-05-01
-------------------

  * Bootstrap: snapshot reordered before `_RY_INSTALL_LOADED` set —
    re-source in same shell now works.
  * Run: `timeout --foreground` for parent→child signal propagation;
    first 5 stderr lines mirrored on rc≠0 under `QUIET`; `pkill -P`
    child reap before keepalive teardown; TMPDIR-aware path redaction.
  * Boot: `mkinitcpio -P` gated on `INSTALL_HAD_ERRORS=false`
    (override `RY_INSTALL_FORCE_BOOT_REBUILD=1`); sudo keepalive
    refresh around boot-sanity / entry-count finds; umask 0177
    around boot-wipe marker mktemp.
  * Verify: pipestatus on LINUX_OPTIONS extraction; masked-services
    field-count pre-check; ntsync `case '*'` catchall; hoisted
    `pacman -Qq` cache for Vulkan check.
  * Validate: `_chk_grep` distinguishes stage-1 sudo/read failure
    from stage-2 grep "not found"; pipestatus across printf /
    `fish --no-execute` stages; mkinitcpio-array warns on duplicate
    `KEY=` lines.
  * Fstab: `_install_fstab_opts` adds post-mktemp symlink check
    (mirror `_atomic_write_file`).
  * Install-file: explicit `switch` hook dispatch; sudo keepalive
    when target writes to /boot or triggers boot rebuild.
  * Preflight: `sudo -n -l` stderr captured to JSONL — sudoers parse
    errors no longer surface as "requires full sudo".
  * Logging: redaction extended (`--apikey`, `--auth`, `--bearer`,
    `--cookie`, `--client-secret`, `--credential`); dispatcher header
    argv redacted; first `_log` write failure surfaced at exit.
  * Comments: multi-line blocks folded to single line; in-line
    review markers stripped; `# lint:ignore` preserved.
  * Footprint: 4,966 → 5,090 LOC (+2.5%).


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
