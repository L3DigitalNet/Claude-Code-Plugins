#!/usr/bin/env bash
# run-tests.sh — Bootstrap the qt-pilot venv (if missing) and run pytest.
#
# Pytest collection imports `main` and `harness`, which in turn import the
# `mcp` and `PySide6` libraries — neither is in the system Python by default.
# `start-qt-pilot.sh` does the same bootstrap before exec'ing the MCP server;
# this wrapper does the same bootstrap before invoking pytest, so test runs
# are idempotent without the caller having to remember the setup step.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
REQUIREMENTS="${SCRIPT_DIR}/requirements.txt"
DEV_REQUIREMENTS="${SCRIPT_DIR}/requirements-dev.txt"

if [ ! -d "${VENV_DIR}" ]; then
    echo "qt-pilot tests: creating virtual environment (first run)..." >&2
    python3 -m venv "${VENV_DIR}" >&2
    echo "qt-pilot tests: installing runtime + dev dependencies (~30s)..." >&2
    "${VENV_DIR}/bin/pip" install --quiet -r "${REQUIREMENTS}" >&2
    "${VENV_DIR}/bin/pip" install --quiet -r "${DEV_REQUIREMENTS}" >&2
elif ! "${VENV_DIR}/bin/python" -c 'import pytest' 2>/dev/null; then
    # Existing venv created by start-qt-pilot.sh (runtime deps only); add pytest.
    echo "qt-pilot tests: existing venv missing pytest; installing dev deps..." >&2
    "${VENV_DIR}/bin/pip" install --quiet -r "${DEV_REQUIREMENTS}" >&2
fi

cd "${SCRIPT_DIR}"
exec "${VENV_DIR}/bin/python" -m pytest "$@"
