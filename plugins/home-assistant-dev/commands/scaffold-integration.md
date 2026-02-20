---
name: scaffold-integration
description: Scaffold a new Home Assistant integration with all required files
disable-model-invocation: true
---

Create a new Home Assistant integration with all required files following 2025 best practices.

## Step 1: Collect Integration Details

Ask for the domain name and integration name as a single open-ended question:

> "What is the **domain name** (lowercase, underscores only — e.g. `my_device`) and the **human-readable name** (e.g. "My Device") for this integration?"

Then use AskUserQuestion for the bounded choices:

```
AskUserQuestion:
  "What type of integration is this?"
  header: "Integration type"
  options:
    - label: "Hub"
      description: "A gateway that connects multiple devices (e.g. Hue bridge, Z-Wave stick)"
    - label: "Device"
      description: "A single standalone device (e.g. one smart plug, one sensor)"
    - label: "Service"
      description: "A cloud or network service (e.g. weather API, notification service)"
```

```
AskUserQuestion:
  "How does this integration communicate with the device/service?"
  header: "IoT class"
  options:
    - label: "local_polling — query device on a schedule (Recommended)"
      description: "Your code calls the device/API periodically to fetch state"
    - label: "local_push — device sends updates to HA"
      description: "Device pushes state changes via webhook, socket, or event"
    - label: "cloud_polling — query cloud API on a schedule"
      description: "Your code calls a remote API periodically"
    - label: "cloud_push — cloud sends updates to HA"
      description: "Remote service pushes state changes via webhook or SSE"
```

```
AskUserQuestion:
  "Which entity platforms does this integration expose? (select all that apply)"
  header: "Platforms"
  multiSelect: true
  options:
    - label: "sensor"
      description: "Read-only state values (temperature, power usage, status)"
    - label: "switch / binary_sensor"
      description: "On/off controls or binary state readings"
    - label: "light"
      description: "Dimmable or colour-controllable lights"
    - label: "climate / other"
      description: "Thermostats, covers, fans, media players, or other platforms"
```

Finally, ask for the GitHub username:

> "What is your **GitHub username** (used for `codeowners` in manifest.json)?"

## Step 2: Confirm Before Writing

Before writing any files, display a summary and confirm:

```
AskUserQuestion:
  "Ready to generate {N} files for `{domain}` ({integration_name})?"
  header: "Confirm"
  options:
    - label: "Generate — create the files (Recommended)"
      description: "Write all scaffold files into custom_components/{domain}/"
    - label: "Abort — cancel"
      description: "Stop without writing anything"
```

If Abort: stop immediately with "Scaffold cancelled."

## Step 3: Generate Files

Write these files using the `ha-integration-scaffold`, `ha-config-flow`, `ha-coordinator`, and `ha-entity-platforms` skills for patterns:

1. `custom_components/{domain}/manifest.json`
2. `custom_components/{domain}/__init__.py`
3. `custom_components/{domain}/const.py`
4. `custom_components/{domain}/config_flow.py`
5. `custom_components/{domain}/coordinator.py`
6. `custom_components/{domain}/entity.py`
7. `custom_components/{domain}/strings.json`
8. `custom_components/{domain}/translations/en.json`
9. `custom_components/{domain}/{platform}.py` for each selected platform

## Quality Target

Generate code that meets **Silver tier** on the Integration Quality Scale:
- DataUpdateCoordinator for polling
- Full error handling (UpdateFailed, ConfigEntryAuthFailed)
- CoordinatorEntity inheritance
- Options flow
- Reauth flow structure

## Step 4: Completion Summary

After all files are written, output:

```
✓ Generated {N} files for `{domain}` ({integration_name}) — Silver tier

Files created:
  custom_components/{domain}/manifest.json
  custom_components/{domain}/__init__.py
  custom_components/{domain}/const.py
  custom_components/{domain}/config_flow.py
  custom_components/{domain}/coordinator.py
  custom_components/{domain}/entity.py
  custom_components/{domain}/strings.json
  custom_components/{domain}/translations/en.json
  {platform files...}

Next steps:
  1. Implement your device client in coordinator.py → _async_update_data
  2. Add device-specific entity attributes in {platform}.py
  3. Run: /home-assistant-dev:ha-quality-review to check IQS compliance
```
