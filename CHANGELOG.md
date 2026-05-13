ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v6.2.2 - 2026-05-13
-------------------

  * logging/json: complete RFC 8259 escape table; `_json_str` now
    escapes `0x07` (BEL) and `0x0b` (VT) as `\u0007` / `\u000b`
    (previously passed through unescaped, producing JSONL that some
    parsers rejected as invalid).
  * preflight/hardware: `EXPECTED_CPU_MATCH` mismatch now refuses to
    deploy. Override: `RY_INSTALL_SKIP_HARDWARE_CHECK=1`. Profile is
    Strix-Halo specific (`amdgpu.cwsr_enable=0`,
    `MKINITCPIO_MODULES=(amdgpu)`); deploying on Intel/NVIDIA silicon
    set incorrect kernel cmdline + initramfs.
  * preflight/sudo: `_ip_probe_sudo_policy` regex now uses a
    negative-character-class lookbehind to skip `Defaults !KEYWORD`
    negations (previously rejected `Defaults !requiretty`, which
    explicitly DISABLES the incompatible directive).
  * preflight/sudo: `_ensure_sudo_cached` no longer redirects stderr
    of the interactive `sudo -v` fallback (previously hid the
    password prompt). Non-TTY refusal path now emits `_err` instead
    of silent log-only.
  * install-file/post-hooks: `_RY_POST_HOOKS` recognises `/efi/*` as
    a boot-rebuild trigger alongside `/boot/*`. `--install-file`
    against an `/efi/loader/loader.conf` no longer silently skips
    mkinitcpio + sdboot-manage.
  * install-file/canonical: `_ry_do_install_file` passes the
    caller-canonicalized path directly to `_ry_install_file` and
    `_post_hook_for_target`. Drops a redundant second `realpath -m`.
  * lock/race: `_acquire_lock` verifies its own PID owns the lock
    file after a stale reclaim. Closes a TOCTOU window where two
    concurrent instances could both reclaim the same dead-PID lock.
  * cleanup/reap: `_dc_kill_children` reads the probe-derived
    `_RY_SLEEP_FRAC` for the SIGTERM→SIGKILL grace window (was
    hardcoded `0.5`, which silently became 0 on integer-only sleep).
  * verify-static/services: cpupower-epp ExecStart check moved from
    raw `grep ExecStart` to `systemctl cat | string match -rg
    ExecStart=…`, correctly resolving drop-ins and line
    continuations.
  * verify-runtime/cmdline: drop sudo fallback for `/proc/cmdline`
    read (world-readable on stock Linux).
  * aur/dkms: `paru` invocation no longer passes `--removemake`.
    DKMS packages (`mt76-mt7925-dkms`) rebuild on every kernel
    upgrade and need `gcc` + `linux-cachyos-headers` + `dkms` to
    remain installed. `_RY_AUR_PARTIAL` tracks per-package retry
    fallout and surfaces in the final summary.
  * preflight/clock: `_progress_now` caches the chosen clock source
    (`/proc/uptime` integer-floor vs `date +%s`) into `_PROG_CLOCK`
    on first call; subsequent calls never mix monotonic-uptime
    deltas with wall-clock-epoch deltas mid-run.
  * preflight/deps: `_ry_check_deps` required-tool list now includes
    `head` (used by argparse + `_run` stderr capture) and `df`
    (used by `_check_avail`).
  * run/timeout: `_run` emits `TIMEOUT_TERM` (rc=124) and
    `TIMEOUT_KILL` (rc=137) markers distinct from generic `EXIT:`,
    enabling JSONL grep on the SIGTERM-vs-SIGKILL boundary.
  * preflight/cpu: `_init_runtime` reads `/proc/cpuinfo` via
    `string match -rg '^model name\s*:\s*(.*)$' < /proc/cpuinfo`;
    drops a `command grep`.
  * preflight/home: `getent passwd | string split ':'` instead of
    `getent | cut`; fold two-pass `string trim` into one.
  * verify-unit-syntax: extract scope label into explicit local
    instead of inline `and echo / or echo` ternary.
  * resolve-esp/boot: try `bootctl -p` / `bootctl -x` without sudo
    first (systemd ≥ 250 grants unprivileged query); fall back to
    `sudo -n bootctl` on empty result. Removes unnecessary sudo
    overhead on the common path.
  * boot-wipe-marker: drop redundant `chmod 600` after mktemp
    (`umask 0177` already produces mode 600).
  * mkinitcpio/conf-parse: `_ry_mkinitcpio_array` regex-escapes
    `$key` before grep interpolation (defensive — current callers
    pass literal keys, but the interface was unsafe).
  * dispatch/argv: pre-dispatch `--help` and `--version` paths exit
    via `$EXIT_OK` sentinel instead of literal `0` (consistency
    with the rest of the exit-code surface).
  * signals/delegation: `_cleanup_other` passes explicit
    `$argv[1]` to `_cleanup` instead of `$argv` (no behavioural
    change; explicitness for future-proofing).
  * version: bump 6.2.1 → 6.2.2; header dated 2026-05-13.

