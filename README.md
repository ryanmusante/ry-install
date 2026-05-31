# ry-install

**CachyOS configuration for the Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S.**

[![version](https://img.shields.io/badge/version-7.17.2-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46.svg)](https://fishshell.com/)
[![kernel](https://img.shields.io/badge/kernel-%E2%89%A5%206.14%20%286.18.4%2B%20rec.%29-orange.svg)](https://www.kernel.org/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
![license](https://img.shields.io/badge/license-MIT-green.svg)

---

## Contents

- [Quick Start](#quick-start)
- [Scope](#scope)
- [Prerequisites](#prerequisites)
- [Hardware](#hardware)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Run Summary](#run-summary)
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

Run as your normal user — root is refused, sudo is internal; without the exec bit, run `fish ry-install.fish`. **Post-install:** reboot (required for the cmdline, initramfs, and NM backend switch), then `--verify`; a full run takes 3–8 minutes. **Upgrading:** re-run `./ry-install.fish` — idempotent, no migration steps.

## Scope

**In:** kernel cmdline, initramfs, systemd units (system + user), network stack, sysctl, gaming env vars, pacman/paru install+remove, and systemd-boot BLS entries via `sdboot-manage`. **Out:** dotfiles, shells, editors, secrets, backups, multi-user, non-CachyOS distros, laptops, and UKI.

## Prerequisites

The platform and tooling the installer needs; an unmet requirement aborts in preflight, before any changes are made.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root |
| fish | ≥ 3.6 |
| Kernel | ≥ 6.14 (≥ 6.18.4 for gfx1151) |
| systemd | ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` |
| paru | required for AUR |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached credential (`sudo -v`) |

> [!WARNING]
> Sudo cache may lapse mid-run. Mitigate: `Defaults timestamp_timeout=60` (`sudo visudo`) or a `NOPASSWD` drop-in at `/etc/sudoers.d/ry-install`. Cron/systemd: pre-cache creds — the `sudo -v` fallback needs a TTY. Recovery: re-run.

```fish
./ry-install.fish --check        # idempotency probe
df -h / /boot                    # verify space
```

## Hardware

Ryzen AI Max+ 395 (Zen 5, gfx1151 iGPU) · Radeon 8060S (RDNA 3.5) · 128 GB LPDDR5x-8000. Runtime init requires a CPU matching `Ryzen AI Max`; the profile is gfx1151-specific, so override with `RY_INSTALL_SKIP_HARDWARE_CHECK=1` on other hardware.

## Usage

The command-line flags; run with no arguments for a full unattended install, or pass one of the flags below to verify, probe, or re-deploy a file.

| Flag | Action |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show install output (check ignores -V) |
| `--verify` | Config files + live system state (static, then runtime) |
| `--check` | Idempotency probe (0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy one managed file (absolute path) |
| `-h, --help` / `-v, --version` | Help / version |

## Install Flow

The installer runs these six phases in order; a package or boot-config failure taints the run and skips the Phase 5 boot rebuild.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | Prereqs + lock + runtime validate |
| 2 | Packages | `pacman -Syu --needed` + AUR via paru + cache refresh |
| 3 | Configuration | Deploy 13 embedded files (atomic) |
| 4 | Services | fstab + resolved + `PKGS_DEL` + mask + enable |
| 5 | Boot | `mkinitcpio -P` + `sdboot-manage` + sanity |
| 6 | Finalize | user daemon-reload + paccache + NM restart (deferred on active WiFi) |

## Run Summary

Prints a CHECK/RESULT/EVIDENCE matrix to stderr (+ totals, elapsed, verdict); JSONL records every `PHASE_RESULT`.

| Result | Semantics | | Verdict | Trigger |
|---|---|---|---|---|
| `PASS` | succeeded | | `PASS` | `0 FAIL · 0 WARN` |
| `WARN` | non-fatal anomaly | | `PASS-WITH-WARNINGS` | `0 FAIL · ≥1 WARN` |
| `FAIL` | failed (`INSTALL_HAD_ERRORS=true`) | | `FAIL` | `≥1 FAIL` |
| `DEFER` | deferred to next boot | | `FAIL-BOOT-CRITICAL` | boot cascade aborted; prints **DO NOT REBOOT** |
| `SKIP` / `N/A` | by design / not applicable | | | |

## Configuration

`--verify` compares installed files to embedded content byte-for-byte (static arm), then checks live state (runtime arm) — the script is the source of truth. Retune via `set -g` globals near the top. Phases 1, 5, 6 deploy no embedded data.

### Phase 1 — Preflight

Bootstrap (fish ≥ 3.6 + coreutils + PATH/TMPDIR/HOME) → `_init_runtime` (root UUID + CPU match + invariants) → lock (atomic `mkdir` 0700 + dead-PID reclaim) → sudo cache → deps (systemd ≥ 250 + paru ≥ 2.0.0) → disk space → network (HTTPS + ICMP) → time sync (NTP, systemd-timesyncd) → kernel (≥ 6.14 FAIL · ≥ 6.18.4 WARN · ntsync) → per-destination config validators.

### Phase 2 — Packages

`pacman -Syu --needed` (`PKGS_ADD`) → `paru` (`AUR_PKGS`) → optional `updatedb` / `pkgfile --update` indexers. `iwd`, `mesa`, and `cpupower` are CachyOS defaults, so they are not re-added; the iwd and NetworkManager configs still deploy unconditionally.

<details open>
<summary><b>Packages — install</b> — 13 pkgs</summary>

| Category | Packages |
|---|---|
| sysadmin | `nvme-cli`, `htop`, `git-delta`, `lm_sensors` |
| gaming | `cachyos-gaming-meta`, `cachyos-gaming-applications` |
| Vulkan/GL | `lib32-mesa` |
| rust utilities | `fd`, `sd`, `dust`, `procs`, `bottom` |
| perf | `realtime-privileges` |

</details>

The one AUR package the installer builds, pulled in unconditionally with no hardware gating.

<details open>
<summary><b>Packages — AUR</b> — 1 pkg</summary>

| Package | Purpose |
|---|---|
| `mkinitcpio-firmware` | firmware blobs not in `linux-firmware` |

</details>

The Vulkan/GL runtime packages, sourced from `chwd` and `PKGS_ADD`; `--verify` fails if any is missing.

<details open>
<summary><b>Vulkan dependencies</b> — 3 pkgs</summary>

| Package | Source |
|---|---|
| `vulkan-radeon` | `chwd` |
| `lib32-vulkan-radeon` | `chwd` |
| `lib32-mesa` | `PKGS_ADD` |

</details>

Rules that constrain every package transaction — full-upgrade policy, the AUR flag set, PGP-failure recovery, and reverse-dependency handling.

<details open>
<summary><b>Package caveats</b> — 4 notes</summary>

| Caveat | Detail |
|---|---|
| Full upgrades only | partial upgrades forbidden; `pacman -Syu --needed` always |
| AUR flags | `paru -S --needed --noconfirm --skipreview --cleanafter` (`--removemake` omitted — DKMS needs makedeps) |
| PGP failures | pre-import `gpg --recv-keys <KEYID>` or run `paru -S <pkg>` manually |
| Reverse deps | `PKGS_DEL` members held by outside rdeps are skipped (rdep detection needs `pacman-contrib`); remove manually with `pacman -Rns` if intended |

</details>

### Phase 3 — Configuration

Atomic write per file: `mktemp` in the destination's parent → render via `tee` → post-write symlink probe → `chmod` → `mv -T` (same-FS). The kernel cmdline is written to `/etc/kernel/cmdline` and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS`), with the root UUID prefix taken from the `/` mount.

<details open>
<summary><b>Kernel cmdline</b> — 16 params</summary>

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `preempt=full`, `split_lock_detect=off`, `tsc=reliable`, `processor.max_cstate=1` |
| GPU/amdgpu | `amdgpu.cwsr_enable=0`, `amdgpu.gpu_recovery=1`, `amdgpu.ppfeaturemask=0xfff73fff` |
| IOMMU/PCIe | `iommu=pt`, `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

</details>

Sets the `systemd-boot` loader defaults and the `sdboot-manage` policy that regenerates boot entries on every change.

<details open>
<summary><b>Bootloader</b> — 10 keys</summary>

| Scope | Settings |
|---|---|
| loader.conf | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| sdboot args | `LINUX_OPTIONS` = `KERNEL_PARAMS`, `LINUX_FALLBACK_OPTIONS=quiet` |
| sdboot entries | `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING=yes`, `OVERWRITE_EXISTING=yes`, `REMOVE_OBSOLETE=yes` |

</details>

The mkinitcpio fields; `_vmh_order_checks` enforces 11 HOOKS ordering invariants (`base` first, `fsck` last, no duplicates).

<details open>
<summary><b>Initramfs</b> — 6 fields</summary>

| Field | Value |
|---|---|
| `MODULES` | `(amdgpu)` |
| `BINARIES` / `FILES` | `()` / `()` |
| `HOOKS` | `(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` |
| `COMPRESSION` | `zstd`, `COMPRESSION_OPTIONS (-1 -T0)` |

</details>

Tunes `systemd-resolved`: multicast DNS on, LLMNR off, opportunistic DNS-over-TLS, and downgrade-tolerant DNSSEC.

<details open>
<summary><b>systemd-resolved</b> — 4 keys</summary>

| Key | Value |
|---|---|
| `MulticastDNS` | `resolve` |
| `LLMNR` | `no` |
| `DNSOverTLS` | `opportunistic` |
| `DNSSEC` | `allow-downgrade` |

</details>

Stops accidental power events — the power, suspend, hibernate, and reboot keys (and their long-press variants) are all set to `ignore`.

<details open>
<summary><b>systemd-logind</b> — 8 keys</summary>

| Key | Value |
|---|---|
| `HandlePowerKey` / `HandlePowerKeyLongPress` | `ignore` |
| `HandleSuspendKey` / `HandleSuspendKeyLongPress` | `ignore` |
| `HandleHibernateKey` / `HandleHibernateKeyLongPress` | `ignore` |
| `HandleRebootKey` / `HandleRebootKeyLongPress` | `ignore` |

</details>

Configures `iwd`: it stops managing IP itself, disables power-save, and defers name resolution to systemd.

<details open>
<summary><b>iwd</b> — 3 keys</summary>

| Section | Key | Value |
|---|---|---|
| `[General]` | `EnableNetworkConfiguration` | `false` |
| `[DriverQuirks]` | `PowerSaveDisable` | `*` |
| `[Network]` | `NameResolvingService` | `systemd` |

</details>

Switches NetworkManager to the `iwd` backend, disables WiFi power-save, and lowers logging to `WARN`.

<details open>
<summary><b>NetworkManager</b> — 3 keys</summary>

| Section | Key | Value |
|---|---|---|
| `[device]` | `wifi.backend` | `iwd` |
| `[connection]` | `wifi.powersave` | `2` |
| `[logging]` | `level` | `WARN` |

</details>

Pins the CPU frequency governor to `powersave`, sourced by `cpupower.service`.

<details open>
<summary><b>cpupower-service</b> — 1 key</summary>

| Key | Value |
|---|---|
| `GOVERNOR` | `powersave` (sourced by `cpupower.service`) |

</details>

Network and VM tunables at priority 95, loaded after CachyOS `70-cachyos-settings.conf`.

<details open>
<summary><b>sysctl</b> — 7 tunables</summary>

| Key | Value |
|---|---|
| `net.core.default_qdisc` | `fq` |
| `net.core.netdev_budget` | `600` |
| `net.core.netdev_budget_usecs` | `5000` |
| `net.ipv4.tcp_congestion_control` | `bbr` |
| `net.ipv4.tcp_notsent_lowat` | `16384` |
| `net.ipv4.tcp_slow_start_after_idle` | `0` |
| `vm.compaction_proactiveness` | `0` |

</details>

Caps the TTM GTT pool at 64 GiB for gfx1151 ROCm (ROCm#5595); applied on next initramfs rebuild; `--verify` greps both keys.

<details open>
<summary><b>amdgpu / ttm modprobe</b> — 2 options</summary>

| Option | Value |
|---|---|
| `ttm pages_limit` | `16777216` |
| `ttm page_pool_size` | `16777216` |

</details>

Unified VRAM heap for all Vulkan apps on gfx1151 (Mesa MR!18884); applied at next Vulkan/GL launch; `--verify` greps the option and checks XML via `xmllint`.

<details open>
<summary><b>RADV drirc</b> — 1 option</summary>

| Option | Value |
|---|---|
| `radv_enable_unified_heap_on_apu` | `true` |

</details>

The gaming and debug environment, loaded by `systemd --user` (`0600`); apply it live via re-login or `systemctl --user import-environment`.

<details open>
<summary><b>Env vars</b> — 10 keys</summary>

| Category | Vars |
|---|---|
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Mesa/RADV | `MESA_SHADER_CACHE_MAX_SIZE=16G`, `AMD_VULKAN_ICD=RADV` |
| Wine | `WINEDEBUG=-all` |

</details>

### Phase 4 — Services

fstab rewrite → `systemd-resolved` restart → `PKGS_DEL` removal → mask `--now` 11 units → `daemon-reload` + enable runtime units. The fstab rewrite strips conflicting `atime`/`relatime`/`strictatime`/`defaults`/`commit=*` and is gated by `findmnt --verify`; **there is no auto-backup, so snapshot `/etc/fstab` first.**

<details open>
<summary><b>fstab</b> — 3 ext4 mount options</summary>

| Option | Effect |
|---|---|
| `noatime` | no access-time writes |
| `lazytime` | deferred timestamp writeback |
| `commit=10` | 10 s journal commit interval |

</details>

Packages removed during install — the Plymouth boot-splash stack (incompatible with `quiet`) and the `micro` editor. **Opt-in:** add `shelly` by uncommenting it in `PKGS_DEL` and bumping invariant 7→8.

<details open>
<summary><b>Packages — remove</b> — 7 pkgs</summary>

| Package | Category |
|---|---|
| `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm` | boot splash (incompatible with `quiet`; Plasma rdeps enumerated) |
| `micro`, `cachyos-micro-settings` | text editor |

</details>

Units stopped and masked with `--now` — replaced daemons, the unused `ufw` firewall, a boot-delay service, and all sleep/suspend targets.

<details open>
<summary><b>Masked units</b> — 11 units</summary>

| Category | Units |
|---|---|
| Replaced daemons | `ananicy-cpp.service`, `avahi-daemon.{service,socket}`, `power-profiles-daemon.service` |
| Unused subsys | `ufw.service` (rules flushed pre-mask) |
| Boot delays | `NetworkManager-wait-online.service` |
| Power states | `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` |

</details>

Runtime units enabled after the reload — weekly `fstrim`, NetworkManager, and `cpupower`; `NetworkManager-dispatcher.service` is also enabled when present.

<details open>
<summary><b>Enabled units</b> — 3 units</summary>

| Unit | Note |
|---|---|
| `fstrim.timer` | weekly TRIM |
| `NetworkManager.service` | deduped via `_RY_PKG_MANAGED_SERVICES` |
| `cpupower.service` | oneshot — `active`/`exited` |

</details>

### Phase 5 — Boot

`mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update` → post-rebuild sanity (`vmlinuz-*` + `initramfs-*.img` + loader-entry kernel path; emits **DO NOT REBOOT** on failure).

### Phase 6 — Finalize

`systemctl --user daemon-reload` (skipped without active user-bus) → pacman cache trim (`paccache -rk2 -ruk0`, falls back to `pacman -Sc`) → NetworkManager restart for the wpa_supplicant → iwd switch (deferred to reboot when WiFi is the active route).

## Managed Files

13 files via the [Phase 3](#phase-3--configuration) atomic-write sequence; system `0644`, user `0600`.

<details open>
<summary><b>Destinations</b> — 13 paths</summary>

| Path | Mode |
|---|---|
| `/boot/loader/loader.conf` | `0644` |
| `/etc/kernel/cmdline` | `0644` |
| `/etc/sdboot-manage.conf` | `0644` |
| `/etc/mkinitcpio.conf` | `0644` |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | `0644` |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | `0644` |
| `/etc/iwd/main.conf` | `0644` |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `0644` |
| `/etc/default/cpupower-service.conf` | `0644` |
| `/etc/sysctl.d/95-ry-overrides.conf` | `0644` |
| `/etc/drirc.d/95-ry-radv-apu.conf` | `0644` |
| `/etc/modprobe.d/ry-amdgpu-strixhalo.conf` | `0644` |
| `~/.config/environment.d/10-environment.conf` | `0600` |

</details>

## Safety & Reliability

How the installer protects the system — atomic writes, automatic backups, file locking, fstab gating, and rollback on failure.

| Feature | Detail |
|---|---|
| Atomic writes | tmp → render → symlink probe → chmod → `mv -T` |
| Auto backups | `<path>.ry.bak` written before overwriting `loader.conf`/`mkinitcpio.conf`; restored on post-write byte-mismatch (fstab excluded) |
| Permissions | system `0644` · user `0600` · `~/ry-install/` `0700` |
| fstab | `findmnt --verify` gate; rejects symlinked `/etc/fstab` |
| Boot rebuild gate | skipped on package/boot-config failure; `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint only |
| mkinitcpio rollback | byte-exact revert on `pacman -Syu` failure or signal |
| Instance lock | atomic mkdir `0700`; reclaims dead-PID lock via `kill -0` |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT → 128+signum; SIGPIPE/WINCH non-fatal |
| Firewall posture | host firewall (ufw) disabled+masked — trusted-LAN assumption; install emits a warning, `--verify` reports `ufw=<state> nft_rules=<n>` |

Every exit status the script returns, by class — success, verify/usage, preflight/boot/lock, `--check` drift, generation errors, and signals.

<details open>
<summary><b>Exit codes</b></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or kernel-floor fail / usage |
| `3` / `4` / `5` | preflight / boot-critical / lock |
| `10` | `--check` drift |
| `11` / `12` / `13` | gen: missing fn / missing UUID / sysctl malformed |
| `128+N` / `251` | signal (130=INT, 143=TERM, …) / `_run` tmpfile alloc fail |

</details>

Environment variables that override defaults — run timeout, the two gate bypasses, and color suppression.

<details open>
<summary><b>Runtime variables</b> — 4 vars</summary>

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | `_run` cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` |
| `NO_COLOR` | unset | suppress ANSI color |

</details>

NDJSON at `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`, one per run, no rotation. Events `header`/`log`/`footer` (carry `ts` + `event`); footer marker `bail` (preflight) or `interrupted` (signal). Prune: `find ~/ry-install/logs -xdev -type f -mtime +30 -delete`.

<details open>
<summary><b>Logs</b></summary>

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):")))' ~/ry-install/logs/**/*.jsonl
```

</details>

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference:

1. `sudo systemctl unmask` the 11 masked units (stopped by `--now`; reboot or start to restore).
2. `sudo rm` deployed paths from the Managed Files list.
3. Restore `/etc/fstab` from your pre-install snapshot.
4. Optionally reverse package changes (`sudo pacman -S <PKGS_DEL>`, `sudo pacman -Rns <PKGS_ADD>`).
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

Known hardware and software quirks on this platform, each with a workaround or its upstream status.

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | `paru -S amdgpu-dkms-firmware` or `IgnorePkg=linux-firmware` |
| Strix Halo GPU | ROCm VRAM allocation | kernel 6.16+ (`pacman -Syu linux-cachyos`) |
| MT7925 | kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| MT7925 | TX power 3 dBm / random deauth | none (upstream) |
| RTL8127 10GbE | throughput drops under load (BBS#7762) | `paru -S r8127-dkms` |
| Strix Halo ACP | `No matching ASoC machine driver` | pending upstream; HDMI/USB audio unaffected |
| NM + iwd | intermittent boot connectivity | `nmcli radio wifi off; and nmcli radio wifi on` |
| NM + iwd | WPA2/3 Enterprise GUI broken | CLI or wpa_supplicant |
| Lock / user-bus | stale lock / `systemctl --user` skipped | dead-PID auto-reclaim; `loginctl enable-linger $USER` |
| AUR | PGP signature failure | `gpg --recv-keys <KEYID>` then re-run |

## Troubleshooting

Common failure modes during or after install, each with its fix.

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | fix cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Sudo cache expired | re-run re-primes; see Prerequisites warning |
| `PKGS_DEL` member skipped | held by outside rdeps — remove manually with `sudo pacman -Rns <pkg>` |
| ntsync missing | kernel 6.14+ · `ls /dev/ntsync` |
| `.ry-install.*` orphan | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, re-run |
| PipeWire `nice-level` denied | `sudo usermod -aG realtime $USER`, re-login |
| Kernel 6.19.0 black screen | `pacman -Syu` (≥6.19.1) ([CachyOS #23042](https://github.com/CachyOS/CachyOS/issues/23042)) |
| iwd edits not applied | `sudo systemctl try-restart iwd.service` |

## References

[NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) · [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) · [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) · [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) · [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) · [CachyOS #23042](https://github.com/CachyOS/CachyOS/issues/23042)

## License

MIT © 2026 Ryan Musante · `SPDX-License-Identifier: MIT`
