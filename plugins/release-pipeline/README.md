# Release Pipeline Plugin

Autonomous release pipeline for any repo. Two modes:

## Quick Merge

Commit all changes and merge testing to main:

```
/release
```

Or say: "ship it", "merge to main"

**What it does:**
1. Verifies clean state and noreply email
2. Stages and commits any pending changes
3. Shows diff summary — waits for your GO
4. Merges testing -> main, pushes, returns to testing

## Full Release

Run the complete release pipeline with a version:

```
/release v1.2.0
```

Or say: "Release v1.2.0 for my-project"

**What it does:**

| Phase | Action | Parallel? |
|-------|--------|-----------|
| 1. Pre-flight | Run tests, audit docs, check git state | Yes (3 agents) |
| 2. Preparation | Bump versions, generate changelog, show diff | Sequential |
| 3. Release | Commit, merge, tag, push, GitHub release | Sequential |
| 4. Verification | Confirm tag, release page, notes | Sequential |

## Fail-Fast

If anything fails, the pipeline stops immediately and suggests rollback steps. No destructive auto-recovery.

## Supported Test Runners

Auto-detected from project files:

- **Python**: pytest (pyproject.toml, pytest.ini, setup.cfg)
- **Node.js**: npm test (package.json)
- **Rust**: cargo test (Cargo.toml)
- **Go**: go test (go.mod)
- **Make**: make test (Makefile)
- **Fallback**: reads CLAUDE.md for test commands

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install release-pipeline@l3digitalnet-plugins
```
