---
name: ha-device-conditions-actions
description: Device conditions and actions for Home Assistant automation. Use when implementing device_condition.py, device_action.py, condition state checks, or device-level automation actions.
---

# Home Assistant — Device Conditions and Actions

## Device Conditions

Conditions let automations check device state before proceeding.

```python
# device_condition.py
"""Device conditions for {Name}."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.const import CONF_CONDITION, CONF_DEVICE_ID, CONF_DOMAIN, CONF_TYPE
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers import (
    condition,
    config_validation as cv,
    entity_registry as er,
)
from homeassistant.helpers.typing import ConfigType, TemplateVarsType

from .const import DOMAIN

CONDITION_TYPES = {"is_on", "is_off", "is_connected"}

CONDITION_SCHEMA = cv.DEVICE_CONDITION_BASE_SCHEMA.extend(
    {
        vol.Required(CONF_TYPE): vol.In(CONDITION_TYPES),
    }
)


async def async_get_conditions(
    hass: HomeAssistant, device_id: str
) -> list[dict[str, Any]]:
    """Return conditions for device."""
    conditions = []
    for condition_type in CONDITION_TYPES:
        conditions.append(
            {
                CONF_CONDITION: "device",
                CONF_DEVICE_ID: device_id,
                CONF_DOMAIN: DOMAIN,
                CONF_TYPE: condition_type,
            }
        )
    return conditions


@callback
def async_condition_from_config(
    hass: HomeAssistant, config: ConfigType
) -> condition.ConditionCheckerType:
    """Create a condition from config."""

    condition_type = config[CONF_TYPE]
    device_id = config[CONF_DEVICE_ID]

    @callback
    def test_condition(hass: HomeAssistant, variables: TemplateVarsType) -> bool:
        """Test the condition."""
        # Worked example: resolve the device's entity and check its state.
        # Replace the always-True placeholder below with logic like this.
        entity_id = er.async_resolve_entity_id_from_unique_id(hass, ...)
        if condition_type == "is_on":
            return condition.state(hass, entity_id, "on")
        if condition_type == "is_off":
            return condition.state(hass, entity_id, "off")
        # Placeholder for unhandled types — always-True is a stub, not correct logic.
        return True

    return test_condition
```

## Device Actions

Actions let automations command devices directly.

Each kind carries a different discriminator key in its listed dicts — this asymmetry is intentional, do not "fix" it: triggers set `CONF_PLATFORM: "device"`, conditions set `CONF_CONDITION: "device"` (above), and actions set neither (the `device_action.py` module location is the discriminator).

```python
# device_action.py
"""Device actions for {Name}."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.const import (
    ATTR_ENTITY_ID,
    CONF_DEVICE_ID,
    CONF_DOMAIN,
    CONF_TYPE,
    SERVICE_TURN_OFF,
    SERVICE_TURN_ON,
)
from homeassistant.core import DOMAIN as HA_DOMAIN, Context, HomeAssistant
from homeassistant.helpers import config_validation as cv, entity_registry as er
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN

ACTION_TYPES = {"turn_on", "turn_off", "toggle"}

ACTION_SCHEMA = cv.DEVICE_ACTION_BASE_SCHEMA.extend(
    {
        vol.Required(CONF_TYPE): vol.In(ACTION_TYPES),
    }
)


async def async_get_actions(
    hass: HomeAssistant, device_id: str
) -> list[dict[str, Any]]:
    """Return actions for device."""
    actions = []
    for action_type in ACTION_TYPES:
        actions.append(
            {
                CONF_DEVICE_ID: device_id,
                CONF_DOMAIN: DOMAIN,
                CONF_TYPE: action_type,
            }
        )
    return actions


async def async_call_action_from_config(
    hass: HomeAssistant,
    config: ConfigType,
    variables: dict[str, Any],
    context: Context | None,
) -> None:
    """Execute action."""
    action_type = config[CONF_TYPE]
    device_id = config[CONF_DEVICE_ID]

    # Worked example: resolve the device's entity and call a real service.
    entity_id = er.async_resolve_entity_id_from_unique_id(hass, ...)
    service = {"turn_on": SERVICE_TURN_ON, "turn_off": SERVICE_TURN_OFF}.get(action_type)
    if service is not None:
        await hass.services.async_call(
            HA_DOMAIN,
            service,
            {ATTR_ENTITY_ID: entity_id},
            blocking=True,
            context=context,
        )
```

## Manifest and discovery

These are two unrelated concerns — do not conflate them:

1. **Module discovery.** Home Assistant discovers `device_trigger.py` / `device_condition.py` / `device_action.py` by filename presence in your integration package. No manifest change is needed to enable them.
2. **`integration_type`.** This is an independent classification field (`device` / `hub` / `service` / `helper` / `system`, defaulting to `hub`) chosen by the integration's actual topology — a single physical device vs. a hub fronting many devices vs. a cloud service. It affects UI grouping and the `dynamic-devices` / `devices` quality-scale rules. Set it to match what the integration really is; do **not** force `"integration_type": "device"` just because the integration ships device automations (a hub integration with device automations is still a hub).

## Related Skills

- Device triggers → `ha-device-triggers`
- Service actions → `ha-service-actions`
