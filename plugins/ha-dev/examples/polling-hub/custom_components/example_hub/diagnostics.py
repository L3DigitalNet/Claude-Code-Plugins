"""Diagnostics support for Example Hub.

Gold tier requirement - provides structured debug information
while protecting sensitive data.
"""
from __future__ import annotations

from typing import Any

from homeassistant.components.diagnostics import async_redact_data
from homeassistant.core import HomeAssistant

from . import ExampleHubConfigEntry

# Keys to redact from diagnostics output
TO_REDACT = {
    "password",
    "username",
    "token",
    "api_key",
    "serial",
    "unique_id",
}


async def async_get_config_entry_diagnostics(
    hass: HomeAssistant,
    entry: ExampleHubConfigEntry,
) -> dict[str, Any]:
    """Return diagnostics for a config entry."""
    coordinator = entry.runtime_data

    return {
        "config_entry": {
            "entry_id": entry.entry_id,
            "version": entry.version,
            "domain": entry.domain,
            "title": entry.title,
            "data": async_redact_data(dict(entry.data), TO_REDACT),
            "options": async_redact_data(dict(entry.options), TO_REDACT),
        },
        "coordinator": {
            "last_update_success": coordinator.last_update_success,
            "last_exception": (
                str(coordinator.last_exception)
                if coordinator.last_exception
                else None
            ),
            "update_interval": str(coordinator.update_interval),
        },
        "device_info": async_redact_data(coordinator.device_info, TO_REDACT),
        "devices": {
            device_id: async_redact_data(data, TO_REDACT)
            for device_id, data in coordinator.devices.items()
        },
    }
