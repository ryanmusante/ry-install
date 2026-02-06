# ry-install

**v4.0.1** · Optimized CachyOS configuration for **Beelink GTR9 Pro** (AMD Ryzen AI Max+ 395 / Strix Halo).

> **Self-contained:** All 16 config files embedded in `ry-install.fish`. No external dependencies.

## Hardware

| Component | Spec |
|-----------|------|
| CPU | Ryzen AI Max+ 395 (Zen 5, 16C/32T, 5.1GHz) |
| GPU | Radeon 8060S (RDNA 3.5, gfx1151, 40 CUs) |
| Memory | 128GB LPDDR5x-8000 (unified with GPU) |
| WiFi | MediaTek MT7925 (WiFi 7) |
| Ethernet | Dual Intel E610 10GbE |
| TDP | 55-120W configurable |

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
./ry-install.fish              # Interactive
./ry-install.fish --all        # Unattended (progress bar)
./ry-install.fish --dry-run    # Preview changes
./ry-install.fish --verify     # Post-install check
```

**Prerequisites:** CachyOS, systemd-boot, fish shell, 2GB free on root, network connection

## Options

### Installation
| Option | Description |
|--------|-------------|
| `--all` | Unattended (auto-yes, progress bar) |
| `--force` | Auto-yes all prompts (for `--clean`, `--all`, etc.) |
| `--verbose` | Show terminal output |
| `--dry-run` | Preview without changes |

### Verification
| Option | Description |
|--------|-------------|
| `--diff` | Compare embedded vs installed |
| `--verify` | Full verification (static + runtime) |
| `--verify-static` | Check config files |
| `--verify-runtime` | Check live state (after reboot) |
| `--lint` | Syntax and anti-pattern check |

### Utilities
| Option | Description |
|--------|-------------|
| `--status` | Quick system health dashboard |
| `--watch` | Live monitoring (temps, power, clocks) |
| `--clean` | System cleanup (cache, journal, orphans) |
| `--wifi-diag` | WiFi diagnostics and troubleshooting |
| `--benchmark` | Quick performance sanity check |
| `--export` | Export system config for sharing/troubleshooting |
| `--backup-list` | List available configuration backups |
| `--logs <target>` | View logs (system, gpu, wifi, boot, audio, usb, or service name) |
| `--diagnose` | Automated problem detection and health check |

### Other
| Option | Description |
|--------|-------------|
| `--no-color` | Disable colored output (also respects `NO_COLOR` env) |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

## Known Limitations

| Limitation | Details |
|------------|---------|
| **AMD GPU only** | Script assumes AMDGPU driver. Intel/NVIDIA systems require modifications. |
| **ntsync** | Requires kernel 6.14+. Script warns if kernel is older. |
| **NM iwd backend** | Experimental upstream. Known issues: enterprise WPA (EAP), hidden SSIDs, some captive portals. |
| **Intel E610 10GbE** | Dual NICs have confirmed firmware lockup under GPU + network load (NVM <1.30). Both ports share a single NVM image and fail simultaneously. `ice` driver is blacklisted. Use WiFi or USB ethernet until Intel releases a stable NVM update. |
| **linux-firmware** | Version 20251125 breaks ROCm on Strix Halo (gfx1151). Use 20251111 or ≥20260110. Script warns in `--diagnose`. |
| **sched-ext** | Not compatible with BORE kernel. Script checks for and warns about active scx schedulers (scx_lavd, scx_bpfland, etc). |
| **Flatpak/Snap** | Environment variables may not propagate. Set in app overrides if needed. |
| **Secure Boot** | Not tested. May require signing custom kernels/modules. |
| **Single system** | Optimized for Beelink GTR9 Pro. Other hardware may need threshold adjustments. |

### Hardcoded Thresholds

These values are optimized for Strix Halo and may need adjustment for other systems:

| Threshold | Value | Location |
|-----------|-------|----------|
| Temperature warning | 85°C | `--status`, `--diagnose` |
| Disk space minimum | 2GB root, 200MB boot | Pre-install check |
| Cache cleanup prompt | >100MB | `--clean` |
| Boot time (verify-runtime) | 15s | `--verify-runtime` |
| Boot time (diagnose) | 30s | `--diagnose` |
| Journal size warning | ≥2GB | `--diagnose` |
| NVMe life warning | ≥90% used | `--diagnose` |
| WiFi band change warning | >5 changes | `--wifi-diag` |

## Safety

| Concern | Handling |
|---------|----------|
| LUKS | Detects and prompts for `sd-encrypt` hook |
| LVM | Skips masking `lvm2-monitor` if LVM detected |
| Backups | All files backed up to `~/ry-install/backup/<timestamp>` |
| AMDGPU timing | Service-based (Arch #72655 - udev timing unreliable) |
| **Syntax validation** | All configs validated before install (hooks, units, fish, modprobe) |
| **Atomic writes** | All file writes use temp file + mv pattern |
| **WiFi credentials** | Passphrase not logged, connection file created with 0600 permissions |

## Recovery

```fish
# Restore from backup
sudo cp ~/ry-install/backup/<timestamp>/etc/mkinitcpio.conf /etc/
sudo mkinitcpio -P

