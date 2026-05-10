ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.

v5.0.18 - 2026-05-10
--------------------

  * cleanup: `_do_cleanup` /tmp sweep — replaced broad
    `-name 'ry-*'` glob with explicit allowlist of six mktemp
    template prefixes (`ry-sudo-err.*`, `ry-run.*`,
    `ry-val-unit.*`, `ry-ka-err.*`, `ry-sudo-l-err.*`,
    `ry-argparse-err.*`). Prevents collateral deletion of
    unrelated user-owned `/tmp/ry-*` files (including
    `ry-install.fish` if invoked from /tmp).
  * verify-static: `_verify_static_checksum` — branch on
    `_installed_bytes` exit code (0/1/2) instead of
    `test -z "$actual"`. Decouples "could not read" from
    "file exists but empty"; mirrors `_check_phase_files`
    rc-branching pattern.
  * runtime: `_vrk_module_state` blacklist iteration — derive
    module list from `module_blacklist=` parse of
    `KERNEL_PARAMS` instead of hardcoded `for mod in pcspkr`.
    Tracks profile drift automatically.
  * runtime: `_vrkg_vram` numeric guard — shape-validate
    `_vram_bytes` with regex before `test -gt` instead of
    relying on test's rc=2-on-non-numeric inversion.
  * sudo: `_ip_probe_sudo_policy` — removed no-op `!PASSWD\b`
    alternative from restrictive-tag regex (not valid
    sudoers syntax; matched nothing).
  * preflight: added GNU grep probe (`grep -m1`) to
    GNU-coreutils preflight chain alongside existing
    sort/stat/find/df/timeout checks. `_pbs_entry_has_valid_kernel`
    relies on `grep -m1`.
  * help: exit-code summary split — `1` is now
    `verify-* FAIL or non-critical install warn`,
    `10` is `--check drift`. Removes ambiguity over which
    mode emits which code.
  * cleanup: removed vestigial fish-completions sweep
    (`~/.config/fish/completions/.ry-install.*`); no current
    writer for that path.
  * style: hygiene — quote `$fish_pid` in printf splat at
    `_acquire_lock_fresh`; tightened multi-line comment
    blocks to single line.

v5.0.17 - 2026-05-10
--------------------

  * security: `_chk_file` — explicit `sudo -n test -L` reject
    for `/boot/*` paths before the `-f` probe. `test -f`
    follows symlinks; rejecting symlinks first is
    defense-in-depth against planted-link smuggle vectors
    (low-risk on vfat ESPs, residual on ext4 XBOOTLDR
    partitions). Existing `_pbs_entry_has_valid_kernel`
    realpath+boundary guard already covered loader-entry
    `linux=` paths; this closes the gap for the simpler
    presence-check sites (`_vsb_loader`, `_vsb_cmdline`,
    `_vsb_mkinitcpio`).
  * style: pre-argparse `-h/--help` and `-v/--version`
    fast-path documented inline. Intentional CLI convention:
    help takes precedence over unknown-positional errors;
    skips preflight overhead for trivial queries.
  * style: `_ry_exit` log-dir rmdir cascade annotated as
    race-safe (rmdir bails silently on ENOTEMPTY).
  * style: top-level mode-rename block annotated — log-rename
    failure is non-fatal, old preflight-named path retained
    and reported via final stderr "[i] Log file:" message.

