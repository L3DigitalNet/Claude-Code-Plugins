#!/usr/bin/env bash
# apply-snapshot.sh — Apply snapshot files to local system by category.
#
# Usage: apply-snapshot.sh <snapshot-dir> <category> [--dry-run]
#   category: settings, plugins, claude-md
# Output: JSON with actions taken and summary.
# Exit:   0 on success, 1 on invalid args.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

SNAPSHOT_DIR="${1:?Usage: apply-snapshot.sh <snapshot-dir> <category> [--dry-run]}"
CATEGORY="${2:?Usage: apply-snapshot.sh <snapshot-dir> <category> [--dry-run]}"
DRY_RUN=false
[[ "${3:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

export SNAPSHOT_DIR CATEGORY DRY_RUN SCRIPT_DIR

$PYTHON << 'PYEOF'
import json, os, shutil, subprocess, sys
from datetime import datetime

snapshot_dir = os.environ["SNAPSHOT_DIR"]
category = os.environ["CATEGORY"]
dry_run = os.environ["DRY_RUN"] == "true"
script_dir = os.environ["SCRIPT_DIR"]

home = os.path.expanduser("~")
actions = []

def ts():
    return datetime.now().strftime("%Y%m%d%H%M%S")

def apply_file(src, dst, reason):
    """Copy src to dst with backup."""
    action = {"file": os.path.relpath(dst, home), "action": "skipped", "reason": reason}

    if os.path.exists(dst):
        src_mtime = os.path.getmtime(src)
        dst_mtime = os.path.getmtime(dst)

        if src_mtime > dst_mtime:
            action["action"] = "updated"
            action["reason"] = f"snapshot newer ({datetime.fromtimestamp(src_mtime).strftime('%Y-%m-%d')} vs {datetime.fromtimestamp(dst_mtime).strftime('%Y-%m-%d')})"
            if not dry_run:
                backup = f"{dst}.bak.{ts()}"
                shutil.copy2(dst, backup)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
        else:
            action["action"] = "skipped"
            action["reason"] = "local newer"
    else:
        action["action"] = "created"
        action["reason"] = "new in snapshot"
        if not dry_run:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    return action

if category == "settings":
    src_dir = os.path.join(snapshot_dir, "claude")
    dst_dir = os.path.join(home, ".claude")

    if os.path.isdir(src_dir):
        for root, dirs, files in os.walk(src_dir):
            for fname in files:
                src_path = os.path.join(root, fname)
                rel = os.path.relpath(src_path, src_dir)
                dst_path = os.path.join(dst_dir, rel)
                actions.append(apply_file(src_path, dst_path, ""))

elif category == "plugins":
    src_dir = os.path.join(snapshot_dir, "plugins")
    dst_dir = os.path.join(home, ".claude", "plugins")

    if os.path.isdir(src_dir):
        for root, dirs, files in os.walk(src_dir):
            for fname in files:
                src_path = os.path.join(root, fname)
                rel = os.path.relpath(src_path, src_dir)
                dst_path = os.path.join(dst_dir, rel)

                # Special handling for installed_plugins.json: merge
                if fname == "installed_plugins.json" and os.path.exists(dst_path):
                    try:
                        with open(src_path) as f:
                            snap_data = json.load(f)
                        with open(dst_path) as f:
                            local_data = json.load(f)

                        # Union merge: snapshot wins on conflicts
                        if isinstance(snap_data, dict) and isinstance(local_data, dict):
                            merged = {**local_data, **snap_data}
                            if not dry_run:
                                backup = f"{dst_path}.bak.{ts()}"
                                shutil.copy2(dst_path, backup)
                                tmp = dst_path + ".tmp"
                                with open(tmp, "w") as f:
                                    json.dump(merged, f, indent=2)
                                os.rename(tmp, dst_path)
                            actions.append({
                                "file": rel, "action": "merged",
                                "reason": f"union merge ({len(merged)} plugins)"
                            })
                            continue
                    except Exception as e:
                        actions.append({
                            "file": rel, "action": "error",
                            "reason": f"merge failed: {e}"
                        })
                        continue

                actions.append(apply_file(src_path, dst_path, ""))

elif category == "claude-md":
    src_file = os.path.join(snapshot_dir, "claude-md", "CLAUDE.md")
    dst_file = os.path.join(home, ".claude", "CLAUDE.md")

    if not os.path.exists(src_file):
        actions.append({"file": "CLAUDE.md", "action": "skipped", "reason": "not in snapshot"})
    else:
        # Read snapshot content
        with open(src_file, encoding="utf-8") as f:
            snap_content = f.read()

        # Extract local config block via config-block.sh
        import re
        local_config_block = ""
        if os.path.exists(dst_file):
            with open(dst_file, encoding="utf-8") as f:
                local_content = f.read()
            m = re.search(r'<!--\s*claude-sync-config\s*\n.*?-->', local_content, re.DOTALL)
            if m:
                local_config_block = m.group(0)

        # Strip snapshot's config block
        merged = re.sub(r'<!--\s*claude-sync-config\s*\n.*?-->\n?', '', snap_content, flags=re.DOTALL)

        # Append local config block if it exists
        if local_config_block:
            merged = merged.rstrip() + "\n\n" + local_config_block + "\n"

        if not dry_run:
            if os.path.exists(dst_file):
                backup = f"{dst_file}.bak.{ts()}"
                shutil.copy2(dst_file, backup)
            os.makedirs(os.path.dirname(dst_file), exist_ok=True)
            tmp = dst_file + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(merged)
            os.rename(tmp, dst_file)

        actions.append({
            "file": "CLAUDE.md", "action": "updated",
            "reason": "merged with local config block preserved" if local_config_block else "applied from snapshot"
        })

else:
    print(json.dumps({"error": f"unknown category: {category}"}), file=sys.stderr)
    sys.exit(1)

summary = {
    "updated": sum(1 for a in actions if a["action"] == "updated"),
    "created": sum(1 for a in actions if a["action"] == "created"),
    "merged": sum(1 for a in actions if a["action"] == "merged"),
    "skipped": sum(1 for a in actions if a["action"] == "skipped"),
    "errors": sum(1 for a in actions if a["action"] == "error"),
}

result = {
    "category": category,
    "dry_run": dry_run,
    "actions": actions,
    "summary": summary,
}

print(json.dumps(result, indent=2))
PYEOF
