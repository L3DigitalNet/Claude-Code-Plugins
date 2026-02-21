export type TestMode = 'mcp' | 'plugin';
export type TestType = 'single' | 'scenario' | 'hook-script' | 'validate' | 'exec';

export interface SessionState {
  sessionId: string;
  branch: string;
  worktreePath: string;
  pluginPath: string;
  pluginName: string;
  pluginMode: 'mcp' | 'plugin';
  // Relative path from the git repo root to the plugin directory.
  // Empty string when the plugin is at the repo root.
  // Used to resolve file paths in pth_apply_fix, pth_sync_to_cache, and pth_reload_plugin.
  pluginRelPath: string;
  startedAt: string;         // ISO 8601
  iteration: number;
  testCount: number;
  passingCount: number;
  failingCount: number;
  convergenceTrend: 'improving' | 'plateaued' | 'oscillating' | 'declining' | 'unknown';
  activeFailures: ActiveFailure[];
}

export interface ActiveFailure {
  testName: string;
  category: string;
  lastDiagnosisSummary?: string;
}

export interface FixCommitTrailers {
  'PTH-Test'?: string;
  'PTH-Category'?: string;
  'PTH-Files'?: string;
  'PTH-Iteration'?: string;
  'PTH-Type'?: string;        // 'fix' | 'state-checkpoint' | 'session-end'
}
