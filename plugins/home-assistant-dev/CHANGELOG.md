# Changelog

All notable changes to the Home Assistant Development Plugin are documented here.

## [2.2.11] - 2026-07-02

### Changed

- polling-hub tests package + scope note + gitignore (F201)
- document MCP server env-var precedence in §5 (F266)
- rebuild dist bundle for review-finding source changes
- add validate-strings unit tests + guard via coverage (F167)
- fix domain/dir mismatch test + create config_flow.py sibling (F160)
- cover wildcard blocklist + getSafetyInfo + array redaction (F166, F168)
- README accuracy fix (F169)
- note CRITICAL repair severity is HA-internal (F119)
- correct IQS example-coverage claim (F107)
- note async_update_entry mutates entry in place (F100)
- clarify generate-docs.py is a standalone CLI (F74)
- fix fictional @anthropic npm install instructions (F63)
- cover wildcard blocklist in safety tests (F64)
- document the SAFE_DOMAINS dry-run bypass precisely (F53)
- cache the service catalog for validation (F57)
- make doc-template/generator linkage explicit (F45)
- mark unimplemented MCP tools as planned, fix 15->12 (F39)
- correct DESIGN_DOCUMENT skill count to 27 (F38)
- reconcile TESTING_STRATEGY with reality (F41, F42, F43)
- dedupe TESTING_STRATEGY — docs/ becomes a pointer to tests/ (F40)
- single-line prose in F32 device-trigger note (prettier)
- document device-trigger validation + capabilities hooks (F32)
- regenerate server bundle with committed src fixes (F1, F2, F8, F9, F11, F12)
- markdownlint --fix auto-fixable rules
- one-time Prettier normalization

### Fixed

