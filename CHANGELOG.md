# Changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

## 7.78.3 - 2026-06-28

- style: collapse 12 single- and two-statement functions to one-line form (house style). Script 5012 -> 4983 lines. Behavior-, count-, and exit-code-neutral.

## 7.78.2 - 2026-06-28

- docs: condense README prose throughout; convert both known-benign log-line tables to prose (all entries retained). No script behavior change.

## 7.78.1 - 2026-06-28

- fix: `argparse --name` used the `path basename` builtin (fish >= 3.7); switched to floor-safe `command basename` for the declared 3.6 floor. Behavior-neutral.
- docs: sync Quick Start checkout pin to v7.78.1.

## 7.78.0 - 2026-06-28

- baloo: remove `~/.config/baloofilerc` (KDE indexing) from managed files; drop `_post_baloo` hook. Managed configs 18 -> 17, USER_DESTINATIONS 3 -> 2, post-hooks 18 -> 17.

## 7.77.2 - 2026-06-28

- verify: remove `_kb_*` known-benign advisory subsystem and `_ry_check_umip_disabled` (INFO-only). -7 functions. Count- and exit-code-neutral.
- docs: add Tuning Notes row for the `clearcpuid=514`/UMIP taint tradeoff.

## 7.77.1 - 2026-06-28

- docs: add two verify-section banners. Comment-only; no behavior change.

## 7.77.0 - 2026-06-27

- cmdline: `iommu=pt` -> `amd_iommu=off` (AMD-Vi fully disabled; no PCI passthrough on this profile). KERNEL_PARAMS count-neutral (16).
- verify: add `_vrkm_iommu` runtime check — derives expected IOMMU state from KERNEL_PARAMS, asserts against live `/sys/kernel/iommu_groups` + dmesg. Count- and exit-code-neutral.

## 7.76.1 - 2026-06-27

- ntsync: drop `/etc/modules-load.d/ntsync.conf` autoload; ntsync is assert-only (preflight + verify). Count-neutral.
- mangohud: comment out `cpu_temp` pending per-host hwmon resolution (re-enable with `cpu_custom_temp_sensor=k10temp`). Count-neutral.

## 7.76.0 - 2026-06-27

- mangohud: add `cpu_temp` after `cpu_stats`.
- preflight: add linux-firmware soft-floor advisory (hard-warn on `20251125*` MES blob, soft-warn < `20260110`). Non-fatal.

## 7.75.1 - 2026-06-27

- cpupower: `CPUPOWER_GOVERNOR` performance -> powersave.
- udev: AMD P-State EPP performance -> balance_performance.

## 7.75.0 - 2026-06-27

- cmdline: add `fsck.mode=force`, `fsck.repair=yes`. KERNEL_PARAMS 14 -> 16.

## 7.74.2 - 2026-06-27

- verify: add `_vss_known_benign` advisory sub. Count- and exit-code-neutral.

## 7.74.1 - 2026-06-27

- time-sync: add `_ry_rtc_writeback` (`hwclock --systohc --utc`) at both sync-confirmed paths. Non-fatal.

## 7.74.0 - 2026-06-27

- cmdline: add `processor.max_cstate=1`. KERNEL_PARAMS 13 -> 14.
- preflight: remove `_ir_validate_repo_tier`.

## 7.73.6 - 2026-06-26

- cmdline: add `btusb.enable_autosuspend=n`. KERNEL_PARAMS 12 -> 13.

## 7.73.4 - 2026-06-26

- preflight: add `*/modprobe.d/*` post-hook. count 17 -> 18.
- install-file: add `_post_modprobe` handler.

## 7.73.1 - 2026-06-26

- preflight: count each fatal condition once via `_err_loud_cont`.

## 7.73.0 - 2026-06-26

- udev: rename `60-ry-perf.rules` -> `99-ry-perf.rules` (sorts after vendor).
- sysctl: drop `vm.page-cluster`, `vm.vfs_cache_pressure` (vendor duplicates). SYSCTL_VALUES 11 -> 9.

