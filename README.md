# ry-install

CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / Radeon 8060S, gfx1151, 128 GB LPDDR5x).

**Version 7.36.1 · fish ≥ 3.6 · CachyOS · MIT**

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

> [!IMPORTANT]
> Run as your normal user — **root is refused (exit 2)**; sudo is invoked internally. Reboot, then `--verify`. Re-running is idempotent.

In scope: kernel cmdline, initramfs, systemd units, network (NetworkManager + iwd), sysctl, gaming env vars, pacman add+remove, sdboot-manage BLS entries. Out: dotfiles, shells, secrets, backups, multi-user, non-CachyOS, laptops, UKI.

## Requirements

Hard requirements abort read-only in preflight (exit 3); `pacman-contrib` and NTP sync only warn. Recommended Zen 5 repos above `[core]`/`[extra]`: `cachyos-znver4`, `cachyos-core-znver4`, `cachyos-extra-znver4`.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root, GNU coreutils + findutils + diffutils |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| curl / findmnt / cmp | all required (cmp gates byte-exact mkinitcpio.conf revert) |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached (`sudo -v`); may lapse mid-run — `Defaults timestamp_timeout=60` or NOPASSWD drop-in |
| pacman-contrib | recommended — pactree (rdep-safe removal) |

## Usage

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output (`--verify`/`--install-file` are always verbose; `--check` is always silent) |
| `--verify` | Config files byte-for-byte, then live state |
| `--check` | Idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--country=XX` | Wireless regdom (ISO-3166-1 alpha-2; default `US`; UK is `GB`) |
| `--` | End of options (no positional arguments accepted) |
| `-h, --help` · `-v, --version` | Help · Version (honored first, except as the `--install-file` value) |

`--verify`/`--check` read state only, lock-free. `--check` compares live `/proc/cmdline` (pending changes read as drift until reboot) and is silent after parsing. `--verify` also reports unwritten state: ntsync, THP/KSM/ZRAM, `tcp_bbr`, drirc XML, ext4 fstab opts, boot time vs 15 s (≥90% = WARN).

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits 4 — **do not reboot** until it succeeds. Non-boot post-hook failures stay exit 0. A non-vfat `/boot` ESP fallback refuses sdboot (exit 4).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure taints the run (skips the Phase 5 rebuild). Phase 3 writes are atomic renames.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | invariants → lock (exit 5) → hard gates; read-only except a non-fatal NTP repair (skipped when chronyd/ntpd is enabled or active) |
| 2 | Packages | `pacman -Syu --needed` → `updatedb`/`pkgfile`. `mkinitcpio.conf` pre-deployed before `-Syu`; one `-Syyu` retry. Managed `.pacnew` auto-resolved (rollback: `pacdiff`); `.pacsave` reported |
| 3 | Configuration | deploy the 18 embedded files atomically |
| 4 | Services | fstab → resolved restart → package removal → nftables activation → mask (ufw flush) → enable → regdom |
| 5 | Boot | `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity. A tainted run skips the rebuild; resolve and re-run |
| 6 | Finalize | user `daemon-reload` → `paccache -rk2 -ruk0` (`pacman -Sc` fallback) → NetworkManager restart (deferred on active Wi-Fi) |

CachyOS defaults (`iwd`, `mesa`, `cpupower`, `iw`, `rtkit`) are not re-added; their configs still deploy. `vulkan-radeon` + `lib32-vulkan-radeon` are verified present.

> [!NOTE]
> With `REMOVE_EXISTING=yes` (set in `sdboot-manage.conf`), `sdboot-manage gen` deletes every `loader/entries/` entry before regenerating — including foreign/other-OS BLS entries. EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

## Run Summary

A CHECK/RESULT/EVIDENCE matrix prints to stderr; the JSONL log records each phase. Verdict (`PASS` · `PASS-WITH-WARNINGS` · `FAIL` · `FAIL-BOOT-CRITICAL` · `PREFLIGHT`) maps to the exit code: `WARN` keeps exit `0`; `DEFER` applies next boot.

