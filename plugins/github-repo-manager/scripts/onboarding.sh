#!/usr/bin/env bash
set -euo pipefail

# onboarding.sh — Pre-session environment validation for github-repo-manager
#
# Validates deps, PAT, tier, portfolio config, and labels in one pass.
# Outputs a single JSON object summarizing readiness.
#
# Usage: onboarding.sh <plugin-root>

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

[ $# -ge 1 ] || { echo '{"error":"usage: onboarding.sh <plugin-root>"}' >&2; exit 1; }

PLUGIN_ROOT="$1"
HELPER="$PLUGIN_ROOT/helper/bin/gh-manager.js"
PORTFOLIO_PATH="$HOME/.config/github-repo-manager/portfolio.yml"

# Collector file — each check appends key=value lines, Python assembles final JSON
STATE=$(mktemp) ; trap 'rm -f "$STATE"' EXIT

add_error() { echo "error=$1" >> "$STATE"; }
add_skip()  { echo "skip=$1" >> "$STATE"; }

# --- Step 1: Dependencies ---
if ! bash "$PLUGIN_ROOT/scripts/ensure-deps.sh" >/dev/null 2>&1; then
  add_error "dependency installation failed"
  $PYTHON -c "
import json; print(json.dumps({'deps_installed':False,'pat_verified':False,'pat_scopes':[],'tier_detected':None,
'config':{'portfolio_found':False,'portfolio_path':'$PORTFOLIO_PATH'},'labels':{'checked':False},
'ready':False,'errors':['dependency installation failed'],'skipped':[]},indent=2))"
  exit 0
fi
echo "deps_installed=true" >> "$STATE"

# --- Step 2: Verify PAT ---
auth_output=""
if auth_output=$(node "$HELPER" auth verify 2>&1); then
  echo "pat_verified=true" >> "$STATE"
  echo "auth_json=$auth_output" >> "$STATE"
else
  echo "pat_verified=false" >> "$STATE"
  add_error "PAT verification failed: $(echo "$auth_output" | head -1)"
fi

# --- Step 3: Detect tier from rate limit ---
if grep -q "pat_verified=true" "$STATE"; then
  rate_output=""
  if rate_output=$(node "$HELPER" repos rate-limit 2>&1); then
    echo "rate_json=$rate_output" >> "$STATE"
  else
    add_skip "rate limit check failed, tier defaulting to unknown"
  fi
else
  add_skip "tier detection skipped: PAT not verified"
fi

# --- Step 4: Portfolio config ---
if [ -f "$PORTFOLIO_PATH" ]; then
  echo "config_found=true" >> "$STATE"
else
  echo "config_found=false" >> "$STATE"
  add_skip "portfolio.yml not found at $PORTFOLIO_PATH"
fi

# --- Step 5: Labels on first configured repo ---
first_repo=""
if [ -f "$PORTFOLIO_PATH" ]; then
  first_repo=$($PYTHON -c "
for line in open('$PORTFOLIO_PATH'):
    s=line.strip()
    if s.startswith('- ') and '/' in s:
        v=s[2:].split(':',1)[-1].strip() if ':' in s else s[2:].strip()
        if '/' in v: print(v); break
" 2>/dev/null || echo "")
fi
echo "first_repo=$first_repo" >> "$STATE"

if [ -n "$first_repo" ] && grep -q "pat_verified=true" "$STATE"; then
  labels_output=""
  if labels_output=$(node "$HELPER" repo labels list --repo "$first_repo" 2>&1); then
    echo "labels_json=$labels_output" >> "$STATE"
  else
    add_skip "label check failed for $first_repo"
  fi
elif [ -z "$first_repo" ]; then
  add_skip "label check skipped: no repo found in portfolio"
else
  add_skip "label check skipped: PAT not verified"
fi

# --- Assemble JSON output ---
STATE_FILE="$STATE" PORTFOLIO_PATH="$PORTFOLIO_PATH" $PYTHON << 'PYEOF'
import json, os

state, errors, skips = {}, [], []
for line in open(os.environ["STATE_FILE"]):
    line = line.strip()
    if not line or "=" not in line: continue
    k, v = line.split("=", 1)
    if k == "error": errors.append(v)
    elif k == "skip": skips.append(v)
    else: state[k] = v

pat_scopes = []
if state.get("auth_json"):
    try:
        d = json.loads(state["auth_json"])
        pat_scopes = d.get("scopes", d.get("pat_scopes", []))
    except: pass

tier = "unknown"
if state.get("rate_json"):
    try:
        d = json.loads(state["rate_json"])
        lim = d.get("rate", {}).get("limit", d.get("_rate_limit", {}).get("limit", 0))
        tier = "enterprise" if lim >= 15000 else "authenticated" if lim >= 5000 else "unauthenticated"
    except: pass

labels_ok = False
if state.get("labels_json"):
    try:
        d = json.loads(state["labels_json"])
        names = {l.get("name", "").lower() for l in d.get("labels", [])}
        labels_ok = {"bug", "enhancement", "documentation"}.issubset(names)
    except: pass

first_repo = state.get("first_repo", "")
print(json.dumps({
    "deps_installed": state.get("deps_installed") == "true",
    "pat_verified": state.get("pat_verified") == "true",
    "pat_scopes": pat_scopes,
    "tier_detected": tier,
    "config": {
        "portfolio_found": state.get("config_found") == "true",
        "portfolio_path": os.environ["PORTFOLIO_PATH"],
        "first_repo": first_repo or None
    },
    "labels": {
        "checked": bool(first_repo),
        "standard_present": labels_ok,
        "repo": first_repo or None
    },
    "ready": not errors,
    "errors": errors,
    "skipped": skips
}, indent=2))
PYEOF
