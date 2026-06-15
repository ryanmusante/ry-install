ry-install changelog - newest first.

7.43.2 - 2026-06-15

- docs: restore the Configuration File/Purpose table dropped in 7.42.1, expanded to cover every managed file (adds nftables.conf and the regdom files; notes DNSSEC allow-downgrade). The one-line prose summary it replaced is removed.
- docs: Configuration Remove row enumerates all nine PKGS_DEL packages (cachyos-micro-settings and the plymouth-stack members were previously implicit).
- docs: Quick Start trimmed to the five vital commands; inline code comments removed.
- docs: README list order (Install, Mask, File/Purpose, Managed Files groups) reordered to match script definition order; admonitions moved to trail their section content.
- No script logic changes: byte-identical to 7.43.1.

7.43.1 - 2026-06-15

- docs: README scope paragraph reformatted as an in-scope/out-of-scope table; Uninstall numbered list reformatted as a numbered step/command table. Same content, no semantic change.
- No script logic changes: content generators, validators, install phases, exit codes, and the lock/timeout/firewall paths are byte-identical to 7.43.0.

7.43.0 - 2026-06-14

- install-file: reject any path component longer than NAME_MAX (255 bytes) before realpath/dispatch. Previously such a path passed argument validation and failed later at mktemp/mv with ENAMETOOLONG; it now fails early with a usage error.
- No other logic changes: byte-identical to 7.42.1.

7.42.1 - 2026-06-14

- comment: correct the content-generator section header count from 17 to 18 (18 generators map 1:1 to the managed destinations). Comment-only; dispatch and validators unchanged.
- docs: README Requirements table trimmed to the hard preflight gates; the duplicate Configuration file table folded into prose.
- No script logic changes: content generators, validators, install phases, and exit codes are byte-identical to 7.42.0.

7.42.0 - 2026-06-14

- docs: README Quick Start pins a released tag and notes the contract is version-coupled.
- docs: document the RY_RUN_TIMEOUT bypass list (pacman/mkinitcpio/sdboot-manage/paccache/updatedb/pkgfile) in README; these long-running ops are not time-capped because a SIGKILL mid-transaction corrupts db.lck or skips the mkinitcpio rollback.
- docs: add a destructive-default WARNING to README Configuration (no-args run removes kdeconnect/micro/cachy-update/plymouth; edit PKGS_DEL to retain).
- comment: fix a stale _vrsv_wifi comment that read "iwd.service is masked"; the handoff disables, not masks. Comment-only.
- No script logic changes: byte-identical to 7.41.0.

7.41.0 - 2026-06-14

- network: keep iwd as the NM Wi-Fi backend (reverts the 7.40.0 wpa_supplicant switch); new _configure_services_iwd_handoff disables (not masks) iwd.service after the mask phase, so NM is the sole manager and still D-Bus-activates iwd on demand. Fixes the iwd/NetworkManager race for wlan0.
- verify: iwd runtime check is now informational, not a hard fail; a non-running iwd process is correct under NM on-demand activation.
- packages: drop wpa_supplicant from PKGS_ADD; iwd is provided by the CachyOS base.
- count assertions: SYSTEM_DESTINATIONS 15 to 16, PKGS_ADD 17 to 16, _RY_POST_HOOKS 17 to 18, _RY_MANAGED_FILE_COUNT 17 to 18.

7.40.0 - 2026-06-14

- network: switch NM Wi-Fi backend iwd to wpa_supplicant (NM+iwd was upstream-experimental with KDE login/reconnect breakage). SYSTEM_DESTINATIONS 16 to 15.
- baloo: add ~/.config/baloofilerc (Indexing-Enabled=false); new generator, verify check, and _post_baloo hook. USER_DESTINATIONS 1 to 2.
- cmdline: remove amdgpu.ppfeaturemask=0xffff7fff (Overdrive hang risk on Strix Halo). KERNEL_PARAMS 12 to 11.
- environment.d: remove PROTON_FSR4_RDNA3_UPGRADE (unverified on gfx1151). ENV_VARS 10 to 9.
- modprobe: non-fatal preflight WARN when dedicated VRAM exceeds 1 GiB (32 GiB TTM GTT cap assumes BIOS UMA=512 MB).
- docs: correct model GTR9 Pro to GTR Pro; PROFILE_NAME gtr9_pro to gtr_pro.

7.39.7 - 2026-06-14

- sourced-execution guard also refuses when status filename is '-' (piped source); stack-trace match still catches source-by-path.
- PID-recycle: fail closed when getconf CLK_TCK and CONFIG_HZ are both unavailable; the prior USER_HZ=100 fallback could reclaim a live lock.
- README: name cachyos-gaming-applications and mkinitcpio-firmware in the Packages summary; enumerate the CLI tools.

7.39.6 - 2026-06-14

- README: correct the kernel-cmdline row; root=UUID=/rw are written into /etc/kernel/cmdline by the generator, not injected by sdboot-manage. Doc-only.

7.39.5 - 2026-06-14

- stop enabling and verifying NetworkManager-dispatcher.service; it is socket/D-Bus-activated on demand. NetworkManager.service itself is unchanged.

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
