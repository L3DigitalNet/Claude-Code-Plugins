"""Unit tests for check-patterns.py script."""
from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

PLUGIN_ROOT = Path(__file__).parent.parent.parent
SCRIPT_PATH = PLUGIN_ROOT / "scripts" / "check-patterns.py"


def run_checker(path: Path) -> tuple[int, str, str]:
    """Run the check-patterns.py script and return (returncode, stdout, stderr)."""
    result = subprocess.run(
        ["python3", str(SCRIPT_PATH), str(path)],
        capture_output=True,
        text=True
    )
    return result.returncode, result.stdout, result.stderr


class TestCheckPatterns:
    """Tests for anti-pattern detection."""

    @pytest.mark.unit
    def test_detects_hass_data_domain(self, temp_python):
        """Detects deprecated hass.data[DOMAIN] usage."""
        py_file = temp_python('coordinator = hass.data[DOMAIN][entry.entry_id]')
        
        returncode, stdout, stderr = run_checker(py_file)
        
        assert "runtime_data" in stdout.lower() or "hass.data" in stdout

    @pytest.mark.unit
    def test_detects_blocking_requests_get(self, temp_python):
        """Detects blocking requests.get call."""
        py_file = temp_python('response = requests.get(url)')
        
        returncode, stdout, stderr = run_checker(py_file)
        
        assert "aiohttp" in stdout.lower() or "requests" in stdout

    @pytest.mark.unit
    def test_detects_time_sleep(self, temp_python):
        """Detects blocking time.sleep call."""
        py_file = temp_python('time.sleep(5)')
        
        returncode, stdout, stderr = run_checker(py_file)
        
        assert "asyncio" in stdout.lower() or "sleep" in stdout

    @pytest.mark.unit
    def test_detects_old_zeroconf_import(self, temp_python):
        """Detects deprecated zeroconf ServiceInfo import."""
        py_file = temp_python(
            'from homeassistant.components.zeroconf import ZeroconfServiceInfo'
        )
        
        returncode, stdout, stderr = run_checker(py_file)
        
        assert "2025" in stdout or "ServiceInfo" in stdout or "zeroconf" in stdout.lower()

    @pytest.mark.unit
    def test_detects_typing_list(self, temp_python):
        """Detects deprecated List[] syntax."""
        py_file = temp_python('def foo(items: List[str]) -> None: pass')
        
        returncode, stdout, stderr = run_checker(py_file)
        
        assert "list" in stdout.lower() or "List" in stdout

    @pytest.mark.unit
    def test_detects_typing_optional(self, temp_python):
        """Detects deprecated Optional[] syntax."""
        py_file = temp_python('def foo(value: Optional[str] = None): pass')
        
        returncode, stdout, stderr = run_checker(py_file)
        
        assert "None" in stdout or "Optional" in stdout

    @pytest.mark.unit
    def test_clean_code_no_issues(self, temp_python):
        """Clean modern code has no error-level issues."""
        py_file = temp_python('''
from __future__ import annotations

async def async_setup():
    pass
''')
        
        returncode, stdout, stderr = run_checker(py_file)
        
        # Should not have ERROR level issues
        assert "ERROR" not in stdout or returncode == 0


class TestCheckPatternsExamples:
    """Test pattern checking against actual example integrations."""

    @pytest.mark.unit
    def test_polling_hub_clean(self, example_polling_hub):
        """polling-hub example should have no errors."""
        returncode, stdout, stderr = run_checker(example_polling_hub)
        
        # May have warnings but should not have blocking errors
        error_lines = [line for line in stdout.split('\n') if 'ERROR' in line and 'blocking' in line.lower()]
        assert len(error_lines) == 0, f"polling-hub has blocking errors: {error_lines}"

    @pytest.mark.unit
    def test_minimal_sensor_clean(self, example_minimal_sensor):
        """minimal-sensor example should have no errors."""
        returncode, stdout, stderr = run_checker(example_minimal_sensor)
        
        error_lines = [line for line in stdout.split('\n') if 'ERROR' in line and 'blocking' in line.lower()]
        assert len(error_lines) == 0, f"minimal-sensor has blocking errors: {error_lines}"

    @pytest.mark.unit
    def test_push_integration_clean(self, example_push_integration):
        """push-integration example should have no errors."""
        returncode, stdout, stderr = run_checker(example_push_integration)
        
        error_lines = [line for line in stdout.split('\n') if 'ERROR' in line and 'blocking' in line.lower()]
        assert len(error_lines) == 0, f"push-integration has blocking errors: {error_lines}"
