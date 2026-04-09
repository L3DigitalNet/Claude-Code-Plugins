#!/usr/bin/env bash
# inventory-sources.sh — Find all non-test source files with metadata.
#
# Usage: inventory-sources.sh <project-type> [scope-directory]
# Output: JSON with source_files array, counts, and function approximations.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

PROJECT_TYPE="${1:?Usage: inventory-sources.sh <project-type> [scope-dir]}"
SCOPE="${2:-.}"

$PYTHON - "$PROJECT_TYPE" "$SCOPE" << 'PYEOF'
import json, os, re, sys

project_type = sys.argv[1]
scope = sys.argv[2]

MAX_FILES = 5000

# Language config: extensions, exclusions, test patterns, function regex
LANG_CONFIG = {
    "python": {
        "extensions": {".py"},
        "exclude_dirs": {"__pycache__", "migrations", "build", "dist", "venv", ".venv",
                         "node_modules", ".tox", ".mypy_cache", ".pytest_cache", "egg-info"},
        "test_patterns": [r"test_.*\.py$", r".*_test\.py$", r"conftest\.py$"],
        "func_re": re.compile(r"^\s*(async\s+)?def\s+\w+", re.MULTILINE),
    },
    "swift": {
        "extensions": {".swift"},
        "exclude_dirs": {".build", "Build", "DerivedData", "Pods"},
        "test_patterns": [r".*Tests\.swift$", r".*Spec\.swift$"],
        "func_re": re.compile(r"^\s*(?:public|private|internal|open|fileprivate)?\s*(?:static\s+)?func\s+\w+", re.MULTILINE),
    },
    "javascript": {
        "extensions": {".js", ".jsx", ".mjs"},
        "exclude_dirs": {"node_modules", "dist", "build", ".next", "coverage"},
        "test_patterns": [r".*\.test\.js$", r".*\.spec\.js$", r"__tests__/"],
        "func_re": re.compile(
            r"^\s*(?:export\s+)?(?:async\s+)?function\s+\w+"
            r"|^\s*(?:export\s+)?(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(",
            re.MULTILINE
        ),
    },
    "typescript": {
        "extensions": {".ts", ".tsx"},
        "exclude_dirs": {"node_modules", "dist", "build", ".next", "coverage"},
        "test_patterns": [r".*\.test\.ts$", r".*\.spec\.ts$", r"__tests__/"],
        "func_re": re.compile(
            r"^\s*(?:export\s+)?(?:async\s+)?function\s+\w+"
            r"|^\s*(?:export\s+)?(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(",
            re.MULTILINE
        ),
    },
    "rust": {
        "extensions": {".rs"},
        "exclude_dirs": {"target", ".cargo"},
        "test_patterns": [r".*_test\.rs$", r"tests/"],
        "func_re": re.compile(r"^\s*(?:pub(?:\(.*\))?\s+)?(?:async\s+)?fn\s+\w+", re.MULTILINE),
    },
    "go": {
        "extensions": {".go"},
        "exclude_dirs": {"vendor"},
        "test_patterns": [r".*_test\.go$"],
        "func_re": re.compile(r"^func\s+(?:\(.*\)\s+)?\w+", re.MULTILINE),
    },
    "java": {
        "extensions": {".java"},
        "exclude_dirs": {"target", "build", ".gradle", "bin"},
        "test_patterns": [r".*Test\.java$", r".*Tests\.java$"],
        "func_re": re.compile(r"^\s*(?:public|private|protected)?\s*(?:static\s+)?(?:\w+\s+)+\w+\s*\(", re.MULTILINE),
    },
}

# Resolve project type to base language
base = project_type.split("-")[0] if "-" in project_type else project_type
if project_type in ("home-assistant", "python-fastapi", "python-django", "python-pyside6"):
    base = "python"
elif project_type in ("swift-swiftui",):
    base = "swift"
elif project_type == "claude-plugin":
    # Plugin projects can have JS/TS/Python - check what exists
    for lang in ("typescript", "javascript", "python"):
        cfg = LANG_CONFIG[lang]
        for root, dirs, files in os.walk(scope, followlinks=False):
            for f in files:
                if os.path.splitext(f)[1] in cfg["extensions"]:
                    base = lang
                    break
            if base != "claude-plugin":
                break

config = LANG_CONFIG.get(base, LANG_CONFIG.get("python"))

source_files = []
truncated = False
excluded = sorted(config["exclude_dirs"])

for root, dirs, files in os.walk(scope, followlinks=False):
    # Prune excluded directories
    dirs[:] = [d for d in dirs if d not in config["exclude_dirs"] and not d.startswith(".")]

    for fname in sorted(files):
        ext = os.path.splitext(fname)[1]
        if ext not in config["extensions"]:
            continue

        filepath = os.path.join(root, fname)
        relpath = os.path.relpath(filepath, scope)

        # Skip test files
        is_test = False
        for pat in config["test_patterns"]:
            if re.search(pat, relpath):
                is_test = True
                break
        if is_test:
            continue

        if len(source_files) >= MAX_FILES:
            truncated = True
            break

        try:
            with open(filepath, errors="replace") as f:
                content = f.read()
            lines = content.count("\n") + (1 if content and not content.endswith("\n") else 0)
            func_count = len(config["func_re"].findall(content))
        except Exception:
            lines = 0
            func_count = 0

        source_files.append({
            "path": relpath,
            "lines": lines,
            "function_approx": func_count,
        })

    if truncated:
        break

total_lines = sum(f["lines"] for f in source_files)
total_funcs = sum(f["function_approx"] for f in source_files)

result = {
    "source_files": source_files,
    "total_files": len(source_files),
    "total_lines": total_lines,
    "total_functions_approx": total_funcs,
    "counting": "approximate",
    "excluded_patterns": excluded,
    "truncated": truncated,
}

print(json.dumps(result, indent=2))
PYEOF
