---
name: mdadm
description: >
  Linux software RAID administration with mdadm: creating and assembling arrays,
  adding and replacing disks, monitoring health, reshaping arrays, and
  troubleshooting degraded or failed RAID sets.
  MUST consult when installing, configuring, or troubleshooting mdadm.
triggerPhrases:
  - "mdadm"
  - "software RAID"
  - "RAID-1"
  - "RAID-5"
  - "RAID-6"
  - "RAID-10"
  - "linux RAID"
  - "md device"
  - "/proc/mdstat"
  - "RAID array"
  - "md0"
  - "md1"
  - "raid level"
  - "degraded array"
  - "rebuild"
  - "resync"
  - "hot spare"
  - "mdadm.conf"
globs:
  - "**/etc/mdadm/mdadm.conf"
  - "**/etc/mdadm.conf"
last_verified: "unverified"
---

## Identity

- **Kernel modules**: `md_mod`, `raid0`, `raid1`, `raid456`, `raid10` (auto-loaded on array use)
- **CLI tool**: `mdadm`
- **Config**: `/etc/mdadm/mdadm.conf` (Debian/Ubuntu), `/etc/mdadm.conf` (RHEL/Fedora)
- **Status file**: `/proc/mdstat` — live array state, rebuild progress, sync speed
- **Logs**: `journalctl -k | grep -i md`, `/var/log/syslog` or `/var/log/messages`
- **Distro install**: `apt install mdadm` / `dnf install mdadm`

## Quick Start

