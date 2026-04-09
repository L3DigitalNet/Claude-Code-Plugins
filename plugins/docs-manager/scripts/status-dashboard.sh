#!/usr/bin/env bash
# status-dashboard.sh — Consolidated health check for /docs status.
#
# Usage: status-dashboard.sh [--test]
# Output: JSON with operational and library health data.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

TEST_MODE=false
[[ "${1:-}" == "--test" ]] && TEST_MODE=true

export TEST_MODE

$PYTHON << 'PYEOF'
import json, os, sys
from datetime import datetime, timedelta

test_mode = os.environ.get("TEST_MODE") == "true"
home = os.path.expanduser("~")
dm_dir = os.path.join(home, ".docs-manager")

tests = []

def test(name, passed, detail=None):
    if test_mode:
        entry = {"name": name, "pass": passed}
        if detail:
            entry["detail"] = detail
        tests.append(entry)

# --- Operational Health ---

operational = {
    "config": {"exists": False, "valid": False, "path": "~/.docs-manager/config.yaml",
               "index_type": None, "machine_id": None},
    "hooks": {"post_tool_use": {"last_fired": None, "age_seconds": None},
              "stop": {"last_fired": None, "age_seconds": None}},
    "queue": {"parseable": False, "item_count": 0, "path": "~/.docs-manager/queue.json"},
    "lock": {"exists": False, "stale": False},
    "fallback": {"exists": False},
}

index_path = None

# Config
config_path = os.path.join(dm_dir, "config.yaml")
if not os.path.isdir(dm_dir):
    test("config_exists", False, "~/.docs-manager/ does not exist")
elif os.path.exists(config_path):
    operational["config"]["exists"] = True
    test("config_exists", True)

    try:
        with open(config_path, encoding="utf-8") as f:
            config_lines = f.readlines()

        config = {}
        for line in config_lines:
            line = line.rstrip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("  - "):
                continue  # list item
            if ": " in line:
                k, v = line.split(": ", 1)
                config[k.strip()] = v.strip()
            elif line.endswith(":"):
                pass  # list key
            # Ignore other lines silently

        operational["config"]["valid"] = True
        operational["config"]["index_type"] = config.get("index_type")
        operational["config"]["machine_id"] = config.get("machine_id")
        index_path = config.get("index_path")
        test("config_valid", True)
    except Exception as e:
        test("config_valid", False, str(e))
else:
    test("config_exists", False, "config.yaml not found")

# Hooks
hooks_dir = os.path.join(dm_dir, "hooks")
now = datetime.now()
if os.path.isdir(hooks_dir):
    for hook_name, hook_key in [("post-tool-use.last-fired", "post_tool_use"),
                                  ("stop.last-fired", "stop")]:
        hook_file = os.path.join(hooks_dir, hook_name)
        if os.path.exists(hook_file):
            try:
                with open(hook_file) as f:
                    ts_str = f.read().strip()
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00").replace("+00:00", ""))
                age = int((now - ts).total_seconds())
                operational["hooks"][hook_key]["last_fired"] = ts_str
                operational["hooks"][hook_key]["age_seconds"] = age
            except Exception:
                pass

# Queue
queue_path = os.path.join(dm_dir, "queue.json")
queue_items = []
if os.path.exists(queue_path):
    size = os.path.getsize(queue_path)
    if size == 0:
        operational["queue"]["parseable"] = False
        test("queue_parseable", False, "empty file")
    else:
        try:
            with open(queue_path) as f:
                queue_data = json.load(f)
            if isinstance(queue_data, list):
                queue_items = queue_data
            elif isinstance(queue_data, dict):
                queue_items = queue_data.get("items", [])
            operational["queue"]["parseable"] = True
            operational["queue"]["item_count"] = len(queue_items)
            test("queue_parseable", True)
        except json.JSONDecodeError:
            test("queue_parseable", False, "invalid JSON")
else:
    operational["queue"]["parseable"] = True  # no file = empty queue, not error
    test("queue_parseable", True)

# Lock
lock_path = os.path.join(dm_dir, "index.lock")
if os.path.exists(lock_path):
    operational["lock"]["exists"] = True
    age = now.timestamp() - os.path.getmtime(lock_path)
    operational["lock"]["stale"] = age > 300
    test("no_stale_lock", not operational["lock"]["stale"],
         f"lock age: {int(age)}s" if operational["lock"]["stale"] else None)
else:
    test("no_stale_lock", True)

# Fallback
fallback_path = os.path.join(dm_dir, "queue.fallback.json")
operational["fallback"]["exists"] = os.path.exists(fallback_path)
test("no_pending_fallback", not operational["fallback"]["exists"])

# --- Library Health ---

library = {
    "available": False,
    "total_documents": 0,
    "missing_source_files": 0,
    "missing_upstream_url": 0,
    "overdue_verification": 0,
    "overdue_threshold_days": 90,
    "pending_queue_items": len(queue_items),
    "libraries": [],
}

if index_path:
    idx_file = os.path.expanduser(index_path)
    if not idx_file.endswith(".json"):
        # Try common index names
        for name in ("docs-index.json", "index.json"):
            candidate = os.path.join(idx_file, name)
            if os.path.exists(candidate):
                idx_file = candidate
                break

    if os.path.exists(idx_file):
        try:
            with open(idx_file) as f:
                index_data = json.load(f)

            docs = []
            if isinstance(index_data, list):
                docs = index_data
            elif isinstance(index_data, dict):
                docs = index_data.get("documents", index_data.get("entries", []))

            library["available"] = True
            library["total_documents"] = len(docs)
            test("index_readable", True)

            threshold = now - timedelta(days=90)
            lib_counts = {}
            for doc in docs:
                if not doc.get("source_files") and not doc.get("source-files"):
                    library["missing_source_files"] += 1
                if not doc.get("upstream_url") and not doc.get("upstream-url"):
                    library["missing_upstream_url"] += 1
                verified = doc.get("last_verified") or doc.get("last-verified")
                if verified:
                    try:
                        v_date = datetime.fromisoformat(verified.replace("Z", "+00:00").replace("+00:00", ""))
                        if v_date < threshold:
                            library["overdue_verification"] += 1
                    except Exception:
                        pass

                lib_name = doc.get("library") or doc.get("collection") or "default"
                lib_counts[lib_name] = lib_counts.get(lib_name, 0) + 1

            library["libraries"] = [{"name": k, "documents": v} for k, v in sorted(lib_counts.items())]

            overdue = library["overdue_verification"]
            test("no_overdue_verification", overdue == 0,
                 f"{overdue} document(s) overdue" if overdue else None)

        except Exception as e:
            test("index_readable", False, str(e))
    else:
        test("index_readable", False, f"index file not found: {idx_file}")

result = {
    "operational": operational,
    "library": library,
}

if test_mode:
    result["tests"] = tests

print(json.dumps(result, indent=2))
PYEOF
