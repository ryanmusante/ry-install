# ry-install

**Version 7.162.1** · [Changelog](CHANGELOG.md)

Idempotent CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One fish script covering 17 [Managed Files](#managed-files), `pacman` add/remove, systemd units, and the fstab rewrite.

## Quick Start

> [!WARNING]
> Run as your normal user — never run the script itself with `sudo`. Meet [Requirements](#requirements) first. The unattended run **removes packages** ([Packages](#packages)). Reboot, then `--verify`.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
sudo -v
./ry-install.fish
```

A run closes with the Totals line and a verdict: `PASS` or `PASS-WITH-WARNINGS` on exit `0`, otherwise `PREFLIGHT`, `FAIL`, or `FAIL-BOOT-CRITICAL` — see [Exit Codes](#exit-codes).

## Requirements

| Requirement | Detail |
|---|---|
| OS | CachyOS (Arch-based), systemd 250 or newer, systemd-boot with BLS entries |
| Shell | fish 3.6 or newer |
| Hardware | CPU matching `Ryzen AI Max` — bypass via [Environment Overrides](#environment-overrides) |
| BIOS | flat 85 W ceiling, `TjMax = 90 °C` — see [BIOS](#bios) |
| Privileges | normal user with sudo rights; `sudo -v` cached before the run |
| Tools | GNU coreutils, `pacman`, `mkinitcpio`, `sdboot-manage`, `systemctl` |

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` and `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits `4` — **do not reboot** until it succeeds.

`--verify`, `--check`, and `--install-file <path>` are mutually exclusive. The bare invocation is the unattended install, all 6 phases; `--install-file` re-deploys one managed file. Positional arguments exit `2`. `--help` (`-h`) and `--version` (`-v`) are the only stdout output — every result goes to stderr.

Each run writes one JSONL log (`0600`) to `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`. A fresh install's `--check` reports drift until reboot.

Per-phase verdicts:

- `PASS` — completed its work.
- `WARN` — hits something non-fatal and keeps exit `0`.
- `FAIL` — did not complete.
- `DEFER` — applies at next boot, as with the NetworkManager restart over Wi-Fi.
- `SKIP` — found preconditions absent, so the phase did not run.
- `--` — not applicable, tallied as `N/A` in Totals.

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | OK — success, `WARN`-only runs, and a clean `--check` |
| `1` | verify-FAIL or install-error — a `--verify` mismatch or a failed install step |
| `2` | usage — bad arguments, a non-absolute or unmanaged `--install-file`, root-guard misuse |
| `3` | preflight — missing or non-GNU dependency, uncached sudo, gate mismatch, root with `--check` (silent) |
| `4` | boot-critical — boot cascade or post-rebuild sanity failed; **do not reboot**, resolve first |
| `5` | lock — another instance holds the lock, and ambiguous pidfiles fail closed |
| `10` | drift — `--check` found drift from the managed baseline |

## Environment Overrides

Skipping the hardware check is the risky override: deploying gfx1151 defaults on a non-matching CPU writes an incorrect kernel cmdline and initramfs `MODULES`.

| Variable | Effect |
|---|---|
| `RY_RUN_TIMEOUT=<sec>` | per-command wall-clock cap — default `3600`, `0` disables, package and boot ops floor at `7200` |
| `RY_INSTALL_SKIP_HARDWARE_CHECK=1` | bypass the `EXPECTED_CPU_MATCH` hard-fail |
| `NO_COLOR` | disable colored output when set to a non-empty value ([no-color.org](https://no-color.org)) |

## Managed Files

In deploy order; system files land `0644`, user files `0600`.

### Boot

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | systemd-boot: `default @saved`, `timeout 0`, `console-mode keep`, `editor no` |
| `/etc/kernel/cmdline` | `rw root=UUID=<detected>` plus the 15 kernel tokens |
| `/etc/sdboot-manage.conf` | `LINUX_OPTIONS` mirror, `LINUX_FALLBACK_OPTIONS="quiet"`, entry management keys |
| `/etc/mkinitcpio.conf` | `MODULES` (`amdgpu`, early KMS), `HOOKS`, `COMPRESSION` `zstd` (`-3`) |

### System

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | mDNS and LLMNR off |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | 8 power, suspend, hibernate, and reboot keys ignored, long-press included |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | `LogLevelMax=notice` |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `wpa_supplicant` backend, Wi-Fi powersave off, log level `WARN` |
| `/etc/iw-regdomain` | regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | auto-power-on, `FastConnectable`, 3 reconnect attempts |
| `/etc/nftables.conf` | default-deny-inbound, IPv4 ping allowed, ICMPv6 base accept |
| `/etc/default/cpupower-service.conf` | governor (`performance`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | `fq` qdisc, TCP `bbr`, VM tunables |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe scheduler `none`, P-State EPP, GPU DPM level `high` |
| `/etc/modprobe.d/60-ry-modules.conf` | `amdxdna` blacklist |

### User

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | session env — DXVK, MangoHud, Proton, VKD3D, Wine, PowerDevil |
| `~/.config/MangoHud/MangoHud.conf` | readout-only HUD — horizontal, top-left, toggle `Shift_R+F12` |

## Install Flow

Phase 4 masks `ufw.service` rather than removing the package, and withholds the mask for the run unless the nftables ruleset is confirmed live and default-deny first.

| Phase | Name | Work |
|---|---|---|
| 1 | Preflight | dependency, network, disk, and systemd gates; hardware match; lock acquisition |
| 2 | Packages | seed `mkinitcpio.conf`, `pacman -Syu`, install `PKGS_ADD` and re-mark explicit, refresh `updatedb` and `pkgfile` |
| 3 | Configuration | deploy 17 embedded configs atomically |
| 4 | Services | fstab → resolved restart → package removal → mask → enable → regulatory domain |
| 5 | Boot | `mkinitcpio -P`, `sdboot-manage gen`, `sdboot-manage update`, boot sanity |
| 6 | Finalize | user `daemon-reload` and PowerDevil re-apply, `paccache -rk2` and `-ruk0`, NetworkManager restart |

## Safety and Reliability

**Atomic writes** — every managed file is rendered to a temp file on the same filesystem, pre-validated where a validator exists (`nft -c` for the ruleset), backed up, moved with `mv -T`, then re-read; a mismatch restores the backup.

**Backups** — `<path>.ry.bak` for the 4 boot files and the fstab rewrite; any other managed file whose content differed at first adoption gets a one-time `<path>.ry.orig`.

**fstab rewrite** — ext4 rows get `noatime,lazytime,commit=10` in column 4, replacing redundant `defaults`, `relatime`, `atime`, `strictatime`, and existing `commit=` tokens; every other row is byte-preserved. `commit=10` doubles the ext4 default of 5 seconds, so a power loss can discard up to 10 seconds of metadata.

**Failure and concurrency** — boot-critical failures exit `4` and skip finalization rather than leave a half-rebuilt ESP. One instance runs at a time, via an atomic `mkdir` lock with dead-PID reclaim; live or ambiguous PIDs fail closed.

**Verification** — `--verify` compares installed bytes to generator output by SHA256, then checks the live state: kernel cmdline, module parameters, sysctl values, unit states, fstab options, and session environment. `--check` reports drift without writing.

`--verify` also reports state the script cannot own: orphaned admin-scope masks, unmanaged `60-ry-*` drop-ins, and any `sdboot-manage.conf.d` drop-in.

## Embedded Values

All tunables are `set -g` globals in `ry-install.fish` — there is no external config file. Edit one, then re-run or `--install-file` the affected file.

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
| `amd_iommu=on` | IOMMU on — required by the XDNA NPU, VFIO and SR-IOV |
| `amd_pstate=active` | CPPC autonomous mode — the `amd-pstate-epp` scaling driver |
| `btusb.enable_autosuspend=n` | keep the BT controller powered — no reconnect stalls |
| `fsck.mode=auto` | fsck only when the filesystem asks for it |
| `fsck.repair=yes` | auto-repair whatever fsck finds |
| `iommu=pt` | passthrough default domain — host devices identity-mapped, DMA overhead stays low |
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

`HOOKS` order is an invariant, enforced at preflight: `base` first, `fsck` last, no duplicates, and `systemd` before `autodetect`, `keyboard`, and `sd-vconsole`; `autodetect` before `microcode` and `modconf`; `keyboard` before `sd-vconsole`; `modconf` before `kms`; `block` before `filesystems`.

| Key | Value | Emitted as |
|---|---|---|
| `MKINITCPIO_MODULES` | `amdgpu` | `MODULES=()` |
| `MKINITCPIO_HOOKS` | `base`, `systemd`, `autodetect`, `microcode`, `modconf`, `kms`, `keyboard`, `sd-vconsole`, `block`, `filesystems`, `fsck` | `HOOKS=()` |
| `MKINITCPIO_COMPRESSION` | `zstd` | `COMPRESSION=` |
| `MKINITCPIO_COMPRESSION_OPTIONS` | `-3` | `COMPRESSION_OPTIONS=()` |

### Service Keys

No upstream is pinned: the drop-in sets no `DNS=` line and NetworkManager declares no `[global-dns]` section, so DHCP-supplied servers arrive as per-link DNS and the router decides where queries go.

`DNSOverTLS=` and `DNSSEC=` are left unset by design — the router does DoT upstream and validates DNSSEC. It serves DoT WAN-side only, so pinning `DNSOverTLS=yes` here would fail closed against a plaintext-only LAN resolver.

`NM_WIFI_POWERSAVE` is `2` because the MT7925 handles powersave in software and spikes latency otherwise. `BLACKLIST_AMDXDNA` is `false` because the IOMMU is on; the script refuses `false` alongside `amd_iommu=off`; [Tuning Notes](#tuning-notes) has the reverse switch.

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
| `EXPECTED_SCALING_DRIVER` | `amd-pstate-epp` | nothing — verify-only |
| `BLACKLIST_AMDXDNA` | `true` | `blacklist amdxdna` |

### Session Environment

| Variable | Effect |
|---|---|
| `DXVK_LOG_LEVEL=none` | DXVK logging off |
| `FSR4_WATERMARK=1` | on-screen FSR4-active indicator |
| `MANGOHUD=1` | HUD on for Vulkan titles |
| `MESA_SHADER_CACHE_MAX_SIZE=16G` | roomy Mesa shader cache |
| `POWERDEVIL_NO_DDCUTIL=1` | PowerDevil DDC/CI off — silences `org_kde_powerdevil` i2c errors |
| `PROTON_LOCAL_SHADER_CACHE=1` | per-prefix shader cache |
| `VKD3D_DEBUG=none` | vkd3d logging off |
| `VKD3D_SHADER_DEBUG=none` | vkd3d shader logging off |
| `WINEDEBUG=-all` | Wine debug channels off |

### Sysctl Overrides

Ships at priority `95`, after the vendor `70-cachyos-settings.conf`.

| Key | Value | Effect |
|---|---|---|
| `kernel.nmi_watchdog` | `0` | NMI watchdog off |
| `net.core.default_qdisc` | `fq` | pairs with BBR |
| `net.ipv4.tcp_congestion_control` | `bbr` | BBR congestion control |
| `net.ipv4.tcp_notsent_lowat` | `16384` | cap unsent buffer at 16 KiB |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | keep the congestion window across idle |
| `vm.compaction_proactiveness` | `0` | proactive compaction off |
| `vm.max_map_count` | `2147483642` | Steam's esync requirement |
| `vm.swappiness` | `150` | push swap traffic onto zram |
| `vm.watermark_boost_factor` | `0` | watermark boosting off |

## Packages

**Install** (`PKGS_ADD`, 16) — `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `lm_sensors`, `rtkit`, `realtime-privileges`, `nftables`, `pacman-contrib`.

**Remove** (`PKGS_DEL`, 9) — `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`, `micro`, `cachyos-micro-settings`, `cachy-update`, `kdeconnect`.

## Units

**Masked** (`MASK`, 11) — `ananicy-cpp.service`, `power-profiles-daemon.service`, `NetworkManager-wait-online.service`, `avahi-daemon.service`, `avahi-daemon.socket`, `ufw.service`, `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target`.

**Enabled** (`EXPECTED_SERVICES`, 5) — `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service`, `bluetooth.service`.

## Tuning Notes

### Gaming Stack

- `/dev/ntsync` — reported by `--verify`: present passes, a loaded module without the node warns, absent is informational. Proton reads it directly; `PROTON_NO_NTSYNC=1` opts out at the Proton level.
- `FSR4_WATERMARK=1` — on-screen indicator confirming FSR4 is active; Proton-CachyOS 11.0-20260702 and later copy `amdxcffx64.dll` themselves, so no upgrade pin is needed.
- `cpu_stats` and `cpu_temp` — both shipped commented out; add either on its own line to enable. `cpu_custom_temp_sensor` is inert here: MangoHud reads `apu_cpu_temp` from `gpu_metrics` first. The Zen 5 `cpu_power` report is open upstream ([MangoHud #1794](https://github.com/flightlessmango/MangoHud/issues/1794)).

### Kernel Parameter Notes

- `amd_iommu=on iommu=pt` — IOMMU on for the XDNA NPU, VFIO and SR-IOV; to shed the last DMA-mapping overhead on a box using none of them, switch to `amd_iommu=off`, set `BLACKLIST_AMDXDNA true`, and re-run.
- `ipv6.disable=1` — the ruleset carries the ICMPv6 base accept, so the fallback entry still gets working NDP; for dual-stack, drop the token, add any service-specific IPv6 rules, and re-run.
- `pcie_aspm.policy=performance` — biases every link away from ASPM, addressing Bluetooth reconnect and NVMe latency; plain `pcie_aspm=off` only inherits the BIOS state.
- `mt7925e.disable_aspm=1` — pairs with `pcie_aspm.policy=performance` at the endpoint driver; coredumps are still reported on the Wi-Fi adapter without it. Drop either token to restore the default.
- `LINUX_FALLBACK_OPTIONS="quiet"` — the fallback entry carries none of the managed kernel parameters, so it boots with the IOMMU on, IPv6 enabled, and firmware-default ASPM; the `amdxdna` blacklist is a modprobe file, so it still applies. `--verify` skips `*-fallback.conf`.
- `timeout 0` with `default @saved` — after an ESP wipe or a fresh install no saved entry exists, so sd-boot picks by its own sort order and can boot the fallback with no menu shown; hold a key at power-on and select the tuned entry once to set `@saved`.

## BIOS

Multi-thread gains flatten past ~85 W. Set a flat `SPL = fPPT = sPPT = 85 W` ceiling (stock boosts to 140 W) with `STAPM Boost = 0` and `TjMax = 90 °C`, under `Advanced → SMU Common Options`; full per-setting walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference).

## Troubleshooting

**Boot failure** — live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update`.

**PipeWire permission denied** — `sudo usermod -aG realtime $USER` and re-login, which needs `realtime-privileges`.

**Bluetooth speaker will not auto-reconnect** — `bluetoothctl trust <MAC>`, then power the speaker on after login.

**Unmanaged 60-ry- drop-in warned** — `pacman -Qo /etc/modprobe.d/*` to confirm ownership, then `sudo rm` the files left by earlier versions.

**Masked unit not in `MASK` reported** — `sudo systemctl unmask <unit>` if an earlier `MASK` masked it; leave distro and hand-made masks alone.

**libvirt and QEMU NAT** — `forward { policy drop; }` silently breaks libvirt/QEMU NAT guest WAN access. VMs are out of scope; if you run them — do **not** duplicate NAT (libvirt's `guest_nat` already masquerades `192.168.122.0/24`).

## Uninstall

There is no automated uninstaller. Use [Managed Files](#managed-files) as the rollback reference; the steps are ordered.

A `.ry.bak` exists only if the file was present before the overwrite — for fstab, only if it was rewritten. A one-time `<path>.ry.orig` may exist for non-boot files; restore it instead of deleting.

1. **Unmask units** — `sudo systemctl unmask` all 11, listed in [Units](#units). Unmask the Avahi pair to restore mDNS: the profile runs no mDNS responder while it is masked, because the resolved drop-in also sets `MulticastDNS=no`.
2. **Remove configs** — `sudo systemctl disable --now nftables` first; its unit loads `/etc/nftables.conf` and fails once the ruleset is gone. Then `sudo rm` the 11 system files and `rm` the 2 user files; step 3 reverts the 4 boot files.
3. **Revert boot files and fstab** — restore `.ry.bak` over `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`, `/etc/fstab` where present, then delete the `.ry.bak` files.
4. **Reverse packages** — optional: `sudo pacman -S --needed` the Remove list, `sudo pacman -Rns` the Install list; both listed in [Packages](#packages).
5. **Rebuild from the reverted files, then reboot** — `sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update`, then `sudo systemctl reboot`.

## Contributing

Questions and bug reports: [GitHub issues](https://github.com/ryanmusante/ry-install/issues). Single-host scope — open an issue before a PR.

## License

MIT — see [LICENSE](LICENSE).
