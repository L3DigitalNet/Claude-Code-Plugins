"""Marketplace-wide Zod-strict guard for plugin.json + hooks.json shape."""
import json
from pathlib import Path

import pytest

PLUGIN_ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.unit
def test_plugin_json_zod_strict_allowlist():
    """plugin.json must have only the Zod-strict allowed fields."""
    allowed = {"name", "version", "description", "author", "homepage"}
    keys = set(json.loads((PLUGIN_ROOT / ".claude-plugin" / "plugin.json").read_text()).keys())
    invalid = keys - allowed
    assert not invalid, f"plugin.json has invalid Zod-strict fields: {invalid}"


@pytest.mark.unit
def test_plugin_json_required_fields_present():
    required = {"name", "version", "description"}
    keys = set(json.loads((PLUGIN_ROOT / ".claude-plugin" / "plugin.json").read_text()).keys())
    missing = required - keys
    assert not missing, f"plugin.json missing required fields: {missing}"


@pytest.mark.unit
def test_hooks_json_exists_and_keyed_in_record_form():
    """ha-dev ships a hooks.json (PostToolUse validator dispatcher); confirm shape."""
    hooks_path = PLUGIN_ROOT / "hooks" / "hooks.json"
    assert hooks_path.exists(), "hooks/hooks.json must exist for ha-dev"
    d = json.loads(hooks_path.read_text())
    assert isinstance(d.get("hooks"), dict), "hooks must be a dict (record-keyed by event), not an array"
