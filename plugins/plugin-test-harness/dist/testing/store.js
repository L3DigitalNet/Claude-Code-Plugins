import fs from 'fs/promises';
import path from 'path';
import { stringify as stringifyYaml } from 'yaml';
export class TestStore {
    tests = new Map();
    add(test) {
        if (this.tests.has(test.id)) {
            throw new Error(`Test with id "${test.id}" already exists. Use update() to replace it.`);
        }
        this.tests.set(test.id, test);
    }
    update(test) {
        this.tests.set(test.id, test);
    }
    get(id) {
        return this.tests.get(id);
    }
    getAll() {
        return Array.from(this.tests.values());
    }
    filter(predicate) {
        return this.getAll().filter(predicate);
    }
    count() {
        return this.tests.size;
    }
    async persistToDir(dirPath) {
        await fs.mkdir(dirPath, { recursive: true });
        // Group by mode for cleaner files
        const mcpTests = this.filter(t => t.mode === 'mcp');
        const pluginTests = this.filter(t => t.mode === 'plugin');
        if (mcpTests.length > 0) {
            await fs.writeFile(path.join(dirPath, 'mcp-tests.yaml'), mcpTests.map(t => stringifyYaml(t)).join('\n---\n'), 'utf-8');
        }
        if (pluginTests.length > 0) {
            await fs.writeFile(path.join(dirPath, 'plugin-tests.yaml'), pluginTests.map(t => stringifyYaml(t)).join('\n---\n'), 'utf-8');
        }
    }
}
//# sourceMappingURL=store.js.map