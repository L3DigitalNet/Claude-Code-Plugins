# NFS Configuration Patterns

---

## /etc/exports Format

Each line defines one export. The format is:

```
/path/to/export  client1(options)  client2(options)
```

`client` can be:
- A hostname: `workstation.local`
- An IP address: `192.168.1.50`
- A CIDR subnet: `192.168.1.0/24`
- A wildcard: `*.example.com`
- `*` for all clients (use with caution)

Multiple clients with different options go on the same line, space-separated.

---

## Common Export Options

| Option | Meaning |
|--------|---------|
| `ro` | Read-only (default) |
| `rw` | Read-write |
| `sync` | Acknowledge writes only after data is on disk (safe, slower) |
| `async` | Acknowledge writes before flush (faster, data-loss risk on crash) |
| `root_squash` | Map client root to `nfsnobody` (default, recommended) |
| `no_root_squash` | Allow client root to act as server root (only for fully trusted clients) |
| `all_squash` | Map all client UIDs/GIDs to `nfsnobody` (for public shares) |
| `no_subtree_check` | Skip subtree permission checks (improves reliability when files are renamed) |
| `anonuid=1000` | UID to use for anonymous (squashed) access |
| `anongid=1000` | GID to use for anonymous (squashed) access |
| `fsid=0` | Mark this export as the NFSv4 pseudo-root (required for NFSv4 root export) |
| `sec=krb5` | Kerberos authentication (identity only); `krb5i` adds integrity, `krb5p` adds encryption |

---

## NFSv4-Only Server Setup (Recommended)

NFSv4 uses a single port (2049) and no portmapper, which simplifies firewall rules and is preferred for new deployments.

**Install and enable:**
```bash
# Debian/Ubuntu
sudo apt install nfs-kernel-server

# RHEL/Fedora
sudo dnf install nfs-utils
sudo systemctl enable --now nfs-server
```

**Restrict to NFSv4 only** (optional, Debian/Ubuntu):

Edit `/etc/nfs.conf` or `/etc/default/nfs-kernel-server`:
```ini
# /etc/nfs.conf
[nfsd]
vers2=n
vers3=n
vers4=y
vers4.1=y
vers4.2=y
```

**Basic /etc/exports:**
```
# Grant one subnet read-write access to /srv/data.
# no_subtree_check avoids spurious permission errors when files are renamed.
/srv/data  192.168.1.0/24(rw,sync,no_subtree_check)

# Read-only for a second host.
/srv/media  192.168.1.0/24(ro,sync,no_subtree_check)
```

After editing:
```bash
sudo exportfs -ra    # reload without restarting the service
exportfs -v          # verify what is active
```

---

## NFSv4 Pseudo-Root with Bind Mounts

NFSv4 requires a single root export (`fsid=0`). All other exports must live under this root — either directly or via bind mounts. This keeps clients from needing to know the server's internal path layout.

```bash
# Create the pseudo-root directory.
sudo mkdir -p /srv/nfs4

# Bind-mount the real directories into the pseudo-root.
sudo mkdir -p /srv/nfs4/data /srv/nfs4/media
sudo mount --bind /srv/data  /srv/nfs4/data
sudo mount --bind /srv/media /srv/nfs4/media
```

Make the bind mounts persistent in `/etc/fstab`:
```
/srv/data   /srv/nfs4/data   none   bind   0 0
/srv/media  /srv/nfs4/media  none   bind   0 0
```

`/etc/exports` for the pseudo-root setup:
```
# fsid=0 marks this as the NFSv4 root — clients mount server:/ to reach it.
/srv/nfs4         192.168.1.0/24(ro,sync,no_subtree_check,fsid=0)
/srv/nfs4/data    192.168.1.0/24(rw,sync,no_subtree_check)
/srv/nfs4/media   192.168.1.0/24(ro,sync,no_subtree_check)
```

Client mounts then use paths relative to the pseudo-root:
```bash
sudo mount -t nfs4 server:/data  /mnt/data
sudo mount -t nfs4 server:/media /mnt/media
```

---

## Client /etc/fstab Entry

For persistent mounts that survive reboots:

```
# server:/export  local-mountpoint  type  options  dump  pass
192.168.1.10:/data  /mnt/data  nfs4  nfsvers=4.2,rsize=65536,wsize=65536,timeo=14,retrans=2,hard,intr,_netdev  0  0
```

Key options explained:

| Option | Purpose |
|--------|---------|
| `nfsvers=4.2` | Force NFSv4.2 (or `4.1`, `4`); avoids fallback negotiation |
| `rsize=65536` | Read block size in bytes (64K is a common sweet spot) |
| `wsize=65536` | Write block size in bytes |
| `timeo=14` | Timeout for RPC retries in tenths of a second (1.4s) |
| `retrans=2` | Number of RPC retransmissions before a soft mount gives up (or hard mount logs an error) |
| `hard` | Retry indefinitely if server goes away (safer for data integrity) |
| `soft` | Return an error to the application after `retrans` failures (risks data loss but avoids hangs) |
| `intr` | Allow signals to interrupt a hung NFS operation (deprecated in kernel >= 2.6.25 but still common in fstab) |
| `_netdev` | Tell systemd to mount this only after the network is up |

---

## Kerberos Authentication Overview

NFS with Kerberos (`sec=krb5`, `krb5i`, or `krb5p`) provides identity verification and optionally integrity/encryption without trusting UIDs.

Requirements:
- A working KDC (MIT Kerberos or FreeIPA)
- Both client and server joined to the Kerberos realm
- `nfs-utils` (or `nfs-common`) with Kerberos support compiled in
- `krb5-workstation` / `krb5-user` packages on both sides
- Service principals: `nfs/<server-fqdn>@REALM` on the server

The three `sec=` levels:
- `krb5` — authentication only (identity verified, traffic still cleartext)
- `krb5i` — authentication + integrity (checksums, prevents tampering)
- `krb5p` — authentication + integrity + privacy (full encryption)

For most homelab/small-office use cases where encryption is needed, a VPN or WireGuard tunnel is simpler than full Kerberos.

---

## Firewall Rules

### NFSv4 Only (simplest)

```bash
# firewalld
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --reload

# ufw
sudo ufw allow 2049/tcp
sudo ufw allow 2049/udp
```

### NFSv3 (also needs portmapper and mountd)

With firewalld, pin mountd and statd to fixed ports first:

```ini
# /etc/nfs.conf (or /etc/sysconfig/nfs on older RHEL)
[mountd]
port=20048
[statd]
port=32765
outgoing-port=32766
[lockd]
port=32803
udp-port=32803
```

Then open all required ports:
```bash
# firewalld — services handle the port groups
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --permanent --add-service=mountd
sudo firewall-cmd --reload

# ufw — manual port list
sudo ufw allow 2049
sudo ufw allow 111
sudo ufw allow 20048
sudo ufw allow 32765:32767/tcp
sudo ufw allow 32765:32767/udp
sudo ufw allow 32803
```
