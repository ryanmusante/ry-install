ry-install - Changelog

All notable changes, newest first. Versions follow MAJOR.MINOR.PATCH.

7.56.0 - 2026-06-20

- cpu: governor performance -> powersave so the EPP hint is honored under amd_pstate=active.
- cpu: EPP performance -> balance_performance (udev rule + static/runtime verify).
- preflight: soft-warn mesa < 25.3 for gfx1151 RADV stability; non-fatal.
- docs: README cpupower/udev row -> powersave + balance_performance.
- docs: note PROFILE_NAME token retention.

7.55.2 - 2026-06-20

- docs: add shields.io badge row, Contents table, Contributing and Security sections to README.
- docs: fold long Configuration, Managed Files, and exit-code tables behind <details> with expand cues.
- docs: split README intro into badge row, blockquote tagline, and pitch.
- docs: README intro says "configs" (was "config generators") to match --help wording.

7.55.1 - 2026-06-20

- json: rewrite _json_str backslash-doubling to '\x5c'/'\x5c\x5c' literals; fixes GitHub highlighter desync. Output byte-identical.
- json: fast-path character class uses \x5c for backslash instead of embedded escaped quote.

7.55.0 - 2026-06-20

- udev: scope GPU clock-floor rule to card device; KERNEL card[0-9]* -> card[0-9], ACTION add|change -> add.
- verify: _vss_udev asserts GPU rule card-scoped (KERNEL=="card[0-9]").
- docs: README notes why realtime/i2c group steps are hinted, not auto-run.

7.54.14 - 2026-06-19

- comment: fix two section banners.
- comment: trim metachar-class regex note.

7.54.13 - 2026-06-19

- mangohud: order gpu_core_clock before gpu_temp.

7.54.12 - 2026-06-18

- comment: sync ten --description strings to bodies.
- docs: trim README; scope cmp note to revert's byte-exact verify.
- fix: restore RY_RUN_TIMEOUT invalid-value warning quote-split.
- docs: clarify "no bundled dependencies" in README and help.
- docs: runnable Uninstall commands; scope usermod rows per group.
- docs: name hard-dependency set; note RY_RUN_TIMEOUT-exempt commands; cross-ref Managed Files.
- docs: correct footer note - gen/run sentinels internal-only.
- comment: trim managed-file-count, timeout, network-fallback comments; drop unverifiable notes.
- preflight: list all four probe hosts in _install_preflight fallback.

7.54.7 - 2026-06-18

- docs: correct Phase 4 order, GTT retuning label, systemd>=250 badge, exit-2 paths, cmdline order, ABRT 134.
- argparse: replace deprecated status basename with path basename.
- modprobe: name amdttm.* in deprecation note.
- signals: remove unreachable SIGUSR1/SIGUSR2 cases from _cleanup.
- help: clarify exit-code note - only 128+N in footer.
- comments: trim inline comments; clarify mkinitcpio validator + Phase 4 banners.

7.54.2 - 2026-06-17

- firewall: flush ufw only after nftables default-deny live; else retain + warn.
- install-file: boot/cmdline post-hook exiting boot-critical prints DO-NOT-REBOOT.
- udev: tighten NVMe match to nvme[0-9]*n[0-9]*; warn when udevadm verify unavailable.
- verify: _vre_fstab fails noatime+relatime/atime/strictatime; _vrs_nm_perms sudo-grep fallback.
- regdom: failed iw reg set records WARN.
- pkg-remove: add --foreground to pactree rdep probe timeout.
- vram probe: floor dedicated-VRAM MiB division.

7.53.0 - 2026-06-17

- nftables: scope inbound IPv4 ICMP to diagnostics; drop echo-request.
- preflight: amdgpu hard-fails when modinfo misses it; ICMP fallback 1.1.1.1 + 8.8.8.8.
- check: log CHECK_NFT_UNPROBEABLE when nft absent.
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

- mangohud: add readout-only MangoHud.conf.
- env: add MANGOHUD=1 to ENV_VARS.
- json: _json_str escapes control chars over whole value.
- timeout: drop -h from value-taking sudo-flag skip list.
- disk: /boot free-space gate only when /boot is own mount.
- cleanup: remove dead _RY_PACMAN_REVERT_ATTEMPTED global.
- packages: remove _ip_scan_pacnew post-upgrade scan.
- help: condense _ry_show_help; drop pacdiff suggestion.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255).

7.41.0 - 2026-06-14

- network: keep iwd as NM backend; handoff disables iwd.service.
- packages: drop wpa_supplicant from PKGS_ADD.
- baloo: add baloofilerc (Indexing-Enabled=false).
- cmdline: remove amdgpu.ppfeaturemask.
- environment.d: remove PROTON_FSR4_RDNA3_UPGRADE.
- comment: fix stale _vrsv_wifi comment.
- guard: sourced-execution guard refuses when status filename is '-'.
- PID-recycle: fail closed when CLK_TCK and CONFIG_HZ both absent.
- services: stop enabling NetworkManager-dispatcher.service.
- regdom: remove --country; regdomain fixed at US.
- cleanup: track run-overflow spill dir on creation.
- preflight: fix SYSTEM_DESTINATIONS count check (17 to 16).

7.39.0 - 2026-06-13

- udev: merge ioscheduler + EPP rules into 60-ry-perf.rules; pin EPP performance.
- verify: assert nftables ICMPv6 NDP/PMTUD accept.
- fstab: add line-count parity gate ahead of size floor.
- cpupower: GOVERNOR powersave -> performance.
- nftables: accept inbound ICMPv6 NDP and PMTUD.
- refactor: rename _mr_copy_size_verify to _mr_copy_cmp_verify.
- PID-recycle: starttime recovers USER_HZ from CONFIG_HZ before fallback.
- probes: run nft and iw under LC_ALL=C.
- package-verify: refuse when pacman unavailable after upgrade.
- sysctl: demote tcp_bbr module-version line to advisory.
- finalize: validate NM_RESTART_DELAY as non-negative integer.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off -> pcie_aspm.policy=performance.
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642.
- preflight: cmp is a hard dependency for the mkinitcpio.conf revert gate.
- network: _is_wifi_active_route adds policy-routing table fallback.

7.28.0 - 2026-06-12

- packages: remove kdeconnect, add mkinitcpio-firmware, drop AUR.
- firewall: reduce inbound to established/related, loopback, ICMPv4.

Earlier releases: see git history.
