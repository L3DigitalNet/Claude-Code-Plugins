# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] - 2026-02-28

### Added

- Persistent REPL mode: `vault.unlock()` opens a single `keepassxc-cli open` process (one YubiKey touch per session); all `run_cli()` calls reuse that process without re-authenticating
- `import_entries` MCP tool: bulk-import multiple entries via XML → staging KDBX → merge; two YubiKey touches regardless of entry count; vault locked after import
- pcscd conflict hint appended to YubiKey timeout errors (`sudo systemctl stop pcscd pcscd.socket`)
- Database path validated at config load: `FileNotFoundError` raised immediately if the configured path does not exist

### Changed

- `run_cli()` now sends commands via REPL stdin and reads output with `asyncio.wait_for(readuntil(...))` instead of spawning a subprocess per call
- `run_cli_binary()` remains a direct subprocess for binary attachment exports (raw bytes cannot transit the text REPL)
- REPL stderr drained in a background `asyncio.Task` to prevent the 64 KB pipe buffer from stalling the session
- `_lock()` kills the REPL process and cancels the stderr drain task
- `fake-tools/keepassxc-cli` refactored: `open` case is now a REPL loop using `eval` to parse `shlex.join`-produced lines; `import` and `merge` subcommands added

### Fixed

- `list_entries` no longer requires N+1 YubiKey touches; all `show` calls within a session share the single unlocked REPL
- Entry titles with spaces now persist correctly: `run_cli()` switched from `shlex.join()` (POSIX single-quote style) to `_repl_join()` (Qt double-quote style); the keepassxc-cli REPL uses Qt's `QProcess::splitCommand` which silently ignored single-quoted arguments
- `create_entry` password field now uses `-p` (`--password-prompt`) and pipes the value via stdin; `keepassxc-cli add` has no `--password <value>` flag so the previous code silently discarded passwords

## [0.2.0] - 2026-02-28

### Changed

- All vault and tool functions are now async (`asyncio.create_subprocess_exec` replaces `subprocess.run`); polling uses `asyncio.to_thread` for YubiKey checks
- stdlib `logging` replaced with `structlog` across all modules; structured key-value log events
- Config validation: types and ranges checked on load (`allowed_groups` must be list of strings, timeouts must be positive integers, `log_level` must be a valid Python log level)
- Config defaults consolidated into a single `_DEFAULTS` dict (no more scattered literal defaults)
- Write lock pattern: `_acquire_lock()` replaced with `@contextmanager _write_lock()` — acquire/release is now a single `with` block
- `YubiKeyInterface` changed from `ABC` to `Protocol` with `@runtime_checkable`
- Audit logger catches `OSError` on write and logs a warning instead of crashing the MCP server
- `deactivate_entry` notes-update failure is non-fatal: entry is still renamed, warning logged
- `_shred_file` logs a warning on `OSError` instead of silently swallowing the error
- Type aliases use Python 3.12+ `type` keyword (`type EntryFields = dict[str, str]`)

### Added

- `log_level` config field (default: `INFO`); controls structlog output level
- `run_cli_binary()` vault method returning raw `bytes` for binary attachment content
- Tool invocation logging: each MCP handler logs `tool_invoked` at INFO level
- 14 new tests: binary attachment round-trip, notes failure resilience, config validation edge cases, unlock handler coverage; total 129 tests at 96% coverage

### Fixed

- Binary attachment corruption: `get_attachment` now uses `run_cli_binary()` to preserve non-UTF-8 bytes (DER certificates, binary keys)
- `run_cli` error message when called with no args: now shows `"unknown"` instead of indexing an empty tuple

## [0.1.2] - 2026-02-28

### Added

- `unlock_vault` MCP tool: explicit vault unlock requiring YubiKey touch; must be called before any other vault tool
- `scripts/start-server.sh`: bash wrapper that resolves Python dependencies via `uv run --with` and starts the FastMCP server; eliminates manual `pip install` step for users
- PTH fake-tool simulation infrastructure (`scripts/fake-tools/`): fake `ykman` and `keepassxc-cli` binaries for plugin-test-harness sessions; prepended to PATH automatically by `start-server.sh` when the directory exists; never present in production

### Fixed

- MCP server startup: `.mcp.json` now uses flat `{"keepass": {...}}` format (the `mcpServers` wrapper is not supported in plugin context)
- Dependency resolution: server uses `uv run --with mcp,structlog,pyyaml,filelock` — no manual Python dependency installation required after plugin install
- `printf` format string handling in fake CLI: `printf -- '...'` prevents bash from interpreting leading dashes as option flags

## [0.1.1] - 2026-02-28

### Added

- 100 unit tests (up from 58): full handler layer coverage, edge cases for config, vault, audit, and tools
- `test_main.py` covering all 8 MCP handlers, `app_lifespan`, and helper functions (~90% coverage on `main.py`)
- ruff + mypy strict configuration; integration test framework with test database creation script

### Fixed

- `add_attachment` handler now catches `binascii.Error` from malformed base64 input
- All 8 MCP handlers now catch `subprocess.TimeoutExpired` from hanging `keepassxc-cli` processes

### Changed

- Comprehensive testing sweep: 58 → 100 tests, coverage raised to ~97%

## [0.1.0] - 2026-02-27

### Added

- FastMCP server with stdio transport and `app_lifespan` context manager
- YubiKey HMAC-SHA1 presence detection via `ykman list`, with configurable grace period on removal
- Vault state machine: locked/unlocked with background polling and auto-lock
- 5 read tools: `list_groups`, `list_entries`, `search_entries`, `get_entry`, `get_attachment`
- 3 write tools: `create_entry`, `deactivate_entry`, `add_attachment`
- Group allowlist restricting all tool access to configured groups
- Soft delete via `[INACTIVE]` prefix (no overwrite or hard delete)
- File locking for write operations via `filelock`
- Secure temp file handling: `chmod 600`, zero-fill before unlink
- JSONL audit logging for all secret-returning operations
- YAML configuration with env var override (`KEEPASS_CRED_MGR_CONFIG`)
- 6 credential-type skills: cPanel, FTP/SFTP, SSH, Brave Search API, Anthropic API, hygiene rules
- 3 slash commands: `/keepass-status`, `/keepass-rotate`, `/keepass-audit`
- Integration test framework with test database creation script
