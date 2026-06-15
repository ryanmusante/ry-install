ry-install changelog - newest first.

7.42.0 - 2026-06-14

- docs: README Quick Start pins a released tag (git checkout v7.42.0) and notes the contract is version-coupled; the unpinned clone could drift from the documented exit-code/path contract.
- docs: document the RY_RUN_TIMEOUT bypass list (pacman/mkinitcpio/sdboot-manage/paccache/updatedb/pkgfile) in README — these long-running ops are intentionally not time-capped because a SIGKILL mid-transaction corrupts db.lck or skips the mkinitcpio rollback (behavior was code-only via _run_effective_timeout).
- docs: add a destructive-default WARNING to README Configuration — the no-args run removes kdeconnect/micro/cachy-update/plymouth via rdep-aware pacman -Rns; edit PKGS_DEL to retain. Mirrors the existing IMPORTANT note in Quick Start.
- comment: fix a stale code comment in _vrsv_wifi that still read "iwd.service is masked" — the 7.41.0 handoff disables (not masks) iwd.service. Comment-only; the disable-not-mask logic was already correct.
- No script logic changes: content generators, validators, install phases, and exit codes are byte-identical to 7.41.0. Version bump tracks the documentation sync only.

7.41.0 - 2026-06-14

- network: keep iwd as the NM Wi-Fi backend (reverts the 7.40.0 wpa_supplicant switch) and fix the actual fault behind the "IWD device named wlan0 is not a Wifi device" / IPv4-forwarding errors: the profile never stopped the standalone iwd.service, so iwd and NetworkManager raced for wlan0. New _configure_services_iwd_handoff disables (not masks) iwd.service after the mask phase, so NM is the sole manager and still D-Bus-activates iwd on demand; unmasks first if a prior run masked it. Restores /etc/iwd/main.conf, its generator, IWD_* globals, _vss_iwd, the iwd post-hook, and _post_nm iwd try-restart. SYSTEM_DESTINATIONS 15 to 16; managed files 17 to 18 (baloo retained).
- verify: iwd runtime check is now informational, not a hard fail — a non-running iwd process is correct under NM on-demand activation (was FAIL "iwd process: NOT running").
- packages: drop wpa_supplicant from PKGS_ADD (17 to 16); iwd is provided by the CachyOS base.
- count assertions: SYSTEM_DESTINATIONS 15 to 16, PKGS_ADD 17 to 16, _RY_POST_HOOKS 17 to 18, _RY_MANAGED_FILE_COUNT 17 to 18.
- docs: README scope/config/managed-files/units revert to iwd and document the iwd.service-disabled handoff.

7.40.0 - 2026-06-14

- network: switch NM Wi-Fi backend iwd to wpa_supplicant. NM+iwd is upstream-experimental with documented KDE Plasma login/reconnect breakage and was failing on the target hardware. Drops managed file /etc/iwd/main.conf, its generator, the IWD_* globals, and the iwd-specific verify/restart paths; SYSTEM_DESTINATIONS 16 to 15. Removes the "NM + iwd intermittent" known-issue row.
- baloo: add ~/.config/baloofilerc (Indexing-Enabled=false) to disable KDE file indexing; new generator, _verify_static_user check, and _post_baloo hook running balooctl6 disable. USER_DESTINATIONS 1 to 2; managed files stay 17 (-1 iwd, +1 baloo).
- cmdline: remove amdgpu.ppfeaturemask=0xffff7fff (force-enabled Overdrive; voids upstream bug reports, hang risk on Strix Halo). KERNEL_PARAMS 12 to 11. _vrkm_amdgpu generalized to any amdgpu.* param.
- environment.d: remove PROTON_FSR4_RDNA3_UPGRADE (RDNA3-named, unverified on gfx1151/RDNA 3.5). ENV_VARS 10 to 9.
- modprobe: add non-fatal preflight WARN when dedicated VRAM exceeds 1 GiB, since the 32 GiB TTM GTT cap assumes BIOS UMA=512 MB.
- docs: correct model GTR9 Pro to GTR Pro (matches DMI); PROFILE_NAME gtr9_pro to gtr_pro. Fix environment.d header comment COSMIC to KDE Plasma.
- _RY_PKG_REMOVE_SKIPS preflight count assertions updated: KERNEL_PARAMS 12 to 11, ENV_VARS 10 to 9, PKGS_ADD 16 to 17, SYSTEM_DESTINATIONS 16 to 15, USER_DESTINATIONS 1 to 2 (stale counts abort preflight).
- packages: add wpa_supplicant to PKGS_ADD (16 to 17).

7.39.7 - 2026-06-14

- sourced-execution guard also refuses when status filename is '-' (piped source); stack-trace match still catches source-by-path.
- PID-recycle: fail closed when getconf CLK_TCK and CONFIG_HZ are both unavailable; the prior USER_HZ=100 fallback could reclaim a live lock.
- README: name cachyos-gaming-applications and mkinitcpio-firmware in the Packages summary; enumerate the CLI tools.

7.39.6 - 2026-06-14

- README: correct the kernel-cmdline row — root=UUID=/rw are written into /etc/kernel/cmdline by the generator, not injected by sdboot-manage. Doc-only.

7.39.5 - 2026-06-14

- stop enabling and verifying NetworkManager-dispatcher.service; it is socket/D-Bus-activated on demand and needs no explicit enable. NetworkManager.service itself is unchanged.

7.39.4 - 2026-06-14

- remove the --country flag and its ISO-3166 validation table; wireless regdom is fixed at US (retune COUNTRY in the script to change it).
- drop internal count annotations from README, changelog, and script comments.
- collapse the sub-group label comments in the content-generator section.

7.39.3 - 2026-06-14

- README trimmed to vital information: config tables collapsed to a per-file summary; document boot/wipe gates and nftables-before-ufw ordering.
- changelog reflowed to a single flat font; verbose entries trimmed.

7.39.2 - 2026-06-14

- track run-overflow spill dir on creation; spills are ephemeral (swept at teardown). _FULL_SPILL gains ephemeral=true.

7.39.1 - 2026-06-14

- fix the SYSTEM_DESTINATIONS count check (17 to 16; USER_DESTINATIONS is the 17th); the stale count aborted every mode at preflight.

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
