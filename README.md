# ry-install

[![version](https://img.shields.io/badge/version-7.108.0-1793d1?style=flat-square)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-1793d1?style=flat-square)](#license)
[![platform](https://img.shields.io/badge/platform-CachyOS-1793d1?style=flat-square)](#requirements)
[![shell](https://img.shields.io/badge/shell-fish-1793d1?style=flat-square)](https://fishshell.com)

> Idempotent CachyOS config manager for the Beelink GTR9 Pro (Ryzen AI Max+ 395 / gfx1151 / Strix Halo). One self-contained fish script, 18 embedded configs — atomic, byte-verifiable (`--verify`), reversible ([Uninstall](#uninstall)).

## Quick Start

> [!IMPORTANT]
> Run as your normal user; cache sudo first (`sudo -v`). The unattended run **removes packages** ([Remove & Verify](#remove--verify)). Reboot, then `--verify`; re-runs are idempotent.

```fish
git clone https://github.com/ryanmusante/ry-install.git
cd ry-install && git checkout v7.108.0
chmod +x ry-install.fish
./ry-install.fish
```

**In scope:** the 18 [Managed Files](#managed-files) domains, plus pacman add/remove, systemd units, and the fstab rewrite.

**Out of scope:** dotfiles beyond the 2 managed user files, secrets, backups, multi-user, non-CachyOS, laptops, UKI, Secure Boot.

## Requirements

| Requirement | Minimum |
|---|---|
| Platform | CachyOS · systemd-boot · ext4 root |
| fish / systemd | ≥ 3.6 / ≥ 250 |
| Hardware | CPU matches `Ryzen AI Max` — bypass via [Environment Overrides](#environment-overrides) |
| Free space | 2 GiB `/` (warn < 5 GiB), 200 MiB `/boot` (warn < 500 MiB; gated only when `/boot` is a separate mount) |

The Platform row is the design target — enforced indirectly (`sdboot-manage` dependency, non-vfat ESP refusal, ext4-only fstab tuning); the rows below it are preflight-checked hard gates. Preflight hard-fails (exit 3) on uncached sudo, missing/non-GNU deps (37 commands, capability-probed), a free-space floor breach, or an unreachable network. NTP sync and a missing `pactree` warn only.

## BIOS

Multi-thread gains flatten past ~85 W — set a flat `SPL = fPPT = sPPT = 85 W` ceiling (stock boosts to 140 W) with `STAPM Boost = 0` and `TjMax = 90 °C`, under `Advanced → SMU Common Options`. Full per-setting walkthrough: [gtr9pro-bios-reference](https://github.com/ryanmusante/gtr9pro-bios-reference).

## Usage

> [!CAUTION]
> `--install-file` of a boot config runs the boot cascade (`loader.conf` / `/etc/kernel/cmdline` regenerate sdboot entries only — no initramfs rebuild); a cascade failure exits 4 — **do not reboot** until it succeeds. ESP autodetect (`bootctl` → `findmnt`) failure falls back to `/boot` with a warning; a non-vfat fallback then refuses sdboot (exit 4).

| Flag | Action |
|---|---|
| *(no args)* | Run the unattended install (silent; phase matrix at end) |
| `--verify` | Verify config files byte-for-byte, then live system state |
| `--check` | Probe idempotency silently vs live `/proc/cmdline` — a fresh install reports drift until reboot ([Exit Codes](#exit-codes)) |
| `--install-file <abs-path>` | Re-deploy a single managed file |
| `--` | End option parsing (no positional args) |
| `-h`/`--help` · `-v`/`--version` | Print and exit before all checks, including the root guard |

`--verify`/`--check` are lock-free and read-only. `--install-file` needs an absolute path resolving to a managed destination. Deploy modes and `--check` hard-gate hardware and key/count invariants (exit 3); `--verify` downgrades the hardware gate to a warning.

### Environment Overrides

Safe fallback when unset or invalid. Color also auto-disables when stderr is not a TTY or `TERM` is `dumb`.

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` s | Per-command cap; `0` disables; package/boot ops floor `7200` s; non-numeric → default; > 9 digits clamps to `2147483647` |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset (check on) | Set `1` (exact) to bypass the `Ryzen AI Max` CPU-match hard-fail; any other value keeps the check on |
| `NO_COLOR` | unset (color on) | Disable colored output when set — any value, including empty (stricter than [no-color.org](https://no-color.org), which ignores an empty string) |

## Install Flow

A `pacman -Syu`, package-verify, or boot-config failure **taints** the run and skips the Phase 5 rebuild; fix and re-run.

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | hard gates → lock → config checks (read-only) |
| 2 | Packages | `pacman -Syu`; `mkinitcpio.conf` pre-deployed so the sync rebuilds initramfs once |
| 3 | Configuration | deploy 18 embedded configs atomically |
| 4 | Services | fstab → resolved → package removal → mask (nftables-first, then ufw flush) → enable → regdomain |
| 5 | Boot | taint-gate → `mkinitcpio -P` → `sdboot-manage gen` + `update` → sanity |
| 6 | Finalize | user `daemon-reload` → `paccache -rk2` + `-ruk0` → NetworkManager restart |

Results print to stderr; one JSONL log per run (`0600`): `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl`. Phase verdicts: `PASS` · `WARN` · `FAIL` · `DEFER` · `SKIP` · `--` (rolled up as `N/A` in the Totals row) — `WARN` keeps exit 0; `DEFER` applies on next boot (e.g. the NetworkManager restart over Wi-Fi).

## Safety & Reliability

> [!WARNING]
> Masks `ufw` and ships an IPv4-only nftables default-deny-inbound ruleset: loopback, established/related, and ICMP echo-request + error/PMTUD types (destination-unreachable, time-exceeded, parameter-problem) accepted; `invalid` state dropped; `forward` drop, `output` accept. IPv6 disabled system-wide (`ipv6.disable=1`).

The fallback BLS entry boots `LINUX_FALLBACK_OPTIONS="quiet"` only — IPv6 and AMD-Vi revert to kernel defaults, though the IPv4-only ruleset and the `amdxdna` blacklist still apply. Game-streaming inbound is off; `RY_REMOTE_PLAY_PORTS=true` + re-run appends Sunshine/Moonlight + Steam Remote Play accepts (`tcp 47984, 47989, 48010, 27036, 27037` · `udp 47998-48010, 27031-27036`).

| Feature | Detail |
|---|---|
| Instance lock | `~/ry-install/.lock/pid` — atomic `mkdir` (then `0700`); stale reclaim only when the recorded PID is dead; live or ambiguous pidfiles fail closed |
| Atomic writes | same-FS tmp + pre-validation (`nft -c` for the ruleset) → backup → atomic `mv -T` → re-read, restore on mismatch |
| Auto backups | `<path>.ry.bak` for the 4 boot files (and `fstab`, during its rewrite) |
| mkinitcpio rollback | byte-exact revert (`cmp`-gated) on `pacman -Syu` failure or signal |
| Boot gates | a tainted phase refuses the rebuild; `sdboot-manage gen` refuses when `$BOOT` is unresolvable |
| Entry regeneration | `REMOVE_EXISTING=yes` clears `loader/entries/` first; EFI-resident loaders (e.g. Windows Boot Manager) untouched |

### Exit Codes

| Code | Meaning | Emitted When |
|---|---|---|
| `0` | OK | Success; also `WARN`-only runs and `--check` clean |
| `1` | verify-FAIL / install-error | `--verify` mismatch, or an install step errored |
| `2` | usage | Bad args, non-absolute/unmanaged `--install-file`, root-guard misuse |
| `3` | preflight | Missing/non-GNU dep, uncached sudo, gate mismatch, root + `--check` (silent) |
| `4` | boot-critical (DO NOT REBOOT) | Boot cascade or post-rebuild sanity failed — resolve before rebooting |
| `5` | lock | Another instance holds the lock (fail-closed on ambiguous pidfile) |
| `10` | `--check` drift | Config drift from the managed baseline |

Sentinels `11-14` / `250` / `251` / `255` are internal and never surface as process exits; signals exit `128+N`.

## Configuration

All tunables are `set -g` globals near the top of the script — no external config file. Edit one, then re-run (or `--install-file` the affected file). Porting to other hardware starts at the profile seam — `PROFILE_NAME`, `PROFILE_DESC`, and `EXPECTED_CPU_MATCH` — then the value arrays in [Embedded Values](#embedded-values). Perms: system `0644`, user `0600`.

### CachyOS Divergences

`sdboot-manage` `REMOVE_EXISTING=yes` ([Safety & Reliability](#safety--reliability)); plaintext DNS — `DNSOverTLS=no` (vendor default is DoT) plus `DNSSEC=no`; AMD P-State EPP `balance_performance` (`--verify` expects the `amd-pstate-epp` scaling driver); sysctl priority `95`, loading after vendor `70-cachyos-settings.conf`; NVMe scheduler `none` (vendor default is `kyber`).

### Packages

`pacman -Rns` is rdep-aware via `pactree` (from `pacman-contrib`). Phase 2 re-marks every `PKGS_ADD` package explicit after `-Syu`, so a later `-Rns` can't orphan a dependency-installed one.

| Action | Packages |
|---|---|
| Install | `nvme-cli`, `cachyos-gaming-meta`, `cachyos-gaming-applications`, `lib32-mesa`, `mkinitcpio-firmware`, `fd`, `sd`, `dust`, `procs`, `bottom`, `htop`, `lm_sensors`, `rtkit`, `realtime-privileges`, `nftables`, `pacman-contrib` |

### Remove & Verify

| Action | Packages |
|---|---|
| Remove (`-Rns`) | plymouth stack (`plymouth`, `cachyos-plymouth-bootanimation`, `cachyos-plymouth-theme`, `breeze-plymouth`, `plymouth-kcm`), `micro` + `cachyos-micro-settings`, `cachy-update`, `kdeconnect` |
| Verify present | `vulkan-radeon`, `lib32-vulkan-radeon` (`chwd` Vulkan drivers) |

### Units

| Action | Units |
|---|---|
| Mask | `ananicy-cpp.service`, `power-profiles-daemon.service`, `ufw.service`, `avahi-daemon.service`, `avahi-daemon.socket`, `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`, `suspend-then-hibernate.target` |
| Enable | `fstrim.timer`, `NetworkManager.service`, `cpupower.service`, `nftables.service`, `bluetooth.service` |
| Untouched | `systemd-oomd.service` (by design — kernel OOM-killer + zram is the intended path) |

### Fstab File

ext4 rows get `noatime,lazytime,commit=10` in column 4 (redundant `defaults`/`relatime`/`atime`/`strictatime`/existing `commit=` tokens normalized away). Everything else is byte-preserved. Gated by line-count parity + size floor + mandatory `findmnt --verify`. A symlinked `/etc/fstab` aborts the rewrite. Malformed (whitespace-split) rows are left byte-identical and warned.

## Managed Files

18 embedded configs, in deploy order ([`--verify`](#usage) checks all, `--install-file` re-deploys one): 4 boot-critical (`.ry.bak`-backed), 11 system, 3 user.

### Boot Files

| File | Purpose |
|---|---|
| `/boot/loader/loader.conf` | loader: default `@saved`, timeout `0`, console-mode `keep`, editor `no` |
| `/etc/kernel/cmdline` | `rw root=UUID` + the 15 `KERNEL_PARAMS` |
| `/etc/sdboot-manage.conf` | entry gen: `LINUX_OPTIONS`, `LINUX_FALLBACK_OPTIONS="quiet"`, `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING=yes`, `OVERWRITE_EXISTING=yes`, `REMOVE_OBSOLETE=yes` |
| `/etc/mkinitcpio.conf` | initramfs `MODULES` (`amdgpu` — early KMS), `HOOKS`, `COMPRESSION` `zstd` (`-1 -T0`) |

### System Files

| File | Purpose |
|---|---|
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | `DNSSEC=no`, no mDNS/LLMNR/DoT |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | ignore power/suspend/hibernate/reboot keys (+ long-press variants — 8 keys) |
| `/etc/systemd/system/NetworkManager-dispatcher.service.d/logging.conf` | `LogLevelMax=notice` — silence info-level `nm-dispatcher` noise |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` | `wpa_supplicant` backend, `wifi.powersave=2` (off), log level `WARN` |
| `/etc/iw-regdomain` | regulatory domain (`US`) |
| `/etc/bluetooth/main.conf` | adapter auto-power-on, `FastConnectable`, 3 paired-sink reconnect attempts |
| `/etc/nftables.conf` | IPv4-only default-deny-inbound (ping allowed) |
| `/etc/default/cpupower-service.conf` | governor (`powersave`) |
| `/etc/sysctl.d/95-ry-overrides.conf` | `fq` + netdev, TCP `bbr`, VM tunables |
| `/etc/udev/rules.d/99-ry-perf.rules` | NVMe sched `none`, P-State EPP, GPU DPM level `auto` (no SCLK pin) |
| `/etc/modprobe.d/60-ry-modules.conf` | `amdxdna` blacklist (`BLACKLIST_AMDXDNA`) |

### User Files

| File | Purpose |
|---|---|
| `~/.config/environment.d/10-environment.conf` | gaming env (RADV, DXVK, MangoHud, Proton, VKD3D, Wine) |
| `~/.config/MangoHud/MangoHud.conf` | readout-only HUD — horizontal, top-left, toggle `Shift_R+F12` |
| `~/.config/systemd/user/plasma-powerdevil.service.d/10-no-ddcutil.conf` | `POWERDEVIL_NO_DDCUTIL=1` — PowerDevil DDC/CI off; silences `org_kde_powerdevil` i2c errors (external-monitor brightness via Plasma intentionally off) |

## Embedded Values

The value arrays behind the managed files, in declaration order. Rationale for the non-obvious entries: [Tuning Notes](#tuning-notes).

### Kernel Parameters

| Token | Effect |
|---|---|
| `amd_iommu=off` | IOMMU fully off — lowest DMA-mapping overhead |
| `amd_pstate=active` | CPPC autonomous mode — the `amd-pstate-epp` scaling driver |
| `btusb.enable_autosuspend=n` | keep the BT controller powered — no wake/reconnect stalls |
| `clearcpuid=umip` | disable UMIP trapping |
| `fsck.mode=force` | run fsck on every boot |
| `fsck.repair=yes` | auto-repair whatever fsck finds |
| `ipv6.disable=1` | disable the IPv6 stack |
| `nowatchdog` | no watchdog modules — fewer timer wakeups |
| `nvme_core.default_ps_max_latency_us=0` | NVMe APST off — no power-state exit latency |
| `pcie_aspm.policy=performance` | force every PCIe link out of ASPM |
| `processor.max_cstate=1` | cap ACPI C-states at C1 — idle-exit latency floor |
| `quiet` | suppress boot console noise |
| `split_lock_detect=off` | no split-lock throttling penalty in games |
| `usbcore.autosuspend=-1` | USB autosuspend off globally |
| `zswap.enabled=0` | zswap off — zram is the swap path |

### Gaming Environment

| Variable | Effect |
|---|---|
| `AMD_VULKAN_ICD=RADV` | pin the RADV Vulkan driver |
| `DXVK_LOG_LEVEL=none` | DXVK logging off |
| `DXVK_LOG_PATH=none` | no DXVK log files |
| `FSR4_UPGRADE=1` | enable the FSR4 upgrade path |
| `MANGOHUD=1` | HUD on for Vulkan titles |
| `MESA_SHADER_CACHE_MAX_SIZE=16G` | roomy Mesa shader cache |
| `PROTON_ENABLE_WAYLAND=1` | native-Wayland Proton path |
| `PROTON_LOCAL_SHADER_CACHE=1` | per-prefix shader cache |
| `VKD3D_CONFIG=descriptor_heap` | D3D12 descriptor-heap fast path |
| `VKD3D_DEBUG=none` | vkd3d logging off |
| `VKD3D_SHADER_DEBUG=none` | vkd3d shader logging off |
| `WINEDEBUG=-all` | Wine debug channels off |

### Sysctl Overrides

Ten keys, split between networking and memory. The network half pairs BBR congestion control with the `fq` qdisc, widens NAPI polling (`netdev_budget=600`, `netdev_budget_usecs=5000`), caps the unsent buffer at 16 KiB (`tcp_notsent_lowat`) for lower send latency, and keeps the congestion window across idle. The VM half disables proactive compaction and watermark boosting (both reclaim-stall sources), raises `vm.max_map_count` to Steam's 2147483642, and sets `vm.swappiness=150` to push swap traffic onto zram.

## Tuning Notes

Non-obvious choices; several list an override to reverse.

| Topic | Detail |
|---|---|
| NTSYNC | `--verify` reports `/dev/ntsync` (present ok · module-no-node warn · absent info). Opt out: `PROTON_NO_NTSYNC=1`. |
| AMD-Vi (IOMMU) | `amd_iommu=off` breaks the XDNA NPU (hence blacklist). NPU/VFIO/SR-IOV: `amd_iommu=on iommu=pt` + `BLACKLIST_AMDXDNA false`, re-run. |
| UMIP (`clearcpuid=umip`) | Disables UMIP trapping; taints kernel. String form is version-stable (CPUID bit numbers shift between kernels). Drop if no `umip_printk` stutter. |
| IPv6 | `ipv6.disable=1`, IPv4-only ruleset. Dual-stack: drop token, add IPv6 rules, re-run. |
| PCIe ASPM | `pcie_aspm.policy=performance` actively disables ASPM on every link (MT7925 coredump / BT-reconnect / assoc fix + NVMe latency). Drop to restore ASPM defaults. |
| FSR4 on RDNA3 | `FSR4_UPGRADE=1` ships enabled (RDNA3/3.5). Verify: `printenv FSR4_UPGRADE`. |
| Avahi | `.service`+`.socket` masked — collided with resolved as a 2nd mDNS responder; profile runs `MulticastDNS=no`. Unmask both to restore. |
| MangoHud `cpu_temp` | Intentionally disabled (commented) in the shipped HUD — uncomment to show CPU temp. `cpu_power` ships active but reads 0 on Zen 5. |
| Large-VRAM compute | GTT caps usable VRAM near 62 GiB; raise BIOS UMA carveout (≤96 GiB) for more (`amdgpu.gttsize` deprecated). Verify: `cat /sys/module/ttm/parameters/pages_limit`. |

## Uninstall

No automated uninstaller; use [Managed Files](#managed-files) as the rollback reference. Manual uninstall — 6 steps, in order:

| # | Step | Action |
|---|---|---|
| 1 | Unmask units | `sudo systemctl unmask` all 10 masked units — exact set in [Units](#units) |
| 2 | Remove configs | `sudo rm` the 11 system files + `rm` the 3 user files — skip the 4 boot files (step 3 reverts them) |
| 3 | Revert boot files + fstab | `.ry.bak` → `/boot/loader/loader.conf`, `/etc/kernel/cmdline`, `/etc/sdboot-manage.conf`, `/etc/mkinitcpio.conf`, `/etc/fstab` (if present); then delete the `.ry.bak` files |
| 4 | Reverse packages (optional) | `pacman -S --needed` the **Remove** list, `pacman -Rns` the **Install** packages — exact sets in [Packages](#packages) + [Remove & Verify](#remove--verify) |
| 5 | Rebuild initramfs + entries | `sudo mkinitcpio -P; and sudo sdboot-manage gen; and sudo sdboot-manage update` |
| 6 | Reboot | `sudo systemctl reboot` |

Disable `nftables` before step 2 — its unit loads `/etc/nftables.conf` at start and fails once the ruleset is removed; disable any other [enabled units](#units) you no longer want the same way. Boot files must be reverted before step 5 — it regenerates entries from that state. A `.ry.bak` exists only if the file was present before the overwrite (fstab: only if rewritten).

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` → `sdboot-manage update` |
| Rebuild refused | a phase tainted boot state — fix the cause, re-run |
| `--verify` drift | `./ry-install.fish --install-file /etc/...` |
| Lock held, no live PID | `rm -rf ~/ry-install/.lock`; re-run |
| PipeWire permission denied | `sudo usermod -aG realtime $USER`, re-login (needs `realtime-privileges`) |
| ddcutil permission denied | `sudo usermod -aG i2c $USER`, re-login (needs `ddcutil`) |
| BT speaker won't auto-reconnect | `bluetoothctl trust <MAC>`, then power the speaker on after login so it re-initiates |

## License

MIT © 2026 Ryan Musante. SPDX-License-Identifier: MIT