# If system won't boot: CachyOS live USB → mount → restore → arch-chroot → rebuild
```

| To revert | Action |
|-----------|--------|
| Kernel params | Restore `/etc/sdboot-manage.conf`, `sudo sdboot-manage update` |
| mkinitcpio | Restore `/etc/mkinitcpio.conf`, `sudo mkinitcpio -P` |
| Masked services | `sudo systemctl unmask <service>` |

## fstab Review

Recommended mount options after install:

**btrfs:** `rw,noatime,compress=zstd:1,ssd,space_cache=v2,subvol=/@`
**ext4:** `rw,noatime`
**Avoid:** `discard` (use `fstrim.timer` instead)

## Hardware Notes

Strix Halo is a new platform—expect updates. Check [Beelink](https://dr.bee-link.cn/) for BIOS, kernel bugzilla/Mesa GitLab for gfx1151 issues.

**Thermal targets:** 85°C sustained, 95°C throttle, 100°C max. Monitor: `sensors`, `amdgpu_top`

**Intel E610 10GbE:** Both NICs share a single NVM firmware image. Under sustained GPU + network load, a confirmed firmware lockup causes both ports to fail simultaneously. This is a cross-platform hardware bug (not Linux-specific) requiring NVM ≥1.30 (shipped with firmware 1.10). The `ice` driver is blacklisted until Intel provides a stable update. Use WiFi or USB ethernet as a workaround.

**Linux firmware:** Version 20251125 introduces a regression that breaks ROCm/compute on Strix Halo (gfx1151). Use 20251111 or ≥20260110. The `--diagnose` command checks for this.

## Implementation Notes

| Topic | Details |
|-------|---------|
| Error tracking | Continues on non-critical failures, reports at end |
| ananicy-cpp | Masked (not removed—`cachyos-settings` depends on it) |
| iwd | Required for NM backend. Do NOT enable `iwd.service` separately |
| WiFi reconnect | Done last (backend switch may disconnect) |
| Sleep | All targets masked (desktop stays on, S0ix unreliable on new platform) |

### Kernel Parameters (20)

| Parameter | Purpose |
|-----------|---------|
| `8250.nr_uarts=0` | Disable serial ports (no UART hardware) |
| `amd_iommu=off` | Disable IOMMU (no VM passthrough needed) |
| `amd_pstate=active` | EPP mode for CPU frequency |
| `amdgpu.cwsr_enable=0` | Disable compute shader workload recovery |
| `amdgpu.dcdebugmask=0x10` | Disable display core PSR negotiation |
| `amdgpu.gpu_recovery=1` | Auto-recover from GPU hangs |
| `amdgpu.modeset=1` | Enable kernel modesetting |
| `amdgpu.ppfeaturemask=0xfffd7fff` | Disable GFXOFF (bit 15) and stutter mode (bit 17) to prevent APU crashes |
| `amdgpu.runpm=0` | Disable runtime power management |
| `audit=0` | Disable audit subsystem |
| `btusb.enable_autosuspend=n` | Prevent Bluetooth USB autosuspend |
| `mt7925e.disable_aspm=1` | Disable WiFi ASPM for stability |
| `nowatchdog` | Disable watchdog timers |
| `nvme_core.default_ps_max_latency_us=0` | Disable NVMe power saving |
| `pci=pcie_bus_perf` | Optimize PCIe bus for performance |
| `quiet` | Silent boot |
| `split_lock_detect=off` | Gaming performance (single-user only) |
| `tsc=reliable` | Consistent timestamps |
| `usbcore.autosuspend=-1` | Disable USB autosuspend globally |
| `zswap.enabled=0` | Disable zswap (128GB RAM) |

### Environment Variables (4)

| Variable | Purpose |
|----------|---------|
| `AMD_VULKAN_ICD=RADV` | Use RADV Vulkan driver |
| `MESA_SHADER_CACHE_MAX_SIZE=12G` | Large shader cache |
| `PROTON_USE_NTSYNC=1` | NT synchronization (kernel 6.14+) |
| `PROTON_NO_WM_DECORATION=1` | Skip WM decorations |

### Masked Services (9)

| Service | Reason |
|---------|--------|
| `ananicy-cpp.service` | Conflicts with manual tuning |
| `lvm2-monitor.service` | Not using LVM (skipped if LVM detected) |
| `ModemManager.service` | No modem hardware |
| `NetworkManager-wait-online.service` | Slows boot unnecessarily |
| `sleep.target` | Desktop stays powered |
| `suspend.target` | S0ix unreliable on Strix Halo |
| `hibernate.target` | Not using hibernate |
| `hybrid-sleep.target` | Not using hybrid sleep |
| `suspend-then-hibernate.target` | Not using suspend-then-hibernate |

### Modprobe Configuration

**Options (6):**
| Module | Option | Purpose |
|--------|--------|---------|
| `amdgpu` | `modeset=1 cwsr_enable=0 gpu_recovery=1 runpm=0 dcdebugmask=0x10` | GPU stability and performance |
| `mt7925e` | `disable_aspm=1` | WiFi stability |
| `btusb` | `enable_autosuspend=n` | Bluetooth stability |
| `usbcore` | `autosuspend=-1` | USB device stability |
| `nvme_core` | `default_ps_max_latency_us=0` | NVMe performance |
| `bluetooth` | `disable_esco=1` | Silence eSCO errors in dmesg |

**Blacklist (6):**
| Module | Reason |
|--------|--------|
| `sp5100_tco` | AMD watchdog (disabled via kernel params) |
| `snd_acp_pci` | Silences "No matching ASoC machine driver" errors |
| `pcspkr` | PC speaker beep |
| `snd_pcsp` | PC speaker audio |
| `floppy` | No floppy drive |
| `ice` | Intel E610 10GbE — firmware lockup (NVM <1.30), both ports fail simultaneously |

### mkinitcpio Configuration

**Modules:** `amdgpu`, `nvme` (early KMS and NVMe support)

**Hooks:** `base` → `systemd` → `autodetect` → `microcode` → `modconf` → `kms` → `keyboard` → `sd-vconsole` → `block` → `filesystems` → `fsck`

**Compression:** `zstd`

> **Note:** `resume` hook omitted (sleep masked). LUKS systems: script prompts to add `sd-encrypt` before `filesystems`.

## Packages

**Added (12):** mkinitcpio-firmware, nvme-cli, htop, iw, plocate, cachyos-gaming-meta, cachyos-gaming-applications, fd, ripgrep, sd, dust, procs

> **Note:** `yay` is conditionally added when CachyOS is detected. `bat` and `eza` are already CachyOS defaults via `cachyos-fish-config` and are not included here. `ripgrep` is a default netinstall selection but included explicitly to guarantee availability.

**Removed (7):** power-profiles-daemon, plymouth, cachyos-plymouth-bootanimation, ufw, octopi, micro, cachyos-micro-settings

## Embedded Files (16)

**System (12):**
| File | Purpose |
|------|---------|
| `/boot/loader/loader.conf` | systemd-boot config (timeout=0, editor=no) |
| `/etc/udev/rules.d/99-cachyos-udev.rules` | ntsync perms, USB autosuspend off |
| `/etc/modprobe.d/99-cachyos-modprobe.conf` | Module options and blacklist |
| `/etc/environment` | Global environment variables |
| `/etc/iwd/main.conf` | iwd for NetworkManager backend |
| `/etc/mkinitcpio.conf` | Initramfs configuration |
| `/etc/modules-load.d/99-cachyos-modules.conf` | Load ntsync at boot |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | Disable mDNS |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | Ignore power/suspend/hibernate buttons |
| `/etc/sdboot-manage.conf` | Kernel cmdline parameters |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | iwd backend, powersave off |
| `/etc/conf.d/wireless-regdom` | Wireless regulatory domain |

**User (2):**
| File | Purpose |
|------|---------|
| `~/.config/fish/conf.d/10-ssh-auth-sock.fish` | SSH agent socket for fish |
| `~/.config/environment.d/50-gaming.conf` | Gaming vars for systemd user services |

**Services (2):**
| File | Purpose |
|------|---------|
| `/etc/systemd/system/amdgpu-performance.service` | Set GPU to high performance |
| `/etc/systemd/system/cpupower-epp.service` | Set CPU governor and EPP to performance |

## Utilities

Beyond installation, ry-install provides system management utilities tailored for the Strix Halo platform.

### System Status (`--status`)

Quick health check dashboard showing 12 sections:
- **System**: Hostname, kernel, uptime
- **Temperatures**: CPU/GPU with threshold warnings
- **GPU Performance**: Level, utilization, VRAM
- **CPU Performance**: Governor, EPP, frequency
- **Services**: amdgpu-performance, cpupower-epp, fstrim.timer status
- **Gaming**: ntsync availability, Proton settings
- **Network**: WiFi connection, signal strength
- **Memory**: RAM and swap usage
- **Storage**: Root filesystem usage
- **Fans**: Fan speeds (if sensors available)
- **Power**: Package and GPU power draw (watts)
- **Schedulers**: CPU scheduler (BORE/EEVDF) and I/O scheduler

```fish
./ry-install.fish --status
```

### Live Monitoring (`--watch`)

Real-time system monitoring using `watch`:
- Temperatures (updates every second)
- GPU busy %, power draw
- CPU frequency
- Memory usage

```fish
./ry-install.fish --watch  # Ctrl+C to exit
```

### System Cleanup (`--clean`)

Interactive cleanup with size reporting (7 targets):
- **Package cache**: Keeps 2 versions (`paccache -rk2`)
- **System journal**: Keeps 7 days (`journalctl --vacuum-time=7d`)
- **Shader caches**: Mesa, RADV shader caches
- **Orphan packages**: Unneeded dependencies
- **Old ry-install logs**: Logs older than 7 days
- **Coredumps**: System crash dumps (`coredumpctl vacuum-time`)
- **User cache**: Thumbnails, fontconfig cache

```fish
./ry-install.fish --clean           # Interactive
./ry-install.fish --clean --dry-run # Preview only
./ry-install.fish --clean --all     # Non-interactive
```

### WiFi Diagnostics (`--wifi-diag`)

Troubleshooting for MT7925 WiFi 7 (9 sections):
- **Driver**: Module name and chip identification
- **Connection**: SSID, frequency, link speed
- **Signal**: Strength with quality assessment
- **NetworkManager Config**: Backend verification (iwd)
- **Recent Issues**: Error log analysis (last 5 min)
- **WiFi 7 / MLO**: Multi-Link Operation error detection
- **Firmware**: Driver firmware version
- **Regulatory**: Country code and regulatory domain
- **Capabilities**: Supported bands, 6GHz, 160MHz support

```fish
./ry-install.fish --wifi-diag
```

### Quick Benchmark (`--benchmark`)

Sanity check for performance:
- CPU: iteration count test
- Memory: dd bandwidth
- GPU: glxgears/vkcube FPS
- Storage: dd sync write

```fish
./ry-install.fish --benchmark
```

> **Note:** For comprehensive benchmarks, use dedicated tools like `phoronix-test-suite`, `glmark2`, or `unigine`.

### System Export (`--export`)

Generate a shareable system configuration report (18 sections):
- **System**: Hostname, kernel, uptime
- **Hardware**: CPU, GPU, BIOS version, memory
- **GPU State**: Performance level, clocks, VRAM
- **CPU State**: Governor, EPP, frequency range
- **Kernel cmdline**: Boot parameters
- **Services**: Systemd service status
- **Masked services**: Disabled services list
- **Network**: IP addresses, DNS, gateway
- **WiFi details**: SSID, signal, band
- **Config files**: Key configuration snippets
- **Packages**: Important package versions
- **Recent errors**: Journal errors (last hour)
- **Boot analysis**: `systemd-analyze` timing
- **Loaded modules**: Relevant kernel modules
- **Block devices**: `lsblk` output
- **Mount options**: Filesystem mount flags
- **PCI devices**: GPU and network adapters
- **Temperatures**: Current sensor readings

```fish
./ry-install.fish --export
# Creates ~/ry-install/logs/export-YYYYMMDD-HHMMSS.txt
```

> **Note:** Export file contains no passwords or sensitive data. Safe to share in forums or support tickets.

### Backup List (`--backup-list`)

View available configuration backups:
- Lists all backups with timestamps
- Shows size and file count
- Displays backup contents (etc/, boot/, home/)

```fish
./ry-install.fish --backup-list
./ry-install.fish --backup-list --verbose  # Show contents
```

### Log Viewer (`--logs`)

Quick access to filtered system logs:

```fish
./ry-install.fish --logs system   # dmesg + journal errors
./ry-install.fish --logs gpu      # AMDGPU/DRM messages
./ry-install.fish --logs wifi     # NetworkManager + iwd
./ry-install.fish --logs boot     # Boot sequence
./ry-install.fish --logs audio    # PipeWire/audio
./ry-install.fish --logs usb      # USB events
./ry-install.fish --logs <name>   # Any systemd service
```

### Diagnostics (`--diagnose`)

Automated problem detection (17 checks):
- **Kernel Errors**: Recent dmesg errors
- **Failed Services**: Systemd failures
- **Expected Services**: amdgpu-performance, cpupower-epp, fstrim.timer
- **GPU State**: Performance level verification
- **CPU State**: Governor and EPP verification
- **Disk Space**: Usage warnings (80%/90% thresholds)
- **Temperatures**: Heat warnings (85°C/90°C thresholds)
- **Network**: Connectivity test
- **Gaming**: ntsync module availability
- **Memory**: OOM event detection
- **Kernel Taint**: Proprietary/out-of-tree module detection
- **Coredumps**: Recent crash dump detection
- **Journal Size**: Disk usage warning (>2GB)
- **NVMe Health**: SMART status and life percentage
- **Boot Performance**: Slow boot detection (>30s)
- **sched-ext**: Warns if scx schedulers active on BORE kernel
- **Linux Firmware**: Warns about known-bad firmware versions for Strix Halo

```fish
./ry-install.fish --diagnose
# Exit code = number of issues found
```

## Fish Completions

Tab completion for all options:

```fish
cp ry-install-completions.fish ~/.config/fish/completions/ry-install.fish
```

## Troubleshooting

### GPU not at high performance
```fish
cat /sys/class/drm/card*/device/power_dpm_force_performance_level  # should be 'high'
sudo systemctl enable --now amdgpu-performance.service
```

### WiFi disconnects
```fish
# Check iwd backend active
nmcli -t -f TYPE,FILENAME connection show --active | grep wifi
# Disable band steering in router if issues persist
```

### ntsync not available
```fish
uname -r  # requires 6.14+
zgrep CONFIG_NTSYNC /proc/config.gz  # should be y or m
ls -la /dev/ntsync  # should exist with rw perms
```

### Dmesg noise silenced
- "No matching ASoC machine driver" → `snd_acp_pci` blacklisted
- "HCI Enhanced Setup Synchronous Connection" → `bluetooth disable_esco=1`

### Boot issues after install
```fish
# Boot from CachyOS live USB, then:
mount /dev/nvme0n1p2 /mnt        # adjust partition
mount /dev/nvme0n1p1 /mnt/boot   # EFI partition
arch-chroot /mnt
cp ~/ry-install/backup/<timestamp>/etc/mkinitcpio.conf /etc/
mkinitcpio -P
exit && reboot
```

## Verification

```fish
./ry-install.fish --verify  # Full check after reboot
```

**Quick check:**
```fish
cat /sys/class/drm/card*/device/power_dpm_force_performance_level  # high
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor          # performance
systemctl is-active cpupower-epp fstrim.timer                      # active
test -c /dev/ntsync && echo "ntsync OK"
```

## Structure

```
ry-install/
├── LICENSE
├── README.md
├── ry-install.fish              # Self-contained (16 configs embedded)
└── ry-install-completions.fish  # Fish shell tab completions
```

## Changelog

### v4.0.1

**Fixed (audit):**

| # | Severity | Fix |
|---|----------|-----|
| 1 | **MED** | `dcdebugmask=0x10` missing from modprobe amdgpu options — cmdline had it but modprobe didn't, so the parameter was lost when amdgpu loaded as a module. Added to match cmdline (5/5 non-exempt params now in parity) |
| 2 | **MED** | WiFi `.nmconnection` UUID malformed — `sed` regex captured 8-5-5-5 groups instead of RFC 4122 standard 8-4-4-4-12, producing invalid UUIDs with embedded whitespace. NM would reject or silently regenerate, breaking deterministic/idempotent updates |
| 3 | **LOW** | Boot entry count in `_install_rebuild_boot` used `find` without `sudo` — inconsistent with `verify_static` which uses `sudo find`. Could miss entries on restrictive `/boot/loader/entries` permissions |
| 4 | **LOW** | `amdgpu-performance.service` enabled without `--now` — inconsistent with `cpupower-epp` which uses `enable --now`. Service wouldn't start until next reboot |

### v4.0

**Fixed (initramfs rebuild + verify accuracy):**

| # | Severity | Fix |
|---|----------|-----|
| 1 | **CRIT** | Initramfs not rebuilt after config changes — `PKGS_REMOVED` flag falsely assumed `pacman -Rns` of non-kernel packages (plymouth, micro, etc.) triggered mkinitcpio hooks. `90-mkinitcpio-install.hook` fires on Install/Upgrade only, not Remove. Initramfs was left with old config (plymouth hook baked in). Removed the optimization; explicit `mkinitcpio -P` always runs |
| 2 | **HIGH** | Verify reported 202 OK with zero boot entries — no check for `*.conf` files in `/boot/loader/entries/`. Added boot entry count to `verify_static` |
| 3 | **MED** | Services verified `is-active` only, not `is-enabled` — a manually-started service passes verify but won't survive reboot. Added `is-enabled` check for `amdgpu-performance`, `cpupower-epp`, `fstrim.timer`, and `ssh-agent` with "won't persist" warning |
| 4 | **MED** | `amdgpu.ppfeaturemask` / `amdgpu.dcdebugmask` not verified at runtime via `/sys/module/amdgpu/parameters/`. Cmdline presence ≠ driver applied the value. Added with hex-normalized comparison |
| 5 | **MED** | `mt7925e.disable_aspm` not verified at runtime. Module parameter `/sys/module/mt7925e/parameters/disable_aspm` now checked (accepts both `Y` and `1`) |
| 6 | **MED** | WiFi connectivity not checked — interface exists + iwd running passed even when disconnected. Added `nmcli` device state check |
| 7 | **MED** | `.nmconnection` absence reported as neutral INFO even when WiFi expected. Now WARN when `wifi.backend=iwd` configured but no profiles exist |
| 8 | **LOW** | NM wifi backend status shown at runtime via `nmcli general` |

### v3.7.3

**Fixed (verify accuracy):**

| # | Severity | Fix |
|---|----------|-----|
| 1 | **MED** | `amdgpu.ppfeaturemask` / `dcdebugmask` verify false-FAIL — sysfs outputs decimal (`4294637567`) but code compared against hex string (`0xfffd7fff`). Now normalizes both sides to decimal before comparison |
| 2 | **LOW** | Verify modes stall 3s on first `/boot` access — `verify_static` and `verify_runtime` now pre-acquire sudo at function entry, eliminating mid-output password prompt that collided with check output |
| 3 | **LOW** | Duplicate `# ─── INSTALLATION SUB-FUNCTIONS ───` section header removed |

