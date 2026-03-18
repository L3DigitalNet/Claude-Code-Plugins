---
name: lxc-lxd
description: >
  LXC/LXD system container administration: launching and managing containers,
  resource limits, profiles, snapshots, networking, storage pools, and
  troubleshooting. Also covers Incus (community fork of LXD).
  MUST consult when installing, configuring, or troubleshooting LXC/LXD containers.
triggerPhrases:
  - "LXC"
  - "LXD"
  - "lxc container"
  - "lxd container"
  - "system container"
  - "lxc-ls"
  - "incus"
  - "lxc launch"
  - "lxc exec"
  - "lxc snapshot"
  - "lxc profile"
  - "lxc storage"
  - "lxc network"
  - "lxc config"
  - "lxd init"
globs: []
last_verified: "unverified"
---

## Identity

- **LXC**: low-level Linux container tooling (cgroups + namespaces + bind mounts); CLI is `lxc-*` (lxc-start, lxc-ls, etc.)
- **LXD**: higher-level daemon on top of LXC; exposes a REST API; CLI is `lxc` (confusingly named); managed via `lxd` service
- **Incus**: community fork of LXD after Canonical relicensed LXD to proprietary-friendly CLA in 2023; API-compatible, same `lxc` CLI shape but binary is `incus`
- **Daemon**: `lxd.service` (or `incus.service` for Incus); snap-packaged LXD uses `snap.lxd.daemon`
- **CLI**: `lxc` for LXD; `incus` for Incus; `lxc-*` utilities for bare LXC
- **Storage root** (snap LXD): `/var/snap/lxd/common/lxd/`; (deb LXD): `/var/lib/lxd/`; (Incus): `/var/lib/incus/`
- **Unix socket** (snap LXD): `/var/snap/lxd/common/lxd/unix.socket`; (deb/Incus): `/var/lib/lxd/unix.socket` or `/run/incus/unix.socket`
- **Config**: runtime config via `lxc config set`; profiles in daemon database; no flat config files to edit
- **Install**: `snap install lxd` (Ubuntu recommended), `apt install lxd` (deb), or `apt install incus` for Incus

## Quick Start

```bash
sudo snap install lxd
sudo lxd init --auto
lxc launch ubuntu:24.04 mycontainer
lxc exec mycontainer -- bash
lxc list
```

## Key Operations

| Task | Command |
|------|---------|
| Initialize LXD (first-time wizard) | `lxd init` |
| Launch container from image | `lxc launch ubuntu:24.04 mycontainer` |
| Launch with specific profile | `lxc launch ubuntu:24.04 mycontainer --profile default --profile custom` |
| List all containers | `lxc list` |
| List containers (compact) | `lxc ls` |
| Get shell in container | `lxc exec mycontainer -- bash` |
| Run single command | `lxc exec mycontainer -- apt update` |
| Start container | `lxc start mycontainer` |
| Stop container (graceful) | `lxc stop mycontainer` |
| Stop container (force) | `lxc stop mycontainer --force` |
| Restart container | `lxc restart mycontainer` |
| Delete container | `lxc delete mycontainer` |
| Delete running container | `lxc delete mycontainer --force` |
| Copy container | `lxc copy mycontainer newcontainer` |
| Rename container | `lxc rename mycontainer newname` |
| Show container info | `lxc info mycontainer` |
| Show full config | `lxc config show mycontainer` |
| Set CPU limit (core count) | `lxc config set mycontainer limits.cpu 2` |
| Set memory limit | `lxc config set mycontainer limits.memory 512MB` |
| Set disk limit (root device) | `lxc config device set mycontainer root size 20GB` |
| List profiles | `lxc profile list` |
| Show profile | `lxc profile show default` |
| Create profile | `lxc profile create myprofile` |
| Edit profile (opens $EDITOR) | `lxc profile edit myprofile` |
| Assign profile to container | `lxc profile assign mycontainer default,myprofile` |
| List networks | `lxc network list` |
| Show network info | `lxc network info lxdbr0` |
| List storage pools | `lxc storage list` |
| Show storage pool | `lxc storage show default` |
| List available images | `lxc image list images:` |
| Search images | `lxc image list images: ubuntu` |
| Take snapshot | `lxc snapshot mycontainer snap0` |
| List snapshots | `lxc info mycontainer \| grep -A20 Snapshots` |
| Restore snapshot | `lxc restore mycontainer snap0` |
| Delete snapshot | `lxc delete mycontainer/snap0` |
| Push file into container | `lxc file push /local/path mycontainer/remote/path` |
| Pull file from container | `lxc file pull mycontainer/remote/path /local/path` |
| Export container to tarball | `lxc export mycontainer mycontainer.tar.gz` |
| Import container from tarball | `lxc import mycontainer.tar.gz` |
| List remotes (image servers) | `lxc remote list` |
| Add remote | `lxc remote add myremote https://host:8443` |
| Show LXD server info | `lxc info` |

