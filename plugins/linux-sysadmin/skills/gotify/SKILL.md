---
name: gotify
description: >
  Gotify self-hosted push notification server: Docker deployment,
  application/client tokens, REST API for sending messages, priority levels,
  plugins, WebSocket subscriptions, and Android app integration.
  MUST consult when installing, configuring, or troubleshooting gotify.
triggerPhrases:
  - "gotify"
  - "gotify notification"
  - "gotify push"
  - "gotify server"
  - "gotify message"
  - "gotify token"
  - "self-hosted notifications"
  - "push notification server"
  - "gotify api"
globs:
  - "**/gotify/**"
last_verified: "2026-03"
---

## Identity
- **Docker image**: `gotify/server` (current stable: v2.9.1)
- **Binary**: single Go binary, downloadable from GitHub releases
- **Config**: environment variables or `config.yml` in the data directory
- **Data dir**: `/app/data` (inside Docker) or `./data` (binary)
- **Database**: SQLite by default (`/app/data/gotify.db`); MySQL and PostgreSQL also supported
- **Logs**: stdout (Docker: `docker logs gotify`)
- **User**: runs as the container user (no dedicated system user)
- **Distro install**: Docker (recommended) or download binary from https://github.com/gotify/server/releases

## Quick Start

```bash
# Docker (simplest)
docker run -d --name gotify \
  -p 8080:80 \
  -v gotify-data:/app/data \
  -e GOTIFY_DEFAULTUSER_NAME=admin \
  -e GOTIFY_DEFAULTUSER_PASS=changeme \
  gotify/server

# Open WebUI
# http://localhost:8080

# Create an application via WebUI, get the app token, then:
curl "http://localhost:8080/message?token=<apptoken>" \
  -F "title=Hello" -F "message=Test notification" -F "priority=5"
```

## Key Operations

| Task | Command |
|------|---------|
| Send a message | `curl "http://localhost:8080/message?token=<apptoken>" -F "title=Alert" -F "message=Server is down" -F "priority=8"` |
| Send JSON message | `curl -X POST "http://localhost:8080/message" -H "X-Gotify-Key: <apptoken>" -H "Content-Type: application/json" -d '{"title":"Alert","message":"Disk full","priority":8}'` |
| List applications | `curl -u admin:password "http://localhost:8080/application"` |
| Create application | `curl -u admin:password -X POST "http://localhost:8080/application" -H "Content-Type: application/json" -d '{"name":"monitoring","description":"Server alerts"}'` |
| List messages | `curl -u admin:password "http://localhost:8080/message"` |
| Delete all messages | `curl -u admin:password -X DELETE "http://localhost:8080/message"` |
| Delete messages for app | `curl -u admin:password -X DELETE "http://localhost:8080/application/<appid>/message"` |
| List clients | `curl -u admin:password "http://localhost:8080/client"` |
| Create client | `curl -u admin:password -X POST "http://localhost:8080/client" -H "Content-Type: application/json" -d '{"name":"my-phone"}'` |
| Check health | `curl -s "http://localhost:8080/health"` |
| Check version | `curl -s "http://localhost:8080/version"` |
| WebSocket stream | `wscat -c "ws://localhost:8080/stream?token=<clienttoken>"` |
| Container logs | `docker logs gotify` |
| Restart | `docker restart gotify` |

## Expected Ports
- `80/tcp` — HTTP (default inside container)
- `443/tcp` — HTTPS (if SSL enabled)
- Typical host mapping: `8080:80`
- Verify: `ss -tlnp | grep gotify` or `docker port gotify`
- Firewall: `sudo ufw allow 8080/tcp` (or your chosen host port)

## Health Checks

1. `curl -sf http://localhost:8080/health` — returns `"green"` when healthy
2. `curl -sf http://localhost:8080/version` — returns version JSON
3. `docker logs gotify 2>&1 | tail -20` — no errors in recent output

## Priority Levels

Gotify uses numeric priority values (0-10) that affect Android notification behavior.

| Priority | Android Behavior |
|----------|-----------------|
| 0 | Appears in feed only; no push notification alert |
| 1-3 | Notification with sound |
| 4-7 | Notification with sound and vibration |
| 8-10 | Maximum intrusiveness; all notification features |

Default priority is 0 if not specified. The WebUI always shows all messages regardless of priority.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Connection refused` on port 8080 | Container not running or wrong port mapping | `docker ps` to verify; check `-p 8080:80` mapping |
| `Unauthorized` when sending message | Wrong or missing token | Verify token in WebUI under Applications; use `?token=` param or `X-Gotify-Key` header |
| Messages not appearing on phone | Android app not connected or wrong client token | Check WebSocket connection in Android app settings; verify client token |
| `UNIQUE constraint failed` on startup | Database migration issue | Back up `gotify.db`, delete it, restart (loses all data); or check GitHub issues |
| No push on Android | Battery optimization killing background process | Disable battery optimization for Gotify in Android settings; the app uses a persistent WebSocket, not FCM |
| SSL certificate errors | Self-signed cert or wrong config | Set `GOTIFY_SERVER_SSL_ENABLED=true` and provide cert/key paths; or put behind a reverse proxy |
| Crash at startup with MySQL | MySQL-specific bug (fixed in v2.9.1) | Update to v2.9.1+; check `GOTIFY_DATABASE_DIALECT` and `GOTIFY_DATABASE_CONNECTION` |
| High memory with many messages | SQLite not vacuumed | Delete old messages via API; or switch to PostgreSQL for large deployments |

## Pain Points

- **No Google FCM/APNs**: Gotify uses a persistent WebSocket connection from the Android app to receive messages. This means the app must maintain a background connection, which some Android OEMs aggressively kill. There is no iOS app because Apple requires APNs for push notifications; a community bridge project (iGotify) exists but requires additional setup.

- **Application tokens vs client tokens**: Applications push messages TO Gotify (use app token with `/message`). Clients receive messages FROM Gotify (use client token with `/stream` WebSocket). Confusing the two is the most common auth error.

- **No built-in authentication proxy**: Gotify uses basic auth or tokens. If exposed to the internet, put it behind a reverse proxy (nginx, Traefik, Caddy) with HTTPS. The admin credentials are set via environment variables on first run and stored in the database after that.

- **Default admin credentials**: The `GOTIFY_DEFAULTUSER_NAME` and `GOTIFY_DEFAULTUSER_PASS` environment variables only take effect on first startup when the database is empty. Changing them after that requires using the WebUI or API.

- **Plugin system is server-side Go plugins**: Gotify supports plugins compiled as Go shared objects (`.so` files). They must be compiled against the same Go version and Gotify version as the server. This makes distribution difficult; most users never need plugins.

- **SQLite limitations at scale**: SQLite is fine for personal use (hundreds of messages). For high-volume scenarios or multi-user deployments, switch to PostgreSQL or MySQL via `GOTIFY_DATABASE_DIALECT`.

## See Also
- **mosquitto** — MQTT broker for IoT pub/sub messaging; different protocol and use case than HTTP push
- **node-red** — flow-based automation that can send Gotify notifications via HTTP request nodes
- **vaultwarden** — another self-hosted service commonly deployed alongside Gotify in homelab stacks

## References
See `references/` for:
- `docs.md` — official documentation links (installation, API, plugins, Android app)
- `common-patterns.md` — Docker Compose setup, sending messages from scripts, monitoring integration, reverse proxy config
