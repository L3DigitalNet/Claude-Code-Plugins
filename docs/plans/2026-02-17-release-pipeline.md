# Release Pipeline Plugin — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone Claude Code plugin (`release-pipeline`) with two modes: quick merge (`/release`) and full release (`/release v1.2.0`) — usable in any repo.

**Architecture:** A `/release` command orchestrates the workflow. Phase 1 uses parallel `Task` subagents (defined as agents/). Helper shell scripts handle mechanical work (version bumping, changelog generation, verification) outside the context window. A companion skill auto-detects release intent from natural language.

**Tech Stack:** Bash scripts, Claude Code plugin YAML/Markdown, `gh` CLI, `git`

**Design Doc:** `docs/plans/2026-02-17-release-pipeline-design.md`

---

## Task 1: Scaffold Plugin Structure + Manifest

**Files:**
- Create: `plugins/release-pipeline/.claude-plugin/plugin.json`
- Create: directories `commands/`, `skills/release-detection/`, `agents/`, `scripts/`, `templates/`

**Step 1: Create directory structure**

```bash
mkdir -p plugins/release-pipeline/.claude-plugin
mkdir -p plugins/release-pipeline/{commands,skills/release-detection,agents,scripts,templates}
```

**Step 2: Write plugin manifest**

Create `plugins/release-pipeline/.claude-plugin/plugin.json`:

```json
{
  "name": "release-pipeline",
  "description": "Autonomous release pipeline — quick merge or full semver release with parallel pre-flight checks, changelog generation, and GitHub release creation.",
  "version": "1.0.0",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "keywords": [
    "release",
    "versioning",
    "changelog",
    "ci",
    "deployment"
  ]
}
```

**Step 3: Validate manifest**

Run: `jq . plugins/release-pipeline/.claude-plugin/plugin.json`
Expected: Pretty-printed JSON, exit 0

**Step 4: Commit**

```bash
git add plugins/release-pipeline/
git commit -m "feat: scaffold release-pipeline plugin structure"
```

---

## Task 2: Script — detect-test-runner.sh

**Files:**
- Create: `plugins/release-pipeline/scripts/detect-test-runner.sh`

**Step 1: Write the script**

Create `plugins/release-pipeline/scripts/detect-test-runner.sh`:

```bash
#!/usr/bin/env bash
# Detect the test runner for a project by examining project files.
# Usage: detect-test-runner.sh [repo-path]
# Outputs: the test command to run (stdout)
# Exit: 0 = found, 1 = not detected
set -euo pipefail

REPO_PATH="${1:-.}"
cd "$REPO_PATH"

# Python: pytest
if [[ -f pyproject.toml ]] && grep -q '\[tool\.pytest' pyproject.toml 2>/dev/null; then
    echo "pytest --tb=short -q"
    exit 0
fi
if [[ -f pytest.ini ]]; then
    echo "pytest --tb=short -q"
    exit 0
fi
if [[ -f setup.cfg ]] && grep -q '\[tool:pytest\]' setup.cfg 2>/dev/null; then
    echo "pytest --tb=short -q"
    exit 0
fi

# Node.js: npm test
if [[ -f package.json ]]; then
    if python3 -c "
import json, sys
d = json.load(open('package.json'))
sys.exit(0 if 'test' in d.get('scripts', {}) else 1)
" 2>/dev/null; then
        echo "npm test"
        exit 0
    fi
fi

# Rust: cargo test
if [[ -f Cargo.toml ]]; then
    echo "cargo test"
    exit 0
fi

# Make: make test
if [[ -f Makefile ]] && grep -q '^test:' Makefile 2>/dev/null; then
    echo "make test"
    exit 0
fi

# Go: go test
if [[ -f go.mod ]]; then
    echo "go test ./..."
    exit 0
fi

# Fallback: check CLAUDE.md for test command
if [[ -f CLAUDE.md ]]; then
    cmd=$(grep -oP '(?:pytest|npm test|cargo test|make test|go test|bun test)[^\n`]*' CLAUDE.md | head -1)
    if [[ -n "$cmd" ]]; then
        echo "$cmd"
        exit 0
    fi
