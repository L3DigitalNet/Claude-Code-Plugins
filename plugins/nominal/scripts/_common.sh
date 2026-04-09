#!/usr/bin/env bash
# _common.sh — Shared utilities for all nominal scripts.
#
# Source this file at the top of every script:
#   source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
#
# Provides: ensure_python, load_profile, detect_firewall, detect_dns_tool,
#           run_check, has_tool, check_result, json_error

set -euo pipefail

# --- Python detection ---

PYTHON=""

ensure_python() {
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
    || { echo '{"error":"python3 not found"}' >&2; exit 1; }
}

ensure_python

# --- Tool detection ---

has_tool() {
  command -v "$1" >/dev/null 2>&1
}

detect_firewall() {
  # Returns first available firewall tool, or "none"
  local tool
  for tool in ufw firewall-cmd nft iptables; do
    if has_tool "$tool"; then
      echo "$tool"
      return
    fi
  done
  echo "none"
}

detect_dns_tool() {
  # Returns first available DNS tool, or "python" as fallback
  local tool
  for tool in dig host nslookup; do
    if has_tool "$tool"; then
      echo "$tool"
      return
    fi
  done
  echo "python"
}

# --- Profile loading ---

load_profile() {
  # Reads and validates environment.json, outputs its content to stdout.
  # Args: <path-to-environment.json>
  # On malformed JSON: prints error to stderr, exits 1.
  local profile_path="${1:?Usage: load_profile <path-to-environment.json>}"

  if [[ ! -f "$profile_path" ]]; then
    echo "{\"error\":\"Profile not found: $profile_path\"}" >&2
    exit 1
  fi

  $PYTHON -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    json.dump(data, sys.stdout)
except (json.JSONDecodeError, ValueError) as e:
    print(json.dumps({'error': f'Invalid environment.json: {e}'}), file=sys.stderr)
    sys.exit(1)
" "$profile_path"
}

# --- Remote execution ---

run_check() {
  # Run a command locally or on a remote host via SSH.
  # Args: <command> [--host <host>]
  # Stdout: command output. Stderr: errors.
  local cmd="" host=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host) host="$2"; shift 2 ;;
      *) cmd="$1"; shift ;;
    esac
  done

  if [[ -z "$cmd" ]]; then
    echo '{"error":"run_check: no command specified"}' >&2
    return 1
  fi

  if [[ -n "$host" ]]; then
    # Remote execution with SSH conventions
    if has_tool timeout; then
      timeout 30 ssh -o ConnectTimeout=10 -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new "$host" "$cmd" 2>/dev/null
    else
      # Bash-native timeout fallback for hosts without GNU coreutils
      local pid
      ( eval "ssh -o ConnectTimeout=10 -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new '$host' '$cmd' 2>/dev/null" ) &
      pid=$!
      ( sleep 30; kill "$pid" 2>/dev/null ) &
      local killer=$!
      wait "$pid" 2>/dev/null
      local rc=$?
      kill "$killer" 2>/dev/null
      wait "$killer" 2>/dev/null
      return $rc
    fi
  else
    # Local execution with timeout
    if has_tool timeout; then
      timeout 30 bash -c "$cmd" 2>/dev/null
    else
      local pid
      ( eval "$cmd" 2>/dev/null ) &
      pid=$!
      ( sleep 30; kill "$pid" 2>/dev/null ) &
      local killer=$!
      wait "$pid" 2>/dev/null
      local rc=$?
      kill "$killer" 2>/dev/null
      wait "$killer" 2>/dev/null
      return $rc
    fi
  fi
}

# --- JSON output helpers ---

check_result() {
  # Build a check result JSON object.
  # Args: <name> <status>
  # Evidence is read from stdin to avoid quoting issues.
  local name="$1" status="$2"
  local evidence
  evidence=$(cat)
  $PYTHON -c "
import json, sys
print(json.dumps({
    'name': sys.argv[1],
    'status': sys.argv[2],
    'evidence': sys.argv[3]
}))
" "$name" "$status" "$evidence"
}

json_error() {
  # Print a JSON error object to stderr and exit.
  # Args: <message>
  $PYTHON -c "import json,sys; print(json.dumps({'error': sys.argv[1]}), file=sys.stderr)" "$1"
  exit 1
}
