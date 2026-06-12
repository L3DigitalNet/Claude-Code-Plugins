#!/usr/bin/env bats
# Tests for uv PATH shim
# Requires: nix shell nixpkgs#uv -c bats ...

bats_require_minimum_version 1.5.0

SHIMS_DIR="${BATS_TEST_DIRNAME}/../hooks/shims"
SHIM="${SHIMS_DIR}/uv"

setup() {
  command -v uv &>/dev/null || skip "uv not available — run via: nix shell nixpkgs#uv -c bats ..."
}

@test "exits non-zero for uv pip install" {
  run "$SHIM" pip install requests
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv add"* ]]
}

@test "exits non-zero for uv pip sync" {
  run "$SHIM" pip sync
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv sync"* ]]
}

@test "exits non-zero for uv pip freeze" {
  run "$SHIM" pip freeze
  [[ $status -ne 0 ]]
  [[ "$output" == *"legacy"* ]]
}

@test "suggests uv remove for uv pip uninstall" {
  run "$SHIM" pip uninstall foo
  [[ $status -ne 0 ]]
  [[ "$output" == *"uv remove"* ]]
}

@test "passes through to real uv for non-pip subcommands" {
  run "$SHIM" --version
  [[ $status -eq 0 ]]
  [[ "$output" == *"uv"* ]]
}

@test "does not block read-only uv pip list" {
  # Stripped PATH: no real uv (and no stale cached shim to chain into), so a
  # pass-through attempt exits 127 — proving the shim did not intercept.
  local path_no_uv="${SHIMS_DIR}:/usr/bin:/bin"
  run -127 env PATH="$path_no_uv" "$SHIM" pip list
  [[ "$output" != *"legacy"* ]]
}

@test "does not block read-only uv pip show" {
  local path_no_uv="${SHIMS_DIR}:/usr/bin:/bin"
  run -127 env PATH="$path_no_uv" "$SHIM" pip show some-package
  [[ "$output" != *"legacy"* ]]
}

@test "exits 127 with error when real uv is not found" {
  # Include /usr/bin for coreutils but exclude dirs with a real uv
  local path_no_uv="${SHIMS_DIR}:/usr/bin:/bin"
  run -127 env PATH="$path_no_uv" "$SHIM" --version
  [[ "$output" == *"real uv binary not found"* ]]
}
