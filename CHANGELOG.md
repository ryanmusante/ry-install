ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v4.5.13 - 2026-05-03
--------------------

  * Packages: pacman flags follow Arch's no-partial-upgrade
    policy by default — `-Syu --needed` when installing.
    Opt-in escape hatch `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1`
    switches to `-Sy --needed` with a partial-upgrade
    warning. Legacy `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE`
    removed (was unreachable when PKGS_ADD was non-empty).
  * Boot: `_install_rebuild_boot` no longer carries a
    standalone `-Syu` site; Packages phase is sole upgrade
    location.
  * Bug: `_RY_BOOT_PIPE_OK=false` (find/sort/split0 stage
    failure) returns EXIT_PREFLIGHT instead of proceeding
    with phantom 0-count, mirroring the v4.5.10 ERR_NO_DATA
    pattern.
  * Bug: `_atomic_write_file` switched to `|`-delimited
    `stat -c` format; `%F` is two-word for non-directories
    and space-splitting shifted uid/mode parts.
  * Verify: IWD DriverQuirks (`_verify_static_system`) and
    ENV_VARS (`_verify_static_user`) checks compare full
    `key=value` (was: key/name only).
  * Verify: `rw` token verified in `_grep_kparam`,
    `_verify_static_boot`, `_verify_runtime_kparams`, and
    `_ry_do_check` Phase 3. Cmdline byte-content unchanged.
  * Bootstrap: HOME validity check re-resolves on
    set-but-invalid (non-empty, not-a-directory) too. Fish
    version regex captures patch (`\d+\.\d+(\.\d+)?`).
  * UX: sdboot-manage-gen failure path uses single `_err`
    (was `_warn`+`_err`); `_configure_services_enable`
    distinguishes NM-dispatcher `is-enabled` empty (unit
    not installed) from "disabled".
  * Glob: `_ry_do_install_file` post-hook and keepalive
    trigger tightened `/etc/sdboot*` → `/etc/sdboot-manage*`.
  * Comments: `_unit_state` docstring corrected.
    Multi-line block comments collapsed to single-line.
  * Help: `-V, --verbose` clarified — only install/check
    default silent.
  * Doc: README §Packages / §Runtime Variables / §Install
    Flow / §Kernel Parameters updated.
  * Repo: ship LICENSE.
  * Footprint: 5,242 → 5,262 LOC. No public-API or JSONL
    schema changes; the EXIT_PREFLIGHT (3) on
    `_RY_BOOT_PIPE_OK=false` path is a semantic correction.

  Migration: default `./ry-install.fish` invocation now
  runs `pacman -Syu --needed` during the Packages phase.
  Set `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` for install-only
  behaviour.


v4.5.12 - 2026-05-03
--------------------

  * Style: normalize bare → `command` for `grep`,
    `stat`, `sed`, `realpath` at all coreutils call
    sites. Codebase convention is `command X` (per
    find/cat/head/awk: 9/25/8/7 × command, 0 bare each);
    19 grep + 4 stat + 3 realpath + 1 sed sites brought
    in line. PATH is pinned at L94 so no functional
    change.
  * Style: bootstrap stderr at L150 now uses `[ERR]`
    prefix matching the other 14 bootstrap stderr emits
    (was `Error:`).
  * Footprint: 5,242 LOC unchanged. No public-API,
    JSONL schema, or exit-code semantic changes.


v4.5.11 - 2026-05-03
--------------------

  * Tuning: drop 5 sysctl entries from SYSCTL_VALUES —
    `vm.swappiness=100`, `kernel.split_lock_mitigate=0`,
    `net.core.busy_read=50`, `net.core.busy_poll=50`,
    `net.core.netdev_budget=600`. Vendor defaults
    (CachyOS 70-cachyos-settings.conf or kernel) now
    apply for those keys. SYSCTL_VALUES count: 21 → 16.
  * Doc: README §System Tuning row updated (drop
    split-lock-suppression mention, 21 → 16 tunables).


