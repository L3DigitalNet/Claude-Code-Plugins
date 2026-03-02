---
name: podman
description: >
  Podman container runtime — rootless containers, daemonless architecture, Quadlet
  systemd integration, pod management, image building, networking, volumes, and
  Docker compatibility.
  Triggers on: podman, Podman, rootless container, podman-compose, podman pod,
  podman systemd, quadlet, podman vs docker, Containerfile, podman generate systemd,
  podman play kube, slirp4netns, pasta networking, podman auto-update.
globs:
  - "*.containerfile"
  - "**/Containerfile"
  - "**/Containerfile.*"
  - "**/quadlet/**/*.container"
  - "**/quadlet/**/*.volume"
  - "**/quadlet/**/*.network"
  - "**/quadlet/**/*.pod"
  - "**/.containerignore"
---

## Identity

- **Binary**: `podman` (no daemon — each invocation is a standalone process)
- **Storage (rootless)**: `~/.local/share/containers/storage/`
- **Storage (root)**: `/var/lib/containers/storage/`
- **Config**: `/etc/containers/` (system), `~/.config/containers/` (user overrides)
- **Registries config**: `/etc/containers/registries.conf`
- **Policy config**: `/etc/containers/policy.json`
- **Quadlet units (rootless)**: `~/.config/containers/systemd/`
- **Quadlet units (root)**: `/etc/containers/systemd/`
- **No socket required**: no `/var/run/docker.sock` equivalent by default
- **Install**: `dnf install podman` (Fedora/RHEL), `apt install podman` (Debian/Ubuntu 20.10+)

## Key Operations

| Task | Command |
|------|---------|
| Run a container | `podman run -it --rm docker.io/library/alpine sh` |
| Run detached | `podman run -d --name myapp -p 8080:80 nginx` |
| Pull an image | `podman pull docker.io/library/nginx:latest` |
| List images | `podman images` |
| List running containers | `podman ps` |
| List all containers | `podman ps -a` |
| Exec into container | `podman exec -it myapp bash` |
| Container logs | `podman logs myapp` / `podman logs -f myapp` |
| Stop container | `podman stop myapp` |
| Remove container | `podman rm myapp` |
| Stop and remove | `podman rm -f myapp` |
| Build image | `podman build -t myapp:latest .` |
| Build from Containerfile | `podman build -f Containerfile -t myapp .` |
| Tag image | `podman tag myapp:latest registry.example.com/myapp:1.0` |
| Push to registry | `podman push registry.example.com/myapp:1.0` |
| Create a pod | `podman pod create --name mypod -p 8080:80` |
| List pods | `podman pod ps` |
| List networks | `podman network ls` |
| List volumes | `podman volume ls` |
| Generate systemd unit (legacy) | `podman generate systemd --new --name myapp` |
| Play Kubernetes YAML | `podman play kube pod.yaml` |
| Inspect container | `podman inspect myapp` |
| Inspect healthcheck status | `podman healthcheck run myapp` |
| Rootless network info | `podman info --format '{{.Host.NetworkBackend}}'` |
| System info | `podman info` |
| System prune | `podman system prune -a` |
| Auto-update (registry label) | `podman auto-update` |

## Expected State

- No daemon process: `systemctl is-active podman` will show inactive or not found — this is normal.
- Containers are per-user: root containers are invisible to user sessions and vice versa.
- `podman info` shows storage driver, network backend (netavark or slirp4netns), and OS info.
- Rootless: containers run under the invoking user's UID; UIDs inside the container are mapped via `/etc/subuid` and `/etc/subgid`.

## Health Checks

1. `podman info` — no errors; shows version, storage, and network backend
2. `podman run --rm docker.io/library/hello-world` — pulls and exits 0
3. `podman ps` — no permission errors; shows per-user container list

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `permission denied` on `/dev/net/tun` | Rootless networking kernel module not loaded or device not available | `modprobe tun`; check `ls -la /dev/net/tun` |
| Volume mount fails with SELinux AVC denial | SELinux label mismatch — container cannot read host path | Add `:z` (shared) or `:Z` (private) to the volume flag: `-v /host/path:/container/path:z` |
| `cannot connect to Docker daemon` | Wrong client — using `docker` CLI against a Podman socket, or no socket exposed | Use `podman` CLI; or start `podman.socket` for Docker-compatible socket |
| Container fails to start on cgroup v1 | Rootless Podman requires cgroup v2 for full functionality | Check `cat /sys/fs/cgroup/cgroup.controllers`; enable cgroup v2 in bootloader or upgrade kernel |
| `listen tcp :80: bind: permission denied` | Rootless containers cannot bind ports < 1024 by default | Use a port >= 1024, or set `net.ipv4.ip_unprivileged_port_start=80` via sysctl |
| Image pull fails with `unauthorized` | Registry authentication required | `podman login registry.example.com` then retry pull |
| Pod networking conflict | Two pods sharing the same published port | Check `podman pod ps` and `podman ps`; stop conflicting pod first |
| `slirp4netns` not found | Network backend missing | `dnf install slirp4netns` or use `pasta` backend (Podman 4.4+) |
| Rootless user not in `/etc/subuid` | UID mapping not configured | `usermod --add-subuids 100000-165535 --add-subgids 100000-165535 <user>` |

## Pain Points

- **Rootless networking is slower**: Rootless containers use `slirp4netns` (userspace TCP/IP stack) or `pasta` (Podman 4.4+, faster). Neither approach reaches the performance of root-mode with netavark. For high-throughput services, run as root or use `--network=host`.
- **No shared daemon means no cross-session visibility**: Containers started as one user are invisible to `podman ps` run as another user (including root). There is no central registry of running containers — this is by design for isolation.
- **`podman generate systemd` is deprecated**: Since Podman 4.4, Quadlet is the recommended way to manage containers as systemd units. `generate systemd` still works but produces units that embed container config into ExecStart flags rather than declarative unit files.
- **SELinux `:z`/`:Z` volume labels are required on SELinux-enforcing systems**: Without these labels, the container process is denied access to bind-mounted host directories. `:z` makes the label shared (multiple containers can read); `:Z` makes it private (single container).
- **Docker Compose compatibility via `podman compose`**: Podman 4.7+ ships `podman compose` as a built-in subcommand backed by `podman-compose`. Older versions require `pip install podman-compose` separately. Not all Docker Compose v3 features are supported.
- **UID mapping in rootless requires `/etc/subuid` and `/etc/subgid`**: If these files don't have an entry for the user, rootless containers fail at startup. Entries are added automatically on most distros when a new user is created, but may be missing on older systems or custom installs.
- **Quadlets vs `generate systemd`**: Quadlets are declarative `.container`/`.volume`/`.network`/`.pod` files processed by `systemd-generator` at boot; `generate systemd` produces imperative unit files that call `podman run` in `ExecStart`. Quadlets are easier to maintain, version-control, and update — prefer them for any new setup.

## References

See `references/` for:
- `quadlet-patterns.md` — Quadlet unit file syntax, `.container`/`.volume`/`.network`/`.pod` examples, auto-update
- `common-patterns.md` — Task-oriented command recipes for the most frequent Podman workflows
- `docs.md` — Official documentation, man pages, and community links
