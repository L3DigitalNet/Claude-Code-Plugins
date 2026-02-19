import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { applyFix } from '../../../src/fix/applicator.js';

describe('applyFix', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-fix-test-'));
    // init git repo in tmp dir
    const { execa } = await import('execa');
    await execa('git', ['init'], { cwd: tmpDir });
    await execa('git', ['config', 'user.email', 'test@pth.test'], { cwd: tmpDir });
    await execa('git', ['config', 'user.name', 'PTH Test'], { cwd: tmpDir });
    // create initial file
    await fs.writeFile(path.join(tmpDir, 'src.ts'), 'const x = 1;\n');
    await execa('git', ['add', '.'], { cwd: tmpDir });
    await execa('git', ['commit', '-m', 'initial'], { cwd: tmpDir });
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true });
  });

  it('writes a file change and creates a commit with PTH trailers', async () => {
    const commitHash = await applyFix({
      worktreePath: tmpDir,
      files: [{ path: 'src.ts', content: 'const x = 2;\n' }],
      commitTitle: 'fix: update value',
      trailers: {
        'PTH-Test': 'my_test',
        'PTH-Iteration': '1',
      },
    });

    const content = await fs.readFile(path.join(tmpDir, 'src.ts'), 'utf-8');
    expect(content).toBe('const x = 2;\n');
    expect(commitHash).toMatch(/^[a-f0-9]+$/);
  });
});
