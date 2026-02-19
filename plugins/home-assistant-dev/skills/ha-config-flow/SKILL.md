---
name: ha-config-flow
description: Home Assistant config flow for initial integration setup. Use when creating or debugging config_flow.py, the user-facing setup wizard, unique_id handling, or strings.json for the setup steps.
---

# Home Assistant Config Flow Development

Config flows are **mandatory** for all new integrations. They provide a guided UI-based setup experience that replaces YAML configuration.

## config_flow.py Template (2025)

```python
"""Config flow for {Name} integration."""
from __future__ import annotations

import logging
from typing import Any

import voluptuous as vol

from homeassistant.config_entries import (
    ConfigEntry,
    ConfigFlow,
    ConfigFlowResult,
    OptionsFlow,
)
from homeassistant.const import CONF_HOST, CONF_PASSWORD, CONF_USERNAME
from homeassistant.core import callback

from .const import DOMAIN

_LOGGER = logging.getLogger(__name__)


class {Name}ConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handle a config flow for {Name}."""

    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Handle the initial step."""
        errors: dict[str, str] = {}

        if user_input is not None:
            try:
                info = await self._async_validate_input(user_input)
            except CannotConnect:
                errors["base"] = "cannot_connect"
            except InvalidAuth:
                errors["base"] = "invalid_auth"
            except Exception:
                _LOGGER.exception("Unexpected exception")
                errors["base"] = "unknown"
            else:
                await self.async_set_unique_id(info["unique_id"])
                self._abort_if_unique_id_configured()
                return self.async_create_entry(title=info["title"], data=user_input)

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema({
                vol.Required(CONF_HOST): str,
                vol.Required(CONF_USERNAME): str,
                vol.Required(CONF_PASSWORD): str,
            }),
            errors=errors,
        )

    async def _async_validate_input(self, data: dict[str, Any]) -> dict[str, Any]:
        """Validate credentials and return device info."""
        client = MyClient(data[CONF_HOST], data[CONF_USERNAME], data[CONF_PASSWORD])
        device_info = await client.async_get_info()
        return {"title": device_info["name"], "unique_id": device_info["serial"]}

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        # See ha-options-flow for the OptionsFlow implementation
        return {Name}OptionsFlow()


class CannotConnect(Exception):
    """Error indicating connection failure."""

class InvalidAuth(Exception):
    """Error indicating invalid credentials."""
```

## strings.json — Config Section

```json
{
  "config": {
    "step": {
      "user": {
        "title": "Connect to {Name}",
        "description": "Enter the connection details.",
        "data": {
          "host": "Host",
          "username": "Username",
          "password": "Password"
        },
        "data_description": {
          "host": "The IP address or hostname of your device",
          "username": "Username for authentication",
          "password": "Password for authentication"
        }
      }
    },
    "error": {
      "cannot_connect": "Unable to connect. Check the host.",
      "invalid_auth": "Authentication failed.",
      "unknown": "Unexpected error occurred."
    },
    "abort": {
      "already_configured": "This device is already configured.",
      "reauth_successful": "Re-authentication successful."
    }
  }
}
```

## Key Rules

1. **Always use `data_description`** — provides context for each field
2. **Validate before saving** — attempt real connection in flow
3. **Set unique_id** — `async_set_unique_id()` + `_abort_if_unique_id_configured()`
4. **Store connection in `entry.data`**, preferences in `entry.options`
5. **VERSION field** — increment when schema changes, implement migration

## Discovery Support

For network discovery, see [reference/discovery-methods.md](reference/discovery-methods.md).

**Important (2025.1+):** ServiceInfo imports have moved:

```python
# NEW (2025.1+)
from homeassistant.helpers.service_info.zeroconf import ZeroconfServiceInfo
from homeassistant.helpers.service_info.ssdp import SsdpServiceInfo
from homeassistant.helpers.service_info.dhcp import DhcpServiceInfo
from homeassistant.helpers.service_info.usb import UsbServiceInfo

# OLD (deprecated, removed in 2026.2)
# from homeassistant.components.zeroconf import ZeroconfServiceInfo
```
