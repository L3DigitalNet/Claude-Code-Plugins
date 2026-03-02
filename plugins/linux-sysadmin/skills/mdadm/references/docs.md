# mdadm Documentation

## Man Pages

- `man mdadm` — full CLI reference (modes, options, examples)
- `man mdadm.conf` — config file format, all directives
- Online mdadm man page: https://linux.die.net/man/8/mdadm

## Official Kernel / MD Driver Documentation

- MD driver documentation (kernel.org): https://www.kernel.org/doc/html/latest/admin-guide/md.html
- `/proc/mdstat` format and sysfs interface: https://www.kernel.org/doc/html/latest/admin-guide/md.html#files-in-sys-block-md-x-md

## HOWTOs and Guides

- Linux RAID wiki (tldp.org): https://tldp.org/HOWTO/Software-RAID-HOWTO.html
- Arch Linux mdadm wiki (comprehensive, distro-agnostic): https://wiki.archlinux.org/title/RAID
- Debian mdadm documentation: https://wiki.debian.org/SoftwareRAID
- Ubuntu mdadm guide: https://help.ubuntu.com/community/Installation/SoftwareRAID

## Distro-Specific References

- RHEL 9 managing RAID: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_storage_devices/managing-raid_managing-storage-devices
- Fedora storage administration (mdadm section): https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/storage-and-file-systems/

## Superblock Versions

- Superblock format overview: https://raid.wiki.kernel.org/index.php/RAID_superblock_formats
- Superblock 1.x detail: https://raid.wiki.kernel.org/index.php/Mdadm_metadata

## RAID Concepts

- RAID levels explained: https://raid.wiki.kernel.org/index.php/Overview#RAID_levels
- Write hole problem (RAID-5/6): https://raid.wiki.kernel.org/index.php/Write-hole
- Write intent bitmap: https://raid.wiki.kernel.org/index.php/Write-intent_bitmap
