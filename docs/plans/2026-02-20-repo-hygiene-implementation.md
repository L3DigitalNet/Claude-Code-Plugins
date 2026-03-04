# repo-hygiene Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `/hygiene` slash command plugin that runs five maintenance checks, auto-fixes safe items, and presents risky changes for approval — with `--dry-run` support.

**Architecture:** Command-only plugin (no MCP). A `commands/hygiene.md` orchestrates the sweep: runs four bash scripts in parallel for mechanical checks, performs README semantic analysis inline, then classifies all findings, applies auto-fixes, and multi-selects risky changes for approval.

**Tech Stack:** Bash (scripts), Markdown (command), Python 3 (JSON parsing inside scripts — avoids jq dependency)

---

## Task 1: Plugin scaffold

**Files:**
- Create: `plugins/repo-hygiene/.claude-plugin/plugin.json`
- Create: `plugins/repo-hygiene/commands/hygiene.md` (stub — full content in Task 6)
- Create: `plugins/repo-hygiene/scripts/` (empty dir via .gitkeep)
- Create: `plugins/repo-hygiene/CHANGELOG.md`
- Create: `plugins/repo-hygiene/README.md`

**Step 1: Create directory structure**

```bash
mkdir -p plugins/repo-hygiene/.claude-plugin
mkdir -p plugins/repo-hygiene/commands
mkdir -p plugins/repo-hygiene/scripts
```

**Step 2: Write plugin.json**

```json
{
  "name": "repo-hygiene",
  "version": "1.0.0",
  "description": "Autonomous maintenance sweep — validates .gitignore patterns, manifest paths, README freshness, plugin state consistency, and stale uncommitted changes.",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  }
}
```

Save to `plugins/repo-hygiene/.claude-plugin/plugin.json`.

**Step 3: Write CHANGELOG.md**

```markdown
# Changelog

## [1.0.0] - 2026-02-20

### Added
- `/hygiene` command with `--dry-run` flag
- Check 1: `.gitignore` stale pattern detection and missing-pattern suggestions
- Check 2: Marketplace manifest `source` path cross-reference
- Check 3: README `Known Issues` / `Principles` semantic staleness (inline AI)
- Check 4: Plugin state orphan detection (`installed_plugins.json` vs `settings.json` vs FS)
- Check 5: Uncommitted changes older than 24 hours
- Auto-fix for safe findings; `AskUserQuestion` multi-select for risky changes
```

**Step 4: Write README.md**

```markdown
# repo-hygiene

Autonomous maintenance sweep for the Claude-Code-Plugins monorepo.

## Usage

```
/hygiene [--dry-run]
```

Runs five checks and auto-fixes safe items. Risky changes are presented for approval.

## Checks

| # | Check | Auto-fixable |
|---|-------|-------------|
| 1 | `.gitignore` patterns (stale / missing) | Append missing patterns |
| 2 | Marketplace manifest `source` paths | Normalize trailing slashes |
| 3 | README `Known Issues` / `Principles` freshness | No (semantic judgment) |
| 4 | Plugin state orphans (installed_plugins.json, settings.json, cache) | No (destructive) |
| 5 | Uncommitted changes older than 24h | No (requires user intent) |

## `--dry-run`

Shows the full report with proposed `[would apply]` labels. No files are modified.
```

**Step 5: Create stub command file** (will be replaced in Task 6)

```markdown
---
description: Autonomous maintenance sweep — validates .gitignore, manifests, README freshness, plugin state, and stale commits.
---

# /hygiene [--dry-run]

> STUB — full implementation in Task 6
```

Save to `plugins/repo-hygiene/commands/hygiene.md`.

**Step 6: Verify directory structure**

```bash
find plugins/repo-hygiene -type f | sort
```

Expected output:
```
plugins/repo-hygiene/.claude-plugin/plugin.json
plugins/repo-hygiene/CHANGELOG.md
plugins/repo-hygiene/README.md
plugins/repo-hygiene/commands/hygiene.md
```

**Step 7: Commit**

```bash
git add plugins/repo-hygiene/
git commit -m "feat(repo-hygiene): scaffold plugin structure v1.0.0"
```

---

## Task 2: check-gitignore.sh

