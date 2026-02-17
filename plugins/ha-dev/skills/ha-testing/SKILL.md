---
name: ha-testing
description: Write tests for Home Assistant integrations using pytest and the hass fixture. Use when mentioning test, pytest, testing, test coverage, mock, fixture, or preparing an integration for core submission.
---

# Testing Home Assistant Integrations

Tests are **required** for Bronze tier on the Integration Quality Scale. At minimum: config flow tests for success, connection failure, and auth failure.

## Test Structure

```
tests/
├── conftest.py           # Shared fixtures
├── test_config_flow.py   # Config flow tests (REQUIRED)
├── test_init.py          # Setup/unload tests
├── test_sensor.py        # Entity tests
└── test_coordinator.py   # Coordinator tests
```

## conftest.py

```python
"""Fixtures for {Name} tests."""
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
    "serial": "ABC123",
    "name": "Test Device",
    "model": "Model X",
}

MOCK_DATA = {
    "devices": {
        "device_1": {
            "temperature": 22.5,
            "humidity": 45,
        },
    },
}


@pytest.fixture
def mock_client() -> Generator[AsyncMock]:
    with patch("custom_components.{domain}.MyClient", autospec=True) as mock:
        client = mock.return_value
        client.async_get_device_info = AsyncMock(return_value=MOCK_DEVICE_INFO)
        client.async_get_data = AsyncMock(return_value=MOCK_DATA)
        yield client


@pytest.fixture
def mock_setup_entry() -> Generator[AsyncMock]:
    with patch(
        "custom_components.{domain}.async_setup_entry",
        return_value=True,
    ) as mock:
        yield mock
```

## test_config_flow.py (REQUIRED)

```python
"""Test config flow."""
from unittest.mock import AsyncMock

from homeassistant import config_entries
from homeassistant.core import HomeAssistant
from homeassistant.data_entry_flow import FlowResultType

from custom_components.{domain}.const import DOMAIN

from .conftest import MOCK_CONFIG


async def test_user_flow_success(
    hass: HomeAssistant,
    mock_client: AsyncMock,
    mock_setup_entry: AsyncMock,
) -> None:
    """Test successful config flow."""
    result = await hass.config_entries.flow.async_init(
        DOMAIN, context={"source": config_entries.SOURCE_USER}
    )
    assert result["type"] is FlowResultType.FORM
    assert result["errors"] == {}

    result = await hass.config_entries.flow.async_configure(
        result["flow_id"], MOCK_CONFIG
    )
    assert result["type"] is FlowResultType.CREATE_ENTRY
    assert result["title"] == "Test Device"
    assert result["data"] == MOCK_CONFIG


async def test_user_flow_cannot_connect(
    hass: HomeAssistant,
    mock_client: AsyncMock,
    mock_setup_entry: AsyncMock,
) -> None:
    """Test connection failure."""
    mock_client.async_get_device_info.side_effect = ConnectionError

    result = await hass.config_entries.flow.async_init(
        DOMAIN, context={"source": config_entries.SOURCE_USER}
    )
    result = await hass.config_entries.flow.async_configure(
        result["flow_id"], MOCK_CONFIG
    )
    assert result["type"] is FlowResultType.FORM
    assert result["errors"] == {"base": "cannot_connect"}


async def test_user_flow_invalid_auth(
    hass: HomeAssistant,
    mock_client: AsyncMock,
    mock_setup_entry: AsyncMock,
) -> None:
    """Test auth failure."""
    mock_client.async_get_device_info.side_effect = InvalidAuth

    result = await hass.config_entries.flow.async_init(
        DOMAIN, context={"source": config_entries.SOURCE_USER}
    )
    result = await hass.config_entries.flow.async_configure(
        result["flow_id"], MOCK_CONFIG
    )
    assert result["type"] is FlowResultType.FORM
    assert result["errors"] == {"base": "invalid_auth"}
```

## test_init.py

```python
"""Test setup and unload."""
from unittest.mock import AsyncMock

from homeassistant.config_entries import ConfigEntryState
from homeassistant.core import HomeAssistant

from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.{domain}.const import DOMAIN

from .conftest import MOCK_CONFIG


async def test_setup_entry(hass: HomeAssistant, mock_client: AsyncMock) -> None:
    """Test successful setup."""
    entry = MockConfigEntry(domain=DOMAIN, data=MOCK_CONFIG)
    entry.add_to_hass(hass)
    await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()
    assert entry.state is ConfigEntryState.LOADED


async def test_unload_entry(hass: HomeAssistant, mock_client: AsyncMock) -> None:
    """Test successful unload."""
    entry = MockConfigEntry(domain=DOMAIN, data=MOCK_CONFIG)
    entry.add_to_hass(hass)
    await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()
    assert entry.state is ConfigEntryState.LOADED

    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()
    assert entry.state is ConfigEntryState.NOT_LOADED


async def test_setup_entry_not_ready(
    hass: HomeAssistant, mock_client: AsyncMock
) -> None:
    """Test setup fails when cannot connect."""
    mock_client.async_get_data.side_effect = ConnectionError
    
    entry = MockConfigEntry(domain=DOMAIN, data=MOCK_CONFIG)
    entry.add_to_hass(hass)
    await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()
    assert entry.state is ConfigEntryState.SETUP_RETRY
```

## Running Tests

```bash
pip install pytest pytest-homeassistant-custom-component pytest-asyncio

pytest tests/ -v
pytest tests/ --cov=custom_components.{domain} --cov-report=html
```

## Key Rules

1. Config flow tests are **mandatory** for Bronze tier
2. Use `AsyncMock` for all async methods
3. Mock the client, not the coordinator
4. Call `await hass.async_block_till_done()` after setup
5. Assert `FlowResultType` enum values, not strings
