---
name: ceph
description: >
  Ceph distributed storage administration: RADOS architecture (MON, OSD, MDS, MGR),
  cephadm bootstrap, pool management, RBD block storage, CephFS file system,
  RGW S3-compatible object storage, CRUSH map, PG management, dashboard, and
  cluster health monitoring.
  MUST consult when installing, configuring, or troubleshooting ceph.
triggerPhrases:
  - "Ceph"
  - "cephadm"
  - "ceph status"
  - "ceph health"
  - "ceph osd"
  - "ceph mon"
  - "ceph mgr"
  - "ceph mds"
  - "RADOS"
  - "RBD"
  - "rbd create"
  - "rbd map"
  - "CephFS"
  - "ceph-fuse"
  - "RGW"
  - "radosgw"
  - "CRUSH map"
  - "placement group"
  - "ceph pool"
  - "ceph dashboard"
  - "ceph orch"
  - "ceph osd pool"
  - "ceph pg"
  - "ceph df"
  - "ceph crash"
  - "erasure coding ceph"
globs: []
last_verified: "2026-03"
---

## Identity

- **Daemons**: `ceph-mon` (monitor), `ceph-osd` (object storage), `ceph-mds` (metadata for CephFS), `ceph-mgr` (manager/dashboard), `radosgw` (S3/Swift gateway)
- **Deployment tool**: `cephadm` (container-based deployment, recommended since Octopus)
- **CLI**: `ceph` (cluster management), `rbd` (block device), `rados` (low-level object operations), `ceph-fuse` (FUSE CephFS client)
- **Config**: `/etc/ceph/ceph.conf` (cluster config), `/etc/ceph/ceph.client.admin.keyring` (auth)
- **Logs**: `/var/log/ceph/<fsid>/` (cephadm clusters), `journalctl -u ceph-*`
- **Service**: Cephadm manages daemons as systemd units via containers (podman or docker)
- **Install**: `cephadm bootstrap` on first node (downloads and runs everything in containers)
- **Version check**: `ceph version` / `ceph versions` (cluster-wide)
- **Current releases**: Tentacle (20.x, latest), Squid (19.x, supported until Sept 2026), Reef (18.x, EOL mid-2025)

## Quick Start

```bash
# Install cephadm on the first node (Debian/Ubuntu)
apt install -y cephadm

# Bootstrap the cluster (creates first MON + MGR)
sudo cephadm bootstrap --mon-ip <node1-ip>
# Outputs the dashboard URL, admin password, and ceph.conf location

# Verify
sudo ceph status
sudo ceph health detail

# Add a second host
sudo ceph orch host add node2 <node2-ip>

# Deploy OSDs on all available unused devices
sudo ceph orch apply osd --all-available-devices

# Create a replicated pool and enable RBD
sudo ceph osd pool create mypool 128
sudo ceph osd pool application enable mypool rbd
sudo rbd pool init mypool
```

## Key Operations

