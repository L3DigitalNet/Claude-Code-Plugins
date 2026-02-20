import type { PthTest } from './types.js';
export declare function parseTest(yamlText: string): PthTest;
export declare function parseTestFile(filePath: string): Promise<PthTest[]>;
export declare function loadTestsFromDir(dirPath: string): Promise<PthTest[]>;
//# sourceMappingURL=parser.d.ts.map