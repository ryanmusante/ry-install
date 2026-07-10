ry-install release notes
=========================

Newest first. Versioning is MAJOR.MINOR.PATCH.
Format: - subsystem: imperative summary (single bullet, 72 cols).

7.98.4 (2026-07-09)
-------------------
  - docs: condense the BIOS section; trim README prose and tables
  - changelog: trim wrapped bullets across historical entries

7.98.3 (2026-07-09)
-------------------
  - docs: drop the Known-Benign Log Lines README table

7.98.2 (2026-07-09)
-------------------
  - verify: compare live COMPRESSION= to MKINITCPIO_COMPRESSION,
    not a zstd literal
  - data: hoist EPP_PREFERENCE + EXPECTED_SCALING_DRIVER; enum-gate
    EPP; align CPUPOWER_GOVERNOR charset with its validator
  - docs: pactree/paccache credit to pacman-contrib; note root
    --check exit 3 and the TTY sudo -v prompt; add BIOS section

7.98.0 - 7.98.1 (2026-07-09)
----------------------------
  - verify: strip inline comments before the token match
  - preflight: require id(1) in the dependency gate
  - verify: quote the GPU_DPM_LEVEL sysfs comparison
  - env: drop RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK; the 6.19 floor
    is unconditional for deploy/--check (--verify warns)
  - docs: drop the override from --help/README; merge changelog
    series entries

7.97.0 - 7.97.3 (2026-07-08)
----------------------------
  - verify: pacman.conf sudo-read fallback + grep/lapse gates
  - verify: Vulkan check reuses the argv installed list
  - verify: _ry_mkinitcpio_array joins multi-line KEY=( ) blocks
  - env: drop NO_COLOR/TMPDIR/RY_NO_NTP_REMEDIATION overrides,
    then restore NO_COLOR; pin tmp to /tmp; NTP always remediates
  - data: derive _RY_BACKUP_TARGETS from _RY_BOOT_CRITICAL_DSTS
  - run: fold tmpdir redaction to the pinned /tmp pattern
  - cleanup: hoist the _post_udev probe; move _set_exit; note
    _installed_bytes text-only
  - docs: single-line comment pass; trim the environment table

7.96.0 - 7.96.6 (2026-07-07 .. 07-08)
-------------------------------------
  - services: mask avahi-daemon .service+.socket (MASK 10 -> 12)
  - validate: KERNEL_PARAMS charset [A-Za-z0-9._,=-]
  - backup: .ry.bak + post-write verify/restore for all 4 boot
    files
  - files: nft -c pre-validate /etc/nftables.conf before commit
  - services: dedupe the live input-drop probe
  - probes: drop builtin->pipe captures (SIGPIPE risk)
  - lock: set the mkdir-success flag beside the rc capture
  - cli: repeated --install-file resolves last-wins
  - log: rename via mv -T with cp -pT recovery (dir-squat safe)
  - run: add -h (host form) to the sudo value-flag skip list
  - preflight: sudo banner suggests scoped NOPASSWD, not ALL
  - cleanup: inline single-caller wrappers; add _taint
  - docs: shutdown-ramfs known issue; README structure pass

7.95.0 - 7.95.2 (2026-07-07)
----------------------------
  - dispatch: single _RY_ARGPARSE_SPEC global + count tripwire
  - install-file: log POST_HOOK_NONE on unmatched hook pattern
  - preflight: validate vercmp output before the mesa compare
  - docs: trim README; align fstab/ntsync/RY_RUN_TIMEOUT notes

7.94.0 - 7.94.5 (2026-07-06 .. 07-07)
-------------------------------------
  - udev: GPU rule DEVTYPE -> ENV{DEVTYPE}; rule never applied
  - modprobe: blacklist amdxdna (-ENODEV under amd_iommu=off)
  - cmdline: clearcpuid=514 -> clearcpuid=umip (version-stable)
  - kernel: re-scope the 6.19 floor rationale to gfx1151 MES-0x86
  - lock: USER_HZ=100 fallback for PID starttime
  - preflight: hard-require find(1); metachar-gate the governor
  - preflight: report mktemp failure distinctly from mv -T
  - run: long-op resolver emits 0 for RY_RUN_TIMEOUT=0
  - rootguard: one @@LEFT@@ line per leftover positional
  - verify: extract the shared _resolve_boot_fstype
  - docs: correct "-Rns -s" to "-Rns"; trim inline comments

7.93.0 (2026-07-05)
-------------------
  - profile: rename gtr_pro -> gtr9_pro

