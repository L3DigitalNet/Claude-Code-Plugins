#!/usr/bin/env bash
# snapshot-metrics.sh — captures LOC and cyclomatic complexity for one or more target files.
# Called twice by commands/refactor.md: once for the baseline (Phase 1) and once for the
# final state (Phase 4). Writes JSON to .claude/state/refactor-metrics-<label>.json.
# Relies on measure-complexity.sh (sibling script) for per-file complexity.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL=""
TARGET_FILES=()
LANGUAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)    LABEL="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --target)   TARGET_FILES+=("$2"); shift 2 ;;
    --help|-h)
      echo "Usage: snapshot-metrics.sh --label <baseline|final> --language <ts|python> --target <file> [--target <file>...]"
      echo "  Writes .claude/state/refactor-metrics-<label>.json"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$LABEL" ]]; then
  echo "ERROR: --label is required (use 'baseline' or 'final')" >&2
  exit 1
fi

if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
  echo "ERROR: at least one --target <file> is required" >&2
  exit 1
fi

mkdir -p .claude/state

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FILES_JSON="["
FIRST=true

for FILE in "${TARGET_FILES[@]}"; do
  if [[ ! -f "$FILE" ]]; then
    echo "WARNING: target file not found, skipping: $FILE" >&2
    continue
  fi

  # LOC: count non-blank lines (crude but fast; avoids comment-stripping complexity)
  LOC=$(grep -c . "$FILE" 2>/dev/null || echo 0)

  # Total line count for context
  TOTAL_LINES=$(wc -l < "$FILE" | tr -d ' ')

  # Complexity (delegates to sibling script; always exits 0)
  COMPLEXITY_JSON=$("$SCRIPT_DIR/measure-complexity.sh" --language "${LANGUAGE:-python}" --file "$FILE" 2>/dev/null || echo "{\"file\":\"$FILE\",\"tool\":\"error\",\"complexity\":null}")
  COMPLEXITY_VAL=$(echo "$COMPLEXITY_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('complexity')))" 2>/dev/null || echo "null")
  COMPLEXITY_TOOL=$(echo "$COMPLEXITY_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('tool','unknown')))" 2>/dev/null || echo '"unknown"')

  if [[ "$FIRST" == "true" ]]; then
    FIRST=false
  else
    FILES_JSON+=","
  fi

  FILES_JSON+="{\"path\":\"$FILE\",\"loc\":$LOC,\"total_lines\":$TOTAL_LINES,\"complexity\":$COMPLEXITY_VAL,\"complexity_tool\":$COMPLEXITY_TOOL}"
done

FILES_JSON+="]"

OUTPUT_FILE=".claude/state/refactor-metrics-${LABEL}.json"
python3 -c "
import json, sys
files = json.loads('''$FILES_JSON''')
total_loc = sum(f['loc'] for f in files)
complexities = [f['complexity'] for f in files if f.get('complexity') is not None]
avg_complexity = round(sum(complexities) / len(complexities), 1) if complexities else None
output = {
    'label': '$LABEL',
    'timestamp': '$TIMESTAMP',
    'total_loc': total_loc,
    'avg_complexity': avg_complexity,
    'complexity_available': len(complexities) > 0,
    'files': files
}
json.dump(output, open('$OUTPUT_FILE', 'w'), indent=2)
print(f'Snapshot saved: $OUTPUT_FILE')
print(f'  Total LOC: {total_loc}')
print(f'  Avg complexity: {avg_complexity if avg_complexity is not None else \"ai-estimated\"}')
"
