# LVM Documentation

## Man Pages

- `man lvm` — LVM overview; lists all subcommands and concepts
- `man lvmconfig` — query and display LVM configuration; `lvmconfig --type default` shows all defaults
- `man pvcreate` — initialize a block device as a physical volume
- `man pvdisplay`, `man pvs`, `man pvremove`, `man pvmove` — PV inspection and management
- `man vgcreate` — create a volume group
- `man vgdisplay`, `man vgs`, `man vgextend`, `man vgreduce`, `man vgrename`, `man vgchange`, `man vgimport` — VG management
- `man lvcreate` — create logical volumes (linear, striped, mirrored, thin, snapshot)
- `man lvdisplay`, `man lvs`, `man lvextend`, `man lvreduce`, `man lvresize`, `man lvconvert`, `man lvchange` — LV management
- `man lvm.conf` — full reference for every directive in `/etc/lvm/lvm.conf`
- `man lvmsystemid` — system ID feature for exclusive VG ownership between hosts

## Official Guides

- RHEL LVM administration guide (RHEL 9): https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/index
- RHEL thin provisioning guide: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/creating-and-managing-thin-provisioned-volumes_configuring-and-managing-logical-volumes

## Community References

- Arch Linux LVM wiki: https://wiki.archlinux.org/title/LVM
- Arch Linux LVM on software RAID: https://wiki.archlinux.org/title/RAID
- Ubuntu Server LVM documentation: https://documentation.ubuntu.com/server/explanation/storage/about-lvm/
- Debian LVM HOWTO: https://wiki.debian.org/LVM

## Thin Provisioning

- Kernel thin provisioning documentation: https://www.kernel.org/doc/html/latest/admin-guide/device-mapper/thin-provisioning.html
- dm-cache (LVM caching) documentation: https://www.kernel.org/doc/html/latest/admin-guide/device-mapper/cache.html
- dm-writecache documentation: https://www.kernel.org/doc/html/latest/admin-guide/device-mapper/writecache.html

## Related Tools

- `man mdadm` — Linux software RAID; commonly layered under LVM for redundancy
- `man resize2fs` — ext4 filesystem resize (used after `lvextend`)
- `man xfs_growfs` — XFS online grow (used after `lvextend`; XFS cannot shrink)
- `man e2fsck` — ext4 filesystem check; required before offline `lvreduce`
- `man blkid` — list block device UUIDs; use in `/etc/fstab` instead of device names for stability
