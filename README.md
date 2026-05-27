# ry-install

**CachyOS configuration for the Beelink GTR9 Pro — Ryzen AI Max+ 395 / Radeon 8060S.**

[![version](https://img.shields.io/badge/version-7.8.4-blue.svg)](CHANGELOG.md)
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
| paru | Required for AUR (`mkinitcpio-firmware`, `mt76-mt7925-dkms`; +`r8127-dkms` on RTL8127 systems) |
| Free space | 2 GiB `/`, 200 MiB `/boot` |

> [!WARNING]
> Sudo cache may lapse during the 3–8 min install. Mitigate via `Defaults timestamp_timeout=60` added to `/etc/sudoers` (edit with `sudo visudo`), a keepalive shell (`while true; sudo -v; sleep 60; end`), or a scoped `NOPASSWD` drop-in at `/etc/sudoers.d/ry-install`. Interactive fallback needs stdin + stderr to be TTYs — set `RY_INSTALL_NO_INTERACTIVE_SUDO=1` for cron/systemd. Recovery: re-run (idempotent).

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

Runtime init requires CPU matching `Ryzen AI Max`; override via `RY_INSTALL_SKIP_HARDWARE_CHECK=1` (profile is amdgpu/gfx1151-specific).

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
| 1 | Preflight | Prereqs + lock + runtime validate |
| 2 | Packages | `pacman -Syu --needed` + AUR via paru + cache refresh |
| 3 | Configuration | Deploy 13 embedded files (atomic) |
| 4 | Services | fstab + resolved + THP + `PKGS_DEL` + mask + enable |
| 5 | Boot | `mkinitcpio -P` + `sdboot-manage` + sanity |
| 6 | Finalize | user daemon-reload + paccache + NM restart (deferred on active WiFi) |

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

`DEFER`/`SKIP`/`N/A` are informational and don't affect the verdict. Set `RY_INSTALL_NO_MATRIX` to any non-empty value to suppress the matrix (JSONL still records every `PHASE_RESULT`).

## Configuration

`--verify-static` compares installed files against embedded content byte-for-byte; the script is the source of truth. Edit `set -g` globals near the top to retune. Phases 1, 5, 6 deploy no embedded data.

### Phase 1 — Preflight

| # | Step | Detail |
|---|---|---|
| 1 | Bootstrap | fish ≥ 3.6 + coreutils + PATH/TMPDIR/HOME |
| 2 | `_init_runtime` | root UUID + CPU match + invariants |
| 3 | Lock | atomic `mkdir` 0700 + dead-PID reclaim |
| 4 | Sudo cache | `RY_INSTALL_NO_INTERACTIVE_SUDO=1` refuses fallback |
| 5 | Deps | systemd ≥ 250 + paru ≥ 2.0.0 |
| 6 | Disk space | 2 GiB `/` + 200 MiB `/boot` |
| 7 | Network | HTTPS + ICMP probe |
| 8 | Kernel | ≥ 6.14 FAIL · ≥ 6.18.4 WARN · ntsync |
| 9 | Configs | per-destination format validators |

### Phase 2 — Packages

| # | Step | Action |
|---|---|---|
| 1 | `_install_packages` | `pacman -Syu --needed` for `PKGS_ADD` |
| 2 | `_install_aur_packages` | `paru` for `AUR_PKGS` |
| 3 | `updatedb` | optional indexer (run when `mlocate` installed) |
| 4 | `pkgfile --update` | optional indexer (run when `pkgfile` installed) |

<details>
<summary><b>Packages — install</b> — 15 pkgs</summary>

| Category | Packages |
|---|---|
| sysadmin | `nvme-cli`, `htop`, `git-delta`, `lm_sensors` |
| gaming | `cachyos-gaming-meta`, `cachyos-gaming-applications` |
| Vulkan/GL | `mesa`, `lib32-mesa` |
| rust utilities | `fd`, `sd`, `dust`, `procs`, `bottom` |
| perf | `realtime-privileges`, `cpupower` |

**Opt-in:** `lact-git` (LACT AMD GPU control) — uncomment in `PKGS_ADD` + bump invariant 15→16.

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
| PGP failures | `--skipreview` auto-declines key import; pre-import via `gpg --recv-keys <KEYID>` or run `paru -S <pkg>` manually |
| Reverse deps | `PKGS_DEL` removal skipped on outside rdeps. Cascade via `RY_INSTALL_PKG_REMOVE_CASCADE=1` (needs `pacman-contrib`); Plasma rdeps already enumerated |

</details>

### Phase 3 — Configuration Files

| # | Step |
|---|---|
| 1 | `mktemp` in destination's parent dir (same-FS rename) |
| 2 | Render embedded content into tmp file via `tee` |
| 3 | Symlink probe (post-write; narrows TOCTOU window to mktemp→tee) |
| 4 | `chmod` to target mode |
| 5 | `mv -T` to destination (atomic, same-FS) |

<details>
<summary><b>Kernel cmdline</b> — 15 params</summary>

| Category | Params |
|---|---|
| CPU | `amd_pstate=active`, `preempt=full`, `split_lock_detect=off`, `tsc=reliable` |
| GPU/amdgpu | `amdgpu.cwsr_enable=0`, `amdgpu.gpu_recovery=1`, `amdgpu.ppfeaturemask=0xfffd3fff` |
| IOMMU/PCIe | `iommu=pt`, `pcie_aspm.policy=performance` |
| Storage | `nvme_core.default_ps_max_latency_us=0`, `zswap.enabled=0` |
| USB/Serial | `8250.nr_uarts=0`, `usbcore.autosuspend=-1` |
| Boot/log | `quiet` (flag), `nowatchdog` (flag) |

Deployed to `/etc/kernel/cmdline` and `/etc/sdboot-manage.conf` (`LINUX_OPTIONS`). UUID prefix computed from the `/` mount at preflight.

</details>

<details>
<summary><b>Bootloader</b> — 10 keys</summary>

| Category | Settings |
|---|---|
| loader.conf — UI | `default=@saved`, `timeout=0`, `console-mode=keep`, `editor=no` |
| sdboot — kernel args | `LINUX_OPTIONS` mirrors `KERNEL_PARAMS`, `LINUX_FALLBACK_OPTIONS=quiet` |
| sdboot — entry mgmt | `DEFAULT_ENTRY=manual`, `REMOVE_EXISTING=yes`, `OVERWRITE_EXISTING=yes`, `REMOVE_OBSOLETE=yes` |

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
| `GOVERNOR` | `'powersave'` |

Sourced by `cpupower.service` (`/usr/lib/systemd/scripts/cpupower`).

</details>

<details>
<summary><b>sysctl</b> — 8 tunables</summary>

| Key | Value |
|---|---|
| `net.core.default_qdisc` | `fq` |
| `net.ipv4.tcp_congestion_control` | `bbr` |
| `net.ipv4.tcp_notsent_lowat` | `16384` |
| `net.ipv4.tcp_slow_start_after_idle` | `0` |
| `vm.compaction_proactiveness` | `0` |
| `vm.dirty_background_bytes` | `67108864` |
| `vm.dirty_bytes` | `268435456` |
| `vm.max_map_count` | `2147483642` |

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
<summary><b>Env vars</b> — 10 keys</summary>

| Category | Vars |
|---|---|
| DXVK | `DXVK_LOG_LEVEL=none`, `DXVK_LOG_PATH=none` |
| VKD3D | `VKD3D_DEBUG=none`, `VKD3D_SHADER_DEBUG=none` |
| Proton | `PROTON_ENABLE_WAYLAND=1`, `PROTON_FSR4_RDNA3_UPGRADE=1`, `PROTON_LOCAL_SHADER_CACHE=1` |
| Mesa/RADV | `MESA_SHADER_CACHE_MAX_SIZE=4G`, `RADV_PERFTEST=nircache` |
| Wine | `WINEDEBUG=-all` |

Loaded by `systemd --user`. Log out and back in, or `systemctl --user import-environment` (then restart active user units) for live apply; running child processes retain inherited env until restarted. User file installs `0600`.

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

Idempotent rewrite — strips conflicting `atime`, `relatime`, `strictatime`, `defaults`, existing `commit=*`. `findmnt --verify` gates the atomic `mv`. Malformed ext4 entries (digits-only `$4`, NF<4) surface as WARN, untouched. **No automatic backup — snapshot `/etc/fstab` before first run.**

</details>

<details>
<summary><b>Packages — remove</b> — 7 pkgs</summary>

| Package | Category |
|---|---|
| `plymouth` | boot splash |
| `cachyos-plymouth-bootanimation` | boot splash |
| `cachyos-plymouth-theme` | boot splash |
| `breeze-plymouth` | boot splash (Plasma rdep) |
| `plymouth-kcm` | boot splash (Plasma rdep) |
| `micro` | text editor |
| `cachyos-micro-settings` | text editor |

Boot-splash group incompatible with `quiet`. Plasma rdeps enumerated so `pacman -R` does not refuse on rdep-hold.

**Opt-in:** `shelly` (CachyOS Shelly pkg mgr) — uncomment in `PKGS_DEL` + bump invariant 7→8.

</details>

<details>
<summary><b>Masked units</b> — 12 units</summary>

| Category | Units |
|---|---|
| Replaced daemons | `ananicy-cpp.service` (cgroups used instead), `avahi-daemon.{service,socket}` (systemd-resolved mDNS), `power-profiles-daemon.service` (conflicts with amd_pstate + cpupower) |
| Unused subsys | `lvm2-monitor.service` (no LVM), `ufw.service` (rules flushed pre-mask via `ufw --force disable`) |
| Boot delays | `NetworkManager-wait-online.service` |
| Power states | `{sleep,suspend,hibernate,hybrid-sleep,suspend-then-hibernate}.target` (suspend / hibernate disabled) |

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
| 2 | pacman cache trim (`paccache -rk2 -ruk0`; keeps 2 installed + 0 uninstalled versions; falls back to `pacman -Sc` when paccache absent; runs when an upgrade ran or any `PKGS_DEL` member was removed this invocation) |
| 3 | NetworkManager restart to apply the wpa_supplicant → iwd backend switch — deferred to next reboot when WiFi is the active route |

## Managed Files

13 files deployed via the [Phase 3](#phase-3--configuration-files) atomic-write sequence. System files install `0644`, the user file `0600`. The two iwd-gated destinations (`/etc/iwd/main.conf` and the NetworkManager drop-in) are skipped when `iwd` is not installed.

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
| `/etc/iwd/main.conf` *(skipped when iwd absent)* | `0644` |
| `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` *(skipped when iwd absent)* | `0644` |
| `/etc/default/cpupower-service.conf` | `0644` |
| `/etc/sysctl.d/99-cachyos-sysctl.conf` | `0644` |
| `/etc/tmpfiles.d/99-cachyos-thp.conf` | `0644` |
| `/etc/modprobe.d/ry-amdgpu-strixhalo.conf` | `0644` |
| `~/.config/environment.d/10-environment.conf` | `0600` |

</details>

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → render → symlink probe → chmod → `mv -T` |
| Permissions | system `0644` · user `0600` · `~/ry-install/` `0700` |
| fstab | `findmnt --verify` gate; rejects symlinked `/etc/fstab` |
| Boot rebuild gate | Skipped on package/boot-config failure. `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint only |
| mkinitcpio rollback | Byte-exact revert on `pacman -Syu` failure or signal |
| Root detection | Refuses root; sudo invoked internally |
| Instance lock | Atomic mkdir `0700`; reclaims dead-PID lock via `kill -0` probe |
| Signals | HUP/INT/QUIT/TERM/USR1/USR2/ABRT → 128+signum; SIGPIPE non-fatal; WINCH non-fatal (progress bar re-anchor) |

<details>
<summary><b>Exit codes</b> — 12 entries</summary>

| Category | Codes |
|---|---|
| General | `0` Success; `1` Verify FAIL count, non-critical install error, or kernel <6.14 hard-floor fail; `2` Usage error |
| Phase failure | `3` Preflight failed; `4` Boot-critical failure; `5` Lock failed |
| Drift | `10` `--check` drift |
| Generator | `11` `EXIT_GEN_NOFN` — content generator function missing (internal sentinel); `12` `EXIT_GEN_NOUUID` — content generator missing prerequisite global (e.g. `_ROOT_UUID`); `13` `EXIT_GEN_SYSCTL` — `_content__etc_sysctl.d_*` output count mismatch / malformed sysctl entry |
| Runtime/sig | `128+N` Signal (`129`=HUP, `130`=INT, `131`=QUIT, `143`=TERM, `134`=ABRT, `138`=USR1, `140`=USR2). `137` (KILL) cannot be caught — surfaces only when external `pkill -KILL` or `_run`'s 10s post-TERM grace fires; `251` `EXIT_RUN_TMPFAIL` — `_run` failed to allocate stdout/stderr capture tmpfiles |

</details>

<details>
<summary><b>Runtime variables</b> — 9 vars</summary>

| Variable | Default | Effect |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | `_run` wall-clock cap (s); `0` disables. Pkg/boot/db-indexer ops bypass |
| `RY_INITRD_WARN_MB` | `100` | Initramfs size warning threshold (MB) |
| `RY_INSTALL_ALLOW_PARTIAL_UPGRADE` | unset | `=1` → `pacman -Sy --needed` (install-only) |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | `=1` bypasses torn-package gate |
| `RY_INSTALL_PKG_REMOVE_CASCADE` | unset | `=1` cascades rdeps into removal set |
| `RY_INSTALL_SKIP_HARDWARE_CHECK` | unset | `=1` bypasses `EXPECTED_CPU_MATCH` hard-fail |
| `RY_INSTALL_NO_INTERACTIVE_SUDO` | unset | `=1` refuses interactive `sudo -v` fallback |
| `RY_INSTALL_NO_MATRIX` | unset | any non-empty value suppresses run-summary matrix (JSONL unaffected) |
| `NO_COLOR` | unset | Suppress ANSI color ([no-color.org](https://no-color.org/)) |

</details>

<details>
<summary><b>Logs</b> — 7 properties</summary>

| Property | Value |
|---|---|
| Path | `~/ry-install/logs/YYYY-MM-DD/MODE-YYYYMMDD-HHMMSS±ZZZZ-PID.jsonl` |
| Format | NDJSON, one file per run, no auto-rotation |
| Prune | `find ~/ry-install/logs -xdev -type f -mtime +30 -delete` |
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
| Strix Halo GPU | MES page faults | `paru -S amdgpu-dkms-firmware` OR `IgnorePkg=linux-firmware` (pin blocks future CVE fixes) |
| Strix Halo GPU | ROCm VRAM allocation | Fixed in kernel 6.16+ (`sudo pacman -Syu linux-cachyos`) |
| MediaTek MT7925 | Kernel panics (`mt792x_mac_reset_work`) | `paru -S mt76-mt7925-dkms` |
| MediaTek MT7925 | TX power 3 dBm / random deauth | None (cosmetic / upstream) |
| Realtek RTL8127 10GbE | Throughput drops / disconnects under sustained load (Beelink BBS#7762) | `paru -S r8127-dkms` (auto-gated by lspci -d 10ec:8127) |
| Strix Halo ACP | `No matching ASoC machine driver` (dmesg, once/boot) | Pending upstream; HDMI + USB audio unaffected |
| NetworkManager + iwd | Boot connectivity failure (intermittent) | `nmcli radio wifi off; and nmcli radio wifi on` |
| NetworkManager + iwd | WPA2/3 Enterprise GUI broken | Use CLI or wpa_supplicant |
| Other | Stale instance lock | Auto-reclaimed if PID dead; else `rm -rf ~/ry-install/.lock` |
| Other | `systemctl --user` skipped | No user-bus; enable via `loginctl enable-linger $USER` |
| Other | AUR PGP signature failure | `gpg --recv-keys <KEYID>` then re-run, or `paru -S <pkg>` without `--skipreview` |

## Troubleshooting

| Problem | Fix |
|---|---|
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| Initramfs rebuild refused | Fix root cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
| Sudo cache expired | `./ry-install.fish` re-primes cache; see Prerequisites WARNING for long runs |
| `PKGS_DEL` member skipped | `RY_INSTALL_PKG_REMOVE_CASCADE=1 ./ry-install.fish`; inspect via `pactree -ru <pkg>` |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| `.ry-install.*` orphan in `/etc` or `/boot/loader` | `sudo find /etc /boot/loader -xdev -name '.ry-install.*' -delete`, then re-run |
| PipeWire `nice-level Permission denied` | `sudo usermod -aG realtime $USER` then re-login |
| Kernel 6.19.0 + Strix Halo black screen | `sudo pacman -Syu` (≥6.19.1) ([CachyOS #23042](https://github.com/CachyOS/CachyOS/issues/23042)) |
| iwd config edits not taking effect | `sudo systemctl try-restart iwd.service` |
| MT7925 workaround applied but WiFi still failing | `dkms status mt76-mt7925`; re-run `paru -S mt76-mt7925-dkms` without `--skipreview` |

## References

[NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) · [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) · [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) · [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) · [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) · [CachyOS #23042](https://github.com/CachyOS/CachyOS/issues/23042) (kernel 6.19.0 black screen)

## License

MIT © 2026 Ryan Musante · `SPDX-License-Identifier: MIT`
