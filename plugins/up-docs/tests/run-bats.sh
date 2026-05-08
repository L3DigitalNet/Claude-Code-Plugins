#!/usr/bin/env bash
# run-bats.sh — wrapper that runs the up-docs bats suite.
#
# Usage:
#   bash run-bats.sh                            — run all top-level *.bats files
#   bash run-bats.sh path/to/specific.bats      — run a specific file
#   bash run-bats.sh tests/integration/         — run a directory of bats files
#   bash run-bats.sh foo.bats bar.bats          — run multiple specific files
#
# Honors $@ so callers can target specific files or directories. Falls back to
# the top-level *.bats glob when called with no arguments.

set -euo pipefail
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS_ROOT="${BATS_ROOT:-/home/chris/.local/lib/node_modules/bats}"
BATS_LIBEXEC="$BATS_ROOT/libexec/bats-core"

# Resolve targets: explicit args win, else top-level *.bats glob.
if [ "$#" -gt 0 ]; then
    TARGETS=("$@")
else
    # shellcheck disable=SC2206
    TARGETS=("$TESTS_DIR"/*.bats)
fi

# If the bats libexec isn't found, fall back to whatever `bats` is on PATH.
if [[ ! -x "$BATS_LIBEXEC/bats" ]]; then
    exec bats "${TARGETS[@]}"
fi

bats_readlinkf() { readlink -f "$1"; }
export -f bats_readlinkf
export BATS_ROOT BATS_LIBDIR="${BATS_LIBDIR:-lib}"
PATH="$BATS_LIBEXEC:$PATH" exec bash "$BATS_LIBEXEC/bats" "${TARGETS[@]}"