**Files:**
- Create: `plugins/repo-hygiene/scripts/check-gitignore.sh`

**Overview:** Finds all non-auto-generated `.gitignore` files in the repo. For each file:
- Checks if well-known patterns are present (per-plugin scope): `node_modules/` when `package.json` exists, `__pycache__/`/`*.pyc` when `*.py` files exist
- Checks for potentially stale patterns using `git ls-files -i`

Auto-fixable: append missing well-known patterns.
Needs-approval: patterns that appear to match nothing in the working tree.

**Step 1: Write check-gitignore.sh**

```bash
#!/usr/bin/env bash
# check-gitignore.sh — Check 1 of repo-hygiene sweep
#
# Scans all non-auto-generated .gitignore files. Emits JSON with:
#   - auto-fixable: well-known patterns missing for the file's context
#   - needs-approval: patterns that appear to match nothing in the working tree
#
# Called from commands/hygiene.md. Runs from repo root.
# Output: single JSON object on stdout. Non-zero exit + stderr on failure.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: not in a git repo" >&2
  exit 1
}
cd "$REPO_ROOT"

findings=()

# Helper: append a finding to the findings array (JSON fragment)
add_finding() {
  local severity="$1" path="$2" detail="$3" auto_fix="$4" fix_cmd="$5"
  # Escape for JSON
  local escaped_detail escaped_cmd
  escaped_detail=$(printf '%s' "$detail" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_cmd=$(printf '%s' "$fix_cmd" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  findings+=("{\"severity\":\"$severity\",\"path\":\"$path\",\"detail\":$escaped_detail,\"auto_fix\":$auto_fix,\"fix_cmd\":$escaped_cmd}")
}

# Find all .gitignore files, excluding auto-generated ones (e.g. pytest creates .pytest_cache/.gitignore)
while IFS= read -r gitignore; do
  # Skip auto-generated gitignores (single-pattern: just '*')
  content=$(cat "$gitignore")
  if [ "$(echo "$content" | grep -v '^#' | grep -v '^$' | tr -d ' \t')" = "*" ]; then
    continue
  fi

  rel_path="${gitignore#$REPO_ROOT/}"
  dir="$(dirname "$gitignore")"

  # --- Missing pattern checks ---

  # node_modules/ needed if package.json exists in same dir
  if [ -f "$dir/package.json" ]; then
    if ! grep -q '^node_modules' "$gitignore" 2>/dev/null; then
      add_finding "warn" "$rel_path" \
        "package.json present but 'node_modules/' not in .gitignore" \
        "true" "echo 'node_modules/' >> $rel_path"
    fi
  fi

  # __pycache__ / *.pyc needed if *.py files exist in same dir or subdirs
  if find "$dir" -maxdepth 3 -name '*.py' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q .; then
    if ! grep -qE '^__pycache__|^\*\.pyc|^\*\.py\[' "$gitignore" 2>/dev/null; then
      add_finding "warn" "$rel_path" \
        "Python files present but '__pycache__/' / '*.pyc' not in .gitignore" \
        "true" "printf '__pycache__/\n*.pyc\n' >> $rel_path"
    fi
  fi

  # .claude/state/ for any plugin dir that doesn't already have it covered by root
  if [[ "$rel_path" == plugins/* ]] && [[ "$rel_path" != ".gitignore" ]]; then
    if ! grep -qE '\.claude/state|\.claude/\*' "$gitignore" 2>/dev/null; then
      # Only flag if the root .gitignore doesn't cover it via **/.claude/state/
      root_gi="$REPO_ROOT/.gitignore"
      if ! grep -qE '\*\*/\.claude/state' "$root_gi" 2>/dev/null; then
        add_finding "info" "$rel_path" \
          "Plugin .gitignore does not explicitly exclude .claude/state/ (verify root .gitignore covers it)" \
          "false" "null"
      fi
    fi
  fi

  # --- Stale pattern checks ---
  # For each non-comment, non-empty, non-negation pattern: check if git ls-files -i matches anything
  while IFS= read -r pattern; do
    # Skip empty, comments, negations, and complex glob patterns with ** (hard to test reliably)
    [[ -z "$pattern" ]] && continue
    [[ "$pattern" == \#* ]] && continue
    [[ "$pattern" == \!* ]] && continue
    [[ "$pattern" == *\** ]] && continue  # skip globs for now — false positives likely

    # Check if this pattern matches any file under the directory
    matched=$(git -C "$dir" ls-files --others --ignored --exclude="$pattern" -- . 2>/dev/null | head -1)
    tracked_match=$(git -C "$dir" ls-files --cached -i --exclude="$pattern" -- . 2>/dev/null | head -1)

    if [ -z "$matched" ] && [ -z "$tracked_match" ]; then
      add_finding "info" "$rel_path" \
        "Pattern '$pattern' appears to match nothing in the working tree — may be stale" \
        "false" "null"
    fi
  done < <(grep -v '^#' "$gitignore" | grep -v '^$' | grep -v '^!')

done < <(find "$REPO_ROOT" -name '.gitignore' -not -path '*/.git/*' | sort)

# Build JSON output
printf '{"check":"gitignore","findings":['
first=1
for f in "${findings[@]}"; do
  [ "$first" -eq 1 ] && first=0 || printf ','
  printf '%s' "$f"
done
printf ']}\n'
```

