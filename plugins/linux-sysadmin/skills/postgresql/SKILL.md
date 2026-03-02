---
name: postgresql
description: >
  PostgreSQL database server administration: installation, configuration,
  user and database management, backup and restore, replication, query
  performance, connection management, and troubleshooting. Triggers on:
  postgresql, postgres, psql, pg_dump, pg_restore, pg_dumpall, pg_hba.conf,
  postgresql.conf, pg_stat_activity, pg_upgrade, PostgreSQL, database postgres,
  vacuumdb, pgbouncer, pg_basebackup, replication slot.
globs:
  - "**/postgresql.conf"
  - "**/pg_hba.conf"
  - "**/pg_ident.conf"
---

## Identity
- **Unit**: `postgresql@16-main.service` (Debian/Ubuntu), `postgresql-16.service` (RHEL/Fedora)
- **Config (Debian)**: `/etc/postgresql/16/main/postgresql.conf`, `/etc/postgresql/16/main/pg_hba.conf`
- **Config (RHEL)**: `/var/lib/pgsql/16/data/postgresql.conf`, `/var/lib/pgsql/16/data/pg_hba.conf`
- **Data dir (Debian)**: `/var/lib/postgresql/16/main/`
- **Data dir (RHEL)**: `/var/lib/pgsql/16/data/`
- **Logs (Debian)**: `/var/log/postgresql/postgresql-16-main.log`
- **Logs (RHEL)**: `journalctl -u postgresql-16`, or `$PGDATA/log/` if logging_collector=on
- **Postgres superuser**: `postgres` (OS user and DB superuser — separate concepts)
- **Install (Debian)**: `apt install postgresql-16`
- **Install (RHEL)**: `dnf install postgresql16-server && postgresql-16-setup initdb`

## Key Operations

| Operation | Command |
|-----------|---------|
| Service status | `systemctl status postgresql@16-main` (Debian) / `systemctl status postgresql-16` (RHEL) |
| Reload config | `sudo systemctl reload postgresql@16-main` or `SELECT pg_reload_conf();` in psql |
| Connect as postgres | `sudo -u postgres psql` |
| Connect to specific db | `sudo -u postgres psql -d mydb` or `psql -h 127.0.0.1 -U myuser -d mydb` |
| List databases | `\l` or `SELECT datname FROM pg_database;` |
| List users/roles | `\du` or `SELECT rolname, rolsuper FROM pg_roles;` |
| List tables | `\dt` (current schema), `\dt *.*` (all schemas) |
| Create database | `CREATE DATABASE mydb;` |
| Create user | `CREATE USER myuser WITH PASSWORD 'secret';` |
| Grant all on database | `GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;` |
| Grant schema usage | `GRANT USAGE ON SCHEMA public TO myuser; GRANT ALL ON ALL TABLES IN SCHEMA public TO myuser;` |
| Dump single database | `pg_dump -U postgres -F c -f mydb.dump mydb` |
| Dump all databases | `pg_dumpall -U postgres -f all_dbs.sql` |
| Restore custom-format dump | `pg_restore -U postgres -d mydb -F c mydb.dump` |
| Restore SQL dump | `psql -U postgres -d mydb -f mydb.sql` |
| Check active connections | `SELECT pid, usename, application_name, state, query FROM pg_stat_activity;` |
| Kill a connection | `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <pid>;` |
| Vacuum a table | `VACUUM VERBOSE ANALYZE mytable;` |
| Full vacuum (locks table) | `VACUUM FULL mytable;` (use sparingly — acquires exclusive lock) |
| Check table sizes | `SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) FROM pg_class WHERE relkind='r' ORDER BY pg_total_relation_size(oid) DESC LIMIT 20;` |
| Replication status | `SELECT * FROM pg_stat_replication;` (primary) / `SELECT * FROM pg_stat_wal_receiver;` (replica) |

## Expected Ports
- 5432/tcp (PostgreSQL default)
- Verify: `ss -tlnp | grep postgres`
- Firewall (ufw): `sudo ufw allow from <client_ip> to any port 5432`
- Firewall (firewalld): `sudo firewall-cmd --add-service=postgresql --permanent && sudo firewall-cmd --reload`

