# ry-install

[![version](https://img.shields.io/badge/version-4.5.11-blue.svg)](CHANGELOG.md)
[![fish](https://img.shields.io/badge/fish-%E2%89%A5%204.0%20%283.6%2B%29-4aae46.svg)](https://fishshell.com/)
[![kernel](https://img.shields.io/badge/kernel-%E2%89%A5%206.14%20%286.18.4%2B%20rec.%29-orange.svg)](https://www.kernel.org/)
[![distro](https://img.shields.io/badge/distro-CachyOS-6a4c93.svg)](https://cachyos.org/)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> Self-contained CachyOS configuration manager. Single Fish script, 15 embedded configs, no required external dependencies (paru optional; needed for MT7925 DKMS).

**Target system:** Beelink GTR9 Pro (Strix Halo APU). See [Hardware Reference](#hardware-reference).

---

## Table of Contents

- [Quick Start](#quick-start)
- [Scope](#scope)
- [Prerequisites](#prerequisites)
- [Hardware Reference](#hardware-reference)
- [Usage](#usage)
- [Install Flow](#install-flow)
- [Configuration Reference](#configuration-reference)
  - [Kernel Parameters](#kernel-parameters)
  - [Boot Loader](#boot-loader)
  - [Initramfs](#initramfs)
  - [System Services](#system-services)
  - [Network Stack](#network-stack)
  - [System Tuning](#system-tuning)
  - [Environment Variables](#environment-variables)
  - [User Configuration](#user-configuration)
  - [Packages](#packages)
  - [Masked Services](#masked-services)
- [Managed Files](#managed-files)
- [Customization](#customization)
- [Safety & Reliability](#safety--reliability)
- [Uninstall](#uninstall)
- [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [License](#license)

---

## Quick Start

```fish
git clone https://github.com/ryanmusante/ry-install.git && cd ry-install
./ry-install.fish              # Deploy everything (unattended)
```

**Post-install verification:**

1. Reboot — required for kernel cmdline, initramfs, NetworkManager backend switch.
2. `./ry-install.fish --verify-static` — confirms managed files match embedded content.
3. `./ry-install.fish --verify-runtime` — confirms live kernel params, services, and modules are loaded.
4. Smoke test: WiFi associates, a Vulkan game launches via Steam/Proton.

Typical first-run duration: **3–8 minutes** (depends on package mirror speed and initramfs rebuild).

> [!NOTE]
> **Installing over WiFi?** The NetworkManager backend switch (wpa_supplicant → iwd) is deferred until your next reboot. On ethernet, run `sudo systemctl restart NetworkManager` once to apply immediately.

> [!IMPORTANT]
> **Since v4.5.2:** initramfs rebuild refuses to run when an earlier phase reported errors (torn-package guard). Set `RY_INSTALL_FORCE_BOOT_REBUILD=1` to override after manual remediation. Since v4.5.4, only the literal value `1` is accepted; any other value (including empty / `0` / typos) is treated as unset.

## Scope

**In scope:** system-wide CachyOS configuration (kernel cmdline, initramfs, systemd units, network stack, sysctl, gaming env vars), package install/remove via pacman + paru, masking of laptop power-management units for desktop use, single-user systemd `--user` units (ssh-agent, environment.d).

**Out of scope:** dotfiles, shell prompts, editor config, application settings, secrets/credentials management, backup orchestration, multi-user provisioning, non-CachyOS distributions, laptops (the script masks all sleep/suspend targets — adjust `MASK` in the inlined defaults if needed).

## Prerequisites

| Requirement | Detail |
|---|---|
| CachyOS | systemd-boot, ext4 |
| Fish | ≥ 4.0 recommended (3.6 minimum) |
| Kernel | ≥ 6.14 (≥ 6.18.4 for gfx1151) |
| Sudo | Unrestricted — no `requiretty`, `tty_tickets`, or `timestamp_timeout=0` |
| `$TMPDIR` (or `/tmp`) | Writable |
| Coreutils | GNU `sort -z`, `stat -c`, `find -printf`/`-samefile`, `df --output`, `timeout` (BSD/busybox incompatible) |
| Free space | 2 GB on `/`, 200 MB on `/boot` |
| Network + `curl` | Required |
| BIOS | Current — [Beelink downloads](https://dr.bee-link.cn/) |
| paru | Optional, for AUR |

**Recommended pre-flight steps:**

```fish
./ry-install.fish --check        # idempotency probe — see Exit Codes
sudo -v                          # warm sudo cache; confirms unrestricted sudo
df -h / /boot                    # verify space (≥2 GB / and ≥200 MB /boot)
```

Then review the [Masked Services](#masked-services) table — the script masks all sleep/suspend targets — laptop users must edit `MASK` in the inlined defaults block (marked `# === GTR9_PRO BUILT-IN DEFAULTS ===`) at the top of `ry-install.fish`. Check [CachyOS news](https://wiki.cachyos.org) and [Arch news](https://archlinux.org/news/) for breaking changes before any `pacman -Syu`.

## Hardware Reference

All kernel parameters, driver workarounds, and tuning values are calibrated against the components below. Other hardware requires forking and editing the inlined defaults block at the top of `ry-install.fish`.

| Component | Detail |
|---|---|
| BIOS | Latest from Beelink — P110+ recommended |
| CPU | Ryzen AI Max+ 395 — Zen 5, 16C/32T, 5.1 GHz · TDP 55 W (cTDP 45–120 W; Beelink: 140 W) |
| GPU | Radeon 8060S — RDNA 3.5, gfx1151, 40 CUs |
| RAM | 128 GB LPDDR5x-8000 |
| WiFi | MediaTek MT7925 (WiFi 7) |
| NIC | Dual Intel E610-XT2 10 GbE |
| Thermals | 85 °C sustained · 95 °C throttle · 100 °C max |

Check [Beelink](https://dr.bee-link.cn/) for BIOS updates, [kernel bugzilla](https://bugzilla.kernel.org) / [Mesa GitLab](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) for gfx1151 issues.

## Usage

All modes are non-interactive. The bare invocation is the primary path; verification flags (`--verify-static`, `--verify-runtime`, `--check`) are read-only and safe to run against an already-configured system. `--install-file` re-deploys a single managed file and does write.

| Flag | Description |
|---|---|
| (no args) | Full unattended install (the only install path) |
| `-V, --verbose` | Show output on terminal (errors are surfaced on rc≠0 regardless) |
| `--verify-static` | Check config files match embedded content |
| `--verify-runtime` | Check live system state (after reboot) |
| `--check` | Silent idempotency probe (exit 0 = clean, 3 = prereq fail, 10 = drift) |
| `--install-file <path>` | Re-deploy a single managed file |
| `-h, --help` | Show help |
| `-v, --version` | Show version |
| `--` | End of options |

## Install Flow

Six sequential phases — boot-critical failures abort immediately:

```
Preflight → Packages → Configuration → Services → Boot → Finalize
```

| Phase | Description |
|---|---|
| **Preflight** | Validate prerequisites (Fish ≥ 3.6, writable `$TMPDIR`, GNU `sort -z` / `stat -c` / `find -printf` / `df --output` / `timeout`, sudo without `requiretty` / `tty_tickets` / `timestamp_timeout=0`), acquire lock, validate runtime (root UUID, CPU model, timing globals) |
| **Packages** | Sync repos, install/remove packages, AUR via paru |
| **Configuration** | Deploy 15 embedded config files (atomic writes) |
| **Services** | Enable, mask, or create systemd units |
| **Boot** | Rebuild initramfs (gated on no-prior-errors), update systemd-boot entries |
| **Finalize** | Daemon-reload, cache cleanup, NM restart (deferred on active WiFi) |

## Configuration Reference

Each subsection corresponds to a discrete layer of the system. All values are embedded in the script and deployed via the paths listed in [Managed Files](#managed-files). Override any setting by editing the inlined defaults block at the top of `ry-install.fish` rather than the deployed managed files directly — doing so will cause `--verify-static` to report drift.

### Kernel Parameters

15 parameters written to `/etc/kernel/cmdline`.

<details>
<summary><b>Show parameter table (15)</b></summary>

| Parameter | Purpose |
|---|---|
| `amd_pstate=active` | Force amd_pstate_epp (Zen 5 native CPPC) |
| `amdgpu.cwsr_enable=0` | gfx1151 VGPR workaround |
| `amdgpu.ppfeaturemask=0xfffd3fff` | Disable overdrive / GFXOFF / stutter (bits 14, 15, 17) |
| `iommu=pt` | IOMMU passthrough |
| `loglevel=3` | Suppress kernel info/notice at boot |
| `module_blacklist=pcspkr` | Silence PC speaker |
| `nowatchdog` | Disable software watchdog |
| `pcie_aspm.policy=performance` | PCIe ASPM L0 always (desktop tower only; trades idle power for lower NVMe burst latency) |
| `quiet` | Suppress kernel boot messages |
| `rd.systemd.show_status=auto` | Initramfs unit status on errors only |
| `rd.udev.log_level=3` | Suppress udev info/debug in initramfs |
| `split_lock_detect=off` | Disable split-lock #AC (gaming) |
| `tsc=reliable` | Bypass TSC watchdog (Zen 5 invariant) |
| `usbcore.autosuspend=-1` | Disable USB autosuspend |
| `zswap.enabled=0` | Disable zswap (ZRAM in use) |

</details>

> [!NOTE]
> Single value per parameter. Comma-separated multi-value lists are not supported by the verifier — split into separate params or extend `_grep_kparam` if you need them.

### Boot Loader

Configures systemd-boot and sdboot-manage generation. `editor no` prevents live kernel cmdline tampering at the boot prompt; `timeout 0` boots the saved entry immediately with no menu delay.

| File | Key | Value |
|---|---|---|
| `loader.conf` | default | `@saved` |
| | timeout | `0` |
| | console-mode | `keep` |
| | editor | `no` |
| `sdboot-manage.conf` | LINUX_OPTIONS | See [Kernel Parameters](#kernel-parameters) |
| | LINUX_FALLBACK_OPTIONS | `"quiet"` |
| | DEFAULT_ENTRY | `"manual"` |
| | REMOVE_EXISTING | `"yes"` |
| | OVERWRITE_EXISTING | `"yes"` |
| | REMOVE_OBSOLETE | `"yes"` |

### Initramfs

`amdgpu` is forced unconditionally — it bypasses `autodetect` rather than relying on it to detect the module. `nvme` is pulled in by the `block` hook + `autodetect` pairing and does not need an explicit module entry. `zstd -1 -T0` uses all available threads at the fastest compression level — decompression is fast enough that the trade-off favors boot time over archive size.

| Setting | Value |
|---|---|
| Modules | `amdgpu` |
| Hooks | `base` → `systemd` → `autodetect` → `microcode` → `modconf` → `kms` → `keyboard` → `sd-vconsole` → `block` → `filesystems` → `fsck` |
| Compression | `zstd` |
| Compression Options | `-1 -T0` |

> [!IMPORTANT]
> Since v4.5.2, `mkinitcpio -P` is **not** invoked when an earlier install phase reported errors (e.g., pacman db lock, AUR dep failure). Override after manual remediation: `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish`.

### System Services

One custom unit is created and enabled. `power-profiles-daemon` is masked separately (see [Masked Services](#masked-services)) to prevent it from fighting `cpupower-epp` over the EPP sysfs knob.

| Unit | Description |
|---|---|
| `cpupower-epp.service` | Write `performance` to CPU `energy_performance_preference` sysfs |

### Network Stack

Three config files lock the WiFi stack to iwd as the NetworkManager backend with power-save disabled — required for MT7925 stability. DNS resolution is handled entirely by systemd-resolved; iwd delegates to it rather than writing `resolv.conf` directly.

| File | Setting |
|---|---|
| `resolved.conf.d` | MulticastDNS=resolve · LLMNR=no · DNSOverTLS=opportunistic · DNSSEC=allow-downgrade |
| `iwd/main.conf` | EnableNetworkConfiguration=false · DriverQuirks=`PowerSaveDisable=*` · NameResolvingService=systemd |
| `NetworkManager` | wifi.backend=iwd · wifi.powersave=2 · wifi.iwd.autoconnect=false · logging.level=WARN |

### System Tuning

Miscellaneous kernel and userspace tuning not covered by other subsections. `coredump.conf.d` is particularly important on this hardware — Wine and Proton processes can produce multi-GB core dumps that silently fill `/var`. Note that `/etc/fstab` is the only path modified outside the managed-file checksum pipeline; the rewrite itself is still atomic (tmp → post-mktemp symlink check → `findmnt --verify` → `sudo mv`) — see [Safety & Reliability](#safety--reliability).

| File | Setting |
|---|---|
| `logind.conf.d` | Ignore 9 power/suspend/hibernate/reboot key events |
| `coredump.conf.d` | Storage=none · ProcessSizeMax=0 |
| `drirc` | RADV unified VRAM heap (APU) |
| `sysctl.d` | BBR+fq · tcp_fastopen=3 · 10 GbE buffers · vm.max_map_count=max · 16 tunables |
| `/etc/fstab` | `noatime,lazytime,commit=10` on ext4 (in-place) |

### Environment Variables

Written to `~/.config/environment.d/10-environment.conf` for systemd user session pickup. All debug logging is silenced by default; re-enable selectively (`DXVK_LOG_LEVEL`, `VKD3D_DEBUG`, `WINEDEBUG`) only when diagnosing driver or shader issues — they generate significant volume under normal play.

<details>
<summary><b>Show 13 environment variables</b></summary>

| Variable | Value |
|---|---|
| `DXVK_LOG_LEVEL` | `none` |
| `DXVK_LOG_PATH` | `none` |
| `ENABLE_LAYER_MESA_ANTI_LAG` | `1` (AMD-only; if you later run mixed / Intel Arc hardware, override per-game with `DISABLE_LAYER_MESA_ANTI_LAG=1`) |
| `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| `PROTON_ENABLE_WAYLAND` | `1` (experimental; breaks Steam Overlay) |
| `PROTON_LOCAL_SHADER_CACHE` | `1` |
| `PROTON_NO_WM_DECORATION` | `1` (disables WM titlebars for borderless-fullscreen correctness under COSMIC; pairs with `PROTON_ENABLE_WAYLAND=1`) |
| `PROTON_USE_NTSYNC` | `1` (default in current proton-cachyos; explicit pin) |
| `RADV_EXPERIMENTAL` | `transfer_queue` |
| `RADV_PERFTEST` | `sam,nircache` |
| `VKD3D_DEBUG` | `none` |
| `VKD3D_SHADER_DEBUG` | `none` |
| `WINEDEBUG` | `-all` |

</details>

<details>
<summary><b>Deprecated flags — DO NOT re-introduce</b></summary>

The following environment variables have been removed upstream and must not be re-added to `ENV_VARS`. All four have been absent from this project's history; the list exists to prevent re-introduction during future refactors or contributions.

| Variable | Status |
|---|---|
| `DXVK_ASYNC` | removed (DXVK 2.3+ uses GPL; state cache removed in 2.7) |
| `DXVK_FRAME_RATE` | removed (use MangoHud / compositor framelimit) |
| `WINE_FULLSCREEN_FSR` | removed (handled by game or Proton config) |
| `VKD3D_FRAME_RATE` | **retained** — still valid in VKD3D-Proton |

</details>

<details>
<summary><b>Per-game tuning</b></summary>

Variables unsafe as global defaults but useful per-title. Apply in Steam → right-click game → Properties → Launch Options, prefixed before `%command%`.

| Variable | Use case | Trade-off |
|---|---|---|
| `MESA_VK_WSI_PRESENT_MODE=mailbox` | Latency-sensitive titles under Wayland | Breaks vsync for FIFO-honoring compositors |
| `DISABLE_LAYER_MESA_ANTI_LAG=1` | Games that crash under the anti-lag layer | No benefit; diagnostic-only |
| `PROTON_NO_WM_DECORATION=0` | Game needs WM decorations (overrides global `=1`) | Borderless-fullscreen may regress |
| `PROTON_FSR4_RDNA3_UPGRADE=1` | Force FSR4 on RDNA 3.5 (gfx1151) | Image quality varies per title |

</details>

### User Configuration

Three files deploy to the calling user's home. The SSH agent runs with `-D` (no daemonize) so systemd can supervise it directly and restart on crash without leaving stale socket files.

| File | Purpose |
|---|---|
| `fish/conf.d/10-ssh-auth-sock.fish` | SSH socket priority: forwarded > gcr > systemd agent |
| `environment.d/10-environment.conf` | Environment variables for systemd user services |
| `systemd/user/ssh-agent.service` | Persistent `ssh-agent -D` with crash recovery |

### Packages

Package operations run during the Packages phase with `--needed` for idempotency — already-installed packages are skipped on subsequent runs. The single AUR package (`mt76-mt7925-dkms`) requires paru; if paru is absent the script emits `[ERR]`, sets `INSTALL_HAD_ERRORS`, and the AUR phase is marked failed. The rest of the install pipeline continues to run *except* the boot rebuild (gated since v4.5.2) — set `RY_INSTALL_FORCE_BOOT_REBUILD=1` to bypass that gate.

| Action | Count | Packages |
|---|---|---|
| **Install** | 14 | mkinitcpio-firmware, nftables, nvme-cli, cachyos-gaming-meta, cachyos-gaming-applications, libva-mesa-driver, lib32-libva-mesa-driver, fd, sd, dust, procs, bottom, git-delta, lm_sensors |
| **Remove** | 8 | plymouth, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, ufw, octopi, micro, cachyos-micro-settings, btop |
| **AUR** | 1 | mt76-mt7925-dkms (paru required; phase fails if absent) |

### Masked Services

10 units masked — **review before running on laptops:**

<details>
<summary><b>Show masked services (10)</b></summary>

| Service | Reason |
|---|---|
| `ananicy-cpp.service` | Manual tuning preferred |
| `power-profiles-daemon.service` | Conflicts with cpupower-epp |
| `lvm2-monitor.service` | Skipped if LVM detected |
| `NetworkManager-wait-online.service` | Unnecessary boot delay |
| `systemd-coredump.socket` | Storage=none already suppresses storage; masking the socket eliminates spawn-and-discard overhead on Wine/Proton crashes |
| `sleep.target` | Desktop — no sleep |
| `suspend.target` | Desktop — no suspend |
| `hibernate.target` | Desktop — no hibernate |
| `hybrid-sleep.target` | Desktop — no hybrid sleep |
| `suspend-then-hibernate.target` | Desktop — no suspend-then-hibernate |

</details>

## Managed Files

15 files deployed via atomic writes (tmp → symlink-check → chmod → mv):

<details>
<summary><b>Show all 15 managed destinations</b></summary>

| Scope | Path |
|---|---|
| System | `/boot/loader/loader.conf` |
| System | `/etc/kernel/cmdline` |
| System | `/etc/sdboot-manage.conf` |
| System | `/etc/mkinitcpio.conf` |
| System | `/etc/systemd/resolved.conf.d/99-cachyos-resolved.conf` |
| System | `/etc/systemd/logind.conf.d/99-cachyos-logind.conf` |
| System | `/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf` |
| System | `/etc/iwd/main.conf` |
| System | `/etc/NetworkManager/conf.d/99-cachyos-nm.conf` |
| System | `/etc/drirc` |
| System | `/etc/sysctl.d/99-cachyos-sysctl.conf` |
| User | `~/.config/fish/conf.d/10-ssh-auth-sock.fish` |
| User | `~/.config/environment.d/10-environment.conf` |
| User | `~/.config/systemd/user/ssh-agent.service` |
| Service | `/etc/systemd/system/cpupower-epp.service` |

</details>

## Customization

Edit the `# === GTR9_PRO BUILT-IN DEFAULTS ===` block at the top of `ry-install.fish` to retune for different hardware. Re-run `./ry-install.fish --verify-static` after changes.

## Safety & Reliability

| Feature | Detail |
|---|---|
| Atomic writes | tmp → post-mktemp symlink check → chmod → mv (same FS); parent dir must be root-owned or uid=$UID, not a symlink, not group/world-writable |
| Permission model | System 0644 · user 0600 · `~/ry-install/` and per-day log dirs 0700 · log/marker files 0600 |
| fstab edits | Idempotent; symlink check before chmod; `findmnt --verify` before write; symlinked `/etc/fstab` rejected; **no backup** — snapshot first |
| Boot rebuild gate | v4.5.2: `mkinitcpio -P` refuses to run when earlier phases set `INSTALL_HAD_ERRORS=true`. Override: `RY_INSTALL_FORCE_BOOT_REBUILD=1` |
| Subprocess control | `_run` uses `timeout --foreground` so external `kill -TERM <pid>` propagates to the child process group |
| Child reaping | `_do_cleanup` runs `pkill -P $fish_pid` before keepalive teardown — closes the RY_RUN_TIMEOUT=0 untimed-branch hang |
| Stderr surfacing | First 5 lines of subprocess stderr mirror to fd 2 on rc≠0 even when `QUIET=true` (no `--verbose` needed for failure diagnosis) |
| Sudoers diagnostics | `sudo -n -l` stderr captured to JSONL; parse errors no longer mask as "requires full sudo" |
| Root detection | Refuses to run as root; sudo invoked internally |
| Instance lock | Atomic mkdir + `flock(1)` stale reclaim; sudo keepalive aborts on concurrent-instance directory recreation |
| Re-source guard | `_RY_INSTALL_LOADED` blocks double-source within a live run; cleared on clean exit (v4.5.2) so re-source after exit just works |
| Credentials | 15 sensitive flag patterns redacted in logs (passphrase, password, token, key, secret, api-key/apikey, psk, wpa-psk, private-key, auth, bearer, cookie, client-secret, credential) — applied to `_run` command lines and the dispatcher header argv |
| Signal handling | HUP/INT/QUIT/TERM → 128+signum; SIGPIPE → 141 |
| Cleanup invariant | Lock, tmpfiles, and sudo keepalive released on every exit path; cleanup is idempotent and re-entry-guarded |
| Boot safety | Aborts on initramfs/bootloader failure; loader-entry kernel paths canonicalized and ESP-boundary-checked |
| Log integrity | NDJSON to `~/ry-install/logs/YYYY-MM-DD/*.jsonl`; single-writer guard prevents subshell races; embedded newlines correctly escaped in JSONL payloads |
| mkinitcpio.conf rollback | v4.5.4: pre-deploy bytes captured; on `pacman -Syu` failure the prior content is restored via atomic mv to avoid a torn-package conf referencing modules from uninstalled packages |
| Read-fail diagnostic | v4.5.4: file-read failures during the idempotency probe no longer masquerade as "current state is empty" — surfaced as redeploy + JSONL `SKIP_PROBE_*` event |
| Log self-heal | v4.5.4: `_log` recreates LOG_FILE if removed mid-run (rotation race, external rm, dispatch rename failure) — events not silently dropped |
| Log rotation safety | v4.5.4: `find→sort→split0` pipeline pipestatus-gated; partial enumeration no longer triggers rotation |

<details>
<summary><b>Exit Codes</b></summary>

Codes are designed for scripting — non-zero always means something actionable. Code `10` is exclusive to `--check` (drift detected) and will never appear during a full install run; code `1` during install indicates a non-critical failure that did not abort the run.

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Non-critical failure / verification drift (`--verify-static`, `--verify-runtime`) |
| `2` | Usage error (argparse failures **and** policy refusals such as root-refusal) |
| `3` | Preflight failed (also `--check` prereq failure) |
| `4` | Boot-critical failure (includes torn-package gate refusal in v4.5.2) |
| `5` | Lock failed |
| `10` | Drift (`--check`) |
| `129/130/131/143` | Signal (HUP / INT / QUIT / TERM) |
| `141` | SIGPIPE |

</details>

<details>
<summary><b>Runtime Variables</b></summary>

Shell variables that modify script behavior at runtime — distinct from the gaming/Proton variables written to the system. Set them in the invoking shell before running; they are not persisted anywhere by the installer.

| Variable | Default | Purpose |
|---|---|---|
| `RY_RUN_TIMEOUT` | `3600` | Per-`_run` wall-clock cap (seconds). `0` = disable (not recommended). |
| `RY_INSTALL_CONFIRM_BOOT_WIPE` | unset | Set `1` to ack first boot-entry wipe (`SDBOOT_REMOVE_EXISTING=yes`). Re-prompts whenever the entry-set hash changes (entries added, removed, or renamed). |
| `RY_INSTALL_CONFIRM_SYSTEM_UPGRADE` | unset | Set `1` to ack unattended `pacman -Syu`. Without ack, prints arch/cachyos news headlines and skips `-Syu`. |
| `RY_INSTALL_FORCE_BOOT_REBUILD` | unset | **Since v4.5.4:** literal value `=1` required to bypass the torn-package gate (allows `mkinitcpio -P` even when earlier phases reported errors). Any other value, including empty / `0` / typos, is treated as unset. Recovery scenarios only. |
| `NO_COLOR` | unset | Suppress ANSI color (also auto on `TERM=dumb` / non-TTY stderr). |

> **Logging — secret-flag redaction:** `_run` and the dispatch-header logger redact values for `--passphrase`, `--password`, `--token`, `--key`, `--secret`, `--api-key`, `--apikey`, `--psk`, `--wpa-psk`, `--private-key`, `--auth`, `--bearer`, `--cookie`, `--client-secret`, `--credential` (both `--flag=value` and `--flag value` forms; v4.5.6+ for the dispatch header). Match is **case-sensitive lowercase only** — uppercase / mixed-case variants (`--Password=`, `--TOKEN=`) are **not** redacted. Use lowercase flag names when invoking commands that pass through `_run`.

</details>

<details>
<summary><b>Data Directory</b></summary>

All runtime state lives under `~/ry-install/`. The directory is created on first run and persists across installs. Logs accumulate per-day and are not pruned automatically — use `jq` against the NDJSON files for post-run analysis.

| Path | Contents |
|---|---|
| `~/ry-install/logs/YYYY-MM-DD/` | NDJSON logs (`*.jsonl`) |
| `~/ry-install/.lock/` | Instance guard |
| `~/ry-install/.boot-wipe-acknowledged` | Boot-wipe ack marker (delete to re-prompt) |

</details>

<details>
<summary><b>Log Format</b></summary>

Every mode writes structured NDJSON. Each line is a self-contained JSON object with a `ts` (ISO 8601) field.

| Event | Key Fields | Emitted |
|---|---|---|
| `header` / `footer` | version, mode, argv (header, redacted); exit_code, pass/fail/warn counts (footer) | Run start / end |
| `ok` / `fail` / `warn` / `err` / `info` | data | Verification results and status |
| `prog_step_start` / `prog_step_end` / `prog_done` | data (`[N/M] label`, `name=X secs=N`, `elapsed_secs=N`) | Phase progression |
| `run` / `stderr` | data | Subprocess execution and captured stderr |
| `section` | data | Phase boundary |
| `bug` | data | Internal assertion failure |

> ~70 additional prefix-routed event types (`lock_acquired`, `service_unmasked`, `pkg_remove_ok`, `ntsync_check`, etc.) follow the same `{"ts":TS,"event":NAME,"data":STR}` schema and are queryable with jq.

Query with jq: `jq 'select(.event == "fail")' ~/ry-install/logs/**/*.jsonl`

**Sample log output:**

```json
{"ts":"YYYY-MM-DDT14:23:01-0700","event":"header","version":"4.5.11","profile":"gtr9_pro","mode":"install","verbose":false,"argv":["./ry-install.fish"]}
{"ts":"YYYY-MM-DDT14:23:04-0700","event":"prog_step_start","data":"[1/6] Preflight"}
{"ts":"YYYY-MM-DDT14:23:12-0700","event":"prog_step_end","data":"name=Preflight secs=8"}
{"ts":"YYYY-MM-DDT14:23:12-0700","event":"prog_step_start","data":"[2/6] Packages"}
{"ts":"YYYY-MM-DDT14:25:19-0700","event":"err","data":"paru not found — cannot install AUR packages: mt76-mt7925-dkms"}
{"ts":"YYYY-MM-DDT14:26:42-0700","event":"footer","mode":"install","exit_code":1,"pass":46,"fail":1,"warn":0,"gen_fail":0}
```

</details>

## Uninstall

ry-install ships no automated uninstaller. The [Managed Files](#managed-files) table lists every deployed file as the source of truth for manual rollback. To revert: unmask the units in [Masked Services](#masked-services), `rm` the paths in [Managed Files](#managed-files), restore `/etc/fstab` from your own snapshot, optionally `pacman -S` the removed packages and `pacman -Rns` the installed ones, then `mkinitcpio -P && sdboot-manage gen` and reboot.

## Known Issues

<details>
<summary><b>Strix Halo GPU (gfx1151)</b></summary>

gfx1151 is a newly-released target with active upstream churn in both the kernel and Mesa. Expect regressions to land and get fixed within weeks — track the linux-cachyos changelog and the Mesa gfx1151 issue tracker before any driver or kernel upgrade.

| Issue | Status | Workaround |
|---|---|---|
| CWSR hang (VGPR count, compute) | Userspace fix in ROCm 7.2; kernel fix pending | `amdgpu.cwsr_enable=0` |
| MES page faults | Firmware-revision specific | Avoid `linux-firmware-20251125` (breaks ROCm on gfx1151); pin ≤ `20250808-1` for ROCm workloads or switch to `amdgpu-dkms-firmware` |
| ROCm VRAM allocation | Fixed in kernel 6.16+ | None — GTT auto-handled |
| PSR freeze (eDP only) | Open | `amdgpu.dcdebugmask=0x10` |
| Black screen | Kernel-version regressions | Downgrade / upgrade |
| ROCm compute | Requires env vars | `HSA_ENABLE_SDMA=0`, `HSA_OVERRIDE_GFX_VERSION=11.5.1` |

</details>

<details>
<summary><b>MediaTek MT7925 WiFi</b></summary>

The in-tree `mt76` driver has known stability bugs specific to the MT7925 revision. The `mt76-mt7925-dkms` AUR package carries out-of-tree patches ahead of mainline merge and should be the first remediation step. If instability persists, an Intel AX210 or AX211 is a well-tested drop-in alternative.

| Issue | Status | Workaround |
|---|---|---|
| Kernel panics (NULL deref `mt792x_mac_reset_work`) | Driver bug | `paru -S mt76-mt7925-dkms` |
| TX power reported as 3 dBm | Cosmetic; kernel patches pending | None |
| Random deauthentication | Intermittent | None |

</details>

<details>
<summary><b>NetworkManager + iwd</b></summary>

These issues are specific to the NM + iwd combination and do not affect wpa_supplicant setups. The boot connectivity failure in particular is intermittent and usually self-resolves after a radio cycle; it does not indicate a misconfigured backend.

| Issue | Workaround |
|---|---|
| Boot connectivity failure | `nmcli radio wifi off && nmcli radio wifi on` |
| WPA2/3 Enterprise GUI broken with iwd | Use CLI or switch to wpa_supplicant |
| Monitor mode requires full reboot | Reboot |

</details>

<details>
<summary><b>Progress bar disabled under mosh</b></summary>

The stationary bottom-row progress bar uses DECSTBM scroll-region
sequences (ESC [ N r / ESC [ r). mosh does not honor DECSTBM, so under
a mosh session the bar is suppressed and only `progress` JSONL events
are emitted. All other output is unaffected. Workaround: run under
SSH, tmux, or a local terminal.

</details>

## Troubleshooting

Start with `--verify-static` and `--verify-runtime` to confirm whether the issue is configuration drift or a runtime state problem. For deeper failures, `journalctl -b -k` and `dmesg -T` are the first sources. The table below covers the most common failure modes and their first-pass fixes.

| Problem | Diagnostic / Fix |
|---|---|
| GPU perf level stuck | `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` |
| WiFi backend mismatch | `grep wifi.backend /etc/NetworkManager/conf.d/99-cachyos-nm.conf; and pgrep -x iwd` |
| ntsync missing | Requires kernel 6.14+ · `ls /dev/ntsync` |
| Boot failure | Live USB → `arch-chroot` → `mkinitcpio -P` → `sdboot-manage gen` |
| FSR4 on RDNA 3.5 | Per-game: `PROTON_FSR4_RDNA3_UPGRADE=1 %command%` |
| Stale lock | `rm -rf ~/ry-install/.lock/` (only if no `pgrep -af ry-install`) |
| AUR pkg not installed | `command -q paru; or sudo pacman -S --needed paru` then re-run |
| Sudo cache expiry mid-run | `sudo -v; and ./ry-install.fish` |
| `drirc` XML rejected | `xmllint --noout /etc/drirc` |
| `--verify-static` drift | `./ry-install.fish --install-file /etc/...` |
| Initramfs rebuild refused | Phase errored earlier — fix root cause, then `RY_INSTALL_FORCE_BOOT_REBUILD=1 ./ry-install.fish` |
| Re-source error | Should auto-clear in v4.5.2; if stuck: `set -e _RY_INSTALL_LOADED` |

## References

Upstream sources for hardware quirks, driver status, and the Arch/CachyOS configuration guidance this project builds on.

| Resource | Topic |
|---|---|
| [NM + iwd](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend) | NetworkManager with iwd backend |
| [MT7925](https://wiki.archlinux.org/title/Network_configuration/Wireless#MediaTek) | MediaTek WiFi 7 driver info |
| [gfx1151 issues](https://gitlab.freedesktop.org/mesa/mesa/-/issues?label_name=gfx1151) | Mesa GPU tracker |
| [ppfeaturemask](https://wiki.archlinux.org/title/AMDGPU#Boot_parameter) | AMDGPU feature mask reference |
| [Strix Halo Toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) | ROCm containers + benchmarks |
| [Ollama gfx1151](https://github.com/ollama/ollama/issues/14855) | LLM setup for Strix Halo |

## License

[MIT](LICENSE) © 2026 Ryan Musante
