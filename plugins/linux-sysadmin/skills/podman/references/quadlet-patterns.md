# Quadlet Patterns

Quadlets are the modern way to run Podman containers as systemd services. Instead of
running `podman generate systemd` and saving the output, you write a declarative unit
file and systemd processes it automatically via a generator at boot (or on
`systemctl --user daemon-reload`).

Quadlet replaced `podman generate systemd` as the recommended approach in Podman 4.4.

---

## Where Files Go

| Scope | Directory |
|-------|-----------|
| Rootless (user) | `~/.config/containers/systemd/` |
| System (root) | `/etc/containers/systemd/` |
| System drop-in | `/usr/share/containers/systemd/` |

After placing or editing a file, reload the generator:

```bash
# Rootless
systemctl --user daemon-reload

# Root
systemctl daemon-reload
```

Quadlet generates a corresponding `.service` file in the systemd runtime directory.
The generated service is named after the `.container` file:
`myapp.container` → `myapp.service`.

---

## Basic `.container` Unit

A complete example showing the most useful directives.

```ini
# ~/.config/containers/systemd/myapp.container
[Unit]
Description=My Application Container
After=network-online.target
Wants=network-online.target

[Container]
# Full image reference — always qualify with registry to avoid ambiguity.
Image=docker.io/library/nginx:1.25

# Exec overrides the image's default CMD (optional).
# Exec=/usr/sbin/nginx -g "daemon off;"

# Named volumes (must be declared in a .volume unit or already exist).
Volume=myapp-data.volume:/var/lib/myapp:z

# Bind mount — :z applies the shared SELinux label on SELinux systems.
# Volume=/host/path:/container/path:z

# Network to attach to (must match a .network unit or existing network name).
Network=myapp-net.network

# Environment variables.
Environment=APP_ENV=production
Environment=LOG_LEVEL=info

# Environment file on the host (one KEY=value per line).
# EnvironmentFile=/etc/myapp/env

# Publish host-port:container-port.
PublishPort=8080:80

# OCI labels — io.containers.autoupdate enables registry-based auto-update.
Label=io.containers.autoupdate=registry
Label=app=myapp

# Run as a specific UID inside the container.
# User=1000

# Drop capabilities for a more restricted container.
# AddCapability=NET_BIND_SERVICE
# DropCapability=ALL

[Service]
# Restart on failure; use 'always' for production services.
Restart=on-failure
TimeoutStartSec=30

[Install]
# For rootless: WantedBy=default.target
# For root: WantedBy=multi-user.target
WantedBy=default.target
```

Enable and start:

```bash
systemctl --user enable --now myapp.service
systemctl --user status myapp.service
```

---

## `.volume` Unit

Declares a named volume managed by Podman. The volume is created before any
container that references it starts.

```ini
# ~/.config/containers/systemd/myapp-data.volume
[Volume]
# Label the volume for identification.
Label=app=myapp

# Optional: set ownership inside the volume (useful for rootless UID mapping).
# User=1000
# Group=1000
```

Volumes created by Quadlet are named `<unitfile-stem>` — so `myapp-data.volume`
creates a volume named `myapp-data`. Reference it from `.container` units as
`Volume=myapp-data.volume:/path`.

---

## `.network` Unit

Declares a Podman network. Containers in the same network can reach each other
by container name.

```ini
# ~/.config/containers/systemd/myapp-net.network
[Network]
# Subnet is optional — Podman assigns one automatically if omitted.
Subnet=10.89.1.0/24
Gateway=10.89.1.1

# DNS enables container-name resolution within the network.
DNS=10.89.1.1

Label=app=myapp
```

Reference from a `.container` unit as `Network=myapp-net.network`.

---

## `.pod` Unit

Groups multiple containers in a shared network namespace (like a Kubernetes Pod).
All containers in the pod share `localhost` — they communicate via `127.0.0.1`.
Port publishing is declared on the pod, not on individual containers.

```ini
# ~/.config/containers/systemd/mypod.pod
[Pod]
# Ports published on the pod's infra container.
PublishPort=8080:80
PublishPort=8443:443

Network=myapp-net.network
```

Containers join the pod by adding `Pod=mypod.pod` to their `.container` unit:

```ini
[Container]
Image=docker.io/library/nginx:1.25
Pod=mypod.pod
# Do NOT publish ports on pod containers — publish on the .pod unit instead.
```

---

## Auto-Update

Podman can pull new image versions and restart containers automatically.

**Step 1**: Add the label to the `.container` unit:
```ini
[Container]
Label=io.containers.autoupdate=registry
```

**Step 2**: Enable the systemd timer that drives updates:
```bash
# Rootless
systemctl --user enable --now podman-auto-update.timer

# Root
systemctl enable --now podman-auto-update.timer
```

**Manual trigger**:
```bash
podman auto-update
```

The `registry` policy pulls the image tagged in the unit file and restarts the
container only if the digest changed. Use `local` policy to update from a locally
rebuilt image instead of a registry.

---

## Running as Root vs Rootless

| Aspect | Rootless | Root |
|--------|----------|------|
| Unit directory | `~/.config/containers/systemd/` | `/etc/containers/systemd/` |
| Systemctl scope | `systemctl --user` | `systemctl` |
| Runs at login | Only while user session is active (unless lingering enabled) | Always |
| Enable lingering | `loginctl enable-linger <user>` | N/A |
| Port < 1024 | Not allowed by default | Allowed |
| Storage | `~/.local/share/containers/` | `/var/lib/containers/` |

Enable lingering so rootless services start at boot without a user login:

```bash
loginctl enable-linger $USER
```
