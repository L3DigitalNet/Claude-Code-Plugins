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

// Reads ~/.claude/plugins/installed_plugins.json to find the versioned install path
// for a named plugin. Returns null if the file is missing or the plugin is not installed.
// The versioned path (e.g. .../cache/l3digitalnet-plugins/my-plugin/0.1.0) is where the
// running MCP server process lives — different from the legacy non-versioned detectCachePath.
export async function getInstallPath(pluginName: string): Promise<string | null> {
  const installedPluginsPath = path.join(os.homedir(), '.claude', 'plugins', 'installed_plugins.json');
  let raw: string;
  try {
    raw = await fs.readFile(installedPluginsPath, 'utf-8');
  } catch {
    return null;
  }

  let data: { plugins?: Record<string, Array<{ installPath: string }>> };
  try {
    data = JSON.parse(raw) as typeof data;
  } catch {
    return null;
  }

  if (!data.plugins) return null;

  // Key format: "pluginName@marketplace" — search by plugin name prefix.
  const entry = Object.entries(data.plugins).find(([key]) => key.startsWith(pluginName + '@'));
  if (!entry) return null;

  const [, records] = entry;
  return records[0]?.installPath ?? null;
}
