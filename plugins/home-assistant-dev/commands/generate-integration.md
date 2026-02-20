---
name: generate-integration
description: Generate a complete Home Assistant integration from scratch with all necessary files. Interactive command that scaffolds a full integration based on user requirements.
---

Generate a complete Home Assistant custom integration. Collects requirements, then produces all files for the selected quality tier.

## Step 1: Collect Core Details

Ask as a single open-ended question:

> "What is the **integration name** (e.g. "Smart Thermostat") and the **domain** (lowercase underscores, e.g. `smart_thermostat`)?"

Then collect bounded choices:

```
AskUserQuestion:
  "What type of integration is this?"
  header: "Integration type"
  options:
    - label: "Hub"
      description: "A gateway connecting multiple devices (e.g. Hue bridge, Z-Wave stick)"
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

## Step 2: Optional Features

```
AskUserQuestion:
  "Which optional features should be included?"
  header: "Features"
  multiSelect: true
  options:
    - label: "Options flow"
      description: "Let users reconfigure settings after setup (Silver IQS requirement)"
    - label: "Reauth flow"
      description: "Handle credential refresh without removing the integration (Silver IQS)"
    - label: "Diagnostics"
      description: "Download integration state for debugging (Gold IQS requirement)"
    - label: "Zeroconf/SSDP discovery"
      description: "Auto-discover devices on the local network (Gold IQS)"
```

## Step 3: Target Quality Tier

```
AskUserQuestion:
  "What quality tier should the generated code target?"
  header: "Target tier"
  options:
    - label: "Silver — reliability + options flow (Recommended)"
      description: "DataUpdateCoordinator, full error handling, options/reauth flow. Good default for new integrations."
    - label: "Gold — best user experience"
      description: "All Silver + diagnostics, translations, entity categories, discovery support"
    - label: "Bronze — minimum viable"
      description: "Config flow, coordinator, entities. Fastest to get started."
```

## Step 4: GitHub Username

Ask:

> "What is your **GitHub username** (for `codeowners` in manifest.json)?"

## Step 5: Confirm Before Writing

Display a plan and confirm:

```
AskUserQuestion:
  "Ready to generate files for `{domain}` ({integration_name}) at {tier} tier?"
  header: "Confirm"
  options:
    - label: "Generate (Recommended)"
      description: "Write all files into custom_components/{domain}/"
    - label: "Abort"
      description: "Cancel without writing anything"
```

If Abort: stop with "Generation cancelled."

## Step 6: Generate Files

### Bronze tier (always generated)
```
custom_components/{domain}/
├── __init__.py
├── manifest.json
├── config_flow.py
├── const.py
├── coordinator.py
├── entity.py
├── strings.json
├── translations/en.json
└── {platform}.py  (one per selected platform)
```

### Silver additions (if Silver or Gold)
- Options flow in `config_flow.py`
- Reauth flow in `config_flow.py`

### Gold additions (if Gold)
- `diagnostics.py` (if Diagnostics selected)
- `translations/en.json` with full entity translation keys
- `icons.json`
- Discovery step in `config_flow.py` (if discovery selected)

### HACS ready (always)
```
hacs.json
README.md
```

Use the `ha-integration-scaffold`, `ha-config-flow`, `ha-coordinator`, and `ha-entity-platforms` skills for all code patterns.

## Step 7: Completion Summary

After all files are written, output:

```
✓ Generated {N} files for `{domain}` ({integration_name}) — {tier} tier

Files created:
  custom_components/{domain}/
  {list of files}
  hacs.json
  README.md

Next steps:
  1. Implement your device client in coordinator.py → _async_update_data
  2. Add device-specific entity attributes in your platform files
  3. Run: /home-assistant-dev:ha-quality-review to check IQS compliance
  4. Run: /home-assistant-dev:ha-hacs when ready to publish to HACS
```
