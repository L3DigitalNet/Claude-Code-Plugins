# SQLite CLI Reference

## 1. Open and Explore a Database

```bash
# Open an existing file (creates it if absent)
sqlite3 /path/to/database.db

# Open in read-only mode
sqlite3 -readonly /path/to/database.db

# Run a single query from the shell (no interactive session)
sqlite3 /path/to/database.db "SELECT count(*) FROM users;"

# Run a single query and print column headers
sqlite3 -header /path/to/database.db "SELECT * FROM users LIMIT 5;"

# List tables and quit
sqlite3 /path/to/database.db ".tables"
```

Inside the interactive shell:
```sql
.help           -- full dot-command reference
.tables         -- list all tables
.tables user%   -- tables matching a pattern
.databases      -- list attached databases and their files
.quit           -- exit (or Ctrl-D)
```

---

## 2. Schema Inspection

```sql
-- Full schema (all CREATE statements)
.schema

-- Schema for one table
.schema users

-- Column names, types, nullability, and defaults
PRAGMA table_info(users);

-- Foreign key constraints
PRAGMA foreign_key_list(orders);

-- Index list for a table
PRAGMA index_list(users);

-- Columns in a specific index
PRAGMA index_info(idx_users_email);

-- All indexes in the database
SELECT * FROM sqlite_master WHERE type = 'index';

-- All tables, views, triggers
SELECT type, name FROM sqlite_master ORDER BY type, name;
```

---

## 3. Query and Format Output Modes

```sql
-- Available modes: column, table, box, markdown, json, csv, tabs, list, insert, quote
.mode column        -- fixed-width columns (good for terminals)
.mode table         -- ASCII table borders
.mode box           -- Unicode box-drawing borders
.mode markdown      -- GitHub Markdown table
.mode json          -- JSON array of objects
.mode csv           -- comma-separated values
.headers on         -- show column names in output
.headers off

-- Set column width in column mode
.width 20 30 10

-- Limit rows from shell
sqlite3 db.sqlite3 "SELECT * FROM users LIMIT 100;"

-- Explain query plan (check for missing indexes)
EXPLAIN QUERY PLAN SELECT * FROM orders WHERE user_id = 42;
```

---

## 4. Export

```bash
# Export entire database as SQL (stdout)
sqlite3 /path/to/db.sqlite3 .dump

# Export to a file
sqlite3 /path/to/db.sqlite3 ".output /tmp/dump.sql" ".dump" ".output stdout"

# Export a single table
sqlite3 /path/to/db.sqlite3 ".output /tmp/users.sql" ".dump users"

# Export a table as CSV
sqlite3 -header -csv /path/to/db.sqlite3 "SELECT * FROM users;" > /tmp/users.csv

# Export inside interactive shell
.headers on
.mode csv
.output /tmp/users.csv
SELECT * FROM users;
.output stdout       -- restore output to terminal
```

---

## 5. Import

```bash
# Import a SQL dump file
sqlite3 /path/to/db.sqlite3 < /tmp/dump.sql

# Same thing using .read inside the shell
sqlite3 /path/to/db.sqlite3 ".read /tmp/dump.sql"

# Import a CSV file into an existing table (first row = column names by default)
sqlite3 /path/to/db.sqlite3 ".import --csv /tmp/users.csv users"

# Import CSV and skip the header row explicitly
sqlite3 /path/to/db.sqlite3 ".import --csv --skip 1 /tmp/users.csv users"

# Import into a new table (SQLite infers columns from header row)
sqlite3 /path/to/db.sqlite3 ".import --csv /tmp/data.csv new_table"
```

---

## 6. Backup