| Task | Command |
|------|---------|
| Cluster status | `ceph status` (or `ceph -s`) |
| Health detail | `ceph health detail` |
| Cluster versions | `ceph versions` |
| Space usage | `ceph df` / `ceph df detail` |
| OSD tree (topology) | `ceph osd tree` |
| OSD status | `ceph osd status` |
| List pools | `ceph osd pool ls detail` |
| Create replicated pool | `ceph osd pool create <pool> [<pg-num>]` |
| Create erasure-coded pool | `ceph osd pool create <pool> <pg-num> erasure [<ec-profile>]` |
| Set pool application | `ceph osd pool application enable <pool> <rbd\|cephfs\|rgw>` |
| Set pool replication size | `ceph osd pool set <pool> size <N>` |
| Set pool quota | `ceph osd pool set-quota <pool> max_bytes <bytes>` |
| Delete pool | `ceph osd pool delete <pool> <pool> --yes-i-really-really-mean-it` |
| Create EC profile | `ceph osd erasure-code-profile set <name> k=<data> m=<parity>` |
| PG autoscaler status | `ceph osd pool autoscale-status` |
| Add host | `ceph orch host add <host> [<ip>] [--labels <label>]` |
| List hosts | `ceph orch host ls` |
| Deploy OSDs (all available) | `ceph orch apply osd --all-available-devices` |
| Deploy OSD (specific device) | `ceph orch daemon add osd <host>:<device>` |
| Remove OSD | `ceph osd out <id>` then `ceph osd purge <id> --yes-i-really-mean-it` |
| Mark OSD out | `ceph osd out <id>` |
| Mark OSD in | `ceph osd in <id>` |
| Create RBD image | `rbd create --size <MB> <pool>/<image>` |
| List RBD images | `rbd ls <pool>` |
| Map RBD to device | `rbd map <pool>/<image>` |
| Unmap RBD device | `rbd unmap /dev/rbd<N>` |
| RBD snapshot create | `rbd snap create <pool>/<image>@<snap>` |
| RBD snapshot protect | `rbd snap protect <pool>/<image>@<snap>` |
| RBD clone from snapshot | `rbd clone <pool>/<image>@<snap> <pool>/<clone>` |
| RBD flatten clone | `rbd flatten <pool>/<clone>` |
| Create CephFS | `ceph fs volume create <fsname>` |
| Mount CephFS (kernel) | `mount -t ceph <user>@.<fsname>=/ <mountpoint> -o mon_addr=<ip>:6789` |
| Mount CephFS (FUSE) | `ceph-fuse -n client.<user> <mountpoint>` |
| Deploy RGW | `ceph orch apply rgw <service-name>` |
| Enable dashboard | `ceph mgr module enable dashboard` |
| Dashboard self-signed cert | `ceph dashboard create-self-signed-cert` |
| Create dashboard user | `ceph dashboard ac-user-create <user> -i <pwfile> administrator` |
| Dashboard URL | `ceph mgr services \| jq .dashboard` |
| View crash reports | `ceph crash ls-new` |
| Archive crash | `ceph crash archive-all` |
| CRUSH rule list | `ceph osd crush rule list` |
| CRUSH rule create (replicated) | `ceph osd crush rule create-replicated <rule> <root> <failure-domain> [<class>]` |
| Set pool CRUSH rule | `ceph osd pool set <pool> crush_rule <rule>` |
| OSD device class | `ceph osd crush set-device-class <ssd\|hdd> <osd-id>` |

## Expected Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 3300 | TCP | Monitor daemon (msgr2 protocol, default since Nautilus) |
| 6789 | TCP | Monitor daemon (legacy msgr1 protocol) |
| 6800-7568 | TCP | OSD, MDS, and MGR daemons (dynamic binding within range) |
| 8443 | TCP | Dashboard (HTTPS, default when SSL enabled) |
| 8080 | TCP | Dashboard (HTTP, when SSL disabled) |
| 7480 | TCP | RGW (default HTTP port for radosgw) |

Each OSD uses up to 4 ports within the 6800-7568 range (client, cluster, two heartbeat). The range is configurable via `ms_bind_port_min` and `ms_bind_port_max`. Separate public and cluster networks are recommended for production: clients access only the public network, while OSDs replicate over the cluster network.

## Health Checks

1. `ceph status` -- overall cluster state (HEALTH_OK / HEALTH_WARN / HEALTH_ERR)
2. `ceph health detail` -- specific warnings with affected components
3. `ceph osd tree` -- all OSDs should show `up` and `in`; any `down` or `out` indicates failure
4. `ceph df` -- check capacity; OSDs above 85% full trigger warnings, 95% blocks writes
5. `ceph osd pool autoscale-status` -- PG counts should be balanced
6. `ceph pg stat` -- all PGs should be `active+clean`; `degraded`, `undersized`, or `stale` need investigation
7. `ceph crash ls-new` -- check for recent daemon crashes
8. `ceph osd perf` -- latency per OSD (commit and apply latency)
9. `ceph tell osd.* version` -- verify all OSDs run the same version after upgrades

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `HEALTH_WARN: X osds down` | OSD daemon crashed or host unreachable | Check host: `ceph osd find osd.<id>`; review logs at `/var/log/ceph/`; restart: `ceph orch daemon restart osd.<id>` |
| `HEALTH_WARN: mon X is down` | Monitor daemon stopped or host offline | Restart the monitor; if host is lost, `ceph mon remove <name>` and deploy replacement |
| `HEALTH_WARN: clock skew detected` (MON_CLOCK_SKEW) | NTP not configured or drifting | Synchronize clocks with chrony or NTP on all nodes |
| PGs stuck in `degraded` | One or more OSDs holding PG replicas are down | Restore the down OSD; PGs recover automatically once OSDs return |
| PGs stuck in `peering` | OSD hosting PG data cannot be reached | Check network connectivity; `ceph pg <pgid> query` to identify blocking OSD |
| PGs in `incomplete` state | Not enough copies available for the PG | Bring up all possible OSDs; if data is permanently lost, mark PG lost: `ceph pg <pgid> mark_unfound_lost revert` |
| `HEALTH_ERR: X full osd(s)` (OSD_FULL) | OSD capacity exceeded full_ratio (default 95%) | Add OSDs, delete data, or temporarily raise ratio: `ceph osd set-full-ratio 0.97` |
| `HEALTH_WARN: pool X has no application enabled` | Pool was created without setting application tag | `ceph osd pool application enable <pool> rbd` (or cephfs/rgw) |
| `HEALTH_WARN: SLOW_OPS` | OSD disk bottleneck or overloaded cluster | `ceph daemon osd.<id> dump_historic_ops`; check disk I/O with `iostat`; consider adding OSDs |
| `HEALTH_WARN: RECENT_CRASH` | A daemon crashed recently | `ceph crash ls-new` to review; `ceph crash archive-all` after investigation |
| RBD map fails: "RBD image feature set mismatch" | Kernel client doesn't support all image features | Disable unsupported features: `rbd feature disable <pool>/<image> object-map fast-diff deep-flatten` |
| CephFS mount hangs | MDS not running or wrong auth credentials | Check `ceph mds stat`; verify keyring permissions |
| `AUTH_INSECURE_GLOBAL_ID_RECLAIM` | Clients using unpatched Ceph with insecure auth | Upgrade all clients; then: `ceph config set mon auth_allow_insecure_global_id_reclaim false` |

