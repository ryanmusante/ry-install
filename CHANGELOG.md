ry-install changelog - newest first.

7.54.12 - 2026-06-18

- comment: sync ten function --description strings to their bodies.
- docs: trim README prose to vital information; scope the cmp note to the revert's byte-exact verify.
- fix: restore the RY_RUN_TIMEOUT invalid-value warning's quote-split (now prints 3600s).

7.54.10 - 2026-06-18

- docs: clarify "no external dependencies" to "no bundled dependencies" in the README intro and help text.
- docs: give runnable commands for README Uninstall steps 1-4.
- docs: scope the README usermod troubleshooting rows per group.
- comment: trim the _RY_MANAGED_FILE_COUNT, _run_effective_timeout, and network-fallback inline comments to vital information.
- comment: drop the unverifiable notes from EXPECTED_VULKAN_PKGS and EXPECTED_SERVICES.

7.54.9 - 2026-06-18

- preflight: list all four probe hosts in the _install_preflight fallback evidence string, matching _ry_check_network.

7.54.8 - 2026-06-18

- docs: correct the README footer note; gen/run sentinels are internal-only.
- docs: name the full hard-dependency set in README Requirements.
- docs: note pacman/mkinitcpio/sdboot-manage/paccache/updatedb/pkgfile are exempt from RY_RUN_TIMEOUT.
- docs: cross-reference Managed Files to the Configuration table.

7.54.7 - 2026-06-18

- docs: correct the Phase 4 sub-step order; nftables enables inside the mask step, not standalone before it.
- docs: relabel the 116 GiB GTT figure as a retuning example.
- docs: add the systemd >= 250 floor to the README version badge.
- docs: clarify that both --install-file rejection paths exit 2.
- argparse: replace deprecated status basename with path basename.
- modprobe: name amdttm.* alongside amdgpu.gttsize in the deprecation note.

7.54.6 - 2026-06-18

- docs: reorder the README kernel-cmdline param list to match emission order.

7.54.5 - 2026-06-18

- signals: remove the unreachable SIGUSR1/SIGUSR2 cases from _cleanup.
- help: clarify the exit-code note; only 128+N appears in the footer.
- docs: balance the environment-overrides parenthetical.
- docs: note the fstab backup is written during its atomic rewrite.
- comments: trim verbose inline comments to vital information.

7.54.4 - 2026-06-18

- docs: add ABRT (exit 134) to the README signal-exit table.

7.54.3 - 2026-06-17

- comment: clarify the mkinitcpio validator banner count; label the Phase 4 banners as the Services slot, fstab as a sub-step.

7.54.2 - 2026-06-17

- firewall: drop ufw.service from the mask set with a WARN until the nftables default-deny ruleset is confirmed live.
- signals: stop trapping SIGUSR1/SIGUSR2 as fatal.
- udev: tighten the NVMe scheduler match to nvme[0-9]*n[0-9]*.
- verify: _vre_fstab fails an ext4 entry carrying relatime/atime/strictatime alongside noatime.
- verify: _vrs_nm_perms falls back to sudo grep when 99-cachyos-nm.conf is 0600.
- regdom: a failed iw reg set records WARN.
- pkg-remove: add --foreground to the pactree rdep probe timeout.

7.54.1 - 2026-06-17

- vram probe: floor the dedicated-VRAM MiB division.

7.54.0 - 2026-06-17

- firewall: flush ufw only after the nftables default-deny ruleset is confirmed live; retain ufw and warn otherwise.
- install-file: a boot/cmdline post-hook exiting boot-critical prints the DO-NOT-REBOOT banner.
- udev: warn when udevadm verify is unavailable (systemd < 254) and a rule is reloaded unvalidated.

7.53.0 - 2026-06-17

- nftables: scope inbound IPv4 ICMP to diagnostics; drop inbound echo-request.
- preflight: amdgpu hard-fails config validation when modinfo cannot find it.
- preflight: network ICMP fallback probes 1.1.1.1 and 8.8.8.8.
- check: log CHECK_NFT_UNPROBEABLE when nft is absent.
- verify: drop the systemd-analyze boot-time check, THP/KSM, BOOT_TIME_TARGET.

7.52.0 - 2026-06-17

- ttm: relabel the 32 GiB GTT value as a cap, not the default.
- docs: note the deliberate CachyOS divergences; record Known Issues for MES, RTL8127, MT7925, and ACP.

7.51.6 - 2026-06-16

- udev: EPP rule ACTION add->add|change so EPP re-asserts after AC/DC switch.

7.51.4 - 2026-06-16

- verify: _vss_udev asserts the GPU clock-floor rule; _vss_regdom asserts /etc/conf.d/wireless-regdom.

