ry-install ChangeLog
====================

Maintained in kernel.org ChangeLog format: newest release first, dated
heading per release, terse bullets naming the subsystem before the
change. Detail belongs in commit messages, not here.


v4.4.24 - 2026-04-26
--------------------

  * Strings: revert L1310, fix L1461. v4.4.23 misdiagnosed; real
    closer-eating bug was `'\\'` vs grammar's left-biased `\\'|\\`
    regex. Bare `\\ \\\\` uses top-level escape, no string opens.
    fish-vs-grammar span divergence: 86 → 0.


v4.4.18..v4.4.23 - 2026-04-26
-----------------------------

  * Comment hygiene + fish-tmbundle grammar tripwire pass:
    multi-line `#` block collapse, ≤60c abbreviation, U+2026 drop,
    unbalanced quote/backtick/paren close. v4.4.23 misdiagnosis
    reverted in v4.4.24.


v4.4.8..v4.4.17 - 2026-04-26
----------------------------

  * Signal-handler, exit-path, namespace-cleanup re-entry guards.
    `_content_bytes` string-collect terminator (15/15 byte-equal
    round-trip). Comment rewrap and pipeline-orientation passes.


v4.4.0..v4.4.7 - 2026-04-25..2026-04-26
---------------------------------------

  * Profile system: $HOME/.config/ry-install/profiles/<n>.fish.
  * Verification split: --verify-static / --verify-runtime / --check.
  * Locking: mkdir mutex + flock(1) stale reclaim.
  * sudo keepalive with TERM→sleep→KILL teardown.


v4.3.x - 2026-04-25
-------------------

  * Embedded content generators per managed file; SHA256-keyed
    verification. cpupower-epp.service printf-truncation fix.


v4.2.x..v4.0.x - 2026-04-18..2026-04-25
---------------------------------------

  * Initial fish rewrite from v3.x bash. Single-file architecture,
    embedded generators, manifest-driven install, argparse CLI.


v3.x and earlier - through 2026-04-13
-------------------------------------

  * Bash-era development. Superseded by v4.0 fish rewrite.
