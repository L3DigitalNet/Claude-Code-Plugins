import { ResultsTracker } from '../../../src/results/tracker.js';
import { detectConvergence } from '../../../src/results/convergence.js';

describe('ResultsTracker', () => {
  it('records a passing result and updates counts', () => {
    const tracker = new ResultsTracker();
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'passing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    expect(tracker.getPassCount()).toBe(1);
    expect(tracker.getFailCount()).toBe(0);
  });

  it('tracks result history per test across iterations', () => {
    const tracker = new ResultsTracker();
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'failing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'passing',
                     iteration: 2, recordedAt: new Date().toISOString() });
    const history = tracker.getHistory('test_a');
    expect(history).toHaveLength(2);
    expect(history[1].status).toBe('passing');
  });
});

describe('detectConvergence', () => {
  it('returns improving when pass count is rising', () => {
    const trend = detectConvergence([
      { passing: 5, failing: 5 },
      { passing: 7, failing: 3 },
      { passing: 9, failing: 1 },
    ]);
    expect(trend).toBe('improving');
  });

  it('returns plateaued when pass count is unchanged for 2+ iterations', () => {
    const trend = detectConvergence([
      { passing: 5, failing: 5 },
      { passing: 7, failing: 3 },
      { passing: 7, failing: 3 },
      { passing: 7, failing: 3 },
    ]);
    expect(trend).toBe('plateaued');
  });

  it('returns unknown with fewer than 2 data points', () => {
    expect(detectConvergence([{ passing: 3, failing: 7 }])).toBe('unknown');
  });
});
