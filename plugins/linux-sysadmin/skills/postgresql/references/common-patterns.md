# PostgreSQL Common Patterns

Each section is a standalone task with copy-paste-ready commands and SQL.
Run SQL blocks inside `psql` unless noted otherwise.

---

## 1. Initial Setup (First-Time Server Configuration)

After installing PostgreSQL, the `postgres` OS user owns the superuser role.
Start here to create a database and an application-specific user.

```bash
# Open a psql session as the postgres superuser via Unix socket (peer auth).
sudo -u postgres psql
```

```sql
-- Create a database for the application.
CREATE DATABASE myapp;

-- Create an application user with a strong password.
-- Never use the postgres superuser for application connections.
CREATE USER myapp_user WITH PASSWORD 'change_me_in_production';

-- Grant connection access to the database.
GRANT CONNECT ON DATABASE myapp TO myapp_user;

-- Grant usage on the public schema and all current tables.
GRANT USAGE ON SCHEMA public TO myapp_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myapp_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO myapp_user;

-- Make future tables also accessible (applies to tables created after this point).
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO myapp_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO myapp_user;
```

---

## 2. Enable Remote Access

Three things must change together: `postgresql.conf`, `pg_hba.conf`, and the firewall.
Changing only one will not work.

**Step 1: Edit postgresql.conf**
```ini
# /etc/postgresql/16/main/postgresql.conf
listen_addresses = '*'   # or a specific IP: '10.0.0.5'
```

**Step 2: Add a pg_hba.conf rule**
```
# /etc/postgresql/16/main/pg_hba.conf
# Allow myapp_user from the application server subnet.
host    myapp    myapp_user    10.0.1.0/24    scram-sha-256
```

**Step 3: Reload PostgreSQL (restart required only for listen_addresses)**
```bash
# listen_addresses requires a restart; pg_hba.conf changes need only a reload.
sudo systemctl restart postgresql@16-main     # Debian
sudo systemctl restart postgresql-16          # RHEL
```

**Step 4: Open the firewall**
```bash
# ufw (Debian/Ubuntu)
sudo ufw allow from 10.0.1.0/24 to any port 5432

# firewalld (RHEL/Fedora)
sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.1.0/24" service name="postgresql" accept' --permanent
sudo firewall-cmd --reload
```

**Verify from the remote host**
```bash
psql -h <server_ip> -U myapp_user -d myapp -c "SELECT 1;"
```

---

## 3. Backup with pg_dump and pg_dumpall

**Single database — custom format (recommended for large databases)**
```bash
# -F c = custom format (compressed, supports parallel restore with pg_restore)
# -f   = output file
# Run as postgres user or with a user that has SELECT on all tables.
pg_dump -U postgres -F c -f /var/backups/myapp_$(date +%Y%m%d).dump myapp
```

**Single database — plain SQL (human-readable, portable)**
```bash
pg_dump -U postgres -F p -f /var/backups/myapp_$(date +%Y%m%d).sql myapp
```

**All databases + global objects (roles, tablespaces)**
```bash
# pg_dumpall always produces plain SQL output.
pg_dumpall -U postgres -f /var/backups/all_dbs_$(date +%Y%m%d).sql
```

**Schema only (no data)**
```bash
pg_dump -U postgres -s -f /var/backups/myapp_schema.sql myapp
```

**Data only (no schema)**
```bash
pg_dump -U postgres -a -f /var/backups/myapp_data.sql myapp
```

---

## 4. Restore from Backup

**Restore custom-format dump**
```bash
# The target database must exist before restoring.
# -d = target database  |  -F c = custom format  |  -j 4 = 4 parallel restore workers
createdb -U postgres myapp_restored
pg_restore -U postgres -d myapp_restored -F c -j 4 /var/backups/myapp_20240101.dump
```

**Restore plain SQL dump**
```bash
# Pipe through psql. Use -v ON_ERROR_STOP=1 to abort on errors.
psql -U postgres -v ON_ERROR_STOP=1 -f /var/backups/myapp_20240101.sql myapp_restored
```

**Restore pg_dumpall output**
```bash
# Restores roles, tablespaces, and all databases.
# Must connect as postgres superuser.
psql -U postgres -f /var/backups/all_dbs_20240101.sql
```

---

## 5. Check and Kill Long-Running Queries

**Find long-running queries**
```sql
-- Lists queries running longer than 5 minutes, most recent first.
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    usename,
    application_name,
    state,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query_snippet
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - interval '5 minutes'
ORDER BY duration DESC;
```

**Cancel a query (sends SIGINT — leaves the connection open)**
```sql
SELECT pg_cancel_backend(pid);
```

**Terminate a backend (sends SIGTERM — closes the connection)**
```sql
-- Use when pg_cancel_backend doesn't respond (e.g., the query is waiting on a lock).
SELECT pg_terminate_backend(pid);
```

**Terminate all connections to a database (for drop/restore operations)**
```sql
-- Revoke new connections first, then terminate existing ones.
REVOKE CONNECT ON DATABASE myapp FROM PUBLIC;
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'myapp' AND pid <> pg_backend_pid();
```

---

## 6. Create a Read-Only Replica User

Useful for reporting tools, analytics queries, or read-only API services
that should never modify data.

```sql
-- Connect to the target database first: \c myapp
CREATE ROLE readonly_user WITH LOGIN PASSWORD 'readonly_pass';

-- Grant connection to the database.
GRANT CONNECT ON DATABASE myapp TO readonly_user;

-- Grant schema visibility and SELECT on all current tables.
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO readonly_user;

-- Ensure future tables are also readable by this role.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO readonly_user;

-- Optional: limit how many concurrent connections this role can hold.
ALTER ROLE readonly_user CONNECTION LIMIT 10;
```