**Step 2: Make executable and run a quick smoke test**

```bash
chmod +x plugins/repo-hygiene/scripts/check-gitignore.sh
bash plugins/repo-hygiene/scripts/check-gitignore.sh | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'check-gitignore: {len(d[\"findings\"])} findings')"
```

Expected: `check-gitignore: N findings` (N >= 0, no error)

**Step 3: Verify output is valid JSON**

```bash
bash plugins/repo-hygiene/scripts/check-gitignore.sh | python3 -m json.tool > /dev/null && echo "Valid JSON"
```

Expected: `Valid JSON`

**Step 4: Commit**

```bash
git add plugins/repo-hygiene/scripts/check-gitignore.sh
git commit -m "feat(repo-hygiene): add check-gitignore.sh"
```

---

## Task 3: check-manifests.sh

**Files:**
- Create: `plugins/repo-hygiene/scripts/check-manifests.sh`

**Overview:** Reads `.claude-plugin/marketplace.json` at repo root. For each plugin entry, verifies:
- `source` directory exists (`./plugins/<name>`)
- `source` directory contains `.claude-plugin/plugin.json`
- Version in marketplace entry matches version in plugin's `plugin.json`

Also reads `~/.claude/plugins/installed_plugins.json` and verifies each `installPath` exists on the filesystem.

Auto-fixable: trailing slash mismatches in source paths (normalize).
Needs-approval: path not found, version mismatch.

**Step 1: Write check-manifests.sh**

