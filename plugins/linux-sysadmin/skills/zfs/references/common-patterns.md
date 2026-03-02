# ZFS Common Patterns

Commands use `/dev/disk/by-id/` paths throughout — never use `/dev/sdX` names in pool
configs because they can change across reboots. Find by-id names with:
`ls -la /dev/disk/by-id/ | grep -v part`

---

## 1. Create a Basic Mirror Pool and First Dataset

A 2-disk mirror survives one disk failure. Add a third disk as a hot spare with `spare`.

```bash
# Replace with actual disk IDs from /dev/disk/by-id/
DISK1="ata-WDC_WD4003FZEX-00Z4SA0_WD-WCC7K5JNRYEL"
DISK2="ata-WDC_WD4003FZEX-00Z4SA0_WD-WCC7K5JNRYES"

# Create the pool.
# -o ashift=12: 4K sector alignment — required for 4Kn and AF drives, safe for all.
# -O compression=lz4: enable compression on all datasets by default.
# -O atime=off: disable access-time updates to reduce write amplification.
# -O xattr=sa: store extended attributes in inodes for better performance.
# -m /mnt/tank: mount the root dataset at /mnt/tank.
zpool create -o ashift=12 \
    -O compression=lz4 \
    -O atime=off \
    -O xattr=sa \
    -m /mnt/tank \
    tank mirror /dev/disk/by-id/$DISK1 /dev/disk/by-id/$DISK2

# Verify pool is ONLINE.
zpool status tank

# Create a dataset. Inherits compression and atime from pool root.
zfs create tank/data

# Create a dataset with a quota (hard limit).
zfs create -o quota=100G tank/users/alice
```

---

## 2. Create RAID-Z1, RAID-Z2, and RAID-Z3 Pools

RAID-Z1 tolerates 1 disk failure (minimum 3 disks), RAID-Z2 tolerates 2 (minimum 4),
RAID-Z3 tolerates 3 (minimum 5). More disks in a single RAID-Z vdev increases rebuild time —
consider using multiple smaller RAID-Z vdevs for large arrays.

```bash
# RAID-Z1: 3 disks, 1 parity disk. Net usable = 2 × disk size.
zpool create -o ashift=12 -O compression=lz4 -O atime=off \
    tank raidz /dev/disk/by-id/disk1 /dev/disk/by-id/disk2 /dev/disk/by-id/disk3

# RAID-Z2: 4 disks, 2 parity. Net usable = 2 × disk size. Tolerates 2 failures.
zpool create -o ashift=12 -O compression=lz4 -O atime=off \
    tank raidz2 /dev/disk/by-id/disk1 /dev/disk/by-id/disk2 \
                /dev/disk/by-id/disk3 /dev/disk/by-id/disk4

# RAID-Z3: 5 disks, 3 parity. Net usable = 2 × disk size. Tolerates 3 failures.
zpool create -o ashift=12 -O compression=lz4 -O atime=off \
    tank raidz3 /dev/disk/by-id/disk1 /dev/disk/by-id/disk2 \
                /dev/disk/by-id/disk3 /dev/disk/by-id/disk4 /dev/disk/by-id/disk5

# Add a second RAID-Z1 vdev to an existing pool (stripes across both vdevs):
zpool add tank raidz /dev/disk/by-id/disk6 /dev/disk/by-id/disk7 /dev/disk/by-id/disk8
```

---

## 3. Snapshot and Rollback

Snapshots are instant and space-efficient. They consume space only for blocks that have
changed since the snapshot was taken.

```bash
# Create a snapshot. Name can be a date, tag, or description.
zfs snapshot tank/data@2025-01-15

# Create snapshots of a dataset and all its children at once (-r = recursive).
zfs snapshot -r tank@2025-01-15

# List snapshots.
zfs list -t snapshot
zfs list -t snapshot -r tank/data  # Limit to one dataset

# View snapshot space usage.
zfs list -t snapshot -o name,used,referenced,written

# Roll back to a snapshot. This destroys all changes since the snapshot.
# -r also destroys any snapshots taken after the target snapshot.
zfs rollback tank/data@2025-01-15

# Access snapshot contents without rolling back (read-only).
ls /mnt/tank/data/.zfs/snapshot/2025-01-15/
# Or make snapdir visible: zfs set snapdir=visible tank/data

# Clone a snapshot into a new writable dataset.
zfs clone tank/data@2025-01-15 tank/data-restored
# Promote the clone to make it independent (breaks dependency on snapshot).
zfs promote tank/data-restored
```

---

## 4. Automated Snapshots with Systemd Timer

A simple approach using two systemd units. For more sophisticated rotation (hourly/daily/weekly
with configurable retention), use `zfs-auto-snapshot` or `sanoid`.

