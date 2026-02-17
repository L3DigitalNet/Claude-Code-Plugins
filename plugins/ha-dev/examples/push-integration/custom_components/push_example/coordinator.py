"""Coordinator for Push Example integration.

Demonstrates push-based updates without DataUpdateCoordinator.
Uses callbacks to notify entities of state changes.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any, Callable

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import CONF_HOST
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_send

from .const import DOMAIN

_LOGGER = logging.getLogger(__name__)

# Signal for push updates
SIGNAL_UPDATE = f"{DOMAIN}_update"


class PushCoordinator:
    """Coordinator that handles push-based updates.

    Unlike DataUpdateCoordinator, this doesn't poll.
    Instead, it maintains a connection and receives pushed updates.
    """

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        """Initialize the coordinator."""
        self.hass = hass
        self.entry = entry
        self._host = entry.data[CONF_HOST]

        # Current state
        self.data: dict[str, Any] = {}
        self.connected = False
        self.device_info: dict[str, Any] = {}

        # Connection management
        self._connection_task: asyncio.Task | None = None
        self._reconnect_interval = 30
        self._should_reconnect = True

    async def async_connect(self) -> None:
        """Establish connection to the device."""
        try:
            # In a real integration, connect to WebSocket/MQTT/etc.
            # self._client = await MyPushClient.connect(self._host)
            # self._client.on_message = self._handle_message

            # Simulated connection
            self.device_info = {
                "serial": "PUSH123",
                "name": "Push Device",
                "model": "Push Pro",
            }
            self.connected = True
            _LOGGER.info("Connected to push device at %s", self._host)

            # Start listening for updates
            self._connection_task = asyncio.create_task(self._listen_loop())

        except Exception as err:
            _LOGGER.error("Failed to connect: %s", err)
            self.connected = False
            # Schedule reconnection
            self._schedule_reconnect()

    async def async_disconnect(self) -> None:
        """Disconnect from the device."""
        self._should_reconnect = False

        if self._connection_task:
            self._connection_task.cancel()
            try:
                await self._connection_task
            except asyncio.CancelledError:
                pass

        # In a real integration: await self._client.disconnect()
        self.connected = False
        _LOGGER.info("Disconnected from push device")

    async def _listen_loop(self) -> None:
        """Listen for pushed updates.

        In a real integration, this would be handled by the client library's
        callback mechanism. This simulates periodic push updates.
        """
        while self._should_reconnect:
            try:
                # Simulate receiving a push update every 10 seconds
                await asyncio.sleep(10)

                if not self.connected:
                    continue

                # Simulated push data
                import random
                self.data = {
                    "temperature": round(20 + random.uniform(-2, 2), 1),
                    "motion": random.choice([True, False]),
                    "last_update": asyncio.get_event_loop().time(),
                }

                # Notify all entities of the update
                self._notify_update()

            except asyncio.CancelledError:
                break
            except Exception as err:
                _LOGGER.error("Connection lost: %s", err)
                self.connected = False
                self._schedule_reconnect()
                break

    @callback
    def _notify_update(self) -> None:
        """Notify entities of new data."""
        async_dispatcher_send(self.hass, SIGNAL_UPDATE)

    def _schedule_reconnect(self) -> None:
        """Schedule a reconnection attempt."""
        if not self._should_reconnect:
            return

        async def reconnect() -> None:
            await asyncio.sleep(self._reconnect_interval)
            if self._should_reconnect and not self.connected:
                _LOGGER.info("Attempting to reconnect...")
                await self.async_connect()

        asyncio.create_task(reconnect())

    @property
    def available(self) -> bool:
        """Return True if connected."""
        return self.connected