v6.2.1 - 2026-05-13
-------------------

  * pkg-removal/pactree: `_csp_filter_rdeps` inspects `$pipestatus[1]`
    after the timed `pactree -ru` pipeline; fails closed (skips the
    package, emits `PACTREE_PROBE_FAIL`) on rc≠0 so a probe timeout
    can no longer be misread as "package has no reverse dependencies".
  * lock/reclaim: `_acquire_lock` retries once when `LOCK_DIR` exists
    AND the recorded pid is not running (`kill -0` probe); emits
    `LOCK_STALE_CLAIM` and reclaims. Manual `rm -rf ~/ry-install/.lock`
    no longer required after a non-graceful exit.
  * cleanup/reap: `_dc_kill_children` widens the SIGTERM → SIGKILL
    grace window to 500 ms (was `_RY_SLEEP_FRAC`, 100 ms when
    fractional sleep is available). Mitigates races against children
    masking SIGTERM briefly (e.g. pacman during db-lock acquisition).
  * paths/sudo-gate: `_is_system_dst` and the `_do_cleanup` tmpfile
    sudo-escalation allowlist now recognise `/efi/*` alongside
    `/boot/*`, matching layouts where the ESP is mounted at `/efi`
    rather than `/boot` (BLS without XBOOTLDR collapses to ESP).
  * logging/json: `_json_str` emits `\u00XX` escapes for non-printable
    bytes (RFC 8259) instead of the lossy `?` substitute; JSONL log
    values now round-trip cleanly through any JSON parser.
  * preflight/deps: `_ry_check_deps` warn-list now includes `ip(8)`
    (iproute2); used by `_is_wifi_active_route` for the
    default-route-on-WiFi check.
  * pacman/rollback: `_RY_PACMAN_REVERTED` renamed to
    `_RY_PACMAN_REVERT_ATTEMPTED` to reflect that the sentinel is set
    before revert outcome is known. No behavioural change.
  * style: collapse multi-line array declarations
    (`KERNEL_PARAMS`, `MKINITCPIO_HOOKS`, `LOGIND_IGNORE_KEYS`,
    `ENV_VARS`, `SYSCTL_VALUES`, `PKGS_ADD`, `PKGS_DEL`, `MASK`,
    `SYSTEM_DESTINATIONS`, `_RY_POST_HOOKS`, …) into single-line
    form; drop section-marker comments; tighten blank lines between
    same-prefix sub-functions. No functional change; script drops
    from 5132 to 4987 lines.

