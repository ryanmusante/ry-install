ry-install changelog
====================

7.19.18  2026-06-03
- cleanup: drop dead ry-val-unit sweep glob (no producer)
- cleanup: track atomic-write/fstab tmpfile after empty-guard

7.19.17  2026-06-03
- verify: root-UUID resolution failure no longer aborts; warns and continues with generic root=UUID check
- docs: convert remaining README prose to tables

7.19.16  2026-06-03
- cli: --country reject message notes UK is GB and that 00/EU are not alpha-2
- style: tighten verbose comments to vital info

7.19.15  2026-06-03
- fix: preflight-abort summary renders verdict PREFLIGHT (exit 3); was FAIL
- docs: README verdict + exit-code tables add PREFLIGHT

7.19.14  2026-06-03
- cleanup: _fstab_needs_change drop redundant -- in commit= capture (inert)

7.19.13  2026-06-03
- fix: fstab rewrite WARNs + logs when findmnt absent (was committed ungated)
- style: trim verbose comments
- docs: trim README/CHANGELOG

7.19.12  2026-06-03
- harden: --country validated against 249 assigned ISO-3166-1 alpha-2 codes
- refactor: RADV drirc option from $RADV_APU_OPTION (single source)
- docs: note 250/255 are internal _as/_run misuse rc, never a process exit

7.19.11  2026-06-03
- fix: drop unused sort from preflight hard-dependency gate
- fix: _install_fstab_opts evidence reflects outcome

7.19.10  2026-06-03
- style: pad CONFIG-FORMAT VALIDATORS divider to 100 cols
- style: drop stray blank lines after two headers

7.19.9  2026-06-03
- pkgs: add cachy-update to PKGS_DEL; 7 -> 8

7.19.8  2026-06-03
- comment: _vmh_order_checks banner 11 -> 10 invariants
- comment: note _as rc=250 / _run rc=255 misuse sentinels

7.19.7  2026-06-03
- style: quote remaining numeric test operands
- docs: README plain layout; udev ACTION=="add|change"

7.19.6  2026-06-03
- docs: README config tables to 2-column layout

7.19.5  2026-06-02
- harden: _ir_validate_counts guards _RY_PHASE_NAMES, _RY_BACKUP_TARGETS, _RY_NTSYNC_MODLOAD_CONFS

7.19.4  2026-06-02
- comment: post-hook handler banner 12 -> 11

7.19.3  2026-06-02
- cmdline: ppfeaturemask 0xffffffff -> 0xfff73fff

7.19.2  2026-06-02
- cleanup: drop SERVICE_DESTINATIONS; _RY_POST_HOOKS 17 -> 16
- docs: regdom falls back to /etc/iw-regdomain when iw absent

7.19.1  2026-06-02
- cmdline: iommu=pt -> amd_iommu=off
- docs: file count 16 -> 15; --country honored in all modes

7.19.0  2026-06-02
- pkgs: drop iw, rtkit; 16 -> 14
- files: drop modules-load.d/i2c-dev.conf; 16 -> 15
- change: wireless regdom to /etc/iw-regdomain

7.18.0  2026-06-01
- remove: kernel-version floor gate

7.17.29  2026-06-01
- docs: PKGS_ADD includes Vulkan/gaming deps

7.17.28  2026-06-01
- comment: condense to single line (<= 120 cols)

7.17.27  2026-06-01
- fix: --check keeps confirmed drift as EXIT_DRIFT (10)

7.17.26  2026-06-01
- fix: _vsc_check_one treats empty installed file as MISMATCH

7.17.25  2026-05-31
- style: collapse two set -l decls in _dc_sweep_filesystem

7.17.24  2026-05-31
- fix: _vrs_installed_file_perms uses per-file findmnt fstype; skips vfat
- change: fstab ext4 rewrite tab-separates; idempotent

