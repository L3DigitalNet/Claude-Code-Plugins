# Redis Common Patterns

Each section below is a complete, copy-paste-ready example. Commands can be run
directly in `redis-cli` or via any Redis client library.

---

## 1. Cache Setup (maxmemory + Eviction Policy)

Configure Redis as a pure cache: evict old keys automatically when memory is full.
Apply either via `redis.conf` (persistent) or `CONFIG SET` (runtime, no restart needed).

```bash
# Runtime (takes effect immediately):
redis-cli CONFIG SET maxmemory 512mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
redis-cli CONFIG SET maxmemory-samples 10

# Persist the runtime config back to redis.conf:
redis-cli CONFIG REWRITE
```

In `redis.conf`:
```
maxmemory 512mb
maxmemory-policy allkeys-lru
maxmemory-samples 10
```

Policy selection:
- `allkeys-lru` — evict any key by LRU. Use this for pure caches where all data
  is reproducible.
- `volatile-lru` — evict only keys that have a TTL set. Use when some keys must
  never be evicted (no TTL) and others are ephemeral.
- `allkeys-lfu` — LFU instead of LRU; better when access patterns are skewed
  (a few hot keys, many cold ones).

Disable RDB snapshots for pure cache (no need to persist data that will be regenerated):
```
# Comment out all save lines in redis.conf:
# save 3600 1
# save 300 100
# save 60 10000
```

---

## 2. Persistent Queue (List-Based LPUSH/BRPOP)

Redis lists implement a reliable FIFO queue. Producers push to one end; consumers
block-wait on the other. BRPOP blocks until an item arrives, eliminating polling.

```bash
# Producer: push a job onto the queue (left side)
redis-cli LPUSH jobs:email '{"to":"user@example.com","subject":"Welcome"}'

# Consumer: blocking pop from the queue (right side), 30-second timeout
# Returns [queue-name, value] or nil on timeout
redis-cli BRPOP jobs:email 30

# Check queue depth
redis-cli LLEN jobs:email

# Peek without removing (index 0 = oldest item at right, -1 = newest at left)
redis-cli LRANGE jobs:email 0 9
```

For reliable processing (no message loss if consumer crashes), use the
BRPOPLPUSH pattern to move items to a "processing" list atomically:

```bash
# Atomically move from jobs:email to jobs:processing and return the item
redis-cli BRPOPLPUSH jobs:email jobs:processing 30

# After successful processing, remove from the processing list
redis-cli LREM jobs:processing 1 '<the-item-value>'

# On crash recovery: items stuck in jobs:processing can be requeued
redis-cli LRANGE jobs:processing 0 -1
```

Note: BRPOPLPUSH is deprecated in Redis 6.2 — use BLMOVE instead:
```bash
redis-cli BLMOVE jobs:email jobs:processing RIGHT LEFT 30
```

---

## 3. Session Storage Configuration

Store web sessions with automatic expiry. Each session is a hash keyed by session ID.

```bash
# Store a session (hash with per-field values)
redis-cli HSET session:abc123 user_id 42 email "user@example.com" role "admin"

# Set TTL: session expires after 3600 seconds (1 hour)
redis-cli EXPIRE session:abc123 3600

# Read session data
redis-cli HGETALL session:abc123

# Read a single field
redis-cli HGET session:abc123 user_id

# Update a field without resetting other fields
redis-cli HSET session:abc123 last_seen "2024-01-15T10:30:00Z"

# Reset TTL on activity (slide the expiry window)
redis-cli EXPIRE session:abc123 3600

# Destroy a session
redis-cli DEL session:abc123

# Check remaining TTL (returns -1 if no expiry, -2 if key doesn't exist)
redis-cli TTL session:abc123
```

In `redis.conf`, use `volatile-lru` eviction so only sessions (which have TTLs)
are evicted under memory pressure, leaving non-TTL keys intact:
```
maxmemory-policy volatile-lru
```

---

## 4. Pub/Sub Basic Usage

Redis pub/sub is fire-and-forget messaging: messages are not persisted and are
only delivered to currently connected subscribers. Use Redis Streams for durable
message delivery.