v6.2.0 - 2026-05-12
-------------------

  * dispatch/argv: move `--install-file` value validation and
    positional-arg check ahead of the root-UID check; usage-form
    errors now surface their actual cause instead of being masked
    by "must not run as root".
  * boot/rollback: `_ip_pacman_invoke` sets `_RY_PACMAN_REVERTED`
    on successful mkinitcpio.conf revert + `_RY_MKI_REVERT_FAILED`
    on revert failure. `_rdi_run_phases` skips the AUR phase when
    pacman was rolled back (avoids building against inconsistent
    mkinitcpio state).
  * boot/rebuild: `_install_rebuild_boot` and `_post_boot` now
    refuse unconditionally on `_RY_MKI_REVERT_FAILED=true`;
    `RY_INSTALL_FORCE_BOOT_REBUILD` does NOT bypass this gate.
  * preflight/disk: `_check_avail` now fails install loudly when
    `df --output=avail` parse fails (was: warn-only). Verify modes
    retain the warn-only behaviour.
  * preflight/fish: tolerate trailing non-digits in `FISH_VERSION`
    minor field (mirrors `KVER_MINOR` handling); dev builds like
    `3.7b1` no longer fail the regex.
  * preflight/timeout: probe `timeout(1)` once at bootstrap into
    `_RY_TIMEOUT_OK`; drop the redundant per-call check in `_run`.
  * preflight/nm: validate `NM_RESTART_DELAY` is a non-negative
    integer at bootstrap.
  * verify-static/cmdline: `_vsb_cmdline` reads `/etc/kernel/cmdline`
    via plain `cat` first (file is conventionally 0644), falls back
    to sudo only on read failure; same change applied to `_vrk_cmdline`
    against `/proc/cmdline`.
  * verify-runtime/fstab: `_vre_fstab` now emits a warn for ext4-like
    fstab rows with fewer than 4 fields (previously dropped silently
    by `_RY_AWK_EXT4_FILTER`).
  * fstab/awk: replace POSIX `[[:space:]]` with `[ \t]` in the ext4
    filter and the awk-rewrite script; broader portability across
    awk implementations.
  * messaging/_as: convert guard chains to explicit `if … end`
    (EPIPE-on-_log safety, consistency with v5.0.34 conversion).
  * boot/sha: parse sha256sum output with `string match -rg '^(\S+)'`
    in `_enum_boot_entries` and `_verify_static_checksum` (robust
    against whitespace drift in coreutils output).
  * argparse/error: cap argparse-error capture to `head -n 3`, joined
    with `; `; emit explicit marker when the tmpfile fell back to
    `/dev/null`.
  * mkinitcpio/hooks: `_vmh_existence_only` takes hooks as `$argv`
    instead of a single space-joined string; caller drops the quotes.
  * scope: explicit `-g` on `set INSTALL_FILE_TARGET …` and on every
    `set _RY_EXIT_CODE $status` arm of the mode-dispatch switch
    (defensive — was relying on existing-scope inheritance).
  * cleanup/_dc_erase_globals: erase `_RY_PACMAN_REVERTED` +
    `_RY_MKI_REVERT_FAILED` alongside the other run-scoped globals.
  * descriptions: trim verbose `--description` strings on 17 function
    declarations to one concise line.
  * version: bump 6.1.0 → 6.2.0; header dated 2026-05-12.

