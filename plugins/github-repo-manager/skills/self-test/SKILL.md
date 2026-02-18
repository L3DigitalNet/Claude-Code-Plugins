# Self-Test — Skill

## Purpose

Run, interpret, and iterate on the gh-manager self-test suite. This skill tells Claude Code how to execute tests, read results, diagnose failures, and fix the helper code.

## When This Skill Applies

- Owner says "run tests", "self-test", "run the test suite"
- Owner asks to verify the plugin works
- Owner reports a command that isn't working
- After making changes to helper source, to verify nothing broke

---

## Test Repo

**Default:** `L3DigitalNet/testing` (private, owned by the plugin author)

Set via environment: `export TEST_REPO=L3DigitalNet/testing`

This repo is a dedicated scratch space. Mutation tests (Tier C) create real issues, PRs, branches, labels, releases, and files in this repo. They clean up after themselves where possible, but closed issues/PRs accumulate over time — that's expected.

---

## Quick Reference

```bash
# Run everything
bash tests/run-all.sh

# Run specific tiers
bash tests/run-all.sh a     # Infrastructure only (no API, no PAT)
bash tests/run-all.sh b     # Read-only API tests
bash tests/run-all.sh c     # Mutation tests (writes to TEST_REPO)
bash tests/run-all.sh ab    # Infrastructure + read-only

# Environment
export GITHUB_PAT=ghp_...           # Required for Tiers B and C
export TEST_REPO=L3DigitalNet/testing  # Default
export GH_MANAGER=gh-manager        # Or full path to binary
```

---

## Test Tiers

### Tier A — Infrastructure (no API calls)

**What it tests:** Binary availability, command parsing, help output for all 14 groups, missing required options produce errors, every dry-run flag short-circuits before making API calls, dry-run output structure (action fields, preserved options), YAML validation on config commands, missing-PAT error messages.

**When to run:** After any change to the CLI entry point (`bin/gh-manager.js`), adding/removing commands, changing option parsing. Safe to run without a PAT.

**Zero network calls.** Uses `GITHUB_PAT=fake-pat-for-dry-run-tests` so commands parse but never hit the API.

### Tier B — Read-Only API Tests

**What it tests:** Every read command against a real repo. Auth verification, rate limit check, repo discovery and classification, repo metadata + community profile + labels, file exists/get, branch listing, PR list/get/diff/comments, issue list/get/comments, all 5 security commands (handles 403/404 gracefully), deps graph + dependabot-prs, releases list/latest/compare/changelog, discussions list, notifications list, config read + resolve.

**When to run:** After any change to a command's data fetching or response trimming logic. Requires a valid PAT.

**Adaptive testing:** If the test repo has no PRs, issues, releases, or discussions, those sub-tests are skipped (not failed). The test reports what it found so you can see the repo's current state.

### Tier C — Mutation Tests

**What it tests:** Full lifecycles — label create→update, file put→get→verify→delete, branch create→verify→delete, issue creation (via API fallback) → get→label→comment→assign→close, PR branch→file→create→get→diff→comment→label→close→cleanup, release draft→verify-draft→publish→cleanup, config write→read→verify→cleanup, wiki clone→diff, discussions comment.

**When to run:** After any change to a mutation command. Only runs against the dedicated test repo.

**Cleanup:** Each test creates timestamped artifacts (`test-label-20260218-001234`, `test/self-test-20260218-001234`). Most are cleaned up automatically. Closed issues and PRs with `[Self-test]` prefix remain — they're harmless but can be cleaned manually via GitHub UI.

---

## Reading Test Output

### Symbols

```
✓  — Passed
✗  — Failed (detail follows on next line)
○  — Skipped (reason in parentheses)
```

### Example Output

```
── B5: PR operations (read) ──
  ✓ prs list returns pull_requests
  PRs found: 3
  ✓ prs get #5 returns review_summary
  ✓ prs diff #5 returns files
  ✓ prs comments #5 returns comments
```

### Failure Output

```
── C4: Issues ──
  ✗ issues label (add)
    → expected action='labeled', got 'undefined'
```

### Summary

```
═══════════════════════════════════════
Results: 87 tests
  ✓ 82 passed
  ✗ 2 failed
  ○ 3 skipped

Failures:
  • C4: Issues: issues label (add)
  • C5: PRs: prs close
═══════════════════════════════════════
```

---

## Diagnosing Failures

### Common Patterns

