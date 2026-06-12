#!/usr/bin/env bash
set -euo pipefail

# Test runner for uv-strict-python. Always use this wrapper, never bare bats:
# this workstation shims find/grep to fd/ugrep, which silently breaks bats
# helpers (false-green) — real coreutils must win the PATH race.
export PATH="/usr/bin:/bin:$PATH"

cd "$(dirname "$0")"

bats ./*.bats
./check-standard-sync.sh
./validate-fenced-blocks.sh
