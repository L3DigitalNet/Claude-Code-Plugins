# What Is Deployed

| Plugin | Version | Status |
| --- | --- | --- |
| home-assistant-dev | 2.2.10 | Released 2026-05-25 (final batch); Dependabot CVE remediation: `qs >=6.15.2` + `fast-uri >=3.1.2` npm overrides (closes GHSA-q3j6, GHSA-v39h, GHSA-q8mj CVEs in @modelcontextprotocol/sdk transitive deps). Rebuilt dist/server.bundle.cjs (847.5kb). Prior 2.2.9 (2026-05-25): TS 6 compatibility fix (`"types": ["node"]` in tsconfig.json). GitHub release tag: `home-assistant-dev/v2.2.10` |
| qt-suite | 0.3.2 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars; no test-suite delta). Prior 0.3.1 (2026-04-23): agent model downgrade. GitHub release tag: `qt-suite/v0.3.2` |
| qdev | 1.6.0 | Released 2026-06-05; D2 grounding skill + sanitizer (commits `f24d690`..`d627a0c`, hardened 75→144 pytest) + 18 prior unreleased commits now shipped. `/qdev:research-grounding` inline skill (Categories A/C auto-trigger, stdin `sanitize_query.py`), README P2 reword, marketplace updated. GitHub release tag: `qdev/v1.6.0`. Prior 1.5.0 (2026-05-08): `/qdev:research` extracted to subagent (Sonnet); design spec updated; positioning clarified vs global research skill. GitHub release tag: `qdev/v1.5.0` |
| repo-hygiene | 1.4.1 | Released 2026-05-25 (batch); TEST-003 fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars). Pre-fix: 29/40 tests passing; post-fix: 40/40. Prior 1.4.0 (2026-04-23): semantic audit subagent split. GitHub release tag: `repo-hygiene/v1.4.1` |
| up-docs | 0.9.0 | Released 2026-05-30; handoff v3 alignment (12 divergences: 2🔴/6🟡/4🟢). Audit → plan (T1–T8) → execution: propagate-repo emits v3 three-line AGENTS.md block + bug-body `## Lesson` (T1/T2); enforces CLAUDE.md ≤2048 / AGENTS.md ≤4096 caps, audits `docs/handoff/specs-plans.md`, route-first `state.md` trim, bug-index verify (T3–T6); drift auditor runs `validate-layout.sh` conformance phase (T7); relabel v2→v3 (T8). 51 bats + 29 pytest. GitHub release tag: `up-docs/v0.9.0`. Prior 0.8.4 (2026-05-29): state-conditioned 2 KB cap. |
| release-pipeline | 2.2.2 | Released 2026-05-25; bump-version.sh plugin-mode now handles package.json + pyproject.toml version updates (new sections 6c/6d with defensive name-match guards). Plugin-test-harness v0.7.6 release exposed the bug: `package.json` was stuck at 0.7.2 even though v0.7.3–v0.7.5 had shipped. Test suite: 11/11 → 15/15. Prior 2.2.0 (2026-05-07): testing-branch retirement. GitHub release tag: `release-pipeline/v2.2.2` |
| plugin-test-harness | 0.7.7 | Released 2026-05-25 (final batch); Dependabot CVE remediation: `qs >=6.15.2` + `fast-uri >=3.1.2` npm overrides (closes GHSA-q3j6, GHSA-v39h, GHSA-q8mj). Rebuilt dist/index.js. Prior 0.7.6 (2026-05-25 batch): TEST-003 fix applied; recovered 22/22 tests. GitHub release tag: `plugin-test-harness/v0.7.7` |
| github-repo-manager | 0.5.1 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars; no test-suite delta). 40/40 tests passing. GitHub release tag: `github-repo-manager/v0.5.1` |
| test-driver | 0.6.1 | Released 2026-05-25 (batch); TEST-003 fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars). Pre-fix: 53/57 tests passing; post-fix: 57/57. GitHub release tag: `test-driver/v0.6.1` |

## Recently Removed (2026-05-30)

opus-context, handoff, nominal — deleted from `plugins/` (unused). Marketplace count went 12 → 9. Removal spanned both planes: repo (`plugins/`, `marketplace.json`, `README.md`, `docs/`, `testing/`) and live Claude Code state (`settings.json` `enabledPlugins`, `installed_plugins.json`, plugin cache, catalog clone). GitHub release tags (`opus-context/v1.1.1`, `handoff/v0.2.1`, `nominal/v1.1.1`) retained for historical install.

## Recently Removed (2026-05-08)

claude-sync, design-assistant, docs-manager, linux-sysadmin, python-dev — deleted from `plugins/` in commit 3b8323e (`Cleaning up old plugins.`). Marketplace count went 17 → 12. All doc layers reconciled in the same session.

## What Remains

- Monitor Tavily `search_depth=fast` vendor bug (returns empty results for queries `basic` answers correctly). Inline-noted in routing rules; revisit if Tavily fixes upstream.
- Centralize bats wrapper to `scripts/run-plugin-bats.sh` (now 6 copies of `tests/run-bats.sh` after plugin removals — was 13). TEST-002 in conventions covers the workaround pattern; centralization is optional cleanup.
