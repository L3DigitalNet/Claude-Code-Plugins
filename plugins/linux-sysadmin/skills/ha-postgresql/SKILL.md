---
name: ha-postgresql
description: >
  High-availability PostgreSQL deployment — Patroni automatic failover, etcd
  distributed consensus, HAProxy connection routing, and streaming replication.
  End-to-end HA cluster setup.
  MUST consult when installing, configuring, or troubleshooting high-availability PostgreSQL (Patroni/etcd/HAProxy).
triggerPhrases:
  - "HA PostgreSQL"
  - "PostgreSQL high availability"
  - "PostgreSQL cluster"
  - "Patroni setup"
  - "PostgreSQL failover"
  - "database HA"
  - "PostgreSQL replication"
  - "postgres cluster"
last_verified: "2026-03"
---

## Overview

A production HA PostgreSQL cluster requires four cooperating components. Each handles one concern; together they provide automatic failover, connection routing, and data durability.

```
                        ┌─────────────┐
                        │   Clients   │
                        └──────┬──────┘
                               │
                    ┌──────────┴──────────┐
                    │      HAProxy        │
                    │  :5000 read-write   │
                    │  :5001 read-only    │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
   ┌────────┴────────┐ ┌──────┴────────┐ ┌───────┴───────┐
   │  Patroni node1  │ │ Patroni node2 │ │ Patroni node3 │
   │  (Leader)       │ │ (Replica)     │ │ (Replica)     │
   │  PostgreSQL     │ │ PostgreSQL    │ │ PostgreSQL    │
   │  :5432 + :8008  │ │ :5432 + :8008│ │ :5432 + :8008│
   └────────┬────────┘ └──────┬────────┘ └───────┬───────┘
            │                  │                  │
            │     streaming replication           │
            │       (WAL shipping)                │
            │                  │                  │
   ┌────────┴──────────────────┴──────────────────┴───────┐
   │                     etcd cluster                     │
   │            (leader election + DCS state)             │
   │         node1:2379    node2:2379    node3:2379        │
   └──────────────────────────────────────────────────────┘
```

## Components

**PostgreSQL** is the database. Each node runs an identical PostgreSQL instance; one is promoted to primary (read-write), the others stream WAL from it as hot standbys (read-only).

**Patroni** manages the PostgreSQL lifecycle on each node. It handles bootstrap, replication setup, health monitoring, and automatic leader election. When the primary fails, Patroni promotes the most up-to-date replica and reconfigures the others to follow the new primary. Patroni exposes a REST API on port 8008 that reports each node's role.

**etcd** provides distributed consensus. Patroni stores its leader lock and cluster state in etcd using a TTL-based lease. The leader must renew this lease every `loop_wait` seconds; if it fails, the remaining Patroni nodes race to acquire the lock and promote their replica. etcd requires a quorum (2 of 3 nodes) to function.

**HAProxy** routes client connections to the correct PostgreSQL node. It polls each Patroni REST API endpoint (`/primary` for writes, `/replica` for reads) via HTTP health checks and directs traffic accordingly. Applications connect to HAProxy, never directly to PostgreSQL nodes.

## Prerequisites

