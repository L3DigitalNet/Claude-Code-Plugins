---
name: df
description: >
  df reports disk space usage at the filesystem level. Invoked when the user asks
  about disk space, "disk full" errors, filesystem usage, inode exhaustion, or
  wants to see how much space remains on a mounted volume.
  MUST consult when checking filesystem disk space or inode usage.
triggerPhrases:
  - "df"
  - "disk space"
  - "filesystem usage"
  - "disk full"
  - "no space left"
  - "disk usage by filesystem"
  - "inode usage"
  - "inode exhaustion"
  - "disk free"
  - "mounted volumes space"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `df` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool (part of coreutils) |
| **Install** | `apt install coreutils` / `dnf install coreutils` (pre-installed on all Linux systems) |

## Quick Start

```bash
# df is pre-installed on all Linux systems (coreutils)
df -h
df -i
df -hT -x tmpfs -x devtmpfs -x squashfs
```

## Key Operations

| Task | Command |
|------|---------|
| Human-readable sizes (KB/MB/GB) | `df -h` |
| Show all filesystems including zero-size | `df -a` |
| Show inode usage instead of block usage | `df -i` |
| Exclude tmpfs and devtmpfs from output | `df -h -x tmpfs -x devtmpfs` |
| Usage for a specific path or mountpoint | `df -h /var/log` |
| POSIX-compliant output (512-byte blocks) | `df -P` |
| Add a total summary line | `df -h --total` |
| Show filesystem type column | `df -hT` |
| Show filesystem type, exclude pseudo-fs | `df -hT -x tmpfs -x devtmpfs -x squashfs` |
| Sort by use percentage (highest first) | `df -h | sort -k5 -rh` |
| Sync before reading (force flush to disk) | `df --sync` |
| Show sizes in 1K blocks (scriptable) | `df -k` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Filesystem shows 100% but `du` total is less | Deleted files held open by a running process | `lsof +L1` to find processes holding deleted files; restart or kill the process to release space |
| "No space left on device" with disk not full | Inode exhaustion — all inodes consumed | `df -i` to confirm; remove many small files or recreate the filesystem with more inodes |
| `df -h` shows tmpfs/devtmpfs inflating totals | Virtual filesystems included in output | `df -h -x tmpfs -x devtmpfs` to suppress them |
| Disk usage jumps after Docker pulls | overlayfs layers counted per-snapshot | `docker system df` and `docker system prune` for Docker-specific accounting |
| btrfs reports less usage than expected | btrfs shows compressed/deduplicated allocation | Use `btrfs filesystem df /mount` and `btrfs filesystem usage /mount` for accurate btrfs stats |
| `/` partition full but large files are in `/home` | `/home` is a separate filesystem | Each mountpoint reports independently; check the correct mountpoint |

## Pain Points

- **Filesystem-level only**: `df` reports per-filesystem totals. To find which directory or file consumes space within a filesystem, use `du` or `ncdu`.
- **Deleted-but-open files**: When a process holds a file descriptor open, the file's blocks are not reclaimed even after `rm`. `df` shows the space as used; `du` shows it as gone. `lsof +L1` reveals the offending process.
- **Inode exhaustion is silent**: A filesystem with 0 inodes free returns "No space left on device" identically to a full-blocks condition. Always check `df -i` alongside `df -h` when diagnosing space errors.
- **tmpfs and overlay inflation**: Without `-x tmpfs -x devtmpfs`, pseudo-filesystems appear in the output and the `--total` line includes them. On systems with many container overlayfs mounts the list can be very long.
- **btrfs accounting is non-obvious**: btrfs reports allocation, not raw consumption, because it uses copy-on-write. Reflinks, snapshots, and compression mean `df` output and `du` output can diverge significantly. Use `btrfs filesystem usage` for authoritative btrfs stats.

## See Also

- **ncdu** — Interactive disk usage analyzer; use to drill down into which directories consume space within a filesystem that `df` reports as full
- **lsblk** — Block device listing; use to see the physical disk layout and device hierarchy that underlies the filesystems `df` reports on

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common df workflows
- `docs.md` — man pages and upstream documentation links
