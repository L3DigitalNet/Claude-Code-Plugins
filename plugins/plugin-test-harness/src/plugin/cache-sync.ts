import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { run, runOrThrow } from '../shared/exec.js';

export async function syncToCache(worktreePath: string, cachePath: string): Promise<void> {
  await fs.mkdir(cachePath, { recursive: true });
  // Use rsync for efficient sync; fall back to cp -r if rsync is not available
  const rsyncResult = await run('rsync', ['-a', '--delete', `${worktreePath}/`, `${cachePath}/`]);
  if (rsyncResult.exitCode !== 0) {
    // rsync failed — check if it's a "command not found" situation or a real error
    // Use cp -r as fallback only when rsync is not installed (ENOENT-like)
    if (rsyncResult.stderr.includes('No such file or directory') ||
        rsyncResult.stderr.includes('command not found') ||
        rsyncResult.exitCode === 127) {
      await runOrThrow('cp', ['-r', `${worktreePath}/.`, cachePath]);
    } else {
      // rsync found but failed — propagate the error
      throw new Error(`rsync failed (exit ${rsyncResult.exitCode}): ${rsyncResult.stderr}`);
    }
  }
}

export function detectCachePath(pluginName: string): string {
  return path.join(os.homedir(), '.claude', 'plugins', 'cache', pluginName);
}
