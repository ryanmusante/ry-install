# ry-install

Self-contained CachyOS configuration manager with profile support. Single Fish script, 15 embedded configs, no external dependencies.

**Default profile:** Beelink GTR9 Pro (Strix Halo APU). See [Hardware Reference](#hardware-reference).

[changelog](CHANGELOG.md)

## Table of Contents

- [Quick Start](#quick-start)
- [Scope](#scope)
- [Prerequisites](#prerequisites)
- [Hardware Reference](#hardware-reference)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Configuration Reference](#configuration-reference)
- [Managed Files](#managed-files)
- [Profiles](#profiles)
- [Safety & Reliability](#safety--reliability)
- [Uninstall](#uninstall)
- [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git && cd ry-install
./ry-install.fish              # Deploy everything (unattended)
```

**Post-install verification:**

1. Reboot — required for kernel cmdline, initramfs, NetworkManager backend switch.
2. `./ry-install.fish --verify-static` — confirms managed files match embedded content (catches manual edits, package overwrites).
3. `./ry-install.fish --verify-runtime` — confirms live kernel params, services, and modules are loaded as expected.
4. Smoke test: WiFi associates, a Vulkan game launches via Steam/Proton.

Typical first-run duration: **3–8 minutes** (depends on package mirror speed and initramfs rebuild).

> **BREAKING (v3.48.0):** Removed `--interactive`, `--dry-run`, `--all`, `--diff`, `--fix`, `--allow-root`, `--force`, and WiFi credential collection. `--all`, `--dry-run`, `--diff`, and `--fix` exit with a migration message; the others exit as unknown options. Unattended install is the only mode. Root execution is refused. See [CHANGELOG](CHANGELOG.md).

> **Installing over WiFi?** The NetworkManager backend switch (wpa_supplicant → iwd) is deferred until your next reboot to keep WiFi connectivity active during install. Reboot after install completes, or run `sudo systemctl restart NetworkManager` once on ethernet to apply immediately.

## Scope

**In scope:** system-wide CachyOS configuration (kernel cmdline, initramfs, systemd units, network stack, sysctl, gaming env vars), package install/remove via pacman + paru, masking of laptop power-management units for desktop use, single-user systemd `--user` units (ssh-agent, environment.d).

**Out of scope:** dotfiles, shell prompts, editor config, application settings, secrets/credentials management, backup orchestration, multi-user provisioning, non-CachyOS distributions, laptops without a custom profile (the default `gtr9_pro` profile masks all sleep/suspend targets).

## Prerequisites

| Requirement | Verification | Notes |
|---|---|---|
| CachyOS (systemd-boot, ext4) | — | Base assumption |
| Fish 3.4+ | `fish --version` | CachyOS ships 4.5 |
| Kernel 6.14+ | `uname -r` | ntsync, gfx1151 fixes |
| Unrestricted sudo | `sudo -l` → `(ALL) ALL` | Required (unattended install) |
| 2 GB root + 200 MB /boot free | `df -h / /boot` | Packages + initramfs |
| Network connectivity | `curl -sf --head https://archlinux.org` | Package sync |
| Current BIOS | [Beelink downloads](https://dr.bee-link.cn/) | P110+ for Strix Halo stability |
| paru (optional) | `command -q paru` | AUR package installation |

**Recommended pre-flight steps:**

```fish
./ry-install.fish --check        # silent idempotency probe (exit 0=clean, 3=prereq fail, 10=drift)
./ry-install.fish --lint         # syntax + anti-pattern check (no system changes)
sudo -v                          # warm sudo cache; confirms unrestricted sudo
df -h / /boot                    # verify space (≥2 GB / and ≥200 MB /boot)
```

Then review the [Masked Services](#masked-services) table — the default profile is **desktop-oriented** and masks all sleep/suspend targets. Laptop users must override `MASK` in a custom profile. Check [CachyOS news](https://wiki.cachyos.org) and [Arch news](https://archlinux.org/news/) for breaking changes before any `pacman -Syu`.

## Hardware Reference

| Component | Detail |
|---|---|
| BIOS | Latest available from Beelink (P110+ recommended for Strix Halo stability) |
| CPU | Ryzen AI Max+ 395 — Zen 5, 16C/32T, 5.1 GHz, 55 W default TDP (cTDP 45–120 W, Beelink: 140 W) |
| GPU | Radeon 8060S — RDNA 3.5, gfx1151, 40 CUs |
| RAM | 128 GB LPDDR5x-8000 |
| WiFi | MediaTek MT7925 (WiFi 7) |
| NIC | Dual Intel E610-XT2 10 GbE |
| Thermals | 85 °C sustained · 95 °C throttle · 100 °C max |

Check [Beelink](https://dr.bee-link.cn/) for BIOS updates, [kernel bugzilla](https://bugzilla.kernel.org) / [Mesa GitLab](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) for gfx1151 issues.

## Usage

| Flag | Description |
|---|---|
| (no args) | Unattended install (the only mode) |
| `-V, --verbose` | Show output on terminal |
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
| **Finalize** | Daemon-reload, cache cleanup, NM restart (deferred on active WiFi), write manifest |

## Configuration Reference

### Kernel Parameters

14 parameters written to `/etc/kernel/cmdline`:

| Parameter | Purpose |
|---|---|
| `amdgpu.cwsr_enable=0` | Disable CWSR — gfx1151 VGPR workaround (ROCm 7.2 userspace fix alone insufficient; kernel-mode fix not yet in mainline) |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Bits 14, 15, 17 off (overdrive / GFXOFF / stutter) |
| `clocksource=tsc` | Force TSC clocksource (prevents HPET demotion, ~10–100× lower read latency) |
| `initcall_blacklist=simpledrm_platform_driver_init` | Prevent simpledrm conflict |
| `amd_iommu=off` | Disable IOMMU (APU unified memory — ~2–6% iGPU bandwidth gain, no VFIO/passthrough) |
| `module_blacklist=pcspkr` | Silence PC speaker beep |
| `nowatchdog` | Disable software watchdog timers |
| `nvme_core.default_ps_max_latency_us=0` | Disable NVMe power states |
| `pcie_aspm.policy=performance` | PCIe ASPM L0 always (framework intact, per-device sysfs control preserved) |
| `quiet` | Suppress kernel boot messages |
| `split_lock_detect=off` | Disable split-lock #AC exception (gaming) |
| `threadirqs` | Force threaded IRQ handlers (lower worst-case latency) |
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
| `sysctl.d` | BBR+fq · tcp_fastopen=3 · 10 GbE buffer tuning · vm.max_map_count=max · watermark tuning · security hardening (17 net-new tunables, supplements CachyOS vendor 70-cachyos-settings.conf; net.core.netdev_max_backlog overrides vendor 4096→16384) |
| `/etc/fstab` | Adds `noatime,lazytime` to ext4 entries (modified in-place, not a managed file) |

### Environment Variables

| Variable | Value |
|---|---|
| `DXVK_LOG_LEVEL` | `none` |
| `DXVK_LOG_PATH` | `none` |
| `ENABLE_LAYER_MESA_ANTI_LAG` | `1` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_USE_NTSYNC` | `1` (default in current proton-cachyos; explicit pin) |
| `RADV_PERFTEST` | `transfer_queue` |
| `VKD3D_CONFIG` | `transfer_queue` |
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
| **Install** | 12 | mkinitcpio-firmware, nvme-cli, iw, cachyos-gaming-meta, cachyos-gaming-applications, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove** | 8 | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, ufw, octopi, micro, cachyos-micro-settings, btop |
| **AUR** | 1 | mt76-mt7925-dkms (via paru — **skipped with WARN if paru is not installed**; install continues) |

### Masked Services

10 units masked — **review before running on laptops:**

| Service | Reason |
|---|---|
| `ananicy-cpp.service` | Manual tuning preferred |
| `irqbalance.service` | Conflicts with threadirqs |
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

External profiles define `function _ry_profile_<name>` with all required globals (26 unconditional + up to 8 conditional). Legacy `profile_<name>` naming is accepted with a deprecation warning. Profiles are syntax-checked before sourcing; validation enforces name consistency and numeric types.

**Creating a profile:**

```fish
echo my_desktop > ~/.config/ry-install/default-profile
```

### Required Globals

A profile must define **26 unconditional globals**, plus **8 conditional globals** activated by the presence of corresponding entries in `SYSTEM_DESTINATIONS`. Preflight reports any missing ones with the variable name.

| Category | Globals |
|---|---|
| Identity | `PROFILE_NAME`, `PROFILE_DESC` |
| Destinations | `SYSTEM_DESTINATIONS`, `USER_DESTINATIONS`, `SERVICE_DESTINATIONS` |
| Kernel + initramfs | `KERNEL_PARAMS`, `MKINITCPIO_MODULES`, `MKINITCPIO_HOOKS`, `MKINITCPIO_COMPRESSION` |
| Boot loader | `LOADER_DEFAULT`, `LOADER_TIMEOUT`, `LOADER_CONSOLE_MODE`, `LOADER_EDITOR`, `SDBOOT_DEFAULT_ENTRY`, `SDBOOT_OVERWRITE`, `SDBOOT_REMOVE_EXISTING`, `SDBOOT_REMOVE_OBSOLETE` |
| Packages + services | `PKGS_ADD`, `MASK`, `EXPECTED_SERVICES` |
| Environment | `ENV_VARS`, `LOGIND_IGNORE_KEYS` |
| Thresholds | `BOOT_SPACE_CRIT`, `BOOT_SPACE_WARN`, `ROOT_AVAIL_CRIT`, `ROOT_AVAIL_WARN` |

**Conditional globals** (required only when the matching destination is present):

| Triggered by destination match | Required globals |
|---|---|
| `*/iwd/*` | `IWD_ENABLE_NETWORK_CONFIG`, `IWD_DRIVER_QUIRKS`, `IWD_DNS_SERVICE` |
| `*nm.conf` | `NM_WIFI_BACKEND`, `NM_WIFI_POWERSAVE`, `NM_LOG_LEVEL` |
| `*/resolved.conf.d/*` | `RESOLVED_MDNS` |
| `*/sysctl.d/*` | `SYSCTL_VALUES` |

**Optional globals** (consumers handle unset safely): `PKGS_DEL`, `AUR_PKGS`, `BOOT_TIME_TARGET`, `EXPECTED_CPU_MATCH`, `MKINITCPIO_COMPRESSION_OPTIONS`.

### Example Profile

Save as `~/.config/ry-install/profiles/my_desktop.fish`:

```fish
function _ry_profile_my_desktop --description "Example desktop profile"
    set -g PROFILE_NAME my_desktop
    set -g PROFILE_DESC "My Desktop — AMD Ryzen 7 7800X3D / RX 7900 XTX"

    # Copy SYSTEM_DESTINATIONS / USER_DESTINATIONS / SERVICE_DESTINATIONS
    # from the built-in gtr9_pro profile and adjust paths as needed.
    # Then define the 26 unconditional + applicable conditional globals
    # listed in the Required Globals tables above.
end
```

Validate before first use:

```fish
./ry-install.fish --verify-static    # check profile/manifest sanity
./ry-install.fish --verify-runtime   # check live system state
```

### Profile Trust Model

External profiles in `~/.config/ry-install/profiles/<name>.fish` are loaded via `source` and execute with the user's privileges. Treat profile files like any other shell script you would run:

- Only use profiles from sources you trust.
- Verify ownership: `stat -c '%U' ~/.config/ry-install/profiles/*.fish` should show your username, not root or any other user.
- The script does not sandbox profile execution; a malicious profile can do anything your user account can do.

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → chmod → mv (same filesystem) |
| fstab edits | Idempotent (skipped if `noatime,lazytime` already present); validated via `findmnt --verify` before atomic move; **no persistent backup written** — snapshot `/etc/fstab` yourself before first run if you want recovery |
| Root detection | **Refuses to run as root.** Run as your normal user; sudo is invoked internally. |
| Instance lock | Atomic mkdir, PID verification, stale reclaim |
| Credentials | Sensitive args redacted in logs (9 patterns: `--passphrase`, `--password`, `--token`, `--key`, etc.) |
| Signal handling | INT/TERM/HUP/QUIT → 128+signum; SIGPIPE → 141 |
| Logging | NDJSON to `~/ry-install/logs/YYYY-MM-DD/*.jsonl` |
| Boot safety | Abort on initramfs or bootloader rebuild failure |
| LVM-aware | Skips lvm2-monitor mask when LVM detected |
| Orphan tracking | Manifest warns on version or profile change |

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Non-critical failure / verification drift (`--verify-static`, `--verify-runtime`) |
| `2` | Usage error |
| `3` | Preflight failed (also `--check` prereq failure) |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | Drift (`--check`) |
| `11` | Lint errors |
| `129/130/131/143` | Signal (HUP / INT / QUIT / TERM) |
| `141` | SIGPIPE |

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
| `header` | version, profile, mode, verbose, command | Run start |
| `footer` | exit_code, pass, fail, warn, interrupted | Run end |
| `ok` | data | Verification pass |
| `fail` | data | Verification failure |
| `warn` | data | Non-fatal issue |
| `err` | data | Blocking error |
| `step_time` | data, elapsed_s | Install step completed |
| `run` | data | Command executed |
| `stderr` | data | Captured stderr |
| `section` | data | Phase boundary |

Query with jq: `jq 'select(.event == "fail")' ~/ry-install/logs/**/*.jsonl`

<details>
<summary>Sample log output</summary>

```json
{"ts":"2026-04-08T14:23:01-0700","event":"header","version":"3.48.12","profile":"gtr9_pro","mode":"install","verbose":false,"command":"./ry-install.fish"}
{"ts":"2026-04-08T14:23:04-0700","event":"section","data":"Preflight"}
{"ts":"2026-04-08T14:23:12-0700","event":"step_time","data":"Packages","elapsed_s":127.4}
{"ts":"2026-04-08T14:25:19-0700","event":"warn","data":"paru not found — skipping AUR packages: mt76-mt7925-dkms"}
{"ts":"2026-04-08T14:26:42-0700","event":"footer","exit_code":0,"pass":47,"fail":0,"warn":1,"interrupted":false}
```

</details>

## Uninstall

ry-install does **not** ship an automated uninstaller. The script tracks deployed files in `~/ry-install/.manifest` — use it as the source of truth for manual rollback.

**Manual rollback steps:**

```fish
# 1. Unmask the 10 systemd units
sudo systemctl unmask \
    ananicy-cpp.service irqbalance.service power-profiles-daemon.service \
    lvm2-monitor.service NetworkManager-wait-online.service \
    sleep.target suspend.target hibernate.target hybrid-sleep.target \
    suspend-then-hibernate.target

# 2. Disable + remove the cpupower-epp unit
sudo systemctl disable --now cpupower-epp.service
sudo rm /etc/systemd/system/cpupower-epp.service

# 3. Remove managed config files (see Managed Files table for full list)
sudo rm /etc/kernel/cmdline /etc/sdboot-manage.conf /etc/mkinitcpio.conf \
    /etc/systemd/resolved.conf.d/99-cachyos-resolved.conf \
    /etc/systemd/logind.conf.d/99-cachyos-logind.conf \
    /etc/systemd/coredump.conf.d/99-cachyos-coredump.conf \
    /etc/iwd/main.conf /etc/NetworkManager/conf.d/99-cachyos-nm.conf \
    /etc/drirc /etc/sysctl.d/99-cachyos-sysctl.conf
rm ~/.config/fish/conf.d/10-ssh-auth-sock.fish \
   ~/.config/environment.d/10-environment.conf \
   ~/.config/systemd/user/ssh-agent.service

# 4. Restore /etc/fstab from your own snapshot (no persistent backup is written by ry-install)
#    Or manually remove "noatime,lazytime" from ext4 entries.

# 5. Restore removed packages if desired
sudo pacman -S --needed plymouth cachyos-plymouth-bootanimation cachyos-plymouth-theme \
    ufw octopi micro cachyos-micro-settings btop

# 6. Rebuild initramfs and bootloader entries
sudo mkinitcpio -P
sudo sdboot-manage gen

# 7. Remove ry-install state
rm -rf ~/ry-install/

# 8. Reboot
```

**Note:** Packages installed by ry-install (`PKGS_ADD`) are not auto-removed; use `pacman -Rns` selectively if desired. AUR `mt76-mt7925-dkms` removal: `paru -Rns mt76-mt7925-dkms`.

## Known Issues

### Strix Halo GPU (gfx1151)

| Issue | Status | Workaround |
|---|---|---|
| CWSR hang — incorrect VGPR count (`cf326449637a5`), compute-only | Userspace fix in ROCm 7.2; kernel-mode fix not yet in mainline | `amdgpu.cwsr_enable=0` (still required) |
| MES page faults | Specific firmware revisions affected | Pin a known-good `linux-firmware` version if encountered |
| ROCm VRAM allocation | Fixed in kernel 6.16+ | GTT handled automatically — no `ttm.pages_limit` or `amdgpu.gttsize` needed |
| PSR freeze (eDP only) | Open | `amdgpu.dcdebugmask=0x10` (not needed for HDMI/DP) |
| Black screen | Reported kernel-version-specific regressions | Track linux-cachyos changelog; downgrade or upgrade as advised |
| ROCm compute | Requires env vars | `HSA_ENABLE_SDMA=0` and `HSA_OVERRIDE_GFX_VERSION=11.5.1` |

### MediaTek MT7925 WiFi

| Issue | Status | Workaround |
|---|---|---|
| Kernel panics (NULL deref in `mt792x_mac_reset_work`) | Driver bug | `paru -S mt76-mt7925-dkms` |
| TX power reported as 3 dBm | Cosmetic — actual TX follows regulatory limits; kernel patches pending | Consider Intel AX210/AX211 if signal issues persist |
| Random deauthentication | Intermittent | None — consider Intel AX210/AX211 |

### NetworkManager + iwd

| Issue | Workaround |
|---|---|
| Boot connectivity failure | `nmcli radio wifi off && nmcli radio wifi on` |
| WPA2/3 Enterprise GUI broken with iwd | Use CLI or switch to wpa_supplicant |
| Monitor mode requires full reboot | Reboot |

## Troubleshooting

| Problem | Diagnostic / Fix |
|---|---|
| GPU perf level stuck | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend mismatch | `nmcli -t -f TYPE,FILENAME connection show --active` (expect `iwd`) |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| FSR4 on RDNA 3.5 | Per-game: `PROTON_FSR4_RDNA3_UPGRADE=1 %command%` (proton-cachyos / GE-Proton 10-9+) |
| Profile load failure | `./ry-install.fish --check` reports missing globals; verify file ownership: `stat -c '%U' ~/.config/ry-install/profiles/*.fish` |
| Stale lock | `rm -rf ~/ry-install/.lock/` (only if no other ry-install process is running: `pgrep -af ry-install`) |
| Manifest version mismatch | Expected after upgrade — script warns but does not block; re-run install to refresh manifest |
| AUR pkg not installed | `command -q paru; or sudo pacman -S --needed paru` then re-run install |
| Sudo cache expiry mid-run | Re-run with fresh sudo: `sudo -v && ./ry-install.fish` |
| `drirc` XML rejected by Mesa | `cat /etc/drirc` and validate with `xmllint --noout /etc/drirc` |
| `--verify-static` reports drift | Re-deploy single file: `./ry-install.fish --install-file /etc/...` |

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

[MIT](LICENSE)
