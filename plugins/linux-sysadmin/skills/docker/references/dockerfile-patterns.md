# Dockerfile Patterns

Canonical, working examples for common Dockerfile patterns. All examples assume
`docker build -t myapp .` from the directory containing the Dockerfile.

---

## 1. Multi-Stage Build

Compile in a full build environment; copy only the artifact into a minimal runtime image.
The `builder` stage is discarded — it never appears in the final image.

```dockerfile
# Stage 1: build
FROM golang:1.22-bookworm AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/app ./cmd/app

# Stage 2: runtime — distroless has no shell, package manager, or OS tools
FROM gcr.io/distroless/static-debian12

COPY --from=builder /out/app /app
ENTRYPOINT ["/app"]
```

**Why**: Final image contains only the binary. No compiler, source, or intermediate
artifacts. Reduces attack surface and image size substantially (often 10-100x smaller).

---

## 2. Non-Root User

Create a dedicated unprivileged user and switch to it before the entrypoint.

```dockerfile
FROM debian:bookworm-slim

# Create system user with no home dir, no login shell, explicit UID/GID.
# Fixed UID/GID (e.g. 1001) makes file permission mapping predictable when
# using bind mounts or when the container writes to a host-owned volume.
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --no-create-home --shell /sbin/nologin appuser

WORKDIR /app
COPY --chown=appuser:appgroup . .

USER appuser

CMD ["./myapp"]
```

**Why**: Limits blast radius if the container process is compromised. Processes inside
the container running as UID 0 map to root on the host if container breakout occurs.

---

## 3. Layer Caching Optimization

Copy dependency manifests first, install, then copy source. Docker cache is invalidated
at the first changed layer — source changes don't re-trigger dependency installs.

```dockerfile
FROM node:20-bookworm-slim

WORKDIR /app

# These two files change rarely — copy and install before anything else.
# As long as package.json and package-lock.json haven't changed, this layer
# is reused from cache even when source files change.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Source changes invalidate only from here down.
COPY . .

CMD ["node", "src/index.js"]
```

**Rule**: Order layers from least-frequently-changing to most-frequently-changing.
System packages -> dependency manifests -> dependency install -> source code.

---

## 4. Python App (uv)

```dockerfile
FROM python:3.12-slim-bookworm

# Install uv for fast dependency resolution.
# Pin the version to make builds reproducible.
COPY --from=ghcr.io/astral-sh/uv:0.4.9 /uv /usr/local/bin/uv

WORKDIR /app

# Dependency files first for cache efficiency.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Source after deps.
COPY src/ ./src/

# uv creates a .venv inside the project; activate it for the runtime.
ENV PATH="/app/.venv/bin:$PATH"

CMD ["python", "-m", "myapp"]
```

**Alternative with pip** (no uv):
```dockerfile
FROM python:3.12-slim-bookworm

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "-m", "myapp"]
```

---

## 5. Node.js App (npm ci)

```dockerfile
FROM node:20-bookworm-slim

# Set NODE_ENV before npm ci — some packages install devDependencies conditionally.
ENV NODE_ENV=production

WORKDIR /app

COPY package.json package-lock.json ./
# npm ci: clean install from lockfile; fails if lockfile is out of sync.
# --omit=dev: skip devDependencies in production.
RUN npm ci --omit=dev

COPY . .

# Run as non-root; node image includes a pre-created 'node' user (UID 1000).
USER node

EXPOSE 3000
CMD ["node", "src/server.js"]
```

---

## 6. Static Binary / Scratch Base

For statically-linked binaries (Go with CGO_ENABLED=0, Rust with musl target).
`scratch` is a zero-byte base — no OS, no shell, no libc.

```dockerfile
FROM golang:1.22-bookworm AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app ./cmd/server

# FROM scratch: literally empty. COPY is the only instruction that makes sense here.
FROM scratch

# If your app reads TLS certificates, copy the CA bundle from the builder.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the statically-linked binary.
COPY --from=builder /app /app

ENTRYPOINT ["/app"]
```

**Tradeoff**: Debugging is impossible — no shell, no tools. Use distroless instead
if you need minimal debugging capability.

---

## 7. .dockerignore Essentials

Always include a `.dockerignore`. Without it, `COPY . .` sends the entire build
context to the daemon, including secrets, large binaries, and unrelated files.

```
# Version control
.git
.gitignore

# CI/CD and editor configs
.github
.vscode
.idea
*.iml

# Dependencies (reinstalled inside the image)
node_modules/
.venv/
__pycache__/
*.pyc
*.pyo

# Build artifacts (rebuilt inside the image)
dist/
build/
target/
*.o
*.a

# Secrets and credentials — never ship these in an image
.env
.env.*
*.pem
*.key
secrets/
credentials/

# Docker files themselves (avoid recursive builds)
Dockerfile*
docker-compose*.yml
.dockerignore

# OS artifacts
.DS_Store
Thumbs.db

# Test and documentation (not needed at runtime)
tests/
docs/
*.md
```

---

## 8. HEALTHCHECK Directive

Tells Docker (and orchestrators like Swarm/Compose) whether the container is healthy.
A container can be running but unhealthy if the app inside is broken.

```dockerfile
FROM nginx:1.25-alpine

COPY site/ /usr/share/nginx/html/

# --interval: how often to run the check
# --timeout: max time for the check command to complete
# --start-period: grace period after container start before failures count
# --retries: consecutive failures before marking unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1

EXPOSE 80
```

**For apps without wget/curl**, use a minimal health endpoint checked by a script:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD ["node", "healthcheck.js"]
```

---

## 9. Build Arguments and Environment Variables

`ARG`: build-time only — not available in the running container.
`ENV`: available both at build time (after the instruction) and in the container.

```dockerfile
FROM python:3.12-slim-bookworm

# ARG: used during build to pull a specific version, set a build mode, etc.
# Provide at build time: docker build --build-arg APP_VERSION=1.2.3 .
ARG APP_VERSION=dev
ARG BUILD_DATE

# ENV: runtime configuration — these persist in the final image and running container.
# Baking secrets into ENV is a security risk — use Docker secrets or runtime injection instead.
ENV APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

# Label the image with build metadata (OCI standard labels).
LABEL org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

WORKDIR /app
COPY . .

EXPOSE ${PORT}
CMD ["python", "-m", "app"]
```

**Build command:**
```bash
docker build \
  --build-arg APP_VERSION=1.2.3 \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  -t myapp:1.2.3 .
```

**Security note**: `ARG` values before a `FROM` are not in the build history, but
`ARG` values after `FROM` appear in `docker history` — do not use for secrets.

---

## 10. Entrypoint Script Pattern

Use a shell script as the entrypoint to run initialization logic before the main process.
The final `exec "$@"` replaces the shell with the CMD process, making it PID 1
so it receives signals (SIGTERM) correctly.

```dockerfile
FROM python:3.12-slim-bookworm

WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt

# Copy and make the entrypoint executable in one layer.
COPY docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
# CMD is passed as arguments to entrypoint.sh and becomes "$@" in the script.
CMD ["python", "-m", "myapp"]
```

`docker-entrypoint.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Run any initialization: wait for DB, run migrations, create directories, etc.
echo "Running database migrations..."
python -m myapp.migrate

echo "Starting application..."
# exec replaces this shell with the CMD process.
# Without exec: PID 1 is bash; signals are not forwarded to the app.
# With exec: PID 1 is the app; SIGTERM is received and handled correctly.
exec "$@"
```

**Common mistake**: forgetting `exec`. Without it, bash catches SIGTERM but doesn't
forward it, so `docker stop` waits the full timeout (10s) before sending SIGKILL.
