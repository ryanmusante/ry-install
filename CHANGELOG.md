ry-install ChangeLog
====================

v7.4.55 - v7.4.56 - 2026-05-23
------------------------------

- README Configuration section: wrap the 6 previously-bare per-phase
  Step tables in `<details>` collapsibles so every table in the
  Configuration section is collapsible-to-table uniformly. Affected:
  - `Phase 1 — Preflight` → `<summary><b>Preflight steps</b> — 10 steps</summary>`
  - `Phase 2 — Packages` → `<summary><b>Phase steps</b> — 4 steps</summary>`
  - `Phase 3 — Configuration Files` → `<summary><b>Atomic-write sequence</b> — 4 steps</summary>`
  - `Phase 4 — Services` → `<summary><b>Phase steps</b> — 6 steps</summary>`
  - `Phase 5 — Boot` → `<summary><b>Boot steps</b> — 4 steps</summary>`
  - `Phase 6 — Finalize` → `<summary><b>Finalize steps</b> — 4 steps</summary>`
  Phase intro prose (e.g. Phase 3 "11 system + 1 user config file
  deployed via atomic writes") kept outside the collapsible so the
  context lead stays visible. Phase 4's "fstab rewrite normalizes the
  field separator" blockquote also kept outside. Configuration section
  now has 25 collapsibles total (6 new + 19 existing), all
  collapsible-to-table.
- Script: no functional changes. Version bump only.

v7.4.54 - v7.4.55 - 2026-05-23
------------------------------

- README Configuration section: convert all 9 non-table collapsibles to
  uniform Markdown tables. Affected:
  - Phase 2: `Packages — install` (inline `·` list → 15-row `Package |
    Purpose` table), `Packages — AUR` (→ 2-row table with terse purpose),
    `Vulkan dependencies` (→ 3-row `Package | Source` table).
  - Phase 3: `Kernel cmdline` (code block → 15-row `Param | Value` table
    matching pre-v7.4.54 form), `systemd-logind` (bullets → 9-row
    `Key | Value` table; all values `ignore`), `cpupower-service` (bullet
    → 1-row `Key | Value` table), `tmpfiles` (bullet → 1-row
    `Type | Path | Mode` table).
  - Phase 4: `fstab` (inline `·` list → 3-row `Option | Effect` table),
    `Packages — remove` (grouped bullets → 11-row `Package | Category`
    table), `Masked units` (grouped bullets → 12-row `Unit | Reason`
    table).
  - Already-table collapsibles untouched: `Package caveats`,
    `Bootloader`, `Initramfs`, `systemd-resolved`, `iwd`,
    `NetworkManager`, `sysctl`, `Env vars`, `Enabled units`.
  All array counts in `<summary>` tags still match script invariants
  (15/2/3/15/9/1/1/3/11/12). Every package, parameter, key, unit, and
  path preserved.
- Script: no functional changes. Version bump only.

v7.4.53 - v7.4.54 - 2026-05-23
------------------------------

- README: trim verbose tables to vital information only. Net 678 → 623
  lines (−55, −8.1%). Table-row count 319 → 241 (−78, −24.4%). No
  semantic loss: every value, count, path, key, command, version-floor,
  and discriminative detail preserved. Trimmed surfaces:
  - Phase 1 preflight: dropped restated function-name parentheticals;
    Action col now carries only the criteria/constants.
  - Packages — install (15 pkgs): table → inline `·`-separated list.
    Purpose col removed (each package name is self-documenting; install
    command preserved in summary).
  - Packages — AUR / Vulkan: same inline-list collapse.
  - Kernel cmdline (15 params): table → compact 4-line code block.
    Deployed-prefix note kept inline.
  - Packages — remove (11 pkgs): table → grouped inline lists (boot
    splash · Thunderbolt · replaced/unused). Plasma-rdep rationale kept
    as one trailing sentence.
  - Masked units (12): table → grouped inline lists (suspend targets ·
    replaced/unused). `ufw disable` rationale kept inline.
  - fstab options: 3-row table → inline `·`-separated list + rewrite
    rules.
  - Managed Files destinations (12 paths): table → bulleted list with
    perm rule stated once in summary (system 0644, user 0600).
  - Safety & Reliability: condensed Detail cells; kept all flags/gates.
  - Runtime variables: `RY_INSTALL_WIRELESS_REGDOM` persist recipe moved
    to trailing paragraph (kept verbatim).
  - Logs: `ERR_NO_DATA` and `gen_fail` cells condensed to one sentence
    each; semantics preserved.
- Script: no functional changes. Version bump only (header banner +
  `VERSION` literal). LOC unchanged at 4771.

v7.4.52 - v7.4.53 - 2026-05-23
------------------------------

- `_verify_static_checksum`: extract per-destination loop body into
  `_vsc_check_one` helper (function split mirrors v7.4.5→22 ≤50-LOC
  pattern: `_install_preflight` → `_ip_record_regdom`,
  `_install_aur_packages` → `_iap_per_pkg_retry`, etc.).
  `_verify_static_checksum` body collapses from 55 LOC to 9 LOC;
  `_vsc_check_one` is 40 LOC; behaviour byte-identical (continue → return 0
  inside the new helper, all _phase_record / _log / _fail_silent /
  VERIFY_GEN_FAIL / VERIFY_FAIL bumps preserved). Net LOC 4777 → 4771.
- README Phase 1 row 9: enumerate `_ry_check_wireless_regdom` alongside
  `_ry_apply_wireless_regdom` — the check runs unconditionally after apply
  and warns when `/etc/conf.d/wireless-regdom` is missing or contains no
  valid 2-letter ISO 3166-1 code, since `set-wireless-regdom` silently
  skips `iw reg set` in that case (cfg80211 stays in `world` domain on
  every boot). Step count remains 10 — verify is the second half of step
  9, not an 11th step.
- CHANGELOG: this entry is the audit-fix bundle for v7.4.52 (no behaviour
  changes; documentation accuracy + function-size discipline only).
  Cumulative LOC since v7.4.34 baseline: 4468 → 4771 (+303 across
  v7.4.34→53).
- README badge: `7.4.52` → `7.4.53`.

v7.4.51 - v7.4.52 - 2026-05-23
------------------------------

- `_rrp_optional_indexer`: `flag` no longer a named third argument; helper now
  captures the optional flag via `set -l flag $argv[3..-1]`. Fish list
  expansion of an empty list emits nothing, so `sudo -n updatedb ""` (which
  mlocate/plocate rejects with "unexpected operand on command line") is no
  longer produced. Caller at the `updatedb` site drops the trailing `""`; the
  `pkgfile --update` caller is unchanged and remains a regression guard for
  non-empty flag propagation.
- `PKGS_DEL`: append `breeze-plymouth`, `plymouth-kcm`, `plasma-thunderbolt`
  to enumerate the Plasma-side hard reverse-dependents that previously held
  `plymouth` and `bolt` and caused `pacman -R` to refuse removal. Sources:
  `extra/breeze-plymouth` PKGBUILD `depends=(glibc plymouth)`,
  `extra/plymouth-kcm` PKGBUILD `depends=(… plymouth …)`,
  `extra/plasma-thunderbolt` package page `depends: bolt …`. With these
  enumerated, the rdep-skip path (`_csp_filter_rdeps`) no longer triggers
  for `plymouth` / `bolt` on a stock CachyOS-KDE profile, and the
  `verify-static` still-installed check passes without operator opt-in to
  `RY_INSTALL_PKG_REMOVE_CASCADE=1`.
- Self-consistency: `_install_preflight` count-drift assertion `PKGS_DEL:8`
  bumped to `PKGS_DEL:11` to match the expanded list (script refuses to
  deploy on mismatch — README/script desync guard).
- README Configuration "Reverse deps" cell: note that `breeze-plymouth`,
  `plymouth-kcm`, and `plasma-thunderbolt` are now enumerated in `PKGS_DEL`
  so cascade is rarely needed in practice; cascade env-var semantics
  unchanged.
- README Packages-remove summary: count `8 pkgs` → `11 pkgs`; `plymouth` row
  parenthetical extended with `breeze-plymouth` + `plymouth-kcm`; `bolt`
  row parenthetical extended with `plasma-thunderbolt`. Each addition
  annotated with its source PKGBUILD `depends=` relationship.
- README Runtime variables `RY_INSTALL_WIRELESS_REGDOM` row: extended with
  persistent-config recipe in `~/.config/fish/conf.d/ry-install-env.fish`
  (`set -gx RY_INSTALL_WIRELESS_REGDOM US`), since a stale
  `/etc/conf.d/wireless-regdom` with no valid value silently disables
  `iw reg set` on every boot.
- README badge: `7.4.51` → `7.4.52`.

v7.4.50 - v7.4.51 - 2026-05-23
------------------------------

- Uninstall steps 1-4: prefix system commands with `sudo`.
- Uninstall step 5 + Known Issues NM+iwd row: bash `&&` → fish `; and`.
- Quick Start preflight: drop redundant standalone `sudo -v` (`_ensure_sudo_cached` primes internally).
- Hardware override + Troubleshooting `PKGS_DEL` cells: show env-var with full `./ry-install.fish` invocation.
- Troubleshooting `set-wireless-regdom` cell: cross-reference `RY_INSTALL_WIRELESS_REGDOM`; manual `tee` kept as fallback.
- Prerequisites WARNING callout: replace prose with three concrete recipes (`visudo` timeout, fish keepalive loop, drop-in path).
- Logs prune cell: `find -delete` → `find -print -delete`.
- Known Issues MES page faults: concrete `paru -S amdgpu-dkms-firmware` / `IgnorePkg` commands.
- Known Issues ROCm VRAM: append `sudo pacman -Syu linux-cachyos` upgrade command.
- Troubleshooting kernel 6.19.0 black screen: explicit upgrade + downgrade commands.
- Package caveats + Known Issues PGP cells: pin `--keyserver hkps://keyserver.ubuntu.com`.
- Troubleshooting PipeWire row: `gpasswd -a` → `usermod -aG` (preserves other groups).
- Troubleshooting sudo-expired cell: drop `sudo -v; and ./ry-install.fish` chain; bare `./ry-install.fish` suffices.

v7.4.49 - v7.4.50 - 2026-05-23
------------------------------

- `_ry_show_help` Log path: `+ZZZZ` → `±ZZZZ` to match `date '+%z'` ±HHMM output.
- `_ry_show_help` signal-caveat: drop stale `3.x` qualifier (script accepts fish ≥3.6).
- `_vrkg_vram`: VRAM-carveout warn replaces removed-section README cross-reference with inline BIOS setting name (`UMA Frame Buffer Size` / iGPU Memory / Shared Video Memory).
- README Usage table: `-V, --verbose` description aligned with `--check` silent-probe contract (drops `-V`).
- README Runtime variables: `RY_RUN_TIMEOUT` bypass list extended to include db-indexer ops (updatedb, pkgfile).
- README Logs `<details>` summary: `5 properties` → `7 properties` (post-v7.4.47→48 row count).

v7.4.48 - v7.4.49 - 2026-05-23
------------------------------

- `_ry_show_help` `RY_INSTALL_NO_MATRIX` label: `=1` → `(any non-empty)` to match `_rdi_render_matrix` gate.
- `_content__etc_systemd_logind` + `_vss_logind`: HSAK <257 skip rewritten as explicit nested `if` (semantics unchanged).
- `_verify_static_checksum`: split gen-stage and ib-stage `string collect` failure single-liners into multi-line `if ... end` (≤220 chars/line).
- `_install_preflight` 3-check loop: inline-comment `_i` advance asymmetry between PASS/FAIL branches.
- Collapse adjacent comments at `_RY_DEPLOY_CHANGED_COUNT` / `_PROFILE_USES_WIFI_BACKEND` declarations to single line.
- README Logs events row: footer field list enumerated; note `ts`/`event` common to all events.

v7.4.47 - v7.4.48 - 2026-05-23
------------------------------

- Kernel <6.14 hard-floor: `_ry_check_kernel_version` emits `_err` (was `_warn`) to match matrix FAIL + exit 1 contract; named return codes `RC_KVER_OK`/`RC_KVER_WARN`/`RC_KVER_FAIL` replace literal 0/1/2 in body and Phase 1 dispatch; 6.19.0 patch test switched to `_kver_below` for consistency.
- Signal-arrival race closures: `_acquire_lock_fresh` sets `_RY_LOCK_DIR_OWNED` sentinel before `mkdir` (erased on failure); new `_set_exit` helper keeps `_RY_EXIT_CODE` and `_INTENDED_EXIT_CODE` in sync across mode dispatch and `_write_footer`; `_write_footer` guard flattened to `test ... ;or return 0`; `_cleanup` adds `case '*'` for unknown signals (`CLEANUP_UNKNOWN_SIGNAL` log).
- `_phase_record` consistency: `_install_finalize` (`systemctl --user daemon-reload` failure), `_configure_services_resolved_restart`, `_configure_services_thp_apply`, and `_cse_collect_units` (daemon-reload failure) now emit `_phase_record` on both branches and set `INSTALL_HAD_ERRORS` on operational failure (were silent or WARN-only).
- `_post_*` rc propagation: `_post_service` propagates `systemctl try-restart` rc; `_post_resolved`, `_post_sysctl`, `_post_tmpfiles`, `_post_cpupower` return 1 on operational failure (were silent-pass); `_post_nm` aggregates iwd try-restart + NetworkManager restart rcs into `$_post_nm_rc`; `_post_envd` appends `systemctl --user import-environment` live-apply hint.
- Tmpfile relocation: `_mkinitcpio_revert`, mkinitcpio snapshot, and `_fstab_atomic_replace` move tmpfile creation from `/etc` to `/run/ry-install` (root-owned 0700, cleared on reboot).
- AWK pipeline hardening (`_far_*`): consolidate to single sudo-awk pipeline (split-privilege awk-then-tee branch removed); `_far_build_awk_script` skips empty tokens (`if (o == "") continue` — malformed `opt1,,opt2` no longer survives); size floor derives 25%-of-input lower bound (absolute floor 20 bytes); `_awf_render_to_tmp` captures tee stderr to tracked tmpfile for ENOSPC/EIO visibility.
- Verify-path symmetry: `_verify_static_services` refactored to `_unit_state_padded`; `_vss_ntsync_modules` case order aligned with `_vre_ntsync` (observed-state-first); `_vre_zram` extracts device via `string match -rg` and refactors 5-way state branching from if-elif to `switch`; `_vs_read_symmetry_selftest` emits WARN + `_phase_record` SKIP + bumps `VERIFY_WARN` when mktemp returns no path (was silent pass); `_verify_static_checksum` checks `pipestatus[2]` at gen and read stages.
- Input validation: `--install-file` rejects embedded-newline paths and caps at PATH_MAX (4096); `_csp_filter_rdeps` splits pactree filter regex into separate empty-line + self-pkg filters with widened 5-stage `_ps` check; realtime group check uses `id -Gn | string split | contains` (was `\brealtime\b` regex); `_ry_check_deps` adds paru minimum-version probe (recommend ≥ 2.0.0); `_vsb_sdboot` LINUX_OPTIONS regex replaces `\x22` hex escapes with literal `"` inside single-quoted regex; `_teardown` numeric-validates `argv[2]` before `_write_footer` printf `%d`.
- Logging: log rename gains `cp -p` + `rm` fallback when `mv` fails (preserves preflight JSONL content under final filename); `[i] Log file:` end-of-run line guarded by `not set -q _RY_LOG_WRITE_FAIL`; `--check` with `-V`/`--verbose` logs `CHECK_VERBOSE_IGNORED` to JSONL (silent-probe contract preserved on stdout); log-rename `[WARN]` site comment explains stderr-only intent (LOG_FILE mid-rename) and sets `_RY_LOG_WRITE_FAIL` for downstream visibility.
- Lifted globals: canonical 6-phase list to `_RY_PHASE_NAMES` (consumed by progress + matrix; matches README Install Flow); ntsync autoload path to `_RY_NTSYNC_MODLOAD_CONF`; `PACTREE_TIMEOUT_S=60` lifted to top-level constant (decoupled from `RY_RUN_TIMEOUT`).
- Misc: `_run_resolve_timeout` returns `0` instead of empty string for disable case (aligns with `RY_RUN_TIMEOUT=0` semantic); `RY_INSTALL_NO_MATRIX` accepts any non-empty value (no-color.org convention); progress bar cursor save/restore switched from DEC-private `\e7`/`\e8` to ANSI standard `\e[s`/`\e[u`; PATH-dedup loop and `TIMESTAMP` construction refactored for readability.
- README sync: Logs section documents `ERR_NO_DATA`, `gen_fail` rc-flip, and `±ZZZZ` timezone-sign; verdict table footnote that `DEFER`/`SKIP`/`N/A` are informational and do not affect verdict; boot-rebuild gate distinguishes taint flag (FORCE-bypassable) from revert-failed flag (unconditionally refused); env-vars table notes `NO_MATRIX=<any non-empty>`; Phase 2 sub-table adds `updatedb` and `pkgfile --update` indexer rows; Troubleshooting adds kernel 6.19.0 black-screen + iwd `main.conf`-startup-only caveats; recovery idempotency caveat (boot-taint per-process), `rw root=UUID=` cmdline prefix note, environment.d `systemctl --user import-environment` alternative, fstab `OFS=" "` normalization note added; CHANGELOG v7.4.44→45 entry corrects step count from "9 preflight steps" to "10".

v7.4.46 - v7.4.47 - 2026-05-23
------------------------------

- Phase 1 + Phase 2 sub-tables: add leading `#` column (`# | Step | Action`) so step numbering is consistent across all six phase tables (Phases 3-6 already had `# | Step`); parallels the parent Install Flow table `# | Phase | Action`.

v7.4.45 - v7.4.46 - 2026-05-23
------------------------------

- Remove redundant `[!IMPORTANT]` callout from Quick Start (duplicated Phase 5 verbatim); Phase 5 paragraph is the canonical location.
- Trim iwd `<details>` skip note (covered canonically in Managed Files preamble; internal `_RY_SKIP_IWD` var name is implementation detail).

v7.4.44 - v7.4.45 - 2026-05-23
------------------------------

- Phase 1: enumerate all 10 preflight steps in actual runtime order (Bootstrap → `_init_runtime` invariants → lock → sudo cache → deps → disk → network → kernel → wireless regdom → config validation); move `EXPECTED_CPU_MATCH` attribution to `_init_runtime` row.
- Phase 5: add post-rebuild sanity row (vmlinuz + initramfs + loader-entry kernel-path verify).
- Exit codes row `1`: drop stale "old-kernel warn" phrase; kernel <6.14 is matrix FAIL (per v7.4.5→22 hard-floor flip), kernel WARN paths do not trigger exit 1.
- Hardware section: clarify CPU check runs in `_init_runtime` on every mode (not install-only preflight).
- `_ry_show_help`: align exit-code one-liner with README exit-code row `1` (kernel <6.14 hard-floor fail).

v7.4.40 - v7.4.44 - 2026-05-22
------------------------------

- Hardware: drop orphan kernel-bugzilla tracker line (References covers gfx1151).
- Managed Files: clarify both iwd-gated destinations (`iwd/main.conf` + NM drop-in) skip when iwd absent.
- Configuration: align cpupower-service + tmpfiles blocks to systemd-logind shape (prose lead + bullet); collapse three low-density tables.
- Logs: drop incorrect `cleanup_exit` claim from Footer-marker row; normal-exit footers carry no marker. Script `_teardown exit` updated to match.

v7.4.39 - v7.4.40 - 2026-05-22
------------------------------

- README safe-trim 740 → 684 lines.
- Drop header blockquote (paru/AUR note → Prerequisites table).
- Drop WiFi-defer sentence from `[!IMPORTANT]` (duplicates Phase 6).
- Prerequisites: fold "Additional preflight gates" prose into table.
- Hardware: compress `[!IMPORTANT]` to one-line; inline UMA Frame Buffer table.
- Run Summary: compress intro paragraph.
- Logs: drop redundant `jq` footer-filter example.
- Known Issues: flatten 5 `<details>` blocks into one 3-column table.
- References: inline link bullets to prose line.

v7.4.38 - v7.4.39 - 2026-05-22
------------------------------

- Collapse verbose multi-clause inline comments to concise WHY lines.
- Split four >220-char lines: `_unit_state`, `_post_sysctl` warn chain, header JSONL printf, pacman db-lock string.
- `_post_cpupower`: split single-line restart-warn into `_warn` + `_info` pair.
- `_init_runtime`: lift KERNEL_PARAMS metachar regex to `set -l`; multi-line if-chain.
- `_check_phase_cmdline`: emit `CHECK_PREFLIGHT` JSONL when `/proc/cmdline` empty (was silent drift).
- `_install_aur_packages`: collapse four `AUR_NOISE_NOTE_TOKEN` calls into single joined log.
- `_post_boot`: shorten `_RY_BOOT_TAINTED=true` rejection parenthetical.

v7.4.37 - v7.4.38 - 2026-05-22
------------------------------

- Flatten `_ry_tmpprobe_dir` initialiser (default-then-update).
- Flatten argparse-tail QUIET toggle (`if/else if` replaces nested `begin..end`).
- Move eight trailing inline comments to dedicated lines.
- README Run Summary: drop example matrix; describe shape in prose.
- README Configuration: Phase 1-6 numbered lists → tables (mobile readability).
- README Phase 6: add `systemctl --user daemon-reload` + JSONL footer row.
- README Phase 3: tmp file in destination's parent dir; symlink probe pre + post render.
- README Safety table: atomic-writes match implementation; fstab notes symlink refusal; mkinitcpio rollback notes `cp + size + cmp -s`; instance-lock notes `/proc/$pid/comm = fish`.

v7.4.36 - v7.4.37 - 2026-05-22
------------------------------

- `_vrsv_chk_nm_dispatcher`: short-circuit on `not-found` (`_warn` + return 0); aligns with sibling `_vrsv_chk_*` helpers.

v7.4.35 - v7.4.36 - 2026-05-22
------------------------------

- Remove three stray `\;` tokens from inline `for` lists (`_vsb_loader`, `_verify_static_system`, `_ry_check_deps`); fish parses `\;` as literal element, flipping `--verify-static` to FAIL on clean installs.
- `RY_INITRD_WARN_MB` invalid values queue into `_RY_DEFERRED_WARNS` (mirrors `RY_RUN_TIMEOUT`).
- Malformed sysctl entries surface via `EXIT_GEN_SYSCTL` dispatcher branch.
- Add defensive `MATRIX_TRUNCATED` JSONL diagnostic in `_rdi_matrix_rows`.

v7.4.34 - v7.4.35 - 2026-05-22
------------------------------

- Split two >250-char lines (MASK service list, sudo-cache warning printf).
- Drop dead `2>/dev/null` on `status stack-trace` (builtin does not write to stderr).

v7.4.33 - v7.4.34 - 2026-05-21
------------------------------

- LOC reduction 5113 → 4468: ~200 multi-line blocks collapsed to `; and` chain form (skipped on blocks with trailing `#` comments).
- Function count unchanged (256 multi-line + 8 single-line); largest still `_ry_show_help` at 39 LOC.

v7.4.32 - v7.4.33 - 2026-05-21
------------------------------

- Consolidate CHANGELOG per-patch entries into ranges; close chain gaps.
- Bump README version badge and run-summary example matrix.

v7.4.31 - v7.4.32 - 2026-05-21
------------------------------

- Expand four single-line content generators (`loader.conf`, resolved drop-in, NM drop-in, `cpupower-service.conf`) to multi-line `printf '%s\n' \` form; output byte-identical.

v7.4.22 - v7.4.31 - 2026-05-21
------------------------------

- README cleanup: Phase blocks → uniform "N sequential operations" intro + ordered step list (Phase 3: "Four-step sequence per file").
- `<summary>` blocks normalised to "count + unit" suffix.
- Inline boot-critical paths → bullet lists in `[!IMPORTANT]` and Phase 3.
- Style sync (`Fish` → `fish`, `Pacman` → `pacman`); en-dash on duration ranges.

v7.4.5 - v7.4.22 - 2026-05-20
-----------------------------

- LOC reduction 5204 → 5113; collapse inline comments to single-line "why" form; semicolon-chain adjacent `set -l`/`set -g` runs.
- Function extractions to keep ≤50 LOC: `_install_preflight` → `_ip_record_regdom`; `_install_aur_packages` → `_iap_per_pkg_retry` + `_iap_record_result`; `_install_rebuild_boot` → `_irb_taint_gate`; `_rdi_run_phases` → `_rrp_optional_indexer`.
- Collapse `_verify_static_services` 9-way `is-enabled` chain to `contains`.
- Bootstrap: non-existent `TMPDIR` → `/tmp` with stderr warning; `_tmp_dir` gains `test -d "$TMPDIR"` defence.
- AUR `mt76-mt7925-dkms` post-build `modinfo` failure now WARN (was silent PASS).
- Emit `BOOT_TAINTED_OVERRIDE` (JSONL + stderr) when `RY_INSTALL_FORCE_BOOT_REBUILD=1` bypasses taint gate.
- Split `_rdi_render_matrix` into header/rows/footer (each ≤50 LOC).
- Kernel <6.14 hard floor now matrix FAIL (was WARN).
- Run-summary matrix: install prints box-drawn Unicode matrix to stderr (CHECK / RESULT / EVIDENCE + totals + verdict); `RY_INSTALL_NO_MATRIX=1` opts out.
- `_phase_record` strips embedded newlines and U+2502 from arguments.
- Drop strict `NOPASSWD: ALL` preflight gate; replace with `_ry_sudo_cache_banner` install-mode warning.

v7.4.0 - v7.4.5 - 2026-05-20
----------------------------

- Preflight + lock + sudo cache redesign.
- Fish-version preflight: flat sentinel replaces nested `begin..end`.
- Preflight rejects `timeout(1)` lacking `--foreground` / `--kill-after` (busybox, uutils).
- `_acquire_lock` closes PID-recycle race via `/proc/$pid/comm`.
- `_acquire_lock_fresh` runs `umask 0077` around mkdir.
- `_ensure_sudo_cached` gains `RY_INSTALL_NO_INTERACTIVE_SUDO=1` opt-out.
- `_csp_filter_rdeps` checks `pipestatus` across all 4 pipe stages.
- `_dc_kill_children` widens SIGKILL grace to 0.5s.
- `_cleanup_tmpfiles` inserts two-step `sudo -n true` gate before `sudo find`.

v7.3.0 - v7.4.0 - 2026-05-17 to 2026-05-19
------------------------------------------

- `_RY_LOUD_ERR`: critical preflight failures reach stderr in default QUIET install mode; `--check` stays silent.
- `_ir_resolve_root_uuid` gains 4-way mode dispatch; `_reason` distinguishes "findmnt failed" from "invalid UUID shape".
- `_RY_LOG_SUPPRESS_CREATE` eliminates orphan `preflight-*.jsonl` on argparse-error paths.
- `_cse_batch_enable` accept-list adds linked, linked-runtime, indirect, generated, transient.
- `_chk_perms` strips leading setuid/setgid/sticky digit.
- `_run_emit_stream` captures head + tail (100 each); build-error tails preserved.
- `_boot_initrd_size_scan` switches to byte comparison (removes off-by-1MB silent pass).
- `_verify_runtime_kparams` pre-extracts preempt/BAR/TSC markers from full dmesg before 5000-line cap.
- LOC reduction via short-circuit chain collapse (5177 → 4842).
- `_ry_check_disk_space` labels switch to GiB/MiB.
- `_vrkg_rebar_sam` lspci regex broadened.
- `_ry_check_deps` adds systemd <250 hard-fail preflight gate.
- `_run` tmpdir-alloc sentinel promoted to `EXIT_RUN_TMPFAIL`.
- Log filename → `MODE-YYYYMMDD-HHMMSS+ZZZZ-PID.jsonl`.

v7.0.0 - v7.3.0 - 2026-05-15 to 2026-05-17
------------------------------------------

- NetworkManager 1.56.0 compat: drop `wifi.iwd.autoconnect=false`.
- `MASK` gains `avahi-daemon.service` and `.socket` (10 → 12 units).
- `PKGS_ADD` gains `realtime-privileges`, `cpupower`; `PKGS_DEL` gains `bolt`.
- New `_ry_check_wireless_regdom`, `_vrk_audio_state`, `_ry_apply_wireless_regdom` (driven by `RY_INSTALL_WIRELESS_REGDOM`).
- `RADV_PERFTEST=transfer_queue` → `RADV_EXPERIMENTAL=transfer_queue`.
- `_vsb_mkinitcpio` amdgpu probe tightened `*amdgpu*` → `\bamdgpu\b`.
- `_ry_check_deps` adds GNU-coreutils `df` probe.
- `HandleSecureAttentionKey` gate <256 → <257.
- Add `/etc/default/cpupower-service.conf`; drop `/etc/drirc`.
- `_vrk_cpu_state` scaling_governor: powersave → performance.
- `_vmh_order_checks` adds `systemd:autodetect` and `autodetect:microcode` pair rules plus fsck-last invariant.
- Drop `cpupower-epp.service`; `SERVICE_DESTINATIONS` empty.
- `_RY_MANAGED_FILE_COUNT` 13 → 12; `EXPECTED_SERVICES` 4 → 3.
- `_vre_fstab` unifies `noatime`/`lazytime`/`commit=10` under `(^|,)tok(,|$)`.
- `_mr_copy_size_verify` adds `cmp -s` after size match.

v6.0.0 - v7.0.0 - 2026-05-12 to 2026-05-15
------------------------------------------

- Foundational v6.x → v7.0 series. v6.0 → v6.1: 5994 → 4985 LOC.
- Drop GNU-tool probes, source-mode scaffolding, ntsync probes, sudo-keepalive, JSONL progress events, log rotation, parallel-child PID guard, atomic-write TOCTOU re-stat, boot-wipe gates, LVM detection.
- Add user-bus detection via `XDG_RUNTIME_DIR/bus` + `systemctl --user is-system-running`.
- HOME field-6 captured via `awk -F:` (GECOS-tolerant).
- JSONL header written before `_init_runtime`.
- `LOCK_DIR` gains `chmod 700`.
- Emit functions use `printf` (flag-injection guard).
- Split `_run` into `_run` / `_run_redact_cmd` / `_run_effective_timeout`; timeout-bypass for pacman, paru, mkinitcpio, sdboot-manage, paccache.
- Tmpfile-path redaction under `$TMPDIR`.
- `_ip_pacman_invoke` gates `-Syyu` retry on `RY_INSTALL_ALLOW_PARTIAL_UPGRADE`.
- Per-package AUR retry.
- `_atomic_write_file` post-write symlink re-check (TOCTOU).
- `_fstab_atomic_replace` `findmnt --verify` hard-fail.
- User destinations install `0600`.
- `--install-file` single-file redeploy with per-target post-hook dispatch.
- Argparse `--exclusive` mode group.
- Atomic `mkdir` + pid-file lock.
- `_ir_validate_counts` enforces array-count invariants.
- `_RY_POST_HOOKS` first-match table for `--install-file` hooks.
- `_rvc_dispatch` adds `*/tmpfiles.d/*` case + `_grep_tmpfiles_entry`.
- Add managed `/etc/tmpfiles.d/99-cachyos-thp.conf`.
- `_aur_verify_mt7925` asserts both pacman and modinfo resolve.
- `_awf_finalize_mv` sudo-lapse returns `$EXIT_FAIL`.
- `_ry_exit` bail path writes JSONL footer.
- `_verify_static_services` multi-`ExecStart` guard.
- Tighten `KERNEL_PARAMS` metachar regex backslash escaping.
