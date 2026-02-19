import { parse as parseYaml } from 'yaml';
import fs from 'fs/promises';
import path from 'path';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { PthTest } from './types.js';

function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}

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

  const mode = obj['mode'] as 'mcp' | 'plugin';
  const name = obj['name'] as string;

  let type: PthTest['type'];
  if (mode === 'mcp') {
    type = obj['steps'] ? 'scenario' : 'single';
  } else {
    type = (obj['type'] as PthTest['type']) ?? 'exec';
  }

  return {
    id: slugify(name),
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
  const raw = await fs.readFile(filePath, 'utf-8');
  // Support multi-document YAML (--- separator) or single test
  const docs = raw.split(/^---$/m).filter(d => d.trim().length > 0);
  return docs.map(doc => parseTest(doc));
}

export async function loadTestsFromDir(dirPath: string): Promise<PthTest[]> {
  const tests: PthTest[] = [];
  try {
    const entries = await fs.readdir(dirPath);
    for (const entry of entries) {
      if (entry.endsWith('.yaml') || entry.endsWith('.yml')) {
        const filePath = path.join(dirPath, entry);
        const filTests = await parseTestFile(filePath);
        tests.push(...filTests);
      }
    }
  } catch {
    // dir doesn't exist yet — return empty
  }
  return tests;
}
