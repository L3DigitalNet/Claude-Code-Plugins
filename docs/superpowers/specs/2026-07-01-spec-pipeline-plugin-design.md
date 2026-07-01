# spec-pipeline Plugin — Design

- **Date:** 2026-07-01
- **Status:** Approved 2026-07-01 — plan in progress
- **Decisions locked during brainstorm:** name `spec-pipeline`; validators only (no enforcement hooks); utility commands `/validate`, `/status`, `/init-project`; Codex/ultracode review dependencies stay hard-required; architecture = single `specpipe` Python CLI.

## Overview

### Problem

Two sibling skills currently live in `agent-configs` (`~/projects/agent-configs/skills/.claude/skills/`):

- `author-master-spec` (v1.6) — authors the canonical project spec and decomposes it into phases.
- `autonomous-phase-execution` (v1.11) — executes the next pending phase end-to-end under TDD with review gates.

They share an explicit producer/consumer contract (master spec → phase plan → handoff state) and ship a **byte-identical** copy of `spec-construction.md` each. Their quality bar is prose: phase-plan schema, acyclic dependencies, decision-id citations, required spec sections, TDD step ordering, RED-evidence capture, and round caps all rely on the model policing itself.

### Goals

1. Merge both skills into one plugin, `spec-pipeline`, in this repo's `l3digitalnet-plugins` marketplace.
2. Deduplicate the shared reference standards into one `references/` library.
3. Mechanize the standards' **file-local and cross-reference structural checks** (sections, schemas, dependency graphs, decision-id citations, TDD step order) via a deterministic validator CLI (`specpipe`) that the skills must run **before** the expensive review gates. Requirement/scope coverage — "every requirement maps to exactly one phase" — is deliberately NOT mechanized: it stays the ultracode review panel's mandate (the author skill's step-5 panel explicitly verifies it), because it requires semantic judgment about what constitutes a requirement.
4. Make phase-state operations (next-phase resolution with resume, status transitions with recovery, round caps, RED→GREEN evidence) computed rather than self-reported.
5. Ship templates whose heading grammar is the same grammar the validator parses, so authored artifacts always parse.

### Non-goals

- No enforcement hooks (PreToolUse frozen-test blocking) — explicitly deferred; validators only in this cycle.
- No change to the review allocation philosophy (one ultracode workflow pass + Codex convergence; Codex hard-required).
- No graceful degradation / configurable review backends.
- No semantic validation (requirement/scope coverage judgment, spec quality) — that remains the review panels' job; specpipe validates structure and links only. No machine-readable requirement-ID inventory or coverage map in this cycle (a possible v2 if panel-only coverage proves insufficient).
- Removing the originals from `agent-configs` is a follow-up decision, not part of this build.

## Architecture

### Plugin layout

```text
plugins/spec-pipeline/
├── .claude-plugin/plugin.json      # name, description, version 0.1.0, L3DigitalNet author
├── README.md
├── CHANGELOG.md
├── skills/
│   ├── author/SKILL.md             # from author-master-spec → /spec-pipeline:author
│   └── execute-phase/SKILL.md      # from autonomous-phase-execution → /spec-pipeline:execute-phase
├── commands/
│   ├── validate.md                 # /spec-pipeline:validate — thin wrapper over specpipe validate
│   ├── status.md                   # /spec-pipeline:status — wrapper over specpipe status
│   └── init-project.md             # /spec-pipeline:init-project — wrapper over specpipe init-project
├── references/
│   ├── spec-construction.md        # core standard (deduped — one copy)
│   ├── spec-construction-master.md # master delta
│   ├── spec-construction-phase.md  # phase delta
│   └── plan-construction.md        # plan standard
├── templates/
│   ├── master-spec.md
│   ├── phase-spec.md
│   ├── implementation-plan.md
│   └── phase-plan.md
├── scripts/specpipe/               # plain Python package dir (stdlib-only, no pyproject/venv/lock)
│   └── specpipe/…                  # imported via PYTHONPATH; run via uv run --no-project
└── tests/                          # pytest suite (conventions.md TEST-001)
```

Key structural decisions:

- **Skills for the two heavy surfaces, commands for the three thin ones.** The skills carry process + references; the utilities are one-paragraph wrappers that invoke specpipe, render its output faithfully (findings grouped by severity, exit code reported, `--json` available on request), and never swallow a non-zero exit. Mirrors release-pipeline's heavy/thin split.
- Both skills keep `model: opus`, `disable-model-invocation: true`, `allowed-tools`, and argument hints. Reference paths change from `./references/` to `${CLAUDE_PLUGIN_ROOT}/references/`.
- `specpipe` is **stdlib-only** (argparse, re, json, pathlib, shlex, subprocess) and deliberately has **no Python project machinery** — no `pyproject.toml`, no venv, no lockfile. It is a plain package directory imported via `PYTHONPATH`, because `uv run` against a project would lock/sync and write `.venv/`+`uv.lock` into the plugin root — which dirties the source repo and is brittle in the installed-plugin cache (`${CLAUDE_PLUGIN_ROOT}` must not receive persistent state). Canonical invocation: `PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -m specpipe …` (uv supplies a suitable interpreter without touching the plugin tree; runtime floor Python ≥ 3.11). Acceptance includes a clean-tree proof: after any specpipe invocation, `git status --short plugins/spec-pipeline/scripts/specpipe` is empty.

### Rejected alternatives

- **Per-concern scripts (release-pipeline style):** familiar house pattern, but the artifacts form a cross-referencing system (phase specs cite master decision ids; the phase plan mirrors the master's build plan). Isolated scripts duplicate parsers and cannot validate the links cheaply. Rejected for weaker cross-artifact validation.
- **Minimal validators (phase-plan graph + plan TDD-order only):** leaves most of the mechanizable surface as prose. Rejected — the marginal cost of the remaining checks is low once the parsers exist.
- **Enforcement hooks (PreToolUse frozen-test block, git-add-all block):** deferred by user decision. Hooks are plugin-global and need self-gating state; validators deliver most of the determinism without session-wide hook friction. May return as a v2.
- **Graceful degradation / configurable review backend:** rejected — this is a personal pipeline; the plugin documents `/codex-review` + ultracode as prerequisites and HALTs when unavailable.

## The specpipe CLI

### Contract

- Every subcommand supports `--json` (machine-readable findings/results) alongside human-readable output.
- Exit codes: `0` clean · `1` findings/failure · `2` bad invocation.
- Findings carry severity: **error** (structural violation — the skill must fix before proceeding past the gate) or **warning** (heuristic smell — the skill judges and may proceed with a recorded justification).

### Subcommands

| Subcommand | Checks / behavior |
| --- | --- |
| `validate phase-plan <path>` | Per-entry schema: id (stable integer), title, status, objective, scope in/out, depends_on, spec slice, acceptance criteria, size note. Unique ids. `depends_on` references **earlier ids only**; graph acyclic. Status in enum `pending · in_progress · complete · blocked`. At most one `in_progress`. |
| `validate spec <path> --kind master\|phase [--master <path>]` | Core: required sections present or explicit `N/A — <reason>`; placeholder scan (TBD/TODO/`???`); red-flag phrase scan ("should", "probably", "handle appropriately") as warnings. Master: build-plan + cross-cutting decision register sections present; `D<n>` ids well-formed and unique; per-project task-count ceiling stated. Phase (requires `--master`): phase-delta sections present (status/revision provenance, provenance & governance, inherited contracts, scope & decomposition, out of scope, sizing flag); every cited `D<n>` resolves in the master's register; inherited restatements carry the `(inherited from <source>)` flag. |
| `validate plan <path>` | Header fields (goal, architecture, tech stack, spec path + conflict rule, global constraints). File-structure symbol table present. Per task: Files / Interfaces / Steps blocks; steps in TDD order (write-test → run-fail → implement → run-pass → gate/commit) with no missing run-fail step; checkbox syntax. Anti-pattern phrase scan ("similar to Task", "write tests for the above", "as above"). Forward-reference check of task symbols against the symbol table (warning severity — heuristic). |
| `next-phase <phase-plan>` | **Resume-first** deterministic resolution: an existing `in_progress` phase is returned before any `pending` one, flagged `resume: true` (the recovery path after an interrupted session — the skill reassesses that phase's partial state instead of starting a new phase). Otherwise: first `pending` entry whose `depends_on` are all `complete`. Outputs id/title/resume-flag/JSON; exit 1 if none resolvable (all done, or blocked graph). |
| `set-status <phase-plan> --id N --to <status>` | Legal transitions only: `pending→in_progress`, `in_progress→complete`, `in_progress→blocked`, `blocked→in_progress`, and the recovery transition `in_progress→pending` (abandon a wedged/stale run so the phase can be re-resolved cleanly). Atomic file rewrite (temp + rename). Illegal transition = exit 1, file untouched. |
| `status <phase-plan> [--state <path>]` | Rendered table: id → title → depends_on → status; next phase (resume-aware); round counters. State file resolution: explicit `--state`, else upward search from the phase-plan's directory for `.spec-pipeline/state.json` — deterministic regardless of invocation cwd or handoff layout. |
| `record-red --cmd <test-cmd> --task <id> --audit <path> [--framework pytest\|generic] [--expect-failure-regex <re>] [--timeout N]` | Runs the command under the execution-safety contract (below). Asserts **non-zero exit** AND — for the default `pytest` framework — that the failure is a genuine assertion/missing-symbol failure, not a collection/import/syntax error (pytest collection-error signatures). `--framework generic` (bats/Jest/other runners) preserves the fails-for-the-right-reason rule via `--expect-failure-regex`: when given, the output must match it (e.g. the expected failing assertion or "not defined" message) or RED is REJECTED; without a regex, any non-zero exit is accepted and the evidence block notes that failure-reason verification was unavailable. Appends an evidence block (task, command, timestamp, failure excerpt) to the audit file. Collection error, unmatched expectation, unexpected pass, or timeout = exit 1. |
| `record-green --cmd <test-cmd> --task <id> --audit <path> [--timeout N]` | Runs the command under the same contract; asserts exit 0; appends the passing evidence block. |
| `rounds <state-file> --gate spec\|plan\|final (--increment\|--check)` | Round counters with caps 3/3/5. `--increment` past the cap = exit 1 (the skill's signal to stop looping and record open findings). |
| `init-project [--dir <path>] [--handoff-dir <rel>]` | Scaffolds the minimal handoff layout the executor expects + an empty `phase-plan.md` from the template; appends `.spec-pipeline/` to `.gitignore`. Idempotent — never overwrites existing files. `--handoff-dir` (default `docs/handoff`) targets projects whose state layout differs. |

### Execution-safety contract (`record-red` / `record-green`)

The test command runs subprocess output into a **committed** audit file, so its execution is constrained:

- **No shell.** The command string is `shlex.split()` into argv and run with `shell=False` — metacharacters (`;`, `|`, `>`, `$()`) are inert. Commands needing shell features must be wrapped in an explicit script by the plan.
- **cwd** is the invocation directory; the skills invoke from the target project root.
- **Timeout** default 600 s (`--timeout` overrides). A timeout is a rejected gate (exit 1) and is recorded in the audit trail as such.
- **Output cap:** capture is truncated to 64 KiB before the last-30-lines excerpt is taken, so a runaway process cannot bloat the audit file.
- **Failure-reason verification** for non-pytest runners: the plan supplies `--expect-failure-regex` per generic-framework task so RED still means "failed for the right reason", mirroring the pytest collection-error rule.
- **Best-effort secret redaction** on the excerpt before append: common token shapes (`ghp_…`/`github_pat_…`, `AKIA…`, `xox[a-z]-…`, `sk-…`, `Bearer <jwt>`, `hvs.…`) are replaced with `[REDACTED]`. Best-effort by design — the skill-level rule remains that only test/verification commands from the reviewed plan may be passed, never arbitrary shell.
- **Append** is a single `O_APPEND` write (atomic for the sequential single-session use the skills perform; concurrent writers are out of scope).
- Rejected attempts (unexpected pass, collection error, timeout, failed GREEN) are ALSO appended, labelled `REJECTED` — the trail is honest about failed gates.

### Heading grammar (closes a real ambiguity)

The prose standards name sections but never pin exact headings. specpipe defines the canonical heading grammar (matched case-insensitively, `##`-level anchors), and the templates instantiate exactly that grammar. Authored-from-template artifacts therefore always parse; hand-authored artifacts get a clear error naming the missing/unrecognized heading. The grammar lives in one module (`specpipe/grammar.py`) that both the validator and the template tests import — a single source of truth.

## State locations (in the target project, not the plugin)

| Artifact | Location | Committed? |
| --- | --- | --- |
| Phase plan (statuses) | `docs/handoff/phase-plan.md` (existing contract, unchanged) | Yes |
| RED→GREEN audit trail | `docs/handoff/audit/phase-<id>.md` | Yes — it is the close-out evidence |
| Transient run state (round counters) | `.spec-pipeline/state.json` | No — gitignored by `init-project` |

Statuses live in the plan file; phase definitions live in the master spec; on conflict the master governs (unchanged from the current contract). Phase ids remain STABLE — never renumbered once execution begins.

**Non-handoff-v3 projects:** the paths above are the **greenfield defaults**, not requirements. The skills keep their existing rule — identify the project's handoff/state layout and conform to it — and `specpipe` is layout-agnostic by construction: every subcommand takes the phase-plan/audit path as an explicit argument. `init-project --handoff-dir` scaffolds into a non-default location; the audit directory always sits beside the phase-plan file (`<handoff-dir>/audit/`).

## Skill changes (the merge)

Content and process are preserved; the changes are mechanical plus validator-gate insertion:

### Both skills

- Rename to `author` / `execute-phase` under `skills/`; invocation becomes `/spec-pipeline:author` and `/spec-pipeline:execute-phase`.
- Reference paths → `${CLAUDE_PLUGIN_ROOT}/references/`; the duplicated `spec-construction.md` collapses to one file.
- A shared "Validator gate" paragraph: at each gate, run the named specpipe subcommand; **errors must be fixed before the workflow/Codex pass**; warnings may be accepted with a one-line recorded justification.

### author (was author-master-spec)

- Step 3/4 (spec + decomposition): instantiate from `templates/master-spec.md` and `templates/phase-plan.md`.
- Step 5 (review): insert `specpipe validate spec --kind master` + `specpipe validate phase-plan` **before** the single ultracode pass; Codex convergence loops call `specpipe rounds --gate spec` instead of counting in-context.
- Step 6 (init handoff): delegate scaffolding to `specpipe init-project`.

### execute-phase (was autonomous-phase-execution)

- Step 1 (resume): resolve the phase with `specpipe next-phase`. If it reports `resume: true` (a prior session left the phase `in_progress`), reassess that phase's partial state — committed tasks stand, the phase continues from the first incomplete task — or, if the partial run is unsalvageable, `set-status … --to pending` to abandon cleanly and re-resolve. For a fresh phase, mark it `in_progress` via `set-status`.
- Step 2 (spec): instantiate from `templates/phase-spec.md`; run `specpipe validate spec --kind phase --master <master>` before the workflow pass; `rounds --gate spec` for Codex.
- Step 3 (plan): instantiate from `templates/implementation-plan.md`; `specpipe validate plan` before the workflow pass; `rounds --gate plan`.
- Step 4 (implement): each task's RED and GREEN runs go through `record-red` / `record-green` targeting `docs/handoff/audit/phase-<id>.md` — the audit trail becomes captured subprocess output, not self-report. `record-red`'s collection-error detection encodes the existing rule that a test erroring on collection has not established RED.
- Step 6 (final review): `rounds --gate final` (cap 5).
- Step 7 (close out): `set-status --to complete`; the close-out report cites the committed audit file.

TDD SCOPE, TDD GUARDRAILS, HALT CONDITIONS, orchestration model, and the review allocation philosophy are unchanged. Validator failures at a gate are not new HALT conditions — the skill fixes errors and re-runs the validator (it is deterministic and free); HALT semantics stay tied to the review loops and irreversible decisions as today.

## Templates

Four templates derived jointly from the reference standards and the specpipe grammar:

- `master-spec.md` — all core + master-delta sections, each with a one-line guidance comment (what belongs here, per the standard).
- `phase-spec.md` — core + phase-delta sections, including provenance/inheritance scaffolding with `(inherited from …)` flag examples.
- `implementation-plan.md` — plan header, file-structure table, and a task skeleton with the six TDD-ordered steps as checkboxes.
- `phase-plan.md` — the per-entry schema block (id, title, status, objective, scope, depends_on, spec slice, acceptance, size note).

## Testing strategy

- Pytest suite under `plugins/spec-pipeline/tests/` (TEST-001: frameworks by language).
- Fixture-driven: for **every validator rule**, at least one failing fixture and one passing fixture (adversarial pairs — e.g. a phase-plan with a forward dependency, a cycle, a duplicate id; a plan task missing its run-fail step; a phase spec citing `D9` when the master defines `D1..D7`).
- State-op recovery fixtures: a stale `in_progress` phase (next-phase must return it with `resume: true`), the `in_progress→pending` abandon transition, and illegal transitions leaving the file untouched.
- `record-red` / `record-green` tested against a toy pytest project fixture: genuine assertion failure (accepted), collection error (rejected), unexpected pass (rejected), timeout (rejected), shell metacharacters inert under argv execution, secret-shaped output redacted in the appended excerpt, `--framework generic` accepting a non-pytest failure.
- Template↔grammar conformance test: every template parses clean through its validator (imports `grammar.py` directly).
- `validate-marketplace.sh` covers the new marketplace entry AND the plugin manifest (it validates `plugin.json` required fields, allowed-field strictness, author shape, and marketplace/manifest version consistency).
- `claude plugin validate --strict plugins/spec-pipeline` — the official runtime validator, warnings-as-errors — runs as an acceptance gate alongside the local script.

## Acceptance criteria

1. `claude plugin` loads `spec-pipeline` from the marketplace with no errors; all five surfaces resolve (`/spec-pipeline:author`, `:execute-phase`, `:validate`, `:status`, `:init-project`).
2. `specpipe` full pytest suite green; every subcommand covered by adversarial fixture pairs.
3. All four templates validate clean through their respective validators.
4. Both skills reference only plugin-local paths (`${CLAUDE_PLUGIN_ROOT}/…`); no residual pointers into `agent-configs`.
5. `references/` contains exactly one `spec-construction.md` (deduped) and the three sibling standards, unmodified in content.
6. Marketplace entry and plugin manifest pass both `validate-marketplace.sh` and `claude plugin validate --strict plugins/spec-pipeline`; version 0.1.0.
7. Recovery semantics hold under test: a stale `in_progress` phase resumes via `next-phase`; `in_progress→pending` abandons cleanly; illegal transitions leave the phase-plan byte-identical.
8. Evidence capture is safe under test: shell metacharacters are inert, timeouts reject the gate, secret-shaped output is redacted before the excerpt is appended, and a generic-framework RED with an unmatched `--expect-failure-regex` is rejected.
9. specpipe invocations leave the plugin tree clean: after running the canonical invocation, `git status --short plugins/spec-pipeline/scripts/specpipe` is empty (no `.venv/`, `uv.lock`, or cache writes).

## Out of scope / follow-ups

- Deprecating/removing the two source skills in `agent-configs` after the plugin is installed and smoke-tested (user decision, separate change in that repo).
- Enforcement hooks (frozen-test PreToolUse block) — possible v2 once validators prove out.
- Machine-readable requirement-ID inventory + coverage validator — possible v2 if panel-only scope coverage proves insufficient (see SA-001).
- Any change to the review backends or their hard-required status.

## Codex review ledger

| Round | Verdict | Findings → resolution |
| --- | --- | --- |
| 1 (2026-07-01, `docs/codex-reviews/2026-07-01-182633-codex-spec-review-round1.md`) | Needs major correction (3 blocking / 3 medium) | SA-001 scope-coverage contradiction → goals narrowed; coverage explicitly review-only, v2 candidate noted. SA-002 stranded `in_progress` → resume-first `next-phase`, `in_progress→pending` recovery transition, skill resume semantics. SA-003 unsafe evidence capture → execution-safety contract (argv/no-shell, timeout, output cap, redaction, O_APPEND). SA-004 pytest-specific RED → `--framework pytest\|generic` boundary. SA-005 state resolution → `status --state` + upward search. SA-006 stale validator claim → corrected; `claude plugin validate --strict` added to acceptance. |
| 2 (2026-07-01, `docs/codex-reviews/2026-07-01-183657-codex-spec-review-round2.md`) | Needs minor correction (0 blocking / 2 medium; SA-001/002/003/005/006 resolved) | SA-004 residual (generic RED weaker than fails-for-the-right-reason) → `--expect-failure-regex` contract for generic frameworks. SA-NEW-001 (`uv run --directory` would lock/sync `.venv`+`uv.lock` into the plugin root) → dropped Python project machinery entirely; plain package dir + `PYTHONPATH` + `uv run --no-project`; clean-tree acceptance criterion added. |
