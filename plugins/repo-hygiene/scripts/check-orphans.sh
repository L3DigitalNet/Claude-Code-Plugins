#!/usr/bin/env bash
# check-orphans.sh — Check 4 of 5 in the repo-hygiene sweep
#
# Compares three plugin state sources to detect orphaned or inconsistent entries:
#   Source 1: ~/.claude/plugins/installed_plugins.json — canonical install registry
#   Source 2: ~/.claude/settings.json enabledPlugins — UI toggle state
#   Source 3: ~/.claude/plugins/cache/ filesystem — top-level temp_* dirs
#
# Finding type 1 (warn): key in settings.json but absent from installed_plugins.json
# Finding type 2 (info): key in installed_plugins.json but absent from settings.json
# Finding type 3 (warn): temp_* directories at the top level of the cache dir
#
# All findings are needs-approval (removal of plugin state is destructive).
# fix_cmd is always null — no automated fixes for any finding type.
#
# Called by the /hygiene command. Outputs a single JSON object on stdout.
# Does NOT use jq — all JSON parsing done via Python 3.

set -euo pipefail

INSTALLED_PLUGINS="${HOME}/.claude/plugins/installed_plugins.json"
SETTINGS="${HOME}/.claude/settings.json"
CACHE_DIR="${HOME}/.claude/plugins/cache"

# Pass empty string when a file is absent — Python side handles gracefully
[[ -f "$INSTALLED_PLUGINS" ]] || INSTALLED_PLUGINS=""
[[ -f "$SETTINGS" ]]           || SETTINGS=""

python3 - "$INSTALLED_PLUGINS" "$SETTINGS" "$CACHE_DIR" <<'PYEOF'
import sys
import os
import json

installed_path = sys.argv[1]   # empty string → file was absent
settings_path  = sys.argv[2]   # empty string → file was absent
cache_dir      = sys.argv[3]

HOME = os.path.expanduser("~")

def tilde(path: str) -> str:
    """Replace home prefix with ~ for display paths."""
    if path.startswith(HOME):
        return "~" + path[len(HOME):]
    return path

findings = []

def finding(severity, path, detail):
    findings.append({
        "severity": severity,
        "path": path,
        "detail": detail,
        "auto_fix": False,
        "fix_cmd": None,
    })

# ── Source 1: installed_plugins.json ─────────────────────────────────────────
installed_keys: set[str] = set()
installed_display = tilde(os.path.join(HOME, ".claude", "plugins", "installed_plugins.json"))

if installed_path:
    try:
        with open(installed_path) as f:
            installed = json.load(f)
        installed_keys = set(installed.get("plugins", {}).keys())
    except (OSError, json.JSONDecodeError) as e:
        finding("warn", installed_display, f"Could not parse installed_plugins.json: {e}")

# ── Source 2: settings.json enabledPlugins ────────────────────────────────────
enabled_keys: set[str] = set()
settings_display = tilde(os.path.join(HOME, ".claude", "settings.json"))

if settings_path:
    try:
        with open(settings_path) as f:
            settings = json.load(f)
        enabled_keys = set(settings.get("enabledPlugins", {}).keys())
    except (OSError, json.JSONDecodeError) as e:
        finding("warn", settings_display, f"Could not parse settings.json: {e}")

# ── Cross-compare Sources 1 and 2 ────────────────────────────────────────────
# Finding type 1: in settings.json but NOT in installed_plugins.json (stale toggle)
for key in sorted(enabled_keys - installed_keys):
    finding(
        "warn",
        settings_display,
        (
            f"enabledPlugins has '{key}' but absent from installed_plugins.json "
            f"(stale entry)"
        ),
    )

# Finding type 2: in installed_plugins.json but NOT in settings.json (silent install)
for key in sorted(installed_keys - enabled_keys):
    finding(
        "info",
        installed_display,
        f"'{key}' is installed but not in settings.json enabledPlugins",
    )

# ── Source 3: temp_* dirs at top level of cache ───────────────────────────────
# Only scan one level deep — temp dirs are created at the cache root, not inside
# marketplace subdirs. Recursing would produce false positives.
if os.path.isdir(cache_dir):
    try:
        for entry in sorted(os.listdir(cache_dir)):
            if entry.startswith("temp_"):
                abs_path = os.path.join(cache_dir, entry)
                if os.path.isdir(abs_path):
                    finding(
                        "warn",
                        tilde(abs_path),
                        f"Orphaned temp directory in plugin cache — safe to delete: {abs_path}",
                    )
    except OSError as e:
        finding("warn", tilde(cache_dir), f"Could not read plugin cache directory: {e}")

# ── Output ────────────────────────────────────────────────────────────────────
print(json.dumps({"check": "orphans", "findings": findings}, indent=2))
PYEOF
