import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { detectPluginMode, detectPluginName, detectBuildSystem, readMcpConfig } from '../plugin/detector.js';
import { generateSessionBranch, createBranch, addWorktree, removeWorktree, pruneWorktrees, commitAll, checkBranchExists, getGitRepoRoot, cleanWorktreePthDir } from './git.js';
import { writeSessionState, readSessionState } from './state-persister.js';
import { TestStore } from '../testing/store.js';
import type { SessionState } from './types.js';
import { run } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import { hasHistory, loadTests, saveTests, loadSnapshot, saveSnapshot, appendResults, saveSessionArtifacts, updateIndex } from '../persistence/store-manager.js';
import { scanPlugin, buildSnapshot } from '../persistence/plugin-scanner.js';
import { analyzeGap } from '../persistence/gap-analyzer.js';
import { buildReportContent } from './report-generator.js';
import { getFixHistory } from '../fix/tracker.js';
import type { GapAnalysisResult, EndSessionOptions } from '../persistence/types.js';
import type { ToolSnapshotEntry } from '../persistence/types.js';

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

  // Check for active session lock — track separately so the verdict can reflect it.
  // A live session blocks pth_start_session even when all other checks pass.
  let liveSessionActive = false;
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
  try {
    const lock = JSON.parse(await fs.readFile(lockPath, 'utf-8')) as { pid: number; branch: string };
    try {
      process.kill(lock.pid, 0);  // check if PID is alive
      liveSessionActive = true;
      checkLines.push(`⚠ Active session detected (PID ${lock.pid}, branch ${lock.branch})`);
    } catch {
      checkLines.push(`⚠ Stale session lock found (PID ${lock.pid} is not running) — will be cleaned up at start`);
    }
  } catch {
    checkLines.push(`✓ No active session lock`);
  }

  // Check for persistent store history
  let pluginName = '';
  try {
    pluginName = await detectPluginName(args.pluginPath);
    const history = await hasHistory(pluginName);
    checkLines.push(history
      ? `✓ Persistent store found: ~/.pth/${pluginName.replace(/[^a-z0-9-]/gi, '-').toLowerCase()}/`
      : `○ No persistent store yet — will be created at session end`
    );
  } catch {
    // Non-fatal — plugin name detection failure is caught later in startSession
  }

  // Verdict first per P3 (lead with findings).
  // Three distinct states: plugin invalid, session active (blocks start), or clear.
  const verdict = !pluginValid
    ? '✗ Cannot start session — fix the issues above first.'
    : liveSessionActive
      ? '⚠ Session already active — call pth_end_session first, or use pth_resume_session.'
      : '✓ OK — ready to start a session.';
  return [verdict, '', 'PTH Preflight Check', '', ...checkLines].join('\n');
}

export interface StartSessionResult {
  state: SessionState;
  message: string;
  gapAnalysis?: GapAnalysisResult;
}

export async function startSession(args: { pluginPath: string; sessionNote?: string }): Promise<StartSessionResult> {
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  await detectBuildSystem(args.pluginPath);

  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');

  // Enforce the session lock — reject if another Claude instance has an active session.
  // Uses the same live-PID check as preflight so stale locks (dead PID) are silently ignored.
  {
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

  // Check for persistent store history and run gap analysis before worktree setup
  // (gap analysis only needs plugin source, not worktree)
  const pluginHasHistory = await hasHistory(pluginName);
  let savedTests: Awaited<ReturnType<typeof loadTests>> = [];
  let gapAnalysis: GapAnalysisResult | undefined;

  if (pluginHasHistory) {
    const [snapshot, tests] = await Promise.all([
      loadSnapshot(pluginName),
      loadTests(pluginName),
    ]);
    savedTests = tests;

    if (snapshot) {
      const scan = await scanPlugin(args.pluginPath, snapshot.capturedAt);
      gapAnalysis = analyzeGap(snapshot, scan, tests);
    }
  }

  // All resource acquisition inside try so we can roll back fully on failure
  try {
    await createBranch(repoRoot, branch);
    await addWorktree(repoRoot, worktreePath, branch);

    // Write session lock
    await fs.mkdir(path.join(args.pluginPath, '.pth'), { recursive: true });
    await fs.writeFile(lockPath, JSON.stringify({ pid: process.pid, branch, startedAt: new Date().toISOString() }), 'utf-8');

    // Load tests from persistent store (authoritative) — worktree has no tests yet
    testStore = new TestStore();
    savedTests.forEach(t => testStore.add(t));

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
          `Next: call pth_generate_tests — tool schemas will be auto-discovered from the MCP server.`,
        ].join('\n')
      : `Next: call pth_generate_tests to analyze hook scripts and manifest.`;

    // Build gap summary for response
    const gapLines: string[] = [];
    if (gapAnalysis) {
      gapLines.push('');
      gapLines.push('Gap Analysis:');
      if (gapAnalysis.newComponents.length > 0) {
        gapLines.push(`  New:      ${gapAnalysis.newComponents.join(', ')}`);
      }
      if (gapAnalysis.modifiedComponents.length > 0) {
        gapLines.push(`  Modified: ${gapAnalysis.modifiedComponents.join(', ')}`);
      }
      if (gapAnalysis.removedComponents.length > 0) {
        gapLines.push(`  Removed:  ${gapAnalysis.removedComponents.join(', ')}`);
      }
      if (gapAnalysis.staleTestIds.length > 0) {
        gapLines.push(`  Stale tests: ${gapAnalysis.staleTestIds.join(', ')}`);
      }
      gapLines.push(`  → ${gapAnalysis.recommendation}`);
    }

    const lines = [
      `PTH session started.`,
      ``,
      `Branch:    ${branch}`,
      `Worktree:  ${worktreePath}`,
      `Mode:      ${pluginMode}`,
      `Plugin:    ${pluginName}`,
      pluginRelPath ? `Subpath:   ${pluginRelPath}` : '',
      `Plugin dir: ${path.join(worktreePath, pluginRelPath)}`,
      savedTests.length > 0 ? `Tests:     ${savedTests.length} loaded from persistent store (~/.pth/${pluginName.replace(/[^a-z0-9-]/gi, '-').toLowerCase()}/)` : `Tests:     0 (run pth_generate_tests to create them)`,
      ...gapLines,
      ``,
      nextStep,
    ].filter(l => l !== undefined) as string[];

    return { state, message: lines.join('\n'), gapAnalysis };
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

  // Load state from worktree (runtime state for in-progress session)
  const savedState = await readSessionState(worktreePath);
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  const pluginRelPath = path.relative(repoRoot, args.pluginPath);

  // Load tests from persistent store (authoritative) — not from worktree
  testStore = new TestStore();
  const tests = await loadTests(pluginName);
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
    `Tests:     ${testStore.count()} loaded from persistent store`,
    `Status:    ${state.passingCount} passing, ${state.failingCount} failing`,
    `Trend:     ${state.convergenceTrend}`,
    ...(!savedState ? [`Note: session-state.json not found — reconstructed from git history.`] : []),
  ];

  return { state, message: lines.join('\n') };
}

