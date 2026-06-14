# ry-install

CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395, gfx1151).

**Version 7.39.6 · fish ≥ 3.6 · CachyOS · MIT**

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

> [!IMPORTANT]
> Run as your normal user — **root is refused (exit 2)**; sudo is invoked internally. Reboot, then `--verify`. Re-running is idempotent.

In scope: kernel cmdline, initramfs, systemd units, network (NetworkManager + iwd), sysctl, gaming env vars, pacman add/remove, sdboot-manage BLS entries. Out of scope: dotfiles, secrets, backups, multi-user, non-CachyOS, laptops, UKI.

## Requirements

Hard requirements abort read-only in preflight (exit 3); NTP sync and `pacman-contrib` (pactree, for rdep-safe removal) only warn.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root, GNU coreutils + findutils + diffutils |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| curl / findmnt / cmp | all required (cmp gates byte-exact mkinitcpio.conf revert) |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached (`sudo -v`); may lapse mid-run — set `timestamp_timeout` or a NOPASSWD drop-in |

## Usage

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output (`--verify`/`--install-file` always verbose; `--check` always silent) |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `-h, --help` · `-v, --version` | Honored first, except as the `--install-file` value |

`--verify`/`--check` read state only, lock-free. `--check` compares live `/proc/cmdline`, so pending changes read as drift until reboot.

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits 4 — **do not reboot** until it succeeds. A non-vfat `/boot` ESP fallback also refuses sdboot (exit 4).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure taints the run and skips the Phase 5 boot rebuild; resolve the cause and re-run. All config writes are atomic renames.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock (exit 5) → hard gates; read-only except a non-fatal NTP repair |
| 2 | Packages | `pacman -Syu` (one `-Syyu` retry); `mkinitcpio.conf` pre-deployed first; managed `.pacnew` auto-resolved |
| 3 | Configuration | deploy the embedded config files atomically |
| 4 | Services | fstab → resolved → package removal → nftables → mask (ufw flush) → enable → regdom |
| 5 | Boot | `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity (tainted run skips this) |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart (deferred on active Wi-Fi) |

A CHECK/RESULT/EVIDENCE matrix prints to stderr and the JSONL log records each phase. The verdict maps to the exit code; `WARN` keeps exit `0`, `DEFER` applies next boot.

## Configuration

The script is the source of truth — retune the `set -g` globals near the top. Each managed file is a single profile concern:

| File | Purpose |
|---|---|
| kernel cmdline | CPU/GPU/IOMMU/storage/USB tuning for gfx1151; `root=UUID=`/`rw` written into `/etc/kernel/cmdline` |
| loader.conf / sdboot-manage.conf | systemd-boot entry generation (`REMOVE_EXISTING=yes`) |
| mkinitcpio.conf | `MODULES=(amdgpu)`, systemd hooks, zstd compression |
| resolved / logind | disable mDNS/LLMNR/DoT; ignore power/suspend/hibernate/reboot keys |
| iwd / NetworkManager | iwd Wi-Fi backend, powersave, regdom |
| cpupower / udev | `performance` governor + EPP, NVMe scheduler `none` |
| amdgpu/ttm modprobe | GTT ~32 GiB (`pages_limit`/`page_pool_size`; needs BIOS UMA 512 MB) |
| RADV drirc | `radv_enable_unified_heap_on_apu` for the APU |
| sysctl | BBR + `fq`, TCP/network tuning, `vm` tuning |
| environment.d | Mesa/RADV/DXVK/VKD3D/Proton gaming env (`0600`) |

**Packages** — installs `cachyos-gaming-meta`, `nvme-cli`, `lib32-mesa`, `nftables`, and CLI tools; removes the plymouth stack, `micro`, `cachy-update`, and `kdeconnect`. `vulkan-radeon` + `lib32-vulkan-radeon` are verified present.

**Units** — masks `ufw`, `power-profiles-daemon`, `ananicy-cpp`, the sleep/suspend/hibernate targets, and `NetworkManager-wait-online`; enables `fstrim.timer`, `NetworkManager`, `cpupower`, and `nftables`.

**fstab** — ext4 entries get `noatime,lazytime,commit=10` rewritten in place, every other column preserved byte-for-byte. Gated by line-count parity, a size floor, and mandatory `findmnt --verify`; symlinked `/etc/fstab` is refused.

## Managed Files

The Phase-3 files — the uninstall reference (system `0644`, user `0600`):

| Group | Files |
|---|---|
| Boot | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| Network | `/etc/iwd/main.conf`, `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/conf.d/wireless-regdom`, `/etc/nftables.conf` |
| Tuning | `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/default/cpupower-service.conf`, `/etc/modprobe.d/ry-amdgpu-strixhalo.conf`, `/etc/drirc.d/95-ry-radv-apu.conf`, `/etc/udev/rules.d/60-ry-perf.rules` |
| User | `~/.config/environment.d/10-environment.conf` |

## Safety & Reliability

> [!WARNING]
> This profile **masks `ufw`** and ships a minimal **nftables default-deny-inbound** ruleset: established/related and loopback accepted, ICMPv4 plus essential ICMPv6 (NDP + PMTUD) accepted, all other inbound dropped — including mDNS. nftables comes up before the ufw flush, so the host is never unfirewalled during the handoff. Add inbound ports to `/etc/nftables.conf` as needed.

> [!NOTE]
> `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete every `loader/entries/` entry before regenerating — including foreign/other-OS BLS entries. EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` / `fstab` |
| mkinitcpio rollback | byte-exact revert on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Instance lock | atomic `mkdir 0700`; dead/recycled-PID reclaim via `/proc` (fail-closed) |

The process exit code is the single source of truth.

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, 129 HUP, 131 QUIT) |

Environment overrides (each falls back safely when unset or invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables), `RY_INSTALL_SKIP_HARDWARE_CHECK=1` (bypass CPU match), `NO_COLOR`, `TMPDIR`.

Logs: one JSONL file per run under `~/ry-install/logs/<date>/`, not auto-pruned.

## Uninstall

No automated uninstaller; use Managed Files as the rollback reference.

1. `sudo systemctl unmask` the masked units.
2. `sudo rm` the deployed system paths; `rm` the user env.d file.
3. Restore `/etc/fstab` from `/etc/fstab.ry.bak`; delete the `.ry.bak` backups.
4. Optionally reverse the package changes.
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | out-of-tree firmware package (unmanaged) |
| MT7925 | kernel panics, low TX power, random deauth | out-of-tree DKMS module; some upstream |
| RTL8127 10GbE | throughput drops under load | out-of-tree DKMS module (unmanaged) |
| Strix Halo ACP | no ASoC machine driver | pending upstream (HDMI/USB audio unaffected) |
| NM + iwd | intermittent boot connectivity | `nmcli radio wifi off; and nmcli radio wifi on` |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Rebuild refused | a phase tainted boot state — fix the cause, then re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire / ddcutil permission denied | `sudo usermod -aG realtime,i2c $USER`, re-login |

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
