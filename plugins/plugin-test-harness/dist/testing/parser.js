import { parse as parseYaml } from 'yaml';
import fs from 'fs/promises';
import path from 'path';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import { slugify } from './utils.js';
export function parseTest(yamlText) {
    let raw;
    try {
        raw = parseYaml(yamlText);
    }
    catch (e) {
        throw new PTHError(PTHErrorCode.INVALID_TEST, `Invalid YAML: ${e.message}`);
    }
    const obj = raw;
    if (!obj['name'] || typeof obj['name'] !== 'string') {
        throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have a string "name" field');
    }
    if (!obj['mode'] || (obj['mode'] !== 'mcp' && obj['mode'] !== 'plugin')) {
        throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have mode: mcp | plugin');
    }
    if (!obj['expect'] || typeof obj['expect'] !== 'object') {
        throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have an "expect" block');
    }
    const mode = obj['mode'];
    const name = obj['name'];
    let type;
    if (mode === 'mcp') {
        type = obj['steps'] ? 'scenario' : 'single';
    }
    else {
        type = obj['type'] ?? 'exec';
    }
    return {
        id: slugify(name),
        name,
        mode,
        type,
        tool: obj['tool'],
        input: obj['input'],
        steps: obj['steps'],
        script: obj['script'],
        stdin: obj['stdin'],
        env: obj['env'],
        checks: obj['checks'],
        command: obj['command'],
        expect: obj['expect'],
        setup: obj['setup'],
        teardown: obj['teardown'],
        tags: obj['tags'],
        generated_from: obj['generated_from'],
        timeout_seconds: obj['timeout_seconds'],
    };
}
export async function parseTestFile(filePath) {
    let raw;
    try {
        raw = await fs.readFile(filePath, 'utf-8');
    }
    catch (err) {
        if (err.code === 'ENOENT')
            return [];
        throw err;
    }
    // Support multi-document YAML (--- separator) or single test
    const docs = raw.split(/^---$/m).filter(d => d.trim().length > 0);
    return docs.map(doc => parseTest(doc));
}
export async function loadTestsFromDir(dirPath) {
    let entries;
    try {
        entries = await fs.readdir(dirPath);
    }
    catch (err) {
        if (err.code === 'ENOENT')
            return [];
        throw err;
    }
    const tests = [];
    for (const entry of entries) {
        if (entry.endsWith('.yaml') || entry.endsWith('.yml')) {
            const filePath = path.join(dirPath, entry);
            const fileTests = await parseTestFile(filePath);
            tests.push(...fileTests);
        }
    }
    return tests;
}
//# sourceMappingURL=parser.js.map