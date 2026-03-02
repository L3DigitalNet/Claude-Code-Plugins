---
name: rclone
description: >
  rclone cloud storage management: configuring remotes, copying and syncing files
  to/from cloud providers, mounting cloud storage as a filesystem, serving cloud
  storage over HTTP/WebDAV/SFTP/S3, client-side encryption with crypt remotes,
  bandwidth throttling, and integrity verification. Triggers on: rclone,
  cloud backup, rclone sync, rclone S3, rclone mount, cloud storage sync,
  Backblaze rclone, rclone remote.
globs:
  - "**/rclone.conf"
  - "**/.config/rclone/rclone.conf"
---

## Identity

- **Binary**: `rclone`
- **Config**: `~/.config/rclone/rclone.conf` (or `$RCLONE_CONFIG`)
- **Logs**: `--log-file=/path/to/rclone.log`, `--log-level DEBUG|INFO|NOTICE|ERROR`
- **Distro install**: `apt install rclone` / `dnf install rclone` / `curl https://rclone.org/install.sh | sudo bash`
- **Backends (70+)**: S3-compatible (AWS S3, MinIO, Wasabi, Cloudflare R2), Google Cloud Storage, Azure Blob, Backblaze B2, Dropbox, Google Drive, OneDrive, SFTP, WebDAV, FTP, local filesystem, HTTP, Mega, Box, pCloud, Jottacloud, Yandex Disk, and more

## Key Operations

| Operation | Command | Notes |
|-----------|---------|-------|
| Configure new remote | `rclone config` | Interactive wizard |
| List configured remotes | `rclone listremotes` | Names only |
| List top-level directories | `rclone lsd remote:bucket` | Dirs only, non-recursive |
| List files (simple) | `rclone lsf remote:path` | One entry per line |
| List files (detailed) | `rclone ls remote:path` | Size + path |
| List files (JSON) | `rclone lsjson remote:path` | Machine-readable |
| Copy (no delete) | `rclone copy src: dst:` | Skips identical files; never deletes destination |
| Sync (mirror) | `rclone sync src: dst:` | Deletes destination files not in source |
| Move | `rclone move src: dst:` | Copy then delete from source |
| Check/verify | `rclone check src: dst:` | Compares checksums or size+modtime |
| Mount as filesystem | `rclone mount remote:path /mnt/point` | Requires FUSE (`fuse3` package) |
| Serve over HTTP | `rclone serve http remote:path --addr :8080` | Read-only by default |
| Serve over WebDAV | `rclone serve webdav remote:path --addr :8080` | WebDAV-compatible clients |
| Serve over SFTP | `rclone serve sftp remote:path --addr :2022` | Standard SFTP clients |
| Serve as S3 | `rclone serve s3 remote:path --addr :9000` | S3-compatible API |
| Bisync (two-way) | `rclone bisync src: dst:` | Experimental; requires `--resync` on first run |
| Delete files | `rclone delete remote:path` | Deletes files matching filters; keeps directories |
| Purge directory | `rclone purge remote:path` | Deletes entire directory tree including dirs |
| Create directory | `rclone mkdir remote:path/newdir` | Creates path including parents |
| Download and print | `rclone cat remote:path/file.txt` | Streams file to stdout |
| Get size/count | `rclone size remote:path` | Total size and object count |
| Encrypt/decrypt remote | `rclone config` (type=crypt) | Wraps another remote; client-side AES-256 |
| Backend commands | `rclone backend <command> remote:` | Provider-specific operations (e.g., B2 lifecycle) |
| Reconnect OAuth | `rclone config reconnect remote:` | Refresh expired OAuth token |
| Config show | `rclone config show` | Print all remotes (includes credentials) |

## Expected State

- Config file exists at `~/.config/rclone/rclone.conf` with at least one `[remote-name]` section
- OAuth remotes have a valid `token` field (expires; refresh with `rclone config reconnect`)
- FUSE package installed if using `rclone mount`: `apt install fuse3` / `dnf install fuse3`
- Mount point directory exists and is empty before mounting

## Health Checks

1. `rclone listremotes` — lists configured remotes (empty output means no remotes configured)
2. `rclone lsd remote:` — lists top-level dirs; authentication and connectivity failure surfaces here

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
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

## References

See `references/` for:
- `cheatsheet.md` — task-organized command examples for common workflows
- `docs.md` — official documentation and backend-specific links
