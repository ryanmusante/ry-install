# ry-install

**v2.0** — Self-contained CachyOS configuration for **Beelink GTR9 Pro** (AMD Ryzen AI Max+ 395 / Strix Halo). All 19 config files and fish completions embedded in `ry-install.fish` — no external configs, requires only standard CachyOS base tools.

## Hardware

Ryzen AI Max+ 395 (Zen 5, 16C/32T, 5.1GHz) · Radeon 8060S (RDNA 3.5, gfx1151, 40 CUs) · 128GB LPDDR5x-8000 (unified) · MediaTek MT7925 (WiFi 7) · Dual Intel E610 10GbE · 55–120W TDP

Strix Halo is a new platform — check [Beelink](https://dr.bee-link.cn/) for BIOS, kernel bugzilla / Mesa GitLab for gfx1151 issues. Thermal limits: 85°C sustained, 95°C throttle, 100°C max. Monitor with `sensors` or `amdgpu_top`. **fstab:** `rw,noatime,lazytime` for ext4/btrfs; avoid `discard` (use `fstrim.timer`).

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
./ry-install.fish              # Interactive
./ry-install.fish --all        # Unattended (progress bar)
./ry-install.fish --dry-run    # Preview changes
./ry-install.fish --verify     # Post-install check
./ry-install.fish --test-all   # Run all safe modes, generate log files
```

**Prerequisites:** CachyOS, systemd-boot, fish 3.3+, 2GB free on root, network connection

## Options

| Option | Description |
|--------|-------------|
| `--all` | Unattended (auto-yes, progress bar) |
| `--force` | Auto-yes all prompts (for `--clean`, `--all`, etc.) |
| `--verbose` | Show terminal output |
| `--dry-run` | Preview without changes |
| `--diff` | Compare embedded vs installed |
| `--verify` | Full verification (static + runtime) |
| `--verify-static` | Check config files |
| `--verify-runtime` | Check live state (after reboot) |
| `--lint` | Syntax and anti-pattern check |
| `--test-all` | Run all safe modes, generate log files (test suite) |
| `--status` | Quick system health dashboard (12 sections) |
| `--clean` | System cleanup — cache, journal, orphans (7 targets) |
| `--wifi-diag` | MT7925 WiFi diagnostics (10 sections) |
| `--export` | System report for sharing/troubleshooting (19 sections) |
| `--logs <target>` | View logs (system, gpu, wifi, boot, audio, usb, kernel, service) |
| `--diagnose` | Automated problem detection (23 checks) |
| `--uninstall` | Remove ry-install configs and unmask services |
| `--completions` | Install fish completions |
| `--no-color` | Disable colored output (also respects `NO_COLOR` env) |
| `--json` | Machine-readable JSON output (with `--diagnose`) |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

## Configuration Reference

### Kernel Parameters (15)

| Parameter | Purpose |
|-----------|---------|
| `amd_iommu=off` | Disable IOMMU (no VM passthrough needed) |
| `amd_pstate=active` | EPP mode for CPU frequency |
| `amdgpu.cwsr_enable=0` | Disable compute shader workload recovery |
| `amdgpu.modeset=1` | Enable kernel modesetting |
| `amdgpu.runpm=0` | Disable runtime power management |
| `audit=0` | Disable audit subsystem |
| `btusb.enable_autosuspend=n` | Prevent Bluetooth USB autosuspend |
| `mt7925e.disable_aspm=1` | Disable WiFi ASPM for stability |
| `nowatchdog` | Disable watchdog timers |
| `nvme_core.default_ps_max_latency_us=0` | Disable NVMe power saving |
| `pci=pcie_bus_perf` | Optimize PCIe bus for performance |
| `quiet` | Silent boot |
| `split_lock_detect=off` | Gaming performance (single-user only) |
| `usbcore.autosuspend=-1` | Disable USB autosuspend globally |
| `zswap.enabled=0` | Disable zswap (128GB RAM) |

### Environment Variables (4)

`AMD_VULKAN_ICD=RADV` (RADV Vulkan) · `MESA_SHADER_CACHE_MAX_SIZE=8G` · `PROTON_USE_NTSYNC=1` (kernel 6.14+) · `PROTON_NO_WM_DECORATION=1`

### Masked Services (10)

`ananicy-cpp` (conflicts with manual tuning) · `lvm2-monitor` (no LVM; skipped if detected) · `ModemManager` (no modem) · `NetworkManager-wait-online` (slows boot) · `scx_loader` (incompatible with BORE) · `sleep.target` (desktop stays on) · `suspend.target` (S0ix unreliable on Strix Halo) · `hibernate.target` · `hybrid-sleep.target` · `suspend-then-hibernate.target`

### Modprobe — Options (5)

| Module | Option | Purpose |
|--------|--------|---------|
| `amdgpu` | `ppfeaturemask=0xfffd7fff` | Disable GFXOFF (bit 15) and stutter mode (bit 17) for APU stability |
| `mt7925e` | `disable_aspm=1` | WiFi stability |
| `btusb` | `enable_autosuspend=n` | Bluetooth stability |
| `usbcore` | `autosuspend=-1` | USB device stability |
| `nvme_core` | `default_ps_max_latency_us=0` | NVMe performance |

### Modprobe — Blacklist (7)

`sp5100_tco` (AMD watchdog) · `snd_acp_pci` (silences ASoC errors) · `pcspkr` · `snd_pcsp` (PC speaker) · `floppy` · `ice` (E610 firmware lockup, NVM <1.30) · `simpledrm` (conflicts with amdgpu on Strix Halo)

### mkinitcpio

**Modules:** `amdgpu`, `nvme` — **Hooks:** `base` → `systemd` → `autodetect` → `microcode` → `modconf` → `kms` → `keyboard` → `sd-vconsole` → `block` → `filesystems` → `fsck` — **Compression:** `zstd` — `resume` omitted (sleep masked)

### Packages

**Added (12):** mkinitcpio-firmware, nvme-cli, iw, cachyos-gaming-meta, cachyos-gaming-applications, fd, sd, dust, procs, stress-ng, lm_sensors, pipewire-libcamera (`yay` added conditionally on CachyOS; `bat`, `eza`, `ripgrep`, `ethtool`, `plocate` are CachyOS defaults)

**Removed (8):** power-profiles-daemon, plymouth, cachyos-plymouth-bootanimation, ufw, octopi, micro, cachyos-micro-settings, btop

## Embedded Files (19)

| File | Purpose |
|------|---------|
| `/boot/loader/loader.conf` | systemd-boot config (timeout=0, editor=no) |
| `/etc/kernel/cmdline` | Kernel cmdline for kernel-install/bootctl fallback (dynamic root UUID) |
| `/etc/sdboot-manage.conf` | Kernel cmdline parameters |
| `/etc/mkinitcpio.conf` | Initramfs configuration |
| `/etc/modprobe.d/99-cachyos-modprobe.conf` | Module options and blacklist |
| `/etc/modules-load.d/99-cachyos-modules.conf` | Load ntsync at boot |
| `/etc/udev/rules.d/99-cachyos-udev.rules` | ntsync perms, USB autosuspend off |
| `/etc/environment` | Global environment variables |
| `/etc/systemd/journald.conf.d/99-cachyos-journald.conf` | Journal size cap (500M) and retention (2 weeks) |
| `/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf` | Coredump storage cap (500M) |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | Disable mDNS |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | Ignore power/suspend/hibernate/reboot buttons (5 keys) |
| `/etc/iwd/main.conf` | iwd for NetworkManager backend |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | iwd backend, powersave off |
| `/etc/conf.d/wireless-regdom` | Wireless regulatory domain |
| `~/.config/fish/conf.d/10-ssh-auth-sock.fish` | SSH agent socket (gpg-agent or ssh-agent) |
| `~/.config/environment.d/50-gaming.conf` | Gaming vars for systemd user services |
| `/etc/systemd/system/amdgpu-performance.service` | Set GPU to high performance |
| `/etc/systemd/system/cpupower-epp.service` | Set CPU governor and EPP to performance |

## Safety & Design

- **LVM detection** — skips masking `lvm2-monitor` if LVM found (including dry-run via `sudo -n`)
- **No auto-backup** — back up manually before running (see [Recovery](#recovery))
- **Restricted sudo** — `--all` aborts in preflight if unrestricted sudo unavailable
- **Boot rebuild** — `--all` aborts if `mkinitcpio` or `sdboot-manage gen` fails
- **Atomic writes** — temp file + mv; all configs syntax-validated before install
- **WiFi credentials** — not logged, connection file 0600
- **Non-interactive** — auto-declines prompts when stdin is not a terminal
- **Instance lock** — atomic mkdir prevents concurrent mutating runs
- **AMDGPU timing** — service-based fallback (Arch #72655)
- **Error tracking** — continues on non-critical failures, reports at end
- **No firewall** — `ufw` removed (conflicts with Steam/Proton); system relies on router NAT; users on public networks should install their own
- **Intentional params** — `amd_iommu=off` for gaming (see script comments for DMA tradeoffs); `audit=0` (no SELinux/AppArmor/auditd on CachyOS)
- **iwd** — required for NM backend; do NOT enable `iwd.service`; WiFi reconnect done last (backend switch may disconnect)
- **ananicy-cpp** — masked not removed (`cachyos-settings` dependency)

**Exit codes:** `0` success · `1` runtime error · `2` usage error · `130` interrupted (Ctrl+C)

## Known Limitations

- **AMD GPU only** — Intel/NVIDIA require modifications
- **ntsync** — kernel 6.14+ required; script warns if older
- **NM iwd backend** — experimental upstream; enterprise WPA (EAP), hidden SSIDs, some captive portals may fail; boot may show 1-2 connect failures before autoconnect recovers (~20s)
- **Intel E610 10GbE** — firmware lockup under GPU + network load (NVM <1.30); both ports share NVM and fail simultaneously; `ice` blacklisted until stable NVM
- **linux-firmware** — 20251125 breaks ROCm on gfx1151; use 20251111 or ≥20260110
- **sched-ext** — incompatible with BORE kernel; script disables scx_loader and stops active schedulers
- **Flatpak/Snap** — environment variables may not propagate; set in app overrides
- **Secure Boot** — not tested; may require signing custom kernels/modules
- **Single system** — optimized for GTR9 Pro; other hardware may need threshold adjustments

### Expected Warnings

Normal `dmesg`/`journalctl` noise — `--diagnose` already filters these as benign.

| Message | Source | Reason |
|---------|--------|--------|
| `invalid HE capabilities` | iwd (MT7925) | Unsupported HE caps from neighboring APs; WiFi works |
| `leaked proxy object` | WirePlumber | PipeWire session startup race; audio works |
| `GetKey … No such file or directory` | COSMIC | Settings key not yet created; defaults used |
| `HCI Enhanced Setup Synchronous Connection … rejected` | btusb | eSCO negotiation fallback; BT connections succeed |
| `Overdrive is enabled` | amdgpu | `ppfeaturemask=0xfffd7fff` exposes tuning knobs; informational |
| Kernel taint `S` (4) | kernel | Out-of-tree module (ZFS/nvidia on CachyOS); not instability |
| No fan sensor readings | lm_sensors | GTR9 Pro EC-controlled fans not exposed via hwmon |
| `No UUID available` / `old NGUID` | nvme | Drive lacks UUID field; identified by NGUID/serial instead |
| `deferred probe pending` | USB-C | UCSI waits for dependent drivers; resolves during boot |

### Configurable Thresholds

Constants at top of `ry-install.fish`: CPU temp 85/90°C (`TEMP_CPU_WARN/CRIT`) · GPU temp 85/95°C (`TEMP_GPU_WARN/CRIT`) · Root disk 80/90% (`DISK_ROOT_WARN/CRIT`) · Boot time 15/30s (`BOOT_TIME_TARGET/WARN`) · NVMe life 90% (`NVME_LIFE_WARN`) · Cache cleanup 100MB (`CACHE_CLEAN_THRESHOLD`) · Max logs 50 (`MAX_LOGS`). Pre-install: 2GB root / 200MB boot. Diagnose: ≥2GB journal. WiFi-diag: >5 band changes.

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

## Utilities

**`--status`** — System health (12 sections): system info, CPU/GPU temps, GPU perf/VRAM, CPU governor/EPP, services, gaming readiness, network/WiFi, memory, storage/NVMe, fans, power, scheduler.

**`--clean`** — Cleanup (7 targets): package cache (keep 2), journal (keep 7d), shader caches, orphans, old logs, coredumps, user cache. Supports `--dry-run`, `--all`, `--force`.

**`--wifi-diag`** — MT7925 diagnostics (10 sections): driver/chip, connection, signal, NM backend, errors, WiFi 7/MLO, firmware, regdom, capabilities, link-layer.

**`--export`** — System report (19 sections): system, hardware, GPU/CPU, cmdline, services, masked, network, WiFi, configs, pacman, packages, errors, boot, modules, block devices, mounts, PCI, temps. No passwords — safe for forums. Output: `~/ry-install/logs/YYYY-MM-DD/export-YYYYMMDD-HHMMSS.txt`

**`--diagnose`** — Problem detection (23 checks): hardware (temps, NVMe, topology, network), services (failed, expected), system (kernel errors, disk, journal, boot, taint, cmdline), compatibility (sched-ext, firmware, ppd), runtime (GPU/CPU, ntsync, OOM, coredumps, ZRAM). Optional stress tests. Exit: 0 = OK, 1 = issues (count in JSON/log).

**`--logs <target>`** — Targets: system, gpu, wifi, boot, audio, usb, kernel, or any service name.

**`--test-all`** — Run all safe modes, exit code = failure count.

## Recovery

### Manual Backup

```fish
# Before install — snapshot configs the script will overwrite
set -l backup_dir ~/ry-install-backup-(date +%Y%m%d-%H%M%S)
mkdir -p $backup_dir
for f in /etc/kernel/cmdline /etc/sdboot-manage.conf /etc/mkinitcpio.conf \
         /etc/modprobe.d/99-cachyos-modprobe.conf /etc/modules-load.d/99-cachyos-modules.conf \
         /etc/environment /etc/iwd/main.conf /etc/NetworkManager/conf.d/99-cachyos-nm.conf \
         /etc/conf.d/wireless-regdom /boot/loader/loader.conf \
         /etc/udev/rules.d/99-cachyos-udev.rules \
         /etc/systemd/journald.conf.d/99-cachyos-journald.conf \
         /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf \
         /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf \
         /etc/systemd/logind.conf.d/99-cachyos-logind.conf
    test -f $f; and sudo cp --parents $f $backup_dir/
end
echo "Backed up to $backup_dir"

# Restore a single file
sudo cp $backup_dir/etc/mkinitcpio.conf /etc/mkinitcpio.conf
sudo mkinitcpio -P; and sudo sdboot-manage update
```

### Uninstall / Restore

```fish
./ry-install.fish --uninstall           # Remove configs, unmask services
./ry-install.fish --uninstall --dry-run # Preview
```

Manual: restore file → rebuild (`sudo mkinitcpio -P`, `sudo sdboot-manage update`). Won't boot: CachyOS live USB → mount → `arch-chroot` → restore → rebuild.

## Troubleshooting

**GPU not at high performance** — `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` should show `high`; fix: `sudo systemctl enable --now amdgpu-performance.service`

**WiFi disconnects** — verify iwd backend: `nmcli -t -f TYPE,FILENAME connection show --active | grep wifi`; disable band steering in router if issues persist

**WiFi fails on boot then recovers** — "connect-failed, status: 15" and "Error loading .psk" are normal; iwd scans before NM is ready, autoconnect recovers ~20s. Persistent: `sudo rm /var/lib/iwd/SSID.psk`

**ntsync not available** — `uname -r` (requires 6.14+) · `zgrep CONFIG_NTSYNC /proc/config.gz` (should be y or m) · `ls -la /dev/ntsync` (should exist with rw perms)

**Boot issues after install** — see [Recovery](#recovery); live USB → mount → `arch-chroot` → restore → `mkinitcpio -P` → reboot

## License

MIT — `ry-install/` contains `LICENSE`, `README.md`, and `ry-install.fish` (self-contained, 19 configs + completions embedded).
