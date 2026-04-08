ry-install changelog

2026-04-08  Ryan Musante

- Tagged as v3.48.8
- LOW FIX (`_ry_verify_runtime`): positional-coupling assertion diagnostic at `sys_units` count drift embedded `\"(count $sys_units)\"` inside a double-quoted string. Fish does not perform command substitution through escape-quoted boundaries, so the error message would have printed the literal text `"(count $sys_units)"` instead of the actual count. Cold path (only fires on maintainer-introduced drift), but misleading when it does. Rewrote as `actual="(count $sys_units)" expected=5` with the command substitution outside the quoted span.

2026-04-08  Ryan Musante

- Tagged as v3.48.7
- LOW FIX (`_content_hash`): `test $status -ne 0` after `set -l _content (_ry_get_file_content ... | string collect --no-trim-newlines)` checked the tail of the pipeline (`string collect`), not the generator — generator failures with partial output would slip past the status check and only be caught by the `-z` fallback. Switched to `$pipestatus[1]` to capture the generator's exit code explicitly. `string collect --no-trim-newlines` is retained for trailing-newline parity with on-disk files written by `tee`.
- LOW FIX (`_msg`): invalid-level branch wrote JSONL directly to `$LOG_FILE` without the `test -n ... ; and test -f ...` guard that `_log` uses. If an invalid level was passed during early init (before log creation) or after lock-contention cleanup (which removes `$LOG_FILE`), the redirect would emit a "No such file" error on stderr. Now gated identically to `_log`.
- LOW FIX (`_validate_kernel_params`): stale inline comments. Header comment claimed `amd_iommu` was unchecked because it lacked a "clean CONFIG_ symbol" — `CONFIG_AMD_IOMMU` exists; the real reason is validation is moot (we disable the feature). Example comment referenced `CONFIG_AMD_PSTATE`, which is not in `param_config_map`. Rewrote both to match the actual map contents.

2026-04-08  Ryan Musante

- Tagged as v3.48.6
- HIGH FIX (`_ry_verify_runtime`): THP `enabled` and `defrag` runtime checks never entered their OK branch. Patterns `string match -q '*\[always\]*'` and `'*\[defer+madvise\]*'` ran in glob mode where backslash-bracket is not a valid escape, so both matches always failed and the checks fell through to WARN on correctly tuned hosts. Switched to regex mode (`string match -qr '\[always\]'` and `string match -qr '\[defer\+madvise\]'`). Verified against live-format sysfs strings.
- LOW FIX (`_ry_do_test_all`): `--test-all` ran `fish $script_path --completions` against the real `$HOME`, overwriting the user's actual `~/.config/fish/completions/ry-install.fish` as a side effect of a read-only test mode. Now sandboxes the invocation under `HOME=$(mktemp -d)`, reads/validates from the sandbox, and cleans up on exit.
- LOW FIX (CLI dispatch): `--install-file` without a path argument, or followed by another flag, silently fell through in the arg loop and produced a misleading "Cannot combine multiple mode flags" error on the next iteration. Now emits an explicit `--install-file requires an absolute path argument` diagnostic and exits `EXIT_USAGE` immediately.