fi

echo "ERROR: Could not auto-detect test runner. Add a test command to CLAUDE.md." >&2
exit 1
```

**Step 2: Validate syntax**

Run: `bash -n plugins/release-pipeline/scripts/detect-test-runner.sh`
Expected: No output, exit 0

**Step 3: Make executable**

Run: `chmod +x plugins/release-pipeline/scripts/detect-test-runner.sh`

**Step 4: Smoke test against a known repo**

Run: `plugins/release-pipeline/scripts/detect-test-runner.sh /home/chris/projects/HA-Light-Controller`
Expected: A pytest command (since HA-Light-Controller is a Python project)

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/detect-test-runner.sh
git commit -m "feat: add test runner auto-detection script"
```

---

## Task 3: Script — bump-version.sh

**Files:**
- Create: `plugins/release-pipeline/scripts/bump-version.sh`

**Step 1: Write the script**

Create `plugins/release-pipeline/scripts/bump-version.sh`:

```bash
#!/usr/bin/env bash
# Find and replace version strings across common project files.
# Usage: bump-version.sh <repo-path> <new-version>
# Outputs: list of files changed (stdout)
# Exit: 0 = at least one file updated, 1 = no version strings found
set -euo pipefail

REPO_PATH="${1:?Usage: bump-version.sh <repo-path> <new-version>}"
NEW_VERSION="${2:?Usage: bump-version.sh <repo-path> <new-version>}"
cd "$REPO_PATH"

# Strip leading 'v' if present
NEW_VERSION="${NEW_VERSION#v}"
CHANGED=0

bump_file() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"

    if [[ -f "$file" ]]; then
        if grep -qE "$pattern" "$file"; then
            sed -i -E "s|$pattern|$replacement|g" "$file"
            echo "  Updated: $file"
            ((CHANGED++))
        fi
    fi
}

echo "Bumping version to $NEW_VERSION"
echo "================================"

# pyproject.toml
bump_file "pyproject.toml" \
    'version\s*=\s*"[0-9]+\.[0-9]+\.[0-9]+"' \
    "version = \"$NEW_VERSION\""

# package.json
bump_file "package.json" \
    '"version"\s*:\s*"[0-9]+\.[0-9]+\.[0-9]+"' \
    "\"version\": \"$NEW_VERSION\""

# Cargo.toml (only the first occurrence — the [package] version)
if [[ -f "Cargo.toml" ]]; then
    if grep -qE 'version\s*=\s*"[0-9]+\.[0-9]+\.[0-9]+"' "Cargo.toml"; then
        sed -i -E "0,/version\s*=\s*\"[0-9]+\.[0-9]+\.[0-9]+\"/s|version\s*=\s*\"[0-9]+\.[0-9]+\.[0-9]+\"|version = \"$NEW_VERSION\"|" "Cargo.toml"
        echo "  Updated: Cargo.toml"
        ((CHANGED++))
    fi
fi

# Claude Code plugin manifest
bump_file ".claude-plugin/plugin.json" \
    '"version"\s*:\s*"[0-9]+\.[0-9]+\.[0-9]+"' \
    "\"version\": \"$NEW_VERSION\""

# __init__.py files (recursive, skip .venv and .git)
while IFS= read -r -d '' f; do
    bump_file "$f" \
        '__version__\s*=\s*"[0-9]+\.[0-9]+\.[0-9]+"' \
        "__version__ = \"$NEW_VERSION\""
done < <(find . -name "__init__.py" -not -path "./.git/*" -not -path "./.venv/*" -not -path "./node_modules/*" -print0 2>/dev/null)

echo "================================"

if [[ $CHANGED -eq 0 ]]; then
    echo "WARNING: No version strings found to update" >&2
    exit 1
fi

echo "$CHANGED file(s) updated. Review changes with: git diff"
exit 0
```

