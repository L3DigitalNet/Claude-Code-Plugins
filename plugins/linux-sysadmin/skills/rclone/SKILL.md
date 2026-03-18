---
name: rclone
description: >
  rclone cloud storage management: configuring remotes, copying and syncing files
  to/from cloud providers, mounting cloud storage as a filesystem, serving cloud
  storage over HTTP/WebDAV/SFTP/S3, client-side encryption with crypt remotes,
  bandwidth throttling, and integrity verification.
  MUST consult when installing, configuring, or troubleshooting rclone.
triggerPhrases:
  - "rclone"
  - "cloud backup"
  - "rclone sync"
  - "rclone S3"
  - "rclone mount"
  - "cloud storage sync"
  - "Backblaze rclone"
  - "rclone remote"
globs:
  - "**/rclone.conf"
  - "**/.config/rclone/rclone.conf"
last_verified: "unverified"
---

## Identity

- **Binary**: `rclone`
- **Config**: `~/.config/rclone/rclone.conf` (or `$RCLONE_CONFIG`)
- **Logs**: `--log-file=/path/to/rclone.log`, `--log-level DEBUG|INFO|NOTICE|ERROR`
- **Distro install**: `apt install rclone` / `dnf install rclone` / `curl https://rclone.org/install.sh | sudo bash`
- **Backends (70+)**: S3-compatible (AWS S3, MinIO, Wasabi, Cloudflare R2), Google Cloud Storage, Azure Blob, Backblaze B2, Dropbox, Google Drive, OneDrive, SFTP, WebDAV, FTP, local filesystem, HTTP, Mega, Box, pCloud, Jottacloud, Yandex Disk, and more

## Quick Start

```bash
sudo apt install rclone
rclone config                        # interactive wizard to add a remote
rclone listremotes                   # verify configured remotes
rclone lsd remote:                   # list top-level dirs on remote
rclone copy /local/path remote:bucket/path
```

## Key Operations

| Task | Command |
|------|---------|
| Configure new remote | `rclone config` |
| List configured remotes | `rclone listremotes` |
| List top-level directories | `rclone lsd remote:bucket` |
| List files (simple) | `rclone lsf remote:path` |
| List files (detailed) | `rclone ls remote:path` |
| List files (JSON) | `rclone lsjson remote:path` |
| Copy (no delete) | `rclone copy src: dst:` |
| Sync (mirror) | `rclone sync src: dst:` |
| Move | `rclone move src: dst:` |
| Check/verify | `rclone check src: dst:` |
| Mount as filesystem | `rclone mount remote:path /mnt/point` |
| Serve over HTTP | `rclone serve http remote:path --addr :8080` |
| Serve over WebDAV | `rclone serve webdav remote:path --addr :8080` |
| Serve over SFTP | `rclone serve sftp remote:path --addr :2022` |
| Serve as S3 | `rclone serve s3 remote:path --addr :9000` |
| Bisync (two-way) | `rclone bisync src: dst:` |
| Delete files | `rclone delete remote:path` |
| Purge directory | `rclone purge remote:path` |
| Create directory | `rclone mkdir remote:path/newdir` |
| Download and print | `rclone cat remote:path/file.txt` |
| Get size/count | `rclone size remote:path` |
| Encrypt/decrypt remote | `rclone config` (type=crypt) |
| Backend commands | `rclone backend <command> remote:` |
| Reconnect OAuth | `rclone config reconnect remote:` |
| Config show | `rclone config show` |

## Expected State

- Config file exists at `~/.config/rclone/rclone.conf` with at least one `[remote-name]` section
- OAuth remotes have a valid `token` field (expires; refresh with `rclone config reconnect`)
- FUSE package installed if using `rclone mount`: `apt install fuse3` / `dnf install fuse3`
- Mount point directory exists and is empty before mounting

## Health Checks

1. `rclone listremotes` — lists configured remotes (empty output means no remotes configured)
2. `rclone lsd remote:` — lists top-level dirs; authentication and connectivity failure surfaces here

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `didn't find section in config file` | Wrong remote name or typo | `rclone listremotes` to see exact names |
| `oauth2: token expired` / `401 Unauthorized` | OAuth token expired | `rclone config reconnect remote:` |
| `429 Too Many Requests` | Provider rate limiting | Add `--tpslimit 4 --tpslimit-burst 4`; check provider quotas |
| Files deleted from destination unexpectedly | Used `sync` instead of `copy` | `sync` mirrors source; use `copy` for additive transfers |
| `mount: fusermount: exec: "fusermount3": executable file not found` | FUSE not installed | `apt install fuse3` or `dnf install fuse3` |
| `NOTICE: ... Bandwidth limit reached` | `--bwlimit` cap hit | Adjust schedule or increase cap |
| `Failed to create file system` on mount | Mount point not empty or doesn't exist | `ls /mnt/point` — must exist and be empty |
| Slow transfers to S3-compatible | Default `--transfers 4` too low | Add `--transfers 16 --checkers 32` for high-latency remotes |
| `checksum not supported` on check | Backend doesn't support checksums | Use `--size-only` flag with `rclone check` |
| Config file permissions warning | Config readable by other users | `chmod 600 ~/.config/rclone/rclone.conf` |

## Pain Points

- **`sync` deletes; `copy` does not**: `rclone sync src: dst:` removes anything in `dst:` that isn't in `src:`. For a first run or when unsure, use `rclone copy`. Always use `--dry-run` before running `sync` on production data.
- **`--dry-run` is not optional**: `rclone sync --dry-run src: dst:` shows exactly what would be transferred or deleted without touching anything. Skip it once, regret it once.
- **OAuth tokens expire**: Google Drive, Dropbox, OneDrive tokens expire. `rclone config reconnect remote:` refreshes interactively. For headless servers, use `rclone authorize` on a machine with a browser and paste the token.
- **Config file contains credentials**: `~/.config/rclone/rclone.conf` stores API keys, tokens, and passwords in plain text. Protect it: `chmod 600 ~/.config/rclone/rclone.conf`. Never commit it to version control.
- **Server-side copy only works within same provider**: Copying between two S3 buckets in the same account uses server-side copy (free, fast). Copying from S3 to B2 downloads then uploads — counts against bandwidth on both sides.
- **`rclone mount` requires FUSE**: The `fuse3` (or `fuse`) package must be installed. Non-root users also need `user_allow_other` in `/etc/fuse.conf` to use `--allow-other`.
- **Crypt remote wraps another remote**: A `crypt` remote is a transparent encryption layer over an existing remote. Files are stored encrypted in the underlying remote; rclone handles AES-256-CTR encryption and decryption on the fly. Losing the crypt password means permanent data loss.

## See Also

- **rsync** — File-level synchronization for local and SSH-based backup
- **borg** — Deduplicated encrypted backup with borgmatic automation wrapper
- **restic** — Content-addressed deduplicating backup with S3/B2/SFTP backends

## References

See `references/` for:
- `cheatsheet.md` — task-organized command examples for common workflows
- `docs.md` — official documentation and backend-specific links
