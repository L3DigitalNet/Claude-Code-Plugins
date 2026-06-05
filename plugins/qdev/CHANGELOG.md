# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.6.0] - 2026-06-05

### Added
- add inline grounding skill (sanitize gate + light/medium escalation)
- add deterministic egress sanitizer for the grounding skill
- per-path routing, Context7 gate, reporting cycle + guardrails in qdev-researcher
- deterministic dedup decision helper with per-branch tests
- add scoped research-frontmatter validator
- add regenerable research-index generator
- add shared frontmatter parser for research-KB scripts

### Changed
- record D2 grounding skill + sanitizer in repo docs
- reword P2 for the auto-trigger skill; describe grounding skill in manifest/marketplace
- grounding-skill reference (category catalog, egress verdicts, trigger matrix)
- cover sanitizer stdin transport + no-leak (SA-NEW-002)
- document reporting cycle; bring qdev into test scope; scrub dead testing/ refs
- scaffold research-KB tests dir + vendor frontmatter schema

### Fixed
- resolve code-review findings — 5 sanitizer/reader bugs + test hardening
- close 3 egress/index bugs + expand test coverage 75→133
- qualified subagent_type + pass scripts path; relay reporting cycle
- qualify subagent_type in all four command dispatches (PLUGIN-001)
- correct Tavily MCP tool prefix in three agents


## [Unreleased]

### Added

- `qdev-grounding` skill: the plugin's first auto-trigger. Cheap inline lookups (Category C) that escalate to the `qdev-researcher` medium sweep (Category A / after 2 failed rounds). Every outbound payload passes a deterministic egress sanitizer (`scripts/sanitize_query.py`) before leaving the machine; flagged payloads pause for approval, auto-fired medium runs confirm before dispatch.
- `scripts/sanitize_query.py`: stdin-driven egress sanitizer (collapse tracebacks -> redact secret families -> strip private identifiers -> approval/provider decision), fail-closed.
- Research reporting cycle: `qdev-researcher` reports now carry project-standards `research` frontmatter; `docs/research/index.md` is regenerated from frontmatter by `scripts/build_research_index.py`; `scripts/validate_research_frontmatter.py` enforces the schema. Dedup updates/links/supersedes prior reports.

### Changed

- `qdev-researcher` routing: Tavily-first recall → Brave cross-check → Serper operators → Tavily extract, with a Context7 docs-vs-web gate (both `query-docs`/`get-library-docs` variants), enforced provider quirks (`gl/hl`, `topic=general`→Brave, `search_depth=basic`), and a fail-soft fallback chain.

### Fixed

