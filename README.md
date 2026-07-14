# ry-install

[![version](https://img.shields.io/badge/version-7.104.0-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish-1793d1?style=flat-square)](https://fishshell.com)

> Idempotent CachyOS config manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 17 embedded configs — atomic, byte-verifiable (`--verify`), reversible ([Uninstall](#uninstall)).

## Quick Start

> [!IMPORTANT]
> Run as your normal user (root refused, exit 2; root `--check`: silent exit 3); cache sudo first (`sudo -v`). The unattended run **removes packages** ([Configuration](#configuration)). Reboot, then `--verify`; re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.104.0
chmod +x ry-install.fish
./ry-install.fish
```

**In scope:** kernel cmdline, initramfs, systemd units, NetworkManager, Bluetooth, sysctl, gaming env vars, MangoHud, pacman add/remove, and sdboot-manage BLS entries. **Out of scope:** dotfiles, secrets, backups, multi-user, non-CachyOS, laptops, and UKI.

## Requirements

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| Kernel | ≥ 6.18.4 (hard-fail, no override; `--verify` warns only) — regression floor (RTL8127 + suspend) |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`; `--verify` warns only) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Preflight hard-fails (exit 3) on missing/non-GNU deps (busybox/uutils rejected), a sub-6.18.4 kernel, or uncached sudo (non-TTY; a TTY prompts once). NTP sync and a missing `pactree` warn only; an unsynced clock with no NTP client auto-enables `systemd-timesyncd` + RTC writeback.

## BIOS

Strix Halo multi-thread gains [flatten](https://strixhalo.wiki/Guides/Power-Modes-and-Performance) past ~85 W, so a flat `SPL = fPPT = sPPT = 85 W` ceiling trades the stock 140 W boost for near-peak throughput on a quiet, constant fan curve. [STAPM](https://skatterbencher.com/amd-precision-boost-2/) tracks a laptop skin temperature (irrelevant on a desktop), so the boost/time-constant rows zero it; `TjMax 90` holds 10 °C under the silicon limit. Full walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference).

`Advanced → SMU Common Options` — power limits in mW, time constants in s, TjMax in °C:

| Setting | Value |
|---|---|
| ECO Mode | `Disabled` |
| SPL Control | `Manual` |
| Sustained Power Limit | `85000` |
| PPT Control | `Manual` |
| Fast PPT Limit | `85000` |
| Slow PPT Limit | `85000` |
| Slow PPT Time Constant | `0` |
| STAPM Control | `Manual` |
| System Temperature Tracking | `Auto` |
| STAPM Boost Override | `1` |
| STAPM Boost | `0` |
| Tskin Time Constant (STAPM) | `0` |
| Thermal Control | `Manual` |
| TjMax | `90` |

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` / `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits 4 — **do not reboot** until it succeeds. A non-vfat `/boot` ESP fallback also refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Unattended install (silent; phase matrix at end) |
| `-V`/`--verbose` | Stream per-command install output (ignored under `--check`) |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Silent idempotency probe vs live `/proc/cmdline` — a fresh install reads drift until reboot ([Exit Codes](#exit-codes)) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End of options (no positional args) |
| `-h`/`--help` · `-v`/`--version` | Honored before all checks, including the root guard |

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving (`realpath -m`) to a managed destination. Deploy modes and `--check` hard-gate hardware, kernel floor, and key/count invariants (exit 3); `--verify` downgrades hardware and kernel floor to warnings.

### Environment Overrides

Safe fallback when unset or invalid. One JSONL log per run: `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl` (`0600`).

| Variable | Effect |
|---|---|
| `RY_RUN_TIMEOUT` | Per-command cap. Default `3600` s; `0` disables; package/boot ops floor `7200` s; invalid → default |
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | Bypass the `Ryzen AI Max` CPU-match hard-fail (`--verify` warns) |
| `NO_COLOR` | Disable colored output when set — any value, including empty ([no-color.org](https://no-color.org)) |

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | hard gates → lock → config checks (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

Results print to stderr; a JSONL log records each phase. `WARN` keeps exit 0; `DEFER` applies on next boot; a boot-critical failure (exit 4) must be resolved before rebooting.

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an IPv4-only nftables default-deny-inbound ruleset (loopback, established/related, inbound ping accepted; `forward` drop, `output` accept). IPv6 disabled system-wide (`ipv6.disable=1`).

The fallback BLS entry boots `LINUX_FALLBACK_OPTIONS="quiet"` only — IPv6 and AMD-Vi revert to kernel defaults, though the IPv4-only ruleset and the `amdxdna` blacklist still apply.

Game-streaming inbound is off (`RY_REMOTE_PLAY_PORTS=false`); set `true` and re-run to append Sunshine/Moonlight + Steam Remote Play accepts.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch (backup targets) |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `/etc/kernel/cmdline` / `/etc/sdboot-manage.conf` / `mkinitcpio.conf` (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (gated by `cmp`) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Entry regeneration | `REMOVE_EXISTING=yes` deletes all `loader/entries/` before regeneration; EFI-resident loaders (e.g. Windows Boot Manager) untouched |
| Instance lock | atomic `mkdir 0700`; stale reclaim only for a provably-recycled PID (`/proc` start-time); else fail-closed |

### Exit Codes

| Code | Meaning | Emitted when |
|---|---|---|
| `0` | OK | Success; also `WARN`-only runs and `--check` clean |
| `1` | verify-FAIL / install-error | `--verify` mismatch, or an install step errored |
| `2` | usage | Bad args, non-absolute/unmanaged `--install-file`, root-guard misuse |
| `3` | preflight | Missing/non-GNU dep, sub-`KERNEL_MIN` kernel, uncached sudo, gate mismatch |
| `4` | boot-critical (DO NOT REBOOT) | Boot cascade or post-rebuild sanity failed — resolve before rebooting |
| `5` | lock | Another instance holds the lock (fail-closed on ambiguous pidfile) |
| `10` | `--check` drift | Config drift from the managed baseline |

## Configuration

All tunables are `set -g` globals near the top of the script — no external config file. Edit one, then re-run (or `--install-file` the affected file).

### Globals

Perms: system `0644`, user `0600`. CachyOS divergences:

| Divergence | Value |
|---|---|
| `DNSSEC` | `allow-downgrade` (vendor default is DoH) |
| sysctl priority | `95` — loads after vendor `70-cachyos-settings.conf` |
| NVMe scheduler | `none` (vendor default is `kyber`) |
| AMD P-State EPP | `balance_performance` |
| `sdboot-manage` | `REMOVE_EXISTING=yes` ([Safety & Reliability](#safety--reliability)) |

### Packages

`pacman -Rns` is rdep-aware via `pactree` (from `pacman-contrib`, which also supplies `paccache`). Phase 2 re-marks every `PKGS_ADD` package explicit after `-Syu`, so a later `-Rns` cannot orphan a dependency-installed one. Reversible ([Uninstall](#uninstall)). Existing installs: `archlinux-contrib` is no longer managed — optional `sudo pacman -Rns archlinux-contrib`.

| Action | Packages |
|---|---|
| Install | gaming (`cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`) · CLI (`fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`) · hardware (`nvme-cli`, `lm_sensors`, `ddcutil`) · RT audio (`rtkit`, `realtime-privileges`) · firewall (`nftables`) · contrib (`pacman-contrib`) |
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (chwd Vulkan drivers) |

### Units

| Action | Units |
|---|---|
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, `modemmanager`, `avahi-daemon` (`.service` + `.socket`), sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched | `systemd-oomd` (by design — kernel OOM-killer + zram is the intended path) |

### fstab

| Aspect | Behavior |
|---|---|
| Change | ext4 rows get `noatime,lazytime,commit=10` in column 4; everything else byte-preserved |
| Normalized away | redundant `defaults` / `relatime` / `atime` / `strictatime` / existing `commit=` tokens |
| Gates | line-count parity + size floor + mandatory `findmnt --verify` |
| Refused | a symlinked `/etc/fstab` — the whole rewrite aborts |
| Preserved + warned | malformed (whitespace-split) rows — left byte-identical; conforming rows still rewritten |

## Managed Files

17 embedded config files, in deploy order; `--verify` checks every one against live state, `--install-file <path>` re-deploys one.

### Boot & initramfs

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot loader settings (default entry, timeout, console-mode) |
| `/etc/kernel/cmdline` | kernel command line: `rw root=UUID` prefix + the 17 `KERNEL_PARAMS` |
| `/etc/sdboot-manage.conf` | boot-entry generation (`REMOVE_EXISTING`, `LINUX_OPTIONS`) |
| `/etc/mkinitcpio.conf` | initramfs `MODULES` / `HOOKS` / `COMPRESSION` (default `zstd`) |

### System services & network

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | systemd-resolved: `DNSSEC=allow-downgrade`, no mDNS/LLMNR/DoT |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power/suspend/hibernate/reboot keys |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | silence info-level `nm-dispatcher` journal noise |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | NM Wi-Fi backend, power-save off, log level |
| `/etc/iw-regdomain` | wireless regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | BlueZ adapter auto-power-on + paired-sink reconnect |
| `/etc/nftables.conf` | IPv4-only default-deny-inbound firewall (inbound ping allowed) |

### Power, modules & user session

| File | Purpose |
|---|---|
| `/etc/default/cpupower-service.conf` | CPU governor (`powersave`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | sysctl tunables (BBR + `fq`, VM, netdev) |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, AMD P-State EPP, GPU DPM |
| `/etc/modprobe.d/60-ry-modules.conf` | `amdxdna` blacklist (toggle `BLACKLIST_AMDXDNA`) |
| `~/.config/environment.d/10-environment.conf` | gaming env vars (RADV, MangoHud, Proton, VKD3D) |
| `~/.config/MangoHud/MangoHud.conf` | readout-only performance HUD |

## Tuning Notes

Rationale for non-obvious choices; several list an override to reverse.

| Topic | Detail |
|---|---|
| Large-VRAM compute | GTT caps usable VRAM near 62 GiB; raise the BIOS UMA carveout (≤96 GiB) for larger allocations — `amdgpu.gttsize` is deprecated. Verify: `cat /sys/module/ttm/parameters/pages_limit`. |
| FSR4 on RDNA3 | `PROTON_FSR4_RDNA3_UPGRADE=1` ships enabled (FSR4 on RDNA3/3.5 via Proton-CachyOS). Verify: `printenv PROTON_FSR4_RDNA3_UPGRADE`. |
| NTSYNC | `--verify` reports `/dev/ntsync` (present ok · module-without-node warn · absent info). Opt a title out: `PROTON_NO_NTSYNC=1`. |
| MangoHud `cpu_temp` | Ships disabled: re-enabling `cpu_temp` re-trips [MangoHud #1794](https://github.com/flightlessmango/MangoHud/issues/1794) (`cpu_power` reads 0 when `cpu_temp` is enabled on Zen 5). |
| PCIe ASPM | `pcie_aspm=off` disables ASPM link-power management globally (MT7925 coredump / BT-reconnect / assoc mitigation, plus NVMe latency); drop the token to restore kernel ASPM defaults. |
| IPv6 | Disabled via `ipv6.disable=1`; ruleset is IPv4-only. For dual-stack: drop the token, add IPv6 rules, re-run. |
| Avahi | `.service`+`.socket` masked — collided with resolved as a second mDNS responder (`hostname-2.local`); the profile runs mDNS off (`MulticastDNS=no`). Unmask both to restore. |
| AMD-Vi (IOMMU) | `amd_iommu=off` disables AMD-Vi and breaks the XDNA NPU (hence the blacklist). NPU/VFIO/SR-IOV: set `amd_iommu=on iommu=pt` + `BLACKLIST_AMDXDNA false`, re-run. |
| UMIP (`clearcpuid=umip`) | Disables UMIP trapping; taints the kernel. String form is version-stable. Drop the token if no `umip_printk` stutter appears. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference. Manual uninstall — 6 steps, in order:

| # | Step | Action |
|---|---|---|
| 1 | Unmask units | `sudo systemctl unmask` all 12 masked units — exact set in [Units](#units) |
| 2 | Remove configs | `sudo rm` managed system files + `rm` the 2 user files — skip the 4 boot files (step 3 reverts them) |
| 3 | Revert boot files + fstab | `.ry.bak` → `loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `mkinitcpio.conf`, `/etc/fstab` (if present); then delete the `.ry.bak` files |
| 4 | Reverse packages (optional) | `pacman -S --needed` the **Remove** row, `pacman -Rns` the **Install** row — exact lists in [Packages](#packages) |
| 5 | Rebuild initramfs + entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

Boot files must be reverted before step 5 — it regenerates entries from that state. A `.ry.bak` exists only if the file was present before the overwrite (fstab: only if rewritten). If ry-install enabled `systemd-timesyncd`: `sudo systemctl disable --now systemd-timesyncd` (optional).

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Rebuild refused | a phase tainted boot state — fix the cause, re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login (needs `realtime-privileges`) |
| ddcutil permission denied | `sudo usermod -aG i2c $USER`, re-login (needs `ddcutil`) |
| BT speaker won't auto-reconnect | `bluetoothctl trust <MAC>`, then power the speaker on after login so it re-initiates |

> [!NOTE]
> The installer prints `usermod` hints but never runs them; group changes need re-login and aren't auto-reverted.

## Contributing

PRs welcome. For config changes, include before/after `--verify`/`--check` output. Lint with `fish --no-execute`, keep comments single-line, and update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, and kernel cmdline. Review the nftables ruleset, `KERNEL_PARAMS`, and `PKGS_DEL` before running. Report concerns via GitHub issues or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
