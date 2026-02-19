import fs from 'fs/promises';
import path from 'path';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { PluginMode, BuildSystem, McpConfig } from './types.js';

export async function detectPluginMode(pluginPath: string): Promise<PluginMode> {
  try {
    await fs.access(pluginPath);
  } catch {
    throw new PTHError(PTHErrorCode.PLUGIN_NOT_FOUND, `Plugin path not found: ${pluginPath}`);
  }

  // MCP plugin has .mcp.json at root
  const mcpJsonPath = path.join(pluginPath, '.mcp.json');
  try {
    await fs.access(mcpJsonPath);
    return 'mcp';
  } catch {
    // not MCP
  }

  // Claude Code plugin has .claude-plugin/ directory
  const claudePluginDir = path.join(pluginPath, '.claude-plugin');
  try {
    await fs.access(claudePluginDir);
    return 'plugin';
  } catch {
    throw new PTHError(
      PTHErrorCode.INVALID_PLUGIN,
      `Not a valid plugin: no .mcp.json or .claude-plugin/ found at ${pluginPath}`
    );
  }
}

export async function detectBuildSystem(pluginPath: string): Promise<BuildSystem> {
  // Check for package.json
  const pkgPath = path.join(pluginPath, 'package.json');
  try {
    const raw = await fs.readFile(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as { scripts?: Record<string, string>; main?: string };
    const hasBuildScript = !!pkg.scripts?.['build'];
    const hasTsConfig = await fileExists(path.join(pluginPath, 'tsconfig.json'));

    return {
      installCommand: ['npm', 'install'],
      buildCommand: hasBuildScript ? ['npm', 'run', 'build'] :
                    hasTsConfig   ? ['npx', 'tsc'] : null,
      startCommand: pkg.main ? ['node', pkg.main] : null,
      language: hasTsConfig ? 'typescript' : 'unknown',
    };
  } catch {
    // no package.json
  }

  // Check for pyproject.toml / setup.py
  if (await fileExists(path.join(pluginPath, 'pyproject.toml')) ||
      await fileExists(path.join(pluginPath, 'setup.py'))) {
    return {
      installCommand: ['pip', 'install', '-e', '.'],
      buildCommand: null,
      startCommand: null,
      language: 'python',
    };
  }

  // Standalone TypeScript project (tsconfig.json without package.json)
  if (await fileExists(path.join(pluginPath, 'tsconfig.json'))) {
    return {
      installCommand: null,
      buildCommand: ['npx', 'tsc'],
      startCommand: null,
      language: 'typescript',
    };
  }

  // Shell plugin (Makefile or .sh entry points)
  if (await fileExists(path.join(pluginPath, 'Makefile')) ||
      await fileExists(path.join(pluginPath, 'install.sh'))) {
    return {
      installCommand: null,
      buildCommand: null,
      startCommand: null,
      language: 'shell',
    };
  }

  // No recognized build system
  return {
    installCommand: null,
    buildCommand: null,
    startCommand: null,
    language: 'unknown',
  };
}

export async function readMcpConfig(pluginPath: string): Promise<McpConfig | null> {
  const mcpJsonPath = path.join(pluginPath, '.mcp.json');

  // Read file directly — return null only on ENOENT, throw on other errors
  let raw: string;
  try {
    raw = await fs.readFile(mcpJsonPath, 'utf-8');
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw err;
  }

  let config: Record<string, { command: string; args: string[]; env?: Record<string, string> }>;
  try {
    config = JSON.parse(raw) as typeof config;
  } catch (err) {
    throw new PTHError(
      PTHErrorCode.INVALID_PLUGIN,
      `Failed to parse .mcp.json at ${mcpJsonPath}: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  const entry = Object.entries(config)[0];
  if (!entry) {
    throw new PTHError(PTHErrorCode.INVALID_PLUGIN, `.mcp.json at ${mcpJsonPath} has no server entries`);
  }
  const [serverName, serverConfig] = entry;
  return { serverName, ...serverConfig };
}

export async function detectPluginName(pluginPath: string): Promise<string> {
  // Try .claude-plugin/manifest.json
  const manifestPath = path.join(pluginPath, '.claude-plugin', 'manifest.json');
  try {
    const raw = await fs.readFile(manifestPath, 'utf-8');
    const manifest = JSON.parse(raw) as { name?: string };
    if (manifest.name) return manifest.name;
  } catch { /* ignore */ }

  // Try package.json
  const pkgPath = path.join(pluginPath, 'package.json');
  try {
    const raw = await fs.readFile(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as { name?: string };
    if (pkg.name) return pkg.name;
  } catch { /* ignore */ }

  // Fall back to directory name
  return path.basename(pluginPath);
}

async function fileExists(p: string): Promise<boolean> {
  try { await fs.access(p); return true; } catch { return false; }
}