- `sanitize_query.py` hardening from a high-effort code review: (a) env-style secret assignments whose keyword is a suffix of a longer name (`AWS_SECRET_ACCESS_KEY=…`, `MY_API_KEY_PROD=…`) are now redacted+flagged — previously the value egressed with no approval; (b) bearer tokens containing base64 chars (`/ + =`) are redacted whole (`\S+`), not just the run before the first such char; (c) two quadratic ReDoS holes fixed by bounding repetition — `host:internal` (`{1,12}` labels; ~16s→0.02s on a 60k dotted string) and `pii:email` (RFC length caps). The egress over-flag bias and the documented heuristic limits (unkeyed high-entropy secrets, non-suffix internal FQDNs) are intentional and noted in the module docstring.
- `build_research_index.py` / `validate_research_frontmatter.py` now also catch `UnicodeDecodeError` (a `ValueError`, not `OSError`), so a single non-UTF-8 report is skipped/reported per-file instead of crashing index regeneration or validation.
- `sanitize_query.py` no longer leaks the tail of a spaced secret value: the `secret:assignment` / `customer:identifier` value capture was `\S+` (first whitespace-delimited token only), so `password: correct horse battery staple` redacted to `[REDACTED] horse battery staple`. Now captures to end of line (`.+`), so the whole value is redacted — over-redaction is the correct bias for an egress sanitizer. Regression test added.
- `build_research_index.py` now escapes `|` (and collapses newlines) in generated index cells, so a report title/field containing a pipe can no longer inject extra columns into `index.md`. Regression test added.
- `build_research_index.py` `collect_reports` no longer aborts the whole index regeneration when a single report has malformed-YAML frontmatter; the bad file is skipped with a stderr warning (parity with `validate_research_frontmatter.py`'s per-file resilience). Regression test added.
- Corrected the Tavily MCP tool prefix in three agents (`qdev-researcher`, `qdev-quality-reviewer`, `qdev-deps-auditor`): `mcp__tavily__tavily_*` → `mcp__tavily-mcp__tavily_*`. The wrong server key meant the Tavily tools were never granted, so every deep-read/extract silently fell back to `WebFetch` — which returns sparse content on the JS-rendered docs/advisory/issue pages these agents target. The prefix now matches the canonical `tavily-mcp` server key (consistent with the sibling `brave-search` / `serper-search` keys).
- Qualified the `subagent_type` in all four qdev command dispatches (`/qdev:deps-audit`, `/qdev:doc-sync`, `/qdev:quality-review`, `/qdev:research`): bare `qdev-<agent>` → `qdev:qdev-<agent>`. Per repo convention PLUGIN-001, a bare plugin-agent name is not resolvable from outside the plugin namespace; it fails at runtime with "Agent type not found", and the failure silently no-ops rather than erroring — so each command could dispatch nothing. Same fix class as the earlier up-docs correction.

## [1.5.0] - 2026-05-08

### Changed
- qdev: bump to v1.5.0 — qdev-researcher subagent
- qdev(README): fix mermaid label, prune-cmd safety, prose polish
- qdev: README — document qdev-researcher and handoff protocol
- qdev(research): fix callout ordering, summary early-exit, hint shape
- qdev: rewrite /qdev:research as thin orchestrator
- qdev(researcher): drop dead Glob/Grep permissions; fix Step 8 ordering
- qdev: add qdev-researcher subagent (Sonnet)


## [1.5.0] - 2026-05-08

### Changed

- `/qdev:research` is now a thin orchestrator that dispatches the new `qdev-researcher` Sonnet subagent. Estimated ~25K tokens saved per invocation when called from Opus. Matches the v1.3.0 extraction pattern used for `quality-review`, `deps-audit`, and `doc-sync`.
- `/qdev:research` topic prompt collapsed from a two-step `AskUserQuestion` (Describe it now / Cancel → follow-up open question) to a single bounded question with up to 3 inferred candidates plus the implicit Other entry.
- `/qdev:research` now offers downstream chaining (`superpowers:brainstorming`, `/qdev:quality-review`) after presenting the report, passing the persisted research path as context.

### Added

- `plugins/qdev/agents/qdev-researcher.md` — Sonnet agent with Context7 routing for libraries, footgun corroboration (2+ sources or official source required), source authority grading (`[official]` / `[community]` / `[blog]` / `[unverified]`), and a single-iteration follow-up pass for angles with thin coverage or open questions.
- `docs/research/` — persistence directory for `qdev-researcher` reports. Filename shape: `<YYYY-MM-DD>-<slug>.md`. Downstream commands and skills consume the artifact by reading that path.
- README: positioning section comparing `/qdev:research` to the global `research`, `search`, and `extract` skills, plus a Handoff Protocol section documenting consumer commands.
- README: structured output contract for `/qdev:research` reports (Summary table, severity-tagged Footgun corroboration, Existing-solution callout placement).

### Fixed

- Stale `2024` literal in the `/qdev:research` example query. The agent now derives the current year via `date +%Y` at sweep time instead of hardcoding it.
- `find` invocation in `/qdev:research` topic inference no longer scans `node_modules`, `__pycache__`, and `.venv` (matches `/qdev:spec-update`).
- Design spec at `docs/superpowers/specs/2026-04-13-qdev-design.md` updated via `/qdev:spec-update` to reflect commands and agents added since 2026-04-13.


## [1.4.0] - 2026-05-07

### Changed
- qdev v1.4.0 — add Tavily MCP support across all commands and agents


## [1.4.0] - 2026-05-07

### Added

- All `/qdev` commands and agents now support the `tavily` MCP server. New tools available to relevant agents/commands: `mcp__tavily__tavily_search` (content-heavy queries that previously required search→scrape) and `mcp__tavily__tavily_extract` (JS-rendered page extraction; replaces `WebFetch` as the preferred fetch tool for documentation, advisory, and issue pages). `brave-search` + `serper-search` remain the primary parallel search pair.

### Changed

- `/qdev:research`: 3-5 deep-dive pages identified after dual-source search are now read via `mcp__tavily__tavily_extract` instead of `WebFetch`. Includes a `search_depth=basic` note to avoid the broken `fast` mode currently in Tavily's MCP.
- `qdev-quality-reviewer` agent: docs/issue/advisory pages requiring JS rendering or full extraction now route through `tavily_extract`.
- `qdev-deps-auditor` agent: CVE advisory pages (GHSA, NVD detail pages) are now read via `tavily_extract` with `WebFetch` as fallback.
- `README.md`: prerequisites now list `tavily` MCP as recommended; mermaid diagrams updated to show the third research surface.

### Notes

- Existing `brave-search` and `serper-search` tool calls are unchanged in shape and parallelism. Tavily is additive, not a replacement for the dual-source primary pair.
- This release follows the marketplace-wide swap from `garylab/serper-mcp-server` (Python, all-Google-verticals) to `marcopesani/serper-search-scrape-mcp-server` (Node, search + scrape only). All `mcp__serper-search__google_search` references continue to resolve correctly.

## [1.3.0] - 2026-04-23

### Changed

- `/qdev:deps-audit`, `/qdev:quality-review`, and `/qdev:doc-sync` are now thin orchestrators that dispatch dedicated subagents rather than performing the research, analysis, and edit work inline. Estimated ~50K tokens saved per typical weekly usage cycle when invoked from Opus sessions.

### Added

- `plugins/qdev/agents/qdev-deps-auditor.md` — Haiku agent for manifest parsing plus per-dependency CVE and version research.
- `plugins/qdev/agents/qdev-quality-reviewer.md` — Sonnet agent for research-first iterative quality review with oscillation detection. Handles the pass loop; the command drives AskUserQuestion for needs-approval findings.
- `plugins/qdev/agents/qdev-doc-syncer.md` — Haiku agent for docstring/JSDoc sync against current signatures. Dry-run and apply modes.

## [1.2.1] - 2026-04-13

### Changed
- `/qdev:quality-review` finding classification now uses a principled decision test instead of type-based lists: a fix is auto-applied when exactly one correct answer exists, no design decision is required, no dependency action is involved, and no non-trivial logic is removed. GAP findings with derivable answers, naming violations, weak requirement words, and dead imports now auto-fix without prompting.

## [1.2.0] - 2026-04-13

### Added
- `/qdev:deps-audit` command: dependency security and freshness audit across all package manifests; researches CVEs and version lag using both search tools; optionally generates upgrade commands for critical and high findings
- `/qdev:doc-sync` command: sync inline code documentation (docstrings, JSDoc, Go doc comments, etc.) with current function signatures; proposes additions for undocumented functions and updates for stale docs before writing anything

## [1.1.0] - 2026-04-13

### Added
- `/qdev:research` command: dual-source internet research sweep covering official docs, community best practices, footguns, and existing tools before designing or building

## [1.0.0] - 2026-04-13

### Added
- `/qdev:quality-review` command: research-first iterative quality review for spec, plan, and code artifacts
- `/qdev:spec-update` command: one-shot sync of a spec file to match current implementation
