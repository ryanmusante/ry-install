ry-install ChangeLog
====================

v7.4.1 - v7.4.2 - 2026-05-19
----------------------------

Audit-driven hardening pass. Three HIGH-severity latent risks closed:
`_ip_probe_sudo_policy` tightens its ALL-grant regex to require an
end-anchor and explicitly skips lines bearing `,\s*!` negation tokens
so a sudoers entry like `(root) NOPASSWD: ALL, !/usr/bin/rm` no
longer passes the unrestricted-grant gate. `_ensure_sudo_cached`
adds `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out so strict-unattended
runs (cron, ansible, systemd unit) refuse the interactive `sudo -v`
fallback. `_csp_filter_rdeps` extends pipestatus inspection from
pactree-only (stage 1) to all four stages so a string-op failure
cannot silently produce a malformed rdep list. Lock acquisition
hardens against PID-recycle: `_acquire_lock` now reads
`/proc/$_stale_pid/comm` and treats `kill -0` success on a non-fish
process as stale-reclaim eligibility. `_acquire_lock_fresh` wraps
`mkdir LOCK_DIR` in `umask 0077` so the lock dir is never
momentarily 0755 between mkdir and chmod. `_dc_kill_children` SIGKILL
grace widens from `$_RY_SLEEP_FRAC` (≤0.1s) to 0.5s so atomic-mv-class
child operations have time to flush. `_cleanup_tmpfiles` adds the
two-step `command -q sudo; and sudo -n true` gate (matching
`_dc_sweep_tmpfiles` at L405) before `sudo find`, preventing noisy
non-cached-sudo invocations. `_log` adds an empty-`LOG_FILE`
early-return so pre-bootstrap callable paths cannot fall through to
`install -m 0600 -- /dev/null ''`. Signal-handler topology
consolidates: `_cleanup_other` is removed, `_cleanup` registers
INT/TERM/HUP/QUIT/USR1/USR2/ABRT directly via seven `--on-signal`
flags on the same function. `_ry_install_file` sudo mkdir adds
explicit `-m 0755` for predictable system-dir mode. Cosmetic:
redundant `2>/dev/null` on numeric `test` invocations removed
(`_vrk_*` dmesg cap line, `_dir_group_or_world_writable`).
`_cleanup_on_exit` and KERNEL_PARAMS validator gain clarifying
comments. README documents `RY_INSTALL_NO_INTERACTIVE_SUDO` in its
runtime-variables section and adds an audit-note to the
sudo-policy preflight description.

v7.4.0 - v7.4.1 - 2026-05-20
----------------------------

Three correctness fixes. The fish-version preflight comparison switches
from a nested `begin ... end` form to a flat `_fish_ok` sentinel so the
"major >= 3 AND (major > 3 OR minor >= 6)" intent is obvious. A new
preflight probe rejects `timeout(1)` builds lacking
`--foreground/--kill-after` (busybox, uutils): `_run`'s hang-protection
path silently passed unsupported flags on such builds. `_vrs_boot_perf`
replaces a fragile `(string match -rg ...)[-1]` negative-index pattern
with an explicit `(count $_tm) -gt 0` guard so an unparseable
`systemd-analyze` first-line cannot silently zero the boot-time
compare. README adds the coreutils ≥ 8.x preflight requirement.

v7.3.9 - v7.4.0 - 2026-05-19
----------------------------

Correctness pass. Critical preflight failures in default QUIET install
mode (sudo, deps, disk, network, config validation) now reach stderr
without `-V`. `_RY_LOUD_ERR` is set on `_install_preflight` entry and
cleared on success; `_err` force-prints via `_msg_print --force` when
set, bypassing QUIET. The sentinel is mode-aware: `--check` retains
silent-probe contract. `_ir_resolve_root_uuid` switches to a four-way
mode dispatch: `install`/`install-file` hard-fail, `verify-static`
hard-fails with a corrected message, `verify-runtime` logs and
continues so UUID-independent probes still run, `check` stays silent.
Argparse-error paths no longer leak orphan `preflight-*.jsonl`:
`_RY_LOG_SUPPRESS_CREATE` short-circuits the lazy-create branch in
`_log` after `_pre_dispatch_log_cleanup`. `_cse_batch_enable` extends
the accept-list to `linked`, `linked-runtime`, `indirect`, `generated`,
`transient`. `_chk_perms` strips the leading setuid/setgid/sticky
digit. `_run_emit_stream` keeps head + tail (cap-100 each) to preserve
build errors at the tail of long pacman/mkinitcpio/paru output.
`_boot_initrd_size_scan` compares in bytes to remove off-by-1MB silent
pass. `_verify_runtime_kparams` extracts preempt / BAR / TSC markers
from the full dmesg buffer before truncating to 5000 lines.

v7.3.8 - v7.3.9 - 2026-05-18
----------------------------

Structural collapse, zero functional change. Nine single-statement
function bodies, sixteen three-line if-end blocks, and ninety-five
four-line if-end blocks collapse to short-circuit chains. Three Class
B sites excluded as status-leak (last statement of caller-status
function); one Class A site excluded as long string-match chain.
Invariants preserved: 253 functions, 15 KERNEL_PARAMS, 11
MKINITCPIO_HOOKS, 12 MASK, 15 PKGS_ADD, 8 PKGS_DEL, 2 AUR_PKGS, 3
EXPECTED_SERVICES, 3 EXPECTED_VULKAN_PKGS, 11 ENV_VARS, 16
SYSCTL_VALUES, 9 LOGIND_IGNORE_KEYS, 14 _RY_POST_HOOKS, 4
_RY_BOOT_CRITICAL_DSTS, 12 managed destinations. 5177 to 4842 lines.

v7.3.7 - v7.3.8 - 2026-05-18
----------------------------

README and CHANGELOG re-styled. Four composite statements split across
continuations. `_ir_resolve_root_uuid` thread a `_reason` string
through the fall-through switch so the diagnostic distinguishes
"findmnt failed" from "invalid UUID shape". `_ry_check_disk_space`
labels switch from `GB`/`MB` to `GiB`/`MiB`. `_vrkg_rebar_sam` lspci
regex broadens to match any G-suffix or M-values ≥ 500.

v7.3.5 - v7.3.6 - 2026-05-17
----------------------------

`_err_loud` becomes log-only when `MODE=check`, preserving the
silence contract. `_ry_show_help` clarifies fish 3.x `--on-signal`
limitation and notes `--check` requirements. `_ry_do_check` collapses
three rc-blocks into a phase-fn-name loop. `_ry_check_network`
replaces `test;and;or` with explicit `if/else`. `_acquire_lock`
stale-pid regex tightens from `^\d+$` to `^[1-9]\d*$`. `_run`
tmpdir-alloc sentinel promoted from magic 251 to named
`EXIT_RUN_TMPFAIL`.

v7.3.0 - v7.3.3 - 2026-05-17
----------------------------

`_ry_check_deps` adds a systemd `<250` hard-fail preflight gate. Log
filename format becomes `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.

