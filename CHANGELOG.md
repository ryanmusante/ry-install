ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: - subsystem: imperative summary (single bullet, 72 cols).

7.98.3 (2026-07-09)
-------------------
  - docs: drop the Known-Benign Log Lines table from the README

7.98.2 (2026-07-09)
-------------------
  - verify: compare the live COMPRESSION= value against
    MKINITCPIO_COMPRESSION instead of a zstd literal; editing the
    global no longer trips a false MISSING
  - data: hoist the EPP hint and the scaling-driver expectation
    into EPP_PREFERENCE / EXPECTED_SCALING_DRIVER; enum-gate EPP
    (spliced into a udev ATTR) and charset-gate CPUPOWER_GOVERNOR
    to the domain the cpupower format validator accepts
  - docs: credit pactree/paccache to pacman-contrib alone and note
    archlinux-contrib is script-unused; document the root --check
    silent exit 3 and the interactive sudo -v prompt; add a BIOS
    section (85 W flat-PPT SMU profile + reference-repo link)

7.98.0 - 7.98.1 (2026-07-09)
----------------------------
  - verify: strip inline comments before the file-content token
    match; a token inside a trailing comment no longer reads present
  - preflight: require id(1) in the dependency gate
  - verify: quote the GPU_DPM_LEVEL sysfs comparison
  - env: drop the RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK override; the
    KERNEL_MIN (>= 6.19) gate is unconditional for deploy/--check
    (--verify still warns only)
  - docs: drop the override from --help and the README; normalize
    the README known-benign table; merge changelog series entries
    and trim wrapped bullets

7.97.0 - 7.97.3 (2026-07-08)
----------------------------
  - verify: pacman.conf inspection gains a sudo read fallback plus
    grep-error/sudo-lapse gates; a 0600 conf reports "inspection
    skipped" instead of a false "not set"
  - verify: Vulkan check reuses the installed list from argv; drop
    a second pacman -Qq and dead guard branches
  - verify: _ry_mkinitcpio_array joins multi-line KEY=( ... )
    blocks (last wins); HOOKS syntax check reuses it
  - env: drop the NO_COLOR, TMPDIR, and RY_NO_NTP_REMEDIATION
    overrides, then restore NO_COLOR support (no-color.org); tmp
    root pinned to /tmp; NTP remediation always runs when unsynced
  - data: derive _RY_BACKUP_TARGETS from _RY_BOOT_CRITICAL_DSTS
  - run: fold tmpdir redaction to the pinned /tmp pattern
  - cleanup: hoist the _post_udev systemd probe; move _set_exit
    beside the bail primitives; note _installed_bytes text-only
  - docs: single-line comment pass; trim the environment table

7.96.0 - 7.96.6 (2026-07-07 .. 07-08)
-------------------------------------
  - services: mask avahi-daemon .service + .socket (MASK 10 -> 12);
    a second mDNS responder advertised a colliding hostname-2.local
  - validate: gate KERNEL_PARAMS tokens to [A-Za-z0-9._,=-]; drop
    the dead metachar re-sweep the charset already covers
  - backup: .ry.bak + post-write byte-verify/restore for all four
    boot-critical files (2 -> 4)
  - files: pre-validate rendered /etc/nftables.conf with nft -c
    before commit; an invalid ruleset refuses deploy unchanged
  - services: deduplicate the live input-drop probe into
    _nft_input_drop_live (3 copies -> 1)
  - probes: replace three builtin->pipe captures with list/match/
    slice; an early-exiting pipe reader could SIGPIPE the shell
  - lock: set the mkdir-success flag beside the rc capture; closes
    a signal window that could strand the lock dir
  - cli: repeated --install-file flags resolve last-wins instead of
    space-joining into a bogus path
  - log: rename via mv -T (cp -pT recovery) so a directory squat
    cannot swallow the JSONL log
  - run: add -h (host form) to the sudo value-flag skip list
  - preflight: sudo banner suggests a scoped NOPASSWD drop-in, not
    ALL
  - cleanup: inline single-caller wrappers; table-drive the
    mkinitcpio SKIP rows and signal switch; add _taint (six sites)
  - docs: record the shutdown-ramfs known issue; README structure
    pass (Safety/Usage/Globals tables, GiB units)

7.95.0 - 7.95.2 (2026-07-07)
----------------------------
  - dispatch: hoist the argparse spec into one _RY_ARGPARSE_SPEC
    global with a count tripwire; three verbatim copies removed
  - install-file: log POST_HOOK_NONE when a changed destination
    matches no _RY_POST_HOOKS pattern
  - preflight: validate vercmp output before the mesa soft-floor
    compare; empty/non-numeric logs and skips
  - docs: trim README to essentials; align fstab symlink-abort,
    ntsync levels, and RY_RUN_TIMEOUT clamp notes with the code

