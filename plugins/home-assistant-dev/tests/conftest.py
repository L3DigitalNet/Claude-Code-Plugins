"""Shared test fixtures for plugin tests."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import pytest

# Add scripts directory to path for imports
PLUGIN_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PLUGIN_ROOT / "scripts"))


@pytest.fixture
def fixtures_dir() -> Path:
    """Return path to fixtures directory."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def valid_manifest(fixtures_dir: Path) -> dict[str, Any]:
    """Load valid manifest fixture."""
    return json.loads((fixtures_dir / "manifests" / "valid_full.json").read_text())


@pytest.fixture
def invalid_manifest(fixtures_dir: Path) -> dict[str, Any]:
    """Load invalid manifest fixture."""
    return json.loads((fixtures_dir / "manifests" / "invalid_missing_fields.json").read_text())


@pytest.fixture
def temp_manifest(tmp_path: Path, valid_manifest: dict[str, Any]):
    """Create a temporary manifest file."""
    def _create(content: dict[str, Any] | None = None, dirname: str = "test_domain"):
        manifest_dir = tmp_path / dirname
        manifest_dir.mkdir(exist_ok=True)
        manifest_path = manifest_dir / "manifest.json"
        manifest_path.write_text(json.dumps(content or valid_manifest, indent=2))
        return manifest_path
    return _create


@pytest.fixture
def temp_strings(tmp_path: Path):
    """Create temporary strings.json and config_flow.py."""
    def _create(strings_content: dict, config_flow_content: str = ""):
        strings_path = tmp_path / "strings.json"
        strings_path.write_text(json.dumps(strings_content, indent=2))
        
        if config_flow_content:
            config_flow_path = tmp_path / "config_flow.py"
            config_flow_path.write_text(config_flow_content)
        
        return strings_path
    return _create


@pytest.fixture
def temp_python(tmp_path: Path):
    """Create a temporary Python file."""
    def _create(content: str, filename: str = "test.py"):
        py_path = tmp_path / filename
        py_path.write_text(content)
        return py_path
    return _create


@pytest.fixture
def example_polling_hub() -> Path:
    """Return path to polling-hub example."""
    return PLUGIN_ROOT / "examples" / "polling-hub" / "custom_components" / "example_hub"


@pytest.fixture
def example_minimal_sensor() -> Path:
    """Return path to minimal-sensor example."""
    return PLUGIN_ROOT / "examples" / "minimal-sensor" / "custom_components" / "minimal_sensor"


@pytest.fixture
def example_push_integration() -> Path:
    """Return path to push-integration example."""
    return PLUGIN_ROOT / "examples" / "push-integration" / "custom_components" / "push_example"
