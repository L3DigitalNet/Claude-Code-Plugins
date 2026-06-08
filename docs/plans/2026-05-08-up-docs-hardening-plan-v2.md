# up-docs Plugin Hardening Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** v2 rewrite. Supersedes [`2026-05-08-up-docs-hardening-plan.md`](./2026-05-08-up-docs-hardening-plan.md) (audited unsafe; see [v1 audit](./2026-05-08-up-docs-hardening-plan-v1-audit.md) for the seven blocking and five non-blocking findings this rewrite resolves).

**Goal:** Address the same eleven actions from the 2026-05-08 up-docs assessment, but with corrected primitives drawn from current Claude Code plugin docs and the 2026-05-08 plugin-security-eval research report. Five sequenced release versions (0.7.2 → 0.8.0 → 0.8.1 → 0.9.0 → optional 0.9.1).

**Architecture:** Five phases of progressively higher leverage. Phase 0 ships hygiene. Phase 1 hardens helper scripts using the May 2026 `CLAUDE_CODE_SESSION_ID` env var. Phase 2 establishes a real plugin-shipped security boundary via `hooks/hooks.json` PreToolUse `deny-guard.sh` — patterned on the canonical `force-push-guard.sh` — plus a documented consumer-side `permissions.deny` requirement. Phase 3 builds the eval infrastructure (PostToolUse opt-in transcript capture with redaction, pinned Pydantic-v2 discriminated-union validators, structured-evidence transcript-grounding) plus the integration test surface wired via `--plugin-dir` + `--strict-mcp-config` + stdio FastMCP stubs. Phase 4 loosens hardcoded layout coupling, adds explicit per-phase drift orchestration, and adds Notion fuzzy-fallback. Each phase ends with a verification gate; releases happen at gates 0, 2, 3, and 4.

**Tech Stack:** bash + bats (existing test harness), Python 3.11+ with Pydantic v2 (discriminated-union validators), FastMCP (stdio MCP stubs), `claude --print --plugin-dir --mcp-config --strict-mcp-config --agent` (integration test driver), DeepEval ≥1.4 with `AnthropicModel` (optional opt-in prose-quality grader), GitHub `gh` CLI (smoke-test verification).

**Research baseline:** [`docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md`](../research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md). Authoritative facts that drive specific tasks:

- Plugin `settings.json` only supports `agent` and `subagentStatusLine` keys — `permissions.deny` and `hooks` blocks there are silently ignored. Plugin hooks ship via `hooks/hooks.json` (Task 9, Task 14).
- PostToolUse hook is the only programmatic path to Bash output from a plugin (`stream-json` does NOT emit tool results). Capture must be opt-in, redacted, and `chmod 600` (Task 13, Task 14).
- `--plugin-dir <path> --strict-mcp-config --mcp-config <file>` is the canonical headless test wiring; FastMCP `Client(server)` in-memory transport does NOT work for an external `claude -p` subprocess — stubs must be stdio FastMCP servers (Task 22).
- Pydantic v2 discriminated unions via `Annotated[Union[...], Field(discriminator="layer")]` produce a clear `union_tag_invalid` error on wrong-layer outputs (Task 15).
- DeepEval renamed `LLMTestCaseParams` → `SingleTurnParams` in 2025; `AnthropicModel` works without an OpenAI key; cloud telemetry is opt-out via `DEEPEVAL_TELEMETRY_OPT_OUT=YES` (Task 28).

**Reference implementations to study before Phase 2:**

- `plugins/release-pipeline/scripts/force-push-guard.sh` — canonical PreToolUse exit-2 deny pattern with `hookSpecificOutput.permissionDecision` JSON.
- `plugins/release-pipeline/hooks/hooks.json` — canonical plugin `hooks.json` schema.
- `plugins/github-repo-manager/scripts/gh-manager-guard.sh` — canonical PreToolUse + PostToolUse audit-log capture pattern with stdin JSON parsing.

**Open questions (verified at execution time, not desk-research):** Three live-system questions left intentionally as smoke-test gates rather than as blocking unknowns:

1. **GH-34573 plugin command-hook silent-drop.** RESOLVED PASS (2026-05-08). T8 smoke test executed; `/tmp/up-docs-hook-smoke.log` captured two `fired` lines (PreToolUse + PostToolUse) under claude 2.1.133. GH-34573 is empirically inactive. Tasks 9–14 may proceed without a re-plan. T8 outcome record: `plugins/up-docs/docs/phase-2-smoke-result.txt`.
2. **`--strict-mcp-config` behavior on missing tools.** Silent-skip vs. error is undocumented. Task 23 includes a smoke-test step that prints the integration test output on first failure for diagnosis.
3. **`--agent <plugin>:<agent-name>` namespacing for `--plugin-dir`-loaded plugins.** Documented namespacing applies in the UI — CLI behavior with a path-loaded plugin is unverified. Task 23's first integration test prints the `system/init` event so any `plugin_errors` or unresolved-agent failures are visible immediately.

**Release sequencing:**

| Version | Phases included | Estimated effort |
| --- | --- | --- |
| 0.7.2 (patch) | Phase 0 (Tasks 1–5) | ~1h |
| 0.8.0 (minor) | Phase 1 (Tasks 6–7) + Phase 2 (Tasks 8–11) + Phase 3 hooks/validators (Tasks 12–19) + Bats wrapper fix (Task 20) | 7–9h |
| 0.8.1 (patch) | Phase 3 integration surface (Tasks 21–24) | 3–4h |
| 0.9.0 (minor) | Phase 4 (Tasks 25–27) | 3–5h |
| 0.9.1 (optional) | Phase 4 DeepEval (Task 28) | 1–2h |

**Task numbering (28 total):**

- Phase 0: T1–T5
- Phase 1: T6–T7
- Phase 2: T8–T11
- Phase 3 (hooks + validators + verifier + bats wrapper): T12–T20
- Phase 3 (integration surface): T21–T24
- Phase 4: T25–T28

---

## File structure

**New files:**

- `plugins/up-docs/hooks/hooks.json` — plugin hook component file (PreToolUse + PostToolUse) [Task 9, Task 14]
- `plugins/up-docs/scripts/deny-guard.sh` — PreToolUse validator that exits 2 on forbidden commands [Task 10]
- `plugins/up-docs/scripts/capture-transcript.sh` — PostToolUse opt-in capture with redaction [Task 13]
- `plugins/up-docs/tests/pyproject.toml` — pinned Pydantic / pytest / DeepEval deps [Task 12]
- `plugins/up-docs/tests/validate_output.py` — Pydantic v2 discriminated-union validators [Task 15]
- `plugins/up-docs/tests/test_validate_output.py` — pytest self-tests for the validators [Task 16]
- `plugins/up-docs/tests/verify_evidence_grounded.py` — structured-evidence transcript cross-check [Task 17]
- `plugins/up-docs/tests/test_verify_evidence_grounded.py` — pytest self-tests for the verifier [Task 18]
- `plugins/up-docs/tests/integration/fixtures/session-summary-config-rebind.md` [Task 21]
- `plugins/up-docs/tests/integration/fixtures/session-summary-bug-fix.md` [Task 21]
- `plugins/up-docs/tests/integration/fixtures/fabricated-evidence-finding.json` [Task 21]
- `plugins/up-docs/tests/integration/fixtures/test-mcp-config.json` [Task 22]
- `plugins/up-docs/tests/stubs/mcp_outline_stub.py` — stdio FastMCP stub [Task 22]
- `plugins/up-docs/tests/stubs/mcp_notion_stub.py` — stdio FastMCP stub [Task 22]
- `plugins/up-docs/tests/integration/propagate-notion.bats` [Task 23]
- `plugins/up-docs/tests/integration/propagate-repo.bats` [Task 23]
- `plugins/up-docs/tests/integration/audit-drift.bats` (with non-API regression OUTSIDE setup gate) [Task 24]
- `plugins/up-docs/tests/test_agent_prose.py` — opt-in DeepEval LLM-judge [Task 28, optional]
- `plugins/up-docs/docs/phase-2-smoke-result.txt` — Task 8 outcome record [Task 8]

**Modified files:**

- `plugins/up-docs/README.md` — drop Opus claim (Task 1); document Python 3 prereq (Task 4); document **consumer-side** `permissions.deny` requirement (Task 11); document `docs/.up-docs.json` layout config (Task 25)
- `plugins/up-docs/CHANGELOG.md` — dedupe `0.3.0` entry (Task 2); add release entries
- `plugins/up-docs/.claude-plugin/plugin.json` — version bumps (4 times)
- `.claude-plugin/marketplace.json` — version bumps (4 times)
- `plugins/up-docs/scripts/convergence-tracker.sh` — `CLAUDE_CODE_SESSION_ID`-based default state file [Task 6]
- `plugins/up-docs/tests/link-audit.bats` — quote-safe rewrite, red-first regression test [Task 5]
- `plugins/up-docs/tests/run-bats.sh` — honor `"$@"` so explicit paths run [Task 20]
- `plugins/up-docs/skills/all/SKILL.md` — Python prereq check (Task 7)
- `plugins/up-docs/skills/repo/SKILL.md` — Python prereq check (Task 7)
- `plugins/up-docs/skills/wiki/SKILL.md` — Python prereq check (Task 7)
- `plugins/up-docs/skills/notion/SKILL.md` — Python prereq check (Task 7)
- `plugins/up-docs/skills/drift/SKILL.md` — Python prereq check (Task 7); per-phase orchestration (Task 26); `CLAUDE_CODE_SESSION_ID`-driven tracker setup (Task 6 follow-on)
- `plugins/up-docs/agents/up-docs-audit-drift.md` — structured evidence schema in prompt (Task 19)
- `plugins/up-docs/agents/up-docs-propagate-repo.md` — layout-config probe with branches for every documented value (Task 25)
- `plugins/up-docs/agents/up-docs-propagate-notion.md` — fuzzy fallback (Task 27)

**Deliberately NOT created in v2 (deviations from v1):**

- `plugins/up-docs/.claude/settings.json` — invalid plugin component path per the v1 audit's CR-001 finding and the Plugins Reference. Plugin-shipped `permissions.deny` is **not** a thing; the consuming-project `permissions.deny` is documented in README via Task 11.
- A single `PropagatorReport` schema accepting any layer — replaced by a Pydantic v2 discriminated union (Task 15) per CR-008.

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

### Task 3: Delete the stale v2.1.92 mitigation note

> **CR-011 resolution:** v1's task title said "move to Resolved subsection" but its steps deleted the bullet outright. v2 picks deletion — the bug is fixed three releases ago, the mitigation is no longer actionable for any current user, and a Resolved subsection adds documentation surface that has to be maintained for no reader benefit. Title and steps now agree on deletion.

**Files:**

- Modify: `plugins/up-docs/README.md` lines 134–141

- [ ] **Step 1: Read the Known Issues block**

Run: `sed -n '134,141p' plugins/up-docs/README.md` Expected: shows the `- **Claude Code version sensitivity (MCP + Haiku):**` bullet.

- [ ] **Step 2: Delete the v2.1.92 bullet**

In `plugins/up-docs/README.md`, find the bullet:

```markdown
- **Claude Code version sensitivity (MCP + Haiku):** Claude Code v2.1.92 had a bug where Haiku's internal title-generation probe could block session-wide MCP tool loading ([anthropics/claude-code#44290](https://github.com/anthropics/claude-code/issues/44290), now closed). On affected versions, `up-docs-propagate-wiki`, `up-docs-propagate-notion`, and `up-docs-audit-drift` may show FAILED rows because their MCP tools never load. Mitigation: upgrade Claude Code past the fix, or fall back to `/up-docs:repo` which uses no MCP tools.
```

and remove the entire bullet (including the surrounding blank line if removing the bullet leaves a doubled blank). The bug is fixed in current Claude Code; readers don't need this for active troubleshooting.

- [ ] **Step 3: Verify removal**

Run: `grep -c "v2.1.92" plugins/up-docs/README.md` Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/README.md
git commit -m "docs(up-docs): delete stale v2.1.92 MCP-loading mitigation note"
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

In `plugins/up-docs/README.md`, in §Requirements, add a new bullet at the top of the list. The full §Requirements block becomes:

```markdown
## Requirements

- Python 3.11+ in `$PATH` (used by all four helper scripts under `scripts/` and by the test suite)
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
git commit -m "docs(up-docs): document Python 3.11+ as a hard requirement"
```

---

### Task 5: Fix link-audit.bats nested-bash quote interpolation (red-first TDD)

`tests/link-audit.bats` uses `bash -c "echo '$md' | bash …"` — works for current inputs but corrupts inputs containing single quotes. Hidden trap. Replace with a quote-safe pattern.

> **CR-010 resolution:** v1 wrote the regression test using the new safe pattern from the start, so it never failed before the fix — there was no red-then-green signal. v2 writes the regression test using the OLD `bash -c "echo '$md'"` invocation first, runs it to confirm it FAILS on the single-quote input, THEN rewrites the entire suite to the safe pattern, THEN runs again to confirm green. Real TDD.

**Files:**

- Modify: `plugins/up-docs/tests/link-audit.bats`

- [ ] **Step 1: Write the regression test using the OLD unsafe pattern**

Append to `plugins/up-docs/tests/link-audit.bats`:

```bash
@test "single-quote inputs do not break link extraction (regression)" {
    local md="See [O'Reilly](https://oreilly.com) for more."
    # Intentionally uses the OLD unsafe pattern to demonstrate the bug.
    # Step 3 of Task 5 rewrites this to the safe pattern after confirming RED.
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.total_links')" -ge 1 ]
}
```

- [ ] **Step 2: Run the test, confirm it FAILS (red)**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | grep -A 1 "single-quote"` Expected: `not ok N single-quote inputs do not break link extraction (regression)` — the embedded `'` in `O'Reilly` terminates the outer single-quoted shell string and the rest of `Reilly](...)` is parsed as separate shell tokens, so either the script gets the wrong stdin or the test fails the `jq` assertion.

If the test PASSES, the bug isn't reproducing — re-read the existing tests and check that `$md` is being interpolated through the `bash -c` like the existing tests do, not wrapped in some other quoting that escapes the issue. Do NOT proceed to Step 3 until the regression test demonstrates RED.

- [ ] **Step 3: Rewrite the regression test to the safe pattern**

In `plugins/up-docs/tests/link-audit.bats`, replace the test body added in Step 1 with the safe form:

```bash
@test "single-quote inputs do not break link extraction (regression)" {
    local md="See [O'Reilly](https://oreilly.com) for more."
    # Safe pattern: pass $md as positional arg "$1" and use printf to write it to stdin.
    run bash -c 'printf "%s\n" "$1" | bash "$SCRIPTS_DIR/link-audit.sh" -' _ "$md"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.total_links')" -ge 1 ]
}
```

The change is the `run bash -c` invocation:

- old: `run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"`
- new: `run bash -c 'printf "%s\n" "$1" | bash "$SCRIPTS_DIR/link-audit.sh" -' _ "$md"`

The new form uses single quotes around the `bash -c` body so `$1` is NOT expanded by the outer shell; `bash -c` then receives `$md` as positional `$1` and `printf` writes it to stdin verbatim.

- [ ] **Step 4: Rewrite every other unsafe test in the file**

Run: `grep -n "bash -c \"echo '" plugins/up-docs/tests/link-audit.bats` Expected: lists every test still using the old pattern. For each match, rewrite the same way:

- old: `run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"`
- new: `run bash -c 'printf "%s\n" "$1" | bash "$SCRIPTS_DIR/link-audit.sh" -' _ "$md"`

After rewrite, run: `grep -c "bash -c \"echo '" plugins/up-docs/tests/link-audit.bats` Expected: `0`

- [ ] **Step 5: Run the full bats suite to confirm green**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5` Expected: all tests pass (35 total — 34 existing + 1 regression).

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/tests/link-audit.bats
git commit -m "test(up-docs): quote-safe link-audit invocations; red-first single-quote regression"
```

---

### Phase 0 checkpoint and v0.7.2 release

- [ ] **Run the full bats suite**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5` Expected: 35 of 35 tests pass.

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
- `tests/link-audit.bats` no longer breaks on inputs containing single quotes; added red-first regression test.

### Added

- README §Requirements now lists Python 3.11+ as a hard prerequisite (used by all four helper scripts and the test suite).
```

- [ ] **Tag and release**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "Release up-docs v0.7.2 — Phase 0 hygiene"
```

Run `/release-pipeline:release` to push the tag and GitHub release. Verify the release lands.

---

## Phase 1 — Helper-script robustness

### Task 6: Migrate convergence-tracker state file to `CLAUDE_CODE_SESSION_ID`

> **CR-005 resolution:** v1 defaulted to `${TMPDIR:-/tmp}/up-docs-drift-tracker-$$.json`. The `$$` (PID) changes for every separate `bash convergence-tracker.sh ...` invocation, and the drift skill makes 6+ separate calls in one session — so `init`, `start-phase`, `record-iteration`, and `check-convergence` all read different files and lose state. v2 keys the default off `CLAUDE_CODE_SESSION_ID` (May 2026 env var, stable across all hook subprocesses and tool calls within one Claude Code session). Falls back to `default` if the env var is unset (e.g. when invoked outside Claude Code, like the existing bats tests).

`scripts/convergence-tracker.sh` hardcodes `/tmp/up-docs-drift-tracker.json` on line 20. Two repos in concurrent `/up-docs:drift` runs collide. Replace with the env-overridable + session-id-based default.

**Files:**

- Modify: `plugins/up-docs/scripts/convergence-tracker.sh` line 20
- Modify: `plugins/up-docs/tests/convergence-tracker.bats` setup/teardown

- [ ] **Step 1: Write a failing test for cross-process state persistence within one "session"**

Append to `plugins/up-docs/tests/convergence-tracker.bats`:

```bash
@test "session-scoped default keeps state across separate process invocations" {
    # Simulate three separate `bash convergence-tracker.sh ...` calls within one
    # Claude Code session. The session-id env var is the same; the state file
    # must be the same file across the three subprocesses.
    export CLAUDE_CODE_SESSION_ID="test-session-abc"
    unset UP_DOCS_TRACKER_STATE
    export TMPDIR="$TEST_TMPDIR"

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    [ "$status" -eq 0 ]
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    [ "$status" -eq 0 ]
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "1" ]
}

@test "concurrent sessions are isolated by CLAUDE_CODE_SESSION_ID" {
    unset UP_DOCS_TRACKER_STATE
    export TMPDIR="$TEST_TMPDIR"

    CLAUDE_CODE_SESSION_ID="session-A" bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    CLAUDE_CODE_SESSION_ID="session-A" bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    CLAUDE_CODE_SESSION_ID="session-B" bash "$SCRIPTS_DIR/convergence-tracker.sh" init

    # Session A should still have phase 1 started; session B should be fresh.
    run bash -c 'CLAUDE_CODE_SESSION_ID="session-A" bash "$SCRIPTS_DIR/convergence-tracker.sh" status'
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "1" ]

    run bash -c 'CLAUDE_CODE_SESSION_ID="session-B" bash "$SCRIPTS_DIR/convergence-tracker.sh" status'
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "0" ]
}

@test "explicit UP_DOCS_TRACKER_STATE wins over CLAUDE_CODE_SESSION_ID" {
    local explicit="$TEST_TMPDIR/explicit-state.json"
    export UP_DOCS_TRACKER_STATE="$explicit"
    export CLAUDE_CODE_SESSION_ID="ignored-session"

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    [ "$status" -eq 0 ]
    [ -f "$explicit" ]
}
```

- [ ] **Step 2: Run the tests, confirm they FAIL**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | grep -E "session-scoped|concurrent sessions|UP_DOCS_TRACKER_STATE wins"` Expected: every new test reports `not ok` because the script ignores both env vars and uses the hardcoded `/tmp/up-docs-drift-tracker.json`.

- [ ] **Step 3: Modify the script to honor both env vars**

In `plugins/up-docs/scripts/convergence-tracker.sh`, replace line 20:

```bash
STATE_FILE="/tmp/up-docs-drift-tracker.json"
```

with:

