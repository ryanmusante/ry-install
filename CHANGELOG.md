ry-install ChangeLog

v7.10.8 - 2026-05-28

- iwd configuration is now unconditional. Removed the iwd-gating subsystem: `_should_skip_iwd`, `_RY_IWD_GATED_DSTS`, the memoized `_RY_SKIP_IWD` probe (`pacman -Qi iwd`), the AUR-phase re-probe, the cleanup-erase entry, and every `skip_iwd` parameter/guard in `_ry_install_file`, `_vss_iwd`, `_vss_nm`, `_verify_static_system`, `_vsc_check_one`, `_check_phase_files`, and `_ry_do_install_file`. `/etc/iwd/main.conf` and the NetworkManager iwd-backend drop-in (`/etc/NetworkManager/conf.d/99-cachyos-nm.conf`) now deploy and verify unconditionally; previously they were skipped when `iwd` was absent. `iwd` is a CachyOS default (base `Network` group), so it is relied upon rather than force-installed.
- Pruned `PKGS_ADD` of packages already present in a default CachyOS install: removed `iwd`, `mesa`, and `cpupower` (base groups), plus the commented `lact-git` opt-in. Invariant `PKGS_ADD` 15→13. README package table and Managed Files / Destinations updated accordingly (no "skipped when iwd absent" note). The `cpupower.service` not-found warning no longer references `PKGS_ADD`.

v7.10.7 - 2026-05-28

- `_ir_detect_rtl8127`: guard `command -q lspci` + numeric-coerce `_hits`. On hosts without `pciutils`, the unguarded `lspci` probe raised two uncaught fish errors (`Unknown command: lspci`, then `Argument is not a number: ''`) that bypassed `QUIET`; now logs `RTL8127_PROBE_SKIP` and treats the chip as absent. `lspci` added to the `_ry_check_deps` optional-tool probe. Detection/`r8127-dkms` gating on hosts that have `lspci` is unchanged.

v7.10.6 - 2026-05-28

- README: `Upgrading` notes condensed to one line each (≤7.8.x orphan-removal command inlined; no content dropped). Docs-only.

v7.10.5 - 2026-05-28

- `_vrk_module_state`: add runtime probe for `ttm pages_limit`/`page_pool_size` (16777216) via `_chk_sysfs_eq` (silent on kernels not exposing the params). Closes the one verification gap where the `/etc/modprobe.d/ry-amdgpu-strixhalo.conf` GTT cap was byte-verified on disk (`--verify-static`) but its live effect was never confirmed (`--verify-runtime` previously checked `amdgpu.ppfeaturemask` only).

v7.10.4 - 2026-05-28

- Script comment trim: 40 verbose inline comments reduced to terse single-line form (−1 KB; line count, behaviour, and all array/count invariants unchanged). `BLS spec` → `BLS` in `_resolve_boot_path` comment.

v7.10.3 - 2026-05-28

- `_rvc_dispatch`: add `*/modprobe.d/*` case routing to new `_grep_modprobe_entry` validator (accepts options/blacklist/install/alias/softdep/remove directives). Prior dispatch fell through to the INI `[Section]` validator, so `/etc/modprobe.d/ry-amdgpu-strixhalo.conf` failed config validation and aborted install at preflight (latent since the file landed in 7.8.0).

v7.10.2 - 2026-05-28

- `ENV_VARS` 11→10: -`DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`. Upgraders re-run + re-login to clear it from the `systemd --user` session env.

v7.10.1 - 2026-05-28

- `_dc_kill_children`: gate `LOCK_DIR` removal on `_RY_HOLDS_LOCK`/`_RY_LOCK_DIR_OWNED` ownership sentinels — prior empty-body `if` removed any non-symlink `LOCK_DIR`, ignoring ownership.

v7.10.0 - 2026-05-28

- `KERNEL_PARAMS` 15→16: +`processor.max_cstate=1` (cap CPU idle at C1; lower wake latency, higher idle power).
- `SYSCTL_VALUES` 8→9: +`net.core.busy_poll=50`, +`busy_read=50`, +`netdev_budget=600`, +`netdev_budget_usecs=5000`; -`vm.dirty_*`, -`vm.max_map_count` (revert to systemd ≥254 / kernel ratio defaults).
- Managed files 12→13: +`/etc/drirc.d/95-ry-radv-apu.conf` (`radv_enable_unified_heap_on_apu=true`, gfx1151 APU unified heap; extends Mesa MR!18884 beyond RDR2). New `_grep_drirc_entry` validator + `_RY_POST_HOOKS` `*/drirc.d/*` case (reread at next Vulkan/GL launch, no service restart).

v7.9.0 - 2026-05-27

