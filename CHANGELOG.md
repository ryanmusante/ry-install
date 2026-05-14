ry-install ChangeLog
====================

v6.2.13 - 2026-05-14
--------------------

  * _run: function split into _run, _run_redact_cmd, and
    _run_effective_timeout. Tmpdir-path redaction of the logged command
    and timeout resolution / bypass selection are now self-contained
    helpers. Wire-level behaviour (logged RUN string, TIMEOUT_BYPASS
    marker, timeout invocation, exit-code propagation) unchanged.
  * _content__etc_systemd_system_cpupower-epp.service: the `$$cpu`
    rationale (systemd.service(5) unescapes `$$`→`$`) collapsed from
    five comment lines to one. No code change.

v6.2.12 - 2026-05-14
--------------------

  * _ry_install_file, _verify_static_checksum, _check_phase_files:
    content equality test fixed for files whose embedded vs installed
    bytes differ only by `<space>` vs `<newline>` token boundaries.
    `set -l x (cmd)` splits stdout on newlines into a fish array;
    `test "$x" = "$y"` then joins quoted-array elements with single
    spaces, so `"a b\nc\n"` and `"a\nb c\n"` compared EQUAL. Three
    callsites now pipe through `string collect --no-trim-newlines
    --allow-empty` to preserve newline positions in a single-element
    scalar comparison. Function return codes are recovered from
    `$pipestatus[1]` (was: `$status`, which would have reflected
    `string collect`'s rc rather than the content generator's).
    Affects: idempotency skip in install path, sha256 mismatch
    detection in --verify-static, drift detection in --check.
  * _run_emit_stream: STDERR/STDOUT line replay uses `printf '%s\n'
    "$_l"` instead of `echo $_l`. Fish builtin `echo` consumes bare
    `-n`, `-e`, `-E`, and `-{n,e,E}` combinations as flags when the
    arg matches exactly. Captured pacman/awk/sudo output containing
    a line equal to (e.g.) `-n` was previously suppressed entirely.
    `--noconfirm`, `-Sy`, etc. were never affected (flag-set is
    strict).
  * _echo: same flag-injection class — `echo "$argv"` replaced with
    `printf '%s\n' (string join ' ' -- $argv)`. Empty-argv preserves
    the prior "empty line on stderr" behavior.
  * _csm_filter_units, _csp_filter_rdeps: capture-pipe emits switched
    from `echo "$pkg"` / `echo "$_unit"` to `printf '%s\n'`. Package
    names cannot begin with `-` per Arch packaging spec and systemd
    unit names cannot either, so the change is defense-in-depth, not
    a fix for an observed failure mode.
  * _write_footer: `$extra_key` is now passed through `_json_str`
    before concatenation into the JSONL footer. All current callers
    (`interrupted`, `cleanup_exit`, empty) are JSON-safe literals;
    the change closes the contract gap for future callers.
  * _verify_static_syntax: `string trim --` added between the
    whitespace-collapse `string replace -ra '\s+' ' '` and the
    `string split ' '` of HOOKS=. Eliminates leading/trailing empty
    array elements when /etc/mkinitcpio.conf had surrounding
    whitespace inside the HOOKS=( ... ) parens. Downstream
    `_vmh_existence_only` already skipped empty hooks, so behavior
    is unchanged; the change removes a sharp edge.
  * _progress_init: pinned-progress-bar terminal probe now also
    bails when `$ZELLIJ` is set. Zellij does not advertise itself
    via `$TERM` (xterm-256color); scroll-region escape sequences
    leak into the pane background otherwise.
  * _content__etc_systemd_system_cpupower-epp.service: inline
    comment added explaining why `$$cpu` is intentional. systemd
    unescapes `$$`→`$` in ExecStart per systemd.service(5); bash
    receives `$cpu`. The previous unannotated `$$cpu` looked like a
    typo on cursory review.

