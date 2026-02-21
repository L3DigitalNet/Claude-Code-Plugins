import { z } from 'zod';

export interface ToolDef {
  name: string;
  description: string;
  inputSchema: z.ZodTypeAny;
}

// ── Dormant tools ──────────────────────────────────────────────

const dormantTools: ToolDef[] = [
  {
    name: 'pth_preflight',
    description: 'Validate prerequisites before starting a PTH session: check plugin path, git repo, build system, no active session lock.',
    inputSchema: z.object({
      pluginPath: z.string().describe('Absolute path to the target plugin'),
    }),
  },
  {
    name: 'pth_start_session',
    description: 'Start a PTH session: create session branch + worktree, detect plugin mode (mcp or plugin), analyze source, load existing tests if present.',
    inputSchema: z.object({
      pluginPath: z.string().describe('Absolute path to the target plugin'),
      sessionNote: z.string().optional().describe('Optional human note about what this session aims to test'),
    }),
  },
  {
    name: 'pth_resume_session',
    description: 'Resume an interrupted PTH session from an existing session branch.',
    inputSchema: z.object({
      branch: z.string().describe('Session branch name, e.g. pth/my-plugin-2026-02-18-abc123'),
      pluginPath: z.string().describe('Absolute path to the target plugin'),
    }),
  },
];

// ── Session tools ──────────────────────────────────────────────

const sessionTools: ToolDef[] = [
  // Management
  {
    name: 'pth_end_session',
    description: 'End the PTH session: persist tests to .pth/tests/, generate SESSION-REPORT.md, remove worktree, deactivate session tools.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_get_session_status',
    description: 'Get current session status: iteration count, passing/failing counts, convergence trend, session metadata.',
    inputSchema: z.object({}),
  },
  // Tests
  {
    name: 'pth_generate_tests',
    description: 'Generate test proposals for the target plugin from available signals (tool schemas, source analysis, manifest). Returns YAML test definitions for review.',
    inputSchema: z.object({
      toolSchemas: z.array(z.unknown()).optional().describe('Tool schemas from the target plugin (paste tools/list output here for MCP plugins)'),
      includeEdgeCases: z.boolean().optional().default(true),
    }),
  },
  {
    name: 'pth_list_tests',
    description: 'List tests in the current suite with optional filtering.',
    inputSchema: z.object({
      mode: z.enum(['mcp', 'plugin']).optional(),
      status: z.enum(['passing', 'failing', 'pending']).optional(),
      tag: z.string().optional(),
      generatedFrom: z.string().optional(),
    }),
  },
  {
    name: 'pth_create_test',
    description: 'Add a new test to the suite.',
    inputSchema: z.object({
      yaml: z.string().describe('YAML test definition'),
    }),
  },
  {
    name: 'pth_edit_test',
    description: 'Update an existing test definition.',
    inputSchema: z.object({
      testId: z.string(),
      yaml: z.string().describe('New YAML test definition'),
    }),
  },
  // Execution
  {
    name: 'pth_record_result',
    description: "Record the result of a test after Claude has executed it. Call this after calling the target plugin's tool and evaluating the assertion.",
    inputSchema: z.object({
      testId: z.string(),
      status: z.enum(['passing', 'failing', 'skipped']),
      durationMs: z.number().optional(),
      failureReason: z.string().optional().describe('What went wrong, if failing'),
      claudeNotes: z.string().optional().describe("Claude's observations about this test result"),
    }),
  },
  {
    name: 'pth_get_results',
    description: 'Get the current pass/fail status of all tests in the suite.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_get_test_impact',
    description: 'Show which tests exercise code in the specified source files (for targeted re-runs after a fix).',
    inputSchema: z.object({
      files: z.array(z.string()).describe('Source file paths relative to plugin root'),
    }),
  },
  // Fixes
  {
    name: 'pth_apply_fix',
    description: 'Apply a code fix: write file changes and commit to session branch with PTH trailers.',
    inputSchema: z.object({
      files: z.array(z.object({
        path: z.string().describe('File path relative to plugin root'),
        content: z.string().describe('Full new file content'),
      })).min(1, 'At least one file change is required'),
      commitTitle: z.string().describe('Git commit title, e.g. "fix: handle null group"'),
      testId: z.string().optional().describe('ID of the test this fix addresses'),
      category: z.string().optional().describe('Failure category, e.g. "runtime-exception"'),
    }),
  },
  {
    name: 'pth_sync_to_cache',
    description: 'Sync worktree changes to the plugin cache directory so hook script changes take effect immediately.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_reload_plugin',
    description: 'Rebuild the MCP plugin and terminate its process so Claude Code restarts it with the new build.',
    inputSchema: z.object({
      processPattern: z.string().optional().describe('Optional pattern to find the MCP server process in ps output. Defaults to plugin dist path.'),
    }),
  },
  {
    name: 'pth_get_fix_history',
    description: 'View all fix commits on the session branch with their PTH trailers.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_revert_fix',
    description: 'Undo a specific fix commit via git revert.',
    inputSchema: z.object({
      commitHash: z.string().regex(/^[0-9a-f]{7,40}$/i, 'commitHash must be a valid git SHA (7–40 hex characters)'),
    }),
  },
  {
    name: 'pth_diff_session',
    description: 'Show cumulative diff of all changes on the session branch vs the branch point.',
    inputSchema: z.object({}),
  },
  // Iteration
  {
    name: 'pth_get_iteration_status',
    description: 'Get iteration number, per-test pass/fail history, and convergence trend (improving, plateaued, oscillating).',
    inputSchema: z.object({}),
  },
];

// All tools are always exposed — Claude Code caches the tool list at session start,
// so dynamic activation via notifications/tools/list_changed is unreliable.
// Session-gating is enforced at dispatch time (server.ts default case).
export class ToolRegistry {
  getAllTools(): ToolDef[] {
    return [...dormantTools, ...sessionTools];
  }

  // Kept for API compatibility; no-ops now that gating is runtime-only.
  activate(): void {}
  deactivate(): void {}
  isActive(): boolean { return true; }
}
