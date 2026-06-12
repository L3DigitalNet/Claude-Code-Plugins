#!/usr/bin/env bats
# Tests for setup-shims.sh SessionStart hook (incl. Python-project gating)

SETUP_SCRIPT="${BATS_TEST_DIRNAME}/../hooks/setup-shims.sh"

setup() {
  export CLAUDE_ENV_FILE
  CLAUDE_ENV_FILE="$(mktemp)"
  # Create a fake uv so the guard passes
  FAKE_BIN="$(mktemp -d)"
  echo '#!/usr/bin/env bash' >"$FAKE_BIN/uv"
  chmod +x "$FAKE_BIN/uv"
  export FAKE_BIN
  # Default project dir: a Python project (marker present)
  PROJECT_DIR="$(mktemp -d)"
  touch "$PROJECT_DIR/pyproject.toml"
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  # Save original PATH
  export ORIG_PATH="$PATH"
}

teardown() {
  rm -f "$CLAUDE_ENV_FILE"
  rm -rf "$FAKE_BIN" "$PROJECT_DIR"
}

@test "exits silently when CLAUDE_ENV_FILE is not set" {
  run env -u CLAUDE_ENV_FILE PATH="${FAKE_BIN}:${ORIG_PATH}" \
    bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
}

@test "exits silently when uv is not available" {
  # Remove fake uv dir from PATH; keep rest so bash/coreutils work
  local path_without_uv=""
  local IFS=:
  for dir in $ORIG_PATH; do
    [[ "$dir" == "$FAKE_BIN" ]] && continue
    # Also skip dirs with real uv
    [[ -x "$dir/uv" ]] && continue
    path_without_uv="${path_without_uv:+${path_without_uv}:}$dir"
  done
  run env PATH="$path_without_uv" CLAUDE_ENV_FILE="$CLAUDE_ENV_FILE" \
    bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "writes PATH export to CLAUDE_ENV_FILE" {
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
}

@test "shims dir appears in PATH export" {
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  local shims_dir
  shims_dir="$(cd "${BATS_TEST_DIRNAME}/../hooks/shims" && pwd)"
  grep -q "$shims_dir" "$CLAUDE_ENV_FILE"
}

@test "shims dir is an absolute path" {
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  local line
  line="$(cat "$CLAUDE_ENV_FILE")"
  [[ "$line" =~ export\ PATH=\"/ ]]
}

@test "appends to existing CLAUDE_ENV_FILE content" {
  echo 'export FOO=bar' >"$CLAUDE_ENV_FILE"
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  grep -q 'export FOO=bar' "$CLAUDE_ENV_FILE"
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
}

@test "does not install shims in a non-Python project" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" CLAUDE_PROJECT_DIR="$empty_dir" \
    bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
  rm -rf "$empty_dir"
}

@test "installs when only uv.lock marks the project" {
  rm "$PROJECT_DIR/pyproject.toml"
  touch "$PROJECT_DIR/uv.lock"
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
}

@test "installs when only .python-version marks the project" {
  rm "$PROJECT_DIR/pyproject.toml"
  echo '3.14' >"$PROJECT_DIR/.python-version"
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
}

@test "shims: never blocks installation in a Python project" {
  mkdir -p "$PROJECT_DIR/.claude"
  printf -- '---\nshims: never\n---\n' >"$PROJECT_DIR/.claude/uv-strict-python.local.md"
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "shims: always installs in a non-Python project" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  mkdir -p "$empty_dir/.claude"
  printf -- '---\nshims: always\n---\n' >"$empty_dir/.claude/uv-strict-python.local.md"
  env PATH="${FAKE_BIN}:${ORIG_PATH}" CLAUDE_PROJECT_DIR="$empty_dir" \
    bash "$SETUP_SCRIPT"
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
  rm -rf "$empty_dir"
}
