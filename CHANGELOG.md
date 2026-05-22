ry-install ChangeLog
====================

v7.4.35 - v7.4.36 - 2026-05-22
------------------------------

Three stray `\;` tokens removed from inline `for` lists. fish parses
`\;` as a literal `;` element of the for-list, not as a separator:
L1741 (_vsb_loader, loader.conf) and L1913 (_verify_static_system,
resolved.conf.d) each caused `_chk_grep` to look for a literal ";"
in the config file, fail, increment VERIFY_FAIL, and flip the
`--verify-static` verdict from PASS to FAIL on a correct
installation. L1350 (_ry_check_deps optional-tools probe) appended
a literal ";" to `_opt_missing`, surfacing as
"Expected tools not found (from base packages): ;" in the _warn
output. Origin: the v7.4.33 → v7.4.34 LOC-collapse pass; the tokens
were visual separators the collapse turned into list elements. All
three sites now use plain whitespace between entries.

RY_INITRD_WARN_MB validation no longer silently falls back. Previous
form (single-line `set -q; and string match; and set`) discarded
invalid values without notice. New form mirrors the L1136
RY_RUN_TIMEOUT pattern: on regex mismatch the message is queued in
`_RY_DEFERRED_WARNS` (necessary because `_warn` and `_log` are not
yet defined at L567), then flushed alongside `_RY_PERM_FIX_NOTICES`
once both functions are live. Valid input behavior unchanged.

Malformed sysctl entries now surface to the user, not just the
JSONL log. `_content__etc_sysctl.d_99-cachyos-sysctl.conf` collects
skipped entries in `_RY_SYSCTL_BAD_ENTRIES`; the EXIT_GEN_SYSCTL
branch of the dispatcher (formerly emitting only
"Content generator assertion failed (output count mismatch): $dst")
now appends the malformed entry list when populated.

Matrix render gains defensive truncation diagnostics. `_rdi_matrix_-
rows` emits `MATRIX_TRUNCATED` to JSONL when a CHECK label or
EVIDENCE string exceeds its column width before `string sub` clips
it. No current `_phase_record` call hits the threshold (longest
label is 33 chars vs the 34-char CHECK column); guard exists for
future labels and locale-driven width drift.

fish --no-execute syntax PASS; --help/--version/--bogus/--check
behaviour unchanged (rc=0/0/2/3); --verify-static verdict on a
correct system transitions rc=1 → rc=0. 4476 → 4490 LOC (+14 from
the four diagnostic additions; semantically narrow). JSONL header
version field reports 7.4.36.

v7.4.34 - v7.4.35 - 2026-05-22
------------------------------

Header byline version-sync to VERSION variable (was v7.4.32; now
v7.4.35). Two pre-existing >250-char lines split to multi-line
continuation form: MASK service list and sudo-cache warning banner
printf. Bootstrap source-protection sentinel drops dead `2>/dev/null`
on `status stack-trace` (the builtin does not write to stderr).
4468 → 4476 LOC (+8 from continuation splits; semantically identical).
fish --no-execute syntax PASS; --help/--version/--bogus/--check
behaviour unchanged (rc=0/0/2/3); JSONL header version field reports
7.4.35.

v7.4.33 - v7.4.34 - 2026-05-21
------------------------------

LOC reduction 5113 → 4468. ~200 multi-line blocks collapsed to
single-line `; and` chained form (if-end bodies, for-loops, printf
'%s\n' continuations, multi-line `set -g` data tables). Collapse
skipped on blocks whose statements carry trailing `#` comments
(joining via `;` would let the `#` consume the trailing `; end`).
Function count unchanged (255 multi-line + 9 single-line); largest
function still 39 LOC (_ry_show_help).

v7.4.32 - v7.4.33 - 2026-05-21
------------------------------

CHANGELOG consolidation. Per-patch entries collapsed to range entries,
closing chain gaps. README version badge and run-summary example
matrix bumped. No functional change; no embedded-content drift;
idempotent re-deploys remain no-ops.

v7.4.31 - v7.4.32 - 2026-05-21
------------------------------

