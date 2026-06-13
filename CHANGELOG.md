ry-install changelog - newest first.

7.31.4 - 2026-06-12

- audit: full line-by-line re-audit (execution flow, streams, scope, syntax, structure, install phases, --verify/--check, 17 embedded files + generators, services, arrays, numbers). Verdict PASS, 0 defects; no code-logic change. Four candidate findings from a prior pass were re-verified and retracted: the KERNEL_PARAMS metachar class keeps its doubled backslash (fish single-quote + PCRE require it to reject a literal backslash); the iw-regdomain (unquoted) vs wireless-regdom (quoted) COUNTRY formats are enforced by their own validators to match each consumer; the nftables ICMPv6/NDP/IPv6 inbound block and the post-hook first-match table are both intentional and already documented.
- docs: README condensed — duplicate MT7925 and ppfeaturemask reference links dropped (both already cited inline in Known Issues / Kernel cmdline); --verify/--check, Run Summary, Install Flow, and Configuration lead-ins tightened. All 16 tables and every fact retained; 236 -> 234 lines.
- no code or invariant change from 7.31.3 apart from version strings; 5027 lines.

7.31.3 - 2026-06-12

- boot: RY_INSTALL_FORCE_BOOT_REBUILD removed; the boot-taint gate is now unconditional. A run tainted by a failed pacman -Syu/package-verify or a boot-critical config write always skips the Phase 5 initramfs rebuild; recovery is to fix the cause and re-run. The taint mechanism (_RY_BOOT_TAINTED) is unchanged.
- boot: _check_boot_taint_gate simplified to two refusal paths, rc 1 (mkinitcpio.conf revert failed) and rc 2 (tainted); the prior forced-warn branch and rc=2 qualifier are dropped. Caller messaging unchanged.
- style: verbose trailing comments trimmed to vital phrasing throughout; script header and lint preserved; code byte-identical (comments only).
- structure: 10 sub-banners added to isolate the orchestrator/dispatch entry points buried in the longest spans (_do_cleanup, _init_runtime, _ry_get_file_content, _run, _chk_grep, the four _verify_runtime_* orchestrators, _install_rebuild_boot); 69 -> 79 banners; code byte-identical (banners + blank lines only); 5027 lines.
- docs: help ENVIRONMENT block, README Phase 5 row, env-var table, and the rebuild-refused troubleshooting row no longer reference the removed variable; README duplicate exit-code mapping and redundant firewall caveats condensed.
- counts unchanged from 7.31.2 apart from version strings and the removed override.

7.31.2 - 2026-06-12

- size: decorative box-drawing tails on all 69 `# ── LABEL ──` banners reduced to a fixed two-char tail. Labels and line count unchanged.
- no code or invariant change from 7.31.1 apart from version strings.

7.31.1 - 2026-06-12

- docs: README --verify/--check state-only advisory condensed to a comma-list; no facts removed.
- no code change from 7.31.0; version strings bumped for release sync.

7.31.0 - 2026-06-12

- kdeconnect: KDE Connect now removed instead of disabled; kdeconnect added to PKGS_DEL (8 -> 9) via the rdep-safe pacman -Rns path. -Rns drops its autostart entry and daemon binary, so no override is needed.
- kdeconnect: the 7.30.0 disable machinery fully reverted (managed files 18 -> 17; USER_DESTINATIONS 2 -> 1; post-hook patterns 18 -> 17; functions 291 -> 287).
- docs: README synced (Remove 9, Managed Files User 1, 17-file deploy phase).

7.30.0 - 2026-06-12

- kdeconnect: KDE Connect disabled via a managed ~/.config/autostart override (Hidden=true); managed files 17 -> 18; USER_DESTINATIONS 1 -> 2; post-hook patterns 17 -> 18.
- kdeconnect: deploy post-hook stops a running kdeconnectd (non-fatal); preflight validator gates [Desktop Entry] + Hidden=true; --verify reports daemon state. D-Bus activation can still start it on demand; inbound pairing stays blocked by the 7.29.0 firewall.
- docs: README synced (service-config row, Managed Files User 2, 18-file deploy phase).

7.29.0 - 2026-06-12

- firewall: inbound allow set reduced to established/related, loopback, and ICMPv4; ipv6-icmp, mDNS (5353/udp), and KDE Connect (1714-1764) accept rules removed (input chain 7 -> 4 rules; policies unchanged).
- firewall: ICMPv6/NDP no longer accepted, disabling inbound IPv6 (NDP and RA/SLAAC are not conntrack-established); inbound mDNS discovery and KDE Connect pairing blocked. Outbound-initiated traffic still returns via established/related.
- docs: README firewall alert synced to the 4-rule ruleset.

7.28.0 - 2026-06-12

- packages: mkinitcpio-firmware moved from AUR into PKGS_ADD (15 -> 16), installed from the CachyOS repo in the same -Syu transaction with package-verify and boot-taint gates.
- packages: AUR support removed end-to-end; the script is pacman-only. AUR-only state (_RY_SYU_FAILED, _RY_AUR_PARTIAL, _RY_IAP_RETRY_FAILED) removed; paru dropped from the timeout-bypass list.
- counts: PKGS_ADD 15 -> 16; AUR_PKGS invariant retired; functions 291 -> 287.
- docs: README is pacman-only (requirements, Phase 2 row, Install 16, Known Issues out-of-tree notes).

7.27.1 - 2026-06-12

- header: script banner synced to release version/date.
- progress: pinned bar requires >= 64 columns at init (longest row is 63); narrower terminals fall back to plain step logging, fixing scroll-region corruption. The WINCH handler applies the same floor on resize.
- cleanup: TMPDIR sweep matches ownership by numeric UID (find -uid), removing all-digit-username ambiguity.
- docs: three README within-cell trims; semantics unchanged.

