# up-docs Plugin Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address eleven actions from the 2026-05-08 up-docs assessment — fixing one stale README claim, four hygiene defects, four structural gaps (tracker state, Python prereq, security boundary, evidence grounding), and three behavioral improvements (handoff-layout coupling, drift orchestration, Notion fuzzy fallback) — across five sequenced release versions (0.7.2 → 0.8.0 → 0.8.1 → 0.9.0 → optional 0.9.1).

**Architecture:** Five phases of progressively higher leverage. Phase 0 ships hygiene (no behavioral change). Phase 1 hardens helper scripts. Phase 2 establishes a real security boundary via project-level `permissions.deny` (the only definitively enforced layer per GH issue research). Phase 3 builds the eval infrastructure that would have caught both prior production bugs (Pydantic schema validation + transcript-grounded evidence cross-check, fed by a PostToolUse capture hook). Phase 4 loosens hardcoded coupling and improves the agent prompts. Each phase ends with a verification gate; releases happen at gates 0, 2, 3, and 4.

**Tech Stack:** bash + bats (existing test harness), Python 3 with Pydantic v2 (new validators), FastMCP (in-memory MCP stubs), `claude --print --agent --output-format stream-json` (integration test driver), DeepEval (optional opt-in prose-quality grader), GitHub `gh` CLI (smoke-test verification).

**Research baseline:** [`docs/research/2026-05-08-testing-hardening-claude-code-plugin-sub-agents.md`](../research/2026-05-08-testing-hardening-claude-code-plugin-sub-agents.md). Key findings drive specific tasks: Pydantic + transcript-grounding catches both Bug #3 and Bug #4 (Task 12 + 14); FastMCP `Client(server)` is the canonical MCP mock (Task 17); `allowed-tools` in SKILL.md is "working as designed" not a bug, only `permissions.deny` in `settings.json` is enforced (Task 9); `--print --output-format stream-json` captures tool inputs but NOT tool results — PostToolUse hook is mandatory (Task 11).

**Resolved blockers (before plan execution):**

- GH issues #37683 (NOT_PLANNED, stale) and #18837 (DUPLICATE of #14956) confirm `allowed-tools` is intentionally non-restrictive. Phase 2 must use project `settings.json` `permissions.deny` as the enforced layer; agent-frontmatter `disallowedTools:` is best-effort defense in depth gated behind Task 8's smoke test.
- `claude --print --output-format stream-json` emits tool-call inputs as `content_block_*` events but tool RESULTS (Bash stdout, file contents) are consumed internally and never reach stdout. Phase 3's evidence-grounding check reads from a PostToolUse-hook-managed side log, not from the stream.

**Release sequencing:**

| Version          | Phases included                           | Estimated effort |
| ---------------- | ----------------------------------------- | ---------------- |
| 0.7.2 (patch)    | Phase 0                                   | ~1h              |
| 0.8.0 (minor)    | Phase 1 + Phase 2 + Phase 3 (Tasks 11–15) | 6–8h             |
| 0.8.1 (patch)    | Phase 3 (Tasks 16–18 integration tests)   | 3–4h             |
| 0.9.0 (minor)    | Phase 4                                   | 3–5h             |
| 0.9.1 (optional) | Phase 3 Task 19 (DeepEval)                | 1–2h             |

---

## File structure

**New files:**

- `plugins/up-docs/.claude/settings.json` — project-level deny rules + PostToolUse hook config
- `plugins/up-docs/scripts/capture-transcript.sh` — PostToolUse hook script
- `plugins/up-docs/tests/validate_output.py` — Pydantic schema validators for all four agent outputs
- `plugins/up-docs/tests/test_validate_output.py` — pytest self-tests for the validators
- `plugins/up-docs/tests/verify_evidence_grounded.py` — transcript-grounded evidence cross-check
- `plugins/up-docs/tests/test_verify_evidence_grounded.py` — pytest self-tests for the cross-check
- `plugins/up-docs/tests/integration/propagate-notion.bats` — end-to-end Notion propagator test
- `plugins/up-docs/tests/integration/propagate-repo.bats` — end-to-end repo propagator test
- `plugins/up-docs/tests/integration/audit-drift.bats` — end-to-end drift auditor test
- `plugins/up-docs/tests/integration/fixtures/session-summary-config-rebind.md` — canned session summary input
- `plugins/up-docs/tests/integration/fixtures/session-summary-bug-fix.md` — Notion-out-of-scope input
- `plugins/up-docs/tests/integration/fixtures/fabricated-evidence-finding.json` — Bug #4 regression fixture
- `plugins/up-docs/tests/stubs/mcp_outline_stub.py` — FastMCP-based Outline stub
- `plugins/up-docs/tests/stubs/mcp_notion_stub.py` — FastMCP-based Notion stub
- `plugins/up-docs/tests/test_agent_prose.py` — opt-in DeepEval LLM-judge (Task 19, optional)

**Modified files:**

- `plugins/up-docs/README.md` — drop Opus claim, document Python 3 prereq, prune stale Known Issues, document `docs/.up-docs.json` (Phase 4)
- `plugins/up-docs/CHANGELOG.md` — dedupe duplicate 0.3.0 entry; add release entries
- `plugins/up-docs/.claude-plugin/plugin.json` — version bumps (4 times)
- `.claude-plugin/marketplace.json` — version bumps (4 times)
- `plugins/up-docs/scripts/convergence-tracker.sh` — env-overridable STATE_FILE
- `plugins/up-docs/tests/link-audit.bats` — fix nested-bash quote interpolation
- `plugins/up-docs/skills/all/SKILL.md` — Python prereq check; layout-config awareness (Phase 4)
- `plugins/up-docs/skills/repo/SKILL.md` — Python prereq check; layout-config awareness (Phase 4)
- `plugins/up-docs/skills/wiki/SKILL.md` — Python prereq check
- `plugins/up-docs/skills/notion/SKILL.md` — Python prereq check
- `plugins/up-docs/skills/drift/SKILL.md` — Python prereq check; per-phase orchestration loop (Phase 4)
- `plugins/up-docs/agents/up-docs-audit-drift.md` — `disallowedTools:` (Phase 2, conditional)
- `plugins/up-docs/agents/up-docs-propagate-repo.md` — `disallowedTools:` (Phase 2); layout config (Phase 4)
- `plugins/up-docs/agents/up-docs-propagate-wiki.md` — `disallowedTools:` (Phase 2)
- `plugins/up-docs/agents/up-docs-propagate-notion.md` — `disallowedTools:` (Phase 2); fuzzy fallback (Phase 4)

---

## Phase 0 — Hygiene (no behavioral change)

Five small, independently-revertible edits. Each is one task. After all five, bump to v0.7.2 and release.

### Task 1: Drop the stale Opus claim from README

The `up-docs-audit-drift` agent has `model: sonnet` in its frontmatter. README §Known Issues says "Drift analysis is designed for Opus 4.6 with 1M context" — direct contradiction. Replace with truthful text.

**Files:**

- Modify: `plugins/up-docs/README.md` line 140

- [ ] **Step 1: Read the current line for context**

Run: `sed -n '138,142p' plugins/up-docs/README.md` Expected: shows the bullet starting `- Drift analysis is designed for Opus 4.6 with 1M context.`

- [ ] **Step 2: Replace the bullet**

In `plugins/up-docs/README.md`, replace:

```markdown
- Drift analysis is designed for Opus 4.6 with 1M context. Running on smaller context models may cause truncation on large wiki collections.
```

with:

```markdown
- Drift analysis runs on Sonnet by default (`model: sonnet` in `up-docs-audit-drift` frontmatter). The auditor's escalation block flags cases where Opus would help — large affected docs (>1000 lines), >10 findings, or cross-layer contradictions — leaving the user to opt in.
```

- [ ] **Step 3: Verify the change**

Run: `grep -n "Opus" plugins/up-docs/README.md` Expected: only references in escalation context (not the "designed for Opus" claim).

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/README.md
git commit -m "docs(up-docs): correct Opus claim in Known Issues — auditor runs Sonnet by frontmatter"
```

---

### Task 2: Dedupe the CHANGELOG 0.3.0 entry

`grep -n "^## \[" plugins/up-docs/CHANGELOG.md` shows two `## [0.3.0] - 2026-04-09` headers (lines 107 and 121). Each has different bullets. Merge them into a single section preserving every bullet.

**Files:**

- Modify: `plugins/up-docs/CHANGELOG.md` lines 107–133

- [ ] **Step 1: Read both blocks for context**

Run: `sed -n '107,133p' plugins/up-docs/CHANGELOG.md` Expected: shows two `## [0.3.0] - 2026-04-09` headers with different bullet sets.

- [ ] **Step 2: Replace both blocks with a single merged block**

In `plugins/up-docs/CHANGELOG.md`, replace lines 107–133 (both 0.3.0 blocks) with this single merged block:

```markdown
## [0.3.0] - 2026-04-09

### Added

- `scripts/context-gather.sh` consolidating git context assessment for all 5 skills
- `scripts/server-inspect.sh` batching 5-15 SSH commands per host into a single session
- `scripts/link-audit.sh` for markdown link extraction and verification
- `scripts/convergence-tracker.sh` for managing iteration state across drift analysis phases

### Changed

- All 5 skill files (repo, wiki, notion, all, drift) now use context-gather.sh for session context
- `skills/drift/SKILL.md` Phase 1 uses server-inspect.sh and convergence-tracker.sh
- `skills/drift/SKILL.md` Phase 3 uses link-audit.sh for external link verification
- Test pass 3 — close remaining gaps, 293 total tests across 9 plugins
- Close gap analysis findings, 247 total tests across 9 plugins
- Add 166 bats tests across 9 plugins for new scripts

### Fixed

- Add handoff to root README, fix up-docs skill names
```

- [ ] **Step 3: Verify only one 0.3.0 header remains**

Run: `grep -c "^## \[0.3.0\]" plugins/up-docs/CHANGELOG.md` Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/CHANGELOG.md
git commit -m "docs(up-docs): dedupe duplicate 0.3.0 CHANGELOG entry"
```

---

### Task 3: Prune stale v2.1.92 mitigation note

Claude Code v2.1.92 was three releases ago. The mitigation note in README §Known Issues is no longer relevant for current users. Move to a "Resolved" subsection.

**Files:**

- Modify: `plugins/up-docs/README.md` lines 134–141

- [ ] **Step 1: Read the Known Issues block**

Run: `sed -n '134,141p' plugins/up-docs/README.md` Expected: shows the `- **Claude Code version sensitivity (MCP + Haiku):**` bullet.

- [ ] **Step 2: Replace the v2.1.92 bullet**

In `plugins/up-docs/README.md`, find the bullet:

```markdown
- **Claude Code version sensitivity (MCP + Haiku):** Claude Code v2.1.92 had a bug where Haiku's internal title-generation probe could block session-wide MCP tool loading ([anthropics/claude-code#44290](https://github.com/anthropics/claude-code/issues/44290), now closed). On affected versions, `up-docs-propagate-wiki`, `up-docs-propagate-notion`, and `up-docs-audit-drift` may show FAILED rows because their MCP tools never load. Mitigation: upgrade Claude Code past the fix, or fall back to `/up-docs:repo` which uses no MCP tools.
```

and remove it. The bug is fixed in current Claude Code; readers don't need this for active troubleshooting.

- [ ] **Step 3: Verify removal**

Run: `grep -c "v2.1.92" plugins/up-docs/README.md` Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/README.md
git commit -m "docs(up-docs): remove stale v2.1.92 MCP-loading mitigation note"
```

---

### Task 4: Document Python 3 as a hard requirement

All four helper scripts shell out to `python3` and exit 1 with a JSON error when missing. README §Requirements doesn't mention Python.

**Files:**

