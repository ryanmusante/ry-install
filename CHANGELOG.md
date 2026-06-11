ry-install changelog - newest first.

# 7.26.3 - 2026-06-11

- packages: a mkinitcpio.conf pre-deploy failure now arms the -Syu-failed gate — the AUR phase no longer dep-syncs against a never-upgraded db.
- nftables: ICMPv6 accept switched to meta l4proto (ip6 nexthdr missed ICMPv6 behind extension headers); managed file redeploys on the next run.
- preflight: hardware-override warnings force-print to stderr in quiet installs via _warn_loud (--check stays silent).
- boot: mkinitcpio revert logs MKINITCPIO_REVERT_CMP_SKIP when cmp(1) is absent instead of skipping byte-verify silently.
- finalize: conditional manual-step hints numbered by counter (no gap when a group hint is skipped).
- style: _installed_bytes string collect gains --allow-empty (parity with callers; no behavior change).
- docs: Finalize row documents the pacman -Sc fallback when paccache is absent.

# 7.26.2 - 2026-06-11

- lock: live-PID reclaim detects recycled PIDs (proc starttime vs pidfile mtime); unprovable stays fail-closed.
- cli: the --install-file value is exempt from early -h/-v interception; argparse validates it (exit 2).
- verify: dead ActiveState 'exited' arms removed (SubState value; cpupower and --check gate on active).
- preflight: environment.d and cpupower-service.conf gain content validators.
- progress: pinned-bar writes stop after SIGPIPE.
- packages: db.lck probe precedes the unattended-upgrade banner.
- style: switch arguments quoted; _ry_exit validates numeric codes; _iap_per_pkg_retry returns 0 explicitly.

# 7.26.1 - 2026-06-11

- lock: stale-claim log only on the numeric-PID path; corrupt pidfile logs one LOCK_PIDFILE_CORRUPT line.
- boot-sanity: warn once when realpath is absent and entry canonicalization falls back to a textual join.
- docs: --verify/--check run lock-free; a concurrent install reads as transient drift.
- style: sudo mkdir umask-union semantics documented.

# 7.26.0 - 2026-06-10

- modprobe: ttm pages_limit and page_pool_size 25165824 -> 8388608 (GTT ~32 GiB).
- verify: runtime unit batch derived from EXPECTED_SERVICES + conf.d-implied units; per-unit dispatch replaces the pinned list.
- verify: sdboot-manage.conf, mkinitcpio arrays, and live-HOOKS reads gain a sudo fallback (perms drift reads unreadable, not missing).
- verify: pacman query failures report query-unavailable instead of false NOT-INSTALLED.
- verify: sudo lapse mid perms/parent-dir loop warns once and stops; blacklist scan warns when lsmod is absent.
- install-file: /etc/kernel/cmdline post-hook regenerates sdboot entries without mkinitcpio -P (13 handlers / 16 patterns).
- boot-sanity: loader-entry kernel probe rejects ../ traversal and survives a missing realpath.
- preflight: GNU find -printf probed with the coreutils gates.
- run: value-taking sudo flags skipped when resolving the timeout-bypass command.
- cli: MODE pinned pre-argparse; --check bootstrap errors print to stderr; -- accepts no positionals.
- style: lock logging unguarded post-bootstrap; fstab backup exclusion documented.

# 7.25.0..7.25.7 - 2026-06-09..2026-06-10

- services: nftables activates before the ufw flush (no unfirewalled window).
- resolved: MulticastDNS -> no (default-deny inbound drops mDNS replies).
- packages: failed or db-locked -Syu skips AUR; post-revert .pacnew left for pacdiff.
- cleanup: children reaped before revert; failed revert preserves the /run snapshot; SIGKILL pass skipped at zero children.
- lock: unsignalable live peer never reclaimed; settle + re-read before reclaim; failures log the holder PID.
- fstab: rewrite splices the options field, whitespace preserved; final atomic mv through _run.
- files: umask 0022 pinned around sudo mkdir -p (intermediate dir modes).
- udev: post-hook gates reload behind udevadm verify on systemd >= 254.
- preflight: mv -T probed with the coreutils gates; PATH hardening drops empty/relative entries; cmp optional.
- verify: nftables in the runtime batch; multi-line HOOKS tolerated; shared vfat skip; NM probe flags sudo lapse.
- log: failed rename keeps the old path; _json_str preserves trailing newlines; _err_loud bumps the fail counter.
- guard: sourced invocation returns 1; sysctl generator key charset pinned.
- cpupower: governor performance -> powersave (EPP unpinned, advisory).
- cmdline: drop preempt=full (kernel default; 13 -> 12).

# 7.24.0..7.24.7 - 2026-06-08..2026-06-09

- security: nftables default-deny-inbound ships; ufw masked (counts 14->15/3->4/15->16/16->17).
- modprobe: ttm pages_limit and page_pool_size -> 25165824 (equal; preflight asserts).
- resolved: DNSOverTLS opportunistic -> no.
- fix: dedicated nftables.conf validator; wifi-route br* glob; non-vfat /boot fallback refuses the boot cascade.
- check: stderr-silent on post-parse anomalies; lock pidfile failures emit JSONL tags.

# 7.20.0..7.23.2 - 2026-06-04..2026-06-08

- cmdline: ppfeaturemask 0xfff73fff -> 0xffff7fff (GFXOFF off, overdrive un-gated).
- sysctl: drop vm.max_map_count + compaction_proactiveness (CachyOS-set; 8 -> 6); verify reports them advisory.
- services: enable NM when preset leaves it disabled; dispatcher static accepted; regdom row in the matrix.
- preflight: invariants before lock; stateful backup-target generators refused; coreutils + kill gated; ISO-3166 count 249; KERNEL_PARAMS metachar reject widened.
- cli: glued -h/-v/-V honored pre-root-guard; 250/255 sentinels named.
- verify: static FAIL outranks runtime preflight bail; malformed LINUX_OPTIONS -> FAIL.
- aur: pacman -T post-verify (paru rc=0 but missing -> WARN).
- pkgs: lib32-mesa out of EXPECTED_VULKAN_PKGS (3 -> 2).
- harden: SIGPIPE skips stderr; timeout bypass matches basename; TMPDIR sweep centralized; sudo-rm roots from managed parents.

# 7.17.0..7.19.25 - 2026-05-30..2026-06-04

- feat: NVMe scheduler none; ddcutil; --country=XX regdom; --verify replaces --verify-static/--verify-runtime.
- fix: preflight-abort renders PREFLIGHT (3); only -Syu/pkg/boot-config taint Phase 5; fstab rewrite refuses without findmnt.
- harden: systemd >= 250 gate; _run overflow-spill; 3x stale-lock reclaim; --country validated; CPU gate every mode.
- pkgs: drop iw, rtkit; add cachy-update to removals; AUR reduced to mkinitcpio-firmware.
- cmdline: iommu=pt -> amd_iommu=off; drop max_cstate, cwsr_enable, sg_display.
- remove: kernel-version floor gate (7.18.0).

# 7.12.0..7.16.0 - 2026-05-29..2026-05-30

- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; time-sync preflight.
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE; sysctl busy_poll/busy_read dropped.
- logind: drop HandleSecureAttentionKey (9 -> 8); mask: drop lvm2-monitor.service (12 -> 11).
- aur: install unconditionally; guard optional tools (ip, ping, swapon, zcat).

Earlier releases: see git history.
