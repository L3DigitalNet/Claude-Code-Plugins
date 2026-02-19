import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { writeSessionState, readSessionState } from '../../../src/session/state-persister.js';
import type { SessionState } from '../../../src/session/types.js';

describe('session state persister', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-test-'));
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true });
  });

  const sampleState: SessionState = {
    sessionId: 'test-123',
    branch: 'pth/my-plugin-2026-02-18-abc123',
    worktreePath: '/tmp/pth-worktree-abc123',
    pluginPath: '/home/dev/my-plugin',
    pluginName: 'my-plugin',
    pluginMode: 'mcp',
    startedAt: '2026-02-18T10:00:00Z',
    iteration: 3,
    testCount: 10,
    passingCount: 7,
    failingCount: 3,
    convergenceTrend: 'improving',
    activeFailures: [{ testName: 'test_foo', category: 'runtime-exception' }],
  };

  it('writes and reads back session state', async () => {
    await writeSessionState(tmpDir, sampleState);
    const loaded = await readSessionState(tmpDir);
    expect(loaded).toEqual(sampleState);
  });

  it('returns null when state file does not exist', async () => {
    const result = await readSessionState('/tmp/nonexistent-pth-dir');
    expect(result).toBeNull();
  });
});
