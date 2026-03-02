# LXC/LXD Common Patterns

## 1. Initial Setup

```bash
# Install LXD via snap (Ubuntu/Debian)
sudo snap install lxd

# Add current user to lxd group (re-login required)
sudo usermod -aG lxd $USER
newgrp lxd

# Run the setup wizard (interactive)
lxd init

# Or use preseed for scripted/automated setup
cat <<EOF | lxd init --preseed
config: {}
networks:
- config:
    ipv4.address: 10.100.0.1/24
    ipv4.nat: "true"
    ipv6.address: none
  name: lxdbr0
  type: bridge
storage_pools:
- config:
    size: 50GB
  driver: zfs
  name: default
profiles:
- config: {}
  description: Default LXD profile
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
EOF

# Verify setup
lxc info
lxc network list
lxc storage list
```

## 2. Launch and Configure a Container

```bash
# List available Ubuntu images
lxc image list ubuntu:

# Launch Ubuntu 24.04 container
lxc launch ubuntu:24.04 web01

# Launch with a specific image alias from linuxcontainers.org
lxc launch images:debian/12 db01

# Launch with cloud-init user-data
lxc launch ubuntu:24.04 web01 --config=user.user-data="$(cat cloud-init.yaml)"

# Get an interactive shell
lxc exec web01 -- bash

# Run a command non-interactively
lxc exec web01 -- apt-get update -y

# View container state and IP addresses
lxc info web01

# View full container configuration
lxc config show web01

# View container logs (console output)
lxc console web01 --show-log
```

## 3. Set Resource Limits

```bash
# Limit to 2 CPU cores
lxc config set web01 limits.cpu 2

# Pin to specific CPU cores (cores 0 and 1)
lxc config set web01 limits.cpu.allowance "0-1"

# Set memory limit (hard limit)
lxc config set web01 limits.memory 1GB

# Enable memory swap limit (equal to memory limit by default)
lxc config set web01 limits.memory.swap false

# Set disk quota on root device
lxc config device set web01 root size 20GB

# Add a separate disk device with its own quota
lxc config device add web01 data disk pool=default path=/data size=10GB

# Verify limits are applied
lxc config show web01 | grep limits

# Check actual resource usage
lxc info web01 | grep -A10 Resources
```

## 4. Profile Creation and Assignment

```bash
# List existing profiles
lxc profile list

# Create a new profile
lxc profile create web-server

# Edit profile (opens $EDITOR — YAML format)
lxc profile edit web-server

# Example profile content (paste or edit in place):
cat <<EOF | lxc profile edit web-server
config:
  limits.cpu: "2"
  limits.memory: 2GB
description: Web server profile with port forwarding
devices:
  eth0:
    name: eth0
    network: lxdbr0
    type: nic
  http:
    connect: tcp:127.0.0.1:80
    listen: tcp:0.0.0.0:8080
    type: proxy
  https:
    connect: tcp:127.0.0.1:443
    listen: tcp:0.0.0.0:8443
    type: proxy
  root:
    path: /
    pool: default
    size: 20GB
    type: disk
EOF

# Assign profile to a container (replaces all current profiles)
lxc profile assign web01 default,web-server

# Add a profile without replacing existing ones
lxc profile add web01 web-server

# Remove a single profile
lxc profile remove web01 web-server

# Copy profile from one container to another
lxc profile assign web02 "$(lxc config show web01 --expanded | grep -A1 'profiles:' | tail -1 | tr -d ' -')"
```

## 5. Snapshot and Restore

```bash
# Take a snapshot (container can be running)
lxc snapshot web01 snap-before-upgrade

# Take a snapshot with expiry
lxc snapshot web01 snap0 --expiry 24h

# List snapshots
lxc info web01

# Restore snapshot (container must be stopped for stateful restore)
lxc stop web01
lxc restore web01 snap-before-upgrade
lxc start web01

# Copy snapshot to new container
lxc copy web01/snap-before-upgrade web01-backup

# Delete a snapshot
lxc delete web01/snap-before-upgrade

# Automate daily snapshots via cron (add to root crontab)
# 0 2 * * * lxc snapshot web01 "daily-$(date +%Y%m%d)" && lxc delete web01/daily-$(date -d '7 days ago' +%Y%m%d) 2>/dev/null
```

## 6. File Transfer (Push/Pull)

