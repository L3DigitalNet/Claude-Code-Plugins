"""Pytest configuration for linux-sysadmin-mcp tests."""

import pytest


def pytest_configure(config: pytest.Config) -> None:
    """Register custom markers."""
    config.addinivalue_line("markers", "unit: Layer 1 structural validation tests")
