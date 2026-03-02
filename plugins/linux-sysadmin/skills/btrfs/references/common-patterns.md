# Btrfs Common Patterns

Each section is a complete, copy-paste-ready sequence. Adjust device paths, UUIDs,
and subvolume names for your system.

---

## 1. Create Btrfs Filesystem and Mount with Recommended Options

Single disk with zstd compression, v2 space cache, and no atime writes.

```bash
# Create filesystem with a label for easy fstab reference.
mkfs.btrfs -L mydata /dev/sda

# Mount the raw filesystem root to set up subvolumes.
mount /dev/sda /mnt

# Create top-level subvolumes (@ convention for Timeshift/snapper compatibility).
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

umount /mnt

# Mount each subvolume with recommended options.
mount -o subvol=@,compress=zstd,space_cache=v2,noatime LABEL=mydata /mnt
mount -o subvol=@home,compress=zstd,space_cache=v2,noatime LABEL=mydata /mnt/home
mount -o subvol=@snapshots,compress=zstd,space_cache=v2,noatime LABEL=mydata /mnt/.snapshots
```

`/etc/fstab` entries (replace UUID with output of `blkid /dev/sda`):

```
UUID=<uuid>  /            btrfs  subvol=@,compress=zstd,space_cache=v2,noatime  0  0
UUID=<uuid>  /home        btrfs  subvol=@home,compress=zstd,space_cache=v2,noatime  0  0
UUID=<uuid>  /.snapshots  btrfs  subvol=@snapshots,compress=zstd,space_cache=v2,noatime  0  0
```

---

## 2. Subvolume Layout: @ and @home (Ubuntu/Timeshift Pattern)

This layout is what Ubuntu's installer creates and what Timeshift expects. The
filesystem root (subvolid=5) is not mounted during normal operation.

```bash
# Inspect the layout of an existing Btrfs system:
mount -o subvolid=5 /dev/sda /mnt   # mount raw fs root
ls /mnt                              # should show @, @home, etc.
btrfs subvolume list /mnt            # list all subvolumes with IDs
umount /mnt
```

To add an `@snapshots` subvolume to an existing system that doesn't have one:

```bash
mount -o subvolid=5 /dev/sda /mnt
btrfs subvolume create /mnt/@snapshots
umount /mnt
# Add fstab entry and mkdir /.snapshots, then mount -a
```

---

## 3. Create and Use Snapshots

```bash
# Read-only snapshot (suitable as backup source or rollback point).
# Source must be mounted; snapshot is created at the given path.
btrfs subvolume snapshot -r / /.snapshots/root-$(date +%Y%m%d-%H%M%S)

# Read-write snapshot (can be booted into or modified).
btrfs subvolume snapshot / /.snapshots/root-rw-$(date +%Y%m%d)

# List all snapshots:
btrfs subvolume list / | grep snapshots

# Delete a snapshot (required to free the space it holds):
btrfs subvolume delete /.snapshots/root-20240115-120000
```

Snapshots are subvolumes. They appear in `btrfs subvolume list` and can be mounted
independently. Space is only reclaimed after deletion completes.

---

## 4. Rollback to a Snapshot

Btrfs does not have a single "rollback" command. The workflow is: delete the current
subvolume, rename the snapshot to take its place, then reboot.

```bash
# Boot from a live system or recovery environment first.
# Mount the raw filesystem root:
mount -o subvolid=5 /dev/sda /mnt

# Delete the broken root subvolume:
btrfs subvolume delete /mnt/@

# Rename the target snapshot to @:
mv /mnt/@snapshots/root-20240115-120000 /mnt/@

# If the snapshot was read-only, convert it to read-write first:
btrfs property set /mnt/@snapshots/root-20240115-120000 ro false
mv /mnt/@snapshots/root-20240115-120000 /mnt/@

umount /mnt
reboot
```

Alternatively, change the default subvolume so the system boots from the snapshot
without deleting anything:

```bash
# Get the snapshot's subvolume ID:
btrfs subvolume list /mnt | grep root-20240115
# Set it as default (replaces ID 256 with the snapshot's ID):
btrfs subvolume set-default <id> /mnt
umount /mnt
reboot
```

---

## 5. Send/Receive for Backup (Manual and btrbk)

`btrfs send` streams a snapshot as a byte stream; `btrfs receive` writes it to a
destination. The source snapshot must be read-only.

