"""Config flow for Example Hub integration.

Demonstrates:
- User setup flow
- Reauth flow with _get_reauth_entry()
- Reconfigure flow
- Options flow (without __init__)
- Proper error handling
- Unique ID management
"""
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

from .const import DEFAULT_SCAN_INTERVAL, DOMAIN

_LOGGER = logging.getLogger(__name__)

STEP_USER_DATA_SCHEMA = vol.Schema(
    {
        vol.Required(CONF_HOST): str,
        vol.Required(CONF_USERNAME): str,
        vol.Required(CONF_PASSWORD): str,
    }
)


class ExampleHubConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handle a config flow for Example Hub."""

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
                # Set unique ID to prevent duplicate entries
                await self.async_set_unique_id(info["unique_id"])
                self._abort_if_unique_id_configured()

                return self.async_create_entry(title=info["title"], data=user_input)

        return self.async_show_form(
            step_id="user",
            data_schema=STEP_USER_DATA_SCHEMA,
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
        """Confirm reauth with new credentials."""
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
            data_schema=vol.Schema(
                {
                    vol.Required(CONF_USERNAME): str,
                    vol.Required(CONF_PASSWORD): str,
                }
            ),
            errors=errors,
        )

    async def async_step_reconfigure(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Handle reconfiguration."""
        errors: dict[str, str] = {}
        reconfigure_entry = self._get_reconfigure_entry()

        if user_input is not None:
            data = {**reconfigure_entry.data, **user_input}

            try:
                await self._async_validate_input(data)
            except CannotConnect:
                errors["base"] = "cannot_connect"
            except InvalidAuth:
                errors["base"] = "invalid_auth"
            else:
                return self.async_update_reload_and_abort(reconfigure_entry, data=data)

        return self.async_show_form(
            step_id="reconfigure",
            data_schema=vol.Schema(
                {
                    vol.Required(
                        CONF_HOST, default=reconfigure_entry.data.get(CONF_HOST)
                    ): str,
                }
            ),
            errors=errors,
        )

    async def _async_validate_input(self, data: dict[str, Any]) -> dict[str, Any]:
        """Validate credentials and return device info."""
        # In a real integration, connect to the device here
        # client = MyClient(data[CONF_HOST], data[CONF_USERNAME], data[CONF_PASSWORD])
        # device_info = await client.async_get_info()

        # Simulated validation
        if data[CONF_HOST] == "fail":
            raise CannotConnect
        if data[CONF_PASSWORD] == "wrong":
            raise InvalidAuth

        # Return info for entry creation
        return {
            "title": f"Example Hub ({data[CONF_HOST]})",
            "unique_id": f"example_hub_{data[CONF_HOST]}",
        }

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        """Get the options flow handler."""
        return ExampleHubOptionsFlow()


class ExampleHubOptionsFlow(OptionsFlow):
    """Handle options flow.

    Note: Do NOT implement __init__ - self.config_entry is automatically available.
    """

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Handle options."""
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Optional(
                        "scan_interval",
                        default=self.config_entry.options.get(
                            "scan_interval", DEFAULT_SCAN_INTERVAL
                        ),
                    ): vol.All(vol.Coerce(int), vol.Range(min=10, max=300)),
                }
            ),
        )


class CannotConnect(Exception):
    """Error indicating connection failure."""


class InvalidAuth(Exception):
    """Error indicating invalid credentials."""
