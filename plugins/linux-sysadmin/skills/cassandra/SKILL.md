---
name: cassandra
description: >
  Apache Cassandra distributed database administration: nodetool operations,
  CQL shell, keyspace and table management, replication strategies, consistency
  levels, compaction, repair, snitch configuration, backup/restore, and cluster
  maintenance.
  MUST consult when installing, configuring, or troubleshooting cassandra.
triggerPhrases:
  - "cassandra"
  - "Cassandra"
  - "cqlsh"
  - "nodetool"
  - "CQL"
  - "cassandra.yaml"
  - "keyspace"
  - "consistency level"
  - "compaction"
  - "sstable"
  - "cassandra repair"
  - "cassandra cluster"
  - "gossip"
  - "snitch"
  - "replication factor"
  - "cassandra snapshot"
globs:
  - "**/cassandra.yaml"
  - "**/cassandra-env.sh"
  - "**/cassandra-rackdc.properties"
  - "**/cassandra-topology.properties"
  - "**/*.cql"
last_verified: "2026-03"
---

## Identity

- **Binary**: `cassandra` (server), `cqlsh` (CQL shell), `nodetool` (admin CLI)
- **Unit**: `cassandra.service`
- **Config**: `/etc/cassandra/cassandra.yaml` (main), `/etc/cassandra/cassandra-env.sh` (JVM), `/etc/cassandra/cassandra-rackdc.properties` (DC/rack)
- **Data dir**: `/var/lib/cassandra/data/` (SSTables)
- **Commitlog**: `/var/lib/cassandra/commitlog/`
- **Saved caches**: `/var/lib/cassandra/saved_caches/`
- **Hints**: `/var/lib/cassandra/hints/`
- **Logs**: `/var/log/cassandra/system.log`, `journalctl -u cassandra`
- **Install**: `apt install cassandra` / `dnf install cassandra` (or tarball from cassandra.apache.org)

## Quick Start

```bash
sudo apt install cassandra
sudo systemctl enable --now cassandra

# Wait for startup (CQL native transport ready)
until cqlsh -e 'DESCRIBE CLUSTER' 2>/dev/null; do sleep 2; done

# Check node status
nodetool status

# Connect to CQL shell
cqlsh
```

## Key Operations

| Task | Command |
|------|---------|
| Cluster status | `nodetool status` |
| Node info | `nodetool info` |
| Ring topology | `nodetool ring` |
| Describe cluster | `nodetool describecluster` |
| Table statistics | `nodetool tablestats <keyspace>.<table>` |
| Thread pool stats | `nodetool tpstats` |
| Compaction stats | `nodetool compactionstats` |
| Network stats | `nodetool netstats` |
| Run repair | `nodetool repair <keyspace>` |
| Run repair (full) | `nodetool repair -full <keyspace>` |
| Force compaction | `nodetool compact <keyspace> <table>` |
| Cleanup after topology change | `nodetool cleanup <keyspace>` |
| Drain before shutdown | `nodetool drain` |
| Decommission node | `nodetool decommission` |
| Take snapshot | `nodetool snapshot -t <tag> <keyspace>` |
| List snapshots | `nodetool listsnapshots` |
| Clear snapshot | `nodetool clearsnapshot -t <tag>` |
| Flush memtables | `nodetool flush <keyspace>` |
| Enable incremental backup | `nodetool enablebackup` |
| CQL shell connect | `cqlsh <host> <port>` (default: localhost 9042) |
| CQL shell with auth | `cqlsh -u <user> -p <password>` |
| Set consistency in cqlsh | `CONSISTENCY QUORUM;` |
| Describe schema | `DESCRIBE SCHEMA;` or `DESCRIBE KEYSPACE <name>;` |
| Tracing | `TRACING ON;` then run query |
| Export data | `COPY <table> TO '/path/data.csv';` |
| Import data | `COPY <table> FROM '/path/data.csv';` |

## Expected Ports

- **9042/tcp** -- CQL native transport (client connections)
- **7000/tcp** -- Inter-node cluster communication (gossip)
- **7001/tcp** -- Inter-node TLS communication (ssl_storage_port)
- **7199/tcp** -- JMX monitoring
- **9160/tcp** -- Thrift client (legacy, disabled by default in v4+)
- Verify: `ss -tlnp | grep -E '9042|7000|7001|7199'`
- Firewall: open 9042 for clients, 7000/7001 between cluster nodes only

