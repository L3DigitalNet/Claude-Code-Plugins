# restic Cheatsheet

All examples assume `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` (or `RESTIC_PASSWORD_FILE`) are set in the environment.
When not set, replace with `-r /path/to/repo` on every command and expect a password prompt.

---

## 1. Initialize a Repository

All restic repositories are encrypted. The password cannot be recovered if lost — store it in a
password manager alongside the repository URL before writing your first backup.

```bash
# Set env vars to avoid repeating flags in every command
export RESTIC_REPOSITORY=/path/to/repo
export RESTIC_PASSWORD='a-strong-passphrase'
# Or point to a file (preferred for scripts — avoids the passphrase in shell history)
# export RESTIC_PASSWORD_FILE=/etc/restic/password

# Local repo
restic init

# Remote SFTP (uses SSH; key auth recommended)
export RESTIC_REPOSITORY=sftp:user@host:/backups/myrepo
restic init

# Custom SSH port or jump host
export RESTIC_REPOSITORY=sftp:user@host:/backups/myrepo
export RESTIC_SSH_COMMAND='ssh -p 2222 -i ~/.ssh/restic_key'
restic init

# S3-compatible (MinIO, Wasabi, AWS S3)
export RESTIC_REPOSITORY=s3:https://minio.example.com/mybucket
export AWS_ACCESS_KEY_ID=mykey
export AWS_SECRET_ACCESS_KEY=mysecret
restic init

# Backblaze B2
export RESTIC_REPOSITORY=b2:mybucket:/subpath
export B2_ACCOUNT_ID=myaccountid
export B2_ACCOUNT_KEY=myappkey
restic init

# REST server (self-hosted)
export RESTIC_REPOSITORY=rest:https://alice:password@backup.example.com/myrepo
restic init
```

---

## 2. Backup

The same command runs for every backup — restic deduplicates automatically and only transfers
changed chunks. `--verbose` prints a progress bar and per-file status during the run.

```bash
# Basic backup (assumes env vars are set)
restic backup /home /etc /var/www

# With common exclusions
restic backup /home \
  --exclude-caches \
  --exclude '/home/*/.local/share/Trash' \
  --exclude '/home/*/.mozilla/firefox/*/Cache' \
  --exclude '*.pyc' \
  --exclude '*/node_modules' \
  --exclude '*/.venv'

# Using an excludes file (cleaner for many patterns)
# /etc/restic/excludes.txt:
# /home/*/.cache
# /tmp
# /proc
# /sys
# /dev
restic backup /home /etc --exclude-file /etc/restic/excludes.txt

# Show progress and per-file status during backup
restic backup /home --verbose

# Tag snapshots for filtering later
restic backup /home --tag home --tag daily

# Restrict to one filesystem (don't cross mount points)
restic backup / --one-file-system --exclude-caches

# Preview what would be backed up without running the backup
restic backup /home --dry-run --verbose
```

---

## 3. List and Inspect Snapshots

`restic snapshots` shows all snapshots with their IDs, timestamps, hostnames, and backed-up paths.
Short IDs (first 8 chars) work for interactive use; use full IDs in scripts to avoid collisions.

```bash
# All snapshots
restic snapshots

# Filter by hostname (important in shared repos)
restic snapshots --host myserver

# Filter by tag
restic snapshots --tag daily

# Filter by backed-up path
restic snapshots --path /home

# Show snapshot JSON (useful for scripting)
restic snapshots --json | jq '.[].id'

# List files inside a snapshot
restic ls latest
restic ls latest /home/user/documents

# Diff two snapshots (what changed between them)
restic diff abc12345 def67890

# Stats about the repository (total size, dedup efficiency)
restic stats

# Stats broken down by file
restic stats --mode blobs-per-file
```

---

## 4. Restore

`--target` is the root into which restic recreates the original path structure. Restoring
`/home/user/file.txt` with `--target /tmp/restore` produces `/tmp/restore/home/user/file.txt`.
To restore to original locations, use `--target /`.

```bash
# Restore the most recent snapshot to /tmp/restore
restic restore latest --target /tmp/restore

# Restore a specific snapshot
restic restore abc12345 --target /tmp/restore

# Restore only specific paths from a snapshot
restic restore latest --include /home/user/documents --target /tmp/restore

# Restore a single file (path must match the stored path exactly)
restic restore latest --include /etc/nginx/nginx.conf --target /tmp/

# Restore to original location (requires root for system paths)
restic restore latest --target /

# Dry run — show what would be restored without extracting
restic restore latest --target /tmp/restore --dry-run --verbose
```

---

## 5. Forget Snapshots (Apply Retention Policy)

`restic forget` removes snapshots from the index according to a retention policy. It does NOT free
disk space — the underlying data blobs remain on disk until `prune` runs. Use `--prune` to combine
both operations in a single command. Always preview with `--dry-run` before running destructively.

