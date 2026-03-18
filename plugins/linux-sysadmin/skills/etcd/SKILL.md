---
name: etcd
description: >
  etcd distributed key-value store: cluster setup and bootstrapping, member
  management, etcdctl key-value operations, snapshot and restore, authentication
  and RBAC, TLS configuration, compaction, defragmentation, and Kubernetes etcd
  administration.
  MUST consult when installing, configuring, or troubleshooting etcd.
triggerPhrases:
  - "etcd"
  - "etcdctl"
  - "etcdutl"
  - "etcd cluster"
  - "etcd backup"
  - "etcd restore"
  - "etcd snapshot"
  - "etcd compaction"
  - "etcd defrag"
  - "etcd member"
  - "kubernetes etcd"
  - "etcd key-value"
globs:
  - "**/etcd.conf.yml"
  - "**/etcd.yaml"
  - "**/etcd.env"
last_verified: "2026-03"
---

## Identity

- **Unit**: `etcd.service`
- **Config**: `/etc/etcd/etcd.conf.yml` (YAML) or command-line flags / environment variables (prefixed `ETCD_`)
- **Logs**: `journalctl -u etcd`
- **Data dir**: `/var/lib/etcd/` (default `${name}.etcd` when unset)
- **Client port**: 2379/tcp (client requests)
- **Peer port**: 2380/tcp (inter-member Raft consensus and data replication)
- **Install**: download pre-built binaries from https://github.com/etcd-io/etcd/releases (distro packages are often outdated and discouraged by the project)
- **License**: Apache 2.0. CNCF graduated project (since Nov 2020). Serves as the backing store for Kubernetes cluster state; every `kubectl` write ultimately lands in etcd.

## Quick Start

```bash
# 1. Download and install (replace version as needed)
ETCD_VER=v3.5.21
curl -fsSL https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  | sudo tar xz -C /usr/local/bin --strip-components=1 \
    etcd-${ETCD_VER}-linux-amd64/etcd \
    etcd-${ETCD_VER}-linux-amd64/etcdctl \
    etcd-${ETCD_VER}-linux-amd64/etcdutl

# 2. Start a single-node instance (dev/testing only)
etcd --data-dir /tmp/etcd-test

# 3. Write and read a key
etcdctl put greeting "hello world"
etcdctl get greeting
```

## Key Operations

| Task | Command |
|------|---------|
| Put a key | `etcdctl put mykey "myvalue"` |
| Get a key | `etcdctl get mykey` |
| Get value only | `etcdctl get mykey --print-value-only` |
| Get by prefix | `etcdctl get --prefix /app/` |
| Get range [a, z) | `etcdctl get a z` |
| Get at revision | `etcdctl get --rev=42 mykey` |
| Get as JSON | `etcdctl get mykey -w json` |
| Delete a key | `etcdctl del mykey` |
| Delete by prefix | `etcdctl del --prefix /app/` |
| Watch a key | `etcdctl watch mykey` |
| Watch prefix from revision | `etcdctl watch --prefix --rev=5 /app/` |
| Grant a lease (TTL) | `etcdctl lease grant 300` |
| Attach key to lease | `etcdctl put mykey "val" --lease=<lease-id>` |
| Revoke lease | `etcdctl lease revoke <lease-id>` |
| Keep lease alive | `etcdctl lease keep-alive <lease-id>` |
| Inspect lease | `etcdctl lease timetolive --keys <lease-id>` |
| Compact history | `etcdctl compact <revision>` |
| Defragment member | `etcdctl defrag --endpoints=<url>` |
| Defragment cluster | `etcdctl defrag --cluster` |
| List members | `etcdctl member list -w table` |
| Add member | `etcdctl member add node4 --peer-urls=http://10.0.1.14:2380` |
| Add learner | `etcdctl member add node4 --peer-urls=http://10.0.1.14:2380 --learner` |
| Promote learner | `etcdctl member promote <member-id>` |
| Remove member | `etcdctl member remove <member-id>` |
| Update peer URLs | `etcdctl member update <member-id> --peer-urls=http://new-ip:2380` |
| Snapshot save | `etcdctl snapshot save backup.db` |
| Snapshot status | `etcdutl snapshot status backup.db -w table` |
| Snapshot restore | `etcdutl snapshot restore backup.db --data-dir /var/lib/etcd-restored` |
| Endpoint health | `etcdctl endpoint health --cluster -w table` |
| Endpoint status | `etcdctl endpoint status --cluster -w table` |
| List alarms | `etcdctl alarm list` |
| Disarm alarms | `etcdctl alarm disarm` |
| Enable auth | `etcdctl user add root && etcdctl auth enable` |
| Create user | `etcdctl user add myuser` |
| Create role | `etcdctl role add myrole` |
| Grant permission | `etcdctl role grant-permission myrole readwrite /app/ --prefix=true` |
| Assign role to user | `etcdctl user grant-role myuser myrole` |

## Expected Ports