v4.5.10 - 2026-05-03
--------------------

  * Bug: `_ry_check_deps` aborted preflight on missing
    paru, contradicting the README §Packages soft-fail
    contract. Now `_warn` + `_info`; `_install_aur_packages`
    handles the actual rc=1 + INSTALL_HAD_ERRORS.
  * Bug: `_ry_do_check` masked + implicit service loops
    used raw `_unit_state` (v4.5.9 retrofitted padded
    helper at 2 of 4 sites only). ERR_NO_DATA now
    returns EXIT_PREFLIGHT, not silent drift.
  * Bug: `_ry_do_check` Phase 4 expected-services still
    mapped ERR_NO_DATA to drift after the v4.5.9 sentinel
    fix. Now EXIT_PREFLIGHT, consistent with masked +
    implicit.
  * Bug: `_ry_do_check` Phase 5 ssh-agent treated empty
    `systemctl --user is-enabled` output as drift. Empty
    = no user-bus session (cron/sudo-shell/headless);
    now EXIT_PREFLIGHT.
  * Bug: `_ry_do_check` Phase 2 conflated generator
    failure (empty `expected`, rc=11/12) with drift.
    Now EXIT_PREFLIGHT, mirrors `_verify_static_checksum`.
  * Reliability: `_ry_do_check` Phase 1 probes `command -q
    systemctl`. Closes the trigger surface for unit-state
    drift coercion.
  * Reliability: `_SYS_TMP_DIRS`, `_USR_TMP_DIRS`,
    `_PROFILE_USES_NM` initialized at top-of-file so
    signal handlers firing pre-`_init_runtime` are
    well-defined.
  * UX: `_install_preflight` no longer emits a redundant
    `_warn` after `_ry_check_kernel_version` already
    emitted `_fail` + `_info`. INSTALL_HAD_ERRORS still
    set, gate behaviour unchanged.
  * Refactor: `_content_bytes` terminal `string collect`
    carries `--allow-empty`, matching `_installed_bytes`
    + `_json_str`.
  * Footprint: 5,221 → 5,247 LOC (+26). No public-API,
    JSONL schema, or exit-code semantic changes;
    EXIT_DRIFT (10) → EXIT_PREFLIGHT (3) on
    previously-misclassified `--check` paths is a
    semantic correction.


v4.5.9 - 2026-05-03
-------------------

  * Bug: secret-flag redaction in `_run` and the dispatch
    header logger emitted fish "Invalid index value"
    runtime errors on every invocation. The pattern
    `"$flag[ =]\S+"` was parsed by fish as a variable
    index expression on `$flag`, causing the regex
    expansion to abort and the redaction to silently
    fail. Close-quote the variable expansion before the
    bracket: `"$flag""[ =]\S+"`. Each affected site was
    emitting 15 stderr errors per call (one per
    `_RY_SECRET_FLAGS` entry).
  * Bug: dispatch-header `argv` field corrupted any
    argv element containing a space (e.g.
    `--install-file '/path with space'`) — the
    join-then-space-split round-trip turned a 2-element
    sequence into 5 tokens. Replaced with a per-element
    redact loop that preserves spaces and handles both
    `--flag=value` and `--flag value` forms without
    regex.
  * Reliability: `_unit_state_padded` helper returns
    `ERR_NO_DATA` sentinels when systemctl produces
    fewer than 3 fields, so `_ry_do_check` Phase 4 and
    `_verify_runtime_services` no longer silently
    coerce missing output to empty drift markers.
    Retro-fitted at the two previously unguarded call
    sites; `_verify_static_services` already had its
    own inline sentinel.
  * Reliability: stale-lock detection cross-checks
    `/proc/<old_pid>/comm` against `fish` before
    refusing to start. Reduces false-positive "Another
    instance running" when the OS has reused the PID.
    PID alive but not fish → falls through to the
    flock-protected reclaim path.
  * Refactor: extract `_start_sudo_keepalive` helper.
    Replaces two 16-line copies in `_install_preflight`
    and `_ry_do_install_file`. Helper centralizes the
    `kill -0` + `disown` post-launch handshake.
  * Refactor: `_pre_dispatch_exit` now delegates to
    `_pre_dispatch_log_cleanup` + `_ry_exit` instead of
    re-implementing the cleanup body. Cuts a 9-line
    duplicate of the rmdir chain.
  * Comments: collapse the two-line KERNEL_PARAMS
    verify-regex note above `set -g KERNEL_PARAMS` into
    a single line. Same content, one line less.
  * Doc: README sample-log header bumped to current
    version.
  * Footprint: 5,205 → 5,221 LOC (+16, +0.3%). No
    public-API, JSONL schema, or exit-code semantic
    changes.


