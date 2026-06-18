ry-install changelog - newest first.

7.54.3 - 2026-06-17

- comment: clarify the mkinitcpio validator banner count (8 pairwise + base-first + fsck-last) and label the two Phase 4 banners as the Services slot, with fstab as a sub-step.

7.54.2 - 2026-06-17

- firewall: drop ufw.service from the mask set with a WARN until the nftables default-deny ruleset is confirmed live; masking it while its rules are retained would block ufw's reload on the next boot and leave the host unfirewalled.
- signals: stop trapping SIGUSR1/SIGUSR2 as fatal; they are application-defined and no longer tear down a mid-flight install.
- udev: tighten the NVMe scheduler KERNEL match to nvme[0-9]*n[0-9]* (namespace block devices), matching the runtime verifier glob.
- verify: _vre_fstab fails an ext4 entry carrying relatime/atime/strictatime alongside noatime (kernel honours the last token); _vrs_nm_perms falls back to sudo grep when 99-cachyos-nm.conf is 0600 so the backend probe no longer misreports.
- regdom: a failed iw reg set records WARN (was DEFER), distinguishing tried-and-failed from deferred-by-absence.
- pkg-remove: add --foreground to the pactree rdep probe timeout so SIGINT reaches pactree.

7.54.1 - 2026-06-17

- vram probe: floor the dedicated-VRAM MiB division; a non-1-MiB-multiple total produced a float the integer UMA-precondition test rejected, silently skipping the warning.

7.54.0 - 2026-06-17

- firewall: flush ufw only after the nftables default-deny ruleset is confirmed live (inet/filter/input chain probe); retain ufw and warn otherwise, closing the unfirewalled window.
- install-file: a boot/cmdline post-hook exiting boot-critical prints the DO-NOT-REBOOT recovery banner, matching the full install path.
- udev: warn (not just log) when udevadm verify is unavailable (systemd < 254) and a rule is reloaded unvalidated.

7.53.0 - 2026-06-17

- nftables: scope inbound IPv4 ICMP to diagnostics (echo-reply, destination-unreachable, time-exceeded, parameter-problem); drop inbound echo-request. Was a blanket accept.
- preflight: amdgpu hard-fails config validation when modinfo cannot find it; other MODULES entries stay warn-only.
- preflight: network ICMP fallback probes 1.1.1.1 and 8.8.8.8 so a single firewalled host no longer mislabels the failure.
- check: log CHECK_NFT_UNPROBEABLE when nft is absent, so exit 10 from a missing nft is distinguishable from drift.
- verify: drop the systemd-analyze boot-time check, the THP/KSM check, and BOOT_TIME_TARGET.

7.52.0 - 2026-06-17

- ttm: relabel the 32 GiB GTT value as a cap, not the default (in-kernel default ~50% of RAM, ~62 GiB on 128 GB).
- docs: note the deliberate divergences from CachyOS defaults (NVMe scheduler none, plaintext DNS with mDNS/LLMNR off, systemd-oomd left untouched); record the Known Issues status for MES, RTL8127, MT7925, and ACP.

7.51.6 - 2026-06-16

- udev: EPP rule ACTION add->add|change so EPP re-asserts after an AC/DC switch.

7.51.4 - 2026-06-16

- verify: _vss_udev asserts the GPU clock-floor rule alongside the NVMe scheduler and EPP; _vss_regdom asserts /etc/conf.d/wireless-regdom in addition to /etc/iw-regdomain.

7.51.0 - 2026-06-16

- init: add _ir_validate_post_hooks — refuse deploy when a _RY_POST_HOOKS tag has no _post_<tag> handler.

7.48.0 - 2026-06-16

- cmdline: IOMMU iommu=pt to amd_iommu=off (disables AMD-Vi; breaks VFIO/PCI-passthrough and USB4 isolation).
- udev: add a gfx1151 GPU clock-floor to 60-ry-perf.rules (power_dpm_force_performance_level=high); _vrk_gpu_state asserts power_dpm == high.

7.47.0 - 2026-06-16

- mangohud: rework MangoHud.conf — add gpu_power, cpu_temp, fps_metrics=avg,0.01,0.001; drop gpu_mem_clock and swap; reorder (18 to 20 directives).

7.46.0 - 2026-06-16

- docs: document the TTM GTT cap as a tunable (default 32 GiB, LLM profile 116 GiB; amdgpu.gttsize forbidden), the Wi-Fi power-save-off rationale for MT7925/mt76, and the radv_enable_unified_heap_on_apu provenance (Mesa MR !18884).

7.44.6 - 2026-06-15

- env: add MANGOHUD=1 to ENV_VARS; auto-enables the MangoHud overlay for Vulkan apps.

7.44.5 - 2026-06-15

- json: _json_str escapes embedded newlines and other control chars over the whole value (regex mode); the prior literal match dropped everything after the first newline.

