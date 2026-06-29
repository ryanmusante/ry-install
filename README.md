# ry-install

[![version](https://img.shields.io/badge/version-7.79.5-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish-1793d1?style=flat-square)](https://fishshell.com)

> Idempotent, reversible CachyOS config manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 17 embedded configs, gaming/LLM desktop profile.

**In 30 seconds:** one unattended run turns a fresh CachyOS install into a tuned single-seat gaming/LLM desktop — kernel cmdline and initramfs for gfx1151, a default-deny nftables firewall (ufw masked), `powersave`/EPP `balance_performance` CPU tuning, BBR networking, Proton/FSR4/RADV session env, and a curated package add/remove. Every change is atomic, byte-verifiable (`--verify`), and reversible by hand ([Uninstall](#uninstall)).

<details>
<summary><strong>Contents</strong></summary>

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Safety & Reliability](#safety--reliability)
- [Configuration](#configuration)
- [Managed Files](#managed-files)
- [Tuning Notes](#tuning-notes)
- [Uninstall](#uninstall)
- [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

</details>

## Quick Start

> [!IMPORTANT]
> Run as your normal user (root refused, exit 2); cache sudo first (`sudo -v`). The unattended run **removes packages** (see [Configuration](#configuration)). Reboot, then `--verify`. Re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.79.5
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
| Kernel | ≥ 6.19 (override `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`) |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Preflight hard-fails (exit 3) on missing deps (`pacman`, `systemctl`, `mkinitcpio`, `sdboot-manage`, `findmnt`, `sha256sum`, `curl`, GNU coreutils/findutils/diffutils — busybox/uutils rejected), a sub-6.19 kernel, or uncached sudo. NTP sync and `paccache` only warn.

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits 4 and prints the DO-NOT-REBOOT banner — **do not reboot** until it succeeds. A non-vfat `/boot` ESP also refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install (silent by default — a phase matrix prints at the end) |
| `-V, --verbose` | Stream per-command install output (ignored under `--check`) |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Silent idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End of options (no positional args) |
| `-h`/`--help` · `-v`/`--version` | Honored before all checks, including the root guard |

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving via `realpath -m` to a managed destination (else exit 2). All modes first run the runtime-init gates (hardware match, kernel floor, key/count validation), which hard-fail **exit 3** on a mismatched or sub-floor host.

### What a clean install looks like

After a successful run, a fully-converged host probes silent and verifies clean:

```fish
$ ./ry-install.fish --check; echo $status
0                                    # 0 = no drift (3 = preflight, 10 = drift)

$ ./ry-install.fish --verify
...
[OK] Combined (static + runtime): 142 OK
```

`--check` writes nothing to the terminal — it is a scriptable exit-code probe. `--verify` prints a per-line `[OK]`/`[WARN]`/`[FAIL]` report ending in the combined tally; a run with no `FAIL` lines exits `0` (warnings alone do not fail).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock → hard gates (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → iwd handoff (only when `NM_WIFI_BACKEND=iwd`) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

A results summary prints to stderr; a JSONL log records each phase. `WARN` keeps exit `0`; `DEFER` applies on next boot (e.g. regdomain).

The intended recovery path for any failure is to read the failing phase, fix the underlying cause, and **re-run** — the script is idempotent, so an already-applied phase no-ops and only the unfinished work is redone. A boot-critical failure (exit 4) is the one case requiring care: resolve it before rebooting (see [Usage](#usage)).

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an nftables **default-deny-inbound** ruleset (established/related + loopback accepted, inbound IPv4 ping dropped, essential ICMPv6 NDP/PMTUD accepted, all else dropped; `forward` drop, `output` accept). `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete all `loader/entries/` entries (including other-OS BLS) before regenerating; EFI-resident loaders like Windows Boot Manager are untouched.

Host-side game streaming is off by default (`RY_REMOTE_PLAY_PORTS=false`); set `true` and re-run to append Sunshine/Moonlight + Steam Remote Play inbound accepts to the input chain.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (gated by `cmp`) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Instance lock | atomic `mkdir 0700`; stale-lock reclaim only for a provably-recycled PID via `/proc` start-time (else fail-closed) |

<details>
<summary><strong>Exit codes, sentinels, and environment overrides</strong></summary>

**Exit codes** `0` ok · `1` verify-FAIL/install-error · `2` usage (incl. root-refused) · `3` preflight · `4` boot-critical (DO NOT REBOOT) · `5` lock · `10` `--check` drift · `128+N` signal (130 INT, 143 TERM, 129 HUP, 131 QUIT, 134 ABRT).
Sentinels `11`–`13` and `250`/`251`/`255` never reach a process exit (surface as the footer `gen_fail` count).

Environment overrides (safe fallback when unset/invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables; `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile` exempt), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`, `NO_COLOR`, `TMPDIR`. Log: one JSONL/run at `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl` (`0600`).

</details>

## Configuration

All tunables live as `set -g` globals near the top of the script — there is no external config file. The subsections below map those globals to what they control: **Globals** covers the scalar knobs and CachyOS-specific divergences, **Packages** the add/remove sets, **Units** the systemd mask/enable lists, and **fstab** the ext4 mount-option rewrite. Edit a global, then re-run (or `--install-file` the single affected file) to apply.

### Globals

Source of truth is the script; retune the `set -g` globals near the top (perms: system `0644`, user `0600`). CachyOS divergences: `DNSSEC=allow-downgrade` (not DoH), sysctl priority 95 (after vendor `70-cachyos-settings.conf`), NVMe sched `none`, AMD P-State EPP `balance_performance`, `sdboot-manage REMOVE_EXISTING=yes` (BLS wipe).

### Packages

`pacman -Rns` is rdep-aware (an external dependant skips + logs). Reversible via [Uninstall](#uninstall).

| Action | Packages |
|---|---|
| Install | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `rtkit`, `realtime-privileges`, `ddcutil`, `nftables` |
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (chwd Vulkan drivers) |

### Units

| Action | Units |
|---|---|
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, `modemmanager`, sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched | `iwd.service` (opt-in: `NM_WIFI_BACKEND=iwd` + re-run); `systemd-oomd` (by design — kernel OOM-killer + zram is the intended path) |

### fstab

| Aspect | Behavior |
|---|---|
| Change | ext4 rows get `noatime,lazytime,commit=10` in column 4 only; every other column and every non-ext4 row byte-preserved |
| Normalized away | redundant `defaults` / `relatime` / `atime` / `strictatime` / existing `commit=` tokens |
| Gates | line-count parity + size floor + mandatory `findmnt --verify` |
| Refused (not corrected) | a symlinked or whitespace-split (malformed) `/etc/fstab` |

## Managed Files

### Boot

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot loader settings (default entry, timeout, console-mode) |
| `/etc/kernel/cmdline` | kernel command line: `root=UUID` prefix + the 16 `KERNEL_PARAMS` |
| `/etc/sdboot-manage.conf` | boot-entry generation (`REMOVE_EXISTING`, `LINUX_OPTIONS`) |
| `/etc/mkinitcpio.conf` | initramfs `MODULES` / `HOOKS` / `zstd` compression |

### systemd drop-ins

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | systemd-resolved: `DNSSEC=allow-downgrade`, no mDNS/LLMNR/DoT |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power/suspend/hibernate/reboot keys |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | silence info-level `nm-dispatcher` journal noise |

### Network

| File | Purpose |
|---|---|
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | NM Wi-Fi backend, power-save off, log level |
| `/etc/iw-regdomain` | wireless regulatory domain (`US`) |

### Bluetooth & firewall

| File | Purpose |
|---|---|
| `/etc/bluetooth/main.conf` | BlueZ adapter auto-power-on + paired-sink reconnect |
| `/etc/nftables.conf` | default-deny-inbound firewall ruleset |

### Power, performance & modules

| File | Purpose |
|---|---|
| `/etc/default/cpupower-service.conf` | CPU governor (`powersave`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | sysctl tunables (BBR + `fq`, VM, netdev) |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, AMD P-State EPP, GPU DPM |
| `/etc/modprobe.d/60-ry-mt7925e.conf` | disable PCIe ASPM on MT7925 (stability mitigation) |

### User session

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | gaming env vars (RADV, MangoHud, Proton) |
| `~/.config/MangoHud/MangoHud.conf` | readout-only performance HUD |

## Tuning Notes

| Topic | Detail |
|---|---|
| Large-VRAM compute | GTT caps usable VRAM near 62 GiB. For a single allocation >~62 GiB (ROCm/llama.cpp), raise the **BIOS UMA carveout** (up to 96 GB), not deprecated `amdgpu.gttsize`. Verify: `cat /sys/module/ttm/parameters/pages_limit`. |
| FSR4 on RDNA3 | `PROTON_FSR4_RDNA3_UPGRADE=1` ships enabled (FSR4 reached RDNA3/3.5 via Proton-CachyOS). Verify: `printenv PROTON_FSR4_RDNA3_UPGRADE` → `1`. |
| NTSYNC | `/dev/ntsync` asserted in preflight + verify (mainline ≥ 6.14). Opt a title out with `PROTON_NO_NTSYNC=1` in its launch options. |
| MT7925 ASPM | `/etc/modprobe.d/60-ry-mt7925e.conf` sets `disable_aspm=1` (coredump / BT-reconnect / assoc-fail mitigation; distinct from `wifi.powersave`). Symptomatic reserve fix — remove if a kernel bump resolves it. |
| AMD-Vi (IOMMU) | `amd_iommu=off` ships in the cmdline; AMD-Vi is fully disabled (single-purpose gaming/LLM desktop, no PCI passthrough). `--verify` confirms 0 entries under `/sys/kernel/iommu_groups/`. **VFIO/passthrough or SR-IOV users must use `amd_iommu=on iommu=pt` instead**, then re-run. |
| UMIP (`clearcpuid=514`) | Ships in the cmdline; UMIP disabled system-wide (`SGDT`/`SIDT`/`SMSW` untrapped) and the kernel is tainted. Intentional latency choice — drop the token to restore UMIP if no `umip_printk` stutter is seen. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference.

<details>
<summary><strong>Manual uninstall</strong> — 6 steps, in order</summary>

| # | Step | Command |
|---|---|---|
| 1 | Unmask | `sudo systemctl unmask ananicy-cpp.service power-profiles-daemon.service NetworkManager-wait-online.service ufw.service modemmanager.service sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target` |
| 2 | Remove system paths, then user env.d | `sudo rm /etc/sdboot-manage.conf /etc/sysctl.d/95-ry-overrides.conf /etc/udev/rules.d/99-ry-perf.rules /etc/modprobe.d/60-ry-mt7925e.conf /etc/iw-regdomain /etc/bluetooth/main.conf /etc/nftables.conf /etc/default/cpupower-service.conf /etc/NetworkManager/conf.d/99-cachyos-nm.conf /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf /etc/systemd/logind.conf.d/99-cachyos-logind.conf /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` then `rm ~/.config/environment.d/10-environment.conf ~/.config/MangoHud/MangoHud.conf` |
| 3 | Restore fstab, delete `.ry.bak` | `sudo mv /etc/fstab.ry.bak /etc/fstab` then `sudo rm -f /boot/loader/loader.conf.ry.bak /etc/mkinitcpio.conf.ry.bak` |
| 4 | Reverse package changes (optional) | `sudo pacman -S --needed plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update kdeconnect` then `sudo pacman -Rns nvme-cli cachyos-gaming-meta cachyos-gaming-applications lib32-mesa mkinitcpio-firmware fd sd dust procs bottom htop git-delta lm_sensors rtkit realtime-privileges ddcutil nftables` |
| 5 | Rebuild initramfs + entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

</details>

For boot files (`loader.conf`, `/etc/kernel/cmdline`, `mkinitcpio.conf`), revert their contents (or `.ry.bak`) before step 5, which regenerates entries from that state.

## Known Issues

| Component | Issue | Status |
|---|---|---|
| Strix Halo GPU | MES page faults | resolved (MES 0x86; current `linux-firmware` + shipped `mkinitcpio-firmware`) |
| RTL8127 10GbE | throughput drops under load; suspend/shutdown hang | resolved — in-tree `r8169` (`f24f7b2f3af9`) + suspend/shutdown hang fix (`ae1737e7339b`) both land in 6.18, so the ≥ 6.19 kernel floor guarantees them; no DKMS |
| MT7925 | kernel panics, low TX power, random deauth | open — out-of-tree DKMS; some fixes upstream. The `3 dBm` TX-power readout is cosmetic (correct power applied) |
| Strix Halo ACP | no ASoC machine driver | open — pending upstream (HDMI/USB audio unaffected) |

### Known-benign log lines

Expected on this hardware (deliberate optimization or capability gap); none affect operation. Live-checkable: `ModemManager1 … could not be found` (KDE D-Bus probe of the by-design-masked `modemmanager.service`); `acp_asoc_acp70 … No matching ASoC machine driver` (missing board-ID quirk, internal mic undetected — HDMI/USB audio fine); `unknown NHI PCI id` from boltd (PCI-ID table gap, USB4/TB still enumerate); `charge thresholds not supported` / `no backlight interface` (mini-PC has no battery or panel backlight); and `Unlikely small volume range` (USB-audio UAC descriptor quirk, capture unaffected).

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
> The installer prints these `usermod` commands when group membership is missing but does not run them — a group change is inert until re-login and can't be cleanly reverted like the managed configs.

## Contributing

PRs welcome. For config changes: include before/after `--verify` and `--check` output, lint with `fish --no-execute`, keep comments single-line, update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, and kernel cmdline. Review before running. Report concerns via GitHub issues or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