```bash
#!/usr/bin/env bash
# check-manifests.sh — Check 2 of repo-hygiene sweep
#
# Cross-references marketplace.json source paths against the filesystem,
# and installed_plugins.json installPath values against the FS cache.
#
# Called from commands/hygiene.md. Runs from repo root.
# Output: single JSON object on stdout. Non-zero exit + stderr on failure.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: not in a git repo" >&2
  exit 1
}
cd "$REPO_ROOT"

MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

[ -f "$MARKETPLACE" ] || { echo "ERROR: marketplace.json not found at $MARKETPLACE" >&2; exit 1; }

findings_json=$(python3 - <<'PYEOF'
import json, os, sys

repo_root = os.environ.get("REPO_ROOT", os.getcwd())
marketplace_path = os.path.join(repo_root, ".claude-plugin", "marketplace.json")
installed_path = os.path.expanduser("~/.claude/plugins/installed_plugins.json")

findings = []

# --- Check marketplace.json source paths ---
with open(marketplace_path) as f:
    marketplace = json.load(f)

for plugin in marketplace.get("plugins", []):
    name = plugin.get("name", "?")
    source = plugin.get("source", "")
    mp_version = plugin.get("version", None)

    if not source:
        findings.append({
            "severity": "warn", "path": ".claude-plugin/marketplace.json",
            "detail": f"Plugin '{name}' has no source field",
            "auto_fix": False, "fix_cmd": None
        })
        continue

    # Resolve relative source path
    resolved = os.path.normpath(os.path.join(repo_root, source))

    if not os.path.isdir(resolved):
        findings.append({
            "severity": "warn", "path": ".claude-plugin/marketplace.json",
            "detail": f"Plugin '{name}' source '{source}' directory not found at {resolved}",
            "auto_fix": False, "fix_cmd": None
        })
        continue

    # Check plugin.json exists in source dir
    plugin_json_path = os.path.join(resolved, ".claude-plugin", "plugin.json")
    if not os.path.isfile(plugin_json_path):
        findings.append({
            "severity": "warn", "path": f"{source}/.claude-plugin/plugin.json",
            "detail": f"Plugin '{name}' source dir exists but missing .claude-plugin/plugin.json",
            "auto_fix": False, "fix_cmd": None
        })
        continue

    # Check version consistency
    with open(plugin_json_path) as f:
        plugin_manifest = json.load(f)
    manifest_version = plugin_manifest.get("version", None)

    if mp_version and manifest_version and mp_version != manifest_version:
        findings.append({
            "severity": "warn",
            "path": ".claude-plugin/marketplace.json",
            "detail": f"Plugin '{name}' version mismatch: marketplace={mp_version}, plugin.json={manifest_version}",
            "auto_fix": False, "fix_cmd": None
        })

# --- Check installed_plugins.json installPath values ---
if os.path.isfile(installed_path):
    with open(installed_path) as f:
        installed = json.load(f)

    plugins_dict = installed.get("plugins", {})
    for plugin_key, install_list in plugins_dict.items():
        for entry in (install_list if isinstance(install_list, list) else [install_list]):
            install_path = entry.get("installPath", "")
            if install_path and not os.path.isdir(install_path):
                findings.append({
                    "severity": "warn",
                    "path": "~/.claude/plugins/installed_plugins.json",
                    "detail": f"Plugin '{plugin_key}' installPath not found on filesystem: {install_path}",
                    "auto_fix": False, "fix_cmd": None
                })

print(json.dumps({"check": "manifests", "findings": findings}))
PYEOF
)

printf '%s\n' "$findings_json"
```

**Step 2: Set REPO_ROOT env var pattern note**

The script uses `REPO_ROOT` as an env var — it's set via `set -a` in the calling context or via the subshell. The `$(git rev-parse --show-toplevel)` call sets the bash var; the Python heredoc needs it via `os.environ`. Fix this by exporting:

Replace the Python heredoc opener line with passing REPO_ROOT explicitly:

After `cd "$REPO_ROOT"`, add:
```bash
export REPO_ROOT
```

**Step 3: Make executable and verify**

```bash
chmod +x plugins/repo-hygiene/scripts/check-manifests.sh
bash plugins/repo-hygiene/scripts/check-manifests.sh | python3 -m json.tool > /dev/null && echo "Valid JSON"
bash plugins/repo-hygiene/scripts/check-manifests.sh | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'check-manifests: {len(d[\"findings\"])} findings')"
```

Expected: `Valid JSON` then `check-manifests: N findings`

**Step 4: Commit**

```bash
git add plugins/repo-hygiene/scripts/check-manifests.sh
git commit -m "feat(repo-hygiene): add check-manifests.sh"
```

---

## Task 4: check-orphans.sh

**Files:**
- Create: `plugins/repo-hygiene/scripts/check-orphans.sh`

**Overview:** Compares three plugin state sources. All findings are needs-approval (removal is destructive).

Sources:
- `~/.claude/plugins/installed_plugins.json` → `plugins` key → keys are `name@marketplace`
- `~/.claude/settings.json` → `enabledPlugins` key → keys are `name@marketplace`
- `~/.claude/plugins/cache/` → directories

Findings:
1. `installed_plugins.json` entry whose `installPath` dir doesn't exist
2. `settings.json` `enabledPlugins` key not present in `installed_plugins.json`
3. `installed_plugins.json` entry not present in `settings.json` `enabledPlugins`
4. `temp_*` directories in `~/.claude/plugins/cache/` (orphaned temp clones from plugin operations)

**Step 1: Write check-orphans.sh**

