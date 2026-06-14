"""Switch platform for Example Hub.

Demonstrates:
- SwitchEntity with a translation key
- Reading on/off state from coordinator data
- Control that refreshes the coordinator after acting on the device
"""
from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import ExampleHubConfigEntry
from .coordinator import ExampleHubCoordinator
from .entity import ExampleHubEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ExampleHubConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up switch platform."""
    coordinator = entry.runtime_data

    # Only create a switch for devices that expose a controllable state
    entities: list[ExampleHubSwitch] = [
        ExampleHubSwitch(coordinator, device_id)
        for device_id, device_data in coordinator.devices.items()
        if "state" in device_data
    ]

    async_add_entities(entities)


class ExampleHubSwitch(ExampleHubEntity, SwitchEntity):
    """Switch for Example Hub."""

    _attr_translation_key = "power"

    def __init__(
        self,
        coordinator: ExampleHubCoordinator,
        device_id: str,
    ) -> None:
        """Initialize the switch."""
        super().__init__(coordinator, device_id)
        self._attr_unique_id = f"{self._attr_unique_id}_power"

    @property
    def is_on(self) -> bool | None:
        """Return True if the switch is on."""
        device_data = self.coordinator.devices.get(self._device_id, {})
        return device_data.get("state")

    async def async_turn_on(self, **kwargs: Any) -> None:
        """Turn the switch on."""
        await self._async_set_state(True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        """Turn the switch off."""
        await self._async_set_state(False)

    async def _async_set_state(self, state: bool) -> None:
        """Set device state, then refresh so the new value is reflected."""
        # In a real integration, call your client library here:
        # await self.coordinator.client.async_set_state(self._device_id, state)
        await self.coordinator.async_request_refresh()