### v3.6.3

**Fixed (documentation and cleanup):**

| # | Severity | Fix |
|---|----------|-----|
| 1 | **LOW** | README kernel parameters table consolidated — all 20 params now in a single table with descriptions instead of split across a 13-row table and a prose "Full list" of 7 |
| 2 | **LOW** | `do_watch` temp script now uses a deterministic path (`/tmp/ry-install-watch-$UID.fish`) instead of `mktemp`, so it self-cleans on next invocation if a previous run was killed with SIGKILL |

### v3.6.2

**Fixed (execution flow audit):**

| # | Severity | Fix |
|---|----------|-----|
| 1 | **MED** | `--logs <service>` service existence check replaced — `systemctl list-unit-files` always returns 0 even for nonexistent units, making the "not found" message unreachable dead code. Now uses `systemctl cat` which correctly fails for missing units |
| 2 | **MED** | Missing `INSTALL_HAD_ERRORS` when iwd not installed at NM restart — `_err` was logged but the flag wasn't set, so the install summary would report success instead of "(WITH WARNINGS)" |
| 3 | **MED** | Redundant second `pacman -Syu` eliminated — after the v3.6.1 merge fix, the first `-Syu --needed` already performs a full system upgrade. The second was a no-op wasting 10-30s of mirror sync in `--all` mode. Now gated by `system_upgraded` flag; only runs if the first was skipped |
| 4 | **LOW** | `do_clean` orphan removal now uses `_run` for logging and error checking — was calling `sudo pacman -Rns` directly, bypassing log capture and printing unconditional success |
| 5 | **LOW** | Wireless regulatory domain `sed` now verifies the substitution took effect — on Arch default files where all `WIRELESS_REGDOM=` lines are commented out, sed silently no-ops. Now detects this and appends the value as a fallback |
| 6 | **LOW** | `NTSYNC_SUPPORTED` now initialized to `true` before the dry-run gate — previously unset in `--dry-run` mode since `check_kernel_version` only runs in live mode. The `set -q` guard prevented crashes, but the explicit default is cleaner |

