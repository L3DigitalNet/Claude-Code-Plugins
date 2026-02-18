# Changelog

All notable changes to the linux-sysadmin-mcp plugin are documented here.

## [1.0.0] - 2026-02-17

### Added
- 5-layer self-testing framework with 1343 assertions across all 106 tools
  - Layer 1: Structural validation (92 pytest tests)
  - Layer 2: MCP server startup validation (14 tests)
  - Layer 3: Tool execution via MCP protocol (1188 assertions, 106 tools)
  - Layer 4: Safety gate unit + E2E tests (26 tests)
  - Layer 5: Knowledge base unit tests (23 tests)
- Disposable Fedora 43 test container with systemd (Dockerfile, docker-compose.yml, setup-fixtures.sh)
- Test runner orchestrator (`tests/run_tests.sh`) with `--unit-only`, `--container-only`, `--skip-container`, `--fresh` modes
- Self-test protocol and results documentation
- `.gitignore` for build artifacts

### Changed
- MCP config updated to use bundled CJS output
- Design document refined with implementation details

## [0.1.0] - 2026-02-17

### Added
- Initial release with 106 MCP tools across 15 modules
- Safety gate with risk classification and confirmation flow
- Knowledge base with 8 YAML profiles (crowdsec, docker, fail2ban, nginx, pihole, sshd, ufw, unbound)
- Distro detection for RHEL/Debian/Arch families
- esbuild CJS bundle for distribution
