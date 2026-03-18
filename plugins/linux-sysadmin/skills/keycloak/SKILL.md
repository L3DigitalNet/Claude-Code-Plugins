---
name: keycloak
description: >
  Keycloak identity and access management: Quarkus-based server deployment,
  realms, clients, users, roles, identity providers (OIDC, SAML, social login),
  admin CLI (kcadm.sh), reverse proxy headers, PostgreSQL database configuration,
  themes, Docker and bare-metal deployment.
  MUST consult when installing, configuring, or troubleshooting keycloak.
triggerPhrases:
  - "keycloak"
  - "Keycloak"
  - "keycloak realm"
  - "keycloak client"
  - "keycloak user"
  - "keycloak role"
  - "keycloak identity provider"
  - "keycloak OIDC"
  - "keycloak SAML"
  - "keycloak social login"
  - "kcadm.sh"
  - "keycloak admin CLI"
  - "keycloak.conf"
  - "keycloak theme"
  - "keycloak docker"
  - "keycloak reverse proxy"
  - "KC_BOOTSTRAP_ADMIN"
globs:
  - "**/keycloak.conf"
last_verified: "2026-03"
---

## Identity

- **Service**: Keycloak (Quarkus-based, v20+). Current release: 26.5.5 (March 2026)
- **Unit**: runs as a standalone Java process or container; no default systemd unit (create one for bare-metal)
- **Config**: `conf/keycloak.conf` (install-relative), environment variables (`KC_` prefix), or CLI arguments
- **Logs**: stdout/stderr by default; configure with `log=console,file`, `log-file=/var/log/keycloak/keycloak.log`
- **Data dir**: external database (PostgreSQL recommended for production); dev mode uses an embedded H2 file store
- **Binary**: `bin/kc.sh` (server), `bin/kcadm.sh` (admin CLI)
- **Image**: `quay.io/keycloak/keycloak` (official; also mirrored on Docker Hub)
- **JDK requirement**: OpenJDK 21
- **License**: Apache License 2.0

## Quick Start

```bash
# Docker dev mode (ephemeral, HTTP-only, auto-creates admin user)
docker run -p 127.0.0.1:8080:8080 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:26.5.5 start-dev

# Admin console: http://localhost:8080/admin
# Account console: http://localhost:8080/realms/master/account
```

For bare-metal, download the zip from the GitHub releases page, extract, then:

```bash
# Prerequisites: OpenJDK 21 installed
export KC_BOOTSTRAP_ADMIN_USERNAME=admin
export KC_BOOTSTRAP_ADMIN_PASSWORD=changeme
bin/kc.sh start-dev
```

## Key Operations

| Task | Command |
|------|---------|
| Start dev mode | `bin/kc.sh start-dev` |
| Build optimized config | `bin/kc.sh build` |
| Start production | `bin/kc.sh start --optimized` |
| Show build config | `bin/kc.sh show-config` |
| Admin CLI login | `kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin` |
| Create realm | `kcadm.sh create realms -s realm=myrealm -s enabled=true` |
| Create client (confidential) | `kcadm.sh create clients -r myrealm -s clientId=myapp -s secret=<SECRET> -s 'redirectUris=["https://app.example.com/*"]' -s enabled=true` |
| Create client (public) | `kcadm.sh create clients -r myrealm -s clientId=myapp -s publicClient=true -s 'redirectUris=["http://localhost:3000/*"]' -s enabled=true` |
| Create user | `kcadm.sh create users -r myrealm -s username=jdoe -s enabled=true -s email=jdoe@example.com` |
| Set password | `kcadm.sh set-password -r myrealm --username jdoe --new-password changeme` |
| Create realm role | `kcadm.sh create roles -r myrealm -s name=app-user` |
| Assign role to user | `kcadm.sh add-roles -r myrealm --uusername jdoe --rolename app-user` |
| Create OIDC identity provider | `kcadm.sh create identity-provider/instances -r myrealm -s alias=my-oidc -s providerId=oidc -s enabled=true -s 'config.authorizationUrl=https://idp.example.com/authorize' -s 'config.tokenUrl=https://idp.example.com/token' -s config.clientId=<CLIENT_ID> -s config.clientSecret=<CLIENT_SECRET>` |
| Create GitHub social provider | `kcadm.sh create identity-provider/instances -r myrealm -s alias=github -s providerId=github -s enabled=true -s config.clientId=<GITHUB_CLIENT_ID> -s config.clientSecret=<GITHUB_CLIENT_SECRET>` |
| Export realm | `kcadm.sh get realms/myrealm > realm-export.json` |

## Expected Ports

- **8080/tcp** -- HTTP (dev mode; disabled by default in production). Verify: `ss -tlnp | grep :8080`
- **8443/tcp** -- HTTPS (production). Verify: `ss -tlnp | grep :8443`
- **9000/tcp** -- management interface (health, metrics, readiness). Verify: `ss -tlnp | grep :9000`

## Health Checks

Health endpoints are served on the management port (9000) and must be enabled at build time.

