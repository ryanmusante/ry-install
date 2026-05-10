ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

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
