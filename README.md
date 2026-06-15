# ry-install

CachyOS configuration manager for the Beelink GTR Pro (Ryzen AI Max+ 395, gfx1151).

**Version 7.43.1 · fish ≥ 3.6 · CachyOS · MIT**

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
git checkout v7.43.1          # pin to a released tag; the exit-code/path contract below is version-coupled
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

> [!IMPORTANT]
> Run as your normal user — **root is refused (exit 2)**; sudo is invoked internally. Reboot, then `--verify`. Re-running is idempotent. The unattended run **removes packages** — see [Configuration](#configuration) before first run.

| In scope | Out of scope |
|---|---|
| Kernel cmdline | Dotfiles |
| Initramfs | Secrets |
| Systemd units | Backups |
| Network (NetworkManager + iwd) | Multi-user |
| Sysctl | Non-CachyOS |
| Gaming env vars | Laptops |
| KDE Baloo indexing | UKI |
| Pacman add/remove | — |
| sdboot-manage BLS entries | — |

A `—` marks an in-scope item with no out-of-scope counterpart; the two columns are independent lists, not paired rows.

## Requirements

Hard requirements abort read-only in preflight (exit 3): a GNU userland (coreutils, findutils, diffutils — `cmp` gates the byte-exact `mkinitcpio.conf` revert), plus `curl` and `findmnt`. NTP sync and `pacman-contrib` (pactree, for rdep-safe removal) only warn. sudo must be cached (`sudo -v`) and may lapse mid-run — set `timestamp_timeout` or a NOPASSWD drop-in.

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |

## Usage

Invoke as the normal user; flags are parsed left to right, with `--help`/`--version` honored before anything else.

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `-h`/`--help` · `-v`/`--version` | Honored first |

`--verify`/`--check` are lock-free and read-only; `--check` compares live `/proc/cmdline`, so pending changes read as drift until reboot. `--install-file` requires an absolute path resolving to a managed destination — anything else is refused (exit 2).

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits 4 — **do not reboot** until it succeeds. A non-vfat `/boot` ESP fallback also refuses sdboot (exit 4).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure taints the run and skips the Phase 5 boot rebuild; resolve the cause and re-run. All config writes are atomic renames.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock → hard gates (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed; `.pacnew` auto-resolved |
| 3 | Configuration | deploy embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → nftables → mask → enable → regdom |
| 5 | Boot | `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

A CHECK/RESULT/EVIDENCE matrix prints to stderr and the JSONL log records each phase. The verdict maps to the exit code; `WARN` keeps exit `0`, `DEFER` applies next boot.

## Configuration

The script is the source of truth — retune the `set -g` globals near the top; each managed file (listed under [Managed Files](#managed-files)) is one profile concern. The non-obvious knobs: `mkinitcpio.conf` ships `MODULES=(amdgpu)` + systemd hooks + zstd; the amdgpu/ttm modprobe sets a ~32 GiB GTT cap that assumes BIOS UMA 512 MB; cpupower/udev pin the `performance` governor + EPP and NVMe scheduler `none`; sysctl enables BBR + `fq`; environment.d carries the Mesa/RADV/DXVK/VKD3D/Proton gaming env. Wireless regdom is fixed at `US` (retune `COUNTRY`).

**Packages** — the no-args run removes the listed packages with `pacman -Rns` (rdep-aware: skipped for any package with an external installed reverse-dependency). Edit `PKGS_DEL` to keep any; removal is reversible via [Uninstall](#uninstall).

| Action | Packages |
|---|---|
| Install | `cachyos-gaming-meta`, `cachyos-gaming-applications`, `nvme-cli`, `lib32-mesa`, `mkinitcpio-firmware`, `nftables`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `realtime-privileges`, `ddcutil` |
| Remove (`-Rns`) | plymouth stack, `micro`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` |

**Units**

| Action | Units |
|---|---|
| Mask | `ufw`, `power-profiles-daemon`, `ananicy-cpp`, `NetworkManager-wait-online`, sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Disable (not mask) | `iwd.service` — NetworkManager is sole Wi-Fi manager, D-Bus-activates iwd on demand |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables` |

**fstab** — ext4 entries get `noatime,lazytime,commit=10` rewritten in place (existing `commit=` replaced); every other row and column is preserved byte-for-byte. Gated by line-count parity, a size floor, and a mandatory `findmnt --verify`; a symlinked `/etc/fstab` is refused.

## Managed Files

The Phase-3 files — the uninstall reference (system `0644`, user `0600`):

| Group | Files |
|---|---|
| Boot | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| Network | `/etc/iwd/main.conf`, `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/conf.d/wireless-regdom`, `/etc/nftables.conf` |
| Tuning | `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/default/cpupower-service.conf`, `/etc/modprobe.d/ry-amdgpu-strixhalo.conf`, `/etc/drirc.d/95-ry-radv-apu.conf`, `/etc/udev/rules.d/60-ry-perf.rules` |
| User | `~/.config/environment.d/10-environment.conf`, `~/.config/baloofilerc` |

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

Environment overrides (each falls back safely when unset or invalid): `RY_RUN_TIMEOUT` (per-command wall-clock cap, default `3600` s, `0` disables; **bypassed for `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile`**, since a SIGKILL mid-transaction corrupts `db.lck` or skips the mkinitcpio rollback — a hung package/boot op is not time-capped), `RY_INSTALL_SKIP_HARDWARE_CHECK=1` (bypass CPU match), `NO_COLOR`, `TMPDIR`.

Logs: one JSONL file per run under `~/ry-install/logs/<date>/`, not auto-pruned.

## Uninstall

No automated uninstaller; use Managed Files as the rollback reference.

| # | Step | Command |
|---|---|---|
| 1 | Unmask the masked units | `sudo systemctl unmask` |
| 2 | Remove deployed system paths; remove user env.d file | `sudo rm` / `rm` |
| 3 | Restore fstab, then delete `.ry.bak` backups | restore `/etc/fstab` from `/etc/fstab.ry.bak` |
| 4 | Optionally reverse the package changes | reinstall the removed set with `sudo pacman -S`; `sudo pacman -Rns` the installed set (both listed under [Configuration](#configuration)) |
| 5 | Rebuild initramfs and boot entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

## Known Issues

Hardware gaps specific to this Strix Halo platform; each is handled by an out-of-tree package this script does not manage.

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | out-of-tree firmware package (unmanaged) |
| MT7925 | kernel panics, low TX power, random deauth | out-of-tree DKMS module; some upstream |
| RTL8127 10GbE | throughput drops under load | out-of-tree DKMS module (unmanaged) |
| Strix Halo ACP | no ASoC machine driver | pending upstream (HDMI/USB audio unaffected) |

## Troubleshooting

Common failure modes and their recovery; boot-critical paths assume a live USB is on hand.

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Rebuild refused | a phase tainted boot state — fix the cause, then re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire / ddcutil permission denied | `sudo usermod -aG realtime,i2c $USER`, re-login |

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
