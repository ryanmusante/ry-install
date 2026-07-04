ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: - subsystem: imperative summary (single bullet, 72 cols).

7.88.3 (2026-07-03)
-------------------
  - logging: hoist the JSONL ISO-8601 timestamp to _RY_TS_FMT

7.88.2 (2026-07-03)
-------------------
  - comments: compress trailing notes to essentials; fix a stale note
  - docs: merge 7.87.x and 7.88.0-7.88.1 blocks; sync pins to 7.88.2

7.88.0 - 7.88.1 (2026-07-03)
----------------------------
  - guard: refuse /dev/stdin and fd-0 aliases like piped stdin
  - probes: silence vercmp stderr on the mesa soft-floor compare
  - cleanup: guard _cleanup_tmpfiles _log for pre-init signals
  - verify: normalize the modprobe section banner glyphs
  - comments: trim over-length trailing notes
  - docs: merge 7.85.x and 7.83-7.84 blocks; sync pins

7.87.0 - 7.87.8 (2026-07-01 .. 07-03)
-------------------------------------
  - install-file: loader.conf regenerates sdboot entries only
  - probes: note the pipestatus[1]-only read contract on byte reads
  - services: skip resolved/NM restarts when drop-in bytes unchanged
  - tmpfiles: PID-scope TMPDIR names + sweep globs (peer-run safe)
  - progress: uptime-base fallback freezes; never mixes epoch clock
  - packages: SYSTEM_UPGRADED from pacman -Q fingerprint, not rc
  - validate: kv/kparam validators report every missing key/token
  - install-file: format-validate content before write
  - run: replace run-overflow spill with inline overflow analysis
  - run: log elided-region diag sample (<=10 lines) + sha256/bytes
  - logs: no run-overflow dir created; nothing retained on disk
  - udev: retrigger cpu beside block so the EPP rule live-applies
  - verify: split amdgpu param pairs once; values may contain ':'
  - lock: create the state dir under umask 0077 (0700 contract)
  - args: root --check with unknown flags or positionals exits 2
  - compat: replace "$()" so the 3.6 version gate can report
  - verify: hardware/kernel-floor gates warn; deploy/check exit 3
  - nftables: drop redundant echo-reply accept (ct covers replies)
  - validate: require ipv6.disable=1 while nftables is IPv4-only
  - backup: correct _awf_make_backup description (fstab is direct)
  - cmdline: add ipv6.disable=1 (IPv6 off system-wide)
  - nftables: drop ICMPv6/NDP accepts; ruleset is IPv4-only
  - nftables: accept inbound IPv4 ping (echo-request)
  - verify: assert the ping accept in file and live ruleset
  - guard: refuse stdin execution ('Standard input' filename)
  - args: root --check beside other modes exits 2, not silent 3
  - fstab: --verify flags 'defaults' as a pending rewrite
  - run: skip separated sudo value flags in timeout bypass
  - README: sync preflight order, IPv4-only notes, uninstall steps
  - comments: trim over-length section, rationale, and code notes

7.86.0 (2026-07-01)
-------------------
  - install-file: resolve $BOOT before the sdboot vfat gate
  - nftables: require hop-limit 255 on inbound ICMPv6 ND types
  - args: glued short flags resolve first-of -h/-v in order
  - help: note --check reads live /proc/cmdline
  - README: sync version pins, glued-flag and drift notes

7.85.0 - 7.85.3 (2026-07-01)
----------------------------
  - check: root --check is silent exit 3; other modes keep exit 2
  - signal: propagate 128+N on INT/TERM/HUP/ABRT (exec re-raise)
  - udev: EPP rule never fired; match KERNEL=="cpu[0-9]*"
  - fstab: atime-variant opts beside conformant rows trigger rewrite
  - install-file: cap mkdir umask at 0022 via _ry_mkdir_0755
  - lock: refuse reclaim on empty/garbage pidfile; re-verify owner
  - backup: skip .ry.bak on inconclusive probe; drop symlink first
  - paccache: split -rk2 and -ruk0 into separate runs
  - timeout: clamp RY_RUN_TIMEOUT above 9 digits to 2147483647
  - ntp: add RY_NO_NTP_REMEDIATION=1; log timesyncd enable
  - mkinitcpio: duplicate KEY= lines resolve to last (shell-sourced)
  - nftables: move the loopback accept first
  - progress: freeze on uptime read failure; never switch clock base
  - log: preserve embedded newlines in JSONL; drop blank ECHO noise
  - quoting: quote nft subjects, test cmdsubs, regdom record
  - cleanup: guard early-arg erase; trim comments and descriptions
  - README: 100-col tables; fstab restore scope; pactree/NTP notes