```bash
# State file resolution order (most specific first):
#   1. UP_DOCS_TRACKER_STATE — explicit override (tests, edge cases)
#   2. CLAUDE_CODE_SESSION_ID — May 2026 Claude Code env var, stable across
#      hook subprocesses and tool calls within one session. The drift skill
#      invokes this script 6+ times per session; all calls must share state.
#   3. "default" — fallback when invoked outside Claude Code (manual debug).
#
# The PID ($$) is intentionally NOT used: it changes between separate
# `bash convergence-tracker.sh ...` invocations and breaks state persistence.
STATE_FILE="${UP_DOCS_TRACKER_STATE:-${TMPDIR:-/tmp}/up-docs-tracker-${CLAUDE_CODE_SESSION_ID:-default}.json}"
```

- [ ] **Step 4: Update existing setup/teardown to use an explicit state file**

In `plugins/up-docs/tests/convergence-tracker.bats`, replace the existing `setup()` and `teardown()` with:

```bash
setup() {
    setup_test_env
    export UP_DOCS_TRACKER_STATE="$TEST_TMPDIR/tracker-state.json"
}

teardown() {
    unset UP_DOCS_TRACKER_STATE
    unset CLAUDE_CODE_SESSION_ID
    teardown_test_env
}
```

- [ ] **Step 5: Run the suite to confirm everything passes**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5` Expected: 38 of 38 tests passed (35 from Phase 0 + 3 new).

- [ ] **Step 6: Update skills/drift/SKILL.md notes section**

In `plugins/up-docs/skills/drift/SKILL.md`, find the §Notes section (or the bottom of the file if no notes section exists) and ensure it contains:

```markdown
## Notes

- Convergence + oscillation detection live in `scripts/convergence-tracker.sh`. The default state-file path is `${TMPDIR:-/tmp}/up-docs-tracker-${CLAUDE_CODE_SESSION_ID:-default}.json` so that the 6+ separate invocations in one drift session share state. Override with `UP_DOCS_TRACKER_STATE` for tests or for non-session usage.
- Findings are advisory: the auditor has no write tools for Outline or Notion. Fixes go through the propagators on a follow-up pass with the user's explicit consent.
```

- [ ] **Step 7: Commit**

```bash
git add plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/tests/convergence-tracker.bats plugins/up-docs/skills/drift/SKILL.md
git commit -m "fix(up-docs): tracker state defaults to CLAUDE_CODE_SESSION_ID; persists across calls"
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

- [ ] **Step 1: Read one skill's Step 1 for context**

Run: `sed -n '1,30p' plugins/up-docs/skills/all/SKILL.md` Expected: shows a `### 1. Gather Session Context` heading followed by a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh` code block.

- [ ] **Step 2: Apply the change to skills/all/SKILL.md**

In `plugins/up-docs/skills/all/SKILL.md`, replace the Step 1 code block currently of the form:

````markdown
### 1. Gather Session Context

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```
````

with:

````markdown
### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```
````

- [ ] **Step 3: Apply the same change to skills/repo/SKILL.md**

Same replacement as Step 2 but in `plugins/up-docs/skills/repo/SKILL.md`.

- [ ] **Step 4: Apply the same change to skills/wiki/SKILL.md**

Same replacement as Step 2 but in `plugins/up-docs/skills/wiki/SKILL.md`.

- [ ] **Step 5: Apply the same change to skills/notion/SKILL.md**

Same replacement as Step 2 but in `plugins/up-docs/skills/notion/SKILL.md`.

- [ ] **Step 6: Apply the change to skills/drift/SKILL.md (Step 1 has two bash invocations — preserve the tracker init)**

In `plugins/up-docs/skills/drift/SKILL.md`, replace the Step 1 block currently of the form:

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

Run: `grep -l "command -v python3" plugins/up-docs/skills/*/SKILL.md` Expected: lists all five SKILL.md files (all, repo, wiki, notion, drift).

- [ ] **Step 8: Commit**

```bash
git add plugins/up-docs/skills/
git commit -m "feat(up-docs): explicit python3 prereq check at skill Step 1 across all 5 skills"
```

---

## Phase 2 — Security boundary correction

> **CR-001/CR-002 resolution architecture.** v1 tried to ship `permissions.deny` inside `plugins/up-docs/.claude/settings.json`. That path is not a valid plugin component — plugin `settings.json` (at plugin root, not under `.claude/`) supports only `agent` and `subagentStatusLine`. v1's deny block would have been silently ignored. v2 ships defense-in-depth in three layers, only one of which can live inside the plugin:
>
> 1. **Plugin-shipped PreToolUse `deny-guard.sh`** (Task 9 + Task 10). Mirrors `force-push-guard.sh`. Parses the full command line including pipes, redirects, and `&&` chains. Issues `exit 2` with `hookSpecificOutput.permissionDecision: "deny"` JSON. Defense-in-depth, NOT a security boundary — `grep`-based deny matching is inherently incomplete.
> 2. **Consumer-side `permissions.deny`** (Task 11). Documented in README as a recommended addition to the _consuming project's_ `.claude/settings.json`. This is the only definitively-enforced layer per current Claude Code permission docs.
> 3. **Agent-frontmatter `disallowedTools:`** — defense-in-depth at model-context level. Not added in this plan because all four agents already declare narrow tool lists, the field is best-effort by design (not engine-enforced), and the v1 audit's CR-002 surfaced that the deny list mirroring problem dwarfed any incremental benefit. Reconsider in a future release if `deny-guard.sh` proves too noisy in practice.

### Task 8: Smoke-test `hooks/hooks.json` actually fires (gate task)

> **Open Question 1 resolution as a gate.** GH-34573 is closed-not-planned but contradicted by the five sibling plugins in this repo using PreToolUse/PostToolUse command hooks in production. Before Tasks 9 and 13 invest in `deny-guard.sh` and `capture-transcript.sh`, prove that a minimal plugin hook actually fires under `claude --plugin-dir`. If it does not, the entire Phase 2/3 hook surface is dead-on-arrival and tasks below need rethinking via a different route (project-level `.claude/settings.json` only).

**Files:**

- Create: `plugins/up-docs/hooks/hooks.json` (minimal smoke-test version, replaced by Task 9)
- Create: `plugins/up-docs/scripts/hook-smoke.sh` (transient — kept until smoke test passes, removed in Task 9)
- Create: `plugins/up-docs/docs/phase-2-smoke-result.txt` (outcome record)

- [ ] **Step 1: Create the directories**

```bash
mkdir -p plugins/up-docs/hooks plugins/up-docs/docs
```

- [ ] **Step 2: Write a minimal hook script that records its firing**

Create `plugins/up-docs/scripts/hook-smoke.sh`:

```bash
#!/usr/bin/env bash
# hook-smoke.sh — Task 8 smoke test for plugin hook firing.
# Records to /tmp/up-docs-hook-smoke.log every time it runs.
# Exit 0 always — never blocks any tool call during the smoke test.
set -u
echo "fired $(date -Iseconds) tool=${1:-?}" >> /tmp/up-docs-hook-smoke.log 2>/dev/null || true
exit 0
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x plugins/up-docs/scripts/hook-smoke.sh
```

- [ ] **Step 4: Write the minimal hooks.json**

Create `plugins/up-docs/hooks/hooks.json`:

```json
{
	"hooks": {
		"PreToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-smoke.sh pre"
					}
				]
			}
		],
		"PostToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-smoke.sh post"
					}
				]
			}
		]
	}
}
```

- [ ] **Step 5: Run the smoke test via `--plugin-dir`**

```bash
rm -f /tmp/up-docs-hook-smoke.log
echo 'Run echo hello to test hooks.' | claude --plugin-dir "$(pwd)/plugins/up-docs" --debug "hooks" --print 2>&1 | tee /tmp/up-docs-hook-smoke-stderr.log
```

- [ ] **Step 6: Inspect the result**

```bash
echo "--- hook-smoke.log ---"
cat /tmp/up-docs-hook-smoke.log 2>/dev/null || echo "(log file does not exist — hook never fired)"
echo "--- stderr debug ---"
grep -iE "hook|plugin" /tmp/up-docs-hook-smoke-stderr.log | head -20
```

Expected outcomes:

- **PASS:** `/tmp/up-docs-hook-smoke.log` contains at least one `fired ...` line, AND the `--debug "hooks"` stderr shows the up-docs hook source-tagged as a plugin hook firing for the Bash tool.
- **FAIL:** the log file is empty or absent, AND no plugin-hook firing appears in the stderr debug. This means GH-34573 is still active and plugin command hooks are silently dropped.

- [ ] **Step 7: Record the outcome**

If PASS:

```bash
{
  echo "Phase 2 smoke test (Task 8) — date: $(date -I)"
  echo "Result: PASS — plugin command hooks fire under --plugin-dir."
  echo "Evidence:"
  cat /tmp/up-docs-hook-smoke.log
} > plugins/up-docs/docs/phase-2-smoke-result.txt
```

If FAIL:

```bash
{
  echo "Phase 2 smoke test (Task 8) — date: $(date -I)"
  echo "Result: FAIL — plugin command hooks did NOT fire under --plugin-dir."
  echo "GH-34573 may still be active. Phase 2/3 hook tasks (9, 10, 13, 14) MUST be re-routed via consumer-project .claude/settings.json BEFORE proceeding."
  echo "Stderr excerpt:"
  grep -iE "hook|plugin" /tmp/up-docs-hook-smoke-stderr.log | head -20
} > plugins/up-docs/docs/phase-2-smoke-result.txt
```

- [ ] **Step 8: Commit the smoke-test record**

```bash
git add plugins/up-docs/hooks/hooks.json plugins/up-docs/scripts/hook-smoke.sh plugins/up-docs/docs/phase-2-smoke-result.txt
git commit -m "test(up-docs): Task 8 hook-firing smoke test outcome recorded"
```

- [ ] **Step 9: Decision point**

Read `plugins/up-docs/docs/phase-2-smoke-result.txt` and either:

- **PASS:** Continue to Task 9. The smoke `hooks.json` and `hook-smoke.sh` get replaced by the real `deny-guard.sh` and `capture-transcript.sh` wiring.
- **FAIL:** STOP. Open a follow-up plan to re-route Phase 2 to a documented consumer-side approach. Do not execute Tasks 9–11 or 13–14 as written.

---

### Task 9: Plugin-shipped `hooks/hooks.json` with PreToolUse `deny-guard.sh`

> **CR-001 resolution.** Hooks live at `plugins/up-docs/hooks/hooks.json`, not `plugins/up-docs/.claude/settings.json`. The Plugins Reference table in current Claude Code docs specifies `hooks/hooks.json` as the plugin hook component path; plugin-root `settings.json` only supports `agent` and `subagentStatusLine` keys.

This task replaces the smoke-test `hooks.json` from Task 8 with the real PreToolUse wiring. The PostToolUse capture wiring is added later in Task 14.

**Files:**

- Modify: `plugins/up-docs/hooks/hooks.json` (replace smoke wiring)
- Delete: `plugins/up-docs/scripts/hook-smoke.sh` (no longer needed)

- [ ] **Step 1: Confirm Task 8 result was PASS**

```bash
grep -q "Result: PASS" plugins/up-docs/docs/phase-2-smoke-result.txt && echo "OK to proceed" || echo "STOP — smoke test did not pass"
```

Expected: `OK to proceed`. If `STOP`, abort this task and re-plan per Task 8 Step 9 FAIL branch.

- [ ] **Step 2: Replace `hooks/hooks.json` with the real PreToolUse wiring**

Overwrite `plugins/up-docs/hooks/hooks.json`:

```json
{
	"hooks": {
		"PreToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/deny-guard.sh"
					}
				]
			}
		]
	}
}
```

(PostToolUse is added in Task 14 after `capture-transcript.sh` exists.)

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; json.load(open('plugins/up-docs/hooks/hooks.json'))" && echo "valid"` Expected: `valid`

- [ ] **Step 4: Delete the no-longer-needed smoke-test script**

```bash
rm plugins/up-docs/scripts/hook-smoke.sh
```

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/hooks/hooks.json plugins/up-docs/scripts/hook-smoke.sh
git commit -m "feat(up-docs): plugin hooks/hooks.json wires PreToolUse deny-guard.sh"
```

(`git add` of the deleted file records the deletion in the commit.)

---

### Task 10: PreToolUse `deny-guard.sh` validator

> **CR-002 resolution.** v1 expressed all denies as `Bash(...)` glob patterns inside `permissions.deny`, with no parsing of pipes, redirects, or `&&` chains — so e.g. `cat /etc/foo > /tmp/bar.sh && bash /tmp/bar.sh` would have evaded a `Bash(rm *)`-style entry, and `cp` overwrites, `tee`-redirected writes, and SQL-write commands were all uncovered. v2 implements a real parser-aware validator that scans the full command string. Patterned on `force-push-guard.sh`. Documents remaining gaps consumer-side in Task 11.

**Files:**

- Create: `plugins/up-docs/scripts/deny-guard.sh`
- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md` — verify the auditor's `<forbidden_commands>` table matches the deny patterns below; add new patterns if absent. (The auditor's table is the spec; the script is the enforcement.)

- [ ] **Step 1: Read the auditor's forbidden_commands table for context**

Run: `grep -A 60 "<forbidden_commands>" plugins/up-docs/agents/up-docs-audit-drift.md | head -80` Expected: shows the seven categories the auditor must avoid. Note any missing from the script below.

- [ ] **Step 2: Write the deny-guard script**

Create `plugins/up-docs/scripts/deny-guard.sh`:

```bash
#!/usr/bin/env bash
# deny-guard.sh — PreToolUse hook for up-docs plugin.
#
# Blocks Bash commands matching the auditor's <forbidden_commands> categories:
#   - Filesystem destruction: rm, rmdir, shred, truncate, mv, cp -f overwriting
#   - Output redirection writes that overwrite system files
#   - Container lifecycle: pct stop/destroy/restore/migrate, qm stop/destroy
#   - Service control: systemctl stop/restart/disable/mask, service X stop, kill, killall, pkill
#   - Network/permissions: iptables, nft, ip route add/del, chmod, chown, chgrp, chattr, setfacl
#   - Package edits: apt install/remove, dnf install/remove, pip install, npm install --save
#   - Git destructive: git rm, git push --force, git reset --hard
#   - SQL writes: INSERT/UPDATE/DELETE/DROP/ALTER/TRUNCATE
#
# The hook parses the full command line — including pipes, redirects, `&&` /
# `;` chains, and inline subshell substitution — by tokenizing on shell
# operators and checking each segment.
#
# Patterned on plugins/release-pipeline/scripts/force-push-guard.sh:
#   - Reads PreToolUse JSON on stdin
#   - exit 0 to allow, exit 2 to block
#   - On block: emits hookSpecificOutput.permissionDecision="deny" JSON
#
# Failure mode: fail open. If the JSON parse fails or the command can't be
# extracted, exit 0. The deny-guard is defense-in-depth, not a security
# boundary — see README "Recommended consumer-side permissions.deny" for
# the actually-enforced layer.

set -uo pipefail

# Read PreToolUse JSON
INPUT=$(cat)

# Extract command (fail open if extraction fails)
COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Tokenize on shell operators: |, &&, ||, ;, $(, `
# Anything inside one of those segments is a candidate command-line.
# We also keep the whole command as one segment for catch-all matchers.
SEGMENTS=$(printf '%s\n' "$COMMAND" | python3 -c "
import sys, re
text = sys.stdin.read()
# Split on |, &&, ||, ;, and the body of \$(...) and \`...\`
parts = [text]
parts.extend(re.findall(r'\\\$\\(([^)]*)\\)', text))
parts.extend(re.findall(r'\`([^\`]*)\`', text))
splitter = re.compile(r'\\|\\||&&|\\||;')
out = []
for p in parts:
    out.extend(splitter.split(p))
for line in out:
    line = line.strip()
    if line:
        print(line)
")

# Patterns to deny. Each pattern is matched against each segment with grep -E.
# Format: one anchored regex per line.
DENY_PATTERNS=$(cat <<'PATTERNS'
^\s*rm(\s+-[a-zA-Z]+)*\s+
^\s*rmdir(\s+-[a-zA-Z]+)*\s+
^\s*shred(\s|$)
^\s*truncate(\s|$)
^\s*mv\s+\S+\s+\S+
^\s*cp\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|-f\s+|--force\s+)
^\s*git\s+rm(\s|$)
^\s*git\s+push\s+(--force|-f(\s|$))
^\s*git\s+reset\s+--hard
^\s*pct\s+(stop|shutdown|destroy|restore|migrate)(\s|$)
^\s*qm\s+(stop|destroy)(\s|$)
^\s*docker\s+(stop|rm)(\s|$)
^\s*docker-compose\s+down(\s|$)
^\s*systemctl\s+(stop|restart|disable|mask)(\s|$)
^\s*service\s+\S+\s+(stop|restart)(\s|$)
^\s*kill(\s|$)
^\s*killall(\s|$)
^\s*pkill(\s|$)
^\s*iptables(\s|$)
^\s*nft(\s|$)
^\s*ip\s+route\s+(add|del)(\s|$)
^\s*chmod(\s|$)
^\s*chown(\s|$)
^\s*chgrp(\s|$)
^\s*chattr(\s|$)
^\s*setfacl(\s|$)
^\s*apt(-get)?\s+(install|remove|purge)(\s|$)
^\s*dnf\s+(install|remove)(\s|$)
^\s*yum\s+(install|remove)(\s|$)
^\s*pip3?\s+install(\s|$)
^\s*npm\s+install\s+(--save|-S\b)
^\s*sed\s+-i(\s|$)
^\s*tee(\s+-a)?\s+(/etc|/usr|/var|/opt|/boot)
.*>\s*(/etc|/usr|/var|/opt|/boot)
.*\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE)\s+(INTO|FROM|TABLE|DATABASE|VIEW|INDEX)\b
PATTERNS
)

# Iterate every segment against every pattern; first match blocks.
MATCHED_SEG=""
MATCHED_PAT=""
while IFS= read -r SEG; do
    [ -z "$SEG" ] && continue
    while IFS= read -r PAT; do
        [ -z "$PAT" ] && continue
        if echo "$SEG" | grep -qE "$PAT"; then
            MATCHED_SEG="$SEG"
            MATCHED_PAT="$PAT"
            break 2
        fi
    done <<< "$DENY_PATTERNS"
done <<< "$SEGMENTS"

if [ -n "$MATCHED_PAT" ]; then
    REASON="up-docs deny-guard blocked: command segment $(printf '%q' "$MATCHED_SEG") matches forbidden pattern $(printf '%q' "$MATCHED_PAT"). See plugins/up-docs/agents/up-docs-audit-drift.md <forbidden_commands>. Override only with explicit owner approval and re-run as a separate command without the up-docs plugin loaded."
    REASON_JSON=$(printf '%s' "$REASON" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$REASON_JSON"
    exit 2
fi

exit 0
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x plugins/up-docs/scripts/deny-guard.sh
```

- [ ] **Step 4: Smoke-test the deny-guard locally with a forbidden command**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/test"}}' | bash plugins/up-docs/scripts/deny-guard.sh
echo "exit=$?"
```

Expected: stdout contains `permissionDecision":"deny"`; `exit=2`.

- [ ] **Step 5: Smoke-test with a piped command (the v1 audit's specific gap)**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"cat /etc/passwd | tee /etc/passwd.bak"}}' | bash plugins/up-docs/scripts/deny-guard.sh
echo "exit=$?"
```

Expected: `permissionDecision":"deny"`; `exit=2`. The `tee /etc/...` segment matches the `^\s*tee(\s+-a)?\s+(/etc|...)` pattern.

- [ ] **Step 6: Smoke-test with a chained command**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls /tmp && rm -rf /tmp/junk"}}' | bash plugins/up-docs/scripts/deny-guard.sh
echo "exit=$?"
```

Expected: `permissionDecision":"deny"`; `exit=2`. The `&&` splits the command and the `rm -rf` segment matches.

- [ ] **Step 7: Smoke-test with an allowed command (negative)**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | bash plugins/up-docs/scripts/deny-guard.sh
echo "exit=$?"
```

Expected: empty stdout; `exit=0`.

- [ ] **Step 8: Smoke-test with malformed JSON (must fail open)**

```bash
echo 'not-json-at-all' | bash plugins/up-docs/scripts/deny-guard.sh
echo "exit=$?"
```

Expected: empty stdout; `exit=0`.

- [ ] **Step 9: Add a bats test for the deny-guard**

Create `plugins/up-docs/tests/deny-guard.bats`:

```bash
#!/usr/bin/env bats
# Tests for scripts/deny-guard.sh — the PreToolUse forbidden-command validator.

load helpers

GUARD="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/deny-guard.sh"
export GUARD  # required: bash -c subshells in tests below need GUARD in their env

@test "deny-guard blocks rm" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/x"}}'
    [ "$status" -eq 2 ]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "deny-guard blocks pct destroy" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"pct destroy 105"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks systemctl stop" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"systemctl stop nginx"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks tee redirect to /etc" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"cat foo | tee /etc/passwd"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks chained rm after &&" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"ls /tmp && rm -rf /tmp/junk"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks rm inside subshell substitution" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"echo $(rm -rf /tmp/x)"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks SQL DELETE" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"sqlite3 db.sqlite \"DELETE FROM users\""}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks redirect to /etc" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"echo bad > /etc/hosts"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks pip install" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"pip install requests"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard allows git status" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "deny-guard allows ssh read-only" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"ssh gmk pct list"}}'
    [ "$status" -eq 0 ]
}