```bash
#!/usr/bin/env bash
# check-orphans.sh — Check 4 of repo-hygiene sweep
#
# Compares installed_plugins.json, settings.json enabledPlugins, and the
# plugin cache filesystem to surface orphaned or inconsistent plugin state.
#
# All findings are needs-approval — plugin state removal is always destructive.
# Called from commands/hygiene.md.
# Output: single JSON object on stdout. Non-zero exit + stderr on failure.

set -euo pipefail

INSTALLED="$HOME/.claude/plugins/installed_plugins.json"
SETTINGS="$HOME/.claude/settings.json"
CACHE_DIR="$HOME/.claude/plugins/cache"

[ -f "$INSTALLED" ] || { echo "ERROR: installed_plugins.json not found" >&2; exit 1; }
[ -f "$SETTINGS" ]  || { echo "ERROR: settings.json not found" >&2; exit 1; }

findings_json=$(python3 - "$INSTALLED" "$SETTINGS" "$CACHE_DIR" <<'PYEOF'
import json, os, sys

installed_path, settings_path, cache_dir = sys.argv[1], sys.argv[2], sys.argv[3]

with open(installed_path) as f:
    installed_data = json.load(f)
with open(settings_path) as f:
    settings_data = json.load(f)

installed_plugins = installed_data.get("plugins", {})   # {name@mp: [{installPath,...}]}
enabled_plugins   = settings_data.get("enabledPlugins", {})  # {name@mp: true}

findings = []

# Finding 1: installPath in installed_plugins.json doesn't exist on FS
for key, entries in installed_plugins.items():
    for entry in (entries if isinstance(entries, list) else [entries]):
        path = entry.get("installPath", "")
        if path and not os.path.isdir(path):
            findings.append({
                "severity": "warn",
                "path": "~/.claude/plugins/installed_plugins.json",
                "detail": f"'{key}' installPath missing on filesystem: {path}",
                "auto_fix": False, "fix_cmd": None
            })

# Finding 2: settings.json key not in installed_plugins.json
for key in enabled_plugins:
    if key not in installed_plugins:
        findings.append({
            "severity": "warn",
            "path": "~/.claude/settings.json",
            "detail": f"enabledPlugins has '{key}' but it's absent from installed_plugins.json (stale entry)",
            "auto_fix": False, "fix_cmd": None
        })

# Finding 3: installed_plugins.json key not in settings.json
for key in installed_plugins:
    if key not in enabled_plugins:
        findings.append({
            "severity": "info",
            "path": "~/.claude/plugins/installed_plugins.json",
            "detail": f"'{key}' is in installed_plugins.json but not in settings.json enabledPlugins",
            "auto_fix": False, "fix_cmd": None
        })

# Finding 4: temp_* directories in cache (orphaned temp clones)
if os.path.isdir(cache_dir):
    for entry in os.listdir(cache_dir):
        if entry.startswith("temp_"):
            full_path = os.path.join(cache_dir, entry)
            findings.append({
                "severity": "warn",
                "path": f"~/.claude/plugins/cache/{entry}",
                "detail": f"Orphaned temp directory in plugin cache: {full_path}",
                "auto_fix": False, "fix_cmd": None
            })

print(json.dumps({"check": "orphans", "findings": findings}))
PYEOF
)

printf '%s\n' "$findings_json"
```

**Step 2: Make executable and verify**

```bash
chmod +x plugins/repo-hygiene/scripts/check-orphans.sh
bash plugins/repo-hygiene/scripts/check-orphans.sh | python3 -m json.tool > /dev/null && echo "Valid JSON"
bash plugins/repo-hygiene/scripts/check-orphans.sh | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'check-orphans: {len(d[\"findings\"])} findings')"
```

Expected: At least 8+ findings (the `temp_*` directories in cache, possibly stale `context-efficiency-toolkit` entry).

**Step 3: Commit**

```bash
git add plugins/repo-hygiene/scripts/check-orphans.sh
git commit -m "feat(repo-hygiene): add check-orphans.sh"
```

---

## Task 5: check-stale-commits.sh

**Files:**
- Create: `plugins/repo-hygiene/scripts/check-stale-commits.sh`

**Overview:** Uses `git status --porcelain` to find modified/untracked files. For each, checks file mtime with `stat`. Files modified > 24 hours ago are flagged. All findings are needs-approval.

**Step 1: Write check-stale-commits.sh**

