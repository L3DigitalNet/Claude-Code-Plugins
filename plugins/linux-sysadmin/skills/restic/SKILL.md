---
name: restic
description: >
  restic backup administration: repository initialization, backup creation,
  snapshot management, restore, forget/prune retention policies, integrity
  checks, and FUSE mount browsing. Supports local, SFTP, S3, Backblaze B2,
  and REST server backends.
  MUST consult when installing, configuring, or troubleshooting restic.
triggerPhrases:
  - "restic"
  - "restic backup"
  - "restic restore"
  - "restic forget"
  - "restic prune"
  - "restic snapshots"
  - "restic init"
  - "restic check"
  - "restic mount"
  - "RESTIC_REPOSITORY"
  - "RESTIC_PASSWORD"
  - "deduplicating backup"
  - "encrypted backup"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `restic` |
| **Unit** | No daemon — run via cron or systemd timer |
| **Config** | No fixed path — driven by env vars or CLI flags |
| **Backends** | local, SFTP, S3/MinIO/Wasabi, Backblaze B2, REST server, Azure Blob, GCS |
| **Type** | CLI backup tool (content-addressed deduplication + AES-256 encryption) |
| **Install** | `apt install restic` / `dnf install restic` / `brew install restic` / binary from GitHub releases |
| **Self-update** | `restic self-update` (updates the binary in-place) |

## Quick Start

```bash
sudo apt install restic
restic -r /path/to/repo init
restic -r /path/to/repo backup /home /etc
restic -r /path/to/repo snapshots
restic -r /path/to/repo check
```

## Key Operations

| Task | Command |
|------|---------|
| Initialize repo (local) | `restic -r /path/to/repo init` |
| Backup path | `restic -r /path/to/repo backup /home /etc` |
| Backup with excludes | `restic -r /repo backup /home --exclude-caches --exclude '*.pyc'` |
| List snapshots | `restic -r /repo snapshots` |
| Filter snapshots by host | `restic -r /repo snapshots --host myhostname` |
| Restore latest | `restic -r /repo restore latest --target /tmp/restore` |
| Restore single path from snapshot | `restic -r /repo restore abc1234 --include /home/user/file.txt --target /tmp/` |
| Forget (apply retention policy) | `restic -r /repo forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6` |
| Forget AND prune in one command | `restic -r /repo forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6` |
| Prune (free disk space) | `restic -r /repo prune` |
| Check metadata integrity | `restic -r /repo check` |
| Check + verify all data chunks | `restic -r /repo check --read-data` |
| FUSE mount repo | `restic -r /repo mount /mnt/restic` |
| Stats | `restic -r /repo stats` |
| Diff two snapshots | `restic -r /repo diff abc1234 def5678` |
| Unlock stuck repo | `restic -r /repo unlock` |
| Repair after interrupted prune | `restic -r /repo repair packs && restic -r /repo prune` |
| List repo keys | `restic -r /repo key list` |
| Add new key | `restic -r /repo key add` |
| Update binary | `restic self-update` |

## Expected State

- `restic -r /repo check` exits 0 with no errors printed
- `restic -r /repo snapshots` lists recent snapshots covering expected paths and hosts
- Retention policy applied on a schedule (cron or systemd timer) with `forget --prune` or `forget` followed by `prune`
- Repository password and path stored securely and separately from the machine being backed up

## Health Checks

1. `restic -r /repo snapshots 2>&1 | tail -5` — lists recent snapshots; confirms repo is accessible and password is correct
2. `restic -r /repo check 2>&1` — verifies repository structure and metadata; exits 0 on success
3. `restic -r /repo stats 2>&1 | grep -E 'Total|Snapshots'` — shows dedup stats and snapshot count without a full data read

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Fatal: wrong password or no key found` | Incorrect password or wrong repo path | Verify `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` / `RESTIC_PASSWORD_FILE` env vars |
| `Fatal: unable to open config file: ...is already locked` | Previous backup crashed while holding repo lock | Verify no backup is running: `pgrep restic`; then `restic -r /repo unlock` |
| `FUSE mount fails: fusermount: exec: "fusermount": executable file not found` | `fuse` package not installed | `apt install fuse` / `dnf install fuse`; user needs to be in the `fuse` group or run as root |
| S3: `error: 403 Forbidden` | Wrong credentials or missing bucket permissions | Check `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`; verify bucket policy grants `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` |
| `repository has unfinished operations` | `prune` was interrupted, leaving partial pack files | `restic -r /repo repair packs` then re-run `prune` |
| Backup runs but `df` shows no disk change after `forget` | `forget` only removes snapshot metadata, not data | Run `restic prune` after `forget`, or use `forget --prune` |
| `Fatal: snapshot ID does not exist` | Short snapshot ID collision or stale ID in a script | Use full 64-char IDs or `latest` keyword; get current IDs with `restic snapshots` |

## Pain Points

- **`forget` and `prune` are separate commands** — `restic forget --keep-daily 7` marks old snapshots for deletion and removes them from the snapshot list, but does NOT free disk space. The underlying data blobs are still on disk until you run `restic prune`. To do both in one step, use `restic forget --prune --keep-*`. Many users run `forget` expecting disk usage to drop immediately, then wonder why nothing changed.

- **No recovery without the password** — Restic repositories are encrypted with AES-256 using a key derived from the password. There is no recovery path if the password is lost. Store it in a password manager (vaultwarden, keepass) alongside the repository URL, and test that you can list snapshots from a clean machine before an emergency occurs.

- **`check` vs `check --read-data`** — `restic check` verifies the repository structure and snapshot metadata quickly (seconds to minutes). `restic check --read-data` downloads and verifies every data chunk against its stored hash — this is slow (hours for large repos) but the only way to verify the actual backup data hasn't been corrupted or partially deleted. Run `--read-data` on a weekly or monthly schedule, not after every backup.

- **Exclude caches and temp dirs explicitly** — Without exclusions, restic backs up `~/.cache`, `/tmp`, browser cache directories, `node_modules`, `.venv`, `.tox`, and similar volatile trees. Use `--exclude-caches` (respects `CACHEDIR.TAG` files that tools like pip and npm write automatically) plus explicit `--exclude` patterns for the rest. A backup that includes gigabytes of caches wastes space and slows both backup and prune.

- **Lock file deadlock with parallel runs** — Two simultaneous `restic backup` commands against the same repository will deadlock on the lock file — the second run will fail immediately with a "repository is already locked" error. For cron/systemd automation, use `Conflicts=` in the systemd service or a script-level lock guard (`flock`) to prevent overlapping runs.

- **Snapshot IDs are not stable across forget/prune cycles** — Short IDs (8 hex chars) are computed from the full 64-char SHA-256 prefix and can collide as the repository grows. Scripts should use either the full 64-char ID or the `latest` keyword. Always retrieve current IDs with `restic snapshots` rather than storing them long-term.

## See Also

- **borg** — Deduplicated encrypted backup with borgmatic automation wrapper
- **rsync** — File-level synchronization for simple backup and mirroring
- **rclone** — Cloud storage sync and mount supporting 70+ providers

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns with copy-paste commands
- `common-patterns.md` — backend setup, systemd timer automation, rest-server, retention policies
- `docs.md` — official documentation links
