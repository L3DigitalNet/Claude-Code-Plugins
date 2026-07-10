# Codex Instructions for Claude-Code-Plugins

**Session state:** Agent Handoff SessionStart injects `docs/handoff/state.md`; do not reread it when injected. Then use this file and `docs/handoff/conventions.md`.

**Full conventions reference:** [`docs/handoff/conventions.md`](docs/handoff/conventions.md) - LLM-targeted pattern library. Every convention follows the six-field schema (Applies-when / Rule / Code / Why / Sources / Related) with a Quick Reference table at the top for O(1) lookup. Do not introduce new patterns without checking conventions first.

**Detailed review workflows:** [AGENTS.reviews.md](AGENTS.reviews.md) - read this only for review-related tasks (review planning, review sweeps, code/security/test/etc. reviews). The verbose per-review routing, defaults, and orchestrator notes live there.

## Repo Purpose

Plugin authoring and release workspace for Claude Code / Codex plugins.

## Key Rules

- Treat the design specs indexed in `docs/handoff/specs-plans.md` (stored under `docs/plans/`, `docs/research/`, and `docs/superpowers/{specs,plans}/`) as the architectural source of truth for plugin behavior; the marketplace schema lives in `docs/handoff/architecture.md`.
- Keep `.claude-plugin/plugin.json`, plugin folders, command wiring, and marketplace metadata in sync.
- Validate substantive plugin changes with the plugin test harness before wrapping up.
- Preserve documented enforcement layers, hooks, and release-pipeline expectations when refactoring.
- **Branch workflow:** direct commit to `main`. No `testing` branch — that convention was retired 2026-05-07. For plugin releases, use the release-pipeline plugin (Codex equivalent of `/release-pipeline:release`). See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md).

## Markdown & Structured-Text Tooling

This repository follows the Markdown Tooling Standard (project-standards v3.0.0). Prettier formats the structured-text it supports (`md`/`json`/`jsonc`/`yaml`/`code-workspace`); markdownlint lints Markdown structure only. JS/TS source is excluded from Prettier via `.prettierignore`. MD060 is enabled at `{style: "leading_and_trailing", aligned_delimiter: false}` (Prettier-compatible; the standard's `{style: "any"}` conflicts with Prettier's empty-cell rendering). Both deviations recorded in [`docs/decisions/adr-0001-prettier-jsts-scope.md`](docs/decisions/adr-0001-prettier-jsts-scope.md). Do not introduce a competing formatter or linter.

### Fix pass

When changing Markdown, JSON, JSONC, or YAML, run the fix pass first:

```bash
npx prettier --write .
npx markdownlint-cli2 --fix "**/*.md"
```

### Check contract

Before considering work complete, run the non-mutating check:

```bash
npx prettier --check .
npx markdownlint-cli2 "**/*.md"
```

Do not claim completion if either command fails.

### Rules

- Prettier owns physical formatting. Do not fight its output or hand-format.
- markdownlint owns Markdown structure. Do not disable a rule to silence a warning — fix the Markdown.
- Do not edit `.prettierrc.json` or `.markdownlint.json` to bypass a check without a documented ADR exception.

<!-- BEGIN agent-handoff managed instructions -->
Use the repo-local `$agent-handoff` skill at startup and closeout.
Do not reread `docs/handoff/state.md` when SessionStart already injected it.
Keep current status and tasks in `docs/STATUS.md` and `docs/TODO.md`; route durable facts through `docs/handoff/`.
At closeout, update only changed facts, preserve user-authored work, store credential references only, and run relevant validation.
<!-- END agent-handoff managed instructions -->
