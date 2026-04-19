# ry-install v4.0.1

Self-contained CachyOS configuration manager with profile support. Single Fish script, 16 embedded configs, no required external dependencies (paru optional; needed for MT7925 DKMS).

**Default profile:** Beelink GTR9 Pro (Strix Halo APU). See [Hardware Reference](#hardware-reference).

[Changelog](CHANGELOG.md)

## Table of Contents

1. [Quick Start](#quick-start)
2. [Scope](#scope)
3. [Prerequisites](#prerequisites)
4. [Hardware Reference](#hardware-reference)
5. [Usage](#usage)
6. [Install Flow](#install-flow)
7. [Configuration Reference](#configuration-reference)
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
8. [Managed Files](#managed-files)
9. [Profiles](#profiles)
   - [Required Globals](#required-globals)
   - [Example Profile](#example-profile)
   - [Profile Trust Model](#profile-trust-model)
10. [Safety & Reliability](#safety--reliability)
    - [Exit Codes](#exit-codes)
    - [Environment Variables](#environment-variables-1)
    - [Data Directory](#data-directory)
    - [Log Format](#log-format)
11. [Uninstall](#uninstall)
12. [Known Issues](#known-issues)
    - [Strix Halo GPU (gfx1151)](#strix-halo-gpu-gfx1151)
    - [MediaTek MT7925 WiFi](#mediatek-mt7925-wifi)
    - [NetworkManager + iwd](#networkmanager--iwd)
13. [Troubleshooting](#troubleshooting)
14. [References](#references)
15. [License](#license)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git && cd ry-install
./ry-install.fish              # Deploy everything (unattended)
```

**Post-install verification:**

1. Reboot — required for kernel cmdline, initramfs, NetworkManager backend switch.
2. `./ry-install.fish --verify-static` — confirms managed files match embedded content.
3. `./ry-install.fish --verify-runtime` — confirms live kernel params, services, and modules are loaded.
4. Smoke test: WiFi associates, a Vulkan game launches via Steam/Proton.

Typical first-run duration: **3–8 minutes** (depends on package mirror speed and initramfs rebuild).

> **Installing over WiFi?** The NetworkManager backend switch (wpa_supplicant → iwd) is deferred until your next reboot. On ethernet, run `sudo systemctl restart NetworkManager` once to apply immediately.

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
| Current BIOS | [Beelink downloads](https://dr.bee-link.cn/) | See [Hardware Reference](#hardware-reference) |
| paru (optional) | `command -q paru` | AUR package installation |

**Recommended pre-flight steps:**

```fish
./ry-install.fish --check        # idempotency probe — see Exit Codes
sudo -v                          # warm sudo cache; confirms unrestricted sudo
df -h / /boot                    # verify space (≥2 GB / and ≥200 MB /boot)
```

Then review the [Masked Services](#masked-services) table — the default profile masks all sleep/suspend targets — laptop users must override `MASK`. Check [CachyOS news](https://wiki.cachyos.org) and [Arch news](https://archlinux.org/news/) for breaking changes before any `pacman -Syu`.

## Hardware Reference

The default `gtr9_pro` profile targets this specific machine. All kernel parameters, driver workarounds, and tuning values in this repo are calibrated against the components below. Other hardware requires a custom profile.

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

All modes are non-interactive. The bare invocation is the primary path; verification flags (`--verify-static`, `--verify-runtime`, `--check`) are read-only and safe to run against an already-configured system. `--install-file` re-deploys a single managed file and does write.

| Flag | Description |
|---|---|
| (no args) | Full unattended install (the only install path) |
| `-V, --verbose` | Show output on terminal |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--check` | Silent idempotency probe (exit 0 = clean, 3 = prereq fail, 10 = drift) |
| `--test-all` | Run all non-destructive modes, generate NDJSON logs |
| `--install-file <path>` | Re-deploy a single managed file |
| `--completions` | Install Fish tab-completions |
| `-h, --help` | Show help |
| `-v, --version` | Show version |
| `--` | End of options |

## Install Flow

Six sequential phases — boot-critical failures abort immediately:

```
Preflight → Packages → Configuration → Services → Boot → Finalize
```

| Phase | Description |
|---|---|
| **Preflight** | Validate prerequisites, acquire lock, load profile |
| **Packages** | Sync repos, install/remove packages, AUR via paru |
| **Configuration** | Deploy 16 embedded config files (atomic writes) |
| **Services** | Enable, mask, or create systemd units |
| **Boot** | Rebuild initramfs, update systemd-boot entries |
| **Finalize** | Daemon-reload, cache cleanup, NM restart (deferred on active WiFi), write manifest |

## Configuration Reference

Each subsection corresponds to a discrete layer of the system. All values are embedded in the script and deployed via the paths listed in [Managed Files](#managed-files). Override any setting by creating a custom profile rather than editing the managed files directly — doing so will cause `--verify-static` to report drift.

### Kernel Parameters

15 parameters written to `/etc/kernel/cmdline`:

| Parameter | Purpose |
|---|---|
| `amd_pstate=active` | Force amd_pstate_epp driver (Zen 5 native MSR CPPC; preferred-core default-on) |
| `amdgpu.cwsr_enable=0` | Disable CWSR — gfx1151 VGPR workaround (see [Known Issues](#known-issues)) |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Bits 14, 15, 17 off (overdrive / GFXOFF / stutter) |
| `iommu=pt` | IOMMU passthrough (preserves IRQ remapping/DMA security on APU, avoids translation overhead; no VFIO/passthrough use) |
| `loglevel=3` | Suppress kernel info/notice messages during boot |
| `module_blacklist=pcspkr` | Silence PC speaker beep |
| `nowatchdog` | Disable software watchdog timers |
| `pcie_aspm.policy=performance` | PCIe ASPM L0 always (framework intact, per-device sysfs control preserved) |
| `quiet` | Suppress kernel boot messages |
| `rd.systemd.show_status=auto` | Show initramfs unit status only on errors |
| `rd.udev.log_level=3` | Suppress udev info/debug messages in initramfs |
| `split_lock_detect=off` | Disable split-lock #AC exception (gaming) |
| `tsc=reliable` | Bypass TSC watchdog (Zen 5 TSC is invariant; avoids "marked unstable" demotion) |
| `usbcore.autosuspend=-1` | Disable USB autosuspend |
| `zswap.enabled=0` | Disable zswap (ZRAM handles compressed swap) |

### Boot Loader

Configures systemd-boot and sdboot-manage generation. `editor no` prevents live kernel cmdline tampering at the boot prompt; `timeout 0` boots the saved entry immediately with no menu delay.

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

`amdgpu` is forced unconditionally — it bypasses `autodetect` rather than relying on it to detect the module. `nvme` is pulled in by the `block` hook + `autodetect` pairing and does not need an explicit module entry. `zstd -1 -T0` uses all available threads at the fastest compression level — decompression is fast enough that the trade-off favors boot time over archive size.

| Setting | Value |
|---|---|
| Modules | `amdgpu` |
| Hooks | `base` → `systemd` → `autodetect` → `microcode` → `modconf` → `kms` → `keyboard` → `sd-vconsole` → `block` → `filesystems` → `fsck` |
| Compression | `zstd` |
| Compression Options | `-1 -T0` |

### System Services

One custom unit is created and enabled. `power-profiles-daemon` is masked separately (see [Masked Services](#masked-services)) to prevent it from fighting `cpupower-epp` over the EPP sysfs knob.

| Unit | Description |
|---|---|
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` sysfs |

### Network Stack

Three config files lock the WiFi stack to iwd as the NetworkManager backend with power-save disabled — required for MT7925 stability. DNS resolution is handled entirely by systemd-resolved; iwd delegates to it rather than writing `resolv.conf` directly.

| File | Setting |
|---|---|
| `resolved.conf.d` | MulticastDNS=resolve · LLMNR=no · DNSOverTLS=opportunistic · DNSSEC=allow-downgrade |
| `iwd/main.conf` | EnableNetworkConfiguration=false · DriverQuirks=`PowerSaveDisable=*` · NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd · wifi.powersave=2 · wifi.iwd.autoconnect=false · logging.level=WARN |

### System Tuning

Miscellaneous kernel and userspace tuning not covered by other subsections. `coredump.conf.d` is particularly important on this hardware — Wine and Proton processes can produce multi-GB core dumps that silently fill `/var`. Note that `/etc/fstab` is the only path modified outside the managed-file checksum pipeline; the rewrite itself is still atomic (tmp → `findmnt --verify` → `sudo mv`) — see [Safety & Reliability](#safety--reliability).

| File | Setting |
|---|---|
| `logind.conf.d` | Ignore power/suspend/hibernate/reboot keys + long-press (9 keys) |
| `coredump.conf.d` | Storage=none · ProcessSizeMax=0 (disables coredump storage — Wine/Proton multi-GB dumps) |
| `drirc` | RADV unified VRAM heap on APU |
| `sysctl.d` | BBR+fq · tcp_fastopen=3 · tcp_notsent_lowat=128K · 10 GbE buffer tuning · vm.max_map_count=max · watermark tuning · security hardening (19 net-new tunables) |
| `/etc/fstab` | Adds `noatime,lazytime,commit=10` to ext4 entries (modified in-place, not a managed file) |

### Environment Variables

Written to `~/.config/environment.d/10-environment.conf` for systemd user session pickup. All debug logging is silenced by default; re-enable selectively (`DXVK_LOG_LEVEL`, `VKD3D_DEBUG`, `WINEDEBUG`) only when diagnosing driver or shader issues — they generate significant volume under normal play.

| Variable | Value |
|---|---|
| `DXVK_LOG_LEVEL` | `none` |
| `DXVK_LOG_PATH` | `none` |
| `ENABLE_LAYER_MESA_ANTI_LAG` | `1` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_USE_NTSYNC` | `1` (default in current proton-cachyos; explicit pin) |
| `RADV_EXPERIMENTAL` | `transfer_queue,hic` |
| `RADV_PERFTEST` | `sam,nircache` |
| `VKD3D_DEBUG` | `none` |
| `VKD3D_SHADER_DEBUG` | `none` |
| `WINEDEBUG` | `-all` |

#### Deprecated flags — DO NOT re-introduce

The following environment variables have been removed upstream and must not be re-added to `ENV_VARS`. All four have been absent from this project's history; the list exists to prevent re-introduction during future refactors or contributions.

| Variable | Status | Notes |
|---|---|---|
| `DXVK_ASYNC` | removed | GPL (graphics pipeline library) replaced async shader compilation in DXVK 2.3+; DXVK state cache removed in 2.7 |
| `DXVK_FRAME_RATE` | removed | Upstream removed; use MangoHud or compositor framelimit instead |
| `WINE_FULLSCREEN_FSR` | removed | Upstream removed; FSR is handled by the game or per-title Proton config |
| `VKD3D_FRAME_RATE` | **retained** | Still valid in VKD3D-Proton — shown here for contrast only |

### User Configuration

Three files deploy to the calling user's home. The SSH agent runs with `-D` (no daemonize) so systemd can supervise it directly and restart on crash without leaving stale socket files.

| File | Purpose |
|---|---|
| `fish/conf.d/10-ssh-auth-sock.fish` | SSH socket priority: forwarded > gcr > systemd agent |
| `environment.d/10-environment.conf` | Environment variables for systemd user services |
| `systemd/user/ssh-agent.service` | Persistent `ssh-agent -D` with crash recovery |

### Packages

Package operations run during the Packages phase with `--needed` for idempotency — already-installed packages are skipped on subsequent runs. The single AUR package (`mt76-mt7925-dkms`) requires paru; if paru is absent the script emits `[ERR]`, sets `INSTALL_HAD_ERRORS`, and the AUR phase is marked failed. The rest of the install pipeline continues to run (boot rebuild, verify, finalize) but the overall exit code reflects the failure.

| Action | Count | Packages |
|---|---|---|
| **Install** | 14 | mkinitcpio-firmware, nftables, nvme-cli, cachyos-gaming-meta, cachyos-gaming-applications, libva-mesa-driver, lib32-libva-mesa-driver, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove** | 8 | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, ufw, octopi, micro, cachyos-micro-settings, btop |
| **AUR** | 1 | mt76-mt7925-dkms (via paru; AUR phase fails with `INSTALL_HAD_ERRORS` if paru absent) |

### Masked Services

10 units masked — **review before running on laptops:**

| Service | Reason |
|---|---|
| `ananicy-cpp.service` | Manual tuning preferred |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `systemd-coredump.socket` | Storage=none already suppresses storage; masking the socket eliminates spawn-and-discard overhead on Wine/Proton crashes |
| `sleep.target` | Desktop — no sleep |
| `suspend.target` | Desktop — no suspend |
| `hibernate.target` | Desktop — no hibernate |
| `hybrid-sleep.target` | Desktop — no hybrid sleep |
| `suspend-then-hibernate.target` | Desktop — no suspend-then-hibernate |

## Managed Files

16 files deployed via atomic writes (tmp → chmod → mv):

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
| 12 | System | `/etc/udev/rules.d/99-nvme-rqaffinity.rules` |
| 13 | User | `~/.config/fish/conf.d/10-ssh-auth-sock.fish` |
| 14 | User | `~/.config/environment.d/10-environment.conf` |
| 15 | User | `~/.config/systemd/user/ssh-agent.service` |
| 16 | Service | `/etc/systemd/system/cpupower-epp.service` |

## Profiles

External profiles live at `~/.config/ry-install/profiles/<n>.fish` and define `function _ry_profile_<n>` with all required globals. Resolution: `~/.config/ry-install/default-profile` (single line: profile name) → `gtr9_pro` (hardcoded fallback). Legacy `profile_<n>` naming accepted with a deprecation warning; syntax and name-consistency validated before sourcing.

```fish
echo my_desktop > ~/.config/ry-install/default-profile
```

### Required Globals

**26 unconditional** — preflight fails and reports the variable name if any are missing:

| Category | Globals |
|---|---|
| Identity | `PROFILE_NAME`, `PROFILE_DESC` |
| Destinations | `SYSTEM_DESTINATIONS`, `USER_DESTINATIONS`, `SERVICE_DESTINATIONS` |
| Kernel + initramfs | `KERNEL_PARAMS`, `MKINITCPIO_MODULES`, `MKINITCPIO_HOOKS`, `MKINITCPIO_COMPRESSION` |
| Boot loader | `LOADER_DEFAULT`, `LOADER_TIMEOUT`, `LOADER_CONSOLE_MODE`, `LOADER_EDITOR`, `SDBOOT_DEFAULT_ENTRY`, `SDBOOT_OVERWRITE`, `SDBOOT_REMOVE_EXISTING`, `SDBOOT_REMOVE_OBSOLETE` |
| Packages + services | `PKGS_ADD`, `MASK`, `EXPECTED_SERVICES` |
| Environment | `ENV_VARS`, `LOGIND_IGNORE_KEYS` |
| Thresholds | `BOOT_SPACE_CRIT`, `BOOT_SPACE_WARN`, `ROOT_AVAIL_CRIT`, `ROOT_AVAIL_WARN` |

**8 conditional** (required when the matching glob appears in `SYSTEM_DESTINATIONS`): `*/iwd/*` → `IWD_ENABLE_NETWORK_CONFIG`, `IWD_DRIVER_QUIRKS`, `IWD_DNS_SERVICE` · `*nm.conf` → `NM_WIFI_BACKEND`, `NM_WIFI_POWERSAVE`, `NM_LOG_LEVEL` · `*/resolved.conf.d/*` → `RESOLVED_MDNS` · `*/sysctl.d/*` → `SYSCTL_VALUES`.

**Optional** (unset-safe): `PKGS_DEL`, `AUR_PKGS`, `BOOT_TIME_TARGET`, `EXPECTED_CPU_MATCH`, `MKINITCPIO_COMPRESSION_OPTIONS`, `EXPECTED_VULKAN_PKGS`.

### Example Profile

Save as `~/.config/ry-install/profiles/my_desktop.fish`:

```fish
function _ry_profile_my_desktop --description "Example desktop profile"
    set -g PROFILE_NAME my_desktop
    set -g PROFILE_DESC "My Desktop — AMD Ryzen 7 7800X3D / RX 7900 XTX"

    # Copy SYSTEM_DESTINATIONS / USER_DESTINATIONS / SERVICE_DESTINATIONS
    # from the built-in gtr9_pro profile and adjust paths as needed.
    # Then define the 26 unconditional + applicable conditional globals
    # listed in the Required Globals table above.
end
```

Run `--verify-static` and `--verify-runtime` before first use.

### Profile Trust Model

Profiles execute via `source` with the user's privileges — treat them like any shell script. Only use profiles from trusted sources; verify ownership with `stat -c '%U' ~/.config/ry-install/profiles/*.fish`. No sandboxing — a malicious profile can do anything your account can.

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → chmod → mv (same filesystem) |
| fstab edits | Idempotent; validated via `findmnt --verify` before write; **no backup written** — snapshot `/etc/fstab` before first run |
| Root detection | **Refuses to run as root** — invoke as your normal user; sudo called internally |
| Instance lock | Atomic mkdir, PID verification, stale reclaim |
| Credentials | 9 sensitive flag patterns redacted in logs (`--passphrase`, `--password`, `--token`, `--key`, etc.) |
| Signal handling | HUP/INT/QUIT/TERM → 128+signum; SIGPIPE → 141 |
| Logging | NDJSON to `~/ry-install/logs/YYYY-MM-DD/*.jsonl` |
| Boot safety | Abort on initramfs or bootloader rebuild failure |
| LVM-aware | Skips lvm2-monitor mask when LVM detected |
| Orphan tracking | Manifest warns on version or profile change |
| Source-safe | When `source`d, returns exit code via `$_RY_INSTALL_LAST_EXIT` instead of calling `exit` — safe for Fish wrapper scripts |

### Exit Codes

Codes are designed for scripting — non-zero always means something actionable. Code `10` is exclusive to `--check` (drift detected) and will never appear during a full install run; code `1` during install indicates a non-critical failure that did not abort the run.

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Non-critical failure / verification drift (`--verify-static`, `--verify-runtime`) |
| `2` | Usage error |
| `3` | Preflight failed (also `--check` prereq failure) |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | Drift (`--check`) |
| `129/130/131/143` | Signal (HUP / INT / QUIT / TERM) |
| `141` | SIGPIPE |

### Environment Variables

Shell variables that modify script behavior at runtime — distinct from the gaming/Proton variables written to the system. Set them in the invoking shell before running; they are not persisted anywhere by the installer.

| Variable | Default | Purpose |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | Positive integer seconds; wraps every `_run` call with `timeout --preserve-status --kill-after=10`. Default: 3600 (60 min). Set to `0` to explicitly disable (not recommended). |
| `RY_INSTALL_CONFIRM_BOOT_WIPE` | unset | Set to `1` to acknowledge the first boot-entry wipe (`SDBOOT_REMOVE_EXISTING=yes`). Gate re-prompts if entry count grows after the initial ack. Marker: `~/ry-install/.boot-wipe-acknowledged`. |
| `NO_COLOR` | unset | Suppresses ANSI color per no-color.org. Also auto-detected from `TERM=dumb` and non-TTY stderr. |

### Data Directory

All runtime state lives under `~/ry-install/`. The directory is created on first run and persists across installs. Logs accumulate per-day and are not pruned automatically — use `jq` against the NDJSON files for post-run analysis.

| Path | Contents |
|---|---|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON logs (`*.jsonl`) |
| `~/ry-install/.lock/` | Instance guard |
| `~/ry-install/.manifest` | Orphan tracking |
| `~/ry-install/.boot-wipe-acknowledged` | Boot-wipe ack marker; suppresses gate on subsequent runs. Delete to re-prompt. |

### Log Format

Every mode writes structured NDJSON. Each line is a self-contained JSON object with a `ts` (ISO 8601) field.

| Event | Key Fields | Emitted |
|---|---|---|
| `header` | version, profile, mode, verbose, command | Run start |
| `footer` | finished, mode, exit_code, pass, fail, warn; `interrupted:true` on signal exit; `cleanup_exit:true` on fish_exit fallback | Run end |
| `ok` | data | Verification pass |
| `fail` | data | Verification failure |
| `warn` | data | Non-fatal issue |
| `err` | data | Blocking error |
| `info` | data | Progress / non-actionable status |
| `echo` | data | Plain message (no level prefix) |
| `bug` | data | Internal assertion failure (invalid level or arg count) |
| `step_time` | data, elapsed_s | Install step completed |
| `progress` | data | Install phase advance ([N/M] label) |
| `run` | data | Command executed |
| `stderr` | data | Captured stderr |
| `section` | data | Phase boundary |

> ~50 additional prefix-routed event types (`lock_acquired`, `manifest_written`, `pkg_remove_ok`, `ntsync_check`, etc.) follow the same `{"ts":…,"event":…,"data":…}` schema and are queryable with jq.

Query with jq: `jq 'select(.event == "fail")' ~/ry-install/logs/**/*.jsonl`

<details>
<summary>Sample log output</summary>

```json
{"ts":"2026-04-19T14:23:01-0700","event":"header","version":"4.0.1","profile":"gtr9_pro","mode":"install","verbose":false,"command":"./ry-install.fish"}
{"ts":"2026-04-18T14:23:04-0700","event":"progress","data":"[1/6] Preflight"}
{"ts":"2026-04-18T14:23:12-0700","event":"step_time","data":"Preflight","elapsed_s":8}
{"ts":"2026-04-18T14:23:12-0700","event":"progress","data":"[2/6] Packages"}
{"ts":"2026-04-18T14:25:19-0700","event":"err","data":"paru not found — cannot install AUR packages: mt76-mt7925-dkms"}
{"ts":"2026-04-18T14:26:42-0700","event":"footer","finished":"2026-04-18T14:26:42-0700","mode":"install","exit_code":1,"pass":46,"fail":1,"warn":0}
```

</details>

## Uninstall

ry-install ships no automated uninstaller. `~/ry-install/.manifest` lists every deployed file as the source of truth for manual rollback. To revert: unmask the units in [Masked Services](#masked-services), `rm` the paths in [Managed Files](#managed-files), restore `/etc/fstab` from your own snapshot, optionally `pacman -S` the removed packages and `pacman -Rns` the installed ones, then `mkinitcpio -P && sdboot-manage gen` and reboot.

## Known Issues

### Strix Halo GPU (gfx1151)

gfx1151 is a newly-released target with active upstream churn in both the kernel and Mesa. Expect regressions to land and get fixed within weeks — track the linux-cachyos changelog and the Mesa gfx1151 issue tracker before any driver or kernel upgrade.

| Issue | Status | Workaround |
|---|---|---|
| CWSR hang — incorrect VGPR count, compute-only | Userspace fix in ROCm 7.2; kernel-mode fix not yet in mainline | `amdgpu.cwsr_enable=0` (still required) |
| MES page faults | Specific firmware revisions affected | Pin a known-good `linux-firmware` version if encountered |
| ROCm VRAM allocation | Fixed in kernel 6.16+ | GTT handled automatically — no `ttm.pages_limit` or `amdgpu.gttsize` needed |
| PSR freeze (eDP only) | Open | `amdgpu.dcdebugmask=0x10` (not needed for HDMI/DP) |
| Black screen | Reported kernel-version-specific regressions | Downgrade or upgrade as advised |
| ROCm compute | Requires env vars | `HSA_ENABLE_SDMA=0` and `HSA_OVERRIDE_GFX_VERSION=11.5.1` |

### MediaTek MT7925 WiFi

The in-tree `mt76` driver has known stability bugs specific to the MT7925 revision. The `mt76-mt7925-dkms` AUR package carries out-of-tree patches ahead of mainline merge and should be the first remediation step. If instability persists, an Intel AX210 or AX211 is a well-tested drop-in alternative.

| Issue | Status | Workaround |
|---|---|---|
| Kernel panics (NULL deref in `mt792x_mac_reset_work`) | Driver bug | `paru -S mt76-mt7925-dkms` |
| TX power reported as 3 dBm | Cosmetic — actual TX follows regulatory limits; kernel patches pending | None (cosmetic) |
| Random deauthentication | Intermittent | None |

### NetworkManager + iwd

These issues are specific to the NM + iwd combination and do not affect wpa_supplicant setups. The boot connectivity failure in particular is intermittent and usually self-resolves after a radio cycle; it does not indicate a misconfigured backend.

| Issue | Workaround |
|---|---|
| Boot connectivity failure | `nmcli radio wifi off && nmcli radio wifi on` |
| WPA2/3 Enterprise GUI broken with iwd | Use CLI or switch to wpa_supplicant |
| Monitor mode requires full reboot | Reboot |

## Troubleshooting

Start with `--verify-static` and `--verify-runtime` to confirm whether the issue is configuration drift or a runtime state problem. For deeper failures, `journalctl -b -k` and `dmesg -T` are the first sources. The table below covers the most common failure modes and their first-pass fixes.

| Problem | Diagnostic / Fix |
|---|---|
| GPU perf level stuck | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend mismatch | `grep wifi.backend /etc/NetworkManager/conf.d/99-cachyos-nm.conf; and pgrep -x iwd` (expect both) |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| FSR4 on RDNA 3.5 | Per-game: `PROTON_FSR4_RDNA3_UPGRADE=1 %command%` (proton-cachyos / GE-Proton 10-9+) |
| Profile load failure | `./ry-install.fish --verify-static` reports missing globals (`--check` is silent — QUIET=true); verify file ownership: `stat -c '%U' ~/.config/ry-install/profiles/*.fish` |
| Stale lock | `rm -rf ~/ry-install/.lock/` (only if no other ry-install process is running: `pgrep -af ry-install`) |
| Manifest version mismatch | Expected after upgrade — script warns but does not block; re-run install to refresh manifest |
| AUR pkg not installed | `command -q paru; or sudo pacman -S --needed paru` then re-run install |
| Sudo cache expiry mid-run | Re-run with fresh sudo: `sudo -v; and ./ry-install.fish` |
| `drirc` XML rejected by Mesa | `cat /etc/drirc` and validate with `xmllint --noout /etc/drirc` |
| `--verify-static` reports drift | Re-deploy single file: `./ry-install.fish --install-file /etc/...` |

## References

Upstream sources for hardware quirks, driver status, and the Arch/CachyOS configuration guidance this project builds on.

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
