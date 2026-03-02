---
name: sqlite
description: >
  SQLite embedded database administration: opening and querying database files,
  schema inspection, data import/export, backup, PRAGMA tuning, WAL mode, and
  troubleshooting. Triggers on: sqlite, SQLite, sqlite3, .db file, embedded
  database, single-file database, sqlite backup, database locked, WAL mode,
  PRAGMA, FTS5, full-text search sqlite.
globs:
  - "**/*.db"
  - "**/*.sqlite"
  - "**/*.sqlite3"
---

## Identity
- **Binary**: `sqlite3`
- **No service**: SQLite is embedded — there is no daemon, no port, no systemd unit
- **Database**: a single file on disk (e.g. `/var/lib/myapp/data.db`)
- **Distro install**: `apt install sqlite3` / `dnf install sqlite`

## Key Operations

| Operation | Command |
|-----------|---------|
| Open a database file | `sqlite3 /path/to/db.sqlite3` |
| Help (dot-command list) | `.help` |
| List tables | `.tables` |
| Show CREATE statements | `.schema` or `.schema <table>` |
| Show column info | `PRAGMA table_info(<table>);` |
| Column-aligned output | `.mode column` |
| Table-style output | `.mode table` |
| JSON output | `.mode json` |
| CSV output | `.mode csv` |
| Show column headers | `.headers on` |
| SELECT example | `SELECT * FROM users WHERE id = 1;` |
| INSERT example | `INSERT INTO users (name, email) VALUES ('Alice', 'a@example.com');` |
| UPDATE example | `UPDATE users SET email = 'b@example.com' WHERE id = 1;` |
| DELETE example | `DELETE FROM users WHERE id = 1;` |
| Export entire DB as SQL | `.dump` (stdout) or `.output dump.sql` then `.dump` |
| Import SQL file | `.read /path/to/dump.sql` |
| Import CSV into table | `.import --csv /path/to/file.csv tablename` |
| Reclaim deleted space | `VACUUM;` |
| Integrity check | `PRAGMA integrity_check;` |
| Journal mode | `PRAGMA journal_mode;` / `PRAGMA journal_mode = WAL;` |
| Page size | `PRAGMA page_size;` |
| Attach a second DB | `ATTACH '/path/other.db' AS other;` |
| Online backup | `.backup /path/to/backup.db` |
| Quit | `.quit` or Ctrl-D |

## Expected State
- No daemon running — a process opens and closes the file directly
- File permissions govern read/write access: `ls -lh /path/to/db.sqlite3`
- WAL mode produces two side-car files: `db.sqlite3-wal` and `db.sqlite3-shm`
- A healthy integrity check returns a single row: `ok`

## Operational Checks
1. `file /path/to/db.sqlite3` → should report `SQLite 3.x database`
2. `sqlite3 db.sqlite3 "PRAGMA integrity_check;"` → `ok`
3. `sqlite3 db.sqlite3 ".tables"` → lists tables without error
4. `ls -lh db.sqlite3` → confirm file size is non-zero and permissions are correct

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `database is locked` | Another writer has an exclusive lock | Only one write connection at a time; switch to WAL mode (`PRAGMA journal_mode = WAL`) for concurrent reads |
| `disk I/O error` | Bad file permissions, full disk, or corruption | Check `ls -lh`, `df -h`, and `PRAGMA integrity_check` |
| WAL side-car files left behind | Crash or missing checkpoint | Safe to open — SQLite auto-checkpoints on next open; force with `PRAGMA wal_checkpoint(FULL);` |
| `no such table` | Wrong database file opened | Verify path with `sqlite3 db.sqlite3 ".tables"` |
| CSV import encoding errors | Non-UTF-8 source file | Convert with `iconv -f latin1 -t utf-8 file.csv > file_utf8.csv` then re-import |
| Slow queries on large database | Missing index | `EXPLAIN QUERY PLAN SELECT ...;` — look for `SCAN TABLE` instead of `SEARCH TABLE USING INDEX` |
| `unable to open database file` | Path does not exist or directory not writable | `ls -ld $(dirname /path/to/db.sqlite3)` — parent directory must be writable |

## Pain Points
- **Single writer**: SQLite serializes all writes. Applications with high write concurrency should use WAL mode, or consider a client-server database.
- **WAL mode**: `PRAGMA journal_mode = WAL` allows concurrent reads and one writer simultaneously. Default (DELETE) mode blocks readers during writes.
- **No user authentication**: Access control is purely filesystem-based. Any OS user with read permission on the file can read the entire database.
- **VACUUM needed after bulk deletes**: SQLite does not shrink the file automatically after large deletes. Run `VACUUM;` or `VACUUM INTO '/path/backup.db'` to reclaim space.
- **Type affinity, not strict typing**: SQLite uses type affinity — `INSERT INTO t (int_col) VALUES ('abc')` succeeds silently unless the table was created with `STRICT`. This causes surprises when migrating from other databases.
- **Datetime has no native type**: Dates are stored as TEXT (ISO-8601), REAL (Julian day), or INTEGER (Unix timestamp). `strftime()` and `date()` functions handle conversion but behavior differs from PostgreSQL/MySQL.
- **FTS5 is a separate virtual table**: Full-text search requires creating a `VIRTUAL TABLE ... USING fts5(...)` and inserting separately from the main table, or using a content table.

## References
See `references/` for:
- `sqlite-cli.md` — task-organized CLI reference: open, inspect, query, export, import, backup, PRAGMA tuning, FTS5, attach
- `docs.md` — official documentation links
