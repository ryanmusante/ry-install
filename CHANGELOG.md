ry-install ChangeLog
====================

v6.5.11 - 2026-05-15
--------------------

  * _ry_exit: bail path writes JSONL footer (`extra_key=bail`) when header already written; previously preflight / `_init_runtime` / `_acquire_lock` failures left no footer.

  * _cleanup_pipe: gate SIGPIPE _log on `_RY_HEADER_WRITTEN` — prevents headerless `preflight-*.jsonl` from short-read consumers (`--help | head -5`).

  * _vrsv_wifi `string match -rg '^wifi:(.*)$'` + _bootctl_dir `string trim -r -c /`: added missing `--` separators (v6.5.3 / v6.5.9 sweep consistency).

  * README badge -> 6.5.11; data-directory section documents the three footer extra-key markers (`interrupted`, `cleanup_exit`, `bail`).

v6.5.10 - 2026-05-15
--------------------

  * _enum_boot_entries: dropped write-only `_RY_BOOT_PIPE_OK` / `_RY_BOOT_HASH` globals + redundant `sort -z` stage; _dc_erase_globals trimmed to match.

  * _awf_finalize_mv: removed dead `dst_dir` local (v6.2.9 missed when sibling local cleared from _atomic_write_file).

  * _verify_unit_syntax: dropped redundant empty `set user_flag` in `system` branch; collapsed to `!= system`.

  * 4997 -> 4990 lines; README badge -> 6.5.10.

v6.5.9 - 2026-05-15
-------------------

  * _verify_unit_syntax: VERIFY_UNIT_WARN/_ERR `_log` calls pipe multi-line `systemd-analyze` stderr through `string join '; '` (suppress fish Cartesian product).

  * _vrs_installed_file_perms: emit aggregate `perm_vfat_skipped` count when non-zero.

  * _verify_static_syntax: removed dead `grep -v '^#'` stage from HOOKS-line extraction (preceding `^[[:space:]]*HOOKS=` anchor already excludes comment lines).

  * Style: four `string trim` sites normalised to `string trim --`. 4996 -> 4997 lines; README badge -> 6.5.9.

v6.5.8 - 2026-05-15
-------------------

  * Top-level dispatcher: two pre-header `_warn` calls (realpath -m failure on --install-file value; log-rename failure) replaced with direct `echo >&2` — both previously emitted JSONL `log` ahead of `header`.

