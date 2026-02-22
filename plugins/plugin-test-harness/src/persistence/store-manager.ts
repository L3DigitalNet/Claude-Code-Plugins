// src/persistence/store-manager.ts — read/write ~/.pth/PLUGIN_NAME/
// This is the authoritative cross-session storage layer. All persistent artifacts
// (tests, results, reports, snapshots) live here. Worktree .pth/ holds only
// runtime data (session-state.json, lock file, tool-schemas cache).
//
// Interacts with:
// - session/manager.ts: called at startSession (load) and endSession (save)
// - testing/parser.ts: loadTestsFromDir() works on any directory path
// - results/tracker.ts: exportHistory() feeds appendResults()
// - fix/tracker.ts: getFixHistory() feeds saveSessionArtifacts()

import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import type { PluginSnapshot, ResultHistoryEntry, StoreIndex, ExportedResults } from './types.js';
import type { FixRecord } from '../fix/types.js';
import type { TestStore } from '../testing/store.js';
import { loadTestsFromDir } from '../testing/parser.js';
import type { PthTest } from '../testing/types.js';

// ── Path helpers ──────────────────────────────────────────────────────────────

// Sanitize plugin name to a safe directory name.
// Same slug logic as session branch names (see session/git.ts generateSessionBranch).
function slugify(name: string): string {
  return name.replace(/[^a-z0-9-]/gi, '-').toLowerCase();
}

export function getPersistentStorePath(pluginName: string): string {
  return path.join(os.homedir(), '.pth', slugify(pluginName));
}

// ── Existence check ───────────────────────────────────────────────────────────

export async function hasHistory(pluginName: string): Promise<boolean> {
  const indexPath = path.join(getPersistentStorePath(pluginName), 'index.json');
  try {
    await fs.access(indexPath);
    return true;
  } catch {
    return false;
  }
}

// ── Test loading ──────────────────────────────────────────────────────────────

// Load test definitions from the persistent store's tests/ directory.
// Returns empty array if no history exists yet.
export async function loadTests(pluginName: string): Promise<PthTest[]> {
  const testsDir = path.join(getPersistentStorePath(pluginName), 'tests');
  return loadTestsFromDir(testsDir);
}

// ── Test saving ───────────────────────────────────────────────────────────────

// Persist the full test suite to ~/.pth/PLUGIN_NAME/tests/.
// Overwrites existing files — the in-memory TestStore is the authoritative state
// for the current session; persistent tests/ is overwritten on each session end.
export async function saveTests(pluginName: string, store: TestStore): Promise<void> {
  const testsDir = path.join(getPersistentStorePath(pluginName), 'tests');
  await fs.mkdir(testsDir, { recursive: true });
  await store.persistToDir(testsDir);
}

// ── Snapshot read/write ───────────────────────────────────────────────────────

export async function loadSnapshot(pluginName: string): Promise<PluginSnapshot | null> {
  const snapshotPath = path.join(getPersistentStorePath(pluginName), 'plugin-snapshot.json');
  try {
    const raw = await fs.readFile(snapshotPath, 'utf-8');
    return JSON.parse(raw) as PluginSnapshot;
  } catch {
    return null;
  }
}

export async function saveSnapshot(pluginName: string, snapshot: PluginSnapshot): Promise<void> {
  const storePath = getPersistentStorePath(pluginName);
  await fs.mkdir(storePath, { recursive: true });
  await fs.writeFile(
    path.join(storePath, 'plugin-snapshot.json'),
    JSON.stringify(snapshot, null, 2),
    'utf-8'
  );
}

// ── Results history ───────────────────────────────────────────────────────────

// Append this session's results to the running results-history.json.
// Format: Record<testId, ResultHistoryEntry[]> — existing entries preserved.
export async function appendResults(
  pluginName: string,
  sessionId: string,
  exportedResults: ExportedResults[]
): Promise<void> {
  if (exportedResults.length === 0) return;

  const storePath = getPersistentStorePath(pluginName);
  await fs.mkdir(storePath, { recursive: true });
  const historyPath = path.join(storePath, 'results-history.json');

  // Load existing history — start fresh if file is absent or malformed
  let history: Record<string, ResultHistoryEntry[]> = {};
  try {
    const raw = await fs.readFile(historyPath, 'utf-8');
    history = JSON.parse(raw) as typeof history;
  } catch {
    history = {};
  }

  // Append entries for results that have a recorded status (not pending)
  const timestamp = new Date().toISOString();
  for (const result of exportedResults) {
    if (result.latestStatus === 'pending') continue;
    const entry: ResultHistoryEntry = {
      sessionId,
      status: result.latestStatus as 'passing' | 'failing' | 'skipped',
      failureReason: result.latestResult?.failureReason,
      timestamp: result.latestResult?.recordedAt ?? timestamp,
    };
    const existing = history[result.testId] ?? [];
    existing.push(entry);
    history[result.testId] = existing;
  }

  await fs.writeFile(historyPath, JSON.stringify(history, null, 2), 'utf-8');
}

// ── Per-session artifacts ─────────────────────────────────────────────────────

export interface SessionArtifacts {
  sessionId: string;
  reportContent: string;                                           // SESSION-REPORT.md text
  iterationHistory: Array<{ passing: number; failing: number; fixesApplied: number }>;
  fixHistory: FixRecord[];
}

// Write per-session directory: SESSION-REPORT.md, iteration-history.json, fix-history.json.
// Directory: ~/.pth/PLUGIN_NAME/sessions/YYYY-MM-DD-<sessionId>/
export async function saveSessionArtifacts(
  pluginName: string,
  artifacts: SessionArtifacts
): Promise<string> {
  const date = new Date().toISOString().slice(0, 10);
  // Use the branch suffix (after pth/<name>-) as a compact session dir name
  const shortId = artifacts.sessionId.split('/').pop() ?? artifacts.sessionId;
  const sessionDir = path.join(
    getPersistentStorePath(pluginName),
    'sessions',
    `${date}-${shortId}`
  );
  await fs.mkdir(sessionDir, { recursive: true });

  await Promise.all([
    fs.writeFile(path.join(sessionDir, 'SESSION-REPORT.md'), artifacts.reportContent, 'utf-8'),
    fs.writeFile(
      path.join(sessionDir, 'iteration-history.json'),
      JSON.stringify(
        artifacts.iterationHistory.map((s, i) => ({
          iteration: i + 1,
          passing: s.passing,
          failing: s.failing,
          fixesApplied: s.fixesApplied,
        })),
        null, 2
      ),
      'utf-8'
    ),
    fs.writeFile(
      path.join(sessionDir, 'fix-history.json'),
      JSON.stringify(artifacts.fixHistory, null, 2),
      'utf-8'
    ),
  ]);

  return sessionDir;
}

// ── Index management ──────────────────────────────────────────────────────────

export async function updateIndex(pluginName: string, sessionId: string): Promise<void> {
  const storePath = getPersistentStorePath(pluginName);
  await fs.mkdir(storePath, { recursive: true });
  const indexPath = path.join(storePath, 'index.json');

  let index: StoreIndex;
  try {
    const raw = await fs.readFile(indexPath, 'utf-8');
    index = JSON.parse(raw) as StoreIndex;
  } catch {
    index = {
      pluginName,
      createdAt: new Date().toISOString(),
      lastSession: sessionId,
      sessionCount: 0,
    };
  }

  index.lastSession = sessionId;
  index.sessionCount = (index.sessionCount ?? 0) + 1;

  await fs.writeFile(indexPath, JSON.stringify(index, null, 2), 'utf-8');
}
