#!/usr/bin/env bash
# check-gitignore.sh — Check 1 of 5 in the repo-hygiene sweep.
# Scans all non-auto-generated .gitignore files for:
#   - Missing patterns (node_modules, Python cache) — auto-fixable
# Called from repo root by the /hygiene command. Emits one JSON object on stdout.
# Non-zero exit + stderr message on failure.
#
# NOTE: .claude/state/ coverage check was intentionally omitted — the root
# .gitignore already has **/.claude/state/ which covers all plugin subdirectories
# via gitignore inheritance. A per-plugin check would be redundant.
#
# NOTE: Stale pattern detection was intentionally removed. Defensive patterns
# (.env, .DS_Store, .vscode/, etc.) are valid even when no matching file currently
# exists in the working tree, so any git ls-files based stale check produces
# systematic false positives against well-maintained .gitignore files.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

python3 - "$REPO_ROOT" << 'PYEOF'
import sys
import os
import json

repo_root = sys.argv[1]

def rel(path):
    """Convert absolute path to repo-root-relative."""
    return os.path.relpath(path, repo_root)

def is_auto_generated(gitignore_path):
    """Return True if ALL non-empty, non-comment lines are just '*'.

    Matches pytest-generated .gitignore files that only contain '*'.
    """
    with open(gitignore_path) as f:
        lines = f.readlines()
    content_lines = [l.strip() for l in lines if l.strip() and not l.strip().startswith('#')]
    if not content_lines:
        return False
    return all(l == '*' for l in content_lines)

def get_patterns(gitignore_path):
    """Return all non-empty, non-comment lines from a .gitignore."""
    with open(gitignore_path) as f:
        return [l.strip() for l in f if l.strip() and not l.strip().startswith('#')]

def python_files_exist_nearby(directory):
    """Check for *.py files up to 3 levels deep under directory."""
    for root, dirs, files in os.walk(directory):
        depth = root[len(directory):].count(os.sep)
        if depth >= 3:
            dirs.clear()
            continue
        if any(f.endswith('.py') for f in files):
            return True
    return False

def has_python_cache_pattern(patterns):
    """Return True if any of the Python cache patterns are present."""
    for p in patterns:
        if p in ('__pycache__/', '*.pyc', '*.py[cod]', '__pycache__'):
            return True
    return False

def find_gitignores():
    """Walk repo and find all .gitignore files, excluding auto-generated ones."""
    result = []
    for root, dirs, files in os.walk(repo_root):
        # Skip .git directory
        dirs[:] = [d for d in dirs if d != '.git']
        if '.gitignore' in files:
            path = os.path.join(root, '.gitignore')
            if not is_auto_generated(path):
                result.append(path)
    return sorted(result)

findings = []

for gi_path in find_gitignores():
    gi_dir = os.path.dirname(gi_path)
    gi_rel = rel(gi_path)
    gi_abs = gi_path  # absolute path for use in fix_cmd to avoid CWD sensitivity
    is_root_gi = (gi_dir == repo_root)
    patterns = get_patterns(gi_path)

    # ── Missing pattern checks (auto-fixable) ─────────────────────────────
    # node_modules/ — only if package.json exists in the same directory
    # Skip root .gitignore (already covers it globally)
    if not is_root_gi:
        pkg_json = os.path.join(gi_dir, 'package.json')
        if os.path.isfile(pkg_json):
            if 'node_modules/' not in patterns and 'node_modules' not in patterns:
                findings.append({
                    'severity': 'warn',
                    'path': gi_rel,
                    'detail': "package.json present but 'node_modules/' not in .gitignore",
                    'auto_fix': True,
                    'fix_cmd': f"echo 'node_modules/' >> '{gi_abs}'",
                })

    # Python cache — if *.py files exist in tree (up to 3 levels)
    # Skip root .gitignore (already covers __pycache__/ and *.py[cod] globally)
    if not is_root_gi:
        if python_files_exist_nearby(gi_dir):
            if not has_python_cache_pattern(patterns):
                findings.append({
                    'severity': 'warn',
                    'path': gi_rel,
                    'detail': "Python files detected but no __pycache__/ or *.pyc pattern in .gitignore",
                    'auto_fix': True,
                    'fix_cmd': f"printf '__pycache__/\\n*.pyc\\n' >> '{gi_abs}'",
                })

print(json.dumps({'check': 'gitignore', 'findings': findings}, indent=2))
PYEOF
