import fs from 'fs/promises';
import path from 'path';
import { run } from '../shared/exec.js';
import type { BuildSystem } from './types.js';

export interface ReloadResult {
  buildSucceeded: boolean;
  buildOutput: string;
  processTerminated: boolean;
  pid?: number;
  message: string;
}

export async function reloadPlugin(
  worktreePath: string,
  buildSystem: BuildSystem,
  pluginStartPattern: string,   // pattern to find process, e.g. path component of start command
  onBuildSuccess?: () => Promise<void>  // called after build succeeds, before process kill (e.g. cache sync)
): Promise<ReloadResult> {
  // Step 1: Install dependencies if missing — worktrees are clean checkouts with no
  // node_modules. Run installCommand once before building so tsc and other bin tools resolve.
  let buildOutput = '';
  if (buildSystem.installCommand) {
    const nodeModulesPath = path.join(worktreePath, 'node_modules');
    const hasDeps = await fs.access(nodeModulesPath).then(() => true).catch(() => false);
    if (!hasDeps) {
      const installResult = await run(
        buildSystem.installCommand[0],
        buildSystem.installCommand.slice(1),
        { cwd: worktreePath, timeoutMs: 120_000 }
      );
      buildOutput += `[install]\n${installResult.stdout}${installResult.stderr}\n`;
      if (installResult.exitCode !== 0) {
        return {
          buildSucceeded: false,
          buildOutput,
          processTerminated: false,
          message: `Dependency install failed (exit ${installResult.exitCode}). Fix install errors before reloading.`,
        };
      }
    }
  }

  // Step 2: Build
  if (buildSystem.buildCommand) {
    const result = await run(
      buildSystem.buildCommand[0],
      buildSystem.buildCommand.slice(1),
      { cwd: worktreePath, timeoutMs: 120_000 }
    );
    buildOutput += result.stdout + result.stderr;
    if (result.exitCode !== 0) {
      return {
        buildSucceeded: false,
        buildOutput,
        processTerminated: false,
        message: `Build failed (exit ${result.exitCode}). Fix build errors before reloading.`,
      };
    }
  }

  // Step 3: Post-build hook (e.g. sync dist to versioned cache) — must run before kill
  // so the restarted process loads the new binary, not the old cached one.
  if (onBuildSuccess) {
    try {
      await onBuildSuccess();
    } catch (err) {
      return {
        buildSucceeded: true,
        buildOutput,
        processTerminated: false,
        message: `Build succeeded but post-build step failed: ${err instanceof Error ? err.message : String(err)}`,
      };
    }
  }

  // Step 4: Find PID — prefer pgrep, fall back to ps aux
  let pid: number | undefined;

  const pgrepResult = await run('pgrep', ['-f', pluginStartPattern]);
  if (pgrepResult.exitCode === 0 && pgrepResult.stdout.trim()) {
    // pgrep returns one PID per line; take the first
    const firstPid = parseInt(pgrepResult.stdout.trim().split('\n')[0], 10);
    if (!isNaN(firstPid)) pid = firstPid;
  }

  if (pid === undefined) {
    // pgrep not available or no match — fall back to ps aux
    const psResult = await run('ps', ['aux']);
    const lines = psResult.stdout.split('\n');
    const matchingLine = lines.find(l =>
      l.includes(pluginStartPattern) && !l.includes('pgrep') && !l.includes('ps aux')
    );
    if (matchingLine) {
      const parsed = parseInt(matchingLine.trim().split(/\s+/)[1], 10);
      if (!isNaN(parsed)) pid = parsed;
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

  // Step 5: Defer SIGTERM — killing synchronously races with the stdio flush and prevents
  // this response from reaching the caller. Critically: when PTH reloads itself (dogfooding),
  // a synchronous kill terminates the process before the MCP response is written.
  // 500 ms is enough for the stdio layer to flush the response before SIGTERM arrives.
  const KILL_DELAY_MS = 500;
  void Promise.resolve().then(() => new Promise<void>(resolve => setTimeout(resolve, KILL_DELAY_MS))).then(async () => {
    try {
      process.kill(pid, 'SIGTERM');
      const ok = await waitForProcessExit(pid, 5000);
      if (!ok) {
        try { process.kill(pid, 'SIGKILL'); } catch { /* already gone */ }
      }
    } catch { /* already gone */ }
  });

  return {
    buildSucceeded: true,
    buildOutput,
    processTerminated: true,  // will terminate in ~KILL_DELAY_MS ms
    pid,
    message: `Build succeeded. Process ${pid} will terminate in ~${KILL_DELAY_MS}ms. Claude Code should restart the plugin automatically. Please verify by calling one of the plugin's tools before continuing.`,
  };
}

async function waitForProcessExit(pid: number, timeoutMs: number): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      process.kill(pid, 0);  // throws ESRCH if process doesn't exist
      await sleep(200);
    } catch {
      return true;  // process is gone
    }
  }
  return false;  // timed out
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
