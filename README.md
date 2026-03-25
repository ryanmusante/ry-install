# ry-install

![Version](https://img.shields.io/badge/version-3.10.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Fish](https://img.shields.io/badge/fish-3.4%2B-orange)

Self-contained CachyOS configuration manager with profile support. Default profile: **Beelink GTR9 Pro** (AMD Ryzen AI Max+ 395 / Strix Halo). Single fish script, 15 embedded configs, no external dependencies.

## Hardware

| Component | Detail |
|-----------|--------|
| BIOS | P110 (Dec 2025 — ACPI fix) |
| CPU | Ryzen AI Max+ 395 — Zen 5, 16C/32T, 5.1 GHz, 55–120 W TDP |
| GPU | Radeon 8060S — RDNA 3.5, gfx1151, 40 CUs |
| RAM | 128 GB LPDDR5x-8000 |
| WiFi | MediaTek MT7925 (WiFi 7) |
| NIC | Dual Intel E610 10 GbE |
| Thermals | 85 °C sustained · 95 °C throttle · 100 °C max |

Check [Beelink](https://dr.bee-link.cn/) for BIOS, kernel bugzilla / Mesa GitLab for gfx1151 issues.

## Prerequisites

| # | Step | Command / Action | Why |
|---|------|-----------------|-----|
| 1 | **CachyOS installed** | systemd-boot, btrfs or ext4, internet | Assumes CachyOS with systemd-boot |
| 2 | **Fish 3.4+** | `fish --version` (CachyOS ships 4.5) | Required syntax features |
| 3 | **Kernel 6.14+** | `uname -r` | ntsync, gfx1151 fixes, mt7925e.disable_aspm |
| 4 | **Unrestricted sudo** | `sudo -l` → `(ALL) ALL` | `--all` aborts if restricted |
| 5 | **2 GB root free** | `df -h /` | Packages + initramfs + cache |
| 6 | **200 MB /boot free** | `df -h /boot` | Kernel images + initramfs |
| 7 | **Network** | `curl -sf --head https://archlinux.org` | Package sync |
| 8 | **BIOS current** | [Beelink](https://dr.bee-link.cn/) | P110+ for Strix Halo stability |
| 9 | **Snapshot rootfs** | `sudo btrfs subvolume snapshot -r / /.snapshots/pre-ry-install` | Rollback point (btrfs) |
| 10 | **Review masked services** | See [Masked Services](#masked-services-10) | Confirm desktop, not laptop |
| 11 | **WiFi ready** | SSID 1-32 bytes, passphrase 8-63 bytes, no `%` | Interactive even with `--all` |
| 12 | **CachyOS news** | [wiki.cachyos.org](https://wiki.cachyos.org/) / [archlinux.org/news](https://archlinux.org/news/) | Known issues before `-Syu` |

```fish
./ry-install.fish --dry-run --all   # Preview
./ry-install.fish --all             # Unattended install
```

**After install:** Reboot → `--verify-static` → `--verify-runtime` → `sudo pacdiff` → test WiFi + gaming.

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git && cd ry-install
./ry-install.fish              # Interactive install
./ry-install.fish --dry-run    # Preview changes
./ry-install.fish --help       # All options
```

## Options

| Flag | Description |
|------|-------------|
| `-a, --all` | Unattended mode |
| `-f, --force` | Auto-yes prompts, no progress bar |
| `-V, --verbose` | Show output on terminal |
| `-n, --dry-run` | Preview without modifying system |
| `--diff [path]` | Per-file unified diff (colorized) |
| `--diff --fix` | Show diffs and re-install drifted files |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--lint` | Fish syntax, anti-pattern, and scope shadow checks (`# lint:ignore` to suppress) |
| `--check` | Silent idempotency probe (exit 0=clean, 10=drift) |
| `--test-all` | Run all safe modes, generate NDJSON logs |
| `--install-file <path>` | Re-deploy a single managed file |
| `--completions` | Install fish tab-completions |
| `-h, --help` | Show help |
| `-v, --version` | Show version |
| `--` | End of options |

## Configuration

### Kernel Parameters (15)

| Parameter | Purpose |
|-----------|---------|
| `amdgpu.cwsr_enable=0` | Disable CWSR — gfx1151 hang workaround (remove on 6.18+) |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Bits 14,15,17 off (overdrive/GFXOFF/stutter) |
| `amdgpu.wbrf=0` | Disable WiFi RFI memory clock throttling (UMA bandwidth) |
| `clocksource=tsc` | Force TSC clocksource on Zen 5 |
| `initcall_blacklist=simpledrm_platform_driver_init` | Prevent simpledrm conflict |
| `iommu=pt` | IOMMU passthrough (DMA protection, near-zero overhead) |
| `module_blacklist=pcspkr,wdat_wdt` | Silence PC speaker beep, block ACPI watchdog |
| `mt7925e.disable_aspm=1` | Disable WiFi ASPM |
| `nowatchdog` | Disable software watchdog timers |
| `nvme_core.default_ps_max_latency_us=0` | Disable NVMe power states |
| `nvme_core.multipath=N` | Disable NVMe multipath on single-drive desktop |
| `quiet` | Suppress boot messages |
| `usbcore.autosuspend=-1` | Disable USB autosuspend |
| `workqueue.power_efficient=0` | Disable power-efficient workqueue remapping |
| `zswap.enabled=0` | Disable zswap (ZRAM masked separately) |

### Boot

| File | Key | Value |
|------|-----|-------|
| `loader.conf` | default | `@saved` |
| | timeout | `0` |
| | console-mode | `keep` |
| | editor | `no` |
| `sdboot-manage.conf` | LINUX_OPTIONS | See [Kernel Parameters](#kernel-parameters-15) |
| | LINUX_FALLBACK_OPTIONS | `"quiet"` |
| | DEFAULT_ENTRY | `"manual"` |
| | REMOVE_EXISTING | `"yes"` |
| | OVERWRITE_EXISTING | `"yes"` |
| | REMOVE_OBSOLETE | `"yes"` |

### mkinitcpio

| Setting | Value |
|---------|-------|
| Modules | `amdgpu`, `nvme` |
| Hooks | `base` → `systemd` → `autodetect` → `microcode` → `modconf` → `kms` → `keyboard` → `sd-vconsole` → `block` → `filesystems` → `fsck` |
| Compression | `zstd` |

### System Configuration

| File | Setting |
|------|---------|
| `udev rules` | `ntsync` MODE=0666 |
| `resolved.conf.d` | MulticastDNS=no · DNSOverTLS=opportunistic · DNSSEC=allow-downgrade |
| `logind.conf.d` | Ignore power/suspend/hibernate/reboot keys + long-press (8 keys) |
| `iwd/main.conf` | EnableNetworkConfiguration=false · DriverQuirks=`DefaultInterface=*`,`PowerSaveDisable=*` · NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd · wifi.powersave=2 · logging.level=WARN |
| `drirc` | RADV unified VRAM heap on APU |

### Environment Variables

| Variable | Value |
|----------|-------|
| `SSH_AUTH_SOCK` | `${XDG_RUNTIME_DIR}/ssh-agent.socket` |
| `DXVK_LOG_LEVEL` | `none` |
| `ENABLE_LAYER_MESA_ANTI_LAG` | `1` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `8G` |
| `PROTON_USE_NTSYNC` | `1` |
| `PROTON_NO_WM_DECORATION` | `1` |

### User Configuration

| File | Purpose |
|------|---------|
| `fish/conf.d/10-ssh-auth-sock.fish` | SSH socket priority: forwarded > gcr > systemd agent |
| `environment.d/10-environment.conf` | Environment variables for systemd user services |
| `systemd/user/ssh-agent.service` | Persistent `ssh-agent -D` with crash recovery |

### Packages

| Action | Packages |
|--------|----------|
| **Add (12)** | mkinitcpio-firmware, nvme-cli, iw, cachyos-gaming-meta, cachyos-gaming-applications, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove (8)** | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, ufw, octopi, micro, cachyos-micro-settings, btop |

### Masked Services (10)

| Service | Note |
|---------|------|
| `ananicy-cpp.service` | Masked for manual tuning |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `systemd-zram-setup@zram0.service` | 128 GB makes ZRAM overhead pointless |
| `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target` | Desktop — no sleep/suspend/hibernate |

### Services (2)

| Unit | Description |
|------|-------------|
| `amdgpu-performance.service` | Write `auto` to `power_dpm_force_performance_level` sysfs (retry loop, multi-GPU). GameMode sets `high` dynamically. |
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` sysfs |

## Embedded Files (15)

| # | Scope | Path |
|---|-------|------|
| 1 | System | `/boot/loader/loader.conf` |
| 2 | System | `/etc/kernel/cmdline` |
| 3 | System | `/etc/sdboot-manage.conf` |
| 4 | System | `/etc/mkinitcpio.conf` |
| 5 | System | `/etc/udev/rules.d/99-cachyos-udev.rules` |
| 6 | System | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` |
| 7 | System | `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| 8 | System | `/etc/iwd/main.conf` |
| 9 | System | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` |
| 10 | System | `/etc/drirc` |
| 11 | User | `~/.config/fish/conf.d/10-ssh-auth-sock.fish` |
| 12 | User | `~/.config/environment.d/10-environment.conf` |
| 13 | User | `~/.config/systemd/user/ssh-agent.service` |
| 14 | Service | `/etc/systemd/system/amdgpu-performance.service` |
| 15 | Service | `/etc/systemd/system/cpupower-epp.service` |

## Safety

| Feature | Detail |
|---------|--------|
| Atomic writes | tmp → chmod → mv (same filesystem) |
| Root detection | Forces `--dry-run` as root |
| Instance lock | Atomic mkdir, PID verification, stale reclaim |
| Credentials | WiFi: read -s, 0600, erased on exit, redacted in logs |
| Signal handling | INT/TERM/HUP/QUIT → 128+signum; SIGPIPE → 141 |
| Logging | NDJSON `~/ry-install/logs/YYYY-MM-DD/*.jsonl` |
| Boot safety | Abort on initramfs/bootloader rebuild failure |
| LVM-aware | Skip lvm2-monitor mask when LVM detected |
| Orphan tracking | Manifest warns on version/profile change |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Non-critical failure |
| `2` | Usage error |
| `3` | Preflight failed |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | Drift (`--check`) |
| `11` | Lint errors |
| `129/130/131/143` | Signal (HUP/INT/QUIT/TERM) |
| `141` | SIGPIPE |

> `--diff` and `--verify-*` return exit 1 on differences (expected for scripting).

### Install Flow (6 steps)

Preflight → Packages → Configuration → Services → Boot → Finalize

### Data Directory

| Path | Contents |
|------|----------|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON logs (*.jsonl) |
| `~/ry-install/.lock/` | Instance guard |
| `~/ry-install/.manifest` | Orphan tracking |

### Log Analysis

Every mode writes structured NDJSON to `~/ry-install/logs/`. Each line is a self-contained JSON object. Analyze with `jq`.

**Log structure:**

| Event | Fields | When |
|-------|--------|------|
| `header` | `version`, `profile`, `mode`, `dry_run`, `all`, `verbose`, `command` | Run start |
| `footer` | `exit_code`, `pass`, `fail`, `warn`, `interrupted` | Run end |
| `ok` | `data` | Verification pass |
| `fail` | `data` | Verification failure |
| `warn` | `data` | Non-fatal issue |
| `err` | `data` | Blocking error |
| `step_time` | `data`, `elapsed_s` | Install step completed |
| `run` | `data` | Command executed |
| `stderr` | `data` | Captured stderr |
| `section` | `data` | Phase boundary |
| `diff` | `data` | File drift detected |

All events include `ts` (ISO 8601 timestamp).

**Examples:**

```fish
# All errors from most recent log
jq 'select(.event == "err")' ~/ry-install/logs/**/*.jsonl | tail -20

# Failures from a specific run
jq 'select(.event == "fail")' ~/ry-install/logs/2026-03-25/install-20260325-140000+0000.jsonl

# Run summary (exit code, pass/fail/warn counts)
jq 'select(.event == "footer")' ~/ry-install/logs/**/*.jsonl

# Step timing for install runs
jq 'select(.event == "step_time") | {step: .data, seconds: .elapsed_s}' ~/ry-install/logs/**/*.jsonl

# All unique warnings across all runs
jq -r 'select(.event == "warn") | .data' ~/ry-install/logs/**/*.jsonl | sort -u

# Commands that failed (non-zero exit)
jq -r 'select(.event == "run") | .data' ~/ry-install/logs/**/*.jsonl | grep '^EXIT: [^0]'

# Interrupted runs
jq 'select(.event == "footer" and .interrupted == true)' ~/ry-install/logs/**/*.jsonl

# Drift check history
jq 'select(.event == "footer" and .mode == "check") | {ts: .ts, exit: .exit_code}' ~/ry-install/logs/**/*.jsonl

# List all runs with mode and exit code
jq -r 'select(.event == "footer") | [.ts, .mode, .exit_code] | @tsv' ~/ry-install/logs/**/*.jsonl
```

## Troubleshooting

| Problem | Command |
|---------|---------|
| GPU perf level | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend | `nmcli -t -f TYPE,FILENAME connection show --active` |
| ntsync | Kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` |

### Profiles

Machine-specific globals in profile functions. Default: `_ry_profile_gtr9_pro`. External: `~/.config/ry-install/profiles/<n>.fish`.

| Source | Resolution |
|--------|-----------|
| `~/.config/ry-install/default-profile` | Persistent default (single line: name) |
| `gtr9_pro` | Hardcoded fallback |

External profiles should define `function _ry_profile_<n>` with all required globals. Legacy `profile_<n>` naming is still accepted (with deprecation warning). Syntax-checked before sourcing. Validation enforces 25+ globals, name consistency, numeric types.

### References

| Link | Topic |
|------|-------|
| [NM iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) | NetworkManager + iwd |
| [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) | MediaTek WiFi 7 |
| [gfx1151](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) | Mesa GPU issues |
| [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) | AMDGPU feature mask |
| [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) | ROCm containers + benchmarks for gfx1151 |
| [Ollama gfx1151](https://github.com/ollama/ollama/issues/14855) | Working LLM setup for Strix Halo |

### Known Hardware Issues

#### Strix Halo (gfx1151) GPU

- **CWSR hang** (fixed 6.18+): Incorrect VGPR count (`cf326449637a5`). Compute-only. Pre-6.18: `amdgpu.cwsr_enable=0`.
- **MES page faults**: FW 0x83 may fault. Avoid `linux-firmware-20251125` (breaks ROCm). Pin if affected.
- **ROCm VRAM**: Kernel 6.16+ handles GTT automatically — no `ttm.pages_limit` or `amdgpu.gttsize` needed.
- **PSR freeze** (eDP only): Add `amdgpu.dcdebugmask=0x10`. Not needed for HDMI/DP.
- **Black screen**: Kernel 6.19.0 regression; 6.18.9 last known-good.
- **ROCm env**: `HSA_ENABLE_SDMA=0` and `HSA_OVERRIDE_GFX_VERSION=11.5.1`.

#### MediaTek MT7925 WiFi

- **Kernel panics**: NULL deref in `mt7925_mac_reset_work`. Fix: `paru -S mt76-mt7925-dkms`.
- **TX power locked**: 3 dBm driver bug. Unfixable.
- **Random deauth**: Unpredictable drops.
- **Fallback**: Intel AX210/AX211.

#### Intel E610 10GbE NIC (Board v1 only)

- **GPU load crash**: Null deref under load. Power cycle to recover. NVM v1.30 partial fix.
- **Board v2.2+**: Stable Realtek NICs. Check revision.
- **Workaround**: BIOS disable or `sudo ip link set <iface> down`.

#### NetworkManager + iwd

- **Boot connectivity**: Fix: `nmcli radio wifi off && nmcli radio wifi on`.
- **DefaultInterface=\***: Intermittent drops.
- **WPA2/3 Enterprise**: GUI broken with iwd.
- **Monitor mode**: Requires full reboot.

## [Changelog](CHANGELOG.txt) · License: MIT
