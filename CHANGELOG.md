ry-install ChangeLog

v7.11.3 - 2026-05-28

- README: all collapsibles in the Configuration section (Phases 1–6, 20 `<details>`) set to `<details open>`; prose-bodied entries (`Vulkan dependencies`, `systemd-resolved`, `systemd-logind`, `iwd`, `NetworkManager`, `cpupower-service`, `amdgpu/ttm`, `RADV drirc`, `fstab`, `Enabled units`) converted to tables. Docs-only; no behaviour/count/invariant change.
- README/script synced to v7.11.3.

v7.11.2 - 2026-05-28

- `_ry_content_bytes`, `_awf_render_to_tmp`: quote `$pipestatus` index operands in numeric `test`/`return` (`"$_ps[1]"`, `"$_ps[2]"`) to match the quoted convention used at all other pipestatus sites. Cosmetic; pipestatus is always populated, so no behaviour/count/invariant change.
- README/script synced to v7.11.2.

v7.11.1 - 2026-05-28

- Inline comment trim: longest explanatory comment condensed to terse single-line form. Section banners, "why" rationale, and script header (version + date + purpose) preserved. No behaviour/count/invariant change.
- CHANGELOG condensed to terse kernel.org-style bullets; all version numbers and concrete values (params, counts, paths, pkgs) preserved verbatim; no entries renumbered.
- README synced to v7.11.1.

v7.10.8 - 2026-05-28

- iwd config now unconditional: removed iwd-gating subsystem (`_should_skip_iwd`, `_RY_IWD_GATED_DSTS`, `_RY_SKIP_IWD` probe, AUR re-probe, cleanup-erase, all `skip_iwd` guards). `/etc/iwd/main.conf` + NM iwd drop-in deploy/verify unconditionally. `iwd` is a CachyOS base default.
- `PKGS_ADD` 15→13: -`iwd`, -`mesa`, -`cpupower` (base groups), -`lact-git` opt-in.
- README: -Upgrading section, tables trimmed to vital data. Docs-only; 616→472 lines.

v7.10.7 - 2026-05-28

- `_ir_detect_rtl8127`: guard `command -q lspci` + numeric-coerce `_hits`; logs `RTL8127_PROBE_SKIP` on hosts without `pciutils`. `lspci` added to `_ry_check_deps`.

v7.10.6 - 2026-05-28

- README: Upgrading notes condensed. Docs-only.

v7.10.5 - 2026-05-28

- `_vrk_module_state`: add runtime probe for `ttm` `pages_limit`/`page_pool_size` (16777216) via `_chk_sysfs_eq`. Closes GTT-cap verify gap.

v7.10.4 - 2026-05-28

- Comment trim: 40 verbose inline comments → terse single-line (−1 KB). Counts/behaviour/invariants unchanged.

v7.10.3 - 2026-05-28

- `_rvc_dispatch`: add `*/modprobe.d/*` → `_grep_modprobe_entry` (options/blacklist/install/alias/softdep/remove). Fixes `/etc/modprobe.d/ry-amdgpu-strixhalo.conf` preflight abort (latent since 7.8.0).

v7.10.2 - 2026-05-28

- `ENV_VARS` 11→10: -`DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`. Upgraders re-run + re-login.

v7.10.1 - 2026-05-28

- `_dc_kill_children`: gate `LOCK_DIR` removal on `_RY_HOLDS_LOCK`/`_RY_LOCK_DIR_OWNED` sentinels (prior empty-body `if` removed any non-symlink `LOCK_DIR`).

v7.10.0 - 2026-05-28

- `KERNEL_PARAMS` 15→16: +`processor.max_cstate=1`.
- `SYSCTL_VALUES` 8→9: +`net.core.busy_poll=50`, +`busy_read=50`, +`netdev_budget=600`, +`netdev_budget_usecs=5000`; -`vm.dirty_*`, -`vm.max_map_count`.
- Managed files 12→13: +`/etc/drirc.d/95-ry-radv-apu.conf` (`radv_enable_unified_heap_on_apu=true`). New `_grep_drirc_entry` + `*/drirc.d/*` post-hook.

