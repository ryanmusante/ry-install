# ry-install

[![version](https://img.shields.io/badge/version-7.74.1-1793d1?style=flat-square)](CHANGELOG.md)

> Idempotent, reversible CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / Radeon 8060S / gfx1151 / Strix Halo).

One self-contained fish script: 18 embedded configs, gaming/LLM desktop profile.

## Quick Start

> [!IMPORTANT]
> Run as your normal user (root is refused, exit 2); cache sudo first (`sudo -v`). The unattended run **removes packages** (see [Configuration](#configuration)). Reboot afterward, then `--verify`. Re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.74.1
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
| Kernel | ≥ 6.18 (override `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`) |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Hard deps abort read-only in preflight (exit 3): `pacman`, `systemctl`, `mkinitcpio`, `sdboot-manage`, `findmnt`, `sha256sum`, `curl`, GNU coreutils/findutils/diffutils (busybox/uutils rejected). Sub-6.18 kernel also hard-fails (override above); sudo must be cached. NTP sync and `paccache` only warn.

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

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving via `realpath -m` to a managed destination (non-managed/malformed → exit 2). All four modes first run the runtime-init gates (hardware match, kernel floor, embedded key/count validation); on a mismatched or sub-floor host these hard-fail **exit 3 before any mode-specific work**, so the exit-2 rejection only surfaces once the gates pass (or are bypassed via the skip overrides).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run. mkinitcpio rollback restores the prior `mkinitcpio.conf` byte-for-byte on such failure or on signal.
| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock → hard gates (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 18 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → iwd handoff (only when `NM_WIFI_BACKEND=iwd`) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

A results summary prints to stderr; a JSONL log records each phase. `WARN` keeps exit `0`; `DEFER` applies on next boot (e.g. regdomain).

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an nftables **default-deny-inbound** ruleset: established/related + loopback accepted, inbound IPv4 ping dropped, essential ICMPv6 (NDP/PMTUD) accepted, all other inbound dropped. `forward` drop, `output` accept.

> [!NOTE]
> `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete all `loader/entries/` entries (including other-OS BLS) before regenerating. EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

> [!NOTE]
> Host-side game streaming is off by default — `RY_REMOTE_PLAY_PORTS=false`. Set it `true` (retune the `set -g` global, re-run) to append the Sunshine/Moonlight + Steam Remote Play inbound accepts (exact ports in the script) to the input chain.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (gated by `cmp`) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Instance lock | atomic `mkdir 0700`; stale-lock reclaim only for a provably recycled PID via `/proc` start-time (unsignalable/unknown ⇒ fail-closed) |

<details>
<summary><strong>Exit codes, sentinels, and environment overrides</strong></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, 129 HUP, 131 QUIT, 134 ABRT) |

Sentinels `11`–`13` and `250`/`251`/`255` never reach a process exit (surface as the footer `gen_fail` count).

Environment overrides (safe fallback when unset/invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables; `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile` exempt), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`, `NO_COLOR`, `TMPDIR`. Log: one JSONL/run, `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl` (`0600`).

</details>

## Configuration

Source of truth is the script; retune the `set -g` globals near the top (permissions: system `0644`, user `0600`). Deliberate CachyOS divergences: `DNSSEC=allow-downgrade` (not DoH), sysctl drop-in at priority 95 (after vendor `70-cachyos-settings.conf`), NVMe scheduler `none`, AMD P-State EPP `performance`, `sdboot-manage REMOVE_EXISTING=yes` (BLS wipe, see above). Cmdline is `rw root=UUID=<root>` + the 14 `KERNEL_PARAMS`; `mkinitcpio` is `MODULES=(amdgpu)` + systemd hooks, `zstd`.

**Packages** — the no-args run removes `PKGS_DEL` with `pacman -Rns` (rdep-aware: skipped + logged if an external package depends on it; reversible via [Uninstall](#uninstall)).

| Action | Packages |
|---|---|
| Install | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `rtkit`, `realtime-privileges`, `ddcutil`, `nftables` |
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (chwd Vulkan drivers) |

**Units**

| Action | Units |
|---|---|
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, `modemmanager`, sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched | `iwd.service` (opt-in: `NM_WIFI_BACKEND=iwd` + re-run); `systemd-oomd` (by design — kernel OOM-killer + zram is the intended path with this much RAM; do not enable) |

**fstab** — ext4 rows get `noatime,lazytime,commit=10` in column 4 only; redundant `defaults`/`relatime`/`atime`/`strictatime`/existing `commit=` tokens are normalized away, every other column and every non-ext4 row byte-preserved. Gated by line-count parity, a size floor, and mandatory `findmnt --verify`; a symlinked or whitespace-split (malformed) `/etc/fstab` is refused, not corrected.

## Managed Files

The 18 managed files and their purpose.

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot loader settings (default entry, timeout, console-mode) |
| `/etc/kernel/cmdline` | kernel command line: `root=UUID` prefix + the 14 `KERNEL_PARAMS` |
| `/etc/sdboot-manage.conf` | boot-entry generation (`REMOVE_EXISTING`, `LINUX_OPTIONS`) |
| `/etc/mkinitcpio.conf` | initramfs `MODULES` / `HOOKS` / `zstd` compression |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | systemd-resolved: `DNSSEC=allow-downgrade`, no mDNS/LLMNR/DoT |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power/suspend/hibernate/reboot keys |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | silence info-level `nm-dispatcher` journal noise |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | NM Wi-Fi backend, power-save off, log level |
| `/etc/iw-regdomain` | wireless regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | BlueZ adapter auto-power-on + paired-sink reconnect |
| `/etc/nftables.conf` | default-deny-inbound firewall ruleset |
| `/etc/default/cpupower-service.conf` | CPU governor (`performance`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | sysctl tunables (BBR + `fq`, VM, netdev) |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, AMD P-State EPP, GPU DPM |
| `/etc/modprobe.d/60-ry-mt7925e.conf` | disable PCIe ASPM on MT7925 (stability mitigation) |
| `~/.config/environment.d/10-environment.conf` | gaming env vars (RADV, MangoHud, Proton) |
| `~/.config/baloofilerc` | disable KDE Baloo file indexing |
| `~/.config/MangoHud/MangoHud.conf` | readout-only performance HUD |

## Tuning Notes

| Topic | Detail |
|---|---|
| Large-VRAM compute | Auto/GTT caps usable VRAM near 62 GiB on a 96 GB box. For a single allocation above ~62 GiB (ROCm / llama.cpp), raise the **BIOS UMA framebuffer carveout** (up to 96 GB) — not `amdgpu.gttsize`, which is deprecated. Gaming is unaffected. Verify: `cat /sys/module/ttm/parameters/pages_limit`. |
| FSR4 on RDNA3 | `PROTON_FSR4_RDNA3_UPGRADE=1` ships enabled (FSR4 reached RDNA3/3.5 via Proton-CachyOS). Verify: `printenv PROTON_FSR4_RDNA3_UPGRADE` → `1`. |
| NTSYNC | `/dev/ntsync` is asserted in preflight and verify (mainline ≥ 6.14). Opt a title out with `PROTON_NO_NTSYNC=1` in its launch options. |
| MT7925 ASPM | `/etc/modprobe.d/60-ry-mt7925e.conf` sets `disable_aspm=1` to mitigate coredump / BT-reconnect / assoc-fail on `mt7925e` (distinct from `wifi.powersave`). Symptomatic reserve fix — remove if a kernel bump resolves it. The `3 dBm` TX-power readout is cosmetic. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference.

<details>
<summary><strong>Manual uninstall</strong> — 6 steps, in order</summary>

| # | Step | Command |
|---|---|---|
| 1 | Unmask | `sudo systemctl unmask ananicy-cpp.service power-profiles-daemon.service NetworkManager-wait-online.service ufw.service modemmanager.service sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target` |
| 2 | Remove system paths, then user env.d | `sudo rm /etc/sdboot-manage.conf /etc/sysctl.d/95-ry-overrides.conf /etc/udev/rules.d/99-ry-perf.rules /etc/modprobe.d/60-ry-mt7925e.conf /etc/iw-regdomain /etc/bluetooth/main.conf /etc/nftables.conf /etc/default/cpupower-service.conf /etc/NetworkManager/conf.d/99-cachyos-nm.conf /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf /etc/systemd/logind.conf.d/99-cachyos-logind.conf /etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` then `rm ~/.config/environment.d/10-environment.conf ~/.config/baloofilerc ~/.config/MangoHud/MangoHud.conf` |
| 3 | Restore fstab, delete `.ry.bak` | `sudo mv /etc/fstab.ry.bak /etc/fstab` then `sudo rm -f /boot/loader/loader.conf.ry.bak /etc/mkinitcpio.conf.ry.bak` |
| 4 | Reverse package changes (optional) | `sudo pacman -S --needed plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update kdeconnect` then `sudo pacman -Rns nvme-cli cachyos-gaming-meta cachyos-gaming-applications lib32-mesa mkinitcpio-firmware fd sd dust procs bottom htop git-delta lm_sensors rtkit realtime-privileges ddcutil nftables` |
| 5 | Rebuild initramfs + entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

</details>

For boot files (`loader.conf`, `/etc/kernel/cmdline`, `mkinitcpio.conf`), step 5 regenerates entries from the restored/removed state; revert their contents (or restore `.ry.bak`) before step 5.

## Known Issues

| Component | Issue | Status |
|---|---|---|
| Strix Halo GPU | MES page faults | resolved (MES 0x86; current `linux-firmware` + shipped `mkinitcpio-firmware`) |
| RTL8127 10GbE | throughput drops under load; suspend/shutdown hang | resolved — in-tree `r8169` (`f24f7b2f3af9`) + suspend/shutdown hang fix (`ae1737e7339b`), both ≥ 6.18 and guaranteed by the kernel floor; no DKMS |
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
| BT speaker won't auto-reconnect | `bluetoothctl trust <MAC>`, then power the speaker on after login so it re-initiates |

> [!NOTE]
> The installer prints these `usermod` commands when group membership is missing but does not run them: a group change is inert until re-login and can't be cleanly reverted like the managed configs.

## Contributing

PRs welcome. For config changes, include before/after `--verify` and `--check` output; lint with `fish --no-execute`; keep comments single-line; update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, and kernel cmdline. Review before running. Report concerns via GitHub issues or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
