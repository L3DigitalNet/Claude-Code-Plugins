# PTH Session Integrity Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix four session integrity bugs in the plugin-test-harness MCP server discovered during self-testing.

**Architecture:** All fixes are in `src/session/manager.ts` (lock enforcement + branch validation) and `src/server.ts` (generate_tests upsert). No new modules. Tests go in `test/unit/` using Jest + ts-jest.

**Tech Stack:** TypeScript, Node.js ESM, Jest with ts-jest, `@modelcontextprotocol/sdk`

---

## Bug Inventory

| # | Location | Root Cause |
|---|----------|-----------|
| BUG-1 | `manager.ts:startSession` | Never reads lock file before creating new session |
| BUG-2 | `manager.ts:resumeSession` | No branch pattern validation; `branch.split('/')[1]` is `undefined` for `main` |
| BUG-3 | `server.ts:pth_end_session` | Cascades from BUG-2 — worktreePath becomes `/tmp/pth-worktree-undefined` |
| BUG-4 | `server.ts:pth_generate_tests` | `store.add()` throws on duplicate ID; no upsert path |

BUG-3 is fully resolved by fixing BUG-2 (branch validation prevents the undefined path). BUG-5
(stale `files:[]` test YAML) is resolved by BUG-4's upsert behavior — users re-run generate to refresh.

---

## Files to Touch

- **Modify:** `plugins/plugin-test-harness/src/session/manager.ts`
- **Modify:** `plugins/plugin-test-harness/src/server.ts`
- **Create:** `plugins/plugin-test-harness/test/unit/manager.test.ts`
- **Create:** `plugins/plugin-test-harness/test/unit/server-generate.test.ts`

Build: `cd plugins/plugin-test-harness && npm run build`
Test: `cd plugins/plugin-test-harness && npm run test:unit`

---

## Task 1: Lock Enforcement in `startSession` (BUG-1)

**File:** `plugins/plugin-test-harness/src/session/manager.ts`

The `startSession` function (line 75) never checks the lock file before creating a new session.
The lock path is `path.join(args.pluginPath, '.pth', 'active-session.lock')`.
The same PID-alive check that `preflight` uses (`process.kill(pid, 0)`) must be applied here.

**Step 1: Write the failing test**

Create `plugins/plugin-test-harness/test/unit/manager.test.ts`:

```typescript
import fs from 'fs/promises';
import path from 'path';
import os from 'os';

// Minimal mocks — we only test the lock-check logic, not git or filesystem side effects
jest.mock('../src/plugin/detector.js', () => ({
  detectPluginName: jest.fn().mockResolvedValue('test-plugin'),
  detectPluginMode: jest.fn().mockResolvedValue('plugin'),
  detectBuildSystem: jest.fn().mockResolvedValue('none'),
  readMcpConfig: jest.fn().mockResolvedValue(null),
}));
jest.mock('../src/session/git.js', () => ({
  getGitRepoRoot: jest.fn().mockResolvedValue('/fake/repo'),
  generateSessionBranch: jest.fn().mockReturnValue('pth/test-plugin-2026-02-21-abc123'),
  pruneWorktrees: jest.fn().mockResolvedValue(undefined),
  checkBranchExists: jest.fn().mockResolvedValue(false),
  createBranch: jest.fn().mockRejectedValue(new Error('git stubbed')),
  addWorktree: jest.fn().mockRejectedValue(new Error('git stubbed')),
  removeWorktree: jest.fn().mockResolvedValue(undefined),
}));

describe('startSession — lock enforcement (BUG-1)', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-test-'));
    await fs.mkdir(path.join(tmpDir, '.pth'), { recursive: true });
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true, force: true });
  });

  it('throws SESSION_ALREADY_ACTIVE when lock exists with live PID', async () => {
    const { startSession } = await import('../src/session/manager.js');
    const lockPath = path.join(tmpDir, '.pth', 'active-session.lock');
    // Write lock with own PID — guaranteed live
    await fs.writeFile(lockPath, JSON.stringify({ pid: process.pid, branch: 'pth/other-2026-01-01-abc123' }));

    await expect(startSession({ pluginPath: tmpDir }))
      .rejects.toMatchObject({ code: 'SESSION_ALREADY_ACTIVE' });
  });

  it('proceeds normally when lock has dead PID', async () => {
    const { startSession } = await import('../src/session/manager.js');
    const lockPath = path.join(tmpDir, '.pth', 'active-session.lock');
    // PID 1 on Linux is always alive, but use a known-dead PID: 99999999
    await fs.writeFile(lockPath, JSON.stringify({ pid: 99999999, branch: 'pth/old-session' }));

    // Will throw GIT_ERROR (from the stubbed git), not SESSION_ALREADY_ACTIVE
    await expect(startSession({ pluginPath: tmpDir }))
      .rejects.toMatchObject({ code: 'GIT_ERROR' });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/plugin-test-harness && npm run test:unit -- --testPathPattern=manager 2>&1 | tail -20
```
Expected: FAIL — `startSession` does not yet throw `SESSION_ALREADY_ACTIVE`.

