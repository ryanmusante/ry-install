ry-install changelog - newest first.

7.51.4 - 2026-06-16

- verify: _vss_udev now asserts the GPU clock-floor rule (power_dpm_force_performance_level="high") alongside the NVMe scheduler and EPP checks.
- verify: _vss_regdom now asserts /etc/conf.d/wireless-regdom (WIRELESS_REGDOM) in addition to /etc/iw-regdomain (COUNTRY); both managed regdom files are now statically verified.
- comment: drop the version stamp from the MangoHud generator comment.
- version: bump to 7.51.4.

7.51.3 - 2026-06-16

- docs: restore comprehensive README and sync concrete tuning values against the script (cmdline params, HOOKS, sysctl, env vars, nftables, loader/sdboot keys, TTM page math, iwd/NM keys). Doc-only.
- version: bump to 7.51.3.

7.51.2 - 2026-06-16

- docs: trim README to vital information; all 13 tables and 80 data rows preserved verbatim. Doc-only.
- version: bump to 7.51.2.

7.51.1 - 2026-06-16

- comment: _awf_make_backup description now lists fstab alongside loader.conf/mkinitcpio.conf; the helper backs up all three. Doc-only.
- version: bump to 7.51.1.

7.51.0 - 2026-06-16

- init: add _ir_validate_post_hooks — refuses to deploy when any _RY_POST_HOOKS pattern has a tag with no _post_<tag> handler (or an empty tag). Mirrors _ir_validate_keys; runs in _init_runtime across all modes.
- version: bump to 7.51.0.

7.50.0 - 2026-06-16

- docs: sync README version stamps (badge + checkout tag) to the script.
- version: bump to 7.50.0.

7.49.0 - 2026-06-16

- docs: model name GTR Pro to GTR9 Pro (header, PROFILE_DESC, MangoHud comment, README); matches official Beelink name. PROFILE_NAME and function names unchanged.
- note: reverses the 7.47.0 F-01 rename; the gtr9 token is reintroduced.
- version: bump to 7.49.0.

7.48.0 - 2026-06-16

- cmdline: IOMMU iommu=pt to amd_iommu=off. Disables AMD-Vi; breaks VFIO/PCI-passthrough and USB4 isolation. Param count unchanged.
- udev: add GPU clock-floor to 60-ry-perf.rules (power_dpm_force_performance_level=high); holds high clock at idle on the 140W APU.
- verify: _vrk_gpu_state asserts power_dpm == high (was auto).
- version: bump to 7.48.0.

7.47.0 - 2026-06-16

- mangohud: rework MangoHud.conf — add gpu_power, cpu_temp, fps_metrics=avg,0.01,0.001; drop gpu_mem_clock and swap; reorder. Directives 18 to 20.
- mangohud: drop in-config comments except the two-line header.
- docs: trim README prose and table cells.
- version: bump to 7.47.0.

7.46.0 - 2026-06-16

- modprobe: document TTM GTT cap as a tunable (default 32 GiB, LLM profile 116 GiB); amdgpu.gttsize forbidden. Values unchanged.
- network: document Wi-Fi power-save-off rationale for MT7925/mt76. Values unchanged.
- drirc: restore radv_enable_unified_heap_on_apu provenance (Mesa MR !18884). Comment only.
- comment: collapse multiline comments to single lines.
- version: bump to 7.46.0.

7.45.0 - 2026-06-15

- docs: changelog reflowed to a single plain font throughout (version lines no longer rendered as headers).
- version: bump to 7.45.0.

7.44.6 - 2026-06-15

- env: add MANGOHUD=1 to ENV_VARS (environment.d); auto-enables the MangoHud overlay for Vulkan apps. ENV_VARS count 9 to 10.

7.44.5 - 2026-06-15

- json: _json_str escapes embedded newlines and other control chars in regex mode against the whole value; the prior literal-mode match dropped everything after the first newline.

7.44.4 - 2026-06-15

- timeout: drop -h from the value-taking sudo-flag skip list in _run_effective_timeout (-h is sudo --help, takes no value). No timeout-bypass change.
- disk: run the dedicated /boot free-space gate only when findmnt reports /boot as its own mountpoint; otherwise / covers it.

7.44.3 - 2026-06-15

- cleanup: remove the dead write-only _RY_PACMAN_REVERT_ATTEMPTED global (last reader removed in 7.44.2).

7.44.2 - 2026-06-15

- packages: remove the _ip_scan_pacnew post-upgrade scan; .pacnew/.pacsave files are no longer reconciled (re-deployed on the next full install).

7.44.1 - 2026-06-15

- help: condense _ry_show_help to per-flag usage and the exit-code line; sentinel/signal-code detail defers to README.
- pacnew: drop the pacdiff suggestion from advisory warnings and the post-revert log line; the script never ran pacdiff.

7.44.0 - 2026-06-15

- mangohud: add ~/.config/MangoHud/MangoHud.conf, a readout-only HUD for the Radeon 8060S. New generator, validator, verify check, notify-only hook.
- count assertions: USER_DESTINATIONS 2 to 3, _RY_POST_HOOKS 18 to 19, _RY_MANAGED_FILE_COUNT 18 to 19.

7.43.2 - 2026-06-15

- docs: restore the Configuration File/Purpose table for every managed file.
- docs: Quick Start trimmed to vital commands; list order matches script definition order.
- No script logic changes: byte-identical to 7.43.1.

7.43.1 - 2026-06-15

- docs: scope paragraph reformatted as an in-scope/out-of-scope table; Uninstall list as a step/command table. No semantic change.
- No script logic changes: byte-identical to 7.43.0.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255 bytes) before realpath/dispatch; previously failed late at mktemp/mv.
- No other logic changes: byte-identical to 7.42.1.

