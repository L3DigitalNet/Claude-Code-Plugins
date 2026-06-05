# Codex Instructions for Claude-Code-Plugins

**Session state:** read `docs/handoff/state.md`, then this file, then `docs/handoff/conventions.md`.

**Full conventions reference:** [`docs/handoff/conventions.md`](docs/handoff/conventions.md) - LLM-targeted pattern library. Every convention follows the six-field schema (Applies-when / Rule / Code / Why / Sources / Related) with a Quick Reference table at the top for O(1) lookup. Do not introduce new patterns without checking conventions first.

**Detailed review workflows:** [AGENTS.reviews.md](AGENTS.reviews.md) - read this only for review-related tasks (review planning, review sweeps, code/security/test/etc. reviews). The verbose per-review routing, defaults, and orchestrator notes live there.

## Repo Purpose

Plugin authoring and release workspace for Claude Code / Codex plugins.

## Key Rules

- Treat `docs/specs/` as the architectural source of truth for plugin behavior and marketplace schema.
- Keep `.codex-plugin/plugin.json`, plugin folders, command wiring, and marketplace metadata in sync.
- Validate substantive plugin changes with the plugin test harness before wrapping up.
- Preserve documented enforcement layers, hooks, and release-pipeline expectations when refactoring.
- **Branch workflow:** direct commit to `main`. No `testing` branch — that convention was retired 2026-05-07. For plugin releases, use the release-pipeline plugin (Codex equivalent of `/release-pipeline:release`). See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md).
