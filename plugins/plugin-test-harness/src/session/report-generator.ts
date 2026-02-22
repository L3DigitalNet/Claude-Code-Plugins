import fs from 'fs/promises';
import path from 'path';
import type { SessionState } from './types.js';
import type { TestResult } from '../results/types.js';

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

// Generates SESSION-REPORT.md content and returns it as a string.
// The caller (server.ts) is responsible for writing it to the appropriate location
// (now ~/.pth/PLUGIN_NAME/sessions/<id>/SESSION-REPORT.md via store-manager).
export function buildReportContent(options: ReportOptions): string {
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
  return lines.join('\n');
}

// Deprecated: use buildReportContent() + write the result yourself.
// Kept for backwards compatibility with any external callers.
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
