#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# Tier B — Read-Only API Tests
# Requires: valid GITHUB_PAT, TEST_REPO exists
# Makes only GET requests. Safe to run repeatedly.
# ─────────────────────────────────────────────────
source "$(dirname "$0")/lib.sh"

echo -e "${BOLD}Tier B — Read-Only API Tests${RESET}"
echo -e "Test repo: ${CYAN}${TEST_REPO}${RESET}"
echo ""

# ── Pre-flight ──────────────────────────────────

group "B0: Pre-flight checks"

if [[ -z "${GITHUB_PAT:-}" ]]; then
  echo -e "${RED}GITHUB_PAT is not set. Cannot run Tier B tests.${RESET}"
  exit 1
fi

assert_json "auth verify" \
  "$GH_MANAGER auth verify"
run "$GH_MANAGER auth verify"
AUTH_USER=$(json_val "login")
echo -e "  Authenticated as: ${CYAN}${AUTH_USER}${RESET}"

assert_json "auth rate-limit" \
  "$GH_MANAGER auth rate-limit"
run "$GH_MANAGER auth rate-limit"
REMAINING=$(json_val "remaining")
echo -e "  API budget: ${CYAN}${REMAINING}${RESET} remaining"
if [[ "$REMAINING" -lt 100 ]]; then
  echo -e "${YELLOW}  ⚠️  Low API budget. Some tests may fail due to rate limiting.${RESET}"
fi

# ── B1: Repo Discovery ─────────────────────────

group "B1: Repo discovery"

assert_json_has "repos list returns repos" \
  "repos" \
  "$GH_MANAGER repos list --limit 5"

assert_json_has "repos classify returns tier" \
  "tier" \
  "$GH_MANAGER repos classify --repo $TEST_REPO"

run "$GH_MANAGER repos classify --repo $TEST_REPO"
TIER=$(json_val "tier")
echo -e "  Detected tier: ${CYAN}${TIER}${RESET}"

# ── B2: Repo Metadata ──────────────────────────

group "B2: Repo metadata"

assert_json_has "repo info returns full_name" \
  "full_name" \
  "$GH_MANAGER repo info --repo $TEST_REPO"

run "$GH_MANAGER repo info --repo $TEST_REPO"
PRIVATE=$(json_val "private")
HAS_WIKI=$(json_val "has_wiki")
HAS_DISCUSSIONS=$(json_val "has_discussions")
HAS_ISSUES=$(json_val "has_issues")
DEFAULT_BRANCH=$(json_val "default_branch")
echo -e "  private=$PRIVATE wiki=$HAS_WIKI discussions=$HAS_DISCUSSIONS issues=$HAS_ISSUES branch=$DEFAULT_BRANCH"

assert_json_has "repo community returns health_percentage" \
  "health_percentage" \
  "$GH_MANAGER repo community --repo $TEST_REPO"

assert_json "repo labels list" \
  "$GH_MANAGER repo labels list --repo $TEST_REPO"

# ── B3: File Operations ────────────────────────

group "B3: File operations (read)"

assert_ok "files exists on README.md (exit 0)" \
  "$GH_MANAGER files exists --repo $TEST_REPO --path README.md"

run "$GH_MANAGER files exists --repo $TEST_REPO --path NONEXISTENT_FILE_12345.md"
if [[ $CMD_EXIT -ne 0 ]]; then
  pass "files exists on missing file (exit non-zero)"
else
  fail "files exists on missing file (exit non-zero)" "expected exit 1, got 0"
fi

assert_json_has "files get README.md returns content" \
  "content" \
  "$GH_MANAGER files get --repo $TEST_REPO --path README.md"

# ── B4: Branch Operations ──────────────────────

group "B4: Branch operations (read)"

assert_json_has "branches list returns branches" \
  "branches" \
  "$GH_MANAGER branches list --repo $TEST_REPO"

run "$GH_MANAGER branches list --repo $TEST_REPO"
BRANCH_COUNT=$(json_val "count")
echo -e "  Branch count: ${CYAN}${BRANCH_COUNT}${RESET}"

# ── B5: PR Operations ──────────────────────────

group "B5: PR operations (read)"

