ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

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
