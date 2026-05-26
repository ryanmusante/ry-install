ry-install ChangeLog

v7.6.28 - v7.6.29 - 2026-05-26

- README: 5 collapsibles regrouped by functional `Category` column (kernel cmdline 6 cats, bootloader 3 cats replacing `File` column, env vars 5 cats, masked units 4 cats, exit codes 5 cats); Destinations unchanged. No script behavior change; KERNEL_PARAMS / ENV_VARS / MASK counts unchanged.

v7.6.27 - v7.6.28 - 2026-05-26

- `KERNEL_PARAMS` net 18 (add `nvme_core.default_ps_max_latency_us=0`, drop `usb4_dma_protection=off`).
- `_vrk_module_state` nvme_core check inverted: now PASS when `default_ps_max_latency_us` reads `0` (APST disabled matches boot param); bespoke 8-line block collapsed into single `_chk_sysfs_eq` call to match adjacent style.
- README kernel cmdline table regenerated.

v7.6.26 - v7.6.27 - 2026-05-26

- `KERNEL_PARAMS` count 19→18; drop `iommu=pt` (inert under `amd_iommu=off`); `_ir_validate_counts` synced.
- README kernel cmdline table regenerated.

v7.6.25 - v7.6.26 - 2026-05-26

- CHANGELOG: trim v7.6.24, v7.6.25 prose entries to bulleted form (kernel.org style).
- No functional changes; script + README unchanged from v7.6.25.

v7.6.24 - v7.6.25 - 2026-05-26

- `KERNEL_PARAMS` count 15→19; `_ir_validate_counts` synced.
  - add: `amd_iommu=off`, `amdgpu.cwsr_enable=0`, `amdgpu.gttsize=126976`, `pcie_aspm=off`, `processor.max_cstate=1`, `ttm.pages_limit=32505856`, `usb4_dma_protection=off`.
  - drop: `module_blacklist=pcspkr`, `pcie_aspm.policy=performance`, `ttm.pages_limit=4194304`.
- README kernel cmdline table regenerated.

v7.6.23 - v7.6.24 - 2026-05-26

- `_run`: `RUN_ABORT` JSONL event embeds `cmd=$log_cmd` for single-line post-mortem grep. No behavior change.

v7.6.22 - v7.6.23 - 2026-05-25

- `SYSCTL_VALUES` drops `kernel.sched_migration_cost_ns=5000000` (moved to debugfs in kernel 5.13; renamed `migration_cost_base_ns` under BORE 5.7+; not exposed as sysctl on current CachyOS kernels — produced runtime WARN) and `vm.swappiness=10` (overridden post-sysctl by vendor `cachyos-settings` udev rule `/usr/lib/udev/rules.d/30-zram.rules` setting `SYSCTL{vm.swappiness}="150"` on zram0 init — produced runtime FAIL) (count 10→8); `_ir_validate_counts` invariants synced.

v7.6.21 - v7.6.22 - 2026-05-25

- `KERNEL_PARAMS` drops `loglevel=3`, `rd.systemd.show_status=auto`, `rd.udev.log_level=3` (count 18→15); `ENV_VARS` drops `ENABLE_LAYER_MESA_ANTI_LAG=1` (count 11→10); `_ir_validate_counts` invariants synced; README `quiet`+`loglevel=3` boot-splash prose collapsed to `quiet`.

v7.6.20 - v7.6.21 - 2026-05-25

- `KERNEL_PARAMS` drops `mitigations=off` (count 19→18); `ENV_VARS` drops `MESA_DISK_CACHE_SINGLE_FILE=1` (count 12→11); `_ir_validate_counts` invariants synced.

v7.6.19 - v7.6.20 - 2026-05-25

