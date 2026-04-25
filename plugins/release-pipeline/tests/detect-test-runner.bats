#!/usr/bin/env bats
# detect-test-runner.bats — Cross-cutting Mechanical: ecosystem-specific detection
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/detect-test-runner.sh"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
}

@test "pyproject.toml with [tool.pytest] → pytest (DT1)" {
  printf '[tool.pytest]\n' > "$REPO/pyproject.toml"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "pytest --tb=short -q" ]
}

@test "pytest.ini → pytest (DT2)" {
  touch "$REPO/pytest.ini"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "pytest --tb=short -q" ]
}

@test "setup.cfg with [tool:pytest] → pytest (DT3)" {
  printf '[tool:pytest]\n' > "$REPO/setup.cfg"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "pytest --tb=short -q" ]
}

@test "package.json with scripts.test → npm test (DT4)" {
  printf '{"scripts":{"test":"jest"}}' > "$REPO/package.json"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "npm test" ]
}

@test "package.json without scripts.test does not match (DT5)" {
  printf '{"scripts":{"build":"tsc"}}' > "$REPO/package.json"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 1 ]
}

@test "Cargo.toml → cargo test (DT6)" {
  touch "$REPO/Cargo.toml"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "cargo test" ]
}

@test "Makefile with test: target → make test (DT7)" {
  printf 'test:\n\techo run\n' > "$REPO/Makefile"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "make test" ]
}

@test "Makefile without test: target does not match (DT8)" {
  printf 'build:\n\techo build\n' > "$REPO/Makefile"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 1 ]
}

@test "go.mod → go test ./... (DT9)" {
  touch "$REPO/go.mod"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "go test ./..." ]
}

@test "pyproject.toml + package.json → Python ecosystem wins (DT10)" {
  # Detection order: Python checked before Node.js — pyproject.toml takes precedence.
  printf '[tool.pytest]\n' > "$REPO/pyproject.toml"
  printf '{"scripts":{"test":"jest"}}' > "$REPO/package.json"
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "pytest --tb=short -q" ]
}

@test "no manifests → exit 1 (DT11)" {
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 1 ]
}

@test "missing repo dir → exit 1 with error (DT12)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nonexistent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "CLAUDE.md fallback extracts pytest command (DT13)" {
  cat > "$REPO/CLAUDE.md" <<'MD'
Run tests via `pytest -v --cov` for full coverage.
MD
  run bash "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == pytest* ]]
}
