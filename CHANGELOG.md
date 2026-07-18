Summary of changes
==================

Newest first. Versioning is MAJOR.MINOR.PATCH.

7.110.0 (2026-07-18)
--------------------
  - remove: AMD_VULKAN_ICD=RADV from ENV_VARS (13 -> 12) — the variable is read only by the switchable-graphics layer shipped with amdvlk (AMDVLK README: with RADV also installed, AMDVLK becomes the default and AMD_VULKAN_ICD switches between them); this profile ships RADV only (EXPECTED_VULKAN_PKGS byte-verified), amdvlk is AUR-only and upstream-discontinued — re-add the pin if amdvlk is ever installed
  - change: nftables input chain reordered to the canonical Arch "Simple & Safe" shape — ct state invalid drop first ("early drop of invalid connections"), then established,related accept, then loopback accept; ct states are disjoint so packet decisions are unchanged except invalid-state loopback packets now drop (matches the Arch-shipped default); live-applies via the nftables post-hook, no reboot
  - readme: Session Environment table -> 12 rows; env-file purpose cell synced; badge/checkout -> 7.110.0

7.109.0 (2026-07-18)
--------------------
  - change: POWERDEVIL_NO_DDCUTIL=1 moves from the per-service drop-in into the managed environment.d file (ENV_VARS 12 -> 13) — environment.d(5) variables reach services started by the systemd user instance, and PowerDevil reads the variable at daemon start (qEnvironmentVariableIntValue > 0); the drop-in ~/.config/systemd/user/plasma-powerdevil.service.d/10-no-ddcutil.conf is retired as a managed file (managed 18 -> 17, USER_DESTINATIONS 3 -> 2, _RY_POST_HOOKS 18 -> 17, _post_powerdevil removed) — delete the deployed drop-in by hand on migration
  - add: one-time first-adoption preserve <dst>.ry.orig for every non-boot managed file whose pre-existing content differs at first deploy (boot files keep the .ry.bak path) — closes the silent-overwrite data-loss gap
  - add: --verify runtime user-unit health check (_vrsv_user_units) — plasma-powerdevil.service must not be in the failed state; any failed systemd --user unit warns
  - change: _post_envd and the install Finalize phase live-apply environment.d changes to PowerDevil (user daemon-reload re-runs the environment generators, then plasma-powerdevil restart; bus-gated, non-fatal) — 7.108.0's drop-in live-apply hook only ran under --install-file, never in a full install
  - readme: counts + tables synced (managed 18 -> 17, user files 3 -> 2, Embedded Values 15/13/10); Gaming Environment -> Session Environment; backups + uninstall cover .ry.orig; badge/checkout -> 7.109.0

7.108.0 (2026-07-17)
--------------------
  - add: PowerDevil DDC/CI opt-out drop-in as managed file 18 (~/.config/systemd/user/plasma-powerdevil.service.d/10-no-ddcutil.conf, POWERDEVIL_NO_DDCUTIL=1) + user-scope live-apply post-hook (systemctl --user daemon-reload + plasma-powerdevil restart, gated on an active user-bus; notify fallback, non-fatal)
  - remove: kernel params 8250.nr_uarts=0 + tsc=reliable (KERNEL_PARAMS 17 -> 15); packages git-delta + ddcutil (PKGS_ADD 18 -> 16; libddcutil stays via the powerdevil dependency); masks NetworkManager-wait-online.service + ModemManager.service (MASK 12 -> 10)
  - resolved: DNSSEC allow-downgrade -> no (validation delegated to the upstream resolver; allow-downgrade is downgrade-attack-vulnerable and a known bogus-failure source)
  - readme: counts + tables synced (managed 17 -> 18, user files 2 -> 3, Embedded Values 15/12/10); badge/checkout -> 7.108.0

7.107.3 (2026-07-16)
--------------------
  - changelog: 7.60.0 - 7.99.1 detail folded into the history-trim line — every entry superseded by current README/source state
  - source + readme: trim pass

7.107.2 (2026-07-16)
--------------------
  - fix: drop the stale -V case from the root pre-scan (flag removed in 7.106.0); root --check -V now exits 2 with usage, matching non-root
  - readme: Sysctl Overrides table -> brief prose; badge/checkout -> 7.107.2
  - packaging: release zip ships ry-install.fish with mode 0755 (was 0644)

7.106.0 - 7.107.1 (2026-07-15)
------------------------------
  - remove: --verbose/-V flag (stream emitter retained for error paths); _vss_modprobe_stale scan; NTP auto-enable + RTC writeback — an unsynced clock now warns only; _lock_pid_started_after recycled-PID rescue (dead-PID stale reclaim retained); Mesa soft-warn + kernel-advisory notes; functions 289 -> 286
  - fix: MASK modemmanager.service -> ModemManager.service (unit lookup is case-sensitive; the lowercase mask never matched); resolved-divergence comment DoH -> DoT
  - source: +5 section banners (fstab atomic replace, post-hooks hardware/firewall, verify-static boot, atomic-write public entry, entry greps)
  - readme: flags/NTP/lock/uninstall wording synced; Requirements 6 -> 4 rows; Mask cell casing; badge/checkout -> 7.107.1

7.105.5 - 7.105.15 (2026-07-14 .. 07-15)
----------------------------------------
  - env: FSR4_UPGRADE=1 replaces PROTON_FSR4_RDNA3_UPGRADE=1 (long form removed in Proton-CachyOS 11.0-20260702)
  - boot: pcie_aspm.policy=performance replaces pcie_aspm=off — actively disables ASPM regardless of BIOS state
  - kernel: enforced floor removed — 6.18.4 advisory only; validators 4 -> 3
  - verify: _vss_modprobe_stale added (unmanaged 60-ry-* scan); exit codes 11-14 + 251 annotated internal-only; packaging: archive -> store-mode (zip -0)
  - readme: Embedded Values tables (17/12/10); Managed Files split into Boot/System/User; consistency + precision fixes; trim to vital (BIOS table -> linked walkthrough)
  - changelog: history condensed to range summaries

7.100.0 - 7.105.4 (2026-07-11 .. 07-14)
---------------------------------------
  - kernel: KERNEL_MIN 6.19 -> 6.18.4 (3-part compare; gfx1151 fix is firmware); MES floor re-anchored post-0x83
  - boot: pcie_aspm.policy=performance -> pcie_aspm=off; drop mt7925e disable_aspm=1
  - values: +VKD3D_CONFIG=descriptor_heap, +vm.watermark_boost_factor=0; packages: drop archlinux-contrib (PKGS_ADD -> 18)
  - source: comment/header/data-row condensation; readme: Env Overrides Default column; ntp: scan openntpd; accept comment-only modprobe drop-in

7.99.1 and earlier
------------------
  - History trimmed. See git tags for the full record.
