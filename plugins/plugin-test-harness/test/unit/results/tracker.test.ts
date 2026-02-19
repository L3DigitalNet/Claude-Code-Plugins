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

  it('getLatest returns undefined for unknown testId', () => {
    const tracker = new ResultsTracker();
    expect(tracker.getLatest('nonexistent')).toBeUndefined();
  });

  it('getFailingTests returns only the latest failing results', () => {
    const tracker = new ResultsTracker();
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'failing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    tracker.record({ testId: 'test_b', testName: 'test_b', status: 'passing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    const failing = tracker.getFailingTests();
    expect(failing).toHaveLength(1);
    expect(failing[0].testId).toBe('test_a');
  });

  it('getAllLatest returns the latest result for each test', () => {
    const tracker = new ResultsTracker();
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'failing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'passing',
                     iteration: 2, recordedAt: new Date().toISOString() });
    tracker.record({ testId: 'test_b', testName: 'test_b', status: 'failing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    const latest = tracker.getAllLatest();
    expect(latest).toHaveLength(2);
    const testA = latest.find(r => r.testId === 'test_a');
    expect(testA?.status).toBe('passing');
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

  it('returns oscillating when pass count reverses direction twice', () => {
    const trend = detectConvergence([
      { passing: 5, failing: 5 },
      { passing: 8, failing: 2 },
      { passing: 5, failing: 5 },
      { passing: 8, failing: 2 },
    ]);
    expect(trend).toBe('oscillating');
  });
});
