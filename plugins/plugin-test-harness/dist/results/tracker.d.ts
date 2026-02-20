import type { TestResult } from '../testing/types.js';
export declare class ResultsTracker {
    private results;
    record(result: TestResult): void;
    getHistory(testId: string): TestResult[];
    getLatest(testId: string): TestResult | undefined;
    getPassCount(): number;
    getFailCount(): number;
    getFailingTests(): TestResult[];
    getAllLatest(): TestResult[];
}
//# sourceMappingURL=tracker.d.ts.map