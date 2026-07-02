---
name: execute-phase
description: Execute the next pending phase of the named project end-to-end — derive the phase spec from the master, plan it, implement under TDD with review gates, and update handoff state. Run once per phase, passing the project name.
argument-hint: '[project-name]'
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill, Agent, Workflow
model: opus
disable-model-invocation: true
compatibility: Claude Code
license: MIT
metadata:
  author: Chris Purcell
  version: '2.0'
---

# Autonomous Phase Execution

Execute the next phase of the project named in $ARGUMENTS end-to-end, autonomously, in this session. Do not stop for input unless genuinely blocked (see HALT CONDITIONS). Stop when the phase is complete. Do not continue to the next phase; that is a separate session.

## Preconditions (verify before starting)

- Session permission mode permits unattended workflow runs. If a review workflow's first run prompts for approval, approve with "don't ask again for this path" so later phases run silently.
- Working tree is clean or its state is understood. Note current branch.

## Orchestration model

- Main session model: Opus (orchestrator + synthesis + convergence judgment).
- Review allocation:
  - Spec and plan gates: exactly ONE `ultracode` workflow pass (panel review of the raw artifact), then `/codex-review` to convergence. The single workflow pass catches structural problems; Codex handles the iterative tail on idle credits.
  - Final review (post-implementation): `/codex-review` only. No `ultracode` workflow at this gate.
- Workflow subagent routing: every `ultracode` workflow MUST use Sonnet worker subagents; reserve Opus subagents only for genuinely complex sub-tasks (e.g. cross-document adversarial comparison). State this constraint explicitly in each workflow trigger so it is encoded into the generated script.

## References

Shared standards live in `${CLAUDE_PLUGIN_ROOT}/references/`. They are the rubric for both authoring and the review gates.

- Spec construction — core: `${CLAUDE_PLUGIN_ROOT}/references/spec-construction.md`
- Spec construction — phase delta: `${CLAUDE_PLUGIN_ROOT}/references/spec-construction-phase.md`
- Plan construction standard: `${CLAUDE_PLUGIN_ROOT}/references/plan-construction.md`

When this skill writes or reviews a phase spec, the standard is the core PLUS the phase delta (read both). The phase delta governs inheritance: cite the master design and predecessor-phase contracts; restate only load-bearing inherited invariants; do not re-derive system architecture.

These standards supersede any external authoring skill. Do NOT invoke Superpowers `brainstorming`, `writing-plans`, or `test-driven-development` while this skill is active — this skill provides its own spec, plan, and TDD process, and these standards are the authority.

## Validator gates (specpipe)