- **2379/tcp** -- client traffic (API, etcdctl, kube-apiserver). Verify: `ss -tlnp | grep :2379`
- **2380/tcp** -- peer traffic (Raft consensus, log replication, snapshot transfer between cluster members). Only needed in multi-node clusters.
- **2381/tcp** -- optional metrics endpoint when `--listen-metrics-urls` is set (keeps metrics off the client port).

## Health Checks

1. `etcdctl endpoint health --cluster -w table` -- per-member health with latency
2. `etcdctl endpoint status --cluster -w table` -- shows leader, DB size, Raft term, Raft index per member
3. `curl -s http://127.0.0.1:2379/health` -- JSON `{"health":"true"}` when healthy
4. `curl -s http://127.0.0.1:2379/livez` -- (v3.6+) liveness probe, 200 = process alive
5. `curl -s http://127.0.0.1:2379/readyz` -- (v3.6+) readiness probe, 200 = able to serve traffic
6. `etcdctl alarm list` -- empty when no alarms; `NOSPACE` alarm indicates quota exceeded

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `etcdserver: mvcc: database space exceeded` | Key history + fragmentation hit `--quota-backend-bytes` (default 2 GB) | Compact old revisions, defragment, disarm the NOSPACE alarm: `rev=$(etcdctl endpoint status -w json \| jq '.[0].Status.header.revision') && etcdctl compact $rev && etcdctl defrag --cluster && etcdctl alarm disarm` |
| `request timed out` / high latency | Slow disk (HDD or throttled cloud disk) | Move data dir to local SSD; etcd needs at least 50 sequential IOPS, ideally 500+ |
| `etcdserver: too many learner members in cluster` | Tried to add multiple learners before promoting | Promote existing learner with `etcdctl member promote` before adding another |
| Leader election churn / `leader changed` in logs | Clock skew, network partition, or resource starvation | Sync clocks (chrony/NTP); check inter-node latency on port 2380; verify CPU/memory not starved |
| `publish error: etcdserver: request timed out` on startup | Cluster lost quorum (majority of members down) | Restore from snapshot if quorum is permanently lost; otherwise bring enough members back online |
| `member X has already been bootstrapped` | Restarting with `--initial-cluster-state=new` on an existing data dir | Use `--initial-cluster-state=existing` or wipe the data dir for a fresh join |
| `authentication is not enabled` | Tried auth operation before `auth enable` | Create root user first, then `etcdctl auth enable` |
| TLS handshake failure between peers | Mismatched CA, expired cert, or missing SAN | Verify all peer certs are signed by the same CA with correct SANs; check `--peer-trusted-ca-file` |
| `apply request took too long` (>100 ms) | Disk I/O bottleneck or large value writes | Use SSD, reduce value sizes, enable auto-compaction |
| Kubernetes API server unreachable after etcd restore | Watch cache invalidation from revision jump | Restore with `etcdutl snapshot restore --bump-revision 1000000000 --mark-compacted` |

## Pain Points

- **Default quota is 2 GB and alarms are cluster-wide.** When any member hits the space quota, the entire cluster rejects writes until the NOSPACE alarm is cleared. Set `--quota-backend-bytes` appropriately for your workload (max recommended: 8 GB) and enable `--auto-compaction-retention` from day one.
- **Compaction does not reclaim disk space.** Compaction marks old revisions as deleted, but the freed pages stay allocated in the BoltDB file. You must defragment after compacting to actually shrink the file. Defrag blocks reads and writes on the target member, so run it during maintenance windows or stagger across members.
- **Snapshot restore creates a new cluster.** A restored snapshot initializes a brand-new cluster with new member IDs. Every member must restore the same snapshot independently; you cannot restore one member and have others catch up via Raft.
- **v3.6 removed several etcdctl subcommands.** `etcdctl snapshot restore`, `etcdctl snapshot status`, and `etcdctl defrag --data-dir` are gone in v3.6. Use `etcdutl` for all offline operations. Check which binary your scripts call before upgrading.
- **v2 API is dead.** The `--enable-v2` flag was removed in v3.6. If anything still uses the v2 API, migrate before upgrading. Kubernetes dropped v2 store dependency in 1.24.
- **Adding a member to a 1-node cluster blocks until the new member starts.** The cluster goes from 1/1 quorum to 1/2 (no quorum) the moment `member add` runs. Start the new member immediately, or add it as a learner first (v3.4+) to avoid downtime.
- **Discovery service is deprecated.** The public https://discovery.etcd.io service is no longer maintained. For dynamic bootstrapping use DNS SRV records or a custom discovery endpoint.

## See Also

- `kubernetes` -- etcd is the backing store for all Kubernetes cluster state; K8s etcd administration is a core operational skill
- `vault` -- HashiCorp Vault can use etcd as a storage backend (though Raft integrated storage is now preferred)

## References

See `references/` for:
- `docs.md` -- verified official documentation links
- `common-patterns.md` -- cluster setup, TLS configuration, snapshot/restore, authentication, Kubernetes etcd operations, compaction and defragmentation workflows
- `etcd.conf.yaml.annotated` -- annotated YAML config covering member, networking, clustering, TLS, auto-compaction, and logging options with defaults and guidance
