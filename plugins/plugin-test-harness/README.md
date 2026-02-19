# Plugin Test Harness (PTH)

An MCP-based iterative testing framework for Claude Code plugins and MCP servers. PTH drives a tight test/fix/reload loop — starting from zero tests, generating proposals, recording pass/fail results, applying source fixes, reloading the target plugin, and retesting — until your plugin converges to a stable, passing state.

Each test run lives on its own git branch for a full audit trail of what changed, what was fixed, and when it passed.

---

## Install

Add the marketplace and install the plugin from within a Claude Code session:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install plugin-test-harness@l3digitalnet-plugins
```

The plugin exposes its `pth_*` tools through an MCP server (`dist/index.js`). Build it once after install:

```bash
cd ~/.claude/plugins/plugin-test-harness
npm install
npm run build
```

---

## Workflow Overview

PTH operates as an iterative loop. Each pass is one iteration:

```
pth_start_session
       |
       v
pth_generate_tests  (or pth_create_test for manual tests)
       |
       v
[Run tests against the target plugin]
       |
       v
pth_record_result  (for each test)
       |
       v
pth_get_iteration_status  (check convergence trend)
       |
       v
pth_apply_fix  (patch source, sync to cache, reload)
       |
       v
[Repeat from generate/run]
       |
       v
pth_end_session  (generates final report, closes branch)
```

Claude drives this loop interactively. You can inspect results, override decisions, or add tests at any point. The session persists to disk so it can be resumed after interruption with `pth_resume_session`.

---

## Two Modes

PTH supports two plugin types:

### `mcp` mode — MCP server plugins

Use this when the target is an MCP server (has a `.mcp.json` and exposes tools via the MCP protocol). PTH connects to the server as a native MCP client and can introspect its tool schemas via `tools/list`.

During `pth_preflight`, provide the target plugin's `.mcp.json` path so PTH can discover available tools:

```
pth_preflight({ pluginPath: "/path/to/my-plugin", mode: "mcp" })
```

### `hook` / `plugin` mode — Hook-based and command-based plugins

Use this when the target is a hook-based plugin or a plugin with slash commands but no MCP server. PTH analyses the plugin's source files (hooks, commands, skills) to generate tests and infer expected behavior.

```
pth_preflight({ pluginPath: "/path/to/my-plugin", mode: "hook" })
```

---

## Starting a Session

### 1. Preflight check

Verify PTH can locate and read the target plugin before committing to a session:

```
pth_preflight({
  pluginPath: "/home/user/projects/Claude-Code-Plugins/plugins/my-plugin"
})
```

PTH will detect the plugin type, check for a manifest, and report any issues.

### 2. Start the session

```
pth_start_session({
  pluginPath: "/home/user/projects/Claude-Code-Plugins/plugins/my-plugin",
  sessionName: "my-plugin-v1-testing",
  description: "Initial test pass for my-plugin v1.0.0"
})
```

PTH creates a git branch named `pth/<sessionName>-<timestamp>` in the plugin's repo. All fixes applied during the session are committed to this branch, leaving your working branch untouched.

---

## Test YAML Format

Tests are stored as YAML files in the session's test directory. Each test describes one scenario:

```yaml
id: "list-tools-returns-array"
name: "tools/list returns an array"
description: "The MCP server must respond to tools/list with a non-empty array of tool definitions."
pluginType: "mcp"
category: "protocol"
severity: "critical"
steps:
  - action: "call_tool"
    tool: "tools/list"
    args: {}
    expect:
      type: "array"
      minLength: 1
tags:
  - "smoke"
  - "protocol"
```

Fields:
- `id` — unique identifier (slug format)
- `name` — short human-readable label
- `description` — what the test verifies
- `pluginType` — `mcp`, `hook`, or `command`
- `category` — `protocol`, `behavior`, `error-handling`, `performance`, etc.
- `severity` — `critical`, `high`, `medium`, or `low`
- `steps` — ordered list of actions and assertions
- `tags` — optional labels for filtering

---

## Key Tools Reference

### Session

| Tool | Description |
|------|-------------|
| `pth_preflight` | Validate target plugin is readable and detect its type |
| `pth_start_session` | Create a new test session and git branch |
| `pth_resume_session` | Resume an interrupted session by ID |
| `pth_end_session` | Close session, generate final report |
| `pth_get_session_status` | Current session state, iteration count, pass/fail summary |

### Tests

| Tool | Description |
|------|-------------|
| `pth_generate_tests` | Auto-generate test proposals from plugin source and schema |
| `pth_list_tests` | List all tests in the session (with pass/fail status) |
| `pth_create_test` | Manually add a single test (provide YAML inline) |
| `pth_edit_test` | Modify an existing test by ID |

### Execution

| Tool | Description |
|------|-------------|
| `pth_record_result` | Record pass/fail for a test after running it |
| `pth_get_results` | Fetch all results for current or past iterations |
| `pth_get_test_impact` | Show which tests are affected by a specific fix |

### Fixes

| Tool | Description |
|------|-------------|
| `pth_apply_fix` | Apply a source patch and commit it to the session branch |
| `pth_sync_to_cache` | Sync session branch files to the plugin cache directory |
| `pth_reload_plugin` | Restart the target MCP server after a fix |
| `pth_get_fix_history` | List all fixes applied in this session |
| `pth_revert_fix` | Revert a specific fix by commit hash |
| `pth_diff_session` | Show all changes made since session start |

### Iteration

| Tool | Description |
|------|-------------|
| `pth_get_iteration_status` | Convergence trend, pass rate, recommendation for next step |

---

## Session Branches

Every PTH session creates a dedicated git branch:

```
pth/<sessionName>-<timestamp>
```

This branch belongs to the **target plugin's repository** (not the PTH plugin repo). All fixes applied during the session are committed there, giving you a complete history of changes ordered by iteration.

After a session ends, review what changed:

```bash
# See all commits from the session
git log pth/my-plugin-v1-testing-1708300000 --oneline

# Diff the entire session against the base branch
git diff main...pth/my-plugin-v1-testing-1708300000

# Merge a successful session to main
git checkout main
git merge --no-ff pth/my-plugin-v1-testing-1708300000
```

Abandoned sessions can be deleted without affecting your working branches:

```bash
git branch -d pth/my-plugin-v1-testing-1708300000
```

---

## Convergence

`pth_get_iteration_status` reports the current trend across iterations:

| Trend | Meaning |
|-------|---------|
| `improving` | Pass rate is rising each iteration — keep going |
| `plateau` | Pass rate has stalled — consider a different fix strategy |
| `oscillating` | Tests flip between pass and fail — a fix is regressing something else |
| `diverging` | Pass rate is falling — recent fixes are making things worse |

When the trend is `improving` and the pass rate reaches 100%, PTH recommends calling `pth_end_session` to close out and generate the final report. For `oscillating` or `diverging`, use `pth_get_test_impact` and `pth_revert_fix` to identify and undo problematic changes before continuing.

---

## Requirements

- Node.js 20+
- The target plugin must be accessible on the local filesystem
- For `mcp` mode: the target MCP server must be startable via its `.mcp.json` command

---

## Project Links

- Repository: [L3DigitalNet/Claude-Code-Plugins](https://github.com/L3DigitalNet/Claude-Code-Plugins)
- Design document: `docs/PTH-DESIGN.md`
- Issues and feedback: [GitHub Issues](https://github.com/L3DigitalNet/Claude-Code-Plugins/issues)
