import { execa } from 'execa';
import { PTHError, PTHErrorCode } from './errors.js';
export async function run(command, args, options) {
    try {
        const result = await execa(command, args, {
            cwd: options?.cwd,
            env: options?.env,
            timeout: options?.timeoutMs,
            reject: false,
        });
        return {
            stdout: result.stdout ?? '',
            stderr: result.stderr ?? '',
            exitCode: result.exitCode ?? (result.isTerminated ? 128 : 0),
            signal: result.signal ?? undefined,
        };
    }
    catch (err) {
        throw new PTHError(PTHErrorCode.BUILD_FAILED, `Command failed to spawn: ${command}`, {
            cause: err instanceof Error ? err.message : String(err),
        });
    }
}
export async function runOrThrow(command, args, options) {
    const result = await run(command, args, options);
    if (result.exitCode !== 0) {
        throw new PTHError(PTHErrorCode.BUILD_FAILED, `Command exited with ${result.exitCode}: ${command}`, {
            stdout: result.stdout,
            stderr: result.stderr,
        });
    }
    return result;
}
//# sourceMappingURL=exec.js.map