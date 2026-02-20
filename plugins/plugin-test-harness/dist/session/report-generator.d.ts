import type { SessionState } from './types.js';
interface TestResult {
    testId: string;
    testName: string;
    status: 'pending' | 'passing' | 'failing' | 'skipped';
    iteration: number;
    durationMs?: number;
    failureReason?: string;
    claudeNotes?: string;
    recordedAt: string;
}
export interface ReportOptions {
    state: SessionState;
    allResults: TestResult[];
    iterationHistory: IterationSummary[];
}
export interface IterationSummary {
    iteration: number;
    passing: number;
    failing: number;
    fixesApplied: number;
}
export declare function generateReport(worktreePath: string, options: ReportOptions): Promise<void>;
export {};
//# sourceMappingURL=report-generator.d.ts.map