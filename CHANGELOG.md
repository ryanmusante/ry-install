ry-install ChangeLog
====================

v7.4.37 - v7.4.38 - 2026-05-22
------------------------------

Bootstrap clarity refactor. L107 `_ry_tmpprobe_dir` initialiser
moved from nested `(set -q ... ; and ... ; or printf /tmp)`
command-substitution chain to a flat default-then-guard form
(`set -l _ry_tmpprobe_dir /tmp` followed by an `if`-update only
when `TMPDIR` is set, non-empty, and an existing directory).
Argparse-tail `QUIET` toggle restructured from a nested
`begin ... end` boolean group inside an `and` chain to flat
`if/else if`. Verbose-mode semantics unchanged: `--check` stays
QUIET (silent-probe contract), `verify-*` and `--install-file`
always verbose, install requires `-V`. Eight trailing inline
comments (L748, L935, L1166, L1425, L1449, L4012, L4169, L4229)
moved to dedicated lines above the annotated statement; no
comment text edits, no semantic change. 4491 → 4500 LOC.

v7.4.36 - v7.4.37 - 2026-05-21
------------------------------

`_vrsv_chk_nm_dispatcher` gains a not-found short-circuit. When
`NetworkManager-dispatcher.service` is uninstalled (`rec[1]=not-found`,
`rec[3]` empty), the helper emits `_warn "NetworkManager-dispatcher:
not installed"` and returns 0 instead of falling into the
unconditional `_fail` branch on `rec[3] != enabled && != static`.
Aligns with sibling helpers `_vrsv_chk_active_enabled`,
`_vrsv_chk_resolved`, and `_vrsv_chk_cpupower_governor`, all of
which already short-circuit on `not-found`. `--verify-runtime` no
longer emits a false-positive `VERIFY_FAIL` on systems that do not
ship NM dispatcher scripts; verdict on systems with NM-dispatcher
installed is unchanged. 4490 → 4491 LOC. fish --no-execute syntax
PASS; JSONL header version field reports 7.4.37.

v7.4.35 - v7.4.36 - 2026-05-22
------------------------------

Three stray `\;` tokens removed from inline `for` lists (`_vsb_loader`
loader.conf, `_verify_static_system` resolved.conf.d, `_ry_check_deps`
optional-tools probe). fish parses `\;` as a literal list element, not
a separator; `_chk_grep` was searching for a literal ";" in config
files, flipping `--verify-static` from PASS to FAIL on correct installs.
Origin: the v7.4.33 → v7.4.34 LOC-collapse pass turned visual separators
into list members. All three sites now use whitespace between entries.
`RY_INITRD_WARN_MB` validation no longer silently falls back: invalid
values queue in `_RY_DEFERRED_WARNS` and surface via `_warn`, mirroring
the `RY_RUN_TIMEOUT` pattern. Malformed sysctl entries now reach the
user through the `EXIT_GEN_SYSCTL` dispatcher branch (formerly JSONL
only). Defensive `MATRIX_TRUNCATED` JSONL diagnostic added to
`_rdi_matrix_rows` for future label/locale-driven column drift.
4476 → 4490 LOC.

v7.4.34 - v7.4.35 - 2026-05-22
------------------------------

Header byline version-sync to `$VERSION`. Two pre-existing >250-char
lines split to continuation form (MASK service list, sudo-cache warning
printf). Bootstrap source-protection sentinel drops dead `2>/dev/null`
on `status stack-trace` (the builtin does not write to stderr).
4468 → 4476 LOC; semantically identical.

v7.4.33 - v7.4.34 - 2026-05-21
------------------------------

LOC reduction 5113 → 4468 via ~200 multi-line blocks collapsed to
single-line `; and` chained form (if-end bodies, for-loops, printf
continuations, multi-line `set -g` data tables). Function count
unchanged (255 multi-line + 9 single-line); largest function still
`_ry_show_help` at 39 LOC. Collapse skipped on blocks carrying
trailing `#` comments (joining via `;` would let `#` consume the
trailing `; end`).

