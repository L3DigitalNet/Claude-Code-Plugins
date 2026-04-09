#!/usr/bin/env bash
# detect-project.sh — Detect project type and matching test-driver profile.
#
# Usage: detect-project.sh [scope-directory]
# Output: JSON with project_type, profile, markers_found, confidence.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

SCOPE="${1:-.}"
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PROFILES_DIR="$PLUGIN_ROOT/references/profiles"

$PYTHON - "$SCOPE" "$PROFILES_DIR" << 'PYEOF'
import json, os, sys

scope = sys.argv[1]
profiles_dir = sys.argv[2]

# Marker files checked in priority order (first match wins)
MARKERS = [
    ("pyproject.toml", "python"),
    ("setup.py", "python"),
    ("requirements.txt", "python"),
    ("Package.swift", "swift-swiftui"),
    ("package.json", "javascript"),
    ("Cargo.toml", "rust"),
    ("go.mod", "go"),
    ("pom.xml", "java"),
    ("build.gradle", "java"),
    (".claude-plugin/plugin.json", "claude-plugin"),
]

ALL_MARKER_FILES = [m[0] for m in MARKERS]

markers_found = []
secondary_markers = []
project_type = None
confidence = "none"

# Check each marker at scope root only (not recursive)
for marker_file, ptype in MARKERS:
    path = os.path.join(scope, marker_file)
    if os.path.exists(path):
        markers_found.append(marker_file)
        if project_type is None:
            project_type = ptype
            confidence = "high"

# Collect secondary markers (found after primary match)
if len(markers_found) > 1:
    secondary_markers = markers_found[1:]

# Python sub-classification
if project_type == "python":
    pyproject = os.path.join(scope, "pyproject.toml")
    setup_py = os.path.join(scope, "setup.py")
    reqs = os.path.join(scope, "requirements.txt")
    hacs = os.path.join(scope, "hacs.json")

    deps_text = ""
    for f in [pyproject, setup_py, reqs]:
        if os.path.exists(f):
            try:
                with open(f, errors="replace") as fh:
                    deps_text += fh.read().lower()
            except Exception:
                pass

    if os.path.exists(hacs) or "homeassistant" in deps_text or "home-assistant" in deps_text:
        project_type = "home-assistant"
    elif "fastapi" in deps_text or "uvicorn" in deps_text:
        project_type = "python-fastapi"
    elif "django" in deps_text:
        project_type = "python-django"
    elif "pyside6" in deps_text or "pyqt6" in deps_text:
        project_type = "python-pyside6"
    else:
        confidence = "medium"

elif project_type == "javascript":
    # Check for TypeScript
    tsconfig = os.path.join(scope, "tsconfig.json")
    if os.path.exists(tsconfig):
        project_type = "typescript"

# Find matching profile
profile = None
if project_type:
    profile_file = f"{project_type}.md"
    if os.path.exists(os.path.join(profiles_dir, profile_file)):
        profile = profile_file
    else:
        # Try without sub-type
        base = project_type.split("-")[0]
        for f in os.listdir(profiles_dir):
            if f.startswith(base) and f.endswith(".md"):
                profile = f
                break

result = {
    "project_type": project_type,
    "profile": profile,
    "markers_found": markers_found,
    "markers_checked": ALL_MARKER_FILES,
    "confidence": confidence,
    "secondary_markers": secondary_markers,
}

print(json.dumps(result, indent=2))
PYEOF