v7.2.4 - v7.2.6 - 2026-05-17
----------------------------

`_vre_fstab` unifies noatime/lazytime/commit=10 token tests under
`(^|,)tok(,|$)`. `_ir_validate_counts` adds `_RY_POST_HOOKS:14` and
`_RY_BOOT_CRITICAL_DSTS:4`. `_mr_copy_size_verify` adds `cmp -s` after
size match. README bootloader section: 8 keys to 10; initramfs
ordering invariants 4 to 9 to 11.

v7.2.1 - v7.2.3 - 2026-05-17
----------------------------

`_vmh_order_checks` adds systemd:autodetect, autodetect:microcode
pair rules and an fsck-last invariant. README Configuration expands
from 2 to 19 per-domain collapsibles. Embedded-config count drops
from 13 to 12. `cpupower-epp.service` dropped; `SERVICE_DESTINATIONS`
empty. `_RY_MANAGED_FILE_COUNT` 13 to 12. `EXPECTED_SERVICES` 4 to 3.

v7.1.0 - v7.2.0 - 2026-05-17
----------------------------

New `_ry_apply_wireless_regdom` driven by `RY_INSTALL_WIRELESS_REGDOM`.
`_install_aur_packages` documents benign tokens via `AUR_NOISE_NOTE`.
`/etc/drirc` dropped; `/etc/default/cpupower-service.conf` added.
`PKGS_ADD` gains `cpupower` (14 to 15); `EXPECTED_SERVICES` gains
`cpupower.service`. `_vrk_cpu_state` scaling_governor moves from
`powersave` to `performance`. README gains Strix Halo ACP audio
known-issue and REGDOM env-var row.

v7.0.17 - v7.0.20 - 2026-05-17
------------------------------

`_vrkg_rebar_sam` lspci gains `command` prefix; drops 256M match.
`_RY_DMESG_BAR` drops `above.4g`. `_MY_UID` hoists below early-exit
loop. `_install_aur_packages` sets `_RY_AUR_PARTIAL` only when 0 <
failed < count. `_post_service` adds `systemctl try-restart` after
`enable --now`. `_post_nm` adds `try-restart iwd.service` when
`iwd/main.conf` is the target.

v7.0.11 - v7.0.16 - 2026-05-16
------------------------------

`KVER` switches to `(command uname -r)`. `_enum_boot_entries` gains
pipestatus capture and `_RY_BOOT_ENUM_OK`. `_acquire_lock_fresh`
hoists `_RY_LOCK_DIR_OWNED` above `chmod 700`.
`_vs_read_symmetry_selftest` memoises via `_RY_READSYM_RESULT`.
Pre-bootstrap `command -q date` check. `_ry_check_deps` adds
`date(1)`.

