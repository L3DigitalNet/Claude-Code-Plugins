#!/usr/bin/env bash
PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)}"
STUBS_DIR="$PLUGIN_ROOT/tests/fixtures/stubs"
path_prepend_stubs() { export PATH="$STUBS_DIR:$PATH"; }
