// src/persistence/gap-analyzer.ts — compare saved PluginSnapshot vs current scan result
// to produce a GapAnalysisResult for inclusion in pth_start_session response.
//
// Gap analysis is informational only — PTH does not auto-generate tests for gaps.
// The AI agent uses the result to decide whether to call pth_generate_tests with
// specific tool names (gap fill) or run the full suite as-is.
//
// Two modes behave differently:
// - Plugin mode: precise name comparison (commands/skills/agents from directories)
// - MCP mode: heuristic name comparison from source scan + source-change signal

import type { PluginSnapshot, GapAnalysisResult } from './types.js';
import type { CurrentScan } from './plugin-scanner.js';
import type { PthTest } from '../testing/types.js';

export function analyzeGap(
  snapshot: PluginSnapshot,
  scan: CurrentScan,
  savedTests: PthTest[]
): GapAnalysisResult {
  const savedTests_count = savedTests.length;

  if (snapshot.pluginMode === 'plugin') {
    return analyzePluginGap(snapshot, scan, savedTests, savedTests_count);
  } else {
    return analyzeMcpGap(snapshot, scan, savedTests, savedTests_count);
  }
}

// ── Plugin mode ──────────────────────────────────────────────────────────────
// Precise: compare component names from directory listings vs saved snapshot.
// Component "name" = the basename of commands/, skills/, agents/ entries.

function analyzePluginGap(
  snapshot: PluginSnapshot,
  scan: CurrentScan,
  savedTests: PthTest[],
  savedTests_count: number
): GapAnalysisResult {
  const savedCommands = new Set(snapshot.commands);
  const savedSkills = new Set(snapshot.skills);
  const savedAgents = new Set(snapshot.agents);

  const currentCommands = new Set(scan.commands);
  const currentSkills = new Set(scan.skills);
  const currentAgents = new Set(scan.agents);

  // Collect all saved component names (prefixed for disambiguation)
  const allSaved = [
    ...snapshot.commands.map(n => `command:${n}`),
    ...snapshot.skills.map(n => `skill:${n}`),
    ...snapshot.agents.map(n => `agent:${n}`),
  ];
  const allCurrent = [
    ...scan.commands.map(n => `command:${n}`),
    ...scan.skills.map(n => `skill:${n}`),
    ...scan.agents.map(n => `agent:${n}`),
  ];

  const savedSet = new Set(allSaved);
  const currentSet = new Set(allCurrent);

  const newComponents = allCurrent.filter(n => !savedSet.has(n));
  const removedComponents = allSaved.filter(n => !currentSet.has(n));
  const unchangedComponents = allCurrent.filter(n => savedSet.has(n));
  // Plugin mode has no schema — "modified" is not detectable without content diffing
  const modifiedComponents: string[] = [];

  // Find test IDs that cover removed components
  const removedNames = new Set(removedComponents.map(c => c.split(':')[1]));
  const staleTestIds = savedTests
    .filter(t => {
      const toolRef = t.tool ?? t.name.split(' ')[0];
      return removedNames.has(toolRef) || removedNames.has(toolRef.replace(/_/g, '-'));
    })
    .map(t => t.id);

  const recommendation = buildRecommendation({
    newCount: newComponents.length,
    modifiedCount: 0,
    removedCount: removedComponents.length,
    staleCount: staleTestIds.length,
    sourceChanged: false,
    pluginMode: 'plugin',
  });

  return {
    savedTests: savedTests_count,
    newComponents,
    modifiedComponents,
    removedComponents,
    unchangedComponents,
    staleTestIds,
    sourceChangedSinceSnapshot: false,
    recommendation,
  };

  void savedCommands; void savedSkills; void savedAgents;
  void currentCommands; void currentSkills; void currentAgents;
}

// ── MCP mode ─────────────────────────────────────────────────────────────────
// Heuristic: compare tool names from source scan vs saved snapshot.
// Schema-level changes detected via source mtime — can't parse schemas without live server.

