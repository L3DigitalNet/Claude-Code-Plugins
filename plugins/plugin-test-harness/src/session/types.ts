export interface SessionState {
  sessionId: string;
  branch: string;
  worktreePath: string;
  pluginPath: string;
  pluginName: string;
  pluginMode: 'mcp' | 'plugin';
  startedAt: string;         // ISO 8601
  iteration: number;
  testCount: number;
  passingCount: number;
  failingCount: number;
  convergenceTrend: 'improving' | 'plateaued' | 'oscillating' | 'unknown';
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
