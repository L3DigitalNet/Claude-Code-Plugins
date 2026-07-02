---
name: author
description: Author the canonical project spec and decompose it into phases for execution by /spec-pipeline:execute-phase. Run once at project inception.
argument-hint: '[project-brief-path]'
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill, Agent, Workflow
model: opus
disable-model-invocation: true
compatibility: Claude Code
license: MIT
metadata:
  author: Chris Purcell
  version: '2.1'
---

# Master Spec Authoring

Author the canonical spec for $ARGUMENTS and decompose it into ordered phases for execution by `execute-phase`. Run once at project inception. Choose sane defaults; do not stop for input except at the architecture checkpoint (step 2) or a HALT CONDITION.

## Preconditions

- A project brief exists: a path via $ARGUMENTS, the current conversation, or a notes doc. If the brief is too thin to derive a defensible scope and architecture, that is a genuine HALT — ask for the missing intent rather than inventing a project.
- The `/codex-review` skill (Codex CLI) and ultracode workflow support are available — the review gates hard-require both. If either is missing, HALT; do not substitute an ad-hoc review and mark the gate passed.
- Working tree clean or understood; note branch (likely a fresh repo).
- Identify the project's handoff/state layout (Agent Handoff System) and existing conventions. Conform to them. If greenfield, this skill establishes the minimal layout the sibling skill expects.

## Orchestration model

- Main session model: Opus (authoring + architecture judgment + synthesis).
- Review allocation (same philosophy as execute-phase): exactly ONE `ultracode` workflow panel pass on the raw artifact, then `/codex-review` to convergence. Workflow workers Sonnet; Opus only for genuinely complex sub-tasks (e.g. validating the phase dependency graph against the spec). State the routing explicitly in each trigger.
- The master spec is the highest-leverage artifact in the system: a flaw propagates into every phase spec and all phase code. It receives phase-gate rigor applied to BOTH the spec content and the phase decomposition.

## References

Shared standards live in `${CLAUDE_PLUGIN_ROOT}/references/`. They are the rubric for both authoring and the review gate.

- Spec construction — core: `${CLAUDE_PLUGIN_ROOT}/references/spec-construction.md`
- Spec construction — master delta: `${CLAUDE_PLUGIN_ROOT}/references/spec-construction-master.md`

When this skill writes or reviews the master spec, the standard is the core PLUS the master delta (read both). The master delta governs the master's obligations: id'd cross-cutting decisions, the phase decomposition, scope coverage (every requirement → exactly one phase), and delegation of exhaustive detail to named planning artifacts.

This standard supersedes any external authoring skill. Do NOT invoke Superpowers `brainstorming` or `writing-plans` during autonomous steps — this skill provides its own process and this standard is the authority. (The architecture checkpoint in step 2 is this skill's own deliberate human gate, not Superpowers'.)

## Validator gates (specpipe)