function analyzeMcpGap(
  snapshot: PluginSnapshot,
  scan: CurrentScan,
  savedTests: PthTest[],
  savedTests_count: number
): GapAnalysisResult {
  const savedToolNames = new Set(snapshot.tools.map(t => t.name));
  const currentToolNames = new Set(scan.toolNames);

  // Only compare if we found tool names via source scan.
  // If source scan returned nothing, we can't determine what changed.
  const hasCurrentNames = currentToolNames.size > 0;

  let newComponents: string[] = [];
  let removedComponents: string[] = [];
  let unchangedComponents: string[] = [];

  if (hasCurrentNames) {
    newComponents = [...currentToolNames].filter(n => !savedToolNames.has(n));
    removedComponents = [...savedToolNames].filter(n => !currentToolNames.has(n));
    unchangedComponents = [...currentToolNames].filter(n => savedToolNames.has(n));
  } else {
    // No source scan results — treat all saved tools as "unknown state"
    unchangedComponents = snapshot.tools.map(t => t.name);
  }

  // "Modified" = in both but source files changed since snapshot (schema may have changed)
  // We can't confirm schema change without a live server, so flag as "potentially modified"
  const sourceChanged = scan.changedSourceFiles.length > 0;
  const modifiedComponents = sourceChanged && hasCurrentNames
    ? unchangedComponents.filter(n => {
        // Heuristic: flag as modified if the tool is in an unchanged component AND source changed.
        // This over-reports (all unchanged tools flagged when any source file changed), but
        // it's conservative — PTH would rather suggest too many tests than miss a regression.
        return scan.changedSourceFiles.some(f =>
          f.includes(n.replace(/_/g, '-')) || f.includes(n)
        );
      })
    : [];

  // Find test IDs that cover removed tools
  const removedSet = new Set(removedComponents);
  const staleTestIds = savedTests
    .filter(t => {
      const toolRef = t.tool ?? '';
      return removedSet.has(toolRef);
    })
    .map(t => t.id);

  const recommendation = buildRecommendation({
    newCount: newComponents.length,
    modifiedCount: modifiedComponents.length,
    removedCount: removedComponents.length,
    staleCount: staleTestIds.length,
    sourceChanged,
    pluginMode: 'mcp',
    noSourceScan: !hasCurrentNames,
    changedFileCount: scan.changedSourceFiles.length,
  });

  return {
    savedTests: savedTests_count,
    newComponents,
    modifiedComponents,
    removedComponents,
    unchangedComponents,
    staleTestIds,
    sourceChangedSinceSnapshot: sourceChanged,
    recommendation,
  };
}

// ── Recommendation text ────────────────────────────────────────────────────────

interface RecOpts {
  newCount: number;
  modifiedCount: number;
  removedCount: number;
  staleCount: number;
  sourceChanged: boolean;
  pluginMode: 'mcp' | 'plugin';
  noSourceScan?: boolean;
  changedFileCount?: number;
}

function buildRecommendation(opts: RecOpts): string {
  const parts: string[] = [];

  if (opts.newCount > 0) {
    parts.push(`${opts.newCount} new component(s) detected → run pth_generate_tests to cover them`);
  }
  if (opts.modifiedCount > 0) {
    parts.push(`${opts.modifiedCount} component(s) potentially modified → regenerate tests to update schemas`);
  }
  if (opts.staleCount > 0) {
    parts.push(`${opts.staleCount} test(s) may be stale (removed components) → review with pth_list_tests`);
  }
  if (opts.pluginMode === 'mcp' && opts.sourceChanged && opts.newCount === 0 && opts.modifiedCount === 0) {
    parts.push(`${opts.changedFileCount ?? 0} source file(s) changed since last snapshot → run pth_generate_tests to verify tool schemas`);
  }
  if (opts.pluginMode === 'mcp' && opts.noSourceScan) {
    parts.push(`Source scan found no tool names — run pth_generate_tests to discover current tools`);
  }
  if (parts.length === 0) {
    return 'No structural changes detected — existing tests should still be valid.';
  }
  return parts.join('. ') + '.';
}
