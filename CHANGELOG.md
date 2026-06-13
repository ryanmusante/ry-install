ry-install changelog - newest first.

7.32.0 - 2026-06-12

- deps: cmp(1) (GNU diffutils) promoted from optional to a hard preflight dependency — it is the sole byte-exact gate for the mkinitcpio.conf revert (a boot-critical file); an absent cmp no longer silently degrades the rollback to a cp-rc-only check.
- net: _is_wifi_active_route falls back to `ip route show default table all` when no default route is in the main table, so policy-routing setups no longer read as non-wireless and skip the Wi-Fi-active NM-restart deferral.
- style: 3 content-generator sub-group dividers + 1 INSTALL SUMMARY section banner added (79 -> 80 section banners); 5035 lines, 287 functions.

7.31.4 - 2026-06-12

- docs: README condensed (duplicate MT7925/ppfeaturemask links dropped; lead-ins tightened). No code or invariant change from 7.31.3; 5027 lines.

7.31.3 - 2026-06-12

- boot: RY_INSTALL_FORCE_BOOT_REBUILD removed; the boot-taint gate is unconditional. A tainted run always skips the Phase 5 rebuild — fix the cause and re-run. _check_boot_taint_gate reduced to two refusal paths (rc 1 revert-failed, rc 2 tainted).
- style/docs: comments trimmed; 10 sub-banners added (69 -> 79); README synced. Code byte-identical.

7.31.2 - 2026-06-12

- size: banner tails reduced to a fixed two-char tail. No code change.

7.31.1 - 2026-06-12

- docs: README --verify/--check advisory condensed. No code change.

7.31.0 - 2026-06-12

- kdeconnect: removed instead of disabled (PKGS_DEL 8 -> 9, rdep-safe -Rns); 7.30.0 disable machinery reverted (managed files 18 -> 17; functions 291 -> 287).

7.30.0 - 2026-06-12

- kdeconnect: disabled via managed autostart override (Hidden=true); deploy hook stops kdeconnectd; managed files 17 -> 18.

7.29.0 - 2026-06-12

- firewall: inbound reduced to established/related, loopback, ICMPv4 (input chain 7 -> 4); ICMPv6/NDP, mDNS, KDE Connect pairing now blocked.

7.28.0 - 2026-06-12

- packages: mkinitcpio-firmware moved AUR -> PKGS_ADD (15 -> 16); AUR support removed end-to-end, script is pacman-only; functions 291 -> 287.

7.27.x - 2026-06-11..2026-06-12

- cmdline: amd_iommu=off -> iommu=pt (passthrough DMA restored; 12 params).
- verify/check/install-file: nftables judged by live ruleset (Type=oneshot reads inactive after clean load); post-hook restarts after nft -c.
- services: avahi unmasked (MASK 11 -> 9). config: wireless-regdom managed (files 16 -> 17).
- progress: pinned bar requires >= 64 cols, else plain logging. cleanup: TMPDIR sweep by numeric UID.

7.26.x - 2026-06-10..2026-06-11

- modprobe: ttm pages_limit/page_pool_size -> 8388608 (GTT ~32 GiB).
- lock: recycled-PID reclaim via /proc starttime vs pidfile mtime; --verify/--check lock-free; fail-closed on kill(1) absent.
- preflight: HTTPS GET network probe; single-client NTP guard. verify: closed-fail on unparseable modes; ENV_VARS strips one quote pair.
- nftables: ICMPv6 via meta l4proto. boot: loader-entry probe rejects ../ traversal, survives missing realpath.
- style: single-line comments everywhere; section banners added; blank-line policy normalized.

7.24.x..7.25.x - 2026-06-08..2026-06-10

- security: nftables default-deny-inbound ships; ufw masked. resolved: DNSOverTLS/MulticastDNS -> no.
- services: nftables activates before ufw flush. cpupower: governor -> powersave (EPP unpinned).
- fstab: option-field splice preserves whitespace; atomic mv. cmdline: drop preempt=full (13 -> 12).
- harden: mv -T probed at bootstrap; sourced invocation returns 1. fix: non-vfat /boot refuses boot cascade.

7.17.x..7.23.x - 2026-05-30..2026-06-08

- cmdline: ppfeaturemask -> 0xffff7fff; drop max_cstate, cwsr_enable, sg_display.
- sysctl: drop vm.max_map_count + compaction_proactiveness (8 -> 6; reported advisory).
- feat: NVMe scheduler none; ddcutil; --country=XX regdom; unified --verify.
- harden: systemd >= 250 gate; 3x stale-lock reclaim; CPU gate every mode; preflight-abort renders PREFLIGHT (3).

7.12.x..7.16.x - 2026-05-29..2026-05-30

- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; time-sync preflight.
- env: PROTON_FSR4_RDNA3_UPGRADE; logind 9 -> 8 keys; mask 12 -> 11 units.

Earlier releases: see git history.
