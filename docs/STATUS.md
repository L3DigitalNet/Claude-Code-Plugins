# Project Status

## Current snapshot

- Marketplace `l3digitalnet-plugins` lists six plugins; all are at their latest tag with no unreleased changes.
- The repository uses direct commits to `main`; plugin releases are manual (version bump + tag `<name>/vX.Y.Z` + `gh release create`).
- Repository documentation is enforced by Prettier and markdownlint, with generated `docs/codex-reviews/` evidence excluded. Both gates are green repo-wide as of 2026-07-10 (the `docs/handoff/bugs/` index generator now emits Prettier-clean tables; the CHANGELOG/emphasis drift noted 2026-07-09 is cleared).
- `spec-pipeline` v0.2.0 is released; its live smoke test and source-skill deprecation decision remain open.
- Agent Handoff v1 provides one shared repo-local SessionStart runtime for the dual Claude/Codex profile.
