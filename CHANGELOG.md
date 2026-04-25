ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first,
entries grouped under a dated heading, each bullet names the
subsystem or function before the change description.


v4.3.7 - 2026-04-25
-------------------

  Audit-driven hardening release. Five low-severity findings
  closed: profile validator metachar gap, keepalive comment vs
  code mismatch, dead rc tracking in cpupower-epp ExecStart,
  network-failure message accuracy, and twin redundant guards
  on post-rebuild boot-entry counts. No execution-flow changes
  beyond the cpupower-epp content hash, which will redeploy on
  next install and re-baseline verify-static for that file.

[security]

  * _validate_profile element regex: extend forbidden-char class
    from [[:space:]"()] to [[:space:]"$'\`()\\;&|<>] (whitespace,
    double-quote, dollar, apostrophe, backtick, parens, backslash,
    semicolon, ampersand, pipe, less, greater). Profile elements
    in KERNEL_PARAMS / MKINITCPIO_MODULES / MKINITCPIO_HOOKS are
    interpolated into /etc/mkinitcpio.conf, which mkinitcpio(8)
    sources as root. The prior class missed bash command-substi-
    tution (backtick), variable-expansion ($), statement separa-
    tors (; & |), redirects (< >), apostrophe, and bare back-
    slash. No privilege escalation in single-user trust model
    (user has full sudo anyway), but defense-in-depth closes the
    gap for shared/repo-pulled profiles. Comment at L893 already
    asserted intent to "reject shell-metachars... embedded into
    config files" — code now matches the intent.

[fix]

  * _content__etc_systemd_system_cpupower-epp.service ExecStart:
    drop dead `rc=0` and `; rc=1` from per-CPU loop. Variable
    was assigned but never observed (literal `exit 0` follows
    unconditionally). Service intentionally succeeds on partial
    EPP write failure; per-CPU errors continue to reach the
    journal via StandardError=journal. Dropping the assignment
    removes a maintenance hazard (future reader assuming `rc`
    participates in exit code) without changing semantics. This
    is the only content-hash change in v4.3.7; verify-static
    will report drift on /etc/systemd/system/cpupower-epp.service
    until the next install redeploys the unit.

  * _verify_static_boot + _install_rebuild_boot: drop redundant
    `test -n "$entry_count"` and `string match -qr '^\d+$'`
    guards on the `count(1)` result. `count` always emits a
    non-negative integer string, so both prefix guards are
    unreachable-false. Single `test "$entry_count" -gt 0`
    suffices. Twin sites updated together for consistency.

[doc]

  * _install_preflight keepalive comment: replace misleading
    "transient PAM failures self-heal next cycle" claim with
    accurate "loop bails on first sudo -n -v failure (fail-fast)"
    description. The `or break` after `command sudo -n -v` exits
    the loop on any failure; there is no retry path. Parent
    surfaces death via _check_sudo_keepalive at each privileged
    phase. Comment now matches code.

  * _ry_check_network: when curl https://archlinux.org fails but
    ping 1.1.1.1 succeeds, message reworded from "HTTPS down
    (raw IP reachable; check /etc/resolv.conf)" to "HTTPS or DNS
    unreachable (raw-IP ICMP works; check /etc/resolv.conf or
    443 egress)". Both DNS-broken and 443-egress-blocked failure
    modes produce identical signals from this evidence; prior
    wording presumed only DNS. Functional behavior unchanged
    (both branches return 1).

[version]

  * VERSION: 4.3.6 -> 4.3.7

[release]

  * banner header: 4.3.7 (2026-04-25)




v4.3.6 - 2026-04-25
-------------------

  Hotfix. Post-install hook dispatcher restored. Single-file
  install path returns rc=0 again with its post-action actually
  invoked.

