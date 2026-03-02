# df Cheatsheet

## 1. Quick Disk Space Overview

The go-to first command. Excludes virtual filesystems for a clean view.

```bash
df -h -x tmpfs -x devtmpfs
```

Sample output:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   38G  9.4G  81% /
/dev/sda2       200G  145G   45G  77% /home
/dev/sdb1       1.9T  1.2T  600G  68% /data
```

---

## 2. Find Which Filesystem Is Full

Show all filesystems sorted by use percentage, highest first.

```bash
df -h | sort -k5 -rh | head -20
```

Skipping the header line cleanly:

```bash
df -h | (read -r header; echo "$header"; sort -k5 -rh)
```

---

## 3. Check a Specific Path

Report which filesystem owns a path and how full it is.

```bash
df -h /var/log
df -h /var/lib/docker
df -h /tmp
```

Useful when a process reports "no space left" — confirms which mount is full.

---

## 4. Inode Usage

Inode exhaustion returns the same error as a full disk. Check both.

```bash
# Block usage
df -h

# Inode usage (same flags, -i switches the metric)
df -i

# Side-by-side: filesystem type + inode stats
df -iT -x tmpfs -x devtmpfs
```

High inode use with low block use is typical of directories with millions of small files
(mail queues, session stores, log directories with per-request files).

---

## 5. Show Filesystem Types

Useful when diagnosing filesystem-specific behavior (btrfs, xfs, ext4, zfs, overlay).

```bash
df -hT
df -hT -x tmpfs -x devtmpfs -x squashfs
```

Filter to only real block-backed filesystems:

```bash
df -hT | grep -E "ext4|xfs|btrfs|zfs|vfat"
```

---

## 6. Add a Total Line

Get the combined total of all listed filesystems.

```bash
df -h --total
df -h -x tmpfs -x devtmpfs --total
```

The `total` row at the bottom sums all included filesystems. Useful for capacity
planning across multiple data disks.

---

## 7. Find Deleted Files Holding Disk Space

`df` shows space used; `du` shows space accounted by files. The gap is deleted-but-open files.

```bash
# Confirm gap exists
df -h /
du -sh /*

# Find the processes holding deleted file descriptors
sudo lsof +L1

# Kill or restart the process to release the blocks
sudo systemctl restart myapp
```

---

## 8. Docker Storage Accounting

Docker's overlayfs layers appear as a single large filesystem under `/var/lib/docker`.
Use Docker's own commands alongside `df`.

```bash
# Overall docker disk usage
docker system df

# Verbose breakdown by image/container/volume
docker system df -v

# Where docker data lives on the host
df -h /var/lib/docker

# Reclaim unused layers, stopped containers, dangling images
docker system prune -f
docker system prune --volumes -f   # Also removes unnamed volumes — use with care
```

---

## 9. Script-Friendly Output

For use in monitoring scripts or alerting pipelines.

```bash
# POSIX output: 512-byte blocks, no locale-specific formatting
df -P

# 1K blocks, predictable column positions
df -k

# Extract use% for a specific mount, strip the % sign
df -P /data | awk 'NR==2 {print $5}' | tr -d '%'

# Alert if any filesystem exceeds 85%
df -P -x tmpfs -x devtmpfs | awk 'NR>1 && $5+0 > 85 {print "WARN:", $6, "is at", $5}'
```

---

## 10. btrfs-Specific Usage

Standard `df` output for btrfs is misleading due to copy-on-write and compression.

```bash
# df gives allocation, not consumption
df -h /data

# btrfs-native usage breakdown (data, metadata, system, unallocated)
btrfs filesystem df /data

# Full usage summary including compression ratio
btrfs filesystem usage /data

# Check btrfs snapshots consuming space
btrfs subvolume list /data
btrfs subvolume show /data/.snapshots/1
```

Always use `btrfs filesystem usage` as the authoritative source on btrfs volumes.
