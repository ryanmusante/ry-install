ry-install changelog - newest first.

7.39.3 - 2026-06-14

- README trimmed to vital information: per-key config tables collapsed to a per-file purpose summary (script remains the source of truth); document boot and wipe gates and nftables-before-ufw ordering.
- changelog reflowed to a single flat font; verbose entries trimmed.

7.39.2 - 2026-06-14

- track run-overflow spill dir on creation; spills are ephemeral (swept at teardown). _FULL_SPILL gains ephemeral=true.

7.39.1 - 2026-06-14

- fix _ir_validate_counts SYSTEM_DESTINATIONS invariant 17 to 16 (USER_DESTINATIONS is the 17th); stale count aborted every mode at preflight.

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
