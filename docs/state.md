# Handoff

**Last updated:** 2026-06-03 (qdev D2 implemented + hardened; manual matrix pending)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev D2 (grounding skill) — implemented + hardened; final manual matrix pending.** `f24d690`..`d627a0c` (on `origin/main`): `sanitize_query.py` + `qdev:research-grounding` skill/reference + README/manifest/marketplace/docs. **144 qdev pytest green.** Hardened by a coverage pass (`1c0f0fa`, 75→133) + a high-effort `/code-review` fix pass (`d627a0c`, 133→144): env-style assignment-key leak, bearer base64-tail leak, two quadratic ReDoS (`host:internal`/`pii:email`, now bounded), `UnicodeDecodeError` crash in both readers, markdown-surface structural test tier. Acceptance passed (pytest, marketplace, no-leak). **Remaining Task 7 (human + release-gated):** auto-trigger matrix, fake-token approval-before-egress, reject/approve persist gate — skill not in installed cache, so run `/release-pipeline:release` first. qdev pytest not in CI (audit item 4 declined).
- **qdev web-research D1 — plugin smoke functionally confirmed.** `/qdev:research` started `qdev:qdev-researcher`, deduped, wrote+validated a report, regenerated index (`9550937`).
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-03)

- **qdev D2 coverage + code-review hardening** — `1c0f0fa`, `d627a0c` (75→144 pytest; 7 bugs fixed incl. 2 ReDoS). Detail in `docs/sessions/2026-06.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
