# Changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

## 7.79.5 - 2026-06-29

- fix: add top-level `set -g SYSTEM_UPGRADED false` default + `set -q` guard in `_install_rebuild_boot` (mirrors `_if_trim_pacman_cache`). Hardening only; no behavior change.

## 7.79.4 - 2026-06-28

- docs: condense changelog entries to one-line form; sync version across script header, `VERSION`, and README badge/pin. Behavior unchanged (version-string bump only).

## 7.79.3 - 2026-06-28

- fix: gate the below-floor kernel branch on `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1` (mirrors the hardware-skip sibling). Previously a parsed sub-floor kernel was un-bypassable.

## 7.79.2 - 2026-06-28

- docs: add README Configuration subsections + grouped Managed Files tables. All 17 rows retained; no script change.

## 7.79.1 - 2026-06-28

- preflight: raise linux-firmware soft-floor advisory 20260110 -> 20260410 (gfx1151 MES-0x86 blob for the >= 6.19 amdgpu handshake). Non-fatal.

## 7.79.0 - 2026-06-28

- preflight: raise `KERNEL_MIN` 6.18 -> 6.19 (gfx1151 MES-0x86 firmware + RTL8127 suspend-hang fix + r8169).
- firewall: add TCP `27037` to gated remote-play set `{ 47984, 47989, 48010, 27036, 27037 }`. Default-off unchanged.
- verify: `_vrk_cpu_state` asserts `amd_pstate/dynamic_epp` == `disabled` (else EPP pin returns -EBUSY). Silent on pre-6.16.
- mangohud: re-enable `cpu_temp` (override `cpu_custom_temp_sensor=<chip>,<input>`).

## 7.78.3 - 2026-06-28

- style: collapse 12 functions to one-line form. 5012 -> 4983 lines.

## 7.78.2 - 2026-06-28

- docs: condense README prose; known-benign log tables -> prose.

## 7.78.1 - 2026-06-28

- fix: replace fish >= 3.7 `path basename` with floor-safe `command basename`.
- docs: pin Quick Start to v7.78.1.

## 7.78.0 - 2026-06-28

- baloo: drop `~/.config/baloofilerc` + `_post_baloo`. configs 18 -> 17, USER_DESTINATIONS 3 -> 2, post-hooks 18 -> 17.

## 7.77.2 - 2026-06-28

- verify: remove `_kb_*` known-benign subsystem + `_ry_check_umip_disabled`. -7 functions.
- docs: add UMIP / `clearcpuid=514` Tuning Note.

## 7.77.1 - 2026-06-28

- docs: add two verify-section banners. Comment-only.

## 7.77.0 - 2026-06-27

- cmdline: `iommu=pt` -> `amd_iommu=off` (count-neutral, 16).
- verify: add `_vrkm_iommu`.

## 7.76.1 - 2026-06-27

- ntsync: drop `modules-load.d/ntsync.conf` (assert-only).
- mangohud: comment out `cpu_temp`.

## 7.76.0 - 2026-06-27

- mangohud: add `cpu_temp`.
- preflight: add linux-firmware soft-floor advisory (`20251125*` blob). Non-fatal.

## 7.75.1 - 2026-06-27

- cpupower: governor performance -> powersave.
- udev: AMD P-State EPP performance -> balance_performance.

## 7.75.0 - 2026-06-27

- cmdline: add `fsck.mode=force`, `fsck.repair=yes`. KERNEL_PARAMS 14 -> 16.

## 7.74.2 - 2026-06-27

- verify: add `_vss_known_benign` advisory.

## 7.74.1 - 2026-06-27

- time-sync: add `_ry_rtc_writeback` (`hwclock --systohc --utc`) at both sync paths. Non-fatal.

## 7.74.0 - 2026-06-27

- cmdline: add `processor.max_cstate=1`. KERNEL_PARAMS 13 -> 14.
- preflight: remove `_ir_validate_repo_tier`.

## 7.73.6 - 2026-06-26

- cmdline: add `btusb.enable_autosuspend=n`. KERNEL_PARAMS 12 -> 13.

## 7.73.4 - 2026-06-26

