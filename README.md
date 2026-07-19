# ry-install

[![version](https://img.shields.io/badge/version-7.120.0-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish%203.6%2B-1793d1?style=flat-square)](#requirements)

Idempotent CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 17 embedded configs — atomic, byte-verifiable, reversible.

## Contents

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Usage](#usage)
- [Exit Codes](#exit-codes)
- [Environment Overrides](#environment-overrides)
- [Install Flow](#install-flow)
- [Safety and Reliability](#safety-and-reliability)
- [Packages](#packages)
- [Units](#units)
- [Managed Files](#managed-files)
- [Embedded Values](#embedded-values)
- [Tuning Notes](#tuning-notes)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [License](#license)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.120.0
sudo -v
./ry-install.fish
```

> [!WARNING]
> Run as your normal user — never with `sudo`. The unattended run **removes packages** ([Packages](#packages)). Reboot, then `--verify`. Re-runs are idempotent.

## Requirements

| Requirement | Detail |
|---|---|
| OS | CachyOS (Arch-based), systemd-boot with BLS entries |
| Shell | fish 3.6 or newer |
| Hardware | CPU matching `Ryzen AI Max` — bypass via [Environment Overrides](#environment-overrides) |
| Privileges | Normal user with sudo rights; `sudo -v` cached before the run |
| Tools | GNU coreutils, `pacman`, `mkinitcpio`, `sdboot-manage`, `systemctl` |

In scope: the 17 [Managed Files](#managed-files), pacman add/remove, systemd units, and the fstab rewrite. Everything else on the system is left alone.

## Usage

| Invocation | Behavior |
|---|---|
| `./ry-install.fish` | Unattended install — all six phases |
| `./ry-install.fish --verify` | Check config files and live system state |
| `./ry-install.fish --check` | Silent idempotency probe against live `/proc/cmdline`; a fresh install reports drift until reboot |
| `./ry-install.fish --install-file <path>` | Re-deploy a single managed file |
| `./ry-install.fish --help` | Usage summary; honored before every other check |
| `./ry-install.fish --version` | Version string; honored before every other check |

`--verify`, `--check`, and `--install-file` are mutually exclusive. No positional arguments are accepted. Every result goes to stderr; stdout carries only `--help` and `--version` output. Each run writes a JSONL record to `~/ry-install/logs/YYYY-MM-DD/`.

## Exit Codes

| Code | Meaning | Emitted when |
|---|---|---|
| `0` | OK | Success, `WARN`-only runs, and a clean `--check` |
| `1` | verify-FAIL / install-error | `--verify` mismatch, or an install step errored |
| `2` | usage | Bad arguments, non-absolute or unmanaged `--install-file`, root-guard misuse |
| `3` | preflight | Missing or non-GNU dependency, uncached sudo, gate mismatch, root with `--check` (silent) |
| `4` | boot-critical | Boot cascade or post-rebuild sanity failed — **do not reboot**, resolve first |
| `5` | lock | Another instance holds the lock; ambiguous pidfiles fail closed |
| `10` | drift | `--check` found drift from the managed baseline |

Sentinels `11`–`14`, `250`, `251`, and `255` are internal function returns and never surface as process exits. Signals exit `128+N`.

## Environment Overrides

| Variable | Effect |
|---|---|
| `RY_RUN_TIMEOUT=<sec>` | Per-command wall-clock cap. Default `3600`; `0` disables; package and boot operations floor at `7200` |
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | Bypass the `EXPECTED_CPU_MATCH` hard-fail. Deploying gfx1151 defaults on a non-matching CPU writes an incorrect kernel cmdline and initramfs `MODULES` |
| `NO_COLOR` | Disable colored output ([no-color.org](https://no-color.org)). Color also auto-disables when stderr is not a TTY or `TERM` is `dumb` |

## Install Flow

| Phase | Name | Work |
|---|---|---|
| 1 | Preflight | Dependency, network, disk, and systemd gates; hardware match; lock acquisition |
| 2 | Packages | `pacman -Syu`, install `PKGS_ADD`, re-mark them explicit |
| 3 | Configuration | Deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved restart → package removal → mask → enable → regulatory domain |
| 5 | Boot | `mkinitcpio -P`, `sdboot-manage gen`, `sdboot-manage update`, boot sanity |
| 6 | Finalize | User daemon-reload, pacman cache trim, NetworkManager restart |

Phase 4 masks `ufw.service` rather than removing the package: the nftables ruleset is confirmed live and default-deny before the ufw flush, so there is no window without inbound protection. If the ruleset cannot be confirmed, the mask is withheld for the run.

## Safety and Reliability

| Guarantee | Mechanism |
|---|---|
| Atomic writes | Same-filesystem temp file, pre-validation (`nft -c` for the ruleset), backup, atomic `mv -T`, re-read, restore on mismatch |
| Backups | `<path>.ry.bak` for the 4 boot files and for `fstab` during its rewrite; a one-time `<path>.ry.orig` for any other managed file whose pre-existing content differed |
| Boot protection | Boot-critical failures set exit `4` and skip finalization rather than leaving a half-rebuilt ESP |
| Single instance | Atomic `mkdir` lock with dead-PID reclaim; live or ambiguous PIDs fail closed |
| Byte verification | `--verify` compares installed bytes against the embedded generator output by SHA256 |
| Idempotency | Re-runs converge; `--check` reports drift without writing anything |

`sdboot-manage` runs with `REMOVE_EXISTING=yes`. DNS is plaintext — `DNSOverTLS=no` and `DNSSEC=no`, both diverging from the CachyOS default. The sysctl drop-in uses priority `95` so it loads after the vendor `70-cachyos-settings.conf`. NVMe scheduler is `none` where the vendor default is `kyber`.

## Packages

`pacman -Rns` is rdep-aware via `pactree` (from `pacman-contrib`). Phase 2 re-marks every `PKGS_ADD` package explicit after `-Syu`, so a later `-Rns` cannot orphan a dependency-installed one.

| Action | Packages |
|---|---|
| Install | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `lm_sensors`, `rtkit`, `realtime-privileges`, `nftables`, `pacman-contrib` |
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro`, `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verified present | `vulkan-radeon`, `lib32-vulkan-radeon` |

## Units

| Action | Units |
|---|---|
| Enable | `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service`, `bluetooth.service` |
| Mask | `ananicy-cpp.service`, `power-profiles-daemon.service`, `NetworkManager-wait-online.service`, `avahi-daemon.service`, `avahi-daemon.socket`, `ufw.service`, `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target` |

## Managed Files

17 embedded configs in deploy order — 4 boot-critical (`.ry.bak`-backed), 11 system, 2 user. `--verify` checks all of them; `--install-file` re-deploys one.

### Boot

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot: `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| `/etc/kernel/cmdline` | `rw root=UUID=<detected>` plus the 14 kernel tokens |
| `/etc/sdboot-manage.conf` | `LINUX_OPTIONS` mirror, `LINUX_FALLBACK_OPTIONS="quiet"`, entry management keys |
| `/etc/mkinitcpio.conf` | `MODULES` (`amdgpu`, early KMS), `HOOKS`, `COMPRESSION` `zstd` (`-1 -T0`) |

### System

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | plaintext DNS, mDNS and LLMNR off |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power, suspend, hibernate, and reboot keys — 8 keys including long-press variants |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | `LogLevelMax=notice` drops info-level dispatcher lines |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `wpa_supplicant` backend, Wi-Fi powersave off, log level `WARN` |
| `/etc/iw-regdomain` | regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | adapter auto-power-on, `FastConnectable`, 3 paired-sink reconnect attempts |
| `/etc/nftables.conf` | IPv4-only default-deny-inbound, ping allowed |
| `/etc/default/cpupower-service.conf` | governor (`powersave`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | `fq` qdisc, netdev budget, TCP `bbr`, VM tunables |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, P-State EPP, GPU DPM level `auto` |
| `/etc/modprobe.d/60-ry-modules.conf` | `amdxdna` blacklist |

### User

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | session env — DXVK, MangoHud, Proton, VKD3D, Wine, plus `POWERDEVIL_NO_DDCUTIL=1` |
| `~/.config/MangoHud/MangoHud.conf` | readout-only HUD — horizontal, top-left, toggle `Shift_R+F12` |

Permissions: system files `0644`, user files `0600`.

## Embedded Values

All tunables are `set -g` globals near the top of the script — there is no external config file. Edit one, then re-run or `--install-file` the affected file. Porting to other hardware starts at `PROFILE_NAME`, `PROFILE_DESC`, and `EXPECTED_CPU_MATCH`.

### Kernel Parameters

| Token | Effect |
|---|---|
| `amd_iommu=off` | IOMMU fully off — lowest DMA-mapping overhead |
| `amd_pstate=active` | CPPC autonomous mode — the `amd-pstate-epp` scaling driver |
| `btusb.enable_autosuspend=n` | keep the BT controller powered — no wake or reconnect stalls |
| `clearcpuid=umip` | disable UMIP trapping |
| `fsck.mode=force` | run fsck on every boot |
| `fsck.repair=yes` | auto-repair whatever fsck finds |
| `ipv6.disable=1` | disable the IPv6 stack |
| `nvme_core.default_ps_max_latency_us=0` | NVMe APST off — no power-state exit latency |
| `pcie_aspm.policy=performance` | force every PCIe link out of ASPM |
| `processor.max_cstate=1` | cap ACPI C-states at C1 — idle-exit latency floor |
| `quiet` | suppress boot console noise |
| `split_lock_detect=off` | no split-lock throttling penalty in games |
| `usbcore.autosuspend=-1` | USB autosuspend off globally |
| `zswap.enabled=0` | zswap off — zram is the swap path |

### Session Environment

| Variable | Effect |
|---|---|
| `DXVK_LOG_LEVEL=none` | DXVK logging off |
| `FSR4_UPGRADE=1` | enable the FSR4 upgrade path |
| `MANGOHUD=1` | HUD on for Vulkan titles |
| `MESA_SHADER_CACHE_MAX_SIZE=16G` | roomy Mesa shader cache |
| `POWERDEVIL_NO_DDCUTIL=1` | PowerDevil DDC/CI off — silences `org_kde_powerdevil` i2c errors |
| `PROTON_ENABLE_WAYLAND=1` | native-Wayland Proton path |
| `PROTON_LOCAL_SHADER_CACHE=1` | per-prefix shader cache |
| `VKD3D_CONFIG=descriptor_heap` | D3D12 descriptor-heap fast path |
| `VKD3D_DEBUG=none` | vkd3d logging off |
| `VKD3D_SHADER_DEBUG=none` | vkd3d shader logging off |
| `WINEDEBUG=-all` | Wine debug channels off |

### Sysctl Overrides

| Key | Value | Effect |
|---|---|---|
| `net.core.default_qdisc` | `fq` | pairs with BBR |
| `net.core.netdev_budget` | `600` | wider NAPI polling for 10GbE |
| `net.core.netdev_budget_usecs` | `5000` | matching poll time budget |
| `net.ipv4.tcp_congestion_control` | `bbr` | BBR congestion control |
| `net.ipv4.tcp_notsent_lowat` | `16384` | cap unsent buffer at 16 KiB for send latency |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | keep the congestion window across idle |
| `vm.compaction_proactiveness` | `0` | proactive compaction off — reclaim-stall source |
| `vm.max_map_count` | `2147483642` | Steam's esync requirement |
| `vm.swappiness` | `150` | push swap traffic onto zram |
| `vm.watermark_boost_factor` | `0` | watermark boosting off — reclaim-stall source |

## Tuning Notes

Non-obvious choices; several list an override to reverse.

| Topic | Detail |
|---|---|
| NTSYNC | `--verify` reports `/dev/ntsync` — present ok, module-without-node warn, absent info. Opt out with `PROTON_NO_NTSYNC=1` |
| AMD-Vi (IOMMU) | `amd_iommu=off` breaks the XDNA NPU, hence the blacklist. For NPU, VFIO, or SR-IOV: `amd_iommu=on iommu=pt` plus `BLACKLIST_AMDXDNA false`, then re-run |
| UMIP | `clearcpuid=umip` disables UMIP trapping and taints the kernel. The string form is version-stable since CPUID bit numbers shift between kernels. Drop it if there is no `umip_printk` stutter |
| IPv6 | `ipv6.disable=1` with an IPv4-only ruleset. For dual-stack: drop the token, add IPv6 rules, re-run |
| PCIe ASPM | `pcie_aspm.policy=performance` actively disables ASPM on every link — fixes MT7925 coredumps, BT reconnect, and association, plus NVMe latency. Drop to restore ASPM defaults |
| FSR4 on RDNA3 | `FSR4_UPGRADE=1` ships enabled for RDNA3 and 3.5. Verify with `printenv FSR4_UPGRADE` |
| Avahi | `.service` and `.socket` are masked — they collided with resolved as a second mDNS responder, and the profile runs `MulticastDNS=no`. Unmask both to restore |
| MangoHud `cpu_temp` | Intentionally commented out in the shipped HUD — uncomment to show CPU temperature. `cpu_power` ships active but reads 0 on Zen 5 |
| Large-VRAM compute | GTT caps usable VRAM near 62 GiB; raise the BIOS UMA carveout (up to 96 GiB) for more, since `amdgpu.gttsize` is deprecated. Check `/sys/module/ttm/parameters/pages_limit` |

## Troubleshooting

| Symptom | Action |
|---|---|
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update` |
| Rebuild refused | A phase tainted boot state — fix the cause, then re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`, then re-run |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login — needs `realtime-privileges` |
| BT speaker will not auto-reconnect | `bluetoothctl trust <MAC>`, then power the speaker on after login |

### libvirt and QEMU NAT

The `forward { policy drop; }` chain silently breaks libvirt and QEMU NAT guest WAN access, since libvirt's own rules no longer see the traffic. VMs are out of scope, but if you run them, add to `/etc/nftables.conf`:

```
# input - guest DHCP/DNS to the host dnsmasq:
iifname "virbr0" udp dport { 53, 67 } accept
iifname "virbr0" tcp dport { 53, 67 } accept

# forward - survive the global drop:
iifname "virbr0" accept
oifname "virbr0" ct state established,related accept
```

Do **not** duplicate NAT — libvirt's `guest_nat` already masquerades `192.168.122.0/24`.

## Uninstall

There is no automated uninstaller. Use [Managed Files](#managed-files) as the rollback reference and work through these six steps in order.

| # | Step | Action |
|---|---|---|
| 1 | Unmask units | `sudo systemctl unmask` all 11 masked units — exact set in [Units](#units) |
| 2 | Remove configs | `sudo rm` the 11 system files and `rm` the 2 user files; skip the 4 boot files, step 3 reverts them |
| 3 | Revert boot files and fstab | Restore `.ry.bak` over `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`, and `/etc/fstab` if present, then delete the `.ry.bak` files |
| 4 | Reverse packages (optional) | `pacman -S --needed` the Remove list, `pacman -Rns` the Install list — exact sets in [Packages](#packages) |
| 5 | Rebuild initramfs and entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

Disable `nftables` before step 2 — its unit loads `/etc/nftables.conf` at start and fails once the ruleset is gone. Disable any other enabled unit you no longer want the same way. Boot files must be reverted before step 5, which regenerates entries from that state. A `.ry.bak` exists only if the file was present before the overwrite; for fstab, only if it was rewritten. A one-time `<path>.ry.orig` may exist for non-boot managed files — restore it instead of plain removal where you want the original back, then delete it.

## License

MIT.
