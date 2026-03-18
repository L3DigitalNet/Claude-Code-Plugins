---
name: buildah
description: >
  Buildah daemonless container image building: buildah from/run/copy/commit
  workflow, Dockerfile and Containerfile builds, rootless image creation,
  multi-stage builds, OCI and Docker format support, and registry push/pull.
  MUST consult when installing, configuring, or troubleshooting buildah.
triggerPhrases:
  - "buildah"
  - "Buildah"
  - "buildah from"
  - "buildah build"
  - "buildah bud"
  - "buildah commit"
  - "buildah push"
  - "daemonless build"
  - "rootless container build"
  - "OCI image build"
  - "buildah run"
  - "buildah copy"
  - "buildah config"
  - "buildah mount"
globs:
  - "**/Containerfile"
  - "**/Containerfile.*"
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "**/.containerignore"
last_verified: "2026-03"
---

## Identity

| Field | Value |
|-------|-------|
| Binary | `buildah` |
| Config | `/etc/containers/registries.conf` (registries), `/etc/containers/storage.conf` (storage), `/etc/containers/policy.json` (signing) |
| Rootless storage | `~/.local/share/containers/storage/` |
| Root storage | `/var/lib/containers/storage/` |
| Install | `apt install buildah` / `dnf install buildah` / `pacman -S buildah` |
| Version check | `buildah --version`; current stable is v1.43.x |
| Rootless prereqs | `/etc/subuid` and `/etc/subgid` entries for user; `fuse-overlayfs` or native overlay |

## Quick Start

```bash
# Install
sudo apt install buildah

# Build from Dockerfile/Containerfile
buildah build -t myapp:latest .

# Or use the step-by-step workflow
ctr=$(buildah from alpine:3.20)
buildah run $ctr -- apk add --no-cache curl
buildah copy $ctr ./app /opt/app
buildah config --entrypoint '["/opt/app/start.sh"]' $ctr
buildah commit $ctr myapp:latest

# Push to registry
buildah push myapp:latest docker://registry.example.com/myapp:latest
```

## Key Operations

| Task | Command |
|------|---------|
| Build from Dockerfile | `buildah build -t <tag> .` or `buildah build -f Dockerfile.prod -t <tag> .` |
| Create working container | `buildah from <image>` (returns container ID) |
| Create from scratch | `buildah from scratch` |
| Run command in container | `buildah run <container> -- <command> [args]` |
| Copy files into container | `buildah copy <container> <src> <dest>` |
| Add files (with URL/tar support) | `buildah add <container> <src> <dest>` |
| Set config (entrypoint) | `buildah config --entrypoint '["<cmd>"]' <container>` |
| Set config (env var) | `buildah config --env KEY=value <container>` |
| Set config (working dir) | `buildah config --workingdir /app <container>` |
| Set config (port) | `buildah config --port 8080 <container>` |
| Set config (label) | `buildah config --label version=1.0 <container>` |
| Set config (user) | `buildah config --user appuser <container>` |
| Set config (cmd) | `buildah config --cmd '["<cmd>"]' <container>` |
| Mount container filesystem | `buildah mount <container>` (returns mount path) |
| Unmount | `buildah unmount <container>` |
| Commit to image | `buildah commit <container> <image-name>` |
| Commit (Docker format) | `buildah commit --format docker <container> <image-name>` |
| Commit (OCI format) | `buildah commit --format oci <container> <image-name>` |
| Push to registry | `buildah push <image> docker://<registry>/<repo>:<tag>` |
| Push (OCI layout) | `buildah push <image> oci:/path/to/layout:<tag>` |
| Pull image | `buildah pull <image>` |
| List images | `buildah images` |
| List working containers | `buildah containers` |
| Inspect image/container | `buildah inspect <image-or-container>` |
| Remove container | `buildah rm <container>` |
| Remove all containers | `buildah rm --all` |
| Remove image | `buildah rmi <image>` |
| Tag image | `buildah tag <image> <new-name>` |
| Login to registry | `buildah login <registry>` |
| Logout from registry | `buildah logout <registry>` |
| Prune build cache | `buildah prune` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `permission denied` running rootless | Missing subuid/subgid entries | `sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER`; verify `/etc/subuid` and `/etc/subgid` |
| `overlay: mount failed` rootless | Missing fuse-overlayfs | `sudo apt install fuse-overlayfs`; or set `driver = "vfs"` in `~/.config/containers/storage.conf` (slower) |
| `image not known` on commit | Container ID changed or was removed | `buildah containers` to list active containers; use the correct ID |
| Push auth failure | Not logged in to registry | `buildah login <registry>` first |
| `manifest unknown` on pull | Tag doesn't exist or registry unreachable | Verify tag exists; check DNS and TLS settings |
| Build cache not reused | Layer order changed or context too broad | Put rarely-changing steps first; use `.containerignore` to exclude unnecessary files |
| Multi-stage build fails | `--from` reference wrong or stage not named | Name stages with `AS builder`; reference with `COPY --from=builder` |
| `Error: error creating build container` | Storage corruption | `buildah rm --all && buildah rmi --all --force` or clear storage dir |

## Pain Points

- **Buildah does not run containers long-term.** `buildah run` executes a command inside a build container and exits; it is not a container runtime. For running containers, use Podman or Docker. Buildah creates images that any OCI-compliant runtime can execute.
- **`buildah build` replaced `buildah bud`.** The `bud` (build-using-dockerfile) subcommand still works as an alias, but `buildah build` is the current name. It reads `Containerfile` by default, falling back to `Dockerfile`.
- **OCI format is the default.** Buildah produces OCI-format images by default. Some older registries or tools expect Docker format. Use `--format docker` with `buildah commit` or `buildah build` if you need Docker v2 manifests.
- **Rootless builds have storage driver constraints.** Rootless mode uses `fuse-overlayfs` (or native overlay on kernel 5.11+). If neither works, it falls back to `vfs`, which copies entire layers and is significantly slower. Check `buildah info` to confirm the active driver.
- **Context directory matters for caching.** Like Docker, Buildah sends the build context to the builder. Large contexts slow builds and invalidate caches. Use `.containerignore` (or `.dockerignore`) to exclude `node_modules`, `.git`, build artifacts, etc.
- **Shared storage with Podman.** Buildah and Podman share the same container storage (`/var/lib/containers/storage` for root, `~/.local/share/containers/storage` for rootless). Images built with Buildah are immediately available to Podman and vice versa.

## See Also

- **docker** -- Container runtime with integrated build; Buildah is the daemonless alternative for the build step
- **podman** -- Daemonless container runtime; shares storage with Buildah and runs the images Buildah creates
- **container-registry** -- OCI registry management for storing and distributing built images

## References

See `references/` for:
- `cheatsheet.md` -- quick reference for all Buildah commands
- `docs.md` -- official documentation links