```bash
sudo apt install mdadm
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1
cat /proc/mdstat
sudo mdadm --detail --scan | sudo tee /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

## Key Operations

| Task | Command |
|------|---------|
| Check array status (summary) | `cat /proc/mdstat` |
| Check array status (detail) | `mdadm --detail /dev/md0` |
| Check individual disk superblock | `mdadm --examine /dev/sdb1` |
| Create RAID-1 array | `mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1` |
| Create RAID-5 array | `mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sdb1 /dev/sdc1 /dev/sdd1` |
| Create RAID-6 array | `mdadm --create /dev/md0 --level=6 --raid-devices=4 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1` |
| Create RAID-10 array | `mdadm --create /dev/md0 --level=10 --raid-devices=4 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1` |
| Assemble existing array | `mdadm --assemble /dev/md0 /dev/sdb1 /dev/sdc1` |
| Assemble all arrays from config | `mdadm --assemble --scan` |
| Add disk (hot spare) | `mdadm --add /dev/md0 /dev/sdd1` |
| Mark disk as failed | `mdadm --fail /dev/md0 /dev/sdb1` |
| Remove disk from array | `mdadm --remove /dev/md0 /dev/sdb1` |
| Replace failed disk (fail + remove + add) | `mdadm --fail /dev/md0 /dev/sdb1 && mdadm --remove /dev/md0 /dev/sdb1 && mdadm --add /dev/md0 /dev/sdd1` |
| Trigger consistency check | `echo check > /sys/block/md0/md/sync_action` |
| Check current sync action | `cat /sys/block/md0/md/sync_action` |
| Abort check/resync in progress | `echo idle > /sys/block/md0/md/sync_action` |
| Set rebuild speed limit (min) | `echo 50000 > /proc/sys/dev/raid/speed_limit_min` |
| Set rebuild speed limit (max) | `echo 200000 > /proc/sys/dev/raid/speed_limit_max` |
| Grow array (add disks, same level) | `mdadm --grow /dev/md0 --raid-devices=4 --add /dev/sde1` |
| Reshape to new RAID level | `mdadm --grow /dev/md0 --level=6 --raid-devices=4` |
| Stop array | `mdadm --stop /dev/md0` |
| Stop all arrays | `mdadm --stop --scan` |
| Update config after changes | `mdadm --detail --scan >> /etc/mdadm/mdadm.conf` |
| Monitor events to syslog | `mdadm --monitor --scan --daemonise --delay=60` |

## Expected Ports / State

- No network ports; mdadm is kernel-level block device management.
- Healthy arrays show `active` or `clean` in `/proc/mdstat` and `--detail`.
- During rebuild: `clean, degraded, recovering` or `active, recovering` with a progress percentage — normal, not alarming unless stalled.
- `UU` (RAID-1) or `UUU` (RAID-5) in `/proc/mdstat` means all devices active. Underscore `_` means a missing/failed device.
- Verify: `grep -E "^md|UU|recovery|resync" /proc/mdstat`

## Health Checks

1. `cat /proc/mdstat` — all arrays listed, no `_` placeholders, no resync/recovery unless intentional
2. `mdadm --detail /dev/md0` — `State` is `clean` or `active`; no `(F)` flags on devices
3. `journalctl -k --since "24 hours ago" | grep -iE "md/raid|array degraded|read error"` — no unexpected errors
4. `dmesg | grep -i "md:" | tail -20` — no repeated read errors on any block device

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Array state is `degraded` | One or more disks failed or missing | `mdadm --detail /dev/md0` — find `(F)` device; check `dmesg` for I/O errors; replace disk |
| `/proc/mdstat` shows `_` in bitmap | Disk dropped from array (kernel evicted after errors) | Check `dmesg` for I/O errors on the device; replace the failed disk and `--add` a new one |
| Rebuild stalled or very slow | Speed limits too low, or competing I/O | Check `speed_limit_min`/`speed_limit_max` in `/proc/sys/dev/raid/`; raise limits temporarily |
| Bitmap sync errors in logs | Write intent bitmap (WIB) corrupted | `mdadm --grow /dev/md0 --bitmap=none` to disable WIB, then re-enable; check dmesg for underlying disk errors |
| `mdadm --assemble` fails with "no valid superblock" | Superblock version mismatch or disk was used in a different array | `mdadm --examine /dev/sdX` on each disk to compare UUIDs and events; reassemble with `--force` only if you understand the risk |
| Array not assembled on boot | `mdadm.conf` missing or outdated | `mdadm --detail --scan > /etc/mdadm/mdadm.conf`; run `update-initramfs -u` on Debian/Ubuntu; run `dracut -f` on RHEL/Fedora |
| Read errors during rebuild causing cascading failure | Second disk degraded under rebuild I/O stress | Stop the rebuild immediately (`echo idle > /sys/block/md0/md/sync_action`); back up data; do not continue on a RAID-5/6 with two failing disks |
| `cannot open /dev/md0: No such file or directory` | Array not assembled yet | `mdadm --assemble --scan` or assemble explicitly with device paths |
| `mdadm: /dev/sdX appears to be part of a raid array` | Disk already has an mdadm superblock | Intentional reuse: `mdadm --zero-superblock /dev/sdX` to wipe; confirm you are targeting the correct disk first |
| Array created but won't start after reboot | `mdadm.conf` not updated + `update-initramfs` not run | Update config and regenerate initramfs; see "Array not assembled on boot" row above |

## Pain Points

- **RAID-5/6 write hole**: If power is lost mid-stripe-write, parity can become inconsistent. Mitigated by a write intent bitmap (`--bitmap=internal`) or a battery-backed write cache. For new deployments consider ZFS (which eliminates this at the filesystem level) unless you need raw block RAID.
- **Rebuild time on large disks**: A 4 TB disk can take 10–20 hours to rebuild under default speed limits. Temporarily raise `speed_limit_max` (e.g. `1000000`) if the server can afford the I/O load. Lower it again afterwards to avoid starving application I/O.
- **Speed limit tuning tension**: Low `speed_limit_min` keeps the array responsive under load but means a rebuild can stall indefinitely. High `speed_limit_max` finishes the rebuild faster but can saturate the disk bus, causing application latency. Tune per workload; idle servers should run rebuilds at full speed.
- **`mdadm.conf` must be updated after every structural change**: Adding a disk, growing an array, or reshaping all change the array metadata. Run `mdadm --detail --scan > /etc/mdadm/mdadm.conf` after any such operation — not `>>` (append) which accumulates stale entries.
- **`update-initramfs` (Debian/Ubuntu) or `dracut -f` (RHEL/Fedora) required after config changes**: The initramfs contains a copy of `mdadm.conf`. Without regenerating it, the system will fail to assemble the root/boot array on next boot even though the config on disk is correct.
- **Email alert setup is not automatic**: `mdadm --monitor` sends mail on disk failures, but `MAILADDR` in `mdadm.conf` and a working MTA (e.g. `postfix`, `msmtp`) must both be configured. Many installs silently have no alerting until a disk fails.
- **Hot spare scope**: A spare added to `/dev/md0` is bound to that array. To share a spare across multiple arrays use `--add --spare-group`; otherwise each array must have its own dedicated spare device.

## See Also

- **lvm** — Logical volume management layered on top of mdadm arrays; use to create flexible, resizable volumes on RAID devices
- **zfs** — Integrated volume manager with built-in RAID (RAIDZ); eliminates the write hole without a separate RAID layer
- **smartctl** — SMART disk health monitoring; use proactively to detect failing drives before they degrade an array

## References

See `references/` for:
- `mdadm.conf.annotated` — full config with every directive explained, plus `/proc/mdstat` format guide
- `docs.md` — upstream documentation and community reference links
