"""Fixtures for Push Example tests."""
from __future__ import annotations

from collections.abc import Generator
from unittest.mock import AsyncMock, patch

import pytest

from homeassistant.const import CONF_HOST

MOCK_CONFIG = {
    CONF_HOST: "192.168.1.50",
}
