# Handoff

**Last updated:** 2026-05-30 (plugin marketplace cleanup + repo-hygiene v3 hardening)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

None.

## Recently closed (this session, 2026-05-30)

- **Plugin marketplace cleanup + repo-hygiene v3 hardening** — Removed 3 unused plugins (opus-context, handoff, nominal: 12 → 9) from both repo and live Claude Code state (marketplace.json, README, docs/, testing/, plus settings.json/installed_plugins.json/cache). repo-hygiene 1.4.2: semantic auditor gains handoff-v3 awareness (canonical files exempt, stray handoff.md is info not warn, validation deferred). test-driver 0.6.2: drop opus-context refs (philosophy intact). Swept 8 stale .release-waivers.json entries (22 → 14) + 5 orphan installed_plugins.json keys + 5 cache dirs from 2026-05-08 removal. No new bugs; all repo/live-plane layers (manifest/README/docs/testing/.waivers.json/installed_plugins.json/cache) synchronized.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
