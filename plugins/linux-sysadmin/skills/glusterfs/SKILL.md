---
name: glusterfs
description: >
  GlusterFS distributed filesystem administration: trusted storage pools, brick management,
  volume types (distribute, replicate, disperse), geo-replication, snapshots, self-heal,
  quota management, and client mounting via native FUSE and NFS-Ganesha.
  MUST consult when installing, configuring, or troubleshooting glusterfs.
triggerPhrases:
  - "GlusterFS"
  - "gluster volume"
  - "gluster peer"
  - "trusted storage pool"
  - "gluster brick"
  - "gluster snapshot"
  - "gluster geo-replication"
  - "gluster self-heal"
  - "gluster quota"
  - "gluster replicate"
  - "gluster disperse"
  - "glusterd"
  - "gluster volume create"
  - "gluster volume start"
  - "gluster volume info"
  - "gluster peer probe"
  - "gluster heal"
  - "gluster mount"
  - "mount.glusterfs"
  - "NFS-Ganesha gluster"
  - "split-brain gluster"
  - "arbiter volume"
  - "distributed replicated volume"
globs: []
last_verified: "2026-03"
---

## Identity

- **Daemon**: `glusterd` (management), `glusterfsd` (brick process per brick)
- **CLI**: `gluster` (all management operations)
- **Config**: `/etc/glusterfs/glusterd.vol` (daemon config), `/var/lib/glusterd/` (peer and volume state)
- **Logs**: `/var/log/glusterfs/` (glusterd, bricks, clients, geo-replication)
- **Service**: `glusterd.service` (systemd)
- **Install**: `apt install glusterfs-server` (Debian/Ubuntu), `dnf install glusterfs-server` (RHEL/Fedora)
- **Client install**: `apt install glusterfs-client` (Debian/Ubuntu), `dnf install glusterfs-fuse` (RHEL/Fedora)
- **Version check**: `gluster --version`
- **Current release**: 11.x (community-maintained; Red Hat ended commercial Gluster Storage support in 2024)

## Quick Start

```bash
# Install on all nodes
sudo apt install glusterfs-server
sudo systemctl enable --now glusterd

# Build the trusted storage pool (run from one node)
sudo gluster peer probe node2
sudo gluster peer probe node3
gluster peer status

# Create a replicated volume (2 copies)
sudo gluster volume create myvol replica 2 \
    node1:/data/brick1 node2:/data/brick1
sudo gluster volume start myvol

# Mount from a client
sudo apt install glusterfs-client
sudo mount -t glusterfs node1:/myvol /mnt/gluster
```

## Key Operations

