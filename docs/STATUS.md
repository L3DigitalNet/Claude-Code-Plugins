# Project Status

## Current snapshot

- Marketplace `l3digitalnet-plugins` lists six plugins; all are at their latest tag with no unreleased changes.
- The repository uses direct commits to `main`; plugin releases are manual (version bump + tag `<name>/vX.Y.Z` + `gh release create`).
- Repository documentation is enforced by Prettier and markdownlint (both gates green repo-wide as of 2026-07-10; the `docs/handoff/bugs/` index generator now emits Prettier-clean tables; the CHANGELOG/emphasis drift noted 2026-07-09 is cleared). Per DOC-006, completed plans and resolved Codex reviews are now deleted (specs/designs retained); the `docs/codex-reviews/` formatter exemption stays for future transient review batches.
- `spec-pipeline` v0.2.0 is released; its live smoke test and source-skill deprecation decision remain open.
- qdev is at v2.0.6 (2026-07-10, three releases in one sweep): `build_research_index.py` now emits MD060-safe em-dash cells, a v3 `validate-id`-compliant stable index id, Prettier-indented frontmatter sequences, and preserves a consumer repo's own id/description on regen — closing the standing red-CI-on-regen defect in consumer repos (homelab, agent-configs).
- Agent Handoff v1 provides one shared repo-local SessionStart runtime for the dual Claude/Codex profile.
