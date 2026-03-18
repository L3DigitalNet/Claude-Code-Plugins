---
name: exfat-ntfs
description: >
  Cross-platform filesystem management for external drives and USB sticks shared
  between Linux, Windows, and macOS: mounting, formatting, repair, permissions,
  fstab entries, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting exFAT/NTFS cross-platform filesystems.
triggerPhrases:
  - "exFAT"
  - "NTFS"
  - "external drive linux"
  - "USB drive"
  - "format exfat"
  - "ntfs-3g"
  - "windows drive linux"
  - "cross-platform filesystem"
  - "exfatprogs"
  - "ntfsfix"
  - "NTFS3"
  - "removable media"
  - "mount external drive"
globs:
  - "**/fstab"
  - "**/etc/fstab"
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **exFAT** | Kernel-native since 5.4 (module `exfat`). Userspace tools: `exfatprogs` (preferred, replaces `exfat-fuse`). No daemon. |
| **NTFS (ntfs-3g)** | FUSE-based read-write driver. Slow but battle-tested. Install: `ntfs-3g`. |
| **NTFS (NTFS3)** | Kernel-native read-write driver since 5.15. Significantly faster than ntfs-3g. Mount with `-t ntfs3`. |
| **Daemon** | None — both are mount-time configured. |
| **Distro install** | Debian/Ubuntu: `apt install exfatprogs ntfs-3g`; RHEL/Fedora: `dnf install exfatprogs ntfs-3g`; Arch: `pacman -S exfatprogs ntfs-3g` |

## Quick Start

```bash
sudo apt install exfatprogs ntfs-3g
lsblk -f /dev/sdX
sudo mount -t exfat -o uid=$(id -u),gid=$(id -g),umask=022 /dev/sdX1 /mnt/usb
touch /mnt/usb/testfile && rm /mnt/usb/testfile
```

## Key Operations

| Task | Command |
|------|---------|
| Detect filesystem type | `blkid /dev/sdX1` or `file -s /dev/sdX1` |
| List partitions and sizes | `lsblk -f` (shows fs type, label, UUID) |
| List all disks with partition table | `sudo fdisk -l` |
| Mount exFAT | `sudo mount -t exfat /dev/sdX1 /mnt/usb` |
| Mount exFAT with user permissions | `sudo mount -t exfat -o uid=1000,gid=1000,umask=022 /dev/sdX1 /mnt/usb` |
| Mount NTFS (ntfs-3g) | `sudo mount -t ntfs-3g /dev/sdX1 /mnt/usb` |
| Mount NTFS (kernel NTFS3, Linux 5.15+) | `sudo mount -t ntfs3 /dev/sdX1 /mnt/usb` |
| Mount NTFS with user permissions | `sudo mount -t ntfs3 -o uid=1000,gid=1000,umask=022 /dev/sdX1 /mnt/usb` |
| Format as exFAT | `sudo mkfs.exfat -n "LABEL" /dev/sdX1` |
| Format as NTFS | `sudo mkntfs -f -L "LABEL" /dev/sdX1` (fast format, skip zeroing) |
| Check and repair exFAT | `sudo fsck.exfat /dev/sdX1` (unmounted) |
| Check and repair NTFS | `sudo ntfsfix /dev/sdX1` (clears dirty bit; run unmounted) |
| Set fstab entry for auto-mount | See `references/mount-options.md` |
| Unmount safely | `udisksctl unmount -b /dev/sdX1` (desktop) or `sudo umount /mnt/usb` |
| Check drive health | `sudo smartctl -a /dev/sdX` |
| Adjust permissions at mount time | Add `uid=`, `gid=`, `umask=` to mount options |
| Add udev rule for auto-mount | See `references/mount-options.md` |

## Expected State
- Drive mounted read-write at target mountpoint.
- Files accessible to the target user without `sudo` (requires `uid`/`gid` mount options — exFAT and NTFS have no per-file permission bits beyond what the mount supplies).
- `lsblk -f` shows the correct fstype and mountpoint.

## Health Checks
1. `lsblk -f /dev/sdX1` → shows `exfat` or `ntfs` under FSTYPE and a non-empty MOUNTPOINT
2. `mount | grep /dev/sdX1` → confirms mount options (check `uid`, `gid`, `rw`)
3. `touch /mnt/usb/testfile && rm /mnt/usb/testfile` → confirms read-write access as the target user

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| NTFS mounts read-only, `read-only filesystem` errors | Windows fast startup left the volume dirty (hibernation file present) | Boot Windows fully and shut down (not restart, not hibernate); or `sudo ntfsfix /dev/sdX1` to clear dirty bit as a workaround |
| `Permission denied` accessing files | Missing `uid`/`gid` mount options — files owned by root | Remount with `-o uid=$(id -u),gid=$(id -g),umask=022` |
| `wrong fs type, bad option, bad superblock` | Missing kernel module or userspace package | `lsmod | grep exfat`; install `exfatprogs` or ensure kernel >= 5.4; for NTFS install `ntfs-3g` |
| `modprobe: FATAL: Module exfat not found` | Kernel < 5.4 or module not built | Install `exfat-fuse` as fallback or upgrade kernel |
| Slow write speed on NTFS | ntfs-3g is FUSE-based (userspace overhead) | Use kernel NTFS3 driver: `mount -t ntfs3` (requires Linux 5.15+) |
| NTFS metadata corruption after unclean unmount | Journal not replayed properly | `sudo ntfsfix /dev/sdX1`; then remount |
| Drive won't unmount: `target is busy` | A process has an open file or the shell is inside the mountpoint | `lsof +D /mnt/usb` to find the process; `cd` out of the mountpoint; then unmount |
| exFAT volume not recognized on macOS/Windows after Linux format | Created without a partition table, or mkfs.exfat targeting the disk not a partition | Format `/dev/sdX1` (a partition), not `/dev/sdX` (the disk) |

## Pain Points
- **Windows fast startup (hibernate-on-shutdown)** leaves the NTFS volume in a dirty state. Linux mounts it read-only. The only clean fix is to boot Windows, disable fast startup (`Control Panel → Power Options → Choose what the power buttons do → Turn off fast startup`), and then shut down normally. `ntfsfix` clears the dirty bit but does not safely replay the Windows journal.
- **ntfs-3g is FUSE-based**: All I/O crosses the userspace/kernel boundary. For frequent or large transfers, use the kernel NTFS3 driver (`-t ntfs3`) on Linux 5.15+. Performance is dramatically better.
- **exFAT has no Unix permissions**: Every file appears owned by the `uid`/`gid` specified at mount time with the `umask` applied uniformly. You cannot `chmod` individual files. Plan the mount options upfront.
- **FAT32 4 GB file limit**: If someone asks why a large file copy fails to a FAT32 drive, the filesystem does not support files larger than 4 GB. Use exFAT (no practical file size limit) or NTFS instead.
- **Always sync before removing**: `sync && udisksctl unmount -b /dev/sdX1` before unplugging. Pulling a drive with dirty buffers causes corruption. On desktop systems, `udisksctl` is safer than raw `umount` because it also powers down the drive after unmounting.

## See Also

- **ext4** — Native Linux filesystem; use when the drive does not need to be read on Windows or macOS
- **fdisk-parted** — Partition management tools; use to create partition tables before formatting with exFAT or NTFS

## References
See `references/` for:
- `mount-options.md` — mount options table, fstab examples, udev rules, udisksctl vs mount
- `docs.md` — upstream documentation and wiki links
