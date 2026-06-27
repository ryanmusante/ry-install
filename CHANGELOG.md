ry-install changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

7.75.1 - 2026-06-27

- cpupower: CPUPOWER_GOVERNOR performance -> powersave.
- udev: AMD P-State EPP performance -> balance_performance (named hint, not raw 0x0). boost/prefcore unchanged.

7.75.0 - 2026-06-27

- cmdline: add fsck.mode=force and fsck.repair=yes to KERNEL_PARAMS (force fsck every boot, auto-repair without prompt). KERNEL_PARAMS 14 -> 16.

7.74.2 - 2026-06-27

- verify: add _vss_known_benign advisory sub (5 INFO checks: masked ModemManager D-Bus noise, ACP70 missing machine driver, boltd unknown NHI id, no battery/backlight sysfs, USB mic volume curve). Emits only when present; count- and exit-code-neutral.
- docs: README — add Known-benign log lines tables; trim to vital info.

7.74.1 - 2026-06-27

- time-sync: add _ry_rtc_writeback (hwclock --systohc --utc) at both sync-confirmed paths in _ry_check_time_sync, so a skewed RTC stops poisoning timer persistence stamps. Guarded on hwclock + RTCInLocalTZ != yes; non-fatal.

7.74.0 - 2026-06-27

- cmdline: add processor.max_cstate=1 to KERNEL_PARAMS (cap C-state). KERNEL_PARAMS 13 -> 14.
- preflight: remove _ir_validate_repo_tier (advisory x86-64-v4 probe). No count/exit-code impact.
- docs: README Phase 4 pipeline now lists the iwd-handoff step (runs only when NM_WIFI_BACKEND=iwd) to match _install_configure_services.
- docs: README systemd-oomd note made RAM-capacity-agnostic (was a specific figure the script does not define).

7.73.6 - 2026-06-26

- cmdline: add btusb.enable_autosuspend=n to KERNEL_PARAMS. KERNEL_PARAMS 12 -> 13.

7.73.5 - 2026-06-26

- docs: trim README prose. Managed Files table + safety admonitions preserved.
- docs: fix stale Quick-Start clone tag.

7.73.4 - 2026-06-26

- preflight: add `*/modprobe.d/*|modprobe` to _RY_POST_HOOKS. count 17 -> 18.
- install-file: add _post_modprobe handler (modprobe.d change applies on reboot).

7.73.3 - 2026-06-26

- docs: render Managed Files as a File|Purpose table, ordered to match SYSTEM/USER_DESTINATIONS.

7.73.2 - 2026-06-26

- docs: trim README to vital info. Safety/recovery content preserved.
- docs: Contributing — lint with fish --no-execute.

7.73.1 - 2026-06-26

- preflight: count each fatal condition once via _err_loud_cont. Exit codes unchanged.
- docs: note runtime-init gates run before mode dispatch; exit 3 precedes --install-file exit 2.
- style: fish-native command-substitution in the content-dispatch comment.

7.73.0 - 2026-06-26

- udev: rename 60-ry-perf.rules -> 99-ry-perf.rules (sorts after vendor 60-ioschedulers.rules). Scheduler unchanged.
- sysctl: drop vm.page-cluster=0 and vm.vfs_cache_pressure=50 (vendor duplicates). SYSCTL_VALUES 11 -> 9.

7.72.0 - 2026-06-26

- network: add 60-ry-mt7925e.conf (disable_aspm=1) for MT7925. Managed configs 17 -> 18, SYSTEM_DESTINATIONS 14 -> 15.
- verify: add _vss_modprobe assertion for the mt7925e drop-in.

7.71.4 - 2026-06-26

- preflight: prefix mesa soft-floor probe with command (avoids shadowing pacman function).
- docs: clarify fstab normalization operates on the options column (field 4) only.

7.71.3 - 2026-06-26

