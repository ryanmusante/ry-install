# ry-install

[![version](https://img.shields.io/badge/version-7.1.1-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%203.6-4aae46.svg)](https://fishshell.com/)
[![kernel](https://img.shields.io/badge/kernel-%E2%89%A5%206.14%20%286.18.4%2B%20rec.%29-orange.svg)](https://www.kernel.org/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
![license](https://img.shields.io/badge/license-MIT-green.svg)

> Self-contained CachyOS configuration manager. Single Fish script, 13
> embedded configs, no required external dependencies (paru required
> for AUR: `mkinitcpio-firmware`, `mt76-mt7925-dkms`).

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

> [!TIP]
> If you cannot set the executable bit: `fish ry-install.fish`.

**Post-install:**
1. Reboot — required for kernel cmdline, initramfs, NM backend switch.
2. `./ry-install.fish --verify-static`
3. `./ry-install.fish --verify-runtime`

Typical duration: **3–8 minutes**.

> [!NOTE]
> Over WiFi, the NM backend switch (wpa_supplicant → iwd) is deferred
> to next reboot. On ethernet:
> `sudo systemctl restart NetworkManager` applies it immediately.

> [!IMPORTANT]
> Initramfs rebuild aborts when on-disk package state or boot-critical
> configs (`/etc/mkinitcpio.conf`, `/etc/kernel/cmdline`,
> `/boot/loader/loader.conf`, `/etc/sdboot-manage.conf`) are
> inconsistent with embedded content. Override after manual
> remediation: `RY_INSTALL_FORCE_BOOT_REBUILD=1`.

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
| Free space | 2 GB `/`, 200 MB `/boot` |

Additional preflight gates (systemd ≥ 250, unrestricted sudo, GNU
coreutils, hardware match) are enforced and fail loudly. The ext4
`/etc/fstab` rewrite is idempotent and mount-semantics-preserving —
only the literal text differs.

```fish
./ry-install.fish --check        # idempotency probe
sudo -v                          # warm sudo cache
df -h / /boot                    # verify space
```

Check [CachyOS](https://wiki.cachyos.org) and
[Arch news](https://archlinux.org/news/) before any `pacman -Syu`.

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

> [!IMPORTANT]
> BIOS prerequisite: set **UMA Frame Buffer Size** to `Auto` or
> `512 MB` (not a fixed 16 GB carveout). The Strix Halo APU uses UMA
> with shared system memory; a large fixed carveout wastes RAM that
> would otherwise be available to the OS and is dynamically backed
> when the GPU needs it. `--verify-runtime` warns when
> `mem_info_vram_total` exceeds 512 MB.

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
| `-h, --help` / `-v, --version` | Help / version |

Positional arguments after `--` are rejected.

## Install Flow

| # | Phase | Action |
|---|---|---|
| 1 | Preflight | Validate prerequisites, acquire lock, validate runtime |
| 2 | Packages | `pacman -Syu --needed`; AUR via paru |
| 3 | Configuration | Deploy 13 embedded config files (atomic) |
| 4 | Services | `daemon-reload`; enable; mask 12 desktop/power units |
| 5 | Boot | Rebuild initramfs, update systemd-boot entries |
| 6 | Finalize | Cache cleanup, NM restart (deferred on WiFi) |

## Configuration

All values are embedded in the script and deployed to the paths in
[Managed Files](#managed-files). To retune, edit the `set -g` profile
globals near the top of `ry-install.fish` (`LOADER_*`, `SDBOOT_*`,
`KERNEL_PARAMS`, `MKINITCPIO_*`, `SYSCTL_VALUES`, `ENV_VARS`, `PKGS_*`,
`AUR_PKGS`, `MASK`, `EXPECTED_SERVICES`). The script is the source of
truth — `--verify-static` matches installed files against embedded
content byte-for-byte.

<details>
<summary><b>Profile highlights</b></summary>

| Domain | Key setting |
|---|---|
| Kernel cmdline | `amd_pstate=active`, `amdgpu.cwsr_enable=0`, `iommu=pt`, `split_lock_detect=off`, `tsc=reliable`, `zswap.enabled=0` (15 params total) |
| Bootloader | systemd-boot, `default=@saved`, `timeout=0` |
| Initramfs | `MODULES=(amdgpu)`, systemd HOOKS, `COMPRESSION=zstd` |
| Network | NetworkManager + iwd; resolved (DoT + DNSSEC + mDNS) |
| Sysctl | BBR+fq, `tcp_fastopen=3`, 10 GbE buffers (16 tunables) |
| fstab | `noatime,lazytime,commit=10` on ext4 (idempotent rewrite) |
| Env | `PROTON_USE_NTSYNC=1`, `RADV_PERFTEST=sam,nircache`, `RADV_EXPERIMENTAL=transfer_queue`, `MESA_SHADER_CACHE_MAX_SIZE=4G` (11 vars) |

Read the script for exact values.

</details>

<details>
<summary><b>Packages</b></summary>

Default: `pacman -Syu --needed` per Arch's
[no-partial-upgrade policy](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported).

| Action | Count |
|---|---|
| Install (`PKGS_ADD`) | 14 |
| Remove (`PKGS_DEL`) | 8 |
| AUR (`AUR_PKGS`) | 2 |

| Caveat | Detail |
|---|---|
| Partial upgrade | `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` switches to `pacman -Sy --needed` (refresh + install only, no upgrade). Retry path uses `-Syy` without `-u`. Violates Arch policy. |
| AUR flags | `paru -S --needed --noconfirm --skipreview --cleanafter`. `--removemake` deliberately omitted: DKMS packages rebuild against the running kernel and need makedeps. |
| PGP failures | `--skipreview` suppresses interactive key import. On `invalid or corrupted package (PGP signature)`: pre-import key (`gpg --recv-keys <KEYID>`) or `paru -S <pkg>` manually. |
| Reverse deps | `PKGS_DEL` removal skipped when an installed package outside the set rdeps on it. Cascade via `RY_INSTALL_PKG_REMOVE_CASCADE=1` (requires `pacman-contrib` for `pactree`). |

</details>

## Managed Files

13 files deployed via atomic writes (tmp → symlink check → chmod → `mv -T`).
System files install `0644`, the user file `0600`. The two `iwd`
destinations are skipped when `iwd` is not installed.

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
| System | `/etc/drirc` |
| System | `/etc/sysctl.d/99-cachyos-sysctl.conf` |
| System | `/etc/tmpfiles.d/99-cachyos-thp.conf` |
| Service | `/etc/systemd/system/cpupower-epp.service` |
| User | `~/.config/environment.d/10-environment.conf` |

`99-cachyos-thp.conf` writes `0` to
`/sys/kernel/mm/transparent_hugepage/shrink_underused` on every boot
via `systemd-tmpfiles-setup.service`; applied immediately during
install and on `--install-file` re-deploy via
`systemd-tmpfiles --create`.

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
| `NO_COLOR` | unset | Suppress ANSI color (any value, per [no-color.org](https://no-color.org/)) |

</details>

<details>
<summary><b>Logs</b></summary>

| Property | Value |
|---|---|
| Path | `~/ry-install/logs/YYYY-MM-DD/MODE-TIMESTAMP-PID.jsonl` |
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
rollback source-of-truth: unmask units, `rm` deployed paths, restore
`/etc/fstab` from your snapshot, optionally reverse package changes,
then `mkinitcpio -P && sdboot-manage gen` and reboot.

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
| `platform acp_asoc_acp70.0: warning: No matching ASoC machine driver found` (dmesg, once per boot); internal analog ACP path not routed | Pending upstream ASoC machine driver. HDMI (`snd_hda_intel`) and USB audio paths unaffected. `--verify-runtime` surfaces this as INFO + `ACP_NO_MACHINE_DRIVER` log token. |

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
