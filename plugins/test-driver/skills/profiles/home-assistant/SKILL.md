---
name: home-assistant
description: >
  Stack profile for Home Assistant custom integrations. Activated when test-driver detects
  manifest.json with a "domain" key and a custom_components/ directory. Defines applicable
  test categories, discovery conventions, execution commands, and coverage tools for HA
  custom components.
---

# Stack Profile: Home Assistant Custom Integration

## 1. Applicable Test Categories

- **Unit** — always applicable
- **Integration** — always applicable (HA's primary test type)
- **E2E** — not applicable (HA testing doesn't run the full HA stack)
- **UI** — not applicable (HA frontend is a separate project)
- **Contract** — not applicable
- **Security** — not applicable

## 2. Test Discovery

- **Location:** `tests/` directory mirroring `custom_components/<integration>/` structure
- **Naming:** files matching `test_*.py`

**Key test files for an HA integration:**

| File | What it tests |
|------|--------------|
| `tests/conftest.py` | Shared fixtures (hass instance, mock config entries) |
| `tests/test_config_flow.py` | Setup wizard steps (success, connection failure, auth failure) |
| `tests/test_init.py` | Integration loading, unloading, and setup |
| `tests/test_sensor.py` | Sensor entity state and attributes |
| `tests/test_coordinator.py` | DataUpdateCoordinator polling and error handling |
| `tests/test_binary_sensor.py` | Binary sensor state |
| `tests/test_switch.py` | Switch on/off behavior |

## 3. Test Execution

```bash
# All tests
pytest tests/

# Single file
pytest tests/test_config_flow.py -v

# Single test
pytest tests/test_config_flow.py::test_form_success -v

# With verbose output for debugging
pytest tests/ -v --tb=long
```

## 4. Coverage Measurement

- **Tool:** coverage.py via pytest-cov
- **Command:** `pytest --cov=custom_components --cov-report=term-missing`
- **Exclude:** `__pycache__`, generated files

## 5. UI Testing

Not applicable. The Home Assistant frontend is a separate JavaScript project. Custom integrations are backend-only Python code.

## Minimum Test Requirements

Per the Home Assistant Integration Quality Scale (IQS):

**Bronze tier (minimum for HACS):**
- Config flow: test success path
- Config flow: test connection failure
- Config flow: test authentication failure

**Silver tier:**
- All Bronze tests plus entity tests
- Coordinator tests (data fetch, error handling)

**Gold tier:**
- All Silver tests plus diagnostics, repair issues
- Full coverage of all entity platforms

## Key Testing Patterns

### hass Fixture

The `hass` fixture provides a running Home Assistant instance for tests:

```python
from homeassistant.core import HomeAssistant

async def test_setup_integration(hass: HomeAssistant):
    """Test that the integration sets up correctly."""
    entry = MockConfigEntry(
        domain="my_integration",
        data={"host": "192.168.1.1", "api_key": "test-key"},
    )
    entry.add_to_hass(hass)
    await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    assert entry.state is ConfigEntryState.LOADED
```

### MockConfigEntry

Create test config entries without going through the config flow:

```python
from homeassistant.config_entries import ConfigEntryState
from tests.common import MockConfigEntry

entry = MockConfigEntry(
    domain="my_integration",
    title="Test Device",
    data={"host": "192.168.1.1"},
    unique_id="test-unique-id",
)
```

### Mocking API Calls

Use `AsyncMock` and `patch` to mock external API calls:

```python
from unittest.mock import AsyncMock, patch

async def test_coordinator_update(hass):
    """Test coordinator fetches data successfully."""
    with patch(
        "custom_components.my_integration.coordinator.MyApiClient.fetch_data",
        new_callable=AsyncMock,
        return_value={"temperature": 22.5},
    ):
        # Set up and trigger update
        await coordinator.async_refresh()
        assert coordinator.data["temperature"] == 22.5
```

### Config Flow Testing

```python
from homeassistant import config_entries
from homeassistant.data_entry_flow import FlowResultType

async def test_form_success(hass):
    """Test successful config flow."""
    result = await hass.config_entries.flow.async_init(
        "my_integration", context={"source": config_entries.SOURCE_USER}
    )
    assert result["type"] is FlowResultType.FORM

    with patch("custom_components.my_integration.config_flow.MyApi.authenticate", return_value=True):
        result = await hass.config_entries.flow.async_configure(
            result["flow_id"],
            {"host": "192.168.1.1", "api_key": "valid-key"},
        )
    assert result["type"] is FlowResultType.CREATE_ENTRY
    assert result["title"] == "My Device"
```

## Delegates To

- `home-assistant-dev:ha-testing` for comprehensive HA test patterns and fixtures
- If not installed, proceed using general pytest and HA documentation knowledge