v6.2.11 - 2026-05-14
--------------------

  * _csp_filter_rdeps: pipestatus gate narrowed from `_pipe_all_ok $_ps`
    back to `test $_ps[1] -ne 0`. The widened check (introduced v6.2.8)
    treated `string replace -r` and `string match -rv` non-match returns
    (rc=1) as pipeline failure, causing PKGS_DEL members with no rdeps
    or no version operators to be silently skipped on every system with
    pacman-contrib installed. Only the first stage (timeout/pactree)
    represents a real probe failure.
  * dispatch/header: JSONL `event=header` line written before
    `_init_runtime` so preflight failures inside `_ir_resolve_root_uuid`
    et al. preserve a parseable log (was: log content without header).
  * dispatch/log-create: lazy creation in `_log` covers the common
    path; top-level eager creation removed. Closes the signal window
    between log-file creation (formerly ~line 169) and signal-handler
    install (line 469). Failure to set mode 0600 on the fallback
    `touch`+`chmod` path now hard-fails preflight instead of warn-only.
  * dispatch/root-check: refusal-to-run-as-root hoisted from
    post-argparse to immediately after UID parse. Root no longer hits
    the HOME-normalisation gate first with a misleading error.
  * lock/perms: `LOCK_DIR` chmod 700 applied immediately after mkdir
    (was: inherits umask; ~/ry-install 0700 made this academic).
  * lock/cleanup: `_RY_LOCK_DIR_OWNED` sentinel set immediately after
    mkdir success so signal-driven cleanup removes the lock dir even
    when the script is killed mid-`mktemp`/`mv`.
  * _verify_unit_syntax: `--argument-names unit_path label intended_scope`
    declaration replaces positional `$argv[1..3]` reads. Matches the
    convention used by every other helper in the file.
  * _post_resolved, _post_sysctl: `--argument-names target` added for
    dispatch-table parity with the other six `_post_*` handlers.
  * _early_usage_exit: also prints `_ry_show_help` to stderr, matching
    the argparse-failure path. `--install-file=foo` and friends now
    show help, not just an `[ERR]` line.
  * _run/timeout-bypass: `updatedb` and `pkgfile --update` added to
    the bypass list. Slow filesystems were hitting the 1h cap during
    post-install DB rebuilds with no rollback to recover.
  * preflight/TMPDIR: probe adds `test -d "$TMPDIR"` so a set-but-
    invalid `TMPDIR` falls back to `/tmp` cleanly.
  * preflight/HOME: getent-passwd pipeline gains `head -n 1` so
    nsswitch chains returning multiple matches don't concatenate
    field-6 values into a malformed path.
  * _vrs_boot_perf: `systemd-analyze` parse anchors on the `= Xs Total`
    match (last `= Xs` token) and tightens the format probe regex.
  * _vsc_static_checksum: log marker rewords `expected_sha`/`actual_sha`
    to `expected_content_sha`/`actual_content_sha` — these are SHA256
    of the trimmed content used for comparison parity, not of the raw
    on-disk file.
  * _cse_collect_units: loop emitting one unit per `echo` replaced with
    a single `printf '%s\n' $_enable` after the loop.
  * _dc_erase_globals: adds `_RY_HOLDS_LOCK`, `_RY_LOCK_DIR_OWNED` to
    the erase list.
  * style: drop dead global `_RY_TIMEOUT_OK` (set once at preflight,
    never read).

