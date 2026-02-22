#!/usr/bin/env bash
# measure-complexity.sh — cyclomatic complexity measurement for autonomous-refactor Phase 1/4.
# Tries language-appropriate external tool first; prompts to install on missing; falls back
# to an AI-estimation sentinel so the caller can request AI analysis.
# Output: JSON to stdout. Exit 0 always (fallback ensures no hard failure).

set -euo pipefail

LANGUAGE=""
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --language) LANGUAGE="$2"; shift 2 ;;
    --file)     TARGET_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: measure-complexity.sh --language ts|py --file <path>"
      echo "  Outputs JSON: {\"file\":\"<path>\",\"tool\":\"<radon|complexity-report|ai-estimated>\",\"complexity\":<N|null>}"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$LANGUAGE" || -z "$TARGET_FILE" ]]; then
  echo "ERROR: --language and --file are required." >&2
  exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "ERROR: file not found: $TARGET_FILE" >&2
  exit 1
fi

measure_python() {
  if python3 -m radon --version >/dev/null 2>&1; then
    # radon cc outputs per-function complexity; take average
    RESULT=$(python3 -m radon cc "$TARGET_FILE" -j 2>/dev/null || echo "[]")
    # Sum all complexities and compute average
    AVG=$(python3 -c "
import json, sys
data = json.loads('''$RESULT''')
complexities = [item['complexity'] for block in data.values() for item in block]
if complexities:
    print(round(sum(complexities) / len(complexities), 1))
else:
    print('null')
" 2>/dev/null || echo "null")
    echo "{\"file\":\"$TARGET_FILE\",\"tool\":\"radon\",\"complexity\":$AVG}"
    return
  fi

  # radon not available — prompt and fall through to AI sentinel
  echo "⚠  radon not installed. For precise complexity metrics:" >&2
  echo "   pip install radon" >&2
  echo "   Falling back to AI-estimated complexity." >&2
  echo "{\"file\":\"$TARGET_FILE\",\"tool\":\"ai-estimated\",\"complexity\":null}"
}

measure_typescript() {
  # Try complexity-report via npx (no global install required)
  if RESULT=$(npx --yes complexity-report --format json "$TARGET_FILE" 2>/dev/null); then
    AVG=$(python3 -c "
import json, sys
data = json.loads('''$RESULT''')
# complexity-report structure: {reports: [{aggregate: {cyclomatic: N}}]}
reports = data.get('reports', [])
vals = [r.get('aggregate', {}).get('cyclomatic', 0) for r in reports if r.get('aggregate')]
if vals:
    print(round(sum(vals) / len(vals), 1))
else:
    print('null')
" 2>/dev/null || echo "null")
    echo "{\"file\":\"$TARGET_FILE\",\"tool\":\"complexity-report\",\"complexity\":$AVG}"
    return
  fi

  # complexity-report failed — prompt and fall through to AI sentinel
  echo "⚠  complexity-report unavailable. For precise TypeScript complexity metrics:" >&2
  echo "   npm install -g complexity-report" >&2
  echo "   Falling back to AI-estimated complexity." >&2
  echo "{\"file\":\"$TARGET_FILE\",\"tool\":\"ai-estimated\",\"complexity\":null}"
}

case "$LANGUAGE" in
  python) measure_python ;;
  typescript|ts) measure_typescript ;;
  *)
    echo "ERROR: unknown language '$LANGUAGE'. Use 'python' or 'typescript'." >&2
    exit 1 ;;
esac
