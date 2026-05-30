ry-install ChangeLog

v7.13.4 - 2026-05-29

- Comment trim: longest explanatory comments condensed to terse single-line form; section banners, "why" rationale, and script header preserved. CHANGELOG condensed; README synced. No behaviour/count/invariant change.

v7.13.3 - 2026-05-29

- Removed `RY_INSTALL_NO_MATRIX`: run-summary matrix always renders to stderr; JSONL `PHASE_RESULT` remains the durable record. Runtime-variable doc count 6 → 5.

v7.13.2 - 2026-05-29

- Removed `RY_INSTALL_PKG_REMOVE_CASCADE`: `PKGS_DEL` members held by outside reverse-deps are always skipped; pactree detection unchanged. Remove manually with `pacman -Rns`.
- Removed `RY_INSTALL_NO_INTERACTIVE_SUDO`: `sudo -v` fallback still runs only on a stdin+stderr TTY, else skipped. Runtime-variable doc count 8 → 6.

v7.13.1 - 2026-05-29

- Removed inert `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` (no effect since v7.12.0); `_ip_pacman_invoke` still runs `pacman -Syu --needed` unconditionally.

v7.13.0 - 2026-05-29

- AUR installs unconditionally: `AUR_PKGS` = `mkinitcpio-firmware mt76-mt7925-dkms r8127-dkms`. Removed hardware-gating detectors and `RY_INSTALL_MAINTENANCE`. Runtime-variable doc 9 → 8; AUR count 2 → 3.

v7.12.0 - 2026-05-29

- Automatic backups: `_atomic_write_file` writes `<path>.ry.bak` before overwriting `loader.conf`/`mkinitcpio.conf`, restores on post-write byte-mismatch (`fstab` excluded). New `_RY_BACKUP_TARGETS`, `_RY_BACKUP_SUFFIX`.
- Time-sync preflight `_ry_check_time_sync`: reads `NTPSynchronized`, enables `systemd-timesyncd` if drifted (non-fatal).
- Partial upgrades forbidden: `_ip_pacman_invoke` always runs `pacman -Syu --needed`.

v7.11.x - 2026-05-28

- Quoted `$pipestatus` index operands across all sites (cosmetic).
- README: Configuration collapsibles opened; prose entries converted to tables.

v7.10.x - 2026-05-28

- `KERNEL_PARAMS` 15 → 16: +`processor.max_cstate=1`.
- `SYSCTL_VALUES` 8 → 9: +`net.core.busy_poll=50`, +`busy_read=50`, +`netdev_budget=600`, +`netdev_budget_usecs=5000`; -`vm.dirty_*`, -`vm.max_map_count`.
- Managed files 12 → 13: +`/etc/drirc.d/95-ry-radv-apu.conf` (`radv_enable_unified_heap_on_apu=true`).
- iwd config unconditional (iwd-gating subsystem removed); `PKGS_ADD` 15 → 13.
- `_rvc_dispatch` +`*/modprobe.d/*` validator; `ENV_VARS` 11 → 10.

v7.9.0 - 2026-05-27

- `ENV_VARS`: +`PROTON_FSR4_UPGRADE`, +`AMD_VULKAN_ICD=RADV`; `MESA_SHADER_CACHE_MAX_SIZE` 4G → 16G.
- `amdgpu.ppfeaturemask` `0xfffd3fff` → `0xfffd7fff`; ttm `pages_limit`/`page_pool_size` → 16777216 (64 GiB GTT).
- Kernel pin: `linux-cachyos` ≥ 6.18.4, skip 6.19.0 (CachyOS#23042).

v7.8.x - 2026-05-26 / 27

- `KERNEL_PARAMS` 18 → 15 (`amd_iommu=off` → `iommu=pt`; +`pcie_aspm.policy=performance`).
- Managed files 12 → 13 (+`ry-amdgpu-strixhalo.conf`); chip-gated `r8127-dkms`.

v7.7.x - 2026-05-26

- `PKGS_DEL` 11 → 7 (`shelly` made opt-in).

v7.6.x - 2026-05-24 / 26

- `KERNEL_PARAMS` → 15, `SYSCTL_VALUES` → 10, `ENV_VARS` → 10.
- New `_acquire_lock_fresh`, `_phase_record` sanitiser, `_init_runtime` CPU fail-closed; NM 1.56.0 compat.

v7.5.0 - 2026-05-23

- `/etc` tmpfile for same-FS atomic `rename(2)`; kernel < 6.14 hard-floor FAIL.

v7.4.x - 2026-05-19 / 20

- Preflight + lock + sudo redesign; `umask 0077` around mkdir; systemd < 250 hard-fail.

v7.3.0 - 2026-05-17

- NM 1.56.0 compat; `MASK` 10 → 12; `PKGS_ADD` +`realtime-privileges`.

v7.0.0 - 2026-05-15

- v6.x → v7.0: user-bus detection, atomic mkdir + pid-file lock, `--install-file` post-hook dispatch.