```ini
# /etc/systemd/system/zfs-snapshot-daily.service
[Unit]
Description=ZFS daily snapshot of tank

[Service]
Type=oneshot
# Snapshot all datasets under tank recursively with a date-based name.
ExecStart=/usr/sbin/zfs snapshot -r tank@daily-%(%Y-%m-%d)T
# Destroy snapshots older than 30 days.
ExecStart=/bin/bash -c 'zfs list -H -o name -t snapshot -r tank | grep "@daily-" | head -n -30 | xargs -r zfs destroy'
```

```ini
# /etc/systemd/system/zfs-snapshot-daily.timer
[Unit]
Description=Run ZFS daily snapshot at 02:00

[Timer]
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl enable --now zfs-snapshot-daily.timer
systemctl list-timers zfs-snapshot-daily.timer
```

---

## 5. Send/Receive Replication (Local and Remote via SSH)

`zfs send` streams a snapshot; `zfs receive` writes it. Use `-i` for incremental sends —
the base snapshot must exist on both source and destination.

```bash
# Full send to a local pool (initial replication).
zfs snapshot tank/data@rep-$(date +%Y%m%d)
zfs send tank/data@rep-20250115 | zfs receive backup/data

# Incremental send (only changes since last snapshot).
# The @rep-20250114 snapshot must exist on both source and backup pool.
zfs send -i tank/data@rep-20250114 tank/data@rep-20250115 \
    | zfs receive backup/data

# Remote replication over SSH.
# -R: include all descendant datasets.
# mbuffer: optional buffer to smooth out I/O bursts (install with apt/dnf).
zfs send -R tank/data@rep-20250115 \
    | ssh backup-host "zfs receive -F backup/data"

# Remote incremental with mbuffer and compression for slow links.
zfs send -i @rep-20250114 tank/data@rep-20250115 \
    | mbuffer -s 128k -m 1G \
    | ssh -c aes128-gcm@openssh.com backup-host "mbuffer -s 128k -m 1G | zfs receive backup/data"

# Resume an interrupted send (OpenZFS 0.7+).
# On the receiving side, get the resume token:
RESUME_TOKEN=$(zfs get -H receiveresume tank/data@rep-20250115 | awk '{print $3}')
# Continue from where it stopped:
zfs send -t "$RESUME_TOKEN" | ssh backup-host "zfs receive backup/data"
```

---

## 6. Encrypted Dataset Setup

Encryption is set at creation and cannot be changed. A child dataset inherits the parent's
encryption key by default, but can have its own key. Load keys at boot via systemd or
`/etc/zfs/zfs-list.cache`.

```bash
# Create an encrypted dataset with a passphrase.
zfs create -o encryption=aes-256-gcm \
           -o keyformat=passphrase \
           -o keylocation=prompt \
           tank/secrets
# Prompts for passphrase twice.

# Create an encrypted dataset with a raw keyfile (32 random bytes for aes-256).
dd if=/dev/urandom bs=32 count=1 of=/etc/zfs/keys/tank-data.key
chmod 400 /etc/zfs/keys/tank-data.key

zfs create -o encryption=aes-256-gcm \
           -o keyformat=raw \
           -o keylocation=file:///etc/zfs/keys/tank-data.key \
           tank/data

# After reboot, load the key and mount:
zfs load-key tank/data
zfs mount tank/data

# Or load all keys:
zfs load-key -a

# Check key status:
zfs get keystatus tank/data

# Unload (lock) the dataset:
zfs umount tank/data
zfs unload-key tank/data

# Auto-load key at boot with systemd (requires ZFS systemd units):
# Set keylocation to a file on a local encrypted volume, or write a systemd unit
# that calls `zfs load-key` before `zfs-mount.service`.
```

---

## 7. Replace a Failed Disk

When a disk fails in a redundant pool (mirror or RAID-Z), the pool becomes DEGRADED but
remains online and accessible. Replace promptly to restore redundancy.

```bash
# Step 1: Identify the failed device.
zpool status -v tank
# Look for a device in FAULTED, REMOVED, or UNAVAIL state.
# Note the device name shown in the output (often a /dev/disk/by-id/ path or sdX name).

# Step 2: If the disk is hot-swappable, physically replace it.
# The OS may need to re-scan: echo "- - -" > /sys/class/scsi_host/host0/scan

# Step 3: Find the new disk's by-id path.
ls -la /dev/disk/by-id/ | grep -v part

# Step 4: Replace. ZFS starts resilvering automatically.
# OLD_DEV: the device path exactly as shown in `zpool status`
# NEW_DEV: the new disk's /dev/disk/by-id/... path
zpool replace tank /dev/disk/by-id/OLD_DEV /dev/disk/by-id/NEW_DEV

# Step 5: Monitor resilver progress.
watch zpool status tank
# Resilver time depends on data volume and disk speed; a few TB can take several hours.

# If the disk was removed and the slot is being re-used with the same path,
# ZFS may auto-replace if autoreplace=on is set on the pool.
```

