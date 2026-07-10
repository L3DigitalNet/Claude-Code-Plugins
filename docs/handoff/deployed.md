# What Is Deployed

| Plugin | Version | Status |
| --- | --- | --- |
| home-assistant-dev | 2.2.10 | Released 2026-05-25 (final batch); Dependabot CVE remediation: `qs >=6.15.2` + `fast-uri >=3.1.2` npm overrides (closes GHSA-q3j6, GHSA-v39h, GHSA-q8mj CVEs in @modelcontextprotocol/sdk transitive deps). Rebuilt dist/server.bundle.cjs (847.5kb). Prior 2.2.9 (2026-05-25): TS 6 compatibility fix (`"types": ["node"]` in tsconfig.json). GitHub release tag: `home-assistant-dev/v2.2.10` |
| qt-suite | 0.3.3 | Released (tag `qt-suite/v0.3.3`, GitHub release published). Prior 0.3.2 (2026-05-25): TEST-003 prophylactic fix applied to `tests/test_helper.bash`. Prior 0.3.1 (2026-04-23): agent model downgrade. |
| qdev | 2.0.2 | Released 2026-06-12 (tag `qdev/v2.0.2`). 2.0.1 (2026-06-08): Prettier normalization + markdownlint fixes. 2.0.2 (2026-06-12): changelog structure fix, re-sync vendored schema, README v2 search model update. Research-only as of 2026-06-07 (search decoupling): removed `/quality-review`, `/deps-audit`, `/doc-sync`, `/spec-update` + their agents and the grounding skill + `sanitize_query.py`; routine search moved to the agent-configs `web-search` skill. `/qdev:research` (qdev-researcher, Sonnet) + research-KB scripts retained. Prior 1.6.0 (2026-06-05): D2 grounding skill + sanitizer (now removed). Prior 1.5.0 (2026-05-08): `/qdev:research` extracted to subagent. |
| up-docs | 0.13.0 | Released 2026-06-12 (tag `up-docs/v0.13.0`, GitHub release published; commit `e831f1e`). Repo + Notion propagators promoted Haiku → Sonnet — all sub-agents now Sonnet (`8f56efa`). PATH-shim fix (`19595e2`, Bug 8) committed but unreleased — ships with next release. Prior 0.12.0 (2026-06-08, tag `up-docs/v0.12.0`): wiki layer retargeted to canonical repo on GMK CT 103 (`/srv/workspaces/llm-wiki`) over SSH (alias `llm-wiki`); propagator + drift-audit wiki phase + commit offer run inside the LXC. Prior 0.11.0 (2026-06-07): `touched_pages` tracking, routing-matrix fail-open, `commit-candidates.sh` + no-push Step-6 consent gate. Prior 0.10.x (2026-06-07): llm-wiki cutover, link-audit parallelization, Bug 7 bats false-green fixed. |
| uv-strict-python | 0.2.0 | Released 2026-06-12 (tag `uv-strict-python/v0.2.0`, GitHub release published; commit `c981da1`). Conformance pass vs project-standards (`e57850f`) + features (`9d5761b`): scope-gated shims (Python-project markers + `.local.md` override), BasedPyright LSP (`.lsp.json`, standard §13), standard-sync drift test, 9 scaffold templates (6 byte-identical to adopt bundle), tests in `tests/` (waiver removed). Cache picks up gating/LSP at next session start. Prior 0.1.0 (2026-06-09): initial release. |

## Recently Removed (2026-07-10)

release-pipeline — deleted from `plugins/` and the marketplace catalog. Removal spanned both planes: repo (`plugins/release-pipeline/`, `.claude-plugin/marketplace.json`, `.claude/settings.json`, README/CLAUDE/AGENTS/BRANCH_PROTECTION/copilot-instructions, `docs/`, `docs/handoff/`) and live Claude Code state (`installed_plugins.json`, plugin cache, catalog clone). Unlike prior removals, **all 13 tags (`release-pipeline/v1.0.0`…`v2.2.3`) and all 13 GitHub releases were deleted** (local + remote), not retained. Plugin releases are now a manual git-tag + `gh release create` process — see [BRANCH_PROTECTION.md](../../BRANCH_PROTECTION.md).

