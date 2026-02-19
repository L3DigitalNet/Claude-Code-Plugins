export interface FileChange {
  path: string;     // relative to worktree root
  content: string;  // new full file content
}

export interface FixRequest {
  worktreePath: string;
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