```bash
# Terminal 1: Subscribe to a channel (blocks, waiting for messages)
redis-cli SUBSCRIBE notifications:user:42

# Terminal 2: Publish a message (returns number of subscribers that received it)
redis-cli PUBLISH notifications:user:42 '{"type":"friend_request","from":99}'

# Subscribe to multiple channels
redis-cli SUBSCRIBE chan:a chan:b chan:c

# Subscribe to a pattern (psubscribe uses glob matching)
redis-cli PSUBSCRIBE notifications:user:*

# List active channels with at least one subscriber
redis-cli PUBSUB CHANNELS 'notifications:*'

# Count subscribers on a channel
redis-cli PUBSUB NUMSUB notifications:user:42
```

---

## 5. Rate Limiting (INCR + EXPIRE)

Limit an action to N occurrences per time window per key (e.g., per IP or user).

```bash
# Pattern: increment a counter with a TTL set on first creation.
# Returns the new count; caller decides whether to allow the action.
#
# Lua script ensures atomicity (INCR + EXPIRE as a single operation):
redis-cli EVAL "
  local key = KEYS[1]
  local limit = tonumber(ARGV[1])
  local window = tonumber(ARGV[2])
  local count = redis.call('INCR', key)
  if count == 1 then
    redis.call('EXPIRE', key, window)
  end
  return count
" 1 ratelimit:ip:192.168.1.1:login 5 60
# Returns current count. If count > 5, deny the request.
```

The plain INCR + EXPIRE approach (without Lua):
```bash
# Non-atomic version — race condition possible at key creation (acceptable for
# approximate rate limiting; use Lua for strict enforcement)
redis-cli INCR ratelimit:ip:192.168.1.1:login
redis-cli EXPIRE ratelimit:ip:192.168.1.1:login 60
redis-cli TTL  ratelimit:ip:192.168.1.1:login
```

For a sliding window, use a sorted set with timestamps:
```bash
# Add current request with timestamp as score
redis-cli ZADD ratelimit:sliding:user:42 1705312200 "req-uuid"

# Remove requests older than the window (60 seconds ago)
redis-cli ZREMRANGEBYSCORE ratelimit:sliding:user:42 0 1705312140

# Count requests in window
redis-cli ZCARD ratelimit:sliding:user:42

# Set TTL on the key so it auto-expires when idle
redis-cli EXPIRE ratelimit:sliding:user:42 60
```

---

## 6. Master-Replica Replication

One master accepts writes; one or more replicas receive async copies. Replicas serve
reads, providing horizontal read scaling and a manual failover target.

On the replica instance's `redis.conf`:
```
replicaof 192.168.1.10 6379
masterauth your-master-password
replica-read-only yes
```

Or set at runtime (takes effect immediately):
```bash
redis-cli -h 192.168.1.20 REPLICAOF 192.168.1.10 6379
redis-cli -h 192.168.1.20 CONFIG SET masterauth your-master-password
```

Verify replication is working:
```bash
# On master:
redis-cli INFO replication
# role:master
# connected_slaves:1
# slave0:ip=192.168.1.20,port=6379,state=online,offset=12345,lag=0

# On replica:
redis-cli -h 192.168.1.20 INFO replication
# role:slave
# master_host:192.168.1.10
# master_link_status:up
# master_last_io_seconds_ago:1
```

Manual failover (promote replica to master):
```bash
# On the replica — disconnects from master and becomes standalone master:
redis-cli -h 192.168.1.20 REPLICAOF NO ONE
```

---

## 7. Redis Sentinel for HA

Sentinel monitors a master and its replicas, automatically promotes a replica
when the master fails. Requires at least 3 Sentinel instances for quorum.

`/etc/redis/sentinel.conf` (same file on all 3 Sentinel nodes):
```
port 26379

# Monitor the master named "mymaster" at given IP:port.
# Quorum = 2: at least 2 Sentinels must agree the master is down before failover.
sentinel monitor mymaster 192.168.1.10 6379 2

# Master is considered down after no response for 5 seconds.
sentinel down-after-milliseconds mymaster 5000

# How long a failover attempt can take before giving up.
sentinel failover-timeout mymaster 10000

# Number of replicas that can sync with the new master simultaneously during failover.
sentinel parallel-syncs mymaster 1

# Required if master uses requirepass.
sentinel auth-pass mymaster your-master-password
```

Start Sentinel:
```bash
redis-sentinel /etc/redis/sentinel.conf
# Or: redis-server /etc/redis/sentinel.conf --sentinel
```

