"""Config flow for Minimal Sensor integration."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.config_entries import ConfigFlow, ConfigFlowResult
from homeassistant.const import CONF_NAME

DOMAIN = "minimal_sensor"


class MinimalSensorConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handle a config flow for Minimal Sensor."""

    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Handle the initial step."""
        if user_input is not None:
            # Set unique ID to prevent duplicates
            await self.async_set_unique_id(user_input[CONF_NAME].lower())
            self._abort_if_unique_id_configured()

            return self.async_create_entry(
                title=user_input[CONF_NAME],
                data=user_input,
            )

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema({
                vol.Required(CONF_NAME, default="My Sensor"): str,
            }),
        )