7.42.1 - 2026-06-14

- comment: correct the content-generator section header count from 17 to 18.
- docs: README Requirements table trimmed to the hard preflight gates.
- No script logic changes: byte-identical to 7.42.0.

7.42.0 - 2026-06-14

- docs: Quick Start pins a released tag; document the RY_RUN_TIMEOUT bypass list; add a destructive-default WARNING to Configuration.
- comment: fix a stale _vrsv_wifi comment (the handoff disables, not masks, iwd.service).
- No script logic changes: byte-identical to 7.41.0.

7.41.0 - 2026-06-14

- network: keep iwd as the NM Wi-Fi backend (reverts the 7.40.0 wpa_supplicant switch); new handoff disables (not masks) iwd.service, fixing the iwd/NM race.
- verify: iwd runtime check is informational, not a hard fail.
- packages: drop wpa_supplicant from PKGS_ADD (in the CachyOS base).
- count assertions: SYSTEM_DESTINATIONS 15 to 16, PKGS_ADD 17 to 16, _RY_POST_HOOKS 17 to 18, _RY_MANAGED_FILE_COUNT 17 to 18.

7.40.0 - 2026-06-14

- network: switch NM Wi-Fi backend iwd to wpa_supplicant. SYSTEM_DESTINATIONS 16 to 15.
- baloo: add ~/.config/baloofilerc (Indexing-Enabled=false). USER_DESTINATIONS 1 to 2.
- cmdline: remove amdgpu.ppfeaturemask (Overdrive hang risk on Strix Halo). KERNEL_PARAMS 12 to 11.
- environment.d: remove PROTON_FSR4_RDNA3_UPGRADE (unverified on gfx1151). ENV_VARS 10 to 9.
- docs: correct model GTR9 Pro to GTR Pro; PROFILE_NAME gtr9_pro to gtr_pro.

7.39.7 - 2026-06-14

- sourced-execution guard also refuses when status filename is '-' (piped source).
- PID-recycle: fail closed when getconf CLK_TCK and CONFIG_HZ are both unavailable.
- README: name cachyos-gaming-applications and mkinitcpio-firmware; enumerate the CLI tools.

7.39.6 - 2026-06-14

- README: correct the kernel-cmdline row; root=UUID=/rw are written by the generator, not sdboot-manage. Doc-only.

7.39.5 - 2026-06-14

- stop enabling and verifying NetworkManager-dispatcher.service; it is socket/D-Bus-activated on demand.

7.39.4 - 2026-06-14

- remove the --country flag and its ISO-3166 table; wireless regdom is fixed at US (retune COUNTRY).
- drop internal count annotations from README, changelog, and script comments.
- collapse the sub-group label comments in the content-generator section.

7.39.3 - 2026-06-14

- README trimmed to vital information; document boot/wipe gates and nftables-before-ufw ordering.
- changelog reflowed to a single flat font; verbose entries trimmed.

7.39.2 - 2026-06-14

- track run-overflow spill dir on creation; spills are ephemeral. _FULL_SPILL gains ephemeral=true.

7.39.1 - 2026-06-14

- fix the SYSTEM_DESTINATIONS count check (17 to 16); the stale count aborted every mode at preflight.

7.39.0 - 2026-06-13

- merge 60-ry-ioschedulers.rules and 61-ry-epp.rules into 60-ry-perf.rules; managed files 18 to 17.

7.38.6 - 2026-06-13

- BOOT_TIME_TARGET 15 to 20 s; near-miss band at 18 s. Verify-only.

7.38.5 - 2026-06-13

- rename _mr_copy_size_verify to _mr_copy_cmp_verify (cp + cmp byte-exact).
- comment _far_build_awk_script: commit= rewritten in place; ext4 option order not preserved.

7.38.4 - 2026-06-13

- README: correct atomic-write order to same-FS tmp then render. Doc-only.

7.38.3 - 2026-06-13

- README rewritten in GitHub-flavored Markdown; no logic change.

7.38.2 - 2026-06-13

- condense README; configuration tables retained.

7.38.1 - 2026-06-13

- collapse multiline header comment to a single line; trim changelog entries.

7.38.0 - 2026-06-13

- --verify asserts the nftables ICMPv6 NDP/PMTUD accept rule, static and live.
- fstab rewrite adds a line-count parity gate ahead of the size floor and findmnt --verify.

7.37.0 - 2026-06-13

- cpupower-service GOVERNOR powersave to performance; EPP stays pinned via udev.

7.36.1 - 2026-06-13

- PID-recycle starttime recovers USER_HZ from CONFIG_HZ before falling back to 100.
- nft and iw probes run under LC_ALL=C.

7.36.0 - 2026-06-13

- package-verify refuses when pacman is unavailable after upgrade; run tainted, rebuild skipped.

7.35.2 - 2026-06-13

- tcp_bbr module-version line demoted to advisory; selection asserted via tcp_congestion_control.
- validate NM_RESTART_DELAY as a non-negative integer before sleep.

7.35.1 - 2026-06-13

- condense inline comments; trim README and changelog.

7.35.0 - 2026-06-13

- pin AMD P-State EPP to performance via udev; managed files 17 to 18.
- nftables ruleset accepts inbound ICMPv6 NDP and PMTUD; prior ruleset dropped all ICMPv6.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off to pcie_aspm.policy=performance (12 params).
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642 (8 values).
- cmp is now a hard preflight dependency for the byte-exact mkinitcpio.conf revert gate.
- _is_wifi_active_route adds a policy-routing table fallback.

7.28.0 - 2026-06-12

- kdeconnect removed; mkinitcpio-firmware added; AUR dropped (pacman-only).
- firewall inbound reduced to established/related, loopback, ICMPv4; boot-taint gate made unconditional.

Earlier releases: see git history.
