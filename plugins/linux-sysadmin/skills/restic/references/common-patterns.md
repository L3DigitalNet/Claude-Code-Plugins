# restic Common Patterns

Numbered recipes for the most common restic deployment scenarios.
Each section is self-contained — copy the commands directly into your shell or scripts.

---

## 1. Local Backend

The simplest setup: repository on a local path (external disk, NAS mount, or another local directory).
Useful for workstation backups to an attached drive or network share mounted over NFS/CIFS.

```bash
# Create password file with restricted permissions
install -m 600 /dev/null /etc/restic/password
echo 'a-strong-passphrase' > /etc/restic/password

# Export environment (add to /etc/restic/env or shell profile for persistence)
export RESTIC_REPOSITORY=/mnt/backup-drive/myhost
export RESTIC_PASSWORD_FILE=/etc/restic/password

# Initialize the repository
restic init

# First backup with recommended exclusions
restic backup \
  --one-file-system \
  --exclude-caches \
  --exclude '/home/*/.local/share/Trash' \
  --exclude '/home/*/.mozilla/firefox/*/Cache' \
  --exclude '*/node_modules' \
  --exclude '*/.venv' \
  /home /etc /var/www

# Verify the backup was written correctly
restic check

# Apply retention policy and free disk space
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune
```

---

## 2. SFTP Backend

Restic connects to the remote host using the system SSH client. Key-based authentication is
strongly recommended — password prompts break unattended backups.

```bash
# Generate a dedicated SSH key for restic (no passphrase — used unattended)
ssh-keygen -t ed25519 -f ~/.ssh/restic_key -C "restic@$(hostname)" -N ''

# Copy the public key to the remote server
ssh-copy-id -i ~/.ssh/restic_key.pub user@backup.host

# Configure restic to use the dedicated key
export RESTIC_SSH_COMMAND='ssh -i ~/.ssh/restic_key -o StrictHostKeyChecking=yes'

# Standard SFTP URL format
export RESTIC_REPOSITORY=sftp:user@backup.host:/backups/myrepo
export RESTIC_PASSWORD_FILE=/etc/restic/password
restic init

# Custom SSH port
export RESTIC_REPOSITORY='sftp:user@backup.host:/backups/myrepo'
export RESTIC_SSH_COMMAND='ssh -i ~/.ssh/restic_key -p 2222'
restic init

# Via jump host
export RESTIC_SSH_COMMAND='ssh -i ~/.ssh/restic_key -J jumpuser@jump.host'
restic init
```

**Restricted `authorized_keys` entry** (prevents the restic key from granting shell access):

```
restrict,command="restic serve --append-only --path /backups/myrepo" ssh-ed25519 AAAA... restic@client
```

- `restrict`: disables port forwarding, X11, PTY allocation, and agent forwarding
- `--append-only`: the client can write new snapshots but cannot delete existing ones (ransomware protection)
- When `--append-only` is active, `forget` and `prune` must be run locally on the server by an admin

---

## 3. S3-Compatible Backend (MinIO / Wasabi / AWS S3)

Restic uses the same `s3:` scheme for AWS S3, MinIO, and Wasabi — only the endpoint URL differs.
Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from your credentials manager (not inline).

**MinIO (self-hosted):**

```bash
export RESTIC_REPOSITORY=s3:http://localhost:9000/restic-backups
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from your secrets store
restic init
```

**Wasabi:**

```bash
export RESTIC_REPOSITORY=s3:https://s3.wasabisys.com/mybucket
# Wasabi does not use AWS_DEFAULT_REGION — the region is encoded in the endpoint
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from your secrets store
restic init
```

**AWS S3:**

```bash
export RESTIC_REPOSITORY=s3:s3.amazonaws.com/mybucket
export AWS_DEFAULT_REGION=us-east-1
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from your secrets store
restic init
```

