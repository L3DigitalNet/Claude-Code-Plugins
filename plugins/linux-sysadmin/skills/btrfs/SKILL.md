---
name: btrfs
description: >
  Btrfs filesystem administration: subvolumes, snapshots, rollback, balance,
  scrub, RAID profiles, compression, quotas, send/receive backups, and
  troubleshooting. Triggers on: btrfs, Btrfs, btrfs snapshot, btrfs subvolume,
  btrfs balance, btrfs scrub, copy-on-write filesystem, CoW filesystem,
  btrfs-progs, mkfs.btrfs, snapper, btrbk.
globs:
  - "**/fstab"
  - "**/etc/fstab"
---

## Identity

- **Type**: Kernel built-in filesystem (no loadable module needed on most distros)
- **CLI tool**: `btrfs` (subcommands: `filesystem`, `subvolume`, `balance`, `scrub`, `device`, `quota`, `qgroup`, `check`, `defragment`, `rescue`)
- **Distro install**: `apt install btrfs-progs` / `dnf install btrfs-progs`
- **Filesystem created at**: `mkfs.btrfs` time (not mounted separately)
- **Kernel version matters**: Significant stability improvements landed between 4.x and 6.x. Older kernels have known bugs — especially with RAID-5/6 and balance operations.

## Key Operations

| Operation | Command |
|-----------|---------|
| Show filesystems | `btrfs filesystem show` |
| Filesystem usage (detailed) | `btrfs filesystem usage /mount` |
| List subvolumes | `btrfs subvolume list /mount` |
| Create subvolume | `btrfs subvolume create /mount/name` |
| Delete subvolume | `btrfs subvolume delete /mount/name` |
| Create read-write snapshot | `btrfs subvolume snapshot /mount/src /mount/dst` |
| Create read-only snapshot | `btrfs subvolume snapshot -r /mount/src /mount/dst` |
| Rollback: delete current, rename snapshot | `btrfs subvolume delete /mount/@; mv /mount/@snapshot /mount/@` |
| Rollback: recreate subvolume from snapshot | `btrfs subvolume snapshot /mount/@snapshot /mount/@` |
| Balance start (all chunks) | `btrfs balance start /mount` |
| Balance start (metadata only) | `btrfs balance start -mconvert=raid1 /mount` |
| Balance status | `btrfs balance status /mount` |
| Balance cancel | `btrfs balance cancel /mount` |
| Scrub start | `btrfs scrub start /mount` |
| Scrub status | `btrfs scrub status /mount` |
| Scrub cancel | `btrfs scrub cancel /mount` |
| Check filesystem (read-only) | `btrfs check /dev/sdX` (unmounted) |
| Defragment file or directory | `btrfs filesystem defragment -r /mount` |
| Resize (grow) | `btrfs filesystem resize max /mount` |
| Resize (shrink) | `btrfs filesystem resize -10G /mount` |
| Add device | `btrfs device add /dev/sdY /mount` |
| Remove device | `btrfs device remove /dev/sdY /mount` |
| Device read/write error stats | `btrfs device stats /mount` |
| Enable quotas | `btrfs quota enable /mount` |
| Show qgroup usage | `btrfs qgroup show -reF /mount` |

## Expected State

- `btrfs device stats /mount` → all counters are `0` (any non-zero value is a read/write error)
- `btrfs scrub status /mount` → `Status: finished` with `0 errors`
- `btrfs balance status /mount` → `No balance found on '/mount'` when idle
- `btrfs filesystem usage /mount` → Data and metadata ratios show reasonable allocation (metadata should not be >80% full)

## Health Checks