- `ENV_VARS` 10→11: -`PROTON_FSR4_RDNA3_UPGRADE`, -`RADV_PERFTEST=nircache`; +`PROTON_FSR4_UPGRADE`, +`DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`, +`AMD_VULKAN_ICD=RADV`; `MESA_SHADER_CACHE_MAX_SIZE` 4G→16G.
- `KERNEL_PARAMS`: `amdgpu.ppfeaturemask` `0xfffd3fff`→`0xfffd7fff` (OD unlock); count 15 unchanged.
- modprobe `ttm` `pages_limit`+`page_pool_size` 32505856→16777216 (64 GiB GTT cap).
- Managed files 13→12: drop `/etc/tmpfiles.d/99-cachyos-thp.conf`; `_vre_thp_ksm` shrink_underused branch + dead `_configure_services_thp_apply` removed.
- sysctl drop-in `99-cachyos-sysctl.conf`→`95-ry-overrides.conf` (priority 99→95).
- `_run_emit_stream`: gate head count on `_need_tail` — fixes silent line loss for 401–500-line streams.
- Kernel pin: keep `linux-cachyos` ≥6.18.4, skip 6.19.0 (CachyOS#23042 black screen; mt76 mt7925e panic); keep `mt76-mt7925-dkms`.
- Upgraders: `sudo rm /etc/sysctl.d/99-cachyos-sysctl.conf /etc/tmpfiles.d/99-cachyos-thp.conf` (orphans).

v7.8.x - 2026-05-26 / 27

- v7.8.5: CHANGELOG trim.
- v7.8.4: script comment cleanup (-7).
- v7.8.3: README `Packages — remove` recategorised by `Category` (7 rows).
- v7.8.2: README orphan-pointer cleanup; script comment cleanup (-4).
- v7.8.1: `KERNEL_PARAMS` 14→15 (+`pcie_aspm.policy=performance`).
- v7.8.0: `ENV_VARS` drop `gpl` from `RADV_PERFTEST`; `PKGS_ADD` +`lact-git` opt-in; managed 12→13 (+`/etc/modprobe.d/ry-amdgpu-strixhalo.conf`, ROCm#5595); `KERNEL_PARAMS` 18→14 (-`amdgpu.gttsize`, -`processor.max_cstate=1`, -`pcie_aspm=off`, -`ttm.pages_limit`; `amd_iommu=off`→`iommu=pt`); chip-gated `r8127-dkms`.

v7.7.x - 2026-05-26

- v7.7.3: `PKGS_DEL` 8→7 (`shelly`→manual opt-in).
- v7.7.2: README `shelly` recategorised misc → package manager.
- v7.7.1: `PKGS_DEL` 11→8 (-`octopi`, -`btop`, -`bolt`, -`plasma-thunderbolt`; +`shelly`).
- v7.7.0: minor bump; counts verified.

v7.6.x - 2026-05-24 / 26

- README/CHANGELOG cleanup, count rebalancing, kernel-param + sysctl + env-var churn.
- `KERNEL_PARAMS`: net 18→15→17→18→19→16→15 across the series; final 7.6 = 15.
- `SYSCTL_VALUES`: 16→5→10 across the series; final 7.6 = 10 (debugfs-only `sched_migration_cost_ns` removed; vendor-duplicate `vm.swappiness` removed).
- `ENV_VARS`: 11→12→11→10 across the series; final 7.6 = 10.
- New functions: `_acquire_lock_fresh`, `_phase_record` sanitiser, `_post_service` user-scope routing, `_init_runtime` CPU-model fail-closed, `_vrk_audio_state`, `_vrk_module_state`, `_vrk_cpu_state` (powersave/balance_performance).
- Fixes: `_dc_kill_children sleep 0.5 </dev/null` (cron/systemd stdin hang); `_set_exit` lifted above `_acquire_lock`; `_ntsync_state` `2>/dev/null` on `grep -q`; `_chk_perms` refuses setuid/sgid/sticky.
- Hardware: NetworkManager 1.56.0 compat; iwd-gate pre-check.

v7.5.0 - 2026-05-23

- `_check_boot_taint_gate` extracted; tmpfile in `/etc` for same-FS atomic `rename(2)`; kernel <6.14 hard-floor FAIL; LOC 5113→4468.

v7.4.x - 2026-05-19 / 20

- Preflight + lock + sudo redesign; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1`; `_ir_resolve_root_uuid` 4-way dispatch; systemd <250 hard-fail; LOC 5204→4842.

v7.3.0 - 2026-05-17

- NM 1.56.0 compat; `MASK` 10→12; `PKGS_ADD` +`realtime-privileges`, +`cpupower`; +`_vrk_audio_state`; managed files 13→12.

v7.0.0 - 2026-05-15

- v6.x→v7.0 series (5994→4985 LOC); user-bus detection, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
