ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.83.0 - 7.83.4 (2026-06-30)
----------------------------
  - Trim in-script comments to essentials; collapse multi-line sysctl
    rationale; document non-obvious sysctl values.
  - Correct two section banners (drop stale TMPFILES; add nftables).
  - _run output-capture tail cap derives from head cap.
  - environment.d and sysctl.d generators reject control chars.
  - Hoist GPU_DPM_LEVEL accepted set to _RY_DPM_LEVELS.
  - Trim exit-code list to user-visible codes (0-5, 10).

7.81.0 - 7.82.0 (2026-06-29 .. 06-30)
-------------------------------------
  - Validate GPU_DPM_LEVEL against the dpm-level enum.
  - Reject ISO-3166-1 reserved COUNTRY codes (AA, QM-QZ, XA-XZ, ZZ).
  - environment.d generator skips malformed entries and asserts count.
  - Remove linux-firmware soft-floor advisory and dangling version prose.
  - Add intros to Managed Files and Tuning Notes sections.

7.79.0 - 7.80.0 (2026-06-28 .. 06-29)
-------------------------------------
  - Raise KERNEL_MIN 6.18 -> 6.19.
  - Add TCP 27037 to gated remote-play set.
  - _vrk_cpu_state asserts amd_pstate/dynamic_epp == disabled.
  - GPU udev rule: KERNEL=="card[0-9]*" plus DEVTYPE=="drm_minor".
  - SYSTEM_UPGRADED false default plus set -q guard.
  - Gate below-floor kernel branch on RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1.
  - Raise linux-firmware soft-floor advisory 20260110 -> 20260410.
  - Add README Configuration subsections and grouped Managed Files tables.

7.77.0 - 7.78.3 (2026-06-27 .. 06-28)
-------------------------------------
  - Collapse 12 functions to one-line form; condense README prose.
  - Replace fish >= 3.7 path basename with floor-safe command basename.
  - Drop baloofilerc and _post_baloo; remove _kb_* known-benign subsystem
    and _ry_check_umip_disabled.
  - Add UMIP / clearcpuid=514 Tuning Note; add two verify-section banners.
  - cmdline: iommu=pt -> amd_iommu=off. Add _vrkm_iommu.

7.73.0 - 7.76.1 (2026-06-26 .. 06-27)
-------------------------------------
  - mangohud cpu_temp toggled; add/restore gpu_power, text_outline, toggle_hud.
  - cpupower governor performance -> powersave.
  - udev AMD P-State EPP performance -> balance_performance.
  - cmdline: add fsck.mode=force, fsck.repair=yes, processor.max_cstate=1,
    btusb.enable_autosuspend=n.
  - Add _vss_known_benign; add _ry_rtc_writeback at both sync paths.
  - Remove _ir_validate_repo_tier; count each fatal condition once.
  - Rename 60-ry-perf.rules -> 99-ry-perf.rules; drop vm.page-cluster,
    vm.vfs_cache_pressure.
  - Add 60-ry-mt7925e.conf (disable_aspm=1) and _vss_modprobe.
  - Add */modprobe.d/* post-hook and _post_modprobe.
  - Prefix mesa soft-floor probe with command; guard the x86-64-v4 probe.

7.71.0 - 7.71.4 (2026-06-26)
----------------------------
  - Add _ir_validate_kernel_floor and _ir_validate_keys.
  - Parameterize GPU_DPM_LEVEL (default auto).
  - Add PROTON_FSR4_RDNA3_UPGRADE=1 and RY_REMOTE_PLAY_PORTS gate (off).

7.68.0 - 7.70.1 (2026-06-22 .. 06-24)
-------------------------------------
  - Guard _err VERIFY_FAIL increment with set -q.
  - Remove /etc/conf.d/wireless-regdom.
  - bluetooth ReconnectAttempts 7 -> 3; remove ReconnectIntervals.
  - Raise mesa soft-floor warn 25.3 -> 26.0.
  - Extract _content_fn_for.
  - cmdline: remove amd_iommu=on, clearcpuid=rdseed.
  - Remove _ry_check_rdseed_workaround_stale.

7.60.0 - 7.66.0 (2026-06-21 .. 06-22)
-------------------------------------
  - Split WiFi runtime state into a dedicated sub-check.
  - mangohud: reorder fps/frametime; add/remove HUD fields across revisions.
  - Remove drirc 95-ry-radv-apu.conf (gfx1151 reports uma:1).
  - bluetooth: add main.conf; enable bluetooth.service. Add _vss_bluetooth.
  - cmdline: amd_iommu toggled to on iommu=pt.
  - NM wifi.backend=wpa_supplicant; wifi.powersave=2. Mask modemmanager.service.
  - Add NM-dispatcher logging.conf (LogLevelMax=notice).
  - Guard vercmp behind command -q.
  - Guards: SYSTEM_DESTINATIONS 17 -> 15, post-hooks and file count 20 -> 18.

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
