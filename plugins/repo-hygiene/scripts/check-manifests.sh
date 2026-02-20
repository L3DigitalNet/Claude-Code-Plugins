#!/usr/bin/env bash
# check-manifests.sh — Check 2 of 5 in the repo-hygiene sweep
#
# Validates two manifest sources for consistency:
#   Source A: .claude-plugin/marketplace.json (repo root) — checks that each
#             plugin's source dir, plugin.json, and version all align.
#   Source B: ~/.claude/plugins/installed_plugins.json — checks that each
#             plugin's installPath directory still exists on disk.
#
# Called by the /hygiene command from repo root. Outputs a single JSON object
# on stdout. Exits non-zero with a message on stderr on hard failures.
#
# Does NOT use jq — all JSON parsing done via Python 3.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
INSTALLED_PLUGINS="${HOME}/.claude/plugins/installed_plugins.json"

# installed_plugins.json may not exist in all environments — skip gracefully
if [[ ! -f "$INSTALLED_PLUGINS" ]]; then
    INSTALLED_PLUGINS=""
fi

if [[ ! -f "$MARKETPLACE" ]]; then
    echo "check-manifests.sh: marketplace.json not found at $MARKETPLACE" >&2
    exit 1
fi

python3 - "$REPO_ROOT" "$MARKETPLACE" "$INSTALLED_PLUGINS" <<'PYEOF'
import sys
import os
import json

repo_root       = sys.argv[1]
marketplace_path = sys.argv[2]
installed_path  = sys.argv[3]  # empty string means file was absent

findings = []

def finding(severity, path, detail):
    findings.append({
        "severity": severity,
        "path": path,
        "detail": detail,
        "auto_fix": False,
        "fix_cmd": None,
    })

# ── Source A: marketplace.json ────────────────────────────────────────────────
with open(marketplace_path) as f:
    marketplace = json.load(f)

marketplace_rel = os.path.relpath(marketplace_path, repo_root)

for plugin in marketplace.get("plugins", []):
    name    = plugin.get("name", "<unnamed>")
    source  = plugin.get("source", "")
    mp_ver  = plugin.get("version")

    # Check 0: trailing slash in source path (auto-fixable normalisation)
    # A trailing slash causes os.path.isdir to behave unexpectedly on some paths
    # and indicates a copy-paste error in marketplace.json — fix before resolving.
    if source.endswith('/'):
        clean_source = source.rstrip('/')
        findings.append({
            "severity": "warn",
            "path": marketplace_rel,
            "detail": f"Plugin '{name}' source has trailing slash: '{source}' — should be '{clean_source}'",
            "auto_fix": True,
            "fix_cmd": (
                f"python3 -c \""
                f"import json; f=open('{marketplace_path}','r+'); "
                f"d=json.load(f); "
                f"next(p for p in d['plugins'] if p['name']=='{name}')['source']='{clean_source}'; "
                f"f.seek(0); json.dump(d,f,indent=2); f.truncate()\""
            ),
        })
        continue  # don't do further checks with the malformed path

    # Resolve source relative to repo root
    if source.startswith("./") or source.startswith("../"):
        source_abs = os.path.normpath(os.path.join(repo_root, source))
    else:
        source_abs = source  # already absolute or unusual — use as-is

    # Check 1: source directory exists
    if not os.path.isdir(source_abs):
        finding(
            "warn",
            marketplace_rel,
            f"Plugin '{name}' source '{source}' directory not found",
        )
        continue  # can't check plugin.json or version without the dir

    # Check 2: plugin.json exists inside source dir
    plugin_json_path = os.path.join(source_abs, ".claude-plugin", "plugin.json")
    if not os.path.isfile(plugin_json_path):
        finding(
            "warn",
            marketplace_rel,
            f"Plugin '{name}' missing .claude-plugin/plugin.json at '{source}'",
        )
        continue  # can't compare versions without plugin.json

    # Check 3: version match between marketplace entry and plugin.json
    with open(plugin_json_path) as pf:
        plugin_manifest = json.load(pf)

    pj_ver = plugin_manifest.get("version")

    if mp_ver is not None and pj_ver is not None and mp_ver != pj_ver:
        finding(
            "warn",
            marketplace_rel,
            (
                f"Plugin '{name}' version mismatch: "
                f"marketplace={mp_ver}, plugin.json={pj_ver}"
            ),
        )

# ── Source B: installed_plugins.json ─────────────────────────────────────────
if installed_path:
    installed_rel = os.path.relpath(installed_path, os.path.expanduser("~"))
    installed_display = "~/" + installed_rel

    with open(installed_path) as f:
        installed = json.load(f)

    for plugin_key, entries in installed.get("plugins", {}).items():
        if not entries:
            continue
        install_path = entries[0].get("installPath", "")
        if not install_path:
            continue
        if not os.path.isdir(install_path):
            finding(
                "warn",
                installed_display,
                f"Plugin '{plugin_key}' installPath not found: {install_path}",
            )

# ── Output ────────────────────────────────────────────────────────────────────
print(json.dumps({"check": "manifests", "findings": findings}, indent=2))
PYEOF
