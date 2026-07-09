ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: - subsystem: imperative summary (single bullet, 72 cols).

7.98.0 (2026-07-09)
-------------------
  - env: drop the RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK override; the
    KERNEL_MIN (>= 6.19) gate is now unconditional for deploy and
    --check (--verify still warns only)
  - docs: remove the override from --help, the README kernel row,
    and the README environment table

7.97.3 (2026-07-08)
-------------------
  - verify: pacman.conf inspection gains a sudo read fallback plus
    grep-error and sudo-lapse gates — a perms-hardened (0600) conf
    now reports "inspection skipped" instead of a false "not set"

7.97.2 (2026-07-08)
-------------------
  - docs: trim in-script comments to essential rationale; no
    functional change
  - docs: compact the 7.97.1 changelog entry

7.97.1 (2026-07-08)
-------------------
  - env: honor NO_COLOR again (no-color.org); document in --help
    and the README environment table
  - data: derive _RY_BACKUP_TARGETS from _RY_BOOT_CRITICAL_DSTS
  - verify: Vulkan check reuses the installed list from argv;
    drop a second pacman -Qq and dead guard branches
  - cleanup: hoist the systemd-version probe in _post_udev; move
    _set_exit beside bail primitives; note _installed_bytes
    text-only contract

7.97.0 (2026-07-08)
-------------------
  - env: drop the NO_COLOR, TMPDIR, and RY_NO_NTP_REMEDIATION
    overrides; tmp root pinned to /tmp, color gates on TERM+tty,
    NTP remediation always runs when the clock is unsynced
  - verify: _ry_mkinitcpio_array joins multi-line KEY=( ... )
    assignments (last wins); the HOOKS syntax check reuses it,
    dropping a duplicate awk extractor
  - run: fold tmpdir redaction to the pinned /tmp pattern
  - docs: trim the environment table to the three remaining vars
  - comments: single-line pass; verbose inline rationale trimmed

7.96.6 (2026-07-08)
-------------------
  - cleanup: inline the single-caller _unit_state, _fail_no_count,
    and _awf_is_backup_target wrappers; drop the _kconfig_cache
    output path (its sole caller discarded it)
  - cleanup: fold the eight mkinitcpio-abort SKIP rows and the
    signal exit-code switch into table-driven loops
  - cleanup: add _taint for the paired error/boot-taint flags (six
    sites); drop the redundant _RY_PKG_REMOVE_SKIPS pre-init and
    four _chk_grep label args that repeated the pattern (the label
    already defaults to it)

7.96.0 - 7.96.5 (2026-07-07 .. 07-08)
-------------------------------------
  - services: mask avahi-daemon.service + .socket (MASK 10 -> 12);
    a second mDNS responder beside resolved advertised a colliding
    hostname-2.local (profile runs MulticastDNS=no)
  - validate: gate every KERNEL_PARAMS token against the
    [A-Za-z0-9._,=-] charset; tokens splice into the shell-sourced
    LINUX_OPTIONS="..." value and /etc/kernel/cmdline
  - validate: drop the dead KERNEL_PARAMS metachar re-sweep — the
    charset gate already excludes every shell metachar
  - backup: add /etc/kernel/cmdline and /etc/sdboot-manage.conf to
    _RY_BACKUP_TARGETS (2 -> 4); all four boot-critical files now
    get .ry.bak plus post-write byte-verify/restore
  - files: pre-validate rendered /etc/nftables.conf with nft -c -f
    against the staged tmpfile before commit; an invalid ruleset
    refuses deploy with live ruleset and installed file unchanged
  - services: deduplicate the live input-policy-drop probe into
    _nft_input_drop_live (--check + verify paths; 3 copies -> 1)
  - probes: replace three builtin->pipe captures (ntsync kconfig,
    dmesg preempt scan, findmnt error excerpt) with list
    membership, string match, and slicing; an early-exiting pipe
    reader could SIGPIPE the shell
  - lock: set the mkdir-success flag beside the rc capture; closes
    the signal window that could strand an unreleasable lock dir
  - cli: repeated --install-file flags resolve last-wins instead of
    space-joining the argparse list into a bogus path
  - log: rename via mv -T (cp -pT recovery) so a directory squatting
    on the target name cannot swallow the JSONL log
  - run: add -h (host form) to the sudo value-flag skip list used
    for long-op timeout classification
  - preflight: sudo-cache banner suggests a scoped NOPASSWD drop-in
    (pacman/mkinitcpio/sdboot-manage/systemctl) instead of ALL
  - docs: record known issue — the mkinitcpio shutdown-ramfs
    generator unit can fail at shutdown on CachyOS installs
    (upstream unit interaction; not remediated in-tree)
  - docs: README structure pass — Safety/Usage/Globals tables, the
    four-file .ry.bak uninstall wording, unified GiB units

7.95.0 - 7.95.2 (2026-07-07)
----------------------------
  - dispatch: hoist the argparse option spec into one
    _RY_ARGPARSE_SPEC global (root-guard + main parsers) with a
    count tripwire; three verbatim copies removed
  - install-file: log POST_HOOK_NONE when a changed destination
    matches no _RY_POST_HOOKS pattern (skip was silent)
  - preflight: validate vercmp output before the mesa soft-floor
    compare; empty/non-numeric output logs and skips
  - docs: trim README to essentials; per-variable environment
    table; fstab symlink-abort, ntsync levels, and RY_RUN_TIMEOUT
    clamp notes aligned with the code

7.94.0 - 7.94.5 (2026-07-06 .. 07-07)
-------------------------------------
  - udev: fix GPU rule key DEVTYPE -> ENV{DEVTYPE} (was rejected as
    an invalid key; GPU clock-floor rule never applied)
  - modprobe: blacklist amdxdna; XDNA NPU needs the IOMMU and
    probes -ENODEV (ret -19) under amd_iommu=off; 17 -> 18 files
  - cmdline: clearcpuid=514 -> clearcpuid=umip; string form is
    stable across kernels (numeric bit is not)
  - kernel: re-scope KERNEL_MIN 6.19 rationale to gfx1151 MES-0x86
    amdgpu; RTL8127 base lands 6.16, hang fix 6.18 (below floor)
  - lock: use USER_HZ=100 not CONFIG_HZ for PID starttime when
    getconf is absent; starttime unit is USER_HZ, not kernel tick
  - preflight: hard-require find(1) in all modes; add
    CPUPOWER_GOVERNOR to the sourced-scalar metachar refuse gate
  - preflight: report mktemp allocation failure distinctly from a
    missing mv -T capability in the coreutils probe
  - run: long-op timeout resolver emits 0 when RY_RUN_TIMEOUT=0
    instead of empty output; consumers unchanged
  - rootguard: emit leftover positionals one @@LEFT@@ line each and
    append raw marker lines, so arguments containing spaces survive
    intact in the usage error (root refusal path only)
  - verify: extract _resolve_boot_fstype; both perm-check subs
    share one $BOOT-fstype resolver
  - comments: correct "-Rns -s" to "-Rns" in the pactree and
    asexplicit rationales; trim nine verbose inline comments
  - docs: mirror the -Rns wording; drop duplicate REMOVE_EXISTING
    gloss; link Globals to Safety

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
