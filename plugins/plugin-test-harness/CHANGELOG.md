# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.7.5] - 2026-05-07

### Changed
- plugin-test-harness: bypass workstation pre-commit hook in fix/ tests
- plugin-test-harness: Phase 2 — convergence + gap-analyzer + registry-shape (18 cases)


## [0.7.4] - 2026-04-20

### Changed
- npm audit fix - resolve hono, path-to-regexp CVEs

### Fixed
- unblock 3 plugin releases


## [0.7.3] - 2026-04-07

### Changed
- Bump handlebars in /plugins/plugin-test-harness
- Bump hono in /plugins/plugin-test-harness
- Bump picomatch in /plugins/plugin-test-harness
- Bump the all-dependencies group across 1 directory with 7 updates
- Bump flatted in /plugins/plugin-test-harness
- bump express-rate-limit in /plugins/plugin-test-harness
- bump @hono/node-server in /plugins/plugin-test-harness

### Fixed
- bump ts-jest to 29.4.9 in both plugin lock files


## [0.7.2] - 2026-03-04

### Changed
- update remaining L3Digital-Net references
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply audit findings — isError, CHANGELOG, README, UX


## [Unreleased]

## [0.7.1] - 2026-03-02

### Changed
- README: fix structural issues and update docs path references
- Cleaned up writing style and documentation consistency

## [0.7.0] - 2026-02-22

### Added
- `pth_delete_test` tool (v0.6.5): remove a test by ID and clear its result history

### Fixed
- Updated tool count expectation to 20 (`pth_delete_test` brings the total from 19)
- MCP array/number coercion and pinned test protection (v0.6.4)
- Three dogfooding bugs — bump to v0.6.3
- Four bugs from PTH dogfooding — bump to v0.6.2

## [0.6.5] - 2026-02-22

### Added
- **`pth_delete_test`**: Remove a test from the suite by ID. Also clears its result history from the in-session `ResultsTracker` to prevent orphaned entries from skewing pass/fail counts.

## [0.6.4] - 2026-02-22

### Fixed
- **MCP non-string parameter serialization**: Claude Code's MCP client sends array and number parameters as JSON strings. Added `z.preprocess(parseJsonString, ...)` to `files` in `pth_get_test_impact` and `pth_apply_fix`, and `z.coerce.number()` for `durationMs` in `pth_record_result` — all now accept both native types and their string-encoded equivalents
- **`pth_generate_tests` overwrites manual test edits**: added `pinned?: boolean` to `PthTest`. `pth_edit_test` now sets `pinned: true` automatically; `pth_generate_tests` skips pinned tests and reports them as "(N pinned)" in the summary

## [0.6.3] - 2026-02-22

### Fixed
- **Plugin scanner false positive**: strip single-line comments before regex scan — the `TOOL_NAME_PATTERN` comment in `plugin-scanner.ts` itself was matched, injecting `tool_name` as a fake new component in the gap analysis
- **`pth_start_session_valid_input` wrong expectation**: renamed to "rejects when session already active", flipped to `success: false` — this is the correct behavior and a valid error-path test
- **`pth_resume_session_valid_input` wrong expectation**: renamed to "rejects invalid branch format", flipped to `success: false` — `branch: main` correctly fails the PTH session branch format guard

## [0.6.2] - 2026-02-22

### Fixed
- **`pth_edit_test` accepts blank testId**: added `.min(1)` to Zod schema and a whitespace guard in dispatch — empty or whitespace-only testId now returns `isError: true`
- **`pth_reload_plugin` orphans MCP context when testing itself**: process kill is now deferred 500ms via `setTimeout` so the success response can be sent over stdio before SIGTERM arrives
- **Schema-generated stubs cause ID collisions across sessions**: `pth_create_test` input YAML now uses `pth_list_tests` (a real tool) and a timestamp suffix; scenario stubs get unique IDs on each `pth_generate_tests` call

### Removed
- Three artifact stub tests (`test-value`, `generated_test`, `scenario_stub_for_pth_record_result`) removed from persistent store — generator left-overs using `tool: example` (non-existent)

## [0.6.1] - 2026-02-22