v6.1.0 - 2026-05-12
-------------------

  * progress: restore `_progress_now`, `_progress_init`, `_progress`,
    `_progress_redraw`, `_progress_done`, `_progress_teardown`,
    `_progress_on_winch` + 6 phase callsites (Preflight, Packages,
    Configuration, Services, Boot, Finalize) + skip-cascade marker on
    `EXIT_BOOT_CRIT` path. Pinned DECSTBM bottom-row bar; auto-skipped
    on non-TTY / mosh / tmux / STY / `screen*` or when `tput` absent.
    JSONL emits `PROG_STEP_START`, `PROG_STEP_END`, `PROG_DONE`.
    `_PROG_BAR_WIDTH=40`.
  * progress: `_progress_done` now logs final `PROG_STEP_END` (v5
    omitted the last step's elapsed-seconds line).
  * progress: `_progress_teardown` + `_progress_on_winch` guard on
    `set -q _PROG_PINNED` so verify/check/install-file modes (which
    never run `_progress_init`) are no-ops.
  * services/mask: drop unreachable LVM-detection `_warn`/`_info`
    branches from `_configure_services_mask`; `_mask_list_effective`
    returns `$MASK` verbatim since v6.0.0. Function description
    corrected.
  * preflight/deps: drop `flock` from required-tool list (never
    invoked; lock implementation uses atomic `mkdir`).
  * verify-static/system: drop empty `── Per-installed-kernel ntsync
    metadata ──` section header (orphaned in v6.0.0).
  * dispatch/argv: rename `_argv_redacted` → `_argv_for_log`
    (redactor removed in v6.0.0).
  * messaging/network: explicit `else` in `_ry_check_network`
    fallback branch (no semantic change).
  * sdboot/parse: `string split ':'` → `string split -m1 ':'` for
    `KEY:value` pairs in `_vsb_sdboot`.
  * lock/log: drop trailing `; or true` after `mkdir -p` parent of
    `LOCK_DIR` and after final `chmod 600` on log file (errors
    already silenced via `2>/dev/null`).
  * post_boot: drop redundant `set -q _RY_BOOT_TAINTED` guard
    (global initialised at bootstrap).
  * user-bus: extract `_has_user_bus_active` helper; replace three
    inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`
    probes (`_vre_envvars`, `_install_finalize`, `_post_service`).
  * version: bump 6.0.0 → 6.1.0; header dated 2026-05-12.

v6.0.0 - 2026-05-12
-------------------

Reduction release: 5994 → 4985 lines (-16.8%). Core install,
verify-static, verify-runtime, --check, --install-file, and all
managed-file deployment unchanged. Removals below have user-facing
notes where relevant.

  * preflight: drop GNU-tool sanity probes (`sort -z`, `stat -c`,
    `find -printf`, `df`, `mv -T`, `chmod`, `awk`, `grep -m`).
    `timeout(1)` probe retained.
  * source-mode: drop top-level caller snapshot,
    `_ry_bail_check` + 34 callsites, sourced-exit branches in
    `_ry_exit` and signal handlers, `_ry_namespace_cleanup`. The
    load guard now refuses `source ry-install.fish` at file head
    (via `status stack-trace`).
  * ntsync: drop `_ntsync_per_kernel_state`,
    `_ntsync_check_installed_kernels`. Running-kernel probe
    (`_ntsync_state`) retained.
  * kernel-params: drop `_validate_kernel_params` (advisory only).
  * initramfs: drop `_ir_validate_timing` (cosmetic).
  * sudo-keepalive: drop `_start_/_kill_/_check_sudo_keepalive` +
    19 callsites + `SUDO_KEEPALIVE_INTERVAL` global. User: sudo may
    re-prompt during long phases — run `sudo -v && ./ry-install.fish`
    or extend `timestamp_timeout`.
  * progress: drop `_progress*` (7 functions) + 11 callsites + JSONL
    `progress` events. User: no visual phase tracker; use
    `--verbose` or tail the JSONL.
  * logging/rotation: drop tail-of-script rotation block +
    `MAX_LOGS` global. User: JSONL logs accumulate — prune with
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
    consulted (also dropped from `--help`). User:
    `SDBOOT_REMOVE_EXISTING=yes` (default) wipes without
    confirmation; set `=no` to preserve entries.
  * lock: drop `_reclaim_stale_lock`, `_rsl_build_sh_script`,
    `_rcl_probe_owner_pid`, `.lock-broker` artifact. User: stale
    lock now exits `EXIT_LOCK (5)` — `rm -rf ~/ry-install/.lock`
    to clear.
  * services/mask: drop `_detect_lvm` and LVM-aware exclusion in
    `_mask_list_effective`. User: `lvm2-monitor.service` always
    masked; LVM users edit `$MASK` directly.
  * _chk_file: body uses declared `$filepath` instead of
    `$argv[1]` (13 sites).
  * _post_resolved, _post_sysctl, _rdi_summary: drop unused
    `--argument-names`.
  * top-level: `return` → `exit` at post-dispatch teardown
    (consistency with exec-only model).
  * --help: drop `RY_INSTALL_CONFIRM_BOOT_WIPE`; add
    `RY_INITRD_WARN_MB`; compact env-var entries.
  * version: bump 5.0.35 → 6.0.0; header dated 2026-05-12.

v5.0.35 - 2026-05-11
--------------------

  * preflight/awk: `n==1` → `n==3` fix (was unsatisfiable on every
    awk implementation; release-blocker for v5.0.34).
  * sudo-keepalive: drop `command` inside `env LC_ALL=C stat -c %i`
    (env cannot exec the builtin); fail-loud guard added.
  * messaging/error-paths: convert remaining 8 `cond; and _err`
    chains to `if … end`.
  * aur/paru: targeted PGP-signature remediation `_info` on
    `--skipreview` retry-path failure.
  * fstab/findmnt: `--verify` failure emits each line as separate
    `_fail` (was joined with `'; '`).
  * logging/redactor: dash-flag guard so `--token --next-flag`
    no longer over-redacts.

v5.0.34 - 2026-05-11
--------------------

  * messaging/error-paths: 24 sites converted from `cond; and _err
    X; and return N` chains to explicit `if … end` (EPIPE on stderr
    `echo` short-circuited the `return N`).
  * preflight/deps: `realpath` moved to soft-dep.
  * pkg-removal/pactree: `_csp_filter_rdeps` clamps probe to 60s
    even when `RY_RUN_TIMEOUT=0`.
  * lock/cleanup: `_acquire_lock` failure routes through
    `_pre_dispatch_exit`.
  * logging/footer: `_write_footer` sets `_RY_LOG_WRITE_FAIL=true`
    on JSONL `printf` failure.
  * progress/timing: `_progress_*` switched to monotonic seconds.

v5.0.33 - 2026-05-11: bootstrap chained-test refactor; kernel-params reject regex extended to shell metachars; df -B probe; fstab awk strips `defaults`; install-file dispatch tag whitelist derived from `_post_<tag>`; sudo-policy under `LC_ALL=C`; dmesg cache cap 5000; cpupower-epp hardening (ProtectSystem/LockPersonality/MemoryDenyWriteExecute).
v5.0.32 - 2026-05-12: redact combined-alternation; source-mode env snapshot; preflight coreutils probes `mv -T`/`chmod --reference`; awk POSIX feature probe; `RY_INITRD_WARN_MB` env override; mkinitcpio post-pacman hook revalidation; concurrency lock atomic pid-file write; pactree honors `RY_RUN_TIMEOUT=0`; all 264 functions ≤50 lines.
v5.0.31 - 2026-05-12: `_MY_UID` regex validation; `_ir_validate_keys` invariant; `_awf_render_to_tmp` distinguishes `_as` BUG sentinel from tee fail; `_post_boot` install-file parity; v5.0.29 heading restored.
v5.0.30 - 2026-05-11: `_RY_SECRET_FLAGS` `$` rejection; `_RY_SYSTEMD_VER_TRIED` sentinel; `_run` hard-fails on missing `timeout(1)`; capture cap 100 → 500; mask list pre-filter via `is-enabled`; cache-trim gated on `SYSTEM_UPGRADED=true`.
v5.0.29 - 2026-05-11: `$BOOT` enumeration via `bootctl -x` (XBOOTLDR); mkinitcpio-rollback signal-time revert; byte-exact size verification; `daemon-reload --user` gated on user-bus.
v5.0.28 - 2026-05-11: `-h`/`--help` to stdout; user-mode perms 0600 → 0644; secondary HTTPS probe to cloudflare.com (captive portals); `_run` redaction on terminal write; lock `chmod 600` post `mv -Tf`.
v5.0.27 - 2026-05-11: `_RY_HAS_LVM` memoization; `_vre_thp_ksm` raw sysfs fallback; `--check` unconditionally silent; virtual-iface allowlist extended.
v5.0.26 - 2026-05-11: cpupower-epp `$$cpu` escape fix (systemd expanded `$cpu` to empty); `_vrsv_chk_cpupower` reads cpu0 EPP; `NO_COLOR` preserved byte-for-byte; `SUDO_KEEPALIVE_INTERVAL` lower bound.
v5.0.25 - 2026-05-11: defensive `2>/dev/null` on sudo probes; `_awf_validate_parent` inode/uid/mode snapshot; `_awf_parent_changed` TOCTOU close; `_mktemp_or_null` helper; `_RY_CANON_*` precomputed (zero per-call realpath forks).
v5.0.24 - 2026-05-11: `_log` JSONL truncation indexes `$_esc_match[1]` (was over-cutting 1–7 bytes); `_is_symlink` rc=2 on cache lapse; `~/.ssh/authorized_keys` checks dropped (scope).
v5.0.23 - 2026-05-11: `_redact_text` greedy multi-token; `_run` line-by-line redact; fstab skips digits-only options; `_ir_validate_counts` map extended.
v5.0.22 - 2026-05-10: drop `_RY_BOOT_TAINTED=true` from AUR failure paths; paru `--removemake`; `_vrk_module_state` split into `_vrkm_amdgpu`/`_vrkm_blacklist`; `_ry_show_help` rewritten as `printf '%s\n' …` list.
v5.0.21 - 2026-05-10: `_run` stderr/stdout `_redact_text` before log; `_pbs_entry_has_valid_kernel` tab-separated `linux<TAB>`; `_ip_probe_sudo_policy` distinguishes "not cached" from "policy denies ALL".
v5.0.20 - 2026-05-10: `find -print0 | string split0` pipestatus inspects `[1]` only (7 sites); refuse PKGS_ADD/DEL/AUR_PKGS dash-prefix; `cpupower-epp.service` hardening flags.
v5.0.19 - 2026-05-10: `_redact_argv_elements` case-insensitive; `bootctl` demoted to advisory; aur `--skipreview` on batch + per-package.
v5.0.18 - 2026-05-10: cleanup explicit mktemp prefix allowlist; `_verify_static_checksum` branches on `_installed_bytes` rc; runtime blacklist derived from `module_blacklist=` parse; `grep -m1` probe.
v5.0.17 - 2026-05-10: `_chk_file` rejects `/boot/*` symlinks before `-f` probe.
v5.0.16 - 2026-05-10: `_ry_content_bytes` preserves dispatcher rc; `_RY_IWD_GATED_DSTS` allowlist; refuse empty/non-dir `HOME`.
v5.0.15 - 2026-05-10: fstab passthrough whitespace preservation; argparse rejects empty `--install-file=`; lock reclaim falls back to flock-broker only when PID proven dead.
v5.0.14 - 2026-05-10: `_pbs_entry_has_valid_kernel` canonicalises `linux=` via `realpath -m`; `_bwg_managed_only` auto-ack when entries regenerable.
v5.0.13 - 2026-05-10: `_start_sudo_keepalive` hermetic child via `fish --no-config -c`; `_do_cleanup` runs `pkill -P` (TERM → KILL).
v5.0.12 - 2026-05-10: pinned scroll-region progress bar (DECSTBM); SIGWINCH re-anchor; skipped under mosh/tmux/screen.
v5.0.11 - 2026-05-10: pre-deploy `/etc/mkinitcpio.conf` before `pacman -Syu`; byte-exact revert on failure.
v5.0.10 - 2026-05-10: `_csp_filter_rdeps` pactree cascade under `RY_INSTALL_PKG_REMOVE_CASCADE=1`; pacman `-Syyu` retry on first failure.
v5.0.9 - 2026-05-10: services split "enable ok, --now failed" from "enable failed"; `_if_nm_restart` defers when WiFi is active route.
v5.0.8 - 2026-05-10: `_resolve_esp` / `_resolve_boot_path` via bootctl; `_preflight_boot_sanity` checks vmlinuz + initramfs + valid entry.
v5.0.7 - 2026-05-10: `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` → `pacman -Sy --needed`; `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint gate.
v5.0.6 - 2026-05-10: `_vre_zram` accepts `static` + active swap; `_vre_thp_ksm` checks defer+madvise + shrink_underused=0 + ksm.run=0.
v5.0.5 - 2026-05-10: `.pacnew` auto-resolve at managed paths; `_post_sysctl` runs `sysctl --system`.
v5.0.4 - 2026-05-10: `NO_COLOR` no-color.org spec; `RY_RUN_TIMEOUT` unified through `math`; `_cleanup` reports actual signal name.
v5.0.3 - 2026-05-09: `htop` added to PKGS_ADD (12 → 13); `_post_boot` honours wipe gate; `_vsb_cmdline` verifies live root UUID.
v5.0.2 - 2026-05-09: `_vre_zram` accepts `static` + swap-active; paru `--cleanafter`.
v5.0.1 - 2026-05-09: style — trim verbose comments.
v5.0   - 2026-05-09: stable milestone; no functional changes from v4.6.20.

----

Pre-v5.0 history (v4.5.x, v4.6.x development iterations) archived
to `ChangeLog-4.x` upstream.
