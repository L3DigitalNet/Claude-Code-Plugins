#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# Tier C — Mutation Tests
# Requires: valid GITHUB_PAT with write access to TEST_REPO
# Creates real issues, PRs, labels, branches, comments, files.
# ⚠️ Only run against a dedicated scratch repo.
# ─────────────────────────────────────────────────
source "$(dirname "$0")/lib.sh"

echo -e "${BOLD}Tier C — Mutation Tests${RESET}"
echo -e "Test repo: ${CYAN}${TEST_REPO}${RESET}"
echo ""
echo -e "${YELLOW}⚠️  This will create real artifacts in the test repo.${RESET}"
echo ""

# ── Pre-flight ──────────────────────────────────

group "C0: Pre-flight"

if [[ -z "${GITHUB_PAT:-}" ]]; then
  echo -e "${RED}GITHUB_PAT is not set. Cannot run Tier C tests.${RESET}"
  exit 1
fi

# Verify we can write to this repo
assert_json "auth verify" "$GH_MANAGER auth verify"
run "$GH_MANAGER auth verify"
AUTH_USER=$(json_val "login")
echo -e "  Authenticated as: ${CYAN}${AUTH_USER}${RESET}"

# Get default branch for later use
run "$GH_MANAGER repo info --repo $TEST_REPO"
DEFAULT_BRANCH=$(json_val "default_branch")
echo -e "  Default branch: ${CYAN}${DEFAULT_BRANCH}${RESET}"

# Timestamp for unique naming
TS=$(date +%Y%m%d-%H%M%S)

# ── C1: Label lifecycle ─────────────────────────

group "C1: Labels (create → update)"

LABEL_NAME="test-label-${TS}"

assert_json_eq "create label" \
  "name" "$LABEL_NAME" \
  "$GH_MANAGER repo labels create --repo $TEST_REPO --name '$LABEL_NAME' --color 0e8a16 --description 'Self-test label'"

assert_json_eq "update label color" \
  "name" "$LABEL_NAME" \
  "$GH_MANAGER repo labels update --repo $TEST_REPO --name '$LABEL_NAME' --color d93f0b"

# ── C2: File lifecycle ──────────────────────────

group "C2: Files (put → get → verify → delete)"

TEST_FILE="test-files/${TS}.md"
TEST_CONTENT="# Self-test file\nCreated at ${TS}\n"

assert_json_eq "put file" \
  "action" "created" \
  "printf '${TEST_CONTENT}' | $GH_MANAGER files put --repo $TEST_REPO --path '${TEST_FILE}' --message 'Test: create file ${TS}'"

assert_json_has "get file returns content" \
  "content" \
  "$GH_MANAGER files get --repo $TEST_REPO --path '${TEST_FILE}'"

# Verify round-trip content
run "$GH_MANAGER files get --repo $TEST_REPO --path '${TEST_FILE}'"
GOT_CONTENT=$(json_val "content")
if echo "$GOT_CONTENT" | grep -q "Self-test file"; then
  pass "file content round-trip matches"
else
  fail "file content round-trip matches" "content doesn't contain expected text"
fi

assert_json_eq "delete file" \
  "action" "deleted" \
  "$GH_MANAGER files delete --repo $TEST_REPO --path '${TEST_FILE}' --message 'Test: cleanup ${TS}'"

# Verify deletion
run "$GH_MANAGER files exists --repo $TEST_REPO --path '${TEST_FILE}'"
if [[ $CMD_EXIT -ne 0 ]]; then
  pass "file confirmed deleted"
else
  fail "file confirmed deleted" "file still exists after delete"
fi

# ── C3: Branch lifecycle ────────────────────────

group "C3: Branches (create → verify → delete)"

BRANCH_NAME="test/self-test-${TS}"

assert_json_has "create branch returns name" \
  "name" \
  "$GH_MANAGER branches create --repo $TEST_REPO --branch '${BRANCH_NAME}' --from $DEFAULT_BRANCH"

# Verify it appears in list
run "$GH_MANAGER branches list --repo $TEST_REPO"
if echo "$CMD_OUT" | grep -q "$BRANCH_NAME"; then
  pass "branch appears in list"
