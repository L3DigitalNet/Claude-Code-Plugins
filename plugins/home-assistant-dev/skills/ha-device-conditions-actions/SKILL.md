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
from homeassistant.helpers import condition, config_validation as cv
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

    @callback
    def test_condition(hass: HomeAssistant, variables: TemplateVarsType) -> bool:
        """Test the condition."""
        # Implement your condition logic
        # Return True if condition is met
        return True

    return test_condition
```

## Device Actions

Actions let automations command devices directly.

```python
# device_action.py
"""Device actions for {Name}."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.const import CONF_DEVICE_ID, CONF_DOMAIN, CONF_TYPE
from homeassistant.core import Context, HomeAssistant
from homeassistant.helpers import config_validation as cv
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

    # Implement your action logic
    if action_type == "turn_on":
        # Call your service or method
        pass
```

## Registering in manifest.json

Device automation modules are auto-discovered when present. Ensure the manifest reflects the integration type:

```json
{
  "domain": "my_integration",
  "name": "My Integration",
  "integration_type": "device"
}
```

## Related Skills

- Device triggers → `ha-device-triggers`
- Service actions → `ha-service-actions`
