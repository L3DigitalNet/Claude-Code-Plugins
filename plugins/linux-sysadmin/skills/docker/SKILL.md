---
name: docker
description: >
  Docker container runtime — installation, daemon config, container lifecycle,
  networking, volumes, image management, troubleshooting, and security.
  Triggers on: docker, container, dockerfile, docker run, docker ps, container
  runtime, docker daemon, dockerd, docker-compose, OCI, container image,
  registry, docker pull, docker build, docker exec, docker logs.
globs:
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "**/.dockerignore"
  - "**/daemon.json"
---

## Identity
- **Unit**: `docker.service` (and `docker.socket`)
- **Config**: `/etc/docker/daemon.json`
- **Logs**: `journalctl -u docker`, `docker logs <container>`
- **Data root**: `/var/lib/docker/` (images, containers, volumes)
- **Socket**: `/var/run/docker.sock` (root access — treat as root equivalent)
- **Install**: `apt install docker.io` (distro pkg) or official: `curl -fsSL https://get.docker.com | sh`

## Key Operations
- **List containers**: `docker ps` (running), `docker ps -a` (all)
- **Container logs**: `docker logs <name>` / `docker logs -f <name>` (follow)
- **Exec into container**: `docker exec -it <name> bash` (or `sh` if no bash)
- **Inspect**: `docker inspect <name>` (full JSON config)
- **Stats**: `docker stats` (live resource usage)
- **Validate daemon config**: `dockerd --validate` (or check `journalctl -u docker` after `systemctl restart docker`)
- **Prune unused**: `docker system prune -a` (images, stopped containers, networks, build cache)
- **Disk usage**: `docker system df`

## Expected Ports
- Docker itself: no default listening ports (Unix socket by default)
- TCP socket (if enabled): 2375/tcp (unencrypted) or 2376/tcp (TLS) — avoid 2375 on production
- Container ports: vary; check `docker ps` PORTS column or `docker inspect`

## Health Checks
1. `systemctl is-active docker` → `active`
2. `docker info` → no errors, shows server version
3. `docker run --rm hello-world` → pulls and runs successfully
4. `docker ps` → no permission denied

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `permission denied on /var/run/docker.sock` | User not in docker group | `sudo usermod -aG docker $USER` then log out/in |
| Container exits immediately | Process exits (not a daemon issue) | `docker logs <name>` to see exit reason |
| `port is already allocated` | Host port bound by another process | `ss -tlnp \| grep <port>` to find conflict |
| Image pull fails | DNS or network issue inside Docker | Check `docker info` for DNS; try `docker pull` manually |
| `no space left on device` | Docker data root full | `docker system prune`; check `/var/lib/docker` size |
| Container can't reach host | Docker network isolation | Use `host.docker.internal` (Docker Desktop) or `172.17.0.1` (bridge gateway) |
| `OCI runtime exec failed` | Binary not found in container | Container doesn't have the binary; use `docker exec ... sh` |

## Pain Points
- **The docker group = root access**: Adding a user to the `docker` group grants effective root on the host via socket. Use rootless Docker for untrusted users.
- **`docker restart` vs `docker stop` + `docker start`**: `restart` sends SIGTERM then SIGKILL; useful for hung containers.
- **Image layers and cache**: Dockerfile order matters for cache efficiency. Put rarely-changing layers first (system deps), frequently-changing last (app code).
- **Volumes vs bind mounts**: Named volumes (`docker volume create`) are managed by Docker and portable. Bind mounts (`-v /host/path:/container/path`) depend on host filesystem.
- **`docker exec` runs in the container's namespace**: Network, filesystem, processes — but NOT the container's entrypoint environment.
- **Signals**: Docker sends SIGTERM to PID 1. If PID 1 doesn't handle it, container won't stop gracefully. Use `exec` form in Dockerfile CMD/ENTRYPOINT (not shell form).
- **`--rm` flag**: Automatically removes container on exit. Use for one-off tasks; don't use for long-running containers you need to inspect after failure.

## References
See `references/` for:
- `daemon.json.annotated` — every Docker daemon config option explained
- `dockerfile-patterns.md` — multi-stage builds, layer caching, security patterns, common base images
- `docs.md` — official documentation links
