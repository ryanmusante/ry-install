ry-install changelog

2026-04-08  Ryan Musante

- Tagged as v3.48.4
- `_ry_do_lint` `$()` detector now excludes `awk` lines so awk field arithmetic (`{print $(i+1)}`) is no longer flagged as bash command substitution. The previous detector emitted a spurious WARN on `_is_wifi_active_route`.
- `_ry_do_lint` adds five new bash anti-pattern detectors: `$?` (use `$status`), `$@` (use `$argv`), backtick command substitution (use `(cmd)`), `unset VAR` (use `set --erase VAR`), and bare positional parameters `$1`-`$9` (use `$argv[N]`). Each detector verified against synthetic bad input to confirm it fires correctly. The positional detector excludes embedded `/bin/sh -c` blocks, awk field references, and `string replace` / `string match` PCRE backreferences.
- Tagged five existing lines with `# lint:ignore` annotated with the actual context: two `/bin/sh -c` heredoc lines in `_acquire_lock` (`embedded /bin/sh -c block`), seven awk continuation lines in `_install_fstab_opts` (`awk field reference`), and three `string replace` regex backreference lines (`PCRE backref`).

2026-04-08  Ryan Musante

- Tagged as v3.48.3
- Stripped historical marker prefixes from in-source comments. Rationale preserved in present tense.
- Collapsed multiline comment blocks to single lines.
- Removed two `if true` wrapper blocks (vestigial from prior refactors) in `_progress_done` and `_install_rebuild_boot`. De-indented bodies.
- Removed dead `_boot_ok` variable and its dead conditional in `_install_rebuild_boot`. The false-arm of the assignment already early-returned with `EXIT_BOOT_CRIT`, so the check was provably always-true.
- Trimmed changelog to last three releases.

2026-04-08  Ryan Musante

- Tagged as v3.48.2
- `_install_packages` description and section comment now correctly state install-only; `PKGS_DEL` removal documented to live in `_install_configure_services`.
- `_ry_verify_runtime` preempt probe uses `sudo dmesg` so `kernel.dmesg_restrict=1` no longer silently degrades to "cannot determine".
- `_preflight_boot_sanity` resolves ESP via `sudo bootctl -p` (fallback `/boot`) instead of hardcoded `/boot`. Hosts with ESP at `/efi` or `/boot/efi` are now correctly verified across vmlinuz scan, initramfs scan, loader/entries scan, and the failure-mode hint.
- `_preflight_boot_sanity` loader-entry kernel-path extraction is now anchored (`string replace -r '^linux\s+' ''`) and strips a leading slash before joining with the ESP root, so the join is unambiguous regardless of `sdboot-manage` emit format.
- Sysctl emitter trims key/value after `string split -m1 '='` so the canonical `key = value` format is preserved if a future profile entry includes surrounding whitespace.

2026-04-07  Ryan Musante

- Tagged as v3.48.1
- `_install_aur_packages` erases `_RY_SKIP_IWD` / `_RY_SKIP_IWD_CACHED` at the package-phase boundary. Closes a latent cache-poisoning hazard where the iwd-skip cache would survive across the `pacman -Syu` boundary and silently skip `iwd/main.conf` and `99-cachyos-nm.conf` if a future profile added iwd to `PKGS_ADD`.
- `_atomic_write_file` expected-hash gen captures generator content + exit code into a variable before hashing, fail-closes on `$status -ne 0`. Previously the wildcard arm of `_ry_get_file_content` (returns 1, no output) would silently produce the empty-string SHA when piped through sha256sum.
- `_do_cleanup` `set --erase`s `_RY_SKIP_IWD` / `_RY_SKIP_IWD_CACHED` alongside `_KCONFIG_*` for consistent cleanup discipline.
- `_acquire_lock` wraps `echo %self >$LOCK_FILE` in a check; on write failure (disk full, inode exhaustion) the just-created `LOCK_DIR` is `rmdir`'d and the function returns 1.
- `_ry_validate_configs` Job 4 INI section check uses `grep -qFx` (whole-line match) instead of `grep -qF`. Defends against false positives where a section name appears inside a comment or value.
- `_ry_verify_runtime` adds a static `(count $sys_units) -ne 5` assertion before the `parsed[1..5]` consumers. Hard-fails on positional-coupling drift.
- `_atomic_write_file` post-write integrity check uses plain `sudo cat` (not `sudo -n cat`) so a lapsed keepalive does not false-abort during long runs.
- `_install_preflight` sudo `-l ALL` detection rewritten with explicit reject of NOEXEC / !PASSWD / !SETENV / LOG_OUTPUT tags before a positive whitelist match. Previous regex matched dangerous tags and let users pass the gate only to fail mid-install.
- `_progress_init` seeds `PROGRESS_STEP_START` with current epoch (was 0). Step 1 elapsed display is now non-empty.
- `_install_fstab_opts` findmnt `--verify` grep changed to also catch capitalisation variants of "invalid".
- `_ry_verify_static` and `_ry_verify_runtime` sudo-cache failure now returns `$EXIT_PREFLIGHT` (was bare 1).
- `_install_preflight` `sudo true` redirected to `/dev/null` to suppress sudo lecture text in the script's banner stream.
