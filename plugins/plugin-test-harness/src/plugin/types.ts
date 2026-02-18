export type PluginMode = 'mcp' | 'plugin';

export interface BuildSystem {
  installCommand: string[] | null;   // e.g. ['npm', 'install']
  buildCommand: string[] | null;     // e.g. ['npm', 'run', 'build']
  startCommand: string[] | null;     // e.g. ['node', 'dist/index.js'] — from .mcp.json
  language: 'typescript' | 'python' | 'shell' | 'unknown';
}

export interface McpConfig {
  serverName: string;
  command: string;
  args: string[];
  env?: Record<string, string>;
}

export interface PluginInfo {
  mode: PluginMode;
  name: string;
  sourcePath: string;
  buildSystem: BuildSystem;
  mcpConfig?: McpConfig;   // only for mcp mode
  cachePath?: string;      // ~/.claude/plugins/cache/<name>/ if detectable
}
