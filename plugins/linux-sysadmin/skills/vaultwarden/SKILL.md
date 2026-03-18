---
name: vaultwarden
description: >
  Vaultwarden self-hosted credential manager administration: Docker deployment,
  environment variable configuration, reverse proxy setup, admin panel, user
  management, backup and restore, email/SMTP, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting vaultwarden.
triggerPhrases:
  - "vaultwarden"
  - "Vaultwarden"
  - "bitwarden"
  - "self-hosted password manager"
  - "vaultwarden docker"
  - "password manager self-hosted"
  - "vaultwarden admin"
  - "vaultwarden backup"
  - "vaultwarden SMTP"
  - "vaultwarden nginx"
globs: []
last_verified: "unverified"
---

## Identity

- **Image**: `vaultwarden/server` (Docker Hub)
- **Config**: Environment variables passed to the container (no separate config file)
- **Data dir**: `/data` inside container (mount a host volume here)
- **Database**: SQLite at `/data/db.sqlite3` by default; PostgreSQL or MySQL optional
- **Port**: 80/tcp (HTTP inside container — always put HTTPS termination in front)
- **Admin panel**: `/admin` path (disabled by default; requires `ADMIN_TOKEN` env var)
- **Websocket port**: 3012/tcp (live sync; must be proxied alongside port 80)

## Quick Start

```bash
docker pull vaultwarden/server
docker run -d --name vaultwarden -v /opt/vaultwarden/data:/data -p 8080:80 vaultwarden/server
# Generate an argon2 admin token
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
# Set ADMIN_TOKEN env var and recreate to enable admin panel
curl -sf http://localhost:8080/alive
```

## Key Operations

| Task | Command |
|------|---------|
| Check container status | `docker ps \| grep vaultwarden` |
| View live logs | `docker logs -f vaultwarden` |
| View last 100 log lines | `docker logs --tail 100 vaultwarden` |
| Restart container | `docker restart vaultwarden` |
| Stop / start | `docker stop vaultwarden` / `docker start vaultwarden` |
| Inspect environment variables | `docker inspect vaultwarden \| python3 -m json.tool \| grep -A1 Env` |
| Backup data directory | `tar czf vaultwarden-backup-$(date +%Y%m%d).tar.gz -C /opt/vaultwarden data/` |
| Restore from backup | `docker stop vaultwarden && tar xzf vaultwarden-backup-<date>.tar.gz -C /opt/vaultwarden && docker start vaultwarden` |
| Enable admin panel | Set `ADMIN_TOKEN` env var and recreate container |
| Generate admin token (argon2) | `docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp` |
| List users (admin API) | `curl -s -H "Authorization: Bearer <token>" https://vault.example.com/admin/users` |
| Force sync all clients | Admin panel → Users → click user → Deauthorize Sessions |
| Update container image | `docker pull vaultwarden/server && docker compose up -d` |
| Disable new signups | Set `SIGNUPS_ALLOWED=false` and recreate container |
| Check email config | Send test email via admin panel → Diagnostics → SMTP → Send test email |
| SQLite integrity check | `docker exec vaultwarden sqlite3 /data/db.sqlite3 'PRAGMA integrity_check;'` |

## Expected Ports

- **80/tcp** — HTTP inside the container (never expose this directly; terminate TLS upstream)
- **3012/tcp** — WebSocket for live sync (must be proxied; clients will poll without it but sync is delayed)
- Bitwarden/Vaultwarden clients **refuse plaintext HTTP** — HTTPS with a valid cert is required
- Verify container is listening: `docker port vaultwarden`

## Health Checks

1. `docker inspect --format='{{.State.Status}}' vaultwarden` → `running`
2. `curl -sf https://vault.example.com/alive` → HTTP 200 (Vaultwarden health endpoint)
3. `curl -sf https://vault.example.com/api/config` → JSON response with `version` field

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Clients show "Invalid server URL" or refuse to connect | HTTP instead of HTTPS — clients enforce TLS | Set up a reverse proxy with a valid cert; `DOMAIN` env var must be the HTTPS URL |
| Admin panel returns 404 | `ADMIN_TOKEN` not set or container not recreated after adding it | Set `ADMIN_TOKEN`, then `docker compose up -d` to recreate (not restart) |
| Email invites / 2FA emails not delivered | SMTP not configured or wrong credentials | Check `SMTP_*` env vars; use admin panel Diagnostics → Send test email |
| Attachment uploads fail or are missing | `/data` volume not mounted or wrong path | Verify volume mount in compose file; check `DATA_FOLDER` env var matches mount |
| "Database is locked" in logs | Concurrent SQLite writes (e.g., multiple containers or backup tool hitting DB live) | Stop container before backup; or migrate to PostgreSQL for multi-user deployments |
| Mobile push notifications not working | `PUSH_ENABLED` not set or Bitwarden relay account not configured | Register at `https://bitwarden.com/host/`; add `PUSH_INSTALLATION_ID` and `PUSH_INSTALLATION_KEY` |
| WebSocket errors in browser console | Port 3012 not proxied or WebSocket upgrade headers missing | Add WebSocket proxy block to nginx/Caddy config; confirm port 3012 forwarded |

## Pain Points

- **HTTPS is mandatory**: Bitwarden-compatible clients enforce HTTPS at the protocol level. A self-signed certificate will cause connection failures unless the cert is manually trusted on every device. Use Let's Encrypt via Caddy or Certbot.
- **Admin panel is off by default**: The `/admin` endpoint only activates when `ADMIN_TOKEN` is set. Use the argon2 hash form (`vaultwarden hash`) rather than a plaintext token — plaintext works but logs a warning every startup.
- **Container must be recreated (not restarted) after env var changes**: `docker restart` does not re-read environment variables. Changes to the compose file require `docker compose up -d` to recreate the container.
- **SQLite is sufficient for personal or small-team use**: The single-writer limitation rarely matters at low concurrency, but if you see "database is locked" under normal use, migrate to PostgreSQL via `DATABASE_URL`.
- **Regular `/data` backups are non-negotiable**: The entire Vaultwarden state (vault DB, attachments, config, RSA keys) lives in `/data`. A missing or stale backup means unrecoverable vault loss. Automate backups with a cron job or a sidecar container.
- **Disable signups after initial user creation**: `SIGNUPS_ALLOWED=true` (the default) lets anyone register. Set `SIGNUPS_ALLOWED=false` immediately after creating your accounts, or use `SIGNUPS_DOMAINS_WHITELIST` to restrict by email domain.
- **`DOMAIN` must match the actual HTTPS URL**: Vaultwarden uses this for generating invitation links, TOTP URIs, and push notification callbacks. A mismatch causes broken invite emails and client errors even when login works.

## See Also

- **nextcloud** — self-hosted cloud storage and collaboration, often deployed alongside Vaultwarden for a complete self-hosted stack

## References

See `references/` for:
- `docker-compose.yml.annotated` — complete compose file with every environment variable explained
- `docs.md` — official documentation and community links
