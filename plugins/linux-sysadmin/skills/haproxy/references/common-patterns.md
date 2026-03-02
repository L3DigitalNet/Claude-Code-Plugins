# HAProxy Common Patterns

Each block below is complete and copy-paste-ready. Place configuration in
`/etc/haproxy/haproxy.cfg`. After editing, validate with `haproxy -c -f /etc/haproxy/haproxy.cfg`
before reloading with `systemctl reload haproxy`.

---

## 1. HTTP Load Balancing (Round-Robin)

Distributes HTTP traffic across three backend servers with passive health checks.
Round-robin distributes requests evenly; max_fails/fail_timeout implement passive
health tracking without requiring `option httpchk`.

```
frontend http_in
    bind *:80
    mode http
    default_backend web_servers

backend web_servers
    mode http
    balance roundrobin
    option forwardfor

    # Passive health check: mark DOWN after 3 failures, retry after 30s.
    # Active health check (option httpchk) is preferred — see Pattern 3.
    server web1 10.0.0.1:8080 check
    server web2 10.0.0.2:8080 check
    server web3 10.0.0.3:8080 check
```

---

## 2. HTTPS Termination with PEM Bundle

HAProxy terminates TLS and forwards plain HTTP to backends. The PEM bundle must
contain the leaf cert, intermediate chain, and private key — concatenated in that order.

Build the bundle from Let's Encrypt certificates:
```bash
cat /etc/letsencrypt/live/example.com/fullchain.pem \
    /etc/letsencrypt/live/example.com/privkey.pem \
    > /etc/haproxy/certs/example.com.pem
chmod 600 /etc/haproxy/certs/example.com.pem
```

```
frontend https_in
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/example.com.pem alpn h2,http/1.1
    mode http

    # Redirect plaintext HTTP to HTTPS.
    http-request redirect scheme https unless { ssl_fc }

    # HSTS: tell browsers to always use HTTPS for 2 years.
    # Only effective on HTTPS connections; the redirect above ensures this.
    http-response set-header Strict-Transport-Security "max-age=63072000"

    # Communicate the original protocol to backends (they receive plain HTTP).
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Proto http  unless { ssl_fc }

    option forwardfor
    default_backend web_servers

backend web_servers
    mode http
    balance roundrobin
    server web1 10.0.0.1:8080 check
    server web2 10.0.0.2:8080 check
```

For multiple domains (SNI-based cert selection), use a crt-list file:
```bash
# /etc/haproxy/crt-list.txt
/etc/haproxy/certs/example.com.pem example.com
/etc/haproxy/certs/other.com.pem   other.com
```
Then in the bind directive: `bind *:443 ssl crt-list /etc/haproxy/crt-list.txt`

---

## 3. Health Checks (HTTP and TCP)

HAProxy supports active health checks (it probes backends) and passive checks
(it watches real traffic). Active checks detect failures before any client hits
a down server.

```
backend web_servers_http_check
    mode http
    balance roundrobin

    # Active HTTP health check: send GET /health every 3s.
    # The \r\nHost: header is required for virtualhosted backends.
    option httpchk GET /health HTTP/1.1\r\nHost:\ localhost

    # Healthy = HTTP 200. Accept a range: "200-399" also works.
    http-check expect status 200

    # check: enable active health checks
    # inter 3s: check every 3 seconds
    # rise 2: need 2 consecutive successes to mark UP
    # fall 3: need 3 consecutive failures to mark DOWN
    server web1 10.0.0.1:8080 check inter 3s rise 2 fall 3
    server web2 10.0.0.2:8080 check inter 3s rise 2 fall 3


backend db_servers_tcp_check
    mode tcp
    balance leastconn

    # TCP health check: just verify the port accepts a connection.
    # No HTTP request is sent; a successful TCP connect = healthy.
    # Default behavior when option httpchk is absent and check is specified.
    server db1 10.0.1.1:5432 check inter 5s rise 2 fall 2
    server db2 10.0.1.2:5432 check inter 5s rise 2 fall 2
```

Check a specific port for health (different from the service port):
```
# "port 8081" overrides the health check port for this server only.
server web1 10.0.0.1:8080 check port 8081 inter 3s
```

---

## 4. Sticky Sessions (Cookie Insertion)

Ties a client to a specific backend server by inserting a persistence cookie.
Use this only when the application has server-side session state that is not
shared across servers. Stateless applications do not need this.