**Step 2: Validate syntax**

Run: `bash -n plugins/release-pipeline/scripts/bump-version.sh`
Expected: No output, exit 0

**Step 3: Make executable**

Run: `chmod +x plugins/release-pipeline/scripts/bump-version.sh`

**Step 4: Commit**

```bash
git add plugins/release-pipeline/scripts/bump-version.sh
git commit -m "feat: add version bump script"
```

---

## Task 4: Script — generate-changelog.sh + Template

**Files:**
- Create: `plugins/release-pipeline/scripts/generate-changelog.sh`
- Create: `plugins/release-pipeline/templates/changelog-entry.template`

**Step 1: Write the changelog template**

Create `plugins/release-pipeline/templates/changelog-entry.template`:

```
## [${VERSION}] - ${DATE}

### Added
${ADDED}

### Changed
${CHANGED}

### Fixed
${FIXED}
```

**Step 2: Write the changelog script**

Create `plugins/release-pipeline/scripts/generate-changelog.sh`:

```bash
#!/usr/bin/env bash
# Generate a Keep a Changelog entry from git commits since last tag.
# Usage: generate-changelog.sh <repo-path> <new-version>
# Outputs: the formatted changelog entry (stdout)
# Side effect: prepends entry to CHANGELOG.md
# Exit: 0 = success, 1 = error
set -euo pipefail

REPO_PATH="${1:?Usage: generate-changelog.sh <repo-path> <new-version>}"
NEW_VERSION="${2:?Usage: generate-changelog.sh <repo-path> <new-version>}"
cd "$REPO_PATH"

NEW_VERSION="${NEW_VERSION#v}"
TODAY=$(date +%Y-%m-%d)

# Find last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "$LAST_TAG" ]]; then
    echo "No previous tag found. Using all commits." >&2
    COMMIT_RANGE="HEAD"
else
    COMMIT_RANGE="${LAST_TAG}..HEAD"
fi

# Categorize commits
ADDED=""
CHANGED=""
FIXED=""

while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Strip short hash prefix
    msg="${line#* }"

    if [[ "$msg" =~ ^feat(\(.+\))?:\ (.+) ]]; then
        ADDED+="- ${BASH_REMATCH[2]}"$'\n'
    elif [[ "$msg" =~ ^fix(\(.+\))?:\ (.+) ]]; then
        FIXED+="- ${BASH_REMATCH[2]}"$'\n'
    elif [[ "$msg" =~ ^(refactor|chore|docs|style|perf|build|ci|test)(\(.+\))?:\ (.+) ]]; then
        CHANGED+="- ${BASH_REMATCH[3]}"$'\n'
    else
        CHANGED+="- ${msg}"$'\n'
    fi
done < <(git log "$COMMIT_RANGE" --oneline --no-merges 2>/dev/null)

# Build the entry
ENTRY="## [$NEW_VERSION] - $TODAY"$'\n'

if [[ -n "$ADDED" ]]; then
    ENTRY+=$'\n'"### Added"$'\n'
    ENTRY+="$ADDED"
fi

if [[ -n "$CHANGED" ]]; then
    ENTRY+=$'\n'"### Changed"$'\n'
    ENTRY+="$CHANGED"
fi

if [[ -n "$FIXED" ]]; then
    ENTRY+=$'\n'"### Fixed"$'\n'
    ENTRY+="$FIXED"
fi

# Output the entry for the command to display
echo "$ENTRY"

# Prepend to CHANGELOG.md
CHANGELOG="CHANGELOG.md"
if [[ -f "$CHANGELOG" ]]; then
    TEMP=$(mktemp)
    if grep -qn '^## ' "$CHANGELOG"; then
        FIRST_SECTION=$(grep -n '^## ' "$CHANGELOG" | head -1 | cut -d: -f1)
        head -n $((FIRST_SECTION - 1)) "$CHANGELOG" > "$TEMP"
        echo "$ENTRY" >> "$TEMP"
        tail -n +$FIRST_SECTION "$CHANGELOG" >> "$TEMP"
    else
        cat "$CHANGELOG" > "$TEMP"
        printf '\n%s' "$ENTRY" >> "$TEMP"
    fi
    mv "$TEMP" "$CHANGELOG"
else
    cat > "$CHANGELOG" <<HEADER
# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

$ENTRY
HEADER
fi

echo "---" >&2
echo "CHANGELOG.md updated." >&2
exit 0
```

