import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { jest } from '@jest/globals';
import { PTHError, PTHErrorCode } from '../../../src/shared/errors.js';

// Minimal mocks — we only test the lock-check logic, not git or filesystem side effects.
// ESM requires jest.unstable_mockModule before the dynamic import of the module under test.
// mockImplementation is used instead of mockResolvedValue to avoid TS strict-return-type issues
// on untyped jest.fn() where the inferred return type becomes `never`.
// createBranch throws a PTHError (matching production) so the dead-PID test sees GIT_ERROR, not a plain Error.
jest.unstable_mockModule('../../../src/plugin/detector.js', () => ({
  detectPluginName: jest.fn().mockImplementation(async () => 'test-plugin'),
  detectPluginMode: jest.fn().mockImplementation(async () => 'plugin'),
  detectBuildSystem: jest.fn().mockImplementation(async () => 'none'),
  readMcpConfig: jest.fn().mockImplementation(async () => null),
}));
jest.unstable_mockModule('../../../src/session/git.js', () => ({
  getGitRepoRoot: jest.fn().mockImplementation(async () => '/fake/repo'),
  generateSessionBranch: jest.fn().mockImplementation(() => 'pth/test-plugin-2026-02-21-abc123'),
  pruneWorktrees: jest.fn().mockImplementation(async () => undefined),
  checkBranchExists: jest.fn().mockImplementation(async () => false),
  createBranch: jest.fn().mockImplementation(async () => {
    throw new PTHError(PTHErrorCode.GIT_ERROR, 'git stubbed');
  }),
  addWorktree: jest.fn().mockImplementation(async () => {
    throw new PTHError(PTHErrorCode.GIT_ERROR, 'git stubbed');
  }),
  removeWorktree: jest.fn().mockImplementation(async () => undefined),
  commitAll: jest.fn().mockImplementation(async () => undefined),
  buildCommitMessage: jest.fn().mockImplementation(() => 'stubbed commit'),
}));

describe('startSession — lock enforcement (BUG-1)', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-test-'));
    await fs.mkdir(path.join(tmpDir, '.pth'), { recursive: true });
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true, force: true });
  });

  it('throws SESSION_ALREADY_ACTIVE when lock exists with live PID', async () => {
    const { startSession } = await import('../../../src/session/manager.js');
    const lockPath = path.join(tmpDir, '.pth', 'active-session.lock');
    // Write lock with own PID — guaranteed live
    await fs.writeFile(lockPath, JSON.stringify({ pid: process.pid, branch: 'pth/other-2026-01-01-abc123' }));

    await expect(startSession({ pluginPath: tmpDir }))
      .rejects.toMatchObject({ code: 'SESSION_ALREADY_ACTIVE' });
  });

  it('proceeds normally when lock has dead PID', async () => {
    const { startSession } = await import('../../../src/session/manager.js');
    const lockPath = path.join(tmpDir, '.pth', 'active-session.lock');
    // Use a known-dead PID: 99999999
    await fs.writeFile(lockPath, JSON.stringify({ pid: 99999999, branch: 'pth/old-session' }));

    // Will throw GIT_ERROR (from the stubbed git), not SESSION_ALREADY_ACTIVE
    await expect(startSession({ pluginPath: tmpDir }))
      .rejects.toMatchObject({ code: 'GIT_ERROR' });
  });
});