- Modify: `plugins/up-docs/README.md` lines 19–24

- [ ] **Step 1: Read the Requirements block**

Run: `sed -n '19,24p' plugins/up-docs/README.md` Expected:

```
## Requirements

- Claude Code (any recent version)
- Outline wiki accessible via MCP (mcp-outline server configured)
- Notion accessible via MCP (Notion MCP server configured)
- SSH access to infrastructure hosts (for `/up-docs:drift`)
```

- [ ] **Step 2: Add the Python 3 bullet**

In `plugins/up-docs/README.md`, in §Requirements, add a new bullet at the top of the list:

```markdown
- Python 3.x in `$PATH` (used by all four helper scripts under `scripts/`)
```

The full §Requirements block becomes:

```markdown
## Requirements

- Python 3.x in `$PATH` (used by all four helper scripts under `scripts/`)
- Claude Code (any recent version)
- Outline wiki accessible via MCP (mcp-outline server configured)
- Notion accessible via MCP (Notion MCP server configured)
- SSH access to infrastructure hosts (for `/up-docs:drift`)
```

- [ ] **Step 3: Verify**

Run: `grep -A 6 "^## Requirements" plugins/up-docs/README.md` Expected: includes the Python 3 bullet.

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/README.md
git commit -m "docs(up-docs): document Python 3 as a hard requirement"
```

---

### Task 5: Fix link-audit.bats nested-bash quote interpolation

`tests/link-audit.bats` uses `bash -c "echo '$md' | bash …"` — works for current inputs but corrupts inputs containing single quotes. Hidden trap. Replace with a quote-safe pattern.

**Files:**

- Modify: `plugins/up-docs/tests/link-audit.bats`

- [ ] **Step 1: Write a regression test that proves the current pattern is fragile**

Append to `plugins/up-docs/tests/link-audit.bats`:

```bash
@test "single-quote inputs do not break link extraction" {
    local md="See [O'Reilly](https://oreilly.com) for more."
    run bash -c "printf '%s\n' \"\$1\" | bash \"$SCRIPTS_DIR/link-audit.sh\" -" _ "$md"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.total_links')" -ge 1 ]
}
```

- [ ] **Step 2: Run the test to see it pass with the new safe pattern**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | grep "single-quote"` Expected: `ok N single-quote inputs do not break link extraction`

- [ ] **Step 3: Replace every other test's nested-bash pattern with the same safe form**

Each existing test in the file uses the form `run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"`. Replace with `run bash -c "printf '%s\n' \"\$1\" | bash \"$SCRIPTS_DIR/link-audit.sh\" -" _ "$md"`.

For example, the test "pipe markdown with internal anchor link" — change:

```bash
run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
```

to:

```bash
run bash -c "printf '%s\n' \"\$1\" | bash \"$SCRIPTS_DIR/link-audit.sh\" -" _ "$md"
```

Apply this rewrite to every `run bash -c "echo '$md'` occurrence in the file.

- [ ] **Step 4: Run the full bats suite to confirm no regression**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5` Expected: `35 of 35 tests passed` (was 34, the regression test adds one).

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/tests/link-audit.bats
git commit -m "test(up-docs): quote-safe link-audit invocations; add single-quote regression"
```

---

### Phase 0 checkpoint and v0.7.2 release

- [ ] **Run the full bats suite**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5` Expected: all tests pass (35 total after Task 5).

- [ ] **Bump plugin.json version**

Edit `plugins/up-docs/.claude-plugin/plugin.json`. Change `"version": "0.7.1"` to `"version": "0.7.2"`.

- [ ] **Bump marketplace.json version**

Edit `.claude-plugin/marketplace.json`. Find the `up-docs` plugin entry and change its `"version"` from `"0.7.1"` to `"0.7.2"`.

- [ ] **Add CHANGELOG entry**

In `plugins/up-docs/CHANGELOG.md`, prepend after the `# Changelog` header (above the `## [0.7.1]` block):

```markdown
## [0.7.2] - 2026-05-08

### Fixed

- README "Known Issues" no longer claims drift analysis is "designed for Opus 4.6" — auditor runs Sonnet by frontmatter; Opus is opt-in via the escalation block.
- Stale Claude Code v2.1.92 MCP-loading mitigation note removed.
- Duplicate `## [0.3.0]` CHANGELOG entry merged into one block.
- `tests/link-audit.bats` no longer breaks on inputs containing single quotes; added regression test.

### Added

- README §Requirements now lists Python 3 as a hard prerequisite (used by all four helper scripts).
```

- [ ] **Tag and release**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "Release up-docs v0.7.2 — Phase 0 hygiene"
```

Run `/release-pipeline:release` to push the tag and GitHub release. Verify the release lands.

---

## Phase 1 — Helper-script robustness

### Task 6: Make convergence-tracker state file env-overridable

`scripts/convergence-tracker.sh` hardcodes `/tmp/up-docs-drift-tracker.json` on line 20. Concurrent `/up-docs:drift` runs across different repos collide. Replace with `${UP_DOCS_TRACKER_STATE:-${TMPDIR:-/tmp}/up-docs-drift-tracker-$$.json}`.

**Files:**

- Modify: `plugins/up-docs/scripts/convergence-tracker.sh` line 20
- Modify: `plugins/up-docs/tests/convergence-tracker.bats` setup/teardown

- [ ] **Step 1: Write a failing test for cross-process isolation**

Append to `plugins/up-docs/tests/convergence-tracker.bats`:

```bash
@test "concurrent runs use isolated state files via UP_DOCS_TRACKER_STATE" {
    local state1="$TEST_TMPDIR/run1.json"
    local state2="$TEST_TMPDIR/run2.json"

    UP_DOCS_TRACKER_STATE="$state1" bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    UP_DOCS_TRACKER_STATE="$state1" bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    UP_DOCS_TRACKER_STATE="$state2" bash "$SCRIPTS_DIR/convergence-tracker.sh" init

    # state1 should still have phase 1 started; state2 should be fresh
    run bash -c "UP_DOCS_TRACKER_STATE=\"$state1\" bash \"$SCRIPTS_DIR/convergence-tracker.sh\" status"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "1" ]

    run bash -c "UP_DOCS_TRACKER_STATE=\"$state2\" bash \"$SCRIPTS_DIR/convergence-tracker.sh\" status"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "0" ]
}
```

- [ ] **Step 2: Run the test, confirm it FAILS**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | grep -A 1 "isolated state"` Expected: `not ok N concurrent runs use isolated state files via UP_DOCS_TRACKER_STATE` (because the script ignores the env var and uses the hardcoded path).

- [ ] **Step 3: Modify the script to honor the env var**

In `plugins/up-docs/scripts/convergence-tracker.sh`, replace line 20:

```bash
STATE_FILE="/tmp/up-docs-drift-tracker.json"
```

with:

```bash
STATE_FILE="${UP_DOCS_TRACKER_STATE:-${TMPDIR:-/tmp}/up-docs-drift-tracker-$$.json}"
```

- [ ] **Step 4: Update the existing teardown that hardcodes the old path**

In `plugins/up-docs/tests/convergence-tracker.bats`, replace the existing `setup()` and `teardown()` with:

```bash
setup() {
    setup_test_env
    export UP_DOCS_TRACKER_STATE="$TEST_TMPDIR/tracker-state.json"
}

teardown() {
    unset UP_DOCS_TRACKER_STATE
    teardown_test_env
}
```

- [ ] **Step 5: Run the suite to confirm everything passes**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5` Expected: 36 of 36 tests passed (35 from Phase 0 + 1 new).

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/tests/convergence-tracker.bats
git commit -m "fix(up-docs): tracker state file is env-overridable; isolate per-process by default"
```

---

### Task 7: Add early Python availability check to all five skills

Each skill's Step 1 invokes `bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh`. If python3 is missing, the script emits an opaque JSON error to stderr and exits 1 — the skill doesn't notice. Add an early check.

**Files:**

- Modify: `plugins/up-docs/skills/all/SKILL.md` Step 1
- Modify: `plugins/up-docs/skills/repo/SKILL.md` Step 1
- Modify: `plugins/up-docs/skills/wiki/SKILL.md` Step 1
- Modify: `plugins/up-docs/skills/notion/SKILL.md` Step 1
- Modify: `plugins/up-docs/skills/drift/SKILL.md` Step 1

- [ ] **Step 1: Define the canonical Python check snippet**

Each skill's Step 1 currently looks like:

````markdown
### 1. Gather Session Context

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```
````

Replace with:

````markdown
### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```
````

- [ ] **Step 2: Apply the change to skills/all/SKILL.md**

In `plugins/up-docs/skills/all/SKILL.md`, replace the Step 1 code block as above.

- [ ] **Step 3: Apply the change to skills/repo/SKILL.md**

In `plugins/up-docs/skills/repo/SKILL.md`, replace the Step 1 code block as above.

- [ ] **Step 4: Apply the change to skills/wiki/SKILL.md**

In `plugins/up-docs/skills/wiki/SKILL.md`, replace the Step 1 code block as above.

- [ ] **Step 5: Apply the change to skills/notion/SKILL.md**

In `plugins/up-docs/skills/notion/SKILL.md`, replace the Step 1 code block as above.

- [ ] **Step 6: Apply the change to skills/drift/SKILL.md (Step 1 has two bash invocations — preserve the tracker init)**

In `plugins/up-docs/skills/drift/SKILL.md`, replace the Step 1 block:

````markdown
### 1. Gather Session Context

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh init
```
````

with:

````markdown
### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh init
```
````

- [ ] **Step 7: Verify all five skills got the check**

Run: `grep -l "command -v python3" plugins/up-docs/skills/*/SKILL.md` Expected: lists all five SKILL.md files.

- [ ] **Step 8: Commit**

```bash
git add plugins/up-docs/skills/
git commit -m "feat(up-docs): explicit python3 prereq check at skill Step 1 across all 5 skills"
```

---

## Phase 2 — Security boundary correction

### Task 8: Smoke-test `disallowedTools:` enforcement (gate task)

GH issue research confirms `allowed-tools` is non-restrictive by design. The parallel `disallowedTools:` field on agents is documented but unverified for this use case. Smoke-test before relying on it.

**Files:**

- Create: `/tmp/disallow-test/.claude/agents/test-deny.md` (transient — deleted after test)

- [ ] **Step 1: Create the test agent**

```bash
mkdir -p /tmp/disallow-test/.claude/agents
cat > /tmp/disallow-test/.claude/agents/test-deny.md <<'EOF'
---
name: test-deny
description: Verify disallowedTools enforcement
tools: Bash
disallowedTools: Bash(echo BLOCKED *)
model: haiku
---
You must run `echo BLOCKED test`. If the tool is blocked, report "DENIED". If it succeeds, report the output verbatim.
EOF
```

- [ ] **Step 2: Run the smoke test**

```bash
cd /tmp/disallow-test
echo "Run echo BLOCKED test and report whether it executed" | claude --print --agent test-deny --output-format stream-json 2>&1 | tee /tmp/disallow-smoke.log
```

- [ ] **Step 3: Inspect the result**

Run: `grep -E "BLOCKED test|DENIED|permission" /tmp/disallow-smoke.log | head -5`

Expected outcomes:

- **PASS (the field works):** output contains `DENIED`, or a permission-denied error, or the Bash call is absent from the stream-json events.
- **FAIL (the field is non-functional):** output contains `BLOCKED test` from a successful Bash invocation.

Record the outcome in a comment on this task. The result determines whether Task 10 ships.

- [ ] **Step 4: Clean up**

```bash
rm -rf /tmp/disallow-test /tmp/disallow-smoke.log
```

- [ ] **Step 5: Document the outcome**

Append to `plugins/up-docs/CHANGELOG.md` under the upcoming 0.8.0 §Notes:

