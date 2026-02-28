#!/usr/bin/env bash
# MCP server launcher — resolves dependencies via uv and starts the FastMCP server.
# Called by Claude Code via .mcp.json; stdout is reserved for the MCP protocol.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

export KEEPASS_CRED_MGR_CONFIG="${KEEPASS_CRED_MGR_CONFIG:-${HOME}/.config/keepass-cred-mgr/config.yaml}"

exec uv run --directory "$PLUGIN_ROOT" --with "mcp,structlog,pyyaml,filelock" python3 -m server.main