Check Sentinel status:
```bash
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL slaves mymaster
redis-cli -p 26379 SENTINEL sentinels mymaster

# Force a manual failover (useful for testing):
redis-cli -p 26379 SENTINEL failover mymaster
```

---

## 8. ACL Setup (Redis 6+)

ACLs replace or supplement `requirepass` with per-user permissions.

Interactive setup via redis-cli:
```bash
# List current users
redis-cli ACL LIST

# Create a read-only user for the app
redis-cli ACL SETUSER readuser on >readpassword ~* +@read

# Create a full-access app user, restricted to keys with prefix "app:"
redis-cli ACL SETUSER appuser on >apppassword ~app:* +@all

# Disable the default user (or restrict it)
redis-cli ACL SETUSER default off

# Persist ACL rules to an aclfile (must configure aclfile in redis.conf first)
redis-cli ACL SAVE
```

`/etc/redis/users.acl` format:
```
# Syntax: user <name> <flags> <password> <key-patterns> <command-permissions>
#
# off/on     — disable or enable the user
# ><password> — set password (hash stored internally)
# ~<pattern> — allow keys matching this glob pattern
# +@<category> — allow command category (+@read, +@write, +@all, etc.)
# -<command>   — deny a specific command even if category allows it
# nopass       — allow login without password (dangerous)
# nocommands   — deny all commands

user default off nopass nocommands
user appuser on >StrongPassword123 ~app:* +@read +@write +DEL +EXPIRE
user monitoring on >MonitorPass ~* +INFO +PING +CLIENT +SLOWLOG -@dangerous
```

In `redis.conf`, point to the ACL file:
```
aclfile /etc/redis/users.acl
```

---

## 9. Benchmark and Memory Inspection

Measure throughput and inspect memory usage without affecting production data.

```bash
# Built-in benchmark: 100K SET/GET operations, 50 parallel clients, 3-byte values
redis-benchmark -h 127.0.0.1 -p 6379 -n 100000 -c 50 -d 3

# Test only specific commands
redis-benchmark -t set,get,lpush,lrange -n 100000

# Pipeline mode (sends commands in batches of 16 — closer to real client behavior)
redis-benchmark -t set -n 100000 -P 16

# Live rolling stats (one line per second: keys, memory, clients, ops/sec)
redis-cli --stat

# Detailed memory stats
redis-cli INFO memory

# Memory usage of a specific key (including metadata overhead)
redis-cli MEMORY USAGE mykey

# Memory breakdown by data type (useful for identifying large key types)
redis-cli MEMORY DOCTOR

# Top N keys by memory (scans entire keyspace — use on dev/staging only)
redis-cli --bigkeys

# Debug object info for a key (encoding, serialized length, refcount)
redis-cli DEBUG OBJECT mykey
```

---

## 10. Safe Production Key Scan (SCAN vs KEYS)

KEYS is O(N) and blocks Redis while it runs. SCAN iterates in small batches without
blocking, making it safe for production keyspace enumeration.

```bash
# List all keys matching a pattern (non-blocking, uses SCAN internally)
redis-cli --scan --pattern 'session:*'

# Count matching keys without storing them
redis-cli --scan --pattern 'session:*' | wc -l

# Manual SCAN loop (for scripting with cursor control):
# SCAN cursor [MATCH pattern] [COUNT hint] [TYPE type]
# cursor=0 starts; loop until cursor=0 again.
redis-cli SCAN 0 MATCH 'app:*' COUNT 100

# Example bash loop over all keys:
cursor=0
while true; do
  result=$(redis-cli SCAN "$cursor" MATCH 'cache:*' COUNT 200)
  cursor=$(echo "$result" | head -1)
  keys=$(echo "$result" | tail -n +2)
  # Process $keys here
  [ "$cursor" = "0" ] && break
done

# Delete keys matching a pattern safely (pipe --scan into DEL via xargs)
redis-cli --scan --pattern 'temp:*' | xargs -L 100 redis-cli DEL

# Disable KEYS command entirely to prevent accidental use (add to redis.conf):
# rename-command KEYS ""
```

COUNT is a hint, not a guarantee — Redis may return more or fewer keys per call.
Each SCAN call returns a cursor plus a batch of results; the scan is complete when
the cursor returns to 0.