```markdown
- Phase 2 smoke test for agent-level `disallowedTools:` field: <PASS or FAIL with one-line evidence>. <If FAIL: project `settings.json` `permissions.deny` is the sole enforced layer; Task 10 skipped. If PASS: Task 10 included as defense in depth.>
```

(The CHANGELOG block is added in the Phase 2 release task; this records the smoke-test result for that block.)

- [ ] **Step 6: Commit a record of the smoke-test result**

If FAIL:

```bash
echo "Phase 2 smoke test: disallowedTools NON-FUNCTIONAL ($(date -I))" >> plugins/up-docs/docs/phase-2-smoke-result.txt
git add plugins/up-docs/docs/phase-2-smoke-result.txt
git commit -m "test(up-docs): record Phase 2 smoke result — disallowedTools non-functional"
```

If PASS, do the same with "FUNCTIONAL".

(This file is referenced from the CHANGELOG and informs Task 10. If the directory `plugins/up-docs/docs/` doesn't exist, create it: `mkdir -p plugins/up-docs/docs`.)

---

### Task 9: Add project-level `settings.json` deny rules (the enforced layer)

Per research, `permissions.deny` in a project-scope `settings.json` is the only definitively enforced layer. Mirror the auditor's `<forbidden_commands>` table into structural rules.

**Files:**

- Create: `plugins/up-docs/.claude/settings.json`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p plugins/up-docs/.claude
```

- [ ] **Step 2: Write the settings.json**

Create `plugins/up-docs/.claude/settings.json`:

```json
{
	"permissions": {
		"deny": [
			"Bash(rm *)",
			"Bash(rmdir *)",
			"Bash(shred *)",
			"Bash(truncate *)",
			"Bash(mv * *)",
			"Bash(git rm *)",
			"Bash(git push --force *)",
			"Bash(git push -f *)",
			"Bash(git reset --hard *)",
			"Bash(pct stop *)",
			"Bash(pct shutdown *)",
			"Bash(pct destroy *)",
			"Bash(pct restore *)",
			"Bash(pct migrate *)",
			"Bash(qm stop *)",
			"Bash(qm destroy *)",
			"Bash(docker stop *)",
			"Bash(docker rm *)",
			"Bash(docker-compose down *)",
			"Bash(systemctl stop *)",
			"Bash(systemctl restart *)",
			"Bash(systemctl disable *)",
			"Bash(systemctl mask *)",
			"Bash(kill *)",
			"Bash(killall *)",
			"Bash(pkill *)",
			"Bash(iptables *)",
			"Bash(nft *)",
			"Bash(chmod *)",
			"Bash(chown *)",
			"Bash(chgrp *)",
			"Bash(chattr *)",
			"Bash(setfacl *)",
			"Bash(apt install *)",
			"Bash(apt remove *)",
			"Bash(dnf install *)",
			"Bash(dnf remove *)",
			"Bash(npm install --save *)",
			"Bash(sed -i *)"
		]
	}
}
```

- [ ] **Step 3: Verify JSON is valid**

Run: `python3 -c "import json; json.load(open('plugins/up-docs/.claude/settings.json'))" && echo "valid"` Expected: `valid`

- [ ] **Step 4: Verify the deny list covers every forbidden verb in the auditor prompt**

The auditor's `<forbidden_commands>` block in `plugins/up-docs/agents/up-docs-audit-drift.md` lists six categories. Confirm each is reflected in the deny list above (it is — filesystem writes, container lifecycle, service control, network/permissions, package edits).

Run: `grep -c "Bash(" plugins/up-docs/.claude/settings.json` Expected: `≥39` (one per pattern; exact count depends on whether you bundled multiple verbs together).

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/.claude/settings.json
git commit -m "feat(up-docs): project-level permissions.deny mirroring auditor forbidden_commands"
```

---

### Task 10: Add `disallowedTools:` to agent frontmatter (conditional on Task 8 PASS)

Skip this task entirely if Task 8 (smoke test) reported FAIL. If it reported PASS, add `disallowedTools:` to all four agents as defense in depth.

**Files:** (only if Task 8 PASS)

- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md` frontmatter
- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md` frontmatter
- Modify: `plugins/up-docs/agents/up-docs-propagate-wiki.md` frontmatter
- Modify: `plugins/up-docs/agents/up-docs-propagate-notion.md` frontmatter

- [ ] **Step 1: Confirm Task 8 outcome**

Run: `cat plugins/up-docs/docs/phase-2-smoke-result.txt` If output contains `NON-FUNCTIONAL`: skip the rest of Task 10. Mark all remaining steps as done and move to Phase 2 checkpoint. If output contains `FUNCTIONAL`: proceed.

- [ ] **Step 2: Define the canonical denylist for propagators**

Propagators need `Bash` for `python3 docs/handoff/bugs/_regen_index.py` (propagate-repo only) but should not delete or push. The denylist:

```
disallowedTools: Bash(rm *), Bash(git rm *), Bash(git push --force *), Bash(git push -f *), Bash(systemctl *), Bash(pct *), Bash(docker *)
```

- [ ] **Step 3: Add to up-docs-propagate-repo.md frontmatter**

In `plugins/up-docs/agents/up-docs-propagate-repo.md`, modify the frontmatter block (lines 1–6). After the `tools:` line, add a `disallowedTools:` line:

```yaml
---
name: up-docs-propagate-repo
description: Propagates named session changes into repository documentation (README.md, docs/, CLAUDE.md, .claude/rules/). Never performs drift detection. Never edits anything not in the session change summary.
tools: Read, Edit, Write, Glob, Grep, Bash
disallowedTools: Bash(rm *), Bash(git rm *), Bash(git push --force *), Bash(git push -f *), Bash(systemctl *), Bash(pct *), Bash(docker *)
model: haiku
---
```

- [ ] **Step 4: Add to up-docs-propagate-wiki.md frontmatter**

In `plugins/up-docs/agents/up-docs-propagate-wiki.md`, after the `tools:` line, insert:

```yaml
disallowedTools: Bash(rm *), Bash(git rm *), Bash(git push *), Bash(systemctl *), Bash(pct *), Bash(docker *)
```

- [ ] **Step 5: Add to up-docs-propagate-notion.md frontmatter**

In `plugins/up-docs/agents/up-docs-propagate-notion.md`, after the `tools:` line, insert:

```yaml
disallowedTools: Bash(rm *), Bash(git rm *), Bash(git push *), Bash(systemctl *), Bash(pct *), Bash(docker *)
```

- [ ] **Step 6: Add to up-docs-audit-drift.md frontmatter (the heavy denylist — auditor has SSH access)**

In `plugins/up-docs/agents/up-docs-audit-drift.md`, after the `tools:` line, insert:

```yaml
disallowedTools: Bash(rm *), Bash(rmdir *), Bash(shred *), Bash(truncate *), Bash(mv * *), Bash(git rm *), Bash(git push *), Bash(pct stop *), Bash(pct shutdown *), Bash(pct destroy *), Bash(qm *), Bash(docker stop *), Bash(docker rm *), Bash(systemctl stop *), Bash(systemctl restart *), Bash(systemctl disable *), Bash(kill *), Bash(killall *), Bash(pkill *), Bash(iptables *), Bash(chmod *), Bash(chown *), Bash(sed -i *), Bash(apt install *), Bash(dnf install *)
```

- [ ] **Step 7: Verify all four agents have the field**

Run: `grep -l "^disallowedTools:" plugins/up-docs/agents/*.md` Expected: lists all four `up-docs-*.md` files.

- [ ] **Step 8: Commit**

```bash
git add plugins/up-docs/agents/
git commit -m "feat(up-docs): defense-in-depth disallowedTools on all four agents (Task 8 PASS)"
```

---

### Phase 2 checkpoint (release with Phase 1 + Phase 3 as v0.8.0)

Phase 2 ships as part of v0.8.0 alongside Phase 1 and Phase 3 Tasks 11–15. Verification gate at the v0.8.0 release task (after Task 15).

---

## Phase 3 — Eval infrastructure

The highest-leverage phase. After 3A (the PostToolUse hook), 3B (Pydantic validators), and 3C (transcript-grounding) are in place, both prior production bugs (Bug #3 namespace, Bug #4 fabrication) become structurally impossible to ship.

### Task 11: PostToolUse hook + capture-transcript.sh

The hook captures every tool_input/tool_result JSON pair to a side log because `--print --output-format stream-json` does NOT include tool results in stdout (per Q2 research finding).

**Files:**

- Create: `plugins/up-docs/scripts/capture-transcript.sh`
- Modify: `plugins/up-docs/.claude/settings.json` (add `hooks` block)

- [ ] **Step 1: Write the hook script**

Create `plugins/up-docs/scripts/capture-transcript.sh`:

```bash
#!/usr/bin/env bash
# capture-transcript.sh — PostToolUse hook for up-docs evidence-grounding tests.
#
# Receives JSON on stdin per Claude Code hook contract:
#   {"tool_name": "Bash", "tool_input": {...}, "tool_response": "..."}
# Appends one JSON line per invocation to ${UP_DOCS_TRANSCRIPT_LOG} (default
# /tmp/up-docs-transcript-$$.log). Read by tests/verify_evidence_grounded.py.
#
# Exit: 0 always (hooks must not block tool execution on capture failure).

set -u
LOG="${UP_DOCS_TRANSCRIPT_LOG:-/tmp/up-docs-transcript-$$.log}"

# Read the entire stdin payload safely
PAYLOAD=$(cat)

# Append as one JSONL line — fail open (don't break the hook on disk error)
{
  printf '%s\n' "$PAYLOAD" >> "$LOG"
} 2>/dev/null || true

exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x plugins/up-docs/scripts/capture-transcript.sh
```

- [ ] **Step 3: Add the hook config to settings.json**

In `plugins/up-docs/.claude/settings.json`, expand the file to include both `permissions.deny` (from Task 9) and the new `hooks` block. Final content:

```json
{
	"permissions": {
		"deny": [
			"Bash(rm *)",
			"Bash(rmdir *)",
			"Bash(shred *)",
			"Bash(truncate *)",
			"Bash(mv * *)",
			"Bash(git rm *)",
			"Bash(git push --force *)",
			"Bash(git push -f *)",
			"Bash(git reset --hard *)",
			"Bash(pct stop *)",
			"Bash(pct shutdown *)",
			"Bash(pct destroy *)",
			"Bash(pct restore *)",
			"Bash(pct migrate *)",
			"Bash(qm stop *)",
			"Bash(qm destroy *)",
			"Bash(docker stop *)",
			"Bash(docker rm *)",
			"Bash(docker-compose down *)",
			"Bash(systemctl stop *)",
			"Bash(systemctl restart *)",
			"Bash(systemctl disable *)",
			"Bash(systemctl mask *)",
			"Bash(kill *)",
			"Bash(killall *)",
			"Bash(pkill *)",
			"Bash(iptables *)",
			"Bash(nft *)",
			"Bash(chmod *)",
			"Bash(chown *)",
			"Bash(chgrp *)",
			"Bash(chattr *)",
			"Bash(setfacl *)",
			"Bash(apt install *)",
			"Bash(apt remove *)",
			"Bash(dnf install *)",
			"Bash(dnf remove *)",
			"Bash(npm install --save *)",
			"Bash(sed -i *)"
		]
	},
	"hooks": {
		"PostToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "${CLAUDE_PLUGIN_ROOT}/scripts/capture-transcript.sh"
					}
				]
			},
			{
				"matcher": "Read",
				"hooks": [
					{
						"type": "command",
						"command": "${CLAUDE_PLUGIN_ROOT}/scripts/capture-transcript.sh"
					}
				]
			}
		]
	}
}
```

- [ ] **Step 4: Smoke-test the hook locally**

```bash
export UP_DOCS_TRANSCRIPT_LOG=/tmp/hook-smoke.log
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":"hi\n"}' \
  | bash plugins/up-docs/scripts/capture-transcript.sh
cat "$UP_DOCS_TRANSCRIPT_LOG"
```

Expected: the log file exists and contains the JSON line just piped in.

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/scripts/capture-transcript.sh plugins/up-docs/.claude/settings.json
git commit -m "feat(up-docs): PostToolUse capture hook for evidence-grounding tests"
```

---

### Task 12: Pydantic output schema validators (the Bug-#4 prevention layer)

Schema validation catches structural fabrication: invented `evidence` keys, wrong `confidence` enum values, IPv4 leaks into Notion output.

**Files:**

- Create: `plugins/up-docs/tests/validate_output.py`

- [ ] **Step 1: Confirm pydantic is available**

Run: `python3 -c "import pydantic; print(pydantic.VERSION)" 2>&1 || pip install --user pydantic` Expected: prints a version `>=2.0.0`. If not, install: `pip install --user pydantic`.

- [ ] **Step 2: Write the validator module**

Create `plugins/up-docs/tests/validate_output.py`:

```python
"""Validate up-docs sub-agent output against canonical schemas.

Usage:
    python3 validate_output.py <agent-name> < agent_output.json

Agent names accepted:
    up-docs-propagate-repo
    up-docs-propagate-wiki
    up-docs-propagate-notion
    up-docs-audit-drift

Exit:
    0 = output is valid against the schema and all invariants
    1 = schema or invariant violation (error written to stderr)
    2 = unknown agent name or malformed JSON input
"""
from __future__ import annotations
import json
import re
import sys
from typing import Literal

from pydantic import BaseModel, ConfigDict, ValidationError, field_validator

IPV4_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


class Row(BaseModel):
    model_config = ConfigDict(extra="forbid")
    n: int
    target: str
    action: Literal["Created", "Updated", "No change needed", "FAILED"]
    summary: str


class Totals(BaseModel):
    model_config = ConfigDict(extra="forbid")
    updated: int
    created: int
    unchanged: int
    failed: int


class PropagatorReport(BaseModel):
    model_config = ConfigDict(extra="forbid")
    layer: Literal["repo", "wiki", "notion"]
    rows: list[Row]
    totals: Totals


class NotionReport(PropagatorReport):
    @field_validator("rows")
    @classmethod
    def no_ipv4_in_summary(cls, v: list[Row]) -> list[Row]:
        for row in v:
            if IPV4_RE.search(row.summary):
                raise ValueError(
                    f"IPv4 leaked into Notion summary for row {row.n}: {row.summary!r}"
                )
        return v

    @field_validator("layer")
    @classmethod
    def layer_must_be_notion(cls, v: str) -> str:
        if v != "notion":
            raise ValueError(f"NotionReport.layer must be 'notion', got {v!r}")
        return v


class Finding(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: int
    layer: Literal["repo", "wiki", "notion"]
    page: str
    page_id: str | None
    stale_line: str
    should_say: str
    confidence: Literal["high", "medium", "low", "unverifiable"]
    destructive_fix: bool
    evidence: str

    @field_validator("evidence")
    @classmethod
    def evidence_format(cls, v: str, info) -> str:
        confidence = info.data.get("confidence")
        if confidence == "unverifiable" and v and not v.startswith("Command failed:"):
            raise ValueError(
                "When confidence='unverifiable', evidence must start with 'Command failed:'"
            )
        return v


class Escalation(BaseModel):
    model_config = ConfigDict(extra="forbid")
    triggered: bool
    reasons: list[str]


class StatsByLayer(BaseModel):
    model_config = ConfigDict(extra="forbid")
    repo: int
    wiki: int
    notion: int


class Stats(BaseModel):
    model_config = ConfigDict(extra="forbid")
    total_findings: int
    by_layer: StatsByLayer
    high_confidence: int
    unverifiable: int
    destructive_fixes_required: int


class AuditorReport(BaseModel):
    model_config = ConfigDict(extra="forbid")
    findings: list[Finding]
    escalation: Escalation
    stats: Stats

    @field_validator("stats")
    @classmethod
    def stats_consistency(cls, v: Stats, info) -> Stats:
        findings = info.data.get("findings", [])
        if v.total_findings != len(findings):
            raise ValueError(
                f"stats.total_findings ({v.total_findings}) != len(findings) ({len(findings)})"
            )
        return v


VALIDATORS: dict[str, type[BaseModel]] = {
    "up-docs-propagate-repo": PropagatorReport,
    "up-docs-propagate-wiki": PropagatorReport,
    "up-docs-propagate-notion": NotionReport,
    "up-docs-audit-drift": AuditorReport,
}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_output.py <agent-name> < output.json", file=sys.stderr)
        return 2
    agent = sys.argv[1]
    cls = VALIDATORS.get(agent)
    if cls is None:
        print(f"Unknown agent: {agent}", file=sys.stderr)
        return 2
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Malformed JSON input: {e}", file=sys.stderr)
        return 2
    try:
        cls.model_validate(payload)
    except ValidationError as e:
        print(f"INVALID ({agent}): {e}", file=sys.stderr)
        return 1
    print(f"VALID ({agent})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Smoke-test against a hand-crafted invalid input**

```bash
echo '{"layer":"notion","rows":[{"n":1,"target":"X","action":"Updated","summary":"Set IP to 192.168.1.5"}],"totals":{"updated":1,"created":0,"unchanged":0,"failed":0}}' \
  | python3 plugins/up-docs/tests/validate_output.py up-docs-propagate-notion
```

Expected: exit 1, stderr contains `IPv4 leaked into Notion summary`.

- [ ] **Step 4: Smoke-test against a valid input**

```bash
echo '{"layer":"notion","rows":[{"n":1,"target":"OpenBao","action":"Updated","summary":"Listener rebound for Tailscale reachability."}],"totals":{"updated":1,"created":0,"unchanged":0,"failed":0}}' \
  | python3 plugins/up-docs/tests/validate_output.py up-docs-propagate-notion
```

Expected: exit 0, stdout `VALID (up-docs-propagate-notion)`.

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/tests/validate_output.py
git commit -m "feat(up-docs): Pydantic schema validators for all four agent outputs"
```

---

### Task 13: Pytest self-tests for the validators

Validators that aren't tested are validators we don't trust. Cover the Bug #4 regression path explicitly.

**Files:**

- Create: `plugins/up-docs/tests/test_validate_output.py`

- [ ] **Step 1: Confirm pytest is available**

Run: `python3 -m pytest --version 2>&1` Expected: pytest version printed. If not, `pip install --user pytest`.

- [ ] **Step 2: Write the test module**

Create `plugins/up-docs/tests/test_validate_output.py`:

```python
"""Self-tests for tests/validate_output.py."""
from __future__ import annotations
import json
import sys
from pathlib import Path

import pytest
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).parent))
from validate_output import (
    AuditorReport,
    Finding,
    NotionReport,
    PropagatorReport,
    VALIDATORS,
)


VALID_PROPAGATOR = {
    "layer": "repo",
    "rows": [{"n": 1, "target": "README.md", "action": "Updated", "summary": "Added flag"}],
    "totals": {"updated": 1, "created": 0, "unchanged": 0, "failed": 0},
}

VALID_NOTION = {
    "layer": "notion",
    "rows": [{"n": 1, "target": "OpenBao", "action": "Updated", "summary": "Listener rebound."}],
    "totals": {"updated": 1, "created": 0, "unchanged": 0, "failed": 0},
}

VALID_AUDITOR = {
    "findings": [
        {
            "id": 1,
            "layer": "wiki",
            "page": "OpenBao",
            "page_id": "abc",
            "stale_line": "BAO_ADDR=127.0.0.1",
            "should_say": "BAO_ADDR=100.90.121.89",
            "confidence": "high",
            "destructive_fix": False,
            "evidence": "ssh gmk 'grep BAO_ADDR /usr/local/bin/backup.sh' returned new value",
        }
    ],
    "escalation": {"triggered": False, "reasons": []},
    "stats": {
        "total_findings": 1,
        "by_layer": {"repo": 0, "wiki": 1, "notion": 0},
        "high_confidence": 1,
        "unverifiable": 0,
        "destructive_fixes_required": 0,
    },
}


def test_valid_propagator_passes():
    PropagatorReport.model_validate(VALID_PROPAGATOR)


def test_valid_notion_passes():
    NotionReport.model_validate(VALID_NOTION)


def test_valid_auditor_passes():
    AuditorReport.model_validate(VALID_AUDITOR)


def test_propagator_rejects_unknown_action():
    bad = json.loads(json.dumps(VALID_PROPAGATOR))
    bad["rows"][0]["action"] = "Frobnicated"
    with pytest.raises(ValidationError):
        PropagatorReport.model_validate(bad)


def test_propagator_rejects_extra_top_level_field():
    bad = json.loads(json.dumps(VALID_PROPAGATOR))
    bad["spurious"] = "extra"
    with pytest.raises(ValidationError):
        PropagatorReport.model_validate(bad)


def test_notion_rejects_ipv4_in_summary():
    """Bug #4-class regression: IPv4 must never leak into Notion."""
    bad = json.loads(json.dumps(VALID_NOTION))
    bad["rows"][0]["summary"] = "Listener bound to 100.90.121.89"
    with pytest.raises(ValidationError, match="IPv4 leaked"):
        NotionReport.model_validate(bad)


def test_notion_rejects_wrong_layer():
    bad = json.loads(json.dumps(VALID_NOTION))
    bad["layer"] = "repo"
    with pytest.raises(ValidationError):
        NotionReport.model_validate(bad)


def test_auditor_rejects_unknown_confidence():
    bad = json.loads(json.dumps(VALID_AUDITOR))
    bad["findings"][0]["confidence"] = "highish"
    with pytest.raises(ValidationError):
        AuditorReport.model_validate(bad)


def test_auditor_rejects_stats_mismatch():
    """Catches reports where stats.total_findings disagrees with len(findings)."""
    bad = json.loads(json.dumps(VALID_AUDITOR))
    bad["stats"]["total_findings"] = 5  # but only 1 finding
    with pytest.raises(ValidationError, match="total_findings"):
        AuditorReport.model_validate(bad)


def test_auditor_unverifiable_must_have_command_failed_evidence():
    bad = json.loads(json.dumps(VALID_AUDITOR))
    bad["findings"][0]["confidence"] = "unverifiable"
    bad["findings"][0]["evidence"] = "Probably failed; not sure."
    with pytest.raises(ValidationError, match="Command failed:"):
        AuditorReport.model_validate(bad)


def test_validators_cover_all_four_agent_names():
    expected = {
        "up-docs-propagate-repo",
        "up-docs-propagate-wiki",
        "up-docs-propagate-notion",
        "up-docs-audit-drift",
    }
    assert set(VALIDATORS) == expected
```

- [ ] **Step 3: Run the tests**

Run: `cd plugins/up-docs && python3 -m pytest tests/test_validate_output.py -v 2>&1 | tail -20` Expected: 11 tests passed.

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/tests/test_validate_output.py
git commit -m "test(up-docs): self-tests for output validators incl. Bug #4 IPv4-leak regression"
```

---

### Task 14: Transcript-grounded evidence cross-check

Reads the auditor's report (JSON) and the captured transcript log (JSONL from Task 11's hook) and asserts every `evidence` field signature appears in actual tool output.

