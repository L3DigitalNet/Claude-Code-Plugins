# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.1] - 2026-05-25

### Changed
- opus-context: Phase 2 — bats suite for SessionStart hook (10 cases)

### Fixed
- canonicalize TEST-003 — bats helper bypass (prophylactic)


## [1.1.0] - 2026-04-23

### Changed

- SessionStart hook now injects `SKILL.md` body into AI context via `hookSpecificOutput.additionalContext` JSON, replacing the prior terminal-only banner. The rules are now guaranteed to be present in every session from turn 1, rather than depending on behavioral skill auto-invocation that was unreliable.
- Tightened `SKILL.md` from ~1000 tokens to ~280 tokens. Removed the Anti-Patterns section (pure negative restatement of the baseline rules) and collapsed repeated justification prose. Every operational rule preserved.
- Terminal confirmation banner moved from stdout to stderr so stdout can carry the JSON payload.

### Fixed

- Skill rules failed to fire in many Opus sessions because description-based auto-invocation depended on the model choosing to call the `Skill` tool. The mechanical SessionStart injection addresses the root cause.

## [1.0.0] - 2026-03-15

### Added

- deep-context skill with five baseline rules for aggressive context utilization
- Deep-context planning mode for complex multi-file tasks
- Five anti-pattern definitions to prevent conservative context behaviors
- Context budget awareness with heuristic-based thresholds
- SessionStart hook with terminal banner
