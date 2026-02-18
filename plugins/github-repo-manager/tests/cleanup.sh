#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# cleanup.sh — Remove accumulated self-test artifacts
# from the test repo. Closes open [Self-test] issues/PRs,
# deletes test branches and labels.
#
# Usage: bash tests/cleanup.sh
# ─────────────────────────────────────────────────

set -uo pipefail

TEST_REPO="${TEST_REPO:-L3DigitalNet/testing}"

if [[ -z "${GITHUB_PAT:-}" ]]; then
  echo "GITHUB_PAT is not set."
  exit 1
fi

API="https://api.github.com/repos/${TEST_REPO}"
AUTH=(-H "Authorization: token ${GITHUB_PAT}" -H "Accept: application/vnd.github+json")

echo "Cleaning test artifacts from ${TEST_REPO}..."

# Close open [Self-test] issues
echo ""
echo "── Closing open [Self-test] issues ──"
ISSUES=$(curl -s "${AUTH[@]}" "${API}/issues?state=open&per_page=100")
echo "$ISSUES" | node -e "
  const issues = JSON.parse(require('fs').readFileSync(0,'utf8'));
  const selfTest = issues.filter(i => !i.pull_request && i.title.includes('[Self-test]'));
  selfTest.forEach(i => console.log(i.number + ' ' + i.title));
  if (!selfTest.length) console.log('(none found)');
" 2>/dev/null

echo "$ISSUES" | node -e "
  const issues = JSON.parse(require('fs').readFileSync(0,'utf8'));
  issues.filter(i => !i.pull_request && i.title.includes('[Self-test]'))
    .forEach(i => process.stdout.write(i.number + '\n'));
" 2>/dev/null | while read -r num; do
  curl -s -X PATCH "${AUTH[@]}" "${API}/issues/${num}" -d '{"state":"closed"}' >/dev/null
  echo "  Closed issue #${num}"
done

# Close open [Self-test] PRs
echo ""
echo "── Closing open [Self-test] PRs ──"
PRS=$(curl -s "${AUTH[@]}" "${API}/pulls?state=open&per_page=100")
echo "$PRS" | node -e "
  const prs = JSON.parse(require('fs').readFileSync(0,'utf8'));
  const selfTest = prs.filter(p => p.title.includes('[Self-test]'));
  selfTest.forEach(p => console.log(p.number + ' ' + p.title));
  if (!selfTest.length) console.log('(none found)');
" 2>/dev/null

echo "$PRS" | node -e "
  const prs = JSON.parse(require('fs').readFileSync(0,'utf8'));
  prs.filter(p => p.title.includes('[Self-test]'))
    .forEach(p => process.stdout.write(p.number + '\n'));
" 2>/dev/null | while read -r num; do
  curl -s -X PATCH "${AUTH[@]}" "${API}/pulls/${num}" -d '{"state":"closed"}' >/dev/null
  echo "  Closed PR #${num}"
done

# Delete test branches
echo ""
echo "── Deleting test/ branches ──"
BRANCHES=$(curl -s "${AUTH[@]}" "${API}/branches?per_page=100")
echo "$BRANCHES" | node -e "
  const branches = JSON.parse(require('fs').readFileSync(0,'utf8'));
  branches.filter(b => b.name.startsWith('test/'))
    .forEach(b => process.stdout.write(b.name + '\n'));
" 2>/dev/null | while read -r name; do
  curl -s -X DELETE "${AUTH[@]}" "${API}/git/refs/heads/${name}" >/dev/null
  echo "  Deleted branch ${name}"
done

# Delete test labels
echo ""
echo "── Deleting test- labels ──"
LABELS=$(curl -s "${AUTH[@]}" "${API}/labels?per_page=100")
echo "$LABELS" | node -e "
  const labels = JSON.parse(require('fs').readFileSync(0,'utf8'));
  labels.filter(l => l.name.startsWith('test-label-'))
    .forEach(l => process.stdout.write(l.name + '\n'));
" 2>/dev/null | while read -r name; do
  curl -s -X DELETE "${AUTH[@]}" "${API}/labels/${name}" >/dev/null
  echo "  Deleted label ${name}"
done

# Delete test releases
echo ""
echo "── Deleting test releases ──"
RELEASES=$(curl -s "${AUTH[@]}" "${API}/releases?per_page=100")
echo "$RELEASES" | node -e "
  const rels = JSON.parse(require('fs').readFileSync(0,'utf8'));
  rels.filter(r => r.tag_name.includes('-test-'))
    .forEach(r => process.stdout.write(r.id + ' ' + r.tag_name + '\n'));
" 2>/dev/null | while read -r id tag; do
  curl -s -X DELETE "${AUTH[@]}" "${API}/releases/${id}" >/dev/null
  curl -s -X DELETE "${AUTH[@]}" "${API}/git/refs/tags/${tag}" >/dev/null 2>&1
  echo "  Deleted release ${tag}"
done

# Delete test files
echo ""
echo "── Deleting test files ──"
TEST_FILES=$(curl -s "${AUTH[@]}" "${API}/contents/test-files" 2>/dev/null)
if echo "$TEST_FILES" | node -e "JSON.parse(require('fs').readFileSync(0,'utf8'))" 2>/dev/null; then
  echo "$TEST_FILES" | node -e "
    const files = JSON.parse(require('fs').readFileSync(0,'utf8'));
    if (Array.isArray(files)) {
      files.forEach(f => process.stdout.write(f.path + ' ' + f.sha + '\n'));
    }
  " 2>/dev/null | while read -r path sha; do
    curl -s -X DELETE "${AUTH[@]}" "${API}/contents/${path}" \
      -d "{\"message\":\"cleanup: remove ${path}\",\"sha\":\"${sha}\"}" >/dev/null
    echo "  Deleted ${path}"
  done
else
  echo "  (no test-files directory)"
fi

# Delete .github-repo-manager.yml if present
echo ""
echo "── Checking for leftover config ──"
CFG=$(curl -s "${AUTH[@]}" "${API}/contents/.github-repo-manager.yml" 2>/dev/null)
CFG_SHA=$(echo "$CFG" | node -e "
  try {
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    if (d.sha) process.stdout.write(d.sha);
  } catch {}
" 2>/dev/null)
if [[ -n "$CFG_SHA" ]]; then
  curl -s -X DELETE "${AUTH[@]}" "${API}/contents/.github-repo-manager.yml" \
    -d "{\"message\":\"cleanup: remove config\",\"sha\":\"${CFG_SHA}\"}" >/dev/null
  echo "  Deleted .github-repo-manager.yml"
else
  echo "  (none found)"
fi

echo ""
echo "Done. Closed issues/PRs remain in history (can't be deleted via API)."
