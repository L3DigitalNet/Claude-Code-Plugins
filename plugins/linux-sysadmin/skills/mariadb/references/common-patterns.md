# MariaDB Common Patterns

Each block is a complete, copy-paste-ready example. SQL statements assume you are
already connected via `sudo mariadb` or `mysql -u root -p`.

---

## 1. Secure Initial Setup

Run immediately after installing MariaDB. `mysql_secure_installation` walks you through
these steps interactively, but here is what it does and why:

```bash
# Start the secure installation wizard.
sudo mysql_secure_installation
```

What the wizard does (and the equivalent manual SQL if you skip it):

```sql
-- Set or change root password (MariaDB 10.4+ uses socket auth for root by default;
-- skip this if you want to keep passwordless socket auth).
ALTER USER 'root'@'localhost' IDENTIFIED BY 'strong-root-password';

-- Remove anonymous users (created by default, allow anyone to connect without a user account).
DELETE FROM mysql.user WHERE User='';

-- Remove test database (world-readable, created by default).
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Disallow root login from non-localhost hosts.
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Apply changes immediately without restarting the service.
FLUSH PRIVILEGES;
```

After running, verify:

```bash
# Confirm anonymous user is gone.
sudo mariadb -e "SELECT User, Host FROM mysql.user;"

# Confirm root can only connect locally.
sudo mariadb -e "SELECT User, Host FROM mysql.user WHERE User='root';"
```

---

## 2. Create Database and User for a Web App (WordPress Pattern)

The standard pattern for any PHP/Python/Node web application that needs its own database.
Always create a dedicated user with minimal privileges rather than using root.

```sql
-- Create the database with explicit character set.
-- utf8mb4 is required for full Unicode support (emoji, supplementary characters).
CREATE DATABASE wordpress
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Create the application user.
-- 'localhost' means this user can only connect via Unix socket or TCP to 127.0.0.1.
-- Use '%' or a specific IP for remote application servers.
CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'strong-password-here';

-- Grant only what the application needs. Most web apps only need these five.
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
    ON wordpress.*
    TO 'wpuser'@'localhost';

-- Apply privilege changes.
FLUSH PRIVILEGES;

-- Verify.
SHOW GRANTS FOR 'wpuser'@'localhost';
```

Test the new user from the shell:

```bash
mysql -u wpuser -p wordpress -e "SHOW TABLES;"
```

---

## 3. Remote Access Configuration

Two steps are required: a config change and a user grant. Neither alone is sufficient.

**Step 1: Change bind-address in my.cnf**

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf (Debian/Ubuntu)
# or /etc/my.cnf (RHEL/Fedora)
[mysqld]
# 0.0.0.0 = listen on all interfaces.
# Or use a specific IP: bind-address = 10.0.0.5
bind-address = 0.0.0.0
```

```bash
sudo systemctl restart mariadb
# Verify it's now listening on all interfaces:
ss -tlnp | grep 3306
```

**Step 2: Create a user that allows remote connections**

```sql
-- '%' means any host. Replace with a specific IP for tighter access control.
CREATE USER 'myuser'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'%';
FLUSH PRIVILEGES;
```

**Step 3: Open the firewall**

```bash
# UFW (Debian/Ubuntu):
sudo ufw allow from 10.0.0.0/24 to any port 3306

# firewalld (RHEL/Fedora) — restrict to a specific source IP:
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.5" port protocol="tcp" port="3306" accept'
sudo firewall-cmd --reload
```

---

## 4. mysqldump Backup

**Single database:**

```bash
# Basic dump — includes CREATE TABLE and INSERT statements.
mysqldump -u root -p mydb > mydb_$(date +%F).sql

# With --single-transaction: consistent snapshot of InnoDB tables without table locks.
# Add --routines and --triggers to include stored procedures, functions, and triggers.
mysqldump -u root -p --single-transaction --routines --triggers mydb > mydb_$(date +%F).sql

# Compress on the fly to save disk space.
mysqldump -u root -p --single-transaction mydb | gzip > mydb_$(date +%F).sql.gz
```

**All databases:**

```bash
# --all-databases includes mysql system tables and all user databases.
# --events includes scheduled events.
mysqldump -u root -p --all-databases --single-transaction --routines --events \
    > all-databases_$(date +%F).sql
