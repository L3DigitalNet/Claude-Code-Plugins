---
name: haproxy
description: >
  HAProxy load balancer and TCP/HTTP proxy administration: config syntax,
  frontend/backend sections, ACL-based routing, SSL termination, health checks,
  stats socket, session persistence, and troubleshooting. Triggers on: haproxy,
  load balancer, HAProxy, haproxy stats, haproxy backend, TCP load balance,
  haproxy frontend, haproxy ACL, haproxy reload, haproxy drain.
globs:
  - "**/haproxy.cfg"
  - "**/haproxy/**/*.cfg"
  - "**/haproxy/**/*.conf"
---

## Identity
- **Unit**: `haproxy.service`
- **Config**: `/etc/haproxy/haproxy.cfg`
- **Stats socket**: `/run/haproxy/admin.sock`
- **Logs**: `journalctl -u haproxy`, `/var/log/haproxy.log` (requires rsyslog; see Pain Points)
- **User/group**: `haproxy` (both Debian/Ubuntu and RHEL/Fedora)
- **Distro install**: `apt install haproxy` / `dnf install haproxy`

## Key Operations

| Operation | Command |
|-----------|---------|
| Status | `systemctl status haproxy` |
| Graceful reload (no dropped connections) | `sudo systemctl reload haproxy` or `haproxy -sf $(cat /run/haproxy.pid) -f /etc/haproxy/haproxy.cfg` |
| Validate config | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` |
| Restart (drops connections) | `sudo systemctl restart haproxy` |
| Show process info via socket | `echo "show info" \| sudo socat stdio /run/haproxy/admin.sock` |
| Show all backends | `echo "show backend" \| sudo socat stdio /run/haproxy/admin.sock` |
| Show server state | `echo "show servers state" \| sudo socat stdio /run/haproxy/admin.sock` |
| Show active connections | `echo "show stat" \| sudo socat stdio /run/haproxy/admin.sock \| cut -d',' -f1,2,5,6,18,19` |
| Enable a server | `echo "enable server mybackend/web1" \| sudo socat stdio /run/haproxy/admin.sock` |
| Disable a server (immediate) | `echo "disable server mybackend/web1" \| sudo socat stdio /run/haproxy/admin.sock` |
| Drain a server (finish sessions) | `echo "set server mybackend/web1 state drain" \| sudo socat stdio /run/haproxy/admin.sock` |
| Set server weight | `echo "set server mybackend/web1 weight 50" \| sudo socat stdio /run/haproxy/admin.sock` |
| Check active connections count | `echo "show info" \| sudo socat stdio /run/haproxy/admin.sock \| grep CurrConns` |
| Clear statistics counters | `echo "clear counters all" \| sudo socat stdio /run/haproxy/admin.sock` |
| Show stick table entries | `echo "show table mybackend" \| sudo socat stdio /run/haproxy/admin.sock` |

## Expected State

| Resource | Expected value |
|----------|---------------|
| HTTP frontend port | 80/tcp |
| HTTPS frontend port | 443/tcp |
| Stats page port | 9000/tcp (or as configured) |
| Backend health check ports | Varies (typically app port) |
| Socket permissions | `/run/haproxy/admin.sock` — writable by haproxy user; readable by root |

Verify: `ss -tlnp | grep haproxy`

## Health Checks
1. `systemctl is-active haproxy` → `active`
2. `sudo haproxy -c -f /etc/haproxy/haproxy.cfg 2>&1` → contains `Configuration file is valid`
3. `echo "show info" | sudo socat stdio /run/haproxy/admin.sock | grep Uptime` → shows uptime
4. `echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock` → all backend servers show state `2` (UP)

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `cannot bind socket [0.0.0.0:80]` | Port already in use or permission denied | `ss -tlnp \| grep :80`; below port 1024 requires root or `CAP_NET_BIND_SERVICE` |
| All servers DOWN in backend | Health check path returning non-2xx, or wrong check port | `echo "show servers state" \| socat stdio /run/haproxy/admin.sock`; verify `option httpchk` path |
| SSL: `no suitable signature algorithm` | PEM bundle missing intermediate cert | Bundle must be: leaf cert + intermediates + (optionally) root, concatenated in order |
| SSL: `Timeout during SSL handshake` | Client timeout too low or backend too slow | Increase `timeout client` in defaults or frontend; check backend response time |
| Health check failing silently | No `option httpchk` but backend expects HTTP | Add `option httpchk GET /health HTTP/1.1\r\nHost: localhost` to backend |
| Session table full | `stick-table` size too small under load | `echo "show table" \| socat...` to inspect; increase `size` in stick-table definition |
| `timeout connect` vs `timeout server` confusion | Both hit at different phases | `timeout connect` = TCP SYN to backend; `timeout server` = waiting for backend response after connect |
| Log not appearing in `/var/log/haproxy.log` | rsyslog not configured for HAProxy's local2 facility | Add `/etc/rsyslog.d/49-haproxy.conf`; see Pain Points |
| `nbthread` startup error | Thread count exceeds compiled-in limit | Check `haproxy -vv \| grep THREAD`; reduce `nbthread` to match |
| 503 Service Unavailable | All backends DOWN or backend has no servers | `show servers state` via socket; check backend server lines |

## Pain Points
- **Config section order is mandatory**: `global` must come before `defaults`, which must come before `frontend`/`backend`. Sections out of order cause a parse error.
- **Graceful reload requires `-sf` PID passing**: `systemctl reload haproxy` handles this on systemd distros, but manual reloads must pass the old master PID with `-sf` — otherwise the old process keeps its bound ports and the new one fails to bind.
- **SSL cert must be a PEM bundle**: HAProxy needs a single file containing the leaf certificate, intermediates, and private key concatenated in that order. Let's Encrypt `fullchain.pem` + `privkey.pem` must be combined: `cat fullchain.pem privkey.pem > /etc/haproxy/certs/example.com.pem`.
- **ACL evaluation order matters**: ACLs are evaluated top-to-bottom; the first matching `use_backend` rule wins. Wildcard or catch-all ACLs placed early will shadow more specific ones below them.
- **Stick tables for session persistence**: Cookie-based persistence (`cookie insert`) is the preferred approach for HTTP. Stick tables (`stick-table type ip`) are better for TCP or when you cannot set cookies. The two mechanisms are independent and not interchangeable.
- **Stats socket security**: The admin socket (`level admin`) allows disabling servers and changing weights — it must be restricted to root or a dedicated admin group. Never expose it to application users.
- **`option forwardfor` strips existing header by default**: If HAProxy is behind another proxy, the `X-Forwarded-For` header from the upstream proxy is preserved only when using `option forwardfor except 127.0.0.1` or similar. Without it, the header is replaced with the connecting IP.
- **`maxconn` must be set at multiple levels**: The global `maxconn` caps the total process, `defaults`/`frontend` `maxconn` caps per-listener, and each `server` line can have its own `maxconn`. All three interact; the lowest one wins.

## References
See `references/` for:
- `haproxy.cfg.annotated` — complete config with every directive explained
- `common-patterns.md` — HTTP LB, HTTPS termination, sticky sessions, TCP mode, and rate limiting examples
- `docs.md` — official documentation links
