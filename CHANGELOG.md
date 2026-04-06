ry-install changelog


3.46.0 (2026-04-05)

- fix(header): sync header comment version to 3.46.0.
- fix(sysctl): use string split -m1 '=' in content generation and
    verify-runtime sysctl checks (prevents incorrect split if future
    values contain '=').
- fix(fstab): add dedup step to prevent doubled noatime when ext4
    entry already has noatime alongside relatime.
- remove(kernel): drop usbhid.mousepoll=1 (global USB autosuspend
    disable via usbcore.autosuspend=-1 supersedes per-HID polling
    interval override). KERNEL_PARAMS stays 15.
- fix(verify): add coredump.conf.d semantic section to
    --verify-static. Checks Storage=none and ProcessSizeMax=0
    individually. Previously only hash-verified.
- docs: sync README (version badge 3.46.0, add coredump.conf.d to
    System Tuning reference table). CHANGELOG trimmed.

3.45.0 (2026-04-05)

- feat(kernel): add preempt=full. Pin Dynamic Preempt to full via
    cmdline — lowest scheduling latency for input and audio.
    KERNEL_PARAMS 14→15.
- perf(sysctl): remove vm.page_lock_unfairness=1. Kernel default 5
    provides optimal throughput per upstream benchmarking (commit
    5ef64cc8987a).
- perf(sysctl): reduce net.core.netdev_max_backlog 300000→16384
    (matches 10 GbE, not 40/100GbE server). Add
    net.core.somaxconn=8192. SYSCTL_VALUES stays 19.
- fix(sysctl): expand 99-cachyos-sysctl.conf header to document
    priority-99 override of CachyOS vendor config.
- fix(verify): update preempt runtime message.
- docs: sync README, CHANGELOG.

3.44.0 (2026-04-05)

- fix(wifi): add '&' to SSID forbidden characters (nmcli silent
    failure). Change .nmconnection IPv6 method=disabled →
    method=auto.
- fix(verify): add '--' separator to grep in blacklisted modules
    and coredump config checks.
- docs: sync README, CHANGELOG.

3.43.0 (2026-04-05)

- feat(env): add PROTON_ENABLE_WAYLAND=1.
- feat(sysctl): add 10 GbE buffer tuning, dirty page limits.
    SYSCTL_VALUES 12→19.
- feat(mask): add irqbalance.service. MASK 9→10.
- feat(kernel): replace iommu=pt → amd_iommu=off.
- remove(env): drop VKD3D_CONFIG=transfer_queue (now default).
- remove(verify): drop workqueue.power_efficient and wdat_wdt
    runtime checks.
- docs: sync README, CHANGELOG.

3.41.0 (2026-04-05)

- feat(fstab): add _install_fstab_opts (noatime,lazytime for ext4).
- feat(verify): add ZRAM, swap, fstab mount option runtime checks.
- feat(env): add PROTON_USE_NTSYNC=1. ENV_VARS 9→10.
- feat(sysctl): add fs.inotify, fs.protected_fifos/regular.
- remove(sysctl): drop 13 values now in CachyOS vendor config.
    SYSCTL_VALUES 22→12.
- remove(mask): unmask zram (enable compressed swap). MASK 10→9.
- remove(kernel): drop wdat_wdt from module_blacklist.
- docs: sync README, CHANGELOG.

3.38.0–3.40.0 (2026-04-02 – 2026-04-05)

- feat(env): RADV_PERFTEST→RADV_EXPERIMENTAL, add VKD3D_CONFIG,
    PROTON_LOCAL_SHADER_CACHE, WINEDEBUG. Remove AMD_VULKAN_ICD.
    ENV_VARS 7→9.
- feat(sysctl): 10 GbE buffers, dirty page limits, page-cluster,
    security hardening. SYSCTL_VALUES 11→23.
- feat(kernel): add usbhid.mousepoll=1. KERNEL_PARAMS 13→14.
- remove(service): drop amdgpu-performance.service (kernel default).
    Embedded files 16→15. EXPECTED_SERVICES 4→3.
- fix(cleanup): guard empty TMPDIR in fallback sweep.
- refactor(progress): extract _emit_step_time helper (-10 lines).
- style: remove decorative box-drawing, duplicate comments
    (-26 lines).
- docs: sync README, CHANGELOG.

3.35.0–3.37.2 (2026-04-01 – 2026-04-02)

- fix(check): return EXIT_PREFLIGHT(3) for infrastructure failures.
- fix(diff): set VERIFY_MODE for accurate JSONL counters.
- fix(diff-fix): call _manifest_write after successful fix.
- fix(validate): surface parallel validation child stderr.
- fix(sudo): 4 bare sudo cat → sudo -n cat.
- fix(docs): correct cTDP spec, CWSR kernel version, MT7925 TX
    power, clocksource latency range, black screen workaround.
- docs: sync README, CHANGELOG.

3.23.0–3.34.0 (2026-03-31 – 2026-04-01)

- feat(sysctl): managed /etc/sysctl.d/99-cachyos-sysctl.conf
    (11→22 tunables across releases).
- feat(resolved): LLMNR=no.
- feat(config): coredump.conf.d (Storage=none, ProcessSizeMax=0).
- perf(kernel): net -6 kernel params. Restore clocksource=tsc,
    quiet.
- docs: README restructure (flatten ToC, expand details,
    560→474 lines).
- style: remove decorative box-drawing, strip unnecessary quotes.

3.10.0–3.22.0 (2026-03-25 – 2026-03-30)

- feat(verify-static): parallel hash workers (min(4, nproc)).
- feat(check): 4-job parallel check with pre-serialized state.
- profile: add split_lock_detect=off, tsc=reliable, AUR_PKGS.
    MESA_SHADER_CACHE_MAX_SIZE 8G→4G. Remove udev rules file.
- fix: 292+ scope fixes, 202 &&/||→Fish, 96+ bare cat/rm→command
    prefix, signal handling, _gkeyfile_escape, _json_str newlines,
    PID lock ownership. Remove --no-color/--no-log/--clean/--json.
- docs: README rewrite, ToC, Install Flow, Known Issues.

3.0.0–3.9.0 (2026-02-27 – 2026-03-24)

- Initial release through early stabilization. Profile-driven
- config management, 15 embedded files, structured NDJSON logging,
- 5-job parallel validation, batch processing (B-1..B-9), exit
- codes 0–5/10–11, --check/--test-all/--completions. Adopt
- kernel.org changelog style.