## Expected Paths / Sockets

- Snap LXD socket: `/var/snap/lxd/common/lxd/unix.socket`
- Deb LXD socket: `/var/lib/lxd/unix.socket`
- Incus socket: `/run/incus/unix.socket`
- Verify socket: `ls -la /var/snap/lxd/common/lxd/unix.socket`
- Check group membership (required for non-root): `groups $USER` — must include `lxd` (or `incus`)

## Health Checks

1. `lxc info 2>&1 | head -5` — daemon responds and shows server config
2. `lxc list` — returns table without errors (verifies auth + storage backend)
3. `lxc launch ubuntu:24.04 test-$(date +%s) && lxc delete test-* --force` — end-to-end launch/delete

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Error: not found` on container ops | Container name typo or wrong remote | `lxc list` to verify name; check `lxc remote get-default` |
| `Error: Failed to connect to LXD` | Daemon not running or wrong socket | `systemctl status snap.lxd.daemon` or `snap start lxd`; check user is in `lxd` group |
| Container starts but no network | No network profile or bridge not up | `lxc profile show default` — verify `eth0` device; `ip link show lxdbr0` |
| `Failed to get idle address` | DHCP range exhausted or `dnsmasq` crashed | `lxc network info lxdbr0`; restart network: `lxc network set lxdbr0 ipv4.dhcp.ranges` |
| Storage pool full | Pool size limit or underlying disk full | `lxc storage info default`; `df -h /var/snap/lxd/common/lxd/` |
| AppArmor denial in container logs | AppArmor profile too restrictive | `dmesg | grep apparmor`; set `security.privileged=true` or add `raw.apparmor` overrides |
| IPv6 connectivity fails inside container | Kernel IPv6 forwarding disabled on host | `sysctl net.ipv6.conf.all.forwarding` — must be `1`; set permanently in `/etc/sysctl.d/` |
| Nested containers fail to start | Missing security flags | `lxc config set mycontainer security.nesting true`; may also need `security.privileged true` |
| File push fails with permission error | UID/GID mismatch between host and container | Use `--uid`/`--gid` flags; or `lxc exec` to fix ownership inside container |
| `lxc` command not found after snap install | Snap bin path not in PATH | `export PATH=$PATH:/snap/bin` or open a new shell |
| `lxd init` hangs or fails | Existing partial config | `lxd init --preseed` with YAML input; check `lxd sql global .dump` for state |

## Pain Points

- **LXD to Incus migration**: In 2023 Canonical moved LXD under Canonical-only CLA; the Linux Containers project forked it as Incus. New installs on non-Ubuntu systems should prefer Incus. Ubuntu 24.04+ ships `incus` as an alternative. The `incus migrate` tool migrates a running LXD installation.
- **Snap-packaged LXD has different paths**: The snap isolates everything under `/var/snap/lxd/`; standard paths like `/var/lib/lxd/` do not exist. Many docs assume deb install. Always check which packaging is in use with `snap list lxd`.
- **Profile inheritance is additive, not overriding**: Multiple profiles merge; a device defined in `default` is inherited unless explicitly removed. Assigning a new profile does not remove `default` unless you explicitly drop it.
- **UID/GID mapping for file permissions**: Unprivileged containers remap UIDs (container root = host UID 100000). Files pushed from the host appear with wrong ownership inside. Use `lxc file push --uid 0 --gid 0` or fix inside the container after push.
- **Limits not enforced without cgroups v2**: `limits.cpu` and `limits.memory` require the host kernel to have cgroups v2 unified hierarchy enabled. Check `mount | grep cgroup2`. On older distros with cgroups v1 hybrid, some limits silently have no effect.
- **Privileged vs unprivileged containers**: Unprivileged (default) maps UIDs and cannot access some kernel features. Privileged (`security.privileged=true`) runs as real root — necessary for Docker-in-LXC or some legacy workloads, but host kernel vulnerabilities directly affect the container. Prefer unprivileged; escalate only when required and document why.

## See Also

- **proxmox** — Full virtualization platform with built-in LXC container support; use when you need a management UI or mixed VM/container clusters
- **docker** — Application-level containers for microservices; use alongside LXC/LXD when you need OCI image workflows rather than full OS containers
- **podman** — Rootless OCI container runtime; lighter alternative to Docker for single-application containers

## References

See `references/` for:
- `common-patterns.md` — setup, resource limits, profiles, snapshots, file transfer, networking, Docker-in-LXC, and export/import examples
- `docs.md` — official documentation links
