# What Is Deployed

| Plugin | Version | Status |
|--------|---------|--------|
| opus-context | 1.1.0 | Released 2026-04-23; SessionStart hook rewritten to read skill body, strip YAML frontmatter, and mechanically inject JSON `hookSpecificOutput` into context window (guarantees rules present on every turn vs. optional via skill tool). SKILL.md tightened 1000 → 350 tokens; terminal banner moved to stderr. GitHub release tag: `opus-context/v1.1.0` |
| home-assistant-dev | 2.2.7 | Released 2026-04-23; ha-integration-reviewer agent downgraded haiku (structural review is mechanical pattern-matching). GitHub release tag: `home-assistant-dev/v2.2.7` |
| qt-suite | 0.3.1 | Released 2026-04-23; gui-tester and test-generator agents explicitly set model: sonnet (was inherit, resolved to opus on opus sessions; ~5x cost reduction per invocation). GitHub release tag: `qt-suite/v0.3.1` |
| qdev | 1.3.0 | Released 2026-04-23; three new agents (qdev-deps-auditor haiku, qdev-quality-reviewer sonnet, qdev-doc-syncer haiku) with grunt work split out; commands rewritten as thin orchestrators (~50K tokens weekly savings). Prior 1.2.1: first release. GitHub release tag: `qdev/v1.3.0` |
| repo-hygiene | 1.4.0 | Released 2026-04-23; semantic audit (Step 2) split to hygiene-semantic-auditor haiku subagent; Step 1 (seven mechanical scripts) unchanged (~15K tokens per run reduction). GitHub release tag: `repo-hygiene/v1.4.0` |
| python-dev | 1.1.0 | Released 2026-04-23; code-review command rewritten as thin dispatcher; 11 domain rules moved to python-code-reviewer sonnet agent (~20K tokens per review reduction). GitHub release tag: `python-dev/v1.1.0` |
| up-docs | 0.6.0 | Released; propagate-repo agent now performs handoff.md pruning (retain most recent 5 Last Updated entries; Bugs Found And Fixed never pruned) and permission-gated stale-file scan (plans/specs/dated `.md` with completion markers + shipped work + >60 days → surfaced as candidates; skill asks via AskUserQuestion; deletion only on explicit consent via `git rm`). Includes drift-auditor stats-key enum pinning. Prior 0.5.1: verification_discipline; evidence-field guard. Prior 0.5.0: mandatory handoff+conventions audit; audience split; Handoff-for-Next-Session brief. GitHub release tag: `up-docs/v0.6.0` |
| release-pipeline | 2.1.2 | Released; README section rename for template compliance. GitHub release tag: `release-pipeline/v2.1.2` |
| linux-sysadmin | 2.1.2 | Released; README `## Hooks` section added documenting the SessionStart context-injection hook. GitHub release tag: `linux-sysadmin/v2.1.2` |
| plugin-test-harness | 0.7.4 | Released; TypeScript config fixes (tsconfig types, jest transform). 50 tests now pass. GitHub release tag: `plugin-test-harness/v0.7.4` |

## What Remains

- Monitor plugin-test-harness CI stability after TypeScript config fixes (jest transform improvements may affect other test suites).
- Merge 15 `tests/<plugin>` branches into `testing` after final verification (Phase 2 test implementations, per-branch Phase 2 execution logs in `testing/plans/<plugin>.md`). Recommend merge order: release-pipeline first, then others in any order (cherry-picks deduplicate on first merge).
- Document bats-wrapper workaround in conventions or centralize to `scripts/run-plugin-bats.sh` for future bats consumers (currently 13 copies of `tests/run-bats.sh` due to bats v1.13.0 env stripping bug on Fedora).