**Minimum IAM policy for an S3 bucket used by restic:**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads",
                "s3:ListBucketVersions"
            ],
            "Resource": "arn:aws:s3:::mybucket"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": "arn:aws:s3:::mybucket/*"
        }
    ]
}
```

Create a dedicated IAM user with only these permissions. Do not reuse root or admin credentials.

---

## 4. Backblaze B2 Backend

B2 is a cost-effective option for offsite backups. Create a Backblaze account, then create a
bucket and an application key restricted to that bucket.

Required application key capabilities: `readFiles`, `writeFiles`, `deleteFiles`, `listBuckets`,
`listFiles`, `readBucketEncryption`, `writeBucketEncryption`.

```bash
export RESTIC_REPOSITORY=b2:mybucket-name:/restic
# Set B2_ACCOUNT_ID and B2_ACCOUNT_KEY from your secrets store
export RESTIC_PASSWORD_FILE=/etc/restic/password

restic init
restic backup /home /etc --exclude-caches
```

The subpath after the bucket name (`/restic`) is optional but useful if you share the bucket with
other tools. Each restic repository must have its own exclusive subpath — multiple repositories
cannot share the same prefix.

---

## 5. REST Server (Self-Hosted)

`rest-server` is the official restic server implementation. It provides an HTTP API that restic
uses as a backend, with optional authentication and TLS via a reverse proxy.

**Install rest-server:**

```bash
# Download the latest release binary
wget https://github.com/restic/rest-server/releases/download/v0.13.0/rest-server_0.13.0_linux_amd64.tar.gz
tar xf rest-server_*.tar.gz
sudo mv rest-server /usr/local/bin/
sudo chmod +x /usr/local/bin/rest-server

# Create data directory and dedicated service user
sudo mkdir -p /var/lib/restic-server
sudo useradd -r -s /bin/false restic-server
sudo chown restic-server:restic-server /var/lib/restic-server
```

**Create user authentication with `.htpasswd`:**

```bash
sudo apt install apache2-utils   # provides htpasswd
sudo mkdir -p /etc/restic-server

# Create the password file with the first user (-c creates the file)
sudo htpasswd -B -c /etc/restic-server/.htpasswd alice

# Add additional users (omit -c to avoid overwriting the existing file)
sudo htpasswd -B /etc/restic-server/.htpasswd bob

sudo chown restic-server:restic-server /etc/restic-server/.htpasswd
sudo chmod 640 /etc/restic-server/.htpasswd
```

**Systemd unit** (`/etc/systemd/system/restic-rest-server.service`):

```ini
[Unit]
Description=Restic REST Server
After=network.target

[Service]
Type=simple
User=restic-server
ExecStart=/usr/local/bin/rest-server \
  --path /var/lib/restic-server \
  --htpasswd-file /etc/restic-server/.htpasswd \
  --listen :8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now restic-rest-server
```

**TLS via Caddy** (recommended — handles certificate renewal automatically):

```
backup.example.com {
    reverse_proxy localhost:8000
}
```

Without TLS, credentials travel in plaintext. Always put a TLS reverse proxy in front of
rest-server when accessible over a network.

**Connecting a restic client:**

```bash
export RESTIC_REPOSITORY=rest:https://alice:password@backup.example.com/myrepo
export RESTIC_PASSWORD_FILE=/etc/restic/password
restic init
restic backup /home /etc
```

Each user gets their own repository path. `alice` can only access paths under `/var/lib/restic-server/alice/`
by default when rest-server is run without `--no-auth`.

**Append-only mode** (ransomware protection):

Prevents clients from deleting snapshots. `forget` and `prune` must be run locally on the server
by an admin — the client cannot destroy its own backups even if compromised.

```ini
ExecStart=/usr/local/bin/rest-server \
  --path /var/lib/restic-server \
  --htpasswd-file /etc/restic-server/.htpasswd \
  --append-only \
  --listen :8000
```

To prune from the server side (bypassing append-only):

```bash
# Run locally on the server as root or restic-server user
export RESTIC_REPOSITORY=/var/lib/restic-server/alice/myrepo
export RESTIC_PASSWORD_FILE=/etc/restic/alice-password
restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6
```

---

## 6. Systemd Timer for Automated Backups

**`/etc/restic/env`** (environment file — keep mode 600):

```
RESTIC_REPOSITORY=s3:https://minio.example.com/backups
RESTIC_PASSWORD_FILE=/etc/restic/password
# Load AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from your secrets store,
# or set them here if this file is only readable by root (mode 600, owned by root).
```

**`/etc/restic/excludes.txt`**:

```
/home/*/.cache
/home/*/.local/share/Trash
/tmp
/proc
/sys
/dev
/run
/var/tmp
*/node_modules
*/.venv
*/.tox
```

**`/etc/systemd/system/restic-backup.service`**:

```ini
[Unit]
Description=Restic Backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
EnvironmentFile=/etc/restic/env
# Unlock any stale lock from a previous crashed run before starting
ExecStartPre=/usr/bin/restic unlock --remove-all
ExecStart=/usr/bin/restic backup \
  --one-file-system \
  --exclude-caches \
  --exclude-file /etc/restic/excludes.txt \
  /home /etc /var/www
ExecStartPost=/usr/bin/restic forget \
  --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6
# OnFailure: consider systemd-email or a healthchecks.io notification hook
```

**`/etc/systemd/system/restic-backup.timer`**:

```ini
[Unit]
Description=Daily Restic Backup
Requires=restic-backup.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

`Persistent=true` means if the machine was off at the scheduled time, the backup runs at next boot.
`RandomizedDelaySec=1h` spreads load when many machines back up to the same remote.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now restic-backup.timer

# Verify the timer is scheduled
systemctl list-timers restic-backup.timer

# Run the backup immediately (for testing)
sudo systemctl start restic-backup.service

# Watch live output
sudo journalctl -fu restic-backup.service
```

**Prevent overlapping runs** (systemd handles this automatically when using a `.service` + `.timer`
pair with `Type=oneshot`, but add `Conflicts=` explicitly if you have multiple backup services):

```ini
[Unit]
Conflicts=restic-backup-full.service
```

---

## 7. Retention Policy Examples

`restic forget` applies retention rules independently per host and per backed-up path. In a
shared repository (multiple hosts writing to the same backend), always pass `--host` to avoid
one host's policy expiring another host's snapshots.

| Policy | Command flags | Effective coverage |
|--------|---------------|-------------------|
| Rolling 30 days | `--keep-daily 30` | Last 30 days of daily snapshots |
| Tiered (home server) | `--keep-daily 7 --keep-weekly 4 --keep-monthly 6` | ~6 months of coverage |
| Tiered (business) | `--keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 3` | ~3 years of coverage |
| Last N only | `--keep-last 10` | Always 10 most recent snapshots |
| Keep everything | _(no forget flags)_ | Snapshots accumulate indefinitely |

**How the tiers interact:** With `--keep-daily 7 --keep-weekly 4`, restic keeps the 7 most recent
daily snapshots and up to 4 additional weekly snapshots for older periods — the weekly bucket covers
the gap beyond 7 days. The oldest dailies are not kept separately alongside the weeklies; the
weeklies subsume them. The result is roughly: full coverage for the last week, one snapshot per
week for the month before that.

```bash
# Typical tiered policy with dry run first
restic forget --dry-run \
  --host $(hostname) \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --keep-yearly 2

# Apply it
restic forget \
  --host $(hostname) \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --keep-yearly 2 \
  --prune
```