**Step 3: Add lock check to `startSession`**

In `manager.ts`, add this block immediately after the `detectBuildSystem` call (before `getGitRepoRoot`):

```typescript
// Enforce the session lock — reject if another Claude instance has an active session.
// Uses the same live-PID check as preflight so stale locks (dead PID) are silently ignored.
const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
try {
  const raw = await fs.readFile(lockPath, 'utf-8');
  const lock = JSON.parse(raw) as { pid: number; branch: string };
  try {
    process.kill(lock.pid, 0);  // throws if PID is dead
    throw new PTHError(
      PTHErrorCode.SESSION_ALREADY_ACTIVE,
      `Session already active (PID ${lock.pid}, branch ${lock.branch}). Call pth_end_session first, or run pth_preflight to verify.`
    );
  } catch (e) {
    if (e instanceof PTHError) throw e;  // re-throw our own error, not the kill signal error
    // PID is dead — stale lock, fall through and overwrite it
  }
} catch (e) {
  if (e instanceof PTHError) throw e;
  // Lock file missing or unreadable — no active session, proceed
}
```

The existing `const lockPath` at line 97 must be removed or renamed to avoid the duplicate.
Replace the existing line 97 `const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');`
with just a comment: `// lockPath defined above for lock enforcement`.

**Step 4: Run test**

```bash
cd plugins/plugin-test-harness && npm run test:unit -- --testPathPattern=manager 2>&1 | tail -20
```
Expected: PASS for both cases.

**Step 5: Commit**

```bash
cd plugins/plugin-test-harness && git add src/session/manager.ts test/unit/manager.test.ts
git commit -m "fix(session): enforce active session lock in startSession (BUG-1)"
```

---

## Task 2: Branch Pattern Validation in `resumeSession` (BUG-2 + BUG-3)

**File:** `plugins/plugin-test-harness/src/session/manager.ts`

`resumeSession` (line 167) only checks `checkBranchExists` but not the branch name pattern.
For branch `"main"`, `branch.split('/')[1]` is `undefined`, producing `pth-worktree-undefined`.

**Step 1: Add test case to `manager.test.ts`**

Append to the describe block in `manager.test.ts`:

```typescript
describe('resumeSession — branch validation (BUG-2)', () => {
  it('throws GIT_ERROR for non-pth branch names', async () => {
    const { resumeSession } = await import('../src/session/manager.js');
    await expect(resumeSession({ branch: 'main', pluginPath: '/any/path' }))
      .rejects.toMatchObject({ code: 'GIT_ERROR', message: expect.stringContaining('pth/') });
  });

  it('throws GIT_ERROR for branches without pth/ prefix', async () => {
    const { resumeSession } = await import('../src/session/manager.js');
    await expect(resumeSession({ branch: 'feature/my-thing', pluginPath: '/any/path' }))
      .rejects.toMatchObject({ code: 'GIT_ERROR' });
  });

  it('proceeds for valid pth/ branch (falls through to git check)', async () => {
    const { resumeSession } = await import('../src/session/manager.js');
    // Will fail on checkBranchExists (branch not found), not on validation
    await expect(resumeSession({ branch: 'pth/my-plugin-2026-02-21-abc123', pluginPath: '/any/path' }))
      .rejects.toMatchObject({ code: 'GIT_ERROR' });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/plugin-test-harness && npm run test:unit -- --testPathPattern=manager 2>&1 | tail -20
```
Expected: FAIL — `resumeSession` currently accepts `'main'` without error.

**Step 3: Add branch validation to `resumeSession`**

In `manager.ts`, add this block as the **first lines** of `resumeSession` (before `getGitRepoRoot`):

```typescript
// Reject non-PTH branch names before any filesystem or git operations.
// This prevents worktreePath from becoming pth-worktree-undefined when branch has no '/'.
if (!args.branch.startsWith('pth/')) {
  throw new PTHError(
    PTHErrorCode.GIT_ERROR,
    `Branch "${args.branch}" is not a PTH session branch. Session branches follow the pattern: pth/<plugin>-<date>-<hash>`
  );
}
```

**Step 4: Run test**

```bash
cd plugins/plugin-test-harness && npm run test:unit -- --testPathPattern=manager 2>&1 | tail -20
```
Expected: PASS for all three cases.

**Step 5: Commit**

```bash
cd plugins/plugin-test-harness && git add src/session/manager.ts test/unit/manager.test.ts
git commit -m "fix(session): validate pth/ branch prefix in resumeSession (BUG-2, BUG-3)"
```

---

## Task 3: Upsert Behavior in `pth_generate_tests` (BUG-4)

**File:** `plugins/plugin-test-harness/src/server.ts`

At line 176, `tests.forEach(t => store.add(t))` throws `INVALID_TEST` if any ID exists.
Fix: use `store.update()` for existing IDs, `store.add()` for new ones. Report counts.

**Step 1: Write the failing test**

Create `plugins/plugin-test-harness/test/unit/server-generate.test.ts`:

