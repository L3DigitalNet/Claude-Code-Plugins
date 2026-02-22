#!/usr/bin/env bash
set -euo pipefail

# api-retry.sh — Exponential backoff + jitter retry wrapper for gh CLI calls.
#
# Usage: api-retry.sh <max_attempts> <base_delay_ms> -- <command...>
# Exit:  0 = command succeeded (or "already exists" in stderr — idempotent)
#        1 = all attempts exhausted
#
# Delay schedule (base=1000ms): ~1s, ~2s, ~4s (plus ±base jitter per attempt)
# Called by: templates/mode-2-full-release.md (Phase 3 gh release create)
#            templates/mode-3-plugin-release.md (Phase 3 gh release create)
#            scripts/verify-release.sh (gh release view calls)

if [[ $# -lt 4 ]]; then
  echo "Usage: api-retry.sh <max_attempts> <base_delay_ms> -- <command...>" >&2
  exit 1
fi

MAX_ATTEMPTS="$1"
BASE_DELAY_MS="$2"
shift 2

if ! [[ "$MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: max_attempts must be a positive integer, got '${MAX_ATTEMPTS}'" >&2
  exit 1
fi

# Consume the '--' separator
if [[ "${1:-}" == "--" ]]; then
  shift
fi

# Declare stderr_file so the trap can reference it even before first mktemp call
stderr_file=""
trap 'rm -f "${stderr_file:-}"' EXIT

attempt=0
while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
  attempt=$((attempt + 1))

  # Capture stderr; if command succeeds, exit immediately
  stderr_file=$(mktemp)
  if "$@" 2>"$stderr_file"; then
    rm -f "$stderr_file"
    exit 0
  fi
  stderr_content=$(cat "$stderr_file")
  rm -f "$stderr_file"

  # "already exists" is treated as success (idempotent re-run)
  if echo "$stderr_content" | grep -qi "already exists"; then
    echo "Note: resource already exists — treating as success." >&2
    exit 0
  fi

  # Permanent HTTP 4xx errors (except 429 Too Many Requests): abort without retry.
  # gh CLI emits "HTTP XXX: ..." in stderr for API errors. 4xx errors indicate a bad
  # request or permission issue — retrying the same call will always fail.
  # 429 (rate-limit) is excluded and falls through to the normal retry path below.
  if echo "$stderr_content" | grep -qiE 'HTTP 4[0-9]{2}:'; then
    http_code=$(echo "$stderr_content" | grep -oiE 'HTTP (4[0-9]{2})' | head -1 | grep -oE '[0-9]+' || true)
    if [[ -n "$http_code" && "$http_code" != "429" ]]; then
      echo "Error: permanent API error (HTTP ${http_code}) — not retrying." >&2
      [[ -n "$stderr_content" ]] && echo "Last error: $stderr_content" >&2
      exit 1
    fi
  fi

  if [[ $attempt -ge $MAX_ATTEMPTS ]]; then
    echo "Error: command failed after ${MAX_ATTEMPTS} attempts." >&2
    [[ -n "$stderr_content" ]] && echo "Last error: $stderr_content" >&2
    exit 1
  fi

  # Exponential delay with jitter: base * 2^(attempt-1) + random[0, base)
  delay_ms=$(( BASE_DELAY_MS * (1 << (attempt - 1)) ))
  jitter=$(( BASE_DELAY_MS > 0 ? RANDOM % BASE_DELAY_MS : 0 ))
  total_ms=$(( delay_ms + jitter ))
  if command -v bc &>/dev/null; then
    total_s=$(echo "scale=3; $total_ms / 1000" | bc)
  else
    total_s=$(( total_ms / 1000 ))
  fi

  echo "Attempt ${attempt} failed. Retrying in ${total_s}s..." >&2
  sleep "$total_s"
done
