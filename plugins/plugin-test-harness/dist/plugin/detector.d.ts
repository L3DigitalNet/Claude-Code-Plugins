import type { PluginMode, BuildSystem, McpConfig } from './types.js';
export declare function detectPluginMode(pluginPath: string): Promise<PluginMode>;
export declare function detectBuildSystem(pluginPath: string): Promise<BuildSystem>;
export declare function readMcpConfig(pluginPath: string): Promise<McpConfig | null>;
export declare function detectPluginName(pluginPath: string): Promise<string>;
//# sourceMappingURL=detector.d.ts.map