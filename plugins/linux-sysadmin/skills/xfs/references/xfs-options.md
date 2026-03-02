# XFS Options Reference

## mkfs.xfs Flags

### `-b` — Block size
```
mkfs.xfs -b size=4096 /dev/sdXN
```
Sets the filesystem block size. Valid values: 512–65536 (must be a power of 2). Default is 4096. Larger blocks improve throughput on sequential workloads; smaller blocks reduce internal fragmentation for many tiny files. Rarely changed from default.

### `-d` — Data section options
```
mkfs.xfs -d agcount=8,sunit=128,swidth=512 /dev/sdXN
```
| Sub-option | Purpose |
|------------|---------|
| `agcount=N` | Number of allocation groups. More AGs increase parallelism on multicore systems. Default is computed from size; 4–8 is typical. |
| `sunit=N` | RAID stripe unit in 512-byte sectors. Aligns allocations to the RAID stripe. Match to your RAID chunk size (e.g., 64K chunk = 128 sectors). |
| `swidth=N` | RAID stripe width in 512-byte sectors. `sunit × number_of_data_disks`. Required alongside `sunit` for correct RAID alignment. |

Use `sunit`/`swidth` on hardware or software RAID (mdraid, LVM striped). Misalignment causes write amplification.

### `-i` — Inode options
```
mkfs.xfs -i size=512 /dev/sdXN
```
| Sub-option | Purpose |
|------------|---------|
| `size=N` | Inode size in bytes. Default 512; 256 is valid but limits inline extended attributes. Increase to 1024 for workloads with many extended attributes (SELinux, ACLs). |
| `maxpct=N` | Maximum percentage of filesystem space used for inodes. Default 25. |

### `-l` — Log (journal) options
```
mkfs.xfs -l size=128m,internal=1,version=2 /dev/sdXN
```
| Sub-option | Purpose |
|------------|---------|
| `size=N` | Log size. Larger log improves write throughput under heavy metadata load. Minimum 512 blocks; typical range 32m–2g. |
| `internal=1` | Log resides inside the data device (default). Set `internal=0` to place on a separate device (external log). |
| `version=2` | Log format version. Version 2 is required for large block sizes and is the default on modern xfsprogs. |

External log (`logdev`) on a low-latency device (SSD/NVMe) significantly reduces metadata commit latency on spinning disks.

### `-n` — Naming options
```
mkfs.xfs -n ftype=1 /dev/sdXN
```
| Sub-option | Purpose |
|------------|---------|
| `ftype=1` | Stores file type in directory entries. Required for overlayfs (Docker overlay2, container runtimes). Default on xfsprogs >= 3.2.3. Verify with `xfs_info` — look for `ftype=1` in naming section. |

### `-L` — Label
```
mkfs.xfs -L mydata /dev/sdXN
```
Sets a filesystem label up to 12 characters. Used to mount by label (`LABEL=mydata` in fstab). Can be changed later with `xfs_admin -L`.

### `-f` — Force overwrite
```
mkfs.xfs -f /dev/sdXN
```
Overwrite an existing filesystem signature. Required when reformatting a device that already contains a filesystem. Use with care.

---

## Mount Options

Add to the options field in `/etc/fstab` or `-o` with `mount`.

| Option | Purpose | When to use |
|--------|---------|-------------|
| `noatime` | Do not update access time on reads. | Nearly always — eliminates metadata writes on every file read. |
| `logbsize=N` | In-memory log buffer size (bytes). Values: 32k–256k. | Increase to 256k on high-metadata-write workloads (databases, build systems). |
| `logbufs=N` | Number of in-memory log buffers (2–8). | Pair with `logbsize` to increase write throughput. |
| `allocsize=N` | Speculative preallocation size for writes. Default 64k. | Increase (e.g., 1m) for streaming write workloads to reduce fragmentation. |
| `inode64` | Allocate inodes across all allocation groups. | Large filesystems (>1TB) to prevent inode exhaustion in low AGs. Implicit on 64-bit kernels with modern xfsprogs. |
| `prjquota` | Enable project quotas. | Directory-tree quotas (containers, user home dirs, project spaces). |
| `uquota` / `usrquota` | Enable user quotas. | Per-user disk usage enforcement. |
| `gquota` / `grpquota` | Enable group quotas. | Per-group disk usage enforcement. |
| `discard` | Issue TRIM/discard on block free (for SSDs). | SSDs and thin-provisioned LUNs. Note: can reduce write performance; consider `fstrim` via cron instead. |
| `norecovery` | Skip journal replay on mount. | Read-only forensic access to an unclean filesystem only. **Never use on a writable mount.** |

Quota options (`prjquota`, `uquota`, `gquota`) are mutually exclusive in some combinations. XFS supports user+group together, but project quota is separate. Check kernel version for supported combinations.

---

## xfs_admin Options

`xfs_admin` modifies filesystem metadata. **The filesystem must be unmounted.**

| Option | Purpose | Example |
|--------|---------|---------|
| `-L label` | Set or change the filesystem label (max 12 chars). | `xfs_admin -L backups /dev/sdb1` |
| `-L --` | Clear the label. | `xfs_admin -L -- /dev/sdb1` |
| `-U uuid` | Set a specific UUID. | `xfs_admin -U 550e8400-e29b-41d4-a716-446655440000 /dev/sdb1` |
| `-U generate` | Generate and assign a new random UUID. | `xfs_admin -U generate /dev/sdb1` |
| `-U nil` | Set UUID to all zeros (rarely needed). | `xfs_admin -U nil /dev/sdb1` |
| `-l` | Print the current label. | `xfs_admin -l /dev/sdb1` |
| `-u` | Print the current UUID. | `xfs_admin -u /dev/sdb1` |

Changing the UUID is needed after cloning a disk to avoid UUID conflicts in `/etc/fstab` or `initramfs`. After changing, update `/etc/fstab` if you mount by UUID.
