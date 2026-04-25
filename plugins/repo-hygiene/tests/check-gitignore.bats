#!/usr/bin/env bats
# check-gitignore.bats — [P3] Scope Fidelity + auto-fix discipline.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  REPO="$TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  git config commit.gpgsign false
  git config tag.gpgsign false
  : > "$REPO/.gitignore"   # empty root gitignore
  git add .gitignore
  git commit -q -m initial
}
teardown() {
  cd /
  teardown_test_env
}

@test "empty repo → no findings (CG1)" {
  run bash "$SCRIPTS_DIR/check-gitignore.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.findings | length')
  [ "$count" -eq 0 ]
}

@test "package.json without node_modules pattern → flagged with auto_fix=true (CG2)" {
  mkdir -p "$REPO/sub"
  echo '{"name": "x"}' > "$REPO/sub/package.json"
  : > "$REPO/sub/.gitignore"
  run bash "$SCRIPTS_DIR/check-gitignore.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.detail | contains("node_modules")) | select(.auto_fix == true)] | length')
  [ "$flagged" -ge 1 ]
}

@test "package.json WITH node_modules pattern → not flagged (CG3 false-positive guard)" {
  mkdir -p "$REPO/sub"
  echo '{"name": "x"}' > "$REPO/sub/package.json"
  echo "node_modules/" > "$REPO/sub/.gitignore"
  run bash "$SCRIPTS_DIR/check-gitignore.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.detail | contains("node_modules"))] | length')
  [ "$flagged" -eq 0 ]
}

@test "Python files without __pycache__ pattern → flagged with auto_fix=true (CG4)" {
  mkdir -p "$REPO/pysub"
  : > "$REPO/pysub/main.py"
  : > "$REPO/pysub/.gitignore"
  run bash "$SCRIPTS_DIR/check-gitignore.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.detail | contains("__pycache__")) | select(.auto_fix == true)] | length')
  [ "$flagged" -ge 1 ]
}

@test "auto-generated .gitignore (single * line) is skipped (CG5)" {
  mkdir -p "$REPO/skipme"
  : > "$REPO/skipme/main.py"
  echo "*" > "$REPO/skipme/.gitignore"
  run bash "$SCRIPTS_DIR/check-gitignore.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.path | contains("skipme"))] | length')
  [ "$flagged" -eq 0 ]
}

@test "root .gitignore is skipped for missing-pattern checks (CG6 documented behavior)" {
  # Even if root has package.json without node_modules in root .gitignore, it's not flagged
  # because the script's comment says root inherits these via global rules.
  echo '{"name": "x"}' > "$REPO/package.json"
  # Root .gitignore is empty — but should not be flagged.
  run bash "$SCRIPTS_DIR/check-gitignore.sh"
  [ "$status" -eq 0 ]
  root_flagged=$(echo "$output" | jq '[.findings[] | select(.path == ".gitignore")] | length')
  [ "$root_flagged" -eq 0 ]
}
