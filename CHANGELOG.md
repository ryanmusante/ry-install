ry-install release notes
========================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.102.1 (2026-07-12)
--------------------
  - docs: trim BIOS, safety-fallback, and packages prose to vital points
  - docs: name the deploy gate key/count (keys + counts, two validators)
  - docs: normalize countable numerals to digits
  - docs: bump version pins

7.102.0 (2026-07-12)
--------------------
  - boot: switch pcie_aspm.policy=performance to pcie_aspm=off
  - env.d: add VKD3D_CONFIG=descriptor_heap
  - sysctl: add vm.watermark_boost_factor=0
  - modprobe: drop mt7925e disable_aspm=1 (covered by pcie_aspm=off)
  - validate: accept comment-only modprobe drop-in
  - docs: sync tables; bump version pins

7.101.0 (2026-07-12)
--------------------
  - comments: trim verbose inline notes to vital rationale
  - docs: condense intro, preflight, BIOS, and packages prose
  - docs: bump version pins

7.100.0 (2026-07-11)
--------------------
  - kernel: re-anchor MES floor to post-0x83 (0x83 reverted upstream 2025-12-01)
  - sysctl: correct netdev comment 2.5GbE -> 10GbE (RTL8127)
  - verify: trim stale Vulkan mention from runtime-session description
  - ntp: scan openntpd.service in the NTP-client conflict guard
  - packages: drop archlinux-contrib (PKGS_ADD 19 -> 18; nothing invokes it)
  - docs: note fallback-entry IPv6/IOMMU exposure; cpu_temp #1794 caveat
  - docs: drop the pre-7.99 modprobe drop-in removal note
  - docs: bump version pins

7.99.1 (2026-07-10)
-------------------
  - signal: hold --check stderr-silence through the pre-argparse window
  - init: set the umask variable directly; drop the autoloaded function
  - comments: trim verbose inline notes
  - docs: merge changelog ranges; bump version pins

7.99.0 (2026-07-10)
-------------------
  - modprobe: merge the two drop-ins into 60-ry-modules.conf
  - modprobe: add the BLACKLIST_AMDXDNA true|false toggle
  - validate: refuse BLACKLIST_AMDXDNA=false under amd_iommu=off
  - guards: managed destinations 18 -> 17
  - docs: sync tables to the merge; note pre-7.99 drop-in removal

7.98.0 - 7.98.6 (2026-07-09 .. 07-10)
-------------------------------------
  - verify: lsmod-check managed modprobe.d blacklist entries
  - verify: compare live COMPRESSION= to MKINITCPIO_COMPRESSION
  - verify: strip inline comments before the token match
  - verify: quote the GPU_DPM_LEVEL sysfs comparison
  - packages: tag the pre-Syu mkinitcpio seed log line
  - preflight: require id(1) in the dependency gate
  - env: drop RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK (floor unconditional)
  - data: hoist EPP + scaling-driver expectations; enum-gate EPP
  - data: align CPUPOWER_GOVERNOR charset with its validator
  - modprobe: correct the amdxdna errno note (-EINVAL, ret -22)
  - changelog: merge 7.98.x; fix errno and path-builtin notes
  - docs: condensed BIOS section; drop Known-Issues/Benign-Log tables
  - docs: root --check exit 3; TTY sudo -v prompt; rehash hint

7.96.0 - 7.97.3 (2026-07-07 .. 07-08)
-------------------------------------
  - services: mask avahi-daemon .service+.socket (MASK 10 -> 12)
  - validate: KERNEL_PARAMS charset [A-Za-z0-9._,=-]
  - backup: .ry.bak + post-write verify/restore for the 4 boot files
  - files: nft -c pre-validate /etc/nftables.conf before commit
  - verify: pacman.conf sudo-read fallback + grep/lapse gates
  - verify: _ry_mkinitcpio_array joins multi-line KEY=( ) blocks
  - env: pin tmp to /tmp; NTP always remediates; keep NO_COLOR
  - data: derive _RY_BACKUP_TARGETS from _RY_BOOT_CRITICAL_DSTS
  - lock: set the mkdir-success flag beside the rc capture
  - cli: repeated --install-file resolves last-wins
  - log: rename via mv -T with cp -pT recovery (dir-squat safe)
  - run: add -h (host form) to the sudo value-flag skip list
  - probes: drop builtin->pipe captures (SIGPIPE risk)
  - docs: single-line comment pass; trim environment table