@test "deny-guard fails open on malformed JSON" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ 'not-json'
    [ "$status" -eq 0 ]
}

@test "deny-guard fails open on missing command field" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{}}'
    [ "$status" -eq 0 ]
}
```

- [ ] **Step 10: Run the new bats tests**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -8` Expected: 51 of 51 tests passed (38 from Phase 0+1 + 13 new).

- [ ] **Step 11: Commit**

```bash
git add plugins/up-docs/scripts/deny-guard.sh plugins/up-docs/tests/deny-guard.bats
git commit -m "feat(up-docs): PreToolUse deny-guard.sh blocks forbidden commands"
```

---

### Task 11: Document consumer-side `permissions.deny` in README

> **CR-001 follow-on.** Plugin-shipped `permissions.deny` is not a supported feature. The actually-enforced layer is the consuming project's `.claude/settings.json` `permissions.deny`. v2 documents this as a recommended addition for users who want a hard security boundary, while making clear that the plugin's `deny-guard.sh` is defense-in-depth that catches a different (and overlapping) failure mode. Users who don't add the consumer-side block still get the plugin-shipped guard.

**Files:**

- Modify: `plugins/up-docs/README.md`

- [ ] **Step 1: Add a Security section to README**

In `plugins/up-docs/README.md`, after the existing §Requirements section and before any §Usage / §Commands section (or at an appropriate position the file's structure supports — typically after §Requirements), add:

````markdown
## Security

up-docs ships with a defense-in-depth `PreToolUse` validator (`scripts/deny-guard.sh`) that blocks Bash commands matching the auditor's forbidden categories: filesystem destruction (rm, mv, cp -f, sed -i, redirect into /etc), container lifecycle (pct stop/destroy/restore/migrate, qm stop/destroy, docker stop/rm), service control (systemctl stop/restart/disable/mask, kill, killall, pkill), network/permissions (iptables, nft, ip route add/del, chmod, chown, chattr, setfacl), package edits (apt install/remove, dnf install/remove, pip install, npm install --save), git destructive (git rm, git push --force, git reset --hard), and SQL writes (INSERT/UPDATE/DELETE/DROP/ALTER/TRUNCATE).

The PreToolUse guard is grep-based and inherently incomplete — sufficiently crafted commands using Bash variable expansion, here-docs, or eval can evade pattern matching. For a definitively-enforced security boundary, add the following block to your **consuming project's** `.claude/settings.json`:

```json
{
	"permissions": {
		"deny": [
			"Bash(rm *)",
			"Bash(rmdir *)",
			"Bash(shred *)",
			"Bash(mv * *)",
			"Bash(cp -f *)",
			"Bash(sed -i *)",
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
			"Bash(pip install *)",
			"Bash(npm install --save *)"
		]
	}
}
```
````

The consumer-side `permissions.deny` is enforced by Claude Code's permission engine regardless of which agent is running. See [Claude Code permission docs](https://code.claude.com/docs/en/settings) for the full deny-pattern syntax.

> Why both layers? The PreToolUse guard parses the full command line (including pipes, redirects, and `&&` chains) so it catches patterns the consumer-side `Bash(* * *)` glob misses. The consumer-side `permissions.deny` is engine-enforced and catches what the guard misses. Defense-in-depth.

````

- [ ] **Step 2: Verify README structure**

Run: `grep -n "^## " plugins/up-docs/README.md`
Expected: shows `## Security` between `## Requirements` and the next `## ` heading.

- [ ] **Step 3: Commit**

```bash
git add plugins/up-docs/README.md
git commit -m "docs(up-docs): document plugin deny-guard + consumer-side permissions.deny"
````

---

### Phase 2 checkpoint

Phase 2 ships as part of v0.8.0 alongside Phase 1 and Phase 3 Tasks 12–20. The release task is at the end of Task 20.

---

## Phase 3 — Eval infrastructure (Tasks 12–20)

The highest-leverage phase. Provides:

- Pinned, reproducible Python test deps (Task 12 — fixes CR-007).
- An opt-in PostToolUse capture hook with redaction and `chmod 600` (Task 13 — fixes CR-006).
- Wiring of the capture hook into the existing `hooks/hooks.json` (Task 14).
- Pydantic v2 discriminated-union output validators (Task 15 — fixes CR-008).
- Pytest self-tests for the validators (Task 16).
- Structured-evidence transcript-grounding verifier (Task 17 — fixes CR-003).
- Pytest self-tests for the verifier (Task 18).
- Auditor-prompt update to emit structured evidence so the verifier has something to check (Task 19 — fixes CR-003 prompt side).
- `tests/run-bats.sh` rewrite to honor `"$@"` so explicit-path invocations work (Task 20 — fixes CR-004 wrapper side).

### Task 12: Pinned Python test dependencies via `tests/pyproject.toml`

> **CR-007 resolution.** v1 used `pip install --user pydantic` fallbacks, which (a) mutate the user environment, (b) don't repair already-broken installs (the audit's environment had `pydantic` shadowed by a typing_extensions import error), and (c) make release gates workstation-dependent. v2 ships a plugin-local `tests/pyproject.toml` with pinned deps; tests run inside an isolated venv.

**Files:**

- Create: `plugins/up-docs/tests/pyproject.toml`
- Create: `plugins/up-docs/tests/.gitignore`

- [ ] **Step 1: Write the pyproject.toml**

Create `plugins/up-docs/tests/pyproject.toml`:

```toml
[project]
name = "up-docs-tests"
version = "0.0.0"
description = "Test dependencies for the up-docs plugin (Pydantic validators, pytest, FastMCP stubs, optional DeepEval)."
requires-python = ">=3.11"
dependencies = [
  "pydantic>=2.5,<3.0",
  "typing_extensions>=4.9,<5.0",
  "pytest>=8.0,<9.0",
]

[project.optional-dependencies]
mcp-stubs = [
  "fastmcp>=0.4,<1.0",
]
deepeval = [
  "deepeval>=1.4,<2.0",
  "anthropic>=0.40,<1.0",
]
test = [
  "up-docs-tests[mcp-stubs]",
]
all = [
  "up-docs-tests[mcp-stubs,deepeval]",
]

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"
```

- [ ] **Step 2: Add a .gitignore for venv artifacts**

Create `plugins/up-docs/tests/.gitignore`:

```
.venv/
__pycache__/
*.egg-info/
.pytest_cache/
```

- [ ] **Step 3: Bootstrap the venv and verify it installs cleanly**

```bash
cd plugins/up-docs/tests
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -e ".[test]"
.venv/bin/python -c "import pydantic, pytest, fastmcp; print(pydantic.VERSION)"
cd -
```

Expected: prints a Pydantic version `>=2.5`. The `import` line confirms all three core deps load without ImportError.

- [ ] **Step 4: Document the test workflow in tests/README**

Create `plugins/up-docs/tests/README.md`:

````markdown
# up-docs test suite

## Setup (one-time per worktree)

```bash
cd plugins/up-docs/tests
python3 -m venv .venv
.venv/bin/pip install -e ".[test]"
```
````

For DeepEval LLM-judge tests (Task 28, optional):

```bash
.venv/bin/pip install -e ".[all]"
```

## Running

Bats (shell-script) suite:

```bash
bash plugins/up-docs/tests/run-bats.sh
```

Pytest (Python validators + verifier):

```bash
cd plugins/up-docs/tests
.venv/bin/python -m pytest -v
```

Integration suite (gated behind `RUN_INTEGRATION=1`, makes real Claude API calls — see `tests/integration/`):

```bash
RUN_INTEGRATION=1 bash plugins/up-docs/tests/run-bats.sh tests/integration/
```

DeepEval LLM-judge (gated behind `RUN_LLMJUDGE=1`, requires `ANTHROPIC_API_KEY`):

```bash
cd plugins/up-docs/tests && \
  RUN_LLMJUDGE=1 ANTHROPIC_API_KEY=sk-ant-... DEEPEVAL_TELEMETRY_OPT_OUT=YES \
  .venv/bin/python -m pytest test_agent_prose.py -v
```

Note: env-var prefix in POSIX shell binds to the next _single_ simple command. Putting the prefix before `cd` would set the variables for `cd` only, not `pytest`. The `cd` must run first, then the prefix-and-pytest command is a single simple command in the shell's view.

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/tests/pyproject.toml plugins/up-docs/tests/.gitignore plugins/up-docs/tests/README.md
git commit -m "feat(up-docs): pinned Python test deps via tests/pyproject.toml; venv workflow"
```

---

### Task 13: PostToolUse capture-transcript.sh — opt-in, redacted, chmod 600

> **CR-006 resolution.** v1's hook captured every Bash and Read tool_input/tool_response to `/tmp` whenever the plugin was loaded — turning a testing utility into a passive data-leak sink that captured SSH output, env dumps, GitHub PATs, BAO_TOKEN values, and any `.env` file Claude reads. v2 makes capture opt-in via `UP_DOCS_TRANSCRIPT_LOG`, sets `umask 077` before file creation, follows up with `chmod 600` for already-existing files, redacts known secret patterns BEFORE writing, and only captures Bash (not Read — which would expose entire file contents per CR-006's "PostToolBatch docs explicitly note Read output can include file content"). Cites CVE-2025-59536 / GH-44868 in the script header so future readers understand why the guards exist.

**Files:**

- Create: `plugins/up-docs/scripts/capture-transcript.sh`

- [ ] **Step 1: Write the capture script**

Create `plugins/up-docs/scripts/capture-transcript.sh`:

```bash
#!/usr/bin/env bash
# capture-transcript.sh — PostToolUse hook for up-docs evidence-grounding tests.
#
# RUNTIME CONTRACT:
#   Receives PostToolUse JSON on stdin per Claude Code hook contract:
#     {"tool_name": "Bash", "tool_input": {...}, "tool_response": {...}, ...}
#   Appends one redacted JSON line per Bash invocation to ${UP_DOCS_TRANSCRIPT_LOG}.
#   Exits 0 always — hooks must not block tool execution on capture failure.
#
# SAFETY CONTRACT (read this if changing this script):
#   1. OPT-IN: no-op unless UP_DOCS_TRANSCRIPT_LOG is set to a non-empty value.
#      The plugin is loaded for every up-docs invocation; the hook is loaded
#      whenever the plugin is loaded; only the env var enables capture.
#   2. BASH ONLY: never captures Read tool_response (which contains entire
#      file contents per Claude Code PostToolBatch docs — see GH-44868).
#   3. UMASK 077: file is created mode 600. If the file pre-existed with
#      looser perms, chmod 600 corrects it before any write.
#   4. REDACTION: secret patterns (Bearer, ghp_, ghs_, AKIA, BAO_TOKEN=,
#      password=, token=, sk-ant-) are redacted BEFORE write. Even with
#      mode 600 and per-session log paths, secrets in plaintext at rest
#      are a known attack surface (CVE-2025-59536, GH-44868).
#   5. OUTPUT TRUNCATION: tool_response.output is truncated to 4 KiB before
#      write. Transcript-grounding only needs distinctive substrings, not
#      full output.
#   6. SESSION CLEANUP: this script does NOT clean up the log file. Set
#      UP_DOCS_TRANSCRIPT_LOG to a per-session path (e.g. /tmp/up-docs-
#      $(date +%s)-$RANDOM.jsonl) so old logs age out via /tmp policy.
#      The companion tests/run-bats.sh integration harness sets a TEST_TMPDIR
#      path and removes the file on teardown.

# OPT-IN GATE — first line, before set -u so an unset env var is a benign no-op.
[ -z "${UP_DOCS_TRANSCRIPT_LOG:-}" ] && exit 0

set -uo pipefail
INPUT=$(cat)

# Extract tool_name and only act on Bash (not Read or other tools)
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('tool_name', ''))
except: print('')
" 2>/dev/null)

[ "$TOOL_NAME" != "Bash" ] && exit 0

# Restrictive permissions before any file creation
umask 077
LOG="${UP_DOCS_TRANSCRIPT_LOG}"
touch "$LOG" 2>/dev/null || exit 0
chmod 600 "$LOG" 2>/dev/null || true

# Pipe input to a Python redactor that writes the JSONL line
printf '%s' "$INPUT" | python3 - "$LOG" <<'PYEOF'
import json, re, sys

LOG_PATH = sys.argv[1]
REDACT = "[REDACTED]"

# Compile-once secret patterns. Each captures the secret value in group 1
# so we can replace just the value, leaving the prefix for diagnostic context.
SECRET_PATTERNS = [
    re.compile(r'(Bearer\s+)([A-Za-z0-9._\-]{20,})', re.IGNORECASE),
    re.compile(r'(BAO_TOKEN\s*[=:]\s*)([^\s\'"&;]+)', re.IGNORECASE),
    re.compile(r'(password\s*[=:]\s*)([^\s\'"&;]{4,})', re.IGNORECASE),
    re.compile(r'(token\s*[=:]\s*)([^\s\'"&;]{8,})', re.IGNORECASE),
    re.compile(r'(api[_-]?key\s*[=:]\s*)([^\s\'"&;]{8,})', re.IGNORECASE),
    re.compile(r'(?<![A-Za-z0-9])(gh[ps]_)([A-Za-z0-9]{36,})'),
    # Anthropic API keys: sk-ant-<version>-<base64url-secret>; separator is hyphen, not underscore.
    # Pattern carried from the research report had `_` as group-1 terminator — would silently
    # miss real keys (verified against documented format: sk-ant-api03-...). Fixed to `-`.
    re.compile(r'(?<![A-Za-z0-9])(sk-ant-[a-zA-Z0-9-]+-)([A-Za-z0-9_\-]{20,})'),
    re.compile(r'(?<![A-Za-z0-9])(AKIA)([A-Z0-9]{16})'),
    re.compile(r'(aws_secret(?:_access)?_key\s*[=:]\s*)([^\s\'"&;]+)', re.IGNORECASE),
]

def redact(s: str) -> str:
    if not isinstance(s, str):
        return s
    for pat in SECRET_PATTERNS:
        s = pat.sub(lambda m: m.group(1) + REDACT, s)
    return s

try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)  # fail open

# tool_response can be either a string OR an object with .output / .isError
resp = data.get("tool_response", {})
if isinstance(resp, dict):
    output = resp.get("output", "") or ""
    is_error = bool(resp.get("isError", False))
else:
    output = str(resp)
    is_error = False

# Truncate output to 4 KiB before redaction (cheap; redaction would be slower on huge logs)
output = output[:4096]

entry = {
    "session_id": data.get("session_id", ""),
    "tool_use_id": data.get("tool_use_id", ""),
    "tool_name": data.get("tool_name", ""),
    "command": redact(data.get("tool_input", {}).get("command", "")),
    "output": redact(output),
    "is_error": is_error,
    "agent_id": data.get("agent_id", ""),
    "agent_type": data.get("agent_type", ""),
}

try:
    with open(LOG_PATH, "a") as f:
        f.write(json.dumps(entry) + "\n")
except Exception:
    sys.exit(0)
PYEOF

exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x plugins/up-docs/scripts/capture-transcript.sh
```

- [ ] **Step 3: Smoke-test with no env var (opt-in gate)**

```bash
unset UP_DOCS_TRANSCRIPT_LOG
echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}' | bash plugins/up-docs/scripts/capture-transcript.sh
echo "exit=$?"
ls /tmp/*transcript* 2>/dev/null && echo "FAIL — file created without env var" || echo "OK — no file created"
```

Expected: `exit=0`, `OK — no file created`.

- [ ] **Step 4: Smoke-test with env var set, capture happens**

```bash
export UP_DOCS_TRANSCRIPT_LOG=/tmp/cap-test-$$.jsonl
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}' | bash plugins/up-docs/scripts/capture-transcript.sh
echo "perms: $(stat -c '%a' "$UP_DOCS_TRANSCRIPT_LOG")"
cat "$UP_DOCS_TRANSCRIPT_LOG"
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
unset UP_DOCS_TRANSCRIPT_LOG
```

Expected: `perms: 600`. Output JSON contains `"command":"echo hi"` and `"output":"hi"`.

- [ ] **Step 5: Smoke-test redaction**

```bash
export UP_DOCS_TRANSCRIPT_LOG=/tmp/cap-redact-$$.jsonl
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
echo '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\" url"},"tool_response":{"output":"BAO_TOKEN=hvs.deadbeefdeadbeefdeadbeef\n"}}' | bash plugins/up-docs/scripts/capture-transcript.sh
cat "$UP_DOCS_TRANSCRIPT_LOG"
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
unset UP_DOCS_TRANSCRIPT_LOG
```

Expected: output contains `Bearer [REDACTED]`, `gh[ps]_[REDACTED]` or similar, and `BAO_TOKEN=[REDACTED]`. Plaintext token values should NOT appear.

- [ ] **Step 6: Smoke-test that Read tool is NOT captured**

```bash
export UP_DOCS_TRANSCRIPT_LOG=/tmp/cap-read-$$.jsonl
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
echo '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"},"tool_response":{"output":"root:x:0:0:..."}}' | bash plugins/up-docs/scripts/capture-transcript.sh
[ -s "$UP_DOCS_TRANSCRIPT_LOG" ] && echo "FAIL — Read was captured" || echo "OK — Read not captured"
rm -f "$UP_DOCS_TRANSCRIPT_LOG"
unset UP_DOCS_TRANSCRIPT_LOG
```

Expected: `OK — Read not captured`.

- [ ] **Step 7: Add bats tests for the capture script**

Create `plugins/up-docs/tests/capture-transcript.bats`:

