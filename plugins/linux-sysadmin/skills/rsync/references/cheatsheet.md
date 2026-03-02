# rsync Command Reference

Each block below is copy-paste-ready. Substitute `/src/`, `/dst/`, `user`, and `host`
for your actual paths and credentials.

The most important flag combination to understand: `-a` (archive) implies
`-r` (recursive) + `-l` (symlinks) + `-p` (permissions) + `-t` (timestamps) +
`-g` (group) + `-o` (owner) + `-D` (device files). Use `-a` as the base for
nearly every real sync.

---

## 1. Local Sync

```bash
# Sync contents of /src/ into /dst/.
# -a: archive mode (preserve perms, times, symlinks, owner, group, device files)
# -v: verbose — list each file as it's transferred
# -h: human-readable sizes
rsync -avh /src/ /dst/

# The trailing slash on /src/ is critical:
#   rsync /src/   /dst/   → copies contents of src into dst (dst/file1, dst/file2, ...)
#   rsync /src    /dst/   → copies src itself into dst (dst/src/file1, dst/src/file2, ...)
```

---

## 2. Remote Sync over SSH

```bash
# Push: local → remote
rsync -avh -e ssh /src/ user@host:/remote/dst/

# Pull: remote → local
rsync -avh -e ssh user@host:/remote/src/ /local/dst/

# Non-default SSH port
rsync -avh -e 'ssh -p 2222' /src/ user@host:/dst/

# Specific SSH key
rsync -avh -e 'ssh -i /home/user/.ssh/backup_key' /src/ user@host:/dst/

# Keep-alive for long transfers over unreliable connections
rsync -avh -e 'ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3' /src/ user@host:/dst/
```

---

## 3. Dry Run Before Real Sync

Always dry-run before using `--delete` or syncing to a new destination for the first time.

```bash
# -n / --dry-run: show what would be transferred without doing anything
rsync -avn /src/ /dst/

# With --delete: shows which destination files would be removed
rsync -avn --delete /src/ /dst/

# --itemize-changes: one line per file with a change-type code
# Format: YXcstpoguax (see man rsync "itemize" for each character's meaning)
# Common codes: >f = file sent, .d = directory unchanged, *deleting = would delete
rsync -avn --itemize-changes /src/ /dst/
```

---

## 4. Exclude Patterns

```bash
# Exclude a single pattern (shell glob, matched against path components)
rsync -avh --exclude='*.log' /src/ /dst/

# Multiple excludes
rsync -avh --exclude='*.log' --exclude='.cache/' --exclude='node_modules/' /src/ /dst/

# Load excludes from a file (one pattern per line; blank lines and # comments OK)
rsync -avh --exclude-from=/etc/rsync/excludes.txt /src/ /dst/

# Example excludes.txt:
# *.log
# *.tmp
# .cache/
# node_modules/
# __pycache__/
# .git/

# Include/exclude combination: include specific files, exclude everything else.
# Rules are evaluated in order — first match wins.
rsync -avh \
  --include='*.conf' \
  --include='*/' \
  --exclude='*' \
  /src/ /dst/
```

---

## 5. Hardlink-Based Incremental Backup (Time Machine Style)

Each run creates a full-snapshot directory. Unchanged files are hardlinked from
the previous snapshot rather than copied, so storage cost is proportional to
what actually changed.

```bash
BACKUP_ROOT=/backups/myhost
PREV=$BACKUP_ROOT/latest
TODAY=$BACKUP_ROOT/$(date +%F)

# --link-dest: for files unchanged since PREV, create a hardlink instead of copying
# Result: $TODAY looks like a full backup but shares inodes with $PREV for unchanged files
rsync -avh --link-dest="$PREV" /src/ "$TODAY/"

# Update the 'latest' symlink so the next run links against today's snapshot
ln -sfn "$TODAY" "$PREV"

# Storage layout after several runs:
# /backups/myhost/
#   2025-01-01/   (full copy — first run, no --link-dest)
#   2025-01-02/   (mostly hardlinks to 2025-01-01, plus any changed files)
#   2025-01-03/   (mostly hardlinks to 2025-01-02, plus any changed files)
#   latest -> 2025-01-03/
```

---

## 6. Mirror with Deletion

`--delete` removes files from the destination that are no longer in the source.
Without it, the destination accumulates deleted-source files forever.

```bash
# Always dry-run first when using --delete
rsync -avn --delete /src/ /dst/

# If the dry-run output looks correct, remove -n
rsync -avh --delete /src/ /dst/

# --delete-delay: collect deletions and apply them after the transfer completes.
# Safer for live systems — avoids a window where dst has neither old nor new file.
rsync -avh --delete-delay /src/ /dst/

# --delete-excluded: also delete destination files that match exclude patterns.
# Use with caution — excludes are usually "don't copy these", not "delete these".
rsync -avh --delete --delete-excluded --exclude='*.log' /src/ /dst/
```

---

## 7. Progress and Stats Flags

```bash
# Show per-file progress (bytes transferred, speed, ETA)
rsync -avh --progress /src/ /dst/

# --info=progress2: single-line overall progress (cleaner for large transfers)
rsync -ah --info=progress2 /src/ /dst/

# --stats: print a summary at the end (files sent, bytes transferred, speedup ratio)
rsync -avh --stats /src/ /dst/

# Combine: overall progress bar + final stats
rsync -ah --info=progress2 --stats /src/ /dst/
```

---

## 8. Bandwidth Limiting

```bash
# --bwlimit: kilobytes per second (not kilobits)
# Limit to 5 MB/s (5000 KB/s)
rsync -avh --bwlimit=5000 /src/ user@host:/dst/

# Limit to 500 KB/s for a background backup that shouldn't saturate the link
rsync -avh --bwlimit=500 /src/ user@host:/dst/
```

---

## 9. Preserve ACLs and Extended Attributes

Standard `-a` does not preserve POSIX ACLs or extended attributes (xattrs).
Add `-A` and `-X` explicitly when the destination filesystem supports them.

```bash
# -A: preserve ACLs (requires ACL support on both source and destination)
# -X: preserve extended attributes (xattrs)
rsync -aAXvh /src/ /dst/

# Full system backup (also preserves hard links with -H)
rsync -aAXHvh --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /dst/
```

---

## 10. rsync Daemon Setup

The rsync daemon (port 873) provides module-based access without requiring SSH.
It has no encryption — use SSH tunneling or rsync-over-SSH for sensitive data.

```ini
# /etc/rsyncd.conf

# Global settings
uid = nobody
gid = nogroup
use chroot = yes
max connections = 4
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid

# A module definition — each [name] block is one accessible path
[backups]
path = /srv/backups
comment = Backup storage
read only = no
auth users = backupuser
secrets file = /etc/rsyncd.secrets
# hosts allow = 10.0.0.0/24
```

```
# /etc/rsyncd.secrets  (mode 600, owned by root)
# Format: username:password (one per line)
backupuser:s3cr3tpassw0rd
```

```bash
# Set correct permissions on secrets file
chmod 600 /etc/rsyncd.secrets

# Start daemon via systemd
sudo systemctl enable --now rsync

# Connect to a daemon module
rsync -av rsync://backupuser@host/backups/

# With password (avoid interactive prompt in scripts)
RSYNC_PASSWORD=s3cr3tpassw0rd rsync -av rsync://backupuser@host/backups/ /local/dst/
```
