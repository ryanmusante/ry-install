ry-install changelog

2026-04-08  Ryan Musante

- Tagged as v3.48.6
- HIGH FIX (`_ry_verify_runtime`): THP `enabled` and `defrag` runtime checks never entered their OK branch. Patterns `string match -q '*\[always\]*'` and `'*\[defer+madvise\]*'` ran in glob mode where backslash-bracket is not a valid escape, so both matches always failed and the checks fell through to WARN on correctly tuned hosts. Switched to regex mode (`string match -qr '\[always\]'` and `string match -qr '\[defer\+madvise\]'`). Verified against live-format sysfs strings.
- LOW FIX (`_ry_do_test_all`): `--test-all` ran `fish $script_path --completions` against the real `$HOME`, overwriting the user's actual `~/.config/fish/completions/ry-install.fish` as a side effect of a read-only test mode. Now sandboxes the invocation under `HOME=$(mktemp -d)`, reads/validates from the sandbox, and cleans up on exit.
- LOW FIX (CLI dispatch): `--install-file` without a path argument, or followed by another flag, silently fell through in the arg loop and produced a misleading "Cannot combine multiple mode flags" error on the next iteration. Now emits an explicit `--install-file requires an absolute path argument` diagnostic and exits `EXIT_USAGE` immediately.

2026-04-08  Ryan Musante

- Tagged as v3.48.5
- HIGH FIX (`_install_aur_packages`): post-package boundary work was buried inside `_install_aur_packages` after two early-return paths (empty `AUR_PKGS`, missing `paru`). Result: a profile listing `iwd` in `PKGS_ADD` on a host where iwd was absent at preflight would keep the stale `_RY_SKIP_IWD=true` cached during mkinitcpio.conf pre-deploy, and `_ry_install_file` would silently skip `iwd/main.conf` and `99-cachyos-nm.conf` for the rest of the run. Same path also skipped `updatedb` and `pkgfile --update`. Extracted into new `_install_post_package_refresh` called unconditionally from `_ry_do_install` between `_install_aur_packages` and `_install_system_files`.
- HIGH FIX (`_pregenerate_content_files`): `set -ga _TRACKED_TMPFILES "$out_dir"` ran unconditionally, so a caller-supplied directory would be `rm -rf`'d by `_do_cleanup`. Dormant (no caller currently passes the arg) but latent. Now only tracks when `mktemp` created the dir.
- MED FIX (`_ry_check_disk_space`): `df -BG /` and `df -BM /boot` round UP, creating false-pass on the boundary (a 1.5 GiB system reports `2G` and passes `< 2` CRIT check). Replaced with `df -B1` + integer division by `1073741824` / `1048576`.
- MED FIX (`_install_finalize`): hardcoded `pacman -Qi iwd` check forced every profile to declare iwd or fail with `INSTALL_HAD_ERRORS`. Now gates on whether `$SYSTEM_DESTINATIONS` actually contains `*nm.conf` or `*/iwd/*` paths — profiles that don't manage iwd skip the NM restart entirely.
- MED FIX (`_install_preflight`): sudoers whitelist regex required literal `ALL` at end-of-line, rejecting valid configurations like `(ALL) NOPASSWD: ALL, /usr/bin/foo`. Anchor relaxed to accept `ALL$` or `ALL,`.
- LOW FIX (`_install_packages`): added `.pacnew`/`.pacsave` scan at managed destinations after `pacman -Syu`. Surfaces config remnants that pacman creates silently when upgrading a package whose config was modified.
- LOW FIX (`_atomic_write_file` + `_ry_install_file`): two hash-comparison code paths used different pipelines (`printf '%s' + sha256sum` vs direct pipe to `sha256sum`) that were equivalent only because `--no-trim-newlines` was present in one of them. Extracted shared `_content_hash` helper used by both call sites.
- LOW FIX (`_atomic_write_file`): post-write integrity check now uses `sudo -n cat` instead of plain `sudo cat`. A lapsed keepalive now produces an explicit empty-hash fail-closed path instead of relying on `2>/dev/null` to swallow a hung password prompt.
- LOW FIX (`_install_finalize`): NetworkManager restart failure no longer escalates to `INSTALL_HAD_ERRORS` (recoverable on reboot). Logs `NM_RESTART_FAILED` and warns instead.
- LOW FIX (log rotation): switched from newline-delimited `find -printf '%T@\t%p\n'` pipeline to null-delimited `-printf '%T@\t%p\0'` + `sort -z` + `string split0`. Theoretical hardening against log paths containing literal newlines.
- LOW FIX (`_acquire_lock`): flock-branch `echo %self >$LOCK_FILE` now matches the parallel branch's error handling (`if not echo ... 2>/dev/null` + rmdir cleanup + LOG_FILE removal). Closes a disk-full race that previously left an empty lock dir.

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