Structural gates run through the bundled specpipe CLI (a plain stdlib package — the invocation never writes into the plugin tree):

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe <subcommand> …`

(Below, `specpipe <subcommand>` abbreviates that invocation.) Errors (exit 1) MUST be fixed and the validator re-run clean BEFORE the gate's workflow/Codex pass — the deterministic pass is free; do not spend panel review on structural defects. Warnings may be accepted with a one-line recorded justification in the artifact. Validator failures are NOT halt conditions: fix and re-run.

Path convention: specpipe is layout-agnostic — every subcommand takes explicit paths. Examples below use the greenfield default `docs/handoff/`; if the project keeps its state elsewhere, resolve paths per that project's convention (the audit file always sits beside the phase plan in an `audit/` subdirectory, and `init-project` accepts `--handoff-dir`).

## Pipeline

### 1. Intake

- Read the brief. Establish, choosing sane defaults aligned with project and toolchain conventions (do not stop on resolvable choices):
  - Problem statement; goals; explicit non-goals.
  - Target environment(s) and dependency boundaries (runtime, OS/platform support, external services).
  - Language/toolchain (default Python: uv, ruff, BasedPyright strict, pytest + coverage.py; FastAPI / Pydantic v2 / Typer as applicable).
  - Hard constraints (performance, security, offline operation, data).
- Discover existing repo conventions and handoff layout; conform rather than invent.

### 2. Architecture & scope draft

- Define the system boundary, major components, key technical decisions (with the one defensible default chosen for each), and the data/interface shape.
- Draft the proposed phase breakdown — titles + one-line objectives only at this stage.
- HUMAN CHECKPOINT (the single deliberate stop): present scope boundary + architecture + proposed phase list for confirmation before authoring the full spec. These are the architectural, big-picture decisions the director owns; everything downstream drafts autonomously. To run fully unattended, skip this checkpoint by prior agreement.

### 3. Master spec authoring

- Instantiate `${CLAUDE_PLUGIN_ROOT}/templates/master-spec.md` (its headings are the canonical grammar specpipe validates) and write the canonical spec per the spec construction standard — core + master delta (see References), formatted for LLM/agent consumption (structured, not narrative prose). Sections:
  - Overview / problem / goals / non-goals
  - Architecture (components, boundaries, key decisions + rationale)
  - Data model / domain types
  - Interfaces (CLI / API / contracts)
  - Behavior & rules (per component)
  - Error handling & failure modes
  - Testing strategy (what TDD targets; high-level logic-bearing vs glue boundaries)
  - Acceptance criteria (system-level)
  - Out of scope
- Write so any single phase's slice is cleanly extractable: the sibling derives each per-phase spec from this document.

### 4. Phase decomposition

Decompose the spec into an ordered phase plan. Rules:

- Each phase is independently executable in a single `execute-phase` session.
- Prefer VERTICAL slices that deliver testable behavior over horizontal layers (all-models-then-all-logic). Vertical slices make per-phase TDD meaningful and keep the logic-vs-glue classification honest.
- Phase 1 establishes the foundation: project skeleton, toolchain config (uv, ruff, BasedPyright strict, pytest, coverage.py), and CI scaffolding — so every later phase has a working test harness for RED→GREEN. Do not defer the test harness.
- Order by dependency; a phase may depend only on earlier phases. The dependency graph must be acyclic.
- Size each phase to the per-phase cost envelope: when run, each phase triggers two doc-review workflow passes + codex convergence + TDD + a final codex review. If a phase's spec would be too large to review in one workflow pass, or its implementation too large for one session, split it.
- Each phase entry uses this stable schema (consumed by execute-phase step 1), written to the phase-plan file instantiated from `${CLAUDE_PLUGIN_ROOT}/templates/phase-plan.md`:
  - id (stable integer) — title — status: pending
  - objective (one line)
  - scope: in / out
  - depends_on: [phase ids]
  - spec slice: which master-spec sections this phase implements
  - acceptance criteria (phase-level, testable)
  - size note

### 5. Review (spec + phase plan)

- VALIDATOR GATE: run `specpipe validate spec --kind master <spec-path>` and `specpipe validate phase-plan <plan-path>`; fix all errors and re-run until clean before the workflow pass.
- WORKFLOW PASS (exactly one — do NOT loop to convergence): `ultracode: comprehensively review the master spec at <path> against the spec construction standard (core + master delta) AND the phase plan at <path>. Use Sonnet worker subagents; Opus only for genuinely complex sub-tasks (dependency-graph soundness, scope-coverage completeness). Independently verify each finding before reporting.` Beyond prose quality the panel MUST verify: (a) every spec requirement is covered by exactly one phase — no orphaned or duplicated scope; (b) the dependency order is acyclic and correct; (c) each phase is independently executable and testable; (d) phase 1 establishes the test harness. Apply all justified fixes from this single pass.
- CODEX CONVERGENCE: run `/codex-review` against the spec and phase plan. Apply justified fixes and re-run until either (a) a pass yields zero justified fixes, or (b) 3 rounds are reached. On hitting the cap, record remaining open findings and proceed. Count rounds deterministically: run `specpipe rounds .spec-pipeline/state.json --gate spec --increment` before each round; a cap-exceeded exit (1) ends the loop.

### 6. Initialize handoff / state

- Run `specpipe init-project` to scaffold the minimal layout (docs/handoff/phase-plan.md from template, docs/handoff/audit/, .spec-pipeline/ gitignored); pass `--handoff-dir` when the project's existing state layout is not docs/handoff/. It is idempotent and never overwrites existing handoff files.
- Seed the project's handoff state (Agent Handoff System layout) so `execute-phase` can resolve "next phase" (= first phase with status: pending), track completion, and carry context across sessions.
- Write the phase-plan file with per-phase status fields. The master spec's build-plan section is DEFINITIONAL (ids, objectives, scope, dependencies); the plan file is its status-tracking projection — statuses live in the file, definitions in the master, and on conflict the master governs. Location: the project's existing handoff convention; greenfield default `docs/handoff/phase-plan.md`.
- Establish state.md / handoff scaffolding per the project's layout. If greenfield, create the minimal layout the sibling skill expects.

### 7. Close out

- Commit the master spec, phase plan, and handoff scaffolding with a clear imperative message.
- Push to the current branch's remote.

## Contract with execute-phase

This skill produces exactly what the sibling consumes:

- Master spec — source of truth for every per-phase spec (sibling step 2).
- Phase plan — ordered, status-tracked projection of the master's build-plan section (definitions stay in the master). Sibling step 1 resolves "next phase" = first entry with status: pending; sibling step 2 then expands that entry into a per-phase spec.
- Handoff/state scaffolding — sibling reads/writes phase outcomes here at close-out.

Phase ids are STABLE: the sibling references phases by plan id across sessions. Never renumber a phase once execution has begun; append or split instead.

## HALT CONDITIONS

- `/codex-review` or ultracode workflow support is unavailable — the review gates hard-require them (see Preconditions).
- The brief is too thin to derive a defensible scope/architecture — ask for the missing intent.
- The architecture checkpoint (step 2) — the single deliberate stop, unless running fully unattended by prior agreement.
- An architectural decision is genuinely irreversible AND has no defensible default.
- Convergence would exceed the 3-round Codex cap with errors (not warnings) unresolved.
- Push fails for an auth/remote reason requiring human intervention.

## Output

Brief report:

- Master spec path; phase count.
- Phase plan summary: id → title → depends_on → status.
- Scope coverage confirmation (no orphaned or duplicated requirements; phase 1 establishes the harness).
- Codex rounds consumed; open/deferred items.
- Commit SHA(s) pushed.
