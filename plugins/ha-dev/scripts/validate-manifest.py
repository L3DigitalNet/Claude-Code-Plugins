#!/usr/bin/env python3
"""Validate Home Assistant integration manifest.json.

Checks for:
- Required fields for Core and HACS
- Valid integration_type values
- Valid iot_class values
- Version format
- Domain naming conventions
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

# Required fields for Home Assistant Core
CORE_REQUIRED = {
    "domain",
    "name",
    "codeowners",
    "documentation",
    "integration_type",
    "iot_class",
}

# Additional required fields for custom integrations (HACS)
HACS_REQUIRED = CORE_REQUIRED | {"version", "issue_tracker"}

VALID_INTEGRATION_TYPES = {
    "device",
    "entity",
    "hardware",
    "helper",
    "hub",
    "service",
    "system",
    "virtual",
}

VALID_IOT_CLASSES = {
    "assumed_state",
    "cloud_polling",
    "cloud_push",
    "local_polling",
    "local_push",
    "calculated",
}

# Semantic version pattern
SEMVER_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?"
    r"(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"
)

# Domain naming pattern
DOMAIN_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


class ValidationError:
    """Represents a validation error."""

    def __init__(self, field: str, message: str, severity: str = "error") -> None:
        self.field = field
        self.message = message
        self.severity = severity  # "error" or "warning"

    def __str__(self) -> str:
        return f"[{self.severity.upper()}] {self.field}: {self.message}"


def validate_manifest(manifest_path: Path, is_custom: bool = True) -> list[ValidationError]:
    """Validate a manifest.json file.

    Args:
        manifest_path: Path to manifest.json
        is_custom: True for custom integrations (HACS), False for core

    Returns:
        List of validation errors
    """
    errors: list[ValidationError] = []

    # Check file exists
    if not manifest_path.exists():
        errors.append(ValidationError("file", f"manifest.json not found at {manifest_path}"))
        return errors

    # Parse JSON
    try:
        with open(manifest_path) as f:
            manifest: dict[str, Any] = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(ValidationError("json", f"Invalid JSON: {e}"))
        return errors

    # Check required fields
    required = HACS_REQUIRED if is_custom else CORE_REQUIRED
    for field in required:
        if field not in manifest:
            errors.append(ValidationError(field, f"Missing required field '{field}'"))

    # Validate domain
    if "domain" in manifest:
        domain = manifest["domain"]
        if not DOMAIN_PATTERN.match(domain):
            errors.append(
                ValidationError(
                    "domain",
                    f"Invalid domain '{domain}'. Must be lowercase with underscores only.",
                )
            )

        # Check domain matches directory name
        expected_dir = manifest_path.parent.name
        if domain != expected_dir:
            errors.append(
                ValidationError(
                    "domain",
                    f"Domain '{domain}' does not match directory name '{expected_dir}'",
                )
            )

    # Validate integration_type
    if "integration_type" in manifest:
        int_type = manifest["integration_type"]
        if int_type not in VALID_INTEGRATION_TYPES:
            errors.append(
                ValidationError(
                    "integration_type",
                    f"Invalid integration_type '{int_type}'. "
                    f"Must be one of: {', '.join(sorted(VALID_INTEGRATION_TYPES))}",
                )
            )

    # Validate iot_class
    if "iot_class" in manifest:
        iot_class = manifest["iot_class"]
        if iot_class not in VALID_IOT_CLASSES:
            errors.append(
                ValidationError(
                    "iot_class",
                    f"Invalid iot_class '{iot_class}'. "
                    f"Must be one of: {', '.join(sorted(VALID_IOT_CLASSES))}",
                )
            )

    # Validate version format (for custom integrations)
    if is_custom and "version" in manifest:
        version = manifest["version"]
        if not SEMVER_PATTERN.match(version):
            errors.append(
                ValidationError(
                    "version",
                    f"Invalid version format '{version}'. Must be valid semver (e.g., 1.0.0)",
                )
            )

    # Validate codeowners format
    if "codeowners" in manifest:
        codeowners = manifest["codeowners"]
        if not isinstance(codeowners, list):
            errors.append(ValidationError("codeowners", "Must be a list"))
        elif len(codeowners) == 0:
            errors.append(
                ValidationError("codeowners", "Must have at least one codeowner", "warning")
            )
        else:
            for owner in codeowners:
                if not owner.startswith("@"):
                    errors.append(
                        ValidationError(
                            "codeowners",
                            f"Codeowner '{owner}' must start with '@'",
                        )
                    )

    # Check config_flow
    if manifest.get("config_flow") is True:
        config_flow_path = manifest_path.parent / "config_flow.py"
        if not config_flow_path.exists():
            errors.append(
                ValidationError(
                    "config_flow",
                    "config_flow is true but config_flow.py not found",
                )
            )

    # Validate URLs
    for url_field in ["documentation", "issue_tracker"]:
        if url_field in manifest:
            url = manifest[url_field]
            if not url.startswith(("http://", "https://")):
                errors.append(
                    ValidationError(url_field, f"Invalid URL format: {url}")
                )

    # Check for deprecated patterns (warnings)
    if manifest.get("config_flow") is None and manifest.get("integration_type") != "virtual":
        errors.append(
            ValidationError(
                "config_flow",
                "Config flow is not enabled. New integrations require config_flow: true",
                "warning",
            )
        )

    return errors


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 2:
        # Try to find manifest.json in current directory or custom_components
        search_paths = [
            Path("manifest.json"),
            Path("custom_components") / "*" / "manifest.json",
        ]
        manifest_path = None
        for pattern in search_paths:
            matches = list(Path(".").glob(str(pattern)))
            if matches:
                manifest_path = matches[0]
                break

        if manifest_path is None:
            print("Usage: validate-manifest.py <path/to/manifest.json>")
            print("       validate-manifest.py --core <path/to/manifest.json>")
            return 1
    else:
        is_custom = "--core" not in sys.argv
        manifest_path = Path(sys.argv[-1])

    is_custom = "--core" not in sys.argv

    print(f"Validating: {manifest_path}")
    print(f"Mode: {'Custom Integration (HACS)' if is_custom else 'Core Integration'}")
    print()

    errors = validate_manifest(manifest_path, is_custom)

    if not errors:
        print("✅ manifest.json is valid!")
        return 0

    error_count = sum(1 for e in errors if e.severity == "error")
    warning_count = sum(1 for e in errors if e.severity == "warning")

    for error in errors:
        print(error)

    print()
    if error_count > 0:
        print(f"❌ {error_count} error(s), {warning_count} warning(s)")
        return 1
    else:
        print(f"⚠️  {warning_count} warning(s)")
        return 0


if __name__ == "__main__":
    sys.exit(main())
