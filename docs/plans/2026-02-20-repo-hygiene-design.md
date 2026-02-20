# repo-hygiene — Design Document

Version: 1.0 (Approved)
Status: Ready for Implementation
Last Updated: 2026-02-20

---

## 1. Problem Statement

When maintaining this Claude-Code-Plugins monorepo over time, several categories of hygiene drift accumulate silently: `.gitignore` files grow stale patterns or miss common transient paths; marketplace manifest `installPath` values drift from actual filesystem locations after renames; plugin READMEs describe "Known Issues" that have since been fixed and "Principles" that no longer match the code; Claude's plugin state files (`installed_plugins.json`, `settings.json`) diverge from each other and from the filesystem, causing "failed to load" errors; and uncommitted work-in-progress lingers for days without being staged.

A one-off CLAUDE.md instruction doesn't catch these because they require active scanning, not passive reminders. A `/hygiene` sweep command runs all five checks, auto-fixes safe items immediately, and surfaces risky changes for explicit approval in a single session.

---

## 2. Goals & Non-Goals

### Goals

- Runs all five hygiene checks in one invocation and produces a complete, actionable report
- Distinguishes auto-fixable findings (safe to apply immediately) from needs-approval findings (destructive or ambiguous)
- Supports `--dry-run` to preview all proposed changes with zero side effects
- Leaves the repo in a cleaner state than it started — or stops and explains why it couldn't

### Non-Goals

- Not a general-purpose tool for other git repos — scoped to this monorepo's conventions
- Does not replace `validate-marketplace.sh` — that validates schema; this validates filesystem reality
- Does not auto-remove plugin state entries without explicit approval

---

## 3. Design Principles

**P1 — Fail transparently**: Script failures surface raw output and a recovery hint. No silent swallowing of errors. A partial result is never presented as a complete one.
*Cost: The sweep may abort mid-run rather than limping through with degraded output.*

**P2 — Approval before irreversibility**: Anything that removes content (gitignore lines, plugin state entries, committed content) requires explicit confirmation, even when not in `--dry-run` mode.
*Cost: More prompts than a fully automated sweep; removal operations never happen silently.*

**P3 — Dry-run is complete**: `--dry-run` emits the full report with all proposed fix commands labeled `[would apply]` — not a subset. The user sees exactly what would happen.
*Cost: The semantic scan (Check 3) still runs in dry-run mode; it just suppresses the writing step.*

---

## 4. Components

### Command

**`commands/hygiene.md`** — User-invocable as `/hygiene [--dry-run]`. Orchestrates the full sweep: runs mechanical scan scripts in parallel, performs semantic README analysis inline, classifies findings, applies auto-fixes (unless dry-run), presents needs-approval items for multi-select confirmation.

### Scripts

**`scripts/check-gitignore.sh`** — Scans all `.gitignore` files in the repo. For each pattern:
- Tests if it matches any existing path (using `git check-ignore`)
- Tests if common missing patterns (`.claude/state/`, `*.pyc`, `node_modules/`, `dist/`) are absent
- Auto-fixable: append missing well-known patterns
- Needs-approval: patterns that match nothing (stale candidates)

**`scripts/check-manifests.sh`** — Reads `.claude-plugin/marketplace.json` and every `plugin.json`. Cross-references `source` paths and any `installPath` values against actual filesystem locations.
- Auto-fixable: path exists but has wrong case or trailing slash mismatch
- Needs-approval: referenced path not found on filesystem

**`scripts/check-orphans.sh`** — Compares three sources of truth: `~/.claude/plugins/installed_plugins.json`, `~/.claude/settings.json` `enabledPlugins`, and the filesystem cache at `~/.claude/plugins/cache/`. Reports:
- Entries in `installed_plugins.json` with no matching cache directory
- Entries in `settings.json` not present in `installed_plugins.json`
- Cache directories not referenced by either state file
All orphan findings are needs-approval (removal is destructive).

**`scripts/check-stale-commits.sh`** — Uses `git status --porcelain` + `git log` to detect uncommitted changes. For each modified/untracked file, checks `stat` mtime against current time. Flags files modified more than 24 hours ago.
All stale-commit findings are needs-approval (staging/committing requires user intent).

---

## 5. Script Output Contract

Each script emits a single JSON object to stdout on success, or exits non-zero with a human-readable error on stderr on failure:

```json
{
  "check": "gitignore | manifests | orphans | stale-commits",
  "findings": [
    {
      "severity": "warn | info",
      "path": "relative/path/to/affected/file",
      "detail": "Human-readable description of the finding",
      "auto_fix": true,
      "fix_cmd": "echo '*.pyc' >> .gitignore"
    },
    {
      "severity": "warn",
      "path": ".gitignore",
      "detail": "Pattern 'build/' matches nothing in the working tree",
      "auto_fix": false,
      "fix_cmd": null
    }
  ]
}
```

---

## 6. Command Workflow

### Phase 0 — Parse flags
- Extract `--dry-run` flag; store boolean `DRY_RUN`
- Resolve `${CLAUDE_PLUGIN_ROOT}` for script paths

### Phase 1 — Mechanical scans (parallel)
Run all four scripts simultaneously and capture JSON output from each.

### Phase 2 — Semantic scan (inline)
For each plugin directory with a README, read its `Known Issues` and `Principles` sections. Compare against actual codebase reality (script contents, hook configurations, command behavior). Generate findings for:
- Principles that no longer match the code
- Known Issues that appear to have been resolved
All findings from this phase are needs-approval (semantic judgment, not mechanical).

### Phase 3 — Classify & report
- Partition all findings: `auto_fixable[]` (have `fix_cmd`, `auto_fix: true`) and `needs_approval[]`
- If `DRY_RUN`: emit full report with `[DRY RUN — would apply]` labels; stop here
- If not `DRY_RUN`: execute each `fix_cmd` for auto-fixable items immediately
- Present `✅ Auto-fixed N items` with a diff-style list
- Present `⚠ N items need your approval` using `AskUserQuestion` multi-select
- Apply approved fixes from needs-approval set

---

## 7. File Layout

```
plugins/repo-hygiene/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   └── hygiene.md
├── scripts/
│   ├── check-gitignore.sh
│   ├── check-manifests.sh
│   ├── check-orphans.sh
│   └── check-stale-commits.sh
├── CHANGELOG.md
└── README.md
```

---

## 8. Testing Strategy

Test the plugin against this repo immediately after implementation:

1. **check-gitignore.sh** — manually add a stale pattern to a test `.gitignore`, run script, verify it appears in findings with `auto_fix: false`
2. **check-manifests.sh** — temporarily rename a plugin dir, run script, verify the broken path appears as needs-approval
3. **check-orphans.sh** — inspect actual `~/.claude/` state; verify output reflects real divergence (if any)
4. **check-stale-commits.sh** — verify against current working tree dirty state (gitStatus shows M files)
5. **--dry-run** — run `/hygiene --dry-run`, confirm no files are modified and report is complete
6. **End-to-end** — run `/hygiene` without dry-run, confirm auto-fixes are applied, needs-approval items presented

---

## 9. Marketplace Entry

```json
{
  "name": "repo-hygiene",
  "description": "Autonomous maintenance sweep for the Claude-Code-Plugins monorepo — validates .gitignore patterns, manifest paths, README freshness, plugin state consistency, and stale uncommitted changes.",
  "version": "1.0.0",
  "author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" },
  "source": "./plugins/repo-hygiene",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/repo-hygiene"
}
```
