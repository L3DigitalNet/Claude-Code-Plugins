# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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

