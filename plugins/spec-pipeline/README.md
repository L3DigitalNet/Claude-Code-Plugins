# spec-pipeline

Spec-driven autonomous development pipeline for Claude Code: author a canonical master spec once, decompose it into ordered phases, then execute each phase end-to-end under TDD — with deterministic validator gates in front of every expensive review pass.

## How it works

1. `/spec-pipeline:author <brief>` — writes the master spec and phase plan from a project brief (one human checkpoint: architecture + scope), reviews them through a single ultracode workflow pass plus Codex convergence, and seeds the handoff layout.
2. `/spec-pipeline:execute-phase <project>` — resolves the next pending phase, derives its phase spec and implementation plan from the master, implements task-by-task under strict RED→GREEN→refactor TDD with frozen tests, and closes out the handoff state. One phase per session.

Every artifact gate runs the bundled `specpipe` CLI first: structural defects (missing sections, dangling decision-id citations, dependency cycles, broken TDD step order, placeholders) are caught deterministically and for free, so the review panels spend their budget on semantics.

## Commands

| Command | Purpose |
| --- | --- |
| `/spec-pipeline:author` | Author master spec + phase decomposition (run once at inception) |
| `/spec-pipeline:execute-phase` | Execute the next pending phase end-to-end (run once per phase) |
| `/spec-pipeline:validate` | Run the structural validators against any artifact, standalone |
| `/spec-pipeline:status` | Phase table, next pending phase, review-round counters |
| `/spec-pipeline:init-project` | Scaffold the minimal handoff layout without authoring a spec |

## The specpipe CLI

Stdlib-only Python with no packaging at all — a plain package directory imported via `PYTHONPATH` and run with `uv run --no-project`, so no invocation ever writes a venv or lockfile into the plugin. Query subcommands (`validate`, `next-phase`, `status`) support `--json`; state operations speak via exit codes and stable single-line output. Exit codes are `0` clean, `1` findings/failure, `2` bad invocation.

| Subcommand | Enforces |
| --- | --- |
| `validate phase-plan` | Entry schema, unique stable ids, earlier-only acyclic dependencies, status enum, single active phase |
| `validate spec --kind master\|phase` | Required sections, placeholder/red-flag scans, decision register + task ceiling (master), decision-id citation resolution + inheritance flags (phase) |
| `validate plan` | Header, symbol table, per-task Files/Interfaces, TDD step order, anti-patterns, forward references |
| `next-phase` | First pending phase whose dependencies are complete — computed, not re-read |
| `set-status` | Legal status transitions only, atomic rewrite |
| `status` | Phase table + round counters |
| `record-red` / `record-green` | Runs the test command under the safety contract (argv/no-shell, timeout, output cap, redaction), rejects collection errors as RED (pytest) or unmatched `--expect-failure-regex` (generic), appends evidence to the committed audit trail |
| `rounds` | Codex convergence round caps (spec 3 / plan 3 / final 5) |
| `init-project` | Idempotent handoff scaffolding |

## State locations (in the target project)

- `docs/handoff/phase-plan.md` — phase statuses (committed; definitions live in the master spec, which governs on conflict)
- `docs/handoff/audit/phase-<id>.md` — RED→GREEN evidence trail (committed with the phase)
- `.spec-pipeline/state.json` — transient round counters (gitignored)

The `docs/handoff/` paths are greenfield defaults, not requirements: the skills conform to whatever handoff/state convention the project already uses, specpipe takes every path as an explicit argument, and `init-project --handoff-dir` scaffolds into a non-default layout (the audit dir always sits beside the phase plan).

## Requirements

- [uv](https://docs.astral.sh/uv/) on PATH (supplies the interpreter via `--no-project`; specpipe itself has zero deps and no packaging)
- Python ≥ 3.11
- The review gates hard-require a `/codex-review` skill (Codex CLI) and ultracore workflow support; the skills HALT if unavailable

## Layout

- `skills/author`, `skills/execute-phase` — the two pipeline skills
- `commands/` — thin wrappers over specpipe
- `references/` — the shared spec/plan construction standards (the review rubric)
- `templates/` — artifact templates; their headings are the exact grammar specpipe validates
- `scripts/specpipe/` — the validator CLI, a plain stdlib package (pytest suite in `tests/`; no pyproject/venv/lock by design)
