ry-install changelog - newest first.

7.28.0 - 2026-06-12

- packages: mkinitcpio-firmware moved from the AUR set into PKGS_ADD (15 -> 16) — installed from the CachyOS repository in the same pacman -Syu transaction, gaining the package-verify and boot-taint gates the AUR path never had.
- packages: AUR support removed end-to-end — no paru invocation, no AUR install phase, no paru/version preflight, no per-package AUR retry; the script is pacman-only.
- verify: AUR package check dropped from static verification (mkinitcpio-firmware is now covered by the PKGS_ADD check).
- cleanup: state that existed only to gate the AUR phase removed (_RY_SYU_FAILED, _RY_AUR_PARTIAL, _RY_IAP_RETRY_FAILED); paru dropped from the long-running-command timeout bypass list; taint-gate guidance no longer references an advisory phase.
- counts: PKGS_ADD 15 -> 16; AUR_PKGS invariant retired (pinned-count set 22 -> 21); functions 291 -> 287.
- docs: README is pacman-only — requirements row and intro, install-flow intro, Phase 2 row, package table (Install 16; AUR row removed), and Known Issues (paru workarounds replaced with unmanaged out-of-tree notes; AUR PGP row removed).

7.27.1 - 2026-06-12

- header: script banner comment synced to the release version and date (still read v7.26.10 / 2026-06-11 since the 7.26.10 cut; the VERSION constant, README, and changelog were already current).
- progress: pinned bar now requires ≥ 64 terminal columns at init (longest rendered row is 63 columns: 40-char bar + brackets + percent + "Aborted (NNNNs)"); narrower terminals fall back to plain step logging — previously the bottom-row printf wrapped and corrupted the scroll region.
- progress: the WINCH handler applies the same ≥ 64-column floor on resize, tearing the bar down exactly as a < 10-row resize does.
- cleanup: TMPDIR sweep matches ownership by numeric UID (`find -uid`) instead of `-user`, removing the name-before-UID lookup ambiguity for all-digit usernames; identical files matched on every standard system (GNU findutils already a hard requirement).
- docs: three within-cell README table trims (kernel-cmdline iommu rationale now changelog-only, instance-lock mechanics condensed with behavior intact, enabled-units internal derived-batch clause dropped); all tables, rows, alerts, commands, counts, and operational semantics unchanged.

7.27.0 - 2026-06-12

- cmdline: amd_iommu=off -> iommu=pt — DMA remapping restored in passthrough mode; USB4/boltd device authorization becomes meaningful (KERNEL_PARAMS count unchanged at 12; live /proc/cmdline reads as drift until the post-deploy reboot).
- verify: nftables.service judged by live ruleset (inet/filter/input with policy drop) when not active — the Arch unit is Type=oneshot without RemainAfterExit, so is-active reads inactive after a clean boot-time load (false FAIL fixed; disabled unit still warns, missing ruleset still fails).
- check: the silent probe applies the same oneshot semantics — an inactive nftables.service with a live default-deny ruleset no longer reads as permanent drift (rc 10) on a healthy system; missing ruleset or nft(8) still drifts.
- install: firewall-handoff message no longer claims the unit is active after enable --now; evidence reworded to the probed reality (rc=0, oneshot semantics).
- install-file: the nftables post-hook restarts the service after a clean nft -c instead of the old reload-if-active path, which was dead code twice over (the unit is never active and ships no ExecReload) — a re-deployed /etc/nftables.conf now applies live.
- services: avahi-daemon.{service,socket} unmasked (MASK 11->9); firewall opens mDNS 5353/udp + KDE Connect 1714-1764 (tcp+udp) for KDE Connect discovery (resolved MulticastDNS=no unchanged — avahi owns 5353).
- config: /etc/conf.d/wireless-regdom managed (WIRELESS_REGDOM="$COUNTRY"; silences the wireless-regdb set-wireless-regdom error; counts: files 16->17, SYSTEM_DESTINATIONS 15->16, post-hook patterns 16->17; pacman-owned — wireless-regdb .pacnew auto-resolved by the managed-destination pacnew scan).