```
backend web_servers
    mode http
    balance roundrobin

    # Cookie name: SERVERID (visible in browser dev tools)
    # insert: add the cookie if the client doesn't already have one
    # indirect: remove the cookie from upstream responses (backends don't need to see it)
    # nocache: set Cache-Control headers to prevent CDNs from caching the cookie
    cookie SERVERID insert indirect nocache

    option httpchk GET /health HTTP/1.1\r\nHost:\ localhost
    http-check expect status 200

    # cookie <value>: the string stored in the cookie to identify this server.
    # Must be unique per server in the pool.
    server web1 10.0.0.1:8080 check cookie web1
    server web2 10.0.0.2:8080 check cookie web2
    server web3 10.0.0.3:8080 check cookie web3
```

If the target server is DOWN, HAProxy will route the request to another server
and update the cookie — the session is not lost, but it will not persist to the
original server until it recovers.

---

## 5. ACL-Based Routing (Path and Host)

Route to different backends based on request path prefix or Host header.
ACLs are evaluated top-to-bottom; the first matching `use_backend` rule wins.

```
frontend http_in
    bind *:80
    mode http
    log global

    # Path-based ACLs.
    acl is_api      path_beg /api/
    acl is_static   path_beg /static/ /img/ /css/ /js/

    # Host-based ACLs.
    acl host_api    hdr(host) -i api.example.com
    acl host_admin  hdr(host) -i admin.example.com

    # Dispatch rules. Evaluated in order; first match wins.
    use_backend api_servers    if is_api or host_api
    use_backend static_servers if is_static
    use_backend admin_backend  if host_admin

    default_backend web_servers

backend api_servers
    mode http
    balance leastconn
    timeout server 120s
    option httpchk GET /api/health HTTP/1.1\r\nHost:\ api.example.com
    server api1 10.0.1.1:8080 check
    server api2 10.0.1.2:8080 check

backend static_servers
    mode http
    balance roundrobin
    server static1 10.0.2.1:80 check
    server static2 10.0.2.2:80 check

backend admin_backend
    mode http
    balance roundrobin
    # Restrict to internal IPs using a second ACL applied at backend level.
    # acl internal src 10.0.0.0/8
    # http-request deny if !internal
    server admin1 10.0.3.1:8080 check

backend web_servers
    mode http
    balance roundrobin
    server web1 10.0.0.1:8080 check
    server web2 10.0.0.2:8080 check
```

---

## 6. Stats Page Setup

Expose the HAProxy stats dashboard. Bind to 127.0.0.1 and tunnel via SSH for
production; never expose to the public internet without authentication.

```
listen stats
    # Bind to all interfaces for internal network access, or 127.0.0.1 for localhost only.
    bind *:9000

    mode http
    log global

    stats enable
    stats uri /stats
    stats realm HAProxy\ Statistics
    stats auth admin:changeme          # Change this password.
    stats refresh 30s

    # Allow server enable/disable/drain from the web UI.
    stats admin if TRUE

    # Hide server version from the stats page.
    stats hide-version
```

Access from a remote workstation via SSH tunnel:
```bash
ssh -L 9000:localhost:9000 user@haproxy-host
# Then browse to http://localhost:9000/stats
```

---

## 7. TCP Mode (MySQL, PostgreSQL Passthrough)

HAProxy passes raw TCP connections to database backends without inspecting content.
Health checks use TCP connect by default; a custom `tcp-check` sequence can simulate
a protocol handshake for more accurate health detection.

```
listen mysql_cluster
    bind *:3306
    mode tcp
    balance leastconn

    # TCP keepalive: detect dead connections at the OS level.
    option tcpka

    # Log TCP connections (not HTTP-formatted).
    option tcplog

    # TCP health check: attempt a full connect then send a MySQL client greeting
    # and check for a valid server response byte. Omit tcp-check for simple connect.
    option tcp-check
    tcp-check connect
    # A MySQL 5.x server responds with 0x0a as the first byte of the greeting.
    # Omit this if your MySQL version differs or use a dedicated health check account.
    # tcp-check expect binary 0a

    # Disable HTTP-specific options inherited from defaults.
    option http-server-close
    no option forwardfor

    timeout connect 5s
    timeout client  1h    # Long timeout for idle DB connections.
    timeout server  1h

    server db1 10.0.1.1:3306 check inter 10s rise 2 fall 3
    server db2 10.0.1.2:3306 check inter 10s rise 2 fall 3 backup


listen postgres_cluster
    bind *:5432
    mode tcp
    balance leastconn

    timeout connect 5s
    timeout client  1h
    timeout server  1h

    server pg1 10.0.2.1:5432 check inter 10s
    server pg2 10.0.2.2:5432 check inter 10s backup
```

