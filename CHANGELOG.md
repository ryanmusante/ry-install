ry-install ChangeLog
====================

v7.4.21 - v7.4.22 - 2026-05-20
------------------------------

Verbose inline comments throughout ry-install.fish trimmed to single concise
lines focused on the "why"; 42 comment hotspots reduced (no comment now
exceeds 120 chars). Fish syntax remains clean (--no-execute rc=0), all 264
functions still resolve, all 15 count invariants still enforced. CHANGELOG
reformatted from bullet list to kernel.org prose style. README badge bumped.
No functional change: script byte-equivalence preserved across all
deployment, verification, and rollback paths.

v7.4.20 - v7.4.21 - 2026-05-20
------------------------------

_install_preflight extracts _ip_record_regdom for the regdom phase-record
block; function reduced from 57 to 47 lines (within ≤50 target).
_install_aur_packages extracts _iap_per_pkg_retry for the post-batch-failure
per-package retry loop and _iap_record_result for final phase-record
dispatch; function reduced from 66 to 44 lines. _install_rebuild_boot
extracts _irb_taint_gate for the mkinitcpio-revert plus _RY_BOOT_TAINTED
early-exit gates; function reduced from 60 to 49 lines. _rdi_run_phases
extracts _rrp_optional_indexer for updatedb / pkgfile --update paired
blocks; function reduced from 60 to 47 lines. _verify_static_services
collapsed the 9-way `or test "$_enabled_state" = <state>` chain (359-char
line) to a `contains` check across all valid is-enabled states; semantics
preserved. _ry_check_wireless_regdom and _ry_apply_wireless_regdom gained
defensive double-quotes around $_conf in five test -f / grep / tee / chmod
sites; matches the script-wide convention even though fish does not
word-split. README: Run Summary heading added to the Contents TOC between
Install Flow and Configuration; the #run-summary anchor was orphaned from
v7.4.11 introduction.

v7.4.19 - v7.4.20 - 2026-05-20
------------------------------

