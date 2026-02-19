// src/results/convergence.ts
import type { IterationSnapshot, ConvergenceTrend } from './types.js';

export function detectConvergence(snapshots: IterationSnapshot[]): ConvergenceTrend {
  if (snapshots.length < 2) return 'unknown';

  const recent = snapshots.slice(-3);  // look at last 3 iterations
  const passValues = recent.map(s => s.passing);

  // Plateaued: same pass count for last 2+ snapshots
  const last = passValues[passValues.length - 1];
  const allSame = passValues.every(v => v === last);
  if (allSame && recent.length >= 2) return 'plateaued';

  // Oscillating: pass count goes up then down (or vice versa) repeatedly
  if (passValues.length >= 3) {
    const diffs = passValues.slice(1).map((v, i) => v - passValues[i]);
    const signChanges = diffs.slice(1).filter((d, i) => Math.sign(d) !== Math.sign(diffs[i]) && d !== 0).length;
    if (signChanges >= 2) return 'oscillating';
  }

  // Improving: trend is upward
  const first = passValues[0];
  if (last > first) return 'improving';

  return 'unknown';
}
