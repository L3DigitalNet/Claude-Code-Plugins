---
name: ha-documentation
description: Generate documentation for Home Assistant integrations. Creates README.md, Home Assistant docs pages, and HACS info pages. Use when asked about documentation, README, docs, or making documentation for an integration.
---

# Home Assistant Integration Documentation

Guide for creating comprehensive documentation for custom integrations.

## Documentation Files

| File | Purpose | Location |
|------|---------|----------|
| README.md | GitHub landing page | Repository root |
| info.md | HACS description | Repository root |
| docs/*.md | Extended docs | Optional |

## README.md Template

```markdown
# {Integration Name}

[![hacs_badge](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![GitHub Release](https://img.shields.io/github/release/{username}/{repo}.svg)](https://github.com/{username}/{repo}/releases)

{Brief description of what the integration does.}

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

### HACS (Recommended)

1. Open HACS in Home Assistant
2. Click "Integrations"
3. Click ⋮ → "Custom repositories"
4. Add `https://github.com/{username}/{repo}` as category "Integration"
5. Click "{Integration Name}" → "Download"
6. Restart Home Assistant

### Manual

1. Download the latest release
2. Copy `custom_components/{domain}` to your `custom_components` folder
3. Restart Home Assistant

## Configuration

1. Go to **Settings** → **Devices & Services**
2. Click **+ Add Integration**
3. Search for "{Integration Name}"
4. Follow the setup wizard

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| Host | Required | Device IP or hostname |
| Username | Required | Login username |
| Password | Required | Login password |

### Advanced Options

| Option | Default | Description |
|--------|---------|-------------|
| Scan Interval | 30 | Update frequency in seconds |

## Entities

### Sensors

| Entity | Description |
|--------|-------------|
| sensor.{domain}_temperature | Current temperature |
| sensor.{domain}_humidity | Current humidity |

### Switches

| Entity | Description |
|--------|-------------|
| switch.{domain}_power | Main power switch |

## Automation Examples

### Turn on when temperature drops

```yaml
automation:
  - alias: "Low Temperature Alert"
    trigger:
      - platform: numeric_state
        entity_id: sensor.{domain}_temperature
        below: 18
    action:
      - service: notify.mobile_app
        data:
          message: "Temperature dropped below 18°C"
```

## Troubleshooting

### Entity shows "Unavailable"

- Check device is powered on
- Verify network connectivity
- Check integration logs for errors

### Authentication Errors

1. Go to integration settings
2. Click "Configure"
3. Re-enter credentials

## Known Limitations

- Limitation 1
- Limitation 2

## Support

- [GitHub Issues](https://github.com/{username}/{repo}/issues)
- [Home Assistant Community](https://community.home-assistant.io/)

## License

MIT
```

## HACS info.md Template

```markdown
# {Integration Name}

{Detailed description for HACS store page.}

## What it does

{Explain the integration's purpose and capabilities.}

## Requirements

- Home Assistant 2024.1.0 or later
- {Device/Service name} with firmware X.X or later

## Features

- ✅ Config flow setup
- ✅ Options flow for settings
- ✅ Diagnostics support
- ✅ Automatic reconnection
```

## Documentation Best Practices

### Structure

1. **Start with what it does** — Users should know in 10 seconds
2. **Installation first** — Most common task
3. **Configuration with examples** — Show, don't just tell
4. **Entity reference** — Complete list of what's created
5. **Troubleshooting** — Answer common questions preemptively
6. **Known limitations** — Set expectations

### Writing Style

- Use second person ("you" not "the user")
- Be concise — bullet points over paragraphs
- Include screenshots where helpful
- Keep examples copy-paste ready
- Update version numbers in badges

### Badges to Include

```markdown
[![hacs_badge](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![GitHub Release](https://img.shields.io/github/release/user/repo.svg)](https://github.com/user/repo/releases)
[![GitHub Downloads](https://img.shields.io/github/downloads/user/repo/total.svg)](https://github.com/user/repo/releases)
[![License](https://img.shields.io/github/license/user/repo.svg)](LICENSE)
```

## IQS Documentation Requirements

### Bronze

- `docs-high-level-description`: What the integration does
- `docs-installation-instructions`: How to install
- `docs-removal-instructions`: How to remove
- `docs-actions`: Service action documentation

### Silver

- `docs-installation-parameters`: All setup fields explained
- `docs-configuration-parameters`: All options explained

### Gold

- `docs-data-update`: How/when data updates
- `docs-examples`: Automation examples
- `docs-known-limitations`: What doesn't work
- `docs-supported-devices`: Compatible devices
- `docs-supported-functions`: Feature list
- `docs-troubleshooting`: Common issues
- `docs-use-cases`: Real-world examples

## Related Skills

- Integration structure → `ha-integration-scaffold`
- HACS publishing → `ha-hacs`
- Quality review → `ha-quality-review`
