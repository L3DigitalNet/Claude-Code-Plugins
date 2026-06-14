# Handoff

**Last updated:** 2026-06-14 (markdown-tooling → project-standards v3.0.0; commit `2d196df`)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## Recently closed (this session, 2026-06-14)

- **markdown-tooling standard bumped to project-standards v3.0.0** (`2d196df`): `.github/workflows/lint-markdown.yml` caller pin `@v2` → `@v3`; MD060 enabled at `{style:leading_and_trailing, aligned_delimiter:false}` (Prettier-compatible; `{style:any}` gave 152 violations); `prettier --write .` formatted 15 pre-existing-dirty files; 30 pre-existing markdownlint errors cleared (MD031 in up-docs-llm-wiki plan, MD040 in uv-strict-python uv-commands.md). Gate clean: `markdownlint-cli2 **/*.md` 0 errors, `prettier --check .` passes. ADR-0001 revised to supersede the original MD060-disable. `docs/standards-refresh-ledger.md` scratch detection ledger created, then removed during the same session's drift-convergence cleanup.
- **Docs converged — `/up-docs:all` + a `/up-docs:drift` convergence loop** (9 audit rounds → `converged`; `4de7fd0`, `49168e1`, `c85bbf6`, `be6b966`): propagated to repo + wiki (MD060×Prettier gotcha → `646a73f` on CT 103); ~30 ground-truthed handoff/CI fixes (qdev `2.0.0`→`2.0.2`, README `6`→`7` plugins, Haiku→Sonnet labels, retired-`testing` triggers, CHANGELOG dedup, test counts); removed an orphaned CI workflow + the scratch ledger; 2 Notion drifts fixed (llm-wiki remote, resume 7 plugins).

Detail in `sessions/2026-06.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
