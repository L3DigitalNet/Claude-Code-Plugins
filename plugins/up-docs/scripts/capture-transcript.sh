#!/usr/bin/env bash
# capture-transcript.sh — PostToolUse hook for up-docs evidence-grounding tests.
#
# RUNTIME CONTRACT:
#   Receives PostToolUse JSON on stdin per Claude Code hook contract:
#     {"tool_name": "Bash", "tool_input": {...}, "tool_response": {...}, ...}
#   Appends one redacted JSON line per Bash invocation to ${UP_DOCS_TRANSCRIPT_LOG}.
#   Exits 0 always — hooks must not block tool execution on capture failure.
#
# SAFETY CONTRACT (read this if changing this script):
#   1. OPT-IN: no-op unless UP_DOCS_TRANSCRIPT_LOG is set to a non-empty value.
#      The plugin is loaded for every up-docs invocation; the hook is loaded
#      whenever the plugin is loaded; only the env var enables capture.
#   2. BASH ONLY: never captures Read tool_response (which contains entire
#      file contents per Claude Code PostToolBatch docs — see GH-44868).
#   3. UMASK 077: file is created mode 600. If the file pre-existed with
#      looser perms, chmod 600 corrects it before any write.
#   4. REDACTION: secret patterns (Bearer, ghp_, ghs_, AKIA, BAO_TOKEN=,
#      password=, token=, sk-ant-) are redacted BEFORE write. Even with
#      mode 600 and per-session log paths, secrets in plaintext at rest
#      are a known attack surface (CVE-2025-59536, GH-44868).
#   5. OUTPUT TRUNCATION: tool_response.output is truncated to 4 KiB before
#      write. Transcript-grounding only needs distinctive substrings, not
#      full output.
#   6. SESSION CLEANUP: this script does NOT clean up the log file. Set
#      UP_DOCS_TRANSCRIPT_LOG to a per-session path (e.g. /tmp/up-docs-
#      $(date +%s)-$RANDOM.jsonl) so old logs age out via /tmp policy.
#      The companion tests/run-bats.sh integration harness sets a TEST_TMPDIR
#      path and removes the file on teardown.
#
# IMPLEMENTATION NOTE: redaction logic lives in scripts/_capture-redactor.py
# (sibling). Mixing an inline Python heredoc with stdin-piped JSON in one
# bash file causes the heredoc to override stdin and silently drop the
# data — caught during T13 smoke testing on 2026-05-08.

# OPT-IN GATE — first line, before set -u so an unset env var is a benign no-op.
[ -z "${UP_DOCS_TRANSCRIPT_LOG:-}" ] && exit 0

set -uo pipefail
INPUT=$(cat)

# Extract tool_name and only act on Bash (not Read or other tools)
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('tool_name', ''))
except: print('')
" 2>/dev/null)

[ "$TOOL_NAME" != "Bash" ] && exit 0

# Restrictive permissions before any file creation
umask 077
LOG="${UP_DOCS_TRANSCRIPT_LOG}"
touch "$LOG" 2>/dev/null || exit 0
chmod 600 "$LOG" 2>/dev/null || true

# Pipe JSON to the sibling Python redactor; it writes one JSONL line to $LOG.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf '%s' "$INPUT" | python3 "$SCRIPT_DIR/_capture-redactor.py" "$LOG" || true

exit 0
