#!/usr/bin/env bash
# Claude Sync — Git repository sync cycle
# Scans for git repos, runs commit/push/fetch/pull on each.
# Returns structured JSON to stdout. Progress/errors to stderr.
#
# Usage: git-sync.sh <repos_root> <hostname> [<exclude_entries>]
#   repos_root:      root directory to scan recursively for .git dirs
#   hostname:        machine hostname for auto-commit messages
#   exclude_entries: newline-separated absolute paths to skip (optional)

set -uo pipefail

die() { jq -n --arg e "$1" '{"error":$e}'; exit 1; }

REPOS_ROOT="${1:?Usage: git-sync.sh <repos_root> <hostname> [exclude_entries]}"
HOSTNAME="${2:?Usage: git-sync.sh <repos_root> <hostname> [exclude_entries]}"
EXCLUDES_RAW="${3:-}"

command -v jq  >/dev/null 2>&1 || die "jq is required but not installed"
command -v git >/dev/null 2>&1 || die "git is required but not installed"
[ -d "$REPOS_ROOT" ] || die "repos root not found: $REPOS_ROOT"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT

# --- Exclude list -----------------------------------------------------------
declare -a EXCLUDES=()
if [ -n "$EXCLUDES_RAW" ]; then
    while IFS= read -r entry; do
        entry="${entry/#\~/$HOME}"
        [ -n "$entry" ] && EXCLUDES+=("$entry")
    done <<< "$EXCLUDES_RAW"
fi

is_excluded() {
    local p="$1"
    for e in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
        [[ "$p" == "$e" || "$p" == "$e"/* ]] && return 0
    done
    return 1
}

# --- Discover repos ----------------------------------------------------------
mapfile -t GIT_DIRS < <(find "$REPOS_ROOT" -name .git -type d 2>/dev/null | sort)
total=${#GIT_DIRS[@]}
synced=0; warnings=0; skipped=0; excluded=0

for git_dir in "${GIT_DIRS[@]}"; do
    repo=$(dirname "$git_dir")
    name=$(basename "$repo")

    # Excluded — invisible
    if is_excluded "$repo"; then
        excluded=$((excluded + 1))
        continue
    fi

    # Remote check
    remote=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
    if [ -z "$remote" ]; then
        jq -n --arg n "$name" --arg p "$repo" \
            '{"name":$n,"path":$p,"remote":"","status":"no_remote",
              "committed":0,"push_ok":false,"push_error":"",
              "message":"no remote configured \u2014 skipped"}' \
            >> "$RESULTS_FILE"
        skipped=$((skipped + 1))
        continue
    fi

    # --- Commit tracked changes ----------------------------------------------
    committed=0
    needs_commit=false
    git -C "$repo" diff --quiet 2>/dev/null || needs_commit=true
    git -C "$repo" diff --cached --quiet 2>/dev/null || needs_commit=true

    if $needs_commit; then
        git -C "$repo" add -u 2>/dev/null || true
        if ! git -C "$repo" diff --cached --quiet 2>/dev/null; then
            if git -C "$repo" commit -m "chore: claude-sync auto-commit [$HOSTNAME] [$TIMESTAMP]" \
                    >/dev/null 2>&1; then
                committed=$(git -C "$repo" diff --stat HEAD~1 2>/dev/null \
                    | tail -1 | grep -oE '[0-9]+' | head -1 || echo 1)
                [ -z "$committed" ] && committed=1
            fi
        fi
    fi

    # --- Push ----------------------------------------------------------------
    push_ok=true; push_err=""
    if ! out=$(git -C "$repo" push 2>&1); then
        push_ok=false
        push_err=$(printf '%s' "$out" | head -3 | tr '\n' ' ')
    fi

    # --- Fetch + pull (best-effort) ------------------------------------------
    git -C "$repo" fetch --quiet 2>/dev/null || true
    git -C "$repo" pull --no-edit --quiet 2>/dev/null || true

    # --- Status and message --------------------------------------------------
    if [ "$push_ok" = false ]; then
        if [ "$committed" -gt 0 ]; then
            msg="committed $committed changes \u00b7 push failed \u00b7 pulled"
        else
            msg="push failed \u2014 ${push_err:0:100} (continuing)"
        fi
        st="push_failed"
        warnings=$((warnings + 1))
    elif [ "$committed" -gt 0 ]; then
        msg="committed $committed changes \u00b7 pushed \u00b7 pulled"
        st="synced"
        synced=$((synced + 1))
    else
        msg="up to date"
        st="up_to_date"
        synced=$((synced + 1))
    fi

    jq -n --arg n "$name" --arg p "$repo" --arg r "$remote" --arg s "$st" \
        --argjson c "$committed" --argjson po "$push_ok" \
        --arg pe "$push_err" --arg m "$msg" \
        '{"name":$n,"path":$p,"remote":$r,"status":$s,
          "committed":$c,"push_ok":$po,"push_error":$pe,"message":$m}' \
        >> "$RESULTS_FILE"
done

# --- Assemble JSON output ----------------------------------------------------
RESULTS=$(jq -s '.' "$RESULTS_FILE" 2>/dev/null || echo '[]')

jq -n \
    --arg root "$REPOS_ROOT" \
    --argjson total "$total" \
    --argjson results "$RESULTS" \
    --argjson synced "$synced" \
    --argjson warnings "$warnings" \
    --argjson skipped "$skipped" \
    --argjson excluded "$excluded" \
    '{repos_root:$root, total_found:$total, results:$results,
      summary:{synced:$synced, warnings:$warnings,
               skipped:$skipped, excluded:$excluded}}'