## Health Checks
1. `systemctl is-active postgresql@16-main` → `active`
2. `sudo -u postgres pg_isready` → `/var/run/postgresql:5432 - accepting connections`
3. `sudo -u postgres psql -c "SELECT version();"` → version string, no errors
4. `sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"` → integer row count

## Common Failures

| Symptom | Likely cause | Check / Fix |
|---------|-------------|-------------|
| `password authentication failed for user "foo"` | Wrong password, or pg_hba.conf requires a different method | Check pg_hba.conf auth method for the source host; reset password with `ALTER USER foo PASSWORD 'newpass';` |
| `no pg_hba.conf entry for host "x.x.x.x"` | Client IP not listed in pg_hba.conf | Add a `host` line for the IP range; reload with `SELECT pg_reload_conf();` |
| `connection refused` on 5432 | PostgreSQL not listening on that interface | Check `listen_addresses` in postgresql.conf; default is `localhost` — change to `'*'` for all interfaces |
| `FATAL: remaining connection slots are reserved` | `max_connections` reached; only superuser slots remain | Check `SELECT count(*) FROM pg_stat_activity;`; add a connection pooler (PgBouncer) or raise `max_connections` |
| Lock contention / queries waiting | Row or table lock held by a blocked or idle transaction | `SELECT * FROM pg_locks JOIN pg_stat_activity USING (pid) WHERE granted = false;` — identify and terminate the blocker |
| Autovacuum not keeping up | Table bloat growing; `n_dead_tup` high | `SELECT relname, n_dead_tup, last_autovacuum FROM pg_stat_user_tables ORDER BY n_dead_tup DESC;`; tune `autovacuum_vacuum_cost_delay` |
| Disk full (WAL accumulation) | WAL not being archived or replicas lagging | `SELECT pg_walfile_name(pg_current_wal_lsn());`; check `pg_stat_replication` lag; free space or resolve replica lag |
| `pg_dump: error: query was canceled` | Statement timeout or pg_dump lacking privileges | Run as `postgres` superuser; check `statement_timeout` setting |

## Pain Points
- **pg_hba.conf: first match wins** — rules are evaluated top-to-bottom and the first matching line applies. A broad rule placed above a restrictive one will silently override it. Ordering matters; add specific rules before general ones.
- **`listen_addresses` defaults to `localhost`** — PostgreSQL refuses remote TCP connections out of the box. To allow remote access, set `listen_addresses = '*'` (or a specific IP) in postgresql.conf and add a matching `host` rule in pg_hba.conf, then reload both.
- **OS user `postgres` vs database role `postgres`** — they share a name but are separate. The OS user gets a `peer` auth entry in pg_hba.conf, which bypasses password checks. Application connections use a password-authenticated database role — do not conflate the two.
- **Connection pooling is not built in** — PostgreSQL creates one OS process per connection. At ~100–200 connections, context-switching overhead becomes measurable. PgBouncer in transaction mode is the standard solution; plan for it before hitting production.
- **WAL archiving complexity** — enabling `archive_mode` requires setting `archive_command` to a working script before enabling; a failing archive command will eventually stall the server once `max_wal_size` is consumed.
- **Major version upgrades require explicit migration** — `pg_upgrade` must be used (not a package upgrade). Data directory format changes between major versions (e.g., 15 → 16). Plan and test upgrades; logical replication is an alternative for low-downtime upgrades.
- **`work_mem` is per sort/hash operation, not per query** — a single complex query can allocate `work_mem` many times in parallel. Setting it too high with many concurrent queries causes OOM. Start at 4–16MB globally and override per-session for known heavy queries.
- **Replica promotion is permanent** — once a standby is promoted with `pg_ctl promote` or `SELECT pg_promote()`, it becomes a primary and cannot rejoin the old primary without a full re-sync (`pg_basebackup`).

## References
See `references/` for:
- `postgresql.conf.annotated` — full config with every directive explained, plus an annotated pg_hba.conf example
- `common-patterns.md` — initial setup, remote access, backup/restore, replication, query analysis, and PgBouncer
- `docs.md` — official documentation links