| Task | Command |
|------|---------|
| Add node to pool | `gluster peer probe <hostname>` |
| Remove node from pool | `gluster peer detach <hostname>` |
| List pool members | `gluster pool list` |
| Peer status | `gluster peer status` |
| Create distributed volume | `gluster volume create <vol> <node1>:<brick> <node2>:<brick>` |
| Create replicated volume | `gluster volume create <vol> replica <N> <node1>:<brick> ... <nodeN>:<brick>` |
| Create replicated + arbiter | `gluster volume create <vol> replica 2 arbiter 1 <n1>:<b1> <n2>:<b2> <n3>:<b3>` |
| Create distributed-replicated | `gluster volume create <vol> replica <N> <bricks...>` (brick count = multiple of N) |
| Create dispersed (erasure-coded) | `gluster volume create <vol> disperse <count> redundancy <N> <bricks...>` |
| Create distributed-dispersed | `gluster volume create <vol> disperse <count> redundancy <N> <bricks...>` (brick count = multiple of disperse count) |
| Start volume | `gluster volume start <vol>` |
| Stop volume | `gluster volume stop <vol>` |
| Delete volume | `gluster volume delete <vol>` (must be stopped first) |
| Volume info | `gluster volume info [<vol>]` |
| Volume status | `gluster volume status [<vol>] [detail\|clients\|mem]` |
| Add bricks (expand) | `gluster volume add-brick <vol> <new-bricks...>` |
| Remove bricks | `gluster volume remove-brick <vol> <bricks...> start` then `commit` |
| Replace brick | `gluster volume replace-brick <vol> <old-brick> <new-brick> commit force` |
| Rebalance after expansion | `gluster volume rebalance <vol> start` |
| Rebalance status | `gluster volume rebalance <vol> status` |
| Set volume option | `gluster volume set <vol> <key> <value>` |
| Get volume options | `gluster volume get <vol> all` |
| Enable quota | `gluster volume quota <vol> enable` |
| Set quota limit | `gluster volume quota <vol> limit-usage <path> <size> [<soft-%>]` |
| Quota info | `gluster volume quota <vol> list [<path>]` |
| Disable quota | `gluster volume quota <vol> disable` |
| Create snapshot | `gluster snapshot create <snapname> <vol> [no-timestamp] [description <desc>]` |
| List snapshots | `gluster snapshot list [<vol>]` |
| Snapshot info | `gluster snapshot info <snapname>` |
| Restore snapshot | `gluster snapshot restore <snapname>` (volume must be stopped) |
| Delete snapshot | `gluster snapshot delete <snapname>` |
| Start geo-replication | `gluster volume geo-replication <primary-vol> <secondary-host>::<secondary-vol> start` |
| Geo-replication status | `gluster volume geo-replication <primary-vol> <secondary-host>::<secondary-vol> status` |
| Stop geo-replication | `gluster volume geo-replication <primary-vol> <secondary-host>::<secondary-vol> stop` |
| Trigger self-heal | `gluster volume heal <vol>` |
| Heal info (pending) | `gluster volume heal <vol> info` |
| Heal info (split-brain) | `gluster volume heal <vol> info split-brain` |
| Heal statistics | `gluster volume heal <vol> statistics heal-count` |
| Mount via FUSE | `mount -t glusterfs <node>:/<vol> <mountpoint>` |

## Expected Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 24007 | TCP | glusterd management daemon |
| 24008 | TCP | RDMA management (optional, only when using InfiniBand) |
| 49152+ | TCP | Brick processes (one port per brick, starting at 49152) |
| 38465-38467 | TCP | GlusterFS built-in NFS server (deprecated in favor of NFS-Ganesha) |
| 111 | TCP/UDP | Portmapper (when using NFS) |
| 2049 | TCP | NFS-Ganesha (when configured) |

From GlusterFS 10 onward, brick ports are randomized within the `base-port` to `max-port` range defined in `glusterd.vol`. Plan firewall rules to cover at least 49152 through 49152 + (number of bricks per node).

## Health Checks

1. `gluster peer status` -- all peers Connected
2. `gluster volume status <vol>` -- all bricks Online, all processes running
3. `gluster volume heal <vol> info` -- zero entries needing heal under normal operation
4. `gluster volume heal <vol> info split-brain` -- zero files in split-brain
5. `gluster volume status <vol> clients` -- verify expected clients are connected
6. `gluster volume profile <vol> start` then `gluster volume profile <vol> info` -- I/O statistics for performance assessment
7. `gluster snapshot list` -- confirm recent snapshots exist per backup policy

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `peer probe` fails: "Probe returned with unknown errno 107" | `glusterd` not running on target node | Start service: `systemctl start glusterd` on the target node |
| Peer status shows `Peer Rejected (Connected)` | Mismatched cluster view after failed expansion | On the rejected node: stop glusterd, remove `/var/lib/glusterd/peers/*`, restart glusterd, re-probe from an existing node |
| Volume create fails: "more than one brick on the same peer" | Multiple bricks from one replica set on the same host | Distribute bricks so each replica set spans different nodes; use `force` only for testing |
| Self-heal shows entries that never clear | Brick process down or unreachable | `gluster volume status` to identify offline brick; restart it or fix the underlying disk/network issue |
| Files in split-brain | Network partition during writes to replicated volume | `gluster volume heal <vol> info split-brain` to identify files; resolve manually by choosing the correct copy or use `gluster volume heal <vol> split-brain source-brick <brick> <filename>` |
| "Transport endpoint is not connected" on FUSE mount | Brick processes crashed or firewall blocking brick ports | Check `gluster volume status`; verify firewall allows 49152+ range; restart bricks |
| Rebalance stuck or slow | Large number of small files, heavy I/O during rebalance | Check `gluster volume rebalance <vol> status`; reduce I/O load; rebalance runs as background process |
| Snapshot create fails: "thinly provisioned LVM required" | Bricks not on LVM thin volumes | GlusterFS snapshots require LVM thin provisioning; migrate bricks to thinly-provisioned LVs |
| Geo-replication status: Faulty | SSH keys not set up, clock skew, or secondary volume down | Verify SSH access, synchronize time with NTP, check secondary volume is started |
| Quota not enforced | Quota not enabled at volume level | `gluster volume quota <vol> enable` before setting limits |
| Volume start fails after node replacement | Stale peer entries referencing old node | `gluster peer detach <old-node>` then re-create volume configuration |

