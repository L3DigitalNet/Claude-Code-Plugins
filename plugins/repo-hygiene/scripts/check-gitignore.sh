#!/usr/bin/env bash
# check-gitignore.sh — Check 1 of 5 in the repo-hygiene sweep.
# Scans all non-auto-generated .gitignore files for:
#   - Missing patterns (node_modules, Python cache) — auto-fixable
#   - Stale patterns that match nothing in the repo — needs-approval
# Called from repo root by the /hygiene command. Emits one JSON object on stdout.
# Non-zero exit + stderr message on failure.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

python3 - "$REPO_ROOT" << 'PYEOF'
import sys
import os
import subprocess
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

def pattern_has_glob(pattern):
    """Patterns with * or ** are unreliable to test — skip them in stale check."""
    return '*' in pattern

def pattern_is_negation(pattern):
    return pattern.startswith('!')

def pattern_matches_something(pattern, gitignore_dir):
    """Check if pattern matches any untracked-ignored or cached-ignored file.
    
    Returns True if the pattern is active (matches something), False if stale.
    Uses git -C to run relative to the .gitignore's directory.
    """
    try:
        # Check untracked files that would be ignored
        r1 = subprocess.run(
            ['git', '-C', gitignore_dir, 'ls-files', '--others', '--ignored',
             '--exclude=' + pattern, '--directory'],
            capture_output=True, text=True, timeout=10
        )
        if r1.returncode == 0 and r1.stdout.strip():
            return True
        # Check cached (tracked) files that match the ignore pattern
        r2 = subprocess.run(
            ['git', '-C', gitignore_dir, 'ls-files', '--cached', '-i',
             '--exclude=' + pattern],
            capture_output=True, text=True, timeout=10
        )
        if r2.returncode == 0 and r2.stdout.strip():
            return True
    except (subprocess.TimeoutExpired, OSError):
        # On error, assume it matches (avoid false stale positives)
        return True
    return False

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
is_root = True  # first .gitignore encountered will be the root one (sorted, root comes first)

for gi_path in find_gitignores():
    gi_dir = os.path.dirname(gi_path)
    gi_rel = rel(gi_path)
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
                    'fix_cmd': f"echo 'node_modules/' >> {gi_rel}",
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
                    'fix_cmd': f"printf '__pycache__/\\n*.pyc\\n' >> {gi_rel}",
                })

    # ── Stale pattern checks (needs-approval) ─────────────────────────────
    for pattern in patterns:
        # Skip negations, globs, and empty — unreliable or special-purpose
        if pattern_is_negation(pattern):
            continue
        if pattern_has_glob(pattern):
            continue
        if not pattern:
            continue

        if not pattern_matches_something(pattern, gi_dir):
            findings.append({
                'severity': 'warn',
                'path': gi_rel,
                'detail': f"Pattern '{pattern}' appears stale — matches no tracked or ignorable files",
                'auto_fix': False,
                'fix_cmd': None,
            })

print(json.dumps({'check': 'gitignore', 'findings': findings}, indent=2))
PYEOF
