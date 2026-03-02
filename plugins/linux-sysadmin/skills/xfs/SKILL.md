---
name: xfs
description: >
  XFS filesystem administration: creation, repair, online growth, quota
  management, label/UUID changes, freeze/unfreeze for snapshots, defragmentation,
  dump and restore, and fragmentation analysis. Triggers on: XFS, xfs_repair,
  xfsprogs, XFS filesystem, xfs_db, xfs_growfs, mkfs.xfs, xfs_info, xfs_admin,
  xfs_fsr, xfsdump, xfsrestore, xfs_freeze.
globs:
  - "**/fstab"
  - "**/etc/fstab"
---

## Identity
- **Kernel module**: Built-in (no module load needed on modern kernels)
- **CLI tools**: `mkfs.xfs`, `xfs_repair`, `xfs_info`, `xfs_admin`, `xfs_growfs`, `xfs_db`, `xfs_freeze`, `xfs_fsr`, `xfsdump`, `xfsrestore`
- **Install**: `apt install xfsprogs` / `dnf install xfsprogs`
- **Default on**: RHEL, CentOS Stream, Fedora (root filesystem)
- **Logs**: kernel ring buffer via `dmesg | grep -i xfs`

## Key Operations

| Operation | Command |
|-----------|---------|
| Show filesystem info | `xfs_info /mount/point` or `xfs_info /dev/sdXN` |
| Create filesystem | `mkfs.xfs /dev/sdXN` |
| Create with label | `mkfs.xfs -L mylabel /dev/sdXN` |
| Repair (unmounted) | `xfs_repair /dev/sdXN` |
| Forced repair (corrupted log) | `xfs_repair -L /dev/sdXN` — zeroes the log; **last resort** |
| Online grow | `xfs_growfs /mount/point` (device must already be larger) |
| Change label | `xfs_admin -L newlabel /dev/sdXN` (unmounted) |
| Change UUID | `xfs_admin -U generate /dev/sdXN` (unmounted) |
| Freeze filesystem | `xfs_freeze -f /mount/point` (for consistent snapshot) |
| Unfreeze filesystem | `xfs_freeze -u /mount/point` |
| Enable project quota | Mount with `prjquota`; run `xfs_quota -x -c 'project -s projname' /mnt` |
| Check quota usage | `xfs_quota -x -c 'report -h' /mount/point` |
| Defragment (online) | `xfs_fsr /mount/point` or `xfs_fsr /dev/sdXN` |
| Dump filesystem | `xfsdump -l 0 -f /backup/dump.xfs /mount/point` |
| Restore from dump | `xfsrestore -f /backup/dump.xfs /restore/point` |
| Check fragmentation | `xfs_db -r -c frag /dev/sdXN` |
| Inspect superblock | `xfs_db -r -c 'sb 0' -c p /dev/sdXN` |

## Expected State
- Filesystem mounts cleanly; `xfs_info` returns valid geometry without errors
- `dmesg | grep -i xfs` shows no corruption or I/O error messages
- Journal replays automatically on unclean shutdown (normal; not an error)
- Quotas active if `prjquota`/`uquota`/`gquota` in mount options

## Health Checks
1. `xfs_info /mount/point` — returns block size, AG count, and geometry without error
2. `dmesg | grep -i 'xfs.*error\|xfs.*corrupt' | tail -20` — empty is healthy
3. `xfs_quota -x -c 'report -h' /mount/point` — runs without error if quotas are enabled

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| Filesystem won't mount; journal dirty | Unclean shutdown; journal not yet replayed | Mount normally — kernel replays journal automatically; if it fails, run `xfs_repair` |
| `xfs_repair` refuses to run | Filesystem is mounted | Unmount first; repair requires the device to be offline |
| `XFS metadata I/O error` in dmesg | Failing hardware (disk or controller) | Run `smartctl -a /dev/sdX`; check controller logs; do not repair until hardware is confirmed good |
| Cannot shrink XFS | XFS supports online grow only; shrink is not implemented | Plan partition size upfront; only option is dump, reformat, restore |
| `xfs_repair -L` causes data loss | `-L` zeroes the log, discarding uncommitted transactions | Use only after normal `xfs_repair` fails; accept potential data loss |
| Quotas not enforced | Mount options missing `prjquota`/`uquota`/`gquota` | Add quota mount option to `/etc/fstab`, remount, initialize with `xfs_quota` |
| Fragmentation degrading performance | Many small files written over time (databases, mail spools) | Run `xfs_fsr` during low-I/O window; monitor with `xfs_db -r -c frag` |
| `xfs_growfs` fails with "filesystem already maximum size" | Block device not yet resized | Resize the partition/LV/volume first, then run `xfs_growfs` |

## Pain Points
- **XFS cannot be shrunk**: Only online growth is supported. Size the partition correctly at creation; recovery requires dump/reformat/restore.
- **`xfs_repair -L` zeroes the log**: This discards any transactions not yet written to disk. Use only when normal `xfs_repair` refuses to proceed and data loss is acceptable — not as a routine first step.
- **Default on RHEL/CentOS/Fedora**: These systems boot from XFS root by default. Know the tools before touching the root filesystem; a failed repair on an unmounted root requires rescue media.
- **RHEL-specific xfs_repair behavior**: Red Hat ships a patched `xfs_repair` with additional safety checks. Behavior may differ from upstream for certain corruption patterns; consult RHEL release notes for known bugs.
- **Metadata locking on large directories**: Very large directories (millions of entries) can cause extended hold times on metadata locks, stalling other operations. Distribute files across subdirectories where possible.
- **`norecovery` mount option is dangerous**: It bypasses journal replay and is intended for read-only forensic access on an unclean filesystem. Never use it on a filesystem you intend to write to.
- **`ftype=1` required for overlayfs/Docker**: If mkfs.xfs was run without `-n ftype=1` (the default on modern xfsprogs, but not on older versions), Docker's overlay2 storage driver will refuse to use the filesystem.

## References
See `references/` for:
- `xfs-options.md` — mkfs.xfs flags, mount options, and xfs_admin options with purpose and usage context
- `docs.md` — official documentation and man page links
