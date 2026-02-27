# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
- 58 unit tests across config, YubiKey, vault, audit, and tool modules
- Integration test framework with test database creation script
