ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.4.26 - 2026-04-27
--------------------

  * Comments: multi-line `#` blocks collapsed to single lines; lint
    annotations and shebang/header preserved.
  * Verify: `_verify_static_system` mirrors generator's systemd<256
    skip for HandleSecureAttentionKey; closes cross-version drift
    between install and verify.
  * Tmpfile tracking: `_atomic_write_file` and `_install_fstab_opts`
    call `_untrack_tmpfile` on every failure path. _TRACKED_TMPFILES
    no longer carries dead entries between aborts.
  * Sudo cache: `_ensure_sudo_cached` cleanup gates `rm` on the
    `/dev/null` mktemp-fail sentinel.
  * Validators: `_grep_kv` adds defensive `case '*'; return 2` for
    unsupported destinations. `_grep_xml_tag` tightens
    `'<application'` to `'<application '` (trailing space).
  * Checksum verify: switch on joined `expected::actual` replaced
    with explicit `test -z` chain; removes `::`-substring ambiguity.
  * Cleanup: `_do_cleanup` erases `_RY_ESP_PATH` and
    `_RY_SYSTEMD_VER` alongside other memoized caches.
  * Logging: `_content__etc_kernel_cmdline` _err message typo
    corrected.
  * Pacman: `pactree -ru` output piped through `string trim --`
    before `string match -v`.


v4.4.25 - 2026-04-27
--------------------

  * Boot: `_resolve_esp` cache; `/boot/loader/entries` hardcoded sites
    replaced. Wipe-marker refuses 0-count writes; pipestatus checked
    across find→sort→split0; tmpfile untracked on success path.
    `linux_check` canonicalized via realpath -m.
  * Logging: `_log` enforces parallel-child guard via
    `_RY_LOG_OWNER_PID`; `_log_base_rot` derived from `LOG_DIR`.
  * Profile: metachar sanitizer extended to MASK, EXPECTED_SERVICES,
    EXPECTED_VULKAN_PKGS, PKGS_*, AUR_PKGS; ENV_VARS rejects
    SSH_AUTH_SOCK collisions.
  * Deps: GNU find -printf and df --output preflight probes added;
    required-cmd list widened (timeout, mktemp, awk, find, grep,
    sort, realpath, flock, bootctl); zcat / tput / nmcli / pkill
    moved to soft-warn list.
  * Fstab: OFS=tab restored; preserves column-aligned format.
  * Progress: tput gated on availability; tmux scroll-region skip;
    unknown step name logged.
  * Mkinitcpio: `systemd:keyboard` order assertion added; modules
    validator switched modprobe -n → modinfo.
  * Pacman.conf parsing: ParallelDownloads / IgnorePkg regex allow
    leading whitespace.
  * Verify: dmesg captured once in `_verify_runtime_kparams` and
    reused for TSC + ReBAR; `_chk_grep` distinguishes rc=2 (file
    error) from rc=1 (not-found); ssh-agent --user check diagnostic
    clarified for headless / no-user-bus; NM wifi info field renamed
    `nm_wifi_enabled`.
  * Content gen: `_content_bytes` drops redundant `test -z` check
    that conflated empty-but-valid output with generator failure.
  * Single-file: `_post_boot` names failed step in EXIT_BOOT_CRIT
    log line.


v4.4.24 - 2026-04-26
--------------------

  * Strings: revert L1310, fix L1461. v4.4.23 misdiagnosed; real
    closer-eating bug was `'\\'` vs grammar's left-biased `\\'|\\`
    regex. Bare `\\ \\\\` uses top-level escape, no string opens.
    fish-vs-grammar span divergence: 86 → 0.


v4.4.18..v4.4.23 - 2026-04-26
-----------------------------

  * Comment hygiene + fish-tmbundle grammar tripwire pass:
    multi-line `#` block collapse, ≤60c abbreviation, U+2026 drop,
    unbalanced quote/backtick/paren close. v4.4.23 misdiagnosis
    reverted in v4.4.24.


v4.4.8..v4.4.17 - 2026-04-26
----------------------------

  * Signal-handler, exit-path, namespace-cleanup re-entry guards.
    `_content_bytes` string-collect terminator (15/15 byte-equal
    round-trip). Comment rewrap and pipeline-orientation passes.


v4.4.0..v4.4.7 - 2026-04-25..2026-04-26
---------------------------------------

  * Profile system: $HOME/.config/ry-install/profiles/<name>.fish.
  * Verification split: --verify-static / --verify-runtime / --check.
  * Locking: mkdir mutex + flock(1) stale reclaim.
  * sudo keepalive with TERM→sleep→KILL teardown.


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256-keyed
    verification. cpupower-epp.service printf-truncation fix.


v4.2.x..v4.0.x - 2026-04-18..2026-04-25
---------------------------------------

  * Initial fish rewrite from v3.x bash. Single-file architecture,
    embedded generators, manifest-driven install, argparse CLI.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