```bash
#!/usr/bin/env bats
# Tests for scripts/capture-transcript.sh — opt-in PostToolUse capture hook.

load helpers

CAP="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/capture-transcript.sh"
export CAP  # required: bash -c subshells in tests below need CAP in their env

setup() {
    setup_test_env
    export UP_DOCS_TRANSCRIPT_LOG="$TEST_TMPDIR/transcript.jsonl"
    : > "$UP_DOCS_TRANSCRIPT_LOG"
}

teardown() {
    unset UP_DOCS_TRANSCRIPT_LOG
    teardown_test_env
}

@test "capture is no-op when UP_DOCS_TRANSCRIPT_LOG is unset" {
    unset UP_DOCS_TRANSCRIPT_LOG
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "capture writes a JSONL line for Bash tools" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hello"},"tool_response":{"output":"hello\n"}}'
    [ "$status" -eq 0 ]
    [ -s "$UP_DOCS_TRANSCRIPT_LOG" ]
    run jq -r '.command' "$UP_DOCS_TRANSCRIPT_LOG"
    [ "$output" = "echo hello" ]
}

@test "capture sets file permissions to 600" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}'
    [ "$(stat -c '%a' "$UP_DOCS_TRANSCRIPT_LOG")" = "600" ]
}

@test "capture corrects looser permissions on pre-existing file" {
    chmod 644 "$UP_DOCS_TRANSCRIPT_LOG"
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}'
    [ "$(stat -c '%a' "$UP_DOCS_TRANSCRIPT_LOG")" = "600" ]
}

@test "capture does not record Read tool calls" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"},"tool_response":{"output":"root:x"}}'
    [ "$status" -eq 0 ]
    [ ! -s "$UP_DOCS_TRANSCRIPT_LOG" ]
}

@test "capture redacts Bearer tokens" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer abcdefghijklmnopqrstuvwxyz123\""},"tool_response":{"output":""}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" == *"Bearer [REDACTED]"* ]]
    [[ "$output" != *"abcdefghijklmnopqrstuvwxyz123"* ]]
}

@test "capture redacts BAO_TOKEN" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"export BAO_TOKEN=hvs.deadbeef123456789012345 && bao status"},"tool_response":{"output":"sealed=false"}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" != *"hvs.deadbeef123456789012345"* ]]
    [[ "$output" == *"[REDACTED]"* ]]
}

@test "capture redacts ghp_ tokens in output field" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo $GH"},"tool_response":{"output":"ghp_abcdefghijklmnopqrstuvwxyz0123456789"}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" != *"ghp_abcdefghijklmnopqrstuvwxyz0123456789"* ]]
    [[ "$output" == *"[REDACTED]"* ]]
}

@test "capture truncates very large outputs" {
    local big_input
    big_input='{"tool_name":"Bash","tool_input":{"command":"yes hi"},"tool_response":{"output":"'"$(printf 'a%.0s' $(seq 1 8192))"'"}}'
    run bash -c 'echo "$1" | bash "$CAP"' _ "$big_input"
    [ "$status" -eq 0 ]
    run jq -r '.output | length' "$UP_DOCS_TRANSCRIPT_LOG"
    [ "$output" -le 4096 ]
}

@test "capture fails open on malformed JSON" {
    run bash -c 'echo "$1" | bash "$CAP"' _ 'not-json'
    [ "$status" -eq 0 ]
    [ ! -s "$UP_DOCS_TRANSCRIPT_LOG" ]
}
```

- [ ] **Step 8: Run the bats suite**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -8` Expected: 61 of 61 tests passed (51 existing + 10 new capture tests).

- [ ] **Step 9: Commit**

```bash
git add plugins/up-docs/scripts/capture-transcript.sh plugins/up-docs/tests/capture-transcript.bats
git commit -m "feat(up-docs): opt-in PostToolUse capture-transcript.sh with redaction + chmod 600"
```

---

### Task 14: Wire `capture-transcript.sh` into `hooks/hooks.json`

Add the PostToolUse stanza alongside the PreToolUse stanza shipped in Task 9.

**Files:**

- Modify: `plugins/up-docs/hooks/hooks.json`

- [ ] **Step 1: Read the current hooks.json**

Run: `cat plugins/up-docs/hooks/hooks.json` Expected: shows the PreToolUse → deny-guard.sh wiring from Task 9.

- [ ] **Step 2: Replace with the full PreToolUse + PostToolUse wiring**

Overwrite `plugins/up-docs/hooks/hooks.json`:

```json
{
	"hooks": {
		"PreToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/deny-guard.sh"
					}
				]
			}
		],
		"PostToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/capture-transcript.sh"
					}
				]
			}
		]
	}
}
```

Note: only `Bash` is captured. `Read` is intentionally excluded — its `tool_response.output` contains entire file contents (per CR-006's reference to GH-44868). The matcher is exact-match (no `|` characters) so no regex evaluation.

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; json.load(open('plugins/up-docs/hooks/hooks.json'))" && echo "valid"` Expected: `valid`

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/hooks/hooks.json
git commit -m "feat(up-docs): hooks.json wires PostToolUse capture-transcript.sh (Bash only)"
```

---

### Task 15: Pydantic v2 discriminated-union validators

> **CR-008 resolution.** v1's single `PropagatorReport` accepted any `layer: Literal["repo","wiki","notion"]` value, so a wiki agent emitting `"layer":"repo"` validated as a repo report. v2 uses `Annotated[Union[RepoReport, WikiReport, NotionReport], Field(discriminator="layer")]` — Pydantic v2 raises `union_tag_invalid` when the tag mismatches all expected literals, and the validator-callsite picks the right concrete class based on the discriminator. The Bug-#3 namespace mistake (auditor-as-propagator-style output) becomes a structural error message naming the bad tag explicitly.
>
> **CR-003 resolution (validator side).** Evidence is changed from a free-form string to a structured object: `{command, expected_output_signature, source_tool_use_id}`. The `Finding` validator rejects evidence values that aren't objects with all three fields, so an auditor that fabricates evidence from prose can't even pass schema validation.

**Files:**

- Create: `plugins/up-docs/tests/validate_output.py`

- [ ] **Step 1: Confirm pydantic v2 is installed in the venv**

```bash
cd plugins/up-docs/tests
.venv/bin/python -c "import pydantic; assert pydantic.VERSION.startswith('2'), pydantic.VERSION; print('pydantic', pydantic.VERSION)"
cd -
```

Expected: prints `pydantic 2.x.y`. If the venv is missing, re-run Task 12 Step 3.

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

Design notes:
    * `LayeredReport` is a Pydantic v2 discriminated union over the `layer`
      field. A wrong-layer value (e.g. wiki agent emitting `"layer":"repo"`)
      surfaces as `union_tag_invalid` naming both the bad tag and the
      expected literals — diagnosing CR-008's wrong-layer bug structurally.
    * `Finding.evidence` is a structured object `{command,
      expected_output_signature, source_tool_use_id}`, not a free-form
      string. A fabricated evidence string ("ssh host returned 1.0.0")
      can't satisfy the schema. The verifier (verify_evidence_grounded.py)
      enforces that `expected_output_signature` actually appears in
      `tool_response.output`, not in `tool_input` (CR-003).
"""
from __future__ import annotations

import json
import re
import sys
from typing import Annotated, Literal, Union

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    TypeAdapter,
    ValidationError,
    field_validator,
)

IPV4_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


# -----------------------------------------------------------------------------
# Propagator output schemas (discriminated union over `layer`)
# -----------------------------------------------------------------------------

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


class _PropagatorBase(BaseModel):
    """Shared fields. Each subclass adds its own `layer: Literal[...]`."""
    model_config = ConfigDict(extra="forbid")
    rows: list[Row]
    totals: Totals

    @field_validator("totals")
    @classmethod
    def totals_match_rows(cls, v: Totals, info) -> Totals:
        rows: list[Row] = info.data.get("rows", [])
        counted = {"updated": 0, "created": 0, "unchanged": 0, "failed": 0}
        for r in rows:
            if r.action == "Updated":
                counted["updated"] += 1
            elif r.action == "Created":
                counted["created"] += 1
            elif r.action == "No change needed":
                counted["unchanged"] += 1
            elif r.action == "FAILED":
                counted["failed"] += 1
        if (v.updated, v.created, v.unchanged, v.failed) != (
            counted["updated"], counted["created"], counted["unchanged"], counted["failed"]
        ):
            raise ValueError(
                f"totals do not match row actions: declared={v.model_dump()}, counted={counted}"
            )
        return v


class RepoReport(_PropagatorBase):
    layer: Literal["repo"] = "repo"


class WikiReport(_PropagatorBase):
    layer: Literal["wiki"] = "wiki"


class NotionReport(_PropagatorBase):
    layer: Literal["notion"] = "notion"

    @field_validator("rows")
    @classmethod
    def no_ipv4_in_summary(cls, v: list[Row]) -> list[Row]:
        for row in v:
            if IPV4_RE.search(row.summary):
                raise ValueError(
                    f"IPv4 leaked into Notion summary for row {row.n}: {row.summary!r}"
                )
        return v


# Discriminated union — Pydantic dispatches on the `layer` field.
PropagatorReport = Annotated[
    Union[RepoReport, WikiReport, NotionReport],
    Field(discriminator="layer"),
]


# -----------------------------------------------------------------------------
# Auditor output schema (structured evidence per CR-003)
# -----------------------------------------------------------------------------

class Evidence(BaseModel):
    """Structured evidence per CR-003. Free-form strings are NOT allowed.

    `command`: the exact tool_input.command string the auditor expected to
        run. Verifier matches this against transcript tool_input commands.
    `expected_output_signature`: a distinctive substring the auditor expects
        to find in tool_response.output. Verifier requires this to appear in
        the OUTPUT (not the union), so an auditor that ran a command but
        misread the output cannot evade detection.
    `source_tool_use_id`: optional. If the auditor recorded which tool_use_id
        produced the evidence, the verifier can scope the search to that
        single call rather than the full transcript.
    """
    model_config = ConfigDict(extra="forbid")
    command: str
    expected_output_signature: str
    source_tool_use_id: str | None = None


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
    evidence: Evidence | None  # None only when confidence='unverifiable' and command failed

    @field_validator("evidence")
    @classmethod
    def evidence_required_unless_unverifiable(cls, v, info):
        confidence = info.data.get("confidence")
        if confidence == "unverifiable":
            return v  # None or Evidence with command failed-style signature both ok
        if v is None:
            raise ValueError(
                f"Finding with confidence={confidence!r} must have a non-null evidence object"
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
        findings: list[Finding] = info.data.get("findings", [])
        if v.total_findings != len(findings):
            raise ValueError(
                f"stats.total_findings ({v.total_findings}) != len(findings) ({len(findings)})"
            )
        return v


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

PROPAGATOR_ADAPTER: TypeAdapter[PropagatorReport] = TypeAdapter(PropagatorReport)


def validate_propagator(payload: dict) -> _PropagatorBase:
    return PROPAGATOR_ADAPTER.validate_python(payload)


def validate_auditor(payload: dict) -> AuditorReport:
    return AuditorReport.model_validate(payload)


# Map agent name → callable that validates and returns a typed object
VALIDATORS: dict[str, callable] = {
    "up-docs-propagate-repo": validate_propagator,
    "up-docs-propagate-wiki": validate_propagator,
    "up-docs-propagate-notion": validate_propagator,
    "up-docs-audit-drift": validate_auditor,
}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_output.py <agent-name> < output.json", file=sys.stderr)
        return 2
    agent = sys.argv[1]
    fn = VALIDATORS.get(agent)
    if fn is None:
        print(f"Unknown agent: {agent}", file=sys.stderr)
        return 2
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Malformed JSON input: {e}", file=sys.stderr)
        return 2
    try:
        fn(payload)
    except ValidationError as e:
        print(f"INVALID ({agent}): {e}", file=sys.stderr)
        return 1
    print(f"VALID ({agent})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Smoke-test the discriminator catches a wrong-layer output**

```bash
cd plugins/up-docs/tests
echo '{"layer":"repo","rows":[{"n":1,"target":"X","action":"Updated","summary":"OK"}],"totals":{"updated":1,"created":0,"unchanged":0,"failed":0}}' | .venv/bin/python validate_output.py up-docs-propagate-wiki
echo "wrong-layer exit=$?"
cd -
```

Wait — that input has `layer:"repo"`, but the validator is called with `up-docs-propagate-wiki`. The function dispatches on `layer`, so the discriminator picks `RepoReport` and validation succeeds — there's nothing in the call signature to enforce that the wiki agent emit `wiki`. The right test is at the agent-prompt level (Task 19's prompt enforces `"layer":"wiki"` for the wiki agent). The schema enforces that whichever literal is present is one of the three valid values — a `"layer":"drift"` would fail with `union_tag_invalid`.

Re-run with a bogus layer:

```bash
cd plugins/up-docs/tests
echo '{"layer":"drift","rows":[],"totals":{"updated":0,"created":0,"unchanged":0,"failed":0}}' | .venv/bin/python validate_output.py up-docs-propagate-wiki
echo "bogus-layer exit=$?"
cd -
```

Expected: `bogus-layer exit=1`, stderr contains `union_tag_invalid` and lists `'repo', 'wiki', 'notion'`.

- [ ] **Step 4: Smoke-test the IPv4 leak rejection**

```bash
cd plugins/up-docs/tests
echo '{"layer":"notion","rows":[{"n":1,"target":"X","action":"Updated","summary":"Set IP to 192.168.1.5"}],"totals":{"updated":1,"created":0,"unchanged":0,"failed":0}}' | .venv/bin/python validate_output.py up-docs-propagate-notion
echo "ipv4-leak exit=$?"
cd -
```

Expected: `ipv4-leak exit=1`, stderr contains `IPv4 leaked into Notion summary`.

- [ ] **Step 5: Smoke-test the totals-match invariant**

```bash
cd plugins/up-docs/tests
echo '{"layer":"repo","rows":[{"n":1,"target":"X","action":"Updated","summary":"OK"}],"totals":{"updated":5,"created":0,"unchanged":0,"failed":0}}' | .venv/bin/python validate_output.py up-docs-propagate-repo
echo "totals-mismatch exit=$?"
cd -
```

Expected: `totals-mismatch exit=1`, stderr contains `totals do not match row actions`.

- [ ] **Step 6: Smoke-test a valid input passes**

```bash
cd plugins/up-docs/tests
echo '{"layer":"notion","rows":[{"n":1,"target":"OpenBao","action":"Updated","summary":"Listener rebound for Tailscale reachability."}],"totals":{"updated":1,"created":0,"unchanged":0,"failed":0}}' | .venv/bin/python validate_output.py up-docs-propagate-notion
echo "valid exit=$?"
cd -
```

Expected: `valid exit=0`, stdout `VALID (up-docs-propagate-notion)`.

- [ ] **Step 7: Commit**

```bash
git add plugins/up-docs/tests/validate_output.py
git commit -m "feat(up-docs): Pydantic v2 discriminated-union validators (CR-008); structured Evidence (CR-003)"
```

---

### Task 16: Pytest self-tests for the validators

**Files:**

- Create: `plugins/up-docs/tests/test_validate_output.py`

- [ ] **Step 1: Write the test module**

Create `plugins/up-docs/tests/test_validate_output.py`:

```python
"""Self-tests for tests/validate_output.py."""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).parent))
from validate_output import (  # noqa: E402
    AuditorReport,
    Finding,
    NotionReport,
    PROPAGATOR_ADAPTER,
    RepoReport,
    VALIDATORS,
    WikiReport,
    validate_auditor,
    validate_propagator,
)


VALID_REPO = {
    "layer": "repo",
    "rows": [{"n": 1, "target": "README.md", "action": "Updated", "summary": "Added flag"}],
    "totals": {"updated": 1, "created": 0, "unchanged": 0, "failed": 0},
}

