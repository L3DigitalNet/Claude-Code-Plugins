export interface FileChange {
  path: string;     // relative to plugin root (not worktree root)
  content: string;  // new full file content
}

export interface FixRequest {
  worktreePath: string;
  pluginRelPath: string;  // path from worktree root to plugin dir ('' when plugin IS the repo root)
  files: FileChange[];
  commitTitle: string;
  trailers: Record<string, string>;
}

export interface FixRecord {
  commitHash: string;
  commitTitle: string;
  trailers: Record<string, string>;
  filesChanged: string[];
  timestamp: string;
}
