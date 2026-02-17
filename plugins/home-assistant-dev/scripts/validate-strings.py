#!/usr/bin/env python3
"""Validate Home Assistant integration strings.json.

Checks for:
- Sync between config_flow.py steps and strings.json
- Required error keys
- Required abort keys
- Proper structure
"""
from __future__ import annotations

import ast
import json
import re
import sys
from pathlib import Path
from typing import Any

# Common error keys that should be present
COMMON_ERRORS = {"cannot_connect", "invalid_auth", "unknown"}

# Common abort reasons
COMMON_ABORTS = {"already_configured"}


class ValidationError:
    """Represents a validation error."""

    def __init__(self, field: str, message: str, severity: str = "error") -> None:
        self.field = field
        self.message = message
        self.severity = severity

    def __str__(self) -> str:
        return f"[{self.severity.upper()}] {self.field}: {self.message}"


def extract_flow_steps(config_flow_path: Path) -> tuple[set[str], set[str], set[str]]:
    """Extract step names, error keys, and abort reasons from config_flow.py.

    Returns:
        Tuple of (step_names, error_keys, abort_reasons)
    """
    steps: set[str] = set()
    errors: set[str] = set()
    aborts: set[str] = set()

    if not config_flow_path.exists():
        return steps, errors, aborts

    content = config_flow_path.read_text()

    # Find async_step_* methods
    step_pattern = re.compile(r"async def async_step_(\w+)\s*\(")
    for match in step_pattern.finditer(content):
        steps.add(match.group(1))

    # Find error assignments: errors["base"] = "cannot_connect"
    error_pattern = re.compile(r'errors\s*\[\s*["\'](\w+)["\']\s*\]\s*=\s*["\'](\w+)["\']')
    for match in error_pattern.finditer(content):
        errors.add(match.group(2))

    # Find abort calls: self.async_abort(reason="already_configured")
    abort_pattern = re.compile(r'async_abort\s*\(\s*reason\s*=\s*["\'](\w+)["\']')
    for match in abort_pattern.finditer(content):
        aborts.add(match.group(1))

    # Also check for _abort_if_unique_id_configured which uses "already_configured"
    if "_abort_if_unique_id_configured" in content:
        aborts.add("already_configured")

    return steps, errors, aborts


def validate_strings(
    strings_path: Path, config_flow_path: Path | None = None
) -> list[ValidationError]:
    """Validate strings.json file.

    Args:
        strings_path: Path to strings.json
        config_flow_path: Optional path to config_flow.py for sync checking

    Returns:
        List of validation errors
    """
    errors: list[ValidationError] = []

    # Check file exists
    if not strings_path.exists():
        errors.append(ValidationError("file", "strings.json not found"))
        return errors

    # Parse JSON
    try:
        with open(strings_path) as f:
            strings: dict[str, Any] = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(ValidationError("json", f"Invalid JSON: {e}"))
        return errors

    # Check basic structure
    if "config" not in strings:
        errors.append(ValidationError("config", "Missing 'config' section"))
        return errors

    config = strings.get("config", {})

    # Check for step section
    if "step" not in config:
        errors.append(ValidationError("config.step", "Missing 'step' section"))

    # Check for error section
    if "error" not in config:
        errors.append(
            ValidationError("config.error", "Missing 'error' section", "warning")
        )

    # Check for abort section
    if "abort" not in config:
        errors.append(
            ValidationError("config.abort", "Missing 'abort' section", "warning")
        )

    # If we have config_flow.py, check sync
    if config_flow_path and config_flow_path.exists():
        flow_steps, flow_errors, flow_aborts = extract_flow_steps(config_flow_path)
        string_steps = set(config.get("step", {}).keys())
        string_errors = set(config.get("error", {}).keys())
        string_aborts = set(config.get("abort", {}).keys())

        # Check for missing step strings
        # Exclude common internal steps that don't need strings
        internal_steps = {"reauth", "reauth_confirm", "reconfigure", "reconfigure_confirm"}
        for step in flow_steps:
            if step not in string_steps and step not in internal_steps:
                # Check if it might be using a different naming
                if step not in internal_steps:
                    errors.append(
                        ValidationError(
                            f"config.step.{step}",
                            f"Step '{step}' in config_flow.py but not in strings.json",
                            "warning",
                        )
                    )

        # Check for orphaned step strings
        for step in string_steps:
            if step not in flow_steps:
                errors.append(
                    ValidationError(
                        f"config.step.{step}",
                        f"Step '{step}' in strings.json but not in config_flow.py",
                        "warning",
                    )
                )

        # Check for missing error strings
        for error in flow_errors:
            if error not in string_errors:
                errors.append(
                    ValidationError(
                        f"config.error.{error}",
                        f"Error '{error}' used in config_flow.py but not in strings.json",
                    )
                )

        # Check for missing abort strings
        for abort in flow_aborts:
            if abort not in string_aborts:
                errors.append(
                    ValidationError(
                        f"config.abort.{abort}",
                        f"Abort reason '{abort}' used in config_flow.py but not in strings.json",
                    )
                )

    # Validate step structure
    steps = config.get("step", {})
    for step_name, step_data in steps.items():
        if not isinstance(step_data, dict):
            errors.append(
                ValidationError(f"config.step.{step_name}", "Step must be an object")
            )
            continue

        # Check for data_description (Bronze requirement)
        if "data" in step_data and "data_description" not in step_data:
            errors.append(
                ValidationError(
                    f"config.step.{step_name}.data_description",
                    "Missing data_description (required for IQS Bronze)",
                    "warning",
                )
            )

        # Validate data and data_description keys match
        if "data" in step_data and "data_description" in step_data:
            data_keys = set(step_data["data"].keys())
            desc_keys = set(step_data["data_description"].keys())

            missing_desc = data_keys - desc_keys
            extra_desc = desc_keys - data_keys

            for key in missing_desc:
                errors.append(
                    ValidationError(
                        f"config.step.{step_name}.data_description.{key}",
                        f"Missing description for field '{key}'",
                        "warning",
                    )
                )

            for key in extra_desc:
                errors.append(
                    ValidationError(
                        f"config.step.{step_name}.data_description.{key}",
                        f"Description for non-existent field '{key}'",
                        "warning",
                    )
                )

    # Check options flow
    if "options" in strings:
        options = strings["options"]
        if "step" not in options:
            errors.append(
                ValidationError("options.step", "Missing 'step' section in options")
            )

    return errors


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 2:
        # Try to find strings.json
        search_paths = [
            Path("strings.json"),
            Path("custom_components") / "*" / "strings.json",
        ]
        strings_path = None
        for pattern in search_paths:
            matches = list(Path(".").glob(str(pattern)))
            if matches:
                strings_path = matches[0]
                break

        if strings_path is None:
            print("Usage: validate-strings.py <path/to/strings.json>")
            return 1
    else:
        strings_path = Path(sys.argv[-1])

    # Look for config_flow.py in same directory
    config_flow_path = strings_path.parent / "config_flow.py"

    print(f"Validating: {strings_path}")
    if config_flow_path.exists():
        print(f"Syncing with: {config_flow_path}")
    print()

    errors = validate_strings(strings_path, config_flow_path)

    if not errors:
        print("✅ strings.json is valid!")
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
