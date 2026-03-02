# Caddy Common Patterns

Each block below is complete and copy-paste-ready. Place site configs in
`/etc/caddy/Caddyfile` (single file) or split into `/etc/caddy/conf.d/*.caddy`
and include them with `import conf.d/*.caddy` at the top of `/etc/caddy/Caddyfile`.

Caddy obtains TLS certificates automatically for any qualifying hostname — no
Certbot, no manual cert management. The only requirement is that port 80 and 443
are reachable from the internet for ACME HTTP-01 validation.

---

## 1. Minimal HTTPS Site

The shortest valid Caddyfile. Caddy handles TLS, HTTP/2, HTTP/3, and the
HTTP-to-HTTPS redirect automatically. No SSL configuration needed.

```caddyfile
example.com {
    root * /var/www/example.com
    file_server
}
```

That's it. Caddy registers an ACME account, obtains a certificate from Let's
Encrypt, renews it automatically ~30 days before expiry, and redirects port 80
to HTTPS.

---

## 2. Reverse Proxy to Docker Container

Proxies to a container on a Docker bridge network. Replace `myapp` with the
container name or service name from docker-compose, and `3000` with the
container's internal port.

```caddyfile
app.example.com {
    reverse_proxy myapp:3000
}
```

For Docker Compose, Caddy must be on the same network as the target container:

```yaml
# docker-compose.yml excerpt
services:
  caddy:
    image: caddy:latest
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"   # HTTP/3
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - web

  myapp:
    image: myapp:latest
    networks:
      - web
    # No ports exposed to host — Caddy reaches it via Docker network

networks:
  web:

volumes:
  caddy_data:
  caddy_config:
```

The `caddy_data` volume persists TLS certificates across container restarts.
Without it, Caddy re-requests a cert every restart and hits rate limits quickly.

---

## 3. Multiple Sites in One Caddyfile

Each site block is independent. Caddy manages a separate TLS cert for each.

```caddyfile
# Global options apply to all sites.
{
    email admin@example.com
}

# Redirect www to apex.
www.example.com {
    redir https://example.com{uri} 301
}

# Main site.
example.com {
    root * /var/www/example.com
    encode gzip zstd
    file_server
}

# API backend.
api.example.com {
    reverse_proxy localhost:8080
}

# Admin panel — IP-restricted.
admin.example.com {
    @allowed remote_ip 10.0.0.0/8 203.0.113.5
    handle @allowed {
        reverse_proxy localhost:9000
    }
    handle {
        respond "Forbidden" 403
    }
}
```

---

## 4. PHP-FPM Integration

Serves a PHP application (e.g., WordPress, Laravel) via PHP-FPM.
`php_fastcgi` is Caddy's convenience wrapper — it sets SCRIPT_FILENAME,
PATH_INFO, and other required FastCGI parameters automatically.

```caddyfile
php.example.com {
    root * /var/www/myapp/public

    # Encode text responses.
    encode gzip zstd

    # Pass PHP files to FPM. Adjust socket path to match your php-fpm pool.
    # Debian/Ubuntu: /run/php/php8.2-fpm.sock
    # RHEL/Fedora:   /run/php-fpm/www.sock
    # TCP fallback:  127.0.0.1:9000
    php_fastcgi unix//run/php/php8.2-fpm.sock

    # Serve everything else as a static file.
    # file_server must come AFTER php_fastcgi; Caddy evaluates directives
    # in a defined priority order, not top-to-bottom.
    file_server

    # WordPress-style: try the request URI as a file/dir first, then fall
    # through to index.php for pretty permalinks.
    # Caddy handles this automatically with php_fastcgi's try_files behavior.
}
```

For WordPress, add a rewrite to route all requests through `index.php`:

```caddyfile
wordpress.example.com {
    root * /var/www/wordpress

    encode gzip zstd

    php_fastcgi unix//run/php/php8.2-fpm.sock

    # WordPress requires rewriting all non-file/dir requests to index.php.
    # Caddy's php_fastcgi does this by default — no explicit rewrite needed.

    file_server

    # Block access to sensitive WordPress files.
    @sensitive {
        path /wp-config.php
        path /.htaccess
        path /xmlrpc.php
    }
    respond @sensitive 403
}
```

---

## 5. Static File Server with Directory Listing

Exposes a directory tree with a browsable listing. Useful for artifact servers,
internal download mirrors, or shared file drops.

```caddyfile
files.example.com {
    root * /srv/shared

    # `browse` enables the built-in HTML directory listing template.
    # Without it, requesting a directory with no index.html returns 404.
    file_server browse

    # Optional: only allow downloads, block browsing HTML pages directly.
    # encode gzip zstd

    # Optional: add basic auth to restrict access.
    basicauth * {
        # Generate: caddy hash-password --plaintext "yourpassword"
        downloads $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
    }
}
```

---

## 6. Basic Authentication

Restricts access to a site or route. Passwords must be bcrypt-hashed before
adding to the Caddyfile — plain text passwords are not accepted.

```bash
# Generate a hashed password (run this on the server):
caddy hash-password --plaintext "your-secure-password"
```

