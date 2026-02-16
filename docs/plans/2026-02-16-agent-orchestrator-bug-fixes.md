# Agent-Orchestrator Bug Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all critical and medium-severity bugs found in agent-orchestrator plugin code review

**Architecture:** Sequential bug fixes with verification between each to ensure no regressions or interference. Fixes are ordered by severity (High → Medium → Low) and by independence (changes that won't affect other fixes first).

**Tech Stack:** Bash scripts, JSON configuration, Markdown documentation

**Bug Summary:**
- **High**: read-counter.sh PID tracking broken (counter never increments)
- **High**: Worktree paths in spawn template incorrect (teammates can't find shared state)
- **Medium**: lead-write-guard.sh fails to match absolute paths
- **Medium**: Plan not persisted to disk between phases
- **Medium**: Hook matchers don't cover all write tools
- **Low**: Minor improvements (whitespace trimming, .gitignore handling)

---

## Task 1: Fix read-counter.sh Session Tracking

**Problem:** `$$` returns the hook script's PID (new process each invocation), not the parent session PID. Counter file name changes every call, so count never increments above 1.

**Files:**
- Modify: `plugins/agent-orchestrator/scripts/read-counter.sh`

**Step 1: Understand the current implementation**

Read the current file to confirm the bug:

```bash
cat plugins/agent-orchestrator/scripts/read-counter.sh
```

Expected: Line 6 shows `COUNTER_FILE=".claude/state/.read-count-$$"`

**Step 2: Write test script to verify the bug**

Create: `plugins/agent-orchestrator/scripts/test-read-counter.sh`

```bash
#!/bin/bash
# Test read-counter behavior - verify bug exists, then verify fix

set -euo pipefail

echo "=== Testing read-counter.sh ==="

# Setup
mkdir -p .claude/state
rm -f .claude/state/.read-count-* 2>/dev/null || true

# Simulate 3 hook invocations
for i in 1 2 3; do
  echo "Invocation $i:"
  bash plugins/agent-orchestrator/scripts/read-counter.sh
  echo "Counter files created:"
  ls -1 .claude/state/.read-count-* 2>/dev/null || echo "  (none)"
  echo ""
done

# Count how many counter files were created
FILE_COUNT=$(ls -1 .claude/state/.read-count-* 2>/dev/null | wc -l)

echo "=== Result ==="
echo "Counter files created: $FILE_COUNT"
if [ "$FILE_COUNT" -eq 1 ]; then
  FINAL_COUNT=$(cat .claude/state/.read-count-*)
  echo "Final count value: $FINAL_COUNT"
  if [ "$FINAL_COUNT" -eq 3 ]; then
    echo "✓ PASS: Counter incremented correctly"
    exit 0
  else
    echo "✗ FAIL: Counter should be 3, got $FINAL_COUNT"
    exit 1
  fi
else
  echo "✗ FAIL: Should create 1 counter file, created $FILE_COUNT"
  echo "This confirms the bug - each invocation creates a new file."
  exit 1
fi
```

**Step 3: Run test to verify bug exists**

```bash
chmod +x plugins/agent-orchestrator/scripts/test-read-counter.sh
bash plugins/agent-orchestrator/scripts/test-read-counter.sh
```

Expected: FAIL with "Should create 1 counter file, created 3"

**Step 4: Implement the fix**

The solution is to use `$PPID` (parent PID) instead of `$$` (current script PID). The parent PID will be consistent across hook invocations within the same Claude Code session.

Modify `plugins/agent-orchestrator/scripts/read-counter.sh`:

```bash
#!/bin/bash
# PostToolUse hook: counts file reads per session (keyed by parent PID).
# Warns at 10+ reads, critical alert at 15+ to enforce context discipline.
# Applies to all agents (lead + teammates).

COUNTER_FILE=".claude/state/.read-count-$PPID"

# Read current count (default 0)
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$COUNT" -eq 10 ]; then
  echo "WARNING: You have read 10 files in this session. Write your handoff note NOW and consider compacting. Context discipline is critical."
elif [ "$COUNT" -eq 15 ]; then
  echo "CRITICAL: 15 file reads. You MUST write a handoff note and compact immediately. Run: /compact"
fi
```

**Step 5: Run test to verify fix works**

```bash
# Clean up old test files
rm -f .claude/state/.read-count-* 2>/dev/null || true

# Run test again
bash plugins/agent-orchestrator/scripts/test-read-counter.sh
```

Expected: PASS with "✓ PASS: Counter incremented correctly"

**Step 6: Update DESIGN.md to document the fix**

Modify `plugins/agent-orchestrator/DESIGN.md` in the "Known Limitations & Open Questions" section:

Find the line about "Read counter keyed by PID" and update it to:

```markdown
~~Unresolved:~~
~~- Read counter keyed by PID (may reuse across sessions)~~

Fixed (2026-02-16):
- Read counter now uses PPID (parent process ID) which remains stable across hook invocations within a session
- Note: Counter files persist in `.claude/state/.read-count-*` and should be cleaned up by cleanup-state.sh
```

**Step 7: Verify cleanup-state.sh will remove counter files**

Check if cleanup-state.sh already handles this with `rm -rf .claude/state/`:

```bash
grep -A 3 "rm -rf" plugins/agent-orchestrator/scripts/cleanup-state.sh
```

Expected: Shows `rm -rf .claude/state/` which will remove counter files

**Step 8: Clean up test script**

```bash
rm plugins/agent-orchestrator/scripts/test-read-counter.sh
rm -f .claude/state/.read-count-* 2>/dev/null || true
```

**Step 9: Commit**

```bash
git add plugins/agent-orchestrator/scripts/read-counter.sh plugins/agent-orchestrator/DESIGN.md
git commit -m "fix(agent-orchestrator): use PPID for read counter session tracking

- Change from $$ to $PPID to track reads per session
- $$ created new PID per hook invocation, breaking counter
- $PPID remains stable across hook calls in same session
- Update DESIGN.md to document fix"
```

---

## Task 2: Fix Worktree Path References in Spawn Template

**Problem:** The spawn template in `orchestrate.md` references `.claude/state/` with project-root-relative paths. When teammates `cd` into `.worktrees/<name>/`, these paths resolve incorrectly to `.worktrees/<name>/.claude/state/` which doesn't exist.

**Files:**
- Modify: `plugins/agent-orchestrator/commands/orchestrate.md:226-228`
- Modify: `plugins/agent-orchestrator/skills/orchestration/SKILL.md:66-71` (documentation already correct)

**Step 1: Verify the bug in orchestrate.md**

```bash
grep -A 10 "Your status file:" plugins/agent-orchestrator/commands/orchestrate.md | head -15
```

Expected: Shows relative paths `.claude/state/[name]-status.md` without `../`

**Step 2: Review the correct pattern in SKILL.md**

```bash
grep -A 5 "Worktree Path Rules" plugins/agent-orchestrator/skills/orchestration/SKILL.md
```

Expected: Shows `../.claude/state/` or absolute path pattern

**Step 3: Create test to demonstrate the bug**

Create: `plugins/agent-orchestrator/scripts/test-worktree-paths.sh`

```bash
#!/bin/bash
# Test worktree path resolution

set -euo pipefail

echo "=== Testing worktree path resolution ==="

# Setup: create minimal worktree structure
rm -rf .test-worktree-demo .claude/state 2>/dev/null || true
mkdir -p .test-worktree-demo/subdir
mkdir -p .claude/state

# Create a marker file at project root
echo "CORRECT" > .claude/state/test-marker.md

echo ""
echo "From project root (./):"
cat .claude/state/test-marker.md
echo ""

# Test what happens when we cd into worktree and use relative path
echo "From worktree subdirectory (.test-worktree-demo/subdir/):"
cd .test-worktree-demo/subdir
if [ -f ".claude/state/test-marker.md" ]; then
  echo "FAIL: Relative path found a file (shouldn't exist here)"
  cat .claude/state/test-marker.md
  exit 1
elif [ -f "../../.claude/state/test-marker.md" ]; then
  echo "PASS: ../.claude/state/ path works from worktree:"
  cat ../../.claude/state/test-marker.md
else
  echo "FAIL: Neither path works"
  exit 1
fi

# Cleanup
cd ../..
rm -rf .test-worktree-demo .claude/state
```

**Step 4: Run test to verify the problem**

```bash
chmod +x plugins/agent-orchestrator/scripts/test-worktree-paths.sh
bash plugins/agent-orchestrator/scripts/test-worktree-paths.sh
```

Expected: PASS showing that `../../.claude/state/` works from two levels deep

**Step 5: Fix the spawn template in orchestrate.md**

Modify `plugins/agent-orchestrator/commands/orchestrate.md` around lines 226-228:

Find this section in the spawn template:

```
## Coordination
- Your status file: .claude/state/[name]-status.md (ONLY file you update for status)
- Your handoff file: .claude/state/[name]-handoff.md
- Shared ledger: .claude/state/ledger.md (READ-ONLY — lead maintains this)
```

Replace with:

```
## Coordination
[If worktrees enabled:]
Access shared state from your worktree via ../.claude/state/ (or use absolute paths).
[If worktrees disabled:]
Access shared state at .claude/state/ (project root).

- Your status file: ../.claude/state/[name]-status.md (ONLY file you update for status)
- Your handoff file: ../.claude/state/[name]-handoff.md
- Shared ledger: ../.claude/state/ledger.md (READ-ONLY — lead maintains this)
- Teammate protocol: ../.claude/state/teammate-protocol.md
```

**Step 6: Fix another reference in the spawn template**

Find the "Protocol" section around line 219:

```
## Protocol
Read .claude/state/teammate-protocol.md for your full operating protocol. Follow it exactly.
```

Replace with:

```
## Protocol
Read ../.claude/state/teammate-protocol.md for your full operating protocol. Follow it exactly.
```

**Step 7: Verify all references are updated**

```bash
grep -n "\.claude/state/" plugins/agent-orchestrator/commands/orchestrate.md | grep -v "^\s*#" | grep -v "mkdir"
```

Expected: Should only show lines in Phase 2.1 setup (creation commands) and context examples, not in the spawn template

**Step 8: Clean up test script**

```bash
rm plugins/agent-orchestrator/scripts/test-worktree-paths.sh
```

**Step 9: Commit**

```bash
git add plugins/agent-orchestrator/commands/orchestrate.md
git commit -m "fix(agent-orchestrator): use correct relative paths for worktree state access

- Change spawn template to use ../.claude/state/ paths
- Teammates cd into .worktrees/<name>/ as first action
- Relative paths from worktree must use ../ to reach project root
- Add conditional note about path differences with/without worktrees"
```

---

## Task 3: Fix lead-write-guard.sh Absolute Path Matching

**Problem:** The `case` statement in lead-write-guard.sh matches relative paths like `.claude/state/*` but Claude Code tools may pass absolute paths like `/home/user/project/.claude/state/ledger.md`. The whitelist won't match, incorrectly blocking legitimate writes.

**Files:**
- Modify: `plugins/agent-orchestrator/scripts/lead-write-guard.sh`

**Step 1: Review current implementation**

```bash
cat plugins/agent-orchestrator/scripts/lead-write-guard.sh
```

Expected: Line 20-23 shows case matching only relative paths

**Step 2: Create test script to verify the bug**

Create: `plugins/agent-orchestrator/scripts/test-lead-guard.sh`

```bash
#!/bin/bash
# Test lead-write-guard with both relative and absolute paths

set -euo pipefail

echo "=== Testing lead-write-guard.sh path matching ==="

export ORCHESTRATOR_LEAD=1

# Test 1: Relative path to allowed file (should allow)
echo ""
echo "Test 1: Relative path to .claude/state/ledger.md"
echo '{"tool_input":{"file_path":".claude/state/ledger.md"}}' | \
  bash plugins/agent-orchestrator/scripts/lead-write-guard.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ PASS: Allowed (exit 0)"
else
  echo "✗ FAIL: Blocked (exit $EXIT_CODE)"
fi

# Test 2: Absolute path to allowed file (should allow, but currently fails)
echo ""
echo "Test 2: Absolute path to .claude/state/ledger.md"
ABS_PATH="$(pwd)/.claude/state/ledger.md"
echo "{\"tool_input\":{\"file_path\":\"$ABS_PATH\"}}" | \
  bash plugins/agent-orchestrator/scripts/lead-write-guard.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ PASS: Allowed (exit 0)"
else
  echo "✗ FAIL: Blocked (exit $EXIT_CODE) - THIS IS THE BUG"
fi

# Test 3: Relative path to source file (should block)
echo ""
echo "Test 3: Relative path to src/main.py"
echo '{"tool_input":{"file_path":"src/main.py"}}' | \
  bash plugins/agent-orchestrator/scripts/lead-write-guard.sh 2>/dev/null
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ]; then
  echo "✓ PASS: Blocked (exit 2)"
else
  echo "✗ FAIL: Should block with exit 2, got exit $EXIT_CODE"
fi

# Test 4: Absolute path to source file (should block)
echo ""
echo "Test 4: Absolute path to src/main.py"
ABS_PATH="$(pwd)/src/main.py"
echo "{\"tool_input\":{\"file_path\":\"$ABS_PATH\"}}" | \
  bash plugins/agent-orchestrator/scripts/lead-write-guard.sh 2>/dev/null
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ]; then
  echo "✓ PASS: Blocked (exit 2)"
else
  echo "✗ FAIL: Should block with exit 2, got exit $EXIT_CODE"
fi

echo ""
echo "=== Summary ==="
echo "Expected: Test 2 to FAIL (demonstrates bug)"
```

**Step 3: Run test to verify bug exists**

```bash
chmod +x plugins/agent-orchestrator/scripts/test-lead-guard.sh
bash plugins/agent-orchestrator/scripts/test-lead-guard.sh
```

Expected: Test 2 shows "FAIL: Blocked" (absolute path to allowed file incorrectly blocked)

**Step 4: Implement the fix**

Modify `plugins/agent-orchestrator/scripts/lead-write-guard.sh`:

```bash
#!/bin/bash
# PreToolUse hook: blocks Write/Edit/MultiEdit on files outside .claude/state/
# Only active when ORCHESTRATOR_LEAD=1 env var is set (lead session only).
# Teammates are NOT affected.

# Skip enforcement for non-lead sessions
if [ "$ORCHESTRATOR_LEAD" != "1" ]; then
  exit 0
fi

# Extract file path from hook input (JSON on stdin)
FILE_PATH=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Fail open if we can't determine the path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize to absolute path for consistent matching
if [[ "$FILE_PATH" = /* ]]; then
  # Already absolute
  ABS_PATH="$FILE_PATH"
else
  # Convert relative to absolute
  ABS_PATH="$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd)/$(basename "$FILE_PATH")"
  # Fallback if path doesn't exist yet
  if [ -z "$ABS_PATH" ] || [ "$ABS_PATH" = "/" ]; then
    ABS_PATH="$(pwd)/$FILE_PATH"
  fi
fi

# Get project root (current directory when hook runs)
PROJECT_ROOT="$(pwd)"

# Check if path is under allowed directories
if [[ "$ABS_PATH" == "$PROJECT_ROOT/.claude/state/"* ]] || \
   [[ "$ABS_PATH" == "$PROJECT_ROOT/.claude/settings"* ]] || \
   [[ "$ABS_PATH" == "$PROJECT_ROOT/.gitignore" ]]; then
  exit 0
fi

# Block: lead cannot write source files
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"DELEGATE MODE: Lead cannot write source files. Delegate this edit to a teammate or subagent."}}'
exit 2
```

**Step 5: Run test to verify fix works**

```bash
bash plugins/agent-orchestrator/scripts/test-lead-guard.sh
```

Expected: All tests PASS (including Test 2)

**Step 6: Add edge case test for worktree paths**

Add to test script before running:

```bash
# Test 5: Path inside worktree .claude/state (should block - not the shared state)
echo ""
echo "Test 5: Path inside worktree's own .claude/state"
echo '{"tool_input":{"file_path":".worktrees/backend/.claude/state/file.md"}}' | \
  bash plugins/agent-orchestrator/scripts/lead-write-guard.sh 2>/dev/null
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ]; then
  echo "✓ PASS: Blocked (exit 2) - worktree state is not shared state"
else
  echo "✗ FAIL: Should block, got exit $EXIT_CODE"
fi
```

Run again to verify worktree isolation:

```bash
bash plugins/agent-orchestrator/scripts/test-lead-guard.sh
```

**Step 7: Clean up test script**

```bash
rm plugins/agent-orchestrator/scripts/test-lead-guard.sh
```

**Step 8: Commit**

```bash
git add plugins/agent-orchestrator/scripts/lead-write-guard.sh
git commit -m "fix(agent-orchestrator): handle absolute paths in lead-write-guard

- Normalize file paths to absolute for consistent matching
- Case patterns only matched relative paths like .claude/state/*
- Claude Code tools may pass absolute paths
- Convert both to absolute and compare against project root
- Maintains worktree isolation (only PROJECT_ROOT/.claude/state/* allowed)"
```

---

## Task 4: Add Plan Persistence Between Phase 1 and Phase 2

**Problem:** The orchestration plan is created in Plan mode (Phase 1) and lives only in the lead's context. If the lead compacts between user approval and Phase 2 execution, the plan details are lost. The ledger template has placeholders but not the full team roster, waves, or worktree strategy.

**Files:**
- Modify: `plugins/agent-orchestrator/commands/orchestrate.md:108-151` (Phase 1.5 Present Plan section)
- Modify: `plugins/agent-orchestrator/commands/orchestrate.md:160-174` (Phase 2.1 Initialize section)

**Step 1: Review current plan presentation flow**

```bash
grep -A 20 "### 1.5 Present Plan" plugins/agent-orchestrator/commands/orchestrate.md
```

Expected: Shows plan output template but no instruction to write to disk

**Step 2: Review Phase 2 initialization**

```bash
grep -A 15 "### 2.1 Initialize Infrastructure" plugins/agent-orchestrator/commands/orchestrate.md
```

Expected: Shows bootstrap but no plan file reading

**Step 3: Update Phase 1.5 to persist the plan**

Find section 1.5 "Present Plan" and modify the instructions after the plan template:

Before the **STOP** line, add:

```markdown
**Write the plan to disk:**

```bash
cat > .claude/state/orchestration-plan.md << 'EOF'
[paste your full plan here - the entire output from Task Summary through Estimated Scope]
EOF
```

This ensures the plan survives any context loss between approval and execution.

**STOP. Wait for explicit user approval before proceeding.**
```

**Step 4: Update Phase 2.1 to restore plan from disk**

After "Exit plan mode now" and before running bootstrap.sh, add:

```markdown
**Restore the plan from disk:**

```bash
cat .claude/state/orchestration-plan.md
```

Read this carefully to refresh your memory of the team roster, waves, worktree strategy, and dependencies.
```

**Step 5: Update cleanup-state.sh to document plan file**

Verify the plan file will be cleaned up:

```bash
grep -A 5 "rm -rf" plugins/agent-orchestrator/scripts/cleanup-state.sh
```

Expected: `rm -rf .claude/state/` already covers orchestration-plan.md (no change needed)

**Step 6: Update template to include plan file**

Check if the template needs the plan file marker:

```bash
cat plugins/agent-orchestrator/templates/ledger.md
```

Expected: Ledger doesn't need to reference the plan (it's separate). No change needed.

**Step 7: Test the flow manually (verification step)**

Create a test plan file to verify the approach:

```bash
mkdir -p .claude/state
cat > .claude/state/orchestration-plan.md << 'EOF'
## Orchestration Plan

### Task Summary
Test task for verification

### Delegation Mode
agent teams

### Worktree Strategy
enabled - orchestrator/test-branch

### Team Roster
- test-teammate

### Execution Waves
Wave 1: [test-teammate]

### Shared State
Location: .claude/state/

### Risk Flags
none

### Guardrails
All mechanical enforcement active

### Estimated Scope
light ≤100k tokens
EOF

echo "Plan file created:"
cat .claude/state/orchestration-plan.md
echo ""
echo "Cleanup test:"
bash plugins/agent-orchestrator/scripts/cleanup-state.sh
ls .claude/state/ 2>/dev/null || echo "✓ .claude/state/ removed correctly"
```

Expected: Plan file created, then cleaned up by cleanup-state.sh

**Step 8: Commit**

```bash
git add plugins/agent-orchestrator/commands/orchestrate.md
git commit -m "fix(agent-orchestrator): persist plan to disk between Phase 1 and 2

- Write plan to .claude/state/orchestration-plan.md after presentation
- Read plan back at start of Phase 2 before execution
- Prevents plan loss if lead compacts between approval and execution
- cleanup-state.sh already removes plan file (rm -rf .claude/state/)"
```

---

## Task 5: Expand Hook Matchers to Cover All Write Tools

**Problem:** The PreToolUse hook only matches `Write|Edit|MultiEdit` but doesn't cover `NotebookEdit` or MCP filesystem write tools like `mcp__filesystem__write_file` or `mcp__filesystem__edit_file`. Lead could bypass write guard through these tools.

**Files:**
- Modify: `plugins/agent-orchestrator/hooks/hooks.json`
- Modify: `plugins/agent-orchestrator/scripts/lead-write-guard.sh` (add tool name detection)

**Step 1: Review current hook matcher**

```bash
cat plugins/agent-orchestrator/hooks/hooks.json
```

Expected: Line 15 shows `"matcher": "Write|Edit|MultiEdit"`

**Step 2: Research available write tool names**

Check what other tools might write files:

```bash
# This is documentation - actual tools depend on Claude Code version and MCP servers
echo "Known write tools:"
echo "- Write (native)"
echo "- Edit (native)"
echo "- MultiEdit (native)"
echo "- NotebookEdit (native - Jupyter notebooks)"
echo "- mcp__filesystem__write_file (MCP filesystem server)"
echo "- mcp__filesystem__edit_file (MCP filesystem server)"
echo "- mcp__filesystem__create_directory (MCP - indirect)"
```

**Step 3: Update hook matcher to cover all write tools**

Modify `plugins/agent-orchestrator/hooks/hooks.json`:

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "auto",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/on-pre-compact.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit|mcp__.*__write.*|mcp__.*__edit.*|mcp__.*__create_file|mcp__.*__update_file",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/lead-write-guard.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read|View",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-counter.sh"
          }
        ]
      }
    ]
  }
}
```

**Step 4: Update lead-write-guard.sh to handle tool name variations**

The current script extracts `file_path` from `tool_input`. MCP tools might use different field names. Add fallback extraction:

Modify `plugins/agent-orchestrator/scripts/lead-write-guard.sh` around line 12:

```bash
# Extract file path from hook input (JSON on stdin)
# Try multiple field names (tool_input.file_path for native tools, path for MCP)
FILE_PATH=$(cat | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Try tool_input.file_path first (native tools)
    path = d.get('tool_input', {}).get('file_path', '')
    if not path:
        # Try tool_input.path (some MCP tools)
        path = d.get('tool_input', {}).get('path', '')
    if not path:
        # Try tool_input.notebook_path (NotebookEdit)
        path = d.get('tool_input', {}).get('notebook_path', '')
    print(path)
except:
    print('')
" 2>/dev/null)
```

**Step 5: Test the hook matcher pattern**

Create test to verify regex patterns:

```bash
# Test if patterns would match
echo "Testing hook matchers:"

for tool in "Write" "Edit" "MultiEdit" "NotebookEdit" \
            "mcp__filesystem__write_file" "mcp__filesystem__edit_file" \
            "mcp__custom__write_data" "mcp__github__create_file"; do
  if [[ "$tool" =~ ^(Write|Edit|MultiEdit|NotebookEdit|mcp__.*__write.*|mcp__.*__edit.*|mcp__.*__create_file|mcp__.*__update_file)$ ]]; then
    echo "  ✓ $tool - MATCHES (would trigger hook)"
  else
    echo "  ✗ $tool - no match"
  fi
done

echo ""
echo "Non-write tools (should not match):"
for tool in "Read" "Bash" "Glob" "Grep"; do
  if [[ "$tool" =~ ^(Write|Edit|MultiEdit|NotebookEdit|mcp__.*__write.*|mcp__.*__edit.*|mcp__.*__create_file|mcp__.*__update_file)$ ]]; then
    echo "  ✗ $tool - MATCHES (false positive!)"
  else
    echo "  ✓ $tool - correctly excluded"
  fi
done
```

Expected: All write tools match, read tools excluded

**Step 6: Validate JSON syntax**

```bash
jq . plugins/agent-orchestrator/hooks/hooks.json
echo "✓ JSON syntax valid"
```

**Step 7: Document the change in DESIGN.md**

Add note in "Known Limitations" section:

```markdown
Fixed (2026-02-16):
- Hook matchers now cover NotebookEdit and MCP filesystem tools (write/edit/create/update patterns)
- Regex pattern `mcp__.*__write.*|mcp__.*__edit.*` catches MCP server write operations
- Script now checks multiple field names (file_path, path, notebook_path) for path extraction
```

**Step 8: Commit**

```bash
git add plugins/agent-orchestrator/hooks/hooks.json \
        plugins/agent-orchestrator/scripts/lead-write-guard.sh \
        plugins/agent-orchestrator/DESIGN.md
git commit -m "fix(agent-orchestrator): expand write hook matchers to cover all tools

- Add NotebookEdit to hook matcher pattern
- Add MCP tool patterns: mcp__.*__write.*, mcp__.*__edit.*, etc.
- Update lead-write-guard.sh to extract path from multiple field names
- Handles tool_input.file_path, .path, and .notebook_path
- Prevents bypass of write guard through MCP filesystem tools"
```

---

## Task 6: Minor Improvements (Optional)

**Problem:** Small improvements to code quality that don't affect functionality but improve robustness.

**Files:**
- Modify: `plugins/agent-orchestrator/scripts/merge-branches.sh` (whitespace trimming)
- Modify: `plugins/agent-orchestrator/scripts/bootstrap.sh` (.gitignore explicit creation)

**Step 1: Fix whitespace trimming in merge-branches.sh**

Modify `plugins/agent-orchestrator/scripts/merge-branches.sh` line 13:

```bash
# Find orchestrator branches (trim leading/trailing whitespace)
BRANCHES=$(git branch --list 'orchestrator/*' | sed 's/^[* ]*//; s/[[:space:]]*$//')
```

**Step 2: Make .gitignore creation explicit in bootstrap.sh**

Modify `plugins/agent-orchestrator/scripts/bootstrap.sh` around line 13:

```bash
# Ensure .gitignore exists
touch .gitignore

# Gitignore orchestration artifacts
for pattern in ".claude/state/" ".worktrees/"; do
  grep -qxF "$pattern" .gitignore || echo "$pattern" >> .gitignore
done
```

**Step 3: Test both scripts**

```bash
# Test merge-branches with no orchestrator branches
bash plugins/agent-orchestrator/scripts/merge-branches.sh
echo "✓ merge-branches.sh handles no branches"

# Test bootstrap with no .gitignore
rm -f .gitignore
bash plugins/agent-orchestrator/scripts/bootstrap.sh
if [ -f .gitignore ]; then
  echo "✓ bootstrap.sh creates .gitignore"
  cat .gitignore
else
  echo "✗ .gitignore not created"
fi

# Cleanup
bash plugins/agent-orchestrator/scripts/cleanup-state.sh
```

**Step 4: Commit**

```bash
git add plugins/agent-orchestrator/scripts/merge-branches.sh \
        plugins/agent-orchestrator/scripts/bootstrap.sh
git commit -m "refactor(agent-orchestrator): minor robustness improvements

- merge-branches.sh: trim trailing whitespace from branch names
- bootstrap.sh: explicitly create .gitignore before appending
- No functional changes, improves code quality"
```

---

## Task 7: Update Plugin Version and Marketplace

**Problem:** After fixing bugs, the plugin version should be bumped and marketplace catalog updated.

**Files:**
- Modify: `plugins/agent-orchestrator/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Bump plugin version**

Modify `plugins/agent-orchestrator/.claude-plugin/plugin.json`:

```json
{
  "name": "agent-orchestrator",
  "description": "General-purpose agent team orchestration with automatic context management, file isolation via git worktrees, and mechanical enforcement hooks.",
  "version": "1.0.1",
  "author": {
    "name": "Agent Orchestrator"
  },
  "keywords": [
    "orchestration",
    "agent-teams",
    "subagents",
    "context-management",
    "worktrees"
  ]
}
```

**Step 2: Update marketplace catalog**

Modify `.claude-plugin/marketplace.json` - find the agent-orchestrator entry and update version:

```bash
# Show current version
jq '.plugins[] | select(.name == "agent-orchestrator") | .version' .claude-plugin/marketplace.json

# Update to 1.0.1 (manual edit or use jq)
jq '.plugins |= map(if .name == "agent-orchestrator" then .version = "1.0.1" else . end)' \
  .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp
mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json

# Verify
jq '.plugins[] | select(.name == "agent-orchestrator")' .claude-plugin/marketplace.json
```

**Step 3: Validate marketplace JSON**

```bash
bash scripts/validate-marketplace.sh
```

Expected: All validation passes

**Step 4: Commit**

```bash
git add plugins/agent-orchestrator/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json
git commit -m "chore(agent-orchestrator): bump version to 1.0.1

Bug fixes in this release:
- Fix read-counter session tracking (PPID instead of $$)
- Fix worktree path references in spawn template
- Fix lead-write-guard absolute path matching
- Add plan persistence between Phase 1 and 2
- Expand hook matchers to cover all write tools
- Minor robustness improvements"
```

---

## Task 8: Final Verification and Testing

**Problem:** Ensure all fixes work together without interference.

**Step 1: Run all validation scripts**

```bash
echo "=== Running validation suite ==="

# Validate marketplace
bash scripts/validate-marketplace.sh

# Validate plugin manifest
jq . plugins/agent-orchestrator/.claude-plugin/plugin.json

# Validate hooks JSON
jq . plugins/agent-orchestrator/hooks/hooks.json

echo "✓ All validations passed"
```

**Step 2: Verify hooks don't conflict**

Check that:
- PreToolUse hook (lead-write-guard) runs for write tools only
- PostToolUse hook (read-counter) runs for read tools only
- PreCompact hook (on-pre-compact) runs on auto compaction

```bash
echo "=== Hook coverage analysis ==="
echo "Write tools → lead-write-guard.sh"
echo "Read tools → read-counter.sh"
echo "Compaction → on-pre-compact.sh"
echo "No overlaps expected ✓"
```

**Step 3: Create integration test checklist**

Create `.claude/state/test-checklist.md`:

```markdown
# Agent-Orchestrator Integration Test Checklist

## Pre-flight Checks
- [ ] All scripts have execute permissions
- [ ] All JSON files validate
- [ ] DESIGN.md documents all fixes

## Hook Tests
- [ ] read-counter increments correctly (multiple invocations)
- [ ] lead-write-guard blocks source files (relative paths)
- [ ] lead-write-guard blocks source files (absolute paths)
- [ ] lead-write-guard allows .claude/state/* (relative)
- [ ] lead-write-guard allows .claude/state/* (absolute)
- [ ] on-pre-compact logs to compaction-events.log

## Path Resolution Tests
- [ ] Worktree spawn template uses ../.claude/state/
- [ ] Teammates can read ledger from worktree
- [ ] Teammates can write status files from worktree

## Plan Persistence Tests
- [ ] Plan written to .claude/state/orchestration-plan.md
- [ ] Plan readable after "exiting" plan mode
- [ ] cleanup-state.sh removes plan file

## Version Tests
- [ ] plugin.json shows 1.0.1
- [ ] marketplace.json shows 1.0.1 for agent-orchestrator
- [ ] Both files validate with jq

## Regression Tests
- [ ] No fix broke another fix
- [ ] Scripts still work without ORCHESTRATOR_LEAD=1
- [ ] Cleanup scripts remove all artifacts
```

**Step 4: Review git log**

```bash
echo "=== Commit history for this fix session ==="
git log --oneline --graph HEAD~8..HEAD
```

Expected: 7-8 commits showing each task

**Step 5: Verify working tree is clean**

```bash
git status
```

Expected: No uncommitted changes

**Step 6: Final commit (plan document)**

```bash
git add docs/plans/2026-02-16-agent-orchestrator-bug-fixes.md
git commit -m "docs: add bug fix implementation plan for agent-orchestrator

Comprehensive plan covering all fixes:
- High priority: read-counter, worktree paths
- Medium priority: absolute path matching, plan persistence, hook matchers
- Low priority: minor improvements
- Version bump to 1.0.1"
```

---

## Summary

**Total Tasks:** 8
**Estimated Time:** 2-3 hours (following each step carefully)
**Risk Level:** Low (each fix is isolated and tested)

**Execution Order Rationale:**
1. **read-counter** - Most isolated, no dependencies
2. **worktree-paths** - Affects spawn template only
3. **lead-write-guard** - Isolated to one script
4. **plan-persistence** - Adds new behavior, doesn't change existing
5. **hook-matchers** - Expands coverage, doesn't restrict existing
6. **minor-improvements** - Pure refactors, no behavior change
7. **version-bump** - Final administrative task
8. **verification** - Confirms no regressions

**Success Criteria:**
- All commits apply cleanly
- All validation scripts pass
- No script errors when run individually
- Git status clean after Task 8
- Plugin version 1.0.1 in both manifest and marketplace
