#!/usr/bin/env python3
"""Generate documentation for a Home Assistant integration.

Analyzes the integration code and generates:
- README.md
- info.md (for HACS)

Usage:
    python generate-docs.py <path/to/custom_components/domain>
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

    # Extract fields from vol.Schema
    # This is a simplified extraction - real implementation would use AST
    schema_matches = re.findall(
        r"vol\.(Required|Optional)\s*\(\s*([A-Z_]+|[\"'][^\"']+[\"'])",
        content,
    )
    info["fields"] = [m[1].strip("\"'") for m in schema_matches]

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


def generate_readme(info: IntegrationInfo, output_path: Path) -> None:
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

    output_path.write_text(readme)
    print(f"Generated: {output_path}")


def generate_hacs_info(info: IntegrationInfo, output_path: Path) -> None:
    """Generate info.md for HACS."""
    platforms_str = "\n".join(f"- {p.title()}" for p in info.platforms) if info.platforms else "- See integration"

    hacs_info = f"""# {info.name}

Home Assistant integration for {info.name}.

## Requirements

- Home Assistant 2024.1.0 or later

## Features

- Config flow setup via UI
{"- Automatic re-authentication\n" if info.has_reauth else ""}{"- Diagnostics support\n" if info.has_diagnostics else ""}

## Platforms

{platforms_str}

## Setup

After installation, add the integration through Settings → Devices & Services.
"""

    output_path.write_text(hacs_info)
    print(f"Generated: {output_path}")


def main() -> int:
    """Main entry point."""
    # Find integration path
    if len(sys.argv) > 1:
        integration_path = Path(sys.argv[1])
    else:
        # Try to auto-detect
        candidates = list(Path(".").glob("custom_components/*/manifest.json"))
        if candidates:
            integration_path = candidates[0].parent
        else:
            print("Usage: generate-docs.py <path/to/custom_components/domain>")
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
    generate_readme(info, repo_root / "README.md")
    generate_hacs_info(info, repo_root / "info.md")

    print()
    print("Documentation generated! Review and customize as needed.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
