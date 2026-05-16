ry-install ChangeLog
====================

v6.5.13 - 2026-05-15
--------------------

  * Comments trimmed (verbose rationale collapsed to single-line "why"); header v6.5.12 -> v6.5.13; 5008 -> 5005 lines. No behaviour change; content generators byte-identical.

v6.5.12 - 2026-05-15
--------------------

  * Log-dir mode audit extended from `$_RY_HOME_DIR` to all three managed paths; GNU `stat(1)` added to early preflight probe; `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL` (was `$EXIT_BOOT_CRIT`); `_acquire_lock` race branch clears `_RY_LOCK_DIR_OWNED`; `_tmp_dir` and/or chain replaced with if/else; unknown-MODE fallback routes through `_msg_print --force`; `_vre_fstab` csv-match passes through `string escape --style=regex`.

v6.5.11 - 2026-05-15
--------------------

  * `_ry_exit` bail path writes JSONL footer (`extra_key=bail`); `_cleanup_pipe` gates SIGPIPE _log on `_RY_HEADER_WRITTEN`; missing `--` separators added to `_vrsv_wifi` and `_bootctl_dir`.

v6.5.10 - 2026-05-15
--------------------

  * `_enum_boot_entries` drops write-only `_RY_BOOT_PIPE_OK`/`_RY_BOOT_HASH` globals; `_awf_finalize_mv` drops dead local; `_verify_unit_syntax` collapses empty `set user_flag` to `!= system`.

v6.5.9 - 2026-05-15
-------------------

  * `_verify_unit_syntax` _log calls pipe multi-line stderr through `string join '; '`; `_vrs_installed_file_perms` emits aggregate `perm_vfat_skipped` count; `_verify_static_syntax` drops redundant `grep -v '^#'`; four `string trim` sites normalised to `--`.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher pre-header `_warn` calls (realpath -m failure on --install-file; log-rename failure) replaced with direct `echo >&2` to avoid emitting JSONL `log` ahead of `header`.