v5.0.16 - 2026-05-10
--------------------

  * generators: `_ry_content_bytes` — preserves the dispatcher's
    exit code (`EXIT_GEN_NOFN`/`NOUUID`/`SYSCTL`) instead of
    collapsing to `rc=1`. Callers (`_check_phase_files`,
    `_verify_static_checksum`, `_ry_install_file`) now branch on
    `$status` rather than `test -z "$expected"`, decoupling
    generator-failure from legitimate empty-content. Future
    zero-byte configs would have been mis-flagged.
  * skip-iwd: `_should_skip_iwd` — glob
    `*/NetworkManager/*nm.conf` replaced with an explicit
    allowlist `$_RY_IWD_GATED_DSTS` containing the two iwd-gated
    destinations. Future NM drop-ins not ending in `nm.conf`
    cannot be inadvertently iwd-gated, and additions are now
    discoverable in one place.
  * preflight: `HOME` post-trim re-validation. Edge case
    `HOME="/"` previously normalized to empty string; subsequent
    `LOG_DIR`/`LOCK_DIR` computation derived from `$HOME` would
    produce surprising paths. Now refuses to proceed with
    `EXIT_PREFLIGHT` if `HOME` is empty or non-dir after trim.
  * mkinitcpio: `_mkinitcpio_hook_exists` — new helper collapses
    the duplicated four-path file existence check that previously
    lived in both `--existence-only` and default branches of
    `_ry_validate_mkinitcpio_hooks`. Single source of truth for
    the `/{usr/lib,etc}/initcpio/{install,hooks}/` path set.
  * install: `_install_rebuild_boot` sets `_RY_BOOT_REBUILD_OK`
    on success; `_install_finalize` gates `_if_write_wipe_marker`
    on this specific flag rather than the generic
    `INSTALL_HAD_ERRORS`. Decouples marker refresh from
    post-boot phase failures unrelated to boot rebuild.
  * verify: `_vsb_sdboot` — added duplicate-key guard before
    quote-count assertion. Multiple `^LINUX_OPTIONS=` lines from a
    manually-edited `sdboot-manage.conf` now warn + skip rather
    than risk mis-extraction.
  * verify: `_grep_kv` — defensive `string escape --style=regex`
    applied to separator (currently `' '` or `'='`, both
    regex-safe). Future separator additions cannot inject regex
    metacharacters.
  * verify: `_check_avail` — disk-space display shows `<1unit`
    instead of `0unit` when nonzero raw bytes round down to zero.
    Eliminates the "0GB available, need 2GB minimum" semantic
    confusion.
  * runtime: `_vrs_nm_perms` — single-index pipestatus check
    annotated as intentional (split0 rc=1 on empty input is a
    valid state here: no `.nmconnection` files = no WiFi
    configured). Contrast with `_enum_boot_entries` where empty
    is an error.
  * logging: `_run` TMPDIR-redact chain split from 5-link
    `and` chain into an explicit `if`-block. Functionally
    identical; eases future edits.
  * logging: `_run_resolve_timeout` — inline trace comment for
    dense `and`/`or` short-circuit chain.
  * style: `_far_awk_rewrite` — description annotated to note
    that `OFS="\t"` applies only to rewritten ext4 entries;
    passthrough lines retain original whitespace (mount(8)
    tolerates both).
  * style: `$_RY_POST_HOOKS` — order-significant first-match-wins
    semantics documented inline.

v5.0.15 - 2026-05-10
--------------------

  * verify: `_vsp_required`, `_vsp_aur`, `_vsp_removed`,
    `_vsp_pacman_conf` — four package-presence checks converted
    from `cmd; and _ok …; or _fail …` chains to explicit
    `if/else`. Prior form let `_ok`/`_warn`'s exit code reach
    the `or` arm (e.g. when `_RY_OUTPUT_BROKEN` short-circuits
    emit), firing both verdicts against the same record. Each
    helper now emits exactly one verdict per record. Mirrors
    the `_vrsv_chk_*` conversion in v5.0.14.
  * verify: `_cg_access_ok` — non-boot read-access branch
    rewritten from `; and _fail …; or _fail …` to explicit
    `if test -f / else`. Same double-emit risk as the `_vsp_*`
    family; harmonised on the same shape.
  * verify: `_unit_state_user` removed. Defined but never
    invoked; user-scope `systemctl --user show` is not part of
    the documented verify-static or verify-runtime contract.
  * content: `_content_…_resolved.conf` — inline comment marks
    `LLMNR`, `DNSOverTLS`, `DNSSEC` as fixed-policy directives
    (intentionally not promoted to `$RESOLVED_*` vars).
    `MulticastDNS` remains the only knob. No output change.
  * content: `_content_…_nm.conf` — inline comment marks
    `wifi.iwd.autoconnect=false` as an architectural pairing
    with `wifi.backend=iwd` (NM owns autoconnect; iwd does
    not). No output change.
  * docs: README license badge link removed. The deliverable
    archive ships source + README + CHANGELOG only; LICENSE
    lives upstream. Badge now renders without a broken
    in-archive href. License section text de-linked to match.

