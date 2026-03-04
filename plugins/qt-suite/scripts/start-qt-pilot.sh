#!/usr/bin/env bash
# start-qt-pilot.sh — Creates venv on first run, then launches the Qt Pilot MCP server.
# Called by .mcp.json on every Claude Code session start that has this plugin enabled.
# Uses CLAUDE_PLUGIN_ROOT so the venv lives alongside the bundled server source.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
VENV_DIR="${PLUGIN_ROOT}/mcp/qt-pilot/.venv"
REQUIREMENTS="${PLUGIN_ROOT}/mcp/qt-pilot/requirements.txt"
SERVER="${PLUGIN_ROOT}/mcp/qt-pilot/main.py"

if [ ! -d "${VENV_DIR}" ]; then
    echo "qt-pilot: creating virtual environment (first run)..." >&2
    python3 -m venv "${VENV_DIR}" >&2
    echo "qt-pilot: installing dependencies (this may take ~30s on first run)..." >&2
    "${VENV_DIR}/bin/pip" install --quiet -r "${REQUIREMENTS}" >&2
    echo "qt-pilot: dependencies installed" >&2
fi

exec "${VENV_DIR}/bin/python" "${SERVER}"