## 7.72.0 - 2026-06-26

- network: add `60-ry-mt7925e.conf` (`disable_aspm=1`). Managed configs 17 -> 18, SYSTEM_DESTINATIONS 14 -> 15.
- verify: add `_vss_modprobe` assertion.

## 7.71.4 - 2026-06-26

- preflight: prefix mesa soft-floor probe with `command` (avoids shadowing pacman function).

## 7.71.3 - 2026-06-26

- mangohud: restore `gpu_power`, `text_outline`, `toggle_hud=Shift_R+F12`.
- preflight: guard the x86-64-v4 probe.

## 7.71.1 - 2026-06-26

- preflight: add `_ir_validate_keys` (refuse deploy on out-of-domain scalar key).

## 7.71.0 - 2026-06-26

- preflight: add `_ir_validate_kernel_floor` (hard-fail on kernel < 6.18; skip-override available).
- gpu: parameterize udev DPM level as `GPU_DPM_LEVEL` (default auto).
- env: add `PROTON_FSR4_RDNA3_UPGRADE=1`. ENV_VARS 10 -> 11.
- firewall: add `RY_REMOTE_PLAY_PORTS` gate (default false).

## 7.70.1 - 2026-06-24

- fix: guard `_err` VERIFY_FAIL increment with `set -q`.

## 7.70.0 - 2026-06-23

- regdom: remove `/etc/conf.d/wireless-regdom`. configs 18 -> 17, SYSTEM_DESTINATIONS 15 -> 14, post-hooks 18 -> 17.
- bluetooth: ReconnectAttempts 7 -> 3; remove ReconnectIntervals.
- preflight: raise mesa soft-floor warn 25.3 -> 26.0.

## 7.69.1 - 2026-06-22

- refactor: extract `_content_fn_for` to single-source generator-name derivation.

## 7.69.0 - 2026-06-22

- cmdline: remove `amd_iommu=on`. KERNEL_PARAMS 13 -> 12.

## 7.68.0 - 2026-06-22

- boot: remove `clearcpuid=rdseed`. KERNEL_PARAMS 14 -> 13.
- preflight: remove `_ry_check_rdseed_workaround_stale`.

## 7.66.0 - 2026-06-22

- verify: split iwd-process state check into `_vrsv_wifi_iwd_proc`.

## 7.65.0 - 2026-06-21

- mangohud: order fps/frametime ahead of GPU/CPU block.

## 7.64.0 - 2026-06-21

- drirc: remove `95-ry-radv-apu.conf` (gfx1151 reports `uma:1` natively).
- network: remove dormant `iwd/main.conf`; `NM_WIFI_BACKEND=iwd` opt-in retained.
- guards: SYSTEM_DESTINATIONS 17 -> 15, post-hooks 20 -> 18, managed-file count 20 -> 18.

## 7.63.0 - 2026-06-21

- bluetooth: add `main.conf` (AutoEnable, FastConnectable, reconnect backoff).
- services: enable `bluetooth.service`. EXPECTED_SERVICES 4 -> 5.
- verify: add `_vss_bluetooth`.

## 7.62.0 - 2026-06-21

- cmdline: `amd_iommu=off` -> `amd_iommu=on iommu=pt`. KERNEL_PARAMS 13 -> 14.
- network: NM backend iwd -> wpa_supplicant; power-save off via `wifi.powersave=2`.
- services: mask `modemmanager.service`. MASK 9 -> 10.

## 7.61.0 - 2026-06-21

- systemd: add NetworkManager-dispatcher `logging.conf` (`LogLevelMax=notice`).
- fix: guard `vercmp` behind `command -q` in mesa soft-floor check.

## 7.60.0 - 2026-06-21

- mangohud: remove `fps_metrics`, `cpu_temp`, `gpu_power`, `text_outline`, `toggle_hud`.
- verify: drop toggle_hud assertion; fps readout retained.

## 7.59.0 and earlier

History trimmed. See git tags for the full record.
