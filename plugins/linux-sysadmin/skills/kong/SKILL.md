---
name: kong
description: >
  Kong API Gateway administration: declarative config (kong.yaml), Admin API,
  services/routes/plugins, rate limiting, authentication plugins, load balancing,
  DB-less mode, Docker deployment, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting kong.
triggerPhrases:
  - "kong"
  - "kong gateway"
  - "kong api gateway"
  - "kong plugin"
  - "kong route"
  - "kong service"
  - "kong admin api"
  - "kong declarative"
  - "kong.yml"
  - "kong db-less"
  - "api gateway"
globs:
  - "**/kong.yml"
  - "**/kong.yaml"
  - "**/kong.conf"
  - "**/kong/**"
last_verified: "2026-03"
---

## Identity
- **Docker image**: `kong/kong-gateway:3.13` (current stable; `kong:latest` tracks OSS releases)
- **Binary install**: Download from https://docs.konghq.com/gateway/latest/install/ or `apt`/`yum` repos
- **Config file**: `/etc/kong/kong.conf` (or env vars prefixed with `KONG_`)
- **Declarative config**: `kong.yml` / `kong.yaml` (DB-less mode)
- **Data dir**: `/usr/local/kong/` (prefix directory)
- **Logs**: `/usr/local/kong/logs/error.log`, `/usr/local/kong/logs/access.log`, or `docker logs kong`
- **User**: `kong`
- **Distro install**: `apt install kong` (from Kong repo) / Docker

## Quick Start

```bash
# DB-less mode with Docker (simplest setup)
docker run -d --name kong \
  -e "KONG_DATABASE=off" \
  -e "KONG_DECLARATIVE_CONFIG=/kong/kong.yml" \
  -e "KONG_PROXY_LISTEN=0.0.0.0:8000, 0.0.0.0:8443 ssl" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -v "$(pwd)/kong.yml:/kong/kong.yml:ro" \
  -p 8000:8000 -p 8443:8443 -p 8001:8001 \
  kong:latest

# Generate a declarative config template
kong config init

# Verify Kong is running
curl -s http://localhost:8001 | jq '.version'
```

## Key Operations

| Task | Command |
|------|---------|
| Check Kong version | `curl -s http://localhost:8001 \| jq '.version'` |
| Check Kong status | `curl -s http://localhost:8001/status \| jq .` |
| List all services | `curl -s http://localhost:8001/services \| jq '.data[].name'` |
| List all routes | `curl -s http://localhost:8001/routes \| jq '.data[].name'` |
| List all plugins | `curl -s http://localhost:8001/plugins \| jq '.data[].name'` |
| List enabled plugins | `curl -s http://localhost:8001 \| jq '.plugins.enabled_in_cluster'` |
| List consumers | `curl -s http://localhost:8001/consumers \| jq '.data[].username'` |
| Add a service (Admin API) | `curl -s -X POST http://localhost:8001/services -d name=my-svc -d url=http://backend:3000` |
| Add a route to a service | `curl -s -X POST http://localhost:8001/services/my-svc/routes -d 'paths[]=/api'` |
| Enable a plugin on a service | `curl -s -X POST http://localhost:8001/services/my-svc/plugins -d name=rate-limiting -d config.minute=60` |
| Delete a service | `curl -s -X DELETE http://localhost:8001/services/my-svc` |
| Load declarative config (runtime) | `curl -s -X POST http://localhost:8001/config -F 'config=@kong.yml'` |
| Validate declarative config | `kong config parse kong.yml` |
| Reload Kong (non-Docker) | `kong reload` |
| Check config syntax | `kong check /etc/kong/kong.conf` |
| Restart container | `docker restart kong` |

## Expected Ports

- `8000/tcp` — Proxy HTTP (consumers hit this)
- `8443/tcp` — Proxy HTTPS
- `8001/tcp` — Admin API HTTP (do NOT expose publicly without auth)
- `8444/tcp` — Admin API HTTPS
- `8002/tcp` — Kong Manager GUI HTTP (Enterprise)
- `8445/tcp` — Kong Manager GUI HTTPS (Enterprise)
- `8005/tcp` — Hybrid mode cluster (control plane)
- `8006/tcp` — Hybrid mode telemetry
- `8007/tcp` — Status listener (v3.6+; for health check probes)
- Verify: `ss -tlnp | grep kong` or `docker port kong`
- Firewall: expose only `8000` and `8443` publicly; restrict `8001`/`8444` to localhost or VPN

