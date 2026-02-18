# Release Pipeline Plugin

Interactive release pipeline for any repo. One command, six options.

## Usage

```
/release
```

Or say: "ship it", "merge to main", "cut a release", "release v1.2.0"

The command auto-detects your repository state and presents a context-aware menu:

| Option | Description |
|--------|-------------|
| Quick Merge | Commit and merge testing → main (no version bump) |
| Full Release | Semver release with pre-flight, changelog, tag, GitHub release |
| Plugin Release | Release a single plugin from a monorepo (scoped tag + changelog) |
| Release Status | Show unreleased commits, last tag, changelog drift |
| Dry Run | Simulate a full release without any changes |
| Changelog Preview | Generate and display a changelog entry |

## Context-Aware

The menu adapts to your repo:
- **Monorepo?** Plugin Release option appears with unreleased plugin count
- **Dirty tree?** Quick Merge warns about uncommitted changes
- **Version suggestion** auto-calculated from conventional commits (feat → minor, fix → patch, BREAKING → major)

## Full Release Workflow

| Phase | Action | Parallel? |
|-------|--------|-----------|
| 0. Detection | Auto-detect repo state, suggest version | Yes |
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
