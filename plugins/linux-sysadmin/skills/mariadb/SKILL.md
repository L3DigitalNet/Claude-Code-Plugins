---
name: mariadb
description: >
  MariaDB and MySQL database administration: installation, configuration, user
  and privilege management, backup and restore, replication, performance tuning,
  and troubleshooting. Triggers on: mariadb, mysql, mysqldump, MariaDB, MySQL,
  WordPress database, mariadb database, my.cnf, innodb, mariadb service,
  mysql service, mysql -u root, CREATE DATABASE, GRANT privileges, slow query log.
globs:
  - "**/my.cnf"
  - "**/mysql/*.cnf"
  - "**/mysql/**/*.cnf"
  - "/etc/mysql/**"
  - "**/mariadb.conf.d/**"
---

## Identity
- **Unit**: `mariadb.service` (Debian/Ubuntu) or `mysqld.service` (RHEL/Fedora)
- **Config**: `/etc/mysql/my.cnf`, `/etc/mysql/mariadb.conf.d/` (Debian/Ubuntu); `/etc/my.cnf`, `/etc/my.cnf.d/` (RHEL/Fedora)
- **Data dir**: `/var/lib/mysql/`
- **Socket**: `/run/mysqld/mysqld.sock` (Debian/Ubuntu), `/var/lib/mysql/mysql.sock` (RHEL)
- **Error log**: `/var/log/mysql/error.log` (Debian/Ubuntu), `/var/log/mariadb/mariadb.log` (RHEL)
- **Slow query log**: `/var/log/mysql/mysql-slow.log` (when enabled)
- **Distro install**: `apt install mariadb-server` / `dnf install mariadb-server`
- **Post-install security**: `sudo mysql_secure_installation`

## Key Operations

| Operation | Command |
|-----------|---------|
| Service status | `sudo systemctl status mariadb` |
| Connect as root (socket auth) | `sudo mariadb` |
| Connect with password | `mysql -u root -p` or `mysql -u myuser -p mydb` |
| Connect to remote host | `mysql -h 10.0.0.5 -u myuser -p mydb` |
| List databases | `SHOW DATABASES;` |
| Use a database | `USE mydb;` |
| List tables | `SHOW TABLES;` |
| Describe table structure | `DESCRIBE tablename;` |
| Create database | `CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;` |
| Create user | `CREATE USER 'myuser'@'localhost' IDENTIFIED BY 'password';` |
| Grant privileges | `GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'localhost';` |
| Flush privileges | `FLUSH PRIVILEGES;` |
| Show grants for user | `SHOW GRANTS FOR 'myuser'@'localhost';` |
| Drop user | `DROP USER 'myuser'@'localhost';` |
| Dump single database | `mysqldump -u root -p mydb > mydb.sql` |
| Dump all databases | `mysqldump -u root -p --all-databases > all.sql` |
| Restore from dump | `mysql -u root -p mydb < mydb.sql` |
| Check processlist | `SHOW FULL PROCESSLIST;` |
| Kill a query | `KILL QUERY <process_id>;` |
| Show status variables | `SHOW STATUS LIKE 'Threads_connected';` or `SHOW GLOBAL STATUS;` |
| Show system variables | `SHOW VARIABLES LIKE 'max_connections';` or `SHOW GLOBAL VARIABLES;` |
| Set global variable (live) | `SET GLOBAL max_connections = 200;` |
| Check slow query log status | `SHOW VARIABLES LIKE 'slow_query_log%';` |
| Enable slow query log (live) | `SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = 2;` |
| Check replication status | `SHOW REPLICA STATUS\G` (MariaDB 10.5+) or `SHOW SLAVE STATUS\G` |
| Show binary logs | `SHOW BINARY LOGS;` |
| Check InnoDB status | `SHOW ENGINE INNODB STATUS\G` |
| Check table | `CHECK TABLE tablename;` |
| Repair table | `REPAIR TABLE tablename;` (MyISAM only; use InnoDB recovery for InnoDB) |

## Expected Ports
- **3306/tcp** — default MySQL/MariaDB port
- Verify: `ss -tlnp | grep :3306`
- Firewall (allow remote): `sudo ufw allow 3306/tcp` or `sudo firewall-cmd --permanent --add-port=3306/tcp`
- Note: bind to `127.0.0.1` by default — remote access requires `bind-address` change plus firewall rule

