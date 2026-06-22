ry-install changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

7.67.0 - 2026-06-22

- style: normalize lone $(string sub ...) inline command substitution in the RDSEED-microcode probe to fish (cmd) form; behavior byte-identical (math hex parse unchanged).

7.66.0 - 2026-06-22

- verify: split iwd-process state check out of _vrsv_wifi into _vrsv_wifi_iwd_proc; behavior unchanged.
- style: trim verbose source comments to vital information; rendered configs byte-identical.

7.65.0 - 2026-06-21

- mangohud: order fps/frametime ahead of GPU/CPU block; drop header comment.
- style: trim redundant embedded-data comments; fix post-hook banner count (19 -> 18).

7.64.0 - 2026-06-21

- drirc: remove 95-ry-radv-apu.conf (gfx1151 reports uma:1 natively).
- network: remove dormant iwd/main.conf; NM_WIFI_BACKEND=iwd opt-in retained.
- network: 99-cachyos-nm.conf header tracks NM_WIFI_BACKEND.
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
- preflight: add _ry_check_umip_disabled (INFO while 514 set).
- sysctl: add vm.swappiness=150, vm.vfs_cache_pressure=50, vm.page-cluster=0. SYSCTL_VALUES 8 -> 11.
- gpu: remove ry-amdgpu-strixhalo.conf (kernel >= 6.16.9 auto-sizes GTT). SYSTEM_DESTINATIONS 16 -> 15.

7.58.1 - 2026-06-21

- fix: sync header-comment version (cosmetic; runtime reads $VERSION).
- style: trim verbose source comments; rendered configs byte-identical.

7.58.0 - 2026-06-20

- refactor: move _configure_services_iwd_handoff to its Phase 4 slot. Behavior unchanged.

7.57.3 - 2026-06-20

- refactor: unify managed-file order onto one canonical order; SYSTEM_DESTINATIONS is source of truth.

7.57.2 - 2026-06-20

- style: collapse 8 embedded-data lists to single-line form (-66 lines, zero behavior change).

7.57.1 - 2026-06-20

- docs: reconcile README against script; trim prose and tables, values byte-identical.

7.57.0 - 2026-06-20

- pkg: add rtkit to PKGS_ADD.
- boot: add clearcpuid=rdseed (masks broken Zen5 RDSEED flag, CVE-2025-62626).
- guard: _ir_validate_counts (KERNEL_PARAMS 11 -> 12, PKGS_ADD 16 -> 17).

7.56.0 - 2026-06-20

- cpu: governor performance -> powersave so EPP is honored under amd_pstate=active.
- cpu: EPP performance -> balance_performance (udev rule + verify).
- preflight: soft-warn mesa < 25.3 for gfx1151 RADV stability; non-fatal.

7.55.2 - 2026-06-20

- docs: add badge row, Contents table, Contributing and Security sections.
- docs: fold long tables behind <details>.

7.55.1 - 2026-06-20

- json: rewrite _json_str backslash-doubling to \x5c literals; byte-identical output.

7.55.0 - 2026-06-20

- udev: scope GPU clock-floor rule to card device (KERNEL card[0-9], ACTION add).
- verify: _vss_udev asserts GPU rule card-scoped.

7.54.14 - 2026-06-19

- comment: fix two section banners; trim metachar-class regex note.

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

7.48.0 - 2026-06-16

- cmdline: iommu=pt -> amd_iommu=off.
- udev: add gfx1151 GPU clock-floor to 60-ry-perf.rules.

7.47.0 - 2026-06-16

- mangohud: add gpu_power, cpu_temp, fps_metrics; drop gpu_mem_clock, swap.

7.46.0 - 2026-06-16

- docs: document TTM GTT cap, MT7925 power-save rationale, radv unified-heap provenance.

7.44.0 - 2026-06-15

- mangohud: add readout-only MangoHud.conf; env adds MANGOHUD=1.
- json: _json_str escapes control chars over whole value.
- disk: /boot free-space gate only when /boot is own mount.
- help: condense _ry_show_help.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255).

7.41.0 - 2026-06-14

- network: keep iwd as NM backend; handoff disables iwd.service.
- packages: drop wpa_supplicant from PKGS_ADD.
- baloo: add baloofilerc (Indexing-Enabled=false).
- cmdline: remove amdgpu.ppfeaturemask.
- guard: sourced-execution guard refuses when status filename is '-'.
- regdom: remove --country; regdomain fixed at US.

7.39.0 - 2026-06-13

- udev: merge ioscheduler + EPP rules into 60-ry-perf.rules; pin EPP performance.
- verify: assert nftables ICMPv6 NDP/PMTUD accept.
- fstab: add line-count parity gate ahead of size floor.
- nftables: accept inbound ICMPv6 NDP and PMTUD.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off -> pcie_aspm.policy=performance.
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642.
- preflight: cmp is a hard dependency for the mkinitcpio.conf revert gate.

7.28.0 - 2026-06-12

- packages: remove kdeconnect, add mkinitcpio-firmware, drop AUR.
- firewall: reduce inbound to established/related, loopback, ICMPv4.
