# ry-install

**CachyOS configuration for the Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S.**

[![version](https://img.shields.io/badge/version-7.18.0-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46.svg)](https://fishshell.com/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
![license](https://img.shields.io/badge/license-MIT-green.svg)

---

## Contents

1. [Quick Start](#quick-start)
2. [Scope](#scope)
3. [Prerequisites](#prerequisites)
4. [Hardware](#hardware)
5. [Usage](#usage)
6. [Install Flow](#install-flow)
7. [Run Summary](#run-summary)
8. [Configuration](#configuration)
9. [Managed Files](#managed-files)
10. [Safety & Reliability](#safety--reliability)
11. [Uninstall](#uninstall)
12. [Known Issues](#known-issues)
13. [Troubleshooting](#troubleshooting)
14. [References](#references)
15. [License](#license)

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

Run as your normal user (root refused, sudo internal). Post-install: reboot, then `--verify`; a full run takes 3–8 minutes. Upgrading: re-run `./ry-install.fish` — idempotent.

## Scope

**In:** kernel cmdline, initramfs, systemd units (system + user), network stack, sysctl, gaming env vars, pacman/paru install+remove, and systemd-boot BLS entries via `sdboot-manage`. **Out:** dotfiles, shells, editors, secrets, backups, multi-user, non-CachyOS distros, laptops, and UKI.

## Prerequisites

Hard requirements (sudo cache, systemd ≥ 250, GNU coreutils, free disk, network, config validity) abort read-only in preflight (exit 3); retry after fixing the cause. paru and NTP sync only warn.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root |
| fish | ≥ 3.6 |
| systemd | ≥ 250 |
| curl | required (HTTPS preflight + connectivity check) |
| Hardware | CPU matches `Ryzen AI Max` |
| paru | recommended ≥ 2.0.0 (AUR phase warns + continues if absent) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached credential (`sudo -v`) |

> [!WARNING]
> Sudo cache may lapse mid-run. Mitigate: `Defaults timestamp_timeout=60` (`sudo visudo`) or a `NOPASSWD` drop-in at `/etc/sudoers.d/ry-install`. Cron/systemd: pre-cache creds — the `sudo -v` fallback needs a TTY. Recovery: re-run.

```fish
./ry-install.fish --check        # idempotency probe
df -h / /boot                    # verify space
```

## Hardware

Ryzen AI Max+ 395 (Zen 5, gfx1151) · Radeon 8060S (RDNA 3.5) · 128 GB LPDDR5x-8000. Runtime init requires a CPU matching `Ryzen AI Max`; override on other hardware with `RY_INSTALL_SKIP_HARDWARE_CHECK=1`.

## Usage

No arguments runs a full unattended install. `--check` and `--verify` only read state; only the no-argument run and `--install-file` write to disk.

| Flag | Action |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show install output (check ignores -V) |
| `--verify` | Config files + live system state (static, then runtime) |
| `--check` | Idempotency probe (0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy one managed file (absolute path) |
| `--country=XX` | Override the wireless regulatory domain (ISO-3166 alpha-2; default `US`) |
| `-h, --help` / `-v, --version` | Help / version |

## Install Flow

Six phases run in order; a package or boot-config failure taints the run and skips the Phase 5 rebuild. Phase 3 writes are atomic renames, so an aborted run leaves each managed file fully old or fully new.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | Prereqs + lock + runtime validate |
| 2 | Packages | `pacman -Syu --needed` + AUR via paru + cache refresh |
| 3 | Configuration | Deploy 16 embedded files (atomic) |
| 4 | Services | fstab + resolved + `PKGS_DEL` + mask + enable |
| 5 | Boot | `mkinitcpio -P` + `sdboot-manage` + sanity |
| 6 | Finalize | user daemon-reload + paccache + NM restart (deferred on active WiFi) |

## Run Summary

Prints a CHECK/RESULT/EVIDENCE matrix (+ totals, elapsed, verdict) to stderr; JSONL under `~/ry-install/logs/` records every `PHASE_RESULT` plus a `MATRIX_RENDERED` event — the durable per-phase record once output scrolls away. The matrix verdict maps to the exit code; the JSONL `footer` `pass`/`fail`/`warn` are message-level tallies and need not equal the phase-matrix counts.

Per-phase result:

| Result | Semantics |
|---|---|
| `PASS` | succeeded |
| `WARN` | non-fatal anomaly (never taints the run; exit stays `0`) |
| `FAIL` | failed — the only result that sets `INSTALL_HAD_ERRORS=true` |
| `DEFER` | deferred to next boot |
| `SKIP` / `N/A` | by design / not applicable |

Overall verdict and the exit code it maps to. A run that is all `PASS`/`WARN` exits `0`. One preflight-stage outcome bypasses this table: a hard-requirement abort exits `3`.

| Verdict | Trigger | Exit |
|---|---|---|
| `PASS` | `0 FAIL · 0 WARN` | `0` |
| `PASS-WITH-WARNINGS` | `0 FAIL · ≥1 WARN` | `0` |
| `FAIL` | `≥1 FAIL` | `1` |
| `FAIL-BOOT-CRITICAL` | boot cascade aborted; prints **DO NOT REBOOT** | `4` |

## Configuration

The script is the source of truth — `--verify` checks embedded files byte-for-byte, then live state; retune via `set -g` globals near the top. Phases 1, 5, and 6 deploy no files.

### Phase 1 — Preflight

Bootstrap (fish ≥ 3.6 + coreutils + PATH/TMPDIR/HOME) → `_init_runtime` (root UUID + CPU match + invariants) → lock (atomic `mkdir` 0700 + dead-PID reclaim) → sudo cache → deps (systemd ≥ 250 hard-gate · paru ≥ 2.0.0 advisory) → disk space → network (HTTPS + ICMP) → time sync (NTP, systemd-timesyncd) → per-destination config validators.

### Phase 2 — Packages

`pacman -Syu --needed` (`PKGS_ADD`) → `paru` (`AUR_PKGS`) → optional `updatedb` / `pkgfile --update`. `iwd`, `mesa`, and `cpupower` are CachyOS defaults (not re-added); the iwd and NetworkManager configs still deploy. The AUR step is advisory: a missing `paru` or a *partial* AUR failure is recorded `WARN` and the install continues (exit `0`); only an AUR step where **every** package fails is a `FAIL` (exit `1`). A `pacman -Syu` failure, by contrast, taints the run and skips the Phase 5 rebuild.

<details open>
<summary><b>Packages — install</b> — 16 pkgs</summary>

| Category | Packages |
|---|---|
| sysadmin | `nvme-cli`, `htop`, `git-delta`, `lm_sensors`, `iw` |
| gaming | `cachyos-gaming-meta`, `cachyos-gaming-applications` |
| Vulkan/GL | `lib32-mesa` |
| rust utilities | `fd`, `sd`, `dust`, `procs`, `bottom` |
| perf | `realtime-privileges`, `rtkit` |
| display | `ddcutil` (loads `i2c-dev`) |

</details>

<details open>
<summary><b>Packages — AUR</b> — 1 pkg</summary>

| Package | Purpose |
|---|---|
| `mkinitcpio-firmware` | firmware blobs not in `linux-firmware` |

</details>

<details open>
<summary><b>Vulkan dependencies</b> — 3 pkgs</summary>

| Package | Source |
|---|---|
| `vulkan-radeon` | `chwd` |
| `lib32-vulkan-radeon` | `chwd` |
| `lib32-mesa` | `PKGS_ADD` |

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

### Phase 3 — Configuration

Atomic write per file: `mktemp` in the destination parent → render via `tee` → symlink probe → `chmod` → `mv -T` (same-FS). The kernel cmdline goes to `/etc/kernel/cmdline` and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS`); root UUID prefix is taken from the `/` mount.

<details open>
<summary><b>Kernel cmdline</b> — 13 params</summary>

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `preempt=full`, `split_lock_detect=off`, `tsc=reliable` |
| GPU/amdgpu | `amdgpu.ppfeaturemask=0xffffffff` |
| IOMMU/PCIe | `iommu=pt`, `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

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

</details>

<details open>
<summary><b>systemd-resolved</b> — 4 keys</summary>

| Key | Value |
|---|---|
| `MulticastDNS` | `resolve` |
| `LLMNR` | `no` |
| `DNSOverTLS` | `no` |
| `DNSSEC` | `allow-downgrade` |

</details>

<details open>
<summary><b>systemd-logind</b> — 8 keys</summary>

| Key | Value |
|---|---|
| `HandlePowerKey` / `HandlePowerKeyLongPress` | `ignore` |
| `HandleSuspendKey` / `HandleSuspendKeyLongPress` | `ignore` |
| `HandleHibernateKey` / `HandleHibernateKeyLongPress` | `ignore` |
| `HandleRebootKey` / `HandleRebootKeyLongPress` | `ignore` |

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
<summary><b>sysctl</b> — 8 tunables</summary>

| Key | Value |
|---|---|
| `net.core.default_qdisc` | `fq` |
| `net.core.netdev_budget` | `600` |
| `net.core.netdev_budget_usecs` | `5000` |
| `net.ipv4.tcp_congestion_control` | `bbr` |
| `net.ipv4.tcp_notsent_lowat` | `16384` |
| `net.ipv4.tcp_slow_start_after_idle` | `0` |
| `vm.compaction_proactiveness` | `0` |
| `vm.max_map_count` | `2147483642` |

</details>

<details open>
<summary><b>amdgpu / ttm modprobe</b> — 2 options (caps GTT at 32 GiB)</summary>

| Option | Value |
|---|---|
| `ttm pages_limit` | `8388608` |
| `ttm page_pool_size` | `8388608` |

</details>

<details open>
<summary><b>cfg80211 regdom</b> — 1 option</summary>

| Option | Value |
|---|---|
| `cfg80211 ieee80211_regdom` | `US` (mandatory; override `--country=XX`) |

</details>

<details open>
<summary><b>RADV drirc</b> — 1 option</summary>

| Option | Value |
|---|---|
| `radv_enable_unified_heap_on_apu` | `true` |

</details>

<details open>
<summary><b>udev — I/O scheduler</b> — 1 rule</summary>

| Device | Scheduler |
|---|---|
| NVMe (`KERNEL=="nvme[0-9]*"`, `ENV{DEVTYPE}=="disk"`) | `none` |

NVMe exposes native multiqueue, so a kernel I/O scheduler adds only overhead; `none` is also the upstream default for NVMe and is pinned explicitly here. The `ENV{DEVTYPE}=="disk"` guard limits the match to whole-disk block devices, avoiding the *No such file or directory* udev write errors that the bare `nvme[0-9]*` form throws on partitions and the controller char-device.

</details>

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

fstab rewrite → `systemd-resolved` restart → `PKGS_DEL` removal → mask `--now` 11 units → `daemon-reload` + enable runtime units → apply the wireless regdom (`iw reg set $COUNTRY`). The fstab rewrite strips conflicting `atime`/`relatime`/`strictatime`/`defaults`/`commit=*`, gated by `findmnt --verify`; **no auto-backup — snapshot `/etc/fstab` first.** The regulatory domain is mandatory (default `US`, override `--country=XX`), set the systemd-native way via `/etc/modprobe.d/ry-cfg80211-regdom.conf` (`options cfg80211 ieee80211_regdom`) — a tracked managed file, verified statically and at runtime (`iw reg get`).

<details open>
<summary><b>fstab</b> — 3 ext4 mount options</summary>

| Option | Effect |
|---|---|
| `noatime` | no access-time writes |
| `lazytime` | deferred timestamp writeback |
| `commit=10` | 10 s journal commit interval |

</details>

<details open>
<summary><b>Packages — remove</b> — 7 pkgs</summary>

| Package | Category |
|---|---|
| `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm` | boot splash (incompatible with `quiet`; Plasma rdeps enumerated) |
| `micro`, `cachyos-micro-settings` | text editor |

</details>

<details open>
<summary><b>Masked units</b> — 11 units</summary>

| Category | Units |
|---|---|
| Replaced daemons | `ananicy-cpp.service`, `avahi-daemon.{service,socket}`, `power-profiles-daemon.service` |
| Unused subsys | `ufw.service` (rules flushed pre-mask) |
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

</details>

### Phase 5 — Boot

`mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update` → post-rebuild sanity (`vmlinuz-*` + `initramfs-*.img` + loader-entry kernel path; emits **DO NOT REBOOT** on failure).

### Phase 6 — Finalize

`systemctl --user daemon-reload` (skipped without active user-bus) → pacman cache trim (`paccache -rk2 -ruk0`, falls back to `pacman -Sc`) → NetworkManager restart for the wpa_supplicant → iwd switch (deferred to reboot when WiFi is the active route).

## Managed Files

16 files via the [Phase 3](#phase-3--configuration) atomic-write sequence; system `0644`, user `0600`. Each is rendered from content embedded in the script, so the file on disk and the `--verify` target share one source.

<details open>
<summary><b>Destinations</b> — 16 paths</summary>

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
| `/etc/modules-load.d/i2c-dev.conf` | `0644` |
| `/etc/modprobe.d/ry-cfg80211-regdom.conf` | `0644` |
| `/etc/udev/rules.d/60-ry-ioschedulers.rules` | `0644` |
| `~/.config/environment.d/10-environment.conf` | `0600` |

</details>

## Safety & Reliability

Atomic writes and a gated Phase 5 rebuild mean a failed package or boot-config step can't leave a broken boot entry; `loader.conf` and `mkinitcpio.conf` get a `.ry.bak` before overwrite. `/etc/fstab` is the exception — rewritten with no automatic backup, so snapshot it first.

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

<details open>
<summary><b>Exit codes</b></summary>

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install FAIL / usage |
| `3` / `4` / `5` | preflight / boot-critical / lock |
| `10` | `--check` drift |
| `11` / `12` / `13` | gen: missing fn / missing UUID / sysctl malformed |
| `128+N` / `251` | signal (130=INT, 143=TERM, …) / `_run` tmpfile alloc fail |

</details>

<details open>
<summary><b>Runtime variables</b> — 4 vars</summary>

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | `_run` cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` |
| `NO_COLOR` | unset | suppress ANSI color |

</details>

NDJSON at `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`, one per run, no rotation. Events `header`/`log`/`footer`; footer marker `bail` (preflight) or `interrupted` (signal). Prune: `find ~/ry-install/logs -xdev -type f -mtime +30 -delete`.

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
4. Optionally reverse package changes (`sudo pacman -S <PKGS_DEL>`, `sudo pacman -Rns <PKGS_ADD>`). **Note:** `PKGS_ADD` includes Vulkan/gaming runtime deps (`lib32-mesa`, `realtime-privileges`, `rtkit`) — review the list and exclude anything still in use before removing.
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

Most clear with a DKMS package; MT7925 TX-power/deauth and Strix Halo ACP audio are upstream-pending with no local fix.

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | `paru -S amdgpu-dkms-firmware` or `IgnorePkg=linux-firmware` |
| MT7925 | kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| MT7925 | TX power 3 dBm / random deauth | none (upstream) |
| RTL8127 10GbE | throughput drops under load (BBS#7762) | `paru -S r8127-dkms` |
| Strix Halo ACP | `No matching ASoC machine driver` | pending upstream; HDMI/USB audio unaffected |
| NM + iwd | intermittent boot connectivity | `nmcli radio wifi off; and nmcli radio wifi on` |
| NM + iwd | WPA2/3 Enterprise GUI broken | CLI or wpa_supplicant |
| Lock / user-bus | stale lock / `systemctl --user` skipped | dead-PID auto-reclaim; `loginctl enable-linger $USER` |
| AUR | PGP signature failure | `gpg --recv-keys <KEYID>` then re-run |

## Troubleshooting

Boot problems recover from a live USB (`arch-chroot` + `mkinitcpio -P` + `sdboot-manage`); config drift is fixable in place with `--install-file`.

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | fix cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Sudo cache expired | re-run re-primes; see Prerequisites warning |
| `PKGS_DEL` member skipped | held by outside rdeps — remove manually with `sudo pacman -Rns <pkg>` |
| `.ry-install.*` orphan | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, re-run |
| PipeWire `nice-level` denied | `sudo usermod -aG realtime $USER`, re-login |
| `ddcutil` permission denied | `sudo usermod -aG i2c $USER`, re-login (`i2c-dev` autoloads at boot) |
| iwd edits not applied | `sudo systemctl try-restart iwd.service` |

## References

[NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) · [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) · [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) · [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) · [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes)

## License

MIT © 2026 Ryan Musante · `SPDX-License-Identifier: MIT`