## Pain Points

- **Snapshots require LVM thin provisioning**: Unlike ZFS or Btrfs, GlusterFS volume snapshots delegate to the underlying LVM layer. Every brick must reside on a thinly-provisioned logical volume, or snapshot operations will fail. Plan this before creating bricks.
- **Split-brain is the primary data-risk scenario**: In replicated volumes, network partitions can cause the same file to diverge on different bricks. Enable server-side quorum (`cluster.server-quorum-type: server`) and client-side quorum (`cluster.quorum-type: auto`) to prevent writes when quorum is lost. Arbiter volumes (replica 2 + arbiter 1) provide a lighter-weight alternative to three-way replication for split-brain prevention.
- **Brick port randomization after GlusterFS 10**: Earlier versions used predictable ports starting at 49152. Version 10+ randomizes brick ports within a configurable range, which can complicate firewall rules. Pin the range in `glusterd.vol` if you need deterministic firewall rules.
- **Red Hat ended commercial support (2024)**: GlusterFS continues as a community project, but enterprise users should factor this into support and lifecycle planning.
- **Small-file workloads suffer**: GlusterFS's distributed hashing works well for large files but has per-file overhead that makes workloads with millions of small files (e.g., build caches, mail directories) significantly slower than local filesystems. Evaluate sharding for workloads with very large files.
- **Rebalance is expensive and non-preemptive**: Adding or removing bricks triggers a rebalance that migrates files across the cluster. This runs as a background process but competes with production I/O. Schedule expansions during maintenance windows.
- **Geo-replication is asynchronous only**: Changes propagate with a delay (configurable sync interval). There is no synchronous geo-replication option, so RPO is never zero for geo-rep setups.
- **NFS-Ganesha replaced built-in NFS**: The legacy GlusterFS NFS translator is deprecated. NFS-Ganesha integration requires separate installation and configuration. Only one NFS implementation (Ganesha, gluster-nfs, or kernel-nfs) can bind port 2049 on a given host.

## See Also

- **ceph** -- Distributed storage with block (RBD), file (CephFS), and object (RGW) interfaces; stronger consistency model but higher operational complexity
- **nfs** -- Network file sharing; GlusterFS can export volumes via NFS-Ganesha for clients that cannot run the FUSE client
- **samba** -- SMB/CIFS file sharing; GlusterFS integrates with Samba's vfs_glusterfs module for Windows client access
- **lvm** -- GlusterFS snapshots depend on LVM thin provisioning; understanding LVM is a prerequisite for snapshot capability

## References

See `references/` for:
- `docs.md` -- official documentation, man pages, and community resources
- `common-patterns.md` -- volume creation, geo-replication, snapshots, NFS-Ganesha, and client mounting examples
