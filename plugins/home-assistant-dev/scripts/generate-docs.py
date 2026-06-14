#!/usr/bin/env python3
"""Generate documentation for a Home Assistant integration.

Analyzes the integration code and generates:
- README.md
- info.md (for HACS)

This builds output programmatically from the integration code; it does NOT read
templates/docs/*.template (those are manual-fill reference templates that may differ).
It is a standalone CLI: the /generate-integration command produces docs inline and does
not invoke this script — run it manually to (re)generate docs for an existing integration
(also exercised in tests/e2e/E2E_CHECKLIST.md section 3.4).

Existing README.md/info.md are never silently overwritten: without --force the
generated content is diverted to README.generated.md / info.generated.md for manual
merge; with --force the existing file is backed up to <name>.bak first.

Usage:
    python generate-docs.py [--force] <path/to/custom_components/domain>
    python generate-docs.py  # Auto-detect in current directory
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class IntegrationInfo:
    """Collected information about an integration."""

    domain: str = ""
    name: str = ""
    version: str = ""
    description: str = ""
    documentation: str = ""
    issue_tracker: str = ""
    iot_class: str = ""
    integration_type: str = ""
    # Minimum supported HA version, read from manifest/hacs.json when present.
    min_ha_version: str = ""
    codeowners: list[str] = field(default_factory=list)
    requirements: list[str] = field(default_factory=list)

    # Extracted from code
    platforms: list[str] = field(default_factory=list)
    config_flow_fields: dict[str, list[str]] = field(default_factory=dict)
    options_flow_fields: list[str] = field(default_factory=list)
    entity_descriptions: dict[str, list[str]] = field(default_factory=dict)
    has_diagnostics: bool = False
    has_reauth: bool = False
    has_reconfigure: bool = False


def load_manifest(integration_path: Path) -> dict[str, Any]:
    """Load manifest.json."""
    manifest_path = integration_path / "manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"manifest.json not found in {integration_path}")

    with open(manifest_path) as f:
        return json.load(f)


def extract_platforms(integration_path: Path) -> list[str]:
    """Extract platforms from __init__.py."""
    init_path = integration_path / "__init__.py"
    if not init_path.exists():
        return []

    content = init_path.read_text()

    # Look for PLATFORMS list
    match = re.search(r"PLATFORMS.*?=.*?\[(.*?)\]", content, re.DOTALL)
    if match:
        platforms_str = match.group(1)
        # Extract Platform.XXX entries
        platforms = re.findall(r"Platform\.(\w+)", platforms_str)
        return [p.lower() for p in platforms]

    return []


def extract_config_flow_info(integration_path: Path) -> dict[str, Any]:
    """Extract config flow information."""
    config_flow_path = integration_path / "config_flow.py"
    if not config_flow_path.exists():
        return {}

    content = config_flow_path.read_text()

    info: dict[str, Any] = {
        "has_reauth": "async_step_reauth" in content,
        "has_reconfigure": "async_step_reconfigure" in content,
        "has_options": "OptionsFlow" in content,
    }

    return info


def extract_strings_info(integration_path: Path) -> dict[str, Any]:
    """Extract information from strings.json."""
    strings_path = integration_path / "strings.json"
    if not strings_path.exists():
        return {}

    with open(strings_path) as f:
        strings = json.load(f)

    info = {}

    # Extract config flow step info
    config_steps = strings.get("config", {}).get("step", {})
    info["config_steps"] = list(config_steps.keys())

    # Extract entity names
    entity_info = strings.get("entity", {})
    info["entities"] = {}
    for platform, entities in entity_info.items():
        info["entities"][platform] = list(entities.keys())

    return info


def analyze_integration(integration_path: Path) -> IntegrationInfo:
    """Analyze an integration and collect information."""
    info = IntegrationInfo()

    # Load manifest
    manifest = load_manifest(integration_path)
    info.domain = manifest.get("domain", "")
    info.name = manifest.get("name", "")
    info.version = manifest.get("version", "")
    info.documentation = manifest.get("documentation", "")
    info.issue_tracker = manifest.get("issue_tracker", "")
    info.iot_class = manifest.get("iot_class", "")
    info.integration_type = manifest.get("integration_type", "")
    info.codeowners = manifest.get("codeowners", [])
    info.requirements = manifest.get("requirements", [])

    # Minimum HA version: manifest "homeassistant" key takes priority, then
    # hacs.json's "homeassistant" key (the conventional HACS location) at repo root.
    info.min_ha_version = str(manifest.get("homeassistant", "") or "")
    if not info.min_ha_version:
        hacs_path = integration_path.parent.parent / "hacs.json"
        if hacs_path.exists():
            try:
                with open(hacs_path) as f:
                    hacs = json.load(f)
                info.min_ha_version = str(hacs.get("homeassistant", "") or "")
            except (json.JSONDecodeError, OSError):
                pass

    # Extract platforms
    info.platforms = extract_platforms(integration_path)

    # Extract config flow info
    config_info = extract_config_flow_info(integration_path)
    info.has_reauth = config_info.get("has_reauth", False)
    info.has_reconfigure = config_info.get("has_reconfigure", False)

    # Check for diagnostics
    info.has_diagnostics = (integration_path / "diagnostics.py").exists()

    # Extract strings info
    strings_info = extract_strings_info(integration_path)
    info.entity_descriptions = strings_info.get("entities", {})

    return info


def write_doc(content: str, output_path: Path, force: bool) -> None:
    """Write generated doc without silently clobbering a curated file.

    If output_path exists: with force, back it up to <name>.bak before
    overwriting; without force, divert the write to <stem>.generated<suffix>
    so the hand-maintained original is left untouched for the user to merge.
    """
    if output_path.exists():
        if force:
            backup_path = output_path.with_name(output_path.name + ".bak")
            backup_path.write_text(output_path.read_text())
            print(f"Backed up existing {output_path.name} to {backup_path.name}")
            output_path.write_text(content)
            print(f"Generated: {output_path}")
        else:
            diverted = output_path.with_name(f"{output_path.stem}.generated{output_path.suffix}")
            diverted.write_text(content)
            print(
                f"Existing {output_path.name} left untouched; wrote {diverted.name} instead "
                f"(merge manually, or re-run with --force to overwrite)"
            )
    else:
        output_path.write_text(content)
        print(f"Generated: {output_path}")


def generate_readme(info: IntegrationInfo, output_path: Path, force: bool = False) -> None:
    """Generate README.md."""
    # Build feature list
    features = []
    if info.platforms:
        features.append(f"Supports: {', '.join(info.platforms)}")
    if info.has_reauth:
        features.append("Automatic re-authentication")
    if info.has_reconfigure:
        features.append("Reconfiguration support")
    if info.has_diagnostics:
        features.append("Diagnostic data collection")

    features_str = "\n".join(f"- {f}" for f in features) if features else "- See documentation"

    # Build entity table
    entities_str = ""
    for platform, entities in info.entity_descriptions.items():
        if entities:
            entities_str += f"\n### {platform.title()}s\n\n"
            entities_str += "| Entity | Description |\n|--------|-------------|\n"
            for entity in entities:
                entities_str += f"| {info.domain}_{entity} | {entity.replace('_', ' ').title()} |\n"

    if not entities_str:
        entities_str = "See the integration in Home Assistant for available entities."

    # Extract GitHub info from documentation URL
    github_match = re.search(r"github\.com/([^/]+)/([^/]+)", info.documentation)
    github_user = github_match.group(1) if github_match else "username"
    github_repo = github_match.group(2) if github_match else "repo"

    readme = f"""# {info.name}

