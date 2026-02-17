---
name: ha-service-actions
description: Generate and explain Home Assistant service actions for controlling entities (lights, switches, climate, media, covers) in Python and YAML. Use when asking about calling services, controlling devices, hass.services.async_call, entity actions, turn_on, turn_off, or invoking HA actions.
---

# Home Assistant Service Actions

Service calls (now called "actions" in the UI) are the primary mechanism for controlling devices. Register them in `async_setup`, not `async_setup_entry`.

## Python Service Calls

```python
await hass.services.async_call(
    domain="light",
    service="turn_on",
    service_data={"brightness_pct": 80, "color_temp_kelvin": 3000},
    target={"entity_id": "light.living_room"},
    blocking=True,  # Wait for completion
)
```

### Targeting

```python
# Multiple entities
target={"entity_id": ["light.kitchen", "light.hallway"]}

# By area
target={"area_id": "living_room"}

# By device
target={"device_id": "abc123def456"}
```

## Registering Custom Actions

Register in `async_setup` (not `async_setup_entry`):

```python
import voluptuous as vol
from homeassistant.helpers import config_validation as cv

async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async def handle_set_mode(call: ServiceCall) -> None:
        entity_ids = call.data.get("entity_id")
        mode = call.data["mode"]
        # Process the action...

    hass.services.async_register(
        DOMAIN,
        "set_mode",
        handle_set_mode,
        schema=vol.Schema({
            vol.Required("entity_id"): cv.entity_ids,
            vol.Required("mode"): vol.In(["auto", "manual", "eco"]),
        }),
    )
    return True
```

## services.yaml

Define action metadata for the UI:

```yaml
set_mode:
  name: "Set Mode"
  description: "Set the operating mode."
  target:
    entity:
      integration: my_integration
  fields:
    mode:
      name: "Mode"
      description: "The operating mode to set."
      required: true
      example: "auto"
      selector:
        select:
          options:
            - "auto"
            - "manual"
            - "eco"
```

## Entity-Level Actions

For actions that operate on specific entities:

```python
from homeassistant.helpers import entity_platform

async def async_setup_entry(hass, entry, async_add_entities):
    platform = entity_platform.async_get_current_platform()

    platform.async_register_entity_service(
        "set_mode",
        {vol.Required("mode"): vol.In(["auto", "manual", "eco"])},
        "async_set_mode",  # Method on entity class
    )

    async_add_entities([MyEntity(entry.runtime_data)])
```

## Common Actions Reference

### Lights
```python
await hass.services.async_call("light", "turn_on", {
    "brightness_pct": 80,
    "color_temp_kelvin": 3000,
    "transition": 2,
}, target={"entity_id": "light.bedroom"}, blocking=True)
```

### Climate
```python
await hass.services.async_call("climate", "set_temperature", {
    "temperature": 22,
    "hvac_mode": "heat",
}, target={"entity_id": "climate.thermostat"}, blocking=True)
```

### Media Player
```python
await hass.services.async_call("media_player", "play_media", {
    "media_content_id": "https://example.com/stream",
    "media_content_type": "music",
}, target={"entity_id": "media_player.speaker"}, blocking=True)
```

## YAML Actions (Automations)

```yaml
action:
  - action: light.turn_on
    target:
      entity_id: light.living_room
    data:
      brightness_pct: 80

  - action: climate.set_temperature
    target:
      entity_id: climate.thermostat
    data:
      temperature: 22
```

## Targeting Guidelines

Target the level the action actually operates on:
- **Entity-level**: Action operates on specific entities → use `entity_id`
- **Device-level**: Action operates on device → use `device_id`
- **Config entry-level**: Action operates on connection/account → use `config_entry_id`

Do not use lower-level targets as a workaround for higher-level ones.