```

**Structure only (no data — useful for schema migrations):**

```bash
mysqldump -u root -p --no-data mydb > mydb_schema.sql
```

**Data only (no CREATE TABLE — useful for re-importing into existing schema):**

```bash
mysqldump -u root -p --no-create-info mydb > mydb_data.sql
```

**Scheduled nightly backup (cron):**

```bash
# /etc/cron.d/mariadb-backup
0 2 * * * root mysqldump -u root --single-transaction --all-databases \
    | gzip > /var/backups/mysql/all-databases_$(date +\%F).sql.gz \
    && find /var/backups/mysql/ -name "*.sql.gz" -mtime +7 -delete
```

---

## 5. Restore from Dump

```bash
# Restore a single database (database must already exist).
mysql -u root -p mydb < mydb_2025-01-01.sql

# Create the database first if needed.
mysql -u root -p -e "CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p mydb < mydb_2025-01-01.sql

# Restore from a compressed dump.
gunzip < mydb_2025-01-01.sql.gz | mysql -u root -p mydb

# Restore all databases (use with caution — overwrites existing data).
mysql -u root -p < all-databases_2025-01-01.sql

# Monitor progress during large restores with pv.
pv mydb_2025-01-01.sql | mysql -u root -p mydb
```

---

## 6. Check and Kill Slow Queries

**Identify slow queries in real time:**

```sql
-- Show all running queries with execution time.
SHOW FULL PROCESSLIST;

-- Filter to queries running longer than 30 seconds.
SELECT id, user, host, db, time, state, info
FROM information_schema.processlist
WHERE time > 30
ORDER BY time DESC;
```

**Kill a specific query:**

```sql
-- Kill just the query (connection stays open).
KILL QUERY 12345;

-- Kill the entire connection.
KILL 12345;
```

**Analyze the slow query log:**

```bash
# Parse slow query log and show top offenders by total time.
mysqldumpslow -s t /var/log/mysql/mysql-slow.log | head -40

# If pt-query-digest is available (from percona-toolkit):
pt-query-digest /var/log/mysql/mysql-slow.log | less
```

**Enable slow query log dynamically (takes effect immediately, no restart):**

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;   -- Log queries slower than 1 second.
SET GLOBAL slow_query_log_file = '/var/log/mysql/mysql-slow.log';
```

---

## 7. Binary Log-Based Point-in-Time Recovery

PITR restores the database to a specific moment in time, not just to the last backup.
Requires binary logging to be enabled (`log_bin` in my.cnf).

**Concept:**
1. Restore the most recent full backup (mysqldump).
2. Replay binary log events from the backup timestamp up to the target time.

```bash
# Step 1: Find the binary log files covering the period after your last backup.
mysql -u root -p -e "SHOW BINARY LOGS;"

# Step 2: Identify the position or timestamp where recovery should stop.
# Use mysqlbinlog to inspect events:
mysqlbinlog /var/log/mysql/mysql-bin.000042 | less

# Step 3: Restore the full backup.
mysql -u root -p mydb < mydb_full_2025-01-01.sql

# Step 4: Replay binary logs up to (but not including) the bad event.
# --stop-datetime stops replay before a specific time.
mysqlbinlog --start-datetime="2025-01-01 02:00:00" \
            --stop-datetime="2025-01-02 14:29:00" \
            /var/log/mysql/mysql-bin.000042 \
            /var/log/mysql/mysql-bin.000043 \
    | mysql -u root -p mydb

# Alternatively, use --stop-position if you know the exact log position of the bad event.
mysqlbinlog --start-position=4 --stop-position=8192 \
    /var/log/mysql/mysql-bin.000042 | mysql -u root -p mydb
```

---

## 8. Replication Setup (Primary / Replica)

**On the primary server:**

```ini
# my.cnf [mysqld] section
server_id   = 1
log_bin     = /var/log/mysql/mysql-bin
binlog_format = ROW
```