```caddyfile
protected.example.com {
    # Apply basicauth to all paths (*).
    # Multiple users: add one username/hash pair per line.
    basicauth * {
        alice $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
        bob   $2a$14$AnotherHashHere...
    }

    reverse_proxy localhost:8080

    # Exempt a health check endpoint from auth.
    handle /health {
        respond "OK" 200
    }
}
```

To protect only a subdirectory:

```caddyfile
example.com {
    # Public area — no auth.
    handle /public/* {
        root * /var/www/public
        file_server
    }

    # Protected admin area.
    handle /admin/* {
        basicauth * {
            admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
        }
        reverse_proxy localhost:9000
    }
}
```

---

## 7. Custom TLS Certificate (Self-Signed or Internal CA)

Use when Caddy should not contact an ACME CA — for internal hostnames, air-gapped
networks, or when you supply certificates from your own CA.

```caddyfile
# Option A: Caddy generates a self-signed certificate automatically.
# The `tls internal` directive tells Caddy to use its internal CA instead of
# ACME. The cert will show a browser warning unless you trust Caddy's local CA.
# Install the local CA root: `caddy trust` (requires root/sudo).
internal.example.local {
    tls internal
    reverse_proxy localhost:3000
}

# Option B: Supply your own certificate files.
# Replace paths with your actual cert and key files.
internal.example.com {
    tls /etc/ssl/certs/example.com.crt /etc/ssl/private/example.com.key
    reverse_proxy localhost:3000
}

# Option C: Disable TLS entirely (plain HTTP on any port).
# Useful when Caddy sits behind another TLS-terminating proxy.
:8080 {
    tls off
    reverse_proxy localhost:3000
}
```

---

## 8. Wildcard Certificates (DNS Challenge)

Wildcard certs (`*.example.com`) cannot be obtained via HTTP-01 ACME challenge —
they require DNS-01. Caddy supports DNS-01 via provider-specific modules that
must be built with xcaddy.

```bash
# Build Caddy with Cloudflare DNS module (example):
xcaddy build --with github.com/caddy-dns/cloudflare
```

```caddyfile
{
    email admin@example.com
}

*.example.com {
    # tls block configures ACME DNS challenge.
    # Replace cloudflare with your DNS provider module.
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Caddy reads the token from the environment variable CLOUDFLARE_API_TOKEN.
        # Set it in /etc/caddy/environment or the systemd unit's EnvironmentFile.
    }

    # Route subdomains via the Host header using the `host` matcher.
    @app host app.example.com
    handle @app {
        reverse_proxy localhost:3000
    }

    @api host api.example.com
    handle @api {
        reverse_proxy localhost:8080
    }

    # Default fallback.
    handle {
        respond "Not found" 404
    }
}
```

Set the API token in `/etc/caddy/environment` (referenced by the systemd unit):

```bash
CLOUDFLARE_API_TOKEN=your_token_here
```

---

## 9. Local Development with HTTPS (`caddy trust`)

Gives local development sites valid HTTPS without ACME or browser warnings.
Caddy's internal CA issues a cert; `caddy trust` installs the CA root into the
system and browser trust stores.

```bash
# One-time setup — installs Caddy's local CA root:
sudo caddy trust

# Run Caddy for local dev (reads Caddyfile in the current directory):
caddy run
```

```caddyfile
# Caddyfile for local development
myapp.localhost {
    # `tls internal` uses Caddy's local CA — no ACME, no internet required.
    # After running `caddy trust`, the browser accepts this cert without warnings.
    tls internal

    reverse_proxy localhost:3000
}

# .localhost TLD is special — browsers recognize it as local without /etc/hosts.
# For custom names, add an entry to /etc/hosts:
#   127.0.0.1  myapp.dev
```

---

## 10. API Gateway with Path-Based Routing

Routes different URL paths to different backend services. Useful as a lightweight
API gateway when a full-featured gateway is overkill.

```caddyfile
api.example.com {
    # Route /auth/* to the auth service.
    handle /auth/* {
        uri strip_prefix /auth
        reverse_proxy localhost:4001
    }

    # Route /users/* to the user service.
    handle /users/* {
        uri strip_prefix /users
        reverse_proxy localhost:4002
    }

    # Route /orders/* to the order service.
    handle /orders/* {
        uri strip_prefix /orders
        reverse_proxy localhost:4003
    }

    # Add CORS headers for browser clients.
    header {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }

    # Handle OPTIONS preflight requests.
    @preflight method OPTIONS
    respond @preflight 204

    # Fallback for unmatched paths.
    handle {
        respond "Not found" 404
    }
}
```

For load-balanced upstreams, list multiple addresses in `reverse_proxy`:

```caddyfile
api.example.com {
    handle /api/* {
        uri strip_prefix /api
        # Caddy load-balances round-robin by default.
        # Health checks run passively; add `health_path /health` for active checks.
        reverse_proxy localhost:4001 localhost:4002 localhost:4003 {
            health_path /health
            health_interval 10s
            lb_policy round_robin
        }
    }
}
```
