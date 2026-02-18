import { randomBytes } from 'crypto';
import { run, runOrThrow } from '../shared/exec.js';
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
  await runOrThrow('git', ['checkout', '-b', branchName], { cwd: repoPath });
}

export async function checkBranchExists(repoPath: string, branchName: string): Promise<boolean> {
  const result = await run('git', ['rev-parse', '--verify', branchName], { cwd: repoPath });
  return result.exitCode === 0;
}

export async function addWorktree(repoPath: string, worktreePath: string, branch: string): Promise<void> {
  await runOrThrow('git', ['worktree', 'add', worktreePath, branch], { cwd: repoPath });
}

export async function removeWorktree(repoPath: string, worktreePath: string): Promise<void> {
  await run('git', ['worktree', 'remove', '--force', worktreePath], { cwd: repoPath });
}

export async function pruneWorktrees(repoPath: string): Promise<void> {
  await run('git', ['worktree', 'prune'], { cwd: repoPath });
}

export async function commitAll(
  worktreePath: string,
  message: string
): Promise<string> {
  await run('git', ['add', '-A'], { cwd: worktreePath });
  const result = await runOrThrow('git', ['commit', '-m', message], { cwd: worktreePath });
  // extract commit hash from output: "[branch abc1234] ..."
  const match = result.stdout.match(/\[[\w/]+ ([a-f0-9]+)\]/);
  return match?.[1] ?? '';
}

export async function getLog(
  worktreePath: string,
  options?: { since?: string; maxCount?: number }
): Promise<string> {
  const args = ['log', '--format=%H %s%n%b'];
  if (options?.maxCount) args.push(`-n${options.maxCount}`);
  const result = await runOrThrow('git', args, { cwd: worktreePath });
  return result.stdout;
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
  await runOrThrow('git', ['revert', '--no-edit', commitHash], { cwd: worktreePath });
}
