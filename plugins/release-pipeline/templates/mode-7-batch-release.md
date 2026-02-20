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
