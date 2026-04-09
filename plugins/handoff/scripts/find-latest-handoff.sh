#!/usr/bin/env bash
# find-latest-handoff.sh — Find the most recent handoff file and extract metadata.
#
# Usage: find-latest-handoff.sh [--directory <path>] [--sort-by mtime|filename]
# Output: JSON with path, filename, and parsed metadata.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

DIR="/mnt/share/instructions"
SORT_BY="mtime"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --directory) DIR="$2"; shift 2 ;;
    --sort-by) SORT_BY="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Check directory accessibility
if [[ ! -d "$DIR" ]] || [[ ! -r "$DIR" ]]; then
  echo "{\"found\":false,\"error\":\"directory not accessible: $DIR\"}"
  exit 0
fi

# Find most recent handoff file
if [[ "$SORT_BY" == "mtime" ]]; then
  LATEST=$(find "$DIR" -maxdepth 1 \( -name 'handoff-*.md' -o -name '*-handoff-*.md' \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
else
  LATEST=$(find "$DIR" -maxdepth 1 \( -name 'handoff-*.md' -o -name '*-handoff-*.md' \) 2>/dev/null | sort -r | head -1)
fi

if [[ -z "$LATEST" ]]; then
  echo '{"found":false}'
  exit 0
fi

if [[ ! -r "$LATEST" ]]; then
  FNAME=$(basename "$LATEST")
  echo "{\"found\":true,\"path\":\"$LATEST\",\"filename\":\"$FNAME\",\"readable\":false,\"error\":\"permission denied\"}"
  exit 0
fi

FNAME=$(basename "$LATEST")

$PYTHON -c "
import json, re, os, sys

filepath = sys.argv[1]
filename = sys.argv[2]

with open(filepath, encoding='utf-8', errors='replace') as f:
    content = f.read()

lines = content.splitlines()
warnings = []

# Title: first H1 heading
title = None
for line in lines:
    m = re.match(r'^#\s+(.+)', line)
    if m:
        title = m.group(1).strip()
        break
if not title:
    warnings.append('no H1 heading found')

# Source machine
machine = None
for line in lines:
    m = re.match(r'\*?\*?(?:Machine|Hostname)\*?\*?:\s*(.+)', line, re.IGNORECASE)
    if m:
        machine = m.group(1).strip().rstrip('*')
        break
if not machine:
    warnings.append('no Machine/Hostname field found')

# Timestamp from filename
ts = None
m = re.search(r'(\d{4}-\d{2}-\d{2})-?(\d{6})', filename)
if m:
    d = m.group(1)
    t = m.group(2)
    ts = f'{d}T{t[:2]}:{t[2:4]}:{t[4:6]}'
if not ts:
    warnings.append('no timestamp in filename')

# Working directory
wd = None
for line in lines:
    m = re.match(r'\*?\*?Working\s+[Dd]irectory\*?\*?:\s*(.+)', line, re.IGNORECASE)
    if m:
        wd = m.group(1).strip().strip('\`')
        break

# Next steps count
next_steps = 0
in_next_steps = False
for line in lines:
    if re.match(r'^##\s+Next\s+Steps', line, re.IGNORECASE):
        in_next_steps = True
        continue
    if in_next_steps:
        if re.match(r'^##\s+', line):
            break
        if re.match(r'^\d+\.\s+', line) or re.match(r'^[-*]\s+', line):
            next_steps += 1

# All H2 sections
sections = []
for line in lines:
    m = re.match(r'^##\s+(.+)', line)
    if m:
        sections.append(m.group(1).strip())

result = {
    'found': True,
    'path': filepath,
    'filename': filename,
    'metadata': {
        'title': title,
        'source_machine': machine,
        'timestamp': ts,
        'working_directory': wd,
        'next_steps_count': next_steps,
        'sections': sections,
    },
}
if warnings:
    result['metadata']['parse_warnings'] = warnings

print(json.dumps(result, indent=2))
" "$LATEST" "$FNAME"