1. `btrfs device stats /mount` → all counters `0`; any non-zero value means hardware errors, act immediately
2. `btrfs filesystem usage /mount` → check both Data and Metadata sections; metadata ENOSPC is the most common silent failure
3. `btrfs scrub status /mount` → verify last scrub completed with no errors; schedule scrubs monthly via systemd timer or cron
4. `btrfs subvolume list /mount` → audit snapshot count; accumulation fills disk without appearing in normal `df` output

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `no space left on device` but `df` shows free space | Metadata chunks exhausted while data chunks exist | `btrfs filesystem usage /mount` — run `btrfs balance start -dusage=50 /mount` to rebalance underused chunks |
| RAID-1 on data but single on metadata | Dangerous default when adding a second disk; metadata is not redundant | `btrfs filesystem usage /mount` — check metadata profile; run `btrfs balance start -mconvert=raid1 /mount` |
| Filesystem mounts read-only | Encountered an error it cannot self-correct | Check `dmesg | grep -i btrfs`; run `btrfs check /dev/sdX` on unmounted device to assess damage |
| Balance fails with ENOSPC mid-run | Not enough free space to relocate all chunks | Use `-dusage=<N>` filter to relocate only partially-used chunks first; free up space before retrying |
| Qgroup show reports inflated usage | Qgroups track snapshot references — shared data counted in each | Shared data is expected; use `btrfs qgroup show -reF` to see exclusive vs shared bytes |
| Snapshot accumulation fills disk | Old snapshots reference deleted data, preventing space reclaim | `btrfs subvolume list /mount | grep snapshot` — delete old snapshots with `btrfs subvolume delete` |
| `btrfs check --repair` made it worse | `--repair` is not safe for general use and can corrupt data | Never run `--repair` without consulting upstream; use `rescue` subcommands instead |
| Filesystem errors after kernel upgrade | Older on-disk format or regression | Check `dmesg`; downgrade kernel or use `btrfs rescue` tools; check known issues for your kernel version |

## Pain Points

- **ENOSPC due to metadata/data imbalance**: The most common Btrfs "gotcha". Btrfs allocates space in chunks — if metadata chunks fill up, writes fail even when data chunks are available and `df` still shows free space. Fix: `btrfs balance start -dusage=50 /mount` to reclaim partially-empty chunks. This is not a bug — it is the expected behavior when chunk allocation becomes imbalanced.
- **Mixed RAID profiles between data and metadata**: Adding a second disk does not automatically mirror metadata. A system can have `RAID1` data but `single` metadata, meaning metadata loss on one disk is fatal. Always explicitly set both with `-d` and `-m` flags.
- **Snapshots are instant but they accumulate**: Snapshot creation is O(1) and free. Deletion requires reference counting and can be slow. Unreferenced snapshots hold on to deleted data indefinitely — disk usage only decreases after snapshot deletion completes.
- **`btrfs check` is slow and `--repair` is risky**: Unlike `fsck.ext4`, Btrfs check does not have a safe repair mode. `--repair` can corrupt a filesystem that `check` reports as damaged. Prefer `btrfs rescue` subcommands (`zero-log`, `fix-device-size`) for targeted fixes.
- **Btrfs RAID-5/6 has known parity issues**: As of kernels through 6.x, Btrfs RAID-5 and RAID-6 have unresolved write-hole bugs. Do not use RAID-5/6 for data you care about. Use RAID-1 or RAID-10 instead.
- **Send/receive for backups**: `btrfs send` / `btrfs receive` is efficient for incremental backups using read-only snapshots as base references. Tools like `snapper` and `btrbk` automate the snapshot lifecycle and send/receive workflow — prefer them over manual scripting.
- **CoW fragmentation on databases and VMs**: Copy-on-write writes new data to new locations, which fragments sequential files over time. Use `nodatacow` mount option (or `chattr +C`) for VM disk images, database files, and other large randomly-written files. `nodatacow` also disables checksums for those files.

## References

See `references/` for:
- `btrfs-options.md` — mkfs and mount options organized by category
- `common-patterns.md` — filesystem setup, subvolume layouts, snapshots, rollback, backup, RAID, and compression
- `docs.md` — official documentation and community links
