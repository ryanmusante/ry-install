ry-install ChangeLog

Newest first; dates ISO-8601.

7.17.10  2026-05-31
- fix: add ry-tee-err.* to the _do_cleanup filesystem-sweep glob set so a fatal signal during a Phase 3 atomic write cannot leave the tee stderr-capture tmpfile orphaned in TMPDIR for a later run to inherit; the six sibling ry-* prefixes were already swept, and the tracked-list sweep already removed it on the normal path.
- comment: condense three verbose rationale comments (lock-ownership gate, fish-math millisecond scaling, post-hook precedence) to tighter single lines; wording only, no code paths changed.

7.17.9  2026-05-31
- fix: count an installed-bytes string-collect failure in _verify_static_checksum once instead of twice; the explicit VERIFY_FAIL bump now pairs with _fail_no_count, matching the generator-stage branch above it. The doubled tally surfaced only on a near-unreachable collect failure and never altered the pass/fail verdict.
- harden: make the systemd ≥ 250 preflight a true hard gate — refuse the install when systemctl --version is unparseable instead of silently passing, aligning behavior with the documented hard requirement.
- harden: allocate the _run STDERR/STDOUT overflow-spill filename with mktemp --suffix=.log instead of a /dev/urandom-derived suffix, eliminating a possible empty suffix and filename collision when /dev/urandom is unreadable.

7.17.8  2026-05-31
- fix: export HOME via set -gx on the getent-recovery path so paru/makepkg/git children inherit it; the normalization assignment now also exports.
- fix: signal-time lock cleanup removes the lock directory only when held by this process or when its pid file is empty/ours, preventing removal of a peer instance's lock if a fatal signal arrives during a failed mkdir.
- harden: _run timeout-bypass detection skips env and VAR=val tokens after sudo when resolving the effective command.

7.17.7  2026-05-31
- format: split the --INSTALL-FILE banner into DISPATCH TABLE + ORCHESTRATOR and POST-HOOK HANDLERS (11) sections. Banners only — no code paths changed.

7.17.6  2026-05-31
- format: split the VERIFY-STATIC SYSTEM block into SYSTEM+USER / PACKAGES+SERVICES+SYNTAX / CHECKSUM+DRIVER banners. Banners only — no code paths changed.
- comment: collapse the two-line _RY_POST_HOOKS dispatch note into a single line.
- header: sync the file-header version string to VERSION (was 7.17.3).

7.17.5  2026-05-31
- format: split the 530-line VERIFY-RUNTIME banner into SERVICES / ENVIRONMENT / SESSION+PERMS arms, plus a TOP-LEVEL ORCHESTRATORS banner before _ry_verify_runtime/_ry_verify_all. Banners only — no code paths changed.

7.17.4  2026-05-31
- kernel: condense _ry_check_kernel_version to the < 6.14 hard-floor only; drop the advisory 6.18.4 stability WARN, the in-preflight ntsync state probe (still covered by verify static + runtime), and the 6.19.0 black-screen WARN.
- cleanup: remove the now-unused RC_KVER_WARN return code and the unreachable WARN branch in the preflight kernel-version switch.
- docs: README flow line — kernel preflight now reads "≥ 6.14 FAIL"; the 6.18.4 recommendation and 6.19.0 troubleshooting entry are retained as guidance.

7.17.3  2026-05-31
- docs: Prerequisites — paru is recommended (≥ 2.0.0), not a hard preflight gate; AUR phase warns and continues when paru is absent.
- docs: scope the preflight-abort statement to hard requirements; clarify the kernel floor (< 6.14) taints the run (exit 1) rather than aborting (exit 3), and paru/NTP sync are warnings.
- docs: Run Summary — split the per-phase Result legend and the overall Verdict legend into two tables (drop the empty spacer column).
- progress: clamp _PROG_TOTAL to ≥ 1 in _progress_init — defensive guard against divide-by-zero in the bar math.
- comments: note _content_…sysctl records malformed entries to a global consumed at deploy time, and that tmpfiles.d-class post-hooks have no default destination (--install-file only).

