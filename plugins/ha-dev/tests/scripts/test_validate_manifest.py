"""Unit tests for validate-manifest.py script."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

PLUGIN_ROOT = Path(__file__).parent.parent.parent
SCRIPT_PATH = PLUGIN_ROOT / "scripts" / "validate-manifest.py"


def run_validator(manifest_path: Path, is_custom: bool = True) -> tuple[int, str, str]:
    """Run the validate-manifest.py script and return (returncode, stdout, stderr)."""
    args = ["python3", str(SCRIPT_PATH), str(manifest_path)]
    if not is_custom:
        args.append("--core")
    
    result = subprocess.run(args, capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr


class TestValidateManifest:
    """Tests for manifest validation."""

    @pytest.mark.unit
    def test_valid_hacs_manifest(self, tmp_path, valid_manifest):
        """Valid HACS manifest passes all checks."""
        # Create proper integration structure
        manifest_dir = tmp_path / "test_integration"
        manifest_dir.mkdir()
        manifest_path = manifest_dir / "manifest.json"
        manifest_path.write_text(json.dumps(valid_manifest, indent=2))
        
        # Create config_flow.py since manifest has config_flow: true
        (manifest_dir / "config_flow.py").write_text("# config flow placeholder")
        
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        # Should pass (returncode 0) or only have warnings
        assert "ERROR" not in stdout, f"Unexpected errors: {stdout}"

    @pytest.mark.unit
    def test_missing_required_field(self, temp_manifest):
        """Missing required field produces error."""
        incomplete = {"domain": "test", "name": "Test"}
        manifest_path = temp_manifest(incomplete)
        
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        # Should report missing fields
        assert "missing" in stdout.lower() or "required" in stdout.lower() or returncode != 0

    @pytest.mark.unit
    def test_invalid_iot_class(self, temp_manifest, valid_manifest):
        """Invalid iot_class produces error."""
        valid_manifest["iot_class"] = "invalid_class"
        manifest_path = temp_manifest(valid_manifest)
        
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        assert "iot_class" in stdout.lower() or "invalid" in stdout.lower()

    @pytest.mark.unit
    def test_invalid_semver_version(self, temp_manifest, valid_manifest):
        """Invalid version format produces error."""
        valid_manifest["version"] = "1.0"  # Missing patch
        manifest_path = temp_manifest(valid_manifest)
        
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        assert "version" in stdout.lower()

    @pytest.mark.unit
    def test_codeowner_without_at(self, temp_manifest, valid_manifest):
        """Codeowner without @ prefix produces error."""
        valid_manifest["codeowners"] = ["missing_at_sign"]
        manifest_path = temp_manifest(valid_manifest)
        
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        assert "@" in stdout or "codeowner" in stdout.lower()

    @pytest.mark.unit
    def test_nonexistent_file(self, tmp_path):
        """Nonexistent file produces error."""
        fake_path = tmp_path / "nonexistent" / "manifest.json"
        
        returncode, stdout, stderr = run_validator(fake_path, is_custom=True)
        
        assert returncode != 0 or "not found" in stdout.lower() or "error" in stderr.lower()


class TestValidateManifestExamples:
    """Test validation against actual example integrations."""

    @pytest.mark.unit
    def test_polling_hub_manifest(self, example_polling_hub):
        """polling-hub example manifest should be valid."""
        manifest_path = example_polling_hub / "manifest.json"
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        assert "ERROR" not in stdout, f"polling-hub has errors: {stdout}"

    @pytest.mark.unit
    def test_minimal_sensor_manifest(self, example_minimal_sensor):
        """minimal-sensor example manifest should be valid."""
        manifest_path = example_minimal_sensor / "manifest.json"
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        assert "ERROR" not in stdout, f"minimal-sensor has errors: {stdout}"

    @pytest.mark.unit
    def test_push_integration_manifest(self, example_push_integration):
        """push-integration example manifest should be valid."""
        manifest_path = example_push_integration / "manifest.json"
        returncode, stdout, stderr = run_validator(manifest_path, is_custom=True)
        
        assert "ERROR" not in stdout, f"push-integration has errors: {stdout}"
