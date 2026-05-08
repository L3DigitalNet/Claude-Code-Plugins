# Handoff

**Last updated:** 2026-05-07

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

None.

## Recently closed (this session, 2026-05-07)

- **Marketplace-wide search-MCP migration** — replaced garylab Python `serper-mcp-server` with marcopesani `serper-search-scrape-mcp-server`; added official Tavily HTTP MCP. Routing rule rewritten as a per-intent table in global Claude/Codex instructions + 6 repo rule files. 3 plugins re-released for migration: qdev v1.4.0, docs-manager v0.2.4, home-assistant-dev v2.2.8.
- **Testing-branch convention retired** — `testing` branch deleted (local + remote), GitHub `lock_branch` protection on `main` removed, 14 local `tests/*` branches deleted with their Phase 2 work (~225 cases) cherry-picked to `main`. Rule docs rewritten across `BRANCH_PROTECTION.md`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `.github/copilot-instructions.md`, `docs/architecture.md`.
- **release-pipeline v2.2.0 bootstrap-released** — Phase 3 of all release modes simplified to drop `git checkout main && git merge testing --no-ff`; uses `git pull --rebase origin main` instead. Mode 1 renamed Quick Merge → Quick Push.
- **plugin-test-harness v0.7.5 released** — 4 environmental test failures fixed by setting `core.hooksPath=/dev/null` in tmpdir test repos so workstation pre-commit hooks don't reject test commits. See bug 005 + convention TEST-003.
