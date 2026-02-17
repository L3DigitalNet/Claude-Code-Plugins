# Example Hub Integration

[![hacs_badge](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)

A **Gold-tier** reference implementation for Home Assistant custom integrations.

## Features

- 🌡️ Temperature and humidity sensors
- 🔌 Switch control
- 📊 Diagnostic data collection
- 🔄 Automatic reconnection
- ⚙️ Configurable polling interval
- 🔐 Reauth flow for expired credentials

## Installation

### HACS (Recommended)

1. Open HACS in Home Assistant
2. Click "Integrations"
3. Click ⋮ → "Custom repositories"
4. Add this repository URL as category "Integration"
5. Click "Example Hub" → "Download"
6. Restart Home Assistant

### Manual

1. Copy `custom_components/example_hub` to your `custom_components` folder
2. Restart Home Assistant

## Configuration

1. Go to Settings → Devices & Services
2. Click "Add Integration"
3. Search for "Example Hub"
4. Enter your device details

## Options

| Option | Default | Description |
|--------|---------|-------------|
| Scan interval | 30 | Polling interval in seconds (10-300) |

## Troubleshooting

### Entity shows "Unavailable"

- Check that the device is powered on
- Verify network connectivity
- Check the integration logs for errors

### Authentication errors

- Use "Configure" to update credentials
- If that fails, remove and re-add the integration

## Development

This integration demonstrates Gold-tier patterns:

- `DataUpdateCoordinator` with `_async_setup`
- `entry.runtime_data` pattern
- `EntityDescription` for declarative entities
- Diagnostics with data redaction
- Complete config flow (user, reauth, reconfigure, options)

## License

MIT