7.83.0 - 7.84 (2026-06-30 .. 07-01)
-----------------------------------
  - run: derive output-capture tail cap from head cap
  - generators: reject control chars in environment.d and sysctl.d
  - refactor: hoist GPU_DPM_LEVEL accepted set to _RY_DPM_LEVELS
  - comments: trim; collapse sysctl rationale to one line
  - docs: correct two banners; add four (85 total); trim exit codes

7.81.0 - 7.82.0 (2026-06-29 .. 06-30)
-------------------------------------
  - validate: GPU_DPM_LEVEL against the dpm-level enum
  - validate: reject ISO-3166-1 reserved COUNTRY codes
  - generators: environment.d skips malformed entries, asserts count
  - docs: remove firmware soft-floor advisory; add section intros

7.79.0 - 7.80.0 (2026-06-28 .. 06-29)
-------------------------------------
  - kernel: raise KERNEL_MIN 6.18 -> 6.19
  - nftables: add TCP 27037 to gated remote-play set
  - verify: assert amd_pstate/dynamic_epp == disabled
  - udev: GPU rule KERNEL=="card[0-9]*" plus DEVTYPE=="drm_minor"
  - globals: SYSTEM_UPGRADED false default plus set -q guard
  - preflight: gate below-floor kernel on skip-floor override
  - docs: add Configuration subsections, grouped Managed Files tables

7.77.0 - 7.78.3 (2026-06-27 .. 06-28)
-------------------------------------
  - refactor: collapse 12 functions to one-line form; condense README
  - compat: replace fish >= 3.7 path basename with command basename
  - cleanup: drop baloofilerc, _post_baloo, _kb_*, umip check fn
  - docs: add UMIP Tuning Note; add two verify-section banners
  - cmdline: iommu=pt -> amd_iommu=off; add _vrkm_iommu

7.73.0 - 7.76.1 (2026-06-26 .. 06-27)
-------------------------------------
  - mangohud: toggle cpu_temp; restore gpu_power, text_outline, toggle
  - cpupower: governor performance -> powersave
  - udev: AMD P-State EPP performance -> balance_performance
  - cmdline: fsck force/repair, max_cstate=1, btusb autosuspend=n
  - verify: add _vss_known_benign; add RTC writeback at sync paths
  - cleanup: remove _ir_validate_repo_tier; count fatals once
  - udev: 60->99-ry-perf.rules; drop page-cluster, vfs_cache_pressure
  - modprobe: add 60-ry-mt7925e.conf (disable_aspm=1), _vss_modprobe
  - hooks: add */modprobe.d/* post-hook and _post_modprobe
  - probes: prefix mesa soft-floor with command; guard x86-64-v4

7.71.0 - 7.71.4 (2026-06-26)
----------------------------
  - validate: add _ir_validate_kernel_floor and _ir_validate_keys
  - gpu: parameterize GPU_DPM_LEVEL (default auto)
  - env: add PROTON_FSR4_RDNA3_UPGRADE=1, RY_REMOTE_PLAY_PORTS (off)

7.68.0 - 7.70.1 (2026-06-22 .. 06-24)
-------------------------------------
  - log: guard _err VERIFY_FAIL increment with set -q
  - regdom: remove /etc/conf.d/wireless-regdom
  - bluetooth: ReconnectAttempts 7 -> 3; drop ReconnectIntervals
  - mesa: raise soft-floor warn 25.3 -> 26.0
  - refactor: extract _content_fn_for
  - cmdline: remove amd_iommu=on, clearcpuid=rdseed; drop stale check

7.60.0 - 7.66.0 (2026-06-21 .. 06-22)
-------------------------------------
  - verify: split WiFi runtime state into a dedicated sub-check
  - mangohud: reorder fps/frametime; adjust HUD fields
  - gpu: remove drirc 95-ry-radv-apu.conf (gfx1151 reports uma:1)
  - bluetooth: add main.conf; enable service; add _vss_bluetooth
  - net: wpa_supplicant, powersave=2, NM log; mask modemmanager
  - probes: guard vercmp behind command -q
  - guards: destinations 17 -> 15; hooks and file count 20 -> 18

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
