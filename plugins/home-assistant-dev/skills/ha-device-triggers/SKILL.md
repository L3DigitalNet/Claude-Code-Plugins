---
name: ha-device-triggers
description: Device triggers for Home Assistant automation. Use when implementing device_trigger.py, allowing automations to fire on hardware events like button presses or motion detection.
---

# Home Assistant Device Triggers

Device triggers allow automations to be triggered by device-specific events, like button presses or motion detection.

## When to Use Device Triggers

Use device triggers when:
- Device has physical buttons or inputs
- Device generates events (motion, doorbell press)
- Hardware state changes need automation triggers
- Standard entity triggers aren't sufficient

## File Structure

```
custom_components/{domain}/
├── device_trigger.py    # Trigger implementation
├── device_condition.py  # See ha-device-conditions-actions
├── device_action.py     # See ha-device-conditions-actions
└── strings.json         # Trigger labels
```

## device_trigger.py Template

```python
"""Device triggers for {Name}."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.components.device_automation import DEVICE_TRIGGER_BASE_SCHEMA
from homeassistant.components.homeassistant.triggers import event as event_trigger
from homeassistant.const import CONF_DEVICE_ID, CONF_DOMAIN, CONF_PLATFORM, CONF_TYPE
from homeassistant.core import CALLBACK_TYPE, HomeAssistant
from homeassistant.helpers import device_registry as dr
from homeassistant.helpers.trigger import TriggerActionType, TriggerInfo
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN

# Define trigger types your device supports
TRIGGER_TYPES = {"button_press", "button_long_press", "motion_detected"}

TRIGGER_SCHEMA = DEVICE_TRIGGER_BASE_SCHEMA.extend(
    {
        vol.Required(CONF_TYPE): vol.In(TRIGGER_TYPES),
    }
)


async def async_get_triggers(
    hass: HomeAssistant, device_id: str
) -> list[dict[str, Any]]:
    """Return a list of triggers for this device."""
    device_registry = dr.async_get(hass)
    device = device_registry.async_get(device_id)

    if device is None:
        return []

    # Check if this device belongs to our integration
    if DOMAIN not in [id[0] for id in device.identifiers]:
        return []

    triggers = []

    # Add triggers based on device capabilities
    # In a real integration, check device.model or stored capabilities
    for trigger_type in TRIGGER_TYPES:
        triggers.append(
            {
                CONF_PLATFORM: "device",
                CONF_DEVICE_ID: device_id,
                CONF_DOMAIN: DOMAIN,
                CONF_TYPE: trigger_type,
            }
        )

    return triggers


async def async_attach_trigger(
    hass: HomeAssistant,
    config: ConfigType,
    action: TriggerActionType,
    trigger_info: TriggerInfo,
) -> CALLBACK_TYPE:
    """Attach a trigger."""
    event_config = event_trigger.TRIGGER_SCHEMA(
        {
            event_trigger.CONF_PLATFORM: "event",
            event_trigger.CONF_EVENT_TYPE: f"{DOMAIN}_event",
            event_trigger.CONF_EVENT_DATA: {
                CONF_DEVICE_ID: config[CONF_DEVICE_ID],
                CONF_TYPE: config[CONF_TYPE],
            },
        }
    )
    return await event_trigger.async_attach_trigger(
        hass, event_config, action, trigger_info, platform_type="device"
    )
```

## Firing Triggers

When your device generates an event, fire it from the coordinator or entity:

```python
from homeassistant.const import CONF_DEVICE_ID, CONF_TYPE

def handle_device_event(self, event_type: str) -> None:
    """Handle event from device."""
    self.hass.bus.async_fire(
        f"{DOMAIN}_event",
        {
            CONF_DEVICE_ID: self._device_id,
            CONF_TYPE: event_type,  # e.g., "button_press"
        },
    )
```

## strings.json for Triggers

```json
{
  "device_automation": {
    "trigger_type": {
      "button_press": "Button pressed",
      "button_long_press": "Button long pressed",
      "motion_detected": "Motion detected"
    }
  }
}
```

## Testing Device Triggers

```python
async def test_get_triggers(hass: HomeAssistant) -> None:
    """Test we get triggers."""
    from custom_components.my_domain.device_trigger import async_get_triggers

    device_registry = dr.async_get(hass)
    device = device_registry.async_get_or_create(
        config_entry_id="test",
        identifiers={(DOMAIN, "test_device")},
    )

    triggers = await async_get_triggers(hass, device.id)

    assert len(triggers) == 3
    assert triggers[0]["type"] == "button_press"
```

## Related Skills

- Device conditions and actions → `ha-device-conditions-actions`
- Automations → `ha-yaml-automations`
- Entity platforms → `ha-entity-platforms`