### Fixed
- **`${CLAUDE_PLUGIN_ROOT}` ENOENT on schema discovery**: `fetchToolSchemasFromMcpServer` now expands `${CLAUDE_PLUGIN_ROOT}` in `.mcp.json` args before calling `spawn()`. Claude Code substitutes this variable at load time, but `spawn()` does not invoke a shell so the literal token caused ENOENT on the child process.
- **"Connection closed" when PTH runs as Claude Code MCP server**: child processes spawned for schema discovery were inheriting the parent's fd 2 (a live Unix socket to Claude Code). Added `stderr: 'pipe'` to `StdioClientTransport` and drain the pipe to prevent backpressure stalls.
- **Missing-required-field tests returned success instead of `isError: true`**: tool dispatch now validates args against each tool's Zod schema before routing. Invalid args return `{ isError: true }` so MCP clients can distinguish validation errors from successful tool execution without string-parsing the response text.
- **`pth_record_result_valid_input` scenario**: fixed expectation and isError handling for unknown testId

## [0.6.0] - 2026-02-22

### Added
- **Persistent storage at `~/.pth/PLUGIN_NAME/`**: tests, results history, session reports, iteration history, fix history, and plugin snapshots now survive across sessions
- **Gap analysis** at `pth_start_session`: compares saved plugin snapshot vs current source files to surface new/modified/removed components without requiring a live server
- `pth_generate_tests` now accepts optional `tools[]` parameter for gap-targeted test generation (only generate tests for specific new/modified tools from gap analysis)
- `pth_preflight` reports whether a persistent store exists for the plugin
- Rich end-session summary with convergence table, fixes applied, and test outcomes

### Changed
- `resumeSession` now loads tests from the persistent store (`~/.pth/PLUGIN_NAME/tests/`) instead of the worktree — persistent store is the authoritative test source
- `endSession` persists all session artifacts to `~/.pth/PLUGIN_NAME/` before worktree removal, and cleans the worktree's `.pth/` directory to prevent stale data loading
- `pth_end_session` response now includes the persistent store path and session report location

## [0.5.1] - 2026-02-22

### Fixed
- **`pth_preflight` stale active-session verdict**: verdict now correctly reflects an active session — returns `⚠ Session already active` instead of `✓ OK — ready to start a session` when a live session lock is detected. Discovered via PTH self-test run.

## [0.5.0] - 2026-02-22

### Added
- `pth_generate_tests` now auto-discovers tool schemas by spawning the target MCP server and calling `tools/list` — no longer requires Claude to manually pass `toolSchemas`. Fixes incomplete test generation when the plugin has more tools than Claude's active tool registry (e.g. 106 tools on linux-sysadmin-mcp vs. 27 previously generated).
- New `fetchToolSchemasFromMcpServer` function in `shared/source-analyzer.ts` using `StdioClientTransport` + `Client` from the MCP SDK

## [0.4.1] - 2026-02-21

### Fixed
- `pth_apply_fix`: detect when `git add` silently stages nothing (gitignored paths) and throw a clear `GIT_ERROR` with the attempted paths instead of a misleading `BUILD_FAILED` from the subsequent commit (BUG-5)
- `pth_apply_fix`: `BUILD_FAILED` from `runOrThrow` on git operations now correctly converted to `GIT_ERROR` in `commitFiles` catch block (BUG-5)
- `pth_reload_plugin`: run `npm install` before build when `node_modules` is absent in worktree — worktrees are clean checkouts with no inherited dependencies (BUG-6)

## [0.4.0] - 2026-02-21

### Fixed
- `pth_start_session` now rejects if an active session lock is held by a live process (BUG-1)
- `pth_resume_session` now validates branch has `pth/` prefix before proceeding (BUG-2, BUG-3)
- `pth_generate_tests` now upserts existing tests instead of throwing on duplicate IDs (BUG-4)

## [0.3.0] - 2026-02-20

### Added
- Updated Plugin Test Harness documentation and implementation notes

## [0.2.0] - 2026-02-20

### Added
- Enhanced plugin management and git integration

