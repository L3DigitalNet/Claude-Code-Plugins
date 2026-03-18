---
name: ncdu
description: >
  ncdu (NCurses Disk Usage) provides an interactive terminal UI for exploring disk
  usage by directory and file. Use when investigating what is consuming space,
  browsing and cleaning up large directories interactively, or as a visual
  alternative to du.
  MUST consult when exploring disk usage interactively.
triggerPhrases:
  - "ncdu"
  - "disk usage"
  - "what is taking space"
  - "find large files"
  - "disk cleanup"
  - "directory size"
  - "du interactive"
  - "large directory"
  - "storage cleanup"
  - "ncurses disk usage"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `ncdu` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool (interactive TUI) |
| **Install** | `apt install ncdu` / `dnf install ncdu` |

## Quick Start

```bash
sudo apt install ncdu
ncdu /var                # scan /var interactively
ncdu -x /               # scan root, stay on one filesystem
ncdu -o /tmp/scan.json / # export scan to JSON for later review
ncdu -f /tmp/scan.json   # load a previous scan
```

## Key Operations

| Task | Command |
|------|---------|
| Scan current directory interactively | `ncdu` |
| Scan a specific path | `ncdu /var/log` |
| Scan as root (access all files) | `sudo ncdu /` |
| Stay on one filesystem (skip NFS, cifs, bind mounts) | `ncdu -x /` |
| Exclude a path pattern | `ncdu --exclude '/proc' --exclude '/sys' /` |
| Export scan results to JSON file | `ncdu -o /tmp/scan.json /` |
| Load a previously exported scan | `ncdu -f /tmp/scan.json` |
| Export and view in one step (pipe) | `ncdu -o- / \| ncdu -f-` |
| Scan without showing progress bar | `ncdu -q /` |
| Show apparent sizes (not disk allocation) | `ncdu --apparent-size /` |

## Interactive Keys

| Key | Action |
|-----|--------|
| `↑` / `↓` or `j` / `k` | Navigate up/down |
| `Enter` or `→` | Enter directory |
| `←` or `q` (in subdir) | Go up one level |
| `d` | Delete selected file or directory (prompts) |
| `i` | Show item info (size, path, dev/ino) |
| `g` | Toggle graph / percentage display |
| `n` | Sort by name |
| `s` | Sort by size (default) |
| `?` | Help screen |
| `q` | Quit |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Scan runs forever / takes many minutes | Scanning NFS, cifs, or network mounts included | Always use `-x` when scanning `/` to stay on one filesystem |
| Reported total is larger than `df` shows | Hardlinks counted multiple times | ncdu counts each hardlink independently; use `--apparent-size` and be aware of the discrepancy |
| `ncdu: command not found` | Not installed by default | `apt install ncdu` or `dnf install ncdu` |
| File accidentally deleted from within UI | `d` key deletes without undo | There is no undo; use `d` only when certain |
| Scan progress freezes at a path | Permission denied or hung mount | Ctrl-C to abort; re-run with `--exclude` for the problematic path |
| Export JSON is very large | Full filesystem scan produces large JSON | Use `-o` to a file and load separately with `-f`; compress with `ncdu -o- / | gzip > scan.json.gz` |

## Pain Points

- **`-x` (one filesystem) is critical for `/` scans**: without it, ncdu crosses into NFS shares, cifs mounts, bind mounts, and procfs, producing incorrect totals and very long scan times. Always add `-x` when scanning the root or any mount that may have submounts.
- **Scanning is not interruptible cleanly**: once started, a scan cannot be paused. If the filesystem is very large, export to JSON first (`-o`) so the result can be loaded without rescanning (`-f`).
- **`d` deletes for real**: ncdu can delete files and directories directly from the UI. There is no recycle bin or undo. The `d` key requires a confirmation prompt but the deletion is permanent.
- **Hardlink double-counting**: directories that share inodes via hardlinks (e.g., Btrfs snapshots, some backup tools) are counted once per reference. The reported total can exceed `df` usage. Use `du --count-links` for comparison or accept the discrepancy as a known artifact.
- **ncdu2 (Rust rewrite) is faster but less widely packaged**: `ncdu2` can scan large trees 3-5x faster than the C version but is not available in most distro repositories as of 2025. Check if it is available before installing from source.

## See Also

- **df** — filesystem-level disk usage summary (complements ncdu's per-directory view)
- **lsblk** — list block devices and mount points to identify which disks to scan

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common ncdu workflows
- `docs.md` — man pages and upstream documentation links
