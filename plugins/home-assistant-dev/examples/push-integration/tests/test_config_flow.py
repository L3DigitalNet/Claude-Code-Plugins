"""Test config flow for Push Example integration."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

from homeassistant import config_entries
from homeassistant.const import CONF_HOST
from homeassistant.core import HomeAssistant
from homeassistant.data_entry_flow import FlowResultType

from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.push_example.binary_sensor import PushMotionBinarySensor
from custom_components.push_example.const import DOMAIN
from custom_components.push_example.coordinator import PushCoordinator

from .conftest import MOCK_CONFIG


async def test_user_flow_success(
    hass: HomeAssistant,
) -> None:
    """Test successful user setup flow."""
    with patch(
        "custom_components.push_example.async_setup_entry",
        return_value=True,
    ):
        result = await hass.config_entries.flow.async_init(
            DOMAIN, context={"source": config_entries.SOURCE_USER}
        )
        assert result["type"] is FlowResultType.FORM
        assert result["step_id"] == "user"
        assert result["errors"] == {}

        result = await hass.config_entries.flow.async_configure(
            result["flow_id"], MOCK_CONFIG
        )

    assert result["type"] is FlowResultType.CREATE_ENTRY
    assert result["data"] == MOCK_CONFIG


async def test_user_flow_duplicate(
    hass: HomeAssistant,
) -> None:
    """Test that duplicate entries are aborted."""
    with patch(
        "custom_components.push_example.async_setup_entry",
        return_value=True,
    ):
        # First entry
        result = await hass.config_entries.flow.async_init(
            DOMAIN, context={"source": config_entries.SOURCE_USER}
        )
        await hass.config_entries.flow.async_configure(
            result["flow_id"], MOCK_CONFIG
        )

        # Second entry with same host — should abort
        result = await hass.config_entries.flow.async_init(
            DOMAIN, context={"source": config_entries.SOURCE_USER}
        )
        result = await hass.config_entries.flow.async_configure(
            result["flow_id"], MOCK_CONFIG
        )

    assert result["type"] is FlowResultType.ABORT
    assert result["reason"] == "already_configured"


async def test_reauth_flow(
    hass: HomeAssistant,
) -> None:
    """Test reauthentication flow (Silver IQS: reauthentication-flow)."""
    with patch(
        "custom_components.push_example.async_setup_entry",
        return_value=True,
    ):
        # Create initial entry
        result = await hass.config_entries.flow.async_init(
            DOMAIN, context={"source": config_entries.SOURCE_USER}
        )
        await hass.config_entries.flow.async_configure(
            result["flow_id"], MOCK_CONFIG
        )

    # Get the created entry
    entries = hass.config_entries.async_entries(DOMAIN)
    assert len(entries) == 1
    entry = entries[0]

    # Initiate reauth
    result = await hass.config_entries.flow.async_init(
        DOMAIN,
        context={"source": config_entries.SOURCE_REAUTH, "entry_id": entry.entry_id},
        data=entry.data,
    )
    assert result["type"] is FlowResultType.FORM
    assert result["step_id"] == "reauth_confirm"

    # Submit the reauth form with a new host and verify it completes end-to-end:
    # async_update_reload_and_abort returns ABORT/reauth_successful and writes the
    # new value into the existing entry's data (no second entry is created).
    new_config = {CONF_HOST: "192.168.1.99"}
    with patch(
        "custom_components.push_example.async_setup_entry",
        return_value=True,
    ):
        result = await hass.config_entries.flow.async_configure(
            result["flow_id"], new_config
        )
        await hass.async_block_till_done()

    assert result["type"] is FlowResultType.ABORT
    assert result["reason"] == "reauth_successful"

    entries = hass.config_entries.async_entries(DOMAIN)
    assert len(entries) == 1
    assert entries[0].data[CONF_HOST] == new_config[CONF_HOST]


async def test_coordinator_push_update_notifies_entity(
    hass: HomeAssistant,
) -> None:
    """Test the push/dispatcher path: a coordinator update writes entity state.

    This exercises the pattern the example teaches end-to-end — an entity
    subscribes to SIGNAL_UPDATE in async_added_to_hass, and the coordinator's
    dispatcher send must drive async_write_ha_state on that entity.
    """
    entry = MockConfigEntry(domain=DOMAIN, data=MOCK_CONFIG, unique_id="192.168.1.50")
    entry.add_to_hass(hass)

    coordinator = PushCoordinator(hass, entry)
    await coordinator.async_connect()
    assert coordinator.connected is True

    # Build a real entity and subscribe it to the dispatcher signal exactly as
    # production does (via async_added_to_hass), then assert the signal drives a
    # state write. Patch async_write_ha_state so we observe the call without
    # needing a fully registered entity_id/platform.
    entity = PushMotionBinarySensor(coordinator, entry)
    entity.hass = hass
    entity.async_write_ha_state = MagicMock()
    await entity.async_added_to_hass()

    coordinator._notify_update()
    await hass.async_block_till_done()

    entity.async_write_ha_state.assert_called_once()

    await coordinator.async_disconnect()
