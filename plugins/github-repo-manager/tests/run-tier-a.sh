#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# Tier A — Infrastructure Tests
# No API calls. No PAT required. Verifies the helper
# binary works, commands parse, dry-run flags short-circuit.
# ─────────────────────────────────────────────────
source "$(dirname "$0")/lib.sh"

echo -e "${BOLD}Tier A — Infrastructure (no API calls)${RESET}"

# ── A1: Binary & Version ────────────────────────

group "A1: Binary availability"

assert_ok "gh-manager --version prints version" \
  "$GH_MANAGER --version"
run "$GH_MANAGER --version"
if [[ "$CMD_OUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  pass "version format is semver"
else
  fail "version format is semver" "got: $CMD_OUT"
fi

assert_ok "gh-manager --help lists all command groups" \
  "$GH_MANAGER --help"
run "$GH_MANAGER --help"
EXPECTED_GROUPS=(auth repos repo files branches prs issues notifications security deps releases discussions config wiki)
for g in "${EXPECTED_GROUPS[@]}"; do
  if echo "$CMD_OUT" | grep -q "$g"; then
    pass "command group '$g' present in help"
  else
    fail "command group '$g' present in help"
  fi
done

# ── A2: Subcommand help parsing ─────────────────

group "A2: Subcommand help (every group parses without error)"

for g in "${EXPECTED_GROUPS[@]}"; do
  assert_ok "$g --help" "$GH_MANAGER $g --help"
done

# ── A3: Missing required options ────────────────

group "A3: Missing required options produce errors"

assert_fail "prs list without --repo fails" \
  "$GH_MANAGER prs list"

assert_fail "files get without --repo fails" \
  "$GH_MANAGER files get"

assert_fail "issues close without --repo fails" \
  "$GH_MANAGER issues close"

assert_fail "releases draft without --tag fails" \
  "$GH_MANAGER releases draft --repo x/y"

# ── A4: Dry-run (no PAT, no network) ────────────

group "A4: Dry-run short-circuits before API calls"

# These all need GITHUB_PAT set (even though they won't call the API)
export GITHUB_PAT=fake-pat-for-dry-run-tests

assert_dry_run "prs create --dry-run" \
  "$GH_MANAGER prs create --repo x/y --head feat --base main --title test --dry-run"

assert_dry_run "prs label --dry-run" \
  "$GH_MANAGER prs label --repo x/y --pr 1 --add bug --dry-run"

assert_dry_run "prs comment --dry-run" \
  "$GH_MANAGER prs comment --repo x/y --pr 1 --body test --dry-run"

assert_dry_run "prs request-review --dry-run" \
  "$GH_MANAGER prs request-review --repo x/y --pr 1 --reviewers user1 --dry-run"

assert_dry_run "prs merge --dry-run" \
  "$GH_MANAGER prs merge --repo x/y --pr 1 --dry-run"

assert_dry_run "prs close --dry-run" \
  "$GH_MANAGER prs close --repo x/y --pr 1 --dry-run"

assert_dry_run "issues label --dry-run" \
  "$GH_MANAGER issues label --repo x/y --issue 1 --add bug --dry-run"

assert_dry_run "issues comment --dry-run" \
  "$GH_MANAGER issues comment --repo x/y --issue 1 --body test --dry-run"

assert_dry_run "issues close --dry-run" \
  "$GH_MANAGER issues close --repo x/y --issue 1 --dry-run"

assert_dry_run "issues assign --dry-run" \
  "$GH_MANAGER issues assign --repo x/y --issue 1 --assignees user1 --dry-run"

assert_dry_run "notifications mark-read --dry-run (all)" \
  "$GH_MANAGER notifications mark-read --repo x/y --dry-run"

assert_dry_run "notifications mark-read --dry-run (thread)" \
  "$GH_MANAGER notifications mark-read --repo x/y --thread-id 123 --dry-run"

assert_dry_run "releases draft --dry-run" \
  "$GH_MANAGER releases draft --repo x/y --tag v1.0.0 --dry-run"

assert_dry_run "releases publish --dry-run" \
  "$GH_MANAGER releases publish --repo x/y --release-id 1 --dry-run"

assert_dry_run "discussions comment --dry-run" \
  "$GH_MANAGER discussions comment --repo x/y --discussion 1 --body test --dry-run"

assert_dry_run "discussions close --dry-run" \
  "$GH_MANAGER discussions close --repo x/y --discussion 1 --dry-run"

assert_dry_run "wiki init --dry-run" \
  "$GH_MANAGER wiki init --repo x/y --dry-run"

# wiki push --dry-run needs a real git dir to show pending changes.
# This is by design (it reads git status for the dry-run output).
# We test it properly in Tier C with a real wiki clone.
skip "wiki push --dry-run" "requires a cloned wiki dir (tested in Tier C)"

# Config dry-run (needs stdin)
run "echo 'repo: {}' | $GH_MANAGER config repo-write --repo x/y --dry-run"
if [[ $CMD_EXIT -eq 0 ]] && echo "$CMD_OUT" | grep -q '"dry_run": true'; then
  pass "config repo-write --dry-run"
else
  fail "config repo-write --dry-run" "exit=$CMD_EXIT"
fi

run "echo 'owner: {}' | $GH_MANAGER config portfolio-write --dry-run"
if [[ $CMD_EXIT -eq 0 ]] && echo "$CMD_OUT" | grep -q '"dry_run": true'; then
  pass "config portfolio-write --dry-run"
else
  fail "config portfolio-write --dry-run" "exit=$CMD_EXIT"
fi

unset GITHUB_PAT

# ── A5: Dry-run JSON structure ──────────────────

group "A5: Dry-run output structure"

export GITHUB_PAT=fake-pat-for-dry-run-tests

# Verify dry-run outputs contain the expected action field
run "$GH_MANAGER prs merge --repo x/y --pr 42 --method squash --dry-run"
actual_action=$(json_val "action")
if [[ "$actual_action" == "merge_pr" ]]; then
  pass "prs merge dry-run includes action=merge_pr"
else
  fail "prs merge dry-run includes action=merge_pr" "got: $actual_action"
fi

run "$GH_MANAGER prs merge --repo x/y --pr 42 --method squash --dry-run"
actual_method=$(json_val "method")
if [[ "$actual_method" == "squash" ]]; then
  pass "prs merge dry-run preserves --method"
else
  fail "prs merge dry-run preserves --method" "got: $actual_method"
fi

run "$GH_MANAGER issues close --repo x/y --issue 7 --reason not_planned --dry-run"
actual_reason=$(json_val "reason")
if [[ "$actual_reason" == "not_planned" ]]; then
  pass "issues close dry-run preserves --reason"
else
  fail "issues close dry-run preserves --reason" "got: $actual_reason"
fi

unset GITHUB_PAT

# ── A6: Config validation ───────────────────────

group "A6: Config YAML validation"

export GITHUB_PAT=fake-pat-for-dry-run-tests

# Invalid YAML should error
run "echo '  bad: yaml: [unclosed' | $GH_MANAGER config portfolio-write --dry-run"
if [[ $CMD_EXIT -ne 0 ]]; then
  pass "invalid YAML rejected on portfolio-write"
else
  fail "invalid YAML rejected on portfolio-write" "expected non-zero exit"
fi

run "echo '  bad: yaml: [unclosed' | $GH_MANAGER config repo-write --repo x/y --dry-run"
if [[ $CMD_EXIT -ne 0 ]]; then
  pass "invalid YAML rejected on repo-write"
else
  fail "invalid YAML rejected on repo-write" "expected non-zero exit"
fi

# Valid YAML should pass
run "echo 'repo:
  tier: 4' | $GH_MANAGER config repo-write --repo x/y --dry-run"
if [[ $CMD_EXIT -eq 0 ]]; then
  pass "valid YAML accepted on repo-write"
else
  fail "valid YAML accepted on repo-write" "exit=$CMD_EXIT"
fi

unset GITHUB_PAT

# ── A7: No-PAT error messages ──────────────────

group "A7: Missing PAT produces clear error"

unset GITHUB_PAT 2>/dev/null || true
run "$GH_MANAGER auth verify"
if [[ $CMD_EXIT -ne 0 ]] && echo "$CMD_OUT$CMD_ERR" | grep -qi "GITHUB_PAT"; then
  pass "auth verify without PAT mentions GITHUB_PAT"
else
  fail "auth verify without PAT mentions GITHUB_PAT" "exit=$CMD_EXIT"
fi

# ── Done ────────────────────────────────────────

summary