- mangohud: restore gpu_power, text_outline, toggle_hud=Shift_R+F12.
- preflight: guard the x86-64-v4 probe (resolve ld-linux via command -v, gate pacman-conf behind command -q).

7.71.2 - 2026-06-26

- style: collapse the nm-dispatcher generator comment to one line.
- docs: reconcile README against script.

7.71.1 - 2026-06-26

- preflight: add _ir_validate_keys — refuse deploy on out-of-domain embedded scalar key.
- docs: note fstab rewrite normalizes redundant atime/defaults/commit tokens.

7.71.0 - 2026-06-26

- preflight: add _ir_validate_kernel_floor — hard-fail on kernel < KERNEL_MIN (6.18); skip-override available.
- preflight: add _ir_validate_repo_tier — advisory x86-64-v4 repo probe.
- gpu: parameterize udev DPM level as GPU_DPM_LEVEL (default auto).
- env: add PROTON_FSR4_RDNA3_UPGRADE=1. ENV_VARS 10 -> 11.
- firewall: add RY_REMOTE_PLAY_PORTS gate (default false).

7.70.1 - 2026-06-24

- fix: guard _err VERIFY_FAIL increment with set -q.

7.70.0 - 2026-06-23

- regdom: remove /etc/conf.d/wireless-regdom. configs 18 -> 17, SYSTEM_DESTINATIONS 15 -> 14, _RY_POST_HOOKS 18 -> 17.
- bluetooth: ReconnectAttempts 7 -> 3; remove ReconnectIntervals.
- preflight: raise mesa soft-floor warn 25.3 -> 26.0.

7.69.1 - 2026-06-22

- refactor: extract _content_fn_for to single-source generator-name derivation.

7.69.0 - 2026-06-22

- cmdline: remove amd_iommu=on from KERNEL_PARAMS. KERNEL_PARAMS 13 -> 12.

7.68.0 - 2026-06-22

- boot: remove clearcpuid=rdseed from KERNEL_PARAMS. KERNEL_PARAMS 14 -> 13.
- preflight: remove _ry_check_rdseed_workaround_stale.

7.67.0 - 2026-06-22

- style: normalize the RDSEED-microcode probe command substitution to fish (cmd) form.

7.66.0 - 2026-06-22

- verify: split iwd-process state check into _vrsv_wifi_iwd_proc.
- style: trim verbose source comments.

7.65.0 - 2026-06-21

- mangohud: order fps/frametime ahead of GPU/CPU block.
- style: fix post-hook banner count.

7.64.0 - 2026-06-21

- drirc: remove 95-ry-radv-apu.conf (gfx1151 reports uma:1 natively).
- network: remove dormant iwd/main.conf; NM_WIFI_BACKEND=iwd opt-in retained.
- guards: SYSTEM_DESTINATIONS 17 -> 15, _RY_POST_HOOKS 20 -> 18, managed-file count 20 -> 18.

7.63.0 - 2026-06-21

- bluetooth: add main.conf (AutoEnable, FastConnectable, reconnect backoff).
- services: enable bluetooth.service. EXPECTED_SERVICES 4 -> 5.
- verify: add _vss_bluetooth.

7.62.0 - 2026-06-21

- cmdline: amd_iommu=off -> amd_iommu=on iommu=pt. KERNEL_PARAMS 13 -> 14.
- network: NM backend iwd -> wpa_supplicant; power-save off via wifi.powersave=2.
- services: mask modemmanager.service. MASK 9 -> 10.

7.61.0 - 2026-06-21

- systemd: add NetworkManager-dispatcher logging.conf (LogLevelMax=notice).
- fix: guard vercmp behind command -q in mesa soft-floor check.

7.60.0 - 2026-06-21

- mangohud: remove fps_metrics, cpu_temp, gpu_power, text_outline, toggle_hud.
- verify: drop toggle_hud assertion; fps readout retained.

7.59.0 and earlier - history trimmed

- Entries for 7.59.0 and earlier removed from this file. See git tags / history for the full record.
