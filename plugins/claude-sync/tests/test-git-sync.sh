#!/usr/bin/env bash
# tests/test-git-sync.sh — Unit and integration tests for git-sync.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts"
GIT_SYNC="$SCRIPT_DIR/git-sync.sh"
source "$(dirname "$0")/helpers.bash"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

REPOS_ROOT="$TMPDIR_TEST/projects"
mkdir -p "$REPOS_ROOT"

echo "=== git-sync.sh ==="

# ---- Test 1: no repos found → empty results ----
echo "— no repos found"
out=$(bash "$GIT_SYNC" "$TMPDIR_TEST/empty-dir-$$" "test-host" "" 2>/dev/null || true)
# The dir doesn't exist so die() fires; that's fine for a missing dir test
# Let's use a real empty dir
mkdir -p "$TMPDIR_TEST/empty"
out=$(bash "$GIT_SYNC" "$TMPDIR_TEST/empty" "test-host" "")
assert_json_eq "$out" ".total_found" "0" "total_found is 0"
assert_json_eq "$out" ".results | length" "0" "results array is empty"

# ---- Test 2: repo without remote → no_remote ----
echo "— repo without remote"
create_mock_repo "$REPOS_ROOT/no-remote-repo" false
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "")
has_no_remote=$(echo "$out" | jq '[.results[] | select(.name=="no-remote-repo" and .status=="no_remote")] | length')
assert_eq "$has_no_remote" "1" "no-remote repo detected"
assert_json_eq "$out" ".summary.skipped" "1" "skipped count is 1"

# ---- Test 3: repo on exclude list → invisible ----
echo "— excluded repo"
create_mock_repo "$REPOS_ROOT/excluded-repo" false
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "$REPOS_ROOT/excluded-repo")
in_results=$(echo "$out" | jq '[.results[] | select(.name=="excluded-repo")] | length')
assert_eq "$in_results" "0" "excluded repo not in results"
excluded_count=$(echo "$out" | jq '.summary.excluded')
assert_eq "$excluded_count" "1" "excluded count incremented"

# ---- Test 4: clean repo with remote → up_to_date ----
echo "— clean repo with remote"
create_mock_repo "$REPOS_ROOT/clean-repo" true
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "$REPOS_ROOT/excluded-repo
$REPOS_ROOT/no-remote-repo")
has_clean=$(echo "$out" | jq '[.results[] | select(.name=="clean-repo" and .status=="up_to_date")] | length')
assert_eq "$has_clean" "1" "clean repo is up_to_date"

# ---- Test 5: repo with tracked changes → auto-committed ----
echo "— repo with tracked changes"
create_mock_repo "$REPOS_ROOT/dirty-repo" true
echo "modified content" > "$REPOS_ROOT/dirty-repo/file.txt"
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "$REPOS_ROOT/excluded-repo
$REPOS_ROOT/no-remote-repo
$REPOS_ROOT/clean-repo")
has_synced=$(echo "$out" | jq '[.results[] | select(.name=="dirty-repo" and .status=="synced")] | length')
assert_eq "$has_synced" "1" "dirty repo was synced"
committed=$(echo "$out" | jq '[.results[] | select(.name=="dirty-repo")] | .[0].committed')
assert_eq "$committed" "1" "committed count is 1"

# ---- Test 6: auto-commit message format ----
echo "— auto-commit message"
log_msg=$(git -C "$REPOS_ROOT/dirty-repo" log -1 --format="%s")
assert_contains "$log_msg" "chore: claude-sync auto-commit" "message starts correctly"
assert_contains "$log_msg" "test-host" "message contains hostname"

# ---- Test 7: push failure → warning ----
echo "— push failure"
create_mock_repo "$REPOS_ROOT/push-fail-repo" false
git -C "$REPOS_ROOT/push-fail-repo" remote add origin "/nonexistent/repo.git"
echo "change" > "$REPOS_ROOT/push-fail-repo/file.txt"
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "$REPOS_ROOT/excluded-repo
$REPOS_ROOT/no-remote-repo
$REPOS_ROOT/clean-repo
$REPOS_ROOT/dirty-repo")
has_failed=$(echo "$out" | jq '[.results[] | select(.name=="push-fail-repo" and .status=="push_failed")] | length')
assert_eq "$has_failed" "1" "push failure detected"
push_ok=$(echo "$out" | jq '[.results[] | select(.name=="push-fail-repo")] | .[0].push_ok')
assert_eq "$push_ok" "false" "push_ok is false"

# ---- Test 8: JSON structure ----
echo "— JSON output structure"
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "")
has_root=$(echo "$out" | jq 'has("repos_root") and has("total_found") and has("results") and has("summary")')
assert_eq "$has_root" "true" "root keys present"
has_summary=$(echo "$out" | jq '.summary | has("synced") and has("warnings") and has("skipped") and has("excluded")')
assert_eq "$has_summary" "true" "summary keys present"

# ---- Test 9: summary counts correct ----
echo "— summary counts"
# Run with all repos visible (no excludes except the already-excluded ones)
out=$(bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "$REPOS_ROOT/excluded-repo")
total=$(echo "$out" | jq '.total_found')
synced=$(echo "$out" | jq '.summary.synced')
warnings=$(echo "$out" | jq '.summary.warnings')
skipped=$(echo "$out" | jq '.summary.skipped')
excluded=$(echo "$out" | jq '.summary.excluded')
sum=$((synced + warnings + skipped))
visible=$((total - excluded))
assert_eq "$sum" "$visible" "synced + warnings + skipped = total - excluded"

# ---- Test 10: untracked files NOT staged ----
echo "— untracked files not staged"
create_mock_repo "$REPOS_ROOT/untracked-repo" true
echo "new file" > "$REPOS_ROOT/untracked-repo/untracked.txt"
bash "$GIT_SYNC" "$REPOS_ROOT" "test-host" "$(find "$REPOS_ROOT" -maxdepth 1 -mindepth 1 -not -name "untracked-repo" -printf '%p\n')" >/dev/null 2>&1
# Check that untracked.txt is still untracked
is_untracked=$(git -C "$REPOS_ROOT/untracked-repo" status --porcelain | grep "^??" | grep "untracked.txt" || true)
assert_contains "$is_untracked" "untracked.txt" "untracked file not staged"

report_results
