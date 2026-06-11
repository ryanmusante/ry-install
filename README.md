# ry-install

CachyOS configuration manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / Radeon 8060S, gfx1151, 128 GB LPDDR5x).

**Version 7.26.3 · fish ≥ 3.6 · CachyOS · MIT**

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install
chmod +x ry-install.fish
./ry-install.fish              # unattended install
```

> [!IMPORTANT]
> Run as your normal user — **root is refused (exit 2)**; sudo is invoked internally. Reboot, then `--verify`. Re-running is idempotent.

In scope: kernel cmdline, initramfs, systemd units, network (NetworkManager + iwd), sysctl, gaming env vars, pacman/AUR add+remove, sdboot-manage BLS entries. Out: dotfiles, shells, secrets, backups, multi-user, non-CachyOS, laptops, UKI.

## Requirements

Hard requirements abort read-only in preflight (exit 3); `paru`, `pacman-contrib`, and NTP sync only warn. Recommended: Zen 5 repos (`cachyos-znver4`, `cachyos-core-znver4`, `cachyos-extra-znver4`) above `[core]`/`[extra]`.

| Requirement | Minimum |
|---|---|
| CachyOS | systemd-boot, ext4 root, GNU coreutils + findutils |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| curl / findmnt | both required |
| Hardware | CPU matches `Ryzen AI Max` (override `RY_INSTALL_SKIP_HARDWARE_CHECK=1`) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |
| sudo | cached (`sudo -v`); may lapse mid-run — `Defaults timestamp_timeout=60` or NOPASSWD drop-in |
| paru / pacman-contrib | recommended — paru ≥ 2.0.0 (AUR); pactree (rdep-safe removal) |

## Usage

| Flag | Action |
|---|---|
| *(no args)* | Full unattended install |
| `-V, --verbose` | Show install output (`--check` ignores it) |
| `--verify` | Config files byte-for-byte, then live state |
| `--check` | Idempotency probe (`0` clean · `3` preflight · `10` drift) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--country=XX` | Wireless regdom (ISO-3166-1 alpha-2; default `US`; UK is `GB`) |
| `-h, --help` · `-v, --version` | Help · Version (honored first, except as the `--install-file` value) |

`--verify`/`--check` only read state and run without the instance lock — a concurrent install can read as transient drift; re-run after it finishes. `--check` compares the running `/proc/cmdline` (pending changes read as drift until reboot) and is stderr-silent after parsing; bootstrap failures before argument parsing still print to stderr. `--verify` also reports runtime state the installer does not write: ntsync, THP/KSM/ZRAM, `tcp_bbr`, drirc XML, ext4 fstab options, CachyOS vm sysctls (advisory), and boot time vs a 15 s target (≥ 90 % = near-miss `WARN`).

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`/etc/kernel/cmdline` regenerates sdboot entries without an initramfs rebuild); a cascade failure exits 4 — **do not reboot** until it succeeds. Non-boot post-hook failures stay exit 0. A non-vfat `/boot` ESP fallback refuses sdboot (exit 4).

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure taints the run and skips the Phase 5 rebuild; a failed `-Syu` also skips AUR; the advisory AUR phase never taints. Phase 3 writes are atomic renames.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | invariants → lock (exit 5) → hard gates; read-only except a non-fatal NTP repair |
| 2 | Packages | `pacman -Syu --needed` → AUR (`paru`) → `updatedb`/`pkgfile`. `mkinitcpio.conf` pre-deployed before `-Syu`; one `-Syyu` retry. Managed `.pacnew` auto-resolved (left for `pacdiff` after a rollback); `.pacsave` reported |
| 3 | Configuration | deploy the 16 embedded files atomically |
| 4 | Services | fstab → resolved restart → package removal → nftables activation → mask (ufw flush) → enable → regdom |
| 5 | Boot | `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity. `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses the taint gate |
| 6 | Finalize | user `daemon-reload` → `paccache -rk2 -ruk0` (`pacman -Sc --noconfirm` when paccache is absent) → NetworkManager restart (deferred on active Wi-Fi) |

CachyOS-default packages (`iwd`, `mesa`, `cpupower`, `iw`, `rtkit`) are not re-added; their configs still deploy. AUR is advisory: partial failure `WARN`, all-failed `FAIL` (a single-package set fails outright, exit 1). `vulkan-radeon` + `lib32-vulkan-radeon` are verified present.

> [!NOTE]
> With `REMOVE_EXISTING=yes`, `sdboot-manage gen` deletes every `loader/entries/` entry before regenerating — including foreign/other-OS BLS entries (`PRESERVE_FOREIGN=yes` would keep them). EFI-resident loaders (e.g. Windows Boot Manager) are untouched.

## Run Summary

