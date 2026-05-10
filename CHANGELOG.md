ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v5.0.19 - 2026-05-10
--------------------

  * logging: `_redact_argv_elements` — case-insensitive compare;
    `_RY_SECRET_FLAGS` extended with `--pass`, `--pw`,
    `--password-file`, `--token-file`. Short flags (`-p`/`-P`)
    intentionally not redacted (too ambiguous across tools).
  * services: `_csp_filter_rdeps` — warn-once when `pactree`
    is absent (pacman-contrib not installed); rdep-cascade
    safety was silently bypassed otherwise.
  * preflight: top-level `PATH` set preserves user `$PATH` after
    the canonical six dirs; previously hid `~/.local/bin` /
    `~/.cargo/bin` for `command -q paru`.
  * preflight: `bootctl` demoted from required to advisory in
    `_ry_check_deps`; `_resolve_esp` already falls back to
    `/boot` when bootctl absent.
  * preflight: `_validate_kernel_params` — inline note of
    intentionally-uncovered KERNEL_PARAMS (mainline-unconditional:
    iommu, loglevel, module_blacklist, nowatchdog, quiet, rd.*,
    tsc).
  * verify: `_chk_path_mode_in` for `~/.ssh/authorized_keys`
    accepts 600 only (was 600/644); `~/.ssh` dir retains 700-only.
  * aur: `_install_aur_packages` — `paru -S` passes `--skipreview`
    on both batch and per-package paths.
  * sudo: `_resolve_systemd_ver` logs `SYSTEMD_VER_PARSE_FAIL`
    when `systemctl --version` returns empty.
  * style: reorder `set -g AUR_PKGS` (mkinitcpio-firmware first)
    to match documentation.
  * style: condense script header; trim multi-clause inline
    rationale comments to single-line per project policy.
  * release: 5.0.18 → 5.0.19.

v5.0.18 - 2026-05-10
--------------------

  * cleanup: `_do_cleanup` /tmp sweep — explicit allowlist of six
    mktemp prefixes (`ry-sudo-err.*`, `ry-run.*`, `ry-val-unit.*`,
    `ry-ka-err.*`, `ry-sudo-l-err.*`, `ry-argparse-err.*`);
    replaces broad `ry-*` glob.
  * verify-static: `_verify_static_checksum` — branch on
    `_installed_bytes` exit code (0/1/2); decouples read failure
    from empty content.
  * runtime: `_vrk_module_state` — derive blacklist from
    `module_blacklist=` parse of `KERNEL_PARAMS` (was hardcoded
    pcspkr).
  * runtime: `_vrkg_vram` — regex shape-validate numeric before
    `test -gt`.
  * sudo: `_ip_probe_sudo_policy` — drop no-op `!PASSWD\b`
    alternative from regex.
  * preflight: GNU `grep -m1` probe added to coreutils chain.
  * help: exit-code summary disambiguated (1 = verify FAIL or
    install warn; 10 = --check drift).
  * cleanup: drop vestigial fish-completions sweep.
  * style: quote `$fish_pid` in `_acquire_lock_fresh`.

v5.0.17 - 2026-05-10
--------------------

  * security: `_chk_file` rejects `/boot/*` symlinks before
    `-f` probe (defense-in-depth against planted-link smuggle
    on ext4 XBOOTLDR).
  * style: pre-argparse `-h`/`-v` fast-path documented;
    `_ry_exit` log-dir rmdir cascade annotated race-safe;
    log-rename failure path is non-fatal.

v5.0.16 - 2026-05-10
--------------------

  * generators: `_ry_content_bytes` preserves dispatcher rc
    (EXIT_GEN_NOFN / NOUUID / SYSCTL) instead of collapsing to 1.
  * skip-iwd: explicit `_RY_IWD_GATED_DSTS` allowlist replaces
    `*/NetworkManager/*nm.conf` glob.
  * preflight: refuse if `HOME` is empty or non-dir after trim
    (handles `HOME="/"` edge).
  * mkinitcpio: `_mkinitcpio_hook_exists` collapses duplicated
    four-path existence check.
  * install: `_RY_BOOT_REBUILD_OK` decouples wipe-marker refresh
    from generic `INSTALL_HAD_ERRORS`.

v5.0.15 - 2026-05-10
--------------------

  * fstab: rewriter passthrough preserves original whitespace
    for non-ext4 / conformant lines; OFS="\t" only on rewritten
    entries.
  * fstab: `_fstab_needs_change` warns on existing non-10
    `commit=` value before override.
  * argparse: `--install-file=` rejects empty value; bare `--`
    followed by positionals → EXIT_USAGE.
  * locking: `_reclaim_stale_lock` falls back from atomic mkdir
    to flock-broker reclaim only when the previous PID proves
    dead via `/proc/<pid>/comm` + `cmdline` probe.

