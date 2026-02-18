#!/usr/bin/env bash
set -euo pipefail

# verify-release.sh — Verify that a release completed successfully.
#
# Usage: verify-release.sh <repo-path> <version>
# Output: verification report (stdout)
# Exit:   0 = all checks pass, 1 = any check failed
#
# Checks performed:
#   1. Tag exists on remote
#   2. GitHub release exists
#   3. Release notes not empty
#   4. Current branch is NOT main (should have returned to dev branch)

# ---------- Argument handling ----------

if [[ $# -lt 2 ]]; then
  echo "Usage: verify-release.sh <repo-path> <version>" >&2
  exit 1
fi

REPO="$1"
VERSION="$2"

# Strip leading 'v' if present, then always prefix with 'v'.
VERSION="${VERSION#v}"
TAG="v${VERSION}"

# Verify directory exists, then resolve to absolute path.
if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

passed=0
failed=0

# ---------- Helper ----------
# check <description> <pass|fail>
#   Prints a PASS/FAIL line and increments the appropriate counter.
check() {
  local description="$1"
  local result="$2"

  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $description"
    passed=$((passed + 1))
  else
    echo "  FAIL: $description"
    failed=$((failed + 1))
  fi
}

# ---------- Report header ----------

echo "Release Verification: ${TAG}"
echo "=========================="

# ---------- 1. Tag exists on remote ----------

if git -C "$REPO" ls-remote --tags origin "$TAG" 2>/dev/null | grep -q "$TAG"; then
  check "Tag exists on remote" "pass"
else
  check "Tag exists on remote" "fail"
fi

# ---------- 2. GitHub release exists ----------

if gh release view "$TAG" --json tagName -q '.tagName' -R "$(git -C "$REPO" remote get-url origin 2>/dev/null)" &>/dev/null; then
  check "GitHub release exists" "pass"
else
  check "GitHub release exists" "fail"
fi

# ---------- 3. Release notes not empty ----------

release_body=""
release_body=$(gh release view "$TAG" --json body -q '.body' -R "$(git -C "$REPO" remote get-url origin 2>/dev/null)" 2>/dev/null || true)

if [[ -n "$release_body" ]]; then
  check "Release notes present" "pass"
else
  check "Release notes present" "fail"
fi

# ---------- 4. Current branch is NOT main ----------

current_branch=$(git -C "$REPO" branch --show-current 2>/dev/null || echo "")

if [[ -n "$current_branch" && "$current_branch" != "main" ]]; then
  check "Returned to dev branch (on: ${current_branch})" "pass"
else
  if [[ "$current_branch" == "main" ]]; then
    check "Returned to dev branch (on: main)" "fail"
  else
    check "Returned to dev branch (detached HEAD)" "fail"
  fi
fi

# ---------- Summary ----------

echo "=========================="
echo "Results: ${passed} passed, ${failed} failed"

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi

exit 0