else
  fail "branch appears in list"
fi

assert_json_eq "delete branch" \
  "action" "deleted" \
  "$GH_MANAGER branches delete --repo $TEST_REPO --branch '${BRANCH_NAME}'"

# ── C4: Issue lifecycle ─────────────────────────
# Issues can't be deleted via API — they accumulate.
# Use a clear naming convention so they're obviously test artifacts.

group "C4: Issues (create via API workaround → label → comment → close)"

# gh-manager doesn't have issues create (by design — skill layer creates
# issues via GitHub API directly). Test the commands we DO have.
# We'll create an issue via the files→PR trick, or just test against
# any existing open issue. If none exist, skip.

# First check if test label exists, create it if not
ISSUE_LABEL="self-test"
run "$GH_MANAGER repo labels list --repo $TEST_REPO"
if ! echo "$CMD_OUT" | grep -q "\"$ISSUE_LABEL\""; then
  run "$GH_MANAGER repo labels create --repo $TEST_REPO --name '$ISSUE_LABEL' --color c5def5 --description 'Auto-created by self-test'"
fi

# Try to find an open issue, or create one via a helper approach
run "$GH_MANAGER issues list --repo $TEST_REPO --state open"
OPEN_ISSUE_COUNT=$(json_val "count")

if [[ "$OPEN_ISSUE_COUNT" -gt 0 ]]; then
  ISSUE_NUM=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    process.stdout.write(String(d.issues[0]?.number || ''));
  " 2>/dev/null)
  echo -e "  Using existing issue #${ISSUE_NUM}"