**Step 3: Validate syntax**

Run: `bash -n plugins/release-pipeline/scripts/generate-changelog.sh`
Expected: No output, exit 0

**Step 4: Make executable**

Run: `chmod +x plugins/release-pipeline/scripts/generate-changelog.sh`

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/generate-changelog.sh plugins/release-pipeline/templates/changelog-entry.template
git commit -m "feat: add changelog generation script and template"
```

---

## Task 5: Script — verify-release.sh

**Files:**
- Create: `plugins/release-pipeline/scripts/verify-release.sh`

**Step 1: Write the script**

Create `plugins/release-pipeline/scripts/verify-release.sh`:

```bash
#!/usr/bin/env bash
# Verify a release completed successfully.
# Usage: verify-release.sh <repo-path> <version>
# Outputs: verification report (stdout)
# Exit: 0 = all checks pass, 1 = any check failed
set -euo pipefail

REPO_PATH="${1:?Usage: verify-release.sh <repo-path> <version>}"
VERSION="${2:?Usage: verify-release.sh <repo-path> <version>}"
cd "$REPO_PATH"

VERSION="${VERSION#v}"
TAG="v${VERSION}"
PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [[ "$result" == "pass" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc"
        ((FAIL++))
    fi
}

echo "Release Verification: $TAG"
echo "=========================="

# Check tag on remote
if git ls-remote --tags origin "$TAG" 2>/dev/null | grep -q "$TAG"; then
    check "Tag exists on remote" "pass"
else
    check "Tag exists on remote" "fail"
fi

# Check GitHub release exists
if gh release view "$TAG" --json tagName -q '.tagName' 2>/dev/null | grep -q "$VERSION"; then
    check "GitHub release exists" "pass"
else
    check "GitHub release exists" "fail"
fi

# Check release notes not empty
NOTES=$(gh release view "$TAG" --json body -q '.body' 2>/dev/null || echo "")
if [[ -n "$NOTES" && "$NOTES" != "null" ]]; then
    check "Release notes present" "pass"
else
    check "Release notes present" "fail"
fi

# Check we're back on development branch
CURRENT=$(git branch --show-current)
if [[ "$CURRENT" != "main" ]]; then
    check "Returned to dev branch (on: $CURRENT)" "pass"
else
    check "Still on main — should have returned to dev branch" "fail"
fi

echo "=========================="
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

exit 0
```

**Step 2: Validate syntax**

Run: `bash -n plugins/release-pipeline/scripts/verify-release.sh`
Expected: No output, exit 0

**Step 3: Make executable**

Run: `chmod +x plugins/release-pipeline/scripts/verify-release.sh`

**Step 4: Commit**

```bash
git add plugins/release-pipeline/scripts/verify-release.sh
git commit -m "feat: add release verification script"
```

---

## Task 6: Agent Definitions

**Files:**
- Create: `plugins/release-pipeline/agents/test-runner.md`
- Create: `plugins/release-pipeline/agents/docs-auditor.md`
- Create: `plugins/release-pipeline/agents/git-preflight.md`

**Step 1: Write test-runner agent**

Create `plugins/release-pipeline/agents/test-runner.md`:

```markdown
---
name: test-runner
description: Run full test suite and report pass/fail count with coverage. Used by release pipeline Phase 1.
tools: Bash, Read, Glob, Grep
model: sonnet
---

You are the test runner agent for a release pipeline pre-flight check.

## Your Task

1. Detect the test framework by running: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-test-runner.sh .`
2. If detection fails, check CLAUDE.md for test instructions
3. Run the full test suite using the detected command
4. Parse the output for: total tests, passed, failed, skipped
5. If a coverage tool is available (pytest-cov, nyc, coverage), report the coverage percentage

## Output Format

Report a structured summary:

```
TEST RESULTS
============
Status: PASS | FAIL
Tests: X passed, Y failed, Z skipped (total: N)
Coverage: XX% (or "not configured")
Details: [any failure messages, truncated to 20 lines max]
```

## Rules

- Run the tests ONCE. Do not retry failures.
- If tests fail, still report the full summary — do not stop at the first failure.
- If no test runner is detected and CLAUDE.md has no test command, report FAIL with "No test runner found".
- Do not modify any files. You are read-only except for running the test command.
```

**Step 2: Write docs-auditor agent**

Create `plugins/release-pipeline/agents/docs-auditor.md`:

```markdown
---
name: docs-auditor
description: Audit documentation for stale versions, broken links, and tone. Used by release pipeline Phase 1.
tools: Read, Glob, Grep
model: sonnet
---

You are the documentation auditor for a release pipeline pre-flight check.

## Your Task

Audit all documentation files in the repository for release readiness.

### 1. Version Consistency

- Find the current version from pyproject.toml, package.json, Cargo.toml, or plugin.json
- Search all .md files for version references
- Flag any that reference an older version (stale)

### 2. Broken Links

- Scan all .md files for relative links: `[text](path)`
- Check that each linked file actually exists on disk
- Do NOT check external URLs (too slow for pre-flight)

### 3. Tone Check

- Scan for overtly corporate language in .md files
- Flag words: "synergy", "leverage" (as verb), "stakeholders", "paradigm", "actionable", "circle back", "bandwidth" (non-technical usage)
- The target tone is professional but approachable — NOT corporate

### 4. File Existence

- Warn (don't fail) if README.md is missing
- Warn (don't fail) if CHANGELOG.md is missing

## Output Format

```
DOCS AUDIT
==========
Status: PASS | WARN | FAIL
Version refs: X checked, Y stale
Broken links: X found
Tone flags: X found
Missing files: [list or "none"]
Details: [specific issues, one per line]
```

## Rules

- PASS = no stale versions and no broken links (tone flags and missing files are warnings only)
- WARN = only warnings (tone flags or missing files, but no stale versions or broken links)
- FAIL = stale version references or broken links found
- Do not modify any files.
```

**Step 3: Write git-preflight agent**

Create `plugins/release-pipeline/agents/git-preflight.md`:

```markdown
---
name: git-preflight
description: Verify clean git state, noreply email, and tag availability. Used by release pipeline Phase 1.
tools: Bash, Read, Grep
model: haiku
---

You are the git pre-flight checker for a release pipeline.

## Your Task

Run these checks and report results:

1. **Clean working tree**: `git status --porcelain` must be empty
2. **On dev branch**: Current branch must NOT be `main` or `master`
3. **Noreply email**: `git config user.email` must match `*@users.noreply.github.com`
4. **Remote exists**: `git remote get-url origin` must succeed
5. **Tag available**: If a target version was provided as the first argument, check that `git tag -l "vX.Y.Z"` returns empty (tag doesn't exist yet)

## Output Format

```
GIT PRE-FLIGHT
==============
Status: PASS | FAIL
Clean tree: YES | NO (X files modified)
Branch: <branch-name> (OK | FAIL — on protected branch)
Email: <email> (OK | FAIL — not noreply)
Remote: <url> (OK | FAIL)
Tag vX.Y.Z: available | ALREADY EXISTS
```

## Rules

- Any single FAIL = overall FAIL
- Do not modify any files or git state.
- Run checks in order, report all results even if one fails early.
```

**Step 4: Commit**

```bash
git add plugins/release-pipeline/agents/
git commit -m "feat: add Phase 1 pre-flight agent definitions"
```

---

## Task 7: Release Command

This is the main orchestrator. It parses arguments, dispatches phases, and gates on user approval.

**Files:**
- Create: `plugins/release-pipeline/commands/release.md`

**Step 1: Write the release command**

Create `plugins/release-pipeline/commands/release.md`:

````markdown
---
name: release
description: "Release pipeline — no args for quick merge (testing->main), or provide version (e.g., /release v1.2.0) for full release with pre-flight checks, changelog, and GitHub release."
---

# Release Pipeline

You are now executing the release pipeline. Parse the arguments to determine the mode:

- **No arguments** or **no version string** → Quick Merge mode
- **Version argument** (e.g., `v1.2.0`, `1.2.0`) → Full Release mode

Extract the version from the arguments. A version matches the pattern `v?[0-9]+\.[0-9]+\.[0-9]+`.

## CRITICAL RULES

1. **Use TodoWrite** to track every step's status throughout
2. **If ANY step fails, STOP IMMEDIATELY** — report what failed, suggest rollback steps, do NOT continue
3. **Never force-push** — always use regular `git push`
4. **Always use noreply email** — verify before any push operation
5. **Wait for explicit user "GO" approval** before executing release operations

---

## Mode 1: Quick Merge (no version argument)

Use this when no version was provided. This commits all changes and merges testing to main.

### Steps

1. **Pre-flight checks** (run in sequence, these are fast):
   - Run `git status --porcelain` — if NOT empty, stage all and prepare a commit message from the diff
   - Verify current branch is `testing` (or a feature branch, NOT `main`)
   - Verify `git config user.email` contains `noreply`

2. **Stage and commit** (if there are changes):
   - Stage all changes: `git add -A`
   - Generate a concise commit message from `git diff --cached --stat`
   - Show the user the diff summary and proposed commit message
   - **Wait for "GO" approval**

3. **Merge to main**:
   ```bash
   git checkout main
   git pull origin main
   git merge testing --no-ff -m "Merge testing into main"
   git push origin main
   git checkout testing
   ```

4. **Report**:
   - Commits merged (count)
   - Files changed
   - Current branch confirmed as `testing`

---

## Mode 2: Full Release (version argument provided)

Use this when a version like `v1.2.0` was provided.

### Phase 1 — Pre-flight (Parallel)

Launch THREE Task agents simultaneously using the Task tool. All three MUST pass before proceeding.

**IMPORTANT:** Launch all three in a SINGLE message with three Task tool calls.

**Agent A — Test Runner:**
```
Task tool call:
  subagent_type: "general-purpose"
  description: "Run test suite"
  prompt: |
    You are a test runner agent for a release pre-flight check.
    Read the agent instructions at: ${CLAUDE_PLUGIN_ROOT}/agents/test-runner.md
    Follow those instructions exactly for the repo at: <current working directory>
    Run the test suite and report results in the specified format.
```

**Agent B — Docs Auditor:**
```
Task tool call:
  subagent_type: "general-purpose"
  description: "Audit documentation"
  prompt: |
    You are a documentation auditor for a release pre-flight check.
    Read the agent instructions at: ${CLAUDE_PLUGIN_ROOT}/agents/docs-auditor.md
    Follow those instructions exactly for the repo at: <current working directory>
    The target release version is: <version>
```

**Agent C — Git Pre-flight:**
```
Task tool call:
  subagent_type: "general-purpose"
  description: "Git pre-flight check"
  prompt: |
    You are a git pre-flight checker for a release.
    Read the agent instructions at: ${CLAUDE_PLUGIN_ROOT}/agents/git-preflight.md
    Follow those instructions exactly for the repo at: <current working directory>
    The target version tag is: v<version>
```

**After all three return:**
- Display each agent's summary
- If ANY agent reported FAIL → STOP. Report which failed and why. Suggest fixes. Do NOT proceed.
- If all PASS (WARN is acceptable) → proceed to Phase 2

### Phase 2 — Preparation (Sequential)

**Step 1: Bump versions**

Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version>`

Display the script's output showing which files were updated.

If the script exits non-zero, STOP and report the error.

**Step 2: Generate changelog**

Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version>`

Display the generated changelog entry.

If the script exits non-zero (and it's not just "no previous tag"), STOP and report.

**Step 3: Show diff summary + approval gate**

Show the user:
- All files modified (from `git diff --stat`)
- The version bump changes (from `git diff` on versioned files)
- The changelog entry preview
- A clear message: **"Review the changes above. Reply GO to proceed with the release, or anything else to abort."**

**WAIT for user response.** Do NOT proceed until you receive explicit approval.

If the user says anything other than clear approval (GO, go, yes, proceed, ship it, do it), ABORT cleanly:
- Run `git checkout -- .` to discard changes
- Report: "Release aborted. All changes discarded."

### Phase 3 — Release (Sequential)

Execute these git operations in order. If any fails, stop and report.

```bash
# 1. Commit all changes
git add -A
git commit -m "Release v<version>"

# 2. Merge to main
git checkout main
git pull origin main
git merge testing --no-ff -m "Release v<version>"

# 3. Tag
git tag -a "v<version>" -m "Release v<version>"

# 4. Push (tags included)
git push origin main --tags

# 5. Return to testing
git checkout testing

# 6. Create GitHub release with changelog as body
```

For the GitHub release, use `gh release create`:
```bash
gh release create "v<version>" --title "v<version>" --notes "<changelog entry text>"
```

Use the changelog entry generated in Phase 2 as the release notes.

### Phase 4 — Verification

Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version>`

Display the verification report.

If verification fails, WARN the user but do NOT attempt rollback — the release artifacts already exist. Report what failed and suggest manual verification steps.

### Final Summary

Display a completion report:

```
RELEASE COMPLETE: v<version>
==============================
Tests: <pass count> passed, <coverage>% coverage
Docs: <status>
Git: tag v<version> pushed to origin/main
GitHub: release page live
Changelog: updated

Links:
- Release: <gh release URL from `gh release view v<version> --json url -q '.url'`>
- Tag: <repo URL>/releases/tag/v<version>
```

---

## Rollback Suggestions

If the pipeline fails, suggest these rollback steps based on where it failed:

**Phase 1 failed:** Nothing to roll back. Fix the issues and retry.

**Phase 2 failed (version bump/changelog):**
```bash
git checkout -- .   # Discard all uncommitted changes
```

**Phase 3 failed (after commit, before push):**
```bash
git tag -d v<version>              # Delete local tag
git checkout testing               # Return to testing
git reset --hard HEAD~1            # Undo the merge commit on main (if on main)
```

**Phase 3 failed (after push):**
```
Manual intervention needed:
- Delete the tag: git push origin --delete v<version>
- Consider: the merge commit is already on main
- Contact repo maintainers if needed
```

**Phase 4 failed:** Release exists but verification couldn't confirm. Check manually:
```bash
gh release view v<version>
git ls-remote --tags origin v<version>
```
````

**Step 2: Commit**

```bash
git add plugins/release-pipeline/commands/release.md
git commit -m "feat: add release command — main orchestrator"
```

---

## Task 8: Release Detection Skill

**Files:**
- Create: `plugins/release-pipeline/skills/release-detection/SKILL.md`

**Step 1: Write the skill**

Create `plugins/release-pipeline/skills/release-detection/SKILL.md`:

```markdown
---
name: release-detection
description: >
  Detect release intent in natural language and route to the /release command.
  Triggers on: "Release vX.Y.Z", "cut a release", "ship it", "merge to main",
  "deploy to production", "push to main", "release for <repo>".
---

# Release Detection

You detected release intent in the user's message. Route to the appropriate release mode.

## Parse the Request

1. **Look for a version number**: pattern `v?[0-9]+\.[0-9]+\.[0-9]+`
   - Found → Full Release mode
   - Not found → Quick Merge mode

2. **Look for a repo name**: if the user mentions a specific repo (e.g., "for HA-Light-Controller"), note it — you may need to `cd` to that repo first.

## Execute

Follow the exact same workflow as the `/release` command defined in `${CLAUDE_PLUGIN_ROOT}/commands/release.md`.

Read that file and follow its instructions with the parsed version (if any) and repo context.
```

**Step 2: Commit**

```bash
git add plugins/release-pipeline/skills/
git commit -m "feat: add release detection skill for natural language triggering"
```

---

## Task 9: README.md

**Files:**
- Create: `plugins/release-pipeline/README.md`

**Step 1: Write README**

Create `plugins/release-pipeline/README.md`:

```markdown
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
4. Merges testing → main, pushes, returns to testing

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
```

**Step 2: Commit**

```bash
git add plugins/release-pipeline/README.md
git commit -m "docs: add README for release-pipeline plugin"
```

---

## Task 10: Marketplace Entry + Validation

**Files:**
- Modify: `.claude-plugin/marketplace.json` — add release-pipeline entry to the plugins array

**Step 1: Add marketplace entry**

Add this object to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "release-pipeline",
  "description": "Autonomous release pipeline — quick merge or full semver release with parallel pre-flight checks, changelog generation, and GitHub release creation.",
  "version": "1.0.0",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "license": "MIT",
  "keywords": ["release", "versioning", "changelog", "deployment"],
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/release-pipeline",
  "source": "./plugins/release-pipeline"
}
```

**Step 2: Validate marketplace JSON**

Run: `jq . .claude-plugin/marketplace.json`
Expected: Valid JSON, exit 0

Run: `jq -e '.plugins[] | select(.name == "release-pipeline") | .name and .version and .author and .source' .claude-plugin/marketplace.json`
Expected: `true`

**Step 3: Validate plugin manifest**

Run: `jq . plugins/release-pipeline/.claude-plugin/plugin.json`
Expected: Valid JSON, exit 0

**Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: add release-pipeline to marketplace catalog"
```

---

## Task 11: Integration Smoke Test

**Step 1: Verify all scripts pass syntax check**

```bash
bash -n plugins/release-pipeline/scripts/detect-test-runner.sh
bash -n plugins/release-pipeline/scripts/bump-version.sh
bash -n plugins/release-pipeline/scripts/generate-changelog.sh
bash -n plugins/release-pipeline/scripts/verify-release.sh
```

Expected: All exit 0 with no output.

**Step 2: Verify plugin structure is complete**

```bash
ls -la plugins/release-pipeline/.claude-plugin/plugin.json
ls -la plugins/release-pipeline/commands/release.md
ls -la plugins/release-pipeline/skills/release-detection/SKILL.md
ls -la plugins/release-pipeline/agents/test-runner.md
ls -la plugins/release-pipeline/agents/docs-auditor.md
ls -la plugins/release-pipeline/agents/git-preflight.md
ls -la plugins/release-pipeline/scripts/detect-test-runner.sh
ls -la plugins/release-pipeline/scripts/bump-version.sh
ls -la plugins/release-pipeline/scripts/generate-changelog.sh
ls -la plugins/release-pipeline/scripts/verify-release.sh
ls -la plugins/release-pipeline/templates/changelog-entry.template
ls -la plugins/release-pipeline/README.md
```

Expected: All files exist.

**Step 3: Test detect-test-runner against a real repo**

```bash
plugins/release-pipeline/scripts/detect-test-runner.sh /home/chris/projects/HA-Light-Controller
```

Expected: Outputs a pytest command.

**Step 4: Verify version consistency**

```bash
PLUGIN_VER=$(jq -r '.version' plugins/release-pipeline/.claude-plugin/plugin.json)
MARKET_VER=$(jq -r '.plugins[] | select(.name == "release-pipeline") | .version' .claude-plugin/marketplace.json)
echo "Plugin: $PLUGIN_VER | Marketplace: $MARKET_VER"
[[ "$PLUGIN_VER" == "$MARKET_VER" ]] && echo "MATCH" || echo "MISMATCH"
```

Expected: `Plugin: 1.0.0 | Marketplace: 1.0.0` and `MATCH`
