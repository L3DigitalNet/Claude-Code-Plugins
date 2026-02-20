# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.1] - 2026-02-19

### Changed
- ux(plugin-test-harness): improve tool output formatting and error handling
- add Principles section to all 7 plugin READMEs
- standardise all plugin READMEs with consistent sections


## [0.1.0] - 2026-02-18

### Added
- add CI workflow and marketplace entry
- add plugin manifest, MCP config, and README
- wire all 16 session tools to their implementations
- implement session manager — start, resume, end, preflight
- add MCP server foundation with dynamic tool registry
- add test generator from tool schemas and plugin source
- add cache sync, plugin builder, and SIGTERM-based reloader
- add fix applicator with git commit trailers and fix history tracker
- add results tracker and convergence detection
- add test YAML types, parser, and test store
- add session state persister and report generator
- add plugin detector — mode detection, build system, .mcp.json parsing
- add git integration — branch, worktree, commit with trailers
- add shared error types, logger, and exec utilities

### Changed
- version 0.1.0 — initial public release
- add design doc and implementation plan
- add sample-mcp-plugin, broken-mcp-plugin, and sample-hook-plugin fixtures
- remove dead outDir from tsconfig.test.json
- scaffold TypeScript project with MCP SDK dependencies

### Fixed
- correct README API signatures and YAML schema
- add python3 fallback in write-guard.sh
- fix diff base and skipped test count in session tool handlers
- roll back branch and worktree on startSession failure
- fix session manager edge cases — empty commit, lock cleanup, preflight errors
- scope session state to createServer factory and add notification error handling
- convert Zod schemas to JSON Schema for MCP wire format
- extract slugify to shared util and improve generator test coverage
- fix cache sync error type, rsync fallback, and process termination
- fix fix history parser and add tracker test coverage
- fix oscillating detection window and add missing tracker test coverage
- fix parser error handling and test store duplicate guard
- remove TOCTOU in readMcpConfig — use readFile+ENOENT check instead of access+readFile
- add INVALID_PLUGIN error code, fix readMcpConfig parse error handling, add shell/tsconfig language detection
- implement getLog since option (was declared but silently ignored)
- fix commitAll regex for hyphenated branches, add GIT_ERROR wrapping, log removeWorktree failures
- narrow ExecResult.exitCode to number (always mapped by fallback)
- fix exec.ts signal handling, spawn error surfacing, and env merge
- resolve ESM/CJS config inconsistency and add missing typescript-eslint dep

