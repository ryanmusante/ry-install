# ry-install

[![version](https://img.shields.io/badge/version-4.6.10-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46.svg)](https://fishshell.com/)
[![kernel](https://img.shields.io/badge/kernel-%E2%89%A5%206.14%20%286.18.4%2B%20rec.%29-orange.svg)](https://www.kernel.org/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> Self-contained CachyOS configuration manager. Single Fish script, 15 embedded configs, no required external dependencies (paru optional; needed for MT7925 DKMS).

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
> **Installing over WiFi?** The NetworkManager backend switch (wpa_supplicant → iwd) is deferred until next reboot. On ethernet, `sudo systemctl restart NetworkManager` applies immediately.

> [!IMPORTANT]
> Initramfs rebuild refuses to run when on-disk package state or boot-critical configs (`/etc/mkinitcpio.conf`, `/etc/kernel/cmdline`, `/boot/loader/loader.conf`, `/etc/sdboot-manage.conf`) may be inconsistent with the embedded content. Service-runtime failures (e.g. a `systemctl enable --now` start failing because the unit's runtime config is invalid) do **not** block boot rebuild — they're surfaced as warnings. Override after manual remediation: `RY_INSTALL_FORCE_BOOT_REBUILD=1`. Only the literal value `1` is accepted.

## Scope

**In scope:** system-wide CachyOS configuration (kernel cmdline, initramfs, systemd units, network stack, sysctl, gaming env vars), package install/remove via pacman + paru, masking of laptop power-management units for desktop use, single-user systemd `--user` units.

**Out of scope:** dotfiles, shell prompts, editor config, secrets management, backup orchestration, multi-user provisioning, non-CachyOS distros, laptops (script masks all sleep/suspend targets).

## Prerequisites

| Requirement | Detail |
|---|---|
| CachyOS | systemd-boot, ext4 |
| Fish | ≥ 3.6 (≥ 4.0 recommended) |
| Kernel | ≥ 6.14 (≥ 6.18.4 for gfx1151) |
| Sudo | Unrestricted — no `requiretty`, `tty_tickets`, or `timestamp_timeout=0` |
| Coreutils | GNU `sort -z`, `stat -c`, `find -printf`, `df --output`, `timeout` |
| Free space | 2 GB on `/`, 200 MB on `/boot` |
| Network | `curl` required |
| paru | Optional, for AUR (`mt76-mt7925-dkms`) |

```fish
./ry-install.fish --check        # idempotency probe
sudo -v                          # warm sudo cache
df -h / /boot                    # verify space
```

Review [Masked Services](#masked-services) before running on laptops. Check [CachyOS](https://wiki.cachyos.org) and [Arch news](https://archlinux.org/news/) before any `pacman -Syu`.

## Hardware Reference

Kernel parameters and tuning values are calibrated for the components below. Other hardware requires editing the `# === GTR9_PRO BUILT-IN DEFAULTS ===` block at the top of `ry-install.fish`.

| Component | Detail |
|---|---|
| CPU | Ryzen AI Max+ 395 (Zen 5, 16C/32T, gfx1151 iGPU) |
| GPU | Radeon 8060S (RDNA 3.5, 40 CUs) |
| RAM | 128 GB LPDDR5x-8000 |
| WiFi | MediaTek MT7925 (WiFi 7) |
| NIC | Dual Intel E610-XT2 10 GbE |
| BIOS | P110+ — [Beelink downloads](https://dr.bee-link.cn/) |

Track [kernel bugzilla](https://bugzilla.kernel.org) and [Mesa gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) for regressions.

## Usage

All modes are non-interactive. Verification flags are read-only.

| Flag | Description |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show output for install/check (silent by default) |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--check` | Silent idempotency probe (exit 0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy a single managed file |
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
| **Configuration** | Deploy all 15 embedded config files (atomic writes; system + service units + user) |
| **Services** | `daemon-reload`, enable system units (cpupower-epp.service, fstrim.timer, NM-dispatcher), mask 11 desktop/power units (5 sleep targets + 6 service/socket masks; `lvm2-monitor` auto-skipped when LVM detected), enable user ssh-agent.service |
| **Boot** | Rebuild initramfs (gated on no-prior-errors), update systemd-boot entries |
| **Finalize** | Cache cleanup, NM restart (deferred on active WiFi) |

## Configuration Reference

All values are embedded in the script and deployed via the paths in [Managed Files](#managed-files). To retune, edit the inlined defaults block at the top of `ry-install.fish`.

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
> `mkinitcpio -P` is **not** invoked when package install or a boot-critical config deploy (`mkinitcpio.conf`/`kernel/cmdline`/`loader.conf`/`sdboot-manage.conf`) failed. Service-runtime `--now` start failures are reported as warnings and do not gate the rebuild. Override: `RY_INSTALL_FORCE_BOOT_REBUILD=1`.

### System Services

| Unit | Purpose |
|---|---|
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` |
| `fstrim.timer` | Weekly TRIM (system-pre-existing; enabled here) |
| `NetworkManager.service` | Pre-enabled by CachyOS base install (verified active+enabled post-install; verify-runtime warns "not installed" if absent) |

Implicit units enabled by deployed conf.d files: `systemd-resolved.service` (via `resolved.conf.d`), `NetworkManager-dispatcher.service` (via `NetworkManager/conf.d`).

`power-profiles-daemon` is masked separately ([Masked Services](#masked-services)) to prevent EPP conflicts.

### Network Stack

WiFi locked to iwd backend (NM) with power-save off — required for MT7925 stability. DNS via systemd-resolved.

| File | Setting |
|---|---|
| `resolved.conf.d` | MulticastDNS=resolve, LLMNR=no, DNSOverTLS=opportunistic, DNSSEC=allow-downgrade |
| `iwd/main.conf` | EnableNetworkConfiguration=false, DriverQuirks=`PowerSaveDisable=*`, NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd, wifi.powersave=2, wifi.iwd.autoconnect=false |

> [!NOTE]
> If `iwd` is not installed at install-time, both `iwd/main.conf` and `NetworkManager/conf.d/99-cachyos-nm.conf` are skipped (deploying `wifi.backend=iwd` against an absent backend would leave NM unable to associate). Install `iwd` first — `sudo pacman -S --needed iwd` — or re-run `ry-install` after installation.

### System Tuning

`coredump.conf.d` is critical: Wine/Proton crashes can produce multi-GB cores that fill `/var`. `/etc/fstab` is the only path modified outside the checksum pipeline (still atomic).

| File | Setting |
|---|---|
| `logind.conf.d` | Ignore 9 power/suspend/hibernate/reboot key events (`HandleSecureAttentionKey` requires systemd ≥ 256; 8 keys emitted on systemd 252–255) |
| `coredump.conf.d` | Storage=none, ProcessSizeMax=0 |
| `drirc` | RADV unified VRAM heap (APU) |
| `sysctl.d` | BBR+fq, tcp_fastopen=3, 10 GbE buffers, 16 tunables |
| `/etc/fstab` | `noatime,lazytime,commit=10` on ext4 |

### Environment Variables

12 vars in `~/.config/environment.d/10-environment.conf` (11 gaming/debug + 1 systemd-user `SSH_AUTH_SOCK` binding). Debug logging silenced by default.

<a id="environment-variables-list"></a>
<details>
<summary><b>Show 12 environment variables</b></summary>

| Variable | Value |
|---|---|
| `SSH_AUTH_SOCK` | `${XDG_RUNTIME_DIR}/ssh-agent.socket` (binds systemd-user services to the local agent socket; fish/conf.d resolves forwarded > gcr > systemd for interactive sessions) |
| `DXVK_LOG_LEVEL` / `DXVK_LOG_PATH` | `none` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` (experimental; breaks Steam Overlay) |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_USE_NTSYNC` | `1` |
| `RADV_EXPERIMENTAL` | `transfer_queue` |
| `RADV_PERFTEST` | `sam,nircache` |
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

Deprecated — do not re-introduce: `DXVK_ASYNC`, `DXVK_FRAME_RATE`, `WINE_FULLSCREEN_FSR`, `DISABLE_LAYER_MESA_ANTI_LAG`, `ENABLE_LAYER_MESA_ANTI_LAG`, `PROTON_NO_WM_DECORATION`. (`VKD3D_FRAME_RATE` is **retained** — still valid.)

</details>

### User Configuration

| File | Purpose |
|---|---|
| `fish/conf.d/10-ssh-auth-sock.fish` | SSH socket priority: forwarded > gcr > systemd agent |
| `environment.d/10-environment.conf` | Env vars for systemd user services |
| `systemd/user/ssh-agent.service` | Persistent `ssh-agent -D` with crash recovery |

### Packages

Default: `pacman -Syu --needed` per Arch's [no-partial-upgrade policy](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported).

> [!CAUTION]
> Set `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` to switch to `pacman -Sy --needed` (refresh+install only, no system upgrade). Violates Arch policy — accept the dependency-version-skew risk.

> [!NOTE]
> Removal of a `PKGS_DEL` member is skipped when an installed package outside `PKGS_DEL` reverse-depends on it. Set `RY_INSTALL_PKG_REMOVE_CASCADE=1` to cascade — both the target and its installed reverse deps are added to the removal set in a single `pacman -Rns` invocation. Inspect the dep chain first: `pactree -ru <pkg>`.

| Action | Count | Packages |
|---|---|---|
| **Install** | 13 | mkinitcpio-firmware, nvme-cli, cachyos-gaming-meta, cachyos-gaming-applications, mesa, lib32-mesa, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove** | 7 | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, octopi, micro, cachyos-micro-settings, btop |
| **AUR** | 1 | mt76-mt7925-dkms (paru required; soft-fail if absent) |

### Masked Services

11 units masked — **review before laptop use:**

<a id="masked-services-list"></a>
<details>
<summary><b>Show masked services (11)</b></summary>

| Service | Reason |
|---|---|
| `ananicy-cpp.service` | Manual tuning preferred |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `systemd-coredump.socket` | Eliminates spawn-and-discard on Wine crashes |
| `ufw.service` | Firewall not used on this profile (mask retained even if `ufw` package is installed; mask survives package install/removal) |
| `sleep.target` / `suspend.target` / `hibernate.target` / `hybrid-sleep.target` / `suspend-then-hibernate.target` | Desktop — no power management |

</details>

## Managed Files

15 files deployed via atomic writes (tmp → symlink-check → chmod → `mv -T`).

<a id="managed-files-list"></a>
<details>
<summary><b>Show all 15 destinations</b></summary>

| Scope | Path |
|---|---|
| System | `/boot/loader/loader.conf` |
| System | `/etc/kernel/cmdline` |
| System | `/etc/sdboot-manage.conf` |
| System | `/etc/mkinitcpio.conf` |
| System | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` |
| System | `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| System | `/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf` |
| System | `/etc/iwd/main.conf` |
| System | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` |
| System | `/etc/drirc` |
| System | `/etc/sysctl.d/99-cachyos-sysctl.conf` |
| Service | `/etc/systemd/system/cpupower-epp.service` |
| User | `~/.config/fish/conf.d/10-ssh-auth-sock.fish` |
| User | `~/.config/environment.d/10-environment.conf` |
| User | `~/.config/systemd/user/ssh-agent.service` |

</details>

## Customization

Edit the `# === GTR9_PRO BUILT-IN DEFAULTS ===` block at the top of `ry-install.fish`. Re-run `--verify-static` after changes.

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → post-mktemp symlink check → chmod → `mv -T` (same FS, refuses target-as-directory); parent dir must be root- or self-owned, not symlinked, not group/world-writable |
| Permissions | System 0644 · user 0600 · `~/ry-install/` 0700 · logs 0600. User-scope `mkdir -p` runs under `umask 0077` so newly-created intermediate dirs are 0700 (counters umask 002 / `USERGROUPS_ENAB` envs) |
| fstab | Idempotent; `findmnt --verify` before write; symlinked fstab rejected; **no backup — snapshot first** |
| Boot rebuild gate | `mkinitcpio -P` refuses to run when package install or boot-critical config deploy failed (`_RY_BOOT_TAINTED`); service-runtime failures do not gate. Override: `RY_INSTALL_FORCE_BOOT_REBUILD=1` |
| Boot-wipe gate | `SDBOOT_REMOVE_EXISTING=yes` auto-acks when every `loader/entries/*.conf` matches a `vmlinuz-*` in the ESP (sdboot-manage will regenerate them). Foreign entries (`windows.conf`, `rescue.conf`, custom kernels) preserve the refusal. Override: `RY_INSTALL_CONFIRM_BOOT_WIPE=1`. Marker file at `~/ry-install/.boot-wipe-acknowledged` records the entry-set hash on first successful run. |
| Pacnew handling | `.pacnew` at managed destinations is silently resolved (re-deploy embedded content + `rm`); embedded content is the source of truth for managed paths. `.pacsave` continues to warn (out-of-scope for auto-resolve). |
| KERNEL_PARAMS hygiene | Preflight rejects whitespace or `"` in any param |
| Sysctl invariant | Generator returns rc 13 if printed line count ≠ `count $SYSCTL_VALUES` |
| Subprocess control | `_run` uses `timeout --foreground`; `_do_cleanup` reaps via `pkill -P` before keepalive teardown |
| Stderr surfacing | First 5 lines of subprocess stderr mirror to fd 2 on rc≠0, even under `QUIET=true`. Under `--verbose`, full stderr **then** full stdout are mirrored to fd 2 (block-ordered, not interleaved with the child's own stream-mixing). |
| Root detection | Refuses to run as root; sudo invoked internally |
| Instance lock | Atomic mkdir + `flock(1)` stale reclaim |
| Re-source guard | `_RY_INSTALL_LOADED` blocks double-source within the same shell session; cleared on every clean exit path including the `--help` / `--version` early-peek |
| Credentials | 15 lowercase secret-flag patterns redacted in logs (passphrase, password, token, key, secret, api-key, apikey, psk, wpa-psk, private-key, auth, bearer, cookie, client-secret, credential) |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT → 128+signum; SIGPIPE → 141 |
| mkinitcpio rollback | Pre-deploy bytes captured; restored via atomic mv on `pacman -Syu` failure (rollback only when pre-deploy backup succeeded; skipped on sudo lapse — `MKINITCPIO_BACKUP_SKIPPED` logged) |
| Log integrity | NDJSON to `~/ry-install/logs/YYYY-MM-DD/*.jsonl`; single-writer guard; self-heal on rotation race |

<a id="exit-codes"></a>
<details>
<summary><b>Exit Codes</b></summary>

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Non-critical failure / verification drift |
| `2` | Usage error (argparse + policy refusals) |
| `3` | Preflight failed |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | Drift (`--check` only) |
| `129/130/131/143` | Signal (HUP / INT / QUIT / TERM) |
| `134/138/140` | Signal (ABRT / USR1 / USR2) |
| `141` | SIGPIPE |

</details>

<a id="runtime-variables"></a>
<details>
<summary><b>Runtime Variables</b></summary>

| Variable | Default | Purpose |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | Per-`_run` wall-clock cap (seconds). `0` disables. |
| `RY_INSTALL_CONFIRM_BOOT_WIPE` | unset | Literal `=1` to ack boot-entry wipe (rejects `01`, `true`, `yes`, etc.). Override only — auto-ack already passes when every existing entry maps to a `vmlinuz-*` in the ESP. Re-prompts on entry-set hash change. |
| `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` | unset | Literal `=1` switches Packages phase to `pacman -Sy --needed` (no system upgrade). Violates Arch policy. |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | Literal `=1` required to bypass torn-package gate. Recovery only. |
| `RY_INSTALL_PKG_REMOVE_CASCADE` | unset | Literal `=1` cascades installed reverse deps into the removal set when a `PKGS_DEL` package is blocked. Default skips with warn. |
| `NO_COLOR` | unset | Suppress ANSI color (also auto on `TERM=dumb` / non-TTY). |

> Secret-flag redaction is **case-sensitive lowercase**. Use lowercase flag names with `_run`-piped commands.

</details>

<a id="data-directory-logs"></a>
<details>
<summary><b>Data Directory & Logs</b></summary>

All runtime state under `~/ry-install/`. Logs auto-prune at `MAX_LOGS=50` (oldest first; `*.jsonl` and `*.log` under `~/ry-install/logs/`).

| Path | Contents |
|---|---|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON logs (`*.jsonl`) |
| `~/ry-install/.lock/` | Instance guard |
| `~/ry-install/.boot-wipe-acknowledged` | Boot-wipe ack marker (entry-set hash; written after every successful rebuild whether ack came from auto / env / marker) |

NDJSON schema: every line is `{"ts":ISO8601,"event":NAME,"data":STR,...}`. Common events: `header`, `footer`, `ok`/`fail`/`warn`/`err`/`info`, `prog_step_start`/`prog_step_end`, `run`, `stderr`, `section`, `bug`. Additional prefix-routed event types (e.g. `BOOT_*`, `CHECK_*`, `MKINITCPIO_*`, `PKG_REMOVE_*`, `SUDO_*`, `VERIFY_*`) follow the same schema.

```fish
jq 'select(.event == "fail")' ~/ry-install/logs/**/*.jsonl
```

</details>

## Uninstall

No automated uninstaller. Use [Managed Files](#managed-files) as the rollback source-of-truth: unmask units, `rm` deployed paths, restore `/etc/fstab` from your snapshot, optionally `pacman -S`/`-Rns` to reverse package changes, then `mkinitcpio -P && sdboot-manage gen` and reboot.

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

The pinned bottom-row bar uses DECSTBM scroll-region sequences which mosh does not honor. Under mosh the bar is suppressed; `progress` JSONL events still emit. Use SSH, tmux, or local terminal.

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
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
| Initramfs rebuild refused | Fix root cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `Foreign entries detected` at boot-wipe gate | Inspect `/boot/loader/entries/*.conf`. If foreign entries (Windows, rescue, custom kernels) are disposable: `RY_INSTALL_CONFIRM_BOOT_WIPE=1 ./ry-install.fish`. To preserve them: keep them out of `loader/entries/` (e.g. relocate to a separate `entries-extra/` directory referenced manually). |
| `PKGS_DEL` member skipped (reverse deps) | `RY_INSTALL_PKG_REMOVE_CASCADE=1 ./ry-install.fish` cascades the rdeps. Inspect the dep chain first: `pactree -ru <pkg>`. |
| `Enabled but failed to start: <unit>` | Unit is enabled (next-boot OK); start blocked by missing/invalid runtime config. Diagnose: `systemctl status <unit>; journalctl -u <unit> -b`. |

## References

| Resource | Topic |
|---|---|
| [NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) | NetworkManager iwd backend |
| [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) | MediaTek WiFi 7 driver |
| [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) | Mesa GPU tracker |
| [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) | AMDGPU feature mask |
| [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) | ROCm containers + benchmarks |

## License

[MIT](LICENSE) © 2026 Ryan Musante
