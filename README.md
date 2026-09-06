# ry-install

**Version 7.199.0** · [Changelog](CHANGELOG.md)

Deploys and converges a tuned CachyOS configuration on the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). `ry-install.fish` renders 17 [Managed Files](#managed-files) from embedded generators, installs and removes `pacman` packages, masks and enables systemd units, and rewrites the fstab — one unattended run, idempotent on every pass, with `--install-file <path>` for single-file repair. Verification ships separately as [ry-verify](https://github.com/ryanmusante/ry-verify).

## Quick Start

> [!WARNING]
> Run as your normal user — never run the script itself with `sudo`. Meet [Requirements](#requirements) first. The unattended run **removes packages** ([Packages](#packages)). Reboot, then verify with [ry-verify](https://github.com/ryanmusante/ry-verify).

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
sudo -v
./ry-install.fish
```

A run closes with the Totals line and a verdict: `PASS` or `PASS-WITH-WARNINGS` on exit `0`, otherwise `PREFLIGHT`, `FAIL`, or `FAIL-BOOT-CRITICAL` — see [Exit Codes](#exit-codes).

## Requirements

`ry-install.fish` gates the tools below at preflight.

| Requirement | Detail |
|---|---|
| OS | CachyOS (Arch-based), systemd 250 or newer, systemd-boot with BLS entries |
| Shell | fish 3.6 or newer |
| Hardware | CPU matching `Ryzen AI Max` — bypass via [Environment Overrides](#environment-overrides) |
| BIOS | flat 85 W ceiling, `TjMax = 90 °C` — see [BIOS](#bios) |
| Privileges | normal user with sudo rights; `sudo -v` cached before the run |
| Tools | GNU coreutils, `findmnt`, `awk`, `grep`, `find`, `cmp`, `curl`, `pacman`, `mkinitcpio`, `sdboot-manage`, `systemctl` |

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade; a cascade failure exits `4` — **do not reboot** until it succeeds.

The bare invocation is the unattended install, all 6 phases; `--install-file <path>` re-deploys one managed file. `--verify` and `--check` belong to [ry-verify](https://github.com/ryanmusante/ry-verify) and are unknown options here, exit `2`. Positional arguments exit `2`. `--help` (`-h`) and `--version` (`-v`) are the only stdout output — every result goes to stderr.

Each run writes one JSONL log (`0600`) to `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`.

Per-phase verdicts:

- `PASS` — completed its work.
- `WARN` — hits something non-fatal and keeps exit `0`.
- `FAIL` — did not complete.
- `DEFER` — applies at next boot.
- `SKIP` — preconditions absent; the phase did not run.
- `--` — not applicable, tallied as `N/A` in Totals.

## Exit Codes

`ry-install.fish` exits `0 1 2 3 4 5`.

| Code | Meaning |
|---|---|
| `0` | OK — success and `WARN`-only runs |
| `1` | a failed install step |
| `2` | bad arguments, a non-absolute or unmanaged `--install-file`, root misuse |
| `3` | missing dependency, uncached sudo, gate mismatch |
| `4` | boot-critical — boot cascade or post-rebuild sanity failed; **do not reboot**, resolve first |
| `5` | lock — another instance holds the lock; ambiguous pidfiles fail closed |

## Environment Overrides

Skipping the hardware check is the risky override — a wrong-CPU deploy writes an incorrect kernel cmdline and initramfs `MODULES`.

| Variable | Effect |
|---|---|
| `RY_RUN_TIMEOUT=<sec>` | per-command wall-clock cap; default `3600`, `0` disables, package/boot ops floor `7200` |
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | bypass the `EXPECTED_CPU_MATCH` hard-fail |
| `NO_COLOR` | disable colored output when set to a non-empty value ([no-color.org](https://no-color.org)) |

## Managed Files

In deploy order; system files land `0644`, user files `0600`.

### Boot

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot: `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| `/etc/kernel/cmdline` | `rw root=UUID=<detected>` plus the 14 kernel tokens |
| `/etc/sdboot-manage.conf` | `LINUX_OPTIONS` mirror, `LINUX_FALLBACK_OPTIONS="quiet"`, entry management keys |
| `/etc/mkinitcpio.conf` | `MODULES` (`amdgpu`, early KMS), `HOOKS`, `COMPRESSION` `zstd` (`-3`) |

### System

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | mDNS and LLMNR off |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | 8 power, suspend, hibernate, and reboot keys ignored, long-press included |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | `LogLevelMax=notice` |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `wpa_supplicant` backend, Wi-Fi powersave off, unlimited autoconnect retries, log `WARN` |
| `/etc/iw-regdomain` | regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | auto-power-on, `FastConnectable`, 3 reconnect attempts |
| `/etc/nftables.conf` | default-deny-inbound, IPv4 ping allowed, ICMPv6 base accept |
| `/etc/default/cpupower-service.conf` | governor (`performance`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | `fq` qdisc, TCP `bbr`, VM tunables |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, P-State EPP, GPU DPM level `high` |
| `/etc/modprobe.d/60-ry-modules.conf` | optional `amdxdna` blacklist — comment-only while `BLACKLIST_AMDXDNA=false` |

### User

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | session env — DXVK, GTK, MangoHud, Mesa, Proton, VKD3D, Wine, PowerDevil |
| `~/.config/MangoHud/MangoHud.conf` | readout-only HUD — horizontal, top-left, toggle `Shift_R+F12` |

## Install Flow

Phase 4 masks `ufw.service` rather than removing the package, and withholds the mask for the run unless the nftables ruleset is confirmed live and default-deny first.

| Phase | Name | Work |
|---|---|---|
| 1 | Preflight | sudo cache, dependency, systemd, disk, network, and time-sync gates; config validation |
| 2 | Packages | seed `mkinitcpio.conf`, `pacman -Syu`, install `PKGS_ADD` (re-marked explicit), refresh `updatedb`/`pkgfile` |
| 3 | Configuration | deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved restart → package removal → mask → enable → regulatory domain |
| 5 | Boot | `mkinitcpio -P`, `sdboot-manage gen`, `sdboot-manage update`, boot sanity |
| 6 | Finalize | user `daemon-reload` + PowerDevil re-apply, `paccache -rk2`/`-ruk0`, NetworkManager restart |

## Safety and Reliability

**Atomic writes** — every managed file is rendered to a temp file on the same filesystem, pre-validated where a validator exists (`nft -c`), then moved with `mv -T`; a post-write mismatch restores the backup.

**Backups** — `.ry.bak` copies for the 4 boot files and the fstab rewrite land in `~/ry-install/backups/` under slash-encoded names (`/etc/fstab` → `_etc_fstab.ry.bak`).

**fstab rewrite** — ext4 rows get `noatime,lazytime,commit=10` in column 4, replacing redundant `defaults`, `*atime` tokens, and any existing `commit=`; every other row is byte-preserved. A power loss can discard up to 10 s of metadata.

**Failure and concurrency** — boot-critical failures exit `4` and skip finalization. One `ry-install.fish` runs at a time; a second exits `5`.

## Embedded Values

> [!CAUTION]
> `ry-install.fish` and `ry-verify.fish` carry their shared tunables verbatim and ship at the same version. Clone both repos at the same version. A version mismatch leaves `ry-verify.fish` checking values `ry-install.fish` no longer deploys.

All tunables are `set -g` globals rendered straight into the managed files at deploy — there is no external config file to edit afterward. Every key below is carried verbatim by [ry-verify](https://github.com/ryanmusante/ry-verify) at the same version; edit both repos in lockstep, then re-run or `--install-file` the affected file.

### Bootloader Keys

| Key | Value | Emitted as | File |
|---|---|---|---|
| `LOADER_DEFAULT` | `@saved` | `default` | `loader.conf` |
| `LOADER_TIMEOUT` | `0` | `timeout` | `loader.conf` |
| `LOADER_CONSOLE_MODE` | `keep` | `console-mode` | `loader.conf` |
| `LOADER_EDITOR` | `no` | `editor` | `loader.conf` |
| `SDBOOT_DEFAULT_ENTRY` | `manual` | `DEFAULT_ENTRY=` | `sdboot-manage.conf` |
| `SDBOOT_OVERWRITE` | `yes` | `OVERWRITE_EXISTING=` | `sdboot-manage.conf` |
| `SDBOOT_REMOVE_EXISTING` | `yes` | `REMOVE_EXISTING=` | `sdboot-manage.conf` |
| `SDBOOT_REMOVE_OBSOLETE` | `yes` | `REMOVE_OBSOLETE=` | `sdboot-manage.conf` |

### Kernel Parameters

| Token | Effect |
|---|---|
| `amd_pstate=active` | CPPC autonomous mode — the `amd-pstate-epp` scaling driver |
| `btusb.enable_autosuspend=n` | keep the BT controller powered — no reconnect stalls |
| `fsck.mode=force` | full fsck on every boot, not only when the filesystem asks |
| `fsck.repair=yes` | auto-repair whatever fsck finds |
| `iommu=pt` | passthrough default domain — low DMA overhead |
| `ipv6.disable=1` | disable the IPv6 stack |
| `mt7925e.disable_aspm=1` | MT7925 endpoint ASPM off — driver-level coredump mitigation |
| `nvme_core.default_ps_max_latency_us=0` | NVMe APST off — no power-state exit latency |
| `pcie_aspm.policy=performance` | bias every PCIe link away from ASPM |
| `processor.max_cstate=1` | cap ACPI C-states at C1 — idle-exit latency floor |
| `quiet` | suppress boot console noise |
| `split_lock_detect=off` | no split-lock throttling penalty in games |
| `ttm.pages_limit=20971520` | TTM page cap in 4 KiB pages — raises the GTT ceiling `amdgpu` may size; the supported successor of the deprecated `amdgpu.gttsize` |
| `usbcore.autosuspend=-1` | USB autosuspend off globally |
| `zswap.enabled=0` | zswap off from early boot — zram is the swap path, and the vendor `30-zram.rules` disables zswap again once `zram0` initializes |

### Initramfs

`HOOKS` order is an invariant, enforced when the profile is deployed: `base` first, `fsck` last, no duplicates, and `systemd` before `autodetect`, `keyboard`, and `sd-vconsole`; `autodetect` before `microcode` and `modconf`; `keyboard` before `sd-vconsole`; `modconf` before `kms`; `block` before `filesystems`.

| Key | Value | Emitted as |
|---|---|---|
| `MKINITCPIO_MODULES` | `amdgpu` | `MODULES=()` |
| `MKINITCPIO_HOOKS` | `base`, `systemd`, `autodetect`, `microcode`, `modconf`, `kms`, `keyboard`, `sd-vconsole`, `block`, `filesystems`, `fsck` | `HOOKS=()` |
| `MKINITCPIO_COMPRESSION` | `zstd` | `COMPRESSION=` |
| `MKINITCPIO_COMPRESSION_OPTIONS` | `-3` | `COMPRESSION_OPTIONS=()` |

### Service Keys

`DNSOverTLS=` and `DNSSEC=` are left unset by design — the router does DoT upstream and validates DNSSEC. The router serves DoT WAN-side only, so a host `DNSOverTLS=yes` would fail closed.

`NM_WIFI_POWERSAVE` is `2` because the MT7925 handles powersave in software and spikes latency otherwise. `BLACKLIST_AMDXDNA` is `false` because the IOMMU is on; [Tuning Notes](#tuning-notes) has the reverse switch.

| Key | Value | Emitted as |
|---|---|---|
| `RESOLVED_MDNS` | `no` | `MulticastDNS=` |
| `RESOLVED_LLMNR` | `no` | `LLMNR=` |
| `NM_DISPATCHER_LOGLEVELMAX` | `notice` | `LogLevelMax=` |
| `COUNTRY` | `US` | `COUNTRY=` |
| `LOGIND_IGNORE_KEYS` | 8 power, suspend, hibernate, and reboot keys | `Handle*Key=ignore` |
| `NM_WIFI_BACKEND` | `wpa_supplicant` | `wifi.backend=` |
| `NM_WIFI_POWERSAVE` | `2` (disabled) | `wifi.powersave=` |
| `NM_LOG_LEVEL` | `WARN` | `level=` |
| `CPUPOWER_GOVERNOR` | `performance` | `GOVERNOR=` |
| `BT_AUTO_ENABLE` | `true` | `AutoEnable=` |
| `BT_FAST_CONNECTABLE` | `true` | `FastConnectable=` |
| `BT_RECONNECT_ATTEMPTS` | `3` | `ReconnectAttempts=` |
| `GPU_DPM_LEVEL` | `high` | udev `ATTR{device/power_dpm_force_performance_level}` |
| `EPP_PREFERENCE` | `performance` | udev `ATTR{cpufreq/energy_performance_preference}` |
| `BLACKLIST_AMDXDNA` | `false` | nothing — `true` emits `blacklist amdxdna` |

### Session Environment

| Variable | Effect |
|---|---|
| `DXVK_LOG_LEVEL=none` | DXVK logging off |
| `GSK_RENDERER=gl` | GTK4 GL renderer; the Vulkan renderer aborts on gfx1151 |
| `MANGOHUD=1` | HUD on for Vulkan titles |
| `MESA_SHADER_CACHE_MAX_SIZE=16G` | roomy Mesa shader cache |
| `POWERDEVIL_NO_DDCUTIL=1` | PowerDevil DDC/CI off — silences `org_kde_powerdevil` i2c errors |
| `PROTON_LOCAL_SHADER_CACHE=1` | per-prefix shader cache |
| `VKD3D_DEBUG=none` | vkd3d logging off |
| `VKD3D_SHADER_DEBUG=none` | vkd3d shader logging off |
| `WINEDEBUG=-all` | Wine debug channels off |

### Sysctl Overrides

Ships at priority `95`, after the vendor `70-cachyos-settings.conf`. `vm.max_map_count` carries the SteamOS value; Arch already defaults to `1048576`, which covers current titles, and the larger value can confuse older programs reading core dumps. `vm.page-cluster` is left to the vendor file, which sets `0`.

| Key | Value | Effect |
|---|---|---|
| `kernel.nmi_watchdog` | `0` | NMI watchdog off |
| `net.core.default_qdisc` | `fq` | pairs with BBR |
| `net.ipv4.tcp_congestion_control` | `bbr` | BBR congestion control |
| `net.ipv4.tcp_notsent_lowat` | `16384` | cap unsent buffer at 16 KiB |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | keep the congestion window across idle |
| `vm.compaction_proactiveness` | `0` | proactive compaction off |
| `vm.max_map_count` | `2147483642` | map headroom for games (SteamOS value) |
| `vm.watermark_boost_factor` | `0` | watermark boosting off |
| `vm.watermark_scale_factor` | `125` | wider reclaim band for zram swap |

## Packages

**Install** (`PKGS_ADD`, 19) — `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `cachyos-benchmarker`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `lm_sensors`, `rtkit`, `realtime-privileges`, `nftables`, `pacman-contrib`, `dmemcg-booster`, `plasma-foreground-booster`.

**Remove** (`PKGS_DEL`, 9) — `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`, `micro`, `cachyos-micro-settings`, `cachy-update`, `kdeconnect`.

## Units

**Masked** (`MASK`, 11) — `ananicy-cpp.service`, `power-profiles-daemon.service`, `NetworkManager-wait-online.service`, `avahi-daemon.service`, `avahi-daemon.socket`, `ufw.service`, `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target`.

**Enabled** (`EXPECTED_SERVICES`, 6) — `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service`, `bluetooth.service`, `dmemcg-booster-system.service`.

## Tuning Notes

### Gaming Stack

- `/dev/ntsync` — Proton reads it directly; `PROTON_NO_NTSYNC=1` opts out at the Proton level.
- `PROTON_FSR4_UPGRADE=1` — the Proton-CachyOS lever that upgrades FSR 3.1 titles to FSR 4, per title in the Steam launch options rather than session-wide, since the DLL lands in the prefix; a version can be pinned as `PROTON_FSR4_UPGRADE=4.0.1`. `PROTON_FSR4_INDICATOR=1` only draws the watermark (`FSR_WATERMARK=1` plus `FSR_FG_WATERMARK=1`) and is no longer shipped.
- `cpu_stats` ships enabled; `cpu_temp` stays commented out — add it on its own line to turn it on. `cpu_custom_temp_sensor` is inert: MangoHud reads `apu_cpu_temp` from `gpu_metrics` first. Zen 5 `cpu_power` is open upstream ([MangoHud #1794](https://github.com/flightlessmango/MangoHud/issues/1794)).
- `game-performance` — the CachyOS wrapper needs `power-profiles-daemon`, whose service this profile masks, and the governor is already pinned to `performance`, so the wrapper is redundant here and fails when the daemon is absent.

### Kernel Parameter Notes

- `iommu=pt` — IOMMU on for the XDNA NPU, VFIO and SR-IOV; to shed the last DMA-mapping overhead on a box using none of them, add `amd_iommu=off`, set `BLACKLIST_AMDXDNA true`, and re-run.
- `ipv6.disable=1` — the ruleset carries the ICMPv6 base accept, so the fallback entry still gets working NDP; for dual-stack, drop the token, add any service-specific IPv6 rules, and re-run.
- `pcie_aspm.policy=performance` — addresses Bluetooth reconnect and NVMe latency; plain `pcie_aspm=off` only inherits the BIOS state.
- `mt7925e.disable_aspm=1` — pairs with `pcie_aspm.policy=performance` at the endpoint driver; coredumps are still reported on the Wi-Fi adapter without it. Drop either token to restore the default.
- `LINUX_FALLBACK_OPTIONS="quiet"` — the fallback entry carries none of the managed kernel parameters, so it boots with the IOMMU on, IPv6 enabled, and firmware-default ASPM.
- `timeout 0` with `default @saved` — with no saved entry (fresh ESP), sd-boot picks by its own sort order and can boot the fallback unseen; hold a key at power-on and select the tuned entry once.

## BIOS

Multi-thread gains flatten past ~85 W. Set a flat `SPL = fPPT = sPPT = 85 W` ceiling (stock boosts to 140 W) with `STAPM Boost = 0` and `TjMax = 90 °C`, under `Advanced → SMU Common Options`; full per-setting walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference).

## Troubleshooting

**Boot failure** — live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update`.

**PipeWire permission denied** — `sudo usermod -aG realtime $USER` and re-login, which needs `realtime-privileges`.

**Bluetooth speaker will not auto-reconnect** — `bluetoothctl trust <MAC>`, then power the speaker on after login.

**libvirt and QEMU NAT** — `forward { policy drop; }` breaks libvirt/QEMU NAT guest WAN access. VMs are out of scope; if you run them, do **not** duplicate NAT (libvirt's `guest_nat` already masquerades `192.168.122.0/24`).

## Uninstall

There is no automated uninstaller. Use [Managed Files](#managed-files) as the rollback reference; the steps are ordered.

1. **Unmask units** — `sudo systemctl unmask` all 11, listed in [Units](#units). Unmask the Avahi pair to restore mDNS.
2. **Remove configs** — `sudo systemctl disable --now nftables` first; its unit loads `/etc/nftables.conf` and fails once the ruleset is gone. Then `sudo rm` the 11 system files and `rm` the 2 user files; step 3 reverts the 4 boot files.
3. **Revert boot files and fstab** — restore the matching `~/ry-install/backups/*.ry.bak` copy over `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`, `/etc/fstab` where present, then delete the backups; older deployments keep the copies beside each file instead.
4. **Reverse packages** — optional: `sudo pacman -S --needed` the Remove list, `sudo pacman -Rns` the Install list; both listed in [Packages](#packages).
5. **Rebuild from the reverted files, then reboot** — `sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update`, then `sudo systemctl reboot`.

## Contributing

Questions and bug reports: [GitHub issues](https://github.com/ryanmusante/ry-install/issues). Single-host scope — open an issue before a PR.

## License

MIT — see [LICENSE](LICENSE).
