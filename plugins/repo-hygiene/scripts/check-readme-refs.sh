#!/usr/bin/env bash
# check-readme-refs.sh — Validates that paths and references in plugin README.md
# files point to files/directories that actually exist. Catches stale references
# after renames, deletions, or restructuring.
#
# Extracts three kinds of references:
#   1. Backtick-delimited paths starting with known plugin directories
#   2. Relative markdown links [text](./path)
#   3. /plugin:command references checked against commands/ directory
#
# Fenced code blocks are stripped before extraction to avoid false positives
# from example snippets.
#
# Called by the /hygiene command in parallel with other check scripts.
# Output contract: JSON {"check": "readme-refs", "findings": [...]} to stdout.
set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
    echo '{"check":"readme-refs","findings":[]}'
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

# Known plugin-internal directory prefixes — paths starting with these are
# treated as references to actual files, not generic examples.
KNOWN_DIRS = (
    "commands/", "scripts/", "skills/", "agents/", "hooks/",
    "templates/", "tests/", "src/", "dist/", "docs/",
    ".claude-plugin/",
)

# Patterns to skip: URLs, shell variables, glob-only patterns
SKIP_PATTERNS = [
    re.compile(r'^https?://'),
    re.compile(r'^\$'),            # shell variables like $REPO_ROOT/...
    re.compile(r'^~'),             # home dir references
    re.compile(r'[*?]'),           # glob patterns
    re.compile(r'^<'),             # HTML/placeholder tags
]


def strip_fenced_blocks(text):
    """Remove fenced code blocks (``` ... ```) to avoid matching example paths."""
    return re.sub(r'```[^\n]*\n.*?```', '', text, flags=re.DOTALL)


def is_skippable(path):
    """Return True if the path looks like a URL, variable, or generic example."""
    for pat in SKIP_PATTERNS:
        if pat.search(path):
            return True
    return False


def extract_backtick_paths(text):
    """Extract backtick-delimited paths that start with known directories."""
    paths = set()
    for m in re.finditer(r'`([^`]+)`', text):
        candidate = m.group(1).strip()
        if any(candidate.startswith(d) for d in KNOWN_DIRS):
            if not is_skippable(candidate):
                paths.add(candidate)
    return paths


def extract_relative_links(text):
    """Extract relative markdown link targets: [text](./path) or [text](path)."""
    paths = set()
    for m in re.finditer(r'\[([^\]]*)\]\(([^)]+)\)', text):
        target = m.group(2).strip()
        # Skip URLs and anchors
        if target.startswith('http') or target.startswith('#') or target.startswith('mailto:'):
            continue
        if is_skippable(target):
            continue
        paths.add(target)
    return paths


def extract_command_refs(text, plugin_name):
    """Extract /plugin:command references and return expected command file paths."""
    refs = {}
    # Match /plugin-name:command or /command patterns in backticks
    pattern = re.compile(r'`/(' + re.escape(plugin_name) + r':)?([a-zA-Z][\w-]*)`')
    for m in pattern.finditer(text):
        has_prefix = m.group(1) is not None
        cmd_name = m.group(2)
        # Only check commands with plugin prefix, or bare /name if not a common word
        if has_prefix:
            refs[f"/{plugin_name}:{cmd_name}"] = cmd_name
    return refs


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

    # Strip fenced code blocks before extracting references
    stripped_text = strip_fenced_blocks(readme_text)

    checked = set()  # deduplicate

    # 1. Backtick-delimited paths relative to plugin directory
    for ref_path in sorted(extract_backtick_paths(stripped_text)):
        abs_path = os.path.join(plugin_dir, ref_path)
        if abs_path in checked:
            continue
        checked.add(abs_path)
        if not os.path.exists(abs_path):
            findings.append({
                "severity": "warn",
                "path": rel_readme,
                "detail": f"References `{ref_path}` which does not exist on disk",
                "auto_fix": False,
            })

    # 2. Relative markdown links
    for ref_path in sorted(extract_relative_links(stripped_text)):
        # Resolve relative to the README's directory (the plugin dir)
        # Strip anchor fragments
        clean_path = ref_path.split('#')[0]
        if not clean_path:
            continue
        if clean_path.startswith('./'):
            clean_path = clean_path[2:]
        abs_path = os.path.normpath(os.path.join(plugin_dir, clean_path))
        if abs_path in checked:
            continue
        checked.add(abs_path)
        if not os.path.exists(abs_path):
            findings.append({
                "severity": "warn",
                "path": rel_readme,
                "detail": f"Relative link [{clean_path}] target does not exist",
                "auto_fix": False,
            })

    # 3. /plugin:command references
    cmd_refs = extract_command_refs(stripped_text, name)
    commands_dir = os.path.join(plugin_dir, "commands")
    for ref_label, cmd_name in sorted(cmd_refs.items()):
        # Check for commands/cmd_name.md or commands/cmd_name/ directory
        md_path = os.path.join(commands_dir, cmd_name + ".md")
        dir_path = os.path.join(commands_dir, cmd_name)
        check_key = f"cmd:{cmd_name}"
        if check_key in checked:
            continue
        checked.add(check_key)
        if not os.path.isfile(md_path) and not os.path.isdir(dir_path):
            findings.append({
                "severity": "warn",
                "path": rel_readme,
                "detail": f"References command `{ref_label}` but commands/{cmd_name}.md not found",
                "auto_fix": False,
            })

print(json.dumps({"check": "readme-refs", "findings": findings}, indent=2))
PYEOF
