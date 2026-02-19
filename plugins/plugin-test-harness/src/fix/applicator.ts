import fs from 'fs/promises';
import path from 'path';
import { commitAll } from '../session/git.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { FixRequest } from './types.js';

export async function applyFix(request: FixRequest): Promise<string> {
  if (request.files.length === 0) {
    throw new PTHError(PTHErrorCode.INVALID_PLUGIN, 'applyFix requires at least one file change');
  }

  // Write all file changes, creating parent directories as needed
  for (const file of request.files) {
    const fullPath = path.join(request.worktreePath, file.path);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, file.content, 'utf-8');
  }

  // Build commit message with PTH trailers
  const trailerLines = Object.entries(request.trailers)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n');
  const message = trailerLines
    ? `${request.commitTitle}\n\n${trailerLines}`
    : request.commitTitle;

  return commitAll(request.worktreePath, message);
}
