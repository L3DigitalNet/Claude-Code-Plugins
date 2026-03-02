# Common Podman Patterns

Task-organized command recipes for the most frequent Podman workflows.

---

## 1. Run a Rootless Container (Basic Usage)

Always qualify image names with the full registry — Podman does not have a default
registry and will prompt interactively if you omit it.

```bash
# Interactive shell — removed on exit
podman run -it --rm docker.io/library/alpine sh

# Background service with port mapping and a name
podman run -d \
  --name myapp \
  -p 8080:80 \
  -e APP_ENV=production \
  docker.io/library/nginx:1.25

# Check it is running
podman ps

# Follow logs
podman logs -f myapp

# Exec into the running container
podman exec -it myapp sh

# Stop and remove
podman stop myapp && podman rm myapp
```

---

## 2. Rootless Persistent Container with systemd (Quadlet)

The preferred approach for containers that should survive reboots. Uses Quadlet
rather than the deprecated `podman generate systemd`.

```bash
# Create the Quadlet unit directory (rootless)
mkdir -p ~/.config/containers/systemd/

# Write the unit file
cat > ~/.config/containers/systemd/myapp.container << 'EOF'
[Unit]
Description=My App
After=network-online.target

[Container]
Image=docker.io/library/nginx:1.25
PublishPort=8080:80
Volume=myapp-data.volume:/usr/share/nginx/html:z
Environment=NGINX_HOST=example.com
Label=io.containers.autoupdate=registry

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Write the volume unit (optional — Podman auto-creates if omitted)
cat > ~/.config/containers/systemd/myapp-data.volume << 'EOF'
[Volume]
Label=app=myapp
EOF

# Reload and start
systemctl --user daemon-reload
systemctl --user enable --now myapp.service
systemctl --user status myapp.service
```

Enable lingering so the service starts at boot without login:
```bash
loginctl enable-linger $USER
```

---

## 3. Podman Pod (Multiple Containers Sharing Network Namespace)

A pod groups containers so they share `localhost`. Useful for tightly coupled
services (e.g., app + sidecar, app + database on the same host).

```bash
# Create a pod with a published port
podman pod create --name webapp -p 8080:80

# Run an nginx container inside the pod (ports already published on pod)
podman run -d --name webapp-nginx --pod webapp docker.io/library/nginx:1.25

# Run a companion container (same pod = same localhost)
podman run -d --name webapp-exporter --pod webapp \
  docker.io/prom/nginx-prometheus-exporter:latest \
  -nginx.scrape-uri http://localhost/stub_status

# Inspect the pod
podman pod inspect webapp

# Stop and remove the entire pod (stops all containers inside)
podman pod stop webapp && podman pod rm webapp
```

---

## 4. Docker Compose Migration (podman compose)

Podman 4.7+ ships `podman compose` as a built-in subcommand. Older versions
require `pip install podman-compose`.

```bash
# Check if built-in compose is available
podman compose version

# If not available, install podman-compose
pip install --user podman-compose

# Run a Compose file (same syntax as docker compose)
podman compose up -d
podman compose logs -f
podman compose down

# Override the compose file
podman compose -f docker-compose.yml -f docker-compose.override.yml up -d
```

Key differences from Docker Compose:
- `podman compose` translates Compose services to individual `podman run` commands.
- Networking between services works via a shared Podman network (same as Docker bridge).
- Rootless: port < 1024 in `ports:` mapping will fail — map to a port >= 1024 on the host side.

---

## 5. Build and Push to Registry

Podman uses `Containerfile` by convention (fully compatible with `Dockerfile` syntax).

```bash
# Build from Containerfile in the current directory
podman build -t myapp:latest .

# Build from a specific file
podman build -f Containerfile.production -t myapp:prod .

# Tag for a registry
podman tag myapp:latest registry.example.com/myteam/myapp:1.0.0

# Log in to the registry
podman login registry.example.com

# Push
podman push registry.example.com/myteam/myapp:1.0.0

# Push to Docker Hub
podman login docker.io
podman tag myapp:latest docker.io/myuser/myapp:1.0.0
podman push docker.io/myuser/myapp:1.0.0

# Build and push in one pipeline (buildah under the hood)
podman build -t registry.example.com/myteam/myapp:latest . && \
  podman push registry.example.com/myteam/myapp:latest
```

