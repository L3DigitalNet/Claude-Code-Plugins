# Project Status

This is the human-facing completion summary for the project. Agents maintain it so the project builder can re-orient quickly.

## Completed

- spec-pipeline plugin implemented and review-hardened (2026-07-02): all 14 plan tasks executed subagent-driven with per-task + final whole-branch review; specpipe validator CLI (stdlib-only, 122 tests), templates, migrated `author`/`execute-phase` skills (v2.1), utility commands, marketplace entry. A follow-up fable-review found 15 findings (4 Medium), all fixed RED-first in `ec74a16`. Unreleased — 0.1.0 tag pending.
- home-assistant-dev: all 284 full-spectrum review findings implemented (2026-06-14, unreleased — ships with the next release).

## Current State

- Marketplace `l3digitalnet-plugins` lists 8 plugins: home-assistant-dev, release-pipeline, qt-suite, test-driver, up-docs, qdev, uv-strict-python, spec-pipeline.
- Repo docs run Prettier + markdownlint (CI-enforced); `docs/codex-reviews/` (generated Codex audit evidence) is exempt from both.

## Recent Changes

- [2026-07-02] spec-pipeline fable-reviewed (15 findings) and all fixed in `ec74a16`: GREEN evidence now needs a positive pass signature, phase-plan parsing is fence-aware, phrase scans are word-boundary, review-tooling HALT preconditions added to both skills; 122/122 tests.
- [2026-07-02] spec-pipeline implemented end-to-end and pushed (18 commits incl. final-review fix `4842a7f`); specs-plans index marked Implemented/Executed.
- [2026-07-01] spec-pipeline spec + 14-task TDD plan written, adversarially reviewed to convergence, and pushed.

## Notes For The Builder

- Next session: smoke-test spec-pipeline live (install + cache sync first), run `/release-pipeline:release` for 0.1.0, and decide whether to deprecate the two source skills in `agent-configs`. 0.1.x hygiene backlog is in TODO.md.
