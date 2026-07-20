Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.


7.129.0
-------

  - readme: service keys become a key/value/emitted-as table, matching
    the five sibling tables under embedded values
  - readme: the renaming rule now reads off the table's third column
    rather than three examples in prose
  - readme: ntsync note says "present passes" so the word no longer
    collides with the OK label in the exit-code table
  - perf: cpu governor and p-state epp hint both set to performance,
    the maximum values the preflight validators accept
  - perf: gpu dpm level forced to high, pinning the gfx1151 clocks to
    their highest power state rather than scaling on demand
  - perf: package power stays capped at 85W in firmware, so peak draw
    is unchanged; idle draw rises because clocks no longer scale down
  - readme: udev and cpupower rows and the cpu/gpu service-key
    paragraph carry the new values
  - changelog: the 7.128.x entries merged into this one
  - affects the udev perf rules and the cpupower drop-in; the other
    fifteen generated files are unchanged


7.127.0
-------

  - license: ship the MIT LICENSE file the readme had claimed since
    7.120.0; badge and license section now resolve to it
  - readme: managed-file split reworded to 15 system-scope, 4 of them
    boot-critical, plus 2 user; "11 system" was the non-boot subset
  - readme: quick start uses "; and" rather than "&&", matching the
    uninstall steps and the script's own style
  - readme: the resolver and cpu/gpu service-key paragraphs split in
    two; both had grown past five sentences on one line
  - readme: troubleshooting "rebuild refused" action put in the
    imperative, as every other action cell already was
  - readme: version separator is a plain middot, dropping the &nbsp;
    html entities from an otherwise markdown-only document
  - no change to executable code, generated config bytes, array counts
    or the exit model; version pins synced across source and changelog


7.126.0
-------

  - dns: upstreams pinned in the resolver drop-in and in the
    NetworkManager global-dns section, which per-link config outranks
  - dns: queries stay in plaintext. Filtering is identical either way
    and strict DNS-over-TLS fails closed on an unreachable endpoint
  - dns: preflight refuses an empty upstream list and any upstream
    that is not an IPv4 literal, before anything is written
  - style: inline comments brought inside the house length range; the
    logind and NetworkManager drop-ins now head with an em dash
  - readme: resolver and NetworkManager entries describe the pinning
    and record why encryption is absent by choice
  - affects the resolver, NetworkManager and logind drop-ins; the
    other fourteen generated files are unchanged


7.123.1
-------

  - color: NO_COLOR now needs a non-empty value to disable color; it
    was honored on presence alone. TERM=dumb and non-TTY unchanged
  - summary: the configuration phase reports under its declared name;
    an abbreviation had shown seven phase names for six
  - modprobe: correct the second amdxdna comment to -ENODEV (-19); the
    generated file was already corrected in 7.123.0
  - no change to any generated file, embedded value or exit code


7.123.0
-------

  - kernel: add mt7925e.disable_aspm=1. The global policy governs link
    state only, so the endpoint driver disables ASPM itself
  - sysctl: add kernel.nmi_watchdog=0. The runtime check asserted it
    while nothing set it; the profile now owns what it verifies
  - env: rename FSR4_UPGRADE to PROTON_FSR4_UPGRADE, the name the Proton
    runtime actually reads. The former was consumed by nothing
  - env: drop VKD3D_CONFIG=descriptor_heap. Not enabled by default
    upstream and within noise here; per-title use is unaffected
  - modprobe: correct the amdxdna probe failure noted in the generated
    file to -ENODEV (-19); the driver returns that, not -EINVAL
  - counts: KERNEL_PARAMS 14 to 15, SYSCTL_VALUES 10 to 11, ENV_VARS 11
    to 10; drift tripwires and the readme tables follow
  - affects /etc/kernel/cmdline, /etc/sdboot-manage.conf, the sysctl
    and modprobe drop-ins and the user environment file; needs a boot


7.120.0 - 7.122.0
-----------------

  - source: comments normalised to one line each, verbose inline notes
    trimmed to the vital fact, safety and lint annotations kept
  - source: section banners name only the functions they hold, arrow glyph
    unified, one blank line before every banner
  - source: "sub:" parent marker completed across the verify helpers;
    description casing left as written, opening with command names
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
  - services: nftables-first gate moved from the removal path to the
    mask path; an unconfirmed ruleset withholds the ufw.service mask
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
