export interface SessionState {
    sessionId: string;
    branch: string;
    worktreePath: string;
    pluginPath: string;
    pluginName: string;
    pluginMode: 'mcp' | 'plugin';
    startedAt: string;
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
    'PTH-Type'?: string;
}
//# sourceMappingURL=types.d.ts.map