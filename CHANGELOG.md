# Changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

## 7.83.2 - 2026-06-30

- docs: document non-obvious sysctl values (netdev budget, `max_map_count`, `swappiness`). Comment-only.

## 7.83.1 - 2026-06-30

- fix: `_run` output-capture tail cap derives from head cap; elided count stays non-negative if retuned. No change at shipped cap.

## 7.83.0 - 2026-07-01

- fix: `environment.d` + `sysctl.d` generators reject control chars, blocking directive injection.
- refactor: hoist `GPU_DPM_LEVEL` accepted set to `_RY_DPM_LEVELS`; guard + message share one source.
- docs: trim exit-code list to user-visible codes (`0`–`5`, `10`).

## 7.82.0 - 2026-06-30

- fix: validate `GPU_DPM_LEVEL` against the dpm-level enum; blocks udev `ATTR{}` corruption.
- fix: reject ISO-3166-1 reserved `COUNTRY` codes (AA, QM-QZ, XA-XZ, ZZ).
- fix: `environment.d` generator skips malformed entries + asserts count. Adds exit code 14.

## 7.81.0 - 2026-06-29

- refactor: remove linux-firmware soft-floor advisory + dangling version prose.
- docs: add intro to Managed Files and Tuning Notes sections.

## 7.80.0 - 2026-06-29

- docs: trim in-script comments to vital rationale; sync version. No behavior change.

## 7.79.6 - 2026-06-29

- fix: GPU udev rule `KERNEL=="card[0-9]*"` + `DEVTYPE=="drm_minor"`. Count-neutral.

## 7.79.5 - 2026-06-29

- fix: `set -g SYSTEM_UPGRADED false` default + `set -q` guard. Hardening only.

## 7.79.4 - 2026-06-28

- docs: condense changelog to one-line form; sync version. Behavior unchanged.

## 7.79.3 - 2026-06-28

- fix: gate below-floor kernel branch on `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`.

## 7.79.2 - 2026-06-28

- docs: add README Configuration subsections + grouped Managed Files tables.

## 7.79.1 - 2026-06-28

- preflight: raise linux-firmware soft-floor advisory 20260110 -> 20260410. Non-fatal.

## 7.79.0 - 2026-06-28

- preflight: raise `KERNEL_MIN` 6.18 -> 6.19.
- firewall: add TCP `27037` to gated remote-play set. Default-off unchanged.
- verify: `_vrk_cpu_state` asserts `amd_pstate/dynamic_epp` == `disabled`. Silent on pre-6.16.
- mangohud: re-enable `cpu_temp`.

## 7.78.3 - 2026-06-28

- style: collapse 12 functions to one-line form. 5012 -> 4983 lines.

## 7.78.2 - 2026-06-28

- docs: condense README prose; known-benign log tables -> prose.

## 7.78.1 - 2026-06-28

- fix: replace fish >= 3.7 `path basename` with floor-safe `command basename`.
- docs: pin Quick Start to v7.78.1.

## 7.78.0 - 2026-06-28

- baloo: drop `~/.config/baloofilerc` + `_post_baloo`. configs 18 -> 17.

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
- preflight: add linux-firmware soft-floor advisory. Non-fatal.

## 7.75.1 - 2026-06-27

- cpupower: governor performance -> powersave.
- udev: AMD P-State EPP performance -> balance_performance.

## 7.75.0 - 2026-06-27

- cmdline: add `fsck.mode=force`, `fsck.repair=yes`. KERNEL_PARAMS 14 -> 16.

## 7.74.2 - 2026-06-27

- verify: add `_vss_known_benign` advisory.

## 7.74.1 - 2026-06-27

- time-sync: add `_ry_rtc_writeback` at both sync paths. Non-fatal.

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

- network: add `60-ry-mt7925e.conf` (`disable_aspm=1`). configs 17 -> 18.
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

- regdom: remove `/etc/conf.d/wireless-regdom`. configs 18 -> 17.
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

- verify: split WiFi runtime state into a dedicated sub-check.

## 7.65.0 - 2026-06-21

- mangohud: order fps/frametime ahead of GPU/CPU.

## 7.64.0 - 2026-06-21

- drirc: remove `95-ry-radv-apu.conf` (gfx1151 reports `uma:1`).
- guards: SYSTEM_DESTINATIONS 17 -> 15, post-hooks 20 -> 18, file count 20 -> 18.

## 7.63.0 - 2026-06-21

- bluetooth: add `main.conf`.
- services: enable `bluetooth.service`. EXPECTED_SERVICES 4 -> 5.
- verify: add `_vss_bluetooth`.

## 7.62.0 - 2026-06-21

- cmdline: `amd_iommu=off` -> `amd_iommu=on iommu=pt`. KERNEL_PARAMS 13 -> 14.
- network: set NM `wifi.backend=wpa_supplicant`; `wifi.powersave=2`.
- services: mask `modemmanager.service`. MASK 9 -> 10.

## 7.61.0 - 2026-06-21

- systemd: add NM-dispatcher `logging.conf` (`LogLevelMax=notice`).
- fix: guard `vercmp` behind `command -q`.

## 7.60.0 - 2026-06-21

- mangohud: remove `fps_metrics`, `cpu_temp`, `gpu_power`, `text_outline`, `toggle_hud`.
- verify: drop toggle_hud assertion.

## 7.59.0 and earlier

History trimmed. See git tags for the full record.
