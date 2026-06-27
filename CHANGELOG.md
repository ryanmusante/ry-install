ry-install changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

7.73.7 - 2026-06-26

- cpupower: CPUPOWER_GOVERNOR powersave -> performance. Under amd_pstate=active the amd-pstate-epp driver pins the max P-state on the performance pseudo-governor.
- udev: AMD P-State EPP balance_performance -> performance in 99-ry-perf.rules (EPP=0x0, max performance bias). _vss_udev and _vrk_cpu_state validators updated; boost/prefcore unchanged.

7.73.6 - 2026-06-26

- cmdline: add btusb.enable_autosuspend=n to KERNEL_PARAMS (disable BT USB controller autosuspend). KERNEL_PARAMS 12 -> 13.

7.73.5 - 2026-06-26

- docs: trim README prose (~5% smaller) — condense Configuration, fstab, Usage, Install-Flow, hard-deps, and the exit-code/env collapsible; drop redundant Known-Issues/Tuning-Notes intro lines. Managed Files table and all safety admonitions (IMPORTANT/CAUTION/WARNING/NOTE) preserved verbatim.
- docs: fix stale Quick-Start clone tag (`git checkout v7.73.3` -> current).

7.73.4 - 2026-06-26

- preflight: add `*/modprobe.d/*|modprobe` to _RY_POST_HOOKS so every managed destination matches a hook pattern; `_RY_POST_HOOKS` count 17 -> 18. Closes a gap where `--install-file /etc/modprobe.d/60-ry-mt7925e.conf` deployed the file but ran no post-hook and printed no reboot-required notice (the full install was unaffected — Phase 5 rebuilds regardless).
- install-file: add `_post_modprobe` handler — notifies that a modprobe.d option change applies on reboot (load-time parameter; an already-loaded module is not live-reconfigurable). No initramfs rebuild forced.

7.73.3 - 2026-06-26

- docs: render Managed Files as a File|Purpose table (one row per file), ordered to match SYSTEM/USER_DESTINATIONS.

7.73.2 - 2026-06-26

- docs: trim README to vital info (~23% smaller) — drop TOC + 4/5 badges, collapse per-file value table to a script pointer, condense fstab/Tuning prose. Safety/recovery content preserved.
- docs: Contributing — lint with fish --no-execute (shellcheck cannot lint fish).

7.73.1 - 2026-06-26

- preflight: count each fatal preflight condition once — rationale/override continuation lines route through new _err_loud_cont (no VERIFY_FAIL bump). Exit codes unchanged.
- docs: note runtime-init gates (hardware/kernel-floor/key-count) run before mode dispatch for all modes; exit 3 precedes the --install-file exit-2 rejection.
- style: fish-native command-substitution notation in the content-dispatch comment.

7.73.0 - 2026-06-26

- udev: rename 60-ry-perf.rules -> 99-ry-perf.rules so NVMe scheduler=none sorts after vendor 60-ioschedulers.rules and wins by explicit prefix. Scheduler unchanged (none); managed-file count unchanged (18).
- sysctl: drop vm.page-cluster=0 and vm.vfs_cache_pressure=50 (identical to vendor 70-cachyos-settings.conf, no effect). SYSCTL_VALUES 11 -> 9.

7.72.0 - 2026-06-26

- network: add 60-ry-mt7925e.conf (disable_aspm=1) to mitigate MT7925 coredump/BT-reconnect/assoc-fail; applies on reboot. Managed configs 17 -> 18, SYSTEM_DESTINATIONS 14 -> 15.
- verify: add _vss_modprobe assertion for the mt7925e drop-in.

7.71.4 - 2026-06-26

- preflight: prefix the mesa soft-floor probe with command (command pacman -Q mesa) — avoids resolving a shadowing pacman function.
- docs: clarify fstab normalization operates on the options column (field 4) only; whitespace-split rows are rejected by the findmnt --verify gate, not corrected.

7.71.3 - 2026-06-26

- mangohud: restore gpu_power (GPU block), text_outline (styling), toggle_hud=Shift_R+F12 (explicit keybind, matches README).
- preflight: guard the x86-64-v4 repo-tier probe — resolve ld-linux via command -v and gate pacman-conf behind command -q (absent path no longer emits a stderr trace).

7.71.2 - 2026-06-26

- style: collapse the nm-dispatcher generator comment to one line (rendered drop-in unchanged).
- docs: reconcile README against script.

7.71.1 - 2026-06-26

- preflight: add _ir_validate_keys — refuse deploy when an embedded scalar key is out of domain (bool/yes-no/int/ISO-3166/non-empty).
- docs: note fstab rewrite normalizes redundant atime/defaults/commit tokens; cmdline rw/root prefix is separate from the 12 KERNEL_PARAMS.

7.71.0 - 2026-06-26

- preflight: add _ir_validate_kernel_floor — hard-fail when running kernel < KERNEL_MIN (6.18); override RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1.
- preflight: add _ir_validate_repo_tier — advisory warn when CPU supports x86-64-v4 but no v4 repo is active.
- gpu: parameterize udev DPM level as GPU_DPM_LEVEL (default auto); avoids pinning SCLK on CPU-bound titles.
- env: add PROTON_FSR4_RDNA3_UPGRADE=1 (FSR4 on RDNA3/3.5 via Proton-CachyOS). ENV_VARS 10 -> 11.
- firewall: add RY_REMOTE_PLAY_PORTS gate (default false); true appends Sunshine/Moonlight + Steam Remote Play inbound ports.

7.70.1 - 2026-06-24

- fix: guard _err VERIFY_FAIL increment with set -q.

7.70.0 - 2026-06-23

- regdom: remove /etc/conf.d/wireless-regdom; /etc/iw-regdomain retained. Managed configs 18 -> 17, SYSTEM_DESTINATIONS 15 -> 14, _RY_POST_HOOKS 18 -> 17.
- bluetooth: ReconnectAttempts 7 -> 3; remove ReconnectIntervals.
- preflight: raise mesa soft-floor warn 25.3 -> 26.0.

7.69.1 - 2026-06-22

- refactor: extract _content_fn_for to single-source generator-name derivation.

7.69.0 - 2026-06-22

- cmdline: remove amd_iommu=on from KERNEL_PARAMS (redundant on AMD). KERNEL_PARAMS 13 -> 12.

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