---

## 7. Monitor Database Size and Table Bloat

**Database sizes**
```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

**Table sizes (including indexes and toast)**
```sql
SELECT
    relname AS table,
    pg_size_pretty(pg_total_relation_size(oid)) AS total,
    pg_size_pretty(pg_relation_size(oid)) AS table_only,
    pg_size_pretty(pg_total_relation_size(oid) - pg_relation_size(oid)) AS indexes
FROM pg_class
WHERE relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC
LIMIT 20;
```

**Dead tuple bloat (candidates for VACUUM)**
```sql
SELECT
    relname AS table,
    n_live_tup,
    n_dead_tup,
    round(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1) AS dead_pct,
    last_autovacuum,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

**Manual vacuum on a bloated table**
```bash
# Run outside a transaction. VERBOSE shows progress.
sudo -u postgres vacuumdb --analyze --verbose -d myapp -t bloated_table
```

**VACUUM FULL (reclaims disk space, requires exclusive lock)**
```sql
-- Use only during maintenance windows. Locks the table for the duration.
-- pg_repack is a better alternative for online bloat removal.
VACUUM FULL VERBOSE bloated_table;
```

---

## 8. Streaming Replication Setup (Primary → Replica)

### On the primary

**Create a replication role**
```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_password';
```

**Edit pg_hba.conf on the primary**
```
host    replication    replicator    <replica_ip>/32    scram-sha-256
```

**Edit postgresql.conf on the primary**
```ini
wal_level = replica
max_wal_senders = 5
wal_keep_size = 1GB    # Retain WAL in case replica lags
```

```bash
sudo systemctl reload postgresql@16-main
```

### On the replica

**Take a base backup from the primary**
```bash
# -R writes standby.signal and primary_conninfo into PGDATA automatically.
# Run as postgres user. Replace paths and IPs for your environment.
pg_basebackup \
    -h <primary_ip> \
    -U replicator \
    -D /var/lib/postgresql/16/main \
    -P -Xs -R
```

**Start the replica**
```bash
sudo systemctl start postgresql@16-main
```

### Verify replication

```sql
-- On the primary:
SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn
FROM pg_stat_replication;

-- On the replica:
SELECT status, received_lsn, last_msg_receipt_time
FROM pg_stat_wal_receiver;
```

---

## 9. Performance: EXPLAIN ANALYZE Basics

`EXPLAIN` shows the planner's execution plan. `ANALYZE` actually executes the query
and adds real timing. Always use both when investigating slow queries.

```sql
-- Basic: see the plan and actual timings.
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;

-- Detailed: include buffer usage and extended node info.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
    SELECT o.id, c.name
    FROM orders o
    JOIN customers c ON c.id = o.customer_id
    WHERE o.created_at > now() - interval '30 days';
```

**Key things to look for in the output:**
- `Seq Scan` on a large table — a sequential scan where an index scan was expected often means the index is missing or statistics are stale.
- `rows=` estimated vs actual — large discrepancies indicate stale statistics. Run `ANALYZE tablename;` to update.
- `Buffers: shared hit=X read=Y` — `read` means disk I/O; high ratios suggest the working set doesn't fit in `shared_buffers`.
- `Sort Method: external merge Disk` — sort spilled to disk because `work_mem` was too small for this query.

**Create an index and measure the change**
```sql
-- Check if an index would help (use EXPLAIN first to see the scan type).
CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders(customer_id);

-- CONCURRENTLY builds without locking writes; takes longer but safe for production.
```

---

## 10. PgBouncer Connection Pooling

PgBouncer sits between the application and PostgreSQL, multiplexing many application
connections onto a smaller number of PostgreSQL backend connections. Use it when
max_connections pressure or connection overhead becomes a bottleneck.

**Install**
```bash
apt install pgbouncer      # Debian/Ubuntu
dnf install pgbouncer      # RHEL/Fedora
```

**Minimal /etc/pgbouncer/pgbouncer.ini**
```ini
[databases]
# Route 'myapp' connections from clients to PostgreSQL on localhost.
myapp = host=127.0.0.1 port=5432 dbname=myapp

[pgbouncer]
# Listen on a different port so applications point at PgBouncer, not Postgres.
listen_port = 6432
listen_addr = 127.0.0.1

# transaction: most efficient; connection released after each transaction.
# session: released after client disconnects (use when SET or prepared statements needed).
pool_mode = transaction

# Maximum connections PgBouncer opens to PostgreSQL (per database).
server_pool_size = 20

# Maximum client connections PgBouncer will accept.
max_client_conn = 200

# Auth file: maps client usernames to passwords.
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Log file (or use syslog).
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
```

**userlist.txt format**
```
"myapp_user" "md5<hash>"    # For md5
"myapp_user" "SCRAM-SHA-256$..."   # For scram-sha-256 (copy from pg_shadow)
```

**Generate scram hash from PostgreSQL**
```sql
-- Run this in psql and copy the output into userlist.txt.
SELECT passwd FROM pg_shadow WHERE usename = 'myapp_user';
```

**Start and verify**
```bash
sudo systemctl enable --now pgbouncer

# Connect through PgBouncer (port 6432) to verify routing.
psql -h 127.0.0.1 -p 6432 -U myapp_user -d myapp -c "SELECT 1;"

# Check pool stats.
psql -h 127.0.0.1 -p 6432 -U myapp_user -d pgbouncer -c "SHOW POOLS;"
```
