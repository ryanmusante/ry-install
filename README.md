# ry-install

[![version](https://img.shields.io/badge/version-7.94.2-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish-1793d1?style=flat-square)](https://fishshell.com)

> Idempotent, reversible CachyOS config manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 18 embedded configs, gaming/LLM desktop profile. Every change is atomic, byte-verifiable (`--verify`), and reversible ([Uninstall](#uninstall)).

## Quick Start

> [!IMPORTANT]
> Run as your normal user (root refused, exit 2); cache sudo first (`sudo -v`). The unattended run **removes packages** (see [Configuration](#configuration)). Reboot, then `--verify`. Re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.94.2
chmod +x ry-install.fish
./ry-install.fish
```

| In scope | Out of scope |
|---|---|
| Kernel cmdline, initramfs, systemd units, NetworkManager, Bluetooth, sysctl, gaming env vars, MangoHud, pacman add/remove, sdboot-manage BLS entries | Dotfiles, secrets, backups, multi-user, non-CachyOS, laptops, UKI |

## Requirements

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| Kernel | ≥ 6.19 (override `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`; `--verify` warns only) |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`; `--verify` warns only) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Preflight hard-fails (exit 3) on missing/non-GNU deps (busybox/uutils rejected), a sub-6.19 kernel, or uncached sudo; NTP and `paccache` only warn. An unsynced clock with no NTP client triggers `systemd-timesyncd` + RTC writeback (skip `RY_NO_NTP_REMEDIATION=1`).

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` and `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits 4 with the DO-NOT-REBOOT banner — **do not reboot** until it succeeds. A non-vfat `/boot` ESP also refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install (silent; phase matrix prints at the end) |
| `-V, --verbose` | Stream per-command install output (ignored under `--check`) |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Silent idempotency probe (`0` clean · `3` preflight · `10` drift). Compares the live `/proc/cmdline`, so a fresh install reads `10` until reboot |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End of options (no positional args) |
| `-h`/`--help` · `-v`/`--version` | Honored before all checks, including the root guard |

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving (`realpath -m`) to a managed destination. Deploy modes and `--check` run hard runtime gates (hardware, kernel floor, key/count) → exit 3 on mismatch; `--verify` downgrades hardware + kernel-floor to warnings.

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | hard gates → lock → config checks (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 18 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

Results print to stderr; a JSONL log records each phase. `WARN` keeps exit 0; `DEFER` applies on next boot; a boot-critical failure (exit 4) must be resolved before rebooting.

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an IPv4-only nftables **default-deny-inbound** ruleset (loopback, established/related, and inbound ping accepted; all else dropped; `forward` drop, `output` accept). IPv6 is disabled system-wide via `ipv6.disable=1` on the cmdline. `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete all `loader/entries/` before regenerating; EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

Host-side game streaming is off by default (`RY_REMOTE_PLAY_PORTS=false`); set `true` and re-run to append Sunshine/Moonlight + Steam Remote Play inbound accepts.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch (backup targets) |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (gated by `cmp`) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Instance lock | atomic `mkdir 0700`; stale-lock reclaim only for a provably-recycled PID via `/proc` start-time (else fail-closed) |

**Exit codes**

| Code | Meaning | Emitted when |
| ---- | ------- | ------------ |
| `0` | OK | Success; also `WARN`-only runs and `--check` clean |
| `1` | verify-FAIL / install-error | `--verify` found a mismatch, or an install step errored |
| `2` | usage | Bad args, non-absolute/unmanaged `--install-file` path, root-guard misuse |
| `3` | preflight | Missing/non-GNU dep, sub-`KERNEL_MIN` kernel, uncached sudo, hardware/key/count gate |
| `4` | boot-critical (DO NOT REBOOT) | Boot cascade or post-rebuild sanity failed — resolve before rebooting |
| `5` | lock | Another instance holds the lock (fail-closed on ambiguous pidfile) |
| `10` | `--check` drift | `--check` confirmed config drift from the managed baseline |

Environment overrides (safe fallback when unset/invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables; package/boot ops floor at `7200` s so a short cap can't SIGKILL a live transaction), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`, `RY_NO_NTP_REMEDIATION=1`, `NO_COLOR`, `TMPDIR`. Log: one JSONL/run at `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl` (`0600`).

## Configuration

All tunables are `set -g` globals near the top of the script — no external config file. Edit a global, then re-run (or `--install-file` the affected file).

### Globals

Perms: system `0644`, user `0600`. CachyOS divergences: `DNSSEC=allow-downgrade` (not DoH), sysctl priority 95 (after vendor `70-cachyos-settings.conf`), NVMe sched `none`, AMD P-State EPP `balance_performance`, `sdboot-manage REMOVE_EXISTING=yes` (see [Safety & Reliability](#safety--reliability)).

### Packages

`pacman -Rns` is rdep-aware via `pactree` (`pacman-contrib`). Since `pacman-contrib`/`archlinux-contrib` are hard-deps of the removed `cachy-update`, Phase 2 marks every `PKGS_ADD` member explicit (`pacman -D --asexplicit`) **after** the `-Syu` so `-Rns -s` can't orphan `pactree`/`paccache`/`checkservices`. An external dependant skips + logs. Reversible via [Uninstall](#uninstall).

| Action | Packages |
|---|---|
| Install | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `rtkit`, `realtime-privileges`, `ddcutil`, `nftables`, `pacman-contrib`, `archlinux-contrib` |
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (chwd Vulkan drivers) |

### Units

| Action | Units |
|---|---|
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, `modemmanager`, sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched | `systemd-oomd` (by design — kernel OOM-killer + zram is the intended path) |

### fstab

| Aspect | Behavior |
|---|---|
| Change | ext4 rows get `noatime,lazytime,commit=10` in column 4 only; all other columns and non-ext4 rows byte-preserved |
| Normalized away | redundant `defaults` / `relatime` / `atime` / `strictatime` / existing `commit=` tokens |
| Gates | line-count parity + size floor + mandatory `findmnt --verify` |
| Refused (not corrected) | a symlinked or whitespace-split (malformed) `/etc/fstab` |

## Managed Files

18 embedded config files, in deploy order; `--verify` checks every one against live state, `--install-file <path>` re-deploys one.

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot loader settings (default entry, timeout, console-mode) |
| `/etc/kernel/cmdline` | kernel command line: `rw root=UUID` prefix + the 17 `KERNEL_PARAMS` |
| `/etc/sdboot-manage.conf` | boot-entry generation (`REMOVE_EXISTING`, `LINUX_OPTIONS`) |
| `/etc/mkinitcpio.conf` | initramfs `MODULES` / `HOOKS` / `zstd` compression |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | systemd-resolved: `DNSSEC=allow-downgrade`, no mDNS/LLMNR/DoT |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power/suspend/hibernate/reboot keys |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | silence info-level `nm-dispatcher` journal noise |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | NM Wi-Fi backend, power-save off, log level |
| `/etc/iw-regdomain` | wireless regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | BlueZ adapter auto-power-on + paired-sink reconnect |
| `/etc/nftables.conf` | IPv4-only default-deny-inbound firewall ruleset (inbound ping allowed) |
| `/etc/default/cpupower-service.conf` | CPU governor (`powersave`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | sysctl tunables (BBR + `fq`, VM, netdev) |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, AMD P-State EPP, GPU DPM |
| `/etc/modprobe.d/60-ry-mt7925e.conf` | disable PCIe ASPM on MT7925 (stability mitigation) |
| `/etc/modprobe.d/60-ry-blacklist-amdxdna.conf` | blacklist the XDNA NPU driver (needs IOMMU; unused under `amd_iommu=off`) |
| `~/.config/environment.d/10-environment.conf` | gaming env vars (RADV, MangoHud, Proton) |
| `~/.config/MangoHud/MangoHud.conf` | readout-only performance HUD |

## Tuning Notes

Rationale for non-obvious choices; several list an override to reverse.

| Topic | Detail |
|---|---|
| Large-VRAM compute | GTT caps usable VRAM near 62 GiB. For a single allocation >~62 GiB (ROCm/llama.cpp), raise the **BIOS UMA carveout** (up to 96 GB), not deprecated `amdgpu.gttsize`. Verify: `cat /sys/module/ttm/parameters/pages_limit`. |
| FSR4 on RDNA3 | `PROTON_FSR4_RDNA3_UPGRADE=1` ships enabled (FSR4 reached RDNA3/3.5 via Proton-CachyOS). Verify: `printenv PROTON_FSR4_RDNA3_UPGRADE` → `1`. |
| NTSYNC | `/dev/ntsync` reported (warn-level) by `--verify` (mainline ≥ 6.14, guaranteed by the ≥ 6.19 floor). Opt a title out with `PROTON_NO_NTSYNC=1` in its launch options. |
| MT7925 ASPM | `/etc/modprobe.d/60-ry-mt7925e.conf` sets `disable_aspm=1` (coredump / BT-reconnect / assoc-fail mitigation; distinct from `wifi.powersave`). Remove if a kernel bump resolves it. |
| IPv6 | Disabled via `ipv6.disable=1`; the nftables ruleset is IPv4-only. Drop the token, restore IPv6 firewall rules, and re-run for dual-stack. |
| AMD-Vi (IOMMU) | `amd_iommu=off` disables AMD-Vi (no PCI passthrough) and refuses the XDNA NPU (`amdxdna`), which the profile blacklists to silence the probe error. **NPU, VFIO/passthrough, or SR-IOV users: set `amd_iommu=on iommu=pt`, drop `60-ry-blacklist-amdxdna.conf`, re-run.** |
| UMIP (`clearcpuid=umip`) | `clearcpuid=umip` disables UMIP (`SGDT`/`SIDT`/`SMSW` untrapped) and taints the kernel. The string form is stable across kernel versions (the numeric `514` is not). Drop the token to restore UMIP if no `umip_printk` stutter appears. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference. Manual uninstall — 6 steps, in order:

| # | Step | Action |
|---|---|---|
| 1 | Unmask units | `sudo systemctl unmask` all 10 masked units — exact set in [Units](#units) |
| 2 | Remove configs | `sudo rm` the managed system files, then `rm` the 2 user files — all of [Managed Files](#managed-files) except `loader.conf`, `/etc/kernel/cmdline`, `mkinitcpio.conf`, which are reverted, not deleted (see note below) |
| 3 | Restore fstab, drop backups | Restore `/etc/fstab` from `.ry.bak` if present, then delete the `loader.conf` and `mkinitcpio.conf` `.ry.bak` backups |
| 4 | Reverse packages (optional) | `pacman -S --needed` the **Remove** row, `pacman -Rns` the **Install** row — exact lists in [Packages](#packages) |
| 5 | Rebuild initramfs + entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

The fstab backup exists only if fstab was rewritten. Revert boot-file contents **before** step 5 (it regenerates entries from that state): restore `loader.conf` / `mkinitcpio.conf` from `.ry.bak`; `/etc/kernel/cmdline` has no backup and is reverted by hand. If ry-install enabled `systemd-timesyncd`, optionally `sudo systemctl disable --now systemd-timesyncd`.

## Known Issues

| Component | Issue |
|---|---|
| MT7925 | kernel panics, low TX power, random deauth — out-of-tree DKMS; some fixes upstream. The `3 dBm` TX-power readout is cosmetic (correct power applied) |
| Strix Halo ACP | no ASoC machine driver — pending upstream (HDMI/USB audio unaffected) |

### Known-benign log lines

Expected and harmless on this hardware: `ModemManager1 … could not be found` (probe of masked `modemmanager.service`) · `acp_asoc_acp70 … No matching ASoC machine driver` (HDMI/USB audio fine) · boltd `unknown NHI PCI id` (USB4/TB still enumerate) · `charge thresholds not supported` / `no backlight interface` (no battery/panel) · `Unlikely small volume range` (USB-audio descriptor quirk).

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
> The installer prints missing-group `usermod` commands but never runs them — a group change is inert until re-login and can't be cleanly reverted like the managed configs.

## Contributing

PRs welcome; for config changes include before/after `--verify`/`--check` output, lint with `fish --no-execute`, keep comments single-line, update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, and kernel cmdline. Review before running. Report concerns via GitHub issues or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