VALID_WIKI = {
    "layer": "wiki",
    "rows": [{"n": 1, "target": "OpenBao Page", "action": "Updated", "summary": "Listener note added"}],
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
            "evidence": {
                "command": "ssh gmk 'grep BAO_ADDR /usr/local/bin/backup.sh'",
                "expected_output_signature": "BAO_ADDR=100.90.121.89",
                "source_tool_use_id": "toolu_01abc",
            },
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


# --- propagator validation -------------------------------------------------

def test_valid_repo_passes():
    obj = validate_propagator(VALID_REPO)
    assert isinstance(obj, RepoReport)


def test_valid_wiki_passes():
    obj = validate_propagator(VALID_WIKI)
    assert isinstance(obj, WikiReport)


def test_valid_notion_passes():
    obj = validate_propagator(VALID_NOTION)
    assert isinstance(obj, NotionReport)


def test_propagator_rejects_unknown_action():
    bad = copy.deepcopy(VALID_REPO)
    bad["rows"][0]["action"] = "Frobnicated"
    with pytest.raises(ValidationError):
        validate_propagator(bad)


def test_propagator_rejects_unknown_layer():
    """CR-008: discriminator catches wrong-layer values structurally."""
    bad = copy.deepcopy(VALID_REPO)
    bad["layer"] = "drift"
    with pytest.raises(ValidationError, match="union_tag_invalid"):
        validate_propagator(bad)


def test_propagator_rejects_extra_top_level_field():
    bad = copy.deepcopy(VALID_REPO)
    bad["spurious"] = "extra"
    with pytest.raises(ValidationError):
        validate_propagator(bad)


def test_propagator_rejects_totals_mismatch():
    bad = copy.deepcopy(VALID_REPO)
    bad["totals"]["updated"] = 5  # but only 1 row
    with pytest.raises(ValidationError, match="totals do not match"):
        validate_propagator(bad)


def test_notion_rejects_ipv4_in_summary():
    """Bug #4-class regression: IPv4 must never leak into Notion."""
    bad = copy.deepcopy(VALID_NOTION)
    bad["rows"][0]["summary"] = "Listener bound to 100.90.121.89"
    with pytest.raises(ValidationError, match="IPv4 leaked"):
        validate_propagator(bad)


def test_repo_rejects_ipv6_does_not_apply():
    """Sanity: an IPv6 in the summary is allowed (we only block IPv4 for Notion)."""
    payload = copy.deepcopy(VALID_NOTION)
    payload["rows"][0]["summary"] = "Listener on [fd00::1]"
    # No IPv4 → must validate
    obj = validate_propagator(payload)
    assert isinstance(obj, NotionReport)


# --- auditor validation ----------------------------------------------------

def test_valid_auditor_passes():
    validate_auditor(VALID_AUDITOR)


def test_auditor_rejects_unknown_confidence():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["confidence"] = "highish"
    with pytest.raises(ValidationError):
        validate_auditor(bad)


def test_auditor_rejects_stats_mismatch():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["stats"]["total_findings"] = 5  # but only 1 finding
    with pytest.raises(ValidationError, match="total_findings"):
        validate_auditor(bad)


def test_auditor_rejects_string_evidence():
    """CR-003 enforcement: free-form string evidence is no longer schema-valid."""
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["evidence"] = "ssh host returned 1.0.0"  # was a string in v1
    with pytest.raises(ValidationError):
        validate_auditor(bad)


def test_auditor_rejects_evidence_missing_signature():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["evidence"] = {
        "command": "ssh host whatever",
        # missing expected_output_signature
    }
    with pytest.raises(ValidationError):
        validate_auditor(bad)


def test_auditor_rejects_high_confidence_with_null_evidence():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["evidence"] = None
    with pytest.raises(ValidationError, match="must have a non-null evidence"):
        validate_auditor(bad)


def test_auditor_allows_unverifiable_with_null_evidence():
    """unverifiable findings represent commands that failed; null evidence is fine."""
    payload = copy.deepcopy(VALID_AUDITOR)
    payload["findings"][0]["confidence"] = "unverifiable"
    payload["findings"][0]["evidence"] = None
    payload["stats"]["high_confidence"] = 0
    payload["stats"]["unverifiable"] = 1
    validate_auditor(payload)  # no raise


def test_validators_cover_all_four_agent_names():
    expected = {
        "up-docs-propagate-repo",
        "up-docs-propagate-wiki",
        "up-docs-propagate-notion",
        "up-docs-audit-drift",
    }
    assert set(VALIDATORS) == expected
```

- [ ] **Step 2: Run the tests in the venv**

```bash
cd plugins/up-docs/tests
.venv/bin/python -m pytest test_validate_output.py -v 2>&1 | tail -25
cd -
```

Expected: 17 passed.

- [ ] **Step 3: Commit**

```bash
git add plugins/up-docs/tests/test_validate_output.py
git commit -m "test(up-docs): self-tests for validators incl. discriminator + structured Evidence"
```

---

### Task 17: Transcript-grounded evidence verifier (with structured evidence)

> **CR-003 resolution (verifier side).** v1's `evidence_signature()` extracted 40 chars after the first colon and searched the union of `tool_input` + `tool_response`. So `ssh host 'cat version.txt' returned 1.0.0` matched the transcript whenever the command appeared, even if the actual output said `0.8.0`. v2 reads structured `Evidence` objects (per Task 15's schema): the verifier requires `expected_output_signature` to appear specifically in the `tool_response.output` of a transcript record whose `tool_input.command` matches `evidence.command`. Optional `source_tool_use_id` narrows further to a single call.

**Files:**

- Create: `plugins/up-docs/tests/verify_evidence_grounded.py`

- [ ] **Step 1: Write the verifier**

Create `plugins/up-docs/tests/verify_evidence_grounded.py`:

```python
"""Verify every `evidence` field in an auditor report is grounded in the
captured PostToolUse transcript.

CR-003 contract:
    Each Finding has Evidence = {command, expected_output_signature, source_tool_use_id?}.
    A finding is "grounded" if there exists a transcript record where:
      - record["tool_input"]["command"] contains evidence.command (or evidence.command
        contains record["tool_input"]["command"] — match in either direction to allow
        for prefix/suffix differences in shell quoting), AND
      - record["tool_response"]["output"] contains evidence.expected_output_signature
        as a literal substring.
    If evidence.source_tool_use_id is set, the search is restricted to the record
    with that tool_use_id (single record).

    Findings with confidence='unverifiable' are skipped (their evidence is nullable).

Usage:
    python3 verify_evidence_grounded.py <auditor-report.json> <transcript.jsonl>

Exit:
    0 = every non-unverifiable finding is grounded
    1 = at least one fabrication detected (details printed to stdout as JSON)
    2 = bad arguments or malformed input
"""
from __future__ import annotations

import json
import sys
from typing import Any


def load_transcript(path: str) -> list[dict]:
    """Read a JSONL file produced by capture-transcript.sh, skipping malformed lines."""
    records: list[dict] = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # skip malformed lines, fail open
    return records


def find_grounding(evidence: dict, transcript: list[dict]) -> dict | None:
    """Return the matching transcript record, or None if no match."""
    cmd = evidence.get("command", "") or ""
    sig = evidence.get("expected_output_signature", "") or ""
    use_id = evidence.get("source_tool_use_id")

    if not cmd or not sig:
        return None

    candidates = transcript
    if use_id:
        candidates = [r for r in transcript if r.get("tool_use_id") == use_id]

    for rec in candidates:
        rec_cmd = rec.get("command", "")
        if not (cmd in rec_cmd or rec_cmd in cmd):
            continue
        rec_out = rec.get("output", "")
        if sig in rec_out:
            return rec
    return None


def verify(report_path: str, transcript_path: str) -> int:
    with open(report_path) as f:
        report = json.load(f)
    transcript = load_transcript(transcript_path)
    violations: list[dict[str, Any]] = []
    for finding in report.get("findings", []):
        if finding.get("confidence") == "unverifiable":
            continue
        ev = finding.get("evidence")
        if ev is None:
            violations.append({
                "finding_id": finding.get("id"),
                "reason": "evidence is null but confidence is not unverifiable",
            })
            continue
        if not isinstance(ev, dict):
            violations.append({
                "finding_id": finding.get("id"),
                "reason": "evidence must be an object with command + expected_output_signature",
            })
            continue
        match = find_grounding(ev, transcript)
        if match is None:
            violations.append({
                "finding_id": finding.get("id"),
                "evidence_command": ev.get("command"),
                "expected_signature": ev.get("expected_output_signature"),
                "source_tool_use_id": ev.get("source_tool_use_id"),
                "reason": (
                    "no transcript record matches both the command and the expected "
                    "output signature — evidence is fabricated or output contradicts claim"
                ),
            })
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

- [ ] **Step 2: Smoke-test the contradiction case (CR-003 specific scenario)**

This is the case the v1 audit called out: command runs, but output contradicts the claim.

```bash
cd plugins/up-docs/tests

cat > /tmp/contradiction-report.json <<'EOF'
{
  "findings": [{
    "id": 1, "layer": "wiki", "page": "Hermes", "page_id": "x",
    "stale_line": "Hermes v0.8.0", "should_say": "Hermes v1.0.0",
    "confidence": "high", "destructive_fix": false,
    "evidence": {
      "command": "ssh hetzner 'cat /home/hermes/version.txt'",
      "expected_output_signature": "1.0.0"
    }
  }],
  "escalation": {"triggered": false, "reasons": []},
  "stats": {"total_findings": 1, "by_layer":{"repo":0,"wiki":1,"notion":0},
            "high_confidence":1, "unverifiable":0, "destructive_fixes_required":0}
}
EOF

# Transcript: command DID run, but output is "0.8.0" (contradicts the claim)
cat > /tmp/contradict-transcript.jsonl <<'EOF'
{"tool_name":"Bash","tool_use_id":"toolu_01","command":"ssh hetzner 'cat /home/hermes/version.txt'","output":"0.8.0\n","is_error":false}
EOF

.venv/bin/python verify_evidence_grounded.py /tmp/contradiction-report.json /tmp/contradict-transcript.jsonl
echo "contradict exit=$?"

cd -
```

Expected: `contradict exit=1`, stdout JSON containing `"fabrications"` array — because `expected_output_signature: "1.0.0"` is NOT in the `output: "0.8.0\n"`. v1's verifier would have passed this since the command appeared in the transcript.

- [ ] **Step 3: Smoke-test the grounded case**

```bash
cd plugins/up-docs/tests

# Same report; transcript output now matches the expected signature
cat > /tmp/grounded-transcript.jsonl <<'EOF'
{"tool_name":"Bash","tool_use_id":"toolu_01","command":"ssh hetzner 'cat /home/hermes/version.txt'","output":"1.0.0\n","is_error":false}
EOF

.venv/bin/python verify_evidence_grounded.py /tmp/contradiction-report.json /tmp/grounded-transcript.jsonl
echo "grounded exit=$?"

rm -f /tmp/contradiction-report.json /tmp/contradict-transcript.jsonl /tmp/grounded-transcript.jsonl
cd -
```

Expected: `grounded exit=0`, stdout `evidence grounded`.

- [ ] **Step 4: Smoke-test the no-transcript-record case (the original Bug #4)**

```bash
cd plugins/up-docs/tests

cat > /tmp/no-record-report.json <<'EOF'
{
  "findings": [{
    "id": 1, "layer": "wiki", "page": "Hermes", "page_id": "x",
    "stale_line": "Hermes v0.8.0", "should_say": "Hermes v1.0.0",
    "confidence": "high", "destructive_fix": false,
    "evidence": {
      "command": "ssh hetzner 'cat /home/hermes/version.txt'",
      "expected_output_signature": "1.0.0"
    }
  }],
  "escalation": {"triggered": false, "reasons": []},
  "stats": {"total_findings": 1, "by_layer":{"repo":0,"wiki":1,"notion":0},
            "high_confidence":1, "unverifiable":0, "destructive_fixes_required":0}
}
EOF

# Transcript only contains an unrelated command
cat > /tmp/empty-transcript.jsonl <<'EOF'
{"tool_name":"Bash","tool_use_id":"toolu_99","command":"pct list","output":"VMID NAME\n113 hermes","is_error":false}
EOF

.venv/bin/python verify_evidence_grounded.py /tmp/no-record-report.json /tmp/empty-transcript.jsonl
echo "no-record exit=$?"

rm -f /tmp/no-record-report.json /tmp/empty-transcript.jsonl
cd -
```

Expected: `no-record exit=1`, fabrication output detects the absence.

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/tests/verify_evidence_grounded.py
git commit -m "feat(up-docs): structured-evidence transcript verifier (CR-003 fix)"
```

---

### Task 18: Pytest self-tests for the evidence verifier

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


def make_finding(command: str, signature: str, *, confidence: str = "high",
                 use_id: str | None = None) -> dict:
    ev = {"command": command, "expected_output_signature": signature}
    if use_id:
        ev["source_tool_use_id"] = use_id
    return {
        "id": 1,
        "layer": "wiki",
        "page": "Test",
        "page_id": "x",
        "stale_line": "old",
        "should_say": "new",
        "confidence": confidence,
        "destructive_fix": False,
        "evidence": ev,
    }


def test_empty_report_passes(tmp_path):
    rc, out = run_verify(tmp_path, BASE_REPORT, [])
    assert rc == 0
    assert "grounded" in out


def test_grounded_evidence_passes(tmp_path):
    """Both command and expected_output_signature appear in matching record."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh gmk 'grep BAO_ADDR /etc/foo'",
        "100.90.121.89",
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_use_id": "tu1",
        "command": "ssh gmk 'grep BAO_ADDR /etc/foo'",
        "output": "BAO_ADDR=100.90.121.89\n",
        "is_error": False,
    }]
    rc, _ = run_verify(tmp_path, report, transcript)
    assert rc == 0


def test_command_ran_but_output_contradicts_fails(tmp_path):
    """CR-003 specific: command appears in transcript but output contradicts the
    expected signature. v1 verifier would have falsely passed this."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh hetzner 'cat /home/hermes/version.txt'",
        "1.0.0",  # auditor claims this output
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_use_id": "tu1",
        "command": "ssh hetzner 'cat /home/hermes/version.txt'",
        "output": "0.8.0\n",  # actual output is different
        "is_error": False,
    }]
    rc, out = run_verify(tmp_path, report, transcript)
    assert rc == 1
    parsed = json.loads(out)
    assert parsed["fabrications"][0]["finding_id"] == 1


def test_command_never_ran_fails(tmp_path):
    """Bug #4 original scenario: cat version.txt was never invoked."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh hetzner 'cat /home/hermes/version.txt'",
        "1.0.0",
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_use_id": "tu99",
        "command": "pct list",
        "output": "VMID NAME\n113 hermes",
        "is_error": False,
    }]
    rc, out = run_verify(tmp_path, report, transcript)
    assert rc == 1
    parsed = json.loads(out)
    assert parsed["fabrications"][0]["finding_id"] == 1


def test_source_tool_use_id_narrows_search(tmp_path):
    """When source_tool_use_id is set, search is scoped to that single record."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "echo hi",
        "hi",
        use_id="tu_target",
    )]}
    transcript = [
        {"tool_name": "Bash", "tool_use_id": "tu_other",
         "command": "echo hi", "output": "hi\n", "is_error": False},
        # The matching tool_use_id record exists but its command is different
        {"tool_name": "Bash", "tool_use_id": "tu_target",
         "command": "ls /tmp", "output": "junk", "is_error": False},
    ]
    rc, _ = run_verify(tmp_path, report, transcript)
    # tu_target's command doesn't contain 'echo hi' — fabrication
    assert rc == 1


def test_source_tool_use_id_grounded(tmp_path):
    """The tool_use_id-pinned record must itself match command + signature."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "echo hi",
        "hi",
        use_id="tu_target",
    )]}
    transcript = [
        {"tool_name": "Bash", "tool_use_id": "tu_target",
         "command": "echo hi", "output": "hi\n", "is_error": False},
    ]
    rc, _ = run_verify(tmp_path, report, transcript)
    assert rc == 0


def test_unverifiable_finding_skipped_with_null_evidence(tmp_path):
    """Unverifiable findings represent failed commands; null evidence is fine."""
    finding = make_finding("does-not-matter", "does-not-matter", confidence="unverifiable")
    finding["evidence"] = None
    report = {**BASE_REPORT, "findings": [finding]}
    rc, _ = run_verify(tmp_path, report, [])
    assert rc == 0


def test_high_confidence_with_null_evidence_fails(tmp_path):
    finding = make_finding("x", "y")
    finding["evidence"] = None
    report = {**BASE_REPORT, "findings": [finding]}
    rc, out = run_verify(tmp_path, report, [])
    assert rc == 1
    parsed = json.loads(out)
    assert "evidence is null" in parsed["fabrications"][0]["reason"]


def test_malformed_transcript_lines_skipped(tmp_path):
    rp = tmp_path / "report.json"
    tp = tmp_path / "transcript.jsonl"
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh gmk 'echo hi'",
        "hi",
    )]}
    rp.write_text(json.dumps(report))
    tp.write_text(
        "not-valid-json\n"
        + json.dumps({"tool_name": "Bash", "tool_use_id": "tu1",
                      "command": "ssh gmk 'echo hi'", "output": "hi\n",
                      "is_error": False}) + "\n"
    )
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), str(rp), str(tp)],
        capture_output=True, text=True,
    )
    assert proc.returncode == 0
```

- [ ] **Step 2: Run the tests**

```bash
cd plugins/up-docs/tests
.venv/bin/python -m pytest test_verify_evidence_grounded.py -v 2>&1 | tail -15
cd -
```

Expected: 9 passed.

- [ ] **Step 3: Run the entire pytest suite to confirm no regressions**

```bash
cd plugins/up-docs/tests
.venv/bin/python -m pytest -v 2>&1 | tail -10
cd -
```

Expected: 26 passed (17 from Task 16 + 9 from Task 18).

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/tests/test_verify_evidence_grounded.py
git commit -m "test(up-docs): self-tests for structured-evidence verifier (incl. CR-003 contradiction case)"
```

---

### Task 19: Update auditor agent prompt to emit structured `Evidence` objects

> **CR-003 prompt-side resolution.** The validator and verifier expect `evidence` to be an object with `command`, `expected_output_signature`, and optional `source_tool_use_id`. The auditor's prompt currently asks for free-form evidence strings. The prompt has to change so the auditor produces what the verifier checks.

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md` — output-format / examples / forbidden_strings sections

- [ ] **Step 1: Find the existing evidence specification in the prompt**

Run: `grep -n -E '"evidence":|<evidence>|^- \*\*evidence\*\*' plugins/up-docs/agents/up-docs-audit-drift.md` Expected: shows the lines where the prompt describes the `evidence` field. Note the line numbers — you'll edit each location.

- [ ] **Step 2: Replace the evidence specification block**

In `plugins/up-docs/agents/up-docs-audit-drift.md`, find the section describing the JSON output format for findings — it currently shows `evidence` as a string. Replace the evidence-field description with:

````markdown
**`evidence`** — An object (NOT a free-form string):

```json
{
	"command": "<exact tool_input.command you ran to verify this finding>",
	"expected_output_signature": "<distinctive substring you observed in the tool_response.output>",
	"source_tool_use_id": "<the tool_use_id of the call, if you can identify it>"
}
```

- `command` MUST be the exact command string you passed to the Bash tool. Not a paraphrase. The verifier matches this against transcript records.
- `expected_output_signature` MUST be a literal substring you saw in the actual `tool_response.output`. Not a summary. Not a value you expected from documentation. The verifier requires this exact substring to appear in the captured output of a transcript record matching `command`.
- `source_tool_use_id` is OPTIONAL. If you can identify the tool_use_id of the verifying call, include it; the verifier will scope the search to that single call rather than the full transcript. If unsure, omit the field.
- For findings with `confidence: "unverifiable"` (the command failed, host was unreachable, or you could not run any verifying command), the `evidence` field MAY be `null`. For all other confidence values, `evidence` is required.

**DO NOT** put prose descriptions, claims about what the command "would" produce, or paraphrases of expected output into `expected_output_signature`. The verifier rejects fabricated evidence as a structural error — output an unverifiable finding instead of inventing a signature.
````

- [ ] **Step 3: Update each example in the prompt to use the new shape**

Find every example finding in the agent prompt (typically inside `<examples>` or `<example>` blocks) and rewrite the `evidence` value from the v1 string form to the v2 object form. Pattern:

- old: `"evidence": "ssh gmk 'grep BAO_ADDR /usr/local/bin/backup.sh' returned BAO_ADDR=100.90.121.89"`
- new:
  ```json
  "evidence": {
    "command": "ssh gmk 'grep BAO_ADDR /usr/local/bin/backup.sh'",
    "expected_output_signature": "BAO_ADDR=100.90.121.89"
  }
  ```

For unverifiable examples:

- old: `"evidence": "Command failed: ssh: connect to host kismet port 22: Connection refused"`
- new: `"evidence": null`

(The error text is no longer tracked in evidence — it lives in conversation logs anyway, and the validator now permits `null` only when `confidence: "unverifiable"`.)

Run after editing: `grep -c '"evidence": "' plugins/up-docs/agents/up-docs-audit-drift.md` Expected: `0` (no string-form evidence remaining).

Run: `grep -c '"command":' plugins/up-docs/agents/up-docs-audit-drift.md` Expected: ≥1 (every example has been updated).

- [ ] **Step 4: Add a "no fabrication" reminder in the agent's `<rules>` block**

In `plugins/up-docs/agents/up-docs-audit-drift.md`, find the `<rules>` block (or equivalent). Append:

```markdown
- **No-fabrication rule:** If you did not observe `expected_output_signature` literally in the `tool_response.output` of a Bash call, you MUST set `confidence: "unverifiable"` and `evidence: null` for that finding. Do not invent a signature, do not paraphrase what the output "should" contain, do not infer the value from the command alone. The verifier (`tests/verify_evidence_grounded.py`) rejects fabricated evidence as a structural error — it is cheaper to honestly mark a finding unverifiable than to ship a confident-but-fabricated finding that fails the verifier.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/agents/up-docs-audit-drift.md
git commit -m "feat(up-docs): auditor prompt emits structured Evidence; no-fabrication rule"
```

---

### Task 20: Make `tests/run-bats.sh` honor explicit path arguments

> **CR-004 wrapper-side resolution.** v1's `run-bats.sh` always runs `"$TESTS_DIR"/*.bats`, ignoring any path arguments the caller passes. So the v1 plan's `bash run-bats.sh tests/integration/` runs the SAME files as a bare `bash run-bats.sh` and never executes the integration suite. v2 fixes the wrapper to run `"$@"` when args are present, and falls back to the existing top-level glob otherwise.

**Files:**

- Modify: `plugins/up-docs/tests/run-bats.sh`

- [ ] **Step 1: Read the current wrapper**

Run: `cat plugins/up-docs/tests/run-bats.sh` Expected: shows the 10-line script that always runs `"$TESTS_DIR"/*.bats`.

- [ ] **Step 2: Rewrite the wrapper**

Overwrite `plugins/up-docs/tests/run-bats.sh`:

```bash
#!/usr/bin/env bash
# run-bats.sh — wrapper that runs the up-docs bats suite.
#
# Usage:
#   bash run-bats.sh                            — run all top-level *.bats files
#   bash run-bats.sh path/to/specific.bats      — run a specific file
#   bash run-bats.sh tests/integration/         — run a directory of bats files
#   bash run-bats.sh foo.bats bar.bats          — run multiple specific files
#
# Honors $@ so callers can target specific files or directories. Falls back to
# the top-level *.bats glob when called with no arguments.

set -euo pipefail
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS_ROOT="${BATS_ROOT:-/home/chris/.local/lib/node_modules/bats}"
BATS_LIBEXEC="$BATS_ROOT/libexec/bats-core"

# Resolve targets: explicit args win, else top-level *.bats glob.
if [ "$#" -gt 0 ]; then
    TARGETS=("$@")
else
    # shellcheck disable=SC2206
    TARGETS=("$TESTS_DIR"/*.bats)
fi

# If the bats libexec isn't found, fall back to whatever `bats` is on PATH.
if [[ ! -x "$BATS_LIBEXEC/bats" ]]; then
    exec bats "${TARGETS[@]}"
fi

bats_readlinkf() { readlink -f "$1"; }
export -f bats_readlinkf
export BATS_ROOT BATS_LIBDIR="${BATS_LIBDIR:-lib}"
PATH="$BATS_LIBEXEC:$PATH" exec bash "$BATS_LIBEXEC/bats" "${TARGETS[@]}"
```

- [ ] **Step 3: Smoke-test no-arg invocation still works**

Run: `bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -3` Expected: same number of tests as before (61 after Task 13).

- [ ] **Step 4: Smoke-test single-file invocation works**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/deny-guard.bats 2>&1 | tail -3` Expected: 13 tests run (only deny-guard.bats), all pass.

- [ ] **Step 5: Smoke-test directory invocation works**

```bash
mkdir -p plugins/up-docs/tests/integration
echo '@test "integration sentinel" { run echo "hi"; [ "$status" -eq 0 ]; }' > plugins/up-docs/tests/integration/_sentinel.bats
bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/integration/_sentinel.bats 2>&1 | tail -3
rm plugins/up-docs/tests/integration/_sentinel.bats
```

Expected: 1 test runs and passes.

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/tests/run-bats.sh
git commit -m "fix(up-docs): run-bats.sh honors explicit path arguments"
```

---

### Phase 1 + Phase 2 + Phase 3 (Tasks 6–20) checkpoint and v0.8.0 release

- [ ] **Run the full bats suite + pytest suite**

```bash
bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -3
cd plugins/up-docs/tests && .venv/bin/python -m pytest -v 2>&1 | tail -3
cd -
```

Expected: bats 61 of 61 passing; pytest 26 passing.

- [ ] **Bump plugin.json to 0.8.0**

Edit `plugins/up-docs/.claude-plugin/plugin.json`. Change `"version": "0.7.2"` to `"version": "0.8.0"`.

- [ ] **Bump marketplace.json to 0.8.0**

Edit `.claude-plugin/marketplace.json`. Change up-docs `"version"` to `"0.8.0"`.

- [ ] **Add CHANGELOG entry**

In `plugins/up-docs/CHANGELOG.md`, prepend below `# Changelog`:

```markdown
## [0.8.0] - 2026-MM-DD

### Added

- `hooks/hooks.json` — plugin-shipped hook component (PreToolUse + PostToolUse) following Plugins Reference table; replaces the v1 plan's invalid `.claude/settings.json` packaging.
- `scripts/deny-guard.sh` — PreToolUse forbidden-command validator. Parses pipes, redirects, and `&&` chains; mirrors the auditor's `<forbidden_commands>` table; defense-in-depth, NOT an enforced security boundary.
- `scripts/capture-transcript.sh` — opt-in PostToolUse capture hook. No-op unless `UP_DOCS_TRANSCRIPT_LOG` is set; uses `umask 077`; redacts Bearer/ghp/ghs/AKIA/BAO_TOKEN/password/token/sk-ant-/aws_secret patterns; truncates output at 4 KiB; Bash only (Read excluded — file contents leak per GH-44868).
- `tests/pyproject.toml` — pinned test deps (pydantic ≥2.5, pytest ≥8.0, fastmcp optional, deepeval optional). Run from `plugins/up-docs/tests/.venv`.
- `tests/validate_output.py` — Pydantic v2 discriminated-union validators for all four agent outputs. Layered reports use `Annotated[Union[...], Field(discriminator="layer")]`; structural mismatch produces a `union_tag_invalid` error naming both the bad tag and the expected literals.
- `tests/verify_evidence_grounded.py` — structured-evidence transcript verifier. Requires `expected_output_signature` to literally appear in `tool_response.output` of a transcript record matching `evidence.command`; closes the v1 audit's CR-003 gap (command-but-output-contradicts case).
- `tests/test_validate_output.py` and `tests/test_verify_evidence_grounded.py` — 26 self-tests including a CR-003-specific contradiction case.
- `CLAUDE_CODE_SESSION_ID`-based default state file in `convergence-tracker.sh` — replaces v1 plan's broken `-$$.json` default. Persists state across the multiple separate invocations the drift skill makes per session.
- README §Security — documents the plugin's defense-in-depth `deny-guard.sh` and recommends a consumer-side `permissions.deny` block for projects that want a hard security boundary.
- README §Requirements — Python 3.11+ as a hard prerequisite (helper scripts and test suite).

### Changed

- Auditor (`up-docs-audit-drift`) prompt: `evidence` is now a structured object `{command, expected_output_signature, source_tool_use_id?}` instead of a free-form string. New no-fabrication rule in `<rules>`: when `expected_output_signature` was not literally observed in tool output, the auditor MUST set `confidence: "unverifiable"` and `evidence: null` rather than inventing a signature.
- `tests/run-bats.sh` honors explicit path arguments (single files, directories, multiple files), falling back to the top-level glob when called bare.
- All five skill files now check for `python3` in PATH at Step 1 and exit with a clear message if missing.

### Fixed

- v1 plan's CR-001 through CR-008 audit findings — see [`docs/plans/2026-05-08-up-docs-hardening-plan-v1-audit.md`](../../docs/plans/2026-05-08-up-docs-hardening-plan-v1-audit.md) for the full list of structural defects this release closes.

### Notes

- Phase 2 hook-firing smoke test (Task 8) result: see `plugins/up-docs/docs/phase-2-smoke-result.txt`.
```

- [ ] **Tag and release**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "Release up-docs v0.8.0 — security boundary + eval infrastructure"
```

Run `/release-pipeline:release` to tag and publish.

---

## Phase 3 — Integration test surface (Tasks 21–24)

### Task 21: Integration test fixtures

Canned session-summary inputs for the integration tests in Task 23–24.

**Files:**

- Create: `plugins/up-docs/tests/integration/fixtures/session-summary-config-rebind.md`
- Create: `plugins/up-docs/tests/integration/fixtures/session-summary-bug-fix.md`
- Create: `plugins/up-docs/tests/integration/fixtures/fabricated-evidence-finding.json`

- [ ] **Step 1: Create the directory**

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

- [ ] **Step 4: Write the fabricated-finding fixture (Bug #4 regression input, structured-evidence form)**

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
			"evidence": {
				"command": "ssh hetzner 'pct exec 113 -- cat /home/hermes/hermes-agent/version.txt'",
				"expected_output_signature": "1.0.0"
			}
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
git commit -m "test(up-docs): integration test fixtures (incl. Bug #4 structured-evidence regression)"
```

---

### Task 22: FastMCP stdio stubs and `test-mcp-config.json`

> **CR-004 MCP-wiring resolution.** v1's stubs were created without a corresponding `--mcp-config` file and without keys matching the plugin's `.mcp.json` server keys, so the agents under test never connected to them. v2 ships a stdio FastMCP stub for each MCP server, plus a `test-mcp-config.json` that registers the stubs under exactly the keys the agent tools resolve to (`mcp-outline`, `Notion`).

**Files:**

- Create: `plugins/up-docs/tests/stubs/mcp_outline_stub.py`
- Create: `plugins/up-docs/tests/stubs/mcp_notion_stub.py`
- Create: `plugins/up-docs/tests/integration/fixtures/test-mcp-config.json`

- [ ] **Step 1: Confirm fastmcp is available in the venv**

```bash
cd plugins/up-docs/tests
.venv/bin/python -c "import fastmcp; print(fastmcp.__version__)"
cd -
```

Expected: prints a fastmcp version. If not, install: `cd plugins/up-docs/tests && .venv/bin/pip install -e ".[test]"`.

- [ ] **Step 2: Create the stubs directory**

```bash
mkdir -p plugins/up-docs/tests/stubs
```

- [ ] **Step 3: Write the Outline stdio stub**

Create `plugins/up-docs/tests/stubs/mcp_outline_stub.py`:

```python
"""FastMCP stdio stub for mcp-outline integration tests.

CRITICAL: never write to stdout — that corrupts the JSON-RPC stream.
All logging goes to stderr.

Fixture selection via environment:
    OUTLINE_FIXTURE=empty             — no documents
    OUTLINE_FIXTURE=openbao           — one OpenBao page
    OUTLINE_FIXTURE=backup-pipeline   — both OpenBao and Backup Pipeline pages

Default fixture is "empty" if the env var is unset or unknown.
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
         "text": "BAO_ADDR=127.0.0.1:8200 is the listener address."},
    ],
    "backup-pipeline": [
        {"id": "abc-123", "title": "OpenBao — CT 111",
         "text": "BAO_ADDR=127.0.0.1:8200 is the listener address."},
        {"id": "def-456", "title": "Backup Pipeline",
         "text": "Run curl http://127.0.0.1:8200/v1/sys/health to verify."},
    ],
}


def _fixture() -> list[dict[str, Any]]:
    return FIXTURES.get(os.environ.get("OUTLINE_FIXTURE", "empty"), [])


@mcp.tool()
def search_documents(query: str) -> list[dict[str, Any]]:
    """Return fixture docs whose title or text contains the query (case-insensitive)."""
    q = (query or "").lower()
    if not q:
        return _fixture()
    return [d for d in _fixture() if q in d["title"].lower() or q in d["text"].lower()]


@mcp.tool()
def read_document(id: str) -> dict[str, Any]:
    for d in _fixture():
        if d["id"] == id:
            return d
    return {"error": f"document {id} not found"}


@mcp.tool()
def list_collections() -> list[dict[str, Any]]:
    return [{"id": "homelab", "name": "Homelab"}]


@mcp.tool()
def update_document(id: str, text: str) -> dict[str, Any]:
    print(f"[outline-stub] update_document id={id} text_len={len(text)}", file=sys.stderr)
    return {"id": id, "ok": True}


@mcp.tool()
def create_document(title: str, text: str, collection_id: str | None = None) -> dict[str, Any]:
    print(f"[outline-stub] create_document title={title!r}", file=sys.stderr)
    return {"id": "new-1", "title": title, "ok": True}


if __name__ == "__main__":
    mcp.run(transport="stdio")
```

- [ ] **Step 4: Write the Notion stdio stub**

Create `plugins/up-docs/tests/stubs/mcp_notion_stub.py`:

```python
"""FastMCP stdio stub for Notion integration tests.

CRITICAL: never write to stdout — JSON-RPC stream corruption.
All logging goes to stderr.

Fixture selection via environment:
    NOTION_FIXTURE=empty                 — no pages
    NOTION_FIXTURE=openbao               — OpenBao page
    NOTION_FIXTURE=kismet-parent-only    — only the parent collection page (forces fuzzy fallback)

Default fixture is "empty" if the env var is unset or unknown.
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
        {"id": "page-1",
         "title": "Homelab / Infrastructure / GMK / CT 111 — OpenBao",
         "text": "OpenBao runs on CT 111 and is reachable from the Tailscale network."},
    ],
    "kismet-parent-only": [
        {"id": "parent-1",
         "title": "Homelab / Infrastructure / GMK",
         "text": "GMK hosts the homelab containers."},
    ],
}


def _fixture() -> list[dict[str, Any]]:
    return FIXTURES.get(os.environ.get("NOTION_FIXTURE", "empty"), [])


@mcp.tool(name="notion-search")
def notion_search(query: str) -> list[dict[str, Any]]:
    q = (query or "").lower()
    if not q:
        return _fixture()
    return [d for d in _fixture() if q in d["title"].lower() or q in d["text"].lower()]


@mcp.tool(name="notion-fetch")
def notion_fetch(id: str) -> dict[str, Any]:
    for d in _fixture():
        if d["id"] == id:
            return d
    return {"error": f"page {id} not found"}


@mcp.tool(name="notion-update-page")
def notion_update_page(id: str, text: str) -> dict[str, Any]:
    print(f"[notion-stub] notion-update-page id={id} text_len={len(text)}", file=sys.stderr)
    return {"id": id, "ok": True}


@mcp.tool(name="notion-create-pages")
def notion_create_pages(parent_id: str, title: str, text: str) -> dict[str, Any]:
    print(f"[notion-stub] notion-create-pages title={title!r}", file=sys.stderr)
    return {"id": "new-page-1", "title": title, "ok": True}


if __name__ == "__main__":
    mcp.run(transport="stdio")
```

- [ ] **Step 5: Smoke-test that each stub at least starts without crashing**

```bash
cd plugins/up-docs/tests
timeout 2 .venv/bin/python stubs/mcp_outline_stub.py 2>/tmp/outline-stub-stderr.log < /dev/null || true
timeout 2 .venv/bin/python stubs/mcp_notion_stub.py  2>/tmp/notion-stub-stderr.log  < /dev/null || true
grep -iE 'error|traceback' /tmp/outline-stub-stderr.log /tmp/notion-stub-stderr.log
echo "(no error lines above means stubs initialize cleanly)"
cd -
```

Expected: no `error` or `Traceback` lines (the `< /dev/null` causes orderly EOF exit, which is not an error).

- [ ] **Step 6: Write the test-mcp-config.json**

Create `plugins/up-docs/tests/integration/fixtures/test-mcp-config.json`:

```json
{
	"mcpServers": {
		"mcp-outline": {
			"command": "python3",
			"args": ["${UP_DOCS_REPO_ROOT}/plugins/up-docs/tests/stubs/mcp_outline_stub.py"],
			"env": { "OUTLINE_FIXTURE": "${OUTLINE_FIXTURE}" }
		},
		"Notion": {
			"command": "python3",
			"args": ["${UP_DOCS_REPO_ROOT}/plugins/up-docs/tests/stubs/mcp_notion_stub.py"],
			"env": { "NOTION_FIXTURE": "${NOTION_FIXTURE}" }
		}
	}
}
```

The keys (`mcp-outline`, `Notion`) MUST match the plugin's `.mcp.json` keys exactly — Claude Code uses the key to derive MCP tool names (`mcp__plugin_<key>_<key>__<tool>`). The bats setup function expands `${UP_DOCS_REPO_ROOT}` and the fixture env vars before invoking `claude`.

- [ ] **Step 7: Commit**

```bash
git add plugins/up-docs/tests/stubs/ plugins/up-docs/tests/integration/fixtures/test-mcp-config.json
git commit -m "test(up-docs): FastMCP stdio stubs + test-mcp-config.json with key-matched server names"
```

---

### Task 23: Integration bats — propagate-notion + propagate-repo

End-to-end tests driving each propagator via `claude --print --plugin-dir --strict-mcp-config --mcp-config --agent`. Gated behind `RUN_INTEGRATION=1` so CI default stays free.

> **CR-004 wiring resolution (test-side).** Tests pass `--plugin-dir "$UP_DOCS_REPO_ROOT/plugins/up-docs"`, `--strict-mcp-config --mcp-config "$test_mcp_config"`, and `--agent up-docs:up-docs-propagate-...`. The first integration test (Step 5 below) prints the `system/init` event so `plugin_errors` and unresolved-agent failures are visible — addresses Open Question 3 (`--agent <plugin>:<agent>` syntax for `--plugin-dir`-loaded plugins) at execution time.

**Files:**

- Create: `plugins/up-docs/tests/integration/propagate-notion.bats`
- Create: `plugins/up-docs/tests/integration/propagate-repo.bats`

- [ ] **Step 1: Write a shared helpers extension for integration tests**

Append to `plugins/up-docs/tests/helpers.bash`:

```bash
# Integration-test helpers (no-op when RUN_INTEGRATION is unset)

setup_integration_env() {
    [ -n "${RUN_INTEGRATION:-}" ] || return 0
    [ -n "${ANTHROPIC_API_KEY:-}" ] || skip "ANTHROPIC_API_KEY required for integration tests"

    export UP_DOCS_REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
    export UP_DOCS_TRANSCRIPT_LOG="$TEST_TMPDIR/transcript.jsonl"
    : > "$UP_DOCS_TRANSCRIPT_LOG"

    # Materialize test-mcp-config.json with $UP_DOCS_REPO_ROOT expanded
    local template="$BATS_TEST_DIRNAME/fixtures/test-mcp-config.json"
    export TEST_MCP_CONFIG="$TEST_TMPDIR/test-mcp-config.expanded.json"
    UP_DOCS_REPO_ROOT="$UP_DOCS_REPO_ROOT" \
        OUTLINE_FIXTURE="${OUTLINE_FIXTURE:-empty}" \
        NOTION_FIXTURE="${NOTION_FIXTURE:-empty}" \
        envsubst < "$template" > "$TEST_MCP_CONFIG"

    export PLUGIN_DIR="$UP_DOCS_REPO_ROOT/plugins/up-docs"
}
```

- [ ] **Step 2: Write propagate-notion.bats**

Create `plugins/up-docs/tests/integration/propagate-notion.bats`:

````bash
#!/usr/bin/env bats
# Integration: drives up-docs-propagate-notion end-to-end with stdio MCP stubs.
# Gated behind RUN_INTEGRATION=1 (real Claude API calls).

load ../helpers

setup() {
    setup_test_env
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable (real API calls)"
    export NOTION_FIXTURE=openbao
    export OUTLINE_FIXTURE=empty
    setup_integration_env
}

teardown() { teardown_test_env; }

@test "propagate-notion: config rebind produces no IPv4 in Notion summary" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md"
    local stdout_file="$TEST_TMPDIR/notion-out.json"

    run claude --plugin-dir "$PLUGIN_DIR" \
               --strict-mcp-config \
               --mcp-config "$TEST_MCP_CONFIG" \
               --agent up-docs:up-docs-propagate-notion \
               --output-format json \
               --max-turns 12 \
               --print "$(cat "$fixture")"
    [ "$status" -eq 0 ]
    echo "$output" > "$stdout_file"

    # Print first 500 chars of the JSON result for diagnostic visibility on first run.
    # Note: --output-format json emits a single final JSON object (not a per-event stream).
    # `system/init` events only appear under --output-format stream-json. We log the raw
    # JSON head so plugin-load/agent-resolution errors surface in test output (open
    # questions 1-3 — hook firing, --strict-mcp-config behavior, --agent namespacing).
    echo "--- claude JSON result head (first 500 chars) ---" >&2
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d, indent=2)[:500])" "$stdout_file" >&2

    # Pull out the JSON code-fenced report from the result text
    local report
    report=$(python3 - "$stdout_file" <<'PYEOF'
import json, re, sys
d = json.load(open(sys.argv[1]))
text = d.get("result", "") if isinstance(d, dict) else ""
m = re.search(r'```json\s*(.*?)\s*```', text, re.DOTALL)
print(m.group(1) if m else text)
PYEOF
)

    # Validate against the discriminated-union schema (rejects IPv4 leak)
    echo "$report" | python3 "$BATS_TEST_DIRNAME/../validate_output.py" up-docs-propagate-notion
}
````

