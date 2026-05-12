ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v5.0.31 - 2026-05-12
--------------------

  * preflight/uid: `_MY_UID` now validated as `^\d+$` immediately after
    `id -u`. A silent NSS lapse or broken `id(1)` returning an empty
    string previously propagated to `getent passwd $_MY_UID` (returns
    all entries) and `test "$_MY_UID" -eq 0` (emits
    `test: argument expected`). Refuses with `EXIT_PREFLIGHT` on
    non-numeric value.
  * preflight/root-uuid: `_ir_resolve_root_uuid` inline-chain refactored
    to an explicit `if` block. The previous `test -n ; and not match ;
    and _err_loud ; and set --erase` relied on positional fall-through
    after the erase to skip the success-return on the next line; any
    future edit between the two statements could break the implicit
    empty-trigger. Block form makes the control flow explicit. Mirrors
    v5.0.29 coreutils-preflight refactor.
  * preflight/keys: new `_ir_validate_keys` invariant asserts that no
    two managed destinations produce the same `_tmpfile_key` (the
    function-name fragment for content-generator dispatch). Currently
    bounded by the 12-destination allowlist with zero collisions, but
    adding any future destination whose path components produce the
    same `slash → underscore` rewrite (e.g. `/etc/foo/bar.conf` vs
    `/etc/foo_bar.conf`) would silently mis-dispatch. Mirrors the
    `_ir_validate_counts` invariant pattern.
  * install/atomic-write: `_awf_render_to_tmp` now distinguishes
    `_as` BUG sentinel (`pipestatus[2] == 2`, non-bool `use_sudo`) from
    a generic tee write failure. The previous code conflated the two
    under "write to temp failed". `_awf_validate_parent` and
    `_awf_parent_changed` already handled `_as` rc=2 distinctly; this
    extends the pattern to the pipe site.
  * boot/install-file-parity: `_post_boot` now calls
    `_check_sudo_keepalive` at function entry and
    `_irb_verify_entries` after `sdboot-manage update` for parity with
    `_install_rebuild_boot`. The entry-count check + initrd-size scan
    (>100 MB warn) were missing from the `--install-file` rebuild path;
    `_preflight_boot_sanity` already validated kernel+initrd+valid
    loader-entry presence, so this is advisory loss only, but parity
    with the full-install path is now restored.
  * boot/resolve: `_resolve_esp` and `_resolve_boot_path` now inspect
    `pipestatus[1]` from `bootctl -p` / `bootctl -x` and log
    `ESP_BOOTCTL_PIPE_FAIL` / `BOOT_BOOTCTL_PIPE_FAIL` on non-zero rc
    (sudo lapse, bootctl error). Previously the pipeline failure was
    silently swallowed; the fallback path (findmnt or ESP) still
    handled the empty result correctly, but triage had no signal that
    bootctl was the failed stage.
  * style/mkinitcpio: `_content__etc_mkinitcpio.conf` adds an inline
    comment documenting the intentional list-flattening inside the
    `COMPRESSION_OPTIONS=($MKINITCPIO_COMPRESSION_OPTIONS)` printf —
    fish joins list elements with spaces inside double-quotes,
    producing the bash array form mkinitcpio expects.
  * docs/CHANGELOG: v5.0.29 heading restored. The previous release
    landed with the body bullets present (lines 95–194 of CHANGELOG.md)
    but no `v5.0.29 - YYYY-MM-DD` heading, leaving the bullets visually
    attached to v5.0.30. Auditability via kernel.org-style ChangeLog
    requires a dated heading per release.
  * release: 5.0.30 → 5.0.31.

