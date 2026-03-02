# Traefik Common Patterns

Each block is copy-paste-ready. Traefik's config is split: `traefik.yml` holds static config
(entrypoints, providers, resolvers) and requires a restart to change. Docker labels and file
provider configs are dynamic and reload automatically as containers start/stop or files change.

---

## 1. Basic Docker Compose Setup

Minimal Traefik v3 stack. Creates a shared `proxy` network, mounts the Docker socket,
and stores ACME certs in a named volume.

```yaml
# docker-compose.yml
services:
  traefik:
    image: traefik:v3
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      # Dashboard — bind to localhost only; don't expose publicly without auth.
      - "127.0.0.1:8080:8080"
    volumes:
      # Docker socket: read-only is sufficient for provider discovery.
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # Static config file.
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      # ACME cert storage. Must survive restarts.
      - letsencrypt:/letsencrypt
    networks:
      - proxy

  # Example app. Attach to the proxy network so Traefik can reach it.
  whoami:
    image: traefik/whoami
    container_name: whoami
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.example.com`)"
      - "traefik.http.routers.whoami.entrypoints=websecure"
      - "traefik.http.routers.whoami.tls.certresolver=letsencrypt"

networks:
  proxy:
    external: true   # Create once with: docker network create proxy

volumes:
  letsencrypt:
```

---

## 2. Docker Labels for HTTP Routing

Plain HTTP routing — no TLS. Useful in internal environments or behind a TLS-terminating
upstream. The label names follow the pattern:
`traefik.http.routers.<router-name>.<option>=<value>`

```yaml
labels:
  # Required: opt this container into Traefik discovery.
  - "traefik.enable=true"

  # Router rule: match requests where the Host header equals this domain.
  # Composite rules: "Host(`a.example.com`) || Host(`b.example.com`)"
  # Path-based: "Host(`example.com`) && PathPrefix(`/api`)"
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"

  # Which entrypoint (defined in traefik.yml) this router listens on.
  - "traefik.http.routers.myapp.entrypoints=web"

  # Port the container listens on. Required when the image exposes multiple ports,
  # or when the container port differs from the default exposed port.
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

---

## 3. Docker Labels for HTTPS with Let's Encrypt

Terminates TLS at Traefik and forwards plain HTTP to the container.

```yaml
labels:
  - "traefik.enable=true"

  # Redirect HTTP to HTTPS (only needed if the web entrypoint doesn't already
  # have a global redirect configured in traefik.yml).
  - "traefik.http.routers.myapp-http.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp-http.entrypoints=web"
  - "traefik.http.routers.myapp-http.middlewares=redirect-https@file"

  # HTTPS router.
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls=true"

  # Name of the certificatesResolver defined in traefik.yml.
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"

  # Container port.
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

---

## 4. Middleware: Basic Auth

Restricts access to a router. The password hash uses bcrypt.
Generate with: `htpasswd -nB username` (install `apache2-utils` on Debian/Ubuntu).

In Docker labels, `$` in bcrypt hashes must be doubled (`$$`) because Docker Compose
performs `$` interpolation. In YAML dynamic config files, do NOT double the `$`.

```yaml
# Define the middleware via Docker labels on the Traefik container or any container.
# Conventional pattern: define auth middlewares on the Traefik container itself.
labels:
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$2y$$05$$abc123hashedpassword"

# Apply on the app's router.
# The @docker suffix tells Traefik this middleware is from the Docker provider.
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
  - "traefik.http.routers.myapp.middlewares=auth@docker"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

Alternatively, define in a dynamic config file (no `$$` escaping needed):

```yaml
# /etc/traefik/dynamic/auth.yml
http:
  middlewares:
    auth:
      basicAuth:
        users:
          - "admin:$2y$05$abc123hashedpassword"
        # Optional: htpasswd file instead of inline users.
        # usersFile: /etc/traefik/.htpasswd
        # removeHeader: true  # Strip Authorization header before forwarding.
```

---

## 5. Middleware: Rate Limiting

Limits requests per second per source IP. Traefik uses a token bucket algorithm.

```yaml
# Dynamic config file: /etc/traefik/dynamic/ratelimit.yml
http:
  middlewares:
    ratelimit:
      rateLimit:
        # Average: sustained request rate per second.
        average: 10

        # Burst: extra requests allowed above the average before throttling.
        # Total capacity = average + burst.
        burst: 20

        # Period over which the average is calculated. Default: 1s.
        # period: "1s"

        # Key: what to rate-limit by. Default: source IP.
        # sourceCriterion:
        #   ipStrategy:
        #     depth: 1          # Use the Nth IP from X-Forwarded-For.
        #     excludedIPs:
        #       - "127.0.0.1"
```

Apply in Docker labels:

```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=ratelimit@file"
```

---

## 6. Middleware: Redirect HTTP to HTTPS

Two approaches. Use the entrypoint-level redirect (in `traefik.yml`) for a global rule.
Use the middleware approach for per-router control.

