# ext4 Options Reference

## mkfs.ext4 Options

| Option | Value | Purpose | When to use |
|--------|-------|---------|-------------|
| `-b` | `1024`, `2048`, `4096` | Block size in bytes | Default 4096 is correct for most workloads; use 1024 for filesystems with many tiny files (rare) |
| `-I` | `128`, `256`, `512` | Inode size in bytes | Default 256; use 128 to pack more inodes on small partitions; use 512 if storing many extended attributes (SELinux, ACLs) |
| `-i` | bytes-per-inode (e.g. `4096`) | Ratio of filesystem bytes per inode — controls total inode count | Lower value (e.g. `-i 4096`) creates more inodes for small-file workloads (mail, containers); higher (e.g. `-i 65536`) for large-file workloads to reduce metadata overhead |
| `-m` | percentage (e.g. `1`, `5`) | Reserved block percentage for root | Default 5%; set to 1% or 0% for dedicated data disks where root never writes; keep at 5% for system partitions |
| `-L` | string | Filesystem label | Use for human-readable fstab entries (`LABEL=data`) instead of UUIDs; max 16 characters |
| `-U` | UUID string or `random`/`clear` | Set filesystem UUID at creation | Useful after cloning to avoid UUID conflicts; `random` generates a new UUID |
| `-j` | — | Create journal (default on for ext4) | Implicit with ext4; explicitly needed only when upgrading ext2/3 |
| `-J size=N` | size in MiB | Journal size | Increase for write-heavy workloads to reduce journal wrap frequency; default is computed from filesystem size |
| `-J location=N` | block number | Place journal at specific block | Rare; used to put journal on a faster region of a spinning disk |
| `-E lazy_itable_init=0` | — | Initialize inode tables immediately instead of in the background | Use when you need the filesystem fully ready immediately after mkfs; default 1 means background init, which can cause slow first-use e2fsck |
| `-E discard` | — | Enable discard (TRIM) in the filesystem metadata | For SSDs/NVMe; tells the filesystem to issue discards on block free; can also enable via mount option |
| `-O ^has_journal` | — | Create ext4 without a journal (ext4 in no-journal mode) | Rarely correct; only for read-only media or throwaway scratch space where data loss is acceptable |

## Mount Options (`/etc/fstab` or `mount -o`)

| Option | Purpose | When to use |
|--------|---------|-------------|
| `noatime` | Disables all access time updates on reads | High-throughput read workloads, SSDs, any filesystem where atime is not needed |
| `relatime` | Updates atime only when atime is older than mtime (default) | Default behavior; reasonable for general use |
| `errors=remount-ro` | Remount read-only on filesystem error (default) | Default and safest; prevents further corruption on error |
| `errors=continue` | Log the error and continue | Use only when availability matters more than data integrity (rare) |
| `errors=panic` | Kernel panic on filesystem error | High-reliability systems where halting is safer than continuing with a corrupt fs |
| `data=journal` | Write data to journal before writing to main filesystem | Maximum data safety; significant write overhead; use for databases requiring strong durability |
| `data=ordered` | Write data to disk before committing metadata to journal (default) | Default and correct for most workloads; good balance of safety and performance |
| `data=writeback` | Metadata journaled; data writes not ordered relative to metadata | Highest write throughput; risk of stale data after crash (file exists, old content); use only with application-level durability (databases with their own journaling) |
| `barrier=0` | Disable write barriers | Unsafe unless the storage guarantees ordering (battery-backed cache); disabling barriers with `data=ordered` can cause corruption |
| `commit=N` | Journal commit interval in seconds (default 5) | Increase (e.g. 30) to reduce journal write frequency at the cost of more data exposure window |
| `journal_async_commit` | Allows journal commits to overlap with data writes | Minor throughput gain; safe for most workloads |
| `noload` | Skip journal replay on mount | Emergency option when journal is corrupt; mounts the filesystem without replaying outstanding transactions — may expose inconsistency |
| `discard` | Issue TRIM/discard commands to storage as blocks are freed | SSDs and NVMe; can be replaced by periodic `fstrim` runs (less write amplification); not recommended for spinning disks |
| `nofail` | Continue booting if the filesystem fails to mount | Correct for non-essential data disks; prevents boot failure if a disk is missing |
| `x-systemd.automount` | Mount on first access rather than at boot | Slow or optional filesystems; reduces boot time |

## tune2fs Options

| Option | Value | Purpose | When to use |
|--------|-------|---------|-------------|
| `-l` | — | Show all filesystem parameters | First step in any ext4 diagnosis |
| `-m` | percentage | Change reserved block percentage | Lower to 1% on large data disks to reclaim space; change is immediate and online |
| `-c` | count | Set max mount count before forced fsck | Set to -1 to disable mount-count-based fsck; set to a number for periodic checks |
| `-i` | interval (e.g. `1m`, `6m`, `0`) | Set time-based fsck interval | `0` disables; `1m` forces fsck monthly; useful on servers with regular maintenance windows |
| `-e` | `continue`, `remount-ro`, `panic` | Change error behavior | Match fstab `errors=` setting; change without remounting |
| `-U` | `random`, `clear`, UUID string | Change filesystem UUID | After disk clone to resolve UUID conflicts; update fstab after changing |
| `-L` | label string | Change filesystem label | Update human-readable label; reflected immediately via `blkid` |
| `-o journal_data_writeback` | — | Switch to writeback journal mode | Only for databases with their own crash recovery; dangerous without barriers |
| `-o ^journal_data_writeback` | — | Remove writeback flag, restore default | Revert to ordered mode |
| `-O dir_index` | — | Enable htree directory indexing | Already default on ext4; use when upgrading old ext2/3 filesystems |
| `-E discard` | — | Enable discard support flag | For SSD; enables TRIM during normal operation |
| `-j` | — | Add journal to an ext2/3 filesystem | Upgrading legacy filesystems to journaled operation |
| `-J size=N` | MiB | Change journal size | Resize journal for heavy write workloads; requires unmounted filesystem |