assert_json_has "prs list returns pull_requests" \
  "pull_requests" \
  "$GH_MANAGER prs list --repo $TEST_REPO --state all --limit 5"

run "$GH_MANAGER prs list --repo $TEST_REPO --state all --limit 5"
PR_COUNT=$(json_val "count")
echo -e "  PRs found: ${CYAN}${PR_COUNT}${RESET}"

# Test prs get/diff/comments only if PRs exist
if [[ "$PR_COUNT" -gt 0 ]]; then
  # Get the first PR number
  FIRST_PR=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    process.stdout.write(String(d.pull_requests[0]?.number || ''));
  " 2>/dev/null)

  if [[ -n "$FIRST_PR" ]]; then
    assert_json_has "prs get #$FIRST_PR returns review_summary" \
      "review_summary" \
      "$GH_MANAGER prs get --repo $TEST_REPO --pr $FIRST_PR"

    assert_json_has "prs diff #$FIRST_PR returns files" \
      "files" \
      "$GH_MANAGER prs diff --repo $TEST_REPO --pr $FIRST_PR"

    assert_json_has "prs comments #$FIRST_PR returns comments" \
      "comments" \
      "$GH_MANAGER prs comments --repo $TEST_REPO --pr $FIRST_PR"
  fi
else
  skip "prs get" "no PRs exist in test repo"
  skip "prs diff" "no PRs exist in test repo"
  skip "prs comments" "no PRs exist in test repo"
fi

# ── B6: Issue Operations ───────────────────────

group "B6: Issue operations (read)"

assert_json_has "issues list returns issues" \
  "issues" \
  "$GH_MANAGER issues list --repo $TEST_REPO --state all --limit 5"

run "$GH_MANAGER issues list --repo $TEST_REPO --state all --limit 5"
ISSUE_COUNT=$(json_val "count")
echo -e "  Issues found: ${CYAN}${ISSUE_COUNT}${RESET}"

if [[ "$ISSUE_COUNT" -gt 0 ]]; then
  FIRST_ISSUE=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    process.stdout.write(String(d.issues[0]?.number || ''));
  " 2>/dev/null)

  if [[ -n "$FIRST_ISSUE" ]]; then
    assert_json_has "issues get #$FIRST_ISSUE returns title" \
      "title" \
      "$GH_MANAGER issues get --repo $TEST_REPO --issue $FIRST_ISSUE"

    assert_json_has "issues comments #$FIRST_ISSUE returns comments" \
      "comments" \
      "$GH_MANAGER issues comments --repo $TEST_REPO --issue $FIRST_ISSUE"
  fi
else
  skip "issues get" "no issues exist in test repo"
  skip "issues comments" "no issues exist in test repo"
fi

# ── B7: Security Operations ───────────────────

group "B7: Security operations (read-only)"

# These may 403/404 depending on repo settings — that's valid data too
run "$GH_MANAGER security dependabot --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "security dependabot (accessible)"
  run "$GH_MANAGER security dependabot --repo $TEST_REPO"
  DEP_COUNT=$(json_val "count")
  echo -e "    Dependabot alerts: ${CYAN}${DEP_COUNT}${RESET}"
elif [[ $CMD_EXIT -eq 1 ]] && echo "$CMD_OUT" | grep -q '"error"'; then
  skip "security dependabot" "not enabled or no permission ($(json_val 'status'))"
else
  fail "security dependabot" "unexpected exit=$CMD_EXIT"
fi

run "$GH_MANAGER security code-scanning --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "security code-scanning"
elif [[ $CMD_EXIT -eq 1 ]] && echo "$CMD_OUT" | grep -q '"error"'; then
  skip "security code-scanning" "not enabled or no permission"
else
  fail "security code-scanning" "unexpected exit=$CMD_EXIT"
fi

run "$GH_MANAGER security secret-scanning --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "security secret-scanning"
elif [[ $CMD_EXIT -eq 1 ]] && echo "$CMD_OUT" | grep -q '"error"'; then
  skip "security secret-scanning" "not enabled or no permission"
else
  fail "security secret-scanning" "unexpected exit=$CMD_EXIT"
