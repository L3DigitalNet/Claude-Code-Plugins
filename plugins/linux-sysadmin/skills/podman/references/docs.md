# Podman Documentation

## Official

- Main site: https://podman.io/
- Getting started: https://podman.io/get-started
- Installation: https://podman.io/docs/installation
- Podman documentation hub: https://docs.podman.io/en/latest/

## Man Pages

- `man podman` — top-level command reference
- `man podman-run` — `podman run` flags in detail
- `man podman-build` — build flags and Containerfile notes
- `man podman-generate-systemd` — legacy unit generation (deprecated in favor of Quadlet)
- `man podman-pod` — pod subcommands
- `man podman-network` — network management
- `man podman-volume` — volume management
- `man podman-auto-update` — registry-based auto-update

## Quadlet

- Quadlet man pages: `man podman-systemd.unit` — complete `.container`/`.volume`/`.network`/`.pod` directive reference
- Quadlet introduction (Red Hat blog): https://www.redhat.com/en/blog/quadlet-podman
- Quadlet reference in docs: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html

## Rootless Containers

- Rootless tutorial: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
- User namespace and UID mapping: https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode
- `/etc/subuid` and `/etc/subgid` configuration: `man subuid`, `man subgid`

## Networking

- Networking overview: https://docs.podman.io/en/latest/markdown/podman-network.1.html
- Pasta (new default backend): https://passt.top/
- slirp4netns (legacy rootless backend): https://github.com/rootless-containers/slirp4netns
- Netavark (root-mode backend): https://github.com/containers/netavark

## Docker Compatibility

- podman-compose (third-party): https://github.com/containers/podman-compose
- Docker CLI compatibility notes: https://docs.podman.io/en/latest/markdown/podman.1.html#docker-compatibility

## Podman Desktop

- GUI for Podman on macOS/Windows/Linux: https://podman-desktop.io/

## Red Hat Container Guides

- Container security guide: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/
- Podman in RHEL 9: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/index

## Source and Issues

- Podman GitHub: https://github.com/containers/podman
- containers/common (shared config): https://github.com/containers/common
- containers/image (registry/transport): https://github.com/containers/image
