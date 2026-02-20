# repo-hygiene

Autonomous maintenance sweep for the Claude-Code-Plugins monorepo.

## Usage

```
/hygiene [--dry-run]
```

Runs five checks and auto-fixes safe items. Risky changes are presented for approval.

## Checks

| # | Check | Auto-fixable |
|---|-------|-------------|
| 1 | `.gitignore` patterns (stale / missing) | Append missing patterns |
| 2 | Marketplace manifest `source` paths | Normalize trailing slashes |
| 3 | README `Known Issues` / `Principles` freshness | No (semantic judgment) |
| 4 | Plugin state orphans (installed_plugins.json, settings.json, cache) | No (destructive) |
| 5 | Uncommitted changes older than 24h | No (requires user intent) |

## `--dry-run`

Shows the full report with proposed `[would apply]` labels. No files are modified.

## Auto-fix vs Needs-Approval

**Auto-fixed immediately:**
- Missing `.gitignore` patterns for well-known transient files (appended, never removed)

**Always needs your approval:**
- Removing stale `.gitignore` patterns
- Plugin state inconsistencies (installed_plugins.json / settings.json / cache)
- Staging uncommitted files
- Any README documentation updates
