ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.4.22 - 2026-04-26
--------------------

  * Comments: fix 2 unbalanced parens in `# Null-delim count (\n` form
    on L2596 + L4490 (TextMate fish grammar mis-colors comments
    after an unclosed `(` as code).
  * Hygiene gate: 9-category audit clean (backtick / single-quote /
    double-quote / paren / bracket / brace pair-balance, trailing
    `\`, control-chars, U+2026).


v4.4.21 - 2026-04-26
--------------------

  * Comments: close 3 unbalanced quotes/backticks left by the
    v4.4.19 truncator (L1091 `"`, L1459+L2323 `` ` ``). Caused
    GitHub's fish grammar to mis-color comments as code after
    each unclosed delimiter.


v4.4.20 - 2026-04-26
--------------------

  * Ellipsis: drop all U+2026 from script (0), CHANGELOG (was 8),
    README (was 1). ASCII `...` in functional output strings kept.


v4.4.19 - 2026-04-26
--------------------

  * Comments: abbreviate to ≤60 cols via 7-pass shrinker (subs +
    em-dash + paren drop + clause drop + word-boundary cut). No
    ellipsis. 106 ≤52, 70 at 53-60.


v4.4.18 - 2026-04-26
--------------------

  * Comments: collapse multi-line `#` blocks back to single-line
    (reverts v4.4.16 + v4.4.17 wraps). 5370→5147 lines.


v4.4.17 - 2026-04-26
--------------------

  * Comments: re-wrap inline `#` blocks to ≤60 cols (textwrap pass).
  * _json_str: leading-pipe `\` `| cmd` → trailing-pipe `cmd |`
    (universally parseable; GitHub fish grammar gutter clean).


v4.4.16 - 2026-04-26
--------------------

  * audit: 6 INFO-tier observations from v4.4.15 line-by-line
    review — bootstrap [ERR] echo + L5135 notice bypass _msg
    NO_COLOR/QUIET/TTY logic; bail-via-_ry_exit forward-compat
    risk; _INTENDED_EXIT_CODE name overlap; _progress_init lacks
    $TERM-shape guard. Zero defect; deferred.
  * _json_str: 5-step `set val (string replace -a X Y | collect)` chain
    → single pipeline. Trailing `string collect --allow-empty`
    keeps count=1 on empty input (preserves cartesian-concat
    contract at L5063 argv emit). 17/17 round-trip equivalent.
  * Comments: rewrap 8 `@@AUDIT@@` notes + 4 long inlines at ~78
    cols. Rewrite `# Escape \\, \x22, \n, \r, \t for JSON` to
    plain English (highlighter-safe).


v4.4.15 - 2026-04-26
--------------------

  * _ry_install_ssh_agent / _post_service: collapse the two-line
    `_run CMD ARGS \n or _warn MSG` SSH_AUTH_SOCK propagation pattern
    to the project-standard `; or _warn MSG` form. Functionally identical;
    aligns with the 12 sibling sites that already use the same-line
    combinator. Two occurrences (install path and re-deploy path).
  * Comments: trim ten multi-line `@@AUDIT@@` blocks and the `_log`
    INVARIANT block to single-line form. Script header (lines 1-2)
    and embedded `lint:ignore` markers preserved verbatim. No
    semantic change; reduces script line count without losing intent.




  * _content_bytes: terminate pipeline with `string collect
    --no-trim-newlines` so the outer command sub preserves the trailing
    `\n`. Pre-fix, every managed file (15/15) lost its final `\n` on
    capture, while `_installed_bytes` preserved it — every comparison
    site read off-by-one and reported a 1-byte diff. Effect:
    `_ry_install_file` (2471) never short-circuited "unchanged" and
    rewrote every file every install; `_verify_static_checksum` (2879)
    reported false MISMATCH on every managed file; `_ry_do_check` (2945)
    reported false drift, breaking the EXIT_DRIFT=10 contract. Verified
    in fish 3.7: 15/15 destinations now round-trip byte-equal.
  * _ry_check_deps: add `curl` to the required-tools list. Drops the
    `command -q curl` gate in `_ry_check_network` — a missing curl is
    now caught upfront with an accurate "missing: curl" preflight error
    instead of falling through to ping and producing a misleading
    "HTTPS or DNS unreachable" diagnostic.
  * _install_fstab_opts: replace `(string match -r '(^|,)commit=\d+')[3]`
    with `(string match -rg '(?:^|,)commit=([0-9]+)(?:,|$)')`. Removes
    the fragile capture-index dependency that broke silently on regex
    edits and returns the digits directly via `--groups-only`.
  * _load_profile: distinguish empty `default-profile` (file present,
    no usable name after trim) from missing file in
    PROFILE_DEFAULT log message. Both paths still fall through to the
    built-in default; the log now reflects which one fired.
  * _verify_static_checksum: log SHA256 of expected/actual on MISMATCH
    instead of dumping raw bytes (subject to the 4 KB `_log` cap). No
    managed-config content leaks into JSONL logs; bounded line length;
    SHA mismatch is sufficient evidence of drift.
  * _progress_init / _progress: derive `_PROG_TOTAL` from new
    `_PROG_STEPS` list (single source of truth). `_progress` now takes
    an optional 2nd `outcome` arg, recorded in PROG_STEP_START as
    `outcome=<value>`; `_ry_do_install` already passed "skip" on the
    boot-critical Finalize bypass and the value is no longer dropped.
  * _verify_runtime_kparams: stop materializing the full kernel ring
    buffer into a fish list (`set -l _dmesg (sudo -n dmesg)`). Two
    grep pipelines now invoke `sudo -n dmesg` directly. Fish-side
    memory cost drops from O(ring_size) to O(matched_lines); kernel
    pays for two extra ring reads (negligible).
  * _RY_SYSTEMD_VER: anchor regex to `^systemd (\d+)` in all three
    capture sites (logind generator, environment.d validator,
    `_ry_check_deps`). Pre-fix `\d+` worked only because systemd's
    version line happens to start with the major number; would have
    silently mis-parsed if upstream prepended a build serial.
  * _install_finalize: chain `; or _warn` on the post-NM-restart
    `_run sleep $NM_RESTART_DELAY` for consistency with surrounding
    `_run` calls. Sleep failure (signal interrupt) is now logged.
  * Post-hooks: surface `$target` in `_post_logind`, `_post_envd`,
    `_post_drirc` info messages. Argument was declared but unused.
  * _log: gate on `_RY_NO_LOG` env var as belt-and-braces enforcement
    of the "no _log from parallel children" invariant. Sudo-keepalive
    `fish -c` child now spawned via `env _RY_NO_LOG=1`.
  * CachyOS April 2026 release cross-check: NVMe scheduler default
    moved from `none` to `kyber` via cachyos-settings, blocky DoH
    layered above systemd-resolved, chwd-based fingerprint sudo.
    None overlap with the Strix Halo profile's managed surface; no
    profile changes required this cycle.


v4.4.13 - 2026-04-26
--------------------

  * Cleanup invariant: pair `command rm -f -- "$LOG_FILE"` with
    `command rmdir -p -- "$LOG_DIR"` at all 20 unpaired bail sites
    (kernel-version parse, lock-acquire 7×, _load_profile 11×,
    install-file no-target). Failed runs no longer leave behind an
    empty `~/ry-install/logs/<date>/` tree. The 6 argparse-time bails
    already had this pairing; full coverage is now 26/26.
  * Dead code: remove udev post-hook surface that became unreachable
    after v4.4.12 dropped the rqaffinity rule. Surfaces removed:
    `_post_udev` function, `_grep_udev_kv` validator,
    `*/udev/rules.d/*` install-validation case,
    `*/udev/rules.d/*|udev` post-hook dispatch entry,
    `_has_udev_dst` block in `_configure_services_preset`,
    `udevadm` from required-tools preflight check.
    Function descriptions retitled to match: `_configure_services_preset`
    "udev finalize, ..." → "systemd-resolved restart, ...";
    `_verify_static_system` "ntsync, udev, ..." → "ntsync,
    modules-load, ..."; internal section header "── Udev rules ──"
    → "── Modules autoload ──" (was always checking modules-load.d,
    never udev rules).


v4.4.12 - 2026-04-26
--------------------

  * Managed files: drop /etc/udev/rules.d/99-nvme-rqaffinity.rules.
    rq_affinity=2 was a small win on Sandy Bridge / Haswell when
    completion soft-IRQs landed on a different L3 from the submitter;
    on a single-CCD Strix Halo APU every CPU shares one L3, so pinning
    completions buys nothing measurable. Managed file count 16 → 15.
  * Bootstrap: _RY_MANAGED_FILE_COUNT 16 → 15. Profile descriptions and
    SYSTEM_DESTINATIONS comment retitled (12+3+1 → 11+3+1).
  * Docs (README): event-table rows progress/step_time replaced with
    actual emitted events prog_step_start/prog_step_end/prog_done; the
    elapsed value lives inside `data` as `secs=N`, not in a separate
    `elapsed_s` field. Sample JSONL block rewritten to match real
    output. Footer version bumped (4.4.8 → 4.4.12).
  * Docs (README): kernel-floor wording corrected. The hard floor is
    6.14 (ntsync + gfx1151 base support); 6.18.4 is a soft warn for
    gfx1151 stability. Badge and prereq table reworded accordingly.
  * Docs (README): profile-mode trust wording tightened — "mode≤0755"
    replaced with the actual rule "no group/world write bit" plus the
    enforcing regex.
  * Docs (README): "~50 prefix-routed events" → "~70" (actual: 69).


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
