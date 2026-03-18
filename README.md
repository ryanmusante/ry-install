# ry-install

![Version](https://img.shields.io/badge/version-3.7.32-blue)
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

Before running the fully automated install (`--all`), complete these steps on a fresh CachyOS system:

| # | Step | Command / Action | Why |
|---|------|-----------------|-----|
| 1 | **CachyOS installed** | systemd-boot, btrfs or ext4 root, working internet | Script assumes CachyOS base with systemd-boot (not GRUB) |
| 2 | **Fish shell 3.4+** | `fish --version` (CachyOS ships 4.5) | Required for `string-collect`, `argparse` enhancements |
| 3 | **Kernel 6.14+** | `uname -r` | ntsync, gfx1151 fixes, mt7925e.disable_aspm |
| 4 | **Unrestricted sudo** | `sudo -l` must show `(ALL) ALL` | `--all` aborts if sudo is restricted |
| 5 | **2 GB root free** | `df -h /` | Packages + initramfs + cache headroom |
| 6 | **200 MB /boot free** | `df -h /boot` | Kernel images + initramfs + boot entries |
| 7 | **Network connectivity** | `curl -sf --head https://archlinux.org` | Package sync and installation |
| 8 | **BIOS current** | Check [Beelink](https://dr.bee-link.cn/) downloads | P110+ for ACPI and Strix Halo stability |
| 9 | **Snapshot rootfs** | `sudo btrfs subvolume snapshot -r / /.snapshots/pre-ry-install` | Rollback point (btrfs only; script creates one automatically) |
| 10 | **Review masked services** | See [Masked Services](#masked-services-9) | Sleep/hibernate/suspend targets will be masked — confirm this is a desktop, not a laptop |
| 11 | **WiFi SSID/passphrase ready** | SSID: 1-32 bytes, no shell metacharacters (`` /\;`$(){}|<>'"% ``), no leading/trailing spaces. Passphrase: WPA2, 8-63 chars, no `%` | WiFi credential prompts are interactive even with `--all` (type SSID + passphrase at the end); skipped on non-TTY |
| 12 | **Check CachyOS news** | [wiki.cachyos.org](https://wiki.cachyos.org/) and [archlinux.org/news](https://archlinux.org/news/) | Known upgrade issues before `-Syu` |

**Minimal automated run:**

```fish
./ry-install.fish --dry-run --all   # Preview everything first
./ry-install.fish --all             # Unattended install (prompts auto-yes, progress bar)
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

### Installation

| Flag | Description |
|------|-------------|
| `-a, --all` | Install without prompts (requires unrestricted sudo) |
| `-f, --force` | Auto-yes without progress bar |
| `-V, --verbose` | Show command output on terminal |
| `-n, --dry-run` | Preview changes (no writes) |

### Verification

| Flag | Description |
|------|-------------|
| `--diff` | Per-file unified diff (uses `delta` if installed) |
| `--diff <path>` | Single file diff |
| `--diff --fix` | Re-install drifted files |
| `--verify-static` | Check configs exist with correct content |
| `--verify-runtime` | Check live system state |
| `--lint` | Fish syntax and anti-pattern checks |
| `--check` | Silent idempotency probe (exit 0 = clean, 10 = drift) |
| `--test-all` | Run all safe modes, generate NDJSON logs |

### Utilities

| Flag | Description |
|------|-------------|
| `--install-file <path>` | Re-deploy single managed file |
| `--completions` | Install tab-completions |

### Logs

| Flag | Description |
|------|-------------|
| `--logs <target>` | View logs (system, gpu, wifi, boot, audio, usb, kernel, `<service>`) |
| `--logs analyze [file]` | Parse NDJSON log |
| `--logs last` | Analyze most recent log |
| `--logs all` | Combined summary |
| `--logs list` | List recent logs with summaries |

### Modifiers

| Flag | Requires | Description |
|------|----------|-------------|
| `--fix` | `--diff` | Re-install drifted files |
| `--` | — | End of options |
| `-h, --help` | — | Show help |
| `-v, --version` | — | Show version |

## Configuration

### Kernel Parameters (18)

| Parameter | Purpose |
|-----------|---------|
| `amd_iommu=off` | Disable IOMMU (no VMs, reduces overhead) |
| `amd_pstate=active` | Enable amd_pstate active mode |
| `amdgpu.aspm=0` | Disable GPU ASPM power saving |
| `amdgpu.cwsr_enable=0` | Disable compute wave save/restore |
| `amdgpu.gpu_recovery=1` | Enable GPU hang recovery |
| `amdgpu.modeset=1` | Enable kernel modesetting |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Disable TDC/GFXOFF/stutter |
| `amdgpu.runpm=0` | Disable GPU runtime PM |
| `audit=0` | Disable audit subsystem |
| `initcall_blacklist=simpledrm_platform_driver_init` | Prevent simpledrm conflict |
| `mt7925e.disable_aspm=1` | Disable WiFi ASPM |
| `nowatchdog` | Disable watchdog timers |
| `nvme_core.default_ps_max_latency_us=0` | Disable NVMe power states |
| `pci=pcie_bus_perf` | PCIe performance tuning |
| `quiet` | Suppress boot messages |
| `split_lock_detect=off` | Disable split lock detection |
| `usbcore.autosuspend=-1` | Disable USB autosuspend |
| `zswap.enabled=0` | Disable zswap (zram preferred) |

### loader.conf

| Key | Value |
|-----|-------|
| `default` | `@saved` |
| `timeout` | `0` |
| `console-mode` | `keep` |
| `editor` | `no` (prevents bootloader editing at boot) |

### sdboot-manage

| Key | Value |
|-----|-------|
| `LINUX_OPTIONS` | See [Kernel Parameters](#kernel-parameters-18) |
| `LINUX_FALLBACK_OPTIONS` | `"quiet"` |
| `DEFAULT_ENTRY` | `"manual"` |
| `REMOVE_EXISTING` | `"yes"` |
| `OVERWRITE_EXISTING` | `"yes"` |
| `REMOVE_OBSOLETE` | `"yes"` |

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
| `resolved.conf.d` | MulticastDNS=no |
| `logind.conf.d` | Ignore power/suspend/hibernate/reboot keys |
| `iwd/main.conf` | EnableNetworkConfiguration=false · DriverQuirks: DefaultInterface/PowerSaveDisable · NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd · wifi.powersave=2 · logging.level=ERR |

### Sysctl Overrides

Complements CachyOS vendor `70-cachyos-settings.conf` — no overlap.
Verify: `sysctl --system 2>&1 | rg cachyos`

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `net.core.default_qdisc` | `fq` | Fair queue pacing for BBR |
| `net.ipv4.tcp_congestion_control` | `bbr` | BBR congestion control |
| `net.ipv4.tcp_fastopen` | `3` | TCP Fast Open client + server |
| `fs.inotify.max_user_watches` | `524288` | Inotify watches for IDEs/build tools |

### Environment Variables

| Variable | Value |
|----------|-------|
| `SSH_AUTH_SOCK` | `${XDG_RUNTIME_DIR}/ssh-agent.socket` (systemd expansion) |
| `AMD_VULKAN_ICD` | `RADV` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `8G` |
| `PROTON_USE_NTSYNC` | `1` |
| `PROTON_NO_WM_DECORATION` | `1` |

### User Configuration

| File | Purpose |
|------|---------|
| `fish/conf.d/10-ssh-auth-sock.fish` | SSH socket priority: forwarded > gcr > systemd user agent |
| `environment.d/10-environment.conf` | Environment variables for systemd user services and graphical sessions |
| `systemd/user/ssh-agent.service` | Persistent `ssh-agent -D` with socket at `%t/ssh-agent.socket` |

### Packages

| Action | Packages |
|--------|----------|
| **Add (12)** | mkinitcpio-firmware, nvme-cli, iw, cachyos-gaming-meta, cachyos-gaming-applications, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove (7)** | plymouth, cachyos-plymouth-bootanimation, ufw, octopi, micro, cachyos-micro-settings, btop |

### Masked Services (9)

| Service | Note |
|---------|------|
| `ananicy-cpp.service` | CachyOS scheduler — masked for manual tuning |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp; masked to prevent dep reinstall |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `sleep.target` | Desktop — no sleep |
| `suspend.target` | Desktop — no suspend |
| `hibernate.target` | Desktop — no hibernate |
| `hybrid-sleep.target` | Desktop — no hybrid sleep |
| `suspend-then-hibernate.target` | Desktop — no suspend-then-hibernate |

### Services (2)

| Unit | Description |
|------|-------------|
| `amdgpu-performance.service` | Write `high` to `power_dpm_force_performance_level` sysfs after graphical.target (retry loop, multi-GPU) |
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` sysfs after cpupower.service |

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
| 10 | System | `/etc/sysctl.d/99-ry-sysctl.conf` |
| 11 | User | `~/.config/fish/conf.d/10-ssh-auth-sock.fish` |
| 12 | User | `~/.config/environment.d/10-environment.conf` |
| 13 | User | `~/.config/systemd/user/ssh-agent.service` |
| 14 | Service | `/etc/systemd/system/amdgpu-performance.service` |
| 15 | Service | `/etc/systemd/system/cpupower-epp.service` |

## Safety

| Feature | Detail |
|---------|--------|
| Atomic writes | Write to tmp → chmod → mv (same filesystem) |
| Root detection | Forces `--dry-run` when run as root |
| Instance lock | Atomic mkdir with PID verification and stale reclaim |
| Credentials | WiFi passphrase: read -s, 0600, erased on all exit paths, redacted in logs |
| Signal handling | Traps SIGINT/SIGTERM/SIGHUP/SIGQUIT (exit 130) and SIGPIPE (exit 141); cleanup runs once via `_CLEANUP_DONE` guard |
| Logging | NDJSON in `~/ry-install/logs/YYYY-MM-DD/*.jsonl` (`jq` queryable) |
| Boot safety | Initramfs/bootloader rebuild aborts on failure |
| LVM-aware | Skips lvm2-monitor masking when LVM detected |
| Orphan tracking | Manifest records installed destinations; warns on version or profile change |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Non-critical failure |
| `2` | Usage error |
| `3` | Preflight check failed |
| `4` | Boot-critical failure (mkinitcpio, sdboot-manage, vmlinuz missing) |
| `5` | Lock acquisition failed |
| `10` | Drift detected (`--check`) |
| `11` | Lint errors (`--lint`) |
| `130` | Interrupted (SIGINT) |
| `141` | Broken pipe (SIGPIPE) |

> `--diff` and `--verify-*` return exit 1 when differences or failures are found.
> This is expected behavior for scripting: `./ry-install.fish --diff || echo "diffs found"`.

### Install Flow (19 steps)

Dependencies → Sync → Packages → System files → User files → AMDGPU service → Databases → Reload → Remove packages → Mask services → NM dispatcher → CPU service → Timers → Upgrade → Initramfs → Bootloader → Finalize → NM restart → WiFi

### Data Directory

| Path | Contents |
|------|----------|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON log files (*.jsonl) |
| `~/ry-install/.lock/` | Instance guard (atomic mkdir) |
| `~/ry-install/.hardware-fingerprint` | Hardware drift detection |
| `~/ry-install/.manifest` | Orphan tracking (version, profile, destinations) |

## After Install

Reboot → `--verify-static` → `--verify-runtime` → `sudo pacdiff` → test WiFi + gaming

## Troubleshooting

| Problem | Command |
|---------|---------|
| Query errors | `jq 'select(.event == "err")' ~/ry-install/logs/**/*.jsonl` |
| GPU perf level | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend | `nmcli -t -f TYPE,FILENAME connection show --active` |
| ntsync check | Kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` |

### Profiles

Machine-specific globals (kernel params, packages, services, thresholds, destinations) are encapsulated in profile functions. The built-in default is `profile_gtr9_pro`. External profiles load from `~/.config/ry-install/profiles/<name>.fish`.

| Source | Resolution order |
|--------|-----------------|
| `~/.config/ry-install/default-profile` | Persistent default (single line: profile name) |
| `gtr9_pro` | Hardcoded fallback |

External profiles must define a `function profile_<name>` setting all required globals. Files are syntax-checked (`fish --no-execute`) before sourcing. Profile validation enforces 25+ required globals, name consistency, and numeric types.

### Adapting

Create `~/.config/ry-install/profiles/<name>.fish` with a `profile_<name>` function. Copy `profile_gtr9_pro` as a starting point and adjust `KERNEL_PARAMS`, `MKINITCPIO_MODULES`, `PKGS_ADD`/`PKGS_DEL`, `MASK`, `EXPECTED_SERVICES`, `ENV_VARS`, service destinations, and threshold globals. Set the profile name in `~/.config/ry-install/default-profile` and run `./ry-install.fish --check` to validate.

### References

| Link | Topic |
|------|-------|
| [NM iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) | NetworkManager + iwd backend |
| [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) | MediaTek WiFi 7 |
| [gfx1151](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) | Mesa GPU issues |
| [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) | AMDGPU feature mask |

## [Changelog](CHANGELOG.txt) · License: MIT