```bash
#!/usr/bin/env bash
# check-stale-commits.sh — Check 5 of repo-hygiene sweep
#
# Finds uncommitted changes (modified or untracked files) that were last
# modified more than 24 hours ago. These may represent forgotten work-in-progress.
#
# All findings are needs-approval — staging/committing requires user intent.
# Called from commands/hygiene.md. Runs from repo root.
# Output: single JSON object on stdout. Non-zero exit + stderr on failure.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: not in a git repo" >&2
  exit 1
}
cd "$REPO_ROOT"

CUTOFF=$(python3 -c "import time; print(int(time.time()) - 86400)")

findings_json=$(python3 - "$CUTOFF" <<'PYEOF'
import json, os, sys, subprocess, time

cutoff = int(sys.argv[1])
now = int(time.time())

# Get uncommitted file list from git status --porcelain
result = subprocess.run(
    ["git", "status", "--porcelain"],
    capture_output=True, text=True, check=True
)

findings = []
for line in result.stdout.splitlines():
    if not line.strip():
        continue
    # Format: XY filename  (where X=index status, Y=worktree status)
    status = line[:2].strip()
    filepath = line[3:].strip()

    # Handle renamed files: "old -> new" format
    if " -> " in filepath:
        filepath = filepath.split(" -> ")[-1]

    # Resolve relative to cwd
    abs_path = os.path.abspath(filepath)
    if not os.path.exists(abs_path):
        continue

    try:
        mtime = int(os.stat(abs_path).st_mtime)
    except OSError:
        continue

    if mtime < cutoff:
        age_hours = (now - mtime) // 3600
        age_days = age_hours // 24
        if age_days > 0:
            age_str = f"{age_days}d {age_hours % 24}h"
        else:
            age_str = f"{age_hours}h"

        findings.append({
            "severity": "warn",
            "path": filepath,
            "detail": f"Uncommitted {status.strip() or 'modified'} file, last changed {age_str} ago",
            "auto_fix": False,
            "fix_cmd": None
        })

print(json.dumps({"check": "stale-commits", "findings": findings}))
PYEOF
)

printf '%s\n' "$findings_json"
```

**Step 2: Make executable and verify**

```bash
chmod +x plugins/repo-hygiene/scripts/check-stale-commits.sh
bash plugins/repo-hygiene/scripts/check-stale-commits.sh | python3 -m json.tool > /dev/null && echo "Valid JSON"
bash plugins/repo-hygiene/scripts/check-stale-commits.sh | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'check-stale-commits: {len(d[\"findings\"])} findings'); [print(f'  {f[\"path\"]}: {f[\"detail\"]}') for f in d['findings']]"
```

The gitStatus at session start shows several M (modified) files — these should appear as findings (they exist from previous sessions).

**Step 3: Commit**

```bash
git add plugins/repo-hygiene/scripts/check-stale-commits.sh
git commit -m "feat(repo-hygiene): add check-stale-commits.sh"
```

---

## Task 6: commands/hygiene.md (main command)

**Files:**
- Modify: `plugins/repo-hygiene/commands/hygiene.md` (replace stub)

**Overview:** The orchestrating command. Parses `--dry-run`, runs four scripts in parallel, performs semantic README analysis inline (Check 3), classifies all findings, applies auto-fixes, presents needs-approval items.

**Step 1: Write the full commands/hygiene.md**

```markdown
---
description: Autonomous maintenance sweep — validates .gitignore patterns, manifest paths, README freshness, plugin state consistency, and stale uncommitted changes.
---

# /hygiene [--dry-run]

Autonomous maintenance sweep for the Claude-Code-Plugins monorepo. Runs five checks,
auto-fixes safe issues immediately (unless `--dry-run`), then presents risky changes
for explicit approval.

## Step 0: Setup

Parse the invocation for `--dry-run` flag. Store as `DRY_RUN=true|false`.

Resolve the plugin root:
```bash
echo $CLAUDE_PLUGIN_ROOT
```

Store as `PLUGIN_ROOT`.

## Step 1: Mechanical Scans (Run all four in parallel)

Run these four scripts and capture their JSON output. Execute them concurrently — they
are independent. Capture stdout from each; if any exits non-zero, surface the stderr
output as a critical failure and stop.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-gitignore.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-manifests.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-orphans.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-stale-commits.sh
```

