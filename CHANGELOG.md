ry-install changelog - newest first.

# 7.37.0 - 2026-06-13

- cpupower-service GOVERNOR changed from powersave to performance; under amd_pstate=active the scaling governor is driver-governed (valid values powersave/performance) and EPP stays pinned performance via 61-ry-epp.rules. Static and runtime governor checks compare against the new value.

# 7.36.1 - 2026-06-13

- PID-recycle starttime math recovers USER_HZ from CONFIG_HZ (/proc/config.gz) when getconf CLK_TCK is unavailable, before falling back to 100; prevents a false lock-reclaim of a live instance on CONFIG_HZ!=100 kernels.
- nft and iw runtime/verify probes run under LC_ALL=C (matches df/lsmod), so ruleset and regdom checks are locale-stable.

# 7.36.0 - 2026-06-13

- package-verify refuses when the pacman binary is unavailable after the upgrade, instead of letting a 127 exit read as all-present; the run is tainted so the Phase 5 rebuild is skipped.
- collapse multiline header comments to single lines; flatten changelog styling.

# 7.35.2 - 2026-06-13

- tcp_bbr module-version line demoted to advisory; congestion-control selection stays asserted via net.ipv4.tcp_congestion_control.
- validate NM_RESTART_DELAY as a non-negative integer before sleep; log assumed USER_HZ=100 when getconf CLK_TCK is unavailable.

# 7.35.1 - 2026-06-13

- condense inline comments to vital information; trim README and changelog.

# 7.35.0 - 2026-06-13

- pin AMD P-State EPP to performance via /etc/udev/rules.d/61-ry-epp.rules; managed files 17 to 18; EPP check enforced.
- nftables ruleset accepts inbound ICMPv6 NDP and PMTUD; prior ruleset dropped all ICMPv6, breaking IPv6 after NDP cache expiry.

# 7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off to pcie_aspm.policy=performance (12 params).
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642 (8 values).
- cmp is now a hard preflight dependency for the byte-exact mkinitcpio.conf revert gate.
- _is_wifi_active_route adds a policy-routing table fallback for the Wi-Fi NM-restart deferral.

# 7.28.0 - 2026-06-12

- kdeconnect removed; mkinitcpio-firmware added; AUR dropped (pacman-only).
- firewall inbound reduced to established/related, loopback, ICMPv4; boot-taint gate made unconditional.

Earlier releases: see git history.