```bash
# Push a single file into the container
lxc file push /etc/hosts web01/etc/hosts

# Push and set ownership (useful for unprivileged containers where UIDs are remapped)
lxc file push /local/app.conf web01/etc/app/app.conf --uid 0 --gid 0 --mode 644

# Push a directory recursively
lxc file push -r /local/myapp/ web01/opt/myapp/

# Pull a file from the container
lxc file pull web01/var/log/syslog /tmp/container-syslog

# Pull a directory recursively
lxc file pull -r web01/etc/nginx/ /tmp/nginx-backup/

# Edit a file directly (pulls, opens in $EDITOR, pushes back)
lxc file edit web01/etc/nginx/nginx.conf
```

## 7. Persistent Storage (Disk Device)

```bash
# Create a new storage volume in the default pool
lxc storage volume create default mydata

# Attach volume to a running container at /data
lxc config device add web01 mydata disk pool=default source=mydata path=/data

# Verify the device is present
lxc config device show web01

# Share a host directory into a container (bind mount)
# WARNING: host path permissions apply — UID remapping complicates this for unprivileged containers
lxc config device add web01 hostshare disk source=/srv/shared path=/mnt/shared

# Remove a disk device
lxc config device remove web01 mydata

# Delete the storage volume when no longer needed
lxc storage volume delete default mydata

# List all volumes in a pool
lxc storage volume list default
```

## 8. Network Configuration

```bash
# List networks managed by LXD
lxc network list

# Create a new bridge network
lxc network create lxdbr1 ipv4.address=10.200.0.1/24 ipv4.nat=true ipv6.address=none

# Attach a second NIC to a container on the new bridge
lxc config device add web01 eth1 nic network=lxdbr1 name=eth1

# Set a static IP for a container on a managed network
lxc network set lxdbr0 ipv4.dhcp.ranges 10.100.0.100-10.100.0.200
# Then reserve a specific IP by MAC:
lxc config set web01 volatile.eth0.hwaddr aa:bb:cc:dd:ee:ff
# Edit dnsmasq config manually for static reservation, or use:
lxc network set lxdbr0 raw.dnsmasq "dhcp-host=aa:bb:cc:dd:ee:ff,10.100.0.50"

# Forward host port to container (proxy device)
lxc config device add web01 http-proxy proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80
lxc config device add web01 https-proxy proxy listen=tcp:0.0.0.0:443 connect=tcp:127.0.0.1:443

# Create a VLAN-tagged NIC (for containers on a specific VLAN)
lxc config device add web01 eth0 nic nictype=macvlan parent=eth0 vlan=100

# Show network info and connected containers
lxc network info lxdbr0
```

## 9. Run Docker Inside LXC

Requires the container to be privileged and nesting enabled. Prefer this over Docker-on-Docker for workloads that need container isolation with direct kernel access.

```bash
# Enable required security options before launch or on existing container
lxc config set docker-host security.nesting true
lxc config set docker-host security.privileged true

# Also needed on some kernels for Docker's iptables rules
lxc config set docker-host linux.kernel_modules "ip_tables,ip6_tables,netfilter,overlay,br_netfilter"

# Optional: allow raw network access (needed for some Docker networking modes)
lxc config set docker-host security.syscalls.intercept.mknod true
lxc config set docker-host security.syscalls.intercept.setxattr true

# Restart container to apply
lxc restart docker-host

# Inside the container, install Docker normally
lxc exec docker-host -- bash -c "curl -fsSL https://get.docker.com | sh"

# Verify Docker works inside
lxc exec docker-host -- docker run --rm hello-world

# NOTE: privileged containers share the host kernel namespace fully.
# Any kernel vulnerability is directly exploitable from within.
# Use only when Docker-in-unprivileged-LXC is not sufficient.
```

## 10. Export and Import Containers

```bash
# Stop container before export for a consistent image (optional but recommended)
lxc stop web01

# Export to tarball (includes all devices and config)
lxc export web01 web01-backup.tar.gz

# Export a specific snapshot only
lxc export web01/snap0 web01-snap0.tar.gz

# Import tarball as a new container
lxc import web01-backup.tar.gz

# Import with a different name
lxc import web01-backup.tar.gz --storage default
# Then rename:
lxc rename web01 web01-restored

# Publish a container as a reusable image
lxc publish web01 --alias my-web-template

# List local images
lxc image list

# Delete a local image
lxc image delete my-web-template

# Transfer container to another LXD host via remote
lxc remote add prod-host https://prod.example.com:8443
lxc copy web01 prod-host:web01
```