```typescript
import { TestStore } from '../../src/testing/store.js';

describe('TestStore upsert pattern (BUG-4)', () => {
  it('add() throws when ID already exists', () => {
    const store = new TestStore();
    const test = { id: 'my_test', name: 'My Test', mode: 'mcp' as const, type: 'single' as const,
      tool: 'example', input: {}, expect: { success: true } };
    store.add(test);
    expect(() => store.add(test)).toThrow('already exists');
  });

  it('update() silently overwrites an existing test', () => {
    const store = new TestStore();
    const test = { id: 'my_test', name: 'My Test', mode: 'mcp' as const, type: 'single' as const,
      tool: 'example', input: {}, expect: { success: true } };
    store.add(test);
    const updated = { ...test, name: 'Updated Name' };
    expect(() => store.update(updated)).not.toThrow();
    expect(store.get('my_test')?.name).toBe('Updated Name');
  });

  it('upsert pattern does not throw on duplicate IDs', () => {
    const store = new TestStore();
    const test = { id: 'my_test', name: 'My Test', mode: 'mcp' as const, type: 'single' as const,
      tool: 'example', input: { old: true }, expect: { success: true } };
    store.add(test);

    // Simulate what pth_generate_tests should do after the fix
    const generated = [{ ...test, input: { new: true } }];
    expect(() => {
      generated.forEach(t => store.get(t.id) ? store.update(t) : store.add(t));
    }).not.toThrow();
    expect(store.get('my_test')?.input).toEqual({ new: true });
  });
});
```

**Step 2: Run test to verify it passes** (these test the existing store, they should pass already)

```bash
cd plugins/plugin-test-harness && npm run test:unit -- --testPathPattern=server-generate 2>&1 | tail -20
```
Expected: PASS — this validates the building-block behavior; the actual server integration is covered by the end-to-end self-test.

**Step 3: Update `pth_generate_tests` dispatch in `server.ts`**

Find the `pth_generate_tests` case in `server.ts` (around line 165).
Replace:

```typescript
tests.forEach(t => store.add(t));
if (tests.length === 0) {
```

With:

```typescript
let newCount = 0;
let updatedCount = 0;
tests.forEach(t => {
  if (store.get(t.id)) {
    store.update(t);
    updatedCount++;
  } else {
    store.add(t);
    newCount++;
  }
});
if (tests.length === 0) {
```

Also update the success respond line at line 183 from:

```typescript
return respond(`Generated ${tests.length} tests:\n\n${tests.map(t => `- ${t.name}`).join('\n')}`);
```

To:

```typescript
const summary = [
  newCount > 0 ? `${newCount} new` : '',
  updatedCount > 0 ? `${updatedCount} updated` : '',
].filter(Boolean).join(', ');
return respond(`Generated ${tests.length} tests (${summary}):\n\n${tests.map(t => `- ${t.name}`).join('\n')}`);
```

**Step 4: Build and verify no TypeScript errors**

```bash
cd plugins/plugin-test-harness && npm run build 2>&1 | tail -20
```
Expected: build succeeds with no errors.

**Step 5: Commit**

```bash
cd plugins/plugin-test-harness && git add src/server.ts test/unit/server-generate.test.ts
git commit -m "fix(generate): upsert existing tests instead of throwing on duplicate IDs (BUG-4)"
```

---

## Task 4: Full Build and Test

**Step 1: Run all unit tests**

```bash
cd plugins/plugin-test-harness && npm run test:unit 2>&1
```
Expected: all tests pass.

**Step 2: Run typecheck**

```bash
cd plugins/plugin-test-harness && npm run typecheck 2>&1
```
Expected: 0 errors.

**Step 3: Run full build**

```bash
cd plugins/plugin-test-harness && npm run build 2>&1 | tail -10
```
Expected: build succeeds.

**Step 4: Bump version in plugin.json and marketplace.json**

Bump `plugins/plugin-test-harness/.claude-plugin/plugin.json` from `"0.3.0"` to `"0.4.0"`.
Bump the matching entry in `.claude-plugin/marketplace.json` to `"0.4.0"`.
Update `plugins/plugin-test-harness/CHANGELOG.md`:
```markdown
## [0.4.0] - 2026-02-21
### Fixed
- `pth_start_session` now rejects if an active session lock is held by a live process (BUG-1)
- `pth_resume_session` now validates branch has `pth/` prefix before proceeding (BUG-2, BUG-3)
- `pth_generate_tests` now upserts existing tests instead of throwing on duplicate IDs (BUG-4)
```

**Step 5: Validate marketplace**

```bash
cd /home/chris/projects/Claude-Code-Plugins && ./scripts/validate-marketplace.sh 2>&1
```
Expected: validation passes.

**Step 6: Final commit**

```bash
cd /home/chris/projects/Claude-Code-Plugins
git add plugins/plugin-test-harness/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        plugins/plugin-test-harness/CHANGELOG.md
git commit -m "chore: bump plugin-test-harness to 0.4.0"
```
