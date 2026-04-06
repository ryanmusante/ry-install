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
