---
name: lvm
description: >
  LVM (Logical Volume Manager) administration: physical volumes, volume groups,
  logical volumes, thin provisioning, snapshots, resizing, pvmove, and disaster
  recovery. Triggers on: LVM, logical volume, pvcreate, vgcreate, lvcreate,
  volume group, LVM snapshot, LVM thin, pvmove, vgextend, lvextend, lvreduce,
  thin pool, physical volume, VG, LV, PV.
globs: []
---

## Identity
- **Kernel modules**: `dm-mod` (device mapper core), `dm-thin-pool` (thin provisioning)
- **CLI tools**: `pvcreate`, `pvdisplay`, `pvs`, `pvremove`, `pvmove`; `vgcreate`, `vgdisplay`, `vgs`, `vgextend`, `vgreduce`, `vgrename`, `vgchange`, `vgscan`; `lvcreate`, `lvdisplay`, `lvs`, `lvextend`, `lvreduce`, `lvresize`, `lvrename`, `lvchange`, `lvscan`, `lvremove`; `lvmconfig`, `lvm`
- **Config**: `/etc/lvm/lvm.conf`, `/etc/lvm/profile/` (per-VG overrides)
- **Metadata backups**: `/etc/lvm/backup/` (latest), `/etc/lvm/archive/` (history)
- **Distro install**: `apt install lvm2` / `dnf install lvm2`
- **Module load**: `modprobe dm-mod` (usually auto-loaded on first use)

## Key Operations

| Operation | Command |
|-----------|---------|
| List physical volumes (brief) | `pvs` |
| List physical volumes (verbose) | `pvdisplay` |
| List volume groups (brief) | `vgs` |
| List volume groups (verbose) | `vgdisplay` |
| List logical volumes (brief) | `lvs` |
| List logical volumes (verbose) | `lvdisplay` |
| List all LVM devices | `lvscan` / `vgscan` |
| Initialize a disk as PV | `pvcreate /dev/sdX` |
| Create a volume group | `vgcreate myvg /dev/sdX` |
| Create a linear LV | `lvcreate -L 20G -n mylv myvg` |
| Create a striped LV (2 disks, 64K stripe) | `lvcreate -L 20G -i 2 -I 64 -n mylv myvg` |
| Create a thin pool | `lvcreate -L 50G --thinpool mypool myvg` |
| Create a thin volume | `lvcreate -V 100G --thin myvg/mypool -n mythinlv` |
| Extend a VG (add disk) | `vgextend myvg /dev/sdY` |
| Extend an LV (size + filesystem) | `lvextend -L +10G /dev/myvg/mylv && resize2fs /dev/myvg/mylv` |
| Extend an LV to fill free space | `lvextend -l +100%FREE /dev/myvg/mylv` |
| Reduce an LV (ext4, offline only) | `e2fsck -f /dev/myvg/mylv && resize2fs /dev/myvg/mylv 15G && lvreduce -L 15G /dev/myvg/mylv` |
| Create a snapshot | `lvcreate -L 5G -s -n mysnap /dev/myvg/mylv` |
| Merge a snapshot back | `lvconvert --merge /dev/myvg/mysnap` |
| Remove a snapshot | `lvremove /dev/myvg/mysnap` |
| Move data off a PV | `pvmove /dev/sdX` |
| Remove a PV from VG | `vgreduce myvg /dev/sdX` |
| Rename a volume group | `vgrename oldvg newvg` |
| Rename a logical volume | `lvrename myvg oldlv newlv` |
| Activate all LVs in a VG | `vgchange -ay myvg` |
| Deactivate all LVs in a VG | `vgchange -an myvg` |
| Scan and import VG from foreign disks | `vgscan && vgimport myvg` |
| Check thin pool utilization | `lvs -o+data_percent,metadata_percent myvg/mypool` |

