#!/usr/bin/env bash
# inventory-tests.sh — Find test files, categorize by type, count tests.
#
# Usage: inventory-tests.sh <project-type> [scope-directory]
# Output: JSON with test_files array, by_category breakdown, totals.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

PROJECT_TYPE="${1:?Usage: inventory-tests.sh <project-type> [scope-dir]}"
SCOPE="${2:-.}"

$PYTHON - "$PROJECT_TYPE" "$SCOPE" << 'PYEOF'
import json, os, re, sys

project_type = sys.argv[1]
scope = sys.argv[2]

# Language config
LANG_CONFIG = {
    "python": {
        "extensions": {".py"},
        "exclude_dirs": {"__pycache__", "venv", ".venv", "node_modules", ".tox"},
        "test_file_patterns": [r"test_.*\.py$", r".*_test\.py$", r"conftest\.py$"],
        "test_func_re": re.compile(r"^\s*(?:async\s+)?def\s+(test_\w+)", re.MULTILINE),
        "marker_re": re.compile(r"@pytest\.mark\.(unit|integration|e2e|slow)", re.MULTILINE),
    },
    "swift": {
        "extensions": {".swift"},
        "exclude_dirs": {".build", "Build", "DerivedData"},
        "test_file_patterns": [r".*Tests\.swift$", r".*Spec\.swift$"],
        "test_func_re": re.compile(r"^\s*func\s+(test\w+)", re.MULTILINE),
        "marker_re": None,
    },
    "javascript": {
        "extensions": {".js", ".jsx", ".mjs"},
        "exclude_dirs": {"node_modules", "dist", "build", "coverage"},
        "test_file_patterns": [r".*\.test\.js$", r".*\.spec\.js$"],
        "test_func_re": re.compile(r"""(?:it|test)\s*\(\s*['"]""", re.MULTILINE),
        "marker_re": None,
    },
    "typescript": {
        "extensions": {".ts", ".tsx"},
        "exclude_dirs": {"node_modules", "dist", "build", "coverage"},
        "test_file_patterns": [r".*\.test\.ts$", r".*\.spec\.ts$"],
        "test_func_re": re.compile(r"""(?:it|test)\s*\(\s*['"]""", re.MULTILINE),
        "marker_re": None,
    },
    "rust": {
        "extensions": {".rs"},
        "exclude_dirs": {"target"},
        "test_file_patterns": [r".*_test\.rs$"],
        "test_func_re": re.compile(r"#\[test\]", re.MULTILINE),
        "marker_re": None,
    },
    "go": {
        "extensions": {".go"},
        "exclude_dirs": {"vendor"},
        "test_file_patterns": [r".*_test\.go$"],
        "test_func_re": re.compile(r"^func\s+(Test\w+)", re.MULTILINE),
        "marker_re": None,
    },
    "java": {
        "extensions": {".java"},
        "exclude_dirs": {"target", "build"},
        "test_file_patterns": [r".*Test\.java$", r".*Tests\.java$"],
        "test_func_re": re.compile(r"@Test", re.MULTILINE),
        "marker_re": None,
    },
}

base = project_type.split("-")[0] if "-" in project_type else project_type
if project_type in ("home-assistant", "python-fastapi", "python-django", "python-pyside6"):
    base = "python"
elif project_type in ("swift-swiftui",):
    base = "swift"

config = LANG_CONFIG.get(base, LANG_CONFIG.get("python"))

# Category detection heuristics
CATEGORY_DIR_PATTERNS = {
    "unit": re.compile(r"(?:^|/)(?:unit|tests?/unit)/", re.IGNORECASE),
    "integration": re.compile(r"(?:^|/)(?:integration|tests?/integration)/", re.IGNORECASE),
    "e2e": re.compile(r"(?:^|/)(?:e2e|end.to.end|tests?/e2e)/", re.IGNORECASE),
}

CATEGORY_FILE_PATTERNS = {
    "integration": re.compile(r"(?:test_integration_|integration_test)", re.IGNORECASE),
    "e2e": re.compile(r"(?:e2e_|_e2e)", re.IGNORECASE),
}

def categorize(relpath, content, config):
    """Determine test category from path, content markers, or filename."""
    # 1. Directory name
    for cat, pat in CATEGORY_DIR_PATTERNS.items():
        if pat.search(relpath):
            return cat

    # 2. Pytest markers in content
    if config.get("marker_re"):
        markers = config["marker_re"].findall(content)
        if markers:
            return markers[0]  # First marker wins

    # 3. File name patterns
    for cat, pat in CATEGORY_FILE_PATTERNS.items():
        if pat.search(os.path.basename(relpath)):
            return cat

    return "uncategorized"

test_files = []
by_category = {}

for root, dirs, files in os.walk(scope, followlinks=False):
    dirs[:] = [d for d in dirs if d not in config["exclude_dirs"] and not d.startswith(".")]

    for fname in sorted(files):
        ext = os.path.splitext(fname)[1]
        if ext not in config["extensions"]:
            continue

        filepath = os.path.join(root, fname)
        relpath = os.path.relpath(filepath, scope)

        # Check if it matches test file patterns
        is_test = False
        for pat in config["test_file_patterns"]:
            if re.search(pat, relpath):
                is_test = True
                break

        # Also check if file is in a tests/ or test/ directory
        if not is_test and re.search(r"(?:^|/)tests?/", relpath):
            is_test = True

        if not is_test:
            continue

        try:
            with open(filepath, errors="replace") as f:
                content = f.read()
            test_count = len(config["test_func_re"].findall(content))
        except Exception:
            content = ""
            test_count = 0

        category = categorize(relpath, content, config)

        test_files.append({
            "path": relpath,
            "category": category,
            "test_count": test_count,
        })

        if category not in by_category:
            by_category[category] = {"files": 0, "tests": 0}
        by_category[category]["files"] += 1
        by_category[category]["tests"] += test_count

# Ensure standard categories exist in output
for cat in ("unit", "integration", "e2e"):
    if cat not in by_category:
        by_category[cat] = {"files": 0, "tests": 0}

result = {
    "test_files": test_files,
    "by_category": by_category,
    "total_files": len(test_files),
    "total_tests": sum(f["test_count"] for f in test_files),
}

print(json.dumps(result, indent=2))
PYEOF
