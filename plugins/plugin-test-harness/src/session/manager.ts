import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { detectPluginMode, detectPluginName, detectBuildSystem, readMcpConfig } from '../plugin/detector.js';
import { generateSessionBranch, createBranch, addWorktree, removeWorktree, pruneWorktrees, commitAll, checkBranchExists } from './git.js';
import { writeSessionState, readSessionState } from './state-persister.js';
import { TestStore } from '../testing/store.js';
import { loadTestsFromDir } from '../testing/parser.js';
import type { SessionState } from './types.js';

// In-memory state shared with server.ts
export let testStore = new TestStore();
export let iterationHistory: Array<{ passing: number; failing: number; fixesApplied: number }> = [];

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
  const mode = await detectPluginMode(args.pluginPath);
  lines.push(`✓ Plugin mode: ${mode}`);

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

  lines.push('', 'OK — ready to start a session.');
  return lines.join('\n');
}

export interface StartSessionResult {
  state: SessionState;
  message: string;
}

export async function startSession(args: { pluginPath: string; sessionNote?: string }): Promise<StartSessionResult> {
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  const _buildSystem = await detectBuildSystem(args.pluginPath);

  // Create session branch
  const branch = generateSessionBranch(pluginName);
  await pruneWorktrees(args.pluginPath);

  // Check branch doesn't exist (regenerate if collision)
  if (await checkBranchExists(args.pluginPath, branch)) {
    throw new Error(`Branch ${branch} already exists — this should be extremely rare`);
  }

  // Create worktree
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${branch.split('/')[1]}`);
  await createBranch(args.pluginPath, branch);
  await addWorktree(args.pluginPath, worktreePath, branch);

  // Write session lock
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
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

  const lines = [
    `PTH session started.`,
    ``,
    `Branch:    ${branch}`,
    `Worktree:  ${worktreePath}`,
    `Mode:      ${pluginMode}`,
    `Plugin:    ${pluginName}`,
    existingTests.length > 0 ? `Tests:     ${existingTests.length} loaded from previous session` : `Tests:     0 (run pth_generate_tests to create them)`,
    ``,
    pluginMode === 'mcp' && mcpConfig
      ? `MCP server: ${mcpConfig.command} ${mcpConfig.args.join(' ')}\nMake sure this plugin is loaded in your Claude Code session, then call pth_generate_tests with the tools/list output.`
      : `Plugin mode: run pth_generate_tests to analyze hook scripts and manifest.`,
  ];

  return { state, message: lines.join('\n') };
}

export async function resumeSession(args: { branch: string; pluginPath: string }): Promise<StartSessionResult> {
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${args.branch.split('/')[1]}`);

  // Check branch exists
  if (!await checkBranchExists(args.pluginPath, args.branch)) {
    throw new Error(`Branch ${args.branch} not found in ${args.pluginPath}`);
  }

  await pruneWorktrees(args.pluginPath);
  await addWorktree(args.pluginPath, worktreePath, args.branch);

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

  // Commit test suite + state
  await commitAll(state.worktreePath, buildCommitMessage('chore: persist PTH test suite', { 'PTH-Type': 'session-end' }));

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
    `Review: git log ${state.branch}`,
    `Diff:   git diff origin/$(git rev-parse --abbrev-ref HEAD)...${state.branch}`,
  ].join('\n');
}

function buildCommitMessage(title: string, trailers: Record<string, string>): string {
  const lines = Object.entries(trailers).map(([k, v]) => `${k}: ${v}`).join('\n');
  return lines ? `${title}\n\n${lines}` : title;
}
