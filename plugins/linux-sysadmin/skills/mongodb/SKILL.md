---
name: mongodb
description: >
  MongoDB document database administration — installation, configuration, user
  management, backup and restore, replication, sharding, indexing, performance
  tuning, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting mongodb.
triggerPhrases:
  - "mongodb"
  - "mongo"
  - "mongosh"
  - "mongod"
  - "mongodump"
  - "mongorestore"
  - "replica set"
  - "NoSQL database"
  - "document database"
  - "BSON"
  - "MongoDB Atlas"
globs:
  - "**/mongod.conf"
  - "**/mongos.conf"
last_verified: "2026-03"
---

## Identity
- **Unit**: `mongod.service`
- **Config**: `/etc/mongod.conf` (YAML format)
- **Logs**: `/var/log/mongodb/mongod.log`
- **Data dir**: `/var/lib/mongodb/` (Debian/Ubuntu), `/var/lib/mongo/` (RHEL/Fedora)
- **Default port**: 27017/tcp
- **Shell**: `mongosh` (replaces the legacy `mongo` shell, deprecated since MongoDB 5.0)
- **Install (Debian/Ubuntu)**: `apt-get install -y mongodb-org` (after adding the MongoDB apt repo)
- **Install (RHEL/Fedora)**: `dnf install -y mongodb-org` (after adding the MongoDB yum repo)

## Quick Start

```bash
# Import the MongoDB GPG key and add the 8.0 repository (Ubuntu example).
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
    sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt-get update && sudo apt-get install -y mongodb-org

# Start and enable the service.
sudo systemctl enable --now mongod

# Connect with mongosh and verify.
mongosh --eval "db.runCommand({ ping: 1 })"
```

```bash
# Quick first-document test.
mongosh <<'EOF'
use testdb
db.items.insertOne({ name: "widget", qty: 25 })
db.items.find({ name: "widget" })
EOF
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status mongod` |
| Start / stop / restart | `sudo systemctl start mongod` / `stop` / `restart` |
| Connect with mongosh | `mongosh` (localhost:27017) or `mongosh "mongodb://user:pass@host:27017/db?authSource=admin"` |
| List databases | `show dbs` |
| Switch database | `use mydb` |
| List collections | `show collections` |
| Insert document | `db.coll.insertOne({ key: "value" })` |
| Insert many | `db.coll.insertMany([{ a: 1 }, { a: 2 }])` |
| Find documents | `db.coll.find({ key: "value" })` |
| Find one | `db.coll.findOne({ key: "value" })` |
| Update document | `db.coll.updateOne({ key: "value" }, { $set: { key: "new" } })` |
| Update many | `db.coll.updateMany({}, { $inc: { qty: 1 } })` |
| Delete document | `db.coll.deleteOne({ key: "value" })` |
| Delete many | `db.coll.deleteMany({ status: "inactive" })` |
| Create admin user | `use admin; db.createUser({ user: "admin", pwd: passwordPrompt(), roles: [{ role: "root", db: "admin" }] })` |
| Create app user | `use admin; db.createUser({ user: "appuser", pwd: passwordPrompt(), roles: [{ role: "readWrite", db: "mydb" }] })` |
| List users | `use admin; db.getUsers()` |
| Dump a database | `mongodump --db=mydb --gzip --archive=mydb.gz` |
| Dump all databases | `mongodump --gzip --archive=full.gz` |
| Restore from archive | `mongorestore --gzip --archive=mydb.gz --drop` |
| Replica set status | `rs.status()` |
| Replica set initiate | `rs.initiate()` |
| Create index | `db.coll.createIndex({ field: 1 })` |
| List indexes | `db.coll.getIndexes()` |

## Expected Ports
- **27017/tcp** — `mongod` (default database server)
- **27018/tcp** — shard server (when running with `--shardsvr`)
- **27019/tcp** — config server (when running with `--configsvr`)
- Verify: `ss -tlnp | grep mongod`
- Firewall (ufw): `sudo ufw allow from <client_ip> to any port 27017`
- Firewall (firewalld): `sudo firewall-cmd --permanent --add-port=27017/tcp && sudo firewall-cmd --reload`

