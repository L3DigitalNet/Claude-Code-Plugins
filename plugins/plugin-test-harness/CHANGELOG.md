# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.7.1] - 2026-03-02

### Changed
- em dash cleanup, root README sync
- fix structural README issues and docs path
- Update GitHub org references from L3DigitalNet to L3DigitalNet
- reduce AI writing signals across all plugin READMEs

### Fixed
- remove em dashes from all READMEs; add hygiene check
- cross-cutting standards sweep across marketplace


## [0.7.0] - 2026-02-22

### Added
- add pth_delete_test tool (v0.6.5)

### Fixed
- update tool count expectation to 20 (pth_delete_test)
- MCP array/number coercion + pinned test protection (v0.6.4)
- three more dogfooding fixes — bump to v0.6.3
- four bugs from PTH dogfooding — bump to v0.6.2


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
- fix pth_record_result_valid_input scenario + isError for unknown testId
- three bugs caught by PTH dogfooding — bump to v0.6.1
- replace \n with <br/> in mermaid node labels across all plugin READMEs


## [0.6.1] - 2026-02-22

### Fixed
- **`${CLAUDE_PLUGIN_ROOT}` ENOENT on schema discovery**: `fetchToolSchemasFromMcpServer` now expands `${CLAUDE_PLUGIN_ROOT}` in `.mcp.json` args before calling `spawn()`. Claude Code substitutes this variable at load time, but `spawn()` does not invoke a shell so the literal token caused ENOENT on the child process.
- **"Connection closed" when PTH runs as Claude Code MCP server**: child processes spawned for schema discovery were inheriting the parent's fd 2 (a live Unix socket to Claude Code). Added `stderr: 'pipe'` to `StdioClientTransport` and drain the pipe to prevent backpressure stalls.
- **Missing-required-field tests returned success instead of `isError: true`**: tool dispatch now validates args against each tool's Zod schema before routing. Invalid args return `{ isError: true }` so MCP clients can distinguish validation errors from successful tool execution without string-parsing the response text.

## [0.6.0] - 2026-02-22

### Added
- rich end-session summary with fixes and test outcomes
- add persistent storage at ~/.pth/PLUGIN_NAME

### Changed
- Enhance Release Pipeline and Repo Hygiene Plugins
- update plugin docs, PTH README for v0.6.0, and repo template
- bump to v0.6.0
- add persistent storage design doc


## [0.6.0] - 2026-02-22

### Added
- **Persistent storage at `~/.pth/PLUGIN_NAME/`**: tests, results history, session reports, iteration history, fix history, and plugin snapshots now survive across sessions
- **Gap analysis** at `pth_start_session`: compares saved plugin snapshot vs current source files to surface new/modified/removed components without requiring a live server
- `pth_generate_tests` now accepts optional `tools[]` parameter for gap-targeted test generation (only generate tests for specific new/modified tools from gap analysis)
- `pth_preflight` reports whether a persistent store exists for the plugin

### Changed
- `resumeSession` now loads tests from the persistent store (`~/.pth/PLUGIN_NAME/tests/`) instead of the worktree — persistent store is the authoritative test source
- `endSession` persists all session artifacts to `~/.pth/PLUGIN_NAME/` before worktree removal, and cleans the worktree's `.pth/` directory to prevent stale data loading
- `pth_end_session` response now includes the persistent store path and session report location

## [0.5.1] - 2026-02-21

### Changed
- Release plugin-test-harness v0.5.1

### Fixed
- preflight verdict reflects active session state


## [0.5.1] - 2026-02-22

### Fixed
- `pth_preflight`: verdict now correctly reflects an active session — returns `⚠ Session already active` instead of `✓ OK — ready to start a session` when a live session lock is detected. Discovered via PTH self-test run.

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
- Update Plugin Test Harness documentation and implementation notes


## [0.2.0] - 2026-02-20

### Added
- enhance plugin management and git integration
- linux-sysadmin-mcp v1.0.5 + plugin-test-harness v0.1.1

### Fixed
- update path variable names for consistency and clarity
- use \${CLAUDE_PLUGIN_ROOT} in .mcp.json args
- commit dist/ so MCP server works after install


## [0.1.3] - 2026-02-20

### Fixed
- fix(plugin-test-harness): `revertCommit` now handles session-state.json conflicts — stashes dirty state before reverting, resolves session-state.json with `--ours`, uses `--allow-empty` for already-neutralised commits that are net no-ops after conflict resolution
- fix(plugin-test-harness): `applyFix` now uses `commitFiles` (stage only written files) instead of `commitAll` (git add -A), preventing session-state.json from contaminating fix commits and causing conflicts during later reverts
- fix(plugin-test-harness): `pth_reload_plugin` now syncs new build to versioned cache via `onBuildSuccess` callback before killing the process — previously the restarted process loaded the stale binary from cache
- fix(plugin-test-harness): `detectBuildSystem` is now called on the plugin subdirectory path within the worktree, not the worktree root — previously no package.json was found and the build step was silently skipped
- fix(plugin-test-harness): parser now honours explicit `id` field in YAML test definitions; falls back to `slugify(name)` only when `id` is absent or not a slug-safe string
- feat(plugin-test-harness): added `commitFiles()` to git.ts for staging a specific list of files (replaces `commitAll` in fix commits)
- feat(plugin-test-harness): added `getInstallPath()` to cache-sync.ts — reads `installed_plugins.json` to resolve the versioned cache path for a plugin (e.g. `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`)
- feat(plugin-test-harness): added `getAllTools()` to tool-registry.ts — returns all registered tools statically; session-gating is enforced at dispatch time

## [0.1.2] - 2026-02-20

### Fixed
- fix(plugin-test-harness): expose all tools statically at startup — Claude Code caches the MCP tool list at session start, so dynamic activation via `notifications/tools/list_changed` was unreliable; session-gating is now enforced at dispatch time instead
- fix(plugin-test-harness): `createBranch` now uses `git branch` instead of `git checkout -b` to avoid switching HEAD before `git worktree add`, which caused the worktree creation to fail and left the repo on the pth branch

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

