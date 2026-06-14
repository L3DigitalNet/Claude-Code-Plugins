---
name: ha-hacs-publishing
description: Publish a Home Assistant integration to HACS — GitHub Actions validation, release workflow, brand submission, and adding to the HACS default repository.
---

# HACS Publishing Workflow

## GitHub Actions Validation

Create `.github/workflows/validate.yml` to run HACS and Hassfest checks on every push:

```yaml
name: Validate

on:
  push:
  pull_request:
  schedule:
    - cron: '0 0 * * *'
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

The `hacs/action@main` and `home-assistant/actions/hassfest@master` floating refs are intentional — these are the officially recommended values per HACS guidance, so do not "fix" them blindly. Note the trade-off: floating refs make the validation workflow non-reproducible and a supply-chain surface (a breaking change in those actions silently breaks your CI). Pinning to a release SHA/tag is the safer practice if you prefer reproducibility over auto-tracking upstream.

## README.md Template

```markdown
# My Integration

[![hacs_badge](https://img.shields.io/badge/HACS-Default-41BDF5.svg)](https://github.com/hacs/integration) [![GitHub Release](https://img.shields.io/github/release/user/repo.svg)](https://github.com/user/repo/releases)

Home Assistant integration for My Device.

## Features

- Feature 1
- Feature 2

## Installation

### HACS (Recommended)

1. Open HACS in Home Assistant
2. Open the three-dots menu (top-right) → "Custom repositories"
3. Add `https://github.com/user/repo` with type "Integration"
4. Search the HACS dashboard for "My Integration" and open it
5. Use the "Download" button (bottom-right) to install it
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

## Home Assistant Brands

Required for HACS default repository submission.

Add your brand to [home-assistant/brands](https://github.com/home-assistant/brands):

1. Fork the brands repository
2. Create `custom_integrations/{domain}/` folder
3. Add logo files:
   - `icon.png` — 256x256 square icon
   - `logo.png` — Horizontal logo (optional)
   - `icon@2x.png` — 512x512 retina icon (optional)
4. Submit pull request

## Publishing Releases

HACS uses GitHub Releases (not just tags):

```bash
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
# Then create Release on GitHub with changelog
```

**Version must match `manifest.json` version.**

## Adding to HACS Default

To add your repository to the HACS default list:

1. Ensure all validation checks pass
2. Publish at least one release
3. Submit your brand to home-assistant/brands
4. Fork [hacs/default](https://github.com/hacs/default)
5. Add your repository to the `integration` file (alphabetically)
6. Submit pull request

Custom repositories can still be added manually by users without being in the default list.

## Related Skills

- HACS metadata → `ha-hacs`
- Documentation → `ha-documentation`