```bash
# Online backup via dot-command (safe with concurrent writers)
sqlite3 /path/to/db.sqlite3 ".backup /tmp/backup.db"

# Backup with progress indicator
sqlite3 /path/to/db.sqlite3 ".backup --append /tmp/backup.db"

# VACUUM INTO: compacts and copies in one step (SQLite 3.27+)
sqlite3 /path/to/db.sqlite3 "VACUUM INTO '/tmp/compact-backup.db';"

# Simple file copy (safe only when no writers are active OR in WAL mode after a checkpoint)
sqlite3 /path/to/db.sqlite3 "PRAGMA wal_checkpoint(FULL);"
cp /path/to/db.sqlite3 /tmp/snapshot.db
```

---

## 7. PRAGMA Settings for Performance

```sql
-- Enable WAL mode: concurrent reads + one writer (persists across connections)
PRAGMA journal_mode = WAL;

-- Reduce fsync calls — safe for non-critical data, faster writes
PRAGMA synchronous = NORMAL;    -- default is FULL; OFF is fastest but risks corruption on crash

-- Increase page cache size (negative = kilobytes, positive = pages)
PRAGMA cache_size = -64000;     -- 64 MB cache

-- Store temp tables in memory instead of temp files
PRAGMA temp_store = MEMORY;

-- Enable foreign key enforcement (off by default, must set per connection)
PRAGMA foreign_keys = ON;

-- Show current WAL checkpoint status
PRAGMA wal_checkpoint;

-- Force a full checkpoint (blocks until complete)
PRAGMA wal_checkpoint(FULL);

-- Check page size (set before any tables are created; cannot change after)
PRAGMA page_size;
-- Set page size at database creation: PRAGMA page_size = 4096;

-- Verify all PRAGMA values
PRAGMA journal_mode;
PRAGMA synchronous;
PRAGMA cache_size;
```

---

## 8. Full-Text Search (FTS5)

```sql
-- Create an FTS5 virtual table (stores its own copy of the data)
CREATE VIRTUAL TABLE docs_fts USING fts5(title, body);

-- Populate from an existing table
INSERT INTO docs_fts(title, body) SELECT title, body FROM documents;

-- Search (returns rows where any column matches)
SELECT * FROM docs_fts WHERE docs_fts MATCH 'sqlite backup';

-- Rank by relevance (bm25 is built-in)
SELECT *, bm25(docs_fts) AS rank
FROM docs_fts
WHERE docs_fts MATCH 'database locked'
ORDER BY rank;

-- Prefix search
SELECT * FROM docs_fts WHERE docs_fts MATCH 'back*';

-- Content table pattern: FTS5 reads content from an existing table (no data duplication)
CREATE VIRTUAL TABLE docs_fts USING fts5(
    title, body,
    content='documents',
    content_rowid='id'
);
-- Rebuild index after bulk insert into the content table
INSERT INTO docs_fts(docs_fts) VALUES ('rebuild');

-- Drop FTS5 table
DROP TABLE docs_fts;
```

---

## 9. Attach Multiple Databases

```sql
-- Attach a second database file as an alias
ATTACH '/path/to/archive.db' AS archive;

-- Query across both databases
SELECT m.name, a.score
FROM main.users AS m
JOIN archive.scores AS a ON m.id = a.user_id;

-- Copy a table from attached database into main
INSERT INTO main.users SELECT * FROM archive.users;

-- List all attached databases
.databases

-- Detach when done
DETACH archive;
```

---

## 10. Integrity Check and Repair

```sql
-- Full integrity check (checks B-tree structure, index consistency, page counts)
PRAGMA integrity_check;
-- Returns "ok" if healthy; lists errors otherwise

-- Quick check (faster, skips some cross-reference validation)
PRAGMA quick_check;

-- Check foreign key violations
PRAGMA foreign_key_check;

-- Recover data from a corrupted database (shell command)
-- sqlite3 corrupt.db ".recover" | sqlite3 repaired.db

-- Alternatively, dump whatever is readable and reimport
sqlite3 corrupt.db ".dump" > /tmp/recovery.sql 2>/tmp/recovery_errors.txt
sqlite3 repaired.db < /tmp/recovery.sql
```
