ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.4.11 - 2026-04-26
--------------------

  * _ry_exit: set _CLEANUP_DONE before BAILING/LAST_EXIT so a signal
    arriving between sentinel sets cannot fork the cleanup path.
  * _ry_do_install: poll _RY_INSTALL_BAILING after every install phase
    (preflight, packages, AUR, system files, fstab, services, boot)
    so a sourced-mode signal unwinds the dispatch tree instead of
    continuing past the handler.
  * Lint hygiene: `command grep` parity at two sites that escaped the
    `command <bin>` discipline used elsewhere.
  * Naming: top-level dispatch global `exit_code` → `_RY_EXIT_CODE`,
    matching the `_RY_*` convention for internal globals.
  * Header: dynamic-dispatch table documented inline so static
    analysers don't flag _post_*, _content_*, _ry_profile_* as dead.


v4.4.10 - 2026-04-26
--------------------

  * _load_profile: propagate _RY_INSTALL_BAILING after each interior
    _ry_exit so source-mode unwinds before executing against an
    erased namespace; eight call sites missed the guard.
  * _install_packages: failed `pacman -Syu` under
    RY_INSTALL_CONFIRM_SYSTEM_UPGRADE=1 now aborts before
    `mkinitcpio -P` so torn package state cannot ship to /boot.
  * Bootstrap: drop dead `set -g HOME ~` fallback (fish ~ requires
    HOME be set, so the line could never recover an unset HOME).


v4.4.9 - 2026-04-26
-------------------

  * _ry_exit, _ry_namespace_cleanup: idempotency guards against
    re-entry. A second bail (e.g. --version → root-check) was
    erasing PATH/LANG/USER/fish_* from the parent shell when sourced,
    because the snapshot of pre-existing globals had been erased on
    the first pass.


v4.4.8 - 2026-04-26
-------------------

  * Signal handlers: set _CLEANUP_DONE before _do_cleanup runs so a
    signal arriving mid-cleanup short-circuits via the handler guard
    instead of double-firing.


v4.4.0..v4.4.7 - 2026-04-25..2026-04-26
---------------------------------------

  * Profile system: file-based override at $HOME/.config/ry-install/
    profiles/<n>.fish; owner/mode/syntax gates before source.
  * Verification: --verify-static (content checksum) and
    --verify-runtime (live state) split from install path.
  * --check: silent idempotency probe; exit codes 0 clean /
    3 prereq fail / 10 drift.
  * Locking: atomic mkdir mutex + flock(1) stale-lock reclaim.
  * sudo keepalive: cached subshell with TERM→sleep→KILL teardown
    plus pkill -P descendant reap.


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators (one per managed file); SHA256-keyed
    verification.
  * cpupower-epp.service printf truncation fix (v4.3.4).


v4.2.x..v4.0.x - 2026-04-18..2026-04-25
---------------------------------------

  * Initial fish rewrite from the v3.x bash original. Single-file
    architecture, embedded config generators, manifest-driven install
    loop, argparse CLI.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Per-file shell blocks; ad-hoc verification;
    no manifest. Superseded by the v4.0 fish rewrite.
