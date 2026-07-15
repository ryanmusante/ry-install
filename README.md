# ry-install

[![version](https://img.shields.io/badge/version-7.105.15-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish-1793d1?style=flat-square)](https://fishshell.com)

> Idempotent CachyOS config manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 17 embedded configs — atomic, byte-verifiable (`--verify`), reversible ([Uninstall](#uninstall)).

## Quick Start

> [!IMPORTANT]
> Run as your normal user; cache sudo first (`sudo -v`). The unattended run **removes packages** ([Configuration](#configuration)). Reboot, then `--verify`; re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.105.15
chmod +x ry-install.fish
./ry-install.fish
```

**In scope:** kernel cmdline, initramfs, systemd units, NetworkManager, Bluetooth, sysctl, gaming env vars, MangoHud, pacman add/remove, sdboot-manage BLS entries. **Out of scope:** dotfiles, secrets, backups, multi-user, non-CachyOS, laptops, UKI.

## Requirements

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| Kernel | 6.18.4 advisory floor (not enforced) — regression baseline (RTL8127 + suspend) |
| Mesa | ≥ 26.0 (below: soft warn only) |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`; `--verify` warns only) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Preflight hard-fails (exit 3) on missing/non-GNU deps (busybox/uutils rejected) or uncached sudo (non-TTY; a TTY prompts once). NTP sync and a missing `pactree` warn only; an unsynced clock with no NTP client auto-enables `systemd-timesyncd` + RTC writeback.

## BIOS

The walkthrough below is collapsible — click/tap the summary to expand.

<details>
<summary>85 W power ceiling — 14 SMU settings</summary>

Strix Halo multi-thread gains flatten past ~85 W, so a flat `SPL = fPPT = sPPT = 85 W` ceiling trades the stock 140 W boost for near-peak throughput on a quiet, constant fan curve; per-setting rationale is in the Note column. Full rationale + walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference).

`Advanced → SMU Common Options` — power limits in mW, time constants in s, TjMax in °C:

| Setting | Value | Note |
|---|---|---|
| ECO Mode | `Disabled` | frees the manual power limits below |
| SPL Control | `Manual` | unlock Sustained Power Limit |
| Sustained Power Limit | `85000` | 85 W ceiling — gains flatten past this |
| PPT Control | `Manual` | unlock Fast/Slow PPT |
| Fast PPT Limit | `85000` | flat with SPL — no transient boost above 85 W |
| Slow PPT Limit | `85000` | flat with SPL |
| Slow PPT Time Constant | `0` | no slow-PPT ramp window |
| STAPM Control | `Manual` | unlock the skin-temp track |
| System Temperature Tracking | `Auto` | leave stock; STAPM Boost below does the zeroing |
| STAPM Boost Override | `1` | enable the override |
| STAPM Boost | `0` | zero a desktop-irrelevant skin-temp track |
| Tskin Time Constant (STAPM) | `0` | no Tskin ramp window |
| Thermal Control | `Manual` | unlock TjMax |
| TjMax | `90` | 10 °C under the silicon limit |

</details>

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` / `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits 4 — **do not reboot** until it succeeds. A non-vfat `/boot` ESP fallback also refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Run the unattended install (silent; phase matrix at end) |
| `-V`/`--verbose` | Stream per-command install output (ignored under `--check`) |
| `--verify` | Verify config files byte-for-byte, then live system state; flag stale `/etc/modprobe.d/60-ry-*` drop-ins outside the managed set |
| `--check` | Probe idempotency silently vs live `/proc/cmdline` — a fresh install reads drift until reboot ([Exit Codes](#exit-codes)) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End option parsing (no positional args) |
| `-h`/`--help` · `-v`/`--version` | Print and exit before all checks, including the root guard |

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving (`realpath -m`) to a managed destination. Deploy modes and `--check` hard-gate hardware and key/count invariants (exit 3); `--verify` downgrades the hardware gate to a warning.

### Environment Overrides

Safe fallback when unset or invalid. One JSONL log per run: `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl` (`0600`).

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` s | Per-command cap; `0` disables; package/boot ops floor `7200` s; invalid → default |
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | `0` (check on) | Bypass the `Ryzen AI Max` CPU-match hard-fail |
| `NO_COLOR` | unset (color on) | Disable colored output when set — any value, including empty ([no-color.org](https://no-color.org)) |

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

Results print to stderr; a JSONL log records each phase. `WARN` keeps exit 0; `DEFER` applies on next boot.

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an IPv4-only nftables default-deny-inbound ruleset (loopback, established/related, inbound ping accepted; `forward` drop, `output` accept). IPv6 disabled system-wide (`ipv6.disable=1`).

The fallback BLS entry boots `LINUX_FALLBACK_OPTIONS="quiet"` only — IPv6 and AMD-Vi revert to kernel defaults, though the IPv4-only ruleset and the `amdxdna` blacklist still apply. Game-streaming inbound is off (`RY_REMOTE_PLAY_PORTS=false`). Set `true` and re-run to append Sunshine/Moonlight + Steam Remote Play accepts.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for the 4 boot files (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (`cmp`-gated) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Entry regeneration | `REMOVE_EXISTING=yes` clears `loader/entries/` first; EFI-resident loaders (e.g. Windows Boot Manager) untouched |
| Instance lock | atomic `mkdir 0700`; stale reclaim only for a provably-recycled PID (`/proc` start-time); else fail-closed |

### Exit Codes

| Code | Meaning | Emitted When |
|---|---|---|
| `0` | OK | Success; also `WARN`-only runs and `--check` clean |
| `1` | verify-FAIL / install-error | `--verify` mismatch, or an install step errored |
| `2` | usage | Bad args, non-absolute/unmanaged `--install-file`, root-guard misuse |
| `3` | preflight | Missing/non-GNU dep, uncached sudo, gate mismatch, root + `--check` (silent) |
| `4` | boot-critical (DO NOT REBOOT) | Boot cascade or post-rebuild sanity failed — resolve before rebooting |
| `5` | lock | Another instance holds the lock (fail-closed on ambiguous pidfile) |
| `10` | `--check` drift | Config drift from the managed baseline |

## Configuration

All tunables are `set -g` globals near the top of the script — no external config file. Edit one, then re-run (or `--install-file` the affected file). Perms: system `0644`, user `0600`.

### CachyOS Divergences

`DNSSEC=allow-downgrade` (vendor default is DoH); sysctl priority `95`, loading after vendor `70-cachyos-settings.conf`; NVMe scheduler `none` (vendor default is `kyber`); AMD P-State EPP `balance_performance`; `sdboot-manage` `REMOVE_EXISTING=yes` ([Safety & Reliability](#safety--reliability)).

### Packages

`pacman -Rns` is rdep-aware via `pactree` (from `pacman-contrib`, which also supplies `paccache`). Phase 2 re-marks every `PKGS_ADD` package explicit after `-Syu`, so a later `-Rns` can't orphan a dependency-installed one. `archlinux-contrib` is no longer managed — optional `sudo pacman -Rns archlinux-contrib`.

| Install | Packages |
|---|---|
| Gaming | `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware` |
| CLI | `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta` |
| Hardware | `nvme-cli`, `lm_sensors`, `ddcutil` |
| RT audio | `rtkit`, `realtime-privileges` |
| Firewall | `nftables` |
| Contrib | `pacman-contrib` |

### Remove and Verify

| Action | Packages |
|---|---|
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (`chwd` Vulkan drivers) |

### Units

| Action | Units |
|---|---|
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, `modemmanager`, `avahi-daemon` (`.service` + `.socket`), sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched | `systemd-oomd` (by design — kernel OOM-killer + zram is the intended path) |

### Fstab File

ext4 rows get `noatime,lazytime,commit=10` in column 4 (redundant `defaults`/`relatime`/`atime`/`strictatime`/existing `commit=` tokens normalized away). Everything else is byte-preserved. Gated by line-count parity + size floor + mandatory `findmnt --verify`. A symlinked `/etc/fstab` aborts the rewrite. Malformed (whitespace-split) rows are left byte-identical and warned.

## Managed Files

17 embedded configs, in deploy order ([`--verify`](#usage) checks all, `--install-file` re-deploys one): 4 boot-critical (`.ry.bak`-backed), 11 system, 2 user.

### Boot Files

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | loader: default entry, timeout, console-mode |
| `/etc/kernel/cmdline` | `rw root=UUID` + the 17 `KERNEL_PARAMS` |
| `/etc/sdboot-manage.conf` | entry gen (`REMOVE_EXISTING`, `LINUX_OPTIONS`) |
| `/etc/mkinitcpio.conf` | initramfs `MODULES`/`HOOKS`/`COMPRESSION` (`zstd`) |

### System Files

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | `DNSSEC=allow-downgrade`, no mDNS/LLMNR/DoT |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power/suspend/hibernate/reboot keys |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | silence info-level `nm-dispatcher` noise |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | Wi-Fi backend, power-save off, log level |
| `/etc/iw-regdomain` | regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | adapter auto-power-on + paired-sink reconnect |
| `/etc/nftables.conf` | IPv4-only default-deny-inbound (ping allowed) |
| `/etc/default/cpupower-service.conf` | governor (`powersave`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | BBR + `fq`, VM, netdev tunables |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe sched `none`, P-State EPP, GPU DPM |
| `/etc/modprobe.d/60-ry-modules.conf` | `amdxdna` blacklist (`BLACKLIST_AMDXDNA`) |

### User Files

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | gaming env (RADV, MangoHud, Proton, VKD3D) |
| `~/.config/MangoHud/MangoHud.conf` | readout-only HUD |

## Tuning Notes

Non-obvious choices; several list an override to reverse.

| Topic | Detail |
|---|---|
| Large-VRAM compute | GTT caps usable VRAM near 62 GiB; raise BIOS UMA carveout (≤96 GiB) for more (`amdgpu.gttsize` deprecated). Verify: `cat /sys/module/ttm/parameters/pages_limit`. |
| FSR4 on RDNA3 | `FSR4_UPGRADE=1` ships enabled (RDNA3/3.5; Proton-CachyOS ≥ 11.0-20260702 replaces removed `PROTON_FSR4_RDNA3_UPGRADE`). Verify: `printenv FSR4_UPGRADE`. |
| NTSYNC | `--verify` reports `/dev/ntsync` (present ok · module-no-node warn · absent info). Opt out: `PROTON_NO_NTSYNC=1`. |
| MangoHud `cpu_temp` | Disabled — re-enabling re-trips [MangoHud #1794](https://github.com/flightlessmango/MangoHud/issues/1794) (`cpu_power` reads 0 on Zen 5). |
| PCIe ASPM | `pcie_aspm.policy=performance` actively disables ASPM on every link (MT7925 coredump / BT-reconnect / assoc fix + NVMe latency); plain `off` merely inherits BIOS link state. Drop to restore ASPM defaults. |
| IPv6 | `ipv6.disable=1`, IPv4-only ruleset. Dual-stack: drop token, add IPv6 rules, re-run. |
| Avahi | `.service`+`.socket` masked — collided with resolved as a 2nd mDNS responder; profile runs `MulticastDNS=no`. Unmask both to restore. |
| AMD-Vi (IOMMU) | `amd_iommu=off` breaks the XDNA NPU (hence blacklist). NPU/VFIO/SR-IOV: `amd_iommu=on iommu=pt` + `BLACKLIST_AMDXDNA false`, re-run. |
| UMIP (`clearcpuid=umip`) | Disables UMIP trapping; taints kernel. String form is version-stable. Drop if no `umip_printk` stutter. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference. Manual uninstall — 6 steps, in order:

| # | Step | Action |
|---|---|---|
| 1 | Unmask units | `sudo systemctl unmask` all 12 masked units — exact set in [Units](#units) |
| 2 | Remove configs | `sudo rm` the 11 system files + `rm` the 2 user files — skip the 4 boot files (step 3 reverts them) |
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
