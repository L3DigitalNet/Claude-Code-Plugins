import type { BuildSystem } from './types.js';
export interface ReloadResult {
    buildSucceeded: boolean;
    buildOutput: string;
    processTerminated: boolean;
    pid?: number;
    message: string;
}
export declare function reloadPlugin(worktreePath: string, buildSystem: BuildSystem, pluginStartPattern: string): Promise<ReloadResult>;
//# sourceMappingURL=reloader.d.ts.map