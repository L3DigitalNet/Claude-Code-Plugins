---
name: traefik
description: >
  Traefik reverse proxy and load balancer: static/dynamic config, Docker label-based
  routing, entrypoints, routers, services, middlewares, ACME/Let's Encrypt, dashboard,
  and troubleshooting. Triggers on: traefik, traefik reverse proxy, traefik router,
  traefik middleware, traefik dashboard, container-native proxy, traefik labels,
  traefik entrypoint, traefik provider, traefik acme, traefik tls.
globs:
  - "traefik.yml"
  - "traefik.toml"
  - "**/traefik/**"
  - "**/traefik.yml"
  - "**/traefik.toml"
---

## Identity
- **Docker image**: `traefik:v3` (current stable; `traefik:latest` tracks major version)
- **Binary install**: `/usr/local/bin/traefik` (when running outside Docker)
- **Static config**: `/etc/traefik/traefik.yml` (or `traefik.toml`; YAML preferred)
- **Dynamic config dir**: `/etc/traefik/dynamic/` (watched by file provider)
- **Docker socket**: `/var/run/docker.sock` (mounted read-only into the Traefik container)
- **Dashboard port**: `8080/tcp` (default; disable or protect in production)
- **Logs**: Docker: `docker logs traefik`; Systemd: `journalctl -u traefik`
- **Distro install**: `apt install traefik` / download binary from https://github.com/traefik/traefik/releases

## Key Operations

| Operation | Command |
|-----------|---------|
| Check dashboard (browser) | `http://localhost:8080/dashboard/` (trailing slash required) |
| API: list routers | `curl -s http://localhost:8080/api/http/routers \| jq '.[].name'` |
| API: list services | `curl -s http://localhost:8080/api/http/services \| jq '.[].name'` |
| API: list middlewares | `curl -s http://localhost:8080/api/http/middlewares \| jq '.[].name'` |
| API: check router detail | `curl -s http://localhost:8080/api/http/routers/<name>@docker \| jq .` |
| API: check TLS certs | `curl -s http://localhost:8080/api/tls/certificates \| jq '.[].domain'` |
| Reload config (Docker) | Traefik watches Docker socket and file provider — no manual reload needed |
| Reload config (binary) | `kill -HUP $(pidof traefik)` — reloads dynamic config only |
| Restart container | `docker restart traefik` |
| Test static config syntax | `traefik version` then `traefik --configfile /etc/traefik/traefik.yml --dry-run` (v3 supports `--dry-run` for static config validation) |
| Enable debug logging | Set `log.level: DEBUG` in static config, restart |
| Healthcheck endpoint | `curl -s http://localhost:8080/ping` → `OK` |
| View Docker provider state | `curl -s http://localhost:8080/api/providers/docker \| jq .` |
| View file provider state | `curl -s http://localhost:8080/api/providers/file \| jq .` |
| Check entrypoints | `curl -s http://localhost:8080/api/entrypoints \| jq '.[].name'` |
| View TCP routers | `curl -s http://localhost:8080/api/tcp/routers \| jq '.[].name'` |

## Expected Ports
- `80/tcp` — web entrypoint (HTTP)
- `443/tcp` — websecure entrypoint (HTTPS)
- `8080/tcp` — dashboard/API (disable or restrict in production)
- Verify: `ss -tlnp | grep traefik` or `docker port traefik`
- Firewall: `sudo ufw allow 80,443/tcp` (do NOT expose 8080 publicly without auth)

## Health Checks
1. `curl -sf http://localhost:8080/ping` → `OK`
2. `curl -sI http://localhost` → HTTP response, not `Connection refused`
3. `curl -s http://localhost:8080/api/http/routers | jq 'length'` → count > 0
4. `docker logs traefik 2>&1 | grep -i error | tail -20` → no unexpected errors

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `404 page not found` | No router rule matches the request | Check `Host` label on the container; verify `rule` syntax in router; confirm entrypoint is listed |
| Dashboard shows router but 404 in browser | Router has no service, or service has no healthy backend | Check service definition; container must be running |
| `Gateway Timeout` / no response | Container not reachable on its port | Verify container is on the same Docker network as Traefik; check `traefik.http.services.<n>.loadbalancer.server.port` label |
| `Entrypoint not defined` | Router references entrypoint not in static config | Entrypoints are static — add to `traefik.yml` and restart |
| Docker socket permission denied | Traefik container can't read the socket | Mount `/var/run/docker.sock:/var/run/docker.sock:ro`; check socket group; or run as root in container |
| ACME: `too many certificates already issued` | Hit Let's Encrypt rate limit | Switch to staging CA (`caServer: https://acme-staging-v02.api.letsencrypt.org/directory`) while debugging |
| ACME: cert never issued | HTTP challenge blocked | Port 80 must reach Traefik publicly; check firewall, NAT, and DNS |
| Middleware not applied | Wrong middleware name or missing `@provider` suffix | Use `traefik.http.routers.<n>.middlewares=name@docker` for Docker-defined middlewares |
| TLS passthrough vs termination confusion | Using `passthrough: true` when you want Traefik to terminate TLS | Passthrough routes raw TCP — no headers injected, no cert management. For termination, omit passthrough |
| `certificate not trusted` in browser | Staging ACME cert in production | Switch `caServer` to production URL and delete `acme.json` to re-issue |
| `acme.json` permission error | Wrong file permissions | `chmod 600 /letsencrypt/acme.json` — ACME storage must not be world-readable |

## Pain Points
- **Static vs dynamic config split**: `entrypoints`, `providers`, `certificatesResolvers`, and `log` are static — they require a Traefik restart to change. Routers, services, and middlewares are dynamic — Traefik reloads them automatically. Confusing the two is the most common source of "my change did nothing" bugs.
- **Entrypoints are static-only**: You cannot define a new entrypoint via a Docker label or file provider. Add them to `traefik.yml` and restart.
- **Docker labels are dynamic config**: They are re-evaluated automatically as containers start/stop. No restart needed for label changes — but the container itself must restart.
- **ACME requires persistent storage**: `acme.json` must survive Traefik restarts. Use a named Docker volume or a bind-mounted path. Losing it forces re-issuance and may hit rate limits.
- **Dashboard has no auth by default**: With `api.insecure: true`, anyone who can reach port 8080 sees your full routing config. Always protect it with a middleware or bind to `127.0.0.1:8080` in production.
- **Traefik v2 vs v3 differences**: v3 removes the `pilot` section, changes some middleware names (e.g., `ReplacePathRegex` capitalization), and introduces the Hub integration. Docker Compose examples online are often v2 — check the `image:` tag before copying.
- **`exposedByDefault: false` is the safe default**: With `true`, every container gets a router — including databases and internal services. Set to `false` and opt in with `traefik.enable=true`.
- **`@provider` suffix in cross-provider references**: A middleware defined via Docker labels is `name@docker`. If a file-provider router references it, the full name `name@docker` is required.

## References
See `references/` for:
- `traefik.yml.annotated` — full static config with every directive explained, plus a dynamic config example
- `common-patterns.md` — Docker Compose setup, label-based routing, HTTPS, middlewares, TCP, load balancing, and file provider examples
- `docs.md` — official documentation links
