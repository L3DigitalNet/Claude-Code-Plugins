# PTH Persistent Storage Design

**Date:** 2026-02-22
**Status:** Approved
**Feature:** Cross-session persistent storage at `~/.pth/PLUGIN_NAME`

## Problem

PTH currently stores all session artifacts (tests, results, reports) in the git worktree
(`/tmp/pth-worktree-*`). The worktree is removed at `pth_end_session`, leaving no durable
record of past sessions. Resuming a session re-loads tests from the worktree, which means
stale worktree data from a previous plugin can be loaded erroneously when testing a different
plugin.

## Goals

1. Persist tests, results, reports, fix history, and plugin snapshots across sessions.
2. Run a gap analysis at session start — compare saved plugin structure vs. current source
   to surface what needs new/updated tests.
3. Clear worktree `.pth/` data before session end to eliminate stale data loading.

## Storage Layout

```
~/.pth/
└── PLUGIN_NAME/
    ├── index.json                      # metadata: lastSession, pluginName, createdAt
    ├── plugin-snapshot.json            # tool schemas/manifest at last session end
    ├── results-history.json            # {testId: [{sessionId, status, timestamp}]}
    ├── tests/
    │   ├── mcp-tests.yaml              # accumulated tests (MCP mode)
    │   └── plugin-tests.yaml           # accumulated tests (plugin mode)
    └── sessions/
        └── YYYY-MM-DD-<sessionId>/
            ├── SESSION-REPORT.md
            ├── iteration-history.json  # [{iteration, passRate, passCount, failCount}]
            └── fix-history.json        # fix commits with PTH trailers
```

`PLUGIN_NAME` is the same sanitized slug used for branch names (existing `slugify()` utility).
`index.json` acts as the existence marker — present means history exists for this plugin.

No new npm dependencies — uses Node.js built-ins (`fs.promises`, `path`, `os`).

## Session Lifecycle Changes

### `pth_start_session`

1. Create git worktree in `/tmp` (unchanged).
2. Check `~/.pth/PLUGIN_NAME/index.json` — if present, load history:
   a. Load saved tests from `~/.pth/PLUGIN_NAME/tests/` into `TestStore`.
   b. Run gap analysis (see below).
3. Return session response including gap analysis summary.
4. Worktree `.pth/` holds only runtime data: `session-state.json`, `active-session.lock`,
   `tool-schemas.json`. No tests written to worktree at start.

### `pth_end_session`

1. Persist tests → `~/.pth/PLUGIN_NAME/tests/` (overwrite — tests are authoritative).
2. Append results → `~/.pth/PLUGIN_NAME/results-history.json`.
3. Write `SESSION-REPORT.md` → `~/.pth/PLUGIN_NAME/sessions/<sessionId>/`.
4. Write `iteration-history.json` → `~/.pth/PLUGIN_NAME/sessions/<sessionId>/`.
5. Write `fix-history.json` → `~/.pth/PLUGIN_NAME/sessions/<sessionId>/`.
6. Snapshot current plugin structure → `~/.pth/PLUGIN_NAME/plugin-snapshot.json`.
7. Update `~/.pth/PLUGIN_NAME/index.json`.
8. **Clean worktree**: remove `.pth/` directory from worktree before `git worktree remove`.
   This eliminates stale data that could be loaded if another session starts on a different plugin.

### `pth_resume_session`

- Load tests from `~/.pth/PLUGIN_NAME/tests/` (not worktree — persistent store is authoritative).
- Load `session-state.json` from worktree (runtime state for in-progress session).

## Gap Analysis

Runs during `pth_start_session` when `plugin-snapshot.json` exists.

### Plugin Snapshot Structure

```typescript
interface PluginSnapshot {
  pluginMode: 'mcp' | 'plugin';
  capturedAt: string;           // ISO timestamp
  tools: Array<{                // MCP mode
    name: string;
    description: string;
    inputSchema: object;
  }>;
  commands: string[];           // plugin mode: names from commands/
  skills: string[];             // plugin mode: names from skills/
  agents: string[];             // plugin mode: names from agents/
}
```

Snapshot is built from plugin source files (not a live server connection), making it
resilient to broken or stopped plugins.

### Gap Categories

| Category | Definition |
|----------|-----------|
| `newTools` | Present in current plugin but absent from snapshot |
| `modifiedTools` | Present in both but `inputSchema` changed (string comparison) |
| `removedTools` | In snapshot but absent from current plugin |
| `unchangedTools` | No change detected |
| `staleTests` | Tests whose target tool appears in `removedTools` |

### Gap Analysis Response (included in `pth_start_session` output)

```json
{
  "savedTests": 12,
  "gapAnalysis": {
    "newTools": ["search_issues", "create_pr"],
    "modifiedTools": ["list_repos"],
    "removedTools": ["delete_webhook"],
    "unchangedTools": ["get_me", "get_commit"],
    "staleTests": ["test-delete-webhook-001"],
    "recommendation": "Generate tests for 2 new tools and 1 modified tool (suggest: 6 tests)"
  }
}
```

Gap analysis is **informational only** — no automatic test generation. The AI agent decides
how to respond (typically calling `pth_generate_tests` with the gap tools list).

## New Modules

### `src/persistence/`

| File | Responsibility |
|------|---------------|
| `types.ts` | `PluginStore`, `SessionRecord`, `GapAnalysisResult`, `PluginSnapshot` interfaces |
| `store-manager.ts` | Read/write `~/.pth/PLUGIN_NAME/` — load tests, save artifacts, update index |
| `gap-analyzer.ts` | Compare `PluginSnapshot` vs current `PluginSnapshot` → `GapAnalysisResult` |
| `plugin-scanner.ts` | Walk plugin source to build current `PluginSnapshot` from files |

## Modified Modules

| Module | Change |
|--------|--------|
| `src/session/manager.ts` | Call `StoreManager` at `startSession` (load + gap) and `endSession` (persist all) |
| `src/session/git.ts` | Add `cleanWorktreePthDir()` — remove `.pth/` from worktree before removal |
| `src/testing/store.ts` | `loadFromDir()` accepts any path (worktree or persistent store) |
| `src/results/tracker.ts` | Add `exportHistory()` → serializable format for persistence |
| `src/tool-registry.ts` | `pth_generate_tests` gains optional `tools` param (gap-targeted generation) |

## Out of Scope

- No SQLite or external query layer.
- No automatic gap-triggered test generation.
- No cross-plugin result aggregation.
- No UI/dashboard for historical data.
