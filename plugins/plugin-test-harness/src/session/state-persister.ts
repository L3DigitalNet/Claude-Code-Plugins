import fs from 'fs/promises';
import path from 'path';
import type { SessionState } from './types.js';

const STATE_FILE = '.pth/session-state.json';

export async function writeSessionState(worktreePath: string, state: SessionState): Promise<void> {
  const dir = path.join(worktreePath, '.pth');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(
    path.join(worktreePath, STATE_FILE),
    JSON.stringify(state, null, 2),
    'utf-8'
  );
}

export async function readSessionState(worktreePath: string): Promise<SessionState | null> {
  const filePath = path.join(worktreePath, STATE_FILE);
  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(raw) as SessionState;
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw err;  // propagate parse errors and permission errors
  }
}
