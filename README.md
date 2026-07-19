# ry-install

**Version 7.123.0** &nbsp;·&nbsp; [Changelog](CHANGELOG.md)

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
- [Managed Files](#managed-files)
- [Install Flow](#install-flow)
- [Safety and Reliability](#safety-and-reliability)
- [Embedded Values](#embedded-values)
- [Packages](#packages)
- [Units](#units)
- [Tuning Notes](#tuning-notes)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [License](#license)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.123.0
sudo -v
./ry-install.fish
```

> [!WARNING]
> Run as your normal user — never with `sudo`. The unattended run **removes packages** ([Packages](#packages)). Reboot, then `--verify`. Re-runs are idempotent.

A successful run closes with `Verdict: PASS` above the Totals line. Anything else is explained in [Usage](#usage) and [Exit Codes](#exit-codes).

## Requirements

| Requirement | Detail |
|---|---|
| OS | CachyOS (Arch-based), systemd-boot with BLS entries |
| Shell | fish 3.6 or newer |
| Hardware | CPU matching `Ryzen AI Max` — bypass via [Environment Overrides](#environment-overrides) |
| Privileges | Normal user with sudo rights; `sudo -v` cached before the run |
| Tools | GNU coreutils, `pacman`, `mkinitcpio`, `sdboot-manage`, `systemctl` |

In scope: the 17 [Managed Files](#managed-files), pacman add/remove, systemd units, and the fstab rewrite. Everything else on the system is left alone.

### BIOS

Multi-thread gains flatten past ~85 W. Set a flat `SPL = fPPT = sPPT = 85 W` ceiling (stock boosts to 140 W) with `STAPM Boost = 0` and `TjMax = 90 °C`, under `Advanced → SMU Common Options`. Full per-setting walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference).

## Usage

| Invocation | Behavior |
|---|---|
| `./ry-install.fish` | Unattended install — all six phases |
| `./ry-install.fish --verify` | Check config files and live system state |
| `./ry-install.fish --check` | Silent idempotency probe against live `/proc/cmdline`; a fresh install reports drift until reboot |
| `./ry-install.fish --install-file <path>` | Re-deploy a single managed file |
| `./ry-install.fish --help` | Usage summary; honored before every other check |
| `./ry-install.fish --version` | Version string; honored before every other check |

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` and `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits `4` — **do not reboot** until it succeeds. ESP autodetect (`bootctl` → `findmnt`) failure falls back to `/boot` with a warning; a non-vfat fallback then refuses sdboot (exit `4`).

`--verify`, `--check`, and `--install-file` are mutually exclusive. No positional arguments are accepted. Every result goes to stderr; stdout carries only `--help` and `--version` output. Each run writes one JSONL log (`0600`) to `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`.

Each phase reports one verdict, tallied in the closing Totals line:

| Verdict | Meaning |
|---|---|
| `PASS` | The phase did what it set out to do |
| `WARN` | Something non-fatal — keeps exit `0` |
| `FAIL` | The phase did not complete |
| `DEFER` | Applies at next boot, as with the NetworkManager restart over Wi-Fi |
| `SKIP` | Preconditions absent, so the phase did not run |
| `--` | Not applicable — shown as `N/A` in Totals |

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
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | Bypass the `EXPECTED_CPU_MATCH` hard-fail |
| `NO_COLOR` | Disable colored output ([no-color.org](https://no-color.org)) |

Color also auto-disables when stderr is not a TTY or `TERM` is `dumb`. Skipping the hardware check is the risky one: deploying gfx1151 defaults on a non-matching CPU writes an incorrect kernel cmdline and initramfs `MODULES`.

## Managed Files

17 embedded configs in deploy order — 4 boot-critical (`.ry.bak`-backed), 11 system, 2 user. `--verify` checks all of them; `--install-file` re-deploys one.

### Boot

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot: `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| `/etc/kernel/cmdline` | `rw root=UUID=<detected>` plus the 15 kernel tokens |
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

## Install Flow

| Phase | Name | Work |
|---|---|---|
| 1 | Preflight | Dependency, network, disk, and systemd gates; hardware match; lock acquisition |
| 2 | Packages | Seed `mkinitcpio.conf`, `pacman -Syu`, install `PKGS_ADD`, re-mark them explicit, refresh `updatedb` and `pkgfile` |
| 3 | Configuration | Deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved restart → package removal → mask → enable → regulatory domain |
| 5 | Boot | `mkinitcpio -P`, `sdboot-manage gen`, `sdboot-manage update`, boot sanity |
| 6 | Finalize | User `daemon-reload` (plus a PowerDevil re-apply when the env file changed), `paccache -rk2` and `-ruk0`, NetworkManager restart |

Phase 4 masks `ufw.service` rather than removing the package: the nftables ruleset is confirmed live and default-deny before the ufw flush, so there is no window without inbound protection. If the ruleset cannot be confirmed, the mask is withheld for the run. The `ufw` package stays installed.

The shipped ruleset is IPv4-only default-deny-inbound. Loopback, established and related traffic, and ICMP echo-request plus the error and PMTUD types (destination-unreachable, time-exceeded, parameter-problem) are accepted; `invalid` state is dropped; `forward` drops and `output` accepts. IPv6 is disabled system-wide via `ipv6.disable=1`.

## Safety and Reliability

Every managed file is written atomically: content is rendered to a temp file on the same filesystem, pre-validated where a validator exists (`nft -c` for the ruleset), backed up, moved into place with `mv -T`, then re-read and compared. A mismatch restores the backup.

Backups are `<path>.ry.bak` for the 4 boot files and for `fstab` during its rewrite. Any other managed file whose pre-existing content differed at first adoption gets a one-time `<path>.ry.orig`.

The fstab rewrite gives ext4 rows `noatime,lazytime,commit=10` in column 4, normalizing away redundant `defaults`, `relatime`, `atime`, `strictatime` and existing `commit=` tokens. Everything else is byte-preserved. It is gated by line-count parity, a size floor and a mandatory `findmnt --verify`; a symlinked `/etc/fstab` aborts the rewrite, and malformed rows are left byte-identical and warned.

Boot-critical failures exit `4` and skip finalization rather than leaving a half-rebuilt ESP. Only one instance runs at a time, enforced by an atomic `mkdir` lock with dead-PID reclaim — live or ambiguous PIDs fail closed. `--verify` compares installed bytes against the embedded generator output by SHA256, and re-runs converge, so `--check` reports drift without writing anything.

`sdboot-manage` runs with `REMOVE_EXISTING=yes`. DNS is plaintext — `DNSOverTLS=no` and `DNSSEC=no`, both diverging from the CachyOS default. The sysctl drop-in uses priority `95` so it loads after the vendor `70-cachyos-settings.conf`. NVMe scheduler is `none` where the vendor default is `kyber`.

## Embedded Values

All tunables are `set -g` globals near the top of the script — there is no external config file. Edit one, then re-run or `--install-file` the affected file. Porting to other hardware starts at `PROFILE_NAME`, `PROFILE_DESC`, and `EXPECTED_CPU_MATCH`.

### Bootloader Keys

| Key | Value | File |
|---|---|---|
| `LOADER_DEFAULT` | `@saved` | `loader.conf` |
| `LOADER_TIMEOUT` | `0` | `loader.conf` |
| `LOADER_CONSOLE_MODE` | `keep` | `loader.conf` |
| `LOADER_EDITOR` | `no` | `loader.conf` |
| `SDBOOT_DEFAULT_ENTRY` | `manual` | `sdboot-manage.conf` |
| `SDBOOT_OVERWRITE` | `yes` | `sdboot-manage.conf` |
| `SDBOOT_REMOVE_EXISTING` | `yes` | `sdboot-manage.conf` |
| `SDBOOT_REMOVE_OBSOLETE` | `yes` | `sdboot-manage.conf` |

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
| `mt7925e.disable_aspm=1` | MT7925 endpoint ASPM off — driver-level coredump mitigation |
| `nvme_core.default_ps_max_latency_us=0` | NVMe APST off — no power-state exit latency |
| `pcie_aspm.policy=performance` | force every PCIe link out of ASPM |
| `processor.max_cstate=1` | cap ACPI C-states at C1 — idle-exit latency floor |
| `quiet` | suppress boot console noise |
| `split_lock_detect=off` | no split-lock throttling penalty in games |
| `usbcore.autosuspend=-1` | USB autosuspend off globally |
| `zswap.enabled=0` | zswap off — zram is the swap path |

### Initramfs

| Key | Value |
|---|---|
| `MKINITCPIO_MODULES` | `amdgpu` |
| `MKINITCPIO_HOOKS` | `base`, `systemd`, `autodetect`, `microcode`, `modconf`, `kms`, `keyboard`, `sd-vconsole`, `block`, `filesystems`, `fsck` |
| `MKINITCPIO_COMPRESSION` | `zstd` |
| `MKINITCPIO_COMPRESSION_OPTIONS` | `-1 -T0` |

`HOOKS` order is an invariant — `systemd` must precede `sd-vconsole`, and `block` must precede `filesystems`. The script validates both before writing.

### Service Keys

These are variables defined in `ry-install.fish`, not CachyOS or upstream settings. Nothing reads a variable named `RESOLVED_DOT` or `GPU_DPM_LEVEL` — the script holds the value under that name and writes it out in whatever form the consuming component expects. Two reach their destination as-is: `COUNTRY` becomes the `COUNTRY=` line in `/etc/iw-regdomain`, and `LOGIND_IGNORE_KEYS` expands to eight `Handle*Key=ignore` lines in the logind drop-in. The rest are renamed on the way out — `RESOLVED_DOT` is written as `DNSOverTLS`, `BT_AUTO_ENABLE` as BlueZ's `AutoEnable`, `EPP_PREFERENCE` as a udev `ATTR{cpufreq/energy_performance_preference}` assignment. Edit the value here, not in the file it lands in; the next run rewrites that file from the value in the script.

**DNS resolution.** `RESOLVED_MDNS` and `RESOLVED_LLMNR` are both `no`, which turns off multicast DNS and LLMNR in systemd-resolved. `RESOLVED_DOT` is `no`, leaving DNS in plaintext — a deliberate divergence from the CachyOS DNS-over-TLS default. `RESOLVED_DNSSEC` is `no`, so responses are not validated. All four land in the resolved drop-in.

**Networking.** `NM_WIFI_BACKEND` is `wpa_supplicant`. `NM_WIFI_POWERSAVE` is `2`, which disables Wi-Fi powersave — the MT7925 handles powersave in software, and leaving it on produces latency spikes. `NM_LOG_LEVEL` is `WARN`, and `NM_DISPATCHER_LOGLEVELMAX` is `notice`, which drops info-level dispatcher lines from the journal while keeping anything more severe. `COUNTRY` is `US` and sets the wireless regulatory domain.

**Bluetooth.** `BT_AUTO_ENABLE` is `true`, so the adapter powers on at boot. `BT_FAST_CONNECTABLE` is `true` and `BT_RECONNECT_ATTEMPTS` is `3`, which together speed up reconnection to paired sinks. All three are written into the BlueZ daemon config.

**CPU and GPU.** `CPUPOWER_GOVERNOR` is `powersave`, the correct choice under `amd-pstate-epp` — the EPP hint, not the governor name, is what drives performance in that mode. `EPP_PREFERENCE` is `balance_performance` and is pinned per-CPU through a udev rule. `GPU_DPM_LEVEL` is `auto`, which leaves the gfx1151 clock floor alone rather than pinning SCLK on CPU-bound titles. `EXPECTED_SCALING_DRIVER` is `amd-pstate-epp`; it writes nothing and exists only so `--verify` can confirm the driver actually in use matches what `amd_pstate=active` should produce. Both `GPU_DPM_LEVEL` and `EPP_PREFERENCE` are checked against an accepted-value list before deployment, since each is interpolated into a udev attribute unquoted.

**Firewall and hardware.** `RY_REMOTE_PLAY_PORTS` is `false`; setting it `true` appends the Sunshine and Steam streaming ports to the nftables input chain. `BLACKLIST_AMDXDNA` is `true`, blacklisting the NPU driver — it pairs with `amd_iommu=off`, since the NPU needs the IOMMU and will not probe without it. Setting it `false` requires switching the kernel command line to `amd_iommu=on iommu=pt`, and the script refuses to deploy an inconsistent pair.

### Session Environment

| Variable | Effect |
|---|---|
| `DXVK_LOG_LEVEL=none` | DXVK logging off |
| `MANGOHUD=1` | HUD on for Vulkan titles |
| `MESA_SHADER_CACHE_MAX_SIZE=16G` | roomy Mesa shader cache |
| `POWERDEVIL_NO_DDCUTIL=1` | PowerDevil DDC/CI off — silences `org_kde_powerdevil` i2c errors |
| `PROTON_ENABLE_WAYLAND=1` | native-Wayland Proton path |
| `PROTON_FSR4_UPGRADE=1` | request the FSR4 DLL upgrade path |
| `PROTON_LOCAL_SHADER_CACHE=1` | per-prefix shader cache |
| `VKD3D_DEBUG=none` | vkd3d logging off |
| `VKD3D_SHADER_DEBUG=none` | vkd3d shader logging off |
| `WINEDEBUG=-all` | Wine debug channels off |

### Sysctl Overrides

| Key | Value | Effect |
|---|---|---|
| `kernel.nmi_watchdog` | `0` | NMI watchdog off — no per-CPU watchdog overhead |
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

## Packages

`pacman -Rns` is rdep-aware via `pactree` (from `pacman-contrib`). Phase 2 re-marks every `PKGS_ADD` package explicit after `-Syu`, so a later `-Rns` cannot orphan a dependency-installed one.

**Install** — `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `lm_sensors`, `rtkit`, `realtime-privileges`, `nftables`, `pacman-contrib`

**Remove** (`-Rns`) — the plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), then `micro`, `cachyos-micro-settings`, `cachy-update`, `kdeconnect`

**Verified present** — `vulkan-radeon`, `lib32-vulkan-radeon`

## Units

**Masked**, in declaration order — `ananicy-cpp.service`, `power-profiles-daemon.service`, `NetworkManager-wait-online.service`, `avahi-daemon.service`, `avahi-daemon.socket`, `ufw.service`, `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target`

**Enabled** — `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service`, `bluetooth.service`

Phase 4 masks before it enables.

## Tuning Notes

Non-obvious choices; several list an override to reverse.

**NTSYNC** — `--verify` reports `/dev/ntsync`: present is ok, a loaded module without the node warns, absent is informational. Proton reads it directly; opt out at the Proton level with `PROTON_NO_NTSYNC=1`, which this script neither sets nor checks.

**AMD-Vi (IOMMU)** — `amd_iommu=off` breaks the XDNA NPU, which is why the driver is blacklisted. For NPU, VFIO or SR-IOV work, switch to `amd_iommu=on iommu=pt`, set `BLACKLIST_AMDXDNA false`, and re-run.

**UMIP** — `clearcpuid=umip` disables UMIP trapping and taints the kernel. The string form is version-stable, since CPUID bit numbers shift between kernels. Drop it if there is no `umip_printk` stutter.

**IPv6** — `ipv6.disable=1` pairs with the IPv4-only ruleset. For dual-stack, drop the token, add IPv6 rules, and re-run.

**PCIe ASPM** — `pcie_aspm.policy=performance` actively disables ASPM on every link, which addresses Bluetooth reconnect and association plus NVMe latency. Plain `pcie_aspm=off` only inherits the BIOS state. The global policy governs link state, so `mt7925e.disable_aspm=1` pairs with it to disable ASPM at the endpoint driver as well — coredumps are still reported on the Wi-Fi adapter without it. Drop either token to restore the corresponding default.

**FSR4 on RDNA3** — `PROTON_FSR4_UPGRADE=1` ships enabled for RDNA3 and 3.5. Recent Proton-CachyOS builds copy the FSR4 DLL automatically, so the variable now mainly pins a specific DLL version. Verify with `printenv PROTON_FSR4_UPGRADE`.

**Avahi** — both `.service` and `.socket` are masked. They collided with resolved as a second mDNS responder, and the profile runs `MulticastDNS=no`. Unmask both to restore.

**MangoHud `cpu_temp`** — the shipped HUD omits `cpu_temp`; the line in its place is a note, not a disabled token, so add `cpu_temp` on its own line to show CPU temperature. Leaving it off is deliberate: on Zen 5, enabling `cpu_temp` makes `cpu_power` read 0 ([MangoHud #1794](https://github.com/flightlessmango/MangoHud/issues/1794), open upstream). `cpu_power` ships active and reads correctly as long as `cpu_temp` stays off.

**Large-VRAM compute** — GTT caps usable VRAM near 62 GiB. Raise the BIOS UMA carveout, up to 96 GiB, for more, since `amdgpu.gttsize` is deprecated. Check `/sys/module/ttm/parameters/pages_limit`.

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

```nft
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

1. **Unmask units** — `sudo systemctl unmask` all 11 masked units; exact set in [Units](#units).
2. **Remove configs** — `sudo rm` the 11 system files and `rm` the 2 user files. Skip the 4 boot files; step 3 reverts them.
3. **Revert boot files and fstab** — restore `.ry.bak` over `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`, and `/etc/fstab` if present, then delete the `.ry.bak` files.
4. **Reverse packages** (optional) — `pacman -S --needed` the Remove list, `pacman -Rns` the Install list; exact sets in [Packages](#packages).
5. **Rebuild initramfs and entries** — `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. **Reboot** — `sudo systemctl reboot`.

Disable `nftables` before step 2 — its unit loads `/etc/nftables.conf` at start and fails once the ruleset is gone. Disable any other enabled unit you no longer want the same way. Boot files must be reverted before step 5, which regenerates entries from that state. A `.ry.bak` exists only if the file was present before the overwrite; for fstab, only if it was rewritten. A one-time `<path>.ry.orig` may exist for non-boot managed files — restore it instead of plain removal where you want the original back, then delete it.

## License

MIT.