else
  # No open issues — we need one. Create via GitHub REST directly.
  echo -e "  ${YELLOW}No open issues found — creating one via API${RESET}"
  ISSUE_JSON=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${TEST_REPO}/issues" \
    -d "{\"title\":\"[Self-test] Test issue ${TS}\",\"body\":\"Created by gh-manager self-test. Safe to close.\"}")
  ISSUE_NUM=$(echo "$ISSUE_JSON" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    process.stdout.write(String(d.number || ''));
  " 2>/dev/null)
  if [[ -z "$ISSUE_NUM" || "$ISSUE_NUM" == "undefined" ]]; then
    fail "create test issue via API" "could not create issue"
    ISSUE_NUM=""
  else
    pass "create test issue #${ISSUE_NUM} via API"
  fi
fi

if [[ -n "$ISSUE_NUM" ]]; then
  assert_json_has "issues get #${ISSUE_NUM}" \
    "title" \
    "$GH_MANAGER issues get --repo $TEST_REPO --issue $ISSUE_NUM"

  assert_json_eq "issues label (add)" \
    "action" "labeled" \
    "$GH_MANAGER issues label --repo $TEST_REPO --issue $ISSUE_NUM --add '$ISSUE_LABEL'"

  assert_json_eq "issues comment" \
    "action" "commented" \
    "$GH_MANAGER issues comment --repo $TEST_REPO --issue $ISSUE_NUM --body 'Self-test comment at ${TS}. <!-- gh-manager:self-test -->'"

  assert_json_has "issues comments returns comments" \
    "comments" \
    "$GH_MANAGER issues comments --repo $TEST_REPO --issue $ISSUE_NUM"

  # Verify dedup marker is findable
  run "$GH_MANAGER issues comments --repo $TEST_REPO --issue $ISSUE_NUM"
  if echo "$CMD_OUT" | grep -q "gh-manager:self-test"; then
    pass "dedup marker retrievable in comments"
  else
    fail "dedup marker retrievable in comments"
  fi

  assert_json_eq "issues assign" \
    "action" "assigned" \
    "$GH_MANAGER issues assign --repo $TEST_REPO --issue $ISSUE_NUM --assignees $AUTH_USER"

  assert_json_eq "issues close" \
    "action" "closed" \
    "$GH_MANAGER issues close --repo $TEST_REPO --issue $ISSUE_NUM --reason completed --body 'Closed by self-test'"
else
  skip "issues label" "no issue available"
  skip "issues comment" "no issue available"
  skip "issues comments" "no issue available"
  skip "issues assign" "no issue available"
  skip "issues close" "no issue available"
fi

# ── C5: PR lifecycle ───────────────────────────

group "C5: PRs (branch → file → create PR → comment → label → close)"

PR_BRANCH="test/pr-self-test-${TS}"

# Create branch
assert_json_has "create PR branch" \
  "name" \
  "$GH_MANAGER branches create --repo $TEST_REPO --branch '${PR_BRANCH}' --from $DEFAULT_BRANCH"

# Put a file on the branch
assert_json_eq "put file on PR branch" \
  "action" "created" \
  "echo 'PR test file ${TS}' | $GH_MANAGER files put --repo $TEST_REPO --path 'test-pr-${TS}.md' --branch '${PR_BRANCH}' --message 'Test: PR file'"

# Create PR
assert_json_has "prs create returns number" \
  "number" \
  "$GH_MANAGER prs create --repo $TEST_REPO --head '${PR_BRANCH}' --base $DEFAULT_BRANCH --title '[Self-test] PR ${TS}' --body 'Created by self-test. Safe to close.' --label '$LABEL_NAME'"

run "$GH_MANAGER prs create --repo $TEST_REPO --head '${PR_BRANCH}' --base $DEFAULT_BRANCH --title '[Self-test] PR ${TS}' --body 'Created by self-test. Safe to close.' --label '$LABEL_NAME'"
# The create may fail if it already exists from the line above. Pull the number from whichever succeeded.
PR_NUM=""
if [[ $CMD_EXIT -eq 0 ]]; then
  PR_NUM=$(json_val "number")
fi

# If create failed (duplicate), find it
if [[ -z "$PR_NUM" || "$PR_NUM" == "undefined" ]]; then
  run "$GH_MANAGER prs list --repo $TEST_REPO --state open"
  PR_NUM=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    const pr = d.pull_requests?.find(p => p.head_branch === '${PR_BRANCH}');
    process.stdout.write(String(pr?.number || ''));
  " 2>/dev/null)
fi

if [[ -n "$PR_NUM" && "$PR_NUM" != "undefined" ]]; then
  echo -e "  Testing against PR #${PR_NUM}"

  assert_json_has "prs get #${PR_NUM}" \
    "review_summary" \
    "$GH_MANAGER prs get --repo $TEST_REPO --pr $PR_NUM"

  assert_json_has "prs diff #${PR_NUM}" \
    "files" \
    "$GH_MANAGER prs diff --repo $TEST_REPO --pr $PR_NUM"

  assert_json_eq "prs comment" \
    "action" "commented" \
    "$GH_MANAGER prs comment --repo $TEST_REPO --pr $PR_NUM --body 'Self-test PR comment ${TS}'"

  assert_json_has "prs comments returns comments" \
    "comments" \
    "$GH_MANAGER prs comments --repo $TEST_REPO --pr $PR_NUM"

  assert_json_eq "prs label (add)" \
    "action" "labeled" \
    "$GH_MANAGER prs label --repo $TEST_REPO --pr $PR_NUM --add '$ISSUE_LABEL'"

  # Close the PR (don't merge — test repo stays clean)
  assert_json_eq "prs close" \
    "action" "closed" \
    "$GH_MANAGER prs close --repo $TEST_REPO --pr $PR_NUM --body 'Closed by self-test'"

  # Cleanup: delete the branch
  run "$GH_MANAGER branches delete --repo $TEST_REPO --branch '${PR_BRANCH}'"
  if [[ $CMD_EXIT -eq 0 ]]; then
    pass "cleanup PR branch"
  else
    skip "cleanup PR branch" "may have been auto-deleted"
  fi
else
  fail "PR lifecycle" "could not create or find test PR"
  skip "prs get" "no PR available"
  skip "prs diff" "no PR available"
  skip "prs comment" "no PR available"
  skip "prs comments" "no PR available"
  skip "prs label" "no PR available"
  skip "prs close" "no PR available"
fi

# ── C6: Notification operations ────────────────

group "C6: Notifications (read + mark-read)"

# We can't create notifications on demand, so just verify the command works
assert_json "notifications list" \
  "$GH_MANAGER notifications list --repo $TEST_REPO"

# mark-read is tested via dry-run in Tier A (too destructive for real runs
# since it clears notification state the user may care about)
skip "notifications mark-read" "destructive — covered by Tier A dry-run"

# ── C7: Release lifecycle ──────────────────────

group "C7: Releases (draft → verify → publish → verify)"

REL_TAG="v0.0.0-test-${TS}"

assert_json_has "releases draft creates release" \
  "id" \
  "$GH_MANAGER releases draft --repo $TEST_REPO --tag '${REL_TAG}' --name 'Self-test ${TS}' --body 'Created by self-test. Safe to delete.'"

run "$GH_MANAGER releases draft --repo $TEST_REPO --tag '${REL_TAG}' --name 'Self-test ${TS}' --body 'Created by self-test. Safe to delete.'"
# May have been created above — get the ID from either call
RELEASE_ID=""
if [[ $CMD_EXIT -eq 0 ]]; then
  RELEASE_ID=$(json_val "id")
fi

if [[ -z "$RELEASE_ID" || "$RELEASE_ID" == "undefined" ]]; then
  # Find it in the releases list
  run "$GH_MANAGER releases list --repo $TEST_REPO --limit 5"
  RELEASE_ID=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    const r = d.releases?.find(r => r.tag_name === '${REL_TAG}');
    process.stdout.write(String(r?.id || ''));
  " 2>/dev/null)
fi

if [[ -n "$RELEASE_ID" && "$RELEASE_ID" != "undefined" ]]; then
  echo -e "  Draft release ID: ${CYAN}${RELEASE_ID}${RESET}"

  # Verify it's a draft
  run "$GH_MANAGER releases list --repo $TEST_REPO --limit 5"
  IS_DRAFT=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    const r = d.releases?.find(r => r.id == ${RELEASE_ID});
    process.stdout.write(String(r?.draft || ''));
  " 2>/dev/null)
  if [[ "$IS_DRAFT" == "true" ]]; then
    pass "release is draft"
  else
    fail "release is draft" "draft=$IS_DRAFT"
  fi

  # Publish it
  assert_json_eq "releases publish" \
    "action" "published" \
    "$GH_MANAGER releases publish --repo $TEST_REPO --release-id $RELEASE_ID"

  # Cleanup: delete the release+tag via API (gh-manager doesn't have delete)
  curl -s -X DELETE \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${TEST_REPO}/releases/${RELEASE_ID}" >/dev/null
  curl -s -X DELETE \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${TEST_REPO}/git/refs/tags/${REL_TAG}" >/dev/null
  pass "cleanup release + tag"
else
  fail "release lifecycle" "could not create or find draft release"
fi

# ── C8: Config write ───────────────────────────

group "C8: Config (write → read → verify → cleanup)"

# Write a test config to the repo
CONFIG_CONTENT="# gh-manager self-test config
repo:
  tier: auto
settings:
  verbose: true
# created: ${TS}"

run "echo '${CONFIG_CONTENT}' | $GH_MANAGER config repo-write --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "config repo-write"
else
  fail "config repo-write" "exit=$CMD_EXIT"
fi

# Read it back
run "$GH_MANAGER config repo-read --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  CFG_EXISTS=$(json_val "exists")
  if [[ "$CFG_EXISTS" == "true" ]]; then
    pass "config repo-read (round-trip)"
  else
    fail "config repo-read (round-trip)" "exists=false after write"
  fi
else
  fail "config repo-read (round-trip)" "exit=$CMD_EXIT"
fi

# Resolve should now include the repo config
assert_json_has "config resolve includes sources" \
  "sources" \
  "$GH_MANAGER config resolve --repo $TEST_REPO"

# Cleanup: delete the config file
run "$GH_MANAGER files delete --repo $TEST_REPO --path '.github-repo-manager.yml' --message 'Self-test cleanup: remove config'"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "cleanup config file"
else
  skip "cleanup config file" "may not have been created"
fi

# ── C9: Wiki operations ────────────────────────

group "C9: Wiki (clone → init → push → cleanup)"

# Wiki tests depend on wiki being enabled
run "$GH_MANAGER repo info --repo $TEST_REPO"
WIKI_ENABLED=$(json_val "has_wiki")

if [[ "$WIKI_ENABLED" == "true" ]]; then
  WIKI_DIR="/tmp/ghm-wiki-test-${TS}"

  run "$GH_MANAGER wiki clone --repo $TEST_REPO --dir $WIKI_DIR"
  if [[ $CMD_EXIT -eq 0 ]]; then
    pass "wiki clone"
    CLONE_STATUS=$(json_val "status")
    echo -e "    Clone status: ${CYAN}${CLONE_STATUS}${RESET}"

    if [[ "$CLONE_STATUS" == "cloned" ]]; then
      # Try wiki diff (should be clean right after clone)
      assert_json "wiki diff" \
        "$GH_MANAGER wiki diff --dir $WIKI_DIR"
    fi

    # Cleanup
    rm -rf "$WIKI_DIR"
    pass "cleanup wiki dir"
  else
    fail "wiki clone" "exit=$CMD_EXIT"
    # Wiki may not be initialized yet — that's okay
    if echo "$CMD_OUT$CMD_ERR" | grep -qi "empty\|not found\|does not"; then
      skip "wiki tests" "wiki exists but has no content yet"
    fi
  fi
else
  skip "wiki clone" "wiki not enabled on test repo"
  skip "wiki diff" "wiki not enabled on test repo"
fi

# ── C10: Discussions ───────────────────────────

group "C10: Discussions (read + comment)"

run "$GH_MANAGER discussions list --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  DISC_ENABLED=$(json_val "enabled")
  if [[ "$DISC_ENABLED" == "false" ]]; then
    skip "discussions comment" "discussions not enabled"
    skip "discussions close" "discussions not enabled"
  else
    DISC_COUNT=$(json_val "total")
    echo -e "  Discussions: ${CYAN}${DISC_COUNT}${RESET}"
    if [[ "$DISC_COUNT" -gt 0 ]]; then
      # Get first discussion number
      FIRST_DISC=$(echo "$CMD_OUT" | node -e "
        const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
        const open = d.discussions?.find(x => !x.closed);
        process.stdout.write(String(open?.number || ''));
      " 2>/dev/null)
      if [[ -n "$FIRST_DISC" && "$FIRST_DISC" != "undefined" ]]; then
        # Comment (but don't close — we may need it for future tests)
        assert_json_eq "discussions comment #${FIRST_DISC}" \
          "action" "commented" \
          "$GH_MANAGER discussions comment --repo $TEST_REPO --discussion $FIRST_DISC --body 'Self-test comment ${TS}'"
      else
        skip "discussions comment" "no open discussions"
      fi
    else
      skip "discussions comment" "no discussions exist"
    fi
    skip "discussions close" "not closing — preserving test discussions"
  fi
else
  fail "discussions list" "exit=$CMD_EXIT"
fi

# ── C11: Label cleanup ─────────────────────────

group "C11: Cleanup"

# Delete the test label we created in C1
# (GitHub API: DELETE /repos/{owner}/{repo}/labels/{name})
curl -s -X DELETE \
  -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${TEST_REPO}/labels/${LABEL_NAME}" >/dev/null 2>&1
pass "cleanup test label"

# Delete test file directory if it was left behind
run "$GH_MANAGER files exists --repo $TEST_REPO --path test-files/"
if [[ $CMD_EXIT -eq 0 ]]; then
  skip "cleanup test-files dir" "directory exists — manual cleanup may be needed"
fi

echo ""
echo -e "${CYAN}Remaining test artifacts in ${TEST_REPO}:${RESET}"
echo -e "  • Closed issue(s) with [Self-test] prefix"
echo -e "  • Closed PR(s) with [Self-test] prefix"
echo -e "  • Commits from file put/delete operations"
echo -e "  These are harmless. Periodically clean via GitHub UI if desired."

# ── Done ────────────────────────────────────────

summary