### Fixed
- Updated path variable names for consistency and clarity
- Used `${CLAUDE_PLUGIN_ROOT}` in `.mcp.json` args
- Committed `dist/` so MCP server works after install

## [0.1.3] - 2026-02-20

### Fixed
- `revertCommit` now handles `session-state.json` conflicts — stashes dirty state before reverting, resolves `session-state.json` with `--ours`, uses `--allow-empty` for already-neutralised commits that are net no-ops after conflict resolution
- `applyFix` now uses `commitFiles` (stage only written files) instead of `commitAll` (`git add -A`), preventing `session-state.json` from contaminating fix commits and causing conflicts during later reverts
- `pth_reload_plugin` now syncs new build to versioned cache via `onBuildSuccess` callback before killing the process — previously the restarted process loaded the stale binary from cache
- `detectBuildSystem` is now called on the plugin subdirectory path within the worktree, not the worktree root — previously no `package.json` was found and the build step was silently skipped
- Parser now honours explicit `id` field in YAML test definitions; falls back to `slugify(name)` only when `id` is absent or not a slug-safe string

### Added
- `commitFiles()` in `git.ts` for staging a specific list of files (replaces `commitAll` in fix commits)
- `getInstallPath()` in `cache-sync.ts` — reads `installed_plugins.json` to resolve the versioned cache path for a plugin
- `getAllTools()` in `tool-registry.ts` — returns all registered tools statically; session-gating is enforced at dispatch time

## [0.1.2] - 2026-02-20

### Fixed
- Expose all tools statically at startup — Claude Code caches the MCP tool list at session start, so dynamic activation via `notifications/tools/list_changed` was unreliable; session-gating is now enforced at dispatch time instead
- `createBranch` now uses `git branch` instead of `git checkout -b` to avoid switching HEAD before `git worktree add`, which caused the worktree creation to fail and left the repo on the pth branch

## [0.1.1] - 2026-02-19

### Changed
- Improved tool output formatting and error handling

## [0.1.0] - 2026-02-18

### Added
- CI workflow and marketplace entry
- Plugin manifest, MCP config, and README
- All 16 session tools wired to their implementations
- Session manager: start, resume, end, preflight
- MCP server foundation with dynamic tool registry
- Test generator from tool schemas and plugin source
- Cache sync, plugin builder, and SIGTERM-based reloader
- Fix applicator with git commit trailers and fix history tracker
- Results tracker and convergence detection
- Test YAML types, parser, and test store
- Session state persister and report generator
- Plugin detector: mode detection, build system, `.mcp.json` parsing
- Git integration: branch, worktree, commit with trailers
- Shared error types, logger, and exec utilities
- Design doc and implementation plan
- Sample fixtures: `sample-mcp-plugin`, `broken-mcp-plugin`, `sample-hook-plugin`

### Changed
- Version 0.1.0 — initial public release

### Fixed
- Correct README API signatures and YAML schema
- Python3 fallback in `write-guard.sh`
- Fixed diff base and skipped test count in session tool handlers
- Rolled back branch and worktree on `startSession` failure
- Fixed session manager edge cases: empty commit, lock cleanup, preflight errors
- Scoped session state to `createServer` factory and added notification error handling
- Converted Zod schemas to JSON Schema for MCP wire format
- Extracted `slugify` to shared util and improved generator test coverage
- Fixed cache sync error type, rsync fallback, and process termination
- Fixed fix history parser and added tracker test coverage
- Fixed oscillating detection window and added missing tracker test coverage
- Fixed parser error handling and test store duplicate guard
- Removed TOCTOU in `readMcpConfig` — use `readFile`+ENOENT check instead of `access`+`readFile`
- Added `INVALID_PLUGIN` error code, fixed `readMcpConfig` parse error handling, added shell/tsconfig language detection
- Implemented `getLog` `since` option (was declared but silently ignored)
- Fixed `commitAll` regex for hyphenated branches, added GIT_ERROR wrapping, logged `removeWorktree` failures
- Narrowed `ExecResult.exitCode` to `number` (always mapped by fallback)
- Fixed `exec.ts` signal handling, spawn error surfacing, and env merge
- Resolved ESM/CJS config inconsistency and added missing `typescript-eslint` dep
