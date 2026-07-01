ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.83.4 (2026-06-30)
-------------------
  - Collapse multi-line sysctl rationale into one comment; trim verbose
    comment lines to essentials.

7.83.3 (2026-06-30)
-------------------
  - Correct two section banners: config-format validators list real
    families (drop stale TMPFILES); runtime-services banner adds nftables.

7.83.2 (2026-06-30)
-------------------
  - Document non-obvious sysctl values (netdev budget, max_map_count,
    swappiness).

7.83.1 (2026-06-30)
-------------------
  - _run output-capture tail cap derives from head cap; elided count
    stays non-negative if the cap is retuned.

7.83.0 (2026-07-01)
-------------------
  - environment.d and sysctl.d generators reject control chars, blocking
    directive injection.
  - Hoist GPU_DPM_LEVEL accepted set to _RY_DPM_LEVELS; guard and message
    share one source.
  - Trim exit-code list to user-visible codes (0-5, 10).

7.82.0 (2026-06-30)
-------------------
  - Validate GPU_DPM_LEVEL against the dpm-level enum; blocks udev ATTR{}
    corruption.
  - Reject ISO-3166-1 reserved COUNTRY codes (AA, QM-QZ, XA-XZ, ZZ).
  - environment.d generator skips malformed entries and asserts count.

7.81.0 (2026-06-29)
-------------------
  - Remove linux-firmware soft-floor advisory and dangling version prose.
  - Add intros to Managed Files and Tuning Notes sections.

7.80.0 (2026-06-29)
-------------------
  - Trim in-script comments to vital rationale.

7.79.6 (2026-06-29)
-------------------
  - GPU udev rule: KERNEL=="card[0-9]*" plus DEVTYPE=="drm_minor".

7.79.5 (2026-06-29)
-------------------
  - SYSTEM_UPGRADED false default plus set -q guard.

7.79.4 (2026-06-28)
-------------------
  - Condense changelog to one-line form.

7.79.3 (2026-06-28)
-------------------
  - Gate below-floor kernel branch on RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1.

7.79.2 (2026-06-28)
-------------------
  - Add README Configuration subsections and grouped Managed Files tables.

7.79.1 (2026-06-28)
-------------------
  - Raise linux-firmware soft-floor advisory 20260110 -> 20260410.

7.79.0 (2026-06-28)
-------------------
  - Raise KERNEL_MIN 6.18 -> 6.19.
  - Add TCP 27037 to gated remote-play set.
  - _vrk_cpu_state asserts amd_pstate/dynamic_epp == disabled.
  - Re-enable mangohud cpu_temp.

7.78.3 (2026-06-28)
-------------------
  - Collapse 12 functions to one-line form.

7.78.2 (2026-06-28)
-------------------
  - Condense README prose; known-benign log tables -> prose.

7.78.1 (2026-06-28)
-------------------
  - Replace fish >= 3.7 path basename with floor-safe command basename.

7.78.0 (2026-06-28)
-------------------
  - Drop baloofilerc and _post_baloo. Configs 18 -> 17.

7.77.2 (2026-06-28)
-------------------
  - Remove _kb_* known-benign subsystem and _ry_check_umip_disabled.
  - Add UMIP / clearcpuid=514 Tuning Note.

7.77.1 (2026-06-28)
-------------------
  - Add two verify-section banners.

7.77.0 (2026-06-27)
-------------------
  - cmdline: iommu=pt -> amd_iommu=off.
  - Add _vrkm_iommu.

7.76.1 (2026-06-27)
-------------------
  - Drop modules-load.d/ntsync.conf.
  - Comment out mangohud cpu_temp.

7.76.0 (2026-06-27)
-------------------
  - Add mangohud cpu_temp.
  - Add linux-firmware soft-floor advisory.

7.75.1 (2026-06-27)
-------------------
  - cpupower governor performance -> powersave.
  - udev AMD P-State EPP performance -> balance_performance.

