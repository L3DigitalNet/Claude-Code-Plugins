# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
