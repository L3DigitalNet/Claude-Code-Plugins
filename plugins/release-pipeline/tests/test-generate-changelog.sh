#!/usr/bin/env bash
# tests/test-generate-changelog.sh — Unit tests for generate-changelog.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/generate-changelog.sh"
PASS=0; FAIL=0

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

assert_contains() {
  local actual="$1" pattern="$2" label="$3"
  if [[ "$actual" == *"$pattern"* ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (expected '$pattern' in output)"; FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local actual="$1" pattern="$2" label="$3"
  if [[ "$actual" != *"$pattern"* ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (unexpectedly found '$pattern' in output)"; FAIL=$((FAIL + 1))
  fi
}

file_exists() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file not found: $path)"; FAIL=$((FAIL + 1))
  fi
}

file_absent() {
  local path="$1" label="$2"
  if [[ ! -f "$path" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file unexpectedly exists: $path)"; FAIL=$((FAIL + 1))
  fi
}

# Build a git repo with mixed commit types
REPO="$TMPDIR_TEST/repo"
git init "$REPO" >/dev/null 2>&1
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"
echo "init" > "$REPO/file.txt"
git -C "$REPO" add .
git -C "$REPO" commit -m "initial" >/dev/null 2>&1
git -C "$REPO" commit --allow-empty -m "feat: add shiny new feature" >/dev/null 2>&1
git -C "$REPO" commit --allow-empty -m "fix: squash the bug" >/dev/null 2>&1
git -C "$REPO" commit --allow-empty -m "chore: update dependencies" >/dev/null 2>&1
git -C "$REPO" commit --allow-empty -m "no prefix message" >/dev/null 2>&1

# ---- Test 1: generates version header with date ----
out=$(bash "$SCRIPT" "$REPO" 1.0.0 --preview 2>/dev/null)
assert_contains "$out" "## [1.0.0]" "generates version header"
assert_contains "$out" "$(date +%Y-%m-%d)" "includes today's date"

# ---- Test 2: categorizes feat: as Added ----
assert_contains "$out" "### Added" "feat → Added section"
assert_contains "$out" "add shiny new feature" "feat message in output"

# ---- Test 3: categorizes fix: as Fixed ----
assert_contains "$out" "### Fixed" "fix → Fixed section"
assert_contains "$out" "squash the bug" "fix message in output"

# ---- Test 4: categorizes chore:/unprefixed as Changed ----
assert_contains "$out" "### Changed" "chore → Changed section"
assert_contains "$out" "no prefix message" "unprefixed commit in Changed"

# ---- Test 5: --preview does not create CHANGELOG.md ----
bash "$SCRIPT" "$REPO" 1.0.0 --preview >/dev/null 2>&1
file_absent "$REPO/CHANGELOG.md" "--preview: does not write CHANGELOG.md"

# ---- Test 6: without --preview, creates CHANGELOG.md ----
bash "$SCRIPT" "$REPO" 1.0.0 >/dev/null 2>&1
file_exists "$REPO/CHANGELOG.md" "writes CHANGELOG.md"
content=$(< "$REPO/CHANGELOG.md")
assert_contains "$content" "## [1.0.0]" "CHANGELOG.md contains version entry"

# ---- Test 7: new entry prepended before existing entry ----
git -C "$REPO" tag v1.0.0 2>/dev/null
git -C "$REPO" commit --allow-empty -m "feat: v2 feature" >/dev/null 2>&1
bash "$SCRIPT" "$REPO" 2.0.0 >/dev/null 2>&1
content=$(< "$REPO/CHANGELOG.md")
# 2.0.0 must appear before 1.0.0 in the file
v2_offset="${content%%2.0.0*}"
v1_offset="${content%%1.0.0*}"
if [[ ${#v2_offset} -lt ${#v1_offset} ]]; then
  echo "  ✓ new entry prepended before old entry"; PASS=$((PASS + 1))
else
  echo "  ✗ new entry should appear before old entry"; FAIL=$((FAIL + 1))
fi

# ---- Test 8: --plugin scopes to plugin directory ----
REPO2="$TMPDIR_TEST/repo2"
mkdir -p "$REPO2/plugins/myplugin"
git init "$REPO2" >/dev/null 2>&1
git -C "$REPO2" config user.email "test@example.com"
git -C "$REPO2" config user.name "Test"
echo "initial" > "$REPO2/plugins/myplugin/file.txt"
git -C "$REPO2" add .
git -C "$REPO2" commit -m "initial" >/dev/null 2>&1
git -C "$REPO2" tag "myplugin/v0.1.0"
echo "change" >> "$REPO2/plugins/myplugin/file.txt"
git -C "$REPO2" add .
git -C "$REPO2" commit -m "feat: plugin only change" >/dev/null 2>&1
# Also add a root-level commit that should NOT appear
git -C "$REPO2" commit --allow-empty -m "fix: root change unrelated to plugin" >/dev/null 2>&1

out=$(bash "$SCRIPT" "$REPO2" 0.2.0 --plugin myplugin --preview 2>/dev/null)
assert_contains "$out" "plugin only change" "--plugin: plugin commit in changelog"
assert_not_contains "$out" "root change unrelated" "--plugin: root commit excluded from changelog"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