7.94.0 - 7.94.5 (2026-07-06 .. 07-07)
-------------------------------------
  - udev: fix GPU rule key DEVTYPE -> ENV{DEVTYPE}; the clock-floor
    rule was rejected and never applied
  - modprobe: blacklist amdxdna; the XDNA NPU probes -ENODEV under
    amd_iommu=off (17 -> 18 files)
  - cmdline: clearcpuid=514 -> clearcpuid=umip; the string form is
    stable across kernels
  - kernel: re-scope the KERNEL_MIN 6.19 rationale to gfx1151
    MES-0x86 amdgpu (RTL8127 and the hang fix land below the floor)
  - lock: use USER_HZ=100, not CONFIG_HZ, for PID starttime when
    getconf is absent
  - preflight: hard-require find(1); gate CPUPOWER_GOVERNOR through
    the sourced-scalar metachar refusal
  - preflight: report mktemp failure distinctly from a missing
    mv -T capability
  - run: the long-op resolver emits 0 for RY_RUN_TIMEOUT=0 instead
    of empty output
  - rootguard: emit leftover positionals one @@LEFT@@ line each so
    spaced arguments survive the usage error intact
  - verify: extract _resolve_boot_fstype; both perm-check subs
    share one $BOOT-fstype resolver
  - docs: correct "-Rns -s" to "-Rns"; trim nine verbose inline
    comments; link Globals to Safety

7.93.0 (2026-07-05)
-------------------
  - profile: rename internal token gtr_pro -> gtr9_pro

7.90.0 - 7.92.4 (2026-07-04 .. 07-05)
-------------------------------------
  - run: hard-cap long pkg/boot/db ops at 7200s (0 still disables;
    above-cap values honored); resolve cmd via PATH first
  - validate: gate boot-crit scalars + COMPRESSION_OPTIONS against
    the metachar/flag class; mkinitcpio skeleton + :2 tripwire
  - mkinitcpio: emit COMPRESSION_OPTIONS via string join
  - metachar: use PCRE \x27 for quote; drop the fragile requote
  - packages: add pacman-contrib, archlinux-contrib (17 -> 19);
    mark PKGS_ADD explicit post-Syu (pactree/paccache rationale)
  - mangohud: reorder gpu_temp before gpu_core_clock; comment out
    cpu_temp; add cpu_power
  - resolve_esp: note the /boot/EFI subdir skip on ext4 /boot
  - cleanup: db.lck grace reaps only -P $fish_pid descendants
  - comments: move standalone rationale inline; strip apostrophes
  - verify: fold the Vulkan check into _vsp_required; retire the
    amd_iommu/tsc correlations; drop 6 stale functions
  - docs: sync README/help/pins; correct the ntsync note (warn via
    --verify, not preflight)

7.89.0 (2026-07-04)
-------------------
  - args: root guard defers to argparse; invalid args exit 2 with
    the same usage message rooted or not

7.87.0 - 7.88.3 (2026-07-01 .. 07-03)
-------------------------------------
  - guard: refuse stdin/pipe exec (/dev/stdin, fd-0, stdin name)
  - install-file: format-validate content before write; loader.conf
    regenerates sdboot entries only
  - run: replace overflow spill with inline analysis; log elided
    sample (<=10 lines) + sha256/bytes; nothing retained on disk
  - cmdline: add ipv6.disable=1; nftables ruleset IPv4-only, accept
    inbound IPv4 ping, drop ICMPv6/NDP accepts
  - packages: SYSTEM_UPGRADED from a pacman -Q fingerprint, not rc
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
  - ntp: add RY_NO_NTP_REMEDIATION=1; log the timesyncd enable
  - args: glued short flags resolve first-of -h/-v in order

7.79.0 - 7.84.0 (2026-06-28 .. 07-01)
-------------------------------------
  - kernel: raise KERNEL_MIN 6.18 -> 6.19
  - generators: reject control chars in environment.d and sysctl.d;
    skip malformed entries and assert count
  - validate: GPU_DPM_LEVEL against the dpm-level enum; reject
    ISO-3166-1 reserved COUNTRY codes
  - run: derive the output-capture tail cap from the head cap
  - verify: assert amd_pstate/dynamic_epp == disabled
  - udev: GPU rule KERNEL=="card[0-9]*" plus DEVTYPE=="drm_minor"
  - nftables: add TCP 27037 to the gated remote-play set

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
  - mesa: raise the soft-floor warn 25.3 -> 26.0
  - guards: destinations 17 -> 15; hooks and file count 20 -> 18

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
