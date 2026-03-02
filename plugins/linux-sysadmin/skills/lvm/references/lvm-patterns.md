# LVM Patterns

Each section is a complete, sequential command sequence for a common task.
Commands are copy-paste ready; replace device names (`/dev/sdX`, `/dev/sdY`),
VG names (`myvg`), LV names (`mylv`), and sizes to match your environment.

---

## 1. Basic Setup: PV → VG → LV → Filesystem → Mount

New disk `/dev/sdb`, creating a single VG and LV, formatted ext4.

```bash
# Verify the disk is visible and not already in use.
lsblk /dev/sdb

# Initialize the disk as a physical volume.
pvcreate /dev/sdb

# Create a volume group named "datavg" using that PV.
vgcreate datavg /dev/sdb

# Create a 20 GiB logical volume named "datalv".
lvcreate -L 20G -n datalv datavg

# Format as ext4.
mkfs.ext4 /dev/datavg/datalv

# Create the mount point and mount.
mkdir -p /mnt/data
mount /dev/datavg/datalv /mnt/data

# Add to /etc/fstab for persistence across reboots.
# Use the device path or UUID (blkid /dev/datavg/datalv).
echo '/dev/datavg/datalv /mnt/data ext4 defaults,noatime 0 2' >> /etc/fstab
```

---

## 2. Extend a Logical Volume

The filesystem must be resized after the LV is extended. Order matters: grow the
block device first, then grow the filesystem. Never resize the filesystem before
the block device.

```bash
# Confirm current size and available free space in the VG.
lvdisplay /dev/datavg/datalv
vgs datavg

# Extend by 10 GiB.
lvextend -L +10G /dev/datavg/datalv

# For ext4: resize2fs works online (while mounted).
resize2fs /dev/datavg/datalv

# For XFS: xfs_growfs uses the mount point, not the device path.
# XFS can only grow, never shrink.
xfs_growfs /mnt/data

# For Btrfs:
btrfs filesystem resize max /mnt/data

# Confirm the new size.
df -h /mnt/data
```

---

## 3. Add a Disk to an Existing VG and Move Data Off the Old Disk

Scenario: `/dev/sda` is a small disk already in `datavg`; `/dev/sdb` is a new
larger disk. Goal: move data to the new disk and remove the old one.

```bash
# Initialize the new disk as a PV.
pvcreate /dev/sdb

# Add it to the existing VG.
vgextend datavg /dev/sdb

# Confirm both PVs are now in the VG.
pvs

# Move all extents off /dev/sda onto free extents in the VG.
# This runs in the background; progress shown via lvs --all.
pvmove /dev/sda

# Monitor progress.
watch -n5 'lvs --all datavg'

# Once pvmove completes, remove /dev/sda from the VG.
vgreduce datavg /dev/sda

# Optionally wipe the LVM metadata so the disk can be reused freely.
pvremove /dev/sda
```

---

## 4. Snapshot for Backup

Snapshots are copy-on-write. Take the snapshot, mount it read-only, run the
backup, then remove it. Do not leave snapshots running indefinitely — they
accumulate COW data and degrade origin LV performance over time.

```bash
# Create a 5 GiB snapshot of datalv.
# The snapshot LV needs enough space to store all writes to the origin
# during the backup window. For a busy volume, size conservatively.
lvcreate -L 5G -s -n datalv-snap /dev/datavg/datalv

# Mount the snapshot read-only so the backup sees a consistent view.
mkdir -p /mnt/snap
mount -o ro /dev/datavg/datalv-snap /mnt/snap

# Run the backup (example: rsync to another host).
rsync -a --delete /mnt/snap/ backup-host:/backups/datalv/

# Unmount and remove the snapshot.
umount /mnt/snap
lvremove -f /dev/datavg/datalv-snap

# Alternative: merge the snapshot back into the origin (reverts all writes
# to the origin since snapshot time). The LV must be unmounted first;
# the merge completes on next activation.
# umount /mnt/data
# lvconvert --merge /dev/datavg/datalv-snap
# lvchange -ay datavg/datalv && mount /dev/datavg/datalv /mnt/data
```

---

## 5. Thin Provisioning Setup and Monitoring

Thin provisioning allows you to allocate more virtual space than physical space
exists. The pool fills as writes arrive, not when LVs are created. Monitor the
pool continuously and enable auto-extension.

