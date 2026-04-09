#!/usr/bin/env bash
# check-readme-structure.sh — Validates plugin README.md files against the canonical
# template (docs/plugin-readme-template.md). Checks for required section headings,
# component-specific headings inferred from directory structure, and conditional
# Requirements section based on dependency manifests.
#
# Called by the /hygiene command in parallel with other check scripts.
# Output contract: JSON {"check": "readme-structure", "findings": [...]} to stdout.
set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
    echo '{"check":"readme-structure","findings":[]}'
    exit 0
fi

"$PYTHON" - "$REPO_ROOT" "$MARKETPLACE" << 'PYEOF'
import sys
import os
import json
import re

repo_root = sys.argv[1]
marketplace_path = sys.argv[2]

with open(marketplace_path) as f:
    marketplace = json.load(f)

findings = []

def finding(path, detail):
    findings.append({
        "severity": "warn",
        "path": path,
        "detail": detail,
        "auto_fix": False,
    })

# Headings that every plugin README must have. Values are synonym groups:
# if any synonym in the group matches a heading in the README, that requirement is satisfied.
REQUIRED_HEADINGS = {
    "Summary": ["Summary"],
    "Principles": ["Principles", "Design Principles"],
    "Installation": ["Installation"],
    "How It Works": ["How It Works", "Architecture", "Design", "Overview"],
    "Usage": ["Usage"],
    "Planned Features": ["Planned Features", "Roadmap"],
    "Known Issues": ["Known Issues"],
    "Links": ["Links"],
}

# Component directories that imply a corresponding heading must exist
COMPONENT_HEADINGS = {
    "commands":  "Commands",
    "skills":    "Skills",
    "agents":    "Agents",
    "hooks":     "Hooks",
}

# Files whose presence makes the Requirements heading mandatory
DEPENDENCY_FILES = [".mcp.json", "package.json", "pyproject.toml"]


def extract_headings(readme_text):
    """Return a set of heading titles (stripped, any level) from markdown."""
    headings = set()
    for line in readme_text.splitlines():
        m = re.match(r'^#{1,6}\s+(.+)$', line)
        if m:
            headings.add(m.group(1).strip())
    return headings


for plugin in marketplace.get("plugins", []):
    name = plugin.get("name", "<unnamed>")
    source = plugin.get("source", "")

    if source.startswith("./") or source.startswith("../"):
        plugin_dir = os.path.normpath(os.path.join(repo_root, source))
    else:
        plugin_dir = source

    readme_path = os.path.join(plugin_dir, "README.md")
    rel_readme = os.path.relpath(readme_path, repo_root)

    if not os.path.isfile(readme_path):
        finding(rel_readme, f"Plugin '{name}' has no README.md")
        continue

    with open(readme_path) as f:
        readme_text = f.read()

    headings = extract_headings(readme_text)

    # Check required headings (with synonym matching)
    for req_name, synonyms in REQUIRED_HEADINGS.items():
        if not any(s in headings for s in synonyms):
            if len(synonyms) > 1:
                alts = " (or: " + ", ".join(synonyms[1:]) + ")"
            else:
                alts = ""
            finding(
                rel_readme,
                f"Missing required section '{req_name}'{alts}",
            )

    # Check Requirements heading — conditional on dependency files
    has_deps = any(
        os.path.isfile(os.path.join(plugin_dir, dep))
        for dep in DEPENDENCY_FILES
    )
    if has_deps and "Requirements" not in headings:
        triggers = [
            dep for dep in DEPENDENCY_FILES
            if os.path.isfile(os.path.join(plugin_dir, dep))
        ]
        finding(
            rel_readme,
            f"Missing 'Requirements' section (has {', '.join(triggers)})",
        )

    # Check component-specific headings based on directory presence
    for comp_dir, heading_name in COMPONENT_HEADINGS.items():
        comp_path = os.path.join(plugin_dir, comp_dir)
        if os.path.isdir(comp_path):
            # Check the directory actually has files (not just empty)
            has_files = any(
                f for f in os.listdir(comp_path)
                if not f.startswith('.')
            )
            if has_files and heading_name not in headings:
                finding(
                    rel_readme,
                    f"Has '{comp_dir}/' directory but no '{heading_name}' section in README",
                )

print(json.dumps({"check": "readme-structure", "findings": findings}, indent=2))
PYEOF
