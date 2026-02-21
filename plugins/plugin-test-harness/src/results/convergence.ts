// src/results/convergence.ts
import type { IterationSnapshot, ConvergenceTrend } from './types.js';

export function detectConvergence(snapshots: IterationSnapshot[]): ConvergenceTrend {
  if (snapshots.length < 2) return 'unknown';

  const recent = snapshots.slice(-4);  // look at last 4 iterations
  const passValues = recent.map(s => s.passing);

  // Plateaued: last 3 values (or all, if fewer) equal the final value
  const last = passValues[passValues.length - 1];
  const plateau = passValues.slice(-3);
  const allSame = plateau.every(v => v === last);
  if (allSame && plateau.length >= 2) return 'plateaued';

  // Oscillating: direction reverses 2+ times in the window
  if (passValues.length >= 3) {
    const diffs = passValues.slice(1).map((v, i) => v - passValues[i]);
    const signChanges = diffs.slice(1).filter((d, i) => Math.sign(d) !== Math.sign(diffs[i]) && d !== 0).length;
    if (signChanges >= 2) return 'oscillating';
  }

  // Improving: trend is upward overall
  const first = passValues[0];
  if (last > first) return 'improving';

  // Declining trend: pass rate fell from first to last snapshot in the window.
  if (last < first) return 'declining';

  return 'unknown';
}