v5.0.14 - 2026-05-10
--------------------

  * verify: `_vrsv_chk_cpupower`, `_vrsv_chk_resolved`,
    `_vrsv_chk_nm_dispatcher`, `_vrsv_chk_fstrim` — five
    `cmd; and _ok …; or _fail …` chains converted to explicit
    `if/else`. Prior form let `_ok`'s exit code reach the `or`
    arm (e.g. when `_RY_OUTPUT_BROKEN` short-circuits emit),
    firing both verdicts against the same record. Each helper
    now emits exactly one verdict per record.
  * verify: `_idf_match_dst` — `; or test …; and echo|return`
    chain in the SYSTEM/SERVICE and USER scope loops rewritten
    as explicit `if/end`. Brittle precedence with the trailing
    `; and echo "true|true"; and return 0` removed; control flow
    now reads in one pass.
  * check: `_ry_do_check` — `$_checked -eq 0` skip-cascade returns
    `EXIT_PREFLIGHT` (was `EXIT_DRIFT`). Empty checked-set is a
    prerequisite failure (every dst skipped via
    `_should_skip_iwd`), not drift. Restores the documented
    `--check` exit semantics. JSONL marker also re-tagged
    `CHECK_PREFLIGHT`.
  * cli: fish-version guard at top-level rewritten from chained
    `; or begin; …; end; and echo; and _ry_exit` to explicit
    `if test … else if begin … end; …; end`. Same semantics
    (≥ 3.6 required); readable in one pass.
  * cli: top-level root probe uses cached `$_MY_UID` instead of
    forking `id -u`. `_MY_UID` is cached at script init (line
    35); reuse parallels existing convention and saves one fork.
  * sudo: `_RY_LOG_OWNER_PID` switches from `set -gx` to `set -g`.
    Internal-only variable, no child process consumes it; removes
    a harmless env-leak into `pacman`, `mkinitcpio`, `paru`,
    `sdboot-manage`, etc.
  * sudo keepalive: embedded `fish -c` child gets `; or break`
    after `command sleep $argv[3]`. If `sleep` is signalled or
    the interval is unparseable (defended upstream by
    `_ir_validate_timing`), the child exits cleanly rather than
    busy-looping `sudo -n -v` at full speed. Defense-in-depth.
  * sudo keepalive: dead `_RY_NO_LOG=1` env var dropped from the
    `fish --no-config -c` invocation. No parent functions are
    loaded in the child; no `_log` ever runs there. The var was
    inert.
  * sudo: `_ip_probe_sudo_policy` Runas-spec regex broadens from
    `(ALL|root)` to also accept `(%groupname)` (e.g. `%wheel`).
    Sudoers configs using `(%wheel) NOPASSWD: ALL` no longer
    false-negative on the policy probe. Pre-screen only —
    actual sudo capability is already verified by `sudo -n -v`
    upstream in `_ensure_sudo_cached`.
  * verify: `_vrk_module_state` amdgpu hex compare validates
    `^0x[0-9a-fA-F]+$` before `printf '%d'`. Prior fallback
    path (`echo` original on `printf` failure) would silently
    compare hex-string vs decimal-string on a malformed sysfs
    value.
  * style: 2-line comment block above `_broker` declaration in
    `_reclaim_stale_lock` consolidated into a single line. Three
    truncated mid-sentence comment fragments in
    `_kill_sudo_keepalive` kill-loop removed; one consolidated
    explanatory comment retained above the `pkill -P` line.
  * style: blank line inserted after section banners
    `# Summary counters for JSONL footer` and `# SIGNAL &
    TEARDOWN HANDLERS …` for parity with the 12 other banner
    sections (all blank-before / blank-after).
  * style: `# === SCRIPT GUARDS & EXIT CODES ===` banner added
    above the top constants block. Parallels the existing
    `# === GTR9_PRO BUILT-IN DEFAULTS ===` banner above the
    per-profile defaults.
  * release: 5.0.13 → 5.0.14.

