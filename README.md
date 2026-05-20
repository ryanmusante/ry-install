# ry-install

[![version](https://img.shields.io/badge/version-7.4.13-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46.svg)](https://fishshell.com/)
[![kernel](https://img.shields.io/badge/kernel-%E2%89%A5%206.14%20%286.18.4%2B%20rec.%29-orange.svg)](https://www.kernel.org/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
![license](https://img.shields.io/badge/license-MIT-green.svg)

> Single Fish script for CachyOS — 12 embedded configs, no required
> external deps. paru required for AUR (`mkinitcpio-firmware`,
> `mt76-mt7925-dkms`).

**Target:** Beelink GTR9 Pro (Strix Halo APU). See [Hardware](#hardware).

---

## Contents

- [Quick Start](#quick-start)
- [Scope](#scope)
- [Prerequisites](#prerequisites)
- [Hardware](#hardware)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Configuration](#configuration)
- [Managed Files](#managed-files)
- [Safety & Reliability](#safety--reliability)
- [Uninstall](#uninstall)
- [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [License](#license)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

If you cannot set the executable bit: `fish ry-install.fish`.

**Post-install:**
1. Reboot — required for kernel cmdline, initramfs, NM backend switch.
2. `./ry-install.fish --verify-static`
3. `./ry-install.fish --verify-runtime`

Typical duration: **3–8 minutes**.

> [!IMPORTANT]
> Over WiFi, the NM backend switch (wpa_supplicant → iwd) is deferred
> to next reboot — on ethernet, `sudo systemctl restart NetworkManager`
> applies it immediately. Initramfs rebuild aborts when on-disk package
> state or boot-critical configs (`/etc/mkinitcpio.conf`,
> `/etc/kernel/cmdline`, `/boot/loader/loader.conf`,
> `/etc/sdboot-manage.conf`) are inconsistent with embedded content.
> Override after manual remediation: `RY_INSTALL_FORCE_BOOT_REBUILD=1`.

## Scope

| Status | Items |
|---|---|
| In | Kernel cmdline, initramfs, systemd units, network stack, sysctl, gaming env vars; pacman + paru install/remove; mask 12 desktop/power units; single-user `systemd --user` units. Boot: systemd-boot with BLS Type #1 entries via `sdboot-manage`. |
| Out | Dotfiles, shells, editors, secrets, backups, multi-user provisioning, non-CachyOS distros, laptops, UKI. |

## Prerequisites

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root |
| Fish | ≥ 3.6 |
| Kernel | ≥ 6.14 (≥ 6.18.4 for gfx1151) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| Before `-Syu` | Read [CachyOS](https://wiki.cachyos.org) + [Arch news](https://archlinux.org/news/) |

Additional preflight gates: systemd ≥ 250, GNU coreutils ≥ 8.x
(`timeout --foreground/--kill-after`), hardware match, and a cached sudo
credential (`sudo -v`). The ext4 `/etc/fstab` rewrite is idempotent and
mount-semantics-preserving.

> [!WARNING]
> Sudo cache may lapse during the 3-8 min install. Mitigations: `Defaults timestamp_timeout=60` in `/etc/sudoers`, a `sudo -v` keepalive in a parallel shell, or a `NOPASSWD: ALL` drop-in. Recovery: re-run ry-install (idempotent).

```fish
./ry-install.fish --check        # idempotency probe
sudo -v                          # warm sudo cache
df -h / /boot                    # verify space
```

## Hardware

| Component | Part |
|---|---|
| CPU | Ryzen AI Max+ 395 (Zen 5, gfx1151 iGPU) |
| GPU | Radeon 8060S (RDNA 3.5) |
| RAM | 128 GB LPDDR5x-8000 |

> [!IMPORTANT]
> Preflight refuses to deploy on hardware not matching
> `EXPECTED_CPU_MATCH` (default `Ryzen AI Max`): the amdgpu modules and
> gfx1151 cmdline are profile-specific and break initramfs on other
> silicon. Override at your own risk:
> `RY_INSTALL_SKIP_HARDWARE_CHECK=1 ./ry-install.fish`.

<details>
<summary><b>BIOS prerequisite — UMA Frame Buffer Size</b></summary>

Set **UMA Frame Buffer Size** to `Auto` or `512 MB` (not a fixed 16 GB
carveout). The Strix Halo APU uses UMA with shared system memory; a
large fixed carveout wastes RAM that would otherwise be available to
the OS and is dynamically backed when the GPU needs it.
`--verify-runtime` warns when `mem_info_vram_total` exceeds 512 MB.

</details>

Trackers: [kernel bugzilla](https://bugzilla.kernel.org),
[Mesa gfx1151](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151).

## Usage

| Flag | Action |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show output for install / check |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--check` | Silent idempotency probe (0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy a single managed file (absolute path) |
| `--` | End of options (positionals after `--` are rejected) |
| `-h, --help` / `-v, --version` | Help / version |

## Install Flow

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | Validate prerequisites, acquire lock, validate runtime |
| 2 | Packages | `pacman -Syu --needed`; AUR via paru; `updatedb` + `pkgfile --update` cache refresh |
| 3 | Configuration | Deploy 12 embedded config files (atomic) |
| 4 | Services | fstab ext4 opts; `systemd-resolved` restart; THP tmpfiles apply; `PKGS_DEL` removal; mask 12 desktop/power units; `daemon-reload` + enable runtime units |
| 5 | Boot | Rebuild initramfs, update systemd-boot entries |
| 6 | Finalize | Cache cleanup; NM restart (deferred when WiFi is active route) |

## Run Summary

After the install completes, a box-drawn matrix prints to stderr summarizing every phase:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                       ry-install v7.4.14 — RUN SUMMARY                       ║
╠════════════════════════════════════╦════════╦════════════════════════════════╣
║ CHECK                              ║ RESULT ║ EVIDENCE                       ║
╠════════════════════════════════════╬════════╬════════════════════════════════╣
║ Preflight: sudo credential cache   ║  PASS  ║ ok                             ║
║ Preflight: kernel version          ║  PASS  ║ 6.18.4                         ║
║ Preflight: wireless regdom         ║   --   ║ RY_INSTALL_WIRELESS_REGDOM uns ║
║ Packages: pacman -Syu              ║  PASS  ║ system upgraded                ║
║ Packages: AUR (paru)               ║  PASS  ║ 2/2 (mt7925e module verified)  ║
║ Configs: system file deployment    ║  PASS  ║ 11 deployed, 1 idempotent      ║
║ Boot: post-rebuild sanity          ║  PASS  ║ vmlinuz+initramfs+entries OK   ║
║ Finalize: NetworkManager restart   ║ DEFER  ║ over WiFi — applies on reboot  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Totals : 19 PASS · 0 WARN · 0 FAIL · 1 DEFER · 0 SKIP · 1 N/A                ║
║ Elapsed: 4m 23s   ·   Verdict: PASS                                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

| Result | Semantics |
|---|---|
| `PASS`  | Step ran and succeeded |
| `WARN`  | Step ran with a non-fatal anomaly (kernel-stability floor, ntsync gap, size threshold, partial AUR, etc.) |
| `FAIL`  | Step ran and failed (sets `INSTALL_HAD_ERRORS=true`) |
| `DEFER` | Step intentionally deferred to next boot (NM-over-wifi, kernel cmdline) |
| `SKIP`  | Step not run by design (tool absent, no user-bus, boot-critical bail, opt-in disabled) |
| `--` / `N/A` | Step not applicable (env var not set, conditional path, optional tool absent) |

| Verdict | Trigger |
|---|---|
| `PASS`               | `0 FAIL · 0 WARN` |
| `PASS-WITH-WARNINGS` | `0 FAIL · ≥1 WARN` |
| `FAIL`               | `≥1 FAIL` (without boot-critical) |
| `FAIL-BOOT-CRITICAL` | Boot rebuild cascade aborted (`EXIT_BOOT_CRIT`); script prints **DO NOT REBOOT** and recovery steps instead of the normal reboot advisory |

Set `RY_INSTALL_NO_MATRIX=1` to suppress the matrix (the JSONL log still records every `PHASE_RESULT` event regardless).

## Configuration

Every value embedded in `ry-install.fish` is documented below, grouped
by install-flow phase. Phases 1, 5, and 6 deploy no embedded data and
are described in prose. To retune, edit the `set -g` profile globals
near the top of the script. The script is the source of truth —
`--verify-static` matches installed files against embedded content
byte-for-byte.

### Phase 1 — Preflight

Validates fish ≥ 3.6, kernel ≥ 6.14, systemd ≥ 250, GNU coreutils,
free space, unrestricted sudo, and `EXPECTED_CPU_MATCH` hardware
fingerprint (`_install_preflight`). Acquires the instance lock
(atomic `mkdir` + `chmod 0700`; auto-reclaims dead PIDs). Runs
`_ir_validate_counts` — refuses to deploy on count drift in any
`set -g` array (15 invariants). Override the hardware gate with
`RY_INSTALL_SKIP_HARDWARE_CHECK=1`.

### Phase 2 — Packages

`pacman -Syu --needed` for `PKGS_ADD`, then `paru` for `AUR_PKGS`
(`_install_packages` / `_install_aur_packages`). `PKGS_DEL` removal
runs later in [Phase 4 — Services](#phase-4--services)
(`_configure_services_pkg_remove`), grouped with systemd-state
mutations. `EXPECTED_VULKAN_PKGS` is verify-only — checked, not installed.

<details>
<summary><b>Packages — install</b> — 15 (<code>PKGS_ADD</code>)</summary>

| Package | Purpose |
|---|---|
| `nvme-cli` | NVMe device management |
| `cachyos-gaming-meta` | CachyOS gaming meta-pkg |
| `cachyos-gaming-applications` | CachyOS gaming apps |
| `mesa` | Mesa Vulkan + GL |
| `lib32-mesa` | 32-bit Mesa (Steam/Wine) |
| `fd` | rust find |
| `sd` | rust sed |
| `dust` | rust du |
| `procs` | rust ps |
| `bottom` | rust top |
| `htop` | classic top |
| `git-delta` | git diff viewer |
| `lm_sensors` | hwmon |
| `realtime-privileges` | PipeWire RT scheduling group |
| `cpupower` | cpufreq governor management |

Default install path: `pacman -Syu --needed --noconfirm`.

</details>

<details>
<summary><b>Packages — AUR</b> — 2 (<code>AUR_PKGS</code>)</summary>

| Package | Purpose |
|---|---|
| `mkinitcpio-firmware` | Firmware blobs not in `linux-firmware` |
| `mt76-mt7925-dkms` | MediaTek MT7925 WiFi DKMS (panic fix) |

Post-install `modinfo mt7925e` cross-check verifies DKMS build
succeeded (paru `rc=0` alone is not definitive). See Package caveats
for `paru` flags and PGP-failure handling.

</details>

<details>
<summary><b>Vulkan dependencies</b> — 3 (<code>EXPECTED_VULKAN_PKGS</code>)</summary>

| Package | Notes |
|---|---|
| `vulkan-radeon` | RADV driver |
| `lib32-vulkan-radeon` | 32-bit RADV (Steam/Wine) |
| `lib32-mesa` | 32-bit Mesa |

`--verify-runtime` fails if any are missing (DXVK/VKD3D-Proton
dependency). `vulkan-radeon` and `lib32-vulkan-radeon` come from
`chwd` on AMD GPU profiles; `lib32-mesa` is in `PKGS_ADD`
(idempotent via `--needed`).

</details>

<details>
<summary><b>Package caveats</b></summary>

| Caveat | Detail |
|---|---|
| Partial upgrade | `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` switches to `pacman -Sy --needed` (refresh + install only, no upgrade). Retry path uses `-Syy` without `-u`. Violates [Arch's no-partial-upgrade policy](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported). |
| AUR flags | `paru -S --needed --noconfirm --skipreview --cleanafter`. `--removemake` deliberately omitted: DKMS packages rebuild against the running kernel and need makedeps. |
| PGP failures | `--skipreview` suppresses interactive key import. On `invalid or corrupted package (PGP signature)`: pre-import key (`gpg --recv-keys <KEYID>`) or `paru -S <pkg>` manually. |
| Reverse deps | `PKGS_DEL` removal skipped when an installed package outside the set rdeps on it. Cascade via `RY_INSTALL_PKG_REMOVE_CASCADE=1` (requires `pacman-contrib` for `pactree`). |
| db lock | `_install_packages` and `_csp_remove_pkgs` check `/var/lib/pacman/db.lck` before + after; aborts cleanly on contention. |
| `.pacnew` handling | Auto-redeployed at managed destinations and `rm`'d; `.pacsave` surfaced as warning for operator review. |

</details>

### Phase 3 — Configuration files

11 system + 1 user config file deployed via atomic writes by
`_install_system_files` (tmp → symlink check → chmod → `mv -T`).
Destinations enumerated in [Managed Files](#managed-files).
Boot-critical files (`/boot/loader/loader.conf`, `/etc/kernel/cmdline`,
`/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`) are deployed here
but take effect after [Phase 5 — Boot](#phase-5--boot) rebuilds initramfs
and bootloader entries.

<details>
<summary><b>Kernel cmdline</b> — 15 params (<code>KERNEL_PARAMS</code>)</summary>

| Param | Value |
|---|---|
| `iommu` | `pt` |
| `amd_pstate` | `active` |
| `amdgpu.cwsr_enable` | `0` |
| `amdgpu.ppfeaturemask` | `0xfffd3fff` |
| `loglevel` | `3` |
| `module_blacklist` | `pcspkr` |
| `nowatchdog` | (flag) |
| `pcie_aspm.policy` | `performance` |
| `quiet` | (flag) |
| `rd.systemd.show_status` | `auto` |
| `rd.udev.log_level` | `3` |
| `split_lock_detect` | `off` |
| `tsc` | `reliable` |
| `usbcore.autosuspend` | `-1` |
| `zswap.enabled` | `0` |

Deployed to `/etc/kernel/cmdline` (single line: `rw root=UUID=<uuid>
<params>`) and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS="<params>"`).

</details>

<details>
<summary><b>Bootloader</b> — 10 keys (4 loader.conf + 6 sdboot-manage.conf)</summary>

`/boot/loader/loader.conf`:

| Key | Value |
|---|---|
| `default` | `@saved` |
| `timeout` | `0` |
| `console-mode` | `keep` |
| `editor` | `no` |

`/etc/sdboot-manage.conf`:

| Key | Value |
|---|---|
| `LINUX_OPTIONS` | (mirrors `KERNEL_PARAMS`) |
| `LINUX_FALLBACK_OPTIONS` | `quiet` |
| `DEFAULT_ENTRY` | `manual` |
| `REMOVE_EXISTING` | `yes` |
| `OVERWRITE_EXISTING` | `yes` |
| `REMOVE_OBSOLETE` | `yes` |

</details>

<details>
<summary><b>Initramfs</b> — <code>/etc/mkinitcpio.conf</code></summary>

| Field | Value |
|---|---|
| `MODULES` | `(amdgpu)` |
| `BINARIES` | `()` |
| `FILES` | `()` |
| `HOOKS` | `(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` |
| `COMPRESSION` | `zstd` |
| `COMPRESSION_OPTIONS` | `(-1 -T0)` |

11 ordering invariants enforced by `_vmh_order_checks`
(including `base` first, `fsck` last, no duplicates). Existence-only
validation also runs post-pacman.

</details>

<details>
<summary><b>systemd-resolved</b> — 4 keys (<code>99-cachyos-resolved.conf</code>)</summary>

| Key | Value |
|---|---|
| `MulticastDNS` | `resolve` |
| `LLMNR` | `no` |
| `DNSOverTLS` | `opportunistic` |
| `DNSSEC` | `allow-downgrade` |

</details>

<details>
<summary><b>systemd-logind</b> — 9 keys (<code>99-cachyos-logind.conf</code>)</summary>

All set to `=ignore` (desktop power-handling deferred to userspace):

| Key | Notes |
|---|---|
| `HandlePowerKey` | |
| `HandlePowerKeyLongPress` | |
| `HandleSuspendKey` | |
| `HandleSuspendKeyLongPress` | |
| `HandleHibernateKey` | |
| `HandleHibernateKeyLongPress` | |
| `HandleRebootKey` | |
| `HandleRebootKeyLongPress` | |
| `HandleSecureAttentionKey` | emitted only when systemd ≥ 257 |

</details>

<details>
<summary><b>iwd</b> — 3 keys (<code>/etc/iwd/main.conf</code>)</summary>

| Section / Key | Value |
|---|---|
| `[General] EnableNetworkConfiguration` | `false` |
| `[DriverQuirks]` | `PowerSaveDisable=*` |
| `[Network] NameResolvingService` | `systemd` |

Skipped when `iwd` package not installed (memoized via `_RY_SKIP_IWD`).

</details>

<details>
<summary><b>NetworkManager</b> — 3 keys (<code>99-cachyos-nm.conf</code>)</summary>

| Section / Key | Value |
|---|---|
| `[device] wifi.backend` | `iwd` |
| `[connection] wifi.powersave` | `2` |
| `[logging] level` | `WARN` |

Skipped when `iwd` package not installed.

</details>

<details>
<summary><b>cpupower-service</b> — 1 key (<code>/etc/default/cpupower-service.conf</code>)</summary>

| Key | Value |
|---|---|
| `GOVERNOR` | `'performance'` |

Sourced by `cpupower.service` (`/usr/lib/systemd/scripts/cpupower`).

</details>

<details>
<summary><b>sysctl</b> — 16 tunables (<code>/etc/sysctl.d/99-cachyos-sysctl.conf</code>)</summary>

| Key | Value |
|---|---|
| `net.core.default_qdisc` | `fq` |
| `net.core.netdev_max_backlog` | `16384` |
| `net.core.rmem_max` | `134217728` |
| `net.core.wmem_max` | `134217728` |
| `net.ipv4.tcp_congestion_control` | `bbr` |
| `net.ipv4.tcp_fastopen` | `3` |
| `net.ipv4.tcp_mtu_probing` | `1` |
| `net.ipv4.tcp_notsent_lowat` | `131072` |
| `net.ipv4.tcp_rmem` | `4096 87380 134217728` |
| `net.ipv4.tcp_slow_start_after_idle` | `0` |
| `net.ipv4.tcp_wmem` | `4096 65536 134217728` |
| `vm.max_map_count` | `2147483642` |
| `vm.watermark_boost_factor` | `0` |
| `fs.protected_fifos` | `2` |
| `fs.protected_regular` | `2` |
| `vm.compaction_proactiveness` | `0` |

Priority 99 — loaded after CachyOS vendor `70-cachyos-settings.conf`.

</details>

<details>
<summary><b>tmpfiles</b> — 1 entry (<code>/etc/tmpfiles.d/99-cachyos-thp.conf</code>)</summary>

| Field | Value |
|---|---|
| Type | `w` |
| Path | `/sys/kernel/mm/transparent_hugepage/shrink_underused` |
| Mode / UID / GID / Age | `- - - -` |
| Argument | `0` |

`systemd-tmpfiles-setup.service` writes this on every boot; applied
immediately during install and on `--install-file` re-deploy.

</details>

<details>
<summary><b>Env vars</b> — 11 keys (<code>~/.config/environment.d/10-environment.conf</code>)</summary>

| Key | Value |
|---|---|
| `DXVK_LOG_LEVEL` | `none` |
| `DXVK_LOG_PATH` | `none` |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_USE_NTSYNC` | `1` |
| `RADV_EXPERIMENTAL` | `transfer_queue` |
| `RADV_PERFTEST` | `sam,nircache` |
| `VKD3D_DEBUG` | `none` |
| `VKD3D_SHADER_DEBUG` | `none` |
| `WINEDEBUG` | `-all` |

Loaded by `systemd --user` (COSMIC, Flatpak, D-Bus activated apps).
Log out and back in to apply.

</details>

### Phase 4 — Services

fstab rewrite (`_install_fstab_opts`), then `_install_configure_services`:
`systemd-resolved` restart (re-applies `99-cachyos-resolved.conf`),
`systemd-tmpfiles --create` for THP, `PKGS_DEL` removal, mask 12
desktop/power units, then `daemon-reload` + enable runtime units.

<details>
<summary><b>fstab</b> — ext4 mount options (idempotent rewrite)</summary>

| Option | Effect |
|---|---|
| `noatime` | Disable atime updates |
| `lazytime` | Defer in-memory atime/mtime writeback |
| `commit=10` | Flush journal every 10s (default 5) |

Idempotent ext4 rewrite — strips conflicting `atime`, `relatime`,
`strictatime`, `defaults`, existing `commit=*` tokens before applying.
`findmnt --verify` gates the atomic `mv`. **No automatic backup —
snapshot `/etc/fstab` before first run.**

</details>

<details>
<summary><b>Packages — remove</b> — 8 (<code>PKGS_DEL</code>)</summary>

| Package | Reason |
|---|---|
| `plymouth` | Boot splash — incompatible with `quiet` + `loglevel=3` |
| `cachyos-plymouth-bootanimation` | Plymouth dep |
| `cachyos-plymouth-theme` | Plymouth dep |
| `octopi` | Pacman GUI — CLI workflow |
| `micro` | Text editor — replaced by user choice |
| `cachyos-micro-settings` | micro dep |
| `btop` | Replaced by `bottom` |
| `bolt` | Thunderbolt manager — not used |

Skipped when an installed package outside the set rdeps on it. Cascade
via `RY_INSTALL_PKG_REMOVE_CASCADE=1` (requires `pacman-contrib` for
`pactree`).

</details>

<details>
<summary><b>Masked units</b> — 12 (<code>MASK</code>)</summary>

| Unit | Reason |
|---|---|
| `ananicy-cpp.service` | CPU nice daemon — managed via cgroups instead |
| `avahi-daemon.service` | mDNS via systemd-resolved instead |
| `avahi-daemon.socket` | socket counterpart of above |
| `power-profiles-daemon.service` | conflicts with amd_pstate + cpupower |
| `lvm2-monitor.service` | no LVM on this profile |
| `NetworkManager-wait-online.service` | adds boot delay |
| `ufw.service` | firewall not in this profile (rules flushed pre-mask) |
| `sleep.target` | suspend disabled (workstation) |
| `suspend.target` | suspend disabled |
| `hibernate.target` | hibernate disabled |
| `hybrid-sleep.target` | hybrid-sleep disabled |
| `suspend-then-hibernate.target` | s2h disabled |

Pre-mask `ufw --force disable` flushes live netfilter rules
(`systemctl mask` alone does not).

</details>

<details>
<summary><b>Enabled units</b> — 3 (<code>EXPECTED_SERVICES</code>)</summary>

| Unit | Notes |
|---|---|
| `fstrim.timer` | weekly SSD TRIM |
| `NetworkManager.service` | also enabled by its pacman scriptlet (deduped via `_RY_PKG_MANAGED_SERVICES`) |
| `cpupower.service` | oneshot — accepts `active` or `exited` |

`NetworkManager-dispatcher.service` is checked but not force-enabled.

</details>

### Phase 5 — Boot

Rebuilds initramfs (`mkinitcpio -P`) and bootloader entries
(`sdboot-manage gen` + `sdboot-manage update`) from the Phase 3
config files. Skipped when on-disk package state or boot-critical
configs are inconsistent with embedded content. Override after manual
remediation with `RY_INSTALL_FORCE_BOOT_REBUILD=1`.

### Phase 6 — Finalize

Pacman cache cleanup (`paccache`). NetworkManager restart to apply
the wpa_supplicant → iwd backend switch — deferred to next reboot
when WiFi is the active route. Writes the JSONL log footer.

## Managed Files

12 files deployed via atomic writes (tmp → symlink check → chmod →
`mv -T`). System files install `0644`, the user file `0600`. The two
`iwd` destinations are skipped when `iwd` is not installed.

<details>
<summary><b>Destinations</b></summary>

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
| System | `/etc/default/cpupower-service.conf` |
| System | `/etc/sysctl.d/99-cachyos-sysctl.conf` |
| System | `/etc/tmpfiles.d/99-cachyos-thp.conf` |
| User | `~/.config/environment.d/10-environment.conf` |

</details>

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → symlink check → chmod → `mv -T`; symlinked parent rejected |
| Permissions | system 0644 · user 0600 · `~/ry-install/` 0700 · logs 0600 |
| fstab | Idempotent ext4 rewrite; `findmnt --verify` hard-fail. **No backup — snapshot first** |
| Boot rebuild gate | `mkinitcpio -P` skipped on package or boot-config failure; failed revert is an unconditional gate (FORCE does not bypass) |
| mkinitcpio rollback | Pre-deploy snapshot; byte-exact revert on `pacman -Syu` failure or signal |
| Root detection | Refuses to run as root; sudo invoked internally |
| Instance lock | Atomic mkdir + chmod 0700; auto-reclaims dead-PID lock |
| Preflight visibility | Failures emit to stderr in default install mode; `--check` stays silent |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT → 128+signum; SIGPIPE non-fatal |

<details>
<summary><b>Exit codes</b></summary>

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Verify FAIL count, non-critical install warn, or old-kernel warn |
| `2` | Usage error |
| `3` | Preflight failed |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | `--check` drift |
| `128+N` | Signal (`129`=HUP, `130`=INT, `131`=QUIT, `143`=TERM, `134`=ABRT, `138`=USR1, `140`=USR2) |

</details>

<details>
<summary><b>Runtime variables</b></summary>

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | Per-`_run` wall-clock cap (s); `0` disables. Package / boot / pkg-db ops bypass the cap |
| `RY_INITRD_WARN_MB` | `100` | Initramfs size warning threshold (MB) |
| `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` | unset | `=1` → `pacman -Sy --needed` (install-only) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_PKG_REMOVE_CASCADE` | unset | `=1` cascades reverse deps into removal set |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` hard-fail |
| `RY_INSTALL_WIRELESS_REGDOM` | unset | `=<CC>` writes `WIRELESS_REGDOM=<CC>` to `/etc/conf.d/wireless-regdom` (2-letter ISO 3166-1; e.g. `US`, `GB`, `DE`) |
| `RY_INSTALL_NO_INTERACTIVE_SUDO` | unset | `=1` refuses interactive `sudo -v` fallback (strict-unattended: cron, ansible, systemd unit) |
| `RY_INSTALL_NO_MATRIX` | unset | `=1` suppresses post-install run-summary matrix (JSONL log unaffected) |
| `NO_COLOR` | unset | Suppress ANSI color (any value, per [no-color.org](https://no-color.org/)) |

</details>

<details>
<summary><b>Logs</b></summary>

| Property | Value |
|---|---|
| Path | `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl` |
| Format | NDJSON, one file per run, no auto-rotation |
| Prune | `find ~/ry-install/logs -mtime +30 -delete` |
| Event `header` | Run metadata (`version`, `mode`, `argv`, etc.) |
| Event `log` | `{"ts":…,"data":STR}` |
| Event `footer` | `{…,"exit_code":N,"pass":N,"fail":N,"warn":N,"gen_fail":N}` |
| Footer marker | `interrupted` (signal), `cleanup_exit` (normal `fish_exit`), `bail` (preflight failure after header) |

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):")))' ~/ry-install/logs/**/*.jsonl
jq 'select(.event == "footer")' ~/ry-install/logs/**/*.jsonl
```

</details>

## Uninstall

No automated uninstaller. Use [Managed Files](#managed-files) as the
rollback source-of-truth:

1. `systemctl unmask` the 12 masked units.
2. `rm` deployed paths from the Managed Files list.
3. Restore `/etc/fstab` from your pre-install snapshot.
4. Optionally reverse package changes (`pacman -S <PKGS_DEL>`, `pacman -Rns <PKGS_ADD>`).
5. `sudo mkinitcpio -P && sudo sdboot-manage gen && sudo sdboot-manage update`.
6. Reboot.

## Known Issues

<details>
<summary><b>Strix Halo GPU</b></summary>

| Issue | Workaround |
|---|---|
| CWSR hang | `amdgpu.cwsr_enable=0` (already set) |
| MES page faults | Pin `linux-firmware` ≤ `20250808-1` or use `amdgpu-dkms-firmware` |
| ROCm VRAM allocation | Fixed in kernel 6.16+ |

</details>

<details>
<summary><b>MediaTek MT7925 WiFi</b></summary>

| Issue | Workaround |
|---|---|
| Kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| TX power 3 dBm / random deauth | None (cosmetic / upstream) |

</details>

<details>
<summary><b>Strix Halo ACP audio</b></summary>

| Issue | Workaround |
|---|---|
| `platform acp_asoc_acp70.0: warning: No matching ASoC machine driver found` (dmesg, once per boot); internal analog ACP path not routed | Pending upstream ASoC machine driver. HDMI (`snd_hda_intel`) and USB audio paths unaffected. |

</details>

<details>
<summary><b>NetworkManager + iwd</b></summary>

| Issue | Workaround |
|---|---|
| Boot connectivity failure (intermittent) | `nmcli radio wifi off && nmcli radio wifi on` |
| WPA2/3 Enterprise GUI broken | Use CLI or wpa_supplicant |

</details>

<details>
<summary><b>Other</b></summary>

| Issue | Workaround |
|---|---|
| Stale instance lock | Auto-reclaimed if PID is dead; manual `rm -rf ~/ry-install/.lock` only if `pgrep -af ry-install` is empty |
| `systemctl --user` skipped | Absent user-bus yields a skip-info; enable with `loginctl enable-linger $USER` |
| AUR PGP signature failure | `gpg --recv-keys <KEYID>` then re-run, or `paru -S <pkg>` without `--skipreview` |

</details>

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | Fix root cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
| Sudo cache expired | `sudo -v; and ./ry-install.fish` |
| `PKGS_DEL` member skipped | `RY_INSTALL_PKG_REMOVE_CASCADE=1`; inspect first with `pactree -ru <pkg>` |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| `.ry-install.*` orphan in `/etc` or `/boot/loader` | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, then re-run |
| `set-wireless-regdom` leaves cfg80211 in `world` domain | `echo 'WIRELESS_REGDOM="<CC>"' \| sudo tee /etc/conf.d/wireless-regdom` (e.g., `US`, `GB`, `DE`) |
| PipeWire `nice-level Permission denied` | `sudo gpasswd -a $USER realtime` then re-login (requires `realtime-privileges`, added by `PKGS_ADD`) |

## References

- [NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend)
- [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek)
- [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151)
- [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter)
- [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes)

## License

MIT © 2026 Ryan Musante
