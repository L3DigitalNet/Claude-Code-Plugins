---
name: gitea
description: >
  Gitea and Forgejo self-hosted git service administration: installation,
  configuration, admin CLI, user and repository management, SSH setup,
  backup/restore, reverse proxy, LFS, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting gitea.
triggerPhrases:
  - "gitea"
  - "forgejo"
  - "Gitea"
  - "Forgejo"
  - "self-hosted git"
  - "gitea docker"
  - "self-hosted github"
  - "app.ini"
  - "gitea admin"
  - "gitea dump"
  - "gitea migrate"
globs:
  - "**/app.ini"
  - "**/gitea/conf/app.ini"
  - "**/gitea/**/*.ini"
last_verified: "unverified"
---

## Identity

- **Deployment**: single binary (native) or Docker image (`gitea/gitea`, `codeberg.org/forgejo/forgejo`)
- **Unit**: `gitea.service` (native) — no systemd unit in Docker deployments
- **Config**: `/etc/gitea/app.ini` (native) or `/data/gitea/conf/app.ini` (Docker volume)
- **Data dir**: `/var/lib/gitea` (native) or `/data` (Docker volume)
- **Logs**: `journalctl -u gitea`, or `/var/lib/gitea/log/` / `/data/gitea/log/`
- **Git user**: `git` (native install) — all SSH operations run as this user
- **Ports**: 3000 (HTTP web UI), 22 or 2222 (SSH git operations)
- **Forgejo**: community fork of Gitea with identical `app.ini` format and CLI — all commands below work on both. Replace `gitea` binary with `forgejo` where applicable.

## Quick Start

```bash
# Docker (recommended)
docker compose pull
docker compose up -d
curl -s http://localhost:3000/api/healthz
# Bare-metal
wget -O gitea https://dl.gitea.com/gitea/latest/gitea-linux-amd64
chmod +x gitea && sudo mv gitea /usr/local/bin/
sudo systemctl enable --now gitea
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status gitea` |
| Start / stop / restart | `systemctl start\|stop\|restart gitea` |
| Reload config (no restart) | `systemctl reload gitea` — note: most `[server]` changes require a full restart |
| Admin CLI help | `gitea admin --help` (or `forgejo admin --help`) |
| Create first admin user | `gitea admin user create --username admin --password-from-env --email admin@example.com --admin` |
| Reset a user credential | `gitea admin user change-password --username <user> --password-from-env` |
| Regenerate git hooks | `gitea admin regenerate hooks` — fixes broken push/post-receive hooks after upgrade |
| Regenerate SSH keys | `gitea admin regenerate keys` — rebuilds `~git/.ssh/authorized_keys` |
| List all users | `gitea admin user list` |
| Create a repository | `gitea admin repo create --owner <user> --name <repo>` |
| Migrate remote repo | `gitea admin repo migrate --url https://github.com/owner/repo --owner <localuser> --name <repo>` |
| Backup (full dump) | `gitea dump -c /etc/gitea/app.ini -t /tmp` — produces a `.zip` with repos, DB, config, attachments |
| Restore from dump | Extract zip, then `gitea restore --config /etc/gitea/app.ini` with the extracted path |
| Run DB migrations | `gitea migrate` — required before starting a newer binary on an older database |
| Show effective config | `gitea dump-config -c /etc/gitea/app.ini` — prints merged config with defaults resolved |
| Check app.ini syntax | `gitea dump-config` exits non-zero on parse errors; also try `gitea web --dry-run` if available |
| List OAuth2 applications | `gitea admin auth list` — shows all external auth sources including OAuth2 apps |
| Delete auth source | `gitea admin auth delete --id <id>` |

## Expected Ports

- **3000/tcp**: HTTP web UI (or custom `HTTP_PORT` in `[server]`)
- **22/tcp**: SSH git (native, using system SSH and `authorized_keys` passthrough)
- **2222/tcp**: SSH git (Docker, mapped from internal 22 to avoid host port conflict)
- Verify: `ss -tlnp | grep -E '3000|2222|:22'`
- Firewall: `sudo ufw allow 3000/tcp && sudo ufw allow 2222/tcp`

