import { TestStore } from '../testing/store.js';
import type { SessionState } from './types.js';
export declare let testStore: TestStore;
export declare const iterationHistory: Array<{
    passing: number;
    failing: number;
    fixesApplied: number;
}>;
export declare function preflight(args: {
    pluginPath: string;
}): Promise<string>;
export interface StartSessionResult {
    state: SessionState;
    message: string;
}
export declare function startSession(args: {
    pluginPath: string;
    sessionNote?: string;
}): Promise<StartSessionResult>;
export declare function resumeSession(args: {
    branch: string;
    pluginPath: string;
}): Promise<StartSessionResult>;
export declare function endSession(state: SessionState): Promise<string>;
//# sourceMappingURL=manager.d.ts.map