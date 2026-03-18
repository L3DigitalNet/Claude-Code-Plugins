---
name: fdisk-parted
description: >
  fdisk, parted, and gdisk create and modify disk partition tables (MBR and GPT).
  Use when partitioning a disk, creating or deleting partitions, setting up GPT or
  MBR layouts, inspecting partition tables, or resizing partitions.
  MUST consult when partitioning disks with fdisk, parted, or gdisk.
triggerPhrases:
  - "fdisk"
  - "parted"
  - "gdisk"
  - "partition"
  - "partition table"
  - "GPT"
  - "MBR"
  - "create partition"
  - "resize partition"
  - "disk setup"
  - "new disk partitioning"
  - "format disk"
  - "partition scheme"
  - "4K alignment"
  - "partition alignment"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binaries** | `fdisk`, `parted`, `gdisk` |
| **Config** | No persistent config — invoked directly or interactively |
| **Logs** | No persistent logs — changes written directly to disk |
| **Type** | CLI tools |
| **Install** | `apt install fdisk parted gdisk` / `dnf install util-linux parted gdisk` |

## Quick Start

```bash
sudo apt install fdisk parted gdisk
sudo fdisk -l                           # list all disks and partitions
sudo parted /dev/sdb mklabel gpt        # create GPT partition table
sudo parted /dev/sdb mkpart primary ext4 1MiB 100%  # create partition
sudo partprobe /dev/sdb                 # inform kernel of changes
```

## Tool Selection Guide

| Use case | Tool |
|----------|------|
| MBR partitioning (legacy BIOS, < 2 TB, < 4 partitions common) | `fdisk` |
| GPT partitioning with advanced features | `gdisk` |
| Non-interactive scripting, LVM/RAID prep | `parted` |
| Converting MBR to GPT without data loss | `gdisk` (hybrid) |
| Resize a partition | `parted resizepart` |
| Align-check partitions | `parted align-check` |

## Key Operations

| Task | Command |
|------|---------|
| List all partitions on all disks | `sudo fdisk -l` |
| List partitions on a specific disk | `sudo fdisk -l /dev/sdb` |
| Interactive MBR partition editor | `sudo fdisk /dev/sdb` |
| Interactive GPT partition editor | `sudo gdisk /dev/sdb` |
| parted interactive session | `sudo parted /dev/sdb` |
| parted: print partition table | `sudo parted /dev/sdb print` |
| parted: create GPT table | `sudo parted /dev/sdb mklabel gpt` |
| parted: create MBR table | `sudo parted /dev/sdb mklabel msdos` |
| parted: create a partition (non-interactive) | `sudo parted /dev/sdb mkpart primary ext4 1MiB 100%` |
| parted: check partition alignment | `sudo parted /dev/sdb align-check optimal 1` |
| parted: resize a partition | `sudo parted /dev/sdb resizepart 1 200GiB` |
| Inform kernel of table changes | `sudo partprobe /dev/sdb` |
| Resize ext4 filesystem after partition grow | `sudo resize2fs /dev/sdb1` |
| Grow XFS filesystem to fill partition | `sudo xfs_growfs /mountpoint` |

## fdisk Interactive Commands

| Key | Action |
|-----|--------|
| `p` | Print current partition table |
| `n` | New partition |
| `d` | Delete partition |
| `t` | Change partition type |
| `g` | Create new GPT table |
| `o` | Create new MBR table |
| `w` | Write changes and exit |
| `q` | Quit without saving |
| `m` | Help / list commands |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| fdisk creates MBR partition table by default | fdisk defaults to MBR (`o`) unless told otherwise | Use `g` in fdisk to create GPT, or use `gdisk`/`parted` for GPT-first workflow |
| Partition changes not visible after fdisk exits | Kernel has the old table cached | `sudo partprobe /dev/sdX`; if device is busy, reboot |
| "WARNING: Re-reading the partition table failed" | The disk is in use (mounted or part of active LVM/RAID) | Unmount all partitions; stop RAID/LVM; then `partprobe` or reboot |
| Partition resized but filesystem still the same size | parted resizes the partition block device only | Grow ext4: `resize2fs /dev/sdX1`; XFS: `xfs_growfs /mountpoint`; btrfs: `btrfs filesystem resize max /mountpoint` |
| "Error: The backup GPT table is not at the end of the disk" | GPT backup header is in wrong location (disk was resized/replaced) | `sudo gdisk /dev/sdX` then `w` and accept fix, or `sudo sgdisk -e /dev/sdX` |
| Partitions misaligned on SSD | Start offset not on 1 MiB boundary | Use `1MiB` as the start offset in parted; verify with `parted /dev/sdX align-check optimal N` |
| Disk larger than 2 TiB not partitionable with fdisk (MBR) | MBR cannot address beyond 2 TiB | Use GPT: `sudo gdisk /dev/sdX` or `sudo parted /dev/sdX mklabel gpt` |

## Pain Points

- **fdisk defaults to MBR**: running `fdisk /dev/sdX` creates an MBR table unless you explicitly press `g` for GPT. For any new disk larger than 2 TB or where UEFI boot is needed, use `gdisk` or `parted` with `mklabel gpt`.
- **Changes only take effect after `w`**: interactive fdisk/gdisk sessions are staged in memory. Pressing `q` discards all changes. Pressing `w` writes them immediately and irreversibly. On a live disk with data, `w` on a wrong table wipes the partition structure.
- **Partition resize does not resize the filesystem**: `parted resizepart` or `fdisk` only changes the partition boundary in the partition table. The filesystem inside must be grown separately. For ext4 use `resize2fs` (online growth supported); for XFS use `xfs_growfs` (online); for btrfs use `btrfs filesystem resize max`; for shrinking ext4, unmount first, run `e2fsck -f`, then `resize2fs`, then `resizepart`.
- **4K alignment matters for SSDs**: starting partitions on 1 MiB boundaries ensures alignment to both 512-byte and 4096-byte physical sector boundaries. Misaligned partitions cause extra read-modify-write cycles on SSDs. Always specify start offsets in MiB when using parted non-interactively.
- **Never partition a mounted disk**: partitioning a disk with active mounts risks data corruption. Unmount all partitions and deactivate LVM/RAID before editing the partition table.
- **`partprobe` is not always sufficient**: if any partition on the disk is mounted or held by LVM/RAID, the kernel will refuse to re-read the table. A reboot is the safe fallback.

## See Also

- **lsblk** — list block devices, partitions, and mount points before partitioning
- **lvm** — logical volume management for flexible partitioning on top of physical volumes
- **mdadm** — software RAID arrays that sit between partitions and filesystems
- **exfat-ntfs** — format partitions for Windows/macOS interoperability

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common partitioning workflows
- `docs.md` — man pages and upstream documentation links
