import type { PthTest } from './types.js';
import type { ToolSchema } from '../shared/source-analyzer.js';
export interface GenerateMcpOptions {
    pluginPath: string;
    toolSchemas: ToolSchema[];
}
export declare function generateMcpTests(options: GenerateMcpOptions): Promise<PthTest[]>;
export declare function generatePluginTests(hookScripts: string[]): PthTest[];
//# sourceMappingURL=generator.d.ts.map