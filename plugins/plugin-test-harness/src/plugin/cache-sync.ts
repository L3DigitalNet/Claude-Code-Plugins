import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { run, runOrThrow } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';

// Returns the number of files synced (0 for cp fallback where count is unavailable).
export async function syncToCache(worktreePath: string, cachePath: string): Promise<number> {
  await fs.mkdir(cachePath, { recursive: true });

  let rsyncResult;
  try {
    // --out-format="%n" prints one line per transferred file — count lines to get file count
    rsyncResult = await run('rsync', ['-a', '--delete', '--out-format=%n', `${worktreePath}/`, `${cachePath}/`]);
  } catch (err) {
    // run() throws PTHError(BUILD_FAILED) when the command can't be spawned (rsync not installed)
    if (err instanceof PTHError && err.code === PTHErrorCode.BUILD_FAILED) {
      // rsync not available — fall back to cp; file count is unavailable
      await runOrThrow('cp', ['-r', `${worktreePath}/.`, cachePath]);
      return 0;
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

  // Count non-empty lines — each represents one file transferred
  return rsyncResult.stdout.split('\n').filter(l => l.trim()).length;
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
