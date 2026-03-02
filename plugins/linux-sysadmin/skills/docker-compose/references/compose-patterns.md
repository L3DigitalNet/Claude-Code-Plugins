# Docker Compose Patterns

Complete, working compose file examples for common scenarios.

---

## 1. Basic Web App + Database

Postgres with a healthcheck; app waits for healthy DB before starting.

```yaml
# compose.yml
services:
  app:
    image: nginx:alpine
    ports:
      - "8080:80"
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: secret
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

volumes:
  db-data:
```

---

## 2. Environment Variables and .env File

`.env` is loaded automatically from the same directory as the compose file.
Use `environment:` for inline values, `env_file:` to load a file explicitly.

```yaml
# compose.yml
services:
  app:
    image: myapp:latest
    environment:
      # Literal value — always set to this string
      LOG_LEVEL: info
      # Interpolated from .env or shell env
      DATABASE_URL: "postgresql://${DB_USER}:${DB_PASS}@db:5432/${DB_NAME}"
      # Escape a literal dollar sign in the value
      DOLLAR_EXAMPLE: "costs $$5.00"
    env_file:
      # Loaded in addition to environment: block above
      - .env
      - .env.local    # Optional; compose ignores missing files with required: false
```

```ini
# .env  (same directory as compose.yml)
DB_USER=appuser
DB_PASS=secret
DB_NAME=appdb
```

**Precedence (highest to lowest):** shell env > `.env` > `environment:` block > `env_file:`.

---

## 3. Named Volumes

Named volumes are managed by Docker and persist across `down` (but not `down -v`).
Bind mounts use a host path; named volumes use Docker's storage backend.

```yaml
# compose.yml
services:
  db:
    image: postgres:16
    volumes:
      # Named volume — Docker manages the path
      - db-data:/var/lib/postgresql/data
      # Bind mount — host path to container path
      - ./init-scripts:/docker-entrypoint-initdb.d:ro

  cache:
    image: redis:7
    volumes:
      - redis-data:/data

# Volumes declared here are created automatically on first `up`
volumes:
  db-data:
  redis-data:
    # Optional: use an external volume created outside compose
    # external: true
```

Inspect volume contents: `docker run --rm -v db-data:/data alpine ls /data`

---

## 4. Custom Networks

Services on the same network can reach each other by service name.
Isolate frontend/backend by placing them on separate networks.

```yaml
# compose.yml
services:
  proxy:
    image: nginx:alpine
    ports:
      - "80:80"
    networks:
      - frontend

  app:
    image: myapp:latest
    networks:
      - frontend
      - backend

  db:
    image: postgres:16
    # Only reachable from app — not from proxy
    networks:
      - backend

networks:
  frontend:
    # driver: bridge is the default; explicit here for clarity
    driver: bridge
  backend:
    driver: bridge
```

Service name DNS resolution only works within shared networks. `app` can reach `db:5432`;
`proxy` cannot.

---

## 5. Healthchecks

Define a healthcheck on the service being waited on; use `condition: service_healthy`
in the dependent service's `depends_on`.

```yaml
# compose.yml
services:
  app:
    image: myapp:latest
    depends_on:
      api:
        condition: service_healthy
      db:
        condition: service_healthy

  api:
    image: myapi:latest
    healthcheck:
      # HTTP check — curl must be in the image
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 20s   # Grace period before retries count as failures

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: appuser
      POSTGRES_DB: appdb
      POSTGRES_PASSWORD: secret
    healthcheck:
      # pg_isready is included in the postgres image
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
```

Without `start_period`, the container can fail healthchecks during normal startup and
be marked unhealthy before it's ready.

---

## 6. Build + Image

Use `build:` to build from a local Dockerfile, or `image:` to pull from a registry.
Both can coexist: compose builds the image and tags it with the name from `image:`.

```yaml
# compose.yml
services:
  app:
    # Build from local Dockerfile; tag the result as myapp:dev
    build:
      context: .               # Build context (sent to Docker daemon)
      dockerfile: Dockerfile   # Relative to context; default is Dockerfile
      args:
        # Build args passed to ARG instructions in the Dockerfile
        APP_ENV: development
        NODE_VERSION: "20"
    image: myapp:dev           # Tag assigned after build
    ports:
      - "3000:3000"

  worker:
    # Pull from registry — no local build
    image: myworker:1.2.3
    command: ["python", "-m", "worker"]
```

