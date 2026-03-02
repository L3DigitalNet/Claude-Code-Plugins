# rclone Command Cheatsheet

Task-organized examples. Replace `remote:` with your configured remote name and bucket/path.

---

## 1. Configure a New Remote

Launch the interactive wizard:

```bash
rclone config
```

Walk through `n` (new remote), enter a name, select the backend type by number, then enter credentials.

**AWS S3 non-interactive** (scripted setup using environment variables):

```bash
# rclone respects AWS env vars for S3 — no config file entry needed.
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"

rclone lsd :s3:my-bucket-name
```

**Backblaze B2** (`rclone.conf` entry):

```ini
[b2]
type = b2
account = YOUR_ACCOUNT_ID
key = YOUR_APPLICATION_KEY
```

**Google Drive** (requires browser for OAuth; run on a machine with a browser):

```bash
rclone config
# Select "n", name it "gdrive", type "drive"
# Follow OAuth prompts in browser
# On headless servers: complete OAuth on another machine with "rclone authorize drive"
# then paste the token into the headless session
```

---

## 2. List and Explore Remotes

```bash
# List all configured remote names
rclone listremotes

# List top-level directories in a remote (non-recursive)
rclone lsd remote:

# List top-level directories in a specific path
rclone lsd remote:backups/2025

# List files with sizes (recursive)
rclone ls remote:bucket/path

# List files, one per line — good for scripting
rclone lsf remote:bucket/path

# List as JSON with full metadata
rclone lsjson remote:bucket/path

# Get total size and file count
rclone size remote:bucket/path
```

---

## 3. Copy Files to Cloud (No Deletion)

`copy` transfers files from source to destination. Files in the destination that don't exist in the source are left untouched.

```bash
# Copy a local directory to cloud
rclone copy /home/user/documents remote:bucket/documents

# Copy with progress display
rclone copy /home/user/documents remote:bucket/documents --progress

# Copy with parallel transfers (default 4; increase for high-latency remotes)
rclone copy /home/user/documents remote:bucket/documents \
  --transfers 16 \
  --checkers 32 \
  --progress

# Copy only files matching a pattern
rclone copy /home/user/documents remote:bucket/documents \
  --include "*.pdf" \
  --progress

# Copy excluding a directory
rclone copy /home/user/project remote:bucket/project \
  --exclude ".git/**" \
  --progress
```

---

## 4. Sync to Cloud (Mirror with Deletion)

`sync` makes the destination identical to the source. Files in the destination that are not in the source **are deleted**. Always dry-run first.

```bash
# Dry run — shows what would change without touching anything
rclone sync /home/user/documents remote:bucket/documents --dry-run

# Live sync after confirming dry-run output
rclone sync /home/user/documents remote:bucket/documents --progress

# Sync with verbose logging to file
rclone sync /home/user/documents remote:bucket/documents \
  --log-file /var/log/rclone-sync.log \
  --log-level INFO \
  --progress

# Sync with backup of deleted/changed files (keeps old versions in a separate path)
rclone sync /home/user/documents remote:bucket/documents \
  --backup-dir remote:bucket/documents-backup/$(date +%Y-%m-%d) \
  --progress
```

---

## 5. Dry Run Before Sync

Use `--dry-run` any time you're unsure what `sync` or `move` will do.

```bash
# Show what sync would transfer and delete — no changes made
rclone sync /data/important remote:bucket/important --dry-run

# Verbose dry-run — shows each file decision
rclone sync /data/important remote:bucket/important --dry-run -v

# check: verify current state without syncing (compares checksums or size+modtime)
rclone check /data/important remote:bucket/important

# check using size+modtime only (for backends without checksum support)
rclone check /data/important remote:bucket/important --size-only
```

---

## 6. Mount Cloud Storage as Filesystem

Requires the `fuse3` (or `fuse`) package. The mount point must exist and be empty.

```bash
# Install FUSE
sudo apt install fuse3       # Debian/Ubuntu
sudo dnf install fuse3       # Fedora/RHEL

# Create mount point
sudo mkdir -p /mnt/gdrive

# Mount (foreground — blocks terminal; use --daemon or systemd for background)
rclone mount gdrive: /mnt/gdrive

# Mount in background with VFS caching for better performance
rclone mount remote:bucket /mnt/mybucket \
  --daemon \
  --vfs-cache-mode full \
  --vfs-cache-max-size 10G \
  --log-file /var/log/rclone-mount.log

# Unmount
fusermount3 -u /mnt/mybucket
# or
sudo umount /mnt/mybucket
```

