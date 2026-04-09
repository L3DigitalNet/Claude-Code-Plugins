# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-04-09

### Added
- add script-backed verification (6 scripts, 2031 lines)

### Changed
- pass 3 — close remaining gaps, 293 total tests across 9 plugins
- close gap analysis findings, 247 total tests across 9 plugins
- add 166 bats tests across 9 plugins for new scripts


## [1.1.0] - 2026-04-09

### Added
- `scripts/_common.sh` shared utility library (Python detection, profile loading, SSH wrapping, tool detection, JSON output helpers)
- `scripts/environment-discover.sh` replacing 10-15 individual system commands with a single script that outputs the full environment profile as JSON
- `scripts/go-nogo-poll.sh` replacing 6-10 individual preflight checks with a single parameterized script
- `scripts/domain-checker.sh` replacing 44-66 individual tool calls (4-6 per domain x 11 domains) with one call per domain
- `scripts/flight-log.sh` for managing runs.jsonl (append, read, query) without manual JSON construction
- `scripts/regression-sweep.sh` for lightweight post-fix-forward verification of key signals

### Changed
- `commands/preflight.md` Steps 1 and 5 now reference environment-discover.sh and go-nogo-poll.sh
- `commands/postflight.md` Steps 3, 4, and 6 now reference domain-checker.sh, regression-sweep.sh, and flight-log.sh
- `commands/abort.md` Steps 4 and 6 now reference go-nogo-poll.sh and flight-log.sh

## [1.0.0] - 2026-03-26

### Added
- `/nominal:preflight` command with Mission Survey discovery, go/no-go poll, and rollback readiness
- `/nominal:postflight` command running 11 verification systems with fix-forward and regression sweep
- `/nominal:abort` command with confirmed rollback execution and post-abort verification
- Environment profile discovery and multi-environment support (`environment.json`)
- Persistent rollback configuration (`abort.json`) surviving session interruptions
- Append-only flight log (`runs.jsonl`) based on OpenTelemetry Log Data Model
- 12 verification domains grounded in ITIL, CIS Controls v8, NIST SP 800-190, Google SRE PRR, and HashiCorp/OWASP
- Aerospace-themed terminal UX with consistent visual grammar
- Reference file architecture: 5 knowledge files loaded on demand by commands
