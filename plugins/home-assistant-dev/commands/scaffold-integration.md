---
name: scaffold-integration
description: Scaffold a new Home Assistant integration with all required files
disable-model-invocation: true
---

Create a new Home Assistant integration with all required files following 2025 best practices.

## Required Information

Ask for:
1. **Domain name**: lowercase, underscores only (e.g., `my_device`)
2. **Integration name**: Human readable (e.g., "My Device")
3. **Integration type**: hub, device, or service
4. **IoT class**: local_polling, local_push, cloud_polling, cloud_push
5. **Platforms**: sensor, binary_sensor, switch, light, climate, etc.
6. **GitHub username**: For codeowners

## Files to Generate

1. `custom_components/{domain}/manifest.json`
2. `custom_components/{domain}/__init__.py`
3. `custom_components/{domain}/const.py`
4. `custom_components/{domain}/config_flow.py`
5. `custom_components/{domain}/coordinator.py`
6. `custom_components/{domain}/entity.py`
7. `custom_components/{domain}/strings.json`
8. `custom_components/{domain}/translations/en.json`
9. `custom_components/{domain}/{platform}.py` for each platform

## Quality Target

Generate code that meets **Silver tier** on the Integration Quality Scale:
- DataUpdateCoordinator for polling
- Full error handling (UpdateFailed, ConfigEntryAuthFailed)
- CoordinatorEntity inheritance
- Options flow
- Reauth flow structure

Use the `ha-integration-scaffold`, `ha-config-flow`, `ha-coordinator`, and `ha-entity-platforms` skills for patterns.
