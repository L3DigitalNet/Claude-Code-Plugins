import path from 'path';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { zodToJsonSchema } from 'zod-to-json-schema';
import { ToolRegistry } from './tool-registry.js';
import type { SessionState } from './session/types.js';
import { ResultsTracker } from './results/tracker.js';
import { detectConvergence } from './results/convergence.js';
import { parseTest } from './testing/parser.js';
import { generateMcpTests, generatePluginTests } from './testing/generator.js';
import { applyFix } from './fix/applicator.js';
import { getFixHistory } from './fix/tracker.js';
import { revertCommit, getDiff } from './session/git.js';
import { run } from './shared/exec.js';
import { reloadPlugin } from './plugin/reloader.js';
import { writeSessionState } from './session/state-persister.js';
import { writeToolSchemasCache } from './shared/source-analyzer.js';
import type { ToolSchema } from './shared/source-analyzer.js';
import { PTHError } from './shared/errors.js';
import * as mgr from './session/manager.js';

function formatTs(iso: string): string {
  return iso.replace('T', ' ').slice(0, 16) + ' UTC';
}

export function createServer(): Server {
  const registry = new ToolRegistry();

  // Session state scoped to this server instance (fix #1: no module-level state)
  let currentSession: SessionState | null = null;

  // ResultsTracker scoped to this server instance — fresh tracker per server
  let resultsTracker = new ResultsTracker();

  // Lazily imported to avoid circular deps
  let sessionManager: typeof import('./session/manager.js') | null = null;

  const server = new Server(
    { name: 'plugin-test-harness', version: '1.0.0' },
    { capabilities: { tools: {} } }
  );

  // Static tool list — all tools always exposed; session-gating enforced at dispatch time.
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: registry.getAllTools().map(t => ({
      name: t.name,
      description: t.description,
      inputSchema: zodToJsonSchema(t.inputSchema),
    })),
  }));

  // Tool dispatch
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    return dispatch(name, args ?? {});
  });

  return server;

  async function dispatch(
    toolName: string,
    args: Record<string, unknown>
  ): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
    const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });

    try {
      // Lazy import session manager
      if (!sessionManager) {
        sessionManager = await import('./session/manager.js');
      }

      switch (toolName) {
        case 'pth_preflight': {
          const result = await sessionManager.preflight(args as { pluginPath: string });
          return respond(result);
        }
        case 'pth_start_session': {
          const result = await sessionManager.startSession(
            args as { pluginPath: string; sessionNote?: string }
          );
          currentSession = result.state;
          resultsTracker = new ResultsTracker();  // fresh tracker for new session
          return respond(result.message);
        }
        case 'pth_resume_session': {
          const result = await sessionManager.resumeSession(
            args as { branch: string; pluginPath: string }
          );
          currentSession = result.state;
          resultsTracker = new ResultsTracker();  // fresh tracker for resumed session
          return respond(result.message);
        }
        case 'pth_end_session': {
          if (!currentSession) return respond('No active session.');
          // Generate the session report before removing the worktree — report-generator
          // needs worktreePath and the in-memory resultsTracker/iterationHistory.
          const { generateReport } = await import('./session/report-generator.js');
          const reportPath = path.join(currentSession.worktreePath, '.pth/SESSION-REPORT.md');
          await generateReport(currentSession.worktreePath, {
            state: currentSession,
            allResults: resultsTracker.getAllLatest(),
            iterationHistory: mgr.iterationHistory.map((s, i) => ({
              iteration: i + 1,
              passing: s.passing,
              failing: s.failing,
              fixesApplied: s.fixesApplied,
            })),
          });
          const result = await sessionManager.endSession(currentSession);
          currentSession = null;
          return respond(`${result}\n\nReport: ${reportPath}`);
        }
        default: {
          if (!currentSession) {
            return respond('No PTH session active. Call pth_start_session first.');
          }
          // await is required — without it, async rejections from handleSessionTool
          // bypass this try-catch and surface as unhandled MCP -32603 errors.
          return await handleSessionTool(toolName, args, currentSession);
        }
      }
    } catch (err) {
      if (err instanceof PTHError) {
        // Surface context (stderr, stdout) alongside the structured error code and message.
        // PTHError.context carries raw diagnostic output that Claude needs to decide next steps.
        const ctxLines = err.context && Object.keys(err.context).length > 0
          ? '\n' + Object.entries(err.context).map(([k, v]) => `  ${k}: ${v}`).join('\n')
          : '';
        return respond(`PTH Error [${err.code}]: ${err.message}${ctxLines}`);
      }
      const msg = err instanceof Error ? err.message : String(err);
      return respond(`PTH Error: ${msg}`);
    }
  }

  async function handleSessionTool(
    toolName: string,
    args: Record<string, unknown>,
    session: SessionState
  ): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
    const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });
    const store = mgr.testStore;

    switch (toolName) {

      // ── Session management ─────────────────────────────────────────
      case 'pth_get_session_status': {
        const pass = resultsTracker.getPassCount();
        const fail = resultsTracker.getFailCount();
        const trend = detectConvergence(mgr.iterationHistory);
        return respond([
          `Session:   ${session.branch}`,
          `Mode:      ${session.pluginMode}`,
          `Iteration: ${session.iteration}`,
          `Tests:     ${store.count()} total, ${pass} passing, ${fail} failing`,
          `Trend:     ${trend}`,
          `Started:   ${formatTs(session.startedAt)}`,
        ].join('\n'));
      }

      // ── Tests ──────────────────────────────────────────────────────
      case 'pth_generate_tests': {
        const { toolSchemas, includeEdgeCases } = args as { toolSchemas?: ToolSchema[]; includeEdgeCases?: boolean };
        let tests;
        if (session.pluginMode === 'mcp' && toolSchemas) {
          await writeToolSchemasCache(session.worktreePath, toolSchemas);
          // Pass session.pluginPath (not worktreePath) so field-name heuristics in
          // buildValidInput can populate *path* fields with a real, reachable directory.
          tests = await generateMcpTests({ pluginPath: session.pluginPath, toolSchemas, includeEdgeCases });
        } else {
          tests = generatePluginTests([]);
        }
        tests.forEach(t => store.add(t));
        if (tests.length === 0) {
          const guidance = session.pluginMode === 'mcp'
            ? 'No tool schemas found. Pass toolSchemas from the plugin\'s tools/list response.'
            : 'No hook scripts found in the plugin. Create tests manually with pth_create_test.';
          return respond(`Generated 0 tests.\n\n${guidance}`);
        }
        return respond(`Generated ${tests.length} tests:\n\n${tests.map(t => `- ${t.name}`).join('\n')}`);
      }

      case 'pth_list_tests': {
        const { mode, status: filterStatus, tag } = args as {
          mode?: 'mcp' | 'plugin'; status?: string; tag?: string
        };
        let tests = store.getAll();
        if (mode) tests = tests.filter(t => t.mode === mode);
        if (tag) tests = tests.filter(t => (t.tags ?? []).includes(tag));
        if (filterStatus) {
          tests = tests.filter(t => {
            const latest = resultsTracker.getLatest(t.id);
            return (latest?.status ?? 'pending') === filterStatus;
          });
        }
        if (tests.length === 0) return respond('No tests match the filter.');
        const lines = tests.map(t => {
          const latest = resultsTracker.getLatest(t.id);
          const status = latest?.status ?? 'pending';
          const icon = status === 'passing' ? '✓' : status === 'failing' ? '✗' : '○';
          return `${icon} [${t.id}] ${t.name}`;
        });
        const filterParts = [
          mode ? `mode=${mode}` : '',
          filterStatus ? `status=${filterStatus}` : '',
          tag ? `tag=${tag}` : '',
        ].filter(Boolean);
        // Show pass/fail breakdown in unfiltered header so Claude can quickly assess session state
        const pass = resultsTracker.getPassCount();
        const fail = resultsTracker.getFailCount();
        const header = filterParts.length > 0
          ? `${tests.length} tests (${filterParts.join(', ')}):`
          : `${tests.length} tests (${pass} passing, ${fail} failing):`;
        return respond(`${header}\n\n${lines.join('\n')}`);
      }

      case 'pth_create_test': {
        const { yaml } = args as { yaml: string };
        const test = parseTest(yaml);
        store.add(test);
        return respond(`Test added: ${test.name}\nID: ${test.id}`);
      }

      case 'pth_edit_test': {
        const { testId, yaml } = args as { testId: string; yaml: string };
        const test = parseTest(yaml);
        // Always update by testId (the caller's intent), warn if id changed in YAML
        const updatedTest = test.id !== testId ? { ...test, id: testId } : test;
        store.update(updatedTest);
        const idChanged = test.id !== testId ? ` (note: YAML id '${test.id}' ignored, kept '${testId}')` : '';
        return respond(`Test updated: ${updatedTest.name}${idChanged}`);
      }

      // ── Execution ──────────────────────────────────────────────────
      case 'pth_record_result': {
        const { testId, status, durationMs, failureReason, claudeNotes } = args as {
          testId: string; status: 'passing' | 'failing' | 'skipped';
          durationMs?: number; failureReason?: string; claudeNotes?: string;
        };
        const test = store.get(testId);
        if (!test) return respond(`Unknown test id: ${testId}`);

        resultsTracker.record({
          testId,
          testName: test.name,
          status,
          iteration: session.iteration,
          durationMs,
          failureReason,
          claudeNotes,
          recordedAt: new Date().toISOString(),
        });

        const pass = resultsTracker.getPassCount();
        const fail = resultsTracker.getFailCount();
        session.passingCount = pass;
        session.failingCount = fail;
        session.activeFailures = resultsTracker.getFailingTests().map(r => ({
          testName: r.testName,
          category: '',
          lastDiagnosisSummary: r.failureReason,
        }));
        await writeSessionState(session.worktreePath, session);

        return respond(
          `Recorded: ${test.name} → ${status}${failureReason ? ` (${failureReason})` : ''}\n` +
          `Totals:   ${pass} passing, ${fail} failing`
        );
      }

      case 'pth_get_results': {
        const all = store.getAll();
        if (all.length === 0) return respond('No tests in suite. Run pth_generate_tests first.');
        const lines = all.map(t => {
          const latest = resultsTracker.getLatest(t.id);
          const status = latest?.status ?? 'pending';
          const icon = status === 'passing' ? '✓' : status === 'failing' ? '✗' : '○';
          return `${icon} ${t.name}${latest?.failureReason ? `\n  ↳ ${latest.failureReason}` : ''}`;
        });
        const pass = resultsTracker.getPassCount();
        const fail = resultsTracker.getFailCount();
        const skipped = all.filter(t => resultsTracker.getLatest(t.id)?.status === 'skipped').length;
        const pending = all.length - pass - fail - skipped;
        const summary = [
          `${pass} passing`,
          `${fail} failing`,
          skipped > 0 ? `${skipped} skipped` : '',
          `${pending} pending`,
        ].filter(Boolean).join(' / ');
        return respond(`${summary}\n\n${lines.join('\n')}`);
      }

      case 'pth_get_test_impact': {
        const { files } = args as { files: string[] };
        const impacted = store.filter(t =>
          files.some(f => {
            const base = f.split('/').pop()?.replace(/\.[^.]+$/, '') ?? '';
            return t.name.toLowerCase().includes(base.toLowerCase()) ||
                   t.id.includes(base.toLowerCase());
          })
        );
        if (impacted.length === 0) {
          return respond(`No tests found with obvious dependency on: ${files.join(', ')}\nConsider running the full suite.`);
        }
        return respond(`${impacted.length} likely-impacted tests:\n${impacted.map(t => `- ${t.name}`).join('\n')}`);
      }

      // ── Fixes ──────────────────────────────────────────────────────
      case 'pth_apply_fix': {
        const { files, commitTitle, testId, category } = args as {
          files: Array<{ path: string; content: string }>;
          commitTitle: string; testId?: string; category?: string;
        };
        const trailers: Record<string, string> = {
          ...(testId ? { 'PTH-Test': testId } : {}),
          ...(category ? { 'PTH-Category': category } : {}),
          'PTH-Iteration': String(session.iteration),
          'PTH-Files': files.map(f => f.path).join(', '),
        };
        const hash = await applyFix({
          worktreePath: session.worktreePath,
          pluginRelPath: session.pluginRelPath,
          files,
          commitTitle,
          trailers,
        });
        // Track fix count on the current iteration snapshot (for convergence history reporting).
        const activeSnap = mgr.iterationHistory[mgr.iterationHistory.length - 1];
        if (activeSnap) activeSnap.fixesApplied++;
        return respond(
          `Fix committed: ${hash.slice(0, 7)} (iteration ${session.iteration})\n` +
          `${commitTitle}\n` +
          `Files: ${files.map(f => f.path).join(', ')}\n` +
          `\nNext: re-run affected tests, then call pth_get_test_impact to identify which tests to re-record.`
        );
      }

      case 'pth_sync_to_cache': {
        const { syncToCache, detectCachePath, getInstallPath } = await import('./plugin/cache-sync.js');
        // Prefer the versioned marketplace install path over the legacy non-versioned heuristic —
        // the running MCP server process is always launched from the versioned install path.
        const cachePath = (await getInstallPath(session.pluginName)) ?? detectCachePath(session.pluginName);
        // Sync from the plugin subdirectory within the worktree, not the worktree root.
        const pluginWorktreePath = path.join(session.worktreePath, session.pluginRelPath);
        try {
          const filesSynced = await syncToCache(pluginWorktreePath, cachePath);
          const countLine = filesSynced > 0 ? `${filesSynced} file(s) synced` : 'No files changed';
          return respond(`Synced worktree to cache: ${cachePath}\n${countLine}. Hook script changes are now live.`);
        } catch (e) {
          return respond(`Cache sync failed: ${(e as Error).message}\nCache path: ${cachePath}`);
        }
      }

      case 'pth_reload_plugin': {
        const { detectBuildSystem } = await import('./plugin/detector.js');
        const { syncToCache, detectCachePath, getInstallPath } = await import('./plugin/cache-sync.js');
        // Build from the plugin subdirectory within the worktree, not the worktree root.
        const pluginWorktreePath = path.join(session.worktreePath, session.pluginRelPath);
        const buildSystem = await detectBuildSystem(pluginWorktreePath);
        const { processPattern } = args as { processPattern?: string };
        // Default pattern: the versioned install path's dist/index.js — matches the actual
        // running process. The worktree path is wrong because the live server runs from cache.
        const installPath = await getInstallPath(session.pluginName);
        const pattern = processPattern ?? (installPath ? `${installPath}/dist/index.js` : pluginWorktreePath);
        // Sync the new build to cache BEFORE killing the process — so the auto-restarted
        // server loads the new binary, not the stale one in cache.
        const cachePath = installPath ?? detectCachePath(session.pluginName);
        const result = await reloadPlugin(pluginWorktreePath, buildSystem, pattern, async () => {
          await syncToCache(pluginWorktreePath, cachePath);
        });
        const MAX_BUILD_LINES = 50;
        const buildLines = result.buildOutput ? result.buildOutput.split('\n') : [];
        const buildTruncated = buildLines.length > MAX_BUILD_LINES;
        const buildDisplay = buildTruncated
          ? buildLines.slice(0, MAX_BUILD_LINES).join('\n') + `\n[Truncated: ${buildLines.length - MAX_BUILD_LINES} more lines]`
          : result.buildOutput;
        return respond([
          result.buildSucceeded ? '✓ Build succeeded' : '✗ Build failed',
          buildDisplay ? `Build output:\n${buildDisplay}` : '',
          result.message,
        ].filter(Boolean).join('\n'));
      }

      case 'pth_get_fix_history': {
        const history = await getFixHistory(session.worktreePath);
        if (history.length === 0) return respond('No fix commits on this session branch yet.');
        const lines = history.map(fix =>
          `${fix.commitHash.slice(0, 7)} ${fix.commitTitle}` +
          (fix.trailers['PTH-Test'] ? `\n  Test:     ${fix.trailers['PTH-Test']}` : '') +
          (fix.trailers['PTH-Category'] ? `\n  Category: ${fix.trailers['PTH-Category']}` : '')
        );
        return respond(`${history.length} fix commits:\n\n${lines.join('\n')}`);
      }

      case 'pth_revert_fix': {
        const { commitHash } = args as { commitHash: string };
        // Get original commit title before reverting — for informative confirmation
        const showResult = await run('git', ['show', '-s', '--format=%s', commitHash], { cwd: session.worktreePath });
        const originalTitle = showResult.stdout.trim();
        await revertCommit(session.worktreePath, commitHash);
        const newHash = (await run('git', ['rev-parse', 'HEAD'], { cwd: session.worktreePath })).stdout.trim();
        return respond(
          `Reverted: ${commitHash.slice(0, 7)} — ${originalTitle}\n` +
          `Revert commit: ${newHash.slice(0, 7)}\n` +
          `\nNext: re-run affected tests to verify the revert resolved the regression.`
        );
      }

      case 'pth_diff_session': {
        const diff = await getDiff(session.worktreePath, 'origin/HEAD');
        if (!diff.trim()) return respond('No changes on session branch yet.');
        const diffLines = diff.split('\n');
        const MAX_DIFF_LINES = 200;
        const truncated = diffLines.length > MAX_DIFF_LINES;
        const display = truncated ? diffLines.slice(0, MAX_DIFF_LINES).join('\n') : diff;
        const suffix = truncated
          ? `\n\n[Truncated: showing ${MAX_DIFF_LINES} of ${diffLines.length} lines. Use pth_get_fix_history for a structured summary.]`
          : '';
        return respond(`Session diff (${diffLines.length} lines):\n\n${display}${suffix}`);
      }

      // ── Iteration ──────────────────────────────────────────────────
      case 'pth_get_iteration_status': {
        // Capture a snapshot of the current pass/fail state. Push only when counts differ
        // from the last snapshot — prevents duplicate rows if called multiple times in a row.
        // This is the canonical "end-of-iteration" checkpoint in the test/fix/reload workflow.
        const pass = resultsTracker.getPassCount();
        const fail = resultsTracker.getFailCount();
        const hasResults = pass + fail > 0;
        const lastSnap = mgr.iterationHistory[mgr.iterationHistory.length - 1];
        if (hasResults && (!lastSnap || lastSnap.passing !== pass || lastSnap.failing !== fail)) {
          mgr.iterationHistory.push({ passing: pass, failing: fail, fixesApplied: 0 });
          session.iteration = mgr.iterationHistory.length;
          session.convergenceTrend = detectConvergence(mgr.iterationHistory);
          await writeSessionState(session.worktreePath, session);
        }

        const trend = detectConvergence(mgr.iterationHistory);
        const history = mgr.iterationHistory.map((s, i) =>
          `| ${i + 1} | ${s.passing} | ${s.failing} | ${s.fixesApplied} |`
        ).join('\n');
        const recommendation = trend === 'improving'    ? 'Keep iterating — pass rate is rising.'
          : trend === 'plateaued'   ? 'Try a different fix strategy — pass rate has stalled.'
          : trend === 'oscillating' ? 'Use pth_get_test_impact to find the regressing fix.'
          : trend === 'declining'   ? 'Pass rate is falling — use pth_revert_fix before continuing.'
          : 'Not enough iterations yet to detect a trend.';
        return respond([
          `Iteration: ${session.iteration}    Trend: ${trend}`,
          `Recommendation: ${recommendation}`,
          ``,
          `| Iteration | Passing | Failing | Fixes |`,
          `|-----------|---------|---------|-------|`,
          history || '| — | — | — | — |',
        ].join('\n'));
      }

      default:
        return respond(`Unknown tool: ${toolName}`);
    }
  }
}
