---
name: redis
description: >
  Redis in-memory data store administration: configuration, key operations,
  memory management, persistence, replication, and troubleshooting. Triggers
  on: redis, Redis cache, redis-cli, redis sentinel, redis cluster,
  key-value store, redis queue, session store redis.
globs:
  - "**/redis.conf"
  - "**/redis/**/*.conf"
---

## Identity
- **Unit**: `redis-server.service`
- **Config**: `/etc/redis/redis.conf`
- **Logs**: `journalctl -u redis-server`, `/var/log/redis/redis-server.log`
- **Data dir**: `/var/lib/redis/`
- **Socket**: `/run/redis/redis-server.sock` (if unixsocket enabled)
- **Distro install**: `apt install redis-server` / `dnf install redis`

## Key Operations

| Operation | Command | Notes |
|-----------|---------|-------|
| Service status | `systemctl status redis-server` | Unit name is `redis` on RHEL |
| Connect (TCP) | `redis-cli -h 127.0.0.1 -p 6379` | Add `-a <password>` or use `AUTH` after connecting |
| Connect (socket) | `redis-cli -s /run/redis/redis-server.sock` | Faster; requires local access |
| Ping server | `redis-cli PING` | Returns `PONG`; use to verify connectivity |
| Set a key | `redis-cli SET mykey "value"` | Add `EX 60` for 60-second TTL |
| Get a key | `redis-cli GET mykey` | Returns `(nil)` if key doesn't exist |
| Delete a key | `redis-cli DEL mykey` | Accepts multiple keys; returns count deleted |
| List all keys (dev only) | `redis-cli KEYS '*'` | O(N) — blocks server; never use on prod |
| Safe key scan (prod) | `redis-cli --scan --pattern 'prefix:*'` | Uses SCAN internally; non-blocking |
| Check memory usage | `redis-cli INFO memory` | Look at `used_memory_human` and `maxmemory` |
| Memory per key | `redis-cli MEMORY USAGE mykey` | Returns bytes including overhead |
| Flush current database | `redis-cli FLUSHDB` | **DESTRUCTIVE** — deletes all keys in DB 0 |
| Flush all databases | `redis-cli FLUSHALL` | **DESTRUCTIVE** — deletes every key in every DB |
| Full server info | `redis-cli INFO all` | Stats, replication, clients, memory, keyspace |
| Monitor live commands | `redis-cli MONITOR` | **High overhead** — only for short debugging sessions |
| Check slow log | `redis-cli SLOWLOG GET 10` | Last 10 slow commands; threshold set by `slowlog-log-slower-than` |
| Config get (runtime) | `redis-cli CONFIG GET maxmemory` | Read any directive without restarting |
| Config set (runtime) | `redis-cli CONFIG SET maxmemory 512mb` | Applies immediately; not persisted unless `CONFIG REWRITE` follows |
| Persist runtime config | `redis-cli CONFIG REWRITE` | Writes current runtime values back to redis.conf |
| Background save (RDB) | `redis-cli BGSAVE` | Fork-based; non-blocking for clients |
| Foreground save | `redis-cli SAVE` | Blocks all clients until complete — avoid in production |
| Replication info | `redis-cli INFO replication` | Role, replica count, replication offset, lag |
| Keyspace stats | `redis-cli INFO keyspace` | Per-database key counts, expires, avg TTL |
| Real-time stats | `redis-cli --stat` | One-line rolling stats every second |

## Expected Ports
- **6379/tcp** — default Redis port
- **16379/tcp** — cluster bus port (Redis Cluster only; always `data-port + 10000`)
- Verify: `ss -tlnp | grep redis`
- Firewall: Redis should **not** be exposed to the internet. Bind to `127.0.0.1` or use `requirepass` + firewall rules.

## Health Checks
1. `systemctl is-active redis-server` → `active`
2. `redis-cli PING` → `PONG`
3. `redis-cli INFO server | grep redis_version` → version string present
4. `redis-cli INFO memory | grep used_memory_human` → reports current usage without OOM errors

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `NOAUTH Authentication required` | Client not sending password | Pass `-a <password>` to redis-cli, or run `AUTH <password>` after connecting |
| `OOM command not allowed` | `maxmemory` reached with non-evicting policy | Set `maxmemory` and `maxmemory-policy` in redis.conf; `CONFIG SET` for immediate effect |
| `MISCONF Redis is configured to save RDB snapshots but it is currently not able to persist` | RDB write failed (usually disk full or permissions) | Check `df -h` on data dir; check `ls -la /var/lib/redis/`; verify redis user owns the dir |
| `KEYS` command slows/hangs prod | O(N) scan blocks entire server | Replace with `SCAN`; add `rename-command KEYS ""` in config to disable |
| Unexpected key eviction | Wrong `maxmemory-policy` for use case | Review policy: `allkeys-lru` evicts any key; `volatile-lru` only keys with TTL |
| Latency spikes every few minutes | Transparent huge pages (THP) enabled | `echo never > /sys/kernel/mm/transparent_hugepage/enabled`; make persistent via rc.local or systemd unit |
| `ERR max number of clients reached` | `maxclients` limit hit | `redis-cli INFO clients`; raise `maxclients` in config; check for connection leaks |
| AOF rewrite fails | `auto-aof-rewrite-percentage` triggered but fork fails | Check `vm.overcommit_memory` — must be 1: `sysctl vm.overcommit_memory=1` |
| Replica not connecting | `masterauth` not set on replica | Replica needs `masterauth <password>` matching master's `requirepass` |

## Pain Points
- **KEYS is O(N) and blocks**: On a database with millions of keys, `KEYS *` can block Redis for seconds. Use `SCAN` with a cursor in production. Add `rename-command KEYS ""` to config to make it impossible to run accidentally.
- **`maxmemory-policy` default is `noeviction`**: Without setting a policy, Redis returns errors when maxmemory is reached instead of evicting old data. For pure cache use cases, set `allkeys-lru`. For mixed persistence + cache, set `volatile-lru` and ensure cache keys have TTLs.
- **Persistence modes are mutually exclusive in impact**: RDB gives point-in-time snapshots with low overhead but risks losing up to `save` interval of data. AOF logs every write for near-zero data loss but uses more disk. Running both provides the best durability but doubles I/O. Choose based on acceptable data loss window.
- **No authentication by default**: Fresh installs have `requirepass` commented out. Anyone with network access to port 6379 has full access. Always set a password or bind exclusively to `127.0.0.1` before exposing any service on the same host.
- **`vm.overcommit_memory` must be 1 for BGSAVE**: Linux's default overcommit behavior can cause BGSAVE (and AOF rewrites) to fail with "Cannot allocate memory" even when physical + swap is sufficient. Set `sysctl -w vm.overcommit_memory=1` and persist in `/etc/sysctl.conf`.
- **ACL system replaces requirepass in Redis 6+**: The `ACL` system (Redis 6+) allows per-user permissions and command restrictions. `requirepass` still works but sets the default user's password. For multi-tenant or security-sensitive deployments, use an `aclfile` with explicit user rules instead.

## References
See `references/` for:
- `redis.conf.annotated` — complete config file with every directive explained
- `common-patterns.md` — cache setup, queues, sessions, replication, Sentinel, and ACL examples
- `docs.md` — official documentation links