## Pain Points

- **PG count matters and is hard to change retroactively**: Too few PGs per pool leads to uneven data distribution; too many wastes memory per OSD. Use the PG autoscaler (`ceph osd pool set <pool> pg_autoscale_mode on`) for all pools. Manual PG tuning is an advanced operation that should be avoided unless you understand the specific tradeoff.
- **Full OSDs block the entire cluster**: When any OSD reaches the `full_ratio` (default 95%), the entire cluster stops accepting writes to protect data integrity. Monitor `ceph df` proactively and set `nearfull_ratio` alerts. Adding capacity is the only sustainable fix.
- **CRUSH map design is a one-time decision**: The failure domain hierarchy (host, rack, datacenter) should be planned before deployment. Changing CRUSH rules after data is written triggers large-scale data migration. Use device classes (ssd, hdd) to direct pools to specific storage tiers.
- **Upgrades are sequential and slow**: Ceph upgrades must proceed one major version at a time (Reef -> Squid -> Tentacle) and roll through MON, MGR, OSD, MDS daemons in order. `cephadm upgrade` automates this but a large cluster can take hours.
- **RBD kernel client feature limitations**: The Linux kernel RBD client does not support all image features available in librbd. When creating images for kernel mapping, use `rbd create --image-feature layering` or disable advanced features before mapping.
- **CephFS requires at least one MDS**: Unlike RBD and RGW, CephFS needs a Metadata Server daemon. MDS is stateful and its failure pauses file operations until standby MDS takes over. Always deploy active-standby MDS pairs.
- **RGW is a separate service layer**: radosgw handles S3/Swift API translation but adds operational overhead (realm, zonegroup, zone hierarchy for multi-site). For simple object storage, consider whether RBD or CephFS meets the need instead.
- **Memory requirements are significant**: Each OSD daemon consumes 3-5 GB of RAM (configurable via `osd_memory_target`). A node with 12 OSDs needs 36-60 GB of RAM just for OSD processes, plus system overhead and MDS/MON if co-located.

## See Also

- **glusterfs** -- Distributed filesystem with simpler architecture; better for pure file-sharing workloads without block or object storage needs
- **minio** -- S3-compatible object storage; simpler alternative to Ceph RGW when you only need object storage
- **zfs** -- Local storage with checksums, snapshots, and send/receive; often used as the underlying filesystem for Ceph OSDs (though Ceph prefers BlueStore on raw devices)
- **lvm** -- Block-level volume management; Ceph's BlueStore can optionally use LVM for OSD device management

## References

See `references/` for:
- `docs.md` -- official documentation, release information, and community resources
- `common-patterns.md` -- cephadm deployment, pool management, RBD, CephFS, RGW, and CRUSH map examples
- `ceph.conf.annotated` -- annotated cluster configuration file covering [global] (identity, networking, auth, pool defaults, CRUSH), [mon] (capacity thresholds, OSD interaction), [osd] (recovery, BlueStore, scrubbing), [mds], and [client] settings
