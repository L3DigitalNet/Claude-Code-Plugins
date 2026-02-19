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
import { reloadPlugin } from './plugin/reloader.js';
import { writeSessionState } from './session/state-persister.js';
import { writeToolSchemasCache } from './shared/source-analyzer.js';
import type { ToolSchema } from './shared/source-analyzer.js';
import * as mgr from './session/manager.js';

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

  // Dynamic tool list
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: registry.getActiveTools().map(t => ({
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
    // Lazy import session manager
    if (!sessionManager) {
      sessionManager = await import('./session/manager.js');
    }

    const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });

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
        registry.activate();
        try { await server.notification({ method: 'notifications/tools/list_changed' }); } catch { /* best-effort */ }
        return respond(result.message);
      }
      case 'pth_resume_session': {
        const result = await sessionManager.resumeSession(
          args as { branch: string; pluginPath: string }
        );
        currentSession = result.state;
        resultsTracker = new ResultsTracker();  // fresh tracker for resumed session
        registry.activate();
        try { await server.notification({ method: 'notifications/tools/list_changed' }); } catch { /* best-effort */ }
        return respond(result.message);
      }
      case 'pth_end_session': {
        if (!currentSession) return respond('No active session.');
        const result = await sessionManager.endSession(currentSession);
        currentSession = null;
        registry.deactivate();
        try { await server.notification({ method: 'notifications/tools/list_changed' }); } catch { /* best-effort */ }
        return respond(result);
      }
      default: {
        // fix #3: guard on currentSession (not registry.isActive()) — eliminates ! assertion
        if (!currentSession) {
          return respond(`No PTH session active. Call pth_start_session first.`);
        }
        // Delegate to session handlers
        return handleSessionTool(toolName, args, currentSession);
      }
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
          `Session: ${session.branch}`,
          `Mode:     ${session.pluginMode}`,
          `Iteration: ${session.iteration}`,
          `Tests:    ${store.count()} total, ${pass} passing, ${fail} failing`,
          `Trend:    ${trend}`,
          `Started:  ${session.startedAt}`,
        ].join('\n'));
      }

      // ── Tests ──────────────────────────────────────────────────────
      case 'pth_generate_tests': {
        const { toolSchemas } = args as { toolSchemas?: ToolSchema[] };
        let tests;
        if (session.pluginMode === 'mcp' && toolSchemas) {
          await writeToolSchemasCache(session.worktreePath, toolSchemas);
          tests = await generateMcpTests({ pluginPath: session.worktreePath, toolSchemas });
        } else {
          tests = generatePluginTests([]);
        }
        tests.forEach(t => store.add(t));
        return respond(`Generated ${tests.length} tests.\n\n${tests.map(t => `- ${t.name}`).join('\n')}`);
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
        return respond(`${tests.length} tests:\n\n${lines.join('\n')}`);
      }

      case 'pth_create_test': {
        const { yaml } = args as { yaml: string };
        const test = parseTest(yaml);
        store.add(test);
        return respond(`Test added: ${test.name} (id: ${test.id})`);
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

        return respond(`Recorded: ${test.name} → ${status}${failureReason ? ` (${failureReason})` : ''}`);
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
          files,
          commitTitle,
          trailers,
        });
        return respond(`Fix committed: ${hash}\n${commitTitle}\nFiles: ${files.map(f => f.path).join(', ')}`);
      }

      case 'pth_sync_to_cache': {
        const { syncToCache, detectCachePath } = await import('./plugin/cache-sync.js');
        const cachePath = detectCachePath(session.pluginName);
        try {
          await syncToCache(session.worktreePath, cachePath);
          return respond(`Synced worktree to cache: ${cachePath}\nHook script changes are now live.`);
        } catch (e) {
          return respond(`Cache sync failed: ${(e as Error).message}\nCache path: ${cachePath}`);
        }
      }

      case 'pth_reload_plugin': {
        const { detectBuildSystem } = await import('./plugin/detector.js');
        const buildSystem = await detectBuildSystem(session.worktreePath);
        const { processPattern } = args as { processPattern?: string };
        const pattern = processPattern ?? session.worktreePath;
        const result = await reloadPlugin(session.worktreePath, buildSystem, pattern);
        return respond([
          result.buildSucceeded ? '✓ Build succeeded' : '✗ Build failed',
          result.buildOutput ? `Build output:\n${result.buildOutput}` : '',
          result.message,
        ].filter(Boolean).join('\n'));
      }

      case 'pth_get_fix_history': {
        const history = await getFixHistory(session.worktreePath);
        if (history.length === 0) return respond('No fix commits on this session branch yet.');
        const lines = history.map(fix =>
          `${fix.commitHash.slice(0, 7)} ${fix.commitTitle}` +
          (fix.trailers['PTH-Test'] ? `\n  Test: ${fix.trailers['PTH-Test']}` : '') +
          (fix.trailers['PTH-Category'] ? ` | ${fix.trailers['PTH-Category']}` : '')
        );
        return respond(`${history.length} fix commits:\n\n${lines.join('\n')}`);
      }

      case 'pth_revert_fix': {
        const { commitHash } = args as { commitHash: string };
        await revertCommit(session.worktreePath, commitHash);
        return respond(`Reverted commit ${commitHash}. Changes undone and a new revert commit added.`);
      }

      case 'pth_diff_session': {
        const diff = await getDiff(session.worktreePath, 'origin/HEAD');
        if (!diff.trim()) return respond('No changes on session branch yet.');
        return respond(`Session diff (${diff.split('\n').length} lines):\n\n${diff}`);
      }

      // ── Iteration ──────────────────────────────────────────────────
      case 'pth_get_iteration_status': {
        const snapshots = mgr.iterationHistory;
        const trend = detectConvergence(snapshots);
        const history = snapshots.map((s, i) =>
          `| ${i + 1} | ${s.passing} | ${s.failing} | ${s.fixesApplied} |`
        ).join('\n');
        return respond([
          `Iteration ${session.iteration} | Trend: ${trend}`,
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