test-driver — deleted from `plugins/` and the marketplace catalog. **All 7 tags (`test-driver/v0.1.0`…`v0.6.2`) and their 7 GitHub releases were deleted** (local + remote). The now-orphaned `.release-waivers.json` (a release-pipeline pre-flight artifact, unused after that plugin's removal) was deleted in the same pass. Live state cleaned: `installed_plugins.json` (llm-wiki project-scope entry) + plugin cache + catalog clone.

## Recently Removed (2026-06-08)

github-repo-manager, plugin-test-harness, repo-hygiene — deleted from `plugins/` (unused). Marketplace count went 9 → 6. GitHub release tags (`github-repo-manager/v0.5.1`, `plugin-test-harness/v0.7.7`, `repo-hygiene/v1.4.1`) retained for historical install.

## Recently Removed (2026-05-30)

opus-context, handoff, nominal — deleted from `plugins/` (unused). Marketplace count went 12 → 9. Removal spanned both planes: repo (`plugins/`, `marketplace.json`, `README.md`, `docs/`, `testing/`) and live Claude Code state (`settings.json` `enabledPlugins`, `installed_plugins.json`, plugin cache, catalog clone). GitHub release tags (`opus-context/v1.1.1`, `handoff/v0.2.1`, `nominal/v1.1.1`) retained for historical install.

## Recently Removed (2026-05-08)

claude-sync, design-assistant, docs-manager, linux-sysadmin, python-dev — deleted from `plugins/` in commit 3b8323e (`Cleaning up old plugins.`). Marketplace count went 17 → 12. All doc layers reconciled in the same session.

## What Remains

- **up-docs PATH-shim hardening committed but unreleased** (`19595e2`, Bug 8): 6 python3-invoking scripts guard against uv-strict-python's python3 shims. Ships with the next up-docs release.
- **home-assistant-dev typescript-eslint bump committed but unreleased** (`4fa2aac`, 2026-06-08): bumps `@typescript-eslint/eslint-plugin`+parser to `^8.60.1` (admits TypeScript 6.0.x) and adds `@eslint/js ^10.0.1`; cleared the `npm run lint` / `npm ci` ERESOLVE failures present since 2026-05-25. Ships with the next home-assistant-dev release.
- **home-assistant-dev — all 284 review findings implemented, committed but unreleased** (`2375c3c..4cfa41d`, 2026-06-14, 185 commits): full-spectrum review implementation (7 Critical / 38 High / 93 Medium / 146 Low) across MCP server (TS), Python scripts, 27 skills, examples, templates, docs — incl. F1 `ws` WebSocket polyfill, F2/F10 `verify_ssl`, F155 dead MCP doc-cache removal (`saveToCache`/`loadFromCache` + `docsTtlHours` plumbing), F167 new `validate-strings.test.ts` (jest now 41 tests). `dist/server.bundle.cjs` rebuilt and committed (bundle fresh). No version bump — version stays **2.2.10**; ships with the next home-assistant-dev release alongside the typescript-eslint bump.
- **Verify uv-strict-python LSP loads** after the next session's cache sync: `/reload-plugins`, then `/plugin` Errors tab (needs `basedpyright-langserver` or uvx).
- Monitor Tavily `search_depth=fast` vendor bug (returns empty results for queries `basic` answers correctly). Inline-noted in routing rules; revisit if Tavily fixes upstream.
- Centralize bats wrapper to `scripts/run-plugin-bats.sh` (now 4 copies of `tests/run-bats.sh` after de-listing github-repo-manager, plugin-test-harness, repo-hygiene — was 6). TEST-002 in conventions covers the workaround pattern; centralization is optional cleanup.
