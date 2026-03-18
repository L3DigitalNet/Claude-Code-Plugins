---
name: ext4
description: >
  ext4 filesystem administration: create, check, repair, tune, and resize ext4
  filesystems.
  MUST consult when installing, configuring, or troubleshooting ext4.
triggerPhrases:
  - "ext4"
  - "e2fsck"
  - "tune2fs"
  - "mke2fs"
  - "ext4 filesystem"
  - "resize2fs"
  - "ext4 journal"
  - "mkfs.ext4"
  - "debugfs"
  - "dumpe2fs"
  - "e2fsprogs"
  - "fsck"
  - "reserved blocks"
  - "inode exhaustion"
  - "filesystem repair"
globs:
  - "**/fstab"
  - "**/etc/fstab"
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Kernel module** | Built-in (`ext4` — no separate package needed) |
| **Userspace tools** | `e2fsprogs` package (`apt install e2fsprogs` / `dnf install e2fsprogs`) |
| **CLI tools** | `mkfs.ext4` (alias: `mke2fs -t ext4`), `e2fsck`, `tune2fs`, `resize2fs`, `debugfs`, `dumpe2fs`, `blkid`, `findmnt` |
| **Config** | `/etc/fstab` (mount options), no daemon config file |
| **Logs** | `journalctl -k | grep ext4` (kernel messages), `dmesg | grep ext4` |

## Quick Start

```bash
sudo apt install e2fsprogs
sudo mkfs.ext4 -L mydata /dev/sdX1
sudo mount /dev/sdX1 /mnt/mydata
sudo dumpe2fs -h /dev/sdX1 | grep "Filesystem state"
```

## Key Operations

| Task | Command |
|------|---------|
| Check filesystem (unmounted) | `sudo e2fsck -f /dev/sdXN` |
| Check and auto-repair (unmounted) | `sudo e2fsck -y /dev/sdXN` |
| Create filesystem | `sudo mkfs.ext4 /dev/sdXN` |
| Create with label | `sudo mkfs.ext4 -L mylabel /dev/sdXN` |
| Get filesystem info | `sudo dumpe2fs /dev/sdXN \| less` |
| Show summary info | `sudo dumpe2fs -h /dev/sdXN` |
| Tune parameters | `sudo tune2fs -c 30 -i 1m /dev/sdXN` |
| Show tune2fs info | `sudo tune2fs -l /dev/sdXN` |
| Online resize (expand only) | `sudo resize2fs /dev/sdXN` (uses full partition) |
| Resize to specific size | `sudo resize2fs /dev/sdXN 20G` |
| Show/set reserved block % | `sudo tune2fs -m 1 /dev/sdXN` |
| Set journal mode (writeback) | `sudo tune2fs -o journal_data_writeback /dev/sdXN` |
| Enable discard (TRIM) via tune2fs | `sudo tune2fs -E discard /dev/sdXN` |
| Check for bad blocks | `sudo badblocks -sv /dev/sdXN` |
| Check bad blocks and update fs | `sudo e2fsck -c /dev/sdXN` |
| Force fsck on next boot | `sudo touch /forcefsck` or `sudo tune2fs -C 1 /dev/sdXN` |
| Query mounted filesystem | `findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /mountpoint` |
| Show filesystem UUID | `blkid /dev/sdXN` |
| Change UUID | `sudo tune2fs -U random /dev/sdXN` |
| Check inode usage | `df -i /mountpoint` |
| Disk usage | `df -h /mountpoint` |
| Read journal (debugfs) | `sudo debugfs -R "logdump -a" /dev/sdXN` |

## Expected State

- `dumpe2fs -h /dev/sdXN` shows `Filesystem state: clean`
- `e2fsck -n /dev/sdXN` returns exit code 0 with no errors reported
- Journal mode set (default: `has_journal` feature present)
- No bad blocks listed in `dumpe2fs` bad block count

## Health Checks

