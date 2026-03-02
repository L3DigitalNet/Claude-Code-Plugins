# lsblk Cheatsheet

## 1. Default Overview

The quickest way to see all block devices and their layout.

```bash
lsblk
```

Sample output:
```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    0   500G  0 disk
├─sda1        8:1    0   512M  0 part /boot/efi
├─sda2        8:2    0     1G  0 part /boot
└─sda3        8:3    0 498.5G  0 part
  ├─vg0-root 253:0   0    50G  0 lvm  /
  └─vg0-home 253:1   0 448.5G  0 lvm  /home
nvme0n1     259:0    0     1T  0 disk
└─nvme0n1p1 259:1    0     1T  0 part /data
```

---

## 2. Filesystem Information

Show UUID, filesystem type, and label alongside device names. Useful when editing
`/etc/fstab` or identifying a device to mount.

```bash
lsblk -f
```

Sample output:
```
NAME        FSTYPE      LABEL  UUID                                 MOUNTPOINTS
sda
├─sda1      vfat        EFI    1234-ABCD                            /boot/efi
├─sda2      ext4               a1b2c3d4-...                         /boot
└─sda3
  ├─vg0-root ext4              e5f6a7b8-...                         /
  └─vg0-home ext4              c9d0e1f2-...                         /home
```

For a combined view with sizes:

```bash
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINT
```

---

## 3. Find a Disk's UUID for fstab

When adding a new entry to `/etc/fstab`, always use UUID (not `/dev/sdX`).

```bash
lsblk -o NAME,UUID /dev/sdb
# or
lsblk -f /dev/sdb
```

Copy the UUID into `/etc/fstab`:
```
UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890  /data  ext4  defaults  0  2
```

---

## 4. JSON Output for Scripts

Machine-readable output for use in scripts or configuration management tools.

```bash
lsblk -J
lsblk -J -o NAME,SIZE,FSTYPE,UUID,MOUNTPOINT

# Parse with jq: list all partition UUIDs
lsblk -J | jq -r '.blockdevices[].children[]? | select(.uuid != null) | "\(.name) \(.uuid)"'

# Find the device backing a mountpoint
lsblk -J | jq -r '.blockdevices[] | .. | objects | select(.mountpoint == "/data") | .name'
```

---

## 5. Exclude Loop Devices (Clean View on Desktop Systems)

snap and flatpak create loop devices for each mounted package. Filter them out.

```bash
# Major device number 7 = loop
lsblk -e 7

# Also exclude RAM disks (major 1)
lsblk -e 1,7

# Alternatively, grep for real storage types
lsblk | grep -v loop
```

---

## 6. Identify LVM and LUKS Devices

Device mapper devices (`dm-*`, `TYPE=lvm`, `TYPE=crypt`) need additional tools to
understand their purpose.

```bash
# See device type in lsblk output
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Identify LVM volumes
lvdisplay
lvs -o lv_name,vg_name,lv_size,lv_attr

# Identify LUKS containers
lsblk -o NAME,TYPE | grep crypt
cryptsetup status /dev/mapper/cryptname

# Full device mapper dependency tree
dmsetup ls --tree
```

---

## 7. Disk Model and Serial Numbers

Useful for hardware inventory, RMA, or matching a device to a physical drive.

```bash
lsblk -o NAME,SIZE,SERIAL,MODEL,TYPE

# For NVMe (may need root)
lsblk -o NAME,SIZE,MODEL,TYPE
sudo smartctl -i /dev/nvme0n1 | grep -E "Model|Serial"
```

---

## 8. Topology and Alignment

Check physical sector size, logical sector size, and alignment — relevant for
SSD performance and ZFS ashift selection.

```bash
lsblk -t
lsblk -o NAME,PHY-SEC,LOG-SEC,ROTA,DISC-GRAN
```

Column meanings:
- `PHY-SEC`: physical sector size (4096 for 4Kn drives, 512 for 512n)
- `LOG-SEC`: logical sector size (512 for 512e drives emulating 512)
- `ROTA`: 1 = rotational (HDD), 0 = non-rotational (SSD/NVMe)
- `DISC-GRAN`: discard/TRIM granularity (non-zero = TRIM supported)

---

## 9. Verify Partition Table After Changes

After partitioning, verify the kernel has picked up the new table without rebooting.

```bash
# Inform the kernel of partition table changes
sudo partprobe /dev/sdb

# Confirm new partitions are visible
lsblk /dev/sdb

# If partprobe fails (device busy), check what is using it
lsof /dev/sdb
fuser -m /dev/sdb
```

---

## 10. Quick Disk Inventory

Get a concise overview of all physical disks with sizes, types, and rotational status.
Useful at the start of a storage troubleshooting session.

```bash
lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT -e 7 | grep -E "disk|NAME"

# With model names (requires root for NVMe)
sudo lsblk -o NAME,SIZE,ROTA,MODEL,SERIAL -d

# Distinguish SSDs from HDDs
lsblk -o NAME,SIZE,ROTA -d | awk 'NR>1 {print $0, ($3=="0" ? "SSD" : "HDD")}'
```
