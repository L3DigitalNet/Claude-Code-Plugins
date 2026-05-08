---
bug_id: 5
date: 2026-05-07
title: "workstation pre-commit hook rejects test commits in tmpdir git repos using fake author email"
services: [claude-code-plugins, plugin-test-harness]
tags: [test-infra, git-hooks]
status: fixed
supersedes: null
superseded_by: null
---
# Bug 5: workstation pre-commit hook rejects test commits in tmpdir git repos using fake author email

## Summary

`plugin-test-harness/test/unit/fix/{applicator,tracker}.test.ts` create temporary git repos in `os.tmpdir()` and run real `git commit` operations using a fake author email (`test@pth.test`). The workstation's global pre-commit hook (configured globally to enforce noreply email pattern `^168346341\+chrisdpurcell@users\.noreply\.github\.com$`) rejected those test commits before the test logic could run, causing 4 of 68 tests to fail at `beforeEach` setup.

The failures were environmental — workstation-specific, contributor-specific, and unrelated to plugin code logic. Identified during the plugin-test-harness v0.7.5 release pre-flight gate (Phase 1 Test Runner reported FAIL).

## Fix

Add `git config core.hooksPath /dev/null` to the tmpdir repo's local config in `beforeEach`, immediately after `git init`. The local `core.hooksPath` overrides any global hooks setting for that specific repo, so test commits don't fire workstation hooks. One-line addition per affected test file.

Contributor-agnostic — works on any developer's machine regardless of global git config. See convention TEST-003 for the durable pattern.

Released in plugin-test-harness v0.7.5 (commit cf9aa1b). Test result delta: 16/18 suites + 64/68 tests → 18/18 suites + 68/68 tests.