7.51.0 - 2026-06-16

- init: add _ir_validate_post_hooks - refuse deploy when a _RY_POST_HOOKS tag has no _post_<tag> handler.

7.48.0 - 2026-06-16

- cmdline: IOMMU iommu=pt to amd_iommu=off.
- udev: add a gfx1151 GPU clock-floor to 60-ry-perf.rules.

7.47.0 - 2026-06-16

- mangohud: add gpu_power, cpu_temp, fps_metrics; drop gpu_mem_clock and swap.

7.46.0 - 2026-06-16

- docs: document the TTM GTT cap tunable, the MT7925 power-save-off rationale, and radv_enable_unified_heap_on_apu provenance.

7.44.6 - 2026-06-15

- env: add MANGOHUD=1 to ENV_VARS.

7.44.5 - 2026-06-15

- json: _json_str escapes control chars over the whole value.

7.44.4 - 2026-06-15

- timeout: drop -h from the value-taking sudo-flag skip list.
- disk: run the dedicated /boot free-space gate only when /boot is its own mount.

7.44.3 - 2026-06-15

- cleanup: remove the dead write-only _RY_PACMAN_REVERT_ATTEMPTED global.

7.44.2 - 2026-06-15

- packages: remove the _ip_scan_pacnew post-upgrade scan.

7.44.1 - 2026-06-15

- help: condense _ry_show_help to per-flag usage and the exit-code line.
- pacnew: drop the pacdiff suggestion from advisory warnings.

7.44.0 - 2026-06-15

- mangohud: add ~/.config/MangoHud/MangoHud.conf, a readout-only HUD.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255 bytes).

7.42.0 - 2026-06-14

- comment: fix a stale _vrsv_wifi comment (the handoff disables iwd.service).

7.41.0 - 2026-06-14

- network: keep iwd as the NM Wi-Fi backend; the handoff disables iwd.service.
- packages: drop wpa_supplicant from PKGS_ADD.

7.40.0 - 2026-06-14

- network: switch the NM Wi-Fi backend to wpa_supplicant.
- baloo: add ~/.config/baloofilerc (Indexing-Enabled=false).
- cmdline: remove amdgpu.ppfeaturemask.
- environment.d: remove PROTON_FSR4_RDNA3_UPGRADE.

7.39.7 - 2026-06-14

- guard: the sourced-execution guard also refuses when status filename is '-'.
- PID-recycle: fail closed when getconf CLK_TCK and CONFIG_HZ are both absent.

7.39.5 - 2026-06-14

- services: stop enabling NetworkManager-dispatcher.service.

7.39.4 - 2026-06-14

- regdom: remove the --country flag; the wireless regdomain is fixed at US.

7.39.2 - 2026-06-14

- cleanup: track the run-overflow spill dir on creation.

7.39.1 - 2026-06-14

- preflight: fix the SYSTEM_DESTINATIONS count check (17 to 16).

7.39.0 - 2026-06-13

- udev: merge 60-ry-ioschedulers.rules and 61-ry-epp.rules into 60-ry-perf.rules.

7.38.5 - 2026-06-13

- refactor: rename _mr_copy_size_verify to _mr_copy_cmp_verify.

7.38.0 - 2026-06-13

- verify: --verify asserts the nftables ICMPv6 NDP/PMTUD accept rule.
- fstab: add a line-count parity gate ahead of the size floor.

7.37.0 - 2026-06-13

- cpupower: GOVERNOR powersave to performance.

7.36.1 - 2026-06-13

- PID-recycle: starttime recovers USER_HZ from CONFIG_HZ before falling back.
- probes: run nft and iw under LC_ALL=C.

7.36.0 - 2026-06-13

- package-verify: refuse when pacman is unavailable after upgrade.

7.35.2 - 2026-06-13

- sysctl: demote the tcp_bbr module-version line to advisory.
- finalize: validate NM_RESTART_DELAY as a non-negative integer.

7.35.0 - 2026-06-13

- udev: pin AMD P-State EPP to performance.
- nftables: accept inbound ICMPv6 NDP and PMTUD.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off to pcie_aspm.policy=performance.
- sysctl: add vm.compaction_proactiveness=0 and vm.max_map_count=2147483642.
- preflight: cmp is now a hard dependency for the mkinitcpio.conf revert gate.
- network: _is_wifi_active_route adds a policy-routing table fallback.

7.28.0 - 2026-06-12

- packages: remove kdeconnect, add mkinitcpio-firmware, drop AUR.
- firewall: reduce inbound to established/related, loopback, and ICMPv4.

Earlier releases: see git history.
