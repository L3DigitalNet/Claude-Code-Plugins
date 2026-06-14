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

Register in `async_setup` (not `async_setup_entry`). This data-level action targets entities, so do not declare `entity_id` in the vol schema — let target-based entity-service registration (see §Entity-Level Actions) resolve it, matching the services.yaml `target` block below and §Targeting Guidelines:

```python
import voluptuous as vol
from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN

async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async def handle_set_mode(call: ServiceCall) -> None:
        mode = call.data["mode"]
        # Process the action...

    hass.services.async_register(
        DOMAIN,
        "set_mode",
        handle_set_mode,
        schema=vol.Schema({
            vol.Required("mode"): vol.In(["auto", "manual", "eco"]),
        }),
    )
    return True
```

### Entry-Level (Connection/Account) Actions

For an action that operates on a connection or account, follow the IQS `action-setup` rule (Bronze): register actions in `async_setup`, accept a `config_entry_id`, look up the entry, and raise `ServiceValidationError` if it is missing or not loaded. See developers.home-assistant.io/docs/core/integration-quality-scale/rules/action-setup.

```python
import voluptuous as vol
from homeassistant.config_entries import ConfigEntryState
from homeassistant.const import ATTR_CONFIG_ENTRY_ID
from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN

async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async def handle_sync(call: ServiceCall) -> None:
        entry_id = call.data[ATTR_CONFIG_ENTRY_ID]
        entry = hass.config_entries.async_get_entry(entry_id)
        if entry is None:
            raise ServiceValidationError(f"Config entry {entry_id} not found")
        if entry.state is not ConfigEntryState.LOADED:
            raise ServiceValidationError(f"Config entry {entry_id} is not loaded")
        # Use entry.runtime_data for the live connection...

    hass.services.async_register(
        DOMAIN,
        "sync",
        handle_sync,
        schema=vol.Schema({
            vol.Required(ATTR_CONFIG_ENTRY_ID): str,
        }),
    )
    return True
```

## services.yaml

Define action metadata for the UI. The `target` block here is what supplies `entity_id` (via target resolution), so the Python schema must not also declare `entity_id` — register the handler as a platform entity service (see §Entity-Level Actions) to match this target block:

```yaml
set_mode:
  name: 'Set Mode'
  description: 'Set the operating mode.'
  target:
    entity:
      integration: my_integration
  fields:
    mode:
      name: 'Mode'
      description: 'The operating mode to set.'
      required: true
      example: 'auto'
      selector:
        select:
          options:
            - 'auto'
            - 'manual'
            - 'eco'
```

## Entity-Level Actions

For actions that operate on specific entities:

```python
import voluptuous as vol
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers import service
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN

# HA 2025.9+: register platform entity services from async_setup via the service
# helper, not platform.async_register_entity_service during platform setup, so the
# service does not depend on platform loading ("Improved API for registering
# platform entity services").
async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    service.async_register_platform_entity_service(
        hass,
        DOMAIN,
        "set_mode",
        entity_domain=Platform.CLIMATE,
        schema={vol.Required("mode"): vol.In(["auto", "manual", "eco"])},
        func="async_set_mode",  # Method on entity class
    )
    return True
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

`media_content_type` should match the source: use `MediaType.MUSIC` for music, `MediaType.URL` for an arbitrary stream URL. Reference the `MediaType` enum (`homeassistant.components.media_player.const.MediaType`) rather than a bare string.

```python
from homeassistant.components.media_player.const import MediaType

await hass.services.async_call("media_player", "play_media", {
    "media_content_id": "https://example.com/stream",
    "media_content_type": MediaType.URL,
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
