Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.


7.120.0 - 7.122.0
-----------------

  - source: comments normalised to one line each, verbose inline notes
    trimmed to the vital fact, safety and lint annotations kept
  - source: section banners name only the functions they hold, arrow glyph
    unified, one blank line before every banner
  - source: "sub:" parent marker completed across the verify helper
    families; description casing left as written, since those strings open
    with command and unit names
  - readme: rewritten in GitHub style - contents list, tables for reference
    data, prose for rationale and procedure
  - readme: section and row order now follows the source declaration order
  - readme: bootloader keys, initramfs and service keys tables added,
    covering 35 globals that had no documentation
  - readme: version moved out of the shields.io badge row into inline
    text, so it renders without a third-party image request
  - changelog: converted to kernel.org style, historical entries merged
  - no functional change across the range: executable code, generated
    config bytes, array counts and the exit model are identical to 7.119.0


7.118.0 - 7.119.0
-----------------

  - services: ufw is masked, not removed - MASK 10 -> 11 (+ufw.service),
    PKGS_DEL 10 -> 9 (-ufw)
  - services: nftables-first gate moved from the removal path to the mask
    path; on an unconfirmed ruleset the ufw.service mask is withheld for
    the run, since mask --now stops ufw and ufw-init flushes its rules
  - nftables.conf: embedded header now reads "ufw masked", producing a
    one-time drift and redeploy
  - readme: flow, warning, packages, units and uninstall synced
  - version pins synced across source, readme and changelog


7.108.0 - 7.117.0
-----------------

  - install-file: post-hook dispatch table with per-target handlers,
    coverage enforced by an invariant validator
  - verify: runtime module-state subchecks split out of the kernel-param
    orchestrator
  - boot: mkinitcpio.conf snapshot and revert with byte-exact compare
  - fstab: atomic replace behind parity, size and findmnt gates
  - lock: dead-PID reclaim only; live or ambiguous pidfiles fail closed
  - logging: JSONL footer carries the exit code for every mode
  - preserve: one-time <path>.ry.orig for non-boot managed files whose
    pre-existing content differed at first adoption


7.106.0 - 7.107.3
-----------------

  - packages: pacman -Rns made rdep-aware via pactree, with a timeout
  - packages: PKGS_ADD re-marked explicit after -Syu so a later removal
    cannot orphan a dependency-installed package
  - preflight: hardware gate fails closed when the CPU model is unreadable
  - progress: pinned bottom row with a scroll region


7.100.0 - 7.105.15
------------------

  - configuration: 17 embedded configs deployed atomically - same-filesystem
    temp file, pre-validation, backup, mv -T, re-read and restore
  - verify: static checksum path compares installed bytes to generator
    output by SHA256
  - check: silent idempotency probe against the live /proc/cmdline
  - services: masked unit set and enabled unit set established
  - boot: boot-critical failures exit 4 and skip finalization


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro: kernel parameters, mkinitcpio,
    sysctl, udev, session environment and the systemd-boot layout