**Global (traefik.yml — affects all routers on the `web` entrypoint):**

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
```

**Per-router (dynamic config file):**

```yaml
# /etc/traefik/dynamic/redirects.yml
http:
  middlewares:
    redirect-https:
      redirectScheme:
        scheme: https
        permanent: true   # 301; set false for 302 during testing.
```

Apply on the HTTP router only:

```yaml
labels:
  - "traefik.http.routers.myapp-http.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp-http.entrypoints=web"
  - "traefik.http.routers.myapp-http.middlewares=redirect-https@file"
```

---

## 7. Middleware: Security Headers

Injects common security headers on responses. This is a dynamic config definition —
apply to any router via `middlewares: secure-headers@file`.

```yaml
# /etc/traefik/dynamic/security-headers.yml
http:
  middlewares:
    secure-headers:
      headers:
        # Prevent browsers from sniffing content-type.
        contentTypeNosniff: true

        # Enable XSS filtering in older browsers.
        browserXssFilter: true

        # Deny framing entirely (use "SAMEORIGIN" to allow same-origin iframes).
        frameDeny: true

        # HSTS: force HTTPS for 1 year, including subdomains.
        # Do NOT enable until you're sure all subdomains support HTTPS.
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true

        # Referrer-Policy.
        referrerPolicy: "strict-origin-when-cross-origin"

        # Permissions-Policy (formerly Feature-Policy).
        permissionsPolicy: "camera=(), microphone=(), geolocation=()"

        # Custom headers to add.
        customResponseHeaders:
          X-Robots-Tag: "noindex, nofollow"   # Remove if you want search indexing.

        # Remove headers that leak server info.
        customRequestHeaders:
          X-Powered-By: ""
```

---

## 8. TCP Passthrough (Raw TCP Routing)

Routes TCP connections without TLS termination. Traefik reads the SNI from the TLS
ClientHello and routes based on it — the backend handles its own TLS.
Use this for databases, mail servers, or anything where Traefik should not inspect the payload.

```yaml
# traefik.yml — add a TCP entrypoint.
entryPoints:
  tcpentry:
    address: ":5432"   # Example: PostgreSQL.

# /etc/traefik/dynamic/tcp.yml
tcp:
  routers:
    postgres:
      entryPoints:
        - tcpentry
      rule: "HostSNI(`*`)"   # Match all SNIs. Use HostSNI(`db.example.com`) to be specific.
      service: postgres-svc
      tls:
        passthrough: true    # Do NOT terminate TLS; forward the raw stream.

  services:
    postgres-svc:
      loadBalancer:
        servers:
          - address: "192.168.1.20:5432"
```

Docker label equivalent (for a PostgreSQL container):

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.tcp.routers.postgres.rule=HostSNI(`*`)"
  - "traefik.tcp.routers.postgres.entrypoints=tcpentry"
  - "traefik.tcp.routers.postgres.tls.passthrough=true"
  - "traefik.tcp.services.postgres.loadbalancer.server.port=5432"
```

---

## 9. Weighted Load Balancing

Distributes traffic across backends with explicit weight ratios. Weight 3:1 sends
75% of requests to server A and 25% to server B.

```yaml
# /etc/traefik/dynamic/weighted.yml
http:
  services:
    weighted-app:
      weighted:
        services:
          - name: app-v2
            weight: 3
          - name: app-v1
            weight: 1

    app-v2:
      loadBalancer:
        servers:
          - url: "http://10.0.0.2:3000"

    app-v1:
      loadBalancer:
        servers:
          - url: "http://10.0.0.1:3000"
```

Reference `weighted-app` in a router:

```yaml
http:
  routers:
    myapp:
      rule: "Host(`myapp.example.com`)"
      entryPoints:
        - websecure
      service: weighted-app
      tls:
        certResolver: letsencrypt
```

---

## 10. File Provider for Non-Docker Services

Routes traffic to bare-metal or VM services that aren't in Docker. Define in the
file provider directory (`/etc/traefik/dynamic/`).

```yaml
# /etc/traefik/dynamic/bare-metal.yml
http:
  routers:
    homeserver:
      entryPoints:
        - websecure
      rule: "Host(`home.example.com`)"
      service: homeserver-svc
      tls:
        certResolver: letsencrypt
      # Optional middlewares.
      middlewares:
        - auth@file
        - secure-headers@file

  services:
    homeserver-svc:
      loadBalancer:
        servers:
          # Traefik forwards to this address. Can be HTTP even if the router uses HTTPS.
          - url: "http://192.168.1.100:8123"

        # Health check: Traefik polls this path. Removes the server from rotation on failure.
        healthCheck:
          path: /api/
          interval: "30s"
          timeout: "5s"

        # Preserve the Host header from the original request (default: false — Traefik
        # rewrites Host to the service URL). Set true if the backend checks Host.
        passHostHeader: true
```

The file provider watches the directory and reloads immediately when this file changes.
No restart needed — but changes to `traefik.yml` (entrypoints, providers) still require one.
