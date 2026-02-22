// src/persistence/plugin-scanner.ts — build a PluginSnapshot from plugin source files
// without requiring a live server connection. Used by gap-analyzer.ts at session start.
//
// Plugin mode: precise — list commands/, skills/, agents/ directories.
// MCP mode: heuristic — regex scan of TypeScript/JavaScript source for tool name patterns
// + mtime comparison to detect files changed since last snapshot.
//
// Snapshot saved at session end (with full schemas from live server) is richer than
// what source scanning can produce. This module only needs to detect names + change signals.

import fs from 'fs/promises';
import path from 'path';
import type { PluginSnapshot, ToolSnapshotEntry } from './types.js';

// Regex to extract tool names from TypeScript/JavaScript source.
// Matches: name: 'tool_name' or name: "tool_name" where tool_name is snake_case.
// Heuristic: snake_case identifiers with at least one underscore or 4+ chars are likely tools,
// not generic 'name' properties (e.g. server name, plugin name, etc.)
const TOOL_NAME_PATTERN = /\bname:\s*['"]([a-z][a-z0-9_]{3,})['"]/g;

export interface CurrentScan {
  pluginMode: 'mcp' | 'plugin';
  version?: string;
  // MCP: tool names extracted from source files (heuristic)
  toolNames: string[];
  // Plugin: component names from directory listing
  commands: string[];
  skills: string[];
  agents: string[];
  // Files changed since snapshotCapturedAt (ISO). Empty when snapshotCapturedAt is undefined.
  changedSourceFiles: string[];
  scannedAt: string;
}

export async function scanPlugin(
  pluginPath: string,
  snapshotCapturedAt?: string
): Promise<CurrentScan> {
  const scannedAt = new Date().toISOString();

  // Determine plugin mode
  const isMcp = await fileExists(path.join(pluginPath, '.mcp.json'));
  const pluginMode = isMcp ? 'mcp' : 'plugin';

  // Read version from package.json or plugin.json
  const version = await readVersion(pluginPath);

  if (pluginMode === 'plugin') {
    const [commands, skills, agents] = await Promise.all([
      listComponentNames(path.join(pluginPath, '.claude-plugin', 'commands')),
      listComponentNames(path.join(pluginPath, '.claude-plugin', 'skills')),
      listComponentNames(path.join(pluginPath, '.claude-plugin', 'agents')),
    ]);
    return { pluginMode, version, toolNames: [], commands, skills, agents, changedSourceFiles: [], scannedAt };
  }

  // MCP mode: scan source files
  const srcDir = path.join(pluginPath, 'src');
  const srcExists = await fileExists(srcDir);

  // Check for changed files since snapshot — any .ts or .js file newer than snapshot
  const snapshotTime = snapshotCapturedAt ? new Date(snapshotCapturedAt).getTime() : undefined;
  const [toolNames, changedSourceFiles] = await Promise.all([
    srcExists ? extractToolNamesFromSource(srcDir) : Promise.resolve([] as string[]),
    snapshotTime ? findChangedSourceFiles(pluginPath, snapshotTime) : Promise.resolve([] as string[]),
  ]);

  return { pluginMode, version, toolNames, commands: [], skills: [], agents: [], changedSourceFiles, scannedAt };
}

// Build a PluginSnapshot from the current scan + tool schemas from the live session.
// Called at pth_end_session when we have full schema data from the live server.
export function buildSnapshot(
  scan: CurrentScan,
  toolSchemas: ToolSnapshotEntry[]
): PluginSnapshot {
  return {
    pluginMode: scan.pluginMode,
    capturedAt: scan.scannedAt,
    version: scan.version,
    tools: toolSchemas,
    commands: scan.commands,
    skills: scan.skills,
    agents: scan.agents,
  };
}

// List component names from a plugin directory (commands/, skills/, agents/).
// Returns the basename of each entry (file stem or directory name), sorted.
async function listComponentNames(dirPath: string): Promise<string[]> {
  try {
    const entries = await fs.readdir(dirPath, { withFileTypes: true });
    return entries
      .map(e => {
        // Directory entry → directory name (e.g. "my-command")
        // File entry → strip extension (e.g. "my-skill.md" → "my-skill")
        if (e.isDirectory()) return e.name;
        return e.name.replace(/\.[^.]+$/, '');
      })
      .filter(n => !n.startsWith('.'))
      .sort();
  } catch {
    return [];
  }
}

// Extract tool name candidates from TypeScript/JavaScript source files.
// Uses a regex heuristic — may produce false positives but is reliable for
// standard MCP server patterns (name: 'tool_name' in object literals).
async function extractToolNamesFromSource(srcDir: string): Promise<string[]> {
  const files = await findSourceFiles(srcDir);
  const names = new Set<string>();

  for (const file of files) {
    try {
      const content = await fs.readFile(file, 'utf-8');
      const matches = content.matchAll(TOOL_NAME_PATTERN);
      for (const match of matches) {
        names.add(match[1]);
      }
    } catch {
      // Skip unreadable files
    }
  }

  return [...names].sort();
}

// Recursively find .ts and .js files in a directory.
async function findSourceFiles(dir: string): Promise<string[]> {
  const results: string[] = [];
  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory() && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
        results.push(...await findSourceFiles(full));
      } else if (entry.isFile() && (entry.name.endsWith('.ts') || entry.name.endsWith('.js'))) {
        results.push(full);
      }
    }
  } catch {
    // Ignore unreadable directories
  }
  return results;
}

// Find source files (src/, scripts/, hooks/) with mtime newer than the given timestamp.
async function findChangedSourceFiles(pluginPath: string, sinceMs: number): Promise<string[]> {
  const searchDirs = ['src', 'scripts', 'hooks'].map(d => path.join(pluginPath, d));
  const changed: string[] = [];

  for (const dir of searchDirs) {
    const files = await findSourceFiles(dir);
    for (const file of files) {
      try {
        const stat = await fs.stat(file);
        if (stat.mtimeMs > sinceMs) {
          changed.push(path.relative(pluginPath, file));
        }
      } catch {
        // Skip
      }
    }
  }

  return changed;
}

async function readVersion(pluginPath: string): Promise<string | undefined> {
  // Try plugin.json first (Claude Code plugins)
  try {
    const raw = await fs.readFile(path.join(pluginPath, '.claude-plugin', 'plugin.json'), 'utf-8');
    const data = JSON.parse(raw) as { version?: string };
    if (data.version) return data.version;
  } catch { /* fall through */ }

  // Try package.json (MCP/npm plugins)
  try {
    const raw = await fs.readFile(path.join(pluginPath, 'package.json'), 'utf-8');
    const data = JSON.parse(raw) as { version?: string };
    if (data.version) return data.version;
  } catch { /* fall through */ }

  return undefined;
}

async function fileExists(p: string): Promise<boolean> {
  try { await fs.access(p); return true; } catch { return false; }
}