A CHECK/RESULT/EVIDENCE matrix prints to stderr; the JSONL log records each phase and a final summary. Verdict (`PASS` · `PASS-WITH-WARNINGS` · `FAIL` · `FAIL-BOOT-CRITICAL` · `PREFLIGHT`) maps to the exit code. `WARN` keeps exit `0`; only `FAIL` sets `INSTALL_HAD_ERRORS`; `DEFER` applies next boot; `SKIP`/`N/A` by design.

## Configuration

The script is the source of truth; retune via the `set -g` globals near the top. In-script timing tunables (not env-overridable): `BOOT_TIME_TARGET=15` s, `PACTREE_TIMEOUT_S=60` s, `NM_RESTART_DELAY=3` s.

**Packages**

| Action | Packages |
|---|---|
| Install (15) | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `git-delta`, `lm_sensors`, `realtime-privileges`, `ddcutil`, `nftables` |
| AUR (1) | `mkinitcpio-firmware` |
| Remove (8) | `plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`, `micro`, `cachyos-micro-settings`, `cachy-update` |

**Kernel cmdline** → `/etc/kernel/cmdline` + sdboot `LINUX_OPTIONS`

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `split_lock_detect=off`, `tsc=reliable` |
| GPU | `amdgpu.ppfeaturemask=0xffff7fff` |
| IOMMU/PCIe | `amd_iommu=off` (disables IOMMU DMA isolation), `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet`, `nowatchdog` |

**Bootloader / initramfs**

| File | Settings |
|---|---|
| `loader.conf` | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| `sdboot-manage.conf` | `LINUX_OPTIONS`=kernel params (`root=` + `rw` injected by sdboot-manage), `LINUX_FALLBACK_OPTIONS=quiet`, `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING`/`OVERWRITE_EXISTING`/`REMOVE_OBSOLETE=yes` |
| `mkinitcpio.conf` | `MODULES=(amdgpu)`, `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`, `COMPRESSION=zstd` `-1 -T0` |

**Service & device configs**

| Config | Settings |
|---|---|
| systemd-resolved | `MulticastDNS=no`, `LLMNR=no`, `DNSOverTLS=no`, `DNSSEC=allow-downgrade` |
| systemd-logind | `Handle{Power,Suspend,Hibernate,Reboot}Key` (+ `…LongPress`) = `ignore` |
| iwd | `EnableNetworkConfiguration=false`, `PowerSaveDisable=*`, `NameResolvingService=systemd` |
| NetworkManager | `wifi.backend=iwd`, `wifi.powersave=2` (disable), `[logging] level=WARN` |
| cpupower | `GOVERNOR=powersave` (amd_pstate=active EPP mode; EPP not pinned) |
| amdgpu/ttm | `pages_limit=8388608`/`page_pool_size=8388608` (GTT ~32 GiB; set BIOS UMA=512 MB) |
| RADV drirc | `radv_enable_unified_heap_on_apu=true` |
| udev | NVMe whole-disk I/O scheduler → `none` |
| wireless regdom | `COUNTRY=US` (`--country=XX`), applied Phase 4; persists via `/etc/iw-regdomain` → cachyos-iw-set-regdomain |

**sysctl** → `/etc/sysctl.d/95-ry-overrides.conf` (loads after CachyOS `70-cachyos-settings.conf`)

| Scope | Settings |
|---|---|
| `net.core` | `default_qdisc=fq`, `netdev_budget=600`, `netdev_budget_usecs=5000` |
| `net.ipv4` | `tcp_congestion_control=bbr`, `tcp_notsent_lowat=16384`, `tcp_slow_start_after_idle=0` |

`vm.max_map_count` and `vm.compaction_proactiveness` are intentionally **not** set — the linux-cachyos kernel ships raised defaults; `--verify` reports the live values (advisory).

**Gaming env** → `~/.config/environment.d/10-environment.conf` (`0600`; `PROTON_*` per proton-cachyos)

| Category | Vars |
|---|---|
| Mesa/RADV | `AMD_VULKAN_ICD=RADV`, `MESA_SHADER_CACHE_MAX_SIZE=16G` |
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Wine | `WINEDEBUG=-all` |

**fstab** — ext4 entries rewritten in place: applies `noatime`, `lazytime`, `commit=10`; strips conflicting atime opts + redundant `defaults`; rewrites any `commit=`; original field whitespace preserved. Mandatory `findmnt --verify` gate; snapshot to `/etc/fstab.ry.bak`; symlinked `/etc/fstab` refused.

**Units**

| Set | Units |
|---|---|
| Masked (11) | `ananicy-cpp.service`, `avahi-daemon.{service,socket}`, `power-profiles-daemon.service`, `ufw.service` (rules flushed pre-mask, after nftables activates), `NetworkManager-wait-online.service`, `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` |
| Enabled (4) | `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service` (+ `NetworkManager-dispatcher.service` if installed); the runtime verify batch is derived from this list + conf.d-implied units |

## Managed Files

The Phase-3 files — the uninstall reference (system `0644`, user `0600`):

