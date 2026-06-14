ry-install changelog - newest first.

7.39.0 - 2026-06-13

- merge /etc/udev/rules.d/60-ry-ioschedulers.rules and /etc/udev/rules.d/61-ry-epp.rules into a single /etc/udev/rules.d/60-ry-perf.rules (NVMe scheduler=none + AMD P-State EPP=performance); managed files 18 to 17. The _content/_vss_udev pair now emits and verifies both directives from one file; _vss_epp folded into _vss_udev. _RY_POST_HOOKS unchanged (the /etc/udev/rules.d/* glob already mapped to one udev tag). No change to deployed rule semantics — same scheduler and EPP assignments, one fewer file.

7.38.6 - 2026-06-13

- BOOT_TIME_TARGET 15 to 20 s: --verify now warns only when systemd-analyze boot time exceeds 20 s (near-miss WARN band stays at >=90% of target, i.e. >=18 s). Verify-only threshold; no install behavior change.

7.38.5 - 2026-06-13

- rename _mkinitcpio_revert helper _mr_copy_size_verify to _mr_copy_cmp_verify: the body is cp + cmp byte-exact (no size comparison); the name now matches its description and the README "byte-exact revert" wording.
- comment _far_build_awk_script: rewriting an existing commit= drops it in place and re-appends commit=10 at the tail, so ext4 option order is not preserved (the kernel is order-insensitive); 1-in-1-out and idempotency are unchanged.
- no functional change to install, verify, check, or install-file behavior; script logic byte-identical to 7.38.4 aside from the rename.

7.38.4 - 2026-06-13

- README: correct the atomic-write order in the Safety table to "same-FS tmp → render" (the tmpfile is created before content is rendered into it); matches _atomic_write_file. Doc-only.
- version bump only; install, verify, check, and install-file behavior byte-identical to 7.38.3.

7.38.3 - 2026-06-13

- README rewritten in GitHub-flavored Markdown; tighten wording, no logic change.
- version bump only; install, verify, check, and install-file behavior byte-identical to 7.38.2.

7.38.2 - 2026-06-13

- condense README to vital information only: fold the Run Summary section into Install Flow and collapse duplicated atomic-write prose; configuration tables retained verbatim.
- no functional change to install, verify, check, or install-file behavior; script logic byte-identical to 7.38.1.

7.38.1 - 2026-06-13

- collapse the remaining multiline header comment to a single line; trim verbose changelog entries to one line each.
- no functional change to install, verify, check, or install-file behavior.

7.38.0 - 2026-06-13

- --verify asserts the nftables ICMPv6 NDP/PMTUD accept rule statically (greps nd-neighbor-solicit) and against the live input chain, independent of unit state.
- fstab rewrite adds a line-count parity gate (awk is 1-in-1-out) ahead of the size-sanity floor and findmnt --verify.

7.37.0 - 2026-06-13

- cpupower-service GOVERNOR powersave to performance; EPP stays pinned performance via 61-ry-epp.rules under amd_pstate=active.

7.36.1 - 2026-06-13

- PID-recycle starttime math recovers USER_HZ from CONFIG_HZ (/proc/config.gz) before falling back to 100, preventing false lock-reclaim on CONFIG_HZ!=100 kernels.
- nft and iw runtime/verify probes run under LC_ALL=C for locale-stable ruleset and regdom checks.

7.36.0 - 2026-06-13

- package-verify refuses when the pacman binary is unavailable after the upgrade; the run is tainted so the Phase 5 rebuild is skipped.
- collapse multiline header comments to single lines; flatten changelog styling.

7.35.2 - 2026-06-13

- tcp_bbr module-version line demoted to advisory; selection stays asserted via net.ipv4.tcp_congestion_control.
- validate NM_RESTART_DELAY as a non-negative integer before sleep; log assumed USER_HZ=100 when getconf CLK_TCK is unavailable.

7.35.1 - 2026-06-13

- condense inline comments to vital information; trim README and changelog.

7.35.0 - 2026-06-13

- pin AMD P-State EPP to performance via /etc/udev/rules.d/61-ry-epp.rules; managed files 17 to 18; EPP check enforced.
- nftables ruleset accepts inbound ICMPv6 NDP and PMTUD; prior ruleset dropped all ICMPv6.

7.34.0 - 2026-06-12

- cmdline: pcie_aspm=off to pcie_aspm.policy=performance (12 params).
- sysctl: add vm.compaction_proactiveness=0, vm.max_map_count=2147483642 (8 values).
- cmp is now a hard preflight dependency for the byte-exact mkinitcpio.conf revert gate.
- _is_wifi_active_route adds a policy-routing table fallback for the Wi-Fi NM-restart deferral.

7.28.0 - 2026-06-12

- kdeconnect removed; mkinitcpio-firmware added; AUR dropped (pacman-only).
- firewall inbound reduced to established/related, loopback, ICMPv4; boot-taint gate made unconditional.

Earlier releases: see git history.
