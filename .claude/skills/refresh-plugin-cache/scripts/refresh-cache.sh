#!/usr/bin/env bash
# refresh-cache.sh — Updates the l3digitalnet-plugins marketplace index and audits installed
# plugin versions. Scoped to l3digitalnet-plugins only — the claude-plugins-official marketplace
# is managed by Anthropic and excluded from both the git refresh and the version check.
#
# Interacts with:
#   ~/.claude/plugins/marketplaces/      — git clones of marketplace repos (updated in-place)
#   ~/.claude/plugins/installed_plugins.json — source of truth for installed plugins
#   ~/.claude/plugins/cache/             — installed plugin snapshots (inspected, not modified)
#
# Outputs structured text for Claude to interpret and summarize. Exits 0 even when plugins
# are stale — Claude decides what remediation action to take.

set -euo pipefail

TARGET_MARKETPLACE="l3digitalnet-plugins"
MARKETPLACES_DIR="${HOME}/.claude/plugins/marketplaces"
INSTALLED_FILE="${HOME}/.claude/plugins/installed_plugins.json"
CACHE_DIR="${HOME}/.claude/plugins/cache"

# --- Step 1: Update the l3digitalnet-plugins marketplace git clone ---

echo "=== MARKETPLACE INDEX REFRESH ==="
echo ""

marketplace_dir="${MARKETPLACES_DIR}/${TARGET_MARKETPLACE}"

if [[ ! -d "$marketplace_dir" ]]; then
    echo "ERROR  $TARGET_MARKETPLACE not found at $marketplace_dir"
elif [[ ! -d "$marketplace_dir/.git" ]]; then
    echo "SKIP   $TARGET_MARKETPLACE  (not a git repo)"
else
    before=$(git -C "$marketplace_dir" rev-parse HEAD 2>/dev/null || echo "unknown")

    if ! git -C "$marketplace_dir" fetch origin --quiet 2>/dev/null; then
        echo "ERROR  $TARGET_MARKETPLACE  (fetch failed — offline?)"
    else
        git -C "$marketplace_dir" reset --hard origin/main --quiet 2>/dev/null
        after=$(git -C "$marketplace_dir" rev-parse HEAD 2>/dev/null || echo "unknown")

        if [[ "$before" == "$after" ]]; then
            echo "OK     $TARGET_MARKETPLACE  (${after:0:8}, no change)"
        else
            echo "UPDATE $TARGET_MARKETPLACE  (${before:0:8} → ${after:0:8})"
        fi
    fi
fi

echo ""

# --- Step 2: Compare l3digitalnet-plugins versions against refreshed marketplace data ---

echo "=== INSTALLED PLUGIN VERSION CHECK ==="
echo ""

if [[ ! -f "$INSTALLED_FILE" ]]; then
    echo "No installed_plugins.json found at $INSTALLED_FILE"
    exit 0
fi

python3 - "$TARGET_MARKETPLACE" <<'PYEOF'
import json
import os
import sys

target_marketplace = sys.argv[1]
installed_file = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
marketplaces_dir = os.path.expanduser("~/.claude/plugins/marketplaces")
cache_dir = os.path.expanduser("~/.claude/plugins/cache")

with open(installed_file) as f:
    installed = json.load(f)

# Load version map for the target marketplace only
mj = os.path.join(marketplaces_dir, target_marketplace, ".claude-plugin", "marketplace.json")
try:
    with open(mj) as f:
        data = json.load(f)
    market_versions = {p["name"]: p.get("version") for p in data.get("plugins", [])}
except FileNotFoundError:
    print(f"ERROR  marketplace.json not found for {target_marketplace}")
    sys.exit(0)
except Exception as e:
    print(f"ERROR  Could not read marketplace.json: {e}")
    sys.exit(0)

stale, current = [], []

for plugin_key, entries in installed["plugins"].items():
    if not entries:
        continue
    # Skip plugins not belonging to the target marketplace
    if not plugin_key.endswith(f"@{target_marketplace}"):
        continue

    entry = entries[0]
    installed_version = entry.get("version", "unknown")
    plugin_name = plugin_key.rsplit("@", 1)[0]

    market_version = market_versions.get(plugin_name)
    if market_version is None:
        # Plugin is installed but no longer listed in marketplace — flag it
        stale.append((plugin_key, installed_version, "(removed from marketplace)"))
        continue

    if installed_version == market_version:
        current.append((plugin_key, installed_version))
    else:
        stale.append((plugin_key, installed_version, market_version))

