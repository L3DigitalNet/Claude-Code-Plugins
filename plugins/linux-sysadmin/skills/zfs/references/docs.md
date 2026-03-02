# ZFS Documentation

## Official OpenZFS

- OpenZFS documentation: https://openzfs.github.io/openzfs-docs/
- Getting started (Linux): https://openzfs.github.io/openzfs-docs/Getting%20Started/index.html
- OpenZFS feature flags: https://openzfs.github.io/openzfs-docs/man/master/7/zpool-features.7.html
- Release notes and changelog: https://github.com/openzfs/zfs/releases

## Man Pages

- `man zpool` — pool management commands and properties
- `man zfs` — dataset/snapshot commands and properties
- `man zdb` — low-level ZFS debug tool (pool/dataset inspection, block-level read)
- `man zed` — ZFS event daemon (monitoring, email alerts)
- `man zfs-mount-generator` — systemd mount generator for ZFS datasets

Online (latest): https://openzfs.github.io/openzfs-docs/man/master/

## FreeBSD Handbook — ZFS Chapter

The FreeBSD handbook ZFS chapter is one of the most complete conceptual references available,
even if you are running Linux. Covers ARC/L2ARC/SLOG in depth, pool design, and administration:
https://docs.freebsd.org/en/books/handbook/zfs/

## Tutorials and Guides

- OpenZFS on Linux wiki (historical, still useful): https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/
- Ubuntu ZFS guide (Canonical): https://ubuntu.com/tutorials/setup-zfs-storage-pool
- ArchWiki ZFS article (comprehensive, distro-agnostic): https://wiki.archlinux.org/title/ZFS
- ZFS best practices and caveats (Aaron Toponce, widely referenced): https://pthree.org/2012/12/13/zfs-administration-part-viii-zpool-best-practices-and-caveats/

## Encryption

- OpenZFS native encryption guide: https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html
- Encryption design document: https://github.com/openzfs/zfs/blob/master/module/icp/README.md

## Replication Tools

- `sanoid` / `syncoid` (snapshot management and replication): https://github.com/jimsalterjrs/sanoid
- `zrepl` (modern push/pull replication daemon): https://zrepl.github.io/
- `zfs-auto-snapshot` (simple snapshot rotation): https://github.com/zfsonlinux/zfs-auto-snapshot

## Performance and Tuning

- ZFS ARC internals: https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/index.html
- OpenZFS workload tuning guide: https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html
- Module parameters reference: https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Module%20Parameters.html