## Health Checks
1. `systemctl is-active mariadb` → `active`
2. `sudo mariadb -e "SELECT 1;"` → `1` (confirms socket auth works)
3. `ss -tlnp | grep :3306` → mariadb/mysqld listed on expected bind address
4. `sudo mariadb -e "SHOW STATUS LIKE 'Uptime';"` → uptime in seconds

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `ERROR 1045 (28000): Access denied for user 'root'@'localhost'` | Password wrong or socket auth bypassed | Use `sudo mariadb` for root socket auth; on RHEL reset with `--skip-grant-tables` |
| `Can't connect to MySQL server on 'x.x.x.x'` | `bind-address = 127.0.0.1` blocking remote | Change `bind-address` in `my.cnf` to `0.0.0.0` or specific IP, restart service |
| `ERROR 1040 (HY000): Too many connections` | `max_connections` too low or connection leak | `SHOW STATUS LIKE 'Threads_connected'; SET GLOBAL max_connections = 300;` |
| Table corruption on InnoDB | Unclean shutdown or disk error | Check `/var/log/mysql/error.log`; InnoDB auto-recovers on restart; run `mysqlcheck -u root -p --all-databases` |
| InnoDB crash recovery loop | `innodb_force_recovery` needed | Set `innodb_force_recovery = 1` (up to 6) in `[mysqld]`, start, dump data, drop and recreate |
| Replication lag / `Seconds_Behind_Master` high | Slave I/O or SQL thread slow | Check `SHOW REPLICA STATUS\G`; look for `Last_Error`; consider `slave_parallel_threads` |
| Slow queries killing performance | Missing indexes or bad query plans | Enable slow query log; analyze with `mysqldumpslow` or `pt-query-digest`; run `EXPLAIN` on offending queries |
| Disk full on `/var/lib/mysql/` | Binary logs not expiring or large tables | Set `expire_logs_days` or `binlog_expire_logs_seconds`; run `PURGE BINARY LOGS BEFORE '2025-01-01 00:00:00';` |
| `ERROR 1215 (HY000): Cannot add foreign key constraint` | Mismatched column types or missing index on referenced column | Check both sides: data types must match exactly; referenced column must be indexed |
| Service fails to start after config edit | Syntax error in `my.cnf` | Check `journalctl -u mariadb -n 50`; MariaDB doesn't have a `--test` flag — validate manually |

## Pain Points
- **`bind-address` defaults to `127.0.0.1`**: Remote connections silently fail until this is changed. Always check before spending time on firewall rules.
- **`GRANT` syntax changed**: In MariaDB 10.4+, `CREATE USER` and `GRANT` are separate — `GRANT ... IDENTIFIED BY` no longer creates users. Use `CREATE USER` first, then `GRANT`.
- **MariaDB vs MySQL divergence**: MariaDB 10.6+ diverges from MySQL 8.0 on JSON support (MariaDB JSON is an alias for LONGTEXT, not a native type), auth plugins (`mysql_native_password` vs `ed25519`), and window functions. Scripts written for MySQL may not be portable.
- **Slow query log disabled by default**: `slow_query_log = OFF` and `long_query_time = 10` out of the box. For production diagnosis, enable with `long_query_time = 1` or lower.
- **InnoDB vs MyISAM**: Always use InnoDB. MyISAM lacks transactions and row-level locking. Legacy tables can be converted: `ALTER TABLE t ENGINE=InnoDB;`
- **Binary log retention**: Binary logs accumulate indefinitely if `expire_logs_days` (or `binlog_expire_logs_seconds` in newer versions) is not set. Disk fills silently.
- **Character set footgun**: Default character set was `latin1` in older installs. Always explicitly set `utf8mb4` when creating databases and users, and in `my.cnf`. `utf8` in MySQL/MariaDB is actually `utf8mb3` (3-byte only) — emoji requires `utf8mb4`.
- **Socket vs TCP localhost**: `mysql -h 127.0.0.1` uses TCP (subject to `bind-address`); `mysql -h localhost` uses the Unix socket. They resolve differently and use different auth paths.

## References
See `references/` for:
- `my.cnf.annotated` — full configuration file with every directive explained
- `common-patterns.md` — backup, restore, user setup, replication, and performance patterns
- `docs.md` — official documentation links
