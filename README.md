# ry-install

[![version](https://img.shields.io/badge/version-5.0.15-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46.svg)](https://fishshell.com/)
[![kernel](https://img.shields.io/badge/kernel-%E2%89%A5%206.14%20%286.18.4%2B%20rec.%29-orange.svg)](https://www.kernel.org/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
![license](https://img.shields.io/badge/license-MIT-green.svg)

> Self-contained CachyOS configuration manager. Single Fish script, 12 embedded configs,
> no required external dependencies (paru required for AUR packages:
> `mkinitcpio-firmware`, `mt76-mt7925-dkms`).

**Target system:** Beelink GTR9 Pro (Strix Halo APU). See [Hardware Reference](#hardware-reference).

---

## Table of Contents

- [Quick Start](#quick-start)
- [Scope](#scope)
- [Prerequisites](#prerequisites)
- [Hardware Reference](#hardware-reference)
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
- [Customization](#customization)
- [Safety & Reliability](#safety--reliability)
    - [Exit Codes](#exit-codes)
    - [Runtime Variables](#runtime-variables)
    - [Data Directory & Logs](#data-directory-logs)
- [Uninstall](#uninstall)
- [Known Issues](#known-issues)
    - [Strix Halo GPU](#known-issues-gfx1151)
    - [MediaTek MT7925](#known-issues-mt7925)
    - [NetworkManager + iwd](#known-issues-nm-iwd)
    - [Progress bar under mosh](#known-issues-mosh)
    - [Sudo keepalive failed to start](#known-issues-keepalive)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [License](#license)

---

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # Deploy everything (unattended)
```

> [!TIP]
> If you cannot set the executable bit, invoke the interpreter directly: `fish ry-install.fish`.

**Post-install verification:**

1. Reboot — required for kernel cmdline, initramfs, NM backend switch.
2. `./ry-install.fish --verify-static` — managed files match embedded content.
3. `./ry-install.fish --verify-runtime` — live kernel params, services, modules.
4. Smoke test: WiFi associates, a Vulkan game launches via Steam/Proton.

Typical first-run duration: **3–8 minutes**.

> [!NOTE]
> **Over WiFi:** the NM backend switch (wpa_supplicant → iwd) is deferred to next reboot.
> **On ethernet:** `sudo systemctl restart NetworkManager` applies it immediately.

> [!IMPORTANT]
> Initramfs rebuild aborts when on-disk package state or boot-critical configs
> (`/etc/mkinitcpio.conf`, `/etc/kernel/cmdline`, `/boot/loader/loader.conf`,
> `/etc/sdboot-manage.conf`) may be inconsistent with embedded content.
> Service-runtime failures are warn-only and don't gate the rebuild.
> Override after manual remediation: `RY_INSTALL_FORCE_BOOT_REBUILD=1` (literal `1` only).

## Scope

**In scope:** system-wide CachyOS configuration (kernel cmdline, initramfs, systemd units,
network stack, sysctl, gaming env vars), package install/remove via pacman + paru,
masking of laptop power-management units for desktop use, single-user systemd `--user` units.

**Out of scope:** dotfiles, shell prompts, editor config, secrets management,
backup orchestration, multi-user provisioning, non-CachyOS distros, laptops
(script masks all sleep/suspend targets).

## Prerequisites

| Requirement | Detail |
|---|---|
| CachyOS | systemd-boot, ext4 |
| Fish | ≥ 3.6 (≥ 4.0 recommended) |
| Kernel | ≥ 6.14 (≥ 6.18.4 for gfx1151) |
| Systemd | ≥ 250 (advisory; older versions warn, install proceeds; ≥ 256 enables `HandleSecureAttentionKey`) |
| Sudo | Unrestricted — no `requiretty`, `tty_tickets`, or `timestamp_timeout=0` |
| Coreutils | GNU `sort -z`, `stat -c`, `find -printf`, `df --output`, `timeout` |
| Free space | 2 GB on `/`, 200 MB on `/boot` |
| Network | `curl` required |
| paru | Required, for AUR (`mkinitcpio-firmware`, `mt76-mt7925-dkms`) |

```fish
./ry-install.fish --check        # idempotency probe
sudo -v                          # warm sudo cache
df -h / /boot                    # verify space
```

Review [Masked Services](#masked-services) before running on laptops.
Check [CachyOS](https://wiki.cachyos.org) and [Arch news](https://archlinux.org/news/) before any `pacman -Syu`.

## Hardware Reference

Kernel parameters and tuning values are calibrated for the components below.
Other hardware requires editing the `# === GTR9_PRO BUILT-IN DEFAULTS ===` block at the top of `ry-install.fish`.

| Component | Detail |
|---|---|
| CPU | Ryzen AI Max+ 395 (Zen 5, 16C/32T, gfx1151 iGPU) |
| GPU | Radeon 8060S (RDNA 3.5, 40 CUs) |
| RAM | 128 GB LPDDR5x-8000 |
| WiFi | MediaTek MT7925 (WiFi 7) |
| NIC | Dual Intel E610-XT2 10 GbE |
| BIOS | P110+ — [Beelink downloads](https://dr.bee-link.cn/) |

Track [kernel bugzilla](https://bugzilla.kernel.org) and
[Mesa gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) for regressions.

## Usage

All modes are non-interactive. Verification flags are read-only.

| Flag | Description |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show output for install/check (silent by default; verify-* and `--install-file` are always verbose) |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--check` | Silent idempotency probe (exit 0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy a single managed file (absolute path required; use `--install-file=<path>` for paths starting with `-`) |
| `--` | End of options. Anything after `--` is treated as a positional and rejected with exit 2. `-h`/`--help` and `-v`/`--version` *before* `--` are still honoured. |
| `-h, --help` / `-v, --version` | Help / version |

## Install Flow

Six sequential phases — boot-critical failures abort immediately:

```
Preflight → Packages → Configuration → Services → Boot → Finalize
```

| Phase | Description |
|---|---|
| **Preflight** | Validate prerequisites, acquire lock, validate runtime |
| **Packages** | `pacman -Syu --needed`; opt-in `-Sy` via `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1`; AUR via paru |
| **Configuration** | Deploy all 12 embedded config files (atomic writes; system + service units + user) |
| **Services** | `daemon-reload`; enable cpupower-epp / fstrim.timer / NM-dispatcher; mask 10 desktop/power units (`lvm2-monitor` auto-skipped under LVM) |
| **Boot** | Rebuild initramfs (gated on no-prior-errors), update systemd-boot entries |
| **Finalize** | Cache cleanup, NM restart (deferred on active WiFi) |

## Configuration Reference

All values are embedded in the script and deployed via the paths in [Managed Files](#managed-files).
To retune, edit the inlined defaults block at the top of `ry-install.fish`.

### Kernel Parameters

15 params written to `/etc/kernel/cmdline`, plus implicit `rw` and `root=UUID=…`.

<a id="kernel-parameters-list"></a>
<details>
<summary><b>Show parameter table (15)</b></summary>

| Parameter | Purpose |
|---|---|
| `amd_pstate=active` | Force amd_pstate_epp (Zen 5 native CPPC) |
| `amdgpu.cwsr_enable=0` | gfx1151 VGPR workaround |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Disable overdrive / GFXOFF / stutter |
| `iommu=pt` | IOMMU passthrough |
| `loglevel=3` | Suppress kernel info/notice at boot |
| `module_blacklist=pcspkr` | Silence PC speaker |
| `nowatchdog` | Disable software watchdog |
| `pcie_aspm.policy=performance` | PCIe ASPM L0 (desktop only) |
| `quiet` | Suppress kernel boot messages |
| `rd.systemd.show_status=auto` | Initramfs status on errors only |
| `rd.udev.log_level=3` | Suppress udev info/debug in initramfs |
| `split_lock_detect=off` | Disable split-lock #AC (gaming) |
| `tsc=reliable` | Bypass TSC watchdog (Zen 5 invariant) |
| `usbcore.autosuspend=-1` | Disable USB autosuspend |
| `zswap.enabled=0` | Disable zswap (ZRAM in use) |

</details>

> [!NOTE]
> Single value per parameter. Comma-separated multi-value lists are not supported by the verifier.

### Boot Loader

systemd-boot + sdboot-manage. `editor no` blocks live cmdline tampering; `timeout 0` boots saved entry immediately.

| File | Setting |
|---|---|
| `loader.conf` | default=@saved, timeout=0, console-mode=keep, editor=no |
| `sdboot-manage.conf` | DEFAULT_ENTRY=manual; REMOVE/OVERWRITE/REMOVE_OBSOLETE=yes |

### Initramfs

| Setting | Value |
|---|---|
| Modules | `amdgpu` (forced; bypasses autodetect) |
| Hooks | `base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck` |
| Compression | `zstd -1 -T0` |

> [!IMPORTANT]
> `mkinitcpio -P` is skipped when package install or a boot-critical config deploy
> (`mkinitcpio.conf` / `kernel/cmdline` / `loader.conf` / `sdboot-manage.conf`) failed.
> Service-runtime `--now` start failures are warn-only and don't gate the rebuild.
> Override: `RY_INSTALL_FORCE_BOOT_REBUILD=1`.

### System Services

| Unit | Purpose |
|---|---|
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` |
| `fstrim.timer` | Weekly TRIM (system-pre-existing; enabled here) |
| `NetworkManager.service` | Pre-enabled by CachyOS base install (verified active+enabled post-install; verify-runtime warns "not installed" if absent) |

Implicit units enabled by deployed conf.d files:
`systemd-resolved.service` (via `resolved.conf.d`),
`NetworkManager-dispatcher.service` (via `NetworkManager/conf.d`).

`power-profiles-daemon` is masked separately ([Masked Services](#masked-services)) to prevent EPP conflicts.

### Network Stack

WiFi locked to iwd backend (NM) with power-save off — required for MT7925 stability. DNS via systemd-resolved.

| File | Setting |
|---|---|
| `resolved.conf.d` | MulticastDNS=resolve, LLMNR=no, DNSOverTLS=opportunistic, DNSSEC=allow-downgrade |
| `iwd/main.conf` | EnableNetworkConfiguration=false, DriverQuirks=`PowerSaveDisable=*`, NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd, wifi.powersave=2, wifi.iwd.autoconnect=false |

> [!NOTE]
> If `iwd` is missing at install-time, both `iwd/main.conf` and
> `NetworkManager/conf.d/99-cachyos-nm.conf` are skipped — deploying `wifi.backend=iwd`
> against an absent backend would leave NM unable to associate.
> Install first: `sudo pacman -S --needed iwd`, then re-run.

### System Tuning

`/etc/fstab` is the only path modified outside the checksum pipeline (still atomic).

| File | Setting |
|---|---|
| `logind.conf.d` | Ignore 9 power/suspend/reboot key events (8 on systemd 252–255 — `HandleSecureAttentionKey` needs ≥256) |
| `drirc` | RADV unified VRAM heap (APU) |
| `sysctl.d` | BBR+fq, tcp_fastopen=3, 10 GbE buffers, 16 tunables |
| `/etc/fstab` | `noatime,lazytime,commit=10` on ext4 |

### Environment Variables

10 vars in `~/.config/environment.d/10-environment.conf`. Debug logging silenced by default.

<a id="environment-variables-list"></a>
<details>
<summary><b>Show 10 environment variables</b></summary>

| Variable | Value |
|---|---|
| `DXVK_LOG_LEVEL` / `DXVK_LOG_PATH` | `none` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` (experimental; breaks Steam Overlay) |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_USE_NTSYNC` | `1` |
| `RADV_PERFTEST` | `sam,nircache,transfer_queue` |
| `VKD3D_DEBUG` / `VKD3D_SHADER_DEBUG` | `none` |
| `WINEDEBUG` | `-all` |

</details>

<a id="per-game-overrides"></a>
<details>
<summary><b>Per-game overrides (Steam launch options)</b></summary>

| Variable | Use case |
|---|---|
| `MESA_VK_WSI_PRESENT_MODE=mailbox` | Latency-sensitive titles under Wayland (breaks vsync) |
| `PROTON_FSR4_RDNA3_UPGRADE=1` | Force FSR4 on gfx1151 |

Deprecated — do not re-introduce: `DXVK_ASYNC`, `DXVK_FRAME_RATE`, `WINE_FULLSCREEN_FSR`,
`DISABLE_LAYER_MESA_ANTI_LAG`, `ENABLE_LAYER_MESA_ANTI_LAG`, `PROTON_NO_WM_DECORATION`.
(`VKD3D_FRAME_RATE` is **retained** — still valid.)

</details>

### User Configuration

| File | Purpose |
|---|---|
| `environment.d/10-environment.conf` | Env vars for systemd user services |

### Packages

Default: `pacman -Syu --needed` per Arch's
[no-partial-upgrade policy](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported).

> [!CAUTION]
> `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` switches the Packages phase to `pacman -Sy --needed`
> (refresh + install only, no upgrade). Violates Arch's no-partial-upgrade policy —
> accept the dependency-skew risk.

> [!NOTE]
> A `PKGS_DEL` removal is skipped when an installed package outside the set
> reverse-depends on it. Cascade with `RY_INSTALL_PKG_REMOVE_CASCADE=1`
> (target + rdeps to one `pacman -Rns`). Inspect first: `pactree -ru <pkg>`.

| Action | Count | Packages |
|---|---|---|
| **Install** | 13 | nvme-cli, cachyos-gaming-meta, cachyos-gaming-applications, mesa, lib32-mesa, fd, sd, dust, procs, bottom, htop, git-delta, lm_sensors |
| **Remove** | 7 | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, octopi, micro, cachyos-micro-settings, btop |
| **AUR** | 2 | mkinitcpio-firmware, mt76-mt7925-dkms (paru required; soft-fail if absent) |

### Masked Services

10 units masked — **review before laptop use:**

<a id="masked-services-list"></a>
<details>
<summary><b>Show masked services (10)</b></summary>

| Service | Reason |
|---|---|
| `ananicy-cpp.service` | Manual tuning preferred |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `ufw.service` | Firewall not used; mask survives `ufw` install/removal |
| `sleep.target` / `suspend.target` / `hibernate.target` / `hybrid-sleep.target` / `suspend-then-hibernate.target` | Desktop — no power management |

</details>

## Managed Files

12 files deployed via atomic writes (tmp → symlink-check → chmod → `mv -T`).

<a id="managed-files-list"></a>
<details>
<summary><b>Show all 12 destinations</b></summary>

| Scope | Path |
|---|---|
| System | `/boot/loader/loader.conf` |
| System | `/etc/kernel/cmdline` |
| System | `/etc/sdboot-manage.conf` |
| System | `/etc/mkinitcpio.conf` |
| System | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` |
| System | `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| System | `/etc/iwd/main.conf` |
| System | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` |
| System | `/etc/drirc` |
| System | `/etc/sysctl.d/99-cachyos-sysctl.conf` |
| Service | `/etc/systemd/system/cpupower-epp.service` |
| User | `~/.config/environment.d/10-environment.conf` |

</details>

## Customization

Edit the `# === GTR9_PRO BUILT-IN DEFAULTS ===` block at the top of `ry-install.fish`.
Re-run `--verify-static` after changes.

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → post-mktemp symlink check → chmod → `mv -T`; parent must be root/self-owned, not symlinked, not group/world-writable |
| Permissions | system 0644 · user 0600 · `~/ry-install/` 0700 · logs 0600; user-scope `mkdir` runs under `umask 0077` |
| fstab | Idempotent; `findmnt --verify` before write; symlink rejected. **No backup — snapshot first.** |
| Boot rebuild gate | `mkinitcpio -P` skipped when package install or boot-critical config deploy failed (`_RY_BOOT_TAINTED`). Override: `RY_INSTALL_FORCE_BOOT_REBUILD=1` |
| Boot-wipe gate | Auto-acks when every entry maps to a `vmlinuz-*`; foreign entries refuse. Override: `RY_INSTALL_CONFIRM_BOOT_WIPE=1` |
| Pacnew handling | `.pacnew` at managed paths re-deploys + removes; `.pacsave` warn-only |
| KERNEL_PARAMS hygiene | Preflight rejects whitespace or `"` in any param |
| Sysctl invariant | Generator returns rc 13 if printed lines ≠ `count $SYSCTL_VALUES` |
| Subprocess control | `_run` uses `timeout --foreground`; `_do_cleanup` reaps via `pkill -P` |
| Stderr surfacing | First 5 stderr lines mirror to fd 2 on rc≠0 (even under `QUIET=true`); `--verbose` mirrors full stderr then full stdout |
| Root detection | Refuses to run as root; sudo invoked internally |
| Instance lock | Atomic mkdir + `flock(1)` stale reclaim |
| Re-source guard | `_RY_INSTALL_LOADED` blocks double-source per session |
| Credentials | 15 lowercase secret-flag patterns redacted in logs |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT → 128+signum; SIGPIPE handled non-fatally (JSONL log canonical) |
| mkinitcpio rollback | Pre-deploy snapshot to tracked tmpfile (`/etc/.ry-install.mki-backup.*`); restored byte-exact on `pacman -Syu` failure. Skipped on sudo lapse (`MKINITCPIO_BACKUP_SKIPPED`). Snapshot tmpfile is removed on install success and on signal/cleanup. |
| Log integrity | NDJSON to `~/ry-install/logs/YYYY-MM-DD/*.jsonl`; single-writer guard; rotation-race self-heal |

<a id="exit-codes"></a>
<details>
<summary><b>Exit Codes</b></summary>

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Non-critical failure / verification drift / old-kernel preflight warn |
| `2` | Usage error (argparse + policy refusals) |
| `3` | Preflight failed |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | Drift (`--check` only) |
| `129/130/131/143` | Signal (HUP / INT / QUIT / TERM) |
| `134/138/140` | Signal (ABRT / USR1 / USR2) |

</details>

<a id="runtime-variables"></a>
<details>
<summary><b>Runtime Variables</b></summary>

| Variable | Default | Purpose |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | Per-`_run` wall-clock cap (seconds). Accepts any non-negative integer (leading zeros tolerated); `0` disables. |
| `RY_INSTALL_CONFIRM_BOOT_WIPE` | unset | Literal `=1` to ack boot-entry wipe (override; auto-ack passes when every entry maps to a `vmlinuz-*`). Persisted in `~/ry-install/.boot-wipe-acknowledged`; re-prompts on entry-set hash change. |
| `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` | unset | Literal `=1` switches Packages phase to `pacman -Sy --needed` (no system upgrade). Violates Arch policy. |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | Literal `=1` required to bypass torn-package gate. Recovery only. |
| `RY_INSTALL_PKG_REMOVE_CASCADE` | unset | Literal `=1` cascades installed reverse deps into the removal set when a `PKGS_DEL` package is blocked. Default skips with warn. |
| `NO_COLOR` | unset | Suppress ANSI color when set (any value, including empty; per [no-color.org](https://no-color.org/)). Auto on `TERM=dumb` / non-TTY. |

> Secret-flag redaction is **case-sensitive lowercase**. Use lowercase flag names with `_run`-piped commands.

</details>

<a id="data-directory-logs"></a>
<details>
<summary><b>Data Directory & Logs</b></summary>

All runtime state under `~/ry-install/`. Logs auto-prune at `MAX_LOGS=50`
(oldest first; `*.jsonl` and `*.log` under `~/ry-install/logs/`).

| Path | Contents |
|---|---|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON logs (`*.jsonl`) |
| `~/ry-install/.lock/` | Instance guard (atomic mkdir) |
| `~/ry-install/.lock-broker` | flock(1) target for stale-lock reclaim (scoped to ry-install) |
| `~/ry-install/.boot-wipe-acknowledged` | Boot-wipe ack marker (entry-set hash; refreshed on every successful rebuild) |

NDJSON schema: `{"ts":ISO8601,"event":NAME,"data":STR,...}`.
Common events: `header`, `footer`, `ok`/`fail`/`warn`/`err`/`info`, `run`, `stderr`, `section`.
Prefix-routed types (`BOOT_*`, `CHECK_*`, `MKINITCPIO_*`, `PKG_REMOVE_*`, `SUDO_*`, `VERIFY_*`)
follow the same schema.

```fish
jq 'select(.event == "fail")' ~/ry-install/logs/**/*.jsonl
```

</details>

## Uninstall

No automated uninstaller. Use [Managed Files](#managed-files) as the rollback source-of-truth:
unmask units, `rm` deployed paths, restore `/etc/fstab` from your snapshot,
optionally `pacman -S`/`-Rns` to reverse package changes,
then `mkinitcpio -P && sdboot-manage gen` and reboot.

## Known Issues

<a id="known-issues-gfx1151"></a>
<details>
<summary><b>Strix Halo GPU (gfx1151)</b></summary>

| Issue | Workaround |
|---|---|
| CWSR hang | `amdgpu.cwsr_enable=0` (already set) |
| MES page faults | Avoid `linux-firmware-20251125` for ROCm; pin ≤ `20250808-1` or use `amdgpu-dkms-firmware` |
| ROCm VRAM allocation | Fixed in kernel 6.16+ |
| PSR freeze (eDP) | `amdgpu.dcdebugmask=0x10` |
| ROCm compute | `HSA_ENABLE_SDMA=0`, `HSA_OVERRIDE_GFX_VERSION=11.5.1` |

</details>

<a id="known-issues-mt7925"></a>
<details>
<summary><b>MediaTek MT7925 WiFi</b></summary>

| Issue | Workaround |
|---|---|
| Kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| TX power reported as 3 dBm | None (cosmetic) |
| Random deauthentication | None |

</details>

<a id="known-issues-nm-iwd"></a>
<details>
<summary><b>NetworkManager + iwd</b></summary>

| Issue | Workaround |
|---|---|
| Boot connectivity failure (intermittent) | `nmcli radio wifi off && nmcli radio wifi on` |
| WPA2/3 Enterprise GUI broken | Use CLI or wpa_supplicant |

</details>

<a id="known-issues-mosh"></a>
<details>
<summary><b>Progress bar disabled under mosh</b></summary>

DECSTBM scroll-region sequences aren't honored by mosh; the bar is suppressed
but `progress` JSONL events still emit. Use SSH, tmux, or a local terminal.

</details>

<a id="known-issues-keepalive"></a>
<details>
<summary><b>Sudo keepalive process failed to start</b></summary>

`_start_sudo_keepalive` forks a hermetic `fish --no-config -c …` child that re-runs
`sudo -n -v` every 45s, tied to `LOCK_DIR`'s inode. If the fork or post-fork `kill -0`
fails, the install proceeds with a warn (no abort) and downstream `sudo -n` may fail
mid-`pacman -Syu`. Mitigation: `sudo -v; and ./ry-install.fish` (idempotent).
Common causes: fork limit (`ulimit -u`), AppArmor/SELinux denial, or a `/proc` mount
blocking `kill -0`. Child stderr is captured to `SUDO_KEEPALIVE_ERR` and surfaced
by `_check_sudo_keepalive`.

</details>

## Troubleshooting

| Problem | Diagnostic / Fix |
|---|---|
| GPU perf level stuck | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend mismatch | `grep wifi.backend /etc/NetworkManager/conf.d/99-cachyos-nm.conf; and pgrep -x iwd` |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Stale lock | `rm -rf ~/ry-install/.lock/` (only if no `pgrep -af ry-install`) |
| AUR pkg missing | `command -q paru; or sudo pacman -S --needed paru`, then re-run |
| Sudo cache expired | `sudo -v; and ./ry-install.fish` |
| Sudo keepalive failed to start | `sudo -v; and ./ry-install.fish` (run before `pacman -Syu` on fork-limit denial) |
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
| Initramfs rebuild refused | Fix root cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `Foreign entries detected` at boot-wipe gate | Inspect `/boot/loader/entries/*.conf`. Disposable: `RY_INSTALL_CONFIRM_BOOT_WIPE=1 ./ry-install.fish`. Preserve: relocate them out of `loader/entries/` |
| `PKGS_DEL` member skipped (reverse deps) | `RY_INSTALL_PKG_REMOVE_CASCADE=1 ./ry-install.fish` cascades the rdeps. Inspect the dep chain first: `pactree -ru <pkg>`. |
| `Enabled but failed to start: <unit>` | Enabled (next-boot OK); start blocked by invalid runtime config. `systemctl status <unit>; journalctl -u <unit> -b` |

## References

| Resource | Topic |
|---|---|
| [NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) | NetworkManager iwd backend |
| [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) | MediaTek WiFi 7 driver |
| [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) | Mesa GPU tracker |
| [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) | AMDGPU feature mask |
| [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) | ROCm containers + benchmarks |

## License

MIT © 2026 Ryan Musante
