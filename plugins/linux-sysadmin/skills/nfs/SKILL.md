---
name: nfs
description: >
  NFS server and client administration: exports configuration, client mounts,
  NFSv4 pseudo-root, UID/GID mapping, idmapd, and troubleshooting. Triggers on:
  NFS, nfs-server, nfs mount, NFS share, exports, network file system, nfsd,
  exportfs, showmount, nfs-kernel-server, nfs-utils, /etc/exports.
globs:
  - "**/exports"
  - "**/exports.d/**"
  - "**/fstab"
---

## Identity
- **Unit**: `nfs-server.service` (RHEL/Fedora) or `nfs-kernel-server.service` (Debian/Ubuntu)
- **Config**: `/etc/exports`, `/etc/exports.d/*.exports`
- **Client daemon**: `rpc.statd` (NFSv3 lock), `rpc-statd.service`; NFSv4 needs no separate daemon
- **Install**: server: `dnf install nfs-utils` / `apt install nfs-kernel-server`; client: `dnf install nfs-utils` / `apt install nfs-common`
- **Ports**: 2049 TCP/UDP (NFS), 111 TCP/UDP (portmapper, NFSv3 only), 20048 TCP/UDP (mountd, NFSv3 only)

## Key Operations

| Operation | Command |
|-----------|---------|
| Server status | `systemctl status nfs-server` |
| List configured exports | `cat /etc/exports` |
| Reload exports after edit | `sudo exportfs -ra` |
| Show active exports with options | `exportfs -v` |
| Show who has mounts (server) | `showmount -a` |
| Show exports on a server (client) | `showmount -e <server>` |
| Mount NFSv4 share (one-time) | `sudo mount -t nfs4 server:/export/path /mnt/local` |
| Mount with explicit options | `sudo mount -t nfs4 -o rsize=65536,wsize=65536,timeo=14,hard server:/path /mnt/local` |
| Unmount | `sudo umount /mnt/local` |
| Lazy unmount (stale handle) | `sudo umount -l /mnt/local` |
| Force unmount | `sudo umount -f /mnt/local` |
| Check rpcbind (NFSv3) | `rpcinfo -p <server>` |
| Check idmapd domain (NFSv4) | `cat /etc/idmapd.conf` — `Domain =` line |
| Restart idmapd | `sudo systemctl restart nfs-idmapd` |
| Lock/state status | `cat /proc/fs/nfsd/clients/*` or `nfsstat -s` |
| NFS statistics (debug) | `nfsstat -c` (client), `nfsstat -s` (server) |
| Recover stale NFS handle | `sudo umount -l /mnt/point && sudo mount /mnt/point` |

## Expected Ports
- **2049 TCP/UDP** — NFS data (all versions)
- **111 TCP/UDP** — portmapper/rpcbind (NFSv3 only; not needed for NFSv4-only setups)
- **20048 TCP/UDP** — mountd (NFSv3 only)
- Verify server: `ss -tlnp | grep 2049`
- Firewall (NFSv4 only): `firewall-cmd --add-service=nfs --permanent` or `ufw allow 2049/tcp`
- Firewall (NFSv3, all ports): `firewall-cmd --add-service={nfs,rpc-bind,mountd} --permanent`

## Health Checks
1. `systemctl is-active nfs-server` → `active`
2. `exportfs -v` → lists expected exports with options
3. From client: `showmount -e <server>` → lists exports
4. From client: `sudo mount -t nfs4 server:/path /mnt/test && ls /mnt/test` → files visible

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `access denied by server while mounting` | Client IP not in exports ACL | Check `/etc/exports` — add client IP or subnet; run `exportfs -ra` |
| `stale file handle` | Server restarted or export removed/moved | `umount -l /mnt/point` then remount; verify export still exists with `showmount -e server` |
| Files owned by `nobody`/`nogroup` | UID/GID mismatch or idmapd domain mismatch (NFSv4) | Verify UID matches on client and server; check `Domain =` in `/etc/idmapd.conf` on both sides |
| Slow write performance | Export using `sync` option | Add `async` to exports options (accepts data-loss risk on crash); or tune `wsize` |
| Firewall blocking portmapper | NFSv3 needs port 111 open | Open ports 111 and 20048 in addition to 2049; switch to NFSv4-only to avoid this |
| NFSv4 files all show as `nobody` | `idmapd.conf` domain mismatch between client and server | Set identical `Domain =` in `/etc/idmapd.conf` on both sides; restart `nfs-idmapd` |
| `mount.nfs: No such device` | `nfs` kernel module not loaded | `sudo modprobe nfs`; verify with `lsmod | grep nfs` |
| `RPC: Port mapper failure` | rpcbind not running (NFSv3) | `sudo systemctl start rpcbind`; check with `rpcinfo -p localhost` |

## Pain Points
- **No encryption by default**: NFS traffic is cleartext. Use IPsec, WireGuard, or an SSH tunnel for untrusted networks. NFSv4 with Kerberos (`sec=krb5p`) provides encryption but adds significant setup complexity.
- **Root squash is the default**: `root_squash` is on by default — root on the client maps to `nfsnobody` on the server. This is correct security behavior but surprises admins who expect root to work across the mount. Use `no_root_squash` only when the client machine is fully trusted.
- **`async` risks data loss**: The `async` export option tells the server to acknowledge writes before flushing to disk. If the server crashes between the acknowledgment and the flush, data is lost. `sync` is safe but slower; profile before switching.
- **NFSv3 firewall complexity**: NFSv3 uses dynamically assigned ports for mountd and statd, making firewall rules error-prone. Prefer NFSv4 (port 2049 only) for any setup where you control firewall rules.
- **idmapd domain must match exactly**: NFSv4 maps user identities as `user@domain` strings. If the `Domain =` setting in `/etc/idmapd.conf` differs by even one character between client and server, all file ownership resolves to `nobody`. This is a silent misconfiguration — NFS mounts and reads succeed, ownership is just wrong.

## References
See `references/` for:
- `nfs-config.md` — exports format, common options, NFSv4 pseudo-root, fstab entries, and firewall rules
- `docs.md` — man pages and external documentation links
