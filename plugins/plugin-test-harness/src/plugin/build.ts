import { runOrThrow } from '../shared/exec.js';
import type { BuildSystem } from './types.js';

export async function buildPlugin(worktreePath: string, buildSystem: BuildSystem): Promise<void> {
  if (buildSystem.installCommand) {
    await runOrThrow(buildSystem.installCommand[0], buildSystem.installCommand.slice(1), {
      cwd: worktreePath,
      timeoutMs: 120_000,
    });
  }
  if (buildSystem.buildCommand) {
    await runOrThrow(buildSystem.buildCommand[0], buildSystem.buildCommand.slice(1), {
      cwd: worktreePath,
      timeoutMs: 120_000,
    });
  }
}

export async function buildOnly(worktreePath: string, buildSystem: BuildSystem): Promise<void> {
  if (buildSystem.buildCommand) {
    await runOrThrow(buildSystem.buildCommand[0], buildSystem.buildCommand.slice(1), {
      cwd: worktreePath,
      timeoutMs: 120_000,
    });
  }
}
