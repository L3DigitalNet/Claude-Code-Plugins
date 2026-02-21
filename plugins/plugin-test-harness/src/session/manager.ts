import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { detectPluginMode, detectPluginName, detectBuildSystem, readMcpConfig } from '../plugin/detector.js';
import { generateSessionBranch, createBranch, addWorktree, removeWorktree, pruneWorktrees, commitAll, checkBranchExists, getGitRepoRoot } from './git.js';
import { writeSessionState, readSessionState } from './state-persister.js';
import { TestStore } from '../testing/store.js';
import { loadTestsFromDir } from '../testing/parser.js';
import type { SessionState } from './types.js';
import { run } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';

// In-memory state shared with server.ts.
// iterationHistory: server.ts pushes a snapshot each time pth_get_iteration_status is called
// with changed counts. detectConvergence() in src/results/convergence.ts reads this array.
// Cleared implicitly on process restart (resume starts with empty history).
export let testStore = new TestStore();
export const iterationHistory: Array<{ passing: number; failing: number; fixesApplied: number }> = [];

export async function preflight(args: { pluginPath: string }): Promise<string> {
  const checkLines: string[] = [];

  // Check path exists
  try {
    await fs.access(args.pluginPath);
    checkLines.push(`✓ Plugin path exists: ${args.pluginPath}`);
  } catch {
    return `✗ Plugin path not found: ${args.pluginPath}`;
  }

  // Check git repo (plugin may be a subdirectory of a larger repo)
  try {
    await getGitRepoRoot(args.pluginPath);
    checkLines.push(`✓ Git repository detected`);
  } catch {
    checkLines.push(`⚠ Not a git repository — PTH requires git for session branch management`);
  }

  // Check plugin mode
  let pluginValid = false;
  try {
    const mode = await detectPluginMode(args.pluginPath);
    checkLines.push(`✓ Plugin mode: ${mode}`);
    pluginValid = true;
  } catch {
    checkLines.push(`✗ Not a valid plugin: no .mcp.json or .claude-plugin/ found`);
  }

  // Check for active session lock
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
  try {
    const lock = JSON.parse(await fs.readFile(lockPath, 'utf-8')) as { pid: number; branch: string };
    try {
      process.kill(lock.pid, 0);  // check if PID is alive
      checkLines.push(`⚠ Active session detected (PID ${lock.pid}, branch ${lock.branch})`);
    } catch {
      checkLines.push(`⚠ Stale session lock found (PID ${lock.pid} is not running) — will be cleaned up at start`);
    }
  } catch {
    checkLines.push(`✓ No active session lock`);
  }

  // Verdict first per P3 (lead with findings)
  const verdict = pluginValid
    ? '✓ OK — ready to start a session.'
    : '✗ Cannot start session — fix the issues above first.';
  return [verdict, '', 'PTH Preflight Check', '', ...checkLines].join('\n');
}

export interface StartSessionResult {
  state: SessionState;
  message: string;
}

export async function startSession(args: { pluginPath: string; sessionNote?: string }): Promise<StartSessionResult> {
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  await detectBuildSystem(args.pluginPath);

  // Enforce the session lock — reject if another Claude instance has an active session.
  // Uses the same live-PID check as preflight so stale locks (dead PID) are silently ignored.
  {
    const activeLockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
    try {
      const raw = await fs.readFile(activeLockPath, 'utf-8');
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
  }

  // Resolve git repo root — plugin may be a subdirectory of a larger mono-repo.
  // pluginRelPath is the relative path from the repo root to the plugin directory.
  // All file writes (pth_apply_fix, sync, build) use path.join(worktreePath, pluginRelPath, ...).
  const repoRoot = await getGitRepoRoot(args.pluginPath);
  const pluginRelPath = path.relative(repoRoot, args.pluginPath);

  // Create session branch
  const branch = generateSessionBranch(pluginName);
  await pruneWorktrees(repoRoot);

  // Check branch doesn't exist (regenerate if collision)
  if (await checkBranchExists(repoRoot, branch)) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Branch ${branch} already exists — this should be extremely rare. Try again.`);
  }

  // Create worktree
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${branch.split('/')[1]}`);
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');

  // All resource acquisition inside try so we can roll back fully on failure
  try {
    await createBranch(repoRoot, branch);
    await addWorktree(repoRoot, worktreePath, branch);

    // Write session lock
    await fs.mkdir(path.join(args.pluginPath, '.pth'), { recursive: true });
    await fs.writeFile(lockPath, JSON.stringify({ pid: process.pid, branch, startedAt: new Date().toISOString() }), 'utf-8');

    // Load existing tests if any
    testStore = new TestStore();
    const existingTests = await loadTestsFromDir(path.join(worktreePath, '.pth', 'tests'));
    existingTests.forEach(t => testStore.add(t));

    const state: SessionState = {
      sessionId: branch,
      branch,
      worktreePath,
      pluginPath: args.pluginPath,
      pluginName,
      pluginMode,
      pluginRelPath,
      startedAt: new Date().toISOString(),
      iteration: 0,
      testCount: testStore.count(),
      passingCount: 0,
      failingCount: 0,
      convergenceTrend: 'unknown',
      activeFailures: [],
    };

    await writeSessionState(worktreePath, state);

    const mcpConfig = pluginMode === 'mcp' ? await readMcpConfig(args.pluginPath) : null;

    const nextStep = pluginMode === 'mcp' && mcpConfig
      ? [
          `MCP server: ${mcpConfig.command} ${mcpConfig.args.join(' ')}`,
          ``,
          `Next: verify the plugin is loaded in your session, then call pth_generate_tests`,
          `      with toolSchemas from its tools/list response.`,
        ].join('\n')
      : `Next: call pth_generate_tests to analyze hook scripts and manifest.`;

    const lines = [
      `PTH session started.`,
      ``,
      `Branch:    ${branch}`,
      `Worktree:  ${worktreePath}`,
      `Mode:      ${pluginMode}`,
      `Plugin:    ${pluginName}`,
      pluginRelPath ? `Subpath:   ${pluginRelPath}` : '',
      `Plugin dir: ${path.join(worktreePath, pluginRelPath)}`,
      existingTests.length > 0 ? `Tests:     ${existingTests.length} loaded from previous session` : `Tests:     0 (run pth_generate_tests to create them)`,
      ``,
      nextStep,
    ].filter(l => l !== undefined) as string[];

    return { state, message: lines.join('\n') };
  } catch (err) {
    // Best-effort rollback: clean up all acquired resources
    await fs.rm(lockPath, { force: true });
    await removeWorktree(repoRoot, worktreePath).catch(() => { /* ignore if not yet added */ });
    await run('git', ['branch', '-D', branch], { cwd: repoRoot }).catch(() => { /* ignore if not yet created */ });
    throw err;
  }
}

