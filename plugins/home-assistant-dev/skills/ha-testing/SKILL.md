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

## Core Setup

```bash
pip install pytest pytest-homeassistant-custom-component pytest-asyncio

pytest tests/ -v
pytest tests/ --cov=custom_components.{domain} --cov-report=html
```

**conftest.py and test_config_flow.py templates** — see [references/test-templates.md](references/test-templates.md)

**test_init.py (setup/unload patterns)** — see [references/test-patterns.md](references/test-patterns.md)

## Key Rules

1. Config flow tests are **mandatory** for Bronze tier
2. Use `AsyncMock` for all async methods
3. Mock the client, not the coordinator
4. Call `await hass.async_block_till_done()` after setup
5. Assert `FlowResultType` enum values, not strings
