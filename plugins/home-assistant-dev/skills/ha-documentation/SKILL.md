---
name: ha-documentation
description: Generate documentation for Home Assistant integrations. Creates README.md, Home Assistant docs pages, and HACS info pages. Use when asked about documentation, README, docs, or making documentation for an integration.
---

# Home Assistant Integration Documentation

Guide for creating comprehensive documentation for custom integrations.

## Documentation Files

| File | Purpose | Location |
|------|---------|----------|
| README.md | GitHub landing page | Repository root |
| info.md | HACS description | Repository root |
| docs/*.md | Extended docs | Optional |

## Templates

**README.md** — see [references/readme-template.md](references/readme-template.md)

**HACS info.md and badge snippets** — see [references/hacs-info-template.md](references/hacs-info-template.md)

## Documentation Best Practices

### Structure

1. **Start with what it does** — Users should know in 10 seconds
2. **Installation first** — Most common task
3. **Configuration with examples** — Show, don't just tell
4. **Entity reference** — Complete list of what's created
5. **Troubleshooting** — Answer common questions preemptively
6. **Known limitations** — Set expectations

### Writing Style

- Use second person ("you" not "the user")
- Be concise — bullet points over paragraphs
- Include screenshots where helpful
- Keep examples copy-paste ready
- Update version numbers in badges

## IQS Documentation Requirements

### Bronze

- `docs-high-level-description`: What the integration does
- `docs-installation-instructions`: How to install
- `docs-removal-instructions`: How to remove
- `docs-actions`: Service action documentation

### Silver

- `docs-installation-parameters`: All setup fields explained
- `docs-configuration-parameters`: All options explained

### Gold

- `docs-data-update`: How/when data updates
- `docs-examples`: Automation examples
- `docs-known-limitations`: What doesn't work
- `docs-supported-devices`: Compatible devices
- `docs-supported-functions`: Feature list
- `docs-troubleshooting`: Common issues
- `docs-use-cases`: Real-world examples

## Related Skills

- Integration structure → `ha-integration-scaffold`
- HACS publishing → `ha-hacs`
- Quality review → `ha-quality-review`