**Files:**

- Create: `plugins/up-docs/tests/verify_evidence_grounded.py`

- [ ] **Step 1: Write the script**

Create `plugins/up-docs/tests/verify_evidence_grounded.py`:

```python
"""Verify every `evidence` field in an auditor report appears in the captured transcript.

Usage:
    python3 verify_evidence_grounded.py <auditor-report.json> <transcript.jsonl>

Exit:
    0 = every non-unverifiable finding's evidence has a substring in the transcript
    1 = at least one fabrication detected (details printed to stdout as JSON)
    2 = bad arguments or malformed input
"""
from __future__ import annotations
import json
import sys


def evidence_signature(evidence: str) -> str:
    """Extract a short, distinctive signature from an evidence string.

    The auditor format is typically "<command> returned <observation>" or
    "Command failed: <error>". We take the chunk after the first colon
    (or the whole thing if no colon), trimmed to 40 chars — enough to be
    distinctive but short enough to survive minor formatting differences.
    """
    sig = evidence.split(":", 1)[-1].strip()
    return sig[:40]


def load_transcript(path: str) -> str:
    """Concatenate all tool_input commands and tool_response payloads."""
    chunks: list[str] = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            tool_input = rec.get("tool_input", {})
            if isinstance(tool_input, dict):
                chunks.append(json.dumps(tool_input))
            tool_response = rec.get("tool_response")
            if tool_response is not None:
                chunks.append(str(tool_response))
    return "\n".join(chunks)


def verify(report_path: str, transcript_path: str) -> int:
    with open(report_path) as f:
        report = json.load(f)
    transcript = load_transcript(transcript_path)
    violations = []
    for finding in report.get("findings", []):
        if finding.get("confidence") == "unverifiable":
            continue  # by-contract: evidence is the error text, not in transcript
        ev = finding.get("evidence", "")
        if not ev:
            continue  # low-confidence findings may have empty evidence
        sig = evidence_signature(ev)
        if sig and sig not in transcript:
            violations.append(
                {
                    "finding_id": finding.get("id"),
                    "missing_signature": sig,
                    "full_evidence": ev,
                }
            )
    if violations:
        print(json.dumps({"fabrications": violations}, indent=2))
        return 1
    print("evidence grounded")
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: verify_evidence_grounded.py <report.json> <transcript.jsonl>",
            file=sys.stderr,
        )
        return 2
    return verify(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Smoke-test against the Bug #4 fabrication scenario**

```bash
# Fabricated finding: claims to have read version.txt, but no transcript supports it
cat > /tmp/fab-report.json <<'EOF'
{
  "findings": [{
    "id": 1, "layer": "wiki", "page": "Hermes", "page_id": "x",
    "stale_line": "Hermes v0.8.0", "should_say": "Hermes v1.0.0",
    "confidence": "high", "destructive_fix": false,
    "evidence": "ssh hetzner 'cat /home/hermes/version.txt' returned 1.0.0"
  }],
  "escalation": {"triggered": false, "reasons": []},
  "stats": {"total_findings": 1, "by_layer":{"repo":0,"wiki":1,"notion":0},
            "high_confidence":1, "unverifiable":0, "destructive_fixes_required":0}
}
EOF