```sql
-- Create a dedicated replication user.
CREATE USER 'replicator'@'10.0.0.%' IDENTIFIED BY 'replication-password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'10.0.0.%';
FLUSH PRIVILEGES;

-- Take a consistent snapshot and note the log file and position.
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
-- Note: File and Position values — needed on the replica.
-- In another session, take the dump, then release the lock.
UNLOCK TABLES;
```

```bash
# Take the dump while the lock is held (run in a second terminal).
mysqldump -u root -p --all-databases --master-data=2 > primary_snapshot.sql
```

**On the replica server:**

```ini
# my.cnf [mysqld] section
server_id  = 2   # Must differ from primary.
relay_log  = /var/log/mysql/mysql-relay-bin
read_only  = ON  # Prevents accidental writes to the replica.
```

```bash
# Import the snapshot.
mysql -u root -p < primary_snapshot.sql
```

```sql
-- Configure the replica to connect to the primary.
CHANGE MASTER TO
    MASTER_HOST='10.0.0.1',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replication-password',
    MASTER_LOG_FILE='mysql-bin.000001',   -- from SHOW MASTER STATUS on primary
    MASTER_LOG_POS=154;                   -- from SHOW MASTER STATUS on primary

-- Start replication.
START SLAVE;

-- Verify replication is running.
SHOW SLAVE STATUS\G
-- Check: Slave_IO_Running: Yes, Slave_SQL_Running: Yes, Seconds_Behind_Master: 0
```

---

## 9. Check Table Status and Repair

InnoDB tables auto-recover on restart. Use these for diagnostics or for legacy MyISAM tables.

```sql
-- Check all tables in a database for errors.
CHECK TABLE tablename;
-- Or use mysqlcheck from the shell:
```

```bash
# Check all databases (connects via socket, requires root).
mysqlcheck -u root -p --all-databases

# Check and auto-repair in one pass (MyISAM only — InnoDB CHECK TABLE is read-only).
mysqlcheck -u root -p --auto-repair --all-databases

# Repair a specific MyISAM table.
mysqlcheck -u root -p --repair mydb tablename
```

```sql
-- REPAIR TABLE works only on MyISAM, ARCHIVE, and CSV engines.
REPAIR TABLE mytable;

-- For InnoDB crash recovery, set in my.cnf [mysqld] and restart:
-- innodb_force_recovery = 1  (try 1 first; escalate to 2, 3, 4, 5, 6 only if needed)
-- At level 3+ you can SELECT and dump data but not write. Dump, drop, recreate.
```

---

## 10. Performance: EXPLAIN Basics and Slow Query Analysis

**EXPLAIN: see how MariaDB executes a query**

```sql
-- Prefix any SELECT with EXPLAIN to see the query plan.
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- EXPLAIN FORMAT=JSON gives more detail (MariaDB 10.1+).
EXPLAIN FORMAT=JSON SELECT * FROM orders WHERE customer_id = 42;
```

Key columns to examine in EXPLAIN output:

| Column | What to look for |
|--------|-----------------|
| `type` | `ALL` = full table scan (bad); `ref` or `eq_ref` = index used (good); `const` = best |
| `key` | The index being used. NULL means no index. |
| `rows` | Estimated rows examined. High = potential performance issue. |
| `Extra` | `Using filesort` = sort without index; `Using temporary` = temp table created |

**Add a missing index:**

```sql
-- Check if an index exists on the column used in WHERE/JOIN/ORDER BY.
SHOW INDEX FROM orders;

-- Add an index.
ALTER TABLE orders ADD INDEX idx_customer_id (customer_id);

-- Composite index for queries filtering on multiple columns.
ALTER TABLE orders ADD INDEX idx_customer_status (customer_id, status);
```

**Analyze a slow query log with mysqldumpslow:**

```bash
# Top 10 queries by total execution time.
mysqldumpslow -s t -t 10 /var/log/mysql/mysql-slow.log

# Top 10 by average execution time (finds consistently slow queries).
mysqldumpslow -s at -t 10 /var/log/mysql/mysql-slow.log

# Filter to queries matching a specific table or pattern.
mysqldumpslow -s t /var/log/mysql/mysql-slow.log | grep orders
```
