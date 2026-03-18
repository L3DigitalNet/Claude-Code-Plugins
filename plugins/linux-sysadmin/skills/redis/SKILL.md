---
name: redis
description: >
  Redis in-memory data store administration: configuration, key operations,
  memory management, persistence, replication, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting redis.
triggerPhrases:
  - "redis"
  - "Redis cache"
  - "redis-cli"
  - "redis sentinel"
  - "redis cluster"
  - "key-value store"
  - "redis queue"
  - "session store redis"
globs:
  - "**/redis.conf"
  - "**/redis/**/*.conf"
last_verified: "unverified"
---

## Identity
- **Unit**: `redis-server.service`
- **Config**: `/etc/redis/redis.conf`
- **Logs**: `journalctl -u redis-server`, `/var/log/redis/redis-server.log`
- **Data dir**: `/var/lib/redis/`
- **Socket**: `/run/redis/redis-server.sock` (if unixsocket enabled)
- **Distro install**: `apt install redis-server` / `dnf install redis`

## Quick Start

```bash
sudo apt install redis-server          # install Redis
sudo systemctl enable redis-server     # enable on boot
sudo systemctl start redis-server      # start the service
redis-cli PING                         # should return PONG
redis-cli INFO server | grep redis_version  # verify version
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status redis-server` |
| Connect (TCP) | `redis-cli -h 127.0.0.1 -p 6379` |
| Connect (socket) | `redis-cli -s /run/redis/redis-server.sock` |
| Ping server | `redis-cli PING` |
| Set a key | `redis-cli SET mykey "value"` |
| Get a key | `redis-cli GET mykey` |
| Delete a key | `redis-cli DEL mykey` |
| List all keys (dev only) | `redis-cli KEYS '*'` |
| Safe key scan (prod) | `redis-cli --scan --pattern 'prefix:*'` |
| Check memory usage | `redis-cli INFO memory` |
| Memory per key | `redis-cli MEMORY USAGE mykey` |
| Flush current database | `redis-cli FLUSHDB` |
| Flush all databases | `redis-cli FLUSHALL` |
| Full server info | `redis-cli INFO all` |
| Monitor live commands | `redis-cli MONITOR` |
| Check slow log | `redis-cli SLOWLOG GET 10` |
| Config get (runtime) | `redis-cli CONFIG GET maxmemory` |
| Config set (runtime) | `redis-cli CONFIG SET maxmemory 512mb` |
| Persist runtime config | `redis-cli CONFIG REWRITE` |
| Background save (RDB) | `redis-cli BGSAVE` |
| Foreground save | `redis-cli SAVE` |
| Replication info | `redis-cli INFO replication` |
| Keyspace stats | `redis-cli INFO keyspace` |
| Real-time stats | `redis-cli --stat` |

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

| Symptom | Cause | Fix |
|---------|-------|-----|
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

## See Also

- **mariadb** — Relational database that Redis commonly fronts as a caching layer
- **postgresql** — Relational database frequently paired with Redis for session and cache storage

## References
See `references/` for:
- `redis.conf.annotated` — complete config file with every directive explained
- `common-patterns.md` — cache setup, queues, sessions, replication, Sentinel, and ACL examples
- `docs.md` — official documentation links
