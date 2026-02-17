# Minimal Sensor Integration

A **Bronze-tier** minimal example for learning Home Assistant integration development.

## Purpose

This is the simplest possible integration structure. Use it for:
- Learning the basics
- Quick prototypes
- Simple single-sensor devices

For production integrations with multiple devices or complex state management, see the `polling-hub` example.

## Structure

```
minimal_sensor/
├── __init__.py      # Entry point (minimal)
├── config_flow.py   # Simple user flow
├── sensor.py        # Single sensor entity
├── manifest.json
└── strings.json
```

## What's Missing (By Design)

This example deliberately omits production patterns:
- ❌ DataUpdateCoordinator (uses direct polling)
- ❌ Options flow
- ❌ Reauth flow
- ❌ Diagnostics
- ❌ Multiple platforms
- ❌ Device registry

## Installation

Copy `custom_components/minimal_sensor` to your Home Assistant's `custom_components` folder.

## License

MIT