v6.5.7 - 2026-05-14
-------------------

  * _init_runtime KERNEL_PARAMS metachar regex: fish single-quote collapsed `\\` → one `\`, PCRE silently accepted shell metachars; source `\\` → `\\\\`; swept other 93 `string match -qr` patterns clean.

v6.5.6 - 2026-05-14
-------------------

  * _msg: dropped `VERIFY_MODE` gate so OK/WARN/FAIL counters track install + install-file modes; removed five dead `set -g VERIFY_MODE` writes; README jq snippet updated to match footer schema.

v6.5.5 - 2026-05-14
-------------------

  * _chk_grep: stage 2 runs `grep -wF` (was `grep -q`, SIGPIPE-killed stage 1 on files larger than pipe buffer).

  * _far_awk_rewrite: awk/tee stderr tmpfiles renamed `.ry-install.{tee,awk}-err.XXXXXX` -> `ry-{fstab-tee,fstab-awk}-err.XXXXXX`; matching globs added to `_dc_sweep_filesystem`.

v6.5.4 - 2026-05-14
-------------------

  * _check_phase_units: NetworkManager-dispatcher.service accepts `static`; systemd-resolved.service still requires `enabled`.

  * _far_awk_rewrite: awk/tee stderr tmpfiles via `_mktemp_or_null` (bare `mktemp` returned empty on alloc failure).

  * _dc_sweep_filesystem: dropped vestigial `ry-ka-err.*` glob (sudo-keepalive removed in v6.0); _rdi_run_phases: removed five unreachable `_RY_INSTALL_BAILING` guards.

  * README: Prerequisites Tooling row marks `ip(8)` recommended.

v6.5.3 - 2026-05-14
-------------------

  * Dispatch: bundled short flags (`-hV`, `-hv`) route through argparse `_flag_help` / `_flag_version` post-block (early-exit `switch` only matched exact tokens).

  * _ry_mkinitcpio_array, _verify_static_syntax, _vrsv_wifi, _is_wifi_active_route: `--` added before `grep` patterns and `basename` arguments.

  * Preflight: non-absolute TMPDIR falls back to /tmp with `[WARN]` before writability probe.

  * README: removed stale `.boot-wipe-acknowledged` reference; three sub-sections converted to tables; added Contents nav; trimmed Prerequisites/Hardware paragraphs.

v6.5.2 - 2026-05-14
-------------------

  * Script header version string bumped (was `v6.5` in line-2 comment despite VERSION global + README badge at 6.5.1).

  * sha256sum / dispatcher / preflight: bare `sha256sum` -> `command sha256sum`; unreachable empty-`INSTALL_FILE_TARGET` guard removed; four uniform preflight blocks collapsed into a for-loop. _resolve_esp / _resolve_boot_path factored shared bootctl probe into `_bootctl_dir`.

v6.5.1 - 2026-05-14
-------------------

  * _resolve_esp / _resolve_boot_path: hard-fail cached on `_RY_ESP_TRIED` / `_RY_BOOT_TRIED` sentinels (previous `test -n` guard treated cached empty as "not cached" and re-ran autodetect).

  * _run_emit_stream: `wc -l` adds one when captured file's last byte is not a newline (suppressed `*_TRUNCATED` marker on truncated-without-newline output).

  * _vre_zram: ZRAM service check derives instance name from live `swapon` device (was hard-coded `zram0`).

  * _post_service / _csm_retry_individual / _cleanup_other / _ip_pacman_invoke: dropped dead `$HOME/*` user-unit branch, redundant per-unit re-filter, redundant `_CLEANUP_DONE` guard, vestigial boot-wipe marker family.

  * README: documented that the ext4 fstab rewrite drops `defaults` and normalises atime/commit options; mount semantics unchanged.

v6.5 - 2026-05-14
-----------------

  * _dc_sweep_tmpfiles spurious-TMPFILE_STUCK fix (or-chain precedence); _verify_static_services multi-ExecStart guard; 14 head/tail sites use `command` prefix; _json_str drops unreachable NUL escape; _run_emit_stream / _ry_do_install / argparse comment trims; README badge -> 6.5.

v6.4 - 2026-05-14
-----------------

  * _vsb_entries distinguishes lapsed-sudo / unresolved-$BOOT from genuine-empty entries dir; _ry_check_deps adds 10 coreutils + reuses _resolve_systemd_ver; _progress_init skipped under NO_COLOR; dead `; or set _ret 1` clauses dropped; LC_ALL=C normalized to `env` prefix; _run_emit_stream / _ry_do_install comments; db.lck message wording; README badge -> 6.4 + logind.conf.d MISMATCH troubleshooting row.

v6.3 - 2026-05-14
-----------------

  * _dc_sweep_tmpfiles logs TMPFILE_STUCK before erase; header-write sets log-write-fail sentinel; _err_loud deduped via `_msg_print --force`; six _msg wrappers + content generators collapsed to one line; _is_wifi_active_route / _ry_check_network loop-folded; _vrsv_chk_nm_dispatcher accepts `static`; _tmpfile_key / _run / _vre_thp_ksm / _json_str rewrites; README reference tables trimmed.

v6.2.13 - 2026-05-14
--------------------

  * _run split into _run / _run_redact_cmd / _run_effective_timeout; cpupower-epp `$$cpu` rationale comment collapsed to one line.

v6.2.12 - 2026-05-14
--------------------

  * Content-equality compare via `string collect` (space-vs-newline token-boundary bug, pipestatus[1] recovery); _run_emit_stream / _echo / _csm_filter_units / _csp_filter_rdeps emit via `printf` (echo flag-injection); _write_footer extra_key through _json_str; _verify_static_syntax HOOKS `string trim`; _progress_init bails under $ZELLIJ; cpupower-epp `$$cpu` inline comment.

v6.2.11 - 2026-05-13
--------------------

  * _csp_filter_rdeps pipestatus gate narrowed to stage 1; JSONL header before _init_runtime; lazy _log creation, eager top-level removed; root-check hoisted after UID parse; LOCK_DIR chmod 700 + _RY_LOCK_DIR_OWNED set post-mkdir; _verify_unit_syntax / _post_* `--argument-names`; _early_usage_exit prints help; updatedb / pkgfile timeout-bypass; TMPDIR / HOME preflight hardening; _vrs_boot_perf parse anchor; _vsc_static_checksum log wording; _cse_collect_units printf; _dc_erase_globals additions; drop dead _RY_TIMEOUT_OK.

v6.2.10 - 2026-05-14
--------------------

  * _ry_check_deps adds `grep`; pacman -Qq / -T status capture across verify + remove paths; _idf_match_dst single-token return; logind HandleSecureAttentionKey explicit if-block; _vsb_mkinitcpio per-token COMPRESSION_OPTIONS match; _verify_runtime_kparams dmesg-slice precompute; _pb_rebuild_cascade dead local; --description trims; _msg_print / _dc_erase_globals / EXIT_* / boot-time `-le` / dispatch QUIET style cleanups; 5054 -> ~5008 LOC.

v6.2.9 - 2026-05-13
-------------------

  * HOME field-6 via `awk -F:` (GECOS-tolerant); _atomic_write_file dead local removed; _ry_check_deps adds `mv`; verbose `--description` strings collapsed to leading clause.

v6.2.8 - 2026-05-13
-------------------

  * Log rename + _acquire_lock before JSONL header; _install_preflight early-returns set _PROG_FINALIZED_SKIP; empty-message short-circuit hoisted to callers; _dc_erase_globals symmetry; _csp_filter_rdeps pipestatus widened; _csp_remove_pkgs visible _ok; _progress_init read-only TTY probe; _ry_do_install dead arg dropped.

v6.2.7 - 2026-05-13
-------------------

  * user destinations 0600; _as BUG rc -> 250; _run sudo-bypass dash-flag scan; _run tmpdir-alloc rc 251; STDOUT label; optional-tool absences batched; _vmh_order_checks / _far_awk_rewrite / _is_system_dst / _dc_sweep_filesystem / _install_aur_packages / _post_service tweaks; explicit `return 0` across 11 sites; cat `--` drop on lock reads; `set -e` -> `set --erase`; two unreachable _RY_INSTALL_BAILING checks removed; dead intermediates dropped; sourcing-guard simplified.

v6.2.6 - 2026-05-13
-------------------

  * Top-level array declarations wrap one element per continuation line for diff granularity.

v6.2.5 - 2026-05-13
-------------------

  * _pbs_check_boot_files snapshots `$pipestatus` before _pipe_all_ok; dead `functions -q _warn` guard dropped from _ry_mkinitcpio_array; ~52 standalone _echo blank-line separators collapsed.

v6.2.4 - 2026-05-13
-------------------

  * _run timeout-bypass for pacman / paru / mkinitcpio / sdboot-manage / paccache (TIMEOUT_BYPASS marker); tmpfile-path redaction under $TMPDIR; `command timeout` refuses if timeout(1) absent; capture cap 100 -> 500 with _TRUNCATED sentinels; _err_loud always emits regardless of QUIET; _vsb_sdboot quote-count == 2 guard.

v6.2.3 - 2026-05-13
-------------------

  * _ip_pacman_invoke -Syyu retry / -Sy gated on RY_INSTALL_ALLOW_PARTIAL_UPGRADE; _install_aur_packages per-pkg retry; .pacnew auto-resolve at managed paths; _vrkg_perf_level per-card scan; _vrkg_rebar_sam dmesg + lspci fallback; _vrkg_vram BIOS carveout check.

v6.2.2 - 2026-05-13
-------------------

  * _atomic_write_file post-write symlink re-check (TOCTOU); _ry_install_file skip-probe via _installed_bytes; _fstab_atomic_replace findmnt --verify hard-fail; _vrs_nm_perms pipestatus; _vrs_parent_dirs refuses group/world-writable parents; _vrs_vulkan EXPECTED_VULKAN_PKGS check; _post_boot force-rebuild taint-gate parity.

v6.2.1 - 2026-05-13
-------------------

  * _ir_validate_counts array-count invariants; _ir_validate_keys _tmpfile_key collision refuse; _init_runtime precomputes caches before any sudo write; _RY_POST_HOOKS first-match table for --install-file hooks.

v6.2.0 - 2026-05-12
-------------------

  * --install-file single-file redeploy with per-target post-hook dispatch (paths canonicalised via `realpath -m`); argparse --exclusive mode group + post-`--` positional reject; atomic mkdir + pid-file lock with dead-PID stale-lock reclaim.

v6.1.0 - 2026-05-12
-------------------

  * user-bus detection via inline `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running` probes, replacing the systemd-keepalive workaround.

v6.0.0 - 2026-05-12
-------------------

  * Reduction release 5994 -> 4985 LOC: drop GNU-tool sanity probes, source-mode scaffolding (_ry_bail_check + 34 sites, _ry_namespace_cleanup), ntsync per-kernel probes, _validate_kernel_params, _ir_validate_timing, sudo-keepalive (+ 19 sites), _progress* + JSONL progress events, tail-of-script log rotation, parallel-child PID guard, _redact_*, atomic-write TOCTOU re-stat, boot-wipe gate family, .lock-broker artifact, LVM detection.
