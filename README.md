# ry-install

[![version](https://img.shields.io/badge/version-7.85.3-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish-1793d1?style=flat-square)](https://fishshell.com)

> Idempotent, reversible CachyOS config manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151). One fish script, 17 embedded configs. Atomic, byte-verifiable (`--verify`), hand-reversible ([Uninstall](#uninstall)).

## Quick Start

> [!IMPORTANT]
> Run as normal user (root refused, exit 2; `--check` stays silent, exit 3); `sudo -v` first. Unattended run **removes packages** ([Configuration](#configuration)). Reboot, then `--verify`.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.85.3
chmod +x ry-install.fish
./ry-install.fish
```

| Scope        | Items                                                                             |
|--------------|-----------------------------------------------------------------------------------|
| In scope     | cmdline, initramfs, units, NM, Bluetooth, sysctl, gaming env, MangoHud, pacman    |
| Out of scope | dotfiles, secrets, backups, multi-user, non-CachyOS, laptops, UKI                 |

## Requirements

| Requirement    | Minimum                                                                         |
|----------------|---------------------------------------------------------------------------------|
| Platform       | CachyOS · systemd-boot · ext4 root                                              |
| Kernel         | ≥ 6.19 (override `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`)                        |
| fish / systemd | ≥ 3.6 / ≥ 250                                                                   |
| Hardware       | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`)        |
| Free space     | 2 GiB `/` (warn < 5) · 200 MiB `/boot` (warn < 500)                             |

Preflight hard-fails (exit 3) on missing deps (`pacman`, `systemctl`, `mkinitcpio`, `sdboot-manage`, `findmnt`, `sha256sum`, `curl`, GNU coreutils/findutils/diffutils — busybox/uutils rejected), sub-6.19 kernel, or uncached sudo. Unsynced clock with no NTP client → `systemd-timesyncd` enabled + RTC writeback (skip: `RY_NO_NTP_REMEDIATION=1`).

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; cascade failure exits 4 with a DO-NOT-REBOOT banner — **do not reboot** until it succeeds. Non-vfat `/boot` ESP also refuses sdboot (exit 4).

| Flag                             | Action                                                        |
|----------------------------------|---------------------------------------------------------------|
| *(no args)*                      | full unattended install (silent; phase matrix at end)         |
| `-V, --verbose`                  | stream per-command install output (ignored under `--check`)   |
| `--verify`                       | config files byte-for-byte, then live system state            |
| `--check`                        | silent probe: `0` clean · `3` preflight · `10` drift          |
| `--install-file <abs-path>`      | re-deploy a single managed file                               |
| `--`                             | end of options (no positional args)                           |
| `-h`/`--help` · `-v`/`--version` | honored before all checks, including root guard               |

`--verify`/`--check` are lock-free, read-only. `--install-file` requires an absolute path resolving to a managed destination (else exit 2). All modes run the runtime-init gates first — exit 3 on mismatched host.

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run.

| # | Phase         | Action                                                                       |
|---|---------------|------------------------------------------------------------------------------|
| 1 | Preflight     | config checks → lock → hard gates (read-only)                                |
| 2 | Packages      | `pacman -Syu`; `mkinitcpio.conf` pre-deployed → one initramfs rebuild        |
| 3 | Configuration | deploy 17 embedded configs atomically                                        |
| 4 | Services      | fstab → resolved → pkg removal → mask (nftables first) → enable → regdom     |
| 5 | Boot          | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity       |
| 6 | Finalize      | user `daemon-reload` → `paccache` → NetworkManager restart                   |

`WARN` keeps exit `0`; `DEFER` applies on next boot; exit 4 must be resolved before rebooting.

## Safety & Reliability

> [!WARNING]
> Masks `ufw`; ships nftables **default-deny-inbound** (established/related + loopback accepted, inbound IPv4 ping dropped, essential ICMPv6 accepted; `forward` drop, `output` accept). `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete all `loader/entries/` (including other-OS BLS); EFI-resident loaders untouched.

Game streaming off by default (`RY_REMOTE_PLAY_PORTS=false`); set `true` and re-run for Sunshine/Moonlight + Steam Remote Play inbound accepts.

| Feature             | Detail                                                                     |
|---------------------|----------------------------------------------------------------------------|
| Atomic writes       | tmp → render → symlink probe → backup → chmod → `mv -T` → re-verify        |
| Auto backups        | `<path>.ry.bak`: `loader.conf` · `mkinitcpio.conf` · `fstab` (rewrite)     |
| mkinitcpio rollback | byte-exact revert (`cmp`-gated) on `pacman -Syu` failure or signal         |
| Boot gates          | tainted phase refuses rebuild; sdboot refused when `$BOOT` unresolvable    |
| Instance lock       | atomic `mkdir 0700`; reclaim only provably-recycled PIDs                   |

**Exit codes** `0` ok · `1` verify-FAIL/install-error · `2` usage · `3` preflight · `4` boot-critical (DO NOT REBOOT) · `5` lock · `10` `--check` drift.

Env overrides: `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables, >9 digits clamp to `2147483647`; `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile` exempt), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`, `RY_NO_NTP_REMEDIATION=1`, `NO_COLOR`, `TMPDIR`. Log: one JSONL/run at `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl` (`0600`).

## Configuration

Tunables are `set -g` globals at the top of the script — no external config file. Edit, re-run (or `--install-file` the affected file).

### Globals

Perms: system `0644`, user `0600`. CachyOS divergences: `DNSSEC=allow-downgrade`, sysctl priority 95, NVMe sched `none`, AMD P-State EPP `balance_performance`, `sdboot-manage REMOVE_EXISTING=yes`.

### Packages

`pacman -Rns` is rdep-aware via `pactree` (if absent, pacman's own refusal is the only gate — an external dependant skips + logs).

| Action          | Count | Packages                                                               |
|-----------------|-------|------------------------------------------------------------------------|
| Install         | 17    | full list below                                                        |
| Remove (`-Rns`) | 9     | full list below                                                        |
| Verify present  | 2     | `vulkan-radeon` · `lib32-vulkan-radeon`                                |

```text
Install : nvme-cli cachyos-gaming-meta cachyos-gaming-applications lib32-mesa
          mkinitcpio-firmware fd sd dust procs bottom htop git-delta lm_sensors
          rtkit realtime-privileges ddcutil nftables
Remove  : plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme
          breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update
          kdeconnect
```

### Units

| Action     | Units                                                                               |
|------------|-------------------------------------------------------------------------------------|
| Mask (10)  | `ananicy-cpp` · `power-profiles-daemon` · `NetworkManager-wait-online` · `ufw` ·    |
|            | `modemmanager` · sleep / suspend / hibernate / hybrid-sleep / s-t-h targets         |
| Enable (5) | `fstrim.timer` · `NetworkManager` · `cpupower` · `nftables` · `bluetooth`           |
| Untouched  | `systemd-oomd` (kernel OOM-killer + zram is the intended path)                      |

### fstab

| Aspect          | Behavior                                                                       |
|-----------------|--------------------------------------------------------------------------------|
| Change          | ext4 rows get `noatime,lazytime,commit=10` in column 4; rest byte-preserved    |
| Normalized away | redundant `defaults` / `relatime` / `atime` / `strictatime` / old `commit=`    |
| Gates           | line-count parity + size floor + mandatory `findmnt --verify`                  |
| Refused         | symlinked or malformed `/etc/fstab` (left untouched)                           |

## Managed Files

17 embedded configs; `--verify` checks each against live state, `--install-file <path>` re-deploys one.

### Boot

| File                       | Purpose                                                             |
|----------------------------|---------------------------------------------------------------------|
| `/boot/loader/loader.conf` | systemd-boot loader settings                                        |
| `/etc/kernel/cmdline`      | `root=UUID` prefix + the 16 `KERNEL_PARAMS`                         |
| `/etc/sdboot-manage.conf`  | boot-entry generation (`REMOVE_EXISTING`, `LINUX_OPTIONS`)          |
| `/etc/mkinitcpio.conf`     | initramfs `MODULES` / `HOOKS` / `zstd`                              |

### systemd drop-ins (under `/etc/systemd/`)

| File                                       | Purpose                                             |
|--------------------------------------------|-----------------------------------------------------|
| `resolved.conf.d/99-cachyos-resolved.conf` | `DNSSEC=allow-downgrade`; no mDNS/LLMNR/DoT         |
| `logind.conf.d/99-cachyos-logind.conf`     | ignore power/suspend/hibernate/reboot keys          |
| `...dispatcher.service.d/logging.conf`     | silence nm-dispatcher journal noise                 |

### Network

| File                                            | Purpose                                        |
|-------------------------------------------------|------------------------------------------------|
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | Wi-Fi backend, power-save off, log level       |
| `/etc/iw-regdomain`                             | wireless regulatory domain (`US`)              |

### Bluetooth & firewall

| File                       | Purpose                                                             |
|----------------------------|---------------------------------------------------------------------|
| `/etc/bluetooth/main.conf` | adapter auto-power-on + paired-sink reconnect                       |
| `/etc/nftables.conf`       | default-deny-inbound ruleset                                        |

### Power, performance & modules

| File                                 | Purpose                                                   |
|--------------------------------------|-----------------------------------------------------------|
| `/etc/default/cpupower-service.conf` | CPU governor (`powersave`)                                |
| `/etc/sysctl.d/95-ry-overrides.conf` | sysctl tunables (BBR + `fq`, VM, netdev)                  |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe sched `none` · AMD P-State EPP · GPU DPM             |
| `/etc/modprobe.d/60-ry-mt7925e.conf` | disable PCIe ASPM on MT7925                               |

### User session

| File                                          | Purpose                                          |
|-----------------------------------------------|--------------------------------------------------|
| `~/.config/environment.d/10-environment.conf` | gaming env vars (RADV, MangoHud, Proton)         |
| `~/.config/MangoHud/MangoHud.conf`            | readout-only performance HUD                     |

## Tuning Notes

| Topic                   | Detail                                                                 |
|-------------------------|------------------------------------------------------------------------|
| Large-VRAM compute      | GTT caps VRAM ~62 GiB; raise BIOS UMA carveout, not `amdgpu.gttsize`   |
| FSR4 on RDNA3           | `PROTON_FSR4_RDNA3_UPGRADE=1` ships enabled                            |
| NTSYNC                  | `/dev/ntsync` asserted; per-title opt-out: `PROTON_NO_NTSYNC=1`        |
| MT7925 ASPM             | `disable_aspm=1` mitigation; remove if a kernel bump resolves it       |
| AMD-Vi (IOMMU)          | `amd_iommu=off` ships; VFIO/SR-IOV: `amd_iommu=on iommu=pt`, re-run    |
| UMIP (`clearcpuid=514`) | UMIP off (kernel tainted); drop if no `umip_printk` stutter            |

## Uninstall

No automated uninstaller; [Managed Files](#managed-files) is the rollback reference. 6 steps, in order (commands below):

| # | Step             | Detail                                                                    |
|---|------------------|---------------------------------------------------------------------------|
| 1 | Unmask units     | restore the 10 masked units                                               |
| 2 | Remove files     | delete the 13 system files, then the 2 user files                         |
| 3 | Restore backups  | `fstab.ry.bak` back into place; delete remaining `.ry.bak`                |
| 4 | Reverse packages | optional: reinstall removed set, remove installed set                     |
| 5 | Rebuild boot     | `mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update`            |
| 6 | Reboot           | `sudo systemctl reboot`                                                   |

```fish
# 1 — unmask
sudo systemctl unmask ananicy-cpp.service power-profiles-daemon.service \
    NetworkManager-wait-online.service ufw.service modemmanager.service \
    sleep.target suspend.target hibernate.target hybrid-sleep.target \
    suspend-then-hibernate.target
# 2 — remove managed files (system, then user)
sudo rm /etc/sdboot-manage.conf /etc/sysctl.d/95-ry-overrides.conf \
    /etc/udev/rules.d/99-ry-perf.rules /etc/modprobe.d/60-ry-mt7925e.conf \
    /etc/iw-regdomain /etc/bluetooth/main.conf /etc/nftables.conf \
    /etc/default/cpupower-service.conf \
    /etc/NetworkManager/conf.d/99-cachyos-nm.conf \
    /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf \
    /etc/systemd/logind.conf.d/99-cachyos-logind.conf \
    /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf
rm ~/.config/environment.d/10-environment.conf ~/.config/MangoHud/MangoHud.conf
# 3 — restore backups
sudo test -f /etc/fstab.ry.bak; and sudo mv /etc/fstab.ry.bak /etc/fstab
sudo rm -f /boot/loader/loader.conf.ry.bak /etc/mkinitcpio.conf.ry.bak
# 4 — reverse package changes (optional)
sudo pacman -S --needed plymouth cachyos-plymouth-bootanimation \
    cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro \
    cachyos-micro-settings cachy-update kdeconnect
sudo pacman -Rns nvme-cli cachyos-gaming-meta cachyos-gaming-applications \
    lib32-mesa mkinitcpio-firmware fd sd dust procs bottom htop git-delta \
    lm_sensors rtkit realtime-privileges ddcutil nftables
# 5 — rebuild boot
sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update
# 6 — reboot
sudo systemctl reboot
```

For boot files, revert their contents (or `.ry.bak`) before step 5. If ry-install enabled `systemd-timesyncd`: optionally `sudo systemctl disable --now systemd-timesyncd`.

## Known Issues

| Component      | Issue                          | Status                                         |
|----------------|--------------------------------|------------------------------------------------|
| Strix Halo GPU | MES page faults                | resolved (MES 0x86 firmware)                   |
| RTL8127 10GbE  | throughput drops; suspend hang | resolved (≥ 6.19 floor; no DKMS)               |
| MT7925         | panics, low TX power, deauth   | open (out-of-tree DKMS)                        |
| Strix Halo ACP | no ASoC machine driver         | open (HDMI/USB audio unaffected)               |

### Known-benign log lines

`ModemManager1 … could not be found` · `acp_asoc_acp70 … No matching ASoC machine driver` · boltd `unknown NHI PCI id` · `charge thresholds not supported` / `no backlight interface` · `Unlikely small volume range`.

## Troubleshooting

| Problem                    | Fix                                                                 |
|----------------------------|---------------------------------------------------------------------|
| Boot failure               | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen`    |
| Rebuild refused            | a phase tainted boot state — fix cause, re-run                      |
| `--verify` drift           | `./ry-install.fish --install-file /etc/...`                         |
| Lock held, no live PID     | `rm -rf ~/ry-install/.lock`; re-run                                 |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login                         |
| ddcutil permission denied  | `sudo usermod -aG i2c $USER`, re-login                              |
| BT sink no auto-reconnect  | `bluetoothctl trust <MAC>`, power sink on after login               |

> [!NOTE]
> The installer prints missing-group `usermod` commands but never runs them.

## Contributing

PRs: include before/after `--verify` + `--check` output, lint with `fish --no-execute`, single-line comments, update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, kernel cmdline. Review before running. Report via GitHub issues or privately.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