7.27.0 - 2026-06-12

- cmdline: amd_iommu=off -> iommu=pt; DMA remapping restored in passthrough mode (KERNEL_PARAMS unchanged at 12; reads as drift until reboot).
- verify: nftables.service judged by live ruleset (input policy drop) when not active; the Arch unit is Type=oneshot without RemainAfterExit, so is-active reads inactive after a clean load (false FAIL fixed).
- check: silent probe applies the same oneshot semantics; an inactive service with a live ruleset no longer reads as drift.
- install-file: the nftables post-hook restarts the service after a clean nft -c instead of the old dead reload-if-active path.
- services: avahi-daemon.{service,socket} unmasked (MASK 11 -> 9); firewall opened mDNS 5353/udp + KDE Connect 1714-1764.
- config: /etc/conf.d/wireless-regdom managed (files 16 -> 17, SYSTEM_DESTINATIONS 15 -> 16, post-hook patterns 16 -> 17).

7.26.10 - 2026-06-11

- color: NO_COLOR now requires a non-empty value per no-color.org.
- log: _json_str returns 0 unconditionally; _run stream capture caps each line at 2000 chars (overflow spill keeps full bytes).
- lock: redundant cleanup calls removed from pidfile-write/install failure paths; kill(1)-absent fallback documented (fail-closed via /proc presence).
- style: _enum_boot_entries/_irb_verify_entries argument renamed esp -> boot.
- docs: README safety warning notes the invalid-state drop; seven within-line trims.

7.26.9 - 2026-06-11

- docs: six README prose paragraphs tightened; tables and semantics unchanged; script unchanged except the version constant.

7.26.8 - 2026-06-11

- style: the last three multi-line comment blocks folded into single banner lines; comments are single-line everywhere outside the two-line header.
- docs: changelog headings flattened to plain text.

7.26.7 - 2026-06-11

- verify: _chk_grep escalates to a sudo read for perms-drifted system files; previously only /boot escalated.
- install: the fstab-opts summary reports SKIP when /etc/fstab is absent and -- when it has no ext4 entries.

7.26.6 - 2026-06-11

- preflight: network probe uses HTTPS GET instead of HEAD; HEAD-rejecting hosts no longer read as offline.
- preflight: NTP repair gains a single-client guard; timesyncd auto-enable is skipped when chronyd/ntpd is enabled or active.
- verify: directory write-bit check fails closed on unparseable modes; short modes zero-padded (066 no longer misreads as not group-writable).
- verify: ENV_VARS compare strips one matched quote pair, not all; trailing-quote values preserved.
- docs: usage table documents per-mode verbosity and --; install-flow notes the NTP guard, revert-gate exception, and cache-trim skip.

7.26.5 - 2026-06-11

- structure: 16 section banners added for navigation; bail primitives moved out of the PATH-hardening banner.
- style: one blank line before each banner; counts unchanged.

7.26.4 - 2026-06-11

- check: timer and service units share one active+enabled gate.
- verify: GPU and CPU sysfs probes folded into their check functions.
- style: blank-line policy normalized (5303 -> 5036 lines; counts unchanged).

7.26.0..7.26.3 - 2026-06-10..2026-06-11

- modprobe: ttm pages_limit and page_pool_size 25165824 -> 8388608 (GTT ~32 GiB).
- nftables: ICMPv6 accept via meta l4proto (ip6 nexthdr missed extension headers).
- lock: recycled-PID reclaim via /proc starttime vs pidfile mtime; --verify/--check run lock-free.
- verify: runtime unit batch derived from EXPECTED_SERVICES + conf.d-implied units; pacman query failures report unavailable.
- install-file: /etc/kernel/cmdline post-hook regenerates sdboot entries without mkinitcpio -P.
- boot: loader-entry kernel probe rejects ../ traversal and survives a missing realpath.

7.25.0..7.25.7 - 2026-06-09..2026-06-10

- services: nftables activates before the ufw flush; MulticastDNS -> no.
- cleanup: children reaped before revert; failed revert preserves the /run snapshot.
- fstab: rewrite splices the options field with whitespace preserved; atomic mv through _run.
- udev: post-hook gates reload behind udevadm verify on systemd >= 254.
- cpupower: governor performance -> powersave (EPP unpinned).
- cmdline: drop preempt=full (13 -> 12). harden: mv -T probed at bootstrap; sourced invocation returns 1.

7.24.0..7.24.7 - 2026-06-08..2026-06-09

- security: nftables default-deny-inbound ships; ufw masked (counts 14 -> 15 / 3 -> 4 / 15 -> 16 / 16 -> 17).
- resolved: DNSOverTLS opportunistic -> no.
- fix: dedicated nftables.conf validator; non-vfat /boot fallback refuses the boot cascade.

7.17.0..7.23.2 - 2026-05-30..2026-06-08

- cmdline: ppfeaturemask 0xfff73fff -> 0xffff7fff; iommu=pt -> amd_iommu=off; drop max_cstate, cwsr_enable, sg_display.
- sysctl: drop vm.max_map_count + compaction_proactiveness (8 -> 6); --verify reports them advisory.
- feat: NVMe scheduler none; ddcutil; --country=XX regdom; --verify replaces --verify-static/--verify-runtime.
- harden: systemd >= 250 gate; 3x stale-lock reclaim; CPU gate every mode; preflight-abort renders PREFLIGHT (3).
- pkgs: drop iw, rtkit; add cachy-update to removals; AUR reduced to mkinitcpio-firmware.

7.12.0..7.16.0 - 2026-05-29..2026-05-30

- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; time-sync preflight.
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE; logind 9 -> 8 keys; mask 12 -> 11 units.

Earlier releases: see git history.
