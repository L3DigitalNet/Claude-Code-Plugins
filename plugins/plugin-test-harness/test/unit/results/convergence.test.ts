// convergence.test.ts — [P5] Convergence is the Contract.
// Trend math is the load-bearing algorithm: agents make iteration decisions
// from the returned trend value. Each documented branch must have one explicit test.

import { detectConvergence } from '../../../src/results/convergence.js';
import type { IterationSnapshot } from '../../../src/results/types.js';

const snap = (passing: number, failing = 0): IterationSnapshot => ({ passing, failing });

describe('detectConvergence', () => {
  it('returns "unknown" with fewer than 2 snapshots (CV-unknown)', () => {
    expect(detectConvergence([])).toBe('unknown');
    expect(detectConvergence([snap(5)])).toBe('unknown');
  });

  it('returns "improving" when pass count rises monotonically (CV-improving)', () => {
    const trend = detectConvergence([snap(2), snap(5), snap(8)]);
    expect(trend).toBe('improving');
  });

  it('returns "declining" when pass count falls (CV-declining)', () => {
    const trend = detectConvergence([snap(8), snap(5), snap(2)]);
    expect(trend).toBe('declining');
  });

  it('returns "plateaued" when last 3 snapshots all equal (CV-plateau)', () => {
    const trend = detectConvergence([snap(2), snap(7), snap(7), snap(7)]);
    expect(trend).toBe('plateaued');
  });

  it('returns "plateaued" with just 2 equal recent values (CV-plateau-2)', () => {
    // Plateau threshold is plateau.length >= 2 with all values equal to last.
    const trend = detectConvergence([snap(7), snap(7)]);
    expect(trend).toBe('plateaued');
  });

  it('returns "oscillating" with 2+ sign changes in the window (CV-oscillating)', () => {
    // Pass counts: 5 -> 8 -> 3 -> 9 yields diffs +3, -5, +6 (two sign changes).
    const trend = detectConvergence([snap(5), snap(8), snap(3), snap(9)]);
    expect(trend).toBe('oscillating');
  });

  it('window is last 4 snapshots — older history ignored (CV-window)', () => {
    // First 3 snapshots oscillate dramatically, but only the last 4 matter.
    // Last 4 = [10, 11, 12, 13] which is improving.
    const trend = detectConvergence([
      snap(99),
      snap(1),
      snap(99),
      snap(10),
      snap(11),
      snap(12),
      snap(13),
    ]);
    expect(trend).toBe('improving');
  });

  it('flat-but-not-plateau-length: 1 vs 2 returns improving/declining (CV-flat-pair)', () => {
    // Two snapshots with last > first: improving.
    expect(detectConvergence([snap(3), snap(7)])).toBe('improving');
    // Two snapshots with last < first: declining.
    expect(detectConvergence([snap(7), snap(3)])).toBe('declining');
  });
});