export async function endSession(state: SessionState, options: EndSessionOptions): Promise<string> {
  // 1. Persist tests to ~/.pth/PLUGIN_NAME/tests/ (authoritative store)
  await saveTests(state.pluginName, testStore);

  // 2. Append results history to ~/.pth/PLUGIN_NAME/results-history.json
  await appendResults(state.pluginName, state.branch, options.exportedResults);

  // 3. Build session report content
  const reportContent = buildReportContent({
    state,
    allResults: [],  // Not used by buildReportContent
    iterationHistory: options.iterationHistory.map((s, i) => ({
      iteration: i + 1,
      passing: s.passing,
      failing: s.failing,
      fixesApplied: s.fixesApplied,
    })),
  });

  // 4. Collect fix history from git before worktree removal
  const fixHistory = await getFixHistory(state.worktreePath);

  // 5. Save per-session artifacts to ~/.pth/PLUGIN_NAME/sessions/<id>/
  const sessionDir = await saveSessionArtifacts(state.pluginName, {
    sessionId: state.branch,
    reportContent,
    iterationHistory: options.iterationHistory,
    fixHistory,
  });

  // 6. Build and save plugin snapshot for gap analysis in future sessions
  // Read tool schema cache written by pth_generate_tests (if it ran this session)
  let toolSchemas: ToolSnapshotEntry[] = [];
  try {
    const cacheRaw = await fs.readFile(path.join(state.worktreePath, '.pth-tools-cache.json'), 'utf-8');
    const cached = JSON.parse(cacheRaw) as Array<{ name: string; description?: string; inputSchema?: object }>;
    toolSchemas = cached.map(t => ({
      name: t.name,
      description: t.description ?? '',
      inputSchema: t.inputSchema ?? {},
    }));
  } catch {
    // pth_generate_tests was not called this session, or cache is unavailable — preserve existing snapshot
  }
  const scan = await scanPlugin(state.pluginPath);
  const snapshot = buildSnapshot(scan, toolSchemas);
  await saveSnapshot(state.pluginName, snapshot);

  // 7. Update persistent store index
  await updateIndex(state.pluginName, state.branch);

  // 8. Clean worktree .pth/ — prevents stale test data from being loaded if this branch
  //    is resumed later after tests have evolved in the persistent store
  await cleanWorktreePthDir(state.worktreePath);

  // 9. Commit any uncommitted plugin code changes on the branch (NOT tests — they're in ~/.pth/)
  const status = await run('git', ['status', '--porcelain'], { cwd: state.worktreePath });
  if (status.stdout.trim()) {
    await commitAll(state.worktreePath, buildCommitMessage('chore: session end cleanup', { 'PTH-Type': 'session-end' }));
  }

  // 10. Remove worktree and lock
  const repoRoot = await getGitRepoRoot(state.pluginPath);
  await removeWorktree(repoRoot, state.worktreePath);
  const lockPath = path.join(state.pluginPath, '.pth', 'active-session.lock');
  await fs.rm(lockPath, { force: true });

  return [
    `PTH session ended.`,
    ``,
    `Branch:       ${state.branch}`,
    `Tests saved:  ${testStore.count()} → ~/.pth/${state.pluginName.replace(/[^a-z0-9-]/gi, '-').toLowerCase()}/tests/`,
    `Iterations:   ${state.iteration}`,
    `Final status: ${state.passingCount} passing, ${state.failingCount} failing`,
    ``,
    `Persistent store: ~/.pth/${state.pluginName.replace(/[^a-z0-9-]/gi, '-').toLowerCase()}/`,
    `Session report:   ${sessionDir}/SESSION-REPORT.md`,
    `Branch ${state.branch} remains in your repo with full fix history.`,
    `Review: git log ${state.branch}  (run from ${state.pluginPath})`,
  ].join('\n');
}

function buildCommitMessage(title: string, trailers: Record<string, string>): string {
  const lines = Object.entries(trailers).map(([k, v]) => `${k}: ${v}`).join('\n');
  return lines ? `${title}\n\n${lines}` : title;
}
