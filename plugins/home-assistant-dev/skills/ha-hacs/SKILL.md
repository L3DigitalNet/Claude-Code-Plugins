---
name: ha-hacs
description: Prepare a Home Assistant integration for HACS (Home Assistant Community Store) distribution. Use when asked about HACS, custom integration publishing, hacs.json, repository setup, HACS validation, or distributing integrations outside core.
---

# HACS Compliance Guide

HACS (Home Assistant Community Store) is the standard distribution method for custom integrations. This skill covers all requirements for HACS submission.

## Repository Structure

```
my-integration/
├── custom_components/
│   └── {domain}/
│       ├── __init__.py
│       ├── manifest.json      # HA manifest (required)
│       ├── config_flow.py
│       ├── const.py
│       ├── coordinator.py
│       └── ...
├── hacs.json                  # HACS metadata (required)
├── README.md                  # Documentation (required)
├── LICENSE                    # License file (recommended)
├── .github/
│   └── workflows/
│       └── validate.yml       # HACS validation workflow
└── info.md                    # HACS store description (optional)
```

## manifest.json Requirements

HACS requires these fields in `manifest.json`:

```json
{
  "domain": "my_integration",
  "name": "My Integration",
  "version": "1.0.0",
  "codeowners": ["@your-github-username"],
  "documentation": "https://github.com/user/repo",
  "issue_tracker": "https://github.com/user/repo/issues",
  "config_flow": true,
  "integration_type": "hub",
  "iot_class": "local_polling",
  "requirements": ["my-library==1.0.0"]
}
```

**Required for HACS:**
- `domain` — Must match folder name
- `name` — Display name
- `version` — Valid semver (X.Y.Z)
- `codeowners` — At least one GitHub username
- `documentation` — URL to docs
- `issue_tracker` — URL for bug reports

## hacs.json Configuration

Create `hacs.json` in repository root:

```json
{
  "name": "My Integration",
  "homeassistant": "2024.1.0"
}
```

### All hacs.json Options

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `name` | string | **Yes** | Display name in HACS |
| `homeassistant` | string | No | Minimum HA version (e.g., "2024.1.0") |
| `hacs` | string | No | Minimum HACS version |
| `content_in_root` | bool | No | Set `true` if files not in custom_components/ |
| `zip_release` | bool | No | Set `true` if using zipped releases |
| `filename` | string | No | Main file name (for zip_release) |
| `country` | string/array | No | ISO country codes (e.g., "US" or ["US", "CA"]) |
| `hide_default_branch` | bool | No | Hide default branch from version list |
| `persistent_directory` | string | No | Directory to preserve during updates |

### Examples

**Standard integration:**
```json
{
  "name": "My Smart Home Hub",
  "homeassistant": "2024.6.0"
}
```

**Country-specific integration:**
```json
{
  "name": "UK Energy Provider",
  "homeassistant": "2024.1.0",
  "country": "GB"
}
```

**With persistent data:**
```json
{
  "name": "My Integration",
  "homeassistant": "2024.1.0",
  "persistent_directory": "data"
}
```

## Home Assistant Brands

**Required for HACS default repository submission.**

Add your brand to [home-assistant/brands](https://github.com/home-assistant/brands):

1. Fork the brands repository
2. Create `custom_integrations/{domain}/` folder
3. Add logo files:
   - `icon.png` — 256x256 square icon
   - `logo.png` — Horizontal logo (optional)
   - `icon@2x.png` — 512x512 retina icon (optional)
4. Submit pull request

## GitHub Actions Validation

Create `.github/workflows/validate.yml`:

```yaml
name: Validate

on:
  push:
  pull_request:
  schedule:
    - cron: "0 0 * * *"
  workflow_dispatch:

jobs:
  validate-hacs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: HACS Validation
        uses: hacs/action@main
        with:
          category: integration

  validate-hassfest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Hassfest Validation
        uses: home-assistant/actions/hassfest@master
```

## README.md Template

```markdown
# My Integration

[![hacs_badge](https://img.shields.io/badge/HACS-Default-41BDF5.svg)](https://github.com/hacs/integration)
[![GitHub Release](https://img.shields.io/github/release/user/repo.svg)](https://github.com/user/repo/releases)

Home Assistant integration for My Device.

## Features

- Feature 1
- Feature 2

## Installation

### HACS (Recommended)

1. Open HACS in Home Assistant
2. Click "Integrations"
3. Click the three dots menu → "Custom repositories"
4. Add `https://github.com/user/repo` as category "Integration"
5. Click "My Integration" → "Download"
6. Restart Home Assistant

### Manual

1. Copy `custom_components/my_integration` to your `custom_components` folder
2. Restart Home Assistant

## Configuration

1. Go to Settings → Devices & Services
2. Click "Add Integration"
3. Search for "My Integration"
4. Follow the setup wizard

## Support

- [Documentation](https://github.com/user/repo/wiki)
- [Issues](https://github.com/user/repo/issues)
```

## Publishing Releases

HACS recommends GitHub Releases (not just tags):

```bash
# Create release
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# Then create Release on GitHub with changelog
```

**Version must match `manifest.json` version.**

## Validation Checklist

Before submitting to HACS default repository:

- [ ] `manifest.json` has all required fields including `issue_tracker`
- [ ] `hacs.json` exists with at least `name` field
- [ ] `README.md` exists with installation instructions
- [ ] Repository has description and topics on GitHub
- [ ] Brand submitted to home-assistant/brands
- [ ] At least one GitHub Release published
- [ ] HACS validation action passes
- [ ] Hassfest validation passes

## Adding to HACS Default

To add your repository to HACS default list:

1. Ensure all validation checks pass
2. Create a release
3. Fork [hacs/default](https://github.com/hacs/default)
4. Add your repository to `integration` file (alphabetically)
5. Submit pull request

**Note:** Custom repositories can still be added manually by users without being in the default list.

## Troubleshooting

### Common Issues

**"Invalid manifest"**
- Check JSON syntax in manifest.json
- Ensure all required fields present
- Version must be valid semver

**"Missing hacs.json"**
- File must be in repository root (not in custom_components)

**"No release found"**
- Publish a GitHub Release (not just a tag)
- Release tag should match manifest version

## Related Skills

- Integration structure → `ha-integration-scaffold`
- Quality requirements → `ha-quality-review`
- Testing setup → `ha-testing`
