ry-install ChangeLog
====================

v7.3.7 - v7.3.8 - 2026-05-18
----------------------------

Synchronization and readability pass. README and CHANGELOG re-styled;
CHANGELOG converted to kernel.org-style flowing prose. Four long-line
composite statements split across continuations: the printf body of
`_content__etc_sdboot-manage.conf` (392 chars to 9 lines),
`_content__etc_mkinitcpio.conf` (288 chars to 8 lines), the noise-note
rationale in `_install_aur_packages` (one long `_log` to four shorter
`AUR_NOISE_NOTE` and `AUR_NOISE_NOTE_TOKEN` entries), and the
`_RY_POST_HOOKS` table (one entry per line). The `_ir_resolve_root_uuid`
path no longer emits two error messages on a shape-invalid UUID; a single
`_reason` string threads through the fall-through switch so the surfaced
diagnostic distinguishes "findmnt failed" from "invalid UUID shape".
`_ry_check_disk_space` labels `GB`/`MB` reworded to `GiB`/`MiB` (numeric
thresholds unchanged); README "Free space" row updated to match. The
`_vrkg_rebar_sam` lspci probe regex broadened to match any G-suffix BAR
size or M-values 500 and above (covers 512/1024/2048/4096/8192M); the
previous regex hard-coded only 512M. Two over-long inline rationale
comments trimmed. Version bumped 7.3.6 to 7.3.8; 5146 to 5177 lines.

v7.3.5 - v7.3.6 - 2026-05-17
----------------------------

`_err_loud` becomes log-only when `MODE=check`, preserving the `--check`
silence contract. `_ry_show_help` exit-codes section reworded to clarify
the fish 3.x `--on-signal` limitation, and `--check` annotated as requiring
functional sudo and systemctl. `_ry_do_check` collapses three rc-blocks
into a phase-fn-name for-loop. `_install_rebuild_boot` rewords its
boot-taint message to "intra-process flag". `_ry_check_network` replaces
`test;and;or` with explicit `if/else`. Four `echo` sites in `_resolve_esp`
and `_resolve_boot_path` switch to `printf %s` for symmetry.
`_acquire_lock` stale-pid regex tightens from `^\d+$` to `^[1-9]\d*$`,
rejecting pid=0. Bootstrap chmod plus perm-verify merges into a
single-pass loop. Five `string join` call sites gain explicit `--`
separators for argv consistency. The `_run` tmpdir-alloc failure sentinel
is promoted from magic 251 to a named `EXIT_RUN_TMPFAIL` constant.
`_idf_match_dst` gains inline rationale on canon-list index alignment.
5136 to 5146 lines.

v7.3.0 - v7.3.3 - 2026-05-17
----------------------------