## Expected State
- All VGs and LVs should be `active` (`lvs` shows `a` in the Attr column)
- Mounted LVs listed in `/etc/fstab` with `noatime` or appropriate options
- Thin pool data usage below the `thin_pool_autoextend_threshold` (default 100%)

## Health Checks
1. `vgs --units g` — confirms VGs exist and shows free space; VFree should be non-zero if more LVs are planned
2. `lvs -o+lv_attr,data_percent,metadata_percent` — `a` in attr means active; data/metadata percentages matter for thin pools
3. `pvs -o+pv_used,pv_free` — confirms PVs are allocated as expected and not reporting errors

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|--------------|-----------|
| LV not activating on boot | Missing fstab entry or not in initrd | Add to `/etc/fstab`; on Debian/Ubuntu run `update-initramfs -u` |
| `No space left on device` inside VG | VG is full | `vgs` to confirm; `vgextend myvg /dev/sdY` to add disk, or `lvreduce` another LV |
| Thin pool showing 100% data usage | Over-provisioned thin volumes wrote more than pool holds | `lvextend -L +20G myvg/mypool`; enable `thin_pool_autoextend` in `lvm.conf` |
| Snapshot LV filling up | COW space exhausted by writes to origin since snapshot was taken | Merge or remove the snapshot immediately; next time use a larger `-L` for the snap |
| `pvmove` hangs or times out | Background kernel move stalled | Check `lvs --all` for `[pvmove0]` progress; `pvmove --abort` to cancel safely |
| VG name collision after disk copy | Two VGs with the same UUID/name imported simultaneously | `vgrename <uuid> newname` to disambiguate before importing |
| `device not found` after UUID change | LVM cached old device UUIDs | `pvscan --cache`; check `filter` in `lvm.conf` is not excluding the device |
| LVM cache (dm-cache) misconfiguration | Cache LV and origin LV roles swapped, or chunk size mismatch | `lvconvert --splitcache myvg/myoriginlv` to detach; reconfigure with correct `--cachemode` and `--chunksize` |
| `Can't open /dev/sdX exclusively` | Another process holds the device | `fuser -m /dev/sdX`; unmount or stop the consumer before LVM operations |

## Pain Points
- **Thin provisioning can silently over-commit**: you can allocate 10TB of thin volumes on a 1TB pool. The pool fills when writes arrive, not when the LV is created. Monitor data percentage continuously — a full thin pool causes I/O errors on all thin volumes simultaneously.
- **Snapshots are copy-on-write and not free**: every write to the origin after snapshot creation doubles the I/O (original write + COW copy). Old snapshots on busy volumes fill up fast; an exhausted snapshot is auto-deactivated and becomes unreadable.
- **pvmove is slow and disruptive**: moving data across spindles at full speed can saturate I/O. There is no built-in throttle. If interrupted (power loss, `pvmove --abort`), LVM resumes on next boot but the mirror state must be clean.
- **LV extension requires two commands**: `lvextend` grows the block device; the filesystem (ext4: `resize2fs`, XFS: `xfs_growfs`, Btrfs: `btrfs filesystem resize`) must be grown separately. Forgetting the second command leaves the filesystem at the old size with no error.
- **VG metadata area limits on large PV counts**: the default metadata area (1 MiB) caps the number of PEs the VG can describe. With many small PVs or very large disks with a small PE size, the metadata area fills. Increase with `pvresize` and `pvchange --metadatacopies`.
- **LVM cache (dm-cache, dm-writecache) is unrelated to ZFS ARC/L2ARC**: LVM cache is a block-level cache layer sitting below the filesystem. Combining it with ZFS ARC/L2ARC on the same volume creates redundant caching layers and can cause cache coherency surprises. Use one caching layer per storage stack.

## References
See `references/` for:
- `lvm-patterns.md` — task-oriented command sequences for common workflows
- `lvm.conf.annotated` — key directives in `/etc/lvm/lvm.conf` explained
- `docs.md` — man pages and official documentation links