- preflight: add `*/modprobe.d/*` post-hook + `_post_modprobe`. count 17 -> 18.

## 7.73.1 - 2026-06-26

- preflight: count each fatal condition once via `_err_loud_cont`.

## 7.73.0 - 2026-06-26

- udev: rename `60-ry-perf.rules` -> `99-ry-perf.rules`.
- sysctl: drop `vm.page-cluster`, `vm.vfs_cache_pressure`. SYSCTL_VALUES 11 -> 9.

## 7.72.0 - 2026-06-26

- network: add `60-ry-mt7925e.conf` (`disable_aspm=1`). configs 17 -> 18, SYSTEM_DESTINATIONS 14 -> 15.
- verify: add `_vss_modprobe`.

## 7.71.4 - 2026-06-26

- preflight: prefix mesa soft-floor probe with `command` (avoid pacman-function shadow).

## 7.71.3 - 2026-06-26

- mangohud: restore `gpu_power`, `text_outline`, `toggle_hud=Shift_R+F12`.
- preflight: guard the x86-64-v4 probe.

## 7.71.1 - 2026-06-26

- preflight: add `_ir_validate_keys` (refuse out-of-domain scalar key).

## 7.71.0 - 2026-06-26

- preflight: add `_ir_validate_kernel_floor`.
- gpu: parameterize `GPU_DPM_LEVEL` (default auto).
- env: add `PROTON_FSR4_RDNA3_UPGRADE=1`. ENV_VARS 10 -> 11.
- firewall: add `RY_REMOTE_PLAY_PORTS` gate (default false).

## 7.70.1 - 2026-06-24

- fix: guard `_err` VERIFY_FAIL increment with `set -q`.

## 7.70.0 - 2026-06-23

- regdom: remove `/etc/conf.d/wireless-regdom`. configs 18 -> 17, SYSTEM_DESTINATIONS 15 -> 14, post-hooks 18 -> 17.
- bluetooth: ReconnectAttempts 7 -> 3; remove ReconnectIntervals.
- preflight: raise mesa soft-floor warn 25.3 -> 26.0.

## 7.69.1 - 2026-06-22

- refactor: extract `_content_fn_for`.

## 7.69.0 - 2026-06-22

- cmdline: remove `amd_iommu=on`. KERNEL_PARAMS 13 -> 12.

## 7.68.0 - 2026-06-22

- boot: remove `clearcpuid=rdseed`. KERNEL_PARAMS 14 -> 13.
- preflight: remove `_ry_check_rdseed_workaround_stale`.

## 7.66.0 - 2026-06-22

- verify: split iwd-process check into `_vrsv_wifi_iwd_proc`.

## 7.65.0 - 2026-06-21

- mangohud: order fps/frametime ahead of GPU/CPU.

## 7.64.0 - 2026-06-21

- drirc: remove `95-ry-radv-apu.conf` (gfx1151 reports `uma:1`).
- network: remove dormant `iwd/main.conf`.
- guards: SYSTEM_DESTINATIONS 17 -> 15, post-hooks 20 -> 18, file count 20 -> 18.

## 7.63.0 - 2026-06-21

- bluetooth: add `main.conf`.
- services: enable `bluetooth.service`. EXPECTED_SERVICES 4 -> 5.
- verify: add `_vss_bluetooth`.

## 7.62.0 - 2026-06-21

- cmdline: `amd_iommu=off` -> `amd_iommu=on iommu=pt`. KERNEL_PARAMS 13 -> 14.
- network: NM backend iwd -> wpa_supplicant; `wifi.powersave=2`.
- services: mask `modemmanager.service`. MASK 9 -> 10.

## 7.61.0 - 2026-06-21

- systemd: add NM-dispatcher `logging.conf` (`LogLevelMax=notice`).
- fix: guard `vercmp` behind `command -q`.

## 7.60.0 - 2026-06-21

- mangohud: remove `fps_metrics`, `cpu_temp`, `gpu_power`, `text_outline`, `toggle_hud`.
- verify: drop toggle_hud assertion.

## 7.59.0 and earlier

History trimmed. See git tags for the full record.