v7.4.32 - v7.4.33 - 2026-05-21
------------------------------

CHANGELOG consolidation: per-patch entries collapsed to range entries,
closing chain gaps. README version badge and run-summary example matrix
bumped. No functional change; idempotent re-deploys remain no-ops.

v7.4.31 - v7.4.32 - 2026-05-21
------------------------------

Source-style cleanup. Four single-line content generators
(`loader.conf`, resolved.conf drop-in, NetworkManager drop-in,
`cpupower-service.conf`) expanded from semicolon-joined single-line
form to multi-line `printf '%s\n' \` style used elsewhere. Output
byte-identical; idempotent re-deploys remain no-ops.

v7.4.22 - v7.4.31 - 2026-05-21
------------------------------

README cleanup pass. Six Phase blocks restructured to uniform "N
sequential operations" intro plus ordered step list (Phase 3 uses
"Four-step sequence per file"). Seven `<summary>` blocks normalised
to "count + unit" suffix. Inline boot-critical paths restructured
to bullet lists in `[!IMPORTANT]` callout and Phase 3. Style sync
(`Fish` → `fish`, `Pacman` → `pacman`); en-dash on duration ranges.

v7.4.5 - v7.4.22 - 2026-05-20
-----------------------------

Refactor cycle. LOC 5204 → 5113. Inline comments collapsed to
single-line "why" form; adjacent `set -l`/`set -g` runs collapsed
to semicolon-chained one-liners. Function extractions to keep ≤50
LOC: `_install_preflight` → `_ip_record_regdom`;
`_install_aur_packages` → `_iap_per_pkg_retry` + `_iap_record_result`;
`_install_rebuild_boot` → `_irb_taint_gate`; `_rdi_run_phases` →
`_rrp_optional_indexer`. `_verify_static_services` 9-way is-enabled
chain collapsed to `contains`. Bootstrap: non-existent TMPDIR
overrides to `/tmp` with stderr warning; `_tmp_dir` gains
`test -d "$TMPDIR"` defence-in-depth. AUR `mt76-mt7925-dkms`
post-build modinfo failure now WARN (not silent PASS).
`BOOT_TAINTED_OVERRIDE` JSONL + stderr emitted when
`RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint gate.
`_rdi_render_matrix` split into header/rows/footer (each ≤50 LOC).
Kernel <6.14 hard floor now records matrix FAIL (was WARN).
Run-summary matrix introduced: install completion prints box-drawn
Unicode matrix to stderr (CHECK/RESULT/EVIDENCE + totals + verdict);
`RY_INSTALL_NO_MATRIX=1` opts out. `_phase_record` strips embedded
newlines and U+2502 from arguments. Strict `NOPASSWD: ALL`
preflight gate dropped; replaced with `_ry_sudo_cache_banner`
install-mode warning.

v7.4.0 - v7.4.5 - 2026-05-20
----------------------------

Preflight + lock + sudo cache redesign. Fish-version preflight: flat
sentinel replaces nested `begin ... end`. Preflight rejects `timeout(1)`
lacking `--foreground` / `--kill-after` (busybox, uutils).
`_acquire_lock` closes PID-recycle race via `/proc/$pid/comm`.
`_acquire_lock_fresh` runs `umask 0077` around mkdir.
`_ensure_sudo_cached` gains `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.
`_csp_filter_rdeps` checks pipestatus across all 4 pipe stages.
`_dc_kill_children` widens SIGKILL grace to 0.5s. `_cleanup_tmpfiles`
inserts two-step `sudo -n true` gate before `sudo find`.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19
------------------------------------------

`_RY_LOUD_ERR`: critical preflight failures reach stderr in default
QUIET install mode; `--check` stays silent. `_ir_resolve_root_uuid`
gains 4-way mode dispatch and `_reason` distinguishes "findmnt failed"
from "invalid UUID shape". `_RY_LOG_SUPPRESS_CREATE` eliminates
orphan `preflight-*.jsonl` on argparse-error paths. `_cse_batch_enable`
accept-list adds linked, linked-runtime, indirect, generated, transient.
`_chk_perms` strips leading setuid/setgid/sticky digit.
`_run_emit_stream` captures head + tail (100 each); build-error tails
preserved. `_boot_initrd_size_scan` switches to byte comparison
(removes off-by-1MB silent pass). `_verify_runtime_kparams` pre-extracts
preempt/BAR/TSC markers from full dmesg before 5000-line cap.
Short-circuit chain collapse (5177 → 4842 LOC). `_ry_check_disk_space`
labels switch to GiB/MiB. `_vrkg_rebar_sam` lspci regex broadens.
`_ry_check_deps` adds systemd <250 hard-fail preflight gate.
`_run` tmpdir-alloc sentinel promoted to `EXIT_RUN_TMPFAIL`. Log
filename → `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17
------------------------------------------

NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
MASK gains `avahi-daemon.service` and `.socket` (10 → 12 units).
`PKGS_ADD` gains `realtime-privileges`, `cpupower`; `PKGS_DEL` gains
`bolt`. New `_ry_check_wireless_regdom`, `_vrk_audio_state`,
`_ry_apply_wireless_regdom` (driven by `RY_INSTALL_WIRELESS_REGDOM`).
`RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`.
`_vsb_mkinitcpio` amdgpu probe tightened `*amdgpu*` → `\bamdgpu\b`.
`_ry_check_deps` adds GNU-coreutils `df` probe.
`HandleSecureAttentionKey` gate <256 → <257.
`/etc/default/cpupower-service.conf` added; `/etc/drirc` dropped.
`_vrk_cpu_state` scaling_governor: powersave → performance.
`_vmh_order_checks` adds `systemd:autodetect` and `autodetect:microcode`
pair rules plus fsck-last invariant. `cpupower-epp.service` dropped;
`SERVICE_DESTINATIONS` empty. `_RY_MANAGED_FILE_COUNT` 13 → 12;
`EXPECTED_SERVICES` 4 → 3. `_vre_fstab` unifies
`noatime`/`lazytime`/`commit=10` under `(^|,)tok(,|$)`.
`_mr_copy_size_verify` adds `cmp -s` after size match.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15
------------------------------------------

Foundational v6.x → v7.0 series. v6.0 → v6.1: 5994 → 4985 LOC.
Drops GNU-tool probes, source-mode scaffolding, ntsync probes,
sudo-keepalive, JSONL progress events, log rotation, parallel-child
PID guard, atomic-write TOCTOU re-stat, boot-wipe gates, LVM
detection. User-bus detection added via `XDG_RUNTIME_DIR/bus` +
`systemctl --user is-system-running`. HOME field-6 captured via
`awk -F:` (GECOS-tolerant). JSONL header written before
`_init_runtime`. `LOCK_DIR` gains `chmod 700`. Emit functions use
`printf` (flag-injection guard). `_run` split into `_run` /
`_run_redact_cmd` / `_run_effective_timeout`; timeout-bypass for
pacman, paru, mkinitcpio, sdboot-manage, paccache. Tmpfile-path
redaction under `$TMPDIR`. `_ip_pacman_invoke` gates `-Syyu` retry
on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`. Per-package AUR retry.
`_atomic_write_file` post-write symlink re-check (TOCTOU).
`_fstab_atomic_replace` `findmnt --verify` hard-fail. User
destinations install `0600`. `--install-file` single-file redeploy
with per-target post-hook dispatch. argparse `--exclusive` mode
group. Atomic `mkdir` + pid-file lock. `_ir_validate_counts`
enforces array-count invariants. `_RY_POST_HOOKS` first-match table
for `--install-file` hooks. `_rvc_dispatch` adds `*/tmpfiles.d/*`
case + `_grep_tmpfiles_entry`. New `/etc/tmpfiles.d/99-cachyos-thp.conf`
managed destination. `_aur_verify_mt7925` asserts both pacman and
modinfo resolve. `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL`.
`_ry_exit` bail path writes JSONL footer. `_verify_static_services`
multi-ExecStart guard. KERNEL_PARAMS metachar regex backslash
escaping tightened.
