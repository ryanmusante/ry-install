ry-install ChangeLog

v7.8.4 - v7.8.5 - 2026-05-27

- CHANGELOG: aggressive trim across all historical stanzas (drop "README regenerated", "invariants synced", explanatory parentheticals; collapse multi-bullet entries).

v7.8.3 - v7.8.4 - 2026-05-27

- Script: trim 7 verbose comments.
- CHANGELOG: trim verbose recent + 6 historical stanzas.

v7.8.2 - v7.8.3 - 2026-05-27

- README `Packages — remove`: convert to standard `Package | Category` form (7 rows).

v7.8.1 - v7.8.2 - 2026-05-27

- README: remove orphan pointer note after `Packages — AUR` collapsible.
- Script: trim four narrative comments.

v7.8.0 - v7.8.1 - 2026-05-27

- `KERNEL_PARAMS` 14→15: +`pcie_aspm.policy=performance`.

v7.7.3 - v7.8.0 - 2026-05-26

- `ENV_VARS`: drop `gpl` from `RADV_PERFTEST`.
- `PKGS_ADD`: +`lact-git` opt-in trailing comment.
- Managed files 12→13: +`/etc/modprobe.d/ry-amdgpu-strixhalo.conf` (ttm sizing; ROCm#5595). `_RY_POST_HOOKS` 14→15.
- `KERNEL_PARAMS` 18→14: drop `amdgpu.gttsize`, `processor.max_cstate=1`, `pcie_aspm=off`, `ttm.pages_limit`; replace `amd_iommu=off` → `iommu=pt`.
- `AUR_PKGS`: chip-gated `r8127-dkms` (Realtek RTL8127; BBS#7762); dynamic 2-or-3 validator.

v7.7.2 - v7.7.3 - 2026-05-26

- `PKGS_DEL` 8→7: `shelly` removed → manual opt-in.

v7.7.1 - v7.7.2 - 2026-05-26

- README: `shelly` recategorized `misc` → `package manager`.

v7.7.0 - v7.7.1 - 2026-05-26

- `PKGS_DEL` 11→8: -`octopi`, -`btop`, -`bolt`, -`plasma-thunderbolt`, +`shelly`.

v7.6.30 - v7.7.0 - 2026-05-26

- Minor bump; counts verified in sync.

v7.6.29 - v7.6.30 - 2026-05-26

- README: 3 ≥10-entry collapsibles → 2-column Category form.

v7.6.28 - v7.6.29 - 2026-05-26

- README: 5 collapsibles regrouped by `Category` column.

v7.6.27 - v7.6.28 - 2026-05-26

- `KERNEL_PARAMS` net 18: +`nvme_core.default_ps_max_latency_us=0`, -`usb4_dma_protection=off`; `_vrk_module_state` nvme_core check inverted (PASS when APST disabled).

v7.6.26 - v7.6.27 - 2026-05-26

- `KERNEL_PARAMS` 19→18: -`iommu=pt` (inert under `amd_iommu=off`).

v7.6.25 - v7.6.26 - 2026-05-26

- CHANGELOG style cleanup.

v7.6.24 - v7.6.25 - 2026-05-26

- `KERNEL_PARAMS` 15→19: +`amd_iommu=off`, +`amdgpu.cwsr_enable=0`, +`amdgpu.gttsize=126976`, +`pcie_aspm=off`, +`processor.max_cstate=1`, +`ttm.pages_limit=32505856`, +`usb4_dma_protection=off`; -`module_blacklist=pcspkr`, -`pcie_aspm.policy=performance`, -`ttm.pages_limit=4194304`.

v7.6.23 - v7.6.24 - 2026-05-26

- `_run`: `RUN_ABORT` JSONL embeds `cmd=$log_cmd` for grep.

v7.6.22 - v7.6.23 - 2026-05-25

- `SYSCTL_VALUES` 10→8: -`kernel.sched_migration_cost_ns` (debugfs since 5.13), -`vm.swappiness=10` (vendor override).

v7.6.21 - v7.6.22 - 2026-05-25

- `KERNEL_PARAMS` 18→15: -`loglevel=3`, -`rd.systemd.show_status=auto`, -`rd.udev.log_level=3`; `ENV_VARS` 11→10: -`ENABLE_LAYER_MESA_ANTI_LAG=1`.

v7.6.20 - v7.6.21 - 2026-05-25

- `KERNEL_PARAMS` 19→18: -`mitigations=off`; `ENV_VARS` 12→11: -`MESA_DISK_CACHE_SINGLE_FILE=1`.

v7.6.19 - v7.6.20 - 2026-05-25

- `KERNEL_PARAMS` 16→19: +`mitigations=off`, +`preempt=full`, +`ttm.pages_limit=4194304`.
- `ENV_VARS` 10→12: -`PROTON_USE_NTSYNC`, +`ENABLE_LAYER_MESA_ANTI_LAG`, +`MESA_DISK_CACHE_SINGLE_FILE`, +`PROTON_FSR4_RDNA3_UPGRADE`; `RADV_PERFTEST` `sam,nircache`→`gpl,nircache`.
- `SYSCTL_VALUES` 5→10.

v7.6.18 - v7.6.19 - 2026-05-25

- `SYSCTL_VALUES` 16→5; drop vendor-duplicate `net.*` + `vm.watermark_boost_factor=0` + `fs.protected_{fifos,regular}`.

v7.6.17 - v7.6.18 - 2026-05-25

- `KERNEL_PARAMS` 15→16: +`8250.nr_uarts=0`; `_vrkg_vram` removed.

v7.6.16 - v7.6.17 - 2026-05-25

- `KERNEL_PARAMS` 17→15: -`amdgpu.cwsr_enable=0`, -`amdgpu.dcdebugmask=0x12`; `ENV_VARS` 11→10: -`RADV_EXPERIMENTAL=transfer_queue`.

v7.6.15 - v7.6.16 - 2026-05-25

- `_vrk_cpu_state` expected `scaling_governor` `performance`→`powersave`; `energy_performance_preference` `performance`→`balance_performance`.

v7.6.14 - v7.6.15 - 2026-05-25

- `CPUPOWER_GOVERNOR` `balanced`→`powersave`.

v7.6.13 - v7.6.14 - 2026-05-25

- `KERNEL_PARAMS` 15→17: +`amdgpu.dcdebugmask=0x12`, +`amdgpu.gpu_recovery=1`; `CPUPOWER_GOVERNOR` `performance`→`balanced`.

v7.6.12 - v7.6.13 - 2026-05-25

- `_vrk_audio_state` consumes pre-extracted `_RY_DMESG_ACP`; `_if_trim_pacman_cache` runs on `PKGS_DEL` removals.

v7.6.11 - v7.6.12 - 2026-05-25

- `_ry_do_install` drops dead `EXIT_USAGE` branch; `_install_preflight` gains `_chk_labels` size-drift assertion.

v7.6.10 - v7.6.11 - 2026-05-24

- `wc` added to required deps; argparse stderr ANSI-stripped; `--install-file` rejects C0/DEL controls + fail-closes on `wc -c` parse failure.

v7.6.9 - v7.6.10 - 2026-05-24

- README prose trimmed; Runtime-variables count 10→9.

v7.6.8 - v7.6.9 - 2026-05-24

- Wireless-regdom feature removed.

v7.6.7 - v7.6.8 - 2026-05-24

- README WARNING, Install Flow, Phase 1 tables trimmed; Packages + Masked-units regrouped.

v7.6.6 - v7.6.7 - 2026-05-24

- `_acquire_lock_fresh` distinguishes EEXIST; `_acquire_lock` + `_dc_kill_children` symlink-guard `LOCK_DIR`; `_phase_record` sanitises fields.

v7.6.5 - v7.6.6 - 2026-05-24

- `_post_service` routes user-scope `*/.config/systemd/user/*` via `systemctl --user`; `_init_runtime` CPU-model check fails closed.

v7.6.4 - v7.6.5 - 2026-05-24

- `_fail_silent` → `_fail_no_count`; `_acquire_lock` stale-PID reclaim simplified to `kill -0`.

v7.6.3 - v7.6.4 - 2026-05-24

- `_chk_perms` refuses setuid/sgid/sticky modes; `_ry_validate_configs` validates iwd-gated content unconditionally; preflight `date '+%z'` probe.

v7.6.2 - v7.6.3 - 2026-05-24

- `_dc_kill_children` `command sleep 0.5` gains `</dev/null` (cron/systemd stdin hang fix).

v7.6.1 - v7.6.2 - 2026-05-24

- JSONL header `printf` format inlined as literal; `_set_exit` definition lifted above `_acquire_lock` call.

v7.6 - v7.6.1 - 2026-05-24

- `_ntsync_state` `CONFIG_NTSYNC=y` `grep -q` gains `2>/dev/null`.

v7.5 - v7.6 - 2026-05-24

- Stable v7.6 cut; iwd-gate pre-check; `_install_fstab_opts` folded into `_install_configure_services`.

v7.4 - v7.5 - 2026-05-21 to 2026-05-23

- `_check_boot_taint_gate` extracted; tmpfile moved to `/etc` for same-FS atomic `rename(2)`; kernel <6.14 hard-floor FAIL; LOC 5113→4468.

v7.4.0 - v7.4.5 - 2026-05-20

- Preflight + lock + sudo cache redesign; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1`; LOC 5204→5113.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19

- Preflight hardening; `_ir_resolve_root_uuid` 4-way dispatch; systemd <250 hard-fail; LOC 5177→4842.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17

- NM 1.56.0 compat; `MASK` 10→12; `PKGS_ADD` +`realtime-privileges`, +`cpupower`; +`_vrk_audio_state`; managed-files 13→12.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15

- Foundational v6.x → v7.0 series (5994→4985 LOC); user-bus detection, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