```bash
# Create a 100 GiB thin pool in datavg.
# LVM will carve out two internal LVs: one for data, one for metadata.
lvcreate -L 100G --thinpool thinpool datavg

# Create thin volumes. Total allocated can exceed 100 GiB — over-provisioning
# is intentional but requires vigilance.
lvcreate -V 50G --thin datavg/thinpool -n thin-vol1
lvcreate -V 50G --thin datavg/thinpool -n thin-vol2
lvcreate -V 50G --thin datavg/thinpool -n thin-vol3  # 150G allocated, 100G pool

# Format and mount as normal.
mkfs.ext4 /dev/datavg/thin-vol1
mkdir -p /mnt/thin1
mount /dev/datavg/thin-vol1 /mnt/thin1

# Monitor pool usage (data_percent, metadata_percent).
lvs -o lv_name,lv_size,data_percent,metadata_percent datavg

# Enable auto-extension in /etc/lvm/lvm.conf (see lvm.conf.annotated):
#   thin_pool_autoextend_threshold = 80
#   thin_pool_autoextend_percent = 20
# Then enable the lvm2-monitor service:
systemctl enable --now lvm2-monitor

# Manually extend the pool if auto-extension is not configured.
lvextend -L +20G datavg/thinpool
```

---

## 6. Move Data Off a Physical Volume and Remove It

Same as Pattern 3 but focused on retiring a specific disk without adding
a replacement (requires enough free extents elsewhere in the VG).

```bash
# Check free space in the VG.
vgs datavg

# Confirm how many extents /dev/sda holds.
pvdisplay /dev/sda

# Move extents to any other PV in the VG.
pvmove /dev/sda

# To move to a specific destination PV:
pvmove /dev/sda /dev/sdb

# Remove the PV from the VG once pvmove completes.
vgreduce datavg /dev/sda

# Wipe LVM signatures from the disk.
pvremove /dev/sda

# The disk can now be partitioned or used for another purpose.
wipefs -a /dev/sda
```

---

## 7. Create a Striped LV for Performance

Striping spreads I/O across multiple PVs, similar to RAID 0. Requires at least
as many PVs as stripes. Stripe size should match filesystem or application I/O
alignment (typically 64K–512K).

```bash
# Ensure the VG has at least two PVs.
pvs

# Create a 40 GiB LV striped across 2 PVs with 256K stripe size.
# LVM distributes extents evenly across all available PVs by default.
lvcreate -L 40G -i 2 -I 256 -n striped-lv datavg

# Verify the stripe configuration.
lvdisplay -m /dev/datavg/striped-lv

# Format and use normally.
mkfs.xfs /dev/datavg/striped-lv
```

---

## 8. LVM on Software RAID (mdadm + LVM Layering)

LVM sits on top of an mdadm RAID array. LVM provides flexible partitioning;
mdadm provides redundancy. This is a common pattern for home servers and NAS.

```bash
# First, create the RAID array with mdadm.
# Example: RAID 1 across /dev/sdb and /dev/sdc.
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# Wait for the initial sync (optional — you can use the array immediately
# but degraded performance until sync completes).
cat /proc/mdstat

# Initialize the RAID device as an LVM PV.
pvcreate /dev/md0

# Create the VG and LV on top of the RAID PV.
vgcreate raidvg /dev/md0
lvcreate -L 100G -n raidlv raidvg

# Persist the RAID config so it reassembles on boot.
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
update-initramfs -u   # Debian/Ubuntu
dracut --force        # RHEL/Fedora

# Add the LV to /etc/fstab as normal.
mkfs.ext4 /dev/raidvg/raidlv
echo '/dev/raidvg/raidlv /mnt/raid ext4 defaults,noatime 0 2' >> /etc/fstab
```

---

## 9. Rename a Volume Group

Renaming a VG updates LVM metadata on all PVs in the group. Update `/etc/fstab`
and any other references to the old name afterwards.

```bash
# Rename datavg to storagevg.
vgrename datavg storagevg

# Verify the rename.
vgs

# Update /etc/fstab: replace all occurrences of /dev/datavg/ with /dev/storagevg/.
sed -i 's|/dev/datavg/|/dev/storagevg/|g' /etc/fstab

# Update initrd/initramfs so the new name is found on boot.
update-initramfs -u   # Debian/Ubuntu
dracut --force        # RHEL/Fedora
```

---

## 10. Disaster Recovery: Import a VG from Disks Moved to a New System

When disks are moved to a new machine, the VG may not activate automatically
because the new system has never seen it. Use `vgimport` to claim ownership.

```bash
# Scan all block devices for LVM signatures.
pvscan

# If the VG shows as "exported" or "foreign", import it.
vgimport myvg

# If pvscan doesn't find the PVs (e.g., device names changed), force a rescan.
pvscan --cache

# Activate the VG and all its LVs.
vgchange -ay myvg

# Verify all LVs are active.
lvs myvg

# Mount the LVs as normal.
mkdir -p /mnt/recovered
mount /dev/myvg/mylv /mnt/recovered

# If there are two VGs with the same name (UUID collision from disk cloning):
# Use the UUID form to disambiguate.
vgs --uuid
vgrename <old-uuid> importedvg
vgchange -ay importedvg
```