export async function resumeSession(args: { branch: string; pluginPath: string }): Promise<StartSessionResult> {
  // Reject non-PTH branch names before any filesystem or git operations.
  // This prevents worktreePath from becoming pth-worktree-undefined when branch has no '/'.
  if (!args.branch.startsWith('pth/')) {
    throw new PTHError(
      PTHErrorCode.GIT_ERROR,
      `Branch "${args.branch}" is not a PTH session branch. Session branches follow the pattern: pth/<plugin>-<date>-<hash>`
    );
  }

  const repoRoot = await getGitRepoRoot(args.pluginPath);
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${args.branch.split('/')[1]}`);

  // Check branch exists
  if (!await checkBranchExists(repoRoot, args.branch)) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Branch ${args.branch} not found in ${args.pluginPath}`);
  }

  await pruneWorktrees(repoRoot);
  const worktreeExists = await fs.access(worktreePath).then(() => true).catch(() => false);
  if (!worktreeExists) {
    await addWorktree(repoRoot, worktreePath, args.branch);
  }

  // Load state
  const savedState = await readSessionState(worktreePath);
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  const pluginRelPath = path.relative(repoRoot, args.pluginPath);

  testStore = new TestStore();
  const tests = await loadTestsFromDir(path.join(worktreePath, '.pth', 'tests'));
  tests.forEach(t => testStore.add(t));

  const state: SessionState = savedState ?? {
    sessionId: args.branch,
    branch: args.branch,
    worktreePath,
    pluginPath: args.pluginPath,
    pluginName,
    pluginMode,
    pluginRelPath,
    startedAt: new Date().toISOString(),
    iteration: 0,
    testCount: testStore.count(),
    passingCount: 0,
    failingCount: 0,
    convergenceTrend: 'unknown',
    activeFailures: [],
  };

  state.worktreePath = worktreePath;
  // Ensure pluginRelPath is set even for sessions created before this field existed
  state.pluginRelPath = state.pluginRelPath ?? pluginRelPath;

  const lines = [
    `PTH session resumed.`,
    ``,
    `Branch:    ${args.branch}`,
    `Iteration: ${state.iteration}`,
    `Tests:     ${testStore.count()} loaded`,
    `Status:    ${state.passingCount} passing, ${state.failingCount} failing`,
    `Trend:     ${state.convergenceTrend}`,
    ...(!savedState ? [`Note: session-state.json not found — reconstructed from git history.`] : []),
  ];

  return { state, message: lines.join('\n') };
}

export async function endSession(state: SessionState): Promise<string> {
  // Persist tests
  await testStore.persistToDir(path.join(state.worktreePath, '.pth', 'tests'));

  // Commit test suite + state (only if there are changes to commit)
  const status = await run('git', ['status', '--porcelain'], { cwd: state.worktreePath });
  if (status.stdout.trim()) {
    await commitAll(state.worktreePath, buildCommitMessage('chore: persist PTH test suite', { 'PTH-Type': 'session-end' }));
  }

  // Remove worktree
  const repoRoot = await getGitRepoRoot(state.pluginPath);
  await removeWorktree(repoRoot, state.worktreePath);

  // Remove lock
  const lockPath = path.join(state.pluginPath, '.pth', 'active-session.lock');
  await fs.rm(lockPath, { force: true });

  return [
    `PTH session ended.`,
    ``,
    `Branch:       ${state.branch}`,
    `Tests saved:  ${testStore.count()}`,
    `Iterations:   ${state.iteration}`,
    `Final status: ${state.passingCount} passing, ${state.failingCount} failing`,
    ``,
    `Branch ${state.branch} remains in your repo with full session history.`,
    `Review: git log ${state.branch}  (run from ${state.pluginPath})`,
    `Diff:   git diff $(git merge-base HEAD ${state.branch})...${state.branch}`,
  ].join('\n');
}

function buildCommitMessage(title: string, trailers: Record<string, string>): string {
  const lines = Object.entries(trailers).map(([k, v]) => `${k}: ${v}`).join('\n');
  return lines ? `${title}\n\n${lines}` : title;
}