Bootstrap: TMPDIR pointing at a non-existent directory now overrides to
/tmp with a stderr warning. Previously the env var leaked through _tmp_dir,
causing every downstream mktemp -p to fail and every _run to return
EXIT_RUN_TMPFAIL with no root-cause surface. _tmp_dir gains a `test -d
"$TMPDIR"` defence-in-depth so a non-existent path cannot leak even if the
bootstrap probe is bypassed. _ry_apply_wireless_regdom emits an explicit
chmod 0644 after `sudo -n tee` writes /etc/conf.d/wireless-regdom,
normalising mode against root's umask. _install_aur_packages: when
mt76-mt7925-dkms is in AUR_PKGS but modinfo mt7925e fails post-build, phase
result is now WARN (sets INSTALL_HAD_ERRORS) instead of silent PASS.
_install_rebuild_boot and _post_boot emit a JSONL BOOT_TAINTED_OVERRIDE log
plus stderr warning when RY_INSTALL_FORCE_BOOT_REBUILD=1 bypasses the taint
gate; post-mortem can now distinguish forced from clean runs.
_rdi_render_matrix split into _rdi_matrix_header, _rdi_matrix_rows, and
_rdi_matrix_footer, each ≤50 lines; output remains byte-identical to the
previous monolithic renderer. _is_system_dst trimmed to /etc/* and /boot/*
roots (the only managed-destination roots); dead branches /efi, /usr, /var,
/srv, /opt removed. _RY_SLEEP_FRAC removed (set on bootstrap, never
consumed in any sleep call). _dc_erase_globals erases _RY_MTX_* matrix
tally globals as part of cleanup symmetry.

v7.4.18 - v7.4.19 - 2026-05-20
------------------------------

_install_preflight: _ry_check_kernel_version rc=2 (hard floor <6.14) now
records matrix FAIL instead of WARN. Soft-warn rc=1 (stability floor,
ntsync, 6.19.0 black-screen regression) remains WARN. _vrsv_wifi gates the
`pgrep -x iwd` probe on `command -q pgrep`; warns when procps-ng is absent
instead of emitting false FAIL. _vsp_pacman_conf reworded the
"ParallelDownloads not set (default: 1)" message to "(sequential downloads
— uncomment in /etc/pacman.conf to enable)". README: Phase 1 wording
changed from "unrestricted sudo" to "cached sudo credential" (stale
phrasing from pre-v7.4.6 strict `NOPASSWD: ALL` gate).

v7.4.17 - v7.4.18 - 2026-05-20
------------------------------

_rdi_render_matrix _inner formula corrected from `w + 6` to `w + 8`.
Previously the top/bottom/mid bars and footer rows were 78 chars against
80-char data rows; all rows are now uniformly 80 wide. CHANGELOG v7.4.x
entry dates normalised to monotonic 2026-05-20.

v7.4.16 - v7.4.17 - 2026-05-20
------------------------------

76 adjacent `set -l` / `set -g` runs collapsed to semicolon-chained
one-liners (5204 → 5040 lines). README: every <details> block now opens to
a markdown table; prose-only collapsibles converted back to tables.

v7.4.15 - v7.4.16 - 2026-05-20
------------------------------

README: 16 enumerative tables trimmed; script remains the source of truth
via --verify-static.

v7.4.14 - v7.4.15 - 2026-05-20
------------------------------

README: 17 <summary> headers stripped of parenthetical suffixes; counts
retained.

v7.4.13 - v7.4.14 - 2026-05-20
------------------------------

_rdi_summary gates the REBOOT advisory on _RY_BOOT_CRIT_HIT and prints
DO NOT REBOOT plus recovery steps on FAIL-BOOT-CRITICAL.
_install_rebuild_boot records "Boot: post-rebuild sanity" SKIP on
_irb_sdboot_apply non-zero return. _rdi_render_matrix totals line gains an
N/A bucket. _ry_check_kernel_version now returns rc=0 (ok), rc=1
(soft-warn), or rc=2 (hard-fail); only the hard floor <6.14 elevates
INSTALL_HAD_ERRORS. _install_preflight regdom test;and;or chain refactored
to if/else. New _irb_skip_post_mki and _ip_bail_prep helpers consolidate
inline SKIP/bail cascades.

v7.4.12 - v7.4.13 - 2026-05-20
------------------------------

Run-summary matrix now renders on preflight bail (EXIT_PREFLIGHT /
EXIT_USAGE). Verdict FAIL-BOOT-CRITICAL keyed on dedicated
_RY_BOOT_CRIT_HIT (previously overloaded _PROG_FINALIZED_SKIP).
_phase_record strips embedded newlines and U+2502 field delimiter from
arguments.

v7.4.11 - v7.4.12 - 2026-05-20
------------------------------

Run-summary matrix introduced: install completion prints a box-drawn
Unicode matrix to stderr with CHECK / RESULT / EVIDENCE columns plus
totals and verdict; RY_INSTALL_NO_MATRIX=1 opts out. New _phase_record
helper appends rows to _RY_PHASE_RESULTS and JSONL. New _rdi_render_matrix
renderer and _rdi_elapsed formatter. _ry_install_file tracks changed-vs-
idempotent deploy outcomes. Phase instrumentation added across preflight,
packages, AUR, configs, fstab, services, boot, and finalize.

v7.4.10 - v7.4.11 - 2026-05-20
------------------------------

_csp_filter_rdeps drops redundant `2>/dev/null` on numeric pipestatus
tests. 18 single-line helpers gain --description for 100% coverage.

v7.4.9 - v7.4.10 - 2026-05-20
-----------------------------

Stage-1-rc semantics tightened: 7 callers check only pipe stage 1 — fish
`string` builtins rc=1 on empty input is normal. Empty enumeration now
routes to "NONE found" diagnostics.

v7.4.7 - v7.4.8 - 2026-05-20
----------------------------

_content__etc_default_cpupower-service.conf: key `governor` renamed to
`GOVERNOR` for upstream env-script compatibility. _csp_filter_rdeps
accepts fish `string` rc=1 on stages 2-4 (no-op).

v7.4.6 - v7.4.7 - 2026-05-20
----------------------------

_ry_sudo_cache_banner trimmed to three lines (risk, mitigations, recovery).

v7.4.5 - v7.4.6 - 2026-05-20
----------------------------

Strict `NOPASSWD: ALL` preflight gate dropped; replaced with
_ry_sudo_cache_banner install-mode warning.

v7.4.4 - v7.4.5 - 2026-05-20
----------------------------

Inline comments collapsed from multi-line to single-line form.

v7.4.0 - v7.4.3 - 2026-05-20
----------------------------

Fish-version preflight: flat sentinel replaces nested `begin ... end`.
Preflight rejects timeout(1) lacking --foreground / --kill-after (busybox,
uutils). _acquire_lock closes the PID-recycle race via /proc/$pid/comm.
_acquire_lock_fresh runs `umask 0077` around the mkdir. _ensure_sudo_cached
gains an RY_INSTALL_NO_INTERACTIVE_SUDO=1 opt-out. _csp_filter_rdeps checks
pipestatus across all 4 pipe stages. _dc_kill_children widens the SIGKILL
grace to 0.5s. _cleanup_tmpfiles inserts a two-step `sudo -n true` gate
before the sudo find.

v7.3.9 - v7.4.0 - 2026-05-19
----------------------------

_RY_LOUD_ERR: critical preflight failures now reach stderr in default
QUIET install mode; --check stays silent. _ir_resolve_root_uuid gains
4-way mode dispatch. _RY_LOG_SUPPRESS_CREATE eliminates orphan
preflight-*.jsonl on argparse-error paths. _cse_batch_enable accept-list
adds linked, linked-runtime, indirect, generated, transient. _chk_perms
strips the leading setuid/setgid/sticky digit. _run_emit_stream captures
head plus tail (100 each) so build-error tails are preserved.
_boot_initrd_size_scan switches to byte comparison, removing the off-by-1MB
silent pass. _verify_runtime_kparams pre-extracts preempt/BAR/TSC markers
from full dmesg before the 5000-line cap.

v7.3.0 - v7.3.9 - 2026-05-17 to 2026-05-18
------------------------------------------

Short-circuit chain collapse: 9 single-statement bodies, 16 three-line and
95 four-line if-end blocks (5177 → 4842 lines). _ir_resolve_root_uuid
`_reason` distinguishes "findmnt failed" from "invalid UUID shape".
_ry_check_disk_space labels switch to GiB / MiB. _vrkg_rebar_sam lspci
regex broadens to any G-suffix or M-values ≥500. _err_loud is log-only
when MODE=check (silence contract). _ry_check_deps adds a systemd <250
hard-fail preflight gate. _run tmpdir-alloc sentinel promoted from magic
251 to EXIT_RUN_TMPFAIL. Log filename format changed to
MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl.

v7.2.0 - v7.2.6 - 2026-05-17
----------------------------

New _ry_apply_wireless_regdom driven by RY_INSTALL_WIRELESS_REGDOM.
/etc/default/cpupower-service.conf added; /etc/drirc dropped. PKGS_ADD
gains cpupower; EXPECTED_SERVICES gains cpupower.service. _vrk_cpu_state
scaling_governor expectation changes from powersave to performance.
_vmh_order_checks adds systemd:autodetect and autodetect:microcode pair
rules plus the fsck-last invariant. cpupower-epp.service dropped;
SERVICE_DESTINATIONS now empty. _RY_MANAGED_FILE_COUNT 13 → 12;
EXPECTED_SERVICES 4 → 3. _vre_fstab unifies noatime / lazytime / commit=10
token tests under `(^|,)tok(,|$)`. _ir_validate_counts adds
_RY_POST_HOOKS:14 and _RY_BOOT_CRITICAL_DSTS:4. _mr_copy_size_verify adds
`cmp -s` after size match.

v7.0.0 - v7.1.0 - 2026-05-15 to 2026-05-17
------------------------------------------

NetworkManager 1.56.0 compatibility: drop wifi.iwd.autoconnect=false.
MASK gains avahi-daemon.service and .socket (10 → 12). New
_csm_disable_ufw_rules. PKGS_ADD gains realtime-privileges; PKGS_DEL gains
bolt. New _ry_check_wireless_regdom and _vrk_audio_state.
RADV_PERFTEST=transfer_queue migrated to RADV_EXPERIMENTAL=transfer_queue.
_vsb_mkinitcpio amdgpu probe tightened from `*amdgpu*` to `\bamdgpu\b`.
_ry_check_deps adds a GNU-coreutils df probe. HandleSecureAttentionKey gate
moves from <256 to <257. _vrkm_blacklist normalises hyphen to underscore
before lsmod compare. Sixty-eight bare system-command invocations gain a
`command` prefix. README: <details> blocks switch to tables for mobile
rendering.

v6.5.0 - v6.5.18 - 2026-05-14 to 2026-05-15
-------------------------------------------

_rvc_dispatch adds a `*/tmpfiles.d/*` case and _grep_tmpfiles_entry. New
/etc/tmpfiles.d/99-cachyos-thp.conf managed destination.
_aur_verify_mt7925 asserts both pacman and modinfo resolve. Log-dir mode
probe extended to three managed paths. _awf_finalize_mv sudo-lapse returns
$EXIT_FAIL. _ry_exit bail path writes the JSONL footer. _cleanup_pipe
SIGPIPE log gated on _RY_HEADER_WRITTEN. _dc_sweep_tmpfiles spurious
TMPFILE_STUCK fix. _verify_static_services multi-ExecStart guard.
_err_loud deduplicated via `_msg_print --force`. _vsb_entries distinguishes
lapsed-sudo from empty entries dir. _ry_check_deps adds 10 coreutils.
KERNEL_PARAMS metachar regex backslash escaping tightened.

v6.2.0 - v6.2.13 - 2026-05-12 to 2026-05-14
-------------------------------------------

HOME field-6 captured via `awk -F:` (GECOS-tolerant). _ry_check_deps adds
mv and grep. JSONL header written before _init_runtime. LOCK_DIR gains
`chmod 700`. Emit functions use printf (flag-injection guard). _run split
into _run, _run_redact_cmd, _run_effective_timeout. _run gains
timeout-bypass for pacman, paru, mkinitcpio, sdboot-manage, paccache.
Tmpfile-path redaction under $TMPDIR. _ip_pacman_invoke gates -Syyu retry
on RY_INSTALL_ALLOW_PARTIAL_UPGRADE. Per-package AUR retry. _vrkg_* GPU
runtime checks added. _atomic_write_file: post-write symlink re-check
(TOCTOU). _fstab_atomic_replace: findmnt --verify hard-fail. User
destinations install with 0600. --install-file single-file redeploy with
per-target post-hook dispatch. argparse --exclusive mode group. Atomic
mkdir plus pid-file lock. _ir_validate_counts enforces array-count
invariants. _RY_POST_HOOKS first-match table for --install-file hooks.

v6.0.0 - v6.1.0 - 2026-05-12
----------------------------

Reduction release: 5994 → 4985 lines. Drops GNU-tool probes, source-mode
scaffolding, ntsync probes, sudo-keepalive, JSONL progress events, log
rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe
gates, and LVM detection. User-bus detection added via
XDG_RUNTIME_DIR/bus plus `systemctl --user is-system-running`.
