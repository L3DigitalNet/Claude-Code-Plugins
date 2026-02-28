# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.1] - 2026-02-28

### Added
- KeePassXC Credential Manager plugin v0.1.0
- add manual setup guide for KeePass MCP plugin

### Changed
- add ruff + mypy config, fix lint and type issues
- fill coverage gaps for handler and search_entries branches
- fill integration test stubs with real keepassxc-cli calls
- add PasswordVault helper for integration tests
- add quality hardening implementation plan
- add quality hardening design (integration tests, coverage, linting)
- Release keepass-cred-mgr v0.1.1
- comprehensive testing (58 -> 100 tests, ~90%+ coverage)


## [0.1.1] - 2026-02-27

### Fixed

- `add_attachment` handler now catches `binascii.Error` from malformed base64 input
- All 8 MCP handlers now catch `subprocess.TimeoutExpired` from hanging `keepassxc-cli` processes

### Added

- 100 unit tests (up from 58): full handler layer coverage, edge cases for config, vault, audit, and tools
- `test_main.py` covering all 8 MCP handlers, `app_lifespan`, and helper functions (~90% coverage on `main.py`)

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