v5.0.30 - 2026-05-11
--------------------

  * preflight/redactor: `_RY_SECRET_FLAGS` glob-metachar gate now also rejects
    `$`. `_redact_text` uses `$1` in the replacement string; a future entry
    containing a literal `$` in the flag name would be mis-captured by the
    fish regex engine. The existing gate refused only `[]*?\` — broadened
    here. No current entry trips the new check; defense against future drift.
  * preflight/systemd-ver: `_resolve_systemd_ver` now uses a separate
    `_RY_SYSTEMD_VER_TRIED` sentinel for the memoization gate instead of
    `set -q _RY_SYSTEMD_VER`. The previous form set `_RY_SYSTEMD_VER` to an
    empty list on parse failure; subsequent `set -q` returned 0 (variables
    are "set" even when empty in fish), permanently caching the parse
    failure across the run. With the sentinel, only the parse-success path
    populates `_RY_SYSTEMD_VER`; an empty parse logs `SYSTEMD_VER_PARSE_FAIL`
    and leaves the var unset so `_content__etc_systemd_logind.conf.d_*` and
    `_vss_logind` consumers correctly treat ver-unknown as "skip
    HandleSecureAttentionKey" (conservative; matches pre-256 behavior).
  * `_do_cleanup` erases `_RY_SYSTEMD_VER_TRIED` alongside `_RY_SYSTEMD_VER`.
  * install/_run: hard-fails when `RY_RUN_TIMEOUT` resolves to non-empty
    AND `timeout(1)` is missing from PATH. Preflight gates on `timeout` at
    bootstrap (line 232), but PATH could be shadowed post-bootstrap by a
    child env or user PATH mutation. Without this gate the silent
    fall-through executed without hang protection; the explicit refusal
    surfaces the cause. Set `RY_RUN_TIMEOUT=0` to disable.
  * install/_run: stdout/stderr capture cap raised from 100 → 500 lines.
    Chatty pacman conflict output (50-200 lines of dep-resolution errors)
    previously truncated in both visible stderr surfacing AND the JSONL
    log, hiding the root cause. On overflow, `_run` emits
    `STDOUT_TRUNCATED` / `STDERR_TRUNCATED` log events recording
    `total_lines=N captured=500` so triage knows the capture was capped.
  * preflight/caches: `_ir_precompute_caches` now asserts cardinality
    parity between `SYSTEM_DESTINATIONS + SERVICE_DESTINATIONS` and
    `_RY_CANON_SYSTEM_DSTS`, and between `USER_DESTINATIONS` and
    `_RY_CANON_USER_DSTS`. Drift would cause `_idf_match_dst`'s
    index-aligned lookup (`_RY_CANON_SYSTEM_DSTS[$_idx]`) to silently
    return the wrong canonical path. Mirrors the existing
    `_ir_validate_counts` invariant pattern; emits `_err_loud` +
    `_pre_dispatch_exit EXIT_PREFLIGHT` on mismatch.
  * lock/reclaim: `/bin/sh -c` payload now uses `find -- "$1" ...` for
    parity with the rest of the codebase (`-- "$1"` already used by
    `rmdir`, `mkdir`, `printf` in the same block). `$1` is `$LOCK_DIR`
    derived from `$HOME`; the bootstrap HOME normalization (line 250)
    already strips leading dashes, so this is defensive parity, not a
    live bug.
  * logging/dead-code: `_log` dropped the `set -q _RY_NO_LOG; and return 0`
    early-return. `_RY_NO_LOG` was never set anywhere in the codebase —
    dead control surface. If a future caller wants log suppression, the
    canonical mechanism is `set -gx _RY_LOG_OWNER_PID -1` (parallel-child
    guard fires and drops writes).
  * install/fstab: `_install_fstab_opts` no-op path (ext4 entries already
    conformant) now emits `FSTAB_OPTS_NOOP: ext4 entries already
    conformant` for symmetry with the success-path
    `FSTAB_OPTS: noatime,lazytime,commit=10 applied`. Auditability via
    `jq 'select(.event == "fstab_opts_noop")' ~/ry-install/logs/**/*.jsonl`.
  * install/fstab: `_far_awk_rewrite` `mktemp` invocation now uses
    `command mktemp` for parity with the 9 other `mktemp` call sites
    (parallel to F28's fish-function-shadow defense). Same hardening
    applied to `_acquire_lock_fresh`, `_run`, `_verify_unit_content`, and
    `_if_write_wipe_marker`.
  * install/mask: `_configure_services_mask` now pre-filters the MASK
    list by `systemctl is-enabled` BEFORE the batch `systemctl mask`
    call. Already-masked units cause the batch to return non-zero ("Unit
    ... is masked"), forcing the per-unit retry path even on otherwise
    clean runs. Pre-filtering drops already-masked + not-installed units
    up-front so the batch call exercises only the units that actually
    need masking. Per-unit retry path retained for genuine mid-batch
    failures and includes a re-probe in case state changed between
    pre-filter and retry.
  * signal/race: `_cleanup` now sets `_CLEANUP_DONE=true` immediately
    after the re-entry gate instead of after the warn echo + label
    compute (~6 statements later). Fish defers signal delivery to safe
    points, so this is hardening, not a correctness fix; the previous
    window was idempotent-safe. Mirrors v5.0.29 `_ry_exit` "order
    matters" rationale.
  * install/cache-trim: `_if_trim_pacman_cache` now gates on
    `SYSTEM_UPGRADED=true`. On idempotent re-runs (no new package
    installs and `--needed` no-op upgrade), `paccache -rk2 -ruk0` would
    still walk `/var/cache/pacman/pkg/` for a few hundred ms with no
    cleanup work to do. Logs `PACMAN_CACHE_TRIM_SKIP: SYSTEM_UPGRADED=false`
    on skip.
  * README: clarified `findmnt --verify` as advisory when `findmnt(8)`
    is available (was unconditional; matches actual `command -q findmnt`
    gate in `_fstab_atomic_replace`). `_run` doc now mentions the
    `timeout(1)` hard-fail and the 500-line capture cap with truncation
    sentinel.

v5.0.29 - 2026-05-11
--------------------

  * boot/xbootldr: `_vsb_entries`, `_install_rebuild_boot` (wipe-gate +
    verify-entries), `_if_write_wipe_marker`, `_post_boot` (install-file
    wipe-gate) now resolve `$BOOT` via `_resolve_boot_path` instead of
    ESP via `_resolve_esp`. Per BLS Type #1 spec, loader entries and
    kernels live on `$BOOT`, which equals ESP only when no XBOOTLDR
    partition exists. The previous code worked on single-ESP systems
    (target Beelink GTR9) but would enumerate the wrong partition on
    systems with a dedicated XBOOTLDR. `_resolve_esp` retained for
    actual EFI-binary path use (none in the current pipeline) and as
    `_resolve_boot_path`'s fallback. README §Scope updated to state
    `$BOOT` enumeration explicitly.
  * boot/resolve: `_resolve_esp` and `_resolve_boot_path` strip
    trailing slashes from `bootctl -p` / `bootctl -x` output
    (`string trim -r -c /`). Current systemd does not emit a trailing
    slash, but a future change would break the
    `^${boot}(/|$)` regex in `_pbs_entry_has_valid_kernel`, causing
    "No boot entry references a valid kernel image" → `EXIT_BOOT_CRIT`
    for every kernel path. Mirrors HOME normalization idiom.
  * install/mkinitcpio-rollback: `_do_cleanup` now runs
    `_mkinitcpio_revert` BEFORE the tmpfile sweep when
    `_RY_MKI_HAD_ORIG=true` and `_RY_MKI_BACKUP_FILE` is still set.
    Closes the narrow window between snapshot creation (line 4012)
    and `_install_packages` cleanup (line 4144) where a HUP/INT/TERM
    would otherwise leave the new mkinitcpio.conf in place with no
    rollback (the backup file got swept by `_cleanup_tmpfiles`
    before any revert could fire). Normal-exit paths erase the
    globals before reaching `_do_cleanup`, so the new branch fires
    only on signal interruption.
  * install/mkinitcpio-rollback: `_mkinitcpio_revert` adds a byte-exact
    size verification step between `cp` and `mv -T`. ENOSPC mid-copy
    can yield rc=0 on some coreutils versions while producing a
    truncated tmpfile; the size check refuses the atomic mv in that
    case, leaving the new (broken) conf in place rather than a
    truncated "revert" that would silently corrupt the real config.
  * preflight/coreutils: 6 single-line `not <cmd>; and echo … >&2;
    and _ry_exit` chains refactored to explicit `if/end` blocks.
    The previous chains relied on `echo`'s rc to advance to
    `_ry_exit`; if stderr closed mid-preflight (a child reaping
    parent's fd 2 at the wrong moment), the exit step would silently
    skip and the script would proceed past a missing GNU tool. Block
    form makes the exit unconditional. Mirrors v5.0.25 HOME/KVER
    refactor.
  * sudo/keepalive: `_check_sudo_keepalive` distinguishes
    `SUDO_KEEPALIVE_ERR=/dev/null` (mktemp sentinel from
    `_mktemp_or_null` when tmpfile allocation failed at keepalive
    start) from "stderr is empty but file exists". On sentinel, the
    warn now states "stderr capture unavailable — mktemp failed at
    keepalive start" instead of falling through to the no-reason
    branch. Logs `err_sentinel=true` in `SUDO_KEEPALIVE_EXPIRED`.
  * preflight/kernel: `_ry_check_kernel_version` hard-floor (kernel
    <6.14) emits `_warn` instead of `_fail`. The function returns 1
    either way and the install continues with
    `INSTALL_HAD_ERRORS=true`; the exit category is documented as
    "old-kernel preflight warn" → exit 1. The previous `_fail`
    output level implied a refusal it isn't.
  * install/finalize: `_install_finalize` gates
    `systemctl --user daemon-reload` on user-bus availability
    (`$XDG_RUNTIME_DIR/bus` OR `systemctl --user is-system-running`).
    SSH sessions without `loginctl enable-linger` have no user
    manager; the previous unconditional call failed every run with
    `Failed to connect to bus` and a stderr warn. Now emits one
    info-level skip line instead. Mirrors the user-bus probe in
    `_post_service` (v5.0.22).
  * verify-runtime/envvars: `_vre_envvars` adds the same user-bus
    pre-probe. On SSH-without-linger, the previous code reported
    each of the 10 ENV_VARS as "NOT SET in current session" with a
    separate warn line, drowning the runtime check output. Now
    emits one skip-info line and returns 0.
  * verify-runtime/perms: `_vrs_installed_file_perms` emits an
    `_info` line for each `/boot/*` destination skipped because
    `/boot` is vfat (unix perms synthesized from mount options
    aren't a meaningful check). The skip is correct behavior; only
    its silence was a problem (verify output gave no signal that
    `/boot/loader/loader.conf` perm check was elided).
  * verify-runtime/dmesg: `_verify_runtime_kparams` logs a
    `DMESG_CACHE_EMPTY` diagnostic (with reason: missing dmesg,
    missing sudo, sudo cache lapse, or restricted ring buffer) when
    the dmesg cache cannot be populated. Downstream consumers
    (`_vrk_cmdline` preempt, `_vrkg_rebar_sam`, `_vrk_clocksource`
    TSC demote) silently elide their dmesg-derived output when the
    cache is empty; the new log line surfaces *why*.
  * style/log: `_log` JSONL-truncation 8-byte window renamed from
    `tail3` (misleading — length is 8) to `_esc_window` (matches
    purpose: tail window for JSON escape backoff). Behavior
    unchanged.
  * style: `_RY_SECRET_FLAGS` and `_early_cleanup` lists split
    across backslash continuations (was single-line, ~350 cols);
    `_ry_bail_check` description trimmed from 303 cols to 1 line
    per project comment policy.
  * docs: README §Scope explicitly states `$BOOT`-enumerated entry
    semantics. §Packages adds CAUTION on `paru --skipreview`
    suppressing interactive PGP-key import prompts. §Runtime
    variables adds explicit warning that `RY_RUN_TIMEOUT=0`
    disables hang protection (wedged pacman/paru will block
    forever). §Other adds rows for `systemctl --user`
    skip-on-no-bus and AUR PGP signature failures. §Safety
    mkinitcpio-rollback row mentions signal-time revert path.
  * release: 5.0.28 → 5.0.29.

v5.0.28 - 2026-05-11
--------------------

  * dispatch/help: early-arg `-h`/`--help` now writes to stdout
    instead of stderr. Conventional CLI behaviour: explicit help
    requests belong on stdout so `ry-install.fish --help | less`
    works without `2>&1`. Argparse-path help (already stdout) is
    unchanged; the two paths now agree.
  * verify-static/perms: dead helper `_chk_path_mode_in` removed.
    Defined since v4.x but never wired in; perm checks all go
    through `_chk_perms` (exact match) or `_vrs_nm_perms` /
    `_vrs_installed_file_perms` (set membership inline). Net -12
    lines; no behaviour change.
  * install/user-files: `_atomic_write_file` perms for user-mode
    destinations changed from `0600` to `0644`. The only user
    destination is `$HOME/.config/environment.d/10-environment.conf`
    which carries no secrets (DXVK/PROTON/MESA tunables) and is
    typically world-readable per XDG convention. Parent dir umask
    remains `0077` (private to user).
  * preflight/network: `_ry_check_network` adds a secondary HTTPS
    probe to `cloudflare.com` between the primary `archlinux.org`
    HEAD and the raw-IP ICMP fallback. Corporate, airline, and
    captive-portal networks routinely drop ICMP to `1.1.1.1` while
    passing 443 to a major CDN — the previous single-host probe
    misdiagnosed these as fully offline.
  * run/redaction: `_run` now redacts captured stderr and stdout
    before writing to user terminal (was: redacted only on the
    JSONL path, raw on the tee'd display). With `-V`, secrets in
    pacman/curl/git stderr could leak to the live terminal even
    though the log was clean. Stderr line cap also bumped 50→100
    to match stdout (avoids dropping the trailing context of long
    pacman conflict reports).
  * check/units: dead glob `*/NetworkManager/dispatcher.d/*` in
    `_check_phase_units` removed. No managed destination ever
    matched that path; the live `*/NetworkManager/conf.d/*` branch
    is the only one that ever fired. Implicit-svcs set assembly
    is unchanged.
  * lock/perms: `_acquire_lock_fresh` adds an explicit `chmod 600`
    on `$LOCK_FILE` after the atomic `mv -Tf`. The script's
    umask is already `0177`, but a caller with a relaxed umask
    (sourced from a shell with `umask 022`) would otherwise leave
    the pid file world-readable. Defence-in-depth.
  * keepalive/locale: embedded `fish --no-config -c` child in
    `_start_sudo_keepalive` now wraps its two `stat -c %i` calls
    with `env LC_ALL=C`. Inode numbers are numeric (no locale
    effect today), but the parent already pins `LC_ALL=C` for
    `stat` in `_awf_*`; the child now matches.
  * verify-runtime/lsmod: `_vrkm_blacklist` wraps `lsmod` with
    `env LC_ALL=C`. kmod always emits C-locale output so the
    grep was robust already; the env pin guards future drift.
  * verify-static/checksum: `_verify_static_checksum` substitutes
    `ERR` sentinel for empty SHA results when `sha256sum` itself
    fails (OOM, EIO). The previous `_log VERIFY_STATIC_MISMATCH:
    ... expected_sha=` line would silently emit a blank hash,
    hiding the tool failure from forensics.
  * install/finalize: `_install_finalize` now probes the sudo
    keepalive at entry, matching every other phase entry
    (`_install_packages`, `_install_system_files`,
    `_install_fstab_opts`, `_install_configure_services`,
    `_install_rebuild_boot`, `_preflight_boot_sanity`,
    `_irb_verify_entries`). If keepalive died mid-Boot, finalize's
    `daemon-reload`/`paccache`/`nmcli` sudo calls previously
    failed silently; now the user is warned to re-auth.

v5.0.27 - 2026-05-11
--------------------

  * preflight/lvm-detect: `_detect_lvm` memoizes its result into a new
    `_RY_HAS_LVM` global. The function is reached transitively from
    `_mask_list_effective`, which is invoked once per `--check` run
    (`_check_phase_units`), once per `--verify-static` run
    (`_verify_static_services`), and once per `install` run
    (`_configure_services_mask`). Each previously re-forked `pvs`
    (under sudo) or `lsblk`. Memoization is per-process and is erased
    in `_do_cleanup` so sourced re-entry (single shell, same install
    after package change) probes the system fresh.
  * verify-runtime/thp: `_vre_thp_ksm` fell back to an empty `_active`
    value when `/sys/kernel/mm/transparent_hugepage/{enabled,defrag}`
    did not match the `[xxx]` selector pattern (regex miss on a future
    kernel format change). The user-facing warn line then printed an
    empty value: "THP enabled:  (recommended: always — ...)". Now
    falls back to the raw sysfs string for forensics.
  * verify-static/kernel-cmdline: `_vsb_cmdline` re-probes `sudo -n
    true` when `sudo -n cat /etc/kernel/cmdline` returns empty. The
    previous code conflated cache lapse with genuine empty file and
    printed `_fail "empty or unreadable"` in both cases. Cache-lapse
    path now emits `_warn` and returns 0 without bumping
    `VERIFY_FAIL`. Mirrors the idiom already used by `_chk_grep`.
  * install-file/post-boot: `_post_boot` empty-ESP guard symmetric
    with `_install_rebuild_boot`. When `_resolve_esp` returned empty
    (bootctl/findmnt both failed AND `/boot` missing), the old code
    passed `""` to `_boot_wipe_gate` and returned `EXIT_PREFLIGHT`
    with no user-facing message. Now returns `EXIT_BOOT_CRIT` with
    the same `_err` cascade as `_install_rebuild_boot` (L4802-4807).
  * dispatch/verbosity: `--check` is now unconditionally silent. The
    previous `-V` × `--check` combination set `QUIET=false`, which
    contradicted the documented "silent idempotency probe" contract
    in `_ry_show_help`. `_ry_do_check` emits no human output anyway,
    so the change is observable only on the (now-impossible) future
    code paths that would have inspected `QUIET` from inside check.
  * cleanup/finalize: `_is_wifi_active_route` virtual-interface
    allowlist extended to cover `br*`, `bridge*`, `macvlan*`,
    `macvtap*`, `vlan*`, `bond*`. The previous list covered VPN/
    tunnel families only. The function defers `NetworkManager
    restart` (iwd backend switch) when WiFi is the active default
    route — a bridged/macvlan'd wlan over libvirt or podman now
    correctly triggers the defer path. GTR9 profile is unaffected
    (no virtualization stack assumed) but the broader install set
    benefits.
  * cleanup/master: `_do_cleanup` erases an explicit list of script-
    set globals (cosmetic — `_ry_namespace_cleanup` snapshot-diff
    catches anything missing). Added: `_RY_HAS_LVM` (new),
    `_RY_DEPLOYED_SERVICES`, `_RY_BOOT_COUNT`, `_RY_BOOT_HASH`,
    `_RY_BOOT_PIPE_OK`, `_CPU_PATH`, `_RY_CANON_SYSTEM_DSTS`,
    `_RY_CANON_USER_DSTS`, `_SYS_TMP_DIRS`, `_USR_TMP_DIRS`,
    `_PROFILE_USES_WIFI_BACKEND`. No behaviour change in non-sourced
    invocations.
  * ux/partial-upgrade: `_ip_pacman_invoke` warning surface now
    states explicitly that the `-Syy` retry path (used when
    `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1`) does NOT upgrade already-
    installed packages — it only re-fetches the DB and installs
    missing packages. The previous text implied the retry might
    cascade an upgrade.
  * release: 5.0.26 → 5.0.27.

v5.0.26 - 2026-05-11
--------------------

  * service/cpupower-epp: escape `$cpu` as `$$cpu` in the
    `ExecStart=/usr/bin/bash -c` body. systemd performs variable
    expansion on the full ExecStart line before invoking bash; the
    unescaped `$cpu` was substituted with empty string (it is not in
    the unit's `Environment=`), so the loop wrote `> ""` for every
    iteration and every core hit "ambiguous redirect" / "No such file
    or directory". The unit reported `active (exited)` while EPP was
    never actually set. The `$$` form is the documented systemd
    escape for a literal `$`.
  * verify-runtime: `_vrsv_chk_cpupower` extended to read cpu0's
    `energy_performance_preference` sysfs node and fail when the
    value is not `performance`. Catches the failure mode where the
    unit started successfully but every sysfs write was lost.
  * security/redaction: `_redact_text` now matches `--flag <token>`
    against a single token only. The previous greedy alternation
    consumed unrelated trailing context (URLs, diagnostic text, the
    next argument) when a secret flag appeared in captured stderr.
    Multi-token unquoted secret values must now use `--flag=value`
    form to remain fully redacted; documented at the call site.
  * env: preserve the inherited `NO_COLOR` environment variable
    byte-for-byte. Previous bootstrap overwrote it with the strings
    `true`/`false` (the script's own ternary), breaking the no-
    color.org contract for any child process or sourced caller. The
    internal state moves to `_RY_NO_COLOR`; the two consumer sites
    (`_msg_print`, `_err_loud`) updated to match.
  * fstab/atomic-write: capture `tee` stderr to a tracked tmpfile
    during the `_far_awk_rewrite` pipeline; previously discarded via
    `2>&1` and lost. First line of the captured stderr now surfaces
    in the user-facing failure message.
  * fstab/atomic-write: zero-byte guard between rewrite and reference
    chmod. A successful awk + tee pipeline can still produce a zero-
    byte tmpfile (filtered-everything edge case); refuse to install
    such a file over `/etc/fstab` regardless of whether `findmnt
    --verify` is available.
  * atomic-write: `_awf_validate_parent` and `_awf_parent_changed`
    distinguish the `_as` BUG path (rc=2, caller-side use_sudo arg
    not bool) from the genuine "parent dir missing or unreadable"
    branch. Previously both produced empty cmdsub output and the
    BUG path was reported as a filesystem state.
  * sudo/keepalive: lower bound on `SUDO_KEEPALIVE_INTERVAL`. Was
    only upper-bound clamped (≤3600); now also rejects values <5 to
    prevent thrashing the sudo credential cache.
  * bootstrap/tmp: when an explicit `TMPDIR` is unwritable but `/tmp`
    is, fall back to `/tmp` and override `TMPDIR` for child
    processes. Previously hard-failed at preflight.
  * sudo/policy: extend the `_ip_probe_sudo_policy` runas regex to
    accept a bare single username (`(alice) NOPASSWD: ALL`). Was
    limited to `ALL`, `root`, or `%group`. Drop the no-op `grep -v
    '^#'` filter on `sudo -l` output (sudo -l does not emit
    comments).
  * bootstrap/secret-flags: source-mode aware bail when
    `_RY_SECRET_FLAGS` contains a glob metachar. Previously called
    raw `exit 3`, which would kill an interactive parent shell when
    the script was sourced. Now returns with the bailing sentinel
    set in sourced mode; still `exit 3` in standalone mode.
  * log-rotation: switch row separator from tab to ASCII unit-
    separator (`\x1f`). Tab is a legal byte in Linux pathnames and
    a path containing one would have split a row at the wrong
    offset, leaving the actual path silently un-rotated. Malformed
    rows now log a `LOG_ROTATION_MALFORMED_ROW` event instead of
    being silently skipped.
  * services/mask: `_configure_services_mask` mirrors the
    `_cse_batch_enable` pattern — batch first, then per-unit retry
    on failure with `is-enabled` probe to distinguish "already
    masked" / "not installed" / "genuine fail". Replaces the
    single-line "Failed to mask some services" warning that
    surfaced no per-unit detail. LVM-detection info message and
    LVM-skip warning are now independent (previously else-if-
    branched; one could mask the other).
  * boot: validate `_resolve_esp` returns a non-empty path before
    handing off to `_boot_wipe_gate` and `_irb_verify_entries`.
    Empty return previously cascaded into an opaque enumeration
    failure; now fails fast with a specific message.
  * style: collapse double space in pacdiff hint emitted by
    `_ip_scan_pacnew`. Em-dash punctuation in the LVM-detection
    mask warning aligned with the rest of the file.
  * release: 5.0.25 → 5.0.26.

v5.0.25 - 2026-05-11
--------------------

  * security/sudo: `_is_symlink`, `_fstab_atomic_replace` — append
    `2>/dev/null` to `sudo -n test -L` invocations. On microsecond-
    narrow cache lapse between the preceding `sudo -n true` probe and
    this call (or between `sudo -n mktemp` and the symlink check),
    sudo would emit "sudo: a password is required" to user stderr;
    defensive redirect.
  * security/sudo: `_far_awk_rewrite` — append `2>/dev/null` to
    `sudo -n awk` and `sudo -n tee` in the rewrite pipeline; cache
    lapse mid-pipeline previously leaked the sudo prompt to user
    stderr while pipestatus already handled the failure case.
  * security/atomic-write: `_awf_validate_parent` extended to emit
    `inode|uid|mode` snapshot on success; new helper
    `_awf_parent_changed` re-stats the parent dir post-mktemp and
    again immediately before `mv -T`. Closes the narrow TOCTOU window
    where a root-equivalent attacker could swap `dst_dir` for a
    symlink between validation and tmpfile creation. Defense-in-
    depth; requires root compromise to exploit on system paths.
  * verify: `_chk_file` — for `/boot/*` paths, re-probe `sudo -n
    true` after `sudo -n test -f` fails. Previously conflated "sudo
    cache lapsed" with "file genuinely missing"; cache lapse now
    warns rather than emitting false FAIL.
  * install: `_if_nm_restart` — replace `_run sleep $NM_RESTART_DELAY`
    with `command sleep`. `_run` wraps with `timeout`; a user-set
    `RY_RUN_TIMEOUT < NM_RESTART_DELAY` would kill the settle-window
    sleep and emit a bogus "interrupted" warning. Sleep is a known-
    safe builtin and bypasses the timeout framework appropriately.
  * cleanup: `_rm_tmp` — handle directories via `rm -rf
    --preserve-root` when `test -d` matches; previously only `rm -f`.
    Add `/dev/null` sentinel early-return (was scattered in callers).
    `_run` post-execute cleanup now routes through `_rm_tmp`
    (unifies the defer-on-failure / sudo-escalation path).
  * cleanup: new `_mktemp_or_null` helper centralizes the
    `mktemp …; or echo /dev/null` pattern at four sites
    (`_ensure_sudo_cached`, `_start_sudo_keepalive`,
    `_ip_probe_sudo_policy`, top-level argparse error capture).
    Redundant `test "$x" != /dev/null` guards at callers removed
    (sentinel handled by `_rm_tmp` and `_track_tmpfile`).
  * style: `_ry_bail_check` helper centralizes the 32-site
    `test "$_RY_INSTALL_BAILING" = true; and return
    $_RY_INSTALL_LAST_EXIT` post-`_ry_exit` guard pattern. Reduces
    risk of a missed guard silently continuing in sourced mode. The
    5 `return 0` (non-propagating) sites in `_rdi_run_phases` retain
    their specific semantic and are intentionally not migrated.
  * style: top-level preflight — dense `test X; or not test Y; and
    echo Z >&2; and _ry_exit W` chains at HOME normalization fallback
    and KVER_MINOR parse refactored to explicit `if/end` blocks;
    mirrors v5.0.21 `_run_resolve_timeout` cleanup.
  * style: top-level argparse — `set -g QUIET false` was assigned
    twice (verbose flag, then mode≠install/check); collapsed to a
    single `if … or begin … end` decision after MODE resolution.
  * style: `_far_awk_rewrite._awk_script` (was 909 chars),
    `_content__etc_systemd_system_cpupower-epp.service` (was 674
    chars) — refactor single-line `string join`/`printf` to multi-
    line backslash-continuation form. Byte-identical output;
    auditable.
  * perf: `_idf_match_dst` — precompute `realpath -m` for all 12
    managed destinations into `_RY_CANON_SYSTEM_DSTS` /
    `_RY_CANON_USER_DSTS` at `_ir_precompute_caches`. Was forking up
    to 12 realpaths per call; now zero forks. Trailing `echo ""` on
    no-match dropped in favor of `return 1` (caller already handles
    empty cmdsub).
  * log: `_run` — TMPDIR-redaction placeholder changed from literal
    `$TMPDIR/ry-[REDACTED]` (read as an unexpanded variable in logs)
    to `<TMPDIR>/ry-[REDACTED]` (unambiguous placeholder).
  * preflight: `_ir_validate_timing` — add upper-bound checks
    (`SUDO_KEEPALIVE_INTERVAL` ≤ 3600s, `NM_RESTART_DELAY` ≤ 60s);
    hostile env values that passed the `^[1-9][0-9]*$` shape check
    no longer cause hour-long sleeps.
  * release: 5.0.24 → 5.0.25.

v5.0.24 - 2026-05-11
--------------------

  * security/log: `_log` — JSONL truncation `_esc_len` calculation read
    `string match -r` output as a list-joined string, so a 6-char
    `\uABCD` trailer expanded to len=12 (full-match + group + space),
    over-cutting valid data by 1–7 bytes per affected line. Fixed by
    indexing `$_esc_match[1]` (full match only). Output JSON remained
    valid; payload was unnecessarily lost.
  * sudo: `_installed_bytes` — re-probe `sudo -n true` after `sudo -n
    cat` failure to distinguish a mid-cat cache lapse from a genuine
    read failure. Previously returned rc=1 (read fail) on lapse,
    causing `--check` mode to misdiagnose lapses as drift.
  * sudo: `_chk_grep` — for `/boot/*` paths, `_stage1_rc=1` now
    re-probes sudo before emitting "MISSING (file has no non-comment
    lines)". A cache lapse during the grep pipeline now warns rather
    than reporting a false FAIL.
  * sudo: `_is_symlink` — return rc=2 on sudo cache lapse (was
    conflated with rc=1 "not a symlink"). `_atomic_write_file` callers
    rewritten to explicit-check `$status` and abort writes on rc=2.
  * atomic-write: `_rm_tmp` — only `_untrack_tmpfile` when the file is
    verifiably gone (rm rc=0 OR path no longer exists). On rm failure
    (typically sudo lapse), path remains tracked so the `_do_cleanup`
    retry path (which escalates with sudo once recovered) can sweep it.
    Logs `RM_TMP_DEFER` for observability.
  * preflight: `_csp_filter_rdeps` — wrap `pactree -ru` in `command
    timeout` clamped to `min(60, _RY_RUN_TIMEOUT_DEFAULT)` seconds;
    guards against hangs on pathological reverse-dep trees.
  * preflight: `_ry_validate_mkinitcpio_hooks` — detect duplicate hooks
    in the HOOKS array (each duplicate emits one error). Order checks
    no longer mask duplicates by tracking only the last-occurrence
    index.
  * service: `_content__etc_systemd_system_cpupower-epp.service` — drop
    `After=cpupower.service` and `Wants=cpupower.service`; the
    `cpupower` package is not in PKGS_ADD and the service writes sysfs
    directly via bash. `ConditionPathExists` gates start; no behavior
    change on systems with cpupower installed.
  * verify: `_verify_runtime_session` — remove `~/.ssh/authorized_keys`
    and `~/.ssh/` directory perm checks; out of scope per README
    §Scope (dotfiles).
  * log: `_install_finalize` log rotation — drop `-o -name '*.log'`
    from the find glob; only `*.jsonl` is ever written.
  * preflight: top-level `HOME` normalization — `string trim --` before
    `string trim -r -c /` so a getent-derived HOME with trailing
    whitespace is handled before slash-trim.
  * style: `_progress_redraw` / `_progress_done` — hoist
    `_PROG_BAR_WIDTH=40` global; four hardcoded `40` literals replaced.
  * style: `_vre_fstab` + `_install_fstab_opts` — hoist
    `_RY_AWK_EXT4_FILTER` global; eliminates four duplicate awk
    programs.
  * style: `_progress_init` — compute `_PROG_ROWS - 1` once into
    `_scroll_bot` instead of invoking `math` twice in the same printf.
  * docs: README §Safety — note `_redact_text` aggressive multi-token
    consumption (URLs/paths after a secret value may be redacted as
    collateral).
  * docs: README §Troubleshooting — add row for `/etc/.ry-install.*`
    orphan tmpfiles after sudo lapse mid-cleanup; recommended manual
    sweep across `/etc`, `/boot`, `/var`.
  * release: 5.0.23 → 5.0.24.

v5.0.23 - 2026-05-11
--------------------

  * security: `_redact_text` — match greedy multi-token values (stops at
    next dash-flag or pipe); previously only the first whitespace-
    separated token after a flag was redacted, leaving `--cookie a b c`
    with `b c` exposed.
  * security: `_run` — redact captured stderr/stdout line-by-line before
    joining with ` | ` for `_log`. Previous join-then-redact let the
    pipe separator be consumed as the secret value, leaving the real
    value on the following pseudo-line unredacted.
  * fstab: `_far_awk_rewrite`, `_fstab_needs_change` — skip ext4
    entries whose options field (`$4`) is digits-only. Such lines are
    malformed per fstab(5) (likely an absent options column with `$4`
    absorbing the dump field); rewriting them previously prepended the
    dump value to the options string.
  * preflight: `_ir_validate_counts` — extend invariant map with
    `EXPECTED_VULKAN_PKGS:3`, `EXPECTED_SERVICES:3`,
    `_RY_PKG_MANAGED_SERVICES:1`. Drift in these arrays now fails the
    preflight gate instead of going silently.
  * preflight: `_detect_lvm` — `pvs` probe honors `RY_RUN_TIMEOUT`
    clamped to ≤10s. Was hardcoded 10s; long `RY_RUN_TIMEOUT` values now
    do not lengthen the preflight probe, short values still apply.
  * style: trim multi-line rationale comment in
    `_content__etc_systemd_system_cpupower-epp.service` into one line.
  * release: 5.0.22 → 5.0.23.

v5.0.22 - 2026-05-10
--------------------

  * aur: `_install_aur_packages` — drop `_RY_BOOT_TAINTED=true` from
    paru-missing / single-pkg / per-pkg failure paths. AUR pkgs are not
    boot-critical; tainting blocked `mkinitcpio -P` for users without
    paru. `INSTALL_HAD_ERRORS=true` still surfaces the warning.
  * aur: `_install_aur_packages` — paru gains `--removemake` alongside
    `--cleanafter`; make-only deps no longer persist.
  * packages: `_install_packages` — mkinitcpio.conf pre-deploy failure
    cleans `_RY_MKI_BACKUP_FILE` + erases `_RY_MKI_HAD_ORIG` before
    return 1; prevents stale globals.
  * packages: `_ip_pacman_invoke` — retry warning notes `-Syyu` handles
    transient mirror staleness (not pkg conflicts); points to JSONL.
  * verify: `_vrk_module_state` split into `_vrkm_amdgpu` (hex-aware
    compare) and `_vrkm_blacklist` (module_blacklist scan).
  * install-file: `_idf_match_dst` short-circuits on literal
    `target = dst` before forking `realpath -m`.
  * install: `_install_finalize` dropped redundant system `daemon-reload`;
    user `daemon-reload` retained.
  * verify: `_vrk_cmdline` — `/proc/cmdline preempt=` fallback when
    `_RY_DMESG_CACHE` is empty; reports cmdline intent w/ caveat.
  * help: `_ry_show_help` rewritten as `printf '%s\n' …` line list.
    Exit-code 1 description synced with README.
  * sudo: `_check_sudo_keepalive` probes `sudo -n true` on keepalive
    death; distinguishes "cache still valid" from "credentials lapsed".
  * boot: `_pbs_entry_has_valid_kernel` grep anchor
    `'^[[:space:]]*linux[[:space:]]'` (was `'^linux[[:space:]]'`).
  * post-hook: `_post_service` adds `systemctl --user is-system-running`
    fallback user-systemd probe.
  * release: 5.0.21 → 5.0.22.

v5.0.21 - 2026-05-10
--------------------

  * security: `_run` — captured stderr/stdout now passes through
    `_redact_text` before `_log STDERR:` / `_log OUTPUT:` so subcommand
    output containing `--password=`, `--token=`, `--bearer …` etc. does
    not leak into JSONL. Case-insensitive across `$_RY_SECRET_FLAGS`;
    handles both `=value` and space-separated `flag value` forms.
  * boot: `_pbs_entry_has_valid_kernel` — accept tab-separated BLS
    `linux<TAB>/path` per freedesktop spec; grep anchor changed from
    `'^linux '` to `'^linux[[:space:]]'`.
  * boot: `_preflight_boot_sanity` — capture each sub-check error count
    separately, validate as integer, sum explicitly; non-integer sub
    stdout coerces to 1 rather than throwing in `math`.
  * progress: `_progress` — refuse to mutate counter on unknown step
    name; logs BUG and returns 1 instead of incrementing past an
    invalid label.
  * preflight: `_ip_probe_sudo_policy` — capture `sudo -n -l` rc
    separately; distinguishes "credential not cached" from "policy
    denies ALL". Two error strings instead of one ambiguous message.
  * verify: `_verify_static_services` — `scaling_governor` regression
    scan now scopes to live `ExecStart` lines via grep prefilter;
    previously `(^|[^#])` matched whitespace-indented comments
    (e.g. `   # ExecStart=...scaling_governor`).
  * services: `_csp_filter_rdeps` — when `pactree` is absent and the
    rdep filter is bypassed, log `PACTREE_BYPASS: pkg=<name>` so the
    specific package emitted unfiltered is recorded.
  * verify: `_chk_path_mode_in` — emit `_info "$label: not present"`
    when the probed path does not exist; was silent (no signal that
    `~/.ssh/authorized_keys` check was skipped).
  * verify: `_vrs_vulkan` — install hint now lists only missing
    packages, not the full `EXPECTED_VULKAN_PKGS` set.
  * style: `_kill_sudo_keepalive`, `_check_sudo_keepalive` — `command
    kill` consistently; bare `kill` removed (was function-shadowable).
  * style: `_run` — BUG-guard return code raised to 255 (was 1/2);
    no longer collides with subprocess `rc=1` / `rc=2`.
  * style: `_run_resolve_timeout` — dense `not …; or …; and …` opener
    replaced with explicit if/elif for the unset/empty case, per
    project comment policy.
  * style: trim multi-clause inline rationale comments.
  * release: 5.0.20 → 5.0.21.

v5.0.20 - 2026-05-10
--------------------

  * boot: `_vsb_entries`, `_enum_boot_entries`, `_pbs_check_kernels`,
    `_pbs_check_initrds`, `_pbs_check_entries`, `_bwg_managed_only`,
    `_boot_initrd_size_scan` — `find … -print0 | string split0` pipestatus
    iteration treated empty-match (split0 rc=1) as enumeration failure;
    inspect `pipestatus[1]` (find) only. Empty boot/loader/entries now
    correctly reports "NONE" instead of "cannot enumerate".
  * preflight: `_init_runtime` rejects PKGS_ADD / PKGS_DEL / AUR_PKGS
    members starting with `-` (pacman/paru would parse as flag past `--`).
  * preflight: `_detect_lvm` gates `pvs` invocation on `command -q pvs`;
    avoids 10s `timeout` fallback on systems without lvm2 installed.
  * services: `cpupower-epp.service` adds `NoNewPrivileges=true`,
    `PrivateTmp=true`, `ProtectHome=true`. Stronger flags (`ProtectSystem=
    strict`, `ProtectKernelTunables=true`) would block the /sys EPP
    write — intentionally omitted. Verified via `systemd-analyze verify`.
    Re-deploys on existing installs: `--verify-static` will report
    cpupower-epp.service MISMATCH until next run.
  * runtime: `_vrk_cmdline` (preempt), `_vrkg_rebar_sam`, `_vrk_clocksource`
    (TSC demote) — guard `printf | grep` over `_RY_DMESG_CACHE` when
    cache is empty (sudo lapsed or dmesg unavailable).
  * style: `_verify_static_system` skip-iwd computation — dense
    `not A; or not B; and C` chain → explicit if/elif.
  * security: bootstrap assertion — refuse to load if `_RY_SECRET_FLAGS`
    entry contains a glob metachar (`[`, `]`, `*`, `?`, `\`); redactor
    relies on glob-safe values for the `flag=value` match path.
  * release: 5.0.19 → 5.0.20.

v5.0.19 - 2026-05-10
--------------------

  * logging: `_redact_argv_elements` — case-insensitive compare;
    `_RY_SECRET_FLAGS` extended with `--pass`, `--pw`,
    `--password-file`, `--token-file`. Short flags (`-p`/`-P`)
    intentionally not redacted (too ambiguous across tools).
  * services: `_csp_filter_rdeps` — warn-once when `pactree`
    is absent (pacman-contrib not installed); rdep-cascade
    safety was silently bypassed otherwise.
  * preflight: top-level `PATH` set preserves user `$PATH` after
    the canonical six dirs; previously hid `~/.local/bin` /
    `~/.cargo/bin` for `command -q paru`.
  * preflight: `bootctl` demoted from required to advisory in
    `_ry_check_deps`; `_resolve_esp` already falls back to
    `/boot` when bootctl absent.
  * preflight: `_validate_kernel_params` — inline note of
    intentionally-uncovered KERNEL_PARAMS (mainline-unconditional:
    iommu, loglevel, module_blacklist, nowatchdog, quiet, rd.*,
    tsc).
  * verify: `_chk_path_mode_in` for `~/.ssh/authorized_keys`
    accepts 600 only (was 600/644); `~/.ssh` dir retains 700-only.
  * aur: `_install_aur_packages` — `paru -S` passes `--skipreview`
    on both batch and per-package paths.
  * sudo: `_resolve_systemd_ver` logs `SYSTEMD_VER_PARSE_FAIL`
    when `systemctl --version` returns empty.
  * style: reorder `set -g AUR_PKGS` (mkinitcpio-firmware first)
    to match documentation.
  * style: condense script header; trim multi-clause inline
    rationale comments to single-line per project policy.
  * release: 5.0.18 → 5.0.19.

v5.0.18 - 2026-05-10
--------------------

  * cleanup: `_do_cleanup` /tmp sweep — explicit allowlist of six
    mktemp prefixes (`ry-sudo-err.*`, `ry-run.*`, `ry-val-unit.*`,
    `ry-ka-err.*`, `ry-sudo-l-err.*`, `ry-argparse-err.*`);
    replaces broad `ry-*` glob.
  * verify-static: `_verify_static_checksum` — branch on
    `_installed_bytes` exit code (0/1/2); decouples read failure
    from empty content.
  * runtime: `_vrk_module_state` — derive blacklist from
    `module_blacklist=` parse of `KERNEL_PARAMS` (was hardcoded
    pcspkr).
  * runtime: `_vrkg_vram` — regex shape-validate numeric before
    `test -gt`.
  * sudo: `_ip_probe_sudo_policy` — drop no-op `!PASSWD\b`
    alternative from regex.
  * preflight: GNU `grep -m1` probe added to coreutils chain.
  * help: exit-code summary disambiguated (1 = verify FAIL or
    install warn; 10 = --check drift).
  * cleanup: drop vestigial fish-completions sweep.
  * style: quote `$fish_pid` in `_acquire_lock_fresh`.

v5.0.17 - 2026-05-10
--------------------

  * security: `_chk_file` rejects `/boot/*` symlinks before
    `-f` probe (defense-in-depth against planted-link smuggle
    on ext4 XBOOTLDR).
  * style: pre-argparse `-h`/`-v` fast-path documented;
    `_ry_exit` log-dir rmdir cascade annotated race-safe;
    log-rename failure path is non-fatal.

v5.0.16 - 2026-05-10
--------------------

  * generators: `_ry_content_bytes` preserves dispatcher rc
    (EXIT_GEN_NOFN / NOUUID / SYSCTL) instead of collapsing to 1.
  * skip-iwd: explicit `_RY_IWD_GATED_DSTS` allowlist replaces
    `*/NetworkManager/*nm.conf` glob.
  * preflight: refuse if `HOME` is empty or non-dir after trim
    (handles `HOME="/"` edge).
  * mkinitcpio: `_mkinitcpio_hook_exists` collapses duplicated
    four-path existence check.
  * install: `_RY_BOOT_REBUILD_OK` decouples wipe-marker refresh
    from generic `INSTALL_HAD_ERRORS`.

v5.0.15 - 2026-05-10
--------------------

  * fstab: rewriter passthrough preserves original whitespace
    for non-ext4 / conformant lines; OFS="\t" only on rewritten
    entries.
  * fstab: `_fstab_needs_change` warns on existing non-10
    `commit=` value before override.
  * argparse: `--install-file=` rejects empty value; bare `--`
    followed by positionals → EXIT_USAGE.
  * locking: `_reclaim_stale_lock` falls back from atomic mkdir
    to flock-broker reclaim only when the previous PID proves
    dead via `/proc/<pid>/comm` + `cmdline` probe.

v5.0.14 - 2026-05-10
--------------------

  * boot: `_pbs_entry_has_valid_kernel` canonicalises `linux=`
    via `realpath -m`; refuses paths that escape `$BOOT` boundary.
  * boot: `_bwg_managed_only` auto-acks wipe gate when every
    entry is regenerable from `$ESP/vmlinuz-*`.
  * verify-runtime: `_vrk_clocksource` correlates TSC demotion
    via dmesg cache when HPET is current.

v5.0.13 - 2026-05-10
--------------------

  * sudo: `_start_sudo_keepalive` hermetic child via
    `fish --no-config -c`; inode-tied to `LOCK_DIR`.
  * sudo: `_check_sudo_keepalive` surfaces premature-exit cause
    from captured child stderr.
  * cleanup: `_do_cleanup` runs `pkill -P $fish_pid`
    (TERM → sleep → KILL) to reap descendants.

v5.0.12 - 2026-05-10
--------------------

  * progress: pinned scroll-region bar (DECSTBM) with SIGWINCH
    re-anchor; skipped under mosh / tmux / screen.
  * progress: `_progress_done` holds position on
    `_PROG_FINALIZED_SKIP=true` (boot-critical abort).

v5.0.11 - 2026-05-10
--------------------

  * mkinitcpio: pre-deploy `/etc/mkinitcpio.conf` before
    `pacman -Syu`; snapshot to tracked tmpfile; byte-exact revert
    on pacman failure.

v5.0.10 - 2026-05-10
--------------------

  * pkg-remove: `_csp_filter_rdeps` checks installed reverse-deps
    via pactree; cascade under `RY_INSTALL_PKG_REMOVE_CASCADE=1`.
  * pacman: `-Syu` retry uses `-Syyu` (force refresh) on first
    failure; aborts on db.lck mid-flight.

v5.0.9 - 2026-05-10
-------------------

  * services: `_cse_batch_enable` splits "enable ok, --now start
    failed" from "enable failed" via is-enabled probe.
  * nm: `_if_nm_restart` defers when WiFi is active route;
    handles VPN-over-WiFi via tunnel-iface detection.

v5.0.8 - 2026-05-10
-------------------

  * resolve: `_resolve_esp` (`bootctl -p`, fallback `/efi`,
    `/boot/efi`, `/boot`); `_resolve_boot_path` (`bootctl -x`
    for XBOOTLDR).
  * boot: `_preflight_boot_sanity` checks vmlinuz, initramfs
    non-zero, ≥1 entry references valid kernel.

v5.0.7 - 2026-05-10
-------------------

  * env: `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` switches Packages
    phase to `pacman -Sy --needed` (no system upgrade); warns
    about Arch policy violation.
  * env: `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses boot-tainted
    gate.

v5.0.6 - 2026-05-10
-------------------

  * verify-runtime: `_vre_zram` accepts `static` + active zram
    swap as valid (template units).
  * verify-runtime: `_vre_thp_ksm` checks defer+madvise defrag,
    shrink_underused=0, ksm.run=0.

v5.0.5 - 2026-05-10
-------------------

  * pacnew: `.pacnew` at managed paths auto-resolved (re-deploy
    embedded, rm `.pacnew`); `.pacsave` warn-only.
  * sysctl: `_post_sysctl` runs `sysctl --system` on single-file
    install; warns if procps-ng absent.

v5.0.4 - 2026-05-10
-------------------

  * env: `NO_COLOR` adopts no-color.org spec — presence alone
    disables (any value, including empty).
  * env: `RY_RUN_TIMEOUT` integer parser unified through `math`;
    leading zeros accepted; `0` disables.
  * signals: `_cleanup` reports actual signal name (`SIGUSR1`
    etc.) instead of fixed string.

v5.0.3 - 2026-05-09
-------------------

  * pkgs: `htop` added to `PKGS_ADD` (12 → 13).
  * post-hook: `_post_boot` honours `_boot_wipe_gate` when
    `SDBOOT_REMOVE_EXISTING=yes` (parity with
    `_install_rebuild_boot`).
  * verify: `_vsb_cmdline` verifies live root UUID against
    `/etc/kernel/cmdline` (was presence-only).
  * preflight: `_validate_kernel_params` map gains
    `amd_pstate=CONFIG_X86_AMD_PSTATE`.

v5.0.2 - 2026-05-09
-------------------

  * verify: `_vre_zram` accepts `static` + swap-active.
  * aur: `paru` calls pass `--cleanafter`.

v5.0.1 - 2026-05-09
-------------------

  * style: trim verbose comments (`_RY_BOOT_TAINTED`, user-scope
    mkdir umask).

v5.0 - 2026-05-09
-----------------

  * release: stable milestone; no functional changes from v4.6.20.

----

Pre-v5.0 history (v4.5.x, v4.6.x development iterations) archived
to `ChangeLog-4.x` upstream.