7.90.0 - 7.92.4 (2026-07-04 .. 07-05)
-------------------------------------
  - run: hard-cap long pkg/boot/db ops at 7200s; resolve via PATH
  - validate: metachar-gate boot scalars + COMPRESSION_OPTIONS
  - mkinitcpio: emit COMPRESSION_OPTIONS via string join
  - metachar: PCRE \x27 for quote; drop the fragile requote
  - packages: add pacman-contrib + archlinux-contrib (17 -> 19);
    mark PKGS_ADD explicit post-Syu
  - mangohud: reorder gpu_temp; comment cpu_temp; add cpu_power
  - resolve_esp: note the /boot/EFI subdir skip on ext4 /boot
  - cleanup: db.lck grace reaps only -P $fish_pid descendants
  - comments: move standalone rationale inline; strip apostrophes
  - verify: fold Vulkan into _vsp_required; drop 6 stale functions
  - docs: sync README/help/pins; correct the ntsync note

7.89.0 (2026-07-04)
-------------------
  - args: root guard defers to argparse; invalid args exit 2

7.87.0 - 7.88.3 (2026-07-01 .. 07-03)
-------------------------------------
  - guard: refuse stdin/pipe execution
  - install-file: format-validate before write; loader.conf
    regenerates sdboot entries only
  - run: inline overflow analysis (sha256 + <=10 sampled lines)
  - cmdline: add ipv6.disable=1; IPv4-only ruleset, inbound ping
  - packages: SYSTEM_UPGRADED from a pacman -Q fingerprint
  - services: skip resolved/NM restarts on unchanged drop-ins
  - tmpfiles: PID-scoped names + sweep globs
  - validate: kv/kparam validators report every missing token
  - verify: hardware/kernel gates warn; deploy/check exit 3
  - args: root --check with unknown flags exits 2
  - lock: create the state dir under umask 0077
  - udev: retrigger cpu beside block (EPP live-apply)
  - logging: hoist the JSONL timestamp to _RY_TS_FMT
  - probes: silence vercmp stderr on the mesa compare

7.85.0 - 7.86.0 (2026-07-01)
----------------------------
  - install-file: resolve $BOOT before the sdboot vfat gate
  - check: root --check is silent exit 3; others keep exit 2
  - signal: propagate 128+N via exec re-raise
  - udev: EPP rule KERNEL=="cpu[0-9]*" (never fired before)
  - fstab: atime-variant opts trigger rewrite
  - lock: refuse reclaim on garbage pidfile; re-verify owner
  - backup: skip .ry.bak on inconclusive probe; drop symlink
    first
  - timeout: clamp RY_RUN_TIMEOUT >9 digits to 2147483647
  - ntp: add RY_NO_NTP_REMEDIATION=1; log the timesyncd enable
  - args: glued short flags resolve first-of -h/-v

7.79.0 - 7.84.0 (2026-06-28 .. 07-01)
-------------------------------------
  - kernel: raise KERNEL_MIN 6.18 -> 6.19
  - generators: reject control chars; skip malformed; assert count
  - validate: GPU_DPM_LEVEL enum; reject reserved COUNTRY codes
  - run: derive the capture tail cap from the head cap
  - verify: assert amd_pstate/dynamic_epp == disabled
  - udev: GPU rule card[0-9]* + DEVTYPE=="drm_minor"
  - nftables: add TCP 27037 to the remote-play set

7.71.0 - 7.78.3 (2026-06-26 .. 06-28)
-------------------------------------
  - refactor: one-line fn collapse; extract _content_fn_for; drop
    baloofilerc/_post_baloo/_kb_*/umip fn
  - cmdline: iommu=pt -> amd_iommu=off; fsck force/repair,
    max_cstate=1, btusb autosuspend=n; add _vrkm_iommu
  - modprobe: add 60-ry-mt7925e.conf (disable_aspm=1)
  - cpupower: governor performance -> powersave
  - udev: EPP performance -> balance_performance; 60 -> 99 rules
  - env: add PROTON_FSR4_RDNA3_UPGRADE=1, RY_REMOTE_PLAY_PORTS
  - validate: add the kernel-floor and key validators
  - compat: command basename over the fish >=3.7 path builtin

7.60.0 - 7.70.1 (2026-06-21 .. 06-24)
-------------------------------------
  - bluetooth: add main.conf; enable service; reconnect=3
  - net: wpa_supplicant, powersave=2, NM log; mask modemmanager
  - gpu: drop drirc + radv-apu overrides (gfx1151 uma:1)
  - verify: split WiFi runtime into a dedicated sub-check
  - regdom: remove /etc/conf.d/wireless-regdom
  - mesa: raise the soft-floor warn 25.3 -> 26.0
  - guards: destinations 17 -> 15; hooks/file count 20 -> 18

7.59.0 and earlier
------------------
  - History trimmed. See git tags for the full record.