# Transcript: only contains a `pct list` call — no version.txt cat
cat > /tmp/fab-transcript.jsonl <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"ssh hetzner 'pct list'"},"tool_response":"VMID  NAME\n113   hermes-prod"}
EOF

python3 plugins/up-docs/tests/verify_evidence_grounded.py /tmp/fab-report.json /tmp/fab-transcript.jsonl
```

Expected: exit 1, output JSON containing `"fabrications"` array.

- [ ] **Step 3: Smoke-test against grounded evidence**

```bash
# Add the matching command to the transcript
cat > /tmp/grounded-transcript.jsonl <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"ssh hetzner 'cat /home/hermes/version.txt'"},"tool_response":"1.0.0\n"}
EOF
python3 plugins/up-docs/tests/verify_evidence_grounded.py /tmp/fab-report.json /tmp/grounded-transcript.jsonl
```

Expected: exit 0, stdout `evidence grounded`.

- [ ] **Step 4: Clean up**

```bash
rm -f /tmp/fab-report.json /tmp/fab-transcript.jsonl /tmp/grounded-transcript.jsonl
```

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/tests/verify_evidence_grounded.py
git commit -m "feat(up-docs): transcript-grounded evidence verifier (Bug #4 prevention)"
```

---

### Task 15: Pytest self-tests for the evidence verifier

**Files:**

- Create: `plugins/up-docs/tests/test_verify_evidence_grounded.py`

- [ ] **Step 1: Write the test module**

Create `plugins/up-docs/tests/test_verify_evidence_grounded.py`:

```python
"""Self-tests for verify_evidence_grounded.py."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).parent / "verify_evidence_grounded.py"


def run_verify(tmp_path, report: dict, transcript_lines: list[dict]) -> tuple[int, str]:
    rp = tmp_path / "report.json"
    tp = tmp_path / "transcript.jsonl"
    rp.write_text(json.dumps(report))
    tp.write_text("\n".join(json.dumps(rec) for rec in transcript_lines) + "\n")
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), str(rp), str(tp)],
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout


BASE_REPORT = {
    "findings": [],
    "escalation": {"triggered": False, "reasons": []},
    "stats": {
        "total_findings": 0,
        "by_layer": {"repo": 0, "wiki": 0, "notion": 0},
        "high_confidence": 0,
        "unverifiable": 0,
        "destructive_fixes_required": 0,
    },
}


def make_finding(evidence: str, confidence: str = "high") -> dict:
    return {
        "id": 1,
        "layer": "wiki",
        "page": "Test",
        "page_id": "x",
        "stale_line": "old",
        "should_say": "new",
        "confidence": confidence,
        "destructive_fix": False,
        "evidence": evidence,
    }


def test_empty_report_passes(tmp_path):
    rc, out = run_verify(tmp_path, BASE_REPORT, [])
    assert rc == 0
    assert "grounded" in out


def test_grounded_evidence_passes(tmp_path):
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh gmk 'grep BAO_ADDR /etc/foo' returned 100.90.121.89"
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_input": {"command": "ssh gmk 'grep BAO_ADDR /etc/foo'"},
        "tool_response": " grep BAO_ADDR /etc/foo returned 100.90.121.89",
    }]
    rc, _ = run_verify(tmp_path, report, transcript)
    assert rc == 0


def test_fabricated_evidence_fails(tmp_path):
    """Bug #4 regression: invented version.txt cat with no transcript support."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "cat /home/hermes/version.txt returned 1.0.0"
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_input": {"command": "pct list"},
        "tool_response": "VMID NAME\n113 hermes",
    }]
    rc, out = run_verify(tmp_path, report, transcript)
    assert rc == 1
    parsed = json.loads(out)
    assert parsed["fabrications"][0]["finding_id"] == 1


def test_unverifiable_findings_skipped(tmp_path):
    """Findings with confidence='unverifiable' carry the error text in evidence,
    not transcript-derived strings, so they must not be cross-checked."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "Command failed: cat: /no/such/file: No such file or directory",
        confidence="unverifiable",
    )]}
    transcript = []  # no matching transcript
    rc, _ = run_verify(tmp_path, report, transcript)
    assert rc == 0  # unverifiable findings pass without transcript match


def test_low_confidence_with_empty_evidence_passes(tmp_path):
    """Low-confidence findings may have empty evidence (host unreachable case)."""
    report = {**BASE_REPORT, "findings": [make_finding("", confidence="low")]}
    rc, _ = run_verify(tmp_path, report, [])
    assert rc == 0


def test_malformed_transcript_lines_are_skipped(tmp_path):
    """A garbled transcript line must not crash the verifier."""
    rp = tmp_path / "report.json"
    tp = tmp_path / "transcript.jsonl"
    rp.write_text(json.dumps({**BASE_REPORT, "findings": [make_finding(
        "ssh gmk 'echo hi' returned hi"
    )]}))
    tp.write_text(
        'not-valid-json\n'
        + json.dumps({"tool_name": "Bash", "tool_input": {"command": "ssh gmk 'echo hi'"},
                      "tool_response": "echo hi returned hi"}) + "\n"
    )
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), str(rp), str(tp)],
        capture_output=True, text=True,
    )
    assert proc.returncode == 0
```

- [ ] **Step 2: Run the tests**

Run: `cd plugins/up-docs && python3 -m pytest tests/test_verify_evidence_grounded.py -v 2>&1 | tail -15` Expected: 6 tests passed.

- [ ] **Step 3: Commit**

```bash
git add plugins/up-docs/tests/test_verify_evidence_grounded.py
git commit -m "test(up-docs): self-tests for evidence-grounding verifier"
```

---

### Phase 1 + Phase 2 + Phase 3 (Tasks 11–15) checkpoint and v0.8.0 release

- [ ] **Run the bats suite + new pytest suites**

```bash
bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -3
cd plugins/up-docs && python3 -m pytest tests/test_validate_output.py tests/test_verify_evidence_grounded.py 2>&1 | tail -5
```

Expected: bats 36/36 pass; pytest 17 passed total.

- [ ] **Bump plugin.json to 0.8.0**

Edit `plugins/up-docs/.claude-plugin/plugin.json`. Change `"version": "0.7.2"` to `"version": "0.8.0"`.

- [ ] **Bump marketplace.json to 0.8.0**

Edit `.claude-plugin/marketplace.json`. Change up-docs `"version"` to `"0.8.0"`.

- [ ] **Add CHANGELOG entry**

In `plugins/up-docs/CHANGELOG.md`, prepend below `# Changelog`:

```markdown
## [0.8.0] - 2026-MM-DD

### Added

- Project-level `permissions.deny` in `plugins/up-docs/.claude/settings.json` — the only definitively enforced security boundary per GH issues #37683 / #18837 (`allowed-tools` is intentionally non-restrictive). Mirrors the auditor's `<forbidden_commands>` table.
- `scripts/capture-transcript.sh` PostToolUse hook captures every Bash and Read tool_input/tool_response to `${UP_DOCS_TRANSCRIPT_LOG}` — required because `--print --output-format stream-json` does NOT emit tool results in stdout.
- `tests/validate_output.py` — Pydantic schema validators for all four agent outputs. NotionReport rejects IPv4 leaks (Bug #4 class regression).
- `tests/test_validate_output.py` — 11 self-tests for the validators.
- `tests/verify_evidence_grounded.py` — cross-checks every non-unverifiable finding's `evidence` substring against the transcript log.
- `tests/test_verify_evidence_grounded.py` — 6 self-tests including a Bug #4 regression scenario.
- `UP_DOCS_TRACKER_STATE` env var override on `convergence-tracker.sh` — concurrent `/up-docs:drift` runs no longer collide on `/tmp`.
- Explicit `command -v python3` precondition check at Step 1 of all five skills.

### Notes

- Phase 2 smoke test for agent-level `disallowedTools:` field: <PASS or FAIL outcome from Task 8 — fill in at release time>.
```

- [ ] **Tag and release**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "Release up-docs v0.8.0 — security boundary + eval infrastructure"
```

Run `/release-pipeline:release`.

---

### Task 16: Integration test fixtures

Canned session-summary inputs for the integration tests in Task 18.

**Files:**

- Create: `plugins/up-docs/tests/integration/fixtures/session-summary-config-rebind.md`
- Create: `plugins/up-docs/tests/integration/fixtures/session-summary-bug-fix.md`
- Create: `plugins/up-docs/tests/integration/fixtures/fabricated-evidence-finding.json`

- [ ] **Step 1: Create the directory structure**

```bash
mkdir -p plugins/up-docs/tests/integration/fixtures
```

- [ ] **Step 2: Write the config-rebind fixture**

Create `plugins/up-docs/tests/integration/fixtures/session-summary-config-rebind.md`:

```markdown
# Session Change Summary

**Session scope:** OpenBao listener rebind for Tailscale reachability.

**Source signals:**

- context-gather.sh: branch=main, 1 commit, 1 file touched
- Conversation: rebound BAO_ADDR on CT 111

## Changes

### 1. OpenBao listener rebind

