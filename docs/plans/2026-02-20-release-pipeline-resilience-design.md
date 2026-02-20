# Release Pipeline Resilience Layer — Design

**Date:** 2026-02-20
**Status:** Approved
**Plugin:** `plugins/release-pipeline`

## Overview

Four interrelated improvements to the release pipeline that add fault tolerance, conflict recovery, and batch operations without rearchitecting the existing orchestration model.

## 1. Tag Reconciliation

### Problem
`git push origin main --tags` fails if the target tag already exists on the remote. The git-preflight agent only checks local tags (`git tag -l`), missing the case where a previous partial run pushed the tag but didn't complete.

### Design
New script `scripts/reconcile-tags.sh <repo-path> <tag>` that compares local vs remote state and outputs one of four statuses:

| Status | Local | Remote | Action |
|--------|-------|--------|--------|
| `MISSING` | ✗ | ✗ | Proceed normally — create and push |
| `LOCAL_ONLY` | ✓ | ✗ | Proceed — push will create it |
| `BOTH` | ✓ | ✓ | Skip `git tag -a`, still push + verify GitHub release |
| `REMOTE_ONLY` | ✗ | ✓ | Auto-fetch (`git fetch origin refs/tags/<tag>:refs/tags/<tag>`), then treat as `BOTH` |

Exit codes: 0 = proceed (any resolvable state), 1 = unrecoverable conflict.

**Integrations:**
- Called in Phase 3 of `mode-2-full-release.md` and `mode-3-plugin-release.md` before `git tag -a`
- `agents/git-preflight.md` gains a 6th check (remote tag status) using the same logic — surfaces conflicts in Phase 1 before any writes happen

### Waivability
`tag_exists` can be added to `.release-waivers.json` to suppress the pre-flight warning when intentionally re-running a release.

---

## 2. API Retry with Exponential Backoff + Jitter

### Problem
`gh release create` and `gh release view` can fail transiently (GitHub API 5xx, network blip). Currently a single failure aborts the entire release.

### Design
New script `scripts/api-retry.sh <max_attempts> <base_delay_ms> -- <command...>`:
- Retries on any non-zero exit from the wrapped command
- Exception: if stderr contains "already exists" → treat as success (exit 0) — handles idempotent re-runs
- Delay: `base_delay * 2^attempt + jitter` where `jitter = $RANDOM % base_delay_ms`
- Default invocation in templates: 3 attempts, 1000ms base delay
- Example delays: ~1s, ~2s, ~4s (plus ±1s jitter each)

**Integrations:**
- `templates/mode-2-full-release.md` Phase 3: `gh release create` wrapped
- `templates/mode-3-plugin-release.md` Phase 3: `gh release create` wrapped
- `scripts/verify-release.sh`: both `gh release view` calls wrapped

---

## 3. Pre-flight Waiver Config (`.release-waivers.json`)

### Problem
Some checks (dirty tree, missing tests) are legitimately not applicable for certain plugins (e.g., docs-only plugins never have tests). Currently these cause hard FAIL that blocks release.

### Design
Optional file at repo root. Schema:

```json
{
  "waivers": [
    { "check": "dirty_working_tree", "plugin": "*",         "reason": "monorepo always has some uncommitted files" },
    { "check": "missing_tests",     "plugin": "docs-manager", "reason": "docs-only plugin" },
    { "check": "tag_exists",        "plugin": "my-plugin",   "reason": "re-running after partial release" }
  ]
}
```

- `plugin: "*"` = applies to all plugins and full-repo releases
- File is optional — absence means no waivers

New script `scripts/check-waivers.sh <waiver-file> <check-name> [plugin-name]`:
- Exit 0 = check is waived (with reason printed to stdout)
- Exit 1 = not waived

**Waivable check names:**

| Check name | Agent | Original condition |
|------------|-------|--------------------|
| `dirty_working_tree` | git-preflight | `git status --porcelain` non-empty |
| `protected_branch` | git-preflight | on `main` or `master` |
| `noreply_email` | git-preflight | email not `*@users.noreply.github.com` |
| `tag_exists` | git-preflight | tag already exists locally or remotely |
| `missing_tests` | test-runner | no test suite found |
| `stale_docs` | docs-auditor | stale version references in docs |

**Agent prompt updates:**
- `agents/git-preflight.md`: before marking each check FAIL, call `check-waivers.sh`; if waived, print `⊘ <check> WAIVED — <reason>` and count as PASS
- `agents/test-runner.md`: same pattern for `missing_tests`
- `agents/docs-auditor.md`: same for `stale_docs`

---

## 4. Batch Release Mode (Mode 7)

### Problem
No way to release multiple plugins in one operation. Requires N sequential `/release` invocations.

### Design
New menu entry in `commands/release.md` (monorepo only):

```
7. Batch Release All Plugins
   "Release all <N> plugins with unreleased changes sequentially — quarantine failures and continue"
```

New template `templates/mode-7-batch-release.md`:

**Step 0 — Plan Presentation:**
Show table of all unreleased plugins with proposed versions (from `suggest-version.sh`). Single gate: "Proceed with batch release of N plugins? → Yes / Abort".

**Step 1-N — Sequential Plugin Releases:**
For each plugin in `unreleased_plugins`:
1. Run Phase 1 (pre-flight) scoped to that plugin
2. If pre-flight FAIL (and not waived) → add to `quarantined` list with reason, **continue to next plugin**
3. Run Phase 2 (prep) + Phase 3 (release) following Mode 3 logic
4. If Phase 2 or 3 fails → quarantine with reason, continue
5. Run Phase 4 (verify) — failure here records a warning but still counts as `succeeded`

**Summary Report (always emitted after all plugins):**

```
BATCH RELEASE REPORT
====================
Succeeded (N):  plugin-a v1.2.0, plugin-b v0.3.1
Failed    (N):  plugin-d v1.1.0 — Phase 1: dirty_working_tree (not waived)
Skipped   (0):  —
```

Exit behavior: if any plugins failed, the report is the only output — no individual failure halts the loop.

---

## Files Changed

### New scripts
- `scripts/reconcile-tags.sh` — tag local/remote diff and auto-fetch
- `scripts/api-retry.sh` — exponential backoff + jitter wrapper for `gh` calls
- `scripts/check-waivers.sh` — waiver lookup against `.release-waivers.json`

### New templates
- `templates/mode-7-batch-release.md` — batch release mode

### Modified
- `scripts/verify-release.sh` — wrap `gh release view` with `api-retry.sh`
- `commands/release.md` — add Mode 7 to menu (monorepo only)
- `templates/mode-2-full-release.md` — Phase 3: reconcile before tag, retry `gh release create`
- `templates/mode-3-plugin-release.md` — Phase 3: reconcile before tag, retry `gh release create`
- `agents/git-preflight.md` — remote tag check + waiver support
- `agents/test-runner.md` — waiver support for `missing_tests`
- `agents/docs-auditor.md` — waiver support for `stale_docs`

### New config (example, not committed to repo)
- `.release-waivers.json` — user creates this at repo root if needed

### Versioning
- Plugin version bumped to `1.6.0` (adds new features)
- CHANGELOG updated
