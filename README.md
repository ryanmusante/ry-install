# ry-install

**CachyOS configuration for the Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S.**

[![version](https://img.shields.io/badge/version-7.6.6-blue.svg)](CHANGELOG.md)
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

**Post-install:**
1. Reboot — required for kernel cmdline, initramfs, NM backend switch.
2. `./ry-install.fish --verify-static`
3. `./ry-install.fish --verify-runtime`

Typical duration: **3–8 minutes**.

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
| GNU coreutils | ≥ 8.x (`timeout --foreground/--kill-after`) |
| Hardware | `EXPECTED_CPU_MATCH` default `Ryzen AI Max` |
| sudo cache | Cached credential (`sudo -v`) |
| paru | Required for AUR (`mkinitcpio-firmware`, `mt76-mt7925-dkms`) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |

> [!WARNING]
> Sudo cache may lapse during the 3–8 min install. Mitigations:
> - `sudo visudo`: add `Defaults timestamp_timeout=60` (60-min cache)
> - Keepalive in another shell: `while true; sudo -v; sleep 60; end`
> - Drop-in: `sudo visudo -f /etc/sudoers.d/ry-install` → `<user> ALL=(ALL) NOPASSWD: ALL`
>
> Interactive sudo fallback requires both stdin and stderr be TTYs; set `RY_INSTALL_NO_INTERACTIVE_SUDO=1` for strict-unattended cron/systemd usage.
>
> Recovery: re-run ry-install (idempotent). Boot-taint flags reset between runs (per-process), so a fresh invocation observes a clean revert state even if the prior run aborted on a boot-critical failure.

```fish
./ry-install.fish --check        # idempotency probe
df -h / /boot                    # verify space
```

## Hardware

| Component | Part |
|---|---|
| CPU | Ryzen AI Max+ 395 (Zen 5, gfx1151 iGPU) |
| GPU | Radeon 8060S (RDNA 3.5) |
| RAM | 128 GB LPDDR5x-8000 |

Runtime init requires CPU matching `Ryzen AI Max` (checked on every mode); override via `RY_INSTALL_SKIP_HARDWARE_CHECK=1 ./ry-install.fish` (amdgpu modules + gfx1151 cmdline are profile-specific and break initramfs on other silicon).

## Usage

| Flag | Action |
|---|---|
| (no args) | Full unattended install |
| `-V, --verbose` | Show install output (check ignores -V) |
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
| 5 | Boot | Rebuild initramfs, update systemd-boot entries, post-rebuild sanity |
| 6 | Finalize | `systemctl --user daemon-reload`; pacman cache cleanup; NM restart (deferred to next reboot when WiFi is the active route) |

## Run Summary

Install completion prints a box-drawn CHECK/RESULT/EVIDENCE matrix to stderr + totals (`PASS · WARN · FAIL · DEFER · SKIP · N/A`) + elapsed wall-clock + single-word verdict.

| Result | Semantics |
|---|---|
| `PASS`  | Ran and succeeded |
| `WARN`  | Ran with a non-fatal anomaly |
| `FAIL`  | Ran and failed (sets `INSTALL_HAD_ERRORS=true`) |
| `DEFER` | Intentionally deferred to next boot |
| `SKIP`  | Not run by design (tool absent, boot-critical bail, opt-in disabled) |
| `--` / `N/A` | Not applicable |

| Verdict | Trigger |
|---|---|
| `PASS`               | `0 FAIL · 0 WARN` |
| `PASS-WITH-WARNINGS` | `0 FAIL · ≥1 WARN` |
| `FAIL`               | `≥1 FAIL` (without boot-critical) |
| `FAIL-BOOT-CRITICAL` | Boot rebuild cascade aborted (`EXIT_BOOT_CRIT`); prints **DO NOT REBOOT** + recovery steps |

`DEFER`, `SKIP`, and `N/A` buckets are informational and do not affect the verdict. Set `RY_INSTALL_NO_MATRIX` to any non-empty value to suppress the matrix (JSONL log still records every `PHASE_RESULT` event).

## Configuration

`--verify-static` compares installed files against embedded content byte-for-byte; the script is the source of truth. Every embedded value is documented below by phase. Edit the `set -g` globals near the top of `ry-install.fish` to retune. (Phases 1, 5, 6 deploy no embedded data.)

### Phase 1 — Preflight

| # | Step | Detail |
|---|---|---|
| 1 | Bootstrap | fish ≥ 3.6, coreutils `timeout`, PATH/TMPDIR/HOME hardening |
| 2 | `_init_runtime` | root UUID, `EXPECTED_CPU_MATCH`, array invariants, metachar guards |
| 3 | Acquire instance lock | atomic `mkdir` 0700, auto-reclaims dead PIDs |
| 4 | Sudo credential cache | `RY_INSTALL_NO_INTERACTIVE_SUDO=1` refuses interactive fallback |
| 5 | `_ry_check_deps` | `df --output`, systemd ≥ 250, paru (≥ 2.0.0 recommended) |
| 6 | `_ry_check_disk_space` | 2 GiB `/`, 200 MiB `/boot` |
| 7 | `_ry_check_network` | archlinux.org, cloudflare.com (HTTPS), 1.1.1.1 (ICMP) |
| 8 | `_ry_check_kernel_version` | ≥ 6.14 FAIL, ≥ 6.18.4 WARN, ntsync probe |
| 9 | Wireless regdom | opt-in apply via `RY_INSTALL_WIRELESS_REGDOM=<CC>` runs first; always-on check then warns on unset/invalid |
| 10 | `_ry_validate_configs` | per-destination format validators |

### Phase 2 — Packages

| # | Step | Action |
|---|---|---|
| 1 | `_install_packages` | `pacman -Syu --needed` for `PKGS_ADD` |
| 2 | `_install_aur_packages` | `paru` for `AUR_PKGS` |
| 3 | `updatedb` | optional indexer (run when `mlocate` installed) |
| 4 | `pkgfile --update` | optional indexer (run when `pkgfile` installed) |

<details>
<summary><b>Packages — install</b> — 15 pkgs</summary>

| Package | Purpose |
|---|---|
| `nvme-cli` | NVMe |
| `cachyos-gaming-meta` | gaming meta |
| `cachyos-gaming-applications` | gaming apps |
| `mesa` | Vulkan + GL |
| `lib32-mesa` | 32-bit Mesa |
| `fd` | rust find |
| `sd` | rust sed |
| `dust` | rust du |
| `procs` | rust ps |
| `bottom` | rust top |
| `htop` | classic top |
| `git-delta` | git diff |
| `lm_sensors` | hwmon |
| `realtime-privileges` | PipeWire RT |
| `cpupower` | cpufreq governor |

</details>

<details>
<summary><b>Packages — AUR</b> — 2 pkgs</summary>

| Package | Purpose |
|---|---|
| `mkinitcpio-firmware` | firmware blobs not in `linux-firmware` |
| `mt76-mt7925-dkms` | MT7925 WiFi (panic fix) |

Post-install `modinfo mt7925e` cross-check verifies DKMS build (paru `rc=0` alone is not definitive).

</details>

<details>
<summary><b>Vulkan dependencies</b> — 3 pkgs</summary>

| Package | Source |
|---|---|
| `vulkan-radeon` | `chwd` |
| `lib32-vulkan-radeon` | `chwd` |
| `lib32-mesa` | `PKGS_ADD` |

`--verify-runtime` fails on any missing.

</details>

<details>
<summary><b>Package caveats</b> — 4 notes</summary>

| Caveat | Detail |
|---|---|
| Partial upgrade | `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` → `pacman -Sy --needed` (no `-u`). Violates [Arch policy](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported) |
| AUR flags | `paru -S --needed --noconfirm --skipreview --cleanafter`. `--removemake` omitted — DKMS needs makedeps |
| PGP failures | Pre-import key (`gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys <KEYID>`) or `paru -S <pkg>` manually |
| Reverse deps | `PKGS_DEL` removal skipped on outside rdeps. Cascade via `RY_INSTALL_PKG_REMOVE_CASCADE=1` (needs `pacman-contrib`); Plasma rdeps already enumerated |

</details>

### Phase 3 — Configuration Files

| # | Step |
|---|---|
| 1 | `mktemp` in destination's parent dir (same-FS rename) |
| 2 | Render embedded content into tmp file via `tee` |
| 3 | Symlink probe (post-write; TOCTOU close) |
| 4 | `chmod` to target mode |
| 5 | `mv -T` to destination (atomic, same-FS) |

<details>
<summary><b>Kernel cmdline</b> — 15 params</summary>

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

Deployed to `/etc/kernel/cmdline` and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS`). UUID prefix computed from the `/` mount at preflight.

</details>

<details>
<summary><b>Bootloader</b> — 10 keys</summary>

| File | Key | Value |
|---|---|---|
| `loader.conf` | `default` | `@saved` |
| `loader.conf` | `timeout` | `0` |
| `loader.conf` | `console-mode` | `keep` |
| `loader.conf` | `editor` | `no` |
| `sdboot-manage.conf` | `LINUX_OPTIONS` | mirrors `KERNEL_PARAMS` |
| `sdboot-manage.conf` | `LINUX_FALLBACK_OPTIONS` | `quiet` |
| `sdboot-manage.conf` | `DEFAULT_ENTRY` | `manual` |
| `sdboot-manage.conf` | `REMOVE_EXISTING` | `yes` |
| `sdboot-manage.conf` | `OVERWRITE_EXISTING` | `yes` |
| `sdboot-manage.conf` | `REMOVE_OBSOLETE` | `yes` |

</details>

<details>
<summary><b>Initramfs</b> — 6 fields</summary>

| Field | Value |
|---|---|
| `MODULES` | `(amdgpu)` |
| `BINARIES` | `()` |
| `FILES` | `()` |
| `HOOKS` | `(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` |
| `COMPRESSION` | `zstd` |
| `COMPRESSION_OPTIONS` | `(-1 -T0)` |

11 ordering invariants enforced by `_vmh_order_checks` (`base` first, `fsck` last, no duplicates). Existence-only validation also runs post-pacman.

</details>

<details>
<summary><b>systemd-resolved</b> — 4 keys</summary>

| Key | Value |
|---|---|
| `MulticastDNS` | `resolve` |
| `LLMNR` | `no` |
| `DNSOverTLS` | `opportunistic` |
| `DNSSEC` | `allow-downgrade` |

</details>

<details>
<summary><b>systemd-logind</b> — 9 keys</summary>

| Key | Value |
|---|---|
| `HandlePowerKey` | `ignore` |
| `HandlePowerKeyLongPress` | `ignore` |
| `HandleSuspendKey` | `ignore` |
| `HandleSuspendKeyLongPress` | `ignore` |
| `HandleHibernateKey` | `ignore` |
| `HandleHibernateKeyLongPress` | `ignore` |
| `HandleRebootKey` | `ignore` |
| `HandleRebootKeyLongPress` | `ignore` |
| `HandleSecureAttentionKey` | `ignore` (systemd ≥ 257) |

</details>

<details>
<summary><b>iwd</b> — 3 keys</summary>

| Section / Key | Value |
|---|---|
| `[General] EnableNetworkConfiguration` | `false` |
| `[DriverQuirks] PowerSaveDisable` | `*` |
| `[Network] NameResolvingService` | `systemd` |

</details>

<details>
<summary><b>NetworkManager</b> — 3 keys</summary>

| Section / Key | Value |
|---|---|
| `[device] wifi.backend` | `iwd` |
| `[connection] wifi.powersave` | `2` |
| `[logging] level` | `WARN` |

</details>

<details>
<summary><b>cpupower-service</b> — 1 key</summary>

| Key | Value |
|---|---|
| `GOVERNOR` | `'performance'` |

Sourced by `cpupower.service` (`/usr/lib/systemd/scripts/cpupower`).

</details>

<details>
<summary><b>sysctl</b> — 16 tunables</summary>

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
<summary><b>tmpfiles</b> — 1 entry</summary>

| Type | Path | Argument |
|---|---|---|
| `w` | `/sys/kernel/mm/transparent_hugepage/shrink_underused` | `0` |

Applied immediately on install and on `--install-file` re-deploy; re-applied every boot by `systemd-tmpfiles-setup.service`.

</details>

<details>
<summary><b>Env vars</b> — 11 keys</summary>

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

Loaded by `systemd --user`. Log out and back in to apply, OR run `systemctl --user import-environment` (and restart active user units) for a live apply without re-login. Note: `import-environment` only refreshes the systemd `--user` manager env; child processes already running keep their inherited env until restarted.

</details>

### Phase 4 — Services

| # | Step |
|---|---|
| 1 | fstab rewrite (`_install_fstab_opts`) |
| 2 | `systemd-resolved` restart (re-applies `99-cachyos-resolved.conf`) |
| 3 | `systemd-tmpfiles --create` for THP |
| 4 | `PKGS_DEL` removal |
| 5 | Mask 12 desktop/power units |
| 6 | `daemon-reload` + enable runtime units |

<details>
<summary><b>fstab</b> — 3 ext4 mount options</summary>

| Option | Effect |
|---|---|
| `noatime` | disable atime updates |
| `lazytime` | defer atime/mtime writeback |
| `commit=10` | journal flush every 10s |

Idempotent rewrite — strips conflicting `atime`, `relatime`, `strictatime`, `defaults`, existing `commit=*`. `findmnt --verify` gates the atomic `mv`. The awk script sets `OFS = " "` so rewritten ext4 entries collapse to single-space-separated fields; comments and non-ext4 entries preserve their original whitespace via awk passthrough. Malformed ext4 entries (digits-only `$4`, NF<4) are left untouched and surface as WARN. **No automatic backup — snapshot `/etc/fstab` before first run.**

</details>

<details>
<summary><b>Packages — remove</b> — 11 pkgs</summary>

| Package | Category |
|---|---|
| `plymouth` | boot splash |
| `cachyos-plymouth-bootanimation` | boot splash |
| `cachyos-plymouth-theme` | boot splash |
| `breeze-plymouth` | boot splash (Plasma rdep) |
| `plymouth-kcm` | boot splash (Plasma rdep) |
| `octopi` | pacman GUI |
| `micro` | text editor |
| `cachyos-micro-settings` | text editor |
| `btop` | replaced by `bottom` |
| `bolt` | Thunderbolt manager |
| `plasma-thunderbolt` | Thunderbolt (Plasma rdep) |

Boot-splash group incompatible with `quiet`+`loglevel=3`. Plasma rdeps (`breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt`) enumerated so `pacman -R` does not refuse on rdep-hold.

</details>

<details>
<summary><b>Masked units</b> — 12 units</summary>

| Unit | Reason |
|---|---|
| `ananicy-cpp.service` | cgroups used instead |
| `avahi-daemon.service` | systemd-resolved mDNS |
| `avahi-daemon.socket` | systemd-resolved mDNS |
| `power-profiles-daemon.service` | conflicts with amd_pstate + cpupower |
| `lvm2-monitor.service` | no LVM |
| `NetworkManager-wait-online.service` | boot delay |
| `ufw.service` | rules flushed pre-mask via `ufw --force disable` |
| `sleep.target` | suspend / hibernate disabled |
| `suspend.target` | suspend / hibernate disabled |
| `hibernate.target` | suspend / hibernate disabled |
| `hybrid-sleep.target` | suspend / hibernate disabled |
| `suspend-then-hibernate.target` | suspend / hibernate disabled |

</details>

<details>
<summary><b>Enabled units</b> — 3 units</summary>

| Unit | Notes |
|---|---|
| `fstrim.timer` | weekly SSD TRIM |
| `NetworkManager.service` | also enabled by its pacman scriptlet (deduped via `_RY_PKG_MANAGED_SERVICES`) |
| `cpupower.service` | oneshot — accepts `active` or `exited` |

`NetworkManager-dispatcher.service` is enabled when installed and not already enabled; silently skipped when absent.

</details>

### Phase 5 — Boot

| # | Step |
|---|---|
| 1 | `mkinitcpio -P` (initramfs rebuild) |
| 2 | `sdboot-manage gen` (bootloader entries) |
| 3 | `sdboot-manage update` (bootloader entries) |
| 4 | Post-rebuild sanity (`vmlinuz-*` + `initramfs-*.img` + loader-entry kernel-path verify; emits **DO NOT REBOOT** on failure) |

### Phase 6 — Finalize

| # | Step |
|---|---|
| 1 | `systemctl --user daemon-reload` (skipped when no active user-bus) |
| 2 | pacman cache trim (`paccache -rk2 -ruk0`; keeps 2 installed + 0 uninstalled versions; falls back to `pacman -Sc` when paccache absent; skipped when no upgrade ran this invocation) |
| 3 | NetworkManager restart to apply the wpa_supplicant → iwd backend switch — deferred to next reboot when WiFi is the active route |

## Managed Files

12 files deployed via the [Phase 3](#phase-3--configuration-files) atomic-write sequence. System files install `0644`, the user file `0600`. The two iwd-gated destinations (`/etc/iwd/main.conf` and the NetworkManager drop-in) are skipped when `iwd` is not installed.

<details>
<summary><b>Destinations</b> — 12 paths</summary>

| Path | Mode |
|---|---|
| `/boot/loader/loader.conf` | `0644` |
| `/etc/kernel/cmdline` | `0644` |
| `/etc/sdboot-manage.conf` | `0644` |
| `/etc/mkinitcpio.conf` | `0644` |
| `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` | `0644` |
| `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` | `0644` |
| `/etc/iwd/main.conf` *(skipped when iwd absent)* | `0644` |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` *(skipped when iwd absent)* | `0644` |
| `/etc/default/cpupower-service.conf` | `0644` |
| `/etc/sysctl.d/99-cachyos-sysctl.conf` | `0644` |
| `/etc/tmpfiles.d/99-cachyos-thp.conf` | `0644` |
| `~/.config/environment.d/10-environment.conf` | `0600` |

</details>

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → symlink probe → chmod → `mv -T` |
| Permissions | system `0644` · user `0600` · `~/ry-install/` `0700` |
| fstab | `findmnt --verify` gate; rejects symlinked `/etc/fstab` |
| Boot rebuild gate | Skipped on package/boot-config failure. `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint only |
| mkinitcpio rollback | Byte-exact revert on `pacman -Syu` failure or signal |
| Root detection | Refuses root; sudo invoked internally |
| Instance lock | Atomic mkdir `0700`; reclaims dead-PID lock via `kill -0` probe |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT → 128+signum; SIGPIPE non-fatal; WINCH non-fatal (progress bar re-anchor) |

<details>
<summary><b>Exit codes</b> — 12 entries</summary>

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Verify FAIL count, non-critical install error, or kernel <6.14 hard-floor fail |
| `2` | Usage error |
| `3` | Preflight failed |
| `4` | Boot-critical failure |
| `5` | Lock failed |
| `10` | `--check` drift |
| `11` | `EXIT_GEN_NOFN` — content generator function missing (internal sentinel) |
| `12` | `EXIT_GEN_NOUUID` — content generator missing prerequisite global (e.g. `_ROOT_UUID`) |
| `13` | `EXIT_GEN_SYSCTL` — `_content__etc_sysctl.d_*` output count mismatch / malformed sysctl entry |
| `128+N` | Signal (`129`=HUP, `130`=INT, `131`=QUIT, `143`=TERM, `134`=ABRT, `138`=USR1, `140`=USR2) |
| `251` | `EXIT_RUN_TMPFAIL` — `_run` failed to allocate stdout/stderr capture tmpfiles |

</details>

<details>
<summary><b>Runtime variables</b> — 10 vars</summary>

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | `_run` wall-clock cap (s); `0` disables. Pkg/boot/db-indexer ops bypass |
| `RY_INITRD_WARN_MB` | `100` | Initramfs size warning threshold (MB) |
| `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` | unset | `=1` → `pacman -Sy --needed` (install-only) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_PKG_REMOVE_CASCADE` | unset | `=1` cascades rdeps into removal set |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` hard-fail |
| `RY_INSTALL_WIRELESS_REGDOM` | unset | `=<CC>` writes `WIRELESS_REGDOM=<CC>` (2-letter ISO 3166-1) |
| `RY_INSTALL_NO_INTERACTIVE_SUDO` | unset | `=1` refuses interactive `sudo -v` fallback |
| `RY_INSTALL_NO_MATRIX` | unset | any non-empty value suppresses run-summary matrix (JSONL unaffected) |
| `NO_COLOR` | unset | Suppress ANSI color ([no-color.org](https://no-color.org/)) |

Persist `RY_INSTALL_WIRELESS_REGDOM` in `~/.config/fish/conf.d/ry-install-env.fish` (`set -gx RY_INSTALL_WIRELESS_REGDOM US`); a stale `/etc/conf.d/wireless-regdom` with no valid value silently disables `iw reg set` on every boot.

</details>

<details>
<summary><b>Logs</b> — 7 properties</summary>

| Property | Value |
|---|---|
| Path | `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl` |
| Format | NDJSON, one file per run, no auto-rotation |
| Prune | `find ~/ry-install/logs -mtime +30 -print -delete` |
| Events | `header`, `log`, `footer`; all carry `ts` + `event` |
| Footer marker | `bail` (preflight fail), `interrupted` (signal); normal exit: none |
| `ERR_NO_DATA` | systemctl probes returning <3 fields emit `ERR_NO_DATA` |
| `gen_fail` | `_content__*` non-zero returns; flips verify exit to `1` |

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

| Category | Issue | Workaround |
|---|---|---|
| Strix Halo GPU | CWSR hang | `amdgpu.cwsr_enable=0` (already set) |
| Strix Halo GPU | MES page faults | `paru -S amdgpu-dkms-firmware` (AUR alt firmware) OR pin via `IgnorePkg = linux-firmware` in `/etc/pacman.conf` — note the pin leaves all firmware unpatched against future CVEs until removed |
| Strix Halo GPU | ROCm VRAM allocation | Fixed in kernel 6.16+ (`sudo pacman -Syu linux-cachyos`) |
| MediaTek MT7925 | Kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| MediaTek MT7925 | TX power 3 dBm / random deauth | None (cosmetic / upstream) |
| Strix Halo ACP | `No matching ASoC machine driver` (dmesg, once/boot) | Pending upstream; HDMI + USB audio unaffected |
| NetworkManager + iwd | Boot connectivity failure (intermittent) | `nmcli radio wifi off; and nmcli radio wifi on` |
| NetworkManager + iwd | WPA2/3 Enterprise GUI broken | Use CLI or wpa_supplicant |
| Other | Stale instance lock | Auto-reclaimed if PID dead; else `rm -rf ~/ry-install/.lock` after `pgrep -af ry-install` empty |
| Other | `systemctl --user` skipped | Absent user-bus; enable with `loginctl enable-linger $USER` |
| Other | AUR PGP signature failure | `gpg --recv-keys <KEYID>` then re-run, or `paru -S <pkg>` without `--skipreview` |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | Fix root cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
| Sudo cache expired | `./ry-install.fish` (script re-primes cache; for long runs see Prerequisites WARNING) |
| `PKGS_DEL` member skipped | `RY_INSTALL_PKG_REMOVE_CASCADE=1 ./ry-install.fish`; inspect first with `pactree -ru <pkg>` |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| `.ry-install.*` orphan in `/etc` or `/boot/loader` | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, then re-run |
| `set-wireless-regdom` leaves cfg80211 in `world` | Re-run with `RY_INSTALL_WIRELESS_REGDOM=<CC>`; fallback: `echo 'WIRELESS_REGDOM="<CC>"' \| sudo tee /etc/conf.d/wireless-regdom` |
| PipeWire `nice-level Permission denied` | `sudo usermod -aG realtime $USER` then re-login |
| Kernel 6.19.0 + Strix Halo black screen | `sudo pacman -Syu` (≥6.19.1) or `paru -S downgrade; and sudo downgrade linux-cachyos` ([CachyOS #23042](https://github.com/CachyOS/CachyOS/issues/23042)) |
| iwd config edits not taking effect | `sudo systemctl try-restart iwd.service` (ry-install does this for managed-file edits) |
| MT7925 workaround applied but WiFi still failing | `dkms status mt76-mt7925`; re-run `paru -S mt76-mt7925-dkms` without `--skipreview` to surface build errors; `--verify-runtime` should report `WiFi device: connected` once the module loads |

## References

[NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) · [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) · [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) · [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) · [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) · [CachyOS #23042](https://github.com/CachyOS/CachyOS/issues/23042) (kernel 6.19.0 black screen)

## License

MIT © 2026 Ryan Musante · `SPDX-License-Identifier: MIT`
