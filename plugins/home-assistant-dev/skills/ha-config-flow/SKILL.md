---
name: ha-config-flow
description: Generate or fix Home Assistant config flow code (config_flow.py, options flow, reauth flow, strings.json). Use when mentioning config flow, options flow, reauth, UI setup, configuration flow, setup wizard, or creating/debugging the user-facing setup experience for an integration.
---

# Home Assistant Config Flow Development

Config flows are **mandatory** for all new integrations. They provide a guided UI-based setup experience that replaces YAML configuration.

## Complete config_flow.py Template (2025)

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

    async def async_step_reauth(
        self, entry_data: dict[str, Any]
    ) -> ConfigFlowResult:
        """Handle reauth when credentials expire."""
        return await self.async_step_reauth_confirm()

    async def async_step_reauth_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Collect new credentials for reauth."""
        errors: dict[str, str] = {}

        if user_input is not None:
            reauth_entry = self._get_reauth_entry()
            data = {**reauth_entry.data, **user_input}
            try:
                await self._async_validate_input(data)
            except CannotConnect:
                errors["base"] = "cannot_connect"
            except InvalidAuth:
                errors["base"] = "invalid_auth"
            else:
                return self.async_update_reload_and_abort(reauth_entry, data=data)

        return self.async_show_form(
            step_id="reauth_confirm",
            data_schema=vol.Schema({
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
        return {Name}OptionsFlow()


class {Name}OptionsFlow(OptionsFlow):
    """Handle options."""

    # NOTE: Do NOT use __init__ to store config_entry - deprecated since 2025.12
    # Access via self.config_entry (automatically set by HA)

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema({
                vol.Optional(
                    "scan_interval",
                    default=self.config_entry.options.get("scan_interval", 30),
                ): vol.All(vol.Coerce(int), vol.Range(min=10, max=300)),
            }),
        )


class CannotConnect(Exception):
    """Error indicating connection failure."""

class InvalidAuth(Exception):
    """Error indicating invalid credentials."""
```

## strings.json Template

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
      },
      "reauth_confirm": {
        "title": "Re-authenticate",
        "description": "Your credentials have expired.",
        "data": {
          "username": "Username",
          "password": "Password"
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
  },
  "options": {
    "step": {
      "init": {
        "title": "Settings",
        "data": {
          "scan_interval": "Update interval (seconds)"
        },
        "data_description": {
          "scan_interval": "How often to poll the device (10-300 seconds)"
        }
      }
    }
  }
}
```

## Key Rules

1. **Always use `data_description`** — provides context for each field
2. **Validate before saving** — attempt real connection in flow
3. **Set unique_id** — `async_set_unique_id()` + `_abort_if_unique_id_configured()`
4. **Store connection in `entry.data`**, preferences in `entry.options`
5. **Implement reauth** — raise `ConfigEntryAuthFailed` in coordinator to trigger
6. **VERSION field** — increment when schema changes, implement migration

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