## Health Checks

1. `curl -sf http://localhost:8001/status | jq '.server.connections_active'` — Admin API responding
2. `curl -sI http://localhost:8000` — proxy entrypoint responding
3. `curl -sf http://localhost:8007/status` — status listener (v3.6+, if configured)
4. `docker logs kong 2>&1 | grep -i error | tail -20` — no unexpected errors

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Connection refused` on 8000 | Kong not running or proxy_listen misconfigured | Check `KONG_PROXY_LISTEN`; verify container is running: `docker ps` |
| `HTTP 404` on proxy | No route matches the request path/host | Check routes: `curl -s http://localhost:8001/routes \| jq .`; verify `paths` and `hosts` match the request |
| `HTTP 405 Not Allowed` on Admin API POST | DB-less mode: Admin API is read-only | Use declarative config (`kong.yml`) and reload via `/config` endpoint or restart |
| `HTTP 503 Service Unavailable` | Upstream service is down or unreachable | Check the upstream URL in the service definition; verify backend is reachable from Kong's network |
| `declarative_config: no such file` | Wrong path to kong.yml in config or env | Verify `KONG_DECLARATIVE_CONFIG` path; in Docker, check volume mount |
| Plugin config error on startup | Invalid plugin configuration in kong.yml | Run `kong config parse kong.yml` to validate; check plugin docs for required fields |
| `address already in use` | Port conflict with another process | Check with `ss -tlnp \| grep 8000`; change port in `KONG_PROXY_LISTEN` |
| Admin API exposed to internet | Default `admin_listen` binds to `0.0.0.0` | Set `KONG_ADMIN_LISTEN=127.0.0.1:8001` or use firewall rules |
| Consumer auth fails | Credentials not associated with consumer | Create consumer first, then create credentials: `POST /consumers/{consumer}/key-auth` |

## Pain Points

- **DB-less mode is read-only via Admin API**: You can GET from any endpoint, but POST/PATCH/PUT/DELETE return `405 Not Allowed`. All configuration must come from the declarative YAML file, loaded at startup or via `POST /config`. This is by design: DB-less trades mutability for simplicity.

- **Not all plugins work in DB-less mode**: Plugins that need to write state to a database at runtime (e.g., OAuth2, which stores tokens) are incompatible with DB-less mode. Check each plugin's documentation for a "Compatible protocols" or "DB-less compatible" note.

- **Declarative config is all-or-nothing**: When you POST to `/config`, the entire configuration is replaced atomically. There is no partial update. If the new config has a validation error, the old config remains active.

- **Admin API has no authentication by default**: Anyone who can reach port 8001 can reconfigure your gateway. Bind it to `127.0.0.1`, use the Kong Admin API RBAC (Enterprise), or put it behind a firewall.

- **Plugin execution order matters**: Kong runs plugins in a specific order determined by their priority value. Authentication plugins run before rate-limiting, which runs before request transformation. You cannot change this order; it is hardcoded per plugin type.

- **Service vs Route vs Upstream confusion**: A Service is a backend API (a URL). A Route maps incoming requests (by path, host, method) to a Service. An Upstream defines load-balancing targets for a Service. Plugins can be applied at global, service, route, or consumer scope.

- **Kong 3.x vs 2.x changes**: Kong 3.x deprecated several legacy features, changed the declarative config `_format_version` to `"3.0"`, and reorganized the plugin ecosystem. If migrating from 2.x, review the migration guide.

## See Also
- **traefik** — container-native reverse proxy with Docker label-based routing and automatic HTTPS
- **nginx** — high-performance web server and reverse proxy, lower-level config than Kong
- **envoy** — high-performance service proxy used in service mesh architectures
- **haproxy** — reliable TCP/HTTP load balancer with health checking

## References
See `references/` for:
- `docs.md` — official documentation links (Admin API, plugins, deployment topologies)
- `common-patterns.md` — Docker Compose DB-less setup, declarative config examples, authentication, rate limiting, load balancing
