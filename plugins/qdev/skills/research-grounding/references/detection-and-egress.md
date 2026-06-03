# Detection signals and egress verdicts (qdev grounding skill)

Read on demand from `SKILL.md`. Keeps the eagerly invoked skill body small.

## Category A - reactive (already stuck) -> medium directly

- The same tool/command/API call failed or returned empty/wrong twice in a row.
- Two or more different approaches to the same subtask both failed.
- A command failed with an unrecognized error (unfamiliar exit code,
  deprecation warning, 4xx implying a changed API).
- A fix was written, verified, and the same failure reappeared unchanged.
- The agent is about to retry something it already tried this session.

## Category C - context gap (information not in context) -> light path

- The task needs the current/latest version of a dependency or tool.
- The task involves something possibly after the training cutoff.
- The agent must verify a fact it cannot confirm from in-context code/files.
- A recommendation is requested and current ecosystem state matters.

## Category B - proactive (out of scope; never auto-fire)

Pre-emptively searching before any external-library/API/date-sensitive work
over-fires on routine tasks. Serve it via deliberate `/qdev:research`.

## Per-provider egress risk

Ranked lowest to highest risk. The sanitizer's `provider_allowed` is fail-closed
(all false when approval is required; Brave ZDR is assumed absent):

- Brave - lowest (only truly low with enterprise Zero-Data-Retention; treat as
  low-medium here).
- Context7 - medium (formulated docs query; reranks via third-party LLMs; stores
  queries).
- Tavily / Serper - high (may reuse/share query data).

## Dedup / reporting cycle

The medium path reuses D1's reporting cycle unchanged: frontmatter, `## Sources`,
dedup (update / new+related / supersede), and regenerated
`docs/research/index.md`. The light path uses none of it: no report, no index,
no dedup.

## Manual trigger matrix

Run in a plugin-loaded session. Record fire / no-fire for each row. Auto-trigger
matching is undocumented, so this is the empirical check.

| # | Prompt (paraphrase) | Category | Expected |
| --- | --- | --- | --- |
| A1 | "I've run this build twice, same error both times." | A | fire -> medium |
| A2 | "Tried two different fixes, the test still fails." | A | fire -> medium |
| A3 | "4xx that looks like the API changed." | A | fire -> medium |
| A4 | "About to retry the same command again." | A | fire -> medium |
| A5 | "Same failure came back after my verified fix." | A | fire -> medium |
| C1 | "What's the current stable version of <lib>?" | C | fire -> light |
| C2 | "Is <lib> still maintained?" | C | fire -> light |
| C3 | "Did <API> change after my cutoff?" | C | fire -> light |
| C4 | "Verify this flag exists in <tool> today." | C | fire -> light |
| C5 | "Latest CVE for <package>?" | C | fire -> light (web, bypass Context7) |
| B1 | "Add a normal function to this file." | B | no fire |
| B2 | "Refactor this loop." | B | no fire |
| B3 | "Rename this variable." | B | no fire |
| B4 | "Write a docstring for X." | B | no fire |
| B5 | "Format this file." | B | no fire |
