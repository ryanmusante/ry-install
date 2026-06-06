# ry-install

CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / Radeon 8060S).

**Version 7.20.5 · fish ≥ 3.6 · CachyOS · MIT**

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

Run as your normal user — **root is refused (exit 2)**; sudo is invoked internally. Reboot, then `--verify`. Re-running is idempotent (safe to upgrade).

## Scope

| Scope | Items |
|---|---|
| **In** | kernel cmdline, initramfs, systemd units (system + user), network stack (NetworkManager + iwd), sysctl, gaming env vars, pacman/AUR install + remove, systemd-boot BLS entries via `sdboot-manage` |
| **Out** | dotfiles, shells, editors, secrets, backups, multi-user, non-CachyOS distros, laptops, UKI |

## Prerequisites

Hard requirements abort read-only in preflight (exit 3); retry after fixing. `paru` and NTP sync only warn.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root, GNU coreutils (busybox/uutils unsupported) |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| curl / findmnt | both required |
| Hardware | CPU matches `Ryzen AI Max` |
| paru | recommended ≥ 2.0.0 (AUR phase warns if absent) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached credential (`sudo -v`) |

The sudo cache can lapse mid-run; mitigate with `Defaults timestamp_timeout=60` or a NOPASSWD drop-in at `/etc/sudoers.d/ry-install`. Cron/systemd contexts must pre-cache (the `sudo -v` fallback needs a TTY). Recovery is always to re-run.

## Hardware

| Component | Spec |
|---|---|
| CPU | Ryzen AI Max+ 395 (Zen 5, gfx1151) |
| GPU | Radeon 8060S (RDNA 3.5) |
| Memory | 128 GB LPDDR5x-8000 |

The CPU gate matches `Ryzen AI Max` in every mode (incl. `--verify`/`--check`); override with `RY_INSTALL_SKIP_HARDWARE_CHECK=1`.

## Usage

`--check` and `--verify` only read state; only the no-argument run and `--install-file` write to disk.

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output (`--check` ignores it) |
| `--verify` | Config files byte-for-byte, then live state |
| `--check` | Idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--country=XX` | Wireless regdom (ISO-3166-1 alpha-2; default `US`; UK is `GB`) |
| `-h, --help` · `-v, --version` | Help · version |

`--install-file` of a boot-critical file (`loader.conf`, `kernel/cmdline`, `sdboot-manage.conf`, `mkinitcpio.conf`) runs the boot cascade; **cascade failure exits 4 (DO NOT REBOOT).** Non-boot post-hook failures stay exit 0 (file already deployed).

## Install Flow

Six phases. A `pacman -Syu`, package-verify, or boot-config failure taints the run and skips the Phase 5 rebuild; the advisory AUR phase never taints. Phase 3 writes are atomic renames.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | prereqs + lock + runtime validation |
| 2 | Packages | `pacman -Syu --needed` + AUR via `paru` + cache refresh |
| 3 | Configuration | deploy 15 embedded files (atomic) |
| 4 | Services | fstab + resolved + package removal + mask + enable |
| 5 | Boot | `mkinitcpio -P` + `sdboot-manage` + post-rebuild sanity |
| 6 | Finalize | user daemon-reload + paccache + NetworkManager restart (deferred on active WiFi) |

## Run Summary

A CHECK/RESULT/EVIDENCE matrix (totals, elapsed, verdict) prints to stderr; the JSONL log records each phase result and a final summary. Verdict maps to the exit code.

| Result | Semantics |
|---|---|
| `PASS` | succeeded |
| `WARN` | non-fatal anomaly (never taints; exit stays `0`) |
| `FAIL` | failed; the only result that sets `INSTALL_HAD_ERRORS` |
| `DEFER` | deferred to next boot |
| `SKIP` / `N/A` | by design / not applicable |

| Verdict | Trigger | Exit |
|---|---|---|
| `PASS` | `0 FAIL · 0 WARN` | `0` |
| `PASS-WITH-WARNINGS` | `0 FAIL · ≥1 WARN` | `0` |
| `FAIL` | `≥1 FAIL` | `1` |
| `FAIL-BOOT-CRITICAL` | boot cascade aborted (prints DO NOT REBOOT) | `4` |
| `PREFLIGHT` | preflight gate failed after a phase row was recorded | `3` |

## Configuration

The script is the source of truth; `--verify` checks each embedded file byte-for-byte, then live state. Retune via the `set -g` globals near the top. Phases 1, 5, and 6 deploy no files.

### Packages

`iwd`, `mesa`, `cpupower`, `iw`, and `rtkit` are CachyOS defaults (not re-added); their configs still deploy. AUR is advisory — missing `paru` or a partial failure is `WARN`; only an all-package AUR failure is `FAIL`. Flags: `paru -S --needed --noconfirm --skipreview --cleanafter` (`--removemake` omitted for DKMS makedeps). PGP failure → `gpg --recv-keys <KEYID>`.

| Action | Packages |
|---|---|
| Install (14) | `nvme-cli`, `htop`, `git-delta`, `lm_sensors`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `fd`, `sd`, `dust`, `procs`, `bottom`, `realtime-privileges`, `ddcutil` |
| AUR (1) | `mkinitcpio-firmware` (firmware blobs absent from `linux-firmware`) |
| Remove (8) | `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm` (boot splash); `micro`, `cachyos-micro-settings` (editor); `cachy-update` |

Vulkan drivers `vulkan-radeon` + `lib32-vulkan-radeon` (chwd) are verified present; `lib32-mesa` ships in the install list.

### Kernel cmdline (13 params)

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `preempt=full`, `split_lock_detect=off`, `tsc=reliable` |
| GPU | `amdgpu.ppfeaturemask=0xfff73fff` |
| IOMMU/PCIe | `amd_iommu=off` (disables IOMMU DMA isolation — perf/compat for Strix Halo), `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

