# ry-install

**Version 7.139.0** · [Changelog](CHANGELOG.md)
Idempotent CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 17 embedded configs — atomic, byte-verifiable, reversible.

## Quick Start

> [!WARNING]
> Run as your normal user — never with `sudo`. The unattended run **removes packages** ([Packages](#packages)). Reboot, then `--verify`. Re-runs are idempotent.

A run closes with the Totals line — each phase's verdict tallied — then the verdict on the Elapsed line below it: `PASS` when clean, `PASS-WITH-WARNINGS` at exit `0` when warnings occurred. Anything else is explained in [Usage](#usage) and [Exit Codes](#exit-codes).

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
sudo -v
./ry-install.fish
```

## Requirements

| Requirement | Detail |
|---|---|
| OS | CachyOS (Arch-based), systemd-boot with BLS entries |
| Shell | fish 3.6 or newer |
| Hardware | CPU matching `Ryzen AI Max` — bypass via [Environment Overrides](#environment-overrides) |
| Privileges | Normal user with sudo rights; `sudo -v` cached before the run |
| Tools | GNU coreutils, `pacman`, `mkinitcpio`, `sdboot-manage`, `systemctl` |

In scope: the 17 [Managed Files](#managed-files), pacman add/remove, systemd units, and the fstab rewrite. Everything else on the system is left alone.

## BIOS

Multi-thread gains flatten past ~85 W. Set a flat `SPL = fPPT = sPPT = 85 W` ceiling (stock boosts to 140 W) with `STAPM Boost = 0` and `TjMax = 90 °C`, under `Advanced → SMU Common Options`; full per-setting walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference). Separately, GTT caps usable VRAM near 62 GiB; raise the BIOS UMA carveout (its own menu), up to 96 GiB, for more, since `amdgpu.gttsize` is deprecated — check `/sys/module/ttm/parameters/pages_limit`.

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` and `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits `4` — **do not reboot** until it succeeds. ESP autodetect (`bootctl` → `findmnt`) failure falls back to `/boot` with a warning; a non-vfat fallback then refuses sdboot (exit `4`).

`--verify`, `--check`, and `--install-file <path>` are mutually exclusive; the bare invocation is the unattended install, all six phases, and `--install-file` re-deploys one managed file. No positional arguments are accepted; `--help` and `--version` are honored before every other check and are the only stdout output — every result goes to stderr. Each run writes one JSONL log (`0600`) to `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`. A fresh install's `--check` reports drift until reboot.

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
| `RY_RUN_TIMEOUT=<sec>` | Per-command wall-clock cap. Default `3600`; `0` disables; package and boot ops floor at `7200` |
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | Bypass the `EXPECTED_CPU_MATCH` hard-fail |
| `NO_COLOR` | Disable colored output when set to a non-empty value ([no-color.org](https://no-color.org)) |

Color also auto-disables when stderr is not a TTY or `TERM` is `dumb`. Skipping the hardware check is the risky one: deploying gfx1151 defaults on a non-matching CPU writes an incorrect kernel cmdline and initramfs `MODULES`.

## Managed Files

In deploy order; system files land `0644`, user files `0600`.

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
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | AdGuard upstreams, mDNS and LLMNR off |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power, suspend, hibernate, and reboot keys — 8 keys including long-press variants |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | `LogLevelMax=notice` drops info-level dispatcher lines |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `wpa_supplicant` backend, Wi-Fi powersave off, log level `WARN`, DNS upstreams pinned |
| `/etc/iw-regdomain` | regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | adapter auto-power-on, `FastConnectable`, 3 paired-sink reconnect attempts |
| `/etc/nftables.conf` | IPv4-only default-deny-inbound, ping allowed |
| `/etc/default/cpupower-service.conf` | governor (`performance`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | `fq` qdisc, netdev budget, TCP `bbr`, VM tunables |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none` (vendor `kyber`), P-State EPP, GPU DPM level `high` |
| `/etc/modprobe.d/60-ry-modules.conf` | `amdxdna` blacklist — unmanaged `60-ry-*` drop-ins are warned by `--verify` and recorded by `--check` |

### User

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | session env — DXVK, MangoHud, Proton, VKD3D, Wine, plus `POWERDEVIL_NO_DDCUTIL=1` |
| `~/.config/MangoHud/MangoHud.conf` | readout-only HUD — horizontal, top-left, toggle `Shift_R+F12` |

## Install Flow

| Phase | Name | Work |
|---|---|---|
| 1 | Preflight | Dependency, network, disk, and systemd gates; hardware match; lock acquisition |
| 2 | Packages | Seed `mkinitcpio.conf`, `pacman -Syu`, install `PKGS_ADD` and re-mark explicit, refresh `updatedb` and `pkgfile` |
| 3 | Configuration | Deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved restart → package removal → mask → enable → regulatory domain |
| 5 | Boot | `mkinitcpio -P`, `sdboot-manage gen`, `sdboot-manage update`, boot sanity |
| 6 | Finalize | User `daemon-reload` (PowerDevil re-apply if the env file changed), `paccache -rk2` and `-ruk0`, NetworkManager restart |

Phase 4 masks `ufw.service` rather than removing the package: the nftables ruleset is confirmed live and default-deny before the ufw flush, so there is no window without inbound protection. If the ruleset cannot be confirmed, the mask is withheld for the run. The `ufw` package stays installed.

The shipped ruleset is IPv4-only default-deny-inbound. Loopback, established and related traffic, and ICMP echo-request plus the error and PMTUD types (destination-unreachable, time-exceeded, parameter-problem) are accepted; `invalid` state is dropped; `forward` drops and `output` accepts. IPv6 is disabled system-wide via `ipv6.disable=1`.

## Safety and Reliability

> [!NOTE]
> Every managed file is written atomically: content is rendered to a temp file on the same filesystem, pre-validated where a validator exists (`nft -c` for the ruleset), backed up, moved into place with `mv -T`, then re-read and compared. A mismatch restores the backup.

Backups: `<path>.ry.bak` for the 4 boot files and the fstab rewrite; any other managed file whose content differed at first adoption gets a one-time `<path>.ry.orig`.

The fstab rewrite gives ext4 rows `noatime,lazytime,commit=10` in column 4, normalizing away redundant `defaults`, `relatime`, `atime`, `strictatime` and existing `commit=` tokens; everything else is byte-preserved. It is gated by line-count parity, a size floor and a mandatory `findmnt --verify`. A symlinked `/etc/fstab` aborts the rewrite; malformed rows are left byte-identical and warned.

Boot-critical failures exit `4` and skip finalization rather than leave a half-rebuilt ESP. One instance runs at a time, enforced by an atomic `mkdir` lock with dead-PID reclaim — live or ambiguous PIDs fail closed. `--verify` compares installed bytes to generator output by SHA256; `--check` reports drift without writing.

Edits reconcile differently by where the value landed. Generated-file values self-heal — each generator rewrites its whole file from the current array on the next run. External state does not: a package dropped from `PKGS_ADD` stays installed and a unit dropped from `MASK` stays masked; the script only adds, never unmasks. `--verify` reports orphaned admin-scope masks (vendor masks and alias cascades are filtered) and unmanaged `60-ry-*` drop-ins; `--check` records both in its JSONL. Neither counts as drift — a re-run cannot clear them; reverse by hand. Dropped `PKGS_ADD` packages are not detected at all: no record is kept of what earlier versions installed.

## Embedded Values

All tunables are `set -g` globals near the top of the script — there is no external config file. Edit one, then re-run or `--install-file` the affected file. Porting to other hardware starts at `PROFILE_NAME`, `PROFILE_DESC`, and `EXPECTED_CPU_MATCH`. Preflight refuses to deploy when the sets contradict each other — a package in both `PKGS_ADD` and `PKGS_DEL`, or a unit in both `MASK` and `EXPECTED_SERVICES`, since phase 4 would undo phase 2.

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
| `pcie_aspm.policy=performance` | bias every PCIe link away from ASPM |
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

These are variables in `ry-install.fish`, not CachyOS settings. Most are renamed on the way out, as the third column shows. Edit the value here, not the generated file; the next run overwrites it.

| Key | Value | Emitted as |
|---|---|---|
| `RESOLVED_MDNS` | `no` | `MulticastDNS=` |
| `RESOLVED_LLMNR` | `no` | `LLMNR=` |
| `RESOLVED_DOT` | `no` | `DNSOverTLS=` |
| `RESOLVED_DNSSEC` | `no` | `DNSSEC=` |
| `RESOLVED_DNS_SERVERS` | `94.140.14.14 94.140.15.15` | `DNS=` |
| `NM_DISPATCHER_LOGLEVELMAX` | `notice` | `LogLevelMax=` |
| `COUNTRY` | `US` | `COUNTRY=` |
| `LOGIND_IGNORE_KEYS` | 8 power, suspend, hibernate, and reboot keys | `Handle*Key=ignore` |
| `NM_WIFI_BACKEND` | `wpa_supplicant` | `wifi.backend=` |
| `NM_WIFI_POWERSAVE` | `2` | `wifi.powersave=` |
| `NM_LOG_LEVEL` | `WARN` | `level=` |
| `CPUPOWER_GOVERNOR` | `performance` | `GOVERNOR=` |
| `BT_AUTO_ENABLE` | `true` | `AutoEnable=` |
| `BT_FAST_CONNECTABLE` | `true` | `FastConnectable=` |
| `BT_RECONNECT_ATTEMPTS` | `3` | `ReconnectAttempts=` |
| `GPU_DPM_LEVEL` | `high` | udev `ATTR{device/power_dpm_force_performance_level}` |
| `EPP_PREFERENCE` | `performance` | udev `ATTR{cpufreq/energy_performance_preference}` |
| `EXPECTED_SCALING_DRIVER` | `amd-pstate-epp` | nothing — verify-only |
| `BLACKLIST_AMDXDNA` | `true` | `blacklist amdxdna` |

`RESOLVED_DOT` is `no` by choice, matching the router: the filtering is identical either way, and `DNSOverTLS=yes` fails closed, so an unreachable endpoint would stop resolution outright. `DNSSEC=no` is the systemd default. The same upstreams repeat in the NetworkManager drop-in under `[global-dns-domain-*]` — without that, DHCP-supplied servers arrive as per-link DNS and outrank the global `DNS=` line.

`NM_WIFI_POWERSAVE` is `2` because the MT7925 handles powersave in software and produces latency spikes otherwise. Under `amd-pstate-epp` with `CPUPOWER_GOVERNOR=performance`, the driver forces the EPP hint to its maximum and rejects any other value, so `EPP_PREFERENCE=performance` restates what the governor already imposes rather than adding to it. Both `GPU_DPM_LEVEL` and `EPP_PREFERENCE` are checked against an accepted-value list, since each is interpolated into a udev attribute unquoted.

`BLACKLIST_AMDXDNA` pairs with `amd_iommu=off` — the NPU needs the IOMMU and will not probe without it. Setting it `false` requires `amd_iommu=on iommu=pt`; the script refuses an inconsistent pair. `LOGIND_IGNORE_KEYS` holds the 8 `Handle*Key=ignore` lines and keeps its own names.

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

Ships at priority `95`, after the vendor `70-cachyos-settings.conf`.

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

**Masked**, in declaration order — `ananicy-cpp.service`, `power-profiles-daemon.service`, `NetworkManager-wait-online.service`, `avahi-daemon.service`, `avahi-daemon.socket`, `ufw.service`, `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target`. The Avahi pair is masked because it collided with resolved as a second mDNS responder; unmask both to restore.

**Enabled** — `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service`, `bluetooth.service`

## Tuning Notes

Non-obvious choices; several list an override to reverse.

**Gaming stack** — `--verify` reports `/dev/ntsync`: present passes, a loaded module without the node warns, absent is informational; Proton reads it directly, and `PROTON_NO_NTSYNC=1` opts out at the Proton level, which this script neither sets nor checks. `PROTON_FSR4_UPGRADE=1` ships enabled for RDNA3 and 3.5; recent Proton-CachyOS builds copy the DLL automatically, so it now mainly pins a version — verify with `printenv PROTON_FSR4_UPGRADE`. The shipped HUD omits `cpu_temp`; add it on its own line to show CPU temperature — leaving it off is deliberate, since on Zen 5 enabling it makes `cpu_power` read 0 ([MangoHud #1794](https://github.com/flightlessmango/MangoHud/issues/1794), open upstream).

**Kernel parameters** — `amd_iommu=off` breaks the XDNA NPU, which is why the driver is blacklisted; for NPU, VFIO or SR-IOV work, switch to `amd_iommu=on iommu=pt`, set `BLACKLIST_AMDXDNA false`, and re-run. `clearcpuid=umip` disables UMIP trapping and taints the kernel; the string form is version-stable, since CPUID bit numbers shift between kernels — drop it if there is no `umip_printk` stutter. `ipv6.disable=1` pairs with the IPv4-only ruleset; for dual-stack, drop the token, add IPv6 rules, and re-run. `pcie_aspm.policy=performance` biases every link away from ASPM, addressing Bluetooth reconnect and NVMe latency; plain `pcie_aspm=off` only inherits the BIOS state. Confirm actual link state with `lspci -vv` (`LnkCtl: ASPM Disabled`) rather than assuming it from the token. `mt7925e.disable_aspm=1` pairs with it at the endpoint driver — coredumps are still reported on the Wi-Fi adapter without it. Drop either token to restore the default.

## Troubleshooting

| Symptom | Action |
|---|---|
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update` |
| Rebuild refused | Fix the cause of the boot-state taint, then re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`, then re-run |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login — needs `realtime-privileges` |
| BT speaker will not auto-reconnect | `bluetoothctl trust <MAC>`, then power the speaker on after login |
| Unmanaged `60-ry-*` drop-in warned | `pacman -Qo /etc/modprobe.d/*` to confirm ownership, then `sudo rm` the pre-7.99 files |
| Masked unit not in `MASK` reported | `systemctl unmask <unit>` if an earlier `MASK` masked it; leave distro and hand-made masks alone |

### libvirt and QEMU NAT

`forward { policy drop; }` silently breaks libvirt/QEMU NAT guest WAN access. VMs are out of scope; if you run them, add to `/etc/nftables.conf` — do **not** duplicate NAT (libvirt's `guest_nat` already masquerades `192.168.122.0/24`):

```nft
# input - guest DHCP/DNS to the host dnsmasq:
iifname "virbr0" udp dport { 53, 67 } accept
iifname "virbr0" tcp dport { 53, 67 } accept
# forward - survive the global drop:
iifname "virbr0" accept
oifname "virbr0" ct state established,related accept
```

## Uninstall

> [!NOTE]
> There is no automated uninstaller. Use [Managed Files](#managed-files) as the rollback reference; the steps are ordered.

A `.ry.bak` exists only if the file was present before the overwrite — for fstab, only if it was rewritten. A one-time `<path>.ry.orig` may exist for non-boot files; restore that instead of deleting.

1. **Unmask units** — `sudo systemctl unmask` all 11; set in [Units](#units).
2. **Remove configs** — `sudo systemctl disable --now nftables` first, since its unit loads `/etc/nftables.conf` at start and fails once the ruleset is gone; then `sudo rm` the 11 system files and `rm` the 2 user files. Skip the 4 boot files; step 3 reverts them.
3. **Revert boot files and fstab** — restore `.ry.bak` over `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`, `/etc/fstab` where present, then delete the `.ry.bak` files.
4. **Reverse packages** (optional) — `pacman -S --needed` the Remove list, `pacman -Rns` the Install list; sets in [Packages](#packages).
5. **Rebuild from the reverted files, then reboot** — `sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update`, then `sudo systemctl reboot`.

## License

MIT — see [LICENSE](LICENSE).
