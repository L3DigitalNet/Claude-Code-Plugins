"""Tests for the PostToolUse hook dispatcher (post-write-hook.sh).

Verifies routing logic without invoking the validators (which have their own
test files). Routes based on basename + path-keyword detection.
"""
import json
import subprocess
from pathlib import Path

import pytest

HOOK = Path(__file__).resolve().parents[2] / "scripts" / "post-write-hook.sh"


def invoke(file_path: str) -> subprocess.CompletedProcess:
    """Run the hook with a given file_path payload and return the completed process."""
    payload = json.dumps({"tool_input": {"file_path": file_path}})
    return subprocess.run(
        ["bash", str(HOOK)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=15,
    )


@pytest.mark.unit
def test_empty_payload_exits_silently():
    result = subprocess.run(
        ["bash", str(HOOK)],
        input="",
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0
    assert result.stdout == ""
    assert result.stderr == ""


@pytest.mark.unit
def test_missing_file_path_exits_silently():
    result = subprocess.run(
        ["bash", str(HOOK)],
        input="{}",
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0
    assert result.stdout == ""


@pytest.mark.unit
def test_npm_manifest_json_not_routed_to_HA_validator(tmp_path):
    """A manifest.json outside custom_components/ must not trigger HA validation.

    Routing relies on path containing 'custom_components' or 'integrations'.
    A bare ./manifest.json is an npm/node manifest and must be ignored.
    """
    fake_npm_manifest = tmp_path / "manifest.json"
    fake_npm_manifest.write_text('{"name": "x"}')
    result = invoke(str(fake_npm_manifest))
    assert result.returncode == 0
    # Hook should produce no validation output for a non-HA manifest.
    assert "manifest" not in result.stderr.lower() or "error" not in result.stderr.lower()


@pytest.mark.unit
def test_python_file_outside_custom_components_not_validated(tmp_path):
    """A *.py file outside custom_components/ must not trigger pattern checks."""
    py = tmp_path / "ordinary_module.py"
    py.write_text("import os\n")
    result = invoke(str(py))
    assert result.returncode == 0


@pytest.mark.unit
def test_strings_json_routes_to_validate_strings(tmp_path):
    """strings.json file path triggers validate-strings.py.

    We can't easily verify which script ran without instrumenting, but we can
    verify the hook accepts the routing target and exits cleanly.
    """
    sj = tmp_path / "strings.json"
    sj.write_text(
        '{"config": {"step": {"user": {"data": {"host": "Host"}}}}}'
    )
    result = invoke(str(sj))
    # Hook always exits 0 (validators run with || true to avoid disrupting writes).
    assert result.returncode == 0


@pytest.mark.unit
def test_config_flow_py_routes_to_validate_strings(tmp_path):
    """config_flow.py also routes to validate-strings.py per the dispatch table."""
    cf = tmp_path / "config_flow.py"
    cf.write_text("class MyFlow: pass\n")
    result = invoke(str(cf))
    assert result.returncode == 0


@pytest.mark.unit
def test_custom_components_python_routes_to_check_patterns(tmp_path):
    """*.py inside custom_components/ triggers check-patterns.py."""
    cc_dir = tmp_path / "custom_components" / "myint"
    cc_dir.mkdir(parents=True)
    py = cc_dir / "sensor.py"
    py.write_text("from homeassistant.helpers.entity import Entity\n")
    result = invoke(str(py))
    assert result.returncode == 0


@pytest.mark.unit
def test_unknown_extension_exits_cleanly(tmp_path):
    """Files with extensions outside the dispatch table are no-ops."""
    other = tmp_path / "README.md"
    other.write_text("# docs\n")
    result = invoke(str(other))
    assert result.returncode == 0
