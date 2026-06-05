---
bug_id: 5
date: 2026-05-07
title: "workstation pre-commit hook rejects test commits in tmpdir git repos using fake author email"
services: [claude-code-plugins, plugin-test-harness, release-pipeline, up-docs, handoff, repo-hygiene, test-driver, github-repo-manager, nominal, opus-context, qt-suite]
tags: [test-infra, git-hooks]
status: fixed
supersedes: null
superseded_by: null
---
# Bug 5: workstation pre-commit hook rejects test commits in tmpdir git repos using fake author email

## Cause

`plugin-test-harness/test/unit/fix/{applicator,tracker}.test.ts` create temporary git repos in `os.tmpdir()` and run real `git commit` operations using a fake author email (`test@pth.test`). The workstation's global pre-commit hook (configured globally to enforce noreply email pattern `^168346341\+chrisdpurcell@users\.noreply\.github\.com$`) rejected those test commits before the test logic could run, causing 4 of 68 tests to fail at `beforeEach` setup.

The failures were environmental — workstation-specific, contributor-specific, and unrelated to plugin code logic. Identified during the plugin-test-harness v0.7.5 release pre-flight gate (Phase 1 Test Runner reported FAIL).

## Fix

Add `git config core.hooksPath /dev/null` to the tmpdir repo's local config in `beforeEach`, immediately after `git init`. The local `core.hooksPath` overrides any global hooks setting for that specific repo, so test commits don't fire workstation hooks. One-line addition per affected test file.

Contributor-agnostic — works on any developer's machine regardless of global git config. See convention TEST-003 for the durable pattern.

Released in plugin-test-harness v0.7.5 (commit cf9aa1b). Test result delta: 16/18 suites + 64/68 tests → 18/18 suites + 68/68 tests.

## Lesson

This is a contributor-environment coupling, not a product bug: a workstation-global pre-commit/GPG hook silently rejects the throwaway commits that tmpdir git tests create. Neutralize git's global + system config at the top of every plugin's test helper — `export GIT_CONFIG_GLOBAL=/dev/null` + `export GIT_CONFIG_NOSYSTEM=1` — rather than waiting for each suite to hit the wall (it recurred three times before canonicalization). The survey `grep -L GIT_CONFIG_GLOBAL plugins/*/tests/{helpers,test_helper}.bash` lists unprotected helpers; note the filename varies (`helpers.bash` vs `test_helper.bash`). See convention TEST-003.

## Recurrence — release-pipeline (2026-05-08)

Same root cause re-surfaced in `release-pipeline/tests/test_helper.bash::make_git_repo` during a post-migration audit: `git commit` for the seed `initial` commit was running under `>/dev/null 2>&1`, the workstation pre-commit hook silently rejected it, HEAD never pointed anywhere, and 13 downstream `git tag` test paths failed with "Failed to resolve 'HEAD' as a valid ref." Fixed by the same one-line `git -C "$dir" config core.hooksPath /dev/null` addition. Bats suite went 63/77 → 76/76 (commit `97365ab`).

The recurrence confirms TEST-003 should be canonicalized into a shared helper or applied preemptively to every plugin's `test_helper.bash` rather than waiting for each plugin to hit the same wall.

## Recurrence — up-docs (2026-05-25)

Surfaced for the third time during `/release-pipeline:release` pre-flight for up-docs v0.8.1. Same root cause in `plugins/up-docs/tests/context-gather.bats` — 4 tests calling `git commit` with `test@test.com` as author. The original `find -name test_helper.bash` survey command missed it because up-docs uses `helpers.bash` (no underscore), not `test_helper.bash`. Fixed in commit `bacf529` with a stronger pattern: `export GIT_CONFIG_GLOBAL=/dev/null` + `export GIT_CONFIG_NOSYSTEM=1` at top of `helpers.bash` rather than the per-tmpdir-repo `git config core.hooksPath` form. The env-var approach also neutralizes `commit.gpgsign` and `tag.gpgsign` which could fire on test repos that try to make signed commits/tags.

## Marketplace-wide canonicalization (2026-05-25)

Immediately after the up-docs recurrence, swept the remaining 7 plugin helpers in one session. Broader survey: `grep -L GIT_CONFIG_GLOBAL plugins/*/tests/{helpers,test_helper}.bash`.

| Plugin | Pre-fix | Post-fix | Status |
|---|---|---|---|
| handoff | 18/22 | 22/22 | actively broken — recovered 4 tests |
| repo-hygiene | 29/40 | 40/40 | actively broken — recovered 11 tests |
| test-driver | 53/57 | 57/57 | actively broken — recovered 4 tests |
| github-repo-manager | 40/40 | 40/40 | prophylactic |
| nominal | 79/79 | 79/79 | prophylactic |
| opus-context | 10/10 | 10/10 | prophylactic |
| qt-suite | 6/6 | 6/6 | prophylactic |

Total: 19 silently-failing tests recovered, 7 helpers now uniformly protected. One commit per plugin: 37c97c3, b6597a9, 8341515, d12fd0c, 57b1f4a, e81232f, d1c7aa2.

Pattern is now fully canonicalized — future regressions are caught by running the audit command above.
