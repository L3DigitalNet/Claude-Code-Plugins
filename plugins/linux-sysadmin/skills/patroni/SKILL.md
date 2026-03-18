---
name: patroni
description: >
  Patroni PostgreSQL high-availability cluster management: DCS-backed leader
  election (etcd, Consul, ZooKeeper), bootstrap configuration, patronictl
  commands, switchover and failover, replica management with pg_rewind,
  REST API health checks, HAProxy/PgBouncer integration, and monitoring.
  MUST consult when installing, configuring, or troubleshooting patroni.
triggerPhrases:
  - "patroni"
  - "Patroni"
  - "patronictl"
  - "patroni switchover"
  - "patroni failover"
  - "PostgreSQL HA"
  - "PostgreSQL high availability"
  - "patroni REST API"
  - "patroni cluster"
  - "patroni bootstrap"
  - "patroni reinit"
  - "patroni pause"
  - "patroni.yml"
  - "pg_rewind patroni"
globs:
  - "**/patroni.yml"
  - "**/patroni.yaml"
  - "**/patroni/**/*.yml"
  - "**/patroni/**/*.yaml"
last_verified: "2026-03"
---

## Identity
- **Binary**: `patroni` (Python, installed via pip)
- **Version**: 4.1.0 (supports PostgreSQL 9.3 through 18)
- **Config**: `/etc/patroni/patroni.yml` (or path passed to `patroni` command)
- **Logs**: `journalctl -u patroni`, or stdout/stderr when running in foreground
- **Data dir**: managed by PostgreSQL; Patroni controls `$PGDATA` via its config
- **DCS backends**: etcd (v2/v3), Consul, ZooKeeper, Kubernetes (native), Exhibitor
- **Install**: `pip install patroni[etcd]` / `pip install patroni[consul]` / `pip install patroni[zookeeper]`
- **Systemd unit**: `/etc/systemd/system/patroni.service` (Type=simple, User=postgres)

## Quick Start

```bash
pip install patroni[etcd] psycopg2-binary          # install Patroni with etcd DCS support
sudo mkdir -p /etc/patroni
sudo cp patroni.yml /etc/patroni/patroni.yml        # deploy your config (see references/)
sudo cp patroni.service /etc/systemd/system/         # install systemd unit
sudo systemctl daemon-reload
sudo systemctl enable --now patroni                  # start Patroni
patronictl -c /etc/patroni/patroni.yml list          # verify cluster state
```

## Key Operations

| Task | Command |
|------|---------|
| List cluster members | `patronictl -c /etc/patroni/patroni.yml list` |
| Cluster topology (tree view) | `patronictl -c /etc/patroni/patroni.yml topology` |
| Planned switchover | `patronictl -c /etc/patroni/patroni.yml switchover --leader node1 --candidate node2` |
| Emergency failover | `patronictl -c /etc/patroni/patroni.yml failover --candidate node2` |
| Schedule a switchover | `patronictl -c /etc/patroni/patroni.yml switchover --scheduled "2026-03-15T02:00+00:00"` |
| Cancel scheduled switchover | `patronictl -c /etc/patroni/patroni.yml flush <cluster> switchover` |
| Edit dynamic config | `patronictl -c /etc/patroni/patroni.yml edit-config` |
| Show dynamic config | `patronictl -c /etc/patroni/patroni.yml show-config` |
| Restart PostgreSQL on a member | `patronictl -c /etc/patroni/patroni.yml restart <cluster> <member>` |
| Reload Patroni + PostgreSQL config | `patronictl -c /etc/patroni/patroni.yml reload <cluster> <member>` |
| Reinitialize a replica | `patronictl -c /etc/patroni/patroni.yml reinit <cluster> <member>` |
| Pause automatic failover | `patronictl -c /etc/patroni/patroni.yml pause --wait` |
| Resume automatic failover | `patronictl -c /etc/patroni/patroni.yml resume --wait` |
| Failover/switchover history | `patronictl -c /etc/patroni/patroni.yml history` |
| Get connection string | `patronictl -c /etc/patroni/patroni.yml dsn --role primary` |
| Run SQL on leader | `patronictl -c /etc/patroni/patroni.yml query <cluster> -r primary -c "SELECT 1;"` |
| Check versions | `patronictl -c /etc/patroni/patroni.yml version` |

## Expected Ports
- **8008/tcp** -- Patroni REST API (configurable via `restapi.listen` in patroni.yml)
- **5432/tcp** -- PostgreSQL (managed by Patroni)
- Verify: `ss -tlnp | grep -E '(patroni|postgres)'`
- The REST API port must be reachable from other Patroni nodes, HAProxy, and monitoring systems.

## Health Checks

1. `systemctl is-active patroni` -> `active`
2. `curl -s http://localhost:8008/health | jq .` -> HTTP 200 when PostgreSQL is running
3. `curl -s http://localhost:8008/primary` -> HTTP 200 on the current primary; 503 on replicas
4. `curl -s http://localhost:8008/replica` -> HTTP 200 on replicas; 503 on the primary
5. `patronictl -c /etc/patroni/patroni.yml list` -> all members show `running` state

### REST API Health Endpoints (for HAProxy / load balancers)

