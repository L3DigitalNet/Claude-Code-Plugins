# nginx Common Patterns

Each block below is a complete, copy-paste-ready config. Place server{} blocks in
`/etc/nginx/sites-available/<name>` and symlink to `sites-enabled/`. Place upstream{}
blocks in `/etc/nginx/conf.d/upstream-<name>.conf` so they load before server{} blocks.

---

## 1. Simple Reverse Proxy

Proxies all traffic to a local app running on port 3000. No SSL.

```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;

        # Forward the original Host header so the upstream knows what was requested.
        proxy_set_header Host $host;

        # Pass real client IP — without this, your app sees 127.0.0.1 for all requests.
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Required for keepalive connections to upstream.
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

---

## 2. Reverse Proxy with SSL (Let's Encrypt)

Terminates HTTPS at nginx and proxies to a local app on port 3000.
Certbot places certs at `/etc/letsencrypt/live/<domain>/`.

```nginx
server {
    listen 80;
    server_name example.com;

    # Let's Encrypt ACME challenge — must be reachable over HTTP.
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other HTTP to HTTPS.
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name example.com;

    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # Trusted cert chain for OCSP stapling (fullchain.pem is also valid here).
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

    # HSTS: tell browsers to use HTTPS for 2 years.
    # Remove includeSubDomains if subdomains aren't all HTTPS.
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

---

## 3. Virtual Host (Static Files)

Serves a static site from `/var/www/mysite`. Suitable for HTML/CSS/JS, built SPAs, etc.

```nginx
server {
    listen 80;
    server_name mysite.example.com;

    root /var/www/mysite;
    index index.html;

    # Serve the file if it exists; serve index.html for SPA client-side routing;
    # return 404 only if neither exists.
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets aggressively in the browser.
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Deny access to hidden files (e.g., .git, .env).
    location ~ /\. {
        deny all;
    }
}
```

---

## 4. Multiple Virtual Hosts on the Same Server

Two separate domains on the same nginx instance. The `default_server` flag determines
which vhost catches requests that don't match any `server_name`.

```nginx
# First vhost — catches unmatched requests (default_server).
server {
    listen 80 default_server;
    server_name site-a.example.com;

    root /var/www/site-a;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Second vhost.
server {
    listen 80;
    server_name site-b.example.com;

    root /var/www/site-b;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

---

## 5. Load Balancer (Round-Robin Upstream)

Distributes requests across three backend servers using round-robin (the default).
Define upstream{} in `conf.d/` so it loads before the server{} block that references it.

```nginx
# /etc/nginx/conf.d/upstream-myapp.conf
upstream myapp {
    # Round-robin is the default — no directive needed.
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;

    # Optional: mark a server as backup (only used when others are down).
    # server 10.0.0.4:3000 backup;

    # Persistent keepalive connections to upstream workers.
    # Requires proxy_http_version 1.1 and proxy_set_header Connection ""
    # in the location block.
    keepalive 32;

    # NOTE: Active health checks (health_check directive) require nginx Plus.
    # For open-source nginx, use passive checks via max_fails and fail_timeout:
    # server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
}

# /etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://myapp;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

---

## 6. WebSocket Proxy

WebSocket requires the `Upgrade` and `Connection` headers to be forwarded. Without
these, the connection is downgraded to a regular HTTP response.

```nginx
# Map used to handle the Connection header correctly.
# $connection_upgrade resolves to "upgrade" when the client sends Upgrade,
# otherwise "close". Defined at http{} level (e.g., in conf.d/websocket.conf).
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name ws.example.com;

    location /ws/ {
        proxy_pass http://127.0.0.1:8080;

        # WebSocket handshake headers.
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        # Standard forwarding headers.
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # WebSocket connections are long-lived; disable read timeout or set it high.
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

---

## 7. Rate Limiting

Limits request rate per client IP using a token bucket algorithm.
Define `limit_req_zone` at `http{}` level (e.g., in `conf.d/rate-limit.conf`).

```nginx
# /etc/nginx/conf.d/rate-limit.conf
# Zone name: "api_limit", keyed by client IP, 10MB shared memory (~160K IPs),
# rate: 10 requests/second per IP.
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

# /etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name myapp.example.com;

    location /api/ {
        # burst: allow up to 20 extra requests queued above the rate limit.
        # nodelay: serve burst requests immediately (don't add artificial delay).
        # Without nodelay, burst requests are served at the rate limit pace.
        limit_req zone=api_limit burst=20 nodelay;

        # Optional: return 429 Too Many Requests instead of default 503.
        limit_req_status 429;

        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
    }
}
```

---

## 8. Basic Auth (htpasswd Protection)

Restricts a location to users listed in an htpasswd file.
Create the file: `htpasswd -c /etc/nginx/.htpasswd username`
Add users:       `htpasswd /etc/nginx/.htpasswd anotheruser`

```nginx
server {
    listen 80;
    server_name admin.example.com;

    location / {
        # Prompt displayed in the browser auth dialog.
        auth_basic "Restricted Area";

        # Path to the htpasswd file. Must be readable by the nginx user (www-data/nginx).
        auth_basic_user_file /etc/nginx/.htpasswd;

        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Allow a specific location without auth (e.g., health check endpoint).
    location /health {
        auth_basic off;
        proxy_pass http://127.0.0.1:3000/health;
    }
}
```

---

## 9. Redirect HTTP to HTTPS

Two patterns. Use the `return` approach — it's faster and simpler than a rewrite.

```nginx
# Pattern A: Dedicated HTTP server block (preferred).
server {
    listen 80;
    server_name example.com www.example.com;

    # 301 Permanent Redirect. Use 302 during testing to avoid browser caching.
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name example.com www.example.com;

    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Pattern B: Combined block using if (acceptable here — "if is evil" applies to
# complex rewrites, not simple redirects).
# server {
#     listen 80;
#     listen 443 ssl;
#     server_name example.com;
#     if ($scheme = http) { return 301 https://$host$request_uri; }
#     ...
# }
```

---

## 10. Custom Error Pages

Override default nginx error pages with your own HTML.

```nginx
server {
    listen 80;
    server_name example.com;

    root /var/www/example;

    # Define custom error pages. The path is relative to root or an absolute URI.
    error_page 404             /errors/404.html;
    error_page 500 502 503 504 /errors/50x.html;

    # Location for the custom error pages. Internal prevents direct client access.
    location /errors/ {
        internal;
        root /var/www/example;
    }

    # Alternative: redirect errors to an external URL.
    # error_page 503 https://status.example.com;

    location / {
        try_files $uri $uri/ =404;
    }
}
```