Parse each output as JSON. Collect all findings arrays into a unified `all_findings` list,
tagging each finding with its `check` source.

## Step 2: Semantic Scan — README Freshness (Check 3)

For each plugin directory in `plugins/`:

**2a. Read the plugin's README.md.** If it has no README, skip.

**2b. Extract the `Known Issues` section** (look for `## Known Issues` or `### Known Issues`
heading). If present, for each bullet item, scan the plugin's scripts, hooks, and commands
for evidence it is still true. If the issue appears to have been resolved in code, add:
```json
{
  "check": "readme-freshness",
  "severity": "warn",
  "path": "plugins/<name>/README.md",
  "detail": "Known Issue '<issue text truncated to 80 chars>' may be stale — code suggests it is resolved",
  "auto_fix": false,
  "fix_cmd": null
}
```

**2c. Extract the `Principles` or `Design Principles` section.** For each principle listed,
check if it is still reflected in the implementation. Look for obvious contradictions only
(e.g., a principle claims "no external dependencies" but `package.json` has deps). If a
principle appears contradicted:
```json
{
  "check": "readme-freshness",
  "severity": "warn",
  "path": "plugins/<name>/README.md",
  "detail": "Principle '<text truncated>' appears contradicted by current codebase",
  "auto_fix": false,
  "fix_cmd": null
}
```

Add all findings to `all_findings`.

## Step 3: Classify Findings

Partition `all_findings` into two lists:
- `auto_fixable`: findings where `auto_fix == true` and `fix_cmd` is not null
- `needs_approval`: all others with `severity == "warn"` (skip `severity == "info"` from approval queue — surface as notes only)

Build a severity-sorted report using 🔴/🟡/🟢 prefixes:
- `warn` → 🔴
- `info` → 🟢

## Step 4: Apply Auto-fixes

**If DRY_RUN is true:** Display all auto-fixable findings with `[DRY RUN — would apply]` prefix.
Do not execute any `fix_cmd`. Continue to Step 5 but also mark needs-approval items as
`[DRY RUN — would present for approval]`.

**If DRY_RUN is false:** For each auto-fixable finding, execute its `fix_cmd` in a bash subshell:
```bash
bash -c "<fix_cmd>"
```
If any fix command fails, surface the error and continue — do not abort the sweep.

After applying, output:
```
✅ Auto-fixed N items:
  • plugins/foo/.gitignore — appended missing '__pycache__/' pattern
  ...
```

## Step 5: Present Needs-Approval Items

If there are no needs-approval findings, output:
```
✅ No risky changes found. Sweep complete.
```
and stop.

Otherwise, present all needs-approval items as a numbered list grouped by check:

```
⚠ N items need your approval:

[orphans]
  1. ~/.claude/plugins/cache/temp_git_1771507907007_vc32bo — orphaned temp directory
  2. ~/.claude/plugins/cache/temp_local_1771456754799_5hqfml — orphaned temp directory

[stale-commits]
  3. .claude-plugin/marketplace.json — uncommitted M file, last changed 2h ago

[readme-freshness]
  4. plugins/github-repo-manager/README.md — Known Issue 'X' may be stale

[gitignore]
  5. plugins/linux-sysadmin-mcp/.gitignore — Pattern 'build/' matches nothing
```

Use `AskUserQuestion` with multi-select to let the user choose which to apply:
- Options: each item numbered (up to 4 shown; if more than 4, offer "All", "None", "Other (specify numbers)")
- For orphaned temp directories, the "fix" is: "Delete `<path>`?" — surface the exact path
- For stale commits, the "fix" is: "Stage `<file>` for commit?"
- For README freshness findings, the "fix" is: "Open `<file>` for review?" (no code change — just flags for manual review)
- For stale gitignore patterns, the "fix" is: "Remove pattern `<pattern>` from `<file>`?"

**If more than 4 needs-approval items:** Group into: "All orphaned temp dirs (N)", "All stale commits (N)", "README findings (N)", "Other (N)". Multi-select to choose categories. Then apply.

## Step 6: Apply Approved Changes

