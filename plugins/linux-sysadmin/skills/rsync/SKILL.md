---
name: rsync
description: >
  rsync file synchronization and backup: local and remote sync, incremental
  backups with --link-dest, exclude patterns, daemon mode, and troubleshooting.
  Triggers on: rsync, rsync backup, rsync remote, rsync SSH, rsync exclude,
  incremental backup rsync, rsync daemon, rsyncd.conf, rsync --delete,
  rsync --link-dest, rsync dry run.
globs:
  - "**/rsyncd.conf"
  - "**/rsyncd.secrets"
---

## Identity

- **Binary**: `rsync`
- **Daemon mode**: `rsync --daemon` (optional; most uses are one-shot CLI invocations)
- **Daemon config**: `/etc/rsyncd.conf`, `/etc/rsyncd.secrets`
- **Daemon logs**: `journalctl -u rsync` (if using systemd unit), or `syslog` / `--log-file`
- **Distro install**: `apt install rsync` / `dnf install rsync`

## Key Operations

| Task | Command |
|------|---------|
| Basic local sync | `rsync -av /src/ /dst/` |
| Dry run first (always before --delete) | `rsync -av --dry-run /src/ /dst/` |
| Short dry-run flag | `rsync -avn /src/ /dst/` |
| Remote push over SSH | `rsync -av -e ssh /src/ user@host:/dst/` |
| Remote pull over SSH | `rsync -av -e ssh user@host:/src/ /dst/` |
| Remote push via rsync daemon | `rsync -av /src/ rsync://host/modulename/` |
| Archive mode (preserve perms, times, symlinks, owner, group) | `rsync -a /src/ /dst/` |
| Archive + human-readable progress | `rsync -ah --progress /src/ /dst/` |
| Show itemized changes (what changed and why) | `rsync -av --itemize-changes /src/ /dst/` |
| Delete files at destination not in source | `rsync -av --delete /src/ /dst/` |
| Limit bandwidth (e.g., 5 MB/s) | `rsync -av --bwlimit=5000 /src/ /dst/` |
| Exclude a pattern | `rsync -av --exclude='*.log' /src/ /dst/` |
| Exclude multiple patterns | `rsync -av --exclude='*.log' --exclude='.cache/' /src/ /dst/` |
| Load excludes from a file | `rsync -av --exclude-from=/path/to/excludes.txt /src/ /dst/` |
| Resume partial file transfers | `rsync -av --partial /src/ /dst/` |
| Hardlink-based incremental backup (Time Machine style) | `rsync -a --link-dest=/backups/prev/ /src/ /backups/$(date +%F)/` |
| Checksum mode (byte-for-byte comparison, slow) | `rsync -avc /src/ /dst/` |
| Preserve ACLs and extended attributes | `rsync -aAX /src/ /dst/` |
| Show transfer stats summary | `rsync -av --stats /src/ /dst/` |
| SSH with non-default port | `rsync -av -e 'ssh -p 2222' /src/ user@host:/dst/` |
| Compress data in transit | `rsync -avz /src/ user@host:/dst/` |

## Expected State

rsync is a one-shot command in most uses — there is no persistent process to check. For daemon mode:

- **Service** (if using systemd): `systemctl is-active rsync`
- **Default port**: 873/tcp
- **Verify listening**: `ss -tlnp | grep ':873'`

## Health Checks

1. Dry run shows expected changes: `rsync -avn /src/ /dst/` — review output before committing
2. Check exit code: `echo $?` → `0` = success, `23` = partial transfer (some files skipped), `24` = partial transfer (source files vanished mid-run), anything else = error

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| Remote files deleted unexpectedly | `--delete` ran without a prior dry-run | Always run `rsync -avn --delete /src/ /dst/` first; restore from backup |
| SSH prompts for password in a cron job | No SSH key auth configured | Set up key-based auth: `ssh-keygen` + `ssh-copy-id user@host`; test with `ssh -i /path/key user@host` |
| "No space left on device" at destination | Destination disk full | `df -h /dst/`; free space or reduce scope |
| "Permission denied" on remote | SSH user lacks write permission on destination | Check ownership: `ls -la /dst/`; adjust or run as correct user |
| "failed to set permissions" on files | Local user differs from file owner at destination | Use `--no-perms --no-owner --no-group` if permission preservation isn't needed |
| Exit code 23 (partial transfer) | Some files could not be transferred (permissions, locks) | Review stderr; not always fatal — treat as warning if expected files transferred |
| Exit code 24 (vanished source files) | Files deleted from source during the sync | Treat as warning if source is live; use `--ignore-missing-args` to suppress |
| `rsync: [Receiver] write error: Broken pipe` | SSH connection dropped mid-transfer | Check network stability; add `-e 'ssh -o ServerAliveInterval=30'` |
| Destination has extra files after sync | Source path has no trailing slash — `dir` syncs the directory itself, not contents | Distinguish `rsync /src/` (contents) from `rsync /src` (directory) |

## Pain Points

- **Trailing slash on source is everything**: `rsync /src/` syncs the contents of `src` into the destination. `rsync /src` syncs the directory `src` itself, creating `/dst/src/`. This is the single most common rsync mistake.
- **Always dry-run before `--delete`**: `--delete` removes files at the destination that are absent from the source. A wrong source path with `--delete` can silently wipe the destination. `rsync -avn --delete` costs nothing.
- **Exit codes 23 and 24 are warnings, not fatal errors**: Scripts that `set -e` will abort on these. Explicitly handle them: `rsync ... || [[ $? -le 24 ]]` or check `$?` after the call.
- **`--checksum` reads every byte**: It skips rsync's default mtime+size heuristic and does a full content comparison. Correct but much slower — only use it when you genuinely distrust file metadata.
- **`--link-dest` for Time Machine-style backups**: Each run creates a new snapshot directory; unchanged files are hardlinked from the previous snapshot, not duplicated. The result is full-backup semantics at incremental-backup storage cost.
- **rsync daemon has no encryption**: The `rsync://` protocol (port 873) is plaintext. For encrypted remote sync, use rsync over SSH (`-e ssh`), not daemon mode. If daemon mode is required, tunnel it through SSH or a VPN.
- **`-z` compression over SSH is usually wasteful**: SSH already compresses the stream if `Compression yes` is set. Double-compressing adds CPU overhead for little gain on fast links. Useful on slow WAN links where CPU is cheaper than bandwidth.

## References

See `references/` for:
- `cheatsheet.md` — task-organized command reference with flag explanations
- `docs.md` — man pages and official documentation links
