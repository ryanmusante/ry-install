ry-install ChangeLog

Newest first; dates ISO-8601.

7.17.25  2026-05-31
- style: collapse two adjacent set -l declarations in _dc_sweep_filesystem onto one line; no behavior change.

7.17.24  2026-05-31
- fix: _vrs_installed_file_perms uses per-file findmnt --target fstype, skipping the perm check on vfat or undetermined fstype; avoids a spurious /boot perm FAIL. --verify only.
- change: fstab ext4 rewrite tab-separates rewritten lines (awk OFS " " -> "\t"); other lines unchanged, still idempotent.

7.17.23  2026-05-31
- fix: --install-file for /etc/modules-load.d/* now loads the listed modules immediately via new _post_modload (modprobe); the file previously deployed with no runtime apply. Adds */modules-load.d/* post-hook; _RY_POST_HOOKS 16 -> 17, handlers 11 -> 12. Full install unaffected (module still autoloads at boot).
- docs: correct content-generator header count 15 -> 16 (udev generator from 7.17.21 was uncounted).
- docs: README sysctl summary 7 -> 8 tunables (table and SYSCTL_VALUES already had 8 since 7.17.20).

7.17.22  2026-05-31
- docs: document curl as a hard dependency in Prerequisites (HTTPS preflight, enforced by the required-command gate).
- fix: fish-version gate defaults an absent minor to 0, so a bare-major string parses against the >= 3.6 floor instead of erroring; garbage strings still rejected. Defensive only.
- refactor: collapse 80 adjacent set -l declarations onto shared lines; 5166 -> 5086 lines, no behavior change.

7.17.21  2026-05-31
- feat: pin NVMe I/O scheduler to none via new /etc/udev/rules.d/60-ry-ioschedulers.rules (native multiqueue makes a scheduler pure overhead); managed-file 15 -> 16, _RY_POST_HOOKS 15 -> 16. Adds generator, */udev/rules.d/* validator, static + runtime checks, and _post_udev. ENV{DEVTYPE}=="disk" guard avoids the partition/controller write errors of the bare nvme[0-9]* form.
- change: ttm pages_limit + page_pool_size 16777216 -> 8388608 (GTT pool 64 -> 32 GiB); module is ttm, not amdttm.

7.17.20  2026-05-31
- change: drop processor.max_cstate=1 and amdgpu.cwsr_enable=0 (deeper C-states; CWSR to default); KERNEL_PARAMS 15 -> 13.
- change: amdgpu.ppfeaturemask 0xfff73fff -> 0xffffffff (all PowerPlay bits). Stale cmdline reads as drift until regenerated.
- feat: add vm.max_map_count=2147483642 (Proton large-address-space); SYSCTL_VALUES 7 -> 8.

7.17.19  2026-05-31
- fix: _tmpfile_key derives the key by literal HOME-prefix compare, not glob; a HOME with glob metacharacters could misroute it. Output byte-identical for a normalized HOME.
- refactor: extract _vrsv_wifi_nm_backend from _vrsv_wifi.
- docs: exit-code table notes code 1 also covers a general install FAIL.

7.17.18  2026-05-31
- fix: route /etc/modules-load.d/i2c-dev.conf to a bare module-name validator (was misrouted to the INI validator, aborting every install at exit 3). Adds */modules-load.d/* dispatch + _grep_modload_entry. Regression from 7.17.16.
- docs: correct content-generator header count 13 -> 15.

7.17.17  2026-05-31
- change: wireless regdom now mandatory (default US) via /etc/modprobe.d/ry-cfg80211-regdom.conf (replaces OpenRC conf.d); now tracked. Managed-file 14 -> 15.
- feat: --verify checks regdom statically and at runtime (iw reg get).
- change: --country=XX overrides US, validated ISO-3166 alpha-2 at argparse.
- feat: add iw to PKGS_ADD; PKGS_ADD 15 -> 16.

7.17.16  2026-05-31
- feat: add ddcutil + rtkit to PKGS_ADD; ship /etc/modules-load.d/i2c-dev.conf. Managed-file 13 -> 14, PKGS_ADD 13 -> 15.
- feat: add opt-in --country=XX wireless regdom (advisory, untracked).
- change: drop amdgpu.gpu_recovery=1 (sets TAINT_USER); KERNEL_PARAMS 16 -> 15.
- change: systemd-resolved DNSOverTLS opportunistic -> no.

7.17.15  2026-05-31
- comment: condense _dc_kill_children fast-path rationale to one line.

7.17.14  2026-05-31
- fix: paru-absent now advisory — WARN + continue (was FAIL).
- fix: partial AUR failure now WARN; only all-packages-failed is FAIL. Resolves verdict/exit desync.
- fix: batch AUR failure recovered by per-package retry is now PASS, not a spurious FAIL.
- fix: WARN-only service paths no longer set INSTALL_HAD_ERRORS.
- fix: PKGS_DEL removal records the actual removed count; db.lck during removal now FAIL.
- docs: README verdict table gains an Exit column + the two preflight-bypass exits.

7.17.13  2026-05-31
- harden: _acquire_lock stale-reclaim retries 3x, re-checking PID liveness each pass (was single-attempt).
- fix: _awf_postwrite_verify_restore logs WARN when byte re-verify is skipped (was a silent return 0).
- docs: README Prerequisites adds a kernel-version map.
- docs: --help notes -h/-v are honored before all checks.

7.17.12  2026-05-31
- perf: _dc_kill_children probes child PIDs before TERM->grace->KILL; no-children exits skip the grace.
- cleanup: drop unreachable tmpfiles.d scaffolding; _RY_POST_HOOKS 16 -> 15, handlers 11 -> 10.
- harden: _resolve_esp / _resolve_boot_path try a non-sudo test -d before the sudo probe.
- cleanup: _dc_erase_globals also erases the fstab/sysctl globals.
- comment: note *.service tag reserved for SERVICE_DESTINATIONS; RC_KVER_FAIL is an internal sentinel.

7.17.11  2026-05-31
- fix: force-print the boot-critical DO NOT REBOOT banner to stderr+JSONL in QUIET install.
- fix: verify sudo-cache bail now symmetric across the static/runtime arms.
- fix: drop a stray JSONL-only _phase_record in _vrsv_wifi.
- harden: write .ry.bak only after render + symlink-probe (commit point).
- comment: note _awf_postwrite_verify_restore re-invokes the generator (keep backup targets side-effect-free).
- docs: disambiguate kernel-floor wording from the boot-rebuild taint.

7.17.10  2026-05-31
- fix: add ry-tee-err.* to the fs-sweep globs so a signal during a Phase 3 write can't orphan it.
- comment: condense three rationale comments to single lines.

7.17.9  2026-05-31
- fix: count an installed-bytes collect failure once in _verify_static_checksum.
- harden: make systemd >= 250 a true hard gate (refuse when systemctl --version is unparseable).
- harden: allocate the _run overflow-spill filename via mktemp --suffix=.log.

7.17.8  2026-05-31
- fix: export HOME via set -gx on the getent-recovery path so child processes inherit it.
- fix: signal-time lock cleanup removes the lock dir only when held by us (or its pid file is ours/empty).
- harden: _run timeout-bypass skips env and VAR=val tokens after sudo.

7.17.7  2026-05-31
- format: split the --INSTALL-FILE banner into DISPATCH TABLE + ORCHESTRATOR and POST-HOOK HANDLERS.

7.17.6  2026-05-31
- format: split VERIFY-STATIC SYSTEM into SYSTEM+USER / PACKAGES+SERVICES+SYNTAX / CHECKSUM+DRIVER banners.
- comment: collapse the _RY_POST_HOOKS dispatch note to one line.
- header: sync the file-header version to VERSION.

7.17.5  2026-05-31
- format: split the VERIFY-RUNTIME banner into SERVICES / ENVIRONMENT / SESSION+PERMS arms + an orchestrators banner.

7.17.4  2026-05-31
- kernel: condense _ry_check_kernel_version to the < 6.14 hard-floor only.
- cleanup: remove the unused RC_KVER_WARN code and its unreachable branch.
- docs: README flow line now reads ">= 6.14 FAIL".

7.17.3  2026-05-31
- docs: Prerequisites — paru recommended (>= 2.0.0), not a hard gate.
- docs: scope the preflight-abort statement to hard requirements; kernel < 6.14 taints (exit 1), not aborts.
- docs: Run Summary — split Result and Verdict legends into two tables.
- progress: clamp _PROG_TOTAL >= 1 in _progress_init (divide-by-zero guard).

7.17.2  2026-05-31
- verify: fix footer double-count when the runtime arm bails at sudo-cache.
- verify: split the drirc xmllint check out of _vrs_vulkan into _vrs_drirc_xml.
- verify: firewall nft_rules counts actual rules, not chain headers.

7.17.1  2026-05-31
- style: quote always-set test operands for uniformity.

7.17.0  2026-05-30
- cmdline: drop amdgpu.sg_display=0; KERNEL_PARAMS 17 -> 16.
- cli: --verify replaces --verify-static/--verify-runtime (one combined pass, combined exit + footer).
- mask: systemctl mask --now stops live service/socket units at install.
- verify: assert masked units inactive, NM wifi.backend==iwd, drirc + modprobe values, firewall posture.
- run: spill full stdout/stderr to LOG_DIR/run-overflow on truncation.
- verify: derive ttm pages_limit/page_pool_size from TTM_* consts; assert drirc XML well-formed via xmllint.
- trim: drop advisory ReBAR/SAM verify telemetry.

7.16.4  2026-05-30
- docs: tighten the Prerequisites sudo-cache warning; all mitigations retained.

7.16.3  2026-05-30
- docs: README collapsible sections all open by default.

7.16.2  2026-05-30
- docs: README Phase 3 heading Configuration Files -> Configuration; anchor updated.

7.16.1  2026-05-30
- docs: README mask count 12 -> 11; matches MASK array.

7.16.0  2026-05-30
- logind: drop HandleSecureAttentionKey; LOGIND_IGNORE_KEYS 9 -> 8; remove the systemd >= 257 gate.
- mask: drop lvm2-monitor.service; MASK 12 -> 11.

7.15.0  2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE for the 8060S; count 10.
- sysctl: drop net.core.busy_poll, net.core.busy_read; SYSCTL_VALUES 9 -> 7.

7.14.3  2026-05-30
- guard optional-tool calls (ip, ping, swapon/zramctl, zcat); absent tools degrade cleanly.

7.14.2  2026-05-29
- format only: one-element-per-line arrays; banners to 100-col; notation normalized.

7.14.1  2026-05-29
- verify: derive expected ppfeaturemask from KERNEL_PARAMS (fixes spurious FAIL).

7.14.0  2026-05-29
- cmdline: ppfeaturemask 0xfffd7fff -> 0xfff73fff; +amdgpu.sg_display=0; KERNEL_PARAMS 16 -> 17.
- aur: reduce to mkinitcpio-firmware (3 -> 1); drop dead scaffolding.

7.13.5  2026-05-29
- drop advisory diagnostics; runtime-vars 5 -> 4.

7.13.4  2026-05-29
- condense comments to single-line; banners, rationale, header retained.

7.13.3  2026-05-29
- drop RY_INSTALL_NO_MATRIX; matrix always renders to stderr; runtime-vars 6 -> 5.

7.13.2  2026-05-29
- drop RY_INSTALL_PKG_REMOVE_CASCADE, RY_INSTALL_NO_INTERACTIVE_SUDO; runtime-vars 8 -> 6.

7.13.1  2026-05-29
- drop inert RY_INSTALL_ALLOW_PARTIAL_UPGRADE; pacman -Syu --needed always.

7.13.0  2026-05-29
- aur: install unconditionally; drop hardware-gating detectors; runtime-vars 9 -> 8; AUR 2 -> 3.

7.12.0  2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf (fstab excluded); add time-sync preflight; forbid partial upgrades.

Earlier releases: see git history.
