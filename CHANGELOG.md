ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v6.0.0 - 2026-05-12
-------------------

Reduction release: 5994 → 4994 lines (-16.7%). Core install,
verify-static, verify-runtime, --check, --install-file, and all
managed-file deployment unchanged. Removals below have user-facing
notes where relevant.

  * preflight: drop GNU-tool sanity probes (`sort -z`, `stat -c`,
    `find -printf`, `df`, `mv -T`, `chmod`, `awk`, `grep -m`).
    `timeout(1)` probe retained.
  * source-mode: drop top-level caller snapshot,
    `_ry_bail_check` + 34 callsites, sourced-exit branches in
    `_ry_exit` and signal handlers, `_ry_namespace_cleanup`. The
    load guard now refuses `source ry-install.fish`.
  * ntsync: drop `_ntsync_per_kernel_state`,
    `_ntsync_check_installed_kernels`. Running-kernel probe
    (`_ntsync_state`) retained.
  * kernel-params: drop `_validate_kernel_params` (advisory only).
  * initramfs: drop `_ir_validate_timing` (cosmetic).
  * sudo-keepalive: drop `_start_/_kill_/_check_sudo_keepalive` +
    19 callsites. User: sudo may re-prompt during long phases —
    run `sudo -v && ./ry-install.fish` or extend
    `timestamp_timeout`.
  * progress: drop `_progress*` (7 functions) + 11 callsites + JSONL
    `progress` events. User: no visual phase tracker; use
    `--verbose` or tail the JSONL.
  * logging/rotation: drop tail-of-script rotation block. User:
    JSONL logs accumulate — prune with
    `find ~/ry-install/logs -mtime +30 -delete`.
  * logging/_log: drop parallel-child PID guard (dead after
    keepalive removal) and `_log_parse_event`/`_log_truncate_safe`.
    All entries now emit `event="log"` with raw `data`. User:
    consumers filtering by event-type must grep `data` instead.
  * credentials/redact: drop `_redact_text`,
    `_redact_argv_elements`, `_run_redact_argv`, `_RY_SECRET_FLAGS`
    top-level block. Script passes no secrets via argv.
  * atomic-writes: drop `_awf_validate_parent`,
    `_awf_parent_changed` and TOCTOU re-stat blocks in
    `_atomic_write_file` and `_awf_finalize_mv`.
  * boot/sdboot: drop `_boot_wipe_gate`, `_bwg_eval_marker`,
    `_bwg_managed_only`. `RY_INSTALL_CONFIRM_BOOT_WIPE` no longer
    consulted. User: `SDBOOT_REMOVE_EXISTING=yes` (default) wipes
    without confirmation; set `=no` to preserve entries.
  * lock: drop `_reclaim_stale_lock`, `_rsl_build_sh_script`,
    `_rcl_probe_owner_pid`. User: stale lock now exits
    `EXIT_LOCK (5)` — `rm -rf ~/ry-install/.lock` to clear.
  * services/mask: drop `_detect_lvm` and LVM-aware exclusion in
    `_mask_list_effective`. User: `lvm2-monitor.service` always
    masked; LVM users edit `$MASK` directly.
  * _chk_file: body uses declared `$filepath` instead of
    `$argv[1]` (13 sites).
  * _post_resolved, _post_sysctl, _rdi_summary: drop unused
    `--argument-names`.
  * --help: add `RY_INITRD_WARN_MB`; compact env-var entries.
  * version: bump 5.0.35 → 6.0.0; header dated 2026-05-12.

v5.0.35 - 2026-05-11
--------------------

  * preflight/awk: probe condition fixed from `n==1` to `n==3` to
    match `split($1,a,",")` output cardinality; previous form was
    unsatisfiable on every awk implementation. Release-blocker for
    v5.0.34.
  * sudo-keepalive: drop `command` from inside `env LC_ALL=C` in
    `stat -c %i` (env cannot exec the builtin); add `test -n
    "$_start_inode"; or exit 0` guard so future regressions fail
    loud.
  * messaging/error-paths: convert remaining 8 `cond; and _err/_warn
    X; and set/return N` chains to explicit `if … end`
    (`_validate_kernel_params` ×2, `_ry_check_kernel_version`,
    `_vmh_order_checks` ×2, `_mkinitcpio_revert`,
    `_pbs_check_entries`, `_rdi_summary`). Same EPIPE failure mode
    as v5.0.34 chain rewrite.
  * aur/paru: `_install_aur_packages` emits targeted PGP-signature
    remediation `_info` on retry-path failure under `--skipreview`.
  * fstab: `_fstab_needs_change` promotes digits-only `$4`
    (FSTAB_SKIP_MALFORMED) from log-only to once-per-scan `_warn`.
  * mkinitcpio/rollback: rename mktemp template
    `.ry-install.mki-backup.XXXXXX` → `.ry-mki-snap.XXXXXX`
    (forecloses `_cleanup_tmpfiles` glob collision).
  * mkinitcpio/revert: header now reflects actual backup lifetime —
    caller `_install_packages` is responsible for cleanup.
  * fstab/findmnt: `--verify` failure emits each output line as a
    separate `_fail` (was joined with `'; '` and corrupted on
    embedded semicolons).
  * logging/redactor: `_redact_argv_elements` adds `string match -q
    -- '-*' "$_next"` guard so `--token --next-flag` no longer
    over-redacts the trailing flag.
  * sudo-keepalive: `command sleep $_RY_SLEEP_FRAC` settle window
    (45ms typical, 1s fallback) before `kill -0 $SUDO_KEEPALIVE_PID`;
    quote `$argv[3]` in embedded child script.

