#!/usr/bin/env bash
# check-prerequisites.sh — Verifies all runtime dependencies for the qt-suite plugin.
# Called by /qt-suite:visual and /qt-suite:coverage before they execute; exits 0 if all OK,
# exits 1 with human-readable instructions if anything is missing. Detects distro automatically.
set -euo pipefail

ERRORS=()
WARNINGS=()

# Python — required; 3.10+ for match-statement compatibility
if ! command -v python3 &>/dev/null; then
    ERRORS+=("python3 not found — install Python 3.10+")
else
    PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
        ERRORS+=("Python ${PY_VERSION} is too old — Python 3.10+ required")
    fi
fi

# Xvfb — required for headless GUI testing
if ! command -v Xvfb &>/dev/null; then
    # Detect distro and give the right install command
    if command -v apt-get &>/dev/null; then
        INSTALL_CMD="sudo apt-get install -y xvfb"
    elif command -v dnf &>/dev/null; then
        INSTALL_CMD="sudo dnf install -y xorg-x11-server-Xvfb"
    elif command -v pacman &>/dev/null; then
        INSTALL_CMD="sudo pacman -S xorg-server-xvfb"
    elif command -v brew &>/dev/null; then
        INSTALL_CMD="brew install --cask xquartz  # then use QT_QPA_PLATFORM=offscreen instead"
    else
        INSTALL_CMD="install xvfb via your package manager"
    fi
    ERRORS+=("Xvfb not found — headless GUI testing requires it: ${INSTALL_CMD}")
fi

# CMake — optional; required for C++ Qt projects
if ! command -v cmake &>/dev/null; then
    WARNINGS+=("cmake not found — required for C++ Qt projects (/qt-suite:run, /qt-suite:coverage)")
fi

# lcov / gcov — optional; required for C++ coverage reports
if ! command -v lcov &>/dev/null; then
    WARNINGS+=("lcov not found — required for C++ coverage reports (/qt-suite:coverage). Install: apt install lcov / dnf install lcov")
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "qt-suite: MISSING REQUIRED DEPENDENCIES" >&2
    for err in "${ERRORS[@]}"; do
        echo "  ✗ ${err}" >&2
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "qt-suite: optional dependencies not found:" >&2
    for warn in "${WARNINGS[@]}"; do
        echo "  ⚠ ${warn}" >&2
    done
fi

if [ ${#ERRORS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "qt-suite: all prerequisites satisfied"
fi

# Exit non-zero only for required dependencies
[ ${#ERRORS[@]} -eq 0 ]