7.94.0 - 7.95.2 (2026-07-06 .. 07-07)
-------------------------------------
  - udev: GPU rule DEVTYPE -> ENV{DEVTYPE}; rule never applied
  - modprobe: blacklist amdxdna (-EINVAL under amd_iommu=off)
  - cmdline: clearcpuid=514 -> clearcpuid=umip (version-stable)
  - kernel: re-scope the 6.19 floor rationale to gfx1151 MES-0x86
  - lock: USER_HZ=100 fallback for PID starttime
  - preflight: hard-require find(1); metachar-gate the governor
  - preflight: validate vercmp output before the mesa compare
  - dispatch: single _RY_ARGPARSE_SPEC global + count tripwire
  - run: long-op resolver emits 0 for RY_RUN_TIMEOUT=0
  - rootguard: one @@LEFT@@ line per leftover positional
  - install-file: log POST_HOOK_NONE on unmatched hook pattern
  - docs: correct "-Rns -s" to "-Rns"; trim README + inline comments

7.90.0 - 7.93.0 (2026-07-04 .. 07-05)
-------------------------------------
  - profile: rename gtr_pro -> gtr9_pro
  - run: hard-cap long pkg/boot/db ops at 7200s; resolve via PATH
  - validate: metachar-gate boot scalars + COMPRESSION_OPTIONS
  - metachar: PCRE \x27 for quote; drop the fragile requote
  - packages: add pacman-contrib + archlinux-contrib (17 -> 19)
  - packages: mark PKGS_ADD explicit post-Syu
  - mangohud: reorder gpu_temp; comment cpu_temp; add cpu_power
  - cleanup: db.lck grace reaps only -P $fish_pid descendants
  - verify: fold Vulkan into _vsp_required; drop 6 stale functions
  - docs: sync README/help/pins; correct the ntsync note

7.85.0 - 7.89.0 (2026-07-01 .. 07-04)
-------------------------------------
  - args: root guard defers to argparse; invalid args exit 2
  - check: root --check is silent exit 3; others keep exit 2
  - guard: refuse stdin/pipe execution
  - signal: propagate 128+N via exec re-raise
  - verify: hardware/kernel gates warn; deploy/check exit 3
  - install-file: format-validate before write
  - install-file: loader.conf regenerates sdboot entries only
  - install-file: resolve $BOOT before the sdboot vfat gate
  - cmdline: add ipv6.disable=1; IPv4-only ruleset, inbound ping
  - packages: SYSTEM_UPGRADED from a pacman -Q fingerprint
  - services: skip resolved/NM restarts on unchanged drop-ins
  - udev: EPP rule KERNEL=="cpu[0-9]*"; retrigger cpu beside block
  - fstab: atime-variant opts trigger rewrite
  - lock: refuse reclaim on garbage pidfile; state dir umask 0077
  - backup: skip .ry.bak on inconclusive probe; drop symlink first
  - timeout: clamp RY_RUN_TIMEOUT >9 digits to 2147483647
  - run: inline overflow analysis (sha256 + <=10 sampled lines)
  - tmpfiles: PID-scoped names + sweep globs
  - ntp: add RY_NO_NTP_REMEDIATION=1 (dropped in 7.97)
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
  - refactor: one-line fn collapse; extract _content_fn_for
  - refactor: drop baloofilerc/_post_baloo/_kb_*/umip fn
  - cmdline: iommu=pt -> amd_iommu=off; add _vrkm_iommu
  - cmdline: fsck force/repair, max_cstate=1, btusb autosuspend=n
  - modprobe: add 60-ry-mt7925e.conf (disable_aspm=1)
  - cpupower: governor performance -> powersave
  - udev: EPP performance -> balance_performance; 60 -> 99 rules
  - env: add PROTON_FSR4_RDNA3_UPGRADE=1, RY_REMOTE_PLAY_PORTS
  - validate: add the kernel-floor and key validators
  - compat: command basename over the fish >=3.5 path builtin

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
