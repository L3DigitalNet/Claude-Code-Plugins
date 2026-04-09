#!/usr/bin/env bash
set -euo pipefail

# batch-executor.sh — Sequential mutation executor with rate limit awareness
#
# Reads a plan JSON file containing a mutations array, executes each via the
# gh-manager helper CLI, and logs results to the audit trail.
# Stops early if rate_limit_remaining drops below the safety threshold.
#
# Usage: batch-executor.sh <plan-json-path> <plugin-root> [--min-remaining 100] [--dry-run]

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

[ $# -ge 2 ] || { echo '{"error":"usage: batch-executor.sh <plan-json-path> <plugin-root> [--min-remaining N] [--dry-run]"}' >&2; exit 1; }

PLAN_PATH="$1"; PLUGIN_ROOT="$2"; shift 2
MIN_REMAINING=100; DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --min-remaining) MIN_REMAINING="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    *) echo "{\"error\":\"unknown option: $1\"}" >&2; exit 1 ;;
  esac
done

HELPER="$PLUGIN_ROOT/helper/bin/gh-manager.js"
AUDIT_LOG="$HOME/.github-repo-manager-audit.log"
[ -f "$PLAN_PATH" ] || { echo "{\"error\":\"plan file not found: $PLAN_PATH\"}" >&2; exit 1; }
[ -f "$HELPER" ]    || { echo "{\"error\":\"helper not found: $HELPER\"}" >&2; exit 1; }

RESULTS_FILE=$(mktemp); trap 'rm -f "$RESULTS_FILE"' EXIT

# Delegate execution loop to Python — minimizes bash/python boundary crossings
PLAN_PATH="$PLAN_PATH" HELPER="$HELPER" AUDIT_LOG="$AUDIT_LOG" \
  MIN_REMAINING="$MIN_REMAINING" DRY_RUN="$DRY_RUN" RESULTS_FILE="$RESULTS_FILE" \
  $PYTHON << 'PYEOF'
import json, os, subprocess, sys
from datetime import datetime

plan_path = os.environ["PLAN_PATH"]
helper = os.environ["HELPER"]
audit_log = os.environ["AUDIT_LOG"]
min_remaining = int(os.environ["MIN_REMAINING"])
dry_run = os.environ["DRY_RUN"] == "true"
results_file = os.environ["RESULTS_FILE"]

with open(plan_path) as f:
    mutations = json.load(f).get("mutations", [])

total = len(mutations)
if total == 0:
    print(json.dumps({"total":0,"succeeded":0,"failed":0,"skipped":0,"results":[],"rate_limit_remaining":None}))
    sys.exit(0)

succeeded, failed, skipped = 0, 0, 0
rate_remaining = None
results = []

def timestamp():
    return datetime.now().astimezone().isoformat(timespec="seconds")

def audit(msg):
    try:
        with open(audit_log, "a") as f:
            f.write(f"[{timestamp()}] {msg}\n")
    except: pass

for i, m in enumerate(mutations):
    cmd = m.get("command", "")
    args = m.get("args", [])
    desc = m.get("description", cmd)

    # Rate limit safety stop
    if rate_remaining is not None and rate_remaining < min_remaining:
        remaining_count = total - i
        skipped += remaining_count
        audit(f"[BATCH-SKIP] rate limit below threshold ({rate_remaining} < {min_remaining}), skipping {remaining_count} mutations")
        for j in range(i, total):
            sd = mutations[j].get("description", mutations[j].get("command", "unknown"))
            results.append({"index": j, "status": "skipped", "reason": "rate_limit_below_threshold", "description": sd})
        break

    if dry_run:
        args_str = " ".join(str(a) for a in args)
        audit(f"[DRY-RUN] {cmd} {args_str}")
        results.append({"index": i, "status": "dry_run", "command": cmd, "description": desc})
        skipped += 1
        continue

    # Build and execute the command
    full_cmd = ["node", helper] + cmd.split() + [str(a) for a in args]
    try:
        proc = subprocess.run(full_cmd, capture_output=True, text=True, timeout=60)
        output = proc.stdout

        # Extract rate limit from response
        try:
            d = json.loads(output)
            r = d.get("_rate_limit", {}).get("remaining")
            if r is not None:
                rate_remaining = int(r)
        except: pass

        args_str = " ".join(str(a) for a in args)
        if proc.returncode == 0:
            audit(f"[BATCH-OK] {cmd} {args_str}")
            results.append({"index": i, "status": "succeeded", "command": cmd, "description": desc})
            succeeded += 1
        else:
            audit(f"[BATCH-FAIL] {cmd} {args_str} (exit {proc.returncode})")
            err_msg = (proc.stderr or output or "")[:200]
            results.append({"index": i, "status": "failed", "command": cmd, "description": desc, "error": err_msg})
            failed += 1
    except subprocess.TimeoutExpired:
        audit(f"[BATCH-FAIL] {cmd} (timeout)")
        results.append({"index": i, "status": "failed", "command": cmd, "description": desc, "error": "timeout after 60s"})
        failed += 1
    except Exception as e:
        audit(f"[BATCH-FAIL] {cmd} ({e})")
        results.append({"index": i, "status": "failed", "command": cmd, "description": desc, "error": str(e)[:200]})
        failed += 1

print(json.dumps({
    "total": total,
    "succeeded": succeeded,
    "failed": failed,
    "skipped": skipped,
    "results": results,
    "rate_limit_remaining": rate_remaining
}, indent=2))
PYEOF
