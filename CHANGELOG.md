ry-install changelog - newest first.

7.34.3 - 2026-06-13

- hardening: pactree rdep probe gains timeout --kill-after=5 (SIGKILL escalation; parity with _run). No success-path change.
- logging: udev post-hook logs UDEV_VERIFY_SKIP when systemd < 254 (udevadm verify absent; rule still reloads). No functional change.

7.34.2 - 2026-06-13

- docs: one-line lead-in before each README Safety & Reliability table. No functional change.

7.34.1 - 2026-06-13

- docs: README firewall note lists the ct-state-invalid drop; dropped stale PRESERVE_FOREIGN mention. No functional change.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off -> pcie_aspm.policy=performance (12 params).

7.33.0 - 2026-06-12

- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642 (SYSCTL_VALUES 6 -> 8); advisory vm reporter removed.

7.32.0 - 2026-06-12

- deps: cmp(1) is now a hard preflight dependency (byte-exact mkinitcpio.conf revert gate).
- net: _is_wifi_active_route adds a policy-routing table fallback for the Wi-Fi NM-restart deferral.

7.28.0..7.31.4 - 2026-06-12

- kdeconnect removed; mkinitcpio-firmware -> PKGS_ADD; AUR dropped (pacman-only).
- firewall: inbound reduced to established/related, loopback, ICMPv4. boot-taint gate made unconditional.

7.24.x..7.27.x - 2026-06-08..2026-06-12

- security: nftables default-deny-inbound ships, ufw masked; resolved DNSOverTLS/MulticastDNS -> no.
- cmdline: amd_iommu=off -> iommu=pt, drop preempt=full; cpupower governor -> powersave.

7.12.x..7.23.x - 2026-05-29..2026-06-08

- feat: NVMe scheduler none, ddcutil, --country=XX regdom, unified --verify, ttm GTT sizing.
- cmdline: ppfeaturemask -> 0xffff7fff. harden: systemd >= 250 gate, stale-lock reclaim, auto .ry.bak backups.

Earlier releases: see git history.
