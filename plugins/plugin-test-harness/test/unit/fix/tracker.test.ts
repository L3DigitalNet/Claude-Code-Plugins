import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { getFixHistory } from '../../../src/fix/tracker.js';
import { applyFix } from '../../../src/fix/applicator.js';

describe('getFixHistory', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-tracker-test-'));
    const { execa } = await import('execa');
    await execa('git', ['init'], { cwd: tmpDir });
    await execa('git', ['config', 'user.email', 'test@pth.test'], { cwd: tmpDir });
    await execa('git', ['config', 'user.name', 'PTH Test'], { cwd: tmpDir });
    await fs.writeFile(path.join(tmpDir, 'init.ts'), 'const x = 0;\n');
    await execa('git', ['add', '.'], { cwd: tmpDir });
    await execa('git', ['commit', '-m', 'initial'], { cwd: tmpDir });
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true });
  });

  it('returns empty array when no PTH commits exist', async () => {
    const history = await getFixHistory(tmpDir);
    expect(history).toEqual([]);
  });

  it('returns a FixRecord for a commit with PTH trailers', async () => {
    await applyFix({
      worktreePath: tmpDir,
      pluginRelPath: '',
      files: [{ path: 'init.ts', content: 'const x = 1;\n' }],
      commitTitle: 'fix: update x',
      trailers: { 'PTH-Test': 'test_x', 'PTH-Iteration': '1' },
    });

    const history = await getFixHistory(tmpDir);
    expect(history).toHaveLength(1);
    expect(history[0].commitTitle).toBe('fix: update x');
    expect(history[0].trailers['PTH-Test']).toBe('test_x');
    expect(history[0].commitHash).toMatch(/^[a-f0-9]+$/);
    expect(history[0].timestamp).toMatch(/^\d{4}-\d{2}-\d{2}/); // ISO date
  });

  it('excludes commits without PTH trailers', async () => {
    const { execa } = await import('execa');
    await fs.writeFile(path.join(tmpDir, 'other.ts'), 'const y = 1;\n');
    await execa('git', ['add', '.'], { cwd: tmpDir });
    await execa('git', ['commit', '-m', 'chore: non-PTH commit'], { cwd: tmpDir });

    const history = await getFixHistory(tmpDir);
    expect(history).toHaveLength(0);
  });
});
