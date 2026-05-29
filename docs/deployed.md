# What Is Deployed

| Plugin | Version | Status |
|--------|---------|--------|
| opus-context | 1.1.1 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars; no test-suite delta). Prior 1.1.0 (2026-04-23): SessionStart hook rewritten. GitHub release tag: `opus-context/v1.1.1` |
| home-assistant-dev | 2.2.10 | Released 2026-05-25 (final batch); Dependabot CVE remediation: `qs >=6.15.2` + `fast-uri >=3.1.2` npm overrides (closes GHSA-q3j6, GHSA-v39h, GHSA-q8mj CVEs in @modelcontextprotocol/sdk transitive deps). Rebuilt dist/server.bundle.cjs (847.5kb). Prior 2.2.9 (2026-05-25): TS 6 compatibility fix (`"types": ["node"]` in tsconfig.json). GitHub release tag: `home-assistant-dev/v2.2.10` |
| qt-suite | 0.3.2 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars; no test-suite delta). Prior 0.3.1 (2026-04-23): agent model downgrade. GitHub release tag: `qt-suite/v0.3.2` |
| qdev | 1.5.0 | Released 2026-05-08 (previous session); `/qdev:research` extracted to subagent (Sonnet); design spec updated; positioning clarified vs global research skill. GitHub release tag: `qdev/v1.5.0` |
| repo-hygiene | 1.4.1 | Released 2026-05-25 (batch); TEST-003 fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars). Pre-fix: 29/40 tests passing; post-fix: 40/40. Prior 1.4.0 (2026-04-23): semantic audit subagent split. GitHub release tag: `repo-hygiene/v1.4.1` |
| up-docs | 0.8.4 | v0.8.4 (commit 0d89372): state-conditioned the `docs/state.md` 2 KB cap rule in `propagate-repo` — was transition-conditioned ("if edits push over"), so already-over files never trimmed; caught dogfooding `/up-docs:repo` with state.md at 11 KB. v0.8.3 (commit 15dd8a7): evidence-graded review — deleted orphaned notion-guidelines.md reference (A5), corrected drift-finding.md evidence schema to structured object (B1), extracted post-propagation-steps template for DRY (B2), retagged example #3 host-unreachable from `confidence:low` to `unverifiable`. v0.8.2 (commit 9c2fbdb): removed unsound PreToolUse deny-guard hook (fired on every Bash, latency tax + architecturally unsound subagent scope detection). Test suite: 62 bats (v0.8.1) → 48 bats (v0.8.2, −14 from deny-guard tests) + 26 pytest (both releases). GitHub release tags: `up-docs/v0.8.2`, `up-docs/v0.8.3`. Prior 0.8.1 (2026-05-25): GIT_CONFIG_GLOBAL fix + deny-guard scope-gating. |
| release-pipeline | 2.2.2 | Released 2026-05-25; bump-version.sh plugin-mode now handles package.json + pyproject.toml version updates (new sections 6c/6d with defensive name-match guards). Plugin-test-harness v0.7.6 release exposed the bug: `package.json` was stuck at 0.7.2 even though v0.7.3–v0.7.5 had shipped. Test suite: 11/11 → 15/15. Prior 2.2.0 (2026-05-07): testing-branch retirement. GitHub release tag: `release-pipeline/v2.2.2` |
| plugin-test-harness | 0.7.7 | Released 2026-05-25 (final batch); Dependabot CVE remediation: `qs >=6.15.2` + `fast-uri >=3.1.2` npm overrides (closes GHSA-q3j6, GHSA-v39h, GHSA-q8mj). Rebuilt dist/index.js. Prior 0.7.6 (2026-05-25 batch): TEST-003 fix applied; recovered 22/22 tests. GitHub release tag: `plugin-test-harness/v0.7.7` |
| github-repo-manager | 0.5.1 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars; no test-suite delta). 40/40 tests passing. GitHub release tag: `github-repo-manager/v0.5.1` |
| test-driver | 0.6.1 | Released 2026-05-25 (batch); TEST-003 fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars). Pre-fix: 53/57 tests passing; post-fix: 57/57. GitHub release tag: `test-driver/v0.6.1` |
| nominal | 1.1.1 | Released 2026-05-25 (batch); TEST-003 prophylactic fix applied to `tests/test_helper.bash` + parameterized plugin version reference in `commands/preflight.md` (removed hardcoded "1.1.0"). 79/79 tests passing. GitHub release tag: `nominal/v1.1.1` |
| handoff | 0.2.1 | Released 2026-05-25 (batch); TEST-003 fix applied to `tests/test_helper.bash` (GIT_CONFIG_GLOBAL=/dev/null env vars). Pre-fix: 18/22 tests passing; post-fix: 22/22. GitHub release tag: `handoff/v0.2.1` |

## Recently Removed (2026-05-08)

claude-sync, design-assistant, docs-manager, linux-sysadmin, python-dev — deleted from `plugins/` in commit 3b8323e (`Cleaning up old plugins.`). Marketplace count went 17 → 12. All doc layers reconciled in the same session.

## What Remains

- Monitor Tavily `search_depth=fast` vendor bug (returns empty results for queries `basic` answers correctly). Inline-noted in routing rules; revisit if Tavily fixes upstream.
- Centralize bats wrapper to `scripts/run-plugin-bats.sh` (now 9 copies of `tests/run-bats.sh` after plugin removals — was 13). TEST-002 in conventions covers the workaround pattern; centralization is optional cleanup.