7.26.10 - 2026-06-11

- color: NO_COLOR now requires a non-empty value per no-color.org; NO_COLOR="" no longer suppresses color; help text corrected from "any value" to "non-empty value".
- log: _json_str returns 0 unconditionally (string collect --allow-empty reads empty input as rc 1; callers consume stdout, never rc).
- log: _run stream capture caps each captured line at 2000 chars (line-count cap alone let one long line bloat the JSONL event; run-overflow spill keeps full bytes; blank lines preserved).
- lock: redundant _pre_dispatch_log_cleanup calls removed from the pidfile-write and pidfile-install failure paths (the caller's _pre_dispatch_exit performs the same cleanup; the mkdir-fail path was already bare).
- lock: stale-PID reclaim comments the kill(1)-absent fallback (rc 127 falls through to the /proc-presence branch, fail-closed).
- style: _enum_boot_entries/_irb_verify_entries argument renamed esp -> boot (receives the XBOOTLDR-aware $BOOT path); BOOT_ENUM_FAIL log key now reads boot=.
- docs: README safety warning notes the invalid-state drop preceding the ICMP accept; seven within-line text trims (lock cell, fstab whitespace note, cpupower/regdom cells, Phase-2 pacnew note, boot-time near-miss wording, uninstall step 2); all tables, rows, alerts, commands, and operational semantics unchanged; behavior, generated bytes, and all pinned counts unchanged except as listed above.

7.26.9 - 2026-06-11

- docs: six README prose paragraphs tightened (requirements intro, usage notes, install-flow intro, package-defaults note, configuration intro, logs note); all tables, alerts, commands, and operational semantics unchanged; script unchanged except the version constant.

7.26.8 - 2026-06-11

- style: the three remaining multi-line comment blocks (section banner + annotation for ENV_VARS, PKGS_ADD, MASK) folded into single 100-char banner lines; comments are now single-line everywhere outside the two-line script header; behavior, generated bytes, and all pinned counts unchanged.
- docs: changelog version headings flattened to plain text for uniform rendering; README carries the version bump only.

7.26.7 - 2026-06-11

- verify: _chk_grep escalates to a sudo read for perms-drifted system files; previously only /boot escalated, so a root-only-readable /etc managed file failed every key check with PERMISSION DENIED while the checksum pass already read the same file via sudo.
- install: the fstab-opts summary row reports SKIP when /etc/fstab is absent and -- (N/A) when it contains no ext4 entries; both previously rendered PASS with explanatory evidence only.

7.26.6 - 2026-06-11

- preflight: network probe uses an HTTPS GET instead of HEAD; hosts that reject HEAD no longer read as offline.
- preflight: NTP repair gains a single-client guard — systemd-timesyncd auto-enable is skipped (WARN + TIME_SYNC_CONFLICT) when chronyd.service or ntpd.service is enabled or active.
- verify: directory write-bit check fails closed — unparseable stat modes now flag the directory, the special-bits digit is dropped by keeping the last three digits, and short modes are zero-padded (a 066 directory previously read as not group/world-writable because stat -c %a prints it as 66).
- verify: ENV_VARS runtime compare strips one matched surrounding quote pair instead of all leading and trailing quote characters; values ending in a quote are preserved.
- install-file: NM post-hook skip message states that all drop-in keys defer when the iwd package is absent (restart behavior unchanged — restarting with wifi.backend=iwd and no iwd would unmanage Wi-Fi immediately).
- help: RY_INSTALL_FORCE_BOOT_REBUILD line states the override never bypasses a failed mkinitcpio revert.
- docs: usage table documents per-mode verbosity and the -- end-of-options terminator; install-flow table notes the NTP-repair guard, the revert-gate exception, and the cache-trim skip condition; env-var table mirrors the revert-gate exception.

7.26.5 - 2026-06-11

- structure: 16 section banners added for navigation and troubleshooting — header constants, help text, early -h/-v intercept, bail primitives, five embedded-data groups, three Phase-4 sub-sections (PKGS_DEL removal, mask + firewall handoff, enable + regdom), run-summary matrix renderer, non-boot post-hooks, and two main-block stages.
- structure: bail primitives (_ry_exit + handler erase) no longer file under the PATH HARDENING banner.
- style: every section banner now carries exactly one preceding blank line; 100-char banner width unchanged; behavior, generated bytes, and all pinned counts unchanged.

7.26.4 - 2026-06-11

- check: timer and service units share one active+enabled gate (duplicate branch merged).
- verify: GPU performance-level sysfs scan folded into _vrk_gpu_state; representative-core cpufreq probe inlined into the CPU check.
- style: blank-line policy — one blank line before each section banner, none elsewhere (5303 -> 5036 lines; behavior, generated bytes, and all pinned counts unchanged).

7.26.0..7.26.3 - 2026-06-10..2026-06-11

- modprobe: ttm pages_limit and page_pool_size 25165824 -> 8388608 (GTT ~32 GiB).
- nftables: ICMPv6 accept via meta l4proto (ip6 nexthdr missed extension headers).
- packages: a mkinitcpio.conf pre-deploy failure arms the -Syu-failed gate; a failed or rolled-back -Syu skips AUR (no dep-sync against a stale db).
- lock: recycled-PID reclaim via /proc starttime vs pidfile mtime; unprovable stays fail-closed; --verify/--check run lock-free.
- verify: runtime unit batch derived from EXPECTED_SERVICES + conf.d-implied units; sudo fallbacks for perms-drifted reads; pacman query failures report unavailable, not missing.
- install-file: /etc/kernel/cmdline post-hook regenerates sdboot entries without mkinitcpio -P (13 handlers / 16 patterns); the --install-file value is exempt from early -h/-v interception.
- preflight: GNU find -printf gated; environment.d and cpupower-service.conf validators; hardware-override warnings force-print in quiet installs (--check stays silent).
- boot: loader-entry kernel probe rejects ../ traversal and survives a missing realpath; revert logs when cmp(1) is absent.
- progress: pinned-bar writes stop after SIGPIPE; db.lck probe precedes the upgrade banner.

7.25.0..7.25.7 - 2026-06-09..2026-06-10

- services: nftables activates before the ufw flush; MulticastDNS -> no (default-deny inbound drops its replies).
- cleanup: children reaped before revert; failed revert preserves the /run snapshot; post-revert .pacnew left for pacdiff.
- fstab: rewrite splices the options field with whitespace preserved; final atomic mv through _run.
- udev: post-hook gates reload behind udevadm verify on systemd >= 254.
- cpupower: governor performance -> powersave (EPP unpinned, advisory).
- cmdline: drop preempt=full (kernel default; 13 -> 12).
- harden: mv -T probed at bootstrap; PATH hardening drops empty/relative entries; sourced invocation returns 1.

7.24.0..7.24.7 - 2026-06-08..2026-06-09

- security: nftables default-deny-inbound ships; ufw masked (counts 14->15/3->4/15->16/16->17).
- resolved: DNSOverTLS opportunistic -> no.
- fix: dedicated nftables.conf validator; non-vfat /boot fallback refuses the boot cascade.

7.17.0..7.23.2 - 2026-05-30..2026-06-08

- cmdline: ppfeaturemask 0xfff73fff -> 0xffff7fff; iommu=pt -> amd_iommu=off; drop max_cstate, cwsr_enable, sg_display.
- sysctl: drop vm.max_map_count + compaction_proactiveness (CachyOS-set; 8 -> 6); --verify reports them advisory.
- feat: NVMe scheduler none; ddcutil; --country=XX regdom; --verify replaces --verify-static/--verify-runtime.
- harden: systemd >= 250 gate; _run overflow-spill; 3x stale-lock reclaim; CPU gate every mode; preflight-abort renders PREFLIGHT (3).
- pkgs: drop iw, rtkit; add cachy-update to removals; AUR reduced to mkinitcpio-firmware.

7.12.0..7.16.0 - 2026-05-29..2026-05-30

- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; time-sync preflight.
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE; logind 9 -> 8 keys; mask 12 -> 11 units.

Earlier releases: see git history.
