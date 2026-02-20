# Release Pipeline Resilience Layer — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add tag reconciliation, exponential retry with jitter, pre-flight waiver config, and batch release mode (Mode 7) to the release-pipeline plugin, bringing it to v1.6.0.

**Architecture:** Three new deterministic bash scripts handle the computational layer (`reconcile-tags.sh`, `api-retry.sh`, `check-waivers.sh`); existing AI prompt templates are updated to call these scripts; a new `mode-7-batch-release.md` template orchestrates sequential plugin releases with quarantine-and-continue semantics. No TypeScript build step — this plugin is pure bash + markdown.

**Tech Stack:** Bash 5+, Markdown (AI prompt templates), `gh` CLI, `git`, `python3` (json processing already used in the project).

---

## Task 1: `scripts/reconcile-tags.sh` (new)

Compares local vs remote tag state and outputs a status string. Called by Phase 3 of mode-2 and mode-3 before `git tag -a`.

**Files:**
- Create: `plugins/release-pipeline/scripts/reconcile-tags.sh`
- Create: `plugins/release-pipeline/tests/test-reconcile-tags.sh`

**Step 1: Create the test script first (TDD)**

```bash
#!/usr/bin/env bash
# tests/test-reconcile-tags.sh — Unit tests for reconcile-tags.sh
# Mocks git by overriding it as a function in each test's subshell.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/reconcile-tags.sh"
PASS=0; FAIL=0

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

# ---- Test 1: MISSING — tag absent locally and remotely ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo ""; else echo ""; fi
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "MISSING" "MISSING when tag absent everywhere"

# ---- Test 2: LOCAL_ONLY — tag only local ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo "v1.0.0"; else echo ""; fi
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "LOCAL_ONLY" "LOCAL_ONLY when tag only local"

# ---- Test 3: BOTH — tag on local and remote ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo "v1.0.0"
    elif [[ "$*" == *"ls-remote"* ]]; then echo "abc123 refs/tags/v1.0.0"; fi
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "BOTH" "BOTH when tag on local and remote"

# ---- Test 4: REMOTE_ONLY — fetches and returns REMOTE_ONLY ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo ""
    elif [[ "$*" == *"ls-remote"* ]]; then echo "abc123 refs/tags/v1.0.0"
    elif [[ "$*" == *"fetch"* ]]; then echo ""; fi  # fetch succeeds
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "REMOTE_ONLY" "REMOTE_ONLY triggers auto-fetch"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

**Step 2: Run tests to confirm they fail (script doesn't exist yet)**

```bash
bash plugins/release-pipeline/tests/test-reconcile-tags.sh
```
Expected: error "No such file or directory" for the script path.

**Step 3: Create `reconcile-tags.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# reconcile-tags.sh — Compare local vs remote tag state before a release push.
#
# Usage: reconcile-tags.sh <repo-path> <tag>
# Output (stdout): MISSING | LOCAL_ONLY | BOTH | REMOTE_ONLY
#   MISSING    — tag absent everywhere: create and push normally
#   LOCAL_ONLY — tag local only: push will create it; no git tag -a needed
#   BOTH       — tag on local and remote: skip git tag -a, verify GitHub release
#   REMOTE_ONLY— tag remote only: auto-fetched to local; treat as BOTH
# Exit: 0 = resolved state (proceed), 1 = unrecoverable conflict