v5.0.14 - 2026-05-10
--------------------

  * boot: `_pbs_entry_has_valid_kernel` canonicalises `linux=`
    via `realpath -m`; refuses paths that escape `$BOOT` boundary.
  * boot: `_bwg_managed_only` auto-acks wipe gate when every
    entry is regenerable from `$ESP/vmlinuz-*`.
  * verify-runtime: `_vrk_clocksource` correlates TSC demotion
    via dmesg cache when HPET is current.

v5.0.13 - 2026-05-10
--------------------

  * sudo: `_start_sudo_keepalive` hermetic child via
    `fish --no-config -c`; inode-tied to `LOCK_DIR`.
  * sudo: `_check_sudo_keepalive` surfaces premature-exit cause
    from captured child stderr.
  * cleanup: `_do_cleanup` runs `pkill -P $fish_pid`
    (TERM → sleep → KILL) to reap descendants.

v5.0.12 - 2026-05-10
--------------------

  * progress: pinned scroll-region bar (DECSTBM) with SIGWINCH
    re-anchor; skipped under mosh / tmux / screen.
  * progress: `_progress_done` holds position on
    `_PROG_FINALIZED_SKIP=true` (boot-critical abort).

v5.0.11 - 2026-05-10
--------------------

  * mkinitcpio: pre-deploy `/etc/mkinitcpio.conf` before
    `pacman -Syu`; snapshot to tracked tmpfile; byte-exact revert
    on pacman failure.

v5.0.10 - 2026-05-10
--------------------

  * pkg-remove: `_csp_filter_rdeps` checks installed reverse-deps
    via pactree; cascade under `RY_INSTALL_PKG_REMOVE_CASCADE=1`.
  * pacman: `-Syu` retry uses `-Syyu` (force refresh) on first
    failure; aborts on db.lck mid-flight.

v5.0.9 - 2026-05-10
-------------------

  * services: `_cse_batch_enable` splits "enable ok, --now start
    failed" from "enable failed" via is-enabled probe.
  * nm: `_if_nm_restart` defers when WiFi is active route;
    handles VPN-over-WiFi via tunnel-iface detection.

v5.0.8 - 2026-05-10
-------------------

  * resolve: `_resolve_esp` (`bootctl -p`, fallback `/efi`,
    `/boot/efi`, `/boot`); `_resolve_boot_path` (`bootctl -x`
    for XBOOTLDR).
  * boot: `_preflight_boot_sanity` checks vmlinuz, initramfs
    non-zero, ≥1 entry references valid kernel.

v5.0.7 - 2026-05-10
-------------------

  * env: `RY_INSTALL_ALLOW_PARTIAL_UPGRADE=1` switches Packages
    phase to `pacman -Sy --needed` (no system upgrade); warns
    about Arch policy violation.
  * env: `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses boot-tainted
    gate.

v5.0.6 - 2026-05-10
-------------------

  * verify-runtime: `_vre_zram` accepts `static` + active zram
    swap as valid (template units).
  * verify-runtime: `_vre_thp_ksm` checks defer+madvise defrag,
    shrink_underused=0, ksm.run=0.

v5.0.5 - 2026-05-10
-------------------

  * pacnew: `.pacnew` at managed paths auto-resolved (re-deploy
    embedded, rm `.pacnew`); `.pacsave` warn-only.
  * sysctl: `_post_sysctl` runs `sysctl --system` on single-file
    install; warns if procps-ng absent.

v5.0.4 - 2026-05-10
-------------------

  * env: `NO_COLOR` adopts no-color.org spec — presence alone
    disables (any value, including empty).
  * env: `RY_RUN_TIMEOUT` integer parser unified through `math`;
    leading zeros accepted; `0` disables.
  * signals: `_cleanup` reports actual signal name (`SIGUSR1`
    etc.) instead of fixed string.

v5.0.3 - 2026-05-09
-------------------

  * pkgs: `htop` added to `PKGS_ADD` (12 → 13).
  * post-hook: `_post_boot` honours `_boot_wipe_gate` when
    `SDBOOT_REMOVE_EXISTING=yes` (parity with
    `_install_rebuild_boot`).
  * verify: `_vsb_cmdline` verifies live root UUID against
    `/etc/kernel/cmdline` (was presence-only).
  * preflight: `_validate_kernel_params` map gains
    `amd_pstate=CONFIG_X86_AMD_PSTATE`.

v5.0.2 - 2026-05-09
-------------------

  * verify: `_vre_zram` accepts `static` + swap-active.
  * aur: `paru` calls pass `--cleanafter`.

v5.0.1 - 2026-05-09
-------------------

  * style: trim verbose comments (`_RY_BOOT_TAINTED`, user-scope
    mkdir umask).

v5.0 - 2026-05-09
-----------------

  * release: stable milestone; no functional changes from v4.6.20.

----

Pre-v5.0 history (v4.5.x, v4.6.x development iterations) archived
to `ChangeLog-4.x` upstream.
