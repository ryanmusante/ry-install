# ry-install

[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46?style=flat-square&logo=fishshell&logoColor=white)](https://fishshell.com)
[![systemd](https://img.shields.io/badge/systemd-%E2%89%A5%20250-30b9db?style=flat-square)](https://systemd.io)
[![CachyOS](https://img.shields.io/badge/distro-CachyOS-1793d1?style=flat-square)](https://cachyos.org)

> Idempotent, reversible CachyOS configuration manager for the Beelink GTR9 Pro
> (Ryzen AI Max+ 395 / Radeon 8060S / gfx1151 / Strix Halo).

A single self-contained fish script — 19 embedded configs, no bundled dependencies — that deploys a tuned gaming/LLM desktop profile and can fully roll itself back.

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
> Run as your normal user — **root is refused (exit 2)**; sudo is invoked internally and must be cached first (`sudo -v`). The unattended run **removes packages** (see [Configuration](#configuration)) before you commit. Reboot afterward, then `--verify`. Re-running is idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.57.0
chmod +x ry-install.fish
./ry-install.fish
```

| In scope | Out of scope |
|---|---|
| Kernel cmdline, Initramfs, Systemd units, Network (NetworkManager + iwd), Sysctl, Gaming env vars, MangoHud HUD, KDE Baloo indexing, Pacman add/remove, sdboot-manage BLS entries | Dotfiles, Secrets, Backups, Multi-user, Non-CachyOS, Laptops, UKI |

## Requirements

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/` (warn < 5), 200 MiB `/boot` (warn < 500) |

Hard requirements abort read-only in preflight (exit 3): `pacman`, `systemctl`, `mkinitcpio`, `sdboot-manage`, `findmnt`, `sha256sum`, `curl`, GNU coreutils (`id`, `timeout --foreground/--kill-after`, `mv -T`, `df --output`), findutils (`find -maxdepth/-printf`), diffutils (`cmp`, gating the `mkinitcpio.conf` byte-exact revert). busybox/uutils are rejected. NTP sync and `paccache` only warn. sudo must be cached (`sudo -v`).

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits 4 and prints the DO-NOT-REBOOT recovery banner — **do not reboot** until it succeeds. A non-vfat `/boot` ESP fallback also refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output (ignored under `--check`) |
| `--verify` | Config files byte-for-byte, then live system state |
| `--check` | Silent idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End of options (no positional args accepted) |
| `-h`/`--help` · `-v`/`--version` | Honored before all checks (even before the root guard) |

`--verify`/`--check` are lock-free and read-only. `--install-file` requires an absolute path (PATH_MAX 4096, NAME_MAX 255/component, no control chars) resolving via `realpath -m` to a managed destination. Malformed args are rejected before dispatch, well-formed non-managed paths after ("Not a managed file"); both exit 2.

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run. mkinitcpio rollback restores the prior `mkinitcpio.conf` byte-for-byte on such failure or on signal.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | config checks → lock → hard gates (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 19 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → iwd disable → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache` → NetworkManager restart |

A CHECK/RESULT/EVIDENCE matrix prints to stderr; a JSONL log records each phase. `WARN` keeps exit `0`; `DEFER` applies on next boot (e.g. the regulatory domain, applied by CachyOS hooks at device-add).

## Configuration

The script is the source of truth — retune the `set -g` globals near the top.

*Expand below for the full per-file key-value reference.*

<details>
<summary><strong>Full managed-file reference</strong> — all 19 files, key values</summary>

| File | Purpose & key values |
|---|---|
| loader.conf | systemd-boot loader: `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| sdboot-manage.conf | entry generation: `DEFAULT_ENTRY=manual`, `OVERWRITE_EXISTING=yes`, `REMOVE_EXISTING=yes` (wipes `loader/entries/` before regen), `REMOVE_OBSOLETE=yes`; `LINUX_OPTIONS` = the cmdline params, `LINUX_FALLBACK_OPTIONS="quiet"` |
| kernel cmdline | `rw root=UUID=<root>` (resolved) + `8250.nr_uarts=0`, `amd_pstate=active`, `amd_iommu=off`, `clearcpuid=rdseed`, `nowatchdog`, `nvme_core.default_ps_max_latency_us=0`, `pcie_aspm.policy=performance`, `quiet`, `split_lock_detect=off`, `tsc=reliable`, `usbcore.autosuspend=-1`, `zswap.enabled=0` |
| mkinitcpio.conf | `MODULES=(amdgpu)`; `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`; `COMPRESSION="zstd"` (`-1 -T0`); `BINARIES=()`, `FILES=()` |
| resolved | `MulticastDNS=no`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` — plaintext DNS, mDNS/LLMNR off (latency-first; diverges from CachyOS DoH default) |
| logind | `Handle{Power,Suspend,Hibernate,Reboot}Key`=ignore (+ `LongPress` variants) |
| iwd / NetworkManager | iwd Wi-Fi backend (`wifi.backend=iwd`); `iwd.service` disabled (NM D-Bus-activates iwd on demand). Power-save off for MT7925 latency: NM `wifi.powersave=2` + iwd `[DriverQuirks] PowerSaveDisable=*`. iwd `EnableNetworkConfiguration=false`, `NameResolvingService=systemd`; NM `logging level=WARN` |
| cpupower / udev | `powersave` governor; udev sets NVMe I/O scheduler `none` (peak IOPS/lowest tail latency; diverges from CachyOS kyber default), AMD P-State EPP `balance_performance`, gfx1151 GPU clock-floor (`power_dpm_force_performance_level=high`, card-scoped `KERNEL=="card[0-9]"`) |
| sysctl | BBR + `fq`; `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0`, `netdev_budget=600`/`budget_usecs=5000`, `vm.compaction_proactiveness=0`, `vm.max_map_count=2147483642` (priority 95, after vendor `70-cachyos-settings.conf`) |
| RADV drirc | `radv_enable_unified_heap_on_apu=true` (Mesa MR !18884, Mesa 22.3+) |
| amdgpu/ttm modprobe | GTT cap via in-kernel `ttm.*` (not deprecated `amdgpu.gttsize`/`amdttm.*`). `pages_limit`=`page_pool_size`; pages = GiB × 262144. Shipped cap 32 GiB = 8388608 (below the in-kernel ~50%-of-RAM default, ~62 GiB on 128 GB). Retune both `TTM_*` globals (116 GiB = 30408704). Assumes BIOS UMA 512 MB |
| iw-regdomain / wireless-regdom | wireless regulatory domain fixed at `US` (retune `COUNTRY`); consumed by CachyOS regdomain hooks at device-add |
| nftables.conf | default-deny-inbound ruleset (see [Safety & Reliability](#safety--reliability)) |
| environment.d | gaming env: `AMD_VULKAN_ICD=RADV`, `MANGOHUD=1`, `MESA_SHADER_CACHE_MAX_SIZE=16G`, `PROTON_ENABLE_WAYLAND=1`, `PROTON_LOCAL_SHADER_CACHE=1`, `WINEDEBUG=-all`, DXVK/VKD3D logging off (`0600`) |
| baloofilerc | KDE Baloo file indexing disabled (`0600`) |
| MangoHud.conf | readout-only HUD: GPU/CPU sensors, unified memory (`vram`+`ram`), FPS with 1%/0.1% lows. Auto-enabled via `MANGOHUD=1`; toggle `Shift_R+F12` (`0600`) |

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
| Mask | `ananicy-cpp`, `power-profiles-daemon`, `NetworkManager-wait-online`, `ufw`, and the sleep/suspend/hibernate/hybrid-sleep/suspend-then-hibernate targets |
| Disable (not mask) | `iwd.service` — NM is sole Wi-Fi manager and D-Bus-activates iwd on demand (a separately-enabled iwd.service races NM) |
| Enable | `fstrim.timer`, `NetworkManager`, `cpupower`, `nftables` |
| Untouched (by design) | `systemd-oomd` — left as-is. CachyOS disables it by default (killed apps too early with le9); the kernel OOM-killer + zram is the intended path on 128 GB. Do not enable |

**fstab** — ext4 entries get `noatime,lazytime,commit=10` rewritten in place; all other rows/columns preserved byte-for-byte. Gated by line-count parity, a size floor, and `findmnt --verify`; a symlinked `/etc/fstab` is refused; malformed ext4 rows left untouched with a warning.

## Managed Files

Canonical path and permission index for the 19 files (described in [Configuration](#configuration)). System `0644`, user `0600`:

*Expand below for the canonical path-and-permission listing by group.*

<details>
<summary><strong>Path and permission index</strong> — 19 files by group</summary>

| Group | Files |
|---|---|
| Boot | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| Network | `/etc/iwd/main.conf`, `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/conf.d/wireless-regdom`, `/etc/nftables.conf` |
| Tuning | `/etc/default/cpupower-service.conf`, `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/drirc.d/95-ry-radv-apu.conf`, `/etc/modprobe.d/ry-amdgpu-strixhalo.conf`, `/etc/udev/rules.d/60-ry-perf.rules` |
| User | `~/.config/environment.d/10-environment.conf`, `~/.config/baloofilerc`, `~/.config/MangoHud/MangoHud.conf` |

</details>

## Safety & Reliability

> [!WARNING]
> This profile **masks `ufw`** and ships a minimal **nftables default-deny-inbound** ruleset: established/related and loopback accepted, `ct state invalid` dropped, inbound IPv4 ICMP scoped to diagnostics (`echo-reply`, `destination-unreachable`, `time-exceeded`, `parameter-problem` — inbound `echo-request`/ping is **dropped**) plus essential ICMPv6 (NDP + echo/PMTUD/time-exceeded/param-problem) accepted, all other inbound dropped (including mDNS). `forward` policy drop, `output` policy accept.

> [!NOTE]
> `REMOVE_EXISTING=yes` makes `sdboot-manage gen` delete every `loader/entries/` entry before regenerating — including foreign/other-OS BLS entries. EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

| Feature | Detail |
|---|---|
| Atomic writes | same-FS tmp → render via generator → symlink-probe → backup → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` (and `fstab`, during its atomic rewrite) |
| mkinitcpio rollback | byte-exact revert (gated by `cmp`) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Instance lock | atomic `mkdir 0700`; stale-lock reclaim only for a provably recycled PID via `/proc` start-time (unsignalable/unknown ⇒ fail-closed) |

*Expand below for the full exit-code, sentinel, and environment-override reference.*

<details>
<summary><strong>Exit codes, sentinels, and environment overrides</strong></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, 129 HUP, 131 QUIT, 134 ABRT) |

Internal sentinels `11`–`13` (`GEN_NOFN`/`GEN_NOUUID`/`GEN_SYSCTL`) and `250`/`251`/`255` (`AS_MISUSE`/`RUN_TMPFAIL`/`RUN_MISUSE`) never reach a process exit; a generator failure surfaces only as the footer's `gen_fail` count. The only non-standard footer `exit_code` is `128+N` on signal.

Environment overrides (safe fallback when unset/invalid): `RY_RUN_TIMEOUT` (per-command cap, default `3600` s, `0` disables; `pacman`/`mkinitcpio`/`sdboot-manage`/`paccache`/`updatedb`/`pkgfile` exempt — a mid-transaction `SIGKILL` would corrupt `db.lck` or bypass rollback), `RY_INSTALL_SKIP_HARDWARE_CHECK=1`, `NO_COLOR`, `TMPDIR` (falls back to `/tmp`). Logs: one JSONL per run at `~/ry-install/logs/YYYY-MM-DD/MODE-...-PID.jsonl`, mode `0600`.

</details>

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference.

| # | Step | Command |
|---|---|---|
| 1 | Unmask the masked units | `sudo systemctl unmask ananicy-cpp.service power-profiles-daemon.service NetworkManager-wait-online.service ufw.service sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target` |
| 2 | Remove deployed system paths, then the user env.d file | `sudo rm /etc/sdboot-manage.conf /etc/sysctl.d/95-ry-overrides.conf /etc/drirc.d/95-ry-radv-apu.conf /etc/modprobe.d/ry-amdgpu-strixhalo.conf /etc/udev/rules.d/60-ry-perf.rules /etc/iw-regdomain /etc/conf.d/wireless-regdom /etc/nftables.conf /etc/default/cpupower-service.conf /etc/iwd/main.conf /etc/NetworkManager/conf.d/99-cachyos-nm.conf /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf /etc/systemd/logind.conf.d/99-cachyos-logind.conf` then `rm ~/.config/environment.d/10-environment.conf ~/.config/baloofilerc ~/.config/MangoHud/MangoHud.conf` |
| 3 | Restore fstab, then delete `.ry.bak` backups | `sudo mv /etc/fstab.ry.bak /etc/fstab` then `sudo rm -f /boot/loader/loader.conf.ry.bak /etc/mkinitcpio.conf.ry.bak` |
| 4 | Optionally reverse package changes | `sudo pacman -S --needed plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme breeze-plymouth plymouth-kcm micro cachyos-micro-settings cachy-update kdeconnect` then `sudo pacman -Rns nvme-cli cachyos-gaming-meta cachyos-gaming-applications lib32-mesa mkinitcpio-firmware fd sd dust procs bottom htop git-delta lm_sensors rtkit realtime-privileges ddcutil nftables` |
| 5 | Rebuild initramfs and boot entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

For boot files (`loader.conf`, `/etc/kernel/cmdline`, `mkinitcpio.conf`), the Phase-5 rebuild regenerates entries from the restored/removed state; revert their contents (or restore `.ry.bak`) before step 5.

---

## Known Issues

Hardware gaps on Strix Halo. MES page faults and RTL8127 are resolved upstream (current kernel + `linux-firmware`; the shipped `mkinitcpio-firmware` covers the firmware side). MT7925 and ACP remain open.

| Component | Issue | Status |
|---|---|---|
| Strix Halo GPU | MES page faults | resolved upstream (MES 0x86); current `linux-firmware` + shipped `mkinitcpio-firmware` carry the fix |
| RTL8127 10GbE | throughput drops under load | resolved upstream — in-tree `r8169` (commit `f24f7b2f3af9` + suspend fix `ae1737e7339b`); no DKMS |
| MT7925 | kernel panics, low TX power, random deauth | open — out-of-tree DKMS; some fixes upstream. The `3 dBm` TX-power readout is cosmetic (correct power applied) |
| Strix Halo ACP | no ASoC machine driver | open — pending upstream (HDMI/USB audio unaffected) |

### Configuration-level (intended behavior, documented for awareness)

These are consequences of deliberate profile choices, not defects. Each is what the profile is *supposed* to do; they are listed so the resulting log lines aren't mistaken for faults.

| Item | Consequence | Rationale / action |
|---|---|---|
| `amd_iommu=off` (cmdline) | The NPU (`amdxdna`) cannot probe: `aie2_init: Running without IOMMU not supported`, `probe ... failed -22`. Expected; the NPU is disabled by this profile. | `amdxdna` requires IOMMU/SVA. Harmless if you don't use Ryzen AI. To enable the NPU, set `amd_iommu=on iommu=pt` in `KERNEL_PARAMS`, then re-run (or `--install-file /etc/kernel/cmdline`) and reboot. |
| TTM GTT cap assumes BIOS UMA ≤ 1 GiB | Preflight emits a **non-fatal WARN** (`TTM_UMA_PRECONDITION: vram_mib=N expected<=1024`) when the firmware reports a large fixed dedicated VRAM (e.g. 32768 MiB), because the 32 GiB `ttm.pages_limit` cap may not apply as intended. Install continues (exit 0). | Set the BIOS iGPU/UMA frame buffer to **Auto** (or ≤ 512 MB) to match the cap assumption, or retune both `TTM_*` globals to your fixed split. Verify: `cat /sys/class/drm/card*/device/mem_info_vram_total`. |
| RDSEED on Zen 5 / Strix Halo | On affected microcode the kernel flags RDSEED as broken (`RDSEED32 is broken. Please update your firmware.`), which can break `-march=znver*` Qt/crypto callers. The cmdline ships `clearcpuid=rdseed`, which masks the capability so software stops probing it and the warning is silenced (this taints the kernel — cosmetic). | CVE-2025-62626 / AMD SB-7055. To instead *restore* a working RDSEED, drop `clearcpuid=rdseed` from `KERNEL_PARAMS` and update microcode: `sudo pacman -Syu --needed amd-ucode linux-firmware && sudo mkinitcpio -P && reboot` (model `0x70` fixed at `0x0b700037`). The `microcode` initramfs hook is already in `MKINITCPIO_HOOKS`. |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Rebuild refused | a phase tainted boot state — fix the cause, then re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login (needs `realtime-privileges`) |
| ddcutil permission denied | `sudo usermod -aG i2c $USER`, re-login (needs `ddcutil`) |

> [!NOTE]
> The installer detects missing `realtime`/`i2c` membership and prints these `usermod` commands, but does not run them. A group change is inert until re-login (it can't affect the running session), can't be cleanly reverted like the managed config files, and targets a user the root-run script must infer — so it hands you the exact command instead.

## Contributing

Issues and PRs welcome. For changes to managed configs, include the `--verify` and `--check` output before and after. Lint with `shellcheck` and `fish --no-execute` before submitting; keep comments single-line and update [CHANGELOG.md](CHANGELOG.md).

## Security

This script invokes `sudo` internally and modifies boot configuration, the firewall, and kernel cmdline. Review it before running. Report security concerns via GitHub issues, or privately to the maintainer.

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