v7.9.0 - 2026-05-27

- `ENV_VARS` 10→11: -`PROTON_FSR4_RDNA3_UPGRADE`, -`RADV_PERFTEST=nircache`; +`PROTON_FSR4_UPGRADE`, +`DXIL_SPIRV_CONFIG`, +`AMD_VULKAN_ICD=RADV`; `MESA_SHADER_CACHE_MAX_SIZE` 4G→16G.
- `KERNEL_PARAMS`: `amdgpu.ppfeaturemask` `0xfffd3fff`→`0xfffd7fff` (count 15 unchanged).
- modprobe `ttm` `pages_limit`+`page_pool_size` 32505856→16777216 (64 GiB GTT).
- Managed files 13→12: -`/etc/tmpfiles.d/99-cachyos-thp.conf`.
- sysctl drop-in `99-cachyos-sysctl.conf`→`95-ry-overrides.conf` (99→95).
- `_run_emit_stream`: gate head count on `_need_tail` (fixes 401–500-line silent loss).
- Kernel pin: `linux-cachyos` ≥6.18.4, skip 6.19.0 (CachyOS#23042); keep `mt76-mt7925-dkms`.

v7.8.x - 2026-05-26 / 27

- v7.8.5: CHANGELOG trim. v7.8.4: comment cleanup (−7). v7.8.3: README remove-table recategorised. v7.8.2: README cleanup; comment cleanup (−4). v7.8.1: `KERNEL_PARAMS` 14→15 (+`pcie_aspm.policy=performance`).
- v7.8.0: `ENV_VARS` -`gpl` from `RADV_PERFTEST`; `PKGS_ADD` +`lact-git`; managed 12→13 (+`ry-amdgpu-strixhalo.conf`); `KERNEL_PARAMS` 18→14 (-`amdgpu.gttsize`, -`processor.max_cstate`, -`pcie_aspm=off`, -`ttm.pages_limit`; `amd_iommu=off`→`iommu=pt`); chip-gated `r8127-dkms`.

v7.7.x - 2026-05-26

- v7.7.3: `PKGS_DEL` 8→7 (`shelly`→opt-in). v7.7.2: README recategorise. v7.7.1: `PKGS_DEL` 11→8 (-`octopi`, -`btop`, -`bolt`, -`plasma-thunderbolt`; +`shelly`). v7.7.0: counts verified.

v7.6.x - 2026-05-24 / 26

- README/CHANGELOG cleanup; count rebalancing.
- `KERNEL_PARAMS` net→15; `SYSCTL_VALUES`→10; `ENV_VARS`→10.
- New: `_acquire_lock_fresh`, `_phase_record` sanitiser, `_post_service` user-scope, `_init_runtime` CPU fail-closed, `_vrk_audio_state`, `_vrk_module_state`, `_vrk_cpu_state`.
- Fixes: `_dc_kill_children sleep 0.5 </dev/null` (stdin hang); `_set_exit` lifted above `_acquire_lock`; `_ntsync_state 2>/dev/null`; `_chk_perms` refuses setuid/sgid/sticky.
- NetworkManager 1.56.0 compat; iwd-gate pre-check.

v7.5.0 - 2026-05-23

- `_check_boot_taint_gate` extracted; `/etc` tmpfile for same-FS atomic `rename(2)`; kernel <6.14 hard-floor FAIL. LOC 5113→4468.

v7.4.x - 2026-05-19 / 20

- Preflight + lock + sudo redesign; `umask 0077` around mkdir; `RY_INSTALL_NO_INTERACTIVE_SUDO=1`; `_ir_resolve_root_uuid` 4-way dispatch; systemd <250 hard-fail. LOC 5204→4842.

v7.3.0 - 2026-05-17

- NM 1.56.0 compat; `MASK` 10→12; `PKGS_ADD` +`realtime-privileges`, +`cpupower`; +`_vrk_audio_state`; managed files 13→12.

v7.0.0 - 2026-05-15

- v6.x→v7.0 (5994→4985 LOC); user-bus detection, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