[![hacs_badge](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![GitHub Release](https://img.shields.io/github/release/{github_user}/{github_repo}.svg)](https://github.com/{github_user}/{github_repo}/releases)

Home Assistant integration for {info.name}.

## Features

{features_str}

## Installation

### HACS (Recommended)

1. Open HACS in Home Assistant
2. Click "Integrations"
3. Click ⋮ → "Custom repositories"
4. Add `https://github.com/{github_user}/{github_repo}` as category "Integration"
5. Click "{info.name}" → "Download"
6. Restart Home Assistant

### Manual

1. Download the latest release
2. Copy `custom_components/{info.domain}` to your `custom_components` folder
3. Restart Home Assistant

## Configuration

1. Go to **Settings** → **Devices & Services**
2. Click **+ Add Integration**
3. Search for "{info.name}"
4. Follow the setup wizard

## Entities
{entities_str}

## Troubleshooting

### Entity shows "Unavailable"

- Check device is powered on
- Verify network connectivity
- Check the integration logs

## Support

- [GitHub Issues]({info.issue_tracker})

## License

MIT
"""

    write_doc(readme, output_path, force)


def generate_hacs_info(info: IntegrationInfo, output_path: Path, force: bool = False) -> None:
    """Generate info.md for HACS."""
    platforms_str = "\n".join(f"- {p.title()}" for p in info.platforms) if info.platforms else "- See integration"

    # Prefer the manifest/hacs.json-derived minimum; fall back to the plugin's
    # modern-HA baseline rather than a stale hardcoded floor.
    min_ha_version = info.min_ha_version or "2025.1.0"

    hacs_info = f"""# {info.name}

Home Assistant integration for {info.name}.

## Requirements

- Home Assistant {min_ha_version} or later

## Features

- Config flow setup via UI
{"- Automatic re-authentication\n" if info.has_reauth else ""}{"- Diagnostics support\n" if info.has_diagnostics else ""}

## Platforms

{platforms_str}

## Setup

After installation, add the integration through Settings → Devices & Services.
"""

    write_doc(hacs_info, output_path, force)


def main() -> int:
    """Main entry point."""
    args = sys.argv[1:]
    force = "--force" in args
    positional = [a for a in args if not a.startswith("-")]

    # Find integration path
    if positional:
        integration_path = Path(positional[0])
    else:
        # Try to auto-detect
        candidates = list(Path(".").glob("custom_components/*/manifest.json"))
        if candidates:
            integration_path = candidates[0].parent
        else:
            print("Usage: generate-docs.py [--force] <path/to/custom_components/domain>")
            return 1

    if not integration_path.exists():
        print(f"Path not found: {integration_path}")
        return 1

    print(f"Analyzing: {integration_path}")

    try:
        info = analyze_integration(integration_path)
    except Exception as e:
        print(f"Error analyzing integration: {e}")
        return 1

    print(f"Integration: {info.name} ({info.domain})")
    print(f"Platforms: {', '.join(info.platforms) or 'none detected'}")
    print()

    # Generate documentation
    repo_root = integration_path.parent.parent
    generate_readme(info, repo_root / "README.md", force=force)
    generate_hacs_info(info, repo_root / "info.md", force=force)

    print()
    print("Documentation generated! Review and customize as needed.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
