# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [2.0.0] - 2026-06-07

### Removed (BREAKING)

- Removed `/qdev:quality-review`, `/qdev:deps-audit`, `/qdev:doc-sync`, and `/qdev:spec-update` commands and their agents (`qdev-quality-reviewer`, `qdev-deps-auditor`, `qdev-doc-syncer`). qdev is now research-only: `/qdev:research` is the single remaining command.
- Removed the `qdev-grounding` (`research-grounding`) auto-trigger skill and its egress sanitizer `scripts/sanitize_query.py` (+ `tests/test_sanitize_query.py`). Routine, agent-initiated web search is decoupled to the standalone Claude Code `web-search` skill (in the agent-configs repo); it does not persist reports or tier search depth.

### Changed

- `/qdev:research` and `qdev-researcher` no longer reference the removed `/qdev:quality-review` in their downstream-chaining text (output text only; research behavior unchanged).
- Manifest + marketplace description rewritten to research-only; structural test (`test_plugin_structure.py`) updated for the skill-less, single-dispatcher surface.

### Fixed

- Corrected the Tavily MCP server key in `qdev-researcher` (`mcp__tavily-mcp__*` → `mcp__tavily__*`) to match this host's configured server name; the wrong key silently dropped the Tavily grant and forced a `WebFetch` fallback on every deep-read. (Lands via precursor commit `56494ad`.)

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