v6.2.10 - 2026-05-14
--------------------

  * _ry_check_deps: `grep` added to required-cmds list (used in
    9 sites: chk_grep, mkinitcpio array parse, sdboot LINUX_OPTIONS
    extract, pacman.conf inspect, mkinitcpio hooks-line parse,
    NM-perms branch, BLS loader-entry probe, blacklist scan).
  * _verify_static_packages: capture `pacman -Qq` exit status; on
    failure (db lock, read error) skip per-pkg verification with a
    single warn instead of false-flagging every PKGS_ADD entry as
    NOT INSTALLED against an empty installed-list.
  * _ip_run_and_verify: capture `pacman -T` status; treat rc not in
    {0, 127} as verification failure (db lock, permission). Was:
    empty stdout + non-zero rc silently reported "All packages
    verified installed".
  * _csp_remove_pkgs/retry: check `pacman -Qq` rc on the per-pkg
    retry list; abort retry with a warn instead of running
    `pacman -R` against a stale/empty pkg set.
  * _idf_match_dst: return single token (`true`/`false`) instead of
    `true|true`/`true|false`. `_ry_do_install_file` reads it
    directly; no split needed.
  * _content/_vss_logind: `HandleSecureAttentionKey` skip on
    systemd<256 rewritten as explicit `if`-block (was relying on
    `test … ; or test … ; and continue` precedence).
  * _vsb_mkinitcpio: `COMPRESSION_OPTIONS` match now per-token,
    order-independent. Was substring match — reordered
    `(-T0 -1)` reported MISSING.
  * _verify_runtime_kparams: dmesg slice extractions (preempt-line,
    BAR-line, TSC-line) precomputed once into globals instead of
    three full re-scans of the 5000-line cache.
  * _pb_rebuild_cascade: dropped dead `_failed_step` local; step
    label inlined in `_log` calls.
  * _resolve_systemd_ver and 26 other `--description` strings
    trimmed to leading clause; parenthetical detail dropped where
    it duplicated the function body.
  * _msg_print: color switch hoisted out of the `begin … end` block
    so the colored stderr write is a straight-line sequence.
  * _dc_erase_globals: 25 single-name `set --erase` lines collapsed
    into 8 grouped lines (fish accepts multiple names per call).
  * top-level: EXIT_* constants grouped (3 lines vs 10) and counter
    inits in `_ry_verify_static`/`_ry_verify_runtime` joined.
  * boot-time: `-lt` → `-le` so an exact-target boot-time
    (e.g. 15.0s against `BOOT_TIME_TARGET=15`) reports "within".
  * dispatch: `QUIET` toggle simplified from nested `begin` blocks
    to single conjunction.
  * style: dedupe two-call `string split` patterns in `_vsb_sdboot`,
    `_vrs_parent_dirs`, `_vrkm_amdgpu`; drop no-op `printf '%s\n'`
    around already-split capture in `_ip_probe_sudo_policy`; drop
    `string split -n` for fixed-format stat output; mkinitcpio
    snapshot tmpfile prefix unified to `.ry-install.mki-snap`;
    `string match -r | tail -n 1` → `string match -rg`; nmcli
    `grep | head | cut` → `string match -rg` capture.
  * script: 5054 → ~5008 LOC; 214241 → ~212200 B (~−2 KB).

v6.2.9 - 2026-05-13
-------------------

  * HOME fallback: getent-passwd field-6 extraction uses
    `awk -F: '{print $6}'` instead of `string split -m6 ':' …[6]`.
    Robust to passwd entries with `:` in GECOS.
  * _atomic_write_file: removed unused `_expected_uid` local.
  * _ry_check_deps: `mv` added to required-cmds (boot-lock install
    and boot-wipe marker both depend on GNU `mv -T`).
  * comments: collapsed verbose `--description` strings to single
    leading clause; ~3.5 KB shaved.

v6.2.8 - 2026-05-13
-------------------

  * dispatch/log-filename: log rename (`preflight-*.jsonl` →
    `<mode>-*.jsonl`) now happens before `_init_runtime`.
  * dispatch/lock-ordering: `_acquire_lock` runs before JSONL
    header write — no orphan log on lock contention.
  * _install_preflight: every early-return sets
    `_PROG_FINALIZED_SKIP=true` so the progress bar renders
    aborted instead of "1/6 Done".
  * _msg/_msg_nocount: empty-message short-circuit hoisted from
    `_msg_print` into the callers; `_log` call also skipped.
  * _dc_erase_globals: also erases `_RY_PACTREE_MISSING_WARNED`
    and `_RY_RUN_TIMEOUT_WARNED` for symmetry.
  * _csp_filter_rdeps: pipestatus gate widened from `_ps[1]` to
    `_pipe_all_ok $_ps`.
  * _csp_remove_pkgs: batch-removal success emits visible
    `_ok "Removed: $argv"`.
  * _progress_init: TTY-feature probe replaced `tput cup 0 0` with
    read-only `tput cols` (no cursor side effect).
  * _ry_do_install: dropped dead `$_boot_rc` argument to
    `_rdi_summary`.

v6.2.7 - 2026-05-13
-------------------

  * perms/user-files: user destinations deploy 0600 (was 0644).
  * _as/sentinel: BUG rc 2 → 250 for non-bool `use_sudo`
    (avoid colliding with downstream tee/sudo exit-2 paths).
  * _run/sudo-bypass: effective-cmd detection scans past dash-flags
    after `sudo` instead of hard-indexing `$argv[3]`.
  * _run/abort: distinct rc=251 for tmpdir-alloc failure.
  * _run_emit_stream: stdout label `OUTPUT` → `STDOUT`.
  * _ry_check_deps: optional-tool absences batched into one warn.
  * _vmh_order_checks: hoist `string split ':'` to one call/iter.
  * _far_awk_rewrite: capture awk stderr to its own tmpfile.
  * _is_system_dst: drop `/root/*` from system-path allowlist.
  * _dc_sweep_filesystem: `find -xdev` added.
  * _install_aur_packages: rewrote `not set -q … or …; and return`
    chain as explicit `if`.
  * _post_service: hoist basename; user-bus daemon-reload gated by
    `_has_user_bus_active`.
  * _if_trim_pacman_cache, _if_nm_restart: explicit `return 0`.
  * 9 sites: bare `return` → `return 0`.
  * cat: drop `--` end-of-options on lock-file reads.
  * HOME-parse: `string split -m6 ':'` for GECOS `:` tolerance.
  * set/erase: replace `set -e` with `set --erase`.
  * dispatch: removed two unreachable `_RY_INSTALL_BAILING` checks.
  * argv-log: dropped dead `_argv_for_log` intermediate.
  * sourcing-guard: simplified `return 1 2>/dev/null; or exit 1`
    to direct `exit 1`.