```bash
# Enable health and metrics
bin/kc.sh build --health-enabled=true --metrics-enabled=true

# Or in keycloak.conf:
# health-enabled=true
# metrics-enabled=true

# Check readiness (HTTP 200 = ready, 503 = not ready)
curl --head -fsS http://localhost:9000/health/ready

# Check liveness
curl --head -fsS http://localhost:9000/health/live

# Check startup status
curl --head -fsS http://localhost:9000/health/started

# Combined health (all checks aggregated)
curl -s http://localhost:9000/health | jq .

# Prometheus metrics
curl -s http://localhost:9000/metrics
```

Available endpoints:

| Endpoint | Purpose |
|----------|---------|
| `/health` | Aggregate of all health checks |
| `/health/live` | Liveness probe: is the process running? |
| `/health/ready` | Readiness probe: can it handle requests? Includes DB connection pool check when metrics are enabled |
| `/health/started` | Startup probe: has initial startup completed? |
| `/metrics` | Prometheus-format operational metrics |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `HTTPS required` error in admin console | Realm SSL policy set to `external requests` or `all requests` but accessing via HTTP | For dev: access via `localhost` (exempted) or set realm SSL policy to `none` in admin console. For production: configure TLS certificates |
| `Invalid redirect URI` on login | Application redirect URI not in client's Valid Redirect URIs list | Add the exact URI (including path and trailing slash) to the client's Valid Redirect URIs in admin console or via kcadm.sh |
| Admin console returns 403 or blank page | Accessing admin from a hostname that doesn't match `hostname` config | Set `hostname=https://keycloak.example.com` or use `hostname-strict=false` for dev |
| `Failed to obtain JDBC connection` | PostgreSQL unreachable, wrong credentials, or database doesn't exist | Verify `db-url-host`, `db-username`, `db-password`; confirm PostgreSQL is running and the database exists (`createdb keycloak`) |
| `Port 8080 already in use` | Another process bound to the port | Change with `http-port=8081` in keycloak.conf, or stop the conflicting process |
| Health endpoints return 404 | Health checks not enabled at build time | Run `bin/kc.sh build --health-enabled=true` then restart |
| `User with username 'admin' already exists` in logs | `KC_BOOTSTRAP_ADMIN_*` env vars still set after initial admin creation | Safe to ignore; Keycloak logs a warning but starts normally. Remove the env vars to silence it |
| Infinite redirect loop behind reverse proxy | Missing or wrong `proxy-headers` setting | Set `proxy-headers=xforwarded` (or `forwarded`) and ensure the proxy sends correct `X-Forwarded-Proto: https` |
| Clients get `invalid_grant` or `expired token` | Clock skew between Keycloak and the client application | Sync clocks via NTP/chrony; check token lifespan settings in realm |
| Theme changes not visible | Theme cache not cleared | Restart Keycloak, or for development: `--spi-theme-cache-themes=false --spi-theme-cache-templates=false` |
| SAML assertion signature validation fails | Certificate mismatch between IdP and Keycloak SP config | Re-import the IdP metadata or manually update the signing certificate in the identity provider config |

## Pain Points

- **Dev mode vs production gap**: `start-dev` enables HTTP, disables hostname checks, uses an embedded H2 database, and skips the build step. None of these carry to production. Plan for TLS, PostgreSQL, and `bin/kc.sh build` from the start.
- **Build-time vs runtime options**: Options like `db`, `features`, `health-enabled`, and `metrics-enabled` are build-time. Changing them requires `bin/kc.sh build` before the change takes effect. Runtime options (credentials, hostname, log levels) apply immediately on `start`.
- **No `/auth` prefix in v20+**: Keycloak on Quarkus dropped the `/auth` context path that WildFly-based versions used. Older tutorials and clients that hardcode `/auth/realms/...` will break. Set `http-relative-path=/auth` to restore backwards compatibility if needed.
- **Admin bootstrapping**: `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` creates a temporary admin on first start. The older `KEYCLOAK_ADMIN` variables still work but are deprecated. Remove the env vars after creating a permanent admin account.
- **Reverse proxy is almost always required**: Production Keycloak sits behind nginx, Caddy, or a load balancer. You must set `proxy-headers=xforwarded` (or `forwarded`) and configure `proxy-trusted-addresses` to restrict which IPs can set those headers. Without this, Keycloak cannot detect the real client IP or protocol.
- **Realm export limitations**: The admin console export does not include user credentials or secrets. For full backup, use `kcadm.sh` or the REST API, or configure realm export on startup with `--export-realm` (dev/testing only).
- **JGroups clustering**: Multi-node production deployments need Infinispan/JGroups cache configuration. The default `jdbc-ping` discovery stack works for PostgreSQL-backed clusters; cloud deployments may need DNS_PING or Kubernetes-native discovery.

## See Also

- `vault` -- secrets management (store Keycloak DB passwords, client secrets, or TLS keys)
- `nginx` -- reverse proxy for Keycloak with `X-Forwarded-*` headers
- `caddy` -- alternative reverse proxy with automatic TLS
- `vaultwarden` -- password manager that can use Keycloak as OIDC provider

## References

See `references/` for:
- `docs.md` -- verified official documentation links
- `common-patterns.md` -- keycloak.conf production config, Docker Compose with PostgreSQL, reverse proxy setup, realm/client/user management via kcadm.sh, identity provider configuration, theme deployment
- `keycloak.conf.annotated` -- annotated Quarkus-based configuration file covering database, hostname, HTTP/HTTPS, proxy, features, logging, cache, transactions, and SPI theme settings
