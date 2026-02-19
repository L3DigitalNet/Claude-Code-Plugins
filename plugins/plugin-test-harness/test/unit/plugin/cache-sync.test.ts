import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { syncToCache, detectCachePath } from '../../../src/plugin/cache-sync.js';

describe('syncToCache', () => {
  it('copies files from worktree to cache dir', async () => {
    const src = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-src-'));
    const dst = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-dst-'));

    await fs.writeFile(path.join(src, 'script.sh'), '#!/bin/bash\necho hello', 'utf-8');

    await syncToCache(src, dst);

    const copied = await fs.readFile(path.join(dst, 'script.sh'), 'utf-8');
    expect(copied).toContain('echo hello');

    await fs.rm(src, { recursive: true });
    await fs.rm(dst, { recursive: true });
  });
});