v6.2.6 - 2026-05-13
-------------------

  * data-tables/wrap: top-level array decls wrap one element per
    continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * preflight/boot-files: `_pbs_check_boot_files` snapshots
    `$pipestatus` into `_ps` before `_pipe_all_ok` for refactor
    robustness.
  * mkinitcpio/array-parse: dropped dead `functions -q _warn`
    guard inside `_ry_mkinitcpio_array`.
  * output/separators: collapsed ~52 standalone `_echo` blank-line
    separators in verification + install routines.

v6.2.4 - 2026-05-13
-------------------

  * run/timeout: `_run` bypasses `RY_RUN_TIMEOUT` for `pacman`,
    `paru`, `mkinitcpio`, `sdboot-manage`, `paccache` (SIGKILL
    would skip rollback). Emits `TIMEOUT_BYPASS` log marker.
  * _run/log-prefix: tmpfile paths under `$TMPDIR` redacted in
    addition to `/tmp/`.
  * timeout/probe: `command timeout` invocation refuses to run if
    `timeout(1)` absent (was a soft warn).
  * _run_emit_stream: log first 500 lines per stream (was 100);
    new `STDERR_TRUNCATED`/`STDOUT_TRUNCATED` sentinels.
  * _msg/levels: `_err_loud` always emits regardless of QUIET;
    used at preflight bail-points.
  * _vsb_sdboot: only extract LINUX_OPTIONS when quote-count == 2.

v6.2.3 - 2026-05-13
-------------------

  * _ip_pacman_invoke: `-Syu` retry path uses `-Syyu` only
    (forced db re-sync); fall-through `-Sy --needed` only when
    `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1`.
  * _install_aur_packages: per-pkg retry after batch failure;
    `_RY_AUR_PARTIAL=true` surfaced in summary.
  * _ip_scan_pacnew: managed `.pacnew` auto-resolves via
    re-deploy; `.pacsave` warn-only.
  * _vrkg_perf_level: scan all `/sys/class/drm/card*/device`,
    report per-card.
  * _vrkg_rebar_sam: dmesg cache + lspci fallback.
  * _vrkg_vram: `mem_info_vram_total` BIOS carveout check.

v6.2.2 - 2026-05-13
-------------------

  * _atomic_write_file: post-write symlink re-check (TOCTOU).
  * _ry_install_file: skip-probe via `_installed_bytes` compare.
  * _fstab_atomic_replace: `findmnt --verify` hard-fail.
  * _vrs_nm_perms: `find -print0 | string split0` + pipestatus.
  * _vrs_parent_dirs: refuse group/world-writable managed parents.
  * _vrs_vulkan: `EXPECTED_VULKAN_PKGS` check (DXVK/VKD3D dep).
  * _post_boot: `RY_INSTALL_FORCE_BOOT_REBUILD` taint-gate parity
    with `_install_rebuild_boot`.

v6.2.1 - 2026-05-13
-------------------

  * _ir_validate_counts: hard-fail when documented array counts
    drift from declared invariants (`_RY_MANAGED_FILE_COUNT`,
    `KERNEL_PARAMS`, `MKINITCPIO_HOOKS`, etc.).
  * _ir_validate_keys: refuse deploy when two managed destinations
    produce the same `_tmpfile_key` (dispatch collision).
  * _init_runtime: precompute caches before any sudo write.
  * _RY_POST_HOOKS: first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * --install-file: single-file redeploy with per-target post-hook
    dispatch (boot, service, resolved, logind, nm, sysctl, envd,
    drirc); paths canonicalised via `realpath -m`.
  * argparse: `--exclusive` group for mode flags; positional after
    `--` rejected; empty `--install-file=` rejected.
  * lock: atomic `mkdir` + pid-file; stale-lock auto-reclaim on
    dead PID (`kill -0`); `EXIT_LOCK (5)` on contention.

