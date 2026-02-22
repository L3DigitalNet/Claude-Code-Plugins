# README.md Template

Full template for a Home Assistant custom integration GitHub landing page.

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
