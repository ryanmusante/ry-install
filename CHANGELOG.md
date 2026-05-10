ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v5.0.11 - 2026-05-10
--------------------

  * ssh-agent: user-scope `ssh-agent.service` and the
    `~/.config/fish/conf.d/10-ssh-auth-sock.fish` socket-priority
    helper removed from managed destinations. The
    `SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket` line is
    dropped from the `environment.d/10-environment.conf` generator.
    `_content_*ssh-auth-sock.fish`, `_content_*ssh-agent.service`,
    `_check_env_ssh_auth_sock`, `_check_phase_user_ssh`,
    `_vrsv_ssh_agent`, and `_cse_ssh_agent` deleted. SSH agent
    handling now defers entirely to whatever the user configures
    outside ry-install scope.
  * config dispatch: `*/fish/conf.d/*.fish` post-hook glob removed
    from `_RY_POST_HOOKS`; `_idf_dispatch_hook` allowlist drops
    `fish`; `_post_fish` and `_rvc_fish_syntax` deleted (no managed
    fish config files remain). `_rvc_dispatch` drops the `*.fish`
    case.
  * verify: `_verify_static_user` reduces to environment.d ENV_VARS
    coverage (description: "Verify environment.d ENV_VARS"). The
    "── SSH agent ──" subsection is gone. `_verify_static_syntax`
    drops the user-svc + fish-script blocks (description: "Validate
    mkinitcpio hooks ordering, systemd unit files").
    `_verify_runtime_services` drops the ssh-agent call (description:
    "Verify systemd unit states (sys batch) and WiFi runtime").
  * services: `_configure_services_enable` drops the
    `_cse_ssh_agent` call and the user-scope `daemon-reload` (no
    managed user services remain). Description: "Daemon-reload,
    batch-enable system units". `_post_service` drops the
    `*ssh-agent*` SSH_AUTH_SOCK propagation block; success branch
    inverted to a single failure check.
  * counts: `_RY_MANAGED_FILE_COUNT` 14 → 12. `USER_DESTINATIONS`
    reduces from 3 to 1 entry (environment.d only).
    `_ir_validate_counts` invariants unchanged (ENV_VARS:10 stays —
    the SSH_AUTH_SOCK line was a separate printf, never part of
    `$ENV_VARS`).
  * docs: README install-flow row counts resync (Configuration 14
    → 12); ssh-agent.service mention removed from Services row;
    Environment Variables section drops "11 vars (10 + 1 binding)"
    framing → "10 vars"; SSH_AUTH_SOCK row removed from env-vars
    table; Show count 11 → 10. User Configuration table reduces to
    a single row. Managed Files section: header and table drop the
    two SSH user destinations; count 14 → 12.
  * release: 5.0.10 → 5.0.11.

v5.0.10 - 2026-05-10
--------------------

  * coredump: `/etc/systemd/coredump.conf.d/99-cachyos-coredump.conf`
    removed from managed destinations; `_content_*` generator,
    `_post_coredump` hook, and `*/coredump.conf.d/*` entry in
    `_RY_POST_HOOKS` deleted. `_idf_dispatch_hook` allowlist drops
    `coredump`. Managed file count 15 → 14
    (`_RY_MANAGED_FILE_COUNT` invariant updated).
  * mask: `systemd-coredump.socket` removed from `MASK`. Coredump
    handling reverts to upstream systemd defaults; users wanting the
    prior Wine/Proton dump suppression can deploy
    `coredump.conf.d/Storage=none` independently or `systemctl mask
    systemd-coredump.socket` manually. MASK count 11 → 10
    (`_ir_validate_counts` invariant updated).
  * verify: `_verify_static_system` drops the coredump.conf
    block (description trimmed: "Verify ntsync, modules-load,
    resolved, logind, iwd, NM, drirc, sysctl"). `_vrk_clocksource_coredump`
    renamed to `_vrk_clocksource` — the coredump file-presence check
    is gone; clocksource + TSC-demotion correlation retained.
    `_verify_runtime_kparams` description and call site updated.
  * docs: README "System Tuning" intro and table drop the
    `coredump.conf.d` row; "Masked Services" header and table drop
    `systemd-coredump.socket`; "Managed Files" header and table drop
    the coredump destination; install-flow row counts resync
    (Configuration 15 → 14, Services mask 11 → 10).
  * release: 5.0.9 → 5.0.10.

v5.0.9 - 2026-05-10
-------------------

  * boot: `_post_boot` now refreshes `~/ry-install/.boot-wipe-acknowledged`
    after successful entry rebuild when `SDBOOT_REMOVE_EXISTING=yes`,
    matching `_install_finalize`. `--install-file` of a boot-tagged
    target no longer leaves the marker stale; subsequent runs fast-ack
    via marker hash instead of falling through to `_bwg_managed_only`
    every time.
  * fstab: `_far_awk_rewrite` adds a pre-skip block — ext4 lines that
    already have `noatime`, `lazytime`, AND `commit=10` pass through
    unchanged. Eliminates incidental space→tab conversion of correctly
    configured entries when any other ext4 line needed a rewrite. The
    OFS-driven recompose now fires only on lines that actually need a
    change.
  * verify: `_vrk_clocksource_coredump` distinguishes "scanned dmesg,
    no TSC demotion markers" from "could not scan dmesg" (empty
    `_RY_DMESG_CACHE` from sudo lapse or `kernel.dmesg_restrict=1`
    without sudo). Prior message misleadingly suggested checking
    BIOS/firmware when no scan happened.
  * boot: `_resolve_esp` `/boot` fallback now verifies `/boot` is a
    directory before caching. In chroot/recovery scenarios where
    `/boot` is unmounted, autodetect emits a clear error
    (`ESP_RESOLVE_HARD_FAIL`) and caches an empty path; downstream
    consumers fail their `test -d` checks gracefully instead of
    operating on a phantom path.
  * style: header comment version corrected (was lagging at v5.0.7).
  * style: 4 namespace section headers added — `# RUNTIME INIT`,
    `# CONTENT GENERATORS`, `# BOOT PATH RESOLUTION`,
    `# POST-INSTALL HOOKS` — for navigability of the 5023-line script.
  * release: 5.0.8 → 5.0.9.

v5.0.8 - 2026-05-10
-------------------

  * style: 114 cluster-internal blank lines removed between
    consecutive same-prefix `_NS_*` functions (e.g. `_content_`,
    `_post_`, `_ry_`, `_chk_`, `_vrsv_`). 113 namespace-boundary
    blanks retained as section separators; 23 top-level/function
    boundary blanks retained. No banner comments added — function
    names self-document namespace; "why-not-what" comment rule
    precludes namespace labels.
  * verify: 246/246 functions retained, 827/827 top-level `end`
    statements retained, zero consecutive-blank lines, all 15
    `_content_*` payload outputs byte-identical to v5.0.7.
  * release: 5.0.7 → 5.0.8.

v5.0.7 - 2026-05-10
-------------------

  * style: `_idf_dispatch_hook` 10-case switch collapsed to dynamic
    `_post_$tag "$target"` dispatch. Pre-existing allowlist
    `contains -- "$tag" $_known` retained as the gate; unknown-tag
    error path unchanged.
  * style: `_rvc_dispatch` drops trailing `return $status` after each
    validator call; fish returns last-command status implicitly.
    Behaviour preserved across all eight branches.
  * style: 33 single-line "what" comments removed (labels restated
    by adjacent code; historical change-notes). Section banners,
    `lint:ignore` markers, `SECURITY:` tags, and "why" comments
    retained.
  * style: 4 incidental double-blank line clusters collapsed.
  * verify: 15/15 `_content_*` payload outputs byte-identical to
    v5.0.6.
  * release: 5.0.6 → 5.0.7.

v5.0.6 - 2026-05-10
-------------------

  * env: RADV `transfer_queue` is gated by `RADV_PERFTEST`, not by
    `RADV_EXPERIMENTAL` (which silently no-op'd the request). Folded
    into `RADV_PERFTEST=sam,nircache,transfer_queue`; the standalone
    `RADV_EXPERIMENTAL` line is dropped. ENV_VARS member count drops
    11 → 10.
  * preflight: `_ir_validate_counts` ENV_VARS invariant 11 → 10
    tracks the env-var change above.
  * preflight: `_ir_validate_counts` PKGS_ADD invariant 12 → 13
    tracks the htop addition in v5.0.3 that was missed at the time.
  * docs: README env-var table drops `RADV_EXPERIMENTAL` row, updates
    `RADV_PERFTEST` value, and resyncs prose count (12 → 11) and
    summary count (12 → 11).
  * release: 5.0.5 → 5.0.6.

v5.0.5 - 2026-05-09
-------------------

  * docs: README version badge synced to script (5.0.3 → 5.0.5);
    `mirror projects match source version` invariant restored after
    v5.0.4 release-process oversight.
  * release: 5.0.4 → 5.0.5.

v5.0.4 - 2026-05-09
-------------------

  * cli: `--` now terminates flag-recognition in the early-arg loop; any
    token after `--` (including `-h` / `--version`) is rejected as a
    positional with `EXIT_USAGE`. `-h` / `-v` *before* `--` remain
    honoured.
  * cli: `--install-file <flag>` (separate-arg form) now disambiguates
    when the consumed value matches a known mode flag — emits a
    "value vs flag" hint instead of the generic leading-dash error.
    Suggests `--install-file=<path>` for paths starting with `-`.
  * env: `NO_COLOR` adopts the no-color.org spec — presence alone
    disables (any value, including empty). Prior behaviour required a
    non-empty value.
  * env: `RY_RUN_TIMEOUT` integer parser unified through `math` —
    leading-zero forms (`01`, `0001`) now accepted; `00`, `000` map to
    `0` (disable). Invalid non-numeric values still warn-once and fall
    back to default.
  * signals: `_cleanup` warning line now reports the actual signal
    name (`Caught SIGUSR1 - cleaning up...`) rather than a fixed
    "Interrupted" string. USR1/USR2/ABRT delegated path preserved via
    `_cleanup_other`.
  * check: `_check_phase_cmdline` return-status now captured
    symmetrically with sibling phases. Future non-zero returns from
    that phase will surface instead of being masked by the next call.
  * docs: `_ry_show_help` env-var block resynced with README — `NO_COLOR`
    wording, `RY_INSTALL_CONFIRM_BOOT_WIPE` marker semantics
    (persisted at `~/ry-install/.boot-wipe-acknowledged`,
    re-prompts on entry-set hash change).
  * style: header comment version corrected (was lagging at v5.0.2).
  * release: 5.0.3 → 5.0.4.

v5.0.3 - 2026-05-09
-------------------

  * pkgs: `htop` added to PKGS_ADD (12 → 13).
  * post-hook: `_post_boot` now calls `_boot_wipe_gate` when
    `SDBOOT_REMOVE_EXISTING=yes`, matching `_install_rebuild_boot`.
    `--install-file /etc/kernel/cmdline` (or any other boot-tagged
    target) no longer silently wipes loader entries.
  * verify: `_vsb_cmdline` root=UUID check tightened — when
    `$_ROOT_UUID` is resolved, the check verifies the live UUID
    appears in `/etc/kernel/cmdline` (was: presence-of-`root=UUID=`
    only; UUID drift was masked at per-param level, only caught by
    the checksum gate).
  * preflight: `_validate_kernel_params` map gains
    `amd_pstate=CONFIG_X86_AMD_PSTATE`. Strix Halo target relies on
    amd_pstate=active; missing CONFIG would have silently degraded.
  * msg: `_msg` counter bumps gated on `VERIFY_MODE=true`. Install
    mode no longer mutates `VERIFY_OK/FAIL/WARN` globals (read only
    by `_verify_summary`).
  * verify: `_verify_runtime_services` drops dead `; or return 1` —
    `_vrsv_sys_units` always returns 0 in practice; the env+session
    skip path was unreachable but surprising. Caller's `if` block
    flattened.
  * mkinitcpio: `_ry_mkinitcpio_array` drops redundant
    `grep -v '^#'` stage; the anchored `^[[:space:]]*$key=` regex
    cannot match a line that starts with `#`.
  * style: comment for `_RY_BOOT_TAINTED` now lists all 4
    boot-critical destinations (was: 3, drift from
    `_RY_BOOT_CRITICAL_DSTS`).
  * style: `argparse --name=(status basename)` (no fork; was
    `(basename -- (status filename))`).
  * style: `_rot_ps[1]" -eq 0` (numeric, was `=`).
  * style: comment above `_content_HOME_…ssh-auth-sock.fish`
    rewritten — empirically verified that fish_indent stripping
    quotes from `'end'` is safe (fish only treats `end` as a block
    terminator as the first word of a command, never as a printf
    argument). Content output byte-identical either way.
  * style: whole script reformatted via `fish_indent`. Compact
    `; and …; or …` chains expanded to canonical multi-line form.
    All 15 `_content_*` payload outputs verified byte-identical to
    v5.0.2 (15/15 diff empty against /tmp/orig_contents.txt).
  * release: 5.0.2 → 5.0.3.

v5.0.2 - 2026-05-09
-------------------

  * verify: `_vre_zram` accepts systemctl state `static` paired with
    an active zram swap device. Template units instantiated by
    zram-generator cannot be `enabled`; the prior strict-`enabled`
    check unconditionally warned on a correct configuration. New
    `static` + no-swap path warns; new `masked` message updated.
  * aur: `_install_aur_packages` — pass `--cleanafter` to paru on
    both batch and per-package retry calls. Removes srcdir on
    successful build; eliminates `==> WARNING: Using existing
    $srcdir/ tree` noise on repeat runs. Failure artifacts retained.
  * release: 5.0.1 → 5.0.2.

v5.0.1 - 2026-05-09
-------------------

  * style: trim verbose comment at L210 (`_RY_BOOT_TAINTED`
    explanation 250→167 chars); technical signal preserved.
  * style: trim verbose comment at L2068 (umask 0077 rationale
    235→158 chars); technical signal preserved.
  * release: 5.0 → 5.0.1.

v5.0 - 2026-05-09
-----------------

  * release: 4.6.20 → 5.0; stable milestone, no functional changes.


----

Pre-v5.0 history (v4.5.x, v4.6.x development iterations) archived to
`ChangeLog-4.x` upstream. v5.0 is the stable milestone — no functional
changes from v4.6.20.
