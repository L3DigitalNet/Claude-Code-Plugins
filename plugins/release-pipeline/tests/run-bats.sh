#!/usr/bin/env bash
# tests/run-bats.sh — Run the bats-core suite for release-pipeline.
#
# Sibling to run-all.sh (which runs the legacy ad-hoc test-*.sh suite). Both
# can run independently; CI / contributors typically run both.
#
# Note: this wrapper bypasses the npm-installed bats wrapper at
# ~/.local/bin/bats because v1.13.0's `exec env BATS_ROOT=... bats-core/bats`
# pattern strips exported bash functions on Fedora 44 (bash 5.3.9 + GNU env),
# leaving bats_readlinkf undefined and breaking BATS_LIBEXEC resolution.
# Calling bats-core directly with the env pre-set sidesteps the bug.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

BATS_ROOT="${BATS_ROOT:-/home/chris/.local/lib/node_modules/bats}"
BATS_LIBEXEC="$BATS_ROOT/libexec/bats-core"

if [[ ! -x "$BATS_LIBEXEC/bats" ]]; then
  # Fall back to PATH-resolved bats. The wrapper's exec-env pattern works fine
  # outside Fedora 44 — only patch behavior when the path-based form is found.
  exec bats "$TESTS_DIR"/*.bats
fi

bats_readlinkf() { readlink -f "$1"; }
export -f bats_readlinkf
export BATS_ROOT BATS_LIBDIR="${BATS_LIBDIR:-lib}"
PATH="$BATS_LIBEXEC:$PATH" exec bash "$BATS_LIBEXEC/bats" "$TESTS_DIR"/*.bats
