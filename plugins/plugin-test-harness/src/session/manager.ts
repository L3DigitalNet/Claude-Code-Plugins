import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { detectPluginMode, detectPluginName, detectBuildSystem, readMcpConfig } from '../plugin/detector.js';
import { generateSessionBranch, createBranch, addWorktree, removeWorktree, pruneWorktrees, commitAll, checkBranchExists } from './git.js';
import { writeSessionState, readSessionState } from './state-persister.js';
import { TestStore } from '../testing/store.js';
import { loadTestsFromDir } from '../testing/parser.js';
import type { SessionState } from './types.js';
import { run } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';

// In-memory state shared with server.ts
export let testStore = new TestStore();
export const iterationHistory: Array<{ passing: number; failing: number; fixesApplied: number }> = [];

export async function preflight(args: { pluginPath: string }): Promise<string> {
  const lines: string[] = ['PTH Preflight Check', ''];

  // Check path exists
  try {
    await fs.access(args.pluginPath);
    lines.push(`✓ Plugin path exists: ${args.pluginPath}`);
  } catch {
    return `✗ Plugin path not found: ${args.pluginPath}`;
  }

  // Check git repo
  try {
    await fs.access(path.join(args.pluginPath, '.git'));
    lines.push(`✓ Git repository detected`);
  } catch {
    lines.push(`⚠ Not a git repository — PTH requires git for session branch management`);
  }

  // Check plugin mode
  let pluginValid = false;
  try {
    const mode = await detectPluginMode(args.pluginPath);
    lines.push(`✓ Plugin mode: ${mode}`);
    pluginValid = true;
  } catch {
    lines.push(`✗ Not a valid plugin: no .mcp.json or .claude-plugin/ found`);
  }

  // Check for active session lock
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
  try {
    const lock = JSON.parse(await fs.readFile(lockPath, 'utf-8')) as { pid: number; branch: string };
    try {
      process.kill(lock.pid, 0);  // check if PID is alive
      lines.push(`⚠ Active session detected (PID ${lock.pid}, branch ${lock.branch})`);
    } catch {
      lines.push(`⚠ Stale session lock found (PID ${lock.pid} is not running) — will be cleaned up at start`);
    }
  } catch {
    lines.push(`✓ No active session lock`);
  }

  if (pluginValid) {
    lines.push('', 'OK — ready to start a session.');
  } else {
    lines.push('', 'Cannot start session — fix the issues above first.');
  }
  return lines.join('\n');
}

export interface StartSessionResult {
  state: SessionState;
  message: string;
}

export async function startSession(args: { pluginPath: string; sessionNote?: string }): Promise<StartSessionResult> {
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  await detectBuildSystem(args.pluginPath);

  // Create session branch
  const branch = generateSessionBranch(pluginName);
  await pruneWorktrees(args.pluginPath);

  // Check branch doesn't exist (regenerate if collision)
  if (await checkBranchExists(args.pluginPath, branch)) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Branch ${branch} already exists — this should be extremely rare. Try again.`);
  }

  // Create worktree
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${branch.split('/')[1]}`);
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');

  // All resource acquisition inside try so we can roll back fully on failure
  try {
    await createBranch(args.pluginPath, branch);
    await addWorktree(args.pluginPath, worktreePath, branch);

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
      existingTests.length > 0 ? `Tests:     ${existingTests.length} loaded from previous session` : `Tests:     0 (run pth_generate_tests to create them)`,
      ``,
      nextStep,
    ];

    return { state, message: lines.join('\n') };
  } catch (err) {
    // Best-effort rollback: clean up all acquired resources
    await fs.rm(lockPath, { force: true });
    await removeWorktree(args.pluginPath, worktreePath).catch(() => { /* ignore if not yet added */ });
    await run('git', ['branch', '-D', branch], { cwd: args.pluginPath }).catch(() => { /* ignore if not yet created */ });
    throw err;
  }
}

export async function resumeSession(args: { branch: string; pluginPath: string }): Promise<StartSessionResult> {
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${args.branch.split('/')[1]}`);

  // Check branch exists
  if (!await checkBranchExists(args.pluginPath, args.branch)) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Branch ${args.branch} not found in ${args.pluginPath}`);
  }

  await pruneWorktrees(args.pluginPath);
  const worktreeExists = await fs.access(worktreePath).then(() => true).catch(() => false);
  if (!worktreeExists) {
    await addWorktree(args.pluginPath, worktreePath, args.branch);
  }

  // Load state
  const savedState = await readSessionState(worktreePath);
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);

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
    startedAt: new Date().toISOString(),
    iteration: 0,
    testCount: testStore.count(),
    passingCount: 0,
    failingCount: 0,
    convergenceTrend: 'unknown',
    activeFailures: [],
  };

  state.worktreePath = worktreePath;

  const lines = [
    `PTH session resumed.`,
    ``,
    `Branch:     ${args.branch}`,
    `Iteration:  ${state.iteration}`,
    `Tests:      ${testStore.count()} loaded`,
    `Status:     ${state.passingCount} passing, ${state.failingCount} failing`,
    `Trend:      ${state.convergenceTrend}`,
    savedState ? `` : `Note: session-state.json not found — reconstructed from git history.`,
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
  await removeWorktree(state.pluginPath, state.worktreePath);

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