1. `sudo dumpe2fs -h /dev/sdXN 2>/dev/null | grep "Filesystem state"` — should output `clean`
2. `sudo e2fsck -n /dev/sdXN 2>&1 | tail -3` — exit 0 means no errors (must be unmounted or read-only mounted)
3. `df -i /mountpoint` — verify `IUse%` is not near 100%

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `structure needs cleaning` in dmesg | Unclean journal or corruption | Unmount, run `e2fsck -f /dev/sdXN`; use `-y` to auto-accept all fixes |
| `No space left on device` but `df` shows free space | Inode exhaustion — too many small files | `df -i` to confirm; inode count is fixed at mkfs time, only option is reformat or migrate to xfs |
| Disk 95% full immediately after mkfs | Reserved blocks at default 5% | `tune2fs -m 1 /dev/sdXN` for data disks (reserve 1% or 0%) |
| `e2fsck: Cannot continue, aborting` | Filesystem mounted read-write during check | Unmount first; for root, boot from live media or use single-user mode |
| Files lost after power failure | Journal mode `writeback` without barriers | Switch to `ordered` (default) mode via tune2fs; check `barrier=0` not in fstab |
| Cloned disk causes UUID conflict in fstab | Two devices share same UUID after `dd` clone | `tune2fs -U random /dev/sdXN` on the clone; update fstab to use new UUID |
| Cannot shrink filesystem online | `resize2fs` only grows online | Unmount, run `e2fsck -f`, then `resize2fs /dev/sdXN <newsize>` before shrinking the partition |
| `HTREE directory inode X has an invalid root node` | Directory index corruption | `e2fsck -D /dev/sdXN` to rebuild directory indices |
| Mount fails with `bad magic number` | Wrong filesystem type or corrupt superblock | Try alternate superblock: `e2fsck -b 32768 /dev/sdXN`; list backups with `mke2fs -n /dev/sdXN` |
| Very slow `e2fsck` on large filesystems | lazy_itable_init not completed | Normal after rapid mkfs; let it finish once or use `tune2fs -E lazy_itable_init=0` at mkfs time |

## Pain Points

- **Must be unmounted for fsck**: Unlike btrfs, ext4 requires the filesystem to be unmounted (or mounted read-only) for `e2fsck`. On live systems this means booting from external media for root filesystem repair.
- **Reserved blocks default 5%**: On a 4 TB disk that's 200 GB reserved for root. For pure data disks (non-root), set `-m 1` at mkfs time or `tune2fs -m 1` afterward.
- **Inode count is immutable**: Set at `mkfs` time (`-i bytes-per-inode`). If you run out of inodes (many small files: mail spools, container layers, package caches), you cannot add more without reformatting. Check early with `df -i`.
- **`e2fsck -y` is dangerous on healthy filesystems**: The `-y` flag answers yes to every prompt including destructive ones. Use only when you intend full automated repair on a known-dirty filesystem, not as a routine precaution.
- **ext4 vs xfs for large files**: xfs handles large files and high-throughput workloads better; ext4 is preferable for workloads with many small files (better directory indexing via htree). Neither is universally better — choose at mkfs time.
- **Journal replay on mount**: If the previous unmount was unclean, ext4 replays the journal automatically on the next mount. This is safe and normal, but dmesg will show recovery messages. If journal replay fails, the filesystem goes read-only.
- **`noatime` is almost always correct**: Default `relatime` still writes atime on first access after mtime changes. For high-throughput workloads, `noatime` in fstab eliminates all atime writes entirely.

## See Also

- **xfs** — High-performance filesystem for large files and RHEL default; use when you need online growth and high-throughput sequential I/O
- **btrfs** — Copy-on-write filesystem with snapshots and checksums; use when you need built-in snapshot/rollback capabilities
- **zfs** — Full storage stack with pooling, checksums, and replication; use when you need enterprise-grade data integrity
- **fdisk-parted** — Partition management tools; use before mkfs.ext4 to create or resize partitions
- **lvm** — Logical volume management; use to create resizable volumes that host ext4 filesystems
- **exfat-ntfs** — cross-platform filesystems for external drives shared with Windows/macOS

## References

See `references/` for:
- `ext4-options.md` — mkfs.ext4, mount, and tune2fs options with purpose and when to use each
- `docs.md` — official documentation and man page links
