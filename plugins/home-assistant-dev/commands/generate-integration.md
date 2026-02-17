---
name: generate-integration
description: Generate a complete Home Assistant integration from scratch with all necessary files. Interactive command that scaffolds a full integration based on user requirements.
---

# Generate Integration Command

Generate a complete Home Assistant custom integration with all necessary files.

## Usage

```
/home-assistant-dev:generate-integration
```

## Interactive Prompts

The command will ask for:

1. **Integration name** (human-readable): "My Smart Device"
2. **Domain** (lowercase, underscores): "my_smart_device"
3. **Integration type**: hub, device, service
4. **IoT class**: local_polling, local_push, cloud_polling, cloud_push
5. **Platforms needed**: sensor, switch, binary_sensor, light, climate, etc.
6. **Features**:
   - Options flow
   - Reauth flow
   - Reconfigure flow
   - Diagnostics
   - Discovery (Zeroconf/SSDP)
7. **Target tier**: Bronze, Silver, Gold

## Generated Files

### Bronze Tier (Minimum)
```
custom_components/{domain}/
├── __init__.py
├── manifest.json
├── config_flow.py
├── const.py
├── strings.json
└── {platform}.py (for each platform)
```

### Silver Tier (+ Reliability)
```
+ coordinator.py
+ entity.py (base class)
+ Options flow in config_flow.py
+ Reauth flow in config_flow.py
```

### Gold Tier (+ Best Experience)
```
+ diagnostics.py
+ translations/en.json
+ icons.json
+ services.yaml (if needed)
+ device_trigger.py (if applicable)
```

### HACS Ready
```
/
├── custom_components/{domain}/
├── hacs.json
├── README.md
├── LICENSE
└── .github/workflows/validate.yml
```

## Example Output

After running the command with:
- Name: "Smart Thermostat"
- Domain: "smart_thermostat"
- Type: device
- IoT class: local_polling
- Platforms: sensor, climate
- Features: options flow, diagnostics
- Tier: Gold

You get a complete, ready-to-customize integration.

## Post-Generation Steps

1. **Implement client library**: Replace mock client calls
2. **Add your API logic**: In coordinator._async_update_data
3. **Customize entities**: Add device-specific sensors
4. **Add tests**: Use templates from `templates/testing/`
5. **Update README**: Add device-specific documentation

## Related Commands

- `/home-assistant-dev:scaffold-integration` - Original scaffolding command
- `/home-assistant-dev:ha-quality-review` - Review generated integration

## Related Skills

- `ha-integration-scaffold` - File structure details
- `ha-config-flow` - Config flow customization
- `ha-coordinator` - Data fetching patterns
- `ha-hacs` - HACS publishing