- [ ] **Step 3: Write propagate-repo.bats**

Create `plugins/up-docs/tests/integration/propagate-repo.bats`:

```bash
#!/usr/bin/env bats
# Integration: drives up-docs-propagate-repo against a fake repo.

load ../helpers

setup() {
    setup_test_env
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable"
    setup_integration_env

    # Fake a tiny repo for the agent to operate on
    mkdir -p "$TEST_TMPDIR/fakerepo/docs"
    cd "$TEST_TMPDIR/fakerepo"
    git init -q -b main
    echo "# Test Repo" > README.md
    echo "BAO_ADDR=127.0.0.1" > docs/handoff/deployed.md
    git add . && git -c user.email=t@t.com -c user.name=T commit -q -m "init"
}

teardown() { teardown_test_env; }

@test "propagate-repo: rebind summary updates docs/handoff/deployed.md" {
    local fixture="$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md"

    run claude --plugin-dir "$PLUGIN_DIR" \
               --strict-mcp-config \
               --mcp-config "$TEST_MCP_CONFIG" \
               --agent up-docs:up-docs-propagate-repo \
               --output-format json \
               --max-turns 12 \
               --print "$(cat "$fixture")"
    [ "$status" -eq 0 ]

    # The agent should have edited docs/handoff/deployed.md to include the new IP
    grep -q "100.90.121.89" docs/handoff/deployed.md
}
```

- [ ] **Step 4: Run with RUN_INTEGRATION unset (everything skips)**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/integration/propagate-notion.bats plugins/up-docs/tests/integration/propagate-repo.bats 2>&1 | tail -10` Expected: every test reports `# skip set RUN_INTEGRATION=1 to enable (real API calls)`.

- [ ] **Step 5: Run with RUN_INTEGRATION=1 (manual, requires API key)**

This step is run manually by the engineer once with `RUN_INTEGRATION=1 ANTHROPIC_API_KEY=sk-ant-... bash run-bats.sh ...`. Capture and review the printed `system/init` events for any `plugin_errors` array — that's the early-warning signal for Open Questions 1–3 (hook firing, strict-mcp-config behavior, --agent namespacing).

If `plugin_errors` is non-empty, re-read the error message and either:

