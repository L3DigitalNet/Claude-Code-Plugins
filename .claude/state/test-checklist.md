# Agent Orchestrator v1.0.1 - Integration Test Checklist

**Date:** 2026-02-16
**Branch:** testing
**Version:** 1.0.1

## Pre-Deployment Validation

All automated validations passed:
- ✅ Marketplace JSON syntax valid
- ✅ Plugin manifest JSON syntax valid
- ✅ Hooks configuration JSON syntax valid
- ✅ All referenced hook scripts exist
- ✅ Versions synchronized (plugin.json and marketplace.json both at 1.0.1)
- ✅ Working tree clean

## Hook Coverage Verification

### PreCompact Hook
- **Script:** `on-pre-compact.sh`
- **Matcher:** `auto` (triggers on automatic context compaction)
- **Purpose:** Warn about context compaction events
- **Status:** ✅ Configured correctly

### PreToolUse Hook
- **Script:** `lead-write-guard.sh`
- **Matcher:** `Write|Edit|MultiEdit|NotebookEdit|mcp__.*__(write|edit|create|update).*`
- **Purpose:** Block write operations when `ORCHESTRATOR_LEAD=1`
- **Fixes Applied:**
  - Task 3: Fixed absolute path matching logic
  - Task 5: Expanded matcher to cover all write tools
- **Status:** ✅ Configured correctly

### PostToolUse Hook
- **Script:** `read-counter.sh`
- **Matcher:** `Read|View`
- **Purpose:** Track file reads per session, warn at threshold
- **Fixes Applied:**
  - Task 1: Fixed session tracking bug with double colon replacement
- **Status:** ✅ Configured correctly

### Hook Conflict Analysis
- ✅ No overlapping matchers (PreToolUse vs PostToolUse on different tools)
- ✅ No conflicting script execution (each hook type has one script)
- ✅ Clear separation of concerns (pre-block, post-monitor, compact-warn)

## Bug Fixes Verification

### Task 1: read-counter.sh Session Tracking
- **Issue:** Session ID with double colons broke filename generation
- **Fix:** Replace `:` with `_` in session ID
- **Verification:** Script syntax valid, logic updated
- **Status:** ✅ Fixed

### Task 2: Worktree Path References
- **Issue:** Spawn template used `$ORCHESTRATOR_WORKTREE` (undefined)
- **Fix:** Changed to `$ORCHESTRATOR_ROOT` (defined in bootstrap)
- **Verification:** Template references correct variable
- **Status:** ✅ Fixed

### Task 3: lead-write-guard.sh Absolute Path Matching
- **Issue:** Used `$ORCHESTRATOR_WORKTREE` and incorrect relative path logic
- **Fix:** Changed to `$ORCHESTRATOR_ROOT` with proper startsWith check
- **Verification:** Script logic updated, paths corrected
- **Status:** ✅ Fixed

### Task 4: Plan Persistence
- **Issue:** Plan created in Phase 1 not accessible in Phase 2
- **Fix:** Added plan copy from worktree to lead's `.claude/state/`
- **Verification:** `merge-branches.sh` includes plan copy logic
- **Status:** ✅ Fixed

### Task 5: Hook Matcher Expansion
- **Issue:** PreToolUse hook only matched `Write`, missed `Edit|MultiEdit|NotebookEdit|mcp__*__write*`
- **Fix:** Expanded matcher to comprehensive write tool pattern
- **Verification:** hooks.json contains full matcher pattern
- **Status:** ✅ Fixed

### Task 6: Minor Improvements (Optional)
- **Changes:**
  - Added `-e` flag to bootstrap.sh for early failure detection
  - Added error messages to cleanup scripts
  - Added comments to all scripts
- **Verification:** Scripts show improved error handling
- **Status:** ✅ Completed

### Task 7: Version Bump
- **Issue:** Need to bump version after bug fixes
- **Fix:** Updated both plugin.json and marketplace.json to v1.0.1
- **Verification:** Both files show version 1.0.1
- **Status:** ✅ Completed

## Manual Integration Testing Required

These scenarios should be tested manually before deployment:

### Scenario 1: Session Tracking with Colons
1. Start orchestration with session ID containing colons (e.g., `orchestrator_2026-02-16T12:30:45`)
2. Read multiple files
3. Verify read counter file created without errors
4. **Expected:** Filename like `/tmp/read-counter_orchestrator_2026-02-16T12_30_45.txt`

### Scenario 2: Worktree Path Resolution
1. Start orchestration
2. Verify `$ORCHESTRATOR_ROOT` points to worktree
3. Navigate within worktree
4. Trigger lead-write-guard
5. **Expected:** Guard correctly identifies files inside worktree

### Scenario 3: Lead Write Blocking
1. Start orchestration with `ORCHESTRATOR_LEAD=1`
2. Attempt to use Write tool
3. **Expected:** Hook blocks with message about delegation
4. Attempt Edit, MultiEdit, NotebookEdit
5. **Expected:** All blocked

### Scenario 4: Plan Persistence
1. Run Phase 1 (plan creation)
2. Verify plan exists in worktree `.claude/state/plan.md`
3. Run Phase 2 (merge)
4. **Expected:** Plan copied to lead's `.claude/state/plan.md`

### Scenario 5: Read Threshold Warning
1. Start orchestration
2. Read 15+ files
3. **Expected:** Warning appears in context after threshold reached

### Scenario 6: MCP Write Tool Blocking
1. Install MCP server with write capability (e.g., filesystem MCP)
2. Start orchestration as lead
3. Attempt `mcp__filesystem__write_file`
4. **Expected:** Hook blocks write operation

## Deployment Readiness

- ✅ All automated validations pass
- ✅ All bug fixes applied and verified
- ✅ Hook configuration is complete and conflict-free
- ✅ Git history shows clean progression of fixes
- ✅ Working tree is clean (no uncommitted changes)
- ✅ Version bumped to 1.0.1 in both manifests

## Recommended Next Steps

1. **Manual testing:** Execute scenarios 1-6 above in test environment
2. **Documentation review:** Verify DESIGN.md and README.md reflect changes
3. **Merge to main:** Once manual tests pass:
   ```bash
   git checkout main
   git merge testing --no-ff -m "Deploy agent-orchestrator v1.0.1: bug fix release"
   git push origin main
   git checkout testing
   ```
4. **Announce update:** Update users via documentation or changelog

## Notes

- This is a **patch release** (1.0.0 → 1.0.1) - bug fixes only, no breaking changes
- All fixes are defensive improvements (prevent errors, don't change core behavior)
- Hooks are now comprehensive (cover all write tools including MCP)
- Session tracking is robust (handles special characters in session IDs)
- Plan persistence ensures continuity between orchestration phases

---

**Validated by:** Task 8 verification
**Ready for deployment:** ✅ Pending manual integration tests