### Bootloader & initramfs

| Target | Settings |
|---|---|
| `loader.conf` | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| `sdboot-manage.conf` | `LINUX_OPTIONS`=cmdline, `LINUX_FALLBACK_OPTIONS=quiet`, `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING`/`OVERWRITE_EXISTING`/`REMOVE_OBSOLETE=yes` |
| `mkinitcpio.conf` | `MODULES=(amdgpu)`, `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`, `COMPRESSION=zstd (-1 -T0)` |

### Service & driver configs

| Config | Settings |
|---|---|
| systemd-resolved | `MulticastDNS=resolve`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` |
| systemd-logind | `Handle{Power,Suspend,Hibernate,Reboot}Key` (+ `…LongPress`) = `ignore` |
| iwd | `EnableNetworkConfiguration=false`, `PowerSaveDisable=*`, `NameResolvingService=systemd` |
| NetworkManager | `wifi.backend=iwd`, `wifi.powersave=2`, `logging level=WARN` |
| cpupower | `GOVERNOR=powersave` |
| amdgpu/ttm | `pages_limit`/`page_pool_size=8388608` (caps GTT at 32 GiB) |
| RADV drirc | `radv_enable_unified_heap_on_apu=true` |
| udev | NVMe whole-disk I/O scheduler → `none` |
| wireless regdom | `COUNTRY=US` (override `--country=XX`) |

### sysctl (8) & fstab

| Scope | Settings |
|---|---|
| `net.core` | `default_qdisc=fq`, `netdev_budget=600`, `netdev_budget_usecs=5000` |
| `net.ipv4` | `tcp_congestion_control=bbr`, `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0` |
| `vm` | `compaction_proactiveness=0`, `max_map_count=2147483642` |
| fstab (ext4) | `noatime`, `lazytime`, `commit=10` |

### Gaming env vars (10)

| Category | Vars |
|---|---|
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Mesa/RADV | `MESA_SHADER_CACHE_MAX_SIZE=16G`, `AMD_VULKAN_ICD=RADV` |
| Wine | `WINEDEBUG=-all` |

### Services (Phase 4)

fstab rewrite → resolved restart → package removal → mask 11 units → enable runtime units → apply regdom. The fstab rewrite strips conflicting options, is gated by `findmnt --verify`, and snapshots to `/etc/fstab.ry.bak` first.

| Set | Units |
|---|---|
| Masked (11) | `ananicy-cpp.service`, `avahi-daemon.{service,socket}`, `power-profiles-daemon.service`, `ufw.service` (rules flushed pre-mask), `NetworkManager-wait-online.service`, `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` |
| Enabled (3) | `fstrim.timer`, `NetworkManager.service`, `cpupower.service` (+ `NetworkManager-dispatcher.service` if installed) |

## Managed Files

15 files via the Phase 3 atomic-write sequence (system `0644`, user `0600`). Use this list as the uninstall reference.

| Path | Mode |
|---|---|
| `/boot/loader/loader.conf` | `0644` |
| `/etc/kernel/cmdline` | `0644` |
| `/etc/sdboot-manage.conf` | `0644` |
| `/etc/mkinitcpio.conf` | `0644` |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | `0644` |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | `0644` |
| `/etc/iwd/main.conf` | `0644` |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `0644` |
| `/etc/default/cpupower-service.conf` | `0644` |
| `/etc/sysctl.d/95-ry-overrides.conf` | `0644` |
| `/etc/drirc.d/95-ry-radv-apu.conf` | `0644` |
| `/etc/modprobe.d/ry-amdgpu-strixhalo.conf` | `0644` |
| `/etc/iw-regdomain` | `0644` |
| `/etc/udev/rules.d/60-ry-ioschedulers.rules` | `0644` |
| `~/.config/environment.d/10-environment.conf` | `0600` |

## Safety and Reliability

Atomic writes plus a gated Phase 5 rebuild keep a failed package or boot-config step from leaving a broken boot entry. `/etc/fstab` is snapshotted to `/etc/fstab.ry.bak` before rewrite; the post-write auto-restore excludes fstab.

| Feature | Detail |
|---|---|
| Atomic writes | tmp → render → symlink probe → chmod → `mv -T` |
| Auto backups | `<path>.ry.bak` before overwriting `loader.conf`/`mkinitcpio.conf`/`fstab` |
| Boot rebuild gate | skipped on package/boot-config failure; `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses the taint only |
| mkinitcpio rollback | byte-exact revert on `pacman -Syu` failure or signal |
| fstab | `findmnt --verify` gate (mandatory); symlinked `/etc/fstab` refused |
| Instance lock | atomic `mkdir` 0700; dead-PID reclaim via `kill -0` |
| Permissions | system `0644`, user `0600`, `~/ry-install/` `0700` |
| Firewall | **WARNING: no host firewall** — `ufw` disabled + masked (trusted-LAN); `--verify` reports its state |

