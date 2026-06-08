# Handoff

**Last updated:** 2026-06-07 (up-docs v0.11.0 orchestration improvements implemented + released — tag `up-docs/v0.11.0` + GitHub release; marketplace index refreshed)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-08)

- **qdev grounding skill removed (search decoupling).** The D2 grounding skill + `sanitize_query.py` were deleted; routine search moved to the agent-configs `web-search` skill. This supersedes the pending D2 Task-7 manual matrix (no longer applicable). qdev bumped to 2.0.0 (research-only). See `docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md`.
- **up-docs v0.11.0 released** (`up-docs/v0.11.0` tag + GitHub release): 8-task plan executed via `superpowers:subagent-driven-development` — (A) `touched_pages` auditor narrowing, (B) routing-matrix fail-open empty-layer skip, (C) baseline-safe consent-gated Step 6 commit offer (`commit-candidates.sh`). 6 review-driven fixes (incl. a real inert-feature defect: part (c) was unreachable). 78 bats + 29 pytest green; commits `b0c8170..29747fe` pushed; tag-only release; marketplace clone refreshed. Full detail in `sessions/2026-06.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
