# ry-install

[![version](https://img.shields.io/badge/version-7.73.0-1793d1?style=flat-square)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46?style=flat-square&logo=fishshell&logoColor=white)](https://fishshell.com)
[![systemd](https://img.shields.io/badge/systemd-%E2%89%A5%20250-30b9db?style=flat-square)](https://systemd.io)
[![CachyOS](https://img.shields.io/badge/distro-CachyOS-1793d1?style=flat-square)](https://cachyos.org)

> Idempotent, reversible CachyOS configuration manager for the Beelink GTR9 Pro
> (Ryzen AI Max+ 395 / Radeon 8060S / gfx1151 / Strix Halo).

One self-contained fish script: 18 embedded configs, gaming/LLM desktop profile.

## Contents

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

## Quick Start

> [!IMPORTANT]
> Run as your normal user (root is refused, exit 2); cache sudo first (`sudo -v`). The unattended run **removes packages** (see [Configuration](#configuration)). Reboot afterward, then `--verify`. Re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.73.0
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

Hard deps abort read-only in preflight (exit 3): `pacman`, `systemctl`, `mkinitcpio`, `sdboot-manage`, `findmnt`, `sha256sum`, `curl`, GNU coreutils, findutils, diffutils. busybox/uutils rejected. A kernel below 6.18 also hard-fails (override as above). NTP sync and `paccache` only warn; sudo must be cached.

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

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving via `realpath -m` to a managed destination; non-managed or malformed paths are rejected (exit 2).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run. mkinitcpio rollback restores the prior `mkinitcpio.conf` byte-for-byte on such failure or on signal.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock → hard gates (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 18 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

A results summary prints to stderr; a JSONL log records each phase. `WARN` keeps exit `0`; `DEFER` applies on next boot (e.g. regdomain).

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an nftables **default-deny-inbound** ruleset: established/related + loopback accepted, inbound IPv4 ping dropped, essential ICMPv6 (NDP/PMTUD) accepted, all other inbound dropped. `forward` drop, `output` accept.

> [!NOTE]
> Host-side game streaming is off by default — `RY_REMOTE_PLAY_PORTS` is `false`, so no inbound stream ports open. Set it `true` (retune the `set -g` global, re-run) to append Sunshine/Moonlight (`tcp 47984,47989,48010`, `udp 47998-48010`) and Steam Remote Play (`tcp 27036`, `udp 27031-27036`) accepts to the input chain.

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
> Exit codes, sentinels, and environment overrides are collapsed below.

<details>
<summary><strong>Exit codes, sentinels, and environment overrides</strong></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, 129 HUP, 131 QUIT, 134 ABRT) |

Sentinels `11`–`13` and `250`/`251`/`255` never reach a process exit (surface as the footer `gen_fail` count).

Environment overrides (safe fallback when unset/invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables; `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile` exempt), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `RY_INSTALL_SKIP_KERNEL_FLOOR_CHECK=1`, `NO_COLOR`, `TMPDIR`. Logs: one JSONL per run at `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl` (`0600`).

</details>

## Configuration

Source of truth is the script; retune the `set -g` globals near the top.

> [!NOTE]
> Full per-file reference is collapsed below.

<details>
<summary><strong>Full managed-file reference</strong> — all 18 files, key values</summary>

| File | Purpose & key values |
|---|---|
| loader.conf | `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| kernel cmdline | `rw root=UUID=<root>` prefix, then the 12 `KERNEL_PARAMS`: `8250.nr_uarts=0`, `amd_pstate=active`, `iommu=pt`, `clearcpuid=514`, `nowatchdog`, `nvme_core.default_ps_max_latency_us=0`, `pcie_aspm.policy=performance`, `quiet`, `split_lock_detect=off`, `tsc=reliable`, `usbcore.autosuspend=-1`, `zswap.enabled=0` |
| sdboot-manage.conf | `DEFAULT_ENTRY=manual`, `OVERWRITE_EXISTING=yes`, `REMOVE_EXISTING=yes` (wipes `loader/entries/` before regen), `REMOVE_OBSOLETE=yes`; `LINUX_OPTIONS`=cmdline params, `LINUX_FALLBACK_OPTIONS="quiet"` |
| mkinitcpio.conf | `MODULES=(amdgpu)`; `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`; `COMPRESSION="zstd"` (`-1 -T0`); `BINARIES=()`, `FILES=()` |
| resolved | `MulticastDNS=no`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` (diverges from CachyOS DoH default) |
| logind | `Handle{Power,Suspend,Hibernate,Reboot}Key`=ignore (+ `LongPress` variants) |
| NetworkManager-dispatcher | `LogLevelMax=notice` drop-in — silences info-level `nm-dispatcher` journal spam |
| NetworkManager | wpa_supplicant backend; power-save off (`wifi.powersave=2`); `logging level=WARN`. Opt into iwd via `NM_WIFI_BACKEND=iwd` + re-run |
| iw-regdomain | regulatory domain fixed `US` (retune `COUNTRY`); consumed by CachyOS hooks at device-add |
| bluetooth main.conf | `AutoEnable=true`, `FastConnectable=true`, `ReconnectAttempts=3`. Per-device reconnect needs one-time `bluetoothctl trust <MAC>` |
| nftables.conf | default-deny-inbound (see [Safety & Reliability](#safety--reliability)) |
| cpupower / udev | `powersave` governor; udev sets NVMe scheduler `none`, AMD P-State EPP `balance_performance`, gfx1151 GPU DPM (`power_dpm_force_performance_level`, `KERNEL=="card[0-9]"`). DPM level is `GPU_DPM_LEVEL` (default `auto` — avoids pinning SCLK and stealing Zen5 boost on CPU-bound titles; set `high` to force) |
| sysctl | BBR + `fq`; `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0`, `netdev_budget=600`/`budget_usecs=5000`, `vm.compaction_proactiveness=0`, `vm.max_map_count=2147483642`, `vm.swappiness=150` (priority 95, after vendor `70-cachyos-settings.conf`) |
| environment.d | gaming env: `AMD_VULKAN_ICD=RADV`, `MANGOHUD=1`, `MESA_SHADER_CACHE_MAX_SIZE=16G`, `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1`, `WINEDEBUG=-all`, DXVK/VKD3D logging off (`0600`) |
| baloofilerc | KDE Baloo indexing disabled (`0600`) |
| MangoHud.conf | readout-only HUD: GPU sensors (clock/temp/power), CPU sensors, unified memory (`vram`+`ram`), FPS + frametime, `text_outline`. Auto-enabled via `MANGOHUD=1`; toggle `Shift_R+F12` (`0600`) |

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
| Untouched (opt-in) | `iwd.service` — set `NM_WIFI_BACKEND=iwd` + re-run to switch |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables`, `bluetooth` |
| Untouched (by design) | `systemd-oomd` — kernel OOM-killer + zram is the intended path on 128 GB. Do not enable |

**fstab** — ext4 entries get `noatime,lazytime,commit=10` applied in place: on a rewritten ext4 row, redundant or conflicting tokens within the comma-separated options column (`defaults`, `relatime`, `atime`, `strictatime`, and any existing `commit=`) are normalized away and the managed options appended; every other column on that row, and every non-ext4 row, is preserved byte-for-byte. Normalization operates on column 4 only — a row whose options are split by whitespace (already malformed, since mount options must not contain unescaped whitespace) is rejected by the mandatory `findmnt --verify` gate before install rather than silently corrected. Gated by line-count parity, a size floor, and `findmnt --verify`; a symlinked `/etc/fstab` is refused; malformed ext4 rows left untouched with a warning.

## Managed Files

Path/permission index for the 18 files (values in [Configuration](#configuration)). System `0644`, user `0600`.

| Group | Files |
|---|---|
| Boot | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf`, `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` |
| Network | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/bluetooth/main.conf`, `/etc/nftables.conf`, `/etc/modprobe.d/60-ry-mt7925e.conf` |
| Tuning | `/etc/default/cpupower-service.conf`, `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/udev/rules.d/99-ry-perf.rules` |
| User | `~/.config/environment.d/10-environment.conf`, `~/.config/baloofilerc`, `~/.config/MangoHud/MangoHud.conf` |

## Tuning Notes

Gaming and compute knobs outside the managed files, or defaults that warrant explanation.

| Topic | Detail |
|---|---|
| Large-VRAM compute | Auto/GTT caps usable VRAM near 62 GiB on a 96 GB box. For a single allocation above ~62 GiB (ROCm / llama.cpp), raise the **BIOS UMA framebuffer carveout** (up to 96 GB) — not `amdgpu.gttsize`, which is deprecated. Gaming is unaffected. Verify: `cat /sys/module/ttm/parameters/pages_limit`. |
| FSR4 on RDNA3 | `PROTON_FSR4_RDNA3_UPGRADE=1` ships enabled (FSR4 reached RDNA3/3.5 via Proton-CachyOS). Verify: `printenv PROTON_FSR4_RDNA3_UPGRADE` → `1`. |
| NTSYNC | `/dev/ntsync` is asserted in preflight and verify (mainline ≥ 6.14, Proton-CachyOS default-on). Opt a title out with `PROTON_NO_NTSYNC=1` in its launch options. Verify: `test -c /dev/ntsync`. |
| MT7925 ASPM | `/etc/modprobe.d/60-ry-mt7925e.conf` sets `disable_aspm=1` to mitigate coredump / BT-reconnect / assoc-fail on `mt7925e`. Distinct from `wifi.powersave` (software PS) and from the upstream `power_save` param (0444, software WiFi PM). Symptomatic reserve fix — remove if a kernel bump resolves it. Verify: `cat /sys/module/mt7925e/parameters/disable_aspm` → `Y`. The `mt7925e: disabling ASPM L0s L1` dmesg line is logged at probe regardless and is benign. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference.

> [!NOTE]
> Step-by-step reversal is collapsed below.

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

Hardware gaps on Strix Halo.

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

PRs welcome. For config changes, include before/after `--verify` and `--check` output; lint with `shellcheck` and `fish --no-execute`; keep comments single-line; update [CHANGELOG.md](CHANGELOG.md).

## Security

Invokes `sudo` internally; modifies boot config, firewall, and kernel cmdline. Review before running. Report concerns via GitHub issues or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
