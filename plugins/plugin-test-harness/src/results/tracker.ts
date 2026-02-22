// src/results/tracker.ts — in-memory result store for the active session.
// exportHistory() serializes the latest result per test for persistence to ~/.pth/PLUGIN_NAME/
// by store-manager.appendResults(). Full in-session result history (per-iteration recordings)
// is still in-memory only and resets on resume — only the final status per test is persisted.
import type { TestResult } from '../testing/types.js';
import type { ExportedResults } from '../persistence/types.js';

export class ResultsTracker {
  private results: Map<string, TestResult[]> = new Map();  // testId -> history

  record(result: TestResult): void {
    const history = this.results.get(result.testId) ?? [];
    history.push(result);
    this.results.set(result.testId, history);
  }

  getHistory(testId: string): TestResult[] {
    return this.results.get(testId) ?? [];
  }

  getLatest(testId: string): TestResult | undefined {
    const history = this.getHistory(testId);
    return history[history.length - 1];
  }

  getPassCount(): number {
    let count = 0;
    for (const [testId] of this.results) {
      const latest = this.getLatest(testId);
      if (latest?.status === 'passing') count++;
    }
    return count;
  }

  getFailCount(): number {
    let count = 0;
    for (const [testId] of this.results) {
      const latest = this.getLatest(testId);
      if (latest?.status === 'failing') count++;
    }
    return count;
  }

  getFailingTests(): TestResult[] {
    const failing: TestResult[] = [];
    for (const [testId] of this.results) {
      const latest = this.getLatest(testId);
      if (latest?.status === 'failing') failing.push(latest);
    }
    return failing;
  }

  getAllLatest(): TestResult[] {
    return Array.from(this.results.keys())
      .map(id => this.getLatest(id))
      .filter((r): r is TestResult => r !== undefined);
  }

  // Export per-test latest status for persistence to ~/.pth/PLUGIN_NAME/results-history.json.
  // Called by server.ts at pth_end_session and passed to EndSessionOptions.exportedResults.
  exportHistory(store: { get(id: string): { name: string } | undefined }): ExportedResults[] {
    const results: ExportedResults[] = [];
    for (const testId of this.results.keys()) {
      const latest = this.getLatest(testId);
      results.push({
        testId,
        testName: store.get(testId)?.name ?? testId,
        latestStatus: latest?.status ?? 'pending',
        latestResult: latest,
      });
    }
    return results;
  }
}