**systemd unit** for persistent mount (`/etc/systemd/system/rclone-mount.service`):

```ini
[Unit]
Description=rclone mount remote:bucket
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount remote:bucket /mnt/mybucket \
  --vfs-cache-mode full \
  --vfs-cache-max-size 10G \
  --log-file /var/log/rclone-mount.log \
  --log-level INFO
ExecStop=/bin/fusermount3 -u /mnt/mybucket
Restart=on-failure
User=youruser

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rclone-mount.service
```

---

## 7. Serve Cloud Storage as Local Network Share

Serve a remote over standard protocols to other machines on the network. None of these expose authentication by default — add `--user` and `--pass` for basic auth.

```bash
# Serve over HTTP (read-only by default)
rclone serve http remote:bucket --addr :8080

# Serve over WebDAV (mountable in Windows Explorer, macOS Finder, Nautilus)
rclone serve webdav remote:bucket --addr :8080 --user alice --pass secret

# Serve over SFTP (standard SSH/SFTP clients)
rclone serve sftp remote:bucket --addr :2022

# Serve as S3-compatible API (use with any S3 client or SDK)
rclone serve s3 remote:bucket --addr :9000 \
  --s3-authkey YOUR_ACCESS_KEY \
  --s3-secretkey YOUR_SECRET_KEY
```

---

## 8. Crypt Remote for Client-Side Encryption

A `crypt` remote wraps an existing remote. rclone encrypts files before uploading and decrypts on download. The underlying remote stores only ciphertext.

**Configure via wizard:**

```bash
rclone config
# n → new remote
# name: "encrypted"
# type: crypt
# remote: b2:my-bucket/encrypted-prefix   <- the underlying remote and path
# filename_encryption: standard            <- encrypts filenames too
# directory_name_encryption: true
# Enter password and confirm (save it — losing it = data loss)
```

**Use the crypt remote exactly like any other remote:**

```bash
# Copy plaintext files — they arrive encrypted in B2
rclone copy /home/user/private encrypted:

# List decrypted filenames (rclone decrypts on the fly)
rclone ls encrypted:

# Restore plaintext files
rclone copy encrypted: /home/user/restored
```

---

## 9. Bandwidth Limiting and Scheduling

```bash
# Limit to 10 MB/s at all times
rclone copy /data remote:bucket --bwlimit 10M

# Time-based schedule: full speed 08:00-17:00 on weekdays, 1 MB/s otherwise
# Format: "HH:MM,bandwidth HH:MM,bandwidth ..."
rclone sync /data remote:bucket \
  --bwlimit "08:00,off 17:00,1M"

# Limit transactions per second (useful for API rate limit compliance)
rclone copy /data remote:bucket --tpslimit 4 --tpslimit-burst 4

# Limit parallel transfers (default 4)
rclone copy /data remote:bucket --transfers 8
```

---

## 10. Check / Verify Sync Integrity

```bash
# Compare source and destination using checksums (default when backend supports it)
rclone check /home/user/documents remote:bucket/documents

# Compare using size and modtime only (fallback for backends without checksum support)
rclone check /home/user/documents remote:bucket/documents --size-only

# Output missing/extra/different files to separate log files
rclone check /home/user/documents remote:bucket/documents \
  --missing-on-dst /tmp/missing-on-dst.txt \
  --missing-on-src /tmp/missing-on-src.txt \
  --differ /tmp/differ.txt

# Download and verify one file's hash manually
rclone hashsum MD5 remote:bucket/path/file.tar.gz
```

---

## 11. Automated Backup with systemd Timer

Two files: a service unit that runs rclone and a timer unit that schedules it.

**`/etc/systemd/system/rclone-backup.service`:**

```ini
[Unit]
Description=rclone backup /home to B2
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
# Run as the user whose rclone config to use
User=youruser
ExecStart=/usr/bin/rclone sync /home/youruser/documents b2:my-bucket/documents \
  --log-file /var/log/rclone-backup.log \
  --log-level INFO \
  --bwlimit "09:00,off 18:00,5M" \
  --backup-dir b2:my-bucket/documents-archive/%Y-%m-%d
```

**`/etc/systemd/system/rclone-backup.timer`:**

```ini
[Unit]
Description=Run rclone backup daily at 02:00

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rclone-backup.timer

# Verify timer is scheduled
systemctl list-timers rclone-backup.timer

# Run backup immediately (without waiting for timer)
sudo systemctl start rclone-backup.service

# Check last run output
journalctl -u rclone-backup.service -n 50
```
