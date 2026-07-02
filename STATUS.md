# Project Status

This is the human-facing completion summary for the project. Agents maintain it so the project builder can re-orient quickly.

## Completed

- All 7 marketplace plugins released and current (2026-07-02): spec-pipeline v0.2.0 (first release), home-assistant-dev v2.2.11, qt-suite v0.3.4, qdev v2.0.3, release-pipeline v2.2.3, up-docs v0.13.1, uv-strict-python v0.2.1. Two batch-release passes — 3 plugins quarantined on real pre-flight test failures in the first pass, root-caused and fixed, then released clean in the second pass.
- home-assistant-dev: all 284 full-spectrum review findings implemented (2026-06-14), now shipped in v2.2.11.

## Current State

- Marketplace `l3digitalnet-plugins` lists 8 plugins: home-assistant-dev, release-pipeline, qt-suite, test-driver, up-docs, qdev, uv-strict-python, spec-pipeline. All 7 actively-released plugins are at their latest tag; no unreleased changes remain (`detect-unreleased.sh` confirms).
- Repo docs run Prettier + markdownlint (CI-enforced); `docs/codex-reviews/` (generated Codex audit evidence) is exempt from both.

## Recent Changes

- [2026-07-02] Batch-released 4 plugins clean (spec-pipeline v0.2.0, home-assistant-dev v2.2.11, qt-suite v0.3.4, qdev v2.0.3); quarantined release-pipeline, up-docs, uv-strict-python on real pre-flight test failures.
- [2026-07-02] Root-caused and fixed all 3 quarantined failures: release-pipeline's `auto-build-plugins.sh` and up-docs's `server-inspect.sh` both had ENV-001's global PATH guard shadowing a test's npm/ssh stub (Bug 9, `ba975a4`/`c0919f9`); uv-strict-python's standards were stale against `project-standards` and re-synced to `6cf2228` (`364f723`). Swept the other 11 ENV-001-guarded scripts — none exposed to the same failure mode, no change needed.
- [2026-07-02] Re-ran batch release for the 3 fixed plugins — all green: release-pipeline v2.2.3, up-docs v0.13.1, uv-strict-python v0.2.1.
- [2026-07-02] spec-pipeline fable-reviewed (15 findings) and all fixed in `ec74a16`: GREEN evidence now needs a positive pass signature, phase-plan parsing is fence-aware, phrase scans are word-boundary, review-tooling HALT preconditions added to both skills; 122/122 tests.

## Notes For The Builder

- Next session: spec-pipeline still needs a live smoke test in a fresh session (install + cache sync first) and a decision on deprecating the two source skills in `agent-configs`. `.release-waivers.json` has one stale, non-blocking waiver entry worth cleaning up. Full backlog in TODO.md.
