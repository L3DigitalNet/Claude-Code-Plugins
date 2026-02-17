"""Fixtures for Example Hub tests."""
from __future__ import annotations

from collections.abc import Generator
from unittest.mock import AsyncMock, patch

import pytest

from homeassistant.const import CONF_HOST, CONF_PASSWORD, CONF_USERNAME

MOCK_CONFIG = {
    CONF_HOST: "192.168.1.100",
    CONF_USERNAME: "admin",
    CONF_PASSWORD: "password",
}

MOCK_DEVICE_INFO = {
    "serial": "EXAMPLE123",
    "name": "Example Hub",
    "model": "Hub Pro",
    "sw_version": "1.2.3",
}

MOCK_DATA = {
    "devices": {
        "device_1": {
            "name": "Living Room Sensor",
            "temperature": 22.5,
            "humidity": 45,
            "online": True,
        },
    },
    "hub_online": True,
}


@pytest.fixture
def mock_setup_entry() -> Generator[AsyncMock]:
    """Mock setup entry."""
    with patch(
        "custom_components.example_hub.async_setup_entry",
        return_value=True,
    ) as mock:
        yield mock
