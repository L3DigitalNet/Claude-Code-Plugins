import type { SessionState } from './types.js';

export async function preflight(_args: { pluginPath: string }): Promise<string> {
  throw new Error('not implemented');
}

export async function startSession(
  _args: { pluginPath: string; sessionNote?: string }
): Promise<{ state: SessionState; message: string }> {
  throw new Error('not implemented');
}

export async function resumeSession(
  _args: { branch: string; pluginPath: string }
): Promise<{ state: SessionState; message: string }> {
  throw new Error('not implemented');
}

export async function endSession(_state: SessionState): Promise<string> {
  throw new Error('not implemented');
}
