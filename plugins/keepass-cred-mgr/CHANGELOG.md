# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.5.0] - 2026-03-14

### Added
- support slot:serial format for yubikey_slot config
- integrate diagnostics into vault.unlock() error paths
- add YubiKey unlock failure diagnostics module

### Changed
- add audit findings fix plan
- add YubiKey access hardening design and plan
- add YubiKey access prerequisites and v0.4.2 changelog

### Fixed
- update integration tests for list_entries signature change
- sync version metadata to 0.4.2
- falsy field check, unused audit param, stale docs
- multi-line notes parsing and allow_inactive for audit


## [0.4.2] - 2026-03-14

### Added

- `server/diagnostics.py`: YubiKey unlock failure diagnostics module; checks pcscd status, hidraw device presence, and slot:serial config on any unlock failure
- `yubikey_slot` config field now accepts `"slot:serial"` format (e.g., `"2:36834370"`) for systems where keepassxc-cli cannot auto-detect the YubiKey serial
- "YubiKey Access Prerequisites" section in setup guide covering pcscd conflicts, hidraw recovery, and serial configuration

### Changed

- `yubikey_slot` config type changed from `int` to `str`; integer values from YAML are auto-coerced for backward compatibility
- `vault.unlock()` error messages now include specific diagnostics (pcscd blocking, missing hidraw node, missing serial) instead of a generic pcscd hint
- `run_cli()` timeout error no longer includes the pcscd hint (command-level timeouts are unrelated to YubiKey access)

### Fixed

- `/keepass-audit` command: `get_entry` now accepts `allow_inactive=True` to read `[INACTIVE]` entries without raising `EntryInactive`
- `_parse_show_output` now captures multi-line notes (continuation lines after `Notes:` field)
- `create_entry` uses `is not None` instead of truthy check for optional fields; empty string values are no longer silently dropped
- Stale "Group allowlist" references removed from `vault.py` docstring and README Security Model section
- Unreachable `TimeoutError` removed from `unlock_vault` exception handler
- Unused `audit` parameter removed from `list_entries` and `search_entries` signatures
- `pyproject.toml` version synced to 0.4.2 (was stale at 0.3.0)
- `marketplace.json` version synced to 0.4.2 (was stale at 0.4.1)

### Removed

- `_PCSCD_HINT` constant from `vault.py` (replaced by diagnostics module)


## [0.4.1] - 2026-03-04

### Fixed
- apply audit findings — CHANGELOG
- backport _sanitize_extra guard to testing branch


## [Unreleased]

## [0.4.0] - 2026-03-03

### Added

- Tag-based access control: entries tagged `AI RESTRICTED` are blocked from all AI access (read and write); entries tagged `READ ONLY` block write operations but remain fully readable
- `_parse_tags()` helper in `server/tools/read.py` extracts semicolon-separated tags from `keepassxc-cli show` output
- `EntryRestricted` exception raised when `AI RESTRICTED` tag is detected during `get_entry`, `get_attachment`, `list_entries`, or `search_entries`
- `EntryReadOnly` exception raised when `READ ONLY` tag is detected during `deactivate_entry` or `add_attachment`
- `search_entries` now handles multi-level group paths (`rsplit("/", 1)` instead of `partition("/")`) — entries in sub-groups like `SSH Keys/Personal/SSH - laptop` are correctly attributed
- `list_entries(group=None)` now enumerates all vault groups via `list_groups()` instead of reading a config allowlist
- Test database seeded with `AI RESTRICTED` and `READ ONLY` tagged entries, sub-group `SSH Keys/Personal`, and multi-level path test entries

### Changed

- `allowed_groups` removed from config entirely; old configs with this key still load (silently ignored for backward compatibility)
- `list_groups` now returns all vault groups with no filtering
- Credential skills updated: `GROUP:` replaced with `STORAGE DEFAULT:` with note that vault layout is user-organized; agents use `search_entries` if entry not found in default group
- `keepass-hygiene` skill updated with search-first lookup rule, `AI RESTRICTED` handling, and `READ ONLY` handling

### Removed

- `GroupNotAllowed` exception and `check_group_allowed()` method — group-based access control replaced by tag-based enforcement


## [0.3.2] - 2026-03-02

### Changed
- em dash cleanup, root README sync


## [0.3.1] - 2026-02-28

### Fixed

- `.mcp.json` was absent from the installed cache directory, preventing Claude Code from registering the MCP server
- `start-server.sh` activated fake tools based on directory existence (`scripts/fake-tools/` is in the git tree); now requires `KEEPASS_USE_FAKE_TOOLS=1` to be set explicitly, so production sessions always use the real `keepassxc-cli`

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