| Endpoint | Returns 200 when | Use case |
|----------|-------------------|----------|
| `/primary` or `/read-write` | Node is primary with leader lock | Route writes through HAProxy |
| `/replica` | Node is running replica, `noloadbalance` tag not set | Route reads through HAProxy |
| `/replica?lag=100MB` | Replica within specified replication lag | Lag-aware read routing |
| `/leader` | Node holds the leader lock (any mode) | Generic leader check |
| `/standby-leader` | Node is leader of a standby cluster | Standby cluster routing |
| `/sync` or `/synchronous` | Node is synchronous standby | Route to sync replicas only |
| `/async` or `/asynchronous` | Node is asynchronous standby | Route to async replicas only |
| `/read-only` | Node is readable (includes primary) | Read-only routing |
| `/health` | PostgreSQL process is up | Basic liveness |
| `/liveness` | Patroni heartbeat loop is current | Kubernetes liveness probe |
| `/readiness` | Node is ready to serve traffic | Kubernetes readiness probe |
| `/metrics` | Always (Prometheus format) | Scrape with Prometheus |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `No cluster leader` / all nodes read-only | DCS (etcd/Consul/ZK) is down or unreachable | Restore DCS connectivity; check `etcdctl endpoint health` or equivalent; consider enabling DCS failsafe mode |
| Leader lock expired, unexpected failover | Patroni heartbeat unable to renew within `ttl` (default 30s) | Check system load and DCS latency; tune `loop_wait`, `retry_timeout`, and `ttl`; ensure NTP is synchronized |
| Replica stuck in `start failed` | `pg_basebackup` failing (wrong replication credentials, disk full, or primary unreachable) | Check `patronictl list` for state; verify replication user password; check disk space; run `patronictl reinit` |
| Former primary won't rejoin as replica | Timeline diverged; `pg_rewind` not enabled or data checksums missing | Enable `use_pg_rewind: true` in config; ensure `wal_log_hints = on` or data checksums; run `patronictl reinit` to rebuild from scratch |
| `pg_rewind` fails with "could not find common ancestor" | WAL segments needed by pg_rewind have been removed | Set `wal_keep_size` high enough or use WAL archiving; fall back to `patronictl reinit` |
| Switchover fails with "no suitable candidate" | No replica is healthy or caught up within `maximum_lag_on_failover` | Check replica lag with `patronictl list`; reduce lag or increase `maximum_lag_on_failover` in dynamic config |
| Split-brain (two primaries) | DCS partition with both sides electing a leader | This should not happen with a healthy DCS quorum; enable watchdog (`watchdog.mode: required`) for fencing; check DCS cluster health |
| REST API returns 503 on all endpoints | Patroni process crashed or config error | `journalctl -u patroni -n 100`; check YAML syntax; verify DCS connection settings |
| `patronictl` commands hang or timeout | Wrong `--dcs-url` or DCS unreachable | Pass explicit `-d etcd://host:2379` or fix the config file DCS section |

## Pain Points
- **DCS is a single point of failure for the cluster**: If the DCS cluster (etcd, Consul, ZK) loses quorum, Patroni demotes all primaries to read-only. Run the DCS as a 3- or 5-node cluster with nodes spread across failure domains. Enable `failsafe_mode` (Patroni 3.0+) to allow the primary to remain writable when it can reach all Patroni members via the REST API but cannot reach the DCS.
- **`switchover` requires a healthy cluster; `failover` does not**: `patronictl switchover` works only when a leader exists and the target candidate is caught up. For an unhealthy cluster with no leader, use `patronictl failover` instead. Confusing the two is a common mistake.
- **`use_pg_rewind` requires data checksums or `wal_log_hints`**: Without one of these, a former primary that has diverged cannot be rewound and must be rebuilt from scratch with `patronictl reinit`. Always enable `data-checksums` during bootstrap (`initdb` flags) or set `wal_log_hints: on` in PostgreSQL parameters.
- **Dynamic vs local config precedence**: Parameters in `patronictl edit-config` (dynamic, stored in DCS) override local `patroni.yml` settings for PostgreSQL GUCs. Changes to `postgresql.parameters` in the local file are ignored if the same key exists in the DCS dynamic config. Use `patronictl edit-config` for cluster-wide PostgreSQL tuning.
- **`ttl`, `loop_wait`, and `retry_timeout` interact**: The `ttl` (default 30s) is the leader lock lease duration. `loop_wait` (default 10s) is the Patroni HA-loop sleep interval. `retry_timeout` (default 10s) is how long Patroni retries DCS operations. If `loop_wait + retry_timeout >= ttl`, the leader can lose its lock before renewing. Keep `ttl > loop_wait + retry_timeout * 2` as a rule of thumb.
- **Never manage PostgreSQL directly**: Do not use `pg_ctl`, `systemctl restart postgresql`, or direct `pg_promote()` on a Patroni-managed cluster. Patroni expects exclusive control of the PostgreSQL lifecycle. Direct manipulation causes state desync, failed rejoin, or split-brain.
- **HAProxy health checks must use the REST API**: Point HAProxy at `/primary` for the read-write backend and `/replica` for the read backend. Do not use TCP checks against port 5432; a PostgreSQL process that is still starting or in recovery will accept TCP connections but reject queries.
- **Callback scripts run with limited context**: The `on_start`, `on_stop`, `on_role_change`, and `on_restart` callbacks run as the `postgres` OS user. They receive the action, role, and cluster name as arguments but have no access to the Patroni config object. Keep them simple (DNS update, monitoring notification) and test them outside Patroni first.

## See Also
- **postgresql** -- The database Patroni manages; understand PostgreSQL replication and configuration first
- **etcd** -- Most common DCS backend for Patroni; run a 3+ node etcd cluster
- **consul** -- Alternative DCS with service discovery; supports Patroni health check registration
- **haproxy** -- Standard load balancer fronting Patroni clusters; uses REST API health checks for routing

## References
See `references/` for:
- `common-patterns.md` -- bootstrap config, HAProxy integration, switchover/failover workflows, monitoring setup, and pg_rewind configuration
- `docs.md` -- official documentation links
