# Changelog

## [0.1.0] - 2026-02-19 — Initial Release

### Added
- Orchestrator command (`/review`) with 6-phase convergence loop
- Three analyst subagents: principles-analyst, ux-analyst, docs-analyst
- Six externalized templates: track criteria (A, B, C), pass report, final report, cross-track impact
- Scoped re-audit skill with file-to-track mapping
- PostToolUse hook for documentation co-mutation tracking
- Session commands: skip, focus, light-pass, revert-pass
- 3-pass budget enforcement with user checkpoint
- [C1] LLM-Optimized Commenting checkpoint — evaluates whether target plugin's in-code comments are tuned for AI readers (architectural role headers, intent-over-mechanics, constraint annotations, decision context, cross-file contracts)
