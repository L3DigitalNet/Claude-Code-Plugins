#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: prepend shims directory to PATH so that bare
# python/pip/pipx/uv-pip invocations are intercepted with uv suggestions.
#
# `uv run` is unaffected because it prepends its managed virtualenv's
# bin/ to PATH, shadowing the shims.
#
# Scope gate: the Python Tooling SSOT Standard is repository-scoped, so the
# shims activate only in Python projects (pyproject.toml, .python-version,
# or uv.lock at the project root). Override per project via
# .claude/uv-strict-python.local.md frontmatter:
#   shims: always   # force shims on in a non-Python project
#   shims: never    # keep shims off even in a Python project
#   shims: auto     # default — markers decide

# Guard: only activate when uv is available
command -v uv &>/dev/null || exit 0

# Guard: CLAUDE_ENV_FILE must be set by the runtime
if [[ -z "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "uv-strict-python: CLAUDE_ENV_FILE not set; shims will not be installed" >&2
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

mode="auto"
settings_file="$project_dir/.claude/uv-strict-python.local.md"
if [[ -f "$settings_file" ]]; then
  parsed="$(awk -F': *' '$1 == "shims" {print $2; exit}' "$settings_file" | tr -d '"' || true)"
  [[ -n "$parsed" ]] && mode="$parsed"
fi

case "$mode" in
  never)
    exit 0
    ;;
  always) ;;
  *)
    if [[ ! -f "$project_dir/pyproject.toml" &&
      ! -f "$project_dir/.python-version" &&
      ! -f "$project_dir/uv.lock" ]]; then
      exit 0
    fi
    ;;
esac

shims_dir="$(cd "$(dirname "$0")/shims" && pwd)" || {
  echo "uv-strict-python: shims directory not found" >&2
  exit 1
}

echo "export PATH=\"${shims_dir}:\${PATH}\"" >>"$CLAUDE_ENV_FILE"