| Group | Files |
|---|---|
| Boot (4) | `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf` |
| systemd (2) | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf`, `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| Network (4) | `/etc/iwd/main.conf`, `/etc/NetworkManager/conf.d/99-cachyos-nm.conf`, `/etc/iw-regdomain`, `/etc/nftables.conf` |
| Tuning (5) | `/etc/sysctl.d/95-ry-overrides.conf`, `/etc/default/cpupower-service.conf`, `/etc/modprobe.d/ry-amdgpu-strixhalo.conf`, `/etc/drirc.d/95-ry-radv-apu.conf`, `/etc/udev/rules.d/60-ry-ioschedulers.rules` |
| User (1) | `~/.config/environment.d/10-environment.conf` |

## Safety & Reliability

> [!WARNING]
> This profile **masks `ufw`** and ships a minimal **nftables default-deny-inbound** ruleset: established/related, loopback, and ICMP allowed; all other inbound dropped; forwarding dropped; output unrestricted. mDNS is disabled (`MulticastDNS=no`) to match. Add inbound ports to `/etc/nftables.conf` as needed.

| Feature | Detail |
|---|---|
| Atomic writes | render → tmp → symlink-probe → `.ry.bak` (backup targets) → chmod → `mv -T` → re-read + restore on mismatch |
| Auto backups | `<path>.ry.bak` for `loader.conf` / `mkinitcpio.conf` / `fstab` |
| mkinitcpio rollback | byte-exact revert on `pacman -Syu` failure or signal; a failed or skipped revert preserves the `/run` snapshot (until reboot) |
| Instance lock | atomic `mkdir 0700`; dead-PID reclaim via `kill -0` + `/proc` liveness; a live PID started after the pidfile (recycled) is reclaimed via `/proc` starttime; empty pidfile settles 0.2 s before reclaim |
| Permissions | system `0644`, user `0600`, `~/ry-install/` `0700` |

| Code | Meaning |
|---|---|
| `0` / `1` / `2` | success / verify-FAIL or install-error / usage (incl. root-refused) |
| `3` / `4` / `5` | preflight / boot-critical (DO NOT REBOOT) / lock (holder PID on stderr; JSONL disambiguates) |
| `10` | `--check` drift |
| `128+N` | signal exit (130 INT, 143 TERM, …) |
| `11`/`12`/`13`/`251`/`250`/`255` | internal sentinels — never a process exit (JSONL `gen_fail`; collapses to `1` install/verify, `3` `--check`) |

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | per-command cap (s); `0` disables (pkg/boot/db ops bypass) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses the torn-package gate |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses the CPU match |
| `NO_COLOR` | unset | suppress ANSI color |
| `TMPDIR` | `/tmp` | scratch dir; invalid values fall back to `/tmp` |

Logs: JSONL under `~/ry-install/logs/<date>/`, one file per run, not auto-pruned (`run-overflow/` holds full spills). Prune: `find ~/ry-install/logs -type f \( -name '*.jsonl' -o -name '*.log' \) -mtime +30 -delete`. Query failures:

```fish
jq 'select(.event == "log" and (.data | test("^(FAIL|ERR):") or test("result=(FAIL|WARN)")))' ~/ry-install/logs/**/*.jsonl
```

## Uninstall

No automated uninstaller; use Managed Files as the rollback reference.

1. `sudo systemctl unmask` the masked units.
2. `sudo rm` the deployed system paths; remove `~/.config/environment.d/10-environment.conf` (no sudo).
3. Restore `/etc/fstab` from `/etc/fstab.ry.bak`; delete the `.ry.bak` backups.
4. Optionally reverse the package changes.
5. `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update`.
6. Reboot.

## Known Issues

| Component | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | MES page faults | `paru -S amdgpu-dkms-firmware` |
| MT7925 | kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| MT7925 | TX power 3 dBm / random deauth | none (upstream) |
| RTL8127 10GbE | throughput drops under load | `paru -S r8127-dkms` |
| Strix Halo ACP | no ASoC machine driver | pending upstream (HDMI/USB audio unaffected) |
| NM + iwd | intermittent boot connectivity | `nmcli radio wifi off; and nmcli radio wifi on` |
| NM + iwd | WPA2/3 Enterprise GUI broken | CLI or wpa_supplicant |
| AUR | PGP signature failure | `gpg --recv-keys <KEYID>`, then re-run |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | fix the cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| `.ry-install.*` orphan | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete; find ~/.config/environment.d -xdev -name '.ry-install.*' -delete`, then re-run |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire / ddcutil permission denied | `sudo usermod -aG realtime,i2c $USER`, re-login |

## References

- NM + iwd: <https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend>
- MT7925: <https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek>
- gfx1151: <https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151>
- ppfeaturemask: <https://wiki.archlinux.org/title/AMDGPU#Boot_parameter>

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
