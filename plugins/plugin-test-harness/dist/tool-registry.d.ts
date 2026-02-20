import { z } from 'zod';
export interface ToolDef {
    name: string;
    description: string;
    inputSchema: z.ZodTypeAny;
}
export declare class ToolRegistry {
    private active;
    getActiveTools(): ToolDef[];
    activate(): void;
    deactivate(): void;
    isActive(): boolean;
}
//# sourceMappingURL=tool-registry.d.ts.map