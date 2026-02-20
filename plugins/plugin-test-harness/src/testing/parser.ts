import { parse as parseYaml } from 'yaml';
import fs from 'fs/promises';
import path from 'path';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { PthTest } from './types.js';
import { slugify } from './utils.js';

export function parseTest(yamlText: string): PthTest {
  let raw: unknown;
  try {
    raw = parseYaml(yamlText);
  } catch (e) {
    throw new PTHError(PTHErrorCode.INVALID_TEST, `Invalid YAML: ${(e as Error).message}`);
  }

  const obj = raw as Record<string, unknown>;

  if (!obj['name'] || typeof obj['name'] !== 'string') {
    throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have a string "name" field');
  }
  if (!obj['mode'] || (obj['mode'] !== 'mcp' && obj['mode'] !== 'plugin')) {
    throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have mode: mcp | plugin');
  }

  if (!obj['expect'] || typeof obj['expect'] !== 'object') {
    throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have an "expect" block');
  }

  const mode = obj['mode'] as 'mcp' | 'plugin';
  const name = obj['name'] as string;

  let type: PthTest['type'];
  if (mode === 'mcp') {
    type = obj['steps'] ? 'scenario' : 'single';
  } else {
    type = (obj['type'] as PthTest['type']) ?? 'exec';
  }

  // Honour explicit id from YAML if present and slug-safe; fall back to derived slug.
  const rawId = typeof obj['id'] === 'string' ? obj['id'].trim() : '';
  const id = rawId && /^[a-z0-9_-]+$/i.test(rawId) ? rawId : slugify(name);

  return {
    id,
    name,
    mode,
    type,
    tool: obj['tool'] as string | undefined,
    input: obj['input'] as Record<string, unknown> | undefined,
    steps: obj['steps'] as PthTest['steps'],
    script: obj['script'] as string | undefined,
    stdin: obj['stdin'] as Record<string, unknown> | undefined,
    env: obj['env'] as Record<string, string> | undefined,
    checks: obj['checks'] as PthTest['checks'],
    command: obj['command'] as string | undefined,
    expect: obj['expect'] as PthTest['expect'],
    setup: obj['setup'] as PthTest['setup'],
    teardown: obj['teardown'] as PthTest['teardown'],
    tags: obj['tags'] as string[] | undefined,
    generated_from: obj['generated_from'] as PthTest['generated_from'],
    timeout_seconds: obj['timeout_seconds'] as number | undefined,
  };
}

export async function parseTestFile(filePath: string): Promise<PthTest[]> {
  let raw: string;
  try {
    raw = await fs.readFile(filePath, 'utf-8');
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw err;
  }
  // Support multi-document YAML (--- separator) or single test
  const docs = raw.split(/^---$/m).filter(d => d.trim().length > 0);
  return docs.map(doc => parseTest(doc));
}

export async function loadTestsFromDir(dirPath: string): Promise<PthTest[]> {
  let entries: string[];
  try {
    entries = await fs.readdir(dirPath);
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw err;
  }
  const tests: PthTest[] = [];
  for (const entry of entries) {
    if (entry.endsWith('.yaml') || entry.endsWith('.yml')) {
      const filePath = path.join(dirPath, entry);
      const fileTests = await parseTestFile(filePath);
      tests.push(...fileTests);
    }
  }
  return tests;
}
