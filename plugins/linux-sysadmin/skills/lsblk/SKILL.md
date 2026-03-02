---
name: lsblk
description: >
  lsblk lists block devices in a tree hierarchy showing disks, partitions, LVM
  volumes, LUKS containers, and their mount points. Invoked when the user asks
  about the disk layout, block device list, partition structure, mount points,
  UUIDs, or wants to understand how storage is organized on a system. Triggers on:
  lsblk, block devices, list disks, disk layout, partition list, mount points,
  disk hierarchy, device tree, block device names, nvme partitions, storage topology.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `lsblk` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool (part of util-linux) |
| **Install** | `apt install util-linux` / `dnf install util-linux` (pre-installed on all Linux systems) |

## Key Operations

| Task | Command |
|------|---------|
| Default tree view (names, sizes, types, mountpoints) | `lsblk` |
| Include all empty and RAM block devices | `lsblk -a` |
| Show filesystem info (UUID, FSTYPE, LABEL, MOUNTPOINT) | `lsblk -f` |
| JSON output for scripting | `lsblk -J` |
| Key=value pairs output | `lsblk -P` |
| Query a specific device only | `lsblk /dev/sda` |
| Show sizes in raw bytes | `lsblk -b` |
| Custom columns: name, size, UUID, label, mountpoint | `lsblk -o NAME,SIZE,UUID,LABEL,MOUNTPOINT` |
| Custom columns with filesystem type | `lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINT,TYPE` |
| Show topology information (queues, alignment) | `lsblk -t` |
| Show disk serial numbers and model | `lsblk -o NAME,SIZE,SERIAL,MODEL,TYPE` |
| Exclude loop devices (snap/flatpak noise) | `lsblk -e 7` |

## Device Naming Reference

| Pattern | Meaning |
|---------|---------|
| `sda`, `sdb` | SATA/SAS/USB disks (first, second) |
| `sda1`, `sda2` | Partitions on `sda` |
| `nvme0n1` | First NVMe drive, namespace 1 |
| `nvme0n1p1` | First partition on NVMe drive |
| `vda`, `vdb` | Virtio block devices (KVM/QEMU VMs) |
| `mmcblk0` | eMMC / SD card |
| `mmcblk0p1` | Partition on eMMC |
| `md0` | Software RAID device (mdadm) |
| `dm-0`, `dm-1` | Device mapper device (LVM LV or LUKS) |
| `loop0`..`loop7` | Loop devices (snap packages, mounted images) |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `MOUNTPOINT` column blank for a mounted device | Device is bind-mounted or mounted in a namespace | `findmnt` gives a more complete picture of all mounts |
| Many `loop` devices cluttering output | snap or flatpak packages each create a loop device | `lsblk -e 7` to exclude loop devices (`7` is the loop device major number) |
| `dm-*` devices shown without context | LVM logical volumes or LUKS containers — names are not descriptive | `lvdisplay` for LVM details; `dmsetup ls` to see dm device purpose |
| NVMe drive not shown | Kernel NVMe module not loaded | `modprobe nvme`; check `dmesg | grep nvme` |
| Partition not shown as child of disk | Disk uses a partition table type kernel did not recognize | `gdisk -l /dev/sdX` to inspect; `partprobe /dev/sdX` to re-read table |
| `lsblk -f` shows no UUID for a partition | Partition exists but has no filesystem | Format with `mkfs.ext4 /dev/sdX1` or appropriate filesystem tool |

## Pain Points

- **Reads from sysfs, not root required**: lsblk does not require root and reads from `/sys/block`. This also means it can only report what the kernel knows — if a partition table change was made without `partprobe`, lsblk will show stale data.
- **`MOUNTPOINT` shows only the first mount**: if a device is mounted in multiple places (bind mounts, bind namespaces), `lsblk` shows only one mountpoint. Use `findmnt --source /dev/sdX1` to see all mount points for a device.
- **dm-* naming is opaque**: Device mapper devices (`dm-0`, `dm-1`) are LVM logical volumes or LUKS containers. The name carries no semantic meaning. Cross-reference with `lvdisplay` (LVM), `cryptsetup status /dev/mapper/name` (LUKS), or `dmsetup ls --tree` (full dependency tree).
- **loop devices from snap/flatpak**: Each snapped application mounts a squashfs image via a loop device. These are legitimate but inflate `lsblk` output on desktop systems. Use `-e 7` to exclude them entirely when looking at real storage devices.
- **`-f` flag does not show size**: `lsblk -f` switches the column set to filesystem-centric columns and drops `SIZE`. Combine explicitly: `lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINT` to get both.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common lsblk workflows
- `docs.md` — man pages and upstream documentation links