Structural gates run through the bundled specpipe CLI (a plain stdlib package — the invocation never writes into the plugin tree):

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe <subcommand> …`

(Below, `specpipe <subcommand>` abbreviates that invocation.) Errors (exit 1) MUST be fixed and the validator re-run clean BEFORE the gate's workflow/Codex pass — the deterministic pass is free; do not spend panel review on structural defects. Warnings may be accepted with a one-line recorded justification in the artifact. Validator failures are NOT halt conditions: fix and re-run.

Path convention: specpipe is layout-agnostic — every subcommand takes explicit paths. Examples below use the greenfield default `docs/handoff/`; if the project keeps its state elsewhere, resolve paths per that project's convention (the audit file always sits beside the phase plan in an `audit/` subdirectory, and `init-project` accepts `--handoff-dir`).

## Phase pipeline

### 1. Resume

- Resolve the next phase deterministically: `specpipe next-phase docs/handoff/phase-plan.md` (resume-first: an in_progress phase from an interrupted session is returned before any pending one) from the project's handoff phase-plan file — the status-tracking projection of the master spec's build-plan section. Statuses live in the plan file; phase definitions live in the master; on conflict the master governs. If it reports RESUME, reassess that phase's partial state — committed tasks stand, continue from the first incomplete task — or abandon an unsalvageable run with `specpipe set-status docs/handoff/phase-plan.md --id <id> --to pending` and re-resolve. For a fresh phase, mark it active with `specpipe set-status docs/handoff/phase-plan.md --id <id> --to in_progress` and reset round counters with `specpipe rounds .spec-pipeline/state.json --reset`.
- When brainstorming or filling gaps, choose sane defaults aligned with project conventions. Do not stop for input on resolvable design choices.

### 2. Spec

- Instantiate `${CLAUDE_PLUGIN_ROOT}/templates/phase-spec.md` and write the phase spec per the spec construction standard — core + phase delta (see References). Full depth on this phase's slice; inherit system context from the master and predecessor phases by reference per the phase delta's inheritance rule. VALIDATOR GATE: `specpipe validate spec --kind phase <spec-path> --master <master-path>` clean before the workflow pass.
- WORKFLOW PASS (exactly one — do NOT loop to convergence): `ultracode: comprehensively review the phase spec at <path> against the spec construction standard (core + phase delta). Use Sonnet worker subagents; Opus only for genuinely complex sub-tasks. Independently verify each finding before reporting.` Apply all justified fixes from this single pass (skip findings that do not survive verification).
- CODEX CONVERGENCE: run `/codex-review` against the spec at <path>. Apply justified fixes and re-run until either (a) a pass yields zero justified fixes, or (b) 3 rounds are reached. On hitting the cap, record remaining open findings in the spec and proceed (subject to HALT CONDITIONS: unresolved errors — not warnings — are a halt, not a proceed). Count rounds with `specpipe rounds .spec-pipeline/state.json --gate spec --increment` before each round.

### 3. Plan

- Instantiate `${CLAUDE_PLUGIN_ROOT}/templates/implementation-plan.md` and write the implementation plan per the plan construction standard (see References). Each task embeds its complete failing-test code and implementation code in TDD order; the RED gate is preserved at execution by step ordering (write test → run/fail → implement → run/pass), not by withholding code. VALIDATOR GATE: `specpipe validate plan <plan-path>` clean before the workflow pass.
- WORKFLOW PASS (exactly one — do NOT loop to convergence): `ultracode: comprehensively review the implementation plan at <path> against the plan construction standard. Use Sonnet worker subagents; Opus only for genuinely complex sub-tasks. Independently verify each finding before reporting.` Apply all justified fixes from this single pass (skip findings that do not survive verification).
- CODEX CONVERGENCE: run `/codex-review` against the plan at <path>. Apply justified fixes and re-run until either (a) a pass yields zero justified fixes, or (b) 3 rounds are reached. On hitting the cap, record remaining open findings in the plan and proceed (subject to HALT CONDITIONS: unresolved errors — not warnings — are a halt, not a proceed). Count rounds with `specpipe rounds .spec-pipeline/state.json --gate plan --increment` before each round.

### 4. Implement (per-task RED → GREEN → refactor)

Work the plan task-by-task. The plan already contains each task's failing-test code and implementation code (per the plan construction standard); execute them in order rather than writing all tests then all implementation.

- Before starting, classify each module the phase touches per TDD SCOPE (below) and record the classification for the close-out report. Logic-bearing modules run the full per-task cycle; glue/config modules need only a smoke test.
- For each task, in order:
  - RED — apply the task's test step(s): write the task's test(s) from the plan, then run them. Confirm they FAIL for the RIGHT reason — a missing symbol or a failed assertion, NOT a collection/import/syntax error in the test. A test that errors on collection has not established RED; fix it until it fails cleanly. Record the RED evidence with `specpipe record-red --cmd '<test command>' --task <task-id> --audit docs/handoff/audit/phase-<id>.md` — it rejects collection errors (RED not established) and appends the evidence block the close-out report cites.
  - The task's tests are now FROZEN (see TDD GUARDRAILS).
  - GREEN — apply the task's implementation from the plan. Run the tests; iterate on the IMPLEMENTATION (never the frozen tests) until green. Record with `specpipe record-green --cmd '<test command>' --task <task-id> --audit docs/handoff/audit/phase-<id>.md`.
  - REFACTOR — refactor for clarity while green; re-run after each change.
  - Run the full verification gate; commit the task.
- Glue/config tasks: a single import-and-instantiate smoke test substitutes for the RED→GREEN cycle.
- Subagent use: a subagent may own a COMPLETE task (its own frozen tests + implementation) and run that task's local RED→GREEN. Do not split a single task's test and implementation across separate subagents — the red-green state is shared mutable repo state and will race.

### 5. Coverage

- Run coverage (e.g. pytest + coverage.py); meet the project's coverage threshold on touched modules.
- Coverage is a BACKSTOP, not the test-writing mechanism: under TDD the tests already exist per task. Any new public surface on a LOGIC-BEARING module that appears WITHOUT a corresponding test from its task is a TDD violation — flag it, add the missing test, and note why it was missed. Do not silently backfill and move on. (Glue/config modules per TDD SCOPE are exempt from the full-test requirement but must still carry their smoke test.)

### 6. Final review (Codex)

- Run `/codex-review` against the implementation for this phase. Do NOT run an `ultracode` workflow at this gate.
- CODEX CONVERGENCE: apply justified fixes and re-run `/codex-review` until either (a) a pass yields zero justified fixes, or (b) 5 rounds are reached. On hitting the cap, record remaining open items and proceed (subject to HALT CONDITIONS for unresolved errors). Count rounds with `specpipe rounds .spec-pipeline/state.json --gate final --increment` before each round.

### 7. Close out

- Summarize phase outcome + any open/deferred items into the handoff state.
- Mark the phase done: `specpipe set-status docs/handoff/phase-plan.md --id <id> --to complete`. Commit `docs/handoff/audit/phase-<id>.md` with the close-out — it IS the RED→GREEN audit trail the report cites.
- Review `git status --porcelain` and stage residual changes by explicit path — never `git add -A` / `git add .` (untracked scratch files, coverage artifacts, or local env files must not enter the phase commit).
- Commit any residual changes with a concise imperative message describing the phase (per-task commits already landed in step 4).
- Close out the session using the project's handoff state (whichever handoff system the project repo has adopted, for example `agent-handoff-v3`) so the next phase can be resolved in a future session.
- Push all commits to the current branch's remote.
- Stop here. Do not continue to the next phase; that is a separate session.

## HALT CONDITIONS (the only reasons to stop and ask)

- A design decision is genuinely irreversible AND has no defensible default.
- A test/review failure indicates a spec-level contradiction that cannot be resolved without redefining phase scope.
- Push fails for an auth/remote reason requiring human intervention.
- Any convergence loop would exceed its round cap (3 for spec/plan Codex review, 5 for the final Codex review) with errors (not warnings) still unresolved — surface them rather than committing broken work.

## TDD SCOPE

Strict TDD (the per-task RED→GREEN→refactor cycle in step 4) applies to LOGIC-BEARING modules. Classify each module touched this phase before implementing, and record the classification in the close-out report.

- Logic-bearing (strict TDD required) — anything with branching, computation, parsing, state transitions, data transformation, error handling, or a contract another module depends on. When in doubt, classify as logic-bearing. This is the default.
- Glue/config (smoke test sufficient) — thin wiring with no branching: argument plumbing, static config/constants, dataclass/Pydantic model declarations with no custom validation, trivial pass-through wrappers, `__init__` exports. A single import-and-instantiate smoke test is enough; a full RED→GREEN cycle is not required.

Rules:

- "Glue" is a justification that must survive scrutiny, not an escape hatch. If a module has ANY conditional logic or could fail in a way a test would catch, it is logic-bearing. Misclassifying logic as glue to skip TDD is a TDD GUARDRAILS violation.
- A custom Pydantic validator, a non-trivial default factory, or any `__post_init__` with logic moves a model from glue to logic-bearing.
- Record the per-module classification (module → logic-bearing | glue, one-line reason) in the close-out report so the scoping decision is auditable.

## TDD GUARDRAILS (violations are HALT conditions, not auto-fixes)

Once RED is established in step 4, the implementation may NOT:

- Edit, delete, weaken, or relax any test assertion to achieve green.
- Add `@pytest.mark.skip`, `@pytest.mark.xfail`, or comment out tests to pass.
- Hardcode return values whose only purpose is to satisfy a specific test.
- Write tautological or vacuous tests (`assert True`, `assert x == x`, no assertions).

The ONLY permitted reason to modify a frozen test is that the test itself encodes a genuine error relative to the converged spec. In that case: STOP, state the contradiction explicitly, correct the test, re-establish RED, and record the change in the close-out report. Do not edit a frozen test silently.

Close-out report must include the RED→GREEN audit trail: for each logic-bearing unit, the test's pre-implementation failure reason and post-implementation pass. This is the evidence that TDD was followed rather than retrofitted.

## Output

Brief final report:

- Phase completed; coverage delta.
- Per-module TDD scope classification (module → logic-bearing | glue, reason).
- RED→GREEN audit trail per logic-bearing unit.
- Per gate: whether the single workflow pass ran (spec/plan) and Codex rounds consumed; open/deferred items.
- Commit SHA(s) pushed.