## Health Checks

1. `systemctl is-active cassandra` -> `active`
2. `nodetool status` -> all nodes show `UN` (Up/Normal)
3. `cqlsh -e 'DESCRIBE CLUSTER'` -> returns cluster name without error
4. `nodetool info` -> shows Uptime, Load, and Gossip active = true

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Node shows `DN` in `nodetool status` | Node down or gossip failure | Check `journalctl -u cassandra` on affected node; verify network between nodes |
| `NoHostAvailableException` from client | All seeds unreachable or auth failure | Verify seeds in `cassandra.yaml`; check firewall on 9042; verify credentials |
| `WriteTimeoutException` | Too few replicas responded within timeout | Check `nodetool status` for downed nodes; verify consistency level vs replication factor |
| `ReadTimeoutException` | Slow disk or too many tombstones | `nodetool tablestats` to check tombstone count; run repair; tune `read_request_timeout` |
| High compaction pending | Write-heavy workload or wrong compaction strategy | `nodetool compactionstats`; consider switching to LeveledCompactionStrategy for read-heavy, SizeTieredCompactionStrategy for write-heavy |
| Commitlog disk full | Commitlog directory on small partition | Move commitlog to larger disk via `commitlog_directory` in cassandra.yaml |
| `GC overhead limit exceeded` | Heap too small for workload | Increase MAX_HEAP_SIZE in cassandra-env.sh; check for wide partitions |
| Schema disagreement | Nodes have different schema versions | `nodetool describecluster` shows schema versions; restart lagging node or run `nodetool resetlocalschema` |
| `Hinted handoff` backlog growing | Target node down too long | Bring target node back; check `max_hint_window_in_ms` (default 3h) |
| Repair takes forever | Large dataset without regular repair schedule | Use `--partitioner-range` for subrange repair; schedule incremental repairs via cron |

## Pain Points

- **Consistency levels are per-query, not per-cluster.** `ONE` is fast but risks stale reads. `QUORUM` balances consistency and availability. `ALL` gives strong consistency but any single node failure blocks the operation. Set the consistency level in cqlsh with `CONSISTENCY <level>;` or in your driver configuration.
- **Repair is mandatory, not optional.** Without regular repair, data diverges across replicas. Run `nodetool repair` on every node within `gc_grace_seconds` (default 10 days). If you skip repairs beyond gc_grace, tombstones expire and deleted data can resurrect.
- **Tombstones are the silent killer.** Deletes and TTL expirations create tombstones that accumulate until compaction removes them. Reading ranges with many tombstones triggers `TombstoneOverwhelmingException`. Avoid wide deletes; prefer TTL-based expiration with appropriate compaction.
- **Partition sizing matters.** Cassandra performs best with partitions under 100 MB. Wide partitions (millions of rows per partition key) cause slow reads, compaction pressure, and repair problems. Design your data model with bounded partition sizes.
- **Snitch must match your topology.** `GossipingPropertyFileSnitch` is the production default; it reads DC/rack from `cassandra-rackdc.properties`. For AWS, use `Ec2Snitch` (single region) or `Ec2MultiRegionSnitch`. Mismatched snitches cause data placement errors.
- **Seed nodes are for bootstrapping only.** Seeds are the initial contact points for new nodes joining the cluster. Every node does not need to be a seed; 2-3 per datacenter is sufficient. A node should not list itself as its own seed.

## See Also

- **mongodb** -- Document database; different consistency model (single-leader replication vs Cassandra's leaderless)
- **postgresql** -- Relational database; use when you need ACID transactions and complex joins that Cassandra doesn't support
- **redis** -- In-memory cache; often used alongside Cassandra to cache hot read paths

## References

See `references/` for:
- `common-patterns.md` -- keyspace creation, replication strategies, compaction tuning, backup/restore, repair scheduling, monitoring queries
- `docs.md` -- official documentation links
- `cassandra.yaml.annotated` -- annotated main configuration file covering cluster identity, seeds, networking, data directories, commitlog, memtable, compaction, concurrency, authentication, and internode/client encryption