```bash
# forget ONLY removes snapshot metadata — disk space is NOT freed until prune runs.
# Use --prune to combine both operations in one command.

# Keep: 7 daily, 4 weekly, 6 monthly, 2 yearly — forget everything else
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --keep-yearly 2 \
  --prune

# Dry run: preview which snapshots would be removed (no changes made)
restic forget --dry-run \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --keep-yearly 2

# Filter forget to a specific hostname (critical in shared repos)
restic forget --host myserver --keep-daily 7 --keep-weekly 4 --prune

# Filter forget to a specific tag
restic forget --tag daily --keep-last 30 --prune

# Keep only the last N snapshots regardless of date
restic forget --keep-last 10 --prune

# Forget a specific snapshot by ID (remove unconditionally)
restic forget abc12345
```

---

## 6. Prune (Free Disk Space)

`prune` removes data blobs that are no longer referenced by any snapshot. This is the step that
actually reclaims disk space. If you used `forget --prune`, this step is already done. Run it
separately only if you ran `forget` without `--prune`.

```bash
# Free disk space by removing unreferenced data blobs
restic prune

# Limit space reclaimed per run (useful on slow storage to avoid long lock hold times)
restic prune --max-repack-size 1G

# Show what would be pruned without doing it
restic prune --dry-run
```

---

## 7. Check Repository Integrity

`check` verifies the repository index and snapshot metadata in seconds to minutes. `check
--read-data` downloads and verifies every data chunk against its hash — the only way to catch
silent corruption or partial deletion, but it can take hours for large repositories. Schedule
`--read-data` weekly or monthly, not after every backup.

```bash
# Verify repository structure and snapshot metadata (fast)
restic check

# Verify ALL data chunks by downloading and hashing them (slow — run weekly/monthly)
restic check --read-data

# Verify a random subset of data (good compromise between speed and coverage)
restic check --read-data-subset=10%

# Verify a specific number of pack files
restic check --read-data-subset=5/100

# Repair incomplete pack files after an interrupted prune
restic repair packs
# Then re-run prune to clean up
restic prune
```

---

## 8. FUSE Mount for Browsing Backups

FUSE mount exposes all snapshots as a read-only filesystem, grouped under
`/mnt/restic/snapshots/` by date and host. This lets you browse before committing to a restore.

Requires the `fuse` package (`apt install fuse` / `dnf install fuse`).
The user running the mount must be in the `fuse` group, or run as root.

```bash
# Create mount point
mkdir /mnt/restic

# Mount all snapshots (each snapshot appears as a dated subdirectory)
restic mount /mnt/restic
# Browse: ls /mnt/restic/snapshots/

# Navigate to a specific snapshot
ls /mnt/restic/snapshots/latest/home/user/

# Copy files out normally
cp /mnt/restic/snapshots/latest/home/user/file.txt /tmp/

# Mount runs in the foreground — open a second terminal to browse, then Ctrl-C to unmount
# Or run in background and unmount explicitly:
restic mount /mnt/restic &
fusermount -u /mnt/restic
# or
umount /mnt/restic
```

---

## 9. Key Management

A restic repository can hold multiple encryption keys. This supports team scenarios where each
member has their own password, and allows password rotation without re-encrypting data.

```bash
# List all encryption keys in the repository
restic key list

# Add a new key (prompts for the new password)
restic key add

# Change the password for the current key (prompts for old password, then new password twice)
restic key passwd

# Remove a key by ID (use 'restic key list' to find the ID)
# Cannot remove the last remaining key — you would lock yourself out of the repository
restic key remove <key-id>
```

---

## 10. Environment Variable Reference

Set these in a shell environment file (`/etc/restic/env`, mode 600) and load with
`EnvironmentFile=` in systemd or `source` in scripts.

| Variable | Purpose | Example |
|----------|---------|---------|
| `RESTIC_REPOSITORY` | Repo URL (required if no `-r` flag) | `s3:https://minio.host/bucket` |
| `RESTIC_PASSWORD` | Repo password (plaintext — avoid in scripts) | `mysecret` |
| `RESTIC_PASSWORD_FILE` | Path to a file containing the password (preferred) | `/etc/restic/password` |
| `RESTIC_PASSWORD_COMMAND` | Command that prints the password to stdout | `pass show restic/myrepo` |
| `RESTIC_COMPRESSION` | Compression level: `auto`, `max`, `off` (default: `auto`) | `auto` |
| `RESTIC_PACK_SIZE` | Pack file size in MiB (default 128; increase for large repos) | `128` |
| `RESTIC_SSH_COMMAND` | SSH command used for SFTP backend | `ssh -p 2222 -i ~/.ssh/restic_key` |
| `AWS_ACCESS_KEY_ID` | S3/MinIO/Wasabi access key | — |
| `AWS_SECRET_ACCESS_KEY` | S3/MinIO/Wasabi secret key | — |
| `AWS_DEFAULT_REGION` | S3 region (required for AWS; often optional for MinIO) | `us-east-1` |
| `B2_ACCOUNT_ID` | Backblaze B2 account ID | — |
| `B2_ACCOUNT_KEY` | Backblaze B2 application key | — |
