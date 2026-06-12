#!/usr/bin/env bats
# Tests for pip/pip3 PATH shim

SHIMS_DIR="${BATS_TEST_DIRNAME}/../hooks/shims"
SHIM="${SHIMS_DIR}/pip"

@test "exits non-zero for pip install" {
  run "$SHIM" install requests
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv add"* ]]
}

@test "suggests uv run --with for one-off usage" {
  run "$SHIM" install requests
  [[ "$output" == *"uv run --with"* ]]
}

@test "exits non-zero for pip uninstall" {
  run "$SHIM" uninstall requests
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv remove"* ]]
}

@test "exits non-zero for pip freeze" {
  run "$SHIM" freeze
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv export"* ]]
}

@test "exits non-zero for bare pip" {
  run "$SHIM"
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv"* ]]
}

@test "pip list suggests uv pip list" {
  run "$SHIM" list
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv pip list"* ]]
}

@test "pip show suggests uv pip show" {
  run "$SHIM" show requests
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv pip show"* ]]
}

@test "works when invoked as pip3 via symlink" {
  run "${SHIMS_DIR}/pip3" install foo
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv add"* ]]
}
