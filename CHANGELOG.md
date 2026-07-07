ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: - subsystem: imperative summary (single bullet, 72 cols).

7.94.2 (2026-07-07)
-------------------
  - cmdline: clearcpuid=514 -> clearcpuid=umip; string form is stable
    across kernels (numeric bit is not) -- same UMIP disable
  - kernel: re-scope KERNEL_MIN 6.19 rationale to gfx1151 MES-0x86
    amdgpu; RTL8127 r8169 base lands 6.16, hang fix 6.18 (below floor)
  - modprobe: correct amdxdna probe errno -EINVAL -> -ENODEV (ret -19)
    in the blacklist comment (behavior unchanged)

7.94.1 (2026-07-06)
-------------------
  - verify: extract _resolve_boot_fstype; both perm-check subs share
    one $BOOT-fstype resolver (behavior unchanged)
  - docs: drop duplicate REMOVE_EXISTING gloss; link Globals to Safety

7.94.0 (2026-07-06)
-------------------
  - udev: fix GPU rule key DEVTYPE -> ENV{DEVTYPE} (was rejected as an
    invalid key; GPU clock-floor rule never applied)
  - modprobe: blacklist amdxdna; XDNA NPU needs the IOMMU and probes
    with -EINVAL under amd_iommu=off (NPU unused); 17 -> 18 files

7.93.0 (2026-07-05)
-------------------
  - profile: rename internal token gtr_pro -> gtr9_pro

7.90.0 - 7.92.4 (2026-07-04 .. 07-05)
-------------------------------------
  - run: hard-cap long pkg/boot/db ops at 7200s (RY_RUN_TIMEOUT=0 still
    disables; a value above cap honored); resolve cmd via PATH first
  - validate: gate boot-crit scalars + COMPRESSION_OPTIONS against the
    metachar/flag class; add mkinitcpio.conf skeleton + :2 tripwire
  - mkinitcpio: emit COMPRESSION_OPTIONS via string join (identical)
  - metachar: use PCRE \x27 for quote, dropping fragile fish requote
  - packages: add pacman-contrib, archlinux-contrib (17 -> 19); mark
    PKGS_ADD explicit post-Syu; correct rationale (pactree/paccache use)
  - mangohud: reorder gpu_temp before gpu_core_clock; comment out
    cpu_temp; add cpu_power readout
  - resolve_esp: note /boot/EFI subdir skip on ext4 /boot
  - cleanup: db.lck grace reaps only -P $fish_pid descendants
  - comments: move standalone rationale inline; strip apostrophes
  - verify: fold Vulkan check into _vsp_required; retire amd_iommu/tsc
    correlations (still at config + live-cmdline); drop 6 stale fns
  - docs: sync README/help/pins; correct ntsync note (warn via --verify,
    not preflight); trim prose, all 18 tables verbatim

7.89.0 (2026-07-04)
-------------------
  - args: root guard defers to argparse; invalid args exit 2 with the
    same usage message whether or not the run is rooted

7.87.0 - 7.88.3 (2026-07-01 .. 07-03)
-------------------------------------
  - guard: refuse stdin/pipe exec (/dev/stdin, fd-0, 'Standard input')
  - install-file: format-validate content before write; loader.conf
    regenerates sdboot entries only
  - run: replace overflow spill with inline analysis; log elided sample
    (<=10 lines) + sha256/bytes; nothing retained on disk
  - cmdline: add ipv6.disable=1; nftables ruleset IPv4-only, accept
    inbound IPv4 ping, drop ICMPv6/NDP accepts
  - packages: SYSTEM_UPGRADED from pacman -Q fingerprint, not rc
  - services: skip resolved/NM restarts when drop-in bytes unchanged
  - tmpfiles: PID-scope TMPDIR names + sweep globs (peer-run safe)
  - validate: kv/kparam validators report every missing key/token
  - verify: hardware/kernel-floor gates warn; deploy/check exit 3
  - args: root --check with unknown flags or positionals exits 2
  - lock: create the state dir under umask 0077 (0700 contract)
  - udev: retrigger cpu beside block so the EPP rule live-applies
  - logging: hoist the JSONL ISO-8601 timestamp to _RY_TS_FMT
  - probes: silence vercmp stderr on the mesa soft-floor compare

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
