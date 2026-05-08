# Handoff

**Last updated:** 2026-05-08

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

None.

## Recently closed (this session, 2026-05-08)

- **simple-git RCE remediation** — alert #87 (HIGH severity, RCE in `simple-git < 3.36.0`) surfaced after the moderate alerts dropped off in the rescan. Direct dep in `plugins/github-repo-manager/helper/package.json` at `^3.33.0`; existing caret range already permitted the patched `3.36.0`. Bumped floor to `^3.36.0` for explicitness, refreshed lockfile (`3.33.0 → 3.36.0`). No automated test suite for the helper; smoke-tested via `node --check bin/gh-manager.js` and dynamic `import('./src/commands/wiki.js')` — both clean. `simple-git` is used only in `src/commands/wiki.js` for wiki-repo clone/push, so the RCE exposure surface was wiki sync against an attacker-controlled remote (low real-world risk for this single-developer use case but still warranted the fix).
- **Dependabot CVE remediation** — 4 open alerts closed via `npm overrides` in `plugins/{plugin-test-harness,home-assistant-dev/mcp-server}/package.json`. `hono >=4.12.14` (CVE: HTML injection in JSX SSR) and `ip-address >=10.1.1` (CVE: XSS in Address6 HTML methods). Both are transitive deps of `@modelcontextprotocol/sdk@^1.27.1` (`hono` direct, `ip-address` via `express-rate-limit`). Lockfiles resolved to `hono@4.12.18` and `ip-address@10.2.0`. Test suites green (pth 68/68, ha-dev mcp-server 31/31). Runtime exposure was effectively zero in both plugins — both ship stdio-only MCP servers, esbuild tree-shakes the HTTP transport that imports the vulnerable code paths (verified: `grep -c "Hono\|StreamableHttp" dist/server.bundle.cjs` = 0). No bundle rebuild or plugin re-release required; the lockfile change closes the alerts at the source-of-truth Dependabot scans.
- **5 plugins removed from marketplace** — commit `3b8323e` (`Cleaning up old plugins.`) deleted `plugins/{claude-sync,design-assistant,docs-manager,linux-sysadmin,python-dev}/` from disk. Doc reconciliation pass propagated the removal across every layer that listed plugins by name: `marketplace.json` (17 → 12 entries), `README.md` (intro paragraph + table + 5 sections + repo-structure tree), `docs/architecture.md` (count + tree), `docs/deployed.md` (3 rows dropped: docs-manager / python-dev / linux-sysadmin), `docs/conventions.md` (TEST-001 test-counts list + TEST-002 affected-plugins list), `docs/skills.md` (Linux Sysadmin Skill Conventions section removed, 87 lines), `docs/plugin-marketplaces.md` (example plugin swapped design-assistant → release-pipeline), `docs/plugin-design-template-full.md` (broken pointer to docs-manager/docs/design.md removed), `testing/STRATEGY.md` (in-scope 15 → 11; priority table trimmed; document index 14 → 11), `testing/plans/{claude-sync,design-assistant,docs-manager,linux-sysadmin}.md` deleted. `.serena/` directory was already in a deleted-but-unstaged state on entry (separate cleanup, not touched by this task). `docs/plans/`, `docs/superpowers/{plans,specs}/`, `docs/ux_refresh/`, `docs/sessions/2026-04.md`, `.release-waivers.json` left as-is — historical artifacts, not current-state docs.

## Recently closed (previous session, 2026-05-07)

- **Marketplace-wide search-MCP migration** — replaced garylab Python `serper-mcp-server` with marcopesani `serper-search-scrape-mcp-server`; added official Tavily HTTP MCP. Routing rule rewritten as a per-intent table in global Claude/Codex instructions + 6 repo rule files. 3 plugins re-released for migration: qdev v1.4.0, docs-manager v0.2.4 (since removed), home-assistant-dev v2.2.8.
- **Testing-branch convention retired** — `testing` branch deleted (local + remote), GitHub `lock_branch` protection on `main` removed, 14 local `tests/*` branches deleted with their Phase 2 work (~225 cases) cherry-picked to `main`. Rule docs rewritten across `BRANCH_PROTECTION.md`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `.github/copilot-instructions.md`, `docs/architecture.md`.
- **release-pipeline v2.2.0 bootstrap-released** — Phase 3 of all release modes simplified to drop `git checkout main && git merge testing --no-ff`; uses `git pull --rebase origin main` instead. Mode 1 renamed Quick Merge → Quick Push.
- **plugin-test-harness v0.7.5 released** — 4 environmental test failures fixed by setting `core.hooksPath=/dev/null` in tmpdir test repos so workstation pre-commit hooks don't reject test commits. See bug 005 + convention TEST-003.