fi

run "$GH_MANAGER security advisories --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "security advisories"
else
  skip "security advisories" "not accessible"
fi

run "$GH_MANAGER security branch-rules --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "security branch-rules"
  run "$GH_MANAGER security branch-rules --repo $TEST_REPO"
  PROTECTED=$(json_val "protected")
  echo -e "    Default branch protected: ${CYAN}${PROTECTED}${RESET}"
elif [[ $CMD_EXIT -eq 1 ]] && echo "$CMD_OUT" | grep -q '"error"'; then
  skip "security branch-rules" "no admin access"
else
  fail "security branch-rules" "unexpected exit=$CMD_EXIT"
fi

# ── B8: Dependency Operations ──────────────────

group "B8: Dependency operations (read-only)"

run "$GH_MANAGER deps graph --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "deps graph"
elif [[ $CMD_EXIT -eq 1 ]] && echo "$CMD_OUT" | grep -q '"error"'; then
  skip "deps graph" "not enabled or no permission"
else
  fail "deps graph" "unexpected exit=$CMD_EXIT"
fi

assert_json "deps dependabot-prs" \
  "$GH_MANAGER deps dependabot-prs --repo $TEST_REPO"

# ── B9: Release Operations ─────────────────────

group "B9: Release operations (read-only)"

assert_json "releases list" \
  "$GH_MANAGER releases list --repo $TEST_REPO --limit 5"

run "$GH_MANAGER releases list --repo $TEST_REPO --limit 5"
REL_COUNT=$(json_val "count")
echo -e "  Releases found: ${CYAN}${REL_COUNT}${RESET}"

run "$GH_MANAGER releases latest --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  HAS_RELEASES=$(json_val "exists")
  if [[ "$HAS_RELEASES" == "false" ]]; then
    pass "releases latest (no releases)"
    skip "releases compare" "no releases exist"
  else
    pass "releases latest"
    TAG=$(json_val "tag_name")
    echo -e "    Latest: ${CYAN}${TAG}${RESET}"

    assert_json_has "releases compare returns total_commits" \
      "total_commits" \
      "$GH_MANAGER releases compare --repo $TEST_REPO"
  fi
else
  fail "releases latest" "exit=$CMD_EXIT"
fi

run "$GH_MANAGER releases changelog --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  CL_EXISTS=$(json_val "exists")
  if [[ "$CL_EXISTS" == "true" ]]; then
    pass "releases changelog (found $(json_val 'filename'))"
  else
    pass "releases changelog (no changelog file)"
  fi
else
  fail "releases changelog" "exit=$CMD_EXIT"
fi

# ── B10: Discussion Operations ─────────────────

group "B10: Discussion operations (read-only)"

run "$GH_MANAGER discussions list --repo $TEST_REPO"
if [[ $CMD_EXIT -eq 0 ]]; then
  DISC_ENABLED=$(json_val "enabled")
  if [[ "$DISC_ENABLED" == "false" ]]; then
    pass "discussions list (not enabled)"
    skip "discussions detail tests" "discussions not enabled"
  else
    pass "discussions list"
    DISC_COUNT=$(json_val "total")
    echo -e "    Discussions: ${CYAN}${DISC_COUNT}${RESET}"
  fi
else
  fail "discussions list" "exit=$CMD_EXIT"
fi

# ── B11: Notification Operations ───────────────

group "B11: Notification operations (read-only)"

assert_json "notifications list" \
  "$GH_MANAGER notifications list --repo $TEST_REPO"

# ── B12: Config Operations ─────────────────────

group "B12: Config operations (read-only)"

assert_json "config repo-read" \
  "$GH_MANAGER config repo-read --repo $TEST_REPO"

run "$GH_MANAGER config repo-read --repo $TEST_REPO"
CFG_EXISTS=$(json_val "exists")
echo -e "  Repo config exists: ${CYAN}${CFG_EXISTS}${RESET}"

assert_json "config portfolio-read" \
  "$GH_MANAGER config portfolio-read"

assert_json "config resolve" \
  "$GH_MANAGER config resolve --repo $TEST_REPO"

# ── Done ────────────────────────────────────────

summary
