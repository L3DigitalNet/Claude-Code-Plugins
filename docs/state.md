# Handoff

**Last updated:** 2026-05-29 (up-docs v0.8.2–v0.8.4: deny-guard removal, evidence-graded review, state.md cap fix)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

None.

## Recently closed (this session, 2026-05-29)

- **up-docs v0.8.2 → v0.8.4** — v0.8.2: removed the unsound PreToolUse deny-guard hook (fired on every Bash call = latency tax; subagent-scope detection was architecturally broken; redundant with engine-enforced `permissions.deny`). v0.8.3: evidence-graded review — deleted orphaned `notion-guidelines.md` (A5), fixed `drift-finding.md` evidence schema → structured object (B1), extracted shared `templates/post-propagation-steps.md` (B2), retagged audit example #3 `low`→`unverifiable`. v0.8.4: state-conditioned the `docs/state.md` 2 KB cap rule in `propagate-repo` — it was transition-conditioned ("if edits push over"), so an already-over file never trimmed; caught dogfooding `/up-docs:repo` this run with state.md at 11 KB (5.5× cap). 48 bats + 26 pytest. Tags `up-docs/v0.8.2..v0.8.4`. Full detail in `docs/sessions/2026-05.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