Exit codes:

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `11` / `12` / `13` | `gen-nofn` (content-gen fn missing) / `gen-nouuid` (prereq global missing) / `gen-sysctl` (malformed entry) |
| `128+N` / `251` | signal (130 INT, 143 TERM, …) / `_run` tmpfile-alloc fail |
| `250` / `255` | internal `_as` / `_run` arg-misuse guards (never a process exit) |

On a signal-terminated run the process `$status` may not match the signal (a fish `--on-signal` limitation); the canonical code is recorded in the JSONL footer (`footer.exit_code`).

Runtime variables:

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | per-command wall-clock cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses the torn-package gate |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses the CPU match |
| `NO_COLOR` | unset | suppress ANSI color |

Logs are NDJSON under `~/ry-install/logs/<date>/`, one file per run, pruned after 30 days:

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):")))' ~/ry-install/logs/**/*.jsonl
```

## Uninstall

No automated uninstaller; use Managed Files as the rollback reference.

1. `sudo systemctl unmask` the 11 masked units.
2. `sudo rm` the deployed paths.
3. Restore `/etc/fstab` from `/etc/fstab.ry.bak`.
4. Optionally reverse the package changes.
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

Most clear with a DKMS package. MT7925 TX-power/deauth and Strix Halo ACP audio are upstream-pending with no local fix.

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | `paru -S amdgpu-dkms-firmware` |
| MT7925 | kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| MT7925 | TX power 3 dBm / random deauth | none (upstream) |
| RTL8127 10GbE | throughput drops under load | `paru -S r8127-dkms` |
| Strix Halo ACP | no ASoC machine driver | pending upstream (HDMI/USB audio unaffected) |
| NM + iwd | intermittent boot connectivity | `nmcli radio wifi off; and nmcli radio wifi on` |
| NM + iwd | WPA2/3 Enterprise GUI broken | CLI or wpa_supplicant |
| AUR | PGP signature failure | `gpg --recv-keys <KEYID>`, then re-run |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | fix the cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| `.ry-install.*` orphan | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, then re-run |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire / ddcutil permission denied | `sudo usermod -aG realtime,i2c $USER`, re-login |

## References

- NM + iwd: <https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend>
- MT7925: <https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek>
- gfx1151: <https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151>
- ppfeaturemask: <https://wiki.archlinux.org/title/AMDGPU#Boot_parameter>

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