---

## 6. Volume Management

Named volumes are managed by Podman and stored under the container storage path.
Bind mounts reference a host path directly.

```bash
# Create a named volume
podman volume create mydata

# List volumes
podman volume ls

# Inspect a volume (shows the mount point on the host)
podman volume inspect mydata

# Use a named volume in a container
podman run -d --name db \
  -v mydata:/var/lib/postgresql/data \
  docker.io/library/postgres:16

# Use a bind mount (host path must exist)
podman run -d --name app \
  -v /home/user/config:/app/config:ro \
  myapp:latest

# Remove a volume (only works if no container is using it)
podman volume rm mydata

# Remove all unused volumes
podman volume prune
```

---

## 7. SELinux Volume Labels (`:z` vs `:Z`)

Required on SELinux-enforcing systems (RHEL, Fedora, CentOS Stream). Without
these labels the container process is denied access to the bind-mounted path.

```bash
# :z — shared label (multiple containers can read/write the same path)
podman run -d -v /data/shared:/app/data:z myapp:latest

# :Z — private label (single container exclusive access; relabels the host path)
podman run -d -v /data/private:/app/data:Z myapp:latest
```

**Which to use:**
- Use `:z` when multiple containers need the same host directory.
- Use `:Z` when only one container should access the directory.
- Named volumes do not need `:z`/`:Z` — Podman manages their labels automatically.
- Never use `:Z` on home directories or system paths — it relabels the host directory,
  which can break other processes accessing the same path.

---

## 8. Rootless Port Binding Workaround

Ports below 1024 require privileges by default. Three options:

```bash
# Option 1: Map to an unprivileged port on the host, use a reverse proxy
podman run -d --name web -p 8080:80 nginx
# Then route 80 -> 8080 via nginx/caddy/traefik on the host

# Option 2: Lower the unprivileged port start (persist in sysctl.conf)
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-podman-ports.conf
sudo sysctl --system

# Option 3: Use CAP_NET_BIND_SERVICE (root-mode containers only)
# Not applicable to rootless
```

---

## 9. Network Creation and Container Networking

```bash
# Create an isolated network
podman network create mynet

# Inspect the network
podman network inspect mynet

# Run containers attached to the network
podman run -d --name db --network mynet \
  -e POSTGRES_PASSWORD=secret \
  docker.io/library/postgres:16

podman run -d --name app --network mynet \
  -e DATABASE_URL=postgres://postgres:secret@db/appdb \
  myapp:latest

# Containers on the same network resolve each other by name (DNS via aardvark-dns)
podman exec app ping db

# Connect a running container to an additional network
podman network connect mynet existingcontainer

# Disconnect
podman network disconnect mynet existingcontainer

# Remove network (only if no containers are attached)
podman network rm mynet
```

---

## 10. Comparing with Docker (Same CLI, Key Differences)

Most `docker` commands map 1:1 to `podman`. The following differences matter in practice:

| Aspect | Docker | Podman |
|--------|--------|--------|
| Daemon | `dockerd` required | No daemon — each command is standalone |
| Default rootless | No (requires setup) | Yes (user install) |
| Default storage | `/var/lib/docker/` | `~/.local/share/containers/` (rootless) |
| Systemd integration | `--restart=always` + service | Quadlet `.container` units |
| Image registry default | `docker.io` (implicit) | No default — must qualify (`docker.io/library/`) |
| `docker compose` | Built-in | `podman compose` (4.7+) or `podman-compose` |
| Socket location | `/var/run/docker.sock` | Not exposed by default; `podman.socket` on request |
| Security model | docker group = root | Each user owns their containers |
| Build tool | Docker BuildKit | Buildah (integrated into `podman build`) |

Drop-in alias (use with caution — some edge cases differ):
```bash
alias docker=podman
```
