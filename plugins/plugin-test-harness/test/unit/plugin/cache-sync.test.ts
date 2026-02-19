import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { syncToCache, detectCachePath } from '../../../src/plugin/cache-sync.js';

describe('syncToCache', () => {
  let src: string;
  let dst: string;

  beforeEach(async () => {
    src = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-src-'));
    dst = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-dst-'));
  });

  afterEach(async () => {
    await fs.rm(src, { recursive: true, force: true });
    await fs.rm(dst, { recursive: true, force: true });
  });

  it('copies files from worktree to cache dir', async () => {
    await fs.writeFile(path.join(src, 'script.sh'), '#!/bin/bash\necho hello', 'utf-8');
    await syncToCache(src, dst);
    const copied = await fs.readFile(path.join(dst, 'script.sh'), 'utf-8');
    expect(copied).toContain('echo hello');
  });
});
