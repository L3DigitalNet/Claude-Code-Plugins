# Borg Backup Cheatsheet

All examples assume `BORG_REPO` and `BORG_PASSPHRASE` are set in the environment.
When not set, replace `/repo` with the full repository path and expect a passphrase prompt.

---

## 1. Initialize a Repository

**repokey mode** (recommended): encryption key stored inside the repo, protected by passphrase.
Key is accessible as long as the repo is accessible — simplest for single-machine use.

```bash
export BORG_PASSPHRASE='a-strong-passphrase'
borg init --encryption=repokey /path/to/repo

# Remote over SSH
borg init --encryption=repokey user@host:/path/to/repo
```

**keyfile mode**: encryption key stored in `~/.config/borg/keys/` on the client machine.
Key survives repo loss but must be backed up separately or the repo is unrecoverable.

```bash
borg init --encryption=keyfile /path/to/repo

# Back up the key immediately after init
borg key export /path/to/repo ~/borg-key-backup.txt
# Or as paper-friendly base64
borg key export --paper /path/to/repo
```

**No encryption** (dev/testing only):

```bash
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
borg init --encryption=none /path/to/repo
```

---

## 2. Create Archives (Backup)

Archive names support strftime placeholders. `{now:%Y-%m-%dT%H:%M}` expands at creation time.

**First backup:**

```bash
borg create \
  --compression lz4 \
  --progress \
  --stats \
  /repo::{hostname}-{now:%Y-%m-%dT%H:%M} \
  /home /etc /var/www

# --compression options: none, lz4 (fast), zstd (balanced), lzma (small)
# --stats prints dedup ratio and transfer size after completion
```

**Subsequent incrementals** (identical command — borg deduplicates automatically):

```bash
borg create \
  --compression lz4 \
  --exclude '/home/*/.cache' \
  --exclude '/home/*/.local/share/Trash' \
  --exclude '*.pyc' \
  /repo::{hostname}-{now:%Y-%m-%dT%H:%M} \
  /home /etc
```

**Exclude patterns file** (cleaner for many exclusions):

```bash
# /etc/borg/excludes.txt
/home/*/.cache
/home/*/.local/share/Trash
/proc
/sys
/dev
/run
/tmp

borg create --exclude-from /etc/borg/excludes.txt /repo::{hostname}-{now:%Y-%m-%dT%H:%M} /
```

---

## 3. List and Verify Archives

```bash
# All archives in the repo
borg list /repo

# With size info
borg list --format '{archive:<40} {time} {size:<10}' /repo

# Contents of a specific archive (files and directories)
borg list /repo::archive-name

# Filter contents by path
borg list /repo::archive-name home/chris/documents

# Repo statistics (total size, dedup ratio, number of archives)
borg info /repo

# Single archive statistics
borg info /repo::archive-name
```

---

## 4. Restore: Full Backup or Single Files

Extraction recreates paths relative to the current directory.
Run from `/` to restore to original locations, or from a temp dir for selective restore.

**Full archive restore:**

```bash
cd /
borg extract /repo::archive-name
# Paths are restored as /home/..., /etc/..., etc.
```

**Single file or directory:**

```bash
# Note: no leading slash in the path argument
borg extract /repo::archive-name home/chris/documents/report.pdf

# Extract to a specific directory
mkdir /tmp/restore
cd /tmp/restore
borg extract /repo::archive-name home/chris/documents
```

**Dry run (list what would be extracted):**

```bash
borg extract --dry-run --list /repo::archive-name home/chris
```

---

## 5. Mount Repository for Browsing (FUSE)

FUSE mount lets you browse all archives as a filesystem before deciding what to restore.
Requires `borgbackup[fuse]` or the `python-llfuse` / `python-pyfuse3` package.

```bash
# Mount the entire repo (all archives visible as subdirs)
mkdir /mnt/borgmount
borg mount /repo /mnt/borgmount

# Browse
ls /mnt/borgmount/
# → archive-2025-01-15  archive-2025-01-22  ...

# Mount a single archive
borg mount /repo::archive-name /mnt/borgmount

# Copy files out normally
cp /mnt/borgmount/archive-name/home/chris/file.txt /tmp/

# Unmount when done
borg umount /mnt/borgmount
```

