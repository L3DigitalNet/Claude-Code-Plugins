# XFS Documentation Links

## Official References

- [XFS Wiki (kernel.org)](https://xfs.wiki.kernel.org/) — authoritative upstream documentation: design, tuning, FAQ, and known issues
- [mkfs.xfs(8) man page](https://man7.org/linux/man-pages/man8/mkfs.xfs.8.html) — all creation flags including `-d`, `-i`, `-l`, `-n` sub-options
- [xfs_repair(8) man page](https://man7.org/linux/man-pages/man8/xfs_repair.8.html) — repair phases, `-L` flag behavior, and when to use `-n` (dry-run check)
- [xfs_info(8) man page](https://man7.org/linux/man-pages/man8/xfs_info.8.html) — output field definitions (agcount, bsize, sunit, swidth, ftype)
- [xfsdump(8) man page](https://man7.org/linux/man-pages/man8/xfsdump.8.html) — dump levels (0=full, 1–9=incremental), session inventory, and restore options

## Distro-Specific Guides

- [RHEL 9 — Managing storage devices: XFS](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_file_systems/assembly_creating-and-mounting-xfs-file-systems_managing-file-systems) — Red Hat's guide covering creation, mounting, quota setup, and growth; describes RHEL-specific xfs_repair behavior
- [Arch Linux Wiki — XFS](https://wiki.archlinux.org/title/XFS) — practical setup, quota configuration, defragmentation, and performance tuning notes; regularly updated by the community

## Quick Reference

| Task | Tool | Notes |
|------|------|-------|
| Create | `mkfs.xfs` | Use `-n ftype=1` explicitly on older xfsprogs |
| Repair | `xfs_repair` | Must unmount; `-L` is last resort |
| Grow | `xfs_growfs` | Online; resize block device first |
| Info | `xfs_info` | Works on mounted filesystem or device |
| Quota | `xfs_quota` | Requires quota mount option |
| Defrag | `xfs_fsr` | Online; safe to run on live filesystem |
| Dump/restore | `xfsdump` / `xfsrestore` | XFS-native; preserves all metadata |
| Debug | `xfs_db` | Interactive; use `-r` for read-only |
