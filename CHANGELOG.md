ry-install ChangeLog
====================

v7.4.22 - v7.4.23 - 2026-05-21
------------------------------

Audit-fix release. README style consistency pass: `Fish` → `fish` at
header byline and Prerequisites table (matches 16 other lowercase
uses, per fishshell.com canonical). `Pacman` → `pacman` in Phase 6
prose (matches 14 other lowercase uses, per archlinux.org canonical).
Install Flow Phase 3 cell `Configuration` → `Configuration files`
to match the body heading (`### Phase 3 — Configuration files`).
Package caveats table (6 cells, lines 274-279) stripped of trailing
sentence period to align with cross-table norm (cf. Runtime
variables `RY_RUN_TIMEOUT` cell and ACP audio dmesg cell — both
multi-sentence, neither uses terminal period). README version badge
and run-summary example matrix bumped to v7.4.23. CHANGELOG
backfilled with `v7.4.3 - v7.4.4` and `v7.4.8 - v7.4.9` no-op
release markers (continuity audit; both were internal refactor
rollups absorbed into adjacent entries). Fish syntax clean
(--no-execute rc=0), 264 functions resolve, 15 count invariants
hold. No functional change; script byte-equivalent across deploy,
verify, rollback paths.

v7.4.21 - v7.4.22 - 2026-05-20
------------------------------

Inline comments trimmed to single concise lines focused on the "why"
(42 hotspots, ≤120 chars). Fish syntax clean (--no-execute rc=0), 264
functions resolve, 15 count invariants hold. CHANGELOG reformatted to
kernel.org prose style. README badge bumped. No functional change;
script byte-equivalent across deploy, verify, rollback paths.

v7.4.20 - v7.4.21 - 2026-05-20
------------------------------

