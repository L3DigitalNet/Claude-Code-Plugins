#!/usr/bin/env bash
set -euo pipefail

# fix-git-email.sh — Check and auto-repair git noreply email for releases.
#
# Usage: fix-git-email.sh <repo-path> [--auto-fix] [--scope local|global]
#   Default:     check only — exit 0 if noreply, exit 1 if not.
#   --auto-fix:  detect GitHub username from gh CLI or remote URL, then set noreply email.
#   --scope:     local (repo git config, default) or global (user-level git config).
#
# Output: "OK: <email>", "FIXED: set user.email → <email>", or "FAIL: <reason>"
# Exit:   0 = email is (or was fixed to) a noreply address, 1 = not noreply and unfixable
#
# Username detection order (for --auto-fix):
#   1. gh api user --jq '.login'  (gh CLI, most reliable)
#   2. HTTPS remote: https://github.com/<owner>/<repo>
#   3. SSH remote:   git@github.com:<owner>/<repo>
#
# Called by: templates/mode-2-full-release.md (Phase 0.5 auto-heal),
#            templates/mode-3-plugin-release.md (same),
#            templates/mode-7-batch-release.md (pre-loop auto-heal)

REPO=""
AUTO_FIX=false
SCOPE="local"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-fix) AUTO_FIX=true; shift ;;
    --scope)    SCOPE="$2"; shift 2 ;;
    -*)         echo "Error: unknown flag '$1'" >&2; exit 1 ;;
    *)          REPO="$1"; shift ;;
  esac
done

REPO="${REPO:-.}"

if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

if [[ "$SCOPE" != "local" && "$SCOPE" != "global" ]]; then
  echo "Error: --scope must be 'local' or 'global'" >&2
  exit 1
fi

# ---------- Check current email ----------

current_email=$(git -C "$REPO" config user.email 2>/dev/null || echo "")

if [[ "$current_email" =~ @users\.noreply\.github\.com$ ]]; then
  echo "OK: ${current_email}"
  exit 0
fi

if [[ "$AUTO_FIX" == false ]]; then
  echo "FAIL: '${current_email}' is not a GitHub noreply address"
  exit 1
fi

# ---------- Auto-fix: detect GitHub username ----------

gh_user=""

# 1. gh CLI — most reliable, works even without a GitHub remote
if command -v gh &>/dev/null; then
  gh_user=$(gh api user --jq '.login' 2>/dev/null || true)
fi

# 2. Parse remote URL (HTTPS or SSH) as fallback
if [[ -z "$gh_user" ]]; then
  remote_url=$(git -C "$REPO" remote get-url origin 2>/dev/null || true)
  # HTTPS: https://github.com/owner/repo[.git]
  if [[ "$remote_url" =~ ^https://github\.com/([^/]+)/ ]]; then
    gh_user="${BASH_REMATCH[1]}"
  # SSH: git@github.com:owner/repo[.git]
  elif [[ "$remote_url" =~ ^git@github\.com:([^/]+)/ ]]; then
    gh_user="${BASH_REMATCH[1]}"
  fi
fi

if [[ -z "$gh_user" ]]; then
  echo "FAIL: could not detect GitHub username (gh CLI unauthenticated and no GitHub remote)"
  exit 1
fi

new_email="${gh_user}@users.noreply.github.com"

if [[ "$SCOPE" == "global" ]]; then
  git config --global user.email "$new_email"
else
  git -C "$REPO" config user.email "$new_email"
fi

echo "FIXED: set user.email → ${new_email} (${SCOPE} scope)"
exit 0