Run `docker compose build` to build without starting, or `docker compose up -d --build`
to build and start in one step.

---

## 7. Reverse Proxy Pattern

Two approaches: nginx as a static proxy with explicit port mappings, or Traefik
reading labels to configure itself dynamically.

### nginx as proxy

```yaml
# compose.yml
services:
  proxy:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - app

  app:
    image: myapp:latest
    # No ports exposed to host — only reachable via proxy
    expose:
      - "8000"
```

```nginx
# nginx.conf
server {
    listen 80;
    location / {
        proxy_pass http://app:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Traefik as proxy (label-driven)

```yaml
# compose.yml
services:
  traefik:
    image: traefik:v3
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "8080:8080"    # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  app:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.example.com`)"
      - "traefik.http.services.app.loadbalancer.server.port=8000"
```

---

## 8. Resource Limits

`resources.limits` enforces a hard cap. `resources.reservations` guarantees
minimums for scheduling decisions.

```yaml
# compose.yml
services:
  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: "0.50"      # Max 50% of one CPU core
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M

  worker:
    image: myworker:latest
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
```

`deploy.resources` requires Compose v2. With Compose v1 (legacy), use the
top-level `mem_limit` and `cpus` keys instead.

---

## 9. Profiles

Services without a `profiles:` key start by default. Services with a profile
are only started when that profile is explicitly activated.

```yaml
# compose.yml
services:
  app:
    image: myapp:latest
    ports:
      - "8000:8000"

  db:
    image: postgres:16
    # No profile — starts with normal `docker compose up`

  debug-tools:
    image: nicolaka/netshoot
    profiles:
      - debug
    network_mode: service:app   # Share app's network namespace

  adminer:
    image: adminer
    profiles:
      - debug
    ports:
      - "8081:8080"
    depends_on:
      - db
```

Start with debug tools: `docker compose --profile debug up -d`
Start without: `docker compose up -d` (debug-tools and adminer are excluded)

---

## 10. Override Files

`compose.override.yml` is merged automatically with `compose.yml` when both exist
in the same directory. Use this to keep dev-only config separate from the base file.

```yaml
# compose.yml  (base — used in both dev and prod)
services:
  app:
    image: myapp:latest
    environment:
      LOG_LEVEL: info

  db:
    image: postgres:16
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

```yaml
# compose.override.yml  (merged automatically in dev)
services:
  app:
    build: .             # Build locally in dev instead of pulling image
    volumes:
      - .:/app           # Live-reload source mount
    environment:
      LOG_LEVEL: debug   # Override for dev

  db:
    ports:
      - "5432:5432"      # Expose DB port to host in dev only
```

For production: `docker compose -f compose.yml up -d` (ignores override file).
For a named override: `docker compose -f compose.yml -f compose.prod.yml up -d`.

---

## 11. Secrets

Docker secrets (via `secrets:`) are mounted as files inside the container at
`/run/secrets/<name>`. Environment variables are simpler but visible in
`docker inspect` and process listings.

```yaml
# compose.yml
services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    environment:
      # Tell the app where to read the secret from
      DB_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key

# Secrets declared here are mounted read-only from host files
secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    file: ./secrets/api_key.txt
```

The app must be written to read the file path from the `_FILE` env var and load
the value at startup — this convention is used by many official images (postgres,
mysql, redis).

**When to use secrets vs env vars:**
- Env vars: low-sensitivity config (log level, feature flags, URLs without credentials)
- Secrets: passwords, API keys, TLS private keys — anything that must not appear in `docker inspect`

---

## 12. Logging Config

Configure per-service logging to control driver, rotation, and retention.

```yaml
# compose.yml
services:
  app:
    image: myapp:latest
    logging:
      driver: json-file       # Default driver; writes to /var/lib/docker/containers/
      options:
        max-size: "10m"       # Rotate when log file reaches 10 MB
        max-file: "5"         # Keep at most 5 rotated files (~50 MB total)

  worker:
    image: myworker:latest
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

  # Send logs to a remote syslog endpoint instead
  api:
    image: myapi:latest
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://logs.example.com:514"
        syslog-facility: daemon
        tag: "myapp-api"
```

Without `max-size` / `max-file`, containers write unbounded logs to disk until
the host runs out of space. Always set these in production.

View logs regardless of driver: `docker compose logs -f servicename`
