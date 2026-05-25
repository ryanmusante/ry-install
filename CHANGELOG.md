ry-install ChangeLog

v7.6.15 - v7.6.16 - 2026-05-25

- `_vrk_cpu_state` expected `scaling_governor` changes from `performance` to `powersave`; expected `energy_performance_preference` changes from `performance` to `balance_performance` (kernel default under `amd_pstate=active` + governor `powersave`); `_post_cpupower` info string rewritten to reflect that EPP is independently configurable when governor is not `performance`.

v7.6.14 - v7.6.15 - 2026-05-25

- `CPUPOWER_GOVERNOR` changes from `balanced` to `powersave` (`balanced` is not a valid cpufreq governor under `amd_pstate=active`; `powersave` is the kernel-accepted name with EPP routing the energy/performance preference).

v7.6.13 - v7.6.14 - 2026-05-25

- `KERNEL_PARAMS` gains `amdgpu.dcdebugmask=0x12` and `amdgpu.gpu_recovery=1` (count 15→17); `CPUPOWER_GOVERNOR` changes from `performance` to `balanced`; `_ir_validate_counts` `KERNEL_PARAMS` invariant bumped 15→17.

v7.6.12 - v7.6.13 - 2026-05-25

- `_vrk_audio_state` consumes pre-extracted `_RY_DMESG_ACP` so the once/boot ACP machine-driver marker survives the 5000-line dmesg cap; `_if_trim_pacman_cache` also runs on `PKGS_DEL` removals (not only on `pacman -Syu` upgrades).

v7.6.11 - v7.6.12 - 2026-05-25

- `_ry_do_install` drops dead `EXIT_USAGE` remap branch; `_install_preflight` gains `_chk_labels` size-drift assertion; README sudoers phrasing clarified; log-prune `find` example gains `-type f` guard.

v7.6.10 - v7.6.11 - 2026-05-24

- `wc` added to required deps; paru `--version` unparseable now warns; argparse error stderr ANSI-stripped; `--install-file` rejects all C0/DEL controls (was newline-only) and fail-closes on `wc -c` parse failure; pre-existing `LOG_FILE` symlink removed before chmod 600; README log-prune `find` gains `-xdev`.

v7.6.9 - v7.6.10 - 2026-05-24

- README prose trimmed across WARNING, Hardware, Configuration, Run Summary, fstab, Env, Known Issues, Troubleshooting; stale Runtime-variables count 10 → 9 corrected; 3 verbose script comments trimmed.

v7.6.8 - v7.6.9 - 2026-05-24

- Wireless-regdom feature removed (3 functions, env var, Phase 1 step, README rows, `--help` line).

v7.6.7 - v7.6.8 - 2026-05-24

- README WARNING block, Install Flow, Phase 1 tables trimmed; Packages-install (5/15), Packages-remove (5/11), Masked-units (7/12) regrouped.

v7.6.6 - v7.6.7 - 2026-05-24

- `_acquire_lock_fresh` distinguishes EEXIST from other mkdir errors; `_acquire_lock` and `_dc_kill_children` symlink-guard `LOCK_DIR`; `_phase_record` sanitises result/check/evidence; README sudoers scoped, PGP/TOCTOU/0600/SIGKILL clarifications.

v7.6.5 - v7.6.6 - 2026-05-24

- `_post_service` routes `*/.config/systemd/user/*` targets via `systemctl --user`; `_init_runtime` CPU-model check fails closed; AUR PGP hint reworded; README warns `IgnorePkg=linux-firmware` blocks future CVE fixes.

v7.6.4 - v7.6.5 - 2026-05-24

- `_fail_silent` renamed to `_fail_no_count`; `_acquire_lock` stale-PID reclaim simplified to `kill -0`; `_mr_copy_size_verify` drops redundant size compare (cmp covers length+content).

v7.6.3 - v7.6.4 - 2026-05-24

- `_chk_perms` refuses 4-digit `stat -c %a` modes (setuid/sgid/sticky); `_ry_validate_configs` validates iwd-gated content unconditionally; preflight gains GNU `date '+%z'` probe.

v7.6.2 - v7.6.3 - 2026-05-24

- `_dc_kill_children` `command sleep 0.5` gains `</dev/null` so stdin closure does not hang under cron / systemd unit.

v7.6.1 - v7.6.2 - 2026-05-24

- JSONL header `printf` format inlined as literal (no variable-as-format-arg surface); `_set_exit` definition lifted above `_acquire_lock` call site.

v7.6 - v7.6.1 - 2026-05-24

- `_ntsync_state` `CONFIG_NTSYNC=y` `grep -q` gains `2>/dev/null` for stderr symmetry with sibling probes.

v7.5 - v7.6 - 2026-05-24

- `_ry_do_install_file` gains iwd-gate pre-check; `_post_nm` defensive `pacman -Qi iwd` precheck; run-summary matrix rows added for `PKGS_DEL`/mask/enable; `_install_fstab_opts` moved into `_install_configure_services`; stable v7.5 cut.

v7.4 - v7.5 - 2026-05-21 to 2026-05-23

- `_check_boot_taint_gate` extracted; `_mkinitcpio_revert` and `_fstab_atomic_replace` tmpfile parent moved `/run/ry-install` → `/etc` for same-FS atomic `rename(2)`; `--install-file` path-length check char → byte; kernel <6.14 hard-floor FAIL; AWK pipeline collapsed to single sudo-awk; LOC 5113 → 4468; box-drawn Unicode run-summary matrix; `RY_INSTALL_NO_MATRIX` env var added.

v7.4.0 - v7.4.5 - 2026-05-20

- Preflight + lock + sudo cache redesign; fish-version flat sentinel; `_acquire_lock` `/proc/$pid/comm` race close; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out; LOC 5204 → 5113.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19

- Major preflight hardening; `_RY_LOUD_ERR` default-quiet; `_ir_resolve_root_uuid` 4-way mode dispatch; systemd <250 hard-fail; `EXIT_RUN_TMPFAIL` sentinel; LOC 5177 → 4842.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17

- NM 1.56.0 compat; `MASK` += avahi.service/.socket (10 → 12); `PKGS_ADD` += `realtime-privileges`, `cpupower`; `PKGS_DEL` += `bolt`; new `_vrk_audio_state`; managed-file count 13 → 12.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994 → 4985 LOC); drop scaffolding; add user-bus detection, `printf`-only emitters, split `_run`, `_atomic_write_file` post-write symlink re-check, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