v6.1.0 - 2026-05-12
-------------------

  * user-bus: replaced systemd-keepalive workaround with inline
    `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`
    probes (`_vre_envvars`, `_install_finalize`, `_post_service`).

v6.0.0 - 2026-05-12
-------------------

Reduction release: 5994 → 4985 LOC (-16.8%).

  * preflight: drop GNU-tool sanity probes (timeout retained).
  * source-mode: drop `_ry_bail_check` + 34 sites,
    `_ry_namespace_cleanup`; load guard refuses `source` at head.
  * ntsync: drop per-installed-kernel probes; running-kernel
    `_ntsync_state` retained.
  * kernel-params: drop `_validate_kernel_params` (advisory).
  * initramfs: drop `_ir_validate_timing`.
  * sudo-keepalive: drop `_*_sudo_keepalive` + 19 sites + interval
    global. User: long phases may re-prompt — `sudo -v` first.
  * progress: drop `_progress*` + JSONL `progress` events.
  * logging/rotation: drop tail-of-script rotation; manual prune
    via `find ~/ry-install/logs -mtime +30 -delete`.
  * logging/_log: drop parallel-child PID guard; entries emit
    `event="log"` with raw `data`.
  * credentials/redact: drop `_redact_*` (script passes no secrets
    via argv).
  * atomic-writes: drop `_awf_validate_parent`,
    `_awf_parent_changed`, TOCTOU re-stat.
  * boot/sdboot: drop `_boot_wipe_gate` family;
    `RY_INSTALL_CONFIRM_BOOT_WIPE` no longer consulted.
  * lock: drop `.lock-broker` artifact; stale lock now exits
    `EXIT_LOCK`.
  * services/mask: drop LVM detection; `lvm2-monitor.service`
    always masked.

