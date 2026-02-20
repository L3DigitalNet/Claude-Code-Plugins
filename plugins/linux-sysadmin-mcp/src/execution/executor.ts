// Command execution layer — every tool command passes through this module.
// Provides the Executor interface; LocalExecutor is the sole implementation today.
// LocalExecutor.execute() is the hard boundary between tool code and the OS —
// changing shell/timeout/buffer behavior here affects every registered tool.
import { execFile } from "node:child_process";
import type { Command } from "../types/command.js";
import { logger } from "../logger.js";

/** Result of command execution. */
export interface ExecResult {
  readonly stdout: string;
  readonly stderr: string;
  readonly exitCode: number;
  readonly durationMs: number;
}

/** Executor interface — local or remote. */
export interface Executor {
  execute(command: Command, timeoutMs: number): Promise<ExecResult>;
}

/** Local executor using child_process (Section 3.2). */
export class LocalExecutor implements Executor {
  async execute(command: Command, timeoutMs: number): Promise<ExecResult> {
    const start = performance.now();
    const [cmd, ...args] = command.argv;

    return new Promise<ExecResult>((resolve) => {
      const child = execFile(
        cmd,
        args,
        {
          timeout: timeoutMs,
          // 10MB ceiling: generous enough for large package/log output (typical: <1MB),
          // but prevents unbounded memory growth from runaway commands.
          maxBuffer: 10 * 1024 * 1024,
          env: command.env ? { ...process.env, ...command.env } : process.env,
          // Security boundary: shell parsing only when argv[0] is explicitly "bash".
          // All other commands run via execFile without shell, preventing injection
          // through argument values. Tools that need pipelines must use execBash().
          shell: cmd === "bash",
        },
        (error, stdout, stderr) => {
          const durationMs = Math.round(performance.now() - start);
          const exitCode = error && "code" in error ? (error.code as number ?? 1) : error ? 1 : 0;
          resolve({ stdout: stdout ?? "", stderr: stderr ?? "", exitCode, durationMs });
        },
      );

      if (command.stdin && child.stdin) {
        child.stdin.write(command.stdin);
        child.stdin.end();
      }
    });
  }
}

/**
 * Execute a raw bash command string. Convenience for tools that build
 * complex pipelines where argv decomposition is impractical.
 */
export async function execBash(executor: Executor, cmd: string, timeoutMs: number): Promise<ExecResult> {
  return executor.execute({ argv: ["bash", "-c", cmd] }, timeoutMs);
}