7.75.0 (2026-06-27)
-------------------
  - cmdline: add fsck.mode=force, fsck.repair=yes.

7.74.2 (2026-06-27)
-------------------
  - Add _vss_known_benign advisory.

7.74.1 (2026-06-27)
-------------------
  - Add _ry_rtc_writeback at both sync paths.

7.74.0 (2026-06-27)
-------------------
  - cmdline: add processor.max_cstate=1.
  - Remove _ir_validate_repo_tier.

7.73.6 (2026-06-26)
-------------------
  - cmdline: add btusb.enable_autosuspend=n.

7.73.4 (2026-06-26)
-------------------
  - Add */modprobe.d/* post-hook and _post_modprobe.

7.73.1 (2026-06-26)
-------------------
  - Count each fatal condition once via _err_loud_cont.

7.73.0 (2026-06-26)
-------------------
  - Rename 60-ry-perf.rules -> 99-ry-perf.rules.
  - Drop vm.page-cluster, vm.vfs_cache_pressure.

7.72.0 (2026-06-26)
-------------------
  - Add 60-ry-mt7925e.conf (disable_aspm=1).
  - Add _vss_modprobe.

7.71.4 (2026-06-26)
-------------------
  - Prefix mesa soft-floor probe with command (avoid pacman shadow).

7.71.3 (2026-06-26)
-------------------
  - Restore mangohud gpu_power, text_outline, toggle_hud.
  - Guard the x86-64-v4 probe.

7.71.1 (2026-06-26)
-------------------
  - Add _ir_validate_keys (refuse out-of-domain scalar key).

7.71.0 (2026-06-26)
-------------------
  - Add _ir_validate_kernel_floor.
  - Parameterize GPU_DPM_LEVEL (default auto).
  - Add PROTON_FSR4_RDNA3_UPGRADE=1.
  - Add RY_REMOTE_PLAY_PORTS gate (default false).

7.70.1 (2026-06-24)
-------------------
  - Guard _err VERIFY_FAIL increment with set -q.

7.70.0 (2026-06-23)
-------------------
  - Remove /etc/conf.d/wireless-regdom.
  - bluetooth ReconnectAttempts 7 -> 3; remove ReconnectIntervals.
  - Raise mesa soft-floor warn 25.3 -> 26.0.

7.69.1 (2026-06-22)
-------------------
  - Extract _content_fn_for.

7.69.0 (2026-06-22)
-------------------
  - cmdline: remove amd_iommu=on.

7.68.0 (2026-06-22)
-------------------
  - boot: remove clearcpuid=rdseed.
  - Remove _ry_check_rdseed_workaround_stale.

7.66.0 (2026-06-22)
-------------------
  - Split WiFi runtime state into a dedicated sub-check.

7.65.0 (2026-06-21)
-------------------
  - mangohud: order fps/frametime ahead of GPU/CPU.

7.64.0 (2026-06-21)
-------------------
  - Remove drirc 95-ry-radv-apu.conf (gfx1151 reports uma:1).
  - Guards: SYSTEM_DESTINATIONS 17 -> 15, post-hooks and file count 20 -> 18.

7.63.0 (2026-06-21)
-------------------
  - bluetooth: add main.conf; enable bluetooth.service.
  - Add _vss_bluetooth.

7.62.0 (2026-06-21)
-------------------
  - cmdline: amd_iommu=off -> amd_iommu=on iommu=pt.
  - NM wifi.backend=wpa_supplicant; wifi.powersave=2.
  - Mask modemmanager.service.

7.61.0 (2026-06-21)
-------------------
  - Add NM-dispatcher logging.conf (LogLevelMax=notice).
  - Guard vercmp behind command -q.

7.60.0 (2026-06-21)
-------------------
  - mangohud: remove fps_metrics, cpu_temp, gpu_power, text_outline, toggle_hud.
  - Drop toggle_hud assertion.

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
