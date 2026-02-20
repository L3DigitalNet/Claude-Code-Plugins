import { run } from '../shared/exec.js';
export async function reloadPlugin(worktreePath, buildSystem, pluginStartPattern // pattern to find process, e.g. path component of start command
) {
    // Step 1: Build
    let buildOutput = '';
    if (buildSystem.buildCommand) {
        const result = await run(buildSystem.buildCommand[0], buildSystem.buildCommand.slice(1), { cwd: worktreePath, timeoutMs: 120_000 });
        buildOutput = result.stdout + result.stderr;
        if (result.exitCode !== 0) {
            return {
                buildSucceeded: false,
                buildOutput,
                processTerminated: false,
                message: `Build failed (exit ${result.exitCode}). Fix build errors before reloading.`,
            };
        }
    }
    // Step 2: Find PID — prefer pgrep, fall back to ps aux
    let pid;
    const pgrepResult = await run('pgrep', ['-f', pluginStartPattern]);
    if (pgrepResult.exitCode === 0 && pgrepResult.stdout.trim()) {
        // pgrep returns one PID per line; take the first
        const firstPid = parseInt(pgrepResult.stdout.trim().split('\n')[0], 10);
        if (!isNaN(firstPid))
            pid = firstPid;
    }
    if (pid === undefined) {
        // pgrep not available or no match — fall back to ps aux
        const psResult = await run('ps', ['aux']);
        const lines = psResult.stdout.split('\n');
        const matchingLine = lines.find(l => l.includes(pluginStartPattern) && !l.includes('pgrep') && !l.includes('ps aux'));
        if (matchingLine) {
            const parsed = parseInt(matchingLine.trim().split(/\s+/)[1], 10);
            if (!isNaN(parsed))
                pid = parsed;
        }
    }
    if (pid === undefined) {
        return {
            buildSucceeded: true,
            buildOutput,
            processTerminated: false,
            message: `Build succeeded but could not find running process matching "${pluginStartPattern}". The plugin may not be running or may need a manual restart.`,
        };
    }
    // Step 3: SIGTERM with SIGKILL fallback
    let terminated = false;
    try {
        process.kill(pid, 'SIGTERM');
        terminated = await waitForProcessExit(pid, 5000);
    }
    catch {
        terminated = true; // Process already gone
    }
    if (!terminated) {
        // SIGTERM didn't work — try SIGKILL
        try {
            process.kill(pid, 'SIGKILL');
            terminated = await waitForProcessExit(pid, 2000);
        }
        catch {
            terminated = true; // Already gone
        }
    }
    return {
        buildSucceeded: true,
        buildOutput,
        processTerminated: terminated,
        pid,
        message: terminated
            ? `Build succeeded. Process ${pid} terminated. Claude Code should restart the plugin automatically. Please verify by calling one of the plugin's tools before continuing.`
            : `Build succeeded but process ${pid} did not exit after SIGTERM + SIGKILL. Manual restart may be required.`,
    };
}
async function waitForProcessExit(pid, timeoutMs) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        try {
            process.kill(pid, 0); // throws ESRCH if process doesn't exist
            await sleep(200);
        }
        catch {
            return true; // process is gone
        }
    }
    return false; // timed out
}
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
//# sourceMappingURL=reloader.js.map