```bash
# Initial full send to a backup location:
btrfs send /.snapshots/root-20240115 | btrfs receive /backup/

# Incremental send (much smaller — only changes since the parent snapshot):
btrfs send -p /.snapshots/root-20240115 /.snapshots/root-20240116 | btrfs receive /backup/

# Send to a remote host over SSH:
btrfs send /.snapshots/root-20240116 | ssh backup-host "btrfs receive /backup/"

# Incremental to remote:
btrfs send -p /.snapshots/root-20240115 /.snapshots/root-20240116 \
  | ssh backup-host "btrfs receive /backup/"
```

Using btrbk (recommended over manual scripting):

```bash
# Install:
apt install btrbk   # or dnf install btrbk

# Minimal /etc/btrbk/btrbk.conf:
snapshot_preserve_min  2d
snapshot_preserve      7d 4w 6m

volume /
  subvolume @
    snapshot_dir /.snapshots
    target ssh://backup-host/backup/myhost
```

```bash
btrbk run        # create snapshots and transfer
btrbk list       # show snapshots and transfer status
btrbk dryrun     # preview without executing
```

---

## 6. Balance to Fix ENOSPC Metadata Issue

When `df` shows free space but writes fail with ENOSPC, Btrfs has exhausted its
allocated metadata chunks. Balance reclaims space from partially-used chunks.

```bash
# Check actual allocation state:
btrfs filesystem usage /

# Rebalance data chunks that are less than 50% full (safest first step):
btrfs balance start -dusage=50 /

# If metadata is nearly full, rebalance metadata chunks too:
btrfs balance start -musage=50 /

# Full balance (slow on large filesystems — use usage filter to limit scope):
btrfs balance start /

# Monitor progress:
btrfs balance status /

# Cancel a running balance:
btrfs balance cancel /
```

A balance can be safely interrupted and resumed. On very full filesystems, run
balance with `-dusage=5` first (only near-empty chunks) to free a little space,
then raise the threshold progressively.

---

## 7. RAID-1 Across Two Disks

Both data and metadata are mirrored. Either disk can fail and the filesystem remains accessible.

```bash
# Create during mkfs:
mkfs.btrfs -d raid1 -m raid1 -L myraid /dev/sda /dev/sdb

# Convert an existing single-disk filesystem to RAID-1 after adding a second disk:
btrfs device add /dev/sdb /
btrfs balance start -dconvert=raid1 -mconvert=raid1 /

# Verify RAID profile after balance:
btrfs filesystem usage /
```

After a disk failure, mount in degraded mode to recover data:

```bash
mount -o degraded /dev/sda /mnt
# Replace the failed disk:
btrfs replace start /dev/sda /dev/sdc /mnt
btrfs replace status /mnt
```

---

## 8. Add a Disk to an Existing Filesystem

```bash
# Add the device (filesystem is live; no unmount needed):
btrfs device add /dev/sdc /

# Verify it was added:
btrfs filesystem show /

# Rebalance to distribute existing data onto the new disk.
# Without balance, new writes go to the new disk but old data stays on the original.
btrfs balance start -dusage=75 /
```

---

## 9. Enable Compression on Existing Data

Compression applies to new writes by default. To recompress files already on disk:

```bash
# Mount with compression (or add to fstab):
mount -o remount,compress=zstd /

# Recompress all existing files (runs defrag + rewrite with compression):
btrfs filesystem defragment -r -czstd /

# Check compression ratio:
compsize /home   # requires 'compsize' package (apt install btrfs-compsize)
```

Note: `defragment` breaks shared extents between snapshots — CoW links are lost.
Run it on a subvolume that does not have active snapshots, or accept the space cost.

---

## 10. Automated Snapshots with Snapper

Snapper integrates with systemd timers to take hourly/daily/weekly snapshots and
manages retention automatically.

```bash
# Install:
apt install snapper   # or dnf install snapper

# Create a snapper config for the root subvolume:
snapper -c root create-config /

# Edit retention policy (optional):
snapper -c root set-config \
  "TIMELINE_MIN_AGE=1800" \
  "TIMELINE_LIMIT_HOURLY=5" \
  "TIMELINE_LIMIT_DAILY=7" \
  "TIMELINE_LIMIT_WEEKLY=0" \
  "TIMELINE_LIMIT_MONTHLY=0" \
  "TIMELINE_LIMIT_YEARLY=0"

# Enable the systemd timers:
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

# List snapshots:
snapper -c root list

# Manually create a snapshot:
snapper -c root create --description "before upgrade"

# Diff between two snapshots:
snapper -c root diff 1..3

# Rollback to snapshot #3:
snapper -c root rollback 3
```