| Failure | Likely Cause | Fix |
|---------|-------------|-----|
| `exit=1 stderr=GITHUB_PAT` | PAT not set | `export GITHUB_PAT=...` |
| `exit=1` on read command | API returned error | Run the command manually, check JSON error message |
| `expected action='labeled', got 'undefined'` | Response shape changed or command returned error | Run command manually, check output fields |
| Security commands skipped | Features not enabled on test repo or PAT lacks scopes | Expected — not a failure |
| `could not create issue` | PAT lacks Issues write scope | Check PAT permissions |
| Wiki tests skipped | Wiki not enabled or empty | Enable wiki and add a Home page |

### Debug Workflow

When a test fails:

1. **Run the failing command manually** to see the full JSON output:
   ```bash
   gh-manager issues label --repo L3DigitalNet/testing --issue 5 --add bug
   ```

2. **Check stderr** — errors go to stderr as JSON:
   ```bash
   gh-manager issues label --repo L3DigitalNet/testing --issue 5 --add bug 2>/tmp/err.json
   cat /tmp/err.json
   ```

3. **Check the source** — open the relevant command file:
   ```
   helper/src/commands/issues.js   → issues commands
   helper/src/commands/prs.js      → PR commands
   helper/src/commands/security.js → security commands
   ```

4. **Fix and re-run** — run just the affected tier:
   ```bash
   bash tests/run-all.sh c
   ```

---

## Fix-Test-Fix Loop

This is the intended development workflow:

1. **Run tests** → identify failures
2. **Read the failure detail** → understand what's wrong
3. **Open the source file** → find the bug or missing feature
4. **Fix it** → edit the command file
5. **Re-run the affected tier** → verify the fix
6. **Run all tiers** → verify nothing else broke
7. **Repeat** until all tiers pass

### After Fixing a Command

```bash
# Quick check — just the tier that failed
bash tests/run-all.sh c

# Full regression — all tiers
bash tests/run-all.sh
```

### After Adding a New Command

1. Add the command to the appropriate tier:
   - **Tier A:** Add a dry-run test (if the command supports `--dry-run`)
   - **Tier B:** Add a read test (if it's a GET operation)
   - **Tier C:** Add a mutation test (if it writes data)
2. Run the tier to verify
3. Run all tiers to catch regressions

---

## Test Repo Preparation

The test repo (`L3DigitalNet/testing`) should have:

| Feature | Required By | How to Enable |
|---------|------------|---------------|
| README.md | Tier B (files) | Already exists |
| Wiki enabled | Tier C (wiki) | Settings → General → Features → Wikis |
| Discussions enabled | Tiers B/C | Settings → General → Features → Discussions |
| Issues enabled | Tier C (issues) | Settings → General → Features → Issues |
| At least 1 release | Tier B (releases) | Create manually or via Tier C |
| Dependabot enabled | Tier B (security) | Settings → Security → Dependabot |

Missing features cause skips, not failures. You can enable them incrementally.

---

## Adding New Tests

### Test File Structure

```
tests/
├── lib.sh           # Shared assertions and output formatting
├── run-all.sh       # Main runner (delegates to tier scripts)
├── run-tier-a.sh    # Infrastructure (no API)
├── run-tier-b.sh    # Read-only API
└── run-tier-c.sh    # Mutations
```

### Available Assertions (from lib.sh)

```bash
# Basic
assert_ok "name" "command"           # Exit 0
assert_fail "name" "command"         # Exit non-zero
assert_json "name" "command"         # Exit 0 + valid JSON
assert_json_has "name" "key" "cmd"   # JSON has top-level key
assert_json_eq "name" "key" "val" "cmd"  # JSON field equals value
assert_dry_run "name" "command"      # JSON has dry_run=true

# Manual (use after `run "command"`)
json_val "key"                       # Extract field from CMD_OUT
json_val "nested.key"                # Dot-path extraction

# Control flow
skip "name" "reason"                 # Mark as skipped
group "Section Name"                 # Start a new test group
```

### Example: Adding a Test for a New Command

If you add `prs approve --repo --pr` to the helper:

```bash
# In run-tier-a.sh (dry-run):
assert_dry_run "prs approve --dry-run" \
  "$GH_MANAGER prs approve --repo x/y --pr 1 --dry-run"

# In run-tier-c.sh (after creating a PR):
assert_json_eq "prs approve" \
  "action" "approved" \
  "$GH_MANAGER prs approve --repo $TEST_REPO --pr $PR_NUM"
```
