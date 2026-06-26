ry-install changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

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

7.59.0 - 2026-06-21

- boot: add clearcpuid=514 (UMIP off). KERNEL_PARAMS 12 -> 13.
- preflight: add _ry_check_umip_disabled.
- sysctl: add vm.swappiness=150, vm.vfs_cache_pressure=50, vm.page-cluster=0. SYSCTL_VALUES 8 -> 11.
- gpu: remove ry-amdgpu-strixhalo.conf. SYSTEM_DESTINATIONS 16 -> 15.

7.58.1 - 2026-06-21

- fix: sync header-comment version (runtime reads $VERSION).

7.58.0 - 2026-06-20

- refactor: move _configure_services_iwd_handoff to its Phase 4 slot.

7.57.3 - 2026-06-20

- refactor: unify managed-file order; SYSTEM_DESTINATIONS is source of truth.

7.57.2 - 2026-06-20

- style: collapse embedded-data lists to single-line form.

7.57.1 - 2026-06-20

- docs: reconcile README against script.

7.57.0 - 2026-06-20

- pkg: add rtkit to PKGS_ADD.
- boot: add clearcpuid=rdseed (masks broken Zen5 RDSEED flag, CVE-2025-62626).
- guard: _ir_validate_counts (KERNEL_PARAMS 11 -> 12, PKGS_ADD 16 -> 17).

7.56.0 - 2026-06-20

- cpu: governor performance -> powersave so EPP is honored under amd_pstate=active.
- cpu: EPP performance -> balance_performance.
- preflight: soft-warn mesa < 25.3 for gfx1151 RADV stability.

7.55.2 - 2026-06-20

- docs: add badge row, Contents table, Contributing and Security sections.

7.55.1 - 2026-06-20

- json: rewrite _json_str backslash-doubling to \x5c literals.

7.55.0 - 2026-06-20

- udev: scope GPU clock-floor rule to card device (KERNEL card[0-9], ACTION add).
- verify: _vss_udev asserts GPU rule card-scoped.

7.54.14 - 2026-06-19

- comment: fix two section banners.

7.54.13 - 2026-06-19

- mangohud: order gpu_core_clock before gpu_temp.

7.54.12 - 2026-06-18

- comment: sync ten --description strings to bodies.
- fix: restore RY_RUN_TIMEOUT invalid-value warning quote-split.
- preflight: list all four probe hosts in fallback.

7.54.7 - 2026-06-18

- docs: correct Phase 4 order, GTT label, systemd badge, exit-2 paths.
- argparse: replace deprecated status basename with path basename.
- signals: remove unreachable SIGUSR1/SIGUSR2 cases from _cleanup.

7.54.2 - 2026-06-17

- firewall: flush ufw only after nftables default-deny live; else retain + warn.
- install-file: boot/cmdline post-hook exiting boot-critical prints DO-NOT-REBOOT.
- udev: tighten NVMe match to nvme[0-9]*n[0-9]*.
- verify: _vre_fstab fails noatime+relatime/atime/strictatime.

7.53.0 - 2026-06-17

- nftables: scope inbound IPv4 ICMP to diagnostics; drop echo-request.
- preflight: amdgpu hard-fails when modinfo misses it; ICMP fallback 1.1.1.1 + 8.8.8.8.
- verify: drop systemd-analyze boot-time, THP/KSM, BOOT_TIME_TARGET.

7.52.0 - 2026-06-17

- ttm: relabel 32 GiB GTT value as a cap.
- docs: note CachyOS divergences; record Known Issues (MES, RTL8127, MT7925, ACP).

7.51.0 - 2026-06-16

- udev: EPP rule add -> add|change (re-asserts after AC/DC).
- verify: _vss_udev asserts GPU clock-floor; _vss_regdom asserts wireless-regdom.
- init: _ir_validate_post_hooks refuses deploy on hook tag with no handler.

7.48.0 and earlier - history trimmed

- Entries for 7.48.0 and earlier removed from this file. See git tags / history for the full record.