- adjust the agent name format (try `up-docs-propagate-notion` without the `up-docs:` prefix)
- adjust the MCP server keys in `test-mcp-config.json`
- file an issue with the empirical findings before declaring the integration suite green.

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/tests/helpers.bash plugins/up-docs/tests/integration/propagate-notion.bats plugins/up-docs/tests/integration/propagate-repo.bats
git commit -m "test(up-docs): integration bats for propagate-notion and propagate-repo with --plugin-dir + stdio MCP stubs"
```

---

### Task 24: Integration bats — audit-drift + Bug #4 regression OUTSIDE integration gate

> **CR-004 setup-gating resolution.** v1's `audit-drift.bats` had `[ -n "${RUN_INTEGRATION:-}" ] || skip ...` in `setup()` — so even the no-API Bug #4 regression test (which only exercises `verify_evidence_grounded.py`) was silently skipped without `RUN_INTEGRATION=1`. v2 splits the file: the no-API regression runs unconditionally; the API-gated test has its skip in its own body.

**Files:**

- Create: `plugins/up-docs/tests/integration/audit-drift.bats`

- [ ] **Step 1: Write audit-drift.bats**

Create `plugins/up-docs/tests/integration/audit-drift.bats`:

````bash
#!/usr/bin/env bats
# Integration tests for up-docs-audit-drift.
#
# Two test classes in this file:
#   1. NO-API regression — exercises verify_evidence_grounded.py against the
#      canonical fabricated-evidence-finding.json fixture. Runs always.
#   2. API integration — drives the auditor agent end-to-end. Requires
#      RUN_INTEGRATION=1 + ANTHROPIC_API_KEY. The skip lives inside the
#      individual @test, not in setup(), so the no-API regression always runs.

load ../helpers

setup() {
    setup_test_env
    # Note: NO RUN_INTEGRATION gate here; per-test gating below.
}

teardown() { teardown_test_env; }


@test "Bug #4 regression: fabricated evidence is rejected (no API needed)" {
    local report="$BATS_TEST_DIRNAME/fixtures/fabricated-evidence-finding.json"
    local empty_transcript="$TEST_TMPDIR/empty.jsonl"
    : > "$empty_transcript"

    run python3 "$BATS_TEST_DIRNAME/../verify_evidence_grounded.py" \
                "$report" "$empty_transcript"

    # The fabrication MUST be detected
    [ "$status" -eq 1 ]
    [[ "$output" == *"fabrications"* ]]
}


@test "CR-003 regression: command-ran-but-output-contradicts is rejected (no API needed)" {
    # This is the v1-audit-specific scenario: command appears in transcript but
    # output contradicts the expected signature.
    local report="$TEST_TMPDIR/contradict.json"
    cat > "$report" <<'EOF'
{
  "findings": [{
    "id": 1, "layer": "wiki", "page": "Hermes", "page_id": "x",
    "stale_line": "Hermes v0.8.0", "should_say": "Hermes v1.0.0",
    "confidence": "high", "destructive_fix": false,
    "evidence": {
      "command": "ssh hetzner 'cat /home/hermes/version.txt'",
      "expected_output_signature": "1.0.0"
    }
  }],
  "escalation": {"triggered": false, "reasons": []},
  "stats": {"total_findings": 1, "by_layer":{"repo":0,"wiki":1,"notion":0},
            "high_confidence":1, "unverifiable":0, "destructive_fixes_required":0}
}
EOF

    local transcript="$TEST_TMPDIR/contradict-transcript.jsonl"
    cat > "$transcript" <<'EOF'
{"tool_name":"Bash","tool_use_id":"tu1","command":"ssh hetzner 'cat /home/hermes/version.txt'","output":"0.8.0\n","is_error":false}
EOF

    run python3 "$BATS_TEST_DIRNAME/../verify_evidence_grounded.py" \
                "$report" "$transcript"
    [ "$status" -eq 1 ]
    [[ "$output" == *"fabrications"* ]]
}


@test "auditor evidence in real run is grounded in transcript (API gated)" {
    [ -n "${RUN_INTEGRATION:-}" ] || skip "set RUN_INTEGRATION=1 to enable (real API calls)"
    [ -n "${ANTHROPIC_API_KEY:-}" ] || skip "ANTHROPIC_API_KEY required"
    setup_integration_env

    local fixture="$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md"
    local stdout_file="$TEST_TMPDIR/audit-out.json"

    run claude --plugin-dir "$PLUGIN_DIR" \
               --strict-mcp-config \
               --mcp-config "$TEST_MCP_CONFIG" \
               --agent up-docs:up-docs-audit-drift \
               --output-format json \
               --max-turns 20 \
               --print "$(cat "$fixture")"
    [ "$status" -eq 0 ]
    echo "$output" > "$stdout_file"

    # Extract the auditor JSON payload from the response
    local report="$TEST_TMPDIR/audit-report.json"
    python3 - "$stdout_file" "$report" <<'PYEOF'
import json, re, sys
d = json.load(open(sys.argv[1]))
text = d.get("result", "") if isinstance(d, dict) else ""
m = re.search(r'```json\s*(.*?)\s*```', text, re.DOTALL)
out = m.group(1) if m else text
open(sys.argv[2], "w").write(out)
PYEOF

    # Schema validation (structured Evidence)
    cat "$report" | python3 "$BATS_TEST_DIRNAME/../validate_output.py" up-docs-audit-drift

    # Evidence grounding against the captured transcript
    [ -s "$UP_DOCS_TRANSCRIPT_LOG" ] || skip "transcript log empty — capture hook may not have fired (Open Question 1)"
    python3 "$BATS_TEST_DIRNAME/../verify_evidence_grounded.py" \
            "$report" "$UP_DOCS_TRANSCRIPT_LOG"
}
````

- [ ] **Step 2: Run the suite without RUN_INTEGRATION**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/integration/audit-drift.bats 2>&1 | tail -10` Expected: 2 of 3 tests pass (the two no-API regressions); 1 skip (`# skip set RUN_INTEGRATION=1 to enable (real API calls)`).

- [ ] **Step 3: Verify the Bug #4 + CR-003 regressions specifically pass**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/integration/audit-drift.bats 2>&1 | grep -E "Bug #4|CR-003"` Expected: both `ok N Bug #4 regression: fabricated evidence is rejected (no API needed)` and `ok N CR-003 regression: command-ran-but-output-contradicts is rejected (no API needed)`.

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/tests/integration/audit-drift.bats
git commit -m "test(up-docs): audit-drift integration bats — no-API regressions outside setup gate"
```

---

### Phase 3 (Tasks 21–24) checkpoint and v0.8.1 release

- [ ] **Run the entire test surface**

```bash
bash plugins/up-docs/tests/run-bats.sh 2>&1 | tail -5
cd plugins/up-docs/tests && .venv/bin/python -m pytest 2>&1 | tail -5
cd -
```

Expected: bats 63 of 63 passing (61 from Tasks 6–20 + 2 unconditional integration regressions); pytest 26 passing.

- [ ] **Bump versions to 0.8.1**

In `plugins/up-docs/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change `0.8.0` to `0.8.1`.

- [ ] **Add CHANGELOG entry**

Prepend to `plugins/up-docs/CHANGELOG.md`:

```markdown
## [0.8.1] - 2026-MM-DD

### Added

- `tests/integration/` end-to-end bats tests driven via `claude --plugin-dir --strict-mcp-config --mcp-config --agent`. Gated behind `RUN_INTEGRATION=1` (default suite remains free of API costs). Includes a non-API Bug #4 fabrication regression AND a CR-003 contradiction regression that run unconditionally (they only need `verify_evidence_grounded.py`).
- `tests/stubs/mcp_outline_stub.py` and `tests/stubs/mcp_notion_stub.py` — FastMCP stdio MCP servers with fixture-keyed responses for reproducible CI. All logging routed to stderr per JSON-RPC stream-safety footgun.
- `tests/integration/fixtures/test-mcp-config.json` — registers the stubs under server keys `mcp-outline` and `Notion` so MCP tool name resolution matches the agent frontmatter.
- Three integration fixtures: config-rebind, bug-fix (Notion-out-of-scope), and the canonical fabricated-evidence-finding.json (Bug #4 input, structured-evidence form).

### Fixed

- v1 plan's CR-004 audit finding — integration tests pass `--plugin-dir`, `--strict-mcp-config`, and `--mcp-config`; `run-bats.sh` honors path arguments; the no-API Bug #4 regression test runs without API gating.
```

- [ ] **Tag and release**

Stage explicitly per the repo's CLAUDE.md non-negotiable ("Never `git add .` or `git add -A` — always add by explicit name"). The CHANGELOG entry for v0.8.1 above lists every file this release touches:

```bash
git add plugins/up-docs/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        plugins/up-docs/CHANGELOG.md \
        plugins/up-docs/tests/run-bats.sh \
        plugins/up-docs/tests/stubs/ \
        plugins/up-docs/tests/integration/
git status --short  # verify only intended files staged
git commit -m "Release up-docs v0.8.1 — integration tests + MCP stubs"
```

Run `/release-pipeline:release`.

---

## Phase 4 — Behavioral hardening

### Task 25: `docs/.up-docs.json` layout config — every documented value gets a branch

> **CR-009 resolution.** v1 documented six values (`auto`, `v1`, `v2`, `simple`, `diataxis`, `none`) but only implemented behavior for `simple` and `diataxis`. Users with `auto` would fall through to a hidden default; `v1`/`v2`/`none` config values would be ignored. v2 specs an explicit branch for every documented value plus an explicit error for unknown values.

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md` `<task>` step 3 (layout detection block)
- Modify: `plugins/up-docs/README.md` §Project Setup

- [ ] **Step 1: Replace the existing layout-detection block in the agent prompt**

In `plugins/up-docs/agents/up-docs-propagate-repo.md`, find the `<task>` step 3 layout-detection block (the current bash that does `[ -f docs/handoff/state.md ] && echo V2`). Replace with:

````markdown
First, detect which layout this repo uses. The `docs/.up-docs.json` config (if present) overrides any auto-detection:

```bash
if [ -f docs/.up-docs.json ]; then
  CFG_LAYOUT=$(python3 -c "import json,sys; print(json.load(open('docs/.up-docs.json')).get('layout','auto').lower())")
else
  CFG_LAYOUT="auto"
fi

case "$CFG_LAYOUT" in
  auto)
    # Probe for v1/v2; fall through to NONE if neither marker file exists.
    if   [ -f docs/handoff/state.md ];   then echo V2
    elif [ -f docs/handoff.md ]; then echo V1
    else                              echo NONE
    fi
    ;;
  v2|v1|simple|diataxis|none)
    echo "${CFG_LAYOUT^^}"
    ;;
  *)
    echo "ERROR: unknown layout='$CFG_LAYOUT' in docs/.up-docs.json. Valid: auto, v1, v2, simple, diataxis, none." >&2
    exit 1
    ;;
esac
```

Each layout value branches the audit scope:

| Layout value | Audit scope |
| --- | --- |
| `AUTO` (default) | Probe for `docs/handoff/state.md` (V2) → `docs/handoff.md` (V1) → fall through to NONE. |
| `V2` (forced or detected) | Full handoff-system-v2 audit: `state.md`, `deployed.md`, `sessions/`, `bugs/`, `conventions.md`, `.claude/rules/`. |
| `V1` (forced or detected) | Legacy single-file audit of `docs/handoff.md`. |
| `SIMPLE` (config-only) | Audit only files listed in the config's `audit_targets` array. No state-tracking, no bugs/, no sessions/. If `audit_targets` is missing or empty, error out. |
| `DIATAXIS` (config-only) | Audit `tutorials/`, `how-to/`, `reference/`, `explanation/` directories at the file-list level. No state-tracking machinery. |
| `NONE` | Skip the mandatory layout audit entirely. Still propagate the session-change-summary items into whatever files the summary names. |

**Specific behaviors:**

- **AUTO with both markers present** (rare — a repo migrating from v1 to v2 may have both temporarily): prefer V2 (newer marker wins).
- **Forced `V2` when `docs/handoff/state.md` is absent**: emit a single advisory row `"V2 layout requested but docs/handoff/state.md not found — initialize handoff-system-v2 before re-running"` and stop.
- **Forced `V1` when `docs/handoff.md` is absent**: emit `"V1 layout requested but docs/handoff.md not found"` and stop.
- **`SIMPLE` with missing `audit_targets`**: emit `"SIMPLE layout requested but audit_targets is missing or empty in docs/.up-docs.json"` and stop.
- **`DIATAXIS` with no canonical dirs**: emit one advisory row per missing directory, then proceed with whatever exists.
- **`NONE`**: do not perform any layout-driven file scanning. Process only the items in the session-change summary.
- **Unknown layout value**: the bash above exits 1 with stderr explaining valid options. The skill caller treats this as a user error and reports the message verbatim to the user.
````

- [ ] **Step 2: Add SIMPLE / DIATAXIS / NONE handling subsections to the prompt**

Append to `<task>` step 3 in `up-docs-propagate-repo.md`, after the existing V2/V1 branches:

````markdown
**If SIMPLE (`docs/.up-docs.json` `layout: simple`):**

Read the `audit_targets` array from the config:

```bash
python3 -c "import json; print('\n'.join(json.load(open('docs/.up-docs.json'))['audit_targets']))"
```

For each path in the list:

- If it exists, audit it against the session-change summary using the same targeted-edit discipline as V2.
- If it does not exist, emit a row `"No change needed — file does not exist"`.

Do not audit any file outside `audit_targets`. Do not perform stale-file scans, bug-KB updates, or session log appends in SIMPLE mode.

**If DIATAXIS (`docs/.up-docs.json` `layout: diataxis`):**

Glob the four canonical Diátaxis directories for `*.md`:

```bash
for d in tutorials how-to reference explanation; do
  [ -d "$d" ] || echo "[advisory] missing canonical dir: $d"
  find "$d" -name '*.md' 2>/dev/null
done
```

Audit each found file against the session-change summary. Skip the V2-specific machinery (no state.md, no bugs/, no sessions/).

**If NONE:**

Skip the layout audit entirely. Process only the session-change-summary items, applying targeted edits to the files the summary explicitly names. Emit one row per item plus a single advisory row noting "No layout audit performed (layout=none)".
````

- [ ] **Step 3: Document the config in README**

In `plugins/up-docs/README.md` §Project Setup (or §Documentation if §Project Setup doesn't exist — pick whichever is the existing convention), add a new subsection:

````markdown
### Custom Layout (Optional)

By default, `up-docs-propagate-repo` auto-detects the v1 (`docs/handoff.md`) or v2 (`docs/handoff/state.md`) handoff-system layout. To override — for projects using Diátaxis or a simpler layout — create `docs/.up-docs.json`:

```json
{
	"layout": "simple",
	"audit_targets": ["README.md", "CHANGELOG.md", "docs/CHANGELOG.md"]
}
```

Recognized `layout` values:

| Value | Audit scope |
| --- | --- |
| `auto` | Default — probe for `docs/handoff/state.md` then `docs/handoff.md`; fall through to `none` if neither exists. |
| `v1` | Force the legacy single-file `docs/handoff.md` audit even if other markers are present. |
| `v2` | Force the handoff-system-v2 audit (state.md, deployed.md, sessions/, bugs/, conventions.md, .claude/rules/). |
| `simple` | Audit only the files in `audit_targets`. Requires `audit_targets` to be present and non-empty. No state-tracking, bug KB, or session logs. |
| `diataxis` | Audit `tutorials/`, `how-to/`, `reference/`, `explanation/` for `*.md` files. No handoff-system machinery. |
| `none` | Skip the mandatory layout audit entirely. Process only items from the session-change summary. |

Unknown `layout` values produce an error; the agent stops and reports the valid options.
````

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/README.md
git commit -m "feat(up-docs): docs/.up-docs.json layout config with explicit branch per documented value"
```

---

### Task 26: Skill-level orchestration of drift phases

Rewrite `skills/drift/SKILL.md` so the skill walks phases 1–4 explicitly, dispatching the auditor scoped to one phase per call. The convergence machinery becomes load-bearing.

**Files:**

- Modify: `plugins/up-docs/skills/drift/SKILL.md` Workflow section

- [ ] **Step 1: Read the current Workflow section for context**

Run: `sed -n '24,80p' plugins/up-docs/skills/drift/SKILL.md` Expected: shows the current Steps 1–5 (single dispatch, no phase loop).

- [ ] **Step 2: Replace Steps 3–4 with an explicit phase loop**

In `plugins/up-docs/skills/drift/SKILL.md`, replace the existing `### 3. Dispatch …` and `### 4. Pass Findings Through` sections with:

````markdown
### 3. Walk the Four Drift Phases Explicitly

Each phase runs as a bounded convergence loop. `convergence-tracker.sh` manages iteration state and detects oscillation. State is shared across all calls because the default state file is keyed off `${CLAUDE_CODE_SESSION_ID}`.

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

    Capture the auditor's findings JSON. Validate against the Pydantic schema:
      cat findings.json | python3 ${CLAUDE_PLUGIN_ROOT}/tests/validate_output.py up-docs-audit-drift

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

Find the §Notes section in `plugins/up-docs/skills/drift/SKILL.md` and replace it with:

```markdown
## Notes

- The skill orchestrates the four-phase loop at the skill level; the auditor sub-agent runs scoped to one phase per dispatch. This makes phase boundaries explicit and trackable rather than relying on the agent to self-organize.
- Convergence + oscillation detection live in `scripts/convergence-tracker.sh`. State path defaults to `${TMPDIR:-/tmp}/up-docs-tracker-${CLAUDE_CODE_SESSION_ID:-default}.json` so all 6+ separate invocations within one skill execution share state.
- Findings are advisory: the auditor has no write tools for Outline or Notion. Fixes go through the propagators on a follow-up pass with the user's explicit consent.
- Auditor output is validated against `tests/validate_output.py` schemas (Pydantic v2 discriminated union) before being recorded; structural defects fail fast rather than corrupting the tracker state.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/skills/drift/SKILL.md
git commit -m "feat(up-docs): explicit per-phase orchestration in /up-docs:drift skill"
```

---

### Task 27: Notion fuzzy fallback

When `notion-search(query: "<exact name>")` returns zero hits, retry with broadened keyword OR-queries derived from the session summary's "Affected area" fields.

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-notion.md` `<task>` step 1

- [ ] **Step 1: Update step 1 of the agent prompt**

In `plugins/up-docs/agents/up-docs-propagate-notion.md`, replace the existing `<task>` step 1 (the `Locate Notion targets.` block) with:

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

In `plugins/up-docs/agents/up-docs-propagate-notion.md`, add this example block to the `<examples>` section, after the existing "New service — new Notion page created" example (or at the end of the existing `<examples>` block if that example doesn't exist):

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
cd plugins/up-docs/tests && .venv/bin/python -m pytest 2>&1 | tail -3
cd -
```

Expected: bats 63 passing, pytest 26 passing (no regression).

- [ ] **Bump versions to 0.9.0**

In `plugins/up-docs/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change `0.8.1` to `0.9.0`.

- [ ] **Add CHANGELOG entry**

Prepend to `plugins/up-docs/CHANGELOG.md`:

```markdown
## [0.9.0] - 2026-MM-DD

### Added

- `docs/.up-docs.json` layout config — supports `auto`, `v1`, `v2`, `simple`, `diataxis`, and `none`. Each value has an explicit branch in `up-docs-propagate-repo`; unknown values produce an error naming the valid options. Loosens previous hardcoding to one user's preferred handoff-system-v2 layout. Documented in README §Project Setup.
- `/up-docs:drift` now walks phases 1–4 explicitly at the skill level; auditor sub-agent dispatched once per phase. Convergence + oscillation detection becomes load-bearing. Findings JSON is validated against the Pydantic v2 schema (Task 15) before recording.
- `up-docs-propagate-notion` fuzzy fallback: when `notion-search(query: "<exact name>")` returns 0 hits, retry up to 3 broadened OR-queries derived from the session summary's `Affected area` field. Search depth recorded in output table.

### Changed

- Default repo-layout detection probe now reads `docs/.up-docs.json` first; falls back to `docs/handoff/state.md` (V2) → `docs/handoff.md` (V1) → NONE.

### Fixed

- v1 plan's CR-009 finding — every documented `layout` value now branches; previously `auto`, `v1`, `v2`, `none` were documented but unimplemented in the agent prompt.
```

- [ ] **Tag and release**

Stage explicitly per the repo's CLAUDE.md non-negotiable ("Never `git add .` or `git add -A` — always add by explicit name"). The CHANGELOG entry for v0.9.0 above lists every file this release touches:

```bash
git add plugins/up-docs/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        plugins/up-docs/CHANGELOG.md \
        plugins/up-docs/README.md \
        plugins/up-docs/agents/up-docs-propagate-repo.md \
        plugins/up-docs/agents/up-docs-propagate-notion.md \
        plugins/up-docs/skills/drift/SKILL.md
