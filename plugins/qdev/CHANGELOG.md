# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