7.17.23  2026-05-31
- fix: --install-file modules-load.d/* modprobes immediately
- docs: content-generator count 15 -> 16; sysctl 7 -> 8

7.17.22  2026-05-31
- docs: curl is a hard dependency
- fix: fish-version gate defaults absent minor to 0
- refactor: collapse set -l decls; 5166 -> 5086 lines

7.17.21  2026-05-31
- feat: pin NVMe scheduler none; 15 -> 16
- change: ttm pages_limit/page_pool_size 16777216 -> 8388608

7.17.20  2026-05-31
- change: drop processor.max_cstate=1, amdgpu.cwsr_enable=0; KERNEL_PARAMS 15 -> 13
- feat: add vm.max_map_count; SYSCTL_VALUES 7 -> 8

7.17.19  2026-05-31
- fix: _tmpfile_key literal HOME-prefix compare
- docs: exit-code 1 covers general install FAIL

7.17.18  2026-05-31
- fix: route modules-load.d/i2c-dev.conf to bare-module validator

7.17.17  2026-05-31
- change: wireless regdom mandatory, default US
- feat: --country=XX overrides US; ISO-3166 alpha-2 validated

7.17.16  2026-05-31
- feat: add ddcutil, rtkit; ship i2c-dev.conf
- change: drop amdgpu.gpu_recovery=1
- change: resolved DNSOverTLS -> no

7.17.15  2026-05-31
- comment: condense _dc_kill_children fast-path rationale

7.17.14  2026-05-31
- fix: paru-absent is WARN+continue; partial AUR WARN, all-failed FAIL
- fix: WARN-only service paths no longer set INSTALL_HAD_ERRORS
- fix: PKGS_DEL records actual removed count

7.17.13  2026-05-31
- harden: _acquire_lock stale-reclaim retries 3x

7.17.12  2026-05-31
- perf: _dc_kill_children probes child PIDs before TERM/grace/KILL
- harden: _resolve_esp/_resolve_boot_path try non-sudo test -d first

7.17.11  2026-05-31
- fix: force-print boot-critical DO NOT REBOOT in QUIET install
- harden: write .ry.bak only after render + symlink-probe

7.17.10  2026-05-31
- fix: add ry-tee-err.* to fs-sweep globs

7.17.9  2026-05-31
- harden: systemd >= 250 a true hard gate
- harden: _run overflow-spill via mktemp --suffix=.log

7.17.8  2026-05-31
- fix: export HOME via set -gx on getent-recovery path
- harden: _run timeout-bypass skips env and VAR=val tokens after sudo

7.17.7  2026-05-31
- format: split --install-file banner

7.17.6  2026-05-31
- format: split verify-static banner

7.17.5  2026-05-31
- format: split verify-runtime banner

7.17.4  2026-05-31
- kernel: condense _ry_check_kernel_version to <6.14 hard-floor

7.17.3  2026-05-31
- docs: paru recommended >= 2.0.0, not a hard gate
- progress: clamp _PROG_TOTAL >= 1

7.17.2  2026-05-31
- verify: fix footer double-count when runtime arm bails at sudo-cache
- verify: firewall nft_rules counts actual rules

7.17.1  2026-05-31
- style: quote always-set test operands

7.17.0  2026-05-30
- cmdline: drop amdgpu.sg_display=0; KERNEL_PARAMS 17 -> 16
- cli: --verify replaces --verify-static/--verify-runtime
- mask: systemctl mask --now stops live units

7.16.4  2026-05-30
- docs: tighten sudo-cache warning

7.16.3  2026-05-30
- docs: README sections open by default

7.16.2  2026-05-30
- docs: Phase 3 heading to Configuration

7.16.1  2026-05-30
- docs: mask count 12 -> 11

7.16.0  2026-05-30
- logind: drop HandleSecureAttentionKey; LOGIND_IGNORE_KEYS 9 -> 8
- mask: drop lvm2-monitor.service; MASK 12 -> 11

7.15.0  2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE
- sysctl: drop net.core.busy_poll/busy_read; SYSCTL_VALUES 9 -> 7

7.14.3  2026-05-30
- harden: guard optional-tool calls (ip, ping, swapon/zramctl, zcat)

7.14.2  2026-05-29
- format: one-element-per-line arrays

7.14.1  2026-05-29
- verify: derive expected ppfeaturemask from KERNEL_PARAMS

7.14.0  2026-05-29
- cmdline: ppfeaturemask 0xfffd7fff -> 0xfff73fff; +amdgpu.sg_display=0; 16 -> 17
- aur: reduce to mkinitcpio-firmware; 3 -> 1

7.13.5  2026-05-29
- trim: drop advisory diagnostics; runtime-vars 5 -> 4

7.13.4  2026-05-29
- comment: condense to single-line

7.13.3  2026-05-29
- cli: drop RY_INSTALL_NO_MATRIX; matrix always to stderr; runtime-vars 6 -> 5

7.13.2  2026-05-29
- cli: drop RY_INSTALL_PKG_REMOVE_CASCADE, RY_INSTALL_NO_INTERACTIVE_SUDO; 8 -> 6

7.13.1  2026-05-29
- cli: drop RY_INSTALL_ALLOW_PARTIAL_UPGRADE; pacman -Syu --needed always

7.13.0  2026-05-29
- aur: install unconditionally; drop hardware-gating; AUR 2 -> 3

7.12.0  2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf; add time-sync preflight

Earlier releases: see git history.
