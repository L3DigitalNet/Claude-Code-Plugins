---
name: zfs
description: >
  ZFS (OpenZFS) storage administration: pool creation and management, datasets,
  snapshots, send/receive replication, scrubbing, disk replacement, encryption,
  and performance tuning. Triggers on: ZFS, zpool, zfs snapshot, ZFS dataset,
  zfs send receive, ZFS scrub, RAID-Z, ZFS pool, OpenZFS, zpool status,
  zpool create, zfs list, zfs destroy, zfs rollback, resilver, ARC cache,
  zpool import, zpool export, zfs compression, zfs quota.
globs: []
---

## Identity

- **Kernel module**: `zfs.ko` (loaded via `modprobe zfs`; auto-loaded on most distros)
- **Main CLI tools**: `zpool` (pool management), `zfs` (dataset/snapshot management), `zdb` (low-level diagnostics)
- **Config**: `/etc/zfs/` (import cache, key files), `/etc/zfs/zpool.cache` (auto-import list)
- **Service**: `zfs-import-cache.service`, `zfs-mount.service`, `zfs-share.service` (systemd units)
- **Logs**: `journalctl -u zfs-import-cache` / `journalctl -u zfs-mount` / `dmesg | grep -i zfs`
- **Distro install**: `apt install zfsutils-linux` (Debian/Ubuntu) / `dnf install zfs` after adding OpenZFS repo (RHEL/Fedora)
- **Version check**: `zpool version` / `zfs version`

## Key Operations

| Operation | Command |
|-----------|---------|
| Pool status (all pools) | `zpool status` |
| Pool status (one pool) | `zpool status <pool>` |
| Pool list (size/free/health) | `zpool list` |
| Create mirror pool | `zpool create <pool> mirror <dev1> <dev2>` |
| Create RAID-Z1 pool | `zpool create <pool> raidz <dev1> <dev2> <dev3>` |
| Destroy pool | `zpool destroy <pool>` |
| Export pool (safe removal) | `zpool export <pool>` |
| Import pool | `zpool import <pool>` |
| Import pool (search path) | `zpool import -d /dev/disk/by-id <pool>` |
| Create dataset | `zfs create <pool>/<name>` |
| List datasets | `zfs list` |
| List datasets (recursive) | `zfs list -r <pool>` |
| Set property | `zfs set compression=lz4 <pool>/<dataset>` |
| Get property | `zfs get compression <pool>/<dataset>` |
| Get all properties | `zfs get all <pool>/<dataset>` |
| Create snapshot | `zfs snapshot <pool>/<dataset>@<snapname>` |
| List snapshots | `zfs list -t snapshot` |
| Destroy snapshot | `zfs destroy <pool>/<dataset>@<snapname>` |
| Rollback to snapshot | `zfs rollback <pool>/<dataset>@<snapname>` |
| Send snapshot (local) | `zfs send <pool>/<dataset>@<snap> \| zfs receive <pool2>/<dest>` |
| Send snapshot (remote SSH) | `zfs send <pool>/<dataset>@<snap> \| ssh host zfs receive <pool>/<dest>` |
| Send incremental | `zfs send -i @<prev> <pool>/<dataset>@<snap> \| zfs receive <pool2>/<dest>` |
| Start scrub | `zpool scrub <pool>` |
| Scrub status | `zpool status <pool>` (shows scrub progress and last result) |
| Replace failed disk | `zpool replace <pool> <old-dev> <new-dev>` |
| Resilver status | `zpool status <pool>` (shows resilver progress) |
| Pool I/O stats | `zpool iostat -v <pool> 1` |
| List with custom cols | `zfs list -o name,used,avail,refer,compression,ratio` |
| Mount dataset | `zfs mount <pool>/<dataset>` |
| Unmount dataset | `zfs unmount <pool>/<dataset>` |
| Upgrade pool features | `zpool upgrade <pool>` |
| Upgrade all pools | `zpool upgrade -a` |
| Add vdev to pool | `zpool add <pool> mirror <dev1> <dev2>` |
| Online expand after resize | `zpool online -e <pool> <dev>` |

## Expected State

- All pools report `ONLINE` under `zpool status` — `DEGRADED` means redundancy is lost, `FAULTED` means data may be at risk.
- No checksum or read errors in `zpool status` output (`errors: No known data errors`).
- All datasets mounted at expected mountpoints: `zfs mount` shows no unmounted datasets that should be online.
- Scrub completed within the last 30 days with zero errors.
- ARC hit rate above 80% under normal workloads: `arc_summary` or `/proc/spl/kstat/zfs/arcstats`.

## Health Checks

