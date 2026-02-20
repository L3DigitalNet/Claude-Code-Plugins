export interface ExecResult {
    stdout: string;
    stderr: string;
    exitCode: number;
    signal?: string;
}
export declare function run(command: string, args: string[], options?: {
    cwd?: string;
    env?: Record<string, string>;
    timeoutMs?: number;
}): Promise<ExecResult>;
export declare function runOrThrow(command: string, args: string[], options?: {
    cwd?: string;
    env?: Record<string, string>;
    timeoutMs?: number;
}): Promise<ExecResult>;
//# sourceMappingURL=exec.d.ts.map