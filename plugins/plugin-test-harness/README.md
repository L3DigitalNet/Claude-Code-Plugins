# Plugin Test Harness (PTH)

An MCP-based iterative testing framework for Claude Code plugins and MCP servers. Drives a tight test/fix/reload loop — generating tests, recording pass/fail results, applying source fixes, reloading the target plugin, and retesting — until your plugin converges to a stable, passing state.

## Summary

PTH treats plugin testing as an iterative convergence problem rather than a one-shot process. Each session creates a dedicated git branch in the target plugin's repository, giving you a complete audit trail of every test added and fix applied. Sessions persist to disk and can be resumed after interruption. Claude drives the loop interactively — you can inspect results, override decisions, or add tests at any point.

## Principles

**[P1] Claude's Judgment, Not Mechanical Rules** — No rigid enforcement gates or hard-coded safety thresholds. Claude assesses risk, decides approval workflows, and manages safety contextually — because tests span wildly varying plugin domains and environment configurations where rigid rules would be either too restrictive or too permissive.

**[P2] Convergence Over Single-Pass** — Testing is an iterative convergence problem. PTH drives successive test/fix/reload cycles and measures the trend (improving, plateau, oscillating, diverging) across iterations. A plugin is not done when the first run passes.

**[P3] Durable Session Assets** — The git branch and test definitions are the session's durable assets. If the environment fails catastrophically, the session can always be resumed from these.

**[P4] Transparent Errors** — PTH always surfaces raw error output alongside its own interpretation. Exceptions are never silently swallowed; Claude always has enough context to decide the next step.

**[P5] Audit Trail by Default** — Every fix is committed to the session branch immediately. The full debug history is always recoverable via `git log` — no extra logging or manual export required.

## Installation

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install plugin-test-harness@l3digitalnet-plugins
```

## Installation Notes

After installation, navigate to the plugin cache directory and install Node.js dependencies:

```bash
cd ~/.claude/plugins/<marketplace>/plugin-test-harness
npm install
```

The `dist/` directory ships prebuilt — a build step is only required if you modify the TypeScript source.

## Usage

PTH operates as an iterative loop. Start with a preflight check, then cycle through generate → run → record → fix → reload until convergence:

```
pth_preflight       → verify target plugin is readable, detect its type
pth_start_session   → create session + git branch in the target repo
pth_generate_tests  → auto-generate test proposals from plugin source
[Run tests manually or via Claude]
pth_record_result   → record pass/fail for each test
pth_get_iteration_status → check convergence trend
pth_apply_fix       → patch source, sync to cache, reload
[Repeat from pth_generate_tests]
pth_end_session     → generate final report, close branch
```

To resume an interrupted session:
```
pth_resume_session({ pluginPath: "...", branch: "pth/my-plugin-2026-02-18-abc123" })
```

## Tools

### Session Management

| Tool | Description |
|------|-------------|
| `pth_preflight` | Validate target plugin is readable and detect its type |
| `pth_start_session` | Create a new test session and git branch |
| `pth_resume_session` | Resume an interrupted session by branch name |
| `pth_end_session` | Close session and generate final report |
| `pth_get_session_status` | Current session state, iteration count, pass/fail summary |

### Test Management

| Tool | Description |
|------|-------------|
| `pth_generate_tests` | Auto-generate test proposals from plugin source and schema |
| `pth_list_tests` | List all tests in the session with pass/fail status |
| `pth_create_test` | Manually add a single test (provide YAML inline) |
| `pth_edit_test` | Modify an existing test by ID |

### Execution & Results

| Tool | Description |
|------|-------------|
| `pth_record_result` | Record pass/fail for a test after running it |
| `pth_get_results` | Fetch all results for current or past iterations |
| `pth_get_test_impact` | Show which tests are affected by a specific fix |
| `pth_get_iteration_status` | Convergence trend, pass rate, and recommendation for next step |

### Fix Management

| Tool | Description |
|------|-------------|
| `pth_apply_fix` | Apply a source patch and commit it to the session branch |
| `pth_sync_to_cache` | Sync session branch files to the plugin cache directory |
| `pth_reload_plugin` | Restart the target MCP server after a fix |
| `pth_get_fix_history` | List all fixes applied in this session |
| `pth_revert_fix` | Revert a specific fix by commit hash |
| `pth_diff_session` | Show all changes made since session start |

## Modes

PTH auto-detects the target plugin type during `pth_preflight` — no `mode` parameter needed.

| Mode | When used | How PTH tests |
|------|-----------|---------------|
| `mcp` | Plugin has `.mcp.json` and exposes MCP tools | Connects as a native MCP client; introspects tool schemas via `tools/list` |
| `plugin` | Hook-based or command-only plugin | Analyses source files (hooks, commands, skills) to infer expected behavior |

## Test YAML Format

Tests are stored as YAML files in the session directory:

```yaml
id: "list-tools-returns-array"
name: "tools/list returns an array"
description: "The MCP server must respond to tools/list with a non-empty array."
mode: "mcp"
type: "scenario"
steps:
  - tool: "tools/list"
    input: {}
    expect:
      success: true
      output_contains: "tools"