For each approved item:
- **orphaned temp dir**: `rm -rf <path>` — confirm the path starts with `~/.claude/plugins/cache/temp_` before executing (safety guard)
- **stale commit file**: `git add <filepath>` — do NOT commit automatically; let user commit with their own message
- **README freshness**: Open the file in a Read and display the flagged section — no automated change
- **stale gitignore pattern**: Remove the specific line from the `.gitignore` file using Edit tool

## Step 7: Final Summary

Output a compact summary:
```
Hygiene sweep complete.
  Auto-fixed:   N items
  Approved:     N items
  Deferred:     N items
  Info notes:   N items
```

If DRY_RUN was active, prefix all counts with `[DRY RUN]`.
```

**Step 2: Verify the file was written correctly**

```bash
head -5 plugins/repo-hygiene/commands/hygiene.md
wc -l plugins/repo-hygiene/commands/hygiene.md
```

Expected: frontmatter present, ~160 lines.

**Step 3: Commit**

```bash
git add plugins/repo-hygiene/commands/hygiene.md
git commit -m "feat(repo-hygiene): add /hygiene command orchestrator"
```

---

## Task 7: Marketplace registration + validation

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Add repo-hygiene entry to marketplace.json**

Open `.claude-plugin/marketplace.json`. Append to the `plugins` array:

```json
{
  "name": "repo-hygiene",
  "description": "Autonomous maintenance sweep — validates .gitignore patterns, manifest paths, README freshness, plugin state consistency, and stale uncommitted changes.",
  "version": "1.0.0",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "source": "./plugins/repo-hygiene",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/repo-hygiene"
}
```

Note: `category` is NOT allowed in plugin entries (Zod strict mode rejects it — see CLAUDE.md gotchas).

**Step 2: Run marketplace validation**

```bash
bash scripts/validate-marketplace.sh
```

Expected: `✓ Marketplace validation passed` (or equivalent success message with no errors).

**Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(repo-hygiene): register in marketplace catalog"
```

---

## Task 8: End-to-end test against this repo

This is the acceptance test. Run the plugin against the actual Claude-Code-Plugins repo state.

**Step 1: Test all four scripts independently first**

```bash
bash plugins/repo-hygiene/scripts/check-gitignore.sh | python3 -m json.tool
bash plugins/repo-hygiene/scripts/check-manifests.sh | python3 -m json.tool
bash plugins/repo-hygiene/scripts/check-orphans.sh   | python3 -m json.tool
bash plugins/repo-hygiene/scripts/check-stale-commits.sh | python3 -m json.tool
```

Expected for each: valid JSON with `findings` array. For check-orphans, expect at minimum 8 findings (temp_* dirs). For check-stale-commits, expect findings matching the M files in gitStatus.

**Step 2: Run the full sweep via Claude Code**

```bash
claude --plugin-dir ./plugins/repo-hygiene
```

Then invoke `/hygiene --dry-run` and verify:
- Report appears with all five checks
- `[DRY RUN — would apply]` labels present
- No files modified

Then invoke `/hygiene` (without dry-run) and verify:
- Auto-fixable items are applied
- Needs-approval items appear in `AskUserQuestion` multi-select
- Final summary shows correct counts

**Step 3: Verify auto-fix idempotency**

Run `/hygiene` a second time. The auto-fixable items from the first run should no longer appear (already fixed). The needs-approval items still appear until the user acts on them.

**Step 4: Final commit**

```bash
git add -A
git status  # review before committing
git commit -m "test(repo-hygiene): verify end-to-end sweep against monorepo"
```

---

## Summary

| Task | Component | Action |
|------|-----------|--------|
| 1 | Plugin scaffold | Create dirs, plugin.json, CHANGELOG, README |
| 2 | check-gitignore.sh | Missing/stale .gitignore patterns |
| 3 | check-manifests.sh | Source path + installPath cross-reference |
| 4 | check-orphans.sh | installed_plugins.json vs settings.json vs FS |
| 5 | check-stale-commits.sh | Uncommitted changes >24h |
| 6 | commands/hygiene.md | Orchestrating command |
| 7 | marketplace.json | Register plugin |
| 8 | End-to-end test | Run against this repo, verify findings |
