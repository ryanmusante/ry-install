Changes for ry-install
======================

Newest first. Versioning is MAJOR.MINOR.PATCH.


7.140.0
-------

  - boot: drop the redundant -T0 from MKINITCPIO_COMPRESSION_OPTIONS;
    mkinitcpio prepends -T0 for zstd, so the image is unchanged
  - verify: warn when a sdboot-manage drop-in is present, since
    drop-ins are sourced after /etc/sdboot-manage.conf and outrank it
  - preflight: drop free, uptime, swapon and zramctl from the optional
    tool probe; the script never invokes any of them
  - readme: correct the PROTON_FSR4_UPGRADE note and record the ext4
    commit=10 tradeoff against the upstream 5 second default
  - docs: cut three readme clauses already stated elsewhere: drop-in
    detection, the edit-the-source rule, and a redundant cross-link


7.139.0
-------

  - verify: sweep every cpufreq policy for driver, governor and EPP
    uniformity; cpu0 stays the representative detail readout
  - verify: assert each non-fallback loader entry carries every
    KERNEL_PARAMS token; fallback entries keep their own options
  - verify: check systemd-resolved unit-file state (enabled or
    static) so --verify and --check agree on persistence
  - verify: report only admin-scope orphan masks and drop vendor
    masks and Alias= cascades of units this profile masks
  - verify: log the root filesystem type and the ext4 fstab entry
    count; distinguish absent sysctl knobs from unreadable ones
  - verify: drop the preemption-model advisory and its dmesg scan;
    the profile never pinned preempt=, so nothing was asserted
  - logging: millisecond JSONL timestamps; CHECK_GREP records use
    key=value form; nftables verdict names the unit-file state
  - internal: hoist the boot-entry list to function scope (same
    block-scope class as the 7.135.1 backup-preserve fix)


7.137.0 - 7.138.0
-----------------

  - configuration: drop the dormant RY_REMOTE_PLAY_PORTS gate and its
    Sunshine/Steam inbound rules from the nftables generator
  - verify: tighten the three preemption advisory strings; branch
    structure and behavior unchanged
  - docs: replace the Usage invocation table with prose and fold the
    Managed Files lead to one line; --help carries the flag detail
  - docs: trim Safety, relocating the DNS, sysctl-priority and NVMe
    scheduler notes to their home sections
  - docs: restructure Uninstall into five ordered steps and trim the
    libvirt/QEMU NAT note; the removed service-key row follows
  - docs: merge the 7.135.0 - 7.137.2 point releases into two range
    blocks; no content change outside this file


7.135.0 - 7.136.1
-----------------

  - install: fix the one-time <path>.ry.orig preserve never running for
    non-boot managed files; a set -l inside an if block does not leak
  - check: record unmanaged 60-ry-*.conf drop-ins and masked units
    absent from MASK, both previously visible to --verify only
  - verify: report masked units the profile no longer declares; the
    script only adds to MASK, so a dropped entry stayed masked
  - preflight: refuse a package in both PKGS_ADD and PKGS_DEL, or a
    unit in both MASK and EXPECTED_SERVICES
  - verify: dynamic_epp probe comment corrected - the node ships in
    Linux 7.1; manual EPP writes are blocked while it is enabled
  - logging: count captured lines without a redirect; fish warns on a
    failed redirect even when stderr is silenced
  - source: the drop-in sweep is one helper shared by both modes
  - docs: self-heal vs external-state reconciliation stated; README
    prose and tuning notes trimmed


7.134.0
-------

  - summary: the abort path records the phase-3 row under the name the
    normal path uses; the old one also overflowed the matrix column
  - verify: two sub markers name the function that calls them, not an
    ancestor, completing the pass begun in 7.132.0 - 7.133.0
  - preflight: read the CPU model through cat. A missing /proc/cpuinfo
    made the redirect emit a warning that --check must never print
  - logging: comma-join the unmanaged drop-in list so files= stays one
    token, matching every other multi-value key
  - docs: uninstall rebuild step uses &&, the form the script prints