tags:
  - "smoke"
  - "protocol"
```

`expect` supports: `success`, `output_contains`, `output_equals`, `output_matches`, `output_json`, `error_contains`, `exit_code`, `stdout_contains`, `stdout_matches`.

## Session Branches

Every session creates a dedicated git branch in the **target plugin's repository**:

```
pth/<plugin>-<timestamp>
```

After a session ends:

```bash
# See all commits from the session
git log pth/my-plugin-2026-02-18-abc123 --oneline

# Diff the entire session against the base branch
git diff main...pth/my-plugin-2026-02-18-abc123

# Merge a successful session to main
git checkout main && git merge --no-ff pth/my-plugin-2026-02-18-abc123
```

Abandoned sessions can be deleted without affecting your working branches:
```bash
git branch -d pth/my-plugin-2026-02-18-abc123
```

## Convergence

`pth_get_iteration_status` reports the current trend across iterations:

| Trend | Meaning | Recommended action |
|-------|---------|-------------------|
| `improving` | Pass rate rising each iteration | Keep iterating |
| `plateau` | Pass rate has stalled | Try a different fix strategy |
| `oscillating` | Tests flip between pass and fail | Use `pth_get_test_impact` to find the regressing fix |
| `diverging` | Pass rate is falling | Use `pth_revert_fix` before continuing |

## Requirements

- Node.js 20+
- Target plugin must be accessible on the local filesystem
- For `mcp` mode: the target MCP server must be startable via its `.mcp.json` command

## Planned Features

- **Parallel test execution** — run independent tests concurrently to reduce session iteration time
- **HTML report export** — generate a self-contained HTML report from a completed session for sharing outside Claude
- **Test suite import** — seed a new session from an existing YAML test file rather than starting from zero
- **Watch mode** — automatically trigger a new iteration whenever source files in the target plugin change

## Known Issues

- **`npm install` must be run manually** — the plugin installer does not execute `npm install`; dependencies are not available until you run it in the plugin cache directory (see Installation Notes above)
- **`pth_reload_plugin` only works for MCP servers** — reloading hook-based or command-only plugins requires restarting the Claude Code session
- **Session state is local** — session files are written to a subdirectory of the plugin cache; if the cache is cleared or the plugin is reinstalled, in-progress sessions cannot be resumed
- **`pth_apply_fix` commits immediately** — there is no staging area; use `pth_revert_fix` to undo a commit if a fix causes regressions

## Project Links

- Repository: [L3DigitalNet/Claude-Code-Plugins](https://github.com/L3DigitalNet/Claude-Code-Plugins)
- Design document: `docs/PTH-DESIGN.md`
- Issues and feedback: [GitHub Issues](https://github.com/L3DigitalNet/Claude-Code-Plugins/issues)
