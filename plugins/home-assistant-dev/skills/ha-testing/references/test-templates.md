# Test File Templates

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

## test_config_flow.py (REQUIRED for Bronze)

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
