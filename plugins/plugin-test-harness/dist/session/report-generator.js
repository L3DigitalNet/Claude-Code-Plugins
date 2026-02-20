import fs from 'fs/promises';
import path from 'path';
export async function generateReport(worktreePath, options) {
    const { state, iterationHistory } = options;
    const lines = [
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
        ...iterationHistory.map(h => `| ${h.iteration} | ${h.passing} | ${h.failing} | ${h.fixesApplied} |`),
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
//# sourceMappingURL=report-generator.js.map