Function extractions to keep ≤50 LOC target: _install_preflight →
_ip_record_regdom (57→47); _install_aur_packages → _iap_per_pkg_retry
+ _iap_record_result (66→44); _install_rebuild_boot → _irb_taint_gate
(60→49); _rdi_run_phases → _rrp_optional_indexer (60→47).
_verify_static_services 9-way `or test "$_enabled_state" = <state>`
chain (359 chars) collapsed to `contains` check across all valid
is-enabled states; semantics preserved. Defensive double-quotes added
to $_conf in five test -f / grep / tee / chmod sites in
_ry_check_wireless_regdom and _ry_apply_wireless_regdom (matches
script-wide convention). README: Run Summary heading added to
Contents TOC between Install Flow and Configuration (orphan
#run-summary anchor from v7.4.11).

v7.4.19 - v7.4.20 - 2026-05-20
------------------------------

Bootstrap: non-existent TMPDIR now overrides to /tmp with stderr
warning (previously leaked through _tmp_dir, every downstream mktemp
-p failed, every _run returned EXIT_RUN_TMPFAIL with no root-cause
surface). _tmp_dir gains `test -d "$TMPDIR"` defence-in-depth.
_ry_apply_wireless_regdom emits explicit chmod 0644 after `sudo -n
tee` writes /etc/conf.d/wireless-regdom (normalises against root
umask). _install_aur_packages: mt76-mt7925-dkms post-build modinfo
failure now WARN (sets INSTALL_HAD_ERRORS), not silent PASS.
_install_rebuild_boot and _post_boot emit BOOT_TAINTED_OVERRIDE JSONL
plus stderr when RY_INSTALL_FORCE_BOOT_REBUILD=1 bypasses the taint
gate; post-mortem can now distinguish forced from clean runs.
_rdi_render_matrix split into _rdi_matrix_header / _rdi_matrix_rows /
_rdi_matrix_footer (each ≤50 LOC); output byte-identical.
_is_system_dst trimmed to /etc/* and /boot/* (dead /efi /usr /var
/srv /opt branches removed). _RY_SLEEP_FRAC removed (unused).
_dc_erase_globals erases _RY_MTX_* tally globals.

v7.4.18 - v7.4.19 - 2026-05-20
------------------------------

_install_preflight: _ry_check_kernel_version rc=2 (hard floor <6.14)
now records matrix FAIL (was WARN); soft-warn rc=1 (stability floor,
ntsync, 6.19.0 black-screen regression) unchanged. _vrsv_wifi gates
`pgrep -x iwd` on `command -q pgrep` — warns when procps-ng absent
instead of false FAIL. _vsp_pacman_conf message reworded:
"ParallelDownloads not set (default: 1)" → "(sequential downloads —
uncomment in /etc/pacman.conf to enable)". README: Phase 1 corrected
from "unrestricted sudo" to "cached sudo credential" (stale
pre-v7.4.6 phrasing).

v7.4.17 - v7.4.18 - 2026-05-20
------------------------------

_rdi_render_matrix _inner formula corrected `w + 6` → `w + 8`; top /
bottom / mid bars and footer rows now uniformly 80-wide (were 78
against 80-char data rows). CHANGELOG v7.4.x dates normalised to
monotonic 2026-05-20.

v7.4.16 - v7.4.17 - 2026-05-20
------------------------------

76 adjacent `set -l` / `set -g` runs collapsed to semicolon-chained
one-liners (5204 → 5040 LOC). README: every `<details>` block opens
to a markdown table; prose-only collapsibles converted to tables.

v7.4.15 - v7.4.16 - 2026-05-20
------------------------------

README: 16 enumerative tables trimmed; script remains the source of
truth via --verify-static.

v7.4.14 - v7.4.15 - 2026-05-20
------------------------------

README: 17 `<summary>` headers stripped of parenthetical suffixes;
counts retained.

v7.4.13 - v7.4.14 - 2026-05-20
------------------------------

_rdi_summary gates REBOOT advisory on _RY_BOOT_CRIT_HIT; prints DO
NOT REBOOT + recovery steps on FAIL-BOOT-CRITICAL.
_install_rebuild_boot records "Boot: post-rebuild sanity" SKIP on
_irb_sdboot_apply non-zero. _rdi_render_matrix totals line gains N/A
bucket. _ry_check_kernel_version returns rc=0/1/2
(ok/soft-warn/hard-fail); only hard floor <6.14 elevates
INSTALL_HAD_ERRORS. _install_preflight regdom test;and;or chain
refactored to if/else. New _irb_skip_post_mki and _ip_bail_prep
consolidate inline SKIP/bail cascades.

v7.4.12 - v7.4.13 - 2026-05-20
------------------------------

Run-summary matrix renders on preflight bail (EXIT_PREFLIGHT /
EXIT_USAGE). FAIL-BOOT-CRITICAL keyed on dedicated _RY_BOOT_CRIT_HIT
(was overloaded _PROG_FINALIZED_SKIP). _phase_record strips embedded
newlines and U+2502 field delimiter from arguments.

v7.4.11 - v7.4.12 - 2026-05-20
------------------------------

Run-summary matrix introduced: install completion prints box-drawn
Unicode matrix to stderr (CHECK / RESULT / EVIDENCE + totals +
verdict); RY_INSTALL_NO_MATRIX=1 opts out. New _phase_record (appends
to _RY_PHASE_RESULTS + JSONL), _rdi_render_matrix, _rdi_elapsed.
_ry_install_file tracks changed-vs-idempotent deploy outcomes. Phase
instrumentation across preflight, packages, AUR, configs, fstab,
services, boot, finalize.

v7.4.10 - v7.4.11 - 2026-05-20
------------------------------

_csp_filter_rdeps drops redundant `2>/dev/null` on numeric pipestatus
tests. 18 single-line helpers gain --description (100% coverage).

v7.4.9 - v7.4.10 - 2026-05-20
-----------------------------

Stage-1-rc semantics tightened: 7 callers check only pipe stage 1 —
fish `string` builtins rc=1 on empty input is normal. Empty
enumeration routes to "NONE found" diagnostics.

v7.4.8 - v7.4.9 - 2026-05-20
----------------------------

Internal refactor consolidation. Stage-1-rc preparation folded
forward into v7.4.10's pipestatus tightening (see
`v7.4.9 - v7.4.10`). No user-visible change.

v7.4.7 - v7.4.8 - 2026-05-20
----------------------------

_content__etc_default_cpupower-service.conf: `governor` → `GOVERNOR`
(upstream env-script compatibility). _csp_filter_rdeps accepts fish
`string` rc=1 on stages 2-4 (no-op).

v7.4.6 - v7.4.7 - 2026-05-20
----------------------------

_ry_sudo_cache_banner trimmed to three lines (risk, mitigations,
recovery).

v7.4.5 - v7.4.6 - 2026-05-20
----------------------------

Strict `NOPASSWD: ALL` preflight gate dropped; replaced with
_ry_sudo_cache_banner install-mode warning.

v7.4.4 - v7.4.5 - 2026-05-20
----------------------------

Inline comments collapsed from multi-line to single-line form.

v7.4.3 - v7.4.4 - 2026-05-20
----------------------------

Internal refactor consolidation. Comment-collapse preparation folded
forward into v7.4.5's single-line conversion pass (see
`v7.4.4 - v7.4.5`). No user-visible change.

v7.4.0 - v7.4.3 - 2026-05-20
----------------------------

Fish-version preflight: flat sentinel replaces nested `begin ... end`.
Preflight rejects timeout(1) lacking --foreground / --kill-after
(busybox, uutils). _acquire_lock closes PID-recycle race via
/proc/$pid/comm. _acquire_lock_fresh runs `umask 0077` around mkdir.
_ensure_sudo_cached gains RY_INSTALL_NO_INTERACTIVE_SUDO=1 opt-out.
_csp_filter_rdeps checks pipestatus across all 4 pipe stages.
_dc_kill_children widens SIGKILL grace to 0.5s. _cleanup_tmpfiles
inserts two-step `sudo -n true` gate before sudo find.

v7.3.9 - v7.4.0 - 2026-05-19
----------------------------

_RY_LOUD_ERR: critical preflight failures reach stderr in default
QUIET install mode; --check stays silent. _ir_resolve_root_uuid gains
4-way mode dispatch. _RY_LOG_SUPPRESS_CREATE eliminates orphan
preflight-*.jsonl on argparse-error paths. _cse_batch_enable
accept-list adds linked, linked-runtime, indirect, generated,
transient. _chk_perms strips leading setuid/setgid/sticky digit.
_run_emit_stream captures head + tail (100 each); build-error tails
preserved. _boot_initrd_size_scan switches to byte comparison
(removes off-by-1MB silent pass). _verify_runtime_kparams
pre-extracts preempt / BAR / TSC markers from full dmesg before
5000-line cap.

v7.3.0 - v7.3.9 - 2026-05-17 to 2026-05-18
------------------------------------------

Short-circuit chain collapse: 9 single-statement bodies, 16
three-line and 95 four-line if-end blocks (5177 → 4842 LOC).
_ir_resolve_root_uuid `_reason` distinguishes "findmnt failed" from
"invalid UUID shape". _ry_check_disk_space labels switch to GiB /
MiB. _vrkg_rebar_sam lspci regex broadens to any G-suffix or
M-values ≥500. _err_loud log-only when MODE=check (silence
contract). _ry_check_deps adds systemd <250 hard-fail preflight
gate. _run tmpdir-alloc sentinel promoted from magic 251 to
EXIT_RUN_TMPFAIL. Log filename → MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl.

v7.2.0 - v7.2.6 - 2026-05-17
----------------------------

New _ry_apply_wireless_regdom driven by RY_INSTALL_WIRELESS_REGDOM.
/etc/default/cpupower-service.conf added; /etc/drirc dropped.
PKGS_ADD and EXPECTED_SERVICES gain cpupower. _vrk_cpu_state
scaling_governor: powersave → performance. _vmh_order_checks adds
systemd:autodetect and autodetect:microcode pair rules plus
fsck-last invariant. cpupower-epp.service dropped;
SERVICE_DESTINATIONS empty. _RY_MANAGED_FILE_COUNT 13→12;
EXPECTED_SERVICES 4→3. _vre_fstab unifies noatime / lazytime /
commit=10 under `(^|,)tok(,|$)`. _ir_validate_counts adds
_RY_POST_HOOKS:14 and _RY_BOOT_CRITICAL_DSTS:4. _mr_copy_size_verify
adds `cmp -s` after size match.

v7.0.0 - v7.1.0 - 2026-05-15 to 2026-05-17
------------------------------------------

NetworkManager 1.56.0 compat: drop wifi.iwd.autoconnect=false. MASK
gains avahi-daemon.service and .socket (10→12). New
_csm_disable_ufw_rules. PKGS_ADD gains realtime-privileges; PKGS_DEL
gains bolt. New _ry_check_wireless_regdom and _vrk_audio_state.
RADV_PERFTEST=transfer_queue → RADV_EXPERIMENTAL=transfer_queue.
_vsb_mkinitcpio amdgpu probe tightened `*amdgpu*` → `\bamdgpu\b`.
_ry_check_deps adds GNU-coreutils df probe. HandleSecureAttentionKey
gate <256 → <257. _vrkm_blacklist normalises hyphen → underscore
before lsmod compare. 68 bare system commands gain `command` prefix.
README: `<details>` blocks switch to tables for mobile rendering.

v6.5.0 - v6.5.18 - 2026-05-14 to 2026-05-15
-------------------------------------------

_rvc_dispatch adds `*/tmpfiles.d/*` case + _grep_tmpfiles_entry. New
/etc/tmpfiles.d/99-cachyos-thp.conf managed destination.
_aur_verify_mt7925 asserts both pacman and modinfo resolve. Log-dir
mode probe extended to three managed paths. _awf_finalize_mv
sudo-lapse returns $EXIT_FAIL. _ry_exit bail path writes JSONL
footer. _cleanup_pipe SIGPIPE log gated on _RY_HEADER_WRITTEN.
_dc_sweep_tmpfiles spurious TMPFILE_STUCK fix.
_verify_static_services multi-ExecStart guard. _err_loud deduplicated
via `_msg_print --force`. _vsb_entries distinguishes lapsed-sudo from
empty entries dir. _ry_check_deps adds 10 coreutils. KERNEL_PARAMS
metachar regex backslash escaping tightened.

v6.2.0 - v6.2.13 - 2026-05-12 to 2026-05-14
-------------------------------------------

HOME field-6 captured via `awk -F:` (GECOS-tolerant). _ry_check_deps
adds mv and grep. JSONL header written before _init_runtime. LOCK_DIR
gains `chmod 700`. Emit functions use printf (flag-injection guard).
_run split into _run / _run_redact_cmd / _run_effective_timeout. _run
gains timeout-bypass for pacman, paru, mkinitcpio, sdboot-manage,
paccache. Tmpfile-path redaction under $TMPDIR. _ip_pacman_invoke
gates -Syyu retry on RY_INSTALL_ALLOW_PARTIAL_UPGRADE. Per-package
AUR retry. _vrkg_* GPU runtime checks added. _atomic_write_file
post-write symlink re-check (TOCTOU). _fstab_atomic_replace findmnt
--verify hard-fail. User destinations install 0600. --install-file
single-file redeploy with per-target post-hook dispatch. argparse
--exclusive mode group. Atomic mkdir + pid-file lock.
_ir_validate_counts enforces array-count invariants. _RY_POST_HOOKS
first-match table for --install-file hooks.

v6.0.0 - v6.1.0 - 2026-05-12
----------------------------

Reduction release: 5994 → 4985 LOC. Drops GNU-tool probes,
source-mode scaffolding, ntsync probes, sudo-keepalive, JSONL
progress events, log rotation, parallel-child PID guard,
atomic-write TOCTOU re-stat, boot-wipe gates, LVM detection.
User-bus detection added via XDG_RUNTIME_DIR/bus + `systemctl --user
is-system-running`.