- `KERNEL_PARAMS` gains `mitigations=off`, `preempt=full`, `ttm.pages_limit=4194304` (count 16→19); `ENV_VARS` drops `PROTON_USE_NTSYNC` (default in proton-cachyos), gains `ENABLE_LAYER_MESA_ANTI_LAG=1`, `MESA_DISK_CACHE_SINGLE_FILE=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `RADV_PERFTEST` `sam,nircache`→`gpl,nircache` (count 10→12); `SYSCTL_VALUES` gains `kernel.sched_migration_cost_ns=5000000`, `net.ipv4.tcp_notsent_lowat=16384`, `vm.dirty_background_bytes=67108864`, `vm.dirty_bytes=268435456`, `vm.swappiness=10` (count 5→10); `_ir_validate_counts` invariants synced.

v7.6.18 - v7.6.19 - 2026-05-25

- `SYSCTL_VALUES` trimmed 16→5 (kept: `default_qdisc=fq`, `tcp_congestion_control=bbr`, `tcp_slow_start_after_idle=0`, `vm.compaction_proactiveness=0`, `vm.max_map_count=2147483642`); dropped 9 net.* tunables that duplicate CachyOS vendor defaults or oversize buffers for sub-10G home networks; dropped `vm.watermark_boost_factor=0` (worsens fragmentation), `fs.protected_{fifos,regular}=2` (security hardening, not performance); `_ir_validate_counts` SYSCTL_VALUES invariant synced.

v7.6.17 - v7.6.18 - 2026-05-25

- `KERNEL_PARAMS` gains `8250.nr_uarts=0` (count 15→16; masks phantom ttyS1 device, saves ~4.25s boot); `_vrkg_vram` removed and `_vrk_gpu_state` no longer reports BIOS VRAM carveout (UMA Frame Buffer Size sized at BIOS, not driver concern); `_ir_validate_counts` KERNEL_PARAMS invariant synced.

v7.6.16 - v7.6.17 - 2026-05-25

- `KERNEL_PARAMS` drops `amdgpu.cwsr_enable=0` and `amdgpu.dcdebugmask=0x12` (count 17→15); `ENV_VARS` drops `RADV_EXPERIMENTAL=transfer_queue` (count 11→10); `_vrkm_amdgpu` validator drops `cwsr_enable:0` pair; `_ir_validate_counts` invariants synced; README Known-Issues CWSR row removed.

v7.6.15 - v7.6.16 - 2026-05-25

- `_vrk_cpu_state` expected `scaling_governor` `performance`→`powersave`, expected `energy_performance_preference` `performance`→`balance_performance` (kernel default under `amd_pstate=active` + governor `powersave`); `_post_cpupower` info string reflects EPP independence when governor is not `performance`.

v7.6.14 - v7.6.15 - 2026-05-25

- `CPUPOWER_GOVERNOR` `balanced`→`powersave` (`balanced` invalid under `amd_pstate=active`; `powersave` routes EPP).

v7.6.13 - v7.6.14 - 2026-05-25

- `KERNEL_PARAMS` gains `amdgpu.dcdebugmask=0x12` and `amdgpu.gpu_recovery=1` (count 15→17); `CPUPOWER_GOVERNOR` `performance`→`balanced`.

v7.6.12 - v7.6.13 - 2026-05-25

- `_vrk_audio_state` consumes pre-extracted `_RY_DMESG_ACP` (survives 5000-line dmesg cap); `_if_trim_pacman_cache` also runs on `PKGS_DEL` removals.

v7.6.11 - v7.6.12 - 2026-05-25

- `_ry_do_install` drops dead `EXIT_USAGE` branch; `_install_preflight` gains `_chk_labels` size-drift assertion; log-prune `find` example gains `-type f` guard.

v7.6.10 - v7.6.11 - 2026-05-24

- `wc` added to required deps; argparse error stderr ANSI-stripped; `--install-file` rejects all C0/DEL controls and fail-closes on `wc -c` parse failure; pre-existing `LOG_FILE` symlink removed before chmod 600.

v7.6.9 - v7.6.10 - 2026-05-24

- README prose trimmed; stale Runtime-variables count 10→9 corrected.

v7.6.8 - v7.6.9 - 2026-05-24

- Wireless-regdom feature removed (3 functions, env var, Phase 1 step, README rows, `--help` line).

v7.6.7 - v7.6.8 - 2026-05-24

- README WARNING, Install Flow, Phase 1 tables trimmed; Packages-install, Packages-remove, Masked-units regrouped.

v7.6.6 - v7.6.7 - 2026-05-24

- `_acquire_lock_fresh` distinguishes EEXIST from other mkdir errors; `_acquire_lock` and `_dc_kill_children` symlink-guard `LOCK_DIR`; `_phase_record` sanitises result/check/evidence.

v7.6.5 - v7.6.6 - 2026-05-24

- `_post_service` routes `*/.config/systemd/user/*` targets via `systemctl --user`; `_init_runtime` CPU-model check fails closed.

v7.6.4 - v7.6.5 - 2026-05-24

- `_fail_silent` renamed to `_fail_no_count`; `_acquire_lock` stale-PID reclaim simplified to `kill -0`; `_mr_copy_size_verify` drops redundant size compare.

v7.6.3 - v7.6.4 - 2026-05-24

- `_chk_perms` refuses 4-digit `stat -c %a` modes (setuid/sgid/sticky); `_ry_validate_configs` validates iwd-gated content unconditionally; preflight gains GNU `date '+%z'` probe.

v7.6.2 - v7.6.3 - 2026-05-24

- `_dc_kill_children` `command sleep 0.5` gains `</dev/null` so stdin closure does not hang under cron / systemd unit.

v7.6.1 - v7.6.2 - 2026-05-24

- JSONL header `printf` format inlined as literal (no variable-as-format-arg surface); `_set_exit` definition lifted above `_acquire_lock` call site.

v7.6 - v7.6.1 - 2026-05-24

- `_ntsync_state` `CONFIG_NTSYNC=y` `grep -q` gains `2>/dev/null` for stderr symmetry with sibling probes.

v7.5 - v7.6 - 2026-05-24

- Stable v7.6 cut; `_ry_do_install_file` iwd-gate pre-check; `_post_nm` `pacman -Qi iwd` precheck; run-summary matrix rows added; `_install_fstab_opts` folded into `_install_configure_services`.

v7.4 - v7.5 - 2026-05-21 to 2026-05-23

- `_check_boot_taint_gate` extracted; `_mkinitcpio_revert` / `_fstab_atomic_replace` tmpfile moved to `/etc` for same-FS atomic `rename(2)`; kernel <6.14 hard-floor FAIL; box-drawn Unicode run-summary matrix; LOC 5113→4468.

v7.4.0 - v7.4.5 - 2026-05-20

- Preflight + lock + sudo cache redesign; `_acquire_lock` `/proc/$pid/comm` race close; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out; LOC 5204→5113.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19

- Preflight hardening; `_ir_resolve_root_uuid` 4-way mode dispatch; systemd <250 hard-fail; `EXIT_RUN_TMPFAIL` sentinel; LOC 5177→4842.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17

- NM 1.56.0 compat; `MASK` += avahi.service/.socket (10→12); `PKGS_ADD` += `realtime-privileges`, `cpupower`; `PKGS_DEL` += `bolt`; new `_vrk_audio_state`; managed-file count 13→12.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994→4985 LOC); user-bus detection, `printf`-only emitters, split `_run`, `_atomic_write_file` post-write symlink re-check, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
