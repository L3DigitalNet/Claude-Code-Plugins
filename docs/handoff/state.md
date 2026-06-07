# Handoff

**Last updated:** 2026-06-07 (up-docs 0.10.0 Outline→llm-wiki cutover shipped + released; bats false-green fixed)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev D2 (grounding skill) Task 7 — manual matrix pending.** Feature released v1.6.0 (commit `efe90b8`). Remaining: auto-trigger rules, fake-token approval-before-egress, reject/approve persist gate. (Implementation detail: `f24d690`..`d627a0c` + hardening; 144 pytest green.)
- **qdev web-research D1 — plugin smoke functionally confirmed.** `/qdev:research` started `qdev:qdev-researcher`, deduped, wrote+validated a report, regenerated index (`9550937`).
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-07)

- **Outline→llm-wiki cutover shipped; up-docs 0.10.0 released** (tag `up-docs/v0.10.0` + GitHub release, HEAD `3fadb69`). Wiki layer retargeted Outline MCP → local `~/projects/llm-wiki`: `propagate-wiki` → Sonnet (writes `status:draft` pages under the llm-wiki contract), `audit-drift` reads llm-wiki from disk + runs its validators as drift checks. Spec + plan each Codex-reviewed to convergence (ledgers in `docs/plans/2026-06-07-up-docs-llm-wiki-migration-{design,plan}.md`); executed subagent-driven (`0d73dcb`..`4b84b0a`). Fixed **Bug 7** (bats false-green via find/grep shims → `run-bats.sh` forces GNU coreutils, `d4119ae`). Codex global `AGENTS.md` gained llm-wiki parity (agent-configs `08fd928`).

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