if stale:
    print("STALE (reinstall needed):")
    for key, iv, mv in sorted(stale):
        print(f"  {key}: {iv} → {mv}")
    print()

if current:
    print("CURRENT:")
    for key, v in sorted(current):
        print(f"  {key}: v{v}")
    print()

# --- Orphaned cache directories under l3digitalnet-plugins cache ---
l3_cache = os.path.join(cache_dir, target_marketplace)
all_install_paths = {
    e["installPath"]
    for entries in installed["plugins"].values()
    for e in entries
}

if os.path.isdir(l3_cache):
    orphans = []
    for plugin_name in os.listdir(l3_cache):
        plugin_dir = os.path.join(l3_cache, plugin_name)
        if not os.path.isdir(plugin_dir):
            continue
        # Check each version subdirectory
        for version in os.listdir(plugin_dir):
            version_dir = os.path.join(plugin_dir, version)
            if not os.path.isdir(version_dir):
                continue
            if version_dir not in all_install_paths:
                orphans.append(version_dir)

    if orphans:
        print("ORPHANED CACHE DIRS (safe to delete):")
        for o in sorted(orphans):
            print(f"  {o}")
        print()
    else:
        print("No orphaned cache directories.")
PYEOF

echo ""

# --- Step 3: Detect live MCP process version skew ---
# Claude Code reads installed_plugins.json once at startup; mid-session path changes don't
# take effect until the next session. If the running process path version differs from the
# installed path version, report LIVE_SKEW — normal reinstall won't fix this mid-session.

echo "=== LIVE MCP PROCESS CHECK ==="
echo ""

python3 - "$TARGET_MARKETPLACE" "$CACHE_DIR" <<'PYEOF'
import json, os, re, subprocess, sys

target_marketplace = sys.argv[1]
cache_dir = sys.argv[2]
installed_file = os.path.expanduser("~/.claude/plugins/installed_plugins.json")

try:
    with open(installed_file) as f:
        installed = json.load(f)
except Exception:
    print("Could not read installed_plugins.json")
    sys.exit(0)

# Snapshot all running node process command lines
try:
    ps = subprocess.run(["ps", "aux"], capture_output=True, text=True, timeout=5)
    ps_output = ps.stdout
except Exception:
    print("Could not inspect running processes")
    sys.exit(0)

# Path pattern: .../cache/<marketplace>/<plugin>/<version>/...
path_re = re.compile(
    rf"({re.escape(os.path.expanduser('~/.claude/plugins/cache'))}"
    rf"/{re.escape(target_marketplace)}/([^/]+)/([^/\s]+)/)"
)

# Build map: plugin_name → set of running version strings
live_versions: dict[str, set[str]] = {}
for match in path_re.finditer(ps_output):
    plugin_name = match.group(2)
    version = match.group(3)
    live_versions.setdefault(plugin_name, set()).add(version)

found_any = False
for plugin_key, entries in installed["plugins"].items():
    if not entries or not plugin_key.endswith(f"@{target_marketplace}"):
        continue
    entry = entries[0]
    installed_version = entry.get("version", "unknown")
    plugin_name = plugin_key.rsplit("@", 1)[0]

    running = live_versions.get(plugin_name)
    if not running:
        print(f"NOT_RUNNING  {plugin_key}: installed={installed_version} (no live process found)")
        found_any = True
        continue

    running_version = next(iter(running))  # typically one process
    if running_version != installed_version:
        install_path = entry.get("installPath", "")
        live_path_match = path_re.search(ps_output)
        print(
            f"LIVE_SKEW  {plugin_key}: running={running_version}  installed={installed_version}\n"
            f"  Running dist: {os.path.expanduser('~/.claude/plugins/cache')}/{target_marketplace}/{plugin_name}/{running_version}/\n"
            f"  Installed at: {install_path}\n"
            f"  Fix: cp <installed>/dist/index.js <running>/dist/index.js  then kill the process"
        )
    else:
        print(f"LIVE_OK  {plugin_key}: running={running_version}")
    found_any = True

if not found_any:
    print(f"No {target_marketplace} plugins installed.")
PYEOF

echo ""
echo "=== DONE ==="
