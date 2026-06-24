# ry-install

[![version](https://img.shields.io/badge/version-7.70.0-1793d1?style=flat-square)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46?style=flat-square&logo=fishshell&logoColor=white)](https://fishshell.com)
[![systemd](https://img.shields.io/badge/systemd-%E2%89%A5%20250-30b9db?style=flat-square)](https://systemd.io)
[![CachyOS](https://img.shields.io/badge/distro-CachyOS-1793d1?style=flat-square)](https://cachyos.org)

> Idempotent, reversible CachyOS configuration manager for the Beelink GTR9 Pro
> (Ryzen AI Max+ 395 / Radeon 8060S / gfx1151 / Strix Halo).

One self-contained fish script: 17 embedded configs, gaming/LLM desktop profile.

## Contents

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Configuration](#configuration)
- [Managed Files](#managed-files)
- [Safety & Reliability](#safety--reliability)
- [Uninstall](#uninstall)
- [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

## Quick Start

> [!IMPORTANT]
> Run as your normal user — **root is refused (exit 2)**; cache sudo first (`sudo -v`). The unattended run **removes packages** (see [Configuration](#configuration)). Reboot afterward, then `--verify`. Re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.70.0
chmod +x ry-install.fish
./ry-install.fish
```

| In scope | Out of scope |
|---|---|
| Kernel cmdline, initramfs, systemd units, NetworkManager, Bluetooth, sysctl, gaming env vars, MangoHud, KDE Baloo, pacman add/remove, sdboot-manage BLS entries | Dotfiles, secrets, backups, multi-user, non-CachyOS, laptops, UKI |

## Requirements

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Hard deps abort read-only in preflight (exit 3): `pacman`, `systemctl`, `mkinitcpio`, `sdboot-manage`, `findmnt`, `sha256sum`, `curl`, GNU coreutils, findutils, diffutils. busybox/uutils rejected. NTP sync and `paccache` only warn; sudo must be cached.

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits 4 and prints the DO-NOT-REBOOT banner — **do not reboot** until it succeeds. A non-vfat `/boot` ESP also refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output (ignored under `--check`) |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Silent idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End of options (no positional args) |
| `-h`/`--help` · `-v`/`--version` | Honored before all checks, including the root guard |

`--verify`/`--check` are lock-free and read-only. `--install-file` requires an absolute path resolving via `realpath -m` to a managed destination. Malformed args rejected before dispatch (exit 2); well-formed non-managed paths after ("Not a managed file", exit 2).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run. mkinitcpio rollback restores the prior `mkinitcpio.conf` byte-for-byte on such failure or on signal.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock → hard gates (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

A CHECK/RESULT/EVIDENCE matrix prints to stderr; a JSONL log records each phase. `WARN` keeps exit `0`; `DEFER` applies on next boot (e.g. regdomain, via CachyOS device-add hooks).

## Configuration

Source of truth is the script; retune the `set -g` globals near the top.

> [!NOTE]
> The full per-file reference is collapsed below — click to expand.

<details>
<summary><strong>Full managed-file reference</strong> — all 17 files, key values</summary>

| File | Purpose & key values |
|---|---|
| loader.conf | `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| kernel cmdline | `rw root=UUID=<root>` (resolved) + `8250.nr_uarts=0`, `amd_pstate=active`, `iommu=pt`, `clearcpuid=514`, `nowatchdog`, `nvme_core.default_ps_max_latency_us=0`, `pcie_aspm.policy=performance`, `quiet`, `split_lock_detect=off`, `tsc=reliable`, `usbcore.autosuspend=-1`, `zswap.enabled=0` |
| sdboot-manage.conf | `DEFAULT_ENTRY=manual`, `OVERWRITE_EXISTING=yes`, `REMOVE_EXISTING=yes` (wipes `loader/entries/` before regen), `REMOVE_OBSOLETE=yes`; `LINUX_OPTIONS`=cmdline params, `LINUX_FALLBACK_OPTIONS="quiet"` |
| mkinitcpio.conf | `MODULES=(amdgpu)`; `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`; `COMPRESSION="zstd"` (`-1 -T0`); `BINARIES=()`, `FILES=()` |
| resolved | `MulticastDNS=no`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` (plaintext DNS; diverges from CachyOS DoH default) |
| logind | `Handle{Power,Suspend,Hibernate,Reboot}Key`=ignore (+ `LongPress` variants) |
| NetworkManager-dispatcher | `LogLevelMax=notice` drop-in — silences routine info-level `nm-dispatcher` journal spam (journald transport, so `StandardError=null` is ineffective) |
| NetworkManager | wpa_supplicant backend (NM default; chosen over iwd for MT7925 stability). Power-save off (`wifi.powersave=2`); `logging level=WARN`. Opt into iwd via `NM_WIFI_BACKEND=iwd` + re-run |
| iw-regdomain | regulatory domain fixed `US` (retune `COUNTRY`); consumed by CachyOS hooks at device-add |
| bluetooth main.conf | `AutoEnable=true`, `FastConnectable=true`, `ReconnectAttempts=3` (intervals omitted → BlueZ default backoff). Fixes BlueZ skipping `AutoEnable` when `main.conf` absent. Per-device reconnect needs one-time `bluetoothctl trust <MAC>` |
| nftables.conf | default-deny-inbound (see [Safety & Reliability](#safety--reliability)) |
| cpupower / udev | `powersave` governor; udev sets NVMe scheduler `none`, AMD P-State EPP `balance_performance`, gfx1151 clock-floor (`power_dpm_force_performance_level=high`, `KERNEL=="card[0-9]"`) |
| sysctl | BBR + `fq`; `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0`, `netdev_budget=600`/`budget_usecs=5000`, `vm.compaction_proactiveness=0`, `vm.max_map_count=2147483642`, `vm.page-cluster=0`, `vm.swappiness=150`, `vm.vfs_cache_pressure=50` (zram-tuned; priority 95, after vendor `70-cachyos-settings.conf`) |
| environment.d | gaming env: `AMD_VULKAN_ICD=RADV`, `MANGOHUD=1`, `MESA_SHADER_CACHE_MAX_SIZE=16G`, `PROTON_ENABLE_WAYLAND=1`, `PROTON_LOCAL_SHADER_CACHE=1`, `WINEDEBUG=-all`, DXVK/VKD3D logging off (`0600`) |
| baloofilerc | KDE Baloo indexing disabled (`0600`) |
| MangoHud.conf | readout-only HUD: GPU/CPU sensors, unified memory (`vram`+`ram`), FPS + frametime. Auto-enabled via `MANGOHUD=1`; toggle `Shift_R+F12` (`0600`) |

</details>

**Packages** — the no-args run removes `PKGS_DEL` with `pacman -Rns` (rdep-aware: skipped + logged if an external package depends on it). Reversible via [Uninstall](#uninstall).

| Action | Packages |
|---|---|
| Install | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `rtkit`, `realtime-privileges`, `ddcutil`, `nftables` |
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (chwd Vulkan drivers) |

**Units**

| Action | Units |
|---|---|
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, `modemmanager`, sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Untouched (opt-in) | `iwd.service` — unused while backend is wpa_supplicant. Set `NM_WIFI_BACKEND=iwd` + re-run to switch (Phase 4 then disables it so NM activates on demand) |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched (by design) | `systemd-oomd` — kernel OOM-killer + zram is the intended path on 128 GB. Do not enable |

**fstab** — ext4 entries get `noatime,lazytime,commit=10` rewritten in place; all other rows/columns preserved byte-for-byte. Gated by line-count parity, a size floor, and `findmnt --verify`; a symlinked `/etc/fstab` is refused; malformed ext4 rows left untouched with a warning.

## Managed Files

Path/permission index for the 17 files (values in [Configuration](#configuration)). System `0644`, user `0600`.

| Group | Files |
|---|---|
| Boot | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf`, `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` |
| Network | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/bluetooth/main.conf`, `/etc/nftables.conf` |
| Tuning | `/etc/default/cpupower-service.conf`, `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/udev/rules.d/60-ry-perf.rules` |
| User | `~/.config/environment.d/10-environment.conf`, `~/.config/baloofilerc`, `~/.config/MangoHud/MangoHud.conf` |

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an nftables **default-deny-inbound** ruleset: established/related + loopback accepted, inbound IPv4 ping dropped, essential ICMPv6 (NDP/PMTUD) accepted, all other inbound dropped. `forward` drop, `output` accept.

> [!NOTE]
> `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete all `loader/entries/` entries (including other-OS BLS) before regenerating. EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (gated by `cmp`) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Instance lock | atomic `mkdir 0700`; stale-lock reclaim only for a provably recycled PID via `/proc` start-time (unsignalable/unknown ⇒ fail-closed) |

> [!NOTE]
> Exit codes, internal sentinels, and environment overrides are collapsed below — click to expand.

<details>
<summary><strong>Exit codes, sentinels, and environment overrides</strong></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, 129 HUP, 131 QUIT, 134 ABRT) |

Sentinels `11`–`13` and `250`/`251`/`255` never reach a process exit (a generator failure surfaces as the footer `gen_fail` count).

Environment overrides (safe fallback when unset/invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables; `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile` exempt), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `NO_COLOR`, `TMPDIR`. Logs: one JSONL per run at `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl` (`0600`).

</details>

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference.

| # | Step | Command |
|---|---|---|
| 1 | Unmask | `sudo systemctl unmask ananicy-cpp.service power-profiles-daemon.service NetworkManager-wait-online.service ufw.service modemmanager.service sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target` |
| 2 | Remove system paths, then user env.d | `sudo rm /etc/sdboot-manage.conf /etc/sysctl.d/95-ry-overrides.conf /etc/udev/rules.d/60-ry-perf.rules /etc/iw-regdomain /etc/bluetooth/main.conf /etc/nftables.conf /etc/default/cpupower-service.conf /etc/NetworkManager/conf.d/99-cachyos-nm.conf /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf /etc/systemd/logind.conf.d/99-cachyos-logind.conf /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` then `rm ~/.config/environment.d/10-environment.conf ~/.config/baloofilerc ~/.config/MangoHud/MangoHud.conf` |
| 3 | Restore fstab, delete `.ry.bak` | `sudo mv /etc/fstab.ry.bak /etc/fstab` then `sudo rm -f /boot/loader/loader.conf.ry.bak /etc/mkinitcpio.conf.ry.bak` |
| 4 | Reverse package changes (optional) | `sudo pacman -S --needed plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update kdeconnect` then `sudo pacman -Rns nvme-cli cachyos-gaming-meta cachyos-gaming-applications lib32-mesa mkinitcpio-firmware fd sd dust procs bottom htop git-delta lm_sensors rtkit realtime-privileges ddcutil nftables` |
| 5 | Rebuild initramfs + entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

For boot files (`loader.conf`, `/etc/kernel/cmdline`, `mkinitcpio.conf`), step 5 regenerates entries from the restored/removed state; revert their contents (or restore `.ry.bak`) before step 5.

## Known Issues

Hardware gaps on Strix Halo.

| Component | Issue | Status |
|---|---|---|
| Strix Halo GPU | MES page faults | resolved (MES 0x86; current `linux-firmware` + shipped `mkinitcpio-firmware`) |
| RTL8127 10GbE | throughput drops under load | resolved — in-tree `r8169` (`f24f7b2f3af9` + suspend fix `ae1737e7339b`); no DKMS |
| MT7925 | kernel panics, low TX power, random deauth | open — out-of-tree DKMS; some fixes upstream. The `3 dBm` TX-power readout is cosmetic (correct power applied) |
| Strix Halo ACP | no ASoC machine driver | open — pending upstream (HDMI/USB audio unaffected) |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Rebuild refused | a phase tainted boot state — fix the cause, re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login (needs `realtime-privileges`) |
| ddcutil permission denied | `sudo usermod -aG i2c $USER`, re-login (needs `ddcutil`) |
| BT speaker won't auto-reconnect | adapter powers on at boot, but a paired sink needs trusting once: `bluetoothctl trust <MAC>` (then power the speaker on after login so it re-initiates) |

> [!NOTE]
> The installer detects missing `realtime`/`i2c` membership and prints these `usermod` commands but does not run them: a group change is inert until re-login and can't be cleanly reverted like the managed configs.

## Contributing

PRs welcome. For config changes, include before/after `--verify` and `--check` output; lint with `shellcheck` and `fish --no-execute`; keep comments single-line; update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, and kernel cmdline. Review before running. Report concerns via GitHub issues or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
