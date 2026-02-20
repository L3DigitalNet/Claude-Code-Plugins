export type PluginMode = 'mcp' | 'plugin';
export interface BuildSystem {
    installCommand: string[] | null;
    buildCommand: string[] | null;
    startCommand: string[] | null;
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
    mcpConfig?: McpConfig;
    cachePath?: string;
}
//# sourceMappingURL=types.d.ts.map