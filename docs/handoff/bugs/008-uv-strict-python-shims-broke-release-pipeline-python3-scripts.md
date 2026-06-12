---
bug_id: 8
date: 2026-06-12
title: 'uv-strict-python PATH shims blocked bare python3 — release-pipeline detect-unreleased.sh misreported "not a monorepo"'
services: [release-pipeline, uv-strict-python]
tags: [environment, path-shims, hooks, false-negative, cross-plugin]
status: fixed
supersedes: null
superseded_by: null
---

# Bug 8: uv-strict-python shims blocked bare python3 in release-pipeline scripts

## Cause

uv-strict-python v0.1.0's `SessionStart` hook prepended its PATH shims in **every** session (`matcher: ""`, no project-type gate) — including this Node.js repo. The `python3` shim intercepts any bare invocation and exits 1 with a "use uv run" error.

release-pipeline scripts parse JSON via bare `python3 -c` inside `$(...)` captures. During the uv-strict-python v0.2.0 release, `detect-unreleased.sh`'s capture swallowed the shim's stderr and the script reported **"not a monorepo (fewer than 2 plugins)"** — a false negative that would have routed the release down the wrong mode. Six sibling scripts (`bump-version`, `check-waivers`, `detect-test-runner`, `force-push-guard`, `auto-build-plugins`, `sync-local-plugins`) shared the same exposure. Same failure class as Bug 7 (find/grep shims neutering bats), different shim source: plugin-installed PATH shims instead of interactive-shell search accelerators.

## Fix

Two-sided, both 2026-06-12:

- **Victim hardened** (`4f9fd1c`): all seven python3-invoking release-pipeline scripts now `export PATH="/usr/bin:/bin:$PATH"` immediately after the shebang/`set` line, so the system interpreter always wins. Verified by re-running `detect-unreleased.sh` bare in the still-shimmed session. Unreleased — ships with the next release-pipeline release.
- **Also applied to up-docs** (`19595e2`): six up-docs scripts (`commit-candidates`, `convergence-tracker`, `context-gather`, `capture-transcript`, `link-audit`, `server-inspect`) received the same guard after `commit-candidates.sh`'s snapshot call failed during a live `/up-docs:all` pre-flight. Unreleased — ships with the next up-docs release.
- **Source scoped** (`9d5761b`, released in uv-strict-python v0.2.0): the SessionStart hook now installs shims only when the project root has `pyproject.toml`/`.python-version`/`uv.lock` (override via `.claude/uv-strict-python.local.md` `shims:` frontmatter), so non-Python repos never see them. Cache picks this up at next session start.

## Lesson

A PATH-mutating plugin hook makes every other plugin's subprocess calls part of its blast radius — and `$(...)` captures hide the shim's error message, so the symptom surfaces as a wrong *answer*, not a visible failure. Two standing rules: (1) any plugin script that shells out to `python3`/`pip`/coreutils must self-harden with the `/usr/bin:/bin` PATH prefix (convention ENV-001); (2) hooks that mutate the session environment must be scoped to the project types they serve, with an explicit override, never installed unconditionally.
