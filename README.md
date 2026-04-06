# ry-install

![Version](https://img.shields.io/badge/version-3.46.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Fish](https://img.shields.io/badge/fish-3.4%2B-orange)

Self-contained CachyOS configuration manager with profile support. Single Fish script, 15 embedded configs, no external dependencies.

**Default profile:** Beelink GTR9 Pro — AMD Ryzen AI Max+ 395 (Zen 5, Strix Halo) / Radeon 8060S (RDNA 3.5, gfx1151) / 128 GB LPDDR5x-8000

[changelog](CHANGELOG.md)

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Configuration Reference](#configuration-reference)
  - [Kernel Parameters](#kernel-parameters)
  - [Boot Loader](#boot-loader)
  - [Initramfs](#initramfs)
  - [System Services](#system-services)
  - [Network Stack](#network-stack)
  - [System Tuning](#system-tuning)
  - [Environment Variables](#environment-variables)
  - [User Configuration](#user-configuration)
  - [Packages](#packages)
  - [Masked Services](#masked-services)
- [Managed Files](#managed-files)
- [Profiles](#profiles)
- [Safety & Reliability](#safety--reliability)
  - [Exit Codes](#exit-codes)
  - [Data Directory](#data-directory)
  - [Log Format](#log-format)
- [Hardware Reference](#hardware-reference)
  - [Specifications](#specifications)
  - [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git && cd ry-install
./ry-install.fish --all        # Unattended — deploy everything
```

**Post-install:** Reboot → `--verify-static` → `--verify-runtime` → `sudo pacdiff` → test WiFi + gaming.

## Prerequisites

| Requirement | Verification | Notes |
|---|---|---|
| CachyOS (systemd-boot, ext4) | — | Base assumption |
| Fish 3.4+ | `fish --version` | CachyOS ships 4.5 |
| Kernel 6.14+ | `uname -r` | ntsync, gfx1151 fixes |
| Unrestricted sudo | `sudo -l` → `(ALL) ALL` | `--all` aborts if restricted |
| 2 GB root + 200 MB /boot free | `df -h / /boot` | Packages + initramfs |
| Network connectivity | `curl -sf --head https://archlinux.org` | Package sync |
| Current BIOS | [Beelink downloads](https://dr.bee-link.cn/) | P110+ for Strix Halo stability |
| WiFi credentials | SSID 1–32 bytes, passphrase 8–63 bytes | Interactive even with `--all` |
| paru (optional) | `command -q paru` | AUR package installation |

**Recommended pre-flight steps:**

```fish
# Review masked services — confirm desktop, not laptop
# See Masked Services section below

# Check for known issues
# https://wiki.cachyos.org  ·  https://archlinux.org/news/
```

## Usage

| Flag | Description |
|---|---|
| `-a, --all` | Unattended mode |
| `-f, --force` | Auto-yes prompts, no progress bar |
| `-V, --verbose` | Show output on terminal |
| `-n, --dry-run` | Preview without modifying system |
| `--diff [path]` | Per-file unified diff (colorized) |
| `--diff --fix` | Show diffs and re-install drifted files |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--lint` | Fish syntax, anti-pattern, and scope shadow checks |
| `--check` | Silent idempotency probe (exit 0 = clean, 3 = prereq fail, 10 = drift) |
| `--test-all` | Run all safe modes, generate NDJSON logs |
| `--install-file <path>` | Re-deploy a single managed file |
| `--completions` | Install Fish tab-completions |
| `-h, --help` | Show help |
| `-v, --version` | Show version |
| `--` | End of options |

Suppress individual lint warnings with `# lint:ignore`.

## Install Flow

Six sequential phases — boot-critical failures abort immediately:

```
Preflight → Packages → Configuration → Services → Boot → Finalize
```

| Phase | Description |
|---|---|
| **Preflight** | Validate prerequisites, acquire lock, load profile |
| **Packages** | Sync repos, install/remove packages, AUR via paru |
| **Configuration** | Deploy 15 embedded config files (atomic writes) |
| **Services** | Enable, mask, or create systemd units |
| **Boot** | Rebuild initramfs, update systemd-boot entries |
| **Finalize** | Daemon-reload, cache cleanup, NM restart, WiFi reconnect, write manifest |

## Configuration Reference

### Kernel Parameters

15 parameters written to `/etc/kernel/cmdline`:

| Parameter | Purpose |
|---|---|
| `amdgpu.cwsr_enable=0` | Disable CWSR — gfx1151 VGPR workaround (remove after ROCm 7.2+ fix) |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Bits 14, 15, 17 off (overdrive / GFXOFF / stutter) |
| `clocksource=tsc` | Force TSC clocksource (prevents HPET demotion, ~10–100× lower read latency) |
| `initcall_blacklist=simpledrm_platform_driver_init` | Prevent simpledrm conflict |
| `amd_iommu=off` | Disable IOMMU (APU unified memory — ~2–6% iGPU bandwidth gain, no VFIO/passthrough) |
| `module_blacklist=pcspkr` | Silence PC speaker beep |
| `nowatchdog` | Disable software watchdog timers |
| `nvme_core.default_ps_max_latency_us=0` | Disable NVMe power states |
| `pcie_aspm.policy=performance` | PCIe ASPM L0 always (framework intact, per-device sysfs control preserved) |
| `preempt=full` | Pin Dynamic Preempt to full (lowest scheduling latency for input/audio) |
| `quiet` | Suppress kernel boot messages |
| `split_lock_detect=off` | Disable split-lock #AC exception (gaming) |
| `threadirqs` | Force threaded IRQ handlers (lower worst-case latency, near-RT with preempt=full) |
| `usbcore.autosuspend=-1` | Disable USB autosuspend |
| `zswap.enabled=0` | Disable zswap (ZRAM handles compressed swap) |

### Boot Loader

| File | Key | Value |
|---|---|---|
| `loader.conf` | default | `@saved` |
| | timeout | `0` |
| | console-mode | `keep` |
| | editor | `no` |
| `sdboot-manage.conf` | LINUX_OPTIONS | See [Kernel Parameters](#kernel-parameters) |
| | LINUX_FALLBACK_OPTIONS | `"quiet"` |
| | DEFAULT_ENTRY | `"manual"` |
| | REMOVE_EXISTING | `"yes"` |
| | OVERWRITE_EXISTING | `"yes"` |
| | REMOVE_OBSOLETE | `"yes"` |

### Initramfs

| Setting | Value |
|---|---|
| Modules | `amdgpu`, `nvme` |
| Hooks | `base` → `systemd` → `autodetect` → `microcode` → `modconf` → `kms` → `keyboard` → `sd-vconsole` → `block` → `filesystems` → `fsck` |
| Compression | `zstd` |
| Compression Options | `-1 -T0` |

### System Services

| Unit | Description |
|---|---|
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` sysfs |

### Network Stack

| File | Setting |
|---|---|
| `resolved.conf.d` | MulticastDNS=no · LLMNR=no · DNSOverTLS=opportunistic · DNSSEC=allow-downgrade |
| `iwd/main.conf` | EnableNetworkConfiguration=false · DriverQuirks=`PowerSaveDisable=*` · NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd · wifi.powersave=2 · logging.level=WARN |

### System Tuning

| File | Setting |
|---|---|
| `logind.conf.d` | Ignore power/suspend/hibernate/reboot keys + long-press (8 keys) |
| `coredump.conf.d` | Storage=none · ProcessSizeMax=0 (disables coredump storage — Wine/Proton multi-GB dumps) |
| `drirc` | RADV unified VRAM heap on APU |
| `sysctl.d` | BBR+fq · tcp_fastopen=3 · 10 GbE buffer tuning · vm.max_map_count=max · dirty page limits · watermark tuning · security hardening (19 tunables, supplements CachyOS vendor config) |
| `/etc/fstab` | Adds `noatime,lazytime` to ext4 entries (modified in-place, not a managed file) |

### Environment Variables

| Variable | Value |
|---|---|
| `DXVK_LOG_LEVEL` | `none` |
| `ENABLE_LAYER_MESA_ANTI_LAG` | `1` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_USE_NTSYNC` | `1` |
| `RADV_EXPERIMENTAL` | `transfer_queue` |
| `VKD3D_DEBUG` | `none` |
| `VKD3D_SHADER_DEBUG` | `none` |
| `WINEDEBUG` | `-all` |

### User Configuration

| File | Purpose |
|---|---|
| `fish/conf.d/10-ssh-auth-sock.fish` | SSH socket priority: forwarded > gcr > systemd agent |
| `environment.d/10-environment.conf` | Environment variables for systemd user services |
| `systemd/user/ssh-agent.service` | Persistent `ssh-agent -D` with crash recovery |

### Packages

| Action | Count | Packages |
|---|---|---|
| **Install** | 13 | mkinitcpio-firmware, nvme-cli, iw, cachyos-gaming-meta, cachyos-gaming-applications, ntsync-common, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove** | 8 | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, ufw, octopi, micro, cachyos-micro-settings, btop |
| **AUR** | 1 | mt76-mt7925-dkms (via paru) |

### Masked Services

10 units masked — **review before running on laptops:**

| Service | Reason |
|---|---|
| `ananicy-cpp.service` | Manual tuning preferred |
| `irqbalance.service` | Conflicts with threadirqs (cache thrashing on 32T) |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `sleep.target` | Desktop — no sleep |
| `suspend.target` | Desktop — no suspend |
| `hibernate.target` | Desktop — no hibernate |
| `hybrid-sleep.target` | Desktop — no hybrid sleep |
| `suspend-then-hibernate.target` | Desktop — no suspend-then-hibernate |

## Managed Files

15 files deployed via atomic writes (tmp → chmod → mv):

| # | Scope | Path |
|---|---|---|
| 1 | System | `/boot/loader/loader.conf` |
| 2 | System | `/etc/kernel/cmdline` |
| 3 | System | `/etc/sdboot-manage.conf` |
| 4 | System | `/etc/mkinitcpio.conf` |
| 5 | System | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` |
| 6 | System | `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| 7 | System | `/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf` |
| 8 | System | `/etc/iwd/main.conf` |
| 9 | System | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` |
| 10 | System | `/etc/drirc` |
| 11 | System | `/etc/sysctl.d/99-cachyos-sysctl.conf` |
| 12 | User | `~/.config/fish/conf.d/10-ssh-auth-sock.fish` |
| 13 | User | `~/.config/environment.d/10-environment.conf` |
| 14 | User | `~/.config/systemd/user/ssh-agent.service` |
| 15 | Service | `/etc/systemd/system/cpupower-epp.service` |

## Profiles

Machine-specific configuration is defined in profile functions. External profiles are loaded from `~/.config/ry-install/profiles/<name>.fish`.

| Source | Resolution |
|---|---|
| `~/.config/ry-install/default-profile` | Persistent default (single line: profile name) |
| `gtr9_pro` | Hardcoded fallback |

External profiles define `function _ry_profile_<name>` with all required globals (25+). Legacy `profile_<name>` naming is accepted with a deprecation warning. Profiles are syntax-checked before sourcing; validation enforces name consistency and numeric types.

**Creating a profile:**

```fish
echo my_desktop > ~/.config/ry-install/default-profile
```

Save as `~/.config/ry-install/profiles/my_desktop.fish`:

```fish
function _ry_profile_my_desktop --description "Example desktop profile"
    set -g PROFILE_NAME my_desktop
    set -g PROFILE_DESC "My Desktop — AMD Ryzen 7 7800X3D / RX 7900 XTX"

    # Copy SYSTEM_DESTINATIONS, USER_DESTINATIONS, SERVICE_DESTINATIONS
    # from the built-in gtr9_pro profile and adjust paths as needed.

    # Required globals (--dry-run reports missing ones):
    # KERNEL_PARAMS MKINITCPIO_MODULES MKINITCPIO_HOOKS MKINITCPIO_COMPRESSION
    # LOADER_DEFAULT LOADER_TIMEOUT LOADER_CONSOLE_MODE LOADER_EDITOR
    # SDBOOT_OVERWRITE SDBOOT_REMOVE_EXISTING SDBOOT_REMOVE_OBSOLETE
    # RESOLVED_MDNS LOGIND_IGNORE_KEYS ENV_VARS PKGS_ADD MASK
    # EXPECTED_SERVICES SYSCTL_VALUES IWD_ENABLE_NETWORK_CONFIG
    # IWD_DRIVER_QUIRKS IWD_DNS_SERVICE NM_WIFI_BACKEND NM_WIFI_POWERSAVE
    # NM_LOG_LEVEL BOOT_SPACE_CRIT BOOT_SPACE_WARN ROOT_AVAIL_CRIT
    # ROOT_AVAIL_WARN
    # Optional: PKGS_DEL BOOT_TIME_TARGET EXPECTED_CPU_MATCH
end
```

Validate before first use:

```fish
./ry-install.fish --dry-run --all    # preview with new profile
./ry-install.fish --diff             # compare against installed state
```

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → chmod → mv (same filesystem) |
| Root detection | Forces `--dry-run` when invoked as root |
| Instance lock | Atomic mkdir, PID verification, stale reclaim |
| Credentials | WiFi: `read -s`, 0600 permissions, erased on exit, redacted in logs |
| Signal handling | INT/TERM/HUP/QUIT → 128+signum; SIGPIPE → 141 |
| Logging | NDJSON to `~/ry-install/logs/YYYY-MM-DD/*.jsonl` |
| Boot safety | Abort on initramfs or bootloader rebuild failure |
| LVM-aware | Skips lvm2-monitor mask when LVM detected |
| Orphan tracking | Manifest warns on version or profile change |

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Non-critical failure |
| `2` | Usage error |
| `3` | Preflight failed (also `--check` prereq failure) |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | Drift (`--check`) |
| `11` | Lint errors |
| `129/130/131/143` | Signal (HUP / INT / QUIT / TERM) |
| `141` | SIGPIPE |

> `--diff` and `--verify-*` return exit 1 on differences — expected for scripting.

### Data Directory

| Path | Contents |
|---|---|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON logs (`*.jsonl`) |
| `~/ry-install/.lock/` | Instance guard |
| `~/ry-install/.manifest` | Orphan tracking |

### Log Format

Every mode writes structured NDJSON. Each line is a self-contained JSON object with a `ts` (ISO 8601) field.

| Event | Key Fields | Emitted |
|---|---|---|
| `header` | version, profile, mode, dry_run, all, verbose, command | Run start |
| `footer` | exit_code, pass, fail, warn, interrupted | Run end |
| `ok` | data | Verification pass |
| `fail` | data | Verification failure |
| `warn` | data | Non-fatal issue |
| `err` | data | Blocking error |
| `step_time` | data, elapsed_s | Install step completed |
| `run` | data | Command executed |
| `stderr` | data | Captured stderr |
| `section` | data | Phase boundary |
| `diff` | data | File drift detected |

Query with jq: `jq 'select(.event == "fail")' ~/ry-install/logs/**/*.jsonl`

## Hardware Reference

### Specifications

| Component | Detail |
|---|---|
| BIOS | P110 (Dec 2025 — ACPI fix) |
| CPU | Ryzen AI Max+ 395 — Zen 5, 16C/32T, 5.1 GHz, 55 W default TDP (cTDP 45–120 W, Beelink: 140 W) |
| GPU | Radeon 8060S — RDNA 3.5, gfx1151, 40 CUs |
| RAM | 128 GB LPDDR5x-8000 |
| WiFi | MediaTek MT7925 (WiFi 7) |
| NIC | Dual Realtek RTL8127 10 GbE (board v2.2) |
| Thermals | 85 °C sustained · 95 °C throttle · 100 °C max |

Check [Beelink](https://dr.bee-link.cn/) for BIOS updates, [kernel bugzilla](https://bugzilla.kernel.org) / [Mesa GitLab](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) for gfx1151 issues.

### Known Issues

#### Strix Halo GPU (gfx1151)

| Issue | Status | Workaround |
|---|---|---|
| CWSR hang — incorrect VGPR count (`cf326449637a5`), compute-only | ROCm 7.2+ userspace + kernel patches (6.14/6.17 OEM) | `amdgpu.cwsr_enable=0` (pre-fix) |
| MES page faults | FW 0x83 affected | Avoid `linux-firmware-20251125`; pin if needed |
| ROCm VRAM allocation | Fixed in kernel 6.16+ | GTT handled automatically — no `ttm.pages_limit` or `amdgpu.gttsize` needed |
| PSR freeze (eDP only) | Open | `amdgpu.dcdebugmask=0x10` (not needed for HDMI/DP) |
| Black screen | Kernel 6.19.0 regression | Downgrade to 6.18.x or upgrade to 6.19.1+ |
| ROCm compute | Requires env vars | `HSA_ENABLE_SDMA=0` and `HSA_OVERRIDE_GFX_VERSION=11.5.1` |

#### MediaTek MT7925 WiFi

| Issue | Status | Workaround |
|---|---|---|
| Kernel panics (NULL deref in `mt792x_mac_reset_work`) | Driver bug | `paru -S mt76-mt7925-dkms` |
| TX power reported as 3 dBm | Cosmetic — actual TX follows regulatory limits; kernel patches pending | Consider Intel AX210/AX211 if signal issues persist |
| Random deauthentication | Intermittent | None — consider Intel AX210/AX211 |

#### NetworkManager + iwd

| Issue | Workaround |
|---|---|
| Boot connectivity failure | `nmcli radio wifi off && nmcli radio wifi on` |
| WPA2/3 Enterprise GUI broken with iwd | Use CLI or switch to wpa_supplicant |
| Monitor mode requires full reboot | Reboot |

## Troubleshooting

| Problem | Diagnostic |
|---|---|
| GPU perf level stuck | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend mismatch | `nmcli -t -f TYPE,FILENAME connection show --active` |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` |
| FSR4 on RDNA 3.5 | Per-game: `PROTON_FSR4_RDNA3_UPGRADE=1 %command%` (proton-cachyos / GE-Proton 10-9+) |

## References

| Resource | Topic |
|---|---|
| [NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) | NetworkManager with iwd backend |
| [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) | MediaTek WiFi 7 driver info |
| [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) | Mesa GPU tracker |
| [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) | AMDGPU feature mask reference |
| [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) | ROCm containers + benchmarks |
| [Ollama gfx1151](https://github.com/ollama/ollama/issues/14855) | LLM setup for Strix Halo |


## License

MIT
