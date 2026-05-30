# ry-install

**CachyOS configuration for the Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S.**

[![version](https://img.shields.io/badge/version-7.14.1-blue.svg)](CHANGELOG.md)
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

Run as your normal user — root is refused; sudo is invoked internally. If you cannot set the executable bit, use `fish ry-install.fish`.

**Post-install:** reboot (required for cmdline, initramfs, NM backend switch), then `--verify-static` and `--verify-runtime`. Typical duration: **3–8 minutes**.

**Upgrading:** re-run `./ry-install.fish` — idempotent, no manual migration steps.

## Scope

**In:** kernel cmdline, initramfs, systemd units (system + user), network stack, sysctl, gaming env vars, pacman/paru install+remove, systemd-boot BLS entries via `sdboot-manage`.

**Out:** dotfiles, shells, editors, secrets, backups, multi-user, non-CachyOS distros, laptops, UKI.

## Prerequisites

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
> Sudo cache may lapse during the 3–8 min run. Mitigate with `Defaults timestamp_timeout=60` (via `sudo visudo`) or a `NOPASSWD` drop-in at `/etc/sudoers.d/ry-install`. For cron/systemd, pre-cache credentials first — the interactive `sudo -v` fallback needs a TTY on stdin+stderr and is skipped without one. Recovery: re-run — idempotent.

```fish
./ry-install.fish --check        # idempotency probe
df -h / /boot                    # verify space
```

## Hardware

Ryzen AI Max+ 395 (Zen 5, gfx1151 iGPU) · Radeon 8060S (RDNA 3.5) · 128 GB LPDDR5x-8000.

Runtime init requires CPU matching `Ryzen AI Max`; override via `RY_INSTALL_SKIP_HARDWARE_CHECK=1` (profile is amdgpu/gfx1151-specific).

## Usage

| Flag | Action |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show install output (check ignores -V) |
| `--verify-static` | Files match embedded content |
| `--verify-runtime` | Live system state (post-reboot) |
| `--check` | Idempotency probe (0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy one managed file (absolute path) |
| `-h, --help` / `-v, --version` | Help / version |

## Install Flow

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | Prereqs + lock + runtime validate |
| 2 | Packages | `pacman -Syu --needed` + AUR via paru + cache refresh |
| 3 | Configuration | Deploy 13 embedded files (atomic) |
| 4 | Services | fstab + resolved + `PKGS_DEL` + mask + enable |
| 5 | Boot | `mkinitcpio -P` + `sdboot-manage` + sanity |
| 6 | Finalize | user daemon-reload + paccache + NM restart (deferred on active WiFi) |

## Run Summary

Install prints a box-drawn CHECK/RESULT/EVIDENCE matrix to stderr + totals + elapsed + verdict (JSONL still records every `PHASE_RESULT`).

| Result | Semantics | | Verdict | Trigger |
|---|---|---|---|---|
| `PASS` | succeeded | | `PASS` | `0 FAIL · 0 WARN` |
| `WARN` | non-fatal anomaly | | `PASS-WITH-WARNINGS` | `0 FAIL · ≥1 WARN` |
| `FAIL` | failed (`INSTALL_HAD_ERRORS=true`) | | `FAIL` | `≥1 FAIL` |
| `DEFER` | deferred to next boot | | `FAIL-BOOT-CRITICAL` | boot cascade aborted; prints **DO NOT REBOOT** |
| `SKIP` / `N/A` | by design / not applicable | | | |

## Configuration

`--verify-static` compares installed files against embedded content byte-for-byte; the script is the source of truth. Edit `set -g` globals near the top to retune. Phases 1, 5, 6 deploy no embedded data.

### Phase 1 — Preflight

Bootstrap (fish ≥ 3.6 + coreutils + PATH/TMPDIR/HOME) → `_init_runtime` (root UUID + CPU match + invariants) → lock (atomic `mkdir` 0700 + dead-PID reclaim) → sudo cache → deps (systemd ≥ 250 + paru ≥ 2.0.0) → disk space → network (HTTPS + ICMP) → time sync (NTP, systemd-timesyncd) → kernel (≥ 6.14 FAIL · ≥ 6.18.4 WARN · ntsync) → per-destination config validators.

### Phase 2 — Packages

`pacman -Syu --needed` (`PKGS_ADD`) → `paru` (`AUR_PKGS`) → optional `updatedb` / `pkgfile --update` indexers.

<details open>
<summary><b>Packages — install</b> — 13 pkgs</summary>

| Category | Packages |
|---|---|
| sysadmin | `nvme-cli`, `htop`, `git-delta`, `lm_sensors` |
| gaming | `cachyos-gaming-meta`, `cachyos-gaming-applications` |
| Vulkan/GL | `lib32-mesa` |
| rust utilities | `fd`, `sd`, `dust`, `procs`, `bottom` |
| perf | `realtime-privileges` |

`iwd`, `mesa`, `cpupower` are CachyOS defaults — not re-added; iwd/NM configs deploy unconditionally.

</details>

<details open>
<summary><b>Packages — AUR</b> — 1 pkg</summary>

| Package | Purpose |
|---|---|
| `mkinitcpio-firmware` | firmware blobs not in `linux-firmware` |

The AUR package is installed unconditionally (no hardware gating).

</details>

<details open>
<summary><b>Vulkan dependencies</b> — 3 pkgs</summary>

| Package | Source |
|---|---|
| `vulkan-radeon` | `chwd` |
| `lib32-vulkan-radeon` | `chwd` |
| `lib32-mesa` | `PKGS_ADD` |

`--verify-runtime` fails on any missing.

</details>

<details open>
<summary><b>Package caveats</b> — 4 notes</summary>

| Caveat | Detail |
|---|---|
| Full upgrades only | partial upgrades forbidden; `pacman -Syu --needed` always |
| AUR flags | `paru -S --needed --noconfirm --skipreview --cleanafter` (`--removemake` omitted — DKMS needs makedeps) |
| PGP failures | pre-import `gpg --recv-keys <KEYID>` or run `paru -S <pkg>` manually |
| Reverse deps | `PKGS_DEL` members held by outside rdeps are skipped (rdep detection needs `pacman-contrib`); remove manually with `pacman -Rns` if intended |

</details>

### Phase 3 — Configuration Files

Atomic write per file: `mktemp` in destination's parent → render via `tee` → post-write symlink probe → `chmod` → `mv -T` (same-FS).

<details open>
<summary><b>Kernel cmdline</b> — 17 params</summary>

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `preempt=full`, `split_lock_detect=off`, `tsc=reliable`, `processor.max_cstate=1` |
| GPU/amdgpu | `amdgpu.cwsr_enable=0`, `amdgpu.gpu_recovery=1`, `amdgpu.ppfeaturemask=0xfff73fff`, `amdgpu.sg_display=0` |
| IOMMU/PCIe | `iommu=pt`, `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

Deployed to `/etc/kernel/cmdline` and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS`); root UUID prefix from the `/` mount.

</details>

<details open>
<summary><b>Bootloader</b> — 10 keys</summary>

| Scope | Settings |
|---|---|
| loader.conf | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| sdboot args | `LINUX_OPTIONS` = `KERNEL_PARAMS`, `LINUX_FALLBACK_OPTIONS=quiet` |
| sdboot entries | `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING=yes`, `OVERWRITE_EXISTING=yes`, `REMOVE_OBSOLETE=yes` |

</details>

<details open>
<summary><b>Initramfs</b> — 6 fields</summary>

| Field | Value |
|---|---|
| `MODULES` | `(amdgpu)` |
| `BINARIES` / `FILES` | `()` / `()` |
| `HOOKS` | `(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` |
| `COMPRESSION` | `zstd`, `COMPRESSION_OPTIONS (-1 -T0)` |

11 ordering invariants enforced by `_vmh_order_checks` (`base` first, `fsck` last, no dupes).

</details>

<details open>
<summary><b>systemd-resolved</b> — 4 keys</summary>

| Key | Value |
|---|---|
| `MulticastDNS` | `resolve` |
| `LLMNR` | `no` |
| `DNSOverTLS` | `opportunistic` |
| `DNSSEC` | `allow-downgrade` |

</details>

<details open>
<summary><b>systemd-logind</b> — 9 keys</summary>

| Key | Value |
|---|---|
| `HandlePowerKey` / `HandlePowerKeyLongPress` | `ignore` |
| `HandleSuspendKey` / `HandleSuspendKeyLongPress` | `ignore` |
| `HandleHibernateKey` / `HandleHibernateKeyLongPress` | `ignore` |
| `HandleRebootKey` / `HandleRebootKeyLongPress` | `ignore` |
| `HandleSecureAttentionKey` (systemd ≥ 257) | `ignore` |

</details>

<details open>
<summary><b>iwd</b> — 3 keys</summary>

| Section | Key | Value |
|---|---|---|
| `[General]` | `EnableNetworkConfiguration` | `false` |
| `[DriverQuirks]` | `PowerSaveDisable` | `*` |
| `[Network]` | `NameResolvingService` | `systemd` |

</details>

<details open>
<summary><b>NetworkManager</b> — 3 keys</summary>

| Section | Key | Value |
|---|---|---|
| `[device]` | `wifi.backend` | `iwd` |
| `[connection]` | `wifi.powersave` | `2` |
| `[logging]` | `level` | `WARN` |

</details>

<details open>
<summary><b>cpupower-service</b> — 1 key</summary>

| Key | Value |
|---|---|
| `GOVERNOR` | `powersave` (sourced by `cpupower.service`) |

</details>

<details open>
<summary><b>sysctl</b> — 9 tunables</summary>

| Key | Value |
|---|---|
| `net.core.busy_poll`, `net.core.busy_read` | `50` |
| `net.core.default_qdisc` | `fq` |
| `net.core.netdev_budget` | `600` |
| `net.core.netdev_budget_usecs` | `5000` |
| `net.ipv4.tcp_congestion_control` | `bbr` |
| `net.ipv4.tcp_notsent_lowat` | `16384` |
| `net.ipv4.tcp_slow_start_after_idle` | `0` |
| `vm.compaction_proactiveness` | `0` |

Priority 95 — loaded after CachyOS `70-cachyos-settings.conf`.

</details>

<details open>
<summary><b>amdgpu / ttm modprobe</b> — 2 options</summary>

| Option | Value |
|---|---|
| `ttm pages_limit` | `16777216` |
| `ttm page_pool_size` | `16777216` |

Caps TTM GTT pool at 64 GiB for gfx1151 ROCm (ROCm#5595). Applied on next initramfs rebuild.

</details>

<details open>
<summary><b>RADV drirc</b> — 1 option</summary>

| Option | Value |
|---|---|
| `radv_enable_unified_heap_on_apu` | `true` |

Unified VRAM heap for all Vulkan apps on gfx1151 (Mesa MR!18884 extended beyond RDR2). Applied at next Vulkan/GL launch.

</details>

<details open>
<summary><b>Env vars</b> — 10 keys</summary>

| Category | Vars |
|---|---|
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Mesa/RADV | `MESA_SHADER_CACHE_MAX_SIZE=16G`, `AMD_VULKAN_ICD=RADV` |
| Wine | `WINEDEBUG=-all` |

Loaded by `systemd --user` (`0600`). Re-login or `systemctl --user import-environment` to apply live.

</details>

### Phase 4 — Services

fstab rewrite → `systemd-resolved` restart → `PKGS_DEL` removal → mask 12 units → `daemon-reload` + enable runtime units.

<details open>
<summary><b>fstab</b> — 3 ext4 mount options</summary>

| Option | Effect |
|---|---|
| `noatime` | no access-time writes |
| `lazytime` | deferred timestamp writeback |
| `commit=10` | 10 s journal commit interval |

Idempotent rewrite strips conflicting `atime`/`relatime`/`strictatime`/`defaults`/`commit=*`; `findmnt --verify` gates the atomic `mv`. **No automatic backup — snapshot `/etc/fstab` first.**

</details>

<details open>
<summary><b>Packages — remove</b> — 7 pkgs</summary>

| Package | Category |
|---|---|
| `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm` | boot splash (incompatible with `quiet`; Plasma rdeps enumerated) |
| `micro`, `cachyos-micro-settings` | text editor |

**Opt-in:** `shelly` — uncomment in `PKGS_DEL` + bump invariant 7→8.

</details>

<details open>
<summary><b>Masked units</b> — 12 units</summary>

| Category | Units |
|---|---|
| Replaced daemons | `ananicy-cpp.service`, `avahi-daemon.{service,socket}`, `power-profiles-daemon.service` |
| Unused subsys | `lvm2-monitor.service`, `ufw.service` (rules flushed pre-mask) |
| Boot delays | `NetworkManager-wait-online.service` |
| Power states | `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` |

</details>

<details open>
<summary><b>Enabled units</b> — 3 units</summary>

| Unit | Note |
|---|---|
| `fstrim.timer` | weekly TRIM |
| `NetworkManager.service` | deduped via `_RY_PKG_MANAGED_SERVICES` |
| `cpupower.service` | oneshot — `active`/`exited` |

`NetworkManager-dispatcher.service` enabled when present.

</details>

### Phase 5 — Boot

`mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update` → post-rebuild sanity (`vmlinuz-*` + `initramfs-*.img` + loader-entry kernel path; emits **DO NOT REBOOT** on failure).

### Phase 6 — Finalize

`systemctl --user daemon-reload` (skipped without active user-bus) → pacman cache trim (`paccache -rk2 -ruk0`, falls back to `pacman -Sc`) → NetworkManager restart for the wpa_supplicant → iwd switch (deferred to reboot when WiFi is the active route).

## Managed Files

13 files deployed via the [Phase 3](#phase-3--configuration-files) atomic-write sequence. System files install `0644`, the user file `0600`.

<details>
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

<details>
<summary><b>Exit codes</b></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or kernel-floor fail / usage |
| `3` / `4` / `5` | preflight / boot-critical / lock |
| `10` | `--check` drift |
| `11` / `12` / `13` | gen: missing fn / missing UUID / sysctl malformed |
| `128+N` / `251` | signal (130=INT, 143=TERM, …) / `_run` tmpfile alloc fail |

</details>

<details>
<summary><b>Runtime variables</b> — 4 vars</summary>

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | `_run` cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` |
| `NO_COLOR` | unset | suppress ANSI color |

</details>

<details>
<summary><b>Logs</b></summary>

NDJSON at `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`, one file per run, no rotation. Events `header`/`log`/`footer` (all carry `ts` + `event`); footer marker `bail` (preflight) or `interrupted` (signal). Prune: `find ~/ry-install/logs -xdev -type f -mtime +30 -delete`.

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):")))' ~/ry-install/logs/**/*.jsonl
```

</details>

## Uninstall

No automated uninstaller. Use [Managed Files](#managed-files) as the rollback source-of-truth:

1. `sudo systemctl unmask` the 12 masked units.
2. `sudo rm` deployed paths from the Managed Files list.
3. Restore `/etc/fstab` from your pre-install snapshot.
4. Optionally reverse package changes (`sudo pacman -S <PKGS_DEL>`, `sudo pacman -Rns <PKGS_ADD>`).
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

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

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | fix cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
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
