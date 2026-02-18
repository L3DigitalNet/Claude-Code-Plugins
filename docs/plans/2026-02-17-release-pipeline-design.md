# Release Pipeline Plugin — Design Document

**Date:** 2026-02-17
**Status:** Approved
**Plugin:** `plugins/release-pipeline/`

## Problem

Releasing software involves a repetitive sequence of checks, version bumps, changelog updates, tagging, and verification. Doing this manually is error-prone (stale versions, forgotten tags, wrong email on commits). An autonomous pipeline invocable from any repo eliminates these failure modes.

## Two Modes

### Quick Merge — `/release` (no args)

Commit all staged/unstaged changes, merge `testing` to `main`, push. No tagging, no changelog, no GitHub release.

**Steps:**
1. Pre-flight: clean tree check, confirm on `testing`, verify noreply email
2. Stage and commit all changes (generate commit message from diff)
3. Show diff summary, wait for "GO" approval
4. `git checkout main && git merge testing --no-ff && git push origin main`
5. `git checkout testing`
6. Report summary (commit count, files changed)

### Full Release — `/release v1.2.0`

Four-phase pipeline with parallel pre-flight agents, version bumping, changelog generation, GitHub release creation, and verification.

## Full Release Pipeline

### Phase 1 — Pre-flight (Parallel Subagents)

Three `Task` agents run simultaneously. Any failure stops the pipeline.

**Agent A: test-runner** (sonnet)
- Tools: Bash, Read, Glob, Grep
- Auto-detects test framework via `detect-test-runner.sh`:
  - `pyproject.toml` with `[tool.pytest]` -> pytest
  - `package.json` with `test` script -> npm test
  - `Makefile` with `test` target -> make test
  - `Cargo.toml` -> cargo test
  - Falls back to CLAUDE.md test command
- Runs full suite, captures pass/fail count, coverage if available
- Returns: pass/fail, test count, coverage %, failure details

**Agent B: docs-auditor** (sonnet)
- Tools: Read, Glob, Grep, WebFetch
- Checks:
  - README.md exists and references current version
  - CHANGELOG.md exists (warn if missing, don't fail)
  - Broken relative links in markdown files
  - Tone: flag corporate language ("synergy", "leverage", "stakeholders")
  - Version string consistency across docs
- Returns: pass/fail, list of issues

**Agent C: git-preflight** (haiku)
- Tools: Bash, Read, Grep
- Checks:
  - Working tree clean (`git status --porcelain` empty)
  - On `testing` branch (or appropriate dev branch)
  - `git user.email` is `*@users.noreply.github.com`
  - Remote `main` exists
  - Tag `vX.Y.Z` doesn't already exist
- Returns: pass/fail, list of issues

### Phase 2 — Preparation (Sequential)

1. **Version bump** via `bump-version.sh`:
   - Targets: `pyproject.toml`, `__init__.py`, `plugin.json`, `marketplace.json`
   - Also scans for `version.*=.*\d+\.\d+\.\d+` patterns
   - Shows exactly what changed

2. **Changelog generation** via `generate-changelog.sh`:
   - Finds last tag: `git describe --tags --abbrev=0`
   - Gets commits since: `git log {last-tag}..HEAD --oneline`
   - Categorizes by conventional commit prefix:
     - `feat:` -> Added
     - `fix:` -> Fixed
     - `refactor:`, `chore:`, `docs:` -> Changed
     - Non-prefixed -> Changed
   - Formats as Keep a Changelog entry with today's date
   - Prepends to CHANGELOG.md (creates if missing)

3. **Approval gate**:
   - Shows: files changed, version bump diff, changelog preview
   - Waits for user "GO"
   - Any other response aborts cleanly

### Phase 3 — Release (Sequential)

1. `git add -A && git commit -m "Release vX.Y.Z"`
2. `git checkout main && git merge testing --no-ff -m "Release vX.Y.Z"`
3. `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
4. `git push origin main --tags`
5. `git checkout testing`
6. `gh release create vX.Y.Z --title "vX.Y.Z" --notes-file -` (changelog entry as body)

### Phase 4 — Verification

Via `verify-release.sh`:
- Tag exists on remote: `git ls-remote --tags origin vX.Y.Z`
- GitHub release page is live: `gh release view vX.Y.Z`
- Release notes not empty
- Final summary with links

## Fail-Fast Behavior

| Failure Point | Action | Rollback Suggestion |
|---------------|--------|---------------------|
| Phase 1 agent fails | Stop immediately | Nothing to roll back (no changes made) |
| Phase 2 script fails | Stop immediately | `git checkout -- .` to discard version bumps |
| Phase 3 push fails | Stop immediately | `git tag -d vX.Y.Z && git reset HEAD~1` |
| Phase 4 check fails | Warn (don't stop) | Manual verification needed |

## Plugin Structure

```
plugins/release-pipeline/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── commands/
│   └── release.md               # /release command (orchestrator)
├── skills/
│   └── release-detection/
│       └── SKILL.md             # NLP trigger for release intent
├── agents/
│   ├── test-runner.md           # Phase 1A
│   ├── docs-auditor.md          # Phase 1B
│   └── git-preflight.md        # Phase 1C
├── scripts/
│   ├── detect-test-runner.sh    # Auto-detect test framework
│   ├── bump-version.sh          # Version string replacement
│   ├── generate-changelog.sh    # Commit -> changelog formatting
│   └── verify-release.sh       # Post-release verification
└── templates/
    └── changelog-entry.template # Keep a Changelog section template
```

## Component Context Cost

| Component | Loads into context? | When? |
|-----------|---------------------|-------|
| `release.md` command | Yes | On `/release` invocation |
| `SKILL.md` skill | Conditionally | When AI detects release intent |
| Agent definitions | No (parent context) | Loaded by spawned agent |
| Scripts | No | Run externally, stdout returns |
| Template | No | Read by script, not by AI |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Plugin home | Standalone `release-pipeline/` | Clean separation, independent versioning |
| Invocation | Skill + Command | Works via `/release` or natural language |
| Test runner | Auto-detect | Supports Python, Node, Rust, Make without config |
| Changelog | Keep a Changelog | Matches existing repo conventions |
| Quick merge | Same command, no version arg | Progressive complexity, one entry point |
| Phase 1 model | sonnet/sonnet/haiku | Haiku for mechanical checks, sonnet for judgment |
| Discussions/wiki | Skipped | Not used in target repos |
| Fail behavior | Stop + suggest rollback | Safe default, no destructive auto-recovery |
