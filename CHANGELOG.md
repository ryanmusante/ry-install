ry-install changelog

Most recent first. Dates ISO-8601; UTC offset omitted.

7.14.1  2026-05-29
- _vrkm_amdgpu: derive expected amdgpu.ppfeaturemask from KERNEL_PARAMS instead
  of a hardcoded literal. The 7.14.0 bump to 0xfff73fff had left the runtime
  expected at 0xfffd7fff, so --verify-runtime reported a spurious ppfeaturemask
  FAIL on a correctly installed system. Install path was unaffected.

7.14.0  2026-05-29
- amdgpu.ppfeaturemask 0xfffd7fff -> 0xfff73fff.
- KERNEL_PARAMS 16 -> 17 (+amdgpu.sg_display=0).
- AUR_PKGS reduced to mkinitcpio-firmware (3 -> 1); drop mt76-mt7925-dkms and
  r8127-dkms plus the now-dead MT7925 verify/record scaffolding.

7.13.5  2026-05-29
- Drop advisory-only diagnostics (_vrkm_ttm_diag, _vrk_audio_state,
  _boot_initrd_size_scan) and their dead plumbing. Runtime-var doc 5 -> 4.

7.13.4  2026-05-29
- Condense explanatory comments to single-line form; section banners, rationale,
  and the script header retained. No behaviour, count, or invariant change.

7.13.3  2026-05-29
- Drop RY_INSTALL_NO_MATRIX; the run-summary matrix always renders to stderr
  (JSONL PHASE_RESULT remains the durable record). Runtime-var doc 6 -> 5.

7.13.2  2026-05-29
- Drop RY_INSTALL_PKG_REMOVE_CASCADE and RY_INSTALL_NO_INTERACTIVE_SUDO. PKGS_DEL
  members held by outside reverse-deps are always skipped. Runtime-var doc 8 -> 6.

7.13.1  2026-05-29
- Drop inert RY_INSTALL_ALLOW_PARTIAL_UPGRADE; pacman -Syu --needed is run
  unconditionally.

7.13.0  2026-05-29
- AUR installs unconditionally; drop hardware-gating detectors and
  RY_INSTALL_MAINTENANCE. Runtime-var doc 9 -> 8; AUR 2 -> 3.

7.12.0  2026-05-29
- Automatic .ry.bak backups for loader.conf and mkinitcpio.conf, restored on
  post-write byte mismatch (fstab excluded). Add time-sync preflight. Forbid
  partial upgrades.

Earlier releases: see git history.
