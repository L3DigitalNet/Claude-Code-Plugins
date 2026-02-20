export interface FileChange {
    path: string;
    content: string;
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
//# sourceMappingURL=types.d.ts.map