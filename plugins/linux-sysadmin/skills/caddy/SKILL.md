---
name: caddy
description: >
  Caddy web server administration: Caddyfile syntax, automatic HTTPS via ACME,
  reverse proxy, TLS certificate management, JSON config API, xcaddy plugins,
  and troubleshooting. Triggers on: caddy, Caddyfile, auto HTTPS, automatic TLS,
  caddy reverse proxy, caddy server, acme_ca, caddy reload, caddy validate,
  caddy fmt, caddy adapt, caddy environ, xcaddy.
globs:
  - "**/Caddyfile"
  - "**/caddy.json"
  - "**/caddy/**"
---

## Identity
- **Unit**: `caddy.service`
- **Config**: `/etc/caddy/Caddyfile`
- **Data dir**: `/var/lib/caddy` (system service) or `~/.local/share/caddy` (user)
- **Logs**: `journalctl -u caddy`, `/var/log/caddy/access.log` (if configured)
- **User**: `caddy` (system service user created by official package)
- **Install**: official repo — https://caddyserver.com/docs/install

## Key Operations

| Operation | Command |
|-----------|---------|
| Status | `systemctl status caddy` |
| Start | `sudo systemctl start caddy` |
| Stop | `sudo systemctl stop caddy` |
| Reload (no downtime) | `sudo systemctl reload caddy` |
| Reload via API | `caddy reload --config /etc/caddy/Caddyfile` |
| Restart | `sudo systemctl restart caddy` |
| Validate config | `caddy validate --config /etc/caddy/Caddyfile` |
| Format Caddyfile | `caddy fmt --overwrite /etc/caddy/Caddyfile` |
| Adapt Caddyfile to JSON | `caddy adapt --config /etc/caddy/Caddyfile` |
| View compiled JSON config | `caddy adapt --config /etc/caddy/Caddyfile \| jq .` |
| Print environment | `caddy environ` |
| Run in foreground (test) | `caddy run --config /etc/caddy/Caddyfile` |
| Run with watch (auto-reload on change) | `caddy run --config /etc/caddy/Caddyfile --watch` |
| Check TLS cert status | `caddy list-modules` / check `/var/lib/caddy/.local/share/caddy/certificates/` |
| Reverse proxy one-liner | `caddy reverse-proxy --from :8080 --to localhost:3000` |
| File server one-liner | `caddy file-server --root /var/www --browse` |
| Version | `caddy version` |

## Expected Ports
- 80/tcp (HTTP — used for ACME HTTP-01 challenge and auto-redirect to HTTPS)
- 443/tcp (HTTPS)
- 443/udp (HTTP/3 via QUIC, enabled by default in recent versions)
- Verify: `ss -tlnp | grep caddy`
- Firewall: `sudo ufw allow 80,443/tcp` and `sudo ufw allow 443/udp` (for HTTP/3)

## Health Checks
1. `systemctl is-active caddy` → `active`
2. `caddy validate --config /etc/caddy/Caddyfile 2>&1` → `Valid configuration`
3. `curl -sI http://localhost` → HTTP response or redirect (not connection refused)
4. `ss -tlnp | grep ':80\|:443'` → caddy listed

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `listen tcp :80: bind: permission denied` | Port <1024 requires root or `CAP_NET_BIND_SERVICE` | System service runs as `caddy` user — grant capability: `sudo setcap cap_net_bind_service=+ep $(which caddy)` or use `AmbientCapabilities` in systemd unit |
| ACME challenge fails — cert not issued | Port 80 unreachable from the internet | Firewall or NAT not forwarding port 80; check `ufw`, router rules, and `curl http://<your-domain>/.well-known/acme-challenge/test` from external |
| `too many certificates already issued` | ACME rate limit hit (Let's Encrypt: 5 certs/domain/week) | Switch to staging CA in global options: `acme_ca https://acme-staging-v02.api.letsencrypt.org/directory` |
| DNS propagation — cert fails after domain change | New DNS record not yet visible to ACME CA | Wait for TTL expiry; check with `dig +short <domain> @8.8.8.8` |
| `config parse error` on reload | Caddyfile syntax error | Run `caddy validate --config /etc/caddy/Caddyfile`; check `journalctl -u caddy -n 50` |
| TLS cert not renewing | Data directory permission issue or ACME account lost | Check `/var/lib/caddy` ownership (`chown -R caddy:caddy /var/lib/caddy`); inspect cert expiry with `caddy adapt \| jq` |
| `unknown directive` | Directive requires an xcaddy plugin | Some directives (e.g., `rate_limit`, `crowdsec`) need a custom `xcaddy` build; check https://caddyserver.com/download |
| `caddy reload` has no effect | API admin endpoint disabled or wrong address | Admin defaults to `localhost:2019`; ensure `admin` is not disabled in global options |
| 502 from reverse proxy | Upstream not running or wrong address | Check upstream service; test with `curl http://127.0.0.1:<port>` directly |

## Pain Points
- **Automatic HTTPS is ON by default**: Any site block with a qualifying hostname gets a Let's Encrypt cert without any TLS configuration. In dev/internal environments this causes ACME failures — disable with `tls internal` (self-signed) or `auto_https off` in global options.
- **Caddyfile vs JSON API duality**: Caddyfile is the human-facing format; Caddy's native config is JSON. `caddy adapt` converts one to the other. The JSON API (`localhost:2019`) can modify live config without a reload, but changes are not written back to the Caddyfile — divergence is easy to introduce.
- **ACME rate limits during testing**: Let's Encrypt enforces 5 duplicate certificates per week. Always test with the staging CA (`acme_ca https://acme-staging-v02.api.letsencrypt.org/directory`) and only switch to production when the config is verified.
- **Data directory permissions**: Caddy stores ACME account keys and certificates in `/var/lib/caddy`. If the service user cannot write there (e.g., after a manual copy or ownership change), cert issuance silently fails. The directory must be owned by the `caddy` user.
- **xcaddy for third-party modules**: The standard `caddy` binary includes only first-party modules. Directives like `rate_limit`, `crowdsec`, `coraza` (WAF), or `cache` require a custom binary built with `xcaddy build`. The package-manager `caddy` binary cannot be extended at runtime.
- **`caddy reload` vs `caddy stop && caddy start`**: `caddy reload` sends the new config to the running process via the admin API — zero downtime, TLS session state preserved. `restart` via systemd is a full process replacement — brief downtime, session state lost. Prefer `reload` for all config changes in production.

## References
See `references/` for:
- `Caddyfile.annotated` — complete Caddyfile with every directive explained
- `common-patterns.md` — reverse proxy, PHP, static files, TLS, and API gateway examples
- `docs.md` — official documentation links
