export interface ToolSchema {
    name: string;
    description?: string;
    inputSchema?: {
        type: string;
        properties?: Record<string, {
            type: string;
            description?: string;
            enum?: unknown[];
        }>;
        required?: string[];
    };
}
export declare function readToolSchemasFromSource(pluginPath: string): Promise<ToolSchema[]>;
export declare function writeToolSchemasCache(pluginPath: string, schemas: ToolSchema[]): Promise<void>;
//# sourceMappingURL=source-analyzer.d.ts.map