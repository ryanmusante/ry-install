# ry-install

CachyOS configuration for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / Radeon 8060S).

Version 7.19.18 · fish >= 3.6 · CachyOS · MIT.

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
10. [Safety and Reliability](#safety-and-reliability)
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

Run as your normal user (root is refused; sudo is internal). Reboot, then `--verify`. Re-run to upgrade (idempotent).

## Scope

| Scope | Items |
|---|---|
| In | kernel cmdline, initramfs, systemd units (system + user), network stack, sysctl, gaming env vars, pacman/paru install + remove, systemd-boot BLS entries via `sdboot-manage` |
| Out | dotfiles, shells, editors, secrets, backups, multi-user, non-CachyOS distros, laptops, UKI |

## Prerequisites

Hard requirements abort read-only in preflight (exit 3); retry after fixing. paru and NTP sync only warn.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root |
| fish | >= 3.6 |
| systemd | >= 250 |
| curl | required (HTTPS preflight) |
| Hardware | CPU matches `Ryzen AI Max` |
| paru | recommended >= 2.0.0 (AUR phase warns if absent) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached credential (`sudo -v`) |

| sudo cache | Detail |
|---|---|
| Risk | can lapse mid-run |
| Mitigate | `Defaults timestamp_timeout=60`, or NOPASSWD drop-in `/etc/sudoers.d/ry-install` |
| Cron/systemd | must pre-cache (`sudo -v` fallback needs a TTY) |
| Recovery | re-run |

## Hardware

| Component | Spec |
|---|---|
| CPU | Ryzen AI Max+ 395 (Zen 5, gfx1151) |
| GPU | Radeon 8060S (RDNA 3.5) |
| Memory | 128 GB LPDDR5x-8000 |
| CPU gate | matches `Ryzen AI Max`; override `RY_INSTALL_SKIP_HARDWARE_CHECK=1` |

## Usage

No arguments runs a full unattended install. `--check` and `--verify` only read state; only the no-argument run and `--install-file` write to disk.

| Flag | Action |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show install output (check ignores -V) |
| `--verify` | Config files + live state (static, then runtime) |
| `--check` | Idempotency probe (0=clean, 3=preflight, 10=drift) |
| `--install-file <path>` | Re-deploy one managed file (absolute path) |
| `--country=XX` | Wireless regulatory domain — assigned ISO-3166-1 alpha-2 (default `US`; UK is GB) |
| `-h, --help` / `-v, --version` | Help / version |

## Install Flow

Six phases in order. A package or boot-config failure taints the run, skipping the Phase 5 rebuild. Phase 3 writes are atomic renames.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | Prereqs + lock + runtime validate |
| 2 | Packages | `pacman -Syu --needed` + AUR via paru + cache refresh |
| 3 | Configuration | Deploy 15 embedded files (atomic) |
| 4 | Services | fstab + resolved + `PKGS_DEL` + mask + enable |
| 5 | Boot | `mkinitcpio -P` + `sdboot-manage` + sanity |
| 6 | Finalize | user daemon-reload + paccache + NM restart (deferred on active WiFi) |

## Run Summary

Prints a CHECK/RESULT/EVIDENCE matrix (totals, elapsed, verdict) to stderr. JSONL under `~/ry-install/logs/` records each `PHASE_RESULT` plus a `MATRIX_RENDERED` event. Verdict maps to exit code.

| Result | Semantics |
|---|---|
| `PASS` | succeeded |
| `WARN` | non-fatal anomaly (never taints; exit stays `0`) |
| `FAIL` | failed; the only result that sets `INSTALL_HAD_ERRORS=true` |
| `DEFER` | deferred to next boot |
| `SKIP` / `N/A` | by design / not applicable |

| Verdict | Trigger | Exit |
|---|---|---|
| `PASS` | `0 FAIL · 0 WARN` | `0` |
| `PASS-WITH-WARNINGS` | `0 FAIL · >=1 WARN` | `0` |
| `FAIL` | `>=1 FAIL` | `1` |
| `FAIL-BOOT-CRITICAL` | boot cascade aborted; prints DO NOT REBOOT | `4` |
| `PREFLIGHT` | preflight gate failed after a phase row was recorded (overrides FAIL/WARN) | `3` |

## Configuration

The script is the source of truth. `--verify` checks embedded files byte-for-byte, then live state; retune via `set -g` globals near the top. Phases 1, 5, and 6 deploy no files.

### Phase 1 — Preflight

Bootstrap (fish >= 3.6 + coreutils + PATH/TMPDIR/HOME) -> `_init_runtime` (root UUID + CPU match + invariants) -> lock (atomic `mkdir` 0700 + dead-PID reclaim) -> sudo cache -> deps (systemd >= 250 hard-gate, paru >= 2.0.0 advisory) -> disk space -> network (HTTPS + ICMP) -> time sync (NTP) -> per-destination config validators.

### Phase 2 — Packages

`pacman -Syu --needed` (`PKGS_ADD`) -> `paru` (`AUR_PKGS`) -> optional `updatedb` / `pkgfile --update`. `iwd`, `mesa`, `cpupower`, `iw`, and `rtkit` are CachyOS defaults (not re-added); their configs still deploy. AUR is advisory: missing `paru` or a partial failure is `WARN`; only an all-package AUR failure is `FAIL`.

Packages — install (14):

| Category | Packages |
|---|---|
| sysadmin | `nvme-cli`, `htop`, `git-delta`, `lm_sensors` |
| gaming | `cachyos-gaming-meta`, `cachyos-gaming-applications` |
| Vulkan/GL | `lib32-mesa` |
| rust utilities | `fd`, `sd`, `dust`, `procs`, `bottom` |
| perf | `realtime-privileges` |
| display | `ddcutil` (ships `i2c-dev` autoload) |

Packages — AUR (1):

| Package | Reason |
|---|---|
| `mkinitcpio-firmware` | firmware blobs absent from `linux-firmware` |

Vulkan deps (3):

| Package | Source |
|---|---|
| `vulkan-radeon` | chwd |
| `lib32-vulkan-radeon` | chwd |
| `lib32-mesa` | `PKGS_ADD` |

Caveats:

| Topic | Detail |
|---|---|
| Upgrades | full only (`pacman -Syu --needed`) |
| AUR flags | `paru -S --needed --noconfirm --skipreview --cleanafter`; `--removemake` omitted (DKMS makedeps) |
| PGP failure | `gpg --recv-keys <KEYID>` |
| `PKGS_DEL` blocked | held by outside rdeps; `pacman -Rns` to force |

### Phase 3 — Configuration

Atomic write per file: `mktemp` in the destination parent -> render via `tee` -> symlink probe -> `chmod` -> `mv -T` (same-FS). Kernel cmdline goes to `/etc/kernel/cmdline` and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS`); root UUID prefix from the `/` mount.

Kernel cmdline (13 params):

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `preempt=full`, `split_lock_detect=off`, `tsc=reliable` |
| GPU/amdgpu | `amdgpu.ppfeaturemask=0xfff73fff` |
| IOMMU/PCIe | `amd_iommu=off`, `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

Bootloader (10 keys):

| Scope | Settings |
|---|---|
| loader.conf | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| sdboot args | `LINUX_OPTIONS` = `KERNEL_PARAMS`, `LINUX_FALLBACK_OPTIONS=quiet` |
| sdboot entries | `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING=yes`, `OVERWRITE_EXISTING=yes`, `REMOVE_OBSOLETE=yes` |

Initramfs (6 fields):

| Field | Value |
|---|---|
| `MODULES` | `(amdgpu)` |
| `BINARIES` / `FILES` | `()` / `()` |
| `HOOKS` | `(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` |
| `COMPRESSION` | `zstd`, `COMPRESSION_OPTIONS (-1 -T0)` |

Service configs:

| Config | Settings |
|---|---|
| systemd-resolved | `[Resolve]` `MulticastDNS=resolve`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` |
| systemd-logind | `[Login]` `Handle{Power,Suspend,Hibernate,Reboot}Key` (+ `...LongPress`) = `ignore` |
| iwd | `[General]` `EnableNetworkConfiguration=false`; `[DriverQuirks]` `PowerSaveDisable=*`; `[Network]` `NameResolvingService=systemd` |
| NetworkManager | `[device]` `wifi.backend=iwd`; `[connection]` `wifi.powersave=2`; `[logging]` `level=WARN` |
| cpupower-service | `GOVERNOR=powersave` (sourced by `cpupower.service`) |

sysctl (8 tunables):

| Scope | Settings |
|---|---|
| `net.core` | `default_qdisc=fq`, `netdev_budget=600`, `netdev_budget_usecs=5000` |
| `net.ipv4` | `tcp_congestion_control=bbr`, `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0` |
| `vm` | `compaction_proactiveness=0`, `max_map_count=2147483642` |

Driver / misc configs:

| Config | Setting |
|---|---|
| amdgpu/ttm modprobe | `ttm pages_limit=8388608`, `page_pool_size=8388608` (caps GTT at 32 GiB) |
| wireless regdom | `COUNTRY=US` (`/etc/iw-regdomain`; override `--country=XX`) |
| RADV drirc | `radv_enable_unified_heap_on_apu=true` |
| udev I/O scheduler | NVMe whole-disk (`KERNEL=="nvme[0-9]*"`, `ENV{DEVTYPE}=="disk"`) -> `none` |

Env vars (10 keys):

| Category | Vars |
|---|---|
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Mesa/RADV | `MESA_SHADER_CACHE_MAX_SIZE=16G`, `AMD_VULKAN_ICD=RADV` |
| Wine | `WINEDEBUG=-all` |

### Phase 4 — Services

fstab rewrite -> `systemd-resolved` restart -> `PKGS_DEL` removal -> mask `--now` 11 units -> `daemon-reload` + enable runtime units -> apply regdom (`iw reg set $COUNTRY`, or `/etc/iw-regdomain` when `iw` absent). The rewrite strips conflicting entries, gated by `findmnt --verify` (WARN if findmnt absent). No auto-backup: snapshot `/etc/fstab` first.

fstab (3 ext4 mount options):

| Option | Effect |
|---|---|
| `noatime` | no access-time writes |
| `lazytime` | deferred timestamp writeback |
| `commit=10` | 10 s journal commit interval |

Packages — remove (8):

| Package | Category |
|---|---|
| `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm` | boot splash (incompatible with `quiet`) |
| `micro`, `cachyos-micro-settings` | text editor |
| `cachy-update` | update tool (script owns `pacman -Syu`) |

Masked units (11):

| Category | Units |
|---|---|
| Replaced daemons | `ananicy-cpp.service`, `avahi-daemon.{service,socket}`, `power-profiles-daemon.service` |
| Unused subsys | `ufw.service` (rules flushed pre-mask) |
| Boot delays | `NetworkManager-wait-online.service` |
| Power states | `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` |

Enabled units (3 verified):

| Unit | Role |
|---|---|
| `fstrim.timer` | weekly TRIM |
| `NetworkManager.service` | deduped via `_RY_PKG_MANAGED_SERVICES` |
| `cpupower.service` | oneshot (`active`/`exited`) |
| `NetworkManager-dispatcher.service` | if installed |

### Phase 5 — Boot

`mkinitcpio -P` -> `sdboot-manage gen` -> `sdboot-manage update` -> post-rebuild sanity (`vmlinuz-*` + `initramfs-*.img` + loader-entry kernel path; emits DO NOT REBOOT on failure).

### Phase 6 — Finalize

`systemctl --user daemon-reload` (skipped without active user-bus) -> pacman cache trim (`paccache -rk2 -ruk0`, falls back to `pacman -Sc`) -> NetworkManager restart (iwd switch deferred to reboot when WiFi is the active route).

## Managed Files

15 files via the [Phase 3](#phase-3--configuration) atomic-write sequence; system `0644`, user `0600`.

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
| `/etc/iw-regdomain` | `0644` |
| `/etc/udev/rules.d/60-ry-ioschedulers.rules` | `0644` |
| `~/.config/environment.d/10-environment.conf` | `0600` |

## Safety and Reliability

Atomic writes plus a gated Phase 5 rebuild keep a failed package or boot-config step from leaving a broken boot entry. `/etc/fstab` is the exception: no auto-backup, so snapshot it first.

| Feature | Detail |
|---|---|
| Atomic writes | tmp -> render -> symlink probe -> chmod -> `mv -T` |
| Auto backups | `<path>.ry.bak` before overwriting `loader.conf`/`mkinitcpio.conf`; restored on post-write byte-mismatch (fstab excluded) |
| Permissions | system `0644`, user `0600`, `~/ry-install/` `0700` |
| fstab | `findmnt --verify` gate (WARN if absent); rejects symlinked `/etc/fstab` |
| Boot rebuild gate | skipped on package/boot-config failure; `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint only |
| mkinitcpio rollback | byte-exact revert on `pacman -Syu` failure or signal |
| Instance lock | atomic mkdir `0700`; reclaims dead-PID lock via `kill -0` |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT -> 128+signum; SIGPIPE/WINCH non-fatal |
| Firewall posture | ufw disabled + masked (trusted-LAN); `--verify` reports `ufw=<state> nft_rules=<n>` |

Exit codes:

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install FAIL / usage |
| `3` / `4` / `5` | preflight / boot-critical / lock |
| `10` | `--check` drift |
| `11` / `12` / `13` | gen: missing fn / missing UUID / sysctl malformed |
| `128+N` / `251` | signal (130=INT, 143=TERM, ...) / `_run` tmpfile alloc fail |
| `250` / `255` | internal `_as` / `_run` arg-misuse guards (never a process exit) |

Runtime variables (4):

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | `_run` cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` |
| `NO_COLOR` | unset | suppress ANSI color |

Logs (NDJSON):

| Field | Detail |
|---|---|
| Path | `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl` |
| Rotation | one per run; none |
| Events | `header`, `log`, `footer` |
| Footer marker | `bail` (preflight) or `interrupted` (signal) |
| Prune | `find ~/ry-install/logs -xdev -type f -mtime +30 -delete` |

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):")))' ~/ry-install/logs/**/*.jsonl
```

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference.

1. `sudo systemctl unmask` the 11 masked units (reboot or start to restore).
2. `sudo rm` deployed paths from the Managed Files list.
3. Restore `/etc/fstab` from your pre-install snapshot.
4. Optionally reverse package changes (`sudo pacman -S <PKGS_DEL>`, `sudo pacman -Rns <PKGS_ADD>`); `PKGS_ADD` includes Vulkan/gaming runtime deps, so exclude anything still in use.
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

Most clear with a DKMS package. MT7925 TX-power/deauth and Strix Halo ACP audio are upstream-pending with no local fix.

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
| Boot failure | live USB -> `arch-chroot` -> `mkinitcpio -P` -> `sdboot-manage gen` |
| Initramfs rebuild refused | fix cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Sudo cache expired | re-run re-primes; see Prerequisites |
| `PKGS_DEL` member skipped | held by outside rdeps; `sudo pacman -Rns <pkg>` |
| `.ry-install.*` orphan | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, re-run |
| PipeWire `nice-level` denied | `sudo usermod -aG realtime $USER`, re-login |
| `ddcutil` permission denied | `sudo usermod -aG i2c $USER`, re-login |
| iwd edits not applied | `sudo systemctl try-restart iwd.service` |

## References

- NM + iwd: https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend
- MT7925: https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek
- gfx1151 issues: https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151
- ppfeaturemask: https://wiki.archlinux.org/title/AMDGPU#Boot_parameter
- Strix Halo Toolboxes: https://github.com/kyuz0/amd-strix-halo-toolboxes

## License

MIT (c) 2026 Ryan Musante. SPDX-License-Identifier: MIT
