ry-install changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

7.58.1 - 2026-06-21

- fix: sync header-comment version to 7.58.0 (was stale 7.57.1; cosmetic, runtime reads $VERSION).
- style: trim verbose source comments to vital information; rendered configs byte-identical.

7.58.0 - 2026-06-20

- refactor: move _configure_services_iwd_handoff to its Phase 4 position (5th, before enable/regdom); source order matches run order. Adds IWD HANDOFF sub-banner. Behavior unchanged.

7.57.3 - 2026-06-20

- refactor: unify managed-file order across SYSTEM_DESTINATIONS, _content_ fns, _RY_POST_HOOKS onto one canonical order (boot -> drop-ins -> network -> tuning -> user). SYSTEM_DESTINATIONS is the source of truth.
- docs: sync README Configuration and Managed Files tables to the canonical order.

7.57.2 - 2026-06-20

- style: collapse 8 embedded-data lists to single-line form (-66 lines, zero behavior change). Count-guarded and source-bearing lists left vertical.

7.57.1 - 2026-06-20

- docs: reconcile README against script; trim prose and tables to vital info, all values byte-identical.
- docs: add expand-cue lines above each collapsible so folded content is signposted.
- docs: standardize TTM UMA precondition wording on the code-enforced ≤ 1 GiB threshold.

7.57.0 - 2026-06-20

- pkg: add rtkit to PKGS_ADD; complements realtime-privileges.
- boot: add clearcpuid=rdseed to KERNEL_PARAMS; masks the broken Zen5 RDSEED flag (CVE-2025-62626), silencing the kernel warning.
- guard: bump _ir_validate_counts (KERNEL_PARAMS 11->12, PKGS_ADD 16->17).

7.56.0 - 2026-06-20

- docs: README Known Issues adds Configuration-level subsection (amd_iommu/NPU, TTM UMA WARN, Zen5 RDSEED).
- cpu: governor performance -> powersave so EPP is honored under amd_pstate=active.
- cpu: EPP performance -> balance_performance (udev rule + verify).
- preflight: soft-warn mesa < 25.3 for gfx1151 RADV stability; non-fatal.

7.55.2 - 2026-06-20

- docs: add badge row, Contents table, Contributing and Security sections to README.
- docs: fold long Configuration, Managed Files, and exit-code tables behind <details>.

7.55.1 - 2026-06-20

- json: rewrite _json_str backslash-doubling to \x5c literals; fixes highlighter desync, byte-identical output.

7.55.0 - 2026-06-20

- udev: scope GPU clock-floor rule to card device (KERNEL card[0-9], ACTION add).
- verify: _vss_udev asserts GPU rule card-scoped.
- docs: README notes why realtime/i2c group steps are hinted, not auto-run.

7.54.14 - 2026-06-19

- comment: fix two section banners; trim metachar-class regex note.

7.54.13 - 2026-06-19

- mangohud: order gpu_core_clock before gpu_temp.

7.54.12 - 2026-06-18

- comment: sync ten --description strings to bodies.
- fix: restore RY_RUN_TIMEOUT invalid-value warning quote-split.
- docs: trim README; runnable Uninstall commands; name hard-dependency set.
- preflight: list all four probe hosts in _install_preflight fallback.

7.54.7 - 2026-06-18

- docs: correct Phase 4 order, GTT label, systemd badge, exit-2 paths, cmdline order, ABRT 134.
- argparse: replace deprecated status basename with path basename.
- signals: remove unreachable SIGUSR1/SIGUSR2 cases from _cleanup.

7.54.2 - 2026-06-17

- firewall: flush ufw only after nftables default-deny live; else retain + warn.
- install-file: boot/cmdline post-hook exiting boot-critical prints DO-NOT-REBOOT.
- udev: tighten NVMe match to nvme[0-9]*n[0-9]*; warn when udevadm verify unavailable.
- verify: _vre_fstab fails noatime+relatime/atime/strictatime.
- vram probe: floor dedicated-VRAM MiB division.

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
- help: condense _ry_show_help; drop pacdiff suggestion.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255).

7.41.0 - 2026-06-14

- network: keep iwd as NM backend; handoff disables iwd.service.
- packages: drop wpa_supplicant from PKGS_ADD.
- baloo: add baloofilerc (Indexing-Enabled=false).
- cmdline: remove amdgpu.ppfeaturemask.
- guard: sourced-execution guard refuses when status filename is '-'.
- regdom: remove --country; regdomain fixed at US.
- preflight: fix SYSTEM_DESTINATIONS count check (17 to 16).

7.39.0 - 2026-06-13

- udev: merge ioscheduler + EPP rules into 60-ry-perf.rules; pin EPP performance.
- verify: assert nftables ICMPv6 NDP/PMTUD accept.
- fstab: add line-count parity gate ahead of size floor.
- nftables: accept inbound ICMPv6 NDP and PMTUD.
- sysctl: demote tcp_bbr module-version line to advisory.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off -> pcie_aspm.policy=performance.
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642.
- preflight: cmp is a hard dependency for the mkinitcpio.conf revert gate.

7.28.0 - 2026-06-12

- packages: remove kdeconnect, add mkinitcpio-firmware, drop AUR.
- firewall: reduce inbound to established/related, loopback, ICMPv4.

Earlier releases: see git history.