### v3.6.1

**Fixed (runtime logic — failure path bugs):**

| # | Severity | Fix |
|---|----------|-----|
| 1 | **CRIT** | `mkinitcpio -P` failure now sets `INSTALL_HAD_ERRORS` — previously only logged the error without flagging, so the install summary would report success even if initramfs rebuild failed |
| 2 | **MED** | Eliminated partial upgrade risk — `pacman -Sy` + `pacman -S` merged into single `pacman -Syu --needed` call. A standalone `-Sy` followed by `-S` can leave the system in a broken state if dependencies were updated in the database but base packages were not upgraded |
| 3 | **MED** | `_run` redaction: `$argv` list now joined via `string join " "` before logging and pattern matching, instead of relying on implicit `"$argv"` concatenation which can mangle multi-word arguments |
| 4 | **LOW** | `--logs -b` now warns instead of silently treating `-b` as a service name. Flags passed as log targets are rejected with a helpful message |
| 5 | **LOW** | Benchmark `mktemp` now uses `--tmpdir` to respect `$TMPDIR` instead of hardcoding `-p /tmp` |

### v3.6.0

**Removed:**
- `nmi_watchdog=0` kernel parameter (redundant with `nowatchdog`, already covered by CachyOS sysctl defaults)
- `RADV_PERFTEST=sam` environment variable (SAM/ReBAR is a PCIe feature for discrete GPUs; irrelevant for iGPU with unified memory — CPU already has full memory access)
- `libcamera` package (no camera hardware on GTR9 Pro)

