import type { PthTest } from './types.js';
export declare class TestStore {
    private tests;
    add(test: PthTest): void;
    update(test: PthTest): void;
    get(id: string): PthTest | undefined;
    getAll(): PthTest[];
    filter(predicate: (t: PthTest) => boolean): PthTest[];
    count(): number;
    persistToDir(dirPath: string): Promise<void>;
}
//# sourceMappingURL=store.d.ts.map