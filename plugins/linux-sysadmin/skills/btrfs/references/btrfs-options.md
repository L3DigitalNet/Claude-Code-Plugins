# Btrfs Options Reference

## mkfs.btrfs Options

### Data and Metadata Profiles (`-d`, `-m`)

Controls how data and metadata are distributed across devices. Metadata profile
defaults to `dup` on single-disk setups (two copies on same disk) and `raid1` is
strongly recommended when two or more disks are present.

| Profile | Devices needed | Description |
|---------|---------------|-------------|
| `single` | 1+ | One copy, striped — no redundancy |
| `dup` | 1 | Two copies on the same device (default for metadata, single disk) |
| `raid0` | 2+ | Striped, no redundancy, full capacity |
| `raid1` | 2+ | Mirror across two devices (recommended for metadata on multi-disk) |
| `raid1c3` | 3+ | Mirror across three devices |
| `raid1c4` | 4+ | Mirror across four devices |
| `raid10` | 4+ | Striped mirrors — combine raid0 throughput with raid1 redundancy |
| `raid5` | 3+ | Distributed parity — known write-hole bug, avoid for important data |
| `raid6` | 4+ | Double distributed parity — same caveat as raid5 |

```bash
# Single disk — use dup metadata (default):
mkfs.btrfs /dev/sda

# Two disks — mirror both data and metadata (explicit -m is important):
mkfs.btrfs -d raid1 -m raid1 /dev/sda /dev/sdb

# Four disks — raid10 for data, raid1 for metadata:
mkfs.btrfs -d raid10 -m raid1 /dev/sd{a,b,c,d}
```

### Label (`-L`)

Sets a filesystem label, usable in `/etc/fstab` as `LABEL=name` instead of UUID.

```bash
mkfs.btrfs -L mydata /dev/sda
```

### Node Size (`-n`)

Btree node size. Default is 16KiB. Larger values (up to 64KiB) can improve performance
on large filesystems at the cost of more wasted space in partially-filled nodes.
Must be a power of two and >= page size (usually 4KiB).

```bash
mkfs.btrfs -n 32768 /dev/sda   # 32KiB nodes
```

### Sector Size (`-s`)

Usually matches the device's physical sector size. Most users leave this at the default (4KiB).

### Checksum Algorithm (`--checksum`)

| Algorithm | Notes |
|-----------|-------|
| `crc32c` | Default; fast, hardware-accelerated on modern CPUs |
| `xxhash` | Faster than crc32c in software; non-cryptographic |
| `sha256` | Cryptographic; slow — only if integrity verification against tampering is required |
| `blake2` | Cryptographic; faster than sha256 |

```bash
mkfs.btrfs --checksum xxhash /dev/sda
```

---

## Mount Options

Mount options go in the fourth field of `/etc/fstab` or with `-o` at mount time.
Multiple options are comma-separated.

### Compression

Compression applies to new writes only — existing data is not recompressed automatically.
Use `btrfs filesystem defragment -r -czstd /mount` to recompress existing data.

| Option | Description |
|--------|-------------|
| `compress=zstd` | Recommended default; good ratio and speed. Level can be set: `compress=zstd:3` (1-15, default 3) |
| `compress=lzo` | Fastest; lowest ratio — good for SSD or when CPU is the bottleneck |
| `compress=zlib` | Slowest; best ratio — rarely worth it over zstd |
| `compress-force=zstd` | Compress everything, including files that appear incompressible. Btrfs normally skips compression if first 128KiB doesn't compress well. |
| `nocompress` | Explicit no-compression (default) |

```bash
# /etc/fstab example with compression:
UUID=... /  btrfs  defaults,compress=zstd,space_cache=v2  0  0
```

### Space Cache

| Option | Description |
|--------|-------------|
| `space_cache=v2` | Recommended. Stores free-space cache as a special inode rather than in-memory tree. Faster mount on large filesystems. |
| `space_cache` | Legacy v1 — keep for kernels < 4.9 only |
| `nospace_cache` | Disables space cache — slows allocation, almost never desirable |
| `clear_cache` | Forces regeneration of space cache on next mount (recovery option) |

### Access Time

| Option | Description |
|--------|-------------|
| `noatime` | Do not update access time on reads — reduces writes, recommended for SSDs |
| `relatime` | Update atime only if mtime is newer (kernel default); good compromise |
| `strictatime` | Update atime on every read — default POSIX behavior, not recommended |

### CoW Control

| Option | Description |
|--------|-------------|
| `nodatacow` | Disable copy-on-write for data (metadata still uses CoW). Also disables checksums for data. Use for VM disk images, database files. Equivalent to `chattr +C` on a file/directory. |
| `nodatasum` | Disable data checksums without disabling CoW. Rarely useful — `nodatacow` already implies this. |

### SSD and Discard

| Option | Description |
|--------|-------------|
| `ssd` | Enables SSD optimizations (usually auto-detected). Spreads writes to reduce wear. |
| `discard=async` | Asynchronous TRIM — batches discard operations. Preferred over `discard` (synchronous) which causes latency spikes. Enable for SSDs if not using `fstrim` via cron/systemd. |

### Subvolume Selection

| Option | Description |
|--------|-------------|
| `subvol=@` | Mount a specific subvolume by path (relative to filesystem root) |
| `subvolid=256` | Mount a specific subvolume by numeric ID |

Each mount point in fstab typically mounts a different subvolume from the same filesystem:

```
UUID=...  /       btrfs  defaults,subvol=@,compress=zstd,space_cache=v2,noatime  0  0
UUID=...  /home   btrfs  defaults,subvol=@home,compress=zstd,space_cache=v2,noatime  0  0
```

### Autodefrag

| Option | Description |
|--------|-------------|
| `autodefrag` | Triggers defragmentation of small random writes in the background. Helps for databases and Vagrant/VM images **not** marked `nodatacow`. Not recommended for most general-purpose use — overhead outweighs benefit for typical workloads. |

---

## Common Subvolume Layout

Most distributions using Btrfs (Ubuntu, Fedora, openSUSE, Timeshift) follow the
`@`/`@home` convention. This separates the root filesystem from home directories so
they can be snapshotted or rolled back independently.

```
/dev/sda (Btrfs filesystem root — typically mounted at /mnt during setup)
├── @            ← mounted at /
├── @home        ← mounted at /home
├── @snapshots   ← mounted at /.snapshots (used by snapper)
└── @var-log     ← optional, to exclude /var/log from root snapshots
```

The filesystem root itself (subvolid=5) is usually not mounted during normal operation —
only the named subvolumes are. To access the raw filesystem root (e.g., to manage
snapshots manually), mount with `subvolid=5` or `subvol=/`.
