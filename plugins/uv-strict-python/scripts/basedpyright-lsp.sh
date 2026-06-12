#!/usr/bin/env bash
set -euo pipefail

# LSP launcher implementing the standard's §13 CLI-agent language-server
# policy: BasedPyright is the single semantic/type authority across editing
# surfaces. Referenced from the plugin's .lsp.json via ${CLAUDE_PLUGIN_ROOT}.
#
# Resolution order:
#   1. basedpyright-langserver on PATH (uv tool install basedpyright)
#   2. uvx fallback — runs from uv's tool cache, downloads on first use

if command -v basedpyright-langserver &>/dev/null; then
  exec basedpyright-langserver --stdio
fi

if command -v uvx &>/dev/null; then
  exec uvx --from basedpyright basedpyright-langserver --stdio
fi

echo "uv-strict-python: basedpyright-langserver not found." >&2
echo "  Install it globally: uv tool install basedpyright" >&2
exit 127
