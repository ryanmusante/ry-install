ry-install changelog

2026-04-09  Ryan Musante

- Tagged as v3.48.17
- `_pregenerate_content_files`: switch `mktemp -d --tmpdir=/tmp` to `-t` for TMPDIR parity with the rest of the script.
- `_cleanup_tmpfiles`: sweep 0700 root-only sys dirs (e.g. /etc/NetworkManager/system-connections) via `sudo -n find` instead of unprivileged find. Collapse three near-identical sweep blocks to single-line `find -delete`.
- `_install_fstab_opts`: change awk `OFS` from `\t` to space; ext4 lines no longer mix tabs into a space-formatted fstab.
- `_install_fstab_opts`: post-rewrite check now uses `findmnt --verify` exit code instead of grepping free-form output for `error|unknown|invalid`.
- `_content_hash`: capture `$pipestatus` after the sha256sum pipeline so generator-side failures return rc=1 instead of an empty hash with rc=0.
- `_ry_do_test_all`: sudo cache is now best-effort; lint/version/help no longer abort on sudo-less hosts.
- `_ry_do_test_all`: completions content check matches `-l <flag>` form rather than the never-present `--<flag>` substring.
- Cosmetic: collapsed runs of consecutive `#` comment lines to single-line comments (36 lines removed). Embedded `/bin/sh -c` and `awk` blocks untouched.

2026-04-08  Ryan Musante

- Tagged as v3.48.16
- `SDBOOT_REMOVE_EXISTING=yes` now requires explicit ack on first run via `RY_INSTALL_CONFIRM_BOOT_WIPE=1`; subsequent runs use `~/ry-install/.boot-wipe-acknowledged` marker. Prevents silent loss of dual-boot/rescue entries.
- New `--restore-power-targets` mode unmasks the sleep/suspend/hibernate targets that install masks.
- `_atomic_write_file`: post-write hash failure messages distinguish sudo credential lapse from filesystem read error.
- Preflight: missing root UUID (findmnt failure) is now a hard `EXIT_PREFLIGHT`, not a warn.
- Preflight: dropped unused `diff`, `md5sum`, `tput` from required deps list.
- Profile: dropped diagnostic-only `iw` from PKGS_ADD (12 → 11).
- `_cleanup_tmpfiles`: NM connections sweep gated on profile actually managing NM/iwd.
- `_acquire_lock`: flock reclaim writes the PID file inside the locked subshell.
- `_load_profile`: logs INFO when defaulting to gtr9_pro.
- `_ry_verify_runtime`: WiFi state checks gated on profile managing NM/iwd.
- `_ry_verify_runtime`: clocksource HPET fail message auto-greps cached dmesg for "Marking TSC unstable".
- `/etc/drirc` generator: comment notes that `radv_enable_unified_heap_on_apu` requires Mesa ≥25.0.

2026-04-08  Ryan Musante

- Tagged as v3.48.15
- README: condensed Uninstall section. Replaced 8-step rollback block with one paragraph pointing at `~/ry-install/.manifest` and the existing Masked Services + Managed Files tables.

2026-04-08  Ryan Musante

- Tagged as v3.48.14
- README: removed v3.48.0 BREAKING blockquote from Quick Start. Removed-flag history is preserved here.

2026-04-08  Ryan Musante

- Tagged as v3.48.13
- README: documentation completeness pass. Added Uninstall section, Scope section, `paru` fallback note, fstab no-persistent-backup note, real `--check`/`--lint`/`sudo -v`/`df -h` pre-flight commands, profile required-globals tables (26 unconditional + 8 conditional), Hardware Reference moved to follow Prerequisites, Known Issues promoted to top-level, 4-step post-install verification workflow, sample NDJSON log output, exit-code disambiguation, Troubleshooting expanded 5 → 12 rows, BREAKING blockquote clarified, TOC trimmed 25 → 13 entries, badges removed.

2026-04-08  Ryan Musante