v5.0.13 - 2026-05-10
--------------------

  * lock: `_reclaim_stale_lock` PID-liveness probe extracted to a
    dedicated helper `_rcl_probe_owner_pid` (argument-named, rc=0
    stale / rc=1 live ry-install). Brings `_reclaim_stale_lock`
    under the 50-line function-size ceiling; the /proc/<pid>/comm
    + cmdline defense-in-depth path is now independently testable.
  * verify: `_vsb_sdboot` LINUX_OPTIONS extraction gains a pre-parse
    quote-count assertion — exactly two `"` chars required before the
    PCRE backref runs. Manual edits to `/etc/sdboot-manage.conf` with
    embedded `\"` no longer mis-extract; `_warn` + skip instead.
    Lint:ignore comment refreshed to reference the new guard.
  * log: `_json_str` fast-path no longer relies on fish's
    left-to-right `; and printf …; and return` chain. Rewritten as
    an explicit `if not match; printf | string collect; return
    $status; end` so a non-zero `string collect` exit propagates
    correctly rather than falling through to the slow-path escapes.
  * sudo keepalive: `_start_sudo_keepalive` embedded `fish -c` child
    block gains a `# lint:ignore (embedded fish -c child …)` tag for
    consistency with the four `lint:ignore` tags already on the
    `flock(1)` `/bin/sh -c` block in `_reclaim_stale_lock`.
    Documents the boundary so future refactors do not fold it into
    parent-scope helpers.
  * style: 3 missing blank lines inserted before single-line section
    comments — before `# internal-only sentinels` (after
    `set -g EXIT_DRIFT`), before `# NO_COLOR: presence-alone …`
    (after `set -g QUIET true`), and before `# _RY_BOOT_TAINTED: …`
    (after `set -g INSTALL_HAD_ERRORS false`). Brings section-banner
    spacing to fully consistent.
  * docs: README Quick Start callouts (`> [!NOTE]`, `> [!IMPORTANT]`),
    Scope paragraphs, blockquote intro, and Hardware Reference prose
    rewrapped to ≤120-char lines for diff-friendliness. Table rows
    remain on single lines (GFM table constraint). Rendered output
    unchanged.
  * docs: CHANGELOG v5.0.12 entry — replace stale absolute line-number
    references (`L4669/L4730/L594/L979/L4646/L4666`) with
    function-name / section-banner references that survive future
    edits. v5.0.1 entry receives the same treatment (`L210/L2068`
    → symbol-anchored).
  * release: 5.0.12 → 5.0.13.

