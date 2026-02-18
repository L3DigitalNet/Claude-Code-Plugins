# Contributing

Thanks for your interest in contributing to the Claude Code Plugins marketplace.

## Getting Started

1. Fork and clone the repository
2. Check out the `testing` branch: `git checkout testing`
3. Make your changes
4. Submit a pull request against `testing`

## Branch Workflow

- **`testing`** is the development branch — all PRs target this branch
- **`main`** is the production branch — only updated via merge from `testing`
- Never submit PRs directly to `main`

## Adding a New Plugin

1. Create your plugin in `plugins/your-plugin/`
2. Add a manifest at `plugins/your-plugin/.claude-plugin/manifest.json`
3. Add an entry to `.claude-plugin/marketplace.json`
4. Validate with `./scripts/validate-marketplace.sh`
5. Submit a PR

See [CLAUDE.md](CLAUDE.md) for detailed plugin structure and schema requirements.

## Updating an Existing Plugin

1. Make your changes in the plugin directory
2. Bump the version in both:
   - `plugins/your-plugin/.claude-plugin/plugin.json` (or `manifest.json`)
   - `.claude-plugin/marketplace.json`
3. Validate with `./scripts/validate-marketplace.sh`
4. Submit a PR

## Code Style

- JSON files must be valid and properly formatted (`jq .` is your friend)
- Shell scripts should pass ShellCheck
- Python code follows standard conventions (type hints, docstrings for public APIs)
- Markdown files should be readable without rendering

## Testing

- Run `./scripts/validate-marketplace.sh` before submitting
- If your plugin has tests, ensure they pass
- Test your plugin locally with `claude --plugin-dir ./plugins/your-plugin`

## Questions?

Open an issue with the `question` label.
