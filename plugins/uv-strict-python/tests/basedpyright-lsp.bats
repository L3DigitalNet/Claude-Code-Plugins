#!/usr/bin/env bats
# Tests for the BasedPyright LSP launcher (scripts/basedpyright-lsp.sh)

bats_require_minimum_version 1.5.0

LAUNCHER="${BATS_TEST_DIRNAME}/../scripts/basedpyright-lsp.sh"

setup() {
  FAKE_BIN="$(mktemp -d)"
  export FAKE_BIN
}

teardown() {
  rm -rf "$FAKE_BIN"
}

@test "execs basedpyright-langserver from PATH with --stdio" {
  cat >"$FAKE_BIN/basedpyright-langserver" <<'EOF'
#!/usr/bin/env bash
echo "fake-langserver $*"
EOF
  chmod +x "$FAKE_BIN/basedpyright-langserver"
  run env PATH="${FAKE_BIN}:/usr/bin:/bin" bash "$LAUNCHER"
  [[ $status -eq 0 ]]
  [[ "$output" == "fake-langserver --stdio" ]]
}

@test "falls back to uvx when langserver is not installed" {
  cat >"$FAKE_BIN/uvx" <<'EOF'
#!/usr/bin/env bash
echo "fake-uvx $*"
EOF
  chmod +x "$FAKE_BIN/uvx"
  run env PATH="${FAKE_BIN}:/usr/bin:/bin" bash "$LAUNCHER"
  [[ $status -eq 0 ]]
  [[ "$output" == "fake-uvx --from basedpyright basedpyright-langserver --stdio" ]]
}

@test "exits 127 with install hint when nothing is available" {
  if env PATH="/usr/bin:/bin" bash -c 'command -v basedpyright-langserver || command -v uvx' >/dev/null; then
    skip "system dirs provide a real binary — cannot isolate"
  fi
  run -127 env PATH="/usr/bin:/bin" bash "$LAUNCHER"
  [[ "$output" == *"uv tool install basedpyright"* ]]
}