- **Change:** `BAO_ADDR=127.0.0.1` → `100.90.121.89` in `/usr/local/bin/backup-dumps.sh` on CT 111
- **Reason:** listener reconfigured for Tailscale reachability (incident 2026-04-17)
- **Affected area:** GMK OpenBao
- **Files touched:** /usr/local/bin/backup-dumps.sh
- **Verifiable against:** `ssh gmk 'pct exec 111 -- bao status -address=http://100.90.121.89:8200'`
```

- [ ] **Step 3: Write the bug-fix fixture (Notion-out-of-scope test case)**

Create `plugins/up-docs/tests/integration/fixtures/session-summary-bug-fix.md`:

```markdown
# Session Change Summary

**Session scope:** Off-by-one fix in sync state machine.

**Source signals:**

- context-gather.sh: branch=main, 1 commit, 1 file touched
- Conversation: fixed sync_repo() ahead-count bug

## Changes

### 1. Bug fix: off-by-one in sync state machine

- **Change:** fixed `sync_repo()` state transition at line 142 in `projects.sh`
- **Reason:** ahead-count was off by 1 on divergent branches
- **Affected area:** sync subcommand
- **Files touched:** projects.sh
- **Verifiable against:** `bats _tests/sync.bats`
```

- [ ] **Step 4: Write the fabricated-finding fixture (Bug #4 regression input)**

Create `plugins/up-docs/tests/integration/fixtures/fabricated-evidence-finding.json`:

```json
{
	"findings": [
		{
			"id": 1,
			"layer": "wiki",
			"page": "LLM Infrastructure",
			"page_id": "jkl-012",
			"stale_line": "Hermes v0.8.0",
			"should_say": "Hermes v1.0.0",
			"confidence": "high",
			"destructive_fix": false,
			"evidence": "ssh hetzner 'pct exec 113 -- cat /home/hermes/hermes-agent/version.txt' returned '1.0.0'"
		}
	],
	"escalation": { "triggered": false, "reasons": [] },
	"stats": {
		"total_findings": 1,
		"by_layer": { "repo": 0, "wiki": 1, "notion": 0 },
		"high_confidence": 1,
		"unverifiable": 0,
		"destructive_fixes_required": 0
	}
}
```

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/tests/integration/fixtures/
git commit -m "test(up-docs): integration test fixtures incl. Bug #4 fabrication regression input"
```

---

### Task 17: FastMCP-based MCP stub servers

Reproducible MCP responses for Outline and Notion without hitting real endpoints. Per research footgun: any stdout chatter from a stub corrupts the JSON-RPC stream — all logging MUST go to stderr.

**Files:**

- Create: `plugins/up-docs/tests/stubs/mcp_outline_stub.py`
- Create: `plugins/up-docs/tests/stubs/mcp_notion_stub.py`

- [ ] **Step 1: Confirm fastmcp is available**

Run: `python3 -c "import fastmcp; print(fastmcp.__version__)" 2>&1 || pip install --user fastmcp` Expected: prints a fastmcp version. If not, install with the fallback command.

- [ ] **Step 2: Create the stubs directory**

```bash
mkdir -p plugins/up-docs/tests/stubs
```

- [ ] **Step 3: Write the Outline stub**

Create `plugins/up-docs/tests/stubs/mcp_outline_stub.py`:

```python
"""FastMCP-based Outline stub for integration tests.

Responses are keyed off OUTLINE_FIXTURE env var:
    empty            → no documents
    openbao          → one OpenBao page returned by search_documents
    backup-pipeline  → both OpenBao and Backup Pipeline pages

CRITICAL: never write to stdout — that corrupts the JSON-RPC stream.
All logging goes to stderr.
"""
from __future__ import annotations
import os
import sys
from typing import Any

from fastmcp import FastMCP

mcp = FastMCP("outline-stub")

FIXTURES: dict[str, list[dict[str, Any]]] = {
    "empty": [],
    "openbao": [
        {"id": "abc-123", "title": "OpenBao — CT 111",
         "text": "BAO_ADDR=127.0.0.1:8200 is the listener address."}
    ],
    "backup-pipeline": [
        {"id": "abc-123", "title": "OpenBao — CT 111",
         "text": "BAO_ADDR=127.0.0.1:8200 is the listener address."},
        {"id": "def-456", "title": "Backup Pipeline",
         "text": "Run curl http://127.0.0.1:8200/v1/sys/health to verify."}
    ],
}


def fixture() -> list[dict[str, Any]]:
    return FIXTURES.get(os.environ.get("OUTLINE_FIXTURE", "empty"), [])


@mcp.tool()
def search_documents(query: str) -> list[dict[str, Any]]:
    """Return fixture documents whose title or text contains the query (case-insensitive)."""
    q = query.lower()
    return [d for d in fixture() if q in d["title"].lower() or q in d["text"].lower()]


@mcp.tool()
def read_document(id: str) -> dict[str, Any]:
    """Return one fixture document by id."""
    for d in fixture():
        if d["id"] == id:
            return d
    return {"error": f"document {id} not found"}


@mcp.tool()
def list_collections() -> list[dict[str, Any]]:
    return [{"id": "homelab", "name": "Homelab"}]


@mcp.tool()
def update_document(id: str, text: str) -> dict[str, Any]:
    """Pretend to update; just echo back."""
    print(f"[outline-stub] update_document id={id} text_len={len(text)}", file=sys.stderr)
    return {"id": id, "ok": True}


@mcp.tool()
def create_document(title: str, text: str, collection_id: str | None = None) -> dict[str, Any]:
    print(f"[outline-stub] create_document title={title!r}", file=sys.stderr)
    return {"id": "new-1", "title": title, "ok": True}


if __name__ == "__main__":
    mcp.run(transport="stdio")
```

- [ ] **Step 4: Write the Notion stub**

Create `plugins/up-docs/tests/stubs/mcp_notion_stub.py`:

```python
"""FastMCP-based Notion stub for integration tests.

Same fixture-keying pattern as the Outline stub. Logs only to stderr.
"""
from __future__ import annotations
import os
import sys
from typing import Any

from fastmcp import FastMCP

mcp = FastMCP("notion-stub")

FIXTURES: dict[str, list[dict[str, Any]]] = {
    "empty": [],
    "openbao": [
        {"id": "page-1", "title": "Homelab / Infrastructure / GMK / CT 111 — OpenBao",
         "text": "OpenBao runs on CT 111 and is reachable from the Tailscale network."}
    ],
    "kismet-parent-only": [
        {"id": "parent-1", "title": "Homelab / Infrastructure / GMK",
         "text": "GMK hosts the homelab containers."}
    ],
}


def fixture() -> list[dict[str, Any]]:
    return FIXTURES.get(os.environ.get("NOTION_FIXTURE", "empty"), [])


@mcp.tool()
def notion_search(query: str) -> list[dict[str, Any]]:
    q = query.lower()
    return [d for d in fixture() if q in d["title"].lower() or q in d["text"].lower()]


@mcp.tool()
def notion_fetch(id: str) -> dict[str, Any]:
    for d in fixture():
        if d["id"] == id:
            return d
    return {"error": f"page {id} not found"}


@mcp.tool()
def notion_update_page(id: str, text: str) -> dict[str, Any]:
    print(f"[notion-stub] notion_update_page id={id} text_len={len(text)}", file=sys.stderr)
    return {"id": id, "ok": True}


@mcp.tool()
def notion_create_pages(parent_id: str, title: str, text: str) -> dict[str, Any]:
    print(f"[notion-stub] notion_create_pages title={title!r}", file=sys.stderr)
    return {"id": "new-page-1", "title": title, "ok": True}


if __name__ == "__main__":
    mcp.run(transport="stdio")
```

- [ ] **Step 5: Smoke-test that stubs at least start without crashing**

```bash
timeout 2 python3 plugins/up-docs/tests/stubs/mcp_outline_stub.py 2>/tmp/stub-stderr.log < /dev/null || true
grep -q "ERROR" /tmp/stub-stderr.log && cat /tmp/stub-stderr.log || echo "Outline stub ok"
```

Expected: `Outline stub ok`. (The stub blocks on stdin — `< /dev/null` causes orderly EOF exit.)

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/tests/stubs/
git commit -m "test(up-docs): FastMCP stubs for Outline and Notion (stderr-only logging)"
```

---

### Task 18: Integration bats tests

End-to-end tests that drive each agent via `claude --print --agent` and validate output via the Phase 3 verifiers. Gated behind `RUN_INTEGRATION=1` so the default suite stays free.

**Files:**

- Create: `plugins/up-docs/tests/integration/propagate-notion.bats`
- Create: `plugins/up-docs/tests/integration/propagate-repo.bats`
- Create: `plugins/up-docs/tests/integration/audit-drift.bats`

- [ ] **Step 1: Write propagate-notion.bats**

Create `plugins/up-docs/tests/integration/propagate-notion.bats`:

```bash
#!/usr/bin/env bats
# Integration: drives up-docs-propagate-notion end-to-end.
# Gated behind RUN_INTEGRATION=1 because it makes real Claude API calls.

load ../helpers

setup() {
    setup_test_env
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable (makes real API calls)"
    [ -n "${ANTHROPIC_API_KEY:-}" ] || skip "ANTHROPIC_API_KEY required"
    export UP_DOCS_TRANSCRIPT_LOG="$TEST_TMPDIR/transcript.jsonl"
    export NOTION_FIXTURE=openbao
    : > "$UP_DOCS_TRANSCRIPT_LOG"
}

teardown() { teardown_test_env; }

@test "config rebind produces no IPv4 in Notion summary" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md"
    local out
    out=$(claude --print --agent up-docs:up-docs-propagate-notion \
                 --output-format json \
                 < "$fixture")

    # Extract the JSON payload from the agent response
    local report
    report=$(echo "$out" | jq -r '.result // empty' | python3 -c "
import sys, re, json
text = sys.stdin.read()
# Find the JSON code fence; agent may emit prose around it.
m = re.search(r'\`\`\`json\s*(.*?)\s*\`\`\`', text, re.DOTALL)
if m:
    print(m.group(1))
else:
    # Try parsing the whole thing as JSON
    json.loads(text)  # raises if not pure JSON
    print(text)
")

    # Validate against Pydantic schema (rejects IPv4 leak)
    echo "$report" | python3 "$BATS_TEST_DIRNAME/../validate_output.py" up-docs-propagate-notion
}
```

- [ ] **Step 2: Write propagate-repo.bats**

Create `plugins/up-docs/tests/integration/propagate-repo.bats`:

```bash
#!/usr/bin/env bats
load ../helpers

setup() {
    setup_test_env
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable"
    [ -n "${ANTHROPIC_API_KEY:-}" ] || skip "ANTHROPIC_API_KEY required"
    export UP_DOCS_TRANSCRIPT_LOG="$TEST_TMPDIR/transcript.jsonl"
    : > "$UP_DOCS_TRANSCRIPT_LOG"

    # Fake a tiny repo for the agent to operate on
    mkdir -p "$TEST_TMPDIR/fakerepo/docs"
    cd "$TEST_TMPDIR/fakerepo"
    git init -q -b main
    echo "# Test Repo" > README.md
    echo "BAO_ADDR=127.0.0.1" > docs/handoff/deployed.md
    git add . && git -c user.email=t@t.com -c user.name=T commit -q -m "init"
}

teardown() { teardown_test_env; }

@test "repo propagator on rebind summary updates docs/handoff/deployed.md" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md"
    claude --print --agent up-docs:up-docs-propagate-repo \
           --output-format json < "$fixture" > /tmp/repo-out.json

    # The agent should have edited docs/handoff/deployed.md to include the new IP
    grep -q "100.90.121.89" docs/handoff/deployed.md
}
```

- [ ] **Step 3: Write audit-drift.bats — the Bug #4 regression test**

Create `plugins/up-docs/tests/integration/audit-drift.bats`:

```bash
#!/usr/bin/env bats
load ../helpers

