ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: - subsystem: imperative summary (single bullet, 72 cols).

7.91.3 (2026-07-05)
-------------------
  - docs: correct ntsync note — /dev/ntsync is reported (warn) by
    --verify only, not in preflight
  - docs: clarify uninstall — loader.conf and mkinitcpio.conf carry
    .ry.bak; /etc/kernel/cmdline is reverted by hand
  - verify: refresh stale fn descriptions (drop ntsync/clocksource/
    TCP/ZRAM; add modprobe) from the 7.90.0 sub-check removals
  - version: sync script header, VERSION global, README pins
    7.91.2 -> 7.91.3

7.91.2 (2026-07-05)
-------------------
  - docs: trim README/CHANGELOG prose to vital form; all 18 tables
    preserved verbatim
  - script: condense verbose comments to single-line vital form
  - size: correct stale count; script is 4965 lines / 288 functions
  - version: sync script header, VERSION global, README pins
    7.91.1 -> 7.91.2

7.91.1 (2026-07-05)
-------------------
  - packages: add pacman-contrib, archlinux-contrib; mark every
    PKGS_ADD member explicit after -Syu (pacman -D --asexplicit) so
    -Rns -s can't orphan pactree/paccache/checkservices; 17 -> 19
  - validate: note _ir_validate_counts literals as independent drift
    tripwires (never derive a count from the array it guards)
  - mangohud: annotate the disabled cpu_temp line as intentional

7.91.0 (2026-07-04)
-------------------
  - mangohud: reorder gpu_temp before gpu_core_clock; comment out
    cpu_temp; add cpu_power readout (~/.config/MangoHud/MangoHud.conf)

7.90.0 (2026-07-04)
-------------------
  - verify: fold Vulkan-package check into _vsp_required (ports the
    pacman-db-lock guard); drop _vre_tcp, _vre_zram,
    _vss_ntsync_modules, _vrkm_iommu, _vrk_clocksource, and the
    _RY_DMESG_TSC cache
  - verify: amd_iommu/tsc effect-correlations retired; directive still
    asserted at config + live-cmdline layers (README AMD-Vi note synced)
  - size: script 5080 -> 4951 lines (294 -> 288 functions)

7.89.0 (2026-07-04)
-------------------
  - args: root guard defers to argparse; invalid args exit 2 with
    the same usage message whether or not the run is rooted
  - docs: sync version pins; note argument-message parity

7.88.0 - 7.88.3 (2026-07-03)
----------------------------
  - guard: refuse /dev/stdin and fd-0 aliases like piped stdin
  - logging: hoist the JSONL ISO-8601 timestamp to _RY_TS_FMT
  - cleanup: guard _cleanup_tmpfiles _log for pre-init signals
  - probes: silence vercmp stderr on the mesa soft-floor compare
  - verify: normalize the modprobe section banner glyphs

7.87.0 - 7.87.8 (2026-07-01 .. 07-03)
-------------------------------------
  - install-file: format-validate content before write; loader.conf
    regenerates sdboot entries only
  - run: replace overflow spill with inline analysis; log elided
    sample (<=10 lines) + sha256/bytes; nothing retained on disk
  - packages: SYSTEM_UPGRADED from pacman -Q fingerprint, not rc
  - services: skip resolved/NM restarts when drop-in bytes unchanged
  - tmpfiles: PID-scope TMPDIR names + sweep globs (peer-run safe)
  - validate: kv/kparam validators report every missing key/token
  - verify: hardware/kernel-floor gates warn; deploy/check exit 3
  - cmdline: add ipv6.disable=1; nftables ruleset is IPv4-only
  - nftables: accept inbound IPv4 ping; drop ICMPv6/NDP accepts
  - args: root --check with unknown flags or positionals exits 2
  - guard: refuse stdin execution ('Standard input' filename)
  - lock: create the state dir under umask 0077 (0700 contract)
  - udev: retrigger cpu beside block so the EPP rule live-applies

7.85.0 - 7.86.0 (2026-07-01)
----------------------------
  - install-file: resolve $BOOT before the sdboot vfat gate
  - check: root --check is silent exit 3; other modes keep exit 2
  - signal: propagate 128+N on INT/TERM/HUP/ABRT (exec re-raise)
  - udev: EPP rule match KERNEL=="cpu[0-9]*" (never fired before)
  - fstab: atime-variant opts beside conformant rows trigger rewrite
  - lock: refuse reclaim on empty/garbage pidfile; re-verify owner
  - backup: skip .ry.bak on inconclusive probe; drop symlink first
  - timeout: clamp RY_RUN_TIMEOUT above 9 digits to 2147483647
  - ntp: add RY_NO_NTP_REMEDIATION=1; log timesyncd enable
  - args: glued short flags resolve first-of -h/-v in order

7.79.0 - 7.84.0 (2026-06-28 .. 07-01)
-------------------------------------
  - kernel: raise KERNEL_MIN 6.18 -> 6.19
  - generators: reject control chars in environment.d and sysctl.d;
    skip malformed entries and assert count
  - validate: GPU_DPM_LEVEL against the dpm-level enum; reject
    ISO-3166-1 reserved COUNTRY codes
  - run: derive output-capture tail cap from head cap
  - verify: assert amd_pstate/dynamic_epp == disabled
  - udev: GPU rule KERNEL=="card[0-9]*" plus DEVTYPE=="drm_minor"
  - nftables: add TCP 27037 to gated remote-play set

7.71.0 - 7.78.3 (2026-06-26 .. 06-28)
-------------------------------------
  - refactor: collapse functions to one-line form; extract
    _content_fn_for; drop baloofilerc, _post_baloo, _kb_*, umip fn
  - cmdline: iommu=pt -> amd_iommu=off; fsck force/repair,
    max_cstate=1, btusb autosuspend=n; add _vrkm_iommu
  - modprobe: add 60-ry-mt7925e.conf (disable_aspm=1); add hook
  - cpupower: governor performance -> powersave
  - udev: AMD P-State EPP performance -> balance_performance;
    60->99-ry-perf.rules
  - env: add PROTON_FSR4_RDNA3_UPGRADE=1, RY_REMOTE_PLAY_PORTS (off)
  - validate: add _ir_validate_kernel_floor and _ir_validate_keys
  - compat: replace fish >= 3.7 path basename with command basename

7.60.0 - 7.70.1 (2026-06-21 .. 06-24)
-------------------------------------
  - bluetooth: add main.conf; enable service; ReconnectAttempts 3
  - net: wpa_supplicant, powersave=2, NM log; mask modemmanager
  - gpu: remove drirc and radv-apu overrides (gfx1151 reports uma:1)
  - verify: split WiFi runtime state into a dedicated sub-check
  - regdom: remove /etc/conf.d/wireless-regdom
  - mesa: raise soft-floor warn 25.3 -> 26.0
  - guards: destinations 17 -> 15; hooks and file count 20 -> 18

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