v5.0.34 - 2026-05-11
--------------------

  * messaging/error-paths: 24 sites converted from `cond; and _err
    X; and return N` chains to explicit `if … end`
    (`_ensure_sudo_cached`, `_chk_perms`, `_chk_file`,
    `_cg_access_ok`, `_ry_check_deps`, `_check_avail`,
    `_ry_validate_configs`, `_awf_validate_parent`,
    `_awf_render_to_tmp`, `_atomic_write_file`, `_isf_deploy_set`,
    `_fstab_atomic_replace`, `_pbs_entry_has_valid_kernel`,
    `_if_write_wipe_marker`, `_validate_kernel_params`). EPIPE
    during stderr `echo` previously short-circuited the trailing
    `return N`.
  * preflight/deps: `realpath` moved to soft-dep; both call sites
    already had fallbacks.
  * pkg-removal/pactree: `_csp_filter_rdeps` clamps the probe to 60s
    even when `RY_RUN_TIMEOUT=0`.
  * lock/cleanup: `_acquire_lock` failure routes through
    `_pre_dispatch_exit`.
  * logging/footer: `_write_footer` sets `_RY_LOG_WRITE_FAIL=true`
    on JSONL printf failure; end-of-script warn-tail surfaces it.
  * fstab/rewrite: `_far_build_awk_script` OFS switched `"\t"` →
    `" "` (matches genfstab idiom; minimises diff vs untouched
    lines).
  * credentials/redact: `_redact_text` eats consecutive non-flag
    tokens after a secret flag (log-only; over-redacts positionals
    after single-value secret flags).
  * preflight/sudo: remove stale `_info "Sudo password required..."`
    from `_install_preflight` (probe is `sudo -n`, no prompt).
  * progress/timing: `_progress_*` switched to monotonic seconds via
    new `_progress_now` helper (first field of `/proc/uptime`,
    fallback `date +%s`).
  * runtime/dmesg: log `DMESG_CAPPED: kept=5000 of N lines` event
    when the cap is applied.