setup() {
    setup_test_env
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable"
}

teardown() { teardown_test_env; }

@test "Bug #4 regression: fabricated evidence is rejected by verify_evidence_grounded" {
    # Use the captured fabrication fixture
    local report="$BATS_TEST_DIRNAME/fixtures/fabricated-evidence-finding.json"
    local empty_transcript="$TEST_TMPDIR/empty.jsonl"
    : > "$empty_transcript"

    run python3 "$BATS_TEST_DIRNAME/../verify_evidence_grounded.py" \
                "$report" "$empty_transcript"

    # The fabrication MUST be detected
    [ "$status" -eq 1 ]
    [[ "$output" == *"fabrications"* ]]
}

@test "auditor evidence in real run is grounded in transcript" {
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable"
    [ -n "${ANTHROPIC_API_KEY:-}" ] || skip "ANTHROPIC_API_KEY required"
    export UP_DOCS_TRANSCRIPT_LOG="$TEST_TMPDIR/transcript.jsonl"
    : > "$UP_DOCS_TRANSCRIPT_LOG"

    local fixture="$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md"
    claude --print --agent up-docs:up-docs-audit-drift \
           --output-format json < "$fixture" > /tmp/audit-out.json

    # Extract the auditor JSON payload from the response
    local report=/tmp/audit-report.json
    python3 -c "
import json, re, sys
text = json.load(open('/tmp/audit-out.json'))['result']
m = re.search(r'\`\`\`json\s*(.*?)\s*\`\`\`', text, re.DOTALL)
print(m.group(1) if m else text)
" > "$report"

    # Schema validation
    cat "$report" | python3 "$BATS_TEST_DIRNAME/../validate_output.py" up-docs-audit-drift

    # Evidence grounding (skips for empty transcript)
    [ -s "$UP_DOCS_TRANSCRIPT_LOG" ] || skip "empty transcript — hook not active"
    python3 "$BATS_TEST_DIRNAME/../verify_evidence_grounded.py" \
            "$report" "$UP_DOCS_TRANSCRIPT_LOG"
}
```

- [ ] **Step 4: Run the integration suite WITHOUT the env var (everything skips)**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/integration/ 2>&1 | tail -10` Expected: every test reports `# skip set RUN_INTEGRATION=1 to enable` (the smoke test in audit-drift.bats may run because it doesn't gate on RUN_INTEGRATION).

- [ ] **Step 5: Run the Bug #4 regression test specifically (no API needed)**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/integration/audit-drift.bats 2>&1 | grep -E "Bug #4|ok|not ok"` Expected: `ok N Bug #4 regression: fabricated evidence is rejected by verify_evidence_grounded`.

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/tests/integration/
git commit -m "test(up-docs): integration bats tests with Bug #4 fabrication regression"
```

---

### Phase 3 Tasks 16–18 checkpoint and v0.8.1 release

- [ ] **Run the entire test surface**

```bash
bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5
cd plugins/up-docs && python3 -m pytest tests/ 2>&1 | tail -5
```

Expected: bats 37 passing (36 + 1 Bug #4 regression), pytest 17 passing.

- [ ] **Bump versions to 0.8.1**

In `plugins/up-docs/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change `0.8.0` to `0.8.1`.

- [ ] **Add CHANGELOG entry**

Prepend to `plugins/up-docs/CHANGELOG.md`:

```markdown
## [0.8.1] - 2026-MM-DD

### Added

- `tests/integration/` end-to-end bats tests driven via `claude --print --agent`. Gated behind `RUN_INTEGRATION=1` (default suite remains free of API costs). Includes a non-API Bug #4 fabrication regression test that runs unconditionally.
- `tests/stubs/mcp_outline_stub.py` and `tests/stubs/mcp_notion_stub.py` — FastMCP-based MCP servers with fixture-keyed responses for reproducible CI. All logging routed to stderr per JSON-RPC stream-safety footgun.
- Three integration fixtures: config-rebind, bug-fix (Notion-out-of-scope), and the canonical fabricated-finding (Bug #4) input.
```

- [ ] **Tag and release**

```bash
git add -A
git commit -m "Release up-docs v0.8.1 — integration tests + MCP stubs"
```

Run `/release-pipeline:release`.

---

### Task 19 (Optional): DeepEval LLM-judge for layer-boundary prose checking

Opt-in deeper grader that catches semantic violations Pydantic can't (e.g., "this paragraph contains a shell command disguised as prose"). Gated behind `RUN_LLMJUDGE=1` — separate cost layer from `RUN_INTEGRATION`.

**Files:** (only if v0.9.1 is being shipped)

- Create: `plugins/up-docs/tests/test_agent_prose.py`

- [ ] **Step 1: Confirm deepeval is available**

Run: `python3 -c "import deepeval; print(deepeval.__version__)" 2>&1 || pip install --user deepeval`

- [ ] **Step 2: Write the prose-quality test**

Create `plugins/up-docs/tests/test_agent_prose.py`:

```python
"""Optional DeepEval LLM-judge for layer-boundary prose violations.

Gated behind RUN_LLMJUDGE=1. Each test case loads a captured agent output
file (produced by tests/integration/) and asks an LLM rubric to grade
whether the prose respects the layer boundary.
"""
from __future__ import annotations
import json
import os
from pathlib import Path

import pytest

# Lazy imports — deepeval pulls in heavy deps.
deepeval = pytest.importorskip("deepeval")
from deepeval import assert_test  # noqa: E402
from deepeval.metrics import GEval  # noqa: E402
from deepeval.test_case import LLMTestCase, LLMTestCaseParams  # noqa: E402

pytestmark = pytest.mark.skipif(
    "RUN_LLMJUDGE" not in os.environ,
    reason="set RUN_LLMJUDGE=1 to enable; requires ANTHROPIC_API_KEY and incurs API cost",
)

FIXTURE_DIR = Path(__file__).parent / "integration" / "fixtures"
LAST_RUN_DIR = Path("/tmp")  # populated by integration tests; opt-in


def _load(path: Path) -> str:
    if not path.exists():
        pytest.skip(f"capture file missing: {path} — run integration suite first")
    return path.read_text()


def test_notion_prose_is_strategic_not_implementation():
    """The Notion propagator output must avoid shell commands, IP addresses,
    and step-by-step procedures. Layer boundary defined in
    skills/notion/references/notion-guidelines.md."""
    metric = GEval(
        name="LayerBoundary",
        criteria=(
            "The output must NOT contain: (a) shell commands like ssh, curl, "
            "systemctl, bash, sed; (b) IPv4 addresses (four dot-separated octets); "
            "(c) absolute filesystem paths starting with /etc, /usr, /var, /home; "
            "(d) numbered step-by-step procedures. The output MAY mention service "
            "names, dates, and high-level reasons. Pass if all four 'must NOT' "
            "constraints are satisfied; fail otherwise."
        ),
        evaluation_params=[LLMTestCaseParams.ACTUAL_OUTPUT],
    )
    case = LLMTestCase(
        input=_load(FIXTURE_DIR / "session-summary-config-rebind.md"),
        actual_output=_load(LAST_RUN_DIR / "notion-out.json"),
    )
    assert_test(case, [metric])
```

- [ ] **Step 3: Verify it skips when not opted in**

Run: `cd plugins/up-docs && python3 -m pytest tests/test_agent_prose.py -v 2>&1 | tail -5` Expected: 1 skipped, 0 failed.

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/tests/test_agent_prose.py
git commit -m "test(up-docs): optional DeepEval LLM-judge for layer-boundary prose (opt-in)"
```

---

## Phase 4 — Behavioral hardening

### Task 20: `docs/.up-docs.json` layout config

Loosens the propagate-repo agent's hard coupling to the V1/V2 handoff layout. Lets users with Diátaxis or other patterns benefit from the plugin.

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md`
- Modify: `plugins/up-docs/README.md` §Project Setup

- [ ] **Step 1: Add layout-config probe to the agent prompt**

In `plugins/up-docs/agents/up-docs-propagate-repo.md`, in `<task>` step 3, replace the existing layout-detection block (the `[ -f docs/handoff/state.md ] && echo V2 …` shell) with:

````markdown
First, detect which layout this repo uses:

```bash
if [ -f docs/.up-docs.json ]; then
  # Explicit user override
  python3 -c "import json; print(json.load(open('docs/.up-docs.json')).get('layout','auto').upper())"
elif [ -f docs/handoff/state.md ]; then
  echo V2
elif [ -f docs/handoff.md ]; then
  echo V1
else
  echo NONE
fi
```

Layout values:

- **`V2`** (default when `docs/handoff/state.md` is present): full handoff-system-v2 audit (state.md, deployed.md, sessions/, bugs/, conventions.md, .claude/rules/).
- **`V1`** (default when `docs/handoff.md` is present without state.md): legacy single-file handoff audit.
- **`SIMPLE`** (set via `docs/.up-docs.json`): audit only the files listed in the config's `audit_targets` array — typically just README.md and CHANGELOG.md.
- **`DIATAXIS`** (set via `docs/.up-docs.json`): audit `tutorials/`, `how-to/`, `reference/`, `explanation/` directories at the file-list level; no opinionated state-tracking.
- **`NONE`**: no recognizable layout — output a single advisory row noting the gap.
````

The `docs/.up-docs.json` schema:

```json
{
	"layout": "simple",
	"audit_targets": ["README.md", "CHANGELOG.md", "docs/CHANGELOG.md"]
}
```

For `layout: simple`, only the listed files are audited. For `layout: diataxis`, the four canonical directories. The existing V1/V2/NONE branches in the agent prompt are reused; SIMPLE and DIATAXIS are new branches the agent must handle.

- [ ] **Step 2: Add SIMPLE branch handling to the agent prompt**

Append to `<task>` step 3 in `up-docs-propagate-repo.md`, after the existing V2 / V1 / NONE branches:

```markdown
**If SIMPLE (`docs/.up-docs.json` `layout: simple`):** read the `audit_targets` array from the config. For each path:

- If it exists, audit it against the session-change summary and apply targeted edits.
- If it does not exist, record `No change needed — file does not exist`.

Do not audit any file outside `audit_targets`. Do not perform stale-file scans, bug-KB updates, or session log appends in SIMPLE mode.

**If DIATAXIS (`docs/.up-docs.json` `layout: diataxis`):** glob the four canonical directories (`tutorials/`, `how-to/`, `reference/`, `explanation/`) for `*.md`. Audit each file against the session summary using the same targeted-edit discipline as V2. Skip the V2-specific machinery (no state.md, no bugs/, no sessions/).
```

- [ ] **Step 3: Document the config in README**

In `plugins/up-docs/README.md`, in §Project Setup, after the existing `## Documentation` mapping example, add:

````markdown
### Custom Layout (Optional)

By default, `up-docs-propagate-repo` detects either the v1 (`docs/handoff.md`) or v2 (`docs/handoff/state.md`) handoff-system layout. To override — for projects using Diátaxis or a simpler layout — create `docs/.up-docs.json`:

```json
{
	"layout": "simple",
	"audit_targets": ["README.md", "CHANGELOG.md", "docs/CHANGELOG.md"]
}
```

Recognized values:

| `layout` | Audit scope |
| --- | --- |
| `auto` | Default — probe for v1/v2; fall back to `none` |
| `simple` | Audit only the files listed in `audit_targets`. No state-tracking, bug KB, or session logs. |
| `diataxis` | Audit `tutorials/`, `how-to/`, `reference/`, `explanation/` directories. |
| `v1` / `v2` | Force a specific handoff-system version even if both file markers are present. |
| `none` | Skip the mandatory audit entirely; only act on session-change-summary items. |
````

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/README.md
git commit -m "feat(up-docs): docs/.up-docs.json layout config (simple, diataxis, v1, v2, none)"
```

---

### Task 21: Skill-level orchestration of drift phases

Rewrite `skills/drift/SKILL.md` so the skill walks phases 1–4 explicitly, dispatching the auditor scoped to one phase per call. The convergence machinery becomes load-bearing.

**Files:**

- Modify: `plugins/up-docs/skills/drift/SKILL.md` Workflow section

- [ ] **Step 1: Read the current Workflow section for context**

Run: `sed -n '24,60p' plugins/up-docs/skills/drift/SKILL.md` Expected: shows the current Steps 1–5 (single dispatch, no phase loop).

- [ ] **Step 2: Replace Steps 3–4 with an explicit phase loop**

In `plugins/up-docs/skills/drift/SKILL.md`, replace the existing `### 3. Dispatch …` and `### 4. Pass Findings Through` sections with:

````markdown
### 3. Walk the Four Drift Phases Explicitly

Each phase runs as a bounded convergence loop. Use `convergence-tracker.sh` to manage iteration state and detect oscillation.

```
For phase in 1, 2, 3, 4:
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh start-phase $phase

  iteration = 0
  loop:
    iteration += 1

    Dispatch up-docs:up-docs-audit-drift via the Agent tool with a prompt that:
      - Includes the session-change summary verbatim.
      - States: "Run only Phase $phase. Stop after emitting findings for this phase. Do not advance to the next phase."
      - Includes any prior-iteration findings as context.

    Capture the auditor's findings JSON.

    Pipe findings to:
      bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh record-iteration $phase

    Run:
      bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh check-convergence $phase

    If converged=true, exit phase loop and advance.
    If iteration >= 3, exit phase loop with status="max_iterations".
    Otherwise, continue.

  bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh check-oscillation $phase
  If oscillating=true, append to advisory output and exit phase loop.
```

Phase definitions (scope hint sent in the agent prompt for each phase):

| Phase | Scope sent to auditor |
| --- | --- |
| 1 | Infrastructure → Wiki: SSH/pct/curl every host claim in the wiki against live state. |
| 2 | Wiki internal consistency: cross-page contradictions, broken inter-wiki refs. |
| 3 | Link integrity: external URLs (use link-audit.sh), internal anchors. |
| 4 | Notion relevance: items from phases 1–3 that warrant a strategic-level update. |

### 4. Collate Findings Across Phases

After all four phase loops complete (or terminate via convergence/oscillation/max-iterations), collate findings:

- One combined JSON block with `findings` from all four phases (re-numbered sequentially)
- One combined markdown table grouped by phase
- Escalation block emitted if ANY phase triggered escalation

Pass the combined output to the user. Apply the same escalation guidance as before — do not auto-fix.
````

- [ ] **Step 3: Update the §Notes section**

In `plugins/up-docs/skills/drift/SKILL.md` §Notes, replace the existing two bullets with:

```markdown
## Notes

- The skill orchestrates the four-phase loop at the skill level; the auditor sub-agent runs scoped to one phase per dispatch. This makes phase boundaries explicit and trackable rather than relying on the agent to self-organize.
- Convergence + oscillation detection live in `scripts/convergence-tracker.sh`. State is per-process via `${UP_DOCS_TRACKER_STATE:-/tmp/up-docs-drift-tracker-$$.json}` (Phase 1 isolation).
- Findings are advisory: the auditor has no write tools for Outline or Notion. Fixes go through the propagators on a follow-up pass with the user's explicit consent.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/skills/drift/SKILL.md
git commit -m "feat(up-docs): explicit per-phase orchestration in /up-docs:drift skill"
```

---

### Task 22: Notion fuzzy fallback

When `notion-search(query: "<exact name>")` returns zero hits, retry with broadened keyword OR-queries derived from the session summary's "Affected area" fields.

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-notion.md` `<task>` step 1

- [ ] **Step 1: Update step 1 of the agent prompt**

In `plugins/up-docs/agents/up-docs-propagate-notion.md`, replace the existing `<task>` step 1 (`Locate Notion targets.`) with:

```markdown
1. Locate Notion targets.
   - Read the project CLAUDE.md for a `## Documentation` section that names the Notion area (page, database, or section).
   - **Primary search:** `notion-search(query: "<exact extractable name from session summary>")` for each name.
   - **Fuzzy fallback:** if the primary search returns 0 hits for an item, retry up to 3 broadened queries:
     1. OR-query of nouns extracted from the item's `Affected area` field (e.g. `"WiFi OR wireless OR security monitoring"` for "Kismet WiFi scanner").
     2. The Affected area field verbatim as a phrase query (e.g. `"GMK homelab"`).
     3. The parent collection name from CLAUDE.md `## Documentation` if specified.
   - Stop at the first fallback that returns hits. Record the search depth used in the output table's `Summary of Changes` column (e.g. `"primary 0 hits → fuzzy 1 hit on 'wireless OR security'"`).
   - If all four queries return 0 hits, record the page as `No change needed — no relevant Notion page found after fuzzy search`.
```

- [ ] **Step 2: Add a new example demonstrating the fuzzy fallback**

In `plugins/up-docs/agents/up-docs-propagate-notion.md`, in `<examples>`, add a new example block after the existing "New service — new Notion page created" example:

```markdown
<example>
  <scenario>Fuzzy fallback finds the right page when the exact name doesn't match.</scenario>
  <session_item>
  1. Kismet deployed on CT 105
     - Change: Kismet WiFi scanner deployed in new container CT 105
     - Reason: wireless security monitoring
     - Affected area: GMK homelab wireless monitoring
     - Files touched: new LXC container, systemd unit
     - Verifiable against: ssh gmk 'pct list | grep 105'
  </session_item>
  <your_actions>
  notion-search(query: "Kismet") → 0 hits.
  Fallback 1: notion-search(query: "wireless OR security OR monitoring") → returns "Homelab / Wireless Security Monitoring".
  notion-fetch → page describes the wireless-security strategy in prose.
  notion-update-page: add a date-stamped status note "Kismet deployed 2026-MM-DD on CT 105 as the WiFi scanner — see Outline for implementation."
  </your_actions>
  <output_rows>
  | 1 | "Wireless Security Monitoring" | Updated | primary 0 hits → fuzzy 1 hit on 'wireless OR security'; added Kismet deployment note |
  </output_rows>
  <lesson>The exact-name search misses pages titled differently from the service name. The Affected area field is the primary signal for fuzzy fallback — extract its nouns and OR-query before giving up.</lesson>
</example>
```

- [ ] **Step 3: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-notion.md
git commit -m "feat(up-docs): Notion fuzzy fallback when exact-name search returns zero hits"
```

---

### Phase 4 checkpoint and v0.9.0 release

- [ ] **Run the full test surface**

```bash
bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -3
cd plugins/up-docs && python3 -m pytest tests/ 2>&1 | tail -3
```

Expected: bats 37 passing, pytest 17 passing (no regression).

- [ ] **Bump versions to 0.9.0**

In `plugins/up-docs/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change `0.8.1` to `0.9.0`.

- [ ] **Add CHANGELOG entry**

Prepend to `plugins/up-docs/CHANGELOG.md`:

```markdown
## [0.9.0] - 2026-MM-DD

### Added

- `docs/.up-docs.json` layout config — supports `simple`, `diataxis`, `v1`, `v2`, `none`, and `auto`. Loosens previous hardcoding to one user's preferred handoff-system-v2 layout. Documented in README §Project Setup.
- `/up-docs:drift` now walks phases 1–4 explicitly at the skill level; auditor sub-agent dispatched once per phase. Convergence + oscillation detection becomes load-bearing.
- `up-docs-propagate-notion` fuzzy fallback: when `notion-search(query: "<exact name>")` returns 0 hits, retry up to 3 broadened OR-queries derived from the session summary's `Affected area` field. Search depth recorded in output table.

### Changed

- Default repo-layout detection probe now checks `docs/.up-docs.json` first, before V1/V2 file probes.
```

- [ ] **Tag and release**

```bash
git add -A
git commit -m "Release up-docs v0.9.0 — behavioral hardening (layout config, phase orchestration, fuzzy fallback)"
```

Run `/release-pipeline:release`.

---

## Self-Review

**Spec coverage:** Eleven actions enumerated → eleven tasks (counting Phase 0's five hygiene tasks, Phase 1's two scripts/skills tasks, Phase 2's three security tasks including the gate, Phase 3's nine eval-infrastructure tasks, and Phase 4's three behavioral tasks). Action cross-reference:

| Action #                | Task #                             | Phase |
| ----------------------- | ---------------------------------- | ----- |
| 1 (evals)               | 11, 12, 13, 14, 15, 16, 17, 18, 19 | 3     |
| 2 (security)            | 8, 9, 10                           | 2     |
| 3 (tracker state)       | 6                                  | 1     |
| 4 (Opus claim)          | 1                                  | 0     |
| 5 (CHANGELOG dedupe)    | 2                                  | 0     |
| 6 (handoff coupling)    | 20                                 | 4     |
| 7 (drift orchestration) | 21                                 | 4     |
| 8 (Python prereq)       | 4, 7                               | 0, 1  |
| 9 (link-audit quoting)  | 5                                  | 0     |
| 10 (Notion fuzzy)       | 22                                 | 4     |
| 11 (transcript hook)    | 11                                 | 3     |

**Placeholder scan:** No `TBD`, `TODO`, `implement later`, or "similar to Task N" present. Every code block contains the literal content.

**Type consistency:** Pydantic class names — `Row`, `Totals`, `PropagatorReport`, `NotionReport`, `Finding`, `Escalation`, `StatsByLayer`, `Stats`, `AuditorReport` — used consistently in Tasks 12, 13, and the integration tests. Function names — `evidence_signature`, `load_transcript`, `verify`, `main` — match between Task 14 (definition) and Task 15 (test imports). Hook env var `UP_DOCS_TRANSCRIPT_LOG` matches between Task 11 (script), Task 18 (bats setup), and the README. Tracker env var `UP_DOCS_TRACKER_STATE` matches between Task 6 (script + tests) and the post-Phase-1 SKILL.md notes.

**Cross-task references verified:**

- Task 16 fixture filenames (`session-summary-config-rebind.md`, `session-summary-bug-fix.md`, `fabricated-evidence-finding.json`) match Task 18's references.
- `agents/up-docs-*.md` filenames match between Task 10's frontmatter additions and the existing repo state.
- Phase 0 tasks all stand alone (no cross-task code dependency).
- Phase 2 Task 10 explicitly depends on Task 8's outcome, with Step 1 of Task 10 reading the recorded result file.

**Dependencies between tasks:**

```
Phase 0 (Tasks 1–5) → checkpoint → release v0.7.2

Phase 1 Task 6 → checkpoint
Phase 1 Task 7 → checkpoint
Phase 2 Task 8 (smoke gate) → Task 9 (always)
                              → Task 10 (only if Task 8 PASS)
Phase 3 Task 11 (hook) → Task 12 (validators) → Task 13 (validator tests)
                       → Task 14 (verifier) → Task 15 (verifier tests)
Tasks 6, 7, 8, 9, 10, 11–15 ship as v0.8.0 release.

Phase 3 Task 16 (fixtures) → Task 17 (stubs) → Task 18 (integration bats)
ships as v0.8.1.

Phase 4 Task 20 (layout config), Task 21 (drift orch), Task 22 (Notion fuzzy)
all independent, ship as v0.9.0.

Optional Phase 3 Task 19 (DeepEval) ships as v0.9.1 if desired.
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-08-up-docs-hardening-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Good fit for the 22 tasks across 5 release versions because each task is self-contained.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints for review. Good fit if you want to make decisions in real time and watch each step land.

Which approach?
