# Home Assistant Development

A comprehensive Claude Code plugin for Home Assistant integration development. Provides skills, agents, and commands aligned with the official [Home Assistant Developer Documentation](https://developers.home-assistant.io/) and the [Integration Quality Scale](https://developers.home-assistant.io/docs/core/integration-quality-scale/).

## Summary

This plugin brings deep Home Assistant integration expertise into Claude Code — covering the full development lifecycle from scaffolding a new integration through HACS publishing. Skills load automatically when Claude detects relevant context, providing current guidance on async patterns, entity platforms, config flows, the DataUpdateCoordinator, and all 52 Integration Quality Scale rules. Includes three specialized agents and five validation scripts.

## Principles

**[P1] Skills Over Monolith** — Knowledge is partitioned into 27 focused skills rather than one large document. Each skill loads only when Claude detects relevant context, minimising context cost on every task.

**[P2] IQS Compliance from Day One** — Integration Quality Scale coverage (all 52 rules) is a first-class requirement, not a post-publication concern. The plugin guides toward Gold tier from the first line of code.

**[P3] Modern Patterns Only** — The plugin tracks and enforces current HA APIs. Deprecated code paths (`hass.data`, `OptionsFlow.__init__`, etc.) are flagged and replaced — the plugin never silently tolerates outdated patterns.

**[P4] Safety for Live Connections** — The MCP server connects to live Home Assistant instances in read-mostly mode. Destructive service calls require explicit dry-run bypass. The plugin never risks unintended home automation state changes.

**[P5] Quality by Example** — Abstract guidance is backed by three concrete reference integrations at Bronze, Silver, and Gold tier — copy-paste starting points that already meet their tier requirements in full.

## Installation

```bash
# Add the L3DigitalNet marketplace
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins

# Install the plugin
/plugin install home-assistant-dev@l3digitalnet-plugins
```

Or for local development:
```bash
git clone https://github.com/L3DigitalNet/Claude-Code-Plugins.git
claude --plugin-dir ./Claude-Code-Plugins/plugins/home-assistant-dev
```

## Installation Notes

Verify the plugin loaded correctly after installation:
```bash
/plugin list
/skills    # Shows all available skills including the 27 ha-* skills
```

Validation scripts (`scripts/`) require Python 3.13+ and are run directly from the plugin cache directory or the source tree.

## Usage

Skills trigger automatically based on your prompts — no manual invocation needed:

```
"Create a new integration for my smart thermostat"
→ Loads ha-integration-scaffold, ha-config-flow, ha-coordinator

"My entities are showing unavailable"
→ Loads ha-debugging, ha-coordinator

"Prepare my integration for HACS"
→ Loads ha-hacs, ha-quality-review
```

For interactive workflows, use the commands directly:
```
/home-assistant-dev:generate-integration
/home-assistant-dev:ha-quality-review
```

## Commands

| Command | Description |
|---------|-------------|
| `/home-assistant-dev:scaffold-integration` | Scaffold a new integration interactively with guided prompts |
| `/home-assistant-dev:generate-integration` | Generate a complete integration from a description |
| `/home-assistant-dev:ha-quality-review` | Run a full Integration Quality Scale assessment |

## Skills

Skills are automatically invoked when Claude detects relevant context:

| Skill | Description |
|-------|-------------|
| `ha-architecture` | Core HA internals: event bus, state machine, service registry, and integration loading |
| `ha-entity-lifecycle` | Entity lifecycle and device/entity registries — async_added_to_hass, device_info, identifiers |
| `ha-integration-scaffold` | Scaffold integrations with correct file structure |
| `ha-config-flow` | Config flow for initial integration setup — user step, unique_id, discovery |
| `ha-options-flow` | Options flow for post-setup preferences, and reauth when credentials expire |
| `ha-coordinator` | DataUpdateCoordinator patterns and error handling |
| `ha-entity-platforms` | Entity platforms (sensor, switch, light, cover, climate, etc.) |
| `ha-service-actions` | Service actions in Python and YAML |
| `ha-async-patterns` | Async Python patterns for Home Assistant |
| `ha-testing` | pytest patterns with the hass fixture |
| `ha-debugging` | Troubleshooting and diagnostics |
| `ha-yaml-automations` | YAML automations — triggers, conditions, and actions |
| `ha-scripts` | YAML scripts — callable, reusable action sequences with optional parameters |
| `ha-blueprints` | YAML blueprints — reusable automation templates with configurable inputs |
| `ha-quality-review` | Integration Quality Scale (all 52 rules) |
| `ha-hacs` | HACS metadata — hacs.json, manifest.json fields, and repository structure |
| `ha-hacs-publishing` | Publish to HACS — GitHub Actions, release workflow, brands submission |
| `ha-diagnostics` | Diagnostics implementation (Gold tier) |
| `ha-migration` | Integration upgrade guide — entry point for version migration and deprecation fixes |
| `ha-config-migration` | Config entry version migration — VERSION, MINOR_VERSION, async_migrate_entry |
| `ha-deprecation-fixes` | Fix deprecation warnings for HA 2024.x/2025.x compatibility |
| `ha-documentation` | README and documentation generation |
| `ha-repairs` | Repair issues and fix flows (Gold tier) |
| `ha-device-triggers` | Device triggers — allow automations to fire on hardware events |
| `ha-device-conditions-actions` | Device conditions and actions for automation — device_condition.py, device_action.py |
| `ha-websocket-api` | Custom WebSocket API commands |
| `ha-recorder` | Statistics and history integration |

## Agents

| Agent | Description |
|-------|-------------|
| `ha-integration-dev` | Full integration development — scaffolding, entities, config flow, coordinator |
| `ha-integration-reviewer` | Code review against all 52 Integration Quality Scale rules |
| `ha-integration-debugger` | Systematic debugging with structured diagnostics |

## Validation Scripts

Scripts that run automatically via hooks or on demand from your integration directory:

| Script | Description |
|--------|-------------|
| `validate-manifest.py` | Validates required fields, iot_class, version |
| `validate-strings.py` | Syncs config_flow.py steps with strings.json |
| `check-patterns.py` | Detects 20+ anti-patterns and deprecations |
| `lint-integration.sh` | Runs ruff, mypy, and all validators |
| `generate-docs.py` | Generates README and info.md from code |

```bash
python scripts/validate-manifest.py custom_components/my_integration/manifest.json
python scripts/check-patterns.py custom_components/my_integration/
bash scripts/lint-integration.sh custom_components/my_integration/
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
├── skills/                    # 27 skills
├── agents/                    # 3 agents
├── commands/                  # 3 commands
├── scripts/                   # 5 validation scripts
├── hooks/                     # Automation hooks
├── examples/                  # 3 reference integrations
│   ├── polling-hub/           # Gold tier reference with DataUpdateCoordinator
│   ├── minimal-sensor/        # Bronze tier starter
│   └── push-integration/      # Silver tier push-based
├── templates/                 # CI, testing, and docs templates
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Planned Features

- **Live HA instance integration** — connect to a running HA instance via REST API to inspect real entity states during development
- **Auto-test generation** — generate pytest test stubs from a finished integration's config flow and coordinator code
- **IQS progress dashboard** — interactive checklist showing which Quality Scale rules are satisfied vs. outstanding for the current integration
- **More deprecation tracking** — auto-detect and suggest fixes for newly deprecated APIs as HA versions advance

## Known Issues

- **IQS rule coverage may lag** — the 52 rules tracked reflect HA up to the 2025.x cycle; new rules added in future HA releases will need skill updates before they appear in quality reviews
- **`generate-integration` can time out on large specs** — very detailed generation prompts may hit context limits; break the request into multiple passes using the scaffold command followed by targeted skill invocations
- **Scripts require a Python environment** — validation scripts must be run in an environment where `python3` is available; they are not installed as executables
- **`ha-quality-review` skill is read-only** — the skill identifies rule violations but does not auto-fix them; apply fixes manually or invoke the relevant implementation skills

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

MIT License — see [LICENSE](LICENSE)