- correct getSafetyInfo blocked count to 7 (F133)
- docs-index snippet/index perf + remove dead doc cache (F151, F152, F153, F155)
- validate-strings aborts affect validity + parity (F146, F150)
- validate-manifest codeowners + config_flow.py parity (F147, F159)
- docs_fetch related-pages naming (F157)
- export docs_examples pattern keys (F156)
- check-patterns perf, resilient walk, suppression, Python parity (F148, F149, F154, F158)
- de-duplicate blockedCount in getSafetyInfo (F145)
- cache entity/device registries + invalidate caches on reconnect (F141)
- README scripts section + async activation triggers (F188, F206, F213)
- ha-hacs minimum-HA baseline 2024.1.0 -> 2025.1.0 (F138)
- ha-debugging python3 for JSON/py_compile snippets (F240)
- test_iqs_accuracy.py review findings (F78, F190, F192)
- test_plugin_structure.py review findings (F195)
- test_validate_manifest.py review findings (F194)
- test_post_write_hook.py review findings (F196)
- run_tests.sh review findings (F76, F191)
- requirements.txt review findings (F75, F193)
- test-mcp-websocket.mjs review findings (F161)
- test-mcp-rest.mjs review findings (F162)
- E2E_CHECKLIST.md review findings (F165)
- docker-compose.test.yml review findings (F77)
- TESTING_STRATEGY.md review findings (F131, F263, F265)
- test_config_flow.py.template review findings (F284)
- requirements-test.txt.template review findings (F283)
- README.md.template review findings (F280)
- ruff.toml.template review findings (F136, F281)
- pre-commit-config.yaml.template review findings (F137)
- github-actions.yml.template review findings (F277, F278, F279, F282)
- SKILL.md review findings (F249, F251)
- SKILL.md review findings (F109, F117, F118, F243, F244, F246)
- SKILL.md review findings (F236, F241)
- SKILL.md review findings (F99, F217, F220, F222)
- SKILL.md review findings (F248)
- SKILL.md review findings (F245)
- SKILL.md review findings (F242, F247)
- quality-scale-checklist.md review findings (F234)
- SKILL.md review findings (F232, F239)
- SKILL.md review findings (F226, F227)
- SKILL.md review findings (F228)
- SKILL.md review findings (F94, F95, F214, F215)
- SKILL.md review findings (F235, F238)
- SKILL.md review findings (F231, F233)
- device-classes.md review findings (F98, F216, F219)
- SKILL.md review findings (F221, F223)
- SKILL.md review findings (F211)
- SKILL.md review findings (F110)
- SKILL.md review findings (F113, F114, F120)
- SKILL.md review findings (F237)
- SKILL.md review findings (F97, F218)
- SKILL.md review findings (F105)
- discovery-methods.md review findings (F104, F225, F230)
- SKILL.md review findings (F224, F229)
- SKILL.md review findings (F250)
- SKILL.md review findings (F212)
- SKILL.md review findings (F209, F210)
- validate-strings.py review findings (F175)
- test-watch.sh review findings (F178)
- setup-test-ha.sh review findings (F179, F180, F183, F185)
- post-write-hook.sh review findings (F177, F181)
- lint-integration.sh review findings (F182, F189)
- generate-docs.py review findings (F184, F186, F187)
- check-patterns.py review findings (F171, F172, F173, F174)
- tsconfig.test.json review findings (F163)
- jest.config.js review findings (F170)
- eslint.config.js review findings (F164)
- test_config_flow.py review findings (F207)
- strings.json review findings (F208)
- SELF_TEST_PROTOCOL.md review findings (F132, F134, F264, F267, F268)
- MCP_SERVER_PLAN.md review findings (F130, F259, F261, F262)
- DESIGN_DOCUMENT.md review findings (F125, F126, F127, F128, F129, F258, F260)
- README.md review findings (F122, F123, F135, F256, F269, F270, F275, F276)
- guard getDevices admin call, getLogs source array, document service-data fold (F139, F142, F144)
- push coordinator fixes (F204, F205)
- polling-hub sensor fix (F200)
- diagnostics fix (F197)
- remove unused CONF_DEVICE_ID (F203)
- comment unused reauth entry_data (F198)
- note unique_id should key on stable id (F199)
- validate domain + compute file count (F124)
- clarify Bronze translations baseline vs Gold (F254)
- reviewer description + haiku rationale (F252, F253)
- tools frontmatter as YAML array (F255)
- repair Response Format fenced block (F257)
- changelog dedupe 2.2.8, move Unreleased to top, drop stale size (F271, F273, F274)
- diagnostics TO_REDACT superset + DOMAIN import (F111, F112)
- order-independent device-trigger test assertion (F108)
- correct recorder exclusion examples (F115, F116)
- use plural automation block keys (F121)
- qualify manifest version requirement for HACS (F106)
- soften Button IDENTIFY entity_category claim (F96)
- soften 'immutable state' overstatement (F93)
- correct fire-and-forget task label (F92)
- options-flow reauth accuracy (F101, F102, F103)
- register the hub device for via_device (F81)
- rename example exceptions shadowing builtins (F83)
- minimal sensor integration_type entity not device (F85)
- drop has_entity_name for device-free minimal sensor (F82)
- poll minimal sensor before adding (F84)
- raise ConfigEntryNotReady on push connect failure (F90)
- stable push device identifier from entry_id (F89)
- use translation_key for push sensor name (F91)
- use hass.loop.time() not deprecated get_event_loop (F88)
- move import random to module top in push coordinator (F87)
- declare quality_scale in example manifests (F86)
- raise hacs.json HA minimum to match code (F79, F80)
- return structured result for strings file/JSON errors (F69)
- domain/directory mismatch is an error, matching Python (F70)
- build setup-test-ha payloads safely (F71, F72)
- mirror full default blocklist in test config (F73)
- tighten missing-unique-id suppression (F68)
- warn on explicit config_flow:false, not just absent (F66)
- assert real invariant in getDevices/getLogs e2e (F65)
- count missing abort strings toward validity (F59)
- skip inline-comment matches in check-patterns (F60)
- scope service-in-setup-entry regex to the function body (F58)
- redact real service-call result, not just dry-run (F56)
- preserve arrays in redactSensitiveData (F52)
- add env overrides for docs/validation tools (F51)
- narrow docs_examples enum to implemented patterns (F62)
- narrow docs_search section to core (only indexed) (F61)
- disconnect prior client on reconnect (F49)
- validate get_config response shape before trusting it (F50)
- unsubscribe entity listener on disconnect (F48)
- don't fail open to empty in area entity lookup (F55)
- harden getLogs since/level filtering (F46, F54)
- validate required service fields by presence, not truthiness (F47)
- patch the real ConfigFlow class, not DOMAIN.title() (F44)
- remove unsupported skills: frontmatter from agents (F37)
- update recorder statistics metadata to mean_type (F34)
- import diagnostics handler from the integration, not core (F33)
- import InvalidAuth in config-flow test template (F31)
- repair README/info.md template fence nesting (F36)
- modern trigger/action keys in README-template automation (F35)
- drop BluetoothServiceInfo from 2025.1 relocation list (F30)
- read SSDP host from ssdp_location, not ssdp_headers \_host (F29)
- use async_register_platform_entity_service helper (F28)
- use UpdateFailed retry_after, correct to HA 2025.11 (F26, F27)
- correct async_add_executor_job positional example (F25)
- mix in RestoreEntity for async_get_last_state (F24)
- enable custom integrations in push tests + document PHCC (F23)
- track push coordinator background tasks for cancellation (F22)
- align push reauth merge idiom with polling-hub (F21)
- add reconfigure_successful abort string to polling-hub (F19)
- clear error when per-module build is missing (F14)
- route config_flow.py writes to the sibling strings.json (F17)
- guard non-dict strings.json sections before .keys()/.items() (F16)
- parse manifest path as positional, not sys.argv[-1] (F18)
- type-guard manifest fields before string ops (F15)
- make missing-future-annotations a file-level check (F12)
- make safety README accurate about blocked vs warned services (F11)
- stop env layer clobbering file-level safety config (F9)
- validate config file structure before merging (F8)
- pass config_entry to polling-hub coordinator super().**init** (F202)
- pass config_entry to coordinator super().**init** (F7)
- add missing push-integration binary_sensor platform (F6)
- enable custom integrations in polling-hub tests + ha-testing template (F5)
- add missing polling-hub switch + binary_sensor platforms (F4, F20)
- make example check-patterns tests assert real signal (F3)
- implement verify_ssl so the documented control works (F2, F10)
- polyfill global WebSocket from ws for Node 18/20 (F1)
- bump typescript-eslint to ^8.60.1 for TypeScript 6 compat
- final structural fixes — markdownlint now 0
- scripted structural fixes (MD036/MD040/MD025)

