# ncdu Cheatsheet

## 1. Basic Interactive Scan

Scan a directory and browse interactively. Use arrow keys to navigate, Enter to descend.

```bash
# Current directory
ncdu

# Specific path
ncdu /var/log

# Root (as current user — some dirs inaccessible without sudo)
ncdu /
```

Navigate with `↑`/`↓`, enter subdirectories with `Enter` or `→`, go up with `←`.
Press `q` to quit.

---

## 2. Scan as Root (Full System View)

Run with sudo to see all files including root-owned directories.

```bash
sudo ncdu /
```

Without sudo, ncdu silently skips unreadable directories and shows `[error opening dir]`
next to them. Root access is needed to get accurate totals for system paths like
`/root`, `/var/lib`, `/etc`.

---

## 3. Stay on One Filesystem

Never scan `/` without `-x` on a system with NFS, cifs, or bind mounts — the scan
will include remote filesystems and run for a very long time.

```bash
sudo ncdu -x /
```

This is equivalent to `du --one-file-system`. If you want to see a specific remote
mount, scan it directly:

```bash
ncdu /mnt/nas
```

---

## 4. Exclude Specific Paths

Exclude directories that don't matter (backups, container overlay layers, snapshots).

```bash
# Single exclusion
ncdu --exclude '/var/lib/docker' /

# Multiple exclusions
ncdu --exclude '/proc' --exclude '/sys' --exclude '/dev' /

# Exclude by glob pattern (applied to path components, not full paths)
ncdu --exclude '*.log' /var
ncdu --exclude '.git' /home/chris/projects
```

Exclusions reduce scan time and keep results focused.

---

## 5. Export Scan to File

Export the scan result to JSON so you can load it later without rescanning.
Useful for large filesystems or automating comparisons over time.

```bash
# Export to a file
sudo ncdu -o /tmp/root-scan.json /

# Load the file for interactive browsing
ncdu -f /tmp/root-scan.json

# Compress for long-term storage
sudo ncdu -o- / | gzip -c > /tmp/root-scan.json.gz
zcat /tmp/root-scan.json.gz | ncdu -f-
```

---

## 6. Scan a Docker Host

Docker's overlay2 layers live under `/var/lib/docker/overlay2` and can consume
large amounts of space. Scan with Docker-aware cleanup.

```bash
# See what Docker itself thinks it's using
docker system df -v

# Browse Docker storage interactively
sudo ncdu /var/lib/docker

# After ncdu identifies unused images/volumes, clean with Docker
docker system prune -f
docker volume prune -f
docker image prune -a -f
```

---

## 7. Find Large Log Files

Quickly identify log directories that have grown out of control.

```bash
ncdu /var/log
```

Navigate into subdirectories to find the largest files. Sorted by size by default.
For files older than N days that are safe to archive:

```bash
# Find large old logs (to inform what to archive, not delete from ncdu)
find /var/log -name "*.log" -mtime +30 -size +100M -ls
```

---

## 8. Analyze a User's Home Directory

Find what a specific user is storing.

```bash
# As root, browse their home
sudo ncdu /home/alice

# Or as the user themselves
ncdu ~
ncdu ~/Downloads
ncdu ~/.local
```

Common culprits: `~/.cache`, `~/.local/share`, `~/Downloads`, editor plugin caches
(`~/.vscode/extensions`, `~/.config/Code`).

---

## 9. Apparent Size vs Disk Allocation

`ncdu` by default shows disk allocation (blocks used). Use `--apparent-size` to show
file content size — relevant for sparse files and compressed filesystems.

```bash
ncdu --apparent-size /data
```

The difference between apparent size and allocation:
- Sparse files: apparent size >> disk use
- Compressed filesystems (btrfs with zstd): apparent size >> disk use
- Files with many small fragments: apparent size < disk use (rare)

---

## 10. Scripted Size Check Without Interactive Mode

When you need ncdu's scanning logic in a script (non-interactive), export to JSON
and parse with `jq`.

```bash
# Export scan
ncdu -o /tmp/scan.json /var/log

# Find the top 5 entries by size from JSON (requires jq)
jq '.children | sort_by(-.asize) | .[:5] | .[] | {name, size: .asize}' /tmp/scan.json 2>/dev/null

# Simpler: just use du for non-interactive scripting
du -sh /var/log/* | sort -rh | head -10
```

For non-interactive scripting, `du -sh` combined with `sort -rh` is usually simpler
than parsing ncdu JSON.
