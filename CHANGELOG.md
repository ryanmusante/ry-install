ry-install changelog
====================

Newest first; dates ISO-8601 (YYYY-MM-DD).

7.19.1  2026-06-02
- cmdline: iommu=pt -> amd_iommu=off; KERNEL_PARAMS stays 13.
- docs: install-flow file count 16 -> 15; --help notes --country=XX honored in all modes.
- format: run-summary evidence column 30 -> 50 cols (no on-screen truncation).

7.19.0  2026-06-02
- pkgs: drop iw, rtkit from PKGS_ADD (CachyOS defaults); 16 -> 14.
- files: drop /etc/modules-load.d/i2c-dev.conf and its machinery (ddcutil ships it); managed-file 16 -> 15.
- change: wireless regdom -> /etc/iw-regdomain (COUNTRY=), consumed by cachyos-iw-set-regdomain; old modprobe value was overridden.
- fix: ntsync autoload verify scans candidate confs; ends spurious WARN. --verify only.

7.18.0  2026-06-01
- remove: drop the kernel-version floor gate; no kernel check at install.
- remove: drop the _ntsync_state kernel-version branch; detection unchanged.
- docs: README drops kernel badge/row/notes and moot pre-7 kernel issues.

7.17.29  2026-06-01
- comment: reword the <6.14 floor comment to "non-aborting".
- docs: uninstall note — PKGS_ADD includes Vulkan/gaming deps; review before -Rns.

7.17.28  2026-06-01
- comment: condense over-length/multi-line comments to single lines (<= 120 cols).

7.17.27  2026-06-01
- fix: --check keeps confirmed drift as EXIT_DRIFT (10), not EXIT_PREFLIGHT (3). --check only.

7.17.26  2026-06-01
- fix: _vsc_check_one treats an empty installed file as MISMATCH, not a collect error. --verify only.

7.17.25  2026-05-31
- style: collapse two set -l decls in _dc_sweep_filesystem.

7.17.24  2026-05-31
- fix: _vrs_installed_file_perms uses per-file findmnt fstype; skips vfat/undetermined. --verify only.
- change: fstab ext4 rewrite tab-separates rewritten lines; still idempotent.

