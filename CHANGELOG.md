ry-install changelog - newest first.

7.25.7 - 2026-06-10
- fstab: final atomic mv runs through _run (stderr captured, JSONL-logged).
- udev: post-hook gates reload behind udevadm verify on systemd >= 254.
- files: pin umask 0022 around sudo mkdir -p (intermediate dir modes).
- verify: drop stray --entire flag from nine string-match validators.
- cleanup: skip the child SIGKILL pass once the grace loop sees zero children.
- preflight: cmp(1) joins the optional-tool warning list (revert byte-verify).
- verify: shared vfat skip probe; parent-dir check under the 50-line cap.
- style: trim verbose comments; drop a redundant guard and two no-op chains.

7.25.6 - 2026-06-10
- resolved: MulticastDNS resolve -> no (default-deny inbound drops mDNS replies).
- preflight: probe mv -T capability with the other coreutils gates.
- preflight: PATH hardening drops empty/relative inherited entries.
- install-file: drop unreachable /efi/* post-hook pattern (17->16).
- sysctl: generator key charset pinned to [A-Za-z0-9._-].
- log: _err_loud bumps the footer fail counter.
- cli: --help notes --check kernel-param drift reads rc=10 until reboot.

7.25.0..7.25.5 - 2026-06-09..2026-06-10
- services: nftables activates before the ufw flush (no unfirewalled window).
- packages: failed or db-locked -Syu skips AUR; post-revert .pacnew left for pacdiff.
- cleanup: children reaped before revert; failed revert preserves the /run snapshot.
- lock: unsignalable live peer never reclaimed; settle + re-read before reclaim; failures log holder PID.
- verify: nftables unit in the runtime batch (5->6); multi-line HOOKS tolerated; vfat parent-dir parity; NM backend probe distinguishes sudo lapse.
- log: failed rename keeps the old path; _json_str preserves trailing newlines.
- fstab: rewrite splices the options field, original whitespace preserved.
- guard: sourced invocation returns 1; progress teardown safe pre-load.
- cpupower: governor performance -> powersave (EPP unpinned, advisory).
- cmdline: drop preempt=full (kernel default; 13->12).

7.24.0..7.24.7 - 2026-06-08..2026-06-09
- security: nftables default-deny-inbound ships; ufw masked (counts 14->15/3->4/15->16/16->17).
- modprobe: ttm pages_limit and page_pool_size -> 25165824 (equal; preflight asserts).
- resolved: DNSOverTLS opportunistic -> no.
- fix: dedicated nftables.conf validator; wifi-route 'br*' glob; non-vfat /boot ESP fallback refuses the boot cascade.
- check: stderr-silent on post-parse anomalies; lock pidfile failures emit JSONL tags.
- progress: WINCH below 10 rows tears the pinned bar down.
- build: archive ships ry-install.fish mode 0755.

7.22.0..7.23.2 - 2026-06-06..2026-06-08
- cmdline: ppfeaturemask 0xfff73fff -> 0xffff7fff (GFXOFF off, overdrive un-gated).
- sysctl: drop vm.max_map_count + compaction_proactiveness (CachyOS-set; 8->6); verify reports them advisory.
- services: enable NM when preset leaves it disabled; dispatcher static accepted; regdom row in the matrix.
- preflight: gate remaining coreutils + kill; count-guard ISO-3166 (249); widen KERNEL_PARAMS metachar reject; ttm pool==limit assert.
- cli: glued -h/-v/-V clusters honored pre-root-guard; positionals listed; 250/255 sentinels named.
- fix: realtime/i2c group hint for existing members; failed-run banner reads ERRORS.
- aur: pacman -T post-verify (paru rc=0 but missing -> WARN).
- harden: TMPDIR glob sweep centralized; user config dir keeps ambient umask.

7.20.0..7.21.9 - 2026-06-04..2026-06-06
- verify: static FAIL outranks runtime preflight bail; malformed LINUX_OPTIONS -> FAIL.
- preflight: invariants run before lock; stateful backup-target generators refused; destination counts pinned.
- install-file: post-hook resolves the matched managed dst; only cmdline needs root UUID.
- lock: corrupt pidfile reclaimed; fstab snapshots to .ry.bak pre-rewrite.
- harden: SIGPIPE skips stderr; timeout bypass matches basename; sudo-rm roots derived from managed parents.
- pkgs: lib32-mesa out of EXPECTED_VULKAN_PKGS (3->2).
- resolved: DNSOverTLS no -> opportunistic (reverted in 7.24.4).

7.19.0..7.19.25 - 2026-06-02..2026-06-04
- fix: preflight-abort renders PREFLIGHT (3); only -Syu/pkg/boot-config taint Phase 5.
- fix: fstab rewrite refuses when findmnt absent.
- harden: validate --country; CPU gate every mode; guard id(1)/PATH.
- verify: combined static+runtime totals; THP/ZRAM/swap advisory.
- install-file: live-apply only on byte change; post-hook rc0 WARN.
- pkgs: drop iw, rtkit (16->14); add cachy-update to removals (7->8).
- files: drop i2c-dev modules-load (16->15); regdom to /etc/iw-regdomain.
- cmdline: ppfeaturemask 0xfff73fff; iommu=pt -> amd_iommu=off.

7.18.0 - 2026-06-01
- remove: kernel-version floor gate.

7.17.0..7.17.29 - 2026-05-30..2026-06-01
- feat: pin NVMe scheduler none (15->16); add ddcutil; --country=XX regdom.
- cli: --verify replaces --verify-static/--verify-runtime.
- cmdline: drop max_cstate, cwsr_enable, sg_display (13 params).
- sysctl: +vm.max_map_count (8); halve ttm page limits.
- harden: systemd >= 250 gate; _run overflow-spill; 3x stale-lock reclaim.
- fix: paru-absent/partial AUR WARN, all-failed FAIL; per-file findmnt skips vfat.
- verify: fix footer double-count; ppfeaturemask derived from KERNEL_PARAMS.

7.16.0 - 2026-05-30
- logind: drop HandleSecureAttentionKey (9->8); mask: drop lvm2-monitor.service (12->11).

7.15.0 - 2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE; sysctl: drop busy_poll/busy_read (9->7).

7.14.0..7.14.3 - 2026-05-29..2026-05-30
- cmdline: ppfeaturemask tuning; AUR reduced to mkinitcpio-firmware (3->1).
- harden: guard optional tools (ip, ping, swapon, zcat).

7.13.0..7.13.5 - 2026-05-29
- aur: install unconditionally; cli: drop RY_INSTALL_* toggles (runtime-vars 6->4).

7.12.0 - 2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; add time-sync preflight.

Earlier releases: see git history.
