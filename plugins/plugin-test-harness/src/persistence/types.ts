// src/persistence/types.ts — cross-session storage types for ~/.pth/PLUGIN_NAME/
// Consumed by store-manager.ts (read/write), gap-analyzer.ts (compare snapshots),
// and session/manager.ts (populate at start/end). Breaking changes here require
// updating all three consumers.

import type { TestResult } from '../results/types.js';

// ── Plugin snapshot ────────────────────────────────────────────────────────────

// Saved at pth_end_session. Describes the plugin structure that the current test
// suite covers. Used by gap-analyzer.ts to detect new/removed/modified components
// in the next session without requiring a live server at start time.
export interface ToolSnapshotEntry {
  name: string;
  description: string;
  // Full inputSchema from the live MCP server at session end.
  // JSON.stringify comparison is used to detect schema-level modifications.
  inputSchema: object;
}

export interface PluginSnapshot {
  pluginMode: 'mcp' | 'plugin';
  capturedAt: string;        // ISO timestamp — used for mtime comparison in MCP gap analysis
  version?: string;          // from package.json or plugin.json at snapshot time
  // MCP mode: populated from fetchToolSchemasFromMcpServer or tool-schemas cache at session end
  tools: ToolSnapshotEntry[];
  // Plugin mode: component names from directory listings at session end
  commands: string[];
  skills: string[];
  agents: string[];
}

// ── Gap analysis ───────────────────────────────────────────────────────────────

// Returned by gap-analyzer.ts, included in pth_start_session response.
// Informational only — PTH does not auto-generate tests for gaps.
export interface GapAnalysisResult {
  savedTests: number;
  // MCP mode: tool names derived from source scan + snapshot comparison
  // Plugin mode: component names from directory listing + snapshot comparison
  newComponents: string[];       // in current source, absent from snapshot
  modifiedComponents: string[];  // in both, but schema/content changed
  removedComponents: string[];   // in snapshot, absent from current source
  unchangedComponents: string[]; // no change detected
  staleTestIds: string[];        // test IDs whose target component was removed
  // MCP mode only: true if any src/ file has mtime newer than snapshot.capturedAt
  sourceChangedSinceSnapshot: boolean;
  recommendation: string;
}

// ── Results history ────────────────────────────────────────────────────────────

// One entry per test per session. Appended (never overwritten) to results-history.json.
// Outer format: Record<testId, ResultHistoryEntry[]>
export interface ResultHistoryEntry {
  sessionId: string;
  status: 'passing' | 'failing' | 'skipped';
  failureReason?: string;
  timestamp: string;
}

// Serializable export from ResultsTracker — passed to store-manager.appendResults()
export interface ExportedResults {
  testId: string;
  testName: string;
  latestStatus: 'passing' | 'failing' | 'skipped' | 'pending';
  latestResult?: TestResult;
}

// ── Persistent store index ─────────────────────────────────────────────────────

// ~/.pth/PLUGIN_NAME/index.json — existence check + metadata.
// Absence of this file means no history exists for the plugin.
export interface StoreIndex {
  pluginName: string;
  createdAt: string;
  lastSession: string;
  sessionCount: number;
}

// ── endSession options ────────────────────────────────────────────────────────

// Passed by server.ts to manager.endSession() — provides the in-memory runtime
// data that manager.ts cannot access directly (it lives in server.ts scope).
export interface EndSessionOptions {
  // Snapshots from mgr.iterationHistory (each push from pth_get_iteration_status)
  iterationHistory: Array<{ passing: number; failing: number; fixesApplied: number }>;
  // Latest result for each test from ResultsTracker.exportHistory()
  exportedResults: ExportedResults[];
}
