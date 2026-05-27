ry-install ChangeLog

v7.8.3 - v7.8.4 - 2026-05-27

- Script: trim 7 verbose comments to single concise line.
- CHANGELOG: trim verbose v7.7.3 → v7.8.0 stanza and 6 historical stanzas (v7.6.16, .17, .18, .19, .22, .28) to kernel.org style.

v7.8.2 - v7.8.3 - 2026-05-27

- README `Packages — remove`: convert to standard `Package | Category` form (7 rows).

v7.8.1 - v7.8.2 - 2026-05-27

- README: remove orphan pointer note after `Packages — AUR` collapsible.
- Script: trim four narrative comments to single concise line.

v7.8.0 - v7.8.1 - 2026-05-27

- `KERNEL_PARAMS` 14→15: +`pcie_aspm.policy=performance` (force ASPM policy, retains DMA protection).

v7.7.3 - v7.8.0 - 2026-05-26

- `ENV_VARS`: drop `gpl` from `RADV_PERFTEST` (Mesa 23.1 default).
- `PKGS_ADD`: add `lact-git` as opt-in trailing comment; both opt-in notes trimmed to single-line form.
- Managed files 12→13: +`/etc/modprobe.d/ry-amdgpu-strixhalo.conf` (ttm `pages_limit` + `page_pool_size`; ROCm#5595). `_RY_POST_HOOKS` 14→15 (+`_post_modprobe`).
- `KERNEL_PARAMS` 18→14; drop `amdgpu.gttsize`, `processor.max_cstate=1`, `pcie_aspm=off`, `ttm.pages_limit`; replace `amd_iommu=off` → `iommu=pt`.
- `AUR_PKGS`: chip-gated `r8127-dkms` (Realtek RTL8127; BBS#7762); static count replaced by `_ir_validate_aur_pkgs_dynamic` (2 or 3).

v7.7.2 - v7.7.3 - 2026-05-26

- `PKGS_DEL` count 8→7; `_ir_validate_counts` synced. `shelly` removal commented out (trailing `# shelly` on the `set -g PKGS_DEL` line) and converted to manual opt-in.
- README `Packages — remove` table regenerated; opt-in instructions added.

v7.7.1 - v7.7.2 - 2026-05-26

- README `Packages — remove`: `shelly` recategorized `misc` → `package manager` (per upstream description: "Shelly: A Modern Arch Package Manager").
- CHANGELOG: v7.6.30 / v7.7.0 / v7.7.1 entries trimmed to kernel.org style.

v7.7.0 - v7.7.1 - 2026-05-26

- `PKGS_DEL` count 11→8; `_ir_validate_counts` synced.
  - drop: `octopi`, `btop`, `bolt`, `plasma-thunderbolt`.
  - add: `shelly`.
- README `Packages — remove` table regenerated.

v7.6.30 - v7.7.0 - 2026-05-26

- Minor bump: no functional or data changes; script ↔ README invariant counts verified in sync.

v7.6.29 - v7.6.30 - 2026-05-26

- README: 3 collapsibles ≥10 entries collapsed to 2-column Category form (Bootloader, Masked units, Exit codes); Destinations unchanged.

v7.6.28 - v7.6.29 - 2026-05-26

- README: 5 collapsibles regrouped by `Category` column (kernel cmdline, bootloader, env vars, masked units, exit codes); counts unchanged.

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

- `SYSCTL_VALUES` 10→8: drop `kernel.sched_migration_cost_ns=5000000` (moved to debugfs in 5.13) and `vm.swappiness=10` (overridden by vendor zram udev rule); `_ir_validate_counts` synced.

v7.6.21 - v7.6.22 - 2026-05-25

- `KERNEL_PARAMS` drops `loglevel=3`, `rd.systemd.show_status=auto`, `rd.udev.log_level=3` (count 18→15); `ENV_VARS` drops `ENABLE_LAYER_MESA_ANTI_LAG=1` (count 11→10); `_ir_validate_counts` invariants synced; README `quiet`+`loglevel=3` boot-splash prose collapsed to `quiet`.

v7.6.20 - v7.6.21 - 2026-05-25

- `KERNEL_PARAMS` drops `mitigations=off` (count 19→18); `ENV_VARS` drops `MESA_DISK_CACHE_SINGLE_FILE=1` (count 12→11); `_ir_validate_counts` invariants synced.

v7.6.19 - v7.6.20 - 2026-05-25

- `KERNEL_PARAMS` 16→19 (+`mitigations=off`, `preempt=full`, `ttm.pages_limit=4194304`); `ENV_VARS` 10→12 (-`PROTON_USE_NTSYNC` default in proton-cachyos; +`ENABLE_LAYER_MESA_ANTI_LAG`, `MESA_DISK_CACHE_SINGLE_FILE`, `PROTON_FSR4_RDNA3_UPGRADE`; `RADV_PERFTEST sam,nircache`→`gpl,nircache`); `SYSCTL_VALUES` 5→10; `_ir_validate_counts` synced.

v7.6.18 - v7.6.19 - 2026-05-25

- `SYSCTL_VALUES` 16→5 (kept: `default_qdisc=fq`, `tcp_congestion_control=bbr`, `tcp_slow_start_after_idle=0`, `vm.compaction_proactiveness=0`, `vm.max_map_count=2147483642`); dropped `net.*` duplicating vendor defaults + `vm.watermark_boost_factor=0` + `fs.protected_{fifos,regular}`; `_ir_validate_counts` synced.

v7.6.17 - v7.6.18 - 2026-05-25

- `KERNEL_PARAMS` 15→16 (+`8250.nr_uarts=0`; masks phantom ttyS1, saves ~4.25s boot); `_vrkg_vram` removed (BIOS-sized UMA, not driver concern); `_ir_validate_counts` synced.

v7.6.16 - v7.6.17 - 2026-05-25

- `KERNEL_PARAMS` 17→15 (-`amdgpu.cwsr_enable=0`, `amdgpu.dcdebugmask=0x12`); `ENV_VARS` 11→10 (-`RADV_EXPERIMENTAL=transfer_queue`); `_ir_validate_counts` synced; README CWSR known-issue row removed.

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