## [Unreleased]

## [2.2.10] - 2026-05-25

### Changed

- security: bump fast-uri >=3.1.2 + qs >=6.15.2 (closes Dependabot #88-95, 4 high + 2 medium)

## [2.2.9] - 2026-05-25

### Changed

- docs+security: closeout for 2026-05-08 session
- home-assistant-dev: fix Jest compile by adding tsconfig.test.json
- home-assistant-dev: Phase 2 — hook dispatcher + manifest guard (11 cases)

### Fixed

- add 'types: [node]' to mcp-server tsconfig for TS 6 compatibility

## [2.2.8] - 2026-05-07

### Changed

- `tests/test_plugin_structure.py`: removed `"WebSearch"` from the `VALID_AGENT_TOOLS` allowlist. The token was defensive; no HA agent declared it. Aligns with the marketplace-wide migration away from the built-in `WebSearch` tool toward MCP-based search backends (`brave-search`, `serper-search`, `tavily`).

## [2.2.7] - 2026-04-23

### Changed

- `ha-integration-reviewer` agent downgraded from Sonnet to Haiku. The review checklist is structural (manifest fields, config_flow presence, coordinator usage, type annotations) — mechanical pattern-matching with no inference required. Roughly 40% reduction in per-review token cost when invoked from Opus sessions.

## [2.2.6] - 2026-04-20

### Changed

- npm audit fix - resolve hono, path-to-regexp CVEs

### Fixed

- unblock 3 plugin releases

## [2.2.5] - 2026-04-07

### Changed

- Bump handlebars
- Bump hono in /plugins/home-assistant-dev/mcp-server
- Bump picomatch
- Bump the all-dependencies group across 1 directory with 7 updates
- Bump flatted in /plugins/home-assistant-dev/mcp-server
- bump express-rate-limit
- bump @hono/node-server

### Fixed

- bump ts-jest to 29.4.9 in both plugin lock files

## [2.2.4] - 2026-03-04

### Changed

- update remaining L3Digital-Net references
- update org references from L3Digital-Net to L3DigitalNet

### Fixed

- apply audit findings — plugin.json, CHANGELOG
- bump hono to 4.12.4 (CVE-2026-27700)

## [2.2.3] - 2026-03-02

### Changed

- Fix structural README issues and docs path
- Revert: restore original HA skill files, remove extracted references
- Strengthen skill triggers and extract long content to references

### Fixed

- Fix ha-dev skill count in README

## [2.2.2] - 2026-02-22

### Fixed

- `validate_manifest` MCP tool now throws (returns `isError:true`) when `path` argument is missing, consistent with `validate_strings` and `check_patterns` behavior

## [2.2.1] - 2026-02-20

### Changed

- Update version numbers in design and testing documents to v2.2.1 and v1.0.5

### Fixed

- Update hono 4.11.9 → 4.12.0 in mcp-server lockfiles (GHSA-gq3j-xvxp-8hrf)

## [2.2.0] - 2026-02-19

### Added

- Audit and split wide-scope skills

### Fixed

- Update hono 4.11.9 → 4.12.0 in mcp-server lockfiles (GHSA-gq3j-xvxp-8hrf)
- Fix HA Dev Plugin Tests failures on testing and main

## [2.1.0] - 2026-02-18

### Added

- MCP server now wired into plugin via `.mcp.json` — registers `ha-dev-mcp` with 12 tools for live HA connection, documentation search, and code validation
- esbuild bundling for MCP server — single self-contained `dist/server.bundle.cjs` requires no `npm install` post-plugin-install
- `.gitignore` for plugin directory — tracks only the distributable bundle, ignores build artifacts and `node_modules/`

### Fixed

- `commands/scaffold-integration.md` — added missing `name` frontmatter field
- `plugin.json` — updated author from `Chris/chrisuthe` to `L3DigitalNet` to match marketplace
- `plugin.json` — fixed `repository` URL to point to `L3DigitalNet/Claude-Code-Plugins`
- `marketplace.json` — restored MCP server mention in description now that it's wired in
- `README.md` — replaced stale `chrisuthe/ha-dev-plugin` install URLs with correct marketplace install instructions
- `README.md` — fixed directory tree root name from `ha-dev-plugin/` to `home-assistant-dev/`
- `README.md` — fixed skill count in directory tree from 18 to 19
- `mcp-server/package.json` — changed package name from `@anthropic/ha-dev-mcp-server` to `ha-dev-mcp-server`
- `mcp-server/package.json` — changed author from `Anthropic` to `L3DigitalNet`

## [2.0.4] - 2026-02-17

### Fixed

- `hooks/hooks.json` rewritten to use correct record schema with dispatcher pattern
- Replaced invalid trigger/action format with proper `PostToolUse` matcher and `${CLAUDE_PLUGIN_ROOT}` path variable

### Added

- `scripts/post-write-hook.sh` — dispatcher script that routes PostToolUse events to the appropriate validation script based on file path

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
  - DataUpdateCoordinator with \_async_setup
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