## Health Checks
1. `systemctl is-active mongod` -> `active`
2. `mongosh --eval "db.runCommand({ ping: 1 })"` -> `{ ok: 1 }`
3. `mongosh --eval "db.serverStatus().connections"` -> current, available, totalCreated counts
4. `mongosh --eval "rs.status().ok"` -> `1` (on replica set members)
5. `mongosh --eval "db.stats()"` -> dataSize, storageSize, indexes, objects counts

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `connection refused` on 27017 | mongod not running, or `net.bindIp` set to `127.0.0.1` only | Check `systemctl status mongod`; set `net.bindIp: 0.0.0.0` in `/etc/mongod.conf` for remote access; open firewall |
| `MongoServerError: Authentication failed` (code 18) | Wrong credentials, wrong `authSource` database, or auth not enabled | Verify username/password; ensure `--authenticationDatabase admin` in connection string; check `security.authorization: enabled` in mongod.conf |
| `WiredTiger cache full` / slow queries under load | WiredTiger cache undersized for working set | Default cache: 50% of (RAM - 1 GB) or 256 MB, whichever is larger. Check `db.serverStatus().wiredTiger.cache`. For containers, set `storage.wiredTiger.engineConfig.cacheSizeGB` explicitly; never exceed 80% of available RAM |
| Replication lag (`rs.status()` shows high `optimeDate` difference) | Secondary cannot keep up with primary write load, network issues, or slow disks | Check `rs.printReplicationInfo()` and `rs.printSecondaryReplicationInfo()`; verify network latency between members; check disk I/O on secondary; use write concern `"majority"` to throttle |
| Disk full on data directory | Large collections, excessive oplog, or missing compaction | Check `db.stats()` and `rs.printReplicationInfo()` for oplog size; reduce `replication.oplogSizeMB`; run `db.runCommand({ compact: "collection" })` on secondaries; enable `autoCompact` (8.0+) |
| `mongod` fails to start after config edit | YAML syntax error in mongod.conf | Check `journalctl -u mongod -n 50`; validate YAML indentation (spaces, not tabs); mongod.conf uses strict YAML format |

## Pain Points
- **SSPL license**: MongoDB Community Server uses the Server Side Public License, which is not recognized as open-source by OSI, Debian, or Red Hat. Anyone offering MongoDB as a service must open-source their entire service stack or obtain a commercial license. Fine for internal use; problematic if you plan to offer it as a managed service.
- **Schema design (embed vs reference)**: The most consequential decision in MongoDB. Embed when data is read together and the embedded array won't grow unbounded. Reference (with `$lookup`) when the related entity is queried independently or updated frequently. The 16 MB document size limit enforces a hard ceiling on embedding. Get this wrong early and you face expensive migrations later.
- **Index strategy**: Every query in production should hit an index. MongoDB performs a full collection scan if no suitable index exists. Compound indexes follow field order strictly; use the ESR rule (Equality, Sort, Range) for field ordering. Text indexes and wildcard indexes have significant write overhead. Use `explain("executionStats")` to verify plans.
- **WiredTiger cache sizing**: The default (50% of RAM minus 1 GB) works well for single-instance hosts but is wrong for containers and shared servers. In Docker or LXC, mongod sees the host's total RAM unless you set `cacheSizeGB` explicitly. Over-sizing causes OOM kills; under-sizing causes excessive eviction.
- **mongosh vs legacy mongo shell**: The legacy `mongo` shell was removed in MongoDB 6.0. mongosh is the replacement; syntax is largely compatible but some helper methods differ (e.g., `printjson()` changed behavior). Scripts using `load()` may need updates.
- **No multi-document transactions before replica sets**: Transactions require a replica set, even for single-node deployments. Convert a standalone to a single-member replica set (`rs.initiate()`) to use transactions. This also enables the oplog, which is required for change streams.

## See Also

- **postgresql** — Relational database with SQL, ACID transactions, and mature tooling for structured/tabular data
- **mariadb** — MySQL-compatible relational database with simpler replication setup
- **redis** — In-memory data store commonly paired with MongoDB for caching and session storage
- **sqlite** — Embedded single-file database for applications that don't need a server process
- **cassandra** — distributed wide-column NoSQL for high write throughput at scale

## References
See `references/` for:
- `docs.md` — verified official documentation links (mongodb.com/docs)
- `mongod.conf.annotated` — annotated configuration file with every directive explained
- `common-patterns.md` — replica set setup, user/role creation, backup strategies, index creation, aggregation pipeline examples, connection string formats