- Tagged as v3.48.12
- README BREAKING note: dropped inaccurate "all pacdiff/pacnew/pacsave handling" claim. `_install_packages` actively scans for `.pacnew`/`.pacsave` and emits `_warn` + `PACNEW_FOUND:` JSONL events.

2026-04-08  Ryan Musante

- Tagged as v3.48.11
- `_log` event classification: 7 sites used `PREFIX(parens):` form, which broke the `^[A-Z][A-Z_]*: ` event-classifier and silently fell through to `event=message`. Rewritten as `PREFIX: (parens) ...`.
- `_ry_verify_runtime`: cache `sudo dmesg` once and reuse for both Dynamic Preempt and ReBAR/SAM detection.
- `_ry_verify_runtime`: env-var absence is now WARN with a `systemctl --user import-environment` hint, not FAIL.
- `_ry_verify_static` / `_parse_systemctl_show`: all three call sites request the same 3 systemd properties (`LoadState,ActiveState,UnitFileState`) for parser symmetry.
- `_ry_verify_static`: hash collection adds explicit `sudo -n true` probe + `$pipestatus[1]` check + new `noread` state to avoid the empty-file digest masquerading as "checksum MISMATCH".
- `_ry_do_test_all`: label derivation strips only the leading `--` (preserving interior hyphens) instead of stripping all `-`.
- README profile example: added missing `AUR_PKGS` and `MKINITCPIO_COMPRESSION_OPTIONS` to optional globals list.

2026-04-08  Ryan Musante

- Tagged as v3.48.10
- `_install_packages`: post-install verification switched from `pacman -Qq` exact-match to `pacman -T` so groups, virtual packages, and providers are honored.
- `_install_preflight` sudo keepalive: child loop uses 3-attempt retry + 1s backoff around `sudo -n -v`; transient PAM/NSS failures no longer kill the loop.
- `_install_aur_packages`: single batched `paru -S --needed --noconfirm -- $AUR_PKGS` with per-package fallback on batch failure.
- `_install_configure_services` / `_ry_do_install_file`: `systemctl --user set-environment` now also requires `test -S "$XDG_RUNTIME_DIR/bus"` so TTY installs don't emit a misleading warning.
- `_ry_do_install`: `_ry_do_completions` moved inside the success branch so it skips on `EXIT_BOOT_CRIT`.
- `_manifest_write` + `_manifest_check_orphans`: completions path now tracked symmetrically.
- `_install_rebuild_boot`: reworded news-review message to reflect unattended reality.
- Top-level arg parser: 9 open-coded usage-error branches extracted to `_early_usage_exit` helper.

2026-04-08  Ryan Musante

- Tagged as v3.48.9
- `_ry_do_check` job 4 child: assertion diagnostic embedded `(count $results)` inside a double-quoted string. Rewrote with command substitution outside the quoted span.

2026-04-08  Ryan Musante

- Tagged as v3.48.8
- `_ry_verify_runtime`: assertion diagnostic embedded `(count $sys_units)` inside escape-quoted boundaries. Rewrote with command substitution outside the quoted span.

2026-04-08  Ryan Musante

- Tagged as v3.48.7
- `_content_hash`: captured `$pipestatus[1]` for generator status instead of bare `$status` (which reflected the tail `string collect`, not the generator).
- `_msg`: invalid-level branch now gated on `test -n ... ; and test -f ...` like `_log`, so it doesn't emit "No such file" if called during early init.
- `_validate_kernel_params`: stale inline comments rewritten to match the actual `param_config_map` contents.

2026-04-08  Ryan Musante

- Tagged as v3.48.6
- `_ry_verify_runtime`: THP `enabled` and `defrag` runtime checks were running glob-mode `string match` against backslash-bracket patterns, which never matched. Switched to regex mode (`-qr '\[always\]'`, `-qr '\[defer\+madvise\]'`).
- `_ry_do_test_all`: sandboxes `--completions` invocation under `HOME=(mktemp -d)` so the test mode doesn't overwrite the user's real completions file.
- CLI dispatch: `--install-file` without a path now emits an explicit usage error and exits `EXIT_USAGE` immediately.
