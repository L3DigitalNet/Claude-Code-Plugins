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

// Returns the absolute path of the git repository root containing dirPath.
export async function getGitRepoRoot(dirPath: string): Promise<string> {
  const result = await run('git', ['rev-parse', '--show-toplevel'], { cwd: dirPath });
  if (result.exitCode !== 0) {
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Not a git repository: ${dirPath}`);
  }
  return result.stdout.trim();
}

export async function createBranch(repoPath: string, branchName: string): Promise<void> {
  // Use 'git branch' not 'git checkout -b' — we must NOT switch HEAD because
  // git worktree add will immediately fail if the branch is already checked out.
  try {
    await runOrThrow('git', ['branch', branchName], { cwd: repoPath });
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

// Stage only specific files (paths relative to worktree root) then commit.
// Prefer this over commitAll for fix commits — avoids capturing .pth/session-state.json
// (always dirty during active sessions), which would create revert conflicts later.
export async function commitFiles(
  worktreePath: string,
  filePaths: string[],
  message: string
): Promise<string> {
  try {
    for (const filePath of filePaths) {
      await run('git', ['add', filePath], { cwd: worktreePath });
    }
    const result = await runOrThrow('git', ['commit', '-m', message], { cwd: worktreePath });
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

// .pth/session-state.json is an internal PTH file that is always written during active
// sessions. It ends up in fix commits via commitAll (git add -A). When reverting those
// commits, this file consistently conflicts with the current session state.
// Strategy: stash dirty files first; after conflict, resolve session-state.json with
// --ours (keep current session state); error on any other conflicted file.
const SESSION_STATE_FILE = '.pth/session-state.json';

export async function revertCommit(
  worktreePath: string,
  commitHash: string
): Promise<void> {
  let stashed = false;
  try {
    const stashOut = await run('git', ['stash'], { cwd: worktreePath });
    stashed = stashOut.exitCode === 0 && stashOut.stdout.trim() !== 'No local changes to save';

    // --no-edit skips the editor; exits non-zero on conflict, leaving repo in merge state.
    const revertResult = await run('git', ['revert', '--no-edit', commitHash], { cwd: worktreePath });

    if (revertResult.exitCode !== 0) {
      // Identify conflicted files via porcelain status (UU = both modified, AA/DD = add/delete conflicts)
      const statusResult = await run('git', ['status', '--porcelain'], { cwd: worktreePath });
      const conflicted = statusResult.stdout.split('\n')
        .filter(l => /^(UU|AA|DD) /.test(l))
        .map(l => l.slice(3).trim());

      const otherConflicts = conflicted.filter(f => f !== SESSION_STATE_FILE);
      if (otherConflicts.length > 0) {
        await run('git', ['revert', '--abort'], { cwd: worktreePath });
        throw new PTHError(PTHErrorCode.GIT_ERROR,
          `Revert conflicts in: ${otherConflicts.join(', ')} — commit may be entangled with later changes`
        );
      }

      if (conflicted.includes(SESSION_STATE_FILE)) {
        // Safe to keep current session state — this file is PTH-internal, not user data.
        await run('git', ['checkout', '--ours', SESSION_STATE_FILE], { cwd: worktreePath });
        await run('git', ['add', SESSION_STATE_FILE], { cwd: worktreePath });
        const short = commitHash.slice(0, 7);
        // --allow-empty handles the case where the commit was already neutralized by a
        // later commit (no net file changes remain after conflict resolution).
        await runOrThrow('git', ['commit', '--allow-empty', '-m',
          `Revert ${short}\n\nThis reverts commit ${commitHash}.\n(session-state.json resolved with --ours)`
        ], { cwd: worktreePath });
        return;
      }

      // No conflicts found but exit code was non-zero — surface raw output
      throw new PTHError(PTHErrorCode.GIT_ERROR,
        `git revert exited ${revertResult.exitCode}: ${revertResult.stderr || revertResult.stdout}`
      );
    }
  } catch (err) {
    await run('git', ['revert', '--abort'], { cwd: worktreePath }).catch(() => {});
    if (err instanceof PTHError) throw err;
    throw new PTHError(PTHErrorCode.GIT_ERROR, `Failed to revert commit: ${commitHash}`, {
      cause: err instanceof Error ? err.message : String(err),
    });
  } finally {
    if (stashed) {
      await run('git', ['stash', 'pop'], { cwd: worktreePath });
    }
  }
}