v5.0.12 - 2026-05-10
--------------------

  * cli: early-arg `-h`/`--help` and `-v`/`--version` now honour
    `_RY_INSTALL_SOURCED` before `exit 0`. Prior code would kill the
    user's interactive shell when ry-install was sourced with `-h`
    (`source ry-install.fish -h`). Both branches now: `test
    "$_RY_INSTALL_SOURCED" = true; and return 0; exit 0`. Mirrors the
    pattern used by `_ry_exit` / `_pre_dispatch_exit` elsewhere.
  * cli: `_ry_show_help` in early-arg loop now writes to stderr
    (`>&2`), matching the other invocation sites in the argparse
    error path and the positional-rejection path. Diagnostic-style
    output stays out of stdout pipelines.
  * perms: `_chk_perms` boolean rewritten — explicit `_bad` flag
    instead of fish's left-to-right `; or test …; and _fail …; and
    return 1` chain. Prior chain silently passed when ONLY perms
    differed (owner matched): `test perms != expected; or test owner
    != expected; and _fail` evaluated as `((test or test) and _fail)`,
    so a perms-only mismatch left the chain status at 0 and `_fail`
    never ran. New form runs each comparison once, ORs the failure
    bits, then emits a single `_fail` covering both fields. Adds a
    `<2 parts` malformed-stat guard so `_parts[2]` is never read empty.
  * fstab: `_install_fstab_opts` and `_far_awk_rewrite` fall through
    to `sudo -n awk` when `/etc/fstab` is not user-readable (mode 0640
    or stricter). Prior `not test -r /etc/fstab → _fail` blocked
    hardened-sudoers configs from rewriting. Hard fail only if even
    `sudo -n test -r` reports unreadable. `_vre_fstab` mirrors the
    same fall-through for verify-runtime.
  * fstab: `_install_fstab_opts` declares `set -l ext4_lines` at
    function scope before the readable/sudo branches; prior `set -l`
    inside each `if/else` arm was block-scoped and would not persist
    past `end`.
  * lock: `_reclaim_stale_lock` now flock-targets a dedicated
    `~/ry-install/.lock-broker` file rather than the shared
    `~/ry-install` parent directory. Defence-in-depth against
    hypothetical future tools also locking the parent path.
  * mkinitcpio rollback: snapshot moves from in-memory fish variable
    (`_RY_MKI_BACKUP`) to a tracked tmpfile path (`_RY_MKI_BACKUP_FILE`)
    under `/etc/.ry-install.mki-backup.XXXXXX`. Eliminates two
    issues: (a) fish command substitution strips trailing whitespace
    before `string collect` runs, so a config file with a final
    newline would round-trip to one without; (b) config content held
    in a fish global persisted across the entire run. Restore path
    uses `sudo -n cp` from the snapshot to a fresh atomic-write
    tmpfile, then `chmod`/`chown --reference` + `mv -T` as before.
    Success path removes the snapshot via `_rm_tmp`; signal/exit
    cleanup pipeline already tracks it.
  * verify: `_vrs_installed_file_perms` user-file owner check drops
    group-name comparison — only owner-name is enforced. Prior
    `(id -un):(id -gn)` would spuriously fail for files created
    under a non-default umask, `chgrp`-touched, or under an
    sgid-bit parent dir. Group is read live from the file's stat
    and folded into the expected-owner string so `_chk_perms`
    output still shows it; only the comparison logic ignores
    group-drift.
  * pkgs: `_csp_filter_rdeps` pactree parser strips optional
    `pkg=1.2.3` version suffix per line before comparison. Prior
    `string match -v -- "$pkg"` would fail to exclude the seed
    package when pactree emitted versioned output, causing the
    cascade list to include the seed pkg twice.
  * boot perf: `_vrs_boot_perf` boot-time integer conversion uses
    `math "round($total_sec)"` instead of `LC_ALL=C printf "%.0f"`.
    Removes libc-dependent rounding-mode behaviour (banker vs
    half-up); `math` round is deterministic.
  * generators: `_awf_render_to_tmp` `switch` cases use the symbolic
    `$EXIT_GEN_NOFN` / `$EXIT_GEN_NOUUID` / `$EXIT_GEN_SYSCTL`
    constants instead of literal `11/12/13`. Future renumbering
    won't silently mis-route error classes.
  * verify: `_verify_static_services` scaling_governor anti-regression
    grep is anchored with `(^|[^#])scaling_governor` to skip
    comments. Prior bare grep would false-positive if a future
    `# scaling_governor` comment was added.
  * post-hooks: `_RY_POST_HOOKS` reformatted with line
    continuations. `/etc/mkinitcpio*` and `/etc/sdboot-manage*`
    globs split into anchored
    `/etc/mkinitcpio.conf` + `/etc/mkinitcpio.d/*` and
    `/etc/sdboot-manage.conf` + `/etc/sdboot-manage.d/*` pairs
    (each tag still routes to `boot`). New table is 14 lines,
    one entry per line — diff-friendly.
  * config: `INITRD_WARN_MB=100` extracted as named constant
    (was hard-coded in `_boot_initrd_size_scan`); parallels
    `BOOT_SPACE_*` / `ROOT_AVAIL_*`.
  * style: file-creation arg quoting — `_atomic_write_file "$dst"
    "$perms" "$use_sudo"` (was unquoted `$perms` / `$use_sudo`).
    Cosmetic, no behaviour change (neither var contains whitespace).
  * style: raw `printf '\n' >&2` in `_install_preflight` replaced
    with `_echo`, honouring QUIET.
  * style: 4 navigation-anchor section comments added —
    `# SIGNAL & TEARDOWN HANDLERS`, `# DISPATCH TABLE`,
    `# PRE-DISPATCH TEARDOWN HELPERS`, and
    `# TOP-LEVEL ARGPARSE + MODE DISPATCH`. Mirrors the v5.0.9
    navigation anchor pass.
  * style: cpupower-epp service comment expanded — "succeeds on
    partial EPP write; failed cores logged to journal via stderr"
    documents the `2>/dev/null || echo … >&2` pattern in the
    embedded ExecStart.
  * counts: README managed-file count drift resync — "15 embedded
    configs" → "12 embedded configs" in README:9; identical fix to
    the `_install_system_files` description ("Deploy all 15
    embedded config files" → "Deploy all 12"). Both were missed
    in the v5.0.10 / v5.0.11 resync passes.
  * docs: README Prerequisites table gains a `Systemd ≥ 250
    (advisory)` row, documenting `_ry_check_deps` warn-only check
    against systemctl version. README Exit Codes table
    code-`1` row clarified to include "old-kernel preflight warn".
    Help text `EXIT CODES` line mirrors.
  * docs: README Data Directory table gains
    `~/ry-install/.lock-broker` row tracking the new flock
    target. mkinitcpio rollback row updated to describe the
    tmpfile-based snapshot.
  * release: 5.0.11 → 5.0.12.

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

  * style: trim verbose comment above `set -g _RY_BOOT_TAINTED`
    (`_RY_BOOT_TAINTED` explanation 250→167 chars); technical
    signal preserved.
  * style: trim verbose comment above the user-scope `mkdir`
    `umask 0077` block in `_ry_install_file` (235→158 chars);
    technical signal preserved.
  * release: 5.0 → 5.0.1.

v5.0 - 2026-05-09
-----------------

  * release: 4.6.20 → 5.0; stable milestone, no functional changes.


----

Pre-v5.0 history (v4.5.x, v4.6.x development iterations) archived to
`ChangeLog-4.x` upstream. v5.0 is the stable milestone — no functional
changes from v4.6.20.
