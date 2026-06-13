ry-install changelog - newest first.

7.35.2 - 2026-06-13

- verify: tcp_bbr module-version line demoted to advisory (was counted as a PASS); active congestion-control selection is still asserted via net.ipv4.tcp_congestion_control. No false PASS on a present-but-unloaded module.
- harden: NM_RESTART_DELAY validated as a non-negative integer before sleep; log the assumed USER_HZ=100 when getconf CLK_TCK is unavailable in the stale-lock PID-recycle check. No functional change to the install flow.

7.35.1 - 2026-06-13

- docs: condensed inline comments to vital information; trimmed README and changelog. No functional change.

7.35.0 - 2026-06-13

- feat: pin AMD P-State EPP to performance via /etc/udev/rules.d/61-ry-epp.rules. Managed files 17 to 18. EPP check promoted advisory to enforced.
- fix: nftables ruleset accepts inbound ICMPv6 NDP and PMTUD; prior ruleset dropped all ICMPv6, breaking IPv6 once the NDP cache expired.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off to pcie_aspm.policy=performance (12 params).
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642 (8 values).
- deps: cmp is now a hard preflight dependency (byte-exact mkinitcpio.conf revert gate).
- net: _is_wifi_active_route adds a policy-routing table fallback for the Wi-Fi NM-restart deferral.

7.28.0 - 2026-06-12

- kdeconnect removed; mkinitcpio-firmware added; AUR dropped (pacman-only).
- firewall: inbound reduced to established/related, loopback, ICMPv4. Boot-taint gate made unconditional.

7.24.0 - 2026-06-08

- security: nftables default-deny-inbound ships, ufw masked; resolved DNSOverTLS and MulticastDNS set to no.
- cmdline: amd_iommu=off to iommu=pt, drop preempt=full; cpupower governor to powersave.

7.12.0 - 2026-05-29

- feat: NVMe scheduler none, ddcutil, --country=XX regdom, unified --verify, ttm GTT sizing.
- cmdline: ppfeaturemask to 0xffff7fff.
- harden: systemd >= 250 gate, stale-lock reclaim, auto .ry.bak backups.

Earlier releases: see git history.
