---
name: borg
description: >
  Borg Backup administration: creating and managing deduplicated, encrypted
  backup repositories, archive creation and extraction, pruning schedules,
  repository integrity checks, remote SSH backups, and borgmatic wrapper
  configuration.
  MUST consult when installing, configuring, or troubleshooting borg.
triggerPhrases:
  - "borg"
  - "borgbackup"
  - "borg backup"
  - "borg repository"
  - "borg prune"
  - "deduplicated backup"
  - "encrypted backup borg"
globs: []
last_verified: "unverified"
---

## Identity

- **Binary**: `borg` (borgbackup package)
- **No daemon**: borg runs on-demand; no persistent service for local use
- **Wrapper**: `borgmatic` — YAML-driven automation layer over raw borg commands
- **Remote hosting**: Borgbase (borgbase.com), rsync.net (both offer borg-specific plans)
- **Key env vars**:
  - `BORG_REPO` — default repository path; avoids repeating it in every command
  - `BORG_PASSPHRASE` — repository encryption passphrase; set for unattended backups
  - `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes` — required to access unencrypted repos without interactive prompt
- **Install**: `apt install borgbackup` / `dnf install borgbackup` / `pip install borgbackup`

## Quick Start

```bash
sudo apt install borgbackup
borg init --encryption=repokey /path/to/repo
borg create --compression lz4 /path/to/repo::first-backup /home
borg list /path/to/repo
borg check /path/to/repo
```

## Key Operations

| Task | Command |
|------|---------|
| Initialize repo (repokey, passphrase in env) | `borg init --encryption=repokey /path/to/repo` |
| Initialize repo (keyfile, key stored locally) | `borg init --encryption=keyfile /path/to/repo` |
| Initialize unencrypted repo | `borg init --encryption=none /path/to/repo` |
| Create archive | `borg create /path/to/repo::archive-name /source/path` |
| Create with compression and progress | `borg create --compression lz4 --progress /repo::archive-name /source` |
| Create with exclusions | `borg create --exclude '/home/*/.cache' /repo::archive-name /home` |
| List all archives in repo | `borg list /path/to/repo` |
| List contents of a specific archive | `borg list /path/to/repo::archive-name` |
| Extract full archive | `borg extract /path/to/repo::archive-name` |
| Extract single file or directory | `borg extract /path/to/repo::archive-name path/to/file` |
| Mount repository as filesystem (FUSE) | `borg mount /path/to/repo /mnt/borgmount` |
| Mount single archive | `borg mount /path/to/repo::archive-name /mnt/borgmount` |
| Unmount | `borg umount /mnt/borgmount` |
| Prune old archives (keep schedule) | `borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 /repo` |
| Prune with dry run | `borg prune --dry-run --keep-daily=7 --list /repo` |
| Compact repo (free space after prune) | `borg compact /path/to/repo` |
| Check repository integrity | `borg check /path/to/repo` |
| Check with archive verification | `borg check --archives-only /path/to/repo` |
| Repository info and stats | `borg info /path/to/repo` |
| Archive info | `borg info /path/to/repo::archive-name` |
| Delete a specific archive | `borg delete /path/to/repo::archive-name` |
| Benchmark I/O performance | `borg benchmark crud /path/to/repo /source/path` |
| Transfer archives between repos | `borg transfer --from-repo /old/repo /new/repo` |
| Serve over SSH (remote access restriction) | `borg serve --restrict-to-path /backups/client` |
| Export repo key (repokey) | `borg key export /path/to/repo /safe/location/key.txt` |
| Export key as base64 (paste-safe) | `borg key export --paper /path/to/repo` |
| Import key | `borg key import /path/to/repo /safe/location/key.txt` |

## Expected State

- `borg check /repo` exits 0 with no errors printed
- Prune running on a schedule (cron or borgmatic timer) with verified archive rotation
- Repository key and passphrase stored securely and separately (not only on the backed-up machine)

## Health Checks

1. `borg list /repo 2>&1 | head -5` — lists archives; confirms repo is accessible and passphrase is correct
2. `borg check --last 1 /repo 2>&1` — verifies the most recent archive is intact (faster than full check)
3. `borg info /repo 2>&1 | grep -E 'Unique|Total'` — shows dedup stats and confirms repo is not corrupted

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Repository has been manually modified` | `.borg` internal files were edited or corrupted | Never touch files inside the repo dir; restore from a known-good copy |
| `passphrase supplied in BORG_PASSPHRASE is incorrect` | Wrong passphrase or env var not set | Verify `echo $BORG_PASSPHRASE`; passphrase cannot be recovered if lost |
| `Failed to create/acquire the lock` | Stale lock from a crashed/killed borg process | Confirm no other borg is running, then `borg break-lock /repo` |
| `Encryption method not supported` | Borg version on client is older than the repo's encryption format | Upgrade borg: `pip install --upgrade borgbackup` |
| Disk full error during backup | Backup partially written; repo may be in inconsistent state | Free space, then `borg check /repo`; compact if check passes |
| `Permission denied (publickey)` for SSH remote | SSH key not in authorized_keys or borg command restriction wrong | Check `~/.ssh/authorized_keys` on remote; verify `command=` restriction points to correct borg binary |
| Archives exist but prune not reducing count | `borg prune` keeps archives but does not free disk space | Run `borg compact /repo` after pruning; compact is always a separate step |
| `Unknown archive` when extracting | Archive name typo or wrong repo | Run `borg list /repo` to see exact names; names are case-sensitive |

## Pain Points

- **Passphrase loss = data loss**: There is no recovery path if the passphrase is lost. Store it in a password manager or secrets vault, separate from the machine being backed up.
- **Repository key must be backed up separately**: For `repokey` mode, `borg key export` embeds the key in the repo — but if the repo is lost, the key is too. For `keyfile` mode, the key lives in `~/.config/borg/keys/` and must be backed up independently. Run `borg key export --paper /repo` to get a printable base64 representation.
- **`borg break-lock` is dangerous if another borg is running**: It removes the lock unconditionally. Confirm with `ps aux | grep borg` before breaking; breaking a live lock causes repository corruption.
- **Prune and compact are separate operations**: `borg prune` marks archives for deletion but does not free disk space. `borg compact` is the second step that actually reclaims space. Easy to forget compact and then wonder why the repo is still full.
- **`borg check` is slow on large repositories**: Checking data integrity reads all chunks. Use `--last N` to verify only recent archives, or `--archives-only` to skip the segment-level check during routine runs.
- **borgmatic simplifies all of this**: A single `borgmatic.yml` replaces manual borg invocations for init, create, prune, compact, and check. Prefer borgmatic for any recurring backup job.
- **Unencrypted repo requires opt-in**: Accessing an unencrypted repo interactively prompts a warning. In scripts, set `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes` to suppress the prompt.

## See Also

- **restic** — Content-addressed deduplicating backup with S3/B2/SFTP backends
- **rsync** — File-level synchronization for simple backup and mirroring
- **rclone** — Cloud storage sync and mount supporting 70+ providers

## References

See `references/` for:
- `cheatsheet.md` — task-organized command reference covering init, backup, restore, prune, compact, check, SSH, borgmatic, and key management
- `docs.md` — official documentation and hosting service links
