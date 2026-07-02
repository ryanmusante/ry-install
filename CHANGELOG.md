ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: subsystem: imperative summary (one line, 72 cols).

7.85.3 (2026-07-01)
-------------------
  check: honor the silent-probe contract when invoked as root
         (exit 3 with no output; other modes keep the loud
         root-refusal usage error, exit 2)
  README: normalize every table to one 100-column width; move
          package lists and uninstall commands into code blocks

7.85.2 (2026-07-01)
-------------------
  signal: propagate 128+N to the parent on INT/TERM/HUP/ABRT
          (fish 3.x swallows handler `exit`; re-raise via exec sh)
  log: preserve embedded newlines in the JSONL data field
  backup: skip .ry.bak when the symlink probe is inconclusive
          (sudo lapse) instead of copying through a possible symlink
  comments: trim lock, backup, and sysctl rationale notes

7.85.1 (2026-07-01)
-------------------
  udev: EPP rule never fired (SUBSYSTEM=="cpu" + DEVPATH cpufreq is
        unsatisfiable); match KERNEL=="cpu[0-9]*", write via cpu dev
  fstab: treat relatime/atime/strictatime/defaults beside conformant
         opts as rewrite triggers (row previously failed --verify)
  install-file: cap mkdir umask at 0022 via _ry_mkdir_0755 (ambient
                umask 0002 yielded 0775 dirs that --verify rejects)
  log: drop blank "ECHO: " JSONL noise from separator _echo calls
  quoting: quote nft string-match subjects, test-equality cmdsubs,
           and the regdom phase record (empty value shifted args)

7.85.0 (2026-07-01)
-------------------
  paccache: split -rk2 and -ruk0 into separate runs
  timeout: clamp RY_RUN_TIMEOUT above 9 digits to 2147483647
  lock: refuse reclaim on empty/garbage pidfile; re-verify ownership
  ntp: add RY_NO_NTP_REMEDIATION=1; record timesyncd enable in matrix
  mkinitcpio: duplicate KEY= lines resolve to last (shell-sourced)
  backup: remove pre-existing symlink at <dst>.ry.bak before cp
  nftables: move the loopback accept first
  progress: freeze on uptime read failure; never switch clock base
  cleanup: guard early-arg erase; trim comments and descriptions
  README: guard fstab restore; scope post-write restore; document
          pactree dependency and NTP remediation

7.84 (2026-07-01)
-----------------
  docs: add four section banners (85 total); no logic change

7.83.0 - 7.83.4 (2026-06-30)
----------------------------
  comments: trim; collapse sysctl rationale to one line
  docs: correct two section banners
  run: derive output-capture tail cap from head cap
  generators: reject control chars in environment.d and sysctl.d
  refactor: hoist GPU_DPM_LEVEL accepted set to _RY_DPM_LEVELS
  docs: trim exit-code list to user-visible codes (0-5, 10)

7.81.0 - 7.82.0 (2026-06-29 .. 06-30)
-------------------------------------
  validate: GPU_DPM_LEVEL against the dpm-level enum
  validate: reject ISO-3166-1 reserved COUNTRY codes
  generators: environment.d skips malformed entries, asserts count
  docs: remove firmware soft-floor advisory; add section intros

7.79.0 - 7.80.0 (2026-06-28 .. 06-29)
-------------------------------------
  kernel: raise KERNEL_MIN 6.18 -> 6.19
  nftables: add TCP 27037 to gated remote-play set
  verify: assert amd_pstate/dynamic_epp == disabled
  udev: GPU rule KERNEL=="card[0-9]*" plus DEVTYPE=="drm_minor"
  globals: SYSTEM_UPGRADED false default plus set -q guard
  preflight: gate below-floor kernel on skip-floor override
  docs: add Configuration subsections, grouped Managed Files tables

7.77.0 - 7.78.3 (2026-06-27 .. 06-28)
-------------------------------------
  refactor: collapse 12 functions to one-line form; condense README
  compat: replace fish >= 3.7 path basename with command basename
  cleanup: drop baloofilerc, _post_baloo, _kb_*, umip check fn
  docs: add UMIP Tuning Note; add two verify-section banners
  cmdline: iommu=pt -> amd_iommu=off; add _vrkm_iommu

7.73.0 - 7.76.1 (2026-06-26 .. 06-27)
-------------------------------------
  mangohud: toggle cpu_temp; restore gpu_power, text_outline, toggle
  cpupower: governor performance -> powersave
  udev: AMD P-State EPP performance -> balance_performance
  cmdline: add fsck.mode=force, fsck.repair=yes,
           processor.max_cstate=1, btusb.enable_autosuspend=n
  verify: add _vss_known_benign; add RTC writeback at sync paths
  cleanup: remove _ir_validate_repo_tier; count fatals once
  udev: rename 60-ry-perf.rules -> 99-ry-perf.rules; drop
        vm.page-cluster, vm.vfs_cache_pressure
  modprobe: add 60-ry-mt7925e.conf (disable_aspm=1), _vss_modprobe
  hooks: add */modprobe.d/* post-hook and _post_modprobe
  probes: prefix mesa soft-floor with command; guard x86-64-v4

7.71.0 - 7.71.4 (2026-06-26)
----------------------------
  validate: add _ir_validate_kernel_floor and _ir_validate_keys
  gpu: parameterize GPU_DPM_LEVEL (default auto)
  env: add PROTON_FSR4_RDNA3_UPGRADE=1, RY_REMOTE_PLAY_PORTS (off)

7.68.0 - 7.70.1 (2026-06-22 .. 06-24)
-------------------------------------
  log: guard _err VERIFY_FAIL increment with set -q
  regdom: remove /etc/conf.d/wireless-regdom
  bluetooth: ReconnectAttempts 7 -> 3; drop ReconnectIntervals
  mesa: raise soft-floor warn 25.3 -> 26.0
  refactor: extract _content_fn_for
  cmdline: remove amd_iommu=on, clearcpuid=rdseed; drop stale check

7.60.0 - 7.66.0 (2026-06-21 .. 06-22)
-------------------------------------
  verify: split WiFi runtime state into a dedicated sub-check
  mangohud: reorder fps/frametime; adjust HUD fields
  gpu: remove drirc 95-ry-radv-apu.conf (gfx1151 reports uma:1)
  bluetooth: add main.conf; enable service; add _vss_bluetooth
  network: wifi.backend=wpa_supplicant, powersave=2; mask
           modemmanager; add NM-dispatcher logging.conf
  probes: guard vercmp behind command -q
  guards: destinations 17 -> 15; hooks and file count 20 -> 18

7.59.0 and earlier
------------------
  History trimmed. See git tags for the full record.
