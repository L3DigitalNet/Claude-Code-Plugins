import fs from 'fs/promises';
import path from 'path';
import { stringify as stringifyYaml } from 'yaml';
import type { PthTest } from './types.js';

export class TestStore {
  private tests: Map<string, PthTest> = new Map();

  add(test: PthTest): void {
    this.tests.set(test.id, test);
  }

  update(test: PthTest): void {
    this.tests.set(test.id, test);
  }

  get(id: string): PthTest | undefined {
    return this.tests.get(id);
  }

  getAll(): PthTest[] {
    return Array.from(this.tests.values());
  }

  filter(predicate: (t: PthTest) => boolean): PthTest[] {
    return this.getAll().filter(predicate);
  }

  count(): number {
    return this.tests.size;
  }

  async persistToDir(dirPath: string): Promise<void> {
    await fs.mkdir(dirPath, { recursive: true });
    // Group by mode for cleaner files
    const mcpTests = this.filter(t => t.mode === 'mcp');
    const pluginTests = this.filter(t => t.mode === 'plugin');

    if (mcpTests.length > 0) {
      await fs.writeFile(
        path.join(dirPath, 'mcp-tests.yaml'),
        mcpTests.map(t => stringifyYaml(t)).join('\n---\n'),
        'utf-8'
      );
    }
    if (pluginTests.length > 0) {
      await fs.writeFile(
        path.join(dirPath, 'plugin-tests.yaml'),
        pluginTests.map(t => stringifyYaml(t)).join('\n---\n'),
        'utf-8'
      );
    }
  }
}
