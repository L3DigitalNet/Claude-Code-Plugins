#!/usr/bin/env bash
set -euo pipefail
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS_ROOT="${BATS_ROOT:-/home/chris/.local/lib/node_modules/bats}"
BATS_LIBEXEC="$BATS_ROOT/libexec/bats-core"
if [[ ! -x "$BATS_LIBEXEC/bats" ]]; then exec bats "$TESTS_DIR"/*.bats; fi
bats_readlinkf() { readlink -f "$1"; }
export -f bats_readlinkf
export BATS_ROOT BATS_LIBDIR="${BATS_LIBDIR:-lib}"
PATH="$BATS_LIBEXEC:$PATH" exec bash "$BATS_LIBEXEC/bats" "$TESTS_DIR"/*.bats
