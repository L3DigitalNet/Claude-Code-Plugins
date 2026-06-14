"""Fixtures for Push Example tests."""
from __future__ import annotations

import pytest

from homeassistant.const import CONF_HOST


@pytest.fixture(autouse=True)
def auto_enable_custom_integrations(enable_custom_integrations):
    """Load custom_components during tests (fixture provided by PHCC)."""
    yield


MOCK_CONFIG = {
    CONF_HOST: "192.168.1.50",
}
