# Changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

## 7.79.3 - 2026-06-28

- fix: `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1` was honored only on the unreadable-`uname -r` path; the parsed-but-below-floor branch hard-failed (exit 3) with no override gate, so a sub-floor kernel could never be bypassed despite the function description, both error hints, `--help`, and README all advertising the override. Gate the below-floor branch to mirror the `RY_INSTALL_SKIP_HARDWARE_CHECK` sibling (`_warn_loud` + proceed on override, else refuse). Affected all modes, since `_init_runtime` runs before dispatch.

## 7.79.2 - 2026-06-28

- docs: add subsection headers to README Configuration (Globals/Packages/Units/fstab) and split Managed Files into grouped tables (Boot, systemd drop-ins, Network, Bluetooth & firewall, Power/performance/modules, User session). All 17 file rows retained; no script change.

## 7.79.1 - 2026-06-28

- preflight: raise the linux-firmware soft-floor advisory (and known-bad-blob upgrade target) 20260110 -> 20260410, matching the gfx1151 MES-0x86 blob the >= 6.19 amdgpu handshake requires. Non-fatal; the warning now covers the full pre-MES range.

## 7.79.0 - 2026-06-28

- preflight: raise `KERNEL_MIN` 6.18 -> 6.19 (gfx1151 MES-0x86 firmware needs the >= 6.19 amdgpu handshake; RTL8127 suspend-hang fix + r8169 also land here). README + floor comments synced.
- firewall: add TCP `27037` to the gated remote-play inbound set (Steam Remote Play 27036-27037/tcp); now `{ 47984, 47989, 48010, 27036, 27037 }`. Default-off gate unchanged.
- verify: `_vrk_cpu_state` asserts `amd_pstate/dynamic_epp` == `disabled` (enabled dynamic EPP overrides the udev EPP pin with -EBUSY). Silent-on-missing for pre-6.16 hosts.
- mangohud: re-enable `cpu_temp`. Override with `cpu_custom_temp_sensor=<chip>,<input>` (e.g. `k10temp`) if the wrong sensor shows.

## 7.78.3 - 2026-06-28

- style: collapse 12 short functions to one-line form. 5012 -> 4983 lines. Behavior-neutral.

## 7.78.2 - 2026-06-28

- docs: condense README prose; convert both known-benign log tables to prose (all entries kept).

## 7.78.1 - 2026-06-28

- fix: `argparse --name` used the fish >= 3.7 `path basename` builtin; switch to floor-safe `command basename`.
- docs: sync Quick Start pin to v7.78.1.

## 7.78.0 - 2026-06-28

- baloo: drop `~/.config/baloofilerc` + `_post_baloo`. Managed configs 18 -> 17, USER_DESTINATIONS 3 -> 2, post-hooks 18 -> 17.

## 7.77.2 - 2026-06-28

- verify: remove `_kb_*` known-benign subsystem and `_ry_check_umip_disabled` (INFO-only). -7 functions.
- docs: add Tuning Notes row for the `clearcpuid=514`/UMIP taint tradeoff.

## 7.77.1 - 2026-06-28

- docs: add two verify-section banners. Comment-only.

## 7.77.0 - 2026-06-27

- cmdline: `iommu=pt` -> `amd_iommu=off` (AMD-Vi disabled; no passthrough on this profile). KERNEL_PARAMS count-neutral (16).
- verify: add `_vrkm_iommu` — derives expected IOMMU state from KERNEL_PARAMS, asserts against live `/sys/kernel/iommu_groups` + dmesg.

## 7.76.1 - 2026-06-27

- ntsync: drop `/etc/modules-load.d/ntsync.conf`; ntsync is assert-only (preflight + verify).
- mangohud: comment out `cpu_temp` pending per-host hwmon resolution.

## 7.76.0 - 2026-06-27

- mangohud: add `cpu_temp` after `cpu_stats`.
- preflight: add linux-firmware soft-floor advisory (hard-warn on `20251125*` blob). Non-fatal.

## 7.75.1 - 2026-06-27

- cpupower: `CPUPOWER_GOVERNOR` performance -> powersave.
- udev: AMD P-State EPP performance -> balance_performance.

## 7.75.0 - 2026-06-27

- cmdline: add `fsck.mode=force`, `fsck.repair=yes`. KERNEL_PARAMS 14 -> 16.

## 7.74.2 - 2026-06-27

- verify: add `_vss_known_benign` advisory sub.

## 7.74.1 - 2026-06-27

- time-sync: add `_ry_rtc_writeback` (`hwclock --systohc --utc`) at both sync-confirmed paths. Non-fatal.

## 7.74.0 - 2026-06-27

- cmdline: add `processor.max_cstate=1`. KERNEL_PARAMS 13 -> 14.
- preflight: remove `_ir_validate_repo_tier`.

## 7.73.6 - 2026-06-26

- cmdline: add `btusb.enable_autosuspend=n`. KERNEL_PARAMS 12 -> 13.

## 7.73.4 - 2026-06-26

- preflight: add `*/modprobe.d/*` post-hook + `_post_modprobe` handler. count 17 -> 18.

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

- preflight: add `_ir_validate_kernel_floor` (hard-fail on kernel < floor; skip-override available).
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