---

## 6. Prune Old Archives

`borg prune` removes archives outside your retention policy. It does NOT free disk space —
run `borg compact` afterward for that.

```bash
# Common retention schedule: 7 daily, 4 weekly, 6 monthly, 1 yearly
borg prune \
  --keep-daily=7 \
  --keep-weekly=4 \
  --keep-monthly=6 \
  --keep-yearly=1 \
  --list \
  /repo

# --list shows which archives are kept and which are pruned (recommended)
# --dry-run previews without deleting anything
borg prune --dry-run --keep-daily=7 --keep-weekly=4 --keep-monthly=6 --list /repo

# Limit prune to archives matching a prefix (useful when multiple hosts share one repo)
borg prune \
  --glob-archives 'myhost-*' \
  --keep-daily=7 \
  --keep-weekly=4 \
  --keep-monthly=6 \
  /repo
```

---

## 7. Compact After Prune

Prune marks archives deleted; compact reclaims the actual disk space.

```bash
borg compact /repo

# With progress output
borg compact --progress /repo
```

Run compact after every prune in automated scripts:

```bash
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 /repo && borg compact /repo
```

---

## 8. Repository Integrity Check

```bash
# Full check: segment files + archive metadata + data integrity
borg check /repo

# Archives only (faster — skips segment-level check)
borg check --archives-only /repo

# Verify only the last 3 archives (fastest for routine use)
borg check --last 3 /repo

# Repair mode (use only when check reports fixable errors)
borg check --repair /repo
```

---

## 9. SSH Remote Backup with Restricted authorized_keys

On the remote server, restrict the borg SSH key so it can only run `borg serve`.
This prevents the backup key from granting full shell access.

**Remote `~/.ssh/authorized_keys` entry:**

```
command="borg serve --restrict-to-path /var/backups/client1 --append-only",restrict ssh-ed25519 AAAA... backup@client1
```

- `--restrict-to-path`: borg can only access that directory
- `--append-only`: prevents the client from deleting archives (ransomware protection); requires a separate privileged borg invocation to prune
- `restrict`: OpenSSH keyword that disables port forwarding, X11, PTY, etc.

**Client-side backup command** (borg connects over SSH automatically):

```bash
export BORG_REPO='user@remote.host:/var/backups/client1'
export BORG_PASSPHRASE='passphrase'
borg create /repo::{hostname}-{now:%Y-%m-%dT%H:%M} /home /etc
```

**SSH options** (custom port or key):

```bash
export BORG_RSH='ssh -i ~/.ssh/borg_key -p 2222'
borg create /repo::archive-name /source
```

---

## 10. borgmatic Configuration (Brief)

borgmatic wraps borg with a YAML config, handles create/prune/compact/check in one command,
and supports hooks (pre/post backup notifications, health checks).

**Install:**

```bash
pip install borgmatic
# or
apt install borgmatic
```

**Minimal config** at `/etc/borgmatic/config.yaml`:

```yaml
repositories:
  - path: /path/to/repo
    label: local

source_directories:
  - /home
  - /etc

encryption_passphrase: "your-passphrase"  # or use passcommand

retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6

consistency:
  checks:
    - name: repository
    - name: archives
      frequency: 2 weeks
```

**Run all operations in sequence:**

```bash
borgmatic create prune compact check --verbosity 1
```

**Systemd timer** (preferred over cron for borgmatic):

```bash
borgmatic --init  # generates systemd unit files
systemctl enable --now borgmatic.timer
```

---

## 11. Key Backup and Recovery

**Export the repository key** (repokey mode — key lives inside the repo):

```bash
# To a file
borg key export /repo ~/borg-key.txt

# As human-readable base64 (print and store offline)
borg key export --paper /repo

# As QR code (requires qrencode)
borg key export --qr-html /repo ~/borg-key.html
```

**Import a key** (after repo loss or migration):

```bash
borg key import /repo ~/borg-key.txt
```

**Key storage checklist:**

- Store the exported key in a password manager separate from the repo machine
- Store the passphrase in the same password manager entry
- For keyfile mode: back up `~/.config/borg/keys/` — losing this directory without a key export means the repo is permanently unreadable
- Test recovery: `borg list /repo` from a different machine using the exported key and passphrase
