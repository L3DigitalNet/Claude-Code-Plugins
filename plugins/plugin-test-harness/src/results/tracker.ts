// src/results/tracker.ts — in-memory result store, intentionally not persisted.
// Result history is lost on pth_resume_session; convergence trend resets to 'unknown' on resume.
// Tests themselves persist via TestStore.persistToDir() — only result recordings don't survive.
// If persistence is ever added, it must write to worktreePath/.pth/results/ to survive worktree reuse.
import type { TestResult } from '../testing/types.js';

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
}
