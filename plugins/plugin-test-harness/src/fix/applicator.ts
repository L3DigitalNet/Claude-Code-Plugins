import fs from 'fs/promises';
import path from 'path';
import { commitFiles } from '../session/git.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { FixRequest } from './types.js';

export async function applyFix(request: FixRequest): Promise<string> {
  if (request.files.length === 0) {
    throw new PTHError(PTHErrorCode.INVALID_PLUGIN, 'applyFix requires at least one file change');
  }

  // Write all file changes, creating parent directories as needed.
  // Files are relative to the plugin root; prepend pluginRelPath to resolve
  // within the worktree (which is the git repo root, not the plugin dir).
  const worktreeRelPaths: string[] = [];
  for (const file of request.files) {
    const fullPath = path.join(request.worktreePath, request.pluginRelPath, file.path);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, file.content, 'utf-8');
    worktreeRelPaths.push(path.join(request.pluginRelPath, file.path));
  }

  // Build commit message with PTH trailers
  const trailerLines = Object.entries(request.trailers)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n');
  const message = trailerLines
    ? `${request.commitTitle}\n\n${trailerLines}`
    : request.commitTitle;

  // Stage ONLY the specific changed files — avoids including .pth/session-state.json
  // (always dirty during active sessions) in fix commits, which would cause conflicts
  // when later reverting those commits via pth_revert_fix.
  return commitFiles(request.worktreePath, worktreeRelPaths, message);
}