v7.0.7 - v7.0.10 - 2026-05-16
-----------------------------

`_vre_fstab` malformed-line filter becomes
`_RY_AWK_EXT4_MALFORMED_FILTER`. `_vrkm_blacklist` normalizes hyphen
to underscore before `lsmod` compare. README `<details>` blocks switch
to tables for mobile rendering. Sixty-eight bare system-command
invocations gain a `command` prefix.

v7.0 - v7.0.6 - 2026-05-15 to 2026-05-16
----------------------------------------

NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`. MASK
gains `avahi-daemon.service` and `.socket` (10 to 12); new
`_csm_disable_ufw_rules`. `PKGS_ADD` gains `realtime-privileges`;
`PKGS_DEL` gains `bolt`. New `_ry_check_wireless_regdom` and
`_vrk_audio_state`. `RADV_PERFTEST=transfer_queue` becomes
`RADV_EXPERIMENTAL=transfer_queue`. `_vsb_mkinitcpio` amdgpu probe
tightens from `*amdgpu*` to `\bamdgpu\b`. `_ry_check_deps` gains a
GNU-coreutils `df` probe. `HandleSecureAttentionKey` gate tightens
from `<256` to `<257`.

v6.5.13 - v6.5.18 - 2026-05-15
------------------------------

`_rvc_dispatch` adds `*/tmpfiles.d/*` case and `_grep_tmpfiles_entry`.
README tables trimmed. `_installed_bytes` terminal `printf` collapsed.
New `/etc/tmpfiles.d/99-cachyos-thp.conf` managed destination (12 to
13). `_aur_verify_mt7925` asserts both `pacman` and `modinfo` resolve.

v6.5.8 - v6.5.12 - 2026-05-15
-----------------------------

Log-dir mode probe extended to three managed paths. `_awf_finalize_mv`
sudo-lapse returns `$EXIT_FAIL`. `_ry_exit` bail path writes the JSONL
footer. `_cleanup_pipe` SIGPIPE log gated on `_RY_HEADER_WRITTEN`.
`_vrs_installed_file_perms` emits a `perm_vfat_skipped` count.

v6.5 - v6.5.7 - 2026-05-14
--------------------------

`_dc_sweep_tmpfiles` spurious `TMPFILE_STUCK` fix.
`_verify_static_services` multi-`ExecStart` guard. `_err_loud`
deduplicated via `_msg_print --force`. `_vsb_entries` distinguishes
lapsed-sudo from empty entries dir. `_ry_check_deps` adds 10 coreutils.
`_chk_grep` stage-2 switches to `grep -wF`. `KERNEL_PARAMS` metachar
regex backslash escaping tightened.

v6.2.9 - v6.2.13 - 2026-05-13 to 2026-05-14
-------------------------------------------

HOME field-6 captured via `awk -F:` (GECOS-tolerant). `_ry_check_deps`
adds `mv`, `grep`. `pacman -Qq` and `-T` status captured. JSONL header
written before `_init_runtime`. `LOCK_DIR` gains `chmod 700`. Emit
functions use `printf` (flag-injection guard). `_run` split into
`_run`, `_run_redact_cmd`, `_run_effective_timeout`.

v6.2.4 - v6.2.8 - 2026-05-13
----------------------------

`_run` timeout-bypass for `pacman`, `paru`, `mkinitcpio`,
`sdboot-manage`, `paccache`. Tmpfile-path redaction under `$TMPDIR`.
`_ip_pacman_invoke` `-Syyu` retry gated on
`RY_INSTALL_ALLOW_PARTIAL_UPGRADE`. Per-package AUR retry. `_vrkg_*`
GPU runtime checks. `_atomic_write_file` post-write symlink re-check
(TOCTOU). `_fstab_atomic_replace` `findmnt --verify` hard-fail. User
destinations install with `0600`. Capture cap raised from 100 to 500.

v6.2.0 - v6.2.3 - 2026-05-12 to 2026-05-13
------------------------------------------

`--install-file`: single-file redeploy with per-target post-hook
dispatch. argparse `--exclusive` mode group. Atomic `mkdir` + pid-file
lock. `_ir_validate_counts` enforces array-count invariants.
`_RY_POST_HOOKS` is a first-match table for `--install-file` hooks.

v6.0.0 - v6.1.0 - 2026-05-12
----------------------------

Reduction release 5994 to 4985 lines: drops GNU-tool probes,
source-mode scaffolding, ntsync probes, sudo-keepalive, JSONL progress
events, log rotation, parallel-child PID guard, atomic-write TOCTOU
re-stat, boot-wipe gates, LVM detection. User-bus detection added via
`XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`.