v5.0.35 - 2026-05-11: preflight/awk `n==1` → `n==3`; sudo-keepalive `env LC_ALL=C stat` fix; `cond; and _err` → `if`; AUR PGP remediation hint; `findmnt --verify` per-line failures; redactor dash-flag guard.
v5.0.34 - 2026-05-11: 24 `cond; and _err X; and return N` → explicit `if` (EPIPE short-circuited return); `realpath` soft-dep; pactree 60s ceiling under `RY_RUN_TIMEOUT=0`; `_acquire_lock` failure via `_pre_dispatch_exit`; `_write_footer` sets log-write-fail flag; `_progress_*` monotonic seconds.
v5.0.33 - 2026-05-11: bootstrap chained-test refactor; KERNEL_PARAMS metachar reject; `df -B`; fstab awk strips `defaults`; install-file dispatch tag whitelist from `_post_<tag>`; sudo-policy `LC_ALL=C`; dmesg cache 5000; cpupower-epp service hardened (ProtectSystem/LockPersonality/MemoryDenyWriteExecute).
v5.0.32 - 2026-05-12: redact combined-alternation; preflight `mv -T`/`chmod --reference`; awk POSIX probe; `RY_INITRD_WARN_MB`; mkinitcpio post-pacman hook revalidation; lock atomic pid-file; pactree honors `RY_RUN_TIMEOUT=0`.
v5.0.31 - 2026-05-12: `_MY_UID` regex; `_ir_validate_keys`; `_awf_render_to_tmp` BUG vs tee-fail distinction; `_post_boot` install-file parity.
v5.0.30 - 2026-05-11: `_RY_SECRET_FLAGS` `$` reject; `_RY_SYSTEMD_VER_TRIED` sentinel; `_run` hard-fails on missing `timeout(1)`; capture cap 100 → 500; mask list pre-filter; cache-trim gated on `SYSTEM_UPGRADED=true`.
v5.0.29 - 2026-05-11: `$BOOT` via `bootctl -x` (XBOOTLDR); mkinitcpio signal-time revert; byte-exact size verify; `daemon-reload --user` gated on user-bus.
v5.0.28 - 2026-05-11: `-h`/`--help` to stdout; user-mode perms 0600 → 0644; cloudflare.com secondary HTTPS probe; `_run` redaction; lock `chmod 600` post `mv -Tf`.
v5.0.27 - 2026-05-11: `_RY_HAS_LVM` memoization; `_vre_thp_ksm` raw sysfs fallback; `--check` unconditionally silent; virtual-iface allowlist.
v5.0.26 - 2026-05-11: cpupower-epp `$$cpu` escape; `_vrsv_chk_cpupower` reads cpu0 EPP; `NO_COLOR` byte-preserved; keepalive lower bound.
v5.0.25 - 2026-05-11: defensive `2>/dev/null` on sudo probes; parent inode/uid/mode TOCTOU snapshot; `_mktemp_or_null`; `_RY_CANON_*` precomputed.
v5.0.24 - 2026-05-11: `_log` JSONL truncation indexing fix; `_is_symlink` rc=2 on sudo lapse; SSH key checks dropped.
v5.0.23 - 2026-05-11: `_redact_text` greedy multi-token; `_run` line-by-line redact; fstab skips digits-only options; `_ir_validate_counts` map extended.
v5.0.22 - 2026-05-10: drop `_RY_BOOT_TAINTED` on AUR failure; paru `--removemake`; `_vrk_module_state` split.
v5.0.21 - 2026-05-10: `_run` redact before log; `_pbs_entry_has_valid_kernel` tab-sep `linux<TAB>`; sudo-policy "not cached" vs "denies ALL".
v5.0.20 - 2026-05-10: `find -print0 | string split0` pipestatus `[1]`; dash-prefix pkg name reject; `cpupower-epp.service` hardening.
v5.0.19 - 2026-05-10: `_redact_argv_elements` case-insensitive; `bootctl` advisory; `--skipreview` on batch+per-pkg.
v5.0.18 - 2026-05-10: cleanup mktemp allowlist; `_verify_static_checksum` branches on `_installed_bytes` rc; runtime blacklist from `module_blacklist=` parse; `grep -m1` probe.
v5.0.17 - 2026-05-10: `_chk_file` rejects `/boot/*` symlinks.
v5.0.16 - 2026-05-10: `_ry_content_bytes` preserves dispatcher rc; `_RY_IWD_GATED_DSTS`; refuse empty/non-dir HOME.
v5.0.15 - 2026-05-10: fstab passthrough whitespace; reject empty `--install-file=`; lock reclaim flock-broker only when PID dead.
v5.0.14 - 2026-05-10: `_pbs_entry_has_valid_kernel` `realpath -m`; `_bwg_managed_only` auto-ack.
v5.0.13 - 2026-05-10: keepalive hermetic child via `fish --no-config -c`; `_do_cleanup` `pkill -P` TERM→KILL.
v5.0.12 - 2026-05-10: pinned scroll-region progress bar (DECSTBM); SIGWINCH re-anchor; skipped under mosh/tmux/screen.
v5.0.11 - 2026-05-10: pre-deploy `/etc/mkinitcpio.conf` before `pacman -Syu`; byte-exact revert on failure.
v5.0.10 - 2026-05-10: pactree cascade under `RY_INSTALL_PKG_REMOVE_CASCADE=1`; pacman `-Syyu` retry.
v5.0.9  - 2026-05-10: services split "enable ok, --now failed" from "enable failed"; NM restart deferred when WiFi is active route.
v5.0.8  - 2026-05-10: `_resolve_esp`/`_resolve_boot_path` via bootctl; `_preflight_boot_sanity` vmlinuz+initramfs+valid-entry.
v5.0.7  - 2026-05-10: `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` → `pacman -Sy --needed`; `RY_INSTALL_FORCE_BOOT_REBUILD` bypasses taint gate.
v5.0.6  - 2026-05-10: `_vre_zram` accepts `static`+active swap; THP defer+madvise + shrink_underused=0 + ksm.run=0.
v5.0.5  - 2026-05-10: `.pacnew` auto-resolve at managed paths; `_post_sysctl` runs `sysctl --system`.
v5.0.4  - 2026-05-10: NO_COLOR no-color.org spec; `RY_RUN_TIMEOUT` unified via `math`; `_cleanup` reports actual signal name.
v5.0.3  - 2026-05-09: `htop` added to PKGS_ADD; `_post_boot` honours wipe gate; `_vsb_cmdline` verifies live root UUID.
v5.0.2  - 2026-05-09: `_vre_zram` accepts `static`+swap; paru `--cleanafter`.
v5.0.1  - 2026-05-09: style — trim verbose comments.
v5.0    - 2026-05-09: stable milestone.

Pre-v5.0 history archived to `ChangeLog-4.x` upstream.