7.132.0 - 7.133.0
-----------------

  - verify: warn on unmanaged /etc/modprobe.d/60-ry-*.conf drop-ins.
    The pre-7.99 files had no owner in the profile and no detection
  - verify: session subchecks name _verify_runtime_session, their only
    caller, rather than the services orchestrator
  - summary: phase-3 matrix row renamed to "Configuration: file
    deployment"; its counters span the system and user sets alike
  - source: sub marker normalized inside every helper family that uses
    one; the parent named is the calling function, stated once
  - source: loader-entry boundary warning uses the arrow glyph the
    other user-facing messages already use
  - docs: quick start no longer checks out a version tag; none is
    published, so the clone lands on the default branch
  - docs: service keys table gains LOGIND_IGNORE_KEYS and the
    Handle*Key=ignore form it emits, completing the twenty keys


7.130.0 - 7.131.1
-----------------

  - perf: cpu governor and p-state epp hint set to performance, the
    maximum values the preflight validators accept
  - perf: gpu dpm level forced to high, pinning the gfx1151 clocks to
    their highest power state rather than scaling on demand
  - perf: package power stays capped at 85W in firmware, so peak draw
    is unchanged; idle draw rises because clocks no longer scale down
  - docs: correct the epp claim. The performance governor pins EPP
    to maximum, so EPP_PREFERENCE restates it rather than outranking it
  - docs: pcie_aspm.policy=performance biases links away from ASPM
    rather than disabling them outright; confirm with lspci -vv
  - docs: promote the readme uninstall lead-in to a NOTE alert; no
    automated uninstaller, Managed Files is the rollback reference
  - source: US spelling completed in the 7.118.0 - 7.122.0 range block


7.123.0 - 7.127.0
-----------------

  - dns: upstreams pinned in the resolver drop-in and in the
    NetworkManager global-dns section, which per-link config outranks
  - dns: queries stay in plaintext. Filtering is identical either way
    and strict DNS-over-TLS fails closed on an unreachable endpoint
  - dns: preflight refuses an empty upstream list and any upstream
    that is not an IPv4 literal, before anything is written
  - kernel: add mt7925e.disable_aspm=1. The global policy governs link
    state only, so the endpoint driver disables ASPM itself
  - sysctl: add kernel.nmi_watchdog=0. The runtime check asserted it
    while nothing set it; the profile now owns what it verifies
  - env: rename FSR4_UPGRADE to PROTON_FSR4_UPGRADE, the name the Proton
    runtime actually reads. The former was consumed by nothing
  - env: drop VKD3D_CONFIG=descriptor_heap. Not enabled by default
    upstream and within noise here; per-title use is unaffected
  - modprobe: correct the amdxdna probe failure to -ENODEV (-19); the
    driver returns that, not -EINVAL
  - color: NO_COLOR now needs a non-empty value to disable color; it
    was honored on presence alone. TERM=dumb and non-TTY unchanged
  - summary: the configuration phase reports under its declared name;
    an abbreviation had shown seven phase names for six
  - counts: KERNEL_PARAMS 14 to 15, SYSCTL_VALUES 10 to 11, ENV_VARS 11
    to 10; drift tripwires and the readme tables follow


7.118.0 - 7.122.0
-----------------

  - services: ufw is masked, not removed - MASK 10 -> 11 (+ufw.service),
    PKGS_DEL 10 -> 9 (-ufw)
  - services: nftables-first gate moved from the removal path to the
    mask path; an unconfirmed ruleset withholds the ufw.service mask
  - nftables.conf: embedded header now reads "ufw masked", producing a
    one-time drift and redeploy
  - source: comments normalized to one line each, verbose inline notes
    trimmed to the vital fact, safety and lint annotations kept
  - source: section banners name only the functions they hold, arrow
    glyph unified, one blank line before every banner
  - source: "sub:" parent marker completed across the verify helpers;
    description casing left as written, opening with command names
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


7.100.0 - 7.107.3
-----------------

  - configuration: 17 embedded configs deployed atomically - same-filesystem
    temp file, pre-validation, backup, mv -T, re-read and restore
  - packages: pacman -Rns made rdep-aware via pactree, with a timeout
  - packages: PKGS_ADD re-marked explicit after -Syu so a later removal
    cannot orphan a dependency-installed package
  - verify: static checksum path compares installed bytes to generator
    output by SHA256
  - check: silent idempotency probe against the live /proc/cmdline
  - services: masked unit set and enabled unit set established
  - boot: boot-critical failures exit 4 and skip finalization
  - preflight: hardware gate fails closed when the CPU model is unreadable
  - progress: pinned bottom row with a scroll region


7.99.1 and earlier
------------------

  - initial profile for the Beelink GTR9 Pro: kernel parameters, mkinitcpio,
    sysctl, udev, session environment and the systemd-boot layout
