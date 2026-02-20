# Release Pipeline

Interactive release pipeline for any repo. One command, six options.

## Summary

Release Pipeline streamlines the full release lifecycle into a single `/release` command. It auto-detects your repository state, suggests a semantic version from conventional commits, runs pre-flight checks in parallel (tests, docs, git state), generates a changelog entry, and creates a tagged GitHub release — all with fail-fast behavior and no destructive auto-recovery.

## Principles

**[P1] Fail Fast, No Auto-Recovery** — If any pre-flight check fails, the pipeline stops immediately and reports. It never attempts to repair problems autonomously or continue past a known failure.

**[P2] Human Gates at Critical Points** — Version bumps, changelogs, tags, and GitHub releases each require explicit human approval before proceeding. Silent deployments are not possible.

**[P3] Conventional Commits as Ground Truth** — Version bump suggestions and changelog entries are derived from commit message prefixes (`feat:`, `fix:`, `BREAKING CHANGE:`). The history is the specification; the pipeline reads it, not the developer's memory.

**[P4] Parallel Where Possible** — Pre-flight checks (tests, docs, git state) run in parallel agents. Concurrency is exploited where safe; sequential logic is preserved at critical approval gates.

**[P5] Dry Run for Tag-Creating Paths** — All release paths that create tags or GitHub releases (Full Release, Plugin Release) support a full simulation via Dry Run that exercises complete pipeline logic without any mutations. Release Status provides a read-only preview for Quick Merge.

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install release-pipeline@l3digitalnet-plugins
```

## Usage

```
/release
```

Or trigger naturally: "ship it", "merge to main", "cut a release", "release v1.2.0"

The command auto-detects your repository state and presents a context-aware menu. The menu adapts: monorepos show an unreleased plugin count, dirty trees warn about uncommitted changes, and version suggestions are calculated from conventional commits (`feat` → minor, `fix` → patch, `BREAKING CHANGE` → major).

## Commands

| Command | Description |
|---------|-------------|
| `/release` | Open the interactive release menu |

## Skills

| Skill | Description |
|-------|-------------|
| `release` | Full release pipeline workflow — phases, version bumping, changelog, GitHub release |
| `release-detection` | Detects release intent in natural language and routes to `/release` |

## Release Options

| Option | Description |
|--------|-------------|
| Quick Merge | Commit and merge testing → main (no version bump) |
| Full Release | Semver release with pre-flight, changelog, tag, GitHub release |
| Plugin Release | Release a single plugin from a monorepo (scoped tag + changelog) |
| Release Status | Show unreleased commits, last tag, changelog drift |
| Dry Run | Simulate a full release without any changes |
| Changelog Preview | Generate and display a changelog entry |

## Full Release Workflow

| Phase | Action | Parallel? |
|-------|--------|-----------|
| 0. Detection | Auto-detect repo state, suggest version | Yes |
| 1. Pre-flight | Run tests, audit docs, check git state | Yes (3 agents) |
| 2. Preparation | Bump versions, generate changelog, show diff | Sequential |
| 3. Release | Commit, merge, tag, push, GitHub release | Sequential |
| 4. Verification | Confirm tag, release page, notes | Sequential |

If anything fails, the pipeline stops immediately and suggests rollback steps. No destructive auto-recovery.

## Supported Test Runners

Auto-detected from project files:

- **Python**: pytest (pyproject.toml, pytest.ini, setup.cfg)
- **Node.js**: npm test (package.json)
- **Rust**: cargo test (Cargo.toml)
- **Go**: go test (go.mod)
- **Make**: make test (Makefile)
- **Fallback**: reads CLAUDE.md for test commands

## Planned Features

- **GitLab support** — detect GitLab remotes and use the `glab` CLI for releases and MR management
- **PyPI / npm publish step** — optional post-release package publish with `twine` or `npm publish`
- **Rollback automation** — `/release rollback` option that reverses a tag, reverts the merge, and re-opens the PR
- **Multi-package monorepo** — release multiple packages in one pass with per-package changelogs and tags

## Known Issues

- **GitHub release requires `gh` CLI** — the Full Release and Plugin Release options create GitHub releases via `gh`; if `gh` is not authenticated, these steps will fail with a permission error
- **Changelog generation assumes conventional commits** — version bump suggestions and changelog entries rely on `feat:`, `fix:`, and `BREAKING CHANGE:` prefixes; non-conventional commit histories will produce a flat "Other changes" section
- **Dry Run does not simulate GitHub API calls** — the Dry Run option skips all git and file mutations but cannot simulate the GitHub release API; actual release creation may still fail after a clean dry run
