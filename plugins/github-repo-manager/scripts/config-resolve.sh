#!/usr/bin/env bash
set -euo pipefail

# config-resolve.sh — Multi-source config resolution for a single repo
#
# Merges configuration from up to four sources with clear precedence:
#   1. Portfolio per-repo overrides (highest)
#   2. Repo-level .github-repo-manager.yml
#   3. Portfolio defaults
#   4. Built-in tier defaults (lowest)
#
# Includes a minimal stdlib-only YAML parser (no PyYAML dependency).
# Outputs a single JSON object with the resolved config and source tracking.
#
# Usage: config-resolve.sh <owner/repo> [--portfolio-path <path>] [--plugin-root <path>]

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

[ $# -ge 1 ] || { echo '{"error":"usage: config-resolve.sh <owner/repo> [--portfolio-path <path>] [--plugin-root <path>]"}' >&2; exit 1; }

REPO="$1"; shift
PORTFOLIO_PATH="$HOME/.config/github-repo-manager/portfolio.yml"
PLUGIN_ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --portfolio-path) PORTFOLIO_PATH="$2"; shift 2 ;;
    --plugin-root)    PLUGIN_ROOT="$2"; shift 2 ;;
    *) echo "{\"error\":\"unknown option: $1\"}" >&2; exit 1 ;;
  esac
done

# Read repo-level config via helper CLI (if plugin root provided)
repo_config_json=""
repo_config_error=""
if [ -n "$PLUGIN_ROOT" ]; then
  HELPER="$PLUGIN_ROOT/helper/bin/gh-manager.js"
  if [ -f "$HELPER" ]; then
    repo_config_json=$(node "$HELPER" config repo-read --repo "$REPO" 2>&1) || \
      repo_config_error="failed to read repo config: $(echo "$repo_config_json" | head -1)"
  fi
fi

# Pass everything to Python for YAML parsing, merging, and JSON output
REPO="$REPO" PORTFOLIO_PATH="$PORTFOLIO_PATH" \
  REPO_CONFIG_JSON="$repo_config_json" REPO_CONFIG_ERROR="$repo_config_error" \
  $PYTHON << 'PYEOF'
import json, os

# --- Minimal YAML parser (stdlib-only) ---
# Handles key:value, 2-space indent nesting, and dash-item lists.
# No flow syntax, anchors, or multiline scalars.

def coerce(val):
    """Coerce YAML string values to native Python types."""
    if val.lower() in ("true", "yes"): return True
    if val.lower() in ("false", "no"): return False
    if val.lower() in ("null", "~", ""): return None
    try: return int(val)
    except ValueError: pass
    try: return float(val)
    except ValueError: pass
    if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
        return val[1:-1]
    return val

def parse_yaml(text):
    root, stack = {}, [(0, root)]
    for raw in text.split("\n"):
        s = raw.rstrip()
        if not s or s.lstrip().startswith("#"): continue
        indent = len(s) - len(s.lstrip())
        stripped = s.strip()
        while len(stack) > 1 and stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1]
        if stripped.startswith("- "):
            val = stripped[2:].strip()
            if isinstance(parent, dict) and parent:
                last_key = list(parent.keys())[-1]
                if not isinstance(parent[last_key], list):
                    parent[last_key] = []
                if ":" in val:
                    k, v = val.split(":", 1)
                    parent[last_key].append({k.strip(): coerce(v.strip())})
                else:
                    parent[last_key].append(coerce(val))
        elif ":" in stripped:
            key, _, value = stripped.partition(":")
            key, value = key.strip(), value.strip()
            if value:
                parent[key] = coerce(value)
            else:
                parent[key] = {}
                stack.append((indent + 2, parent[key]))
    return root

def deep_merge(base, override):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

# --- Read portfolio ---
repo = os.environ["REPO"]
portfolio_path = os.environ["PORTFOLIO_PATH"]
portfolio_defaults, portfolio_repo = {}, {}
portfolio_found = False

try:
    with open(portfolio_path) as f:
        parsed = parse_yaml(f.read())
    portfolio_found = True
    portfolio_defaults = parsed.get("defaults", {})
    repos_section = parsed.get("repos", {})
    if isinstance(repos_section, dict):
        portfolio_repo = repos_section.get(repo, {})
    elif isinstance(repos_section, list):
        for entry in repos_section:
            if isinstance(entry, dict) and entry.get("name") == repo:
                portfolio_repo = {k: v for k, v in entry.items() if k != "name"}
                break
except FileNotFoundError:
    pass

# --- Read repo-level config ---
repo_config, repo_config_found = {}, False
raw = os.environ.get("REPO_CONFIG_JSON", "")
if raw:
    try:
        d = json.loads(raw)
        p = d.get("parsed", {})
        if p:
            repo_config, repo_config_found = p, True
    except: pass

# --- Merge with precedence ---
tier_defaults = {"labels":{"sync":True},"security":{"check_dependabot":True,"check_code_scanning":True},"community":{"check_all":True}}
merged = tier_defaults
merged = deep_merge(merged, portfolio_defaults)
merged = deep_merge(merged, repo_config)
merged = deep_merge(merged, portfolio_repo)

# Track sources
precedence = []
if portfolio_found and portfolio_defaults: precedence.append("portfolio_defaults")
if repo_config_found: precedence.append("repo_config")
if portfolio_found and portfolio_repo: precedence.append("portfolio_repo_override")

result = {
    "repo": repo,
    "sources": {
        "tier_defaults": tier_defaults,
        "portfolio_defaults": portfolio_defaults if portfolio_found else None,
        "portfolio_path": portfolio_path,
        "repo_config": repo_config if repo_config_found else None,
        "portfolio_repo_override": portfolio_repo if portfolio_found and portfolio_repo else None
    },
    "resolved": merged,
    "precedence_applied": precedence or ["tier_defaults_only"]
}
err = os.environ.get("REPO_CONFIG_ERROR", "")
if err: result["errors"] = [err]

print(json.dumps(result, indent=2))
PYEOF
