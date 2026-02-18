import { execa } from 'execa';
import { PTHError, PTHErrorCode } from './errors.js';

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export async function run(
  command: string,
  args: string[],
  options?: { cwd?: string; env?: Record<string, string>; timeoutMs?: number }
): Promise<ExecResult> {
  try {
    const result = await execa(command, args, {
      cwd: options?.cwd,
      env: options?.env ? { ...process.env, ...options.env } : undefined,
      timeout: options?.timeoutMs,
      reject: false,
    });
    return {
      stdout: typeof result.stdout === 'string' ? result.stdout : '',
      stderr: typeof result.stderr === 'string' ? result.stderr : '',
      exitCode: result.exitCode ?? 0,
    };
  } catch (err) {
    const execaErr = err as { stdout?: string; stderr?: string; exitCode?: number };
    throw new PTHError(PTHErrorCode.BUILD_FAILED, `Command failed: ${command}`, {
      stdout: execaErr.stdout,
      stderr: execaErr.stderr,
      exitCode: execaErr.exitCode,
    });
  }
}

export async function runOrThrow(
  command: string,
  args: string[],
  options?: { cwd?: string; env?: Record<string, string>; timeoutMs?: number }
): Promise<ExecResult> {
  const result = await run(command, args, options);
  if (result.exitCode !== 0) {
    throw new PTHError(
      PTHErrorCode.BUILD_FAILED,
      `Command exited with ${result.exitCode}: ${command}`,
      {
        stdout: result.stdout,
        stderr: result.stderr,
      }
    );
  }
  return result;
}
