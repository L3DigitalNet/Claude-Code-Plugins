// src/testing/generator.ts
import type { PthTest } from './types.js';
import type { ToolSchema } from '../shared/source-analyzer.js';

export interface GenerateMcpOptions {
  pluginPath: string;
  toolSchemas: ToolSchema[];
}

export async function generateMcpTests(options: GenerateMcpOptions): Promise<PthTest[]> {
  const tests: PthTest[] = [];

  for (const tool of options.toolSchemas) {
    // Test 1: valid input (using required fields with minimal values)
    const validInput = buildValidInput(tool);
    tests.push({
      id: slugify(`${tool.name}_valid_input`),
      name: `${tool.name} — valid input`,
      mode: 'mcp',
      type: 'single',
      tool: tool.name,
      input: validInput,
      expect: { success: true },
      generated_from: 'schema',
      timeout_seconds: 10,
    });

    // Test 2: missing required field (if any required fields exist)
    const required = tool.inputSchema?.required ?? [];
    if (required.length > 0) {
      const missingInput = { ...validInput };
      delete missingInput[required[0]];
      tests.push({
        id: slugify(`${tool.name}_missing_required`),
        name: `${tool.name} — missing required field "${required[0]}"`,
        mode: 'mcp',
        type: 'single',
        tool: tool.name,
        input: missingInput,
        expect: { success: false },
        generated_from: 'schema',
        timeout_seconds: 10,
      });
    }
  }

  return tests;
}

export function generatePluginTests(pluginPath: string, hookScripts: string[]): PthTest[] {
  const tests: PthTest[] = [];

  for (const script of hookScripts) {
    tests.push({
      id: slugify(`validate_${script}`),
      name: `${script} — script exists and is readable`,
      mode: 'plugin',
      type: 'validate',
      checks: [{ type: 'file-exists', files: [script] }],
      expect: {},   // validate tests have no output expectations — empty ExpectBlock
      generated_from: 'source_analysis',
    });
  }

  return tests;
}

function buildValidInput(tool: ToolSchema): Record<string, unknown> {
  const input: Record<string, unknown> = {};
  const props = tool.inputSchema?.properties ?? {};
  const required = tool.inputSchema?.required ?? [];

  for (const field of required) {
    const prop = props[field];
    if (!prop) { input[field] = ''; continue; }
    if (prop.type === 'string') input[field] = prop.enum ? prop.enum[0] : 'test-value';
    else if (prop.type === 'number' || prop.type === 'integer') input[field] = 1;
    else if (prop.type === 'boolean') input[field] = true;
    else if (prop.type === 'array') input[field] = [];
    else if (prop.type === 'object') input[field] = {};
    else input[field] = null;
  }
  return input;
}

function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}
