# What Is Deployed

| Plugin | Version | Status |
| --- | --- | --- |
| home-assistant-dev | 2.2.10 | Released 2026-05-25 (final batch); Dependabot CVE remediation: `qs >=6.15.2` + `fast-uri >=3.1.2` npm overrides (closes GHSA-q3j6, GHSA-v39h, GHSA-q8mj CVEs in @modelcontextprotocol/sdk transitive deps). Rebuilt dist/server.bundle.cjs (847.5kb). Prior 2.2.9 (2026-05-25): TS 6 compatibility fix (`"types": ["node"]` in tsconfig.json). GitHub release tag: `home-assistant-dev/v2.2.10` |
| qt-suite | 0.3.2 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars; no test-suite delta). Prior 0.3.1 (2026-04-23): agent model downgrade. GitHub release tag: `qt-suite/v0.3.2` |
| qdev | 2.0.0 | Released 2026-06-08 (tag `qdev/v2.0.0`, GitHub release published). Research-only as of 2026-06-07 (search decoupling): removed `/quality-review`, `/deps-audit`, `/doc-sync`, `/spec-update` + their agents and the grounding skill + `sanitize_query.py`; routine search moved to the agent-configs `web-search` skill. `/qdev:research` (qdev-researcher, Sonnet) + research-KB scripts retained. Prior 1.6.0 (2026-06-05): D2 grounding skill + sanitizer (now removed). Prior 1.5.0 (2026-05-08): `/qdev:research` extracted to subagent. |
| up-docs | 0.12.0 | Released 2026-06-08 (tag `up-docs/v0.12.0`, GitHub release published; commit `0f07df6`). Wiki layer retargeted from local `~/projects/llm-wiki` to the canonical repo on GMK CT 103 (`/srv/workspaces/llm-wiki`), accessed only over SSH (alias `llm-wiki`); wiki propagator + drift-auditor wiki phase + commit offer all run inside the LXC over SSH. Pre-release: fixed dead `docs/plans/2026-05-08-up-docs-hardening-plan-v1-audit.md` link in CHANGELOG.md [0.8.0] notes. Prior 0.11.0 (2026-06-07, tag `up-docs/v0.11.0`): orchestration improvements — `touched_pages` path tracking, routing-matrix fail-open, `commit-candidates.sh` + no-push Step-6 consent gate. Prior 0.10.1 (2026-06-07): parallelized link-audit.sh, eliminated convergence-tracker redundant re-read, retired final "collection" vocabulary. Prior 0.10.0 (2026-06-07): wiki layer from decommissioned hosted-wiki MCP → local llm-wiki; propagator Haiku→Sonnet; Bug 7 bats false-green fixed. |
| release-pipeline | 2.2.2 | Released 2026-05-25; bump-version.sh plugin-mode now handles package.json + pyproject.toml version updates (new sections 6c/6d with defensive name-match guards). Plugin-test-harness v0.7.6 release exposed the bug: `package.json` was stuck at 0.7.2 even though v0.7.3–v0.7.5 had shipped. Test suite: 11/11 → 15/15. Prior 2.2.0 (2026-05-07): testing-branch retirement. GitHub release tag: `release-pipeline/v2.2.2` |
| test-driver | 0.6.2 | **Marketplace-live at 0.6.2** (marketplace `source` serves `./plugins` from `main`) but **NOT yet GitHub-released** — latest tag is `test-driver/v0.6.1`. Untagged delta: 0.6.2 (commit `e3e0b11`) drops references to the deleted opus-context plugin while preserving the full-context reading philosophy verbatim. Released baseline 0.6.1 (2026-05-25): TEST-003 fix, 57/57 tests. **Pending:** `/release-pipeline:release` to tag v0.6.2. |

## Recently Removed (2026-06-08)

github-repo-manager, plugin-test-harness, repo-hygiene — deleted from `plugins/` (unused). Marketplace count went 9 → 6. GitHub release tags (`github-repo-manager/v0.5.1`, `plugin-test-harness/v0.7.7`, `repo-hygiene/v1.4.1`) retained for historical install.

## Recently Removed (2026-05-30)

opus-context, handoff, nominal — deleted from `plugins/` (unused). Marketplace count went 12 → 9. Removal spanned both planes: repo (`plugins/`, `marketplace.json`, `README.md`, `docs/`, `testing/`) and live Claude Code state (`settings.json` `enabledPlugins`, `installed_plugins.json`, plugin cache, catalog clone). GitHub release tags (`opus-context/v1.1.1`, `handoff/v0.2.1`, `nominal/v1.1.1`) retained for historical install.

## Recently Removed (2026-05-08)

claude-sync, design-assistant, docs-manager, linux-sysadmin, python-dev — deleted from `plugins/` in commit 3b8323e (`Cleaning up old plugins.`). Marketplace count went 17 → 12. All doc layers reconciled in the same session.

## What Remains

- **One marketplace-live manifest bump awaits a GitHub release tag:** test-driver v0.6.2 (bumped on `main`, never tagged). Run `/release-pipeline:release` to reconcile. Installers already receive this version; only the GitHub release/tag artifact lags.
- Monitor Tavily `search_depth=fast` vendor bug (returns empty results for queries `basic` answers correctly). Inline-noted in routing rules; revisit if Tavily fixes upstream.
- Centralize bats wrapper to `scripts/run-plugin-bats.sh` (now 3 copies of `tests/run-bats.sh` after de-listing github-repo-manager, plugin-test-harness, repo-hygiene — was 6). TEST-002 in conventions covers the workaround pattern; centralization is optional cleanup.
