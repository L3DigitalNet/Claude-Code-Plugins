import type { FixCommitTrailers } from './types.js';
export declare function generateSessionBranch(pluginName: string): string;
export declare function buildCommitMessage(title: string, trailers: FixCommitTrailers): string;
export declare function parseTrailers(commitMessage: string): Record<string, string>;
export declare function createBranch(repoPath: string, branchName: string): Promise<void>;
export declare function checkBranchExists(repoPath: string, branchName: string): Promise<boolean>;
export declare function addWorktree(repoPath: string, worktreePath: string, branch: string): Promise<void>;
export declare function removeWorktree(repoPath: string, worktreePath: string): Promise<void>;
export declare function pruneWorktrees(repoPath: string): Promise<void>;
export declare function commitAll(worktreePath: string, message: string): Promise<string>;
export declare function getLog(worktreePath: string, options?: {
    since?: string;
    maxCount?: number;
}): Promise<string>;
export declare function getDiff(worktreePath: string, base: string): Promise<string>;
export declare function revertCommit(worktreePath: string, commitHash: string): Promise<void>;
//# sourceMappingURL=git.d.ts.map