import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { run, runOrThrow } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';

export async function syncToCache(worktreePath: string, cachePath: string): Promise<void> {
  await fs.mkdir(cachePath, { recursive: true });

  let rsyncResult;
  try {
    rsyncResult = await run('rsync', ['-a', '--delete', `${worktreePath}/`, `${cachePath}/`]);
  } catch (err) {
    // run() throws PTHError(BUILD_FAILED) when the command can't be spawned (rsync not installed)
    if (err instanceof PTHError && err.code === PTHErrorCode.BUILD_FAILED) {
      // rsync not available — fall back to cp
      await runOrThrow('cp', ['-r', `${worktreePath}/.`, cachePath]);
      return;
    }
    throw err;
  }

  if (rsyncResult.exitCode !== 0) {
    // rsync was found but failed — this is a real sync error, not a missing-binary situation
    throw new PTHError(
      PTHErrorCode.CACHE_SYNC_FAILED,
      `rsync failed (exit ${rsyncResult.exitCode})`,
      { stderr: rsyncResult.stderr }
    );
  }
}

export function detectCachePath(pluginName: string): string {
  return path.join(os.homedir(), '.claude', 'plugins', 'cache', pluginName);
}
