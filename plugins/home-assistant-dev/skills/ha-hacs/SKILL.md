---
name: ha-hacs
description: HACS metadata requirements for a Home Assistant integration — hacs.json, manifest.json fields, and repository structure. Use when preparing or validating HACS metadata files.
---

# HACS Metadata Guide

HACS (Home Assistant Community Store) is the standard distribution method for custom integrations.

## Repository Structure

```
my-integration/
├── custom_components/
│   └── {domain}/
│       ├── __init__.py
│       ├── manifest.json      # HA manifest (required)
│       ├── config_flow.py
│       └── ...
├── hacs.json                  # HACS metadata (required)
├── README.md                  # Documentation (required)
├── LICENSE                    # License file (recommended)
└── .github/
    └── workflows/
        └── validate.yml       # HACS validation workflow
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

## Validation Checklist

Before submitting to HACS default repository:

- [ ] `manifest.json` has all required fields including `issue_tracker`
- [ ] `hacs.json` exists with at least `name` field
- [ ] `README.md` exists with installation instructions
- [ ] Repository has description and topics on GitHub
- [ ] At least one GitHub Release published (tag must match manifest version)
- [ ] HACS validation action passes
- [ ] Hassfest validation passes

## Troubleshooting

**"Invalid manifest"** — Check JSON syntax; ensure all required fields present; version must be valid semver.

**"Missing hacs.json"** — File must be in repository root (not in custom_components).

**"No release found"** — Publish a GitHub Release (not just a tag); release tag should match manifest version.

## Related Skills

- HACS publishing workflow → `ha-hacs-publishing`
- Integration structure → `ha-integration-scaffold`
