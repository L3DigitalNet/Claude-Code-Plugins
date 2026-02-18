import { randomBytes } from 'crypto';
import { run, runOrThrow } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import { warn } from '../shared/logger.js';
import type { FixCommitTrailers } from './types.js';

export function generateSessionBranch(pluginName: string): string {
  const date = new Date().toISOString().slice(0, 10);
  const hash = randomBytes(3).toString('hex');
  const safeName = pluginName.replace(/[^a-z0-9-]/gi, '-').toLowerCase();
  return `pth/${safeName}-${date}-${hash}`;
}

export function buildCommitMessage(title: string, trailers: FixCommitTrailers): string {
  const trailerLines = Object.entries(trailers as Record<string, string | undefined>)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n');
  return trailerLines ? `${title}\n\n${trailerLines}` : title;
}

export function parseTrailers(commitMessage: string): Record<string, string> {
  const result: Record<string, string> = {};
  const lines = commitMessage.split('\n');
  for (const line of lines) {
    const match = line.match(/^(PTH-[A-Za-z]+):\s*(.+)$/);
    if (match) {
      result[match[1]] = match[2].trim();
    }
  }
  return result;
}

export async function createBranch(repoPath: string, branchName: string): Promise<void> {
  try {
    await runOrThrow('git', ['checkout', '-b', branchName], { cwd: repoPath });
  } catch (err) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Failed to create branch: ${branchName}`, {
      cause: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function checkBranchExists(repoPath: string, branchName: string): Promise<boolean> {
  const result = await run('git', ['rev-parse', '--verify', branchName], { cwd: repoPath });
  return result.exitCode === 0;
}

export async function addWorktree(repoPath: string, worktreePath: string, branch: string): Promise<void> {
  try {
    await runOrThrow('git', ['worktree', 'add', worktreePath, branch], { cwd: repoPath });
  } catch (err) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Failed to add worktree at: ${worktreePath}`, {
      cause: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function removeWorktree(repoPath: string, worktreePath: string): Promise<void> {
  const result = await run('git', ['worktree', 'remove', '--force', worktreePath], { cwd: repoPath });
  if (result.exitCode !== 0) {
    warn(`git worktree remove failed (exit ${result.exitCode}): ${result.stderr}`);
  }
}

export async function pruneWorktrees(repoPath: string): Promise<void> {
  await run('git', ['worktree', 'prune'], { cwd: repoPath });
}

export async function commitAll(
  worktreePath: string,
  message: string
): Promise<string> {
  try {
    await run('git', ['add', '-A'], { cwd: worktreePath });
    const result = await runOrThrow('git', ['commit', '-m', message], { cwd: worktreePath });
    // extract commit hash from output: "[branch abc1234] ..."
    const match = result.stdout.match(/\[[\w/.-]+ ([a-f0-9]+)\]/);
    if (!match?.[1]) {
      throw new PTHError(PTHErrorCode.GIT_ERROR, `Could not extract commit hash from git output: ${result.stdout}`);
    }
    return match[1];
  } catch (err) {
    if (err instanceof PTHError) throw err;
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Failed to commit changes in: ${worktreePath}`, {
      cause: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function getLog(
  worktreePath: string,
  options?: { since?: string; maxCount?: number }
): Promise<string> {
  try {
    const args = ['log', '--format=%H %s%n%b'];
    if (options?.maxCount) args.push(`-n${options.maxCount}`);
    if (options?.since) args.push(`${options.since}..HEAD`);
    const result = await runOrThrow('git', args, { cwd: worktreePath });
    return result.stdout;
  } catch (err) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Failed to get git log in: ${worktreePath}`, {
      cause: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function getDiff(
  worktreePath: string,
  base: string
): Promise<string> {
  const result = await run('git', ['diff', base], { cwd: worktreePath });
  return result.stdout;
}

export async function revertCommit(
  worktreePath: string,
  commitHash: string
): Promise<void> {
  try {
    await runOrThrow('git', ['revert', '--no-edit', commitHash], { cwd: worktreePath });
  } catch (err) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Failed to revert commit: ${commitHash}`, {
      cause: err instanceof Error ? err.message : String(err),
    });
  }
}
