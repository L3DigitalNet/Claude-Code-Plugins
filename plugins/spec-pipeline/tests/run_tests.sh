#!/usr/bin/env bash
# Runs the specpipe pytest suite. specpipe is a plain stdlib package imported
# via PYTHONPATH — deliberately NO pyproject/venv/lock, so uv never writes
# into the plugin tree (--no-project skips lock/sync; pytest comes from an
# ephemeral --with env in uv's cache). Always invoke this wrapper, never bare
# pytest (import path).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
export PYTHONPATH="$PLUGIN_ROOT/scripts/specpipe${PYTHONPATH:+:$PYTHONPATH}"
# Keep the plugin tree free of generated state (AC9): no bytecode, no pytest cache.
export PYTHONDONTWRITEBYTECODE=1
exec uv run --no-project --with pytest pytest -p no:cacheprovider "$SCRIPT_DIR" "$@"