- **3 nodes minimum** (can co-locate etcd + Patroni + PostgreSQL on the same hosts for small clusters, or separate them for larger deployments)
- **OS**: Debian 12+ / Ubuntu 22.04+ / RHEL 9+ (any Linux with systemd)
- **PostgreSQL**: 14+ recommended (16 preferred for logical replication slot failover)
- **Network**: All nodes must reach each other on ports 2379-2380 (etcd), 5432 (PostgreSQL), 8008 (Patroni REST API)
- **Firewall**: Open TCP 2379, 2380, 5432, 8008 between cluster nodes; open 5000, 5001 on the HAProxy host for clients
- **NTP**: Time must be synchronized across all nodes (Patroni's TTL-based leader lease is time-sensitive)
- **Disk**: Fast storage for PostgreSQL data dirs and etcd (SSD strongly recommended; etcd is fsync-heavy)

## Quick Start

Condensed 3-node setup. For full configs with all options explained, see `references/common-patterns.md`.

```bash
# --- On all 3 nodes ---
# 1. Install PostgreSQL 16
sudo apt-get install -y postgresql-16 postgresql-client-16

# 2. Stop and disable the default PostgreSQL service (Patroni will manage it)
sudo systemctl stop postgresql
sudo systemctl disable postgresql

# 3. Install etcd
sudo apt-get install -y etcd

# 4. Install Patroni
sudo pip install patroni[etcd3] psycopg2-binary

# 5. Install HAProxy (on the HAProxy host, or all 3 for redundancy)
sudo apt-get install -y haproxy

# --- Configure etcd on each node (see references/common-patterns.md for full config) ---
# Edit /etc/default/etcd with node-specific IPs, then:
sudo systemctl enable --now etcd
etcdctl endpoint health --cluster

# --- Configure Patroni on each node ---
sudo mkdir -p /etc/patroni
# Deploy node-specific patroni.yml (see references/common-patterns.md)
sudo systemctl enable --now patroni
patronictl -c /etc/patroni/patroni.yml list

# --- Configure HAProxy ---
# Deploy haproxy.cfg with Patroni health check backends (see references/common-patterns.md)
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy

# --- Verify ---
# Connect through HAProxy (writes)
psql -h haproxy-host -p 5000 -U admin -d postgres -c "SELECT pg_is_in_recovery();"
# Should return 'f' (false = primary)

# Connect through HAProxy (reads)
psql -h haproxy-host -p 5001 -U admin -d postgres -c "SELECT pg_is_in_recovery();"
# Should return 't' (true = replica)
```

## Data Flow

### Write Path

1. Client connects to HAProxy port 5000
2. HAProxy checks each node's `GET /primary` endpoint (Patroni REST API on port 8008)
3. Only the current leader returns HTTP 200; replicas return 503
4. HAProxy forwards the TCP connection to the leader's PostgreSQL port 5432
5. PostgreSQL processes the write and streams WAL to replicas via streaming replication

### Read Path

1. Client connects to HAProxy port 5001
2. HAProxy checks each node's `GET /replica` endpoint
3. Replicas return HTTP 200; the leader returns 503
4. HAProxy distributes connections across healthy replicas using round-robin
5. Read queries execute against hot standby replicas (slight lag, typically sub-second)

### Failover Sequence

1. The leader's Patroni process crashes, loses network, or the PostgreSQL process dies
2. The leader fails to renew its etcd lease within the TTL (default 30 seconds)
3. The etcd lease expires; the leader key is deleted
4. Remaining Patroni nodes detect the missing leader and start a leader race
5. Each candidate checks its replication position; the most up-to-date replica (within `maximum_lag_on_failover`) acquires the etcd lock
6. The winning node promotes its PostgreSQL to primary via `pg_promote()`
7. Other replicas reconfigure to stream from the new primary (using `pg_rewind` if they diverged)
8. HAProxy detects the role change via health checks within 3-10 seconds (depending on `inter` setting)
9. New write connections route to the promoted node; existing connections to the old leader are dropped

## Integration Points

### Patroni and etcd (DCS)

Patroni stores its cluster state under `/service/<scope>/` in etcd. The leader holds a lease-based key that must be renewed every `loop_wait` seconds (default 10). If the lease expires after `ttl` seconds (default 30), any healthy node can claim leadership.

Critical timing constraint: `ttl > loop_wait + 2 * retry_timeout`. Violating this causes spurious failovers.

etcd must maintain quorum (majority of nodes) for Patroni to function. If etcd loses quorum, Patroni demotes all primaries to read-only as a safety measure. Enable `failsafe_mode` (Patroni 3.0+) to allow the primary to remain writable when it can still reach all Patroni peers via REST API.

### Patroni and PostgreSQL (Streaming Replication)

Patroni manages `postgresql.conf`, `pg_hba.conf`, and the PostgreSQL process lifecycle. It configures streaming replication slots, handles `pg_basebackup` for new replicas, and uses `pg_rewind` to rejoin diverged former primaries.

Never manage PostgreSQL directly (`pg_ctl`, `systemctl restart postgresql`, or manual `pg_promote()`) on a Patroni-managed cluster. Patroni expects exclusive control.

### HAProxy and Patroni (REST API Health Checks)

HAProxy uses HTTP health checks against the Patroni REST API to determine each node's role. The key endpoints:

| HAProxy Backend | Patroni Endpoint | HTTP 200 When |
|-----------------|-------------------|---------------|
| Read-write (port 5000) | `GET /primary` | Node is the current leader |
| Read-only (port 5001) | `GET /replica` | Node is a healthy replica |
| Sync replica only | `GET /synchronous` | Node is a synchronous standby |
| Lag-aware reads | `GET /replica?lag=100MB` | Replica within specified lag |

Do not use TCP health checks against PostgreSQL port 5432. A PostgreSQL process that is starting up or in recovery will accept TCP connections but reject queries, causing application errors.

### Optional: PgBouncer Connection Pooling

PgBouncer sits between HAProxy and PostgreSQL on each node (or co-located with HAProxy). It pools connections, reducing PostgreSQL backend process overhead. Configuration is straightforward: point PgBouncer at localhost:5432 and HAProxy at PgBouncer's port instead of PostgreSQL's.

## Operational Procedures

### Planned Switchover

Move the primary role to a specific replica with minimal downtime (typically 1-3 seconds).

```bash
# Verify cluster health first
patronictl -c /etc/patroni/patroni.yml list

# Switchover to a specific node
patronictl -c /etc/patroni/patroni.yml switchover \
    --leader node1 --candidate node2 --force

# Schedule for a maintenance window
patronictl -c /etc/patroni/patroni.yml switchover \
    --leader node1 --candidate node2 \
    --scheduled "2026-03-15T02:00:00+00:00" --force

# Verify the new leader
patronictl -c /etc/patroni/patroni.yml list
```

### Emergency Failover

Force-promote a replica when the current primary is unrecoverable.

```bash
# Confirm no leader exists
patronictl -c /etc/patroni/patroni.yml list

# Failover to the best candidate
patronictl -c /etc/patroni/patroni.yml failover --candidate node2 --force

# Verify
patronictl -c /etc/patroni/patroni.yml list
```

### Adding a Node

```bash
# 1. Install PostgreSQL + Patroni on the new node
# 2. Configure patroni.yml with a unique name and the existing etcd endpoints
# 3. Start Patroni — it will automatically pg_basebackup from the current leader
sudo systemctl enable --now patroni

# 4. Add the new node to HAProxy backends and reload
sudo systemctl reload haproxy

# 5. Verify
patronictl -c /etc/patroni/patroni.yml list
```

### Backup Strategy

Patroni does not handle backups. Use standard PostgreSQL backup tools alongside the HA cluster.

```bash
# pg_basebackup from the leader (or a replica to reduce primary load)
pg_basebackup -h haproxy-host -p 5001 -U replicator -D /backups/base -Fp -Xs -P

# pgBackRest or Barman for continuous archiving + point-in-time recovery
# Configure WAL archiving in patronictl edit-config:
#   postgresql.parameters.archive_mode: "on"
#   postgresql.parameters.archive_command: "pgbackrest --stanza=main archive-push %p"
```

### Maintenance Mode

Pause automatic failover during planned maintenance.

```bash
patronictl -c /etc/patroni/patroni.yml pause --wait
# ... perform maintenance ...
patronictl -c /etc/patroni/patroni.yml resume --wait
```

## See Also

- **postgresql** -- PostgreSQL configuration, tuning, and query optimization
- **patroni** -- Detailed Patroni configuration, patronictl commands, REST API endpoints
- **etcd** -- etcd cluster setup, maintenance, backup, and monitoring
- **haproxy** -- HAProxy configuration, ACLs, stats, and SSL termination

## References

See `references/` for:
- `common-patterns.md` -- Full 3-node setup walkthrough: etcd cluster config, Patroni config per node, HAProxy config with health check backends, PgBouncer optional layer
- `docs.md` -- Links to official documentation for all components
