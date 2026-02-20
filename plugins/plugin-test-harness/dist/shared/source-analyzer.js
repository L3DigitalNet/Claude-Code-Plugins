// src/shared/source-analyzer.ts
import fs from 'fs/promises';
import path from 'path';
export async function readToolSchemasFromSource(pluginPath) {
    // Read .pth-tools-cache.json if present (populated by Claude after tools/list)
    const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
    let raw;
    try {
        raw = await fs.readFile(cachePath, 'utf-8');
    }
    catch (err) {
        if (err.code === 'ENOENT')
            return [];
        throw err;
    }
    return JSON.parse(raw);
}
export async function writeToolSchemasCache(pluginPath, schemas) {
    const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
    await fs.writeFile(cachePath, JSON.stringify(schemas, null, 2), 'utf-8');
}
//# sourceMappingURL=source-analyzer.js.map