Source-style cleanup. Four single-line content generators
(loader.conf, resolved.conf drop-in, NetworkManager drop-in,
cpupower-service.conf) expanded from semicolon-joined single-line form
to multi-line `printf '%s\n' \` style used elsewhere. Output
byte-identical; idempotent re-deploys remain no-ops.

v7.4.22 - v7.4.31 - 2026-05-21
------------------------------

README cleanup pass. Six Phase prose blocks restructured to uniform
"N sequential operations" intro plus ordered step list (Phase 3 uses
"Four-step sequence per file"). Seven `<summary>` blocks normalised to
"count + unit" suffix. Inline boot-critical paths restructured to
bullet lists in `[!IMPORTANT]` callout and Phase 3. Style sync: `Fish`
→ `fish`, `Pacman` → `pacman`. Column header `Notes` → `Purpose` on
Vulkan deps table. `[!WARNING]` sudo-cache blockquote wrapped at ~70
columns; `3-8 min` → `3–8 min` (en-dash).

v7.4.5 - v7.4.22 - 2026-05-20
-----------------------------

Refactor cycle. LOC reduction 5204 → 5113. Inline comments collapsed
to single-line "why" form. Adjacent `set -l`/`set -g` runs collapsed
to semicolon-chained one-liners. Function extractions to keep ≤50 LOC
target: _install_preflight → _ip_record_regdom; _install_aur_packages
→ _iap_per_pkg_retry + _iap_record_result; _install_rebuild_boot →
_irb_taint_gate; _rdi_run_phases → _rrp_optional_indexer.
_verify_static_services 9-way is-enabled chain collapsed to
`contains`. Defensive double-quotes on $_conf in five test/grep/tee/
chmod sites. Bootstrap: non-existent TMPDIR now overrides to /tmp with
stderr warning; _tmp_dir gains `test -d "$TMPDIR"` defence-in-depth.
_ry_apply_wireless_regdom emits explicit chmod 0644 after `sudo -n
tee`. AUR mt76-mt7925-dkms post-build modinfo failure now WARN, not
silent PASS. BOOT_TAINTED_OVERRIDE JSONL+stderr when
RY_INSTALL_FORCE_BOOT_REBUILD=1 bypasses taint gate. _rdi_render_-
matrix split into header/rows/footer (each ≤50 LOC). _is_system_dst
trimmed to /etc/* and /boot/*. Kernel <6.14 hard floor now records
matrix FAIL (was WARN). Run-summary matrix introduced: install
completion prints box-drawn Unicode matrix to stderr (CHECK/RESULT/
EVIDENCE + totals + verdict); RY_INSTALL_NO_MATRIX=1 opts out.
_phase_record strips embedded newlines and U+2502 from arguments.
_content__etc_default_cpupower-service.conf: `governor` → `GOVERNOR`.
Strict `NOPASSWD: ALL` preflight gate dropped; replaced with
_ry_sudo_cache_banner install-mode warning. README: every `<details>`
block opens to a markdown table.

v7.4.0 - v7.4.5 - 2026-05-20
----------------------------

Preflight + lock + sudo cache redesign. Fish-version preflight: flat
sentinel replaces nested `begin ... end`. Preflight rejects timeout(1)
lacking --foreground / --kill-after (busybox, uutils). _acquire_lock
closes PID-recycle race via /proc/$pid/comm. _acquire_lock_fresh runs
`umask 0077` around mkdir. _ensure_sudo_cached gains
RY_INSTALL_NO_INTERACTIVE_SUDO=1 opt-out. _csp_filter_rdeps checks
pipestatus across all 4 pipe stages. _dc_kill_children widens SIGKILL
grace to 0.5s. _cleanup_tmpfiles inserts two-step `sudo -n true` gate
before sudo find.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19
------------------------------------------

_RY_LOUD_ERR: critical preflight failures reach stderr in default
QUIET install mode; --check stays silent. _ir_resolve_root_uuid gains
4-way mode dispatch and `_reason` distinguishes "findmnt failed" from
"invalid UUID shape". _RY_LOG_SUPPRESS_CREATE eliminates orphan
preflight-*.jsonl on argparse-error paths. _cse_batch_enable
accept-list adds linked, linked-runtime, indirect, generated,
transient. _chk_perms strips leading setuid/setgid/sticky digit.
_run_emit_stream captures head + tail (100 each); build-error tails
preserved. _boot_initrd_size_scan switches to byte comparison (removes
off-by-1MB silent pass). _verify_runtime_kparams pre-extracts preempt/
BAR/TSC markers from full dmesg before 5000-line cap. Short-circuit
chain collapse (5177 → 4842 LOC). _ry_check_disk_space labels switch
to GiB/MiB. _vrkg_rebar_sam lspci regex broadens. _ry_check_deps adds
systemd <250 hard-fail preflight gate. _run tmpdir-alloc sentinel
promoted to EXIT_RUN_TMPFAIL. Log filename → MODE-YYYYMMDD-HHMMSS+
ZZZZ-PID.jsonl.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17
------------------------------------------

NetworkManager 1.56.0 compat: drop wifi.iwd.autoconnect=false. MASK
gains avahi-daemon.service and .socket (10 → 12). New
_csm_disable_ufw_rules. PKGS_ADD gains realtime-privileges; PKGS_DEL
gains bolt. New _ry_check_wireless_regdom and _vrk_audio_state.
RADV_PERFTEST=transfer_queue → RADV_EXPERIMENTAL=transfer_queue.
_vsb_mkinitcpio amdgpu probe tightened `*amdgpu*` → `\bamdgpu\b`.
_ry_check_deps adds GNU-coreutils df probe. HandleSecureAttentionKey
gate <256 → <257. _vrkm_blacklist normalises hyphen → underscore
before lsmod compare. 68 bare system commands gain `command` prefix.
New _ry_apply_wireless_regdom driven by RY_INSTALL_WIRELESS_REGDOM.
/etc/default/cpupower-service.conf added; /etc/drirc dropped. PKGS_ADD
and EXPECTED_SERVICES gain cpupower. _vrk_cpu_state scaling_governor:
powersave → performance. _vmh_order_checks adds systemd:autodetect and
autodetect:microcode pair rules plus fsck-last invariant.
cpupower-epp.service dropped; SERVICE_DESTINATIONS empty.
_RY_MANAGED_FILE_COUNT 13 → 12; EXPECTED_SERVICES 4 → 3. _vre_fstab
unifies noatime/lazytime/commit=10 under `(^|,)tok(,|$)`.
_ir_validate_counts adds _RY_POST_HOOKS:14 and
_RY_BOOT_CRITICAL_DSTS:4. _mr_copy_size_verify adds `cmp -s` after
size match. README: `<details>` blocks switch to tables for mobile
rendering.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15
------------------------------------------

Foundational v6.x → v7.0 series. Reduction release v6.0 → v6.1: 5994
→ 4985 LOC. Drops GNU-tool probes, source-mode scaffolding, ntsync
probes, sudo-keepalive, JSONL progress events, log rotation,
parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe
gates, LVM detection. User-bus detection added via XDG_RUNTIME_DIR/bus
+ `systemctl --user is-system-running`. HOME field-6 captured via
`awk -F:` (GECOS-tolerant). _ry_check_deps adds mv and grep. JSONL
header written before _init_runtime. LOCK_DIR gains `chmod 700`. Emit
functions use printf (flag-injection guard). _run split into _run /
_run_redact_cmd / _run_effective_timeout. _run gains timeout-bypass
for pacman, paru, mkinitcpio, sdboot-manage, paccache. Tmpfile-path
redaction under $TMPDIR. _ip_pacman_invoke gates -Syyu retry on
RY_INSTALL_ALLOW_PARTIAL_UPGRADE. Per-package AUR retry. _vrkg_* GPU
runtime checks added. _atomic_write_file post-write symlink re-check
(TOCTOU). _fstab_atomic_replace findmnt --verify hard-fail. User
destinations install 0600. --install-file single-file redeploy with
per-target post-hook dispatch. argparse --exclusive mode group.
Atomic mkdir + pid-file lock. _ir_validate_counts enforces array-
count invariants. _RY_POST_HOOKS first-match table for --install-file
hooks. _rvc_dispatch adds `*/tmpfiles.d/*` case + _grep_tmpfiles_entry.
New /etc/tmpfiles.d/99-cachyos-thp.conf managed destination.
_aur_verify_mt7925 asserts both pacman and modinfo resolve. Log-dir
mode probe extended to three managed paths. _awf_finalize_mv
sudo-lapse returns $EXIT_FAIL. _ry_exit bail path writes JSONL footer.
_cleanup_pipe SIGPIPE log gated on _RY_HEADER_WRITTEN.
_verify_static_services multi-ExecStart guard. _err_loud deduplicated
via `_msg_print --force`. _vsb_entries distinguishes lapsed-sudo from
empty entries dir. _ry_check_deps adds 10 coreutils. KERNEL_PARAMS
metachar regex backslash escaping tightened.