## Configuration

The script is the source of truth (retune the `set -g` globals near the top). In-script timing tunables, not env-overridable: `BOOT_TIME_TARGET=15` s, `PACTREE_TIMEOUT_S=60` s, `NM_RESTART_DELAY=3` s.

**Packages**

| Action | Packages |
|---|---|
| Install (16) | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `realtime-privileges`, `ddcutil`, `nftables` |
| Remove (9) | `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`, `micro`, `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |

**Kernel cmdline** → `/etc/kernel/cmdline` + sdboot `LINUX_OPTIONS`

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `split_lock_detect=off`, `tsc=reliable` |
| GPU | `amdgpu.ppfeaturemask=0xffff7fff` |
| IOMMU/PCIe | `iommu=pt`, `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

**Bootloader / initramfs**

| File | Settings |
|---|---|
| `loader.conf` | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| `sdboot-manage.conf` | `LINUX_OPTIONS`=kernel params (`root=` + `rw` injected by sdboot-manage), `LINUX_FALLBACK_OPTIONS=quiet`, `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING`/`OVERWRITE_EXISTING`/`REMOVE_OBSOLETE=yes` |
| `mkinitcpio.conf` | `MODULES=(amdgpu)`, `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`, `COMPRESSION=zstd` `-1 -T0` |

**Service & device configs**

| Config | Settings |
|---|---|
| systemd-resolved | `MulticastDNS=no`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` |
| systemd-logind | `Handle{Power,Suspend,Hibernate,Reboot}Key` (+ `…LongPress`) = `ignore` |
| iwd | `EnableNetworkConfiguration=false`, `PowerSaveDisable=*`, `NameResolvingService=systemd` |
| NetworkManager | `wifi.backend=iwd`, `wifi.powersave=2` (disable), `[logging] level=WARN` |
| cpupower | `GOVERNOR=powersave`; EPP pinned `performance` via udev (`amd_pstate=active` driver-governed) |
| amdgpu/ttm | `pages_limit=8388608`/`page_pool_size=8388608` (GTT ~32 GiB; requires BIOS UMA 512 MB) |
| RADV drirc | `radv_enable_unified_heap_on_apu=true` |
| udev | NVMe whole-disk I/O scheduler → `none`; CPU EPP → `performance` |
| wireless regdom | `COUNTRY=US` (`--country=XX`); persists via `/etc/iw-regdomain` → `cachyos-iw-set-regdomain` |

**sysctl** → `/etc/sysctl.d/95-ry-overrides.conf` (loads after CachyOS `70-cachyos-settings.conf`)

| Scope | Settings |
|---|---|
| `net.core` | `default_qdisc=fq`, `netdev_budget=600`, `netdev_budget_usecs=5000` |
| `net.ipv4` | `tcp_congestion_control=bbr`, `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0` |
| `vm` | `compaction_proactiveness=0`, `max_map_count=2147483642` |

**Gaming env** → `~/.config/environment.d/10-environment.conf` (`0600`; `PROTON_*` per `proton-cachyos`)

| Category | Vars |
|---|---|
| Mesa/RADV | `AMD_VULKAN_ICD=RADV`, `MESA_SHADER_CACHE_MAX_SIZE=16G` |
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Wine | `WINEDEBUG=-all` |

**fstab** — ext4 entries rewritten in place: applies `noatime`, `lazytime`, `commit=10`; strips conflicting atime opts + redundant `defaults`; rewrites any `commit=`. Mandatory `findmnt --verify` gate; snapshot to `/etc/fstab.ry.bak`; symlinked `/etc/fstab` refused.

**Units**

| Set | Units |
|---|---|
| Masked (9) | `ananicy-cpp.service`, `power-profiles-daemon.service`, `NetworkManager-wait-online.service`, `ufw.service` (rules flushed pre-mask, after nftables activates), `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` |
| Enabled (4) | `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service` (+ `NetworkManager-dispatcher.service` if installed) |

## Managed Files

The Phase-3 files — the uninstall reference (system `0644`, user `0600`):

| Group | Files |
|---|---|
| Boot (4) | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd (2) | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| Network (5) | `/etc/iwd/main.conf`, `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/conf.d/wireless-regdom`, `/etc/nftables.conf` |
| Tuning (6) | `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/default/cpupower-service.conf`, `/etc/modprobe.d/ry-amdgpu-strixhalo.conf`, `/etc/drirc.d/95-ry-radv-apu.conf`, `/etc/udev/rules.d/60-ry-ioschedulers.rules`, `/etc/udev/rules.d/61-ry-epp.rules` |
| User (1) | `~/.config/environment.d/10-environment.conf` |

## Safety & Reliability

> [!WARNING]
> This profile **masks `ufw`** and ships a minimal **nftables default-deny-inbound** ruleset: established/related and loopback accepted, invalid conntrack dropped, ICMPv4 plus essential ICMPv6 (NDP + PMTUD) accepted, all other inbound dropped — including mDNS. Add inbound ports to `/etc/nftables.conf` as needed.

Every managed write is crash-safe: render → same-FS tmp → symlink-probe → `.ry.bak` → chmod → `mv -T` → re-read + restore on mismatch.

| Feature | Detail |
|---|---|
| Atomic writes | render → tmp → symlink-probe → backup → chmod → `mv -T` → restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` / `fstab` |
| mkinitcpio rollback | byte-exact revert on `pacman -Syu` failure or signal; failed revert keeps the `/run` snapshot |
| Instance lock | atomic `mkdir 0700`; dead/recycled-PID reclaim via `/proc` (fail-closed) |
| Permissions | system `0644`, user `0600`, `~/ry-install/` `0700` |

