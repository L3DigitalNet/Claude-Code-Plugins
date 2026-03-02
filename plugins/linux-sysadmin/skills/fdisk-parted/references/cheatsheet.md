# fdisk / parted / gdisk Cheatsheet

## 1. List Existing Partitions

Start every partitioning session by inspecting the current layout.

```bash
# All disks and partitions
sudo fdisk -l

# Specific disk
sudo fdisk -l /dev/sdb
sudo parted /dev/sdb print
sudo gdisk -l /dev/sdb

# Quick visual tree with sizes and types
lsblk /dev/sdb
```

---

## 2. Create a New GPT Partition Table

For any disk > 2 TB, UEFI boot, or modern deployments. GPT is the correct default.

**Using gdisk (interactive):**
```bash
sudo gdisk /dev/sdb
# At gdisk prompt:
#   o   → create new GPT table (destroys existing data)
#   n   → new partition (accept defaults for full disk, or set start/end)
#   w   → write and exit
```

**Using parted (non-interactive):**
```bash
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary ext4 1MiB 100%
sudo partprobe /dev/sdb
sudo mkfs.ext4 /dev/sdb1
```

---

## 3. Create a New MBR Partition Table

For legacy BIOS systems, bootable USB drives, or disks < 2 TB that need MBR.

**Using fdisk (interactive):**
```bash
sudo fdisk /dev/sdb
# At fdisk prompt:
#   o   → create new MBR table (destroys existing data)
#   n   → new partition → primary → partition number → accept defaults
#   w   → write and exit
```

After writing:
```bash
sudo partprobe /dev/sdb
sudo mkfs.ext4 /dev/sdb1
```

---

## 4. Add a New Partition to an Existing GPT Disk

Adding a data partition to a disk that already has partitions (e.g., adding `/data`).

```bash
# Find the free space
sudo parted /dev/sdb print free

# Create partition in free space (non-interactive)
sudo parted /dev/sdb mkpart primary ext4 101GiB 100%

# Or interactively with gdisk
sudo gdisk /dev/sdb
# n → partition number → first sector → last sector → hex code (8300 = Linux)
# w to write

# Re-read the table and format
sudo partprobe /dev/sdb
lsblk /dev/sdb
sudo mkfs.ext4 /dev/sdb2
```

---

## 5. Grow a Partition (Online)

Extend an existing partition to use more space (e.g., after replacing with a larger disk
or extending a VM's virtual disk).

```bash
# Step 1: Identify the partition and its current end
sudo parted /dev/sdb print

# Step 2: Resize the partition to the new end (or 100%)
sudo parted /dev/sdb resizepart 1 100%

# Step 3: Inform the kernel
sudo partprobe /dev/sdb

# Step 4: Grow the filesystem (ext4 — can be done live on mounted fs)
sudo resize2fs /dev/sdb1

# For XFS (must be mounted)
sudo xfs_growfs /mountpoint

# For btrfs
sudo btrfs filesystem resize max /mountpoint
```

---

## 6. Delete a Partition

Remove a partition from the table. Data on the partition is lost.

```bash
# Using fdisk (interactive)
sudo fdisk /dev/sdb
# d → partition number → w

# Using parted (non-interactive)
sudo parted /dev/sdb rm 2

# Confirm it is gone
sudo partprobe /dev/sdb
lsblk /dev/sdb
```

---

## 7. Verify Partition Alignment

Misaligned SSD partitions cause performance penalties. Check and enforce 1 MiB alignment.

```bash
# Check alignment for partition 1 (optimal = aligned to physical sector boundaries)
sudo parted /dev/sdb align-check optimal 1

# Check all partitions
for i in 1 2 3 4; do
    sudo parted /dev/sdb align-check optimal "$i" 2>/dev/null
done

# When creating partitions, always use MiB start offsets:
sudo parted /dev/sdb mkpart primary ext4 1MiB 50GiB
sudo parted /dev/sdb mkpart primary ext4 50GiB 100%
```

Rule: start at `1MiB` minimum; all subsequent partition starts at MiB boundaries.

---

## 8. Convert MBR to GPT Without Data Loss

gdisk can convert an existing MBR table to GPT while preserving partitions.

```bash
# WARNING: Back up data first. Test on a non-critical disk before production.
sudo gdisk /dev/sdb

# At gdisk prompt:
#   Verify it reads the MBR correctly (shows partition list)
#   w   → write GPT (gdisk converts the in-memory MBR to GPT before writing)
#   y   → confirm

# After conversion, verify
sudo gdisk -l /dev/sdb
```

Conversion works because GPT stores a protective MBR record. UEFI firmware sees GPT;
legacy BIOS tools see a "whole disk" protective MBR entry.

---

## 9. Shrink a Partition (ext4 Only, Offline)

Shrinking is destructive if done wrong. Filesystem must be shrunk before the partition.

```bash
# Step 1: Unmount the filesystem
sudo umount /dev/sdb1

# Step 2: Check and repair the filesystem
sudo e2fsck -f /dev/sdb1

# Step 3: Shrink the filesystem (target size must fit all data + headroom)
sudo resize2fs /dev/sdb1 30G

# Step 4: Shrink the partition in parted (must be >= filesystem size)
sudo parted /dev/sdb resizepart 1 31GiB

# Step 5: Check
sudo e2fsck -f /dev/sdb1
lsblk /dev/sdb
```

XFS cannot be shrunk. btrfs can be shrunk online with `btrfs filesystem resize`.

---

## 10. Prepare a Disk for LVM

LVM typically uses a single partition spanning the full disk, type `LVM`.

```bash
# Create GPT with one partition spanning the whole disk, type 8e00 (Linux LVM)
sudo gdisk /dev/sdb
# n → 1 → default start → default end → 8e00 → w

# Or with parted
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary 1MiB 100%
sudo parted /dev/sdb set 1 lvm on

sudo partprobe /dev/sdb

# Initialize as LVM physical volume
sudo pvcreate /dev/sdb1

# Verify
sudo pvdisplay /dev/sdb1
```