v6.5.7 - 2026-05-14
-------------------

  * KERNEL_PARAMS metachar regex source `\\` -> `\\\\` (fish single-quote collapsed `\\` -> `\`, PCRE accepted shell metachars); 93 `string match -qr` patterns swept clean.

v6.5.6 - 2026-05-14
-------------------

  * `_msg` drops `VERIFY_MODE` gate so OK/WARN/FAIL counters track install + install-file modes; five dead `set -g VERIFY_MODE` writes removed; README jq snippet updated.

v6.5.5 - 2026-05-14
-------------------

  * `_chk_grep` stage 2 runs `grep -wF` (was `-q`, SIGPIPE-killed stage 1 on files > pipe buffer); awk/tee stderr tmpfiles renamed for `_dc_sweep_filesystem` glob coverage.

v6.5.4 - 2026-05-14
-------------------

  * `_check_phase_units` accepts `static` for NetworkManager-dispatcher; `_far_awk_rewrite` allocates stderr tmpfiles via `_mktemp_or_null`; `_dc_sweep_filesystem` drops vestigial `ry-ka-err.*`; five unreachable `_RY_INSTALL_BAILING` guards removed.

v6.5.3 - 2026-05-14
-------------------

  * Bundled short flags (`-hV`, `-hv`) route through argparse `_flag_help`/`_flag_version` post-block (early-exit `switch` only matched exact tokens); `--` added before `grep` and `basename` args; non-absolute TMPDIR falls back to /tmp.

v6.5.2 - 2026-05-14
-------------------

  * Script header version bumped (was `v6.5` despite VERSION global + README at 6.5.1); bare `sha256sum` -> `command sha256sum`; uniform preflight blocks collapsed to for-loop; `_resolve_esp`/`_resolve_boot_path` factor shared `bootctl` probe into `_bootctl_dir`.

v6.5.1 - 2026-05-14
-------------------

  * `_resolve_esp`/`_resolve_boot_path` hard-fail cached on `_RY_ESP_TRIED`/`_RY_BOOT_TRIED` (previous `test -n` guard treated cached empty as not-cached); `_run_emit_stream` adds 1 to `wc -l` when last byte is non-newline; `_vre_zram` derives instance name from live swapon device.

v6.5 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` spurious-TMPFILE_STUCK fix (or-chain precedence); `_verify_static_services` multi-ExecStart guard; 14 head/tail sites use `command` prefix; `_json_str` drops unreachable NUL escape.

v6.4 - 2026-05-14
-----------------

  * `_vsb_entries` distinguishes lapsed-sudo / unresolved-$BOOT from empty entries dir; `_ry_check_deps` adds 10 coreutils; `_progress_init` skipped under NO_COLOR; LC_ALL=C normalised to `env` prefix; logind.conf.d MISMATCH troubleshooting row added.

v6.3 - 2026-05-14
-----------------

  * `_dc_sweep_tmpfiles` logs TMPFILE_STUCK before erase; header-write sets log-write-fail sentinel; `_err_loud` deduped via `_msg_print --force`; `_is_wifi_active_route`/`_ry_check_network` loop-folded; `_vrsv_chk_nm_dispatcher` accepts `static`.

v6.2.13 - 2026-05-14
--------------------

  * `_run` split into `_run`/`_run_redact_cmd`/`_run_effective_timeout`; cpupower-epp `$$cpu` rationale comment collapsed.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect`; emit functions use `printf` instead of `echo` (flag injection); `_write_footer` `extra_key` through `_json_str`; `_progress_init` bails under `$ZELLIJ`.

v6.2.11 - 2026-05-13
--------------------

  * `_csp_filter_rdeps` pipestatus gate narrowed to stage 1; JSONL header before `_init_runtime`; lazy `_log` creation; root-check hoisted after UID parse; LOCK_DIR chmod 700; `_verify_unit_syntax`/`_post_*` `--argument-names`; TMPDIR/HOME preflight hardening.

v6.2.10 - 2026-05-14
--------------------

  * `_ry_check_deps` adds `grep`; pacman `-Qq`/`-T` status capture across verify+remove paths; logind `HandleSecureAttentionKey` explicit if-block; `_vsb_mkinitcpio` per-token COMPRESSION_OPTIONS match; `_verify_runtime_kparams` dmesg-slice precompute; 5054 -> 5008 LOC.

v6.2.9 - 2026-05-13
-------------------

  * HOME field-6 via `awk -F:` (GECOS-tolerant); `_atomic_write_file` dead local removed; `_ry_check_deps` adds `mv`.

v6.2.8 - 2026-05-13
-------------------

  * Log rename + `_acquire_lock` before JSONL header; `_install_preflight` early-returns set `_PROG_FINALIZED_SKIP`; empty-message short-circuit hoisted; `_csp_filter_rdeps` pipestatus widened.

v6.2.7 - 2026-05-13
-------------------

  * User destinations 0600; `_as` BUG rc -> 250; `_run` sudo-bypass dash-flag scan; `_run` tmpdir-alloc rc 251; capture cap 100 -> 500 with _TRUNCATED sentinels; sourcing-guard simplified.

v6.2.6 - 2026-05-13
-------------------

  * Top-level array declarations wrap one element per continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * `_pbs_check_boot_files` snapshots `$pipestatus` before `_pipe_all_ok`; ~52 standalone `_echo` blank-line separators collapsed.

v6.2.4 - 2026-05-13
-------------------

  * `_run` timeout-bypass for pacman/paru/mkinitcpio/sdboot-manage/paccache (TIMEOUT_BYPASS marker); tmpfile-path redaction under $TMPDIR; capture cap 100 -> 500; `_err_loud` always emits regardless of QUIET.

v6.2.3 - 2026-05-13
-------------------

  * `_ip_pacman_invoke` `-Syyu` retry / `-Sy` gated on RY_INSTALL_ALLOW_PARTIAL_UPGRADE; `_install_aur_packages` per-pkg retry; .pacnew auto-resolve at managed paths; `_vrkg_*` GPU runtime checks (per-card scan, dmesg+lspci fallback, BIOS carveout).

v6.2.2 - 2026-05-13
-------------------

  * `_atomic_write_file` post-write symlink re-check (TOCTOU); `_ry_install_file` skip-probe via `_installed_bytes`; `_fstab_atomic_replace` `findmnt --verify` hard-fail; `_vrs_parent_dirs` refuses group/world-writable; `_post_boot` force-rebuild taint-gate parity.

v6.2.1 - 2026-05-13
-------------------

  * `_ir_validate_counts` array-count invariants; `_ir_validate_keys` `_tmpfile_key` collision refuse; `_init_runtime` precomputes caches before sudo write; `_RY_POST_HOOKS` first-match table for `--install-file` hooks.

v6.2.0 - 2026-05-12
-------------------

  * `--install-file` single-file redeploy with per-target post-hook dispatch (paths via `realpath -m`); argparse `--exclusive` mode group; atomic mkdir + pid-file lock with dead-PID stale-lock reclaim.

v6.1.0 - 2026-05-12
-------------------

  * User-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running` probes, replacing the systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 -> 4985 LOC: drop GNU-tool sanity probes, source-mode scaffolding (`_ry_bail_check` + 34 sites), ntsync per-kernel probes, sudo-keepalive (+19 sites), JSONL progress events, tail-of-script log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gate family, LVM detection.
