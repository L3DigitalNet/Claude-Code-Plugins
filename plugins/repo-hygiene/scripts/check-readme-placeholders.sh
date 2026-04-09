#!/usr/bin/env bash
# check-readme-placeholders.sh — Detects unmodified template placeholder text in
# plugin README.md files. Catches boilerplate that was copied from the template
# but never replaced with actual content.
#
# Called by the /hygiene command in parallel with other check scripts.
# Output contract: JSON {"check": "readme-placeholders", "findings": [...]} to stdout.
set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
    echo '{"check":"readme-placeholders","findings":[]}'
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

# Literal strings that indicate unmodified template content
LITERAL_PLACEHOLDERS = [
    "One-sentence description",
    "Brief paragraph expanding",
    "Feature one",
    "Feature two",
    "Feature three",
    "Issue title",
    "Principle Name",
    "Step one",
    "Step two",
    "Step three",
    "skill-name",
    "agent-name",
    "What it does and when to use it",
    "What the user can do and why it matters",
]

# Patterns matched via regex (case-insensitive)
REGEX_PLACEHOLDERS = [
    (re.compile(r'\bTODO\b'), "TODO"),
    (re.compile(r'\bFIXME\b'), "FIXME"),
    (re.compile(r'\bPLACEHOLDER\b', re.IGNORECASE), "PLACEHOLDER"),
]


def is_sole_content(line, token):
    """Return True if the token is effectively the only content in a table cell or bullet.

    Catches patterns like: | `/command-name` | or - `/command-name`
    """
    stripped = line.strip()
    # Strip markdown bullet prefix
    stripped = re.sub(r'^[-*+]\s+', '', stripped)
    # Strip table cell delimiters and whitespace
    stripped = stripped.strip('|').strip()
    # Strip backticks
    stripped = stripped.strip('`').strip()
    return stripped == token


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
        continue

    with open(readme_path) as f:
        readme_text = f.read()

    seen = set()  # deduplicate per-plugin

    # Check literal placeholders
    for placeholder in LITERAL_PLACEHOLDERS:
        if placeholder in readme_text and placeholder not in seen:
            seen.add(placeholder)
            findings.append({
                "severity": "warn",
                "path": rel_readme,
                "detail": f"Contains template placeholder: '{placeholder}'",
                "auto_fix": False,
            })

    # Check regex placeholders
    for pattern, label in REGEX_PLACEHOLDERS:
        if pattern.search(readme_text) and label not in seen:
            seen.add(label)
            findings.append({
                "severity": "warn",
                "path": rel_readme,
                "detail": f"Contains placeholder marker: '{label}'",
                "auto_fix": False,
            })

    # Check /command-name — only flag when it's the sole content of a cell or bullet
    for line in readme_text.splitlines():
        if "/command-name" in line and is_sole_content(line, "/command-name"):
            if "/command-name" not in seen:
                seen.add("/command-name")
                findings.append({
                    "severity": "warn",
                    "path": rel_readme,
                    "detail": "Contains template placeholder: '/command-name' as sole cell/bullet content",
                    "auto_fix": False,
                })
            break

    # Check bare "..." (three dots as sole content of a bullet/cell, not part of prose)
    for line in readme_text.splitlines():
        stripped = line.strip()
        # Match bullets or table cells that contain only "..."
        cell_content = re.sub(r'^[-*+]\s+', '', stripped)
        cell_content = cell_content.strip('|').strip().strip('`').strip()
        if cell_content == "..." and "..." not in seen:
            seen.add("...")
            findings.append({
                "severity": "info",
                "path": rel_readme,
                "detail": "Contains placeholder ellipsis '...' as sole cell/bullet content",
                "auto_fix": False,
            })
            break

print(json.dumps({"check": "readme-placeholders", "findings": findings}, indent=2))
PYEOF
