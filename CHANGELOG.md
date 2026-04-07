ry-install changelog

2026-04-07  Ryan Musante

- Tagged as v3.47.6
- fix: PKGS_ADD — removed `ntsync-common`. Redundant on CachyOS: linux-cachyos ships `CONFIG_NTSYNC=m` and declares `provides=(NTSYNC-MODULE)`; wine-cachyos (transitive dep of cachyos-gaming-meta via wine-cachyos-opt) installs `/usr/lib/modules-load.d/10-ntsync.conf` to auto-load the in-kernel module on boot. Refs: github.com/CachyOS/linux-cachyos config + PKGBUILD, github.com/CachyOS/CachyOS-PKGBUILDS/wine-cachyos.
- fix: SYSCTL_VALUES — dropped `vm.dirty_bytes=268435456` and `vm.dirty_background_bytes=67108864`. Both are byte-identical to vendor `/usr/lib/sysctl.d/70-cachyos-settings.conf` and were no-op duplicates.
- doc: README sysctl row updated to "17 net-new tunables" and explicitly notes `net.core.netdev_max_backlog` overrides vendor 4096→16384 (99-* loads after 70-* lexically).
- doc: Hardware Reference NIC corrected from "Dual Realtek RTL8127 10 GbE (board v2.2)" to "Dual Intel E610-XT2 10 GbE" per ServeTheHome review and Beelink/Intel support correspondence (craigwilson.blog).
- fix: KERNEL_PARAMS — removed `preempt=full`. No-op on stock linux-cachyos (CONFIG_PREEMPT=y + CONFIG_PREEMPT_DYNAMIC=y → "full" is already the dynamic default). README kernel-params count 15 → 14.
- doc: README Masked Services — removed unsourced "cache thrashing on 32T" framing from irqbalance row; left only the verifiable "Conflicts with threadirqs".
- doc: README Environment Variables — `PROTON_USE_NTSYNC=1` annotated as "default in current proton-cachyos; explicit pin" since recent proton-cachyos releases enable it by default.
- doc: README + profile comment — softened CWSR row, dropped unverifiable "Ubuntu OEM kernel 1018+ (not mainline as of 2026-Q2)" claim; kept the verified ROCm 7.2 userspace fix note and the kernel workaround.
- doc: README Known Issues — softened MES page faults row (dropped specific FW 0x83 / linux-firmware-20251125 date string pending upstream verification); softened black-screen row (dropped specific 6.19.0/6.19.1+ version pins pending verification).
- doc: Hardware Reference BIOS row softened from "P110 (Dec 2025 — ACPI fix)" to "Latest available from Beelink (P110+ recommended)" — vendor changelog not publicly verifiable.

2026-04-07  Ryan Musante

- Tagged as v3.47.5
- fix: ENV_VARS — `DXVK_LOG_LEVEL=none` valid but creates empty `app_d3d11.log` / `app_dxgi.log` files (doitsujin/dxvk#1703); added `DXVK_LOG_PATH=none` per DXVK README to disable log file creation entirely.
- doc: corrected `amdgpu.cwsr_enable=0` rationale in profile comment, README env table, and audit table — kernel-mode fix is only in Ubuntu OEM kernel 1018+ (not mainline as of 2026-Q2); ROCm 7.2 ships userspace fix only, kernel workaround still required. Refs: ROCm/ROCm#5724, ROCm/TheRock#2991.

2026-04-07  Ryan Musante

- Tagged as v3.47.4
- fix: ENV_VARS — `RADV_EXPERIMENTAL=transfer_queue` does not exist; correct variable per Mesa 26.0 is `RADV_PERFTEST=transfer_queue`. Also added `VKD3D_CONFIG=transfer_queue` so vkd3d-proton (DX12) titles actually use the dedicated SDMA transfer queue. Ref: https://www.phoronix.com/news/Mesa-26.0-RADV-Transfer-SDMA

2026-04-07  Ryan Musante

- Tagged as v3.47.3
- _install_fstab_opts: replace substring sed pipeline with field-based awk filter ($3 == "ext4"); old pipeline corrupted unrelated mounts whose path contained the literal "ext4" (e.g. /srv/ext4backups on xfs). Same fix applied to _ry_verify_runtime and needs_change check.
- _install_rebuild_boot: initrd size loop uses sudo find instead of user-context glob; on ESP-mounted /boot (vfat 0700) the glob silently yielded zero iterations.
- _ry_verify_static, _install_rebuild_boot: add -maxdepth 1 -type f to find /boot/loader/entries -name '*.conf'.
- CLI dispatch: unknown-mode arm uses $EXIT_USAGE constant.
- _validate_profile: SYSCTL_VALUES moved to conditional required block (only when */sysctl.d/* destination present); _ry_verify_runtime sysctl loop guards on set -q.
- _manifest_write: drop tmp from _TRACKED_TMPFILES on successful mv.
- Top-level LOG_FILE rename: capture mv rc, warn on failure, keep old path so footer/header still write.
- WiFi passphrase % rejection: rationale corrected to "NM keyfile reserved character".

2026-04-06  Ryan Musante

- Tagged as v3.47.2
- Drop spurious second `--` in 8 `string split -- ':' --` calls; rec[1..3] indices were off by one, breaking every service-state assertion in --verify-static and --verify-runtime.
- _validate_profile case glob `*/nm.conf` -> `*nm.conf` (fish glob `*` doesn't cross `/`; basename `99-cachyos-nm.conf` never matched).
- lint: changelog cross-check pointed at CHANGELOG.txt (file is .md) and used a regex for `3.47.1 (...)`; updated to match `- Tagged as v<ver>` lines.
- Log rotation piped `string join0` directly into xargs; capture into variable was stripping NULs and removing only one stale log per run.
- Removed dead `or set sudo_all 0` after `set -l sudo_all (...)`.
- test: --test-all completions check matches full flag tokens.
- _install_fstab_opts: removed unused `_mnt` local.

2026-04-05  Ryan Musante

- Tagged as v3.47.1
- Re-source guard no longer kills caller's interactive shell.
- _atomic_write_file: chown failure now returns 1.
- _acquire_lock: removed redundant PID write inside flock /bin/sh -c.
- Extracted _write_footer helper; deduped four JSONL footer printf sites.

2026-04-04  Ryan Musante

- Tagged as v3.47.0
- _atomic_write_file: parent-dir trust check before sudo mktemp; closes TOCTOU vs symlink probe.
- _atomic_write_file: fail-closed on empty pre-mv / post-mv hash.
- _ry_install_files: _argparse_tmp /dev/null fallback emits one-shot WARN.
- _pregenerate_content_files: mktemp uses --tmpdir=/tmp explicitly.
- Bootloader update: interactive confirm before destructive sdboot-manage gen.
- Root invocation emits explicit [NOTICE] when forcing --dry-run.
