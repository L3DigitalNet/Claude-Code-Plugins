#!/usr/bin/env bash
# run-coverage.sh — Portable coverage script for Qt projects (Python + C++).
# Works locally and in any CI. Reads .qt-test.json for project config.
# Usage: ./run-coverage.sh [--python|--cpp|--both] [--threshold N]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ────────────────────────────────────────────────────────────────
MODE="auto"          # auto | python | cpp | both
THRESHOLD=80
BUILD_DIR="build-coverage"
OUTPUT_DIR="htmlcov"
FAIL_ON_THRESHOLD=true

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --python) MODE="python" ;;
        --cpp)    MODE="cpp" ;;
        --both)   MODE="both" ;;
        --threshold) THRESHOLD="$2"; shift ;;
        --no-fail) FAIL_ON_THRESHOLD=false ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
    shift
done

# ── Auto-detect project type ─────────────────────────────────────────────────
if [ "$MODE" = "auto" ]; then
    HAS_PYTHON=false
    HAS_CPP=false
    [ -f "${ROOT_DIR}/pyproject.toml" ] || [ -f "${ROOT_DIR}/setup.cfg" ] && HAS_PYTHON=true
    [ -f "${ROOT_DIR}/CMakeLists.txt" ] && HAS_CPP=true

    if $HAS_PYTHON && $HAS_CPP; then
        MODE="both"
    elif $HAS_PYTHON; then
        MODE="python"
    elif $HAS_CPP; then
        MODE="cpp"
    else
        echo "ERROR: Could not detect project type. Use --python or --cpp." >&2
        exit 1
    fi
    echo "Auto-detected mode: ${MODE}"
fi

# ── Read .qt-test.json if present ────────────────────────────────────────────
CONFIG_FILE="${ROOT_DIR}/.qt-test.json"
if [ -f "$CONFIG_FILE" ]; then
    CFG_THRESHOLD=$(python3 -c "import json; d=json.load(open('${CONFIG_FILE}')); print(d.get('coverage_threshold', ${THRESHOLD}))" 2>/dev/null || echo "$THRESHOLD")
    # CLI --threshold overrides config
    [ "$THRESHOLD" = "80" ] && THRESHOLD="$CFG_THRESHOLD"
    BUILD_DIR=$(python3 -c "import json; d=json.load(open('${CONFIG_FILE}')); print(d.get('build_dir', '${BUILD_DIR}'))" 2>/dev/null || echo "$BUILD_DIR")
fi

echo "Coverage threshold: ${THRESHOLD}%"

# ── Python coverage ───────────────────────────────────────────────────────────
run_python_coverage() {
    echo ""
    echo "═══ Python Coverage ═══"

    if ! command -v pytest &>/dev/null; then
        echo "ERROR: pytest not found. Install with: pip install pytest pytest-cov" >&2
        return 1
    fi

    # Determine source package
    SOURCE=$(python3 -c "
import json, os
cfg = '${CONFIG_FILE}'
if os.path.exists(cfg):
    d = json.load(open(cfg))
    # Infer package name from project structure
    print(d.get('source', ''))
" 2>/dev/null || echo "")

    if [ -z "$SOURCE" ]; then
        # Try to infer from pyproject.toml or setup.cfg
        SOURCE=$(python3 -c "
import re, pathlib
for f in ['pyproject.toml', 'setup.cfg']:
    p = pathlib.Path(f)
    if p.exists():
        m = re.search(r'name\s*=\s*[\"\']([\w-]+)', p.read_text())
        if m: print(m.group(1).replace('-', '_')); break
" 2>/dev/null || echo ".")
    fi

    export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"

    pytest \
        --cov="${SOURCE}" \
        --cov-branch \
        --cov-report=term-missing \
        --cov-report=html:"${OUTPUT_DIR}/python" \
        --cov-report=json:.coverage.json \
        tests/

    COVERAGE=$(python3 -c "
import json
d = json.load(open('.coverage.json'))
print(f\"{d['totals']['percent_covered']:.1f}\")
" 2>/dev/null || echo "unknown")

    echo ""
    echo "Python coverage: ${COVERAGE}%"

    if $FAIL_ON_THRESHOLD && [ "$COVERAGE" != "unknown" ]; then
        if python3 -c "import sys; sys.exit(0 if float('${COVERAGE}') >= ${THRESHOLD} else 1)"; then
            echo "✅ Above threshold (${THRESHOLD}%)"
        else
            echo "❌ Below threshold (${THRESHOLD}%)"
            return 1
        fi
    fi

    echo "HTML report: ${OUTPUT_DIR}/python/index.html"
}

# ── C++ coverage ──────────────────────────────────────────────────────────────
run_cpp_coverage() {
    echo ""
    echo "═══ C++ Coverage ═══"

    for tool in cmake lcov genhtml; do
        if ! command -v "$tool" &>/dev/null; then
            echo "ERROR: $tool not found" >&2
            [ "$tool" = "cmake" ] && echo "  Install cmake via your package manager" >&2
            [ "$tool" = "lcov" ] && echo "  Install lcov: apt install lcov / dnf install lcov" >&2
            return 1
        fi
    done

    cmake -B "${BUILD_DIR}" \
          -DCMAKE_BUILD_TYPE=Debug \
          -DENABLE_COVERAGE=ON \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

    cmake --build "${BUILD_DIR}" --parallel "$(nproc 2>/dev/null || echo 4)"

    lcov --zerocounters --directory "${BUILD_DIR}"

    (cd "${BUILD_DIR}" && ctest --output-on-failure --parallel 4)

    lcov --capture \
         --directory "${BUILD_DIR}" \
         --output-file coverage_raw.info \
         --no-external

    lcov --remove coverage_raw.info \
         '*/tests/*' '*/moc_*' '*/ui_*' "*/$(basename ${BUILD_DIR})/*" \
         --output-file coverage.info

    lcov --summary coverage.info

    mkdir -p "${OUTPUT_DIR}/cpp"
    genhtml coverage.info \
            --output-directory "${OUTPUT_DIR}/cpp" \
            --title "$(basename ${ROOT_DIR}) C++ Coverage" \
            --legend

    COVERAGE=$(lcov --summary coverage.info 2>&1 | grep "lines" | grep -oP '\d+\.\d+' | head -1)
    echo ""
    echo "C++ line coverage: ${COVERAGE}%"

    if $FAIL_ON_THRESHOLD; then
        if python3 -c "import sys; sys.exit(0 if float('${COVERAGE}') >= ${THRESHOLD} else 1)"; then
            echo "✅ Above threshold (${THRESHOLD}%)"
        else
            echo "❌ Below threshold (${THRESHOLD}%)"
            return 1
        fi
    fi

    echo "HTML report: ${OUTPUT_DIR}/cpp/index.html"
}

# ── Execute ───────────────────────────────────────────────────────────────────
EXIT_CODE=0

case "$MODE" in
    python) run_python_coverage || EXIT_CODE=$? ;;
    cpp)    run_cpp_coverage    || EXIT_CODE=$? ;;
    both)
        run_python_coverage || EXIT_CODE=$?
        run_cpp_coverage    || { [ $? -ne 0 ] && EXIT_CODE=$?; }
        ;;
esac

exit $EXIT_CODE