[fix]

  * _ry_install_file post-hook dispatcher: dropped redundant
    `post_` prefix from all 14 entries in the _post_hooks glob
    table. Dispatcher at L4742/L4747 is `_post_$_h`, so a value
    of `post_boot` resolved to `_post_post_boot` — a name that
    matches no defined function. Every single-file install of a
    managed config since v4.3.2 (when the table was introduced)
    has emitted `Internal: post-hook _post_post_X not defined`
    via the L4741 existence guard and returned rc=1, skipping
    its post-action: mkinitcpio rebuild, sdboot-manage refresh,
    daemon-reload + service enable, udev reload-rules + trigger
    + settle, NetworkManager restart, sysctl reload, resolved
    restart, coredump.socket reload, drirc/envd session-restart
    notice, and logind reboot notice. Now consistent with the
    `_ry_profile_$name` and `_content_$key` dispatchers, which
    have always used bare keys with the prefix in the dispatch
    line. Bulk install path (_ry_do_install) was never
    affected — it calls _ry_install_file directly without the
    glob table.

  * L4741 existence guard retained as defense-in-depth against
    future malformed table entries (its original v4.3.2 intent).

[version]

  * VERSION: 4.3.5 -> 4.3.6

[release]

  * banner header: 4.3.6 (2026-04-25)




  Hygiene release. Completes the comment-rendering fix line that
  began in v4.3.3. No runtime behavior change; fish parser was
  unaffected throughout. External contracts preserved.

[hygiene]

  * comments: 30 paired-quote spans inside fish line-comments
    rewritten to bare prose. v4.3.3 replaced 19 paired backticks
    with single quotes to dodge the fish-tmbundle
    string.interpolated.backtick.fish trap, but the same grammar
    opens string.quoted.single scope on paired apostrophes inside
    comment.line.fish, reproducing the identical
    highlighting-poison cascade with a different delimiter. v4.3.5
    strips both single- and double-quote pairs from every comment;
    inline references like 'fish -c', 'set -l', "rebind", and
    "Unknown function" are now bare. Help-text echo string at
    L1681 retains its single backtick pair (string scope sandboxes
    it correctly).

  * comments: one five-line @@AUDIT@@ rationale block in
    _content__etc_systemd_system_cpupower-epp.service collapsed to
    a single line.

[version]

  * version: 4.3.4 -> 4.3.5. Header date stamp resynced.


v4.3.4 - 2026-04-25
-------------------

  Install-affecting fix exposed during a v4.3.3 follow-up cleanup,
  plus apostrophe and double-quote analogs of the v4.3.3
  paired-backtick comment sweep.

[fixes]

  * _content__etc_systemd_system_cpupower-epp.service: fix
    premature termination of the multi-line single-quoted printf
    body. Unescaped apostrophe pair around the OR-fallback token
    in the L1211 @@AUDIT@@ v4.3.2 comment closed the printf string
    early; printf rc=0, OR short-circuited, error never surfaced.
    v4.3.0 through v4.3.3 installed a 12-line cpupower-epp.service
    missing StandardError, ExecStart, and the [Install] section;
    systemctl start would have failed with Unit-has-no-ExecStart
    but the install run never observed it. Generator rewritten as
    per-line printf args. Hosts that ran v4.3.0-v4.3.3 should
    reinstall or verify
    /etc/systemd/system/cpupower-epp.service is 17 lines and
    contains ExecStart= and [Install].

[hygiene]

  * comments: 13 contractions and several stray apostrophe / quote
    sites inside fish line-comments rewritten. Apostrophe analog
    of the v4.3.3 paired-backtick fix. Note: superseded by the
    exhaustive v4.3.5 sweep.


v4.3.3 - 2026-04-25
-------------------

  Maintenance release. One install-blocker fix, three robustness
  guards, one defensive arity check, and a project-wide rewrite
  of paired backticks in fish comments that confused the
  fish-tmbundle grammar into entering string scope mid-comment.