7.44.4 - 2026-06-15

- timeout: drop -h from the value-taking sudo-flag skip list in _run_effective_timeout (-h takes no value). No timeout-bypass change.
- disk: run the dedicated /boot free-space gate only when findmnt reports /boot as its own mountpoint.

7.44.3 - 2026-06-15

- cleanup: remove the dead write-only _RY_PACMAN_REVERT_ATTEMPTED global.

7.44.2 - 2026-06-15

- packages: remove the _ip_scan_pacnew post-upgrade scan; .pacnew/.pacsave files are re-deployed on the next full install instead.

7.44.1 - 2026-06-15

- help: condense _ry_show_help to per-flag usage and the exit-code line; sentinel/signal detail defers to the README.
- pacnew: drop the pacdiff suggestion from advisory warnings and the post-revert log line; the script never ran pacdiff.

7.44.0 - 2026-06-15

- mangohud: add ~/.config/MangoHud/MangoHud.conf, a readout-only HUD for the Radeon 8060S, with generator, validator, verify check, and notify-only hook.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255 bytes) before realpath/dispatch; previously failed late at mktemp/mv.

7.42.0 - 2026-06-14

- comment: fix a stale _vrsv_wifi comment (the handoff disables, not masks, iwd.service).

7.41.0 - 2026-06-14

- network: keep iwd as the NM Wi-Fi backend (reverts the 7.40.0 wpa_supplicant switch); the handoff disables (not masks) iwd.service, fixing the iwd/NM race. The iwd runtime check is informational, not a hard fail.
- packages: drop wpa_supplicant from PKGS_ADD (in the CachyOS base).

7.40.0 - 2026-06-14

- network: switch the NM Wi-Fi backend to wpa_supplicant.
- baloo: add ~/.config/baloofilerc (Indexing-Enabled=false).
- cmdline: remove amdgpu.ppfeaturemask (Overdrive hang risk on Strix Halo).
- environment.d: remove PROTON_FSR4_RDNA3_UPGRADE (unverified on gfx1151).

7.39.7 - 2026-06-14

- guard: the sourced-execution guard also refuses when status filename is '-' (piped source).
- PID-recycle: fail closed when getconf CLK_TCK and CONFIG_HZ are both unavailable.

7.39.5 - 2026-06-14

- services: stop enabling and verifying NetworkManager-dispatcher.service; it is socket/D-Bus-activated on demand.

7.39.4 - 2026-06-14

- regdom: remove the --country flag and its ISO-3166 table; the wireless regdomain is fixed at US (retune COUNTRY).

7.39.2 - 2026-06-14

- cleanup: track the run-overflow spill dir on creation; spills are ephemeral.

7.39.1 - 2026-06-14

- preflight: fix the SYSTEM_DESTINATIONS count check (17 to 16); the stale count aborted every mode at preflight.

7.39.0 - 2026-06-13

- udev: merge 60-ry-ioschedulers.rules and 61-ry-epp.rules into 60-ry-perf.rules.

7.38.5 - 2026-06-13

- rename _mr_copy_size_verify to _mr_copy_cmp_verify (cp + cmp byte-exact).

7.38.0 - 2026-06-13

- verify: --verify asserts the nftables ICMPv6 NDP/PMTUD accept rule, static and live.
- fstab: add a line-count parity gate ahead of the size floor and findmnt --verify.

7.37.0 - 2026-06-13

- cpupower: GOVERNOR powersave to performance; EPP stays pinned via udev.

7.36.1 - 2026-06-13

- PID-recycle: starttime recovers USER_HZ from CONFIG_HZ before falling back to 100.
- probes: run nft and iw under LC_ALL=C.

7.36.0 - 2026-06-13

- package-verify: refuse when pacman is unavailable after upgrade; run tainted, rebuild skipped.

7.35.2 - 2026-06-13

- sysctl: demote the tcp_bbr module-version line to advisory; selection is asserted via tcp_congestion_control.
- finalize: validate NM_RESTART_DELAY as a non-negative integer before sleep.

7.35.0 - 2026-06-13

- udev: pin AMD P-State EPP to performance.
- nftables: accept inbound ICMPv6 NDP and PMTUD; the prior ruleset dropped all ICMPv6.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off to pcie_aspm.policy=performance.
- sysctl: add vm.compaction_proactiveness=0 and vm.max_map_count=2147483642.
- preflight: cmp is now a hard dependency for the byte-exact mkinitcpio.conf revert gate.
- network: _is_wifi_active_route adds a policy-routing table fallback.

7.28.0 - 2026-06-12

- packages: remove kdeconnect, add mkinitcpio-firmware, drop AUR (pacman-only).
- firewall: reduce inbound to established/related, loopback, and ICMPv4; make the boot-taint gate unconditional.

Earlier releases: see git history.