7.17.2  2026-05-31
- verify: fix footer double-count when the runtime arm bails at sudo-cache before its counter reset; static totals restored verbatim, exit code unchanged.
- verify: split drirc xmllint check out of _vrs_vulkan into _vrs_drirc_xml.
- verify: firewall nft_rules counts actual rules (handle lines minus block declarations), not chain headers.

7.17.1  2026-05-31
- style: quote always-set test operands ($crit/$warn/$EXIT_BOOT_CRIT, ntsync conf path) for uniformity.

7.17.0  2026-05-30
- cmdline: drop amdgpu.sg_display=0; KERNEL_PARAMS 17 -> 16.
- cli: --verify replaces --verify-static/--verify-runtime — one combined pass (static then runtime), combined exit code + footer.
- mask: systemctl mask --now — stop live svc/socket units at install.
- verify: assert masked units inactive, NM wifi.backend==iwd, drirc + modprobe values, firewall-posture; boot-time WARN + critical-chain diagnostic.
- run: spill full stdout/stderr to LOG_DIR/run-overflow on truncation.
- verify: derive ttm pages_limit/page_pool_size from TTM_* consts; assert drirc XML well-formed via xmllint.
- trim: drop advisory ReBAR/SAM verify telemetry — firmware state, not script-set.

7.16.4  2026-05-30
- docs: tighten Prerequisites sudo-cache warning; all 7 mitigations retained.

7.16.3  2026-05-30
- docs: README collapsible sections all open by default (Destinations, Exit codes, Runtime variables, Logs; the other 20 already open).

7.16.2  2026-05-30
- docs: README Phase 3 heading 'Configuration Files' -> 'Configuration'; anchor updated.

7.16.1  2026-05-30
- docs: README mask count 12 -> 11; matches MASK array (lvm2-monitor dropped in 7.16.0).

7.16.0  2026-05-30
- logind: drop HandleSecureAttentionKey; LOGIND_IGNORE_KEYS 9 -> 8; remove systemd>=257 gate.
- mask: drop lvm2-monitor.service; MASK 12 -> 11.

7.15.0  2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE for the RDNA 3.5 8060S; count 10.
- sysctl: drop net.core.busy_poll, net.core.busy_read; SYSCTL_VALUES 9 -> 7.

7.14.3  2026-05-30
- guard optional-tool calls (ip, ping, swapon/zramctl, zcat); absent tools degrade cleanly.

7.14.2  2026-05-29
- format only: one-element-per-line arrays; banners to 100-col; notation normalized.

7.14.1  2026-05-29
- verify: derive expected ppfeaturemask from KERNEL_PARAMS (fixes spurious 0xfffd7fff FAIL).

7.14.0  2026-05-29
- cmdline: ppfeaturemask 0xfffd7fff -> 0xfff73fff; +amdgpu.sg_display=0; KERNEL_PARAMS 16 -> 17.
- aur: reduce to mkinitcpio-firmware (3 -> 1); drop mt76-mt7925-dkms, r8127-dkms + dead scaffolding.

7.13.5  2026-05-29
- drop advisory diagnostics (_vrkm_ttm_diag, _vrk_audio_state, _boot_initrd_size_scan); runtime-vars 5 -> 4.

7.13.4  2026-05-29
- condense comments to single-line; banners, rationale, header retained.

7.13.3  2026-05-29
- drop RY_INSTALL_NO_MATRIX; matrix always renders to stderr; runtime-vars 6 -> 5.

7.13.2  2026-05-29
- drop RY_INSTALL_PKG_REMOVE_CASCADE, RY_INSTALL_NO_INTERACTIVE_SUDO; held rdeps skipped; runtime-vars 8 -> 6.

7.13.1  2026-05-29
- drop inert RY_INSTALL_ALLOW_PARTIAL_UPGRADE; pacman -Syu --needed always.

7.13.0  2026-05-29
- aur: install unconditionally; drop hardware-gating detectors, RY_INSTALL_MAINTENANCE; runtime-vars 9 -> 8; AUR 2 -> 3.

7.12.0  2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf (fstab excluded); add time-sync preflight; forbid partial upgrades.

Earlier releases: see git history.