v4.5.8 - 2026-05-02
-------------------

  * Refactor: extract `_rm_tmp` helper (sudo-aware tmpfile
    delete + `_TRACKED_TMPFILES` untrack) and `_is_symlink`
    helper (sudo-aware `test -L`). Replaces 27 instances of
    the 2-line `(sudo -n|command) rm -f -- "$X" 2>/dev/null
    / _untrack_tmpfile "$X"` pattern across
    `_atomic_write_file`, `_ensure_sudo_cached`,
    `_verify_unit_content`, `_ry_validate_configs`,
    `_install_preflight`, `_install_packages` (mkinitcpio
    rollback), `_install_fstab_opts`, `_install_finalize`
    (boot-wipe marker), and `_early_usage_exit` /
    post-argparse cleanup. `_atomic_write_file`
    additionally drops 2 sudo-vs-no-sudo `if test -L`
    branch pairs into single `_is_symlink` calls.
    Behaviour-preserving — every failure path still
    rm + untracks via the helper.
  * Refactor: extract `_enum_boot_entries` helper that
    enumerates `$esp/loader/entries/*.conf` and exports
    `_RY_BOOT_COUNT` / `_RY_BOOT_HASH` / `_RY_BOOT_PIPE_OK`.
    Replaces the 14-line `find | sort -z | split0 +
    pipestatus + count + hash` block duplicated between
    `_install_rebuild_boot` precheck and `_install_finalize`
    marker write. Helper globals are auto-cleared by
    `_ry_namespace_cleanup` (set after `_RY_PRE_GLOBALS`
    snapshot).
  * Comments: drop the two redundant
    `# was _pre_dispatch_exit; forward-ref bug` notes
    above the kernel-version-parse `_ry_exit` calls. The
    code itself is final; the historical note no longer
    aids maintenance.
  * Comments: restore the v4.5.4 KERNEL_PARAMS verify-regex
    constraint note (`# One-value-per-entry — verify regex
    requires whole-token match`) above `set -g
    KERNEL_PARAMS`. The note was promised by the v4.5.4
    changelog but appears to have been collateral in
    v4.5.5's review-marker cleanup. The constraint itself
    was always real (verify regex is `(^|\s)$param(\s|\$)`)
    — only the doc was missing.
  * Footprint: 5,240 → 5,205 LOC (-35, -0.7%). No
    public-API, JSONL schema, or exit-code semantic changes.


v4.5.7 - 2026-05-02
-------------------

  * Boot: mkinitcpio rollback (`_install_packages` failure
    path) now gates `chmod 644` and `chown root:root` on
    explicit success checks. Prior code dropped both errors
    via `2>/dev/null` with no rc check; on a sudo-cred lapse
    between the `tee` and `chmod`, `mv` would proceed with
    mktemp's default `0600` perms or wrong owner, surfacing
    later as a spurious `verify-static` mismatch. New path
    routes both failures to `MKINITCPIO_REVERT_FAIL` with
    distinct log markers (`chmod failed`, `chown failed`).
  * Logging: `_pre_dispatch_log_cleanup` and
    `_pre_dispatch_exit` now preserve `LOG_FILE` when the
    dispatch JSONL header was already written. New global
    `_RY_HEADER_WRITTEN=true` is set immediately after the
    header `printf` succeeds. Lock-conflict diagnostics
    (`_acquire_lock` failure after header write) no longer
    silently delete the log artifact.
  * Verify: `_verify_unit_content` drops GNU-only
    `mktemp --suffix=.service`. Replaced with
    `mktemp -t ry-val-unit.XXXXXX` plus an explicit
    `mv -- "$tmp_raw" "$tmp_raw.service"`, restoring
    portability to `mktemp` builds without coreutils
    extensions. systemd-analyze still receives a path with
    the `.service` suffix it requires for unit-type
    detection.
  * Verify: dispatch-fall-through case bodies in
    `_ry_validate_configs` (`*/mkinitcpio.conf`,
    `*/environment.d/*`) now carry inline comments naming
    the alternate validators (Phase 1
    `_ry_validate_mkinitcpio_*`, Phase 3
    `_check_env_ssh_auth_sock`). No behavior change —
    visual signal that the empty body is intentional.
  * Refactor: 7 `string match -qr -- "$pattern" -- "$value"`
    sites trimmed to `string match -qr -- "$pattern"
    "$value"`. The redundant second `--` was consumed as an
    additional STRING argument (multi-string match
    semantics); always-non-matching against the patterns in
    use. Single source of truth for the option terminator
    eliminates a future-bug surface if any pattern were
    ever revised to accept `--` as input.
  * Preflight: `_install_preflight` `sudo -n -l` parser
    standardised to `^[[:space:]]*#` POSIX class. Prior
    `^\s*#` relied on GNU grep's PCRE-style extension; on
    busybox/BSD grep this matched a literal `s`, allowing
    sudoers comment lines to leak into the NOPASSWD scan.
    CachyOS ships GNU grep so behaviour was correct on
    target; the change closes a portability landmine.
  * Dispatch: `case install-file` now carries the standard
    `test "$_RY_INSTALL_BAILING" = true; and return
    $_RY_INSTALL_LAST_EXIT` guard between
    `_pre_dispatch_exit $EXIT_USAGE` (empty-target branch)
    and `_acquire_lock`. Branch is unreachable in normal
    flow (argparse `install-file=` rejects empty values);
    consistency with the 14 other top-level exit sites
    avoids future-edit drift.
  * Footprint: 5,215 → 5,240 LOC (+0.5%). No public-API,
    JSONL schema, or exit-code semantic changes.

  Migration: none. Behaviour-preserving fixes; users who
  hit the lock-conflict path will newly retain a log
  artifact with the dispatch header.


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