if [[ $# -lt 2 ]]; then
  echo "Usage: reconcile-tags.sh <repo-path> <tag>" >&2
  exit 1
fi

REPO="$1"
TAG="$2"

if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

local_exists=false
remote_exists=false

# Check local tags
if git -C "$REPO" tag -l "$TAG" | grep -q "^${TAG}$" 2>/dev/null; then
  local_exists=true
fi

# Check remote tags (ls-remote outputs "SHA refs/tags/TAG" when found)
if git -C "$REPO" ls-remote --tags origin "refs/tags/${TAG}" 2>/dev/null \
    | grep -q "refs/tags/${TAG}$"; then
  remote_exists=true
fi

if [[ "$local_exists" == false && "$remote_exists" == false ]]; then
  echo "MISSING"
  exit 0
fi

if [[ "$local_exists" == true && "$remote_exists" == false ]]; then
  echo "LOCAL_ONLY"
  exit 0
fi

if [[ "$local_exists" == true && "$remote_exists" == true ]]; then
  echo "BOTH"
  exit 0
fi

# REMOTE_ONLY: tag exists on remote but not local — auto-fetch to sync
if git -C "$REPO" fetch origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null; then
  echo "REMOTE_ONLY"
  echo "Auto-fetched remote tag ${TAG} to local." >&2
  exit 0
else
  echo "REMOTE_ONLY"
  echo "Warning: could not fetch remote tag ${TAG} — push may fail." >&2
  exit 1
fi
```

**Step 4: Make executable and run tests**

```bash
chmod +x plugins/release-pipeline/scripts/reconcile-tags.sh
bash plugins/release-pipeline/tests/test-reconcile-tags.sh
```
Expected: `4 passed, 0 failed`

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/reconcile-tags.sh \
        plugins/release-pipeline/tests/test-reconcile-tags.sh
git commit -m "feat(release-pipeline): add reconcile-tags.sh for local/remote tag reconciliation"
```

---

## Task 2: `scripts/api-retry.sh` (new)

Exponential backoff + jitter wrapper for `gh` CLI calls. Treats "already exists" as success (idempotent re-runs).

**Files:**
- Create: `plugins/release-pipeline/scripts/api-retry.sh`
- Create: `plugins/release-pipeline/tests/test-api-retry.sh`

**Step 1: Create the test script**

```bash
#!/usr/bin/env bash
# tests/test-api-retry.sh — Unit tests for api-retry.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/api-retry.sh"
PASS=0; FAIL=0

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

# ---- Test 1: succeeds on first attempt ----
out=$(bash "$SCRIPT" 3 100 -- echo "ok" 2>/dev/null)
assert_eq "$out" "ok" "passes through output on success"

# ---- Test 2: fails all attempts → exit 1 ----
bash "$SCRIPT" 3 100 -- false 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "exits 1 when all attempts exhausted"

# ---- Test 3: succeeds on second attempt ----
COUNT_FILE=$(mktemp)
echo "0" > "$COUNT_FILE"
CMD=$(mktemp)
cat > "$CMD" <<CMDEOF
#!/usr/bin/env bash
count=\$(cat "$COUNT_FILE")
count=\$((count + 1))
echo \$count > "$COUNT_FILE"
[[ \$count -ge 2 ]]  # exits 0 on attempt 2+
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 3 100 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "0" "retries and succeeds on second attempt"
rm -f "$COUNT_FILE" "$CMD"

# ---- Test 4: 'already exists' in stderr → treated as success ----
CMD=$(mktemp)
cat > "$CMD" <<'CMDEOF'
#!/usr/bin/env bash
echo "already exists" >&2
exit 1
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 3 100 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "0" "already-exists in stderr treated as success"
rm -f "$CMD"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

**Step 2: Run tests to confirm they fail**

```bash
bash plugins/release-pipeline/tests/test-api-retry.sh
```
Expected: error "No such file or directory"

**Step 3: Create `api-retry.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# api-retry.sh — Exponential backoff + jitter retry wrapper for gh CLI calls.
#
# Usage: api-retry.sh <max_attempts> <base_delay_ms> -- <command...>
# Exit:  0 = command succeeded (or "already exists" in stderr — idempotent)
#        1 = all attempts exhausted
#
# Delay schedule (base=1000ms): ~1s, ~2s, ~4s (plus ±base jitter per attempt)
# Called by: templates/mode-2-full-release.md (Phase 3 gh release create)
#            templates/mode-3-plugin-release.md (Phase 3 gh release create)
#            scripts/verify-release.sh (gh release view calls)

if [[ $# -lt 4 ]]; then
  echo "Usage: api-retry.sh <max_attempts> <base_delay_ms> -- <command...>" >&2
  exit 1
fi

MAX_ATTEMPTS="$1"
BASE_DELAY_MS="$2"
shift 2

# Consume the '--' separator
if [[ "${1:-}" == "--" ]]; then
  shift
fi

attempt=0
while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
  attempt=$((attempt + 1))

  # Capture stderr; if command succeeds, exit immediately
  stderr_file=$(mktemp)
  if "$@" 2>"$stderr_file"; then
    rm -f "$stderr_file"
    exit 0
  fi
  stderr_content=$(cat "$stderr_file")
  rm -f "$stderr_file"

  # "already exists" is treated as success (idempotent re-run)
  if echo "$stderr_content" | grep -qi "already exists"; then
    echo "Note: resource already exists — treating as success." >&2
    exit 0
  fi

  if [[ $attempt -ge $MAX_ATTEMPTS ]]; then
    echo "Error: command failed after ${MAX_ATTEMPTS} attempts." >&2
    [[ -n "$stderr_content" ]] && echo "Last error: $stderr_content" >&2
    exit 1
  fi

  # Exponential delay with jitter: base * 2^(attempt-1) + random[0, base)
  delay_ms=$(( BASE_DELAY_MS * (1 << (attempt - 1)) ))
  jitter=$(( RANDOM % BASE_DELAY_MS ))
  total_ms=$(( delay_ms + jitter ))
  total_s=$(echo "scale=3; $total_ms / 1000" | bc)

  echo "Attempt ${attempt} failed. Retrying in ${total_s}s..." >&2
  sleep "$total_s"
done
```

**Step 4: Make executable and run tests**

```bash
chmod +x plugins/release-pipeline/scripts/api-retry.sh
bash plugins/release-pipeline/tests/test-api-retry.sh
```
Expected: `4 passed, 0 failed`

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/api-retry.sh \
        plugins/release-pipeline/tests/test-api-retry.sh
git commit -m "feat(release-pipeline): add api-retry.sh with exponential backoff and jitter"
```

---

## Task 3: `scripts/check-waivers.sh` (new)

Looks up whether a named pre-flight check is waived for a given plugin in `.release-waivers.json`.

**Files:**
- Create: `plugins/release-pipeline/scripts/check-waivers.sh`
- Create: `plugins/release-pipeline/tests/test-check-waivers.sh`

**Step 1: Create the test script**

```bash
#!/usr/bin/env bash
# tests/test-check-waivers.sh — Unit tests for check-waivers.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/check-waivers.sh"
PASS=0; FAIL=0
TMPDIR_LOCAL=$(mktemp -d)

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

# Write a test waivers file
WAIVER_FILE="$TMPDIR_LOCAL/.release-waivers.json"
cat > "$WAIVER_FILE" <<'JSON'
{
  "waivers": [
    { "check": "dirty_working_tree", "plugin": "*",          "reason": "monorepo always dirty" },
    { "check": "missing_tests",      "plugin": "docs-manager", "reason": "docs-only plugin" },
    { "check": "tag_exists",         "plugin": "my-plugin",   "reason": "re-running partial release" }
  ]
}
JSON

# ---- Test 1: wildcard waiver matches any plugin ----
reason=$(bash "$SCRIPT" "$WAIVER_FILE" dirty_working_tree any-plugin 2>/dev/null)
assert_eq "$?" "0" "wildcard waiver: exit 0"
assert_eq "$reason" "monorepo always dirty" "wildcard waiver: correct reason"

# ---- Test 2: plugin-specific waiver matches exact plugin ----
reason=$(bash "$SCRIPT" "$WAIVER_FILE" missing_tests docs-manager 2>/dev/null)
assert_eq "$?" "0" "specific plugin waiver: exit 0"
assert_eq "$reason" "docs-only plugin" "specific plugin waiver: correct reason"

# ---- Test 3: plugin-specific waiver does NOT match different plugin ----
bash "$SCRIPT" "$WAIVER_FILE" missing_tests other-plugin 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "plugin-specific waiver: no match for other plugin → exit 1"

# ---- Test 4: check not in waivers → exit 1 ----
bash "$SCRIPT" "$WAIVER_FILE" noreply_email any-plugin 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "unknown check → exit 1"

# ---- Test 5: missing waiver file → exit 1 (fail open: don't waive) ----
bash "$SCRIPT" "/nonexistent/.release-waivers.json" dirty_working_tree any-plugin 2>/dev/null \
  && RES=0 || RES=$?
assert_eq "$RES" "1" "missing waiver file → exit 1"

rm -rf "$TMPDIR_LOCAL"
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

**Step 2: Run tests to confirm they fail**

```bash
bash plugins/release-pipeline/tests/test-check-waivers.sh
```
Expected: error "No such file or directory"

**Step 3: Create `check-waivers.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# check-waivers.sh — Look up whether a pre-flight check is waived.
#
# Usage: check-waivers.sh <waiver-file> <check-name> [plugin-name]
# Output: waiver reason (stdout) if waived
# Exit:   0 = check is waived, 1 = not waived (or file missing)
#
# Waiver file: .release-waivers.json at repo root
# Called by: agents/git-preflight.md, agents/test-runner.md, agents/docs-auditor.md
# before marking any check as FAIL.
#
# Supported check names: dirty_working_tree, protected_branch, noreply_email,
#   tag_exists, missing_tests, stale_docs

if [[ $# -lt 2 ]]; then
  echo "Usage: check-waivers.sh <waiver-file> <check-name> [plugin-name]" >&2
  exit 1
fi

WAIVER_FILE="$1"
CHECK_NAME="$2"
PLUGIN_NAME="${3:-*}"

if [[ ! -f "$WAIVER_FILE" ]]; then
  exit 1
fi

# Use sys.argv to avoid shell injection; exit 0 from python means waived
python3 - "$WAIVER_FILE" "$CHECK_NAME" "$PLUGIN_NAME" <<'PYEOF'
import json, sys

waiver_file = sys.argv[1]
check_name  = sys.argv[2]
plugin_name = sys.argv[3]

try:
    with open(waiver_file) as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError):
    sys.exit(1)

for w in data.get("waivers", []):
    if w.get("check") != check_name:
        continue
    p = w.get("plugin", "*")
    if p == "*" or p == plugin_name:
        print(w.get("reason", "no reason specified"))
        sys.exit(0)

sys.exit(1)
PYEOF
```

**Step 4: Make executable and run tests**

```bash
chmod +x plugins/release-pipeline/scripts/check-waivers.sh
bash plugins/release-pipeline/tests/test-check-waivers.sh
```
Expected: `5 passed, 0 failed`

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/check-waivers.sh \
        plugins/release-pipeline/tests/test-check-waivers.sh
git commit -m "feat(release-pipeline): add check-waivers.sh for pre-flight check waivers"
```

---

## Task 4: Update `scripts/verify-release.sh`

Wrap both `gh release view` calls with `api-retry.sh`.

**Files:**
- Modify: `plugins/release-pipeline/scripts/verify-release.sh`

**Step 1: Identify the two `gh release view` calls**

In `verify-release.sh`:
- Line 88: `gh release view "$TAG" --json tagName ...` (GitHub release exists check)
- Line 97: `gh release view "$TAG" --json body ...` (release notes check)

**Step 2: Update the file — wrap both calls**

Replace the GitHub release exists check (lines 88-92):
```bash
# Old:
if gh release view "$TAG" --json tagName -q '.tagName' -R "$(git -C "$REPO" remote get-url origin 2>/dev/null)" &>/dev/null; then
# New:
if bash "$(dirname "$0")/api-retry.sh" 3 1000 -- \
    gh release view "$TAG" --json tagName -q '.tagName' \
    -R "$(git -C "$REPO" remote get-url origin 2>/dev/null)" &>/dev/null; then
```

Replace the release notes fetch (line 97):
```bash
# Old:
release_body=$(gh release view "$TAG" --json body -q '.body' -R "$(git -C "$REPO" remote get-url origin 2>/dev/null)" 2>/dev/null || true)
# New:
release_body=$(bash "$(dirname "$0")/api-retry.sh" 3 1000 -- \
    gh release view "$TAG" --json body -q '.body' \
    -R "$(git -C "$REPO" remote get-url origin 2>/dev/null)" 2>/dev/null || true)
```

**Step 3: Verify the file is syntactically valid**

```bash
bash -n plugins/release-pipeline/scripts/verify-release.sh
```
Expected: no output (no errors)

**Step 4: Commit**

```bash
git add plugins/release-pipeline/scripts/verify-release.sh
git commit -m "feat(release-pipeline): wrap gh release view calls with api-retry in verify-release.sh"
```

---

## Task 5: Update `agents/git-preflight.md`

Add (a) remote tag check using `reconcile-tags.sh` output, and (b) waiver support for all 4 git checks. Also add `tag_exists` to the check list.

**Files:**
- Modify: `plugins/release-pipeline/agents/git-preflight.md`

**Step 1: Rewrite the file**

The updated file adds:
1. A 6th check: **Remote tag status** — runs `reconcile-tags.sh` and reports the status
2. Waiver lookups: before marking ANY check FAIL, call `check-waivers.sh` (if `.release-waivers.json` exists at the repo root). If waived, print `⊘ <check> WAIVED — <reason>` and count as PASS.
3. The waiver file path is `.release-waivers.json` in the current working directory.

```markdown
---
name: git-preflight
description: Verify clean git state, noreply email, and tag availability. Used by release pipeline Phase 1.
tools: Bash, Read, Grep
model: haiku
---

You are the git pre-flight checker for a release pipeline.

## Your Task

Run these checks and report results. Before marking any check FAIL, run the waiver lookup (see Waiver Lookup section).

1. **Clean working tree**: `git status --porcelain` must be empty
2. **On dev branch**: Current branch must NOT be `main` or `master`
3. **Noreply email**: `git config user.email` must match `*@users.noreply.github.com`
4. **Remote exists**: `git remote get-url origin` must succeed
5. **Tag available (local)**: Target tag must not already exist locally (`git tag -l "TAG"` returns empty)
6. **Tag available (remote)**: Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-tags.sh . <target-tag>` and capture output

For check 6, interpret the output:
- `MISSING` or `LOCAL_ONLY` → PASS (tag not on remote yet)
- `BOTH` or `REMOTE_ONLY` → check waiver for `tag_exists`; if not waived → FAIL with "tag already exists on remote"
- Script exit 1 → FAIL with "could not determine remote tag state"

## Waiver Lookup

Before marking any check FAIL, look for `.release-waivers.json` in the current directory and run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-waivers.sh .release-waivers.json <check-name> [plugin-name]
```

Check name mapping:
- Check 1 (clean tree) → `dirty_working_tree`
- Check 2 (dev branch) → `protected_branch`
- Check 3 (noreply email) → `noreply_email`
- Check 5 (local tag) → `tag_exists`
- Check 6 (remote tag) → `tag_exists`

If `check-waivers.sh` exits 0 (waived): print `⊘ <check> WAIVED — <reason>` and count as PASS.
If `check-waivers.sh` exits 1 (not waived) or the file doesn't exist: proceed with original FAIL behavior.

The plugin-name argument is the scoped plugin being released, or omit it for full-repo releases.

## Output Format

```
GIT PRE-FLIGHT
==============
Status: PASS | FAIL
Clean tree:   YES | NO (X files modified) | ⊘ WAIVED — <reason>
Branch:       <branch-name> (OK | FAIL — on protected branch | ⊘ WAIVED — <reason>)
Email:        <email> (OK | FAIL — not noreply | ⊘ WAIVED — <reason>)
Remote:       <url> (OK | FAIL)
Tag (local):  <tag> — available | ALREADY EXISTS | ⊘ WAIVED — <reason>
Tag (remote): MISSING | LOCAL_ONLY | BOTH | REMOTE_ONLY — <OK | FAIL | ⊘ WAIVED — <reason>>
```

## Rules

- Any single unwaived FAIL = overall FAIL
- Do not modify any files or git state.
- Run checks in order, report all results even if one fails early.
```

**Step 2: Verify the file was written correctly (check for key phrases)**

```bash
grep -c "reconcile-tags.sh\|check-waivers.sh\|tag_exists\|WAIVED" \
  plugins/release-pipeline/agents/git-preflight.md
```
Expected: 4 or more (each term appears at least once)

**Step 3: Commit**

```bash
git add plugins/release-pipeline/agents/git-preflight.md
git commit -m "feat(release-pipeline): add remote tag check and waiver support to git-preflight agent"
```

---

## Task 6: Update `agents/test-runner.md`

Add waiver support for `missing_tests`.

**Files:**
- Modify: `plugins/release-pipeline/agents/test-runner.md`

**Step 1: Rewrite the file**

Add a "Waiver Lookup" section before the Rules section. When no test runner is detected (the `missing_tests` condition), run `check-waivers.sh` first.

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

## Waiver Lookup

When no test runner is detected (step 2 fails and CLAUDE.md has no test command), before reporting FAIL run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-waivers.sh .release-waivers.json missing_tests [plugin-name]
```

If exit 0 (waived): report `⊘ missing_tests WAIVED — <reason>` and set status to PASS.
If exit 1 (not waived): proceed with original FAIL behavior ("No test runner found").

## Output Format

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
- If no test runner is detected and CLAUDE.md has no test command, check waiver before reporting FAIL.
- Do not modify any files. You are read-only except for running the test command.
```

**Step 2: Verify**

```bash
grep -c "check-waivers.sh\|missing_tests\|WAIVED" \
  plugins/release-pipeline/agents/test-runner.md
```
Expected: 3 or more

**Step 3: Commit**

```bash
git add plugins/release-pipeline/agents/test-runner.md
git commit -m "feat(release-pipeline): add missing_tests waiver support to test-runner agent"
```

---

## Task 7: Update `agents/docs-auditor.md`

Add waiver support for `stale_docs`.

**Files:**
- Modify: `plugins/release-pipeline/agents/docs-auditor.md`

**Step 1: Rewrite the file**

Add a "Waiver Lookup" section. The `stale_docs` waiver applies when the status would be FAIL due to stale version references.

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
- Flag words: "synergy", "leverage" (as verb), "stakeholders", "paradigm", "circle back", "bandwidth" (non-technical usage)
- The target tone is professional but approachable — NOT corporate

### 4. File Existence

- Warn (don't fail) if README.md is missing
- Warn (don't fail) if CHANGELOG.md is missing

## Waiver Lookup

When the audit would result in FAIL status (stale versions or broken links found), before reporting FAIL run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-waivers.sh .release-waivers.json stale_docs [plugin-name]
```

If exit 0 (waived): downgrade FAIL to WARN and annotate `⊘ stale_docs WAIVED — <reason>`.
If exit 1 (not waived): proceed with original FAIL behavior.

Note: broken links are NOT waivable — only stale version references are covered by `stale_docs`.

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
- WARN = only warnings (tone flags or missing files, but no stale versions or broken links; or stale_docs waived)
- FAIL = stale version references or broken links found (and not waived)
- Do not modify any files.
```

**Step 2: Verify**

```bash
grep -c "check-waivers.sh\|stale_docs\|WAIVED" \
  plugins/release-pipeline/agents/docs-auditor.md
```
Expected: 3 or more

**Step 3: Commit**

```bash
git add plugins/release-pipeline/agents/docs-auditor.md
git commit -m "feat(release-pipeline): add stale_docs waiver support to docs-auditor agent"
```

---

## Task 8: Update `templates/mode-2-full-release.md`

Add tag reconciliation (before `git tag -a`) and retry wrapper (for `gh release create`) in Phase 3.

**Files:**
- Modify: `plugins/release-pipeline/templates/mode-2-full-release.md`

**Step 1: Add tag reconciliation block before `git tag -a`**

In Phase 3, before the `git tag -a "v<version>"` command, add:

```markdown
**Tag reconciliation:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-tags.sh . "v<version>"
```

Capture the first line of stdout as `tag_status`. Branch based on value:
- `MISSING` or `LOCAL_ONLY`: proceed to `git tag -a` step normally
- `BOTH` or `REMOTE_ONLY`: skip `git tag -a` entirely — tag already exists; proceed to `git push origin main --tags` (will be a no-op for that tag) and then the GitHub release step
```

**Step 2: Wrap `gh release create` with retry**

Replace:
```bash
gh release create "v<version>" --title "v<version>" --notes "<changelog entry>"
```
With:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/api-retry.sh 3 1000 -- \
  gh release create "v<version>" --title "v<version>" --notes "<changelog entry>"
```

**Step 3: Verify the file contains both new calls**

```bash
grep -c "reconcile-tags.sh\|api-retry.sh" \
  plugins/release-pipeline/templates/mode-2-full-release.md
```
Expected: 2

**Step 4: Commit**

```bash
git add plugins/release-pipeline/templates/mode-2-full-release.md
git commit -m "feat(release-pipeline): add tag reconciliation and retry to mode-2 full release"
```

---

## Task 9: Update `templates/mode-3-plugin-release.md`

Same changes as Task 8 but for scoped plugin release (tag format is `<plugin>/v<version>`).

**Files:**
- Modify: `plugins/release-pipeline/templates/mode-3-plugin-release.md`

**Step 1: Add tag reconciliation before `git tag -a`**

```markdown
**Tag reconciliation:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-tags.sh . "<plugin-name>/v<version>"
```

Capture the first line of stdout as `tag_status`. Same branching logic as Mode 2:
- `MISSING` or `LOCAL_ONLY`: create tag normally
- `BOTH` or `REMOTE_ONLY`: skip `git tag -a`, proceed to push and GitHub release
```

**Step 2: Wrap `gh release create` with retry**

Replace:
```bash
gh release create "<plugin-name>/v<version>" --title "<plugin-name> v<version>" --notes "<changelog entry>"
```
With:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/api-retry.sh 3 1000 -- \
  gh release create "<plugin-name>/v<version>" --title "<plugin-name> v<version>" --notes "<changelog entry>"
```

**Step 3: Verify**

```bash
grep -c "reconcile-tags.sh\|api-retry.sh" \
  plugins/release-pipeline/templates/mode-3-plugin-release.md
```
Expected: 2

**Step 4: Commit**

```bash
git add plugins/release-pipeline/templates/mode-3-plugin-release.md
git commit -m "feat(release-pipeline): add tag reconciliation and retry to mode-3 plugin release"
```

---

## Task 10: Create `templates/mode-7-batch-release.md` (new)

New batch release template. Iterates all unreleased plugins, quarantines failures, emits summary report.

**Files:**
- Create: `plugins/release-pipeline/templates/mode-7-batch-release.md`

**Step 1: Write the template**

```markdown
# Mode 7: Batch Release All Plugins

# Loaded by the release command router after the user selects "Batch Release All Plugins".
# Context from Phase 0: is_monorepo=true, unreleased_plugins (TSV list), current_branch.
#
# Quarantine semantics: on any FAIL during pre-flight, prep, or release phases,
# add the plugin to the failed list and continue to the next plugin WITHOUT stopping.
# Phase 4 (verification) failures are recorded as warnings but do NOT quarantine.

## Step 0 — Release Plan Presentation

For each plugin in `unreleased_plugins`, run in parallel:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-version.sh . --plugin <plugin-name>
```

Collect `suggested_version` for each plugin. Then display the plan:

```
BATCH RELEASE PLAN
==================
Plugin              Current    →  Proposed
<plugin-a>          <ver>      →  <proposed>
<plugin-b>          <ver>      →  <proposed>
```

Use **AskUserQuestion**:
- question: `"Proceed with batch release of <N> plugins?"`
- header: `"Batch Release"`
- options:
  1. label: `"Proceed"`, description: `"Release all <N> plugins sequentially — failures quarantined"`
  2. label: `"Abort"`, description: `"Cancel the batch release"`

If Abort → stop.

Initialize: `succeeded=[]`, `failed=[]`

---

## Per-Plugin Loop

Repeat the following block for each plugin in `unreleased_plugins` in order.

**Output a header at the start of each plugin:**
```
── Releasing <plugin-name> v<proposed-version> (<N> of <total>) ──
```

### Phase 1 — Scoped Pre-flight

Launch THREE Task agents simultaneously (same as Mode 3 Phase 1):

**Agent A — Test Runner (scoped):**
Follow Mode 3 Phase 1 Agent A prompt exactly.

**Agent B — Docs Auditor (scoped):**
Follow Mode 3 Phase 1 Agent B prompt exactly.

**Agent C — Git Pre-flight (scoped):**
Follow Mode 3 Phase 1 Agent C prompt exactly.

After all return, check results:
- If ALL PASS or WARN → continue to Phase 2
- If ANY FAIL → **quarantine**: append `"<plugin-name> v<version> — Phase 1: <failing check>"` to `failed[]`, output `"⚠ Quarantined <plugin-name>: Phase 1 failure"`, and **skip to the next plugin**

### Phase 2 — Scoped Preparation

Follow Mode 3 Phase 2 exactly, with these differences:
- **No approval gate** — batch consent was given at Step 0
- If any step fails: revert changes (`git checkout -- plugins/<plugin-name>/`), append to `failed[]`, output `"⚠ Quarantined <plugin-name>: Phase 2 failure — <error>"`, and skip to next plugin

### Phase 3 — Scoped Release

Follow Mode 3 Phase 3 exactly (including tag reconciliation and retry).
If any step fails: append to `failed[]`, output `"⚠ Quarantined <plugin-name>: Phase 3 failure — <error>"`, and skip to next plugin.

**Do NOT attempt rollback of git operations already committed** — report the state in the summary.

### Phase 4 — Scoped Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version> --plugin <plugin-name>
```

- Exit 0: append `"<plugin-name> v<version>"` to `succeeded[]`
- Exit 1: append `"<plugin-name> v<version> ⚠"` to `succeeded[]` (released but verify failed)

---

## Summary Report

Always emit this after all plugins are processed, regardless of failures:

```
BATCH RELEASE REPORT
====================
Succeeded (<N>): <plugin-a> v1.2.0, <plugin-b> v0.3.1
Failed    (<N>): <plugin-d> v1.1.0 — Phase 1: dirty_working_tree (not waived)
Skipped   (<N>): —
```

If `failed` is non-empty, append:
```
⚠ <N> plugin(s) require attention. See failures above. Re-run `/release` for each to retry.
```
```

**Step 2: Verify the file was created**

```bash
grep -c "Batch Release\|quarantine\|succeeded\|failed\[\]" \
  plugins/release-pipeline/templates/mode-7-batch-release.md
```
Expected: 4 or more

**Step 3: Commit**

```bash
git add plugins/release-pipeline/templates/mode-7-batch-release.md
git commit -m "feat(release-pipeline): add mode-7-batch-release.md template"
```

---

## Task 11: Update `commands/release.md`

Add Mode 7 (Batch Release) to the menu and route it to `mode-7-batch-release.md`.

**Files:**
- Modify: `plugins/release-pipeline/commands/release.md`

**Step 1: Add menu entry after Plugin Release (monorepo-only section)**

In the "Conditionally include" section, after Plugin Release option (option 6), add:

```markdown
7. **Batch Release All Plugins**
   - label: `"Batch Release"`
   - description: `"Release all <N> plugins with unreleased changes sequentially — quarantine failures, produce summary (${N} plugins ready)"` where N is `len(unreleased_plugins)`
   - If `unreleased_plugins` is empty: `"Batch Release (all plugins up to date — nothing to release)"`
```

**Step 2: Add routing to the template dispatch table**

In the `| Selection | Template |` table, add the row:

```
| Batch Release | `${CLAUDE_PLUGIN_ROOT}/templates/mode-7-batch-release.md` |
```

**Step 3: Verify**

```bash
grep -c "Batch Release\|mode-7" plugins/release-pipeline/commands/release.md
```
Expected: 2

**Step 4: Commit**

```bash
git add plugins/release-pipeline/commands/release.md
git commit -m "feat(release-pipeline): add Batch Release option to /release menu"
```

---

## Task 12: Version Bump, CHANGELOG, and Final Commit

Bump plugin to v1.6.0, update marketplace.json, write CHANGELOG entry.

**Files:**
- Modify: `plugins/release-pipeline/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/release-pipeline/CHANGELOG.md`

**Step 1: Bump version in plugin.json**

```json
{ "name": "release-pipeline", "version": "1.6.0", ... }
```

**Step 2: Bump version in marketplace.json**

Find the `release-pipeline` entry and update `"version": "1.6.0"`.

**Step 3: Add CHANGELOG entry** (prepend under `# Changelog`):

```markdown
## [1.6.0] - 2026-02-20

### Added
- `scripts/reconcile-tags.sh` — compare local/remote tag state; auto-fetch REMOTE_ONLY tags before push
- `scripts/api-retry.sh` — exponential backoff + jitter retry wrapper (3 attempts) for `gh` CLI calls
- `scripts/check-waivers.sh` — look up pre-flight check waivers from `.release-waivers.json`
- `.release-waivers.json` support — permanently waive checks per-plugin (`dirty_working_tree`, `protected_branch`, `noreply_email`, `tag_exists`, `missing_tests`, `stale_docs`)
- Mode 7: Batch Release All Plugins — release all unreleased plugins sequentially with quarantine-and-continue semantics and summary report
- `agents/git-preflight.md`: remote tag check (check 6) + waiver support for all git checks
- `agents/test-runner.md`: waiver support for `missing_tests`
- `agents/docs-auditor.md`: waiver support for `stale_docs`

### Changed
- `templates/mode-2-full-release.md` Phase 3: tag reconciliation before push, retry on `gh release create`
- `templates/mode-3-plugin-release.md` Phase 3: same as mode-2
- `scripts/verify-release.sh`: `gh release view` calls now use retry wrapper
```

**Step 4: Run marketplace validator**

```bash
bash scripts/validate-marketplace.sh
```
Expected: `✓ Marketplace validation passed`

**Step 5: Final commit**

```bash
git add plugins/release-pipeline/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        plugins/release-pipeline/CHANGELOG.md
git commit -m "feat(release-pipeline): v1.6.0 — resilience layer (tag reconcile, retry, waivers, batch release)"
```

---

## Run All Tests

After all tasks complete, run the full test suite to confirm nothing regressed:

```bash
bash plugins/release-pipeline/tests/test-reconcile-tags.sh
bash plugins/release-pipeline/tests/test-api-retry.sh
bash plugins/release-pipeline/tests/test-check-waivers.sh
bash scripts/validate-marketplace.sh
```

All four must exit 0.
