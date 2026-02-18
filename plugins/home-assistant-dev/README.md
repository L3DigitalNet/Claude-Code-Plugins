# Home Assistant Development Plugin for Claude Code

A comprehensive Claude Code plugin for Home Assistant integration development. Provides skills, agents, and commands aligned with the official [Home Assistant Developer Documentation](https://developers.home-assistant.io/) and the [Integration Quality Scale](https://developers.home-assistant.io/docs/core/integration-quality-scale/).

## Features

### 19 Agent Skills

Skills are automatically invoked when Claude detects relevant context:

| Skill | Description |
|-------|-------------|
| `ha-architecture` | Core HA internals: event bus, state machine, entity lifecycle |
| `ha-integration-scaffold` | Scaffold integrations with correct structure |
| `ha-config-flow` | Config flows, options flows, reauth, discovery |
| `ha-coordinator` | DataUpdateCoordinator patterns and error handling |
| `ha-entity-platforms` | Entity platforms (sensor, switch, light, etc.) |
| `ha-service-actions` | Service actions in Python and YAML |
| `ha-async-patterns` | Async Python patterns for HA |
| `ha-testing` | pytest patterns with hass fixture |
| `ha-debugging` | Troubleshooting and diagnostics |
| `ha-yaml-automations` | YAML automations, scripts, blueprints |
| `ha-quality-review` | Integration Quality Scale (all 52 rules) |
| `ha-hacs` | HACS compliance, hacs.json, brands, publishing |
| `ha-diagnostics` | Diagnostics implementation (Gold tier) |
| `ha-migration` | Version migration, deprecation fixes |
| `ha-documentation` | README and documentation generation |
| `ha-repairs` | Repair issues and fix flows (Gold tier) |
| `ha-device-triggers` | Device triggers, conditions, actions |
| `ha-websocket-api` | Custom WebSocket API commands |
| `ha-recorder` | Statistics and history integration |

### Automated Validation

Scripts that run automatically or on demand:

| Script | Description |
|--------|-------------|
| `validate-manifest.py` | Validates required fields, iot_class, version |
| `validate-strings.py` | Syncs config_flow.py steps with strings.json |
| `check-patterns.py` | Detects 20+ anti-patterns and deprecations |
| `lint-integration.sh` | Runs ruff, mypy, and all validators |
| `generate-docs.py` | Generates README and info.md from code |

### Example Templates

| Example | Tier | Description |
|---------|------|-------------|
| `polling-hub` | Gold | Complete reference with DataUpdateCoordinator, diagnostics, tests |
| `minimal-sensor` | Bronze | Simplest possible integration for learning |
| `push-integration` | Silver | Push-based updates with dispatcher pattern |

### Project Templates

| Template | Purpose |
|----------|---------|
| `testing/conftest.py` | Test fixtures template |
| `testing/test_config_flow.py` | Config flow tests |
| `testing/test_init.py` | Setup/unload tests |
| `testing/pytest.ini` | pytest configuration |
| `ci/github-actions.yml` | CI/CD workflow |
| `ci/pre-commit-config.yaml` | Pre-commit hooks |
| `ci/ruff.toml` | Ruff linter config |
| `docs/README.md` | Documentation template |

### 3 Specialized Agents

| Agent | Purpose |
|-------|---------|
| `ha-integration-dev` | Full integration development guidance |
| `ha-integration-reviewer` | Code review against Quality Scale |
| `ha-integration-debugger` | Systematic debugging assistance |

### Commands

| Command | Description |
|---------|-------------|
| `/home-assistant-dev:scaffold-integration` | Scaffold a new integration interactively |
| `/home-assistant-dev:generate-integration` | Generate complete integration from prompts |
| `/home-assistant-dev:ha-quality-review` | Run Quality Scale assessment |

## Installation

### From Marketplace (Recommended)

```bash
# Add the L3DigitalNet marketplace
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins

# Install the plugin
/plugin install home-assistant-dev@l3digitalnet-plugins
```

### Local Development

```bash
# Clone the marketplace repository
git clone https://github.com/L3DigitalNet/Claude-Code-Plugins.git

# Install from local path
claude --plugin-dir ./Claude-Code-Plugins/plugins/home-assistant-dev
```

### Verify Installation

```bash
# Check plugin is loaded
/plugin list

# View available skills
/skills
```

## Usage

### Automatic Invocation

Skills trigger automatically based on your prompts:

```
"Create a new integration for my smart thermostat"
→ Loads ha-integration-scaffold, ha-config-flow, ha-coordinator

"My entities are showing unavailable"
→ Loads ha-debugging, ha-coordinator

"Prepare my integration for HACS"
→ Loads ha-hacs, ha-quality-review
```

### Running Validation

```bash
# Validate manifest
python scripts/validate-manifest.py custom_components/my_integration/manifest.json

# Check for anti-patterns
python scripts/check-patterns.py custom_components/my_integration/

# Run all linters
bash scripts/lint-integration.sh custom_components/my_integration/

# Generate documentation
python scripts/generate-docs.py custom_components/my_integration/
```

## What This Plugin Knows

### Home Assistant 2025+ Requirements

- Python 3.13 required (HA 2025.2+)
- Modern type syntax (`list[str]` not `List[str]`)
- `from __future__ import annotations` everywhere
- Config flow mandatory (no YAML-only)
- `entry.runtime_data` instead of `hass.data[DOMAIN]`

### Integration Quality Scale

The plugin covers all 52 IQS rules across 4 tiers:

| Tier | Rules | Key Requirements |
|------|-------|------------------|
| **Bronze** | 18 | Config flow, unique IDs, tests, branding |
| **Silver** | 10 | Error handling, reauth, options, unload |
| **Gold** | 21 | Diagnostics, repairs, translations, discovery |
| **Platinum** | 3 | Async library, websession injection, strict typing |

### Deprecation Coverage

The plugin tracks all major deprecations:
- ServiceInfo import relocation (2025.1 → 2026.2)
- `hass.data[DOMAIN]` → `entry.runtime_data`
- OptionsFlow `__init__` deprecation
- VacuumActivity enum migration
- Camera WebRTC changes
- Type annotation modernization

## Directory Structure

```
home-assistant-dev/
├── .claude-plugin/
│   └── plugin.json
├── skills/                    # 19 skills
│   ├── ha-architecture/
│   ├── ha-integration-scaffold/
│   ├── ha-config-flow/
│   ├── ha-coordinator/
│   ├── ha-entity-platforms/
│   ├── ha-service-actions/
│   ├── ha-async-patterns/
│   ├── ha-testing/
│   ├── ha-debugging/
│   ├── ha-yaml-automations/
│   ├── ha-quality-review/
│   ├── ha-hacs/
│   ├── ha-diagnostics/
│   ├── ha-migration/
│   ├── ha-documentation/
│   ├── ha-repairs/
│   ├── ha-device-triggers/
│   ├── ha-websocket-api/
│   └── ha-recorder/
├── agents/                    # 3 agents
├── commands/                  # 2 commands
├── scripts/                   # 5 validation scripts
├── hooks/                     # Automation hooks
├── examples/                  # 3 example integrations
│   ├── polling-hub/
│   ├── minimal-sensor/
│   └── push-integration/
├── templates/                 # Project templates
│   ├── testing/
│   ├── ci/
│   └── docs/
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## References

- [Home Assistant Developer Docs](https://developers.home-assistant.io/)
- [Integration Quality Scale](https://developers.home-assistant.io/docs/core/integration-quality-scale/)
- [Creating an Integration](https://developers.home-assistant.io/docs/creating_component_index/)
- [Config Flow](https://developers.home-assistant.io/docs/config_entries_config_flow_handler/)
- [DataUpdateCoordinator](https://developers.home-assistant.io/docs/integration_fetching_data/)
- [HACS Documentation](https://hacs.xyz/docs/publish/integration/)
- [Home Assistant Brands](https://github.com/home-assistant/brands)

## Contributing

Contributions welcome! Please ensure changes align with the official Home Assistant developer documentation.

## License

MIT License - see [LICENSE](LICENSE)
