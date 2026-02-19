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
  pluginStartPattern: string   // pattern to find process, e.g. path component of start command
): Promise<ReloadResult> {
  // Step 1: Build
  let buildOutput = '';
  if (buildSystem.buildCommand) {
    const result = await run(
      buildSystem.buildCommand[0],
      buildSystem.buildCommand.slice(1),
      { cwd: worktreePath, timeoutMs: 120_000 }
    );
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

  // Step 2: Find PID via ps aux
  const psResult = await run('ps', ['aux']);
  const lines = psResult.stdout.split('\n');
  const matchingLine = lines.find(l => l.includes(pluginStartPattern) && !l.includes('grep'));

  if (!matchingLine) {
    return {
      buildSucceeded: true,
      buildOutput,
      processTerminated: false,
      message: `Build succeeded but could not find running process matching "${pluginStartPattern}". The plugin may not be running or may need a manual restart.`,
    };
  }

  const pid = parseInt(matchingLine.trim().split(/\s+/)[1], 10);
  if (isNaN(pid)) {
    return {
      buildSucceeded: true,
      buildOutput,
      processTerminated: false,
      message: `Build succeeded but could not parse PID from ps output.`,
    };
  }

  // Step 3: SIGTERM with SIGKILL fallback
  try {
    process.kill(pid, 'SIGTERM');
    await waitForProcessExit(pid, 5000);
  } catch {
    // Process already gone — fine
  }

  // Try SIGKILL if still running
  try {
    process.kill(pid, 0);  // throws if process doesn't exist
    process.kill(pid, 'SIGKILL');
  } catch {
    // Already gone — success
  }

  return {
    buildSucceeded: true,
    buildOutput,
    processTerminated: true,
    pid,
    message: `Build succeeded. Process ${pid} terminated. Claude Code should restart the plugin automatically. Please verify by calling one of the plugin's tools before continuing.`,
  };
}

async function waitForProcessExit(pid: number, timeoutMs: number): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      process.kill(pid, 0);  // throws ESRCH if process doesn't exist
      await sleep(200);
    } catch {
      return;  // process is gone
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