---

## 8. Graceful Reload with `-sf`

`systemctl reload haproxy` handles this correctly on systemd distros. For manual
reloads or scripted deployments, pass the old master PID to `-sf` so the old
process hands off its listening sockets and waits for existing connections to finish.

```bash
# Write the current PID to a file (haproxy does this when pid file is configured).
# global section: pidfile /run/haproxy.pid

# Graceful reload: new process starts, old process drains then exits.
haproxy -f /etc/haproxy/haproxy.cfg -sf $(cat /run/haproxy.pid)

# Validate before reloading (always do this first).
haproxy -c -f /etc/haproxy/haproxy.cfg && \
  haproxy -f /etc/haproxy/haproxy.cfg -sf $(cat /run/haproxy.pid)
```

The `-sf` flag (soft finish) signals the old workers to stop accepting new connections
but keeps them alive until current sessions close. `-st` (hard terminate) closes
sessions immediately — equivalent to a restart.

For the `stats socket expose-fd listeners` to work (required for HAProxy 2.x
socket-based reload), the systemd unit must also have `ExecReload` configured.
Check `systemctl cat haproxy` to confirm.

---

## 9. Connection Draining Before Maintenance

Drain a server to allow in-flight requests to complete before taking it offline.
The server stops receiving new connections but keeps existing ones until they close.

```bash
# Step 1: Set the server to DRAIN state via the runtime API.
echo "set server web_servers/web1 state drain" | \
  sudo socat stdio /run/haproxy/admin.sock

# Step 2: Monitor current connections on that server.
# The "scur" column (current sessions) should trend to 0.
watch -n 2 'echo "show servers state web_servers" | sudo socat stdio /run/haproxy/admin.sock'

# Step 3: Once scur = 0, disable the server completely.
echo "disable server web_servers/web1" | \
  sudo socat stdio /run/haproxy/admin.sock

# Step 4: Perform maintenance on web1.

# Step 5: Re-enable the server after maintenance.
echo "enable server web_servers/web1" | \
  sudo socat stdio /run/haproxy/admin.sock

# Step 6: Confirm it shows as UP.
echo "show servers state web_servers" | \
  sudo socat stdio /run/haproxy/admin.sock
```

Note: drain state changes via the socket are volatile — they are lost on HAProxy
reload/restart. For permanent disable, comment out the server line in `haproxy.cfg`
and reload.

---

## 10. Rate Limiting with Stick Tables

HAProxy stick tables track client state (connection counts, request rates) across
requests. Use them to rate-limit by IP at the TCP or HTTP level.

```
frontend http_in
    bind *:80
    mode http

    # Define a stick table to track HTTP request rate per client IP.
    # type ip: key is client IP
    # size 100k: track up to 100,000 unique IPs
    # expire 30s: remove entries after 30s of inactivity
    # store http_req_rate(10s): count requests per IP in a 10s sliding window
    stick-table type ip size 100k expire 30s store http_req_rate(10s),conn_cur

    # Track each connection into the table.
    http-request track-sc0 src

    # Deny if the IP has made more than 100 requests in the last 10s.
    # Adjust the threshold to match your expected legitimate traffic patterns.
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }

    # Deny if the IP has more than 20 concurrent connections.
    http-request deny deny_status 429 if { sc_conn_cur(0) gt 20 }

    default_backend web_servers

backend web_servers
    mode http
    balance roundrobin
    server web1 10.0.0.1:8080 check
    server web2 10.0.0.2:8080 check
```

Inspect the stick table at runtime:
```bash
# Show all entries in the table (table name = frontend name for inline tables).
echo "show table http_in" | sudo socat stdio /run/haproxy/admin.sock

# Clear a specific IP entry (e.g., after a false positive).
echo "clear table http_in key 192.168.1.100" | sudo socat stdio /run/haproxy/admin.sock
```

For TCP rate limiting, use a `listen` or `frontend` in `mode tcp` and replace
`http_req_rate` with `conn_rate(10s)`.