## Health Checks

1. `systemctl is-active gitea` → `active` (native installs only)
2. `curl -sI http://localhost:3000` → HTTP 200 or 302 (not connection refused)
3. `curl -s http://localhost:3000/api/healthz` → `{"status":"pass"}` (Gitea 1.16+)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "There is no user with that email" on first web setup | No admin user exists yet | Run `gitea admin user create --admin` from the CLI before opening the web installer |
| SSH key accepted but `git clone` returns "Permission denied" | `authorized_keys` not rebuilt after install or upgrade | Run `gitea admin regenerate keys`; check `~git/.ssh/authorized_keys` contains entries |
| SSH works locally but not through reverse proxy | SSH passthrough not configured — proxy only forwards HTTP | Use a dedicated TCP proxy for port 22/2222, or configure `SSH_DOMAIN` and map Docker port directly |
| LFS pushes succeed but objects return 404 on fetch | LFS server not enabled or storage misconfigured | Set `LFS_START_SERVER = true` in `[server]`; confirm `LFS_CONTENT_PATH` is writable |
| HTTPS OAuth / webhook callbacks fail | `ROOT_URL` does not match actual public URL | Set `ROOT_URL = https://git.example.com/` exactly — trailing slash required; mismatch breaks redirects and HMAC signatures |
| Database migration fails on upgrade | Newer binary run before `gitea migrate` | Stop service, run `gitea migrate -c /etc/gitea/app.ini`, then start new binary |
| Email notifications not sent | SMTP unconfigured or `ENABLED = false` in `[mailer]` | Set `ENABLED = true`, correct `SMTP_ADDR`, `FROM`, `USER`, `PASSWD`; test with `gitea admin sendmail` |
| Webhook deliveries show "connection refused" | Webhook target is localhost and `ALLOW_LOCAL_NETWORKS` is false | Set `ALLOW_LOCAL_NETWORKS = true` in `[webhook]` for internal targets, or use the real external URL |

## Pain Points

- **`ROOT_URL` must be exact**: include protocol, domain, port (if non-standard), and a trailing slash. OAuth2 redirect URIs, webhook HMAC signing, and avatar URLs are all derived from this value. A mismatch causes silent partial failures.
- **SSH passthrough via `authorized_keys`**: native installs use the `git` system user; every registered SSH key is written to `~git/.ssh/authorized_keys` with a `command=` wrapper pointing at the Gitea binary. Docker deployments avoid this complexity by exposing port 2222 directly — no host `git` user needed.
- **`gitea migrate` before binary upgrade**: Gitea does not auto-migrate on startup. Running a newer binary against an unmigrated database produces confusing errors. Always stop, migrate, then start.
- **LFS requires separate storage config**: Git LFS is not enabled by default. It requires `LFS_START_SERVER = true` and a configured `LFS_CONTENT_PATH` (or S3/Minio object storage for larger deployments).
- **Forgejo is a drop-in replacement**: all `app.ini` keys, Docker image layout, and CLI commands are identical. Replace `gitea` binary/image with `forgejo` equivalent; no config changes required. Forgejo may diverge in future versions — check its changelog before assuming parity.
- **Docker volume layout differs from native**: inside the container `/data/gitea/conf/app.ini` is the config, `/data/git/repositories` holds repos. Mount `/data` as a single volume or map subdirectories individually — mixing strategies causes permission issues.
- **`INSTALL_LOCK = true` must be set before first start in automated deployments**: without it, any unauthenticated visitor who reaches the install page can become the first admin. Set it in `app.ini` before exposing the port.

## See Also

- **nextcloud** — self-hosted file storage and collaboration platform that complements a Gitea code hosting setup

## References

See `references/` for:
- `app.ini.annotated` — full app.ini with every directive explained
- `docs.md` — official documentation links