---

## 8. Performance Tuning

### ARC Size Limit

By default ZFS uses all available RAM for ARC. Limit it if other services are starved.

```bash
# Check current ARC max (bytes):
cat /sys/module/zfs/parameters/zfs_arc_max

# Set ARC max to 4 GB at runtime (does not survive reboot):
echo $((4 * 1024 * 1024 * 1024)) > /sys/module/zfs/parameters/zfs_arc_max

# Persist across reboots:
cat > /etc/modprobe.d/zfs.conf <<'EOF'
# Limit ZFS ARC to 4 GB. Without this, ZFS claims all available RAM.
options zfs zfs_arc_max=4294967296
EOF
update-initramfs -u  # Debian/Ubuntu; or dracut --regenerate-all on RHEL
```

### recordsize for Databases

Set before writing data — `recordsize` changes apply to new writes only.

```bash
# PostgreSQL: match ZFS recordsize to PostgreSQL block size (8K default).
zfs set recordsize=8K tank/postgres

# MySQL/InnoDB: InnoDB default page size is 16K.
zfs set recordsize=16K tank/mysql

# Large files (backups, media, VM images): use the default or larger.
zfs set recordsize=1M tank/backups

# Check current setting:
zfs get recordsize tank/postgres
```

### Compression

```bash
# lz4 is fast with minimal CPU overhead — enable everywhere.
zfs set compression=lz4 tank

# zstd gives better compression ratios at moderate CPU cost.
# Good for cold storage, backups, infrequently accessed data.
zfs set compression=zstd tank/backups

# Check compression ratio:
zfs get compressratio tank
zfs list -o name,compression,compressratio -r tank
```

### atime and xattr

```bash
# Disable atime to eliminate one write per read:
zfs set atime=off tank

# Store xattrs in inodes instead of directories (faster for apps that use xattrs):
zfs set xattr=sa tank
```

---

## 9. Scrub Schedule and Monitoring

Scrubs verify every block against its checksum. Monthly is a common baseline;
weekly for pools with critical data.

```bash
# Run a scrub immediately:
zpool scrub tank

# Cancel an in-progress scrub:
zpool scrub -s tank

# Check scrub status and last result:
zpool status tank | grep -A5 scan

# Systemd timer for monthly scrub (Debian/Ubuntu include this in zfs-zed package).
# If not present, create manually:
cat > /etc/systemd/system/zfs-scrub-monthly.service <<'EOF'
[Unit]
Description=Monthly ZFS scrub

[Service]
Type=oneshot
ExecStart=/usr/sbin/zpool scrub tank
EOF

cat > /etc/systemd/system/zfs-scrub-monthly.timer <<'EOF'
[Unit]
Description=Run ZFS scrub on the first Sunday of each month

[Timer]
OnCalendar=Sun *-*-1..7 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable --now zfs-scrub-monthly.timer

# ZED (ZFS Event Daemon) sends email on errors:
# Install: apt install zfs-zed
# Config:  /etc/zfs/zed.d/zed.rc — set ZED_EMAIL_ADDR
```

---

## 10. Expand Pool (Add Vdev or Grow Existing Disks)

### Add a new vdev to an existing pool

Adding a vdev stripes data across all vdevs. The new vdev must match the existing vdev type
(mirror to mirror, RAID-Z to RAID-Z of the same width) for balanced performance.

```bash
# Add a second mirror vdev to a pool that already has one mirror vdev:
zpool add tank mirror /dev/disk/by-id/disk3 /dev/disk/by-id/disk4

# Verify the new layout:
zpool status tank
```

### Grow existing disks (replace with larger disks)

Replace each disk one at a time; wait for resilver to complete between replacements.
After all disks are replaced, expand the pool.

```bash
# Enable autoexpand so ZFS uses the new space automatically:
zpool set autoexpand=on tank

# Replace disk1 with a larger disk and wait for resilver.
zpool replace tank /dev/disk/by-id/old-disk1 /dev/disk/by-id/new-larger-disk1
watch zpool status tank  # Wait for "resilver in progress" to disappear

# After all disks are replaced, online-expand if autoexpand did not trigger:
zpool online -e tank /dev/disk/by-id/new-larger-disk1

# Check the new size:
zpool list tank
```
