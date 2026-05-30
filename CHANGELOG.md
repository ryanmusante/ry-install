ry-install ChangeLog

Newest first; dates ISO-8601.

7.16.1  2026-05-30
- docs: README prose mask count 12 -> 11 (Phase 4 narrative + Uninstall); now matches MASK array and detail table (lvm2-monitor.service dropped in 7.16.0).

7.16.0  2026-05-30
- logind: drop HandleSecureAttentionKey; LOGIND_IGNORE_KEYS 9 -> 8; remove systemd>=257 gate.
- mask: drop lvm2-monitor.service; MASK 12 -> 11.

7.15.0  2026-05-30
- env: PROTON_FSR4_UPGRADE -> PROTON_FSR4_RDNA3_UPGRADE for the RDNA 3.5 8060S; count 10.
- sysctl: drop net.core.busy_poll, net.core.busy_read; SYSCTL_VALUES 9 -> 7.

7.14.3  2026-05-30
- guard optional-tool calls (ip, ping, swapon/zramctl, zcat); absent tools degrade cleanly.

7.14.2  2026-05-29
- format only: one-element-per-line arrays; banners to 100-col; notation normalized.

7.14.1  2026-05-29
- verify: derive expected ppfeaturemask from KERNEL_PARAMS (fixes spurious 0xfffd7fff FAIL).

7.14.0  2026-05-29
- cmdline: ppfeaturemask 0xfffd7fff -> 0xfff73fff; +amdgpu.sg_display=0; KERNEL_PARAMS 16 -> 17.
- aur: reduce to mkinitcpio-firmware (3 -> 1); drop mt76-mt7925-dkms, r8127-dkms + dead scaffolding.

7.13.5  2026-05-29
- drop advisory diagnostics (_vrkm_ttm_diag, _vrk_audio_state, _boot_initrd_size_scan); runtime-vars 5 -> 4.

7.13.4  2026-05-29
- condense comments to single-line; banners, rationale, header retained.

7.13.3  2026-05-29
- drop RY_INSTALL_NO_MATRIX; matrix always renders to stderr; runtime-vars 6 -> 5.

7.13.2  2026-05-29
- drop RY_INSTALL_PKG_REMOVE_CASCADE, RY_INSTALL_NO_INTERACTIVE_SUDO; held rdeps skipped; runtime-vars 8 -> 6.

7.13.1  2026-05-29
- drop inert RY_INSTALL_ALLOW_PARTIAL_UPGRADE; pacman -Syu --needed always.

7.13.0  2026-05-29
- aur: install unconditionally; drop hardware-gating detectors, RY_INSTALL_MAINTENANCE; runtime-vars 9 -> 8; AUR 2 -> 3.

7.12.0  2026-05-29
- backups: auto .ry.bak for loader.conf, mkinitcpio.conf (fstab excluded); add time-sync preflight; forbid partial upgrades.

Earlier releases: see git history.
