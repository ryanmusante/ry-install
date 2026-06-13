ry-install changelog - newest first.

7.34.2 - 2026-06-13

- docs: added a one-line lead-in before each table in the README Safety & Reliability section (atomic writes, exit codes, environment variables). No functional change.

7.34.1 - 2026-06-13

- docs: README firewall description now lists the ct-state-invalid drop rule (ruleset already shipped it).
- docs: removed PRESERVE_FOREIGN reference from the sdboot REMOVE_EXISTING note (never a script-emitted key). No functional change.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off -> pcie_aspm.policy=performance (restored performance ASPM policy; 12 params).

7.33.0 - 2026-06-12

- sysctl: add vm.compaction_proactiveness=0 and vm.max_map_count=2147483642 (SYSCTL_VALUES 6 -> 8, enforced); advisory vm reporter removed (functions 287 -> 286).

7.32.0 - 2026-06-12

- deps: cmp(1) promoted to a hard preflight dependency (sole byte-exact gate for the mkinitcpio.conf revert).
- net: _is_wifi_active_route falls back to a policy-routing table lookup for the Wi-Fi-active NM-restart deferral.

7.28.0..7.31.4 - 2026-06-12

- kdeconnect removed (rdep-safe); mkinitcpio-firmware moved to PKGS_ADD, AUR support dropped (pacman-only).
- firewall: inbound reduced to established/related, loopback, ICMPv4. boot: boot-taint gate made unconditional.

7.24.x..7.27.x - 2026-06-08..2026-06-12

- security: nftables default-deny-inbound ships, ufw masked; resolved DNSOverTLS/MulticastDNS -> no.
- cmdline: amd_iommu=off -> iommu=pt, drop preempt=full. cpupower governor -> powersave.

7.12.x..7.23.x - 2026-05-29..2026-06-08

- feat: NVMe scheduler none, ddcutil, --country=XX regdom, unified --verify, ttm GTT sizing.
- cmdline: ppfeaturemask -> 0xffff7fff. harden: systemd >= 250 gate, stale-lock reclaim, auto .ry.bak backups.

Earlier releases: see git history.
