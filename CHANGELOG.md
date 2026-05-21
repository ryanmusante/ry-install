ry-install ChangeLog
====================

v7.4.32 - v7.4.33 - 2026-05-21
------------------------------

CHANGELOG consolidation. Thirty per-patch entries collapsed to nine
range entries, closing seven chain gaps (v7.4.8↔v7.4.9, v7.4.3↔v7.4.4,
v7.2.6↔v7.3.0, v7.1.0↔v7.2.0, v6.5.18↔v7.0.0, v6.2.13↔v6.5.0,
v6.1.0↔v6.2.0) where prior consecutive range entries left a missing
transition. README version badge and run-summary example matrix
bumped to v7.4.33. No functional change to ry-install.fish behaviour;
no embedded-content drift; idempotent re-deploys remain no-ops.

v7.4.31 - v7.4.32 - 2026-05-21
------------------------------

Source-style cleanup. Four single-line content generators
(`_content__boot_loader_loader.conf`,
`_content__etc_systemd_resolved.conf.d_99-cachyos-resolved.conf`,
`_content__etc_NetworkManager_conf.d_99-cachyos-nm.conf`,
`_content__etc_default_cpupower-service.conf`) expanded from
semicolon-joined single-line form to the multi-line `printf '%s\n' \`
style used elsewhere in the file. Output byte-identical; idempotent
re-deploys remain no-ops; embedded-vs-installed checksum unchanged.
No functional change.

v7.4.28 - v7.4.31 - 2026-05-21
------------------------------

README cleanup pass (three releases consolidated). Redundancy
elimination: four-path boot-critical bullet list in Phase 3 collapsed
to Managed Files Destinations table reference; atomic-write step
sequence in Managed Files prose collapsed to Phase 3 canonical;
trailing `RY_INSTALL_PKG_REMOVE_CASCADE` paragraph collapsed to
Package caveats Reverse-deps row. Six Phase prose blocks restructured
to uniform "N sequential operations" intro plus ordered step list
(Phase 1: 3 ops, Phase 2: 2 ops, Phase 3: 4 sub-steps, Phase 4: 6
ops, Phase 5: 3 ops, Phase 6: 3 ops). Six `<summary>` blocks switched
to "count + unit" suffix (Initramfs/6 fields, Package caveats/6
notes, fstab/3 options, Destinations/12 paths, Exit codes/8 codes,
Runtime variables/10 vars, Logs/5 properties). Inline boot-critical
paths restructured to bullet lists in `[!IMPORTANT]` callout and
Phase 3.

v7.4.22 - v7.4.28 - 2026-05-21
------------------------------

README style sync. `Fish` → `fish` at header byline and Prerequisites
table; `Pacman` → `pacman` in Phase 6 prose and `octopi` reason cell.
Install Flow Phase 3 cell `Configuration` → `Configuration files` to
match the body heading. Package caveats table stripped of trailing
sentence period. `<summary>` count suffixes normalised: 6 bare-count
blocks gain unit suffix, aligning with the 10 descriptive-suffix
neighbours. `Vulkan dependencies` column header `Notes` → `Purpose`.
`iwd` table row 2 reformatted from `[DriverQuirks] | PowerSaveDisable
=*` to `[DriverQuirks] PowerSaveDisable | *`, restoring the
"Section Key | Value" column pattern. `[!WARNING]` sudo-cache
blockquote wrapped at ~70 columns; `3-8 min` → `3–8 min` (en-dash).

v7.4.5 - v7.4.22 - 2026-05-20
-----------------------------

Refactor cycle (sixteen releases consolidated). LOC reduction
5204→5113. Inline comments collapsed to single-line "why" form (42
hotspots, ≤120 chars). 76 adjacent `set -l`/`set -g` runs collapsed
to semicolon-chained one-liners. Function extractions to keep ≤50
LOC target: _install_preflight → _ip_record_regdom; _install_aur_-
packages → _iap_per_pkg_retry + _iap_record_result;
_install_rebuild_boot → _irb_taint_gate; _rdi_run_phases →
_rrp_optional_indexer. _verify_static_services 9-way is-enabled
chain collapsed to `contains`. Defensive double-quotes added to
$_conf in five test/grep/tee/chmod sites in _ry_check_wireless_-
regdom and _ry_apply_wireless_regdom. Bootstrap: non-existent
TMPDIR now overrides to /tmp with stderr warning (previously leaked
through _tmp_dir, every downstream mktemp -p failed). _tmp_dir
gains `test -d "$TMPDIR"` defence-in-depth. _ry_apply_wireless_-
regdom emits explicit chmod 0644 after `sudo -n tee`. AUR
mt76-mt7925-dkms post-build modinfo failure now WARN, not silent
PASS. BOOT_TAINTED_OVERRIDE JSONL+stderr when
RY_INSTALL_FORCE_BOOT_REBUILD=1 bypasses taint gate. _rdi_render_-
matrix split into header/rows/footer (each ≤50 LOC). _is_system_dst
trimmed to /etc/* and /boot/*. _install_preflight: kernel <6.14
hard floor now records matrix FAIL (was WARN). _vrsv_wifi gates
`pgrep -x iwd` on `command -q pgrep`. _rdi_render_matrix _inner
formula corrected (top/bottom/mid bars now uniformly 80-wide).
Run-summary matrix introduced: install completion prints box-drawn
Unicode matrix to stderr (CHECK/RESULT/EVIDENCE + totals + verdict);
RY_INSTALL_NO_MATRIX=1 opts out. _phase_record strips embedded
newlines and U+2502 from arguments. Stage-1-rc semantics tightened
across 7 callers. _content__etc_default_cpupower-service.conf:
`governor` → `GOVERNOR`. _ry_sudo_cache_banner trimmed to three
lines. Strict `NOPASSWD: ALL` preflight gate dropped; replaced with
_ry_sudo_cache_banner install-mode warning. README: every
`<details>` block opens to a markdown table.

v7.4.0 - v7.4.5 - 2026-05-20
----------------------------

Preflight + lock + sudo cache redesign. Fish-version preflight: flat
sentinel replaces nested `begin ... end`. Preflight rejects
timeout(1) lacking --foreground / --kill-after (busybox, uutils).
_acquire_lock closes PID-recycle race via /proc/$pid/comm.
_acquire_lock_fresh runs `umask 0077` around mkdir.
_ensure_sudo_cached gains RY_INSTALL_NO_INTERACTIVE_SUDO=1 opt-out.
_csp_filter_rdeps checks pipestatus across all 4 pipe stages.
_dc_kill_children widens SIGKILL grace to 0.5s. _cleanup_tmpfiles
inserts two-step `sudo -n true` gate before sudo find. Inline
comments collapsed from multi-line to single-line form.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19
------------------------------------------

_RY_LOUD_ERR: critical preflight failures reach stderr in default
QUIET install mode; --check stays silent. _ir_resolve_root_uuid
gains 4-way mode dispatch and `_reason` distinguishes "findmnt
failed" from "invalid UUID shape". _RY_LOG_SUPPRESS_CREATE
eliminates orphan preflight-*.jsonl on argparse-error paths.
_cse_batch_enable accept-list adds linked, linked-runtime,
indirect, generated, transient. _chk_perms strips leading
setuid/setgid/sticky digit. _run_emit_stream captures head + tail
(100 each); build-error tails preserved. _boot_initrd_size_scan
switches to byte comparison (removes off-by-1MB silent pass).
_verify_runtime_kparams pre-extracts preempt/BAR/TSC markers from
full dmesg before 5000-line cap. Short-circuit chain collapse: 9
single-statement bodies, 16 three-line and 95 four-line if-end
blocks (5177→4842 LOC). _ry_check_disk_space labels switch to
GiB/MiB. _vrkg_rebar_sam lspci regex broadens to any G-suffix or
M-values ≥500. _ry_check_deps adds systemd <250 hard-fail
preflight gate. _run tmpdir-alloc sentinel promoted to
EXIT_RUN_TMPFAIL. Log filename →
MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17
------------------------------------------

NetworkManager 1.56.0 compat: drop wifi.iwd.autoconnect=false. MASK
gains avahi-daemon.service and .socket (10→12). New
_csm_disable_ufw_rules. PKGS_ADD gains realtime-privileges; PKGS_DEL
gains bolt. New _ry_check_wireless_regdom and _vrk_audio_state.
RADV_PERFTEST=transfer_queue → RADV_EXPERIMENTAL=transfer_queue.
_vsb_mkinitcpio amdgpu probe tightened `*amdgpu*` → `\bamdgpu\b`.
_ry_check_deps adds GNU-coreutils df probe.
HandleSecureAttentionKey gate <256 → <257. _vrkm_blacklist
normalises hyphen → underscore before lsmod compare. 68 bare system
commands gain `command` prefix. New _ry_apply_wireless_regdom
driven by RY_INSTALL_WIRELESS_REGDOM. /etc/default/cpupower-
service.conf added; /etc/drirc dropped. PKGS_ADD and
EXPECTED_SERVICES gain cpupower. _vrk_cpu_state scaling_governor:
powersave → performance. _vmh_order_checks adds systemd:autodetect
and autodetect:microcode pair rules plus fsck-last invariant.
cpupower-epp.service dropped; SERVICE_DESTINATIONS empty.
_RY_MANAGED_FILE_COUNT 13→12; EXPECTED_SERVICES 4→3. _vre_fstab
unifies noatime/lazytime/commit=10 under `(^|,)tok(,|$)`.
_ir_validate_counts adds _RY_POST_HOOKS:14 and
_RY_BOOT_CRITICAL_DSTS:4. _mr_copy_size_verify adds `cmp -s` after
size match. README: `<details>` blocks switch to tables for mobile
rendering.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15
------------------------------------------

Foundational releases (v6.x series → v7.0). Reduction release v6.0
→ v6.1: 5994 → 4985 LOC. Drops GNU-tool probes, source-mode
scaffolding, ntsync probes, sudo-keepalive, JSONL progress events,
log rotation, parallel-child PID guard, atomic-write TOCTOU
re-stat, boot-wipe gates, LVM detection. User-bus detection added
via XDG_RUNTIME_DIR/bus + `systemctl --user is-system-running`.
HOME field-6 captured via `awk -F:` (GECOS-tolerant). _ry_check_deps
adds mv and grep. JSONL header written before _init_runtime.
LOCK_DIR gains `chmod 700`. Emit functions use printf
(flag-injection guard). _run split into _run / _run_redact_cmd /
_run_effective_timeout. _run gains timeout-bypass for pacman, paru,
mkinitcpio, sdboot-manage, paccache. Tmpfile-path redaction under
$TMPDIR. _ip_pacman_invoke gates -Syyu retry on
RY_INSTALL_ALLOW_PARTIAL_UPGRADE. Per-package AUR retry. _vrkg_*
GPU runtime checks added. _atomic_write_file post-write symlink
re-check (TOCTOU). _fstab_atomic_replace findmnt --verify
hard-fail. User destinations install 0600. --install-file
single-file redeploy with per-target post-hook dispatch. argparse
--exclusive mode group. Atomic mkdir + pid-file lock.
_ir_validate_counts enforces array-count invariants. _RY_POST_HOOKS
first-match table for --install-file hooks. _rvc_dispatch adds
`*/tmpfiles.d/*` case + _grep_tmpfiles_entry. New
/etc/tmpfiles.d/99-cachyos-thp.conf managed destination.
_aur_verify_mt7925 asserts both pacman and modinfo resolve.
Log-dir mode probe extended to three managed paths.
_awf_finalize_mv sudo-lapse returns $EXIT_FAIL. _ry_exit bail path
writes JSONL footer. _cleanup_pipe SIGPIPE log gated on
_RY_HEADER_WRITTEN. _verify_static_services multi-ExecStart guard.
_err_loud deduplicated via `_msg_print --force`. _vsb_entries
distinguishes lapsed-sudo from empty entries dir. _ry_check_deps
adds 10 coreutils. KERNEL_PARAMS metachar regex backslash escaping
tightened.