v5.0.33 - 2026-05-11
--------------------

  * bootstrap/error-paths: replaced chained `test ... ; and echo
    ... ; and _ry_exit` (log-dir mode, log-file create,
    kernel-version parse, managed-file count drift) with explicit
    `if ... end`; SIGPIPE during the intervening echo previously
    silently elided the abort.
  * boot-wipe/marker: `_bwg_eval_marker` refuses on unreadable
    marker (was silently ACK'd via empty-hash legacy branch); emits
    `BOOT_WIPE_MARKER_UNREADABLE`.
  * preflight/kernel-params: extend reject regex to cover shell
    metachars `$`, `` ` ``, `;`, `\`, `"` in addition to whitespace.
  * preflight/coreutils: add `df -B` probe alongside `df --output`
    (runtime `_check_avail` uses `df --output=avail -B1`).
  * fstab/awk: rewriter strips `defaults` from option list when
    re-emitting ext4 entries (visual hygiene; last-wins semantics
    made it harmless).
  * fstab/guard: minimum-size guard on rewritten tmpfile tightened
    from `< 1` to `< 20` bytes.
  * install-file/dispatch: `_idf_dispatch_hook` tag whitelist now
    derived from `functions -q _post_<tag>` (single source of
    truth; was hardcoded parallel array).
  * preflight/sudo-policy: `sudo -n -l` runs under `LC_ALL=C` so the
    runas/ALL regex matches a locale-stable English string.
  * runtime/dmesg-cache: cap `_RY_DMESG_CACHE` at 5000 lines via
    `head -n 5000`.
  * service/cpupower-epp: add `ProtectSystem=strict`,
    `LockPersonality=true`, `MemoryDenyWriteExecute=true` to the
    embedded unit; stronger flags omitted (would block EPP write or
    kill journal stderr).
  * runtime/wifi-detection: extend virtual-interface prefix list in
    `_is_wifi_active_route` with `geneve*`, `vxlan*`, `nlmon*`.
  * sudo-aware/path-coverage: `_is_system_dst` extended with
    `/srv/*`, `/opt/*`, `/root/*` (defense-in-depth).
  * docs: corrected `_ir_validate_timing` comment math (1h
    keepalive ceiling vs sudo `timestamp_timeout=300/600`).

v5.0.32 - 2026-05-12
--------------------

  * security/redact: `_redact_text` rewritten with combined-alternation
    regex covering `--flag=value`, `--flag "multi token"`,
    `--flag 'multi token'`, `--flag <single-token>` in a single
    pass. Previous separate-pass form had the unquoted fallback
    clobber the quoted redaction output.
  * security/sudo-policy: `_ip_probe_sudo_policy` runas regex
    accepts any non-empty parenthesised runas spec
    (`(alice, bob)`, `(:wheel)`, `(ALL : ALL)`).
  * source-mode/env: snapshot caller's `HOME`/`PATH`/`TMPDIR` at
    load time; `_ry_namespace_cleanup` restores on source-mode bail.
  * env/PATH: prepend uses order-preserving manual dedup so repeated
    `source ry-install.fish` does not grow `$PATH` unbounded.
  * preflight/deps: `_ry_check_deps` whitelist trimmed to
    non-base-coreutils only. Stale `sed` entry dropped.
  * preflight/coreutils: add `mv -T` and `chmod --reference` GNU-
    extension probes.
  * preflight/awk: add POSIX `split + regex + OFS` feature probe.
  * preflight/initramfs: `INITRD_WARN_MB` overridable via
    `RY_INITRD_WARN_MB` (positive integer, `^[1-9][0-9]*$`).
  * install/mkinitcpio: post-`pacman -Syu` hook revalidation —
    `_ry_validate_mkinitcpio_hooks --existence-only` re-probes
    against on-disk install/hooks after upgrade; failure taints
    `_RY_BOOT_TAINTED`.
  * install/install-file: `_post_boot` honors `_RY_BOOT_TAINTED`
    gate; parity with `_install_rebuild_boot`.
  * boot/sdboot: `_irb_sdboot_apply` refuses when `_resolve_esp`
    fell back to `/boot` AND `/boot` is not vfat (catches
    GRUB/non-UEFI).
  * verify-runtime/perms: `_vrs_installed_file_perms` vfat skip
    resolves boot path via `_resolve_boot_path`.
  * concurrency/lock: `_reclaim_stale_lock` pid-file write made
    atomic (`mktemp` under broker parent → `printf > tmp` →
    cleanup → `mkdir` → `mv -- tmp/pid`).
  * concurrency/log: `_log` emits one-shot stderr warn on first
    parallel-child-PID drop; persistent failure short-circuits
    subsequent calls.
  * tools/pactree: `_csp_filter_rdeps` wall-clock cap respects
    `RY_RUN_TIMEOUT=0` (disable).
  * refactor/function-length: split oversized functions to meet the
    ≤50-line invariant. New helpers: `_run_emit_stream`,
    `_dc_mki_revert`, `_dc_sweep_tmpfiles`, `_dc_sweep_filesystem`,
    `_dc_erase_globals`, `_dc_kill_children`, `_awf_symlink_check`,
    `_awf_finalize_mv`, `_mr_copy_size_verify`, `_mr_chmod_chown_mv`,
    `_vmh_existence_only`, `_vmh_order_checks`, `_log_parse_event`,
    `_log_truncate_safe`, `_pb_rebuild_cascade`,
    `_rsl_build_sh_script`, `_ip_run_and_verify`,
    `_csm_filter_units`, `_csm_retry_individual`,
    `_far_build_awk_script`, `_kver_below`. All 264 functions now
    ≤50 lines.
  * refactor/dispatch: removed dead `_flag_help`/`_flag_version`
    branches in post-argparse dispatch (early-arg loop catches
    first).

v5.0.31 - 2026-05-12
--------------------

  * preflight/uid: `_MY_UID` validated as `^\d+$` immediately after
    `id -u`; refuses with `EXIT_PREFLIGHT` on non-numeric.
  * preflight/root-uuid: `_ir_resolve_root_uuid` inline chain
    refactored to explicit `if` block.
  * preflight/keys: new `_ir_validate_keys` invariant asserts no two
    managed destinations produce the same `_tmpfile_key`.
  * install/atomic-write: `_awf_render_to_tmp` distinguishes `_as`
    BUG sentinel (`pipestatus[2] == 2`, non-bool `use_sudo`) from
    generic tee write failure.
  * boot/install-file-parity: `_post_boot` calls
    `_check_sudo_keepalive` at entry and `_irb_verify_entries`
    after `sdboot-manage update` for parity with
    `_install_rebuild_boot`.
  * boot/resolve: `_resolve_esp`/`_resolve_boot_path` inspect
    `pipestatus[1]` from `bootctl`; log
    `ESP_BOOTCTL_PIPE_FAIL`/`BOOT_BOOTCTL_PIPE_FAIL` on non-zero rc.
  * style/mkinitcpio: inline comment documents intentional list-
    flattening inside `COMPRESSION_OPTIONS=(...)` printf.
  * docs/CHANGELOG: v5.0.29 heading restored (body bullets had
    landed visually attached to v5.0.30).
  * release: 5.0.30 → 5.0.31.

v5.0.30 - 2026-05-11
--------------------

  * preflight/redactor: `_RY_SECRET_FLAGS` glob-metachar gate also
    rejects `$` (`_redact_text` uses `$1` in replacement).
  * preflight/systemd-ver: `_resolve_systemd_ver` uses
    `_RY_SYSTEMD_VER_TRIED` sentinel for memoization (was
    `set -q _RY_SYSTEMD_VER`, which cached parse failure
    permanently since fish considers empty lists as "set").
    `_do_cleanup` erases the sentinel.
  * install/_run: hard-fail when `RY_RUN_TIMEOUT` resolves
    non-empty AND `timeout(1)` is missing from PATH (set `=0` to
    disable).
  * install/_run: stdout/stderr capture cap raised 100 → 500 lines;
    overflow emits `STDOUT_TRUNCATED`/`STDERR_TRUNCATED` with
    `total_lines=N captured=500`.
  * preflight/caches: `_ir_precompute_caches` asserts cardinality
    parity between `SYSTEM_DESTINATIONS + SERVICE_DESTINATIONS` and
    `_RY_CANON_SYSTEM_DSTS`, and `USER_DESTINATIONS` vs
    `_RY_CANON_USER_DSTS`.
  * lock/reclaim: `/bin/sh -c` payload uses `find -- "$1" ...` for
    parity with rest of block.
  * logging/dead-code: `_log` drops the `set -q _RY_NO_LOG; and
    return 0` early-return (never set anywhere).
  * install/fstab: `_install_fstab_opts` no-op path emits
    `FSTAB_OPTS_NOOP` event for symmetry with success-path
    `FSTAB_OPTS`.
  * install/fstab: `_far_awk_rewrite` mktemp invocation uses
    `command mktemp` for parity with 9 other call sites; same
    applied to `_acquire_lock_fresh`, `_run`,
    `_verify_unit_content`, `_if_write_wipe_marker`.
  * install/mask: `_configure_services_mask` pre-filters MASK list
    by `systemctl is-enabled` before the batch `systemctl mask`
    call (already-masked units forced per-unit retry otherwise).
  * signal/race: `_cleanup` sets `_CLEANUP_DONE=true` immediately
    after re-entry gate.
  * install/cache-trim: `_if_trim_pacman_cache` gates on
    `SYSTEM_UPGRADED=true`; logs `PACMAN_CACHE_TRIM_SKIP`.
  * README: clarify `findmnt --verify` as advisory; `_run` doc
    mentions `timeout(1)` hard-fail and 500-line capture cap with
    truncation sentinel.

v5.0.29 - 2026-05-11
--------------------

  * boot/xbootldr: `_vsb_entries`, `_install_rebuild_boot`,
    `_if_write_wipe_marker`, `_post_boot` resolve `$BOOT` via
    `_resolve_boot_path` instead of ESP via `_resolve_esp`. Per
    BLS Type #1, loader entries and kernels live on `$BOOT` which
    equals ESP only when no XBOOTLDR partition exists.
    `_resolve_esp` retained for EFI-binary path use and as fallback.
  * boot/resolve: `_resolve_esp`/`_resolve_boot_path` strip trailing
    slashes from `bootctl -p`/`bootctl -x` output
    (`string trim -r -c /`); mirrors HOME normalization idiom.
  * install/mkinitcpio-rollback: `_do_cleanup` runs
    `_mkinitcpio_revert` BEFORE the tmpfile sweep when
    `_RY_MKI_HAD_ORIG=true`. Closes the signal-interrupt window
    between snapshot creation and `_install_packages` cleanup.
  * install/mkinitcpio-rollback: `_mkinitcpio_revert` adds
    byte-exact size verification step between `cp` and `mv -T`
    (ENOSPC mid-copy can yield rc=0 with truncated tmpfile on some
    coreutils).
  * preflight/coreutils: 6 chained `not <cmd>; and echo … >&2; and
    _ry_exit` refactored to explicit `if/end`; SIGPIPE on stderr
    previously skipped the exit step.
  * sudo/keepalive: `_check_sudo_keepalive` distinguishes
    `SUDO_KEEPALIVE_ERR=/dev/null` (mktemp sentinel from
    `_mktemp_or_null`) from "stderr empty but file exists"; logs
    `err_sentinel=true` in `SUDO_KEEPALIVE_EXPIRED`.
  * preflight/kernel: `_ry_check_kernel_version` hard-floor emits
    `_warn` not `_fail` (matches "old-kernel preflight warn" →
    exit 1 semantics; function returns 1 either way).
  * install/finalize: `_install_finalize` gates `systemctl --user
    daemon-reload` on user-bus availability (`$XDG_RUNTIME_DIR/bus`
    OR `systemctl --user is-system-running`); SSH-without-linger
    now emits one info-level skip instead of failing.
  * verify-runtime/envvars: `_vre_envvars` adds same user-bus probe;
    on SSH-without-linger emits one skip-info line, returns 0.
  * verify-runtime/perms: `_vrs_installed_file_perms` emits `_info`
    line for each `/boot/*` destination skipped (vfat mount).
  * verify-runtime/dmesg: `_verify_runtime_kparams` logs
    `DMESG_CACHE_EMPTY` diagnostic with reason (missing dmesg,
    sudo, cache lapse, or restricted ring buffer).
  * style/log: `_log` JSONL-truncation 8-byte window renamed
    `tail3` → `_esc_window`.
  * style: `_RY_SECRET_FLAGS`, `_early_cleanup` split across
    backslash continuations; `_ry_bail_check` description trimmed
    per project comment policy.
  * README: §Scope states `$BOOT`-enumerated entry semantics;
    §Packages CAUTION on `paru --skipreview` PGP-key prompts;
    §Runtime variables warning on `RY_RUN_TIMEOUT=0`; §Other rows
    for `systemctl --user` skip and AUR PGP failures; §Safety
    mkinitcpio-rollback signal-time revert.
  * release: 5.0.28 → 5.0.29.

v5.0.28 - 2026-05-11
--------------------

  * dispatch/help: early-arg `-h`/`--help` writes to stdout (was
    stderr). Argparse-path help already stdout; the two paths now
    agree.
  * verify-static/perms: dead helper `_chk_path_mode_in` removed
    (never wired in; perm checks go through `_chk_perms` or
    `_vrs_*_perms`). Net -12 lines.
  * install/user-files: `_atomic_write_file` user-mode perms
    changed `0600` → `0644` (sole user destination carries no
    secrets; parent dir umask remains `0077`).
  * preflight/network: `_ry_check_network` adds secondary HTTPS
    probe to `cloudflare.com` between primary `archlinux.org` HEAD
    and raw-IP ICMP fallback (captive portals drop ICMP, pass 443).
  * run/redaction: `_run` redacts captured stderr and stdout before
    writing to user terminal (was redacted only on JSONL path);
    stderr line cap bumped 50 → 100 to match stdout.
  * check/units: dead glob `*/NetworkManager/dispatcher.d/*` in
    `_check_phase_units` removed; live `*/NetworkManager/conf.d/*`
    branch was the only one ever firing.
  * lock/perms: `_acquire_lock_fresh` adds explicit `chmod 600` on
    `$LOCK_FILE` after atomic `mv -Tf` (defence against relaxed
    caller umask).
  * keepalive/locale: embedded `fish --no-config -c` child wraps
    its two `stat -c %i` calls with `env LC_ALL=C` (parity with
    parent `_awf_*` usage).
  * verify-runtime/lsmod: `_vrkm_blacklist` wraps `lsmod` with
    `env LC_ALL=C`.
  * verify-static/checksum: `_verify_static_checksum` substitutes
    `ERR` sentinel for empty SHA when `sha256sum` itself fails
    (OOM, EIO).
  * install/finalize: `_install_finalize` probes the sudo keepalive
    at entry, matching every other phase entry.

v5.0.27 - 2026-05-11
--------------------

  * preflight/lvm-detect: `_detect_lvm` memoizes result into new
    `_RY_HAS_LVM`; erased in `_do_cleanup` so sourced re-entry
    probes fresh.
  * verify-runtime/thp: `_vre_thp_ksm` falls back to raw sysfs
    string when `[xxx]` selector regex misses.
  * verify-static/kernel-cmdline: `_vsb_cmdline` re-probes `sudo -n
    true` when `sudo -n cat /etc/kernel/cmdline` returns empty;
    cache-lapse path emits `_warn` and returns 0.
  * install-file/post-boot: `_post_boot` empty-ESP guard symmetric
    with `_install_rebuild_boot` (returns `EXIT_BOOT_CRIT` with the
    same `_err` cascade).
  * dispatch/verbosity: `--check` is now unconditionally silent
    (`-V` × `--check` no longer forces `QUIET=false`).
  * cleanup/finalize: `_is_wifi_active_route` virtual-interface
    allowlist extended to `br*`, `bridge*`, `macvlan*`,
    `macvtap*`, `vlan*`, `bond*`.
  * cleanup/master: `_do_cleanup` erases explicit list of script-set
    globals: `_RY_HAS_LVM`, `_RY_DEPLOYED_SERVICES`,
    `_RY_BOOT_COUNT`, `_RY_BOOT_HASH`, `_RY_BOOT_PIPE_OK`,
    `_CPU_PATH`, `_RY_CANON_SYSTEM_DSTS`, `_RY_CANON_USER_DSTS`,
    `_SYS_TMP_DIRS`, `_USR_TMP_DIRS`,
    `_PROFILE_USES_WIFI_BACKEND`.
  * ux/partial-upgrade: `_ip_pacman_invoke` warning explicitly
    states `-Syy` retry path does NOT upgrade already-installed
    packages.
  * release: 5.0.26 → 5.0.27.

v5.0.26 - 2026-05-11
--------------------

  * service/cpupower-epp: escape `$cpu` as `$$cpu` in
    `ExecStart=/usr/bin/bash -c` body (systemd expands `$cpu` to
    empty before invoking bash; loop wrote `> ""` every iteration
    while unit reported `active (exited)`).
  * verify-runtime: `_vrsv_chk_cpupower` reads cpu0's
    `energy_performance_preference` sysfs node; fails when value is
    not `performance`.
  * security/redaction: `_redact_text` matches `--flag <token>`
    against a single token only (was greedy alternation consuming
    URLs/diagnostic text). Multi-token unquoted secret values must
    now use `--flag=value` form.
  * env: preserve inherited `NO_COLOR` byte-for-byte (was
    overwritten with `true`/`false`); internal state moves to
    `_RY_NO_COLOR`, consumers (`_msg_print`, `_err_loud`) updated.
  * fstab/atomic-write: capture `tee` stderr to tracked tmpfile
    during `_far_awk_rewrite`; first captured line surfaces in
    failure message.
  * fstab/atomic-write: zero-byte guard between rewrite and
    reference chmod (filtered-everything edge case).
  * atomic-write: `_awf_validate_parent`/`_awf_parent_changed`
    distinguish `_as` BUG path (rc=2, non-bool `use_sudo`) from
    genuine "parent dir missing or unreadable".
  * sudo/keepalive: lower bound on `SUDO_KEEPALIVE_INTERVAL` (<5
    rejected; thrashes credential cache).
  * bootstrap/tmp: when explicit `TMPDIR` is unwritable but `/tmp`
    is, fall back to `/tmp` and override `TMPDIR` for children.
  * sudo/policy: `_ip_probe_sudo_policy` runas regex accepts bare
    single username `(alice) NOPASSWD: ALL`; drop no-op
    `grep -v '^#'` filter.
  * bootstrap/secret-flags: source-mode aware bail on glob metachar
    (was raw `exit 3`); standalone-mode unchanged.
  * log-rotation: row separator switched tab → ASCII unit-separator
    (`\x1f`); malformed rows log `LOG_ROTATION_MALFORMED_ROW`.
  * services/mask: `_configure_services_mask` mirrors
    `_cse_batch_enable` batch-then-per-unit pattern with
    `is-enabled` probe; LVM-detection info and LVM-skip warning are
    now independent.
  * boot: validate `_resolve_esp` returns non-empty before handing
    off to `_boot_wipe_gate` and `_irb_verify_entries`.
  * style: collapse double-space in `_ip_scan_pacnew` pacdiff hint;
    em-dash in LVM-detection warn aligned.
  * release: 5.0.25 → 5.0.26.

v5.0.25 - 2026-05-11
--------------------

  * security/sudo: `_is_symlink`, `_fstab_atomic_replace` append
    `2>/dev/null` to `sudo -n test -L` (defensive redirect for
    microsecond cache lapse).
  * security/sudo: `_far_awk_rewrite` appends `2>/dev/null` to
    `sudo -n awk` and `sudo -n tee`.
  * security/atomic-write: `_awf_validate_parent` emits
    `inode|uid|mode` snapshot on success; new `_awf_parent_changed`
    re-stats post-mktemp and immediately before `mv -T` (closes
    TOCTOU window).
  * verify: `_chk_file` re-probes `sudo -n true` after `sudo -n
    test -f` failure on `/boot/*` (cache-lapse now warns rather
    than false FAIL).
  * install: `_if_nm_restart` replaces `_run sleep` with
    `command sleep` (low `RY_RUN_TIMEOUT` would kill the settle).
  * cleanup: `_rm_tmp` handles directories via `rm -rf
    --preserve-root` when `test -d` matches; `/dev/null` sentinel
    early-return; `_run` post-execute cleanup routes through
    `_rm_tmp`.
  * cleanup: new `_mktemp_or_null` helper centralizes the
    `mktemp …; or echo /dev/null` pattern at 4 sites.
  * style: `_ry_bail_check` helper centralizes the 32-site
    `_RY_INSTALL_BAILING=true` post-`_ry_exit` guard.
  * style: HOME normalization fallback + KVER_MINOR parse chains
    refactored to `if/end`.
  * style: collapse double `set -g QUIET false` to single `if … or
    begin … end` after MODE resolution.
  * style: `_far_awk_rewrite._awk_script` (909 chars),
    `_content__etc_systemd_system_cpupower-epp.service` (674 chars)
    refactored to multi-line backslash-continuation.
  * perf: `_idf_match_dst` precomputes `realpath -m` for all 12
    managed destinations into `_RY_CANON_{SYSTEM,USER}_DSTS` at
    `_ir_precompute_caches` (was up to 12 forks/call).
  * log: `_run` TMPDIR-redaction placeholder changed
    `$TMPDIR/ry-[REDACTED]` → `<TMPDIR>/ry-[REDACTED]`.
  * preflight: `_ir_validate_timing` adds upper-bound checks
    (`SUDO_KEEPALIVE_INTERVAL` ≤ 3600s, `NM_RESTART_DELAY` ≤ 60s).
  * release: 5.0.24 → 5.0.25.

v5.0.24 - 2026-05-11
--------------------

  * security/log: `_log` JSONL truncation `_esc_len` calculation
    indexes `$_esc_match[1]` (full match only); previously read
    list-joined string and over-cut valid data 1–7 bytes per line.
  * sudo: `_installed_bytes` re-probes `sudo -n true` after `sudo
    -n cat` failure (distinguishes mid-cat cache lapse from
    genuine read failure).
  * sudo: `_chk_grep` for `/boot/*` paths re-probes sudo on
    `_stage1_rc=1`; cache lapse warns rather than false FAIL.
  * sudo: `_is_symlink` returns rc=2 on cache lapse (was conflated
    with rc=1 "not a symlink"); `_atomic_write_file` callers
    explicit-check `$status` and abort on rc=2.
  * atomic-write: `_rm_tmp` only `_untrack_tmpfile`s when file is
    verifiably gone; logs `RM_TMP_DEFER`.
  * preflight: `_csp_filter_rdeps` wraps `pactree -ru` in
    `command timeout` clamped to `min(60,
    _RY_RUN_TIMEOUT_DEFAULT)`.
  * preflight: `_ry_validate_mkinitcpio_hooks` detects duplicate
    hooks in HOOKS array.
  * service: `_content__etc_systemd_system_cpupower-epp.service`
    drops `After=cpupower.service`/`Wants=cpupower.service`
    (package not in PKGS_ADD; service writes sysfs directly via
    bash).
  * verify: `_verify_runtime_session` removes
    `~/.ssh/authorized_keys` and `~/.ssh/` perm checks (out of
    scope per README §Scope).
  * log: `_install_finalize` log rotation drops `-o -name '*.log'`
    from find glob (only `*.jsonl` is written).
  * preflight: HOME normalization adds `string trim --` before
    `string trim -r -c /`.
  * style: hoist `_PROG_BAR_WIDTH=40` global (`_progress_redraw`,
    `_progress_done`); hoist `_RY_AWK_EXT4_FILTER` global
    (`_vre_fstab`, `_install_fstab_opts`); compute
    `_PROG_ROWS - 1` once.
  * docs: README §Safety notes `_redact_text` aggressive multi-token
    consumption; §Troubleshooting adds row for `/etc/.ry-install.*`
    orphan tmpfiles.
  * release: 5.0.23 → 5.0.24.

v5.0.23 - 2026-05-11
--------------------

  * security: `_redact_text` matches greedy multi-token values
    (stops at next dash-flag or pipe); `--cookie a b c` no longer
    leaves `b c` exposed.
  * security: `_run` redacts captured stderr/stdout line-by-line
    before joining with ` | ` for `_log`.
  * fstab: `_far_awk_rewrite`, `_fstab_needs_change` skip ext4
    entries with digits-only options field (malformed per
    fstab(5); rewriting prepended dump value to options string).
  * preflight: `_ir_validate_counts` extends invariant map with
    `EXPECTED_VULKAN_PKGS:3`, `EXPECTED_SERVICES:3`,
    `_RY_PKG_MANAGED_SERVICES:1`.
  * preflight: `_detect_lvm` `pvs` probe honors `RY_RUN_TIMEOUT`
    clamped to ≤10s.
  * style: collapse multi-line rationale comment in
    `_content__etc_systemd_system_cpupower-epp.service`.
  * release: 5.0.22 → 5.0.23.

v5.0.22 - 2026-05-10
--------------------

  * aur: `_install_aur_packages` drops `_RY_BOOT_TAINTED=true` from
    paru-missing/single-pkg/per-pkg failure paths (AUR pkgs not
    boot-critical; tainting blocked `mkinitcpio -P` for users
    without paru).
  * aur: paru gains `--removemake` alongside `--cleanafter`.
  * packages: mkinitcpio.conf pre-deploy failure cleans
    `_RY_MKI_BACKUP_FILE` + erases `_RY_MKI_HAD_ORIG` before
    return 1.
  * packages: `_ip_pacman_invoke` retry warn notes `-Syyu` handles
    transient mirror staleness (not pkg conflicts); points to
    JSONL.
  * verify: `_vrk_module_state` split into `_vrkm_amdgpu`
    (hex-aware compare) and `_vrkm_blacklist` (module_blacklist
    scan).
  * install-file: `_idf_match_dst` short-circuits on literal
    `target = dst` before forking `realpath -m`.
  * install: `_install_finalize` drops redundant system
    `daemon-reload`; user `daemon-reload` retained.
  * verify: `_vrk_cmdline` adds `/proc/cmdline preempt=` fallback
    when `_RY_DMESG_CACHE` is empty.
  * help: `_ry_show_help` rewritten as `printf '%s\n' …` line list;
    exit-code 1 synced with README.
  * sudo: `_check_sudo_keepalive` probes `sudo -n true` on
    keepalive death.
  * boot: `_pbs_entry_has_valid_kernel` grep anchor
    `'^[[:space:]]*linux[[:space:]]'`.
  * post-hook: `_post_service` adds `systemctl --user
    is-system-running` fallback user-systemd probe.
  * release: 5.0.21 → 5.0.22.

v5.0.21 - 2026-05-10
--------------------

  * security: `_run` captured stderr/stdout passes through
    `_redact_text` before `_log STDERR:`/`OUTPUT:`; case-insensitive
    across `$_RY_SECRET_FLAGS`; handles `=value` and space-separated
    `flag value`.
  * boot: `_pbs_entry_has_valid_kernel` accepts tab-separated
    `linux<TAB>/path` per freedesktop; grep anchor `'^linux '` →
    `'^linux[[:space:]]'`.
  * boot: `_preflight_boot_sanity` captures each sub-check error
    count separately; non-integer stdout coerces to 1 rather than
    throwing in `math`.
  * progress: `_progress` refuses counter mutation on unknown step
    name; logs BUG and returns 1.
  * preflight: `_ip_probe_sudo_policy` captures `sudo -n -l` rc
    separately; distinguishes "credential not cached" from "policy
    denies ALL".
  * verify: `_verify_static_services` `scaling_governor` regression
    scan scopes to live `ExecStart` via grep prefilter.
  * services: `_csp_filter_rdeps` logs `PACTREE_BYPASS: pkg=<name>`
    when pactree is absent.
  * verify: `_chk_path_mode_in` emits `_info "$label: not present"`
    when probed path missing.
  * verify: `_vrs_vulkan` install hint lists only missing packages.
  * style: `_kill_sudo_keepalive`, `_check_sudo_keepalive` use
    `command kill` consistently.
  * style: `_run` BUG-guard return code raised to 255 (was 1/2).
  * style: `_run_resolve_timeout` dense opener replaced with
    explicit if/elif.
  * release: 5.0.20 → 5.0.21.

v5.0.20 - 2026-05-10
--------------------

  * boot: `find … -print0 | string split0` pipestatus iteration
    inspects `pipestatus[1]` (find) only; empty
    boot/loader/entries now reports "NONE" instead of "cannot
    enumerate". Sites: `_vsb_entries`, `_enum_boot_entries`,
    `_pbs_check_kernels`, `_pbs_check_initrds`,
    `_pbs_check_entries`, `_bwg_managed_only`,
    `_boot_initrd_size_scan`.
  * preflight: `_init_runtime` rejects PKGS_ADD/PKGS_DEL/AUR_PKGS
    members starting with `-`.
  * preflight: `_detect_lvm` gates `pvs` invocation on
    `command -q pvs`.
  * services: `cpupower-epp.service` adds `NoNewPrivileges=true`,
    `PrivateTmp=true`, `ProtectHome=true`; re-deploys on existing
    installs.
  * runtime: `_vrk_cmdline` (preempt), `_vrkg_rebar_sam`,
    `_vrk_clocksource` (TSC demote) guard `printf | grep` over
    empty `_RY_DMESG_CACHE`.
  * style: `_verify_static_system` skip-iwd computation refactored
    to explicit if/elif.
  * security: bootstrap assertion refuses to load if
    `_RY_SECRET_FLAGS` entry contains a glob metachar (`[`, `]`,
    `*`, `?`, `\`).
  * release: 5.0.19 → 5.0.20.

v5.0.19 - 2026-05-10
--------------------

  * logging: `_redact_argv_elements` case-insensitive; extend
    `_RY_SECRET_FLAGS` with `--pass`, `--pw`, `--password-file`,
    `--token-file`.
  * services: `_csp_filter_rdeps` warns once when pactree absent.
  * preflight: top-level PATH preserves user `$PATH` after the
    canonical six dirs.
  * preflight: `bootctl` demoted from required to advisory in
    `_ry_check_deps`.
  * preflight: `_validate_kernel_params` inline-notes
    intentionally-uncovered KERNEL_PARAMS (iommu, loglevel,
    module_blacklist, nowatchdog, quiet, rd.*, tsc).
  * verify: `_chk_path_mode_in` for `~/.ssh/authorized_keys`
    accepts 600 only; `~/.ssh` dir retains 700-only.
  * aur: `_install_aur_packages` passes `--skipreview` on batch
    and per-package paths.
  * sudo: `_resolve_systemd_ver` logs `SYSTEMD_VER_PARSE_FAIL`
    on empty `systemctl --version`.
  * style: reorder `set -g AUR_PKGS` (mkinitcpio-firmware first).
  * style: condense script header; trim multi-clause inline
    rationale comments per project policy.
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
