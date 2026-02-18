import fs from 'fs/promises';
import path from 'path';
import type { SessionState } from './types.js';

// Inline minimal TestResult type — full type created in Task 7 (src/results/types.ts)
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

export async function generateReport(worktreePath: string, options: ReportOptions): Promise<void> {
  const { state, iterationHistory } = options;
  const lines: string[] = [
    `# PTH Session Report`,
    ``,
    `**Plugin:** ${state.pluginName}`,
    `**Mode:** ${state.pluginMode}`,
    `**Branch:** ${state.branch}`,
    `**Started:** ${state.startedAt}`,
    `**Ended:** ${new Date().toISOString()}`,
    `**Total Iterations:** ${state.iteration}`,
    ``,
    `## Test Results`,
    ``,
    `| Tests | Passing | Failing |`,
    `|-------|---------|---------|`,
    `| ${state.testCount} | ${state.passingCount} | ${state.failingCount} |`,
    ``,
    `## Convergence`,
    ``,
    `| Iteration | Passing | Failing | Fixes Applied |`,
    `|-----------|---------|---------|---------------|`,
    ...iterationHistory.map(h =>
      `| ${h.iteration} | ${h.passing} | ${h.failing} | ${h.fixesApplied} |`
    ),
    ``,
    `## Status`,
    ``,
    state.failingCount === 0
      ? `All ${state.testCount} tests passing.`
      : `${state.failingCount} tests still failing at session end.`,
  ];

  const dir = path.join(worktreePath, '.pth');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(worktreePath, '.pth/SESSION-REPORT.md'), lines.join('\n'), 'utf-8');
}