7.17.23  2026-05-31
- fix: --install-file for modules-load.d/* now modprobes immediately (_post_modload); hooks 16 -> 17.
- docs: content-generator count 15 -> 16; sysctl 7 -> 8.

7.17.22  2026-05-31
- docs: document curl as a hard dependency.
- fix: fish-version gate defaults an absent minor to 0; garbage still rejected.
- refactor: collapse 80 set -l decls; 5166 -> 5086 lines.

7.17.21  2026-05-31
- feat: pin NVMe scheduler to none (60-ry-ioschedulers.rules); managed-file 15 -> 16, hooks 15 -> 16.
- change: ttm pages_limit/page_pool_size 16777216 -> 8388608 (GTT 64 -> 32 GiB).

7.17.20  2026-05-31
- change: drop processor.max_cstate=1, amdgpu.cwsr_enable=0; KERNEL_PARAMS 15 -> 13.
- change: amdgpu.ppfeaturemask 0xfff73fff -> 0xffffffff.
- feat: add vm.max_map_count=2147483642; SYSCTL_VALUES 7 -> 8.

7.17.19  2026-05-31
- fix: _tmpfile_key uses literal HOME-prefix compare, not glob.
- refactor: extract _vrsv_wifi_nm_backend from _vrsv_wifi.
- docs: exit-code table notes code 1 covers general install FAIL.

7.17.18  2026-05-31
- fix: route modules-load.d/i2c-dev.conf to the bare-module validator (was aborting at exit 3). Regression from 7.17.16.
- docs: content-generator count 13 -> 15.

7.17.17  2026-05-31
- change: wireless regdom mandatory (default US) via ry-cfg80211-regdom.conf; managed-file 14 -> 15.
- feat: --verify checks regdom statically and at runtime.
- change: --country=XX overrides US; ISO-3166 alpha-2 validated.
- feat: add iw to PKGS_ADD; 15 -> 16.

7.17.16  2026-05-31
- feat: add ddcutil, rtkit to PKGS_ADD; ship i2c-dev.conf; managed-file 13 -> 14, PKGS_ADD 13 -> 15.
- feat: opt-in --country=XX regdom (advisory, untracked).
- change: drop amdgpu.gpu_recovery=1; KERNEL_PARAMS 16 -> 15.
- change: resolved DNSOverTLS opportunistic -> no.

7.17.15  2026-05-31
- comment: condense the _dc_kill_children fast-path rationale to one line.

7.17.14  2026-05-31
- fix: paru-absent now advisory (WARN + continue).
- fix: partial AUR failure WARN; only all-failed is FAIL.
- fix: batch AUR failure recovered by retry is PASS.
- fix: WARN-only service paths no longer set INSTALL_HAD_ERRORS.
- fix: PKGS_DEL records the actual removed count; db.lck during removal FAIL.
- docs: verdict table gains an Exit column + two preflight-bypass exits.

7.17.13  2026-05-31
- harden: _acquire_lock stale-reclaim retries 3x, re-checking PID liveness.
- fix: _awf_postwrite_verify_restore logs WARN when re-verify is skipped.
- docs: Prerequisites adds a kernel-version map.
- docs: --help notes -h/-v are honored before all checks.

7.17.12  2026-05-31
- perf: _dc_kill_children probes child PIDs before TERM/grace/KILL.
- cleanup: drop unreachable tmpfiles.d scaffolding; hooks 16 -> 15.
- harden: _resolve_esp/_resolve_boot_path try a non-sudo test -d first.
- cleanup: _dc_erase_globals erases the fstab/sysctl globals.
- comment: note *.service tag reserved for SERVICE_DESTINATIONS.

7.17.11  2026-05-31
- fix: force-print the boot-critical DO NOT REBOOT banner in QUIET install.
- fix: verify sudo-cache bail symmetric across static/runtime arms.
- fix: drop a stray JSONL-only _phase_record in _vrsv_wifi.
- harden: write .ry.bak only after render + symlink-probe.
- docs: disambiguate kernel-floor wording from the boot-rebuild taint.

7.17.10  2026-05-31
- fix: add ry-tee-err.* to the fs-sweep globs.
- comment: condense three rationale comments to single lines.

7.17.9  2026-05-31
- fix: count an installed-bytes collect failure once in _verify_static_checksum.
- harden: systemd >= 250 a true hard gate.
- harden: allocate the _run overflow-spill via mktemp --suffix=.log.

7.17.8  2026-05-31
- fix: export HOME via set -gx on the getent-recovery path.
- fix: signal-time lock cleanup removes the dir only when held by us.
- harden: _run timeout-bypass skips env and VAR=val tokens after sudo.

7.17.7  2026-05-31
- format: split the --INSTALL-FILE banner into DISPATCH TABLE + POST-HOOK HANDLERS.

7.17.6  2026-05-31
- format: split VERIFY-STATIC SYSTEM into SYSTEM+USER / PACKAGES+SERVICES+SYNTAX / CHECKSUM+DRIVER.
- comment: collapse the _RY_POST_HOOKS dispatch note to one line.

7.17.5  2026-05-31
- format: split the VERIFY-RUNTIME banner into SERVICES / ENVIRONMENT / SESSION+PERMS + orchestrators.

7.17.4  2026-05-31
- kernel: condense _ry_check_kernel_version to the <6.14 hard-floor only.
- cleanup: remove the unused RC_KVER_WARN code.
- docs: README flow line reads ">= 6.14 FAIL".

7.17.3  2026-05-31
- docs: paru recommended (>= 2.0.0), not a hard gate.
- docs: scope preflight-abort to hard requirements; kernel <6.14 taints, not aborts.
- docs: Run Summary splits Result/Verdict legends.
- progress: clamp _PROG_TOTAL >= 1 (divide-by-zero guard).

7.17.2  2026-05-31
- verify: fix footer double-count when the runtime arm bails at sudo-cache.
- verify: split the drirc xmllint check into _vrs_drirc_xml.
- verify: firewall nft_rules counts actual rules, not chain headers.

7.17.1  2026-05-31
- style: quote always-set test operands.

7.17.0  2026-05-30
- cmdline: drop amdgpu.sg_display=0; KERNEL_PARAMS 17 -> 16.
- cli: --verify replaces --verify-static/--verify-runtime (combined pass + exit).
- mask: systemctl mask --now stops live units at install.
- verify: assert masked units inactive, NM backend==iwd, drirc/modprobe, firewall.
- run: spill full stdout/stderr to LOG_DIR/run-overflow on truncation.
- verify: derive ttm limits from TTM_* consts; assert drirc XML well-formed.
- trim: drop advisory ReBAR/SAM telemetry.

7.16.4  2026-05-30
- docs: tighten the Prerequisites sudo-cache warning.

7.16.3  2026-05-30
- docs: README collapsible sections open by default.

7.16.2  2026-05-30
- docs: Phase 3 heading Configuration Files -> Configuration.

7.16.1  2026-05-30
- docs: mask count 12 -> 11.

7.16.0  2026-05-30
- logind: drop HandleSecureAttentionKey; LOGIND_IGNORE_KEYS 9 -> 8.
- mask: drop lvm2-monitor.service; MASK 12 -> 11.

7.15.0  2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE; count 10.
- sysctl: drop net.core.busy_poll/busy_read; SYSCTL_VALUES 9 -> 7.

7.14.3  2026-05-30
- harden: guard optional-tool calls (ip, ping, swapon/zramctl, zcat).

7.14.2  2026-05-29
- format: one-element-per-line arrays; banners to 100 cols.

7.14.1  2026-05-29
- verify: derive expected ppfeaturemask from KERNEL_PARAMS.

7.14.0  2026-05-29
- cmdline: ppfeaturemask 0xfffd7fff -> 0xfff73fff; +amdgpu.sg_display=0; KERNEL_PARAMS 16 -> 17.
- aur: reduce to mkinitcpio-firmware (3 -> 1).

7.13.5  2026-05-29
- trim: drop advisory diagnostics; runtime-vars 5 -> 4.

7.13.4  2026-05-29
- comment: condense comments to single-line; banners/rationale/header retained.

7.13.3  2026-05-29
- cli: drop RY_INSTALL_NO_MATRIX; matrix always to stderr; runtime-vars 6 -> 5.

7.13.2  2026-05-29
- cli: drop RY_INSTALL_PKG_REMOVE_CASCADE, RY_INSTALL_NO_INTERACTIVE_SUDO; runtime-vars 8 -> 6.

7.13.1  2026-05-29
- cli: drop RY_INSTALL_ALLOW_PARTIAL_UPGRADE; pacman -Syu --needed always.

7.13.0  2026-05-29
- aur: install unconditionally; drop hardware-gating; runtime-vars 9 -> 8; AUR 2 -> 3.

7.12.0  2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf (fstab excluded); add time-sync preflight.

Earlier releases: see git history.