`_ry_check_deps` adds a systemd less-than-250 hard-fail as a preflight
gate. Log filename format becomes `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.
Six standalone rationale comments inlined at their referent sites. README
install-flow Phase 1, 4, 5, and 6 prose tightened.

v7.2.4 - v7.2.6 - 2026-05-17
----------------------------

`_vre_fstab` unifies the noatime, lazytime, and commit=10 token tests
under the single regex `(^|,)tok(,|$)`. `_ir_validate_counts` adds
`_RY_POST_HOOKS:14` and `_RY_BOOT_CRITICAL_DSTS:4` for a 15-invariant
total. `_mr_copy_size_verify` gains a `cmp -s` byte-content verify after
the size match. `_dc_erase_globals` adds `_RY_BOOT_TAINTED` for symmetry.
`_verify_static_syntax` passes an explicit system scope argument.
`_ip_snapshot_mkinitcpio` drops a redundant `chmod 600`. README bootloader
section grows from 8 keys to 10 (4 loader.conf plus 6 sdboot-manage.conf).
README initramfs ordering invariants expand from 4 to 9. README
install-flow Phase 4 entry adds fstab ext4 opts and PKGS_DEL removal.
`_ry_show_help` exit-codes: rc=1 now covers the old-kernel warn path.
`_dc_kill_children` description updated to match `pkill -P` semantics
(parent reap, not process group). README install-flow Phase 2 gains
`updatedb` plus `pkgfile --update` cache refresh. README initramfs section
expands from 9 ordering invariants to 11 hook invariants. Documentation
refresh. 5138 to 5139 lines.

v7.2.1 - v7.2.3 - 2026-05-17
----------------------------

`_vmh_order_checks` adds two pair rules (systemd:autodetect,
autodetect:microcode) and an fsck-last invariant. `_msg_print` color
branch switches from `echo` to `printf`. `_vrs_boot_perf` cleans up
adjacent-quote string concatenation. README Configuration section expands
from 2 collapsibles to 19 per-domain collapsibles. Embedded-config count
drops from 13 to 12. README Quick Start admonitions tightened.
`cpupower-epp.service` dropped; `SERVICE_DESTINATIONS` is now empty.
`_RY_MANAGED_FILE_COUNT` drops 13 to 12 and `EXPECTED_SERVICES` drops 4 to
3. Removed: `_content__etc_systemd_system_cpupower-epp.service` and
`_vrsv_chk_cpupower`. `_vrsv_sys_units` shrinks from a 6-unit batch to 5.
Service-related blocks now gate on `$SERVICE_DESTINATIONS` count. 5185 to
5138 lines.

v7.2.0 - 2026-05-17
-------------------

`/etc/drirc` dropped. `/etc/default/cpupower-service.conf` added with
`governor='performance'`. `PKGS_ADD` gains `cpupower` (14 to 15);
`EXPECTED_SERVICES` gains `cpupower.service` (3 to 4). `_RY_POST_HOOKS`
replaces the drirc entry with cpupower-service; new `_post_cpupower`
handler. `_vrk_cpu_state` scaling_governor expectation moves from
`powersave` to `performance`. `_vrsv_sys_units` grows from a 5-unit batch
to 6, gaining `cpupower.service`; new `_vrsv_chk_cpupower_governor`.
`_verify_static_system` drops `_vss_drirc_sysctl` and adds a
cpupower-service.conf grep. `_rvc_dispatch` drops the drirc XML case and
adds cpupower-service.conf as a no-validation case. Removed:
`_content__etc_drirc`, `_grep_xml_tag`, `_post_drirc`. 5181 to 5185 lines.

v7.1.0 - v7.1.2 - 2026-05-17
----------------------------

New function `_ry_apply_wireless_regdom`, driven by
`RY_INSTALL_WIRELESS_REGDOM=<CC>`. The function downgrades rc=1 to a soft
warn (only `EXIT_USAGE` aborts preflight), tees stderr to a tmpfile,
applies `string trim` before `string upper`, and logs result as
`REGDOM_SET_FAIL`. `_install_preflight` captures the apply-regdom status.
`_ry_check_wireless_regdom` hint anchor moves from Environment to Runtime
variables. `_csp_filter_rdeps` demotes per-package WARN to INFO and
aggregates at phase end. `_if_nm_restart` and `_post_nm` collapse multiple
WARNs to one WARN plus one INFO. `_install_aur_packages` documents benign
tokens via `AUR_NOISE_NOTE`. `_vrkg_vram` warns and points to README
Hardware UMA; switches `math` to `math --scale=0`. `_acquire_lock` gains
`--` separators at two `command cat` sites. `_msg_print` no-color and
no-tty branches switch from `echo` to `printf`.
`_vs_read_symmetry_selftest` reads the fish version from `$FISH_VERSION`,
dropping a `fish` fork. README gains the Strix Halo ACP audio known-issue
and a REGDOM env-var row. 5127 to 5181 lines.

v7.0.17 - v7.0.20 - 2026-05-17
------------------------------

`_vrkg_rebar_sam` lspci call gains `command` prefix; drops the 256M lspci
regex match. `_RY_DMESG_BAR` drops `above.4g` from its grep.
`_vs_read_symmetry_selftest` invokes `command fish` rather than a bare
`fish`. Fourteen one-line rationale comments added. `_MY_UID` hoists below
the early-exit loop. `_dc_sweep_filesystem` gates on `functions -q
_tmp_dir`. `_vmh_order_checks` empty-hooks branch becomes an explicit
`if/end`. `_install_aur_packages` sets `_RY_AUR_PARTIAL` only when 0 less
than failed less than count. `_post_service` adds `systemctl try-restart`
after `enable --now`. `_post_nm` adds `try-restart iwd.service` when iwd
`main.conf` is the target. `_ry_show_help -V` description clarified.
`_run` TIMEOUT_TERM and TIMEOUT_KILL log strings tidied.
`_verify_static_checksum` calls `_gen_rc` before `_installed_bytes`. 5100
to 5127 lines.

v7.0.11 - v7.0.16 - 2026-05-16
------------------------------

KVER capture switches from a bare `(uname -r)` to `(command uname -r)`.
Four two-line rationale blocks collapsed to one line each. Header version
sync; README badge bump. `_enum_boot_entries` gains pipestatus capture and
a `_RY_BOOT_ENUM_OK` sentinel. `_acquire_lock_fresh` hoists
`_RY_LOCK_DIR_OWNED` above the `chmod 700`. `_vs_read_symmetry_selftest`
memoises its result in `_RY_READSYM_RESULT`. Pre-bootstrap `command -q
date` check. Help text `-V` clarified. `_ry_check_deps` adds `date(1)`.
`_log_section` description corrected. `_ry_do_check` calls `_log_section`
at all return paths. 5064 to 5104 lines.

v7.0.7 - v7.0.10 - 2026-05-16
-----------------------------

`_vre_fstab` malformed-line filter becomes `_RY_AWK_EXT4_MALFORMED_FILTER`.
`_vrkm_blacklist` normalizes hyphen to underscore before `lsmod` compare.
`EXIT_GEN_NOFN`, `EXIT_GEN_NOUUID`, and `EXIT_GEN_SYSCTL` gain inline
rationale. `_ensure_sudo_cached` description reworded. README `<details>`
blocks switch to tables for mobile rendering. Sixty-eight bare
system-command invocations gain a `command` prefix. 5054 to 5064 lines.

v7.0.4 - v7.0.6 - 2026-05-16
----------------------------

`_ry_check_wireless_regdom` regex requires a 2-letter ISO 3166-1 code.
`_post_hook_for_target` uses `string split -r -m1 '|'`. `_unit_state`
drops a redundant `string split \n`. `_RY_POST_HOOKS` adds
`*/tmpfiles.d/*|tmpfiles` and a new `_post_tmpfiles` handler.
`_ensure_sudo_cached` gains a stderr redirect on retry.
`HandleSecureAttentionKey` systemd-version gate tightens from less-than-256
to less-than-257. `_aur_verify_mt7925` hoists the `pacman -Q | awk`
pipeline out of the `_warn` call. `_install_rebuild_boot` hoists
`_resolve_boot_path` to a single call. `_is_wifi_active_route` glob set
switches from `br*` to `br[0-9]*` and `br-*`. `_awf_finalize_mv`
sudo-lapse returns a literal `1`. 5041 to 5060 lines.

v7.0 - 2026-05-15
-----------------

NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`. `MASK`
gains `avahi-daemon.service` and `avahi-daemon.socket` (10 to 12); new
`_csm_disable_ufw_rules`. `PKGS_ADD` gains `realtime-privileges` (13 to
14); `PKGS_DEL` gains `bolt` (7 to 8). New `_ry_check_wireless_regdom` and
`_vrk_audio_state`. `RADV_PERFTEST=transfer_queue` becomes
`RADV_EXPERIMENTAL=transfer_queue`. `_ok`, `_fail`, `_warn`, `_info`,
`_err`, and `_fail_silent` gain explicit `return 0`. `_vsb_mkinitcpio`
amdgpu probe tightens from `*amdgpu*` to `\bamdgpu\b`. `_ry_check_deps`
gains a GNU-coreutils `df` probe. 117 inter-function blank lines
collapsed. `_ir_validate_counts` synced. 5092 to 5041 lines.

v6.5.13 - v6.5.18 - 2026-05-15
------------------------------

`_rvc_dispatch` adds `*/tmpfiles.d/*` case and `_grep_tmpfiles_entry`.
README tables trimmed. Profile-highlight matrix collapsed. `_msg_print`
argv mutation removed. Single-line rationale at four dynamic-dispatch
sites. Single-line rationale at three regression-prone sites.
`_installed_bytes` terminal `printf` collapsed. New
`/etc/tmpfiles.d/99-cachyos-thp.conf` managed destination (12 to 13).
`_aur_verify_mt7925` asserts both `pacman` and `modinfo` resolve. Comments
trimmed to single-line rationale. 5005 to 5092 lines.

v6.5.8 - v6.5.12 - 2026-05-15
-----------------------------

Log-dir mode probe extended to three managed paths. `_awf_finalize_mv`
sudo-lapse returns `$EXIT_FAIL`. Unknown-MODE fallback via `_msg_print
--force`. `_ry_exit` bail path writes the JSONL footer. `_cleanup_pipe`
SIGPIPE log gated on `_RY_HEADER_WRITTEN`. `_enum_boot_entries` drops
write-only globals. `_verify_unit_syntax` collapses a branch.
`_verify_unit_syntax` log joins multi-line stderr.
`_vrs_installed_file_perms` emits a `perm_vfat_skipped` count. Top-level
dispatcher pre-header `_warn` becomes a direct `echo >&2`.

v6.5 - v6.5.7 - 2026-05-14
--------------------------

`_dc_sweep_tmpfiles` spurious `TMPFILE_STUCK` fix.
`_verify_static_services` multi-`ExecStart` guard. Fourteen `head` and
`tail` sites use the `command` prefix. `_dc_sweep_tmpfiles` logs
`TMPFILE_STUCK` before erase. `_err_loud` deduplicated via `_msg_print
--force`. `_vsb_entries` distinguishes lapsed-sudo from empty entries dir.
`_ry_check_deps` adds 10 coreutils. `_chk_grep` stage-2 switches to `grep
-wF`. `_msg` drops the `VERIFY_MODE` gate. `KERNEL_PARAMS` metachar regex
source backslash escaping tightened. Ninety-three `string match -qr`
patterns swept.

v6.2.9 - v6.2.13 - 2026-05-13 to 2026-05-14
-------------------------------------------

HOME field-6 captured via `awk -F:` (GECOS-tolerant). `_ry_check_deps`
adds `mv`. `_ry_check_deps` adds `grep`. `pacman -Qq` and `-T` status
captured. Dmesg-slice precomputed. `_csp_filter_rdeps` pipestatus gate
narrowed. JSONL header written before `_init_runtime`. `LOCK_DIR` gains
`chmod 700`. Content-equality compare via `string collect`. Emit functions
use `printf` (flag-injection guard). `_run` split into `_run`,
`_run_redact_cmd`, and `_run_effective_timeout`. 5054 to 5008 lines.

v6.2.4 - v6.2.8 - 2026-05-13
----------------------------

`_run` timeout-bypass for `pacman`, `paru`, `mkinitcpio`, `sdboot-manage`,
and `paccache`. Tmpfile-path redaction under `$TMPDIR`.
`_ip_pacman_invoke` `-Syyu` retry gated on
`RY_INSTALL_ALLOW_PARTIAL_UPGRADE`. Per-package AUR retry. `_vrkg_*` GPU
runtime checks. `_atomic_write_file` post-write symlink re-check (TOCTOU).
`_fstab_atomic_replace` `findmnt --verify` hard-fail. User destinations
install with `0600`. `_run` sudo-bypass scans for dash flags. Capture cap
raised from 100 to 500 with `_TRUNCATED` sentinels. Log rename and
`_acquire_lock` move before the JSONL header. `_install_preflight`
early-returns set `_PROG_FINALIZED_SKIP`.

v6.2.0 - v6.2.3 - 2026-05-12 to 2026-05-13
------------------------------------------

`--install-file`: single-file redeploy with per-target post-hook dispatch.
argparse `--exclusive` mode group. Atomic `mkdir` plus pid-file lock.
`_ir_validate_counts` enforces array-count invariants. `_RY_POST_HOOKS` is
a first-match table for `--install-file` hooks. Top-level array
declarations: one element per continuation line. `_pbs_check_boot_files`
snapshots `$pipestatus` before `_pipe_all_ok`.

v6.1.0 - 2026-05-12
-------------------

User-bus detection via inline `XDG_RUNTIME_DIR/bus` plus `systemctl --user
is-system-running`.

v6.0.0 - 2026-05-12
-------------------

Reduction release 5994 to 4985 lines: drops GNU-tool probes, source-mode
scaffolding, ntsync probes, sudo-keepalive, JSONL progress events, log
rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe
gates, and LVM detection.
