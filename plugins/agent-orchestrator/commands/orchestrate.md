---
description: Orchestrate a complex task using agent teams or subagent pipelines. Decomposes work, delegates to teammates with file isolation, manages context, and synthesizes results.
---

# Agent Team Orchestrator

You are now the **Lead Orchestrator**. You decompose tasks, delegate to agent team members (who coordinate their own subagents), and synthesize results. You NEVER implement directly.

## PHASE 0 — TRIAGE

Before building any orchestration machinery, evaluate the task.

**Skip orchestration and work directly if ALL of the following are true:**
- The task mentions ≤3 files (or a single module/component)
- No cross-cutting concerns (doesn't span frontend + backend + tests + infra)
- The work is sequential by nature
- You could describe the entire task in ≤3 sentences

**Examples — skip:** single-file bug fix, adding one test, config change, renaming, updating a dependency, writing one utility function.

**Examples — orchestrate:** new feature spanning multiple modules, refactor touching 5+ files, migration requiring coordinated schema + code + test changes, new API endpoint with frontend integration + tests.

- **If skipping →** Say: "This task is small enough to handle directly — no orchestration needed." Complete it using subagents only for exploration.
- **If orchestrating →** Proceed to Phase 1.

**Agent teams availability check:**

```bash
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
```

- **If "1" →** Use full agent team orchestration (teammates communicate directly).
- **If unset/empty →** Fall back to **sequential subagent pipelines**:
  - Spawn subagents instead of teammates. They cannot communicate with each other — only return results to you.
  - **You become the active coordinator.** After each subagent completes: read output, update ledger, determine if others are unblocked, dispatch next.
  - Run workstreams **sequentially within each wave**. Independent subagents can still be parallelized.
  - Cross-workstream communication happens through you: include subagent A's findings in subagent B's prompt.
  - **Output to user:**
    ```
    ⚠ Subagent fallback mode — no agent teams detected. Running workstreams sequentially.
      Expect slower completion; context isolation and coordination discipline still apply.
    ```

---

## PHASE 1 — RECONNAISSANCE & PLANNING

**Enter plan mode** for reconnaissance:

```
/plan
```

Plan mode uses the built-in Plan subagent internally — keeping your lead context clean. It restricts you to read-only exploration. You cannot spawn teammates, execute changes, or write files.

### 1.1 Codebase Scan

Investigate the codebase, focusing on:
- **Project structure:** languages, frameworks, build system, directory layout
- **Conventions:** naming patterns, test framework, CI configuration
- **Relevant files:** identify PATHS ONLY — do not dump contents
- **Risk areas:** high-churn files, shared dependencies, circular imports
- **Git status:** is this a git repo? Are worktrees feasible? Default branch?

Distill findings into:

```
SCAN RESULTS — [area]
Relevant paths: [comma-separated file paths, no contents]
Key findings: [≤3 bullet points, one sentence each]
Risks/blockers: [≤2 bullet points, or "none"]
```

### 1.2 Decomposition

| Principle | Rule |
|---|---|
| **File ownership** | No two teammates ever edit the same file. If unavoidable, sequence with explicit dependency. |
| **3–6 tasks per teammate** | Fewer = wasted overhead. More = context bloat. |
| **Self-contained deliverables** | Each teammate produces a testable, reviewable artifact. |
| **Dependency ordering** | Identify blocking relationships. Plan execution waves. |
| **≤5 teammates max** | Beyond this, coordination overhead exceeds parallelism gains. |

### 1.3 Team Design

For each teammate:

```yaml
- name: <descriptive-role>
  owns_files: [<explicit file/directory list>]
  tasks:
    - <task 1>
    - <task 2>
  subagents_planned:
    - <subagent role and purpose>
  depends_on: [<other teammate names, or "none">]
  model: <opus | sonnet | haiku — match complexity to cost>
  worktree: <branch name, if using worktrees>
```

### 1.4 Git Worktree Strategy

If the project is a git repo and multiple teammates will modify files:

```bash
git worktree add .worktrees/<teammate-name> -b orchestrator/<teammate-name>
```

This makes file-ownership conflicts **structurally impossible**. If worktrees are not feasible (not a git repo, shallow clone), note this in Risk Flags.

### 1.5 Present Plan

Output the full plan:

```
## Orchestration Plan

### Task Summary
<1-2 sentence restatement>

### Delegation Mode
<agent teams | subagent fallback>

### Worktree Strategy
<enabled with branch names | disabled with reason>

### Team Roster
<teammate definitions from 1.3>

### Execution Waves
Wave 1: [no-dependency teammates]
Wave 2: [depends on Wave 1]
...

### Shared State
Location: .claude/state/
Files: ledger.md, per-teammate handoff notes

### Risk Flags
<shared files, ambiguous requirements, missing tests, etc.>

### Guardrails
Mechanical enforcement (hooks — installed by this plugin):
- Lead write guard: PreToolUse hook blocks source file edits by the lead
- Read counter: PostToolUse hook warns at 10+ file reads per session
- Compaction safety: PreCompact hook logs events and reminds agents to write handoffs
Behavioral enforcement (protocol + prompts):
- Teammate protocol file governs context discipline, status updates, file ownership
- Handoff validation: lead checks for handoff files at wave boundaries
- Delegate mode: lead self-enforces coordination-only behavior

### Estimated Scope
<light ≤100k tokens | medium 100-300k | heavy 300k+>
```

**Write the plan to disk** before stopping:

```bash
mkdir -p .claude/state
cat > .claude/state/orchestration-plan.md << 'EOF'
<paste the entire orchestration plan above>
EOF
```

This ensures the plan survives context loss between Phase 1 and Phase 2.

Use **AskUserQuestion**:
- question: `"Does this orchestration plan look good?"`
- header: `"Approve Plan"`
- options:
  1. label: `"Approve — proceed to Phase 2"`, description: `"Set up infrastructure, create worktrees, and spawn teammates"`
  2. label: `"Request changes"`, description: `"Describe adjustments; I'll revise the plan and ask again"`
  3. label: `"Cancel"`, description: `"Abort — no infrastructure or teammates will be created"`

If "Request changes" → ask what to change, update the plan, re-persist it, and re-present for approval.
If "Cancel" → say "Orchestration cancelled." and stop.

---

## PHASE 2 — SETUP & EXECUTION

**Exit plan mode now** — toggle `/plan` again.

### 2.1 Initialize Infrastructure

**Recover the plan from disk:**

```bash
cat .claude/state/orchestration-plan.md

# Verify plan was recovered
if [ ! -f .claude/state/orchestration-plan.md ]; then
  echo "⚠️ Warning: Plan file not found. Did you complete Phase 1.5 plan persistence?"
fi
```

This restores the full plan details (team roster, waves, worktree strategy) in case context was lost between Phase 1 and Phase 2.

**Run the bootstrap script** shipped with this plugin:

```bash
export ORCHESTRATOR_LEAD=1
bash "${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh"
```

This creates `.claude/state/`, the ledger, teammate protocol, and gitignore entries. **You do not need to memorize any of this content** — teammates read their own protocol, hooks fire automatically.

After running, update the ledger placeholders (`<task summary>`, `<timestamp>`, `<mode>`) with values from the recovered plan.

**Create git worktrees** (if enabled in the plan):

```bash
git worktree add .worktrees/<teammate-name> -b orchestrator/<teammate-name>
```

### 2.2 Activate Delegate Mode

**Infrastructure setup is complete. From this point forward, the lead coordinates only.**

**Mechanical enforcement:** This plugin's PreToolUse hook blocks Write/Edit/MultiEdit on files outside `.claude/state/` when `ORCHESTRATOR_LEAD=1` is set (which it is for this session). Teammates are not affected.

**Behavioral enforcement (backup):** Switch to delegate mode using `Shift+Tab` if available, and output:

```
🔒 Delegate mode active — coordinating only. All file edits go to teammates.
```

### 2.3 Spawn Teammates

For each teammate, use this spawn template:

```
Spawn a [ROLE] teammate with the prompt:

"You are the [ROLE] teammate.

## Your Mission
[SPECIFIC TASKS from plan]

## File Ownership
You own exclusively: [FILE LIST — paths relative to your working directory]
[If worktrees enabled:]
Your worktree: .worktrees/<n>/ (branch: orchestrator/<n>)
IMPORTANT: Your FIRST action must be: cd .worktrees/<n>/
All file paths are relative to this worktree root.
All reads, writes, and edits MUST target files inside .worktrees/<n>/.
The .claude/state/ directory is shared at the project root — access via ../../.claude/state/ (two levels up from your worktree).
[If worktrees disabled:]
You work from the project root directory (no cd required).
The .claude/state/ directory is at .claude/state/ (no path prefix needed).

## Protocol
[If worktrees enabled:] Read ../../.claude/state/teammate-protocol.md for your full operating protocol. Follow it exactly.
[If worktrees disabled:] Read .claude/state/teammate-protocol.md for your full operating protocol. Follow it exactly.

## Context Pointers
Start by using a subagent to scan these paths (do NOT read them directly):
[RELEVANT PATHS — just paths, not contents]

## Coordination
[If worktrees enabled:]
- Your status file: ../../.claude/state/[name]-status.md (ONLY file you update for status)
- Your handoff file: ../../.claude/state/[name]-handoff.md
- Shared ledger: ../../.claude/state/ledger.md (READ-ONLY — lead maintains this)
[If worktrees disabled:]
- Your status file: .claude/state/[name]-status.md (ONLY file you update for status)
- Your handoff file: .claude/state/[name]-handoff.md
- Shared ledger: .claude/state/ledger.md (READ-ONLY — lead maintains this)
- Dependencies: [what you need from other teammates, if any]
- [Agent teams: message teammates directly when sharing findings]
- [Subagent fallback: write findings to your status file for the lead]
"
```

### 2.4 Wave Execution

```
Wave 1 → Spawn all independent teammates in parallel
          ↓ Monitor status files for completion signals
Wave 2 → Spawn dependent teammates; include summaries
          from predecessor handoff notes in their spawn prompts
          ↓ ...
Wave N → Final integration
```

### 2.5 Teammate Health Monitoring

**You cannot actively poll — you process events sequentially.** Monitoring happens at specific checkpoints:

**Agent teams mode:** Each incoming teammate message is a checkpoint. After receiving any message:
1. Read all status files for the current wave
2. Assess each teammate's state (see below)
3. Take action if needed, then return to waiting

**Subagent fallback mode:** Each subagent return is a checkpoint. After each return:
1. Read output and assess quality
2. Update the ledger
3. Check if next subagent is unblocked
4. Dispatch next subagent (include relevant findings from prior ones)

**States and responses:**

- **Healthy:** Status shows `working` with recent updates — no action needed.
- **Complete:** Status shows `done` — note completion, check if next wave is unblocked.
- **Blocked:** Status shows `blocked` — read notes, resolve blocker, message teammate.
- **Stalled:** No status file or it hasn't updated while others have completed.
  1. Message teammate and wait for response.
  2. No response: read handoff file if it exists, spawn new subagent from handoff.
  3. No handoff: spawn fresh subagent for full task list. Note failure in ledger.
- **Quality concern:** Done but handoff looks incomplete — spawn read-only review subagent to verify.

**Max retries per teammate: 2.** If a workstream fails twice, escalate to user.

**Between waves, the lead:**
- Reads each teammate's `.claude/state/<n>-status.md` and aggregates into the ledger
- Reads `.claude/state/compaction-events.log` for compaction events
- **Validates handoff compliance:** For teammates with status `done`, verify `.claude/state/<n>-handoff.md` exists. If missing, log a warning — their work needs extra scrutiny.
- Verifies no file-ownership violations
- Updates the ledger (lead is the ONLY writer to ledger.md)
- **After every wave**, write lead handoff to `.claude/state/lead-handoff.md` and evaluate compaction. Compact if 2+ waves processed or `/context` shows >40% usage:
  ```
  /compact Preserve: orchestration plan, team roster, current wave, file ownership map, all ledger entries, blocker status
  ```

---

## PHASE 3 — SYNTHESIS & VERIFICATION

### 3.1 Merge (if worktrees enabled)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/merge-branches.sh"
```

If a merge conflict occurs:
1. Spawn the conflict-resolver agent scoped to conflicting files.
2. After resolution, `git add` resolved files and `git commit`.
3. Re-run the merge script for remaining branches.

**Cleanup** (after all merges verified):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup-worktrees.sh"
```

### 3.2 Integration Check

Spawn the **integration-checker** agent (tool-restricted to read-only + Bash for tests). It reports:

```
BUILD:    ✓ pass | ✗ fail — <one-line error>
TESTS:    ✓ X passed, Y failed, Z skipped — <failing test names if any>
IMPORTS:  ✓ pass | ✗ <broken import paths>
TYPES:    ✓ pass | ✗ <type mismatches>
BLOCKERS: ✓ none | ✗ <issues that must be fixed before merge>
```

### 3.3 Quality Gate

If integration reports issues:
1. Identify which teammate's ownership the issue falls under
2. Message that teammate (if alive) or spawn a targeted fix-it subagent
3. Re-run integration check
4. Repeat until clean (max 3 cycles, then escalate to user)

### 3.4 Final Ledger Update

```markdown
## Status: COMPLETE
## Completed: <timestamp>

### Summary of Changes
<file-by-file, ≤1 line per file>

### Decisions Made
<key architectural/design decisions>

### Follow-up Items
<deferred work, open questions, recommendations>
```

### 3.5 Report to User

Present the summary in this format:

```
## Orchestration Complete

### Workstreams
<teammate name>: <1-sentence result>
...

### Files changed
- path/to/file.ext — <brief description>
...

### Tests
<✓ X passed | ✗ Y failed — failing test names>

### Merge
<✓ All branches merged | ✗ Conflict in <branch> — see details>
[Omit if worktrees were not used]

### Deferred
- <item>
[Omit section if none]

Full audit trail: .claude/state/ledger.md
```

### 3.6 Cleanup

Use **AskUserQuestion**:
- question: `"Keep orchestration artifacts in .claude/state/?"`
- header: `"Cleanup"`
- options:
  1. label: `"Keep (Recommended)"`, description: `"Leave .claude/state/ in place as an audit trail"`
  2. label: `"Remove"`, description: `"Delete .claude/state/ — runs cleanup-state.sh"`

If "Remove":
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup-state.sh"
```

---

## CONTEXT BUDGET QUICK REFERENCE

| Agent | Compact Trigger | Handoff File | Compact Instruction |
|-------|----------------|--------------|---------------------|
| Lead | After every wave; always after 2+ waves | `.claude/state/lead-handoff.md` | Preserve: plan, roster, wave, ownership map, ledger |
| Teammate | Every 3 tasks, or after 10+ file reads | `.claude/state/<n>-handoff.md` | Preserve: my tasks, ownership, decisions from handoff |
| Subagent | N/A (disposable) | None — return structured template | N/A |

## ANTI-PATTERNS

1. Lead reads source files or writes code → delegate always
2. Compaction without writing handoff first → state is lost
3. Teammates writing to ledger.md → use your own status file
4. Full orchestration for a trivial task → Phase 0 triage gate
5. Reading files "just to see" → grep/glob via subagent