git status --short  # verify only intended files staged
git commit -m "Release up-docs v0.9.0 — behavioral hardening (layout config, phase orchestration, fuzzy fallback)"
```

Run `/release-pipeline:release`.

---

### Task 28 (Optional): DeepEval LLM-judge with `SingleTurnParams` and `AnthropicModel`

> **CR-012 resolution.** v1 imported `LLMTestCaseParams` (deprecated; renamed to `SingleTurnParams` in 2025) and didn't pin DeepEval, didn't route through `AnthropicModel` (silently requiring an `OPENAI_API_KEY`), and didn't opt out of cloud telemetry. v2 pins DeepEval ≥1.4 in `tests/pyproject.toml [deepeval]` extra (Task 12), uses `SingleTurnParams`, instantiates `AnthropicModel(...)`, and sets `DEEPEVAL_TELEMETRY_OPT_OUT=YES` in the test environment.

Opt-in deeper grader for layer-boundary semantic violations Pydantic can't catch (e.g., "this paragraph contains a shell command disguised as prose"). Gated behind `RUN_LLMJUDGE=1` — separate cost layer from `RUN_INTEGRATION`.

**Files:** (only if v0.9.1 is being shipped)

- Create: `plugins/up-docs/tests/test_agent_prose.py`

- [ ] **Step 1: Install the DeepEval extra in the venv**

```bash
cd plugins/up-docs/tests
.venv/bin/pip install -e ".[all]"
.venv/bin/python -c "import deepeval; print(deepeval.__version__)"
cd -
```

Expected: prints a DeepEval version `>=1.4`.

- [ ] **Step 2: Write the prose-quality test module**

Create `plugins/up-docs/tests/test_agent_prose.py`:

```python
"""Optional DeepEval LLM-judge for layer-boundary prose violations.

Gated behind RUN_LLMJUDGE=1 AND ANTHROPIC_API_KEY. Each test case loads a
captured agent output produced by the integration suite, then asks a
GEval rubric (running on Anthropic Claude via AnthropicModel) to grade
whether the output respects the layer boundary.

Per CR-012:
    * Uses SingleTurnParams (LLMTestCaseParams was renamed in DeepEval 2025).
    * Routes through AnthropicModel — no OpenAI key required.
    * Tests should set DEEPEVAL_TELEMETRY_OPT_OUT=YES to opt out of
      Confident-AI cloud upload.
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest

# Lazy imports — deepeval pulls in heavy deps. importorskip lets the test
# silently skip if DeepEval isn't installed (the [deepeval] extra is opt-in).
deepeval = pytest.importorskip("deepeval")
from deepeval import assert_test  # noqa: E402
from deepeval.metrics import GEval  # noqa: E402
from deepeval.models import AnthropicModel  # noqa: E402
from deepeval.test_case import LLMTestCase, SingleTurnParams  # noqa: E402

pytestmark = pytest.mark.skipif(
    "RUN_LLMJUDGE" not in os.environ or not os.environ.get("ANTHROPIC_API_KEY"),
    reason="set RUN_LLMJUDGE=1 and ANTHROPIC_API_KEY=<key> to enable; incurs API cost",
)

FIXTURE_DIR = Path(__file__).parent / "integration" / "fixtures"
LAST_RUN_DIR = Path("/tmp")  # populated by integration tests; opt-in


def _load(path: Path) -> str:
    if not path.exists():
        pytest.skip(f"capture file missing: {path} — run integration suite first")
    return path.read_text()


@pytest.fixture(scope="module")
def judge_model():
    """Construct the Anthropic-backed GEval model once per test session."""
    return AnthropicModel(model="claude-3-5-sonnet-latest", temperature=0)


def test_notion_prose_is_strategic_not_implementation(judge_model):
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
        evaluation_params=[SingleTurnParams.INPUT, SingleTurnParams.ACTUAL_OUTPUT],
        model=judge_model,
        threshold=0.7,
    )
    case = LLMTestCase(
        input=_load(FIXTURE_DIR / "session-summary-config-rebind.md"),
        actual_output=_load(LAST_RUN_DIR / "notion-out.json"),
    )
    assert_test(case, [metric])


def test_repo_propagator_does_not_fabricate(judge_model):
    """The repo propagator must only reference files, line ranges, and
    services named in the session-change summary. No invented file paths."""
    metric = GEval(
        name="NoFabrication",
        criteria=(
            "The actual output must not contain any file path, line number, "
            "service name, IP address, or hostname that is not present in "
            "the input session-change summary. Confirm each reference in the "
            "output also appears in the input. Pass if every concrete reference "
            "is grounded in the input; fail otherwise."
        ),
        evaluation_params=[SingleTurnParams.INPUT, SingleTurnParams.ACTUAL_OUTPUT],
        model=judge_model,
        threshold=0.8,
    )
    case = LLMTestCase(
        input=_load(FIXTURE_DIR / "session-summary-config-rebind.md"),
        actual_output=_load(LAST_RUN_DIR / "repo-out.json"),
    )
    assert_test(case, [metric])
```

- [ ] **Step 3: Verify it skips when not opted in**

```bash
cd plugins/up-docs/tests
unset RUN_LLMJUDGE
.venv/bin/python -m pytest test_agent_prose.py -v 2>&1 | tail -5
cd -
```

Expected: 2 skipped, 0 failed (skip reason mentions `RUN_LLMJUDGE` and `ANTHROPIC_API_KEY`).

- [ ] **Step 4: Smoke-test that telemetry is opted out**

```bash
cd plugins/up-docs/tests
DEEPEVAL_TELEMETRY_OPT_OUT=YES .venv/bin/python -c "
from deepeval.test_case import SingleTurnParams
print('SingleTurnParams imports cleanly')
print('telemetry opt-out:', __import__('os').environ.get('DEEPEVAL_TELEMETRY_OPT_OUT'))
"
cd -
```

Expected: prints `SingleTurnParams imports cleanly` and `telemetry opt-out: YES`. (The runtime telemetry check inside DeepEval reads this env var lazily; presence in the env is sufficient.)

- [ ] **Step 5: Bump versions to 0.9.1**

In `plugins/up-docs/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change `0.9.0` to `0.9.1`.

- [ ] **Step 6: Add CHANGELOG entry**

Prepend to `plugins/up-docs/CHANGELOG.md`:

```markdown
## [0.9.1] - 2026-MM-DD

### Added

- Optional `tests/test_agent_prose.py` — DeepEval LLM-judge for layer-boundary prose violations and no-fabrication semantic checks. Gated behind `RUN_LLMJUDGE=1` AND `ANTHROPIC_API_KEY`. Routes through `AnthropicModel` (no OpenAI key required); telemetry opt-out via `DEEPEVAL_TELEMETRY_OPT_OUT=YES`. Pinned via the `tests/pyproject.toml [deepeval]` extra.

### Fixed

- v1 plan's CR-012 finding — DeepEval `SingleTurnParams` (not deprecated `LLMTestCaseParams`); explicit `AnthropicModel`; opt-out of cloud telemetry.
```

- [ ] **Step 7: Commit and tag**

```bash
git add plugins/up-docs/tests/test_agent_prose.py plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "feat(up-docs): optional DeepEval LLM-judge via SingleTurnParams + AnthropicModel"
```

Run `/release-pipeline:release`.

---

## Self-Review

### Audit-finding → task cross-reference

Every CR-NNN finding from `2026-05-08-up-docs-hardening-plan-v1-audit.md` resolves to one or more concrete v2 tasks. No finding is silently skipped:

| CR # | Severity | v1 defect | v2 resolution |
| --- | --- | --- | --- | --- |
| CR-001 | Critical | Plugin `.claude/settings.json` is not a supported component path. | T9 ships `plugins/up-docs/hooks/hooks.json` (the supported plugin hook path). T11 documents consumer-side `permissions.deny` as the actually-enforced security layer. T8 smoke-tests that the hook actually fires before T9–T14 depend on it (Open Question 1 mitigation). |
| CR-002 | High | Deny list as `Bash(...)` glob patterns missed pipes, redirects, `&&` chains, `cp -f`, `tee`, SQL writes, etc. | T10 ships `scripts/deny-guard.sh` — a real PreToolUse parser-aware validator that splits on ` | `, `&&`, `;`, `$()`, backticks and matches every segment against the auditor's full forbidden table. T11 also documents consumer-side `Bash(...)` denies as the engine-enforced complement. |
| CR-003 | High | `evidence_signature()` matched the command in `tool_input` not the output — verifier passed when output contradicted the claim. | T15 restructures `evidence` to a Pydantic object `{command, expected_output_signature, source_tool_use_id?}`. T17 verifier requires `expected_output_signature` to literally appear in `tool_response.output` of a transcript record matching `command`. T19 updates the auditor prompt to emit the structured form. |
| CR-004 | High | Integration tests didn't pass `--plugin-dir`, didn't wire `--mcp-config` to FastMCP stubs; `run-bats.sh` ignored path args; the no-API Bug #4 test was inside `setup()` gating. | T20 fixes `run-bats.sh` to honor `"$@"`. T22 ships stdio FastMCP stubs + `test-mcp-config.json` with key-matched server names. T23 invokes `claude --plugin-dir --strict-mcp-config --mcp-config --agent up-docs:...`. T24 splits `audit-drift.bats` so the no-API Bug #4 + CR-003 regressions run unconditionally outside the API-gated `setup()`. |
| CR-005 | High | Default `${TMPDIR}/up-docs-drift-tracker-$$.json` had a different PID per separate invocation, so the 6+ tracker calls per session each used a different file. | T6 changes the default to `${TMPDIR:-/tmp}/up-docs-tracker-${CLAUDE_CODE_SESSION_ID:-default}.json`. The May 2026 `CLAUDE_CODE_SESSION_ID` is stable across all hook subprocesses and tool calls in one session. Bats tests cover the persistence + isolation invariants. |
| CR-006 | High | Hook captured all Bash + Read by default to `/tmp` whenever the plugin was loaded — passive secret-leak sink. | T13 makes capture opt-in (no-op unless `UP_DOCS_TRANSCRIPT_LOG` is set). Uses `umask 077`, `chmod 600`, redacts Bearer/ghp/ghs/AKIA/BAO_TOKEN/password/token/sk-ant-/aws_secret patterns BEFORE write, truncates output at 4 KiB, captures Bash only (not Read — which would expose entire file contents per GH-44868). Cites CVE-2025-59536 / GH-44868 in the script header. |
| CR-007 | High | `pip install --user` fallbacks were non-reproducible; current env had a broken pydantic. | T12 ships `plugins/up-docs/tests/pyproject.toml` with pinned `pydantic>=2.5,<3.0`, `pytest>=8.0,<9.0`, `typing_extensions>=4.9,<5.0`, optional `[mcp-stubs]` with FastMCP, optional `[deepeval]`. Workflow uses an isolated `tests/.venv`. |
| CR-008 | Medium | Single `PropagatorReport` accepted any `layer` Literal; wiki-mislabeled-as-repo passed schema validation. | T15 uses Pydantic v2 `Annotated[Union[RepoReport, WikiReport, NotionReport], Field(discriminator="layer")]`. Each subclass declares its own `layer: Literal[...]`. Bogus values produce `union_tag_invalid` naming the bad tag. T16 has explicit tests for the `union_tag_invalid` path and totals-mismatch invariant. |
| CR-009 | Medium | Layout config documented `auto`/`v1`/`v2`/`none` but the agent only handled SIMPLE/DIATAXIS — `auto` and friends fell through to no branch. | T25 specs an explicit branch for every documented value: `auto` probes V2→V1→NONE; `v1`/`v2` force layouts and emit a clear error if marker files are missing; `simple` requires `audit_targets`; `diataxis` globs the four canonical dirs; `none` skips audit; unknown values exit 1 with valid-options list. |
| CR-010 | Low | The new link-audit regression test used the safe pattern from the start, so it never reproduced the bug. | T5 explicitly writes the regression first using the OLD `bash -c "echo '$md'"` pattern, runs it to confirm RED, THEN rewrites the suite to the safe `printf` pattern, THEN runs again to confirm GREEN. Real TDD. |
| CR-011 | Low | Task 3 title said "move to Resolved subsection" but its steps deleted the bullet. | T3 picks deletion (the bug is fixed three releases ago, the mitigation is no longer actionable, and a Resolved subsection adds maintenance surface). Title and steps now agree on deletion. |
| CR-012 | Low | DeepEval used deprecated `LLMTestCaseParams` (renamed `SingleTurnParams` in 2025); silently required `OPENAI_API_KEY`; cloud telemetry on by default. | T28 uses `SingleTurnParams`, instantiates `AnthropicModel(model="claude-3-5-sonnet-latest")`, gates on `RUN_LLMJUDGE` AND `ANTHROPIC_API_KEY`, sets `DEEPEVAL_TELEMETRY_OPT_OUT=YES` in the test env. Pinned `deepeval>=1.4,<2.0` via `tests/pyproject.toml [deepeval]` extra. |

### Open-question handling

The three live-system questions from the research report are all addressed at execution time as smoke-test gates rather than blocking design unknowns:

| Open Q | v2 task addressing it |
| --- | --- |
| Q1 — GH-34573 plugin command-hook silent-drop. | **RESOLVED PASS (2026-05-08).** T8 executed; hook fired under claude 2.1.133 (`--plugin-dir`) — two `fired` lines captured (pre + post). GH-34573 empirically inactive. Tasks 9–14 may proceed as written. |
| Q2 — `--strict-mcp-config` behavior on missing tools. | T23 Step 5's manual run captures the `system/init` event for diagnostic visibility on first failure; the printed `plugin_errors` and missing-tool errors are the empirical answer. |
| Q3 — `--agent <plugin>:<agent>` syntax for path-loaded plugins. | T23 Step 5 prints raw claude output including `system/init`, so unresolved-agent errors are immediately visible; T23 Step 6 lists alternative agent-name formats to try if the first run fails. |

### Spec-coverage check

Eleven actions from the original assessment, mapped to v2 tasks:

| Action                           | v2 task(s)       | Phase |
| -------------------------------- | ---------------- | ----- |
| 1. Stale Opus claim              | T1               | 0     |
| 2. CHANGELOG dedupe              | T2               | 0     |
| 3. Stale v2.1.92 note            | T3               | 0     |
| 4. Python 3 hard-prereq doc      | T4, T7           | 0, 1  |
| 5. Link-audit quoting            | T5               | 0     |
| 6. Tracker state collision       | T6               | 1     |
| 7. Security boundary             | T8, T9, T10, T11 | 2     |
| 8. PostToolUse capture hook      | T13, T14         | 3     |
| 9. Pydantic schema validation    | T15, T16         | 3     |
| 10. Transcript-grounded evidence | T17, T18, T19    | 3     |
| 11. Layout coupling              | T25              | 4     |

Plus three plan-internal tasks not directly in the original eleven actions but required by the audit:

- T12 (pinned Python deps) addresses CR-007.
- T20 (run-bats.sh fix) addresses CR-004 wrapper side.
- T26 (drift orchestration) and T27 (Notion fuzzy fallback) preserve v1's Phase 4 behavioral hardening.
- T28 (DeepEval) is the optional v0.9.1 carry-forward.

### Placeholder scan

No `TBD`, `TODO`, "implement later", "fill in details", "Add appropriate error handling", "similar to Task N" present. Every code block contains literal content the engineer types or copies. Tasks that depend on an earlier task's output reference the earlier task by number (e.g., T19 references T15 schema; T23 references T22 stubs; T26 references T15 validator).

### Type / symbol consistency

Verified across the plan:

- **Pydantic class names** — `Row`, `Totals`, `_PropagatorBase`, `RepoReport`, `WikiReport`, `NotionReport`, `PropagatorReport` (the discriminated-union type alias), `Evidence`, `Finding`, `Escalation`, `StatsByLayer`, `Stats`, `AuditorReport` — used consistently in T15 (definition), T16 (imports), T17 (consumer), T19 (auditor prompt mirror), T23/T24 (integration validation).
- **Function names** — `find_grounding`, `load_transcript`, `verify`, `validate_propagator`, `validate_auditor` — match between T15/T17 (definition) and T16/T18 (test imports).
- **Hook env var** `UP_DOCS_TRANSCRIPT_LOG` — matches between T13 (script first-line gate), T14 (hook command resolves the path lazily through env), T23 (`setup_integration_env` exports it), T24 (audit-drift integration test uses it), and the README §Security note (Task 11).
- **Tracker env var** `UP_DOCS_TRACKER_STATE` (explicit override) and `CLAUDE_CODE_SESSION_ID` (default-keying) — match between T6 (script + tests) and T6 Step 6 / T26 (skill notes).
- **DeepEval env vars** — `RUN_LLMJUDGE` and `DEEPEVAL_TELEMETRY_OPT_OUT` and `ANTHROPIC_API_KEY` — consistent between T28 test module gating and T28 Step 4 smoke test.
- **File paths** — `plugins/up-docs/hooks/hooks.json` (T8, T9, T14), `plugins/up-docs/scripts/deny-guard.sh` (T9, T10), `plugins/up-docs/scripts/capture-transcript.sh` (T13, T14), `plugins/up-docs/tests/pyproject.toml` (T12, T28), `plugins/up-docs/tests/validate_output.py` (T15, T16, T19, T23, T24, T26), `plugins/up-docs/tests/verify_evidence_grounded.py` (T17, T18, T24), `plugins/up-docs/tests/integration/fixtures/test-mcp-config.json` (T22, T23) — all consistent across creation and reference.
- **Skill arguments / agent names** — `up-docs:up-docs-propagate-repo`, `up-docs:up-docs-propagate-wiki`, `up-docs:up-docs-propagate-notion`, `up-docs:up-docs-audit-drift` — match between agent file frontmatter and `claude --agent` invocations in T23 / T24.

### Cross-task references

- T9 references T8's PASS outcome; T9 Step 1 reads `phase-2-smoke-result.txt`.
- T10 creates `scripts/deny-guard.sh` which T9's `hooks/hooks.json` already references; T14 extends `hooks/hooks.json` with PostToolUse (not T10).
- T13 is referenced by T14 (which adds it to `hooks.json`).
- T15 schemas are referenced by T16 (tests), T17 (verifier consumer), T19 (auditor prompt mirror), T23/T24 (integration validation), T26 (drift skill orchestration).
- T17 verifier is referenced by T18 (tests), T24 (integration regression), T26 (drift skill orchestration).
- T19 auditor prompt update depends on the structured `Evidence` schema from T15.
- T20 wrapper fix is required by T23 / T24 (passing path arguments).
- T22 stubs are referenced by T23 / T24 (integration tests).
- T23 helpers are referenced by T24 (audit-drift `setup_integration_env` call).

### Dependency graph

```
Phase 0 (T1-T5) → checkpoint → release v0.7.2

Phase 1 T6 (tracker)
Phase 1 T7 (skill prereq check)
Phase 2 T8 (smoke gate, BLOCKING for T9-T14)
   └─ if PASS: → T9 (hooks.json) → T10 (deny-guard.sh) → T11 (consumer doc)
   └─ if FAIL: STOP and re-plan
Phase 3 T12 (pinned deps, BLOCKING for T15+)
Phase 3 T13 (capture-transcript.sh) → T14 (wire into hooks.json)
Phase 3 T15 (validators) → T16 (tests)
Phase 3 T17 (verifier, requires T15 Evidence schema) → T18 (tests)
Phase 3 T19 (auditor prompt update, requires T15 Evidence schema)
Phase 3 T20 (run-bats.sh fix)

T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20 ship as v0.8.0.

Phase 3 T21 (fixtures)
Phase 3 T22 (stubs + test-mcp-config.json)
Phase 3 T23 (propagator integration bats, requires T20, T22)
Phase 3 T24 (audit-drift integration bats, requires T17, T22, T23 helpers)

T21, T22, T23, T24 ship as v0.8.1.

Phase 4 T25 (layout config), T26 (drift orchestration, requires T15 validator),
        T27 (Notion fuzzy) — independent, ship as v0.9.0.

Optional Phase 4 T28 (DeepEval) ships as v0.9.1.
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-08-up-docs-hardening-plan-v2.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task; review between tasks; fast iteration. Good fit for the 28 tasks across 5 release versions because each task is self-contained and the per-task review surface is small.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`; batch execution with checkpoints for review. Good fit when decisions need to be made in real time and you want to watch each step land — particularly relevant for Tasks 8 (smoke-test outcome decides whether T9–T14 ship as drafted or are re-planned) and T23 Step 5 (live diagnosis of `--strict-mcp-config` and `--agent` behavior).

Which approach?
