ry-install changelog

2026-04-07  Ryan Musante

- Tagged as v3.47.1
- fix: re-source guard no longer kills caller's interactive shell — uses `status is-interactive; and return 1; or exit 1` instead of unconditional `exit 1`.
- fix(SEC): _atomic_write_file — chown failure now returns 1 (was: _warn + INSTALL_HAD_ERRORS=true + return 0, leaving caller with mixed success/failure signal).
- fix: _acquire_lock — flock sh-block no longer writes PID inside the embedded /bin/sh -c (outer fish overwrites with same %self anyway); inner write was redundant.
- refactor: extract _write_footer helper; dedup four identical JSONL footer printf sites (_cleanup, _cleanup_pipe, _cleanup_on_exit, main exit) — single source of truth, idempotent via _FOOTER_WRITTEN guard inside helper.

2026-04-06  Ryan Musante

- Tagged as v3.47.0
- fix(SEC): _atomic_write_file — parent-dir trust check (root-owned, not symlink, not group/world writable) before sudo mktemp; closes TOCTOU window between mktemp and symlink probe.
- fix(SEC): _atomic_write_file — fail-closed when pre-mv expected hash is empty (sudo cred timeout / read failure no longer silently accepted); post-mv compare also fails on empty actual hash.
- fix: _ry_install_files — _argparse_tmp /dev/null fallback now emits one-shot WARN via _MKTEMP_DEGRADED_WARNED (parity with stderr/stdout_tmp paths).
- fix: _pregenerate_content_files — mktemp uses --tmpdir=/tmp explicitly; no longer honors $TMPDIR.
- fix: bootloader update — interactive confirm before destructive sdboot-manage gen when SDBOOT_REMOVE_EXISTING=yes and not --all (manual entries warning).
- fix: root invocation now emits explicit [NOTICE] when forcing --dry-run (was silent).
- refactor: extract _ry_count_managed_cases helper; dedup two identical case-counting blocks (was L1656 + L4927).
- refactor: extract _ry_mkinitcpio_array helper; dedup four mkinitcpio.conf grep pipelines (MODULES, HOOKS, COMPRESSION, COMPRESSION_OPTIONS).
- refactor: unify sudo cred-cache style in --diff --fix path with _ensure_sudo_cached (capture stderr, log on failure).
- fix: self-lint sed pipeline now strips heredoc bodies before grepping for bash $() patterns; reduces false positives in embedded sh/systemd blocks.
- docs: inline rationale on lint:ignore markers in embedded /bin/sh -c block; cpupower-epp.service inline-bash rationale comment added.
- docs: sync README, CHANGELOG.

ry-install changelog

2026-04-05  Ryan Musante

- Tagged as v3.46.0
- fix: sync header comment version to 3.46.0.
- fix: use string split -m1 '=' in sysctl content and verify checks.
- fix: dedup noatime when ext4 entry already has it.
- remove: drop usbhid.mousepoll=1. KERNEL_PARAMS stays 15.
- fix: add coredump.conf.d semantic checks to --verify-static.
- docs: sync README, CHANGELOG trimmed.
- Tagged as v3.45.0
- feat: add preempt=full kernel param. KERNEL_PARAMS 14→15.
- perf: remove vm.page_lock_unfairness=1 (kernel default is optimal).
- perf: netdev_max_backlog 300000→16384, add somaxconn=8192.
- fix: expand sysctl.conf header with priority-99 override note.
- docs: sync README, CHANGELOG.
- Tagged as v3.44.0
- fix: add '&' to SSID forbidden characters.
- fix: change .nmconnection IPv6 method=disabled → method=auto.
- fix: add '--' separator to grep in module/coredump checks.
- Tagged as v3.43.0
- feat: add PROTON_ENABLE_WAYLAND=1.
- feat: add 10 GbE sysctl buffer tuning. SYSCTL_VALUES 12→19.
- feat: mask irqbalance.service. MASK 9→10.
- feat: replace iommu=pt → amd_iommu=off.
- remove: drop VKD3D_CONFIG=transfer_queue (now default).
- Tagged as v3.41.0
- feat: add _install_fstab_opts (noatime,lazytime for ext4).
- feat: add ZRAM, swap, fstab runtime checks.
- feat: add PROTON_USE_NTSYNC=1. ENV_VARS 9→10.
- remove: drop 13 sysctl values now in CachyOS vendor config.
- remove: unmask zram, drop wdat_wdt from module_blacklist.

2026-04-02  Ryan Musante

- Tagged as v3.38.0 – v3.40.0
- feat: RADV_EXPERIMENTAL, VKD3D_CONFIG, shader cache, WINEDEBUG.
- feat: 10 GbE sysctl buffers, dirty page limits. SYSCTL_VALUES 11→23.
- remove: drop amdgpu-performance.service. Embedded files 16→15.
- fix: guard empty TMPDIR in fallback sweep.
- refactor: extract _emit_step_time helper (−10 lines).

2026-04-01  Ryan Musante

- Tagged as v3.35.0 – v3.37.2
- fix: return EXIT_PREFLIGHT(3) for --check infra failures.
- fix: set VERIFY_MODE in --diff for accurate JSONL counters.
- fix: call _manifest_write after --diff --fix success.
- fix: surface parallel validation child stderr.
- fix: 4 bare sudo cat → sudo -n cat.

2026-03-31  Ryan Musante

- Tagged as v3.23.0 – v3.34.0
- feat: managed sysctl.d config (11→22 tunables).
- feat: coredump.conf.d (Storage=none, ProcessSizeMax=0).
- perf: net −6 kernel params, restore clocksource=tsc.
- docs: README restructure (560→474 lines).

2026-03-25  Ryan Musante

- Tagged as v3.10.0 – v3.22.0
- feat: parallel verify-static hash workers, 4-job parallel check.
- fix: 292+ scope fixes, 202 &&/||→Fish, 96+ command prefix adds.
- remove: --no-color, --no-log, --clean, --json flags.
- docs: README rewrite with ToC, Install Flow, Known Issues.

2026-02-27  Ryan Musante

- Tagged as v3.0.0 – v3.9.0
- Initial release through early stabilization.
- Profile-driven config, 15 embedded files, NDJSON logging.
- 5-job parallel validation, batch processing, exit codes 0–11.
