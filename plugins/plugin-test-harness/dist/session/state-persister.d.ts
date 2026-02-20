import type { SessionState } from './types.js';
export declare function writeSessionState(worktreePath: string, state: SessionState): Promise<void>;
export declare function readSessionState(worktreePath: string): Promise<SessionState | null>;
//# sourceMappingURL=state-persister.d.ts.map