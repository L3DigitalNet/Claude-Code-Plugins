# Changelog

All notable changes to the Home Assistant Development Plugin are documented here.

## [2.0.0] - 2026-02-17

### Added

#### New Skills (7)
- `ha-hacs` - Complete HACS compliance guide: hacs.json, brands, validation, publishing
- `ha-diagnostics` - Diagnostics implementation for Gold tier compliance  
- `ha-migration` - Version migration, deprecation fixes, config entry upgrades
- `ha-documentation` - README and documentation generation
- `ha-repairs` - Repair issues and fix flows (Gold tier requirement)
- `ha-device-triggers` - Device triggers, conditions, and actions
- `ha-websocket-api` - Custom WebSocket API commands
- `ha-recorder` - Statistics and history integration

#### Automated Validation (5 scripts)
- `scripts/validate-manifest.py` - Validates manifest.json required fields
- `scripts/validate-strings.py` - Syncs config_flow.py steps with strings.json
- `scripts/check-patterns.py` - Detects 20+ anti-patterns and deprecations
- `scripts/lint-integration.sh` - Wrapper for ruff, mypy, and custom checks
- `scripts/generate-docs.py` - Generates README and info.md from code

#### Hook Configuration
- `hooks/hooks.json` - PostToolUse hook configuration for automatic validation

#### Example Integrations (3)
- `examples/polling-hub/` - Complete Gold-tier reference integration
  - DataUpdateCoordinator with _async_setup
  - entry.runtime_data pattern
  - EntityDescription pattern for sensors
  - Complete config flow (user, reauth, reconfigure, options)
  - Diagnostics with data redaction
  - HACS-compliant structure
  - GitHub Actions workflow
  - Test examples
- `examples/minimal-sensor/` - Bronze-tier minimal example for learning
- `examples/push-integration/` - Silver-tier push-based integration with dispatcher

#### Project Templates (9)
- `templates/testing/conftest.py.template` - Test fixtures
- `templates/testing/test_config_flow.py.template` - Config flow tests
- `templates/testing/test_init.py.template` - Setup/unload tests
- `templates/testing/pytest.ini.template` - pytest configuration
- `templates/testing/requirements-test.txt.template` - Test dependencies
- `templates/ci/github-actions.yml.template` - CI/CD workflow
- `templates/ci/pre-commit-config.yaml.template` - Pre-commit hooks
- `templates/ci/ruff.toml.template` - Ruff linter configuration
- `templates/docs/README.md.template` - Documentation template
- `templates/docs/info.md.template` - HACS info page template

#### Commands
- `generate-integration` - Generate complete integration from prompts

#### MCP Server (Complete Implementation)
- `mcp-server/` - Full TypeScript MCP server implementation
  - 12 tool handlers across 3 categories
  - Home Assistant WebSocket client with state caching
  - Safety layer with configurable blocklists
  - Documentation search with pre-indexed content
  - Code pattern detection for 20+ anti-patterns
  - Manifest and strings.json validation
  - Unit tests for safety checker
  - ESLint and Jest configuration

### Changed

#### ha-integration-scaffold
- Added `issue_tracker` to manifest.json template (required for HACS)
- Added `services.yaml` and `icons.json` to file structure
- Added HACS repository structure (hacs.json, README.md)

#### ha-quality-review (REWRITTEN)
- Now covers all 52 official IQS rules (was ~30%)
- Bronze tier: 18 rules
- Silver tier: 10 rules
- Gold tier: 21 rules
- Platinum tier: 3 rules
- Added quick validation commands
- Updated reference checklist with implementation examples

#### ha-config-flow
- Added OptionsFlow deprecation note (don't use `__init__`)
- Clarified `self.config_entry` is automatically available

#### ha-testing
- Fixed missing imports in test_init.py examples
- Added `MockConfigEntry` import
- Added `test_setup_entry_not_ready` example
- Added proper type hints

### Fixed
- Removed malformed directory artifacts
- Corrected manifest.json required fields list

### Statistics
- **19 skills** (up from 11)
- **5 scripts** for automated validation
- **3 example integrations**
- **9 project templates**
- **~75 files** total (up from 22)

## [1.0.0] - 2026-02-17

### Added

#### Skills (11 total)
- `ha-architecture` - Core HA internals: event bus, state machine, service registry, entity lifecycle
- `ha-integration-scaffold` - Scaffold new integrations with 2025 file structure
- `ha-config-flow` - Config flows, options flows, reauth, discovery methods
- `ha-coordinator` - DataUpdateCoordinator with `_async_setup` and error handling
- `ha-entity-platforms` - Entity platforms with EntityDescription patterns
- `ha-service-actions` - Service actions in Python and YAML
- `ha-async-patterns` - Async Python patterns for Home Assistant
- `ha-testing` - pytest patterns with hass fixture
- `ha-debugging` - Troubleshooting workflows and common fixes
- `ha-yaml-automations` - YAML automations, scripts, blueprints
- `ha-quality-review` - Integration Quality Scale assessment

#### Agents (3 total)
- `ha-integration-dev` - Full integration development specialist
- `ha-integration-reviewer` - Code reviewer against Quality Scale
- `ha-integration-debugger` - Systematic debugging assistant

#### Commands
- `scaffold-integration` - Interactive integration scaffolding

#### Reference Files
- `ha-config-flow/reference/discovery-methods.md` - Zeroconf, SSDP, DHCP, USB patterns
- `ha-entity-platforms/reference/device-classes.md` - Complete device class reference
- `ha-quality-review/reference/quality-scale-checklist.md` - Full tier checklists

### Home Assistant Compatibility

- Targets Home Assistant 2025.2+ (Python 3.13)
- Includes ServiceInfo import relocations (2025.1+)
- Includes DataUpdateCoordinator `_async_setup` (2024.8+)
- Includes `retry_after` support (2025.10+)
- Follows Integration Quality Scale requirements

### Claude Code Compatibility

- Requires Claude Code 1.0+
- Uses plugin manifest v1 schema
- Skills support progressive disclosure via reference files