**Added:**
- `ice` module blacklisted — Intel E610 10GbE NICs have a confirmed cross-platform firmware lockup under sustained GPU + network load (NVM <1.30). Both ports share a single NVM image and fail simultaneously. Blacklisted until Intel releases a stable NVM update.
- sched-ext scheduler check in `--diagnose` — warns if scx_loader or scx schedulers (scx_lavd, scx_bpfland, scx_rusty) are running, which are not compatible with the BORE kernel
- linux-firmware version check in `--diagnose` — warns about version 20251125 which breaks ROCm/compute on Strix Halo (gfx1151). Recommends 20251111 or ≥20260110.

**Fixed:**
- `ppfeaturemask=0xfffd7fff` documentation — previously described as "Enable PowerPlay features". Corrected to "Disable GFXOFF (bit 15) and stutter mode (bit 17) to prevent APU crashes". Overdrive (bit 14) remains enabled; this mask clears two bits, not one.

**Kept for precaution (audited, documented in source):**

The following were flagged during audit but retained. Each has inline documentation in `ry-install.fish` explaining the finding and rationale.

| Item | Finding | Rationale |
|------|---------|-----------|
| `amd_pstate=active` | Redundant (default since kernel 6.5) | Explicit is safer across kernel upgrades |
| `amdgpu.modeset=1` | No-op (KMS unconditional on RDNA 3.5+) | Harmless, guards against future kernel changes |
| `amdgpu.runpm=0` | No-op on iGPU-only (runtime PM is for dGPU D3cold) | Harmless, prevents issues if eGPU ever added |
| `amdgpu.gpu_recovery=1` | Redundant (default auto=-1 enables for GFX8+) | Explicit guarantee of hang recovery |
| `usbcore.autosuspend=-1` | Broader than needed (btusb handles MT7925E) | Prevents USB dropouts on all devices |
| `split_lock_detect=off` | CachyOS prefers sysctl `kernel.split_lock_mitigate=0` | Cmdline approach is simpler for gaming |
| `tsc=reliable` | Unnecessary on Zen 5 (auto-detects TSC) | Harmless, avoids clocksource edge cases |
| Modprobe `amdgpu modeset=1 runpm=0` | Mirrors kernel cmdline flags | Needed when amdgpu loads as module |
| Modprobe `bluetooth disable_esco=1` | Generic workaround, not MT7925E-specific | Silences eSCO dmesg noise |
| `MESA_SHADER_CACHE_MAX_SIZE=12G` | Audit suggested 2-4G (Fossilize bypasses this) | 128GB system has headroom, benefits non-Steam Vulkan |
| `amdgpu-performance.service` "high" | May not change clocks on Strix Halo iGPU | Safe fallback, adds 5-15W idle when working |
| `cpupower-epp.service` | Adds 20-40W idle overhead | User preference for locked performance mode on BORE |
| `power-profiles-daemon` removed | CachyOS ships custom ppd with integrations | Not needed with BORE kernel + cpupower.service |
| `ufw` removed | Leaves no firewall | Acceptable: E610 blacklisted, WiFi-only behind NAT |
| TTM `pages_limit` not added | Required for ROCm/LLM (exposes ~124GB to GPU) | Gaming-focused config, add when ROCm needed |

**Documentation:**
- Added Intel E610 firmware lockup details to Known Limitations and Hardware Notes
- Added linux-firmware regression warning to Known Limitations and Hardware Notes
- Added sched-ext/BORE kernel incompatibility to Known Limitations
- Inline audit notes added to kernel params, env vars, modprobe, services, and packages sections
- Updated diagnostics from 15 to 17 checks
- Updated kernel parameters from 21 to 20
- Updated environment variables from 5 to 4
- Updated packages from 13 to 12 added
- Updated blacklist from 5 to 6 modules

### v3.5.1

Initial public release.

## License

MIT