[fixes]

  * _ry_validate_configs: drop trailing dash arg from fish
    --no-execute invocation. Fish does not special-case dash as
    stdin (GH #1039 open since 2013); previous form returned
    rc=127, causing every install to abort at preflight before
    the package phase.

[robustness]

  * _install_preflight: command prefix on kill/sudo/sleep inside
    the sudo keepalive fish -c subshell.
  * _chk_perms / _verify_runtime_session: stat-fail guards.
  * _as: arity guard; empty-argv calls now return rc=2 and log BUG.

[hygiene]

  * comments: 19 paired backticks in fish comments replaced with
    single quotes. Fish runtime parser was unaffected; rendering
    fix only. Note: single-quote replacement reintroduced the same
    class of bug under the apostrophe rule and was finished off in
    v4.3.5.


v4.3.2 - 2026-04-25
-------------------

  Audit follow-up. Ten findings from the v4.3.1 line-by-line audit
  addressed; changes marked @@AUDIT@@ v4.3.2 inline. Highlights:
  _cleanup_on_exit consults $_RY_INSTALL_LAST_EXIT for early-fail
  footer; sudo-probe stderr redirects unified; _post_$hook
  existence guard before dispatch; cpupower-epp drops |logger
  fallback in favor of StandardError=journal; _acquire_lock
  requires both flock(1) and /bin/sh; _ry_do_check uses whole-word
  regex for KERNEL_PARAMS in /proc/cmdline; _log drops redundant
  set -l on event/data sanitize lines.


v4.3.1 - 2026-04-25
-------------------

  Audit-driven cleanup. Eighteen v4.3.0 findings addressed plus a
  simplification pass adding four verifier helpers (_chk_eq,
  _chk_sysfs_eq, _chk_perms, _chk_present) and trimming inline
  rationale. _atomic_write_file untracks tmpfile after mv so the
  cleanup loop stops stat()-ing dead paths. _post_boot END writes
  moved to _ry_do_install_file via single-exit refactor. _grep_kv
  escapes $key via string escape --style=regex before
  interpolation. Output byte-identical for verify-static and
  verify-runtime modes.


v4.3.0 - 2026-04-25
-------------------

  Decomposition release. Four large-function splits scoped in
  v4.2.0 completed: _install_configure_services 155L->13L+3
  helpers; _ry_verify_static 427L->31L+7 section helpers;
  _ry_verify_runtime 818L->30L+4 section helpers;
  _ry_profile_gtr9_pro 192L->14L+8 inline helpers. Output
  byte-identical to v4.2.1 on the gtr9_pro profile.


v4.2.1 - 2026-04-25
-------------------

  Targeted hardening. _json_str escape pass extended to {\\, ", \n,
  \r, \t} plus C0/DEL strip. _ry_check_kernel_version soft-warns
  for [6.14, 6.18.4); 6.18.4 documented as gfx1151 stability floor.
  _validate_profile rejects empty-string scalar globals for 10
  required globals. _should_skip_iwd glob tightened to
  */NetworkManager/*nm.conf. _is_wifi_active_route detects
  tun/tap/wg/ppp/gre/sit/ip6tnl/ipip default-route ifaces.


v4.2.0 - 2026-04-23
-------------------

  Profile system release. Profile loader extracted from script
  body; gtr9_pro profile data isolated from install logic.
  Manifest format introduced for verify-static checksum
  comparisons. New flags: --verify-static, --verify-runtime,
  --check (silent idempotency probe).


v4.1.x - 2026-04-19 to 2026-04-22 (rollup)
------------------------------------------

  Fifteen patch releases. Highlights: JSONL log schema stabilized;
  _run timeout enforcement via timeout(1); progress bar via
  DECSTBM scroll region; lock file with flock(1); signal handlers
  for SIGINT/TERM/HUP/PIPE; sudo keepalive subshell; atomic file
  writes via mktemp + sudo mv with --reference. Several
  cpupower-epp.service iterations leading to the v4.3.4-discovered
  printf-truncation bug.


v4.0.x - 2026-04-18 to 2026-04-19
---------------------------------

  Initial fish rewrite from the v3.x bash original. Single-file
  architecture with embedded config generators (no /usr/share data
  files). Manifest-driven install loop replacing per-file shell
  blocks. argparse-based CLI with --help, --version, --verbose,
  --install-file flags.


v3.51.x - 2026-04-13 to 2026-04-17
----------------------------------

  Late-bash hardening. Manifest format finalized to count+sha256
  separated by space. Embedded-content hashing centralized.


v3.50.x and earlier - through 2026-04-13
----------------------------------------

  Bash-era development. Per-file shell blocks; ad-hoc verification;
  no manifest. Superseded by the v4.0 fish rewrite.
