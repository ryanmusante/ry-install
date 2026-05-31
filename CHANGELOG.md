ry-install ChangeLog

Newest first; dates ISO-8601.

7.17.14  2026-05-31
- fix: paru-absent is now advisory — WARN + continue (exit 0), matching the documented "not a hard gate / warns and continues" contract; was FAIL + INSTALL_HAD_ERRORS (exit 1).
- fix: a *partial* AUR failure (some-but-not-all packages) is recorded WARN and no longer taints the run; only an all-packages-failed AUR step is FAIL (exit 1). Resolves the verdict↔exit desync where the matrix showed PASS-WITH-WARNINGS while the process exited 1.
- fix: a batch AUR install that fails but fully recovers on per-package retry is now PASS, not a spurious "0/N (all failed)" FAIL.
- fix: WARN-only service paths no longer set INSTALL_HAD_ERRORS — systemd-resolved restart, system + user daemon-reload, and iwd-package-absent at finalize. A run whose only anomalies are WARN now exits 0, consistent with the verdict table.
- fix: PKGS_DEL removal records the actual removed count (was the requested count, overstating success on per-package failures); a pacman db.lck during removal is now recorded FAIL to match the taint it already set (was a misleading PASS/N-A row).
- docs: README Run Summary — verdict table gains an Exit column and notes the two preflight-stage exits (hard-requirement abort = 3, kernel < 6.14 floor = 1) that bypass it; clarify the JSONL footer pass/fail/warn are message-level tallies while the matrix verdict + PHASE_RESULT/MATRIX_RENDERED events are the authoritative per-phase record; Phase 2 now spells out the advisory AUR-failure semantics.


- harden: _acquire_lock stale-reclaim retries up to 3x — a peer that wins the post-rm mkdir race re-populates the lock, and each pass re-checks PID liveness before reclaiming (was a single attempt that could return EXIT_LOCK while the lock was actually free).
- fix: _awf_postwrite_verify_restore logs a WARN (+ JSONL POSTWRITE_VERIFY_SKIP) when the byte re-verify is skipped because the content-generator re-run or the installed-bytes read failed (e.g. transient sudo lapse) on a backup-target file; was a silent return 0.
- docs: README Prerequisites adds a kernel-version map note consolidating the >=6.14 floor, >=6.18.4 gfx1151 rec, >=6.16 ROCm, and >=6.19.1 regression-fix references.
- docs: --help notes that -h/--help and -v/--version are honored before all checks (root guard + argparse).

7.17.12  2026-05-31
- perf: _dc_kill_children probes for child PIDs (pgrep -P) before the TERM→0.5s-grace→KILL cycle; clean exits with no children skip the grace entirely (pgrep absent still runs the full cycle).
- cleanup: drop the unreachable systemd-tmpfiles.d scaffolding (_post_tmpfiles, _grep_tmpfiles_entry, the */tmpfiles.d/* dispatch + post-hook tag); no tmpfiles.d destination is managed, so it was never reachable. _RY_POST_HOOKS 16 -> 15; post-hook handlers 11 -> 10.
- harden: _resolve_esp / _resolve_boot_path try a non-sudo test -d on candidate paths before the sudo probe, so a readable vfat ESP is not misclassified to the /boot fallback on a sudo-cache lapse.
- cleanup: _dc_erase_globals also erases _RY_FSTAB_NEEDS_CHANGE, _RY_FSTAB_COMMIT_OVERRIDES, _RY_SYSCTL_BAD_ENTRIES (already cleared inline; defence-in-depth across modes).
- comment: note the *.service post-hook tag is reserved for SERVICE_DESTINATIONS (wired but currently empty); note RC_KVER_FAIL is an internal switch sentinel, never a process exit.

7.17.11  2026-05-31
- fix: force-print the boot-critical "DO NOT REBOOT" banner + recovery to stderr+JSONL in the default QUIET install (was dropped by the QUIET gate); --install-file unaffected.
- fix: verify sudo-cache bail is now symmetric across static/runtime arms (both via _err_loud, no VERIFY_FAIL bump); exit 3 unchanged.
- fix: drop a stray JSONL-only _phase_record in _vrsv_wifi (verify renders no matrix; the _info already logs the skip).
- harden: in _atomic_write_file, write .ry.bak only after render + symlink-probe (the commit point), so a render failure leaves no stale backup.
- comment: note _awf_postwrite_verify_restore re-invokes the generator, so _RY_BACKUP_TARGETS must stay side-effect-free.
- docs: README Prerequisites — disambiguate kernel-floor wording (exit 1 at end, still rebuilds) from the boot-rebuild taint.

7.17.10  2026-05-31
- fix: add ry-tee-err.* to the _do_cleanup filesystem-sweep globs so a signal during a Phase 3 write can't orphan the tee stderr tmpfile (normal path already removed it).
- comment: condense three rationale comments (lock-ownership, fish-math ms scaling, post-hook precedence) to single lines.

7.17.9  2026-05-31
- fix: count an installed-bytes string-collect failure once in _verify_static_checksum (now pairs with _fail_no_count); verdict was never affected.
- harden: make systemd >= 250 a true hard gate — refuse when systemctl --version is unparseable.
- harden: allocate the _run overflow-spill filename via mktemp --suffix=.log (drops the /dev/urandom-suffix path).

7.17.8  2026-05-31
- fix: export HOME via set -gx on the getent-recovery path so paru/makepkg/git children inherit it.
- fix: signal-time lock cleanup removes the lock dir only when held by us or its pid file is empty/ours (protects a peer's lock).
- harden: _run timeout-bypass detection skips env and VAR=val tokens after sudo.

7.17.7  2026-05-31
- format: split the --INSTALL-FILE banner into DISPATCH TABLE + ORCHESTRATOR and POST-HOOK HANDLERS (11). Banners only.

7.17.6  2026-05-31
- format: split VERIFY-STATIC SYSTEM into SYSTEM+USER / PACKAGES+SERVICES+SYNTAX / CHECKSUM+DRIVER banners. Banners only.
- comment: collapse the _RY_POST_HOOKS dispatch note to one line.
- header: sync the file-header version to VERSION (was 7.17.3).

7.17.5  2026-05-31
- format: split the VERIFY-RUNTIME banner into SERVICES / ENVIRONMENT / SESSION+PERMS arms + a TOP-LEVEL ORCHESTRATORS banner. Banners only.

7.17.4  2026-05-31
- kernel: condense _ry_check_kernel_version to the < 6.14 hard-floor only; drop the 6.18.4 WARN, in-preflight ntsync probe, and 6.19.0 WARN.
- cleanup: remove the unused RC_KVER_WARN code and its unreachable WARN branch.
- docs: README flow line now reads ">= 6.14 FAIL"; 6.18.4 + 6.19.0 retained as guidance.

7.17.3  2026-05-31
- docs: Prerequisites — paru recommended (>= 2.0.0), not a hard gate; AUR phase warns and continues if absent.
- docs: scope the preflight-abort statement to hard requirements; kernel < 6.14 taints (exit 1), not aborts (exit 3); paru/NTP warn.
- docs: Run Summary — split Result and Verdict legends into two tables.
- progress: clamp _PROG_TOTAL >= 1 in _progress_init (divide-by-zero guard).
- comments: note the sysctl generator records malformed entries to a deploy-time global, and tmpfiles.d post-hooks are --install-file only.

7.17.2  2026-05-31
- verify: fix footer double-count when the runtime arm bails at sudo-cache; static totals restored, exit unchanged.
- verify: split the drirc xmllint check out of _vrs_vulkan into _vrs_drirc_xml.
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