The process exit code is the single source of truth; internal sentinels stay in the JSONL log only.

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, …) |
| `11`/`12`/`13`/`251`/`250`/`255` | internal sentinels — never a process exit (JSONL `gen_fail`) |

These environment variables are the only external overrides; each falls back safely when unset or invalid.

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | per-command cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses the CPU match |
| `NO_COLOR` | unset | suppress ANSI color |
| `TMPDIR` | `/tmp` | scratch dir; invalid values fall back to `/tmp` |

Logs: JSONL under `~/ry-install/logs/<date>/`, one per run, not auto-pruned; `run-overflow/` holds full spills. Prune: `find ~/ry-install/logs -type f \( -name '*.jsonl' -o -name '*.log' \) -mtime +30 -delete`. Query failures:

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):") or test("result=(FAIL|WARN)")))' ~/ry-install/logs/**/*.jsonl
```

## Uninstall

No automated uninstaller; use Managed Files as the rollback reference.

1. `sudo systemctl unmask` the masked units.
2. `sudo rm` the deployed system paths; `rm` the user env.d file (no sudo).
3. Restore `/etc/fstab` from `/etc/fstab.ry.bak`; delete the `.ry.bak` backups.
4. Optionally reverse the package changes.
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | out-of-tree firmware package (unmanaged) |
| MT7925 | kernel panics (`mt792x_mac_reset_work`) | out-of-tree DKMS module (unmanaged) |
| MT7925 | TX power 3 dBm / random deauth | none (upstream) |
| RTL8127 10GbE | throughput drops under load | out-of-tree DKMS module (unmanaged) |
| Strix Halo ACP | no ASoC machine driver | pending upstream (HDMI/USB audio unaffected) |
| NM + iwd | intermittent boot connectivity | `nmcli radio wifi off; and nmcli radio wifi on` |
| NM + iwd | WPA2/3 Enterprise GUI broken | CLI or `wpa_supplicant` |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | a phase tainted boot state — fix the cause, then re-run (idempotent) |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| `.ry-install.*` orphan | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete; find ~/.config/environment.d -xdev -name '.ry-install.*' -delete`, then re-run |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire / ddcutil permission denied | `sudo usermod -aG realtime,i2c $USER`, re-login |

## References

- NM + iwd: <https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend>
- gfx1151: <https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151>

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