1. `zpool status` — all pools ONLINE, no errors, scrub date and result visible
2. `zpool list` — verify free space; pools above 80% capacity show fragmentation increases
3. `zfs mount` — lists currently mounted datasets; cross-check against `zfs list`
4. `awk '/^hits|^misses/ {sum+=$3} END {print "ARC total accesses:", sum}' /proc/spl/kstat/zfs/arcstats` — then compute hit rate: `hits / (hits + misses)`

## Common Failures

| Symptom | Likely cause | Check / Fix |
|---------|-------------|-------------|
| Pool status shows `DEGRADED` | One or more disks failed | `zpool status -v <pool>` to identify failed device; replace with `zpool replace` |
| Pool status shows `FAULTED` | Too many disk failures for redundancy level | Restore from backup; RAIDZ1 cannot survive 2 simultaneous disk failures |
| Checksum errors without disk failure | Bit rot, bad cables, flaky controller | `zpool scrub` to assess scope; check cables and HBA; replace suspect disk |
| `cannot import pool: no such pool in the system` | Pool was exported or cache file missing | `zpool import -d /dev/disk/by-id` to search by path; or `zpool import` after attaching all disks |
| `cannot import pool: host ID mismatch` | Pool moved from another machine, `hostid` differs | Override with `zpool import -f <pool>` — verify disks are no longer in use on the original host first |
| Dataset full, but pool shows free space | Dataset has a `quota` set | `zfs get quota <pool>/<dataset>`; raise or remove with `zfs set quota=none` |
| Pool nearly full, cannot free space | Snapshots holding referenced blocks | `zfs list -t snapshot -o name,used,refer` to find large snapshots; destroy old ones |
| `cannot destroy snapshot: dataset is busy` | A clone depends on the snapshot | `zfs list -t all -o name,origin` to find clones; destroy clone first, then snapshot |
| `zfs send` fails with incremental mismatch | Intermediate snapshots were destroyed | Must restart full send; incremental base snapshot must exist on both source and destination |
| `zfs receive` errors with `cannot receive incremental stream` | Destination has diverged (rollbacks or manual snapshots) | `zfs rollback` on destination to match base, then re-send |
| ARC consuming all available RAM | Expected behavior — ARC is a cache | Limit if needed: `echo <bytes> > /sys/module/zfs/parameters/zfs_arc_max`; persist in `/etc/modprobe.d/zfs.conf` |

## Pain Points

- **ARC is not a memory leak**: ZFS ARC uses all available RAM by design — it releases memory to other processes on demand via the kernel's memory pressure mechanism. Only cap it if RAM pressure is causing issues.
- **Deduplication is memory-expensive**: The deduplication table (DDT) requires roughly 300–500 bytes of RAM per unique block. A 10 TB deduplicated pool can require 5–30 GB of RAM just for the DDT. Use `compression=lz4` or `compression=zstd` instead — similar space savings at negligible cost.
- **Cannot shrink a vdev**: Once a vdev is added to a pool, its device count is permanent. You cannot remove a RAIDZ vdev (only mirrors can be removed in recent OpenZFS versions). Plan pool layout before creation.
- **Pool feature flags are one-way upgrades**: `zpool upgrade` enables new features but the pool then requires the same or newer OpenZFS version to import. Never upgrade if the pool might need to be read by an older system.
- **ECC RAM — required or recommended**: ZFS does not require ECC RAM; it runs fine without it. ECC protects against RAM bit errors corrupting data before ZFS writes it. On servers with large datasets and high write rates, ECC is strongly recommended. On a home NAS it is a judgment call.
- **L2ARC and SLOG devices**: L2ARC (SSD read cache) rarely helps unless your working set is larger than RAM. SLOG (separate ZFS Intent Log) only speeds up synchronous writes — databases, NFS with sync enabled. Cheap SSDs as SLOG devices are dangerous: a failed SLOG can cause a pool to need recovery. Use enterprise or power-loss-protected SSDs for SLOG.
- **`recordsize` matters for databases**: Default `recordsize=128K` is good for large sequential files. PostgreSQL and MySQL benefit from `recordsize=16K` or `recordsize=8K` to match their page sizes. Set before writing data — changing `recordsize` applies to new writes only.
- **Snapshot space accounting**: `zfs list -t snapshot` shows `USED` for each snapshot, but this only reflects blocks that are unique to that snapshot. Deleting a snapshot transfers its blocks to the next newer snapshot until the last one is destroyed. Space is not freed until the last snapshot holding unique blocks is destroyed.

## References

See `references/` for:
- `zfs-properties.md` — pool and dataset property reference organized by category
- `common-patterns.md` — pool creation, snapshots, send/receive, encryption, and tuning examples
- `docs.md` — official documentation and man page links
